local specification = {
    --
    -- metadata
    --
    name      = "apa",
    version   = "1.00",
    comment   = "APA specification",
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
        --
        -- list of fields that are interpreted as names: "NAME [and NAME]" where
        -- NAME is one of the following:
        --
        -- First vons Last
        -- vons Last, First
        -- vons Last, Jrs, First
        -- Vons, Last, Jrs, First
        --
        author      = "author", -- interpreted as name(s)
        withauthor  = "author",
        editor      = "author",
        translator  = "author",
        artist      = "author",
        composer    = "author",
        producer    = "author",
        director    = "author",
        doi         = "url",        -- an external link
        url         = "url",
        page        = "pagenumber", -- number or range: f--t
        pages       = "pagenumber",
        volume      = "range",
        number      = "range",
        keywords    = "keyword",    -- comma|-|separated list
        year        = "number",
    },
    --
    -- categories with their specific fields
    --
    categories = {
        --
        -- categories are added below
        --
    },
}

local generic = {
    --
    -- A set returns the first field (in order of position below) that is found
    -- present in an entry. A set having the same name as a field conditionally
    -- allows the substitution of an alternate field.
    --
    -- note that anything can get assigned a doi or be available online.
    doi        = { "doi", "url" },
    editionset = { "edition", "volume", "number", "pages" },
}

-- Definition of recognized categories and the fields that they contain.
-- Required fields should be present; optional fields may also be rendered;
-- all other fields will be ignored.

-- Sets contain either/or in order of precedence.
--
-- For a category *not* defined here yet present in the dataset, *all* fields
-- are taken as optional. This allows for flexibility in the addition of new
-- categories.

local categories = specification.categories

-- an article from a journal

categories.article = {
    sets = {
        author = { "author", "organization", "editor", "title" },
        doi    = generic.doi,
    },
    required = {
        "author", -- a set
    },
    optional = {
        "withauthor", "translator",
        "year",
        "subtitle", "type", "file",
        "journal", "volume", "number", "pages",
        "doi", "note",
     -- APA ignores this: 
     -- 
     -- "month",
     -- 
     -- fields defined in jabref but presently ignored:
     -- 
     -- "issn",
    },
}

-- an article from a magazine

categories.magazine = {
    sets = categories.article.sets,
    required = {
        "author",
        "year",
        "journal",
    },
    optional = {
        "withauthor", "translator",
        "subtitle", "type", "file",
        "number",
        "month", "day",
        "doi", "note",
    },
}

categories.newspaper = categories.magazine

-- (from jabref) to be identified and setup ...

categories.periodical = {
    sets = {
        author = { "editor", "publisher", "organization", },
        doi    = generic.doi,
    },
    required = {
        "title",
        "year",
    },
    optional = {
        "author", "withauthor", "translator",
        "subtitle", "file",
        "series", "volume", "number", "month",
        "organization",
        "doi", "note",
    },
}

-- (from jabref) to be identified and setup ...

categories.standard = {
    sets = {
        author = { "author", "institution", "organization" },
        doi    = generic.doi,
    },
    required = {
        "author",
        "year",
        "title", "subtitle",
        "doi", "note",
    },
    optional = {
        "withauthor", "translator",
    },
}

-- a book with an explicit publisher.

categories.book = {
    sets = {
        author     = { "author", "editor", "publisher", "title" },
        ineditor   = { "editor" },
        editionset = generic.editionset,
        doi        = generic.doi,
    },
    required = { "author" },
    optional = {
        "ineditor",
        "withauthor", "translator",
        "year", "month", "day",
        "subtitle", "type",  "file",
        "editionset", "series",
        "address",
        "doi", "note",
        "abstract",
    },
}

-- a part of a book, which may be a chapter (or section or whatever) and/or a range of pages.

categories.inbook = {
    sets = {
        author     = { "author", "organization", "editor", "publisher", "title", },
        ineditor   = { "editor" },
        editionset = generic.editionset,
        doi        = generic.doi,
    },
    required = {
        "author",
        "year" ,
    },
    optional = {
        "ineditor",
        "withauthor", "translator",
        "subtitle", "type", "file",
        "booktitle", "subbooktitle",
        -- APA ignores this: "chapter",
        "editionset", "series",
        "month",
        "address",
        "doi", "note",
    },
}

-- a book having its own title as part of a collection.
-- (like inbook, but we here make booktitle required)

categories.incollection = {
    sets = {
        author     = { "author", "editor", "publisher", "title", },
        ineditor   = { "editor" },
        editionset = generic.editionset,
        doi        = generic.doi,
    },
    required = {
        "author",
        "booktitle",
        "year",
    },
    optional = {
        "ineditor",
        "withauthor", "translator",
        "subtitle", "type", "file",
        "subbooktitle",
        "editionset", "series",
        -- APA ignores this: "chapter",
        "month",
        "address",
        "doi", "note",
    },
}

-- a work that is printed and bound, but without a named publisher or sponsoring institution.

categories.booklet = {
    sets = {
        author = { "author", "title", },
        publisher = { "howpublished" }, -- no "publisher"!
        doi    = generic.doi,
    },
    required = {
        "author"
    },
    optional = {
        "withauthor", "translator",
        "publisher",
        "year", "month",
        "subtitle", "type", "file",
        "address",
        "doi", "note",
     },
}

-- the proceedings of a conference.

categories.proceedings = {
    sets = {
        author     = { "editor", "organization", "publisher", "title" }, -- no "author"!
        publisher  = { "publisher", "organization" },
        editionset = generic.editionset,
        doi        = generic.doi,
    },
    required = {
        "author",
        "year"
    },
    optional = {
        "withauthor", "translator",
        "publisher",
        "subtitle", "file",
        "editionset", "series",
        "month",
        "address",
        "doi", "note",
    },
}

-- an article in a conference proceedings.

categories.inproceedings = {
    sets     = categories.incollection.sets,
    required = categories.incollection.required,
    optional = {
        "withauthor", "translator",
        "subtitle", "type", "file",
        "month",
        "edition", "series",
        "address", "organization",
        "doi", "note",
    },
}

categories.conference = categories.inproceedings

-- a thesis (of course).

categories.thesis = {
    sets = {
        doi = generic.doi,
    },
    required = {
        "author",
        "title",
        "school",
        "year",
        "type"
    },
    optional = {
        "withauthor", "translator",
        "subtitle", "file",
        "month",
        "address",
        "doi", "note",
    },
}

categories.mastersthesis = {
    sets     = categories.thesis.sets,
    required = {
        "author",
        "title",
        "school",
        "year"
    },
    optional = {
        "withauthor", "translator",
        "type",
        "subtitle", "file",
        "month",
        "address",
        "doi", "note",
    },
}
categories.phdthesis = categories.mastersthesis

-- a report published by a school or other institution, usually numbered within a series.

categories.techreport = {
    sets = {
        author     = { "author", "institution", "publisher", "title" },
        publisher  = { "publisher", "institution", },
        editionset = { "type", "volume", "number", "pages" }, -- no "edition"!
        doi        = generic.doi,
    },
    required = {
        "author",
        "title",
        "institution",
        "year"
    },
    optional = {
        "withauthor", "translator",
        "publisher",
        "address",
        "subtitle", "file",
        "editionset",
        "month",
        "doi", "note",
    },
}

-- technical documentation.

categories.manual = {
    sets = {
        author     = { "author", "organization", "publisher", "title" },
        publisher  = { "publisher", "organization", },
        editionset = generic.editionset,
        doi        = generic.doi,
    },
    required = {
        "title"
    },
    optional = {
        "author", "publisher",
        "withauthor", "translator",
        "address",
        "subtitle", "file",
        "editionset", "month", "year",
        "doi", "note",
--         "abstract",
    },
}

-- a patent (of course).

categories.patent = {
    sets = {
        author = { "author", "assignee", },
        publisher = { "publisher", "assignee", },
        year = { "year", "yearfiled", },
        month = { "month", "monthfiled", },
        day = { "day", "dayfiled", },
        doi = generic.doi,
    },
    required = {
        "nationality",
        "number",
        "year",
    },
    optional = {
        "type",
        --check this: "language",
        "author", "publisher",
        "withauthor", "translator",
        "title", "subtitle", "file",
        "address",
        "day", "month",
        "doi", "note"
    },
}

-- a document having an author and title, but not formally published.

categories.unpublished = {
    sets = {
        doi = generic.doi,
    },
    required = {
        "author",
        "title",
        "note"
    },
    optional = {
        "withauthor", "translator",
        "subtitle", "file",
        "year", "month",
        "doi"
    },
}

-- like misc below but includes organization.

categories.electronic = {
    sets = {
        doi = generic.doi,
        author = { "author", "organization", },
    },
    required = {
        "title"
    },
    optional = {
        "subtitle", "type", "file",
        "year", "month",
        "author", "withauthor", "translator",
        "address",
        "organization",
        "howpublished",
        "doi", "note"
    },
}

-- not bibtex categories...

categories.film = {
    sets = {
        doi = generic.doi,
        author = { "author", "producer", "director", },
    },
    required = {
        "author",
        "title",
        "year",
        "address", "publisher", -- aka studio
    },
    optional = {
        "withauthor", "translator",
        "type",
        "note",
        "doi",
    },
}

categories.music = {
    sets = {
        doi = generic.doi,
        author  = { "composer", "artist", "title", "album" },
        title   = { "title", "album", },
    },
    required = {
        "author",
        "title",
        "year",
        "address", "publisher", -- aka label
    },
    optional = {
        "withauthor", "translator",
        "type",
        "note",
        "doi",
    },
}

-- use this type when nothing else fits.

categories.misc = {
    sets = {
        doi  = generic.doi,
    },
    required = {
        -- nothing is really important here
    },
    optional = {
        "author", "withauthor", "translator",
        "title", "subtitle", "file",
        "year", "month",
        "howpublished",
        "doi", "note",
    },
}

-- other (whatever jabref does not know!)

categories.other = {
    sets = {
        doi  = generic.doi,
    },
    required = {
        "author",
        "title",
        "year"
    },
    optional = {
        "withauthor", "translator",
        "subtitle", "file",
        "doi", "note",
    },
}

-- if all else fails to match:

categories.literal = {
    sets = {
        author = { "key" },
        doi    = generic.doi,
    },
    required = {
        "author",
        "text"
    },
    optional = {
        "withauthor", "translator",
        "doi", "note"
    },
    virtual = false,
}

-- done

return specification
