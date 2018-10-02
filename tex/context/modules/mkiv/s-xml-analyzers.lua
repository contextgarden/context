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
local formatters = string.formatters
local setmetatableindex = table.setmetatableindex
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

    local function att(t,k)
        local v = setmetatableindex("number")
        t[k] = v
        return v
    end

    local function add(t,k)
        local v = {
            n          = 0,
            attributes = setmetatableindex(att),
            children   = setmetatableindex(add),
        }
        t[k] = v
        return v
    end

    setmetatableindex(tags,add)

    setmetatableindex(ents,"number")
    setmetatableindex(char,"number")

    setmetatableindex(attr,function(t,k)
        char[k] = char[k] or 0
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
            local children = parent and tags[parent].children[tg]
            local childatt = children and children.attributes
            if children then
                children.n = children.n + 1
            end
            if at then
                local attributes = tag.attributes
                for k, v in next, at do
                    local a = attributes[k]
                    a[v] = a[v] + 1
                    if childatt then
                        local a = childatt[k]
                        a[v] = a[v] + 1
                    end
                    for s in utfvalues(v) do
                        attr[s] = attr[s] + 1
                    end
                end
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
        local name = filename[i]
        local root = xml.load(name)
        --
        logs.report("xml analyze","loaded: %s",name)
        --
        collect(root)
        --
        local names = root.statistics.entities.names
        for n in next, names  do
            ents[n] = ents[n] + 1
        end
    end

    setmetatableindex(tags,nil)
    setmetatableindex(char,nil)
    setmetatableindex(attr,nil)
    setmetatableindex(ents,nil)

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
            local t = { }
            for k, v in next, children do
                t[k] = v.n
            end
            NC() context.bold("children") NC() context.puretext(sequenced(t)) NC() NR()
        end
        if next(attributes) then
            NC() context.bold("attributes") NC() context.puretext.darkgreen(concat(sortedkeys(attributes)," ")) NC() NR()
            for attribute, values in sortedhash(attributes) do
                local n = table.count(values)
                if attribute == "id" or attribute == "xml:id" or n > maxnofattributes then
                    NC() context("@%s",attribute) NC() context("%s different values",n) NC() NR()
                else
                    NC() context("@%s",attribute) NC() context.puretext(sequenced(values)) NC() NR()
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

local f_parent_s = formatters["xml:%s"]
local f_parent_n = formatters["\\startxmlsetups xml:%s\n  \\xmlflush{#1}\n\\stopxmlsetups"]
local f_parent_a = formatters["\\startxmlsetups xml:%s\n  %% @ % t\n  \\xmlflush{#1}\n\\stopxmlsetups"]
local f_child_s  = formatters["xml:%s:%s"]
local f_child_n  = formatters["\\startxmlsetups xml:%s:%s\n  \\xmlflush{#1}\n\\stopxmlsetups"]
local f_child_a  = formatters["\\startxmlsetups xml:%s:%s\n  %% @ % t\n  \\xmlflush{#1}\n\\stopxmlsetups"]

local f_template = formatters [ [[
%% file: %s

%% Beware, these are all (first level) setups. If you have a complex document
%% it often makes sense to use \\xmlfilter or similar local filter options.

%% presets

\startxmlsetup xml:presets:all
  \xmlsetsetups {#1} {
    %s
  }
\stopxmlsetups

%% setups

\xmlregistersetup{xml:presets:all}

\starttext
    \xmlprocessfile{main}{somefile.xml}{}
\stoptext

%s
]] ]

function moduledata.xml.analyzers.allsetups(filename,usedname)
    analyze(filename)
    local result = { }
    local setups = { }
    for name, data in table.sortedhash(tags) do
        local children   = data.children
        local attributes = data.attributes
        if next(attributes) then
            result[#result+1] = f_parent_a(name,sortedkeys(attributes))
        else
            result[#result+1] = f_parent_n(name)
        end
        setups[#setups+1] = f_parent_s(name)
        if next(children) then
            for k, v in sortedhash(children) do
                local attributes = v.attributes
                if next(attributes) then
                    result[#result+1] = f_child_a(name,k,sortedkeys(attributes))
                else
                    result[#result+1] = f_child_n(name,k)
                end
                setups[#setups+1] = f_child_s(name,k)
            end
        end
    end
    table.sort(setups)
    --
    if type(filename) == "table" then
        filename = concat(filename," | ")
    end
    --
    usedname = usedname or "xml-analyze-template.tex"
    --
    io.savedata(usedname,f_template(filename,concat(setups,"|\n    "),concat(result,"\n\n")))
    logs.report("xml analyze","presets saved in: %s",usedname)
end

-- example:

-- local t = { }
-- local x = xml.load("music-collection.xml")
-- for c in xml.collected(x,"//*") do
--     if not c.special and not t[c.tg] then
--         t[c.tg] = true
--     end
-- end
-- inspect(table.sortedkeys(t))

-- xml.finalizers.taglist = function(collected)
--     local t = { }
--     for i=1,#collected do
--         local c = collected[i]
--         if not c.special then
--             local tg = c.tg
--             if tg and not t[tg] then
--                 t[tg] = true
--             end
--         end
--     end
--     return t
-- end
-- local x = xml.load("music-collection.xml")
-- inspect(table.sortedkeys(xml.applylpath(x,"//*/taglist()")))

-- xml.finalizers.taglist = function(collected,parenttoo)
--     local t = { }
--     for i=1,#collected do
--         local c = collected[i]
--         if not c.special then
--             local tg = c.tg
--             if tg and not t[tg] then
--                 t[tg] = true
--             end
--             if parenttoo then
--                 local p = c.__p__
--                 if p and not p.special then
--                     local tg = p.tg .. ":" .. tg
--                     if tg and not t[tg] then
--                         t[tg] = true
--                     end
--                 end
--             end
--         end
--     end
--     return t
-- end

-- local x = xml.load("music-collection.xml")
-- inspect(table.sortedkeys(xml.applylpath(x,"//*/taglist()")))

-- local x = xml.load("music-collection.xml")
-- inspect(table.sortedkeys(xml.applylpath(x,"//*/taglist(true)")))
