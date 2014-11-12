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
        author      = "author",
        editor      = "author",
        artist      = "author",
        interpreter = "author",
        composer    = "author",
        producer    = "author",
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
            required = { "author", "title", "year", "note", "url" },
            optional = { "subtitle", "doi", "file" },
        },
        ["demo-b"] = {
            sets     = {
                authors = { "author", "institution", "organization" },
            },
            required = { "authors", "title", "year", "note", "url" },
            optional = { "subtitle", "doi", "file" },
        },
        --
        -- more categories are added below
        --
    },
}

-- Definition of recognized categories and the fields that they contain.
-- Required fields should be present; optional fields may also be rendered;
-- all other fields will be ignored.

-- Sets contain either/or in order of precedence.

local categories = specification.categories

-- an article from a journal

categories.article = {
    sets = {
        author = { "author", "editor", "title" },
        links  = { "doi", "url" },
        isbn   = { "issn" },
    },
    required = {
        "author"
    },
    optional = {
        "year",
        "subtitle", "type", "file",
        "journal", "volume", "number", "pages",
        "note", "links", "isbn",
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
        "subtitle", "type", "file",
        "volume", "number", "pages",
        "month", "day",
        "note", "links", "isbn",
    },
}

categories.newspaper = categories.magazine

-- (from jabref) to be identified and setup ...

categories.periodical = {
    sets = {
        author = { "editor", "publisher" },
        links  = { "doi", "url" },
        isbn   = { "issn" },
    },
    required = {
        "title",
        "year",
    },
    optional = {
        "author",
        "subtitle", "file",
        "series", "volume", "number", "month",
        "organization",
        "note", "links", "isbn",
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
        "note",
        "url",
    },
    optional = {
        "doi"
    },
}

-- a book with an explicit publisher.

categories.book = {
    sets = {
        author = { "author", "editor", "publisher", "title" },
    },
    required = { "author" },
    optional = {
        "year", "month", "day",
        "subtitle", "type",  "file",
        "edition", "series", "volume", "number", "pages",
        "address",
        "url",
        "note", "isbn"
    },
}

-- a part of a book, which may be a chapter (or section or whatever) and/or a range of pages.

categories.inbook = {
    sets = {
        author = { "author", "editor", "publisher", "title", "chapter", "pages" },
    },
    required = {
        "author",
        "year" ,
    },
    optional = {
        "subtitle", "type", "file",
        "volume", "number", "series",
        "edition", "month",
        "address",
        "note", "isbn"
    },
}

-- a work that is printed and bound, but without a named publisher or sponsoring institution.

categories.booklet = {
    sets = {
        author = { "author", "title" },
    },
    required = {
        "author"
    },
    optional = {
        "year", "month",
         "subtitle", "type", "file",
         "address",
         "howpublished",
         "note", "isbn"
     },
}

-- a part of a book having its own title.

categories.incollection = {
    sets = {
        author = { "author", "editor", "publisher", "title" },
    },
    required = {
        "author",
        "booktitle",
        "year",
    },
    optional = {
        "subtitle", "type", "file",
        "month", "edition",
        "volume", "number", "series",
        "chapter", "pages",
        "address",
        "note", "isbn"
    },
}

-- the proceedings of a conference.

categories.proceedings = {
    sets = {
        author = { "editor", "publisher", "title" },
    },
    required = {
        "author",
        "year"
    },
    optional = {
        "subtitle", "file",
        "volume", "number", "series", "pages",
        "month",
        "address", "organization",
        "note", "isbn"
    },
}

-- an article in a conference proceedings.

categories.inproceedings = {
    sets     = categories.incollection.sets,
    required = categories.incollection.required,
    optional = {
        "subtitle", "type", "file",
        "month",
        "volume", "number", "series",
        "pages",
        "address", "organization",
        "note", "isbn"
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
        "subtitle", "file",
        "month",
        "address",
        "note"
    },
}

categories.mastersthesis = {
    required = {
        "author",
        "title",
        "school",
        "year"
    },
    optional = {
        "type",
        "subtitle", "file",
        "month",
        "address",
        "note"
    },
}
categories.phdthesis = categories.mastersthesis

-- a report published by a school or other institution, usually numbered within a series.

categories.techreport = {
    required = {
        "author",
        "title",
        "institution",
        "year"
    },
    optional = {
        "subtitle", "type", "file",
        "number", "month",
        "address",
        "note", --"isbn",
    },
}

-- technical documentation.

categories.manual = {
    required = {
        "title"
    },
    optional = {
        "subtitle", "file",
        "author", "address", "organization",
        "edition", "month", "year",
        "note", "isbn",
    },
}

-- a patent (of course).

categories.patent = {
    required = {
        "nationality",
        "number",
        "year", "yearfiled"
    },
    optional = {
        "type",
        --check this: "language",
        "author", "assignee",
        "title", "subtitle", "file",
        "address",
        "day", "dayfiled", "month", "monthfiled",
        "note"
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
        "subtitle", "file",
        "year", "month"
    },
}

-- like misc below but includes organization.

categories.electronic = {
    required = {
        "title"
    },
    optional = {
        "subtitle", "type", "file",
        "year", "month",
        "author",
        "address",
        "organization",
        "howpublished",
        "url", "doi",
        "note"
    },
}

-- use this type when nothing else fits.

categories.misc = {
    sets = {
        isbn   = { "isbn", "issn" },
    },
    required = {
        -- nothing is really important here
    },
    optional = {
        "author",
        "title", "subtitle", "file",
        "year", "month",
        "howpublished",
        "note", "isbn",
    },
}

-- other (whatever jabref does not know!)

categories.other = {
    sets = {
        isbn   = { "isbn", "issn" },
    },
    required = {
        "author",
        "title",
        "year"
    },
    optional = {
        "subtitle", "file",
        "note",
        "doi", "isbn",
    },
}

-- if all else fails to match:

categories.literal = {
    sets = {
        author = { "key" },
    },
    required = {
        "author",
        "text"
    },
 -- optional = {
 --  -- whatever comes up
 -- },
    virtual = false,
}

-- done

return specification
