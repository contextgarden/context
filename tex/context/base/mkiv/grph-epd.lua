if not modules then modules = { } end modules ['grph-epd'] = {
    version   = 1.001,
    comment   = "companion to grph-epd.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local variables = interfaces.variables
local settings_to_hash = utilities.parsers.settings_to_hash
local codeinjections = backends.pdf.codeinjections

local trace  = false  trackers.register("figures.merging", function(v) trace = v end)

local report = logs.reporter("backend","merging")

local function mergegoodies(optionlist)
    local options = settings_to_hash(optionlist)
    local yes     = options[variables.yes]
    local all     = options[variables.all]
    if next(options) then
        report("% t",table.sortedkeys(options))
    end
    if all or yes or options[variables.reference] then
        codeinjections.mergereferences()
    end
    if all or options[variables.comment] then
        codeinjections.mergecomments()
    end
    if all or yes or options[variables.bookmark] then
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
    -- todo: we can use runtoks instead
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
