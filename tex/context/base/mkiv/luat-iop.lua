if not modules then modules = { } end modules ['luat-iop'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local cleanedpathlist = resolvers.cleanedpathlist
local registerroot    = sandbox.registerroot

sandbox.initializer {
    category = "files",
    action   = function()
        local function register(str,mode)
            local trees = cleanedpathlist(str)
            for i=1,#trees do
                registerroot(trees[i],mode)
            end
        end
        register("TEXMF","read")
        register("TEXINPUTS","read")
        register("MPINPUTS","read")
     -- register("TEXMFCACHE","write")
        registerroot(".","write")
    end
}
