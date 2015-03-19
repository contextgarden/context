if not modules then modules = { } end modules ['back-pdf'] = {
    version   = 1.001,
    comment   = "companion to back-pdf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}


local tonumber = tonumber
local sind, cosd = math.sind, math.cosd
local insert, remove = table.insert, table.remove
local codeinjections = backends.pdf.codeinjections

local context        = context
local outputfilename

function codeinjections.getoutputfilename()
    if not outputfilename then
        outputfilename = file.addsuffix(tex.jobname,"pdf")
    end
    return outputfilename
end

backends.install("pdf")

local f_matrix = string.formatters["%F %F %F %F"] -- 0.8 is default

function commands.pdfrotation(a)
    -- todo: check for 1 and 0 and flush sparse
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

function commands.pdfstartrotation(a)
    if a == 0 then
        insert(stack,false)
    else
        local s, c = sind(a), cosd(a)
        context(pdfsave())
        context(pdfsetmatrix(c,s,-s,c))
        insert(stack,restore and { c, -s, s, c } or true)
    end
end

function commands.pdfstartscaling(sx,sy)
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

function commands.pdfstartmatrix(sx,rx,ry,sy) -- tx, ty
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

commands.pdfstoprotation = pdfstopsomething
commands.pdfstopscaling  = pdfstopsomething
commands.pdfstopmatrix   = pdfstopsomething

function commands.pdfstartmirroring()
    context(pdfsetmatrix(-1,0,0,1))
end

commands.pdfstopmirroring = commands.pdfstartmirroring

-- todo : clipping
