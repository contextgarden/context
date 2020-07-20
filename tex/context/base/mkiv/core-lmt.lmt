if not modules then modules = { } end modules ['core-lmt'] = {
    version   = 1.001,
    comment   = "companion to core-lmt.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local implement   = interfaces.implement
local scankeyword = tokens.scanners.keyword

local settextdir = tex.settextdir
local setlinedir = tex.setlinedir
local setpardir  = tex.setpardir
local setboxdir  = tex.setboxdir

local function scandir(what)
    if scankeyword("tlt") then
        what(0)
    elseif scankeyword("trt") then
        what(1)
 -- elseif scankeyword("rtt") then
 --     what(2)
 -- elseif scankeyword("ltl") then
 --     what(3)
    else
        what(0)
    end
end

implement { name = "textdir", public = true, protected = true, actions = function() scandir(settextdir) end }
implement { name = "linedir", public = true, protected = true, actions = function() scandir(setlinedir) end }
implement { name = "pardir",  public = true, protected = true, actions = function() scandir(setpardir)  end }
implement { name = "boxdir",  public = true, protected = true, actions = function() scandir(setboxdir)  end }
