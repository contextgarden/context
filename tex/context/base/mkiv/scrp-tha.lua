if not modules then modules = { } end modules ['scrp-tha'] = {
    version   = 1.001,
    comment   = "companion to scrp-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module needs dictionary files that looks as follows. At some point
-- we will add these files to the distribution.
--
-- word-th.lua:
--
-- return {
--     comment   = "The data is taken from http://thailinux.gits.net.th/websvn/wsvn/software.swath by Phaisarn Charoenpornsawat and Theppitak Karoonboonyanan.",
--     copyright = "gnu general public license",
--     language  = "th",
--     compiling = "mtxrun --script patterns --words --update --compress word-th.lua",
--     timestamp = "0000-00-00 00:00:00",
--     version   = "1.00",
--     lists     = {
--         { filename = "tdict-city.txt" },
--         { filename = "tdict-collection.txt" },
--         { filename = "tdict-common.txt" },
--         { filename = "tdict-country.txt" },
--         { filename = "tdict-district.txt" },
--         { filename = "tdict-geo.txt" },
--         { filename = "tdict-history.txt" },
--         { filename = "tdict-ict.txt" },
--         { filename = "tdict-lang-ethnic.txt" },
--         { filename = "tdict-proper.txt" },
--         { filename = "tdict-science.txt" },
--         { filename = "tdict-spell.txt" },
--         { filename = "tdict-std-compound.txt" },
--         { filename = "tdict-std.txt" },
--     },
-- }

-- Currently there is nothing additional special here, first we need a
-- ConTeXt user who uses it. It's a starting point.

local splitters = scripts.splitters

scripts.installmethod {
    name        = "thai",
    splitter    = splitters.insertafter,
    initializer = splitters.load,
    files       = {
     -- "scrp-imp-word-thai.lua",
        "word-th.lua",
    },
    datasets    = {
        default = {
            inter_word_stretch_factor = 0.25, -- of quad
        },
    },
}
