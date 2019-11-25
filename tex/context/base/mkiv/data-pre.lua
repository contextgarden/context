if not modules then modules = { } end modules ['data-pre'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- filename        : only the basename, including suffix (file:)
-- pathname        : the pathpart (path:)
-- locate          : lookup in database (full: kpse: loc:)
-- home            : home path
-- jobpath         : job path
-- relative        : relative path ./ ../ ../.. (rel:)
-- auto            : relatove or lookup
-- toppath         : topmost path in input stack
-- selfautodir     : rather tex specific
-- selfautoloc     : rather tex specific
-- selfautoparent  : rather tex specific
-- environment     : expansion of variable (env:)
--
-- nodename        : computer name
-- machine         : private, when set
-- sysname         : operating system name
-- version         : operating system version
-- release         : operating system release

local insert, remove = table.insert, table.remove

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
    local pth = getenv('SELFAUTOLOC')
    return cleanpath(str and joinpath(pth,str) or pth)
end

prefixes.selfautoparent = function(str)
    local pth = getenv('SELFAUTOPARENT')
    return cleanpath(str and joinpath(pth,str) or pth)
end

prefixes.selfautodir = function(str)
    local pth = getenv('SELFAUTODIR')
    return cleanpath(str and joinpath(pth,str) or pth)
end

prefixes.home = function(str)
    local pth = getenv('HOME')
    return cleanpath(str and joinpath(pth,str) or pth)
end

prefixes.env  = prefixes.environment
prefixes.rel  = prefixes.relative
prefixes.loc  = prefixes.locate
prefixes.kpse = prefixes.locate
prefixes.full = prefixes.locate
prefixes.file = prefixes.filename
prefixes.path = prefixes.pathname

-- This one assumes that inputstack is set (used in the tex loader). It is a momentary resolve
-- as the top of the input stack changes.

local inputstack = { }
local stackpath  = resolvers.stackpath

local function toppath()
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

-- The next variant is similar but bound to explicitly registered paths. Practice should
-- show if that gives the same results as the previous one. It is meant for a project
-- stucture.

local function jobpath()
    local path = stackpath()
    if not path or path == "" then
        return "."
    else
        return path
    end
end

local function pushinputname(name)
    insert(inputstack,name)
end

local function popinputname(name)
    return remove(inputstack)
end

resolvers.toppath       = toppath
resolvers.jobpath       = jobpath
resolvers.pushinputname = pushinputname
resolvers.popinputname  = popinputname

-- This hook sit into the resolver:

prefixes.toppath = function(str) return cleanpath(joinpath(toppath(),str)) end -- str can be nil or empty
prefixes.jobpath = function(str) return cleanpath(joinpath(jobpath(),str)) end -- str can be nil or empty

resolvers.setdynamic("toppath")
resolvers.setdynamic("jobpath")

-- for a while (obsolete):
--
-- prefixes.jobfile = prefixes.jobpath
-- resolvers.setdynamic("jobfile")
