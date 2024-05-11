This is Lua 5.4 as taken from: https://github.com/lua/lua.git (intermediate releases). For
installation instructions, license details, and further information about Lua, see the
documentation of LUA.

There is a pitfall in using release candidates: when the bytecode organization changes
we can get crashes. At some point the luac version became an integer so we could encode
a subnumber but that was reverted to a byte. This means that we again can get crashes
(unless we mess a bit with that byte). It makes usage a bit fragile but so be it.
