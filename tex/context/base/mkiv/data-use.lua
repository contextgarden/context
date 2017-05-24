if not modules then modules = { } end modules ['data-use'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, lower, gsub, find = string.format, string.lower, string.gsub, string.find

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_mounts = logs.reporter("resolvers","mounts")

local resolvers = resolvers

-- we will make a better format, maybe something xml or just text or lua

resolvers.automounted = resolvers.automounted or { }

function resolvers.automount(usecache)
    local mountpaths = resolvers.cleanpathlist(resolvers.expansion('TEXMFMOUNT'))
    if (not mountpaths or #mountpaths == 0) and usecache then
        mountpaths = caches.getreadablepaths("mount")
    end
    if mountpaths and #mountpaths > 0 then
        resolvers.starttiming()
        for k=1,#mountpaths do
            local root = mountpaths[k]
            local f = io.open(root.."/url.tmi")
            if f then
                for line in f:lines() do
                    if line then
                        if find(line,"^[%%#%-]") then -- or %W
                            -- skip
                        elseif find(line,"^zip://") then
                            if trace_locating then
                                report_mounts("mounting %a",line)
                            end
                            table.insert(resolvers.automounted,line)
                            resolvers.usezipfile(line)
                        end
                    end
                end
                f:close()
            end
        end
        resolvers.stoptiming()
    end
end

-- status info

statistics.register("used config file", function() return caches.configfiles() end)
statistics.register("used cache path",  function() return caches.usedpaths() end)

-- experiment (code will move)

function statistics.savefmtstatus(texname,formatbanner,sourcefile,kind,banner) -- texname == formatname
    local enginebanner = status.banner
    if formatbanner and enginebanner and sourcefile then
        local luvname = file.replacesuffix(texname,"luv") -- utilities.lua.suffixes.luv
        local luvdata = {
            enginebanner = enginebanner,
            formatbanner = formatbanner,
            sourcehash   = md5.hex(io.loaddata(resolvers.findfile(sourcefile)) or "unknown"),
            sourcefile   = sourcefile,
        }
        io.savedata(luvname,table.serialize(luvdata,true))
        lua.registerfinalizer(function()
            logs.report("format banner","%s",banner)
            logs.newline()
        end)
    end
end

-- todo: check this at startup and return (say) 999 as signal that the run
-- was aborted due to a wrong format in which case mtx-context can trigger
-- a remake

function statistics.checkfmtstatus(texname)
    local enginebanner = status.banner
    if enginebanner and texname then
        local luvname = file.replacesuffix(texname,"luv") -- utilities.lua.suffixes.luv
        if lfs.isfile(luvname) then
            local luv = dofile(luvname)
            if luv and luv.sourcefile then
                local sourcehash = md5.hex(io.loaddata(resolvers.findfile(luv.sourcefile)) or "unknown")
                local luvbanner = luv.enginebanner or "?"
                if luvbanner ~= enginebanner then
                    return format("engine mismatch (luv: %s <> bin: %s)",luvbanner,enginebanner)
                end
                local luvhash = luv.sourcehash or "?"
                if luvhash ~= sourcehash then
                    return format("source mismatch (luv: %s <> bin: %s)",luvhash,sourcehash)
                end
            else
                return "invalid status file"
            end
        else
            return "missing status file"
        end
    end
    return true
end
