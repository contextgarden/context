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

local nodecodes         = nodes.nodecodes
local nodepool          = nodes.pool
local disc_code         = nodecodes.disc
local glyph_code        = nodecodes.glyph
local emwidths          = fonts.hashes.emwidths
local exheights         = fonts.hashes.exheights
local newkern           = nodepool.kern
local newrule           = nodepool.rule
local newglue           = nodepool.glue

local insert_node_after = node.insert_after
local traverse_by_id    = node.traverse_id
local hyphenate         = languages.hyphenators.handler -- lang.hyphenate
local find_tail         = node.tail
local remove_node       = nodes.remove

local tracers           = nodes.tracers
local colortracers      = tracers and tracers.colors
local setnodecolor      = colortracers.set

local function identify(head,marked)
    local current, prev = head, nil
    while current do
        local id = current.id
        local next = current.next
        if id == disc_code then
            if prev and next then -- and next.id == glyph_code then -- catch other usage of disc
                marked[#marked+1] = prev
            end
        elseif id == glyph_code then
            prev = current
        end
        current = next
    end
end

local function strip(head,marked)
    for i=1,#marked do
        local prev = marked[i]
        remove_node(head,prev.next,true)
    end
end

local function mark(head,marked,w,h,d,how)
    for i=1,#marked do
        local prev  = marked[i]
        local font  = prev.font
        local em    = emwidths[font]
        local ex    = exheights[font]
        local width = w*em
        local rule  = newrule(width,h*ex,d*ex)
        head, prev  = insert_node_after(head,prev,newkern(-width/2))
        head, prev  = insert_node_after(head,prev,rule)
        head, prev  = insert_node_after(head,prev,newkern(-width/2))
        head, prev  = insert_node_after(head,prev,newglue(0))
        setnodecolor(rule,how,prev[a_colormodel])
    end
end

local langs, tags, noflanguages = { }, { }, 0

local colorbytag = false

function moduledata.languages.hyphenation.showhyphens(head)
    if noflanguages > 0 then
        local marked = { }
        for i=1,noflanguages do
            local m = { }
            local l = langs[i]
            marked[i] = m
            for n in traverse_by_id(glyph_code,head) do
                n.lang = l
            end
            languages.hyphenators.methods.original(head)
            identify(head,m)
            strip(head,m)
        end
        for i=noflanguages,1,-1 do
            local l = noflanguages - i + 1
            mark(head,marked[i],1/16,l/2,l/4,"hyphenation:"..(colorbytag and tags[i] or i))
        end
        return head, true
    else
        return head, false
    end
end

local savedlanguage

function moduledata.languages.hyphenation.startcomparepatterns(list)
    if list and list ~= "" then
        tags = utilities.parsers.settings_to_array(list)
    end
    savedlanguage = tex.language
    tex.language = 0
    noflanguages = #tags
    for i=1,noflanguages do
        langs[i] = tags[i] and languages.getnumber(tags[i])
    end
    nodes.tasks.enableaction("processors","moduledata.languages.hyphenation.showhyphens")
end

function moduledata.languages.hyphenation.stopcomparepatterns()
    noflanguages = 0
    tex.language = savedlanguage or tex.language
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
