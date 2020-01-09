if not modules then modules = { } end modules ['libs-ini'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is a loader for optional libraries in luametatex with context lmtx. It's
-- kind of experimental. We also use a different locator than in mkiv because we
-- don't support loading lua libraries and swiglibs any more. Of course one can
-- try the regular lua loaders but we just assume that a user then knows what (s)he
-- is doing.

local type, unpack = type, unpack

-- here we implement the resolver

local type = type

local nameonly      = file.nameonly
local joinfile      = file.join
local addsuffix     = file.addsuffix
local qualifiedpath = file.is_qualified_path

local isfile        = lfs.isfile

local findfile      = resolvers.findfile
local expandpaths   = resolvers.expandedpathlistfromvariable

local report        = logs.reporter("resolvers","libraries")
local trace         = false

trackers.register("resolvers.lib", function(v) trace = v end)

local function findlib(required) -- todo: cache
    local suffix = os.libsuffix or "so"
    if not qualifiedpath(required) then
        local list = directives.value("system.librarynames" )
        local only = nameonly(required)
        if type(list) == "table" then
            list = list[only]
            if type(list) ~= "table" then
                list = { only }
            end
        else
            list = { only }
        end
        if trace then
            report("using lookup list for library %a: % | t",only,list)
        end
        for i=1,#list do
            local name  = list[i]
            local found = findfile(name,"lib")
            if not found then
                found = findfile(addsuffix(name,suffix),"lib")
            end
            if found then
                if trace then
                    report("library %a resolved via %a path to %a",name,"tds lib",found)
                end
                return found
            end
        end
        if expandpaths then
            local list = expandpaths("PATH")
            local base = addsuffix(only,suffix)
            for i=1,#list do
                local full  = joinfile(list[i],base)
                local found = isfile(full) and full
                if found then
                    if trace then
                        report("library %a resolved via %a path to %a",name,"system",found)
                    end
                    return found
                end
            end
        end
    elseif isfile(addsuffix(required,suffix)) then
        if trace then
            report("library with qualified name %a %sfound",required,"")
        end
        return required
    else
        if trace then
            report("library with qualified name %a %sfound",required,"not ")
        end
    end
    return false
end

local foundlibraries = table.setmetatableindex(function(t,k)
    local v = findlib(k)
    t[k] = v
    return v
end)

function resolvers.findlib(required)
    return foundlibraries[required]
end

-- here we implement the loader

local libraries     = { }
resolvers.libraries = libraries

local report        = logs.reporter("optional")

function libraries.validoptional(name)
    local thelib = optional and optional[name]
    if not thelib then
        -- forget about it, no message here
    elseif thelib.initialize then
        return thelib
    else
        report("invalid optional library %a",libname)
    end
end

function libraries.optionalloaded(name,libnames)
    local thelib = optional and optional[name]
    if not thelib then
        report("no optional %a library found",name)
    else
        local thelib_initialize = thelib.initialize
        if not thelib_initialize then
            report("invalid optional library %a",name)
        else
            if type(libnames) == "string" then
                libnames = { libnames }
            end
            if type(libnames) == "table" then
                for i=1,#libnames do
                    local libname  = libnames[i]
                    local filename = foundlibraries[libname]
                    if filename then
                        libnames[i] = filename
                    else
                        report("unable to locate library %a",libname)
                        return
                    end
                end
                local initialized = thelib_initialize(unpack(libnames))
                if initialized then
                    report("using library '% + t'",libnames)
                else
                    report("unable to initialize library '% + t'",libnames)
                end
                return initialized
            end
        end
    end
end

-- local patterns = {
--     "libs-imp-%s.mkxl",
--     "libs-imp-%s.mklx",
-- }
--
-- local function action(name,foundname)
--     -- could be one command
--     context.startreadingfile()
--     context.input(foundname)
--     context.stopreadingfile()
-- end
--
-- interfaces.implement {
--     name      = "uselibrary",
--     arguments = "string"
--     actions   = function(name)
--         resolvers.uselibrary {
--             category = "color definition",
--             name     = name,
--             patterns = patterns,
--             action   = action,
--             onlyonce = true,
--         }
--     end
-- }
