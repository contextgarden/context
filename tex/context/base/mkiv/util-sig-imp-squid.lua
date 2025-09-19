if not modules then modules = { } end modules ['util-sig-imp-squid'] = {
    version   = 1.002,
    comment   = "companion to util-sig.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type

local serialwrite = serial and serial.write or os.serialwrite

if not serialwrite then
    return
end

-- Interfaces:

local trace    = environment.arguments.verbose
local signals  = utilities.signals

local report   = signals.report or logs.reporter("signal")
local state    = signals.loadstate()

local server   = state and state.servers and state.servers[state.usage.server or "default"]
local client   = state and state.clients and state.clients[state.usage.client or "default"]

local protocol = server and server.protocol or "serial"

if protocol == "serial" then

    -- use signals.serialwrite

    local port = false
    local baud = 115200

    if server then
        port = server.port or port
        baud = server.baud or baud
    end

    if not port then
        report("unknown serial post")
        return
    end

    local prefix  = signals.serialprefix
    local forward = signals.serialprefix .. "wf"

    if not (client and client.protocol == "forward") then
        forward = false
    end

    local function squidsome(cmd,fwd)
        serialwrite(port,baud,prefix .. cmd .. "\r")
        if forward and fwd then
            serialwrite(port,baud,forward)
        end
    end

    local function squidreset  () squidsome("qr",true) end
    local function squidbusy   () squidsome("qs") end
    local function squidstep   () squidsome("qs") end
    local function squiddone   () squidsome("qf") end
    local function squidproblem() squidsome("qp") end
    local function squiderror  () squidsome("qe") end

    local function squidstep()
        signals.serialfast(port,baud,prefix .. "qs")
    end

    local function squiddone(currentrun,details)
        signals.serialfast(port,baud,prefix .. "qf")
        if details and statistics and statistics.feedback then
            statistics.feedback.processstates(function(s)
                local index    = s.index
                local category = s.category
                local command  = false
                if category == "performance" then
                    command = "fb"
                elseif category == "problem" then
                    command = "fp"
                elseif category == "interference" then
                    command = "fe"
                end
                if command then
                    command = prefix .. command .. index
                    -- "\n"
--                     command = command .. " "
--                     command = command .. "\n"
-- print(command)
                    signals.serialfast(port,baud,command)
                end
            end)
        end
        signals.serialclose(port)
    end

    signals.squidinit     = squidreset
    signals.squidreset    = squidreset
    signals.squidbusy     = squidbusy
    signals.squidstep     = squidstep
    signals.squiddone     = squiddone
    signals.squidfinished = squiddone
    signals.squidproblem  = squidproblem
    signals.squiderror    = squiderror

    return {
        name    = "squid",
        report  = report,
        trigger = function(state,currentrun)
            -- We can let context handle it if we plug into the closer. We can also
            -- intercept redundant error/problem/done handling if needed.
         -- if state == "busy" then
         --     squidbusy()
         -- else
            if state == "reset" or state == "init" then
                squidreset()
            elseif state == "problem" then
                squidproblem()
            elseif state == "error" then
                squiderror()
         -- elseif state == "done" then
         --     squiddone()
         -- elseif state == "finished" then
         --     squidfinished() -- already set
            end
        end,
        stepper = function(action,process,step,issue)
            local cmd = "r"
            if action == "busy" then
                cmd = issue and "e" or "s"
            elseif action == "finished" then
                cmd = "f"
            elseif action == "problem" then
                cmd = "p"
            elseif action == "error" then
                cmd = "e"
            end
            if process then
                cmd = "s" .. cmd .. process
            else
                cmd = "q" .. cmd
            end
            squidsome(cmd)
        end,
        signal = function(action,currentrun)
            local cmd = "ar"
            if action == "busy" or action == "step" then
                cmd = "ab"
            elseif action == "done" then
                cmd = "ad"
            elseif action == "finished" then
                cmd = "af"
            elseif action == "problem" then
                cmd = "ap"
            elseif action == "error" then
                cmd = "ae"
            end
            squidsome(cmd)
        end,
    }

end

