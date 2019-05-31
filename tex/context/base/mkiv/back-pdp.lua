if not modules then modules = { } end modules ['back-pdp'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is temporary ... awaiting a better test .. basically we can
-- always use this: pdf primitives.

local context           = context
local lpdf              = lpdf

local lpdfreserveobject = lpdf.reserveobject
local lpdfcompresslevel = lpdf.compresslevel
local lpdfobj           = lpdf.obj
local lpdfpagereference = lpdf.pagereference
local lpdfxformname     = lpdf.xformname

local tokenscanners     = tokens.scanners
local scanword          = tokenscanners.word
local scankeyword       = tokenscanners.keyword
local scanstring        = tokenscanners.string
local scaninteger       = tokenscanners.integer
local scanwhd           = tokenscanners.whd

local trace             = false  trackers.register("backend", function(v) trace = v end)
local report            = logs.reporter("backend")

local nodepool          = nodes.pool
local newliteral        = nodepool.literal
local newsave           = nodepool.save
local newrestore        = nodepool.restore
local newsetmatrix      = nodepool.setmatrix

local implement         = interfaces.implement
local constants         = interfaces.constants
local variables         = interfaces.variables

-- literals

local function pdfliteral()
    context(newliteral(scanword() or "origin",scanstring()))
end

-- objects

local lastobjnum = 0

local function pdfobj()
    if scankeyword("reserveobjnum") then
        lastobjnum = lpdfreserveobject()
        if trace then
            report("\\pdfobj reserveobjnum: object %i",lastobjnum)
        end
    else
        local immediate    = true
        local objnum       = scankeyword("useobjnum") and scaninteger() or lpdfreserveobject()
        local uncompress   = scankeyword("uncompressed") or lpdfcompresslevel() == 0
        local streamobject = scankeyword("stream")
        local attributes   = scankeyword("attr") and scanstring() or nil
        local fileobject   = scankeyword("file")
        local content      = scanstring()
        local object = streamobject and {
            type          = "stream",
            objnum        = objnum,
            immediate     = immediate,
            attr          = attributes,
            compresslevel = uncompress and 0 or nil,
        } or {
            type          = "raw",
            objnum        = objnum,
            immediate     = immediate,
        }
        if fileobject then
            object.filename = content
        else
            object.string = content
        end
        lpdfobj(object)
        lastobjnum = objnum
        if trace then
            report("\\pdfobj: object %i",lastobjnum)
        end
    end
end

local function pdflastobj()
    context("%i",lastobjnum)
    if trace then
        report("\\lastobj: object %i",lastobjnum)
    end
end

local function pdfrefobj()
    local objnum = scaninteger()
    if trace then
        report("\\refobj: object %i (todo)",objnum)
    end
end

-- annotations

local lastobjnum = 0

local function pdfannot()
    if scankeyword("reserveobjnum") then
        lastobjnum = lpdfreserveobject()
        if trace then
            report("\\pdfannot reserveobjnum: object %i",lastobjnum)
        end
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
        local width, height, depth = scanwhd()
        if scankeyword("attr") then
            attr = scanstring()
        end
        data = scanstring()
        context(backends.nodeinjections.annotation(width or 0,height or 0,depth or 0,data or ""))
    end
end

local function pdfdest()
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
        width, height, depth = scanwhd()
    elseif scankeyword("fit") then
        view = "fit"
    end
    context(backends.nodeinjections.destination(width or 0,height or 0,depth or 0,{ name or "" },view or "fit"))
end

-- management

local function pdfsave()
    context(newsave())
end

local function pdfrestore()
    context(newrestore())
end

local function pdfsetmatrix()
    context(newsetmatrix(scanstring()))
end

-- extras

local function pdfpageref()
    context(lpdfpagereference())
end

local function pdfxformname()
    context(lpdfxformname())
end

-- extensions: literal dest annot save restore setmatrix obj refobj colorstack
-- startlink endlink startthread endthread thread outline glyphtounicode fontattr
-- mapfile mapline includechars catalog info names trailer

local extensions = {
    literal   = pdfliteral,
    obj       = pdfobj,
    refobj    = pdfrefobj,
    dest      = pdfdest,
    annot     = pdfannot,
    save      = pdfsave,
    restore   = pdfrestore,
    setmatrix = pdfsetmatrix,
}

local function pdfextension()
    local w = scanword()
    if w then
        local e = extensions[w]
        if e then
            e()
        else
            report("\\pdfextension: unknown %a",w)
        end
    end
end

-- feedbacks: colorstackinit creationdate fontname fontobjnum fontsize lastannot
-- lastlink lastobj pageref retval revision version xformname

local feedbacks = {
    lastobj    = pdflastobj,
    pageref    = pdfpageref,
    xformname  = pdfxformname,
}

local function pdffeedback()
    local w = scanword()
    if w then
        local f = feedbacks[w]
        if f then
            f()
        else
            report("\\pdffeedback: unknown %a",w)
        end
    end
end

-- variables: (integers:) compresslevel decimaldigits gamma gentounicode
-- ignoreunknownimages imageaddfilename imageapplygamma imagegamma imagehicolor
-- imageresolution inclusioncopyfonts inclusionerrorlevel majorversion minorversion
-- objcompresslevel omitcharset omitcidset pagebox pkfixeddpi pkresolution
-- recompress suppressoptionalinfo uniqueresname (dimensions:) destmargin horigin
-- linkmargin threadmargin vorigin xformmargin (tokenlists:) pageattr pageresources
-- pagesattr pkmode trailerid xformattr xformresources

-- local variables = {
-- }
--
-- local function pdfvariable()
--     local w = scanword()
--     if w then
--         local f = variables[w]
--         if f then
--             f()
--         else
--             print("invalid variable",w)
--         end
--     else
--         print("missing variable")
--     end
-- end

-- kept:

implement { name = "pdfextension", actions = pdfextension }
implement { name = "pdffeedback",  actions = pdffeedback }
--------- { name = "pdfvariable",  actions = pdfvariable }

-- for the moment (tikz)

implement { name = "pdfliteral", actions = pdfliteral }
implement { name = "pdfobj",     actions = pdfobj }
implement { name = "pdflastobj", actions = pdflastobj }
implement { name = "pdfrefobj",  actions = pdfrefobj }
--------- { name = "pdfannot",   actions = pdfannot }
--------- { name = "pdfdest",    actions = pdfdest }
