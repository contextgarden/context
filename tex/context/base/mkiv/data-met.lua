if not modules then modules = { } end modules ['data-met'] = {
    version   = 1.100,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type
local find = string.find
local addurlscheme, urlhashed = url.addscheme, url.hashed
local collapsepath, joinfile = file.collapsepath, file.join

local report_methods = logs.reporter("resolvers","methods")

local trace_locating = false
local trace_methods  = false

trackers.register("resolvers.locating", function(v) trace_methods = v end)
trackers.register("resolvers.methods",  function(v) trace_methods = v end)

local allocate   = utilities.storage.allocate
local resolvers  = resolvers

local registered = { }

local function splitmethod(filename) -- todo: filetype in specification
    if not filename then
        return {
            scheme   = "unknown",
            original = filename,
        }
    end
    if type(filename) == "table" then
        return filename -- already split
    end
    filename = collapsepath(filename,".") -- hm, we should keep ./ in some cases
    if not find(filename,"://",1,true) then
        return {
            scheme   = "file",
            path     = filename,
            original = filename,
            filename = filename,
        }
    end
    local specification = urlhashed(filename)
    if not specification.scheme or specification.scheme == "" then
        return {
            scheme   = "file",
            path     = filename,
            original = filename,
            filename = filename,
        }
    else
        return specification
    end
end

-- local function splitmethod(filename) -- todo: filetype in specification
--     if not filename then
--         return { scheme = "unknown", original = filename }
--     end
--     if type(filename) == "table" then
--         return filename -- already split
--     end
--     return urlhashed(filename)
-- end

resolvers.splitmethod = splitmethod -- bad name but ok

-- the second argument is always analyzed (saves time later on) and the original
-- gets passed as original but also as argument

local function methodhandler(what,first,...) -- filename can be nil or false
    local method = registered[what]
    if method then
        local how       = method.how
        local namespace = method.namespace
        if how == "uri" or how == "url" then
            local specification = splitmethod(first)
            local scheme        = specification.scheme
            local resolver      = namespace and namespace[scheme]
            if resolver then
                if trace_methods then
                    report_methods("resolving, method %a, how %a, handler %a, argument %a",what,how,scheme,first)
                end
                return resolver(specification,...)
            else
                resolver = namespace.default or namespace.file
                if resolver then
                    if trace_methods then
                        report_methods("resolving, method %a, how %a, handler %a, argument %a",what,how,"default",first)
                    end
                    return resolver(specification,...)
                elseif trace_methods then
                    report_methods("resolving, method %a, how %a, handler %a, argument %a",what,how,"unset")
                end
            end
        elseif how == "tag" then
            local resolver = namespace and namespace[first]
            if resolver then
                if trace_methods then
                    report_methods("resolving, method %a, how %a, tag %a",what,how,first)
                end
                return resolver(...)
            else
                resolver = namespace.default or namespace.file
                if resolver then
                    if trace_methods then
                        report_methods("resolving, method %a, how %a, tag %a",what,how,"default")
                    end
                    return resolver(...)
                elseif trace_methods then
                    report_methods("resolving, method %a, how %a, tag %a",what,how,"unset")
                end
            end
        end
    else
        report_methods("resolving, invalid method %a")
    end
end

resolvers.methodhandler = methodhandler

function resolvers.registermethod(name,namespace,how)
    registered[name] = {
        how       = how or "tag",
        namespace = namespace
    }
    namespace["byscheme"] = function(scheme,filename,...)
        if scheme == "file" then
            return methodhandler(name,filename,...)
        else
            return methodhandler(name,addurlscheme(filename,scheme),...)
        end
    end
end

local concatinators = allocate { notfound = joinfile        }  -- concatinate paths
local locators      = allocate { notfound = function() end  }  -- locate databases
local hashers       = allocate { notfound = function() end  }  -- load databases
local generators    = allocate { notfound = function() end  }  -- generate databases

resolvers.concatinators = concatinators
resolvers.locators      = locators
resolvers.hashers       = hashers
resolvers.generators    = generators

local registermethod = resolvers.registermethod

registermethod("concatinators",concatinators,"tag")
registermethod("locators",     locators,     "uri")
registermethod("hashers",      hashers,      "uri")
registermethod("generators",   generators,   "uri")
