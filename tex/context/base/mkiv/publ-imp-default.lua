-- For the moment I put this here as example. When writing the publication modules we
-- explored several approached: pure tex, pure lua, a mix with xml, etc. In the end
-- each has advantages and drawbacks so we ended up with readable tex plus helpers in
-- lua. Anyway here is a lua variant of a setup ... it doesn't look nicer. An alternative
-- can be to build a table with characters but then we need to pass left, right and
-- other separators so again no real gain.

-- function publications.maybe.default.journal(currentdataset,currenttag)
--     if publications.okay(currentdataset,currenttag,"journal") then
--         context.btxspace()
--         context.startbtxstyle("italic")
--             commands.btxflush(currentdataset,currenttag,"expandedjournal -> journal")
--         context.stopbtxstyle()
--         if publications.okay(currentdataset,currenttag,"volume") then
--             context.btxspace()
--             commands.btxflush(currentdataset,currenttag,"volume")
--             if publications.okay(currentdataset,currenttag,"number") then
--                 context.ignorespaces()
--                 context.btxleftparenthesis()
--                 commands.btxflush(currentdataset,currenttag,"number")
--                 context.btxrightparenthesis()
--             end
--         elseif publications.okay(currentdataset,currenttag,"number") then
--             context.btxlabeltext("default:number")
--             context.btxspace()
--             commands.btxflush(currentdataset,currenttag,"number")
--         end
--         if publications.okay(currentdataset,currenttag,"pages") then
--             context.btxcomma()
--             commands.btxflush(currentdataset,currenttag,"pages")
--         end
--         context.btxcomma()
--     end
-- end

return {
    --
    -- metadata
    --
    name      = "default",
    version   = "1.00",
    comment   = "DEFAULT specification",
    author    = "Alan Braslau and Hans Hagen",
    copyright = "ConTeXt development team",
    --
    -- derived (combinations of) fields (all share the same default set)
    --
    virtual = {
        "authoryear",
        "authoryears",
        "authornum",
        "num",
        "suffix",
    },
    --
    -- special datatypes
    --
    types = {
        author   = "author",     -- interpreted as name(s)
        editor   = "author",     -- interpreted as name(s)
        page     = "pagenumber", -- number or range: f--t -- maybe just range
        pages    = "pagenumber", -- number or range: f--t -- maybe just range
        volume   = "range",      -- number or range: f--t
        number   = "range",      -- number or range: f--t
        keywords = "keyword",    -- comma|-|separated list
    },
    --
    -- categories with their specific fields
    --
    categories = {
        --
        -- the following fields are for documentation and testing purposes
        --
        ["demo-a"] = {
            sets     = {
                author  = { "author", "institution", "organization" },
            },
            required = { "author", "title", "year" },
            optional = { "subtitle" },
        },
        ["demo-b"] = {
            sets     = {
                authors = { "author", "institution", "organization" },
            },
            required = { "authors", "title", "year" },
            optional = { "subtitle" },
        },
        --
        -- we only provide article and book (maybe a few more later) and we keep it
        -- real simple. See the apa and aps definitions for more extensive examples
        --
        article = {
            sets = {
                author = { "author", "editor" },
            },
            required = {
                "author", -- a set
                "year",
            },
            optional = {
                "title",
                "keywords",
                "journal", "volume", "number", "pages",
                "note",
            },
        },
        book = {
            sets = {
                author     = { "author", "editor", },
                editionset = { "edition", "volume", "number" },
            },
            required = {
                "title",
                "year",
            },
            optional = {
                "author", -- a set
                "subtitle",
                "keywords",
                "publisher", "address",
                "editionset",
                "note",
            },
        },
    },
}
