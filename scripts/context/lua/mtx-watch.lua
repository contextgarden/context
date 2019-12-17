if not modules then modules = { } end modules ['mtx-watch'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-watch</entry>
  <entry name="detail">ConTeXt Request Watchdog</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="logpath"><short>optional path for log files</short></flag>
    <flag name="watch"><short>watch given path [<ref name="delay]"/></short></flag>
    <flag name="pipe"><short>use pipe instead of execute</short></flag>
    <flag name="delay"><short>delay between sweeps</short></flag>
    <flag name="automachine"><short>replace /machine/ in path /servername/</short></flag>
    <flag name="collect"><short>condense log files</short></flag>
    <flag name="cleanup" value="delay"><short>remove files in given path [<ref name="force]"/></short></flag>
    <flag name="showlog"><short>show log data</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-watch",
    banner   = "ConTeXt Request Watchdog 1.00",
    helpinfo = helpinfo,
}

local report = application.report

scripts       = scripts       or { }
scripts.watch = scripts.watch or { }

local format, concat, difftime, time = string.format, table.concat, os.difftime, os.time
local next, type = next, type
local basename, dirname, joinname = file.basename, file.dirname, file.join
local lfsdir, lfsattributes = lfs.dir, lfs.attributes

-- the machine/instance matches the server app we use

local machine  = socket.dns.gethostname() or "unknown-machine"
local instance = string.match(machine,"(%d+)$") or "0"

function scripts.watch.save_exa_modes(joblog,ctmname)
    local values = joblog and joblog.values
    if values then
        local t= { }
        t[#t+1] = "<?xml version='1.0' standalone='yes'?>\n"
        t[#t+1] = "<exa:variables xmlns:exa='htpp://www.pragma-ade.com/schemas/exa-variables.rng'>"
        for k, v in next, joblog.values do
            t[#t+1] = format("\t<exa:variable label='%s'>%s</exa:variable>", k, tostring(v))
        end
        t[#t+1] = "</exa:variables>"
        io.savedata(ctmname,concat(t,"\n"))
    else
        os.remove(ctmname)
    end
end

local function toset(t)
    if type(t) == "table" then
        return concat(t,",")
    else
        return t
    end
end

local function noset(t)
    if type(t) == "table" then
        return t[1]
    else
        return t
    end
end

-- todo: split order (o-name.luj) and combine with atime to determine sort order.

local function glob(files,path) -- some day: sort by name (order prefix) and atime
    for name in lfsdir(path) do
        if name:find("^%.") then
            -- skip . and ..
        else
            name = path .. "/" .. name
            local a = lfsattributes(name)
            if not a then
                -- weird
            elseif a.mode == "directory" then
                if name:find("graphics$") or name:find("figures$") or name:find("resources$") then
                    -- skip these too
                else
                    glob(files,name)
                end
            elseif name:find(".%luj$") then
                local bname = basename(name)
                local dname = dirname(name)
                local order = tonumber(bname:match("^(%d+)")) or 0
                files[#files+1] = { dname, bname, order }
            end
        end
    end
end

local clock = os.gettimeofday or (socket and socket.gettime) or os.time -- we cannot trust os.clock on linux

-- local function filenamesort(a,b)
--     local fa, da = a[1], a[2]
--     local fb, db = b[1], b[2]
--     if da == db then
--         return fa < fb
--     else
--         return da < db
--     end
-- end

local function filenamesort(a,b)
    local fa, oa = a[2], a[3]
    local fb, ob = b[2], b[3]
    if fa == fb then
        if oa == ob then
            return a[1] < b[1] -- order file  dir
        else
            return oa < ob     -- order file
        end
    else
        if oa == ob then
            return fa < fb     -- order file
        else
            return oa < ob     -- order file
        end
    end
end

function scripts.watch.watch()
    local delay   = tonumber(environment.argument("delay") or 5) or 5
    if delay == 0 then
        delay = .25
    end
    local logpath = environment.argument("logpath") or ""
    local pipe    = environment.argument("pipe")    or false
    local watcher = "mtxwatch.run"
    local paths   = environment.files
    if #paths > 0 then
        if environment.argument("automachine") then
            logpath = string.gsub(logpath,"/machine/","/"..machine.."/")
            for i=1,#paths do
                paths[i] = string.gsub(paths[i],"/machine/","/"..machine.."/")
            end
        end
        for i=1,#paths do
            report("watching path %s",paths[i])
        end
        local function process()
            local done = false
            for i=1,#paths do
                local path = paths[i]
                lfs.chdir(path)
                local files = { }
                glob(files,path)
                glob(files,".")
                table.sort(files,filenamesort)
--                 for name, time in next, files do
                for i=1,#files do
                    local f = files[i]
                    local dirname = f[1]
                    local basename = f[2] -- we can use that later on
                    local name = joinname(dirname,basename)
                --~ local ok, joblog = xpcall(function() return dofile(name) end, function() end )
                    local ok, joblog = pcall(dofile,name)
report("checking file %s/%s: %s",dirname,basename,ok and "okay" or "skipped")
                    if ok and joblog then
                        if joblog.status == "processing" then
                            report("aborted job, %s added to queue",name)
                            joblog.status = "queued"
                            io.savedata(name, table.serialize(joblog,true))
                        elseif joblog.status == "queued" then
                            local command = joblog.command
                            if command then
                                local replacements = {
                                    inputpath  = toset((joblog.paths and joblog.paths.input ) or "."),
                                    outputpath = noset((joblog.paths and joblog.paths.output) or "."),
                                    filename   = joblog.filename or "",
                                }
                                -- todo: revision path etc
                                command = command:gsub("%%(.-)%%", replacements)
                                if command ~= "" then
                                    joblog.status = "processing"
                                    joblog.runtime = clock()
                                    io.savedata(name, table.serialize(joblog,true))
                                    report("running: %s", command)
                                    local newpath = file.dirname(name)
                                    io.flush()
                                    local result = ""
                                    local ctmname = file.basename(replacements.filename)
                                    if ctmname == "" then ctmname = name end -- use self as fallback
                                    ctmname = file.replacesuffix(ctmname,"ctm")
                                    if newpath ~= "" and newpath ~= "." then
                                        local oldpath = lfs.currentdir()
                                        lfs.chdir(newpath)
                                        scripts.watch.save_exa_modes(joblog,ctmname)
                                        if pipe then result = os.resultof(command) else result = os.execute(command) end
                                        lfs.chdir(oldpath)
                                    else
                                        scripts.watch.save_exa_modes(joblog,ctmname)
                                        if pipe then result = os.resultof(command) else result = os.execute(command) end
                                    end
                                    report("return value: %s", result)
                                    done = true
                                    local path, base = replacements.outputpath, file.basename(replacements.filename)
                                    joblog.runtime = clock() - joblog.runtime
                                    if base ~= "" then
                                        joblog.result = file.replacesuffix(file.join(path,base),"pdf")
                                        joblog.size   = lfs.attributes(joblog.result,"size")
                                    end
                                    joblog.status = "finished"
                                else
                                    joblog.status = "invalid command"
                                end
                            else
                                joblog.status = "no command"
                            end
                            -- pcall, when error sleep + again
                            -- todo: just one log file and append
                            io.savedata(name, table.serialize(joblog,true))
                            if logpath and logpath ~= "" then
                                local name = file.join(logpath,os.uuid() .. ".lua")
                                io.savedata(name, table.serialize(joblog,true))
                                report("saving joblog in %s",name)
                            end
                        end
                    end
                end
            end
        end
        local n, start = 0, time()
        local wtime = 0
        local function wait()
            io.flush()
            if not done then
                n = n + 1
                if n >= 10 then
                    report("run time: %i seconds, memory usage: %0.3g MB", difftime(time(),start), (status.luastate_bytes/1024)/1000)
                    n = 0
                end
                local ttime = 0
                while ttime <= delay do
                    local wt = lfs.attributes(watcher,"mtime")
                    if wt and wt ~= wtime then
                        -- fast signal that there is a request
                        wtime = wt
                        break
                    end
                    ttime = ttime + 0.2
                    os.sleep(0.2)
                end
            end
        end
        local cleanupdelay, cleanup = environment.argument("cleanup"), false
        if cleanupdelay then
            local lasttime = time()
            cleanup = function()
                local currenttime = time()
                local delta = difftime(currenttime,lasttime)
                if delta > cleanupdelay then
                    lasttime = currenttime
                    for i=1,#paths do
                        local path = paths[i]
                        if string.find(path,"%.") then
                            -- safeguard, we want a fully qualified path
                        else
                            local files = dir.glob(file.join(path,"*"))
                            for i=1,#files do
                                local name = files[i]
                                local filetime = lfs.attributes(name,"modification")
                                local delta = difftime(currenttime,filetime)
                                if delta > cleanupdelay then
                                 -- report("cleaning up '%s'",name)
                                    os.remove(name)
                                end
                            end
                        end
                    end
                end
            end
        else
            cleanup = function()
                -- nothing
            end
        end
        while true do
            if false then
--~             if true then
                process()
                cleanup()
                wait()
            else
                pcall(process)
                pcall(cleanup)
                pcall(wait)
            end
        end
    else
        report("no paths to watch")
    end
end

function scripts.watch.collect_logs(path) -- clean 'm up too
    path = path or environment.argument("logpath") or ""
    path = (path == "" and ".") or path
    local files = dir.globfiles(path,false,"^%d+%.lua$")
    local collection = { }
    local valid = table.tohash({"filename","result","runtime","size","status"})
    for i=1,#files do
        local name = files[i]
        local t = dofile(name)
        if t and type(t) == "table" and t.status then
            for k, v in next, t do
                if not valid[k] then
                    t[k] = nil
                end
            end
            collection[name:gsub("[^%d]","")] = t
        end
    end
    return collection
end

function scripts.watch.save_logs(collection,path) -- play safe
    if collection and next(collection) then
        path = path or environment.argument("logpath") or ""
        path = (path == "" and ".") or path
        local filename = format("%s/collected-%s.lua",path,tostring(time()))
        io.savedata(filename,table.serialize(collection,true))
        local check = dofile(filename)
        for k,v in next, check do
            if not collection[k] then
                report("error in saving file")
                os.remove(filename)
                return false
            end
        end
        for k,v in next, check do
            os.remove(format("%s.lua",k))
        end
        return true
    else
        return false
    end
end

function scripts.watch.collect_collections(path) -- removes duplicates
    path = path or environment.argument("logpath") or ""
    path = (path == "" and ".") or path
    local files = dir.globfiles(path,false,"^collected%-%d+%.lua$")
    local collection = { }
    for i=1,#files do
        local name = files[i]
        local t = dofile(name)
        if t and type(t) == "table" then
            for k, v in next, t do
                collection[k] = v
            end
        end
    end
    return collection
end

function scripts.watch.show_logs(path) -- removes duplicates
    local collection = scripts.watch.collect_collections(path) or { }
    local max = 0
    for k,v in next, collection do
        v = v.filename or "?"
        if #v > max then max = #v end
    end
 -- print(max)
    local sorted = table.sortedkeys(collection)
    for k=1,#sorted do
        local v = sorted[k]
        local c = collection[v]
        local f, s, r, n = c.filename or "?", c.status or "?", c.runtime or 0, c.size or 0
        report("%s  %s  %3i  %8i  %s",string.padd(f,max," "),string.padd(s,10," "),r,n,v)
    end
end

function scripts.watch.cleanup_stale_files() -- removes duplicates
    local path  = environment.files[1]
    local delay = tonumber(environment.argument("cleanup"))
    local force = environment.argument("force")
    if not path or path == "." then
        report("provide qualified path")
    elseif not delay then
        report("missing --cleanup=delay")
    else
        if not force then
            report("dryrun, use --force for real cleanup")
        end
        local files = dir.glob(file.join(path,"*"))
        local rtime = time()
        for i=1,#files do
            local name = files[i]
            local mtime = lfs.attributes(name,"modification")
            local delta = difftime(rtime,mtime)
            if delta > delay then
                report("cleaning up '%s'",name)
                if force then
                    os.remove(name)
                end
            end
        end
    end
end

if environment.argument("watch") then
    scripts.watch.watch()
elseif environment.argument("collect") then
    scripts.watch.save_logs(scripts.watch.collect_logs())
elseif environment.argument("cleanup") then
    scripts.watch.save_logs(scripts.watch.cleanup_stale_files())
elseif environment.argument("showlog") then
    scripts.watch.show_logs()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
