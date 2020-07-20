if not modules then modules = { } end modules ['libs-imp-mujs'] = {
    version   = 1.001,
    comment   = "companion to luat-imp-mujs.mkxl",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is an experiment. When a new user knows \JAVASCRIPT\ it can be a
-- stepping stone to using \LUA.

-- local ecmascript = optional.mujs.initialize("libmujs")
-- local execute    = optional.mujs.execute

local libname = "mujs"
local libfile = "libmujs"

if package.loaded[libname] then
    return package.loaded[libname]
end

local mujslib = resolvers.libraries.validoptional(libname)

if not mujslib then
    return
end

local files    = { }
local openfile = io.open
local findfile = resolvers.findfile

local mujs_execute = mujslib.execute
local mujs_dofile  = mujslib.dofile
local mujs_reset   = mujslib.reset

local function okay()
    if resolvers.libraries.optionalloaded(libname,libfile) then
        mujs_execute(
            "var catcodes = { " ..
                "'tex': " .. tex.texcatcodes .. "," ..
                "'ctx': " .. tex.ctxcatcodes .. "," ..
                "'prt': " .. tex.prtcatcodes .. "," ..
                "'vrb': " .. tex.vrbcatcodes .. "," ..
            "};"
        )
        okay = function() return true end
    else
        okay = function() return false end
    end
    return okay()
end

mujslib.setfindfile(findfile)

mujslib.setopenfile(function(name)
    local full = findfile(name)
    if full then
        local f = openfile(full,"rb")
        if f then
            for i=1,100 do
                if not files[i] then
                    files[i] = f
                    return i
                end
            end
        end
    end
end)

mujslib.setclosefile(function(id)
    local f = files[id]
    if f then
        f:close()
        files[id] = false
    end
end)

mujslib.setreadfile(function(id,how)
    local f = files[id]
    if f then
        return (f:read(how or "*l"))
    end
end)

mujslib.setseekfile(function(id,whence,offset)
    local f = files[id]
    if f then
        return (f:seek(whence,offset))
    end
end)

local reporters = {
    console = logs.reporter("mujs","console"),
    report  = logs.reporter("mujs","report"),
}

mujslib.setconsole(function(category,name)
    reporters[category](name)
end)

local mujs = {
    ["execute"] = function(c,s) if okay() then mujs_execute(c,s) end end,
    ["dofile"]  = function(n)   if okay() then mujs_dofile(n)    end end,
    ["reset"]   = function(n)   if okay() then mujs_reset(n)     end end,
}

package.loaded[libname] = mujs

optional.loaded.mujs = mujs

interfaces.implement {
    name      = "ecmacode",
    actions   = mujs.execute,
    arguments = "string",
    public    = true,
}

interfaces.implement {
    name      = "ecmafile",
    actions   = mujs.dofile,
    arguments = "string",
    public    = true,
    protected = true,
}

return mujs
