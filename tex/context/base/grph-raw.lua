if not modules then modules = { } end modules ['grph-raw'] = {
    version   = 1.001,
    comment   = "companion to grph-raw.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module is for Mojca, who wanted something like this for
-- her gnuplot project. It's somewhat premliminary code but it
-- works ok for that purpose.

local tonumber = tonumber

local report_bitmap = logs.reporter("graphics","bitmaps")

local context = context
local texsp   = tex.sp

function figures.bitmapimage(t)
    local data        = t.data
    local xresolution = tonumber(t.xresolution)
    local yresolution = tonumber(t.yresolution)
    if data and xresolution and yresolution then
        local width, height = t.width or "", t.height or ""
        local n = backends.nodeinjections.injectbitmap {
            xresolution = xresolution,
            yresolution = yresolution,
            width       = width  ~= "" and texsp(width)  or nil,
            height      = height ~= "" and texsp(height) or nil,
            data        = data,
            colorspace  = t.colorspace,
        }
        if n then
            context.hbox(n)
        else
            report_bitmap("format no supported by backend")
        end
    else
        report_bitmap("invalid specification")
    end
end

interfaces.implement {
    name      = "bitmapimage",
    actions   = figures.bitmapimage,
    arguments = {
        {
            { "data" },
            { "colorspace" },
            { "width" },
            { "height" },
            { "xresolution" },
            { "yresolution" },
        }
    }
}
