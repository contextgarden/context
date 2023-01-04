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

local contextrunner = sandbox.registerrunner {
    name     = "hashed context run",
    program  = "context",
    template = [[%options% %?path: --path=%path% ?% %?runpath: --runpath=%runpath% ?% %filename%]],
    checkers = {
        options  = "string",
        filename = "readable",
        path     = "string",
        runpath  = "string",
    }
}

-- we can also use:
--
-- local jobvariables = job.variables
-- jobvariables.getchecksum(tag)
-- jobvariables.makechecksum(data)
-- jobvariables.setchecksum(tag,checksum)

-- The runpath features makes things more complex than needed, so we need to wrap
-- that some day in a helper. This is also very sensitive for both being set!

function jobfiles.run(action)
    local filename = action.filename
    if filename and filename ~= "" then
        local result      = action.result
        local runner      = action.runner or contextrunner
        local path        = action.path
if not isfile(filename) and path and path ~= "" then
    filename = file.join(path,filename)
end
        local oldchecksum = collected[filename]
        local newchecksum = checksum(filename)
-- print(filename,oldchecksum,newchecksum)
        local tobedone    = false
        local forcerun    = action.forcerun or jobfiles.forcerun
        if not result then
            result = replacesuffix(filename,resultsuffix)
            action.result = result
        end
        if forcerun then
            tobedone = true
            if trace_run then
                report_run("processing file, changes in %a, %s",filename,"processing forced")
            end
        end
        if not tobedone and not oldchecksum then
            tobedone = true
            if trace_run then
                report_run("processing file, changes in %a, %s",filename,"no checksum yet")
            end
        end
        if not tobedone and oldchecksum ~= newchecksum then
            tobedone = true
            if trace_run then
                report_run("processing file, changes in %a, %s",filename,"checksum mismatch")
            end
        end
        if not tobedone and not isfile(result) then
            tobedone = true
            if trace_run then
                report_run("processing file, changes in %a, %s",filename,"no result file")
            end
        end
        if tobedone then
            local kind = type(runner)
            if kind == "function" then
                if trace_run then
                    report_run("processing file, command: %s",action.name or "unknown")
                end
                -- We can have a sandbox.registerrunner here in which case we need to make
                -- sure that we don't feed a function into the checker. So one cannot use a
                -- variable named "runner" in the template but that's no big deal.
                local r = action.runner
                action.runner = nil
                runner(action)
                action.runner = r
            elseif kind == "string" then
                -- can be anything but we assume it gets checked by the sandbox
                if trace_run then
                    report_run("processing file, command: %s",runner)
                end
                os.execute(runner)
            else
                report_run("processing file, changes in %a, %s",filename,"no valid runner")
            end
        elseif trace_run then
            report_run("processing file, no changes in %a, %s",filename,"not processed")
        end
        tobesaved[filename] = newchecksum
    else
        -- silently ignore error
    end
end

--

local done = { }

local function analyzed(name,options)
    local usedname   = addsuffix(name,inputsuffix)      -- we assume tex if not set
    local resultname = replacesuffix(name,resultsuffix) -- we assume tex if not set
    local pathname   = file.pathpart(usedname)
    local path       = environment.arguments.path -- sic, no runpath
    local runpath    = environment.arguments.runpath
    local resultname = replacesuffix(name,resultsuffix) -- we assume tex if not set
    if runpath and runpath ~= "" then
        -- not really needed but probably more robust for local leftovers
        resultname = file.join(runpath,file.basename(resultname))
    end
    if path ~= "" then
        if path then
            path = file.join(path,pathname)
        else
            path = pathname
        end
        usedname = file.basename(usedname)
    end
    return {
        options  = options,
        path     = path,
        filename = usedname,
        result   = resultname,
        runpath  = runpath,
    }
end

function jobfiles.context(name,options) -- runpath ?
    if type(name) == "table" then
        local result = { }
        for i=1,#name do
            result[#result+1] = jobfiles.context(name[i],options)
        end
        return result
    elseif name ~= "" then
        local action = analyzed(name,options)
        local result = action.result
        if not done[result] then
            jobfiles.run(action)
            done[result] = true
        end
        return result
    else
        return { }
    end
end

interfaces.implement {
    name      = "runcontextjob",
    arguments = "2 strings",
    actions   = { jobfiles.context, context }
}
