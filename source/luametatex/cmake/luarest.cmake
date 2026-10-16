# The cerf library is actually optional but for now we compile it with the
# rest because the complex interfaces are different per platform. There is
# not that much code involved. But, anyway, at some point it might become
# a real optional module in which case the following will change.
# cmake/luarest.cmake

set(luarest_sources
    source/luaoptional/lmtcerflib.c
    source/libraries/libcerf/erfcx.c
    source/libraries/libcerf/err_fcts.c
    source/libraries/libcerf/im_w_of_x.c
    source/libraries/libcerf/w_of_z.c
    source/libraries/libcerf/width.c

    source/luarest/lmtfilelib.c
    source/luarest/lmtpdfelib.c
    source/luarest/lmtiolibext.c
    source/luarest/lmtoslibext.c
    source/luarest/lmtstrlibext.c
    source/luarest/lmtdecodelib.c
    source/luarest/lmtsha2lib.c
    source/luarest/lmtmd5lib.c
    source/luarest/lmtaeslib.c
    source/luarest/lmtbasexxlib.c
    source/luarest/lmtxmathlib.c
    source/luarest/lmtxcomplexlib.c
    source/luarest/lmtxdecimallib.c
    source/luarest/lmtxintervallib.c
    source/luarest/lmtziplib.c
    source/luarest/lmtsparselib.c
    source/luarest/lmtbitsetlib.c
    source/luarest/lmtposit.c
    source/luarest/lmtpotrace.c
    source/luarest/lmtqrcodegen.c
    source/luarest/lmtnanojpeg.c
    source/luarest/lmtseriallib.c
    source/luarest/lmtprocesslib.c
    source/luarest/lmttimerlib.c
    source/luarest/lmtvectorlib.c
    source/luarest/lmtbytemaplib.c
    source/luarest/lmteffectslib.c
    source/luarest/lmtzbufferlib.c
    source/luarest/lmtkdtreelib.c
    source/luarest/lmtclientlib.c
    source/luarest/lmtserverlib.c
)

add_library(luarest STATIC ${luarest_sources})

target_compile_definitions(luarest PUBLIC
    DECUSE64=1
  # DECCHECK=1
  # DECBUFFER=512
    DECNUMDIGITS=1000
)

target_include_directories(luarest PRIVATE
    source/libraries/libcerf
    source/luacore/lua55/src
    source/libraries/mimalloc/include
    source/libraries/potrace/src
    source/libraries/qrcodegen
    source/libraries/nanojpeg
    source/libraries/pplib
    source/libraries/pplib/util
    source/libraries/decnumber
    source/libraries/filib
)

include(CheckCCompilerFlag)

CHECK_C_COMPILER_FLAG("-Wno-discarded-qualifiers" limited_support)

if (limited_support)
    target_compile_options(luarest PRIVATE -Wno-discarded-qualifiers)
endif()

if (NOT MSVC)
    target_compile_options(luarest PRIVATE
        -O3
        -fstrict-aliasing
    )
endif()

# File-specific compilation rule for vector math speedup

set_source_files_properties(
    source/luarest/lmtvectorlib.c
    source/luarest/lmteffectslib.c
    source/luarest/lmtzbufferlib.c
    PROPERTIES
    COMPILE_FLAGS "-O3 -ffp-contract=fast -ftree-vectorize"
)

if (WIN32)
    target_link_libraries(luarest PRIVATE winhttp)
endif()