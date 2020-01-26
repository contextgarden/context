if not modules then modules = { } end modules ['node-fin'] = {
    version   = 1.001,
    comment   = "companion to node-fin.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- this module is being reconstructed
-- local functions, only slightly slower
--
-- leaders are also triggers ... see colo-ext for an example (negate a box)

local next, type, format = next, type, string.format
local setmetatableindex = table.setmetatableindex

local attributes, nodes, node = attributes, nodes, node

local nuts               = nodes.nuts
local tonut              = nodes.tonut

local getnext            = nuts.getnext
local getid              = nuts.getid
local getlist            = nuts.getlist
local getleader          = nuts.getleader
local getattr            = nuts.getattr
local getwidth           = nuts.getwidth
local getwhd             = nuts.getwhd
local getorientation     = nuts.getorientation
local has_dimensions     = nuts.has_dimensions
local getbox             = nuts.getbox

local setlist            = nuts.setlist
local setleader          = nuts.setleader

local copy_node          = nuts.copy
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after

local nextnode           = nuts.traversers.node

local nodecodes          = nodes.nodecodes
local rulecodes          = nodes.rulecodes

local boxrule_code       = rulecodes.box
local imagerule_code     = rulecodes.image
local emptyrule_code     = rulecodes.empty

local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local glue_code          = nodecodes.glue
local rule_code          = nodecodes.rule
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist

local texlists           = tex.lists
local texgetnest         = tex.getnest

local states             = attributes.states
local numbers            = attributes.numbers
local a_trigger          = attributes.private('trigger')
local triggering         = false

local implement          = interfaces.implement

local starttiming        = statistics.starttiming
local stoptiming         = statistics.stoptiming
local loadstripped       = utilities.lua.loadstripped
local unsetvalue         = attributes.unsetvalue

-- these two will be like trackers

function states.enabletriggering () triggering = true  end
function states.disabletriggering() triggering = false end

implement { name = "enablestatetriggering",  actions = states.enabletriggering  }
implement { name = "disablestatetriggering", actions = states.disabletriggering }

nodes.plugindata = nil

-- inheritance: -0x7FFFFFFF -- we can best use nil and skip !

local template = [[
local plugin = nodes.plugindata
local starttiming = statistics.starttiming
local stoptiming = statistics.stoptiming
local namespace = plugin.namespace
local attribute = namespace.attribute or attributes.numbers[plugin.name]
local processor = plugin.processor
local initializer = plugin.initializer
local resolver = plugin.resolver
local finalizer = plugin.finalizer
local flusher = plugin.flusher
if not processor then
    return function(head)
        return head
    end
elseif initializer or finalizer or resolver then
    return function(head)
        starttiming(attributes)
        local used, inheritance
        if resolver then
            inheritance = resolver()
        end
        if initializer then
            initializer(namespace,attribute,head)
        end
        head = processor(namespace,attribute,head,inheritance)
        if finalizer then
            head, used = finalizer(namespace,attribute,head)
            if used and flusher then
                head = flusher(namespace,attribute,head,used)
            end
        end
        stoptiming(attributes)
        return head
    end
else
    return function(head)
        starttiming(attributes)
        head = processor(namespace,attribute,head)
        stoptiming(attributes)
        return head
    end
end
nodes.plugindata = nil
]]

function nodes.installattributehandler(plugin)
    nodes.plugindata = plugin
    return loadstripped(template)()
end

-- the injectors

local nsdata, nsnone, nslistwise, nsforced, nsselector, nstrigger
local current, current_selector = 0, 0 -- nb, stack has a local current !
local nsbegin, nsend, nsreset

function states.initialize(namespace,attribute,head)
    nsdata           = namespace.data
    nsnone           = namespace.none
    nsforced         = namespace.forced
    nsselector       = namespace.selector
    nslistwise       = namespace.listwise
    nstrigger        = triggering and namespace.triggering and a_trigger
    current          = 0
    current_selector = 0
    nsstep           = namespace.resolve_step
    if nsstep then
        nsreset      = namespace.resolve_reset
        nsbegin      = namespace.resolve_begin
        nsend        = namespace.resolve_end
        nspush       = namespace.push
        nspop        = namespace.pop
    end
end

function states.finalize(namespace,attribute,head) -- is this one ok?
    if current > 0 and nsnone then
        local id = getid(head)
        if id == hlist_code or id == vlist_code then
            local content = getlist(head)
            if content then
                local list = insert_node_before(content,content,copy_node(nsnone)) -- two return values
                if list ~= content then
                    setlist(head,list)
                end
            end
        else
            head = insert_node_before(head,head,copy_node(nsnone))
        end
        return head, true
    end
    return head, false
end

-- we need to deal with literals too (reset as well as oval)

local function process(attribute,head,inheritance,default) -- one attribute
    local check  = false
    local leader = nil
    for stack, id in nextnode, head do
        if id == glyph_code or id == disc_code then
            check = true
        elseif id == glue_code then
            leader = getleader(stack)
            if leader then
                check = true
            end
        elseif id == hlist_code or id == vlist_code then
            local content = getlist(stack)
            if content then
                -- tricky checking
                local outer
                if getorientation(stack) then
                    outer = getattr(stack,attribute)
                    if outer then
                        if default and outer == inheritance then
                            if current ~= default then
                                head    = insert_node_before(head,stack,copy_node(nsdata[default]))
                                current = default
                            end
                        elseif current ~= outer then
                            head    = insert_node_before(head,stack,copy_node(nsdata[c]))
                            current = outer
                        end
                    elseif default and inheritance then
                        if current ~= default then
                            head    = insert_node_before(head,stack,copy_node(nsdata[default]))
                            current = default
                        end
                    elseif current > 0 then
                        head    = insert_node_before(head,stack,copy_node(nsnone))
                        current = 0
                    end
                end
                -- begin nested --
                local list
                if nstrigger and getattr(stack,nstrigger) then
                    if not outer then
                        outer = getattr(stack,attribute)
                    end
                    if outer ~= inheritance then
                        list = process(attribute,content,inheritance,outer)
                    else
                        list = process(attribute,content,inheritance,default)
                    end
                else
                    list = process(attribute,content,inheritance,default)
                end
                if content ~= list then
                    setlist(stack,list)
                end
                -- end nested --
            end
        elseif id == rule_code then
            check = has_dimensions(stack)
        end
        -- much faster this way than using a check() and nested() function
        if check then
            local c = getattr(stack,attribute)
            if c then
                if default and c == inheritance then
                    if current ~= default then
                        head    = insert_node_before(head,stack,copy_node(nsdata[default]))
                        current = default
                    end
                elseif current ~= c then
                    head    = insert_node_before(head,stack,copy_node(nsdata[c]))
                    current = c
                end
                if leader then
                    local savedcurrent = current
                    local ci = getid(leader)
                    if ci == hlist_code or ci == vlist_code then
                        -- else we reset inside a box unneeded, okay, the downside is
                        -- that we trigger color in each repeated box, so there is room
                        -- for improvement here
                        current = 0
                    end
                    -- begin nested --
                    local list
                    if nstrigger and getattr(stack,nstrigger) then
                        local outer = getattr(stack,attribute)
                        if outer ~= inheritance then
                            list = process(attribute,leader,inheritance,outer)
                        else
                            list = process(attribute,leader,inheritance,default)
                        end
                    else
                        list = process(attribute,leader,inheritance,default)
                    end
                    if leader ~= list then
                        setleader(stack,list)
                    end
                    -- end nested --
                    current = savedcurrent
                    leader = false
                end
            elseif default and inheritance then
                if current ~= default then
                    head    = insert_node_before(head,stack,copy_node(nsdata[default]))
                    current = default
                end
            elseif current > 0 then
                head    = insert_node_before(head,stack,copy_node(nsnone))
                current = 0
            end
            check = false
        end
    end
    return head
end

states.process = function(namespace,attribute,head,default)
    return process(attribute,head,default)
end

-- we can force a selector, e.g. document wide color spaces, saves a little
-- watch out, we need to check both the selector state (like colorspace) and
-- the main state (like color), otherwise we get into troubles when a selector
-- state changes while the main state stays the same (like two glyphs following
-- each other with the same color but different color spaces e.g. \showcolor)

local function selective(attribute,head,inheritance,default) -- two attributes
    local check  = false
    local leader = nil
    for stack, id, subtype in nextnode, head do
        if id == glyph_code or id == disc_code then
            check = true
        elseif id == glue_code then
            leader = getleader(stack)
            if leader then
                check = true
            end
        elseif id == hlist_code or id == vlist_code then
            local content = getlist(stack)
            if content then
                -- tricky checking
                local outer
                if getorientation(stack) then
                    outer = getattr(stack,attribute)
                    if outer then
                        if default and outer == inheritance then
                            if current ~= default then
                                local data = nsdata[default]
                                head = insert_node_before(head,stack,copy_node(data[nsforced or getattr(stack,nsselector) or nsselector]))
                                current = default
                            end
                        else
                            local s = getattr(stack,nsselector)
                         -- local s = nsforced or getattr(stack,nsselector)
                            if current ~= outer or current_selector ~= s then
                                local data = nsdata[outer]
                                head = insert_node_before(head,stack,copy_node(data[nsforced or s or nsselector]))
                                current = outer
                                current_selector = s
                            end
                        end
                    elseif default and inheritance then
                        if current ~= default then
                            local data = nsdata[default]
                            head    = insert_node_before(head,stack,copy_node(data[nsforced or getattr(stack,nsselector) or nsselector]))
                            current = default
                        end
                    elseif current > 0 then
                        head = insert_node_before(head,stack,copy_node(nsnone))
                        current, current_selector = 0, 0
                    end
                end
                -- begin nested
                local list
                if nstrigger and getattr(stack,nstrigger) then
                    if not outer then
                        outer = getattr(stack,attribute)
                    end
                    if outer ~= inheritance then
                        list = selective(attribute,content,inheritance,outer)
                    else
                        list = selective(attribute,content,inheritance,default)
                    end
                else
                    list = selective(attribute,content,inheritance,default)
                end
                if content ~= list then
                    setlist(stack,list)
                end
                -- end nested
            end
        elseif id == rule_code then
            if subtype == boxrule_code or subtype == imagerule_code or subtype == emptyrule_code then
                -- so no redundant color stuff (only here, layers for instance should obey)
                check = false
            else
                check = has_dimensions(stack)
            end
        end
        if check then
            local c = getattr(stack,attribute)
            if c then
                if default and c == inheritance then
                    if current ~= default then
                        local data = nsdata[default]
                        head = insert_node_before(head,stack,copy_node(data[nsforced or getattr(stack,nsselector) or nsselector]))
                        current = default
                    end
                else
                    local s = getattr(stack,nsselector)
                 -- local s = nsforced or getattr(stack,nsselector)
                    if current ~= c or current_selector ~= s then
                        local data = nsdata[c]
                        head = insert_node_before(head,stack,copy_node(data[nsforced or s or nsselector]))
                        current = c
                        current_selector = s
                    end
                end
                if leader then
                    -- begin nested
                    local list
                    if nstrigger and getattr(stack,nstrigger) then
                        local outer = getattr(stack,attribute)
                        if outer ~= inheritance then
                            list = selective(attribute,leader,inheritance,outer)
                        else
                            list = selective(attribute,leader,inheritance,default)
                        end
                    else
                        list = selective(attribute,leader,inheritance,default)
                    end
                    if leader ~= list then
                        setleader(stack,list)
                    end
                    -- end nested
                    leader = false
                end
            elseif default and inheritance then
                if current ~= default then
                    local data = nsdata[default]
                    head    = insert_node_before(head,stack,copy_node(data[nsforced or getattr(stack,nsselector) or nsselector]))
                    current = default
                end
            elseif current > 0 then
                head = insert_node_before(head,stack,copy_node(nsnone))
                current, current_selector = 0, 0
            end
            check = false
        end
    end
    return head
end

states.selective = function(namespace,attribute,head,default)
    return selective(attribute,head,default)
end

-- Ideally the next one should be merged with the previous but keeping it separate is
-- safer. We deal with two situations: efficient boxwise (layoutareas) and mixed layers
-- (as used in the stepper). In the stepper we cannot use the box branch as it involves
-- paragraph lines and then gets mixed up. A messy business (esp since we want to be
-- efficient).
--
-- Todo: make a better stacker. Keep track (in attribute) about nesting level. Not
-- entirely trivial and a generic solution is nicer (compares to the exporter).

local function stacked(attribute,head,default) -- no triggering, no inheritance, but list-wise
    local stack   = head
    local current = default or 0
    local depth   = 0
    local check   = false
    local leader  = false
    while stack do
        local id = getid(stack)
        if id == glyph_code then
            check = true
        elseif id == glue_code then
            leader = getleader(stack)
            if leader then
                check = true
            end
        elseif id == hlist_code or id == vlist_code then
            local content = getlist(stack)
            if content then
             -- the problem is that broken lines gets the attribute which can be a later one
                local list
                if nslistwise then
                    local a = getattr(stack,attribute)
                    if a and current ~= a and nslistwise[a] then -- viewerlayer / needs checking, see below
                        local p = current
                        current = a
                        head    = insert_node_before(head,stack,copy_node(nsdata[a]))
                        list    = stacked(attribute,content,current) -- two return values
                        head, stack = insert_node_after(head,stack,copy_node(nsnone))
                        current = p
                    else
                        list = stacked(attribute,content,current)
                    end
                else
                    list = stacked(attribute,content,current)
                end
                if content ~= list then
                    setlist(stack,list) -- only if ok
                end
            end
        elseif id == rule_code then
            check = has_dimensions(stack)
        end
        if check then
            local a = getattr(stack,attribute)
            if a then
                if current ~= a then
                    head    = insert_node_before(head,stack,copy_node(nsdata[a]))
                    depth   = depth + 1
                    current = a
                end
                if leader then
                    local content = getlist(leader)
                    if content then
                        local list = stacked(attribute,content,current)
                        if leader ~= list then
                            setleader(stack,list) -- only if ok
                        end
                    end
                    leader = false
                end
            elseif default > 0 then
                --
            elseif current > 0 then
                head    = insert_node_before(head,stack,copy_node(nsnone))
                depth   = depth - 1
                current = 0
            end
            check = false
        end
        stack = getnext(stack)
    end
    while depth > 0 do
        head = insert_node_after(head,stack,copy_node(nsnone))
        depth = depth - 1
    end
    return head
end

states.stacked = function(namespace,attribute,head,default)
    return stacked(attribute,head,default)
end

-- experimental

local function stacker(attribute,head,default) -- no triggering, no inheritance, but list-wise

 -- nsbegin()
    local stacked  = false

    local current  = head
    local previous = head
    local attrib   = default or unsetvalue
    local check    = false
    local leader   = false

    while current do
        local id = getid(current)
        if id == glyph_code then
            check = true
        elseif id == glue_code then
            leader = getleader(current)
            if leader then
                check = true
            end
        elseif id == hlist_code or id == vlist_code then
            local content = getlist(current)
            if content then
                local list
                if nslistwise then
                    local a = getattr(current,attribute)
                    if a and attrib ~= a and nslistwise[a] then -- viewerlayer
                        head = insert_node_before(head,current,copy_node(nsdata[a]))
                        list = stacker(attribute,content,a)
                        if list ~= content then
                            setlist(current,list)
                        end
                        head, current = insert_node_after(head,current,copy_node(nsnone))
                    else
                        list = stacker(attribute,content,attrib)
                        if list ~= content then
                            setlist(current,list)
                        end
                    end
                else
                    list = stacker(attribute,content,default)
                    if list ~= content then
                        setlist(current,list)
                    end
                end
            end
        elseif id == rule_code then
            check = has_dimensions(current)
        end

        if check then
            local a = getattr(current,attribute) or unsetvalue
            if a ~= attrib then
                if not stacked then
                    stacked = true
                    nsbegin()
                end
                local n = nsstep(a)
                if n then
                    head = insert_node_before(head,current,n) -- a
                end
                attrib = a
                if leader then
                    -- tricky as a leader has to be a list so we cannot inject before
                 -- local list = stacker(attribute,leader,attrib)
                 -- leader = false

                    local content = getlist(leader)
                    if content then
                        local list = stacker(attribute,leader,attrib)
                        if leader ~= list then
                            setleader(current,list)
                        end
                    end

                    leader = false
                end
            end
            check = false
        end

        previous = current
        current = getnext(current)
    end

    if stacked then
        local n = nsend()
        while n do
            head = insert_node_after(head,previous,n)
            n = nsend()
        end
    end

    return head
end

states.stacker = function(namespace,attribute,head,default)
    local head = stacker(attribute,head,default)
    nsreset()
    return head
end

-- -- --

statistics.register("attribute processing time", function()
    return statistics.elapsedseconds(attributes,"front- and backend")
end)

-- -- --

do

    local cleaners = { }
    local trace    = true -- false

    function attributes.cleanup()
        if next(cleaners) then
            local values = setmetatableindex("table")

            if trace then
                starttiming(values)
            end

            local function check(l)
                for n, id in nextnode, l do
                    if id == hlist_code or id == vlist_code or id == glue_code then
                        local l = getlist(n)
                        if l then
                            check(l)
                        end
                    end
                    for a in next, cleaners do
                        local v = getattr(n,a)
                        if v then
                         -- values[a] = values[a] + 1
                            values[a][v] = true
                        end
                    end
                end
            end

            local top = texgetnest("ptr")
            for i=1,top do
                local l = texgetnest(i)
                if l then
                    check(tonut(l.head))
                end
            end

            do local l
                l = tonut(texlists.page_ins_head)       if l then check(l) end
                l = tonut(texlists.contrib_head)        if l then check(l) end
                l = tonut(texlists.page_discards_head)  if l then check(l) end
                l = tonut(texlists.split_discards_head) if l then check(l) end
                l = tonut(texlists.page_head)           if l then check(l) end
            end

            -- todo: traverseboxes

            for i=0,65535 do
                local b = getbox(i)
                if b then
                    local l = getlist(b)
                    if l then
                        check(l)
                    end
                end
            end

            for a, t in next, values do
                cleaners[a](a,t)
            end

            if trace then
                stoptiming(values)
                local a = table.sortedkeys(values)
                local t = statistics.elapsedtime(values)
                local r = tex.getcount("realpageno")
                if #a == 0 then
                    logs.report("attributes","cleaning up at page %i took %s seconds, no attributes",r,t)
                else
                    logs.report("attributes","cleaning up at page %i took %s seconds, attributes: % t",r,t,a)
                end
            end
        end
    end

    -- not yet used but when we do ... delay a call till we enable it (attr-ini.mkiv)

    -- local function show(a,t) for k, v in next, t do print(a,k) end end
    --
    -- attributes.registercleaner(  1, show)
    -- attributes.registercleaner(  2, show)

    function attributes.registercleaner(a,f)
        cleaners[a] = f
    end

    implement {
        name    = "cleanupattributes",
        actions = attributes.cleanup,
    }

end
