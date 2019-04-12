if not modules then modules = { } end modules ['back-ini'] = {
    version   = 1.001,
    comment   = "companion to back-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local format = string.format
local sind, cosd, abs = math.sind, math.cosd, math.abs
local insert, remove = table.insert, table.remove
local unpack = unpack

backends                = backends or { }
local backends          = backends

local trace_backend     = false  trackers.register("backend.initializers", function(v) trace_finalizers = v end)

local report            = logs.reporter("backend")
local report_backend    = logs.reporter("backend","initializing")

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex
local setaction         = nodes.tasks.setaction

local scanners          = tokens.scanners
local scannumber        = scanners.number
local scankeyword       = scanners.keyword
local scancount         = scanners.count
local scanstring        = scanners.string

local scanners          = interfaces.scanners

local implement         = interfaces.implement

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
            if trace_backend then
                if backend.comment then
                    report_backend("initializing backend %a, %a",what,backend.comment)
                else
                    report_backend("initializing backend %a",what)
                end
            end
            backends.current = what
            for category, default in next, defaults do
                local target = backends[category]
                local plugin = backend [category]
                setmetatableindex(plugin, default)
                setmetatableindex(target, plugin)
            end
        elseif trace_backend then
            report_backend("no backend named %a",what)
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
        setaction("shipouts","nodes.handlers.accessibility",v == interfaces.variables.yes)
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

-- could also be codeinjections

function backends.noflatelua()
    return status.late_callbacks or 0
end

--

local stack         = { }
local restore       = true -- false

local nodepool      = nodes.pool
local savenode      = nodepool.save
local restorenode   = nodepool.restore
local setmatrixnode = nodepool.setmatrix

updaters.register("backend.update",function()
    savenode      = nodepool.save
    restorenode   = nodepool.restore
    setmatrixnode = nodepool.setmatrix
end)

local function stopsomething()
    local top = remove(stack)
    if top == false then
        -- not wrapped
    elseif top == true then
        context(restorenode())
    elseif top then
        context(setmatrixnode(unpack(top))) -- not really needed anymore
        context(restorenode())
    else
        -- nesting error
    end
end

local function startrotation()
    local a = scannumber()
    if a == 0 then
        insert(stack,false)
    else
        local s, c = sind(a), cosd(a)
        if abs(s) < 0.000001 then
            s = 0 -- otherwise funny -0.00000
        end
        if abs(c) < 0.000001 then
            c = 0 -- otherwise funny -0.00000
        end
        context(savenode())
        context(setmatrixnode(c,s,-s,c))
        insert(stack,restore and { c, -s, s, c } or true)
    end
end

implement { name = "startrotation", actions = startrotation }
implement { name = "stoprotation",  actions = stopsomething }

local function startscaling() -- at the tex end we use sx and sy instead of rx and ry
    local rx, ry = 1, 1
    while true do
        if scankeyword("rx") then
            rx = scannumber()
        elseif scankeyword("ry") then
            ry = scannumber()
     -- elseif scankeyword("revert") then
     --     local top = stack[#stack]
     --     if top then
     --         rx = top[1]
     --         ry = top[4]
     --     else
     --         rx = 1
     --         ry = 1
     --     end
        else
            break
        end
    end
    if rx == 1 and ry == 1 then
        insert(stack,false)
    else
        if rx == 0 then
            rx = 0.0001
        end
        if ry == 0 then
            ry = 0.0001
        end
        context(savenode())
        context(setmatrixnode(rx,0,0,ry))
        insert(stack,restore and { 1/rx, 0, 0, 1/ry } or true)
    end
end

implement { name = "startscaling", actions = startscaling }
implement { name = "stopscaling",  actions = stopsomething }

local function startmatrix() -- rx sx sy ry  -- tx, ty
    local rx, sx, sy, ry = 1, 0, 0, 1
    while true do
            if scankeyword("rx") then rx = scannumber()
        elseif scankeyword("ry") then ry = scannumber()
        elseif scankeyword("sx") then sx = scannumber()
        elseif scankeyword("sy") then sy = scannumber()
        else   break end
    end
    if rx == 1 and sx == 0 and sy == 0 and ry == 1 then
        insert(stack,false)
    else
        context(savenode())
        context(setmatrixnode(rx,sx,sy,ry))
        insert(stack,store and { -rx, -sx, -sy, -ry } or true)
    end
end

implement { name = "startmatrix", actions = startmatrix }
implement { name = "stopmatrix",  actions = stopsomething }

local function startmirroring()
    context(setmatrixnode(-1,0,0,1))
end

implement { name = "startmirroring", actions = startmirroring }
implement { name = "stopmirroring",  actions = startmirroring } -- not: stopsomething
