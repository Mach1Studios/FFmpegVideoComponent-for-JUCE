cmake_minimum_required(VERSION 3.15 FATAL_ERROR)

include_guard(GLOBAL)

include(FetchContent)
include(FeatureSummary)
include(FindPackageMessage)
include(FindPackageHandleStandardArgs)

# Avoid warning about DOWNLOAD_EXTRACT_TIMESTAMP in CMake 3.24:
if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.24.0")
    cmake_policy(SET CMP0135 NEW)
endif()

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    set_package_properties("${CMAKE_FIND_PACKAGE_NAME}" 
                            PROPERTIES 
                                URL "https://www.ffmpeg.org/"
                                DESCRIPTION "Audio and video codecs")
    FetchContent_Declare(ffmpeg 
                          GIT_REPOSITORY "https://github.com/mach1studios/ffmpegBuild.git"
                          GIT_TAG origin/feature/5-1-6)

elseif (${CMAKE_SYSTEM_NAME} STREQUAL "Windows" AND ${CMAKE_SYSTEM_PROCESSOR} STREQUAL "AMD64")
    set_package_properties("${CMAKE_FIND_PACKAGE_NAME}" 
                            PROPERTIES 
                                URL "https://www.ffmpeg.org/"
                                DESCRIPTION "Audio and video codecs")
    FetchContent_Declare(ffmpeg 
                          GIT_REPOSITORY "https://github.com/mach1studios/ffmpegBuild.git"
                          GIT_TAG origin/feature/windows-build)

elseif (${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set_package_properties("${CMAKE_FIND_PACKAGE_NAME}" 
                            PROPERTIES 
                                URL "https://www.ffmpeg.org/"
                                DESCRIPTION "Audio and video codecs")
    FetchContent_Declare(ffmpeg 
                          GIT_REPOSITORY "https://github.com/mach1studios/ffmpegBuild.git"
                          GIT_TAG origin/feature/linux-build)

endif()

FetchContent_MakeAvailable(ffmpeg)

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")

    find_package_message("${CMAKE_FIND_PACKAGE_NAME}" 
                          "ffmpeg package found -- Sources downloaded"
                          "ffmpeg (GitHub)")

    set(${CMAKE_FIND_PACKAGE_NAME}_FOUND TRUE)

else()

    macro(find_component _component _header)
        find_path(${_component}_INCLUDE_DIRS "${_header}" PATH_SUFFIXES ffmpeg)
        
        if (${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
            set(CMAKE_FIND_LIBRARY_PREFIXES "lib")
            set(CMAKE_FIND_LIBRARY_SUFFIXES ".dll.a")
            #message(STATUS "ffmpeg component: ${CMAKE_FIND_LIBRARY_PREFIXES}${_component}${CMAKE_FIND_LIBRARY_SUFFIXES}")
            find_library(${_component}_LIBRARY NAMES "${CMAKE_FIND_LIBRARY_PREFIXES}${_component}${CMAKE_FIND_LIBRARY_SUFFIXES}" PATH_SUFFIXES ffmpeg)
        else()
            find_library(${_component}_LIBRARY NAMES "${_component}" PATH_SUFFIXES ffmpeg)            
        endif()

        if (${_component}_LIBRARY AND ${_component}_INCLUDE_DIRS)
            set(ffmpeg_${_component}_FOUND TRUE)
            set(ffmpeg_LINK_LIBRARIES ${ffmpeg_LINK_LIBRARIES} "${${_component}_LIBRARY}")
            list(APPEND ffmpeg_INCLUDE_DIRS ${${_component}_INCLUDE_DIRS}) 

            if (NOT TARGET ffmpeg::${_component})
                add_library(ffmpeg_${_component} STATIC IMPORTED)
                set_target_properties(ffmpeg_${_component} PROPERTIES
                    INTERFACE_INCLUDE_DIRECTORIES "${${_component}_INCLUDE_DIRS}"
                    IMPORTED_LOCATION "${${_component}_LIBRARY}"
                )
                add_library(ffmpeg::${_component} ALIAS ffmpeg_${_component})
            endif()
        endif()
      
        mark_as_advanced(${_component}_INCLUDE_DIRS)
        mark_as_advanced(${_component}_LIBRARY)
    endmacro()

    # The default components
    if (NOT ffmpeg_FIND_COMPONENTS)
        set(ffmpeg_FIND_COMPONENTS avcodec avfilter avformat avdevice avutil swresample swscale)
    endif ()

    # Traverse the user-selected components of the package and find them
    set(ffmpeg_INCLUDE_DIRS "${PROJECT_BINARY_DIR}/_deps/ffmpeg-build/include")
    set(ffmpeg_LINK_LIBRARIES)

    foreach(_component ${ffmpeg_FIND_COMPONENTS})
        find_component(${_component} lib${_component}/${_component}.h)
    endforeach()
    mark_as_advanced(ffmpeg_INCLUDE_DIRS)
    mark_as_advanced(ffmpeg_LINK_LIBRARIES)

    #message(STATUS "ffmpeg lib paths: ${ffmpeg_LINK_LIBRARIES}")

    # Handle findings
    list(LENGTH ffmpeg_FIND_COMPONENTS ffmpeg_COMPONENTS_COUNT)
    find_package_handle_standard_args(ffmpeg REQUIRED_VARS ffmpeg_COMPONENTS_COUNT HANDLE_COMPONENTS)

    # Publish targets if succeeded to find the ffmpeg package and the requested components
    if (ffmpeg_FOUND AND NOT TARGET ffmpeg::ffmpeg)
        add_library(ffmpeg INTERFACE)
        set_target_properties(ffmpeg PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${ffmpeg_INCLUDE_DIRS}"
            INTERFACE_LINK_LIBRARIES "${ffmpeg_LINK_LIBRARIES}"
        )
        add_library(ffmpeg::ffmpeg ALIAS ffmpeg)
    endif()

endif()