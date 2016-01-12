if not modules then modules = { } end modules ['cldf-ver'] = {
    version   = 1.001,
    comment   = "companion to cldf-ver.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We have better verbatim: context.verbatim so that needs to be looked
-- into. We can also directly store in buffers although this variant works
-- better when used mixed with other code (synchronization issue).

local concat, tohandle = table.concat, table.tohandle
local find, splitlines = string.find, string.splitlines
local tostring, type = tostring, type

local context = context

local function flush(...)
    context(concat{...,"\r"}) -- was \n
end

local function t_tocontext(...)
    context.starttyping { "typing" } -- else [1] is intercepted
    context.pushcatcodes("verbatim")
    tohandle(flush,...) -- ok?
    context.stoptyping()
    context.popcatcodes()
end

local function s_tocontext(...) -- we need to catch {\}
    context.type()
    context("{")
    context.pushcatcodes("verbatim")
    context(concat({...}," "))
    context.popcatcodes()
    context("}")
end

local function b_tocontext(b)
    s_tocontext(tostring(b))
end

table  .tocontext = t_tocontext
string .tocontext = s_tocontext
boolean.tocontext = b_tocontext

function context.tocontext(first,...)
    local t = type(first)
    if t == "string" then
        s_tocontext(first,...)
    elseif t == "table" then
        t_tocontext(first,...)
    elseif t == "boolean" then
        b_tocontext(first,...)
    end
end

-- function context.tobuffer(name,str)
--     context.startbuffer { name }
--     context.pushcatcodes("verbatim")
--     local lines = (type(str) == "string" and find(str,"[\n\r]") and splitlines(str)) or str
--     for i=1,#lines do
--         context(lines[i] .. " ")
--     end
--     context.stopbuffer()
--     context.popcatcodes()
-- end

context.tobuffer = buffers.assign -- (name,str,catcodes)

function context.tolines(str)
    local lines = type(str) == "string" and splitlines(str) or str
    for i=1,#lines do
        context(lines[i] .. " ")
    end
end
