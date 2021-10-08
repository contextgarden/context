local info = {
    version   = 1.002,
    comment   = "theme for scintilla lpeg lexer for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

if not lexers or not lexers.initialized then

    local font_name = 'Dejavu Sans Mono'
    local font_size = '14'

    local colors = {
        red       = { 0x7F, 0x00, 0x00 },
        green     = { 0x00, 0x7F, 0x00 },
        blue      = { 0x00, 0x00, 0x7F },
        cyan      = { 0x00, 0x7F, 0x7F },
        magenta   = { 0x7F, 0x00, 0x7F },
        yellow    = { 0x7F, 0x7F, 0x00 },
        orange    = { 0xB0, 0x7F, 0x00 },
        --
        white     = { 0xFF },
        light     = { 0xCF },
        grey      = { 0x80 },
        dark      = { 0x4F },
        black     = { 0x00 },
        --
        selection = { 0xF7 },
        logpanel  = { 0xE7 },
        textpanel = { 0xCF },
        linepanel = { 0xA7 },
        tippanel  = { 0x44 },
        --
        right     = { 0x00, 0x00, 0xFF },
        wrong     = { 0xFF, 0x00, 0x00 },
    }

    local styles = {

        ["mainspace"]    = { },
        ["whitespace"]   = { },
     -- ["default"]      = { font = font_name, size = font_size, fore = colors.black, back = colors.textpanel },
     -- ["default"]      = { font = font_name, size = font_size, fore = colors.black },
        ["default"]      = { font = font_name, size = font_size, fore = colors.black },
        ["number"]       = { fore = colors.cyan },
        ["comment"]      = { fore = colors.yellow },
        ["keyword"]      = { fore = colors.blue, bold = true },
        ["string"]       = { fore = colors.magenta },
     -- ["preproc"]      = { fore = colors.yellow, bold = true },
        ["error"]        = { fore = colors.red },
        ["label"]        = { fore = colors.red, bold = true  },

        ["nothing"]      = { },
        ["class"]        = { fore = colors.black, bold = true },
        ["function"]     = { fore = colors.black, bold = true },
        ["constant"]     = { fore = colors.cyan, bold = true },
        ["operator"]     = { fore = colors.blue },
        ["regex"]        = { fore = colors.magenta },
        ["preprocessor"] = { fore = colors.yellow, bold = true },
        ["tag"]          = { fore = colors.cyan },
        ["type"]         = { fore = colors.blue },
        ["variable"]     = { fore = colors.black },
        ["identifier"]   = { },

        ["linenumber"]   = { back = colors.linepanel },
        ["bracelight"]   = { fore = colors.orange, bold = true },
        ["bracebad"]     = { fore = colors.orange, bold = true },
        ["controlchar"]  = { },
        ["indentguide"]  = { fore = colors.linepanel, back = colors.white },
        ["calltip"]      = { fore = colors.white, back = colors.tippanel },

        ["invisible"]    = { back = colors.orange },
        ["quote"]        = { fore = colors.blue, bold = true },
        ["special"]      = { fore = colors.blue },
        ["extra"]        = { fore = colors.yellow },
        ["embedded"]     = { fore = colors.black, bold = true },
        ["char"]         = { fore = colors.magenta },
        ["reserved"]     = { fore = colors.magenta, bold = true },
        ["definition"]   = { fore = colors.black, bold = true },
        ["okay"]         = { fore = colors.dark },
        ["warning"]      = { fore = colors.orange },
        ["standout"]     = { fore = colors.orange, bold = true },
        ["command"]      = { fore = colors.green, bold = true },
        ["internal"]     = { fore = colors.orange, bold = true },
        ["preamble"]     = { fore = colors.yellow },
        ["grouping"]     = { fore = colors.red  },
        ["primitive"]    = { fore = colors.blue, bold = true },
        ["plain"]        = { fore = colors.dark, bold = true },
        ["user"]         = { fore = colors.green },
        ["data"]         = { fore = colors.cyan, bold = true },

        -- equal to default:

        ["text"]         = { font = font_name, size = font_size, fore = colors.black, back = colors.textpanel },
        ["text"]         = { font = font_name, size = font_size, fore = colors.black },

    }

    return styles

end
