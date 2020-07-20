if not modules then modules = { } end modules ['lpdf-vfc'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local setmetatableindex = table.setmetatableindex
local formatters = string.formatters

local bp  = number.dimenfactors.bp
local r   = 16384 * bp
local f_1 = formatters["%.6F w 0 %.6F %.6F %.6F re f"]
local f_2 = formatters["[] 0 d 0 J %.6F w %.6F %.6F %.6F %.6F re S"]

local vfspecials = backends.pdf.tables.vfspecials

vfspecials.backgrounds = setmetatableindex(function(t,h)
    local h = h * bp
    local v = setmetatableindex(function(t,d)
        local d = d * bp
        local v = setmetatableindex(function(t,w)
            local v = { "pdf", "origin", f_1(r,-d,w*bp,h+d) }
            t[w] = v
            return v
        end)
        t[d] = v
        return v
    end)
    t[h] = v
    return v
end)

vfspecials.outlines = setmetatableindex(function(t,h)
    local h = h * bp
    local v = setmetatableindex(function(t,d)
        local d = d * bp
        local v = setmetatableindex(function(t,w)
            -- the frame goes through the boundingbox
            local v = { "pdf", "origin", f_2(r,r/2,-d+r/2,w*bp-r,h+d-r) }
            t[w] = v
            return v
        end)
        t[d] = v
        return v
    end)
    t[h] = v
    return v
end)
