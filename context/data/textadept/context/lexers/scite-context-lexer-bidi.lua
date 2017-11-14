local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for plain text (with spell checking)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P, S, Cmt, Cp = lpeg.P, lpeg.S, lpeg.Cmt, lpeg.Cp
local find, match = string.find, string.match

local lexer        = require("scite-context-lexer")
local context      = lexer.context
local patterns     = context.patterns

local token        = lexer.token

local bidilexer    = lexer.new("bidi","scite-context-lexer-bidi")
local whitespace   = bidilexer.whitespace

local space        = patterns.space
local any          = patterns.any

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

require("char-def")

characters.directions  = { }

setmetatable(characters.directions,{ __index = function(t,k)
    local d = data[k]
    if d then
        local v = d.direction
        if v then
            t[k] = v
            return v
        end
    end
    t[k] = false -- maybe 'l'
    return false
end })

characters.mirrors  = { }

setmetatable(characters.mirrors,{ __index = function(t,k)
    local d = data[k]
    if d then
        local v = d.mirror
        if v then
            t[k] = v
            return v
        end
    end
    t[k] = false
    return false
end })

characters.textclasses  = { }

setmetatable(characters.textclasses,{ __index = function(t,k)
    local d = data[k]
    if d then
        local v = d.textclass
        if v then
            t[k] = v
            return v
        end
    end
    t[k] = false
    return false
end })

local directiondata  = characters.directions
local mirrordata     = characters.mirrors
local textclassdata  = characters.textclasses

local maximum_stack  = 0xFF -- unicode: 60, will be jumped to 125, we don't care too much
local analyze_fences = false

local whitespace = {
    lre = true,
    rle = true,
    lro = true,
    rlo = true,
    pdf = true,
    bn  = true,
    ws  = true,
}

local b_s_ws_on = {
    b   = true,
    s   = true,
    ws  = true,
    on  = true
}

local mt_space  = { __index = { char = 0x0020, direction = "ws",  original = "ws",  level = 0 } }
local mt_lre    = { __index = { char = 0x202A, direction = "lre", original = "lre", level = 0 } }
local mt_rle    = { __index = { char = 0x202B, direction = "rle", original = "rle", level = 0 } }
local mt_pdf    = { __index = { char = 0x202C, direction = "pdf", original = "pdf", level = 0 } }
local mt_object = { __index = { char = 0xFFFC, direction = "on",  original = "on",  level = 0 } }

local list  = { }
local stack = { }

setmetatable(stack, { __index = function(t,k) local v = { } t[k] = v return v end })

local function build_list(head)
    -- P1
    local size = 0
    lpegmatch(pattern,head)
    return list, size
end

local function resolve_fences(list,size,start,limit)
    -- N0: funny effects, not always better, so it's an option
    local nofstack = 0
    for i=start,limit do
        local entry = list[i]
        if entry.direction == "on" then
            local char   = entry.char
            local mirror = mirrordata[char]
            if mirror then
                local class = textclassdata[char]
                entry.mirror = mirror
                entry.class  = class
                if class == "open" then
                    nofstack       = nofstack + 1
                    local stacktop = stack[nofstack]
                    stacktop[1]    = mirror
                    stacktop[2]    = i
                    stacktop[3]    = false -- not used
                elseif nofstack == 0 then
                    -- skip
                elseif class == "close" then
                    while nofstack > 0 do
                        local stacktop = stack[nofstack]
                        if stacktop[1] == char then
                            local open  = stacktop[2]
                            local close = i
                            list[open ].paired = close
                            list[close].paired = open
                            break
                        else
                            -- do we mirror or not
                        end
                        nofstack = nofstack - 1
                    end
                end
            end
        end
    end
end

local function get_baselevel(list,size,direction)
    if direction == "TRT" then
        return 1, "TRT", true
    elseif direction == "TLT" then
        return 0, "TLT", true
    end
    -- P2, P3:
    for i=1,size do
        local entry     = list[i]
        local direction = entry.direction
        if direction == "r" or direction == "al" then -- and an ?
            return 1, "TRT", true
        elseif direction == "l" then
            return 0, "TLT", true
        end
    end
    return 0, "TLT", false
end

local function resolve_explicit(list,size,baselevel)
-- if list.rle or list.lre or list.rlo or list.lro then
    -- X1
    local level    = baselevel
    local override = "on"
    local nofstack = 0
    for i=1,size do
        local entry     = list[i]
        local direction = entry.direction
        -- X2
        if direction == "rle" then
            if nofstack < maximum_stack then
                nofstack        = nofstack + 1
                local stacktop  = stack[nofstack]
                stacktop[1]     = level
                stacktop[2]     = override
                level           = level + (level % 2 == 1 and 2 or 1) -- least_greater_odd(level)
                override        = "on"
                entry.level     = level
                entry.direction = "bn"
                entry.remove    = true
            end
        -- X3
        elseif direction == "lre" then
            if nofstack < maximum_stack then
                nofstack        = nofstack + 1
                local stacktop  = stack[nofstack]
                stacktop[1]     = level
                stacktop[2]     = override
                level           = level + (level % 2 == 1 and 1 or 2) -- least_greater_even(level)
                override        = "on"
                entry.level     = level
                entry.direction = "bn"
                entry.remove    = true
            end
        -- X4
        elseif direction == "rlo" then
            if nofstack < maximum_stack then
                nofstack        = nofstack + 1
                local stacktop  = stack[nofstack]
                stacktop[1]     = level
                stacktop[2]     = override
                level           = level + (level % 2 == 1 and 2 or 1) -- least_greater_odd(level)
                override        = "r"
                entry.level     = level
                entry.direction = "bn"
                entry.remove    = true
            end
        -- X5
        elseif direction == "lro" then
            if nofstack < maximum_stack then
                nofstack        = nofstack + 1
                local stacktop  = stack[nofstack]
                stacktop[1]     = level
                stacktop[2]     = override
                level           = level + (level % 2 == 1 and 1 or 2) -- least_greater_even(level)
                override        = "l"
                entry.level     = level
                entry.direction = "bn"
                entry.remove    = true
            end
        -- X7
        elseif direction == "pdf" then
            if nofstack < maximum_stack then
                local stacktop  = stack[nofstack]
                level           = stacktop[1]
                override        = stacktop[2]
                nofstack        = nofstack - 1
                entry.level     = level
                entry.direction = "bn"
                entry.remove    = true
            end
        -- X6
        else
            entry.level = level
            if override ~= "on" then
                entry.direction = override
            end
        end
    end
-- else
--     for i=1,size do
--         list[i].level = baselevel
--     end
-- end
    -- X8 (reset states and overrides after paragraph)
end

local function resolve_weak(list,size,start,limit,orderbefore,orderafter)
    -- W1: non spacing marks get the direction of the previous character
-- if list.nsm then
    for i=start,limit do
        local entry = list[i]
        if entry.direction == "nsm" then
            if i == start then
                entry.direction = orderbefore
            else
                entry.direction = list[i-1].direction
            end
        end
    end
-- end
    -- W2: mess with numbers and arabic
-- if list.en then
    for i=start,limit do
        local entry = list[i]
        if entry.direction == "en" then
            for j=i-1,start,-1 do
                local prev = list[j]
                local direction = prev.direction
                if direction == "al" then
                    entry.direction = "an"
                    break
                elseif direction == "r" or direction == "l" then
                    break
                end
            end
        end
    end
-- end
    -- W3
-- if list.al then
    for i=start,limit do
        local entry = list[i]
        if entry.direction == "al" then
            entry.direction = "r"
        end
    end
-- end
    -- W4: make separators number
-- if list.es or list.cs then
        -- skip
--     if false then
    if false then
        for i=start+1,limit-1 do
            local entry     = list[i]
            local direction = entry.direction
            if direction == "es" then
                if list[i-1].direction == "en" and list[i+1].direction == "en" then
                    entry.direction = "en"
                end
            elseif direction == "cs" then
                local prevdirection = list[i-1].direction
                if prevdirection == "en" then
                    if list[i+1].direction == "en" then
                        entry.direction = "en"
                    end
                elseif prevdirection == "an" and list[i+1].direction == "an" then
                    entry.direction = "an"
                end
            end
        end
    else -- only more efficient when we have es/cs
        local runner = start + 2
        local before = list[start]
        local entry  = list[start + 1]
        local after  = list[runner]
        while after do
            local direction = entry.direction
            if direction == "es" then
                if before.direction == "en" and after.direction == "en" then
                    entry.direction = "en"
                end
            elseif direction == "cs" then
                local prevdirection = before.direction
                if prevdirection == "en" then
                    if after.direction == "en" then
                        entry.direction = "en"
                    end
                elseif prevdirection == "an" and after.direction == "an" then
                    entry.direction = "an"
                end
            end
            before  = current
            current = after
            after   = list[runner]
            runner  = runner + 1
        end
    end
-- end
    -- W5
-- if list.et then
    local i = start
    while i <= limit do
        if list[i].direction == "et" then
            local runstart = i
            local runlimit = runstart
            for i=runstart,limit do
                if list[i].direction == "et" then
                    runlimit = i
                else
                    break
                end
            end
            local rundirection = runstart == start and sor or list[runstart-1].direction
            if rundirection ~= "en" then
                rundirection = runlimit == limit and orderafter or list[runlimit+1].direction
            end
            if rundirection == "en" then
                for j=runstart,runlimit do
                    list[j].direction = "en"
                end
            end
            i = runlimit
        end
        i = i + 1
    end
-- end
    -- W6
-- if list.es or list.cs or list.et then
    for i=start,limit do
        local entry     = list[i]
        local direction = entry.direction
        if direction == "es" or direction == "et" or direction == "cs" then
            entry.direction = "on"
        end
    end
-- end
    -- W7
    for i=start,limit do
        local entry = list[i]
        if entry.direction == "en" then
            local prev_strong = orderbefore
            for j=i-1,start,-1 do
                local direction = list[j].direction
                if direction == "l" or direction == "r" then
                    prev_strong = direction
                    break
                end
            end
            if prev_strong == "l" then
                entry.direction = "l"
            end
        end
    end
end

local function resolve_neutral(list,size,start,limit,orderbefore,orderafter)
    -- N1, N2
    for i=start,limit do
        local entry = list[i]
        if b_s_ws_on[entry.direction] then
            -- this needs checking
            local leading_direction, trailing_direction, resolved_direction
            local runstart = i
            local runlimit = runstart
            for j=runstart+1,limit do
                if b_s_ws_on[list[j].direction] then
                    runlimit = j
                else
                    break
                end
            end
            if runstart == start then
                leading_direction = orderbefore
            else
                leading_direction = list[runstart-1].direction
                if leading_direction == "en" or leading_direction == "an" then
                    leading_direction = "r"
                end
            end
            if runlimit == limit then
                trailing_direction = orderafter
            else
                trailing_direction = list[runlimit+1].direction
                if trailing_direction == "en" or trailing_direction == "an" then
                    trailing_direction = "r"
                end
            end
            if leading_direction == trailing_direction then
                -- N1
                resolved_direction = leading_direction
            else
                -- N2 / does the weird period
                resolved_direction = entry.level % 2 == 1 and "r" or "l"
            end
            for j=runstart,runlimit do
                list[j].direction = resolved_direction
            end
            i = runlimit
        end
        i = i + 1
    end
end

local function resolve_implicit(list,size,start,limit,orderbefore,orderafter,baselevel)
    for i=start,limit do
        local entry     = list[i]
        local level     = entry.level
        local direction = entry.direction
        if level % 2 ~= 1 then -- even
            -- I1
            if direction == "r" then
                entry.level = level + 1
            elseif direction == "an" or direction == "en" then
                entry.level = level + 2
            end
        else
            -- I2
            if direction == "l" or direction == "en" or direction == "an" then
                entry.level = level + 1
            end
        end
    end
end

local function resolve_levels(list,size,baselevel,analyze_fences)
    -- X10
    local start = 1
    while start < size do
        local level = list[start].level
        local limit = start + 1
        while limit < size and list[limit].level == level do
            limit = limit + 1
        end
        local prev_level  = start == 1    and baselevel or list[start-1].level
        local next_level  = limit == size and baselevel or list[limit+1].level
        local orderbefore = (level > prev_level and level or prev_level) % 2 == 1 and "r" or "l"
        local orderafter  = (level > next_level and level or next_level) % 2 == 1 and "r" or "l"
        -- W1 .. W7
        resolve_weak(list,size,start,limit,orderbefore,orderafter)
        -- N0
        if analyze_fences then
            resolve_fences(list,size,start,limit)
        end
        -- N1 .. N2
        resolve_neutral(list,size,start,limit,orderbefore,orderafter)
        -- I1 .. I2
        resolve_implicit(list,size,start,limit,orderbefore,orderafter,baselevel)
        start = limit
    end
    -- L1
    for i=1,size do
        local entry     = list[i]
        local direction = entry.original
        -- (1)
        if direction == "s" or direction == "b" then
            entry.level = baselevel
            -- (2)
            for j=i-1,1,-1 do
                local entry = list[j]
                if whitespace[entry.original] then
                    entry.level = baselevel
                else
                    break
                end
            end
        end
    end
    -- (3)
    for i=size,1,-1 do
        local entry = list[i]
        if whitespace[entry.original] then
            entry.level = baselevel
        else
            break
        end
    end
    -- L4
    if analyze_fences then
        for i=1,size do
            local entry = list[i]
            if entry.level % 2 == 1 then -- odd(entry.level)
                if entry.mirror and not entry.paired then
                    entry.mirror = false
                end
                -- okay
            elseif entry.mirror then
                entry.mirror = false
            end
        end
    else
        for i=1,size do
            local entry = list[i]
            if entry.level % 2 == 1 then -- odd(entry.level)
                local mirror = mirrordata[entry.char]
                if mirror then
                    entry.mirror = mirror
                end
            end
        end
    end
end

local index = 1

local function process(head,direction)
    local list, size = build_list(head)
    local baselevel = get_baselevel(list,size,direction) -- we always have an inline dir node in context
    resolve_explicit(list,size,baselevel)
    resolve_levels(list,size,baselevel,analyze_fences)
    index = 1
    return list, size
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local utf     = lexer.helpers.utfbytepattern

-- local t_start = token("default", utf, function(s,i) if i == 1 then index = 1 process(s) end end))
-- local t_bidi  = token("error",   utf / function() index = index + 1 return list[index].direction == "r" end)
-- local t_rest  = token("default", any)

-- bidilexer._rules = {
--     { "start", t_start },
--     { "bidi",  t_bidi  },
--     { "rest",  t_rest  },
-- }

bidilexer._grammar = #utf * function(s,i)
    process(s)
    local t = { }
    local n = 0
    for i=1,size do
        n = n + 1 t[n] = i
        n = n + 1 t[n] = "error"
    end
    return t
end

bidilexer._tokenstyles = context.styleset

return bidilexer
