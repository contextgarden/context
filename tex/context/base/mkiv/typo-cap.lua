if not modules then modules = { } end modules ['typo-cap'] = {
    version   = 1.001,
    comment   = "companion to typo-cap.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
    }

local next, type, tonumber = next, type, tonumber
local format, insert = string.format, table.insert
local div, getrandom = math.div, utilities.randomizer.get

local trace_casing = false  trackers  .register("typesetters.casing",            function(v) trace_casing = v end)
local check_kerns  = true   directives.register("typesetters.casing.checkkerns", function(v) check_kerns  = v end)

local report_casing = logs.reporter("typesetting","casing")

local nodes, node = nodes, node

local nuts            = nodes.nuts

local getnext         = nuts.getnext
local getprev         = nuts.getprev
local getid           = nuts.getid
----- getattr         = nuts.getattr
local takeattr        = nuts.takeattr
local getfont         = nuts.getfont
local getsubtype      = nuts.getsubtype
local getchar         = nuts.getchar
local isglyph         = nuts.isglyph
local getdisc         = nuts.getdisc

local setattr         = nuts.setattr
local setchar         = nuts.setchar
local setfont         = nuts.setfont

local copy_node       = nuts.copy
local end_of_math     = nuts.end_of_math
local insert_after    = nuts.insert_after
local find_attribute  = nuts.find_attribute

local nextglyph       = nuts.traversers.glyph

local nodecodes       = nodes.nodecodes
local kerncodes       = nodes.kerncodes

local glyph_code      = nodecodes.glyph
local kern_code       = nodecodes.kern
local disc_code       = nodecodes.disc
local math_code       = nodecodes.math

local fontkern_code   = kerncodes.fontkern

local enableaction    = nodes.tasks.enableaction

local newkern         = nuts.pool.kern

local fonthashes      = fonts.hashes
local fontdata        = fonthashes.identifiers
local fontchar        = fonthashes.characters

local variables       = interfaces.variables
local v_reset         = variables.reset

local texsetattribute = tex.setattribute
local unsetvalue      = attributes.unsetvalue

typesetters           = typesetters or { }
local typesetters     = typesetters

typesetters.cases     = typesetters.cases or { }
local cases           = typesetters.cases

cases.actions         = { }
local actions         = cases.actions
local a_cases         = attributes.private("case")

local extract         = bit32.extract
local run             = 0 -- a trick to make neighbouring ranges work
local blocked         = { }

local function set(tag,font)
    if run == 0x40 then -- 2^6
        run = 1
    else
        run = run + 1
    end
    local a = font * 0x10000 + tag * 0x100 + run
    blocked[a] = false
    return a
end

local function get(a)
    return
        extract(a, 8, 8), -- tag
        extract(a,16,12), -- font
        extract(a, 0, 8)  -- run
end

-- a previous implementation used char(0) as placeholder for the larger font, so we needed
-- to remove it before it can do further harm ... that was too tricky as we use char 0 for
-- other cases too
--
-- we could do the whole glyph run here (till no more attributes match) but then we end up
-- with more code .. maybe i will clean this up anyway as the lastfont hack is somewhat ugly
-- ... on the other hand, we need to deal with cases like:
--
-- \WORD {far too \Word{many \WORD{more \word{pushed} in between} useless} words}

local uccodes    = characters.uccodes
local lccodes    = characters.lccodes
local categories = characters.categories

-- true false true == mixed

local function replacer(start,codes)
    local char, fnt = isglyph(start)
    local dc = codes[char]
    if dc then
        local ifc = fontchar[fnt]
        if type(dc) == "table" then
            for i=1,#dc do
                if not ifc[dc[i]] then
                    return start, false
                end
            end
            for i=#dc,1,-1 do
                local chr = dc[i]
                if i == 1 then
                    setchar(start,chr)
                else
                    local g = copy_node(start)
                    setchar(g,chr)
                    insert_after(start,start,g)
                end
            end
        elseif ifc[dc] then
            setchar(start,dc)
        end
    end
    return start
end

local registered, n = { }, 0

local function register(name,f)
    if type(f) == "function" then
        n = n + 1
        actions[n] = f
        registered[name] = n
        return n
    else
        local n = registered[f]
        registered[name] = n
        return n
    end
end

cases.register = register

local function WORD(start,attr,lastfont,n,count,where,first)
    lastfont[n] = false
    return replacer(first or start,uccodes)
end

local function word(start,attr,lastfont,n,count,where,first)
    lastfont[n] = false
    return replacer(first or start,lccodes)
end

local function Words(start,attr,lastfont,n,count,where,first) -- looks quite complex
    if where == "post" then
        return
    end
    if count == 1 and where ~= "post" then
        replacer(first or start,uccodes)
        return start, true
    else
        return start, true
    end
end

local function Word(start,attr,lastfont,n,count,where,first)
    blocked[attr] = true
    return Words(start,attr,lastfont,n,count,where,first)
end

local function camel(start,attr,lastfont,n,count,where,first)
    word(start,attr,lastfont,n,count,where,first)
    Words(start,attr,lastfont,n,count,where,first)
    return start, true
end

-- local function mixed(start,attr,lastfont,n,count,where,first)
--     if where == "post" then
--         return
--     end
--     local used = first or start
--     local char = getchar(first)
--     local dc   = uccodes[char]
--     if not dc then
--         -- quit
--     elseif dc == char then
--         local lfa = lastfont[n]
--         if lfa then
--             setfont(first,lfa)
--         end
--     else
--         replacer(first or start,uccodes)
--     end
--     return start, true
-- end

local function mixed(start,attr,lastfont,n,count,where,first)
    if where == "post" then
        return
    end
    local used = first or start
    local char = getchar(used)
    local dc   = uccodes[char]
    if not dc then
        -- quit
    elseif dc == char then
        local lfa = lastfont[n]
        if lfa then
            setfont(used,lfa)
        end
    elseif check_kerns then
        local p = getprev(used)
        if p and getid(p) == glyph_code then
            local c = lccodes[char]
            local c = type(c) == "table" and c[1] or c
            replacer(used,uccodes)
            local fp = getfont(p)
            local fc = getfont(used)
            if fp ~= fc then
                local k = fonts.getkern(fontdata[fp],getchar(p),c)
                if k ~= 0 then
                    insert_after(p,p,newkern(k))
                end
            end
        else
            replacer(used,uccodes)
        end
    else
        replacer(used,uccodes)
    end
    return start, true
end

local function Capital(start,attr,lastfont,n,count,where,first,once) -- 3
    local used = first or start
    if count == 1 and where ~= "post" then
        local lfa = lastfont[n]
        if lfa then
            local dc = uccodes[getchar(used)]
            if dc then
                setfont(used,lfa)
            end
        end
    end
    local s, c = replacer(first or start,uccodes)
    if once then
        lastfont[n] = false -- here
    end
    return start, c
end

local function capital(start,attr,lastfont,n,where,count,first,count) -- 4
    return Capital(start,attr,lastfont,n,where,count,first,true)
end

local function none(start,attr,lastfont,n,count,where,first)
    return start, true
end

local function randomized(start,attr,lastfont,n,count,where,first)
    local used  = first or start
    local char  = getchar(used)
    local font  = getfont(used)
    local tfm   = fontchar[font]
    lastfont[n] = false
    local kind  = categories[char]
    if kind == "lu" then
        while true do
            local n = getrandom("capital lu",0x41,0x5A)
            if tfm[n] then -- this also intercepts tables
                setchar(used,n)
                return start
            end
        end
    elseif kind == "ll" then
        while true do
            local n = getrandom("capital ll",0x61,0x7A)
            if tfm[n] then -- this also intercepts tables
                setchar(used,n)
                return start
            end
        end
    end
    return start
end

register(variables.WORD,   WORD)              --   1
register(variables.word,   word)              --   2
register(variables.Word,   Word)              --   3
register(variables.Words,  Words)             --   4
register(variables.capital,capital)           --   5
register(variables.Capital,Capital)           --   6
register(variables.none,   none)              --   7 (dummy)
register(variables.random, randomized)        --   8
register(variables.mixed,  mixed)             --   9
register(variables.camel,  camel)             --  10

register(variables.cap,    variables.capital) -- clone
register(variables.Cap,    variables.Capital) -- clone

-- This can be more clever: when we unset we can actually use the same attr ref if
-- needed. Using properties to block further usage is not faster.

function cases.handler(head) -- not real fast but also not used on much data
    local start    = head
    local lastfont = { }
    local lastattr = nil
    local count    = 0
    local previd   = nil
    local prev     = nil
    while start do -- while because start can jump ahead
        local id = getid(start)
        if id == glyph_code then
         -- local attr = getattr(start,a_cases)
            local attr = takeattr(start,a_cases)
            if attr and attr > 0 and not blocked[attr] then
                if attr ~= lastattr then
                    lastattr = attr
                    count    = 1
                else
                    count    = count + 1
                end
             -- setattr(start,a_cases,unsetvalue) -- not needed
                local n, id, m = get(attr)
                if lastfont[n] == nil then
                    lastfont[n] = id
                end
                local action = actions[n] -- map back to low number
                if action then
                    local quit
                    start, quit = action(start,attr,lastfont,n,count)
                    if trace_casing then
                        report_casing("case trigger %a, instance %a, fontid %a, result %a",n,m,id,quit and "-" or "+")
                    end
                elseif trace_casing then
                    report_casing("unknown case trigger %a",n)
                end
            end
        elseif id == disc_code then
         -- local attr = getattr(start,a_cases)
            local attr = takeattr(start,a_cases)
            if attr and attr > 0 and not blocked[attr] then
                if attr ~= lastattr then
                    lastattr = attr
                    count    = 0
                end
             -- setattr(start,a_cases,unsetvalue) -- not needed
                local n, id, m = get(attr)
                if lastfont[n] == nil then
                    lastfont[n] = id
                end
                local action = actions[n] -- map back to low number
                if action then
                    local pre, post, replace = getdisc(start)
                    if replace then
                        local cnt = count
                        for g in nextglyph, replace do
                            cnt = cnt + 1
                            takeattr(g,a_cases)
                         -- setattr(g,a_cases,unsetvalue)
                            local h, quit = action(start,attr,lastfont,n,cnt,"replace",g)
                            if quit then
                                break
                            end
                        end
                    end
                    if pre then
                        local cnt = count
                        for g in nextglyph, pre do
                            cnt = cnt + 1
                            takeattr(g,a_cases)
                         -- setattr(g,a_cases,unsetvalue)
                            local h, quit = action(start,attr,lastfont,n,cnt,"pre",g)
                            if quit then
                                break
                            end
                        end
                    end
                    if post then
                        local cnt = count
                        for g in nextglyph, post do
                            cnt = cnt + 1
                            takeattr(g,a_cases)
                         -- setattr(g,a_cases,unsetvalue)
                            local h, quit = action(start,attr,lastfont,n,cnt,"post",g)
                            if quit then
                                break
                            end
                        end
                    end
                end
                count = count + 1
            end
        elseif id == math_code then
            start = end_of_math(start)
            count = 0
        elseif prev_id == kern_code and getsubtype(prev) == fontkern_code then
            -- still inside a word ...normally kerns are added later
        else
            count = 0
        end
        if start then
            prev   = start
            previd = id
            start  = getnext(start)
        end
    end
    return head
end

-- function cases.handler(head) -- not real fast but also not used on much data
--     local attr, start = find_attribute(head,a_cases)
--     if not start then
--         return head, false
--     end
--     local lastfont = { }
--     local lastattr = nil
--     local count    = 0
--     local previd   = nil
--     local prev     = nil
--     while start do
--         while start do -- while because start can jump ahead
--             local id = getid(start)
--             if id == glyph_code then
--              -- local attr = getattr(start,a_cases)
--                 local attr = takeattr(start,a_cases)
--                 if attr and attr > 0 and not blocked[attr] then
--                     if attr ~= lastattr then
--                         lastattr = attr
--                         count    = 1
--                     else
--                         count    = count + 1
--                     end
--                  -- setattr(start,a_cases,unsetvalue) -- not needed
--                     local n, id, m = get(attr)
--                     if lastfont[n] == nil then
--                         lastfont[n] = id
--                     end
--                     local action = actions[n] -- map back to low number
--                     if action then
--                         start = action(start,attr,lastfont,n,count)
--                         if trace_casing then
--                             report_casing("case trigger %a, instance %a, fontid %a, result %a",n,m,id,ok)
--                         end
--                     elseif trace_casing then
--                         report_casing("unknown case trigger %a",n)
--                     end
--                 end
--             elseif id == disc_code then
--              -- local attr = getattr(start,a_cases)
--                 local attr = takeattr(start,a_cases)
--                 if attr and attr > 0 and not blocked[attr] then
--                     if attr ~= lastattr then
--                         lastattr = attr
--                         count    = 0
--                     end
--                  -- setattr(start,a_cases,unsetvalue) -- not needed
--                     local n, id, m = get(attr)
--                     if lastfont[n] == nil then
--                         lastfont[n] = id
--                     end
--                     local action = actions[n] -- map back to low number
--                     if action then
--                         local pre, post, replace = getdisc(start)
--                         if replace then
--                             local cnt = count
--                             for g in glyph_code, replace do
--                                 cnt = cnt + 1
--                                 takeattr(g,a_cases)
--                              -- setattr(g,a_cases,unsetvalue)
--                                 local h, quit = action(start,attr,lastfont,n,cnt,"replace",g)
--                                 if quit then
--                                      break
--                                 end
--                             end
--                         end
--                         if pre then
--                             local cnt = count
--                             for g in nextglyph, pre do
--                                 cnt = cnt + 1
--                                 takeattr(g,a_cases)
--                              -- setattr(g,a_cases,unsetvalue)
--                                 local h, quit = action(start,attr,lastfont,n,cnt,"pre",g)
--                                 if quit then
--                                      break
--                                 end
--                             end
--                         end
--                         if post then
--                             local cnt = count
--                             for g in nextglyph, post do
--                                 cnt = cnt + 1
--                                 takeattr(g,a_cases)
--                              -- setattr(g,a_cases,unsetvalue)
--                                 local h, quit = action(start,attr,lastfont,n,cnt,"post",g)
--                                 if quit then
--                                      break
--                                 end
--                             end
--                         end
--                     end
--                     count = count + 1
--                 end
--             elseif id == math_code then
--                 start = end_of_math(start)
--                 count = 0
--             elseif prev_id == kern_code and getsubtype(prev) == fontkern_code then
--                 -- still inside a word ...normally kerns are added later
--             else
--                 count = 0
--                 start = getnext(start)
--                 break
--             end
--             if start then
--                 prev   = start
--                 previd = id
--                 start  = getnext(start)
--             end
--         end
--         if start then
--             attr, start = find_attribute(start,a_cases)
--         end
--     end
--     return head
-- end

-- function cases.handler(head) -- let's assume head doesn't change ... no reason
--     local lastfont = { }
--     for first, last, size, attr in nuts.words(head,a_cases) do
--         local n, id, m = get(attr)
--         if lastfont[n] == nil then
--             lastfont[n] = id
--         end
--         local action = actions[n]
--         if action then
--             action(first,attr,lastfont,n)
--         end
--     end
--     return head
-- end

local enabled = false

function cases.set(n,id)
    if n == v_reset then
        n = unsetvalue
    else
        n = registered[n] or tonumber(n)
        if n then
            if not enabled then
                enableaction("processors","typesetters.cases.handler")
                if trace_casing then
                    report_casing("enabling case handler")
                end
                enabled = true
            end
            n = set(n,id)
        else
            n = unsetvalue
        end
    end
    texsetattribute(a_cases,n)
 -- return n -- bonus
end

-- interface

interfaces.implement {
    name      = "setcharactercasing",
    actions   = cases.set,
    arguments = { "string", "integer" }
}
