cmake_minimum_required(VERSION 3.22)
project(qr_scanner LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Release)
endif()

option(QR_BUILD_BENCH "Build the qr_bench reliability benchmark" OFF)
option(QR_BUILD_EXTENSION "Build the Godot extension" ON)

include(FetchContent)

# Readers only: the extension never encodes. The benchmark needs the old writer.
if(QR_BUILD_BENCH)
	set(ZXING_WRITERS "OLD" CACHE STRING "" FORCE)
else()
	set(ZXING_WRITERS "OFF" CACHE STRING "" FORCE)
endif()
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(ZXING_READERS ON CACHE BOOL "" FORCE)
set(ZXING_C_API OFF CACHE BOOL "" FORCE)
set(ZXING_EXAMPLES OFF CACHE BOOL "" FORCE)
set(ZXING_UNIT_TESTS OFF CACHE BOOL "" FORCE)
set(ZXING_BLACKBOX_TESTS OFF CACHE BOOL "" FORCE)
set(ZXING_DEPENDENCIES "LOCAL" CACHE STRING "" FORCE)

FetchContent_Declare(zxing
	GIT_REPOSITORY https://github.com/zxing-cpp/zxing-cpp.git
	GIT_TAG 287c85df6f961c8efbfb5ffd736cd9457b8b890e # v3.1.1
	GIT_SHALLOW FALSE
)
FetchContent_MakeAvailable(zxing)

add_library(qr_core STATIC src/qr_core.cpp)
target_link_libraries(qr_core PUBLIC ZXing::ZXing)

if(QR_BUILD_BENCH)
	add_executable(qr_bench tools/qr_bench.cpp)
	target_link_libraries(qr_bench PRIVATE qr_core)
endif()

if(QR_BUILD_EXTENSION)
	set(GODOTCPP_TARGET "template_release" CACHE STRING "" FORCE)
	set(GODOTCPP_BUILD_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/build_profile.json" CACHE PATH "" FORCE)
	FetchContent_Declare(godot-cpp
		GIT_REPOSITORY https://github.com/godotengine/godot-cpp.git
		GIT_TAG e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77 # godot-4.5-stable; extensions stay loadable by newer engines
		GIT_SHALLOW FALSE
	)
	FetchContent_MakeAvailable(godot-cpp)

	add_library(qr_scanner SHARED src/qr_decoder.cpp src/register_types.cpp src/android_camera.cpp)
	target_link_libraries(qr_scanner PRIVATE qr_core godot::cpp)
	set_target_properties(qr_scanner PROPERTIES
		CXX_VISIBILITY_PRESET hidden
		VISIBILITY_INLINES_HIDDEN ON
		PREFIX "lib"
		OUTPUT_NAME "qr_scanner.${QR_PLATFORM_TAG}"
		LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../addons/qr_scanner/bin"
	)
	if(ANDROID)
		target_link_libraries(qr_scanner PRIVATE log camera2ndk mediandk)
		target_link_options(qr_scanner PRIVATE -Wl,-z,max-page-size=16384)
	endif()
	if(UNIX AND NOT APPLE)
		target_link_options(qr_scanner PRIVATE -Wl,--exclude-libs,ALL -s)
	endif()
endif()
