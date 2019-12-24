 if not modules then modules = { } end modules ['luat-env'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- A former version provided functionality for non embeded core scripts i.e. runtime
-- library loading. Given the amount of Lua code we use now, this no longer makes
-- sense. Much of this evolved before bytecode arrays were available and so a lot of
-- code has disappeared already.

local rawset, loadfile = rawset, loadfile
local gsub = string.gsub

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_lua = logs.reporter("resolvers","lua")

local luautilities = utilities.lua
local luasuffixes  = luautilities.suffixes

local texgettoks   = tex and tex.gettoks

environment        = environment or { }
local environment  = environment

-- environment

local mt = {
    __index = function(_,k)
        if k == "version" then
            local version = texgettoks and texgettoks("contextversiontoks")
            if version and version ~= "" then
                rawset(environment,"version",version)
                return version
            else
                return "unknown"
            end
        elseif k == "kind" then
            local kind = texgettoks and texgettoks("contextkindtoks")
            if kind and kind ~= "" then
                rawset(environment,"kind",kind)
                return kind
            else
                return "unknown"
            end
        elseif k == "jobname" or k == "formatname" then
            local name = tex and tex[k]
            if name or name== "" then
                rawset(environment,k,name)
                return name
            else
                return "unknown"
            end
        elseif k == "outputfilename" then
            local name = environment.jobname
            rawset(environment,k,name)
            return name
        end
    end
}

setmetatable(environment,mt)

-- weird place ... depends on a not yet loaded module

function environment.texfile(filename)
    return resolvers.findfile(filename,'tex')
end

function environment.luafile(filename) -- needs checking

    if CONTEXTLMTXMODE and CONTEXTLMTXMODE > 0 and file.suffix(filename) == "lua" then
        -- no "tex", as that's pretty slow when not found (suffixes get appended, shouldn't happen)
     -- trackers.enable("resolvers.*")
        local resolved = resolvers.findfile(file.replacesuffix(filename,"lmt")) or ""
     -- trackers.disable("resolvers.*")
        if resolved ~= "" then
            return resolved
        end
    end

    local resolved = resolvers.findfile(filename,'tex') or ""
    if resolved ~= "" then
        return resolved
    end
    resolved = resolvers.findfile(filename,'texmfscripts') or ""
    if resolved ~= "" then
        return resolved
    end
    return resolvers.findfile(filename,'luatexlibs') or ""
end

-- local function checkstrip(filename)
--     local modu = modules[file.nameonly(filename)]
--     return modu and modu.dataonly
-- end

local stripindeed = false  directives.register("system.compile.strip", function(v) stripindeed = v end)

local function strippable(filename)
    if stripindeed then
        local modu = modules[file.nameonly(filename)]
        return modu and modu.dataonly
    else
        return false
    end
end

function environment.luafilechunk(filename,silent,macros) -- used for loading lua bytecode in the format
    filename = file.replacesuffix(filename, "lua")
    local fullname = environment.luafile(filename)
    if fullname and fullname ~= "" then
        local data = luautilities.loadedluacode(fullname,strippable,filename,macros)
        if not silent then
            report_lua("loading file %a %s",fullname,not data and "failed" or "succeeded")
        end
        return data
    else
        if not silent then
            report_lua("unknown file %a",filename)
        end
        return nil
    end
end

-- the next ones can use the previous ones / combine

function environment.loadluafile(filename, version)
    local lucname, luaname, chunk
    local basename = file.removesuffix(filename)
    if basename == filename then
        luaname = file.addsuffix(basename,luasuffixes.lua)
        lucname = file.addsuffix(basename,luasuffixes.luc)
    else
        luaname = filename -- forced suffix
        lucname = nil
    end
    -- when not overloaded by explicit suffix we look for a luc file first
    local fullname = (lucname and environment.luafile(lucname)) or ""
    if fullname ~= "" then
        if trace_locating then
            report_lua("loading %a",fullname)
        end
        -- maybe: package.loaded[file.nameonly(fullname)] = true
        chunk = loadfile(fullname) -- this way we don't need a file exists check
    end
    if chunk then
        chunk()
        if version then
            -- we check of the version number of this chunk matches
            local v = version -- can be nil
            if modules and modules[filename] then
                v = modules[filename].version -- new method
            elseif versions and versions[filename] then
                v = versions[filename]        -- old method
            end
            if v == version then
                return true
            else
                if trace_locating then
                    report_lua("version mismatch for %a, lua version %a, luc version %a",filename,v,version)
                end
                environment.loadluafile(filename)
            end
        else
            return true
        end
    end
    fullname = (luaname and environment.luafile(luaname)) or ""
    if fullname ~= "" then
        if trace_locating then
            report_lua("loading %a",fullname)
        end
        chunk = loadfile(fullname) -- this way we don't need a file exists check
        if not chunk then
            if trace_locating then
                report_lua("unknown file %a",filename)
            end
        else
            chunk()
            return true
        end
    end
    return false
end

environment.filenames = setmetatable( { }, {
    __index = function(t,k)
        local v = environment.files[k]
        if v then
            return (gsub(v,"%.+$",""))
        end
    end,
    __newindex = function(t,k)
        -- nothing
    end,
    __len = function(t)
        return #environment.files
    end,
} )
