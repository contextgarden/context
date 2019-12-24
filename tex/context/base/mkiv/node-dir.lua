if not modules then modules = { } end modules ['node-dir'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nodes             = nodes
local nuts              = nodes.nuts

local normaldir_code    = nodes.dircodes.normal
local line_code         = nodes.listcodes.line
local lefttoright_code  = nodes.dirvalues.lefttoright

local getnext           = nuts.getnext
local getlist           = nuts.getlist
local getwhd            = nuts.getwhd
local getdirection      = nuts.getdirection

local setlist           = nuts.setlist

local nextdir           = nuts.traversers.dir
local nexthlist         = nuts.traversers.hlist

local rangedimensions   = nuts.rangedimensions
local insert_before     = nuts.insert_before

local new_rule          = nuts.pool.rule
local new_kern          = nuts.pool.kern

local setcolor          = nodes.tracers.colors.set
local settransparency   = nodes.tracers.transparencies.set

-- local function dirdimensions(parent,begindir) -- can be a helper
--     local level   = 1
--     local enddir  = begindir
--     local width   = 0
--     for current, subtype in nextdir, getnext(begindir) do
--         if subtype == normaldir_code then -- todo
--             level = level + 1
--         else
--             level = level - 1
--         end
--         if level == 0 then -- does the type matter
--             enddir = current
--             width  = rangedimensions(parent,begindir,enddir)
--             return width, enddir
--         end
--     end
--     if enddir == begindir then
--         width = rangedimensions(parent,begindir)
--     end
--     return width, enddir
-- end

local function dirdimensions(parent,begindir) -- can be a helper
    local level   = 1
    local lastdir = nil
    local width   = 0
    for current, subtype in nextdir, getnext(begindir) do
        if subtype == normaldir_code then -- todo
            level = level + 1
        else
            level = level - 1
        end
        if level == 0 then -- does the type matter
            return (rangedimensions(parent,begindir,current)), current
        end
    end
    return (rangedimensions(parent,begindir)), begindir
end

nuts.dirdimensions = dirdimensions

local function colorit(list,current,dir,w,h,d)
    local rule  = new_rule(w,h,d)
    local kern  = new_kern(-w)
    local color = dir == lefttoright_code and "trace:s" or "trace:o"
    setcolor(rule,color)
    settransparency(rule,color)
    list, current = insert_before(list,current,kern)
    list, current = insert_before(list,current,rule)
    return list, current
end

function nodes.tracers.directions(head)
    for hlist, subtype in nexthlist, head do
        if subtype == line_code then
            local list = getlist(hlist)
            local w, h, d = getwhd(hlist)
            list = colorit(list,list,getdirection(hlist),w,h,d)
            for current in nextdir, list do
                local dir, cancel = getdirection(current)
                if not cancel then
                    local width = dirdimensions(hlist,current)
                    list = colorit(list,current,dir,width,h,d)
                end
            end
            setlist(hlist,list)
        end
    end
    return head
end

local enabled = false

trackers.register("nodes.directions", function(v)
    if not enabled then
        enabled = true
        nodes.tasks.appendaction("finalizers","after","nodes.tracers.directions",nil,"nut","enabled")
    end
    nodes.tasks.setaction(v)
end)
