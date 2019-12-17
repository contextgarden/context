if not modules then modules = { } end modules ['node-mig'] = {
    version   = 1.001,
    comment   = "companion to node-mig.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: insert_after

local format = string.format

local trace_migrations = false trackers.register("nodes.migrations", function(v) trace_migrations = v end)

local report_nodes = logs.reporter("nodes","migrations")

local attributes    = attributes
local nodes         = nodes
local enableaction  = nodes.tasks.enableaction

local nuts          = nodes.nuts
local tonut         = nuts.tonut

local getnext       = nuts.getnext
local getid         = nuts.getid
local getlist       = nuts.getlist
----- getattr       = nuts.getattr
local getprop       = nuts.getprop

----- setattr       = nuts.setattr
local setprop       = nuts.setprop
local setlink       = nuts.setlink
local setlist       = nuts.setlist
local setprev       = nuts.setprev
local setnext       = nuts.setnext
local setboth       = nuts.setboth

local remove_node   = nuts.remove

local nodecodes     = nodes.nodecodes
local hlist_code    = nodecodes.hlist
local vlist_code    = nodecodes.vlist
local insert_code   = nodecodes.ins
local mark_code     = nodecodes.mark

local a_migrated    = attributes.private("migrated")

local migrate_inserts, migrate_marks, inserts_too

local t_inserts, t_marks, t_sweeps = 0, 0, 0

local function locate(head,first,last,ni,nm)
    local current = head
    while current do
        local id = getid(current)
        if id == vlist_code or id == hlist_code then
            local list = getlist(current)
            if list then
                list, first, last, ni, nm = locate(list,first,last,ni,nm)
                setlist(current,list)
            end
            current = getnext(current)
        elseif migrate_inserts and id == insert_code then
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
            ni = ni + 1
        elseif migrate_marks and id == mark_code then
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
            nm = nm + 1
        else
            current = getnext(current)
        end
    end
    return head, first, last, ni, nm
end

function nodes.handlers.migrate(head,where)
    if head then
        if trace_migrations then
            report_nodes("migration sweep %a",where)
        end
        local current = head
        while current do
            local id = getid(current)
            -- inserts_too is a temp hack, we should only do them when it concerns
            -- newly placed (flushed) inserts

            -- todo: getprop / setprop

         -- if id == vlist_code or id == hlist_code or (inserts_too and id == insert_code) and not getattr(current,a_migrated) then
            if id == vlist_code or id == hlist_code or (inserts_too and id == insert_code) and not getprop(current,"migrated") then
             -- setattr(current,a_migrated,1)
                setprop(current,"migrated",true)
                t_sweeps = t_sweeps + 1
                local h = getlist(current)
                local first, last, ni, nm
                while h do
                    local id = getid(h)
                    if id == vlist_code or id == hlist_code then
                        h, first, last, ni, nm = locate(h,first,last,0,0)
                    end
                    h = getnext(h)
                end
                if first then
                    t_inserts = t_inserts + ni
                    t_marks   = t_marks   + nm
                    if trace_migrations and (ni > 0 or nm > 0) then
                        report_nodes("sweep %a, container %a, %s inserts and %s marks migrated outwards during %a",
                            t_sweeps,nodecodes[id],ni,nm,where)
                    end
                    -- inserts after head, use insert_after
                    local n = getnext(current)
                    if n then
                        setlink(last,n)
                    end
                    setlink(current,first)
                    current = last
                end
            end
            current = getnext(current)
        end
        return head
    end
end

-- for the moment this way, this will disappear

experiments.register("marks.migrate", function(v)
    if v then
        enableaction("mvlbuilders", "nodes.handlers.migrate")
    end
    migrate_marks = v
end)

experiments.register("inserts.migrate", function(v)
    if v then
        enableaction("mvlbuilders", "nodes.handlers.migrate")
    end
    migrate_inserts = v
end)

experiments.register("inserts.migrate.nested", function(v)
    if v then
        enableaction("mvlbuilders", "nodes.handlers.migrate")
    end
    inserts_too = v
end)

statistics.register("node migrations", function()
    if trace_migrations and t_sweeps > 0 then
        return format("%s sweeps, %s inserts moved, %s marks moved",t_sweeps,t_inserts,t_marks)
    end
end)
