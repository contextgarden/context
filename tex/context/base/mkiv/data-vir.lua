if not modules then modules = { } end modules ['data-vir'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type
local formatters, validstrings = string.formatters, string.valid

local trace_virtual  = false
local report_virtual = logs.reporter("resolvers","virtual")

trackers.register("resolvers.locating", function(v) trace_virtual = v end)
trackers.register("resolvers.virtual",  function(v) trace_virtual = v end)

local resolvers = resolvers

local finders, openers, loaders, savers = resolvers.finders, resolvers.openers, resolvers.loaders, resolvers.savers

local data        = { }
local n           = 0 -- hm, number can be query
local f_virtual_n = formatters["virtual://%s.%s"]
local f_virtual_y = formatters["virtual://%s-%s.%s"]

function savers.virtual(specification,content,suffix)
    n = n + 1 -- one number for all namespaces
    local path = type(specification) == "table" and specification.path or specification
    if type(path) ~= "string" or path == "" then
        path = "virtualfile"
    end
    local filename = suffix and f_virtual_y(path,n,suffix) or f_virtual_n(path,suffix)
    if trace_virtual then
        report_virtual("saver: file %a saved",filename)
    end
    data[filename] = content
    return filename
end

function finders.virtual(specification)
    local original = specification.original
    local d = data[original]
    if d then
        if trace_virtual then
            report_virtual("finder: file %a found",original)
        end
        return original
    else
        if trace_virtual then
            report_virtual("finder: unknown file %a",original)
        end
        return finders.notfound()
    end
end

function openers.virtual(specification)
    local original = specification.original
    local d = data[original]
    if d then
        if trace_virtual then
            report_virtual("opener: file %a opened",original)
        end
        data[original] = nil -- when we comment this we can have error messages
        -- With utf-8 we signal that no regime is to be applied!
     -- characters.showstring(d)
        return openers.helpers.textopener("virtual",original,d,"utf-8")
    else
        if trace_virtual then
            report_virtual("opener: file %a not found",original)
        end
        return openers.notfound()
    end
end

function loaders.virtual(specification)
    local original = specification.original
    local d = data[original]
    if d then
        if trace_virtual then
            report_virtual("loader: file %a loaded",original)
        end
        data[original] = nil
        return true, d, #d
    end
    if trace_virtual then
        report_virtual("loader: file %a not loaded",original)
    end
    return loaders.notfound()
end
