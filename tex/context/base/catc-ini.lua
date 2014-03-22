if not modules then modules = { } end modules ['catc-ini'] = {
    version   = 1.001,
    comment   = "companion to catc-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

catcodes         = catcodes         or { }
catcodes.numbers = catcodes.numbers or { }
catcodes.names   = catcodes.names   or { }

storage.register("catcodes/numbers", catcodes.numbers, "catcodes.numbers")
storage.register("catcodes/names",   catcodes.names,   "catcodes.names")

local numbers = catcodes.numbers
local names   = catcodes.names

-- this only happens at initime

function catcodes.register(name,number)
    numbers[name] = number
    local cnn = names[number]
    if cnn then
        cnn[#cnn+1] = name
    else
        names[number] = { name }
    end
    tex[name] = number -- downward compatible
end

-- this only happens at runtime

for k, v in next, numbers do
    tex[k] = v -- downward compatible
end

-- nasty

table.setmetatableindex(numbers,function(t,k) if type(k) == "number" then t[k] = k return k end end)
table.setmetatableindex(names,  function(t,k) if type(k) == "string" then t[k] = k return k end end)

commands.registercatcodetable = catcodes.register
--------.definecatcodetable   = characters.define   -- not yet defined
--------.setcharactercodes    = characters.setcodes -- not yet defined
