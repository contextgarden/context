if not modules then modules = { } end modules ['font-syn'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: subs in lookups requests
-- todo: see if the (experimental) lua reader (on my machine) be used (it's a bit slower so maybe wait till lua 5.3)

-- identifying ttf/otf/ttc/afm : 2200 fonts:
--
-- old ff  loader: 140 sec
-- new lua loader:   5 sec

-- maybe find(...,strictname,1,true)

local next, tonumber, type, tostring = next, tonumber, type, tostring
local sub, gsub, match, find, lower, upper = string.sub, string.gsub, string.match, string.find, string.lower, string.upper
local concat, sort, fastcopy, tohash = table.concat, table.sort, table.fastcopy, table.tohash
local serialize, sortedhash = table.serialize, table.sortedhash
local lpegmatch = lpeg.match
local unpack = unpack or table.unpack
local formatters, topattern = string.formatters, string.topattern
local round = math.round
local P, R, S, C, Cc, Ct, Cs = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cc, lpeg.Ct, lpeg.Cs
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local isfile, modificationtime = lfs.isfile, lfs.modification

local allocate             = utilities.storage.allocate
local sparse               = utilities.storage.sparse
local setmetatableindex    = table.setmetatableindex

local removesuffix         = file.removesuffix
local splitbase            = file.splitbase
local splitname            = file.splitname
local basename             = file.basename
local nameonly             = file.nameonly
local pathpart             = file.pathpart
local suffixonly           = file.suffix
local filejoin             = file.join
local is_qualified_path    = file.is_qualified_path
local exists               = io.exists

local findfile             = resolvers.findfile
local cleanpath            = resolvers.cleanpath
local resolveprefix        = resolvers.resolve

local settings_to_hash     = utilities.parsers.settings_to_hash_tolerant

local trace_names          = false  trackers.register("fonts.names",          function(v) trace_names          = v end)
local trace_warnings       = false  trackers.register("fonts.warnings",       function(v) trace_warnings       = v end)
local trace_specifications = false  trackers.register("fonts.specifications", function(v) trace_specifications = v end)
local trace_rejections     = false  trackers.register("fonts.rejections",     function(v) trace_rejections     = v end)

local report_names         = logs.reporter("fonts","names")

--[[ldx--
<p>This module implements a name to filename resolver. Names are resolved
using a table that has keys filtered from the font related files.</p>
--ldx]]--

fonts                      = fonts or { } -- also used elsewhere

local names                = fonts.names or allocate { }
fonts.names                = names

local filters              = names.filters or { }
names.filters              = filters

local treatments           = fonts.treatments or { }
fonts.treatments           = treatments

names.data                 = names.data or allocate { }

names.version              = 1.131
names.basename             = "names"
names.saved                = false
names.loaded               = false
names.be_clever            = true
names.enabled              = true
names.cache                = containers.define("fonts","data",names.version,true)

local usesystemfonts       = true
local autoreload           = true

directives.register("fonts.autoreload",     function(v) autoreload     = toboolean(v) end)
directives.register("fonts.usesystemfonts", function(v) usesystemfonts = toboolean(v) end)

--[[ldx--
<p>A few helpers.</p>
--ldx]]--

-- -- what to do with these -- --
--
-- thin -> thin
--
-- regu -> regular  -> normal
-- norm -> normal   -> normal
-- stan -> standard -> normal
-- medi -> medium
-- ultr -> ultra
-- ligh -> light
-- heav -> heavy
-- blac -> black
-- thin
-- book
-- verylight
--
-- buch        -> book
-- buchschrift -> book
-- halb        -> demi
-- halbfett    -> demi
-- mitt        -> medium
-- mittel      -> medium
-- fett        -> bold
-- mage        -> light
-- mager       -> light
-- nord        -> normal
-- gras        -> normal

local weights = Cs ( -- not extra
    P("demibold")
  + P("semibold")
  + P("mediumbold")
  + P("ultrabold")
  + P("extrabold")
  + P("ultralight")
  + P("extralight")
  + P("bold")
  + P("demi")  -- / "semibold"
  + P("semi")  -- / "semibold"
  + P("light")
  + P("medium")
  + P("heavy")
  + P("ultra")
  + P("black")
--+ P("bol")      / "bold" -- blocks
  + P("bol")
  + P("regular")  / "normal"
)

-- local weights = {
--     [100] = "thin",
--     [200] = "extralight",
--     [300] = "light",
--     [400] = "normal",
--     [500] = "medium",
--     [600] = "semibold", -- demi demibold
--     [700] = "bold",
--     [800] = "extrabold",
--     [900] = "black",
-- }

local normalized_weights = sparse {
    regular = "normal",
}

local styles = Cs (
    P("reverseoblique") / "reverseitalic"
  + P("regular")        / "normal"
  + P("italic")
  + P("oblique")        / "italic"
  + P("slanted")
  + P("roman")          / "normal"
  + P("ital")           / "italic" -- might be tricky
  + P("ita")            / "italic" -- might be tricky
--+ P("obli")           / "oblique"
)

local normalized_styles = sparse {
    reverseoblique = "reverseitalic",
    regular        = "normal",
    oblique        = "italic",
}

local widths = Cs(
    P("condensed")
  + P("thin")
  + P("expanded")
  + P("cond")     / "condensed"
--+ P("expa")     / "expanded"
  + P("normal")
  + P("book")     / "normal"
)

local normalized_widths = sparse()

local variants = Cs( -- fax casual
    P("smallcaps")
  + P("oldstyle")
  + P("caps")      / "smallcaps"
)

local normalized_variants = sparse()

names.knownweights = {
    "black",
    "bold",
    "demi",
    "demibold",
    "extrabold",
    "heavy",
    "light",
    "medium",
    "mediumbold",
    "normal",
    "regular",
    "semi",
    "semibold",
    "ultra",
    "ultrabold",
    "ultralight",
}

names.knownstyles = {
    "italic",
    "normal",
    "oblique",
    "regular",
    "reverseitalic",
    "reverseoblique",
    "roman",
    "slanted",
}

names.knownwidths = {
    "book",
    "condensed",
    "expanded",
    "normal",
    "thin",
}

names.knownvariants = {
    "normal",
    "oldstyle",
    "smallcaps",
}

local remappedweights = {
    [""]    = "normal",
    ["bol"] = "bold",
}

local remappedstyles = {
    [""]    = "normal",
}

local remappedwidths = {
    [""]    = "normal",
}

local remappedvariants = {
    [""]    = "normal",
}

names.remappedweights  = remappedweights   setmetatableindex(remappedweights ,"self")
names.remappedstyles   = remappedstyles    setmetatableindex(remappedstyles  ,"self")
names.remappedwidths   = remappedwidths    setmetatableindex(remappedwidths  ,"self")
names.remappedvariants = remappedvariants  setmetatableindex(remappedvariants,"self")

local any = P(1)

local analyzed_table

local analyzer = Cs (
    (
        weights  / function(s) analyzed_table[1] = s return "" end
      + styles   / function(s) analyzed_table[2] = s return "" end
      + widths   / function(s) analyzed_table[3] = s return "" end
      + variants / function(s) analyzed_table[4] = s return "" end
      + any
    )^0
)

local splitter = lpeg.splitat("-")

function names.splitspec(askedname)
    local name, weight, style, width, variant = lpegmatch(splitter,askedname)
    weight  = weight  and lpegmatch(weights, weight)  or weight
    style   = style   and lpegmatch(styles,  style)   or style
    width   = width   and lpegmatch(widths,  width)   or width
    variant = variant and lpegmatch(variants,variant) or variant
    if trace_names then
        report_names("requested name %a split in name %a, weight %a, style %a, width %a and variant %a",
            askedname,name,weight,style,width,variant)
    end
    if not weight or not weight or not width or not variant then
        weight, style, width, variant = weight or "normal", style or "normal", width or "normal", variant or "normal"
        if trace_names then
            report_names("request %a normalized to '%s-%s-%s-%s-%s'",
                askedname,name,weight,style,width,variant)
        end
    end
    return name or askedname, weight, style, width, variant
end

local function analyzespec(somename)
    if somename then
        analyzed_table = { }
        local name = lpegmatch(analyzer,somename)
        return name, analyzed_table[1], analyzed_table[2], analyzed_table[3], analyzed_table[4]
    end
end

--[[ldx--
<p>It would make sense to implement the filters in the related modules,
but to keep the overview, we define them here.</p>
--ldx]]--

filters.afm = fonts.handlers.afm.readers.getinfo
filters.otf = fonts.handlers.otf.readers.getinfo
filters.ttf = filters.otf
filters.ttc = filters.otf
-------.ttx = filters.otf

-- local function normalize(t) -- only for afm parsing
--     local boundingbox = t.boundingbox or t.fontbbox
--     if boundingbox then
--         for i=1,#boundingbox do
--             boundingbox[i] = tonumber(boundingbox[i])
--         end
--     else
--         boundingbox = { 0, 0, 0, 0 }
--     end
--     return {
--         copyright     = t.copyright,
--         fontname      = t.fontname,
--         fullname      = t.fullname,
--         familyname    = t.familyname,
--         weight        = t.weight,
--         widtht        = t.width,
--         italicangle   = tonumber(t.italicangle) or 0,
--         monospaced    = t.monospaced or toboolean(t.isfixedpitch) or false,
--         boundingbox   = boundingbox,
--         version       = t.version, -- not used
--         capheight     = tonumber(t.capheight),
--         xheight       = tonumber(t.xheight),
--         ascender      = tonumber(t.ascender),
--         descender     = tonumber(t.descender),
--     }
-- end
--
-- function filters.afm(name)
--     -- we could parse the afm file as well, and then report an error but
--     -- it's not worth the trouble
--     local pfbname = findfile(removesuffix(name)..".pfb","pfb") or ""
--     if pfbname == "" then
--         pfbname = findfile(nameonly(name)..".pfb","pfb") or ""
--     end
--     if pfbname ~= "" then
--         local f = io.open(name)
--         if f then
--             local hash = { }
--             local okay = false
--             for line in f:lines() do -- slow but only a few lines at the beginning
--                 if find(line,"StartCharMetrics",1,true) then
--                     break
--                 else
--                     local key, value = match(line,"^(.+)%s+(.+)%s*$")
--                     if key and #key > 0 then
--                         hash[lower(key)] = value
--                     end
--                 end
--             end
--             f:close()
--             return normalize(hash)
--         end
--     end
--     return nil, "no matching pfb file"
-- end

-- local p_spaces  = lpegpatterns.whitespace
-- local p_number  = (R("09")+S(".-+"))^1 / tonumber
-- local p_boolean = P("false") * Cc(false)
--                 + P("false") * Cc(false)
-- local p_string  = P("(") * C((lpegpatterns.nestedparents + 1 - P(")"))^1) * P(")")
-- local p_array   = P("[") * Ct((p_number + p_boolean + p_string + p_spaces^1)^1) * P("]")
--                 + P("{") * Ct((p_number + p_boolean + p_string + p_spaces^1)^1) * P("}")
--
-- local p_key     = P("/") * C(R("AZ","az")^1)
-- local p_value   = p_string
--                 + p_number
--                 + p_boolean
--                 + p_array
--
-- local p_entry   = p_key * p_spaces^0 * p_value
--
-- function filters.pfb(name)
--     local f = io.open(name)
--     if f then
--         local hash = { }
--         local okay = false
--         for line in f:lines() do -- slow but only a few lines at the beginning
--             if find(line,"dict begin",1,true) then
--                 okay = true
--             elseif not okay then
--                 -- go on
--             elseif find(line,"currentdict end",1,true) then
--                 break
--             else
--                 local key, value = lpegmatch(p_entry,line)
--                 if key and value then
--                     hash[lower(key)] = value
--                 end
--             end
--         end
--         f:close()
--         return normalize(hash)
--     end
-- end

--[[ldx--
<p>The scanner loops over the filters using the information stored in
the file databases. Watch how we check not only for the names, but also
for combination with the weight of a font.</p>
--ldx]]--

filters.list = {
    "otf", "ttf", "ttc", "afm", -- no longer dfont support (for now)
}

-- to be considered: loop over paths per list entry (so first all otf ttf etc)

names.fontconfigfile       = "fonts.conf"   -- a bit weird format, bonus feature
names.osfontdirvariable    = "OSFONTDIR"    -- the official way, in minimals etc
names.extrafontsvariable   = "EXTRAFONTS"   -- the official way, in minimals etc
names.runtimefontsvariable = "RUNTIMEFONTS" -- the official way, in minimals etc

filters.paths = { }
filters.names = { }

function names.getpaths(trace)
    local hash, result, r = { }, { }, 0
    local function collect(t,where)
        for i=1,#t do
            local v = cleanpath(t[i])
            v = gsub(v,"/+$","") -- not needed any more
            local key = lower(v)
            report_names("variable %a specifies path %a",where,v)
            if not hash[key] then
                r = r + 1
                result[r] = v
                hash[key] = true
            end
        end
    end
    local path = names.osfontdirvariable or ""
    if path ~= "" then
        collect(resolvers.expandedpathlist(path),path)
    end
    local path = names.extrafontsvariable or ""
    if path ~= "" then
        collect(resolvers.expandedpathlist(path),path)
    end
    if xml then
        local confname = resolvers.expansion("FONTCONFIG_FILE") or ""
        if confname == "" then
            confname = names.fontconfigfile or ""
        end
        if confname ~= "" then
            -- first look in the tex tree
            local name = findfile(confname,"fontconfig files") or ""
            if name == "" then
                -- after all, fontconfig is a unix thing
                name = filejoin("/etc",confname)
                if not isfile(name) then
                    name = "" -- force quit
                end
            end
            if name ~= "" and isfile(name) then
                if trace_names then
                    report_names("%s fontconfig file %a","loading",name)
                end
                local xmldata = xml.load(name)
                -- begin of untested mess
                xml.include(xmldata,"include","",true,function(incname)
                    if not is_qualified_path(incname) then
                        local path = pathpart(name) -- main name
                        if path ~= "" then
                            incname = filejoin(path,incname)
                        end
                    end
                    if isfile(incname) then
                        if trace_names then
                            report_names("%s fontconfig file %a","merging included",incname)
                        end
                        return io.loaddata(incname)
                    elseif trace_names then
                        report_names("%s fontconfig file: %a","ignoring included",incname)
                    end
                end)
                -- end of untested mess
                local fontdirs = xml.collect_texts(xmldata,"dir",true)
                if trace_names then
                    report_names("%s dirs found in fontconfig",#fontdirs)
                end
                collect(fontdirs,"fontconfig file")
            end
        end
    end
    sort(result)
    function names.getpaths()
        return result
    end
    return result
end

local function cleanname(name)
    return (gsub(lower(name),"[^%a%d]",""))
end

local function cleanfilename(fullname,defaultsuffix)
    if fullname then
        local path, name, suffix = splitname(fullname)
        if name then
            name = gsub(lower(name),"[^%a%d]","")
            if suffix and suffix ~= "" then
                return name .. ".".. suffix
            elseif defaultsuffix and defaultsuffix ~= "" then
                return name .. ".".. defaultsuffix
            else
                return name
            end
        end
    end
    return "badfontname"
end

local sorter = function(a,b)
    return a > b -- longest first
end

-- local sorter = nil

names.cleanname     = cleanname
names.cleanfilename = cleanfilename

-- local function check_names(result)
--     local names = result.names
--     if names then
--         for i=1,#names do
--             local name = names[i]
--             if name.lang == "English (US)" then
--                 return name.names
--             end
--         end
--     end
--     return result
-- end


local function check_name(data,result,filename,modification,suffix,subfont)
    -- shortcuts
    local specifications = data.specifications
    -- fetch
    local fullname       = result.fullname
    local fontname       = result.fontname
    local family         = result.family
    local subfamily      = result.subfamily
    local familyname     = result.familyname
    local subfamilyname  = result.subfamilyname
 -- local compatiblename = result.compatiblename
 -- local cfffullname    = result.cfffullname
    local weight         = result.weight
    local width          = result.width
    local italicangle    = tonumber(result.italicangle)
    local subfont        = subfont
    local rawname        = fullname or fontname or familyname
    local filebase       = removesuffix(basename(filename))
    local cleanfilename  = cleanname(filebase) -- for WS
    -- normalize
    fullname       = fullname       and cleanname(fullname)
    fontname       = fontname       and cleanname(fontname)
    family         = family         and cleanname(family)
    subfamily      = subfamily      and cleanname(subfamily)
    familyname     = familyname     and cleanname(familyname)
    subfamilyname  = subfamilyname  and cleanname(subfamilyname)
 -- compatiblename = compatiblename and cleanname(compatiblename)
 -- cfffullname    = cfffullname    and cleanname(cfffullname)
    weight         = weight         and cleanname(weight)
    width          = width          and cleanname(width)
    italicangle    = italicangle == 0 and nil
    -- analyze
    local a_name, a_weight, a_style, a_width, a_variant = analyzespec(fullname or fontname or familyname)
    -- check
    local width   = width or a_width
    local variant = a_variant
    local style   = subfamilyname or subfamily -- can re really trust subfamilyname?
    if style then
        style = gsub(style,"[^%a]","")
    elseif italicangle then
        style = "italic"
    end
    if not variant or variant == "" then
        variant = "normal"
    end
    if not weight or weight == "" then
        weight = a_weight
    end
    if not style or style == ""  then
        style = a_style
    end
    if not familyname then
        familyname = a_name
    end
    fontname   = fontname   or fullname or familyname or filebase -- maybe cleanfilename
    fullname   = fullname   or fontname
    familyname = familyname or fontname
    -- we do these sparse -- todo: check table type or change names in ff loader
    local units      = result.units       or 1000 -- can be zero too
    local designsize = result.designsize  or 0
    local minsize    = result.minsize     or 0
    local maxsize    = result.maxsize     or 0
    local angle      = result.italicangle or 0
    local pfmwidth   = result.pfmwidth    or 0
    local pfmweight  = result.pfmweight   or 0
    --
    local instancenames = result.instancenames
    --
    specifications[#specifications+1] = {
        filename       = filename, -- unresolved
        cleanfilename  = cleanfilename,
     -- subfontindex   = subfont,
        format         = lower(suffix),
        subfont        = subfont,
        rawname        = rawname,
        fullname       = fullname,
        fontname       = fontname,
        family         = family,
        subfamily      = subfamily,
        familyname     = familyname,
        subfamilyname  = subfamilyname,
     -- compatiblename = compatiblename,  -- nor used / needed
     -- cfffullname    = cfffullname,
        weight         = weight,
        style          = style,
        width          = width,
        variant        = variant,
        units          = units        ~= 1000 and units        or nil,
        pfmwidth       = pfmwidth     ~=    0 and pfmwidth     or nil,
        pfmweight      = pfmweight    ~=    0 and pfmweight    or nil,
        angle          = angle        ~=    0 and angle        or nil,
        minsize        = minsize      ~=    0 and minsize      or nil,
        maxsize        = maxsize      ~=    0 and maxsize      or nil,
        designsize     = designsize   ~=    0 and designsize   or nil,
        modification   = modification ~=    0 and modification or nil,
        instancenames  = instancenames or nil,
    }
end

local function cleanupkeywords()
    local data           = names.data
    local specifications = names.data.specifications
    if specifications then
        local weights  = { }
        local styles   = { }
        local widths   = { }
        local variants = { }
        for i=1,#specifications do
            local s = specifications[i]
            -- fix (sofar styles are taken from the name, and widths from the specification)
            local _, b_weight, b_style, b_width, b_variant = analyzespec(s.weight)
            local _, c_weight, c_style, c_width, c_variant = analyzespec(s.style)
            local _, d_weight, d_style, d_width, d_variant = analyzespec(s.width)
            local _, e_weight, e_style, e_width, e_variant = analyzespec(s.variant)
            local _, f_weight, f_style, f_width, f_variant = analyzespec(s.fullname or "")
            local weight  = b_weight  or c_weight  or d_weight  or e_weight  or f_weight  or "normal"
            local style   = b_style   or c_style   or d_style   or e_style   or f_style   or "normal"
            local width   = b_width   or c_width   or d_width   or e_width   or f_width   or "normal"
            local variant = b_variant or c_variant or d_variant or e_variant or f_variant or "normal"
            weight  = remappedweights [weight  or ""]
            style   = remappedstyles  [style   or ""]
            width   = remappedwidths  [width   or ""]
            variant = remappedvariants[variant or ""]
            weights [weight ] = (weights [weight ] or 0) + 1
            styles  [style  ] = (styles  [style  ] or 0) + 1
            widths  [width  ] = (widths  [width  ] or 0) + 1
            variants[variant] = (variants[variant] or 0) + 1
            if weight ~= s.weight then
                s.fontweight = s.weight
            end
            s.weight, s.style, s.width, s.variant = weight, style, width, variant
        end
        local statistics = data.statistics
        statistics.used_weights  = weights
        statistics.used_styles   = styles
        statistics.used_widths   = widths
        statistics.used_variants = variants
    end
end

local function collectstatistics(runtime)
    local data           = names.data
    local specifications = data.specifications
    local statistics     = data.statistics
    if specifications then
        local f_w = formatters["%i"]
        local f_a = formatters["%0.2f"]
        -- normal stuff
        local weights    = { }
        local styles     = { }
        local widths     = { }
        local variants   = { }
        -- weird stuff
        local angles     = { }
        -- extra stuff
        local pfmweights = { } setmetatableindex(pfmweights,"table")
        local pfmwidths  = { } setmetatableindex(pfmwidths, "table")
        -- main loop
        for i=1,#specifications do
            local s = specifications[i]
            -- normal stuff
            local weight  = s.weight
            local style   = s.style
            local width   = s.width
            local variant = s.variant
            if weight  then weights [weight ] = (weights [weight ] or 0) + 1 end
            if style   then styles  [style  ] = (styles  [style  ] or 0) + 1 end
            if width   then widths  [width  ] = (widths  [width  ] or 0) + 1 end
            if variant then variants[variant] = (variants[variant] or 0) + 1 end
            -- weird stuff
            local angle   = f_a(tonumber(s.angle) or 0)
            angles[angle] = (angles[angles] or 0) + 1
            -- extra stuff
            local pfmweight     = f_w(s.pfmweight or 0)
            local pfmwidth      = f_w(s.pfmwidth  or 0)
            local tweights      = pfmweights[pfmweight]
            local twidths       = pfmwidths [pfmwidth]
            tweights[pfmweight] = (tweights[pfmweight] or 0) + 1
            twidths[pfmwidth]   = (twidths [pfmwidth]  or 0) + 1
        end
        --
        statistics.weights    = weights
        statistics.styles     = styles
        statistics.widths     = widths
        statistics.variants   = variants
        statistics.angles     = angles
        statistics.pfmweights = pfmweights
        statistics.pfmwidths  = pfmwidths
        statistics.fonts      = #specifications
        --
        setmetatableindex(pfmweights,nil)
        setmetatableindex(pfmwidths, nil)
        --
        report_names("")
        report_names("statistics: ")
        report_names("")
        report_names("weights")
        report_names("")
        report_names(formatters["  %T"](weights))
        report_names("")
        report_names("styles")
        report_names("")
        report_names(formatters["  %T"](styles))
        report_names("")
        report_names("widths")
        report_names("")
        report_names(formatters["  %T"](widths))
        report_names("")
        report_names("variants")
        report_names("")
        report_names(formatters["  %T"](variants))
        report_names("")
        report_names("angles")
        report_names("")
        report_names(formatters["  %T"](angles))
        report_names("")
        report_names("pfmweights")
        report_names("")
        for k, v in sortedhash(pfmweights) do
            report_names(formatters["  %-10s: %T"](k,v))
        end
        report_names("")
        report_names("pfmwidths")
        report_names("")
        for k, v in sortedhash(pfmwidths) do
            report_names(formatters["  %-10s: %T"](k,v))
        end
        report_names("")
        report_names("registered fonts : %i", statistics.fonts)
        report_names("read files       : %i", statistics.readfiles)
        report_names("skipped files    : %i", statistics.skippedfiles)
        report_names("duplicate files  : %i", statistics.duplicatefiles)
            if runtime then
        report_names("total scan time  : %0.3f seconds",runtime)
            end
    end
end

local function collecthashes()
    local data           = names.data
    local mappings       = data.mappings
    local fallbacks      = data.fallbacks
    local specifications = data.specifications
    local nofmappings    = 0
    local noffallbacks   = 0
    if specifications then
        -- maybe multiple passes (for the compatible and cffnames so that they have less preference)
        local conflicts = setmetatableindex("table")
        for index=1,#specifications do
            local specification  = specifications[index]
            local format         = specification.format
            local fullname       = specification.fullname
            local fontname       = specification.fontname
         -- local rawname        = specification.rawname
         -- local compatiblename = specification.compatiblename
         -- local cfffullname    = specification.cfffullname
            local familyname     = specification.familyname or specification.family
            local subfamilyname  = specification.subfamilyname
            local subfamily      = specification.subfamily
            local weight         = specification.weight
            local mapping        = mappings[format]
            local fallback       = fallbacks[format]
            local instancenames  = specification.instancenames
            if fullname and not mapping[fullname] then
                mapping[fullname] = index
                nofmappings       = nofmappings + 1
            end
            if fontname and not mapping[fontname] then
                mapping[fontname] = index
                nofmappings       = nofmappings + 1
            end
            if instancenames then
                for i=1,#instancenames do
                    local instance = fullname .. instancenames[i]
                    mapping[instance] = index
                    nofmappings       = nofmappings + 1
                end
            end
         -- if compatiblename and not mapping[compatiblename] then
         --     mapping[compatiblename] = index
         --     nofmappings             = nofmappings + 1
         -- end
         -- if cfffullname and not mapping[cfffullname] then
         --     mapping[cfffullname] = index
         --     nofmappings          = nofmappings + 1
         -- end
            if familyname then
                if weight and weight ~= sub(familyname,#familyname-#weight+1,#familyname) then
                    local madename = familyname .. weight
                    if not mapping[madename] and not fallback[madename] then
                        fallback[madename] = index
                        noffallbacks       = noffallbacks + 1
                    end
                end
                if subfamily and subfamily ~= sub(familyname,#familyname-#subfamily+1,#familyname) then
                    local extraname = familyname .. subfamily
                    if not mapping[extraname] and not fallback[extraname] then
                        fallback[extraname] = index
                        noffallbacks        = noffallbacks + 1
                    end
                end
                if subfamilyname and subfamilyname ~= sub(familyname,#familyname-#subfamilyname+1,#familyname) then
                    local extraname = familyname .. subfamilyname
                    if not mapping[extraname] and not fallback[extraname] then
                        fallback[extraname] = index
                        noffallbacks        = noffallbacks + 1
                    end
                end
                -- dangerous ... first match takes slot
                if not mapping[familyname] and not fallback[familyname] then
                    fallback[familyname] = index
                    noffallbacks         = noffallbacks + 1
                end
                local conflict = conflicts[format]
                conflict[familyname] = (conflict[familyname] or 0) + 1
            end
        end
        for format, conflict in next, conflicts do
            local fallback = fallbacks[format]
            for familyname, n in next, conflict do
                if n > 1 then
                    fallback[familyname] = nil
                    noffallbacks = noffallbacks - n
                end
            end
        end
    end
    return nofmappings, noffallbacks
end

local function collectfamilies()
    local data           = names.data
    local specifications = data.specifications
    local families       = data.families
    for index=1,#specifications do
        local familyname = specifications[index].familyname
        local family     = families[familyname]
        if not family then
            families[familyname] = { index }
        else
            family[#family+1] = index
        end
    end
end

local function checkduplicate(where) -- fails on "Romantik" but that's a border case anyway
    local data           = names.data
    local mapping        = data[where]
    local specifications = data.specifications
    local loaded         = { }
    if specifications and mapping then
     -- was: for _, m in sortedhash(mapping) do
        local order = filters.list
        for i=1,#order do
            local m = mapping[order[i]]
            for k, v in sortedhash(m) do
                local s = specifications[v]
                local hash = formatters["%s-%s-%s-%s-%s"](s.familyname,s.weight or "*",s.style or "*",s.width or "*",s.variant or "*")
                local h = loaded[hash]
                if h then
                    local ok = true
                    local fn = s.filename
                    for i=1,#h do
                        if h[i] == fn then
                            ok = false
                            break
                        end
                    end
                    if ok then
                        h[#h+1] = fn
                    end
                else
                    loaded[hash] = { s.filename }
                end
            end
        end
    end
    local n = 0
    for k, v in sortedhash(loaded) do
        local nv = #v
        if nv > 1 then
            if trace_warnings then
                report_names("lookup %a clashes with %a",k,v)
            end
            n = n + nv
        end
    end
    report_names("%a double lookups in %a",n,where)
end

local function checkduplicates()
    checkduplicate("mappings")
    checkduplicate("fallbacks")
end

local function sorthashes()
    local data             = names.data
    local list             = filters.list
    local mappings         = data.mappings
    local fallbacks        = data.fallbacks
    local sorted_mappings  = { }
    local sorted_fallbacks = { }
    data.sorted_mappings   = sorted_mappings
    data.sorted_fallbacks  = sorted_fallbacks
    for i=1,#list do
        local l = list[i]
        sorted_mappings [l] = table.keys(mappings[l])
        sorted_fallbacks[l] = table.keys(fallbacks[l])
        sort(sorted_mappings [l],sorter)
        sort(sorted_fallbacks[l],sorter)
    end
    local sorted_families = table.keys(data.families)
    data.sorted_families  = sorted_families
    sort(sorted_families,sorter)
end

local function unpackreferences()
    local data           = names.data
    local specifications = data.specifications
    if specifications then
        for k, v in sortedhash(data.families) do
            for i=1,#v do
                v[i] = specifications[v[i]]
            end
        end
        local mappings = data.mappings
        if mappings then
            for _, m in sortedhash(mappings) do
                for k, v in sortedhash(m) do
                    m[k] = specifications[v]
                end
            end
        end
        local fallbacks = data.fallbacks
        if fallbacks then
            for _, f in sortedhash(fallbacks) do
                for k, v in sortedhash(f) do
                    f[k] = specifications[v]
                end
            end
        end
    end
end

local function analyzefiles(olddata)

    if not trace_warnings then
        report_names("warnings are disabled (tracker 'fonts.warnings')")
    end

    local data               = names.data
    local done               = { }
    local totalnofread       = 0
    local totalnofskipped    = 0
    local totalnofduplicates = 0
    local nofread            = 0
    local nofskipped         = 0
    local nofduplicates      = 0
    local skip_paths         = filters.paths
    local skip_names         = filters.names
    local specifications     = data.specifications
    local oldindices         = olddata and olddata.indices        or { }
    local oldspecifications  = olddata and olddata.specifications or { }
    local oldrejected        = olddata and olddata.rejected       or { }
    local treatmentdata      = treatments.data or { } -- when used outside context
    ----- walked             = setmetatableindex("number")

    local function walk_tree(pathlist,suffix,identify)
        if pathlist then
            for i=1,#pathlist do
                local path = pathlist[i]
                path = cleanpath(path .. "/")
                path = gsub(path,"/+","/")
                local pattern = path .. "**." .. suffix -- ** forces recurse
                report_names("globbing path %a",pattern)
                local t = dir.glob(pattern)
                sort(t,sorter)
                for j=1,#t do
                    local completename = t[j]
                    identify(completename,basename(completename),suffix,completename)
                end
             -- walked[path] = walked[path] + #t
            end
        end
    end

    local function identify(completename,name,suffix,storedname)
        local pathpart, basepart = splitbase(completename)
        nofread = nofread + 1
        local treatment = treatmentdata[completename] or treatmentdata[basepart]
        if treatment and treatment.ignored then
            if trace_names or trace_rejections then
                report_names("%s font %a is ignored, reason %a",suffix,completename,treatment.comment or "unknown")
            end
            nofskipped = nofskipped + 1
        elseif done[name] then
            if lower(completename) ~= lower(done[name]) then
                -- already done (avoid otf afm clash)
                if trace_names or trace_rejections then
                    report_names("%s font %a already done as %a",suffix,completename,done[name])
                end
                nofduplicates = nofduplicates + 1
                nofskipped = nofskipped + 1
            end
        elseif not exists(completename) then
            -- weird error
            if trace_names or trace_rejections then
                report_names("%s font %a does not really exist",suffix,completename)
            end
            nofskipped = nofskipped + 1
        elseif not is_qualified_path(completename) and findfile(completename,suffix) == "" then
            -- not locatable by backend anyway
            if trace_names or trace_rejections then
                report_names("%s font %a cannot be found by backend",suffix,completename)
            end
            nofskipped = nofskipped + 1
        else
            if #skip_paths > 0 then
                for i=1,#skip_paths do
                    if find(pathpart,skip_paths[i]) then
                        if trace_names or trace_rejections then
                            report_names("rejecting path of %s font %a",suffix,completename)
                        end
                        nofskipped = nofskipped + 1
                        return
                    end
                end
            end
            if #skip_names > 0 then
                for i=1,#skip_paths do
                    if find(basepart,skip_names[i]) then
                        done[name] = true
                        if trace_names or trace_rejections then
                            report_names("rejecting name of %s font %a",suffix,completename)
                        end
                        nofskipped = nofskipped + 1
                        return
                    end
                end
            end
            if trace_names then
                report_names("identifying %s font %a",suffix,completename)
            end
            -- needs checking with ttc / ttx : date not updated ?
            local result = nil
            local modification = modificationtime(completename)
            if olddata and modification and modification > 0 then
                local oldindex = oldindices[storedname] -- index into specifications
                if oldindex then
                    local oldspecification = oldspecifications[oldindex]
                    if oldspecification and oldspecification.filename == storedname then -- double check for out of sync
                        local oldmodification = oldspecification.modification
                        if oldmodification == modification then
                            result = oldspecification
                            specifications[#specifications + 1] = result
                        else
                            -- ??
                        end
                    else
                         -- ??
                    end
                elseif oldrejected[storedname] == modification then
                    result = false
                end
            end
            if result == nil then
                local lsuffix = lower(suffix)
                local result, message = filters[lsuffix](completename)
                if result then
                    if #result > 0 then
                        for r=1,#result do
                            check_name(data,result[r],storedname,modification,suffix,r) -- subfonts start at zero
                        end
                    else
                        check_name(data,result,storedname,modification,suffix)
                    end
                    if trace_warnings and message and message ~= "" then
                        report_names("warning when identifying %s font %a, %s",suffix,completename,message)
                    end
                elseif trace_warnings then
                    nofskipped = nofskipped + 1
                    report_names("error when identifying %s font %a, %s",suffix,completename,message or "unknown")
                end
            end
            done[name] = completename
        end
        logs.flush() --  a bit overkill for each font, maybe not needed here
    end

    local function traverse(what, method)
        local list = filters.list
        for n=1,#list do
            local suffix = list[n]
            local t = os.gettimeofday() -- use elapser
            nofread, nofskipped, nofduplicates = 0, 0, 0
            suffix = lower(suffix)
            report_names("identifying %s font files with suffix %a",what,suffix)
            method(suffix)
            suffix = upper(suffix)
            report_names("identifying %s font files with suffix %a",what,suffix)
            method(suffix)
            totalnofread, totalnofskipped, totalnofduplicates = totalnofread + nofread, totalnofskipped + nofskipped, totalnofduplicates + nofduplicates
            local elapsed = os.gettimeofday() - t
            report_names("%s %s files identified, %s skipped, %s duplicates, %s hash entries added, runtime %0.3f seconds",nofread,what,nofskipped,nofduplicates,nofread-nofskipped,elapsed)
        end
        logs.flush()
    end

    -- problem .. this will not take care of duplicates

    local function withtree(suffix)
        resolvers.dowithfilesintree(".*%." .. suffix .. "$", function(method,root,path,name)
            if method == "file" or method == "tree" then
                local completename = root .."/" .. path .. "/" .. name
                completename = resolveprefix(completename) -- no shortcut
                identify(completename,name,suffix,name)
                return true
            end
        end, function(blobtype,blobpath,pattern)
            blobpath = resolveprefix(blobpath) -- no shortcut
            report_names("scanning path %a for %s files",blobpath,suffix)
        end, function(blobtype,blobpath,pattern,total,checked,done)
            blobpath = resolveprefix(blobpath) -- no shortcut
            report_names("%s %s files checked, %s okay",checked,suffix,done)
        end)
    end

    local function withlsr(suffix) -- all trees
        -- we do this only for a stupid names run, not used for context itself,
        -- using the vars is too clumsy so we just stick to a full scan instead
        local pathlist = resolvers.splitpath(resolvers.showpath("ls-R") or "")
        walk_tree(pathlist,suffix,identify)
    end

    local function withsystem(suffix) -- OSFONTDIR cum suis
        walk_tree(names.getpaths(trace),suffix,identify)
    end

    traverse("tree",withtree) -- TEXTREE only

    if not usesystemfonts then
        report_names("ignoring system fonts")
    elseif texconfig.kpse_init then
        traverse("lsr", withlsr)
    else
        traverse("system", withsystem)
    end

    data.statistics.readfiles      = totalnofread
    data.statistics.skippedfiles   = totalnofskipped
    data.statistics.duplicatefiles = totalnofduplicates

 -- for k, v in sortedhash(walked) do
 --     report_names("%s : %i",k,v)
 -- end

end

local function addfilenames()
    local data           = names.data
    local specifications = data.specifications
    local indices        = { }
    local files          = { }
    for i=1,#specifications do
        local fullname = specifications[i].filename
        files[cleanfilename(fullname)] = fullname
        indices[fullname] = i
    end
    data.files   = files
    data.indices = indices
end

local function rejectclashes() -- just to be sure, so no explicit afm will be found then
    local specifications  = names.data.specifications
    local used            = { }
    local okay            = { }
    local rejected        = { } -- only keep modification
    local o               = 0
    for i=1,#specifications do
        local s = specifications[i]
        local f = s.fontname
        if f then
            local fnd = used[f]
            local fnm = s.filename
            if fnd then
                if trace_warnings then
                    report_names("fontname %a clashes, %a rejected in favor of %a",f,fnm,fnd)
                end
                rejected[f] = s.modification
            else
                used[f] = fnm
                o = o + 1
                okay[o] = s
            end
        else
            o = o + 1
            okay[o] = s
        end
    end
    local d = #specifications - #okay
    if d > 0 then
        report_names("%s files rejected due to clashes",d)
    end
    names.data.specifications = okay
    names.data.rejected       = rejected
end

local function resetdata()
    local mappings  = { }
    local fallbacks = { }
    for _, k in next, filters.list do
        mappings [k] = { }
        fallbacks[k] = { }
    end
    names.data = {
        version        = names.version,
        mappings       = mappings,
        fallbacks      = fallbacks,
        specifications = { },
        families       = { },
        statistics     = { },
        names          = { },
        indices        = { },
        rejected       = { },
        datastate      = resolvers.datastate(),
    }
end

function names.identify(force)
    local starttime = os.gettimeofday() -- use elapser
    resetdata()
    analyzefiles(not force and names.readdata(names.basename))
    rejectclashes()
    collectfamilies()
    cleanupkeywords()
    collecthashes()
    checkduplicates()
    addfilenames()
 -- sorthashes() -- will be resorted when saved
    collectstatistics(os.gettimeofday()-starttime)
end

function names.is_permitted(name)
    return containers.is_usable(names.cache, name)
end
function names.writedata(name,data)
    containers.write(names.cache,name,data)
end
function names.readdata(name)
    return containers.read(names.cache,name)
end

function names.load(reload,force)
    if not names.loaded then
        if reload then
            if names.is_permitted(names.basename) then
                names.identify(force)
                names.writedata(names.basename,names.data)
            else
                report_names("unable to access database cache")
            end
            names.saved = true
        end
        local data = names.readdata(names.basename)
        names.data = data
        if not names.saved then
            if not data or not next(data) or not data.specifications or not next(data.specifications) then
               names.load(true)
            end
            names.saved = true
        end
        if not data then
            report_names("accessing the data table failed")
        else
            unpackreferences()
            sorthashes()
        end
        names.loaded = true
    end
end

local function list_them(mapping,sorted,pattern,t,all)
    if mapping[pattern] then
        t[pattern] = mapping[pattern]
    else
        for k=1,#sorted do
            local v = sorted[k]
            if not t[v] and find(v,pattern) then
                t[v] = mapping[v]
                if not all then
                    return
                end
            end
        end
    end
end

function names.list(pattern,reload,all) -- here?
    names.load() -- todo reload
    if names.loaded then
        local t = { }
        local data = names.data
        if data then
            local list             = filters.list
            local mappings         = data.mappings
            local sorted_mappings  = data.sorted_mappings
            local fallbacks        = data.fallbacks
            local sorted_fallbacks = data.sorted_fallbacks
            for i=1,#list do
                local format = list[i]
                list_them(mappings[format],sorted_mappings[format],pattern,t,all)
                if next(t) and not all then
                    return t
                end
                list_them(fallbacks[format],sorted_fallbacks[format],pattern,t,all)
                if next(t) and not all then
                    return t
                end
            end
        end
        return t
    end
end

local reloaded = false

local function is_reloaded()
    if not reloaded then
        local data = names.data
        if autoreload then
            local c_status = serialize(resolvers.datastate())
            local f_status = serialize(data.datastate)
            if c_status == f_status then
                if trace_names then
                    report_names("font database has matching configuration and file hashes")
                end
                return
            else
                report_names("font database has mismatching configuration and file hashes")
            end
        else
            report_names("font database is regenerated (controlled by directive 'fonts.autoreload')")
        end
        names.loaded = false
        reloaded = true
        logs.flush()
        names.load(true)
    end
end

--[[ldx--
<p>The resolver also checks if the cached names are loaded. Being clever
here is for testing purposes only (it deals with names prefixed by an
encoding name).</p>
--ldx]]--

local function fuzzy(mapping,sorted,name,sub)
    local condensed = gsub(name,"[^%a%d]","")
    for k=1,#sorted do
        local v = sorted[k]
        if find(v,condensed) then
            return mapping[v], v
        end
    end
end

-- we could cache a lookup .. maybe some day ... (only when auto loaded!)

local function checkinstance(found,askedname)
    local instancenames = found.instancenames
    if instancenames then
        local fullname = found.fullname
        for i=1,#instancenames do
            local instancename = instancenames[i]
            if fullname .. instancename == askedname then
                local f = fastcopy(found)
                f.instances = nil
                f.instance  = instancename
                return f
            end
        end
    end
    return found
end

local function foundname(name,sub) -- sub is not used currently
    local data             = names.data
    local mappings         = data.mappings
    local sorted_mappings  = data.sorted_mappings
    local fallbacks        = data.fallbacks
    local sorted_fallbacks = data.sorted_fallbacks
    local list             = filters.list
    -- dilemma: we lookup in the order otf ttf ttc ... afm but now an otf fallback
    -- can come after an afm match ... well, one should provide nice names anyway
    -- and having two lists is not an option
    for i=1,#list do
        local l = list[i]
        local found = mappings[l][name]
        if found then
            if trace_names then
                report_names("resolved via direct name match: %a",name)
            end
            return checkinstance(found,name)
        end
    end
    for i=1,#list do
        local l = list[i]
        local found, fname = fuzzy(mappings[l],sorted_mappings[l],name,sub)
        if found then
            if trace_names then
                report_names("resolved via fuzzy name match: %a onto %a",name,fname)
            end
            return checkinstance(found,name)
        end
    end
    for i=1,#list do
        local l = list[i]
        local found = fallbacks[l][name]
        if found then
            if trace_names then
                report_names("resolved via direct fallback match: %a",name)
            end
            return checkinstance(found,name)
        end
    end
    for i=1,#list do
        local l = list[i]
        local found, fname = fuzzy(sorted_mappings[l],sorted_fallbacks[l],name,sub)
        if found then
            if trace_names then
                report_names("resolved via fuzzy fallback match: %a onto %a",name,fname)
            end
            return checkinstance(found,name)
        end
    end
    if trace_names then
        report_names("font with name %a cannot be found",name)
    end
end

function names.resolvedspecification(askedname,sub)
    if askedname and askedname ~= "" and names.enabled then
        askedname = cleanname(askedname)
        names.load()
        local found = foundname(askedname,sub)
        if not found and is_reloaded() then
            found = foundname(askedname,sub)
        end
        return found
    end
end

function names.resolve(askedname,sub)
    local found = names.resolvedspecification(askedname,sub)
    if found then
        return found.filename, found.subfont and found.rawname, found.subfont, found.instance
    end
end

-- function names.getfilename(askedname,suffix) -- last resort, strip funny chars
--     names.load()
--     local files = names.data.files
--     askedname = files and files[cleanfilename(askedname,suffix)] or ""
--     if askedname == "" then
--         return ""
--     else -- never entered
--         return resolvers.findbinfile(askedname,suffix) or ""
--     end
-- end

local runtimefiles = { }
local runtimedone  = false

local function addruntimepath(path)
    names.load()
    local paths    = type(path) == "table" and path or { path }
    local suffixes = tohash(filters.list)
    for i=1,#paths do
        local path = resolveprefix(paths[i])
        if path ~= "" then
            local list = dir.glob(path.."/*")
            for i=1,#list do
                local fullname = list[i]
                local suffix   = lower(suffixonly(fullname))
                if suffixes[suffix] then
                    local c = cleanfilename(fullname)
                    runtimefiles[c] = fullname
                    if trace_names then
                        report_names("adding runtime filename %a for %a",c,fullname)
                    end
                end
            end
        end
    end
end

local function addruntimefiles(variable)
    local paths = variable and resolvers.expandedpathlistfromvariable(variable)
    if paths and #paths > 0 then
        addruntimepath(paths)
    end
end

names.addruntimepath  = addruntimepath
names.addruntimefiles = addruntimefiles

function names.getfilename(askedname,suffix) -- last resort, strip funny chars
    if not runtimedone then
        addruntimefiles(names.runtimefontsvariable)
        runtimedone = true
    end
    local cleanname = cleanfilename(askedname,suffix)
    local found     = runtimefiles[cleanname]
    if found then
        return found
    end
    names.load()
    local files = names.data.files
    local found = files and files[cleanname] or ""
    if found == "" and is_reloaded() then
        files = names.data.files
        found = files and files[cleanname] or ""
    end
    if found and found ~= "" then
        return resolvers.findbinfile(found,suffix) or "" -- we still need to locate it
    end
end

-- specified search

local function s_collect_weight_style_width_variant(found,done,all,weight,style,width,variant,family)
    if family then
        for i=1,#family do
            local f = family[i]
            if f and weight == f.weight and style == f.style and width == f.width and variant == f.variant then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_weight_style_width_variant(found,done,all,weight,style,width,variant,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and weight == f.weight and style == f.style and width == f.width and variant == f.variant and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect_weight_style_width(found,done,all,weight,style,width,family)
    if family then
        for i=1,#family do
            local f = family[i]
            if f and weight == f.weight and style == f.style and width == f.width then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_weight_style_width(found,done,all,weight,style,width,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and weight == f.weight and style == f.style and width == f.width and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect_weight_style(found,done,all,weight,style,family)
    if family then
        for i=1,#family do local f = family[i]
            if f and weight == f.weight and style == f.style then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_weight_style(found,done,all,weight,style,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and weight == f.weight and style == f.style and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect_style_width(found,done,all,style,width,family)
    if family then
        for i=1,#family do local f = family[i]
            if f and style == f.style and width == f.width then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_style_width(found,done,all,style,width,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and style == f.style and width == f.width and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect_weight(found,done,all,weight,family)
    if family then
        for i=1,#family do local f = family[i]
            if f and weight == f.weight then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_weight(found,done,all,weight,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and weight == f.weight and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect_style(found,done,all,style,family)
    if family then
        for i=1,#family do local f = family[i]
            if f and style == f.style then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_style(found,done,all,style,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and style == f.style and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect_width(found,done,all,width,family)
    if family then
        for i=1,#family do local f = family[i]
            if f and width == f.width then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect_width(found,done,all,width,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and width == f.width and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function s_collect(found,done,all,family)
    if family then
        for i=1,#family do local f = family[i]
            if f then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end
local function m_collect(found,done,all,families,sorted,strictname)
    for i=1,#sorted do
        local k = sorted[i]
        local family = families[k]
        for i=1,#family do
            local f = family[i]
            if not done[f] and find(f.fontname,strictname) then
                found[#found+1], done[f] = f, true
                if not all then return end
            end
        end
    end
end

local function collect(stage,found,done,name,weight,style,width,variant,all)
    local data = names.data
    local families = data.families
    local sorted = data.sorted_families
    local strictname = "^".. name -- to be checked
    local family = families[name]
    if trace_names then
        report_names("resolving name %a, weight %a, style %a, width %a, variant %a",name,weight,style,width,variant)
    end
    if weight and weight ~= "" then
        if style and style ~= "" then
            if width and width ~= "" then
                if variant and variant ~= "" then
                    if trace_names then
                        report_names("resolving stage %s, name %a, weight %a, style %a, width %a, variant %a",stage,name,weight,style,width,variant)
                    end
                    s_collect_weight_style_width_variant(found,done,all,weight,style,width,variant,family)
                    m_collect_weight_style_width_variant(found,done,all,weight,style,width,variant,families,sorted,strictname)
                else
                    if trace_names then
                        report_names("resolving stage %s, name %a, weight %a, style %a, width %a",stage,name,weight,style,width)
                    end
                    s_collect_weight_style_width(found,done,all,weight,style,width,family)
                    m_collect_weight_style_width(found,done,all,weight,style,width,families,sorted,strictname)
                end
            else
                if trace_names then
                    report_names("resolving stage %s, name %a, weight %a, style %a",stage,name,weight,style)
                end
                s_collect_weight_style(found,done,all,weight,style,family)
                m_collect_weight_style(found,done,all,weight,style,families,sorted,strictname)
            end
        else
            if trace_names then
                report_names("resolving stage %s, name %a, weight %a",stage,name,weight)
            end
            s_collect_weight(found,done,all,weight,family)
            m_collect_weight(found,done,all,weight,families,sorted,strictname)
        end
    elseif style and style ~= "" then
        if width and width ~= "" then
            if trace_names then
                report_names("resolving stage %s, name %a, style %a, width %a",stage,name,style,width)
            end
            s_collect_style_width(found,done,all,style,width,family)
            m_collect_style_width(found,done,all,style,width,families,sorted,strictname)
        else
            if trace_names then
                report_names("resolving stage %s, name %a, style %a",stage,name,style)
            end
            s_collect_style(found,done,all,style,family)
            m_collect_style(found,done,all,style,families,sorted,strictname)
        end
    elseif width and width ~= "" then
        if trace_names then
            report_names("resolving stage %s, name %a, width %a",stage,name,width)
        end
        s_collect_width(found,done,all,width,family)
        m_collect_width(found,done,all,width,families,sorted,strictname)
    else
        if trace_names then
            report_names("resolving stage %s, name %a",stage,name)
        end
        s_collect(found,done,all,family)
        m_collect(found,done,all,families,sorted,strictname)
    end
end

local function heuristic(name,weight,style,width,variant,all) -- todo: fallbacks
    local found, done = { }, { }
--~ print(name,weight,style,width,variant)
    weight, style, width, variant = weight or "normal", style or "normal", width or "normal", variant or "normal"
    name = cleanname(name)
    collect(1,found,done,name,weight,style,width,variant,all)
    -- still needed ?
    if #found == 0 and variant ~= "normal" then -- not weight
        variant = "normal"
        collect(4,found,done,name,weight,style,width,variant,all)
    end
    if #found == 0 and width ~= "normal" then
        width = "normal"
        collect(2,found,done,name,weight,style,width,variant,all)
    end
    if #found == 0 and weight ~= "normal" then -- not style
        weight = "normal"
        collect(3,found,done,name,weight,style,width,variant,all)
    end
    if #found == 0 and style ~= "normal" then -- not weight
        style = "normal"
        collect(4,found,done,name,weight,style,width,variant,all)
    end
    --
    local nf = #found
    if trace_names then
        if nf then
            local t = { }
            for i=1,nf do
                t[i] = formatters["%a"](found[i].fontname)
            end
            report_names("name %a resolved to %s instances: % t",name,nf,t)
        else
            report_names("name %a unresolved",name)
        end
    end
    if all then
        return nf > 0 and found
    else
        return found[1]
    end
end

function names.specification(askedname,weight,style,width,variant,reload,all)
    if askedname and askedname ~= "" and names.enabled then
        askedname = cleanname(askedname) -- or cleanname
        names.load(reload)
        local found = heuristic(askedname,weight,style,width,variant,all)
        if not found and is_reloaded() then
            found = heuristic(askedname,weight,style,width,variant,all)
            if not filename then
                found = foundname(askedname) -- old method
            end
        end
        return found
    end
end

function names.collect(askedname,weight,style,width,variant,reload,all)
    if askedname and askedname ~= "" and names.enabled then
        askedname = cleanname(askedname) -- or cleanname
        names.load(reload)
        local list = heuristic(askedname,weight,style,width,variant,true)
        if not list or #list == 0 and is_reloaded() then
            list = heuristic(askedname,weight,style,width,variant,true)
        end
        return list
    end
end

function names.collectspec(askedname,reload,all)
    local name, weight, style, width, variant = names.splitspec(askedname)
    return names.collect(name,weight,style,width,variant,reload,all)
end

function names.resolvespec(askedname,sub) -- redefined later
    local found = names.specification(names.splitspec(askedname))
    if found then
        return found.filename, found.subfont and found.rawname
    end
end

function names.collectfiles(askedname,reload) -- no all
    if askedname and askedname ~= "" and names.enabled then
        askedname = cleanname(askedname) -- or cleanname
        names.load(reload)
        local list = { }
        local specifications = names.data.specifications
        for i=1,#specifications do
            local s = specifications[i]
            if find(cleanname(basename(s.filename)),askedname) then
                list[#list+1] = s
            end
        end
        return list
    end
end

-- todo:
--
-- blacklisted = {
--     ["cmr10.ttf"] = "completely messed up",
-- }

function names.exists(name)
    local found = false
    local list = filters.list
    for k=1,#list do
        local v = list[k]
        found = (findfile(name,v) or "") ~= ""
        if found then
            return found
        end
    end
    return (findfile(name,"tfm") or "") ~= "" or (names.resolve(name) or "") ~= ""
end

local lastlookups, lastpattern = { }, ""

-- function names.lookup(pattern,name,reload) -- todo: find
--     if lastpattern ~= pattern then
--         names.load(reload)
--         local specifications = names.data.specifications
--         local families = names.data.families
--         local lookups = specifications
--         if name then
--             lookups = families[name]
--         elseif not find(pattern,"=",1,true) then
--             lookups = families[pattern]
--         end
--         if trace_names then
--             report_names("starting with %s lookups for %a",#lookups,pattern)
--         end
--         if lookups then
--             for key, value in gmatch(pattern,"([^=,]+)=([^=,]+)") do
--                 local t, n = { }, 0
--                 if find(value,"*",1,true) then
--                     value = topattern(value)
--                     for i=1,#lookups do
--                         local s = lookups[i]
--                         if find(s[key],value) then
--                             n = n + 1
--                             t[n] = lookups[i]
--                         end
--                     end
--                 else
--                     for i=1,#lookups do
--                         local s = lookups[i]
--                         if s[key] == value then
--                             n = n + 1
--                             t[n] = lookups[i]
--                         end
--                     end
--                 end
--                 if trace_names then
--                     report_names("%s matches for key %a with value %a",#t,key,value)
--                 end
--                 lookups = t
--             end
--         end
--         lastpattern = pattern
--         lastlookups = lookups or { }
--     end
--     return #lastlookups
-- end

local function look_them_up(lookups,specification)
    for key, value in sortedhash(specification) do
        local t = { }
        local n = 0
        if find(value,"*",1,true) then
            value = topattern(value)
            for i=1,#lookups do
                local s = lookups[i]
                if find(s[key],value) then
                    n = n + 1
                    t[n] = lookups[i]
                end
            end
        else
            for i=1,#lookups do
                local s = lookups[i]
                if s[key] == value then
                    n = n + 1
                    t[n] = lookups[i]
                end
            end
        end
        if trace_names then
            report_names("%s matches for key %a with value %a",#t,key,value)
        end
        lookups = t
    end
    return lookups
end

local function first_look(name,reload)
    names.load(reload)
    local data           = names.data
    local specifications = data.specifications
    local families       = data.families
    if name then
        return families[name]
    else
        return specifications
    end
end

function names.lookup(pattern,name,reload) -- todo: find
    names.load(reload)
    local data           = names.data
    local specifications = data.specifications
    local families       = data.families
    local lookups        = specifications
    if name then
        name = cleanname(name)
    end
    if type(pattern) == "table" then
        local familyname = pattern.familyname
        if familyname then
            familyname = cleanname(familyname)
            pattern.familyname = familyname
        end
        local lookups = first_look(name or familyname,reload)
        if lookups then
            if trace_names then
                report_names("starting with %s lookups for '%T'",#lookups,pattern)
            end
            lookups = look_them_up(lookups,pattern)
        end
        lastpattern = false
        lastlookups = lookups or { }
    elseif lastpattern ~= pattern then
        local lookups = first_look(name or (not find(pattern,"=",1,true) and pattern),reload)
        if lookups then
            if trace_names then
                report_names("starting with %s lookups for %a",#lookups,pattern)
            end
            local specification = settings_to_hash(pattern)
            local familyname = specification.familyname
            if familyname then
                familyname = cleanname(familyname)
                specification.familyname = familyname
            end
            lookups = look_them_up(lookups,specification)
        end
        lastpattern = pattern
        lastlookups = lookups or { }
    end
    return #lastlookups
end

function names.getlookupkey(key,n)
    local l = lastlookups[n or 1]
    return (l and l[key]) or ""
end

function names.noflookups()
    return #lastlookups
end

function names.getlookups(pattern,name,reload)
    if pattern then
        names.lookup(pattern,name,reload)
    end
    return lastlookups
end

-- The following is new ... watch the overload!

local specifications = allocate()
names.specifications = specifications

-- files = {
--     name = "antykwapoltawskiego",
--     list = {
--         ["AntPoltLtCond-Regular.otf"] = {
--          -- name   = "antykwapoltawskiego",
--             style  = "regular",
--             weight = "light",
--             width  = "condensed",
--         },
--     },
-- }

function names.register(files)
    if files then
        local list, commonname = files.list, files.name
        if list then
            local n, m = 0, 0
            for filename, filespec in sortedhash(list) do
                local name = lower(filespec.name or commonname)
                if name and name ~= "" then
                    local style    = normalized_styles  [lower(filespec.style   or "normal")]
                    local width    = normalized_widths  [lower(filespec.width   or "normal")]
                    local weight   = normalized_weights [lower(filespec.weight  or "normal")]
                    local variant  = normalized_variants[lower(filespec.variant or "normal")]
                    local weights  = specifications[name  ] if not weights  then weights  = { } specifications[name  ] = weights  end
                    local styles   = weights       [weight] if not styles   then styles   = { } weights       [weight] = styles   end
                    local widths   = styles        [style ] if not widths   then widths   = { } styles        [style ] = widths   end
                    local variants = widths        [width ] if not variants then variants = { } widths        [width ] = variants end
                    variants[variant] = filename
                    n = n + 1
                else
                    m = m + 1
                end
            end
            if trace_specifications then
                report_names("%s filenames registered, %s filenames rejected",n,m)
            end
        end
    end
end

function names.registered(name,weight,style,width,variant)
    local ok = specifications[name]
    ok = ok and (ok[(weight  and weight  ~= "" and weight ) or "normal"] or ok.normal)
    ok = ok and (ok[(style   and style   ~= "" and style  ) or "normal"] or ok.normal)
    ok = ok and (ok[(width   and width   ~= "" and width  ) or "normal"] or ok.normal)
    ok = ok and (ok[(variant and variant ~= "" and variant) or "normal"] or ok.normal)
    --
    -- todo: same fallbacks as with database
    --
    if ok then
        return {
            filename = ok,
            subname  = "",
         -- rawname  = nil,
        }
    end
end

function names.resolvespec(askedname,sub) -- overloads previous definition
    local name, weight, style, width, variant = names.splitspec(askedname)
    if trace_specifications then
        report_names("resolving specification: %a to name=%s, weight=%s, style=%s, width=%s, variant=%s",askedname,name,weight,style,width,variant)
    end
    local found = names.registered(name,weight,style,width,variant)
    if found and found.filename then
        if trace_specifications then
            report_names("resolved by registered names: %a to %s",askedname,found.filename)
        end
        return found.filename, found.subname, found.rawname
    else
        found = names.specification(name,weight,style,width,variant)
        if found and found.filename then
            if trace_specifications then
                report_names("resolved by font database: %a to %s",askedname,found.filename)
            end
            return found.filename, found.subfont and found.rawname
        end
    end
    if trace_specifications then
        report_names("unresolved: %s",askedname)
    end
end

function fonts.names.ignoredfile(filename) -- only supported in mkiv
    return false -- will be overloaded
end

-- example made for luatex list (unlikely to be used):
--
-- local command = [[reg QUERY "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"]]
-- local pattern = ".-[\n\r]+%s+(.-)%s%(([^%)]+)%)%s+REG_SZ%s+(%S+)%s+"
--
-- local function getnamesfromregistry()
--     local data = os.resultof(command)
--     local list = { }
--     for name, format, filename in string.gmatch(data,pattern) do
--         list[name] = filename
--     end
--     return list
-- end
