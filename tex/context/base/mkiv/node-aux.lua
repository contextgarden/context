if not modules then modules = { } end modules ['node-aux'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: n1 .. n2 : __concat metatable

local type, tostring = type, tostring

local nodes, node = nodes, node

local utfvalues          = utf.values

local nodecodes          = nodes.nodecodes

local glyph_code         = nodecodes.glyph
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local attributelist_code = nodecodes.attributelist -- temporary

local nuts               = nodes.nuts
local tonut              = nuts.tonut
local tonode             = nuts.tonode
local vianuts            = nuts.vianuts

local getbox             = nuts.getbox
local getnext            = nuts.getnext
local getid              = nuts.getid
local getsubtype         = nuts.getsubtype
local getlist            = nuts.getlist
local getfont            = nuts.getfont
local getchar            = nuts.getchar
local getattr            = nuts.getattr
local getfield           = nuts.getfield

local setfield           = nuts.setfield
local setattr            = nuts.setattr
local setlink            = nuts.setlink
local setlist            = nuts.setlist
local setnext            = nuts.setnext
local setprev            = nuts.setprev

local traverse_nodes     = nuts.traverse
local traverse_id        = nuts.traverse_id
local flush_node         = nuts.flush
local hpack_nodes        = nuts.hpack
local unset_attribute    = nuts.unset_attribute
local first_glyph        = nuts.first_glyph
local copy_node          = nuts.copy
----- copy_node_list     = nuts.copy_list
local find_tail          = nuts.tail
local insert_node_after  = nuts.insert_after
local getbox             = nuts.getbox

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
        local copy = copy_node(box)
        local list = getlist(box)
        if list then
            setlist(copy,list)
            setlist(box,nil)
        end
        texsetbox(id,nil)
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
    for n in traverse_nodes(head) do
        setattr(n,attr,value)
        local id = getid(n)
        if id == hlist_node or id == vlist_node then
            set_attributes(getlist(n),attr,value)
        end
    end
end

local function set_unset_attributes(head,attr,value)
    for n in traverse_nodes(head) do
        if not getattr(n,attr) then
            setattr(n,attr,value)
        end
        local id = getid(n)
        if id == hlist_code or id == vlist_code then
            set_unset_attributes(getlist(n),attr,value)
        end
    end
end

local function unset_attributes(head,attr)
    for n in traverse_nodes(head) do
        setattr(n,attr,unsetvalue)
        local id = getid(n)
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

-- history:
--
-- local function glyph_width(a)
--     local ch = chardata[getfont(a)][getchar(a)]
--     return (ch and ch.width) or 0
-- end
--
-- local function glyph_total(a)
--     local ch = chardata[getfont(a)][getchar(a)]
--     return (ch and (ch.height+ch.depth)) or 0
-- end
--
-- local function non_discardable(a) -- inline
--     return getid(id) < math_node -- brrrr
-- end
--
-- local function calculate_badness(t,s)
--     if t == 0 then
--         return 0
--     elseif s <= 0 then
--         return INF_BAD
--     else
--         local r
--         if t <= 7230584 then
--             r = t * 297 / s
--         elseif s >= 1663497 then
--             r = t / floor(s / 297)
--         else
--             r = t
--         end
--         r = floor(r)
--         if r > 1290 then
--             return INF_BAD
--         else
--             return floor((r * r * r + 0x20000) / 0x40000) -- 0400000 / 01000000
--         end
--     end
-- end
--
-- left-overs
--
-- local function round_xn_over_d(x, n, d)
--     local positive -- was x >= 0
--     if x >= 0 then
--         positive = true
--     else
--         x = -x
--         positive = false
--     end
--     local t = floor(x % 0x8000) * n              -- 0100000
--     local f = floor(t / 0x8000)                  -- 0100000
--     local u = floor(x / 0x8000) * n + f          -- 0100000
--     local v = floor(u % d) * 0x8000 + f          -- 0100000
--     if floor(u / d) >= 0x8000 then               -- 0100000
--         report_parbuilders('arith_error')
--     else
--         u = 0x8000 * floor(u / d) + floor(v / d) -- 0100000
--     end
--     v = floor(v % d)
--     if 2*v >= d then
--         u = u + 1
--     end
--     if positive then
--         return u
--     else
--         return -u
--     end
-- end
--
-- local function firstline(n)
--     while n do
--         local id = getid(n)
--         if id == hlist_code then
--             if getsubtype(n) == line_code then
--                 return n
--             else
--                 return firstline(getlist(n))
--             end
--         elseif id == vlist_code then
--             return firstline(getlist(n))
--         end
--         n = getnext(n)
--     end
-- end
--
-- nodes.firstline = firstline

function nuts.firstcharacter(n,untagged) -- tagged == subtype > 255
    if untagged then
        return first_glyph(n)
    else
        for g in traverse_id(glyph_code,n) do
            return g
        end
    end
end

local function firstcharinbox(n)
    local l = getlist(getbox(n))
    if l then
        for g in traverse_id(glyph_code,l) do
            return getchar(g)
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
         -- setfield(n,"attr",copy_node_list(attr))
            setfield(n,"attr",attr)
        end
        if head then
            insert_node_after(head,tail,n)
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
    for n in traverse_nodes(start) do
        local id = getid(n)
        if id == wantedid then
            if not wantedsubtype or getsubtype(n) == wantedsubtype then
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
    local size = width or getfield(n,"width")
    local temp = hpack_nodes(head,size,"exactly")
    setfield(n,"width",     size)
    setfield(n,"glue_set",  getfield(temp,"glue_set"))
    setfield(n,"glue_sign", getfield(temp,"glue_sign"))
    setfield(n,"glue_order",getfield(temp,"glue_order"))
    setlist(temp)
    flush_node(temp)
    return n
end

nuts.rehpack = rehpack

function nodes.rehpack(n,...)
    rehpack(tonut(n),...)
end

-- I have no use for this yet:
--
-- \skip0=10pt plus 2pt minus 2pt
-- \cldcontext{"\letterpercent p",tex.stretch_amount(tex.skip[0],1000)} -- 14.30887pt
--
-- local gluespec_code = nodes.nodecodes.gluespec
--
-- function tex.badness_to_ratio(badness)
--     return (badness/100)^(1/3)
-- end
--
-- function tex.stretch_amount(skip,badness) -- node no nut
--     if skip.id == gluespec_code then
--         return skip.width + (badness and (badness/100)^(1/3) or 1) * skip.stretch
--     else
--         return 0
--     end
-- end
