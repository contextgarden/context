if not modules then modules = { } end modules ['data-lst'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- used in mtxrun, can be loaded later .. todo

local type = type
local concat, sortedhash = table.concat,table.sortedhash

local resolvers       = resolvers
local listers         = resolvers.listers or { }
resolvers.listers     = listers

local resolveprefix   = resolvers.resolve

local report_lists    = logs.reporter("resolvers","lists")
local report_resolved = logs.reporter("system","resolved")

local function tabstr(str)
    if type(str) == 'table' then
        return concat(str," | ")
    else
        return str
    end
end

function listers.variables(pattern)
    local result = resolvers.knownvariables(pattern)
    for key, value in sortedhash(result) do
        report_lists(key)
        report_lists("  env: %s",tabstr(value.environment or "unset"))
        report_lists("  var: %s",tabstr(value.variable    or "unset"))
        report_lists("  exp: %s",tabstr(value.expansion   or "unset"))
        report_lists("  res: %s",tabstr(value.resolved    or "unset"))
    end
end

function listers.configurations()
    local configurations = resolvers.configurationfiles()
    for i=1,#configurations do
        report_resolved("file : %s",resolveprefix(configurations[i]))
    end
    report_resolved("")
    local list = resolvers.expandedpathfromlist(resolvers.splitpath(resolvers.luacnfspec))
    for i=1,#list do
        local li = resolveprefix(list[i])
        if lfs.isdir(li) then
            report_resolved("path - %s",li)
        else
            report_resolved("path + %s",li)
        end
    end
end
