#include "FFmpegMediaReader.h"

FFmpegMediaReader::FFmpegMediaReader (const int audioFifoSize, const int videoFifoSize)
:   FFmpegMediaDecodeThread(audioFifo, videoFifoSize),
    audioFifoSize (audioFifoSize),
    audioFifo(DEFAULT_NUM_CHANNELS, audioFifoSize),
    nextReadPos(0),
    effectiveSampleRate(DEFAULT_SAMPLE_RATE),
    effectiveNumChannels(DEFAULT_NUM_CHANNELS),
    usingEmulatedAudio(false)
{
}

FFmpegMediaReader::~FFmpegMediaReader()
{
    closeMediaFile();
    masterReference.clear();
}

int FFmpegMediaReader::loadMediaFile (const juce::File& inputFile)
{
    if (!inputFile.existsAsFile()) {
        closeMediaFile();
        return false;
    }
    
    if (FFmpegMediaDecodeThread::loadMediaFile(inputFile)) {
	    // Reset state variables
	    currentPositionSeconds = 0.0;
	    endOfFileReached = false;

        // Set up audio parameters based on whether we have a real audio stream
        if (getAudioContext() != nullptr) {
            effectiveSampleRate = getSampleRate();
            effectiveNumChannels = getNumberOfAudioChannels();
            usingEmulatedAudio = false;
        } else {
            // No audio stream - use default values
            effectiveSampleRate = DEFAULT_SAMPLE_RATE;
            effectiveNumChannels = DEFAULT_NUM_CHANNELS;
            usingEmulatedAudio = true;
            
            // Initialize audio FIFO with default parameters
            audioFifo.setSize(effectiveNumChannels, audioFifoSize);
        }

        if (getVideoStreamIndex() >= 0) {
            videoListeners.call(&FFmpegVideoListener::videoFileChanged, inputFile);
            videoListeners.call(&FFmpegVideoListener::videoSizeChanged, getVideoWidth(),
                              getVideoHeight(), getPixelFormat());
        }
        return true;
    }
    return false;
}


double FFmpegMediaReader::getPositionSeconds() const
{
    if (getSampleRate() > 0)
        return static_cast<double> (nextReadPos) / getSampleRate();
    return -1.0;
}

void FFmpegMediaReader::prepareToPlay (int samplesPerBlockExpected, double newSampleRate)
{
    //newSampleRate is ignored and not propagated to the video reader, since the is the source of the transport source.
    //The readers samplerate should not be changed, so it's data can be correctly resampled. It must always be the
    //correct samplerate of the video file. It is set when loading a file

    //DBG("FFmpegVideoReader::prepareToPlay, SR: " + juce::String(getSampleRate()));
    //When there's no audio, the audio FIFO might not be properly initialized
    const int numChannels = (std::max)(1, getNumberOfAudioChannels());
    audioFifo.setSize (numChannels, audioFifoSize);
    audioFifo.reset();
    nextReadPos = 0;
}

void FFmpegMediaReader::releaseResources ()
{
//    DBG("FFmpegVideoReader::releaseResources()");
    audioFifo.clear();
}

void FFmpegMediaReader::getNextAudioBlock (const juce::AudioSourceChannelInfo &bufferToFill)
{
    // If we're using emulated audio, fill with silence
    if (usingEmulatedAudio) {
        bufferToFill.clearActiveBufferRegion();
        nextReadPos += bufferToFill.numSamples;
        
        // Still trigger video frame updates based on timing
        setPositionSeconds(static_cast<double>(nextReadPos) / effectiveSampleRate, false);
        return;
    }
    
    // Use real audio
    setPositionSeconds(static_cast<double>(nextReadPos) / effectiveSampleRate, false);
    
    if (audioFifo.getNumReady() >= bufferToFill.numSamples) {
        audioFifo.readFromFifo(bufferToFill);
    } else {
        int numSamples = audioFifo.getNumReady();
        if (numSamples > 0) {
            audioFifo.readFromFifo(bufferToFill, numSamples);
            bufferToFill.buffer->clear(numSamples, bufferToFill.numSamples - numSamples);
        } else {
            bufferToFill.clearActiveBufferRegion();
        }
    }

    nextReadPos += bufferToFill.numSamples;
    
    if (endOfFileReached && nextReadPos >= getTotalLength()) {
        videoListeners.call(&FFmpegVideoListener::videoEnded);
    }
}

bool FFmpegMediaReader::waitForNextAudioBlockReady (const juce::AudioSourceChannelInfo &bufferToFill, const int msecs) const
{
    const juce::int64 timeout (juce::Time::getCurrentTime().toMilliseconds() + msecs);
    while (audioFifo.getNumReady () < bufferToFill.numSamples && juce::Time::getCurrentTime().toMilliseconds() < timeout)
    {
        juce::Thread::sleep (5);
    }
    return false;
}

void FFmpegMediaReader::setNextReadPosition(juce::int64 newPosition)
{
    if (effectiveSampleRate <= 0)
        return;

    nextReadPos = newPosition;
    setPositionSeconds(static_cast<double>(nextReadPos) / effectiveSampleRate, true);
}

void FFmpegMediaReader::setOffsetReadPosition(juce::int64 newOffset)
{
    //    DBG("FFmpegVideoReader::setOffsetReadPosition(" + juce::String(newOffset) + ")");
    if (getSampleRate() <= 0)
        return;

    //tell decode thread to set offset
    if(setOffsetSeconds(static_cast<double>(newOffset) / static_cast<double>(getSampleRate())))
    {
        nextReadPos = nextReadPos + newOffset;
    }
}

juce::int64 FFmpegMediaReader::getNextReadPosition () const
{
    return nextReadPos;
}

juce::int64 FFmpegMediaReader::getTotalLength() const
{
    return static_cast<juce::int64>(getDuration() * effectiveSampleRate);
}

bool FFmpegMediaReader::isLooping() const
{
    return false;
}

double FFmpegMediaReader::getSampleRate() const
{
    return effectiveSampleRate;
}

int FFmpegMediaReader::getNumberOfAudioChannels() const
{
    return effectiveNumChannels;
}

const AVFrame* FFmpegMediaReader::getNextVideoFrame()
{
    if (videoFramesFifo.countNewFrames() > 0)
    {
        AVFrame* nextFrame = videoFramesFifo.getFrameAtReadIndex();
        currentPositionSeconds = videoFramesFifo.getSecondsAtReadIndex();
        videoFramesFifo.advanceReadIndex();
        return nextFrame;
    }
    return nullptr;
}

bool FFmpegMediaReader::isEndOfFile() const
{
    return endOfFileReached;
}


