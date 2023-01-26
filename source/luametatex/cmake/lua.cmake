set(lua_sources

    source/luacore/lua54/src/lapi.c
    source/luacore/lua54/src/lauxlib.c
    source/luacore/lua54/src/lbaselib.c
    source/luacore/lua54/src/lcode.c
    source/luacore/lua54/src/lcorolib.c
    source/luacore/lua54/src/lctype.c
    source/luacore/lua54/src/ldblib.c
    source/luacore/lua54/src/ldebug.c
    source/luacore/lua54/src/ldo.c
    source/luacore/lua54/src/ldump.c
    source/luacore/lua54/src/lfunc.c
    source/luacore/lua54/src/lgc.c
    source/luacore/lua54/src/linit.c
    source/luacore/lua54/src/liolib.c
    source/luacore/lua54/src/llex.c
    source/luacore/lua54/src/lmathlib.c
    source/luacore/lua54/src/lmem.c
    source/luacore/lua54/src/loadlib.c
    source/luacore/lua54/src/lobject.c
    source/luacore/lua54/src/lopcodes.c
    source/luacore/lua54/src/loslib.c
    source/luacore/lua54/src/lparser.c
    source/luacore/lua54/src/lstate.c
    source/luacore/lua54/src/lstring.c
    source/luacore/lua54/src/lstrlib.c
    source/luacore/lua54/src/ltable.c
    source/luacore/lua54/src/ltablib.c
    source/luacore/lua54/src/ltm.c
    source/luacore/lua54/src/lua.c
    source/luacore/lua54/src/lundump.c
    source/luacore/lua54/src/lutf8lib.c
    source/luacore/lua54/src/lvm.c
    source/luacore/lua54/src/lzio.c

    source/luacore/luapeg/lptree.c
    source/luacore/luapeg/lpvm.c
    source/luacore/luapeg/lpprint.c
    source/luacore/luapeg/lpcap.c
    source/luacore/luapeg/lpcode.c

)

add_library(lua STATIC ${lua_sources})

set_property(TARGET lua PROPERTY C_STANDARD 99)

target_include_directories(lua PRIVATE
    source/luacore/lua54/src
    source/luacore/luapeg
)

# luajit: 8000, lua 5.3: 1000000 or 15000

target_compile_definitions(lua PUBLIC
    # This one should also be set in the lua namespace!
  # LUAI_HASHLIMIT=6 # obsolete
  # LUAI_MAXSHORTLEN=48
    LUAI_MAXCSTACK=6000
    LUA_UCID
  # LUA_USE_JUMPTABLE=0
    LPEG_DEBUG
  # LUA_NOCVTS2N
  # LUA_NOBUILTIN # disable likely usage
  # LUAI_ASSERT
  # LUA_STRFTIMEOPTIONS="aAbBcCdDeFgGhHIjmMnprRStTuUVwWxXyYzZ%" 
  # MINSTRTABSIZE=65536
)

if (UNIX)
    target_compile_definitions(lua PUBLIC
        LUA_USE_POSIX
        LUA_USE_DLOPEN
    )
endif (UNIX)

if (NOT MSVC)
    target_compile_options(lua PRIVATE
        -Wno-cast-align
        -Wno-cast-qual
    )
endif (NOT MSVC)

if (CMAKE_HOST_APPLE)
    target_compile_definitions(lua PUBLIC
        TARGET_OS_IOS=0
        TARGET_OS_WATCH=0
        TARGET_OS_TV=0
    )
endif (CMAKE_HOST_APPLE)

# this seems to be ok for mingw default
#
# todo: what is the right way to increase the stack (mingw)

# target_compile_options(lua PRIVATE -DLUAI_MAXCSTACK=65536 -Wl,--stack,16777216)
