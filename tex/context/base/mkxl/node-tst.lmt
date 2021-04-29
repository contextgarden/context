if not modules then modules = { } end modules ['node-tst'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nodes, node = nodes, node

local chardata                   = characters.data
local nodecodes                  = nodes.nodecodes
local gluecodes                  = nodes.gluecodes

local glue_code                  = nodecodes.glue
local penalty_code               = nodecodes.penalty
local kern_code                  = nodecodes.kern
local glyph_code                 = nodecodes.glyph

local abovedisplayshortskip_code = gluecodes.abovedisplayshortskip
local belowdisplayshortskip_code = gluecodes.belowdisplayshortskip

local nuts                       = nodes.nuts

local getnext                    = nuts.getnext
local getprev                    = nuts.getprev
local getid                      = nuts.getid
local getchar                    = nuts.getchar
local getsubtype                 = nuts.getsubtype
local getkern                    = nuts.getkern
local getpenalty                 = nuts.getpenalty
local getwidth                   = nuts.getwidth

function nuts.somespace(n,all)
    if n then
        local id = getid(n)
        if id == glue_code then
            return (all or (getwidth(n) ~= 0)) and glue_code -- temp: or 0
        elseif id == kern_code then
            return (all or (getkern(n) ~= 0)) and kern_code
        elseif id == glyph_code then
         -- maybe more category checks are needed
            return (chardata[getchar(n)].category == "zs") and glyph_code
        end
    end
    return false
end

function nuts.somepenalty(n,value)
    if n then
        local id = getid(n)
        if id == penalty_code then
            if value then
                return getpenalty(n) == value
            else
                return true
            end
        end
    end
    return false
end

function nuts.is_display_math(head)
    local n = getprev(head)
    while n do
        local id = getid(n)
        if id == penalty_code then
        elseif id == glue_code then
            if getsubtype(n) == abovedisplayshortskip_code then
                return true
            end
        else
            break
        end
        n = getprev(n)
    end
    n = getnext(head)
    while n do
        local id = getid(n)
        if id == penalty_code then
        elseif id == glue_code then
            if getsubtype(n) == belowdisplayshortskip_code then
                return true
            end
        else
            break
        end
        n = getnext(n)
    end
    return false
end

nodes.leftmarginwidth  = nodes.vianuts(nuts.leftmarginwidth)
nodes.rightmarginwidth = nodes.vianuts(nuts.rightmarginwidth)
nodes.somespace        = nodes.vianuts(nuts.somespace)
nodes.somepenalty      = nodes.vianuts(nuts.somepenalty)
nodes.is_display_math  = nodes.vianuts(nuts.is_display_math)
