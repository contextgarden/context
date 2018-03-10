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

-- I have some experimental code for including comments and fields but it's
-- unfinished and not included as it was just a proof of concept to get some idea
-- about what is needed and possible. But the placeholders are here already.

local codeinjections = backends.codeinjections

local function mergegoodies(optionlist)
    local options = settings_to_hash(optionlist)
    local all     = options[variables.all] or options[variables.yes]
    if all or options[variables.reference] then
        codeinjections.mergereferences()
    end
    if all or options[variables.comment] then
        codeinjections.mergecomments()
    end
    if all or options[variables.bookmark] then
        codeinjections.mergebookmarks()
    end
    if all or options[variables.field] then
        codeinjections.mergefields()
    end
    if all or options[variables.layer] then
        codeinjections.mergeviewerlayers()
    end
    codeinjections.flushmergelayer()
end

function figures.mergegoodies(optionlist)
    context.stepwise(function()
        -- we use stepwise because we might need to define symbols
        -- for stamps that have no default appearance
        mergegoodies(optionlist)
    end)
end

interfaces.implement {
    name      = "figure_mergegoodies",
    actions   = figures.mergegoodies,
    arguments = "string"
}
