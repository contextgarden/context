if not modules then modules = { } end modules ['font-ldr'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module provides an experimental replacement for fontloader.to_table
-- but is not used that much.

local fields = fontloader.fields

if fields then

    local glyphfields

    local function get_glyphs(r)
        local t = { }
        local g = r.glyphs
        for i=1,r.glyphmax-1 do
            local gi = g[i]
            if gi then
                if not glyphfields then
                    glyphfields = fields(gi)
                end
                local h = { }
                for i=1,#glyphfields do
                    local s = glyphfields[i]
                    h[s] = gi[s]
                end
                t[i] = h
            end
        end
        return t
    end

    local function to_table(r)
        local f = fields(r)
        if f then
            local t = { }
            for i=1,#f do
                local fi = f[i]
                local ri = r[fi]
                if not ri then
                    -- skip
                elseif fi == "glyphs" then
                    t.glyphs = get_glyphs(r)
                elseif fi == "subfonts" then
                    t[fi] = ri
                    ri.glyphs = get_glyphs(ri)
                else
                    t[fi] = r[fi]
                end
            end
            return t
        end
    end

    -- currently glyphs, subfont-glyphs and the main table are userdata

    function fonts.to_table(raw)
        return to_table(raw)
    end

else

    fonts.to_table = fontloader.to_table

end
