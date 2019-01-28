if not modules then modules = { } end modules ['typo-dir'] = {
    version   = 1.001,
    comment   = "companion to typo-dir.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- When we started with this, there were some issues in luatex so we needed to take care of
-- intereferences. Some has been improved but we stil might end up with each node having a
-- dir property. Now, the biggest problem is that there is an official bidi algorithm but
-- some searching on the web shows that there are many confusing aspects and therefore
-- proposals circulate about (sometimes imcompatible ?) improvements. In the end it all boils
-- down to the lack of willingness to tag an input source. Of course tagging of each number
-- and fenced strip is somewhat over the top, but now it has to be captured in logic. Texies
-- normally have no problem with tagging but we need to handle any input. So, what we have
-- done here (over the years) is starting from what we expect to see happen, especially with
-- respect to punctation, numbers and fences. Eventually alternative algorithms will be provides
-- so that users can choose (the reason why suggestion sfor improvements circulate on the web
-- is that it is non trivial to predict the expected behaviour so one hopes that the ditor
-- and the rest of the machinery match somehow. Anyway, the fun of tex is that it has no hard
-- coded behavior. And ... we also want to have more debugging and extras and ... so we want
-- a flexible approach. In the end we will have:
--
-- = full tagging (mechanism turned off)
-- = half tagging (the current implementation)
-- = unicode version x interpretation (several depending on the evolution)

local next, type = next, type
local format, insert, sub, find, match = string.format, table.insert, string.sub, string.find, string.match

local nodes, node = nodes, node

local trace_textdirections  = false  trackers.register("typesetters.directions.text", function(v) trace_textdirections = v end)
local trace_mathdirections  = false  trackers.register("typesetters.directions.math", function(v) trace_mathdirections = v end)
local trace_directions      = false  trackers.register("typesetters.directions",      function(v) trace_textdirections = v trace_mathdirections = v end)

local one_too               = false  directives.register("typesetters.directions.onetoo", function(v) one_too = v end)

local report_textdirections = logs.reporter("typesetting","text directions")
----- report_mathdirections = logs.reporter("typesetting","math directions")

local band                  = bit32.band

local texsetattribute       = tex.setattribute
local unsetvalue            = attributes.unsetvalue

local nuts                  = nodes.nuts
local getnext               = nuts.getnext
local getattr               = nuts.getattr

local enableaction          = nodes.tasks.enableaction
local tracers               = nodes.tracers
local setcolor              = tracers.colors.set
local resetcolor            = tracers.colors.reset

local implement             = interfaces.implement

local directions            = typesetters.directions or { }
typesetters.directions      = directions

local a_directions          = attributes.private('directions')

local variables             = interfaces.variables
local v_global              = variables["global"]
local v_local               = variables["local"]
local v_on                  = variables.on
local v_yes                 = variables.yes

local m_enabled             = 0x00000040 -- 2^6 64
local m_global              = 0x00000080 -- 2^7
local m_fences              = 0x00000100 -- 2^8

local handlers              = { }
local methods               = { }
local lastmethod            = 0

local function installhandler(name,handler)
    local method = methods[name]
    if not method then
        lastmethod    = lastmethod + 1
        method        = lastmethod
        methods[name] = method
    end
    handlers[method] = handler
    return method
end

directions.handlers       = handlers
directions.installhandler = installhandler

local function tomode(specification)
    local scope = specification.scope
    local mode
    if scope == v_global or scope == v_on then
        mode = m_enabled + m_global
    elseif scope == v_local then
        mode = m_enabled
    else
        return 0
    end
    local method = methods[specification.method]
    if method then
        mode = mode + method
    else
        return 0
    end
    if specification.fences == v_yes then
        mode = mode + m_fences
    end
    return mode
end

local function getglobal(a)
    return a and a > 0 and band(a,m_global) ~= 0
end

local function getfences(a)
    return a and a > 0 and band(a,m_fences) ~= 0
end

local function getmethod(a)
    return a and a > 0 and a % m_enabled or 0
end

directions.tomode         = tomode
directions.getglobal      = getglobal
directions.getfences      = getfences
directions.getmethod      = getmethod
directions.installhandler = installhandler

-- beware: in dha we have character properties and in dua|b we have direction properties

function directions.setcolor(current,direction,reversed,mirror)
    if mirror then
        setcolor(current,"bidi:mirrored")
    elseif direction == "l" then
        setcolor(current,reversed and "bidi:left:reversed" or "bidi:left:original")
    elseif direction == "r" then
        setcolor(current,reversed and "bidi:right:reversed" or "bidi:right:original")
    else
        resetcolor(current)
    end
end

implement {
    name      = "getbidimode",
    actions   = { tomode, context },
    arguments = {
        {
            { "scope" },
            { "method" },
            { "fences" },
        }
    }
}

local enabled = false

local starttiming = statistics.starttiming
local stoptiming  = statistics.stoptiming

-- If we have hbox{!} then the hbox determines the direction but we can consider
-- a fast analysis, not that it matters much because there's nothing to swap in
-- the list unless one glyphs becomes multiple (can that really happen?).
--
-- \enabledirectives[typesetters.directions.onetoo]

function directions.handler(head,where,_,_,direction)
    local only_one = not getnext(head)
    if only_one and not one_too then
        return head
    end
    local attr = getattr(head,a_directions)
    if not attr or attr == 0 then
        return head
    end
    local method  = getmethod(attr)
    local handler = handlers[method]
    if not handler then
        return head
    end
    starttiming(directions)
    head = handler(head,direction,only_one,where)
    stoptiming(directions)
    return head
end

statistics.register("text directions", function()
    if enabled then
        return statistics.elapsedseconds(directions)
    end
end)

function directions.set(n) -- todo: names and numbers
    if not enabled then
        if trace_textdirections then
            report_textdirections("enabling directions handler")
        end
        enableaction("processors","typesetters.directions.handler")
        enabled = true
    end
    if not n or n == 0 then
        n = unsetvalue
        -- maybe tracing
    end
    texsetattribute(a_directions,n)
end

implement {
    name      = "setdirection",
    arguments = "integer",
    actions   = directions.set
}
