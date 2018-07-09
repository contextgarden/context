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
local splitlines, strip = string.splitlines, string.strip
local tostring, type = tostring, type
local assignbuffer = buffers.assign

local context = context

context.tobuffer = assignbuffer -- (name,str,catcodes)

function context.tolines(str,strip)
    local lines = type(str) == "string" and splitlines(str) or str
    for i=1,#lines do
        if strip then
            context(strip(lines[i]) .. " ")
        else
            context(lines[i] .. " ")
        end
    end
end

-- local function flush(...)
--     context(concat { ..., "\r" }) -- was \n
-- end
--
-- somehow this doesn't work any longer .. i need to figure out why
--
-- local function t_tocontext(t)
--     context.starttyping { "typing" } -- else [1] is intercepted
--     context.pushcatcodes("verbatim")
--  -- tohandle(flush,...)
--     context(table.serialize(t))
--     context.stoptyping()
--     context.popcatcodes()
-- end
--
-- local function s_tocontext(first,second,...) -- we need to catch {\}
--     context.type()
--     context("{")
--     context.pushcatcodes("verbatim")
--     if second then
--         context(concat({ first, second, ... }, " "))
--     else
--         context(first) -- no need to waste a { }
--     end
--     context.popcatcodes()
--     context("}")
-- end

local t_buffer = { "t_o_c_o_n_t_e_x_t" }
local t_typing = { "typing" }
local t_type   = { "type" }

local function flush(s,inline)
    assignbuffer("t_o_c_o_n_t_e_x_t",s)
    context[inline and "typeinlinebuffer" or "typebuffer"](t_buffer)
    context.resetbuffer(t_buffer)
end

local function t_tocontext(t)
    local s = table.serialize(t)
    context(function() flush(s,false) end)
end

local function s_tocontext(first,second,...) -- we need to catch {\}
    local s = second and concat({ first, second, ... }, " ") or first
    context(function() flush(s,true) end)
end

local function b_tocontext(b)
    s_tocontext(tostring(b))
end

table  .tocontext = t_tocontext
string .tocontext = s_tocontext
boolean.tocontext = b_tocontext
number .tocontext = s_tocontext

local tocontext = {
    ["string"]   = s_tocontext,
    ["table"]    = t_tocontext,
    ["boolean"]  = b_tocontext,
    ["number"]   = s_tocontext,
    ["function"] = function() s_tocontext("<function>") end,
    ["nil"]      = function() s_tocontext("<nil>") end,
 -- ------------ = -------- can be extended elsewhere
}

table.setmetatableindex(tocontext,function(t,k)
    local v = function(s)
        s_tocontext("<"..tostring(s)..">")
    end
    t[k] = v
    return v
end)

table.setmetatablecall(tocontext,function(t,k,...)
    tocontext[type(k)](k)
end)

context.tocontext = tocontext

