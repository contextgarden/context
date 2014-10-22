-- to be checked

return {
    name = "apa",
    version = "1.00",
    comment = "APA specification.",
    author = "Alan Braslau and Hans Hagen",
    copyright = "ConTeXt development team",
    categories = {
        article = {
            required = { {"author", "editor"}, "title", "journal", "year" },
            optional = { "volume", "number", "pages", "note", "type", "url", "doi" },
        },
        magazine = {
            required = { {"author", "editor",}, "title", "journal", "year" },
            optional = { "volume", "number", "pages", "month", "day", "note", "url", "doi" },
        },
        newspaper = {
            required = { {"author", "editor",}, "title", "journal", "year" },
            optional = { "volume", "number", "pages", "month", "day", "note", "url", "doi" },
        },
        book = {
            required = { { "author", "editor" }, "title", "publisher", "year" },
            optional = { { "volume", "number" }, "series", "address", "edition", "month", "note", "pages", "ISBN" },
        },
        booklet = {
            required = { "title" },
            optional = { "author", "howpublished", "address", "month", "year", "note" },
        },
        inbook = {
            required = { { "author", "editor" }, "title", { "chapter", "pages" }, "publisher","year" },
            optional = { { "volume", "number" }, "series", "type", "address", "edition", "month", "note", "ISBN" },
        },
        incollection = {
            required = { "author", "title", "booktitle", "publisher", "year" },
            optional = { "editor", { "volume", "number" }, "series", "type", "chapter", "pages", "address", "edition", "month", "note", "ISBN" },
        },
        inproceedings = {
            required = { "author", "title", "booktitle", "year" },
            optional = { "editor", { "volume", "number" }, "series", "pages", "address", "month", "organization", "publisher", "note", "ISBN" },
        },
        -- does this work:
        conference = inproceedings,
        manual = {
            required = { "title" },
            optional = { "author", "organization", "address", "edition", "month", "year", "note" },
        },
        mastersthesis = {
            required = { "author", "title", "school", "year" },
            optional = { "type", "address", "month", "note" },
        },
        misc = {
            required = { },
            optional = { "author", "title", "howpublished", "month", "year", "note" },
        },
        -- Not sure yet how "periodical" is used... but "jabref" includes it as standard.
        -- strangely, "jabref" does not include "author" as required nor optional..
        periodical = {
            required = { "title", "year" },
            optional = { "author", "editor", "month", "note", "number", "organization", "series", "volume" },
        },
        phdthesis = {
            required = { "author", "title", "school", "year" },
            optional = { "type", "address", "month", "note" },
        },
        proceedings = {
            required = { "title", "year" },
            optional = { "editor", { "volume", "number" }, "series", "address", "month", "organization", "publisher", "note", "pages", "ISBN" },
        },
        techreport = {
            required = { "author", "title", "institution", "year" },
            optional = { "type", "number", "address", "month", "note" },
        },
        patent = {
            required = { "nationality", "number", "year", "yearfiled" },
            optional = { "author", "title", "language", "assignee", "address", "type", "day", "dayfiled", "month", "monthfiled", "note", },
        },
        unpublished = {
            required = { "author", "title", "note" },
            optional = { "month", "year" },
        },
        literal = {
            required = { "key", "text", },
            optional = { },
        },
    },
}

