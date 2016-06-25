if not modules then modules = { } end modules ['luatex-fonts-demo-vf-4'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

return function(specification)
    local t = { }
    for k, v in pairs(specification.features.normal) do
        local n = tonumber(k)
        if n then
            t[n] = v
        end
    end
    for k, v in ipairs(t) do
        local name, rest = string.match(v,"^(.-){(.*)}$")
        if rest then
            t[k] = { name = name, list = { } }
            for s in string.gmatch(rest,"([^%+]+)") do
                local b, e = string.match(s,"^(.-)%-(.*)$")
                if b and e then
                    b = tonumber(b)
                    e = tonumber(e)
                else
                    b = tonumber(s)
                    e = b
                end
                if b and e then
                    table.insert(t[k].list,{ b = b, e = e })
                end
            end
        else
            t[k] = { name = v }
        end
    end
    local ids = { }
    for k, v in ipairs(t) do
        local f, id
        if tonumber(v.name) then
            id = tonumber(v.name)
            f = fonts.hashes.identifiers[id]
        else
            f, id = fonts.constructors.readanddefine(v.name,specification.size)
        end
        v.f = f
        ids[k] = { id = id }
    end
    local one = t[1].f
    if one then
        one.properties.name = specification.name
        one.properties.virtualized = true
        one.fonts = ids
        local chr = one.characters
        for n, v in ipairs(t) do
            if n == 1 then
                -- use font 1 as base
            elseif v.list and #v.list > 0 then
                local chrs = v.f.characters
                for k, v in ipairs(v.list) do
                    for u=v.b,v.e do
                        local c = chrs[u]
                        if c then
                            c.commands = {
                                { 'slot', n, u },
                            }
                            chr[u] = c
                        end
                    end
                end
            else
                for u, c in ipairs(v.f.characters) do
                    c.commands = {
                        { 'slot', n, u },
                    }
                    chr[u] = c
                end
            end
        end
    end
    return one
end
