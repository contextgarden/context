set(luamplib_sources
    luamplib/mpc/mp.c
    luamplib/mpc/mplib.h
    luamplib/mpc/mpmp.h
    luamplib/mpc/mpmath.h
    luamplib/mpc/mpmath.c
    luamplib/mpc/mpmathdecimal.h
    luamplib/mpc/mpmathdecimal.c
    luamplib/mpc/mpmathdouble.h
    luamplib/mpc/mpmathdouble.c
    luamplib/mpc/mpstrings.h
    luamplib/mpc/mpstrings.c
    luamplib/mpc/mplibps.h
    luamplib/mpc/mppsout.h
    luamplib/mpc/psout.c
    luamplib/mpc/decContext.h
    luamplib/mpc/decContext.c
    luamplib/mpc/decNumber.h
    luamplib/mpc/decNumber.c
    luamplib/mpc/decNumberLocal.h
    luamplib/mpc/avl.h
    luamplib/mpc/avl.c
    luamplib/mpc/tfmin.c
)

add_library(luamplib STATIC ${luamplib_sources})

target_include_directories(luamplib
    PRIVATE
        luamplib
        luamplib/mpc
        luamplib/mpc/w2c
        libs/zlib/zlib-src
        lua54/src
)

target_compile_options(luamplib PRIVATE -Wno-unused-parameter)
target_compile_options(luamplib PRIVATE -Wno-sign-compare)
target_compile_options(luamplib PRIVATE -Wno-implicit-fallthrough)
