if not modules then modules = { } end modules ['mtx-update'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This script is dedicated to Mojca Miklavec, who is the driving force behind
-- moving minimal generation from our internal machines to the context garden.
-- Together with Arthur Reutenauer she made sure that it worked well on all
-- platforms that matter.

-- LuaTeX and LuajitTeX are now always installed together.

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-update</entry>
  <entry name="detail">ConTeXt Minimals Updater</entry>
  <entry name="version">1.03</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="platform" value="string"><short>platform (windows, linux, linux-64, osx-intel, osx-ppc, linux-ppc)</short></flag>
    <flag name="server" value="string"><short>repository url (rsync://contextgarden.net)</short></flag>
    <flag name="module" value="string"><short>repository url (minimals)</short></flag>
    <flag name="repository" value="string"><short>specify version (current, experimental)</short></flag>
    <flag name="context" value="string"><short>specify version (current, latest, beta, yyyy.mm.dd)</short></flag>
    <flag name="rsync" value="string"><short>rsync binary (rsync)</short></flag>
    <flag name="texroot" value="string"><short>installation directory (not guessed for the moment)</short></flag>
    <flag name="engine" value="string"><short>tex engine (luatex, pdftex, xetex)</short></flag>
    <flag name="modules" value="string"><short>extra modules (can be list or 'all')</short></flag>
    <flag name="fonts" value="string"><short>additional fonts (can be list or 'all')</short></flag>
    <flag name="goodies" value="string"><short>extra binaries (like scite and texworks)</short></flag>
    <flag name="force"><short>instead of a dryrun, do the real thing</short></flag>
    <flag name="update"><short>update minimal tree</short></flag>
    <flag name="make"><short>also make formats and generate file databases</short></flag>
    <flag name="keep"><short>don't delete unused or obsolete files</short></flag>
    <flag name="state"><short>update tree using saved state</short></flag>
    <flag name="cygwin"><short>adapt drive specs to cygwin</short></flag>
    <flag name="mingw"><short>assume mingw binaries being used</short></flag>
    <flag name="silent"><short>less (or no) logging</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-update",
    banner   = "ConTeXt Minimals Updater 1.03",
    helpinfo = helpinfo,
}

local report = application.report

local format, concat, gmatch, gsub, find = string.format, table.concat, string.gmatch, string.gsub, string.find

scripts         = scripts         or { }
scripts.update  = scripts.update  or { }
local update    = scripts.update

minimals        = minimals        or { }
minimals.config = minimals.config or { }

-- this is needed under windows
-- else rsync fails to set the right chmod flags to files

os.setenv("CYGWIN","nontsec")

update.texformats = {
    "cont-en",
    "cont-nl",
    "cont-cz",
    "cont-de",
    "cont-fa",
    "cont-it",
    "cont-ro",
    "cont-uk",
    "cont-pe",
 -- "cont-xp",
    "mptopdf",
    "plain"
}

-- update.mpformats = {
--  -- "metafun",
--  -- "mpost",
-- }

-- experimental is not functional at the moment

update.repositories = {
    "current",
    "experimental"
}

-- more options than just these two are available (no idea why this is here)

update.versions = {
    "current",
    "latest"
}

-- list of basic folders that are needed to make a functional distribution

update.base = {
    { "base/tex/",                "texmf" },
    { "base/metapost/",           "texmf" },
    { "fonts/common/",            "texmf" },
    { "fonts/other/",             "texmf" }, -- not *really* needed, but helpful
    { "context/<version>/",       "texmf-context" },
    { "misc/setuptex/",           "." },
    { "misc/web2c",               "texmf" },
    { "bin/common/<platform>/",   "texmf-<platform>" },
    { "bin/context/<platform>/",  "texmf-<platform>" },
    { "bin/metapost/<platform>/", "texmf-<platform>" },
    { "bin/man/",                 "texmf-<platform>" },
}

-- binaries and font-related files
-- for pdftex we don't need OpenType fonts, for LuaTeX/XeTeX we don't need TFM files

update.defaultengine = "luatex"
update.rsyncvariant  = "cygwin" -- will be come mingw

update.engines = {
    ["luatex"] = {
        { "fonts/new/",               "texmf" },
        { "bin/luatex/<platform>/",   "texmf-<platform>" },
     -- { "bin/luajittex/<platform>/","texmf-<platform>" },
    },
    ["xetex"] = {
        { "base/xetex/",              "texmf" },
        { "fonts/new/",               "texmf" },
        { "bin/luatex/<platform>/",   "texmf-<platform>" }, -- tools
        { "bin/xetex/<platform>/",    "texmf-<platform>" },
    },
    ["pdftex"] = {
        { "fonts/old/",               "texmf" },
        { "bin/luatex/<platform>/",   "texmf-<platform>" }, -- tools
        { "bin/pdftex/<platform>/",   "texmf-<platform>" },
    },
    ["all"] = {
        { "fonts/new/",               "texmf" },
        { "fonts/old/",               "texmf" },
        { "base/xetex/",              "texmf" },
        { "bin/luatex/<platform>/",   "texmf-<platform>" },
     -- { "bin/luajittex/<platform>/","texmf-<platform>" },
        { "bin/xetex/<platform>/",    "texmf-<platform>" },
        { "bin/pdftex/<platform>/",   "texmf-<platform>" },
    },
}

update.goodies = {
    ["scite"] = {
        { "bin/<platform>/scite/",    "texmf-<platform>" },
    },
    ["texworks"] = {
        { "bin/<platform>/texworks/", "texmf-<platform>" },
    },
}

-- update.platforms = {
--     ["mswin"]          = "mswin",
--     ["windows"]        = "mswin",
--     ["win32"]          = "mswin",
--     ["win"]            = "mswin",
--  -- ["mswin"]          = "win32",
--  -- ["windows"]        = "win32",
--  -- ["win32"]          = "win32",
--  -- ["win"]            = "win32",
--     --
--  -- ["mswin-64"]       = "mswin-64",
--  -- ["windows-64"]     = "mswin-64",
--  -- ["win64"]          = "mswin-64",
--     ["mswin-64"]       = "win64",
--     ["windows-64"]     = "win64",
--     ["win64"]          = "win64",
--     --
--     ["linux"]          = "linux",
--     ["linux-32"]       = "linux",
--     ["linux32"]        = "linux",
--     --
--     ["linux-64"]       = "linux-64",
--     ["linux64"]        = "linux-64",
--     --
--     ["linuxmusl-64"]   = "linuxmusl-64",
--     --
--     ["linux-armhf"]    = "linux-armhf",
--     --
--     ["freebsd"]        = "freebsd",
--     --
--     ["freebsd-amd64"]  = "freebsd-amd64",
--     --
--     ["kfreebsd"]       = "kfreebsd-i386",
--     ["kfreebsd-i386"]  = "kfreebsd-i386",
--     --
--     ["kfreebsd-amd64"] = "kfreebsd-amd64",
--     --
--     ["linux-ppc"]      = "linux-ppc",
--     ["ppc"]            = "linux-ppc",
--     --
--     ["osx"]            = "osx-intel",
--     ["macosx"]         = "osx-intel",
--     ["osx-intel"]      = "osx-intel",
--     ["osxintel"]       = "osx-intel",
--     --
--     ["osx-ppc"]        = "osx-ppc",
--     ["osx-powerpc"]    = "osx-ppc",
--     ["osxppc"]         = "osx-ppc",
--     ["osxpowerpc"]     = "osx-ppc",
--     --
--     ["osx-64"]         = "osx-64",
--     --
--     ["solaris-intel"]  = "solaris-intel",
--     --
--     ["solaris-sparc"]  = "solaris-sparc",
--     ["solaris"]        = "solaris-sparc",
--     --
--     ["unknown"]        = "unknown",
-- }

update.platforms = {
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
    ["openbsd"]        = "openbsd6.5",
    ["openbsd-i386"]   = "openbsd6.5",
    ["openbsd-amd64"]  = "openbsd6.5-amd64",
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

local windowsplatform = {
    ["mswin"] = true,
    ["win32"] = true,
    ["win64"] = true,
}

update.selfscripts = {
    "mtxrun",
 -- "luatools",
}

-- the list is filled up later (when we know what modules to download)

update.modules = {
}

update.fonts = {
}

function update.run(str)
    -- important, otherwise formats fly to a weird place
    -- (texlua sets luatex as the engine, we need to reset that or to fix texexec :)
    os.setenv("engine",nil)
    if environment.argument("force") then
        report("run, %s",str)
        os.execute(str)
    else
        report("dry run, %s",str)
    end
end

function update.fullpath(path)
    if file.is_rootbased_path(path) then
        return path
    else
        return lfs.currentdir() .. "/" .. path
    end
end

local function drive(d)
    if update.rsyncvariant == "cygwin" then
        d = gsub(d,[[([a-zA-Z]):/]], "/cygdrive/%1/")
    else
        d = gsub(d,[[([a-zA-Z]):/]], "/%1/")
    end
    return d
end

function update.synchronize()

    report("update, start")

    local texroot      = update.fullpath(states.get("paths.root"))
    local engines      = states.get('engines') or { }
    local platforms    = states.get('platforms') or { }
    local repositories = states.get('repositories')      -- minimals
    local bin          = states.get("rsync.program")     -- rsync
    local url          = states.get("rsync.server")      -- contextgarden.net
    local version      = states.get("context.version")   -- current (or beta)
    local modules      = states.get("modules")           -- modules (third party)
    local fonts        = states.get("fonts")             -- fonts (experimental or special)
    local goodies      = states.get("goodies")           -- goodies (like editors)
    local force        = environment.argument("force")
    local silent       = environment.argument("silent") and "--silent" or ""
    local quiet        = silent == "" and "" or "--quiet"

    bin = gsub(bin,"\\","/")

    if not find(url,"::$") then url = url .. "::" end
    local ok = lfs.attributes(texroot,"mode") == "directory"
    if not ok and force then
        dir.mkdirs(texroot)
        ok = lfs.attributes(texroot,"mode") == "directory"
    end

    if force then
        dir.mkdirs(format("%s/%s", texroot, "texmf-cache"))
        dir.mkdirs(format("%s/%s", texroot, "texmf-local"))
        dir.mkdirs(format("%s/%s", texroot, "texmf-project"))
        dir.mkdirs(format("%s/%s", texroot, "texmf-fonts"))
        dir.mkdirs(format("%s/%s", texroot, "texmf-modules"))
    end

    if ok or not force then

        local fetched, individual, osplatform = { }, { }, os.platform

        -- takes a collection as argument and returns a list of folders

        local function collection_to_list_of_folders(collection, platform)
            local archives = {}
            for i=1,#collection do
                local archive = collection[i][1]
                archive = gsub(archive,"<platform>",platform)
                archive = gsub(archive,"<version>",version)
                archives[#archives+1] = archive
            end
            return archives
        end

        -- takes a list of folders as argument and returns a string for rsync
        -- sample input:
        --     {'bin/common', 'bin/context'}
        -- output:
        --     'minimals/current/bin/common minimals/current/bin/context'

        local function list_of_folders_to_rsync_string(list_of_folders)
            local repository  = 'current'
            local prefix = format("%s/%s/", states.get('rsync.module'), repository) -- minimals/current/

            return prefix .. concat(list_of_folders, format(" %s", prefix))
        end

        -- example of usage: print(list_of_folders_to_rsync_string(collection_to_list_of_folders(update.base, os.platform)))

        -- rename function and add some more functionality:
        --   * recursive/non-recursive (default: non-recursive)
        --   * filter folders or regular files only (default: no filter)
        --   * grep for size of included files (with --stats switch)

        local function get_list_of_files_from_rsync(list_of_folders)
            -- temporary file to store the output of rsync (could be a more random name; watch for overwrites)
            local temp_file = "rsync.tmp.txt"
            -- a set of folders
            local folders = {}
            local command = format("%s %s'%s' > %s", bin, url, list_of_folders_to_rsync_string(list_of_folders), temp_file)
            os.execute(command)
            -- read output of rsync
            local data = io.loaddata(temp_file) or ""
            -- for every line extract the filename :  drwxr-sr-x          18 2013/10/06 06:16:10 libertine
            for chmod, s in gmatch(data,"([d%-][rwxst%-]+).-(%S+)[\n\r]") do
                -- skip "current" folder
                if s ~= '.' and #chmod >= 10 then
                    folders[#folders+1] = s
                end
            end
            -- delete the file to which we have put output of rsync
            os.remove(temp_file)
            return folders
        end

        -- rsync://contextgarden.net/minimals/current/modules/

        local available_platforms = get_list_of_files_from_rsync({"bin/luatex/"})

        report("available platforms: % t",table.sorted(available_platforms))

        if modules and type(modules) == "table" then
            -- fetch the list of available modules from rsync server
         -- local available_modules = get_list_of_files_from_rsync({"modules/"})
            -- hash of requested modules
            -- local h = table.tohash(modules:split(","))
            local available_modules = get_list_of_files_from_rsync({"modules/"})
            local asked = table.copy(modules)
            asked.all = nil
            report("available modules: %s",#available_modules)
            for i=1,#available_modules do
                local s = available_modules[i]
                if modules.all or modules[s] then
                    update.modules[#update.modules+1] = { format("modules/%s/",s), "texmf-modules" }
                    report("+ %s",s)
                else
                    report("  %s",s)
                end
                asked[s] = nil
            end
            if next(asked) then
                report("skipping unknown modules: %s",concat(table.sortedkeys(asked),", "))
            end
        end

        -- rsync://contextgarden.net/minimals/current/fonts/extra/

        if fonts and type(fonts) == "table" then
            local available_fonts = get_list_of_files_from_rsync({"fonts/extra/"})
            local asked = table.copy(fonts)
            asked.all = nil
            for i=1,#available_fonts do
                local s = available_fonts[i]
                if fonts.all or fonts[s] then
                    update.fonts[#update.fonts+1] = { format("fonts/extra/%s/",s), "texmf" }
                end
                asked[s] = nil
            end
            if next(asked) then
                report("skipping unknown fonts: %s",concat(table.sortedkeys(asked),", "))
            end
        end

        local function add_collection(collection,platform)
            if collection and platform then
                platform = update.platforms[platform]
                if platform then
                    for i=1,#collection do
                        local c = collection[i]
                        local archive = gsub(c[1],"<platform>",platform)
                        local destination = format("%s/%s", texroot, gsub(c[2],"<platform>", platform))
                        destination = gsub(destination,"\\","/")
                        archive = gsub(archive,"<version>",version)
                        if osplatform == "windows" or osplatform == "mswin" or osplatform == "win64" then
                            destination = drive(destination)
                        end
                        individual[#individual+1] = { archive, destination }
                    end
                end
            end
        end

        for platform in table.sortedhash(platforms) do
            add_collection(update.base,platform)
        end
        for platform in table.sortedhash(platforms) do
            add_collection(update.modules,platform)
        end
        for platform in table.sortedhash(platforms) do
            add_collection(update.fonts,platform)
        end
        for engine in table.sortedhash(engines) do
            for platform in table.sortedhash(platforms) do
                add_collection(update.engines[engine],platform)
            end
        end

        if goodies and type(goodies) == "table" then
            for goodie in table.sortedhash(goodies) do
                for platform in table.sortedhash(platforms) do
                    add_collection(update.goodies[goodie],platform)
                end
            end
        end

        local combined = { }
        local update_repositories = update.repositories
        for i=1,#update_repositories do
            local repository = update_repositories[i]
            if repositories[repository] then
                for _, v in table.sortedhash(individual) do
                    local archive, destination = v[1], v[2]
                    local cd = combined[destination]
                    if not cd then
                        cd = { }
                        combined[destination] = cd
                    end
                    cd[#cd+1] = format("%s/%s/%s",states.get('rsync.module'),repository,archive)
                end
            end
        end
        for destination, archive in table.sortedhash(combined) do
            local archives, command = concat(archive," "), ""
            local normalflags, deleteflags = states.get("rsync.flags.normal"), ""
            if os.name == "windows" then
                normalflags = normalflags .. " -L" -- no symlinks
            end
            local dryrunflags = ""
            if not environment.argument("force") then
                dryrunflags = "--dry-run"
            end
            if (find(destination,"texmf$") or find(destination,"texmf%-context$") or find(destination,"texmf%-modules$")) and (not environment.argument("keep")) then
                deleteflags = states.get("rsync.flags.delete")
            end
            command = format("%s %s %s %s %s'%s' '%s'", bin, normalflags, deleteflags, dryrunflags, url, archives, drive(destination))
            -- report("running command: %s",command)
            if not fetched[command] then
                update.run(command,true)
                fetched[command] = command
            end
        end

        local function update_script(script, platform)
            local bin = gsub(bin,"\\","/")
            local texroot = gsub(texroot,"\\","/")
            platform = update.platforms[platform]
            if platform then
                local command
                if windowsplatform[platform] then
                    bin = drive(bin)
                    texroot = drive(texroot)
                    command = format([[%s -t "%s/texmf-context/scripts/context/lua/%s.lua" "%s/texmf-%s/bin/"]], bin, texroot, script, texroot, platform)
                else
                    command = format([[%s -tgo --chmod=a+x '%s/texmf-context/scripts/context/lua/%s.lua' '%s/texmf-%s/bin/%s']], bin, texroot, script, texroot, platform, script)
                end
                report("updating %s for %s: %s", script, platform, command)
                update.run(command)
            end
        end

        for platform in table.sortedhash(platforms) do
            for i=1, #update.selfscripts do
                update_script(update.selfscripts[i],platform)
            end
        end

    else
        report("no valid texroot: %s",texroot)
    end
    if not force then
        report("use --force to really update files")
    end

    resolvers.load_tree(texroot) -- else we operate in the wrong tree

    -- update filename database for pdftex/xetex
    update.run(format('mtxrun --tree="%s" %s --direct --resolve mktexlsr %s',texroot,silent,quiet))
    -- update filename database for luatex
    update.run(format('mtxrun --tree="%s" %s --generate',texroot,silent))

    report("update, done")
end

function table.fromhash(t)
    local h = { }
    for k, v in table.sortedhash(t) do -- not indexed
        if v then h[#h+1] = k end
    end
    return h
end

-- make the ConTeXt formats
function update.make()

    report("make, start")

    local force     = environment.argument("force")
    local silent    = environment.argument("silent") and "--silent" or ""
    local quiet     = silent == "" and "" or "--quiet"
    local texroot   = update.fullpath(states.get("paths.root"))
    local engines   = states.get('engines')
    local goodies   = states.get('goodies')
    local platforms = states.get('platforms')
    local formats   = states.get('formats')

    resolvers.load_tree(texroot)

    update.run(format('mtxrun --tree="%s" %s --direct --resolve mktexlsr %s',texroot,silent,quiet))
    update.run(format('mtxrun --tree="%s" %s --generate',texroot,silent))

    local askedformats = formats
    local texformats = table.tohash(update.texformats)
 -- local mpformats = table.tohash(update.mpformats)
    for k,v in table.sortedhash(texformats) do
        if not askedformats[k] then
            texformats[k] = nil
        end
    end
 -- for k,v in table.sortedhash(mpformats) do
 --     if not askedformats[k] then
 --         mpformats[k] = nil
 --     end
 -- end
    local formatlist = concat(table.fromhash(texformats), " ")
    if formatlist ~= "" then
        for engine in table.sortedhash(engines) do
            if engine == "luatex" or engine == "luajittex" then
                update.run(format('mtxrun --tree="%s" %s --script context --autogenerate --make %s',texroot,silent,silent))
                update.run(format('mtxrun --tree="%s" %s --script context --autogenerate --make --engine=luajittex %s',texroot,silent,silent))
            else
             -- update.run(format('mtxrun --tree="%s" %s --script texexec --make --all %s --%s %s',texroot,silent,silent,engine,formatlist))
                update.run(format('mtxrun --tree="%s" --resolve %s --script context --resolve --make %s --engine=%s %s',texroot,silent,silent,engine,formatlist))
            end
        end
    end
 -- local formatlist = concat(table.fromhash(mpformats), " ")
 -- if formatlist ~= "" then
 --     update.run(format('mtxrun --tree="%s" %s --script texexec --make --all %s %s',texroot,silent,silent,formatlist))
 -- end
    if not force then
        report("make, use --force to really make formats")
    end

 -- update.run(format('mtxrun --tree="%s" %s --direct --resolve mktexlsr',texroot,silent)) -- needed for mpost
    update.run(format('mtxrun --tree="%s" %s --generate',texroot,silent))

    report("make, done")
end

scripts.savestate = true

if scripts.savestate then

    states.load("status-of-update.lua")

    -- tag, value, default, persistent

    statistics.starttiming(states)

    states.set("info.version",0.1) -- ok
    states.set("info.count",(states.get("info.count") or 0) + 1,1,false) -- ok
    states.set("info.comment","this file contains the settings of the last 'mtxrun --script update' run",false) -- ok
    states.set("info.date",os.date("!%Y-%m-%d %H:%M:%S")) -- ok

    states.set("rsync.program", environment.argument("rsync"), "rsync", true) -- ok
    states.set("rsync.server", environment.argument("server"), "contextgarden.net::", true) -- ok
    states.set("rsync.module", environment.argument("module"), "minimals", true) -- ok
    states.set("rsync.flags.normal", environment.argument("flags"), "-rpztlv", true) -- ok
    states.set("rsync.flags.delete", nil, "--delete", true) -- ok

    states.set("paths.root", environment.argument("texroot"), "tex", true) -- ok

    states.set("context.version", environment.argument("context"), "current", true) -- ok

    local valid = table.tohash(update.repositories)
    for r in gmatch(environment.argument("repository") or "current","([^, ]+)") do
        if valid[r] then states.set("repositories." .. r, true) end
    end

    local valid = update.engines
    local engine = environment.argument("engine") or ""
    if engine == "" then
        local e = states.get("engines")
        if not e or not next(e) then
            engine = update.defaultengine
        end
    end
    if engine ~= "" then
        for r in gmatch(engine,"([^, ]+)") do
            if r == "all" then
                for k, v in next, valid do
                    if k ~= "all" then
                        states.set("engines." .. k, true)
                    end
                end
                break
            elseif valid[r] then
                states.set("engines." .. r, true)
            end
        end
    end

    -- old

    local valid = update.platforms
    for r in gmatch(environment.argument("platform") or os.platform,"([^, ]+)") do
        if valid[r] then states.set("platforms." .. r, true) end
    end

    -- new

--     local osplatform = environment.arguments.platform or nil
--     local platform   = platforms[osplatform or os.platform or ""]
--
--     if (platform == "unknown" or platform == "" or not platform) and osplatform then
--         -- catches openbsdN.M kind of specifications
--         platform = osplatform
--     elseif not osplatform then
--         osplatform = platform
--     end
--     states.set("platforms." .. platform, true) end

    -- so far

    local valid = table.tohash(update.texformats)
    for r in gmatch(environment.argument("formats") or "","([^, ]+)") do
        if valid[r] then states.set("formats." .. r, true) end
    end

 -- local valid = table.tohash(update.mpformats)
 -- for r in gmatch(environment.argument("formats") or "","([^, ]+)") do
 --     if valid[r] then states.set("formats." .. r, true) end
 -- end

    states.set("formats.cont-en", true)
    states.set("formats.cont-nl", true)
 -- states.set("formats.metafun", true)

    for r in gmatch(environment.argument("extras") or "","([^, ]+)") do -- for old times sake
        if r ~= "all" and not find(r,"^[a-z]%-") then
            r = "t-" .. r
        end
        states.set("modules." .. r, true)
    end
    for r in gmatch(environment.argument("modules") or "","([^, ]+)") do
        if r ~= "all" and not find(r,"^[a-z]%-") then
            r = "t-" .. r
        end
        states.set("modules." .. r, true)
    end
    for r in gmatch(environment.argument("fonts") or "","([^, ]+)") do
        states.set("fonts." .. r, true)
    end
    for r in gmatch(environment.argument("goodies") or "","([^, ]+)") do
        states.set("goodies." .. r, true)
    end

    report("state, loaded")
    report()

end

if environment.argument("state") then
    environment.setargument("update",true)
    environment.setargument("force",true)
    environment.setargument("make",true)
end

if environment.argument("mingw") then
    update.rsyncvariant = "mingw"
elseif environment.argument("cygwin") then
    update.rsyncvariant = "cygwin"
end

if environment.argument("update") then
    update.synchronize()
    if environment.argument("make") then
        update.make()
    end
elseif environment.argument("make") then
    update.make()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end

if scripts.savestate then
    statistics.stoptiming(states)
    states.set("info.runtime",tonumber(statistics.elapsedtime(states)))
    if environment.argument("force") then
        states.save()
        report("state","saved")
    end
end
