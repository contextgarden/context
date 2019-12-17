if not modules then modules = { } end modules ['attr-lay'] = {
    version   = 1.001,
    comment   = "companion to attr-lay.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- layers (ugly code, due to no grouping and such); currently we use exclusive layers
-- but when we need it stacked layers might show up too; the next function based
-- approach can be replaced by static (metatable driven) resolvers

-- maybe use backends.registrations here too

local type = type
local insert, remove = table.insert, table.remove

local attributes          = attributes
local nodes               = nodes
local utilities           = utilities
local logs                = logs
local backends            = backends

local context             = context
local interfaces          = interfaces
local tex                 = tex

local implement           = interfaces.implement

local allocate            = utilities.storage.allocate
local setmetatableindex   = table.setmetatableindex
local formatters          = string.formatters

local report_viewerlayers = logs.reporter("viewerlayers")

-- todo: document this but first reimplement this as it reflects the early
-- days of luatex / mkiv and we have better ways now

-- nb: attributes: color etc is much slower than normal (marks + literals) but ...
-- nb. too many "0 g"s
-- nb: more local tables

attributes.viewerlayers = attributes.viewerlayers or { }
local viewerlayers      = attributes.viewerlayers

local variables         = interfaces.variables
local v_local           = variables["local"]
local v_global          = variables["global"]
local v_start           = variables["start"]
local v_yes             = variables["yes"]

local a_viewerlayer     = attributes.private("viewerlayer")

viewerlayers            = viewerlayers            or { }
viewerlayers.data       = allocate()
viewerlayers.registered = viewerlayers.registered or { }
viewerlayers.values     = viewerlayers.values     or { }
viewerlayers.scopes     = viewerlayers.scopes     or { }
viewerlayers.listwise   = allocate()
viewerlayers.attribute  = a_viewerlayer
viewerlayers.supported  = true
viewerlayers.hasorder   = true

local states            = attributes.states
local enableaction      = nodes.tasks.enableaction
local disableaction     = nodes.tasks.disableaction
local nodeinjections    = backends.nodeinjections
local codeinjections    = backends.codeinjections

local texsetattribute   = tex.setattribute
local texgetattribute   = tex.getattribute
local texsettokenlist   = tex.settoks
local unsetvalue        = attributes.unsetvalue

local data              = viewerlayers.data
local values            = viewerlayers.values
local listwise          = viewerlayers.listwise
local registered        = viewerlayers.registered
local scopes            = viewerlayers.scopes

local f_stamp           = formatters["%s"]

storage.register("attributes/viewerlayers/registered", registered, "attributes.viewerlayers.registered")
storage.register("attributes/viewerlayers/values",     values,     "attributes.viewerlayers.values")
storage.register("attributes/viewerlayers/scopes",     scopes,     "attributes.viewerlayers.scopes")

local layerstacker = utilities.stacker.new("layers") -- experiment

layerstacker.mode  = "stack"
layerstacker.unset = attributes.unsetvalue

viewerlayers.resolve_reset = layerstacker.resolve_reset
viewerlayers.resolve_begin = layerstacker.resolve_begin
viewerlayers.resolve_step  = layerstacker.resolve_step
viewerlayers.resolve_end   = layerstacker.resolve_end

-- stacked

local function startlayer(...) startlayer = nodeinjections.startlayer return startlayer(...) end
local function stoplayer (...) stoplayer  = nodeinjections.stoplayer  return stoplayer (...) end

local function extender(viewerlayers,key)
    if viewerlayers.supported and key == "none" then
        local d = stoplayer()
        viewerlayers.none = d
        return d
    end
end

local function reviver(data,n)
    if viewerlayers.supported then
        local v = values[n]
        if v then
            local d = startlayer(v)
            data[n] = d
            return d
        else
            report_viewerlayers("error: unknown reference %a",tostring(n))
        end
    end
end

setmetatableindex(viewerlayers,extender)
setmetatableindex(viewerlayers.data,reviver)

--  !!!! TEST CODE !!!!

layerstacker.start  = function(...) local f = nodeinjections.startstackedlayer  layerstacker.start  = f return f(...) end
layerstacker.stop   = function(...) local f = nodeinjections.stopstackedlayer   layerstacker.stop   = f return f(...) end
layerstacker.change = function(...) local f = nodeinjections.changestackedlayer layerstacker.change = f return f(...) end

local function initializer(...)
    return states.initialize(...)
end

attributes.viewerlayers.handler = nodes.installattributehandler {
    name        = "viewerlayer",
    namespace   = viewerlayers,
    initializer = initializer,
    finalizer   = states.finalize,
    processor   = states.stacker,
 -- processor   = states.stacked,
}

local stack, enabled, global = { }, false, false

function viewerlayers.enable(value)
    if value == false or not viewerlayers.supported then
        if enabled then
            disableaction("shipouts","attributes.viewerlayers.handler")
        end
        enabled = false
    else
        if not enabled then
            enableaction("shipouts","attributes.viewerlayers.handler")
        end
        enabled = true
    end
end

function viewerlayers.forcesupport(value)
    viewerlayers.supported = value
    report_viewerlayers("viewerlayers are %ssupported",value and "" or "not ")
    viewerlayers.enable(value)
end

local function register(name,lw) -- if not inimode redefine data[n] in first call
    if not enabled then
        viewerlayers.enable(true)
    end
    local stamp = f_stamp(name)
    local n = registered[stamp]
    if not n then
        n = #values + 1
        values[n] = name
        registered[stamp] = n
        listwise[n] = lw or false -- lw forces a used
    end
    return registered[stamp] -- == n
end

viewerlayers.register = register

function viewerlayers.setfeatures(hasorder)
    viewerlayers.hasorder = hasorder
end

local usestacker = true -- new, experimental

function viewerlayers.start(name)
    local a
    if usestacker then
        a = layerstacker.push(register(name) or unsetvalue)
    else
        insert(stack,texgetattribute(a_viewerlayer))
        a = register(name) or unsetvalue
    end
    if global or scopes[name] == v_global then
        scopes[a] = v_global -- messy but we don't know the attributes yet
        texsetattribute("global",a_viewerlayer,a)
    else
        texsetattribute(a_viewerlayer,a)
    end
    -- or macro
    texsettokenlist("currentviewerlayertoks",name)
end

function viewerlayers.stop()
    local a
    if usestacker then
        a = layerstacker.pop()
    else
        a = remove(stack)
    end
    if not a then
        -- error
    elseif a >= 0 then
        if global or scopes[a] == v_global then
            texsetattribute("global",a_viewerlayer,a)
        else
            texsetattribute(a_viewerlayer,a)
        end
        texsettokenlist("currentviewerlayertoks",values[a] or "")
    else
        if global or scopes[a] == v_global then
            texsetattribute("global",a_viewerlayer,unsetvalue)
        else
            texsetattribute(a_viewerlayer,unsetvalue)
        end
        texsettokenlist("currentviewerlayertoks","")
    end
end

function viewerlayers.define(settings)
    local tag = settings.tag
    if not tag or tag == "" then
        -- error
    elseif not scopes[tag] then -- prevent duplicates
        local title = settings.title
        if not title or title == "" then
            settings.title = tag
        end
        scopes[tag] = settings.scope or v_local
        codeinjections.defineviewerlayer(settings)
    end
end

function viewerlayers.definedlayoutcomponent(tag)
    viewerlayers.define {
        tag       = tag,
        title     = utilities.strings.nice(tag),
        visible   = v_start,
        editable  = v_yes,
        printable = v_yes,
    }
    return register(tag,true) -- true forces a use
end

function viewerlayers.cleanup()
    layerstacker.clean()
    -- todo
end

implement {
    name      = "cleanuplayers",
    actions   = viewerlayers.cleanup
}

implement {
    name      = "defineviewerlayer",
    actions   = viewerlayers.define,
    arguments = {
        {
            { "tag" },
            { "title" },
            { "visible" },
            { "editable" },
            { "export" },
            { "printable" },
            { "scope" },
        },
        true
    }
}

implement {
    name      = "definedlayoutcomponent",
    actions   = { viewerlayers.definedlayoutcomponent, context },
    arguments = "string"
}

implement {
    name      = "startviewerlayer",
    actions   = viewerlayers.start,
    arguments = "string",
}

implement {
    name      = "stopviewerlayer",
    actions   = viewerlayers.stop
}

implement {
    name      = "registeredviewerlayer",
    actions   = { register, context },
    arguments = { "string", true } -- true forces a use
}
