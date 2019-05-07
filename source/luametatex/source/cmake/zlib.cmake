set(luazlib_sources
    libs/zlib/zlib-src/adler32.c
    libs/zlib/zlib-src/compress.c
    libs/zlib/zlib-src/crc32.c
    libs/zlib/zlib-src/crc32.h
    libs/zlib/zlib-src/deflate.c
    libs/zlib/zlib-src/deflate.h
    libs/zlib/zlib-src/infback.c
    libs/zlib/zlib-src/gzclose.c
    libs/zlib/zlib-src/gzguts.h
    libs/zlib/zlib-src/gzlib.c
    libs/zlib/zlib-src/gzread.c
    libs/zlib/zlib-src/gzwrite.c
    libs/zlib/zlib-src/inffast.c
    libs/zlib/zlib-src/inffast.h
    libs/zlib/zlib-src/inffixed.h
    libs/zlib/zlib-src/inflate.c
    libs/zlib/zlib-src/inflate.h
    libs/zlib/zlib-src/inftrees.c
    libs/zlib/zlib-src/inftrees.h
    libs/zlib/zlib-src/trees.c
    libs/zlib/zlib-src/trees.h
    libs/zlib/zlib-src/uncompr.c
    libs/zlib/zlib-src/zutil.h
    libs/zlib/zlib-src/zutil.c
)

add_library(luazlib STATIC ${luazlib_sources})

target_compile_options(luazlib PRIVATE -Wno-cast-qual)
target_compile_options(luazlib PRIVATE -Wno-implicit-fallthrough)
