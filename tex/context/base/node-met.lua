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

local gonuts               = type(node.direct) == "table"
-- local gonuts            = false

nodes                      = nodes or { }
local nodes                = nodes

nodes.gonuts               = gonuts

local nodecodes            = nodes.nodecodes
local hlist_code           = nodecodes.hlist
local vlist_code           = nodecodes.vlist

nodes.tostring             = node.tostring or tostring
nodes.copy                 = node.copy
nodes.copy_list            = node.copy_list
nodes.delete               = node.delete
nodes.dimensions           = node.dimensions
nodes.end_of_math          = node.end_of_math
nodes.flush_list           = node.flush_list
nodes.flush_node           = node.flush_node
nodes.free                 = node.free
nodes.insert_after         = node.insert_after
nodes.insert_before        = node.insert_before
nodes.hpack                = node.hpack
nodes.new                  = node.new
nodes.tail                 = node.tail
nodes.traverse             = node.traverse
nodes.traverse_id          = node.traverse_id
nodes.slide                = node.slide
nodes.vpack                = node.vpack
nodes.fields               = node.fields
nodes.is_node              = node.is_node

nodes.first_glyph          = node.first_glyph
nodes.first_character      = node.first_character
nodes.has_glyph            = node.has_glyph or node.first_glyph

nodes.current_attr         = node.current_attr
nodes.do_ligature_n        = node.do_ligature_n
nodes.has_field            = node.has_field
nodes.last_node            = node.last_node
nodes.usedlist             = node.usedlist
nodes.protrusion_skippable = node.protrusion_skippable
nodes.write                = node.write

nodes.has_attribute        = node.has_attribute
nodes.set_attribute        = node.set_attribute
nodes.unset_attribute      = node.unset_attribute

nodes.protect_glyphs       = node.protect_glyphs
nodes.unprotect_glyphs     = node.unprotect_glyphs
nodes.kerning              = node.kerning
nodes.ligaturing           = node.ligaturing
nodes.mlist_to_hlist       = node.mlist_to_hlist

if not gonuts or not node.getfield then
    node.getfield = metatable.__index
    node.setfield = metatable.__newindex
end

-- if gonuts then
    nodes.tonode = function(n) return n end
    nodes.tonut  = function(n) return n end
-- end

local getfield          = node.getfield
local setfield          = node.setfield

local getattr           = getfield
local setattr           = setfield

local getnext           = node.getnext    or function(n) return getfield(n,"next")    end
local getprev           = node.getprev    or function(n) return getfield(n,"prev")    end
local getid             = node.getid      or function(n) return getfield(n,"id")      end
local getchar           = node.getchar    or function(n) return getfield(n,"char")    end
local getfont           = node.getfont    or function(n) return getfield(n,"font")    end
local getsubtype        = node.getsubtype or function(n) return getfield(n,"subtype") end
local getlist           = node.getlist    or function(n) return getfield(n,"list")    end
local getleader         = node.getleader  or function(n) return getfield(n,"leader")  end

nodes.getfield          = getfield
nodes.getattr           = getattr

nodes.setfield          = setfield
nodes.setattr           = setattr

nodes.getnext           = getnext
nodes.getprev           = getprev
nodes.getid             = getid
nodes.getchar           = getchar
nodes.getfont           = getfont
nodes.getsubtype        = getsubtype
nodes.getlist           = getlist
nodes.getleader         = getleader

nodes.getbox            = node.getbox  or tex.getbox
nodes.setbox            = node.setbox  or tex.setbox
nodes.getskip           = node.getskip or tex.get

local n_new_node        = nodes.new
local n_free_node       = nodes.free
local n_setfield        = nodes.setfield
local n_getfield        = nodes.getfield
local n_getnext         = nodes.getnext
local n_getprev         = nodes.getprev
local n_getid           = nodes.getid
local n_getlist         = nodes.getlist
local n_copy_node       = nodes.copy
local n_copy_list       = nodes.copy_list
local n_find_tail       = nodes.tail
local n_insert_after    = nodes.insert_after
local n_insert_before   = nodes.insert_before
local n_slide           = nodes.slide

local n_remove_node     = node.remove -- not yet nodes.remove

-- if t.id == glue_code then
--     local s = t.spec
--     if s and s.writable then
--         free_node(s)
--     end
--     t.spec = nil
-- end

local function remove(head,current,free_too)
    local t = current
    head, current = n_remove_node(head,current)
    if not t then
        -- forget about it
    elseif free_too then
        n_free_node(t)
        t = nil
    else
        n_setfield(t,"next",nil)
        n_setfield(t,"prev",nil)
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
        n_setfield(new,"next",next)
        n_setfield(next,"prev",new)
    end
    if prev then
        n_setfield(new,"prev",prev)
        n_setfield(prev,"next",new)
    end
    if head then
        if head == current then
            head = new
        end
        n_free_node(current)
        return head, new
    else
        n_free_node(current)
        return new
    end
end

local function count(stack,flat)
    local n = 0
    while stack do
        local id = n_getid(stack)
        if not flat and id == hlist_code or id == vlist_code then
            local list = n_getlist(stack)
            if list then
                n = n + 1 + count(list) -- self counts too
            else
                n = n + 1
            end
        else
            n = n + 1
        end
        stack = n_getnext(stack)
    end
    return n
end

nodes.count = count

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
                n_setfield(last,"next",next)
                n_setfield(next,"prev",last)
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
                n_setfield(tail,"next",li)
                n_setfield(li,"prev",tail)
            else
                head = li
            end
            tail = n_slide(li)
        end
    end
    return head, tail
end

--[[
<p>At some point we ran into a problem that the glue specification
of the zeropoint dimension was overwritten when adapting a glue spec
node. This is a side effect of glue specs being shared. After a
couple of hours tracing and debugging Taco and I came to the
conclusion that it made no sense to complicate the spec allocator
and settled on a writable flag. This all is a side effect of the
fact that some glues use reserved memory slots (with the zeropoint
glue being a noticeable one). So, next we wrap this into a function
and hide it for the user. And yes, LuaTeX now gives a warning as
well.</p>
]]--

function nodes.writable_spec(n) -- not pool
    local spec = n_getfield(n,"spec")
    if not spec then
        spec = n_copy_node(glue_spec)
        n_setfield(n,"spec",spec)
    elseif not n_getfield(spec,"writable") then
        spec = n_copy_node(spec)
        n_setfield(n,"spec",spec)
    end
    return spec
end

function nodes.copy_spec(old,free) -- also frees
    if not old then
        return n_new_node("glue_spec")
    else
        local new = n_copy_node(old)
        if free and old.writable then
            free_node(old)
        end
        return new
    end
end

function nodes.free_spec(old)
    if not old then
        -- skip
    elseif old.writable then
        free_node(old)
    else
        -- skip
    end
end

if gonuts then

    function nodes.reference(n)
        return n and tonut(n) or "<none>"
    end

else

    local left, space = lpeg.P("<"), lpeg.P(" ")

    local reference = left * (1-left)^0 * left * space^0 * lpeg.C((1-space)^0)

    function nodes.reference(n)
        return n and lpegmatch(reference,tostring(n)) or "<none>"
    end

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
        n_setfield(tail,"next",n2)
        n_setfield(n2,"prev",tail)
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
                n_setfield(t,"next",head)
                n_setfield(head,"prev",t)
            end
            head = h
        end
        local t = n_find_tail(n)
        n_setfield(t,"next",head)
        n_setfield(head,"prev",t)
    else
        local head
        for i=2,multiplier do
            local c = n_copy_node(n)
            if head then
                n_setfield(c,"next",head)
                n_setfield(head,"prev",c)
            end
            head = c
        end
        n_setfield(n,"next",head)
        n_setfield(head,"prev",n)
    end
    return n
end

metatable.__sub = function(first,second)
    if type(second) == "number" then
        local tail = n_find_tail(first)
        for i=1,second do
            local prev = n_getfield(tail,"prev")
            n_free_node(tail) -- can become flushlist/flushnode
            if prev then
                tail = prev
            else
                return nil
            end
        end
        if tail then
            n_setfield(tail,"next",nil)
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
            n_setfield(secondtail,"next",firsttail)
            n_setfield(firsttail,"prev",ltail)
            n_setfield(prev,"next",second)
            n_setfield(second,"prev",prev)
            return first
        else
            local secondtail = n_find_tail(second)
            n_setfield(secondtail,"next",first)
            n_setfield(first,"prev",ltail)
            return second
        end
    end
end

metatable.__add = function(first,second)
    if type(first) == "number" then
        local head = second
        for i=1,first do
            local second = n_getnext(head)
            n_free_node(head) -- can become flushlist/flushnode
            if second then
                head = second
            else
                return nil
            end
        end
        if head then
            n_setfield(head,"prev",nil)
            return head
        else
            return nil
        end
    else
       -- aaaaa + bbb => abbbaaaa
        local next = n_getnext(first)
        if next then
            local secondtail = n_find_tail(second)
            n_setfield(first,"next",second)
            n_setfield(second,"prev",first)
            n_setfield(secondtail,"next",next)
            n_setfield(next,"prev",secondtail)
        else
            n_setfield(first,"next",second)
            n_setfield(second,"prev",first)
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
    if getnext(n) then
        if multiplier == 1 then
            head = n_copy_list(n)
        else
            for i=1,multiplier do
                local h = n_copy_list(n)
                if head then
                    local t = n_find_tail(h)
                    n_setfield(t,"next",head)
                    n_setfield(head,"prev",t)
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
                    n_setfield(head,"next",c)
                    n_setfield(c,"prev",head)
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
        n_setfield(first,"prev",current)
        n_setfield(current,"next",first)
        first = current
        current = next
    end
    n_setfield(first,"prev",nil)
    n_setfield(last,"next",nil)
    return first
end

-- see node-nut.lua for more info on going nuts

if not gonuts then

    local nuts = { }
    nodes.nuts = nuts

    local function dummy(f) return f end

    nodes.vianuts  = dummy
    nodes.vianodes = dummy

    for k, v in next, nodes do
        if type(v) == "function" then
            nuts[k] = v
        end
    end

end

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
    nodecodes.gluespec,
    nodecodes.action,
}

table.setmetatableindex(keys,function(t,k)
    local v = getfields(k)
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

table.setmetatableindex(whatsitkeys,function(t,k)
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

-- one issue solved in flush_node:
--
-- case glue_spec_node:
--     if (glue_ref_count(p)!=null) {
--         decr(glue_ref_count(p));
--         return ;
--     /*
--     } else if (! valid_node(p)) {
--          return ;
--     */
--     /*
--     } else {
--         free_node(p, get_node_size(type(p), subtype(p)));
--         return ;
--     */
--     }
--     break ;
--
-- or:
--
-- case glue_spec_node:
--     if (glue_ref_count(p)!=null) {
--         decr(glue_ref_count(p));
--         return ;
--     } else if (valid_node(p)) {
--         free_node(p, get_node_size(type(p), subtype(p)));
--         return ;
--     } else {
--         break ;
--     }
