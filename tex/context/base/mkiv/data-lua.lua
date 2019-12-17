if not modules then modules = { } end modules ['data-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is now a plug in into l-lua (as we also use the extra paths elsewhere).

local package, lpeg = package, lpeg

local loadfile = loadfile
local addsuffix = file.addsuffix

local P, S, Cs, lpegmatch = lpeg.P, lpeg.S, lpeg.Cs, lpeg.match

local luasuffixes   = { 'tex', 'lua' }
local libsuffixes   = { 'lib' }
local luaformats    = { 'TEXINPUTS', 'LUAINPUTS' }
local libformats    = { 'CLUAINPUTS' }
local helpers       = package.helpers or { }
local methods       = helpers.methods or { }

local resolvers     = resolvers
local resolveprefix = resolvers.resolve
local expandedpaths = resolvers.expandedpathlistfromvariable
local findfile      = resolvers.findfile

helpers.report      = logs.reporter("resolvers","libraries")

trackers.register("resolvers.libraries", function(v) helpers.trace = v end)
trackers.register("resolvers.locating",  function(v) helpers.trace = v end)

helpers.sequence = {
    "already loaded",
    "preload table",
    "lua variable format",
    "lib variable format",
    "lua extra list",
    "lib extra list",
    "path specification",
    "cpath specification",
    "all in one fallback",
    "not loaded",
}

local pattern = Cs(P("!")^0 / "" * (P("/") * P(-1) / "/" + P("/")^1 / "/" + 1)^0)

function helpers.cleanpath(path) -- hm, don't we have a helper for this?
    return resolveprefix(lpegmatch(pattern,path))
end

local loadedaslib   = helpers.loadedaslib
local registerpath  = helpers.registerpath
local lualibfile    = helpers.lualibfile

local luaformatpaths
local libformatpaths

local function getluaformatpaths()
    if not luaformatpaths then
        luaformatpaths = { }
        for i=1,#luaformats do
            registerpath("lua format","lua",luaformatpaths,expandedpaths(luaformats[i]))
        end
    end
    return luaformatpaths
end

local function getlibformatpaths()
    if not libformatpaths then
        libformatpaths = { }
        for i=1,#libformats do
            registerpath("lib format","lib",libformatpaths,expandedpaths(libformats[i]))
        end
    end
    return libformatpaths
end

local function loadedbyformat(name,rawname,suffixes,islib,what)
    local trace  = helpers.trace
    local report = helpers.report
    for i=1,#suffixes do -- so we use findfile and not a lookup loop
        local format   = suffixes[i]
        local resolved = findfile(name,format) or ""
        if trace then
            report("%s format, identifying %a using format %a",what,name,format)
        end
        if resolved ~= "" then
            if trace then
                report("%s format, %a found on %a",what,name,resolved)
            end
            if islib then
                return loadedaslib(resolved,rawname)
            else
                return loadfile(resolved)
            end
        end
    end
end

helpers.loadedbyformat = loadedbyformat

-- print(lualibfile("bar"))
-- print(lualibfile("foo.bar"))
-- print(lualibfile("crap/foo...bar"))
-- print(lualibfile("crap//foo.bar"))
-- print(lualibfile("crap/../foo.bar"))
-- print(lualibfile("crap/.././foo.bar"))

-- alternatively we could split in path and base and temporary set the libpath to path

-- we could build a list of relevant paths but for tracing it's better to have the
-- whole lot (ok, we could skip the duplicates)

methods["lua variable format"] = function(name)
    if helpers.trace then
        helpers.report("%s format, checking %s paths","lua",#getluaformatpaths()) -- call triggers building
    end
    return loadedbyformat(addsuffix(lualibfile(name),"lua"),name,luasuffixes,false,"lua")
end

methods["lib variable format"] = function(name)
    if helpers.trace then
        helpers.report("%s format, checking %s paths","lib",#getlibformatpaths()) -- call triggers building
    end
    return loadedbyformat(addsuffix(lualibfile(name),os.libsuffix),name,libsuffixes,true,"lib")
end

-- package.extraclibpath(environment.ownpath)

resolvers.loadlualib = require -- hm
