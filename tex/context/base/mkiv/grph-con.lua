if not modules then modules = { } end modules ['grph-con'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, R, S, Cc, C, Cs, Ct, lpegmatch = lpeg.P, lpeg.R, lpeg.S, lpeg.Cc, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.match

local tonumber          = tonumber
local longtostring      = string.longtostring
local formatters        = string.formatters
local expandfilename    = dir.expandname
local isfile            = lfs.isfile

local settings_to_array = utilities.parsers.settings_to_array
local settings_to_hash  = utilities.parsers.settings_to_hash
local allocate          = utilities.storage.allocate
local setmetatableindex = table.setmetatableindex

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

do -- eps | ps

    -- \externalfigure[cow.eps]
    -- \externalfigure[cow.pdf][conversion=stripped]

    -- todo: colorspace
    -- todo: lowres

    local epsconverter = converters.eps
    converters.ps      = epsconverter

    local resolutions = {
        [v_low]    = "screen",
        [v_medium] = "ebook",
        [v_high]   = "prepress",
    }

    local runner = sandbox.registerrunner {
        name     = "eps to pdf",
        program  = {
            windows = os.platform == "win64" and "gswin64c" or "gswin32c",
            unix    = "gs",
        },
        template = longtostring [[
            -q
            -sDEVICE=pdfwrite
            -dNOPAUSE
            -dNOCACHE
            -dBATCH
            -dAutoRotatePages=/None
            -dPDFSETTINGS=/%presets%
            -dEPSCrop
            -dCompatibilityLevel=%level%
            -sOutputFile=%newname%
            %colorspace%
            %oldname%
            -c quit
        ]],
        checkers = {
            oldname    = "readable",
            newname    = "writable",
            presets    = "string",
            level      = "string",
            colorspace = "string",
        },
    }

    programs.epstopdf = { resolutions = epstopdf, runner = runner  }
    programs.gs       = programs.epstopdf

    local cleanups    = { }
    local cleaners    = { }

    local whitespace  = lpeg.patterns.whitespace
    local quadruple   = Ct((whitespace^0 * lpeg.patterns.number/tonumber * whitespace^0)^4)
    local betterbox   = P("%%BoundingBox:")      * quadruple
                      * P("%%HiResBoundingBox:") * quadruple
                      * P("%AI3_Cropmarks:")     * quadruple
                      * P("%%CropBox:")          * quadruple
                      / function(b,h,m,c)
                             return formatters["%%%%BoundingBox: %r %r %r %r\n%%%%HiResBoundingBox: %F %F %F %F\n%%%%CropBox: %F %F %F %F\n"](
                                 m[1],m[2],m[3],m[4], -- rounded integer
                                 m[1],m[2],m[3],m[4], -- real number
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
        local presets  = resolutions[resolution or "high"] or resolutions.high
        local level    = codeinjections.getformatoption("pdf_level") or "1.3"
        local tmpname  = oldname
        if not tmpname or tmpname == "" or not isfile(tmpname) then
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
        runner {
            newname    = newname,
            oldname    = tmpname,
            presets    = presets,
            level      = tostring(level),
            colorspace = colorspace,
        }
        if tmpname ~= oldname then
            os.remove(tmpname)
        end
    end

    epsconverter["gray.pdf"] = function(oldname,newname,resolution) -- the resolution interface might change
        epsconverter.pdf(oldname,newname,resolution,"gray")
    end

    epsconverter.default = epsconverter.pdf

end

-- do -- pdf
--
--     local pdfconverter = converters.pdf
--
--     programs.pdftoeps = {
--         runner = sandbox.registerrunner {
--             name     = "pdf to ps",
--             command  = "pdftops",
--             template = [[-eps "%oldname%" "%newname%"]],
--             checkers = {
--                 oldname = "readable",
--                 newname = "writable",
--             }
--         }
--     }
--
--     pdfconverter.stripped = function(oldname,newname)
--         local pdftoeps = programs.pdftoeps -- can be changed
--         local epstopdf = programs.epstopdf -- can be changed
--         local presets  = epstopdf.resolutions[resolution or ""] or epstopdf.resolutions.high
--         local level    = codeinjections.getformatoption("pdf_level") or "1.3"
--         local tmpname  = newname .. ".tmp"
--         pdftoeps.runner { oldname = oldname, newname = tmpname, presets = presets, level = level }
--         epstopdf.runner { oldname = tmpname, newname = newname, presets = presets, level = level }
--         os.remove(tmpname)
--     end
--
--     figures.registersuffix("stripped","pdf")
--
-- end

do -- svg

    local svgconverter = converters.svg
    converters.svgz    = svgconverter

    -- inkscape on windows only works with complete paths .. did the command line
    -- arguments change again? Ok, it's weirder, with -A then it's a name only when
    -- not . (current)

    local runner = sandbox.registerrunner {
        name     = "svg to something",
        program  = "inkscape",
        template = longtostring [[
            %oldname%
            --export-dpi=%resolution%
            --export-%format%=%newname%
        ]],
        checkers = {
            oldname    = "readable",
            newname    = "writable",
            format     = "string",
            resolution = "string",
        },
        defaults = {
            format     = "pdf",
            resolution = "600",
        }
    }

    programs.inkscape = {
        runner = runner,
    }

    function svgconverter.pdf(oldname,newname)
        runner {
            format     = "pdf",
            resolution = "600",
            newname    = expandfilename(newname),
            oldname    = expandfilename(oldname),
        }
    end

    function svgconverter.png(oldname,newname)
        runner {
            format     = "png",
            resolution = "600",
            newname    = expandfilename(newname),
            oldname    = expandfilename(oldname),
        }
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
        if not isfile(rgbprofile) then
            local found = resolvers.findfile(rgbprofile)
            if found and found ~= "" then
                rgbprofile = found
            else
                report_figures("unknown profile %a",rgbprofile)
            end
        end
        if not isfile(cmykprofile) then
            local found = resolvers.findfile(cmykprofile)
            if found and found ~= "" then
                cmykprofile = found
            else
                report_figures("unknown profile %a",cmykprofile)
            end
        end
        return rgbprofile, cmykprofile
    end

    local checkers = {
        oldname     = "readable",
        newname     = "writable",
        rgbprofile  = "string",
        cmykprofile = "string",
        resolution  = "string",
        color       = "string",
    }

    local defaults = {
        resolution = "600",
    }

    local pngtocmykpdf = sandbox.registerrunner {
        name     = "png to cmyk pdf",
        program  = "gm",
        template = [[convert -compress Zip  -strip +profile "*" -profile %rgbprofile% -profile %cmykprofile% -sampling-factor 1x1 %oldname% %newname%]],
        checkers = checkers,
        defaults = defaults,
    }

    local jpgtocmykpdf = sandbox.registerrunner {
        name     = "jpg to cmyk pdf",
        program  = "gm",
        template = [[convert -compress JPEG -strip +profile "*" -profile %rgbprofile% -profile %cmykprofile% -sampling-factor 1x1 %oldname% %newname%]],
        checkers = checkers,
        defaults = defaults,
    }

    local pngtograypdf = sandbox.registerrunner {
        name     = "png to gray pdf",
        program  = "gm",
        template = [[convert -colorspace gray -compress Zip -sampling-factor 1x1 %oldname% %newname%]],
        checkers = checkers,
        defaults = defaults,
    }

    local jpgtograypdf = sandbox.registerrunner {
        name     = "jpg to gray pdf",
        program  = "gm",
        template = [[convert -colorspace gray -compress Zip -sampling-factor 1x1 %oldname% %newname%]],
        checkers = checkers,
        defaults = defaults,
    }

    programs.pngtocmykpdf = { runner = pngtocmykpdf }
    programs.jpgtocmykpdf = { runner = jpgtocmykpdf }
    programs.pngtograypdf = { runner = pngtograypdf }
    programs.jpgtograypdf = { runner = jpgtograypdf }

    pngconverters["cmyk.pdf"] = function(oldname,newname,resolution)
        local rgbprofile, cmykprofile = profiles()
        pngtocmykpdf {
            oldname     = oldname,
            newname     = newname,
            rgbprofile  = rgbprofile,
            cmykprofile = cmykprofile,
            resolution  = resolution,
        }
    end

    pngconverters["gray.pdf"] = function(oldname,newname,resolution)
        pngtograypdf {
            oldname    = oldname,
            newname    = newname,
            resolution = resolution,
        }
    end

    jpgconverters["cmyk.pdf"] = function(oldname,newname,resolution)
        local rgbprofile, cmykprofile = profiles()
        jpgtocmykpdf {
            oldname     = oldname,
            newname     = newname,
            rgbprofile  = rgbprofile,
            cmykprofile = cmykprofile,
            resolution  = resolution,
        }
    end

    jpgconverters["gray.pdf"] = function(oldname,newname,resolution)
        jpgtograypdf {
            oldname    = oldname,
            newname    = newname,
            resolution = resolution,
        }
    end

    -- recolor

    local recolorpng = sandbox.registerrunner {
        name     = "recolor png",
        program  = "gm",
        template = [[convert -recolor %color% %oldname% %newname%]],
        checkers = checkers,
        defaults = defaults,
    }

    -- this is now built in so not really needed any more

    programs.recolor = { runner = recolorpng }

    pngconverters["recolor.png"] = function(oldname,newname,resolution,arguments)
        recolorpng {
            oldname    = oldname,
            newname    = newname,
            resolution = resolution,
            color      = arguments or ".5 0 0 .7 0 0 .9 0 0",
        }
    end

end

if CONTEXTLMTXMODE > 0 then

    -- This might also work ok in mkiv but is yet untested. Anyway, it's experimental as we
    -- go through TeX which is is inefficient. I'll improve the buffer trick.

    local function remap(specification)
        local fullname = specification.fullname
        if fullname then
            local only = file.nameonly(fullname)
            local name = formatters["svg-%s-inclusion"](only)
            local code = formatters["\\includesvgfile[%s]\\resetbuffer[%s]"](fullname,name)
            buffers.assign(name,code)
            specification.format   = "buffer"
            specification.fullname = name
        end
        return specification
    end

    figures.remappers.svg = { mp = remap }

end
