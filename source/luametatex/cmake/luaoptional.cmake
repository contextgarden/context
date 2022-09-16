set(luaoptional_sources

    source/luaoptional/lmtsqlite.c
    source/luaoptional/lmtmysql.c
    source/luaoptional/lmtpostgress.c
    source/luaoptional/lmtcurl.c
    source/luaoptional/lmtghostscript.c
    source/luaoptional/lmtimagemagick.c
    source/luaoptional/lmtgraphicsmagick.c
    source/luaoptional/lmtzint.c
    source/luaoptional/lmtmujs.c
    source/luaoptional/lmtlzo.c
    source/luaoptional/lmtlz4.c
    source/luaoptional/lmtkpse.c
    source/luaoptional/lmthb.c
    source/luaoptional/lmtzstd.c
    source/luaoptional/lmtlzma.c
    source/luaoptional/lmtforeign.c

)

add_library(luaoptional STATIC ${luaoptional_sources})

target_include_directories(luaoptional PRIVATE
    .
    source/.
    source/luacore/lua54/src
    source/libraries/mimalloc/include
)

