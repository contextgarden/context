if not modules then modules = { } end modules ['cldf-scn'] = {
    version   = 1.001,
    comment   = "companion to cldf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not tokens.setters then return end

local load, type = load, type

local formatters = string.formatters
local char       = string.char
local concat     = table.concat

local f_action_f = formatters["action%s(%s)"]
local f_action_s = formatters["local action%s = action[%s]"]
local f_command  = formatters["local action = tokens._action\n%\nt\nreturn function(%s) return %s end"]

local interfaces = interfaces
local commands   = commands
local scanners   = interfaces.scanners

local compile    = tokens.compile or function() end

local report     = logs.reporter("interfaces","implementor")

function interfaces.implement(specification)
    local actions   = specification.actions
    local name      = specification.name
    local arguments = specification.arguments
    local scope     = specification.scope
    if not actions then
        if name then
            report("error: no actions for %a",name)
        else
            report("error: no actions and no name")
        end
        return
    end
    local scanner = compile(specification)
    if not name or name == "" then
        return scanner
    end
    local command = nil
    if type(actions) == "function" then
        command = actions
    elseif actions == context then
        command = context
    elseif #actions == 1 then
        command = actions[1]
    else
        tokens._action = actions
        local f = { }
        local a = { }
        local args = ""
        if arguments then
            for i=1,#arguments do
                local v = arguments[i]
                local t = type(v)
                if t == "boolean" then
                    a[i] = tostring(v)
                else
                    a[i] = char(96+i)
                end
            end
            args = concat(a,",")
        end
        command = args
        for i=1,#actions do
            command = f_action_f(i,command)
            f[#f+1] = f_action_s(i,i)
        end
        command = f_command(f,args,command)
        command = load(command)
        if command then
            command = command()
        end
        tokens._action = nil
    end
    if scanners[name] then
        report("warning: 'scanners.%s' is redefined",name)
    end
    scanners[name] = scanner
    if scope == "private" then
        return
    end
    if commands[name] and not specification.overload then
        report("warning: 'commands.%s' is redefined",name)
    end
    commands[name] = command
 -- return scanner, command
end

-- it's convenient to have copies here:

interfaces.setmacro = tokens.setters.macro
interfaces.setcount = tokens.setters.count
interfaces.setdimen = tokens.setters.dimen
