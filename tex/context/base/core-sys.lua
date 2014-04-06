if not modules then modules = { } end modules ['core-sys'] = {
    version   = 1.001,
    comment   = "companion to core-sys.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lower, format, gsub = string.lower, string.format, string.gsub
local suffixonly, basename, removesuffix = file.suffix, file.basename, file.removesuffix

local environment = environment

local report_files = logs.reporter("system","files")

-- function commands.updatefilenames(jobname,fulljobname,inputfilename,outputfilename)
--     --
--     environment.jobname             = jobname
--     --
--     local       jobfilename         = gsub(fulljobname or jobname or inputfilename or tex.jobname or "","%./","")
--     --
--     environment.jobfilename         = jobfilename
--     environment.jobfilesuffix       = lower(suffixonly(environment.jobfilename))
--     --
--     local       inputfilename       = gsub(inputfilename or "","%./","")
--     environment.inputfilename       = inputfilename
--     environment.inputfilebarename   = removesuffix(basename(inputfilename))
--     --
--     local       inputfilerealsuffix = suffixonly(inputfilename)
--     environment.inputfilerealsuffix = inputfilerealsuffix
--     --
--     local       inputfilesuffix     = inputfilerealsuffix == "" and "tex" or lower(inputfilerealsuffix)
--     environment.inputfilesuffix     = inputfilesuffix
--     --
--     local       outputfilename      = outputfilename or environment.inputfilebarename or ""
--     environment.outputfilename      = outputfilename
--     --
--     local runpath                   = resolvers.cleanpath(lfs.currentdir())
--     environment.runpath             = runpath
--     --
--     statistics.register("running on path", function()
--         return environment.runpath
--     end)
--     --
--     statistics.register("job file properties", function()
--         return format("jobname %a, input %a, suffix %a",jobfilename,inputfilename,inputfilesuffix)
--     end)
--     --
-- end

function environment.initializefilenames() -- commands.updatefilenames(jobname,fulljobname,input,result)

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

    environment.jobfilename       = jobfilebase
    environment.jobfilesuffix     = lower(suffixonly(jobfilebase))

    environment.inputfilename     = inputfilename -- so here we keep e.g. ./ or explicit paths
    environment.inputfilebarename = removesuffix(inputfilebase)
    environment.inputfilesuffix   = lower(suffixonly(inputfilebase))

    environment.outputfilename    = outputfilename or environment.inputfilebarename or ""

    environment.filename          = filename
    environment.suffix            = suffix

    report_files("jobname %a, input %a, result %a",jobfilename,inputfilename,outputfilename)

    function environment.initializefilenames() end
end

statistics.register("result saved in file", function()
    -- suffix will be fetched from backend
    local outputfilename = environment.outputfilename or environment.jobname or tex.jobname or "<unset>"
    if tex.pdfoutput > 0 then
        return format("%s.%s, compresslevel %s, objectcompresslevel %s",outputfilename,"pdf",tex.pdfcompresslevel, tex.pdfobjcompresslevel)
    else
        return format("%s.%s",outputfilename,"dvi") -- hard to imagine
    end
end)
