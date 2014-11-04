-- category = {
--     sets     = {
--         authors = { "author", "editor" },
--     },
--     required = { "authors", "title" },
--     optional = { "year", "journal", "editor", "volume", "number", "pages" },
--     virtual  = { "authoryear", "authoryears", "authornum", "num", "suffix" },
-- }

-- category = {
--     sets     = {
--         author = { "author", "editor" },
--     },
--     required = { "author", "title" },
--     optional = { "year", "journal", "editor", "volume", "number", "pages" },
--     virtual  = { "authoryear", "authoryears", "authornum", "num", "suffix" },
-- }

return {
    name = "apa",
    version = "1.00",
    comment = "APA specification.",
    author = "Alan Braslau and Hans Hagen",
    copyright = "ConTeXt development team",
    virtual = {
        -- all share the same default set
        "authoryear", "authoryears", "authornum", "num", "suffix",
    },
    categories = {
        article = {
            sets     = {
                author = { "author", "editor" },
            },
            required = { "author", "title" },
            optional = { "year", "type", "journal", "volume", "number", "pages", "url", "note", "doi" },
        },
        magazine = {
            sets     = {
                author = { "author", "editor" },
            },
            required = { "author", "editor", "title", "journal", "year" },
            optional = { "volume", "number", "pages", "month", "day", "note", "url", "doi" },
        },
        newspaper = {
            sets     = {
                author = { "author", "editor" },
            },
            required = { "author", "title", "journal", "year" },
            optional = { "volume", "number", "pages", "month", "day", "note", "url", "doi" },
        },
        book = {
            sets     = {
                author = { "author", "editor", "publisher" },
            },
            virtual  = { "authoryear" },
            required = { "author", "title" },
            optional = { "year", "month", "day", "title", "type", "edition", "series", "volume", "number", "pages", "address", "publisher", "url", "note", "ISBN" },
        },
        booklet = {
            required = { "title" },
            optional = { "author", "howpublished", "address", "month", "year", "note" },
        },
        inbook = {
            sets     = {
                author = { "author", "editor", "publisher" },
            },
            required = { "author", "title", "chapter", "pages", "year" },
            optional = { "volume", "number", "series", "type", "address", "edition", "month", "note", "ISBN" },
            author   = { "author", "editor", "publisher" },
        },
        incollection = {
            sets     = {
                author = { "author", "editor", "publisher" },
            },
            required = { "author", "title", "booktitle", "publisher", "year" },
            optional = { "editor", "volume", "number", "series", "type", "chapter", "pages", "address", "edition", "month", "note", "ISBN" },
        },
        inproceedings = {
            sets     = {
                author = { "author", "editor", "publisher" },
            },
            required = { "author", "title", "booktitle", "year" },
            optional = { "editor", "volume", "number", "series", "pages", "address", "month", "organization", "publisher", "note", "ISBN" },
        },
        conference =
            "inproceedings", -- Alan: does this work? Hans: I just made it work.
        manual = {
            required = { "title" },
            optional = { "author", "organization", "address", "edition", "month", "year", "note" },
        },
        mastersthesis = {
            required = { "author", "title", "school", "year" },
            optional = { "type", "address", "month", "note" },
        },
        phdthesis = {
            required = { "author", "title", "school", "year" },
            optional = { "type", "address", "month", "note" },
        },
        thesis = {
            required = { "author", "title", "school", "year", "type" },
            optional = { "address", "month", "note" },
        },
        misc = {
            required = { },
            optional = { "author", "title", "howpublished", "month", "year", "note" },
        },
        -- Not sure yet how "periodical" is used... but "jabref" includes it as standard.
        -- strangely, "jabref" does not include "author" as required nor optional..
        periodical = {
            sets     = {
                author = { "editor", "publisher" },
            },
            required = { "title", "year" },
            optional = { "author", "editor", "month", "note", "number", "organization", "series", "volume" },
        },
        proceedings = {
            required = { "title", "year" },
            optional = { "editor", "volume", "number", "series", "address", "month", "organization", "publisher", "note", "pages", "ISBN" },
        },
        techreport = {
            required = { "author", "title", "institution", "year" },
            optional = { "type", "number", "address", "month", "note" },
        },
        other = {
            required = { "author", "title", "year" },
            optional = { "note", "doi" },
        },
        patent = {
            required = { "nationality", "number", "year", "yearfiled" },
            optional = { "author", "title", "language", "assignee", "address", "type", "day", "dayfiled", "month", "monthfiled", "note", },
        },
        electronic = {
            required = { "title" },
            optional = { "address", "author", "howpublished", "month", "note", "organization", "year", "url", "doi", "type" },
        },
        -- check this!
        standard = {
            sets     = {
                author = { "author", "institution", "organization" },
            },
            required = { "author", "title", "year", "note", "url" },
            optional = { "doi", },
        },
        unpublished = {
            required = { "author", "title", "note" },
            optional = { "month", "year" },
        },
        literal = {
            required = { "key", "text", },
            optional = { },
            virtual  = false,
        },
        --
        ["demo-a"] = {
            sets     = {
                author  = { "author", "institution", "organization" },
            },
            required = { "author", "title", "year", "note", "url" },
            optional = { "doi", },
        },
        ["demo-b"] = {
            sets     = {
                authors = { "author", "institution", "organization" },
            },
            required = { "authors", "title", "year", "note", "url" },
            optional = { "doi", },
        },
    },
}

