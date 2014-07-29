if not modules then modules = { } end modules ['font-sel'] = {
    version   = 1.000,
    comment   = "companion to font-sel.mkvi",
    author    = "Wolfgang Schuster",
    copyright = "Wolfgang Schuster",
    license   = "GNU General Public License"
}

local context                 = context
local cleanname               = fonts.names.cleanname
local gsub, splitup, find     = string.gsub, string.splitup, string.find
local splitbase, removesuffix = file.splitbase, file.removesuffix
local splitat, lpegmatch      = lpeg.splitat, lpeg.match

local formatters              = string.formatters
local settings_to_array       = utilities.parsers.settings_to_array

local v_yes                   = interfaces.variables.yes
local v_simplefonts           = interfaces.variables.simplefonts
local v_selectfont            = interfaces.variables.selectfont
local v_default               = interfaces.variables.default

local selectfont              = fonts.select or { }
fonts.select                  = selectfont

local data                    = selectfont.data or { }
selectfont.data               = data

local fallbacks               = selectfont.fallbacks or { }
selectfont.fallbacks          = fallbacks

local methods                 = selectfont.methods or { }
selectfont.methods            = methods

local getlookups              = fonts.names.getlookups
local registerdesignsizes     = fonts.goodies.designsizes.register

local alternatives = {
    ["tf"] = "regular",
    ["it"] = "italic",
    ["sl"] = "slanted",
    ["bf"] = "bold",
    ["bi"] = "bolditalic",
    ["bs"] = "boldslanted",
    ["sc"] = "smallcaps",
}

local styles = {
    ["rm"] = "serif",
    ["ss"] = "sans",
    ["tt"] = "mono",
    ["hw"] = "handwriting",
    ["cg"] = "calligraphy",
    ["mm"] = "math",
}

local sizes = {
    ["default"] = {
        { 40, "4pt" },
        { 50, "5pt" },
        { 60, "6pt" },
        { 70, "7pt" },
        { 80, "8pt" },
        { 90, "9pt" },
        { 100, "10pt" },
        { 110, "11pt" },
        { 120, "12pt" },
        { 144, "14.4pt" },
        { 173, "17.3pt" },
    },
    ["dtp"] = {
        { 50, "5pt" },
        { 60, "6pt" },
        { 70, "7pt" },
        { 80, "8pt" },
        { 90, "9pt" },
        { 100, "10pt" },
        { 110, "11pt" },
        { 120, "12pt" },
        { 130, "13pt" },
        { 140, "14pt" },
        { 160, "16pt" },
        { 180, "18pt" },
        { 220, "22pt" },
        { 280, "28pt" },
    }
}

local synonyms = {
    ["rm"] = {
        ["tf"] = "Serif",
        ["it"] = "SerifItalic",
        ["sl"] = "SerifSlanted",
        ["bf"] = "SerifBold",
        ["bi"] = "SerifBoldItalic",
        ["bs"] = "SerifBoldSlanted",
        ["sc"] = "SerifCaps",
    },
    ["ss"] = {
        ["tf"] = "Sans",
        ["it"] = "SansItalic",
        ["sl"] = "SansSlanted",
        ["bf"] = "SansBold",
        ["bi"] = "SansBoldItalic",
        ["bs"] = "SansBoldSlanted",
        ["sc"] = "SansCaps",
    },
    ["tt"] = {
        ["tf"] = "Mono",
        ["it"] = "MonoItalic",
        ["sl"] = "MonoSlanted",
        ["bf"] = "MonoBold",
        ["bi"] = "MonoBoldItalic",
        ["bs"] = "MonoBoldSlanted",
        ["sc"] = "MonoCaps",
    },
    ["hw"] = {
        ["tf"] = "Handwriting",
    },
    ["cg"] = {
        ["tf"] = "Calligraphy",
    },
    ["mm"] = {
        ["tf"] = "MathRoman",
        ["bf"] = "MathBold",
    }
}

local replacement = {
    ["style"] = {
        ["it"] = "tf",
        ["sl"] = "it",
        ["bf"] = "tf",
        ["bi"] = "bf",
        ["bs"] = "bi",
        ["sc"] = "tf",
    },
    ["weight"] = {
        ["it"] = "tf",
        ["sl"] = "tf",
        ["bf"] = "tf",
        ["bi"] = "bf",
        ["bs"] = "bf",
        ["sc"] = "tf",
    },
}

local names = {
    ["selectfont"] = { -- weight, style, width, variant, italic
        ["regular"]      = { weight = "normal", style = "normal",  width = "normal", variant = "normal", 	italic = false },
        ["italic"]       = { weight = "normal", style = "italic",  width = "normal", variant = "normal",    italic = true  },
        ["slanted"]      = { weight = "normal", style = "slanted", width = "normal", variant = "normal",    italic = true  },
        ["medium"]       = { weight = "medium", style = "normal",  width = "normal", variant = "normal",    italic = false },
        ["mediumitalic"] = { weight = "medium", style = "italic",  width = "normal", variant = "normal",    italic = true  },
        ["mediumcaps"]   = { weight = "medium", style = "normal",  width = "normal", variant = "smallcaps", italic = true  },
        ["bold"]         = { weight = "bold",   style = "normal",  width = "normal", variant = "normal",    italic = false },
        ["bolditalic"]   = { weight = "bold",   style = "italic",  width = "normal", variant = "normal",    italic = true  },
        ["boldslanted"]  = { weight = "bold",   style = "slanted", width = "normal", variant = "normal",    italic = true  },
        ["smallcaps"]    = { weight = "normal", style = "normal",  width = "normal", variant = "smallcaps", italic = false },
    },
    ["simplefonts"] = {
        ["light"]        = { "lightregular", "light" },
        ["lightitalic"]  = { "lightitalic", "lightit", "lightoblique" },
        ["lightcaps"]    = { "smallcapslight" },
        ["regular"]      = { "roman", "regular", "book", "" },
        ["italic"]       = { "italic", "it", "oblique", "kursiv", "bookitalic", "bookit" },
        ["medium"]       = { "mediumregular", "medregular", "medium" },
        ["mediumitalic"] = { "mediumitalic", "meditalic" },
        ["mediumcaps"]   = { "mediumcaps" },
        ["bold"]         = { "bold", "bd", "kraeftig", "mediumregular", "semibold", "demi" },
        ["bolditalic"]   = { "bolditalic", "boldit", "bdit", "boldoblique", "mediumitalic", "semibolditalic", "demiitalic" },
        ["smallcaps"]    = { "smallcaps", "capitals", "sc" },
        ["heavy"]        = { "heavyregular", "heavy" },
        ["heavyitalic"]  = { "heavyitalic" },
    },
    ["default"] = { -- weight, width, italic
        ["thin"]             = { weight = { 100, 200, 300, 400, 500 }, width = 5, italic = false },
        ["thinitalic"]       = { weight = { 100, 200, 300, 400, 500 }, width = 5, italic = true  },
        ["extralight"]       = { weight = { 200, 100, 300, 400, 500 }, width = 5, italic = false },
        ["extralightitalic"] = { weight = { 200, 100, 300, 400, 500 }, width = 5, italic = true  },
        ["light"]            = { weight = { 300, 200, 100, 400, 500 }, width = 5, italic = false },
        ["lightitalic"]      = { weight = { 300, 200, 100, 400, 500 }, width = 5, italic = true  },
        ["regular"]          = { weight = { 400, 500, 300, 200, 100 }, width = 5, italic = false },
        ["italic"]           = { weight = { 400, 500, 300, 200, 100 }, width = 5, italic = true  },
        ["medium"]           = { weight = { 500, 400, 300, 200, 100 }, width = 5, italic = false },
        ["mediumitalic"]     = { weight = { 500, 400, 300, 200, 100 }, width = 5, italic = true  },
        ["demibold"]         = { weight = { 600, 700, 800, 900 },      width = 5, italic = false },
        ["demibolditalic"]   = { weight = { 600, 700, 800, 900 },      width = 5, italic = true  },
        ["bold"]             = { weight = { 700, 600, 800, 900 },      width = 5, italic = false },
        ["bolditalic"]       = { weight = { 700, 600, 800, 900 },      width = 5, italic = true  },
        ["extrabold"]        = { weight = { 800, 900, 700, 600 },      width = 5, italic = false },
        ["extrabolditalic"]  = { weight = { 800, 900, 700, 600 },      width = 5, italic = true  },
        ["heavy"]            = { weight = { 900, 800, 700, 600 },      width = 5, italic = false },
        ["heavyitalic"]      = { weight = { 900, 800, 700, 600 },      width = 5, italic = true  },
    }
}

-- simplefonts synonyms

names.simplefonts.slanted       = names.simplefonts.italic
names.simplefonts.boldslanted   = names.simplefonts.bolditalic

-- default synonyms

names.default.ultralight        = names.default.extralight
names.default.semibold          = names.default.demibold
names.default.ultrabold         = names.default.extrabold
names.default.black             = names.default.heavy

names.default.ultralightitalic  = names.default.extralightitalic
names.default.semibolditalic    = names.default.demibolditalic
names.default.ultrabolditalic   = names.default.extrabolditalic
names.default.blackitalic       = names.default.heavyitalic

names.default.thinslanted       = names.default.thinitalic
names.default.extralightslanted = names.default.extralightitalic
names.default.ultralightslanted = names.default.extralightitalic
names.default.lightslanted      = names.default.lightitalic
names.default.slanted           = names.default.italic
names.default.demiboldslanted   = names.default.demibolditalic
names.default.semiboldslanted   = names.default.demibolditalic
names.default.boldslanted       = names.default.bolditalic
names.default.extraboldslanted  = names.default.extrabolditalic
names.default.ultraboldslanted  = names.default.extrabolditalic
names.default.heavyslanted      = names.default.heavyitalic
names.default.blackslanted      = names.default.heavyitalic

names.default.smallcaps         = names.default.regular

local mathsettings = {
    ["asanamath"] = {
        extras   = "asana-math",
        goodies  = {
            ["tf"] = "anana-math",
        },
        features = {
            ["tf"] = "math\\mathsizesuffix",
        },
    },
    ["cambriamath"] = {
        extras   = "cambria-math",
        goodies  = {
            ["tf"] = "cambria-math",
        },
        features = {
            ["tf"] = "math\\mathsizesuffix",
        },
    },
    ["neoeuler"] = {
        extras   = "euler-math",
        features = {
            ["tf"] = "math\\mathsizesuffix",
        },
    },
    ["latinmodernmath"] = {
        extras   = "lm,lm-math",
        goodies  = {
            ["tf"] = "lm",
        },
        features = {
            ["tf"] = "math\\mathsizesuffix,lm-math",
        },
    },
    ["lucidabrightmathot"] = {
        extras   = "lucida-opentype-math",
        goodies  = {
            ["tf"] = "lucida-opentype-math",
        },
        features = {
            ["tf"] = "math\\mathsizesuffix",
        },
    },
    ["texgyrepagellamath"] = {
        extras   = "texgyre",
        features = {
            ["tf"] = "math\\mathsizesuffix",
        },
    },
    ["texgyrebonummath"] = {
        extras   = "texgyre",
        features = {
            ["tf"] = "math\\mathsizesuffix",
        },
    },
    ["texgyretermesmath"] = {
        extras   = "texgyre",
        features = {
            ["tf"] = "math\\mathsizesuffix",
        },
    },
    ["xitsmath"] = {
        extras   = "xits-math",
        goodies  = {
            ["tf"] = "xits-math",
        },
        features = {
            ["tf"] = "math\\mathsizesuffix",
        },
    },
}

function commands.defineselectfont(settings)
    local index = #data + 1
    data[index] = settings
    selectfont.searchfiles(index)
    selectfont.filterinput(index)
    context(index)
end

local function savefont(data,alternative,entries)
    local f = data.fonts
    if not f then
        f = { }
        data.fonts = f
    end
    f[alternative] = entries
end

local function savefeatures(data,alternative,entries)
    local e = gsub(entries,"{(.*)}","%1")
    local f = data.features
    if not f then
        f = { }
        data.features = f
    end
    f[alternative] = e
end

local function savegoodies(data,alternative,entries)
    local e = gsub(entries,"{(.*)}","%1")
    local g = data.goodies
    if not f then
        g = { }
        data.goodies = g
    end
    g[alternative] = e
end

methods[v_simplefonts] = function(data,alternative,style)
    local family = data.metadata.family
    local names  = names["simplefonts"][style] or names["simplefonts"]["regular"]
    for _, name in next, names do
        local filename      = cleanname(formatters["%s%s"](family,name))
        local fullname      = getlookups{ fullname      = filename }
        local fontname      = getlookups{ fontname      = filename }
        local cleanfilename = getlookups{ cleanfilename = filename }
        if #fullname > 0 then
            savefont(data,alternative,fullname)
            break
        elseif #fontname > 0 then
            savefont(data,alternative,fontname)
            break
        elseif #cleanfilename > 0 then
            savefont(data,alternative,cleanfilename)
            break
        end
    end
end

methods[v_default] = function(data,alternative,style)
    local family = data.metadata.family
    local spec   = names["default"][style] or names["default"]["regular"]
    local weights = spec["weight"]
    for _, weight in next, weights do
        local pattern = getlookups{
            familyname = cleanname(family),
            pfmweight  = weight,
            pfmwidth   = spec["width"],
        }
        if #pattern > 0 then
            local fontfiles = { }
            for _, fontfile in next, pattern do
                if (fontfile["angle"] and spec["italic"] == true) or (not fontfile["angle"] and spec["italic"] == false) then
                    fontfiles[#fontfiles + 1] = fontfile
                end
            end
            savefont(data,alternative,fontfiles)
            break
       end
    end
end

methods[v_selectfont] = function(data,alternative,style)
    local family  = data.metadata.family
    local spec    = names["selectfont"][style] or names["selectfont"]["regular"]
    local pattern = getlookups{
        familyname = cleanname(family),
        weight     = spec["weight"],
        style      = spec["style"],
        width      = spec["width"],
        variant    = spec["variant"]
    }
    if #pattern > 0 then
        local fontfiles = { }
        for _, fontfile in next, pattern do
            if (fontfile["angle"] and spec["italic"] == true) or (not fontfile["angle"] and spec["italic"] == false) then
                fontfiles[#fontfiles + 1] = fontfile
            end
        end
        savefont(data,alternative,fontfiles)
    end
end

methods["name"] = function(data,alternative,filename)
    local data     = data
    local family   = data.metadata.family
    local filename = cleanname(gsub(filename,"*",family))
    local fullname = getlookups{ fullname = filename }
    local fontname = getlookups{ fontname = filename }
    if #fullname > 0 then
        savefont(data,alternative,fullname)
    elseif #fontname > 0 then
        savefont(data,alternative,fontname)
    end
end

methods["file"] = function(data,alternative,filename)
    local data     = data
    local family   = data.metadata.family
    local filename = gsub(removesuffix(filename),"*",family)
    local filename = getlookups{ cleanfilename = cleanname(filename) }
    if #filename > 0 then
        savefont(data,alternative,filename)
    end
end

methods["spec"] = function(data,alternative,filename)
    local family  = data.metadata.family
    local weight, style, width, variant = splitup(filename,"-")
    local pattern = getlookups{
        familyname = cleanname(family),
        weight     = weight  or "normal",
        style      = style   or "normal",
        width      = width   or "normal",
        variant    = variant or "normal",
    }
    if #pattern > 0 then
        savefont(data,alternative,pattern)
    end
end

methods["style"] = function(data,alternative,style)
    local method = data.options.alternative or nil
    (methods[method] or methods[v_default])(data,alternative,style)
end

methods["features"] = function(data,alternative,features)
    savefeatures(data,alternative,features)
end

methods["goodies"] = function(data,alternative,goodies)
    savegoodies(data,alternative,goodies)
end

function selectfont.searchfiles(index)
    local data = data[index]
    for alternative, _ in next, alternatives do
        local filename = data.files[alternative]
        local method   = data.options.alternative
        local family   = data.metadata.family
        local style    = alternatives[alternative]
        if filename == "" then
            local pattern = getlookups{ familyname = cleanname(family) }
            if #pattern == 1 and alternative == "tf" then -- needs to be improved
                savefont(data,alternative,pattern)
            else
                (methods[method] or methods[v_default])(data,alternative,style)
            end
        else
            method, filename = splitup(filename,":")
            if not filename then
                filename = method
                method   = "name"
            end
            (methods[method] or methods["name"])(data,alternative,filename)
        end
    end
end

function selectfont.filterinput(index)
    local data = data[index]
    local p    = splitat(":",true)
    for alternative, _ in next, alternatives do
        local list = settings_to_array(data.alternatives[alternative])
        for _, entry in next, list do
            method, entries = lpegmatch(p,entry)
            if not entries then
                entries = method
                method  = "name"
            end
            (methods[method] or methods["name"])(data,alternative,entries)
        end
    end
end

local function definefontsynonym(data,alternative,index,fallback)
    local fontdata     = data.fonts and data.fonts[alternative]
    local style        = data.metadata.style
    local typeface     = data.metadata.typeface
    local mathsettings = mathsettings[cleanname(data.metadata.family)]
    local features     = mathsettings and mathsettings["features"] and (mathsettings["features"][alternative] or mathsettings["features"]["tf"]) or data.features and data.features[alternative] or ""
    local goodies      = mathsettings and mathsettings["goodies"]  and (mathsettings["goodies"] [alternative] or mathsettings["goodies"] ["tf"]) or data.goodies  and data.goodies [alternative] or ""
    local parent       = replacement["style"][alternative] or ""
    local fontname, fontfile, fontparent
    if fallback then
        fontname   = formatters["%s-%s-%s-fallback-%s"](typeface, style, alternative, index)
        fontfile   = formatters["%s-%s-%s-%s"]         (typeface, style, alternative, index)
        fontparent = formatters["%s-%s-%s-fallback-%s"](typeface, style, parent,      index)
    else
        fontname   = synonyms[style][alternative]
        fontfile   = formatters["%s-%s-%s"](typeface, style, alternative)
        fontparent = formatters["%s-%s-%s"](typeface, style, parent)
    end
    if fontdata and #fontdata > 0 then
        for _, size in next, sizes["default"] do
            for _, entry in next, fontdata do
                if entry["minsize"] and entry["maxsize"] then
                    if size[1] > entry["minsize"] and size[1] <= entry["maxsize"] then
                        local filepath, filename = splitbase(entry["filename"])
                        registerdesignsizes( fontfile, size[2], filename )
                    end
                end
            end
        end
        for _, entry in next, fontdata do
            local designsize = entry["designsize"] or 100
            if designsize == 100 or designsize == 110 or designsize == 120 or designsize == 0 or #fontdata == 1 then
                local filepath, filename = splitbase(entry["filename"])
                if entry["format"] == "ttc" or entry["format"] == "dfont" then
                    filename = formatters["%s(%s)"](filename, entry["rawname"])
                end
                registerdesignsizes( fontfile, "default", filename )
                break
            end
        end
        if fallback then
            context.definefontsynonym( { fontname }, { fontfile }, { features = features } )
        else
            context.definefontsynonym( { fontname }, { fontfile }, { features = features, fallbacks = fontfile, goodies = goodies } )
        end
    else
        if fallback then
            context.definefontsynonym( { fontname }, { fontparent }, { features = features } )
        else
            context.definefontsynonym( { fontname }, { fontparent }, { features = features, fallbacks = fontfile, goodies = goodies } )
        end
    end
end

local function definetypescript(index)
    local data         = data[index]
    local entry        = data.fonts
    local mathsettings = mathsettings[cleanname(data.metadata.family)]
    local goodies      = mathsettings and mathsettings.extras or data.options.goodies
    local typeface     = data.metadata.typeface
    local style        = data.metadata.style
    if entry and entry["tf"] then
        context.startfontclass( { typeface } )
        if goodies ~= "" then
            goodies = utilities.parsers.settings_to_array(goodies)
            for _, goodie in next, goodies do
                context.loadfontgoodies( { goodie } )
            end
        end
        for alternative, _ in next, alternatives do
            if synonyms[style][alternative] then -- prevent unnecessary synonyms for handwriting, calligraphy and math
                definefontsynonym(data,alternative)
            end
        end
        context.stopfontclass()
    else
        -- regular style not available, loading aborted
    end
end

function selectfont.registerfallback(typeface,style,index)
    local t = fallbacks[typeface]
    if not t then
        fallbacks[typeface] = { [style] = { index } }
    else
        local s = t[style]
        if not s then
            fallbacks[typeface][style] = { index }
        else
            fallbacks[typeface][style][#s+1] = index
        end
    end
end

local function definetextfontfallback(data,alternative,index)
    local typeface = data.metadata.typeface
    local style    = data.metadata.style
    local features = data.features[alternative]
    local range    = data.options.range
    local rscale   = data.options.scale ~= "" and data.options.scale or 1
    local check    = data.options.check ~= "" and data.options.check or "yes"
    local force    = data.options.force ~= "" and data.options.force or "yes"
    local synonym  = formatters["%s-%s-%s-fallback-%s"](typeface, style, alternative, index)
    local fallback = formatters["%s-%s-%s"]            (typeface, style, alternative)
    if index == 1 then
        context.resetfontfallback( { fallback } )
    end
    context.definefontfallback( { fallback }, { synonym }, { range }, { rscale = rscale, check = check, force = force } )
end

local function definetextfallback(entry,index)
    local data     = data[index]
    local typeface = data.metadata.typeface
    context.startfontclass( { typeface } )
    for alternative, _ in next, alternatives do
        definefontsynonym     (data,alternative,entry,true)
        definetextfontfallback(data,alternative,entry)
    end
    context.stopfontclass()
    -- inspect(data)
end

local function definemathfontfallback(data,alternative,index)
    local typeface = data.metadata.typeface
    local style    = data.metadata.style
    local range    = data.options.range
    local rscale   = data.options.scale ~= "" and data.options.scale or 1
    local check    = data.options.check ~= "" and data.options.check or "yes"
    local force    = data.options.force ~= "" and data.options.force or "yes"
    local offset   = data.options.offset
    local features = data.features[alternative]
    local fontdata = data.fonts and data.fonts[alternative]
    local fallback = formatters["%s-%s-%s"](typeface, style, alternative)
    if index == 1 then
        context.resetfontfallback( { fallback } )
    end
    if fontdata and #fontdata > 0 then
        for _, entry in next, fontdata do
            local filename   = entry["filename"]
            local designsize = entry["designsize"] or 100
            if designsize == 100 or designsize == 110 or designsize == 120 or designsize == 0 or #fontdata == 1 then
                context.definefontfallback( { fallback }, { formatters["file:%s*%s"](filename,features) }, { range }, { rscale = rscale, check = check, force = force, offset = offset } )
                break
            end
        end
    end
end

local function definemathfallback(entry,index)
    local data     = data[index]
    local typeface = data.metadata.typeface
    local style    = data.metadata.style
    context.startfontclass( { typeface } )
    for alternative, _ in next, alternatives do
        if synonyms[style][alternative] then
            definemathfontfallback(data,alternative,entry)
        end
    end
    context.stopfontclass()
    -- inspect(data)
end

local function definefallbackfont(index)
    local data = data[index]
    local f    = fallbacks[data.metadata.typeface]
    if f then
        local s = f[data.metadata.style]
        if s then
            for entry, fallback in next, s do
                if data.metadata.style == "mm" then
                    definemathfallback(entry,fallback)
                else
                    definetextfallback(entry,fallback)
                end
            end
        end
    end
end

local function definetextfont(index)
    local data       = data[index]
    local fontclass  = data.metadata.typeface
    local shortstyle = data.metadata.style
    local style      = styles[data.metadata.style]
    local designsize = data.options.opticals == v_yes and "auto" or "default"
    local scale      = data.options.scale ~= "" and data.options.scale or 1
    context.definetypeface( { fontclass }, { shortstyle }, { style }, { "" }, { "default" }, { designsize = designsize, rscale = scale } )
end

local function definemathfont(index)
    local data       = data[index]
    local fontclass  = data.metadata.typeface
    local shortstyle = data.metadata.style
    local style      = styles[data.metadata.style]
    local scale      = data.options.scale ~= "" and data.options.scale or 1
    local typescript = cleanname(data.metadata.family)
    local entries    = data.fonts
    if entries then
        context.definetypeface( { fontclass }, { shortstyle }, { style }, { "" }, { "default" }, { rscale = scale } )
    else
        context.definetypeface( { fontclass }, { shortstyle }, { style }, { typescript }, { "default" }, { rscale = scale } )
    end
end

function selectfont.definetypeface(index)
    local data = data[index]
    if data.metadata.style == "mm" then
        definefallbackfont(index)
        definetypescript  (index)
        definemathfont    (index)
    else
        definefallbackfont(index)
        definetypescript  (index)
        definetextfont    (index)
    end
    -- inspect(data)
end

commands.definefontfamily     = selectfont.definetypeface
commands.definefallbackfamily = selectfont.registerfallback
