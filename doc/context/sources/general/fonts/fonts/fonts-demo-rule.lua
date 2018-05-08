local startactualtext = backends.codeinjections.startunicodetoactualtext
local stopactualtext  = backends.codeinjections.stopunicodetoactualtext

return function(specification)
    local features = specification.features.normal
    local name     = features.original or "dejavu-serif"
    local option   = features.option      -- we only support "line"
    local size     = specification.size   -- always set
    local detail   = specification.detail -- e.g. default
    if detail then
        name = name .. "*" .. detail
    end
    local f, id = fonts.constructors.readanddefine(name,size)
    if f then
        f.properties.name = specification.name
        f.properties.virtualized = true
        f.fonts = {
            { id = id },
        }
        for s in string.gmatch("aeuioy",".") do
            local n = utf.byte(s)
            local c = f.characters[n]
            if c then
                local w = c.width  or 0
                local h = c.height or 0
                local d = c.depth  or 0
                if option == "line" then
                    f.characters[n].commands = {
                        { "special", "pdf:direct:" .. startactualtext(n) },
                        { "rule", option == "line" and size/10, w },
                        { "special", "pdf:direct:" .. stopactualtext() },
                    }
                else
                    f.characters[n].commands = {
                        { "special", "pdf:direct:" .. startactualtext(n) },
                        { "down", d },
                        { "rule", h + d, w },
                        { "special", "pdf:direct:" .. stopactualtext() },
                    }
                end
            else
                -- probably a real bad font
            end
        end
    end
    return f
end
