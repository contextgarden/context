if not modules then modules = { } end modules ['mlib-lua'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local type = type
local insert, remove = table.insert, table.remove

local set = mp.set
local get = mp.get

local currentmpx = nil
local stack      = { }

local get_numeric = mplib.get_numeric
local get_integer = mplib.get_integer
local get_string  = mplib.get_string
local get_boolean = mplib.get_boolean
local get_path    = mplib.get_path
local set_path    = mplib.set_path

get.numeric = function(s)   return get_numeric(currentmpx,s)   end
get.number  = function(s)   return get_numeric(currentmpx,s)   end
get.integer = function(s)   return get_integer(currentmpx,s)   end
get.string  = function(s)   return get_string (currentmpx,s)   end
get.boolean = function(s)   return get_boolean(currentmpx,s)   end
get.path    = function(s)   return get_path   (currentmpx,s)   end
set.path    = function(s,t) return set_path   (currentmpx,s,t) end -- not working yet

function metapost.pushscriptrunner(mpx)
    insert(stack,mpx)
    currentmpx = mpx
end

function metapost.popscriptrunner()
    currentmpx = remove(stack,mpx)
end

function metapost.currentmpx()
    return currentmpx
end

local status = mplib.status

function metapost.currentmpxstatus()
    return status and status(currentmpx) or 0
end
