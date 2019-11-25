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
local direct              = node.direct

local fastcopy            = table.fastcopy

local nodecodes           = nodes.nodecodes
local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local glyph_code          = nodecodes.glyph

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

-- -- some tracing:
--
-- local hash = table.setmetatableindex("number")
-- local ga = direct.get_attribute
-- function direct.get_attribute(n,a)
--     hash[a] = hash[a] + 1
--     return ga(n,a)
-- end
-- function nuts.reportattr()
--     inspect(hash)
-- end

-- local function track(name)
--     local n = 0
--     local f = direct[name]
--     direct[name] = function(...)
--         n = n + 1
--         if n % 1000 == 0 then
--             print(name,n)
--         end
--         return f(...)
--     end
-- end
-- track("getfield")

-- helpers

local nuts                   = nodes.nuts

nuts.check_discretionaries   = direct.check_discretionaries
nuts.copy                    = direct.copy
nuts.copy_node               = direct.copy
nuts.copy_only               = direct.copy_only or direct.copy
nuts.copy_list               = direct.copy_list
nuts.count                   = direct.count
nuts.current_attr            = direct.current_attr
nuts.delete                  = direct.delete
nuts.dimensions              = direct.dimensions
nuts.end_of_math             = direct.end_of_math
nuts.find_attribute          = direct.find_attribute
nuts.first_glyph             = direct.first_glyph
nuts.flatten_discretionaries = direct.flatten_discretionaries
nuts.flush                   = direct.flush_node
nuts.flush_list              = direct.flush_list
nuts.flush_node              = direct.flush_node
nuts.free                    = direct.free
nuts.get_synctex_fields      = direct.get_synctex_fields
nuts.has_attribute           = direct.has_attribute
nuts.has_field               = direct.has_field
nuts.has_glyph               = direct.has_glyph or direct.first_glyph
nuts.hpack                   = direct.hpack
nuts.insert_after            = direct.insert_after
nuts.insert_before           = direct.insert_before
nuts.is_direct               = direct.is_direct
nuts.is_node                 = direct.is_node
nuts.is_nut                  = direct.is_direct
nuts.kerning                 = direct.kerning
nuts.hyphenating             = direct.hyphenating
nuts.last_node               = direct.last_node
nuts.length                  = direct.length
nuts.ligaturing              = direct.ligaturing
nuts.new                     = direct.new
nuts.protect_glyph           = direct.protect_glyph
nuts.protect_glyphs          = direct.protect_glyphs
nuts.flush_components        = direct.flush_components
nuts.protrusion_skippable    = direct.protrusion_skippable
nuts.rangedimensions         = direct.rangedimensions
nuts.set_attribute           = direct.set_attribute
nuts.set_synctex_fields      = direct.set_synctex_fields
nuts.slide                   = direct.slide
nuts.tail                    = direct.tail
nuts.tostring                = direct.tostring
nuts.traverse                = direct.traverse
nuts.traverse_char           = direct.traverse_char
nuts.traverse_glyph          = direct.traverse_glyph
nuts.traverse_id             = direct.traverse_id
nuts.traverse_list           = direct.traverse_list
nuts.unprotect_glyph         = direct.unprotect_glyph
nuts.unprotect_glyphs        = direct.unprotect_glyphs
nuts.unset_attribute         = direct.unset_attribute
nuts.unset_attribute         = direct.unset_attribute
nuts.usedlist                = direct.usedlist
nuts.uses_font               = direct.uses_font
nuts.vpack                   = direct.vpack
nuts.writable_spec           = direct.writable_spec
nuts.write                   = direct.write
nuts.mlist_to_hlist          = direct.mlist_to_hlist
nuts.has_dimensions          = direct.has_dimensions
nuts.start_of_par            = direct.start_of_par

if not nuts.mlist_to_hlist then

    local n_mlist_to_hlist = node.mlist_to_hlist

    function nuts.mlist_to_hlist(head,...)
        if head then
            local head = n_mlist_to_hlist(tonode(head),...)
            if head then
                return tonut(head)
            end
        end
    end

end

if not nuts.has_dimensions then

    local getwhd = direct.getwhd

    function nuts.has_dimensions(n)
        local wd, ht, dp = getwhd(n)
        return wd ~= 0 or (ht + dp) ~= 0
    end

end

local getfield        = direct.getfield
local setfield        = direct.setfield

nuts.getfield         = getfield
nuts.setfield         = setfield

nuts.getnext          = direct.getnext
nuts.setnext          = direct.setnext

nuts.getid            = direct.getid

nuts.getprev          = direct.getprev
nuts.setprev          = direct.setprev

local get_attribute   = direct.get_attribute
local set_attribute   = direct.set_attribute
local unset_attribute = direct.unset_attribute

nuts.getattr          = get_attribute
nuts.setattr          = set_attribute
nuts.takeattr         = unset_attribute -- ?

nuts.is_zero_glue     = direct.is_zero_glue
nuts.effective_glue   = direct.effective_glue

nuts.getglue          = direct.getglue
nuts.setglue          = direct.setglue
nuts.getboxglue       = direct.getglue
nuts.setboxglue       = direct.setglue

nuts.getdisc          = direct.getdisc
nuts.setdisc          = direct.setdisc
nuts.getdiscretionary = direct.getdisc
nuts.setdiscretionary = direct.setdisc

nuts.getpre           = direct.getpre
nuts.setpre           = direct.setpre
nuts.getpost          = direct.getpost
nuts.setpost          = direct.setpost
nuts.getreplace       = direct.getreplace
nuts.setreplace       = direct.setreplace

local getdata         = direct.getdata
local setdata         = direct.setdata

nuts.getdata          = getdata
nuts.setdata          = setdata
nuts.getvalue         = getdata
nuts.setvalue         = setdata

nuts.getexpansion     = direct.getexpansion
nuts.setexpansion     = direct.setexpansion

nuts.getwhd           = direct.getwhd
nuts.setwhd           = direct.setwhd
nuts.getwidth         = direct.getwidth
nuts.setwidth         = direct.setwidth
nuts.getheight        = direct.getheight
nuts.setheight        = direct.setheight
nuts.getdepth         = direct.getdepth
nuts.setdepth         = direct.setdepth
nuts.getshift         = direct.getshift
nuts.setshift         = direct.setshift

-- lmtx compatibility

nuts.getorientation   = direct.getorientation or function() end
nuts.setorientation   = direct.setorientation or function() end

nuts.getglyphdata     = direct.getglyphdata or               get_attribute
nuts.setglyphdata     = direct.setglyphdata or function(n,d) set_attribute(n,0,d) end

nuts.getruledata      = direct.getglyphdata and getdata or function(n)   return getfield(n,"transform")   end
nuts.setruledata      = direct.setglyphdata and setdata or function(n,d) return setfield(n,"transform",d) end

-- so far

nuts.getnucleus       = direct.getnucleus
nuts.setnucleus       = direct.setnucleus
nuts.getsup           = direct.getsup
nuts.setsup           = direct.setsup
nuts.getsub           = direct.getsub
nuts.setsub           = direct.setsub

nuts.getchar          = direct.getchar
nuts.setchar          = direct.setchar
nuts.getfont          = direct.getfont
nuts.setfont          = direct.setfont
nuts.getfam           = direct.getfam
nuts.setfam           = direct.setfam

nuts.getboth          = direct.getboth
nuts.setboth          = direct.setboth
nuts.setlink          = direct.setlink
nuts.setsplit         = direct.setsplit

nuts.getlist          = direct.getlist -- only hlist and vlist !
nuts.setlist          = direct.setlist
nuts.getleader        = direct.getleader
nuts.setleader        = direct.setleader
nuts.getcomponents    = direct.getcomponents
nuts.setcomponents    = direct.setcomponents

nuts.getsubtype       = direct.getsubtype
nuts.setsubtype       = direct.setsubtype

nuts.getlang          = direct.getlang
nuts.setlang          = direct.setlang
nuts.getlanguage      = direct.getlang
nuts.setlanguage      = direct.setlang

nuts.getattrlist      = direct.getattributelist
nuts.setattrlist      = direct.setattributelist
nuts.getattributelist = direct.getattributelist
nuts.setattributelist = direct.setattributelist

nuts.getoffsets       = direct.getoffsets
nuts.setoffsets       = direct.setoffsets

nuts.getkern          = direct.getkern
nuts.setkern          = direct.setkern

nuts.getdir           = direct.getdir
nuts.setdir           = direct.setdir

nuts.getdirection     = direct.getdirection
nuts.setdirection     = direct.setdirection

nuts.getpenalty       = direct.getpenalty
nuts.setpenalty       = direct.setpenalty

nuts.getbox           = direct.getbox
nuts.setbox           = direct.setbox

nuts.ischar           = direct.is_char
nuts.isglyph          = direct.is_glyph

----.is_char          = nuts.ischar
----.is_glyph         = nuts.isglyph

local d_remove_node   = direct.remove
local d_flush_node    = direct.flush_node
local d_getnext       = direct.getnext
local d_getprev       = direct.getprev
local d_getid         = direct.getid
local d_getlist       = direct.getlist
local d_find_tail     = direct.tail
local d_insert_after  = direct.insert_after
local d_insert_before = direct.insert_before
local d_slide         = direct.slide
----- d_copy_node     = direct.copy
local d_traverse      = direct.traverse
local d_setlink       = direct.setlink
local d_setboth       = direct.setboth
local d_getboth       = direct.getboth

local remove = CONTEXTLMTXMODE > 0 and d_remove_node or function(head,current,free_too)
    if current then
        local h, c = d_remove_node(head,current)
        if free_too then
            d_flush_node(current)
            return h, c
        else
            d_setboth(current)
            return h, c, current
        end
    end
    return head, current
end

-- for now

if not nuts.start_of_par then

    local localparcodes = nodes.localparcodes
    local hmodepar_code = localparcodes.vmode_par
    local vmodepar_code = localparcodes.hmode_par

    local getsubtype    = nuts.getsubtype

    function nuts.start_of_par(n)
        local s = getsubtype(n)
        return s == hmodepar_code or s == vmodepar_code
    end

end

-- for now

if not nuts.getpre then

    local d_getdisc  = direct.getdisc
    local d_setfield = direct.setfield

    function nuts.getpre    (n) local h, _, _, t, _, _ = d_getdisc(n,true) return h, t end
    function nuts.getpost   (n) local _, h, _, _, t, _ = d_getdisc(n,true) return h, t end
    function nuts.getreplace(n) local _, _, h, _, _, t = d_getdisc(n,true) return h, t end

    function nuts.setpre    (n,h) d_setfield(d,"pre",    h) end
    function nuts.setpost   (n,h) d_setfield(d,"post",   h) end
    function nuts.setreplace(n,h) d_setfield(d,"replace",h) end

end

-- alias

nuts.getsurround = nuts.getkern
nuts.setsurround = nuts.setkern

nuts.remove = remove

function nuts.delete(head,current)
    return remove(head,current,true)
end

function nuts.replace(head,current,new) -- no head returned if false
    if not new then
        head, current, new = false, head, current
    end
    local prev, next = d_getboth(current)
    if prev or next then
        d_setlink(prev,new,next)
    end
    if head then
        if head == current then
            head = new
        end
        d_flush_node(current)
        return head, new
    else
        d_flush_node(current)
        return new
    end
end

local function countall(stack,flat)
    local n = 0
    while stack do
        local id = d_getid(stack)
        if not flat and id == hlist_code or id == vlist_code then
            local list = d_getlist(stack)
            if list then
                n = n + 1 + countall(list) -- self counts too
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

nuts.countall = countall

function nodes.countall(stack,flat)
    return countall(tonut(stack),flat)
end

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

function nuts.linked(...) -- slides !
    local head, last
    for i=1,select("#",...) do
        local next = select(i,...)
        if next then
            if head then
                d_setlink(last,next)
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
                d_setlink(tail,li)
            else
                head = li
            end
            tail = d_slide(li)
        end
    end
    return head, tail
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
            -- no setboth here yet
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
--             d_setnext(n,h)
--             d_setprev(n)
--             d_setprev(h,n)
--         else
--             local cp = d_getprev(c)
--             d_setnext(n,c)
--             d_setprev(n,cp)
--             if cp then
--                 d_setnext(cp,n)
--             end
--             d_setprev(c,n)
--             return h, n
--         end
--     end
--     return n, n
-- end

-- function nuts.insert_after(h,c,n)
--     if c then
--         local cn = d_getnext(c)
--         if cn then
--             d_setlink(n,cn)
--         else
--             d_setnext(n,nil)
--         end
--         d_setlink(c,n)
--         return h, n
--     end
--     return n, n
-- end

function nuts.insert_list_after(h,c,n)
    local t = d_tail(n)
    if c then
        local cn = d_getnext(c)
        if cn then
            d_setlink(t,cn)
        else
            d_setnext(t)
        end
        d_setlink(c,n)
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

local propertydata = direct.get_properties_table(true)

local getattr = nuts.getattr
local setattr = nuts.setattr

nodes.properties = {
    data = propertydata,
}

if direct.set_properties_mode then
    direct.set_properties_mode(true,true)  -- create metatable, slower but needed for font-otj.lua (unless we use an intermediate table)
    function direct.set_properties_mode() end
end

-- experimental code with respect to copying attributes has been removed
-- as it doesn't pay of (most attributes are only accessed once anyway)

nuts.getprop = function(n,k)
    local p = propertydata[n]
    if p then
        if k then
            return p[k]
        else
            return p
        end
    end
end

nuts.rawprop = function(n,k)
    local p = rawget(propertydata,n)
    if p then
        if k then
            return p[k]
        else
            return p
        end
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

nuts.isdone = function(n,k)
    local p = propertydata[n]
    if not p then
        propertydata[n] = { [k] = true }
        return false
    end
    local v = p[k]
    if v == nil then
        propertydata[n] = { [k] = true }
        return false
    end
    return v
end

-- nodes.setprop = nodes.setproperty
-- nodes.getprop = nodes.getproperty

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
