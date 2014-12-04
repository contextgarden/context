if not modules then modules = { } end modules ['typo-cap'] = {
    version   = 1.001,
    comment   = "companion to typo-cap.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
    }

local next, type = next, type
local format, insert = string.format, table.insert
local div, randomnumber = math.div, math.random

local trace_casing = false  trackers.register("typesetters.casing", function(v) trace_casing = v end)

local report_casing = logs.reporter("typesetting","casing")

local nodes, node = nodes, node

local nuts            = nodes.nuts
local tonode          = nuts.tonode
local tonut           = nuts.tonut

local getfield        = nuts.getfield
local setfield        = nuts.setfield
local getnext         = nuts.getnext
local getprev         = nuts.getprev
local getid           = nuts.getid
local getattr         = nuts.getattr
local setattr         = nuts.setattr
local getfont         = nuts.getfont
local getsubtype      = nuts.getsubtype
local getchar         = nuts.getchar

local copy_node       = nuts.copy
local end_of_math     = nuts.end_of_math

local nodecodes       = nodes.nodecodes
local skipcodes       = nodes.skipcodes
local kerncodes       = nodes.kerncodes

local glyph_code      = nodecodes.glyph
local kern_code       = nodecodes.kern
local disc_code       = nodecodes.disc
local math_code       = nodecodes.math

local kerning_code    = kerncodes.kerning
local userskip_code   = skipcodes.userskip

local tasks           = nodes.tasks

local fonthashes      = fonts.hashes
local fontdata        = fonthashes.identifiers
local fontchar        = fonthashes.characters

local variables       = interfaces.variables
local v_reset         = variables.reset

local chardata        = characters.data
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

local function set(tag,font)
    if run == 2^6 then
        run = 1
    else
        run = run + 1
    end
    return font * 0x10000 + tag * 0x100 + run
end

local function get(a)
    local font = extract(a,16,12) -- 4000
    local tag  = extract(a, 8, 8) --  250
    local run  = extract(a, 0, 8) --   50
    return tag, font, run
end

-- print(get(set(  1,   0)))
-- print(get(set(  1,  99)))
-- print(get(set(  2,  96)))
-- print(get(set( 30, 922)))
-- print(get(set(250,4000)))

-- a previous implementation used char(0) as placeholder for the larger font, so we needed
-- to remove it before it can do further harm ... that was too tricky as we use char 0 for
-- other cases too
--
-- we could do the whole glyph run here (till no more attributes match) but then we end up
-- with more code .. maybe i will clean this up anyway as the lastfont hack is somewhat ugly
-- ... on the other hand, we need to deal with cases like:
--
-- \WORD {far too \Word{many \WORD{more \word{pushed} in between} useless} words}

local uccodes = characters.uccodes
local lccodes = characters.lccodes

-- true false true == mixed

local function helper(start,attr,lastfont,n,codes,special,once,keepother)
    local char = getchar(start)
    local dc   = codes[char]
    if dc then
        local fnt = getfont(start)
        if keepother and dc == char then
            local lfa = lastfont[n]
            if lfa then
                setfield(start,"font",lfa)
                return start, true
            else
                return start, false
            end
        else
            if special then
                local lfa = lastfont[n]
                if lfa then
                    local previd = getid(getprev(start))
                    if previd ~= glyph_code and previd ~= disc_code then
                        fnt = lfa
                        setfield(start,"font",lfa)
                    end
                end
            end
            local ifc = fontchar[fnt]
            if type(dc) == "table" then
                local ok = true
                for i=1,#dc do
                    -- could be cached in font
                    if not ifc[dc[i]] then
                        ok = false
                        break
                    end
                end
                if ok then
                    -- todo: use generic injector
                    local prev     = start
                    local original = start
                    for i=1,#dc do
                        local chr = dc[i]
                        prev = start
                        if i == 1 then
                            setfield(start,"char",chr)
                        else
                            local g = copy_node(original)
                            setfield(g,"char",chr)
                            local next = getnext(start)
                            setfield(g,"prev",start)
                            if next then
                                setfield(g,"next",next)
                                setfield(start,"next",g)
                                setfield(next,"prev",g)
                            end
                            start = g
                        end
                    end
                    if once then
                        lastfont[n] = false
                    end
                    return prev, true
                end
                if once then
                    lastfont[n] = false
                end
                return start, false
            elseif ifc[dc] then
                setfield(start,"char",dc)
                if once then
                    lastfont[n] = false
                end
                return start, true
            end
        end
    end
    if once then
        lastfont[n] = false
    end
    return start, false
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

local function WORD(start,attr,lastfont,n)
    lastfont[n] = false
    return helper(start,attr,lastfont,n,uccodes)
end

local function word(start,attr,lastfont,n)
    lastfont[n] = false
    return helper(start,attr,lastfont,n,lccodes)
end

local function blockrest(start)
    local n = getnext(start)
    while n do
        local id = getid(n)
        if id == glyph_code or id == disc_node and getattr(n,a_cases) == attr then
            setattr(n,a_cases,unsetvalue)
        else
         -- break -- we can have nested mess
        end
        n = getnext(n)
    end
end

local function Word(start,attr,lastfont,n) -- looks quite complex
    lastfont[n] = false
    local prev = getprev(start)
    if prev and getid(prev) == kern_code and getsubtype(prev) == kerning_code then
        prev = getprev(prev)
    end
    if not prev then
        blockrest(start)
        return helper(start,attr,lastfont,n,uccodes)
    end
    local previd = getid(prev)
    if previd ~= glyph_code and previd ~= disc_code then
        -- only the first character is treated
        blockrest(start)
        -- we could return the last in the range and save some scanning
        -- but why bother
        return helper(start,attr,lastfont,n,uccodes)
    else
        return start, false
    end
end

local function Words(start,attr,lastfont,n)
    lastfont[n] = false
    local prev = getprev(start)
    if prev and getid(prev) == kern_code and getsubtype(prev) == kerning_code then
        prev = getprev(prev)
    end
    if not prev then
        return helper(start,attr,lastfont,n,uccodes)
    end
    local previd = getid(prev)
    if previd ~= glyph_code and previd ~= disc_code then
        return helper(start,attr,lastfont,n,uccodes)
    else
        return start, false
    end
end

local function capital(start,attr,lastfont,n) -- 3
    return helper(start,attr,lastfont,n,uccodes,true,true)
end

local function Capital(start,attr,lastfont,n) -- 4
    return helper(start,attr,lastfont,n,uccodes,true,false)
end

local function mixed(start,attr,lastfont,n)
    return helper(start,attr,lastfont,n,uccodes,false,false,true)
end

local function none(start,attr,lastfont,n)
    return start, false
end

local function random(start,attr,lastfont,n)
    lastfont[n] = false
    local ch  = getchar(start)
    local tfm = fontchar[getfont(start)]
    if lccodes[ch] then
        while true do
            local d = chardata[randomnumber(1,0xFFFF)]
            if d then
                local uc = uccodes[d]
                if uc and tfm[uc] then -- this also intercepts tables
                    setfield(start,"char",uc)
                    return start, true
                end
            end
        end
    elseif uccodes[ch] then
        while true do
            local d = chardata[randomnumber(1,0xFFFF)]
            if d then
                local lc = lccodes[d]
                if lc and tfm[lc] then -- this also intercepts tables
                    setfield(start,"char",lc)
                    return start, true
                end
            end
        end
    end
    return start, false
end

local function camel(start,attr,lastfont,n)
    local start, done_1 = word(start,attr,lastfont,n)
    local start, done_2 = Words(start,attr,lastfont,n)
    return start, done_1 or done_2
end

register(variables.WORD,    WORD)              --   1
register(variables.word,    word)              --   2
register(variables.Word,    Word)              --   3
register(variables.Words,   Words)             --   4
register(variables.capital, capital)           --   5
register(variables.Capital, Capital)           --   6
register(variables.none,    none)              --   7 (dummy)
register(variables.random,  random)            --   8
register(variables.mixed,   mixed)             --   9
register(variables.camel,   camel)             --  10

register(variables.cap,     variables.capital) -- clone
register(variables.Cap,     variables.Capital) -- clone

function cases.handler(head) -- not real fast but also not used on much data
    head           = tonut(head)
    local lastfont = { }
    local lastattr = nil
    local done     = false
    local start    = head
    while start do -- while because start can jump ahead
        local id = getid(start)
        if id == glyph_code then
            local attr = getattr(start,a_cases)
            if attr and attr > 0 then
                if attr ~= lastattr then
                    lastattr = attr
                end
                setattr(start,a_cases,unsetvalue)
                local n, id, m = get(attr)
                if lastfont[n] == nil then
                    lastfont[n] = id
                end
                local action = actions[n] -- map back to low number
                if action then
                    start, ok = action(start,attr,lastfont,n)
                    if ok then
                        done = true
                    end
                    if trace_casing then
                        report_casing("case trigger %a, instance %a, fontid %a, result %a",n,m,id,ok)
                    end
                elseif trace_casing then
                    report_casing("unknown case trigger %a",n)
                end
            end
        elseif id == disc_code then
            local attr = getattr(start,a_cases)
            if attr and attr > 0 then
                if attr ~= lastattr then
                    lastattr = attr
                end
                setattr(start,a_cases,unsetvalue)
                local n, id, m = get(attr)
                if lastfont[n] == nil then
                    lastfont[n] = id
                end
                local action = actions[n] -- map back to low number
                if action then
                    local replace = getfield(start,"replace")
                    if replace then
                        action(replace,attr,lastfont,n)
                    end
                    local pre = getfield(start,"pre")
                    if pre then
                        action(pre,attr,lastfont,n)
                    end
                    local post = getfield(start,"post")
                    if post then
                        action(post,attr,lastfont,n)
                    end
                end
            end
        elseif id == math_code then
            start = end_of_math(start)
        end
        if start then -- why test
            start = getnext(start)
        end
    end
    return tonode(head), done
end

local enabled = false

function cases.set(n,id)
    if n == v_reset then
        n = unsetvalue
    else
        n = registered[n] or tonumber(n)
        if n then
            if not enabled then
                tasks.enableaction("processors","typesetters.cases.handler")
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

commands.setcharactercasing = cases.set
