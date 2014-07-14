return {
    name = "html export",
    version = "1.00",
    comment = "Experimental feature.",
    author = "Hans Hagen",
    copyright = "ConTeXt development team",
    suffix = "html",
    remapping = {
        {
            pattern = "!m:*",
            element = "div",
            extras  = {
                namespace = true, -- okay as we have no attributes with that name
                align     = {
                    flushleft  = "left",
                    flushright = "right",
                    middle     = "center",
                }
            }
        },
    }
}

