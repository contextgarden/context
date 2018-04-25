if not modules then modules = { } end modules ['s-languages-hyphenation'] = {
    version   = 1.001,
    comment   = "companion to s-languages-hyphenation.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.languages             = moduledata.languages             or { }
moduledata.languages.hyphenation = moduledata.languages.hyphenation or { }

local a_colormodel      = attributes.private('colormodel')

local tex               = tex
local context           = context

local nodecodes         = nodes.nodecodes
local nuts              = nodes.nuts
local nodepool          = nuts.pool

local disc_code         = nodecodes.disc
local glyph_code        = nodecodes.glyph

local emwidths          = fonts.hashes.emwidths
local exheights         = fonts.hashes.exheights

local newkern           = nodepool.kern
local newrule           = nodepool.rule
local newglue           = nodepool.glue

local insert_node_after = nuts.insert_after

local nextglyph         = nuts.traversers.glyph

local tonut             = nodes.tonut
local tonode            = nodes.tonode
local getid             = nuts.getid
local getnext           = nuts.getnext
local getdisc           = nuts.getdisc
local getattr           = nuts.getattr
local getfont           = nuts.getfont
local getfield          = nuts.getfield
local getlang           = nuts.getlang
local setlang           = nuts.setlang
local setlink           = nuts.setlink
local setdisc           = nuts.setdisc
local setfield          = nuts.setfield
local free_node         = nuts.free

local tracers           = nodes.tracers
local colortracers      = tracers and tracers.colors
local setnodecolor      = colortracers.set

-- maybe this will become code code

local states      = table.setmetatableindex(function(t,k)
    return {
        lefthyphenmin  = tex.lefthyphenmin,
        righthyphenmin = tex.righthyphenmin,
        hyphenationmin = tex.hyphenationmin,
        prehyphenchar  = tex.prehyphenchar,
        posthyphenchar = tex.posthyphenchar,
    }
end)

interfaces.implement {
    name    = "storelanguagestate",
    actions = function()
        states[tex.language] = {
            lefthyphenmin  = tex.lefthyphenmin,
            righthyphenmin = tex.righthyphenmin,
            hyphenationmin = tex.hyphenationmin,
            prehyphenchar  = tex.prehyphenchar,
            posthyphenchar = tex.posthyphenchar,
        }
    end
}

function moduledata.languages.getstate(l)
    return states[l] -- code
end

-- end

local function identify(head,marked)
    local current = tonut(head)
    local prev    = nil
    while current do
        local id   = getid(current)
        local next = getnext(current)
        if id == disc_code then
            if prev and next then -- asume glyphs
                marked[#marked+1] = prev
                local pre, post, replace, pre_tail, post_tail, replace_tail = getdisc(current,true)
                if replace then
                    setlink(prev,replace)
                    setlink(replace_tail,next)
                    setdisc(pre,post,nil)
                    prev = tail
                else
                    setlink(prev,next)
                end
                free_node(current)
            end
        elseif id == glyph_code then
            prev = current
        else
            prev = nil
        end
        current = next
    end
end

local function mark(head,marked,w,h,d,how)
    head = tonut(head)
    for i=1,#marked do
        local current = marked[i]
        local font    = getfont(current)
        local em      = emwidths[font]
        local ex      = exheights[font]
        local width   = w*em
        local rule    = newrule(width,h*ex,d*ex)
        head, current = insert_node_after(head,current,newkern(-width/2))
        head, current = insert_node_after(head,current,rule)
        head, current = insert_node_after(head,current,newkern(-width/2))
        head, current = insert_node_after(head,current,newglue(0))
        setnodecolor(rule,how) -- ,getattr(current,a_colormodel))
    end
end

local function getlanguage(head,l,left,right)
    local t = { }
    for n in nextglyph, tonut(head) do
        t[n] = {
            getlang(n),
            getfield(n,"left"),
            getfield(n,"right"),
        }
    end
end

local langs        = { }
local tags         = { }
local noflanguages = 0
local colorbytag   = false

function moduledata.languages.hyphenation.showhyphens(head)
    if noflanguages > 0 then
        local marked = { }
        local cached = { }
        -- somehow assigning -1 fails
        for n in nextglyph, tonut(head) do
            cached[n] = {
                getlang(n),
                getfield(n,"left"),
                getfield(n,"right")
            }
        end
        for i=1,noflanguages do
            local m = { }
            local l = langs[i]
            local s = states[l]
            marked[i] = m
            local lmin = s.lefthyphenmin
            local rmin = s.righthyphenmin
            for n in next, cached do
                setlang(n,l)
                setfield(n,"left",lmin)
                setfield(n,"right",rmin)
            end
            languages.hyphenators.methods.original(head)
            identify(head,m)
        end
        for i=noflanguages,1,-1 do
            local l = noflanguages - i + 1
            mark(head,marked[i],1/16,l/2,l/4,"hyphenation:"..(colorbytag and tags[i] or i))
        end
        for n, d in next, cached do
            setlang(n,d[1])
            setfield(n,"left",d[2])
            setfield(n,"right",d[3])
        end
        return head, true
    else
        return head, false
    end
end

function moduledata.languages.hyphenation.startcomparepatterns(list)
    if list and list ~= "" then
        tags = utilities.parsers.settings_to_array(list)
    end
    noflanguages = #tags
    context.begingroup()
    for i=1,noflanguages do
        langs[i] = tags[i] and languages.getnumber(tags[i])
        context.language{tags[i]}
    end
    context.endgroup()
    nodes.tasks.enableaction("processors","moduledata.languages.hyphenation.showhyphens")
end

function moduledata.languages.hyphenation.stopcomparepatterns()
    noflanguages = 0
    nodes.tasks.disableaction("processors","moduledata.languages.hyphenation.showhyphens")
end

function moduledata.languages.hyphenation.showcomparelegend(list)
    if list and list ~= "" then
        tags = utilities.parsers.settings_to_array(list)
    end
    for i=1,#tags do
        if i > 1 then
            context.enspace()
        end
        context.color( { "hyphenation:"..(colorbytag and tags[i] or i) }, tags[i])
    end
end

nodes.tasks.appendaction("processors","before","moduledata.languages.hyphenation.showhyphens")
nodes.tasks.disableaction("processors","moduledata.languages.hyphenation.showhyphens")
