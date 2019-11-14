if not modules then modules = { } end modules ['m-asymptote'] = {
    version   = 1.001,
    comment   = "companion to m-asymptote.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- See m-asymptote.mkiv for some comment.

local context = context
local replacesuffix = file.replacesuffix

moduledata.asymptote = { }

sandbox.registerrunner {
    name     = "asymptote prc",
    program  = "asy",
    method   = "execute",
    template = [[-noV -config="" -tex=context -outformat="prc" %filename%]],
    checkers = { filename = "readable" },
}

sandbox.registerrunner {
    name     = "asymptote pdf",
    program  = "asy",
    method   = "execute",
    template = [[-noV -config="" -tex=context -outformat="pdf" %filename%]],
    checkers = { filename = "readable" },
}

function moduledata.asympote.process(name,type)
    if type == "prc" then
        local result = buffers.run(name,false,"asymptote prc","prc")
        local jsdata = { js = replacesuffix(result,"js") }
        local parset = parametersets[name]
        if parset then
            -- so we can overload at the tex end
            setmetatableindex(parset,jsdata)
        else
            parametersets[name] = jsdata
        end
        context(result)
    else
        local result = buffers.run(name,false,"asymptote pdf","pdf")
        context(result)
    end
end
