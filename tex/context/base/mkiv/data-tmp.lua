if not modules then modules = { } end modules ['data-tmp'] = {
    version   = 1.100,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This module deals with caching data. It sets up the paths and implements
loaders and savers for tables. Best is to set the following variable. When not
set, the usual paths will be checked. Personally I prefer the (users) temporary
path.</p>

</code>
TEXMFCACHE=$TMP;$TEMP;$TMPDIR;$TEMPDIR;$HOME;$TEXMFVAR;$VARTEXMF;.
</code>

<p>Currently we do no locking when we write files. This is no real problem
because most caching involves fonts and the chance of them being written at the
same time is small. We also need to extend luatools with a recache feature.</p>
--ldx]]--

local next, type = next, type
local pcall, loadfile, collectgarbage = pcall, loadfile, collectgarbage
local format, lower, gsub = string.format, string.lower, string.gsub
local concat, serialize, fastserialize, serializetofile = table.concat, table.serialize, table.fastserialize, table.tofile
local mkdirs, expanddirname, isdir, isfile = dir.mkdirs, dir.expandname, lfs.isdir, lfs.isfile
local is_writable, is_readable = file.is_writable, file.is_readable
local collapsepath, joinfile, addsuffix, dirname = file.collapsepath, file.join, file.addsuffix, file.dirname
local savedata = file.savedata
local formatters = string.formatters
local osexit, osdate, osuuid = os.exit, os.date, os.uuid
local removefile = os.remove
local md5hex = md5.hex

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)
local trace_cache    = false  trackers.register("resolvers.cache",    function(v) trace_cache    = v end)

local report_caches    = logs.reporter("resolvers","caches")
local report_resolvers = logs.reporter("resolvers","caching")

local resolvers    = resolvers
local cleanpath    = resolvers.cleanpath
local resolvepath  = resolvers.resolve

local luautilities = utilities.lua

-- intermezzo

do

    local directive_cleanup = false  directives.register("system.compile.cleanup", function(v) directive_cleanup = v end)
    local directive_strip   = false  directives.register("system.compile.strip",   function(v) directive_strip   = v end)

    local compilelua = luautilities.compile

    function luautilities.compile(luafile,lucfile,cleanup,strip)
        if cleanup == nil then cleanup = directive_cleanup end
        if strip   == nil then strip   = directive_strip   end
        return compilelua(luafile,lucfile,cleanup,strip)
    end

end

-- end of intermezzo

caches              = caches or { }
local caches        = caches
local writable      = nil
local readables     = { }
local usedreadables = { }

local compilelua    = luautilities.compile
local luasuffixes   = luautilities.suffixes

caches.base         = caches.base or "luatex-cache"  -- can be local
caches.more         = caches.more or "context"       -- can be local
caches.defaults     = { "TMPDIR", "TEMPDIR", "TMP", "TEMP", "HOME", "HOMEPATH" }

local direct_cache  = false -- true is faster but may need huge amounts of memory
local fast_cache    = false
local cache_tree    = false

directives.register("system.caches.direct",function(v) direct_cache = true end)
directives.register("system.caches.fast",  function(v) fast_cache   = true end)

-- we could use a metatable for writable and readable but not yet

local function configfiles()
    return concat(resolvers.configurationfiles(),";")
end

local function hashed(tree)
    tree = gsub(tree,"[\\/]+$","")
    tree = lower(tree)
    local hash = md5hex(tree)
    if trace_cache or trace_locating then
        report_caches("hashing tree %a, hash %a",tree,hash)
    end
    return hash
end

local function treehash()
    local tree = configfiles()
    if not tree or tree == "" then
        return false
    else
        return hashed(tree)
    end
end

caches.hashed      = hashed
caches.treehash    = treehash
caches.configfiles = configfiles

local function identify()
    -- Combining the loops makes it messy. First we check the format cache path
    -- and when the last component is not present we try to create it.
    local texmfcaches = resolvers.cleanpathlist("TEXMFCACHE") -- forward ref
    if texmfcaches then
        for k=1,#texmfcaches do
            local cachepath = texmfcaches[k]
            if cachepath ~= "" then
                cachepath = resolvepath(cachepath)
                cachepath = cleanpath(cachepath)
                cachepath = collapsepath(cachepath)
                local valid = isdir(cachepath)
                if valid then
                    if is_readable(cachepath) then
                        readables[#readables+1] = cachepath
                        if not writable and is_writable(cachepath) then
                            writable = cachepath
                        end
                    end
                elseif not writable then
                    local cacheparent = dirname(cachepath)
                    if is_writable(cacheparent) then -- we go on anyway (needed for mojca's kind of paths)
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
    -- As a last resort we check some temporary paths but this time we don't
    -- create them.
    local texmfcaches = caches.defaults
    if texmfcaches then
        for k=1,#texmfcaches do
            local cachepath = texmfcaches[k]
            cachepath = resolvers.expansion(cachepath) -- was getenv
            if cachepath ~= "" then
                cachepath = resolvepath(cachepath)
                cachepath = cleanpath(cachepath)
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
        osexit()
    elseif #readables == 0 then
        report_caches("fatal error: there is no valid readable cache path defined")
        osexit()
    end
    -- why here
    writable = expanddirname(cleanpath(writable)) -- just in case
    -- moved here ( we have only one writable tree)
    local base = caches.base
    local more = caches.more
    local tree = cache_tree or treehash() -- we have only one writable tree
    if tree then
        cache_tree = tree
        writable = mkdirs(writable,base,more,tree)
        for i=1,#readables do
            readables[i] = joinfile(readables[i],base,more,tree)
        end
    else
        writable = mkdirs(writable,base,more)
        for i=1,#readables do
            readables[i] = joinfile(readables[i],base,more)
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

local r_cache = { }
local w_cache = { }

local function getreadablepaths(...)
    local tags = { ... }
    local hash = concat(tags,"/")
    local done = r_cache[hash]
    if not done then
        local writable, readables = identify() -- exit if not found
        if #tags > 0 then
            done = { }
            for i=1,#readables do
                done[i] = joinfile(readables[i],...)
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

local function setfirstwritablefile(filename,...)
    local wr = getwritablepath(...)
    local fullname = joinfile(wr,filename)
    return fullname, wr
end

local function setluanames(path,name)
    return
        format("%s/%s.%s",path,name,luasuffixes.tma),
        format("%s/%s.%s",path,name,luasuffixes.tmc)
end

local function getfirstreadablefile(filename,...)
    -- check if we have already written once
    local fullname, path = setfirstwritablefile(filename,...)
    if is_readable(fullname) then
        return fullname, path -- , true
    end
    -- otherwise search for pregenerated
    local rd = getreadablepaths(...)
    for i=1,#rd do
        local path = rd[i]
        local fullname = joinfile(path,filename)
        if is_readable(fullname) then
            usedreadables[i] = true
            return fullname, path -- , false
        end
    end
    -- else assume new written
    return fullname, path -- , true
end

caches.getreadablepaths     = getreadablepaths
caches.getwritablepath      = getwritablepath
caches.setfirstwritablefile = setfirstwritablefile
caches.getfirstreadablefile = getfirstreadablefile
caches.setluanames          = setluanames

-- -- not used:
--
-- function caches.define(category,subcategory)
--     return function()
--         return getwritablepath(category,subcategory)
--     end
-- end

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
        local state  = false
        local tmaname, tmcname = setluanames(path,name)
        if isfile(tmcname) then
            state, loader = pcall(loadfile,tmcname)
        end
        if not loader and isfile(tmaname) then
            -- can be different paths when we read a file database from disk
            local tmacrap, tmcname = setluanames(writable,name)
            if isfile(tmcname) then
                state, loader = pcall(loadfile,tmcname)
            end
            compilelua(tmaname,tmcname)
            if isfile(tmcname) then
                state, loader = pcall(loadfile,tmcname)
            end
            if not loader then
                state, loader = pcall(loadfile,tmaname)
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
    local tmaname, tmcname = setluanames(filepath,filename)
    return is_writable(tmaname)
end

local saveoptions = { compact = true }

function caches.savedata(filepath,filename,data,fast)
    local tmaname, tmcname = setluanames(filepath,filename)
    data.cache_uuid = osuuid()
    if fast or fast_cache then
        savedata(tmaname,fastserialize(data,true))
    elseif direct_cache then
        savedata(tmaname,serialize(data,true,saveoptions))
    else
        serializetofile(tmaname,data,true,saveoptions)
    end
    compilelua(tmaname,tmcname)
end

-- moved from data-res:

local content_state = { }

function caches.contentstate()
    return content_state or { }
end

function caches.loadcontent(cachename,dataname,filename)
    if not filename then
        local name = hashed(cachename)
        local full, path = getfirstreadablefile(addsuffix(name,luasuffixes.lua),"trees")
        filename = joinfile(path,name)
    end
    local state, blob = pcall(loadfile,addsuffix(filename,luasuffixes.luc))
    if not blob then
        state, blob = pcall(loadfile,addsuffix(filename,luasuffixes.lua))
    end
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
        local name = hashed(cachename)
        local full, path = setfirstwritablefile(addsuffix(name,luasuffixes.lua),"trees")
        filename = joinfile(path,name) -- is full
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
        date    = osdate("%Y-%m-%d"),
        time    = osdate("%H:%M:%S"),
        content = content,
        uuid    = osuuid(),
    }
    local ok = savedata(luaname,serialize(data,true))
    if ok then
        if trace_locating then
            report_resolvers("category %a, cachename %a saved in %a",dataname,cachename,luaname)
        end
        if compilelua(luaname,lucname) then
            if trace_locating then
                report_resolvers("%a compiled to %a",dataname,lucname)
            end
            return true
        else
            if trace_locating then
                report_resolvers("compiling failed for %a, deleting file %a",dataname,lucname)
            end
            removefile(lucname)
        end
    elseif trace_locating then
        report_resolvers("unable to save %a in %a (access error)",dataname,luaname)
    end
end
