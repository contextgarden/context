# cmake/utilities.cmake

set(utilities_sources
    source/utilities/auxmemory.c
    source/utilities/auxzlib.c
    source/utilities/auxsparsearray.c
    source/utilities/auxsystem.c
    source/utilities/auxunistring.c
    source/utilities/auxfile.c
    source/utilities/auxposit.c
    source/utilities/auxbytemaps.c
    source/utilities/auxkdtree2d.c
    source/utilities/auxkdtree3d.c
    source/utilities/auxserialize.c

    source/libraries/hnj/hnjhyphen.c
)

add_library(utilities STATIC ${utilities_sources})

target_include_directories(utilities PRIVATE
    source/.
    source/luacore/lua55/src
)

if (NOT MSVC)
    target_compile_options(utilities PRIVATE
        -O3
        -fomit-frame-pointer
    )
endif()