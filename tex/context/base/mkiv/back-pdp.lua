if not modules then modules = { } end modules ['back-pdp'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is temporary ... awaiting a better test .. basically we can
-- always use this: pdf primitives.

local context          = context

local lpdfreserveobject = lpdf.reserveobject
local lpdfcompresslevel = lpdf.compresslevel
local lpdfobj           = lpdf.obj
local lpdfpagereference = lpdf.pagereference
local lpdfxformname     = lpdf.xformname

local jobpositions      = job.positions
local gethpos           = jobpositions.gethpos
local getvpos           = jobpositions.getvpos

local tokenscanners     = tokens.scanners
local scanword          = tokenscanners.word
local scankeyword       = tokenscanners.keyword
local scanstring        = tokenscanners.string
local scaninteger       = tokenscanners.integer
local scandimension     = tokenscanners.dimension

local trace             = false  trackers.register("commands", function(v) trace = v end)
local report            = logs.reporter("command")

local nodepool          = nodes.pool
local newsavepos        = nodepool.savepos
local newliteral        = nodepool.literal
local newsave           = nodepool.save
local newrestore        = nodepool.restore
local newsetmatrix      = nodepool.setmatrix

local implement         = interfaces.implement
local constants         = interfaces.constants
local variables         = interfaces.variables

-- helper

local function scanwhd()
    local width, height, depth
    while true do
        if scankeyword("width") then
            width = scandimension()
        elseif scankeyword("height") then
            height = scandimension()
        elseif scankeyword("depth") then
            depth = scandimension()
        else
            break
        end
    end
    if width or height or depth then
        return width or 0, height or 0, depth or 0
    else
        -- we inherit
    end
end

-- positions

local function savepos()
    context(newsavepos())
end

local function lastxpos()
    context(gethpos())
end

local function lastypos()
    context(getvpos())
end

implement { name = "savepos",  actions = savepos }
implement { name = "lastxpos", actions = lastxpos }
implement { name = "lastypos", actions = lastypos }

-- literals

local function pdfliteral()
    context(newliteral(scanword() or "origin",scanstring()))
end

implement { name = "pdfliteral", actions = pdfliteral }

-- box resources

local boxresources = tex.boxresources
local savebox      = boxresources.save
local usebox       = boxresources.use

local lastindex    = 0

local function saveboxresource()
    local immediate  = true
    local kind       = scankeyword("type") and scaninteger() or 0
    local attributes = scankeyword("attr") and scanstring() or nil
    local resources  = scankeyword("resources") and scanstring() or nil
    local margin     = scankeyword("margin") and scandimension() or 0 -- register
    local boxnumber  = scaninteger()
    --
    lastindex = savebox(boxnumber,attributes,resources,immediate,kind,margin)
    if trace then
        report("\\saveboxresource: index %i",lastindex)
    end
end

local function lastsavedboxresourceindex()
    if trace then
        report("\\lastsaveboxresource: index %i",lastindex)
    end
    context("%i",lastindex)
end

local function useboxresource()
    local width, height, depth = scanwhd()
    local index = scaninteger()
    local node  = usebox(index,width,height,depth)
    if trace then
        report("\\useboxresource: index %i",index)
    end
    context(node)
end

implement { name = "saveboxresource",           actions = saveboxresource }
implement { name = "lastsavedboxresourceindex", actions = lastsavedboxresourceindex }
implement { name = "useboxresource",            actions = useboxresource }

-- image resources (messy: will move)

local imageresources = { }
local lastindex      = 0
local lastpages      = 1

local function saveimageresource()
    local width, height, depth = scanwhd()
    local page       = 1
    local immediate  = true
    local margin     = 0 -- or dimension
    local attributes = scankeyword("attr") and scanstring() or nil
    if scankeyword("named") then
        scanstring() -- ignored
    elseif scankeyword("page") then
        page = scaninteger()
    end
    local userpassword    = scankeyword("userpassword") and scanstring() or nil
    local ownerpassword   = scankeyword("ownerpassword") and scanstring() or nil
    local visiblefilename = scankeyword("visiblefilename") and scanstring() or nil
    local colorspace      = scankeyword("colorspace") and scaninteger() or nil
    local pagebox         = scanword() or nil
    local filename        = scanstring()
-- pcall
    context.getfiguredimensions( { filename }, {
        [constants.userpassword]  = userpassword,
        [constants.ownerpassword] = ownerpassword,
        [constants.page]          = page or 1,
        [constants.size]          = pagebox,
    })
    context.relax()
    lastindex = lastindex + 1
    lastpages = 1
    imageresources[lastindex] = {
        filename = filename,
        page     = page or 1,
        size     = pagebox,
        width    = width,
        height   = height,
        depth    = depth,
        attr     = attributes,
     -- margin   = margin,
     }
end

local function lastsavedimageresourceindex()
    context("%i",lastindex or 0)
end

local function lastsavedimageresourcepages()
    context("%i",lastpages or 0) -- todo
end

local function useimageresource()
    local width, height, depth = scanwhd()
    if scankeyword("keepopen") then
        -- ignored
    end
    local index = scaninteger()
    local l = imageresources[index]
    if l then
        if not (width or height or depth) then
            width  = l.width
            height = l.height
            depth  = l.depth
        end
-- pcall
        context.externalfigure( { l.filename }, {
            [constants.userpassword]  = l.userpassword,
            [constants.ownerpassword] = l.ownerpassword,
            [constants.width]         = width and (width .. "sp") or nil,
            [constants.height]        = height and (height .. "sp") or nil,
            [constants.page]          = l.page or 1,
            [constants.size]          = pagebox,
        })
        context.relax()
    else
        print("no image resource",index)
    end
end

implement { name = "saveimageresource",           actions = saveimageresource }
implement { name = "lastsavedimageresourceindex", actions = lastsavedimageresourceindex }
implement { name = "lastsavedimageresourcepages", actions = lastsavedimageresourcepages }
implement { name = "useimageresource",            actions = useimageresource }

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
        local streamobject = scankeyword("stream") and true or false
        local attributes   = scankeyword("attr") and scanstring()
        local fileobject   = scankeyword("file")
        local content      = scanstring()
        local object = {
            immediate     = immediate,
            attr          = attributes,
            objnum        = objnum,
            type          = streamobject and "stream" or nil,
            compresslevel = uncompress and 0 or nil,
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

implement { name = "pdfobj",     actions = pdfobj }
implement { name = "pdflastobj", actions = pdflastobj }
implement { name = "pdfrefobj",  actions = pdfrefobj }

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

implement { name = "pdfannot", actions = pdfannot }

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

implement { name = "pdfdest", actions = pdfdest }

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

implement { name = "pdfextension", actions = pdfextension }

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

implement { name = "pdffeedback", actions = pdffeedback }

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

--------- { name = "pdfvariable",                 actions = pdfvariable }
