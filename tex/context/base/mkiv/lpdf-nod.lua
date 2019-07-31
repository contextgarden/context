if not modules then modules = { } end modules ['lpdf-nod'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nodecodes             = nodes.nodecodes
local whatsitcodes          = nodes.whatsitcodes

local nodeinjections        = backends.nodeinjections

local nuts                  = nodes.nuts

local setfield              = nuts.setfield
local setdata               = nuts.setdata

local copy_node             = nuts.copy
local new_node              = nuts.new

local nodepool              = nuts.pool
local register              = nodepool.register

local whatsit_code          = nodecodes.whatsit

local savewhatsit_code      = whatsitcodes.save
local restorewhatsit_code   = whatsitcodes.restore
local setmatrixwhatsit_code = whatsitcodes.setmatrix
local literalwhatsit_code   = whatsitcodes.literal

local literalvalues         = nodes.literalvalues
local originliteral_code    = literalvalues.origin
local pageliteral_code      = literalvalues.page
local directliteral_code    = literalvalues.direct
local rawliteral_code       = literalvalues.raw

local tomatrix              = drivers.helpers.tomatrix

local originliteralnode     = register(new_node(whatsit_code, literalwhatsit_code))  setfield(originliteralnode,"mode",originliteral_code)
local pageliteralnode       = register(new_node(whatsit_code, literalwhatsit_code))  setfield(pageliteralnode,  "mode",pageliteral_code)
local directliteralnode     = register(new_node(whatsit_code, literalwhatsit_code))  setfield(directliteralnode,"mode",directliteral_code)
local rawliteralnode        = register(new_node(whatsit_code, literalwhatsit_code))  setfield(rawliteralnode,   "mode",rawliteral_code)

function nodepool.originliteral(str) local t = copy_node(originliteralnode) setdata(t,str) return t end
function nodepool.pageliteral  (str) local t = copy_node(pageliteralnode  ) setdata(t,str) return t end
function nodepool.directliteral(str) local t = copy_node(directliteralnode) setdata(t,str) return t end
function nodepool.rawliteral   (str) local t = copy_node(rawliteralnode   ) setdata(t,str) return t end

local literals = {
    [originliteral_code] = originliteralnode, [literalvalues[originliteral_code]] = originliteralnode,
    [pageliteral_code]   = pageliteralnode,   [literalvalues[pageliteral_code]]   = pageliteralnode,
    [directliteral_code] = directliteralnode, [literalvalues[directliteral_code]] = directliteralnode,
    [rawliteral_code]    = rawliteralnode,    [literalvalues[rawliteral_code]]    = rawliteralnode,
}

function nodepool.literal(mode,str)
    if str then
        local t = copy_node(literals[mode] or pageliteralnode)
        setdata(t,str)
        return t
    else
        local t = copy_node(pageliteralnode)
        setdata(t,mode)
        return t
    end
end

local savenode      = register(new_node(whatsit_code, savewhatsit_code))
local restorenode   = register(new_node(whatsit_code, restorewhatsit_code))
local setmatrixnode = register(new_node(whatsit_code, setmatrixwhatsit_code))

function nodepool.save()
    return copy_node(savenode)
end

function nodepool.restore()
    return copy_node(restorenode)
end

function nodepool.setmatrix(rx,sx,sy,ry,tx,ty)
    local t = copy_node(setmatrixnode)
    setdata(t,tomatrix(rx,sx,sy,ry,tx,ty))
    return t
end
