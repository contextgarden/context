if not modules then modules = { } end modules ['typo-dig'] = {
    version   = 1.001,
    comment   = "companion to typo-dig.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we might consider doing this after the otf pass because now osf do not work
-- out well in node mode.

local next, type, tonumber = next, type, tonumber
local format, insert = string.format, table.insert
local round, div = math.round, math.div

local trace_digits = false  trackers.register("typesetters.digits", function(v) trace_digits = v end)

local report_digits = logs.reporter("typesetting","digits")

local nodes, node = nodes, node

local nuts               = nodes.nuts

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getwidth           = nuts.getwidth
local isglyph            = nuts.isglyph
local takeattr           = nuts.takeattr

local setlink            = nuts.setlink
local setnext            = nuts.setnext
local setprev            = nuts.setprev

local hpack_node         = nuts.hpack
local traverse_id        = nuts.traverse_id
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph

local nodepool           = nuts.pool
local enableaction       = nodes.tasks.enableaction

local new_glue           = nodepool.glue

local fonthashes         = fonts.hashes
local chardata           = fonthashes.characters

local v_reset            = interfaces.variables.reset

local charbase           = characters.data
local getdigitwidth      = fonts.helpers.getdigitwidth

typesetters              = typesetters or { }
local typesetters        = typesetters

typesetters.digits       = typesetters.digits or { }
local digits             = typesetters.digits

digits.actions           = { }
local actions            = digits.actions

local a_digits           = attributes.private("digits")

-- at some point we can manipulate the glyph node so then i need
-- to rewrite this then

function nodes.aligned(head,start,stop,width,how)
    if how == "flushright" or how == "middle" then
        head, start = insert_node_before(head,start,new_glue(0,65536,65536))
    end
    if how == "flushleft" or how == "middle" then
        head, stop = insert_node_after(head,stop,new_glue(0,65536,65536))
    end
    local prv = getprev(start)
    local nxt = getnext(stop)
    setprev(start)
    setnext(stop)
    local packed = hpack_node(start,width,"exactly") -- no directional mess here, just lr
    if prv then
        setlink(prv,packed)
    end
    if nxt then
        setlink(packed,nxt)
    end
    if getprev(packed) then
        return head, packed
    else
        return packed, packed
    end
end

actions[1] = function(head,start,attr)
    local char, font = isglyph(start)
    local unic = chardata[font][char].unicode or char
    if charbase[unic].category == "nd" then -- ignore unic tables
        local oldwidth = getwidth(start)
        local newwidth = getdigitwidth(font)
        if newwidth ~= oldwidth then
            if trace_digits then
                report_digits("digit trigger %a, instance %a, char %C, unicode %U, delta %s",
                    attr%100,div(attr,100),char,unic,newwidth-oldwidth)
            end
            head, start = nodes.aligned(head,start,start,newwidth,"middle")
            return head, start
        end
    end
    return head, start
end

function digits.handler(head)
    local current = head
    while current do
        if getid(current) == glyph_code then
            local attr = takeattr(current,a_digits)
            if attr and attr > 0 then
                local action = actions[attr%100] -- map back to low number
                if action then
                    head, current = action(head,current,attr)
                elseif trace_digits then
                    report_digits("unknown digit trigger %a",attr)
                end
            end
        end
        if current then
            current = getnext(current)
        end
    end
    return head
end

local m, enabled = 0, false -- a trick to make neighbouring ranges work

function digits.set(n) -- number or 'reset'
    if n == v_reset then
        n = unsetvalue
    else
        n = tonumber(n)
        if n then
            if not enabled then
                enableaction("processors","typesetters.digits.handler")
                if trace_digits then
                    report_digits("enabling digit handler")
                end
                enabled = true
            end
            if m == 100 then
                m = 1
            else
                m = m + 1
            end
            n = m * 100 + n
        else
            n = unsetvalue
        end
    end
    texsetattribute(a_digits,n)
end

-- interface

interfaces.implement {
    name      = "setdigitsmanipulation",
    actions   = digits.set,
    arguments = "string"
}
