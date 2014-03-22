if not modules then modules = { } end modules ['luat-ini'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- rather experimental down here ... adapted to lua 5.2 ... but still
-- experimental

local debug = require("debug")

local string, table, lpeg, math, io, system = string, table, lpeg, math, io, system
local rawset, rawget, next, setmetatable = rawset, rawget, next, setmetatable

--[[ldx--
<p>We cannot load anything yet. However what we will do us reserve a few tables.
These can be used for runtime user data or third party modules and will not be
cluttered by macro package code.</p>
--ldx]]--

userdata      = userdata      or { } -- for users (e.g. functions etc)
thirddata     = thirddata     or { } -- only for third party modules
moduledata    = moduledata    or { } -- only for development team
documentdata  = documentdata  or { } -- for users (e.g. raw data)
parametersets = parametersets or { } -- experimental for team

table.setmetatableindex(moduledata,table.autokey)
table.setmetatableindex(thirddata, table.autokey)

--[[ldx--
<p>Please create a namespace within these tables before using them!</p>

<typing>
userdata ['my.name'] = { }
thirddata['tricks' ] = { }
</typing>
--ldx]]--

--[[ldx--
<p>We could cook up a readonly model for global tables but it makes more sense
to invite users to use one of the predefined namespaces. One can redefine the
protector. After all, it's just a lightweight suggestive system, not a
watertight one.</p>
--ldx]]--

local global  = _G
global.global = global

local dummy = function() end

--[[ldx--
<p>Another approach is to freeze tables by using a metatable, this will be
implemented stepwise.</p>
--ldx]]--

-- moduledata  : no need for protection (only for developers)
-- isolatedata : full protection
-- userdata    : protected
-- thirddata   : protected

--[[ldx--
<p>We could have a metatable that automaticaly creates a top level namespace.</p>
--ldx]]--

local luanames = lua.name -- luatex itself

lua.numbers  = lua.numbers  or { } local numbers  = lua.numbers
lua.messages = lua.messages or { } local messages = lua.messages

storage.register("lua/numbers",  numbers,  "lua.numbers" )
storage.register("lua/messages", messages, "lua.messages")

local f_message = string.formatters["=[instance: %s]"] -- the = controls the lua error / see: lobject.c

local setfenv = setfenv or debug.setfenv -- < 5.2

if setfenv then

    local protected = {
        -- global table
        global       = global,
        -- user tables
     -- moduledata   = moduledata,
        userdata     = userdata,
        thirddata    = thirddata,
        documentdata = documentdata,
        -- reserved
        protect      = dummy,
        unprotect    = dummy,
        -- luatex
        tex          = tex,
        -- lua
        string       = string,
        table        = table,
        lpeg         = lpeg,
        math         = math,
        io           = io,
        file         = file,
        bit32        = bit32,
        --
        context      = context,
    }

    local protect_full = function(name)
        local t = { }
        for k, v in next, protected do
            t[k] = v
        end
        return t
    end

    local protect_part = function(name) -- adds
        local t = rawget(global,name)
        if not t then
            t = { }
            for k, v in next, protected do
                t[k] = v
            end
            rawset(global,name,t)
        end
        return t
    end

    protect = function(name)
        if name == "isolateddata" then
            setfenv(2,protect_full(name))
        else
            setfenv(2,protect_part(name or "shareddata"))
        end
    end

    function lua.registername(name,message)
        local lnn = lua.numbers[name]
        if not lnn then
            lnn = #messages + 1
            messages[lnn] = message
            numbers[name] = lnn
        end
        luanames[lnn] = message
        context(lnn)
        -- initialize once
        if name ~= "isolateddata" then
            protect_full(name or "shareddata")
        end
    end

elseif libraries then  -- assume >= 5.2

    local shared

    protect = function(name)
        if not shared then
            -- e.g. context is not yet known
            local public = {
                global       = global,
             -- moduledata   = moduledata,
                userdata     = userdata,
                thirddata    = thirddata,
                documentdata = documentdata,
                protect      = dummy,
                unprotect    = dummy,
                context      = context,
            }
            --
            for k, v in next, libraries.builtin   do public[k] = v   end
            for k, v in next, libraries.functions do public[k] = v   end
            for k, v in next, libraries.obsolete  do public[k] = nil end
            --
            shared = { __index = public }
            protect = function(name)
                local t = global[name] or { }
                setmetatable(t,shared) -- set each time
                return t
            end
        end
        return protect(name)
    end

    function lua.registername(name,message)
        local lnn = lua.numbers[name]
        if not lnn then
            lnn = #messages + 1
            messages[lnn] = message
            numbers[name] = lnn
        end
        luanames[lnn] = f_message(message)
        context(lnn)
    end

else

    protect = dummy

    function lua.registername(name,message)
        local lnn = lua.numbers[name]
        if not lnn then
            lnn = #messages + 1
            messages[lnn] = message
            numbers[name] = lnn
        end
        luanames[lnn] = f_message(message)
        context(lnn)
    end

end

