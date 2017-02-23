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

local attributes, nodes, node = attributes, nodes, node

local nuts               = nodes.nuts
local tonode             = nuts.tonode
local tonut              = nuts.tonut

local getfield           = nuts.getfield
local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getlist            = nuts.getlist
local getleader          = nuts.getleader
local getattr            = nuts.getattr
local getwidth           = nuts.getwidth

local setlist            = nuts.setlist
local setleader          = nuts.setleader

local copy_node          = nuts.copy
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after

local nodecodes          = nodes.nodecodes
local whatcodes          = nodes.whatcodes
local rulecodes          = nodes.rulecodes

local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local glue_code          = nodecodes.glue
local rule_code          = nodecodes.rule
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist

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
        return head, false
    end
elseif initializer or finalizer or resolver then
    return function(head)
        starttiming(attributes)
        local done, used, ok, inheritance = false, nil, false, nil
        if resolver then
            inheritance = resolver()
        end
        if initializer then
            initializer(namespace,attribute,head)
        end
        head, ok = processor(namespace,attribute,head,inheritance)
        if ok then
            if finalizer then
                head, ok, used = finalizer(namespace,attribute,head)
                if used and flusher then
                    head = flusher(namespace,attribute,head,used)
                end
            end
            done = true
        end
        stoptiming(attributes)
        return head, done
    end
else
    return function(head)
        starttiming(attributes)
        local head, done = processor(namespace,attribute,head)
        stoptiming(attributes)
        return head, done
    end
end
nodes.plugindata = nil
]]

function nodes.installattributehandler(plugin)
    nodes.plugindata = plugin
    return loadstripped(template)()
end

-- for the moment:

local function copied(n)
    return copy_node(tonut(n))
end

-- the injectors

local nsdata, nsnone, nslistwise, nsforced, nsselector, nstrigger
local current, current_selector, done = 0, 0, false -- nb, stack has a local current !
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
    done             = false -- todo: done cleanup
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
        head = tonut(head)
        local id = getid(head)
        if id == hlist_code or id == vlist_code then
            local content = getlist(head)
            if content then
                local list = insert_node_before(content,content,copied(nsnone)) -- two return values
                if list ~= content then
                    setlist(head,list)
                end
            end
        else
            head = insert_node_before(head,head,copied(nsnone))
        end
        return tonode(head), true, true
    end
    return head, false, false
end

-- we need to deal with literals too (reset as well as oval)

local function process(namespace,attribute,head,inheritance,default) -- one attribute
    local stack  = head
    local done   = false
    local check  = false
    local leader = nil
    while stack do
        local id = getid(stack)
        if id == glyph_code then
            check = true
        elseif id == disc_code then
            check = true -- no longer needed as we flatten replace
        elseif id == glue_code then
            leader = getleader(stack)
            if leader then
                check = true
            end
        elseif id == hlist_code or id == vlist_code then
            local content = getlist(stack)
            if content then
                -- begin nested --
                if nstrigger and getattr(stack,nstrigger) then
                    local outer = getattr(stack,attribute)
                    if outer ~= inheritance then
                        local list, ok = process(namespace,attribute,content,inheritance,outer)
                        if content ~= list then
                            setlist(stack,list)
                        end
                        if ok then
                            done = true
                        end
                    else
                        local list, ok = process(namespace,attribute,content,inheritance,default)
                        if content ~= list then
                            setlist(stack,list)
                        end
                        if ok then
                            done = true
                        end
                    end
                else
                    local list, ok = process(namespace,attribute,content,inheritance,default)
                    if content ~= list then
                        setlist(stack,list)
                    end
                    if ok then
                        done = true
                    end
                end
                -- end nested --
            end
        elseif id == rule_code then
            check = getwidth(stack) ~= 0
        end
        -- much faster this way than using a check() and nested() function
        if check then
            local c = getattr(stack,attribute)
            if c then
                if default and c == inheritance then
                    if current ~= default then
                        head    = insert_node_before(head,stack,copied(nsdata[default]))
                        current = default
                        done    = true
                    end
                elseif current ~= c then
                    head    = insert_node_before(head,stack,copied(nsdata[c]))
                    current = c
                    done    = true
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
                    if nstrigger and getattr(stack,nstrigger) then
                        local outer = getattr(stack,attribute)
                        if outer ~= inheritance then
                            local list, ok = process(namespace,attribute,leader,inheritance,outer)
                            if leader ~= list then
                                setleader(stack,list)
                            end
                            if ok then
                                done = true
                            end
                        else
                            local list, ok = process(namespace,attribute,leader,inheritance,default)
                            if leader ~= list then
                                setleader(stack,list)
                            end
                            if ok then
                                done = true
                            end
                        end
                    else
                        local list, ok = process(namespace,attribute,leader,inheritance,default)
                        if leader ~= list then
                            setleader(stack,list)
                        end
                        if ok then
                            done = true
                        end
                    end
                    -- end nested --
                    current = savedcurrent
                    leader = false
                end
            elseif default and inheritance then
                if current ~= default then
                    head    = insert_node_before(head,stack,copied(nsdata[default]))
                    current = default
                    done    = true
                end
            elseif current > 0 then
                head    = insert_node_before(head,stack,copied(nsnone))
                current = 0
                done    = true
            end
            check = false
        end
        stack = getnext(stack)
    end
    return head, done
end

states.process = function(namespace,attribute,head,default)
    local head, done = process(namespace,attribute,tonut(head),default)
    return tonode(head), done
end

-- we can force a selector, e.g. document wide color spaces, saves a little
-- watch out, we need to check both the selector state (like colorspace) and
-- the main state (like color), otherwise we get into troubles when a selector
-- state changes while the main state stays the same (like two glyphs following
-- each other with the same color but different color spaces e.g. \showcolor)

local function selective(namespace,attribute,head,inheritance,default) -- two attributes
    local stack  = head
    local done   = false
    local check  = false
    local leader = nil
    while stack do
        local id = getid(stack)
        if id == glyph_code then
            check = true
        elseif id == disc_code then
            check = true -- not needed when we flatten replace
        elseif id == glue_code then
            leader = getleader(stack)
            if leader then
                check = true
            end
        elseif id == hlist_code or id == vlist_code then
            local content = getlist(stack)
            if content then
                -- begin nested
                if nstrigger and getattr(stack,nstrigger) then
                    local outer = getattr(stack,attribute)
                    if outer ~= inheritance then
                        local list, ok = selective(namespace,attribute,content,inheritance,outer)
                        if content ~= list then
                            setlist(stack,list)
                        end
                        if ok then
                            done = true
                        end
                    else
                        local list, ok = selective(namespace,attribute,content,inheritance,default)
                        if content ~= list then
                            setlist(stack,list)
                        end
                        if ok then
                            done = true
                        end
                    end
                else
                    local list, ok = selective(namespace,attribute,content,inheritance,default)
                    if content ~= list then
                        setlist(stack,list)
                    end
                    if ok then
                        done = true
                    end
                end
                -- end nested
            end
        elseif id == rule_code then
            check = getwidth(stack) ~= 0
        end

        if check then
            local c = getattr(stack,attribute)
            if c then
                if default and c == inheritance then
                    if current ~= default then
                        local data = nsdata[default]
                        head = insert_node_before(head,stack,copied(data[nsforced or getattr(stack,nsselector) or nsselector]))
                        current = default
                        if ok then
                            done = true
                        end
                    end
                else
                    local s = getattr(stack,nsselector)
                    if current ~= c or current_selector ~= s then
                        local data = nsdata[c]
                        head = insert_node_before(head,stack,copied(data[nsforced or getattr(stack,nsselector) or nsselector]))
                        current = c
                        current_selector = s
                        if ok then
                            done = true
                        end
                    end
                end
                if leader then
                    -- begin nested
                    if nstrigger and getattr(stack,nstrigger) then
                        local outer = getatribute(stack,attribute)
                        if outer ~= inheritance then
                            local list, ok = selective(namespace,attribute,leader,inheritance,outer)
                            if leader ~= list then
                                setleader(stack,list)
                            end
                            if ok then
                                done = true
                            end
                        else
                            local list, ok = selective(namespace,attribute,leader,inheritance,default)
                            if leader ~= list then
                                setleader(stack,list)
                            end
                            if ok then
                                done = true
                            end
                        end
                    else
                        local list, ok = selective(namespace,attribute,leader,inheritance,default)
                        if leader ~= list then
                            setleader(stack,list)
                        end
                        if ok then
                            done = true
                        end
                    end
                    -- end nested
                    leader = false
                end
            elseif default and inheritance then
                if current ~= default then
                    local data = nsdata[default]
                    head    = insert_node_before(head,stack,copied(data[nsforced or getattr(stack,nsselector) or nsselector]))
                    current = default
                    done    = true
                end
            elseif current > 0 then
                head = insert_node_before(head,stack,copied(nsnone))
                current, current_selector, done = 0, 0, true
            end
            check = false
        end
        stack = getnext(stack)
    end
    return head, done
end

states.selective = function(namespace,attribute,head,default)
    local head, done = selective(namespace,attribute,tonut(head),default)
    return tonode(head), done
end

-- Ideally the next one should be merged with the previous but keeping it separate is
-- safer. We deal with two situations: efficient boxwise (layoutareas) and mixed layers
-- (as used in the stepper). In the stepper we cannot use the box branch as it involves
-- paragraph lines and then gets mixed up. A messy business (esp since we want to be
-- efficient).
--
-- Todo: make a better stacker. Keep track (in attribute) about nesting level. Not
-- entirely trivial and a generic solution is nicer (compares to the exporter).

local function stacked(namespace,attribute,head,default) -- no triggering, no inheritance, but list-wise
    local stack   = head
    local done    = false
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
                if nslistwise then
                    local a = getattr(stack,attribute)
                    if a and current ~= a and nslistwise[a] then -- viewerlayer / needs checking, see below
                        local p = current
                        current = a
                        head    = insert_node_before(head,stack,copied(nsdata[a]))
                        local list = stacked(namespace,attribute,content,current) -- two return values
                        if content ~= list then
                            setlist(stack,list)
                        end
                        head, stack = insert_node_after(head,stack,copied(nsnone))
                        current = p
                        done    = true
                    else
                        local list, ok = stacked(namespace,attribute,content,current)
                        if content ~= list then
                            setlist(stack,list) -- only if ok
                        end
                        if ok then
                            done = true
                        end
                    end
                else
                    local list, ok = stacked(namespace,attribute,content,current)
                    if content ~= list then
                        setlist(stack,list) -- only if ok
                    end
                    if ok then
                        done = true
                    end
                end
            end
        elseif id == rule_code then
            check = getwidth(stack) ~= 0
        end

        if check then
            local a = getattr(stack,attribute)
            if a then
                if current ~= a then
                    head    = insert_node_before(head,stack,copied(nsdata[a]))
                    depth   = depth + 1
                    current = a
                    done    = true
                end
                if leader then
                    local list, ok = stacked(namespace,attribute,content,current)
                    if leader ~= list then
                        setleader(stack,list) -- only if ok
                    end
                    if ok then
                        done = true
                    end
                    leader = false
                end
            elseif default > 0 then
                --
            elseif current > 0 then
                head    = insert_node_before(head,stack,copied(nsnone))
                depth   = depth - 1
                current = 0
                done    = true
            end
            check = false
        end
        stack = getnext(stack)
    end
    while depth > 0 do
        head = insert_node_after(head,stack,copied(nsnone))
        depth = depth - 1
    end
    return head, done
end

states.stacked = function(namespace,attribute,head,default)
    local head, done = stacked(namespace,attribute,tonut(head),default)
    return tonode(head), done
end

-- experimental

local function stacker(namespace,attribute,head,default) -- no triggering, no inheritance, but list-wise

--     nsbegin()
    local stacked  = false

    local current  = head
    local previous = head
    local done     = false
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
            if not content then
                -- skip
            elseif nslistwise then
                local a = getattr(current,attribute)
                if a and attrib ~= a and nslistwise[a] then -- viewerlayer
                    head = insert_node_before(head,current,copied(nsdata[a]))
                    local list = stacker(namespace,attribute,content,a)
                    if list ~= content then
                        setlist(current,list)
                    end
                    done = true
                    head, current = insert_node_after(head,current,copied(nsnone))
                else
                    local list, ok = stacker(namespace,attribute,content,attrib)
                    if content ~= list then
                        setlist(current,list)
                    end
                    if ok then
                        done = true
                    end
                end
            else
                local list, ok = stacker(namespace,attribute,content,default)
                if list ~= content then
                    setlist(current,list)
                end
                if ok then
                    done = true
                end
            end
        elseif id == rule_code then
            check = getwidth(current) ~= 0
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
                    head = insert_node_before(head,current,tonut(n)) -- a
                end
                attrib = a
                done   = true
                if leader then
                    -- tricky as a leader has to be a list so we cannot inject before
                    local list, ok = stacker(namespace,attribute,leader,attrib)
                    if ok then
                        done = true
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
        head = insert_node_after(head,previous,tonut(n))
        n = nsend()
    end

end

    return head, done
end

states.stacker = function(namespace,attribute,head,default)
    local head, done = stacker(namespace,attribute,tonut(head),default)
    nsreset()
    return tonode(head), done
end

-- -- --

statistics.register("attribute processing time", function()
    return statistics.elapsedseconds(attributes,"front- and backend")
end)
