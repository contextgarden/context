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
local scaninteger    = scanners.integer
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

scanners.pdfstartrotation = function()
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

scanners.pdfstartscaling = function() -- at the tex end we use sx and sy instead of rx and ry
    local rx, ry = 1, 1
    while true do
        if scankeyword("rx") then
            rx = scannumber()
        elseif scankeyword("ry") then
            ry = scannumber()
     -- elseif scankeyword("revert") then
     --     local top = stack[#stack]
     --     if top then
     --         rx = top[1]
     --         ry = top[4]
     --     else
     --         rx = 1
     --         ry = 1
     --     end
        else
            break
        end
    end
    if rx == 1 and ry == 1 then
        insert(stack,false)
    else
        if rx == 0 then
            rx = 0.0001
        end
        if ry == 0 then
            ry = 0.0001
        end
        context(pdfsave())
        context(pdfsetmatrix(rx,0,0,ry))
        insert(stack,restore and { 1/rx, 0, 0, 1/ry } or true)
    end
end

scanners.pdfstartmatrix = function() -- rx sx sy ry  -- tx, ty
    local rx, sx, sy, ry = 1, 0, 0, 1
    while true do
            if scankeyword("rx") then rx = scannumber()
        elseif scankeyword("ry") then ry = scannumber()
        elseif scankeyword("sx") then sx = scannumber()
        elseif scankeyword("sy") then sy = scannumber()
        else   break end
    end
    if rx == 1 and sx == 0 and sy == 0 and ry == 1 then
        insert(stack,false)
    else
        context(pdfsave())
        context(pdfsetmatrix(rx,sx,sy,ry))
        insert(stack,store and { -rx, -sx, -sy, -ry } or true)
    end
end

local function pdfstopsomething()
    local top = remove(stack)
    if top == false then
        -- not wrapped
    elseif top == true then
        context(pdfrestore())
    elseif top then
        context(pdfsetmatrix(unpack(top))) -- not really needed anymore
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
