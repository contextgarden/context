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

-- todo: collect successive bit and pieces and combine them
--
-- path s ; s := shaped(p) ; % p[] has rectangles
-- fill s withcolor .5white ;
-- draw boundingbox s withcolor yellow;

local tonumber           = tonumber

local context            = context
local attributes         = attributes
local nodes              = nodes
local properties         = nodes.properties

local enableaction       = nodes.tasks.enableaction

local nuts               = nodes.nuts
local tonode             = nuts.tonode
local tonut              = nuts.tonut

local getfield           = nuts.getfield
local setnext            = nuts.setnext
local setprev            = nuts.setprev
local setlink            = nuts.setlink
local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getdir             = nuts.getdir
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local getfont            = nuts.getfont
local getsubtype         = nuts.getsubtype
local getlist            = nuts.getlist
local setwhd             = nuts.setwhd
local setattrlist        = nuts.setattrlist
local setshift           = nuts.setshift
local getwidth           = nuts.getwidth
local setwidth           = nuts.setwidth
local setfield           = nuts.setfield

local flushlist          = nuts.flush_list
local effective_glue     = nuts.effective_glue
local insert_node_after  = nuts.insert_after
local insert_node_before = nuts.insert_before
local find_tail          = nuts.tail
local setglue            = nuts.setglue
local list_dimensions    = nuts.rangedimensions
local hpack_nodes        = nuts.hpack
local current_attr       = nuts.current_attr
local copy_list          = nuts.copy_list

local nexthlist          = nuts.traversers.hlist

local nodecodes          = nodes.nodecodes
local rulecodes          = nodes.rulecodes
local gluecodes          = nodes.gluecodes
local listcodes          = nodes.listcodes
local kerncodes          = nodes.kerncodes

local glyph_code         = nodecodes.glyph
local localpar_code      = nodecodes.localpar
local dir_code           = nodecodes.dir
local glue_code          = nodecodes.glue
local hlist_code         = nodecodes.hlist

local indent_code        = listcodes.indent
local line_code          = listcodes.line

local leftskip_code      = gluecodes.leftskip
local rightskip_code     = gluecodes.rightskip
local parfillskip_code   = gluecodes.parfillskip

local nodepool           = nuts.pool

local new_rule           = nodepool.rule
local new_userrule       = nodepool.userrule
local new_kern           = nodepool.kern
local new_leader         = nodepool.leader

local n_tostring         = nodes.idstostring
local n_tosequence       = nodes.tosequence

local variables          = interfaces.variables
local implement          = interfaces.implement

local privateattributes  = attributes.private

local a_ruled            = privateattributes('ruled')
local a_runningtext      = privateattributes('runningtext')
local a_color            = privateattributes('color')
local a_transparency     = privateattributes('transparency')
local a_colormodel       = privateattributes('colormodel')
local a_linefiller       = privateattributes("linefiller")
local a_viewerlayer      = privateattributes("viewerlayer")

local v_both             = variables.both
local v_left             = variables.left
local v_right            = variables.right
local v_local            = variables["local"]
local v_yes              = variables.yes
local v_foreground       = variables.foreground

local fonthashes         = fonts.hashes
local fontdata           = fonthashes.identifiers
local fontresources      = fonthashes.resources

local dimenfactor        = fonts.helpers.dimenfactor
local splitdimen         = number.splitdimen
local setmetatableindex  = table.setmetatableindex

--

local striprange         = nuts.striprange
local processwords       = nuts.processwords

--

local rules = nodes.rules or { }
nodes.rules = rules
rules.data  = rules.data  or { }

local nutrules = nuts.rules or { }
nuts.rules     = nutrules -- not that many

storage.register("nodes/rules/data", rules.data, "nodes.rules.data")

local data = rules.data

-- we implement user rules here as it takes less code this way

local function usernutrule(t,noattributes)
    local r = new_userrule(t.width or 0,t.height or 0,t.depth or 0)
    if noattributes == false or noattributes == nil then
        -- avoid fuzzy ones
    else
        setattrlist(r,current_attr())
    end
    properties[r] = t
    return r
end

nutrules.userrule = usernutrule

local function userrule(t,noattributes)
    return tonode(usernutrule(t,noattributes))
end

rules.userrule    = userrule
local ruleactions = { }
rules.ruleactions = ruleactions

local function mathradical(n,h,v)
    ----- size    = getfield(n,"index")
    local font    = getfield(n,"transform")
    local actions = fontresources[font].mathruleactions
    if actions then
        local action = actions.radicalaction
        if action then
            action(n,h,v,font)
        end
    end
end

local function mathrule(n,h,v)
    ----- size    = getfield(n,"index")
    local font    = getfield(n,"transform")
    local actions = fontresources[font].mathruleactions
    if actions then
        local action = actions.hruleaction
        if action then
            action(n,h,v,font)
        end
    end
end

local function useraction(n,h,v)
    local p = properties[n]
    if p then
        local i = p.type or "draw"
        local a = ruleactions[i]
        if a then
            a(p,h,v,i,n)
        end
    end
end

local subtypeactions = {
    [rulecodes.user]     = useraction,
    [rulecodes.over]     = mathrule,
    [rulecodes.under]    = mathrule,
    [rulecodes.fraction] = mathrule,
    [rulecodes.radical]  = mathradical,
}

local function process_rule(n,h,v)
    local n = tonut(n)
    local s = getsubtype(n)
    local a = subtypeactions[s]
    if a then
        a(n,h,v)
    end
end

callbacks.register("process_rule",process_rule,"handle additional user rule features")

callbacks.functions.process_rule = process_rule

--

local trace_ruled   = false  trackers.register("nodes.rules", function(v) trace_ruled = v end)
local report_ruled  = logs.reporter("nodes","rules")

function rules.define(settings)
    local nofdata = #data+1
    data[nofdata] = settings
    local text = settings.text
    if text then
        local b = nuts.takebox(text)
        if b then
            nodepool.register(b)
            settings.text = getlist(b)
        else
            settings.text = nil
        end
    end
    context(nofdata)
end

local function flush_ruled(head,f,l,d,level,parent,strip) -- not that fast but acceptable for this purpose
    local font = nil
    local id   = getid(f)
    if id == glyph_code then
        font = getfont(f)
    elseif id == hlist_code then
        font = getattr(f,a_runningtext)
    end
    if not font then
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
    local w, ht, dp     = list_dimensions(parent,f,getnext(l))
    local method        = d.method
    local empty         = d.empty == v_yes
    local offset        = d.offset
    local dy            = d.dy
    local order         = d.order
    local max           = d.max
    local mp            = d.mp
    local rulethickness = d.rulethickness
    local unit          = d.unit
    local ma            = d.ma
    local ca            = d.ca
    local ta            = d.ta
    local colorspace    = ma > 0 and ma or getattr(f,a_colormodel) or 1
    local color         = ca > 0 and ca or getattr(f,a_color)
    local transparency  = ta > 0 and ta or getattr(f,a_transparency)
    local foreground    = order == v_foreground
    local layer         = getattr(f,a_viewerlayer)
    local e             = dimenfactor(unit,font) -- what if no glyph node
    local rt            = tonumber(rulethickness)
    if rt then
        rulethickness = e * rulethickness / 2
    else
        local n, u = splitdimen(rulethickness)
        if n and u then -- we need to intercept ex and em and % and ...
            rulethickness = n * dimenfactor(u,fontdata[font]) / 2
        else
            rulethickness = 1/5
        end
    end
    --
    if level > max then
        level = max
    end
    if method == 0 then -- center
        offset = 2*offset
        m = (offset+(level-1)*dy)*e/2 + rulethickness/2
    else
        m = 0
    end

    local function inject(r,w,ht,dp)
        if layer then
            setattr(r,a_viewerlayer,layer)
        end
        if empty then
            head = insert_node_before(head,f,r)
            setlink(r,getnext(l))
            setprev(f)
            setnext(l)
            flushlist(f)
        else
            local k = new_kern(-w)
            if foreground then
                insert_node_after(head,l,k)
                insert_node_after(head,k,r)
                l = r
            else
                head = insert_node_before(head,f,r)
                insert_node_after(head,r,k)
            end
        end
        if trace_ruled then
            report_ruled("level %a, width %p, height %p, depth %p, nodes %a, text %a",
                level,w,ht,dp,n_tostring(f,l),n_tosequence(f,l,true))
        end
    end
    if mp and mp ~= "" then
        local r = usernutrule {
            width  = w,
            height = ht,
            depth  = dp,
            type   = "mp",
            factor = e,
            offset = offset,
            line   = rulethickness,
            data   = mp,
            ma     = colorspace,
            ca     = color,
            ta     = transparency,
        }
        inject(r,w,ht,dp)
    else
        local tx = d.text
        if tx then
            local l = copy_list(tx)
            if d["repeat"] == v_yes then
                l = new_leader(w,l)
                setattrlist(l,tx)
            end
            l = hpack_nodes(l,w,"exactly")
            inject(l,w,ht,dp)
        else
            for i=1,level do
                local ht =  (offset+(i-1)*dy)*e + rulethickness - m
                local dp = -(offset+(i-1)*dy)*e + rulethickness + m
                local r = new_rule(w,ht,dp)
                if color then
                    setattr(r,a_colormodel,colorspace)
                    setattr(r,a_color,color)
                end
                if transparency then
                    setattr(r,a_transparency,transparency)
                end
                inject(r,w,ht,dp)
            end
        end
    end
    return head
end

rules.handler = function(head)
    return processwords(a_ruled,data,flush_ruled,head)
end

function rules.enable()
    enableaction("shipouts","nodes.rules.handler")
end

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
    setprev(first)
    setnext(last)
    local width, height, depth = list_dimensions(parent,first,next)
    local list = hpack_nodes(first,width,"exactly") -- we can use a simple pack
    if first == head then
        head = list
    end
    if prev then
        setlink(prev,list)
    end
    if next then
        setlink(list,next)
    end
    local raise = data.dy * dimenfactor(data.unit,fontdata[getfont(first)])
    setshift(list,raise)
    setwhd(list,width,height,depth)
    if trace_shifted then
        report_shifted("width %p, nodes %a, text %a",width,n_tostring(first,last),n_tosequence(first,last,true))
    end
    return head
end

nodes.shifts.handler = function(head)
    return processwords(a_shifted,data,flush_shifted,head)
end

function nodes.shifts.enable()
    enableaction("shipouts","nodes.shifts.handler")
end

-- linefillers

nodes.linefillers      = nodes.linefillers      or { }
nodes.linefillers.data = nodes.linefillers.data or { }

storage.register("nodes/linefillers/data", nodes.linefillers.data, "nodes.linefillers.data")

local data = nodes.linefillers.data

function nodes.linefillers.define(settings)
    data[#data+1] = settings
    context(#data)
end

local function linefiller(current,data,width,location)
    local height = data.height
    local depth  = data.depth
    local mp     = data.mp
    local ma     = data.ma
    local ca     = data.ca
    local ta     = data.ta
    if mp and mp ~= "" then
        return usernutrule {
            width     = width,
            height    = height,
            depth     = depth,
            type      = "mp",
            line      = data.rulethickness,
            data      = mp,
            ma        = ma,
            ca        = ca,
            ta        = ta,
            option    = location,
            direction = getdir(current),
        }
    else
        local rule = new_rule(width,height,depth)
        if ca then
            setattr(rule,a_colorspace,ma)
            setattr(rule,a_color,ca)
        end
        if ta then
            setattr(rule,a_transparency,ta)
        end
        return rule
    end
end

function nodes.linefillers.filler(current,data,width,height,depth)
    if width and width > 0 then
        local height = height or data.height or 0
        local depth  = depth  or data.depth  or 0
        if (height + depth) ~= 0 then
            local mp = data.mp
            local ma = data.ma
            local ca = data.ca
            local ta = data.ta
            if mp and mp ~= "" then
                return usernutrule {
                    width     = width,
                    height    = height,
                    depth     = depth,
                    type      = "mp",
                    line      = data.rulethickness,
                    data      = mp,
                    ma        = ma,
                    ca        = ca,
                    ta        = ta,
                    option    = location,
                    direction = getdir(current),
                }
            else
                local rule = new_rule(width,height,depth)
                if ca then
                    setattr(rule,a_colorspace,ma)
                    setattr(rule,a_color,ca)
                end
                if ta then
                    setattr(rule,a_transparency,ta)
                end
                return rule
            end
        end
    end
end

local function find_attr(head,attr)
    while head do
        local a = head[attr]
        if a then
            return a, head
        end
        head = getnext(head)
    end
end

function nodes.linefillers.handler(head) -- traverse_list
    for current in nexthlist, head do -- LUATEXVERSION >= 1.090
        if getsubtype(current) == line_code then
            local list = getlist(current)
            if list then
                -- why doesn't leftskip take the attributes
                -- or list[linefiller] or maybe first match (maybe we need a fast helper for that)
                local a = getattr(current,a_linefiller)
                if a then
                    local class = a % 1000
                    local data  = data[class]
                    if data then
                        local location   = data.location
                        local scope      = data.scope
                        local distance   = data.distance
                        local threshold  = data.threshold
                        local leftlocal  = false
                        local rightlocal = false
                        --
                        if scope == v_right then
                            leftlocal = true
                        elseif scope == v_left then
                            rightlocal = true
                        elseif scope == v_local then
                            leftlocal  = true
                            rightlocal = true
                        end
                        --
                        if location == v_left or location == v_both then
                            local lskip = nil -- leftskip
                            local iskip = nil -- indentation
                            local head  = list
                            while head do
                                local id = getid(head)
                                if id == glue_code then
                                    if getsubtype(head) == leftskip_code then
                                        lskip = head
                                    else
                                        break
                                    end
                                elseif id == localpar_code or id == dir_code then
                                    -- go on
                                elseif id == hlist_code then
                                    if getsubtype(head) == indent_code then
                                        iskip = head
                                    end
                                    break
                                else
                                    break
                                end
                                head = getnext(head)
                            end
                            if head then
                                local indentation = iskip and getwidth(iskip) or 0
                                local leftfixed   = lskip and getwidth(lskip) or 0
                                local lefttotal   = lskip and effective_glue(lskip,current) or 0
                                local width = lefttotal - (leftlocal and leftfixed or 0) + indentation - distance
                                if width > threshold then
                                    if iskip then
                                        setwidth(iskip,0)
                                    end
                                    if lskip then
                                        setglue(lskip,leftlocal and getwidth(lskip) or nil)
                                        if distance > 0 then
                                            insert_node_after(list,lskip,new_kern(distance))
                                        end
                                        insert_node_after(list,lskip,linefiller(current,data,width,"left"))
                                    else
                                        insert_node_before(list,head,linefiller(current,data,width,"left"))
                                        if distance > 0 then
                                            insert_node_before(list,head,new_kern(distance))
                                        end
                                    end
                                end
                            end
                        end
                        --
                        if location == v_right or location == v_both then
                            local pskip = nil -- parfillskip
                            local rskip = nil -- rightskip
                            local tail  = find_tail(list)
                            while tail and getid(tail) == glue_code do
                                local subtype = getsubtype(tail)
                                if subtype == rightskip_code then
                                    rskip = tail
                                elseif subtype == parfillskip_code then
                                    pskip = tail
                                else
                                    break
                                end
                                tail = getprev(tail)
                            end
                            if tail then
                                local rightfixed = rskip and getwidth(rskip) or 0
                                local righttotal = rskip and effective_glue(rskip,current) or 0
                                local parfixed   = pskip and getwidth(pskip) or 0
                                local partotal   = pskip and effective_glue(pskip,current) or 0
                                local width = righttotal - (rightlocal and rightfixed or 0) + partotal - distance
                                if width > threshold then
                                    if pskip then
                                        setglue(pskip)
                                    end
                                    if rskip then
                                        setglue(rskip,rightlocal and getwidth(rskip) or nil)
                                        if distance > 0 then
                                            insert_node_before(list,rskip,new_kern(distance))
                                        end
                                        insert_node_before(list,rskip,linefiller(current,data,width,"right"))
                                    else
                                        insert_node_after(list,tail,linefiller(current,data,width,"right"))
                                        if distance > 0 then
                                            insert_node_after(list,tail,new_kern(distance))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return head
end

if LUATEXVERSION >= 1.090  then

    function nodes.linefillers.handler(head) -- traverse_list
        for current, subtype, list in nexthlist, head do -- LUATEXVERSION >= 1.090
            if list and subtype == line_code then
                -- why doesn't leftskip take the attributes
                -- or list[linefiller] or maybe first match (maybe we need a fast helper for that)
                local a = getattr(current,a_linefiller)
                if a then
                    local class = a % 1000
                    local data  = data[class]
                    if data then
                        local location   = data.location
                        local scope      = data.scope
                        local distance   = data.distance
                        local threshold  = data.threshold
                        local leftlocal  = false
                        local rightlocal = false
                        --
                        if scope == v_right then
                            leftlocal = true
                        elseif scope == v_left then
                            rightlocal = true
                        elseif scope == v_local then
                            leftlocal  = true
                            rightlocal = true
                        end
                        --
                        if location == v_left or location == v_both then
                            local lskip = nil -- leftskip
                            local iskip = nil -- indentation
                            local head  = list
                            while head do
                                local id = getid(head)
                                if id == glue_code then
                                    if getsubtype(head) == leftskip_code then
                                        lskip = head
                                    else
                                        break
                                    end
                                elseif id == localpar_code or id == dir_code then
                                    -- go on
                                elseif id == hlist_code then
                                    if getsubtype(head) == indent_code then
                                        iskip = head
                                    end
                                    break
                                else
                                    break
                                end
                                head = getnext(head)
                            end
                            if head then
                                local indentation = iskip and getwidth(iskip) or 0
                                local leftfixed   = lskip and getwidth(lskip) or 0
                                local lefttotal   = lskip and effective_glue(lskip,current) or 0
                                local width = lefttotal - (leftlocal and leftfixed or 0) + indentation - distance
                                if width > threshold then
                                    if iskip then
                                        setwidth(iskip,0)
                                    end
                                    if lskip then
                                        setglue(lskip,leftlocal and getwidth(lskip) or nil)
                                        if distance > 0 then
                                            insert_node_after(list,lskip,new_kern(distance))
                                        end
                                        insert_node_after(list,lskip,linefiller(current,data,width,"left"))
                                    else
                                        insert_node_before(list,head,linefiller(current,data,width,"left"))
                                        if distance > 0 then
                                            insert_node_before(list,head,new_kern(distance))
                                        end
                                    end
                                end
                            end
                        end
                        --
                        if location == v_right or location == v_both then
                            local pskip = nil -- parfillskip
                            local rskip = nil -- rightskip
                            local tail  = find_tail(list)
                            while tail and getid(tail) == glue_code do
                                local subtype = getsubtype(tail)
                                if subtype == rightskip_code then
                                    rskip = tail
                                elseif subtype == parfillskip_code then
                                    pskip = tail
                                else
                                    break
                                end
                                tail = getprev(tail)
                            end
                            if tail then
                                local rightfixed = rskip and getwidth(rskip) or 0
                                local righttotal = rskip and effective_glue(rskip,current) or 0
                                local parfixed   = pskip and getwidth(pskip) or 0
                                local partotal   = pskip and effective_glue(pskip,current) or 0
                                local width = righttotal - (rightlocal and rightfixed or 0) + partotal - distance
                                if width > threshold then
                                    if pskip then
                                        setglue(pskip)
                                    end
                                    if rskip then
                                        setglue(rskip,rightlocal and getwidth(rskip) or nil)
                                        if distance > 0 then
                                            insert_node_before(list,rskip,new_kern(distance))
                                        end
                                        insert_node_before(list,rskip,linefiller(current,data,width,"right"))
                                    else
                                        insert_node_after(list,tail,linefiller(current,data,width,"right"))
                                        if distance > 0 then
                                            insert_node_after(list,tail,new_kern(distance))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return head
    end

end

local enable = false

function nodes.linefillers.enable()
    if not enable then
    -- we could now nil it
        enableaction("finalizers","nodes.linefillers.handler")
        enable = true
    end
end

-- interface

implement {
    name      = "definerule",
    actions   = { rules.define, context },
    arguments = {
        {
            { "continue" },
            { "unit" },
            { "order" },
            { "method", "integer" },
            { "offset", "number" },
            { "rulethickness" },
            { "dy", "number" },
            { "max", "number" },
            { "ma", "integer" },
            { "ca", "integer" },
            { "ta", "integer" },
            { "mp" },
            { "empty" },
            { "text", "integer" },
            { "repeat" },
        }
    }
}

implement {
    name     = "enablerules",
    onlyonce = true,
    actions  = rules.enable
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

implement {
    name      = "definelinefiller",
    actions   = { nodes.linefillers.define, context },
    arguments = {
        {
            { "method", "integer" },
            { "location", "string" },
            { "scope", "string" },
            { "mp", "string" },
            { "ma", "integer" },
            { "ca", "integer" },
            { "ta", "integer" },
            { "depth", "dimension" },
            { "height", "dimension" },
            { "distance", "dimension" },
            { "threshold", "dimension" },
            { "rulethickness", "dimension" },
        }
    }
}

implement {
    name     = "enablelinefillers",
    onlyonce = true,
    actions  = nodes.linefillers.enable
}

-- We add a bonus feature here:

interfaces.implement {
    name      = "autorule",
    arguments = {
        {
            { "width", "dimension" },
            { "height", "dimension" },
            { "depth", "dimension" },
            { "left", "dimension" },
            { "right", "dimension" },
        },
    },
    actions   = function(t)
        local l = t.left
        local r = t.right
        local n = new_rule(
            t.width,
            t.height,
            t.depth
        )
        setattrlist(n,current_attr())
        if LUATEXFUNCTIONALITY >= 6710 then
            if l then
                setfield(n,"left",l)
            end
            if r then
                setfield(n,"right",r)
            end
        end
        context(tonode(n))
    end
}
