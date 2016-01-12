if not modules then modules = { } end modules ['util-lib'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- This is experimental code for Hans and Luigi. Don't depend on it! There
-- will be a plain variant.

--[[

The problem with library bindings is manyfold. They are of course platform
dependent and while a binary with its directly related libraries are often
easy to maintain and load, additional libraries can each have their demands.

One important aspect is that loading additional libraries from within the
loaded one is also operating system dependent. There can be shared libraries
elsewhere on the system and as there can be multiple libraries with the same
name but different usage and versioning there can be clashes. So there has to
be some logic in where to look for these sublibraries.

We found out that for instance on windows libraries are by default sought on
the parents path and then on the binary paths and these of course can be in
an out of our control, thereby enlarging the changes on a clash. A rather
safe solution for that to load the library on the path where it sits.

Another aspect is initialization. When you ask for a library t.e.x it will
try to initialize luaopen_t_e_x no matter if such an inializer is present.
However, because loading is configurable and in the case of luatex is already
partly under out control, this is easy to deal with. We only have to make
sure that we inform the loader that the library has been loaded so that
it won't load it twice.

In swiglib we have chosen for a clear organization and although one can use
variants normally in the tex directory structure predictability is more or
less the standard. For instance:

.../tex/texmf-mswin/bin/lib/luatex/lua/swiglib/mysql/core.dll
.../tex/texmf-mswin/bin/lib/luajittex/lua/swiglib/mysql/core.dll
.../tex/texmf-mswin/bin/lib/luatex/context/lua/swiglib/mysql/core.dll
.../tex/texmf-mswin/bin/lib/swiglib/lua/mysql/core.dll
.../tex/texmf-mswin/bin/lib/swiglib/lua/mysql/5.6/core.dll

The lookups are determined via an entry in texmfcnf.lua:

CLUAINPUTS = ".;$SELFAUTOLOC/lib/{$engine,luatex}/lua//",

A request for t.e.x is converted to t/e/x.dll or t/e/x.so depending on the
platform. Then we use the regular finder to locate the file in the tex
directory structure. Once located we goto the path where it sits, load the
file and return to the original path. We register as t.e.x in order to
prevent reloading and also because the base name is seldom unique.

The main function is a big one and evolved out of experiments that Luigi
Scarso and I conducted when playing with variants of SwigLib. The function
locates the library using the context mkiv resolver that operates on the
tds tree and if that doesn't work out well, the normal clib path is used.

The lookups is somewhat clever in the sense that it can deal with (optional)
versions and can fall back on non versioned alternatives if needed, either
or not using a wildcard lookup.

This code is experimental and by providing a special abstract loader (called
swiglib) we can start using the libraries.

A complication is that we might end up with a luajittex path matching before a
luatex path due to the path spec. One solution is to first check with the engine
prefixed. This could be prevented by a more strict lib pattern but that is not
always under our control. So, we first check for paths with engine in their name
and then without.

]]--

-- seems to be clua in recent texlive

local gsub, find = string.gsub, string.find
local pathpart, nameonly, joinfile = file.pathpart, file.nameonly, file.join
local findfile, findfiles = resolvers and resolvers.findfile, resolvers and resolvers.findfiles

local loaded         = package.loaded

local report_swiglib = logs.reporter("swiglib")
local trace_swiglib  = false  trackers.register("resolvers.swiglib", function(v) trace_swiglib = v end)

-- We can check if there are more that one component, and if not, we can
-- append 'core'.

local done = false

local function requireswiglib(required,version)
    local trace_swiglib = trace_swiglib or package.helpers.trace
    local library = loaded[required]
    if library == nil then
        if trace_swiglib then
            report_swiglib("requiring library %a with version %a",required,version or "any")
        end
        -- initialize a few variables
        local required_full = gsub(required,"%.","/") -- package.helpers.lualibfile
        local required_path = pathpart(required_full)
        local required_base = nameonly(required_full)
        local required_name = required_base .. "." .. os.libsuffix
        local version       = type(version) == "string" and version ~= "" and version or false
        local engine        = environment.ownmain or false
        --
        if trace_swiglib and not done then
            local list = resolvers.expandedpathlistfromvariable("lib") -- fresh, no reuse
            for i=1,#list do
               report_swiglib("tds path %i: %s",i,list[i])
            end
        end
        -- helpers
        local function found(locate,asked_library,how,...)
            if trace_swiglib then
                report_swiglib("checking %s: %a",how,asked_library)
            end
            return locate(asked_library,...)
        end
        local function check(locate,...)
            local found = nil
            if version then
                local asked_library = joinfile(required_path,version,required_name)
                if trace_swiglib then
                    report_swiglib("checking %s: %a","with version",asked_library)
                end
                found = locate(asked_library,...)
            end
            if not found or found == "" then
                local asked_library = joinfile(required_path,required_name)
                if trace_swiglib then
                    report_swiglib("checking %s: %a","with version",asked_library)
                end
                found = locate(asked_library,...)
            end
            return found and found ~= "" and found or false
        end
        -- Alternatively we could first collect the locations and then do the two attempts
        -- on this list but in practice this is not more efficient as we might have a fast
        -- match anyway.
        local function attempt(checkpattern)
            -- check cnf spec using name and version
            if trace_swiglib then
                report_swiglib("checking tds lib paths strictly")
            end
            local found = findfile and check(findfile,"lib")
            if found and (not checkpattern or find(found,checkpattern)) then
                return found
            end
            -- check cnf spec using wildcard
            if trace_swiglib then
                report_swiglib("checking tds lib paths with wildcard")
            end
            local asked_library = joinfile(required_path,".*",required_name)
            if trace_swiglib then
                report_swiglib("checking %s: %a","latest version",asked_library)
            end
            local list = findfiles(asked_library,"lib",true)
            if list and #list > 0 then
                table.sort(list)
                local found = list[#list]
                if found and (not checkpattern or find(found,checkpattern)) then
                    return found
                end
            end
            -- Check lib paths using name and version.
            if trace_swiglib then
                report_swiglib("checking lib paths")
            end
            package.extralibpath(environment.ownpath)
            local paths = package.libpaths()
            for i=1,#paths do
                local found = check(lfs.isfile)
                if found and (not checkpattern or find(found,checkpattern)) then
                    return found
                end
            end
            return false
        end
        local found_library = nil
        if engine then
            if trace_swiglib then
                report_swiglib("attemp 1, engine %a",engine)
            end
            found_library = attempt("/"..engine.."/")
            if not found_library then
                if trace_swiglib then
                    report_swiglib("attemp 2, no engine",asked_library)
                end
                found_library = attempt()
            end
        else
            found_library = attempt()
        end
        -- load and initialize when found
        if not found_library then
            if trace_swiglib then
                report_swiglib("not found: %a",required)
            end
            library = false
        else
            local path = pathpart(found_library)
            local base = nameonly(found_library)
            dir.push(path)
            if trace_swiglib then
                report_swiglib("found: %a",found_library)
            end
            local message = nil
            local opener  = "luaopen_" .. required_base
            library, message = package.loadlib(found_library,opener)
            local libtype = type(library)
            if libtype == "function" then
                library = library()
            else
                report_swiglib("load error: %a returns %a, message %a, library %a",opener,libtype,(string.gsub(message or "no message","[%s]+$","")),found_library or "no library")
                library = false
            end
            dir.pop()
        end
        -- cache result
        if not library then
            report_swiglib("unknown: %a",required)
        elseif trace_swiglib then
            report_swiglib("stored: %a",required)
        end
        loaded[required] = library
    else
        report_swiglib("reused: %a",required)
    end
    return library
end

--[[

For convenience we make the require loader function swiglib aware. Alternatively
we could put the specific loader in the global namespace.

]]--

local savedrequire = require

function require(name,version)
    if find(name,"^swiglib%.") then
        return requireswiglib(name,version)
    else
        return savedrequire(name)
    end
end

--[[

At the cost of some overhead we provide a specific loader so that we can keep
track of swiglib usage which is handy for development. In context this is the
recommended loader.

]]--

local swiglibs    = { }
local initializer = "core"

function swiglib(name,version)
    local library = swiglibs[name]
    if not library then
        statistics.starttiming(swiglibs)
        if trace_swiglib then
            report_swiglib("loading %a",name)
        end
        if not find(name,"%." .. initializer .. "$") then
            fullname = "swiglib." .. name .. "." .. initializer
        else
            fullname = "swiglib." .. name
        end
        library = requireswiglib(fullname,version)
        swiglibs[name] = library
        statistics.stoptiming(swiglibs)
    end
    return library
end

statistics.register("used swiglibs", function()
    if next(swiglibs) then
        return string.format("%s, initial load time %s seconds",table.concat(table.sortedkeys(swiglibs)," "),statistics.elapsedtime(swiglibs))
    end
end)

--[[

So, we now have:

local gm = require("swiglib.gmwand.core")
local gm = swiglib("gmwand.core")
local sq = swiglib("mysql.core")
local sq = swiglib("mysql.core","5.6")

Watch out, the last one is less explicit and lacks the swiglib prefix.

]]--
