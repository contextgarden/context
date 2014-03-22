if not modules then modules = { } end modules ['page-flt'] = {
    version   = 1.001,
    comment   = "companion to page-flt.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- floats -> managers.floats
-- some functions are a tex/lua mix so we need a separation

local insert, remove = table.insert, table.remove
local find = string.find

local trace_floats = false  trackers.register("graphics.floats", function(v) trace_floats = v end) -- name might change

local report_floats = logs.reporter("structure","floats")

local C, S, P, lpegmatch = lpeg.C, lpeg.S, lpeg.P, lpeg.match

-- we use floatbox, floatwidth, floatheight
-- text page leftpage rightpage (todo: top, bottom, margin, order)

local copy_node_list   = node.copy_list
local flush_node_list  = node.flush_list
local copy_node        = node.copy

local setdimen         = tex.setdimen
local setcount         = tex.setcount
local texgetbox        = tex.getbox
local texsetbox        = tex.setbox
local textakebox       = nodes.takebox

floats                 = floats or { }
local floats           = floats

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

local function setdimensions(b)
    local w, h, d = 0, 0, 0
    if b then
        w, h, d = b.width, b.height, b.depth
    end
    setdimen("global","floatwidth", w)
    setdimen("global","floatheight", h+d)
    return w, h, d
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

function floats.save(which,data)
    which = which or default
    local b = textakebox("floatbox")
    if b then
        local stack = stacks[which]
        noffloats = noffloats + 1
        local t = {
            n    = noffloats,
            data = data or { },
            box  = b,
        }
        insert(stack,t)
        setcount("global","savednoffloats",#stacks[default])
        if trace_floats then
            report_floats("%s, category %a, number %a, slot %a, width %p, height %p, depth %p","saving",
                which,noffloats,#stack,b.width,b.height,b.depth)
        else
            interfaces.showmessage("floatblocks",2,noffloats)
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
        last.box = b
        insert(stack,1,last)
        setcount("global","savednoffloats",#stacks[default])
        if trace_floats then
            report_floats("%s, category %a, number %a, slot %a width %p, height %p, depth %p","resaving",
                which,noffloats,#stack,b.width,b.height,b.depth)
        else
            interfaces.showmessage("floatblocks",2,noffloats)
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
        if trace_floats then
            local w, h, d = setdimensions(b) -- ?
            report_floats("%s, category %a, number %a, slot %a width %p, height %p, depth %p","flushing",
                which,t.n,n,w,h,d)
        else
            interfaces.showmessage("floatblocks",3,t.n)
        end
        texsetbox("floatbox",b)
        last = remove(stack,n)
        last.box = nil
        setcount("global","savednoffloats",#stacks[default]) -- default?
    else
        setdimensions()
    end
end

function floats.consult(which,n)
    which = which or default
    local stack = stacks[which]
    local t, b, n = get(stack,n)
    if t then
        if trace_floats then
            local w, h, d = setdimensions(b)
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
    which = which or default
    local stack = stacks[which]
    local n, m = #stack, 0
    for i=1,n do
        local t, b, n = get(stack,i)
        if t then
            local w, h, d = setdimensions(b)
            if w + distance < maxwidth then
                m = m + 1
                maxwidth = maxwidth - w - distance
            else
                break
            end
        else
            break
        end
    end
    if m == 0 then
        m = 1
    end
    setcount("global","nofcollectedfloats",m)
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

function floats.nofstacked()
    return #stacks[which or default] or 0
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

local context          = context
local context_setvalue = context.setvalue

commands.flushfloat    = floats.flush
commands.savefloat     = floats.save
commands.resavefloat   = floats.resave
commands.pushfloat     = floats.push
commands.popfloat      = floats.pop
commands.consultfloat  = floats.consult
commands.collectfloat  = floats.collect

function commands.getfloatvariable  (...) local v = floats.getvariable(...)      if v then context(v) end end
function commands.checkedpagefloat  (...) local v = floats.checkedpagefloat(...) if v then context(v) end end

function commands.nofstackedfloats  (...) context(floats.nofstacked(...))             end
function commands.doifelsesavedfloat(...) commands.doifelse(floats.nofstacked(...)>0) end

function commands.analysefloatmethod(str) -- currently only one method
    local method, label, row, column = floats.analysemethod(str)
    context_setvalue("floatmethod",method or "")
    context_setvalue("floatlabel", label  or "")
    context_setvalue("floatrow",   row    or "")
    context_setvalue("floatcolumn",column or "")
end
