if not modules then modules = { } end modules ['luat-sto'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we could nil some function in the productionrun

local type, next, setmetatable, getmetatable, collectgarbage = type, next, setmetatable, getmetatable, collectgarbage
local gmatch, format = string.gmatch, string.format
local serialize, concat, sortedhash = table.serialize, table.concat, table.sortedhash
local bytecode = lua.bytecode
local strippedloadstring = utilities.lua.strippedloadstring
local formatters = string.formatters

local trace_storage  = false
local report_storage = logs.reporter("system","storage")

storage            = storage or { }
local storage      = storage

local data         = { }
storage.data       = data

storage.min        = 0 -- 500
storage.max        = storage.min - 1
storage.noftables  = storage.noftables or 0
storage.nofmodules = storage.nofmodules or 0

storage.mark       = utilities.storage.mark
storage.allocate   = utilities.storage.allocate
storage.marked     = utilities.storage.marked
storage.strip      = false

directives.register("system.compile.strip", function(v) storage.strip = v end)

function storage.register(...)
    local t = { ... }
    local d = t[2]
    if d then
        storage.mark(d)
    else
        report_storage("fatal error: invalid storage %a",t[1])
        os.exit()
    end
    data[#data+1] = t
    return t
end

local n = 0 -- is that one used ?

if environment.initex then

 -- local function dump()
 --     local max = storage.max
 --     for i=1,#data do
 --         local d = data[i]
 --         local message, original, target = d[1], d[2] ,d[3]
 --         local c, code, name = 0, { }, nil
 --         -- we have a nice definer for this
 --         for str in gmatch(target,"([^%.]+)") do
 --             if name then
 --                 name = name .. "." .. str
 --             else
 --                 name = str
 --             end
 --             c = c + 1 ; code[c] = formatters["%s = %s or { }"](name,name)
 --         end
 --         max = max + 1
 --         if trace_storage then
 --             c = c + 1 ; code[c] = formatters["print('restoring %s from slot %s')"](message,max)
 --         end
 --         c = c + 1 ; code[c] = serialize(original,name)
 --         if trace_storage then
 --             report_storage('saving %a in slot %a, size %s',message,max,#code[c])
 --         end
 --         -- we don't need tracing in such tables
 --         bytecode[max] = strippedloadstring(concat(code,"\n"),storage.strip,format("slot %s (%s)",max,name))
 --         collectgarbage("step")
 --     end
 --     storage.max = max
 -- end

    local function dump()
        local max   = storage.max
        local strip = storage.strip
        for i=1,#data do
            max = max + 1
            local tabledata  = data[i]
            local message    = tabledata[1]
            local original   = tabledata[2]
            local target     = tabledata[3]
            local definition = utilities.tables.definetable(target,false,true)
            local comment    = formatters["restoring %s from slot %s"](message,max)
            if trace_storage then
                comment = formatters["print('%s')"](comment)
            else
                comment = formatters["-- %s"](comment)
            end
            local dumped = serialize(original,target)
            if trace_storage then
                report_storage('saving %a in slot %a, size %s',message,max,#dumped)
            end
            -- we don't need tracing in such tables
            dumped = concat({ definition, comment, dumped },"\n")
            bytecode[max] = strippedloadstring(dumped,strip,formatters["slot %s (%s)"](max,name))
            collectgarbage("step")
        end
        storage.max = max
    end

    lua.registerfinalizer(dump,"dump storage")

end

-- to be tested with otf caching:

function lua.collectgarbage(threshold)
    local current = collectgarbage("count")
    local threshold = threshold or 256 * 1024
    while true do
        collectgarbage("collect")
        local previous = collectgarbage("count")
        if current - previous < threshold then
            break
        else
            current = previous
        end
    end
end

-- -- we also need to count at generation time (nicer for message)
--
-- if lua.bytecode then -- from 0 upwards
--     local i, b = storage.min, lua.bytecode
--     while b[i] do
--         storage.noftables = i
--         b[i]()
--         b[i] = nil
--         i = i + 1
--     end
-- end

statistics.register("stored bytecode data", function()
    local nofmodules = (storage.nofmodules > 0 and storage.nofmodules) or (status.luabytecodes - lua.firstbytecode - 1)
    local nofdumps   = (storage.noftables  > 0 and storage.noftables ) or storage.max-storage.min + 1
    local tofmodules = storage.tofmodules or 0
    local tofdumps   = storage.toftables  or 0
    if environment.initex then
        local luautilities = utilities.lua
        return format("%s modules, %s tables, %s chunks, %s chunks stripped (%s bytes)",
            nofmodules,
            nofdumps,
            nofmodules + nofdumps,
            luautilities.nofstrippedchunks or 0,
            luautilities.nofstrippedbytes or 0
        )
    else
        return format("%s modules (%0.3f sec), %s tables (%0.3f sec), %s chunks (%0.3f sec)",
            nofmodules, tofmodules,
            nofdumps, tofdumps,
            nofmodules + nofdumps, tofmodules + tofdumps
        )
    end
end)

if lua.bytedata then
    storage.register("lua/bytedata",lua.bytedata,"lua.bytedata")
end

-- Because the storage mechanism assumes tables, we define a table for storing
-- (non table) values.

storage.shared = storage.shared or { }

storage.register("storage/shared", storage.shared, "storage.shared")

local mark  = storage.mark

if string.patterns     then                               mark(string.patterns)     end
if string.formatters   then                               mark(string.formatters)   end
if lpeg.patterns       then                               mark(lpeg.patterns)       end
if os.env              then                               mark(os.env)              end
if number.dimenfactors then                               mark(number.dimenfactors) end
if libraries           then for k,v in next, libraries do mark(v)                   end end
