if not modules then modules = { } end modules ['node-met'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Here starts some more experimental code that Luigi and I use in a next stage of
-- exploring and testing potential speedups in the engines. This code is not meant
-- for users and can change (or be removed) any moment. During the experiments I'll
-- do my best to keep the code as fast as possible by using two codebases. See
-- about-fast.pdf for some more info about impacts. Although key based access has
-- more charm, function based is somewhat faster and has more potential for future
-- speedups.

-- This next iteration is flagged direct because we avoid user data which has a price
-- in allocation and metatable tagging. Although in this stage we pass numbers around
-- future versions might use light user data, so never depend on what direct function
-- return. Using the direct approach had some speed advantages but you loose the key
-- based access. The speed gain is only measurable in cases with lots of access. For
-- instance when typesettign arabic with advanced fonts, we're talking of many millions
-- of function calls and there we can get a 30\% or more speedup. On average complex
-- \CONTEXT\ runs the gain can be 10\% to 15\% percent. Because mixing the two models
-- (here we call then nodes and nuts) is not possible you need to cast either way which
-- has a penalty. Also, error messages in nuts mode are less clear and \LUATEX\ will
-- often simply abort when you make mistakes of mix the models. So, development (at least
-- in \CONTEXT) can be done in node mode and not in nuts mode. Only robust code will
-- be turned nuts afterwards and quite likely not all code. The official \LUATEX\ api
-- to nodes is userdata!
--
-- Listening to 'lunatic soul' at the same time helped wrapping my mind around the mixed
-- usage of both models. Just for the record: the potential of the direct approach only
-- became clear after experimenting for weeks and partly adapting code. It is one of those
-- (sub)projects where you afterwards wonder if it was worth the trouble, but users that
-- rely on lots of complex functionality and font support will probably notice the speedup.
--
--                                luatex                    luajittex
-- -------------    -----    --------------------     ---------------------------------
-- name             pages     old   new       pct      old         new              pct
-- -------------    -----    --------------------     ---------------------------------
-- fonts-mkiv         166     9.3   7.7/7.4  17.2      7.4 (37.5)  5.9/5.7 (55.6)  20.3
-- about               60     3.3   2.7/2.6  20.4      2.5 (39.5)  2.1     (57.0)  23.4
-- arabic-001          61    25.3  15.8      18.2     15.3 (46.7)  6.8     (54.7)  16.0
-- torture-001        300    21.4  11.4      24.2     13.9 (35.0)  6.3     (44.7)  22.2
--
-- so:
--
-- - we run around 20% faster on documents of average complexity and gain more when
--   dealing with scripts like arabic and such
-- - luajittex benefits a bit more so a luajittex job can (in principle) now be much
--   faster
-- - if we reason backwards, and take luajittex as norm we get 1:2:3 on some jobs for
--   luajittex direct:luatex direct:luatex normal i.e. we can be 3 times faster
-- - keep in mind that these are tex/lua runs so the real gain at the lua end is much
--   larger
--
-- Because we can fake direct mode a little bit by using the fast getfield and setfield
-- at the cost of wrapped getid and alike, we still are running quite ok. As we could gain
-- some 5% with fast mode, we can sacrifice some on wrappers when we use a few fast core
-- functions. This means that simulated direct mode runs font-mkiv in 9.1 seconds (we could
-- get down to 8.7 seconds in fast mode) and that we can migrate slowely to direct mode.
--
-- The following measurements are from 2013-07-05 after adapting some 47 files to nuts. Keep
-- in mind that the old binary can fake a fast getfield and setfield but that the other
-- getters are wrapped functions. The more we have, the slower it gets.
--
--                                           fonts   about   arabic
-- old mingw, indexed plus some functions :   8.9     3.2     20.3
-- old mingw, fake functions              :   9.9     3.5     27.4
-- new mingw, node functions              :   9.0     3.1     20.8
-- new mingw, indexed plus some functions :   8.6     3.1     19.6
-- new mingw, direct functions            :   7.5     2.6     14.4
--
-- \starttext \dorecurse{1000}{test\page} \stoptext :
--
-- luatex    560 pps
-- luajittex 600 pps
--
-- \setupbodyfont[pagella]
--
-- \edef\zapf{\cldcontext{context(io.loaddata(resolvers.findfile("zapf.tex")))}}
--
-- \starttext \dorecurse{1000}{\zapf\par} \stoptext
--
-- luatex    3.9 sec / 54 pps
-- luajittex 2.3 sec / 93 pps

local type, rawget = type, rawget

local nodes               = nodes
local gonuts              = nodes.gonuts
local direct              = node.direct

local fastcopy            = table.fastcopy

-- if type(direct) ~= "table" then
--     return
-- elseif gonuts then
--     statistics.register("running in nuts mode", function() return "yes" end)
-- else
--     statistics.register("running in nuts mode", function() return "no" end)
--     return
-- end

local texget              = tex.get

local nodecodes           = nodes.nodecodes
local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist

local nuts                = nodes.nuts or { }
nodes.nuts                = nuts

nodes.is_node             = direct.is_node   or function() return true  end
nodes.is_direct           = direct.is_direct or function() return false end
nodes.is_nut              = nodes.is_direct

-- casters

local tonode              = direct.tonode   or function(n) return n end
local tonut               = direct.todirect or function(n) return n end

nuts.tonode               = tonode
nuts.tonut                = tonut

nodes.tonode              = tonode
nodes.tonut               = tonut

-- getters

nuts.getfield             = direct.getfield
nuts.getnext              = direct.getnext
nuts.getprev              = direct.getprev
nuts.getid                = direct.getid
nuts.getattr              = direct.has_attribute or direct.getfield
nuts.getchar              = direct.getchar
nuts.getfont              = direct.getfont
nuts.getsubtype           = direct.getsubtype
nuts.getlist              = direct.getlist -- only hlist and vlist !
nuts.getleader            = direct.getleader

-- local function track(name)
--     local n = 0
--     local f = nuts[name]
--     function nuts[name](...)
--         n = n + 1
--         if n % 1000 == 0 then
--             print(name,n)
--         end
--         return f(...)
--     end
-- end

-- track("getsubtype")

-- local dgf = direct.getfield  function nuts.getlist(n) return dgf(n,"list") end

-- setters

nuts.setfield             = direct.setfield
nuts.setattr              = direct.set_attribute or setfield

nuts.getbox               = direct.getbox
nuts.setbox               = direct.setbox
nuts.getskip              = direct.getskip or function(s) return tonut(texget(s)) end

-- helpers

nuts.tostring             = direct.tostring
nuts.copy                 = direct.copy
nuts.copy_list            = direct.copy_list
nuts.delete               = direct.delete
nuts.dimensions           = direct.dimensions
nuts.end_of_math          = direct.end_of_math
nuts.flush_list           = direct.flush_list
nuts.flush_node           = direct.flush_node
nuts.free                 = direct.free
nuts.insert_after         = direct.insert_after
nuts.insert_before        = direct.insert_before
nuts.hpack                = direct.hpack
nuts.new                  = direct.new
nuts.tail                 = direct.tail
nuts.traverse             = direct.traverse
nuts.traverse_id          = direct.traverse_id
nuts.slide                = direct.slide
nuts.writable_spec        = direct.writable_spec
nuts.vpack                = direct.vpack
nuts.is_node              = direct.is_node
nuts.is_direct            = direct.is_direct
nuts.is_nut               = direct.is_direct
nuts.first_glyph          = direct.first_glyph
nuts.first_character      = direct.first_character
nuts.has_glyph            = direct.has_glyph or direct.first_glyph

nuts.current_attr         = direct.current_attr
nuts.do_ligature_n        = direct.do_ligature_n
nuts.has_field            = direct.has_field
nuts.last_node            = direct.last_node
nuts.usedlist             = direct.usedlist
nuts.protrusion_skippable = direct.protrusion_skippable
nuts.write                = direct.write

nuts.has_attribute        = direct.has_attribute
nuts.set_attribute        = direct.set_attribute
nuts.unset_attribute      = direct.unset_attribute

nuts.protect_glyphs       = direct.protect_glyphs
nuts.unprotect_glyphs     = direct.unprotect_glyphs

-- placeholders

if not direct.kerning then

    local n_kerning = node.kerning

    function nuts.kerning(head)
        return tonode(n_kerning(tonut(head)))
    end

end

if not direct.ligaturing then

    local n_ligaturing = node.ligaturing

    function nuts.ligaturing(head)
        return tonode(n_ligaturing(tonut(head)))
    end

end

if not direct.mlist_to_hlist then

    local n_mlist_to_hlist = node.mlist_to_hlist

    function nuts.mlist_to_hlist(head)
        return tonode(n_mlist_to_hlist(tonut(head)))
    end

end

--

local d_remove_node     = direct.remove
local d_free_node       = direct.free
local d_getfield        = direct.getfield
local d_setfield        = direct.setfield
local d_getnext         = direct.getnext
local d_getprev         = direct.getprev
local d_getid           = direct.getid
local d_getlist         = direct.getlist
local d_find_tail       = direct.tail
local d_insert_after    = direct.insert_after
local d_insert_before   = direct.insert_before
local d_slide           = direct.slide
local d_copy_node       = direct.copy
local d_traverse        = direct.traverse

local function remove(head,current,free_too)
    local t = current
    head, current = d_remove_node(head,current)
    if not t then
        -- forget about it
    elseif free_too then
        d_free_node(t)
        t = nil
    else
        d_setfield(t,"next",nil) -- not that much needed (slows down unless we check the source on this)
        d_setfield(t,"prev",nil) -- not that much needed (slows down unless we check the source on this)
    end
    return head, current, t
end

-- bad: we can have prev's being glue_spec

-- local function remove(head,current,free_too) -- d_remove_node does a slide which can fail
--     local prev = d_getprev(current)          -- weird
--     local next = d_getnext(current)
--     if next then
--     -- print("!!!!!!!! prev is gluespec",
--     --     nodes.nodecodes[d_getid(current)],
--     --     nodes.nodecodes[d_getid(next)],
--     --     nodes.nodecodes[d_getid(prev)])
--         d_setfield(prev,"next",next)
--         d_setfield(next,"prev",prev)
--     else
--         d_setfield(prev,"next",nil)
--     end
--     if free_too then
--         d_free_node(current)
--         current = nil
--     else
--         d_setfield(current,"next",nil) -- use this fact !
--         d_setfield(current,"prev",nil) -- use this fact !
--     end
--     if head == current then
--         return next, next, current
--     else
--         return head, next, current
--     end
-- end

nuts.remove = remove

function nuts.delete(head,current)
    return remove(head,current,true)
end

function nuts.replace(head,current,new) -- no head returned if false
    if not new then
        head, current, new = false, head, current
    end
    local prev = d_getprev(current)
    local next = d_getnext(current)
    if next then
        d_setfield(new,"next",next)
        d_setfield(next,"prev",new)
    end
    if prev then
        d_setfield(new,"prev",prev)
        d_setfield(prev,"next",new)
    end
    if head then
        if head == current then
            head = new
        end
        d_free_node(current)
        return head, new
    else
        d_free_node(current)
        return new
    end
end

local function count(stack,flat)
    local n = 0
    while stack do
        local id = d_getid(stack)
        if not flat and id == hlist_code or id == vlist_code then
            local list = d_getlist(stack)
            if list then
                n = n + 1 + count(list) -- self counts too
            else
                n = n + 1
            end
        else
            n = n + 1
        end
        stack = d_getnext(stack)
    end
    return n
end

nuts.count = count

function nuts.append(head,current,...)
    for i=1,select("#",...) do
        head, current = d_insert_after(head,current,(select(i,...)))
    end
    return head, current
end

function nuts.prepend(head,current,...)
    for i=1,select("#",...) do
        head, current = d_insert_before(head,current,(select(i,...)))
    end
    return head, current
end

function nuts.linked(...)
    local head, last
    for i=1,select("#",...) do
        local next = select(i,...)
        if next then
            if head then
                d_setfield(last,"next",next)
                d_setfield(next,"prev",last)
            else
                head = next
            end
            last = d_find_tail(next) -- we could skip the last one
        end
    end
    return head
end

function nuts.concat(list) -- consider tail instead of slide
    local head, tail
    for i=1,#list do
        local li = list[i]
        if li then
            if head then
                d_setfield(tail,"next",li)
                d_setfield(li,"prev",tail)
            else
                head = li
            end
            tail = d_slide(li)
        end
    end
    return head, tail
end

function nuts.writable_spec(n) -- not pool
    local spec = d_getfield(n,"spec")
    if not spec then
        spec = d_copy_node(glue_spec)
        d_setfield(n,"spec",spec)
    elseif not d_getfield(spec,"writable") then
        spec = d_copy_node(spec)
        d_setfield(n,"spec",spec)
    end
    return spec
end

function nuts.reference(n)
    return n or "<none>"
end

-- quick and dirty tracing of nuts

-- for k, v in next, nuts do
--     if string.find(k,"box") then
--         nuts[k] = function(...) print(k,...) return v(...) end
--     end
-- end

function nodes.vianuts (f) return function(n,...) return tonode(f(tonut (n),...)) end end
function nodes.vianodes(f) return function(n,...) return tonut (f(tonode(n),...)) end end

nuts.vianuts  = nodes.vianuts
nuts.vianodes = nodes.vianodes

-- for k, v in next, nuts do
--     if type(v) == "function" then
--         if not string.find(k,"^[sg]et") and not string.find(k,"^to") then
--             local f = v
--             nuts[k] = function(...) print("d",k,...) return f(...) end
--         end
--     end
-- end

-- for k, v in next, nodes do
--     if type(v) == "function" then
--         if not string.find(k,"^[sg]et") and not string.find(k,"^to") then
--             local f = v
--             nodes[k] = function(...) print("n",k,...) return f(...) end
--         end
--     end
-- end

-- function nodes.insert_before(h,c,n)
--     if c then
--         if c == h then
--             n_setfield(n,"next",h)
--             n_setfield(n,"prev",nil)
--             n_setfield(h,"prev",n)
--         else
--             local cp = n_getprev(c)
--             n_setfield(n,"next",c)
--             n_setfield(n,"prev",cp)
--             if cp then
--                 n_setfield(cp,"next",n)
--             end
--             n_setfield(c,"prev",n)
--             return h, n
--         end
--     end
--     return n, n
-- end

-- function nodes.insert_after(h,c,n)
--     if c then
--         local cn = n_getnext(c)
--         if cn then
--             n_setfield(n,"next",cn)
--             n_setfield(cn,"prev",n)
--         else
--             n_setfield(n,"next",nil)
--         end
--         n_setfield(c,"next",n)
--         n_setfield(n,"prev",c)
--         return h, n
--     end
--     return n, n
-- end

function nodes.insert_list_after(h,c,n)
    local t = n_tail(n)
    if c then
        local cn = n_getnext(c)
        if cn then
            n_setfield(t,"next",cn)
            n_setfield(cn,"prev",t)
        else
            n_setfield(t,"next",nil)
        end
        n_setfield(c,"next",n)
        n_setfield(n,"prev",c)
        return h, n
    end
    return n, t
end

-- function nuts.insert_before(h,c,n)
--     if c then
--         if c == h then
--             d_setfield(n,"next",h)
--             d_setfield(n,"prev",nil)
--             d_setfield(h,"prev",n)
--         else
--             local cp = d_getprev(c)
--             d_setfield(n,"next",c)
--             d_setfield(n,"prev",cp)
--             if cp then
--                 d_setfield(cp,"next",n)
--             end
--             d_setfield(c,"prev",n)
--             return h, n
--         end
--     end
--     return n, n
-- end

-- function nuts.insert_after(h,c,n)
--     if c then
--         local cn = d_getnext(c)
--         if cn then
--             d_setfield(n,"next",cn)
--             d_setfield(cn,"prev",n)
--         else
--             d_setfield(n,"next",nil)
--         end
--         d_setfield(c,"next",n)
--         d_setfield(n,"prev",c)
--         return h, n
--     end
--     return n, n
-- end

function nuts.insert_list_after(h,c,n)
    local t = d_tail(n)
    if c then
        local cn = d_getnext(c)
        if cn then
            d_setfield(t,"next",cn)
            d_setfield(cn,"prev",t)
        else
            d_setfield(t,"next",nil)
        end
        d_setfield(c,"next",n)
        d_setfield(n,"prev",c)
        return h, n
    end
    return n, t
end

-- test code only

-- collectranges and mix

local report = logs.reporter("sliding")

local function message(detail,head,current,previous)
    report("error: %s, current: %s:%s, previous: %s:%s, list: %s, text: %s",
        detail,
        nodecodes[d_getid(current)],
        current,
        nodecodes[d_getid(previous)],
        previous,
        nodes.idstostring(head),
        nodes.listtoutf(head)
    )
    utilities.debugger.showtraceback(report)
end

local function warn()
    report()
    report("warning: the slide tracer is enabled")
    report()
    warn = false
end

local function tracedslide(head)
    if head then
        if warn then
            warn()
        end
        local next = d_getnext(head)
        if next then
            local prev = head
            for n in d_traverse(next) do
                local p = d_getprev(n)
                if not p then
                    message("unset",head,n,prev)
                 -- break
                elseif p ~= prev then
                    message("wrong",head,n,prev)
                 -- break
                end
                prev = n
            end
        end
        return d_slide(head)
    end
end

local function nestedtracedslide(head,level) -- no sliding !
    if head then
        if warn then
            warn()
        end
        local id = d_getid(head)
        local next = d_getnext(head)
        if next then
            report("%whead:%s",level or 0,nodecodes[id])
            local prev = head
            for n in d_traverse(next) do
                local p = d_getprev(n)
                if not p then
                    message("unset",head,n,prev)
                 -- break
                elseif p ~= prev then
                    message("wrong",head,n,prev)
                 -- break
                end
                prev = n
                local id = d_getid(n)
                if id == hlist_code or id == vlist_code then
                    nestedtracedslide(d_getlist(n),(level or 0) + 1)
                end
            end
        elseif id == hlist_code or id == vlist_code then
            report("%wlist:%s",level or 0,nodecodes[id])
            nestedtracedslide(d_getlist(head),(level or 0) + 1)
        end
     -- return d_slide(head)
    end
end

local function untracedslide(head)
    if head then
        if warn then
            warn()
        end
        local next = d_getnext(head)
        if next then
            local prev = head
            for n in d_traverse(next) do
                local p = d_getprev(n)
                if not p then
                    return "unset", d_getid(n)
                elseif p ~= prev then
                    return "wrong", d_getid(n)
                end
                prev = n
            end
        end
        return d_slide(head)
    end
end

nuts.tracedslide       = tracedslide
nuts.untracedslide     = untracedslide
nuts.nestedtracedslide = nestedtracedslide

-- nuts.slide          = tracedslide

-- this might move

local propertydata = direct.get_properties_table and direct.get_properties_table()

local getattr = nuts.getattr
local setattr = nuts.setattr

if propertydata then

    nodes.properties = {
        data = propertydata,
    }

 -- direct.set_properties_mode(true,false) -- shallow copy ... problem: in fonts we then affect the originals too
    direct.set_properties_mode(true,true)  -- create metatable, slower but needed for font-inj.lua (unless we use an intermediate table)

    -- todo:
    --
    -- function direct.set_properties_mode()
    --     -- we really need the set modes
    -- end

    -- experimental code with respect to copying attributes has been removed
    -- as it doesn't pay of (most attributes are only accessed once anyway)

    nuts.getprop = function(n,k)
        local p = propertydata[n]
        if p then
            return p[k]
        end
    end

    nuts.setprop = function(n,k,v)
        local p = propertydata[n]
        if p then
            p[k] = v
        else
            propertydata[n] = { [k] = v }
        end
    end

    nuts.theprop = function(n)
        local p = propertydata[n]
        if not p then
            p = { }
            propertydata[n] = p
        end
        return p
    end

    nodes.setprop = nodes.setproperty
    nodes.getprop = nodes.getproperty

else

    -- for testing and simple cases

    nuts.getprop  = getattr
    nuts.setprop  = setattr

    nodes.setprop = getattr
    nodes.getprop = setattr

end

function nuts.copy_properties(source,target,what)
    local newprops = propertydata[source]
    if not newprops then
        -- nothing to copy
        return
    end
    if what then
        -- copy one category
        newprops = rawget(source,what)
        if newprops then
            newprops = fastcopy(newprops)
            local p = rawget(propertydata,target)
            if p then
                p[what] = newprops
            else
                propertydata[target] = {
                    [what] = newprops,
                }
            end
        end
    else
        -- copy all properties
        newprops = fastcopy(newprops)
        propertydata[target] = newprops
    end
    return newprops -- for checking
end

-- a bit special

local getwidth      = { }
local setwidth      = { }
local getdimensions = { }
local setdimensions = { }

nodes.whatsitters = {
    getters = { width = getwidth, dimensions = getdimensions },
    setters = { width = setwidth, dimensions = setdimensions },
}

-- this might move (in fact forms and images will become nodes)

local function get_width(n,dir)
    n = tonut(n)
    return getfield(n,"width")
end

local function get_dimensions(n,dir)
    n = tonut(n)
    return getfield(n,"width"), getfield(n,"height"), getfield(n,"depth")
end

local whatcodes         = nodes.whatcodes
local pdfrefximage_code = whatcodes.pdfrefximage
local pdfrefxform_code  = whatcodes.pdfrefxform

getwidth     [pdfrefximage_code] = get_width
getwidth     [pdfrefxform_code ] = get_width

getdimensions[pdfrefximage_code] = get_dimensions
getdimensions[pdfrefxform_code ] = get_dimensions


