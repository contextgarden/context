if not modules then modules = { } end modules ['meta-fun'] = {
    version   = 1.001,
    comment   = "companion to meta-fun.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- very experimental, actually a joke ... see metafun manual for usage

local format, load, type = string.format, load, type

local context    = context
local metapost   = metapost

local metafun    = metapost.metafun or { }
metapost.metafun = metafun

function metafun.topath(t,connector)
    context("(")
    if #t > 0 then
        if not connector then
            connector = ".."
        end
        for i=1,#t do
            if i > 1 then
                context(connector)
            end
            local ti = t[i]
            if type(ti) == "string" then
                context(ti)
            else
                context("(%F,%F)",ti.x or ti[1] or 0,ti.y or ti[2] or 0)
            end
        end
    else
        context("origin")
    end
    context(")")
end

function metafun.interpolate(f,b,e,s,c)
    local done = false
    context("(")
    local d = load(format("return function(x) return %s end",f))
    if d then
        d = d()
        if not c then
            c = "..."
        end
        for i=b,e,(e-b)/s do
            if done then
                context(c)
            else
                done = true
            end
            context("(%F,%F)",i,d(i))
        end
    end
    if not done then
        context("origin")
    end
    context(")")
end
