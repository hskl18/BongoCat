cmake_minimum_required(VERSION 3.20)

project(BongoCubism LANGUAGES C CXX OBJC OBJCXX)

if(NOT CUBISM_SDK_ROOT)
  message(FATAL_ERROR "Set CUBISM_SDK_ROOT to CubismSdkForNative-5-r.5")
endif()

if(NOT CUBISM_BUILD_ROOT)
  message(FATAL_ERROR "Set CUBISM_BUILD_ROOT to the generated runtime directory")
endif()

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_OSX_DEPLOYMENT_TARGET 26.0)

add_library(Live2DCubismCore STATIC IMPORTED GLOBAL)
set_target_properties(Live2DCubismCore PROPERTIES
  IMPORTED_LOCATION "${CUBISM_BUILD_ROOT}/lib/libLive2DCubismCore.a"
  INTERFACE_INCLUDE_DIRECTORIES "${CUBISM_SDK_ROOT}/Core/include"
)

set(FRAMEWORK_SOURCE Metal)
add_subdirectory(
  "${CUBISM_SDK_ROOT}/Framework"
  "${CMAKE_CURRENT_BINARY_DIR}/Framework"
)
target_link_libraries(Framework PUBLIC Live2DCubismCore)

add_library(BongoCubism STATIC BongoCubism.mm)
target_include_directories(BongoCubism PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../Sources/CubismAPI/include"
  "${CUBISM_SDK_ROOT}/Framework/src"
  "${CUBISM_SDK_ROOT}/Core/include"
)
target_compile_options(BongoCubism PRIVATE -fobjc-arc)
target_link_libraries(BongoCubism PUBLIC
  Framework
  Live2DCubismCore
  "-framework AppKit"
  "-framework Foundation"
  "-framework Metal"
  "-framework MetalKit"
  "-framework QuartzCore"
)

set_target_properties(BongoCubism Framework PROPERTIES
  ARCHIVE_OUTPUT_DIRECTORY "${CUBISM_BUILD_ROOT}/lib"
)

include("${CMAKE_CURRENT_SOURCE_DIR}/MetalShaders.cmake")
