cmake_minimum_required(VERSION 3.15 FATAL_ERROR)

include_guard(GLOBAL)

include(FetchContent)
include(ExternalProject)
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

elseif (${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
    set_package_properties("${CMAKE_FIND_PACKAGE_NAME}" 
                            PROPERTIES 
                                URL "https://www.ffmpeg.org/"
                                DESCRIPTION "Audio and video codecs")
    
    # Determine Windows target architecture
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(FFMPEG_TARGET "win64")
    else()
        set(FFMPEG_TARGET "win32")
    endif()
    
    # Set build variant (can be overridden by user)
    if(NOT DEFINED FFMPEG_VARIANT)
        set(FFMPEG_VARIANT "gpl" CACHE STRING "FFmpeg build variant (gpl, lgpl, nonfree, gpl-shared, lgpl-shared, nonfree-shared)")
    endif()
    
    # Set FFmpeg version (can be overridden by user)
    if(NOT DEFINED FFMPEG_VERSION)
        set(FFMPEG_VERSION "5.1" CACHE STRING "FFmpeg version (4.4, 5.0, 5.1, 6.0, 6.1, 7.0, 7.1, or empty for master)")
    endif()
    
    # Determine archive name based on version
    if(FFMPEG_VERSION STREQUAL "")
        set(FFMPEG_ARCHIVE_NAME "ffmpeg-master-latest-${FFMPEG_TARGET}-${FFMPEG_VARIANT}")
    else()
        set(FFMPEG_ARCHIVE_NAME "ffmpeg-${FFMPEG_VERSION}-${FFMPEG_TARGET}-${FFMPEG_VARIANT}")
    endif()
    
    FetchContent_Declare(ffmpeg_builds
                          GIT_REPOSITORY "https://github.com/BtbN/FFmpeg-Builds.git"
                          GIT_TAG "master")
    
    FetchContent_GetProperties(ffmpeg_builds)
    if(NOT ffmpeg_builds_POPULATED)
        FetchContent_Populate(ffmpeg_builds)
        
        # Build FFmpeg using the provided build.sh script with version
        ExternalProject_Add(ffmpeg_build
            SOURCE_DIR ${ffmpeg_builds_SOURCE_DIR}
            CONFIGURE_COMMAND ""
            BUILD_COMMAND bash ${ffmpeg_builds_SOURCE_DIR}/build.sh ${FFMPEG_TARGET} ${FFMPEG_VARIANT} ${FFMPEG_VERSION}
            BUILD_IN_SOURCE 1
            INSTALL_COMMAND ""
            BUILD_BYPRODUCTS ${ffmpeg_builds_SOURCE_DIR}/artifacts/${FFMPEG_ARCHIVE_NAME}.zip
        )
        
        # Extract the built FFmpeg
        ExternalProject_Add_Step(ffmpeg_build extract_ffmpeg
            COMMAND ${CMAKE_COMMAND} -E tar xf ${ffmpeg_builds_SOURCE_DIR}/artifacts/${FFMPEG_ARCHIVE_NAME}.zip
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            DEPENDEES build
        )
        
        # Set FFmpeg paths
        set(FFMPEG_ROOT_DIR ${CMAKE_CURRENT_BINARY_DIR}/${FFMPEG_ARCHIVE_NAME})
        set(FFMPEG_INCLUDE_DIRS ${FFMPEG_ROOT_DIR}/include)
        set(FFMPEG_LIBRARY_DIRS ${FFMPEG_ROOT_DIR}/lib)
        set(FFMPEG_BINARY_DIR ${FFMPEG_ROOT_DIR}/bin)
    endif()

elseif (${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set_package_properties("${CMAKE_FIND_PACKAGE_NAME}" 
                            PROPERTIES 
                                URL "https://www.ffmpeg.org/"
                                DESCRIPTION "Audio and video codecs")
    
    # Determine Linux target architecture
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
        set(FFMPEG_TARGET "linux64")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
        set(FFMPEG_TARGET "linuxarm64")
    else()
        message(FATAL_ERROR "Unsupported Linux architecture: ${CMAKE_SYSTEM_PROCESSOR}")
    endif()
    
    # Set build variant (can be overridden by user)
    if(NOT DEFINED FFMPEG_VARIANT)
        set(FFMPEG_VARIANT "gpl" CACHE STRING "FFmpeg build variant (gpl, lgpl, nonfree, gpl-shared, lgpl-shared, nonfree-shared)")
    endif()
    
    # Set FFmpeg version (can be overridden by user)
    if(NOT DEFINED FFMPEG_VERSION)
        set(FFMPEG_VERSION "5.1" CACHE STRING "FFmpeg version (4.4, 5.0, 5.1, 6.0, 6.1, 7.0, 7.1, or empty for master)")
    endif()
    
    # Determine archive name based on version
    if(FFMPEG_VERSION STREQUAL "")
        set(FFMPEG_ARCHIVE_NAME "ffmpeg-master-latest-${FFMPEG_TARGET}-${FFMPEG_VARIANT}")
    else()
        set(FFMPEG_ARCHIVE_NAME "ffmpeg-${FFMPEG_VERSION}-${FFMPEG_TARGET}-${FFMPEG_VARIANT}")
    endif()
    
    FetchContent_Declare(ffmpeg_builds
                          GIT_REPOSITORY "https://github.com/BtbN/FFmpeg-Builds.git"
                          GIT_TAG "master")
    
    FetchContent_GetProperties(ffmpeg_builds)
    if(NOT ffmpeg_builds_POPULATED)
        FetchContent_Populate(ffmpeg_builds)
        
        # Build FFmpeg using the provided build.sh script with version
        ExternalProject_Add(ffmpeg_build
            SOURCE_DIR ${ffmpeg_builds_SOURCE_DIR}
            CONFIGURE_COMMAND ""
            BUILD_COMMAND bash ${ffmpeg_builds_SOURCE_DIR}/build.sh ${FFMPEG_TARGET} ${FFMPEG_VARIANT} ${FFMPEG_VERSION}
            BUILD_IN_SOURCE 1
            INSTALL_COMMAND ""
            BUILD_BYPRODUCTS ${ffmpeg_builds_SOURCE_DIR}/artifacts/${FFMPEG_ARCHIVE_NAME}.tar.xz
        )
        
        # Extract the built FFmpeg
        ExternalProject_Add_Step(ffmpeg_build extract_ffmpeg
            COMMAND ${CMAKE_COMMAND} -E tar xf ${ffmpeg_builds_SOURCE_DIR}/artifacts/${FFMPEG_ARCHIVE_NAME}.tar.xz
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            DEPENDEES build
        )
        
        # Set FFmpeg paths
        set(FFMPEG_ROOT_DIR ${CMAKE_CURRENT_BINARY_DIR}/${FFMPEG_ARCHIVE_NAME})
        set(FFMPEG_INCLUDE_DIRS ${FFMPEG_ROOT_DIR}/include)
        set(FFMPEG_LIBRARY_DIRS ${FFMPEG_ROOT_DIR}/lib)
        set(FFMPEG_BINARY_DIR ${FFMPEG_ROOT_DIR}/bin)
    endif()

endif()

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    FetchContent_MakeAvailable(ffmpeg)

    find_package_message("${CMAKE_FIND_PACKAGE_NAME}" 
                          "ffmpeg package found -- Sources downloaded"
                          "ffmpeg (GitHub)")

    set(${CMAKE_FIND_PACKAGE_NAME}_FOUND TRUE)

else()
    # For Windows and Linux, create imported targets for FFmpeg libraries
    if(TARGET ffmpeg_build)
        # Create imported targets for the main FFmpeg libraries
        set(FFMPEG_LIBRARIES avcodec avformat avutil swscale swresample avfilter avdevice)
        
        foreach(lib ${FFMPEG_LIBRARIES})
            if(NOT TARGET ffmpeg::${lib})
                add_library(ffmpeg::${lib} STATIC IMPORTED)
                add_dependencies(ffmpeg::${lib} ffmpeg_build)
                set_target_properties(ffmpeg::${lib} PROPERTIES
                    IMPORTED_LOCATION ${FFMPEG_LIBRARY_DIRS}/lib${lib}.a
                    INTERFACE_INCLUDE_DIRECTORIES ${FFMPEG_INCLUDE_DIRS}
                )
            endif()
        endforeach()
        
        # Create a combined ffmpeg::ffmpeg target
        if(NOT TARGET ffmpeg::ffmpeg)
            add_library(ffmpeg::ffmpeg INTERFACE IMPORTED)
            set_target_properties(ffmpeg::ffmpeg PROPERTIES
                INTERFACE_INCLUDE_DIRECTORIES ${FFMPEG_INCLUDE_DIRS}
                INTERFACE_LINK_DIRECTORIES ${FFMPEG_LIBRARY_DIRS}
            )
            
            # Link all FFmpeg libraries
            foreach(lib ${FFMPEG_LIBRARIES})
                target_link_libraries(ffmpeg::ffmpeg INTERFACE ffmpeg::${lib})
            endforeach()
            
            # Add system libraries that FFmpeg depends on
            if(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
                target_link_libraries(ffmpeg::ffmpeg INTERFACE 
                    ws2_32 winmm ole32 strmiids uuid secur32 bcrypt mfplat mfuuid)
            elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
                target_link_libraries(ffmpeg::ffmpeg INTERFACE 
                    pthread m dl z)
            endif()
        endif()
        
        find_package_message("${CMAKE_FIND_PACKAGE_NAME}" 
                              "ffmpeg package found -- Built from BtbN/FFmpeg-Builds"
                              "ffmpeg (${FFMPEG_TARGET}/${FFMPEG_VARIANT}/${FFMPEG_VERSION})")
        
        set(${CMAKE_FIND_PACKAGE_NAME}_FOUND TRUE)
    endif()

endif()