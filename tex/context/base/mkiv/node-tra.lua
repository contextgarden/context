if not modules then modules = { } end modules ['node-tra'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This is rather experimental. We need more control and some of this
might become a runtime module instead. This module will be cleaned up!</p>
--ldx]]--

local next = next
local utfchar = utf.char
local format, match, gmatch, concat, rep = string.format, string.match, string.gmatch, table.concat, string.rep
local lpegmatch = lpeg.match
local clock = os.gettimeofday or os.clock -- should go in environment

local report_nodes = logs.reporter("nodes","tracing")

local nodes, node, context = nodes, node, context

local texgetattribute = tex.getattribute

local tracers         = nodes.tracers or { }
nodes.tracers         = tracers

local tasks           = nodes.tasks or { }
nodes.tasks           = tasks

local handlers        = nodes.handlers or {}
nodes.handlers        = handlers

local injections      = nodes.injections or { }
nodes.injections      = injections

local nuts            = nodes.nuts
local tonut           = nuts.tonut
local tonode          = nuts.tonode

local getnext         = nuts.getnext
local getprev         = nuts.getprev
local getid           = nuts.getid
local getsubtype      = nuts.getsubtype
local getlist         = nuts.getlist
local getdisc         = nuts.getdisc
local setattr         = nuts.setattr
local getglue         = nuts.getglue
local isglyph         = nuts.isglyph
local getdirection    = nuts.getdirection
local getwidth        = nuts.getwidth

local flush_list      = nuts.flush_list
local count_nodes     = nuts.countall
local used_nodes      = nuts.usedlist

local nextnode        = nuts.traversers.node
local nextglyph       = nuts.traversers.glyph

local d_tostring      = nuts.tostring

local nutpool         = nuts.pool
local new_rule        = nutpool.rule

local nodecodes       = nodes.nodecodes
local whatsitcodes    = nodes.whatsitcodes
local fillcodes       = nodes.fillcodes

local subtypes        = nodes.subtypes

local glyph_code      = nodecodes.glyph
local hlist_code      = nodecodes.hlist
local vlist_code      = nodecodes.vlist
local disc_code       = nodecodes.disc
local glue_code       = nodecodes.glue
local kern_code       = nodecodes.kern
local rule_code       = nodecodes.rule
local dir_code        = nodecodes.dir
local localpar_code   = nodecodes.localpar
local whatsit_code    = nodecodes.whatsit

local dimenfactors    = number.dimenfactors
local formatters      = string.formatters

local start_of_par    = nuts.start_of_par

-- this will be reorganized:

function nodes.showlist(head, message)
    if message then
        report_nodes(message)
    end
    for n in nextnode, tonut(head) do
        report_nodes(d_tostring(n))
    end
end

function nodes.handlers.checkglyphs(head,message)
    local h = tonut(head) -- tonut needed?
    local t = { }
    local n = 0
    local f = formatters["%U:%s"]
    for g, char, font in nextglyph, h do
        n = n + 1
        t[n] = f(char,getsubtype(g))
    end
    if n == 0 then
        -- nothing to report
    elseif message and message ~= "" then
        report_nodes("%s, %s glyphs: % t",message,n,t)
    else
        report_nodes("%s glyphs: % t",n,t)
    end
    return false
end

function nodes.handlers.checkforleaks(sparse)
    local l = { }
    local q = used_nodes()
    for p, id in nextnode, q do
        local s = table.serialize(nodes.astable(p,sparse),nodecodes[id])
        l[s] = (l[s] or 0) + 1
    end
    flush_list(q)
    for k, v in next, l do
        report_nodes("%s * %s",v,k)
    end
end

local fontcharacters -- = fonts.hashes.descriptions

local function tosequence(start,stop,compact)
    if start then
        if not fontcharacters then
            fontcharacters = fonts.hashes.descriptions
            if not fontcharacters then
                return "[no char data]"
            end
        end
        local f_sequence = formatters["U+%04X:%s"]
        local f_subrange = formatters["[[ %s ][ %s ][ %s ]]"]
        start = tonut(start)
        stop = stop and tonut(stop)
        local t = { }
        local n = 0
        while start do
            local c, id = isglyph(start)
            if c then
                local u = fontcharacters[id][c] -- id == font id
                u = u and u.unicode or c
                if type(u) == "table" then
                    local tt = { }
                    for i=1,#u do
                        local c = u[i]
                        tt[i] = compact and utfchar(c) or f_sequence(c,utfchar(c))
                    end
                    n = n + 1 ; t[n] = "(" .. concat(tt," ") .. ")"
                else
                    n = n + 1 ; t[n] = compact and utfchar(c) or f_sequence(c,utfchar(c))
                end
            elseif id == disc_code then
                local pre, post, replace = getdisc(start)
                t[#t+1] = f_subrange(pre and tosequence(pre),post and tosequence(post),replace and tosequence(replace))
            elseif id == rule_code then
                n = n + 1 ; t[n] = compact and "|" or nodecodes[id] or "?"
            elseif id == dir_code then
                local d, p = getdirection(start)
                n = n + 1 ; t[n] = "[<" .. (p and "-" or "+") .. d .. ">]" -- todo l2r etc
            elseif id == localpar_code and start_of_par(current) then
                n = n + 1 ; t[n] = "[<" .. getdirection(start) .. ">]" -- todo l2r etc
            elseif compact then
                n = n + 1 ; t[n] = "[]"
            else
                n = n + 1 ; t[n] = nodecodes[id]
            end
            if start == stop then
                break
            else
                start = getnext(start)
            end
        end
        if compact then
            return concat(t)
        else
            return concat(t," ")
        end
    else
        return "[empty]"
    end
end

nodes.tosequence = tosequence
nuts .tosequence = tosequence

function nodes.report(t)
    report_nodes("output %a, %s nodes",status.output_active,count_nodes(t))
end

function nodes.packlist(head)
    local t = { }
    for n in nextnode, tonut(head) do
        t[#t+1] = d_tostring(n)
    end
    return t
end

function nodes.idstostring(head,tail)
    head = tonut(head)
    tail = tail and tonut(tail)
    local t       = { }
    local last_id = nil
    local last_n  = 0
    local f_two   = formatters["[%s*%s]"]
    local f_one   = formatters["[%s]"]
    for n, id, subtype in nextnode, head do
        if id == whatsit_code then
            id = whatsitcodes[subtype]
        else
            id = nodecodes[id]
        end
        if not last_id then
            last_id = id
            last_n  = 1
        elseif last_id == id then
            last_n = last_n + 1
        else
            if last_n > 1 then
                t[#t+1] = f_two(last_n,last_id)
            else
                t[#t+1] = f_one(last_id)
            end
            last_id = id
            last_n  = 1
        end
        if n == tail then
            break
        end
    end
    if not last_id then
        t[#t+1] = "no nodes"
    else
        if last_n > 1 then
            t[#t+1] = f_two(last_n,last_id)
        else
            t[#t+1] = f_one(last_id)
        end
    end
    return concat(t," ")
end

function nodes.idsandsubtypes(head)
    local h = tonut(head)
    local t = { }
    local f = formatters["%s:%s"]
    for n, id, subtype in nextnode, h do
        local c = nodecodes[id]
        if subtype then
            t[#t+1] = f(c,subtypes[id][subtype])
        else
            t[#t+1] = c
        end
    end
    return concat(t, " ")
end

-- function nodes.xidstostring(head,tail) -- only for special tracing of backlinks
--     head = tonut(head)
--     tail = tonut(tail)
--     local n = head
--     while n.next do
--         n = n.next
--     end
--     local t, last_id, last_n = { }, nil, 0
--     while n do
--         local id = n.id
--         if not last_id then
--             last_id, last_n = id, 1
--         elseif last_id == id then
--             last_n = last_n + 1
--         else
--             if last_n > 1 then
--                 t[#t+1] = formatters["[%s*%s]"](last_n,nodecodes[last_id] or "?")
--             else
--                 t[#t+1] = formatters["[%s]"](nodecodes[last_id] or "?")
--             end
--             last_id, last_n = id, 1
--         end
--         if n == head then
--             break
--         end
--         n = getprev(n)
--     end
--     if not last_id then
--         t[#t+1] = "no nodes"
--     elseif last_n > 1 then
--         t[#t+1] = formatters["[%s*%s]"](last_n,nodecodes[last_id] or "?")
--     else
--         t[#t+1] = formatters["[%s]"](nodecodes[last_id] or "?")
--     end
--     return table.concat(table.reversed(t)," ")
-- end

local function showsimplelist(h,depth,n)
    h = h and tonut(h)
    while h do
        report_nodes("% w%s",n,d_tostring(h))
        if not depth or n < depth then
            local id = getid(h)
            if id == hlist_code or id == vlist_code then
                showsimplelist(getlist(h),depth,n+1)
            end
        end
        h = getnext(h)
    end
end

-- \startluacode
-- callbacks.register('buildpage_filter',function() nodes.show_simple_list(tex.lists.contrib_head) end)
-- \stopluacode
-- \vbox{b\footnote{n}a}
-- \startluacode
-- callbacks.register('buildpage_filter',nil)
-- \stopluacode

nodes.showsimplelist = function(h,depth) showsimplelist(h,depth,0) end

local function listtoutf(h,joiner,textonly,last,nodisc)
    local w = { }
    local n = 0
    local g = formatters["<%i>"]
    local d = formatters["[%s|%s|%s]"]
    while h do
        local c, id = isglyph(h)
        if c then
            n = n + 1 ; w[n] = c >= 0 and utfchar(c) or g(c)
            if joiner then
                n = n + 1 ; w[n] = joiner
            end
        elseif id == disc_code then
            local pre, pos, rep = getdisc(h)
            if not nodisc then
                n = n + 1 ; w[n] = d(
                    pre and listtoutf(pre,joiner,textonly) or "",
                    pos and listtoutf(pos,joiner,textonly) or "",
                    rep and listtoutf(rep,joiner,textonly) or ""
                )
            elseif rep then
                n = n + 1 ; w[n] = listtoutf(rep,joiner,textonly) or ""
            end
            if joiner then
                n = n + 1 ; w[n] = joiner
            end
        elseif textonly then
            if id == glue_code then
                if getwidth(h) > 0 then
                    n = n + 1 ; w[n] = " "
                end
            elseif id == hlist_code or id == vlist_code then
                n = n + 1 ; w[n] = "["
                n = n + 1 ; w[n] = listtoutf(getlist(h),joiner,textonly,last,nodisc)
                n = n + 1 ; w[n] = "]"
            end
        else
            n = n + 1 ; w[n] = "[-]"
        end
        if h == last then
            break
        else
            h = getnext(h)
        end
    end
    return concat(w,"",1,(w[n] == joiner) and (n-1) or n)
end

function nodes.listtoutf(h,joiner,textonly,last,nodisc)
    if h then
        local joiner = joiner == true and utfchar(0x200C) or joiner -- zwnj
        return listtoutf(tonut(h),joiner,textonly,last and tonut(last),nodisc)
    else
        return ""
    end
end

local what = { [0] = "unknown", "line", "box", "indent", "row", "cell" }

local function showboxes(n,symbol,depth)
    depth  = depth  or 0
    symbol = symbol or "."
    for n, id, subtype in nextnode, tonut(n) do
        if id == hlist_code or id == vlist_code then
            report_nodes(rep(symbol,depth) .. what[subtype] or subtype)
            showboxes(getlist(n),symbol,depth+1)
        end
    end
end

nodes.showboxes = showboxes

local ptfactor = dimenfactors.pt
local bpfactor = dimenfactors.bp
local stripper = lpeg.patterns.stripzeros

local f_f_f = formatters["%0.5Fpt plus %0.5F%s minus %0.5F%s"]
local f_f_m = formatters["%0.5Fpt plus %0.5F%s minus %0.5Fpt"]
local f_p_f = formatters["%0.5Fpt plus %0.5Fpt minus %0.5F%s"]
local f_p_m = formatters["%0.5Fpt plus %0.5Fpt minus %0.5Fpt"]
local f_f_z = formatters["%0.5Fpt plus %0.5F%s"]
local f_p_z = formatters["%0.5Fpt plus %0.5Fpt"]
local f_z_f = formatters["%0.5Fpt minus %0.5F%s"]
local f_z_m = formatters["%0.5Fpt minus %0.5Fpt"]
local f_z_z = formatters["%0.5Fpt"]

local tonut = nodes.tonut

local function nodetodimen(n)
    n = tonut(n)
    local id = getid(n)
    if id == kern_code then
        local width = getwidth(n)
        if width == 0 then
            return "0pt"
        else
            return f_z_z(width)
        end
    elseif id ~= glue_code then
        return "0pt"
    end
    local width, stretch, shrink, stretch_order, shrink_order = getglue(n)
    stretch = stretch / 65536
    shrink  = shrink  / 65536
    width   = width   / 65536
    if stretch_order ~= 0 then
        if shrink_order ~= 0 then
            return f_f_f(width,stretch,fillcodes[stretch_order],shrink,fillcodes[shrink_order])
        elseif shrink ~= 0 then
            return f_f_m(width,stretch,fillcodes[stretch_order],shrink)
        else
            return f_f_z(width,stretch,fillcodes[stretch_order])
        end
    elseif shrink_order ~= 0 then
        if stretch ~= 0 then
            return f_p_f(width,stretch,shrink,fillcodes[shrink_order])
        else
            return f_z_f(width,shrink,fillcodes[shrink_order])
        end
    elseif stretch ~= 0 then
        if shrink ~= 0 then
            return f_p_m(width,stretch,shrink)
        else
            return f_p_z(width,stretch)
        end
    elseif shrink ~= 0 then
        return f_z_m(width,shrink)
    elseif width == 0 then
        return "0pt"
    else
        return f_z_z(width)
    end
end


-- number.todimen(123)
-- number.todimen(123,"cm")
-- number.todimen(123,false,"%F))

local f_pt = formatters["%p"]
local f_un = formatters["%F%s"]

dimenfactors[""] = dimenfactors.pt

local function numbertodimen(d,unit,fmt)
    if not d or d == 0 then
        if fmt then
            return formatters[fmt](0,unit or "pt")
        elseif unit then
            return 0 .. unit
        else
            return "0pt"
        end
    elseif fmt then
        if not unit then
            unit = "pt"
        end
        return formatters[fmt](d*dimenfactors[unit],unit)
    elseif not unit or unit == "pt" then
        return f_pt(d)
    else
        return f_un(d*dimenfactors[unit],unit)
    end
end

number.todimen = numbertodimen
nodes .todimen = nodetodimen

function number.topoints      (n,fmt) return numbertodimen(n,"pt",fmt) end
function number.toinches      (n,fmt) return numbertodimen(n,"in",fmt) end
function number.tocentimeters (n,fmt) return numbertodimen(n,"cm",fmt) end
function number.tomillimeters (n,fmt) return numbertodimen(n,"mm",fmt) end
function number.toscaledpoints(n,fmt) return numbertodimen(n,"sp",fmt) end
function number.toscaledpoints(n)     return            n .. "sp"      end
function number.tobasepoints  (n,fmt) return numbertodimen(n,"bp",fmt) end
function number.topicas       (n,fmt) return numbertodimen(n "pc",fmt) end
function number.todidots      (n,fmt) return numbertodimen(n,"dd",fmt) end
function number.tociceros     (n,fmt) return numbertodimen(n,"cc",fmt) end
function number.tonewdidots   (n,fmt) return numbertodimen(n,"nd",fmt) end
function number.tonewciceros  (n,fmt) return numbertodimen(n,"nc",fmt) end

function nodes.topoints      (n,fmt) return nodetodimen(n,"pt",fmt) end
function nodes.toinches      (n,fmt) return nodetodimen(n,"in",fmt) end
function nodes.tocentimeters (n,fmt) return nodetodimen(n,"cm",fmt) end
function nodes.tomillimeters (n,fmt) return nodetodimen(n,"mm",fmt) end
function nodes.toscaledpoints(n,fmt) return nodetodimen(n,"sp",fmt) end
function nodes.toscaledpoints(n)     return          n .. "sp"      end
function nodes.tobasepoints  (n,fmt) return nodetodimen(n,"bp",fmt) end
function nodes.topicas       (n,fmt) return nodetodimen(n "pc",fmt) end
function nodes.todidots      (n,fmt) return nodetodimen(n,"dd",fmt) end
function nodes.tociceros     (n,fmt) return nodetodimen(n,"cc",fmt) end
function nodes.tonewdidots   (n,fmt) return nodetodimen(n,"nd",fmt) end
function nodes.tonewciceros  (n,fmt) return nodetodimen(n,"nc",fmt) end

-- stop redefinition

local points = function(n)
    if not n or n == 0 then
        return "0pt"
    elseif type(n) == "number" then
        return lpegmatch(stripper,format("%.5fpt",n*ptfactor)) -- faster than formatter
    else
        return numbertodimen(n,"pt") -- also deals with nodes
    end
end

local basepoints = function(n)
    if not n or n == 0 then
        return "0bp"
    elseif type(n) == "number" then
        return lpegmatch(stripper,format("%.5fbp",n*bpfactor)) -- faster than formatter
    else
        return numbertodimen(n,"bp") -- also deals with nodes
    end
end

local pts = function(n)
    if not n or n == 0 then
        return "0pt"
    elseif type(n) == "number" then
        return format("%.5fpt",n*ptfactor) -- faster than formatter
    else
        return numbertodimen(n,"pt") -- also deals with nodes
    end
end

local nopts = function(n)
    if not n or n == 0 then
        return "0"
    else
        return format("%.5f",n*ptfactor) -- faster than formatter
    end
end

number.points     = points
number.basepoints = basepoints
number.pts        = pts
number.nopts      = nopts

nodes.points     = function(n) return numbertodimen(n,"pt")     end
nodes.basepoints = function(n) return numbertodimen(n,"bp")     end
nodes.pts        = function(n) return numbertodimen(n,"pt")     end
nodes.nopts      = function(n) return format("%.5f",n*ptfactor) end

local colors          = { }
tracers.colors        = colors

local unsetvalue      = attributes.unsetvalue

local a_color         = attributes.private('color')
local a_colormodel    = attributes.private('colormodel')
local m_color         = attributes.list[a_color] or { }

function colors.set(n,c,s)
    local mc = m_color[c]
    local nn = tonut(n)
    if mc then
        local mm = s or texgetattribute(a_colormodel)
        setattr(nn,a_colormodel,mm <= 0 and mm or 1)
        setattr(nn,a_color,mc)
    else
        setattr(nn,a_color,unsetvalue)
    end
    return n
end

function colors.setlist(n,c,s)
    local nn = tonut(n)
    local mc = m_color[c] or unsetvalue
    local mm = s or texgetattribute(a_colormodel)
    if mm <= 0 then
        mm = 1
    end
    while nn do
        setattr(nn,a_colormodel,mm)
        setattr(nn,a_color,mc)
        nn = getnext(nn)
    end
    return n
end

function colors.reset(n)
    setattr(tonut(n),a_color,unsetvalue)
    return n
end

-- maybe

local transparencies   = { }
tracers.transparencies = transparencies

local a_transparency   = attributes.private('transparency')
local m_transparency   = attributes.list[a_transparency] or { }

function transparencies.set(n,t)
    setattr(tonut(n),a_transparency,m_transparency[t] or unsetvalue)
    return n
end

function transparencies.setlist(n,c,s)
    local nn = tonut(n)
    local mt = m_transparency[c] or unsetvalue
    while nn do
        setattr(nn,a_transparency,mt)
        nn = getnext(nn)
    end
    return n
end

function transparencies.reset(n)
    setattr(n,a_transparency,unsetvalue)
    return n
end

-- for the moment here

local visualizers = nodes.visualizers or { }
nodes.visualizers = visualizers

function visualizers.handler(head)
    return head, false
end

-- we could cache attribute lists and set attr (copy will increment count) .. todo ..
-- although tracers are used seldom

local function setproperties(n,c,s)
    local nn = tonut(n)
    local mm = texgetattribute(a_colormodel)
    setattr(nn,a_colormodel,mm > 0 and mm or 1)
    setattr(nn,a_color,m_color[c])
    setattr(nn,a_transparency,m_transparency[c])
    return n
end

tracers.setproperties = setproperties

-- setting attrlist entries instead of attr for successive entries doesn't
-- speed up much (this function is only used in tracers anyway)

function tracers.setlist(n,c,s)
    local nn = tonut(n)
    local mc = m_color[c]
    local mt = m_transparency[c]
    local mm = texgetattribute(a_colormodel)
    if mm <= 0 then
        mm = 1
    end
    while nn do
        setattr(nn,a_colormodel,mm)
        setattr(nn,a_color,mc)
        setattr(nn,a_transparency,mt)
        nn = getnext(nn)
    end
    return n
end

function tracers.resetproperties(n)
    local nn = tonut(n)
    setattr(nn,a_color,unsetvalue)
    setattr(nn,a_transparency,unsetvalue)
    return n
end

-- this one returns a nut

local nodestracerpool = { }
local nutstracerpool  = { }

tracers.pool = {
    nodes = nodestracerpool,
    nuts  = nutstracerpool,
}

table.setmetatableindex(nodestracerpool,function(t,k,v)
    local f = nutstracerpool[k]
    local v = function(...)
        return tonode(f(...))
    end
    t[k] = v
    return v
end)

function nutstracerpool.rule(w,h,d,c,s) -- so some day we can consider using literals (speedup)
    return setproperties(new_rule(w,h,d),c,s)
end

tracers.rule = nodestracerpool.rule -- for a while

-- local function show(head,n,message)
--     print("START",message or "")
--     local i = 0
--     for current in traverse(head) do
--         local prev = getprev(current)
--         local next = getnext(current)
--         i = i + 1
--         print(i, prev and nodecodes[getid(prev)],nodecodes[getid(current)],next and nodecodes[getid(next)])
--         if i == n then
--             break
--         end
--     end
--     print("STOP", message or "")
-- end
