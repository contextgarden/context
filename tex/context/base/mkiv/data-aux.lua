if not modules then modules = { } end modules ['data-aux'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find = string.find
local type, next = type, next

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local resolvers = resolvers

local report_scripts = logs.reporter("resolvers","scripts")

function resolvers.updatescript(oldname,newname) -- oldname -> own.name, not per se a suffix
 -- local scriptpath = "scripts/context/lua"
    local scriptpath = "context/lua"
    newname = file.addsuffix(newname,"lua")
    local oldscript = resolvers.cleanpath(oldname)
    if trace_locating then
        report_scripts("to be replaced old script %a", oldscript)
    end
    local newscripts = resolvers.findfiles(newname) or { }
    if #newscripts == 0 then
        if trace_locating then
            report_scripts("unable to locate new script")
        end
    else
        for i=1,#newscripts do
            local newscript = resolvers.cleanpath(newscripts[i])
            if trace_locating then
                report_scripts("checking new script %a", newscript)
            end
            if oldscript == newscript then
                if trace_locating then
                    report_scripts("old and new script are the same")
                end
            elseif not find(newscript,scriptpath,1,true) then
                if trace_locating then
                    report_scripts("new script should come from %a",scriptpath)
                end
            elseif not (find(oldscript,file.removesuffix(newname).."$") or find(oldscript,newname.."$")) then
                if trace_locating then
                    report_scripts("invalid new script name")
                end
            else
                local newdata = io.loaddata(newscript)
                if newdata then
                    if trace_locating then
                        report_scripts("old script content replaced by new content: %s",oldscript)
                    end
                    io.savedata(oldscript,newdata)
                    break
                elseif trace_locating then
                    report_scripts("unable to load new script")
                end
            end
        end
    end
end
