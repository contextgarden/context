set(libcerf_sources
    libs/libcerf/lib/cerf.h
    libs/libcerf/lib/erfcx.c
    libs/libcerf/lib/err_fcts.c
    libs/libcerf/lib/im_w_of_x.c
    libs/libcerf/lib/w_of_z.c
    libs/libcerf/lib/width.c
)

add_library(libcerf STATIC ${libcerf_sources})

target_include_directories(libcerf
    PRIVATE
        libs/libcerf/lib
)

target_compile_options(libcerf PRIVATE -Wno-declaration-after-statement)
