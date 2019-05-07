add_compile_options(-DLUA_CORE)

set(luametatex_sources
    luametatex.c
)

add_executable(luametatex ${luametatex_sources})

target_include_directories(luametatex
    PRIVATE
        .
        lua54/src
)

target_link_libraries(luametatex
    texmeta
    texlua
    luamisc
    luamath
    luamplib
    luasocket
    luaffi
    luapplib
    luazlib
    libdeflate
    libcerf

    m

    ${extra_libraries}
)

##    ws2_32
