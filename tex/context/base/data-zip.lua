if not modules then modules = { } end modules ['data-zip'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- real old code ... partly redone .. needs testing due to changes as well as a decent overhaul

local format, find, match = string.format, string.find, string.match

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_zip = logs.reporter("resolvers","zip")

--[[ldx--
<p>We use a url syntax for accessing the zip file itself and file in it:</p>

<typing>
zip:///oeps.zip?name=bla/bla.tex
zip:///oeps.zip?tree=tex/texmf-local
zip:///texmf.zip?tree=/tex/texmf
zip:///texmf.zip?tree=/tex/texmf-local
zip:///texmf-mine.zip?tree=/tex/texmf-projects
</typing>
--ldx]]--

local resolvers = resolvers

zip                   = zip or { }
local zip             = zip

zip.archives          = zip.archives or { }
local archives        = zip.archives

zip.registeredfiles   = zip.registeredfiles or { }
local registeredfiles = zip.registeredfiles

local limited = false

directives.register("system.inputmode", function(v)
    if not limited then
        local i_limiter = io.i_limiter(v)
        if i_limiter then
            zip.open = i_limiter.protect(zip.open)
            limited = true
        end
    end
end)

local function validzip(str) -- todo: use url splitter
    if not find(str,"^zip://") then
        return "zip:///" .. str
    else
        return str
    end
end

function zip.openarchive(name)
    if not name or name == "" then
        return nil
    else
        local arch = archives[name]
        if not arch then
           local full = resolvers.findfile(name) or ""
           arch = full ~= "" and zip.open(full) or false
           archives[name] = arch
        end
       return arch
    end
end

function zip.closearchive(name)
    if not name or (name == "" and archives[name]) then
        zip.close(archives[name])
        archives[name] = nil
    end
end

function resolvers.locators.zip(specification)
    local archive = specification.filename
    local zipfile = archive and archive ~= "" and zip.openarchive(archive) -- tricky, could be in to be initialized tree
    if trace_locating then
        if zipfile then
            report_zip("locator: archive %a found",archive)
        else
            report_zip("locator: archive %a not found",archive)
        end
    end
end

function resolvers.hashers.zip(specification)
    local archive = specification.filename
    if trace_locating then
        report_zip("loading file %a",archive)
    end
    resolvers.usezipfile(specification.original)
end

function resolvers.concatinators.zip(zipfile,path,name) -- ok ?
    if not path or path == "" then
        return format('%s?name=%s',zipfile,name)
    else
        return format('%s?name=%s/%s',zipfile,path,name)
    end
end

function resolvers.finders.zip(specification)
    local original = specification.original
    local archive = specification.filename
    if archive then
        local query = url.query(specification.query)
        local queryname = query.name
        if queryname then
            local zfile = zip.openarchive(archive)
            if zfile then
                if trace_locating then
                    report_zip("finder: archive %a found",archive)
                end
                local dfile = zfile:open(queryname)
                if dfile then
                    dfile = zfile:close()
                    if trace_locating then
                        report_zip("finder: file %a found",queryname)
                    end
                    return specification.original
                elseif trace_locating then
                    report_zip("finder: file %a not found",queryname)
                end
            elseif trace_locating then
                report_zip("finder: unknown archive %a",archive)
            end
        end
    end
    if trace_locating then
        report_zip("finder: %a not found",original)
    end
    return resolvers.finders.notfound()
end

function resolvers.openers.zip(specification)
    local original = specification.original
    local archive = specification.filename
    if archive then
        local query = url.query(specification.query)
        local queryname = query.name
        if queryname then
            local zfile = zip.openarchive(archive)
            if zfile then
                if trace_locating then
                    report_zip("opener; archive %a opened",archive)
                end
                local dfile = zfile:open(queryname)
                if dfile then
                    if trace_locating then
                        report_zip("opener: file %a found",queryname)
                    end
                    return resolvers.openers.helpers.textopener('zip',original,dfile)
                elseif trace_locating then
                    report_zip("opener: file %a not found",queryname)
                end
            elseif trace_locating then
                report_zip("opener: unknown archive %a",archive)
            end
        end
    end
    if trace_locating then
        report_zip("opener: %a not found",original)
    end
    return resolvers.openers.notfound()
end

function resolvers.loaders.zip(specification)
    local original = specification.original
    local archive = specification.filename
    if archive then
        local query = url.query(specification.query)
        local queryname = query.name
        if queryname then
            local zfile = zip.openarchive(archive)
            if zfile then
                if trace_locating then
                    report_zip("loader: archive %a opened",archive)
                end
                local dfile = zfile:open(queryname)
                if dfile then
                    logs.show_load(original)
                    if trace_locating then
                        report_zip("loader; file %a loaded",original)
                    end
                    local s = dfile:read("*all")
                    dfile:close()
                    return true, s, #s
                elseif trace_locating then
                    report_zip("loader: file %a not found",queryname)
                end
            elseif trace_locating then
                report_zip("loader; unknown archive %a",archive)
            end
        end
    end
    if trace_locating then
        report_zip("loader: %a not found",original)
    end
    return resolvers.openers.notfound()
end

-- zip:///somefile.zip
-- zip:///somefile.zip?tree=texmf-local -> mount

function resolvers.usezipfile(archive)
    local specification = resolvers.splitmethod(archive) -- to be sure
    local archive = specification.filename
    if archive and not registeredfiles[archive] then
        local z = zip.openarchive(archive)
        if z then
            local instance = resolvers.instance
            local tree = url.query(specification.query).tree or ""
            if trace_locating then
                report_zip("registering: archive %a",archive)
            end
            statistics.starttiming(instance)
            resolvers.prependhash('zip',archive)
            resolvers.extendtexmfvariable(archive) -- resets hashes too
            registeredfiles[archive] = z
            instance.files[archive] = resolvers.registerzipfile(z,tree)
            statistics.stoptiming(instance)
        elseif trace_locating then
            report_zip("registering: unknown archive %a",archive)
        end
    elseif trace_locating then
        report_zip("registering: archive %a not found",archive)
    end
end

function resolvers.registerzipfile(z,tree)
    local names    = { }
    local files    = { } -- somewhat overkill .. todo
    local remap    = { } -- somewhat overkill .. todo
    local n        = 0
    local filter   = tree == "" and "^(.+)/(.-)$" or format("^%s/(.+)/(.-)$",tree)
    local register = resolvers.registerfile
    if trace_locating then
        report_zip("registering: using filter %a",filter)
    end
    for i in z:files() do
        local filename = i.filename
        local path, name = match(filename,filter)
        if not path then
            n = n + 1
            register(names,filename,"")
            local usedname  = lower(filename)
            files[usedname] = ""
            if usedname ~= filename then
                remap[usedname] = filename
            end
        elseif name and name ~= "" then
            n = n + 1
            register(names,name,path)
            local usedname  = lower(name)
            files[usedname] = path
            if usedname ~= name then
                remap[usedname] = name
            end
        else
            -- directory
        end
    end
    report_zip("registering: %s files registered",n)
    return {
     -- metadata = { },
        files    = files,
        remap    = remap,
    }
end
