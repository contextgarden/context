if not modules then modules = { } end modules ['file-lib'] = {
    version   = 1.001,
    comment   = "companion to file-lib.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: check all usage of truefilename at the tex end and remove
-- files there (and replace definitions by full names)

local type = type
local format, gsub = string.format, string.gsub
local loadtable = table.load

local trace_libraries = false  trackers.register("resolvers.libraries", function(v) trace_libraries = v end)
----- trace_files     = false  trackers.register("resolvers.readfile",  function(v) trace_files     = v end)

local report_library  = logs.reporter("files","library")
----- report_files    = logs.reporter("files","readfile")

local removesuffix    = file.removesuffix
local collapsepath    = file.collapsepath

local getreadfilename = resolvers.getreadfilename

local libraries       = table.setmetatableindex("table")
local defaultpatterns = { "%s" }

local function defaultaction(name,foundname)
    report_files("asked name %a, found name %a",name,foundname)
end

local function defaultfailure(name)
    report_files("asked name %a, not found",name)
end

local ignoredfiles = { }
local distributed  = nil -- becomes false when not found
local reported     = false

function resolvers.ignorelibrary(name)
    ignoredfiles[name] = true
end

local function missinglibrary(expected)
    if not expected then
        return
    end
    if distributed == nil then
        distributed = loadtable(resolvers.findfile("context-libraries.tma") or "") or false
    end
    if distributed then
        local f = distributed.files
        if f then
            if type(expected) == "string" then
                expected = { expected }
            end
            for i=1,#expected do
                local e = expected[i]
                if f[e] then
                    report_library()
                    report_library("file %a should be in the installed distribution",e,category)
                    report_library()
                    f[e] = false -- so we report once
                    reported = true
                end
            end
        end
    end
end

resolvers.missinglibrary = missinglibrary

function resolvers.uselibrary(specification) -- todo: reporter
    local name = specification.name
    if name and name ~= "" and not ignoredfiles[name] then
        local patterns = specification.patterns or defaultpatterns
        local action   = specification.action   or defaultaction
        local failure  = specification.failure  or defaultfailure
        local onlyonce = specification.onlyonce
        local files    = utilities.parsers.settings_to_array(name)
        local truename = environment.truefilename
        local function found(filename)
            local somename  = truename and truename(filename) or filename
            local foundname = getreadfilename("any",".",somename) -- maybe some day also an option not to backtrack .. and ../.. (or block global)
            return foundname ~= "" and foundname
        end
        local loaded   = libraries[patterns]
        local expected = { }
        for i=1,#files do
            local filename = files[i]
            if not loaded[filename] then
                local foundname = nil
                local barename  = removesuffix(filename)
                -- direct search (we have an explicit suffix)
                if barename ~= filename then
                    foundname = found(filename)
                    if trace_libraries then
                        report_library("checking %a: %s",filename,foundname or "not found")
                    end
                end
                if not foundname then
                    -- pattern based search
                    for i=1,#patterns do
                        local pattern = patterns[i]
                        if pattern and pattern ~= "" then
                            local wanted = format(pattern,barename)
                            foundname = found(wanted)
                            if trace_libraries then
                                report_library("checking %a as %a: %s",filename,wanted,foundname or "not found")
                            end
                            if foundname then
                                break
                            end
                            expected[#expected+1] = wanted
                        else
                            -- can be a bogus path (coming from a test)
                        end
                    end
                end
                if type(foundname) == "string" then
                    if not loaded[foundname] then
                        if foundname then
                            foundname = collapsepath(foundname)
                            -- this way we can run a module (nil when making a format):
                            local inputname = environment.inputfilename
                            if not inputname or collapsepath(inputname) ~= foundname then
                                action(name,foundname)
                            end
                            -- afterwards:
                            if onlyonce then
                                loaded[foundname] = true -- todo: base this on return value
                            end
                        elseif failure then
                            failure(name)
                        end
                        if onlyonce then
                            loaded[filename] = true -- todo: base this on return value
                        end
                    end
                else
                    missinglibrary(expected)
                end
            end
        end
    end
end

statistics.register("missing files", function()
    if reported then
        local report = logs.reporter("system")
        logs.startfilelogging(report,"missing files")
        report()
        for k, v in table.sortedhash(distributed.files) do
            if not v then
                report("  %s",k)
            end
        end
        report()
        report("  These files should have been there but might have been dropped by the")
        report("  distribution that you use. There is not much we can do about that.")
        report()
        logs.stopfilelogging()
    end
end)

-- We keep these in the commands namespace even if it's not that logical
-- but this way we are compatible.

function commands.loadlibrary(name,foundname,nointerference)
    if not foundname then
        foundname = name
    end
    if foundname and foundname ~= "" then
        if nointerference then
            context.startnointerference()
        end
        context.startreadingfile()
        context.input(foundname)
        context.stopreadingfile()
        if nointerference then
            context.stopnointerference()
        end
    end
end

commands.uselibrary = resolvers.uselibrary
