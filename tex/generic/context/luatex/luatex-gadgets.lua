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

local marking        = { }
gadgets.marking      = marking

local marksignal     = 5001 -- will be set in the tex module
local lastmarked     = 0
local marked         = { }
local local_par_code = 9

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
                if not prev or prev[marksignal] ~= attr or prev.id == local_par_code then
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

-- local imgscan = img.scan
--
-- local valid = {
--     ["png"] = "^" .. string.char(0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A),
--     ["jpg"] = "^" .. string.char(0xFF,0xD8,0xFF),
--     ["jp2"] = "^" .. string.char(0x00,0x00,0x00,0x0C,0x6A,0x50,0x20,0x20,0x0D,0x0A),
--     ["pdf"] = "^" .. ".-%%PDF",
-- }
--
-- function img.scan(t)
--     if t and t.filename then
--         local f = io.open(t.filename,"rb")
--         if f then
--             local d = f:read(4096)
--             for k, v in next,valid do
--                 if string.find(d,v) then
--                     f:close() -- be nice
--                     return imgscan(t)
--                 end
--             end
--             f:close() -- be nice
--         end
--     end
-- end
--
-- print(img.scan({filename = "hacker1b.tif"}))
-- print(img.scan({filename = "cow.pdf"}))
-- print(img.scan({filename = "mill.png"}))
