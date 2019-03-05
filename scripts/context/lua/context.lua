-- This file is a companion to "context(.exe)" and is effectively the same
-- as:
--
--     mtxrun -script context ...
--
-- which will locate "mtx-context.lua" and load that one. The binary is a
-- copy of "luametatex(.exe)" aka luatex 2.0 for context lmtx. In a similar
-- fashion "mtxrun(.exe)" will load the "mtrun.lua" script.
--
-- The installation of context should do this on Windows:
--
-- luametatex.exe -> tex/texmf-win64/bin/luatex.exe
-- luametatex.exe -> tex/texmf-win64/bin/mtxrun.exe
-- luametatex.exe -> tex/texmf-win64/bin/context.exe
-- mtxrun.lua     -> tex/texmf-win64/bin/mtxrun.lua
-- context.lua    -> tex/texmf-win64/bin/context.lua
--
-- and this on Unix:
--
-- luametatex     -> tex/texmf-linux-64/bin/luatex
-- luametatex     -> tex/texmf-linux-64/bin/mtxrun
-- luametatex     -> tex/texmf-linux-64/bin/context
-- mtxrun.lua     -> tex/texmf-linux-64/bin/mtxrun.lua
-- context.lua    -> tex/texmf-linux-64/bin/context.lua
--
-- The static binary is smaller than 3MB so the few copies provide no real
-- overhead.

local selfpath = os.selfpath

if not arg or not selfpath then
    print("invalid stub")
    os.exit()
end

arg[0] = "mtxrun"

table.insert(arg,1,"mtx-context")
table.insert(arg,1,"--script")

dofile(selfpath .. "/" .. "mtxrun.lua")
