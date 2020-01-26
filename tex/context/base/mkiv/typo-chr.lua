if not modules then modules = { } end modules ['typo-chr'] = {
    version   = 1.001,
    comment   = "companion to typo-bld.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module can be optimized.

-- local nodecodes        = nodes.nodecodes
-- local whatsitcodes     = nodes.whatsitcodes
--
-- local glyph_code       = nodecodes.glyph
-- local whatsit_code     = nodecodes.whatsit
--
-- local userwhatsit_code = whatsitcodes.userdefined
--
-- local stringusernode   = nodes.pool.userstring
--
-- local nuts             = nodes.nuts
-- local pool             = nuts.pool
--
-- local getid            = nuts.getid
-- local getprev          = nuts.getprev
-- local getchar          = nuts.getchar
-- local getdata          = nuts.getdata
-- local getfield         = nuts.getfield
--
-- local remove_node      = nuts.remove
-- local nextwhatsit      = nuts.traversers.whatsit
--
-- local signal           = pool.userids.signal
--
-- local is_punctuation   = characters.is_punctuation
--
-- local actions = {
--     removepunctuation = function(head,n)
--         local prev = getprev(n)
--         if prev then
--             if getid(prev) == glyph_code and is_punctuation[getchar(prev)] then
--                 head = remove_node(head,prev,true)
--             end
--         end
--         return head
--     end
-- }
--
-- -- we can also use properties .. todo (saves pass)
--
-- typesetters.signals = { }
--
-- function typesetters.signals.handler(head)
--     local done = false
--     for n, subtype in nextwhatsit, head do
--         if subtype == userwhatsit_code and getfield(n,"user_id") == signal and getfield(n,"type") == 115 then
--             local action = actions[getdata(n)]
--             if action then
--                 head = action(h,n)
--             end
--             head = remove_node(head,n,true)
--             done = true
--         end
--     end
--     return head, done
-- end
--
-- local enabled = false
--
-- local function signal(what)
--     if not enabled then
--         nodes.tasks.prependaction("processors","normalizers", "typesetters.signals.handler")
--         enabled = true
--     end
--     context(stringusernode(signal,what))
-- end
--
-- interfaces.implement {
--     name      = "signal",
--     actions   = signal,
--     arguments = "string",
-- }

local insert, remove = table.insert, table.remove

local context           = context
local ctx_doifelse      = commands.doifelse

local nodecodes         = nodes.nodecodes
local boundarycodes     = nodes.boundarycodes
local subtypes          = nodes.subtypes

local glyph_code        = nodecodes.glyph
local localpar_code     = nodecodes.localpar
local boundary_code     = nodecodes.boundary

local wordboundary_code = boundarycodes.word

local texgetnest        = tex.getnest -- to be used
local texsetcount       = tex.setcount

local flush_node        = nodes.flush_node
local flush_list        = nodes.flush_list

local settexattribute   = tex.setattribute
local punctuation       = characters.is_punctuation

local variables         = interfaces.variables
local v_all             = variables.all
local v_reset           = variables.reset

local stack             = { }

local a_marked          = attributes.numbers['marked']
local lastmarked        = 0
local marked            = {
    [v_all]   = 1,
    [""]      = 1,
    [v_reset] = attributes.unsetvalue,
}

local function pickup()
    local list = texgetnest()
    if list then
        local tail = list.tail
        if tail and tail.id == glyph_code and punctuation[tail.char] then
            local prev = tail.prev
            list.tail = prev
            if prev then
                prev.next = nil
            end
            list.tail = prev
            tail.prev = nil
            return tail
        end
    end
end

local actions = {
    remove = function(specification)
        local n = pickup()
        if n then
            flush_node(n)
        end
    end,
    push = function(specification)
        local n = pickup()
        if n then
            insert(stack,n or false)
        end
    end,
    pop = function(specification)
        local n = remove(stack)
        if n then
            context(n)
        end
    end,
}

local function pickuppunctuation(specification)
    local action = actions[specification.action or "remove"]
    if action then
        action(specification)
    end
end

-- I played with nested marked content but it makes no sense and gives
-- complex code. Also, it's never needed so why bother.

local function pickup(head,tail,str)
    local attr = marked[str]
    local last = tail
    if last[a_marked] == attr then
        local first = last
        while true do
            local prev = first.prev
            if prev and prev[a_marked] == attr then
                if prev.id == localpar_code then -- and start_of_par(prev)
                    break
                else
                    first = prev
                end
            else
                break
            end
        end
        return first, last
    end
end

local function found(str)
    local list = texgetnest()
    if list then
        local tail = list.tail
        return tail and tail[a_marked] == marked[str]
    end
end

local actions = {
    remove = function(specification)
        local list = texgetnest()
        if list then
            local head = list.head
            local tail = list.tail
            local first, last = pickup(head,tail,specification.mark)
            if first then
                if first == head then
                    list.head = nil
                    list.tail = nil
                else
                    local prev = first.prev
                    list.tail  = prev
                    prev.next  = nil
                end
                flush_list(first)
            end
        end
    end,
}

local function pickupmarkedcontent(specification)
    local action = actions[specification.action or "remove"]
    if action then
        action(specification)
    end
end

local function markcontent(str)
    local currentmarked = marked[str or v_all]
    if not currentmarked then
        lastmarked    = lastmarked + 1
        currentmarked = lastmarked
        marked[str]   = currentmarked
    end
    settexattribute(a_marked,currentmarked)
end

interfaces.implement {
    name      = "pickuppunctuation",
    actions   = pickuppunctuation,
    arguments = {
        {
            { "action" }
        }
    }
}

interfaces.implement {
    name      = "pickupmarkedcontent",
    actions   = pickupmarkedcontent,
    arguments = {
        {
            { "action" },
            { "mark" }
        }
    }
}

interfaces.implement {
    name      = "markcontent",
    actions   = markcontent,
    arguments = "string",
}

interfaces.implement {
    name      = "doifelsemarkedcontent",
    actions   = function(str) ctx_doifelse(found(str)) end,
    arguments = "string",
}

-- We just put these here.

interfaces.implement {
    name    = "lastnodeidstring",
    public  = true,
    actions = function()
        local list = texgetnest() -- "top"
        local okay = false
        if list then
            local tail = list.tail
            if tail then
                okay = nodecodes[tail.id]
            end
        end
        context(okay or "")
    end,
}

-- local t_lastnodeid = token.create("c_syst_last_node_id")
--
-- interfaces.implement {
--     name    = "lastnodeid",
--     public  = true,
--     actions = function()
--         ...
--         tex.setcount("c_syst_last_node_id",okay)
--         context.sprint(t_lastnodeid)
--     end,
-- }

-- not needed in lmtx ...

interfaces.implement {
    name    = "lastnodeid",
    actions = function()
        local list = texgetnest() -- "top"
        local okay = -1
        if list then
            local tail = list.tail
            if tail then
                okay = tail.id
            end
        end
        texsetcount("c_syst_last_node_id",okay)
    end,
}

interfaces.implement {
    name    = "lastnodesubtypestring",
    public  = true,
    actions = function()
        local list = texgetnest() -- "top"
        local okay = false
        if list then
            local tail = list.tail
            if head then
                okay = subtypes[tail.id][tail.subtype]
            end
        end
        context(okay or "")
    end,
}

local function lastnodeequals(id,subtype)
    local list = texgetnest() -- "top"
    local okay = false
    if list then
        local tail = list.tail
        if tail then
            local i = tail.id
            okay = i == id or i == nodecodes[id]
            if subtype then
                local s = tail.subtype
                okay = s == subtype or s == subtypes[i][subtype]
            end
        end
    end
    ctx_doifelse(okay)
end

interfaces.implement {
    name      = "lastnodeequals",
    arguments = "2 strings",
    actions   = lastnodeequals,
}

interfaces.implement {
    name    = "atwordboundary",
    actions = function()
        lastnodeequals(boundary_code,wordboundary_code)
    end,
}

