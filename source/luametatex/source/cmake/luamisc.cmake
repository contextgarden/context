set(luamisc_sources

    lua/lsha2lib.h
    lua/lsha2lib.c

    lua/lmd5lib.h
    lua/lmd5lib.c

    lua/lbasexxlib.h
    lua/lbasexxlib.c

    lua/lflatelib.h
    lua/lflatelib.c

    lua/lfilelib.h
    lua/lfilelib.c

    luazlib/src/lgzip.h
    luazlib/src/lgzip.c

    luazlib/src/lzlib.h
    luazlib/src/lzlib.c

)

add_library(luamisc STATIC ${luamisc_sources})

target_include_directories(luamisc
    PRIVATE
    libs/zlib/zlib-src
    libs/libdeflate
    libs/libdeflate/lib
    libs/libdeflate/common
    lua54/src
)
