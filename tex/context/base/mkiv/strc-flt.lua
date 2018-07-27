if not modules then modules = { } end modules ['strc-flt'] = {
    version   = 1.001,
    comment   = "companion to strc-flt.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- nothing

local sequencers      = utilities.sequencers
local appendaction    = sequencers.appendaction
local enableaction    = sequencers.enableaction
local disableaction   = sequencers.disableaction

local texgetdimen     = tex.getdimen

local trace           = trackers.register("structure.sidefloats.pageflush")
local report          = logs.reporter("structure","floats")

local forcepageflush  = builders.vspacing.forcepageflush

function builders.checksidefloat(mode,indented)
    local s = texgetdimen("d_page_sides_vsize")
    if s > 0 then
        if trace then
            report("force flushing page state, height %p",s)
        end
        forcepageflush()
    end
    return indented
end

appendaction ("newgraf","system","builders.checksidefloat")
disableaction("newgraf","builders.checksidefloat")

interfaces.implement {
    name     = "enablesidefloatchecker",
    onlyonce = true,
    actions  = function()
        enableaction("newgraf","builders.checksidefloat")
    end,
}
