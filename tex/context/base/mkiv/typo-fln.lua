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
local enableaction       = tasks.enableaction
local disableaction      = tasks.disableaction

local context            = context
local implement          = interfaces.implement

local nuts               = nodes.nuts
local tonode             = nuts.tonode

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getboth            = nuts.getboth
local setboth            = nuts.setboth
local getid              = nuts.getid
local getwidth           = nuts.getwidth
local getlist            = nuts.getlist
local setlist            = nuts.setlist
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local getbox             = nuts.getbox
local getdisc            = nuts.getdisc
local setdisc            = nuts.setdisc
local setlink            = nuts.setlink
local setfont            = nuts.setfont
local setglyphdata       = nuts.setglyphdata
local getprop            = nuts.getprop
local setprop            = nuts.setprop

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local kern_code          = nodecodes.kern
local glue_code          = nodecodes.glue
local localpar_code      = nodecodes.localpar

local spaceskip_code     = nodes.gluecodes.spaceskip

local nextglyph          = nuts.traversers.glyph
local nextdisc           = nuts.traversers.disc

local flush_node_list    = nuts.flush_list
local flush_node         = nuts.flush_node
local copy_node_list     = nuts.copy_list
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local remove_node        = nuts.remove
local getdimensions      = nuts.dimensions
local hpack_node_list    = nuts.hpack
local start_of_par       = nuts.start_of_par

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

local texget             = tex.get

local variables          = interfaces.variables
local v_default          = variables.default
local v_line             = variables.line
local v_word             = variables.word

local function set(par,specification)
    enableaction("processors","typesetters.firstlines.handler")
    if trace_firstlines then
        report_firstlines("enabling firstlines")
    end
    setprop(par,a_firstline,specification)
end

function firstlines.set(specification)
    nuts.setparproperty(set,specification)
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
    local dynamic    = setting.dynamic
    local font       = setting.font
    local noflines   = setting.n or 1
    local ma         = setting.ma or 0
    local ca         = setting.ca
    local ta         = setting.ta
    local hangafter  = texget("hangafter")
    local hangindent = texget("hangindent")
    local parindent  = texget("parindent")
    local nofchars   = 0
    local n          = 0
    local temp       = copy_node_list(head)
    local linebreaks = { }

    set = function(head)
        for g in nextglyph, head do
            if dynamic > 0 then
                setglyphdata(g,dynamic)
            end
            setfont(g,font)
        end
    end

    set(temp)

    for g in nextdisc, temp do
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
        local hsize = texget("hsize") - texget("leftskip",false) - texget("rightskip",false)
        if i == 1 then
            hsize = hsize - parindent
        end
        if i <= - hangafter then
            hsize = hsize - hangindent
        end

        local function list_dimensions(list,start)
            local temp = copy_node_list(list,start)
            temp = nodes.handlers.characters(temp)
            temp = nodes.injections.handler(temp)
         -- temp = typesetters.fontkerns.handler(temp) -- maybe when enabled
         --        nodes.handlers.protectglyphs(temp)  -- not needed as we discard
         -- temp = typesetters.spacings.handler(temp)  -- maybe when enabled
         -- temp = typesetters.kerns.handler(temp)     -- maybe when enabled
            local width = getdimensions(temp)
            return width
        end

        local function try(extra)
            local width = list_dimensions(list,start)
            if extra then
                width = width + list_dimensions(extra)
            end
         -- report_firstlines("line length: %p, progression: %p, text: %s",hsize,width,nodes.listtoutf(list,nil,nil,start))
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
                -- go on
            elseif id == disc_code then
                -- this could be an option
                n = n + 1
                local pre, post, replace = getdisc(start)
                if pre and try(pre) then
                    break
                elseif replace and try(replace) then
                    break
                end
            elseif id == kern_code then -- todo: fontkern
                -- this could be an option
            elseif id == glue_code then
                n = n + 1
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

    flush_node_list(temp)

    local start = head
    local n     = 0

    local function update(start)
        if dynamic > 0 then
            setglyphdata(start,dynamic)
        end
        setfont(start,font)
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
            local ok = false
            if id == glyph_code then
                update(start)
            elseif id == disc_code then
                n = n + 1
                local disc = start
                local pre, post, replace, pretail, posttail, replacetail = getdisc(disc,true)
                if linebreak == n then
                    local p, n = getboth(start)
                    if pre then
                        for current in nextglyph, pre do
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
                        for current in nextglyph, replace do
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
            elseif id == glue_code then
                n = n + 1
                if linebreak ~= n then
                    head = insert_node_before(head,start,newpenalty(10000)) -- nobreak
                end
            end
            local next = getnext(start)
            if linebreak == n then
                if start ~= head then
                    local where = id == glue_code and getprev(start) or start
                    if trace_firstlines then
                        head, where = insert_node_after(head,where,newpenalty(10000)) -- nobreak
                        head, where = insert_node_after(head,where,newkern(-65536))
                        head, where = insert_node_after(head,where,tracerrule(65536,4*65536,2*65536,"darkblue"))
                    end
                    head, where = insert_node_after(head,where,newpenalty(-10000)) -- break
                end
                start = next
                break
            end
            start = next
        end
    end

    return head
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
                setglyphdata(start,dynamic)
            end
            setfont(start,font)
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
    return head
end

actions[v_default] = actions[v_line]

function firstlines.handler(head)
    if getid(head) == localpar_code and start_of_par(head) then
        local settings = getprop(head,a_firstline)
        if settings then
            disableaction("processors","typesetters.firstlines.handler")
            local alternative = settings.alternative or v_default
            local action = actions[alternative] or actions[v_default]
            if action then
                if trace_firstlines then
                    report_firstlines("processing firstlines, alternative %a",alternative)
                end
                return action(head,settings)
            end
        end
    end
    return head
end

-- goodie

local function applytofirstcharacter(box,what)
    local tbox = getbox(box) -- assumes hlist
    local list = getlist(tbox)
    local done = nil
    for n in nextglyph, list do
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
