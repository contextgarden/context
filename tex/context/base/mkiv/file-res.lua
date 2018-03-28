if not modules then modules = { } end modules ['file-res'] = {
    version   = 1.001,
    comment   = "companion to supp-fil.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber
local format, find = string.format, string.find
local isfile = lfs.isfile
local is_qualified_path = file.is_qualified_path
local hasscheme, urlescape = url.hasscheme, url.escape

local trace_files   = false  trackers.register("resolvers.readfile",         function(v) trace_files   = v end)
local trace_details = false  trackers.register("resolvers.readfile.details", function(v) trace_details = v end)
local report_files  = logs.reporter("files","readfile")

resolvers.maxreadlevel = 2

directives.register("resolvers.maxreadlevel", function(v)
 -- resolvers.maxreadlevel = (v == false and 0) or (v == true and 2) or tonumber(v) or 2
    resolvers.maxreadlevel = v == false and 0 or tonumber(v) or 2
end)

local finders, loaders, openers = resolvers.finders, resolvers.loaders, resolvers.openers

local found = { } -- can best be done in the resolver itself

local function readfilename(specification,backtrack,treetoo)
    if trace_details then
        report_files(table.serialize(specification,"specification"))
    end
    local name = specification.filename
    local fnd = name and found[name]
    if not fnd then
        local names
        local suffix = file.suffix(name)
        if suffix ~= "" then
            names = { name }
        else
            local defaultsuffixes = resolvers.defaultsuffixes
            names = { }
            for i=1,#defaultsuffixes do
                names[i] = name .. "." .. defaultsuffixes[i]
            end
            if trace_files then
                report_files("locating: %s, using default suffixes: %a",name,defaultsuffixes)
            end
        end
        for i=1,#names do
            local fname = names[i]
            if isfile(fname) then
                if trace_files then
                    report_files("found local: %s",name)
                end
                fnd = fname
                break
            end
        end
        if not fnd and backtrack then
            for i=1,#names do
                local fname = names[i]
                for i=1,backtrack,1 do
                    fname = "../" .. fname
                    if isfile(fname) then
                        if trace_files then
                            report_files("found by backtracking: %s",fname)
                        end
                        fnd = fname
                        break
                    elseif trace_files then
                        report_files("not found by backtracking: %s",fname)
                    end
                end
                if fnd then
                    break
                end
            end
        end
        if not fnd then
            local paths = resolvers.getextrapaths()
            if paths then
                for i=1,#paths do
                    for i=1,#names do
                        local fname = paths[i] .. "/" .. names[i]
                        if isfile(fname) then
                            if trace_files then
                                report_files("found on extra path: %s",fname)
                            end
                            fnd = fname
                            break
                        end
                    end
                    if fnd then
                        break
                    end
                end
            end
        end
        if not fnd and treetoo then
            fnd = resolvers.findtexfile(name) or ""
            if trace_files then
                if fnd ~= "" then
                    report_files("found by tree lookup: %s",fnd)
                else
                    report_files("not found by tree lookup: %s",name)
                end
            end
        end
        found[name] = fnd
    elseif trace_files then
        if fnd ~= "" then
            report_files("already found: %s",fnd)
        else
            report_files("already not found: %s",name)
        end
    end
    return fnd or ""
end

-- resolvers.readfilename = readfilename -- bonus use getreadfilename instead

function resolvers.finders.original(specification) -- handy, see memstreams
    return specification.path
end

function finders.job(specification) return readfilename(specification,false,                 false) end -- current path, no backtracking
function finders.loc(specification) return readfilename(specification,resolvers.maxreadlevel,false) end -- current path, backtracking
function finders.sys(specification) return readfilename(specification,false,                 true ) end -- current path, obeys tex search
function finders.fix(specification) return readfilename(specification,resolvers.maxreadlevel,false) end -- specified path, backtracking
function finders.set(specification) return readfilename(specification,false,                 false) end -- specified path, no backtracking
function finders.any(specification) return readfilename(specification,resolvers.maxreadlevel,true ) end -- loc job sys

openers.job = openers.file loaders.job = loaders.file -- default anyway
openers.loc = openers.file loaders.loc = loaders.file
openers.sys = openers.file loaders.sys = loaders.file
openers.fix = openers.file loaders.fix = loaders.file
openers.set = openers.file loaders.set = loaders.file
openers.any = openers.file loaders.any = loaders.file

local function getreadfilename(scheme,path,name) -- better do a split and then pass table
    local fullname
    if hasscheme(name) or is_qualified_path(name) then
        fullname = name
    else
        if not find(name,"%",1,true) then
            name = urlescape(name) -- if no % in names
        end
        fullname = ((path == "") and format("%s:///%s",scheme,name)) or format("%s:///%s/%s",scheme,path,name)
    end
    return resolvers.findtexfile(fullname) or "" -- can be more direct
end

resolvers.getreadfilename = getreadfilename

-- a name belonging to the run but also honoring qualified

local implement = interfaces.implement

implement {
    name      = "getreadfilename",
    actions   = { getreadfilename, context },
    arguments = "3 strings",
}

implement {
    name      = "locfilename",
    actions   = { getreadfilename, context },
    arguments = { "'loc'","'.'", "string" },
}

implement {
    name      = "doifelselocfile",
    actions   = { getreadfilename, isfile, commands.doifelse },
    arguments = { "'loc'","'.'", "string" },
}
