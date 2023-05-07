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
    <flag name="install"><short>install modules</short></flag>
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
    <example><command>mtxrun --script install-modules --install --module t-letter.zip</command></example>
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

local urls = {
    ctan    = "https://mirrors.ctan.org/install",
    modules = "https://modules.contextgarden.net/dl"
}

local tmpzipfile = "temp.zip"
local checkdir   = "texmf-context"
local targetdir  = "texmf-modules"

local function install(list)
    if type(list) ~= "table"then
        report("unknown specification")
    end
    local zips   = list.zips
    local wipes  = list.wipes
    if type(zips) ~= "table" then
        report("incomplete specification")
    else
        report("installing into %a",targetdir)
        for i=1,#zips do
            local where = urls[list.url] .. "/" .. zips[i]
            local data  = fetched(where)
            if string.find(data,"^PK") then
                io.savedata(tmpzipfile,data)
                report("from %a",where)
                report("into %a",targetdir)
                utilities.zipfiles.unzipdir {
                    zipname = tmpzipfile,
                    path    = ".",
                    verbose = "steps",
                }
                os.remove(tmpzipfile)
            else
                report("unknown %a",where)
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

local function wipers(s)
    return {
        "tex/context/third/"    ..s.. "/**",
        "doc/context/third/"    ..s.. "/**",
        "source/context/third/" ..s.. "/**",

        "tex/context/"          ..s.. "/**",
        "doc/context/"          ..s.. "/**",
        "source/context/"       ..s.. "/**",

        "scripts/"              ..s.. "/**",
    }
end

local defaults = {
    "tex/latex/**",
    "tex/plain/**",

    "doc/latex/**",
    "doc/plain/**",
    "doc/generic/**",

    "source/latex/**",
    "source/plain/**",
    "source/generic/**",
}

local lists = {
    ["tikz"] = {
        url  = "ctan",
        zips = {
            "graphics/pgf/base/pgf.tds.zip",
            "graphics/pgf/contrib/pgfplots.tds.zip",
            "graphics/pgf/contrib/circuitikz.tds.zip",
        },
        wipes = {
            wipers("pgf"),
            wipers("pgfplots"),
            wipers("circuitikz"),
            defaults,
        }
    },
    -- from the context garden
    ["pocketdiary"]       = { url = "modules", zips = { "Collection-of-calendars-based-on-PocketDiary-module.zip" } },
    ["collating"]         = { url = "modules", zips = { "Environment-for-collating-marks.zip" } },
    ["account"]           = { url = "modules", zips = { "t-account.zip" } },
    ["algorithmic"]       = { url = "modules", zips = { "t-algorithmic.zip" } },
    ["animation"]         = { url = "modules", zips = { "t-animation.zip" } },
    ["annotation"]        = { url = "modules", zips = { "t-annotation.zip" } },
    ["aquamints"]         = { url = "modules", zips = { "aquamints.zip" } },
    ["bibmod-doc"]        = { url = "modules", zips = { "bibmod-doc.zip" } },
 -- ["bnf-0.3"]           = { url = "modules", zips = { "t-bnf-0.3.zip" } },
    ["bnf"]               = { url = "modules", zips = { "t-bnf.zip" } },
    ["chromato"]          = { url = "modules", zips = { "t-chromato.zip" } },
    ["cmscbf"]            = { url = "modules", zips = { "t-cmscbf.zip" } },
    ["cmttbf"]            = { url = "modules", zips = { "t-cmttbf.zip" } },
    ["crossref"]          = { url = "modules", zips = { "t-crossref.zip" } },
    ["cyrillicnumbers"]   = { url = "modules", zips = { "t-cyrillicnumbers.zip" } },
    ["degrade"]           = { url = "modules", zips = { "t-degrade.zip" } },
    ["enigma"]            = { url = "modules", zips = { "enigma.zip" } },
    ["fancybreak"]        = { url = "modules", zips = { "t-fancybreak.zip" } },
    ["filter"]            = { url = "modules", zips = { "t-filter.zip" } },
    ["french"]            = { url = "modules", zips = { "t-french.zip" } },
    ["fullpage"]          = { url = "modules", zips = { "t-fullpage.zip" } },
    ["gantt"]             = { url = "modules", zips = { "t-gantt.zip" } },
    ["gfsdidot"]          = { url = "modules", zips = { "gfsdidot.zip" } },
    ["gm"]                = { url = "modules", zips = { "t-gm.zip" } },
    ["gnuplot"]           = { url = "modules", zips = { "t-gnuplot.zip" } },
    ["greek"]             = { url = "modules", zips = { "t-greek.zip" } },
    ["grph-downsample"]   = { url = "modules", zips = { "grph-downsample.lua.zip" } },
    ["gs"]                = { url = "modules", zips = { "t-gs.zip" } },
    ["high"]              = { url = "modules", zips = { "high.zip" } },
    ["inifile"]           = { url = "modules", zips = { "t-inifile.zip" } },
    ["karnaugh"]          = { url = "modules", zips = { "karnaugh.zip" } },
    ["layout"]            = { url = "modules", zips = { "t-layout.zip" } },
    ["letter"]            = { url = "modules", zips = { "t-letter.zip" } },
    ["letterspace"]       = { url = "modules", zips = { "t-letterspace.mkiv.zip" } },
    ["lettrine"]          = { url = "modules", zips = { "t-lettrine.zip" } },
    ["lua-widow-control"] = { url = "modules", zips = { "lua-widow-control.zip" } },
    ["mathsets"]          = { url = "modules", zips = { "t-mathsets.zip" } },
    ["metaducks"]         = { url = "modules", zips = { "metaducks.zip" } },
    ["pret-c.lua"]        = { url = "modules", zips = { "pret-c.lua.zip" } },
    ["rst"]               = { url = "modules", zips = { "t-rst.zip" } },
    ["rsteps"]            = { url = "modules", zips = { "t-rsteps.zip" } },
    ["simplebib"]         = { url = "modules", zips = { "t-simplebib.zip" } },
    ["simplefonts"]       = { url = "modules", zips = { "t-simplefonts.zip" } },
    ["simpleslides"]      = { url = "modules", zips = { "t-simpleslides.zip" } },
    ["stormfontsupport"]  = { url = "modules", zips = { "stormfontsupport.zip" } },
    ["sudoku"]            = { url = "modules", zips = { "sudoku.zip" } },
    ["taspresent"]        = { url = "modules", zips = { "t-taspresent.zip" } },
    ["texshow"]           = { url = "modules", zips = { "u-texshow.zip" } },
    ["title"]             = { url = "modules", zips = { "t-title.zip" } },
    ["transliterator"]    = { url = "modules", zips = { "t-transliterator.zip" } },
    ["typearea"]          = { url = "modules", zips = { "t-typearea.zip" } },
    ["typescripts"]       = { url = "modules", zips = { "t-typescripts.zip" } },
    ["urwgaramond"]       = { url = "modules", zips = { "f-urwgaramond.zip" } },
    ["urwgothic"]         = { url = "modules", zips = { "f-urwgothic.zip" } },
    ["vim"]               = { url = "modules", zips = { "t-vim.zip" } },
    ["visualcounter"]     = { url = "modules", zips = { "t-visualcounter.zip" } },
}


function scripts.modules.list()
    for k, v in table.sortedhash(lists) do
        report("%-20s: %-36s : % t",k,urls[v.url],v.zips)
    end
end

function scripts.modules.install()
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
                install { url = "modules", zips = { file.addsuffix(name,"zip") } }
            end
            done = files
        end
    else
        local files = environment.argument("all") and table.sortedkeys(lists) or environment.files
        if #files == 0 then
            report("no module names provided")
        else
            for i=1,#files do
                local list = lists[files[i]]
                if list then
                    install(list)
                end
            end
            done = files
        end
    end
    if done then
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

if environment.argument("list") then
    scripts.modules.list()
elseif environment.argument("install") then
    scripts.modules.install()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
    report("")
end

