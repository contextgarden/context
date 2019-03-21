if not modules then modules = { } end modules ['mtx-fcd'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "based on the ruby version from 2005",
}

-- This is a kind of variant of the good old ncd (norton change directory) program. This
-- script uses the same indirect cmd trick as Erwin Waterlander's wcd program.
--
-- The program is called via the stubs fcd.cmd or fcd.sh. On unix one should probably source
-- the file: ". fcd args" in order to make the chdir persistent.
--
-- You need to create a stub with:
--
--   mtxrun --script fcd --stub > fcd.cmd
--   mtxrun --script fcd --stub > fcd.sh
--
-- The stub starts this script and afterwards runs the created directory change script as
-- part if the same run, so that indeed we change.

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-fcd</entry>
  <entry name="detail">Fast Directory Change</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="clear"><short>clear the cache</short></flag>
    <flag name="clear"><short><ref name="history"/> [entry] clear the history</short></flag>
    <flag name="scan"><short>clear the cache and add given path(s)</short></flag>
    <flag name="add"><short>add given path(s)</short></flag>
    <flag name="find"><short>find given path (can be substring)</short></flag>
    <flag name="find"><short><ref name="nohistory"/> find given path (can be substring) but don't use history</short></flag>
    <flag name="stub"><short>print platform stub file</short></flag>
    <flag name="list"><short>show roots of cached dirs</short></flag>
    <flag name="list"><short><ref name="history"/> show history of chosen dirs</short></flag>
    <flag name="help"><short>show this help</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Example</title>
   <subcategory>
    <example><command>fcd --scan t:\</command></example>
    <example><command>fcd --add f:\project</command></example>
    <example><command>fcd [--find] whatever</command></example>
    <example><command>fcd --list</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-fcd",
    banner   = "Fast Directory Change 1.00",
    helpinfo = helpinfo,
}

local report  = application.report
local writeln = (logs and logs.writer) or (texio and texio.write_nl) or print

local find, char, byte, lower, gsub, format = string.find, string.char, string.byte, string.lower, string.gsub, string.format

local mswinstub = [[@echo off

rem this is: fcd.cmd

@echo off

if not exist "%HOME%" goto homepath

:home

mtxrun --script mtx-fcd.lua %1 %2 %3 %4 %5 %6 %7 %8 %9

if exist "%HOME%\mtx-fcd-goto.cmd" call "%HOME%\mtx-fcd-goto.cmd"

goto end

:homepath

if not exist "%HOMEDRIVE%\%HOMEPATH%" goto end

mtxrun --script mtx-fcd.lua %1 %2 %3 %4 %5 %6 %7 %8 %9

if exist "%HOMEDRIVE%\%HOMEPATH%\mtx-fcd-goto.cmd" call "%HOMEDRIVE%\%HOMEPATH%\mtx-fcd-goto.cmd"

goto end

:end
]]

local unixstub = [[#!/usr/bin/env sh

# this is: fcd.sh

# mv fcd.sh fcd
# chmod fcd 755
# . fcd [args]

ruby -S fcd_start.rb $1 $2 $3 $4 $5 $6 $7 $8 $9

if test -f "$HOME/fcd_stage.sh" ; then
  . $HOME/fcd_stage.sh ;
fi;

]]

local gotofile
local datafile
local stubfile
local stubdata
local stubdummy
local stubchdir


if os.type == 'windows' then
    local shell = "cmd"
--     local shell = "powershell"
    if shell == "powershell" then
        gotofile  = 'mtx-fcd-goto.ps1'
        datafile  = 'mtx-fcd-data.lua'
        stubfile  = 'fcd.cmd'
        stubdata  = mswinstub
        stubdummy = '# no dir to change to'
        stubchdir = '. Set-Location %s' -- powershell
    else
        gotofile  = 'mtx-fcd-goto.cmd'
        datafile  = 'mtx-fcd-data.lua'
        stubfile  = 'fcd.cmd'
        stubdata  = mswinstub
        stubdummy = 'rem no dir to change to'
        stubchdir = 'cd /d "%s"' -- cmd
    end
else
    gotofile  = 'mtx-fcd-goto.sh'
    datafile  = 'mtx-fcd-data.lua'
    stubfile  = 'fcd.sh'
    stubdata  = unixstub
    stubdummy = '# no dir to change to'
    stubchdir = '# cd "%s"'
end

local homedir = os.env["HOME"] or "" -- no longer TMP etc

if homedir == "" then
    homedir = format("%s/%s",os.env["HOMEDRIVE"] or "",os.env["HOMEPATH"] or "")
end

if homedir == "/" or not lfs.isdir(homedir) then
    os.exit()
end

local datafile = file.join(homedir,datafile)
local gotofile = file.join(homedir,gotofile)
local hash     = nil
local found    = { }
local pattern  = ""
local version  = modules['mtx-fcd'].version

io.savedata(gotofile,stubdummy)

if not lfs.isfile(gotofile) then
    -- write error
    os.exit()
end

local function fcd_clear(onlyhistory,what)
    if onlyhistory and hash and hash.history then
        if what and what ~= "" then
            hash.history[what] = nil
        else
            hash.history = { }
        end
    else
        hash = {
            name    = "fcd cache",
            comment = "generated by mtx-fcd.lua",
            created = os.date(),
            version = version,
            paths   = { },
            history = { },
        }
    end
end

local function fcd_changeto(dir)
    if dir and dir ~= "" then
        io.savedata(gotofile,format(stubchdir,dir,dir))
    end
end

local function fcd_load(forcecreate)
    if lfs.isfile(datafile) then
        hash = dofile(datafile)
    end
    if not hash or hash.version ~= version then
        if forcecache then
            fcd_clear()
        else
            writeln("empty dir cache")
            fcd_clear()
            os.exit()
        end
    end
end

local function fcd_save()
    if hash then
        io.savedata(datafile,table.serialize(hash,true))
    end
end

local function fcd_list(onlyhistory)
    if hash then
        writeln("")
        if onlyhistory then
            if next(hash.history) then
                for k, v in table.sortedhash(hash.history) do
                    writeln(format("%s => %s",k,v))
                end
            else
                writeln("no history")
            end
        else
            local paths = hash.paths
            if #paths > 0 then
                for i=1,#paths do
                    local path = paths[i]
                    writeln(format("%4i  %s",#path[2],path[1]))
                end
            else
                writeln("empty cache")
            end
        end
    end
end

local function fcd_find()
    found = { }
    pattern = lower(environment.files[1] or "")
    if pattern ~= "" then
        pattern = string.escapedpattern(pattern)
        local paths = hash.paths
        for i=1,#paths do
            local paths = paths[i][2]
            for i=1,#paths do
                local path = paths[i]
                if find(lower(path),pattern) then
                    found[#found+1] = path
                end
            end
        end
    end
end

local function fcd_choose(new)
    if pattern == "" then
        writeln(format("staying in dir %q",(gsub(lfs.currentdir(),"\\","/"))))
        return
    end
    if #found == 0 then
        writeln(format("dir %q not found",pattern))
        return
    end
    local okay = #found == 1 and found[1] or (not new and hash.history[pattern])
    if okay then
        writeln(format("changing to %q",okay))
        fcd_changeto(okay)
        return
    end
    local offset = 0
    while true do
        if not found[offset] then
            offset = 0
        end
        io.write("\n")
        for i=1,26 do
            local v = found[i+offset]
            if v then
                writeln(format("%s  %3i  %s",char(i+96),offset+i,v))
            else
                break
            end
        end
        offset = offset + 26
        if found[offset+1] then
            io.write("\n[press enter for more or select letter]\n\n>> ")
        else
            io.write("\n[select letter]\n\n>> ")
        end
        local answer = lower(io.read() or "")
        if not answer or answer == 'quit' then
            break
        elseif #answer > 0 then
            local choice = tonumber(answer)
            if not choice then
                if answer >= "a" and answer <= "z" then
                    choice = byte(answer) - 96 + offset - 26
                end
            end
            local newdir = found[choice]
            if newdir then
                hash.history[pattern] = newdir
                writeln(format("changing to %q",newdir))
                fcd_changeto(newdir)
                fcd_save()
                return
            end
        else
            -- try again
        end
    end
end

local function globdirs(path,dirs)
    local dirs = dirs or { }
    for name in lfs.dir(path) do
        if not find(name,"%.$") then
            local fullname = path .. "/" .. name
            if lfs.isdir(fullname) and not find(fullname,"/%.") then
                dirs[#dirs+1] = fullname
                globdirs(fullname,dirs)
            end
        end
    end
    return dirs
end

local function fcd_scan()
    if hash then
        local paths = hash.paths
        for i=1,#environment.files do
            local name = environment.files[i]
            local name = gsub(name,"\\","/")
            local name = gsub(name,"/$","")
            local list = globdirs(name)
            local done = false
            for i=1,#paths do
                if paths[i][1] == name then
                    paths[i][2] = list
                    done = true
                    break
                end
            end
            if not done then
                paths[#paths+1] = { name, list }
            end
        end
    end
end

local argument = environment.argument

if argument("clear") then
    if argument("history") then
        fcd_load()
        fcd_clear(true)
    else
        fcd_clear()
    end
    fcd_save()
elseif argument("scan") then
    fcd_clear()
    fcd_scan()
    fcd_save()
elseif argument("add") then
    fcd_load(true)
    fcd_scan()
    fcd_save()
elseif argument("stub") then
    writeln(stubdata)
elseif argument("list") then
    fcd_load()
    if argument("history") then
        fcd_list(true)
    else
        fcd_list()
    end
elseif argument("help") then
    application.help()
elseif argument("exporthelp") then
    application.export(argument("exporthelp"),environment.files[1])
else -- also argument("find")
    fcd_load()
    fcd_find()
    fcd_choose(argument("nohistory"))
end

