-- to be checked

local virtual = { "authoryear", "authoryears", "authornum", "num", "suffix" }
local authors = { "author", "editor", "publisher" }

return {
    name = "apa",
    version = "1.00",
    comment = "APA specification.",
    author = "Alan Braslau and Hans Hagen",
    copyright = "ConTeXt development team",
    categories = {
        article = {
            required = { { "author", "editor" }, "title"},
            optional = { "year", "type", "journal", "volume", "number", "pages", "url", "note", "doi" },
            virtual  = virtual,
            author   = authors,
        },
        magazine = {
            required = { { "author", "editor" }, "title", "journal", "year" },
            optional = { "volume", "number", "pages", "month", "day", "note", "url", "doi" },
            virtual  = virtual,
            author   = authors,
        },
        newspaper = {
            required = { { "author", "editor" }, "title", "journal", "year" },
            optional = { "volume", "number", "pages", "month", "day", "note", "url", "doi" },
            virtual  = virtual,
            author   = authors,
        },
        book = {
            virtual  = { "authoryear" },
            required = { { "author", "editor", "publisher" }, "title"},
            optional = { "year", "month", "day", "title", "type", "edition", "series", "volume", "number", "pages", "address", "publisher", "url", "note", "ISBN" },
            virtual  = virtual,
            author   = authors,
        },
        booklet = {
            required = { "title" },
            optional = { "author", "howpublished", "address", "month", "year", "note" },
            virtual  = virtual,
            author   = authors,
        },
        inbook = {
            required = { { "author", "editor", "publisher" }, "title", "chapter", "pages","year" },
            optional = { "volume", "number", "series", "type", "address", "edition", "month", "note", "ISBN" },
            virtual  = virtual,
            author   = authors,
        },
        incollection = {
            required = { "author", "title", "booktitle", "publisher", "year" },
            optional = { "editor", "volume", "number", "series", "type", "chapter", "pages", "address", "edition", "month", "note", "ISBN" },
            virtual  = virtual,
            author   = authors,
        },
        inproceedings = {
            required = { "author", "title", "booktitle", "year" },
            optional = { "editor", "volume", "number", "series", "pages", "address", "month", "organization", "publisher", "note", "ISBN" },
            virtual  = virtual,
            author   = authors,
        },
        conference =
            "inproceedings", -- Alan: does this work? Hans: I just made it work.
        manual = {
            required = { "title" },
            optional = { "author", "organization", "address", "edition", "month", "year", "note" },
            virtual  = virtual,
            author   = authors,
        },
        mastersthesis = {
            required = { "author", "title", "school", "year" },
            optional = { "type", "address", "month", "note" },
            virtual  = virtual,
            author   = authors,
        },
        misc = {
            required = { },
            optional = { "author", "title", "howpublished", "month", "year", "note" },
            virtual  = virtual,
            author   = authors,
        },
        -- Not sure yet how "periodical" is used... but "jabref" includes it as standard.
        -- strangely, "jabref" does not include "author" as required nor optional..
        periodical = {
            required = { "title", "year" },
            optional = { "author", "editor", "month", "note", "number", "organization", "series", "volume" },
            virtual  = virtual,
            author   = authors,
        },
        phdthesis = {
            required = { "author", "title", "school", "year" },
            optional = { "type", "address", "month", "note" },
            virtual  = virtual,
        },
        proceedings = {
            required = { "title", "year" },
            optional = { "editor", "volume", "number", "series", "address", "month", "organization", "publisher", "note", "pages", "ISBN" },
            virtual  = virtual,
            author   = authors,
        },
        techreport = {
            required = { "author", "title", "institution", "year" },
            optional = { "type", "number", "address", "month", "note" },
            virtual  = virtual,
            author   = authors,
        },
        patent = {
            required = { "nationality", "number", "year", "yearfiled" },
            optional = { "author", "title", "language", "assignee", "address", "type", "day", "dayfiled", "month", "monthfiled", "note", },
            virtual  = virtual,
            author   = authors,
        },
        unpublished = {
            required = { "author", "title", "note" },
            optional = { "month", "year" },
            virtual  = virtual,
            author   = authors,
        },
        literal = {
            required = { "key", "text", },
            optional = { },
        },
    },
}

