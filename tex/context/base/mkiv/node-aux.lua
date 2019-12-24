if not modules then modules = { } end modules ['node-aux'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: n1 .. n2 : __concat metatable

local type, tostring = type, tostring

local nodes              = nodes
local context            = context

local utfvalues          = utf.values

local nodecodes          = nodes.nodecodes

local glyph_code         = nodecodes.glyph
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local attributelist_code = nodecodes.attributelist -- temporary
local localpar_code      = nodecodes.localpar

local nuts               = nodes.nuts
local tonut              = nuts.tonut
local tonode             = nuts.tonode
local vianuts            = nuts.vianuts

local getbox             = nuts.getbox
local getnext            = nuts.getnext
local getid              = nuts.getid
local getsubtype         = nuts.getsubtype
local getlist            = nuts.getlist
local getattr            = nuts.getattr
local getboth            = nuts.getboth
local getprev            = nuts.getprev
local getcomponents      = nuts.getcomponents
local getwidth           = nuts.getwidth
local setwidth           = nuts.setwidth
local getboxglue         = nuts.getboxglue
local setboxglue         = nuts.setboxglue

local setfield           = nuts.setfield
local setattr            = nuts.setattr
local setlink            = nuts.setlink
local setlist            = nuts.setlist
local setnext            = nuts.setnext
local setprev            = nuts.setprev
local setcomponents      = nuts.setcomponents
local setattrlist        = nuts.setattrlist

local traversers         = nuts.traversers
local nextnode           = traversers.node
local nextglyph          = traversers.glyph

local flush_node         = nuts.flush
local flush_list         = nuts.flush_list
local hpack_nodes        = nuts.hpack
local unset_attribute    = nuts.unset_attribute
local first_glyph        = nuts.first_glyph
local copy_node          = nuts.copy
local find_tail          = nuts.tail
local getbox             = nuts.getbox
local count              = nuts.count

local nodepool           = nuts.pool
local new_glue           = nodepool.glue
local new_glyph          = nodepool.glyph

local unsetvalue         = attributes.unsetvalue

local current_font       = font.current

local texsetbox          = tex.setbox

local report_error       = logs.reporter("node-aux:error")

-- At some point we figured that copying before using was the safest bet
-- when dealing with boxes at the tex end. This is because tex also needs
-- to manage the grouping (i.e. savestack). However, there is an easy
-- solution that keeps the tex end happy as tex.setbox deals with this. The
-- overhead of one temporary list node is neglectable.
--
-- function tex.takebox(id)
--     local box = tex.getbox(id)
--     if box then
--         local copy = node.copy(box)
--         local list = box.list
--         copy.list = list
--         box.list = nil
--         tex.setbox(id,nil)
--         return copy
--     end
-- end

local function takebox(id)
    local box = getbox(id)
    if box then
        local list = getlist(box)
        setlist(box,nil)
        local copy = copy_node(box)
        if list then
            setlist(copy,list)
        end
        texsetbox(id,false)
        return copy
    end
end

function nodes.takebox(id)
    local b = takebox(id)
    if b then
        return tonode(b)
    end
end

local splitbox = tex.splitbox
nodes.splitbox = splitbox

function nuts.splitbox(id,height)
    return tonut(splitbox(id,height))
end

-- function nodes.takelist(n)
--     -- when we need it
-- end

function nuts.takelist(n)
    local l = getlist(n)
    setlist(n)
    flush_node(n)
    return l
end

nuts.takebox = takebox
tex.takebox  = nodes.takebox -- sometimes more clear

-- so far

local function repackhlist(list,...)
    local temp, b = hpack_nodes(list,...)
    list = getlist(temp)
    setlist(temp)
    flush_node(temp)
    return list, b
end

nuts.repackhlist = repackhlist

function nodes.repackhlist(list,...)
    local list, b = repackhlist(tonut(list),...)
    return tonode(list), b
end

local function set_attributes(head,attr,value)
    for n, id in nextnode, head do
        setattr(n,attr,value)
        if id == hlist_node or id == vlist_node then
            set_attributes(getlist(n),attr,value)
        end
    end
end

local function set_unset_attributes(head,attr,value)
    for n, id in nextnode, head do
        if not getattr(n,attr) then
            setattr(n,attr,value)
        end
        if id == hlist_code or id == vlist_code then
            set_unset_attributes(getlist(n),attr,value)
        end
    end
end

local function unset_attributes(head,attr)
    for n, id in nextnode, head do
        setattr(n,attr,unsetvalue)
        if id == hlist_code or id == vlist_code then
            unset_attributes(getlist(n),attr)
        end
    end
end

-- for old times sake

nuts.setattribute        = nuts.setattr                      nodes.setattribute       = nodes.setattr
nuts.getattribute        = nuts.getattr                      nodes.getattribute       = nodes.getattr
nuts.unsetattribute      = nuts.unset_attribute              nodes.unsetattribute     = nodes.unset_attribute
nuts.has_attribute       = nuts.has_attribute                nodes.has_attribute      = nodes.has_attribute
nuts.firstglyph          = nuts.first_glyph                  nodes.firstglyph         = nodes.first_glyph

nuts.setattributes       = set_attributes                    nodes.setattributes      = vianuts(set_attributes)
nuts.setunsetattributes  = set_unset_attributes              nodes.setunsetattributes = vianuts(set_unset_attributes)
nuts.unsetattributes     = unset_attributes                  nodes.unsetattributes    = vianuts(unset_attributes)

function nuts.firstcharacter(n,untagged) -- tagged == subtype > 255
    if untagged then
        return first_glyph(n)
    else
        for g in nextglyph ,n do
            return g
        end
    end
end

local function firstcharinbox(n)
    local l = getlist(getbox(n))
    if l then
        for g, c in nextglyph, l do
            return c
        end
    end
    return 0
end

nuts .firstcharinbox = firstcharinbox
nodes.firstcharinbox = firstcharinbox -- hm, ok ?
nodes.firstcharacter = vianuts(firstcharacter)

interfaces.implement {
    name      = "buildtextaccent",
    arguments = "integer",
    actions   = function(n) -- Is this crap really used? Or was it an experiment?
        local char = firstcharinbox(n)
        if char > 0 then
         -- context.accent(false,char)
            context([[\accent%s\relax]],char)
        end
    end
}

-- this depends on fonts, so we have a funny dependency ... will be
-- sorted out .. we could make tonodes a plugin into this

local function tonodes(str,fnt,attr) -- (str,template_glyph) -- moved from blob-ini
    if not str or str == "" then
        return
    end
    local head, tail, space, fnt, template = nil, nil, nil, nil, nil
    if not fnt then
        fnt = current_font()
    elseif type(fnt) ~= "number" and getid(fnt) == glyph_code then -- so it has to be a real node
        fnt, template = nil, tonut(fnt)
    end
    for s in utfvalues(str) do
        local n
        if s == 32 then
            if space then
                n = copy_node(space)
            elseif fonts then -- depedency
                local parameters = fonts.hashes.identifiers[fnt].parameters
                space = new_glue(parameters.space,parameters.space_stretch,parameters.space_shrink)
                n = space
            end
        elseif template then
            n = copy_node(template)
            setvalue(n,"char",s)
        else
            n = new_glyph(fnt,s)
        end
        if attr then -- normally false when template
            setattrlist(n,attr)
        end
        if head then
            setlink(tail,n)
        else
            head = n
        end
        tail = n
    end
    return head, tail
end

nuts.tonodes = tonodes

nodes.tonodes = function(str,fnt,attr)
    local head, tail = tonodes(str,fnt,attr)
    return tonode(head), tonode(tail)
end

local function link(list,currentfont,currentattr,head,tail) -- an oldie, might be replaced
    for i=1,#list do
        local n = list[i]
        if n then
            local tn = type(n)
            if tn == "string" then
                if #tn > 0 then
                    if not currentfont then
                        currentfont = current_font()
                    end
                    local h, t = tonodes(n,currentfont,currentattr)
                    if not h then
                        -- skip
                    elseif not head then
                        head, tail = h, t
                    else
                        setnext(tail,h)
                        setprev(h,t)
                        tail = t
                    end
                end
            elseif tn == "table" then
                if #tn > 0 then
                    if not currentfont then
                        currentfont = current_font()
                    end
                    head, tail = link(n,currentfont,currentattr,head,tail)
                end
            elseif not head then
                head = n
                tail = find_tail(n)
            elseif getid(n) == attributelist_code then
                -- weird case
                report_error("weird node type in list at index %s:",i)
                for i=1,#list do
                    local l = list[i]
                    report_error("%3i: %s %S",i,getid(l) == attributelist_code and "!" or ">",l)
                end
                os.exit()
            else
                setlink(tail,n)
                if getnext(n) then
                    tail = find_tail(n)
                else
                    tail = n
                end
            end
        else
            -- permitting nil is convenient
        end
    end
    return head, tail
end

nuts.link = link

nodes.link = function(list,currentfont,currentattr,head,tail)
    local head, tail = link(list,currentfont,currentattr,tonut(head),tonut(tail))
    return tonode(head), tonode(tail)
end

local function locate(start,wantedid,wantedsubtype)
    for n, id, subtype in nextnode, start do
        if id == wantedid then
            if not wantedsubtype or subtype == wantedsubtype then
                return n
            end
        elseif id == hlist_code or id == vlist_code then
            local found = locate(getlist(n),wantedid,wantedsubtype)
            if found then
                return found
            end
        end
    end
end

nuts.locate = locate

function nodes.locate(start,wantedid,wantedsubtype)
    local found = locate(tonut(start),wantedid,wantedsubtype)
    return found and tonode(found)
end

local function rehpack(n,width)
    local head = getlist(n)
    local size = width or getwidth(n)
    local temp = hpack_nodes(head,size,"exactly")
    setwidth(n,size)
    local set, order, sign = getboxglue(temp)
    setboxglue(n,set,order,sign)
    setlist(temp)
    flush_node(temp)
    return n
end

nuts.rehpack = rehpack

function nodes.rehpack(n,...)
    rehpack(tonut(n),...)
end

-- nodemode helper: the next and prev pointers are untouched

function nuts.copy_no_components(g,copyinjection)
    local components = getcomponents(g)
    if components then
        setcomponents(g)
        local n = copy_node(g)
        if copyinjection then
            copyinjection(n,g)
        end
        setcomponents(g,components)
        -- maybe also upgrade the subtype but we don't use it anyway
        return n
    else
        local n = copy_node(g)
        if copyinjection then
            copyinjection(n,g)
        end
        return n
    end
end

function nuts.copy_only_glyphs(current)
    local head     = nil
    local previous = nil
    for n in nextglyph, current do
        n = copy_node(n)
        if head then
            setlink(previous,n)
        else
            head = n
        end
        previous = n
    end
    return head
end

-- node- and basemode helper

function nuts.use_components(head,current)
    local components = getcomponents(current)
    if not components then
        return head, current, current
    end
    local prev, next = getboth(current)
    local first = current
    local last  = next
    while components do
        local gone = current
        local tail = find_tail(components)
        if prev then
            setlink(prev,components)
        end
        if next then
            setlink(tail,next)
        end
        if first == current then
            first = components
        end
        if head == current then
            head = components
        end
        current = components
        setcomponents(gone)
        flush_node(gone)
        while true do
            components = getcomponents(current)
            if components then
                next = getnext(current)
                break -- current is composed
            end
            if next == last then
                last = current
                break -- components is false
            end
            prev    = current
            current = next
            next    = getnext(current)
        end
    end
    return head, first, last
end

do

    local localparcodes = nodes.localparcodes
    local hmodepar_code = localparcodes.vmode_par
    local vmodepar_code = localparcodes.hmode_par

    local getnest       = tex.getnest
    local getsubtype    = nuts.getsubtype

    function nuts.setparproperty(action,...)
        local tail = tonut(getnest().tail)
        while tail do
            if getid(tail) == localpar_code then
                local s = getsubtype(tail)
                if s == hmodepar_code or s == vmodepar_code then
                    return action(tail,...)
                else
                    -- something is wrong here
                end
            end
            tail = getprev(tail)
        end
    end

    local getsubtype = nodes.getsubtype

    function nodes.start_of_par(n)
        local s = getsubtype(n)
        return s == hmodepar_code or s == vmodepar_code
    end

end

-- Currently only in luametatex ... experimental anyway .. if it doesn't end
-- up in luatex I'll move this to a different module.

do

    local nextnode           = traversers.glue
    local findfail           = nuts.tail

    local getid              = nuts.getid
    local getsubtype         = nuts.getsubtype
    local getlist            = nuts.getlist
    local getwidth           = nuts.getwidth

    local direct             = node.direct

    local nodecodes          = nodes.nodecodes
    local skipcodes          = nodes.skipcodes

    local hlist_code         = nodecodes.hlist
    local line_code          = nodecodes.line

    local leftskip_code      = skipcodes.leftskip
    local rightskip_code     = skipcodes.rightskip
    local lefthangskip_code  = skipcodes.lefthangskip
    local righthangskip_code = skipcodes.righthangskip
    local indentskip_code    = skipcodes.indentskip
    local parfillskip_code   = skipcodes.parfillskip

    local find_node = direct.find_node or function(h,t,s)
        if h then
            if s then
                for node, subtype in traversers[t] do
                    if s == subtype then
                        return current
                    end
                end
            else
                for node, subtype in traversers[t] do
                    return current, subtype
                end
            end
        end
    end

    nuts.find_node = find_node

    nodes.getnormalizeline = nodes.getnormalizeline or function() return 0 end
    nodes.setnormalizeline = nodes.setnormalizeline or function()          end

    nuts.getnormalizedline = direct.getnormalizedline or function(h)
        if getid(h) == hlist_code and getsubtype(h) == line_code then
            local ls, rs = 0, 0
            local lh, rh = 0, 0
            local is, ps = 0, 0
            local h = getlist(h)
            local t = findtail(h)
            for n, subtype in nextglue, h do
                if     subtype == leftskip_code      then ls = getwidth(n)
                elseif subtype == rightskip_code     then rs = getwidth(n)
                elseif subtype == lefthangskip_code  then lh = getwidth(n)
                elseif subtype == righthangskip_code then rh = getwidth(n)
                elseif subtype == indentskip_code    then is = getwidth(n)
                elseif subtype == parfillskip_code   then ps = getwidth(n)
                end
            end
            return ls, rs, lh, rh, is, ps, h, t
        end
    end

end

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
