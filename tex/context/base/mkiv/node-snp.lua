if not modules then modules = { } end modules ['node-snp'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not nodes then
    nodes = { } -- also loaded in mtx-timing
end

local snapshots  = { }
nodes.snapshots  = snapshots

local nodeusage  = nodes.pool and nodes.pool.usage
local clock      = os.gettimeofday or os.clock -- should go in environment
local lasttime   = clock()
local samples    = { }

local parameters = {
    "cs_count",
    "dyn_used",
    "elapsed_time",
    "luabytecode_bytes",
    "luastate_bytes",
    "max_buf_stack",
    "obj_ptr",
    "pdf_mem_ptr",
    "pdf_mem_size",
    "pdf_os_cntr",
--  "pool_ptr", -- obsolete
    "str_ptr",
}

function snapshots.takesample(comment)
    if nodeusage then
        local c = clock()
        local t = {
            elapsed_time = c - lasttime,
            node_memory  = nodeusage(),
            comment      = comment,
        }
        for i=1,#parameters do
            local parameter = parameters[i]
            local ps = status[parameter]
            if ps then
                t[parameter] = ps
            end
        end
        samples[#samples+1] = t
        lasttime = c
    end
end

function snapshots.getsamples()
    return samples -- one return value !
end

function snapshots.resetsamples()
    samples = { }
end

function snapshots.getparameters()
    return parameters
end
