if not modules then modules = { } end modules ['font-shp'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat = table.concat
local load, tonumber = load, tonumber

local otf         = fonts.handlers.otf
local afm         = fonts.handlers.afm

local hashes      = fonts.hashes
local identifiers = hashes.identifiers

local version     = 0.006
local cache       = containers.define("fonts", "shapes", version, true)

-- shapes (can be come a separate file at some point)

local function packoutlines(data,makesequence)
    local subfonts = data.subfonts
    if subfonts then
        for i=1,#subfonts do
            packoutlines(subfonts[i],makesequence)
        end
        return
    end
    local common = data.segments
    if common then
        return
    end
    local glyphs = data.glyphs
    if not glyphs then
        return
    end
    if makesequence then
        for index=1,#glyphs do
            local glyph = glyphs[index]
            local segments = glyph.segments
            if segments then
                local sequence    = { }
                local nofsequence = 0
                for i=1,#segments do
                    local segment    = segments[i]
                    local nofsegment = #segment
                    nofsequence = nofsequence + 1
                    sequence[nofsequence] = segment[nofsegment]
                    for i=1,nofsegment-1 do
                        nofsequence = nofsequence + 1
                        sequence[nofsequence] = segment[i]
                    end
                end
                glyph.sequence = sequence
                glyph.segments = nil
            end
        end
    else
        local hash    = { }
        local common  = { }
        local reverse = { }
        local last    = 0
        for index=1,#glyphs do
            local segments = glyphs[index].segments
            if segments then
                for i=1,#segments do
                    local h = concat(segments[i]," ")
                    hash[h] = (hash[h] or 0) + 1
                end
            end
        end
        for index=1,#glyphs do
            local segments = glyphs[index].segments
            if segments then
                for i=1,#segments do
                    local segment = segments[i]
                    local h = concat(segment," ")
                    if hash[h] > 1 then -- minimal one shared in order to hash
                        local idx = reverse[h]
                        if not idx then
                            last = last + 1
                            reverse[h] = last
                            common[last] = segment
                            idx = last
                        end
                        segments[i] = idx
                    end
                end
            end
        end
        if last > 0 then
            data.segments = common
        end
    end
end

local function unpackoutlines(data)
    local subfonts = data.subfonts
    if subfonts then
        for i=1,#subfonts do
            unpackoutlines(subfonts[i])
        end
        return
    end
    local common = data.segments
    if not common then
        return
    end
    local glyphs = data.glyphs
    if not glyphs then
        return
    end
    for index=1,#glyphs do
        local segments = glyphs[index].segments
        if segments then
            for i=1,#segments do
                local c = common[segments[i]]
                if c then
                    segments[i] = c
                end
            end
        end
    end
    data.segments = nil
end

-- todo: loaders per format

local function load(filename,sub)
    local base = file.basename(filename)
    local name = file.removesuffix(base)
    local kind = file.suffix(filename)
    local attr = lfs.attributes(filename)
    local size = attr and attr.size or 0
    local time = attr and attr.modification or 0
    local sub  = tonumber(sub)

    -- fonts.formats

    if size > 0 and (kind == "otf" or kind == "ttf" or kind == "tcc") then
        local hash = containers.cleanname(base) -- including suffix
        if sub then
            hash = hash .. "-" .. sub
        end
        data = containers.read(cache,hash)
        if not data or data.time ~= time or data.size  ~= size then
            data = otf.readers.loadshapes(filename,sub)
            if data then
                data.size   = size
                data.format = data.format or (kind == "otf" and "opentype") or "truetype"
                data.time   = time
                packoutlines(data)
                containers.write(cache,hash,data)
                data = containers.read(cache,hash) -- frees old mem
            end
        end
        unpackoutlines(data)
    elseif size > 0 and (kind == "pfb") then
        local hash = containers.cleanname(base) -- including suffix
        data = containers.read(cache,hash)
        if not data or data.time ~= time or data.size  ~= size then
            data = afm.readers.loadshapes(filename)
            if data then
                data.size   = size
                data.format = "type1"
                data.time   = time
                packoutlines(data)
                containers.write(cache,hash,data)
                data = containers.read(cache,hash) -- frees old mem
            end
        end
        unpackoutlines(data)
    else
        data = {
            filename = filename,
            size     = 0,
            time     = time,
            format   = "unknown",
            units    = 1000,
            glyphs   = { }
        }
    end
    return data
end

hashes.shapes = table.setmetatableindex(function(t,k)
    local d = identifiers[k]
    local v = load(d.properties.filename,d.subindex)
    t[k] = v
    return v
end)
