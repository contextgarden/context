if not modules then modules = { } end modules ['mtxlibs'] = {
    version   = 1.001,
    comment   = "a reasonable subset of mtxrun preloaded libraries",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This file can be used to load a the (relevant) helper libraries that are also used
-- in ConTeXt. You can use it as:
--
--   -- if needed (outside texlua):
--
--   -- require("lpeg")      -- mandate
--   -- require("md5")       -- handy
--   -- require("lfs")       -- recommended
--   -- require("slunicode") -- sort of obsolete
--
--   -- the library:
--
--   require("mtxlibs")
--
-- An alternative is to merge all libraries into this one so that you don't have to
-- distribute them.
--
--   mtxlibs --selfmerge
--
-- If you need additional libraries, you can do something like this:
--
--   lua mtxlibs.lua  --selfmerge  my-web-project.lua  trac-lmx util-jsn
--   lua mtxlibs.lua  --selfmerge  my-sql-project.lua  util-sql util-sql-imp-library util-sql-imp-client
--
-- That way you only need to update one file in a project and are not dependent on changes
-- in the core ConTeXT libraries. The libraries are maintained as part of ConTeXt and used
-- in projects so relative stable. The code works in Lua 5.1 as well as in 5.2. Not all
-- functionality makes sense for users who are not familiar with ConTeXt but for instance
-- trackers and loggers are included because that way we have can provide users with a
-- consistent ecosystem.
--
-- Much of the provided functionality is described in cld-mkiv.pdf and related manuals, on
-- contextgarden.net as well in articles. The XML subsystem is described in its own manual.
-- Templates and SQL (not preloaded) is also has its own manual.
--
-- The next section contains the merged code, with each block ending uop in its own
-- closure. The code gets somewhat compacted to save space and speed up loading.
--
-- There are some dependencies between the several modules. Also, quite some functions are added
-- to the regular Lua namespaces. In due time I'll isolate them in their own namespaces but with
-- the for context handy option to expose them in the normal ones. I might make the dependencies
-- less but it probably makes no sense to waste time on them.

xpcall(function() local _, t = require("lpeg")      if t then lpeg     = t end return  end,function() end)
xpcall(function() local _, t = require("md5")       if t then md5      = t end return  end,function() end)
xpcall(function() local _, t = require("lfs")       if t then lfs      = t end return  end,function() end)
xpcall(function() local _, t = require("slunicode") if t then unicode  = t end return  end,function() end)

-- begin library merge

-- end library merge

local gsub, gmatch, match, find = string.gsub, string.gmatch, string.match, string.find
local concat = table.concat

local ownname = arg and arg[0] or 'mtxlibs.lua'
local ownpath = gsub(match(ownname,"^(.+)[\\/].-$") or ".","\\","/")
local owntree = ownpath

local ownlibs = {

    "l-bit32.lua",
    "l-lua.lua",
    "l-macro.lua",
    "l-sandbox.lua",
    "l-package.lua",
    "l-lpeg.lua",
    "l-function.lua",
    "l-string.lua",
    "l-table.lua",
    "l-io.lua",
    "l-number.lua",
    "l-set.lua",
    "l-os.lua",
    "l-file.lua",     -- limited functionality when no lfs
 -- "l-gzip.lua",
    "l-md5.lua",      -- not loaded when no md5 library
    "l-sha.lua",      -- not loaded when no sha2 library
    "l-url.lua",
    "l-dir.lua",      -- limited functionality when no lfs
    "l-boolean.lua",
    "l-unicode.lua",  -- nowadays independent of slunicode
    "l-math.lua",

    "util-str.lua",
    "util-tab.lua",
    "util-fil.lua",
    "util-sac.lua",
    "util-sto.lua",
 -- "util-lua.lua", -- no need for compiling
    "util-prs.lua",
 -- "util-fmt.lua", -- no need for table formatters
 -- "util-deb.lua", -- no need for debugging (and tracing)

    "util-soc-imp-reset",
    "util-soc-imp-socket",
    "util-soc-imp-copas",
    "util-soc-imp-ltn12",
 -- "util-soc-imp-mbox",
    "util-soc-imp-mime",
    "util-soc-imp-url",
    "util-soc-imp-headers",
    "util-soc-imp-tp",
    "util-soc-imp-http",
    "util-soc-imp-ftp",
    "util-soc-imp-smtp",

    "trac-set.lua",
    "trac-log.lua",
 -- "trac-pro.lua",  -- not relevant outside context
    "trac-inf.lua",

    "util-mrg.lua",
    "util-tpl.lua",
    "util-sbx.lua",

    "util-env.lua",
 -- "luat-env.lua",  -- not relevant outside context

    "lxml-tab.lua",
    "lxml-lpt.lua",
    "lxml-mis.lua",
    "lxml-aux.lua",
    "lxml-xml.lua",

    "trac-xml.lua",  -- handy for helpinfo
}

package.path = "t:/sources/?.lua;t:/sources/?;" .. package.path

local ownlist = {
    '.',
    ownpath ,
    ownpath .. "/../sources", -- HH's development path
    --
    owntree .. "/../../texmf-local/tex/context/base/mkiv",
    owntree .. "/../../texmf-context/tex/context/base/mkiv",
    owntree .. "/../../texmf/tex/context/base/mkiv",
    owntree .. "/../../../texmf-local/tex/context/base/mkiv",
    owntree .. "/../../../texmf-context/tex/context/base/mkiv",
    owntree .. "/../../../texmf/tex/context/base/mkiv",
    --
    owntree .. "/../../texmf-local/tex/context/base",
    owntree .. "/../../texmf-context/tex/context/base",
    owntree .. "/../../texmf/tex/context/base",
    owntree .. "/../../../texmf-local/tex/context/base",
    owntree .. "/../../../texmf-context/tex/context/base",
    owntree .. "/../../../texmf/tex/context/base",
}

if ownpath == "." then table.remove(ownlist,1) end

own = {
    name = ownname,
    path = ownpath,
    tree = owntree,
    list = ownlist,
    libs = ownlibs,
}

local function locate_libs()
    local name = ownlibs[1]
    local done = false
    for i=1,#ownlist do
        local path = ownlist[i]
        local filename = path .. "/" .. name
        local f = io.open(filename)
        if f then
            f:close()
            package.path = package.path .. ";" .. path .. "/?.lua" -- in case l-* does a require
            done = path
            break
        end
    end
    locate_libs = function() return done end
    return done
end

local function load_libs()
    local found = locate_libs()
    if found then
        for i=1,#ownlibs do
            local basename = ownlibs[i]
            local filename = found .. "/" .. basename
            local codeblob = loadfile(filename)
            if codeblob then
                package.preload[basename] = codeblob() or true
            end
        end
    end
end

if not unicode then
    load_libs()
end

local merger = utilities and utilities.merger

if not merger then
    return
end

local arguments = environment.arguments
local files     = environment.files

local ownname   = file.basename(environment.ownname)

local helpinfo = [[
usage: mtxlibs [options]

--selfmerge
--selfmerge targetfile extralibs
--selfclean

and in a lua file:

require("mtxlibs")
]]

local application = logs.application {
    name     = "mtxlibs",
    banner   = "ConTeXt Basic Lua Libraries 1.00",
    helpinfo = helpinfo,
}

local report = application.report

if ownname == "mtxrun" or ownname == "mtxrun.lua" then
    -- we're using mtxrun
    ownname = "mtxlibs.lua"
elseif ownname == "mtxlibs" or ownname == "mtxlibs.lua" then
    -- we're using lua
    ownname = "mtxlibs.lua"
else
    report("usage : lua mtxlibs.lua ...")
    report("      : mtxrun --script mtxlibs.lua ...")
    return
end

if arguments.selfmerge then

    report("merging libraries")
    local found = locate_libs()
    if found then
        local target = files[1]
        if target == ownname then
            report("target cannot be this file")
            return
        elseif target then
            report("target: %s",target)
            for i=1,#files do
                ownlibs[#ownlibs+1] = file.addsuffix(files[i],"lua")
            end
        end
        merger.selfmerge(ownname,ownlibs,{ found },target)
        report("done")
    else
        report("no libraries found")
    end

elseif arguments.selfclean then

    report("cleaning libraries")
    merger.selfclean(ownname)
    report("done")

else -- if arguments.help or files[1] == "help" then

    application.help()

end
