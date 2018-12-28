if not modules then modules = { } end modules ['math-dir'] = {
    version   = 1.001,
    comment   = "companion to typo-dir.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- As I'm wrapping up the updated math support (for CTX/TUG 2013) I wondered about numbers in
-- r2l math mode. Googling lead me to TUGboat, Volume 25 (2004), No. 2 where I see numbers
-- running from left to right. Makes me wonder how far we should go. And as I was looking
-- into bidi anyway, it's a nice distraction.
--
-- I first tried to hook something into noads but that gets pretty messy due to indirectness
-- char noads. If needed, I'll do it that way. With regards to spacing: as we can assume that
-- only numbers are involved we can safely swap them and the same is true for mirroring. But
-- anyway, I'm not too happy with this solution so eventually I'll do something with noads (as
-- an alternative method). Yet another heuristic approach.

local nodes, node = nodes, node

local trace_directions   = false  trackers.register("typesetters.directions.math", function(v) trace_directions = v end)

local report_directions  = logs.reporter("typesetting","math directions")

local nuts               = nodes.nuts
local tonut              = nuts.tonut
local tonode             = nuts.tonode

local getnext            = nuts.getnext
local getchar            = nuts.getchar
local getid              = nuts.getid
local getlist            = nuts.getlist
local getattr            = nuts.getattr

local setchar            = nuts.setchar
local setlist            = nuts.setlist

local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after

local nodecodes          = nodes.nodecodes
local enableaction       = nodes.tasks.enableaction

local glyph_code         = nodecodes.glyph
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist

local nodepool           = nuts.pool

local new_direction      = nodepool.direction

local lefttoright_code   = nodes.dirvalues.lefttoright

local chardirections     = characters.directions
local charmirrors        = characters.mirrors
local charclasses        = characters.textclasses

local directions         = typesetters.directions or { }

local a_mathbidi         = attributes.private('mathbidi')

local function processmath(head)
    local current = head
    local start   = nil
    local stop    = nil
    local function capsulate()
        head = insert_node_before(head,start,new_direction(lefttoright_code))
        insert_node_after(head,stop,new_direction(lefttoright_code,true))
        if trace_directions then
            report_directions("reversed: %s",nodes.listtoutf(start,false,false,stop))
        end
        start = false
        stop  = nil
    end
    while current do
        local id = getid(current)
        if id == glyph_code then
            local char = getchar(current)
            local cdir = chardirections[char]
            if cdir == "en" or cdir == "an" then -- we could check for mathclass punctuation
                if not start then
                    start = current
                end
                stop = current
            else
                if not start then
                    -- nothing
                elseif start == stop then
                    start = nil
                else
                    capsulate()
                end
                if cdir == "on" then
                    local mirror = charmirrors[char]
                    if mirror then
                        local class = charclasses[char]
                        if class == "open" or class == "close" then
                            setchar(current,mirror)
                            if trace_directions then
                                report_directions("mirrored: %C to %C",char,mirror)
                            end
                        end
                    end
                end
            end
        elseif not start then
            -- nothing
            if id == hlist_code or id == vlist_code then
                local list = processmath(getlist(current))
                setlist(current,list)
            end
        elseif start == stop then
            start = nil
        else
            capsulate(head,start,stop)
            -- math can pack things into hlists .. we need to make sure we don't process
            -- too often: needs checking
            if id == hlist_code or id == vlist_code then
                local list = processmath(getlist(current))
                setlist(current,list)
            end
        end
        current = getnext(current)
    end
    if not start then
        -- nothing
    elseif start == stop then
        -- nothing
    else
        capsulate()
    end
    return head
end

local enabled = false

function directions.processmath(head) -- style, penalties
    if enabled then
        local a = getattr(head,a_mathbidi)
        if a and a > 0 then
            return processmath(head)
        end
    end
end

function directions.setmath(n)
    if not enabled and n and n > 0 then
        if trace_directions then
            report_directions("enabling directions handler")
        end
        enableaction("math","typesetters.directions.processmath")
        enabled = true
    end
end

interfaces.implement {
    name      = "setmathdirection",
    actions   = directions.setmath,
    arguments = "integer"
}
