-- from the context garden

-- incorrectly packaged: metaducks, sudoku, aquamints

return {
    name = "mtx-install-imp-modules",
    version = "1.01",
    comment = "Third party modules",
    author = "Hans Hagen & others",
    copyright = "ConTeXt development team",
    lists = {
        ["pocketdiary"]       = { url = "modules", zips = { "PocketDiary-V2.zip", "Environment-for-collating-marks.zip", "Collection-of-calendars-based-on-PocketDiary-module.zip" } },
        ["collating-marks"]   = { url = "modules", zips = { "Environment-for-collating-marks.zip" } },
        ["construction-plan"] = { url = "modules", zips = { "t-construction-plan.zip" } },
        ["account"]           = { url = "modules", zips = { "t-account.zip" } },
        ["algorithmic"]       = { url = "modules", zips = { "t-algorithmic.zip" } },
        ["animation"]         = { url = "modules", zips = { "t-animation.zip" } },         -- probably obsolete
        ["annotation"]        = { url = "modules", zips = { "t-annotation.zip" } },
     -- ["aquamints"]         = { url = "modules", zips = { "aquamints.zip" } },           -- obsolete (fonts)
        ["bibmod-doc"]        = { url = "modules", zips = { "bibmod-doc.zip" } },
     -- ["bnf-0.3"]           = { url = "modules", zips = { "t-bnf-0.3.zip" } },
        ["bnf"]               = { url = "modules", zips = { "t-bnf.zip" } },
        ["chromato"]          = { url = "modules", zips = { "t-chromato.zip" } },
     -- ["cmscbf"]            = { url = "modules", zips = { "t-cmscbf.zip" } },            -- obsolete (fonts)
     -- ["cmttbf"]            = { url = "modules", zips = { "t-cmttbf.zip" } },            -- obsolete (fonts)
        ["crossref"]          = { url = "modules", zips = { "t-crossref.zip" } },
        ["cyrillicnumbers"]   = { url = "modules", zips = { "t-cyrillicnumbers.zip" } },   -- probably obsolete
    --  ["degrade"]           = { url = "modules", zips = { "t-degrade.zip" } },           -- obsolete, early version of grph-downsample
        ["enigma"]            = { url = "modules", zips = { "enigma.zip" } },
        ["fancybreak"]        = { url = "modules", zips = { "t-fancybreak.zip" } },
        ["filter"]            = { url = "modules", zips = { "t-filter.zip" } },
        ["french"]            = { url = "modules", zips = { "t-french.zip" } },            -- probably obsolete
        ["fullpage"]          = { url = "modules", zips = { "t-fullpage.zip" } },
        ["gantt"]             = { url = "modules", zips = { "t-gantt.zip" } },
    --  ["gfsdidot"]          = { url = "modules", zips = { "gfsdidot.zip" } },            -- obsolete (fonts)
        ["gm"]                = { url = "modules", zips = { "t-gm.zip" } },                -- probably obsolete
        ["gnuplot"]           = { url = "modules", zips = { "t-gnuplot.zip" } },
        ["greek"]             = { url = "modules", zips = { "t-greek.zip" } },
    --  ["grph-downsample"]   = { url = "modules", zips = { "grph-downsample.lua.zip" } }, -- doesn’t work with LMTX
        ["gs"]                = { url = "modules", zips = { "t-gs.zip" } },                -- probably obsolete
        ["high"]              = { url = "modules", zips = { "high.zip" } },
    --  ["handlecsv"]         = { url = "modules", zips = { "t-handlecsv.zip" } },         -- has top level files
        ["inifile"]           = { url = "modules", zips = { "t-inifile.zip" } },
        ["karnaugh"]          = { url = "modules", zips = { "karnaugh.zip" } },
        ["layout"]            = { url = "modules", zips = { "t-layout.zip" } },            -- probably obsolete
        ["letter"]            = { url = "modules", zips = { "t-letter.zip" } },
        ["letterspace"]       = { url = "modules", zips = { "t-letterspace.mkiv.zip" } },
        ["lettrine"]          = { url = "modules", zips = { "t-lettrine.zip" } },
        ["lua-widow-control"] = { url = "modules", zips = { "lua-widow-control.zip" } },   -- we wipe the non context stuff
        ["mathsets"]          = { url = "modules", zips = { "t-mathsets.zip" } },
    --  ["metaducks"]         = { url = "modules", zips = { "metaducks.zip" } },           -- has top level files
        ["pararef"]           = { url = "modules", zips = { "pararef.zip" } },
    --  ["presvoz"]           = { url = "modules", zips = { "presvoz.zip" } },             -- has top level files
        ["pret-c.lua"]        = { url = "modules", zips = { "pret-c.lua.zip" } },
        ["rst"]               = { url = "modules", zips = { "t-rst.zip" } },
        ["rsteps"]            = { url = "modules", zips = { "t-rsteps.zip" } },
        ["simplebib"]         = { url = "modules", zips = { "t-simplebib.zip" } },
    --  ["simplefonts"]       = { url = "modules", zips = { "t-simplefonts.zip" } },       -- obsolete (confuses users)
        ["simpleslides"]      = { url = "modules", zips = { "t-simpleslides.zip" } },
        ["squares"]           = { url = "modules", zips = { "squares.zip" } },
    --  ["stormfontsupport"]  = { url = "modules", zips = { "stormfontsupport.zip" } },    -- obsolete (fonts)
        ["sudoku"]            = { url = "modules", zips = { "sudoku.zip" } },
    --  ["taspresent"]        = { url = "modules", zips = { "t-taspresent.zip" } },        -- obsolete (early version of simpleslides)
    --  ["texshow"]           = { url = "modules", zips = { "u-texshow.zip" } },
        ["title"]             = { url = "modules", zips = { "t-title.zip" } },
        ["transliterator"]    = { url = "modules", zips = { "t-transliterator.zip" } },    -- probably obsolete
        ["typearea"]          = { url = "modules", zips = { "t-typearea.zip" } },          -- probably obsolete
    --  ["typescripts"]       = { url = "modules", zips = { "t-typescripts.zip" } },       -- obsolete (fonts)
    --  ["urwgaramond"]       = { url = "modules", zips = { "f-urwgaramond.zip" } },       -- obsolete (fonts)
    --  ["urwgothic"]         = { url = "modules", zips = { "f-urwgothic.zip" } },         -- obsolete (fonts)
        ["vim"]               = { url = "modules", zips = { "t-vim.zip" } },
        ["visualcounter"]     = { url = "modules", zips = { "t-visualcounter.zip" } },
    }
}
