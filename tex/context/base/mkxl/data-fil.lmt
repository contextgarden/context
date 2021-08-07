if not modules then modules = { } end modules ['data-fil'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local ioopen = io.open
local isdir = lfs.isdir

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_files = logs.reporter("resolvers","files")

local resolvers        = resolvers
local resolveprefix    = resolvers.resolve
local findfile         = resolvers.findfile
local scanfiles        = resolvers.scanfiles
local registerfilehash = resolvers.registerfilehash
local appendhash       = resolvers.appendhash

local loadcachecontent = caches.loadcontent

local checkgarbage     = utilities.garbagecollector and utilities.garbagecollector.check

function resolvers.locators.file(specification)
    local filename = specification.filename
    local realname = resolveprefix(filename) -- no shortcut
    if realname and realname ~= '' and isdir(realname) then
        if trace_locating then
            report_files("file locator %a found as %a",filename,realname)
        end
        appendhash('file',filename,true) -- cache
    elseif trace_locating then
        report_files("file locator %a not found",filename)
    end
end

function resolvers.hashers.file(specification)
    local pathname = specification.filename
    local content  = loadcachecontent(pathname,'files')
    registerfilehash(pathname,content,content==nil)
end

function resolvers.generators.file(specification)
    local pathname = specification.filename
    local content  = scanfiles(pathname,false,true) -- scan once
    registerfilehash(pathname,content,true)
end

resolvers.concatinators.file = file.join

local finders  = resolvers.finders
local notfound = finders.notfound

function finders.file(specification,filetype)
    local filename  = specification.filename
    local foundname = findfile(filename,filetype)
    if foundname and foundname ~= "" then
        if trace_locating then
            report_files("file finder: %a found",filename)
        end
        return foundname
    else
        if trace_locating then
            report_files("file finder: %a not found",filename)
        end
        return notfound()
    end
end

-- The default textopener will be overloaded later on.

local openers    = resolvers.openers
local notfound   = openers.notfound
local overloaded = false

local function textopener(tag,filename,f)
    return {
        reader = function() return f:read () end,
        close  = function() return f:close() end,
    }
end

function openers.helpers.textopener(...)
    return textopener(...)
end

function openers.helpers.settextopener(opener)
    if overloaded then
        report_files("file opener: %s overloaded","already")
    else
        if trace_locating then
            report_files("file opener: %s overloaded","once")
        end
        overloaded = true
        textopener = opener
    end
end

function openers.file(specification,filetype)
    local filename = specification.filename
    if filename and filename ~= "" then
        local f = ioopen(filename,"r")
        if f then
            if trace_locating then
                report_files("file opener: %a opened",filename)
            end
            return textopener("file",filename,f)
        end
    end
    if trace_locating then
        report_files("file opener: %a not found",filename)
    end
    return notfound()
end

local loaders  = resolvers.loaders
local notfound = loaders.notfound

function loaders.file(specification,filetype)
    local filename = specification.filename
    if filename and filename ~= "" then
        local f = ioopen(filename,"rb")
        if f then
            if trace_locating then
                report_files("file loader: %a loaded",filename)
            end
            local s = f:read("*a") -- io.readall(f) is faster but we never have large files here
            if checkgarbage then
                checkgarbage(#s)
            end
            f:close()
            if s then
                return true, s, #s
            end
        end
    end
    if trace_locating then
        report_files("file loader: %a not found",filename)
    end
    return notfound()
end
