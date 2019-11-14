if not modules then modules = { } end modules ['mtx-install'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: initial install from zip

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-install</entry>
  <entry name="detail">ConTeXt Installer</entry>
  <entry name="version">2.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="platform" value="string"><short>platform (windows, linux, linux-64, osx-intel, osx-ppc, linux-ppc)</short></flag>
    <flag name="server" value="string"><short>repository url (rsync://contextgarden.net)</short></flag>
    <flag name="modules" value="string"><short>extra modules (can be list or 'all')</short></flag>
    <flag name="fonts" value="string"><short>additional fonts (can be list or 'all')</short></flag>
    <flag name="goodies" value="string"><short>extra binaries (like scite and texworks)</short></flag>
    <flag name="install"><short>install context</short></flag>
    <flag name="update"><short>update context</short></flag>
    <flag name="erase"><short>wipe the cache</short></flag>
    <flag name="identify"><short>create list of files</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local gsub, find, escapedpattern = string.gsub, string.find, string.escapedpattern
local round = math.round
local savetable, loadtable, sortedhash = table.save, table.load, table.sortedhash
local copyfile, joinfile, filesize, dirname, addsuffix, basename = file.copy, file.join, file.size, file.dirname, file.addsuffix, file.basename
local isdir, isfile, walkdir, pushdir, popdir, currentdir = lfs.isdir, lfs.isfile, lfs.dir, lfs.chdir, dir.push, dir.pop, currentdir
local mkdirs, globdir = dir.mkdirs, dir.glob
local osremove, osexecute, ostype = os.remove, os.execute, os.type
local savedata = io.savedata
local formatters = string.formatters

local fetch = socket.http.request

local application = logs.application {
    name     = "mtx-install",
    banner   = "ConTeXt Installer 2.00",
    helpinfo = helpinfo,
}

local report = application.report

scripts         = scripts         or { }
scripts.install = scripts.install or { }
local install   = scripts.install

local texformats = {
    "cont-en",
    "cont-nl",
    "cont-cz",
    "cont-de",
    "cont-fa",
    "cont-it",
    "cont-ro",
    "cont-uk",
    "cont-pe",
}

local platforms = {
    ["mswin"]          = "mswin",
    ["windows"]        = "mswin",
    ["win32"]          = "mswin",
    ["win"]            = "mswin",
    --
    ["mswin-64"]       = "win64",
    ["windows-64"]     = "win64",
    ["win64"]          = "win64",
    --
    ["linux"]          = "linux",
    ["linux-32"]       = "linux",
    ["linux32"]        = "linux",
    --
    ["linux-64"]       = "linux-64",
    ["linux64"]        = "linux-64",
    --
    ["linuxmusl-64"]   = "linuxmusl-64",
    --
    ["linux-armhf"]    = "linux-armhf",
    --
    ["openbsd"]        = "openbsd6.6",
    ["openbsd-i386"]   = "openbsd6.6",
    ["openbsd-amd64"]  = "openbsd6.6-amd64",
    --
    ["freebsd"]        = "freebsd",
    ["freebsd-i386"]   = "freebsd",
    ["freebsd-amd64"]  = "freebsd-amd64",
    --
 -- ["kfreebsd"]       = "kfreebsd-i386",
 -- ["kfreebsd-i386"]  = "kfreebsd-i386",
 -- ["kfreebsd-amd64"] = "kfreebsd-amd64",
    --
 -- ["linux-ppc"]      = "linux-ppc",
 -- ["ppc"]            = "linux-ppc",
    --
 -- ["osx"]            = "osx-intel",
 -- ["macosx"]         = "osx-intel",
 -- ["osx-intel"]      = "osx-intel",
 -- ["osxintel"]       = "osx-intel",
    --
 -- ["osx-ppc"]        = "osx-ppc",
 -- ["osx-powerpc"]    = "osx-ppc",
 -- ["osxppc"]         = "osx-ppc",
 -- ["osxpowerpc"]     = "osx-ppc",
    --
    ["macosx"]         = "osx-64",
    ["osx"]            = "osx-64",
    ["osx-64"]         = "osx-64",
    --
 -- ["solaris-intel"]  = "solaris-intel",
    --
 -- ["solaris-sparc"]  = "solaris-sparc",
 -- ["solaris"]        = "solaris-sparc",
    --
    ["unknown"]        = "unknown",
}

function install.identify()

    -- We have to be in "...../tex" where subdirectories are prefixed with
    -- "texmf". We strip the "tex/texm*/" from the name in the list.

    local hashdata = sha2 and sha2.HASH256 or md5.hex

    local function collect(root,tree)

        local path = root .. "/" .. tree

        if isdir(path) then

            local prefix  = path .. "/"
            local files   = globdir(prefix .. "**")
            local pattern = escapedpattern("^" .. prefix)

            local details = { }
            local total   = 0

            for i=1,#files do
                local name  = files[i]
                local size  = filesize(name)
                local base  = gsub(name,pattern,"")
                local stamp = hashdata(io.loaddata(name))
                details[i]  = { base, size, stamp }
                total       = total + size
            end
            report("%-20s : %4i files, %3.0f MB",tree,#files,total/(1000*1000))

            savetable(path .. ".tma",details)

        end

    end

    local sourceroot = file.join(dir.current(),"tex")

    for d in walkdir("./tex") do
        if find(d,"%texmf") then
            collect(sourceroot,d)
        end
    end

    savetable("./tex/status.tma",{
        name    = "context",
        version = "lmtx",
        date    = os.date("%Y-%m-%d"),
    })

end

local function disclaimer()
    report("ConTeXt LMTX with LuaMetaTeX is still experimental and when you get a crash this")
    report("can be due to a mismatch between Lua bytecode and the engine. In that case you can")
    report("try the following:")
    report("")
    report("  - wipe the texmf-cache directory")
    report("  - run: mtxrun --generate")
    report("  - run: context --make")
    report("")
    report("When that doesn't solve the problem, ask on the mailing list (ntg-context@ntg.nl).")
end

function install.update()

    local function validdir(d)
        local ok = isdir(d)
        if not ok then
            mkdirs(d)
            ok = isdir(d)
        end
        return ok
    end

    local function download(what,url,target,total,done)
        local data = fetch(url .. "/" .. target)
        if data then
            if total and done then
                report("%-8s : %3i %% : %8i : %s",what,round(100*done/total),#data,target)
            else
                report("%-8s : %8i : %s",what,#data,target)
            end
            if validdir(dirname(target)) then
                savedata(target,data)
            else
                -- message
            end
        end
    end

    local function remove(what,target)
        report("%-8s : %8i : %s",what,filesize(target),target)
        osremove(target)
    end

    local function ispresent(target)
        return isfile(target)
    end

    local function hashed(list)
        local hash = { }
        for i=1,#list do
            local l = list[i]
            hash[l[1]] = l
        end
        return hash
    end

    local function run(fmt,...)
        local command = formatters[fmt](...)
     -- command = gsub(command,"/","\\")
        report("running: %s",command)
        osexecute(command)
    end

    local function prepare(tree)
        tree = joinfile("tex",tree)
        mkdirs(tree)
    end

    local function update(url,what,zipfile,skiplist)

        local tree = joinfile("tex",what)

        local ok = validdir(tree)
        if not validdir(tree) then
            report("invalid directory %a",tree)
            return
        end

        local lua = tree .. ".tma"
        local all = url .. "/" .. lua
        local old = loadtable(lua)
        local new = fetch(all)

        if new then
            new = loadstring(new)
            if new then
                new = new()
            end
        end

        if not new then
            report("invalid database %a",all)
            return
        end

        local total = 0
        local done  = 0
        local count = 0

        if not old then

            if zipfile then
                zipfile = addsuffix(what,"zip")
            end
            if zipfile then
                local zipurl = url .. "/" .. zipfile
                report("fetching %a",zipurl)
                local zipdata = fetch(zipurl)
                if zipdata then
                    io.savedata(zipfile,zipdata)
                else
                    zipfile = false
                end
            end

            if type(zipfile) == "string" and isfile(zipfile) then

                -- todo: pcall

                report("unzipping %a",zipfile)

                local specification = {
                    zipname = zipfile,
                    path    = ".",
                 -- verbose = true,
                    verbose = "steps",
                }

                if utilities.zipfiles.unzipdir(specification) then
                    osremove(zipfile)
                    goto done
                else
                    osremove(zipfile)
                end

            end

            count = #new

            report("installing %s, %i files",tree,count)

            for i=1,count do
                total = total + new[i][2]
            end

            for i=1,count do
                local entry  = new[i]
                local name   = entry[1]
                local size   = entry[2]
                local target = joinfile(tree,name)
                done = done + size
                if not skiplist or not skiplist[basename(name)] then
                    download("new",url,target,total,done)
                else
                    report("skipping %s",target)
                end
            end

            ::done::

        else

            report("updating %s, %i files",tree,#new)

            local hold = hashed(old)
            local hnew = hashed(new)
            local todo = { }

            for newname, newhash in sortedhash(hnew) do
                local target = joinfile(tree,newname)
                if not skiplist or not skiplist[basename(newname)] then
                    local oldhash = hold[newname]
                    local action  = nil
                    if not oldhash then
                        action = "added"
                    elseif oldhash[3] ~= newhash[3] then
                        action = "changed"
                    elseif not ispresent(joinfile(tree,newname)) then
                        action = "missing"
                    end
                    if action then
                        local size = newhash[2]
                        total = total + size
                        todo[#todo+1] = { action, target, size }
                    end
                else
                    report("skipping %s",target)
                end
            end

            count = #todo

            for i=1,count do
                local entry = todo[i]
                download(entry[1],url,entry[2],total,done)
                done = done + entry[3]
            end

            for oldname, oldhash in sortedhash(hold) do
                local newhash = hnew[oldname]
                local target  = joinfile(tree,oldname)
                if not newhash and ispresent(target) then
                    remove("removed",target)
                end
            end

        end

        savetable(lua,new)

        return { tree, count, done }

    end

    local targetroot = dir.current()

    local server     = environment.arguments.server   or ""
    local instance   = environment.arguments.instance or ""
    local osplatform = environment.arguments.platform or nil
    local platform   = platforms[osplatform or os.platform or ""]

    if (platform == "unknown" or platform == "" or not platform) and osplatform then
        -- catches openbsdN.M kind of specifications
        platform = osplatform
    elseif not osplatform then
        osplatform = platform
    end

    if server == "" then
        server = "lmtx.contextgarden.net,lmtx.pragma-ade.com,lmtx.pragma-ade.nl,dmz.pragma-ade.nl"
    end
    if instance == "" then
        instance = "install-lmtx"
    end
    if not platform then
        report("unknown platform")
        return
    end

    local list   = utilities.parsers.settings_to_array(server)
    local server = false

    for i=1,#list do
        local host = list[i]
        local data, status, detail = fetch("http://" .. host .. "/" .. instance .. "/tex/status.tma")
        if status == 200 and type(data) == "string" then
            local t = loadstring(data)
            if type(t) == "function" then
                t = t()
            end
            if type(t) == "table" and t.name == "context" and t.version == "lmtx" then
                server = host
                break
            end
        end
    end

    if not server then
        report("provide valid server and instance")
        return
    end

    local url = "http://" .. server .. "/" .. instance .. "/"

    local texmfplatform = "texmf-" .. platform

    report("server   : %s",server)
    report("instance : %s",instance)
    report("platform : %s",osplatform)
    report("system   : %s",ostype)

    local status   = { }
    local skiplist = {
        ["mtxrun"]      = true,
        ["context"]     = true,
        ["mtxrun.exe"]  = true,
        ["context.exe"] = true,
    }

    status[#status+1] = update(url,"texmf",true)
    status[#status+1] = update(url,"texmf-context",true)
    status[#status+1] = update(url,texmfplatform,false,skiplist)

    prepare("texmf-cache")
    prepare("texmf-project")
    prepare("texmf-fonts")
    prepare("texmf-local")
    prepare("texmf-modules")

    local binpath = joinfile(targetroot,"tex",texmfplatform,"bin")

    local luametatex = "luametatex"
    local mtxrun     = "mtxrun"
    local context    = "context"

    if ostype == "windows" then
        luametatex = addsuffix(luametatex,"exe")
        mtxrun     = addsuffix(mtxrun,"exe")
        context    = addsuffix(context,"exe")
    end

    local luametatexbin = joinfile(binpath,luametatex)
    local mtxrunbin     = joinfile(binpath,mtxrun)
    local contextbin    = joinfile(binpath,context)

    local cdir = currentdir()
    local pdir = pushdir(binpath)

    report("current  : %S",cdir)
    report("target   : %S",pdir)

    if pdir ~= cdir then

        report("removing : %s",mtxrun)
        report("removing : %s",context)

        osremove(mtxrun)
        osremove(context)

        if isfile(luametatex) then
            lfs.symlink(luametatex,mtxrun)
            lfs.symlink(luametatex,context)
        end

        if isfile(mtxrun) then
            report("linked   : %s",mtxrun)
        else
            copyfile(luametatex,mtxrun)
            report("copied   : %s",mtxrun)
        end
        if isfile(context) then
            report("linked   : %s",context)
        else
            copyfile(luametatex,context)
            report("copied   : %s",context)
        end

    end

    popdir()

    if lfs.setexecutable(luametatexbin) then
        report("xbit set : %s",luametatexbin)
    else
     -- report("xbit bad : %s",luametatexbin)
    end
    if lfs.setexecutable(mtxrunbin) then
        report("xbit set : %s",mtxrunbin)
    else
     -- report("xbit bad : %s",mtxrunbin)
    end
    if lfs.setexecutable(contextbin) then
        report("xbit set : %s",contextbin)
    else
     -- report("xbit bad : %s",contextbin)
    end

    run("%s --generate",mtxrunbin)
    if environment.argument("erase") then
        run("%s --script cache --erase",mtxrunbin)
        run("%s --generate",mtxrunbin)
    end
    run("%s --make en", contextbin)


    -- in calling script: update mtxrun.exe and mtxrun.lua

    report("")
    for i=1,#status do
        report("%-20s : %4i files with %9i bytes installed",unpack(status[i]))
    end
    report("")
    disclaimer()
    report("")

    report("update, done")
end

if environment.argument("identify") then
    install.identify()
elseif environment.argument("install") then
    install.update()
elseif environment.argument("update") then
    install.update()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
    report("")
    disclaimer()
end
