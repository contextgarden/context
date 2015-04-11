if not modules then modules = { } end modules ['lang-url'] = {
    version   = 1.001,
    comment   = "companion to lang-url.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utfcharacters, utfvalues, utfbyte, utfchar = utf.characters, utf.values, utf.byte, utf.char

local commands  = commands
local context   = context

local implement = interfaces.implement

local variables = interfaces.variables
local v_before  = variables.before
local v_after   = variables.after

local is_letter = characters.is_letter

--[[
<p>Hyphenating <l n='url'/>'s is somewhat tricky and a matter of taste. I did
consider using a dedicated hyphenation pattern or dealing with it by node
parsing, but the following solution suits as well. After all, we're mostly
dealing with <l n='ascii'/> characters.</p>
]]--

commands.hyphenatedurl = commands.hyphenatedurl or { }
local hyphenatedurl    = commands.hyphenatedurl

local characters = utilities.storage.allocate {
    ["!"]  = "before",
    ["\""] = "before",
    ["#"]  = "before",
    ["$"]  = "before",
    ["%"]  = "before",
    ["&"]  = "before",
    ["("]  = "before",
    ["*"]  = "before",
    ["+"]  = "before",
    [","]  = "before",
    ["-"]  = "before",
    ["."]  = "before",
    ["/"]  = "before",
    [":"]  = "before",
    [";"]  = "before",
    ["<"]  = "before",
    ["="]  = "before",
    [">"]  = "before",
    ["?"]  = "before",
    ["@"]  = "before",
    ["["]  = "before",
    ["\\"] = "before",
    ["^"]  = "before",
    ["_"]  = "before",
    ["`"]  = "before",
    ["{"]  = "before",
    ["|"]  = "before",
    ["~"]  = "before",

    ["'"]  = "after",
    [")"]  = "after",
    ["]"]  = "after",
    ["}"]  = "after",
}

local mapping = utilities.storage.allocate {
  -- [utfchar(0xA0)] = "~", -- nbsp (catch)
}

hyphenatedurl.characters     = characters
hyphenatedurl.mapping        = mapping
hyphenatedurl.lefthyphenmin  = 2
hyphenatedurl.righthyphenmin = 3
hyphenatedurl.discretionary  = nil

-- more fun is to write nodes .. maybe it's nicer to do this
-- in an attribute handler anyway

-- local ctx_a = context.a
-- local ctx_b = context.b
-- local ctx_d = context.d
-- local ctx_n = context.n
-- local ctx_s = context.s

-- local function action(hyphenatedurl,str,left,right,disc)
--     local n = 0
--     local b = math.max(      left  or hyphenatedurl.lefthyphenmin,    2)
--     local e = math.min(#str-(right or hyphenatedurl.righthyphenmin)+2,#str)
--     local d = disc or hyphenatedurl.discretionary
--     local p = nil
--     for s in utfcharacters(str) do
--         n = n + 1
--         s = mapping[s] or s
--         if n > 1 then
--             ctx_s() -- can be option
--         end
--         if s == d then
--             ctx_d(utfbyte(s))
--         else
--             local c = characters[s]
--             if not c or n <= b or n >= e then
--                 ctx_n(utfbyte(s))
--             elseif c == 1 then
--                 ctx_b(utfbyte(s))
--             elseif c == 2 then
--                 ctx_a(utfbyte(s))
--             end
--         end
--         p = s
--     end
-- end

local ctx_a = context.a
local ctx_b = context.b
local ctx_d = context.d
local ctx_c = context.c
local ctx_l = context.l
local ctx_C = context.C
local ctx_L = context.L

local function action(hyphenatedurl,str,left,right,disc)
    local n = 0
    local b = math.max(      left  or hyphenatedurl.lefthyphenmin,    2)
    local e = math.min(#str-(right or hyphenatedurl.righthyphenmin)+2,#str)
    local d = disc or hyphenatedurl.discretionary
    local p = nil
    for s in utfcharacters(str) do
        n = n + 1
        s = mapping[s] or s
        if s == d then
            ctx_d(utfbyte(s))
        else
            local c = characters[s]
            if c == v_before then
                p = false
                ctx_b(utfbyte(s))
            elseif c == v_after then
                p = false
                ctx_a(utfbyte(s))
            else
                local l = is_letter[s]
                if n <= b or n >= e then
                    if p and l then
                        ctx_L(utfbyte(s))
                    else
                        ctx_C(utfbyte(s))
                    end
                elseif p and l then
                    ctx_l(utfbyte(s))
                else
                    ctx_c(utfbyte(s))
                end
                p = l
            end
        end
    end
end

-- hyphenatedurl.action = function(_,...) action(...) end -- sort of obsolete

table.setmetatablecall(hyphenatedurl,action) -- watch out: a caller

-- todo, no interface in mkiv yet

function hyphenatedurl.setcharacters(str,value) -- 1, 2 == before, after
    for s in utfcharacters(str) do
        characters[s] = value or v_before
    end
end

-- .hyphenatedurl.setcharacters("')]}",2)

implement {
    name      = "sethyphenatedurlcharacters",
    actions   = hyphenatedurl.setcharacters,
    arguments = { "string", "string" }
}

implement {
    name      = "hyphenatedurl",
    scope     = "private",
    actions   = function(...) action(hyphenatedurl,...) end,
    arguments = { "string", "integer", "integer", "string" }
}
