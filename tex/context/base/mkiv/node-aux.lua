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
local par_code           = nodecodes.par

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
local setattrlist        = nuts.setattrlist

local traversers         = nuts.traversers
local nextnode           = traversers.node
local nextglyph          = traversers.glyph

local flushnode          = nuts.flush
local flushlist          = nuts.flushlist
local hpack_nodes        = nuts.hpack
local unsetattribute     = nuts.unsetattribute
local firstglyph         = nuts.firstglyph
local copy_node          = nuts.copy
local find_tail          = nuts.tail
local getbox             = nuts.getbox
local count              = nuts.count
local isglyph            = nuts.isglyph

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
--         local copy = nodes.copy(box)
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
    flushnode(n)
    return l
end

nuts.takebox = takebox
tex.takebox  = nodes.takebox -- sometimes more clear

-- so far

local function repackhlist(list,...)
    local temp, b = hpack_nodes(list,...)
    list = getlist(temp)
    setlist(temp)
    flushnode(temp)
    return list, b
end

nuts.repackhlist = repackhlist

function nodes.repackhlist(list,...)
    local list, b = repackhlist(tonut(list),...)
    return tonode(list), b
end

if not nuts.setattributes then

    local function setattributes(head,attr,value)
        for n, id in nextnode, head do
            setattr(n,attr,value)
            if id == hlist_node or id == vlist_node then
                setattributes(getlist(n),attr,value)
            end
        end
    end

    nuts .setattributes = setattributes
    nodes.setattributes = vianuts(setattributes)

end

if not nuts.setunsetattributes then

    local function setunsetattributes(head,attr,value)
        for n, id in nextnode, head do
            if not getattr(n,attr) then
                setattr(n,attr,value)
            end
            if id == hlist_code or id == vlist_code then
                setunsetattributes(getlist(n),attr,value)
            end
        end
    end

    nuts .setunsetattributes = setunsetattributes
    nodes.setunsetattributes = vianuts(setunsetattributes)

end

if not nuts.unsetattributes then

    local function unsetattributes(head,attr)
        for n, id in nextnode, head do
            setattr(n,attr,unsetvalue)
            if id == hlist_code or id == vlist_code then
                unsetattributes(getlist(n),attr)
            end
        end
    end

    nuts .unsetattributes = unsetattributes
    nodes.unsetattributes = vianuts(unsetattributes)

end

function nuts.firstcharacter(n,untagged) -- tagged == subtype > 255
    if untagged then
        return firstglyph(n)
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
    flushnode(temp)
    return n
end

nuts.rehpack = rehpack

function nodes.rehpack(n,...)
    rehpack(tonut(n),...)
end

do

    local parcodes      = nodes.parcodes
    local hmodepar_code = parcodes.vmode_par
    local vmodepar_code = parcodes.hmode_par

    local getnest       = tex.getnest
    local getsubtype    = nuts.getsubtype

    function nuts.setparproperty(action,...)
        local tail = tonut(getnest().tail)
        while tail do
            if getid(tail) == par_code then
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

    function nodes.startofpar(n)
        local s = getsubtype(n)
        return s == hmodepar_code or s == vmodepar_code
    end

end

if not nuts.getnormalizedline then

    local nextnode           = traversers.glue
    local findfail           = nuts.tail

    local getid              = nuts.getid
    local getsubtype         = nuts.getsubtype
    local getlist            = nuts.getlist
    local getwidth           = nuts.getwidth

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

    nuts.findnode = node.direct.find_node or function(h,t,s)
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


    function nuts.getnormalizedline(h)
        if getid(h) == hlist_code and getsubtype(h) == line_code then
            local ls, rs = 0, 0
            local lh, rh = 0, 0
            local lp, rp = 0, 0
            local is     = 0
            local h = getlist(h)
            local t = findtail(h)
            for n, subtype in nextglue, h do
                if     subtype == leftskip_code      then ls = getwidth(n)
                elseif subtype == rightskip_code     then rs = getwidth(n)
                elseif subtype == lefthangskip_code  then lh = getwidth(n)
                elseif subtype == righthangskip_code then rh = getwidth(n)
                elseif subtype == indentskip_code    then is = getwidth(n)
                elseif subtype == parfillskip_code   then rp = getwidth(n)
                end
            end
            return {
                leftskip         = ls,
                rightskip        = rs,
                lefthangskip     = lh,
                righthangskip    = rh,
                indent           = is,
                parfillrightskip = rp,
                parfillleftskip  = lp,
                head             = h,
                tail             = t,
            }
        end
    end

end
