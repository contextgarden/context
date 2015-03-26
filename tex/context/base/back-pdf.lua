if not modules then modules = { } end modules ['back-pdf'] = {
    version   = 1.001,
    comment   = "companion to back-pdf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we could do \pdfmatrix sx <> sy <> etc

local tonumber = tonumber
local sind, cosd = math.sind, math.cosd
local insert, remove = table.insert, table.remove

local codeinjections = backends.pdf.codeinjections

local context        = context

local scanners       = tokens.scanners
local scanstring     = scanners.string
local scannumber     = scanners.number
local scankeyword    = scanners.keyword

local scanners       = interfaces.scanners

local outputfilename

function codeinjections.getoutputfilename()
    if not outputfilename then
        outputfilename = file.addsuffix(tex.jobname,"pdf")
    end
    return outputfilename
end

backends.install("pdf")

local f_matrix = string.formatters["%F %F %F %F"] -- 0.8 is default

scanners.pdfrotation = function() -- a
    -- todo: check for 1 and 0 and flush sparse
    local a = scannumber()
    local s, c = sind(a), cosd(a)
    context(f_matrix(c,s,-s,c))
end

-- experimental code (somewhat weird here) .. todo: nodeinjections .. this will only work
-- out well if we also calculate the accumulated cm and wrap inclusions / annotations in
-- the accumulated ... it's a mess
--
-- we could also do the save restore wrapping here + colorhack

local pdfsave      = nodes.pool.pdfsave
local pdfrestore   = nodes.pool.pdfrestore
local pdfsetmatrix = nodes.pool.pdfsetmatrix

local stack        = { }
local restore      = true -- false

scanners.pdfstartrotation = function() -- a
    local a = scannumber()
    if a == 0 then
        insert(stack,false)
    else
        local s, c = sind(a), cosd(a)
        context(pdfsave())
        context(pdfsetmatrix(c,s,-s,c))
        insert(stack,restore and { c, -s, s, c } or true)
    end
end

scanners.pdfstartscaling = function() --  sx sy
    local sx, sy = 0, 0
    while true do
        if scankeyword("sx") then
            sx = scannumber()
        elseif scankeyword("sy") then
            sy = scannumber()
        else
            break
        end
    end
    if sx == 1 and sy == 1 then
        insert(stack,false)
    else
        if sx == 0 then
            sx = 0.0001
        end
        if sy == 0 then
            sy = 0.0001
        end
        context(pdfsave())
        context(pdfsetmatrix(sx,0,0,sy))
        insert(stack,restore and { 1/sx, 0, 0, 1/sy } or true)
    end
end

scanners.pdfstartmatrix = function() -- sx rx ry sy  -- tx, ty
    local sx, rx, ry, sy = 0, 0, 0, 0
    while true do
        if scankeyword("sx") then
            sx = scannumber()
        elseif scankeyword("sy") then
            sy = scannumber()
        elseif scankeyword("rx") then
            rx = scannumber()
        elseif scankeyword("ry") then
            ry = scannumber()
        else
            break
        end
    end
    if sx == 1 and rx == 0 and ry == 0 and sy == 1 then
        insert(stack,false)
    else
        context(pdfsave())
        context(pdfsetmatrix(sx,rx,ry,sy))
        insert(stack,store and { -sx, -rx, -ry, -sy } or true)
    end
end

local function pdfstopsomething()
    local top = remove(stack)
    if top == false then
        -- not wrapped
    elseif top == true then
        context(pdfrestore())
    elseif top then
        context(pdfsetmatrix(unpack(top)))
        context(pdfrestore())
    else
        -- nesting error
    end
end

scanners.pdfstoprotation = pdfstopsomething
scanners.pdfstopscaling  = pdfstopsomething
scanners.pdfstopmatrix   = pdfstopsomething

scanners.pdfstartmirroring = function()
    context(pdfsetmatrix(-1,0,0,1))
end

scanners.pdfstopmirroring = scanners.pdfstartmirroring

-- todo : clipping
