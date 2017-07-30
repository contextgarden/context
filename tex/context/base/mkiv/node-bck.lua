if not modules then modules = { } end modules ['node-bck'] = {
    version   = 1.001,
    comment   = "companion to node-bck.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- beware, this one takes quite some runtime, so we need a status flag
-- maybe some page related state

local attributes, nodes, node = attributes, nodes, node

local enableaction      = nodes.tasks.enableaction

local nodecodes         = nodes.nodecodes
local listcodes         = nodes.listcodes

local hlist_code        = nodecodes.hlist
local vlist_code        = nodecodes.vlist
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

local setattr           = nuts.setattr
local setlink           = nuts.setlink
local setlist           = nuts.setlist

local traverse          = nuts.traverse
local traverse_id       = nuts.traverse_id

local new_rule          = nodepool.rule
local new_glue          = nodepool.glue

local a_color           = attributes.private('color')
local a_transparency    = attributes.private('transparency')
local a_colormodel      = attributes.private('colormodel')
local a_background      = attributes.private('background')
local a_alignbackground = attributes.private('alignbackground')

local function add_backgrounds(head) -- rather old code .. to be redone
    local current = head
    while current do
        local id = getid(current)
        if id == hlist_code or id == vlist_code then
            local list = getlist(current)
            if list then
                local head = add_backgrounds(list)
                if head then
                    setlist(current,head)
                    list = head
                end
            end
            local width, height, depth = getwhd(current)
            if width > 0 then
                local background = getattr(current,a_background)
                if background then
                    -- direct to hbox
                    -- colorspace is already set so we can omit that and stick to color
                    local mode = getattr(current,a_colormodel)
                    if mode then
                        local skip = id == hlist_code and width or (height + depth)
                        local glue = new_glue(-skip)
                        local rule = new_rule(width,height,depth)
                        local color = getattr(current,a_color)
                        local transparency = getattr(current,a_transparency)
                        setattr(rule,a_colormodel,mode)
                        if color then
                            setattr(rule,a_color,color)
                        end
                        if transparency then
                            setattr(rule,a_transparency,transparency)
                        end
--                         setlink(rule,glue)
--                         if list then
--                             setlink(glue,list)
--                         end
--                         setlist(current,rule)
                        setlist(current,rule,glue,list)
                    end
                end
            end
        end
        current = getnext(current)
    end
    return head, true
end

local function add_alignbackgrounds(head)
    local current = head
    while current do
        local id = getid(current)
        if id == hlist_code then
            local list = getlist(current)
            if not list then
                -- no need to look
            elseif getsubtype(current) == cell_code then
                local background = nil
                local found = nil
             -- for l in traverse(list) do
             --     background = getattr(l,a_alignbackground)
             --     if background then
             --         found = l
             --         break
             --     end
             -- end
                -- we know that it's a fake hlist (could be user node)
                -- but we cannot store tables in user nodes yet
                for l in traverse_id(hpack_code,list) do
                    background = getattr(l,a_alignbackground)
                    if background then
                        found = l
                    end
                    break
                end
                --
                if background then
                    -- current has subtype 5 (cell)
                    local width, height, depth = getwhd(current)
                    if width > 0 then
                        local mode = getattr(found,a_colormodel)
                        if mode then
                            local glue = new_glue(-width)
                            local rule = new_rule(width,height,depth)
                            local color = getattr(found,a_color)
                            local transparency = getattr(found,a_transparency)
                            setattr(rule,a_colormodel,mode)
                            if color then
                                setattr(rule,a_color,color)
                            end
                            if transparency then
                                setattr(rule,a_transparency,transparency)
                            end
                            setlink(rule,glue)
                            if list then
                                setlink(glue,list)
                            end
                            setlist(current,rule)
                        end
                    end
                end
            else
                add_alignbackgrounds(list)
            end
        elseif id == vlist_code then
            local list = getlist(current)
            if list then
                add_alignbackgrounds(list)
            end
        end
        current = getnext(current)
    end
    return head, true
end

-- nodes.handlers.backgrounds      = add_backgrounds
-- nodes.handlers.alignbackgrounds = add_alignbackgrounds

nodes.handlers.backgrounds      = function(head) local head, done = add_backgrounds     (tonut(head)) return tonode(head), done end
nodes.handlers.alignbackgrounds = function(head) local head, done = add_alignbackgrounds(tonut(head)) return tonode(head), done end

interfaces.implement {
    name      = "enablebackgroundboxes",
    onlyonce  = true,
    actions   = enableaction,
    arguments = { "'shipouts'", "'nodes.handlers.backgrounds'" }
}

interfaces.implement {
    name      = "enablebackgroundalign",
    onlyonce  = true,
    actions   = enableaction,
    arguments = { "'shipouts'", "'nodes.handlers.alignbackgrounds'" }
}
