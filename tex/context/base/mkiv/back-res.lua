if not modules then modules = { } end modules ['back-res'] = {
    version   = 1.001,
    comment   = "companion to back-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local context       = context

local trace         = false  trackers.register("backend", function(v) trace = v end)
local report        = logs.reporter("backend")

local scanners      = tokens.scanners
local scankeyword   = scanners.keyword
local scaninteger   = scanners.integer
local scanstring    = scanners.string
local scandimension = scanners.dimension
local scanword      = scanners.word
local scanwhd       = scanners.whd

local scanners      = interfaces.scanners
local implement     = interfaces.implement
local constants     = interfaces.constants
local variables     = interfaces.variables

-- A box resource has an index. This happens to be an object number due to the pdf
-- backend but in fact it's an abstraction. This is why we have explicit fetchers.
-- The internal number (as in \Fm123) is yet another number.

local tex_saveboxresource          = tex.saveboxresource
local tex_useboxresource           = tex.useboxresource
local tex_getboxresourcebox        = tex.getboxresourcebox
local tex_getboxresourcedimensions = tex.getboxresourcedimensions

updaters.register("backend.update",function()
    tex_saveboxresource          = tex.saveboxresource
    tex_useboxresource           = tex.useboxresource
    tex_getboxresourcebox        = tex.getboxresourcebox
    tex_getboxresourcedimensions = tex.getboxresourcedimensions
end)

local savebox = function(...) return tex_saveboxresource(...) end
local usebox  = function(...) return tex_useboxresource(...) end
local getbox  = function(...) return tex_getboxresourcebox(...) end
local getwhd  = function(...) return tex_getboxresourcedimensions(...) end

local boxresources = {
    save          = savebox,
    use           = usebox,
    getbox        = getbox,
    getdimensions = getwhd,
}

tex.boxresources = boxresources

-- local tex_saveimageresource = tex.saveimageresource
-- local tex_useimageresource  = tex.useimageresource
--
-- updaters.register("backend.update",function()
--     tex_saveimageresource = tex.saveimageresource
--     tex_useimageresource  = tex.useimageresource
-- end)
--
-- tex.imageresources = {
--     save = function(...) return tex_saveimageresource(...) end,
--     use  = function(...) return tex_useimageresource(...) end,
-- }

local lastindex = 0

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

-- image resources

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
        -- pcall / we could use a dedicated call instead:
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
        report("no valid image resource %a",index)
    end
end

implement { name = "saveimageresource",           actions = saveimageresource }
implement { name = "lastsavedimageresourceindex", actions = lastsavedimageresourceindex }
implement { name = "lastsavedimageresourcepages", actions = lastsavedimageresourcepages }
implement { name = "useimageresource",            actions = useimageresource }
