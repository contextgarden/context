if not modules then modules = { } end modules ['back-trf'] = {
    version   = 1.001,
    comment   = "companion to back-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local sind, cosd, abs = math.sind, math.cosd, math.abs
local insert, remove = table.insert, table.remove
local unpack = unpack

local context           = context

local formatters        = string.formatters

local scanners          = tokens.scanners
local scankeyword       = scanners.keyword
local scaninteger       = scanners.integer
local scannumber        = scanners.number
local scanstring        = scanners.string

local implement         = interfaces.implement

local nodepool          = nodes.pool
local savenode          = nodepool.save
local restorenode       = nodepool.restore
local setmatrixnode     = nodepool.setmatrix
local literalnode       = nodepool.literal -- has to become some nodeinjection

local stack             = { }
local restore           = true -- false

updaters.register("backend.update",function()
    savenode      = nodepool.save
    restorenode   = nodepool.restore
    setmatrixnode = nodepool.setmatrix
    literalnode   = nodepool.literal -- has to become some nodeinjection
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

-- this could also run on top of pack-rul ... todo

-- local function startclipping()
--  -- context(savenode())
--     context(literalnode("origin",formatters["q 0 w %s W n"](scanstring())))
-- end
--
-- local function stopclipping()
--  -- context(restorenode())
--     context(literalnode("Q"))
-- end

local function startclipping()
    context(savenode())
    context(literalnode("origin",formatters["0 w %s W n"](scanstring())))
end

local function stopclipping()
    context(restorenode())
end

implement { name = "startclipping", actions = startclipping }
implement { name = "stopclipping",  actions = stopclipping }
