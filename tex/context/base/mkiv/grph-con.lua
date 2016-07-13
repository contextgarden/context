if not modules then modules = { } end modules ['grph-con'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, R, S, Cc, C, Cs, Ct, lpegmatch = lpeg.P, lpeg.R, lpeg.S, lpeg.Cc, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.match

local longtostring      = string.longtostring
local formatters        = string.formatters
local expandfilename    = dir.expandname

local settings_to_array = utilities.parsers.settings_to_array
local settings_to_hash  = utilities.parsers.settings_to_hash
local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex
local replacetemplate   = utilities.templates.replace

local codeinjections    = backends.codeinjections
local nodeinjections    = backends.nodeinjections

local report_figures    = logs.reporter("system","graphics")

local variables         = interfaces.variables
local v_high            = variables.high
local v_low             = variables.low
local v_medium          = variables.medium

local figures           = figures

local converters        = figures.converters
local programs          = figures.programs

local runprogram        = programs.run
local makeuptions       = programs.makeoptions

do -- eps | ps

    -- \externalfigure[cow.eps]
    -- \externalfigure[cow.pdf][conversion=stripped]

    -- todo: colorspace
    -- todo: lowres

    local epsconverter = converters.eps
    converters.ps      = epsconverter

    local epstopdf = {
        resolutions = {
            [v_low]    = "screen",
            [v_medium] = "ebook",
            [v_high]   = "prepress",
        },
        command = os.type == "windows" and { "gswin64c", "gswin32c" } or "gs",
        -- -dProcessDSCComments=false
        argument = longtostring [[
            -q
            -sDEVICE=pdfwrite
            -dNOPAUSE
            -dNOCACHE
            -dBATCH
            -dAutoRotatePages=/None
            -dPDFSETTINGS=/%presets%
            -dEPSCrop
            -dCompatibilityLevel=%level%
            -sOutputFile="%newname%"
            %colorspace%
            "%oldname%"
            -c quit
        ]],
    }

    programs.epstopdf = epstopdf
    programs.gs       = epstopdf

    local cleanups    = { }
    local cleaners    = { }

    local whitespace  = lpeg.patterns.whitespace
    local quadruple   = Ct((whitespace^0 * lpeg.patterns.number/tonumber * whitespace^0)^4)
    local betterbox   = P("%%BoundingBox:")      * quadruple
                      * P("%%HiResBoundingBox:") * quadruple
                      * P("%AI3_Cropmarks:")     * quadruple
                      * P("%%CropBox:")          * quadruple
                      / function(b,h,m,c)
                             return formatters["%%%%BoundingBox: %i %i %i %i\n%%%%HiResBoundingBox: %F %F %F %F\n%%%%CropBox: %F %F %F %F\n"](
                                 m[1],m[2],m[3],m[4],
                                 m[1],m[2],m[3],m[4],
                                 m[1],m[2],m[3],m[4]
                             )
                         end
    local nocrap      = P("%") / "" * (
                             (P("AI9_PrivateDataBegin") * P(1)^0)                            / "%%%%EOF"
                           + (P("%EOF") * whitespace^0 * P("%AI9_PrintingDataEnd") * P(1)^0) / "%%%%EOF"
                           + (P("AI7_Thumbnail") * (1-P("%%EndData"))^0 * P("%%EndData"))    / ""
                        )
    local whatever    = nocrap + P(1)
    local pattern     = Cs((betterbox * whatever^1 + whatever)^1)

    directives.register("graphics.conversion.eps.cleanup.ai",function(v) cleanups.ai = v end)

    cleaners.ai = function(name)
        local tmpname = name .. ".tmp"
        io.savedata(tmpname,lpegmatch(pattern,io.loaddata(name) or ""))
        return tmpname
    end

    function epsconverter.pdf(oldname,newname,resolution,colorspace) -- the resolution interface might change
        local epstopdf = programs.epstopdf -- can be changed
        local presets  = epstopdf.resolutions[resolution or "high"] or epstopdf.resolutions.high
        local level    = codeinjections.getformatoption("pdf_level") or "1.3"
        local tmpname  = oldname
        if not tmpname or tmpname == "" or not lfs.isfile(tmpname) then
            return
        end
        if cleanups.ai then
            tmpname = cleaners.ai(oldname)
        end
        if colorspace == "gray" then
            colorspace = "-sColorConversionStrategy=Gray -sProcessColorModel=DeviceGray"
         -- colorspace = "-sColorConversionStrategy=Gray"
        else
            colorspace = nil
        end
        runprogram(epstopdf.command, epstopdf.argument, {
            newname    = newname,
            oldname    = tmpname,
            presets    = presets,
            level      = tostring(level),
            colorspace = colorspace,
        } )
        if tmpname ~= oldname then
            os.remove(tmpname)
        end
    end

    epsconverter["gray.pdf"] = function(oldname,newname,resolution) -- the resolution interface might change
        epsconverter.pdf(oldname,newname,resolution,"gray")
    end

    epsconverter.default = epsconverter.pdf

end

do -- pdf

    local pdfconverter = converters.pdf

    -- programs.pdftoeps = {
    --     command  = "pdftops",
    --     argument = [[-eps "%oldname%" "%newname%"]],
    -- }
    --
    -- pdfconverter.stripped = function(oldname,newname)
    --     local pdftoeps = programs.pdftoeps -- can be changed
    --     local epstopdf = programs.epstopdf -- can be changed
    --     local presets  = epstopdf.resolutions[resolution or ""] or epstopdf.resolutions.high
    --     local level    = codeinjections.getformatoption("pdf_level") or "1.3"
    --     local tmpname  = newname .. ".tmp"
    --     runprogram(pdftoeps.command, pdftoeps.argument, { oldname = oldname, newname = tmpname, presets = presets, level = level })
    --     runprogram(epstopdf.command, epstopdf.argument, { oldname = tmpname, newname = newname, presets = presets, level = level })
    --     os.remove(tmpname)
    -- end
    --
    -- figures.registersuffix("stripped","pdf")

end

do -- svg

    local svgconverter = converters.svg
    converters.svgz    = svgconverter

    -- inkscape on windows only works with complete paths .. did the command line arguments change again?

    programs.inkscape = {
        command  = "inkscape",
        pdfargument = longtostring [[
            "%oldname%"
            --export-dpi=600
            -A
            --export-pdf="%newname%"
        ]],
        pngargument = longtostring [[
            "%oldname%"
            --export-dpi=600
            --export-png="%newname%"
        ]],
    }

    function svgconverter.pdf(oldname,newname)
        local inkscape = programs.inkscape -- can be changed
        runprogram(inkscape.command, inkscape.pdfargument, {
            newname = expandfilename(newname),
            oldname = expandfilename(oldname),
        } )
    end

    function svgconverter.png(oldname,newname)
        local inkscape = programs.inkscape
        runprogram(inkscape.command, inkscape.pngargument, {
            newname = expandfilename(newname),
            oldname = expandfilename(oldname),
        } )
    end

    svgconverter.default = svgconverter.pdf

end

do -- gif | tif

    local gifconverter = converters.gif
    local tifconverter = converters.tif
    local bmpconverter = converters.bmp

    programs.convert = {
        command  = "gm", -- graphicmagick
        argument = [[convert "%oldname%" "%newname%"]],
    }

    local function converter(oldname,newname)
        local convert = programs.convert
        runprogram(convert.command, convert.argument, {
            newname = newname,
            oldname = oldname,
        } )
    end

    tifconverter.pdf = converter
    gifconverter.pdf = converter
    bmpconverter.pdf = converter

    gifconverter.default = converter
    tifconverter.default = converter
    bmpconverter.default = converter

end

do -- png | jpg | profiles

    -- ecirgb_v2.icc
    -- ecirgb_v2_iccv4.icc
    -- isocoated_v2_300_eci.icc
    -- isocoated_v2_eci.icc
    -- srgb.icc
    -- srgb_v4_icc_preference.icc

    -- [[convert %?colorspace: -colorspace "%colorspace%" ?%]]

    local rgbprofile  = "srgb_v4_icc_preference.icc" -- srgb.icc
    local cmykprofile = "isocoated_v2_300_eci.icc"   -- isocoated_v2_eci.icc

    directives.register("graphics.conversion.rgbprofile", function(v) rgbprofile  = type(v) == "string" and v or rgbprofile  end)
    directives.register("graphics.conversion.cmykprofile",function(v) cmykprofile = type(v) == "string" and v or cmykprofile end)

    local jpgconverters = converters.jpg
    local pngconverters = converters.png

    local function profiles()
        if not lfs.isfile(rgbprofile) then
            local found = resolvers.findfile(rgbprofile)
            if found and found ~= "" then
                rgbprofile = found
            else
                report_figures("unknown profile %a",rgbprofile)
            end
        end
        if not lfs.isfile(cmykprofile) then
            local found = resolvers.findfile(cmykprofile)
            if found and found ~= "" then
                cmykprofile = found
            else
                report_figures("unknown profile %a",cmykprofile)
            end
        end
        return rgbprofile, cmykprofile
    end

    programs.pngtocmykpdf = {
        command  = "gm",
        argument = [[convert -compress Zip  -strip +profile "*" -profile "%rgbprofile%" -profile "%cmykprofile%" -sampling-factor 1x1 "%oldname%" "%newname%"]],
    }

    programs.jpgtocmykpdf = {
        command  = "gm",
        argument = [[convert -compress JPEG -strip +profile "*" -profile "%rgbprofile%" -profile "%cmykprofile%" -sampling-factor 1x1 "%oldname%" "%newname%"]],
    }

    programs.pngtograypdf = {
        command  = "gm",
        argument = [[convert -colorspace gray -compress Zip -sampling-factor 1x1 "%oldname%" "%newname%"]],
    }

    programs.jpgtograypdf = {
        command  = "gm",
        argument = [[convert -colorspace gray -compress Zip -sampling-factor 1x1 "%oldname%" "%newname%"]],
    }

    pngconverters["cmyk.pdf"] = function(oldname,newname,resolution)
        local rgbprofile, cmykprofile = profiles()
        runprogram(programs.pngtocmykpdf.command, programs.pngtocmykpdf.argument, {
     -- runprogram(programs.pngtocmykpdf, {
            rgbprofile  = rgbprofile,
            cmykprofile = cmykprofile,
            oldname     = oldname,
            newname     = newname,
        } )
    end

    pngconverters["gray.pdf"] = function(oldname,newname,resolution)
        runprogram(programs.pngtograypdf.command, programs.pngtograypdf.argument, {
     -- runprogram(programs.pngtograypdf, {
            oldname = oldname,
            newname = newname,
        } )
    end

    jpgconverters["cmyk.pdf"] = function(oldname,newname,resolution)
        local rgbprofile, cmykprofile = profiles()
        runprogram(programs.jpgtocmykpdf.command, programs.jpgtocmykpdf.argument, {
     -- runprogram(programs.jpgtocmykpdf, {
            rgbprofile  = rgbprofile,
            cmykprofile = cmykprofile,
            oldname     = oldname,
            newname     = newname,
        } )
    end

    jpgconverters["gray.pdf"] = function(oldname,newname,resolution)
        runprogram(programs.jpgtograypdf.command, programs.jpgtograypdf.argument, {
     -- runprogram(programs.jpgtograypdf, {
            oldname = oldname,
            newname = newname,
        } )
    end

    -- recolor

    programs.recolor = {
        command  = "gm",
        argument = [[convert -recolor "%color%" "%oldname%" "%newname%"]],
    }

    pngconverters["recolor.png"] = function(oldname,newname,resolution,arguments)
        runprogram (
            programs.recolor.command,
            programs.recolor.argument,
            {
                oldname = oldname,
                newname = newname,
                color   = arguments or ".5 0 0 .7 0 0 .9 0 0",
            }
        )
    end

end
