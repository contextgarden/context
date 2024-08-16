return {
    name = "compactors-preset",
    version = "1.00",
    comment = "Definitions that complement pdf embedding.",
    author = "Hans Hagen",
    copyright = "ConTeXt development team",
    compactors = {
        ["default"] = {
            strip = {
                marked    = "page",  -- check page stream if stripping is needed
                pieceinfo = true,
            },
            cleanup = {
                procset   = true,
                pieceinfo = true,
            }
        },
        ["yes"] = {
            merge = {
                lmtx      = true,
            },
            strip = {
                marked    = "force", -- always strip, no checking -- always strip
            },
            cleanup = {
                procset   = true,
                pieceinfo = true,
            }
        },
        ["merge"] = {
            merge = {
                type0     = true,
                truetype  = true,
                type1     = true,
             -- type3     = true,
                lmtx      = true,
            },
            strip = {
                marked    = "force", -- always strip, no checking
            },
            cleanup = {
                procset   = true,
                pieceinfo = true,
            }
        },
        ["demo"] = {
            merge = {
                type0     = true,
                truetype  = true,
                type1     = true,
             -- type3     = true,
                lmtx      = true,
            },
            strip = {
                marked    = "force", -- always strip, no checking
                group     = true,
-- cm        = true,
            },
            cleanup = {
                procset   = true,
                pieceinfo = true,
            }
        },
        ["tikz"] = {
            merge = {
                type0     = true,
                truetype  = true,
                type1     = true,
                lmtx      = true,
            },
            strip = {
                marked     = "force",
                pollution  = true, -- e.g. in tikz
                identitycm = true, -- 1 0 0 1 0 0
            },
            cleanup = {
                procset   = true,
                pieceinfo = true,
            }
        },
     -- ["dontuse"] = {
     --     name = "preset:dontuse",
     --     identify = "all",
     --     embed = {
     --        type0    = true,
     --        truetype = true,
     --        type1    = true,
     --     },
     --     merge = {
     --         type0    = true, -- check if a..z A..Z 0..9
     --         truetype = true,
     --         type1    = true,
     --         LMTX     = true,
     --     },
     --     strip = {
     --         group     = true,
     --         extgstate = true,
     --         marked    = true,
     --     },
     --     cleanup = {
     --         pieceinfo = true,
     --         procset   = true,
     --         cidset    = true,
     --     },
     --     reduce = {
     --         color = true,
     --         rgb   = true,
     --         cmyk  = true,
     --     },
     --     convert = {
     --         rgb  = true,
     --         cmyk = true,
     --         cmyk = {
     --             { 100, 100, 55, 0, 57, 0, 22, 40.8 } -- factor, c, m, y, k, r, g, b
     --         }
     --     },
     --     recolor = {
     --         gray = { 1, 0, 0 },
     --     },
     --     add = {
     --         cidset = true, -- when missing or even fix
     --     },
     --     presets = {
     --      -- matte = { 127, 127, 127, 127 }
     --     }
     -- },
    },
}
