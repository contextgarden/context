if modules then modules = { } end modules ['typo-bld'] = { -- was node-par
    version   = 1.001,
    comment   = "companion to typo-bld.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- no need for nuts in the one-line demo (that might move anyway)

local insert, remove = table.insert, table.remove

builders                 = builders or { }
local builders           = builders

builders.paragraphs      = builders.paragraphs or { }
local parbuilders        = builders.paragraphs

parbuilders.constructors = parbuilders.constructors or { }
local       constructors = parbuilders.constructors

constructors.names       = constructors.names or { }
local names              = constructors.names

constructors.numbers     = constructors.numbers or { }
local numbers            = constructors.numbers

constructors.methods     = constructors.methods or { }
local methods            = constructors.methods

local a_parbuilder       = attributes.numbers['parbuilder'] or 999 -- why 999
constructors.attribute   = a_parbuilder

local unsetvalue         = attributes.unsetvalue
local texsetattribute    = tex.setattribute
local texnest            = tex.nest
local texlists           = tex.lists

local nodes              = nodes
local nodepool           = nodes.pool
local new_baselineskip   = nodepool.baselineskip
local new_lineskip       = nodepool.lineskip
local insert_node_before = nodes.insert_before
local hpack_node         = nodes.hpack

local starttiming        = statistics.starttiming
local stoptiming         = statistics.stoptiming

local registercallback   = callbacks.register

storage.register("builders/paragraphs/constructors/names",   names,   "builders.paragraphs.constructors.names")
storage.register("builders/paragraphs/constructors/numbers", numbers, "builders.paragraphs.constructors.numbers")

local trace_page_builder = false  trackers.register("builders.page", function(v) trace_page_builder = v end)
local trace_post_builder = false  trackers.register("builders.post", function(v) trace_post_builder = v end)

local report_par_builder  = logs.reporter("builders","par")
local report_page_builder = logs.reporter("builders","page")

local mainconstructor = nil -- not stored in format
local nofconstructors = 0
local stack           = { }

function constructors.define(name)
    nofconstructors = nofconstructors + 1
    names[nofconstructors] = name
    numbers[name] = nofconstructors
end

function constructors.set(name) --- will go
    if name then
        mainconstructor = numbers[name] or unsetvalue
    else
        mainconstructor = stack[#stack] or unsetvalue
    end
    texsetattribute(a_parbuilder,mainconstructor)
    if mainconstructor ~= unsetvalue then
        constructors.enable()
    end
end

function constructors.start(name)
    local number = numbers[name]
    insert(stack,number)
    mainconstructor = number or unsetvalue
    texsetattribute(a_parbuilder,mainconstructor)
    if mainconstructor ~= unsetvalue then
        constructors.enable()
    end
 -- report_par_builder("start %a",name)
end

function constructors.stop()
    remove(stack)
    mainconstructor = stack[#stack] or unsetvalue
    texsetattribute(a_parbuilder,mainconstructor)
    if mainconstructor == unsetvalue then
        constructors.disable()
    end
 -- report_par_builder("stop")
end

-- return values:
--
-- true  : tex will break itself
-- false : idem but dangerous
-- head  : list of valid vmode nodes with last being hlist

function constructors.handler(head,followed_by_display)
    if type(head) == "boolean" then
        return head
    else
        local attribute = head[a_parbuilder] -- or mainconstructor
        if attribute then
            local method = names[attribute]
            if method then
                local handler = methods[method]
                if handler then
                    return handler(head,followed_by_display)
                else
                    report_par_builder("contructor method %a is not defined",tostring(method))
                    return true -- let tex break
                end
            end
        end
        return true -- let tex break
    end
end

-- just for testing

function constructors.methods.default(head,followed_by_display)
    return true -- let tex break
end

-- also for testing (now also surrounding spacing done)

function builders.paragraphs.constructors.methods.oneline(head,followed_by_display)
    -- when needed we will turn this into a helper
    local t = texnest[texnest.ptr]
    local h = hpack_node(head)
    local d = tex.baselineskip.width - t.prevdepth - h.height
    t.prevdepth = h.depth
    t.prevgraf  = 1
    if d < tex.lineskiplimit then
        return insert_node_before(h,h,new_lineskip(tex.lineskip))
    else
        return insert_node_before(h,h,new_baselineskip(d))
    end
end

-- It makes no sense to have a sequence here as we already have
-- pre and post hooks and only one parbuilder makes sense, so no:
--
-- local actions = nodes.tasks.actions("parbuilders")
--
-- yet ... maybe some day.

local actions = constructors.handler
local enabled = false

local function processor(head,followed_by_display)
    -- todo: not again in otr so we need to flag
    if enabled then
        starttiming(parbuilders)
        local head = actions(head,followed_by_display)
        stoptiming(parbuilders)
        return head
    else
        return true -- let tex do the work
    end
end

function constructors.enable () enabled = true  end
function constructors.disable() enabled = false end

registercallback('linebreak_filter', processor, "breaking paragraps into lines")

statistics.register("linebreak processing time", function()
    return statistics.elapsedseconds(parbuilders)
end)

-- todo: move from nodes.builders to builders

nodes.builders = nodes.builder or { }
local builders = nodes.builders

local vboxactions = nodes.tasks.actions("vboxbuilders")

function builders.vpack_filter(head,groupcode,size,packtype,maxdepth,direction)
    local done = false
    if head then
        starttiming(builders)
        if trace_vpacking then
            local before = nodes.count(head)
            head, done = vboxactions(head,groupcode,size,packtype,maxdepth,direction)
            local after = nodes.count(head)
            if done then
                nodes.processors.tracer("vpack","changed",head,groupcode,before,after,true)
            else
                nodes.processors.tracer("vpack","unchanged",head,groupcode,before,after,true)
            end
        else
            head, done = vboxactions(head,groupcode)
        end
        stoptiming(builders)
    end
    return head, done
end

-- This one is special in the sense that it has no head and we operate on the mlv. Also,
-- we need to do the vspacing last as it removes items from the mvl.

local pageactions = nodes.tasks.actions("mvlbuilders")
----- lineactions = nodes.tasks.actions("linebuilders")

local function report(groupcode,head)
    report_page_builder("trigger: %s",groupcode)
    report_page_builder("  vsize    : %p",tex.vsize)
    report_page_builder("  pagegoal : %p",tex.pagegoal)
    report_page_builder("  pagetotal: %p",tex.pagetotal)
    report_page_builder("  list     : %s",head and nodeidstostring(head) or "<empty>")
end

-- use tex.[sg]etlist

-- check why box is called before after_linebreak .. maybe make categories and
-- call 'm less

-- this will be split into contribute_filter for these 4 so at some point
-- the check can go away

function builders.buildpage_filter(groupcode)
    -- the next check saves 1% runtime on 1000 tufte pages
    local head = texlists.contrib_head
    local done = false
    if head then
        -- called quite often ... maybe time to remove timing
        starttiming(builders)
        if trace_page_builder then
            report(groupcode,head)
        end
        head, done = pageactions(head,groupcode)
        stoptiming(builders)
     -- -- doesn't work here (not passed on?)
     -- tex.pagegoal = tex.vsize - tex.dimen.d_page_floats_inserted_top - tex.dimen.d_page_floats_inserted_bottom
        texlists.contrib_head = head or nil -- needs checking
     -- tex.setlist("contrib_head",head,head and nodes.tail(head))
        return done and head or true -- no return value needed
    else
        -- happens quite often
        if trace_page_builder then
            report(groupcode)
        end
        return nil, false -- no return value needed
    end
end

registercallback('vpack_filter',      builders.vpack_filter,      "vertical spacing etc")
registercallback('buildpage_filter',  builders.buildpage_filter,  "vertical spacing etc (mvl)")
----------------('contribute_filter', builders.contribute_filter, "adding content to lists")

statistics.register("v-node processing time", function()
    return statistics.elapsedseconds(builders)
end)

local implement = interfaces.implement

implement { name = "defineparbuilder",  actions = constructors.define, arguments = "string" }
implement { name = "setparbuilder",     actions = constructors.set,    arguments = "string" }
implement { name = "startparbuilder",   actions = constructors.start,  arguments = "string" }
implement { name = "stopparbuilder",    actions = constructors.stop    }
implement { name = "enableparbuilder",  actions = constructors.enable  }
implement { name = "disableparbuilder", actions = constructors.disable }

-- Here are some tracers:

local new_kern     = nodes.pool.kern
local new_rule     = nodes.pool.rule
local hpack        = nodes.hpack
local setcolor     = nodes.tracers.colors.set
local listtoutf    = nodes.listtoutf

local report_hpack = logs.reporter("hpack routine")
local report_vpack = logs.reporter("vpack routine")

-- overflow|badness w h d dir

local function vpack_quality(how,n,detail,first,last)
    if last <= 0 then
        report_vpack("%s vbox",how)
    elseif first > 0 and first < last then
        report_vpack("%s vbox at line %i - %i",how,first,last)
    else
        report_vpack("%s vbox at line %i",how,last)
    end
end

trackers.register("builders.vpack.quality",function(v)
    registercallback("vpack_quality",v and report_vpack_quality or nil,"check vpack quality")
end)

local report, show = false, false

local function hpack_quality(how,detail,n,first,last)
    if report then
        local str = listtoutf(n.head,"",true,nil,true)
        if last <= 0 then
            report_hpack("%s hbox: %s",how,str)
        elseif first > 0 and first < last then
            report_hpack("%s hbox at line %i - %i: %s",how,first,last,str)
        else
            report_hpack("%s hbox at line %i: %s",how,last,str)
        end
    end
    if show then
        local width  = 2*65536
        local height = n.height
        local depth  = n.depth
        local dir    = n.dir
        if height < 4*65526 then
            height = 4*65526
        end
        if depth < 2*65526 then
            depth = 2*65526
        end
        local rule = new_rule(width,height,depth)
        rule.dir = dir
        if how == "overfull" then
            setcolor(rule,"red")
            local kern = new_kern(-detail)
            kern.next = rule
            rule.prev = kern
            rule = kern
        elseif how == "underfull" then
            setcolor(rule,"blue")
        elseif how == "loose" then
            setcolor(rule,"magenta")
        elseif how == "tight" then
            setcolor(rule,"cyan")
        end
        rule = hpack(rule)
        rule.width = 0
        rule.dir = dir
        return rule
    end
end

trackers.register("builders.hpack.quality",function(v)
    report = v
    registercallback("hpack_quality",(report or show) and hpack_quality or nil,"check hpack quality")
end)

trackers.register("builders.hpack.overflow",function(v)
    show = v
    registercallback("hpack_quality",(report or show) and hpack_quality or nil,"check hpack quality")
end)

-- local ignoredepth = - 65536000
--
-- registercallback(
--     "append_to_vlist_filter",
--     function(box,location,prevdepth,mirrored),
--         if prevdepth > ignoredepth then
--             local b = tex.baselineskip
--             local d = b.width - prevdepth
--             local g = nil
--             if mirrored then
--                 d = d - box.depth
--             else
--                 d = d - box.height
--             end
--             if d < tex.lineskiplimit then
--                 g = nodes.pool.glue()
--                 g.spec = tex.lineskip
--             else
--                 g = nodes.pool.baselineskip(d)
--             end
--             g.next = box
--             box.prev = g
--             return g, mirrored and box.height or box.depth
--         else
--             return box, mirrored and box.height or box.depth
--         end
--     end,
--     "experimental prevdepth checking"
-- )
