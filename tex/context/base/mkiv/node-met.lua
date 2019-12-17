if not modules then modules = { } end modules ['node-nut'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is an experimental module. Don't use nuts for generic code, at least not till
-- the regular code is proven stable. No support otherwise.

-- luatex: todo: copylist should return h, t
-- todo: see if using insert_before and insert_after makes sense here

-- This file is a side effect of the \LUATEX\ speed optimization project of Luigi
-- Scarso and me. As \CONTEXT\ spends over half its time in \LUA, we though that
-- using \LUAJIT\ could improve performance. We've published some of our experiences
-- elsewhere, but to summarize: \LUAJITTEX\ benefits a lot from the faster virtual
-- machine, but when jit is turned of we loose some again. We experimented with
-- ffi (without messing up the \CONTEXT\ code too much) but there we also lost more
-- than we gained (mostly due to lack of compatible userdata support: it's all or
-- nothing). This made us decide to look into the \LUA||\TEX\ interfacing and by
-- profiling and careful looking at the (of course then still beta source code) we
-- could come up with some improvements. The first showed up in 0.75 and we've more
-- on the agenda for 0.80. Although some interfaces could be sped up significantly
-- in practice we're only talking of 5||10\% on a \CONTEXT\ run and maybe more when
-- complex and extensive node list manipulations happens (we're talking of hundreds
-- of millions cross boundary calls then for documents of hundreds pages). One of the
-- changes in the \CONTEXT\ code base is that we went from indexed access to nodes to
-- function calls (in principle faster weren't it that the accessors need to do more
-- checking which makes them slower) and from there to optimizing these calls as well
-- as providing fast variants for well defined situations. At first optimizations were
-- put in a separate \type {node.fast} table although some improvements could be
-- ported to the main node functions. Because we got the feeling that more gain was
-- possible (especially when using more complex fonts and \MKIV\ functionality) we
-- eventually abandoned this approach and dropped the \type {fast} table in favour of
-- another hack. In the process we had done lots of profiling and testing so we knew
-- where time was wasted,
--
-- As lots of testing and experimenting was part of this project, I could not have
-- done without stacks of new \CD s and \DVD s. This time Porcupine Tree, No-Man
-- and Archive were came to rescue.
--
-- It all started with testing performance of:
--
-- node.getfield = metatable.__index
-- node.setfield = metatable.__newindex

local type, select = type, select
local setmetatableindex = table.setmetatableindex

-- First we get the metatable of a node:

local metatable = nil

do
    local glyph = node.new("glyph",0)
    metatable = getmetatable(glyph)
    node.free(glyph)
end

-- statistics.tracefunction(node,       "node",       "getfield","setfield")
-- statistics.tracefunction(node.direct,"node.direct","getfield","setfield")

-- We start with some helpers and provide all relevant basic functions in the
-- node namespace as well.

nodes                       = nodes or { }
local nodes                 = nodes

local nodecodes               = nodes.nodecodes

nodes.tostring                = node.tostring or tostring
nodes.copy                    = node.copy
nodes.copy_node               = node.copy
nodes.copy_list               = node.copy_list
nodes.delete                  = node.delete
nodes.dimensions              = node.dimensions
nodes.rangedimensions         = node.rangedimensions
nodes.end_of_math             = node.end_of_math
nodes.flush                   = node.flush_node
nodes.flush_node              = node.flush_node
nodes.flush_list              = node.flush_list
nodes.free                    = node.free
nodes.insert_after            = node.insert_after
nodes.insert_before           = node.insert_before
nodes.hpack                   = node.hpack
nodes.new                     = node.new
nodes.tail                    = node.tail
nodes.traverse                = node.traverse
nodes.traverse_id             = node.traverse_id
nodes.traverse_char           = node.traverse_char
nodes.traverse_glyph          = node.traverse_glyph
nodes.traverse_list           = node.traverse_list
nodes.slide                   = node.slide
nodes.vpack                   = node.vpack
nodes.fields                  = node.fields
nodes.is_node                 = node.is_node
nodes.setglue                 = node.setglue
nodes.uses_font               = node.uses_font

nodes.first_glyph             = node.first_glyph
nodes.has_glyph               = node.has_glyph or node.first_glyph

nodes.current_attr            = node.current_attr
nodes.has_field               = node.has_field
nodes.last_node               = node.last_node
nodes.usedlist                = node.usedlist
nodes.protrusion_skippable    = node.protrusion_skippable
nodes.check_discretionaries   = node.check_discretionaries
nodes.write                   = node.write
nodes.flatten_discretionaries = node.flatten_discretionaries

nodes.count                   = node.count
nodes.length                  = node.length

nodes.has_attribute           = node.has_attribute
nodes.set_attribute           = node.set_attribute
nodes.find_attribute          = node.find_attribute
nodes.unset_attribute         = node.unset_attribute

nodes.protect_glyph           = node.protect_glyph
nodes.protect_glyphs          = node.protect_glyphs
nodes.unprotect_glyph         = node.unprotect_glyph
nodes.unprotect_glyphs        = node.unprotect_glyphs
nodes.kerning                 = node.kerning
nodes.ligaturing              = node.ligaturing
nodes.hyphenating             = node.hyphenating
nodes.mlist_to_hlist          = node.mlist_to_hlist

nodes.effective_glue          = node.effective_glue
nodes.getglue                 = node.getglue
nodes.setglue                 = node.setglue
nodes.is_zero_glue            = node.is_zero_glue

nodes.tonode = function(n) return n end
nodes.tonut  = function(n) return n end

-- These are never used in \CONTEXT, only as a gimmick in node operators
-- so we keep them around.

local n_getfield = node.getfield
local n_getattr  = node.get_attribute

local n_setfield = node.setfield
local n_setattr  = n_setfield

nodes.getfield = n_getfield
nodes.setfield = n_setfield
nodes.getattr  = n_getattr
nodes.setattr  = n_setattr
nodes.takeattr = nodes.unset_attribute

local function n_getid     (n) return n_getfield(n,"id")      end
local function n_getsubtype(n) return n_getfield(n,"subtype") end

nodes.getid      = n_getid
nodes.getsubtype = n_getsubtype

local function n_getchar(n)   return n_getfield(n,"char")    end
local function n_setchar(n,c) return n_setfield(n,"char",c)  end
local function n_getfont(n)   return n_getfield(n,"font")    end
local function n_setfont(n,f) return n_setfield(n,"font",f)  end

nodes.getchar = n_getchar
nodes.setchar = n_setchar
nodes.getfont = n_getfont
nodes.setfont = n_setfont

local function n_getlist  (n)   return n_getfield(n,"list")     end
local function n_setlist  (n,l) return n_setfield(n,"list",l)   end
local function n_getleader(n)   return n_getfield(n,"leader")   end
local function n_setleader(n,l) return n_setfield(n,"leader",l) end

nodes.getlist   = n_getlist
nodes.setlist   = n_setlist
nodes.getleader = n_getleader
nodes.setleader = n_setleader

local function n_getnext(n)       return n_getfield(n,"next")    end
local function n_setnext(n,nn)    return n_setfield(n,"next",nn) end
local function n_getprev(n)       return n_getfield(n,"prev")    end
local function n_setprev(n,pp)    return n_setfield(n,"prev",pp) end
local function n_getboth(n)       return n_getfield(n,"prev"),    n_getfield(n,"next")    end
local function n_setboth(n,pp,nn) return n_setfield(n,"prev",pp), n_setfield(n,"next",nn) end

nodes.getnext = n_getnext
nodes.setnext = n_setnext
nodes.getprev = n_getprev
nodes.setprev = n_setprev
nodes.getboth = n_getboth
nodes.setboth = n_setboth

local function n_setlink(...)
    -- not that fast but not used often anyway
    local h = nil
    for i=1,select("#",...) do
        local n = select(i,...)
        if not n then
            -- go on
        elseif h then
            n_setfield(h,"next",n)
            n_setfield(n,"prev",h)
        else
            h = n
        end
    end
    return h
end

nodes.setlink = n_setlink

nodes.getbox  = node.getbox or tex.getbox
nodes.setbox  = node.setbox or tex.setbox

local n_flush_node    = nodes.flush
local n_copy_node     = nodes.copy
local n_copy_list     = nodes.copy_list
local n_find_tail     = nodes.tail
local n_insert_after  = nodes.insert_after
local n_insert_before = nodes.insert_before
local n_slide         = nodes.slide

local n_remove_node   = node.remove -- not yet nodes.remove

local function remove(head,current,free_too)
    local t = current
    head, current = n_remove_node(head,current)
    if not t then
        -- forget about it
    elseif free_too then
        n_flush_node(t)
        t = nil
    else
        n_setboth(t)
    end
    return head, current, t
end

nodes.remove = remove

function nodes.delete(head,current)
    return remove(head,current,true)
end

-- local h, c = nodes.replace(head,current,new)
-- local c = nodes.replace(false,current,new)
-- local c = nodes.replace(current,new)
--
-- todo: check for new.next and find tail

function nodes.replace(head,current,new) -- no head returned if false
    if not new then
        head, current, new = false, head, current
--         current, new = head, current
    end
    local prev = n_getprev(current)
    local next = n_getnext(current)
    if next then
        n_setlink(new,next)
    end
    if prev then
        n_setlink(prev,new)
    end
    if head then
        if head == current then
            head = new
        end
        n_flush_node(current)
        return head, new
    else
        n_flush_node(current)
        return new
    end
end

-- nodes.countall : see node-nut.lua

function nodes.append(head,current,...)
    for i=1,select("#",...) do
        head, current = n_insert_after(head,current,(select(i,...)))
    end
    return head, current
end

function nodes.prepend(head,current,...)
    for i=1,select("#",...) do
        head, current = n_insert_before(head,current,(select(i,...)))
    end
    return head, current
end

function nodes.linked(...)
    local head, last
    for i=1,select("#",...) do
        local next = select(i,...)
        if next then
            if head then
                n_setlink(last,next)
            else
                head = next
            end
            last = n_find_tail(next) -- we could skip the last one
        end
    end
    return head
end

function nodes.concat(list) -- consider tail instead of slide
    local head, tail
    for i=1,#list do
        local li = list[i]
        if li then
            if head then
                n_setlink(tail,li)
            else
                head = li
            end
            tail = n_slide(li)
        end
    end
    return head, tail
end

function nodes.reference(n)
    return n and tonut(n) or "<none>"
end

-- Here starts an experiment with metatables. Of course this only works with nodes
-- wrapped in userdata with a metatable.
--
-- Nodes are kind of special in the sense that you need to keep an eye on creation
-- and destruction. This is quite natural if you consider that changing the content
-- of a node would also change any copy (or alias). As there are too many pitfalls
-- we don't have this kind of support built in \LUATEX, which means that macro
-- packages are free to provide their own. One can even use local variants.
--
-- n1 .. n2 : append nodes, no copies
-- n1 * 5   : append 4 copies of nodes
-- 5 + n1   : strip first 5 nodes
-- n1 - 5   : strip last 5 nodes
-- n1 + n2  : inject n2 after first of n1
-- n1 - n2  : inject n2 before last of n1
-- n1^2     : two copies of nodes (keep orginal)
-- - n1     : reverse nodes
-- n1/f     : apply function to nodes

-- local s = nodes.typesetters.tonodes
--
-- local function w(lst)
--     context.dontleavehmode()
--     context(lst)
--     context.par()
-- end
--
-- local n1 = s("a")
-- local n2 = s("b")
-- local n3 = s("c")
-- local n4 = s("d")
-- local n5 = s("e")
-- local n6 = s("f")
-- local n7 = s("g")
--
-- local n0 = n1 .. (n2 * 10).. n3 .. (5 * n4) .. n5 .. ( 5 * n6 ) .. n7 / function(n) n.char = string.byte("!") return n end
--
-- w(#n0)
--
-- w(n0)
--
-- local n1 = s("a") * 10
-- local n2 = s("b") * 10
--
-- local n0 = ((5 + n1) .. (n2 - 5) )
-- local n0 = - n0
--
-- local n0 = nil .. n0^3 .. nil
--
-- w(n0)
--
-- w ( s("a") + s("b") ) w ( s("a") + 4*s("b") ) w ( 4*s("a") + s("b") ) w ( 4*s("a") + 4*s("b") )
-- w ( s("a") - s("b") ) w ( s("a") - 4*s("b") ) w ( 4*s("a") - s("b") ) w ( 4*s("a") - 4*s("b") )

local n_remove_node = nodes.remove

metatable.__concat = function(n1,n2) -- todo: accept nut on one end
    if not n1 then
        return n2
    elseif not n2 then
        return n1
    elseif n1 == n2 then
        -- or abort
        return n2 -- or n2 * 2
    else
        local tail = n_find_tail(n1)
        n_setlink(tail,n2)
        return n1
    end
end

metatable.__mul = function(n,multiplier)
    if type(multiplier) ~= "number" then
        n, multiplier = multiplier, n
    end
    if multiplier <= 1 then
        return n
    elseif n_getnext(n) then
        local head
        for i=2,multiplier do
            local h = n_copy_list(n)
            if head then
                local t = n_find_tail(h)
                n_setlink(t,head)
            end
            head = h
        end
        local t = n_find_tail(n)
        n_setlink(t,head)
    else
        local head
        for i=2,multiplier do
            local c = n_copy_node(n)
            if head then
                n_setlink(c,head)
            end
            head = c
        end
        n_setlink(n,head)
    end
    return n
end

metatable.__sub = function(first,second)
    if type(second) == "number" then
        local tail = n_find_tail(first)
        for i=1,second do
            local prev = n_getprev(tail)
            n_flush_node(tail) -- can become flushlist/flushnode
            if prev then
                tail = prev
            else
                return nil
            end
        end
        if tail then
            n_setnext(tail)
            return first
        else
            return nil
        end
    else
       -- aaaaa - bbb => aaaabbba
        local firsttail = n_find_tail(first)
        local prev = n_getprev(firsttail)
        if prev then
            local secondtail = n_find_tail(second)
            n_setlink(secondtail,firsttail)
            n_setlink(prev,second)
            return first
        else
            local secondtail = n_find_tail(second)
            n_setlink(secondtail,first)
            return second
        end
    end
end

metatable.__add = function(first,second)
    if type(first) == "number" then
        local head = second
        for i=1,first do
            local second = n_getnext(head)
            n_flush_node(head) -- can become flushlist/flushnode
            if second then
                head = second
            else
                return nil
            end
        end
        if head then
            n_setprev(head)
            return head
        else
            return nil
        end
    else
       -- aaaaa + bbb => abbbaaaa
        local next = n_getnext(first)
        if next then
            local secondtail = n_find_tail(second)
            n_setlink(first,second)
            n_setlink(secondtail,next)
        else
            n_setlink(first,second)
        end
        return first
    end
end

metatable.__len = function(current)
    local length = 0
    while current do
        current = n_getnext(current)
        length = length + 1
    end
    return length
end

metatable.__div = function(list,action)
    return action(list) or list -- always a value
end

metatable.__pow = function(n,multiplier)
    local tail = n
    local head = nil
    if n_getnext(n) then
        if multiplier == 1 then
            head = n_copy_list(n)
        else
            for i=1,multiplier do
                local h = n_copy_list(n)
                if head then
                    local t = n_find_tail(h)
                    n_setlink(t,head)
                end
                head = h
            end
        end
    else
        if multiplier == 1 then
            head = n_copy_node(n)
        else
            for i=2,multiplier do
                local c = n_copy_node(n)
                if head then
                    n_setlink(head,c)
                end
                head = c
            end
        end
    end
    -- todo: tracing
    return head
end

metatable.__unm = function(head)
    local last = head
    local first = head
    local current = n_getnext(head)
    while current do
        local next = n_getnext(current)
        n_setlink(current,first)
        first = current
        current = next
    end
    n_setprev(first)
    n_setnext(last)
    return first
end

-- see node-nut.lua for more info on going nuts

-- if not gonuts then
--
--     local nuts = { }
--     nodes.nuts = nuts
--
--     local function dummy(f) return f end
--
--     nodes.vianuts  = dummy
--     nodes.vianodes = dummy
--
--     for k, v in next, nodes do
--         if type(v) == "function" then
--             nuts[k] = v
--         end
--     end
--
-- end

-- also handy

local tonode       = nodes.tonode
local whatsit_code = nodecodes.whatsit
local getfields    = node.fields
local sort         = table.sort
local whatsitkeys  = { }
local keys         = { whatsit = whatsitkeys }
local messyhack    = table.tohash { -- temporary solution
    nodecodes.attributelist,
    nodecodes.attribute,
    nodecodes.action, -- hm
}

setmetatableindex(keys,function(t,k)
    local v = (k == "attributelist" or k == nodecodes.attributelist) and { } or getfields(k)
    if messyhack[k] then
        for i=1,#v do
            if v[i] == "subtype" then
                remove(v,i)
                break
            end
        end
    end
    if v[ 0] then v[#v+1] = "next" v[ 0] = nil end
    if v[-1] then v[#v+1] = "prev" v[-1] = nil end
    sort(v)
    t[k] = v
    return v
end)

setmetatableindex(whatsitkeys,function(t,k)
    local v = getfields(whatsit_code,k)
    if v[ 0] then v[#v+1] = "next" v[ 0] = nil end
    if v[-1] then v[#v+1] = "prev" v[-1] = nil end
    sort(v)
    t[k] = v
    return v
end)

local function nodefields(n)
    n = tonode(n)
    local id = n.id
    if id == whatsit_code then
        return whatsitkeys[n.subtype]
    else
        return keys[id]
    end
end

nodes.keys   = keys       -- [id][subtype]
nodes.fields = nodefields -- (n)

if not nodes.count then

    local type = type

    local direct   = node.direct
    local todirect = direct.tovaliddirect
    local tonode   = direct.tonode

    local count  = direct.count
    local length = direct.length
    local slide  = direct.slide

    function node.count(id,first,last)
        return count(id,first and todirect(first), last and todirect(last) or nil)
    end

    function node.length(first,last)
        return length(first and todirect(first), last and todirect(last) or nil)
    end

    function node.slide(n)
        if n then
            n = slide(todirect(n))
            if n then
                return tonode(n)
            end
        end
        return nil
    end

    local hyphenating = direct.hyphenating
    local ligaturing  = direct.ligaturing
    local kerning     = direct.kerning

    -- kind of inconsistent

    function node.hyphenating(first,last)
        if first then
            local h, t = hyphenating(todirect(first), last and todirect(last) or nil)
            return h and tonode(h) or nil, t and tonode(t) or nil, true
        else
            return nil, false
        end
    end

    function node.ligaturing(first,last)
        if first then
            local h, t = ligaturing(todirect(first), last and todirect(last) or nil)
            return h and tonode(h) or nil, t and tonode(t) or nil, true
        else
            return nil, false
        end
    end

    function node.kerning(first,last)
        if first then
            local h, t = kerning(todirect(first), last and todirect(last) or nil)
            return h and tonode(h) or nil, t and tonode(t) or nil, true
        else
            return nil, false
        end
     end

    local protect_glyph    = direct.protect_glyph
    local unprotect_glyph  = direct.unprotect_glyph
    local protect_glyphs   = direct.protect_glyphs
    local unprotect_glyphs = direct.unprotect_glyphs

    function node.protect_glyphs(first,last)
        protect_glyphs(todirect(first), last and todirect(last) or nil)
    end

    function node.unprotect_glyphs(first,last)
        unprotect_glyphs(todirect(first), last and todirect(last) or nil)
    end

    function node.protect_glyph(first)
        protect_glyph(todirect(first))
    end

    function node.unprotect_glyph(first)
        unprotect_glyph(todirect(first))
    end

    local flatten_discretionaries = direct.flatten_discretionaries
    local check_discretionaries   = direct.check_discretionaries
    local check_discretionary     = direct.check_discretionary

    function node.flatten_discretionaries(first)
        local h, count = flatten_discretionaries(todirect(first))
        return tonode(h), count
    end

    function node.check_discretionaries(n)
        check_discretionaries(todirect(n))
    end

    function node.check_discretionary(n)
        check_discretionary(todirect(n))
    end

    local hpack         = direct.hpack
    local vpack         = direct.vpack
    local list_to_hlist = direct.mlist_to_hlist

    function node.hpack(head,...)
        local h, badness = hpack(head and todirect(head) or nil,...)
        return tonode(h), badness
    end

    function node.vpack(head,...)
        local h, badness = vpack(head and todirect(head) or nil,...)
        return tonode(h), badness
    end

    function node.mlist_to_hlist(head,...)
        return tonode(mlist_to_hlist(head and todirect(head) or nil,...))
    end

    local end_of_math    = direct.end_of_math
    local find_attribute = direct.find_attribute
    local first_glyph    = direct.first_glyph

    function node.end_of_math(n)
        if n then
            n = end_of_math(todirect(n))
            if n then
                return tonode(n)
            end
        end
        return nil
    end

    function node.find_attribute(n,a)
        if n then
            local v, n = find_attribute(todirect(n),a)
            if n then
                return v, tonode(n)
            end
        end
        return nil
    end

    function node.first_glyph(first,last)
        local n = first_glyph(todirect(first), last and todirect(last) or nil)
        return n and tonode(n) or nil
    end

    local dimensions      = direct.dimensions
    local rangedimensions = direct.rangedimensions
    local effective_glue  = direct.effective_glue

    function node.dimensions(a,b,c,d,e)
        if type(a) == "userdata" then
            a = todirect(a)
            if type(b) == "userdata" then
                b = todirect(b)
            end
            return dimensions(a,b)
        else
            d = todirect(d)
            if type(e) == "userdata" then
                e = todirect(e)
            end
            return dimensions(a,b,c,d,e)
        end
        return 0, 0, 0
    end

    function node.rangedimensions(parent,first,last)
        return rangedimenensions(todirect(parent),todirect(first),last and todirect(last))
    end

    function node.effective_glue(list,parent)
        return effective_glue(list and todirect(list) or nil,parent and todirect(parent) or nil)
    end

    local uses_font            = direct.uses_font
    local has_glyph            = direct.has_glyph
    local protrusion_skippable = direct.protrusion_skippable
    local prepend_prevdepth    = direct.prepend_prevdepth
    local make_extensible      = direct.make_extensible

    function node.uses_font(n,f)
        return uses_font(todirect(n),f)
    end

    function node.has_glyph(n)
        return has_glyph(todirect(n))
    end

    function node.protrusion_skippable(n)
        return protrusion_skippable(todirect(n))
    end

    function node.prepend_prevdepth(n)
        local n, d = prepend_prevdepth(todirect(n))
        return tonode(n), d
    end

    function node.make_extensible(...)
        local n = make_extensible(...)
        return n and tonode(n) or nil
    end

    local last_node = direct.last_node

    function node.last_node()
        local n = last_node()
        return n and tonode(n) or nil
    end

    local is_zero_glue = direct.is_zero_glue
    local getglue      = direct.getglue
    local setglue      = direct.setglue

    function node.is_zero_glue(n)
        return is_zero_glue(todirect(n))
    end

    function node.get_glue(n)
        return get_glue(todirect(n))
    end

    function node.set_glue(n)
        return set_glue(todirect(n))
    end

end
