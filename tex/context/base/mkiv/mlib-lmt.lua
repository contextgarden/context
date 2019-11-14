if not modules then modules = { } end modules ['mlib-lmt'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local mppath       = mp.path

local scannumeric  = mp.scan.numeric
local scanpath     = mp.scan.path

local getparameter = metapost.getparameter

function mp.lmt_function_x(xmin,xmax,xstep,code,shape) -- experimental
    local code      = "return function(x) return " .. code .. " end"
    local action    = load(code)
    local points    = { }
    local nofpoints = 0
    if action then
         action = action()
    end
    if shape == "steps" then
        local halfx     = xstep / 2
        local lastx     = xmin
        local lasty     = action(xmin)
        for xi = xmin, xmax, xstep do
            local yi  = action(xi)
            local xx  = lastx + halfx
            nofpoints = nofpoints + 1 ; points[nofpoints] = { xx, lasty }
            nofpoints = nofpoints + 1 ; points[nofpoints] = { xx, yi }
            lastx     = xi
            lasty     = yi
        end
        if points[nofpoints][1] ~= xmax then
            local yi  = action(xmax)
            local xx  = lastx + halfx
            nofpoints = nofpoints + 1 ; points[nofpoints] = { xx, lasty }
            nofpoints = nofpoints + 1 ; points[nofpoints] = { xx, yi }
            lastx     = xi
            lasty     = yi
        end
    else
        for xi = xmin, xmax, xstep do
            nofpoints = nofpoints + 1 ; points[nofpoints] = { xi, action(xi) }
        end
        if points[nofpoints][1] ~= xmax then
            nofpoints = nofpoints + 1 ; points[nofpoints] = { xmax, action(xmax) }
        end
    end
    mppath(points,shape == "curve" and ".." or "--",false)
end

function mp.lmt_mesh_set()
    local mesh = getparameter { "mesh", "paths" }
    structures.references.currentset.mesh = mesh
end

function mp.lmt_mesh_update()
    local mesh = getparameter { "paths" } or getparameter { "mesh", "paths" }
    mesh[scannumeric()] = scanpath(true)
end
