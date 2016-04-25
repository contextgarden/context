if not modules then modules = { } end modules ['s-xml-analyzers'] = {
    version   = 1.001,
    comment   = "companion to s-xml-analyzers.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.xml           = moduledata.xml           or { }
moduledata.xml.analyzers = moduledata.xml.analyzers or { }

local next, type = next, type
local utfvalues = string.utfvalues
local context = context
local NC, NR, HL, FL, LL, SL, TB = context.NC, context.NR, context.HL, context.TB, context.FL, context.LL, context.SL
local sortedhash, sortedkeys, concat, sequenced = table.sortedhash, table.sortedkeys, table.concat, table.sequenced

local chardata = characters.data

local tags = { }
local char = { }
local attr = { }
local ents = { }
local name = nil

local function analyze(filename)

    if type(filename) == "string" then
        filename = { filename }
    end

    table.sort(filename)

    local hash = concat(filename,"|")

    if hash == name then
        return
    end

    name = hash
    tags = { }
    char = { }
    attr = { }
    ents = { }

    table.setmetatableindex(tags,function(t,k)
        local v = {
            n          = 0,
            attributes = { },
            children   = { },
        }
        t[k] = v
        return v
    end)

    table.setmetatableindex(char,function(t,k)
        t[k] = 0
        return 0
    end)

    table.setmetatableindex(attr,function(t,k)
        char[k] = char[k] or 0
        t[k] = 0
        return 0
    end)

    table.setmetatableindex(ents,function(t,k)
        t[k] = 0
        return 0
    end)

    local function collect(e,parent)
        local dt = e.dt
        if e.special then
            if dt then
                for i=1,#dt do
                    local d = dt[i]
                    if type(d) == "table" then
                        collect(d,tg)
                    end
                end
            end
        else
            local at = e.at
            local tg = e.tg
            local tag = tags[tg]
            tag.n = tag.n + 1
            if at then
                local attributes = tag.attributes
                for k, v in next, at do
                    local a = attributes[k]
                    if a then
                        a[v] = (a[v] or 0) + 1
                    else
                        attributes[k] = { [v] = 1 }
                    end
                    for s in utfvalues(v) do
                        attr[s] = attr[s] + 1
                    end
                end
            end
            if parent then
                local children = tags[parent].children
                children[tg] = (children[tg] or 0) + 1
            end
            if dt then
                for i=1,#dt do
                    local d = dt[i]
                    if type(d) == "table" then
                        collect(d,tg)
                    else
                        for s in utfvalues(d) do
                            char[s] = char[s] + 1
                        end
                    end
                end
            end
        end
    end

    for i=1,#filename do
        local root = xml.load(filename[i])
        collect(root)
        --
        local names = root.statistics.entities.names
        for n in next, names  do
            ents[n] = ents[n] + 1
        end
    end

    table.setmetatableindex(tags,nil)
    table.setmetatableindex(char,nil)
    table.setmetatableindex(attr,nil)
    table.setmetatableindex(ents,nil)

end

moduledata.xml.analyzers.maxnofattributes = 100

function moduledata.xml.analyzers.structure(filename)
    analyze(filename)
    local done = false
    local maxnofattributes = tonumber(moduledata.xml.analyzers.maxnofattributes) or 100
    context.starttabulate { "|l|pA{nothyphenated,flushleft,verytolerant,stretch,broad}|" }
    for name, data in table.sortedhash(tags) do
        if done then
            context.TB()
        else
            done = true
        end
        local children   = data.children
        local attributes = data.attributes
        NC() context.bold("element") NC() context.darkred(name) NC() NR()
        NC() context.bold("frequency") NC() context(data.n) NC() NR()
        if next(children) then
            NC() context.bold("children") NC() context.puretext(sequenced(children)) NC() NR()
        end
        if next(attributes) then
            NC() context.bold("attributes") NC() context.puretext.darkgreen(concat(sortedkeys(attributes)," ")) NC() NR()
            for attribute, values in sortedhash(attributes) do
                local n = table.count(values)
                if attribute == "id" or attribute == "xml:id" or n > maxnofattributes then
                    NC() context(attribute) NC() context("%s different values",n) NC() NR()
                else
                    NC() context(attribute) NC() context.puretext(sequenced(values)) NC() NR()
                end
            end
        end
    end
    context.stoptabulate()
end

function moduledata.xml.analyzers.characters(filename)
    analyze(filename)
    context.starttabulate { "|r|r|l|c|l|" }
    for c, n in table.sortedhash(char) do
        NC() context.darkred("%s",n)
        NC() context.darkgreen("%s",attr[c])
        NC() context("%U",c)
        NC() context.char(c)
        NC() context("%s",chardata[c].description)
        NC() NR()
    end
    context.stoptabulate()
end

function moduledata.xml.analyzers.entities(filename)
    analyze(filename)
    context.starttabulate { "|l|r|" }
    for e, n in table.sortedhash(ents) do
        NC() context(e)
        NC() context(n)
        NC() NR()
    end
    context.stoptabulate()
end


