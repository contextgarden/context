if not modules then modules = { } end modules ['luat-run'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next
local find = string.find
local insert, remove = table.insert, table.remove
local osexit = os.exit

-- trace_job_status is also controlled by statistics.enable that is set via the directive system.nostatistics

local trace_lua_dump   = false  trackers.register("system.dump",      function(v) trace_lua_dump   = v end)
local trace_temp_files = false  trackers.register("system.tempfiles", function(v) trace_temp_files = v end)
local trace_job_status = true   trackers.register("system.jobstatus", function(v) trace_job_status = v end)
local trace_tex_status = false  trackers.register("system.texstatus", function(v) trace_tex_status = v end)

local report_lua       = logs.reporter("system","lua")
local report_tex       = logs.reporter("system","status")
local report_tempfiles = logs.reporter("resolvers","tempfiles")

luatex        = luatex or { }
local luatex  = luatex
local synctex = luatex.synctex

if not synctex then
    synctex        = table.setmetatableindex(function() return function() end end)
    luatex.synctex = synctex
end

local startactions = { }
local stopactions  = { }
local dumpactions  = { }
local pageactions  = { }

function luatex.registerstartactions(...) insert(startactions, ...) end
function luatex.registerstopactions (...) insert(stopactions,  ...) end
function luatex.registerdumpactions (...) insert(dumpactions,  ...) end
function luatex.registerpageactions (...) insert(pageactions,  ...) end

local function start_run()
    if logs.start_run then
        logs.start_run()
    end
    for i=1,#startactions do
        startactions[i]()
    end
end

local function stop_run()
    for i=1,#stopactions do
        stopactions[i]()
    end
    local quit = logs.finalactions()
    if trace_job_status then
        statistics.show()
    end
    if trace_tex_status then
        logs.newline()
        for k, v in table.sortedhash(status.list()) do
            report_tex("%S=%S",k,v)
        end
    end
    if quit then
        local setexitcode = lua.setexitcode or status.setexitcode
        if setexitcode then
            setexitcode(1)
            if type(quit) == "table" then
                logs.newline()
                report_tex("quitting due to: %, t",quit)
                logs.newline()
            end
        end
    end
    if logs.stop_run then
        logs.stop_run()
    end
end

local function start_shipout_page()
    synctex.start()
    logs.start_page_number()
end

local function stop_shipout_page()
    logs.stop_page_number()
    for i=1,#pageactions do
        pageactions[i]()
    end
    synctex.stop()
end

local function report_output_pages()
end

local function report_output_log()
end

-- local function show_open()
-- end

-- local function show_close()
-- end

local function pre_dump_actions()
    for i=1,#dumpactions do
        dumpactions[i]()
    end
    lua.finalize(trace_lua_dump and report_lua or nil)
 -- statistics.savefmtstatus("\jobname","\contextversion","context.tex")
end

local function wrapup_synctex()
    synctex.wrapup()
end

-- For Taco ...

local sequencers     = utilities.sequencers
local appendgroup    = sequencers.appendgroup
local appendaction   = sequencers.appendaction
local wrapupactions  = sequencers.new { }
local cleanupactions = sequencers.new { }

appendgroup(wrapupactions,"system")
appendgroup(wrapupactions,"user")

appendgroup(cleanupactions,"system")
appendgroup(cleanupactions,"user")

local function wrapup_run()
    local runner = wrapupactions.runner
    if runner then
        runner()
    end
end

local function cleanup_run()
    local runner = cleanupactions.runner
    if runner then
        runner()
    end
end

function luatex.wrapup(action)
    appendaction(wrapupactions,"user",action)
end

function luatex.cleanup(action)
    appendaction(cleanupactions,"user",action)
end

function luatex.abort()
    cleanup_run()
    osexit(1)
end

appendaction(wrapupactions,"system",synctex.wrapup)

-- this can be done later

callbacks.register('start_run',               start_run,           "actions performed at the beginning of a run")
callbacks.register('stop_run',                stop_run,            "actions performed at the end of a run")

---------.register('show_open',               show_open,           "actions performed when opening a file")
---------.register('show_close',              show_close,          "actions performed when closing a file")

callbacks.register('report_output_pages',     report_output_pages, "actions performed when reporting pages")
callbacks.register('report_output_log',       report_output_log,   "actions performed when reporting log file")

---------.register('start_page_number',       start_shipout_page,  "actions performed at the beginning of a shipout")
---------.register('stop_page_number',        stop_shipout_page,   "actions performed at the end of a shipout")

callbacks.register('start_page_number',       function() end,      "actions performed at the beginning of a shipout")
callbacks.register('stop_page_number',        function() end,      "actions performed at the end of a shipout")

callbacks.register('process_input_buffer',    false,               "actions performed when reading data")
callbacks.register('process_output_buffer',   false,               "actions performed when writing data")

callbacks.register("pre_dump",                pre_dump_actions,    "lua related finalizers called before we dump the format") -- comes after \everydump

-- finish_synctex might go away (move to wrapup_run)

callbacks.register("finish_synctex",          wrapup_synctex,      "rename temporary synctex file")
callbacks.register('wrapup_run',              wrapup_run,          "actions performed after closing files")

-- temp hack for testing:

callbacks.functions.start_page_number = start_shipout_page
callbacks.functions.stop_page_number  = stop_shipout_page

-- an example:

local tempfiles = { }

function luatex.registertempfile(name,extrasuffix,keep) -- namespace might change
    if extrasuffix then
        name = name .. ".mkiv-tmp" -- maybe just .tmp
    end
    if trace_temp_files and not tempfiles[name] then
        if keep then
            report_tempfiles("%s temporary file %a","registering",name)
        else
            report_tempfiles("%s temporary file %a","unregistering",name)
        end
    end
    tempfiles[name] = keep or false
    return name
end

function luatex.cleanuptempfiles()
    for name, keep in next, tempfiles do
        if not keep then
            if trace_temp_files then
                report_tempfiles("%s temporary file %a","removing",name)
            end
            os.remove(name)
        end
    end
    tempfiles = { }
end

luatex.registerstopactions(luatex.cleanuptempfiles)

-- Reporting filenames has been simplified since lmtx because we don't need  the
-- traditional () {} <> etc methods (read: that directive option was never chosen).

local report_open  = logs.reporter("open source")
local report_close = logs.reporter("close source")
local report_load  = logs.reporter("load resource")

local register     = callbacks.register

local level = 0
local total = 0
local stack = { }

function luatex.currentfile()
    return stack[#stack] or tex.jobname
end

local function report_start(name,rest)
    if rest then
        -- luatex
        if name ~= 1 then
            insert(stack,false)
            return
        end
        name = rest
    end
    if find(name,"virtual://",1,true) then
        insert(stack,false)
    else
        insert(stack,name)
        total = total + 1
        level = level + 1
     -- report_open("%i > %i > %s",level,total,name or "?")
        report_open("level %i, order %i, name %a",level,total,name or "?")
        synctex.setfilename(name)
    end
end

local function report_stop()
    local name = remove(stack)
    if name then
     -- report_close("%i > %i > %s",level,total,name or "?")
        report_close("level %i, order %i, name %a",level,total,name or "?")
        level = level - 1
        synctex.setfilename(stack[#stack] or tex.jobname)
    end
end

local function report_none()
end

register("start_file",report_start)
register("stop_file", report_stop)

directives.register("system.reportfiles", function(v)
    if v then
        register("start_file",report_start)
        register("stop_file", report_stop)
    else
        register("start_file",report_none)
        register("stop_file", report_none)
    end
end)

-- start_run doesn't work

-- luatex.registerstartactions(function()
--     if environment.arguments.sandbox then
--         sandbox.enable()
--     end
-- end)

