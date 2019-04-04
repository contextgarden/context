if not modules then modules = { } end modules ['core-sys'] = {
    version   = 1.001,
    comment   = "companion to core-sys.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lower, format, gsub = string.lower, string.format, string.gsub
local suffixonly, basename, removesuffix = file.suffix, file.basename, file.removesuffix

local environment  = environment
local context      = context
local implement    = interfaces.implement

local report_files = logs.reporter("system","files")

function environment.initializefilenames()

    local arguments      = environment.arguments

    local jobname        = arguments.jobname or tex.jobname
    local fulljobname    = arguments.fulljobname or jobname
    local inputfilename  = arguments.input or fulljobname
    local outputfilename = arguments.result or removesuffix(jobname)

    local inputfilename  = suffixonly(inputfilename) == "tex" and removesuffix(inputfilename) or inputfilename or ""

    local filename       = fulljobname
    local suffix         = suffixonly(filename)

    local filename       = ctxrunner.resolve(filename) -- in case we're prepped

    local jobfilename    = jobname or inputfilename or tex.jobname or ""
    local inputfilename  = inputfilename or ""

    local jobfilebase    = basename(jobfilename)
    local inputfilebase  = basename(inputfilename)

 -- jobfilename          = gsub(jobfilename,  "^./","")
 -- inputfilename        = gsub(inputfilename,"^./","")

    environment.jobfilefullname   = fulljobname
    environment.jobfilename       = jobfilebase
    environment.jobfilesuffix     = lower(suffixonly(jobfilebase))

    environment.inputfilename     = inputfilename -- so here we keep e.g. ./ or explicit paths
    environment.inputfilebarename = removesuffix(inputfilebase)
    environment.inputfilesuffix   = lower(suffixonly(inputfilebase))

    environment.outputfilename    = outputfilename or environment.inputfilebarename or ""

    environment.filename          = filename
    environment.suffix            = suffix

 -- if tex then
 --     tex.jobname = jobfilename
 -- end

    report_files("jobname %a, input %a, result %a",jobfilename,inputfilename,outputfilename)

    function environment.initializefilenames() end
end

-- we could set a macro (but will that work when we're expanding? needs testing!)

implement { name = "operatingsystem",     actions = function() context(os.platform)                     end }
implement { name = "jobfilefullname",     actions = function() context(environment.jobfilefullname)     end }
implement { name = "jobfilename",         actions = function() context(environment.jobfilename)         end }
implement { name = "jobfilesuffix",       actions = function() context(environment.jobfilesuffix)       end }
implement { name = "inputfilebarename",   actions = function() context(environment.inputfilebarename)   end }
implement { name = "inputfilerealsuffix", actions = function() context(environment.inputfilerealsuffix) end }
implement { name = "inputfilesuffix",     actions = function() context(environment.inputfilesuffix)     end }
implement { name = "inputfilename",       actions = function() context(environment.inputfilename)       end }
implement { name = "outputfilename",      actions = function() context(environment.outputfilename)      end }

statistics.register("result saved in file", function()
    -- suffix will be fetched from backend
    local outputfilename = environment.outputfilename or environment.jobname or tex.jobname or "<unset>"
 -- if (tex.pdfoutput or tex.outputmode) > 0 then
        return format("%s.%s, compresslevel %s, objectcompresslevel %s",outputfilename,"pdf",
            lpdf.getcompression()
        )
 -- else
 --     return format("%s.%s",outputfilename,"dvi") -- hard to imagine
 -- end
end)

implement {
    name      = "systemlog",
    arguments = "3 strings",
    actions   = function(whereto,category,text)
        logs.system(whereto,"context",tex.jobname,category,text)
    end,
}
