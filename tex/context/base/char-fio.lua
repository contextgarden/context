if not modules then modules = { } end modules ['char-fio'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- --

local sequencers      = utilities.sequencers
local appendaction    = sequencers.appendaction
local enableaction    = sequencers.enableaction
local disableaction   = sequencers.disableaction

local utffilters      = characters.filters.utf

local textfileactions = resolvers.openers.helpers.textfileactions
local textlineactions = resolvers.openers.helpers.textlineactions

appendaction (textfileactions,"system","characters.filters.utf.reorder")
disableaction(textfileactions,         "characters.filters.utf.reorder")

appendaction (textlineactions,"system","characters.filters.utf.reorder")
disableaction(textlineactions,         "characters.filters.utf.reorder")

appendaction (textfileactions,"system","characters.filters.utf.collapse")
disableaction(textfileactions,         "characters.filters.utf.collapse")

appendaction (textfileactions,"system","characters.filters.utf.decompose")
disableaction(textfileactions,         "characters.filters.utf.decompose")

function characters.filters.utf.enable()
    enableaction(textfileactions,"characters.filters.utf.reorder")
    enableaction(textfileactions,"characters.filters.utf.collapse")
    enableaction(textfileactions,"characters.filters.utf.decompose")
end

local function configure(what,v)
    if not v then
        disableaction(textfileactions,what)
        disableaction(textlineactions,what)
    elseif v == "line" then
        disableaction(textfileactions,what)
        enableaction (textlineactions,what)
    else -- true or text
        enableaction (textfileactions,what)
        disableaction(textlineactions,what)
    end
end

directives.register("filters.utf.reorder",   function(v) configure("characters.filters.utf.reorder",  v) end)
directives.register("filters.utf.collapse",  function(v) configure("characters.filters.utf.collapse", v) end)
directives.register("filters.utf.decompose", function(v) configure("characters.filters.utf.decompose",v) end)

utffilters.setskippable { "mkiv", "mkvi", "mkix", "mkxi" }
