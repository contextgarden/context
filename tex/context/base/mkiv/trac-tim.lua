if not modules then modules = { } end modules ['trac-tim'] = {
    version   = 1.001,
    comment   = "companion to m-timing.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gsub = string.format, string.gsub
local concat, sort = table.concat, table.sort
local next, tonumber = next, tonumber

moduledata          = moduledata or { }
local progress      = moduledata.progress or { }
moduledata.progress = progress

local report_timing = logs.reporter("timing")

if not nodes then nodes = { } end -- when loaded in mtxrun

progress.parameters      = nodes and nodes.snapshots.getparameters
progress.defaultfilename = ((tex and tex.jobname) or "whatever") .. "-luatex-progress"

-- storage

function progress.store()
    nodes.snapshots.takesample()
end

function progress.save(name)
    local filename = (name or progress.defaultfilename) .. ".lut"
    report_timing("saving data in %a",filename)
    table.save(filename,nodes.snapshots.getsamples())
    nodes.snapshots.resetsamples()
end

-- conversion

local processed  = { }
local parameters = progress.parameters()

local function convert(name)
    name = name ~= "" and name or progress.defaultfilename
    if not processed[name] then
        local names, top, bot, pages, paths, keys = { }, { }, { }, 0, { }, { }
        local data = table.load(name .. ".lut")
        if data then
            pages = #data
            if pages > 1 then
                local factor = 100
                for k=1,#data do
                    for k, v in next, data[k].node_memory do
                        keys[k] = true
                    end
                end
                for k=1,#data do
                    local m = data[k].node_memory
                    for k, v in next, keys do
                        if not m[k] then m[k] = 0 end
                    end
                end
                local function path(tag,subtag)
                    local b, t, s = nil, nil, { }
                    for k=1,#data do
                        local v = data[k][tag]
                        v = v and (subtag and v[subtag]) or v
                        if v then
                            v = tonumber(v)
                            if b then
                                if v > t then t = v end
                                if v < b then b = v end
                            else
                                t = v
                                b = v
                            end
                            s[k] = v
                        else
                            s[k] = 0
                        end
                    end
                    local tagname = subtag or tag
                    top[tagname] = gsub(format("%.3f",t),"%.000$","")
                    bot[tagname] = gsub(format("%.3f",b),"%.000$","")
                    local delta = t-b
                    if delta == 0 then
                        delta = 1
                    else
                        delta = factor/delta
                    end
                    for k=1,#s do
                        s[k] = format("(%.3f,%.3f)",k,(s[k]-b)*delta)
                    end
                    paths[tagname] = concat(s,"--")
                end
                for i=1,#parameters do
                    path(parameters[i])
                end
                for tag, _ in next, keys do
                    path("node_memory",tag)
                    names[#names+1] = tag
                end
                pages = pages - 1
            end
        end
        sort(names)
        processed[name] = {
            names = names,
            top   = top,
            bot   = bot,
            pages = pages,
            paths = paths,
        }
    end
    return processed[name]
end

progress.convert = convert

function progress.bot(name,tag)
    return convert(name).bot[tag] or 0
end

function progress.top(name,tag)
    return convert(name).top[tag] or 0
end

function progress.pages(name,tag)
    return convert(name).pages or 0
end

function progress.path(name,tag)
    return convert(name).paths[tag] or "origin"
end

function progress.nodes(name)
    return convert(name).names or { }
end

