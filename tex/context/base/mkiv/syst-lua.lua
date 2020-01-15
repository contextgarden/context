if not modules then modules = { } end modules ['syst-lua'] = {
    version   = 1.001,
    comment   = "companion to syst-lua.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find = string.find
local S, C, P, lpegmatch, lpegtsplitat = lpeg.S, lpeg.C, lpeg.P, lpeg.match, lpeg.tsplitat

commands        = commands or { }
local commands  = commands
local context   = context
local implement = interfaces.implement

local ctx_protected_cs         = context.protected.cs -- more efficient
local ctx_firstoftwoarguments  = context.firstoftwoarguments
local ctx_secondoftwoarguments = context.secondoftwoarguments
local ctx_firstofoneargument   = context.firstofoneargument
local ctx_gobbleoneargument    = context.gobbleoneargument

local two_strings = interfaces.strings[2]

implement { -- will be overloaded later
    name      = "writestatus",
    arguments = two_strings,
    actions   = logs.status,
}

function commands.doifelse(b)
    if b then
        ctx_firstoftwoarguments()
    else
        ctx_secondoftwoarguments()
    end
end

function commands.doifelsesomething(b)
    if b and b ~= "" then
        ctx_firstoftwoarguments()
    else
        ctx_secondoftwoarguments()
    end
end

function commands.doif(b)
    if b then
        ctx_firstofoneargument()
    else
        ctx_gobbleoneargument()
    end
end

function commands.doifsomething(b)
    if b and b ~= "" then
        ctx_firstofoneargument()
    else
        ctx_gobbleoneargument()
    end
end

function commands.doifnot(b)
    if b then
        ctx_gobbleoneargument()
    else
        ctx_firstofoneargument()
    end
end

function commands.doifnotthing(b)
    if b and b ~= "" then
        ctx_gobbleoneargument()
    else
        ctx_firstofoneargument()
    end
end

commands.testcase = commands.doifelse -- obsolete

function commands.boolcase(b)
    context(b and 1 or 0)
end

function commands.doifelsespaces(str)
    if find(str,"^ +$") then
        ctx_firstoftwoarguments()
    else
        ctx_secondoftwoarguments()
    end
end

local pattern = lpeg.patterns.validdimen

function commands.doifelsedimenstring(str)
    if lpegmatch(pattern,str) then
        ctx_firstoftwoarguments()
    else
        ctx_secondoftwoarguments()
    end
end

local p_first = C((1-P(",")-P(-1))^0)

implement {
    name      = "firstinset",
    arguments = "string",
    actions   = function(str) context(lpegmatch(p_first,str or "")) end,
    public    = true,
}

implement {
    name      = "ntimes",
    arguments = { "string", "integer" },
    actions   = { string.rep, context }
}

implement {
    name      = "execute",
    arguments = "string",
    actions   = os.execute -- wrapped in sandbox
}

implement {
    name      = "doifelsesame",
    arguments = two_strings,
    actions   = function(a,b)
        if a == b then
            ctx_firstoftwoarguments()
        else
            ctx_secondoftwoarguments()
        end
    end
}

implement {
    name      = "doifsame",
    arguments = two_strings,
    actions   = function(a,b)
        if a == b then
            ctx_firstofoneargument()
        else
            ctx_gobbleoneargument()
        end
    end
}

implement {
    name      = "doifnotsame",
    arguments = two_strings,
    actions   = function(a,b)
        if a == b then
            ctx_gobbleoneargument()
        else
            ctx_firstofoneargument()
        end
    end
}

-- This is a bit of a joke as I never really needed floating point expressions (okay,
-- maybe only with scaling because there one can get numbers that are too large for
-- dimensions to deal with). Of course one can write a parser in \TEX\ speak but then
-- one also needs to implement a bunch of functions. It doesn't pay of so we just
-- stick to the next gimmick. It looks inefficient but performance is actually quite
-- efficient.

local concat = table.concat
local utfchar = utf.char
local load, type, tonumber = load, type, tonumber

local xmath    = xmath    or math
local xcomplex = xcomplex or { }

local cmd          = tokens.commands

local get_next     = token.get_next
local get_command  = token.get_command
local get_mode     = token.get_mode
local get_index    = token.get_index
local get_csname   = token.get_csname
local get_macro    = token.get_macro

local put_next     = token.put_next

local scan_token   = token.scan_token

local getdimen     = tex.getdimen
local getglue      = tex.getglue
local getcount     = tex.getcount
local gettoks      = tex.gettoks
local gettex       = tex.get

local context      = context
local dimenfactors = number.dimenfactors

local result = { "return " }
local word   = { }
local r      = 1
local w      = 0

local report = logs.reporter("system","expression")

local function unexpected(c)
    report("unexpected token %a",c)
end

local function expression()
    local w = 0
    local r = 1
    while true do
        local t = get_next()
        local n = get_command(t)
        local c = cmd[n]
        -- todo, helper: returns number
        if c == "letter"  then
            w = w + 1 ; word[w] = utfchar(get_mode(t))
        else
            if w > 0 then
                local s = concat(word,"",1,w)
                local d = dimenfactors[s]
                if d then
                    r = r + 1 ; result[r] = "*"
                    r = r + 1 ; result[r] = 1/d
                else
                    if xmath[s] then
                        r = r + 1 ; result[r] = "xmath."
                    elseif xcomplex[s] then
                        r = r + 1 ; result[r] = "xcomplex."
                    end
                    r = r + 1 ; result[r] = s
                end
                w = 0
            end
            if     c == "other_char" then
                r = r + 1 ; result[r] = utfchar(get_mode(t))
            elseif c == "spacer" then
             -- r = r + 1 ; result[r] = " "
            elseif c == "relax" then
                break
            elseif c == "assign_int" then
                r = r + 1 ; result[r] = getcount(get_index(t))
            elseif c == "assign_dimen" then
                r = r + 1 ; result[r] = getdimen(get_index(t))
            elseif c == "assign_glue" then
                r = r + 1 ; result[r] = getglue(get_index(t))
            elseif c == "assign_toks" then
                r = r + 1 ; result[r] = gettoks(get_index(t))
            elseif c == "char_given" or c == "math_given" or c == "xmath_given" then
                r = r + 1 ; result[r] = get_mode(t)
            elseif c == "last_item" then
                local n = get_csname(t)
                if n then
                    local s = gettex(n)
                    if s then
                        r = r + 1 ; result[r] = s
                    else
                        unexpected(c)
                    end
                else
                    unexpected(c)
                end
            elseif c == "call" then
                local n = get_csname(t)
                if n then
                    local s = get_macro(n)
                    if s then
                        r = r + 1 ; result[r] = s
                    else
                        unexpected(c)
                    end
                else
                    unexpected(c)
                end
            elseif c == "the" or c == "convert" or c == "lua_expandable_call" then
                put_next(t)
                scan_token() -- expands
            else
                unexpected(c)
            end
        end
    end
    local code = concat(result,"",1,r)
    local func = load(code)
    if type(func) == "function" then
        context(func())
    else
        report("invalid lua %a",code)
    end
end

-- local letter_code              <const> = cmd.letter
-- local other_char_code          <const> = cmd.other_char
-- local spacer_code              <const> = cmd.spacer
-- local other_char_code          <const> = cmd.other_char
-- local relax_code               <const> = cmd.relax
-- local assign_int_code          <const> = cmd.assign_int
-- local assign_dimen_code        <const> = cmd.assign_dimen
-- local assign_glue_code         <const> = cmd.assign_glue
-- local assign_toks_code         <const> = cmd.assign_toks
-- local char_given_code          <const> = cmd.char_given
-- local math_given_code          <const> = cmd.math_given
-- local xmath_given_code         <const> = cmd.xmath_given
-- local last_item_code           <const> = cmd.last_item
-- local call_code                <const> = cmd.call
-- local the_code                 <const> = cmd.the
-- local convert_code             <const> = cmd.convert
-- local lua_expandable_call_code <const> = cmd.lua_expandable_call
--
-- local function unexpected(c)
--     report("unexpected token %a",c)
-- end
--
-- local function expression()
--     local w = 0
--     local r = 1
--     while true do
--         local t = get_next()
--         local n = get_command(t)
--         if n == letter_code  then
--             w = w + 1 ; word[w] = utfchar(get_mode(t))
--         else
--             if w > 0 then
--                 -- we could use a metatable for all math, complex and factors
--                 local s = concat(word,"",1,w)
--                 local d = dimenfactors[s]
--                 if d then
--                     r = r + 1 ; result[r] = "*"
--                     r = r + 1 ; result[r] = 1/d
--                 else
--                     if xmath[s] then
--                         r = r + 1 ; result[r] = "xmath."
--                     elseif xcomplex[s] then
--                         r = r + 1 ; result[r] = "xcomplex."
--                     end
--                     r = r + 1 ; result[r] = s
--                 end
--                 w = 0
--             end
--             if     n == other_char_code then
--                 r = r + 1 ; result[r] = utfchar(get_mode(t))
--             elseif n == spacer_code then
--              -- r = r + 1 ; result[r] = " "
--             elseif n == relax_code then
--                 break
--             elseif n == assign_int_code then
--                 r = r + 1 ; result[r] = getcount(get_index(t))
--             elseif n == assign_dimen_code then
--                 r = r + 1 ; result[r] = getdimen(get_index(t))
--             elseif n == assign_glue_code then
--                 r = r + 1 ; result[r] = getglue(get_index(t))
--             elseif n == assign_toks_code then
--                 r = r + 1 ; result[r] = gettoks(get_index(t))
--             elseif n == char_given_code or n == math_given_code or n == xmath_given_code then
--                 r = r + 1 ; result[r] = get_mode(t)
--             elseif n == last_item_code then
--                 local n = get_csname(t)
--                 if n then
--                     local s = gettex(n)
--                     if s then
--                         r = r + 1 ; result[r] = s
--                     else
--                         unexpected(c)
--                     end
--                 else
--                     unexpected(c)
--                 end
--             elseif n == call_code then
--                 local n = get_csname(t)
--                 if n then
--                     local s = get_macro(n)
--                     if s then
--                         r = r + 1 ; result[r] = s
--                     else
--                         unexpected(c)
--                     end
--                 else
--                     unexpected(c)
--                 end
--             elseif n == the_code or n == convert_code or n == lua_expandable_call_code then
--                 put_next(t)
--                 scan_token() -- expands
--             else
--                 unexpected(c)
--             end
--         end
--     end
--     local code = concat(result,"",1,r)
--     local func = load(code)
--     if type(func) == "function" then
--         context(func())
--     else
--         report("invalid lua %a",code)
--     end
-- end

implement {
    public  = true,
    name    = "expression",
    actions = expression,
}
