if not modules then modules = { } end modules ['typo-sus'] = {
    version   = 1.001,
    comment   = "companion to typo-sus.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next

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

local weird = {
    lm = true,
    no = true,
}

local categories      = characters.categories

local nodecodes       = nodes.nodecodes

local glyph_code      = nodecodes.glyph
local kern_code       = nodecodes.kern
local penalty_code    = nodecodes.penalty
local glue_code       = nodecodes.glue
local math_code       = nodecodes.math
local hlist_code      = nodecodes.hlist
local vlist_code      = nodecodes.vlist

local nuts            = nodes.nuts

local getid           = nuts.getid
local getprev         = nuts.getprev
local getnext         = nuts.getnext
local getattr         = nuts.getattr
local getfont         = nuts.getfont
local getlist         = nuts.getlist
local getkern         = nuts.getkern
local getpenalty      = nuts.getpenalty
local getwidth        = nuts.getwidth
local getwhd          = nuts.getwhd
local isglyph         = nuts.isglyph

local setattr         = nuts.setattr
local setlist         = nuts.setlist

local setcolor        = nodes.tracers.colors.set
local insert_before   = nuts.insert_before
local insert_after    = nuts.insert_after
local end_of_math     = nuts.end_of_math

local nodepool        = nuts.pool

local new_rule        = nodepool.rule
local new_kern        = nodepool.kern
local new_hlist       = nodepool.hlist
----- new_penalty     = nodepool.penalty

local a_characters    = attributes.private("characters")
local a_suspecting    = attributes.private('suspecting')
local a_suspect       = attributes.private('suspect')
local texsetattribute = tex.setattribute
local unsetvalue      = attributes.unsetvalue
local enabled         = false

local enableaction    = nodes.tasks.enableaction

local threshold       = 65536 / 4

local function special(n)
    if n then
        local id = getid(n)
        if id == kern_code then
            return getkern(n) < threshold
        elseif id == penalty_code then
            return true
        elseif id == glue_code then
            return getwidth(n) < threshold
        elseif id == hlist_code then
            return getwidth(n) < threshold
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
        local width = getwidth(current)
        local rule  = new_rule(width)
        local kern  = new_kern(-width)
        head = insert_before(head,current,rule)
        head = insert_before(head,current,kern)
        setcolor(rule,color)
 -- elseif id == kern_code then
 --     local width = getkern(current)
 --     local rule  = new_rule(width)
 --     local kern  = new_kern(-width)
 --     head = insert_before(head,current,rule)
 --     head = insert_before(head,current,kern)
 --     setcolor(rule,color)
    else
        local width, height, depth = getwhd(current)
        local extra = fonts.hashes.xheights[getfont(current)] / 2
        local rule  = new_rule(width,height+extra,depth+extra)
        local hlist = new_hlist(rule)
        head = insert_before(head,current,hlist)
        setcolor(rule,color)
        setcolor(current,"white")
    end
    return head, current
end

-- we can cache the font and skip ahead to next but it doesn't
-- save enough time and it makes the code looks bad too ... after
-- all, we seldom use this

local colors = {
    "darkred",
    "darkgreen",
    "darkblue",
    "darkcyan",
    "darkmagenta",
    "darkyellow",
    "darkgray",
    "orange",
}

local found = 0

function typesetters.marksuspects(head)
    local current  = head
    local lastdone = nil
    while current do
        if getattr(current,a_suspecting) then
            local char, id = isglyph(current)
            if char then
                local code = categories[char]
                local done = false
                if punctuation[code] then
                    local prev, pid = goback(current)
                    if prev and pid == glue_code then
                        done = 3 -- darkblue
                    elseif prev and pid == math_code then
                        done = 3 -- darkblue
                    else
                        local next, nid = goforward(current)
                        if next and nid ~= glue_code then
                            done = 3 -- darkblue
                        end
                    end
                elseif openquote[code] then
                    local next, nid = goforward(current)
                    if next and nid == glue_code then
                        done = 1 -- darkred
                    end
                elseif closequote[code] then
                    local prev, pid = goback(current)
                    if prev and pid == glue_code then
                        done = 1 -- darkred
                    end
                elseif weird[code] then
                    done = 2 -- darkgreen
                else
                    local prev, pid = goback(current)
                    if prev then
                        if pid == math_code then
                            done = 7-- darkgray
                        elseif pid == glyph_code and getfont(current) ~= getfont(prev) then
                            if lastdone ~= prev then
                                done = 2 -- darkgreen
                            end
                        end
                    end
                    if not done then
                        local next, nid = goforward(current)
                        if next then
                            if nid == math_code then
                                done = 7 -- darkgray
                            elseif nid == glyph_code and getfont(current) ~= getfont(next) then
                                if lastdone ~= prev then
                                    done = 2 -- darkgreen
                                end
                            end
                        end
                    end
                end
                if done then
                    setattr(current,a_suspect,done)
                    lastdone = current
                    found = found + 1
                end
                current = getnext(current)
            elseif id == math_code then
                current = getnext(end_of_math(current))
            elseif id == glue_code then
                local a = getattr(current,a_characters)
                if a then
                    local prev = getprev(current)
                    local prid = prev and getid(prev)
                    local done = false
                    if prid == penalty_code and getpenalty(prev) == 10000 then
                        done = 8 -- orange
                    else
                        done = 5 -- darkmagenta
                    end
                    if done then
                        setattr(current,a_suspect,done)
                     -- lastdone = current
                        found = found + 1
                    end
                end
                current = getnext(current)
            else
                current = getnext(current)
            end
        else
            current = getnext(current)
        end
    end
    return head
end

local function showsuspects(head)
    local current = head
    while current do
        local id = getid(current)
        if id == glyph_code then
            local a = getattr(current,a_suspect)
            if a then
                head, current = mark(head,current,id,colors[a])
            end
        elseif id == glue_code then
            local a = getattr(current,a_suspect)
            if a then
                head, current = mark(head,current,id,colors[a])
            end
        elseif id == math_code then
            current = end_of_math(current)
        elseif id == hlist_code or id == vlist_code then
            local list = getlist(current)
            if list then
                local l = showsuspects(list)
                if l ~= list then
                    setlist(current,l)
                end
            end
        end
        current = getnext(current)
    end
    return head
end

function typesetters.showsuspects(head)
    if found > 0 then
        return showsuspects(head)
    else
        return head
    end
end

-- or maybe a directive

trackers.register("typesetters.suspects",function(v)
    texsetattribute(a_suspecting,v and 1 or unsetvalue)
    if v and not enabled then
        enableaction("processors","typesetters.marksuspects")
        enableaction("shipouts",  "typesetters.showsuspects")
        enabled = true
    end
end)

