if not modules then modules = { } end modules ['typo-krn'] = {
    version   = 1.001,
    comment   = "companion to typo-krn.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- glue is still somewhat suboptimal

local next, type, tonumber = next, type, tonumber
local utfchar = utf.char

local nodes, node, fonts = nodes, node, fonts

local tasks              = nodes.tasks
local nuts               = nodes.nuts
local nodepool           = nuts.pool

local tonode             = nuts.tonode
local tonut              = nuts.tonut

local find_node_tail     = nuts.tail
local free_node          = nuts.free
local free_nodelist      = nuts.flush_list
local copy_node          = nuts.copy
local copy_nodelist      = nuts.copy_list
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local end_of_math        = nuts.end_of_math

local getfield           = nuts.getfield
local setfield           = nuts.setfield
local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local getfont            = nuts.getfont
local getsubtype         = nuts.getsubtype
local getchar            = nuts.getchar

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local new_gluespec       = nodepool.gluespec
local new_kern           = nodepool.kern
local new_glue           = nodepool.glue

local nodecodes          = nodes.nodecodes
local kerncodes          = nodes.kerncodes
local skipcodes          = nodes.skipcodes
local disccodes          = nodes.disccodes

local glyph_code         = nodecodes.glyph
local kern_code          = nodecodes.kern
local disc_code          = nodecodes.disc
local glue_code          = nodecodes.glue
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local math_code          = nodecodes.math

local discretionary_code = disccodes.discretionary
local kerning_code       = kerncodes.kerning
local userkern_code      = kerncodes.userkern
local userskip_code      = skipcodes.userskip
local spaceskip_code     = skipcodes.spaceskip
local xspaceskip_code    = skipcodes.xspaceskip

local fonthashes         = fonts.hashes
local fontdata           = fonthashes.identifiers
local chardata           = fonthashes.characters
local quaddata           = fonthashes.quads
local markdata           = fonthashes.marks
local fontproperties     = fonthashes.properties
local fontdescriptions   = fonthashes.descriptions
local fontfeatures       = fonthashes.features

local tracers            = nodes.tracers
local setcolor           = tracers.colors.set
local resetcolor         = tracers.colors.reset

local v_max              = interfaces.variables.max
local v_auto             = interfaces.variables.auto

typesetters              = typesetters or { }
local typesetters        = typesetters

typesetters.kerns        = typesetters.kerns or { }
local kerns              = typesetters.kerns

local report             = logs.reporter("kerns")
local trace_ligatures    = false  trackers.register("typesetters.kerns.ligatures",function(v) trace_ligatures = v end)

kerns.mapping            = kerns.mapping or { }
kerns.factors            = kerns.factors or { }
local a_kerns            = attributes.private("kern")
local a_fontkern         = attributes.private('fontkern')

local contextsetups      = fonts.specifiers.contextsetups

storage.register("typesetters/kerns/mapping", kerns.mapping, "typesetters.kerns.mapping")
storage.register("typesetters/kerns/factors", kerns.factors, "typesetters.kerns.factors")

local mapping = kerns.mapping
local factors = kerns.factors

-- one must use liga=no and mode=base and kern=yes
-- use more helpers
-- make sure it runs after all others
-- there will be a width adaptor field in nodes so this will change
-- todo: interchar kerns / disc nodes / can be made faster
-- todo: use insert_before etc

local gluefactor = 4 -- assumes quad = .5 enspace

kerns.keepligature = false -- just for fun (todo: control setting with key/value)
kerns.keeptogether = false -- just for fun (todo: control setting with key/value)

-- red   : kept by dynamic feature
-- green : kept by static feature
-- blue  : keep by goodie

function kerns.keepligature(n) -- might become default
    local f = getfont(n)
    local a = getattr(n,0) or 0
    if trace_ligatures then
        local c = getchar(n)
        local d = fontdescriptions[f][c].name
        if a > 0 and contextsetups[a].keepligatures == v_auto then
            report("font %!font:name!, glyph %a, slot %X -> ligature %s, by %s feature %a",f,d,c,"kept","dynamic","keepligatures")
            setcolor(n,"darkred")
            return true
        end
        local k = fontfeatures[f].keepligatures
        if k == v_auto then
            report("font %!font:name!, glyph %a, slot %X -> ligature %s, by %s feature %a",f,d,c,"kept","static","keepligatures")
            setcolor(n,"darkgreen")
            return true
        end
        if not k then
            report("font %!font:name!, glyph %a, slot %X -> ligature %s, by %s feature %a",f,d,c,"split","static","keepligatures")
            resetcolor(n)
            return false
        end
        local k = fontproperties[f].keptligatures
        if not k then
            report("font %!font:name!, glyph %a, slot %X -> ligature %s, %s goodie specification",f,d,c,"split","no")
            resetcolor(n)
            return false
        end
        if k and k[c] then
            report("font %!font:name!, glyph %a, slot %X -> ligature %s, %s goodie specification",f,d,c,"kept","by")
            setcolor(n,"darkblue")
            return true
        else
            report("font %!font:name!, glyph %a, slot %X -> ligature %s, %s goodie specification",f,d,c,"split","by")
            resetcolor(n)
            return false
        end
    else
        if a > 0 and contextsetups[a].keepligatures == v_auto then
            return true
        end
        local k = fontfeatures[f].keepligatures
        if k == v_auto then
            return true
        end
        if not k then
            return false
        end
        local k = fontproperties[f].keptligatures
        if not k then
            return false
        end
        if k and k[c] then
            return true
        end
    end
end

-- can be optimized .. the prev thing .. but hardly worth the effort

local function kern_injector(fillup,kern)
    if fillup then
        local g = new_glue(kern)
        local s = getfield(g,"spec")
        setfield(s,"stretch",kern)
        setfield(s,"stretch_order",1)
        return g
    else
        return new_kern(kern)
    end
end

local function spec_injector(fillup,width,stretch,shrink)
    if fillup then
        local s = new_gluespec(width,2*stretch,2*shrink)
        setfield(s,"stretch_order",1)
        return s
    else
        return new_gluespec(width,stretch,shrink)
    end
end

-- needs checking ... base mode / node mode -- also use insert_before/after etc

local function do_process(head,force) -- todo: glue so that we can fully stretch
    local start        = head
    local done         = false
    local lastfont     = nil
    local keepligature = kerns.keepligature
    local keeptogether = kerns.keeptogether
    local fillup       = false
    while start do
        -- faster to test for attr first
        local attr = force or getattr(start,a_kerns)
        if attr and attr > 0 then
            setattr(start,a_kerns,unsetvalue)
            local krn = mapping[attr]
            if krn == v_max then
                krn    = .25
                fillup = true
            else
                fillup = false
            end
            if krn and krn ~= 0 then
                local id = getid(start)
                if id == glyph_code then -- we could use the subtype ligature
                    lastfont = getfont(start)
                    local c = getfield(start,"components")
                    if not c then
                        -- fine
                    elseif keepligature and keepligature(start) then
                        -- keep 'm
                    else
                        c = do_process(c,attr)
                        local s    = start
                        local p    = getprev(s)
                        local n    = getnext(s)
                        local tail = find_node_tail(c)
                        if p then
                            setfield(p,"next",c)
                            setfield(c,"prev",p)
                        else
                            head = c
                        end
                        if n then
                            setfield(n,"prev",tail)
                        end
                        setfield(tail,"next",n)
                        start = c
                        setfield(s,"components",nil)
                        -- we now leak nodes !
                    --  free_node(s)
                        done = true
                    end
                    local prev = getprev(start)
                    if not prev then
                        -- skip
                    elseif markdata[lastfont][getchar(start)] then
                            -- skip
                    else
                        local pid = getid(prev)
                        if not pid then
                            -- nothing
                        elseif pid == kern_code then
                            if getsubtype(prev) == kerning_code or getattr(prev,a_fontkern) then
                                if keeptogether and getid(getprev(prev)) == glyph_code and keeptogether(getprev(prev),start) then -- we could also pass start
                                    -- keep 'm
                                else
                                    -- not yet ok, as injected kerns can be overlays (from node-inj.lua)
                                    setfield(prev,"subtype",userkern_code)
                                    setfield(prev,"kern",getfield(prev,"kern") + quaddata[lastfont]*krn) -- here
                                    done = true
                                end
                            end
                        elseif pid == glyph_code then
                            if getfont(prev) == lastfont then
                                local prevchar, lastchar = getchar(prev), getchar(start)
                                if keeptogether and keeptogether(prev,start) then
                                    -- keep 'm
                                else
                                    local kerns = chardata[lastfont][prevchar].kerns
                                    local kern = kerns and kerns[lastchar] or 0
                                    krn = kern + quaddata[lastfont]*krn -- here
                                    insert_node_before(head,start,kern_injector(fillup,krn))
                                    done = true
                                end
                            else
                                krn = quaddata[lastfont]*krn -- here
                                insert_node_before(head,start,kern_injector(fillup,krn))
                                done = true
                            end
                        elseif pid == disc_code then
                            -- a bit too complicated, we can best not copy and just calculate
                            -- but we could have multiple glyphs involved so ...
                            local disc = prev -- disc
                            local prv  = getprev(disc)
                            local nxt  = getnext(disc)
                            if getsubtype(disc) == discretionary_code then
                                -- maybe we should forget about this variant as there is no glue
                                -- possible .. hardly used so a copy doesn't hurt much
                                local pre     = getfield(disc,"pre")
                                local post    = getfield(disc,"post")
                                local replace = getfield(disc,"replace")
                                if pre and prv then -- must pair with getprev(start)
                                    local before = copy_node(prv)
                                    setfield(pre,"prev",before)
                                    setfield(before,"next",pre)
                                    setfield(before,"prev",nil)
                                    pre = do_process(before,attr)
                                    pre = getnext(pre)
                                    setfield(pre,"prev",nil)
                                    setfield(disc,"pre",pre)
                                    free_node(before)
                                end
                                if post and nxt then  -- must pair with start
                                    local after = copy_node(nxt)
                                    local tail  = find_node_tail(post)
                                    setfield(tail,"next",after)
                                    setfield(after,"prev",tail)
                                    setfield(after,"next",nil)
                                    post = do_process(post,attr)
                                    setfield(tail,"next",nil)
                                    setfield(disc,"post",post)
                                    free_node(after)
                                end
                                if replace and prv and nxt then -- must pair with start and start.prev
                                    local before = copy_node(prv)
                                    local after  = copy_node(nxt)
                                    local tail   = find_node_tail(replace)
                                    setfield(replace,"prev",before)
                                    setfield(before,"next",replace)
                                    setfield(before,"prev",nil)
                                    setfield(tail,"next",after)
                                    setfield(after,"prev",tail)
                                    setfield(after,"next",nil)
                                    replace = do_process(before,attr)
                                    replace = getnext(replace)
                                    setfield(replace,"prev",nil)
                                    setfield(getfield(after,"prev"),"next",nil)
                                    setfield(disc,"replace",replace)
                                    free_node(after)
                                    free_node(before)
                                elseif prv and getid(prv) == glyph_code and getfont(prv) == lastfont then
                                    local prevchar = getchar(prv)
                                    local lastchar = getchar(start)
                                    local kerns    = chardata[lastfont][prevchar].kerns
                                    local kern     = kerns and kerns[lastchar] or 0
                                    krn = kern + quaddata[lastfont]*krn -- here
                                    setfield(disc,"replace",kern_injector(false,krn)) -- only kerns permitted, no glue
                                else
                                    krn = quaddata[lastfont]*krn -- here
                                    setfield(disc,"replace",kern_injector(false,krn)) -- only kerns permitted, no glue
                                end
                            else
                                -- this one happens in most cases: automatic (-), explicit (\-), regular (patterns)
                                if prv and getid(prv) == glyph_code and getfont(prv) == lastfont then
                                    -- the normal case
                                    local prevchar = getchar(prv)
                                    local lastchar = getchar(start)
                                    local kerns    = chardata[lastfont][prevchar].kerns
                                    local kern     = kerns and kerns[lastchar] or 0
                                    krn = kern + quaddata[lastfont]*krn
                                else
                                    krn = quaddata[lastfont]*krn
                                end
                                insert_node_before(head,start,kern_injector(fillup,krn))
                            end
                        end
                    end
                elseif id == glue_code then
                    local subtype = getsubtype(start)
                    if subtype == userskip_code or subtype == xspaceskip_code or subtype == spaceskip_code then
                        local s = getfield(start,"spec")
                        local w = getfield(s,"width")
                        if w > 0 then
                            local width   = w+gluefactor*w*krn
                            local stretch = getfield(s,"stretch")
                            local shrink  = getfield(s,"shrink")
                            setfield(start,"spec",spec_injector(fillup,width,stretch*width/w,shrink*width/w))
                            done = true
                        end
                    end
                elseif id == kern_code then
                 -- if getsubtype(start) == kerning_code then -- handle with glyphs
                 --     local sk = getfield(start,"kern")
                 --     if sk > 0 then
                 --         setfield(start,"kern",sk*krn)
                 --         done = true
                 --     end
                 -- end
                elseif lastfont and (id == hlist_code or id == vlist_code) then -- todo: lookahead
                    local p = getprev(start)
                    if p and getid(p) ~= glue_code then
                        insert_node_before(head,start,kern_injector(fillup,quaddata[lastfont]*krn))
                        done = true
                    end
                    local n = getnext(start)
                    if n and getid(n) ~= glue_code then
                        insert_node_after(head,start,kern_injector(fillup,quaddata[lastfont]*krn))
                        done = true
                    end
                elseif id == math_code then
                    start = end_of_math(start)
                end
            end
        end
        if start then
            start = getnext(start)
        end
    end
    return head, done
end

local enabled = false

function kerns.set(factor)
    if factor ~= v_max then
        factor = tonumber(factor) or 0
    end
    if factor == v_max or factor ~= 0 then
        if not enabled then
            tasks.enableaction("processors","typesetters.kerns.handler")
            enabled = true
        end
        local a = factors[factor]
        if not a then
            a = #mapping + 1
            factors[factors], mapping[a] = a, factor
        end
        factor = a
    else
        factor = unsetvalue
    end
    texsetattribute(a_kerns,factor)
    return factor
end

function kerns.handler(head)
    local head, done = do_process(tonut(head))  -- no direct map, because else fourth argument is tail == true
    return tonode(head), done
end

-- interface

commands.setcharacterkerning = kerns.set
