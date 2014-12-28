if not modules then modules = { } end modules ['luat-iop'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- local input_mode  directives.register("system.inputmode", function(v) input_mode  = v end)
-- local output_mode directives.register("system.outputmode",function(v) output_mode = v end)

-- limiters = {
--     input = {
--         paranoid = {
--             { "permit", "^[^/]+$"    },
--             { "permit", "^./"        },
--             { "forbid", ".."         },
--             { "tree"  , "TEXMF"      },
--             { "tree"  , "MPINPUTS"   },
--             { "tree"  , "TEXINPUTS"  },
--             { "forbid", "^/.."       },
--             { "forbid", "^[a-c]:/.." },
--         },
--     },
--     output = {
--         paranoid = {
--             { "permit", "^[^/]+$"    },
--             { "permit", "^./"        },
--         },
--     }
-- }

--         sandbox.registerroot(".","write") -- always ok

local cleanedpathlist = resolvers.cleanedpathlist
local registerroot    = sandbox.registerroot

sandbox.initializer(function()
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
end)
