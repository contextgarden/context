cmake_minimum_required(VERSION 3.5)

project(luametatex VERSION 2.00 LANGUAGES C)

# https://sourceforge.net/p/predef/wiki/OperatingSystems/
# https://sourceforge.net/p/predef/wiki/Architectures/
#
# http://nadeausoftware.com/articles/2012/01/c_c_tip_how_use_compiler_predefined_macros_detect_operating_system

# We support only those operating systems and architectures that make
# sense for runing cq. using tex and friends.
#
# --------------------------------------------------------------------
# windows
# --------------------------------------------------------------------
#
# _WIN32  32 or 64 bit
# _WIN64  64 bit
#
# --------------------------------------------------------------------
# linux
# --------------------------------------------------------------------
#
# __linux__ || __gnu_linux__
#
# --------------------------------------------------------------------
# free bsd
# --------------------------------------------------------------------
#
# __FreeBSD__        all versions, has main version number
# __FreeBSD_version  6 digit version number (first two matter)
#
# --------------------------------------------------------------------
# open bsd
# --------------------------------------------------------------------
#
# __OpenBSD__     all versions
# OpenBSD'V'_'R'  comes from <sys/param.h>
#
# --------------------------------------------------------------------
# net bsd
# --------------------------------------------------------------------
#
# __NetBSD__     all versions
# NetBSD'V'_'R'  comes from <sys/param.h>
#
# --------------------------------------------------------------------
# osx
# --------------------------------------------------------------------
#
# __APPLE__ && __MACH__
#
# --------------------------------------------------------------------
# android
# --------------------------------------------------------------------
#
# __ANDROID__
# __ANDROID_API__   <android/api-level.h>
#
# --------------------------------------------------------------------
# comments
# --------------------------------------------------------------------
#
# We might need to set WIN32 when we have _WIN32.
#
# Only a few libraries check for _WIN64, __MINGW32__ or __MINGW64__.
#
# There are some we need to keep an eye on: IS_DIR_SEP, PATH_MAX, STDC,
# NO_GETCWD, NO_CHDIR, HAVE_UNISTD_H, HAVE_ASSERT_H, LUA_USE_POSIX,
# LUA_WIN, _CRTIMP_TYPEINFO, HAVE_SYS_TIME_H, HAVE_SYS_TIMEB_H,
# HAVE_GETTIMEOFDAY, HAVE_FTIME.
#
# --------------------------------------------------------------------

add_compile_options(-Wall)
add_compile_options(-Wextra)

add_compile_options(-O3)

add_compile_options(-Wcast-align)
add_compile_options(-Wcast-qual)

add_compile_options(-Wnested-externs)
add_compile_options(-Wwrite-strings)
add_compile_options(-Wdeclaration-after-statement)
add_compile_options(-Wno-unknown-pragmas)
add_compile_options(-Wpointer-arith)

add_compile_options(-DLUAI_HASHLIMIT=6)
add_compile_options(-DLUA_USE_JUMPTABLE=0)

# add_compile_options(-DLUA_BUILD_AS_DLL=1)
# add_compile_options(-DLUA_CORE)
# add_compile_options(-DLUA_LIB)

# -ldl

# # mp, avl, libdeflate, ffi, socket:
#
# add_compile_options(-Wshadow)

# $ RANLIB= ranlib

# # when we run valgrind we need verbose binaries:
# #
# # valgrind -v --track-origins=yes --leak-check=full context ...
#
# add_compile_options(-g)

# # for profiling with vallgrind / cachegrind we need:
#
# add_compile_options(-pg)
# set(CMAKE_EXE_LINKER_FLAGS "-pg")

# # otherwise we strip the binaries:

# when we want lua exposed we can say:
#
# add_compile_options(-fvisibility=hidden)
# set(CMAKE_ENABLE_EXPORTS true)
# set(CMAKE_EXE_LINKER_FLAGS "-s")

# # but normally we do:
#
set(CMAKE_EXE_LINKER_FLAGS "-s")

# # link optimization doesn't work
#
# add_compile_options(-flto)
# set(CMAKE_EXE_LINKER_FLAGS "-s -flto")

# add_compile_options(-fPIE)
# add_compile_options(-fPIC)
# add_compile_options(-pie)

include(cmake/texlua.cmake)
include(cmake/zlib.cmake)
include(cmake/libdeflate.cmake)
include(cmake/libcerf.cmake)
include(cmake/luamplib.cmake)
include(cmake/luaffi.cmake)
include(cmake/luapplib.cmake)
include(cmake/luamisc.cmake)
include(cmake/luamath.cmake)
include(cmake/luasocket.cmake)
include(cmake/texmeta.cmake)

include(cmake/luametatex.cmake)
