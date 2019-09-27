if not modules then modules = { } end modules ['back-ini'] = {
    version   = 1.001,
    comment   = "companion to back-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local format = string.format

backends                = backends or { }
local backends          = backends

local context           = context

local trace             = false  trackers.register("backend", function(v) trace = v end)
local report            = logs.reporter("backend")

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex
local setaction         = nodes.tasks.setaction

local implement         = interfaces.implement
local variables         = interfaces.variables

local texset            = tex.set

local nodeinjections    = { }
local codeinjections    = { }
local registrations     = { }
local tables            = allocate()

local function nothing()
    return nil
end

backends.nothing = nothing

local function donothing(t,k)
    t[k] = nothing
    return nothing
end

setmetatableindex(nodeinjections, donothing)
setmetatableindex(codeinjections, donothing)
setmetatableindex(registrations,  donothing)

local defaults = {
    nodeinjections = nodeinjections,
    codeinjections = codeinjections,
    registrations  = registrations,
    tables         = tables,
}

backends.defaults = defaults

backends.nodeinjections = { }  setmetatableindex(backends.nodeinjections, nodeinjections)
backends.codeinjections = { }  setmetatableindex(backends.codeinjections, codeinjections)
backends.registrations  = { }  setmetatableindex(backends.registrations,  registrations)
backends.tables         = { }  setmetatableindex(backends.tables,         tables)

backends.current = "unknown"

local lmtx_mode  = nil

local function lmtxmode()
    if lmtx_mode == nil then
        lmtx_mode = CONTEXTLMTXMODE > 0 and drivers and drivers.lmtxversion
    end
    return lmtx_mode
end

codeinjections.lmtxmode = lmtxmode

function backends.install(what)
    if type(what) == "string" then
        local backend = backends[what]
        if backend then
            if trace then
                if backend.comment then
                    report("initializing backend %a, %a",what,backend.comment)
                else
                    report("initializing backend %a",what)
                end
            end
            backends.current = what
            for category, default in next, defaults do
                local target = backends[category]
                local plugin = backend [category]
                setmetatableindex(plugin, default)
                setmetatableindex(target, plugin)
            end
        elseif trace then
            report("no backend named %a",what)
        end
    end
end

statistics.register("used backend", function()
    local bc = backends.current
    if bc ~= "unknown" then
        local lmtx = lmtxmode()
        local cmnt = backends[bc].comment or "no comment"
        if lmtx then
            return format("lmtx version %0.2f, %s (%s)",lmtx,bc,cmnt)
        else
            return format("%s (%s)",bc,cmnt)
        end
    else
        return nil
    end
end)

local comment = { "comment", "" }

tables.vfspecials = allocate {
    red        = comment,
    green      = comment,
    blue       = comment,
    black      = comment,
    startslant = comment,
    stopslant  = comment,
}

-- can best be here

interfaces.implement {
    name      = "setrealspaces",
    arguments = "string",
    actions   = function(v)
        setaction("shipouts","nodes.handlers.accessibility",v == variables.yes)
    end
}

-- moved to here

local included = table.setmetatableindex( {
    context  = true,
    id       = true,
    metadata = true,
    date     = true,
    id       = true,
    pdf      = true,
}, function(t,k)
    return true
end)

backends.included = included

function backends.timestamp()
    return os.date("%Y-%m-%dT%X") .. os.timezone(true)
end

-- Also here:

local paper_width  = 0
local paper_height = 0

function codeinjections.setpagedimensions(paperwidth,paperheight)
    if paperwidth then
        paper_width = paperwidth
    end
    if paperheight then
        paper_height = paperheight
    end
    if not lmtxmode() then
        texset("global","pageheight",paper_height)
        texset("global","pagewidth", paper_width)
    end
    return paper_width, paper_height
end

function codeinjections.getpagedimensions()
    return paper_width, paper_height
end

implement {
    name    = "shipoutoffset",
    actions = function()
        context(lmtxmode() and "0pt" or "-1in") -- the old tex offset
    end
}


local page_x_origin = 0
local page_y_origin = 0

function codeinjections.setpageorigin(x,y)
    page_x_origin = x
    page_y_origin = y
end

function codeinjections.getpageorigin()
    local x = page_x_origin
    local y = page_y_origin
    page_x_origin = 0
    page_y_origin = 0
    return x, y, (x ~= 0 or y ~= 0)
end

implement {
    name      = "setpageorigin",
    arguments = { "dimension", "dimension" },
    actions   = codeinjections.setpageorigin,
}

-- could also be codeinjections

function backends.noflatelua()
    return status.late_callbacks or 0
end
