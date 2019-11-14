if not modules then modules = { } end modules ['char-fio'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- % directives="filters.utf.reorder=false"


local next = next

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

appendaction (textfileactions,"system","characters.filters.utf.collapse")   -- not per line
disableaction(textfileactions,         "characters.filters.utf.collapse")

appendaction (textfileactions,"system","characters.filters.utf.decompose")  -- not per line
disableaction(textfileactions,         "characters.filters.utf.decompose")

local report    = logs.reporter("unicode filter")
local reporting = "no"

-- this is messy as for performance reasons i don't want this to happen
-- per line by default

local enforced = {
    ["characters.filters.utf.collapse"]  = true,
    ["characters.filters.utf.decompose"] = true,
    ["characters.filters.utf.reorder"]   = false,
}

function utffilters.enable()
    -- only used one time (normally)
    for k, v in next, enforced do
        if v then
            if reporting == "yes" then
                report("%a enabled",k)
            end
            enableaction(textfileactions,k)
        else
            if reporting == "yes" then
                report("%a not enabled",k)
            end
        end
    end
    reporting = "never"
end

local function configure(what,v)
    if v == "" then
        report("%a unset",what)
    elseif v == "line" then
        disableaction(textfileactions,what)
        enableaction (textlineactions,what)
    elseif not toboolean(v) then
        if reporting ~= "never" then
            report("%a disabled",what)
            reporting = "yes"
        end
        enforced[what] = false
        disableaction(textfileactions,what)
        disableaction(textlineactions,what)
    else -- true or text
        enableaction (textfileactions,what)
        disableaction(textlineactions,what)
    end
end

-- first line:
--
-- % directives="filters.utf.collapse=true"

directives.register("filters.utf.reorder",   function(v) configure("characters.filters.utf.reorder",  v) end)
directives.register("filters.utf.collapse",  function(v) configure("characters.filters.utf.collapse", v) end)
directives.register("filters.utf.decompose", function(v) configure("characters.filters.utf.decompose",v) end)

utffilters.setskippable {
    "mkiv", "mkvi",
    "mkix", "mkxi",
    "mkxl", "mklx",
}

interfaces.implement {
    name     = "enableutf",
    onlyonce = true,
    actions  = utffilters.enable
}
