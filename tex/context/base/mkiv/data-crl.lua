if not modules then modules = { } end modules ['data-crl'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this one is replaced by data-sch.lua --

local gsub   = string.gsub
local exists = io.exists

local resolvers = resolvers
local finders   = resolvers.finders
local openers   = resolvers.openers
local loaders   = resolvers.loaders

local setfirstwritablefile = caches.setfirstwritablefile

local curl     = resolvers.curl or { }
resolvers.curl = curl
local cached   = { }

local runner = sandbox.registerrunner {
    name     = "curl resolver",
    method   = "execute",
    program  = "curl",
    template = '--silent --insecure --create-dirs --output "%cachename%" "%original%"',
    checkers = {
        cachename = "cache",
        original  = "url",
    }
}

local function runcurl(specification)
    local original  = specification.original
 -- local scheme    = specification.scheme
    local cleanname = gsub(original,"[^%a%d%.]+","-")
    local cachename = setfirstwritablefile(cleanname,"curl")
    if not cached[original] then
        if not exists(cachename) then
            cached[original] = cachename
            runner {
                cachename = cachename,
                original  = original,
            }
        end
        if exists(cachename) then
            cached[original] = cachename
        else
            cached[original] = ""
        end
    end
    return cached[original]
end

-- old code: we could be cleaner using specification (see schemes)

local function finder(specification,filetype)
    return resolvers.methodhandler("finders",runcurl(specification),filetype)
end

local opener = openers.file
local loader = loaders.file

local function install(scheme)
    finders[scheme] = finder
    openers[scheme] = opener
    loaders[scheme] = loader
end

resolvers.curl.install = install

install('http')
install('https')
install('ftp')
