if not modules then modules = { } end modules ['typo-prc'] = {
    version   = 1.001,
    comment   = "companion to typo-prc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lpegmatch, patterns, P, C, Cs = lpeg.match, lpeg.patterns, lpeg.P, lpeg.C, lpeg.Cs

-- processors: syntax: processor->data ... not ok yet

local context           = context
local implement         = interfaces.implement

local formatters        = string.formatters

typesetters.processors  = typesetters.processors   or { }
local processors        = typesetters.processors

local trace_processors  = false
local report_processors = logs.reporter("processors")
local registered        = { }

local ctx_applyprocessor      = context.applyprocessor
local ctx_firstofoneargument  = context.firstofoneargument

trackers.register("typesetters.processors", function(v) trace_processors = v end)

function processors.register(p)
    registered[p] = true
end

function processors.reset(p)
    registered[p] = nil
end

--~ local splitter = lpeg.splitat("->",true) -- also support =>

local becomes    = P('->')
local processor  = (1-becomes)^1
local splitter   = C(processor) * becomes * Cs(patterns.argument + patterns.content)

function processors.split(str,nocheck)
    local p, s = lpegmatch(splitter,str)
    if p and (nocheck or registered[p]) then
        return p, s
    else
        return false, str
    end
end

function processors.apply(p,s)
    local str = p
    if s == nil then
        p, s = lpegmatch(splitter,p)
    end
    if p and registered[p] then
        if trace_processors then
            report_processors("applying %s processor %a, argument: %s","known",p,s)
        end
        ctx_applyprocessor(p,s)
    elseif s then
        if trace_processors then
            report_processors("applying %s processor %a, argument: %s","unknown",p,s)
        end
        context(s)
    elseif str then
        if trace_processors then
            report_processors("applying %s processor, data: %s","ignored",str)
        end
        context(str)
    end
end

function processors.startapply(p,s)
    local str = p
    if s == nil then
        p, s = lpegmatch(splitter,p)
    end
    if p and registered[p] then
        if trace_processors then
            report_processors("start applying %s processor %a","known",p)
        end
        ctx_applyprocessor(p)
        context("{")
        return s
    elseif p then
        if trace_processors then
            report_processors("start applying %s processor %a","unknown",p)
        end
        ctx_firstofoneargument()
        context("{")
        return s
    else
        if trace_processors then
            report_processors("start applying %s processor","ignored")
        end
        ctx_firstofoneargument()
        context("{")
        return str
    end
end

function processors.stopapply()
    context("}")
    if trace_processors then
        report_processors("stop applying processor")
    end
end

function processors.tostring(str)
    local p, s = lpegmatch(splitter,str)
    if registered[p] then
        return formatters["\\applyprocessor{%s}{%s}"](p,s)
    else
        return str
    end
end

function processors.stripped(str)
    local p, s = lpegmatch(splitter,str)
    return s or str
end

-- interface

implement { name = "registerstructureprocessor", actions = processors.register, arguments = "string" }
implement { name = "resetstructureprocessor",    actions = processors.reset,    arguments = "string" }
