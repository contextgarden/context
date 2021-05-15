if not modules then modules = { } end modules ['node-mig'] = {
    version   = 1.001,
    comment   = "companion to node-mig.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local trace_migrations = false trackers.register("nodes.migrations", function(v) trace_migrations = v end)

local report_nodes = logs.reporter("nodes","migrations")

local attributes       = attributes
local nodes            = nodes

local nuts             = nodes.nuts
local tonut            = nuts.tonut

local getnext          = nuts.getnext
local getid            = nuts.getid
local getlist          = nuts.getlist
local getprop          = nuts.getprop

local setprop          = nuts.setprop
local setlink          = nuts.setlink
local setlist          = nuts.setlist
local setprev          = nuts.setprev
local setnext          = nuts.setnext
local setboth          = nuts.setboth

local remove_node      = nuts.remove
local count            = nuts.count

local nodecodes        = nodes.nodecodes
local hlist_code       = nodecodes.hlist
local vlist_code       = nodecodes.vlist
local insert_code      = nodecodes.ins
local mark_code        = nodecodes.mark

local a_migrated       = attributes.private("migrated")
local trialtypesetting = context.trialtypesetting

local migrate_inserts  = false
local migrate_marks    = false

local t_inserts        = 0
local t_marks          = 0
local t_sweeps         = 0

local function locate(head,first,last)
    local current = head
    while current do
        local id = getid(current)
        if id == vlist_code or id == hlist_code then
            local list = getlist(current)
            if list then
                local l
                l, first, last = locate(list,first,last)
                if l ~= list then
                    setlist(current,l)
                end
            end
            current = getnext(current)
        elseif id == insert_code then
            if migrate_inserts then
                local insert
                head, current, insert = remove_node(head,current)
                if first then
                    setnext(insert)
                    setlink(last,insert)
                else
                    setboth(insert)
                    first = insert
                end
                last = insert
            end
        elseif id == mark_code then
            if migrate_marks then
                local mark
                head, current, mark = remove_node(head,current)
                if first then
                    setnext(mark)
                    setlink(last,mark)
                else
                    setboth(mark)
                    first = mark
                end
                last = mark
            end
        else
            current = getnext(current)
        end
    end
    return head, first, last
end

function nodes.handlers.migrate(head,where)
    if head and not trialtypesetting() then
        if trace_migrations then
            report_nodes("migration sweep %a",where)
        end
        local current = head
        while current do
            local id = getid(current)
            if (id == vlist_code or id == hlist_code or id == insert_code) and not getprop(current,"migrated") then
                setprop(current,"migrated",true)
                local h = getlist(current)
                if h then
                    t_sweeps = t_sweeps + 1
                    local first, last
                    while h do
                        local id = getid(h)
                        if id == vlist_code or id == hlist_code then
                            h, first, last = locate(h,first,last)
                        end
                        h = getnext(h)
                    end
                    if first then
                        if trace_migrations then
                            local ni = count(insert_code,first)
                            local nm = count(mark_code,first)
                            t_inserts = t_inserts + ni
                            t_marks   = t_marks   + nm
                            report_nodes("sweep %a, container %a, %s inserts and %s marks migrated outwards during %a",
                                t_sweeps,nodecodes[id],ni,nm,where)
                        end
                        local n = getnext(current)
                        if n then
                            setlink(last,n)
                        end
                        setlink(current,first)
                        current = last
                    end
                end
            end
            current = getnext(current)
        end
    end
    return head
end

statistics.register("node migrations", function()
    if trace_migrations and t_sweeps > 0 then
        return format("%s sweeps, %s inserts moved, %s marks moved",t_sweeps,t_inserts,t_marks)
    end
end)

-- Since we started with mkiv we had it as experiment but it is about time
-- to have a more formal interface .. it's still optional due to possible
-- side effects.

local enableaction  = nodes.tasks.enableaction
local disableaction = nodes.tasks.disableaction

local migrations = { }
nodes.migrations = migrations
local enabled    = false

local function check()
    if migrate_marks or migrate_inserts then
        if not enabled then
            enableaction("mvlbuilders", "nodes.handlers.migrate")
            enableaction("processors", "nodes.handlers.migrate")
            enabled = true
        end
    else
        if enabled then
            disableaction("mvlbuilders", "nodes.handlers.migrate")
            disableaction("processors", "nodes.handlers.migrate")
            enabled = false
        end
    end
end

function migrations.setmarks(v)
    migrate_marks = v
    check()
end

function migrations.setinserts(v)
    migrate_inserts = v
    check()
end
