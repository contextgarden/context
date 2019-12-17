if not modules then modules = { } end modules ['grph-bmp'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local random        = math.random
local context       = context

local report_bitmap = logs.reporter("graphics","bitmap")

local bitmaps       = { }
graphics.bitmaps    = bitmaps

local wrapimage     = images.wrap

function bitmaps.new(xsize,ysize,colorspace,colordepth,mask,index)
    if not xsize or not ysize or xsize == 0 or ysize == 0 then
        report_bitmap("provide 'xsize' and 'ysize' larger than zero")
        return
    end
    if not colorspace then
        report_bitmap("provide 'colorspace' (1, 2, 3, 'gray', 'rgb', 'cmyk'")
        return
    end
    if not colordepth then
        report_bitmap("provide 'colordepth' (1, 2)")
        return
    end
    return graphics.identifiers.bitmap {
        colorspace = colorspace,
        colordepth = colordepth,
        xsize      = xsize,
        ysize      = ysize,
        mask       = mask and true or nil,
        index      = index and true or nil,
    }
end

-- function backends.codeinjections.bitmap(bitmap)
--     return lpdf.injectors.bitmap(bitmap)
-- end

local function flush(bitmap)
    local specification = backends.codeinjections.bitmap(bitmap)
    if specification then
        return wrapimage(specification)
    end
end

bitmaps.flush = flush

function bitmaps.tocontext(bitmap,width,height)
    local bmp = flush(bitmap)
    if bmp then
        if type(width) == "number" then
            width = width .. "sp"
        end
        if type(height) == "number" then
            height = height .. "sp"
        end
        if width or height then
            context.scale (
                {
                    width  = width,
                    height = height,
                },
                bmp
            )
        else
            context(bmp)
        end
    end
end

local function placeholder(nx,ny)

    local nx     = nx or 8
    local ny     = ny or nx
    local bitmap = bitmaps.new(nx,ny,"gray",1)
    local data   = bitmap.data

    for i=1,ny do
        local d = data[i]
        for j=1,nx do
            d[j] = random(100,199)
        end
    end

    return lpdf.injectors.bitmap(bitmap)

end

bitmaps.placeholder = placeholder
