if not modules then modules = { } end modules ['grph-inc'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local xpcall, pcall = xpcall, pcall

local bpfactor          = number.dimenfactors.bp

local report            = logs.reporter("graphics")
local report_inclusion  = logs.reporter("graphics","inclusion")
local report_bitmap     = logs.reporter("graphics","bitmap")
local report_pdf        = logs.reporter("graphics","pdf")

local trace_pdf         = false  trackers.register("graphics.pdf", function(v) trace_pdf = v end)

local checkers          = figures.checkers
local genericchecker    = checkers.generic

local placeholder       = graphics.bitmaps.placeholder

-- This is an experiment. The following method uses Lua to handle the embedding
-- using the epdf library. This feature will be used when we make the transition
-- from the pre 1.10 epdf library (using an unsuported low level poppler api) to a
-- new (lightweight, small and statically compiled) library. More on that later.
--
-- The method implemented below has the same performance as the hard coded inclusion
-- but opens up some possibilities (like merging fonts) that I will look into some
-- day.

function checkers.pdf(data)
    local request = data.request
    local used    = data.used
    if request and used and not request.scanimage then
        local image    = lpdf.epdf.image
        local openpdf  = image.open
        local closepdf = image.close
        local querypdf = image.query
        local copypage = image.copy
        local pdfdoc   = nil
        local filename = nil
        request.scanimage = function(t)
            if pdfdoc then
                if trace_pdf then
                    report_pdf("scan image %a",filename)
                end
                if not filename then
                    filename = pdfdoc.filename
                end
            else
                filename = t.filename
                if trace_pdf then
                    report_pdf("open and scan image %a",filename)
                end
                pdfdoc = openpdf(filename,request.userpassword,request.ownerpassword)
            end
            if pdfdoc then
                --
                local info = querypdf(pdfdoc,request.page,request.size)
                if info then
                    local bbox     = info and info.boundingbox or { 0, 0, 0, 0 }
                    local height   = bbox[4] - bbox[2]
                    local width    = bbox[3] - bbox[1]
                    local rotation = info.rotation or 0
                    if rotation == 90 then
                        rotation, height, width = 3, width, height
                    elseif rotation == 180 then
                        rotation = 2
                    elseif rotation == 270 then
                        rotation, height, width = 1, width, height
                    elseif rotation == 1 or rotation == 3 then
                        height, width = width, height
                    else
                        rotation = 0
                    end
                    return {
                        filename   = filename,
                     -- page       = 1,
                        pages      = pdfdoc.nofpages,
                        width      = width,
                        height     = height,
                        depth      = 0,
                        colordepth = 0,
                        xres       = 0,
                        yres       = 0,
                        xsize      = width,
                        ysize      = height,
                        rotation   = rotation,
                        pdfdoc     = pdfdoc,
                    }
                end
            end
        end
        request.copyimage = function(t)
            if not pdfdoc then
                pdfdoc = t.pdfdoc
            end
            if pdfdoc then
                local page   = request.page
                local copied = pdfdoc.nofcopied or 0
                if not pdfdoc.copied[page] then
                    pdfdoc.copied[page] = true
                    copied = copied + 1
                end
                pdfdoc.nofcopied = copied
                if trace_pdf then
                    report_pdf("copy page %i from image %a, %i pages copied",page,filename,copied)
                end
                local result = copypage(pdfdoc,page,nil,request.compact,request.width,request.height,request.attr)
                if pdfdoc.nofcopied >= pdfdoc.nofpages then
                    if trace_pdf then
                        report_pdf("closing image %a, %i pages copied",filename,copied)
                    end
                    closepdf(pdfdoc)
                    pdfdoc = nil
                    t.pdfdoc = nil
                end
                return result
            else
                -- message, should not happen as we always first scan so that reopens
            end
        end
    end
    return genericchecker(data)
end

local function wrappedidentify(identify,filename)
    local wrapup    = function() report_inclusion("fatal error reading %a",filename) end
    local _, result = xpcall(identify,wrapup,filename)
    if result then
        local xsize = result.xsize or 0
        local ysize = result.ysize or 0
        local xres  = result.xres or 0
        local yres  = result.yres or 0
        if xres == 0 or yres == 0 then
            xres = 300
            yres = 300
        end
        result.xsize       = xsize
        result.ysize       = ysize
        result.xres        = xres
        result.yres        = yres
        result.width       = result.width  or ((72/xres) * xsize / bpfactor)
        result.height      = result.height or ((72/yres) * ysize / bpfactor)
        result.depth       = result.depth  or 0
        result.filename    = filename
        result.colordepth  = result.colordepth or 0
        result.colorspace  = result.colorspace or 0
        result.rotation    = result.rotation or 0
        result.orientation = result.orientation or 0
        result.transform   = result.transform or 0
        return result
    else
        return { error = "fatal error" }
    end
end

function checkers.jpg(data)
    local request = data.request
    local used    = data.used
    if request and used and not request.scanimage then
        local identify = graphics.identify
        local inject   = lpdf.injectors.jpg
        local found    = false
        request.scanimage = function(t)
            local result = wrappedidentify(identify,t.filename)
            found = not result.error
            return {
                filename    = result.filename,
                width       = result.width,
                height      = result.height,
                depth       = result.depth,
                colordepth  = result.colordepth,
                xres        = result.xres,
                yres        = result.yres,
                xsize       = result.xsize,
                ysize       = result.ysize,
                colorspace  = result.colorspace,
                rotation    = result.rotation,
                orientation = result.orientation,
                transform   = result.transform,
            }
        end
        request.copyimage = function(t)
            if found then
                found = false
                return inject(t)
            end
        end
    end
    return genericchecker(data)
end

function checkers.jp2(data) -- idem as jpg
    local request = data.request
    local used    = data.used
    if request and used and not request.scanimage then
        local identify = graphics.identify
        local inject   = lpdf.injectors.jp2
        local found    = false
        request.scanimage = function(t)
            local result = wrappedidentify(identify,t.filename)
            found = not result.error
            return {
                filename    = result.filename,
                width       = result.width,
                height      = result.height,
                depth       = result.depth,
                colordepth  = result.colordepth,
                xres        = result.xres,
                yres        = result.yres,
                xsize       = result.xsize,
                ysize       = result.ysize,
                rotation    = result.rotation,
                colorspace  = result.colorspace,
                orientation = result.orientation,
                transform   = result.transform,
            }
        end
        request.copyimage = function(t)
            if found then
                found = false
                return inject(t)
            end
        end
    end
    return genericchecker(data)
end

function checkers.png(data) -- same as jpg (for now)
    local request = data.request
    local used    = data.used
    if request and used and not request.scanimage then
        local identify = graphics.identify
        local inject   = lpdf.injectors.png -- currently pdf specific
        local found    = false
        request.scanimage = function(t)
            local result = wrappedidentify(identify,t.filename)
            found = not result.error
            return {
                filename    = result.filename,
                width       = result.width,
                height      = result.height,
                depth       = result.depth,
                colordepth  = result.colordepth,
                xres        = result.xres,
                yres        = result.yres,
                xsize       = result.xsize,
                ysize       = result.ysize,
                rotation    = result.rotation,
                colorspace  = result.colorspace,
                tables      = result.tables,
                interlace   = result.interlace,
                filter      = result.filter,
                orientation = result.orientation,
                transform   = result.transform,
            }
        end
        request.copyimage = function(t)
            t.colorref = used.colorref -- this is a bit of a hack
            if found then
                found = false
                local ok, result = pcall(inject,t)
                if ok then
                    return result
                else
                    report_inclusion("bad bitmap image")
                    return placeholder()
                end
            end
        end
    end
    return genericchecker(data)
end
