if not modules then modules = { } end modules ['luat-usr'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local global            = global

local moduledata        = moduledata
local thirddata         = thirddata
local userdata          = userdata
local documentdata      = documentdata

local context           = context
local tostring          = tostring
local tonumber          = tonumber
local print             = print

local string            = string
local table             = table
local lpeg              = lpeg
local math              = math
local io                = io
local os                = os
local lpeg              = lpeg

local luanames          = lua.name -- luatex itself

local setmetatableindex = table.setmetatableindex
local load              = load
local xpcall            = xpcall
local instance_banner   = string.formatters["=[instance: %s]"] -- the = controls the lua error / see: lobject.c
local tex_errormessage  = context.errmessage

local implement         = interfaces.implement
local reporter          = logs.reporter

local report            = reporter("lua instance")

lua.numbers             = lua.numbers  or { }
lua.messages            = lua.messages or { }

local numbers           = lua.numbers
local messages          = lua.messages

storage.register("lua/numbers",  numbers,  "lua.numbers" )
storage.register("lua/messages", messages, "lua.messages")

local function registername(name,message)
    if not name or name == "" then
        report("no valid name given")
        return
    end
    if not message or message == "" then
        message = name
    end
    if not message or message == "" then
        message = name
    end
    local lnn = numbers[name]
    if not lnn then
        lnn = #messages + 1
        messages[lnn] = message
        numbers[name] = lnn
    end
    luanames[lnn] = instance_banner(message)
    local report = reporter("lua instance",message)
    local proxy = {
        -- we can access all via:
        global       = global,
        -- some protected data
        moduledata   = setmetatableindex(moduledata),    --
        thirddata    = setmetatableindex(thirddata),
        -- less protected data
        userdata     = userdata,
        documentdata = documentdata,
        -- always there fast
        context      = context,
        tostring     = tostring,
        tonumber     = tonumber,
        -- standard lua modules
        string       = string,
        table        = table,
        lpeg         = lpeg,
        math         = math,
        io           = io,
        os           = os,
        lpeg         = lpeg,
        --
        print        = print,
        report       = report,
    }
    return function(code)
        local code, message = load(code,nil,nil,proxy)
        if not code then
            report("error: %s",message or code)
        elseif not xpcall(code,report) then
            tex_errormessage("hit return to continue or quit this run")
        end
    end
end

lua.registername = registername

implement {
    name      = "registernamedlua",
    arguments = { "string", "string", "string" },
    actions   = function(name,message,csname)
        if csname and csname ~= "" then
            implement {
                name      = csname,
                arguments = "string",
                actions   = registername(name,message) or report,
                scope     = "private",
            }
        else
            report("unvalid csname for %a",message or name or "?")
        end
    end
}
