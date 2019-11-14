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

local setmetatableindex = table.setmetatableindex

interfaces.implement {
    name      = "setpdfcompression",
    arguments = { "integer", "integer" },
    actions   = lpdf.setcompression,
}

do

    local dummy  = function() end
    local report = logs.reporter("backend")

    local function unavailable(t,k)
        report("calling unavailable pdf.%s function",k)
        t[k] = dummy
        return dummy
    end

    updaters.register("backend.update",function()
        --
        -- For now we keep this for tikz. If really needed some more can be made
        -- accessible but it has to happen in a controlled way then, for instance
        -- by first loading or enabling some compatibility layer so that we can
        -- trace possible interferences.
        --
        pdf = {
            immediateobj = pdf.immediateobj
        }
        setmetatableindex(pdf,unavailable)
    end)

end

backends.install("pdf")
