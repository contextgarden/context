if not modules then modules = { } end modules ['back-res'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- A box resource has an index. This happens to be an object number
-- due to the pdf backend but in fact it's an abstraction. This is why
-- we have explicit fetchers. The internal number (as in \Fm123) is yet
-- another number.

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

tex.boxresources = {
    save          = function(...) return tex_saveboxresource(...) end,
    use           = function(...) return tex_useboxresource(...) end,
    getbox        = function(...) return tex_getboxresourcebox(...) end,
    getdimensions = function(...) return tex_getboxresourcedimensions(...) end,
}

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
