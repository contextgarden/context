set(texlua_sources
    lua54/src/lapi.h
    lua54/src/lauxlib.h
    lua54/src/lcode.h
    lua54/src/lctype.h
    lua54/src/ldebug.h
    lua54/src/ldo.h
    lua54/src/lfunc.h
    lua54/src/lgc.h
    lua54/src/llex.h
    lua54/src/llimits.h
    lua54/src/lmem.h
    lua54/src/lobject.h
    lua54/src/lopcodes.h
    lua54/src/lparser.h
    lua54/src/lstate.h
    lua54/src/lstring.h
    lua54/src/ltable.h
    lua54/src/ltm.h
    lua54/src/luaconf.h
    lua54/src/lua.h
    lua54/src/lualib.h
    lua54/src/lundump.h
    lua54/src/lvm.h
    lua54/src/lzio.h
    lua54/src/lapi.c
    lua54/src/lauxlib.c
    lua54/src/lbaselib.c
    lua54/src/lbitlib.c
    lua54/src/lcode.c
    lua54/src/lcorolib.c
    lua54/src/lctype.c
    lua54/src/ldblib.c
    lua54/src/ldebug.c
    lua54/src/ldo.c
    lua54/src/ldump.c
    lua54/src/lfunc.c
    lua54/src/lgc.c
    lua54/src/linit.c
    lua54/src/liolib.c
    lua54/src/llex.c
    lua54/src/lmathlib.c
    lua54/src/lmem.c
    lua54/src/loadlib.c
    lua54/src/lobject.c
    lua54/src/lopcodes.c
    lua54/src/loslib.c
    lua54/src/lparser.c
    lua54/src/lstate.c
    lua54/src/lstring.c
    lua54/src/lstrlib.c
    lua54/src/ltable.c
    lua54/src/ltablib.c
    lua54/src/ltm.c
    lua54/src/lua.c
    lua54/src/lundump.c
    lua54/src/lutf8lib.c
    lua54/src/lvm.c
    lua54/src/lzio.c

    luapeg/lpeg.h
    luapeg/lpeg.c
)

add_library(texlua STATIC ${texlua_sources})

target_compile_options(texlua PRIVATE -O2)
target_compile_options(texlua PRIVATE -Wno-cast-align)
target_compile_options(texlua PRIVATE -Wno-cast-qual)
target_compile_options(texlua PRIVATE -Wno-implicit-fallthrough)
target_compile_options(texlua PRIVATE -std=c99)

# for lpeg:

target_include_directories(texlua
    PRIVATE
    lua54/src
)
