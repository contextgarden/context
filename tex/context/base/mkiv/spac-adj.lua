if not modules then modules = { } end modules ['spac-adj'] = {
    version   = 1.001,
    comment   = "companion to spac-adj.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- sort of obsolete code

local a_vadjust    = attributes.private('graphicvadjust')

local nodecodes    = nodes.nodecodes

local hlist_code   = nodecodes.hlist
local vlist_code   = nodecodes.vlist

local remove_node  = nodes.remove
local hpack_node   = node.hpack

local enableaction = nodes.tasks.enableaction

function nodes.handlers.graphicvadjust(head,groupcode) -- we can make an actionchain for mvl only
    if groupcode == "" then -- mvl only
        local h, p, done = head, nil, false
        while h do
            local id = h.id
            if id == hlist_code or id == vlist_code then
                local a = h[a_vadjust]
                if a then
                    if p then
                        local n
                        head, h, n = remove_node(head,h)
                        local pl = p.list
                        if n.width ~= 0 then
                            n = hpack_node(n,0,'exactly') -- todo: dir
                        end
                        if pl then
                            pl.prev = n
                            n.next = pl
                        end
                        p.list = n
                        done = true
                    else
                        -- can't happen
                    end
                else
                    p = h
                    h = h.next
                end
            else
                h = h.next
            end
        end
        return head, done
    else
        return head, false
    end
end

interfaces.implement {
    name     = "enablegraphicvadjust",
    onlyonce = true,
    actions  = function()
        enableaction("finalizers","nodes.handlers.graphicvadjust")
    end
}
