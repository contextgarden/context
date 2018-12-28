if not modules then modules = { } end modules ['back-pdf'] = {
    version   = 1.001,
    comment   = "companion to back-pdf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we could do \pdfmatrix sx <> sy <> etc

local sind, cosd, abs = math.sind, math.cosd, math.abs
local insert, remove = table.insert, table.remove

local codeinjections = backends.pdf.codeinjections

local context        = context

local scanners       = tokens.scanners
local scannumber     = scanners.number
local scankeyword    = scanners.keyword
local scancount      = scanners.count
local scanstring     = scanners.string

local scanners       = interfaces.scanners
local implement      = interfaces.implement

local report         = logs.reporter("backend")

local outputfilename

function codeinjections.getoutputfilename()
    if not outputfilename then
        outputfilename = file.addsuffix(tex.jobname,"pdf")
    end
    return outputfilename
end

backends.install("pdf")

-- local f_matrix = string.formatters["%F %F %F %F"] -- 0.8 is default
--
-- scanners.pdfrotation = function() -- a
--     -- todo: check for 1 and 0 and flush sparse
--     local a = scannumber()
--     local s, c = sind(a), cosd(a)
--     context(f_matrix(c,s,-s,c))
-- end

-- experimental code (somewhat weird here) .. todo: nodeinjections .. this will only work
-- out well if we also calculate the accumulated cm and wrap inclusions / annotations in
-- the accumulated ... it's a mess
--
-- we could also do the save restore wrapping here + colorhack

local nodepool     = nodes.pool
local pdfsave      = nodepool.pdfsave
local pdfrestore   = nodepool.pdfrestore
local pdfsetmatrix = nodepool.pdfsetmatrix

local stack        = { }
local restore      = true -- false

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

local function pdfstartrotation()
    local a = scannumber()
    if a == 0 then
        insert(stack,false)
    else
        local s, c = sind(a), cosd(a)
        if abs(s) < 0.000001 then
            s = 0 -- otherwise funny -0.00000
        end
        if abs(c) < 0.000001 then
            c = 0 -- otherwise funny -0.00000
        end
        context(pdfsave())
        context(pdfsetmatrix(c,s,-s,c))
        insert(stack,restore and { c, -s, s, c } or true)
    end
end

implement { name = "pdfstartrotation", actions = pdfstartrotation }
implement { name = "pdfstoprotation",  actions = pdfstopsomething }

local function pdfstartscaling() -- at the tex end we use sx and sy instead of rx and ry
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

implement { name = "pdfstartscaling", actions = pdfstartscaling }
implement { name = "pdfstopscaling",  actions = pdfstopsomething }

local function pdfstartmatrix() -- rx sx sy ry  -- tx, ty
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

implement { name = "pdfstartmatrix", actions = pdfstartmatrix }
implement { name = "pdfstopmatrix",  actions = pdfstopsomething }

local function pdfstartmirroring()
    context(pdfsetmatrix(-1,0,0,1))
end

implement { name = "pdfstartmirroring", actions = pdfstartmirroring }
implement { name = "pdfstopmirroring",  actions = pdfstartmirroring } -- not: pdfstopsomething

if environment.arguments.nocompression then
    lpdf.setcompression(0,0,true)
end

-- todo:

implement {
    name      = "setmapfile",
    arguments = "string",
    actions   = lpdf.setmapfile
}

implement {
    name      = "setmapline",
    arguments = "string",
    actions   = lpdf.setmapline
}

implement {
    name      = "setpdfcompression",
    arguments = { "integer", "integer" },
    actions   = lpdf.setcompression,
}

