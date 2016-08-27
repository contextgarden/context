if not modules then modules = { } end modules ['data-tmp'] = {
    version   = 1.100,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This module deals with caching data. It sets up the paths and
implements loaders and savers for tables. Best is to set the
following variable. When not set, the usual paths will be
checked. Personally I prefer the (users) temporary path.</p>

</code>
TEXMFCACHE=$TMP;$TEMP;$TMPDIR;$TEMPDIR;$HOME;$TEXMFVAR;$VARTEXMF;.
</code>

<p>Currently we do no locking when we write files. This is no real
problem because most caching involves fonts and the chance of them
being written at the same time is small. We also need to extend
luatools with a recache feature.</p>
--ldx]]--

local format, lower, gsub, concat = string.format, string.lower, string.gsub, table.concat
----- serialize, serializetofile = table.serialize, table.tofile -- overloaded so no local
local concat = table.concat
local mkdirs, isdir, isfile = dir.mkdirs, lfs.isdir, lfs.isfile
local addsuffix, is_writable, is_readable = file.addsuffix, file.is_writable, file.is_readable
local formatters = string.formatters

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)
local trace_cache    = false  trackers.register("resolvers.cache",    function(v) trace_cache    = v end)

local report_caches    = logs.reporter("resolvers","caches")
local report_resolvers = logs.reporter("resolvers","caching")

local resolvers = resolvers
local cleanpath = resolvers.cleanpath

-- intermezzo

local directive_cleanup = false  directives.register("system.compile.cleanup", function(v) directive_cleanup = v end)
local directive_strip   = false  directives.register("system.compile.strip",   function(v) directive_strip   = v end)

local compile = utilities.lua.compile

function utilities.lua.compile(luafile,lucfile,cleanup,strip)
    if cleanup == nil then cleanup = directive_cleanup end
    if strip   == nil then strip   = directive_strip   end
    return compile(luafile,lucfile,cleanup,strip)
end

-- end of intermezzo

caches       = caches or { }
local caches = caches

local luasuffixes = utilities.lua.suffixes

caches.base     = caches.base or "luatex-cache"
caches.more     = caches.more or "context"
caches.direct   = false -- true is faster but may need huge amounts of memory
caches.tree     = false
caches.force    = true
caches.ask      = false
caches.relocate = false
caches.defaults = { "TMPDIR", "TEMPDIR", "TMP", "TEMP", "HOME", "HOMEPATH" }

local writable, readables, usedreadables = nil, { }, { }

-- we could use a metatable for writable and readable but not yet

local function identify()
    -- Combining the loops makes it messy. First we check the format cache path
    -- and when the last component is not present we try to create it.
    local texmfcaches = resolvers.cleanpathlist("TEXMFCACHE") -- forward ref
    if texmfcaches then
        for k=1,#texmfcaches do
            local cachepath = texmfcaches[k]
            if cachepath ~= "" then
                cachepath = resolvers.resolve(cachepath)
                cachepath = resolvers.cleanpath(cachepath)
                cachepath = file.collapsepath(cachepath)
                local valid = isdir(cachepath)
                if valid then
                    if is_readable(cachepath) then
                        readables[#readables+1] = cachepath
                        if not writable and is_writable(cachepath) then
                            writable = cachepath
                        end
                    end
                elseif not writable and caches.force then
                    local cacheparent = file.dirname(cachepath)
                    if is_writable(cacheparent) and true then -- we go on anyway (needed for mojca's kind of paths)
                        if not caches.ask or io.ask(format("\nShould I create the cache path %s?",cachepath), "no", { "yes", "no" }) == "yes" then
                            mkdirs(cachepath)
                            if isdir(cachepath) and is_writable(cachepath) then
                                report_caches("path %a created",cachepath)
                                writable = cachepath
                                readables[#readables+1] = cachepath
                            end
                        end
                    end
                end
            end
        end
    end
    -- As a last resort we check some temporary paths but this time we don't
    -- create them.
    local texmfcaches = caches.defaults
    if texmfcaches then
        for k=1,#texmfcaches do
            local cachepath = texmfcaches[k]
            cachepath = resolvers.expansion(cachepath) -- was getenv
            if cachepath ~= "" then
                cachepath = resolvers.resolve(cachepath)
                cachepath = resolvers.cleanpath(cachepath)
                local valid = isdir(cachepath)
                if valid and is_readable(cachepath) then
                    if not writable and is_writable(cachepath) then
                        readables[#readables+1] = cachepath
                        writable = cachepath
                        break
                    end
                end
            end
        end
    end
    -- Some extra checking. If we have no writable or readable path then we simply
    -- quit.
    if not writable then
        report_caches("fatal error: there is no valid writable cache path defined")
        os.exit()
    elseif #readables == 0 then
        report_caches("fatal error: there is no valid readable cache path defined")
        os.exit()
    end
    -- why here
    writable = dir.expandname(resolvers.cleanpath(writable)) -- just in case
    -- moved here
    local base, more, tree = caches.base, caches.more, caches.tree or caches.treehash() -- we have only one writable tree
    if tree then
        caches.tree = tree
        writable = mkdirs(writable,base,more,tree)
        for i=1,#readables do
            readables[i] = file.join(readables[i],base,more,tree)
        end
    else
        writable = mkdirs(writable,base,more)
        for i=1,#readables do
            readables[i] = file.join(readables[i],base,more)
        end
    end
    -- end
    if trace_cache then
        for i=1,#readables do
            report_caches("using readable path %a (order %s)",readables[i],i)
        end
        report_caches("using writable path %a",writable)
    end
    identify = function()
        return writable, readables
    end
    return writable, readables
end

function caches.usedpaths(separator)
    local writable, readables = identify()
    if #readables > 1 then
        local result = { }
        local done = { }
        for i=1,#readables do
            local readable = readables[i]
            if readable == writable then
                done[readable] = true
                result[#result+1] = formatters["readable+writable: %a"](readable)
            elseif usedreadables[i] then
                done[readable] = true
                result[#result+1] = formatters["readable: %a"](readable)
            end
        end
        if not done[writable] then
            result[#result+1] = formatters["writable: %a"](writable)
        end
        return concat(result,separator or " | ")
    else
        return writable or "?"
    end
end

function caches.configfiles()
    return concat(resolvers.instance.specification,";")
end

function caches.hashed(tree)
    tree = gsub(tree,"[\\/]+$","")
    tree = lower(tree)
    local hash = md5.hex(tree)
    if trace_cache or trace_locating then
        report_caches("hashing tree %a, hash %a",tree,hash)
    end
    return hash
end

function caches.treehash()
    local tree = caches.configfiles()
    if not tree or tree == "" then
        return false
    else
        return caches.hashed(tree)
    end
end

local r_cache, w_cache = { }, { } -- normally w in in r but who cares

local function getreadablepaths(...)
    local tags = { ... }
    local hash = concat(tags,"/")
    local done = r_cache[hash]
    if not done then
        local writable, readables = identify() -- exit if not found
        if #tags > 0 then
            done = { }
            for i=1,#readables do
                done[i] = file.join(readables[i],...)
            end
        else
            done = readables
        end
        r_cache[hash] = done
    end
    return done
end

local function getwritablepath(...)
    local tags = { ... }
    local hash = concat(tags,"/")
    local done = w_cache[hash]
    if not done then
        local writable, readables = identify() -- exit if not found
        if #tags > 0 then
            done = mkdirs(writable,...)
        else
            done = writable
        end
        w_cache[hash] = done
    end
    return done
end

caches.getreadablepaths = getreadablepaths
caches.getwritablepath  = getwritablepath

-- this can be tricky as we can have a pre-generated format while at the same time
-- use e.g. a home path where we have updated file databases and so maybe we need
-- to check first if we do have a writable one

-- function caches.getfirstreadablefile(filename,...)
--     local rd = getreadablepaths(...)
--     for i=1,#rd do
--         local path = rd[i]
--         local fullname = file.join(path,filename)
--         if is_readable(fullname) then
--             usedreadables[i] = true
--             return fullname, path
--         end
--     end
--     return caches.setfirstwritablefile(filename,...)
-- end

-- next time we have an issue, we can test this instead:

function caches.getfirstreadablefile(filename,...)
    -- check if we have already written once
    local fullname, path = caches.setfirstwritablefile(filename,...)
    if is_readable(fullname) then
        return fullname, path -- , true
    end
    -- otherwise search for pregenerated
    local rd = getreadablepaths(...)
    for i=1,#rd do
        local path = rd[i]
        local fullname = file.join(path,filename)
        if is_readable(fullname) then
            usedreadables[i] = true
            return fullname, path -- , false
        end
    end
    -- else assume new written
    return fullname, path -- , true
end

function caches.setfirstwritablefile(filename,...)
    local wr = getwritablepath(...)
    local fullname = file.join(wr,filename)
    return fullname, wr
end

function caches.define(category,subcategory) -- not used
    return function()
        return getwritablepath(category,subcategory)
    end
end

function caches.setluanames(path,name)
    return format("%s/%s.%s",path,name,luasuffixes.tma), format("%s/%s.%s",path,name,luasuffixes.tmc)
end

-- This works best if the first writable is the first readable too. In practice
-- we can have these situations for file databases:
--
-- tma in readable
-- tma + tmb/c in readable
--
-- runtime files like fonts are written to the writable cache anyway

function caches.loaddata(readables,name,writable)
    if type(readables) == "string" then
        readables = { readables }
    end
    for i=1,#readables do
        local path   = readables[i]
        local loader = false
        local tmaname, tmcname = caches.setluanames(path,name)
        if isfile(tmcname) then
            loader = loadfile(tmcname)
        end
        if not loader and isfile(tmaname) then
            -- can be different paths when we read a file database from disk
            local tmacrap, tmcname = caches.setluanames(writable,name)
            if isfile(tmcname) then
                loader = loadfile(tmcname)
            end
            utilities.lua.compile(tmaname,tmcname)
            if isfile(tmcname) then
                loader = loadfile(tmcname)
            end
            if not loader then
                loader = loadfile(tmaname)
            end
        end
        if loader then
            loader = loader()
            collectgarbage("step")
            return loader
        end
    end
    return false
end

function caches.is_writable(filepath,filename)
    local tmaname, tmcname = caches.setluanames(filepath,filename)
    return is_writable(tmaname)
end

local saveoptions = { compact = true }

-- add some point we will only use the internal bytecode compiler and
-- then we can flag success in the tma so that it can trigger a compile
-- if the other engine

function caches.savedata(filepath,filename,data,raw)
    local tmaname, tmcname = caches.setluanames(filepath,filename)
    data.cache_uuid = os.uuid()
    if caches.direct then
        file.savedata(tmaname,table.serialize(data,true,saveoptions))
    else
        table.tofile(tmaname,data,true,saveoptions)
    end
    utilities.lua.compile(tmaname,tmcname)
end

-- moved from data-res:

local content_state = { }

function caches.contentstate()
    return content_state or { }
end

function caches.loadcontent(cachename,dataname,filename)
    if not filename then
        local name = caches.hashed(cachename)
        local full, path = caches.getfirstreadablefile(addsuffix(name,luasuffixes.lua),"trees")
        filename = file.join(path,name)
    end
    local blob = loadfile(addsuffix(filename,luasuffixes.luc)) or loadfile(addsuffix(filename,luasuffixes.lua))
    if blob then
        local data = blob()
        if data and data.content then
            if data.type == dataname then
                if data.version == resolvers.cacheversion then
                    content_state[#content_state+1] = data.uuid
                    if trace_locating then
                        report_resolvers("loading %a for %a from %a",dataname,cachename,filename)
                    end
                    return data.content
                else
                    report_resolvers("skipping %a for %a from %a (version mismatch)",dataname,cachename,filename)
                end
            else
                report_resolvers("skipping %a for %a from %a (datatype mismatch)",dataname,cachename,filename)
            end
        elseif trace_locating then
            report_resolvers("skipping %a for %a from %a (no content)",dataname,cachename,filename)
        end
    elseif trace_locating then
        report_resolvers("skipping %a for %a from %a (invalid file)",dataname,cachename,filename)
    end
end

function caches.collapsecontent(content)
    for k, v in next, content do
        if type(v) == "table" and #v == 1 then
            content[k] = v[1]
        end
    end
end

function caches.savecontent(cachename,dataname,content,filename)
    if not filename then
        local name = caches.hashed(cachename)
        local full, path = caches.setfirstwritablefile(addsuffix(name,luasuffixes.lua),"trees")
        filename = file.join(path,name) -- is full
    end
    local luaname = addsuffix(filename,luasuffixes.lua)
    local lucname = addsuffix(filename,luasuffixes.luc)
    if trace_locating then
        report_resolvers("preparing %a for %a",dataname,cachename)
    end
    local data = {
        type    = dataname,
        root    = cachename,
        version = resolvers.cacheversion,
        date    = os.date("%Y-%m-%d"),
        time    = os.date("%H:%M:%S"),
        content = content,
        uuid    = os.uuid(),
    }
    local ok = io.savedata(luaname,table.serialize(data,true))
    if ok then
        if trace_locating then
            report_resolvers("category %a, cachename %a saved in %a",dataname,cachename,luaname)
        end
        if utilities.lua.compile(luaname,lucname) then
            if trace_locating then
                report_resolvers("%a compiled to %a",dataname,lucname)
            end
            return true
        else
            if trace_locating then
                report_resolvers("compiling failed for %a, deleting file %a",dataname,lucname)
            end
            os.remove(lucname)
        end
    elseif trace_locating then
        report_resolvers("unable to save %a in %a (access error)",dataname,luaname)
    end
end
