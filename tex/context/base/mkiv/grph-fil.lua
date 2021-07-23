if not modules then modules = { } end modules ['grph-fil'] = {
    version   = 1.001,
    comment   = "companion to grph-fig.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type

local trace_run  = false  trackers.register("graphic.runfile",function(v) trace_run = v end)
local report_run = logs.reporter("graphics","run")

local isfile        = lfs.isfile
local replacesuffix = file.replacesuffix
local addsuffix     = file.addsuffix
local checksum      = file.checksum

-- Historically running files is part of graphics processing, so this is why it
-- sits here but is part of the job namespace.

local allocate = utilities.storage.allocate

local collected = allocate()
local tobesaved = allocate()

local jobfiles = {
    collected = collected,
    tobesaved = tobesaved,
    forcerun  = false, -- maybe a directive some day
}

job.files = jobfiles

local inputsuffix  = "tex"
local resultsuffix = "pdf"

local function initializer()
    tobesaved = jobfiles.tobesaved
    collected = jobfiles.collected
end

job.register('job.files.collected', tobesaved, initializer)

-- When there is a runpath specified, we're already there, so then we only need to
-- pass the orginal path. But we pass it because it will prevent prepending the
-- current direction to the given name.

local runner = sandbox.registerrunner {
    name     = "hashed context run",
    program  = "context",
    template = [[%options% --path=%path% %filename%]],
    template = [[%options% %?path: --path=%path% ?% %?runpath: --runpath=%runpath% ?% %filename%]],
    checkers = {
        options  = "string",
        filename = "readable",
        path     = "string",
        runpath  = "string",
    }
}

function jobfiles.run(name,action)
    local usedname    = addsuffix(name,inputsuffix) -- we assume tex if not set
    local oldchecksum = collected[usedname]
    local newchecksum = checksum(usedname)
    local resultfile  = replacesuffix(usedname,resultsuffix)
    local tobedone    = false
    if jobfiles.forcerun then
        tobedone = true
        if trace_run then
            report_run("processing file, changes in %a, %s",name,"processing forced")
        end
    end
    if not tobedone and not oldchecksum then
        tobedone = true
        if trace_run then
            report_run("processing file, changes in %a, %s",name,"no checksum yet")
        end
    end
    if not tobedone and oldchecksum ~= newchecksum then
        tobedone = true
        if trace_run then
            report_run("processing file, changes in %a, %s",name,"checksum mismatch")
        end
    end
    if not tobedone and not isfile(resultfile) then
        tobedone = true
        if trace_run then
            report_run("processing file, changes in %a, %s",name,"no result file")
        end
    end
    if tobedone then
        local ta = type(action)
        if ta == "function" then
            action(name)
        elseif ta == "string" and action ~= "" then
            -- can be anything but we assume it gets checked by the sandbox
            os.execute(action)
        elseif ta == "table" then
            local path    = action.path
            local runpath = action.runpath
            action.path    = environment.arguments.path
            action.runpath = environment.arguments.runpath
            runner(action)
            action.path    = path
            action.runpath = runpath
        else
            report_run("processing file, no action given for processing %a",name)
        end
    elseif trace_run then
        report_run("processing file, no changes in %a, not processed",name)
    end
    tobesaved[name] = newchecksum
end

--

local done = { }

function jobfiles.context(name,options)
    if type(name) == "table" then
        local result = { }
        for i=1,#name do
            result[#result+1] = jobfiles.context(name[i],options)
        end
        return result
    else
        local result = replacesuffix(name,resultsuffix)
        if not done[result] then
            jobfiles.run(name, { options = options, filename = name })
            done[result] = true
        end
        return result
    end
end

interfaces.implement {
    name      = "runcontextjob",
    arguments = "2 strings",
    actions   = { jobfiles.context, context }
}
