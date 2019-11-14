if not modules then modules = { } end modules ['core-uti'] = {
    version   = 1.001,
    comment   = "companion to core-uti.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: keep track of changes here (hm, track access, and only true when
-- accessed and changed)

--[[ldx--
<p>A utility file has always been part of <l n='context'/> and with
the move to <l n='luatex'/> we also moved a lot of multi-pass info
to a <l n='lua'/> table. Instead of loading a <l n='tex'/> based
utility file under different setups, we now load a table once. This
saves much runtime but at the cost of more memory usage.</p>
--ldx]]--

local math = math
local format, match = string.format, string.match
local next, type, tostring, tonumber = next, type, tostring, tonumber
local concat = table.concat

local definetable    = utilities.tables.definetable
local accesstable    = utilities.tables.accesstable
local migratetable   = utilities.tables.migratetable
local serialize      = table.serialize
local packers        = utilities.packers
local allocate       = utilities.storage.allocate
local mark           = utilities.storage.mark

local getrandom      = utilities.randomizer.get
local setrandomseedi = utilities.randomizer.setseedi
local getrandomseed  = utilities.randomizer.getseed

local implement      = interfaces.implement

local texgetcount    = tex.getcount

local report_passes  = logs.reporter("job","passes")

job                  = job or { }
local job            = job

job.version          = 1.31
job.packversion      = 1.02

-- some day we will implement loading of other jobs and then we need
-- job.jobs

--[[ldx--
<p>Variables are saved using in the previously defined table and passed
onto <l n='tex'/> using the following method. Of course one can also
directly access the variable using a <l n='lua'/> call.</p>
--ldx]]--

local savelist, comment = { }, { }

function job.comment(key,value)
    if type(key) == "table" then
        for k, v in next, key do
            comment[k] = v
        end
    else
        comment[key] = value
    end
end

job.comment("version",job.version)

local enabled     = true
local initialized = false

directives.register("job.save",function(v) enabled = v end)
----------.register("job.keep",function(v) kept    = v end)

function job.disablesave() -- can be command
    enabled = false
end

function job.initialize(loadname,savename)
    if not initialized then
        if not loadname or loadname == "" then
            loadname = tex.jobname .. ".tuc"
        end
        if not savename or savename == "" then
            savename = tex.jobname .. ".tua"
        end
        job.load(loadname) -- has to come after structure is defined !
        luatex.registerstopactions(function()
            if enabled and not status.lasterrorstring or status.lasterrorstring == "" then
             -- if kept then
             --     job.keep(loadname) -- could move to mtx-context instead
             -- end
                job.save(savename)
            end
        end)
        initialized = true
    end
end

function job.register(collected, tobesaved, initializer, finalizer, serializer)
    savelist[#savelist+1] = { collected, tobesaved, initializer, finalizer, serializer }
end

-- as an example we implement variables

local tobesaved, collected, checksums = allocate(), allocate(), allocate()

local jobvariables = {
    collected = collected,
    tobesaved = tobesaved,
    checksums = checksums,
}

-- if not checksums.old then checksums.old = md5.HEX("old") end -- used in experiment
-- if not checksums.new then checksums.new = md5.HEX("new") end -- used in experiment

job.variables = jobvariables

local function initializer()
    checksums = jobvariables.checksums
end

job.register('job.variables.checksums', 'job.variables.checksums', initializer)

local rmethod, rvalue
local collectedmacros, tobesavedmacros

local ctx_setxvalue = context.setxvalue

local function initializer()
    tobesaved = jobvariables.tobesaved
    collected = jobvariables.collected
    --
    rvalue = collected.randomseed
    if not rvalue then
        rvalue = getrandom("initialize")
        setrandomseedi(rvalue)
        rmethod = "initialized"
    else
        setrandomseedi(rvalue)
        rmethod = "resumed"
    end
    tobesaved.randomseed = rvalue
    --
    collectedmacros = collected.macros
    tobesavedmacros = tobesaved.macros
    if not collectedmacros then
        collectedmacros  = { }
        collected.macros = collectedmacros
    end
    if not tobesavedmacros then
        tobesavedmacros  = { }
        tobesaved.macros = tobesavedmacros
    end
    -- will become collected.macros
    for cs, value in next, collectedmacros do
        if type(value) == "string" then -- safeguard
            ctx_setxvalue(cs,value)
        end
    end
end

job.register('job.variables.collected', tobesaved, initializer)

function jobvariables.save(cs,value)
    tobesavedmacros[cs] = value
end

function jobvariables.restore(cs)
    return collectedmacros[cs] or tobesavedmacros[cs]
end

function job.getrandomseed()
    return tobesaved.randomseed or getrandomseed()
end

-- checksums

function jobvariables.getchecksum(tag)
    return checksums[tag] -- no default
end

function jobvariables.makechecksum(data)
    return data and md5.HEX(data) -- no default
end

function jobvariables.setchecksum(tag,checksum)
    checksums[tag] = checksum
end

--

local packlist = {
    "numbers",
    "ownnumbers",
    "metadata",
    "sectiondata",
    "prefixdata",
    "numberdata",
    "pagedata",
    "directives",
    "specification",
    "processors", -- might become key under directives or metadata
--  "references", -- we need to rename of them as only one packs (not structures.lists.references)
}

local skiplist = {
    "datasets",
    "userdata",
    "positions",
}

-- not ok as we can have arbitrary keys in userdata and dataset so some day we
-- might need a bit more granularity, like skippers

local jobpacker = packers.new(packlist,job.packversion,skiplist) -- jump number when changs in hash

job.pack = true
-- job.pack = false

directives.register("job.pack",function(v) job.pack = v end)

local _save_, _load_, _others_ = { }, { }, { } -- registers timing

function job.save(filename) -- we could return a table but it can get pretty large
    statistics.starttiming(_save_)
    local f = io.open(filename,'w')
    if f then
        f:write("local utilitydata = { }\n\n")
        f:write(serialize(comment,"utilitydata.comment",true),"\n\n")
        for l=1,#savelist do
         -- f:write("do\n\n") -- no solution for the jit limitatione either
            local list       = savelist[l]
            local target     = format("utilitydata.%s",list[1])
            local data       = list[2]
            local finalizer  = list[4]
            local serializer = list[5]
            if type(data) == "string" then
                data = utilities.tables.accesstable(data)
            end
            if type(finalizer) == "function" then
                finalizer()
            end
            if job.pack then
                packers.pack(data,jobpacker,true)
            end
            local definer, name = definetable(target,true,true) -- no first and no last
            if serializer then
                f:write(definer,"\n\n",serializer(data,name,true),"\n\n")
            else
                f:write(definer,"\n\n",serialize(data,name,true),"\n\n")
            end
         -- f:write("end\n\n")
        end
        if job.pack then
            packers.strip(jobpacker)
         -- f:write("do\n\n")
            f:write(serialize(jobpacker,"utilitydata.job.packed",true),"\n\n")
         -- f:write("end\n\n")
        end
        f:write("return utilitydata")
        f:close()
    end
    statistics.stoptiming(_save_)
end

local function load(filename)
    if lfs.isfile(filename) then

        local function dofile(filename)
            local result = loadstring(io.loaddata(filename))
            if result then
                return result()
            else
                return nil
            end
        end

        local okay, data = pcall(dofile,filename)
        if okay and type(data) == "table" then
            local jobversion  = job.version
            local datacomment = data.comment
            local dataversion = datacomment and datacomment.version or "?"
            if dataversion ~= jobversion then
                report_passes("version mismatch: %s <> %s",dataversion,jobversion)
            else
                return data
            end
        else
            os.remove(filename) -- probably a bad file (or luajit overflow as it cannot handle large tables well)
            report_passes("removing stale job data file %a, restart job, message: %s%s",filename,tostring(data),
                jit and " (try luatex instead of luajittex)" or "")
            os.exit(true) -- trigger second run
        end
    end
end

function job.load(filename)
    statistics.starttiming(_load_)
    local utilitydata = load(filename)
    if utilitydata then
        local jobpacker = utilitydata.job.packed
        local handlers  = { }
        for i=1,#savelist do
            local list        = savelist[i]
            local target      = list[1]
            local initializer = list[3]
            local result      = accesstable(target,utilitydata)
            if result then
                local done = packers.unpack(result,jobpacker,true)
                if done then
                    migratetable(target,mark(result))
                    if type(initializer) == "function" then
                        handlers[#handlers+1] = { initializer, result }
                    end
                else
                    report_passes("pack version mismatch")
                end
            end
        end
        -- so we have all tables available (unpacked)
        for i=1,#handlers do
            local handler = handlers[i]
            handler[1](handler[2])
        end
    end
    statistics.stoptiming(_load_)
end

function job.loadother(filename)
    statistics.starttiming(_load_)
    _others_[#_others_+1] = file.nameonly(filename)
    local utilitydata = load(filename)
    if utilitydata then
        local jobpacker = utilitydata.job.packed
        local unpacked = { }
        for l=1,#savelist do
            local list   = savelist[l]
            local target = list[1]
            local result = accesstable(target,utilitydata)
            local done = packers.unpack(result,jobpacker,true)
            if done then
                migratetable(target,result,unpacked)
            end
        end
        unpacked.job.packed = nil -- nicer in inspecting
        return unpacked
    end
    statistics.stoptiming(_load_)
end

-- function job.keep(filename)
--     local suffix = file.suffix(filename)
--     local base   = file.removesuffix(filename)
--     if suffix == "" then
--         suffix = "tuc"
--     end
--     for i=1,10 do
--         local tmpname = format("%s-%s-%02d.tmp",base,suffix,i)
--         if lfs.isfile(tmpname) then
--             os.remove(tmpname)
--             report_passes("removing %a",tmpname)
--         end
--     end
--     if lfs.isfile(filename) then
--         local tmpname = format("%s-%s-%02d.tmp",base,suffix,environment.currentrun or 1)
--         report_passes("copying %a into %a",filename,tmpname)
--         file.copy(filename,tmpname)
--     else
--         report_passes("no file %a, nothing kept",filename)
--     end
-- end

-- eventually this will end up in strc-ini

statistics.register("startup time", function()
    return statistics.elapsedseconds(statistics,"including runtime option file processing")
end)

statistics.register("jobdata time",function()
    if enabled then
        if #_others_ > 0 then
            return format("%s seconds saving, %s seconds loading, other files: %s",statistics.elapsedtime(_save_),statistics.elapsedtime(_load_),concat(_others_," "))
        else
            return format("%s seconds saving, %s seconds loading",statistics.elapsedtime(_save_),statistics.elapsedtime(_load_))
        end
    else
        if #_others_ > 0 then
            return format("nothing saved, %s seconds loading, other files: %s",statistics.elapsedtime(_load_),concat(_others_," "))
        else
            return format("nothing saved, %s seconds loading",statistics.elapsedtime(_load_))
        end
    end
end)

-- statistics.register("callbacks", function()
--     local total, indirect = status.callbacks or 0, status.indirect_callbacks or 0
--     local pages = texgetcount('realpageno') - 1
--     if pages > 1 then
--         return format("direct: %s, indirect: %s, total: %s (%i per page)", total-indirect, indirect, total, total/pages)
--     else
--         return format("direct: %s, indirect: %s, total: %s", total-indirect, indirect, total)
--     end
-- end)

function statistics.callbacks()
    local c_internal = status.callbacks or 0
    local c_file     = status.indirect_callbacks or 0
    local c_direct   = status.direct_callbacks or 0
    local c_late     = backends.noflatelua() or 0
    local c_function = status.function_callbacks or 0
    local c_total    = c_internal + c_file + c_direct + c_late + c_function
    local n_pages    = texgetcount('realpageno') - 1
    local c_average  = n_pages > 0 and math.round(c_total/n_pages) or 0
    local s_result   = format (
        c_average > 0 and "internal: %s, file: %s, direct: %s, late: %s, function %s, total: %s (%s per page)"
                       or "internal: %s, file: %s, direct: %s, late: %s, function %s, total: %s",
        c_internal, c_file, c_direct, c_late, c_function, c_total, c_average
    )
    statistics.callbacks = function()
        return s_result
    end
    return s_result
end

statistics.register("callbacks", statistics.callbacks)

statistics.register("randomizer", function()
    if rmethod and rvalue then
        return format("%s with value %s",rmethod,rvalue)
    end
end)

-- a sort of joke (for ctx meeting)

-- local kg_per_watt_per_second  = 1 / 15000000
-- local watts_per_core          = 50
-- local speedup_by_other_engine = 1.2
-- local used_wood_factor        = watts_per_core * kg_per_watt_per_second / speedup_by_other_engine
-- local used_wood_factor        = (50 / 15000000) / 1.2


function statistics.formatruntime(runtime)
    if not environment.initex then -- else error when testing as not counters yet
     -- stoptiming(statistics) -- to be sure
        local shipped = texgetcount('nofshipouts')
        local pages = texgetcount('realpageno')
        if pages > shipped then
            pages = shipped
        end
        runtime = tonumber(runtime)
        if shipped > 0 or pages > 0 then
            local persecond = (runtime > 0) and (shipped/runtime) or pages
            if pages == 0 then
                pages = shipped
            end
            return format("%0.3f seconds, %i processed pages, %i shipped pages, %.3f pages/second",runtime,pages,shipped,persecond)
        else
            return format("%0.3f seconds",runtime)
        end
    end
end

implement {
    name      = "savevariable",
    actions   = job.variables.save,
    arguments = "2 strings",
}

implement {
    name      = "setjobcomment",
    actions   = job.comment,
    arguments = { { "*" } }
}

implement {
    name      = "initializejob",
    actions   = job.initialize
}

implement {
    name      = "disablejobsave",
    actions   = job.disablesave
}
