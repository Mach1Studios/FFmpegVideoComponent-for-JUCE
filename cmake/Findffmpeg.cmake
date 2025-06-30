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
    
    # Build FFmpeg 5.1 from source using BtbN/FFmpeg-Builds
    message(STATUS "Building FFmpeg 5.1 from source for Windows...")
    
    # Check for required tools (Docker and bash)
    find_program(DOCKER_EXECUTABLE docker)
    find_program(BASH_EXECUTABLE bash)
    
    if(NOT DOCKER_EXECUTABLE OR NOT BASH_EXECUTABLE)
        message(WARNING "Docker and/or bash not found. Falling back to pre-built binaries.")
        message(STATUS "Please install Docker Desktop and ensure bash is available (e.g., via Git Bash, WSL, or MSYS2)")
        
        # Fallback to pre-built binaries
        set(BUILT_ffmpeg_RELEASE "ffmpeg-master-latest-win64-gpl-shared.zip")
        
        if (NOT "${PROJECT_BINARY_DIR}/_deps/ffmpeg-build" IN_LIST "${CMAKE_PREFIX_PATH}")
            list(APPEND CMAKE_PREFIX_PATH "${PROJECT_BINARY_DIR}/_deps/ffmpeg-build")
        endif()
        message(STATUS "ffmpeg download path: ${PROJECT_BINARY_DIR}/_deps/ffmpeg-build")

        FetchContent_Declare(ffmpeg
            URL  "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/${BUILT_ffmpeg_RELEASE}"
            SOURCE_DIR "${PROJECT_BINARY_DIR}/_deps/ffmpeg-build"  
        )
    else()
        # Build from source using BtbN/FFmpeg-Builds
        message(STATUS "Docker and bash found. Building FFmpeg 5.1 from source...")
        
        # Set up build directory
        set(FFMPEG_BUILD_DIR "${PROJECT_BINARY_DIR}/_deps/ffmpeg-builds")
        set(FFMPEG_OUTPUT_DIR "${PROJECT_BINARY_DIR}/_deps/ffmpeg-build")
        
        if (NOT "${FFMPEG_OUTPUT_DIR}" IN_LIST "${CMAKE_PREFIX_PATH}")
            list(APPEND CMAKE_PREFIX_PATH "${FFMPEG_OUTPUT_DIR}")
        endif()
        
        # Clone the BtbN/FFmpeg-Builds repository
        FetchContent_Declare(ffmpeg_builds
            GIT_REPOSITORY "https://github.com/BtbN/FFmpeg-Builds.git"
            GIT_TAG "master"
            SOURCE_DIR "${FFMPEG_BUILD_DIR}"
            CONFIGURE_COMMAND ""
            BUILD_COMMAND ""
        )
        
        FetchContent_MakeAvailable(ffmpeg_builds)
        
        # Custom target to build FFmpeg 5.1
        add_custom_target(build_ffmpeg
            COMMAND ${BASH_EXECUTABLE} -c "cd ${FFMPEG_BUILD_DIR} && ./build.sh win64 gpl 5.1"
            WORKING_DIRECTORY ${FFMPEG_BUILD_DIR}
            COMMENT "Building FFmpeg 5.1 for Windows x64 with GPL..."
        )
        
        # Extract the built artifacts
        add_custom_target(extract_ffmpeg
            COMMAND ${CMAKE_COMMAND} -E make_directory ${FFMPEG_OUTPUT_DIR}
            COMMAND ${CMAKE_COMMAND} -E chdir ${FFMPEG_BUILD_DIR}/artifacts 
                ${CMAKE_COMMAND} -E tar xf ffmpeg-5.1-win64-gpl.zip
            COMMAND ${CMAKE_COMMAND} -E copy_directory 
                ${FFMPEG_BUILD_DIR}/artifacts/ffmpeg-5.1-win64-gpl 
                ${FFMPEG_OUTPUT_DIR}
            DEPENDS build_ffmpeg
            COMMENT "Extracting FFmpeg build artifacts..."
        )
        
        # Create a dummy target for FetchContent compatibility
        add_custom_target(ffmpeg_dummy DEPENDS extract_ffmpeg)
        
        # Set ffmpeg as built
        set(ffmpeg_POPULATED TRUE)
        set(ffmpeg_SOURCE_DIR ${FFMPEG_BUILD_DIR})
        set(ffmpeg_BINARY_DIR ${FFMPEG_OUTPUT_DIR})
    endif()

elseif (${CMAKE_SYSTEM_NAME} STREQUAL "Linux")

    # TODO: Use the FFMPEGBUILD concept for mac here too
    
    if(${CMAKE_SYSTEM_PROCESSOR} STREQUAL "x86_64" OR ${CMAKE_SYSTEM_PROCESSOR} STREQUAL "amd64")
        set(BUILT_ffmpeg_RELEASE "ffmpeg-master-latest-linux64-gpl.tar.xz")
    elseif(${CMAKE_SYSTEM_PROCESSOR} STREQUAL aarch64)
        set(BUILT_ffmpeg_RELEASE "ffmpeg-master-latest-linuxarm64-gpl.tar.xz")
    endif()

    if(NOT BUILT_ffmpeg_RELEASE)
        message(FATAL_ERROR "Platform ${CMAKE_SYSTEM_PROCESSOR} on system ${CMAKE_SYSTEM_NAME} is not supported!")
    endif()

    if (NOT "${PROJECT_BINARY_DIR}/_deps/ffmpeg-build" IN_LIST "${CMAKE_PREFIX_PATH}")
        list(APPEND CMAKE_PREFIX_PATH "${PROJECT_BINARY_DIR}/_deps/ffmpeg-build")
    endif()

    FetchContent_Declare(ffmpeg
        URL  "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/${BUILT_ffmpeg_RELEASE}"
        SOURCE_DIR "${PROJECT_BINARY_DIR}/_deps/ffmpeg-build"  
    )

endif()

# Handle FetchContent_MakeAvailable for different cases
if(${CMAKE_SYSTEM_NAME} STREQUAL "Windows" AND ${CMAKE_SYSTEM_PROCESSOR} STREQUAL "AMD64")
    # For Windows, we handle this conditionally above
    if(NOT DOCKER_EXECUTABLE OR NOT BASH_EXECUTABLE)
        FetchContent_MakeAvailable(ffmpeg)
    endif()
    # For source builds, dependencies are handled by custom targets
else()
    FetchContent_MakeAvailable(ffmpeg)
endif()

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")

    find_package_message("${CMAKE_FIND_PACKAGE_NAME}" 
                          "ffmpeg package found -- Sources downloaded"
                          "ffmpeg (GitHub)")

    set(${CMAKE_FIND_PACKAGE_NAME}_FOUND TRUE)

else()

    # Check if we're building from source on Windows
    set(BUILDING_FROM_SOURCE FALSE)
    if(${CMAKE_SYSTEM_NAME} STREQUAL "Windows" AND ${CMAKE_SYSTEM_PROCESSOR} STREQUAL "AMD64" AND DOCKER_EXECUTABLE AND BASH_EXECUTABLE)
        set(BUILDING_FROM_SOURCE TRUE)
        
        # Clear any cached version variables that might interfere
        unset(ffmpeg_VERSION CACHE)
        unset(ffmpeg_VERSION_STRING CACHE)
        unset(FFMPEG_VERSION CACHE)
        unset(FFMPEG_VERSION_STRING CACHE)
        
        # Set our specific version
        set(ffmpeg_VERSION "5.1.6")
        set(ffmpeg_VERSION_STRING "5.1.6")
        set(ffmpeg_VERSION_MAJOR "5")
        set(ffmpeg_VERSION_MINOR "1")
        set(ffmpeg_VERSION_PATCH "6")
        
        message(STATUS "ffmpeg package will be built from source (5.1) - BtbN/FFmpeg-Builds")
    endif()

    macro(find_component _component _header)
        if(BUILDING_FROM_SOURCE)
            # For source builds, we know the structure and create targets that will be available after build
            set(${_component}_INCLUDE_DIRS "${PROJECT_BINARY_DIR}/_deps/ffmpeg-build/include")
            if (${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
                set(${_component}_LIBRARY "${PROJECT_BINARY_DIR}/_deps/ffmpeg-build/lib/lib${_component}.dll.a")
            else()
                set(${_component}_LIBRARY "${PROJECT_BINARY_DIR}/_deps/ffmpeg-build/lib/lib${_component}.a")
            endif()
            
            set(ffmpeg_${_component}_FOUND TRUE)
            set(ffmpeg_LINK_LIBRARIES ${ffmpeg_LINK_LIBRARIES} "${${_component}_LIBRARY}")
            list(APPEND ffmpeg_INCLUDE_DIRS ${${_component}_INCLUDE_DIRS}) 

            if (NOT TARGET ffmpeg::${_component})
                if (${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
                    # Windows builds from BtbN are shared libraries
                    add_library(ffmpeg_${_component} SHARED IMPORTED)
                    set_target_properties(ffmpeg_${_component} PROPERTIES
                        INTERFACE_INCLUDE_DIRECTORIES "${${_component}_INCLUDE_DIRS}"
                        IMPORTED_IMPLIB "${${_component}_LIBRARY}"
                    )
                else()
                    # Linux builds are static
                    add_library(ffmpeg_${_component} STATIC IMPORTED)
                    set_target_properties(ffmpeg_${_component} PROPERTIES
                        INTERFACE_INCLUDE_DIRECTORIES "${${_component}_INCLUDE_DIRS}"
                        IMPORTED_LOCATION "${${_component}_LIBRARY}"
                    )
                endif()
                add_library(ffmpeg::${_component} ALIAS ffmpeg_${_component})
                
                # Add dependency on the extraction target if building from source
                if(TARGET extract_ffmpeg)
                    add_dependencies(ffmpeg_${_component} extract_ffmpeg)
                endif()
            endif()
        else()
            # Normal find logic for pre-built binaries
            find_path(${_component}_INCLUDE_DIRS "${_header}" PATH_SUFFIXES ffmpeg)
            
            if (${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
                set(CMAKE_FIND_LIBRARY_PREFIXES "lib")
                set(CMAKE_FIND_LIBRARY_SUFFIXES ".dll.a")
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
    if(BUILDING_FROM_SOURCE)
        # For source builds, bypass standard version detection completely
        set(ffmpeg_FOUND TRUE)
        message(STATUS "Found ffmpeg components: ${ffmpeg_FIND_COMPONENTS}")
        message(STATUS "ffmpeg version: ${ffmpeg_VERSION_STRING} (building from source)")
    else()
        find_package_handle_standard_args(ffmpeg REQUIRED_VARS ffmpeg_COMPONENTS_COUNT HANDLE_COMPONENTS)
    endif()

    # Publish targets if succeeded to find the ffmpeg package and the requested components
    if (ffmpeg_FOUND AND NOT TARGET ffmpeg::ffmpeg)
        add_library(ffmpeg INTERFACE)
        set_target_properties(ffmpeg PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${ffmpeg_INCLUDE_DIRS}"
            INTERFACE_LINK_LIBRARIES "${ffmpeg_LINK_LIBRARIES}"
        )
        add_library(ffmpeg::ffmpeg ALIAS ffmpeg)
        
        # Add build dependency if building from source
        if(BUILDING_FROM_SOURCE AND TARGET extract_ffmpeg)
            add_dependencies(ffmpeg extract_ffmpeg)
        endif()
    endif()
    


endif()