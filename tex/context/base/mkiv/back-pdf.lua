if not modules then modules = { } end modules ['back-pdf'] = {
    version   = 1.001,
    comment   = "companion to back-pdf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we could do \pdfmatrix sx <> sy <> etc

local sind, cosd = math.sind, math.cosd
local insert, remove = table.insert, table.remove

local codeinjections = backends.pdf.codeinjections

local context        = context

local scanners       = tokens.scanners
local scannumber     = scanners.number
local scankeyword    = scanners.keyword
local scandimen      = scanners.dimen
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

if environment.arguments.nocompression then
    lpdf.setcompression(0,0,true)
end

scanners.pdfstopmirroring = scanners.pdfstartmirroring

-- todo, change the above to implement too --

implement {
    name      = "setmapfile",
    arguments = "string",
    actions   = pdf.mapfile
}

implement {
    name      = "setmapline",
    arguments = "string",
    actions   = pdf.mapline
}

implement {
    name      = "setpdfcompression",
    arguments = { "integer", "integer" },
    actions   = lpdf.setcompression,
}

local report = logs.reporter("backend","pdftex primitives")
local trace  = false

scanners.pdfannot = function()
    if scankeyword("reserveobjectnum") then
        report("\\pdfannot reserveobjectnum is not (yet) supported")
     -- if trace then
     --     report()
     --     report("\\pdfannot: reserved number (not supported yet)")
     --     report()
     -- end
    else
        local width  = false
        local height = false
        local depth  = false
        local data   = false
        local object = false
        local attr   = false
        --
        if scankeyword("useobjnum") then
            object = scancount()
            report("\\pdfannot useobjectnum is not (yet) supported")
        end
        while true do
            if scankeyword("width") then
                width = scandimen()
            elseif scankeyword("height") then
                height = scandimen()
            elseif scankeyword("depth") then
                depth = scandimen()
            else
                break
            end
        end
        if scankeyword("attr") then
            attr = scanstring()
        end
        data = scanstring()
        --
        -- less strict variant:
        --
     -- while true do
     --     if scankeyword("width") then
     --         width = scandimen()
     --     elseif scankeyword("height") then
     --         height = scandimen()
     --      elseif scankeyword("depth") then
     --         depth = scandimen()
     --     elseif scankeyword("useobjnum") then
     --         object = scancount()
     --     elseif scankeyword("attr") then
     --         attr = scanstring()
     --     else
     --         data = scanstring()
     --         break
     --     end
     -- end
        --
     -- if trace then
     --     report()
     --     report("\\pdfannot:")
     --     report()
     --     report("  object: %s",object or "<unset> (not supported yet)")
     --     report("  width : %p",width  or "<unset>")
     --     report("  height: %p",height or "<unset>")
     --     report("  depth : %p",depth  or "<unset>")
     --     report("  attr  : %s",attr   or "<unset>")
     --     report("  data  : %s",data   or "<unset>")
     --     report()
     -- end
        context(backends.nodeinjections.annotation(width or 0,height or 0,depth or 0,data or ""))
    end
end

scanners.pdfdest = function()
    local name   = false
    local zoom   = false
    local view   = false
    local width  = false
    local height = false
    local depth  = false
    if scankeyword("num") then
        report("\\pdfdest num is not (yet) supported")
    elseif scankeyword("name") then
        name = scanstring()
    end
    if scankeyword("xyz") then
        view = "xyz"
        if scankeyword("zoom") then
            report("\\pdfdest zoom is ignored")
            zoom = scancount() -- will be divided by 1000 in the backend
        end
    elseif scankeyword("fitbh") then
        view = "fitbh"
    elseif scankeyword("fitbv") then
        view = "fitbv"
    elseif scankeyword("fitb") then
        view = "fitb"
    elseif scankeyword("fith") then
        view = "fith"
    elseif scankeyword("fitv") then
        view = "fitv"
    elseif scankeyword("fitr") then
        view = "fitr"
        while true do
            if scankeyword("width") then
                width = scandimen()
            elseif scankeyword("height") then
                height = scandimen()
            elseif scankeyword("depth") then
                depth = scandimen()
            else
                break
            end
        end
    elseif scankeyword("fit") then
        view = "fit"
    end
 -- if trace then
 --     report()
 --     report("\\pdfdest:")
 --     report()
 --     report("  name  : %s",name   or "<unset>")
 --     report("  view  : %s",view   or "<unset>")
 --     report("  zoom  : %s",zoom   or "<unset> (not supported)")
 --     report("  width : %p",width  or "<unset>")
 --     report("  height: %p",height or "<unset>")
 --     report("  depth : %p",depth  or "<unset>")
 --     report()
 -- end
    context(backends.nodeinjections.destination(width or 0,height or 0,depth or 0,{ name or "" },view or "fit"))
end
