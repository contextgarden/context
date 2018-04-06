if not modules then modules = { } end modules ['font-enh'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next

local trace_unicoding    = false

trackers.register("fonts.defining",  function(v) trace_unicoding = v end)
trackers.register("fonts.unicoding", function(v) trace_unicoding = v end)

local report_unicoding   = logs.reporter("fonts","unicoding")

local fonts              = fonts
local constructors       = fonts.constructors

----- tfmfeatures        = constructors.features.tfm
local afmfeatures        = constructors.features.afm
local otffeatures        = constructors.features.otf

----- registertfmfeature = tfmfeatures.register
local registerafmfeature = afmfeatures.register
local registerotffeature = otffeatures.register

-- -- these will become goodies (when needed at all)
--
-- local fontencodings      = fonts.encodings
-- fontencodings.remappings = fontencodings.remappings or { }
--
-- local function reencode(tfmdata,encoding)
--     if encoding and fontencodings.known[encoding] then
--         local data = fontencodings.load(encoding)
--         if data then
--             tfmdata.properties.encoding = encoding
--             local characters = tfmdata.characters
--             local original   = { }
--             local vector     = data.vector
--             for unicode, character in next, characters do
--                 character.name    = vector[unicode]
--                 character.index   = unicode, character
--                 original[unicode] = character
--             end
--             for newcode, oldcode in next, data.unicodes do
--                 if newcode ~= oldcode then
--                     if trace_unicoding then
--                         report_unicoding("reencoding %U to %U",oldcode,newcode)
--                     end
--                     characters[newcode] = original[oldcode]
--                 end
--             end
--         end
--     end
-- end
--
-- registertfmfeature {
--     name         = "reencode",
--     description  = "reencode",
--     manipulators = {
--         base = reencode,
--         node = reencode,
--     }
-- }
--
-- local function remap(tfmdata,remapping)
--     local vector = remapping and fontencodings.remappings[remapping]
--     if vector then
--         local characters, original = tfmdata.characters, { }
--         for k, v in next, characters do
--             original[k], characters[k] = v, nil
--         end
--         for k,v in next, vector do
--             if k ~= v then
--                 if trace_unicoding then
--                     report_unicoding("remapping %U to %U",k,v)
--                 end
--                 local c = original[k]
--                 characters[v] = c
--                 c.index = k
--             end
--         end
--         local properties = tfmdata.properties
--         if not properties then
--             properties = { }
--             tfmdata.properties = properties
--         else
--             properties.encodingbytes = 2
--             properties.format        = properties.format or 'type1'
--         end
--     end
-- end
--
-- registertfmfeature {
--     name         = "remap",
--     description  = "remap",
--     manipulators = {
--         base = remap,
--         node = remap,
--     }
-- }

-- \definefontfeature[dingbats][goodies=dingbats,unicoding=yes]

-- we only add and don't replace
-- we could also add kerns but we asssume symbols
-- todo: complain if not basemode

--  remapping = {
--      tounicode = true,
--      unicodes = {
--         a1   = 0x2701,

----- tosixteen = fonts.mappings.tounicode16

local function initialize(tfmdata)
    local goodies   = tfmdata.goodies
    local newcoding = nil
    for i=1,#goodies do
        local remapping = goodies[i].remapping
        if remapping and remapping.unicodes then
            newcoding = remapping.unicodes  -- names to unicodes
        end
    end
    if newcoding then
        local characters   = tfmdata.characters
        local descriptions = tfmdata.descriptions
        local oldcoding    = tfmdata.resources.unicodes
        local originals    = { }
        for name, newcode in next, newcoding do
            local oldcode = oldcoding[name]
            if characters[newcode] and not originals[newcode] then
                originals[newcode] = {
                    character   = characters  [newcode],
                    description = descriptions[newcode],
                }
            end
            if oldcode then
                local original = originals[oldcode]
                local character, description
                if original then
                    character   = original.character
                    description = original.description
                else
                    character   = characters  [oldcode]
                    description = descriptions[oldcode]
                end
                characters  [newcode] = character
                descriptions[newcode] = description
                character  .unicode = newcode
                description.unicode = newcode
            else
                oldcoding[name] = newcode
            end
            if trace_unicoding then
                if oldcode then
                    report_unicoding("aliasing glyph %a from %U to %U",name,oldcode,newcode)
                else
                    report_unicoding("aliasing glyph %a to %U",name,newcode)
                end
            end
        end
    end
end

local specification = {
    name        = "unicoding",
    description = "adapt unicode table",
    initializers = {
        base = initialize,
        node = initialize,
    },
}

registerotffeature(specification)
registerafmfeature(specification)
