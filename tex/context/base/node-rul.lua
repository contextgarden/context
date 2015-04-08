if not modules then modules = { } end modules ['node-rul'] = {
    version   = 1.001,
    comment   = "companion to node-rul.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this will go to an auxiliary module
-- beware: rules now have a dir field
--
-- todo: make robust for layers ... order matters

local attributes, nodes, node = attributes, nodes, node

local nuts         = nodes.nuts
local tonode       = nuts.tonode
local tonut        = nuts.tonut

local getfield     = nuts.getfield
local setfield     = nuts.setfield
local getnext      = nuts.getnext
local getprev      = nuts.getprev
local getid        = nuts.getid
local getattr      = nuts.getattr
local setattr      = nuts.setattr
local getfont      = nuts.getfont
local getsubtype   = nuts.getsubtype
local getchar      = nuts.getchar
local getlist      = nuts.getlist

local nodecodes    = nodes.nodecodes
local tasks        = nodes.tasks

local glyph_code   = nodecodes.glyph
local disc_code    = nodecodes.disc
local rule_code    = nodecodes.rule

function nodes.striprange(first,last) -- todo: dir
    if first and last then -- just to be sure
        if first == last then
            return first, last
        end
        while first and first ~= last do
            local id = getid(first)
            if id == glyph_code or id == disc_code then -- or id == rule_code
                break
            else
                first = getnext(first)
            end
        end
        if not first then
            return nil, nil
        elseif first == last then
            return first, last
        end
        while last and last ~= first do
            local id = getid(last)
            if id == glyph_code or id == disc_code then -- or id == rule_code
                break
            else
                local prev = getprev(last) -- luatex < 0.70 has italic correction kern not prev'd
                if prev then
                    last = prev
                else
                    break
                end
            end
        end
        if not last then
            return nil, nil
        end
    end
    return first, last
end

-- todo: order and maybe other dimensions

local floor = math.floor

local trace_ruled        = false  trackers.register("nodes.rules", function(v) trace_ruled = v end)
local report_ruled       = logs.reporter("nodes","rules")

local n_tostring         = nodes.idstostring
local n_tosequence       = nodes.tosequence

local a_ruled            = attributes.private('ruled')
local a_color            = attributes.private('color')
local a_transparency     = attributes.private('transparency')
local a_colorspace       = attributes.private('colormodel')

local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local list_dimensions    = nuts.dimensions
local hpack_nodes        = nuts.hpack

local striprange         = nodes.striprange

local fontdata           = fonts.hashes.identifiers
local variables          = interfaces.variables
local dimenfactor        = fonts.helpers.dimenfactor
local splitdimen         = number.splitdimen

local v_yes              = variables.yes
local v_foreground       = variables.foreground

local nodecodes          = nodes.nodecodes
local skipcodes          = nodes.skipcodes
local whatcodes          = nodes.whatcodes
local kerncodes          = nodes.kerncodes

local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local glue_code          = nodecodes.glue
local penalty_code       = nodecodes.penalty
local kern_code          = nodecodes.kern
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local rule_code          = nodecodes.rule
local whatsit_code       = nodecodes.whatsit

local userskip_code      = skipcodes.userskip
local spaceskip_code     = skipcodes.spaceskip
local xspaceskip_code    = skipcodes.xspaceskip

local dir_code           = whatcodes.dir

local kerning_code       = kerncodes.kern

local nodepool           = nuts.pool

local new_rule           = nodepool.rule
local new_kern           = nodepool.kern
local new_glue           = nodepool.glue

-- we can use this one elsewhere too
--
-- todo: functions: word, sentence
--
-- glyph rule unset whatsit glue margin_kern kern math disc

local checkdir = true

-- we assume {glyphruns} and no funny extra kerning, ok, maybe we need
-- a dummy character as start and end; anyway we only collect glyphs
--
-- this one needs to take layers into account (i.e. we need a list of
-- critical attributes)

-- omkeren class en level -> scheelt functie call in analyze

-- todo: switching inside math

local function processwords(attribute,data,flush,head,parent) -- we have hlistdir and local dir
    local n = head
    if n then
        local f, l, a, d, i, class
        local continue, done, strip, level = false, false, true, -1
        while n do
            local id = getid(n)
            if id == glyph_code or id == rule_code then
                local aa = getattr(n,attribute)
                if aa then
                    if aa == a then
                        if not f then -- ?
                            f = n
                        end
                        l = n
                    else
                        -- possible extensions: when in same class then keep spanning
                        local newlevel, newclass = floor(aa/1000), aa%1000
                     -- strip = not continue or level == 1 -- 0
                        if f then
                            if class == newclass then -- and newlevel > level then
                                head, done = flush(head,f,l,d,level,parent,false), true
                            else
                                head, done = flush(head,f,l,d,level,parent,strip), true
                            end
                        end
                        f, l, a = n, n, aa
                        level, class = newlevel, newclass
                        d = data[class]
                        continue = d.continue == v_yes
                    end
                else
                    if f then
                        head, done = flush(head,f,l,d,level,parent,strip), true
                    end
                    f, l, a = nil, nil, nil
                end
--             elseif f and (id == disc_code or (id == kern_code and getsubtype(n) == kerning_code)) then
--                 l = n
            elseif id == disc_code then
                if f then
                    l = n
                end
            elseif id == kern_code and getsubtype(n) == kerning_code then
                if f then
                    l = n
                end
            elseif id == hlist_code or id == vlist_code then
                if f then
                    head, done = flush(head,f,l,d,level,parent,strip), true
                    f, l, a = nil, nil, nil
                end
                local list = getlist(n)
                if list then
                    setfield(n,"list",(processwords(attribute,data,flush,list,n))) -- watch ()
                end
            elseif checkdir and id == whatsit_code and getsubtype(n) == dir_code then -- only changes in dir, we assume proper boundaries
                if f and a then
                    l = n
                end
            elseif f then
                if continue then
                    if id == penalty_code then
                        l = n
                 -- elseif id == kern_code then
                 --     l = n
                    elseif id == glue_code then
                        -- catch \underbar{a} \underbar{a} (subtype test is needed)
                        local subtype = getsubtype(n)
                        if getattr(n,attribute) and (subtype == userskip_code or subtype == spaceskip_code or subtype == xspaceskip_code) then
                            l = n
                        else
                            head, done = flush(head,f,l,d,level,parent,strip), true
                            f, l, a = nil, nil, nil
                        end
                    end
                else
                    head, done = flush(head,f,l,d,level,parent,strip), true
                    f, l, a = nil, nil, nil
                end
            end
            n = getnext(n)
        end
        if f then
            head, done = flush(head,f,l,d,level,parent,strip), true
        end
        return head, true -- todo: done
    else
        return head, false
    end
end

-- nodes.processwords = processwords

nodes.processwords = function(attribute,data,flush,head,parent) -- we have hlistdir and local dir
    head = tonut(head)
    if parent then
        parent = tonut(parent)
    end
    local head, done = processwords(attribute,data,flush,head,parent)
    return tonode(head), done
end

--

nodes.rules      = nodes.rules      or { }
nodes.rules.data = nodes.rules.data or { }

storage.register("nodes/rules/data", nodes.rules.data, "nodes.rules.data")

local data = nodes.rules.data

function nodes.rules.define(settings)
    data[#data+1] = settings
    context(#data)
end

local a_viewerlayer = attributes.private("viewerlayer")

local function flush_ruled(head,f,l,d,level,parent,strip) -- not that fast but acceptable for this purpose
    if getid(f) ~= glyph_code then
        -- saveguard ... we need to deal with rules and so (math)
        return head
    end
    local r, m
    if strip then
        if trace_ruled then
            local before = n_tosequence(f,l,true)
            f, l = striprange(f,l)
            local after = n_tosequence(f,l,true)
            report_ruled("range stripper, before %a, after %a",before,after)
        else
            f, l = striprange(f,l)
        end
    end
    if not f then
        return head
    end
    local w = list_dimensions(getfield(parent,"glue_set"),getfield(parent,"glue_sign"),getfield(parent,"glue_order"),f,getnext(l))
    local method, offset, continue, dy, order, max = d.method, d.offset, d.continue, d.dy, d.order, d.max
    local rulethickness, unit = d.rulethickness, d.unit
    local ma, ca, ta = d.ma, d.ca, d.ta
    local colorspace   = ma > 0 and ma or getattr(f,a_colorspace) or 1
    local color        = ca > 0 and ca or getattr(f,a_color)
    local transparency = ta > 0 and ta or getattr(f,a_transparency)
    local foreground = order == v_foreground

    local e = dimenfactor(unit,getfont(f)) -- what if no glyph node

    local rt = tonumber(rulethickness)
    if rt then
        rulethickness = e * rulethickness / 2
    else
        local n, u = splitdimen(rulethickness)
        if n and u then -- we need to intercept ex and em and % and ...
            rulethickness = n * dimenfactor(u,fontdata[getfont(f)]) / 2
        else
            rulethickness = 1/5
        end
    end

    if level > max then
        level = max
    end
    if method == 0 then -- center
        offset = 2*offset
        m = (offset+(level-1)*dy)*e/2 + rulethickness/2
    else
        m = 0
    end
    for i=1,level do
        local ht =  (offset+(i-1)*dy)*e + rulethickness - m
        local dp = -(offset+(i-1)*dy)*e + rulethickness + m
        local r = new_rule(w,ht,dp)
        local v = getattr(f,a_viewerlayer)
        -- quick hack
        if v then
            setattr(r,a_viewerlayer,v)
        end
        --
        if color then
            setattr(r,a_colorspace,colorspace)
            setattr(r,a_color,color)
        end
        if transparency then
            setattr(r,a_transparency,transparency)
        end
        local k = new_kern(-w)
        if foreground then
            insert_node_after(head,l,k)
            insert_node_after(head,k,r)
            l = r
        else
            head = insert_node_before(head,f,r)
            insert_node_after(head,r,k)
        end
        if trace_ruled then
            report_ruled("level %a, width %p, height %p, depth %p, nodes %a, text %a",
                level,w,ht,dp,n_tostring(f,l),n_tosequence(f,l,true))
        end
    end
    return head
end

local process = nodes.processwords

nodes.rules.handler = function(head) return process(a_ruled,data,flush_ruled,head) end

function nodes.rules.enable()
    tasks.enableaction("shipouts","nodes.rules.handler")
end

-- elsewhere:
--
-- tasks.appendaction ("shipouts", "normalizers", "nodes.rules.handler")
-- tasks.disableaction("shipouts",                "nodes.rules.handler") -- only kick in when used

local trace_shifted = false  trackers.register("nodes.shifting", function(v) trace_shifted = v end)

local report_shifted = logs.reporter("nodes","shifting")

local a_shifted = attributes.private('shifted')

nodes.shifts      = nodes.shifts      or { }
nodes.shifts.data = nodes.shifts.data or { }

storage.register("nodes/shifts/data", nodes.shifts.data, "nodes.shifts.data")

local data = nodes.shifts.data

function nodes.shifts.define(settings)
    data[#data+1] = settings
    context(#data)
end

local function flush_shifted(head,first,last,data,level,parent,strip) -- not that fast but acceptable for this purpose
    if true then
        first, last = striprange(first,last)
    end
    local prev = getprev(first)
    local next = getnext(last)
    setfield(first,"prev",nil)
    setfield(last,"next",nil)
    local width, height, depth = list_dimensions(getfield(parent,"glue_set"),getfield(parent,"glue_sign"),getfield(parent,"glue_order"),first,next)
    local list = hpack_nodes(first,width,"exactly")
    if first == head then
        head = list
    end
    if prev then
       setfield(prev,"next",list)
       setfield(list,"prev",prev)
    end
    if next then
        setfield(next,"prev",list)
        setfield(list,"next",next)
    end
    local raise = data.dy * dimenfactor(data.unit,fontdata[getfont(first)])
    setfield(list,"shift",raise)
    setfield(list,"height",height)
    setfield(list,"depth",depth)
    if trace_shifted then
        report_shifted("width %p, nodes %a, text %a",width,n_tostring(first,last),n_tosequence(first,last,true))
    end
    return head
end

local process = nodes.processwords

nodes.shifts.handler = function(head) return process(a_shifted,data,flush_shifted,head) end

function nodes.shifts.enable()
    tasks.enableaction("shipouts","nodes.shifts.handler")
end

-- interface

local implement = interfaces.implement

implement {
    name      = "definerule",
    actions   = { nodes.rules.define, context },
    arguments = {
        {
            { "continue" },
            { "unit" },
            { "order" },
            { "method", "integer" },
            { "offset", "number" },
            { "rulethickness", "string" },
            { "dy", "number" },
            { "max", "number" },
            { "ma", "integer" },
            { "ca", "integer" },
            { "ta", "integer" },
        }
    }
}

implement {
    name     = "enablerules",
    onlyonce = true,
    actions  = nodes.rules.enable
}

implement {
    name      = "defineshift",
    actions   = { nodes.shifts.define, context },
    arguments = {
        {
            { "continue" },
            { "unit" },
            { "method", "integer" },
            { "dy", "number" },
        }
    }
}

implement {
    name     = "enableshifts",
    onlyonce = true,
    actions  = nodes.shifts.enable
}
