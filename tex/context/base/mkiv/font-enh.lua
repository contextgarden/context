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

----- tfmfeatures        = constructors.newfeatures("tfm")
----- registertfmfeature = tfmfeatures.register

local afmfeatures        = fonts.constructors.newfeatures("afm")
local registerafmfeature = afmfeatures.register

local otffeatures        = fonts.constructors.newfeatures("otf")
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

local function initializeunicoding(tfmdata)
    local goodies   = tfmdata.goodies
    local newcoding = nil
 -- local tounicode = false
    for i=1,#goodies do
        local remapping = goodies[i].remapping
        if remapping and remapping.unicodes then
            newcoding = remapping.unicodes  -- names to unicodes
         -- tounicode = remapping.tounicode -- not used
        end
    end
    if newcoding then
        local characters   = tfmdata.characters
        local descriptions = tfmdata.descriptions
        local oldcoding    = tfmdata.resources.unicodes
     -- local tounicodes   = tfmdata.resources.tounicode -- index to unicode
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
                if original then
                    characters  [newcode] = original.character
                    descriptions[newcode] = original.description
                else
                    characters  [newcode] = characters  [oldcode]
                    descriptions[newcode] = descriptions[oldcode]
                end
            else
                oldcoding[name] = newcode
            end
         -- if tounicode then
         --     local description = descriptions[newcode]
         --     if description then
         --         local index = description.index
         --         if not tounicodes[index] then
         --             tounicodes[index] = tosixteen(newcode) -- shared (we could have a metatable)
         --         end
         --     end
         -- end
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

local unicoding_specification = {
    name        = "unicoding",
    description = "adapt unicode table",
    initializers = {
        base = initializeunicoding,
        node = initializeunicoding,
    },
 -- manipulators = {
 --     base = finalizeunicoding,
 --     node = finalizeunicoding,
 -- }
}

registerotffeature(unicoding_specification)
registerafmfeature(unicoding_specification)
