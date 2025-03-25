# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "photo_gallery_pro")
project(${PROJECT_NAME} LANGUAGES CXX)

# Define standard settings function
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_14)
  target_compile_options(${TARGET} PRIVATE -Wall -Werror)
  target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
  target_compile_definitions(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:NDEBUG>")
endfunction()

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
pkg_check_modules(GDK_PIXBUF REQUIRED IMPORTED_TARGET gdk-pixbuf-2.0)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "photo_gallery_pro_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "photo_gallery_pro_plugin.cc"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Configure Flutter Linux dependencies
if(DEFINED ENV{FLUTTER_ROOT})
  set(FLUTTER_ROOT $ENV{FLUTTER_ROOT})
  set(FLUTTER_LINUX_INCLUDE_PATH "${FLUTTER_ROOT}/bin/cache/artifacts/engine/linux-x64/include")
  set(FLUTTER_LINUX_LIB_PATH "${FLUTTER_ROOT}/bin/cache/artifacts/engine/linux-x64")
else()
  message(FATAL_ERROR "Flutter SDK not found. Please set FLUTTER_ROOT environment variable.")
endif()

# Ensure Flutter Linux headers are available
execute_process(
  COMMAND "${FLUTTER_ROOT}/bin/flutter" assemble --no-version-check
    -dTargetPlatform=linux-x64
    -dBuildMode=debug
    --output-directory="${CMAKE_BINARY_DIR}/flutter"
    linux-x64
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)

# Add Flutter Linux include paths
list(APPEND FLUTTER_LINUX_INCLUDE_DIRS
  "${FLUTTER_LINUX_INCLUDE_PATH}"
  "${CMAKE_BINARY_DIR}/flutter/flutter_linux"
  "${CMAKE_BINARY_DIR}/flutter/ephemeral"
)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
  "${FLUTTER_LINUX_INCLUDE_PATH}")

target_link_libraries(${PLUGIN_NAME} PRIVATE 
  PkgConfig::GTK 
  PkgConfig::GDK_PIXBUF
  flutter-engine)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(photo_gallery_pro_bundled_libraries
  ""
  PARENT_SCOPE
)

# === Tests ===
if(${include_${PROJECT_NAME}_tests})
  if(${CMAKE_VERSION} VERSION_LESS "3.11.0")
    message("Unit tests require CMake 3.11.0 or later")
  else()
    set(TEST_RUNNER "${PROJECT_NAME}_test")
    enable_testing()

    # Add the Google Test dependency
    include(FetchContent)
    FetchContent_Declare(
      googletest
      URL https://github.com/google/googletest/archive/release-1.11.0.zip
    )
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
    FetchContent_MakeAvailable(googletest)

    # Configure test executable
    add_executable(${TEST_RUNNER}
      test/photo_gallery_pro_plugin_test.cc
      ${PLUGIN_SOURCES}
    )
    apply_standard_settings(${TEST_RUNNER})

    # Add include directories
    target_include_directories(${TEST_RUNNER} PRIVATE
      "${CMAKE_CURRENT_SOURCE_DIR}"
      "${CMAKE_CURRENT_SOURCE_DIR}/include"
      "${CMAKE_BINARY_DIR}/googletest-src/googletest/include"
      "${CMAKE_BINARY_DIR}/googletest-src/googlemock/include"
      ${FLUTTER_LINUX_INCLUDE_DIRS}
    )

    # Link libraries
    target_link_libraries(${TEST_RUNNER} PRIVATE 
      ${PLUGIN_NAME}
      PkgConfig::GTK 
      PkgConfig::GDK_PIXBUF 
      "${FLUTTER_LINUX_LIB_PATH}/libflutter_linux_gtk.so"
      gtest_main 
      gmock
    )

    # Enable test discovery
    include(GoogleTest)
    gtest_discover_tests(${TEST_RUNNER})
  endif()
endif()