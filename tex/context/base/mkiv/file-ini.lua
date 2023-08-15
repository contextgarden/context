if not modules then modules = { } end modules ['file-ini'] = {
    version   = 1.001,
    comment   = "companion to file-ini.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- It's more convenient to manipulate filenames (paths) in Lua than in TeX. These
-- methods have counterparts at the TeX end.

local implement       = interfaces.implement
local setmacro        = interfaces.setmacro
local setcount        = interfaces.setcount

resolvers.jobs        = resolvers.jobs or { }

local filenametotable = file.nametotable
local findtexfile     = resolvers.findtexfile

local ctx_doifelse    = commands.doifelse

local function splitfilename(full)
    local split = filenametotable(full)
    local path  = split.path
    setcount("splitoffkind",(path == "" and 0) or (path == '.' and 1) or 2)
    setmacro("splitofffull",full or "")
    setmacro("splitoffpath",path or "")
    setmacro("splitoffname",split.name or "")
    setmacro("splitoffbase",split.base or "")
    setmacro("splitofftype",split.suffix or "")
end

local function isparentfile(name)
    return
        name == environment.jobname
     or name == environment.jobname .. '.tex'
     or name == environment.outputfilename
end

local function istexfile(name)
    local name = name and findtexfile(name)
    return name ~= "" and name
end

implement { name = "splitfilename",      actions = splitfilename,                  arguments = "string" }
implement { name = "doifelseparentfile", actions = { isparentfile, ctx_doifelse }, arguments = "string" }
implement { name = "doifelsepathexist",  actions = { lfs.isdir,    ctx_doifelse }, arguments = "string" }
implement { name = "doifelsefileexist",  actions = { istexfile,    ctx_doifelse }, arguments = "string" }
