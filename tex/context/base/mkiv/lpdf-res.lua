if not modules then modules = { } end modules ['lpdf-res'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local codeinjections           = backends.codeinjections

local nuts                     = nodes.nuts
local tonut                    = nodes.tonut

local setwhd                   = nuts.setwhd
local setlist                  = nuts.setlist

local new_hlist                = nuts.pool.hlist

local boxresources             = tex.boxresources
local saveboxresource          = boxresources.save
local useboxresource           = boxresources.use
local getboxresourcedimensions = boxresources.getdimensions

local pdfcollectedresources    = lpdf.collectedresources

function codeinjections.registerboxresource(n,offset)
    local r = saveboxresource(n,nil,pdfcollectedresources(),true,0,offset or 0) -- direct, todo: accept functions as attr/resources
    return r
end

function codeinjections.restoreboxresource(index)
    local hbox = new_hlist()
    local list, wd, ht, dp = useboxresource(index)
    setlist(hbox,tonut(list))
    setwhd(hbox,wd,ht,dp)
    return hbox -- so we return a nut !
end

function codeinjections.boxresourcedimensions(index)
    return getboxresourcedimensions(index)
end
