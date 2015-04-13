if not modules then modules = { } end modules ['typo-chr'] = {
    version   = 1.001,
    comment   = "companion to typo-bld.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- local nodecodes      = nodes.nodecodes
-- local whatsitcodes   = nodes.whatsitcodes
-- local glyph_code     = nodecodes.glyph
-- local whatsit_code   = nodecodes.whatsit
-- local user_code      = whatsitcodes.userdefined
--
-- local stringusernode = nodes.pool.userstring
--
-- local nuts           = nodes.nuts
-- local pool           = nuts.pool
--
-- local tonut          = nuts.tonut
-- local tonode         = nuts.tonode
-- local getid          = nuts.getid
-- local getprev        = nuts.getprev
-- local getsubtype     = nuts.getsubtype
-- local getchar        = nuts.getchar
-- local getfield       = nuts.getfield
--
-- local remove_node    = nuts.remove
-- local traverse_by_id = nuts.traverse_id
--
-- local signal         = pool.userids.signal
--
-- local is_punctuation = characters.is_punctuation
--
-- local actions = {
--     removepunctuation = function(head,n)
--         local prev = getprev(n)
--         if prev then
--             if getid(prev) == glyph_code then
--                 if is_punctuation[getchar(prev)] then
--                     head = remove_node(head,prev,true)
--                 end
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
--     local h = tonut(head)
--     local done = false
--     for n in traverse_by_id(whatsit_code,h) do
--         if getsubtype(n) == user_code and getfield(n,"user_id") == signal and getfield(n,"type") == 115 then
--             local action = actions[getfield(n,"value")]
--             if action then
--                 h = action(h,n)
--             end
--             h = remove_node(h,n,true)
--             done = true
--         end
--     end
--     if done then
--         return tonode(h), true
--     else
--         return head
--     end
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

local nodecodes   = nodes.nodecodes
local glyph_code  = nodecodes.glyph

local texnest     = tex.nest
local free_node   = node.free

local punctuation = characters.is_punctuation

local stack       = { }

local function pickup()
    local list = texnest[texnest.ptr]
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
            free_node(n)
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

interfaces.implement {
    name      = "pickuppunctuation",
    actions   = pickuppunctuation,
    arguments = {
        {
            { "action" }
        }
    }
}

