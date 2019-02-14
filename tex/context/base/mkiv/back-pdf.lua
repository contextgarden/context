if not modules then modules = { } end modules ['back-pdf'] = {
    version   = 1.001,
    comment   = "companion to back-pdf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

interfaces.implement {
    name      = "setpdfcompression",
    arguments = { "integer", "integer" },
    actions   = lpdf.setcompression,
}

backends.install("pdf")
