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

local enableaction      = nodes.tasks.enableaction

local nodecodes         = nodes.nodecodes
local listcodes         = nodes.listcodes

local hlist_code        = nodecodes.hlist
local vlist_code        = nodecodes.vlist
local alignment_code    = listcodes.alignment
local cell_code         = listcodes.cell

local nuts              = nodes.nuts
local nodepool          = nuts.pool

local tonode            = nuts.tonode
local tonut             = nuts.tonut

local getnext           = nuts.getnext
local getprev           = nuts.getprev
local getid             = nuts.getid
local getlist           = nuts.getlist
local getattr           = nuts.getattr
local getsubtype        = nuts.getsubtype
local getwhd            = nuts.getwhd
local getwidth          = nuts.getwidth

local setattr           = nuts.setattr
local setlink           = nuts.setlink
local setlist           = nuts.setlist
local setattributelist  = nuts.setattributelist

local takebox           = nuts.takebox
local findtail          = nuts.tail

local traverse          = nuts.traverse
local traverse_id       = nuts.traverse_id

local flush_node_list   = nuts.flush_list

local new_rule          = nodepool.rule
local new_kern          = nodepool.kern

local privateattributes = attributes.private

local linefillers       = nodes.linefillers

local a_color           = privateattributes("color")
local a_transparency    = privateattributes("transparency")
local a_colormodel      = privateattributes("colormodel")
local a_background      = privateattributes("background")
local a_alignbackground = privateattributes("alignbackground")
local a_linefiller      = privateattributes("linefiller")
local a_ruled           = privateattributes("ruled")

-- actually we can be more clever now: we can store cells and row data
-- and apply it

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
        local back = new_kern(-((id == vlist_code and total) or width))
        setattributelist(rule,template)
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
            rule = new_rule(width-indent,height,depth)
            setattributelist(rule,template)
        end
        local back = new_kern(-((id == vlist_code and total) or width))
        return setlink(fore,rule,back,list)
    end
end

local function add_backgrounds(head)
    for current, id in traverse(head) do
        if id == hlist_code or id == vlist_code then
            local list = getlist(current)
            if list then
                local head = add_backgrounds(list)
                if head then
                    setlist(current,head)
                    list = head
                end
            end
            local background = getattr(current,a_background)
            if background then
                local list = colored_a(current,list,current,id)
                if list then
                    setlist(current,list)
                end
            end
        end
    end
    return head, true
end

-- We use a fake hlist with proper attributes.

local templates  = { }
local currentrow = 0

local function add_alignbackgrounds(head)
    for current in traverse_id(hlist_code,head) do -- what is valign?
        if getsubtype(current) == alignment_code then
            local list = getlist(current)
            if list then
                for current in traverse_id(hlist_code,list) do
                    if getsubtype(current) == cell_code then
                        local list = getlist(current)
                        if list then
                            for template in traverse_id(hlist_code,list) do
                                local background = getattr(template,a_alignbackground)
                                if background then
                                    local list = colored_a(current,list,template)
                                    if list then
                                        setlist(current,list)
                                    end
                                end
                                break
                            end
                        end
                    end
                end
            end
            currentrow = currentrow + 1
            local template = templates[currentrow]
            if template then
                local list = colored_b(current,list,template[1],hlist_code,template[2])
                if list then
                    setlist(current,list)
                end
                flush_node_list(template)
                templates[currentrow] = false
            end
        end
    end
    return head, true
end

function nodes.handlers.backgrounds(head,where)
    local head, done = add_backgrounds(tonut(head))
    return tonode(head), done
end

function nodes.handlers.alignbackgrounds(head,where)
    if where == "alignment" and head then
        local head, done = add_alignbackgrounds(tonut(head))
        return tonode(head), done
    else
        return head, false
    end
end

-- interfaces.implement {
--     name      = "enablebackgroundboxes",
--     onlyonce  = true,
--     actions   = enableaction,
--     arguments = { "'shipouts'", "'nodes.handlers.backgrounds'" }
-- }
--
-- doing it in the shipout works as well but this is nicer

interfaces.implement {
    name      = "enablebackgroundboxes",
    onlyonce  = true,
    actions   = function()
        enableaction("mvlbuilders", "nodes.handlers.backgrounds")
        enableaction("vboxbuilders","nodes.handlers.backgrounds")
    end,
}

interfaces.implement {
    name      = "enablebackgroundalign",
    onlyonce  = true,
    actions   = function()
        enableaction("mvlbuilders", "nodes.handlers.alignbackgrounds")
        enableaction("vboxbuilders","nodes.handlers.alignbackgrounds")
    end,
}

interfaces.implement {
    name      = "setbackgroundrowdata",
    arguments = { "integer", "integer", "dimension" },
    actions   = function(row,box,indent)
        templates[row] = { takebox(box), indent }
    end,
}

interfaces.implement {
    name      = "resetbackgroundrowdata",
    actions   = function()
        currentrow = 0
    end,
}
