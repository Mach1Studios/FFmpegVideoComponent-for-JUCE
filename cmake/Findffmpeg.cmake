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

# Prevent CMake from automatically detecting and overriding our versions
set(CMAKE_FIND_PACKAGE_QUIET TRUE)

# Set target FFmpeg version explicitly
set(ffmpeg_VERSION_MAJOR 5)
set(ffmpeg_VERSION_MINOR 1)  
set(ffmpeg_VERSION_PATCH 6)
set(ffmpeg_VERSION "${ffmpeg_VERSION_MAJOR}.${ffmpeg_VERSION_MINOR}.${ffmpeg_VERSION_PATCH}")

# Clear any cached version variables to prevent confusion
unset(ffmpeg_VERSION CACHE)
unset(ffmpeg_VERSION_MAJOR CACHE)  
unset(ffmpeg_VERSION_MINOR CACHE)
unset(ffmpeg_VERSION_PATCH CACHE)

# Platform-specific configurations
if(WIN32)
    set(FFMPEG_URL "https://github.com/BtbN/FFmpeg-Builds.git")
    set(FFMPEG_EXTRACT_DIR "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-extract")
    set(FFMPEG_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/FFmpeg-Builds")
    
    # Check if we need to build from source
    set(BUILDING_FROM_SOURCE FALSE)
    
    # Check if FFmpeg is already built
    if(NOT EXISTS "${FFMPEG_EXTRACT_DIR}/bin/ffmpeg.exe")
        set(BUILDING_FROM_SOURCE TRUE)
        
        # Build FFmpeg 5.1 from source using BtbN/FFmpeg-Builds
        find_program(DOCKER_EXECUTABLE docker REQUIRED)
        find_program(BASH_EXECUTABLE bash REQUIRED)
        
        if(DOCKER_EXECUTABLE AND BASH_EXECUTABLE)
            message(STATUS "Building FFmpeg 5.1 from source using Docker...")
            
            # Custom target to build FFmpeg
            add_custom_target(extract_ffmpeg
                COMMENT "Building FFmpeg 5.1 from source..."
                COMMAND ${CMAKE_COMMAND} -E remove_directory "${FFMPEG_BUILD_DIR}"
                COMMAND ${CMAKE_COMMAND} -E remove_directory "${FFMPEG_EXTRACT_DIR}"
                COMMAND git clone --depth 1 "${FFMPEG_URL}" "${FFMPEG_BUILD_DIR}"
                COMMAND ${BASH_EXECUTABLE} -c "cd '${FFMPEG_BUILD_DIR}' && ./build.sh win64 gpl 5.1"
                COMMAND ${CMAKE_COMMAND} -E make_directory "${FFMPEG_EXTRACT_DIR}"
                COMMAND powershell -Command "Get-ChildItem -Path '${FFMPEG_BUILD_DIR}/artifacts' -Filter 'ffmpeg-*-win64-gpl-*.zip' | ForEach-Object { Expand-Archive -Path $_.FullName -DestinationPath '${FFMPEG_BUILD_DIR}/artifacts/temp' -Force }"
                COMMAND powershell -Command "Get-ChildItem -Path '${FFMPEG_BUILD_DIR}/artifacts/temp' -Directory | ForEach-Object { Copy-Item -Path (Join-Path $_.FullName '*') -Destination '${FFMPEG_EXTRACT_DIR}' -Recurse -Force }"
                WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
            )
        else()
            message(FATAL_ERROR "Docker and bash are required to build FFmpeg from source")
        endif()
    endif()
    
    # Set FFmpeg paths
    set(FFMPEG_ROOT "${FFMPEG_EXTRACT_DIR}")
    
    # Define the components we need
    set(FFMPEG_COMPONENTS avcodec avfilter avformat avdevice avutil swresample swscale)
    
    # Create imported targets for each component  
    foreach(component IN LISTS FFMPEG_COMPONENTS)
        if(NOT TARGET ffmpeg::${component})
            add_library(ffmpeg::${component} SHARED IMPORTED)
            
            # Set the DLL and import library paths
            set_target_properties(ffmpeg::${component} PROPERTIES
                IMPORTED_LOCATION "${FFMPEG_ROOT}/bin/${component}.dll"
                IMPORTED_IMPLIB "${FFMPEG_ROOT}/lib/${component}.dll.a"
                INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_ROOT}/include"
            )
            
            # Add dependency on extract_ffmpeg if building from source
            if(BUILDING_FROM_SOURCE)
                add_dependencies(ffmpeg::${component} extract_ffmpeg)
            endif()
        endif()
    endforeach()
    
    # Create convenience target
    if(NOT TARGET ffmpeg::ffmpeg)
        add_library(ffmpeg::ffmpeg INTERFACE IMPORTED)
        
        # Build the component targets list
        set(ffmpeg_components_targets "")
        foreach(component IN LISTS FFMPEG_COMPONENTS)
            if(TARGET ffmpeg::${component})
                list(APPEND ffmpeg_components_targets ffmpeg::${component})
            endif()
        endforeach()
        
        set_target_properties(ffmpeg::ffmpeg PROPERTIES
            INTERFACE_LINK_LIBRARIES "${ffmpeg_components_targets}"
        )
        
        if(BUILDING_FROM_SOURCE)
            add_dependencies(ffmpeg::ffmpeg extract_ffmpeg)
        endif()
    endif()
    
    # Set component variables
    foreach(component IN LISTS FFMPEG_COMPONENTS)
        string(TOUPPER ${component} component_upper)
        set(ffmpeg_${component}_FOUND TRUE)
        set(PC_ffmpeg_${component_upper}_VERSION "${ffmpeg_VERSION}")
    endforeach()
    
elseif(UNIX AND NOT APPLE)
    # Linux configuration
    set(FFMPEG_URL "https://github.com/BtbN/FFmpeg-Builds.git")
    set(FFMPEG_EXTRACT_DIR "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-extract")
    set(FFMPEG_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/FFmpeg-Builds")
    
    set(BUILDING_FROM_SOURCE FALSE)
    
    if(NOT EXISTS "${FFMPEG_EXTRACT_DIR}/lib/libavcodec.a")
        set(BUILDING_FROM_SOURCE TRUE)
        
        find_program(DOCKER_EXECUTABLE docker REQUIRED)
        find_program(BASH_EXECUTABLE bash REQUIRED)
        
        if(DOCKER_EXECUTABLE AND BASH_EXECUTABLE)
            message(STATUS "Building FFmpeg 5.1 from source using Docker...")
            
            add_custom_target(extract_ffmpeg
                COMMENT "Building FFmpeg 5.1 from source..."
                COMMAND ${CMAKE_COMMAND} -E remove_directory "${FFMPEG_BUILD_DIR}"
                COMMAND ${CMAKE_COMMAND} -E remove_directory "${FFMPEG_EXTRACT_DIR}"
                COMMAND git clone --depth 1 "${FFMPEG_URL}" "${FFMPEG_BUILD_DIR}"
                COMMAND ${BASH_EXECUTABLE} -c "cd '${FFMPEG_BUILD_DIR}' && ./build.sh linux64 gpl 5.1"
                COMMAND ${CMAKE_COMMAND} -E make_directory "${FFMPEG_EXTRACT_DIR}"
                COMMAND ${BASH_EXECUTABLE} -c "cd '${FFMPEG_BUILD_DIR}/artifacts' && tar -xJf ffmpeg-*-linux64-gpl-*.tar.xz --strip-components=1 -C '${FFMPEG_EXTRACT_DIR}'"
                WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
            )
        endif()
    endif()
    
    set(FFMPEG_ROOT "${FFMPEG_EXTRACT_DIR}")
    set(FFMPEG_COMPONENTS avcodec avfilter avformat avdevice avutil swresample swscale)
    
    # Create static library targets for Linux
    foreach(component IN LISTS FFMPEG_COMPONENTS)
        if(NOT TARGET ffmpeg::${component})
            add_library(ffmpeg::${component} STATIC IMPORTED)
            set_target_properties(ffmpeg::${component} PROPERTIES
                IMPORTED_LOCATION "${FFMPEG_ROOT}/lib/lib${component}.a"
                INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_ROOT}/include"
            )
            
            if(BUILDING_FROM_SOURCE)
                add_dependencies(ffmpeg::${component} extract_ffmpeg)
            endif()
        endif()
    endforeach()
    
    if(NOT TARGET ffmpeg::ffmpeg)
        add_library(ffmpeg::ffmpeg INTERFACE IMPORTED)
        
        # Build the component targets list
        set(ffmpeg_components_targets "")
        foreach(component IN LISTS FFMPEG_COMPONENTS)
            if(TARGET ffmpeg::${component})
                list(APPEND ffmpeg_components_targets ffmpeg::${component})
            endif()
        endforeach()
        
        set_target_properties(ffmpeg::ffmpeg PROPERTIES
            INTERFACE_LINK_LIBRARIES "${ffmpeg_components_targets}"
        )
        
        if(BUILDING_FROM_SOURCE)
            add_dependencies(ffmpeg::ffmpeg extract_ffmpeg)  
        endif()
    endif()
    
    foreach(component IN LISTS FFMPEG_COMPONENTS)
        string(TOUPPER ${component} component_upper)
        set(ffmpeg_${component}_FOUND TRUE)  
        set(PC_ffmpeg_${component_upper}_VERSION "${ffmpeg_VERSION}")
    endforeach()
    
else()
    # macOS - try to find system FFmpeg or use Homebrew
    find_package(PkgConfig QUIET)
    
    if(PkgConfig_FOUND)
        set(FFMPEG_COMPONENTS avcodec avfilter avformat avdevice avutil swresample swscale)
        
        foreach(component IN LISTS FFMPEG_COMPONENTS)
            pkg_check_modules(PC_ffmpeg_${component} lib${component})
            
            if(PC_ffmpeg_${component}_FOUND)
                if(NOT TARGET ffmpeg::${component})
                    add_library(ffmpeg::${component} INTERFACE IMPORTED)
                    set_target_properties(ffmpeg::${component} PROPERTIES
                        INTERFACE_INCLUDE_DIRECTORIES "${PC_ffmpeg_${component}_INCLUDE_DIRS}"
                        INTERFACE_LINK_LIBRARIES "${PC_ffmpeg_${component}_LINK_LIBRARIES}"
                        INTERFACE_LINK_DIRECTORIES "${PC_ffmpeg_${component}_LIBRARY_DIRS}"
                        INTERFACE_COMPILE_OPTIONS "${PC_ffmpeg_${component}_CFLAGS_OTHER}"
                    )
                endif()
                set(ffmpeg_${component}_FOUND TRUE)
            endif()
        endforeach()
        
        if(NOT TARGET ffmpeg::ffmpeg)
            add_library(ffmpeg::ffmpeg INTERFACE IMPORTED)
            set(ffmpeg_components_targets "")
            foreach(component IN LISTS FFMPEG_COMPONENTS)
                if(TARGET ffmpeg::${component})
                    list(APPEND ffmpeg_components_targets ffmpeg::${component})
                endif()
            endforeach()
            if(ffmpeg_components_targets)
                set_target_properties(ffmpeg::ffmpeg PROPERTIES
                    INTERFACE_LINK_LIBRARIES "${ffmpeg_components_targets}"
                )
            endif()
        endif()
    endif()
endif()

# Final component checking
set(FFMPEG_COMPONENTS avcodec avfilter avformat avdevice avutil swresample swscale) 
foreach(component IN LISTS FFMPEG_COMPONENTS)
    if(TARGET ffmpeg::${component})
        set(ffmpeg_${component}_FOUND TRUE)
    endif()
endforeach()

# Generate component list for find_package_handle_standard_args
set(ffmpeg_components_list "")
foreach(component IN LISTS FFMPEG_COMPONENTS)
    if(ffmpeg_${component}_FOUND)
        list(APPEND ffmpeg_components_list ${component})
    endif()
endforeach()

# Custom status messages instead of standard CMake detection
if(BUILDING_FROM_SOURCE)
    message(STATUS "Found ffmpeg: Building 5.1.6 from source (found components: ${ffmpeg_components_list})")
else()
    # Use standard find_package_handle_standard_args for system installs
    include(FindPackageHandleStandardArgs)
    find_package_handle_standard_args(ffmpeg
        FOUND_VAR ffmpeg_FOUND
        REQUIRED_VARS ffmpeg_components_list
        VERSION_VAR ffmpeg_VERSION
        HANDLE_COMPONENTS
    )
endif()

# Ensure we have the components we need
set(ffmpeg_FOUND TRUE)
foreach(component IN LISTS FFMPEG_COMPONENTS)
    if(NOT ffmpeg_${component}_FOUND)
        set(ffmpeg_FOUND FALSE)
        break()
    endif()
endforeach()