if not modules then modules = { } end modules ['lxml-sor'] = {
    version   = 1.001,
    comment   = "companion to lxml-sor.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, concat, rep = string.format, table.concat, string.rep
local lpegmatch = lpeg.match
local next = next

local xml         = xml
local lxml        = lxml
local context     = context

local lxmlsorters = lxml.sorters or { }
lxml.sorters      = lxmlsorters

if not lxml.splitid then
    local splitter = lpeg.C((1-lpeg.P(":"))^1) * lpeg.P("::") * lpeg.C(lpeg.P(1)^1)
    function lxml.splitid(id)
        local d, i = lpegmatch(splitter,id)
        if d then
            return d, i
        else
            return "", id
        end
    end
end

local lists = { }

function lxmlsorters.reset(name)
    lists[name] = {
        sorted  = false,
        entries = { },
        reverse = { },
        results = { },
    }
end

function lxmlsorters.add(name,n,key)
    local list = lists[name]
    if list.sorted then
        -- reverse is messed up, we could regenerate it and go on
    else
        local entries = list and list.entries
        if entries then
            local reverse = list.reverse
            local e = reverse[n]
            if e then
                local keys = entries[e][2]
                keys[#keys+1] = key
            else
                entries[#entries+1] = { n, { key } }
                reverse[n] = #entries
            end
        end
    end
end

function lxmlsorters.show(name)
    local list = lists[name]
    local entries = list and list.entries
    local NC, NR, bold = context.NC, context.NR, context.bold -- somehow bold is not working
    if entries then
        local maxn = 1
        for i=1,#entries do
            if #entries[i][2] > maxn then maxn = #entries[i][2] end
        end
        context.starttabulate { "|Tr|Tr|" .. rep("Tlp|",maxn) }
        NC() bold("n")
        NC() bold("id")
        if maxn > 1 then
            for i=1,maxn do
                NC() bold("entry " .. i)
            end
        else
            NC() bold("entry")
        end
        NC() NR()
        context.HL()
        for i=1,#entries do
            local entry = entries[i]
            local document, node = lxml.splitid(entry[1])
            NC() context(i)
            NC() context(node)
            local e = entry[2]
            for i=1,#e do
                NC() context.detokenize(e[i])
            end
            NC() NR()
        end
        context.stoptabulate()
    end
end

lxmlsorters.compare = sorters.comparers.basic -- (a,b)

function lxmlsorters.sort(name)
    local list = lists[name]
    local entries = list and list.entries
    if entries then
        -- filtering
        local results = { }
        list.results = results
        for i=1,#entries do
            local entry = entries[i]
            results[i] = {
                entry = entry[1],
                key = concat(entry[2], " "),
            }
        end
        -- preparation
        local strip = sorters.strip
        local splitter = sorters.splitters.utf
        local firstofsplit = sorters.firstofsplit
        for i=1, #results do
            local r = results[i]
            r.split = splitter(strip(r.key))
        end
        -- sorting
        sorters.sort(results,lxmlsorters.compare)
        -- finalizing
        list.nofsorted = #results
        local split = { }
        for k=1,#results do -- rather generic so maybe we need a function
            local v = results[k]
            local entry, tag = firstofsplit(v)
            local s = split[entry] -- keeps track of change
            if not s then
                s = { tag = tag, data = { } }
                split[entry] = s
            end
            s.data[#s.data+1] = v
        end
        list.results = split
        -- done
        list.sorted = true
    end
end

function lxmlsorters.flush(name,setup)
    local list = lists[name]
    local results = list and list.results
    local xmlw = context.xmlw
    if results and next(results) then
        for key, result in next, results do
            local tag, data = result.tag, result.data
            for d=1,#data do
                xmlw(setup,data[d].entry)
            end
        end
    else
        local entries = list and list.entries
        if entries then
            for i=1,#entries do
                xmlw(setup,entries[i][1])
            end
        end
    end
end
