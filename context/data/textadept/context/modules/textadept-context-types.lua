local info = {
    version   = 1.002,
    comment   = "filetypes for textadept for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- todo: add the same ones as we have in scite

local lexer   = require("scite-context-lexer")
local context = lexer.context
local install = context.install

install {
    lexer    = "scite-context-lexer-tex",
    suffixes = {
        "tex",
        "mkii",
        "mkiv", "mkvi", "mkix", "mkxi"
    },
    check    = [[mtxrun --autogenerate --script check   "%basename%"]],
    process  = [[mtxrun --autogenerate --script context "%basename%"]], -- --autopdf takes long to stop (weird, not in scite)
    preview  = [[]],
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    lexer    = "scite-context-lexer-xml",
    suffixes = {
        "xml", "xsl", "xsd", "fo", "dtd", "xslt",
        "lmx", "exa", "ctx", "export",
        "rlb", "rlg", "rlv", "rng",
        "xfdf",
        "htm", "html", "xhtml",
        "svg",
        "xul"
    },
    check    = [[tidy -quiet -utf8 -xml -errors "%basename%"]],
    process  = [[mtxrun --autogenerate --script context "%basename%"]], -- --autopdf takes long to stop (weird, not in scite)
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    lexer    = "scite-context-lexer-mps",
    suffixes = {
        "mp", "mpx"
    },
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    lexer    = "scite-context-lexer-lua",
    suffixes = {
        "lua", "luc",
        "cld", "tuc", "luj", "lum", "tma", "lfg", "luv", "lui"
    },
    check    = [[mtxrun --autogenerate --script "%basename%"]],
    process  = [[mtxrun --autogenerate --script "%basename%"]],
    preview  = [[mtxrun --autogenerate --script "%basename%"]],
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    lexer    = "scite-context-lexer-txt",
    suffixes = {
        "txt"
    },
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    lexer    = "scite-context-lexer-pdf",
    suffixes = {
        "pdf"
    },
    encoding = "7-BIT-ASCII",
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    lexer    = "scite-context-lexer-web",
    suffixes = {
        "w",
        "ww"
    },
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    lexer    = "scite-context-lexer-cpp",
    suffixes = {
        "h", "c",
        "hh", "cc",
        "hpp", "cpp",
        "hxx", "cxx"
    },
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    "scite-context-lexer-bibtex",
    suffixes = {
        "bib"
    },
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    "scite-context-lexer-sql",
    suffixes = {
        "sql"
    },
    setter   = function(lexer)
        -- whatever
    end,
}
