if not modules then modules = { } end modules ['node-tsk'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This might move to task-* and become less code as in sequencers
-- we already have dirty flags as well. On the other hand, nodes are
-- rather specialized and here we focus on node related tasks.

local format = string.format

local trace_tasks = false  trackers.register("tasks.creation", function(v) trace_tasks = v end)

local report_tasks  = logs.reporter("tasks")

local allocate      = utilities.storage.allocate

local context       = context
local nodes         = nodes

local tasks         = nodes.tasks or { }
nodes.tasks         = tasks

local tasksdata     = { } -- no longer public

local sequencers    = utilities.sequencers
local compile       = sequencers.compile
local nodeprocessor = sequencers.nodeprocessor

local newsequencer  = sequencers.new

local appendgroup   = sequencers.appendgroup
----- prependgroup  = sequencers.prependgroup
----- replacegroup  = sequencers.replacegroup
local enablegroup   = sequencers.enablegroup
local disablegroup  = sequencers.disablegroup

local appendaction  = sequencers.appendaction
local prependaction = sequencers.prependaction
local replaceaction = sequencers.replaceaction
local enableaction  = sequencers.enableaction
local disableaction = sequencers.disableaction

local frozengroups  = "no"

function tasks.freeze(kind)
    frozengroups = kind or "tolerant" -- todo: hook into jobname
end

function tasks.new(specification) -- was: name,arguments,list
    local name      = specification.name
    local sequence  = specification.sequence
    if name and sequence then
        local tasklist = newsequencer {
            name = name
            -- we can move more to the sequencer now .. todo
        }
        tasksdata[name] = {
            name      = name,
            list      = tasklist,
            runner    = false,
            frozen    = { },
            processor = specification.processor or nodeprocessor,
            -- could be metatable but best freeze it
            arguments = specification.arguments or 0,
            templates = specification.templates,
        }
        for l=1,#sequence do
            appendgroup(tasklist,sequence[l])
        end
    end
end

local function valid(name)
    local data = tasksdata[name]
    if not data then
        report_tasks("unknown task %a",name)
    else
        return data
    end
end

local function validgroup(name,group,what)
    local data = tasksdata[name]
    if not data then
        report_tasks("unknown task %a",name)
    else
        local frozen = data.frozen[group]
        if frozen then
            if frozengroup == "no" then
                -- default
            elseif frozengroup == "strict" then
                report_tasks("warning: group %a of task %a is frozen, %a applied but not supported",group,name,what)
                return
            else -- if frozengroup == "tolerant" then
                report_tasks("warning: group %a of task %a is frozen, %a ignored",group,name,what)
            end
        end
        return data
    end
end

function tasks.freezegroup(name,group)
    local data = valid(name)
    if data then
        data.frozen[group] = true
    end
end

function tasks.restart(name)
    local data = valid(name)
    if data then
        data.runner = false
    end
end

function tasks.enableaction(name,action)
    local data = valid(name)
    if data then
        enableaction(data.list,action)
        data.runner = false
    end
end

function tasks.disableaction(name,action)
    local data = valid(name)
    if data then
        disableaction(data.list,action)
        data.runner = false
    end
end

function tasks.replaceaction(name,group,oldaction,newaction)
    local data = valid(name)
    if data then
        replaceaction(data.list,group,oldaction,newaction)
        data.runner = false
    end
end

do

    local enableaction  = tasks.enableaction
    local disableaction = tasks.disableaction

    function tasks.setaction(name,action,value)
        if value then
            enableaction(name,action)
        else
            disableaction(name,action)
        end
    end

end

function tasks.enablegroup(name,group)
    local data = validgroup(name,"enable group")
    if data then
        enablegroup(data.list,group)
        data.runner = false
    end
end

function tasks.disablegroup(name,group)
    local data = validgroup(name,"disable group")
    if data then
        disablegroup(data.list,group)
        data.runner = false
    end
end

function tasks.appendaction(name,group,action,where,kind,state)
    local data = validgroup(name,"append action")
    if data then
        local list = data.list
        appendaction(list,group,action,where,kind)
        if state == "disabled" or (state == "production" and environment.initex) then
            disableaction(list,action)
        end
        data.runner = false
    end
end

function tasks.prependaction(name,group,action,where,kind,state)
    local data = validgroup(name,"prepend action")
    if data then
        local list = data.list
        prependaction(list,group,action,where,kind)
        if state == "disabled" or (state == "production" and environment.initex) then
            disableaction(list,action)
        end
        data.runner = false
    end
end

function tasks.removeaction(name,group,action)
    local data = validgroup(name,"remove action")
    if data then
        removeaction(data.list,group,action)
        data.runner = false
    end
end

function tasks.showactions(name,group,action,where,kind)
    local data = valid(name)
    if data then
        report_tasks("task %a, list:\n%s",name,nodeprocessor(data.list))
    end
end

-- Optimizing for the number of arguments makes sense, but getting rid of
-- the nested call (no problem but then we also need to register the
-- callback with this mechanism so that it gets updated) does not save
-- much time (24K calls on mk.tex).

local created, total = 0, 0

statistics.register("node list callback tasks", function()
    if total > 0 then
        return format("%s unique task lists, %s instances (re)created, %s calls",table.count(tasksdata),created,total)
    else
        return nil
    end
end)

local function create(data,t)
    created = created + 1
    local runner = compile(data.list,data.processor,t)
    if trace_tasks then
        report_tasks("creating runner %a, %i actions enabled",t.name,data.list.steps or 0)
    end
    data.runner = runner
    return runner
end

function tasks.actions(name)
    local data = tasksdata[name]
    if data then
        local t = data.templates
        if t then
            t.name = data.name
            return function(...)
                total = total + 1
                return (data.runner or create(data,t))(...)
            end
        end
    end
    return nil
end

function tasks.table(name) --maybe move this to task-deb.lua
    local tsk = tasksdata[name]
    local lst = tsk and tsk.list
    local HL, NC, NR, bold, type = context.HL, context.NC, context.NR, context.bold, context.type
    if lst then
        local list, order = lst.list, lst.order
        if list and order then
            context.starttabulate { "|l|l|" }
            NC() bold("category") NC() bold("function") NC() NR()
            for i=1,#order do
                HL()
                local o = order[i]
                local l = list[o]
                if #l == 0 then
                    NC() type(o) NC() context("unset") NC() NR()
                else
                    local done = false
                    for k, v in table.sortedhash(l) do
                        NC() if not done then type(o) done = true end NC() type(v) NC() NR()
                    end
                end
            end
            context.stoptabulate()
        end
    end
end

-- -- shipouts everypar -- --

-- the shipout handlers acts on boxes so we don't need to return something
-- and also don't need to keep the state (done)

local templates = {

default = [[
return function(head)
    return head
end
]],

process = [[
local tonut  = nodes.tonut
local tonode = nodes.nuts.tonode

%localize%

return function(head)
    local nuthead = tonut(head)

%actions%
    return tonode(nuthead)
end
]],

step = [[
    nuthead = tonut((%action%(tonode(nuthead))))
]],

nut  = [[
    nuthead = %action%(nuthead)
]],

nohead = [[
    %action%(tonode(nuthead))
]],

nonut = [[
    %action%(nuthead)
]],

}

tasks.new {
    name      = "shipouts",
    processor = nodeprocessor,
    sequence  = {
        "before",      -- users
        "normalizers", -- system
        "finishers",   -- system
        "after",       -- users
        "wrapup",      -- system
    },
    templates = templates
}

tasks.new {
    name      = "everypar",
    processor = nodeprocessor,
    sequence  = {
        "before",      -- users
        "normalizers", -- system
        "after",       -- users
    },
    templates = templates,
}

-- -- finalizers -- --

tasks.new {
    name      = "finalizers",
    sequence  = {
        "before",      -- for users
        "normalizers",
        "fonts",
        "lists",
        "after",       -- for users
    },
    processor = nodeprocessor,
    templates = {

default = [[
return function(head)
    return head
end
]],

process = [[
local tonut  = nodes.tonut
local tonode = nodes.nuts.tonode

%localize%

return function(head,groupcode)
    local nuthead = tonut(head)

%actions%
    return tonode(nuthead)
end
]],

step = [[
    nuthead = tonut((%action%(tonode(nuthead),groupcode)))
]],

nut  = [[
    nuthead = %action%(nuthead,groupcode)
]],

nohead = [[
    %action%(tonode(nuthead),groupcode)
]],

nonut = [[
    %action%(nuthead,groupcode)
]],

    }
}

-- -- processors -- --

tasks.new {
    name      = "processors",
    processor = nodeprocessor,
    sequence  = {
        "before",      -- for users
        "normalizers",
        "characters",
        "words",
        "fonts",
        "lists",
        "after",       -- for users
    },
    templates = {

default = [[
return function(head)
    return head
end
]],

process = [[
local tonut  = nodes.tonut
local tonode = nodes.nuts.tonode

%localize%

return function(head,groupcode,size,packtype,direction,attributes)
    local nuthead = tonut(head)

%actions%
    return tonode(nuthead)
end
]],

step = [[
    nuthead = tonut((%action%(tonode(nuthead),groupcode,size,packtype,direction,attributes)))
]],

nut  = [[
    nuthead = %action%(nuthead,groupcode,size,packtype,direction,attributes)
]],

nohead = [[
    %action%(tonode(nuthead),groupcode,size,packtype,direction,attributes)
]],

nonut = [[
    %action%(nuthead,groupcode,size,packtype,direction,attributes)
]],

    }
}

tasks.new {
    name      = "finalizers",
    processor = nodeprocessor,
    sequence  = {
        "before",      -- for users
        "normalizers",
        "fonts",
        "lists",
        "after",       -- for users
    },
    templates = {

default = [[
return function(head)
    return head
end
]],

process = [[
local tonut  = nodes.tonut
local tonode = nodes.nuts.tonode

%localize%

return function(head)
    local nuthead = tonut(head)

%actions%
    return tonode(nuthead)
end
]],

step = [[
    nuthead = tonut((%action%(tonode(nuthead))))
]],

nut  = [[
    nuthead = %action%(nuthead)
]],

nohead = [[
    %action%(tonode(nuthead))
]],

nonut = [[
    %action%(nuthead)
]],

    }
}

tasks.new {
    name      = "mvlbuilders",
    processor = nodeprocessor,
    sequence  = {
        "before",      -- for users
        "normalizers",
        "after",       -- for users
    },
    templates = {

default = [[
return function(head)
    return head
end
]],

process = [[
local tonut  = nodes.tonut
local tonode = nodes.nuts.tonode

%localize%

return function(head,groupcode)
    local nuthead = tonut(head)

%actions%
    return tonode(nuthead)
end
]],

step = [[
    nuthead = tonut((%action%(tonode(nuthead),groupcode)))
]],

nut  = [[
    nuthead = %action%(nuthead,groupcode)
]],

nohead = [[
    %action%(tonode(nuthead),groupcode)
]],

nonut = [[
    %action%(nuthead,groupcode)
]],

    }
}

tasks.new {
    name      = "vboxbuilders",
    processor = nodeprocessor,
    sequence  = {
        "before",      -- for users
        "normalizers",
        "after",       -- for users
    },
    templates = {

default = [[
return function(head)
    return head
end
]],

process = [[
local tonut  = nodes.tonut
local tonode = nodes.nuts.tonode

%localize%

return function(head,groupcode,size,packtype,maxdepth,direction)
    local nuthead = tonut(head)

%actions%
    return tonode(nuthead)
end
]],

step = [[
    nuthead = tonut((%action%(tonode(nuthead),groupcode,size,packtype,maxdepth,direction)))
]],

nut  = [[
    nuthead = %action%(nuthead,groupcode,size,packtype,maxdepth,direction)
]],

nohead = [[
    %action%(tonode(nuthead),groupcode,size,packtype,maxdepth,direction)
]],

nonut = [[
    %action%(nuthead,groupcode,size,packtype,maxdepth,direction)
]],

    }

}

tasks.new {
    name      = "contributers",
    processor = nodeprocessor,
    sequence  = {
        "before",      -- for users
        "normalizers",
        "after",       -- for users
    },
    templates = {

default = [[
return function(head)
    return head
end
]],

process = [[
local tonut  = nodes.tonut
local tonode = nodes.nuts.tonode

%localize%

-- we operate exclusively on nuts

return function(nuthead,groupcode,nutline)
%actions%
    return nuthead
end
]],

step = [[
    nuthead = tonut((%action%(tonode(nuthead),groupcode,line)))
]],

nut  = [[
    nuthead = %action%(nuthead,groupcode,nutline)
]],

nohead = [[
    %action%(tonode(nuthead),groupcode,line)
]],

nonut = [[
    %action%(nuthead,groupcode,nutline)
]],

    }
}

-- -- math -- --

tasks.new {
    name      = "math",
    processor = nodeprocessor,
    sequence  = {
        "before",
        "normalizers",
        "builders",
        "after",
    },
    templates = {

default = [[
return function(head)
    return head
end
]],

process = [[
local tonut  = nodes.tonut
local tonode = nodes.nuts.tonode

%localize%

return function(head,style,penalties)
    local nuthead = tonut(head)

%actions%
    return tonode(nuthead)
end
]],

step = [[
    nuthead = tonut((%action%(tonode(nuthead),style,penalties)))
]],

nut  = [[
    nuthead = %action%(nuthead,style,penalties)
]],

nohead = [[
    %action%(tonode(nuthead),style,penalties)
]],

nonut = [[
    %action%(nuthead,style,penalties)
]],

    }
}

-- tasks.new {
--     name      = "parbuilders",
--     arguments = 1,
--     processor = nodeprocessor,
--     sequence  = {
--         "before",      -- for users
--         "lists",
--         "after",       -- for users
--     }
-- }

-- tasks.new {
--     name      = "pagebuilders",
--     arguments = 5,
--     processor = nodeprocessor,
--     sequence  = {
--         "before",      -- for users
--         "lists",
--         "after",       -- for users
--     }
-- }

-- for now quite useless (too fuzzy)
--
-- tasks.new {
--     name            = "listbuilders",
--     processor       = nodeprocessor,
--     sequence        = {
--         "before",      -- for users
--         "normalizers",
--         "after",       -- for users
--     },
--     templates       = {
-- -- we don't need a default
--         default = [[
-- return function(box,location,prevdepth)
--     return box, prevdepth
-- end
--         ]],
--         process = [[
-- %localize%
-- return function(box,location,prevdepth,mirrored)
--     %actions%
--     return box, prevdepth
-- end
--         ]],
--         step = [[
-- box, prevdepth = %action%(box,location,prevdepth,mirrored)
--         ]],
--     },
-- }

-- -- math -- --

-- not really a node processor

-- tasks.new {
--     name      = "newpar",
--     processor = nodeprocessor,
--     sequence  = {
--         "before",
--         "normalizers",
--         "after",
--     },
--     templates = {
--
-- default = [[
-- return function(mode,indent)
--     return indent
-- end
-- ]],
--
-- process = [[
-- %localize%
--
-- return function(mode,indent)
--
-- %actions%
--     return indent
-- end
-- ]],
--
-- step = [[
--     indent = %action%(mode,indent)
-- ]],
--
--     }
-- }
