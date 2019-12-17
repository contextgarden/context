if not modules then modules = { } end modules ['data-env'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lower, gsub = string.lower, string.gsub
local next, rawget = next, rawget

local resolvers = resolvers

local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex
local suffixonly        = file.suffixonly

local formats           = allocate()
local suffixes          = allocate()
local dangerous         = allocate()
local suffixmap         = allocate()
local usertypes         = allocate()

resolvers.formats       = formats
resolvers.suffixes      = suffixes
resolvers.dangerous     = dangerous
resolvers.suffixmap     = suffixmap
resolvers.usertypes     = usertypes

local luasuffixes       = utilities.lua.suffixes

local relations = allocate { -- todo: handlers also here
    core = {
        ofm = { -- will become obsolete
            names    = { "ofm", "omega font metric", "omega font metrics" },
            variable = 'OFMFONTS',
            suffixes = { 'ofm', 'tfm' },
        },
        ovf = { -- will become obsolete
            names    = { "ovf", "omega virtual font", "omega virtual fonts" },
            variable = 'OVFFONTS',
            suffixes = { 'ovf', 'vf' },
        },
        tfm = {
            names    = { "tfm", "tex font metric", "tex font metrics" },
            variable = 'TFMFONTS',
            suffixes = { 'tfm' },
        },
        vf = {
            names    = { "vf", "virtual font", "virtual fonts" },
            variable = 'VFFONTS',
            suffixes = { 'vf' },
        },
        otf = {
            names    = { "otf", "opentype", "opentype font", "opentype fonts"},
            variable = 'OPENTYPEFONTS',
            suffixes = { 'otf' },
        },
        ttf = {
            names    = { "ttf", "truetype", "truetype font", "truetype fonts", "truetype collection", "truetype collections", "truetype dictionary", "truetype dictionaries" },
            variable = 'TTFONTS',
            suffixes = { 'ttf', 'ttc', 'dfont' },
        },
        afm = {
            names    = { "afm", "adobe font metric", "adobe font metrics" },
            variable = "AFMFONTS",
            suffixes = { "afm" },
        },
        pfb = {
            names    = { "pfb", "type1", "type 1", "type1 font", "type 1 font", "type1 fonts", "type 1 fonts" },
            variable = 'T1FONTS',
            suffixes = { 'pfb', 'pfa' },
        },
        fea = {
            names    = { "fea", "font feature", "font features", "font feature file", "font feature files" },
            variable = 'FONTFEATURES',
            suffixes = { 'fea' },
        },
        cid = {
            names    = { "cid", "cid map", "cid maps", "cid file", "cid files" },
            variable = 'FONTCIDMAPS',
            suffixes = { 'cid', 'cidmap' },
        },
        fmt = {
            names    = { "fmt", "format", "tex format" },
            variable = 'TEXFORMATS',
            suffixes = { 'fmt' },
        },
        mem = { -- will become obsolete
            names    = { 'mem', "metapost format" },
            variable = 'MPMEMS',
            suffixes = { 'mem' },
        },
        mp = {
            names    = { "mp" },
            variable = 'MPINPUTS',
            suffixes = { 'mp', 'mpvi', 'mpiv', 'mpxl', 'mpii' },
            usertype = true,
        },
        tex = {
            names    = { "tex" },
            variable = 'TEXINPUTS',
            suffixes = { "tex", "mkiv", "mkvi", "mkxl", "mklx", "mkii", "cld", "lfg", "xml" }, -- known suffixes have less lookups
            usertype = true,
        },
        icc = {
            names    = { "icc", "icc profile", "icc profiles" },
            variable = 'ICCPROFILES',
            suffixes = { 'icc' },
        },
        texmfscripts = {
            names    = { "texmfscript", "texmfscripts", "script", "scripts" },
            variable = 'TEXMFSCRIPTS',
            suffixes = { 'lua', 'rb', 'pl', 'py' },
        },
        lua = {
            names    = { "lua" },
            variable = 'LUAINPUTS',
            suffixes = { luasuffixes.lua, luasuffixes.luc, luasuffixes.tma, luasuffixes.tmc },
            usertype = true,
        },
        lib = {
            names    = { "lib" },
            variable = 'CLUAINPUTS',
            suffixes = os.libsuffix and { os.libsuffix } or { 'dll', 'so' },
        },
        bib = {
            names    = { 'bib' },
            variable = 'BIBINPUTS',
            suffixes = { 'bib' },
            usertype = true,
        },
        bst = {
            names    = { 'bst' },
            variable = 'BSTINPUTS',
            suffixes = { 'bst' },
            usertype = true,
        },
        fontconfig = {
            names    = { 'fontconfig', 'fontconfig file', 'fontconfig files' },
            variable = 'FONTCONFIG_PATH',
        },
        pk = {
            names    = { "pk" },
            variable = 'PKFONTS',
            suffixes = { 'pk' },
        },
    },
    obsolete = {
        enc = {
            names    = { "enc", "enc files", "enc file", "encoding files", "encoding file" },
            variable = 'ENCFONTS',
            suffixes = { 'enc' },
        },
        map = {
            names    = { "map", "map files", "map file" },
            variable = 'TEXFONTMAPS',
            suffixes = { 'map' },
        },
        lig = {
            names    = { "lig files", "lig file", "ligature file", "ligature files" },
            variable = 'LIGFONTS',
            suffixes = { 'lig' },
        },
        opl = {
            names    = { "opl" },
            variable = 'OPLFONTS',
            suffixes = { 'opl' },
        },
        ovp = {
            names    = { "ovp" },
            variable = 'OVPFONTS',
            suffixes = { 'ovp' },
        },
    },
    kpse = { -- subset
        base = {
            names    = { 'base', "metafont format" },
            variable = 'MFBASES',
            suffixes = { 'base', 'bas' },
        },
        cmap = {
            names    = { 'cmap', 'cmap files', 'cmap file' },
            variable = 'CMAPFONTS',
            suffixes = { 'cmap' },
        },
        cnf = {
            names    = { 'cnf' },
            suffixes = { 'cnf' },
        },
        web = {
            names    = { 'web' },
            suffixes = { 'web', 'ch' }
        },
        cweb = {
            names    = { 'cweb' },
            suffixes = { 'w', 'web', 'ch' },
        },
        gf = {
            names    = { 'gf' },
            suffixes = { '<resolution>gf' },
        },
        mf = {
            names    = { 'mf' },
            variable = 'MFINPUTS',
            suffixes = { 'mf' },
        },
        mft = {
            names    = { 'mft' },
            suffixes = { 'mft' },
        },
        pk = {
            names    = { 'pk' },
            suffixes = { '<resolution>pk' },
        },
    },
}

resolvers.relations = relations

-- formats: maps a format onto a variable

function resolvers.updaterelations()
    for category, categories in next, relations do
        for name, relation in next, categories do
            local rn = relation.names
            local rv = relation.variable
            if rn and rv then
                local rs = relation.suffixes
                local ru = relation.usertype
                for i=1,#rn do
                    local rni = lower(gsub(rn[i]," ",""))
                    formats[rni] = rv
                    if rs then
                        suffixes[rni] = rs
                        for i=1,#rs do
                            local rsi = rs[i]
                            suffixmap[rsi] = rni
                        end
                    end
                end
                if ru then
                    usertypes[name] = true
                end
            end
        end
    end
end

resolvers.updaterelations() -- push this in the metatable -> newindex

local function simplified(t,k)
    return k and rawget(t,lower(gsub(k," ",""))) or nil
end

setmetatableindex(formats,   simplified)
setmetatableindex(suffixes,  simplified)
setmetatableindex(suffixmap, simplified)

-- A few accessors, mostly for command line tool.

function resolvers.suffixofformat(str)
    local s = suffixes[str]
    return s and s[1] or ""
end

function resolvers.suffixofformat(str)
    return suffixes[str] or { }
end

for name, format in next, formats do
    dangerous[name] = true -- still needed ?
end

-- because vf searching is somewhat dangerous, we want to prevent
-- too liberal searching esp because we do a lookup on the current
-- path anyway; only tex (or any) is safe

dangerous.tex = nil

--~ print(table.serialize(dangerous))

-- more helpers

function resolvers.formatofvariable(str)
    return formats[str] or ''
end

function resolvers.formatofsuffix(str) -- of file
    return suffixmap[suffixonly(str)] or 'tex' -- so many map onto tex (like mkiv, cld etc)
end

function resolvers.variableofformat(str)
    return formats[str] or ''
end

function resolvers.variableofformatorsuffix(str)
    local v = formats[str]
    if v then
        return v
    end
    v = suffixmap[suffixonly(str)]
    if v then
        return formats[v]
    end
    return ''
end

