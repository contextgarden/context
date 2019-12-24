if not modules then modules = { } end modules ['font-enc'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this module is obsolete

local next, rawget = next, rawget
local match, gmatch, gsub = string.match, string.gmatch, string.gsub

local setmetatableindex = table.setmetatableindex

local allocate          = utilities.storage.allocate
local mark              = utilities.storage.mark

--[[ldx--
<p>Because encodings are going to disappear, we don't bother defining
them in tables. But we may do so some day, for consistency.</p>
--ldx]]--

local report_encoding = logs.reporter("fonts","encoding")

local encodings = fonts.encodings or { }
fonts.encodings = encodings

encodings.version = 1.03
encodings.cache   = containers.define("fonts", "enc", fonts.encodings.version, true)
encodings.known   = allocate { -- sort of obsolete
    texnansi = true,
    ec       = true,
    qx       = true,
    t5       = true,
    t2a      = true,
    t2b      = true,
    t2c      = true,
    unicode  = true,
}

function encodings.is_known(encoding)
    return containers.is_valid(encodings.cache,encoding)
end

--[[ldx--
<p>An encoding file looks like this:</p>

<typing>
/TeXnANSIEncoding [
/.notdef
/Euro
...
/ydieresis
] def
</typing>

<p>Beware! The generic encoding files don't always apply to the ones that
ship with fonts. This has to do with the fact that names follow (slightly)
different standards. However, the fonts where this applies to (for instance
Latin Modern or <l n='tex'> Gyre) come in OpenType variants too, so these
will be used.</p>
--ldx]]--

local enccodes = characters.enccodes or { }

function encodings.load(filename)
    local name = file.removesuffix(filename)
    local data = containers.read(encodings.cache,name)
    if data then
        return data
    end
    if name == "unicode" then
        data = encodings.make_unicode_vector() -- special case, no tex file for this
    end
    if data then
        return data
    end
    local vector, tag, hash, unicodes = { }, "", { }, { }
    local foundname = resolvers.findfile(filename,'enc')
    if foundname and foundname ~= "" then
        local ok, encoding, size = resolvers.loadbinfile(foundname)
        if ok and encoding then
            encoding = gsub(encoding,"%%(.-)[\n\r]+","")
            if encoding then
                local unicoding = fonts.encodings.agl.unicodes
                local tag, vec = match(encoding,"[/]*(%w+)%s*%[(.*)%]%s*def")
                if vec then
                    local i = 0
                    for ch in gmatch(vec,"/([%a%d%.]+)") do
                        if ch ~= ".notdef" then
                            vector[i] = ch
                            if not hash[ch] then
                                hash[ch] = i
                            else
                                -- duplicate, play safe for tex ligs and take first
                            end
                            local u = unicoding[ch] or enccodes[ch] -- enccodes have also context names
                            if u then
                                unicodes[u] = i
                            end
                        end
                        i = i + 1
                    end
                else
                    report_encoding("reading vector in encoding file %a fails",filename)
                end
            else
                report_encoding("reading encoding file %a fails",filename)
            end
        end
    end
    local data = {
        name     = name,
        tag      = tag,
        vector   = vector,
        hash     = hash,
        unicodes = unicodes
    }
    return containers.write(encodings.cache, name, data)
end

--[[ldx--
<p>There is no unicode encoding but for practical purposes we define
one.</p>
--ldx]]--

-- maybe make this a function:

function encodings.make_unicode_vector()
    local vector, hash = { }, { }
    for code, v in next, characters.data do
        local name = v.adobename
        if name then
            vector[code] = name
            hash[name]   = code
        else
            vector[code] = '.notdef'
        end
    end
    for name, code in next, characters.synonyms do
        if not vector[code] then
            vector[code] = name
        end
        if not hash[name] then
            hash[name]   = code
        end
    end
    return containers.write(encodings.cache, 'unicode', { name='unicode', tag='unicode', vector=vector, hash=hash })
end

if not encodings.agl then

    -- We delay delay loading this rather big vector that is only needed when a
    -- font is loaded for caching. Once we're further along the route we can also
    -- delay it in the generic version (which doesn't use this file).

    encodings.agl = allocate { }

    setmetatableindex(encodings.agl, function(t,k)
        report_encoding("loading (extended) adobe glyph list")
        dofile(resolvers.findfile("font-agl.lua"))
        return rawget(encodings.agl,k)
    end)

end
