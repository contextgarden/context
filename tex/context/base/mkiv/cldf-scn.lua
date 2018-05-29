if not modules then modules = { } end modules ['cldf-scn'] = {
    version   = 1.001,
    comment   = "companion to cldf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local load, type, tostring  = load, type, tostring

local formatters  = string.formatters
local char        = string.char
local concat      = table.concat

local lpegmatch   = lpeg.match
local p_unquoted  = lpeg.Cs(lpeg.patterns.unquoted)

local f_action_f  = formatters["action%s(%s)"]
local f_action_s  = formatters["local action%s = action[%s]"]
local f_command   = formatters["local action = tokens._action\n%\nt\nreturn function(%s) return %s end"]

local interfaces  = interfaces
local commands    = commands
local scanners    = interfaces.scanners
local register    = interfaces.registerscanner

local compile     = tokens.compile or function() end
local presets     = tokens.presets

local dummy       = function() end

local report      = logs.reporter("interfaces","implementor")

function interfaces.implement(specification)
    local actions   = specification.actions
    local name      = specification.name
    local arguments = specification.arguments
    local private   = specification.scope == "private"
    local onlyonce  = specification.onlyonce
    if not actions then
        if name then
            report("error: no actions for %a",name)
        else
            report("error: no actions and no name")
        end
        return
    end
    if name == "" then
        name = nil
    end
    local p = arguments and presets[arguments]
    if p then
        arguments = p
    end
    local scanner
    local resetter = onlyonce and name and commands.ctxresetter(name)
    if resetter then
        local scan = compile(specification)
        if private then
            scanner = function()
                resetter()
                return scan()
            end
        else
            scanner = function()
                commands[name] = dummy
                resetter()
                return scan()
            end
        end
    else
        scanner = compile(specification)
    end
    if not name then
        return scanner
    end
    if scanners[name] and not specification.overload then
        report("warning: 'scanners.%s' is redefined",name)
    end
 -- scanners[name] = scanner -- we now use:
    register(name,scanner,specification.protected,specification.public,specification.call)
    if private then
        return
    end
    local command
    if onlyonce then
        if type(actions) == "function" then
            actions = { actions }
        elseif #actions == 1 then
            actions = { actions[1] }
        end
    end
    if type(actions) == "function" then
        command = actions
    elseif #actions == 1 then
        command = actions[1]
    else
        -- this one is not yet complete .. compare tokens
        tokens._action = actions
        local f = { }
        local args
        if not arguments then
            args = ""
        elseif type(arguments) == "table" then
            local a = { }
            for i=1,#arguments do
                local v = arguments[i]
                local t = type(v)
                if t == "boolean" then
                    a[i] = tostring(v)
                elseif t == "number" then
                    a[i] = tostring(v)
                elseif t == "string" then
                    local s = lpegmatch(p_unquoted,v)
                    if s and v ~= s then
                        a[i] = v -- a string, given as "'foo'" or '"foo"'
                    else
                        a[i] = char(96+i)
                    end
                else
                    -- nothing special for tables
                    a[i] = char(96+i)
                end
            end
            args = concat(a,",")
        else
            args = "a"
        end
        command = args
        for i=1,#actions do
            command = f_action_f(i,command)
            f[i] = f_action_s(i,i)
        end
        command = f_command(f,args,command)
        command = load(command)
        if command then
            if resetter then
                local cmd = command()
                command = function()
                    commands[name] = dummy
                    resetter()
                    cmd()
                end
            else
                command = command()
            end
        end
        tokens._action = nil
    end
    if commands[name] and not specification.overload then
        report("warning: 'commands.%s' is redefined",name)
    end
    commands[name] = command
 -- return scanner, command
end

-- it's convenient to have copies here:

interfaces.defined  = tokens.defined

interfaces.setmacro = tokens.setters.macro
interfaces.setcount = tokens.setters.count
interfaces.setdimen = tokens.setters.dimen

interfaces.strings = table.setmetatableindex(function(t,k)
    local v = { }
    for i=1,k do
        v[i] = "string"
    end
    t[k] = v
    return v
end)
