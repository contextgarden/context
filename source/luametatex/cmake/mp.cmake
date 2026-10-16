set(mp_sources
    source/mp/mp.c
    source/mp/mpstrings.c
    source/mp/mpmathscaled.c
    source/mp/mpmathdouble.c
    source/mp/mpmathbinary.c
    source/mp/mpmathdecimal.c
    source/mp/mpmathposit.c
    source/mp/mpmathinterval.c

    source/libraries/decnumber/decContext.c
    source/libraries/decnumber/decNumber.c

    source/libraries/avl/avl.c

    source/lua/lmtmplib.c
)

add_library(mp STATIC ${mp_sources})

# Ensure target dependencies for circular symbol resolution
target_link_libraries(mp PRIVATE utilities luarest lua)

target_include_directories(mp PRIVATE
    .
    source/.
    source/mp
    source/luacore/lua55/src
    source/libraries/avl
    source/libraries/decnumber
    source/utilities
    source/libraries/mimalloc/include
    source/libraries/softposit/source/include
    source/libraries/filib
)

target_compile_definitions(mp PUBLIC
    DECUSE64=1
  # DECCHECK=1
  # DECBUFFER=512
    DECNUMDIGITS=1000
)

# Floating-point precision rules for MetaPost path solving
if (MSVC)
    target_compile_options(mp PRIVATE
     #  /O2 /Oi /Ot
        /fp:precise
    )
else()
    target_compile_options(mp PRIVATE
        -O3
        -fno-fast-math
        -ffp-contract=off
        -fno-associative-math
        -fno-strict-aliasing
        -Wno-unused-parameter
        -Wno-sign-compare
        -Wno-cast-qual
        -Wno-cast-align
    )
endif()

if (CMAKE_C_COMPILER_ID STREQUAL "Clang")
    target_compile_options(mp PRIVATE
        -Wno-unreachable-code-break
    )
endif()