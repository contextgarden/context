set(libdeflate_sources
    libs/libdeflate/lib/x86/cpu_features.c
    libs/libdeflate/lib/arm/cpu_features.c
    libs/libdeflate/libdeflate.h
    libs/libdeflate/common/common_defs.h
    libs/libdeflate/lib/adler32.c
    libs/libdeflate/lib/aligned_malloc.c
    libs/libdeflate/lib/crc32.c
    libs/libdeflate/lib/deflate_compress.c
    libs/libdeflate/lib/deflate_decompress.c
    libs/libdeflate/lib/gzip_compress.c
    libs/libdeflate/lib/gzip_decompress.c
    libs/libdeflate/lib/zlib_compress.c
    libs/libdeflate/lib/zlib_decompress.c
)

add_library(libdeflate STATIC ${libdeflate_sources})

target_include_directories(libdeflate
    PRIVATE
        libs/libdeflate
        libs/libdeflate/lib
        libs/libdeflate/common
)


target_compile_options(libdeflate PRIVATE -Wno-sign-compare)
target_compile_options(libdeflate PRIVATE -Wno-unused-parameter)
target_compile_options(libdeflate PRIVATE -Wno-cast-qual)
