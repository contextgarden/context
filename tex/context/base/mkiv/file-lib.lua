if not modules then modules = { } end modules ['file-lib'] = {
    version   = 1.001,
    comment   = "companion to file-lib.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: check all usage of truefilename at the tex end and remove
-- files there (and replace definitions by full names)

local format, gsub = string.format, string.gsub

local trace_libraries = false  trackers.register("resolvers.libraries", function(v) trace_libraries = v end)
----- trace_files     = false  trackers.register("resolvers.readfile",  function(v) trace_files     = v end)

local report_library  = logs.reporter("files","library")
----- report_files    = logs.reporter("files","readfile")

local removesuffix    = file.removesuffix

local getreadfilename = resolvers.getreadfilename

local loaded          = { }
local defaultpatterns = { "%s" }

local function defaultaction(name,foundname)
    report_files("asked name %a, found name %a",name,foundname)
end

local function defaultfailure(name)
    report_files("asked name %a, not found",name)
end

function resolvers.uselibrary(specification) -- todo: reporter
    local name = specification.name
    if name and name ~= "" then
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
        for i=1,#files do
            local filename = files[i]
            if loaded[filename] then
                -- next one
            else
                if onlyonce then
                    loaded[filename] = true -- todo: base this on return value
                end
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
                        local wanted = format(patterns[i],barename)
                        foundname = found(wanted)
                        if trace_libraries then
                            report_library("checking %a as %a: %s",filename,wanted,foundname or "not found")
                        end
                        if foundname then
                            break
                        end
                    end
                end
                if foundname then
                    action(name,foundname)
                elseif failure then
                    failure(name)
                end
            end
        end
    end
end

commands.uselibrary = resolvers.uselibrary -- for the moment
