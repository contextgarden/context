if not modules then modules = { } end modules ['typo-dua'] = {
    version   = 1.001,
    comment   = "companion to typo-dir.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team / See below",
    license   = "see context related readme files / whatever applies",
    comment   = "Unicode bidi (sort of) variant a",
    derived   = "derived from t-bidi by Khaled Hosny who derived from minibidi.c by Arabeyes",
}

-- Comment by Khaled Hosny:
--
-- This code started as a line for line translation of Arabeyes' minibidi.c from C to Lua,
-- excluding parts that of no use to us like shaping. The C code is Copyright (c) 2004
-- Ahmad Khalifa, and is distributed under the MIT Licence. The full license text can be
-- found at: http://svn.arabeyes.org/viewvc/projects/adawat/minibidi/LICENCE.
--
-- Comment by Hans Hagen:
--
-- The initial conversion to Lua has been done by Khaled Hosny. As a first step I optimized the
-- code (to suit todays context mkiv). Next I fixed the foreign object handling, for instance,
-- we can skip over math but we need to inject before the open math node and after the close node,
-- so we need to keep track of the endpoint. After I fixed that bit I realized that it was possible
-- to generalize the object skipper if only because it saves memory (and processing time). The
-- current implementation is about three times as fast (roughly measured) and I can probably squeeze
-- out some more, only to sacrifice soem when I start adding features. A next stage will be to have
-- more granularity in foreign objects. Of course all errors are mine. I'll also added the usual bit
-- of context tracing and reshuffled some code. A memory optimization is on the agenda (already sort
-- of prepared). It is no longer line by line.
--
-- The first implementation of bidi in context started out from examples of mixed usage (including
-- more than text) with an at that point bugged r2l support. It has  some alternatives for letting
-- the tex markup having a bit higher priority. I will  probably add some local (style driven)
-- overrides to the following code as well. It also means that we can selectively enable and disable
-- the parser (because a document wide appliance migh tnot be what we want). This will bring a
-- slow down but not that much. (I need to check with Idris why we have things like isol there.)
--
-- We'll probably keep multiple methods around (this is just a side track of improving the already
-- available scanner). I need to look into the changed unicode recomendations anyway as a first
-- impression is that some fuzzyness has been removed. I finally need to spend time on those specs. So,
-- there will be a third variant (written from scratch) so some point. The fun about TeX is that we
-- can provide alternative solutions (given that it doesn't bloat the engine!)
--
-- A test with some hebrew, mixed with hboxes with latin/hebrew and simple math. In fact this triggered
-- playing with bidi again:
--
-- 0.11 :      nothing
-- 0.14 : 0.03 node list only, one pass
-- 0.23 : 0.12 close to unicode bidi, multipass
-- 0.44 : 0.33 original previous
--
-- todo: check for introduced errors
-- todo: reuse list, we have size, so we can just change values (and auto allocate when not there)
-- todo: reuse the stack
-- todo: no need for a max check
-- todo: collapse bound similar ranges (not ok yet)
-- tood: combine some sweeps
--
-- This one wil get frozen (or if needed in sync with basic t-bidi) and I will explore more options
-- in typo-dub.lua. There I might also be able to improve performance a bit. Derived and improved
-- versions will also be sped up

local insert, remove, unpack, concat = table.insert, table.remove, table.unpack, table.concat
local utfchar = utf.char
local formatters = string.formatters

local directiondata       = characters.directions
local mirrordata          = characters.mirrors

local nuts                = nodes.nuts

local getnext             = nuts.getnext
local getid               = nuts.getid
local getsubtype          = nuts.getsubtype
local getlist             = nuts.getlist
local getchar             = nuts.getchar
local getprop             = nuts.getprop
local getdirection        = nuts.getdirection

local setprop             = nuts.setprop
local setchar             = nuts.setchar
local setdirection        = nuts.setdirection
----- setattrlist         = nuts.setattrlist

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

local maximum_stack       = 60

local directions          = typesetters.directions
local setcolor            = directions.setcolor

local remove_controls     = true  directives.register("typesetters.directions.one.removecontrols",function(v) remove_controls  = v end)

local report_directions   = logs.reporter("typesetting","directions one")

local trace_directions    = false trackers  .register("typesetters.directions",               function(v) trace_directions = v end)
local trace_details       = false trackers  .register("typesetters.directions.details",       function(v) trace_details    = v end)




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
    for i=1,size do
        local entry     = list[i]
        local character = entry.char
        local begindir  = entry.begindir
        local enddir    = entry.enddir
        if begindir then
            result[#result+1] = formatters["<%s>"](begindir)
        end
        if entry.remove then
            -- continue
        elseif character == 0xFFFC then
            result[#result+1] = formatters["<%s>"]("?")
        elseif character == 0x0020 then
            result[#result+1] = formatters["<%s>"](" ")
        elseif character >= 0x202A and character <= 0x202C then
            result[#result+1] = formatters["<%s>"](entry.original)
        else
            result[#result+1] = utfchar(character)
        end
        if enddir then
            result[#result+1] = formatters["<%s>"](enddir)
        end
    end
    return concat(result,joiner)
end

-- keeping the list and overwriting doesn't save much runtime, only a few percent
-- char is only used for mirror, so in fact we can as well only store it for
-- glyphs only

local function build_list(head) -- todo: store node pointer ... saves loop
    -- P1
    local current = head
    local list    = { }
    local size    = 0
    while current do
        size = size + 1
        local id = getid(current)
        if getprop(current,"directions") then
            local skip = 0
            local last = id
            current    = getnext(current)
            while current do
                local id = getid(current)
                if getprop(current,"directions") then
                    skip    = skip + 1
                    last    = id
                    current = getnext(current)
                else
                    break
                end
            end
            if id == last then -- the start id
                list[size] = { char = 0xFFFC, direction = "on", original = "on", level = 0, skip = skip, id = id }
            else
                list[size] = { char = 0xFFFC, direction = "on", original = "on", level = 0, skip = skip, id = id, last = last }
            end
        elseif id == glyph_code then
            local chr = getchar(current)
            local dir = directiondata[chr]
            list[size] = { char = chr, direction = dir, original = dir, level = 0 }
            current = getnext(current)
        elseif id == glue_code then -- and how about kern
            list[size] = { char = 0x0020, direction = "ws", original = "ws", level = 0 }
            current = getnext(current)
        elseif id == dir_code then
            local direction, pop = getdirection(current)
            if direction == lefttoright_code then
                if pop then
                    list[size] = { char = 0x202C, direction = "pdf", original = "pdf", level = 0 }
                else
                    list[size] = { char = 0x202A, direction = "lre", original = "lre", level = 0 }
                end
            elseif direction == righttoleft_code then
                if pop then
                    list[size] = { char = 0x202C, direction = "pdf", original = "pdf", level = 0 }
                else
                    list[size] = { char = 0x202B, direction = "rle", original = "rle", level = 0 }
                end
            else
                list[size] = { char = 0xFFFC, direction = "on", original = "on", level = 0, id = id } -- object replacement character
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
            list[size] = { char = 0xFFFC, direction = "on", original = "on", level = 0, skip = skip, id = id }
        else
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
                list[size] = { char = 0xFFFC, direction = "on", original = "on", level = 0, skip = skip, id = id }
            else
                list[size] = { char = 0xFFFC, direction = "on", original = "on", level = 0, skip = skip, id = id, last = last }
            end
        end
    end
    return list, size
end

-- the action

-- local function find_run_limit_et(list,run_start,limit)
--     local run_limit = run_start
--     local i = run_start
--     while i <= limit and list[i].direction == "et" do
--         run_limit = i
--         i = i + 1
--     end
--     return run_limit
-- end

local function find_run_limit_et(list,start,limit) -- returns last match
    for i=start,limit do
        if list[i].direction == "et" then
            start = i
        else
            return start
        end
    end
    return start
end

-- local function find_run_limit_b_s_ws_on(list,run_start,limit)
--     local run_limit = run_start
--     local i = run_start
--     while i <= limit and b_s_ws_on[list[i].direction] do
--         run_limit = i
--         i = i + 1
--     end
--     return run_limit
-- end

local function find_run_limit_b_s_ws_on(list,start,limit)
    for i=start,limit do
        if b_s_ws_on[list[i].direction] then
            start = i
        else
            return start
        end
    end
    return start
end

local function get_baselevel(head,list,size,direction)
    -- This is an adapted version:
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
        if direction == "r" or direction == "al" then
            return righttoleft_code, true
        elseif direction == "l" then
            return lefttoright_code, true
        end
    end
    return lefttoright_code, false
end

local function resolve_explicit(list,size,baselevel)
    -- X1
    local level    = baselevel
    local override = "on"
    local stack    = { }
    local nofstack = 0
    for i=1,size do
        local entry     = list[i]
        local direction = entry.direction
        -- X2
        if direction == "rle" then
            if nofstack < maximum_stack then
                nofstack        = nofstack + 1
                stack[nofstack] = { level, override }
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
                stack[nofstack] = { level, override }
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
                stack[nofstack] = { level, override }
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
                stack[nofstack] = { level, override }
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
            if noifstack > 0 then
                local stacktop  = stack[nofstack]
                nofstack        = nofstack - 1
                level           = stacktop[1]
                override        = stacktop[2]
                entry.level     = level
                entry.direction = "bn"
                entry.remove    = true
            elseif trace_directions then
                report_directions("stack underflow at position %a with direction %a",i,direction)
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

local function resolve_weak(list,size,start,limit,sor,eor)
    -- W1
    for i=start,limit do
        local entry = list[i]
        if entry.direction == "nsm" then
            if i == start then
                entry.direction = sor
            else
                entry.direction = list[i-1].direction
            end
        end
    end
    -- W2
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
    -- W3
    for i=start,limit do
        local entry = list[i]
        if entry.direction == "al" then
            entry.direction = "r"
        end
    end
    -- W4
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
    -- W5
    local i = start
    while i <= limit do
        if list[i].direction == "et" then
            local runstart     = i
            local runlimit     = find_run_limit_et(list,runstart,limit) -- when moved inline we can probably collapse a lot
            local rundirection = runstart == start and sor or list[runstart-1].direction
            if rundirection ~= "en" then
                rundirection = runlimit == limit and eor or list[runlimit+1].direction
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
    -- W6
    for i=start,limit do
        local entry     = list[i]
        local direction = entry.direction
        if direction == "es" or direction == "et" or direction == "cs" then
            entry.direction = "on"
        end
    end
    -- W7
    for i=start,limit do
        local entry = list[i]
        if entry.direction == "en" then
            local prev_strong = sor
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

local function resolve_neutral(list,size,start,limit,sor,eor)
    -- N1, N2
    for i=start,limit do
        local entry = list[i]
        if b_s_ws_on[entry.direction] then
            local leading_direction, trailing_direction, resolved_direction
            local runstart = i
            local runlimit = find_run_limit_b_s_ws_on(list,runstart,limit)
            if runstart == start then
                leading_direction = sor
            else
                leading_direction = list[runstart-1].direction
                if leading_direction == "en" or leading_direction == "an" then
                    leading_direction = "r"
                end
            end
            if runlimit == limit then
                trailing_direction = eor
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
                resolved_direction = entry.level % 2 == 1 and "r" or "l" -- direction_of_level(entry.level)
            end
            for j=runstart,runlimit do
                list[j].direction = resolved_direction
            end
            i = runlimit
        end
        i = i + 1
    end
end

-- local function resolve_implicit(list,size,start,limit,sor,eor)
--     -- I1
--     for i=start,limit do
--         local entry = list[i]
--         local level = entry.level
--         if level % 2 ~= 1 then -- not odd(level)
--             local direction = entry.direction
--             if direction == "r" then
--                 entry.level = level + 1
--             elseif direction == "an" or direction == "en" then
--                 entry.level = level + 2
--             end
--         end
--     end
--     -- I2
--     for i=start,limit do
--         local entry = list[i]
--         local level = entry.level
--         if level % 2 == 1 then -- odd(level)
--             local direction = entry.direction
--             if direction == "l" or direction == "en" or direction == "an" then
--                 entry.level = level + 1
--             end
--         end
--     end
-- end

local function resolve_implicit(list,size,start,limit,sor,eor)
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

local function resolve_levels(list,size,baselevel)
    -- X10
    local start = 1
    while start < size do
        local level = list[start].level
        local limit = start + 1
        while limit < size and list[limit].level == level do
            limit = limit + 1
        end
        local prev_level = start == 1    and baselevel or list[start-1].level
        local next_level = limit == size and baselevel or list[limit+1].level
        local sor = (level > prev_level and level or prev_level) % 2 == 1 and "r" or "l" -- direction_of_level(max(level,prev_level))
        local eor = (level > next_level and level or next_level) % 2 == 1 and "r" or "l" -- direction_of_level(max(level,next_level))
        -- W1 .. W7
        resolve_weak(list,size,start,limit,sor,eor)
        -- N1 .. N2
        resolve_neutral(list,size,start,limit,sor,eor)
        -- I1 .. I2
        resolve_implicit(list,size,start,limit,sor,eor)
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

local function insert_dir_points(list,size)
    -- L2, but no actual reversion is done, we simply annotate where
    -- begindir/endddir node will be inserted.
    local maxlevel = 0
    local finaldir = false
    for i=1,size do
        local level = list[i].level
        if level > maxlevel then
            maxlevel = level
        end
    end
    for level=0,maxlevel do
        local started  = false
        local begindir = nil
        local enddir   = nil
        if level % 2 == 1 then
            begindir = righttoleft_code
            enddir   = righttoleft_code
        else
            begindir = lefttoright_code
            enddir   = lefttoright_code
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
                    list[i-1].enddir = enddir
                    started          = false
                end
            end
        end
        -- make sure to close the run at end of line
        if started then
            finaldir = enddir
        end
    end
    if finaldir then
        list[size].enddir = finaldir
    end
end

local function apply_to_list(list,size,head,pardir)
    local index   = 1
    local current = head
    while current do
        if index > size then
            report_directions("fatal error, size mismatch")
            break
        end
        local id       = getid(current)
        local entry    = list[index]
        local begindir = entry.begindir
        local enddir   = entry.enddir
        setprop(current,"directions",true)
        if id == glyph_code then
            local mirror = entry.mirror
            if mirror then
                setchar(current,mirror)
            end
            if trace_directions then
                local direction = entry.direction
                setcolor(current,direction,false,mirror)
            end
        elseif id == hlist_code or id == vlist_code then
            setdirection(current,pardir) -- is this really needed?
        elseif id == glue_code then
            if enddir and getsubtype(current) == parfillskip_code then
                -- insert the last enddir before \parfillskip glue
                local d = new_direction(enddir,true)
             -- setprop(d,"directions",true)
             -- setattrlist(d,current)
                head = insert_node_before(head,current,d)
                enddir = false
            end
        elseif begindir then
            if id == localpar_code and start_of_par(current) then
                -- localpar should always be the 1st node
                local d = new_direction(begindir)
             -- setprop(d,"directions",true)
             -- setattrlist(d,current)
                head, current = insert_node_after(head,current,d)
                begindir = nil
            end
        end
        if begindir then
            local d = new_direction(begindir)
         -- setprop(d,"directions",true)
         -- setattrlist(d,current)
            head = insert_node_before(head,current,d)
        end
        local skip = entry.skip
        if skip and skip > 0 then
            for i=1,skip do
                current = getnext(current)
                setprop(current,"directions",true)
            end
        end
        if enddir then
            local d = new_direction(enddir,true)
         -- setprop(d,"directions",true)
         -- setattrlist(d,current)
            head, current = insert_node_after(head,current,d)
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
    return head
end

local function process(head,direction,only_one,where)
    -- This is an adapted version:
    local list, size = build_list(head)
    local baselevel, dirfound = get_baselevel(head,list,size,direction)
    if not dirfound and trace_details then
        report_directions("no initial direction found, gambling")
    end
    if trace_details then
        report_directions("before : %s",show_list(list,size,"original"))
    end
    resolve_explicit(list,size,baselevel)
    resolve_levels(list,size,baselevel)
    insert_dir_points(list,size)
    if trace_details then
        report_directions("after  : %s",show_list(list,size,"direction"))
        report_directions("result : %s",show_done(list,size))
    end
    return apply_to_list(list,size,head,baselevel)
end

directions.installhandler(interfaces.variables.one,process)
