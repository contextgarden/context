if not modules then modules = { } end modules ['page-flt'] = {
    version   = 1.001,
    comment   = "companion to page-flt.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- floats -> managers.floats
-- some functions are a tex/lua mix so we need a separation

local next = next
local tostring = tostring
local insert, remove = table.insert, table.remove
local find = string.find
local abs = math.abs

local trace_floats     = false  trackers.register("floats.caching",    function(v) trace_floats     = v end)
local trace_collecting = false  trackers.register("floats.collecting", function(v) trace_collecting = v end)

local report_floats     = logs.reporter("floats","caching")
local report_collecting = logs.reporter("floats","collecting")

local C, S, P, lpegmatch = lpeg.C, lpeg.S, lpeg.P, lpeg.match

-- we use floatbox, floatwidth, floatheight
-- text page leftpage rightpage (todo: top, bottom, margin, order)

local setdimen         = tex.setdimen
local getdimen         = tex.getdimen
local setcount         = tex.setcount
local texsetbox        = tex.setbox
local textakebox       = nodes.takebox

floats                 = floats or { }
local floats           = floats

local context          = context
local commands         = commands
local interfaces       = interfaces
local showmessage      = interfaces.showmessage
local implement        = interfaces.implement
local setmacro         = interfaces.setmacro

local noffloats        = 0
local last             = nil
local default          = "text"
local pushed           = { }

local function initialize()
    return {
        text      = { },
        page      = { },
        leftpage  = { },
        rightpage = { },
        somewhere = { },
    }
end

local stacks = initialize()

-- list location

function floats.stacked(which) -- floats.thenofstacked
    return #stacks[which or default]
end

function floats.push()
    insert(pushed,stacks)
    stacks = initialize()
    setcount("global","savednoffloats",0)
end

function floats.pop()
    local popped = remove(pushed)
    if popped then
        for which, stack in next, stacks do
            for i=1,#stack do
                insert(popped[which],stack[i])
            end
        end
        stacks = popped
        setcount("global","savednoffloats",#stacks[default])
    end
end

local function setdimensions(t,b)
    local bw, bh, bd = 0, 0, 0
    local nw, nh, nd = 0, 0, 0
    local cw, ch, cd = 0, 0, 0
    if b then
        bw = b.width
        bh = b.height
        bd = b.depth
        cw = b.cwidth
        ch = b.cheight
        cd = b.cdepth
    end
    if t then
        nw = t.width   or bw
        nh = t.height  or bh
        nd = t.depth   or bd
        cw = t.cwidth  or cw
        ch = t.cheight or ch
        cd = t.cdepth  or cd
    end
    setdimen("global","floatwidth",     bw)
    setdimen("global","floatheight",    bh+bd)
    setdimen("global","naturalfloatwd", nw)
    setdimen("global","naturalfloatht", nh)
    setdimen("global","naturalfloatdp", nd)
    setdimen("global","floatcaptionwd", cw)
    setdimen("global","floatcaptionht", ch)
    setdimen("global","floatcaptiondp", cd)
    return bw, bh, bd, nw, nh, dp, cw, xh, xp
end

local function get(stack,n,bylabel)
    if bylabel then
        for i=1,#stack do
            local s = stack[i]
            local n = string.topattern(tostring(n)) -- to be sure
            if find(s.data.label,n) then
                return s, s.box, i
            end
        end
    else
        n = n or #stack
        if n > 0 then
            local t = stack[n]
            if t then
                return t, t.box, n
            end
        end
    end
end

function floats.save(which,data) -- todo: just pass
    which = which or default
    local b = textakebox("floatbox")
    if b then
        local stack = stacks[which]
        noffloats = noffloats + 1
        local t = {
            n       = noffloats,
            data    = data or { },
            width   = getdimen("naturalfloatwd"),
            height  = getdimen("naturalfloatht"),
            depth   = getdimen("naturalfloatdp"),
            cwidth  = getdimen("floatcaptionwd"),
            cheight = getdimen("floatcaptionht"),
            cdepth  = getdimen("floatcaptiondp"),
            box     = b,
        }
        insert(stack,t)
-- inspect(stacks)
        setcount("global","savednoffloats",#stacks[default])
        if trace_floats then
            report_floats("%s, category %a, number %a, slot %a, width %p, height %p, depth %p","saving",
                which,noffloats,#stack,b.width,b.height,b.depth)
        else
            showmessage("floatblocks",2,noffloats)
        end
    else
        report_floats("ignoring empty, category %a, number %a",which,noffloats)
    end
end

function floats.resave(which)
    if last then
        which = which or default
        local stack = stacks[which]
        local b = textakebox("floatbox")
        if not b then
            report_floats("resaved float is empty")
        end
        last.box = b
        insert(stack,1,last)
        setcount("global","savednoffloats",#stacks[default])
        if trace_floats then
            report_floats("%s, category %a, number %a, slot %a width %p, height %p, depth %p","resaving",
                which,noffloats,#stack,b.width,b.height,b.depth)
        else
            showmessage("floatblocks",2,noffloats)
        end
    else
        report_floats("unable to resave float")
    end
end

function floats.flush(which,n,bylabel)
    which = which or default
    local stack = stacks[which]
    local t, b, n = get(stack,n or 1,bylabel)
    if t then
        if not b then
            showmessage("floatblocks",1,t.n)
        end
        local w, h, d = setdimensions(t,b)
        if trace_floats then
            report_floats("%s, category %a, number %a, slot %a width %p, height %p, depth %p","flushing",
                which,t.n,n,w,h,d)
        else
            showmessage("floatblocks",3,t.n)
        end
        texsetbox("floatbox",b)
        last = remove(stack,n)
        last.box = nil
        setcount("global","savednoffloats",#stacks[which]) -- default?
    else
        setdimensions()
    end
end

function floats.consult(which,n)
    which = which or default
    local stack = stacks[which]
    local t, b, n = get(stack,n)
    if t then
        local w, h, d = setdimensions(t,b)
        if trace_floats then
            report_floats("%s, category %a, number %a, slot %a width %p, height %p, depth %p","consulting",
                which,t.n,n,w,h,d)
        end
        return t, b, n
    else
        if trace_floats then
            report_floats("nothing to consult")
        end
        setdimensions()
    end
end

function floats.collect(which,maxwidth,distance)
    local usedwhich = which or default
    local stack     = stacks[usedwhich]
    local stacksize = #stack
    local collected = 0
    local maxheight = 0
    local maxdepth  = 0

    local function register()
        collected = collected + 1
        maxwidth  = rest
        if h > maxheight then
            maxheight = h
        end
        if d > maxdepth then
            maxdepth = d
        end
    end

    for i=1,stacksize do
        local t, b, n = get(stack,i)
        if t then
            local w, h, d, nw, nh, nd, cw, ch, cd = setdimensions(t,b)
            -- we use the real width
            if cw > nw then
                w = cw
            else
                w = nw
            end
            -- which could be an option
            local rest = maxwidth - w - distance
            local fits = rest > -10
            if trace_collecting then
                report_collecting("%s, category %a, number %a, slot %a width %p, rest %p, fit %a","collecting",
                    usedwhich,t.n,n,w,rest,fits)
            end
            if fits then
                collected = collected + 1
                maxwidth  = rest
                if h > maxheight then
                    maxheight = h
                end
                if d > maxdepth then
                    maxdepth = d
                end
            else
                break
            end
        else
            break
        end
    end
    setcount("global","nofcollectedfloats",collected)
    setdimen("global","maxcollectedfloatstotal",maxheight+maxdepth)
end

function floats.getvariable(name,default)
    local value = last and last.data[name] or default
    return value ~= "" and value
end

function floats.checkedpagefloat(packed)
    if structures.pages.is_odd() then
        if #stacks.rightpage > 0 then
            return "rightpage"
        elseif #stacks.page > 0 then
            return "page"
        elseif #stacks.leftpage > 0 then
            if packed then
                return "leftpage"
            end
        end
    else
        if #stacks.leftpage > 0 then
            return "leftpage"
        elseif #stacks.page > 0 then
            return "page"
        elseif #stacks.rightpage > 0 then
            if packed then
                return "rightpage"
            end
        end
    end
end

function floats.nofstacked(which)
    return #stacks[which or default] or 0
end

function floats.hasstacked(which)
    return (#stacks[which or default] or 0) > 0
end

-- todo: check for digits !

local method   = C((1-S(", :"))^1)
local position = P(":") * C((1-S("*,"))^1) * (P("*") * C((1-S(","))^1))^0
local label    = P(":") * C((1-S(",*: "))^0)

local pattern = method * (
    label * position * C("")
  + C("") * position * C("")
  + label * C("") * C("")
  + C("") * C("") * C("")
) + C("") * C("") * C("") * C("")

-- inspect { lpegmatch(pattern,"somewhere:blabla,crap") }
-- inspect { lpegmatch(pattern,"somewhere:1*2") }
-- inspect { lpegmatch(pattern,"somewhere:blabla:1*2") }
-- inspect { lpegmatch(pattern,"somewhere::1*2") }
-- inspect { lpegmatch(pattern,"somewhere,") }
-- inspect { lpegmatch(pattern,"somewhere") }
-- inspect { lpegmatch(pattern,"") }

function floats.analysemethod(str) -- will become a more extensive parser
    return lpegmatch(pattern,str or "")
end

-- interface

implement {
    name      = "flushfloat",
    actions   = floats.flush,
    arguments = { "string", "integer" },
}

implement {
    name      = "flushlabeledfloat",
    actions   = floats.flush,
    arguments = { "string", "string", true },
}

implement {
    name      = "savefloat",
    actions   = floats.save,
    arguments = "string"
}

implement {
    name      = "savespecificfloat",
    actions   = floats.save,
    arguments = {
        "string",
        {
            { "specification" },
            { "label" },
        }
    }
}

implement {
    name      = "resavefloat",
    actions   = floats.resave,
    arguments = "string"
}

implement {
    name      = "pushfloat",
    actions   = floats.push
}

implement {
    name      = "popfloat",
    actions   = floats.pop
}

implement {
    name      = "consultfloat",
    actions   = floats.consult,
    arguments = "string",
}

implement {
    name      = "collectfloat",
    actions   = floats.collect,
    arguments = { "string", "dimen", "dimen" }
}

implement {
    name      = "getfloatvariable",
    actions   = { floats.getvariable, context },
    arguments = "string"
}

implement {
    name      = "checkedpagefloat",
    actions   = { floats.checkedpagefloat, context },
    arguments = "string"
}

implement {
    name      = "nofstackedfloats",
    actions   = { floats.nofstacked, context },
    arguments = "string"
}

implement {
    name      = "doifelsestackedfloats",
    actions   = { floats.hasstacked, commands.doifelse },
    arguments = "string"
}

implement {
    name    = "analysefloatmethod",
    actions = function(str)
        local method, label, column, row = floats.analysemethod(str)
        setmacro("floatmethod",method or "")
        setmacro("floatlabel", label  or "")
        setmacro("floatrow",   row    or "")
        setmacro("floatcolumn",column or "")
    end,
    arguments = "string"
}
