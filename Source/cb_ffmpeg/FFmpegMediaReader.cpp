#include "FFmpegMediaReader.h"

FFmpegMediaReader::FFmpegMediaReader (const int audioFifoSize, const int videoFifoSize)
:   FFmpegMediaDecodeThread(audioFifo, videoFifoSize),
    audioFifoSize (audioFifoSize),
    audioFifo (2, audioFifoSize),
    nextReadPos (0)
{
}

FFmpegMediaReader::~FFmpegMediaReader()
{
    closeMediaFile();
    masterReference.clear();
}

int FFmpegMediaReader::loadMediaFile (const juce::File& inputFile)
{
    closeMediaFile();
    mediaFile = juce::File();
    
    // Reset state variables
    currentPositionSeconds = 0.0;
    endOfFileReached = false;
    
    //open file, update file handle
    if (FFmpegMediaDecodeThread::loadMediaFile (inputFile))
    {
        if (getVideoStreamIndex() >= 0) // Only call videoSizeChanged if a video stream exists
        {
            //notify listeners about the new video file and it's size
            videoListeners.call(&FFmpegVideoListener::videoFileChanged, inputFile);
            videoListeners.call(&FFmpegVideoListener::videoSizeChanged, getVideoWidth(),
                                getVideoHeight(), getPixelFormat()/*videoContext->pix_fmt*/);
        }
        else
        {
            // Notify listeners to clear any video frames
            videoListeners.call(&FFmpegVideoListener::videoFileChanged, inputFile);
            videoListeners.call(&FFmpegVideoListener::videoSizeChanged, 0, 0, AV_PIX_FMT_NONE);
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
    const int numChannels = std::max(1, getNumberOfAudioChannels());
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
    // return if samplerate is invalid
    if (getSampleRate() <= 0 || getNumberOfAudioChannels() <= 0)
    {
        bufferToFill.clearActiveBufferRegion();
        nextReadPos += bufferToFill.numSamples;
        DBG("Invalid samplerate: " + std::to_string(getSampleRate()));
        return;
    }
    
    // this triggers reading of new video frame
    setPositionSeconds (static_cast<double>(nextReadPos) / static_cast<double>(getSampleRate()), false);
    
    if (audioFifo.getNumReady() >= bufferToFill.numSamples)
    {
        audioFifo.readFromFifo (bufferToFill);
    }
    else
    {
        int numSamples = audioFifo.getNumReady();
        if (numSamples > 0) {
            audioFifo.readFromFifo (bufferToFill, numSamples);
            bufferToFill.buffer->clear (numSamples, bufferToFill.numSamples - numSamples);
        }
        else {
            bufferToFill.clearActiveBufferRegion();
        }
    }

    nextReadPos += bufferToFill.numSamples;
    
    //if the decoding thread has reached the end of file and the next read position is larger then total length
    if(endOfFileReached && nextReadPos >= getTotalLength())
    {
        DBG("End at position: " + juce::String(static_cast<double>(nextReadPos) / static_cast<double>(getSampleRate())));
        videoListeners.call (&FFmpegVideoListener::videoEnded);
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

void FFmpegMediaReader::setNextReadPosition (juce::int64 newPosition)
{
//    DBG("FFmpegVideoReader::setNextReadPosition(" + juce::String(newPosition) + ")");
    if (getSampleRate() <= 0)
        return;
    nextReadPos = newPosition;
    
    //tell decode thread to seek to position
    setPositionSeconds ( static_cast<double>(nextReadPos) / static_cast<double>(getSampleRate()), true);
}

juce::int64 FFmpegMediaReader::getNextReadPosition () const
{
    return nextReadPos;
}

juce::int64 FFmpegMediaReader::getTotalLength () const
{
    if (getSampleRate() > 0) {
        return static_cast<juce::int64>(getDuration() * getSampleRate());
    } else if (getFramesPerSecond() > 0) {
        // if there's no audio stream, you should use the video stream's duration
        return static_cast<juce::int64>(getDuration() * getFramesPerSecond());
    } else {
        return 0;
    }
}

bool FFmpegMediaReader::isLooping() const
{
    return false;
}
