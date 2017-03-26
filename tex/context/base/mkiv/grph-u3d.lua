if not modules then modules = { } end modules ['grph-u3d'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- see lpdf-u3d.lua for comment

-- maybe: backends.codeinjections.insertu3d

local trace_inclusion = false  trackers.register("figures.inclusion",  function(v) trace_inclusion = v end)

local report_u3d = logs.reporter("graphics","u3d")

local figures         = figures
local context         = context
local nodeinjections  = backends.nodeinjections
local todimen         = string.todimen

function figures.checkers.u3d(data)
    local dr, du, ds = data.request, data.used, data.status
    local width = todimen(dr.width or figures.defaultwidth)
    local height = todimen(dr.height or figures.defaultheight)
    local foundname = du.fullname
    dr.width, dr.height = width, height
    du.width, du.height, du.foundname = width, height, foundname
    if trace_inclusion then
        report_u3d("including u3d %a, width %p, height %p",foundname,width,height)
    end
    context.startfoundexternalfigure(width .. "sp",height .. "sp")
    context(function()
        nodeinjections.insertu3d {
            foundname  = foundname,
            width      = width,
            height     = height,
            factor     = number.dimenfactors.bp,
            display    = dr.display,
            controls   = dr.controls,
            label      = dr.label,
        }
    end)
    context.stopfoundexternalfigure()
    return data
end

figures.includers.u3d = figures.includers.nongeneric

-- figures.checkers .prc = figures.checkers.u3d
-- figures.includers.prc = figures.includers.nongeneric

figures.registersuffix("u3d","u3d")
figures.registersuffix("prc","u3d")
