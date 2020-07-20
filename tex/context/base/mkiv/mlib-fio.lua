if not modules then modules = { } end modules ['mlib-run'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local concat = table.concat
local mplib  = mplib

local report_logger = logs.reporter("metapost log")
local report_error  = logs.reporter("metapost error")

local l, nl, dl = { }, 0, false
local t, nt, dt = { }, 0, false
local e, ne, de = { }, 0, false

mplib.realtimelogging = false

local function logger(target,str)
    if target == 1 then
        -- log
    elseif target == 2 or target == 3 then
        -- term
        if str == "\n" then
            mplib.realtimelogging = true
            if nl > 0 then
                report_logger(concat(l,"",1,nl))
                nl, dl = 0, false
            elseif not dl then
                report_logger("")
                dl = true
            end
        else
            nl = nl + 1
            l[nl] = str
        end
    elseif target == 4 then
        report_error(str)
    end
end

local finders = { }
mplib.finders = finders -- also used in meta-lua.lua

local new_instance = mplib.new

local function validftype(ftype)
    if ftype == "mp" then
        return "mp"
    else
        return nil
    end
end

finders.file = function(specification,name,mode,ftype)
    return resolvers.findfile(name,validftype(ftype))
end

local function i_finder(name,mode,ftype) -- fake message for mpost.map and metafun.mpvi
    local specification = url.hashed(name)
    local finder = finders[specification.scheme] or finders.file
    local found = finder(specification,name,mode,validftype(ftype))
    return found
end

local function o_finder(name,mode,ftype)
    return name
end

o_finder = sandbox.register(o_finder,sandbox.filehandlerone,"mplib output finder")

local function finder(name,mode,ftype)
    return (mode == "w" and o_finder or i_finder)(name,mode,validftype(ftype))
end

function mplib.new(specification)
    specification.find_file  = finder
    specification.run_logger = logger
    return new_instance(specification)
end

mplib.finder = finder

