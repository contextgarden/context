local specification = {
    --
    -- metadata
    --
    name      = "aps",
    version   = "1.00",
    comment   = "APS specification",
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
        editor      = "author",
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
    editionset = { "edition", "volume", "number", "pages" },
}

-- Note that the APS specification allows an additional field "collaboration"
-- to be rendered following the author list (if the collaboration name appears
-- in the byline of the cited article).

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
        author = { "author", "editor" },
    },
    required = {
        "author",
    },
    optional = {
        "collaboration",
        "year",
        "title", "subtitle", "type", "file",
        "journal", "volume", "number", "pages",
        "doi", "url", "note",
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
        "collaboration",
        "title", "subtitle", "type", "file",
        "number", "pages",
        "month", "day",
        "doi", "url", "note",
    },
}

categories.newspaper = categories.magazine

-- (from jabref) to be identified and setup ...

categories.periodical = {
    sets = {
        author = { "editor", "publisher" },
    },
    required = {
        "title",
        "year",
    },
    optional = {
        "author",
        "collaboration",
        "subtitle", "file",
        "series", "volume", "number", "month",
        "organization",
        "doi", "url", "note",
    },
}

-- (from jabref) to be identified and setup ...

categories.standard = {
    sets = {
        author = { "author", "institution", "organization" },
    },
    required = {
        "author",
        "year",
        "title", "subtitle",
        "doi", "note",
    },
    optional = {
        "collaboration",
        "url",
    },
}

-- a book with an explicit publisher.

categories.book = {
    sets = {
        author     = { "author", "editor", "publisher" },
        editionset = generic.editionset,
    },
    required = {
        "author",
        "title",
    },
    optional = {
        "collaboration",
        "year", "month", "day",
        "title", "subtitle", "type",  "file",
        "editionset", "series",
        "address",
        "doi", "url", "note",
    },
}

-- a part of a book, which may be a chapter (or section or whatever) and/or a range of pages.

categories.inbook = {
    sets = {
        author     = { "author", "editor", "publisher", },
        editionset = generic.editionset,
    },
    required = {
        "author",
        "year" ,
        "title",
    },
    optional = {
        "collaboration",
        "subtitle", "type", "file",
        "booktitle",
        -- "chapter",
        "editionset", "series",
        "month",
        "address",
        "doi", "url", "note",
    },
}

-- a book having its own title as part of a collection.
-- (like inbook, but we here make booktitle required)

categories.incollection = {
    sets = {
        author     = { "author", "editor", "publisher" },
        editionset = generic.editionset,
    },
    required = {
        "author",
        "booktitle",
        "year",
    },
    optional = {
        "collaboration",
        "title", "subtitle", "type", "file",
        "editionset", "series",
        "chapter",
        "month",
        "address",
        "doi", "url", "note",
    },
}

-- a work that is printed and bound, but without a named publisher or sponsoring institution.

categories.booklet = {
    sets = {
        publisher = { "howpublished" }, -- no "publisher"!
    },
    required = {
        "author",
        "title",
    },
    optional = {
        "publisher",
        "collaboration",
        "year", "month",
        "subtitle", "type", "file",
        "address",
        "doi", "url", "note",
     },
}

-- the proceedings of a conference.

categories.proceedings = {
    sets = {
        author     = { "editor", "organization", "publisher" }, -- no "author"!
        publisher  = { "publisher", "organization" },
        editionset = generic.editionset,
    },
    required = {
        "author",
        "year"
    },
    optional = {
        "collaboration",
        "publisher",
        "title", "subtitle", "file",
        "editionset", "series",
        "month",
        "address",
        "doi", "url", "note",
    },
}

-- an article in a conference proceedings.

categories.inproceedings = {
    sets     = categories.incollection.sets,
    required = categories.incollection.required,
    optional = {
        "collaboration",
        "title", "subtitle", "type", "file",
        "month",
        "edition", "series",
        "address", "organization",
        "doi", "url", "note",
    },
}

categories.conference = categories.inproceedings

-- a thesis (of course).

categories.thesis = {
    required = {
        "author",
        "title",
        "school",
        "year",
        "type"
    },
    optional = {
        "collaboration",
        "subtitle", "file",
        "month",
        "address",
        "doi", "url", "note",
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
        "collaboration",
        "type",
        "subtitle", "file",
        "month",
        "address",
        "doi", "url", "note",
    },
}
categories.phdthesis = categories.mastersthesis

-- a report published by a school or other institution, usually numbered within a series.

categories.techreport = {
    sets = {
        author     = { "author", "institution", "publisher" },
        publisher  = { "publisher", "institution", },
        editionset = { "type", "volume", "number", "pages" }, -- no "edition"!
    },
    required = {
        "author",
        "title",
        "institution",
        "year"
    },
    optional = {
        "collaboration",
        "publisher",
        "address",
        "subtitle", "file",
        "editionset",
        "month",
        "doi", "url", "note",
    },
}

-- technical documentation.

categories.manual = {
    sets = {
        author     = { "author", "organization", "publisher" },
        publisher  = { "publisher", "organization", },
        editionset = generic.editionset,
    },
    required = {
        "title"
    },
    optional = {
        "author", "publisher",
        "collaboration",
        "address",
        "subtitle", "file",
        "editionset", "month", "year",
        "doi", "url", "note",
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
        "collaboration",
        "title", "subtitle", "file",
        "address",
        "day", "month",
        "doi", "url", "note",
    },
}

-- a document having an author and title, but not formally published.

categories.unpublished = {
    required = {
        "author",
        "title",
        "note"
    },
    optional = {
        "collaboration",
        "subtitle", "file",
        "year", "month",
        "doi", "url",
    },
}

-- like misc below but includes organization.

categories.electronic = {
    sets = {
        author = { "author", "collaboration", "organization", },
        howpublished = { "howpublished", "doi", "url", },
    },
    required = {
        "title"
    },
    optional = {
        "subtitle", "type", "file",
        "year", "month",
        "author",
        "collaboration",
        "organization",
        "address",
        "howpublished",
        "doi", "url", "note",
    },
}

-- use this type when nothing else fits.

categories.misc = {
    sets = {
        author = { "author", "collaboration", },
        howpublished = { "howpublished", "doi", "url", },
    },
    required = {
        -- nothing is really important here
    },
    optional = {
        "author",
        "collaboration",
        "title", "subtitle", "file",
        "year", "month",
        "howpublished",
        "doi", "url", "note",
    },
}

-- other (whatever jabref does not know!)

categories.other = {
    required = {
        "author",
        "title",
        "year"
    },
    optional = {
        "collaboration",
        "subtitle", "file",
        "doi", "url", "note",
    },
}

-- if all else fails to match:

categories.literal = {
    sets = {
        author = { "tag" }, -- need to check this!
    },
    required = {
        "text"
    },
    optional = {
        "author",
        "doi", "url", "note"
    },
    virtual = false,
}

-- done

return specification
