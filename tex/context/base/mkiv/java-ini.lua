if not modules then modules = { } end modules ['java-ini'] = {
    version   = 1.001,
    comment   = "companion to java-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: don't flush scripts if no JS key

local format, gsub, find = string.format, string.gsub, string.find
local concat = table.concat
local lpegmatch, P, S, C, Carg, Cc = lpeg.match, lpeg.P, lpeg.S, lpeg.C, lpeg.Carg, lpeg.Cc

local allocate           = utilities.storage.allocate
local settings_to_array  = utilities.parsers.settings_to_array

local variables          = interfaces.variables
local formatters         = string.formatters

local context            = context
local implement          = interfaces.implement

local trace_javascript   = false  trackers.register("backends.javascript", function(v) trace_javascript = v end)

local report_javascripts = logs.reporter ("interactions","javascripts")
local status_javascripts = logs.messenger("interactions","javascripts")

local javascripts        = interactions.javascripts or { }
interactions.javascripts = javascripts

local codes              = allocate()
local preambles          = allocate()
local functions          = allocate()

javascripts.codes        = codes
javascripts.preambles    = preambles
javascripts.functions    = functions

local preambled = { }

local function storefunction(s,preamble)
    if trace_javascript then
        report_javascripts("found function %a",s)
    end
    functions[s] = preamble
end

local uses     = P("uses")
local used     = P("used")
local left     = P("{")
local right    = P("}")
local space    = S(" \r\n")
local spaces   = space^0
local braced   = left * C((1-right-space)^1) * right
local unbraced = C((1-space)^1)
local name     = spaces * (braced + unbraced) * spaces
local any      = P(1)
local script   = C(any^1)
local funct    = P("function")
local leftp    = P("(")
local rightp   = P(")")
local fname    = spaces * funct * spaces * (C((1-space-left-leftp)^1) * Carg(1) / storefunction) * spaces * leftp

local parsecode      = name * ((uses * name) + Cc("")) * spaces * script
local parsepreamble  = name * ((used * name) + Cc("")) * spaces * script
local parsefunctions = (fname + any)^0

function javascripts.storecode(str)
    local name, uses, script = lpegmatch(parsecode,str)
    if name and name ~= "" then
        script = gsub(script,"%s*([^\n\r]+)%s*[\n\r]+$","%1")
        codes[name] = { uses, script }
    end
end

function javascripts.storepreamble(str) -- now later
    local name, used, script = lpegmatch(parsepreamble,str)
    if name and name ~= "" and not preambled[name] then
        local n = #preambles + 1
        preambles[n] = { name, used, script }
        preambled[name] = n
        if trace_javascript then
            report_javascripts("stored preamble %a, state %a, order %a",name,used,n)
        end
        lpegmatch(parsefunctions,script,1,n)
    end
end

function javascripts.setpreamble(name,script) -- now later
    if name and name ~= "" and not preambled[name] then
        local n = #preambles + 1
        preambles[n] = { name, "now", script }
        preambled[name] = n
        if trace_javascript then
            report_javascripts("adapted preamble %a, state %a, order %a",name,"now",n)
        end
        lpegmatch(parsefunctions,script,1,n)
    end
end

function javascripts.addtopreamble(name,script)
    if name and name ~= "" then
        local p = preambled[name]
        if p then
            preambles[p] = { "now", preambles[p] .. " ;\n" .. script }
            if trace_javascript then
                report_javascripts("extended preamble %a, state %a, order %a",name,"now",p)
            end
        else
            local n = #preambles + 1
            preambles[n] = { name, "now", script }
            preambled[name] = n
            if trace_javascript then
                report_javascripts("stored preamble %a, state %a, order %a",name,"now",n)
            end
            lpegmatch(parsefunctions,script,1,n)
        end
    end
end

function javascripts.usepreamblenow(name) -- now later
    if name and name ~= "" and name ~= variables.reset then -- todo: reset
        local names = settings_to_array(name)
        for i=1,#names do
            local somename = names[i]
            local preamble = preambled[somename]
            if preamble  then
                preambles[preamble][2] = "now"
                if trace_javascript then
                    report_javascripts("used preamble %a, state %a, order %a",somename,"now","auto")
                end
            end
        end
    end
end

local splitter = lpeg.tsplitat(lpeg.patterns.commaspacer)

local used, reported = false, { } -- we can cache more

function javascripts.code(name,arguments)
    local c = codes[name]
    if c then
        local u, code = c[1], c[2]
        if u ~= "" then
            local p = preambled[u]
            if p then
                preambles[p][2] = "now"
                if trace_javascript and not reported[name] then
                    reported[name] = true
                    report_javascripts("used code %a, preamble %a",name,u)
                end
            elseif trace_javascript and not reported[name] then
                reported[name] = true
                report_javascripts("used code %a",name)
            end
        elseif trace_javascript and not reported[name] then
            reported[name] = true
            report_javascripts("used code %a",name)
        end
        used = true
        return code
    end
    local f = functions[name]
    if f then
        used = true
        if trace_javascript and not reported[name] then
            reported[name] = true
            report_javascripts("used function %a",name)
        end
        preambles[f][2] = "now" -- automatically tag preambles that define the function (as later)
        if arguments then
            local args = lpegmatch(splitter,arguments)
            for i=1,#args do -- can be a helper
                args[i] = formatters["%q"](args[i])
            end
            return formatters["%s(%s)"](name,concat(args,","))
        else
            return formatters["%s()"](name)
        end
    end
end

function javascripts.flushpreambles()
    local t = { }
--     if used then -- we want to be able to enforce inclusion
        for i=1,#preambles do
            local preamble = preambles[i]
            if preamble[2] == "now" then
                if trace_javascript then
                    report_javascripts("flushed preamble %a",preamble[1])
                end
                t[#t+1] = { preamble[1], preamble[3] }
            end
        end
--     end
    return t
end

local patterns = {
    CONTEXTLMTXMODE > 0 and "java-imp-%s.mkxl" or "",
    "java-imp-%s.mkiv",
    "java-imp-%s.tex",
    -- obsolete:
    "java-%s.mkiv",
    "java-%s.tex"
}

local function action(name,foundname)
    commands.loadlibrary(name,foundname,true)
    status_javascripts("loaded: library %a",name)
end

local function failure(name)
    report_javascripts("unknown library %a",name)
end

function javascripts.usescripts(name)
    if name ~= variables.reset then -- reset is obsolete
        resolvers.uselibrary {
            name     = name,
            patterns = patterns,
            action   = action,
            failure  = failure,
            onlyonce = true,
        }
    end
end

-- interface

implement {
    name      = "storejavascriptcode",
    actions   = javascripts.storecode,
    arguments = "string"
}

implement {
    name      = "storejavascriptpreamble",
    actions   = javascripts.storepreamble,
    arguments = "string"
}

implement {
    name      = "setjavascriptpreamble",
    actions   = javascripts.setpreamble,
    arguments = "2 strings",
}

implement {
    name      = "addtojavascriptpreamble",
    actions   = javascripts.addtopreamble,
    arguments = "2 strings",
}

implement {
    name      = "usejavascriptpreamble",
    actions   = javascripts.usepreamblenow,
    arguments = "string"
}

implement {
    name      = "usejavascriptscripts",
    actions   = javascripts.usescripts,
    arguments = "string"
}
