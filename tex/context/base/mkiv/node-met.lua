    if not modules then modules = { } end modules ['node-MET'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is an experimental module. Don't use nuts for generic code, at least not till
-- the regular code is proven stable. No support otherwise.

-- luatex: todo: copylist should return h, t
-- todo: see if using insertbefore and insertafter makes sense here

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

nodes                        = nodes or { }
local nodes                  = nodes

local nodecodes              = nodes.nodecodes

nodes.tostring               = node.tostring or tostring
nodes.copy                   = node.copy
nodes.copynode               = node.copy
nodes.copylist               = node.copy_list
nodes.delete                 = node.delete
nodes.dimensions             = node.dimensions
nodes.rangedimensions        = node.rangedimensions
nodes.endofmath              = node.end_of_math
nodes.flush                  = node.flush_node
nodes.flushnode              = node.flush_node
nodes.flushlist              = node.flush_list
nodes.free                   = node.free
nodes.insertafter            = node.insert_after
nodes.insertbefore           = node.insert_before
nodes.hpack                  = node.hpack
nodes.new                    = node.new
nodes.tail                   = node.tail
nodes.traverse               = node.traverse
nodes.traverseid             = node.traverse_id
nodes.traversechar           = node.traverse_char
nodes.traverseglyph          = node.traverse_glyph
nodes.traverselist           = node.traverse_list
nodes.slide                  = node.slide
nodes.vpack                  = node.vpack
nodes.fields                 = node.fields
nodes.isnode                 = node.is_node
nodes.isdirect               = node.is_direct
nodes.isnut                  = node.is_direct
nodes.setglue                = node.setglue
nodes.usesfont               = node.uses_font

nodes.firstglyph             = node.first_glyph
nodes.hasglyph               = node.has_glyph

nodes.currentattributes      = node.current_attributes or node.current_attr
nodes.hasfield               = node.has_field
nodes.last_node              = node.last_node
nodes.usedlist               = node.usedlist
nodes.protrusionskippable    = node.protrusion_skippable
nodes.checkdiscretionaries   = node.check_discretionaries
nodes.write                  = node.write
nodes.flattendiscretionaries = node.flatten_discretionaries

nodes.count                  = node.count
nodes.length                 = node.length

nodes.hasattribute           = node.has_attribute
nodes.setattribute           = node.set_attribute
nodes.findattribute          = node.find_attribute
nodes.unsetattribute         = node.unset_attribute

nodes.protectglyph           = node.protect_glyph
nodes.protectglyphs          = node.protect_glyphs
nodes.unprotectglyph         = node.unprotect_glyph
nodes.unprotectglyphs        = node.unprotect_glyphs
nodes.kerning                = node.kerning
nodes.ligaturing             = node.ligaturing
nodes.hyphenating            = node.hyphenating
nodes.mlisttohlist           = node.mlist_to_hlist

nodes.effectiveglue          = node.effective_glue
nodes.getglue                = node.getglue
nodes.setglue                = node.setglue
nodes.iszeroglue             = node.iszeroglue

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
nodes.takeattr = nodes.unsetattribute

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

local n_flushnode    = nodes.flush
local n_copynode     = nodes.copy
local n_copylist     = nodes.copylist
local n_findtail     = nodes.tail
local n_insertafter  = nodes.insertafter
local n_insertbefore = nodes.insertbefore
local n_slide        = nodes.slide

local n_remove_node   = node.remove -- not yet nodes.remove

local function remove(head,current,free_too)
    local t = current
    head, current = n_remove_node(head,current)
    if not t then
        -- forget about it
    elseif free_too then
        n_flushnode(t)
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
        n_flushnode(current)
        return head, new
    else
        n_flushnode(current)
        return new
    end
end

-- nodes.countall : see node-nut.lua

function nodes.append(head,current,...)
    for i=1,select("#",...) do
        head, current = n_insertafter(head,current,(select(i,...)))
    end
    return head, current
end

function nodes.prepend(head,current,...)
    for i=1,select("#",...) do
        head, current = n_insertbefore(head,current,(select(i,...)))
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
            last = n_findtail(next) -- we could skip the last one
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
        local tail = n_findtail(n1)
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
            local h = n_copylist(n)
            if head then
                local t = n_findtail(h)
                n_setlink(t,head)
            end
            head = h
        end
        local t = n_findtail(n)
        n_setlink(t,head)
    else
        local head
        for i=2,multiplier do
            local c = n_copynode(n)
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
        local tail = n_findtail(first)
        for i=1,second do
            local prev = n_getprev(tail)
            n_flushnode(tail) -- can become flushlist/flushnode
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
        local firsttail = n_findtail(first)
        local prev = n_getprev(firsttail)
        if prev then
            local secondtail = n_findtail(second)
            n_setlink(secondtail,firsttail)
            n_setlink(prev,second)
            return first
        else
            local secondtail = n_findtail(second)
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
            n_flushnode(head) -- can become flushlist/flushnode
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
            local secondtail = n_findtail(second)
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
            head = n_copylist(n)
        else
            for i=1,multiplier do
                local h = n_copylist(n)
                if head then
                    local t = n_findtail(h)
                    n_setlink(t,head)
                end
                head = h
            end
        end
    else
        if multiplier == 1 then
            head = n_copynode(n)
        else
            for i=2,multiplier do
                local c = n_copynode(n)
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
