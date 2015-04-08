if not modules then modules = { } end modules ['typo-lan'] = {
    version   = 1.001,
    comment   = "companion to typo-lan.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next = type, next

local currentfont       = font.current
local setmetatableindex = table.setmetatableindex
local utfbyte           = utf.byte

local hashes            = fonts.hashes
local fontdata          = hashes.characters
local emwidths          = hashes.emwidths

local frequencies       = languages.frequencies or { }
languages.frequencies   = frequencies

local frequencydata     = { }
local frequencyfile     = string.formatters["lang-frq-%s.lua"]
local frequencycache    = { }

setmetatableindex(frequencydata, function(t,language)
    local fullname = resolvers.findfile(frequencyfile(language))
    local v = fullname ~= "" and dofile(fullname)
    if not v or not v.frequencies then
        v = t.en
    end
    t[language] = v
    return v
end)

setmetatableindex(frequencycache, function(t,language)
    local dataset = frequencydata[language]
    local frequencies = dataset.frequencies
    if not frequencies then
        return t.en
    end
    local v = { }
    setmetatableindex(v, function(t,font)
        local average = emwidths[font] / 2
        if frequencies then
            local characters = fontdata[font]
            local sum, tot = 0, 0
            for k, v in next, frequencies do
                local character = characters[k] -- characters[type(k) == "number" and k or utfbyte(k)]
                tot = tot + v
                sum = sum + v * (character and character.width or average)
            end
            average = sum / tot -- widths
        end
        t[font] = average
        return average
    end)
    t[language] = v
    return v
end)

function frequencies.getdata(language)
    return frequencydata[language]
end

function frequencies.averagecharwidth(language,font)
    return frequencycache[language or "en"][font or currentfont()]
end

interfaces.implement {
    name      = "averagecharwidth",
    actions   = { frequencies.averagecharwidth, context },
    arguments = "string"
}
