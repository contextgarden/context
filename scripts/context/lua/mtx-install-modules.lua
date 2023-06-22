if not modules then modules = { } end modules ['mtx-install-modules'] = {
    version   = 1.234,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen",
    copyright = "ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Installing tikz is a bit tricky because there are many packages involved and it's
-- sort of impossible to derive from the names what to include in the installation.
-- I tried to use the ctan scrips we ship but there is no way to reliably derive a
-- set from the topics or packages using the web api (there are also some
-- inconsistencies between the json and xml interfaces that will not be fixed). A
-- wildcard pull of everything tikz/pgf is likely to fail or at least gives files we
-- don't want and/or need, the solution is to be specific.
--
-- After that was implemented the script changed name and now also installs the
-- third party modules.
--
-- We use curl and not the built in socket library because all kind of ssl and
-- redirection can kick in and who know how it evolves.
--
-- We use the context unzipper because we cannot be sure if unzip is present on the
-- system. In many cases windows, linux and osx installations lack it by default.
--
-- This script should be run in the tex root where there is also a texmf-context sub
-- directory; it will quit otherwise. The modules path will be created when absent.
--
-- Maybe some day we can get the modules from ctan but then we need a consistent
-- names and such.

local find = string.find

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-install</entry>
  <entry name="detail">ConTeXt Installer</entry>
  <entry name="version">2.01</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="list"><short>list modules</short></flag>
    <flag name="installed"><short>list installed modules</short></flag>
    <flag name="install"><short>install modules</short></flag>
    <flag name="uninstall"><short>uninstall modules</short></flag>
    <flag name="module"><short>install (zip) file(s)</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Examples</title>
   <subcategory>
    <example><command>mtxrun --script install-modules --list</command></example>
   </subcategory>
   <subcategory>
    <example><command>mtxrun --script install-modules --install filter letter</command></example>
    <example><command>mtxrun --script install-modules --install tikz</command></example>
    <example><command>mtxrun --script install-modules --install --all</command></example>
   </subcategory>
   <subcategory>
    <example><command>mtxrun --script install-modules --install   --module t-letter.zip</command></example>
    <example><command>mtxrun --script install-modules --uninstall --module t-letter.zip</command></example>
   </subcategory>
   <subcategory>
    <example><command>mtxrun --script install-modules --installed</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-install-modules",
    banner   = "ConTeXt Module Installer 1.00",
    helpinfo = helpinfo,
}

local report = application.report

scripts         = scripts         or { }
scripts.modules = scripts.modules or { }

local okay, curl = pcall(require,"libs-imp-curl")

local fetched = curl and curl.fetch and function(str)
    local data, message = curl.fetch {
        url            = str,
        followlocation = true,
        sslverifyhost  = false,
        sslverifypeer  = false,
    }
    if not data then
        report("some error: %s",message)
    end
    return data
end or function(str)
    -- So, no redirect to http, which means that we cannot use the built in socket
    -- library. What if the client is happy with http?
    local data = os.resultof("curl -sSL " .. str)
    return data
end

-- We use some abstraction:

local urls = {
    ctan    = "https://mirrors.ctan.org/install",
    modules = "https://modules.contextgarden.net/dl"
}

-- Some package this in the root which is asking for conflicts.

-- local badones = {
--  -- "LICENSE",
--  -- "README",
--  -- "README.md",
--  -- "VERSION",
-- }

local tmpzipfile = "temp.zip"
local checkdir   = "texmf-context"
local targetdir  = "texmf-modules"
local basefile   = "mtx-install-imp-modules.lua"
local lists      = false

-- local lists = {
--     ["tikz"] = {
--         url   = "ctan",
--         zips  = { }, -- table of zip files
--         wipes = { }, -- (nested) table of delete patterns
--     },
--     ["filter"] = {
--         url   = "modules",
--         zips  = { "t-filter.zip" }
--     },
-- }

local function loadlists()
    if not lists then
        lists = { }
        local mainfile = resolvers.findfile(basefile)
        if mainfile and mainfile ~= "" then
            local path  = file.pathpart(mainfile)
            local files = dir.glob((path == "" and "." or path) .. "/mtx-install-imp*.lua")
            for i=1,#files do
                local name = files[i]
                local data = table.load(name)
                if data then
                    local entries = data.lists
                    if entries then
                        report("loading entries from file %a",name)
                        for entry, data in table.sortedhash(entries) do
                            if lists[entry] then
                                report("entry %a already set from %a",entry,name)
                            else
                                lists[entry] = data
                            end
                        end
                    else
                        report("no entries in file %a",name)
                    end
                end
            end
        else
            report("base file %a is not found",basefile)
        end
        report()
    end
end

local function validate(n)
    return not (
           find(n,"latex")
        or find(n,"lualatex")
        or find(n,"plain")
        or find(n,"optex")
     -- or find(n,"luatex")
     -- or find(n,"pdftex")
    )
end

local function install(list,wipe)
    if type(list) ~= "table" then
        report("unknown specification")
    end
    local zips  = list.zips
    local wipes = list.wipes
    if type(zips) ~= "table" then
        report("incomplete specification")
    else
     -- report("installing into %a",targetdir)
        for i=1,#zips do
            local remote = list.url
            local where  = zips[i]
            local hash = file.addsuffix(sha2.HASH256(where),"tma")
            local data = table.load(hash)
            if data then
                local name = data.name
                local list = data.list
                if name and list then
                    report()
                    report("removing %i old files for %a",#list,name)
                    report()
                    for i=1,#list do
                        os.remove(list[i])
                    end
                end
            end
            if not wipe then
                if remote then
                    where = (urls[remote] or remote) .. "/" .. where
                end
                local data  = fetched(where)
                if string.find(data,"^PK") then
                    io.savedata(tmpzipfile,data)
                    report("from %a",where)
                    report("into %a",targetdir)
                    local done = utilities.zipfiles.unzipdir {
                        zipname  = tmpzipfile,
                        path     = ".",
                        verbose  = "steps",
                        collect  = true,
                        validate = validate,
                    }
                    table.save(hash,{ name = where, list = done })
                    os.remove(tmpzipfile)
                else
                    report("unknown %a",where)
                end
            end
        end

        local function wiper(wipes)
            for i=1,#wipes do
                local s = wipes[i]
                if type(s) == "table" then
                    wiper(s)
                elseif type(s) == "string" then
                    local t = dir.glob(s)
                    report("wiping %i files in %a",#t,s)
                    for i=1,#t do
-- report("wiping %a",t[i])
                        os.remove(t[i])
                    end
                end
            end
        end

        if type(wipes) == "table" then
            wiper(wipes)
        end
    end
end

function scripts.modules.list()
    loadlists()
    for k, v in table.sortedhash(lists) do
        report("%-20s: %-36s : % t",k,urls[v.url],v.zips)
    end
end

function scripts.modules.installed()
    local files = dir.glob(targetdir .. "/*.tma")
    if files then
        for i=1,#files do
            local data = table.load(files[i])
            if data then
                local name = data.name
                local list = data.list
                if name and list then
                    report("%4i : %s",#list,name)
                end
            end
        end
    end
end

function scripts.modules.install(wipe)
    local curdir = dir.current()
    local done   = false
    if not lfs.isdir(checkdir) then
        report("unknown subdirectory %a",checkdir)
    elseif not dir.mkdirs(targetdir) then
        report("unable to create %a",targetdir)
    elseif not lfs.chdir(targetdir) then
        report("unable to go into %a",targetdir)
    elseif environment.argument("module") or environment.argument("modules") then
        local files = environment.files
        if #files == 0 then
            report("no archive names provided")
        else
            for i=1,#files do
                local name = files[i]
                if url.hasscheme(name) then
                    install({ url = false, zips = { file.addsuffix(name,"zip") } }, wipe)
                else
                    loadlists()
                    install({ url = "modules", zips = { file.addsuffix(name,"zip") } }, wipe)
                end
            end
            done = files
        end
    else
        loadlists()
        local files = environment.argument("all") and table.sortedkeys(lists) or environment.files
        if #files == 0 then
            report("no module names provided")
        else
            for i=1,#files do
                local name = files[i]
                local list = lists[name]
                if list then
                    install(list,wipe)
                end
            end
            done = files
        end
    end
    if done then
        --
     -- for i=1,#badones do
     --     os.remove(badones[i])
     -- end
        local okay = false
        local files = dir.glob("*")
        for i=1,#files do
            local name = files[i]
            if file.suffix(name) == "tma" then
                -- keep it
            else
                if not okay then
                    report()
                    okay = true
                end
                report("removed %a",name)
                os.remove(name)
            end
        end
        --
        report()
        report("renewing file database")
        report()
        resolvers.renewcache()
        resolvers.load()
        report()
        report("installed: % t",done)
        report()
    end
    lfs.chdir(curdir)
end

function scripts.modules.uninstall()
    scripts.modules.install(true)
end

if environment.argument("list") then
    scripts.modules.list()
elseif environment.argument("installed") then
    scripts.modules.installed()
elseif environment.argument("install") then
    scripts.modules.install()
elseif environment.argument("uninstall") then
    scripts.modules.uninstall()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
    report("")
end

