if not modules then modules = { } end modules ['math-spa'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- for the moment (when testing) we use a penalty 1

local penalty_code  = nodes.nodecodes.penalty
local glue_code     = nodes.nodecodes.glue

local nuts          = nodes.nuts
local tonut         = nodes.tonut
local tonode        = nodes.tonode

local getid         = nuts.getid
local getnext       = nuts.getnext
local getwidth      = nuts.getwidth
local setglue       = nuts.setglue
local getpenalty    = nuts.getpenalty
local setpenalty    = nuts.setpenalty
local getdimensions = nuts.dimensions
local nextglue      = nuts.traversers.glue

local texsetdimen   = tex.setdimen

local v_none = interfaces.variables.none
local v_auto = interfaces.variables.auto

local method   = v_none
local distance = 0

function noads.handlers.align(h)
    if method ~= v_none then
        if method == v_auto then
            local s = h
            while s do
                local id = getid(s)
                local n  = getnext(s)
                if id == penalty_code and getpenalty(s) == 1 then
                    setpenalty(s,0)
                    if n and getid(n) == glue_code then
                        s = n
                        n = getnext(s)
                    end
                    local w = getdimensions(h,n) + distance
                    texsetdimen("global","d_strc_math_indent",w)
                    break
                end
                s = n
            end
        else
            texsetdimen("global","d_strc_math_indent",distance)
        end
        for n in nextglue, h do
            setglue(n,getwidth(n),0,0)
        end
    else
     -- texsetdimen("global","d_strc_math_indent",0)
    end
end

interfaces.implement {
    name      = "setmathhang",
    arguments = {
        {
            { "method", "string" },
            { "distance", "dimension" },
        }
    },
    actions   = function(t)
        method   = t.method or v_none
        distance = t.distance or 0
    end
}

interfaces.implement {
    name      = "resetmathhang",
    actions   = function(t)
        method   = v_none
        distance = 0
    end
}

