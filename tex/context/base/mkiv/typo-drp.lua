if not modules then modules = { } end modules ['typo-drp'] = {
    version   = 1.001,
    comment   = "companion to typo-drp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This one is sensitive for order (e.g. when combined with first line
-- processing.

-- todo: use isglyph

local tonumber, type, next = tonumber, type, next
local ceil = math.ceil
local settings_to_hash = utilities.parsers.settings_to_hash

local trace_initials    = false  trackers.register("typesetters.initials", function(v) trace_initials = v end)
local report_initials   = logs.reporter("nodes","initials")

local initials          = typesetters.paragraphs or { }
typesetters.initials    = initials or { }

local nodes             = nodes

local tasks             = nodes.tasks
local enableaction      = tasks.enableaction
local disableaction     = tasks.disableaction

local nuts              = nodes.nuts
local tonut             = nodes.tonut

local getnext           = nuts.getnext
local getprev           = nuts.getprev
local getchar           = nuts.getchar
local getid             = nuts.getid
local getattr           = nuts.getattr
local getwhd            = nuts.getwhd

local getprop           = nuts.getprop
local setprop           = nuts.setprop

local setattr           = nuts.setattr
local setlink           = nuts.setlink
local setprev           = nuts.setprev
local setnext           = nuts.setnext
local setfont           = nuts.setfont
local setchar           = nuts.setchar
local setwhd            = nuts.setwhd
local setkern           = nuts.setkern
local setoffsets        = nuts.setoffsets
local setglyphdata      = nuts.setglyphdata
local setattr           = nuts.setattr

local hpack_nodes       = nuts.hpack

local nodecodes         = nodes.nodecodes

local nodepool          = nuts.pool
local new_kern          = nodepool.kern

local insert_before     = nuts.insert_before
local insert_after      = nuts.insert_after
local remove_node       = nuts.remove
local start_of_par      = nuts.start_of_par

local nextnode          = nuts.traversers.node
local nextglyph         = nuts.traversers.glyph

local variables         = interfaces.variables
local v_default         = variables.default
local v_margin          = variables.margin
local v_auto            = variables.auto
local v_first           = variables.first
local v_last            = variables.last

local texget            = tex.get
local texset            = tex.set
local unsetvalue        = attributes.unsetvalue

local glyph_code        = nodecodes.glyph
local hlist_code        = nodecodes.hlist
local glue_code         = nodecodes.glue
local kern_code         = nodecodes.kern
local localpar_code     = nodecodes.localpar

local actions           = { }
initials.actions        = actions

local a_initial         = attributes.private("initial")
local a_color           = attributes.private('color')
local a_transparency    = attributes.private('transparency')
local a_colormodel      = attributes.private('colormodel')

local category          = characters.category

local function set(par,specification)
    enableaction("processors","typesetters.initials.handler")
    if trace_initials then
        report_initials("enabling initials")
    end
    setprop(par,a_initial,specification)
end

function initials.set(specification)
    nuts.setparproperty(set,specification)
end

interfaces.implement {
    name      = "setinitial",
    actions   = initials.set,
    arguments = {
        {
            { "location" },
            { "enabled", "boolean" },
            { "method" },
            { "distance" ,"dimen" },
            { "hoffset" ,"dimen" },
            { "voffset" ,"dimen" },
            { "font", "integer" },
            { "dynamic", "integer" },
            { "ca", "integer" },
            { "ma", "integer" },
            { "ta", "integer" },
            { "n", "integer" },
            { "m", "integer" },
        }
    }
}

-- todo: prevent linebreak .. but normally a initial ends up at the top of
-- a page so this has a low priority

actions[v_default] = function(head,setting)
    -- begin of par
    local first  = getnext(head)
    local indent = false
    -- parbox .. needs to be set at 0
    if first and getid(first) == hlist_code then
        first  = getnext(first)
        indent = true
    end
    -- we need to skip over kerns and glues (signals)
    while first and getid(first) ~= glyph_code do
        first = getnext(first)
    end
    if first and getid(first) == glyph_code then
        local ma        = setting.ma or 0
        local ca        = setting.ca
        local ta        = setting.ta
        local last      = first
        local distance  = setting.distance or 0
        local voffset   = setting.voffset or 0
        local hoffset   = setting.hoffset or 0
        local parindent = texget("parindent")
        local baseline  = texget("baselineskip",false)
        local lines     = tonumber(setting.n) or 0
        local dynamic   = setting.dynamic
        local font      = setting.font
        local method    = settings_to_hash(setting.method)
        local length    = tonumber(setting.m) or 1
        --
        -- 1 char | n chars | skip first quote | ignore punct | keep punct
        --
        if getattr(first,a_initial) then
            for current in nextnode, getnext(first) do
                if getattr(current,a_initial) then
                    last = current
                else
                    break
                end
            end
        elseif method[v_auto] then
            local char = getchar(first)
            local kind = category(char)
            if kind == "po" or kind == "pi" then
                if method[v_first] then
                    -- remove quote etc before initial
                    local next = getnext(first)
                    if not next then
                        -- don't start with a quote or so
                        return head
                    end
                    last = nil
                    for current in nextglyph, next do
                        head, first = remove_node(head,first,true)
                        first = current
                        last = first
                        break
                    end
                    if not last then
                        -- no following glyph or so
                        return head
                    end
                else
                    -- keep quote etc with initial
                    local next = getnext(first)
                    if not next then
                        -- don't start with a quote or so
                        return head
                    end
                    for current in nextglyph, next do
                        last = current
                        break
                    end
                    if last == first then
                        return head
                    end
                end
            elseif kind == "pf" then
                -- error: final quote
            else
                -- okay
            end
            -- maybe also: get all A. B. etc
            local next = getnext(first)
            if next then
                for current, char in nextglyph, next do
                    local kind = category(char)
                    if kind == "po" then
                        if method[v_last] then
                            -- remove period etc after initial
                            remove_node(head,current,true)
                        else
                            -- keep period etc with initial
                            last = current
                        end
                    end
                    break
                end
            end
        else
            for current in nextglyph, first do
                last = current
                if length <= 1 then
                    break
                else
                    length = length - 1
                end
            end
        end
        local current = first
        while true do
            local id = getid(current)
            if id == kern_code then
                setkern(current,0)
            elseif id == glyph_code then
                local next = getnext(current)
                if font then
                    setfont(current,font)
                end
                if dynamic > 0 then
                    setglyphdata(current,dynamic)
                end
                -- can be a helper
                if ca and ca > 0 then
                    setattr(current,a_colormodel,ma == 0 and 1 or ma)
                    setattr(current,a_color,ca)
                end
                if ta and ta > 0 then
                    setattr(current,a_transparency,ta)
                end
                --
            end
            if current == last then
                break
            else
                current = getnext(current)
            end
        end
        -- We pack so that successive handling cannot touch the dropped cap. Packaging
        -- in a hlist is also needed because we cannot locally adapt e.g. parindent (not
        -- yet stored in with localpar).
        local prev = getprev(first)
        local next = getnext(last)
        --
        setprev(first)
        setnext(last)
        local dropper = hpack_nodes(first)
        local width, height, depth = getwhd(dropper)
        setwhd(dropper,0,0,0)
        --
        setlink(prev,dropper)
        setlink(dropper,next)
        --
        if next then
            local current = next
            while current do
                local id = getid(current)
                if id == glue_code or id == kern_code then
                    local next = getnext(current)
                 -- remove_node(current,current,true) -- created an invalid next link and dangling remains
                    remove_node(head,current,true)
                    current = next
                else
                    break
                end
            end
        end
        --
        local hoffset = width + hoffset + distance + (indent and parindent or 0)
        for current in nextglyph, first do
            setoffsets(current,-hoffset,-voffset) -- no longer - height here
            if current == last then
                break
            end
        end
        --
        first = dropper
        --
        if setting.location == v_margin then
            -- okay
        else
            if lines == 0 then -- safeguard, not too precise
                lines = ceil((height+voffset) / baseline)
            end
            -- We cannot set parshape yet ... when we can I'll add a slope
            -- option (positive and negative, in emwidth).
            local hangafter  = - lines
            local hangindent = width + distance
            if trace_initials then
                report_initials("setting hangafter to %i and hangindent to %p",hangafter,hangindent)
            end
            texset("hangafter",hangafter)
            texset("hangindent",hangindent)
        end
        if indent then
            insert_after(first,first,new_kern(-parindent))
        end
    end
    return head
end

-- we can count ... when all done, we can disable ...

function initials.handler(head)
    if getid(head) == localpar_code and start_of_par(head) then
        local settings = getprop(head,a_initial)
        if settings then
            disableaction("processors","typesetters.initials.handler")
            local alternative = settings.alternative or v_default
            local action = actions[alternative] or actions[v_default]
            if action then
                if trace_initials then
                    report_initials("processing initials, alternative %a",alternative)
                end
                return action(head,settings)
            end
        end
    end
    return head
end
