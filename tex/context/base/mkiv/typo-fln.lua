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
local getprev            = nuts.getprev
local getboth            = nuts.getboth
local setboth            = nuts.setboth
local getid              = nuts.getid
local getfield           = nuts.getfield
local setfield           = nuts.setfield
local getlist            = nuts.getlist
local setlist            = nuts.setlist
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local getbox             = nuts.getbox
local getdisc            = nuts.getdisc
local setdisc            = nuts.setdisc
local setlink            = nuts.setlink

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local kern_code          = nodecodes.kern

local traverse_id        = nuts.traverse_id
local flush_node_list    = nuts.flush_list
local flush_node         = nuts.flush_node
local copy_node_list     = nuts.copy_list
local insert_node_after  = nuts.insert_after
local remove_node        = nuts.remove
local list_dimensions    = nuts.dimensions

local nodepool           = nuts.pool
local newpenalty         = nodepool.penalty
local newkern            = nodepool.kern
local tracerrule         = nodes.tracers.pool.nuts.rule

local actions            = { }
firstlines.actions       = actions

local a_firstline        = attributes.private('firstline')
local a_color            = attributes.private('color')
local a_transparency     = attributes.private('transparency')
local a_colormodel       = attributes.private('colormodel')

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

    local function set(head)
        for g in traverse_id(glyph_code,head) do
            if dynamic > 0 then
                setattr(g,0,dynamic)
            end
            setfield(g,"font",font)
        end
    end

    set(temp)

    for g in traverse_id(disc_code,temp) do
        local pre, post, replace = getdisc(g)
        if pre then
            set(pre)
        end
        if post then
            set(post)
        end
        if replace then
            set(replace)
        end
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

        local function try(extra)
            local width = list_dimensions(list,start)
            if extra then
                width = width + list_dimensions(extra)
            end
            if width > hsize then
                list = prev
                return true
            else
                linebreaks[i] = n
                prev = start
                nofchars = n
            end
        end

        while start do
            local id = getid(start)
            if id == glyph_code then
                n = n + 1
            elseif id == disc_code then
                -- this could be an option
                n = n + 1
                if try(getfield(start,"pre")) then
                    break
                end
            elseif id == kern_code then -- todo: fontkern
                -- this could be an option
            elseif n > 0 then
                if try() then
                    break
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

    local function update(start)
        if dynamic > 0 then
            setattr(start,0,dynamic)
        end
        setfield(start,"font",font)
        if ca and ca > 0 then
            setattr(start,a_colormodel,ma == 0 and 1 or ma)
            setattr(start,a_color,ca)
        end
        if ta and ta > 0 then
            setattr(start,a_transparency,ta)
        end
    end

    for i=1,noflines do
        local linebreak = linebreaks[i]
        while start and n < nofchars do
            local id = getid(start)
            if id == glyph_code then
                n = n + 1
                update(start)
            elseif id == disc_code then
                n = n + 1
                local disc = start
                local pre, post, replace, pretail, posttail, replacetail = getdisc(disc,true)
                if linebreak == n then
                    local p, n = getboth(start)
                    if pre then
                        for current in traverse_id(glyph_code,pre) do
                            update(current)
                        end
                        setlink(pretail,n)
                        setlink(p,pre)
                        start = pretail
                        pre = nil
                    else
                        setlink(p,n)
                        start = p
                    end
                    if post then
                        local p, n = getboth(start)
                        setlink(posttail,n)
                        setlink(start,post)
                        post = nil
                    end
                else
                    local p, n = getboth(start)
                    if replace then
                        for current in traverse_id(glyph_code,replace) do
                            update(current)
                        end
                        setlink(replacetail,n)
                        setlink(p,replace)
                        start = replacetail
                        replace = nil
                    else
                        setlink(p,n)
                        start = p
                    end
                end
                setdisc(disc,pre,post,replace)
                flush_node(disc)
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
    flush_node_list(temp)
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
                setattr(start,a_colormodel,ma == 0 and 1 or ma)
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
