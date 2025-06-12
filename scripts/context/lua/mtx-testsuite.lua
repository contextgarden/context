if not modules then modules = { } end modules['mtx-testsuite'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- runtestsparallel.cmd:

-- @echo off
--
-- REM ~ echo %path%
--
-- mtxrun  --generate %1
-- context --make en %1
-- mtxrun  --script font --reload --force
-- mtxrun  --script testsuite --parallel --pattern=**/*.tex --purge %1
--
-- echo.
-- echo results:
-- echo.
--
-- type testsuite-process.lua
--
-- echo.
-- echo.

-- runtestsparallel.sh:

-- #! /bin/sh
--
-- mtxrun  --generate $1
-- context --make en $1
-- mtxrun  --script font --reload --force
-- mtxrun  --script testsuite --parallel --pattern=**/*.tex --purge $1
--
-- cat testsuite-process.lua

-- (1) mtxrun --script testsuite --compare --oldname=foo --newname=bar --objects --pattern=*.tex
-- (2) move/mv bar.lua foo.lua
-- (3) mtxrun --script testsuite --compare --oldname=foo --newname=bar --objects --pattern=*.tex

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-testsuite</entry>
  <entry name="detail">Experiments with the testsuite</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="process"><short>process files (<ref name="pattern"/>)"/></short></flag>
   </subcategory>
   <subcategory>
    <flag name="compare"><short>compare files (<ref name="pattern"/> <ref name="newname"/> <ref name="oldname"/> <ref name="collect)"/></short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Example</title>
   <subcategory>
    <example><command>mtxrun --script testsuite --compare --objects --oldname=cld-compare-old  --newname=cld-compare-new  --pattern=**/*.cld</command></example>
    <example><command>mtxrun --script testsuite --compare --objects --oldname=mkiv-compare-old --newname=mkiv-compare-new --pattern=**/*.mkiv</command></example>
    <example><command>mtxrun --script testsuite --compare --objects --oldname=mkvi-compare-old --newname=mkvi-compare-new --pattern=**/*.mkvi</command></example>
    <example><command>mtxrun --script testsuite --compare --objects --oldname=tex-compare-old  --newname=tex-compare-new  --pattern=**/*.tex</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-testsuite",
    banner   = "Experiments with the testsuite 1.00",
    helpinfo = helpinfo,
}

local gmatch, match, gsub, find, lower, format = string.gmatch, string.match, string.gsub, string.find, string.lower, string.format
local concat = table.concat
local split = string.split
local are_equal = table.are_equal
local tonumber = tonumber
local formatters = string.formatters

local report = application.report

scripts           = scripts           or { }
scripts.testsuite = scripts.testsuite or { }

local f_runner = formatters['%s --batch --nocompression --nodates --trailerid=1 --randomseed=1234 %s "%s"']
----- f_runner = formatters['%s --nocompression --nodates --trailerid=1 --randomseed=1234 "%s"']

function scripts.testsuite.process()
    local pattern = environment.argument("pattern")
    if pattern then
        local cleanup = environment.argument("cleanup")
        local jit     = environment.argument("jit")
        local engine  = environment.argument("luatex") and "--luatex" or ""
        local results = { }
        local start   = statistics.starttiming(scripts.testsuite.process)
        local files   = dir.glob(pattern)
        local start   = tonumber(environment.argument("start"))
        local suffix  = start and ("-" ..start) or ""
        local start   = start or 1
        local stop    = tonumber(environment.argument("stop"))  or #files
        local step    = tonumber(environment.argument("step"))  or 1
        local luaname = "testsuite-process" .. suffix .. ".lua"
        for i=start,stop,step do
            local filename = files[i]
            if filename then
                local dirname  = file.dirname(filename)
                local basename = file.basename(filename)
                local texname  = basename
                local pdfname  = file.replacesuffix(basename,"pdf")
                local tucname  = file.replacesuffix(basename,"tuc")
                local workdir  = lfs.currentdir()
                lfs.chdir(dirname)
                os.remove(pdfname)
                if cleanup then
                    os.remove(tucname)
                end
                if lfs.isfile(texname) then
                    local command = f_runner(jit and "contextjit" or "context",engine,texname)
                    local result  = tonumber(os.execute(command)) or 0
                    if result > 0 then
                        results[filename] = result
                    end
                end
                lfs.chdir(workdir)
            else
                break
            end
        end
        statistics.stoptiming(scripts.testsuite.process)
        results.runtime = statistics.elapsedtime(scripts.testsuite.process)
        io.savedata(luaname,table.serialize(results,true))
        report()
        report("files: %i, runtime: %s, overview: %s",#files,results.runtime,luaname)
        report()
    end
end

local popen  = io.popen
local close  = io.close
local read   = io.read
local gobble = io.gobble
local clock  = os.clock

function scripts.testsuite.parallel() -- quite some overlap but ...
    local pattern = environment.argument("pattern")
    if pattern then
        local cleanup = environment.argument("cleanup")
        local engine  = environment.argument("luatex") and "--luatex" or ""
--         local signal  = environment.argument("signal")
        local squid   = environment.argument("squid")
        local results = { }
        local start   = statistics.starttiming(scripts.testsuite.process)
        local files   = dir.glob(pattern)
        local luaname = "testsuite-process.lua"
        local process = { }
        local total   = #files
        local runners = tonumber(environment.argument("parallel")) or 8
        local count   = 0
        local problem = false
--         local signalled = signal and function(state)
--             local c = format("mtxrun --script %s --state=%s --run=1 --all",signal,state)
--             os.resultof(c)
--         end or false
--         if signalled then
--             signalled("busy")
--         end
        if squid then
            squid = require("util-sig-imp-squid.lua")
        end
        if squid then
--             signalled = false
            squid.stepper("reset")
        end
        local steps = { }
        for i=1,runners do
            steps[i] = 0
        end
        --
        if squid then
            squid.signal("busy")
        end
        os.execute("mtxrun  --generate")
        if squid then
            squid.signal("busy")
            os.sleep(2)
            squid.signal("busy")
        end
        os.execute("context --make en")
        if squid then
            squid.signal("finished")
            os.sleep(2)
            squid.signal("busy")
        end
        os.execute("mtxrun  --script font  --reload --force")
        if squid then
            squid.signal("finished")
            os.sleep(2)
            squid.signal("reset")
        end
        while true do
            local done = false
            for i=1,runners do
                local pi = process[i]
                if pi then
                 -- local s = read(pi[1],"l")
                    local s = gobble(pi[1])
                    if s then
                     -- print(pi[3],s)
                        done = true
                        goto done
                    else
                        local r, detail, n = close(pi[1])
                        local bad = not r or n > 0
                        if bad then
                            results[pi[2]] = { detail, n }
                        end
                        if bad then
--                             if signalled and not problem then
--                                 signalled("problem")
--                             end
                            problem = true
                        end
                        report("%02i : %04i : %s : %s : %0.3f ",i,pi[3],bad and "error" or "done ",pi[2],clock()-pi[4])
                        process[i] = false
                    end
                end
                count = count + 1
                if count > total then
                    -- we're done
                else
                    local filename = files[count]
                    local dirname  = file.dirname(filename)
                    local basename = file.basename(filename)
                    local texname  = basename
                    local pdfname  = file.replacesuffix(basename,"pdf")
                    local tucname  = file.replacesuffix(basename,"tuc")
                    local workdir  = lfs.currentdir()
                    lfs.chdir(dirname)
                    os.remove(pdfname)
                    if cleanup then
                        os.remove(tucname)
                    end
                    if lfs.isfile(texname) then
steps[i] = steps[i] + 1
if squid then
    squid.stepper("busy",i,steps[i],problem)
end
                        local command = f_runner("context",engine,texname)
                        local result  = popen(command)
                        if result then
-- result:setvbuf("full",64*1024)
                            process[i] = { result, filename, count, clock() }
                        else
--                             if signalled and not problem then
--                                 signalled("problem")
--                                 problem = true
--                             end
                            results[filename] = "error"
if squid then
    squid.stepper("busy",i,steps[i],problem)
end
                        end
                        report("%02i : %04i : %s : %s",i,count,result and "start" or "error",filename)
                    end
                    lfs.chdir(workdir)
                    done = true
                end
              ::done::
            end
            if not done then
                break
            end
        end
        if squid then
            squid.signal(problem and "error" or "finished")
        end
        statistics.stoptiming(scripts.testsuite.process)
        results.runtime = statistics.elapsedtime(scripts.testsuite.process)
        io.savedata(luaname,table.serialize(results,true))
--         if signalled then
--             signalled(problem and "error" or "finished")
--         end
        report()
        report("files: %i, runtime: %s, overview: %s",total,results.runtime,luaname)
        report()
    end
end

function scripts.testsuite.compare()
    local pattern = environment.argument("pattern")
    local oldname = environment.argument("oldname")
    local newname = environment.argument("newname")
    local collect = environment.argument("collect")
    local bitmaps = environment.argument("bitmaps")
    local objects = environment.argument("objects")
    local cleanup = environment.argument("cleanup")
    local jit     = environment.argument("jit")
    local engine  = environment.argument("luatex") and "--luatex" or ""
    if pattern and newname then
        oldname = oldname and file.addsuffix(oldname,"lua")
        newname = file.addsuffix(newname,"lua")
        local files = dir.glob(pattern)
        local info  = table.load("testsuite-info.lua")
        local skip  = info and info.exceptions or { }
        local oldhashes = oldname and lfs.isfile(oldname) and dofile(oldname) or { }
        local newhashes = {
            version = 0.01,
            files   = { },
            data    = os.date(),
        }
        local old = oldhashes and oldhashes.files or {}
        local new = newhashes and newhashes.files or {}
        local err = { }

        local function compare(filename,olddata,name)
            local newhash = md5.HEX(io.loaddata(name))
            local oldhash = olddata and olddata.hash
            if not oldhash then
                new[filename] = { status = "new", hash = newhash }
            elseif oldhash == newhash then
                new[filename] = { status = "unchanged", hash = oldhash }
            else
                new[filename] = { status = "changed", hash = newhash }
            end
        end

        for i=1,#files do
            local filename = files[i]
            local olddata  = old[filename]
            if collect then
                new[filename] = olddata or { status = "collected" }
            elseif olddata and olddata.status == "skip" then
                new[filename] = olddata
            else
                local dirname  = file.dirname(filename)
                local basename = file.basename(filename)
                local texname  = basename
                local pdfname  = file.replacesuffix(basename,"pdf")
                local tucname  = file.replacesuffix(basename,"tuc")
                local pngname  = "temp.png"
                local oldname  = "old-" .. pdfname
                local workdir  = lfs.currentdir()
                lfs.chdir(dirname)
                os.remove(oldname)
                os.rename(pdfname,oldname)
                if cleanup then
                    os.remove(tucname)
                end
                os.remove(pngname)
                if lfs.isfile(texname) then
                    local command = f_runner(jit and "contextjit" or "context",engine,texname)
                    local result  = os.execute(command)
                    if result > 0 then
                        new[filename] = { status = "error", comment = "error code: " .. result }
                        err[filename] = result
                    elseif lfs.isfile(pdfname) then
                        local fullname = gsub(filename,"^%./","")
                        if skip[fullname] then
                            new[filename] = { status = "okay", comment = (bitmaps or objects) and "not compared" or nil }
                        elseif bitmaps then -- -A 8
                            local command = string.format('mutool draw -o %s -r 600 %s',pngname,pdfname)
                            local result = os.execute(command)
                            if lfs.isfile(pngname) then
                                compare(filename,olddata,pngname)
                            else
                                new[filename] = { status = "error", comment = "no png file" }
                            end
                        elseif objects then
                            compare(filename,olddata,pdfname)
                        else
                            new[filename] = { status = "okay" }
                        end
                    else
                        new[filename] = { status = "error", comment = "no pdf file" }
                    end
                else
                   new[filename] = { status = "error", comment = "no tex file" }
                end
                os.remove(pngname)
                lfs.chdir(workdir)
            end
        end
        io.savedata(newname,table.serialize(newhashes,true))
        if next(err) then
            for filename, data in table.sortedhash(err) do
                report("fatal error in file %a",filename)
            end
        else
            report("no fatal errors")
        end
    else
        report("provide --pattern --oldname --newname [--cleanup] [--bitmaps | --objects]")
    end
end

if environment.argument("compare") then
    scripts.testsuite.compare()
elseif environment.argument("process") then
    scripts.testsuite.process()
elseif environment.argument("parallel") then
    scripts.testsuite.parallel()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end

