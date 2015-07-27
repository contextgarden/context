if not modules then modules = { } end modules ['luatex-gadgets'] = {
    version   = 1.001,
    comment   = "companion to luatex-gadgets.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if context then return end

-- This module contains some maybe useful gadgets. More might show up here
-- as side effect of tutorials or articles. Don't use this file in ConTeXt
-- because we often have similar mechanisms already.

gadgets = gadgets or { } -- global namespace

-- marking content for optional removal

local marking   = { }
gadgets.marking = marking

local marksignal   = 5001 -- will be set in the tex module
local lastmarked   = 0
local marked       = { }
local local_par    = 6
local whatsit_node = 8

function marking.setsignal(n)
    marksignal = tonumber(n) or marksignal
end

function marking.mark(str)
    local currentmarked = marked[str]
    if not currentmarked then
        lastmarked    = lastmarked + 1
        currentmarked = lastmarked
        marked[str]   = currentmarked
    end
    tex.setattribute(marksignal,currentmarked)
end

function marking.remove(str)
    local attr = marked[str]
    if not attr then
        return
    end
    local list = tex.nest[tex.nest.ptr]
    if list then
        local head = list.head
        local tail = list.tail
        local last = tail
        if last[marksignal] == attr then
            local first = last
            while true do
                local prev = first.prev
                if not prev
                        or prev[marksignal] ~= attr
                        or (prev.id == whatsit_node and prev.subtype == local_par) then
                    break
                else
                    first = prev
                end
            end
            if first == head then
                list.head = nil
                list.tail = nil
            else
                local prev = first.prev
                list.tail  = prev
                prev.next  = nil
            end
            node.flush_list(first)
        end
    end
end
