# We use CMake but I bet we can also provide a simple make file for linux just because
# when I look what gets compiled into CMake we need very little of that (and it
# has a lot of dependencies - ssh related, compression, security, xml, etc), but maybe
# there is a lightweight version of CMake.

# Don't use -ffast-math as we depend on sign bit nilling in mp.

# -fno-fast-math -ffp-contract=off -fno-associative-math -fno-reciprocal-math

# /fp:strict

cmake_minimum_required(VERSION 3.10..3.28)

project(luametatex VERSION 2.11 LANGUAGES C)

if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build." FORCE)
endif()

# I need to check with Mojca of the compile farm can handle this. It currently is not that
# critical because CMake will use a lower version if needed. But we do need to enable the
# extensions.

# set(CMAKE_C_STANDARD 11)
# set(CMAKE_C_STANDARD 17)

if (CMAKE_VERSION VERSION_GREATER_EQUAL 3.21)
    set(CMAKE_C_STANDARD 23)
elseif (CMAKE_VERSION VERSION_GREATER_EQUAL 3.12)
    set(CMAKE_C_STANDARD 11) # for debian 9 bah
else ()
    set(CMAKE_C_STANDARD 11)
endif ()

set(CMAKE_C_STANDARD_REQUIRED OFF) # OFF is default

# set(CMAKE_C_EXTENSIONS ON) # ON is default

# https://sourceforge.net/p/predef/wiki/OperatingSystems/
# https://sourceforge.net/p/predef/wiki/Architectures/

include(GNUInstallDirs)

# Optionals (maybe have a LMT_*_TOO for each of them). We might start out with only a very few
# optionals at some time, but for now we enable them (there is not not much code involved). The
# idea behind these optionals is that we have very simple (!) interfaces, delegating as much as
# possible to Lua. We will *not* add interfaces with many bindings because that will introduce
# dependencies (and looking at e.g. LuaTeX build updates shows that clearly: a no-go).

set(LMT_KPSE_TOO   1) # In case we want to manage MKII scripts (etc) with mtxrun.
set(LMT_HB_TOO     1) # Maybe handy for Idris' font development (old converted ffi stuff).
set(LMT_SOCKET_TOO 0) # Only when we transition.

# Options:

option(LMT_DEBUG      "Build with debug symbols and no optimizations" OFF)
option(LMT_NOOPTIMIZE "Build without link time optimization" OFF)

# Profile-guided optimization is a two-stage build.  The build script uses
# GENERATE for the training binary and USE for the final binary.

set(LMT_PROFILE "OFF" CACHE STRING "Profile-guided optimization mode: OFF, GENERATE, or USE")
set_property(CACHE LMT_PROFILE PROPERTY STRINGS OFF GENERATE USE)
set(LMT_PROFILE_DIR "" CACHE PATH "Directory containing profile data")

# Usually this is the same as LMT_PROFILE_DIR.  A MinGW binary launched from
# WSL can need a Windows/UNC spelling for the directory at runtime, while GCC
# itself still needs the WSL spelling when it consumes the data.

set(LMT_PROFILE_RUNTIME_DIR "${LMT_PROFILE_DIR}" CACHE STRING
    "Directory spelling used by the instrumented binary at runtime"
)

string(TOUPPER "${LMT_PROFILE}" LMT_PROFILE_MODE)
if (LMT_PROFILE_MODE STREQUAL "ON" OR LMT_PROFILE_MODE STREQUAL "TRUE")
    # Keep the old boolean spelling useful for callers that used the former
    # option, while giving the profile build its intended meaning.
    set(LMT_PROFILE_MODE "GENERATE")
endif()

if (NOT LMT_PROFILE_MODE STREQUAL "OFF" AND
    NOT LMT_PROFILE_MODE STREQUAL "GENERATE" AND
    NOT LMT_PROFILE_MODE STREQUAL "USE")
    message(FATAL_ERROR "LMT_PROFILE must be OFF, GENERATE, or USE")
endif()

if (NOT LMT_PROFILE_MODE STREQUAL "OFF")
    if (LMT_DEBUG)
        message(FATAL_ERROR "LMT_PROFILE cannot be combined with LMT_DEBUG")
    endif()
    if (NOT LMT_PROFILE_DIR)
        message(FATAL_ERROR "LMT_PROFILE_DIR is required when LMT_PROFILE is enabled")
    endif()

    if (LMT_PROFILE_MODE STREQUAL "GENERATE")
        file(MAKE_DIRECTORY "${LMT_PROFILE_DIR}")
    elseif (NOT EXISTS "${LMT_PROFILE_DIR}/profile.ready")
        message(FATAL_ERROR
            "No complete profile found in ${LMT_PROFILE_DIR}; run the training build first")
    endif()

    if (MSVC)
        message(FATAL_ERROR "LMT_PROFILE currently supports GCC and Clang GNU-style builds only")
    elseif (CMAKE_C_COMPILER_ID STREQUAL "GNU")
        if (LMT_PROFILE_MODE STREQUAL "GENERATE")
            add_compile_options("-fprofile-generate=${LMT_PROFILE_RUNTIME_DIR}")
            add_link_options("-fprofile-generate=${LMT_PROFILE_RUNTIME_DIR}")
        else()
            add_compile_options(
                "-fprofile-use=${LMT_PROFILE_DIR}"
                -fprofile-correction
                -Wno-missing-profile
                # Keep normal inline limits even for code not hit during training:
                -fprofile-partial-training
                --param=inline-unit-growth=100
                --param=hot-bb-frequency-fraction=1000
            )
            add_link_options(
                "-fprofile-use=${LMT_PROFILE_DIR}"
                -fprofile-correction
            )
        endif()
    elseif (CMAKE_C_COMPILER_ID MATCHES "Clang")
        if (LMT_PROFILE_MODE STREQUAL "GENERATE")
            add_compile_options(-fprofile-instr-generate)
            add_compile_options(-Wno-profile-instr-unprofiled)
            add_link_options(-fprofile-instr-generate)
        else()
            if (NOT EXISTS "${LMT_PROFILE_DIR}/luametatex.profdata")
                message(FATAL_ERROR
                    "No Clang profile data found at ${LMT_PROFILE_DIR}/luametatex.profdata")
            endif()
            add_compile_options("-fprofile-instr-use=${LMT_PROFILE_DIR}/luametatex.profdata")
            add_compile_options(-Wno-profile-instr-unprofiled)
            add_link_options("-fprofile-instr-use=${LMT_PROFILE_DIR}/luametatex.profdata")
        endif()
    else()
        message(FATAL_ERROR "LMT_PROFILE requires a GCC or Clang C compiler")
    endif()
endif()

if (NOT LMT_DEBUG)
    # This triggers link time optimization, which adds to compile time and gains (at most) a few
    # percent on runtime. When set, because we're sparse, we also strip the binary. On the manual
    # we gain 2-4 percent, so not that much. However, as we moved to more inline function in favor
    # of macros, link time optimizations makes sense!

    if (NOT LMT_NOOPTIMIZE)
        set(LMT_OPTIMIZE 1)
    endif()

    # This makes the binary some 135K smaller so it might become the default at some point which is
    # nice (the smaller as runner the better). After all, we don't load external (Lua) libraries
    # anyway.

    set(LMT_STRIP 1)
endif()

# Specific adjustments for musl-gcc compiler wrapper

if (CMAKE_C_COMPILER MATCHES "musl-gcc")
    add_compile_options(-std=gnu11 -Wno-cpp)
    add_compile_definitions(_GNU_SOURCE)
endif()

if (LMT_DEBUG)
    if (NOT MINGW)
        # fails with mingw
        add_compile_options(-g -O0 -fsanitize=address)
        add_link_options(-fsanitize=address)
    endif()
endif()

if (CMAKE_C_COMPILER_ID STREQUAL "GNU")

    # Default is ~50,000,000 (bytes). Raising it allows GCC to finish tracking large node tables.

    add_compile_options(--param=max-vartrack-size=100000000)

endif()

# This is for Mikael, Keith and Hans to play with. We use less memory but not that much compared
# to what this mechanism used anyway. This will likely become the default.

# add_compile_definitions(LMT_ZBUFFER_FLOAT_RGB=1)

# When one wants to use Lua libraries, this is needed. But keep in mind that it's not supported,
# so we won't look into issues that could result from that. Getting a matching library is upto
# the user. Keep in mind that we might have set a different bytecode (luac) version during the
# alpha/beta stages of a Lua development version.

# set(LMT_PERMIT_LUA_LIBRARIES 1)

if (DEFINED LMT_PERMIT_LUA_LIBRARIES)
    unset(LMT_STRIP)
    unset(LMT_OPTIMIZE)
    add_compile_definitions(LMT_PERMIT_LUA_LIBRARIES="yes")
endif ()

if (MSVC)

    # Apply universally to all MSVC toolchains to suppress unsafe function warnings

    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)

    if (CMAKE_C_COMPILER_ID MATCHES "Clang")

        if (LMT_DEBUG)
            add_compile_options(
                -g
                -O0
            )
        else()
            add_compile_options(
                -O3
            )
        endif()

        add_compile_options(
            -Wcast-align
            -Wcast-qual

            -Wno-unknown-pragmas
            -fno-strict-aliasing

            -Wno-pedantic
            -Wno-deprecated-declarations
            -Wno-missing-noreturn
            -Wno-shadow
        )

        add_compile_definitions(LMT_COMPILER_USED="clang")

    else()

        add_compile_options(
            /W4
        )

        # We always optimize ... symbols are not in the binary anyway so there is no advantage
        # (like when accessing Lua api functions). We could have an additional luametatex-lua.dll
        # but that also creates a dependency (possible conflict). So just don't expect using
        # Lua libraries in luametatex.

        if (NOT LMT_DEBUG)
            add_compile_options(
                /O2  # maximize speed
                /Oi  # enable intrinsic functions
                /Ot  # favor fast code over small size
                /Ob2 # aggressive inlining
                /GL  # whole program link optimization
                /Gw  # whole program data optimization (a little smaller bin)
            )
        endif()

        add_compile_definitions(LMT_COMPILER_USED="msvc")

        add_compile_options(
            /W4
            /utf-8
            /wd4201 # Nonstandard extension: nameless struct/union
            /wd4310 # Cast truncates constant value
            /wd4100 # Unreferenced formal parameter
            /wd4244 # Conversion loss of data (e.g. int to short)
            /wd4267 # Conversion loss of data (size_t to int)
            /wd4018 # Signed/unsigned mismatch
            /wd4127 # Conditional expression is constant
            /wd4706 # Assignment within conditional expression
            /wd4456 # Declaration hides previous local declaration
            /wd4709 # Comma operator within a subscript expression
        )

    endif()

else()

    if (CMAKE_C_COMPILER_ID MATCHES "Clang")

        if (LMT_DEBUG)
            add_compile_options(
                -g
                -O0
            )
        else()
            add_compile_options(
                -O3
            )
        endif()

        add_compile_definitions(LMT_COMPILER_USED="clang")

    else()

        if (LMT_DEBUG)
            add_compile_options(
                -g
                -O0
            )
        else()
            add_compile_options(
                -O3
            )
        endif()

        add_compile_definitions(LMT_COMPILER_USED="gcc")

      # add_compile_options(-pg)
      # add_link_options(-pg)

      # e.g. mp crashes when we have > 4K currentpicture clips in a row

        if (MINGW)
            add_link_options("-Wl,--stack,2621440")
        elseif (SOLARIS OR CMAKE_SYSTEM_NAME MATCHES "SunOS" OR CMAKE_HOST_SOLARIS)
            # Solaris / SunOS linker doesn't consistently support -z stack-size.
            # Stack size management is handled via ulimit / setrlimit on SunOS.
        else()
            # Linux, BSDs, and general ELF
            add_link_options("-Wl,-z,stack-size=2621440")
        endif()

    endif()

    add_compile_options(
        -Wall

        -Wcast-align
        -Wcast-qual

        -Wno-unknown-pragmas
        -Wno-unused-result
        -fno-strict-aliasing
    )

    # for c17
    #
    # add_compile_definitions(__STDC_WANT_LIB_EXT2__=1)

    if (((DEFINED LMT_OPTIMIZE) OR (DEFINED LMT_STRIP)) AND NOT LMT_DEBUG)
        if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
            # skip
        elseif (${CMAKE_SYSTEM_NAME} MATCHES "ARM64")
            # skip
        else()
            set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -s")
        endif()
    endif()

endif()

if (CMAKE_C_COMPILER_ID MATCHES "Clang")

    add_compile_options(
        # prevent unknown flag errors across different Clang compiler versions
        -Wno-unknown-warning-option

        # silence pedantic checks on standard C headers and pointer math
        -Wno-reserved-identifier
        -Wno-reserved-id-macro
        -Wno-unsafe-buffer-usage # Clang 16+ pointer arithmetic warnings

        # cross-platform header inclusion & format flexibility
        -Wno-nonportable-include-path
        -Wno-format-nonliteral

        # noisy type conversions & shadow suppressions
        -Wno-sign-conversion
        -Wno-shadow
        -Wno-implicit-fallthrough
    )

endif()

if (MSVC)
    # Remove runtime checks (/RTC1) which conflict with optimizations (/O2)
    foreach(flag_var
        CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
        CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO)
        if(${flag_var} MATCHES "/RTC1")
            string(REGEX REPLACE "/RTC1" "" ${flag_var} "${${flag_var}}")
        endif()
    endforeach()
endif()

if (MSVC)
    # Remove runtime checks (/RTC1) and clean up conflicting default flags to avoid D9025 warnings
    foreach(flag_var
        CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
        CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO)

        if(${flag_var} MATCHES "/W3")
            string(REGEX REPLACE "/W3" "/W4" ${flag_var} "${${flag_var}}")
        endif()

        if(${flag_var} MATCHES "/Od")
            string(REGEX REPLACE "/Od" "/O2" ${flag_var} "${${flag_var}}")
        endif()

        # Strip out /Ob0 so it doesn't clash with your /Ob2
        if(${flag_var} MATCHES "/Ob0")
            string(REGEX REPLACE "/Ob0" "" ${flag_var} "${${flag_var}}")
        endif()

        if(${flag_var} MATCHES "/MDd")
            string(REGEX REPLACE "/MDd" "/MD" ${flag_var} "${${flag_var}}")
        endif()

        string(REGEX REPLACE "/RTC1" "" ${flag_var} "${${flag_var}}")
    endforeach()
endif()


# Not that tested (converted ffi originals):

if (LMT_KPSE_TOO)
    add_compile_definitions(LMT_KPSE_TOO=1)
endif()
if (LMT_HB_TOO)
    add_compile_definitions(LMT_HB_TOO=1)
endif()
if (LMT_SOCKET_TOO)
    add_compile_definitions(LMT_SOCKET_TOO=1)
endif()

# This needs cmake >= 3.9 and produces a 60K smaller mingw binary but it take quite a bit of
# runtime to get there so it should become an option (apart from testing on all builders).

if ((DEFINED LMT_OPTIMIZE) AND NOT LMT_DEBUG)

    include(CheckIPOSupported)
    check_ipo_supported(RESULT ipo_supported OUTPUT ipo_message)

    if (CMAKE_C_COMPILER MATCHES "musl-gcc")
        #
        # musl-gcc wrapper needs explicit LTO & linker plugin flags,
        # and MUST NOT use -fwhole-program to prevent static libc symbol stripping issues.
        add_compile_options(-flto)
        add_link_options(-flto -fuse-linker-plugin)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
        #
    elseif (ipo_supported)
        #
        # We only have one program so we do it global (can become an -- option)
        #
        # set_property(TARGET luametatex PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE)
        #
        # mingw64: 2865664, nocona: 2819584, lto: 2835968 (around 1% gain on manual)
        #
        set(CMAKE_C_VISIBILITY_PRESET hidden)

        if (CMAKE_C_COMPILER_ID MATCHES "Clang")
            # already -03
            add_compile_options(-mllvm -import-instr-limit=250)
            add_link_options(-mllvm -import-instr-limit=250)
        elseif (CMAKE_C_COMPILER_ID STREQUAL "GNU")
            # already -03
            add_link_options(-fwhole-program)
        elseif (MSVC)
            add_link_options(/LTCG:STATUS /OPT:REF /OPT:ICF)
        endif ()

        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
        #
    else()
        # No message needed, just accept the fact.
    endif()

endif()

# Mimalloc is still under development, so we only support it on a few platforms. By the time it is
# stable we can probably remove some of the following tests. A bit of a hack.
#
# When the old osx version is dropped and armhf is upgraded we can enable unix except solaris which
# fails. So, only osx 10.6 and rpi 32 fail. But we will probably drop 32 bit in the future anyway.
#
# At the beginning of 2025 on Windows 10 the gain is some 5 percent on the 650 page luametatex
# manual over the default memory allocator.

# CMAKE_HOST_SYSTEM_PROCESSOR arm64 x86_64

# if (APPLE)
#     set(MI_OSX_ZONE 1)
# endif()

if (CMAKE_HOST_SOLARIS)
    unset(luametatex_use_mimalloc)
elseif (MSVC)
    set(luametatex_use_mimalloc 1)
elseif (CMAKE_C_COMPILER MATCHES "musl-gcc")
    # Disable mimalloc for musl static builds to prevent allocator symbol collisions
  # unset(luametatex_use_mimalloc)
elseif (CMAKE_HOST_APPLE AND NOT (${CMAKE_C_COMPILER} MATCHES "arm"))
    # fails on the osx intel
elseif (${CMAKE_SYSTEM_PROCESSOR} MATCHES "armv7l")
    # fails on the rpi 32 bit
elseif (CMAKE_C_COMPILER_ID MATCHES "AppleClang|Clang")
    # no motivation to figure specifics out
else()
    set(luametatex_use_mimalloc 1)
endif()

# unset(luametatex_use_mimalloc)

include_directories(${CMAKE_ROOT}/source)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/source)

if (DEFINED luametatex_use_mimalloc)
    add_compile_definitions(LUAMETATEX_USE_MIMALLOC=1)
  # add_compile_definitions(MIMALLOC_RESET_DELAY=250)
  # set(luametatex_use_mimalloc 1)
    include(cmake/mimalloc.cmake)
endif()

include(cmake/utilities.cmake)
include(cmake/tex.cmake)
include(cmake/lua.cmake)
include(cmake/mp.cmake)

include(cmake/luarest.cmake)

if (LMT_SOCKET_TOO)
    include(cmake/luasocket.cmake)
endif()

include(cmake/luaoptional.cmake)

include(cmake/pplib.cmake)
include(cmake/filib.cmake)
include(cmake/miniz.cmake)
include(cmake/softposit.cmake)
include(cmake/potrace.cmake)
include(cmake/qrcodegen.cmake)
include(cmake/nanojpeg.cmake)
include(cmake/triangles.cmake)

# include(cmake/qhull.cmake)

include(cmake/luametatex.cmake)
