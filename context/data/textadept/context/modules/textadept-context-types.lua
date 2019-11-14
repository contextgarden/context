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

-- autopdf takes long to stop (weird, not in scite)

-- WIN32 and 'start "" "%e.pdf"' or OSX and 'open "%e.pdf"' or 'xdg-open "%e.pdf"',

local quitter = function(output)
    return find(output,"%? +$") and true or false, "see message above"
end

local listing = {
    command = [[mtxrun --autogenerate --script context --autopdf --extra=listing --scite --compact "%basename%"]],
    quitter = quitter,
}

install {
    lexer    = "scite-context-lexer-tex",
    suffixes = {
        "tex",
        "mkii",
        "mkiv", "mkvi", "mkix", "mkxi",
        "mkic", "mkci", 

    },
    check    = {
        command = [[mtxrun --autogenerate --script check "%basename%"]],
        quitter = quitter,
    },
    process  = {
        command = [[mtxrun --autogenerate --script context --autopdf "%basename%"]], 
        quitter = quitter,
    },
    listing  = listing,
    generate = [[mtxrun --generate]],
    fonts    = [[mtxrun --script fonts --reload --force]],
    clear    = [[mtxrun --script cache --erase]],
    purge    = [[mtxrun --script context --purgeall]],
    preview  = [[]],
    logfile  = [[]],
    arrange  = [[]],
    unicodes = [[]],
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
    process  = {
        command = [[mtxrun --autogenerate --script context --autopdf "%basename%"]], --  --autopdf]],
        quitter = quitter,
    },
    listing  = listing,
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    lexer    = "scite-context-lexer-mps",
    suffixes = {
        "mp", "mpx"
    },
    listing  = listing,
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
    listing  = listing,
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    lexer    = "scite-context-lexer-txt",
    suffixes = {
        "txt"
    },
    listing  = listing,
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
    listing  = listing,
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
    listing  = listing,
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    "scite-context-lexer-bibtex",
    suffixes = {
        "bib"
    },
    listing  = listing,
    setter   = function(lexer)
        -- whatever
    end,
}

install {
    "scite-context-lexer-sql",
    suffixes = {
        "sql"
    },
    listing  = listing,
    setter   = function(lexer)
        -- whatever
    end,
}
