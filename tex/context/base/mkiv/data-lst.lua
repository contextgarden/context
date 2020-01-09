if not modules then modules = { } end modules ['data-lst'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- used in mtxrun, can be loaded later .. todo

local type = type
local sortedhash = table.sortedhash
local isdir = lfs.isdir

local resolvers            = resolvers
local listers              = resolvers.listers or { }
resolvers.listers          = listers

local resolveprefix        = resolvers.resolve
local configurationfiles   = resolvers.configurationfiles
local expandedpathfromlist = resolvers.expandedpathfromlist
local splitpath            = resolvers.splitpath
local knownvariables       = resolvers.knownvariables

local report_lists         = logs.reporter("resolvers","lists")
local report_resolved      = logs.reporter("system","resolved")

local function tabstr(str)
    if not str then
        return "unset"
    elseif type(str) == 'table' then
        return concat(str," | ")
    else
        return str
    end
end

function listers.variables(pattern)
    local result = resolvers.knownvariables(pattern)
    for key, value in sortedhash(result) do
        report_lists(key)
        report_lists("  env: %s",tabstr(value.environment))
        report_lists("  var: %s",tabstr(value.variable))
        report_lists("  exp: %s",tabstr(value.expansion))
        report_lists("  res: %s",tabstr(value.resolved))
    end
end

function listers.configurations()
    local configurations = configurationfiles()
    for i=1,#configurations do
        report_resolved("file : %s",resolveprefix(configurations[i]))
    end
    report_resolved("")
    local list = expandedpathfromlist(splitpath(resolvers.luacnfspec))
    for i=1,#list do
        local li = resolveprefix(list[i])
        if isdir(li) then
            report_resolved("path - %s",li)
        else
            report_resolved("path + %s",li)
        end
    end
end
