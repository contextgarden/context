if not modules then modules = { } end modules ['back-pdf'] = {
    version   = 1.001,
    comment   = "companion to back-pdf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We hide the pdf table from users so that we can guarantee no interference with
-- the way we manage resources, info, etc. Users should use the \type {lpdf}
-- interface instead. If needed I will provide replacement functionality.

interfaces.implement {
    name      = "setpdfcompression",
    arguments = { "integer", "integer" },
    actions   = lpdf.setcompression,
}

if CONTEXTLMTXMODE == 0 then
    updaters.apply("backend.update.pdf")
    updaters.apply("backend.update.lpdf")
    updaters.apply("backend.update.tex")
    updaters.apply("backend.update")
end

backends.install("pdf")
