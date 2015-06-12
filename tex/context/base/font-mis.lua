if not modules then modules = { } end modules ['font-mis'] = {
    version   = 1.001,
    comment   = "companion to mtx-fonts",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next
local lower, strip = string.lower, string.strip

-- also used in other scripts so we need to check some tables:

fonts          = fonts or { }

fonts.helpers  = fonts.helpers or { }
local helpers  = fonts.helpers

fonts.handlers = fonts.handlers or { }
local handlers = fonts.handlers

handlers.otf   = handlers.otf or { }
local otf      = handlers.otf

otf.version    = otf.version or 2.815
otf.cache      = otf.cache   or containers.define("fonts", "otf", otf.version, true)

local fontloader    = fontloader
local font_to_table = fontloader.to_table
local open_font     = fontloader.open
local get_font_info = fontloader.info
local close_font    = fontloader.close

function otf.loadcached(filename,format,sub)
    -- no recache when version mismatch
    local name = file.basename(file.removesuffix(filename))
    if sub == "" then sub = false end
    local hash = name
    if sub then
        hash = hash .. "-" .. sub
    end
    hash = containers.cleanname(hash)
    local data = containers.read(otf.cache, hash)
    if data and not data.verbose then
        otf.enhancers.unpack(data)
        return data
    else
        return nil
    end
end

local featuregroups = { "gsub", "gpos" }

function fonts.helpers.getfeatures(name,t,script,language) -- maybe per font type
    local t = lower(t or (name and file.suffix(name)) or "")
    if t == "otf" or t == "ttf" or t == "ttc" or t == "dfont" then
        local filename = resolvers.findfile(name,t) or ""
        if filename ~= "" then
            local data = otf.loadcached(filename)
            if data and data.resources and data.resources.features then
                return  data.resources.features
            else
                local ff = open_font(filename)
                if ff then
                    local data = font_to_table(ff)
                    close_font(ff)
                    local features = { }
                    for k=1,#featuregroups do
                        local what = featuregroups[k]
                        local dw = data[what]
                        if dw then
                            local f = { }
                            features[what] = f
                            for i=1,#dw do
                                local d = dw[i]
                                local dfeatures = d.features
                                if dfeatures then
                                    for i=1,#dfeatures do
                                        local df = dfeatures[i]
                                        local tag = strip(lower(df.tag))
                                        local ft = f[tag] if not ft then ft = {} f[tag] = ft end
                                        local dfscripts = df.scripts
                                        for i=1,#dfscripts do
                                            local ds = dfscripts[i]
                                            local scri = strip(lower(ds.script))
                                            local fts = ft[scri] if not fts then fts = {} ft[scri] = fts end
                                            local dslangs = ds.langs
                                            for i=1,#dslangs do
                                                local lang = dslangs[i]
                                                lang = strip(lower(lang))
                                                if scri == script then
                                                    if lang == language then
                                                        fts[lang] = 'sl'
                                                    else
                                                        fts[lang] = 's'
                                                    end
                                                else
                                                    if lang == language then
                                                        fts[lang] = 'l'
                                                    else
                                                        fts[lang] = true
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    return features
                end
            end
        end
    end
    return nil, nil
end
