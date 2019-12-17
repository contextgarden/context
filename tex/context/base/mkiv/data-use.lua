if not modules then modules = { } end modules ['data-use'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_mounts = logs.reporter("resolvers","mounts")

local resolvers = resolvers
local findfile  = resolvers.findfile

-- -- This should mount a zip file so that we can run from zip files but I never went
-- -- on with it. It's really old code, from right when we started with luatex and
-- -- mkiv. Nowadays I'd use a lua specification file instead of a line based url.tmi,
-- -- file so just to be modern I patched it but it's untested. This is a normally a
-- -- startup-only feature.
--
-- do
--
--     local mounted = { }
--
--     function resolvers.automount(usecache)
--         local mountpaths = resolvers.cleanpathlist(resolvers.expansion('TEXMFMOUNT'))
--         if (not mountpaths or #mountpaths == 0) and usecache then
--             mountpaths = caches.getreadablepaths("mount")
--         end
--         if mountpaths and #mountpaths > 0 then
--             resolvers.starttiming()
--             for k=1,#mountpaths do
--                 local root = mountpaths[k]
--                 local list = table.load("automount.lua")
--                 if list then
--                     local archives = list.archives
--                     if archives then
--                         for i=1,#archives do
--                             local archive = archives[i]
--                             local already = false
--                             for i=1,#mounted do
--                                 if archive == mounted[i] then
--                                     already = true
--                                     break
--                                 end
--                             end
--                             if not already then
--                                 mounted[#mounted+1] = archive
--                                 resolvers.usezipfile(archive)
--                             end
--                         end
--                     end
--                 end
--             end
--             resolvers.stoptiming()
--         end
--     end
--
-- end

-- status info

statistics.register("used config file", function() return caches.configfiles() end)
statistics.register("used cache path",  function() return caches.usedpaths() end)

-- experiment (code will move)

function statistics.savefmtstatus(texname,formatbanner,sourcefile,kind,banner) -- texname == formatname
    local enginebanner = status.banner
    if formatbanner and enginebanner and sourcefile then
        local luvname = file.replacesuffix(texname,"luv") -- utilities.lua.suffixes.luv
        local luvdata = {
            enginebanner  = enginebanner,
            formatbanner  = formatbanner,
            sourcehash    = md5.hex(io.loaddata(findfile(sourcefile)) or "unknown"),
            sourcefile    = sourcefile,
            luaversion    = LUAVERSION,
            formatid      = LUATEXFORMATID,
            functionality = LUATEXFUNCTIONALITY,
        }
        io.savedata(luvname,table.serialize(luvdata,true))
        lua.registerfinalizer(function()
            if jit then
                logs.report("format banner","%s  lua: %s jit",banner,LUAVERSION)
            else
                logs.report("format banner","%s  lua: %s",banner,LUAVERSION)
            end
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
                local sourcehash = md5.hex(io.loaddata(findfile(luv.sourcefile)) or "unknown")
                local luvbanner = luv.enginebanner or "?"
                if luvbanner ~= enginebanner then
                    return format("engine mismatch (luv: %s <> bin: %s)",luvbanner,enginebanner)
                end
                local luvhash = luv.sourcehash or "?"
                if luvhash ~= sourcehash then
                    return format("source mismatch (luv: %s <> bin: %s)",luvhash,sourcehash)
                end
                local luvluaversion = luv.luaversion or 0
                local engluaversion = LUAVERSION or 0
                if luvluaversion ~= engluaversion then
                    return format("lua mismatch (luv: %s <> bin: %s)",luvluaversion,engluaversion)
                end
                local luvfunctionality = luv.functionality or 0
                local engfunctionality = status.development_id or 0
                if luvfunctionality ~= engfunctionality then
                    return format("functionality mismatch (luv: %s <> bin: %s)",luvfunctionality,engfunctionality)
                end
                local luvformatid = luv.formatid or 0
                local engformatid = status.format_id or 0
                if luvformatid ~= engformatid then
                    return format("formatid mismatch (luv: %s <> bin: %s)",luvformatid,engformatid)
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
