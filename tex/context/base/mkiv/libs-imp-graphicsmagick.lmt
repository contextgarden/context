if not modules then modules = { } end modules ['libs-imp-graphicsmagick'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkxl",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local libname = "graphicsmagick"
local libfile = { "CORE_RL_magick_", "CORE_RL_wand_" }

local gmlib = resolvers.libraries.validoptional(libname)

if not gmlib then return end

local function okay()
    if resolvers.libraries.optionalloaded(libname,libfile) then
        okay = function() return true end
    else
        okay = function() return false end
    end
    return okay()
end

local graphicsmagick     = utilities.graphicsmagick or { }
utilities.graphicsmagick = graphicsmagick
utilities.graphicmagick  = graphicsmagick

local gm_execute = gmlib.execute
local nofruns    = 0
local report     = logs.reporter(libname)

function graphicsmagick.convert(specification)
    if okay() then
        --
        nofruns = nofruns + 1
        statistics.starttiming(graphicsmagick)
        --
        local inputname  = specification.inputname
        if not inputname or inputname == "" then
            report("invalid run %s, no inputname specified",nofruns)
            statistics.stoptiming(graphicsmagick)
            return false
        end
        local outputname = specification.outputname
        if not outputname or outputname == "" then
            outputname = file.replacesuffix(inputname,"pdf")
        end
        --
        if not lfs.isfile(inputname) then
            report("invalid run %s, input file %a is not found",nofruns,inputname)
            statistics.stoptiming(graphicsmagick)
            return false
        end
        --
        report("run %s, input file %a, outputfile %a",nofruns,inputname,outputname)
        --
        gm_execute { inputfile = inputname, outputfile = outputname }
        --
        statistics.stoptiming(graphicsmagick)
    end
end

function graphicsmagick.statistics(report)
    local runtime = statistics.elapsedtime(graphicsmagick)
    if report then
        report("nofruns %s, runtime %s",nofruns,runtime)
    else
        return {
            runtime = runtime,
            nofruns = nofruns,
        }
    end
end

-- graphicsmagick.convert { inputname = "t:/sources/hacker.jpg", outputname = "e:/tmp/hacker.png" }
-- graphicsmagick.statistics(true)
