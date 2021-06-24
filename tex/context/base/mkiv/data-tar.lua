if not modules then modules = { } end modules ['data-tar'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, find, match = string.format, string.find, string.match

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_tar = logs.reporter("resolvers","tar")

--[[ldx--
<p>We use a url syntax for accessing the tar file itself and file in it:</p>

<typing>
tar:///oeps.tar?name=bla/bla.tex
tar:///oeps.tar?tree=tex/texmf-local
</typing>
--ldx]]--

local resolvers    = resolvers
local findfile     = resolvers.findfile
local registerfile = resolvers.registerfile
local splitmethod  = resolvers.splitmethod
local starttiming  = resolvers.starttiming
local stoptiming   = resolvers.stoptiming

local urlquery     = url.query

--- hm, zip sits in the global namespace, but tar doesn't

local tar          = utilities.tar or { }
utilities.tar      = tar -- not needed

local archives     = tar.archives or { }
tar.archives       = archives

local registeredfiles = tar.registeredfiles or { }
tar.registeredfiles   = registeredfiles

-- foo.tar.xz : done
-- foo.tar.gz : todo
-- foo.tar    : done

local hashtar, fetchtar, wipetar  do

    local suffix = file.suffix -- hassuffix .. no need to split

    local tarfiles       = utilities.tar.file
    local tarstrings     = utilities.tar.string

    local hashtarfile    = tar.files.hash
    local fetchtarfile   = tar.files.fetch

    local hashtarstring  = tar.strings.hash
    local fetchtarstring = tar.strings.fetch

    local register       = resolvers.decompressors.register

    hashtar = function(archive,strip)
        local a = register(archive)
        if a then
            return hashtarstring(a,archive)
        else
            return hashtarfile(archive,archive)
        end
    end

    fetchtar = function(archive,filename,list)
        local a = register(archive)
        if a then
            return fetchtarstring(a,filename,list)
        else
            return fetchtarfile(archive,filename,list)
        end
    end

    wipetar = resolvers.decompressors.unregister

end

local function validfile(archive,name)
    return archive[name]
end

local function openarchive(name)
    if not name or name == "" then
        return nil
    else
        local arch = archives[name]
        if not arch then
           local full = findfile(name) or ""
           arch = full ~= "" and hashtar(full,name) or false
           archives[name] = arch
        end
        return arch
    end
end

local function closearchive(name)
    if not name or (name == "" and archives[name]) then
        archives[name] = nil
        wipetar(name)
    end
end

tar.openarchive  = openarchive
tar.closearchive = closearchive

function resolvers.locators.tar(specification)
    local archive = specification.filename
    local tarfile = archive and archive ~= "" and openarchive(archive)
    if trace_locating then
        if tarfile then
            report_tar("locator: archive %a found",archive)
        else
            report_tar("locator: archive %a not found",archive)
        end
    end
end

function resolvers.concatinators.tar(tarfile,path,name) -- ok ?
    if not path or path == "" then
        return format('%s?name=%s',tarfile,name)
    else
        return format('%s?name=%s/%s',tarfile,path,name)
    end
end

local finders  = resolvers.finders
local notfound = finders.notfound

function finders.tar(specification)
    local original = specification.original
    local archive  = specification.filename
    if archive then
        local query     = urlquery(specification.query)
        local queryname = query.name
        if queryname then
            local tfile = openarchive(archive)
            if tfile then
                if trace_locating then
                    report_tar("finder: archive %a found",archive)
                end
                if validfile(tfile,queryname) then
                    if trace_locating then
                        report_tar("finder: file %a found",queryname)
                    end
                    return specification.original
                elseif trace_locating then
                    report_tar("finder: file %a not found",queryname)
                end
            elseif trace_locating then
                report_tar("finder: unknown archive %a",archive)
            end
        end
    end
    if trace_locating then
        report_tar("finder: %a not found",original)
    end
    return notfound()
end

local openers    = resolvers.openers
local notfound   = openers.notfound
local textopener = openers.helpers.textopener

function openers.tar(specification)
    local original = specification.original
    local archive  = specification.filename
    if archive then
        local query     = urlquery(specification.query)
        local queryname = query.name
        if queryname then
            local tfile = openarchive(archive)
            if tfile then
                if trace_locating then
                    report_tar("opener; archive %a opened",archive)
                end
                local data = fetchtar(archive,queryname,tfile)
                if data then
                    if trace_locating then
                        report_tar("opener: file %a found",queryname)
                    end
                    return textopener('tar',original,data) -- a string handle
                elseif trace_locating then
                    report_tar("opener: file %a not found",queryname)
                end
            elseif trace_locating then
                report_tar("opener: unknown archive %a",archive)
            end
        end
    end
    if trace_locating then
        report_tar("opener: %a not found",original)
    end
    return notfound()
end

loaders  = resolvers.loaders
local notfound = loaders.notfound

function loaders.tar(specification)
    local original = specification.original
    local archive  = specification.filename
    if archive then
        local query     = urlquery(specification.query)
        local queryname = query.name
        if queryname then
            local tfile = openarchive(archive)
            if tfile then
                if trace_locating then
                    report_tar("loader: archive %a opened",archive)
                end
                local data = fetchtar(archive,queryname,tfile)
                if data then
                    if trace_locating then
                        report_tar("loader; file %a loaded",original)
                    end
                    return true, data, #data
                elseif trace_locating then
                    report_tar("loader: file %a not found",queryname)
                end
            elseif trace_locating then
                report_tar("loader; unknown archive %a",archive)
            end
        end
    end
    if trace_locating then
        report_tar("loader: %a not found",original)
    end
    return notfound()
end
