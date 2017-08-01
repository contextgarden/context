if not modules then modules = { } end modules ['core-ctx'] = {
    version   = 1.001,
    comment   = "companion to core-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[
Job control files aka ctx files are rather old and date from the mkii times.
They were handled in texexec and mtx-context and deals with modes, modules,
environments and preprocessing in projects where one such file drives the
processing of lots of files without the need to provide command line
arguments.

In mkiv this concept was of course supported as well. The first implementation
of mtx-context took much of the approach of texexec, but by now we have gotten
rid of the option file (for passing modes, modules and environments), the stubs
(for directly processing cld and xml) as well as the preprocessing component
of the ctx files. Special helper features, like typesetting listings, were
already moved to the extras (a direct side effect of the ability to pass along
command line arguments.) All this made mtx-context more simple than its ancestor
texexec.

Because some of the modes might affect the mtx-context end, the ctx file is
still loaded there but only for getting the modes. The file is loaded again
during the run but as loading and basic processing takes less than a
millisecond it's not that much of a burden.
--]]

-- the ctxrunner tabel might either become private or move to the job namespace
-- which also affects the loading order

local trace_prepfiles = false  trackers.register("system.prepfiles", function(v) trace_prepfiles = v end)

local tostring = tostring
local gsub, find, match, validstring = string.gsub, string.find, string.match, string.valid
local concat = table.concat
local xmltext = xml.text

local report_jobfile   = logs.reporter("system","jobfile")
local report_prepfiles = logs.reporter("system","prepfiles")

local commands         = commands
local implement        = interfaces.implement

ctxrunner              = ctxrunner or { }

ctxrunner.prepfiles    = utilities.storage.allocate()

local function dontpreparefile(t,k)
    return k -- we only store when we have a prepper
end

table.setmetatableindex(ctxrunner.prepfiles,dontpreparefile)

local function filtered(str,method) -- in resolvers?
    str = tostring(str)
    if     method == 'name'     then str = file.nameonly(str)
    elseif method == 'path'     then str = file.dirname(str)
    elseif method == 'suffix'   then str = file.suffix(str)
    elseif method == 'nosuffix' then str = file.removesuffix(str)
    elseif method == 'nopath'   then str = file.basename(str)
    elseif method == 'base'     then str = file.basename(str)
--  elseif method == 'full'     then
--  elseif method == 'complete' then
--  elseif method == 'expand'   then -- str = file.expandpath(str)
    end
    return (gsub(str,"\\","/"))
end

-- local function substitute(e,str)
--     local attributes = e.at
--     if str and attributes then
--         if attributes['method'] then
--             str = filtered(str,attributes['method'])
--         end
--         if str == "" and attributes['default'] then
--             str = attributes['default']
--         end
--     end
--     return str
-- end

local function substitute(str)
    return str
end

local function justtext(str)
    str = xml.unescaped(tostring(str))
    str = xml.cleansed(str)
    str = gsub(str,"\\+",'/')
    str = gsub(str,"%s+",' ')
    return str
end

function ctxrunner.load(ctxname)

    report_jobfile("processing %a",ctxname)

    local xmldata = xml.load(ctxname)

    local jobname = tex.jobname -- todo

    local variables   = { job = jobname }
    local commands    = { }
    local flags       = { }
    local paths       = { } -- todo
    local treatments  = { }
    local suffix      = "prep"

    xml.include(xmldata,'ctx:include','name', {'.', file.dirname(ctxname), "..", "../.." })

    for e in xml.collected(xmldata,"/ctx:job/ctx:flags/ctx:flag") do
        local flag = xmltext(e)
        local key, value = match(flag,"^(.-)=(.+)$")
        if key and value then
            environment.setargument(key,value)
        else
            environment.setargument(flag,true)
        end
    end

    -- add to document.options.ctxfile[...]

    local ctxfile  = document.options.ctxfile

    local modes        = ctxfile.modes
    local modules      = ctxfile.modules
    local environments = ctxfile.environments

    for e in xml.collected(xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:mode") do
        modes[#modes+1] = xmltext(e)
    end

    for e in xml.collected(xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:module") do
        modules[#modules+1] = xmltext(e)
    end

    for e in xml.collected(xmldata,"/ctx:job/ctx:process/ctx:resources/ctx:environment") do
        environments[#environments+1] = xmltext(e)
    end

    for e in xml.collected(xmldata,"ctx:message") do
        report_jobfile("ctx comment: %s", xmltext(e))
    end

    for r, d, k in xml.elements(xmldata,"ctx:value[@name='job']") do
        d[k] = variables['job'] or ""
    end

    for e in xml.collected(xmldata,"/ctx:job/ctx:preprocess/ctx:processors/ctx:processor") do
        local name   = e.at and e.at['name'] or "unknown"
        local suffix = e.at and e.at['suffix'] or "prep"
        for r, d, k in xml.elements(command,"ctx:old") do
            d[k] = "%old%"
        end
        for r, d, k in xml.elements(e,"ctx:new") do
            d[k] = "%new%"
        end
        for r, d, k in xml.elements(e,"ctx:value") do
            local tag = d[k].at['name']
            if tag then
                d[k] = "%" .. tag .. "%"
            end
        end
        local runner = xml.textonly(e)
        if runner and runner ~= "" then
            commands[name] = {
                suffix = suffix,
                runner = runner,
            }
        end
    end

    local suffix   = xml.filter(xmldata,"xml:///ctx:job/ctx:preprocess/attribute('suffix')") or suffix
    local runlocal = xml.filter(xmldata,"xml:///ctx:job/ctx:preprocess/ctx:processors/attribute('local')")

    runlocal = toboolean(runlocal)

    -- todo: only collect, then plug into file handler

    local inputfile = validstring(environment.arguments.input) or jobname

    variables.old = inputfile

    for files in xml.collected(xmldata,"/ctx:job/ctx:preprocess/ctx:files") do
        for pattern in xml.collected(files,"ctx:file") do
            local preprocessor = pattern.at['processor'] or ""
            for r, d, k in xml.elements(pattern,"/ctx:old") do
                d[k] = jobname
            end
            for r, d, k in xml.elements(pattern,"/ctx:value[@name='old'") do
                d[k] = jobname
            end
            pattern =justtext(xml.tostring(pattern))
            if preprocessor and preprocessor ~= "" and pattern and pattern ~= "" then
                local noftreatments = #treatments + 1
                local findpattern   = string.topattern(pattern)
                local preprocessors = utilities.parsers.settings_to_array(preprocessor)
                treatments[noftreatments] = {
                    pattern       = findpattern,
                    preprocessors = preprocessors,
                }
                report_jobfile("step %s, pattern %a, preprocessor: %a",noftreatments,findpattern,preprocessors)
             end
        end
    end

    if #treatments == 0 then
        report_jobfile("no treatments needed")
    end

    local function needstreatment(oldfile)
        for i=1,#treatments do
            local treatment = treatments[i]
            local pattern = treatment.pattern
            if find(oldfile,pattern) then
                return treatment
            end
        end
    end

    local preparefile = #treatments > 0 and function(prepfiles,filename)

        filename = file.collapsepath(filename)

        local treatment = needstreatment(filename)
        local oldfile = filename
        local newfile = false
        if treatment then
            local preprocessors = treatment.preprocessors
            local runners = { }
            for i=1,#preprocessors do
                local preprocessor = preprocessors[i]
                local command = commands[preprocessor]
                if command then
                    local runner = command.runner
                    local suffix = command.suffix
                    local result = filename .. "." .. suffix
                    if runlocal then
                        result = file.basename(result)
                    end
                    variables.old = oldfile
                    variables.new = result
                    runner = utilities.templates.replace(runner,variables)
                    if runner and runner ~= "" then
                        runners[#runners+1] = runner
                        oldfile = result
                        if runlocal then
                            oldfile = file.basename(oldfile)
                        end
                        newfile = oldfile
                    end
                end
            end
            oldname = file.collapsepath(oldname)
            newname = file.collapsepath(newname)
            if not newfile then
                newfile = filename
                report_prepfiles("%a is not converted to %a",filename,newfile)
            elseif not lfs.isfile(newfile) or file.needsupdating(filename,newfile) then
                for i=1,#runners do
                    report_prepfiles("step %i: %s",i,runners[i])
                end
                --
                for i=1,#runners do
                    local command = runners[i]
                    report_prepfiles("command: %s",command)
                    --
                    -- remark: we don't use sandbox.registerrunner here as we cannot predict what
                    -- gets done here, so just:
                    --
                    local result = os.execute(command) or 0
                    --
                 -- if result > 0 then
                 --     report_prepfiles("error, return code: %s",result)
                 -- end
                    logs.newline()
                    logs.newline()
                end
                if lfs.isfile(newfile) then
                    file.syncmtimes(filename,newfile)
                    report_prepfiles("%a is converted to %a",filename,newfile)
                else
                    report_prepfiles("%a is not converted to %a",filename,newfile)
                    newfile = filename
                end
            elseif lfs.isfile(newfile) then
                report_prepfiles("%a is already converted to %a",filename,newfile)
            else
                report_prepfiles("unknown error when converting %a to %a",filename,newfile)
            end
        else
            newfile = filename
        end
        prepfiles[filename] = newfile
        -- in case we ask twice (with the prepped name) ... todo: avoid this mess
        prepfiles[newfile]  = newfile
        return newfile
    end

    table.setmetatableindex(ctxrunner.prepfiles,preparefile or dontpreparefile)

    -- we need to deal with the input filename as it has already be resolved

end

--     print("\n")
--     document = {
--         options =  {
--             ctxfile = {
--                 modes        = { },
--                 modules      = { },
--                 environments = { },
--             }
--         }
--     }
--     environment.arguments.input = "test.tex"
--     ctxrunner.load("x-ldx.ctx")

local function resolve(name) -- used a few times later on
    return ctxrunner.prepfiles[file.collapsepath(name)] or false
end

function ctxrunner.preparedfile(name)
    return resolve(name) or name
end

local processfile       = commands.processfile
local doifelseinputfile = commands.doifelseinputfile

implement {
    name      = "processfile",
    overload  = true,
    arguments = { "string", "integer" },
    actions   = function(name,maxreadlevel) -- overloaded
        local prepname = resolve(name)
        if prepname then
            return processfile(prepname,0)
        end
        return processfile(name,maxreadlevel)
    end
}

implement {
    name      = "doifelseinputfile",
    overload  = true,
    arguments = { "string", "integer" },
    actions   = function(name,depth)
        local prepname = resolve(name)
        if prepname then
            return doifelseinputfile(prepname,0)
        end
        return doifelseinputfile(name,depth)
    end
}

-- implement {
--     name      = "preparedfile", -- not used
--     arguments = "string",
--     actions   = { ctxrunner.preparedfile, context }
-- }

implement {
    name      = "setdocumentctxfile",
    onlyonce  = true,
    actions   = function()
        local ctxfile = document.arguments.ctx or ""
        if ctxfile ~= "" then
            ctxrunner.load(ctxfile) -- do we need to locate it?
        end
    end
}

function ctxrunner.resolve(name) -- used a few times later on
    local collapsedname = file.collapsepath(name,".")
    return ctxrunner.prepfiles[collapsedname] or collapsedname
end

-- ctxrunner.load("t:/sources/core-ctx.ctx")

-- context(ctxrunner.prepfiles["one-a.xml"]) context.par()
-- context(ctxrunner.prepfiles["one-b.xml"]) context.par()
-- context(ctxrunner.prepfiles["two-c.xml"]) context.par()
-- context(ctxrunner.prepfiles["two-d.xml"]) context.par()
-- context(ctxrunner.prepfiles["all-x.xml"]) context.par()

-- inspect(ctxrunner.prepfiles)
