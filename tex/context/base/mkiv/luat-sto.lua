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
local setbytecode = lua.setbytecode
local strippedloadstring = utilities.lua.strippedloadstring
local loadstring = utilities.lua.loadstring
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
                report_storage("saving %a in slot %a, size %s",message,max,#dumped)
            end
            -- we don't need tracing in such tables
            dumped = concat({ definition, comment, dumped },"\n")
            local code = nil
            local name = formatters["slot %s (%s)"](max,name)
            if LUAVERSION >= 5.3 then
                local code = loadstring(dumped,name)
                setbytecode(max,code,strip)
            else
                local code = strippedloadstring(dumped,name,strip)
                setbytecode(max,code)
            end
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
