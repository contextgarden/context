if not modules then modules = { } end modules ['font-trt'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local rawget, dofile, next, type = rawget, dofile, next, type

local cleanfilename = fonts.names.cleanfilename
local splitbase     = file.splitbase
local lower         = string.lower

--[[ldx--
<p>We provide a simple treatment mechanism (mostly because I want to demonstrate
something in a manual). It's one of the few places where an lfg file gets loaded
outside the goodies manager.</p>
--ldx]]--

local treatments       = fonts.treatments or { }
fonts.treatments       = treatments

local treatmentdata    = treatments.data or utilities.storage.allocate()
treatments.data        = treatmentdata

treatments.filename    = "treatments.lfg"

local trace_treatments = false  trackers.register("fonts.treatments", function(v) trace_treatments = v end)
local report_treatment = logs.reporter("fonts","treatment")

treatments.report      = report_treatment

function treatments.trace(...)
    if trace_treatments then
        report_treatment(...)
    end
end

-- function treatments.load(name)
--     local filename = resolvers.findfile(name)
--     if filename and filename ~= "" then
--         local goodies = dofile(filename)
--         if goodies then
--             local treatments = goodies.treatments
--             if treatments then
--                 for name, data in next, treatments do
--                     treatmentdata[name] = data -- always wins
--                 end
--             end
--         end
--     end
-- end

table.setmetatableindex(treatmentdata,function(t,k)
    local files = resolvers.findfiles(treatments.filename)
    if files then
        for i=1,#files do
            local goodies = dofile(files[i])
            if goodies then
                local treatments = goodies.treatments
                if treatments then
                    for name, data in next, treatments do
                        if not rawget(t,name) then
                            t[name] = data
                        end
                    end
                end
            end
        end
    end
    table.setmetatableindex(treatmentdata,nil)
    return treatmentdata[k]
end)

local function applyfix(fix,filename,data,n)
    if type(fix) == "function" then
        -- we assume that when needed the fix reports something
     -- if trace_treatments then
     --     report_treatment("applying treatment %a to file %a",n,filename)
     -- end
        fix(data)
    elseif trace_treatments then
        report_treatment("invalid treatment %a for file %a",n,filename)
    end
end

function treatments.applyfixes(filename,data)
    local filename = cleanfilename(filename)
    local pathpart, basepart = splitbase(filename)
    local treatment = treatmentdata[filename] or treatmentdata[basepart]
    if treatment then
        local fixes = treatment.fixes
        if not fixes then
            -- nothing to fix
        elseif type(fixes) == "table" then
            for i=1,#fixes do
                applyfix(fixes[i],filename,data,i)
            end
        else
            applyfix(fixes,filename,data,1)
        end
    end
end

function treatments.ignoredfile(fullname)
    local treatmentdata = treatments.data or { } -- when used outside context
    local _, basepart = splitbase(fullname)
    local treatment = treatmentdata[basepart] or treatmentdata[lower(basepart)]
    if treatment and treatment.ignored then
        report_treatment("font file %a resolved as %a is ignored, reason %a",basepart,fullname,treatment.comment or "unknown")
        return true
    end
end

fonts.names.ignoredfile = treatments.ignoredfile
