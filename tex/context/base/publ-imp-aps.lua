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
        author      = "author",
        editor      = "author",
        artist      = "author",
        interpreter = "author",
        composer    = "author",
        producer    = "author",
        doi         = "url",
        url         = "url", 
        page        = "pagenumber",
        pages       = "pagenumber",
        keywords    = "keyword",
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
                doi     = { "doi", "url" },
            },
            required = { "author", "title", "year", "note", "doi" },
            optional = { "subtitle", "file" },
        },
        ["demo-b"] = {
            sets     = {
                authors = { "author", "institution", "organization" },
                doi     = { "doi", "url" },
            },
            required = { "authors", "title", "year", "note", "doi" },
            optional = { "subtitle", "file" },
        },
        --
        -- more categories are added below
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
    doi = { "doi", "url" },
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
        author = { "author", "editor", "title" },
	volume = { "volume", "number", "pages" },
        doi    = generic.doi,
        isbn   = { "issn" },
    },
    required = {
        "author"
    },
    optional = {
        "collaboration",
        "year",
        "subtitle", "type", "file",
        "journal", "volume",
        "doi", "note", "isbn"
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
        "subtitle", "type", "file",
        "volume",
        "month", "day",
        "doi", "note", "isbn"
    },
}

categories.newspaper = categories.magazine

-- (from jabref) to be identified and setup ...

categories.periodical = {
    sets = {
        author = { "editor", "publisher" },
        doi    = generic.doi,
        isbn   = { "issn" },
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
        "doi", "note", "isbn"
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
        "collaboration",
    },
}

-- a book with an explicit publisher.

categories.book = {
    sets = {
        author  = { "author", "editor", "publisher", "title" },
        edition = { "edition", "volume", "number", "pages" },
        doi     = generic.doi,
    },
    required = { "author" },
    optional = {
        "collaboration",
        "year", "month", "day",
        "subtitle", "type",  "file",
        "edition", "series",
        "address",
        "doi", "note", "isbn"
    },
}

-- a part of a book, which may be a chapter (or section or whatever) and/or a range of pages.

categories.inbook = {
    sets = {
        author  = { "author", "editor", "publisher", "title", "chapter" },
        edition = { "edition", "volume", "number", "pages" },
        doi     = generic.doi,
    },
    required = {
        "author",
        "year" ,
    },
    optional = {
        "collaboration",
        "subtitle", "type", "file",
        "edition", "series",
        "month",
        "address",
        "doi", "note", "isbn"
    },
}

-- a work that is printed and bound, but without a named publisher or sponsoring institution.

categories.booklet = {
    sets = {
        author = { "author", "title" },
        doi    = generic.doi,
    },
    required = {
        "author"
    },
    optional = {
        "collaboration",
        "year", "month",
        "subtitle", "type", "file",
        "address",
        "howpublished",
        "doi", "note", "isbn"
     },
}

-- a part of a book having its own title.

categories.incollection = {
    sets = {
        author  = { "author", "editor", "publisher", "title" },
        edition = { "edition", "volume", "number", "pages" },
        doi     = generic.doi,
    },
    required = {
        "author",
        "booktitle",
        "year",
    },
    optional = {
        "collaboration",
        "subtitle", "type", "file",
        "month",
        "edition", "series",
        "chapter",
        "address",
        "doi", "note", "isbn"
    },
}

-- the proceedings of a conference.

categories.proceedings = {
    sets = {
        author  = { "editor", "publisher", "title" },
        edition = { "edition", "volume", "number", "pages" },
        doi     = generic.doi,
    },
    required = {
        "author",
        "year"
    },
    optional = {
        "collaboration",
        "subtitle", "file",
        "edition", "series",
        "month",
        "address", "organization",
        "doi", "note", "isbn"
    },
}

-- an article in a conference proceedings.

categories.inproceedings = {
    sets     = categories.incollection.sets,
    required = categories.incollection.required,
    optional = {
        "collaboration",
        "subtitle", "type", "file",
        "month",
        "edition", "series",
        "address", "organization",
        "doi", "note", "isbn"
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
        "collaboration",
        "subtitle", "file",
        "month",
        "address",
        "doi", "note", "isbn"
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
        "doi", "note", "isbn"
    },
}
categories.phdthesis = categories.mastersthesis

-- a report published by a school or other institution, usually numbered within a series.

categories.techreport = {
    sets = {
        -- no "edition"!
        edition = { "type", "volume", "number", "pages" },
        doi     = generic.doi,
    },
    required = {
        "author",
        "title",
        "institution",
        "year"
    },
    optional = {
        "collaboration",
        "subtitle", "file",
        "edition", -- set, not field!
        "month",
        "address",
        "doi", "note", "isbn"
    },
}

-- technical documentation.

categories.manual = {
    sets = {
        edition = { "edition", "volume", "number", "pages" },
        doi     = generic.doi,
    },
    required = {
        "title"
    },
    optional = {
        "collaboration",
        "subtitle", "file",
        "author", "address", "organization",
        "edition", "month", "year",
        "doi", "note", "isbn"
    },
}

-- a patent (of course).

categories.patent = {
    sets = {
        doi = generic.doi,
    },
    required = {
        "nationality",
        "number",
        "year", "yearfiled"
    },
    optional = {
        "type",
        --check this: "language",
        "collaboration",
        "author", "assignee",
        "title", "subtitle", "file",
        "address",
        "day", "dayfiled", "month", "monthfiled",
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
        "collaboration",
        "subtitle", "file",
        "year", "month",
        "doi"
    },
}

-- like misc below but includes organization.

categories.electronic = {
    sets = {
        doi = generic.doi,
    },
    required = {
        "title"
    },
    optional = {
        "subtitle", "type", "file",
        "year", "month",
        "author",
        "collaboration",
        "address",
        "organization",
        "howpublished",
        "doi", "note"
    },
}

-- use this type when nothing else fits.

categories.misc = {
    sets = {
        doi  = generic.doi,
        isbn = { "isbn", "issn" },
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
        "doi", "note", "isbn"
    },
}

-- other (whatever jabref does not know!)

categories.other = {
    sets = {
        doi  = generic.doi,
        isbn = { "isbn", "issn" },
    },
    required = {
        "author",
        "title",
        "year"
    },
    optional = {
        "collaboration",
        "subtitle", "file",
        "doi", "note", "isbn"
    },
}

-- if all else fails to match:

categories.literal = {
    sets = {
        author = { "key" }, -- need to check this!
        doi    = generic.doi,
    },
    required = {
        "text"
    },
    optional = {
        "author",
        "doi", "note"
    },
    virtual = false,
}

-- done

return specification
