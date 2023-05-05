if not modules then modules = { } end modules ['mtx-install-tikz'] = {
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
-- inconsistencies between the jkson and xml interfaces that will not be fixed). A
-- wildcard pull of everything tikz/pgf is likely to fail or at least gives files we
-- don't want and/or need, the solution is to be specific.
--
-- We use curl and not the built in socket library because all kind of ssl and
-- redirection can kick in and who know how it evolves.
--
-- We use the context unzipper because we cannot be sure if unzip is present on the
-- system. In many cases windows, linux and osx installations lack it by default.
--
-- This script has no help info etc as it's a rather dumb downloader. One can always
-- do a better job than this suboptimal quick hack. Let me know if I forget to wipe
-- something.
--
--   mtxrun --script install-tikz
--
-- It should be run in the tex root and will quit when there is no texmf-context
-- path found. The modules path will be created when absent.

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

local ctanurl    = "https://mirrors.ctan.org/install"
local tmpzipfile = "temp.zip"
local checkdir   = "texmf-context"
local targetdir  = "texmf-modules"

local report = logs.reporter("install")

scripts      = scripts      or { }
scripts.ctan = scripts.ctan or { }

function scripts.ctan.install(list)
    if type(list) ~= "table"then
        report("unknown specification")
    end
    local zips  = list.zips
    local wipes = list.wipes
    if type(zips) ~= "table" or type(wipes) ~= "table" then
        report("incomplete specification")
    elseif not lfs.isdir(checkdir) then
        report("unknown subdirectory %a",checkdir)
    elseif not dir.mkdirs(targetdir) then
        report("unable to create %a",targetdir)
    elseif not lfs.chdir(targetdir) then
        report("unable to go into %a",targetdir)
    else
        report("installing into %a",targetdir)
        for i=1,#zips do
            local where = ctanurl .. "/" .. zips[i]
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

        wiper(wipes)

        report("renewing file database")
        resolvers.renewcache()
        resolvers.load()
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
    tikz = {
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
}

scripts.ctan.install(lists.tikz)
