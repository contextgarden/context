if not modules then modules = { } end modules ['cont-run'] = {
    version   = 1.001,
    comment   = "companion to cont-yes.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- When a style is loaded there is a good change that we never enter
-- this code.

local report = logs.reporter("system")

local type, tostring = type, tostring

local report        = logs.reporter("sandbox","call")
local fastserialize = table.fastserialize
local quoted        = string.quoted
local possiblepath  = sandbox.possiblepath

local context       = context
local implement     = interfaces.implement

local qualified     = { }
local writeable     = { }
local readable      = { }
local blocked       = { }
local trace_files   = false
local trace_calls   = false
local nofcalls      = 0
local nofrejected   = 0
local logfilename   = "sandbox.log"

local function registerstats()
    statistics.register("sandboxing", function()
        if trace_files then
            return string.format("%i calls, %i rejected, logdata in '%s'",nofcalls,nofrejected,logfilename)
        else
            return string.format("%i calls, %i rejected",nofcalls,nofrejected)
        end
    end)
    registerstats = false
end

local function logsandbox(details)
    local comment   = details.comment
    local result    = details.result
    local arguments = details.arguments
    for i=1,#arguments do
        local argument = arguments[i]
        local t = type(argument)
        if t == "string" then
            arguments[i] = quoted(argument)
            if trace_files and possiblepath(argument) then
                local q = qualified[argument]
                if q then
                    local c = q[comment]
                    if c then
                        local r = c[result]
                        if r then
                            c[result] = r + 1
                        else
                            c[result] = r
                        end
                    else
                        q[comment] = {
                            [result] = 1
                        }
                    end
                else
                    qualified[argument] = {
                        [comment] = {
                            [result] = 1
                        }
                    }
                end
            end
        elseif t == "table" then
            arguments[i] = fastserialize(argument)
        else
            arguments[i] = tostring(argument)
        end
    end
    if trace_calls then
        report("%s(%,t) => %l",details.comment,arguments,result)
    end
    nofcalls = nofcalls + 1
    if not result then
        nofrejected = nofrejected + 1
    end
end

local ioopen = sandbox.original(io.open) -- dummy call

local function logsandboxfiles(name,what,asked,okay)
    -- we're only interested in permitted access
    if not okay then
        blocked  [asked] = blocked  [asked] or 0 + 1
    elseif what == "*" or what == "w" then
        writeable[asked] = writeable[asked] or 0 + 1
    else
        readable [asked] = readable [asked] or 0 + 1
    end
end

function sandbox.logcalls()
    if not trace_calls then
        trace_calls = true
        sandbox.setlogger(logsandbox)
        if registerstats then
            registerstats()
        end
    end
end

function sandbox.logfiles()
    if not trace_files then
        trace_files = true
        sandbox.setlogger(logsandbox)
        sandbox.setfilenamelogger(logsandboxfiles)
        luatex.registerstopactions(function()
            table.save(logfilename,{
                calls = {
                    nofcalls    = nofcalls,
                    nofrejected = nofrejected,
                    filenames   = qualified,
                },
                checkednames = {
                    readable  = readable,
                    writeable = writeable,
                    blocked   = blocked,
                },
            })
        end)
        if registerstats then
            registerstats()
        end
    end
end

trackers.register("sandbox.tracecalls",sandbox.logcalls)
trackers.register("sandbox.tracefiles",sandbox.logfiles)

local sandboxing = environment.arguments.sandbox
local debugging  = environment.arguments.debug

if sandboxing then

    report("enabling sandbox")

    sandbox.enable()

    if type(sandboxing) == "string" then
        sandboxing = utilities.parsers.settings_to_hash(sandboxing)
        if sandboxing.calls then
            sandbox.logcalls()
        end
        if sandboxing.files then
            sandbox.logfiles()
        end
    end

    -- Nicer would be if we could just disable write 18 and keep os.execute
    -- which in fact we can do by defining write18 as macro instead of
    -- primitive ... todo ... well, it has been done now.

    -- We block some potential escapes from protection.

    context [[\let\primitive\relax\let\normalprimitive\relax]]

    debug = {
        traceback = traceback,
    }

    package.loaded.debug = debug

elseif debugging then

    -- we keep debug

else

    debug = {
        traceback = traceback,
        getinfo   = getinfo,
        sethook   = sethook,
    }

    package.loaded.debug = debug

end

local preparejob  preparejob = function() -- tricky: we need a hook for this

    local arguments = environment.arguments

    environment.lmtxmode = CONTEXTLMTXMODE

    if arguments.nosynctex then
        luatex.synctex.setup {
            state  = interfaces.variables.never,
        }
    elseif arguments.synctex then
        luatex.synctex.setup {
            state  = interfaces.variables.start,
            method = interfaces.variables.max,
        }
    end

 -- -- todo: move from mtx-context to here:
 --
 -- local timing = arguments.timing
 -- if type(timing) == "string" then
 --     context.usemodule { timing }
 -- end
 -- local nodates = arguments.nodates
 -- if nodates then
 --     context.enabledirectives { "backend.date=" .. (type(nodates) == "string" and nodates or "no") }
 -- end
 -- local trailerid = arguments.trailerid
 -- if type(trailerid) == "string" then
 --     context.enabledirectives { "backend.trailerid=" .. trailerid }
 -- end
 -- local profile = arguments.profile
 -- if profile then
 --     context.enabledirectives { "system.profile=" .. tonumber(profile) or 0 }
 -- end

 -- -- already done in mtxrun / mtx-context, has to happen very early
 --
 -- if arguments.silent then
 --     directives.enable("logs.blocked",arguments.silent)
 -- end
 --
 -- -- already done in mtxrun / mtx-context, can as well happen here
 --
 -- if arguments.errors then
 --     directives.enable("logs.errors",arguments.errors)
 -- end

    preparejob = function() end

    job.prepare = preparejob

end

job.prepare = preparejob

local function processjob()

    environment.initializefilenames() -- todo: check if we really need to pre-prep the filename

    local arguments = environment.arguments
    local suffix    = environment.suffix
    local filename  = environment.filename -- hm, not inputfilename !

    preparejob()

    if not filename or filename == "" then
        -- skip
    elseif suffix == "xml" or arguments.forcexml then

        -- Maybe we should move the preamble parsing here as it
        -- can be part of (any) loaded (sub) file. The \starttext
        -- wrapping might go away.

        report("processing as xml: %s",filename)

        context.starttext()
            context.xmlprocess("main",filename,"")
        context.stoptext()

    elseif suffix == "cld" or arguments.forcecld then

        report("processing as cld: %s",filename)

        context.runfile(filename)

    elseif suffix == "lua" or arguments.forcelua then

        -- The wrapping might go away. Why is is it there in the
        -- first place.

        report("processing as lua: %s",filename)

        context.starttext()
            context.ctxlua(string.format('dofile("%s")',filename))
        context.stoptext()

    elseif suffix == "mp" or arguments.forcemp then

        report("processing as metapost: %s",filename)

        context.starttext()
            context.processMPfigurefile(filename)
        context.stoptext()

    -- elseif suffix == "prep" then
    --
    --     -- Why do we wrap here. Because it can be xml? Let's get rid
    --     -- of prepping in general.
    --
    --     context.starttext()
    --     context.input(filename)
    --     context.stoptext()

    elseif suffix == "mps" or arguments.forcemps then

        report("processing metapost output: %s",filename)

        context.starttext()
            context.startTEXpage()
                context.externalfigure { filename }
            context.stopTEXpage()
        context.stoptext()

    else

     -- \writestatus{system}{processing as tex}
        -- We have a regular tex file so no \starttext yet as we can
        -- load fonts.
     -- context.enabletrackers { "resolvers.*" }
        context.input(filename)
     -- context.disabletrackers { "resolvers.*" }

    end

    context.finishjob()

end

implement {
    name     = "processjob",
    onlyonce = true,
    actions  = processjob,
}
