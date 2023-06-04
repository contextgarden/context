local function wipers(s)
    return {
        "tex/context/third/"    ..s.. "/**",
        "doc/context/third/"    ..s.. "/**",
        "source/context/third/" ..s.. "/**",

        "tex/context/"          ..s.. "/**",
        "doc/context/"          ..s.. "/**",
        "source/context/"       ..s.. "/**",

        "scripts/"              ..s.. "/**",
    }
end

local defaults = {
    "tex/latex/**",
    "tex/plain/**",

    "doc/latex/**",
    "doc/plain/**",
    "doc/generic/**",

    "source/latex/**",
    "source/plain/**",
 -- "source/generic/**",
}

return {
    name = "mtx-install-imp-tikz",
    version = "1.00",
    comment = "Tikz",
    author = "Hans Hagen & others",
    copyright = "ConTeXt development team",
    lists = {
        ["tikz"] = {
            url  = "ctan",
            zips = {
                "graphics/pgf/base/pgf.tds.zip",
                "graphics/pgf/contrib/pgfplots.tds.zip",
                "graphics/pgf/contrib/circuitikz.tds.zip",
            },
            wipes = {
                wipers("pgf"),
                wipers("pgfplots"),
                wipers("circuitikz"),
                defaults,
            }
        },
    },
}
