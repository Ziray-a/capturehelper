cmake_minimum_required(VERSION 3.10)

if (UNIX AND POLICY CMP0072)
	# In case of both legacy and glvnd OpenGL libraries found. Prefer GLVND
	cmake_policy(SET CMP0072 NEW)
endif()

project(obs-studio)

option(DEBUG_FFMPEG_MUX "Debug FFmpeg muxer subprocess" FALSE)

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

if(WIN32)
	cmake_minimum_required(VERSION 3.16)

	# Check for Win SDK version 10.0.20348 or above
	if(MSVC)
		message(STATUS "Windows API version is ${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION}")
		string(REPLACE "." ";" WINAPI_VER "${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION}")

		list(GET WINAPI_VER 0 WINAPI_VER_MAJOR)
		list(GET WINAPI_VER 1 WINAPI_VER_MINOR)
		list(GET WINAPI_VER 2 WINAPI_VER_BUILD)

		set(WINAPI_COMPATIBLE FALSE)
		if(WINAPI_VER_MAJOR EQUAL 10)
			if (WINAPI_VER_MINOR EQUAL 0)
				if (WINAPI_VER_BUILD GREATER_EQUAL 20348)
					set(WINAPI_COMPATIBLE TRUE)
				endif()
			else()
				set(WINAPI_COMPATIBLE TRUE)
			endif()
		elseif(WINAPI_VER_MAJOR GREATER 10)
			set(WINAPI_COMPATIBLE TRUE)
		endif()

		if(NOT WINAPI_COMPATIBLE)
			message(FATAL_ERROR "OBS requires Windows 10 SDK version 10.0.20348.0 and above to compile.\nPlease download the most recent Windows 10 SDK in order to compile.")
		endif()
	endif()

	if (QTDIR OR DEFINED ENV{QTDIR} OR DEFINED ENV{QTDIR32} OR DEFINED ENV{QTDIR64})
		# Qt path set by user or env var
	else()
		set(QTDIR "" CACHE PATH "Path to Qt (e.g. C:/Qt/5.7/msvc2015_64)")
		message(WARNING "QTDIR variable is missing.  Please set this variable to specify path to Qt (e.g. C:/Qt/5.7/msvc2015_64)")
	endif()
	if (DepsPath OR DEFINED ENV{DepsPath} OR DEFINED ENV{DepsPath32} OR DEFINED ENV{DepsPath64})
		# Dependencies path set by user or env var
	else()
		set(DepsPath "" CACHE PATH "Path to compiled dependencies (e.g. D:/dependencies/win64)")
		message(WARNING "DepsPath variable is missing.  Please set this variable to specify path to compiled dependencies (e.g. D:/dependencies/win64)")
	endif()
endif()

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/Modules/")
set(ENABLE_SCRIPTING TRUE CACHE BOOL "Enables scripting")
set(SCRIPTING_ENABLED OFF CACHE BOOL "Internal global cmake variable" FORCE)

include(ObsHelpers)
include(ObsCpack)
include(GNUInstallDirs)
include(CheckCCompilerFlag)
include(CheckCXXCompilerFlag)

# Must be a string in the format of "x.x.x-rcx"
if(DEFINED RELEASE_CANDIDATE)
	set(OBS_VERSION "${RELEASE_CANDIDATE}")
	string(REPLACE "-rc" "." RC_SPLIT ${RELEASE_CANDIDATE})
	string(REPLACE "." ";" RC_SPLIT ${RC_SPLIT})
	message(WARNING "******************************************************************************\nRelease candidate deteced, OBS_VERSION is now: ${OBS_VERSION}\n******************************************************************************")
	list(GET RC_SPLIT 0 OBS_RELEASE_CANDIDATE_MAJOR)
	list(GET RC_SPLIT 1 OBS_RELEASE_CANDIDATE_MINOR)
	list(GET RC_SPLIT 2 OBS_RELEASE_CANDIDATE_PATCH)
	list(GET RC_SPLIT 3 OBS_RELEASE_CANDIDATE)
else()
	set(OBS_RELEASE_CANDIDATE_MAJOR 0)
	set(OBS_RELEASE_CANDIDATE_MINOR 0)
	set(OBS_RELEASE_CANDIDATE_PATCH 0)
	set(OBS_RELEASE_CANDIDATE 0)
endif()

# Binary Versioning for Windows
if(WIN32)
	string(REPLACE "-" ";" UI_VERSION_SPLIT ${OBS_VERSION})
	list(GET UI_VERSION_SPLIT 0 UI_VERSION)
	string(REPLACE "." ";" UI_VERSION_SEMANTIC ${UI_VERSION})
	list(GET UI_VERSION_SEMANTIC 0 UI_VERSION_MAJOR)
	list(GET UI_VERSION_SEMANTIC 1 UI_VERSION_MINOR)
	list(GET UI_VERSION_SEMANTIC 2 UI_VERSION_PATCH)
	set(OBS_COMPANY_NAME "OBS")
	set(OBS_PRODUCT_NAME "Capturehelper based on OBS Studio")
	set(OBS_COMMENTS "Free and open source software for video recording and live streaming")
	set(OBS_LEGAL_COPYRIGHT "(C) Hugh Bailey")
	set(MODULE_DESCRIPTION "OBS Studio")
	configure_file(UI/obs.rc.in ${PROJECT_BINARY_DIR}/obs.rc)
endif()

if(MSVC AND NOT EXISTS "${CMAKE_BINARY_DIR}/ALL_BUILD.vcxproj.user")
	file(GENERATE
		OUTPUT "${CMAKE_BINARY_DIR}/ALL_BUILD.vcxproj.user"
		INPUT "${CMAKE_SOURCE_DIR}/cmake/ALL_BUILD.vcxproj.user.in")
endif()

if(NOT CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS NO)

if(${CMAKE_C_COMPILER_ID} MATCHES "Clang" OR ${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")
	set(CMAKE_COMPILER_IS_CLANG TRUE)
endif()

if (MSVC_CXX_ARCHITECTURE_ID)
    string(TOLOWER ${MSVC_CXX_ARCHITECTURE_ID} LOWERCASE_CMAKE_SYSTEM_PROCESSOR)
else ()
    string(TOLOWER ${CMAKE_SYSTEM_PROCESSOR} LOWERCASE_CMAKE_SYSTEM_PROCESSOR)
endif ()

if(LOWERCASE_CMAKE_SYSTEM_PROCESSOR MATCHES "(i[3-6]86|x86|x64|x86_64|amd64|e2k)")
	if(NOT MSVC)
		set(ARCH_SIMD_FLAGS "-mmmx" "-msse" "-msse2")
	endif()
elseif(LOWERCASE_CMAKE_SYSTEM_PROCESSOR MATCHES "^(powerpc|ppc)64(le)?")
	set(ARCH_SIMD_DEFINES "-DNO_WARN_X86_INTRINSICS")
	set(ARCH_SIMD_FLAGS "-mvsx")
	add_compile_definitions(NO_WARN_X86_INTRINSICS)
else()
	if(CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_GNUCXX)
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DSIMDE_ENABLE_OPENMP")
		set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DSIMDE_ENABLE_OPENMP")
		CHECK_C_COMPILER_FLAG("-fopenmp-simd" C_COMPILER_SUPPORTS_OPENMP_SIMD)
		if(C_COMPILER_SUPPORTS_OPENMP_SIMD)
			set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fopenmp-simd")
		endif()
		CHECK_CXX_COMPILER_FLAG("-fopenmp-simd" CXX_COMPILER_SUPPORTS_OPENMP_SIMD)
		if(CXX_COMPILER_SUPPORTS_OPENMP_SIMD)
			set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fopenmp-simd")
		endif()
	endif()
	set(ARCH_SIMD_FLAGS "")
	message(STATUS "No Native SSE2 SIMD Support - Using SIMDE")
endif()

if(CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_GNUCXX OR CMAKE_COMPILER_IS_CLANG)
	set(CMAKE_CXX_FLAGS "-Wall -Wextra -Wvla -Wno-unused-function -Wno-missing-field-initializers ${CMAKE_CXX_FLAGS} -fno-strict-aliasing")
	set(CMAKE_C_FLAGS "-Wall -Wextra -Wvla -Wno-unused-function -Werror-implicit-function-declaration -Wno-missing-braces -Wno-missing-field-initializers ${CMAKE_C_FLAGS} -std=gnu99 -fno-strict-aliasing")

	option(USE_LIBC++ "Use libc++ instead of libstdc++" ${APPLE})
	if(USE_LIBC++)
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")
	endif()
elseif(MSVC)
	if(CMAKE_CXX_FLAGS MATCHES "/W[0-4]")
		string(REGEX REPLACE "/W[0-4]" "/W4" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
	else()
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /W4")
	endif()

	# Disable pointless constant condition warnings
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4127 /wd4201 /wd4456 /wd4457 /wd4458 /wd4459 /wd4595")
endif()

if(WIN32)
	add_definitions(-DUNICODE -D_UNICODE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS)
endif()

if(MSVC)
	add_compile_options("/MP")
	set(CMAKE_C_FLAGS_DEBUG "/DDEBUG=1 /D_DEBUG=1 ${CMAKE_C_FLAGS_DEBUG}")
	set(CMAKE_CXX_FLAGS_DEBUG "/DDEBUG=1 /D_DEBUG=1 ${CMAKE_C_FLAGS_DEBUG}")

	# https://gitlab.kitware.com/cmake/cmake/-/issues/20812
	set(CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO} /Ob2")
	set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO} /Ob2")

	if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
		set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /SAFESEH:NO")
		set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /SAFESEH:NO")
		set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} /SAFESEH:NO")
	endif()

	foreach(t EXE SHARED MODULE)
		set(CMAKE_${t}_LINKER_FLAGS "${CMAKE_${t}_LINKER_FLAGS} /OPT:REF")
		set(CMAKE_${t}_LINKER_FLAGS_DEBUG "${CMAKE_${t}_LINKER_FLAGS_DEBUG} /INCREMENTAL:NO")
		set(CMAKE_${t}_LINKER_FLAGS_RELWITHDEBINFO "${CMAKE_${t}_LINKER_FLAGS_RELWITHDEBINFO} /INCREMENTAL:NO /OPT:ICF")
	endforeach()
else()
	if(MINGW)
		set(CMAKE_WIDL "widl" CACHE STRING "wine IDL header file generation program")
		set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_WIN32_WINNT=0x0600 -DWINVER=0x0600")
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_WIN32_WINNT=0x0600 -DWINVER=0x0600")
	endif()
	set(CMAKE_C_FLAGS_DEBUG "-DDEBUG=1 -D_DEBUG=1 ${CMAKE_C_FLAGS_DEBUG}")
	set(CMAKE_CXX_FLAGS_DEBUG "-DDEBUG=1 -D_DEBUG=1 ${CMAKE_C_FLAGS_DEBUG}")
endif()

if(APPLE)
	set(CMAKE_MACOSX_RPATH TRUE)
	set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)
	list(APPEND CMAKE_INSTALL_RPATH "@loader_path/" "@executable_path/")
elseif(UNIX)
	option(USE_XDG "Utilize XDG Base Directory Specification" ON)
	option(ENABLE_WAYLAND "Build support for Wayland" ON)
	if(CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_GNUCXX)
		option(ENABLE_DARRAY_TYPE_TEST "Test types of darray argument" ON)
	else()
		option(ENABLE_DARRAY_TYPE_TEST "Test types of darray argument" OFF)
	endif()

	if(USE_XDG)
		add_definitions(-DUSE_XDG)
	endif()

	if(NOT UNIX_STRUCTURE)
		list(APPEND CMAKE_INSTALL_RPATH "$ORIGIN")
	endif()

	if(ENABLE_DARRAY_TYPE_TEST)
		add_definitions(-DENABLE_DARRAY_TYPE_TEST)
	endif()
endif()

if(LOWERCASE_CMAKE_SYSTEM_PROCESSOR MATCHES "e2k")
	foreach(TEST_C_FLAG "-Wno-unused-parameter" "-Wno-ignored-qualifiers" "-Wno-pointer-sign" "-Wno-unused-variable" "-Wno-sign-compare" "-Wno-bad-return-value-type" "-Wno-maybe-uninitialized")
		CHECK_C_COMPILER_FLAG(${TEST_C_FLAG} C_COMPILER_SUPPORTS_FLAG_${TEST_C_FLAG})
		if(C_COMPILER_SUPPORTS_FLAG_${TEST_C_FLAG})
			set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${TEST_C_FLAG}")
		endif()
	endforeach()
	foreach(TEST_CXX_FLAG "-Wno-invalid-offsetof" "-Wno-maybe-uninitialized")
		CHECK_CXX_COMPILER_FLAG(${TEST_CXX_FLAG} CXX_COMPILER_SUPPORTS_FLAG_${TEST_CXX_FLAG})
		if(CXX_COMPILER_SUPPORTS_FLAG_${TEST_CXX_FLAG})
			set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${TEST_CXX_FLAG}")
		endif()
	endforeach()
endif()

option(BUILD_TESTS "Build test directory (includes test sources and possibly a platform test executable)" FALSE)
mark_as_advanced(BUILD_TESTS)

if(NOT INSTALLER_RUN)
	option(ENABLE_UI "Enables the OBS user interfaces" ON)
	if(DISABLE_UI OR NOT ENABLE_UI)
		set(UI_ENABLED FALSE)
	else()
		set(UI_ENABLED TRUE)

		if(CMAKE_SIZEOF_VOID_P EQUAL 8)
			set(_lib_suffix 64)
		else()
			set(_lib_suffix 32)
		endif()

		if(DEFINED QTDIR${_lib_suffix})
			list(APPEND CMAKE_PREFIX_PATH "${QTDIR${_lib_suffix}}")
		elseif(DEFINED QTDIR)
			list(APPEND CMAKE_PREFIX_PATH "${QTDIR}")
		elseif(DEFINED ENV{QTDIR${_lib_suffix}})
			list(APPEND CMAKE_PREFIX_PATH "$ENV{QTDIR${_lib_suffix}}")
		elseif(DEFINED ENV{QTDIR})
			list(APPEND CMAKE_PREFIX_PATH "$ENV{QTDIR}")
		endif()

		find_package(Qt5Widgets REQUIRED)
	endif()

	add_subdirectory(deps)

	if(WIN32)
		add_subdirectory(libobs-d3d11)
		add_subdirectory(libobs-winrt)
	endif()

	add_subdirectory(libobs-opengl)
	add_subdirectory(libobs)
	add_subdirectory(plugins)
	add_subdirectory(UI)

	if (ENABLE_UNIT_TESTS)
		enable_testing()
	endif()

	if (BUILD_TESTS OR ENABLE_UNIT_TESTS)
		add_subdirectory(test)
	endif()
else()
	obs_generate_multiarch_installer()
endif()

include(CopyMSVCBins)
