if not modules then modules = { } end modules ['typo-sus'] = {
    version   = 1.001,
    comment   = "companion to typo-sus.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local punctuation = {
    po = true,
}

local openquote = {
    ps = true,
    pi = true,
}

local closequote = {
    pe = true,
    pf = true,
}

local categories    = characters.categories

local nodecodes     = nodes.nodecodes

local glyph_code    = nodecodes.glyph
local kern_code     = nodecodes.kern
local penalty_code  = nodecodes.penalty
local glue_code     = nodecodes.glue
local math_code     = nodecodes.math
local hlist_code    = nodecodes.hlist

local nuts          = nodes.nuts
local tonut         = nodes.tonut
local tonode        = nodes.tonode

local getid         = nuts.getid
local getchar       = nuts.getchar
local getprev       = nuts.getprev
local getnext       = nuts.getnext
local getfield      = nuts.getfield
local getattr       = nuts.getattr
local getfont       = nuts.getfont

local setcolor      = nodes.tracers.colors.set
local insert_before = nuts.insert_before
local insert_after  = nuts.insert_after
local end_of_math   = nuts.end_of_math

local nodepool      = nuts.pool

local new_rule      = nodepool.rule
local new_kern      = nodepool.kern
local new_penalty   = nodepool.penalty

local a_characters  = attributes.private("characters")

local threshold     = 65536 / 4

local function special(n)
    if n then
        local id = getid(n)
        if id == kern_code then
            local kern = getfield(n,"kern")
            return kern < threshold
        elseif id == penalty_code then
            return true
        elseif id == glue_code then
            local width = getfield(getfield(n,"spec"),"width")
            return width < threshold
        elseif id == hlist_code then
            local width = getfield(n,"width")
            return width < threshold
        end
    else
        return false
    end
end

local function goback(current)
    local prev = getprev(current)
    while prev and special(prev) do
        prev = getprev(prev)
    end
    if prev then
        return prev, getid(prev)
    end
end

local function goforward(current)
    local next = getnext(current)
    while next and special(next) do
        next = getnext(next)
    end
    if next then
        return next, getid(next)
    end
end

local function mark(head,current,id,color)
    if id == glue_code then
        -- the glue can have stretch and/or shrink so the rule can overlap with the
        -- following glyph .. no big deal as that one then sits on top of the rule
        local width = getfield(getfield(current,"spec"),"width")
        local rule  = new_rule(width)
        local kern  = new_kern(-width)
        head = insert_before(head,current,rule)
        head = insert_before(head,current,kern)
        setcolor(rule,color)
    elseif id == kern_code then
        local width = getfield(current,"kern")
        local rule  = new_rule(width)
        local kern  = new_kern(-width)
        head = insert_before(head,current,rule)
        head = insert_before(head,current,kern)
        setcolor(rule,color)
    else
        local width = getfield(current,"width")
        local rule  = new_rule(width,getfield(current,"height"),getfield(current,"depth"))
        local kern  = new_kern(-width)
        head = insert_before(head,current,rule)
        head = insert_before(head,current,kern)
        setcolor(rule,color)
        setcolor(current,"white")
    end
    return head, current
end

-- we can cache the font and skip ahead to next but it doesn't
-- save enough time and it makes the code looks bad too ... after
-- all, we seldom use this

function typesetters.showsuspects(head)
    local head     = tonut(head)
    local current  = head
    local lastdone = nil
    while current do
        local id = getid(current)
        if id == glyph_code then
            local char = getchar(current)
            local code = categories[char]
            local done = false
            if punctuation[code] then
                local prev, pid = goback(current)
                if prev and pid == glue_code then
                    done = "darkblue"
                elseif prev and pid == math_code then
                    done = "darkgray"
                else
                    local next, nid = goforward(current)
                    if next and nid ~= glue_code then
                        done = "darkblue"
                    end
                end
            elseif openquote[code] then
                local next, nid = goforward(current)
                if next and nid == glue_code then
                    done = "darkred"
                end
            elseif closequote[code] then
                local prev, pid = goback(current)
                if prev and pid == glue_code then
                    done = "darkred"
                end
            else
                local prev, pid = goback(current)
                if prev then
                    if pid == math_code then
                        done = "darkgray"
                    elseif pid == glyph_code and getfont(current) ~= getfont(prev) then
                        if lastdone ~= prev then
                            done = "darkgreen"
                        end
                    end
                end
                if not done then
                    local next, nid = goforward(current)
                    if next then
                        if nid == math_code then
                            done = "darkgray"
                        elseif nid == glyph_code and getfont(current) ~= getfont(next) then
                            if lastdone ~= prev then
                                done = "darkgreen"
                            end
                        end
                    end
                end
            end
            if done then
                head     = mark(head,current,id,done)
                lastdone = current
            end
            current = getnext(current)
        elseif id == math_code then
            current = getnext(end_of_math(current))
        elseif id == glue_code then
            local a = getattr(current,a_characters)
            if a then
                local prev = getprev(current)
                local prid = prev and getid(prev)
                if prid == penalty_code and getfield(prev,"penalty") == 10000 then
                    head = mark(head,current,id,"orange")
                    head = insert_before(head,current,new_penalty(10000))
                else
                    head = mark(head,current,id,"darkmagenta")
                end
            end
            current = getnext(current)
        else
            current = getnext(current)
        end
    end
    return tonode(head), false
end

nodes.tasks.appendaction("processors","after","typesetters.showsuspects")
nodes.tasks.disableaction("processors","typesetters.showsuspects")

-- or maybe a directive

trackers.register("typesetters.suspects",function(v)
    nodes.tasks.setaction("processors","typesetters.showsuspects",v)
end)

