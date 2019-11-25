if not modules then modules = { } end modules ['data-sch'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this one will be redone / localized

local load, tonumber = load, tonumber
local gsub, format = string.gsub, string.format
local sortedhash, concat = table.sortedhash, table.concat
local finders, openers, loaders = resolvers.finders, resolvers.openers, resolvers.loaders
local addsuffix, suffix, splitbase = file.addsuffix, file.suffix, file.splitbase
local md5hex = md5.hex

local trace_schemes  = false  trackers.register("resolvers.schemes",function(v) trace_schemes = v end)
local report_schemes = logs.reporter("resolvers","schemes")

local http           = require("socket.http")
local ltn12          = require("ltn12")

if mbox then mbox = nil end -- useless and even bugged (helper overwrites lib)

local resolvers      = resolvers
local schemes        = resolvers.schemes or { }
resolvers.schemes    = schemes

local cleaners       = { }
schemes.cleaners     = cleaners

local threshold      = 24 * 60 * 60

directives.register("schemes.threshold", function(v) threshold = tonumber(v) or threshold end)

function cleaners.none(specification)
    return specification.original
end

-- function cleaners.strip(specification)
--     -- todo: only keep suffix periods, so after the last
--     return (gsub(specification.original,"[^%a%d%.]+","-")) -- so we keep periods
-- end

function cleaners.strip(specification) -- keep suffixes
    local path, name = splitbase(specification.original)
    if path == "" then
        return (gsub(name,"[^%a%d%.]+","-"))
    else
        return (gsub((gsub(path,"%.","-") .. "-" .. name),"[^%a%d%.]+","-"))
    end
end

function cleaners.md5(specification)
    return addsuffix(md5hex(specification.original),suffix(specification.path))
end

local cleaner = cleaners.strip

directives.register("schemes.cleanmethod", function(v) cleaner = cleaners[v] or cleaners.strip end)

function resolvers.schemes.cleanname(specification)
    local hash = cleaner(specification)
    if trace_schemes then
        report_schemes("hashing %a to %a",specification.original,hash)
    end
    return hash
end

local cached     = { }
local loaded     = { }
local reused     = { }
local thresholds = { }
local handlers   = { }
local runner     = sandbox.registerrunner {
    name     = "curl resolver",
    method   = "execute",
    program  = "curl",
    template = '--silent --insecure --create-dirs --output "%cachename%" "%original%"',
    checkers = {
        cachename = "cache",
        original  = "url",
    }
}

local function fetch(specification)
    local original  = specification.original
    local scheme    = specification.scheme
    local cleanname = schemes.cleanname(specification)
    local cachename = caches.setfirstwritablefile(cleanname,"schemes")
    if not cached[original] then
        statistics.starttiming(schemes)
        if not io.exists(cachename) or (os.difftime(os.time(),lfs.attributes(cachename).modification) > (thresholds[protocol] or threshold)) then
            cached[original] = cachename
            local handler = handlers[scheme]
            if handler then
                if trace_schemes then
                    report_schemes("fetching %a, protocol %a, method %a",original,scheme,"built-in")
                end
                logs.flush()
                handler(specification,cachename)
            else
                if trace_schemes then
                    report_schemes("fetching %a, protocol %a, method %a",original,scheme,"curl")
                end
                logs.flush()
                runner {
                    original  = original,
                    cachename = cachename,
                }
            end
        end
        if io.exists(cachename) then
            cached[original] = cachename
            if trace_schemes then
                report_schemes("using cached %a, protocol %a, cachename %a",original,scheme,cachename)
            end
        else
            cached[original] = ""
            if trace_schemes then
                report_schemes("using missing %a, protocol %a",original,scheme)
            end
        end
        loaded[scheme] = loaded[scheme] + 1
        statistics.stoptiming(schemes)
    else
        if trace_schemes then
            report_schemes("reusing %a, protocol %a",original,scheme)
        end
        reused[scheme] = reused[scheme] + 1
    end
    return cached[original]
end

local function finder(specification,filetype)
    return resolvers.methodhandler("finders",fetch(specification),filetype)
end

local opener = openers.file
local loader = loaders.file

local function install(scheme,handler,newthreshold)
    handlers  [scheme] = handler
    loaded    [scheme] = 0
    reused    [scheme] = 0
    finders   [scheme] = finder
    openers   [scheme] = opener
    loaders   [scheme] = loader
    thresholds[scheme] = newthreshold or threshold
end

schemes.install = install

local function http_handler(specification,cachename)
    local tempname = cachename .. ".tmp"
    local handle   = io.open(tempname,"wb")
    local status, message = http.request {
        url  = specification.original,
        sink = ltn12.sink.file(handle)
    }
    if not status then
        os.remove(tempname)
    else
        os.remove(cachename)
        os.rename(tempname,cachename)
    end
    return cachename
end

install('http',http_handler)
install('https') -- see pod
install('ftp')

statistics.register("scheme handling time", function()
    local l, r, nl, nr = { }, { }, 0, 0
    for k, v in sortedhash(loaded) do
        if v > 0 then
            nl = nl + 1
            l[nl] = k .. ":" .. v
        end
    end
    for k, v in sortedhash(reused) do
        if v > 0 then
            nr = nr + 1
            r[nr] = k .. ":" .. v
        end
    end
    local n = nl + nr
    if n > 0 then
        if nl == 0 then l = { "none" } end
        if nr == 0 then r = { "none" } end
        return format("%s seconds, %s processed, threshold %s seconds, loaded: %s, reused: %s",
            statistics.elapsedtime(schemes), n, threshold, concat(l," "), concat(l," "))
    else
        return nil
    end
end)

-- We provide a few more helpers:

----- http        = require("socket.http")
local httprequest = http.request
local toquery     = url.toquery

local function fetchstring(url,data)
    local q = data and toquery(data)
    if q then
        url = url .. "?" .. q
    end
    local reply = httprequest(url)
    return reply -- just one argument
end

schemes.fetchstring = fetchstring

function schemes.fetchtable(url,data)
    local reply = fetchstring(url,data)
    if reply then
        local s = load("return " .. reply)
        if s then
            return s()
        end
    end
end
