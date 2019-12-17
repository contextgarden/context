if not modules then modules = { } end modules ['page-str'] = {
    version   = 1.001,
    comment   = "companion to page-str.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- streams -> managers.streams

-- work in progresss .. unfinished .. non-optimized

local concat, insert, remove = table.concat, table.insert, table.remove

local nodes, node = nodes, node

local tasks             = nodes.tasks

local implement         = interfaces.implement

local nodecodes         = nodes.nodecodes

local nuts              = nodes.nuts
local tonut             = nodes.tonut
local slide_node_list   = nuts.slide
local write_node        = nuts.write
local flush_node        = nuts.flush
local copy_node_list    = nuts.copy_list
local vpack_node_list   = nuts.vpack

local getbox            = nuts.getbox
local setlink           = nuts.setlink
local getlist           = nuts.getlist
local setlist           = nuts.setlist
local getwhd            = nuts.getwhd
local setwhd            = nuts.setwhd

local settings_to_array = utilities.parsers.settings_to_array

local enableaction      = nodes.tasks.enableaction

local texgetdimen       = tex.getdimen
----- texgetbox         = tex.getbox

local trace_collecting = false  trackers.register("streams.collecting", function(v) trace_collecting = v end)
local trace_flushing   = false  trackers.register("streams.flushing",   function(v) trace_flushing   = v end)

local report_streams = logs.reporter("streams")

streams       = streams or { } -- might move to the builders namespace
local streams = streams

-- maybe store head and tail ... first we need usage

local data    = { }
local name    = nil
local stack   = { }

function streams.enable(newname)
    if newname == "default" then
        name = nil
    else
        name = newname
    end
end

function streams.disable()
    name = stack[#stack]
end

function streams.start(newname)
    insert(stack,name)
    name = newname
end

function streams.stop(newname)
    name = remove(stack)
end

function streams.collect(head,where)
    if name and head and name ~= "default" then
        local head = tonut(head)
        local dana = data[name]
        if not dana then
            dana = { }
            data[name] = dana
        end
        local last = dana[#dana]
        if last then
            local tail = slide_node_list(last)
            setlink(tail,head)
        elseif last == false then
            dana[#dana] = head
        else
            dana[1] = head
        end
        if trace_collecting then
            report_streams("appending snippet %a to slot %s",name,#dana)
        end
        return nil
    else
        return head
    end
end

function streams.push(thename)
    if not thename or thename == "" then
        thename = name
    end
    if thename and thename ~= "" then
        local dana = data[thename]
        if dana then
            dana[#dana+1] = false
            if trace_collecting then
                report_streams("pushing snippet %a",thename)
            end
        end
    end
end

function streams.flush(name,copy) -- problem: we need to migrate afterwards
    local dana = data[name]
    if dana then
        local dn = #dana
        if dn == 0 then
            -- nothing to flush
        elseif copy then
            if trace_flushing then
                report_streams("flushing copies of %s slots of %a",dn,name)
            end
            for i=1,dn do
                local di = dana[i]
                if di then
                    write_node(copy_node_list(getlist(di))) -- list, will be option
                end
            end
            if copy then
                data[name] = nil
            end
        else
            if trace_flushing then
                report_streams("flushing %s slots of %a",dn,name)
            end
            for i=1,dn do
                local di = dana[i]
                if di then
                    write_node(getlist(di)) -- list, will be option
                    setlist(di)
                    flush_node(di)
                end
            end
        end
    end
end

function streams.synchronize(list) -- this is an experiment !
    -- we don't optimize this as we want to trace in detail
    list = settings_to_array(list)
    local max = 0
    if trace_flushing then
        report_streams("synchronizing list: % t",list)
    end
    for i=1,#list do
        local dana = data[list[i]]
        if dana then
            local n = #dana
            if n > max then
                max = n
            end
        end
    end
    if trace_flushing then
        report_streams("maximum number of slots: %s",max)
    end
    for m=1,max do
        local height, depth = 0, 0
        for i=1,#list do
            local name = list[i]
            local dana = data[name]
            if dana then
                local slot = dana[m]
                if slot then
                    local vbox = vpack_node_list(slot)
                    local wd, ht, dp = getwhd(vbox)
                    if ht > height then
                        height = ht
                    end
                    if dp > depth then
                        depth = dp
                    end
                    dana[m] = vbox
                    if trace_flushing then
                        report_streams("slot %s of %a is packed to height %p and depth %p",m,name,ht,dp)
                    end
                end
            end
        end
        if trace_flushing then
            report_streams("slot %s has max height %p and max depth %p",m,height,depth)
        end
        local strutht = texgetdimen("globalbodyfontstrutheight")
        local strutdp = texgetdimen("globalbodyfontstrutdepth")
        local struthtdp = strutht + strutdp
        for i=1,#list do
            local name = list[i]
            local dana = data[name]
            if dana then
                local vbox = dana[m]
                if vbox then
                    local wd, ht, dp = getwhd(vbox)
                    local delta_height = height - ht
                    local delta_depth  = depth  - dp
                    if delta_height > 0 or delta_depth > 0 then
                        if false then
                            -- actually we need to add glue and repack
                            setwhd(vbox,false,height,depth)
                            if trace_flushing then
                                report_streams("slot %s of %a with delta (%p,%p) is compensated",m,i,delta_height,delta_depth)
                            end
                        else
                            -- this is not yet ok as we also need to keep an eye on vertical spacing
                            -- so we might need to do some splitting or whatever
                            local list  = getlist(vbox)
                            local tail  = list and slide_node_list(list)
                            local n     = 0
                            local delta = delta_height -- for tracing
                            while delta > 0 do
                                -- we need to add some interline penalties
                                local line = copy_node_list(getbox("strutbox"))
                                setwhd(line,false,strutht,strutdp)
                                if tail then
                                    setlink(tail,line)
                                end
                                tail  = line
                                n     = n + 1
                                delta = delta - struthtdp
                            end
                            dana[m] = vpack_node_list(getlist(vbox))
                            setlist(vbox)
                            flush_node(vbox)
                            if trace_flushing then
                                report_streams("slot %s:%s with delta (%p,%p) is compensated by %s lines",m,i,delta_height,delta_depth,n)
                            end
                        end
                    end
                end
            else
                -- make dummy
            end
        end
    end
end

-- hm, nut or node

tasks.appendaction("mvlbuilders", "normalizers", "streams.collect")

tasks.disableaction("mvlbuilders", "streams.collect")

function streams.initialize()
    enableaction("mvlbuilders","streams.collect")
    function streams.initialize() end
end

-- todo: remove empty last { }'s
-- todo: better names, enable etc

implement {
    name     = "initializestream",
    actions  = streams.initialize,
    onlyonce = true,
}

implement {
    name      = "enablestream",
    actions   = streams.enable,
    arguments = "string"
}

implement {
    name      = "disablestream",
    actions   = streams.disable
}

implement {
    name      = "startstream",
    actions   = streams.start,
    arguments = "string"
}

implement {
    name      = "stopstream",
    actions   = streams.stop
}

implement {
    name      = "flushstream",
    actions   = streams.flush,
    arguments = "string"
}

implement {
    name      = "flushstreamcopy",
    actions   = streams.flush,
    arguments = { "string", true }
}

implement {
    name      = "synchronizestream",
    actions   = streams.synchronize,
    arguments = "string"
}

implement {
    name      = "pushstream",
    actions   = streams.push,
    arguments = "string"
}
