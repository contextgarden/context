if not modules then modules = { } end modules ['cldf-bas'] = {
    version   = 1.001,
    comment   = "companion to cldf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- -- speedtest needed:
--
-- local flush, writer = context.getlogger()
--
-- trackers.register("context.trace",function(v)
--     flush, writer = context.getlogger()
-- end)
--
-- function context.bgroup()
--     flush(ctxcatcodes,"{")
-- end
--
-- function context.egroup()
--     flush(ctxcatcodes,"}")
-- end

local type         = type
local format       = string.format
local utfchar      = utf.char
local concat       = table.concat

local context      = context
local ctxcore      = context.core
local variables    = interfaces.variables

local nodepool     = nodes.pool
local new_rule     = nodepool.rule
local new_glyph    = nodepool.glyph

local current_font = font.current
local texgetcount  = tex.getcount
local texsetcount  = tex.setcount

-- a set of basic fast ones

function context.char(k) -- used as escape too, so don't change to utf
    if type(k) == "table" then
        local n = #k
        if n == 1 then
            context([[\char%s\relax]],k[1])
        elseif n > 0 then
            context([[\char%s\relax]],concat(k,[[\relax\char]]))
        end
    else
        if type(k) == "string" then
            k = tonumber(k)
        end
        if type(k) == "number" then
            context([[\char%s\relax]],k)
        end
    end
end

function context.utfchar(k)
    if type(k) == "string" then
        k = tonumber(k)
    end
    if type(k) == "number" then
        context(utfchar(k))
    end
end

function context.par()
    context([[\par]]) -- no need to add {} there
end

function context.bgroup()
    context("{")
end

function context.egroup()
    context("}")
end

function context.space()
    context("\\space") -- no " " as that gets intercepted
end

function context.rule(w,h,d,dir)
    if type(w) == "table" then
        context(new_rule(w.width,w.height,w.depth,w.dir))
    else
        context(new_rule(w,h,d,dir))
    end
end

function context.glyph(id,k)
    if id then
        if not k then
            id, k = current_font(), id
        end
        context(new_glyph(id,k))
    end
end

-- we also register these in core:

ctxcore.par    = context.par
ctxcore.space  = context.space
ctxcore.bgroup = context.bgroup
ctxcore.egroup = context.egroup

-- not yet used ... but will get variant at the tex end as well

function ctxcore.sethboxregister(n) context([[\setbox %s\hbox]],n) end
function ctxcore.setvboxregister(n) context([[\setbox %s\vbox]],n) end

function ctxcore.starthboxregister(n)
    if type(n) == "number" then
        context([[\setbox%s\hbox{]],n)
    else
        context([[\setbox\%s\hbox{]],n)
    end
end

function ctxcore.startvboxregister(n)
    if type(n) == "number" then
        context([[\setbox%s\vbox{]],n)
    else
        context([[\setbox\%s\vbox{]],n)
    end
end

ctxcore.stophboxregister = ctxcore.egroup
ctxcore.stopvboxregister = ctxcore.egroup

function ctxcore.flushboxregister(n)
    if type(n) == "number" then
        context([[\box%s ]],n)
    else
        context([[\box\%s]],n)
    end
end

function ctxcore.beginvbox()
    context([[\vbox{]]) -- we can do \bvbox ... \evbox (less tokens)
end

function ctxcore.beginhbox()
    context([[\hbox{]]) -- todo: use fast one
end

ctxcore.endvbox = ctxcore.egroup
ctxcore.endhbox = ctxcore.egroup

local function allocate(name,what,cmd)
    local a = format("c_syst_last_allocated_%s",what)
    local n = texgetcount(a) + 1
    if n <= texgetcount("c_syst_max_allocated_register") then
        texsetcount(a,n)
    end
    context("\\global\\expandafter\\%sdef\\csname %s\\endcsname %s\\relax",cmd or what,name,n)
    return n
end

context.registers = {
    -- the number is available directly, the csname after the lua call
    newdimen  = function(name) return allocate(name,"dimen") end,
    newskip   = function(name) return allocate(name,"skip") end,
    newcount  = function(name) return allocate(name,"count") end,
    newmuskip = function(name) return allocate(name,"muskip") end,
    newtoks   = function(name) return allocate(name,"toks") end,
    newbox    = function(name) return allocate(name,"box","mathchar") end,
    -- not really a register but kind of belongs here
    chardef   = function(name,u) context([[\chardef\%s=%s\relax]],name,u) end,
}
