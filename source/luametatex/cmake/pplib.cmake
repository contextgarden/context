set(pplib_sources

    source/libraries/pplib/pparray.c
    source/libraries/pplib/ppcrypt.c
    source/libraries/pplib/ppdict.c
    source/libraries/pplib/ppheap.c
    source/libraries/pplib/ppload.c
    source/libraries/pplib/ppstream.c
    source/libraries/pplib/ppxref.c
    source/libraries/pplib/util/utilbasexx.c
    source/libraries/pplib/util/utilcrypt.c
    source/libraries/pplib/util/utilflate.c
    source/libraries/pplib/util/utilfpred.c
    source/libraries/pplib/util/utiliof.c
    source/libraries/pplib/util/utillog.c
    source/libraries/pplib/util/utillzw.c
    source/libraries/pplib/util/utilmd5.c
    source/libraries/pplib/util/utilmem.c
    source/libraries/pplib/util/utilmemheap.c
    source/libraries/pplib/util/utilmemheapiof.c
    source/libraries/pplib/util/utilmeminfo.c
    source/libraries/pplib/util/utilnumber.c
    source/libraries/pplib/util/utilsha.c

)

add_library(pplib STATIC ${pplib_sources})

if (NOT MSVC)
    target_compile_options(pplib PRIVATE
        -Wno-missing-declarations
    )
endif (NOT MSVC)

target_include_directories(pplib PRIVATE
    source/libraries/pplib
    source/libraries/pplib/util
    source/libraries/zlib

    source/libraries/miniz
    source/utilities/auxmemory
    source/utilities/auxzlib
)
