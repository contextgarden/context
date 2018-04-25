if not modules then modules = { } end modules ['typo-rep'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This was rather boring to program (more of the same) but I could
-- endure it by listening to a couple cd's by The Scene and The Lau
-- on the squeezebox on my desk.

local next, type, tonumber = next, type, tonumber

local trace_stripping = false  trackers.register("nodes.stripping",  function(v) trace_stripping = v end)
                               trackers.register("fonts.stripping",  function(v) trace_stripping = v end)

local report_stripping = logs.reporter("fonts","stripping")

local nodes           = nodes
local enableaction    = nodes.tasks.enableaction

local nuts            = nodes.nuts

local getnext         = nuts.getnext
local getchar         = nuts.getchar
local isglyph         = nuts.isglyph

local getattr         = nuts.getattr

local delete_node     = nuts.delete
local replace_node    = nuts.replace
local copy_node       = nuts.copy

local nodecodes       = nodes.nodecodes

local chardata        = characters.data
local collected       = false

local a_stripping     = attributes.private("stripping")
local texsetattribute = tex.setattribute
local unsetvalue      = attributes.unsetvalue

local v_reset         = interfaces.variables.reset

-- todo: other namespace -> typesetters

nodes.stripping  = nodes.stripping  or { } local stripping  = nodes.stripping
stripping.glyphs = stripping.glyphs or { } local glyphs     = stripping.glyphs

local function initialize()
    for k, v in next, chardata do
        if v.category == "cf" and not v.visible and not glyphs[k] then
            glyphs[k] = true
        end
    end
    initialize = nil
end

local function process(what,head,current,char)
    if what == true then
        if trace_stripping then
            report_stripping("deleting %C from text",char)
        end
        head, current = delete_node(head,current)
    elseif type(what) == "function" then
        head, current = what(head,current)
        current = getnext(current)
        if trace_stripping then
            report_stripping("processing %C in text",char)
        end
    elseif what then  -- assume node
        head, current = replace_node(head,current,copy_node(what))
        current = getnext(current)
        if trace_stripping then
            report_stripping("replacing %C in text",char)
        end
    end
    return head, current
end

function nodes.handlers.stripping(head) -- use loop
    local current = head
    while current do
        local char, id = isglyph(current)
        if char then
            -- it's more efficient to keep track of what needs to be kept
            local todo = getattr(current,a_stripping)
            if todo == 1 then
                local what = glyphs[char]
                if what then
                    head, current = process(what,head,current,char)
                else -- handling of spacing etc has to be done elsewhere
                    current = getnext(current)
                end
            else
                current = getnext(current)
            end
        else
            current = getnext(current)
        end
    end
    return head
end

local enabled = false

function stripping.set(n) -- number or 'reset'
    if n == v_reset then
        n = unsetvalue
    else
        n = tonumber(n)
        if n then
            if not enabled then
                if initialize then initialize() end
                enableaction("processors","nodes.handlers.stripping")
                enabled = true
            end
        else
            n = unsetvalue
        end
    end
    texsetattribute(a_stripping,n)
end

-- interface

interfaces.implement {
    name      = "setcharacterstripping",
    actions   = stripping.set,
    arguments = "string"
}
