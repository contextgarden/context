if not modules then modules = { } end modules ['font-sel'] = {
    version   = 1.001,
    comment   = "companion to font-sel.mkvi",
    author    = "Wolfgang Schuster",
    copyright = "Wolfgang Schuster",
    license   = "GNU General Public License"
}

local next, type = next, type

local context                    = context
local cleanname                  = fonts.names.cleanname
local gsub, splitup, find, lower = string.gsub, string.splitup, string.find, string.lower
local concat, sortedkeys         = table.concat, table.sortedkeys
local merge, remove              = table.merge, table.remove
local splitbase, removesuffix    = file.splitbase, file.removesuffix
local splitat, lpegmatch         = lpeg.splitat, lpeg.match

local formatters                 = string.formatters
local settings_to_array          = utilities.parsers.settings_to_array
local settings_to_hash           = utilities.parsers.settings_to_hash
local allocate                   = utilities.storage.allocate

local v_default                  = interfaces.variables.default

local implement                  = interfaces.implement

local fonts                      = fonts

local getlookups                 = fonts.names.getlookups
local registerdesignsizes        = fonts.goodies.designsizes.register
local bodyfontsizes              = storage.shared.bodyfontsizes

fonts.select                     = fonts.select or { }
local selectfont                 = fonts.select

selectfont.data                  = selectfont.data         or allocate()
selectfont.fallbacks             = selectfont.fallbacks    or allocate()
selectfont.methods               = selectfont.methods      or allocate()
selectfont.extras                = selectfont.extras       or allocate()
selectfont.alternatives          = selectfont.alternatives or allocate()
selectfont.presets               = selectfont.presets      or allocate()
selectfont.defaults              = selectfont.defaults     or allocate()

storage.register("fonts/select/presets", selectfont.presets, "fonts.select.presets")

local data                       = selectfont.data
local fallbacks                  = selectfont.fallbacks
local methods                    = selectfont.methods
local extras                     = selectfont.extras
local alternatives               = selectfont.alternatives
local presets                    = selectfont.presets
local defaults                   = selectfont.defaults

local ctx_definefontsynonym      = context.definefontsynonym
local ctx_resetfontfallback      = context.resetfontfallback
local ctx_startfontclass         = context.startfontclass
local ctx_stopfontclass          = context.stopfontclass
local ctx_loadfontgoodies        = context.loadfontgoodies
local ctx_definefontfallback     = context.definefontfallback
local ctx_definetypeface         = context.definetypeface
local ctx_definebodyfont         = context.definebodyfont

local trace_register     = false  trackers.register("selectfont.register",     function(v) trace_register     = v end)
local trace_files        = false  trackers.register("selectfont.files",        function(v) trace_files        = v end)
local trace_features     = false  trackers.register("selectfont.features",     function(v) trace_features     = v end)
local trace_goodies      = false  trackers.register("selectfont.goodies",      function(v) trace_goodies      = v end)
local trace_alternatives = false  trackers.register("selectfont.alternatives", function(v) trace_alternatives = v end)
local trace_typescript   = false  trackers.register("selectfont.typescripts",  function(v) trace_typescript   = v end)

local report_selectfont   = logs.reporter("selectfont")
local report_files        = logs.reporter("selectfont","files")
local report_features     = logs.reporter("selectfont","features")
local report_goodies      = logs.reporter("selectfont","goodies")
local report_typescript   = logs.reporter("selectfont","typescripts")

defaults["rm"] = { features = { ["sc"] = "*,f:smallcaps" } }
defaults["ss"] = { features = { ["sc"] = "*,f:smallcaps" } }

defaults["asanamath"]          = { options = { extras = "asana-math",           features = "math\\mathsizesuffix",         goodies = "anana-math"           } }
defaults["cambriamath"]        = { options = { extras = "cambria-math",         features = "math\\mathsizesuffix",         goodies = "cambria-math"         } }
defaults["dejavumath"]         = { options = { extras = "dejavu",               features = "math\\mathsizesuffix"                                           } }
defaults["neoeuler"]           = { options = { extras = "euler-math",           features = "math\\mathsizesuffix"                                           } }
defaults["latinmodernmath"]    = { options = { extras = "lm,lm-math",           features = "math\\mathsizesuffix,lm-math", goodies = "lm"                   } }
defaults["lucidabrightmathot"] = { options = { extras = "lucida-opentype-math", features = "math\\mathsizesuffix",         goodies = "lucida-opentype-math" } }
defaults["minionmath"]         = { options = { extras = "minion-math",          features = "math\\mathsizesuffix",         goodies = "minion-math"          } }
defaults["texgyredejavumath"]  = { options = { extras = "dejavu",               features = "math\\mathsizesuffix"                                           } }
defaults["texgyrepagellamath"] = { options = { extras = "texgyre",              features = "math\\mathsizesuffix"                                           } }
defaults["texgyrebonummath"]   = { options = { extras = "texgyre",              features = "math\\mathsizesuffix"                                           } }
defaults["texgyrescholamath"]  = { options = { extras = "texgyre",              features = "math\\mathsizesuffix"                                           } }
defaults["texgyretermesmath"]  = { options = { extras = "texgyre",              features = "math\\mathsizesuffix"                                           } }
defaults["xitsmath"]           = { options = { extras = "xits-math",            features = "math\\mathsizesuffix",         goodies = "xits-math"            } }

extras["features"] = function(data,alternative,features)
    local d = data.options.features
    local e = gsub(gsub(features,"*",d),"{(.*)}","%1")
    local f = data.features
    if trace_features then
        report_features("Alternative '%s': Saving features '%s'",alternative,e)
    end
    if not f then
        f = { }
        data.features = f
    end
    f[alternative] = e
end

extras["goodies"] = function(data,alternative,goodies)
    local e = gsub(goodies,"{(.*)}","%1")
    local g = data.goodies
    if trace_goodies then
        report_goodies("Alternative '%s': Saving goodies '%s'",alternative,e)
    end
    if not g then
        g = { }
        data.goodies = g
    end
    g[alternative] = e
end

local function selectfont_savefile(data,alternative,bodyfontsize,size,file)
    local f    = data.files
    local p, n = splitbase(file["filename"])
    local t    = file["format"]
    local r    = file["rawname"]
    if t == "ttc" then
        n = formatters["%s(%s)"](n,r)
    end
    if not f then
        f = { }
        data.files = f
    end
    local a = f[alternative]
    if not a then
        a = { }
        f[alternative] = a
    end
    a[bodyfontsize] = { size, n }
    if trace_files then
        report_files("Alternative '%s': Saving file '%s' for size '%s'",alternative,n,size)
    end
end

methods["name"] = function(data,alternative,name)
    local family   = data.metadata.family
    local filename = cleanname(gsub(name,"*",family))
    if trace_alternatives then
        report_selectfont("Alternative '%s': Using method 'name' with argument '%s'",alternative,filename)
    end
    local fontname = getlookups{ fontname = filename }
    local fullname = getlookups{ fullname = filename }
    if #fontname > 0 then
        selectfont_savefile(data,alternative,0,"default",fontname[1])
    elseif #fullname > 0 then
        selectfont_savefile(data,alternative,0,"default",fullname[1])
    else
        if trace_alternatives then
            report_selectfont("Alternative '%s': No font was found for the requested name '%s'",alternative,filename)
        end
    end
end

methods["file"] = function(data,alternative,file)
    local family   = data.metadata.family
    local filename = cleanname(gsub(removesuffix(file),"*",family))
    if trace_alternatives then
        report_selectfont("Alternative '%s': Using method 'file' with argument '%s'",alternative,filename)
    end
    local filename = getlookups{ cleanfilename = cleanname(filename) }
    if #filename > 0 then
        selectfont_savefile(data,alternative,0,"default",filename[1])
    else
        if trace_alternatives then
            report_selectfont("Alternative '%s': No font was found for the requested file '%s'",alternative,cleanname(gsub(removesuffix(file),"*",family)))
        end
    end
end

local m_weight = {
    ["thin"]       = 100,
    ["extralight"] = 200,
    ["light"]      = 300,
    ["regular"]    = 400,
    ["medium"]     = 500,
    ["semibold"]   = 600,
    ["bold"]       = 700,
    ["extrabold"]  = 800,
    ["black"]      = 900
}

local m_width = {
    ["ultracondensed"] = 1,
    ["extracondensed"] = 2,
    ["condensed"]      = 3,
    ["semicondensed"]  = 4,
    ["normal"]         = 5,
    ["semiexpanded"]   = 6,
    ["expanded"]       = 7,
    ["extraexpanded"]  = 8,
    ["ultraexpanded"]  = 9,
}

local m_name = {
    ["thin"]             = { weight = "thin"                                       },
    ["thinitalic"]       = { weight = "thin",                  style = "italic"    },
    ["extralight"]       = { weight = "extralight"                                 },
    ["extralightitalic"] = { weight = "extralight",            style = "italic"    },
    ["light"]            = { weight = "light"                                      },
    ["lightitalic"]      = { weight = "light",                 style = "italic"    },
    ["regular"]          = { weight = { "regular", "medium" }                      },
    ["italic"]           = { weight = { "regular", "medium" }, style = "italic"    },
    ["medium"]           = { weight = "medium"                                     },
    ["mediumitalic"]     = { weight = "medium",                style = "italic"    },
    ["semibold"]         = { weight = "semibold"                                   },
    ["semibolditalic"]   = { weight = "semibold",              style = "italic"    },
    ["bold"]             = { weight = { "bold", "semibold" }                       },
    ["bolditalic"]       = { weight = { "bold", "semibold" },  style = "italic"    },
    ["extrabold"]        = { weight = "extrabold"                                  },
    ["extrabolditalic"]  = { weight = "extrabold",             style = "italic"    },
    ["black"]            = { weight = "black"                                      },
    ["blackitalic"]      = { weight = "black",                 style = "italic"    },
    ["smallcaps"]        = { weight = "regular",             variant = "smallcaps" },
}

local m_alternative = {
    ["tf"] = "regular",
    ["bf"] = "bold",
    ["it"] = "italic",
    ["sl"] = "italic",
    ["bi"] = "bolditalic",
    ["bs"] = "bolditalic",
    ["sc"] = "smallcaps"
}

local function m_style_family(family)
    local askedname  = cleanname(family)
    local familyname = getlookups{ familyname = askedname }
    local family     = getlookups{ family     = askedname }
    local fontname   = getlookups{ fontname   = askedname }
    if #familyname > 0 then
        return familyname
    elseif #family > 0 then
        return family
    elseif #fontname > 0 then
        local fontfamily = fontname[1]["familyname"]
        report_selectfont("The name '%s' is not a proper family name, use '%s' instead.",askedname,fontfamily)
        return nil
    else
        return nil
    end
end

local function m_style_subfamily(entries,style,family)
    local t      = { }
    local style  = cleanname(style)
    local family = cleanname(family)
    for index, entry in next, entries do
        if entry["familyname"] == family and entry["subfamilyname"] == style then -- familyname + subfamilyname
            t[#t+1] = entry
        elseif entry["family"] == family and entry["subfamily"] == style then -- family + subfamily
            t[#t+1] = entry
        end
    end
    return #t ~= 0 and t or nil
end

local function m_style_weight(entries,style)
    local t = { }
    local weight    = m_name[style] and m_name[style]["weight"] or "regular"
    if type(weight) == "table" then
        for _, w in next, weight do
            local found = false
            local pfmweight = m_weight[w]
            for index, entry in next, entries do
                if entry["pfmweight"] == pfmweight then
                    found = true
                    t[#t+1] = entry
                elseif entry["weight"] == w then
                    found = true
                    t[#t+1] = entry
                end
            end
            if found then break end
        end
    else
        local pfmweight = m_weight[weight]
        for index, entry in next, entries do
            if entry["pfmweight"] == pfmweight then
                t[#t+1] = entry
            elseif entry["weight"] == weight then
                t[#t+1] = entry
            end
        end
    end
    return #t ~= 0 and t or nil
end

local function m_style_style(entries,style)
    local t = { }
    local style = m_name[style] and m_name[style]["style"] or "normal"
    for index, entry in next, entries do
        if style == "italic" and entry["angle"] and entry["angle"] ~= 0 then
            t[#t+1] = entry
        elseif style == "normal" and entry["angle"] and entry["angle"] ~= 0 then
         -- Fix needed for fonts with wrong value for the style field
        elseif entry["style"] == style then
            t[#t+1] = entry
        end
    end
    return #t ~= 0 and t or nil
end

local function m_style_variant(entries,style)
    local t = { }
    local variant = m_name[style] and m_name[style]["variant"] or "normal"
    for index, entry in next, entries do
        if entry["variant"] == variant then
            t[#t+1] = entry
        end
    end
    return #t ~= 0 and t or nil
end

local function m_style_width(entries,style)
    local t = { }
    local width    = m_name[style] and m_name[style]["width"] or "normal"
    local pfmwidth = m_width[width]
    for index, entry in next, entries do
        if entry["pfmwidth"] == pfmwidth then
            t[#t+1] = entry
        end
    end
    return #t ~= 0 and t or nil
end

local function m_style_size(data,alternative,entries)
    if #entries == 1 then
        selectfont_savefile(data,alternative,0,"default",entries[1])
    else
        for index, entry in next, entries do
            local minsize = entry["minsize"]
            local maxsize = entry["maxsize"]
            if minsize and maxsize then
                for size, state in next, bodyfontsizes do
                    local bodyfontsize, _ = number.splitdimen(size)
                          bodyfontsize    = bodyfontsize * 10
                    if minsize < bodyfontsize and bodyfontsize < maxsize then
                        if bodyfontsize == 100 then
                            selectfont_savefile(data,alternative,0,"default",entry)
                        end
                        selectfont_savefile(data,alternative,bodyfontsize,size,entry)
                    end
                end
            else
                if trace_alternatives then
                    report_selectfont("Alternative '%s': Multiple files are available for the requested style '%s' from '%s'",alternative,style,family)
                end
            end
        end
    end
end

methods["style"] = function(data,alternative,style)
    local fontfamily = data.metadata.family
    local designsize = data.options.designsize
    local fontstyle  = m_alternative[style] or style
    local entries    = m_style_family(fontfamily)
    if entries then
        local subfamily = m_style_subfamily(entries,fontstyle,fontfamily)
        if subfamily then
            entries = subfamily
        else
            entries = m_style_weight(entries,fontstyle)
            if entries then
                entries = m_style_style(entries,fontstyle)
                if entries then
                    entries = m_style_variant(entries,fontstyle)
                    if entries and #entries > 1 and designsize == "default" then
                        entries = m_style_width(entries,fontstyle)
                    end
                end
            end
        end
    end
    if entries then
        m_style_size(data,alternative,entries)
    else
        if trace_alternatives then
            report_selectfont("Alternative '%s': No font was found for the requested style '%s' from '%s'",alternative,style,family)
        end
    end
end

methods[v_default] = function(data,alternative)
    local family = data.metadata.family
    if trace_alternatives then
        report_selectfont("Alternative '%s': Using method 'default'",alternative)
    end
    local result = getlookups{ familyname = cleanname(family) }
    if #result == 1 and alternative == "tf" then
        if trace_alternatives then
            report_selectfont("Alternative '%s': The family '%s' contains only one font",alternative,family)
        end
        selectfont_savefile(data,alternative,0,"default",result[1])
     -- if trace_alternatives then
     --     report_selectfont("Alternative '%s': Changing method 'default' to method 'style'",alternative)
     -- end
     -- methods["file"](data,alternative,result[1]["filename"])
    else
        if trace_alternatives then
            report_selectfont("Alternative '%s': Changing method 'default' to method 'style'",alternative)
        end
        methods["style"](data,alternative,alternative)
    end
end

local function selectfont_savealternative(data,alternative,userdata)
    local a = data.alternatives
    local e = userdata[alternative]
    if not a then
        a = { }
        data.alternatives = a
    end
    a[alternative] = e
end

function selectfont.fontdata(index)
    local data     = data[index]
    local style    = data.metadata.style
    local defaults = defaults[style]
    if defaults then
        for category, argument in next, defaults do
            local extra  = extras[category]
            if extra then
                for alternative, entry in next, argument do
                    extra(data,alternative,entry)
                end
            end
        end
    end
end

function selectfont.userdata(index)
    local data     = data[index]
    local preset   = data.options.preset
    local presets  = presets[preset]
    local userdata = settings_to_hash(data.userdata)
    if presets then
        merge(userdata,presets)
    end
    for alternative, _ in next, alternatives do
        selectfont_savealternative(data,alternative,userdata)
    end
end

function selectfont.registerfiles(index)
    local data  = data[index]
    local colon = splitat(":",true)
    for alternative, _ in next, alternatives do
        local arguments = data.alternatives[alternative]
        if arguments and arguments ~= "" then
            local entries = settings_to_array(arguments)
            for index, entry in next, entries do
                method, argument = lpegmatch(colon,entry)
                if not argument then
                    argument = method
                    method   = "name"
                end
                (extras[method] or methods[method] or methods[v_default])(data,alternative,argument)
            end
        else
            methods[v_default](data,alternative)
        end
    end
end

function selectfont.registerfontalternative(alternative)
    local a = alternatives[alternative]
    if not a then
        if trace_register then
            report_selectfont("Register alternative '%s'",alternative)
        end
        a = true
        alternatives[alternative] = a
    end
end

function selectfont.registerfallback(index)
    local data      = data[index]
    local fontclass = data.metadata.typeface
    local fontstyle = data.metadata.style
    local fallback  = fallbacks[fontclass]
    if not fallback then
        fallback = { }
        fallbacks[fontclass] = fallback
    end
    local entries = fallback[fontstyle]
    if not entries then
        entries = { }
        fallback[fontstyle] = entries
    end
    entries[#entries+1] = index
end

function selectfont.registerfontfamily(settings)
    local index = #data + 1
    data[index] = settings
    selectfont.fontdata     (index)
    selectfont.userdata     (index)
    selectfont.registerfiles(index)
    return index
end

local m_synonym = {
    ["rm"] = {
        ["tf"] = "Serif",
        ["bf"] = "SerifBold",
        ["it"] = "SerifItalic",
        ["sl"] = "SerifSlanted",
        ["bi"] = "SerifBoldItalic",
        ["bs"] = "SerifBoldSlanted",
        ["sc"] = "SerifCaps",
    },
    ["ss"] = {
        ["tf"] = "Sans",
        ["bf"] = "SansBold",
        ["it"] = "SansItalic",
        ["sl"] = "SansSlanted",
        ["bi"] = "SansBoldItalic",
        ["bs"] = "SansBoldSlanted",
        ["sc"] = "SansCaps",
    },
    ["tt"] = {
        ["tf"] = "Mono",
        ["bf"] = "MonoBold",
        ["it"] = "MonoItalic",
        ["sl"] = "MonoSlanted",
        ["bi"] = "MonoBoldItalic",
        ["bs"] = "MonoBoldSlanted",
        ["sc"] = "MonoCaps",
    },
    ["mm"] = {
        ["tf"] = "MathRoman",
        ["bf"] = "MathBold",
    },
    ["hw"] = {
        ["tf"] = "Handwriting",
    },
    ["cg"] = {
        ["tf"] = "Calligraphy",
    },
}

function selectfont.features(data,style,alternative)
    local family   = data.metadata.family
    local features = data.features
    local options  = data.options
    local defaults = defaults[cleanname(family)]
    if features and features[alternative] then
        return features[alternative]
    elseif defaults and defaults.options and defaults.options.features then
        return defaults.options.features
    else
        return options.features
    end
end

function selectfont.goodies(data,style,alternative)
    local family   = data.metadata.family
    local goodies  = data.goodies
    local options  = data.options
    local defaults = defaults[cleanname(family)]
    if goodies and goodies[alternative] then
        return goodies[alternative]
    elseif defaults and defaults.options and defaults.options.goodies then
        return defaults.options.goodies
    else
        return options.goodies
    end
end

function selectfont.fontsynonym(data,class,style,alternative,index)
    local fontfiles    = data.files[alternative] or data.files["tf"]
    local fontsizes    = sortedkeys(fontfiles)
    local fallback     = index ~= 0
    local fontclass    = lower(class)
  --local fontfeature  = data.features and data.features[alternative] or data.options.features
  --local fontgoodie   = data.goodies  and data.goodies [alternative] or data.options.goodies
    local fontfeature  = selectfont.features(data,style,alternative)
    local fontgoodie   = selectfont.goodies (data,style,alternative)
    local synonym      = m_synonym[style] and m_synonym[style][alternative]
    local fontfile     = formatters    ["file-%s-%s-%s"](fontclass,style,alternative)
    local fontsynonym  = formatters ["synonym-%s-%s-%s"](fontclass,style,alternative)
    if fallback then
        fontfile     = formatters    ["file-%s-%s-%s-%s"](fontclass,style,alternative,index)
        fontsynonym  = formatters ["synonym-%s-%s-%s-%s"](fontclass,style,alternative,index)
    end
    local fontfallback = formatters["fallback-%s-%s-%s"](fontclass,style,alternative)
    for _, fontsize in next, fontsizes do
     -- if trace_typescript then
     --     report_typescript("Synonym: '%s', Size: '%s', File: '%s'",fontfile,fontfiles[fontsize][1],fontfiles[fontsize][2])
     -- end
        registerdesignsizes(fontfile,fontfiles[fontsize][1],fontfiles[fontsize][2])
    end
    if fallback then
     -- if trace_typescript then
     --     report_typescript("Synonym: '%s', File: '%s', Features: '%s'",fontsynonym,fontfile,fontfeature)
     -- end
        ctx_definefontsynonym( { fontsynonym }, { fontfile }, { features = fontfeature } )
    else
     -- if trace_typescript then
     --     report_typescript("Synonym: '%s', File: '%s', Features: '%s', Goodies: '%s', Fallbacks: '%s'",fontsynonym,fontfile,fontfeature,fontgoodie,fontfallback)
     -- end
        ctx_definefontsynonym( { fontsynonym }, { fontfile }, { features = fontfeature, goodies = fontgoodie, fallbacks = fontfallback } )
        if synonym then
         -- if trace_typescript then
         --     report_typescript("Synonym: '%s', File: '%s'",synonym,fontsynonym)
         -- end
            ctx_definefontsynonym( { synonym }, { fontsynonym } )
        end
    end
end

function selectfont.fontfallback(data,class,style,alternative,index)
    local range        = data.options.range
    local scale        = data.options.rscale ~= "" and data.options.rscale or 1
    local check        = data.options.check  ~= "" and data.options.check  or ""
    local force        = data.options.force  ~= "" and data.options.force  or ""
    local fontfeature  = data.features and data.features[alternative] or data.options.features
    local fontclass    = lower(class)
    local fontsynonym  = formatters ["synonym-%s-%s-%s-%s"](fontclass,style,alternative,index)
    local fontfallback = formatters["fallback-%s-%s-%s"]   (fontclass,style,alternative)
    if index == 1 then
        ctx_resetfontfallback( { fontfallback } )
    end
 -- if trace_typescript then
 --     report_typescript("Fallback: '%s', Synonym: '%s', Range: '%s', Scale: '%s', Check: '%s', Force: '%s'",fontfallback,fontsynonym,range,scale,check,force)
 -- end
    ctx_definefontfallback( { fontfallback }, { fontsynonym }, { range }, { rscale = scale, check = check, force = force } )
end

function selectfont.filefallback(data,class,style,alternative,index)
    local range        = data.options.range
    local offset       = data.options.offset
    local scale        = data.options.rscale ~= "" and data.options.rscale or 1
    local check        = data.options.check  ~= "" and data.options.check  or "yes"
    local force        = data.options.force  ~= "" and data.options.force  or "yes"
    local fontfile     = data.files[alternative] and data.files[alternative][0] or data.files["tf"][0]
    local fontfeature  = data.features and data.features[alternative] or data.options.features
    local fontclass    = lower(class)
    local fontfallback = formatters["fallback-%s-%s-%s"](fontclass,style,alternative)
    if index == 1 then
        ctx_resetfontfallback( { fontfallback } )
    end
 -- if trace_typescript then
 --     report_typescript("Fallback: '%s', File: '%s', Features: '%s', Range: '%s', Scale: '%s', Check: '%s', Force: '%s', Offset: '%s'",fontfallback,fontfile[2],fontfeature,range,scale,check,force,offset)
 -- end
    ctx_definefontfallback( { fontfallback }, { formatters["file:%s*%s"](fontfile[2],fontfeature) }, { range }, { rscale = scale, check = check, force = force, offset = offset } )
end

function selectfont.mathfallback(index,entry,class,style)
    local data = data[entry]
    ctx_startfontclass( { class } )
        for alternative, _ in next, alternatives do
            if alternative == "tf" or alternative == "bf" then
                selectfont.filefallback(data,class,style,alternative,index)
            end
        end
    ctx_stopfontclass()
end

function selectfont.textfallback(index,entry,class,style)
    local data = data[entry]
    ctx_startfontclass( { class } )
        for alternative, _ in next, alternatives do
            selectfont.fontsynonym (data,class,style,alternative,index)
            selectfont.fontfallback(data,class,style,alternative,index)
        end
    ctx_stopfontclass()
end

function selectfont.fallback(data)
    local fontclass = data.metadata.typeface
    local fontstyle = data.metadata.style
    local fallbacks = fallbacks[fontclass] and fallbacks[fontclass][fontstyle]
    if fallbacks then
        for index, entry in next, fallbacks do
         -- I need different fallback routines for math and text because
         -- font synonyms can’t be used with math fonts and I have to apply
         -- feature settings with the \definefontfallback command.
            if fontstyle == "mm" then
                selectfont.mathfallback(index,entry,fontclass,fontstyle)
            else
                selectfont.textfallback(index,entry,fontclass,fontstyle)
            end
        end
    end
end

function selectfont.typescript(data)
    local class    = data.metadata.typeface
    local family   = data.metadata.family
    local style    = data.metadata.style
    local extras   = data.options.extras
    local defaults = defaults[cleanname(family)]
    if extras == "" then
        extras = defaults and defaults.options and defaults.options.extras or ""
    end
    ctx_startfontclass( { class } )
        if extras ~= "" then
            extras = settings_to_array(extras)
            for _, extra in next, extras do
                ctx_loadfontgoodies( { extra } )
            end
        end
        for alternative, _ in next, alternatives do
            if style == "mm" then
             -- Set math fonts only for upright and bold alternatives
                if alternative == "tf" or alternative == "bf" then
                    selectfont.fontsynonym (data,class,style,alternative,0)
                end
            else
                selectfont.fontsynonym (data,class,style,alternative,0)
            end
        end
    ctx_stopfontclass()
end

function selectfont.bodyfont(data)
    local class       = data.metadata.typeface
    local fontstyle   = data.metadata.style
    local fontclass   = lower(class)
    local fontsizes   = concat(sortedkeys(bodyfontsizes),",")
    local fontsynonym = nil
    local fontlist    = { }
    for alternative, _ in next, alternatives do
        fontsynonym           = formatters["synonym-%s-%s-%s"](fontclass,fontstyle,alternative)
        fontlist[#fontlist+1] = formatters["%s=%s sa 1"]      (alternative,fontsynonym)
     -- if trace_typescript then
     --     report_typescript("Alternative '%s': Synonym '%s'",alternative,fontsynonym)
     -- end
    end
    fontlist = concat(fontlist,",")
    ctx_definebodyfont( { class }, { fontsizes }, { fontstyle }, { fontlist } )
end

local m_style = {
    ["rm"] = "serif",
    ["ss"] = "sans",
    ["tt"] = "mono",
    ["mm"] = "math",
    ["hw"] = "handwriting",
    ["cg"] = "calligraphy",
}

function selectfont.typeface(data)
    local fontclass = data.metadata.typeface
    local fontstyle = data.metadata.style
    local style     = m_style[fontstyle]
    local size      = data.options.designsize ~= "" and data.options.designsize or "default"
    local scale     = data.options.rscale     ~= "" and data.options.rscale     or 1
 -- if trace_typescript then
 --     report_typescript("Class: '%s', Style: '%s', Size: '%s', Scale: '%s'",fontclass,fontstyle,size,scale)
 -- end
    ctx_definetypeface( { fontclass }, { fontstyle }, { style }, { "" }, { "default" }, { designsize = size, rscale = scale } )
end

function selectfont.default(data)
    local family    = data.metadata.family
    local fontclass = data.metadata.typeface
    local fontstyle = data.metadata.style
    local style     = m_style[fontstyle]
    report_selectfont("The requested font '%s' has no files for the 'tf' alternative, Latin Modern is used instead.",family)
    ctx_definetypeface( { fontclass }, { fontstyle }, { style }, { "modern" }, { "default" } )
end

function selectfont.definefontfamily(index)
    local data      = data[index]
    local fontstyle = data.metadata.style
    local fontfiles = data.files and data.files["tf"]
    if fontfiles then
        selectfont.fallback  (data)
        selectfont.typescript(data)
        if fontstyle ~= "mm" then
            selectfont.bodyfont(data)
        end
        selectfont.typeface(data)
    else
        selectfont.default(data)
    end
end

function selectfont.definefallbackfamily(index)
    local data      = data[index]
    local family    = data.metadata.family
    local fontclass = data.metadata.typeface
    local fontstyle = data.metadata.style
    local fontfiles = data.files
    if fontfiles then
        selectfont.registerfallback(index)
    else
        report_selectfont("The requested fallback font '%s' for typeface '%s' style '%s' was ignored because no files where found.",family,fontclass,fontstyle)
    end
end

function selectfont.definefontfamilypreset(name,data)
    local p = presets[name]
    local d = settings_to_hash(data)
    if not p then
        p = d
        presets[name] = p
    end
end

implement {
    name      = "registerfontfamily",
    actions   = { selectfont.registerfontfamily, context },
    arguments = {
        {
            {
                "metadata", {
                    { "typeface" },
                    { "style" },
                    { "family" }
                }
            },
            {
                "options", {
                    { "designsize" },
                    { "rscale" },
                    { "goodies" },
                    { "preset" },
                    { "extras" },
                    { "features" },
                    { "range" },
                    { "offset" },
                    { "check" },
                    { "force" }
                }
            },
            {
                "userdata"
            }
        }
    }
}

implement {
    name      = "registerfontalternative",
    actions   = selectfont.registerfontalternative,
    arguments = "string"
}

implement {
    name      = "definefontfamily",
    actions   = selectfont.definefontfamily,
    arguments = "integer"
}

implement {
    name      = "definefallbackfamily",
    actions   = selectfont.definefallbackfamily,
    arguments = "integer"
}

implement {
    name      = "definefontfamilypreset",
    actions   = selectfont.definefontfamilypreset,
    arguments = "2 strings",
}
