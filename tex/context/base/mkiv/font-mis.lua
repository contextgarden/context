if not modules then modules = { } end modules ['font-mis'] = {
    version   = 1.001,
    comment   = "companion to mtx-fonts",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

fonts          = fonts or { }

fonts.helpers  = fonts.helpers or { }
local helpers  = fonts.helpers

fonts.handlers = fonts.handlers or { }
local handlers = fonts.handlers

handlers.otf   = handlers.otf or { }
local otf      = handlers.otf

local readers  = otf.readers

if readers then

    otf.version = otf.version or 3.104
    otf.cache   = otf.cache   or containers.define("fonts", "otl", otf.version, true)

    function fonts.helpers.getfeatures(name,save)
        local filename = resolvers.findfile(name) or ""
        if filename ~= "" then
--             local name      = file.removesuffix(file.basename(filename))
--             local cleanname = containers.cleanname(name)
--             local data      = containers.read(otf.cache,cleanname)
--             if data then
--                 readers.unpack(data)
--             else
--                 data = readers.loadfont(filename) -- we can do a more minimal load
--              -- if data and save then
--              --     -- keep this in sync with font-otl
--              --     readers.compact(data)
--              --     readers.rehash(data,"unicodes")
--              --     readers.addunicodetable(data)
--              --     readers.extend(data)
--              --     readers.pack(data)
--              --     -- till here
--              --     containers.write(otf.cache,cleanname,data)
--              -- end
--             end
--             if not data then
--                 data = readers.loadfont(filename) -- we can do a more minimal load
--             end
--             if data then
--                 readers.unpack(data)
--             end
local data = otf.load(filename)
            return data and data.resources and data.resources.features
        end
    end

else

    function fonts.helpers.getfeatures(name)
        -- not supported
    end

end
