if not modules then modules = { } end modules ['grph-epd'] = {
    version   = 1.001,
    comment   = "companion to grph-epd.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local variables = interfaces.variables
local settings_to_hash = utilities.parsers.settings_to_hash

-- todo: page, name, file, url

local codeinjections = backends.codeinjections

function figures.mergegoodies(optionlist)
    local options = settings_to_hash(optionlist)
    local all = options[variables.all] or options[variables.yes]
    if all or options[variables.reference] then
        codeinjections.mergereferences()
    end
    if all or options[variables.layer] then
        codeinjections.mergeviewerlayers()
    end
    if all or options[variables.bookmark] then
        codeinjections.mergebookmarks()
    end
end

interfaces.implement {
    name      = "figure_mergegoodies",
    actions   = figures.mergegoodies,
    arguments = "string"
}
