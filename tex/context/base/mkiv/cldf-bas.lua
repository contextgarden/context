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

local tonumber      = tonumber
local type          = type
local format        = string.format
local utfchar       = utf.char
local concat        = table.concat

local context       = context
local ctxcore       = context.core

local variables     = interfaces.variables

local ctx_flushnode = context.nuts.flush

local nuts          = nodes.nuts
local tonode        = nuts.tonode
local nodepool      = nuts.pool
local new_rule      = nodepool.rule
local new_glyph     = nodepool.glyph
local new_latelua   = nodepool.latelua

local setattrlist   = nuts.setattrlist

local texgetcount   = tex.getcount
local texsetcount   = tex.setcount

-- a set of basic fast ones

function context.setfontid(n)
    -- isn't there a setter?
    context("\\setfontid%i\\relax",n)
end

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

function context.rule(w,h,d,direction)
    local rule
    if type(w) == "table" then
        rule = new_rule(w.width,w.height,w.depth,w.direction)
    else
        rule = new_rule(w,h,d,direction)
    end
    setattrlist(rule,true)
    context(tonode(rule))
 -- ctx_flushnode(tonode(rule))
end

function context.glyph(id,k)
    if id then
        if not k then
            id, k = true, id
        end
        local glyph = new_glyph(id,k)
        setattrlist(glyph,true)
        context(tonode(glyph))
     -- ctx_flushnode(tonode(glyph))
    end
end

-- local function ctx_par  () context("\\par")   end
-- local function ctx_space() context("\\space") end

local ctx_par   = context.cs.par
local ctx_space = context.cs.space

context.par   = ctx_par
context.space = ctx_space

ctxcore.par   = ctx_par
ctxcore.space = ctx_space

-- local function ctx_bgroup() context("{") end
-- local function ctx_egroup() context("}") end

local ctx_bgroup = context.cs.bgroup
local ctx_egroup = context.cs.egroup

context.bgroup = ctx_bgroup
context.egroup = ctx_egroup

ctxcore.bgroup = ctx_bgroup
ctxcore.egroup = ctx_egroup

-- not yet used ... but will get variant at the tex end as well

local function setboxregister(kind,n)
    context(type(n) == "number" and [[\setbox%s\%s]] or [[\setbox\%s\%s]],n,kind)
end

function ctxcore.sethboxregister(n) setboxregister("hbox",n) end
function ctxcore.setvboxregister(n) setboxregister("vbox",n) end
function ctxcore.setvtopregister(n) setboxregister("vtop",n) end

local function startboxregister(kind,n)
    context(type(n) == "number" and [[\setbox%s\%s{]] or [[\setbox\%s\%s{]],n,kind)
end

function ctxcore.starthboxregister(n) startboxregister("hbox",n) end
function ctxcore.startvboxregister(n) startboxregister("vbox",n) end
function ctxcore.startvtopregister(n) startboxregister("vtop",n) end

ctxcore.stophboxregister = ctx_egroup
ctxcore.stopvboxregister = ctx_egroup
ctxcore.stopvtopregister = ctx_egroup

function ctxcore.flushboxregister(n)
    context(type(n) == "number" and [[\box%s ]] or [[\box\%s]],n)
end

-- function ctxcore.beginhbox() context([[\hbox\bgroup]]) end
-- function ctxcore.beginvbox() context([[\vbox\bgroup]]) end
-- function ctxcore.beginvtop() context([[\vtop\bgroup]]) end

local ctx_hbox = context.cs.hbox
local ctx_vbox = context.cs.vbox
local ctx_vtop = context.cs.vtop

function ctxcore.beginhbox() ctx_hbox() ctx_bgroup() end
function ctxcore.beginvbox() ctx_vbox() ctx_bgroup() end
function ctxcore.beginvtop() ctx_vtop() ctx_bgroup() end

ctxcore.endhbox = ctx_egroup -- \egroup
ctxcore.endvbox = ctx_egroup -- \egroup
ctxcore.endvtop = ctx_egroup -- \egroup

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
    newchar   = function(name,u) context([[\chardef\%s=%s\relax]],name,u) end,
}

function context.latelua(f)
    -- table check moved elsewhere
    local latelua = new_latelua(f)
    setattrlist(latelua,true) -- will become an option
    ctx_flushnode(latelua,true)
end

do

    local NC = ctxcore.NC
    local BC = ctxcore.BC
    local NR = ctxcore.NR

    context.nc = setmetatable({ }, {
        __call =
            function(t,...)
                NC()
                return context(...)
            end,
        __index =
            function(t,k)
                NC()
                return context[k]
            end,
        }
    )

    function context.bc(...)
        BC()
        return context(...)
    end

    function context.nr(...)
        NC()
        NR()
    end

end

