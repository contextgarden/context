if not modules then modules = { } end modules ['node-bck'] = {
    version   = 1.001,
    comment   = "companion to node-bck.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- beware, this one takes quite some runtime, so we need a status flag
-- maybe some page related state

-- todo: done (or just get rid of done altogether) ... saves no purpose
-- any longer

local attributes, nodes, node = attributes, nodes, node

local enableaction       = nodes.tasks.enableaction

local nodecodes          = nodes.nodecodes
local listcodes          = nodes.listcodes

local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist

local alignmentlist_code = listcodes.alignment
local celllist_code      = listcodes.cell

local nuts               = nodes.nuts
local nodepool           = nuts.pool

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getlist            = nuts.getlist
local getattr            = nuts.getattr
local getsubtype         = nuts.getsubtype
local getwhd             = nuts.getwhd
local getwidth           = nuts.getwidth
local getprop            = nuts.getprop

local setattr            = nuts.setattr
local setlink            = nuts.setlink
local setlist            = nuts.setlist
local setattributelist   = nuts.setattributelist
local setprop            = nuts.setprop

local takebox            = nuts.takebox
local findtail           = nuts.tail

local nextnode           = nuts.traversers.node
local nexthlist          = nuts.traversers.hlist
local nextlist           = nuts.traversers.list

local flush_node_list    = nuts.flush_list

local new_rule           = nodepool.rule
local new_kern           = nodepool.kern
local new_hlist          = nodepool.hlist

local privateattributes  = attributes.private
local unsetvalue         = attributes.unsetvalue

local linefillers        = nodes.linefillers

local a_color            = privateattributes("color")
local a_transparency     = privateattributes("transparency")
local a_colormodel       = privateattributes("colormodel")
local a_background       = privateattributes("background")
local a_alignbackground  = privateattributes("alignbackground")
local a_linefiller       = privateattributes("linefiller")
local a_ruled            = privateattributes("ruled")

local trace_alignment    = false
local report_alignment   = logs.reporter("backgrounds","alignment")

trackers.register("backgrounds.alignments",function(v) trace_alignment = v end)

-- We can't use listbuilders with where=alignment because at that stage we have
-- unset boxes. Also, post_linebreak is unsuitable for nested processing as we
-- get the same stuff many times (wrapped again and again).
--
-- After many experiments with different callbacks the shipout is still the best
-- place but then we need to store some settings longer or save them with the node.
-- For color only we can get away with it with an extra attribute flagging a row
-- but for more complex stuff we can better do as we do here now.

local overshoot = math.floor(65781/5) -- could be an option per table (just also store it)

local function colored_a(current,list,template,id)
    local width, height, depth = getwhd(current)
    local total = height + depth
    if width > 0 and total > 0 then
        local rule = nil
        --
        local a = getattr(template,a_linefiller)
        if a then
            local d = linefillers.data[a%1000]
            if d then
                rule = linefillers.filler(template,d,width,height,depth)
            end
        end
        --
        if not rule then
            rule = new_rule(width,height,depth)
        end
        setattributelist(rule,template)
        local back = new_kern(-((id == vlist_code and total) or width))
        return setlink(rule,back,list)
    end
end

local function colored_b(current,list,template,id,indent)
    local width, height, depth = getwhd(current)
    local total = height + depth
    if width > 0 and total > 0 then
        local fore = (indent ~= 0) and new_kern(indent)
        local rule = nil
        --
        local a = getattr(template,a_linefiller)
        if a then
            local d = linefillers.data[a%1000]
            if d then
                rule = linefillers.filler(template,d,width-indent,height,depth)
            end
        end
        --
        if not rule then
            rule = new_rule(width-indent,height+overshoot,depth+overshoot)
            setattributelist(rule,template)
        end
        if overshoot == 0 then
            local back = new_kern(-((id == vlist_code and total) or width))
            return setlink(fore,rule,back,list)
        else
            rule = new_hlist(rule)
            return setlink(fore,rule,list)
        end
    end
end

local templates  = { }
local currentrow = 0
local enabled    = false
local alignments = false

local function add_alignbackgrounds(head,list)
    for current, id, subtype, list in nextlist, list do
        if list and id == hlist_code and subtype == celllist_code then
            for template in nexthlist, list do
                local background = getattr(template,a_alignbackground)
                if background then
                    local list = colored_a(current,list,template)
                    if list then
                        setlist(current,list)
                    end
                    setattr(template,a_alignbackground,unsetvalue) -- or property
                end
                break
            end
        end
    end
    local template = getprop(head,"alignmentchecked")
    if template then
        list = colored_b(head,list,template[1],hlist_code,template[2])
        flush_node_list(template)
        templates[currentrow] = false
        return list
    end
end

local function add_backgrounds(head,id,list)
    if list then
        for current, id, subtype, list in nextlist, list do
            if list then
                if alignments and subtype == alignmentlist_code then
                    local l = add_alignbackgrounds(current,list)
                    if l then
                        list = l
                        setlist(current,list)
                    end
                end
                local l = add_backgrounds(current,id,list)
                if l then
                    list = l
                    setlist(current,l)
                end
            end
        end
    end
    if id == hlist_code or id == vlist_code then
        local background = getattr(head,a_background)
        if background then
            list = colored_a(head,list,head,id)
            -- not needed
            setattr(head,a_background,unsetvalue) -- or property
            return list
        end
    end
end

function nodes.handlers.backgrounds(head)
    add_backgrounds(head,getid(head),getlist(head))
    return head
end

function nodes.handlers.backgroundspage(head,where)
    if head and where == "alignment" then
        for n in nexthlist, head do
            local p = getprop(n,"alignmentchecked")
            if not p and getsubtype(n) == alignmentlist_code then
                currentrow = currentrow + 1
                local template = templates[currentrow]
                if trace_alignment then
                    report_alignment("%03i %s %s",currentrow,"page",template and "+" or "-")
                end
                setprop(n,"alignmentchecked",template)
            end
        end
    end
    return head
end

function nodes.handlers.backgroundsvbox(head,where)
    if head and where == "vbox" then
        local list = getlist(head)
        if list then
            for n in nexthlist, list do
                local p = getprop(n,"alignmentchecked")
                if not p and getsubtype(n) == alignmentlist_code then
                    currentrow = currentrow + 1
                    local template = templates[currentrow]
                    if trace_alignment then
                        report_alignment("%03i %s %s",currentrow,"vbox",template and "+" or "-")
                    end
                    setprop(n,"alignmentchecked",template)
                end
            end
        end
    end
    return head
end

-- interfaces.implement {
--     name      = "enablebackgroundboxes",
--     onlyonce  = true,
--     actions   = enableaction,
--     arguments = { "'shipouts'", "'nodes.handlers.backgrounds'" }
-- }
--
-- doing it in the shipout works as well but this is nicer

local function enable(alignmentstoo)
    if not enabled then
        enabled = true
        enableaction("shipouts","nodes.handlers.backgrounds")
    end
    if not alignments and alignmentstoo then
        alignments = true
        enableaction("vboxbuilders","nodes.handlers.backgroundsvbox")
        enableaction("mvlbuilders", "nodes.handlers.backgroundspage")
    end
end

interfaces.implement {
    name      = "enablebackgroundboxes",
    onlyonce  = true,
    actions   = enable,
}

interfaces.implement {
    name      = "enablebackgroundalign",
    onlyonce  = true,
    actions   = function()
        enable(true)
    end,
}

interfaces.implement {
    name      = "setbackgroundrowdata",
    arguments = { "integer", "integer", "dimension" },
    actions   = function(row,box,indent)
        row = row -1 -- better here than in tex
        if box == 0 then
            templates[row] = false
        else
            templates[row] = { takebox(box), indent }
        end
    end,
}

interfaces.implement {
    name      = "resetbackgroundrowdata",
    actions   = function()
        currentrow = 0
    end,
}
