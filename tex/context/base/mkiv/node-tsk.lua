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

local frozengroups  = "no"

function tasks.freeze(kind)
    frozengroups = kind or "tolerant" -- todo: hook into jobname
end

function tasks.new(specification) -- was: name,arguments,list
    local name      = specification.name
    local arguments = specification.arguments or 0
    local sequence  = specification.sequence
    if name and sequence then
        local tasklist = sequencers.new {
            -- we can move more to the sequencer now .. todo
        }
        tasksdata[name] = {
            list      = tasklist,
            runner    = false,
            arguments = arguments,
         -- sequence  = sequence,
            frozen    = { },
            processor = specification.processor or nodeprocessor
        }
        for l=1,#sequence do
            sequencers.appendgroup(tasklist,sequence[l])
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
        sequencers.enableaction(data.list,action)
        data.runner = false
    end
end

function tasks.disableaction(name,action)
    local data = valid(name)
    if data then
        sequencers.disableaction(data.list,action)
        data.runner = false
    end
end

function tasks.replaceaction(name,group,oldaction,newaction)
    local data = valid(name)
    if data then
        sequencers.replaceaction(data.list,group,oldaction,newaction)
        data.runner = false
    end
end

function tasks.setaction(name,action,value)
    if value then
        tasks.enableaction(name,action)
    else
        tasks.disableaction(name,action)
    end
end

function tasks.enablegroup(name,group)
    local data = validgroup(name,"enable group")
    if data then
        sequencers.enablegroup(data.list,group)
        data.runner = false
    end
end

function tasks.disablegroup(name,group)
    local data = validgroup(name,"disable group")
    if data then
        sequencers.disablegroup(data.list,group)
        data.runner = false
    end
end

function tasks.appendaction(name,group,action,where,kind)
    local data = validgroup(name,"append action")
    if data then
        sequencers.appendaction(data.list,group,action,where,kind)
        data.runner = false
    end
end

function tasks.prependaction(name,group,action,where,kind)
    local data = validgroup(name,"prepend action")
    if data then
        sequencers.prependaction(data.list,group,action,where,kind)
        data.runner = false
    end
end

function tasks.removeaction(name,group,action)
    local data = validgroup(name,"remove action")
    if data then
        sequencers.removeaction(data.list,group,action)
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

function tasks.actions(name) -- we optimize for the number or arguments (no ...)
    local data = tasksdata[name]
    if data then
        local n = data.arguments or 0
        if n == 0 then
            return function(head)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        report_tasks("creating runner %a",name)
                    end
                    runner = compile(data.list,data.processor,0)
                    data.runner = runner
                end
                return runner(head)
            end
        elseif n == 1 then
            return function(head,one)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        report_tasks("creating runner %a with %s extra arguments",name,1)
                    end
                    runner = compile(data.list,data.processor,1)
                    data.runner = runner
                end
                return runner(head,one)
            end
        elseif n == 2 then
            return function(head,one,two)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        report_tasks("creating runner %a with %s extra arguments",name,2)
                    end
                    runner = compile(data.list,data.processor,2)
                    data.runner = runner
                end
                return runner(head,one,two)
            end
        elseif n == 3 then
            return function(head,one,two,three)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        report_tasks("creating runner %a with %s extra arguments",name,3)
                    end
                    runner = compile(data.list,data.processor,3)
                    data.runner = runner
                end
                return runner(head,one,two,three)
            end
        elseif n == 4 then
            return function(head,one,two,three,four)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        report_tasks("creating runner %a with %s extra arguments",name,4)
                    end
                    runner = compile(data.list,data.processor,4)
                    data.runner = runner
                end
                return runner(head,one,two,three,four)
            end
        elseif n == 5 then
            return function(head,one,two,three,four,five)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        report_tasks("creating runner %a with %s extra arguments",name,5)
                    end
                    runner = compile(data.list,data.processor,5)
                    data.runner = runner
                end
                return runner(head,one,two,three,four,five)
            end
        else
            return function(head,...)
                total = total + 1 -- will go away
                local runner = data.runner
                if not runner then
                    created = created + 1
                    if trace_tasks then
                        report_tasks("creating runner %a with %s extra arguments",name,n)
                    end
                    runner = compile(data.list,data.processor,"n")
                    data.runner = runner
                end
                return runner(head,...)
            end
        end
    else
        return nil
    end
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

-- this will move

tasks.new {
    name      = "processors",
    arguments = 5, -- often only the first is used, and the last three are only passed in hpack filter
--  arguments = 2,
    processor = nodeprocessor,
    sequence  = {
        "before",      -- for users
        "normalizers",
        "characters",
        "words",
        "fonts",
        "lists",
        "after",       -- for users
    }
}

tasks.new {
    name      = "finalizers",
    arguments = 1,
    processor = nodeprocessor,
    sequence  = {
        "before",      -- for users
        "normalizers",
--      "characters",
--      "finishers",
        "fonts",
        "lists",
        "after",       -- for users
    }
}

tasks.new {
    name      = "shipouts",
    arguments = 0,
    processor = nodeprocessor,
    sequence  = {
        "before",      -- for users
        "normalizers",
        "finishers",
        "after",       -- for users
    }
}

tasks.new {
    name      = "mvlbuilders",
    arguments = 1,
    processor = nodeprocessor,
    sequence  = {
        "before",      -- for users
        "normalizers",
        "after",       -- for users
    }
}

tasks.new {
    name      = "vboxbuilders",
    arguments = 5,
    processor = nodeprocessor,
    sequence  = {
        "before",      -- for users
        "normalizers",
        "after",       -- for users
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
