if not modules then modules = { } end modules ['luatex-plain-tfm'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- \font\foo=file:luatex-plain-tfm.lua:tfm=csr10;enc=csr;pfb=csr10 at 12pt
--
-- \foo áäčďěíĺľňóôŕřšťúýž ff ffi \input tufte

return function(specification)

    local size = specification.size
    local feat = specification.features and specification.features.normal

    if not feat then
        return
    end

    local tfm = feat.tfm
    local enc = feat.enc or tfm
    local pfb = feat.pfb or tfm

    if not tfm then
        return
    end

    local tfmfile = tfm .. ".tfm"
    local encfile = enc .. ".enc"
    local pfbfile = pfb .. ".pfb"

    local tfmdata, id = fonts.constructors.readanddefine("file:"..tfmfile,size)

    local encoding = fonts.encodings.load(encfile)
    if encoding then
        encoding = encoding.hash
    else
        encoding = false
    end

    local unicoding = fonts.encodings.agl and fonts.encodings.agl.unicodes

    if tfmdata and encoding and unicoding then

        local characters = { }
        local originals  = tfmdata.characters
        local indices    = { }
        local parentfont = { "font", 1 }
        local mapline    = tfm .. "<" .. pfbfile -- .."<"..encfile

        local dummy = unicoding.foo -- foo forces loading

        -- create characters table

        for name, index in next, encoding do
            local unicode = unicoding[name]
            if unicode then
                local original = originals[index]
                original.name = name -- so one can lookup weird names
                original.commands = { parentfont, { "char", index } }
                characters[unicode] = original
                indices[index] = unicode
            else
                -- unknown name
            end
        end

        -- also include ligatures and whatever left

        local p = fonts.constructors.privateoffset
        for k, v in next, originals do
            if not indices[k] then
                characters[p] = v
                indices[k] = p
                p = p + 1
            end
        end

        -- redo kerns and ligatures

        for k, v in next, characters do
            local kerns = v.kerns
            if kerns then
                local t = { }
                for k, v in next, kerns do
                    local i = indices[k]
                    t[i] = v
                end
                v.kerns = t
            end
            local ligatures = v.ligatures
            if ligatures then
                local t = { }
                for k, v in next, ligatures do
                    t[indices[k]] = v
                    v.char = indices[v.char]
                end
                v.ligatures = t
            end
        end

        -- wrap up

        tfmdata.fonts      = { { id = id } }
        tfmdata.characters = characters

        pdf.mapline(mapline)

    end
    return tfmdata
end
