if not modules then modules = { } end modules ['grph-wnd'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Thanks to Luigi Scarso for making graphic magic work in luatex.
--
-- \externalfigure[hacker.jpeg][width=4cm,conversion=gray.jpg]

local converters, suffixes = figures.converters, figures.suffixes

local trace_conversion = false  trackers.register("figures.conversion", function(v) trace_conversion = v end)

local report_wand = logs.reporter("graphics","wand")

local function togray(oldname,newname)
    if lfs.isfile(oldname) then
        require("gmwand")
        if trace_conversion then
            report_wand("converting %a to %a using gmwand",oldname,newname)
        end
        gmwand.InitializeMagick("./") -- What does this path do?
        local wand = gmwand.NewMagickWand()
        gmwand.MagickReadImage(wand,oldname)
        gmwand.MagickSetImageColorspace(wand,gmwand.GRAYColorspace)
        gmwand.MagickWriteImages(wand,newname,1)
        gmwand.DestroyMagickWand(wand)
    else
        report_wand("unable to convert %a to %a using gmwand",oldname,newname)
    end
end

local formats = { "png", "jpg", "gif" }

for i=1,#formats do
    local oldformat = formats[i]
    local newformat = "gray." .. oldformat
    if trace_conversion then
        report_wand("installing converter for %a to %a",oldformat,newformat)
    end
    converters[oldformat]            = converters[oldformat] or { }
    converters[oldformat][newformat] = togray
    suffixes  [newformat]            = oldformat
end
