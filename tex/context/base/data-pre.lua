if not modules then modules = { } end modules ['data-pre'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local resolvers     = resolvers
local prefixes      = resolvers.prefixes

local cleanpath     = resolvers.cleanpath
local findgivenfile = resolvers.findgivenfile
local expansion     = resolvers.expansion
local getenv        = resolvers.getenv -- we can probably also use resolvers.expansion

local basename      = file.basename
local dirname       = file.dirname
local joinpath      = file.join

local isfile        = lfs.isfile

prefixes.environment = function(str)
    return cleanpath(expansion(str))
end

local function relative(str,n)
    if not isfile(str) then
        local pstr = "./" .. str
        if isfile(pstr) then
            str = pstr
        else
            local p = "../"
            for i=1,n or 2 do
                local pstr = p .. str
                if isfile(pstr) then
                    str = pstr
                    break
                else
                    p = p .. "../"
                end
            end
        end
    end
    return cleanpath(str)
end

local function locate(str)
    local fullname = findgivenfile(str) or ""
    return cleanpath(fullname ~= "" and fullname or str)
end

prefixes.relative = relative
prefixes.locate   = locate

prefixes.auto = function(str)
    local fullname = relative(str)
    if not isfile(fullname) then
        fullname = locate(str)
    end
    return fullname
end

prefixes.filename = function(str)
    local fullname = findgivenfile(str) or ""
    return cleanpath(basename((fullname ~= "" and fullname) or str)) -- no cleanpath needed here
end

prefixes.pathname = function(str)
    local fullname = findgivenfile(str) or ""
    return cleanpath(dirname((fullname ~= "" and fullname) or str))
end

prefixes.selfautoloc = function(str)
    return cleanpath(joinpath(getenv('SELFAUTOLOC'),str))
end

prefixes.selfautoparent = function(str)
    return cleanpath(joinpath(getenv('SELFAUTOPARENT'),str))
end

prefixes.selfautodir = function(str)
    return cleanpath(joinpath(getenv('SELFAUTODIR'),str))
end

prefixes.home = function(str)
    return cleanpath(joinpath(getenv('HOME'),str))
end

local function toppath()
    local inputstack = resolvers.inputstack -- dependency, actually the code should move but it's
    if not inputstack then                  -- more convenient to keep it here
        return "."
    end
    local pathname = dirname(inputstack[#inputstack] or "")
    if pathname == "" then
        return "."
    else
        return pathname
    end
end

resolvers.toppath = toppath

prefixes.toppath = function(str)
    return cleanpath(joinpath(toppath(),str))
end

prefixes.env  = prefixes.environment
prefixes.rel  = prefixes.relative
prefixes.loc  = prefixes.locate
prefixes.kpse = prefixes.locate
prefixes.full = prefixes.locate
prefixes.file = prefixes.filename
prefixes.path = prefixes.pathname

prefixes.jobfile = function(str)
    local path = resolvers.stackpath() or "."
    if str and str ~= "" then
        return cleanpath(joinpath(path,str))
    else
        return cleanpath(path)
    end
end

resolvers.setdynamic("jobfile")
