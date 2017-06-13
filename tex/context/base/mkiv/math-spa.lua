if not modules then modules = { } end modules ['math-spa'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- for the moment (when testing) we use a penalty 1

local penalty_code = nodes.nodecodes.penalty
local glue_code    = nodes.nodecodes.glue

local nuts         = nodes.nuts
local tonut        = nodes.tonut
local tonode       = nodes.tonode
local getid        = nuts.getid
local getnext      = nuts.getnext
local getwidth     = nuts.getwidth
local setglue      = nuts.setglue
local getpenalty   = nuts.getpenalty
local setpenalty   = nuts.setpenalty

local traverse_id    = nuts.traverse_id
local get_dimensions = nuts.dimensions


local texsetdimen    = tex.setdimen

local v_none = interfaces.variables.none
local v_auto = interfaces.variables.auto

local method   = v_none
local distance = 0

function noads.handlers.align(l)
    if method ~= v_none then
        local h = tonut(l)
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
                    local w = get_dimensions(h,n) + distance
                    texsetdimen("global","d_strc_math_indent",w)
                    break
                end
                s = n
            end
        else
            texsetdimen("global","d_strc_math_indent",distance)
        end
        for n in traverse_id(glue_code,h) do
            setglue(n,getwidth(n),0,0)
        end
    else
     -- texsetdimen("global","d_strc_math_indent",0)
    end
    return l, true
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

