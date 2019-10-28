if not modules then modules = { } end modules ['font-mis'] = {
    version   = 1.001,
    comment   = "companion to mtx-fonts",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

fonts          = fonts or { }

local helpers  = fonts.helpers or { }
fonts.helpers  = helpers

local handlers = fonts.handlers or { }
fonts.handlers = handlers

local otf      = handlers.otf or { }
handlers.otf   = otf

local readers  = otf.readers

if readers then

    otf.version = otf.version or 3.110
    otf.cache   = otf.cache   or containers.define("fonts", "otl", otf.version, true)

    function fonts.helpers.getfeatures(name,save)
        local filename = resolvers.findfile(name) or ""
        if filename ~= "" then
         -- local name      = file.removesuffix(file.basename(filename))
         -- local cleanname = containers.cleanname(name)
         -- local data      = containers.read(otf.cache,cleanname)
         -- if data then
         --     readers.unpack(data)
         -- else
         --     data = readers.loadfont(filename) -- we can do a more minimal load
         --  -- if data and save then
         --  --     -- keep this in sync with font-otl
         --  --     readers.compact(data)
         --  --     readers.rehash(data,"unicodes")
         --  --     readers.addunicodetable(data)
         --  --     readers.extend(data)
         --  --     readers.pack(data)
         --  --     -- till here
         --  --     containers.write(otf.cache,cleanname,data)
         --  -- end
         -- end
         -- if not data then
         --     data = readers.loadfont(filename) -- we can do a more minimal load
         -- end
         -- if data then
         --     readers.unpack(data)
         -- end
            local data = otf.load(filename)
            local resources = data and data.resources
            if resources then
                return data.resources.features, data.resources.foundtables, data
            end
        end
    end

else

    function fonts.helpers.getfeatures(name)
        -- not supported
    end

end
