if not modules then modules = { } end modules ['data-lst'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- used in mtxrun, can be loaded later .. todo

local rawget, type, next = rawget, type, next

local find, concat, upper = string.find, table.concat, string.upper
local fastcopy, sortedpairs = table.fastcopy, table.sortedpairs

local resolvers     = resolvers
local listers       = resolvers.listers or { }
resolvers.listers   = listers

local resolveprefix = resolvers.resolve

local report_lists = logs.reporter("resolvers","lists")

local function tabstr(str)
    if type(str) == 'table' then
        return concat(str," | ")
    else
        return str
    end
end

function listers.variables(pattern)
    local instance    = resolvers.instance
    local environment = instance.environment
    local variables   = instance.variables
    local expansions  = instance.expansions
    local pattern     = upper(pattern or "")
    local configured  = { }
    local order       = instance.order
    for i=1,#order do
        for k, v in next, order[i] do
            if v ~= nil and configured[k] == nil then
                configured[k] = v
            end
        end
    end
    local env = fastcopy(environment)
    local var = fastcopy(variables)
    local exp = fastcopy(expansions)
    for key, value in sortedpairs(configured) do
        if key ~= "" and (pattern == "" or find(upper(key),pattern)) then
            report_lists(key)
            report_lists("  env: %s",tabstr(rawget(environment,key))        or "unset")
            report_lists("  var: %s",tabstr(configured[key])                or "unset")
            report_lists("  exp: %s",tabstr(expansions[key])                or "unset")
            report_lists("  res: %s",tabstr(resolveprefix(expansions[key])) or "unset")
        end
    end
    instance.environment = fastcopy(env)
    instance.variables   = fastcopy(var)
    instance.expansions  = fastcopy(exp)
end

local report_resolved = logs.reporter("system","resolved")

function listers.configurations()
    local configurations = resolvers.instance.specification
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
