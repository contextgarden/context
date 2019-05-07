set(luamath_sources

    lua/lxmathlib.h
    lua/lxmathlib.c

    lua/lxcomplexlib.h
    lua/lxcomplexlib.c

)

add_library(luamath STATIC ${luamath_sources})

target_include_directories(luamath
    PRIVATE
    libs/libcerf/lib
    lua54/src
)

# target_compile_options(luamath PRIVATE -std=c99)

