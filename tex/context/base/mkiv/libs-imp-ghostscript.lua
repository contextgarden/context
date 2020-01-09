if not modules then modules = { } end modules ['libs-imp-ghostscript'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkxl",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local libname = "ghostscript"
local libfile = "gsdll64" -- what on unix?

local gslib = resolvers.libraries.validoptional(libname)

if not gslib then return end

local function okay()
    if resolvers.libraries.optionalloaded(libname,libfile) then
        okay = function() return true end
    else
        okay = function() return false end
    end
    return okay()
end

local insert = table.insert
local formatters = string.formatters

local ghostscript     = utilities.ghostscript or { }
utilities.ghostscript = ghostscript

local gs_execute = gslib.execute
local nofruns    = 0
local report     = logs.reporter(libname)

function ghostscript.convert(specification)
    if okay() then
        --
        nofruns = nofruns + 1
        statistics.starttiming(ghostscript)
        --
        local inputname = specification.inputname
        if not inputname or inputname == "" then
            report("invalid run %s, no inputname specified",nofruns)
            statistics.stoptiming(ghostscript)
            return false
        end
        local outputname = specification.outputname
        if not outputname or outputname == "" then
            outputname = file.replacesuffix(inputname,"pdf")
        end
        --
        if not lfs.isfile(inputname) then
            report("invalid run %s, input file %a is not found",nofruns,inputname)
            statistics.stoptiming(ghostscript)
            return false
        end
        --
        local device = specification.device
        if not device or device == "" then
            device = "pdfwrite"
        end
        --
        local code = specification.code
        if not code or code == "" then
            code = ".setpdfwrite"
        end
        --
        local options = specification.options or { }
        --
        insert(options,"-dNOPAUSE")
        insert(options,"-dBATCH")
        insert(options,"-dSAFER")
        insert(options,formatters["-sDEVICE=%s"](device))
        insert(options,formatters["-sOutputFile=%s"](outputname))
        insert(options,"-c")
        insert(options,code)
        insert(options,"-f")
        insert(options,inputname)
        --
        report("run %s, input file %a, outputfile %a",nofruns,inputname,outputname)
        report("")
        local done = gslib_execute(options)
        report("")
        --
        statistics.stoptiming(ghostscript)
        if done then
            return outputname
        else
            report("run %s quit with errors",nofruns)
            return false
        end
    end
end

function ghostscript.statistics(report)
    local runtime = statistics.elapsedtime(ghostscript)
    if report then
        report("nofruns %s, runtime %s",nofruns,runtime)
    else
        return {
            runtime = runtime,
            nofruns = nofruns,
        }
    end
end

-- for i=1,100 do
--     ghostscript.convert { inputname = "temp.eps" }
--     ghostscript.convert { inputname = "t:/escrito/tiger.eps" }
-- end
-- ghostscript.statistics(true)
