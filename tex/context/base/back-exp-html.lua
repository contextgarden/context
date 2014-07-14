return {
    name = "html export",
    version = "1.00",
    comment = "Experimental feature.",
    author = "Hans Hagen",
    copyright = "ConTeXt development team",
    suffix = "html",
    remapping = {
        {
            pattern = "tabulate",
            element = "table",
            class   = "tabulate",
        },
        {
            pattern = "tabulaterow",
            element = "tr",
            class   = "tabulate.tr",
        },
        {
            pattern = "tabulatecell",
            element = "td",
            class   = "tabulate.td",
            extras  = {
                align = {
                    flushleft  = "tabulate.td.left",
                    flushright = "tabulate.td.right",
                    middle     = "tabulate.td.center",
                }
            }
        },
        {
            pattern = "break",
            element = "br",
        },
        {
            pattern = "section",
            element = "div",
        },
        {
            pattern = "verbatimblock",
            element = "pre",
        },
        {
            pattern = "verbatimlines|verbatimline",
            element = "div",
        },
        {
            pattern = "!(div|table|td|tr|pre)",
            element = "div",
        },
    }
}
