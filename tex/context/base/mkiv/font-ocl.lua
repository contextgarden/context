if not modules then modules = { } end modules ['font-ocl'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (context)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo : user list of colors

local f_color_start = string.formatters["pdf:direct: %f %f %f rg"]
local s_color_stop  = "pdf:direct:"

local function initializecolr(tfmdata,kind,value) -- hm, always value
    if value then
        local palettes = tfmdata.resources.colorpalettes
        if palettes then
            local characters   = tfmdata.characters
            local descriptions = tfmdata.descriptions
            local properties   = tfmdata.properties
            local colorvalues  = { }
            --
            properties.virtualized = true
            tfmdata.fonts = {
                { id = 0 }
            }
            --
            local startactualtext = context and backends.codeinjections.startunicodetoactualtext
            local stopactualtext  = context and backends.codeinjections.stopunicodetoactualtext
            if not startactualtext then
                -- let's be nice for generic
                local tounicode = fonts.mappings.tounicode16
                startactualtext = function(n)
                    return "/Span << /ActualText <feff" .. tounicode(n) .. "> >> BDC"
                end
                stopactualtext = function(n)
                    return "EMC"
                end
            end
            --
            palettes = palettes[tonumber(value) or 1] or palettes[1]
            for i=1,#palettes do
                local p = palettes[i]
                colorvalues[i] = { "special", f_color_start(p[1]/255,p[2]/255,p[3]/255) }
            end
            --
            local stop = { "special", "pdf:direct:" .. stopactualtext() }
            --
            for unicode, character in next, characters do
                local description = descriptions[unicode]
                if description then
                    local colorlist = description.colors
                    if colorlist then
                        local w = character.width or 0
                        local s = #colorlist
                        local n = 1
                        local t = {
                            { "special", "pdf:direct:" .. startactualtext(unicode) }
                        }
                        for i=1,s do
                            local entry = colorlist[i]
                            n = n + 1 t[n] = colorvalues[entry.class]
                            n = n + 1 t[n] = { "char", entry.slot }
                            if s > 1 and i < s and w ~= 0 then
                                n = n + 1 t[n] = { "right", -w }
                            end
                        end
                        n = n + 1 t[n] = stop
                        character.commands = t
                    end
                end
            end
        end
    end
end

fonts.handlers.otf.features.register {
    name         = "colr",
    description  = "color glyphs",
    manipulators = {
        base = initializecolr,
        node = initializecolr,
    }
}
