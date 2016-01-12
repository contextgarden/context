if not modules then modules = { } end modules ['typo-fln'] = {
    version   = 1.001,
    comment   = "companion to typo-fln.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- When I ran into the following experimental code again, I figured that it dated
-- from the early days of mkiv, so I updates it a bit to fit into todays context.
-- In the process I might have messed up things. For instance we had a diffent
-- wrapper then using head and tail.

-- todo: only letters (no punctuation)
-- todo: nuts

local trace_firstlines   = false  trackers.register("typesetters.firstlines", function(v) trace_firstlines = v end)
local report_firstlines  = logs.reporter("nodes","firstlines")

typesetters.firstlines   = typesetters.firstlines or { }
local firstlines         = typesetters.firstlines

local nodes              = nodes
local tasks              = nodes.tasks

local context            = context
local implement          = interfaces.implement

local nuts               = nodes.nuts
local tonut              = nuts.tonut
local tonode             = nuts.tonode

local getnext            = nuts.getnext
local getid              = nuts.getid
local getfield           = nuts.getfield
local setfield           = nuts.setfield
local getlist            = nuts.getlist
local setlist            = nuts.setlist
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local getbox             = nuts.getbox

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local kern_code          = nodecodes.kern

local traverse_id        = nuts.traverse_id
local free_node_list     = nuts.flush_list
local free_node          = nuts.flush_node
local copy_node_list     = nuts.copy_list
local insert_node_after  = nuts.insert_after
local insert_node_before = nuts.insert_before
local hpack_node_list    = nuts.hpack
local remove_node        = nuts.remove

local nodepool           = nuts.pool
local newpenalty         = nodepool.penalty
local newkern            = nodepool.kern
local tracerrule         = nodes.tracers.pool.nuts.rule

local actions            = { }
firstlines.actions       = actions

local a_firstline        = attributes.private('firstline')
local a_color            = attributes.private('color')
local a_transparency     = attributes.private('transparency')
local a_colorspace       = attributes.private('colormodel')

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local variables          = interfaces.variables
local v_default          = variables.default
local v_line             = variables.line
local v_word             = variables.word

----- is_letter          = characters.is_letter
----- categories         = characters.categories

local settings           = nil

function firstlines.set(specification)
    settings = specification or { }
    tasks.enableaction("processors","typesetters.firstlines.handler")
    if trace_firstlines then
        report_firstlines("enabling firstlines")
    end
    texsetattribute(a_firstline,1)
end

implement {
    name      = "setfirstline",
    actions   = firstlines.set,
    arguments = {
        {
            { "alternative" },
            { "font", "integer" },
            { "dynamic", "integer" },
            { "ma", "integer" },
            { "ca", "integer" },
            { "ta", "integer" },
            { "n", "integer" },
        }
    }
}

actions[v_line] = function(head,setting)
 -- local attribute = fonts.specifiers.contextnumber(setting.feature) -- was experimental
    local dynamic    = setting.dynamic
    local font       = setting.font
    local noflines   = setting.n or 1
    local ma         = setting.ma or 0
    local ca         = setting.ca
    local ta         = setting.ta
    local hangafter  = tex.hangafter
    local hangindent = tex.hangindent
    local parindent  = tex.parindent
    local nofchars   = 0
    local n          = 0
    local temp       = copy_node_list(head)
    local linebreaks = { }
    for g in traverse_id(glyph_code,temp) do
        if dynamic > 0 then
            setattr(g,0,dynamic)
        end
        setfield(g,"font",font)
    end
    local start = temp
    local list  = temp
    local prev  = temp
    for i=1,noflines do
        local hsize = tex.hsize - tex.leftskip.width - tex.rightskip.width
        if i == 1 then
            hsize = hsize - parindent
        end
        if i <= - hangafter then
            hsize = hsize - hangindent
        end
        while start do
            local id = getid(start)
            if id == glyph_code then
                n = n + 1
            elseif id == disc_code then
                -- this could be an option
            elseif id == kern_code then -- todo: fontkern
                -- this could be an option
            elseif n > 0 then
                local pack = hpack_node_list(copy_node_list(list,start))
                if getfield(pack,"width") > hsize then
                    free_node_list(pack)
                    list = prev
                    break
                else
                    linebreaks[i] = n
                    prev = start
                    free_node_list(pack)
                    nofchars = n
                end
            end
            start = getnext(start)
        end
        if not linebreaks[i] then
            linebreaks[i] = n
        end
    end
    local start = head
    local n     = 0
    for i=1,noflines do
        local linebreak = linebreaks[i]
        while start and n < nofchars do
            local id = getid(start)
            if id == glyph_code then -- or id == disc_code then
                if dynamic > 0 then
                    setattr(start,0,dynamic)
                end
                setfield(start,"font",font)
                if ca and ca > 0 then
                    setattr(start,a_colorspace,ma == 0 and 1 or ma)
                    setattr(start,a_color,ca)
                end
                if ta and ta > 0 then
                    setattr(start,a_transparency,ta)
                end
                n = n + 1
            end
            if linebreak == n then
                if trace_firstlines then
                    head, start = insert_node_after(head,start,newpenalty(10000)) -- nobreak
                    head, start = insert_node_after(head,start,newkern(-65536))
                    head, start = insert_node_after(head,start,tracerrule(65536,4*65536,2*65536,"darkblue"))
                end
                head, start = insert_node_after(head,start,newpenalty(-10000)) -- break
                break
            end
            start = getnext(start)
        end
    end
    free_node_list(temp)
    return head, true
end

actions[v_word] = function(head,setting)
 -- local attribute = fonts.specifiers.contextnumber(setting.feature) -- was experimental
    local dynamic  = setting.dynamic
    local font     = setting.font
    local words    = 0
    local nofwords = setting.n or 1
    local start    = head
    local ok       = false
    local ma       = setting.ma or 0
    local ca       = setting.ca
    local ta       = setting.ta
    while start do
        local id = getid(start)
        -- todo: delete disc nodes
        if id == glyph_code then
            if not ok then
                words = words + 1
                ok = true
            end
            if ca and ca > 0 then
                setattr(start,a_colorspace,ma == 0 and 1 or ma)
                setattr(start,a_color,ca)
            end
            if ta and ta > 0 then
                setattr(start,a_transparency,ta)
            end
            if dynamic > 0 then
                setattr(start,0,dynamic)
            end
            setfield(start,"font",font)
        elseif id == disc_code then
            -- continue
        elseif id == kern_code then -- todo: fontkern
            -- continue
        else
            ok = false
            if words == nofwords then
                break
            end
        end
        start = getnext(start)
    end
    return head, true
end

actions[v_default] = actions[v_line]

function firstlines.handler(head)
    head = tonut(head)
    local start = head
    local attr  = nil
    while start do
        attr = getattr(start,a_firstline)
        if attr then
            break
        elseif getid(start) == glyph_code then
            break
        else
            start = getnext(start)
        end
    end
    if attr then
        -- here as we can process nested boxes first so we need to keep state
        tasks.disableaction("processors","typesetters.firstlines.handler")
     -- texsetattribute(attribute,unsetvalue)
        local alternative = settings.alternative or v_default
        local action = actions[alternative] or actions[v_default]
        if action then
            if trace_firstlines then
                report_firstlines("processing firstlines, alternative %a",alternative)
            end
            local head, done = action(head,settings)
            return tonode(head), done
        end
    end
    return tonode(head), false
end

-- goodie

local function applytofirstcharacter(box,what)
    local tbox = getbox(box) -- assumes hlist
    local list = getlist(tbox)
    local done = nil
    for n in traverse_id(glyph_code,list) do
        list = remove_node(list,n)
        done = n
        break
    end
    if done then
        setlist(tbox,list)
        local kind = type(what)
        if kind == "string" then
            context[what](tonode(done))
        elseif kind == "function" then
            what(done)
        else
            -- error
        end
    end
end

implement {
    name      = "applytofirstcharacter",
    actions   = applytofirstcharacter,
    arguments = { "integer", "string" }
}
