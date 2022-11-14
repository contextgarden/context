set(mp_sources

    source/mp/mpc/mp.c
    source/mp/mpc/mpstrings.c
    source/mp/mpc/mpmath.c
    source/mp/mpc/mpmathdouble.c
    source/mp/mpc/mpmathbinary.c
    source/mp/mpc/mpmathdecimal.c

    source/libraries/decnumber/decContext.c
    source/libraries/decnumber/decNumber.c

    source/libraries/avl/avl.c

    source/lua/lmtmplib.c

    source/luarest/lmtxdecimallib.c

)

add_library(mp STATIC ${mp_sources})

target_include_directories(mp PRIVATE
    .
    source/.
    source/mp/mpc
    source/luacore/lua54/src
    source/libraries/avl
    source/libraries/decnumber
    source/utilities
    source/libraries/mimalloc/include
)

target_compile_definitions(mp PUBLIC
    DECUSE64=1
  # DECCHECK=1
  # DECBUFFER=512
    DECNUMDIGITS=1000
)

if (CMAKE_C_COMPILER_ID STREQUAL "Clang")
    target_compile_options(mp PRIVATE
        -Wno-unreachable-code-break
    )
endif()

if (NOT MSVC)
    target_compile_options(mp PRIVATE
        -Wno-unused-parameter
        -Wno-sign-compare
        -Wno-cast-qual
        -Wno-cast-align
        # for decnumber with lto
        -fno-strict-aliasing
    )
endif()
