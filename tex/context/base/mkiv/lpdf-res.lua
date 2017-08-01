if not modules then modules = { } end modules ['lpdf-res'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local codeinjections  = backends.codeinjections
local implement       = interfaces.implement

local nuts            = nodes.nuts
local tonut           = nodes.tonut

local setwhd          = nuts.setwhd
local setlist         = nuts.setlist

local new_hlist       = nuts.pool.hlist

local saveboxresource = tex.saveboxresource
local useboxresource  = tex.useboxresource
local getboxresource  = tex.getboxresourcedimensions

function codeinjections.registerboxresource(n)
    local r = saveboxresource(n,nil,lpdf.collectedresources(),true) -- direct, todo: accept functions as attr/resources
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
    return getboxresource(index)
end
