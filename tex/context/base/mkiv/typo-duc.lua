if not modules then modules = { } end modules ['typo-duc'] = {
    version   = 1.001,
    comment   = "companion to typo-dir.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "Unicode bidi (sort of) variant c",
}

-- This is a follow up on typo-uda which itself is a follow up on t-bidi by Khaled Hosny which
-- in turn is based on minibidi.c from Arabeyes. This is a further optimizations, as well as
-- an update on some recent unicode bidi developments. There is (and will) also be more control
-- added. As a consequence this module is somewhat slower than its precursor which itself is
-- slower than the one-pass bidi handler. This is also a playground and I might add some plugin
-- support. However, in the meantime performance got a bit better and this third variant is again
-- some 10% faster than the second variant.

-- todo (cf html):
--
-- normal            The element does not offer a additional level of embedding with respect to the bidirectional algorithm. For inline elements implicit reordering works across element boundaries.
-- embed             If the element is inline, this value opens an additional level of embedding with respect to the bidirectional algorithm. The direction of this embedding level is given by the direction property.
-- bidi-override     For inline elements this creates an override. For block container elements this creates an override for inline-level descendants not within another block container element. This means that inside the element, reordering is strictly in sequence according to the direction property; the implicit part of the bidirectional algorithm is ignored.
-- isolate           This keyword indicates that the element's container directionality should be calculated without considering the content of this element. The element is therefore isolated from its siblings. When applying its bidirectional-resolution algorithm, its container element treats it as one or several U+FFFC Object Replacement Character, i.e. like an image.
-- isolate-override  This keyword applies the isolation behavior of the isolate keyword to the surrounding content and the override behavior o f the bidi-override keyword to the inner content.
-- plaintext         This keyword makes the elements directionality calculated without considering its parent bidirectional state or the value of the direction property. The directionality is calculated using the P2 and P3 rules of the Unicode Bidirectional Algorithm.
--                   This value allows to display data which has already formatted using a tool following the Unicode Bidirectional Algorithm.
--
-- todo: check for introduced errors
-- todo: reuse list, we have size, so we can just change values (and auto allocate when not there)
-- todo: reuse the stack
-- todo: no need for a max check
-- todo: collapse bound similar ranges (not ok yet)
-- todo: combine some sweeps
-- todo: removing is not needed when we inject at the same spot (only chnage the dir property)
-- todo: isolated runs (isolating runs are similar to bidi=local in the basic analyzer)

-- todo: check unicode addenda (from the draft):
--
-- Added support for canonical equivalents in BD16.
-- Changed logic in N0 to not check forwards for context in the case of enclosed text opposite the embedding direction.
-- Major extension of the algorithm to allow for the implementation of directional isolates and the introduction of new isolate-related values to the Bidi_Class property.
-- Adds BD8, BD9, BD10, BD11, BD12, BD13, BD14, BD15, and BD16, Sections 2.4 and 2.5, and Rules X5a, X5b, X5c and X6a.
-- Extensively revises Section 3.3.2, Explicit Levels and Directions and its existing X rules to formalize the algorithm for matching a PDF with the embedding or override initiator whose scope it terminates.
-- Moves Rules X9 and X10 into a separate new Section 3.3.3, Preparations for Implicit Processing.
-- Modifies Rule X10 to make the isolating run sequence the unit to which subsequent rules are applied.
-- Modifies Rule W1 to change an NSM preceded by an isolate initiator or PDI into ON.
-- Adds Rule N0 and makes other changes to Section 3.3.5, Resolving Neutral and Isolate Formatting Types to resolve bracket pairs to the same level.

local insert, remove, unpack, concat = table.insert, table.remove, table.unpack, table.concat
local utfchar = utf.char
local setmetatable = setmetatable
local formatters = string.formatters

local directiondata       = characters.directions
local mirrordata          = characters.mirrors
local textclassdata       = characters.textclasses

local nuts                = nodes.nuts

local getnext             = nuts.getnext
local getid               = nuts.getid
local getsubtype          = nuts.getsubtype
local getlist             = nuts.getlist
local getchar             = nuts.getchar
local getattr             = nuts.getattr
local getprop             = nuts.getprop
local getdirection        = nuts.getdirection
local isglyph             = nuts.isglyph

local setprop             = nuts.setprop
local setchar             = nuts.setchar
local setdirection        = nuts.setdirection
local setattrlist         = nuts.setattrlist

local properties          = nodes.properties.data

local remove_node         = nuts.remove
local insert_node_after   = nuts.insert_after
local insert_node_before  = nuts.insert_before
local start_of_par        = nuts.start_of_par

local nodepool            = nuts.pool
local new_direction       = nodepool.direction

local nodecodes           = nodes.nodecodes
local gluecodes           = nodes.gluecodes

local glyph_code          = nodecodes.glyph
local glue_code           = nodecodes.glue
local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local math_code           = nodecodes.math
local dir_code            = nodecodes.dir
local localpar_code       = nodecodes.localpar

local parfillskip_code    = gluecodes.parfillskip

local dirvalues           = nodes.dirvalues
local lefttoright_code    = dirvalues.lefttoright
local righttoleft_code    = dirvalues.righttoleft

local maximum_stack       = 0xFF

local a_directions        = attributes.private('directions')

local directions          = typesetters.directions
local setcolor            = directions.setcolor
local getfences           = directions.getfences

local remove_controls     = true  directives.register("typesetters.directions.removecontrols",function(v) remove_controls  = v end)
----- analyze_fences      = true  directives.register("typesetters.directions.analyzefences", function(v) analyze_fences   = v end)

local report_directions   = logs.reporter("typesetting","directions three")

local trace_directions    = false trackers.register("typesetters.directions",         function(v) trace_directions = v end)
local trace_details       = false trackers.register("typesetters.directions.details", function(v) trace_details    = v end)
local trace_list          = false trackers.register("typesetters.directions.list",    function(v) trace_list       = v end)

-- strong (old):
--
-- l   : left to right
-- r   : right to left
-- lro : left to right override
-- rlo : left to left override
-- lre : left to right embedding
-- rle : left to left embedding
-- al  : right to legt arabic (esp punctuation issues)
--
-- weak:
--
-- en  : english number
-- es  : english number separator
-- et  : english number terminator
-- an  : arabic number
-- cs  : common number separator
-- nsm : nonspacing mark
-- bn  : boundary neutral
--
-- neutral:
--
-- b  : paragraph separator
-- s  : segment separator
-- ws : whitespace
-- on : other neutrals
--
-- interesting: this is indeed better (and more what we expect i.e. we already use this split
-- in the old original (also these isolates)
--
-- strong (new):
--
-- l   : left to right
-- r   : right to left
-- al  : right to left arabic (esp punctuation issues)
--
-- explicit: (new)
--
-- lro : left to right override
-- rlo : left to left override
-- lre : left to right embedding
-- rle : left to left embedding
-- pdf : pop dir format
-- lri : left to right isolate
-- rli : left to left isolate
-- fsi : first string isolate
-- pdi : pop directional isolate

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

-- tracing

local function show_list(list,size,what)
    local what   = what or "direction"
    local joiner = utfchar(0x200C)
    local result = { }
    for i=1,size do
        local entry     = list[i]
        local character = entry.char
        local direction = entry[what]
        if character == 0xFFFC then
            local first = entry.id
            local last  = entry.last
            local skip  = entry.skip
            if last then
                result[i] = formatters["%-3s:%s %s..%s (%i)"](direction,joiner,nodecodes[first],nodecodes[last],skip or 0)
            else
                result[i] = formatters["%-3s:%s %s (%i)"](direction,joiner,nodecodes[first],skip or 0)
            end
        elseif character >= 0x202A and character <= 0x202C then
            result[i] = formatters["%-3s:%s %U"](direction,joiner,character)
        else
            result[i] = formatters["%-3s:%s %c %U"](direction,joiner,character,character)
        end
    end
    return concat(result,joiner .. " | " .. joiner)
end

-- preparation

local function show_done(list,size)
    local joiner = utfchar(0x200C)
    local result = { }
    local format = formatters["<%s>"]
    for i=1,size do
        local entry     = list[i]
        local character = entry.char
        local begindir  = entry.begindir
        local enddir    = entry.enddir
        if begindir then
            result[#result+1] = format(begindir)
        end
        if entry.remove then
            -- continue
        elseif character == 0xFFFC then
            result[#result+1] = format("?")
        elseif character == 0x0020 then
            result[#result+1] = format(" ")
        elseif character >= 0x202A and character <= 0x202C then
            result[#result+1] = format(entry.original)
        else
            result[#result+1] = utfchar(character)
        end
        if enddir then
            result[#result+1] = format(enddir)
        end
    end
    return concat(result,joiner)
end

-- keeping the list and overwriting doesn't save much runtime, only a few percent
-- char is only used for mirror, so in fact we can as well only store it for
-- glyphs only
--
-- tracking what direction is used and skipping tests is not faster (extra kind of
-- compensates gain)

local mt_space  = { __index = { char = 0x0020, direction = "ws",  original = "ws",  level = 0, skip = 0 } }
local mt_lre    = { __index = { char = 0x202A, direction = "lre", original = "lre", level = 0, skip = 0 } }
local mt_rle    = { __index = { char = 0x202B, direction = "rle", original = "rle", level = 0, skip = 0 } }
local mt_pdf    = { __index = { char = 0x202C, direction = "pdf", original = "pdf", level = 0, skip = 0 } }
local mt_object = { __index = { char = 0xFFFC, direction = "on",  original = "on",  level = 0, skip = 0 } }

local stack = table.setmetatableindex("table") -- shared
local list  = { }                              -- shared

local function build_list(head,where)
    -- P1
    local current = head
    local size    = 0
    while current do
        size = size + 1
        local id = getid(current)
        local p  = properties[current]
        if p and p.directions then
            -- tricky as dirs can be injected in between
            local skip = 0
            local last = id
            current    = getnext(current)
            while current do
                local id = getid(current)
                local p  = properties[current]
                if p and p.directions then
                    skip    = skip + 1
                    last    = id
                    current = getnext(current)
                else
                    break
                end
            end
            if id == last then -- the start id
                list[size] = setmetatable({ skip = skip, id = id },mt_object)
            else
                list[size] = setmetatable({ skip = skip, id = id, last = last },mt_object)
            end
        elseif id == glyph_code then
            local chr  = getchar(current)
            local dir  = directiondata[chr]
            -- could also be a metatable
            list[size] = { char = chr, direction = dir, original = dir, level = 0 }
            current    = getnext(current)
         -- if not list[dir] then list[dir] = true end -- not faster when we check for usage
        elseif id == glue_code then -- and how about kern
            list[size] = setmetatable({ },mt_space)
            current    = getnext(current)
        elseif id == dir_code then
            local dir, pop = getdirection(current)
            if dir == lefttoright_code then
                list[size] = setmetatable({ },pop and mt_pdf or mt_lre)
            elseif dir == righttoleft_code then
                list[size] = setmetatable({ },pop and mt_pdf or mt_rle)
            else
                list[size] = setmetatable({ id = id },mt_object)
            end
            current = getnext(current)
        elseif id == math_code then
            local skip = 0
            current    = getnext(current)
            while getid(current) ~= math_code do
                skip    = skip + 1
                current = getnext(current)
            end
            skip       = skip + 1
            current    = getnext(current)
            list[size] = setmetatable({ id = id, skip = skip },mt_object)
        else -- disc_code: we assume that these are the same as the surrounding
            local skip = 0
            local last = id
            current    = getnext(current)
            while n do
                local id = getid(current)
                if id ~= glyph_code and id ~= glue_code and id ~= dir_code then
                    skip    = skip + 1
                    last    = id
                    current = getnext(current)
                else
                    break
                end
            end
            if id == last then -- the start id
                list[size] = setmetatable({ id = id, skip = skip },mt_object)
            else
                list[size] = setmetatable({ id = id, skip = skip, last = last },mt_object)
            end
        end
    end
    return list, size
end

-- new

-- we could support ( ] and [ ) and such ...

-- ש ) ל ( א       0-0
-- ש ( ל ] א       0-0
-- ש ( ל ) א       2-4
-- ש ( ל [ א ) כ ] 2-6
-- ש ( ל ] א ) כ   2-6
-- ש ( ל ) א ) כ   2-4
-- ש ( ל ( א ) כ   4-6
-- ש ( ל ( א ) כ ) 2-8,4-6
-- ש ( ל [ א ] כ ) 2-8,4-6

local fencestack = table.setmetatableindex("table")

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
                    local stacktop = fencestack[nofstack]
                    stacktop[1]    = mirror
                    stacktop[2]    = i
                elseif nofstack == 0 then
                    -- skip
                elseif class == "close" then
                    while nofstack > 0 do
                        local stacktop = fencestack[nofstack]
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

-- local function test_fences(str)
--     local list  = { }
--     for s in string.gmatch(str,".") do
--         local b = utf.byte(s)
--         list[#list+1] = { c = s, char = b, direction = directiondata[b] }
--     end
--     resolve_fences(list,#list,1,#size)
--     inspect(list)
-- end
--
-- test_fences("a(b)c(d)e(f(g)h)i")
-- test_fences("a(b[c)d]")

-- the action

local function get_baselevel(head,list,size,direction)
    if direction == lefttoright_code or direction == righttoleft_code then
        return direction, true
    elseif getid(head) == localpar_code and start_of_par(head) then
        direction = getdirection(head)
        if direction == lefttoright_code or direction == righttoleft_code then
            return direction, true
        end
    end
    -- for old times sake we we handle strings too
    if direction == "TLT" then
        return lefttoright_code, true
    elseif direction == "TRT" then
        return righttoleft_code, true
    end
    -- P2, P3
    for i=1,size do
        local entry     = list[i]
        local direction = entry.direction
        if direction == "r" or direction == "al" then -- and an ?
            return righttoleft_code, true
        elseif direction == "l" then
            return lefttoright_code, true
        end
    end
    return lefttoright_code, false
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
            elseif trace_directions then
                report_directions("stack overflow at position %a with direction %a",i,direction)
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
            elseif trace_directions then
                report_directions("stack overflow at position %a with direction %a",i,direction)
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
            elseif trace_directions then
                report_directions("stack overflow at position %a with direction %a",i,direction)
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
            elseif trace_directions then
                report_directions("stack overflow at position %a with direction %a",i,direction)
            end
        -- X7
        elseif direction == "pdf" then
            if nofstack > 0 then
                local stacktop  = stack[nofstack]
                level           = stacktop[1]
                override        = stacktop[2]
                nofstack        = nofstack - 1
                entry.level     = level
                entry.direction = "bn"
                entry.remove    = true
            elseif trace_directions then
                report_directions("stack underflow at position %a with direction %a",
                    i, direction)
            else
                report_directions("stack underflow at position %a with direction %a: %s",
                    i, direction, show_list(list,size))
            end
        -- X6
        else
            entry.level = level
            if override ~= "on" then
                entry.direction = override
            end
        end
    end
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
        if runner <= limit then
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
--             for j=runstart,limit do
            for j=runstart+1,limit do
                if b_s_ws_on[list[j].direction] then
--                     runstart = j
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

local stack = { }

local function insert_dir_points(list,size)
    -- L2, but no actual reversion is done, we simply annotate where
    -- begindir/endddir node will be inserted.
    local maxlevel = 0
    local toggle   = true
    for i=1,size do
        local level = list[i].level
        if level > maxlevel then
            maxlevel = level
        end
    end
    for level=0,maxlevel do
        local started  -- = false
        local begindir -- = nil
        local enddir   -- = nil
        local prev     -- = nil
        if toggle then
            begindir = lefttoright_code
            enddir   = lefttoright_code
            toggle   = false
        else
            begindir = righttoleft_code
            enddir   = righttoleft_code
            toggle   = true
        end
        for i=1,size do
            local entry = list[i]
            if entry.level >= level then
                if not started then
                    entry.begindir = begindir
                    started        = true
                end
            else
                if started then
                    prev.enddir = enddir
                    started     = false
                end
            end
            prev = entry
        end
    end
    -- make sure to close the run at end of line
    local last = list[size]
    if not last.enddir then
        local n = 0
        for i=1,size do
            local entry = list[i]
            local e = entry.enddir
            local b = entry.begindir
            if e then
                n = n - 1
            end
            if b then
                n = n + 1
                stack[n] = b
            end
        end
        if n > 0 then
            if trace_list and n > 1 then
                report_directions("unbalanced list")
            end
            last.enddir = stack[n]
        end
    end
end

-- We flag nodes that can be skipped when we see them again but because whatever
-- mechanism can injetc dir nodes that then are not flagged, we don't flag dir
-- nodes that we inject here.

local function apply_to_list(list,size,head,pardir)
    local index   = 1
    local current = head
    if trace_list then
        report_directions("start run")
    end
    while current do
        if index > size then
            report_directions("fatal error, size mismatch")
            break
        end
        local id       = getid(current)
        local entry    = list[index]
        local begindir = entry.begindir
        local enddir   = entry.enddir
        local p = properties[current]
        if p then
            p.directions = true
        else
            properties[current] = { directions = true }
        end
        if id == glyph_code then
            local mirror = entry.mirror
            if mirror then
                setchar(current,mirror)
            end
            if trace_directions then
                local direction = entry.direction
                if trace_list then
                    local original = entry.original
                    local char     = entry.char
                    local level    = entry.level
                    if direction == original then
                        report_directions("%2i : %C : %s",level,char,direction)
                    else
                        report_directions("%2i : %C : %s -> %s",level,char,original,direction)
                    end
                end
                setcolor(current,direction,false,mirror)
            end
        elseif id == hlist_code or id == vlist_code then
            setdirection(current,pardir) -- is this really needed?
        elseif id == glue_code then
            if enddir and getsubtype(current) == parfillskip_code then
                -- insert the last enddir before \parfillskip glue
                head = insert_node_before(head,current,new_direction(enddir,true))
                enddir = false
            end
        elseif begindir then
            if id == localpar_code and start_of_par(current) then
                -- localpar should always be the 1st node
                head, current = insert_node_after(head,current,new_direction(begindir))
                begindir = nil
            end
        end
        if begindir then
            head = insert_node_before(head,current,new_direction(begindir))
        end
        local skip = entry.skip
        if skip and skip > 0 then
            for i=1,skip do
                current = getnext(current)
                local p = properties[current]
                if p then
                    p.directions = true
                else
                    properties[current] = { directions = true }
                end
            end
        end
        if enddir then
            head, current = insert_node_after(head,current,new_direction(enddir,true))
        end
        if not entry.remove then
            current = getnext(current)
        elseif remove_controls then
            -- X9
            head, current = remove_node(head,current,true)
        else
            current = getnext(current)
        end
        index = index + 1
    end
    if trace_list then
        report_directions("stop run")
    end
    return head
end

-- If needed we can optimize for only_one. There is no need to do anything
-- when it's not a glyph. Otherwise we only need to check mirror and apply
-- directions when it's different from the surrounding. Paragraphs always
-- have more than one node. Actually, we only enter this function when we
-- do have a glyph!

local function process(head,direction,only_one,where)
    -- for the moment a whole paragraph property
    local attr = getattr(head,a_directions)
    local analyze_fences = getfences(attr)
    --
    local list, size = build_list(head,where)
    local baselevel, dirfound = get_baselevel(head,list,size,direction)
    if trace_details then
        report_directions("analyze: baselevel %a",baselevel == righttoleft_code and "r2l" or "l2r")
        report_directions("before : %s",show_list(list,size,"original"))
    end
    resolve_explicit(list,size,baselevel)
    resolve_levels(list,size,baselevel,analyze_fences)
    insert_dir_points(list,size)
    if trace_details then
        report_directions("after  : %s",show_list(list,size,"direction"))
        report_directions("result : %s",show_done(list,size))
    end
    return apply_to_list(list,size,head,baselevel)
end

local variables = interfaces.variables

directions.installhandler(variables.one,    process) -- for old times sake
directions.installhandler(variables.two,    process) -- for old times sake
directions.installhandler(variables.three,  process) -- for old times sake
directions.installhandler(variables.unicode,process)
