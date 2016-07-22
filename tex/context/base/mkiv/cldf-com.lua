if not modules then modules = { } end modules ['cldf-com'] = {
    version   = 1.001,
    comment   = "companion to cldf-com.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Some day I'll make a table toolkit ...

local tostring, select = tostring, select

local context = context
local ctxcore = context.core

local ctx_NC  = ctxcore.NC
local ctx_NR  = ctxcore.NR

local function tabulaterow(how,...)
    local ctx_flush = how and context[how] or context
    for i=1,select("#",...) do
        ctx_NC()
        ctx_flush(tostring(select(i,...)))
    end
    ctx_NC()
    ctx_NR()
end

function ctxcore.tabulaterow    (...) tabulaterow(false, ...) end
function ctxcore.tabulaterowbold(...) tabulaterow("bold",...) end
function ctxcore.tabulaterowtype(...) tabulaterow("type",...) end
function ctxcore.tabulaterowtyp (...) tabulaterow("typ", ...) end
