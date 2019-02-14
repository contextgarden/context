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

local setmetatableindex = table.setmetatableindex
local load              = load
local xpcall            = xpcall
local instance_banner   = string.formatters["=[instance: %s]"] -- the = controls the lua error / see: lobject.c
local tex_errormessage  = context.errmessage

local implement         = interfaces.implement
local reporter          = logs.reporter

local report_instance   = reporter("lua instance")
local report_script     = reporter("lua script")
local report_thread     = reporter("lua thread")
local newline           = logs.newline

lua.numbers             = lua.numbers  or { }
lua.messages            = lua.messages or { }

local numbers           = lua.numbers
local messages          = lua.messages

storage.register("lua/numbers",  numbers,  "lua.numbers" )
storage.register("lua/messages", messages, "lua.messages")

-- First we implement a pure lua version of directlua and a persistent
-- variant of it:

local function runscript(code)
    local done, message = loadstring(code)
    if done then
        done()
    else
        newline()
        report_script("error : %s",message or "unknown")
        report_script()
        report_script("code  : %s",code)
        newline()
    end
end

local threads = setmetatableindex(function(t,k)
    local v = setmetatableindex({},global)
    t[k] = v
    return v
end)

local function runthread(name,code)
    if not code or code == "" then
        threads[name] = nil
    else
        local thread = threads[name]
        local done, message = loadstring(code,nil,nil,thread)
        if done then
            done()
        else
            newline()
            report_thread("thread: %s",name)
            report_thread("error : %s",message or "unknown")
            report_thread()
            report_thread("code  : %s",code)
            newline()
        end
    end
end

interfaces.implement {
    name      = "luascript",
    actions   = runscript,
    arguments = "string"
}

interfaces.implement {
    name      = "luathread",
    actions   = runthread,
    arguments = "2 strings",
}

-- local scanners = interfaces.scanners
--
-- local function ctxscanner(name)
--     local scanner = scanners[name]
--     if scanner then
--         scanner()
--     else
--         report("unknown scanner: %s",name)
--     end
-- end
--
-- interfaces.implement {
--     name      = "clfscanner",
--     actions   = ctxscanner,
--     arguments = "string",
-- }

local function registername(name,message)
    if not name or name == "" then
        report_instance("no valid name given")
        return
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
    local report = reporter("lua instance",message)
    local proxy = {
        -- we can access all via:
        global       = global, -- or maybe just a metatable
        -- some protected data
        moduledata   = setmetatableindex(moduledata),
        thirddata    = setmetatableindex(thirddata),
        -- less protected data
        userdata     = userdata,
        documentdata = documentdata,
        -- always there fast
        context      = context,
        --
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
            report_instance("error: %s",message or code)
        elseif not xpcall(code,report) then
            tex_errormessage("hit return to continue or quit this run")
        end
    end
end

lua.registername = registername

implement {
    name      = "registernamedlua",
    arguments = "3 strings",
    actions   = function(name,message,csname)
        if csname and csname ~= "" then
            implement {
                name      = csname,
                arguments = "string",
                actions   = registername(name,message) or report,
                scope     = "private",
            }
        else
            report_instance("unvalid csname for %a",message or name or "?")
        end
    end
}
