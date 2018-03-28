if not modules then modules = { } end modules ['mult-aux'] = {
    version   = 1.001,
    comment   = "companion to mult-aux.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find = string.find
local next = next

interfaces.namespaces = interfaces.namespaces or { }
local namespaces      = interfaces.namespaces
local variables       = interfaces.variables

local context         = context

local trace_namespaces = false  trackers.register("interfaces.namespaces", function(v) trace_namespaces = v end)

local report_namespaces = logs.reporter("interface","namespaces")

local v_yes, v_list = variables.yes, variables.list

local prefix  = "????"
local meaning = "@@@@"

local data = { }

function namespaces.define(namespace,settings)
    if trace_namespaces then
        report_namespaces("installing namespace %a with settings %a",namespace,settings)
    end
    if data[namespace] then
        report_namespaces("namespace %a is already taken",namespace)
    end
    if #namespace < 2 then
        report_namespaces("namespace %a should have more than 1 character",namespace)
    end
    local ns = { }
    data[namespace] = ns
    utilities.parsers.settings_to_hash(settings,ns)
    local name = ns.name
    if not name or name == "" then
        report_namespaces("provide a (command) name in namespace %a",namespace)
    end
    local self = "\\" .. prefix .. namespace
    context.unprotect()
 -- context.installnamespace(namespace)
    context("\\def\\%s%s{%s%s}",prefix,namespace,meaning,namespace) -- or context.setvalue
    if trace_namespaces then
        report_namespaces("using namespace %a for %a",namespace,name)
    end
    local parent = ns.parent or ""
    if parent ~= "" then
        if trace_namespaces then
            report_namespaces("namespace %a for %a uses parent %a",namespace,name,parent)
        end
        if not find(parent,"\\",1,true) then
            parent = "\\" .. prefix .. parent
            -- todo: check if defined
        end
    end
    context.installparameterhandler(self,name)
    if trace_namespaces then
        report_namespaces("installing parameter handler for %a",name)
    end
    context.installparameterhashhandler(self,name)
    if trace_namespaces then
        report_namespaces("installing parameterhash handler for %a",name)
    end
    local style = ns.style
    if style == v_yes then
        context.installstyleandcolorhandler(self,name)
        if trace_namespaces then
            report_namespaces("installing attribute handler for %a",name)
        end
    end
    local command = ns.command
    if command == v_yes then
        context.installdefinehandler(self,name,parent)
        if trace_namespaces then
            report_namespaces("installing definition  command for %a (single)",name)
        end
    elseif command == v_list then
        context.installdefinehandler(self,name,parent)
        if trace_namespaces then
            report_namespaces("installing definition command for %a (multiple)",name)
        end
    end
    local setup = ns.setup
    if setup == v_yes then
        context.installsetuphandler(self,name)
        if trace_namespaces then
            report_namespaces("installing setup command for %a (%s)",name,"single")
        end
    elseif setup == v_list then
        context.installsetuphandler(self,name)
        if trace_namespaces then
            report_namespaces("installing setup command for %a (%s)",name,"multiple")
        end
    end
    local set = ns.set
    if set == v_yes then
        context.installparametersethandler(self,name)
        if trace_namespaces then
            report_namespaces("installing set/let/reset command for %a (%s)",name,"single")
        end
    elseif set == v_list then
        context.installparametersethandler(self,name)
        if trace_namespaces then
            report_namespaces("installing set/let/reset command for %a (%s)",name,"multiple")
        end
    end
    local frame = ns.frame
    if frame == v_yes then
        context.installinheritedframed(name)
        if trace_namespaces then
            report_namespaces("installing framed command for %a",name)
        end
    end
    context.protect()
end

function utilities.formatters.list(data,key,keys)
    if not keys then
        keys = { }
        for _, v in next, data do
            for k, _ in next, v do
                keys[k] = true
            end
        end
        keys = table.sortedkeys(keys)
    end
    context.starttabulate { "|"..string.rep("l|",#keys+1) }
    context.NC()
    context(key)
    for i=1,#keys do
        context.NC()
        context(keys[i])
    end context.NR()
    context.HL()
    for k, v in table.sortedhash(data) do
        context.NC()
        context(k)
        for i=1,#keys do
            context.NC()
            context(v[keys[i]])
        end context.NR()
    end
    context.stoptabulate()
end

function namespaces.list()
 -- utilities.formatters.list(data,"namespace")
    local keys = { "type", "name", "comment", "version", "parent", "definition", "setup", "style" }
    utilities.formatters.list(data,"namespace",keys)
end


interfaces.implement {
    name      = "definenamespace",
    arguments = "2 strings",
    actions   = namespaces.define
}

interfaces.implement {
    name      = "listnamespaces",
    actions   = namespaces.list
}
