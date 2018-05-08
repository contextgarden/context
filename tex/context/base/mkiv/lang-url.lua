if not modules then modules = { } end modules ['lang-url'] = {
    version   = 1.001,
    comment   = "companion to lang-url.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utfcharacters, utfvalues, utfbyte, utfchar = utf.characters, utf.values, utf.byte, utf.char
local min, max = math.min, math.max

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

local urls     = { }
languages.urls = urls

local characters = utilities.storage.allocate {
    ["!"] = "before",
    ['"'] = "before",
    ["#"] = "before",
    ["$"] = "before",
    ["%"] = "before",
    ["&"] = "before",
    ["("] = "before",
    ["*"] = "before",
    ["+"] = "before",
    [","] = "before",
    ["-"] = "before",
    ["."] = "before",
    ["/"] = "before",
    [":"] = "before",
    [";"] = "before",
    ["<"] = "before",
    ["="] = "before",
    [">"] = "before",
    ["?"] = "before",
    ["@"] = "before",
    ["["] = "before",
   ["\\"] = "before",
    ["^"] = "before",
    ["_"] = "before",
    ["`"] = "before",
    ["{"] = "before",
    ["|"] = "before",
    ["~"] = "before",

    ["'"] = "after",
    [")"] = "after",
    ["]"] = "after",
    ["}"] = "after",
}

local mapping = utilities.storage.allocate {
  -- [utfchar(0xA0)] = "~", -- nbsp (catch)
}

urls.characters     = characters
urls.mapping        = mapping
urls.lefthyphenmin  = 2
urls.righthyphenmin = 3
urls.discretionary  = nil
urls.packslashes    = false

directives.register("hyphenators.urls.packslashes",function(v) urls.packslashes = v end)

local trace  = false   trackers.register("hyphenators.urls",function(v) trace = v end)
local report = logs.reporter("hyphenators","urls")

-- local ctx_a = context.a
-- local ctx_b = context.b
-- local ctx_d = context.d
-- local ctx_c = context.c
-- local ctx_l = context.l
-- local ctx_C = context.C
-- local ctx_L = context.L

-- local function action(hyphenatedurl,str,left,right,disc)
--     --
--     left  = max(      left  or urls.lefthyphenmin,    2)
--     right = min(#str-(right or urls.righthyphenmin)+2,#str)
--     disc  = disc or urls.discretionary
--     --
--     local word   = nil
--     local prev   = nil
--     local pack   = urls.packslashes
--     local length = 0
--     --
--     for char in utfcharacters(str) do
--         length  = length + 1
--         char    = mapping[char] or char
--         local b = utfbyte(char)
--         if prev == char and prev == "/" then
--             ctx_c(b)
--         elseif char == disc then
--             ctx_d()
--         else
--             if prev == "/" then
--                 ctx_d()
--             end
--             local how = characters[char]
--             if how == v_before then
--                 word = false
--                 ctx_b(b)
--             elseif how == v_after then
--                 word = false
--                 ctx_a(b)
--             else
--                 local letter = is_letter[char]
--                 if length <= left or length >= right then
--                     if word and letter then
--                         ctx_L(b)
--                     else
--                         ctx_C(b)
--                     end
--                 elseif word and letter then
--                     ctx_l(b)
--                 else
--                     ctx_c(b)
--                 end
--                 word = letter
--             end
--         end
--         if pack then
--             prev = char
--         else
--             prev = nil
--         end
--     end
-- end

local function action(hyphenatedurl,str,left,right,disc)
    --
    left  = max(      left  or urls.lefthyphenmin,    2)
    right = min(#str-(right or urls.righthyphenmin)+2,#str)
    disc  = disc or urls.discretionary
    --
    local word   = nil
    local pack   = urls.packslashes
    local length = 0
    local list   = utf.split(str)
    local size   = #list
    local prev   = nil

    for i=1,size do
        local what = nil
        local dodi = false
        local char = list[i]
        length     = length + 1
        char       = mapping[char] or char
        if char == disc then
            dodi = true
        elseif pack and char == "/" and (list[i+1] == "/" or prev == "/") then
            what = "c"
        else
            local how = characters[char]
            if how == v_before then
                what = "b"
            elseif how == v_after then
                word = false
                what = "a"
            else
                local letter = is_letter[char]
                if length <= left or length >= right then
                    if word and letter then
                        what = "L"
                    else
                        what = "C"
                    end
                elseif word and letter then
                    what = "l"
                else
                    what = "c"
                end
                word = letter
            end
        end
        if dodi then
            list[i] = "\\d"
        else
            list[i] = "\\" .. what .. "{" .. utfbyte(char) .. "}"
        end
        prev = char
    end
    if trace then
        report("old : %s",str)
        report("new : %t",list)
    end
    context("%t",list)
end

-- urls.action = function(_,...) action(...) end -- sort of obsolete

table.setmetatablecall(hyphenatedurl,action) -- watch out: a caller

-- todo, no interface in mkiv yet

function urls.setcharacters(str,value) -- 1, 2 == before, after
    for s in utfcharacters(str) do
        characters[s] = value or v_before
    end
end

-- .urls.setcharacters("')]}",2)

implement {
    name      = "sethyphenatedurlcharacters",
    actions   = urls.setcharacters,
    arguments = "2 strings",
}

implement {
    name      = "hyphenatedurl",
    scope     = "private",
    actions   = function(...) action(hyphenatedurl,...) end,
    arguments = { "string", "integer", "integer", "string" }
}
