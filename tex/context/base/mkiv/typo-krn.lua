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

local nodes              = nodes
local fonts              = fonts

local tasks              = nodes.tasks
local nuts               = nodes.nuts
local nodepool           = nuts.pool

local tonode             = nuts.tonode
local tonut              = nuts.tonut

-- check what is used

local find_node_tail     = nuts.tail
local free_node          = nuts.free
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local end_of_math        = nuts.end_of_math

local getfield           = nuts.getfield
local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getboth            = nuts.getboth
local getid              = nuts.getid
local getfont            = nuts.getfont
local getsubtype         = nuts.getsubtype
local getchar            = nuts.getchar
local getdisc            = nuts.getdisc

local setfield           = nuts.setfield
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local setlink            = nuts.setlink
local setsubtype         = nuts.setsubtype

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local new_gluespec       = nodepool.gluespec
local new_kern           = nodepool.kern
local new_glue           = nodepool.glue

local nodecodes          = nodes.nodecodes
local kerncodes          = nodes.kerncodes
local skipcodes          = nodes.skipcodes
local disccodes          = nodes.disccodes
local listcodes          = nodes.listcodes

local glyph_code         = nodecodes.glyph
local kern_code          = nodecodes.kern
local disc_code          = nodecodes.disc
local glue_code          = nodecodes.glue
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local math_code          = nodecodes.math

local box_list_code      = listcodes.box
local user_list_code     = listcodes.unknown

local discretionary_code = disccodes.discretionary
local automatic_code     = disccodes.automatic

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

-- use_advance is just an experiment: it makes copying glyphs (instead of new_glyph) dangerous

local use_advance        = false  directives.register("typesetters.kerns.advance", function(v) use_advance = v end)

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
        setfield(g,"stretch",kern)
        setfield(g,"stretch_order",1)
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

-- a simple list injector, no components and such .. just disable ligatures in
-- kern mode .. maybe not even hyphenate ... anyway, the next one is for simple
-- sublists .. beware: we can have char -1

local function inject_begin(boundary,prev,keeptogether,krn,ok) -- prev is a glyph
    local id = getid(boundary)
    if id == kern_code then
        if getsubtype(boundary) == kerning_code or getattr(boundary,a_fontkern) then
            local inject = true
            if keeptogether then
                local next = getnext(boundary)
                if not next or (getid(next) == glyph_code and keeptogether(prev,next)) then
                    inject = false
                end
            end
            if inject then
                -- not yet ok, as injected kerns can be overlays (from node-inj.lua)
                setsubtype(boundary,userkern_code)
                setfield(boundary,"kern",getfield(boundary,"kern") + quaddata[getfont(prev)]*krn)
                return boundary, true
            end
        end
    elseif id == glyph_code then
        if keeptogether and keeptogether(boundary,prev) then
            -- keep 'm
        else
            local charone = getchar(prev)
            if charone > 0 then
                local font    = getfont(boundary)
                local chartwo = getchar(boundary)
                local data    = chardata[font][charone]
                local kerns   = data and data.kerns
                local kern    = new_kern((kerns and kerns[chartwo] or 0) + quaddata[font]*krn)
                setlink(kern,boundary)
                return kern, true
            end
        end
    end
    return boundary, ok
end

local function inject_end(boundary,next,keeptogether,krn,ok)
    local tail = find_node_tail(boundary)
    local id   = getid(tail)
    if id == kern_code then
        if getsubtype(tail) == kerning_code or getattr(tail,a_fontkern) then
            local inject = true
            if keeptogether then
                local prev = getprev(tail)
                if getid(prev) == glyph_code and keeptogether(prev,two) then
                    inject = false
                end
            end
            if inject then
                -- not yet ok, as injected kerns can be overlays (from node-inj.lua)
                setsubtype(tail,userkern_code)
                setfield(tail,"kern",getfield(tail,"kern") + quaddata[getfont(next)]*krn)
                return boundary, true
            end
        end
    elseif id == glyph_code then
        if keeptogether and keeptogether(tail,two) then
            -- keep 'm
        else
            local charone = getchar(tail)
            if charone > 0 then
                local font    = getfont(tail)
                local chartwo = getchar(next)
                local data    = chardata[font][charone]
                local kerns   = data and data.kerns
                local kern    = (kerns and kerns[chartwo] or 0) + quaddata[font]*krn
                insert_node_after(boundary,tail,new_kern(kern))
                return boundary, true
            end
        end
    end
    return boundary, ok
end

local function process_list(head,keeptogether,krn,font,okay)
    local start = head
    local prev  = nil
    local pid   = nil
    local kern  = 0
    local mark  = font and markdata[font]
    while start  do
        local id = getid(start)
        if id == glyph_code then
            if not font then
                font = getfont(start)
                mark = markdata[font]
                kern = quaddata[font]*krn
            end
            if prev then
                local char = getchar(start)
                if mark[char] then
                    -- skip
                elseif pid == kern_code then
                    if getsubtype(prev) == kerning_code or getattr(prev,a_fontkern) then
                        local inject = true
                        if keeptogether then
                            local prevprev = getprev(prev)
                            if getid(prevprev) == glyph_code and keeptogether(prevprev,start) then
                                inject = false
                            end
                        end
                        if inject then
                            -- not yet ok, as injected kerns can be overlays (from node-inj.lua)
                            setsubtype(prev,userkern_code)
                            setfield(prev,"kern",getfield(prev,"kern") + kern)
                            okay = true
                        end
                    end
                elseif pid == glyph_code then
                    if keeptogether and keeptogether(prev,start) then
                        -- keep 'm
                    else
                        local prevchar = getchar(prev)
                        local data     = chardata[font][prevchar]
                        local kerns    = data and data.kerns
                     -- if kerns then
                     --     print("it happens indeed, basemode kerns not yet injected")
                     -- end
                        insert_node_before(head,start,new_kern((kerns and kerns[char] or 0) + kern))
                        okay = true
                    end
                end
            end
        end
        if start then
            prev  = start
            pid   = id
            start = getnext(start)
        end
    end
    return head, okay, prev
end

local function closest_bound(b,get)
    b = get(b)
    if b and getid(b) ~= glue_code then
        while b do
            if not getattr(b,a_kerns) then
                break
            elseif getid(b) == glyph_code then
                return b, getfont(b)
            else
                b = get(b)
            end
        end
    end
end

function kerns.handler(head)
    local head         = tonut(head)
    local start        = head
    local done         = false
    local lastfont     = nil
    local keepligature = kerns.keepligature
    local keeptogether = kerns.keeptogether
    local fillup       = false
    local bound        = false
    local prev         = nil
    local previd       = nil
    local prevchar     = nil
    local prevfont     = nil
    local prevmark     = nil
    while start do
        -- fontkerns don't get the attribute but they always sit between glyphs so
        -- are always valid bound .. disc nodes also somtimes don't get them
        local id   = getid(start)
        local attr = getattr(start,a_kerns)
        if attr and attr > 0 then
            setattr(start,a_kerns,0) -- unsetvalue)
            local krn = mapping[attr]
            if krn == v_max then
                krn    = .25
                fillup = true
            else
                fillup = false
            end
            if not krn or krn == 0 then
                bound = false
            elseif id == glyph_code then -- we could use the subtype ligature
                local c = getfield(start,"components")
                if not c then
                    -- fine
                elseif keepligature and keepligature(start) then
                    -- keep 'm
                    c = nil
                else
                    while c do
                        local s = start
                        local t = find_node_tail(c)
                        local p, n = getboth(s)
                        if p then
                            setlink(p,c)
                        else
                            head = c
                        end
                        if n then
                            setlink(t,n)
                        end
                        start = c
                        setfield(s,"components",nil)
                        free_node(s)
                        c = getfield(start,"components")
                    end
                end
                local char = getchar(start)
                local font = getfont(start)
                local mark = markdata[font]
                if not bound then
                    -- yet
                elseif mark[char] then
                    -- skip
                elseif previd == kern_code then
                    if getsubtype(prev) == kerning_code or getattr(prev,a_fontkern) then
                        local inject = true
                        if keeptogether then
                            if previd == glyph_code and keeptogether(prev,start) then
                                inject = false
                            end
                        end
                        if inject then
                            -- not yet ok, as injected kerns can be overlays (from node-inj.lua)
                            setsubtype(prev,userkern_code)
                            setfield(prev,"kern",getfield(prev,"kern") + quaddata[font]*krn)
                            done = true
                        end
                    end
                elseif previd == glyph_code then
                    if prevfont == font then
                        if keeptogether and keeptogether(prev,start) then
                            -- keep 'm
                        else
                            local data  = chardata[font][prevchar]
                            local kerns = data and data.kerns
                            local kern  = (kerns and kerns[char] or 0) + quaddata[font]*krn
                            if not fillup and use_advance then
                                setfield(prev,"xadvance",getfield(prev,"xadvance") + kern)
                            else
                                insert_node_before(head,start,kern_injector(fillup,kern))
                            end
                            done = true
                        end
                    else
                        insert_node_before(head,start,kern_injector(fillup,quaddata[font]*krn))
                        done = true
                    end
                end
                prev     = start
                prevchar = char
                prevfont = font
                prevmark = mark
                previd   = id
                bound    = true
            elseif id == disc_code then
                local prev, next, pglyph, nglyph -- delayed till needed
                local subtype = getsubtype(start)
                if subtype == automatic_code then
                    -- this is kind of special, as we have already injected the
                    -- previous kern
                    local prev   = getprev(start)
                    local pglyph = prev and getid(prev) == glyph_code
                    languages.expand(start,pglyph and prev)
                    -- we can have a different start now
                elseif subtype ~= discretionary_code then
                    prev    = getprev(start)
                    pglyph  = prev and getid(prev) == glyph_code
                    languages.expand(start,pglyph and prev)
                end
                local pre, post, replace = getdisc(start)
                -- we really need to reasign the fields as luatex keeps track of
                -- the tail in a temp preceding head .. kind of messy so we might
                -- want to come up with a better solution some day like a real
                -- pretail etc fields in a disc node
                --
                -- maybe i'll merge the now split functions
                if pre then
                    local okay = false
                    if not prev then
                        prev   = prev or getprev(start)
                        pglyph = prev and getid(prev) == glyph_code
                    end
                    if pglyph then
                        pre, okay = inject_begin(pre,prev,keeptogether,krn,okay)
                    end
                    pre, okay = process_list(pre,keeptogether,krn,false,okay)
                    if okay then
                        setfield(start,"pre",pre)
                        done = true
                    end
                end
                if post then
                    local okay = false
                    if not next then
                        next   = getnext(start)
                        nglyph = next and getid(next) == glyph_code
                    end
                    if nglyph then
                        post, okay = inject_end(post,next,keeptogether,krn,okay)
                    end
                    post, okay = process_list(post,keeptogether,krn,false,okay)
                    if okay then
                        setfield(start,"post",post)
                        done = true
                    end
                end
                if replace then
                    local okay = false
                    if not prev then
                        prev    = prev or getprev(start)
                        pglyph  = prev and getid(prev) == glyph_code
                    end
                    if pglyph then
                        replace, okay = inject_begin(replace,prev,keeptogether,krn,okay)
                    end
                    if not next then
                        next   = getnext(start)
                        nglyph = next and getid(next) == glyph_code
                    end
                    if nglyph then
                        replace, okay = inject_end(replace,next,keeptogether,krn,okay)
                    end
                    replace, okay = process_list(replace,keeptogether,krn,false,okay)
                    if okay then
                        setfield(start,"replace",replace)
                        done = true
                    end
                elseif prevfont then
                    setfield(start,"replace",new_kern(quaddata[prevfont]*krn))
                    done = true
                end
                bound = false
            elseif id == kern_code then
                bound  = getsubtype(start) == kerning_code or getattr(start,a_fontkern)
                prev   = start
                previd = id
            elseif id == glue_code then
                local subtype = getsubtype(start)
                if subtype == userskip_code or subtype == xspaceskip_code or subtype == spaceskip_code then
                    local w = getfield(start,"width")
                    if w > 0 then
                        local width   = w+gluefactor*w*krn
                        local stretch = getfield(start,"stretch")
                        local shrink  = getfield(start,"shrink")
                        setfield(start,"spec",spec_injector(fillup,width,stretch*width/w,shrink*width/w))
                        done = true
                    end
                end
                bound = false
            elseif id == hlist_code or id == vlist_code then
                local subtype = getsubtype(start)
                if subtype == user_list_code or subtype == box_list_code then
                    -- special case
                    local b, f = closest_bound(start,getprev)
                    if b then
                        insert_node_before(head,start,kern_injector(fillup,quaddata[f]*krn))
                        done = true
                    end
                    local b, f = closest_bound(start,getnext)
                    if b then
                        insert_node_after(head,start,kern_injector(fillup,quaddata[f]*krn))
                        done = true
                    end
                end
                bound = false
            elseif id == math_code then
                start = end_of_math(start)
                bound = false
            end
            if start then
                start = getnext(start)
            end
        elseif id == kern_code then
            bound  = getsubtype(start) == kerning_code or getattr(start,a_fontkern)
            prev   = start
            previd = id
            start  = getnext(start)
        else
            bound = false
            start = getnext(start)
        end
    end
    return tonode(head), done
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

-- interface

interfaces.implement {
    name      = "setcharacterkerning",
    actions   = kerns.set,
    arguments = "string"
}

