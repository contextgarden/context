if not modules then modules = { } end modules ['file-lib'] = {
    version   = 1.001,
    comment   = "companion to file-lib.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: check all usage of truefilename at the tex end and remove
-- files there (and replace definitions by full names)

local format = string.format

local trace_files   = false  trackers.register("resolvers.readfile", function(v) trace_files = v end)
local report_files  = logs.reporter("files","readfile")

local loaded          = { }
local defaultpatterns = { "%s" }

local function defaultaction(name,foundname)
    report_files("asked name %a, found name %a",name,foundname)
end

local function defaultfailure(name)
    report_files("asked name %a, not found",name)
end

-- function commands.uselibrary(specification) -- todo; reporter
--     local name = specification.name
--     if name and name ~= "" then
--         local patterns = specification.patterns or defaultpatterns
--         local action   = specification.action   or defaultaction
--         local failure  = specification.failure  or defaultfailure
--         local onlyonce = specification.onlyonce
--         local files    = utilities.parsers.settings_to_array(name)
--         local truename = environment.truefilename
--         local done     = false
--         for i=1,#files do
--             local filename = files[i]
--             if not loaded[filename] then
--                 if onlyonce then
--                     loaded[filename] = true -- todo: base this on return value
--                 end
--                 for i=1,#patterns do
--                     local somename = format(patterns[i],filename)
--                     if truename then
--                         somename = truename(somename)
--                     end
--                     local foundname = resolvers.getreadfilename("any",".",somename) or ""
--                     if foundname ~= "" then
--                         action(name,foundname)
--                         done = true
--                         break
--                     end
--                 end
--                 if done then
--                     break
--                 end
--             end
--         end
--         if failure and not done then
--             failure(name)
--         end
--     end
-- end

function commands.uselibrary(specification) -- todo: reporter
    local name = specification.name
    if name and name ~= "" then
        local patterns = specification.patterns or defaultpatterns
        local action   = specification.action   or defaultaction
        local failure  = specification.failure  or defaultfailure
        local onlyonce = specification.onlyonce
        local files    = utilities.parsers.settings_to_array(name)
        local truename = environment.truefilename
        for i=1,#files do
            local filename = files[i]
            if loaded[filename] then
                -- next one
            else
                if onlyonce then
                    loaded[filename] = true -- todo: base this on return value
                end
                local done = false
                for i=1,#patterns do
                    local somename = format(patterns[i],filename)
                    if truename then
                        somename = truename(somename)
                    end
                    local foundname = resolvers.getreadfilename("any",".",somename) or ""
                    if foundname ~= "" then
                        action(name,foundname)
                        done = true
                        break
                    end
                end
                if failure and not done then
                    failure(name)
                end
            end
        end
    end
end
