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

-- maybe use context.generics

local type         = type
local format       = string.format
local utfchar      = utf.char
local concat       = table.concat

local context      = context
local generics     = context.generics
local variables    = interfaces.variables

local nodepool     = nodes.pool
local new_rule     = nodepool.rule
local new_glyph    = nodepool.glyph

local current_font = font.current
local texgetcount  = tex.getcount
local texsetcount  = tex.setcount

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

-- plain variants

function context.chardef(cs,u)
    context([[\chardef\%s=%s\relax]],k)
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

function context.hrule(w,h,d,dir)
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

context.vrule = context.hrule

--~ local hbox, bgroup, egroup = context.hbox, context.bgroup, context.egroup

--~ function context.hbox(a,...)
--~     if type(a) == "table" then
--~         local s = { }
--~         if a.width then
--~             s[#s+1] = "to " .. a.width -- todo: check for number
--~         elseif a.spread then
--~             s[#s+1] = "spread " .. a.spread -- todo: check for number
--~         end
--~         -- todo: dir, attr etc
--~         hbox(false,table.concat(s," "))
--~         bgroup()
--~         context(string.format(...))
--~         egroup()
--~     else
--~         hbox(a,...)
--~     end
--~ end

-- not yet used ... but will get variant at the tex end as well

function context.sethboxregister(n) context([[\setbox %s\hbox]],n) end
function context.setvboxregister(n) context([[\setbox %s\vbox]],n) end

function context.starthboxregister(n)
    if type(n) == "number" then
        context([[\setbox%s\hbox{]],n)
    else
        context([[\setbox\%s\hbox{]],n)
    end
end

function context.startvboxregister(n)
    if type(n) == "number" then
        context([[\setbox%s\vbox{]],n)
    else
        context([[\setbox\%s\vbox{]],n)
    end
end

context.stophboxregister = context.egroup
context.stopvboxregister = context.egroup

function context.flushboxregister(n)
    if type(n) == "number" then
        context([[\box%s ]],n)
    else
        context([[\box\%s]],n)
    end
end

function context.beginvbox()
    context([[\vbox{]]) -- we can do \bvbox ... \evbox (less tokens)
end

function context.beginhbox()
    context([[\hbox{]]) -- todo: use fast one
end

context.endvbox = context.egroup
context.endhbox = context.egroup

local function allocate(name,what,cmd)
    local a = format("c_syst_last_allocated_%s",what)
    local n = texgetcount(a) + 1
    if n <= texgetcount("c_syst_max_allocated_register") then
        texsetcount(a,n)
    end
    context("\\global\\expandafter\\%sdef\\csname %s\\endcsname %s\\relax",cmd or what,name,n)
    return n
end

function context.newdimen (name) return allocate(name,"dimen") end
function context.newskip  (name) return allocate(name,"skip") end
function context.newcount (name) return allocate(name,"count") end
function context.newmuskip(name) return allocate(name,"muskip") end
function context.newtoks  (name) return allocate(name,"toks") end
function context.newbox   (name) return allocate(name,"box","mathchar") end
