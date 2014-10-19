-- to be checked

return {
    name = "aps",
    version = "1.00",
    comment = "APA specification.",
    author = "Alan Braslau and Hans Hagen",
    copyright = "ConTeXt development team",
    categories = {
        article = {
            required = { "author", "title", "journal", "year" },
            optional = { "volume", "number", "pages", "month", "note" },
        },
        book = {
            required = { { "author", "editor" }, "title", "publisher", "year" },
            optional = { { "volume", "number" }, "series", "address", "edition", "month","note" },
        },
        booklet = {
            required = { "title" },
            optional = { "author", "howpublished", "address", "month", "year", "note" },
        },
        inbook = {
            required = { { "author", "editor" }, "title", { "chapter", "pages" }, "publisher","year" },
            optional = { { "volume", "number" }, "series", "type", "address", "edition", "month", "note" },
        },
        incollection = {
            required = { "author", "title", "booktitle", "publisher", "year" },
            optional = { "editor", { "volume", "number" }, "series", "type", "chapter", "pages", "address", "edition", "month", "note" },
        },
        inproceedings = {
            required = { "author", "title", "booktitle", "year" },
            optional = { "editor", { "volume", "number" }, "series", "pages", "address", "month","organization", "publisher", "note" },
        },
        manual = {
            required = { "title" },
            optional = { "author", "organization", "address", "edition", "month", "year", "note" },
        },
        mastersthesis = {
            required = { "author", "title", "school", "year" },
            optional = { "type", "address", "month", "note" },
        },
        misc = {
            required = { "author", "title", "howpublished", "month", "year", "note" },
            optional = { "author", "title", "howpublished", "month", "year", "note" },
        },
        phdthesis = {
            required = { "author", "title", "school", "year" },
            optional = { "type", "address", "month", "note" },
        },
        proceedings = {
            required = { "title", "year" },
            optional = { "editor", { "volume", "number" }, "series", "address", "month", "organization", "publisher", "note" },
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
    },
}

