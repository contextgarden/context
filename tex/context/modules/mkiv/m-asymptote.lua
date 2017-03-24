if not modules then modules = { } end modules ['m-asymptote'] = {
    version   = 1.001,
    comment   = "companion to m-pstricks.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- See m-asymptote.mkiv for some comment.

local context = context
local replacesuffix = file.replacesuffix

moduledata.asymptote = { }

sandbox.registerrunner {
    name     = "asymptote",
    program  = "asy",
    method   = "execute",
    template = '-noV -config="" -tex=pdflatex -outformat="prc" "%filename%"',
 -- template = '-noV -config="" -tex=context -outformat="prc" "%filename%"',
    checkers = {
        filename = "readable",
    }
}

function moduledata.asympote.process(name)
    local result = buffers.run( -- experimental
        name,        -- name of the buffer
        false,       -- no wrapping
        "asymptote", -- name of the process
        "prc"        -- suffix of result
    )
    parametersets[name] = {
        js = replacesuffix(result,"js")
    }
    context(result)
end
