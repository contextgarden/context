if not modules then modules = { } end modules ['publ-dat'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: strip the @ in the lpeg instead of on do_definition and do_shortcut
-- todo: store bibroot and bibrootdt
-- todo: dataset = datasets[dataset] => current = datasets[dataset]

--[[ldx--
<p>This is a prelude to integrated bibliography support. This file just loads
bibtex files and converts them to xml so that the we access the content
in a convenient way. Actually handling the data takes place elsewhere.</p>
--ldx]]--

if not characters then
    dofile(resolvers.findfile("char-utf.lua"))
    dofile(resolvers.findfile("char-tex.lua"))
end

local chardata  = characters.data
local lowercase = characters.lower

local lower, gsub, find = string.lower, string.gsub, string.find
local concat = table.concat
local next, type, rawget = next, type, rawget
local utfchar = utf.char
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local textoutf = characters and characters.tex.toutf
local settings_to_hash, settings_to_array = utilities.parsers.settings_to_hash, utilities.parsers.settings_to_array
local formatters = string.formatters
local sortedkeys, sortedhash = table.sortedkeys, table.sortedhash
local xmlcollected, xmltext, xmlconvert = xml.collected, xml.text, xmlconvert
local setmetatableindex = table.setmetatableindex

-- todo: more allocate

local P, R, S, V, C, Cc, Cs, Ct, Carg = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Carg

local trace             = false  trackers.register("publications", function(v) trace = v end)
local report            = logs.reporter("publications")

publications            = publications or { }
local publications      = publications

local datasets          = publications.datasets or { }
publications.datasets   = datasets

local writers           = publications.writers or { }
publications.writers    = writers

publications.statistics = publications.statistics or { }
local publicationsstats = publications.statistics

publicationsstats.nofbytes       = 0
publicationsstats.nofdefinitions = 0
publicationsstats.nofshortcuts   = 0
publicationsstats.nofdatasets    = 0

if not publications.usedentries then
    function publications.usedentries()
        return { }
    end
end

local v_all = interfaces and interfaces.variables.all or "all"

local xmlplaceholder = "<?xml version='1.0' standalone='yes'?>\n<bibtex></bibtex>"

local defaultshortcuts = {
    jan =  "1",
    feb =  "2",
    mar =  "3",
    apr =  "4",
    may =  "5",
    jun =  "6",
    jul =  "7",
    aug =  "8",
    sep =  "9",
    oct = "10",
    nov = "11",
    dec = "12",
}

local space      = lpeg.patterns.whitespace^0
local separator  = space * "+" * space
local l_splitter = lpeg.tsplitat(separator)
local d_splitter = lpeg.splitat (separator)

function publications.parenttag(dataset,tag)
    if not dataset or not tag then
        report("error in specification, dataset %a, tag %a",dataset,tag)
    elseif find(tag,"%+") then
        local tags    = lpegmatch(l_splitter,tag)
        local parent  = tags[1]
        local luadata = datasets[dataset].luadata
        local first   = luadata[parent]
        if first then
            local combined = first.combined
            if not combined then
                combined = { }
                first.combined = combined
            end
            -- add new ones but only once
            for i=2,#tags do
                local tag = tags[i]
                for j=1,#combined do
                    if combined[j] == tag then
                        tag = false
                    end
                end
                if tag then
                    local entry = luadata[tag]
                    if entry then
                        combined[#combined+1] = tag
                    end
                end
            end
            return parent
        end
    end
    return tag or ""
end

function publications.new(name)
    publicationsstats.nofdatasets = publicationsstats.nofdatasets + 1
    local dataset = {
        name       = name or "dataset " .. publicationsstats.nofdatasets,
        nofentries = 0,
        shortcuts  = { },
        luadata    = { },
        suffixes   = { },
        xmldata    = xmlconvert(xmlplaceholder),
     -- details    = { },
     -- ordered    = { },
        nofbytes   = 0,
        entries    = nil, -- empty == all
        sources    = { },
        loaded     = { },
        fields     = { },
        userdata   = { },
        used       = { },
        commands   = { }, -- for statistical purposes
        status     = {
            resources = false,
            userdata  = false,
        },
    }
    -- we delay details till we need it (maybe we just delay the
    -- individual fields but that is tricky as there can be some
    -- depedencies)
    setmetatableindex(dataset,function(t,k)
        -- will become a plugin
        if k == "details" then
            if publications.enhance then
                dataset.details = { }
                publications.enhance(dataset.name)
                return dataset.details
            end
        elseif k == "ordered" then
            local luadata = dataset.luadata
            local ordered = sortedkeys(luadata)
            for i=1,#ordered do
                ordered[i] = luadata[ordered[i]]
            end
            dataset.ordered = ordered
            return ordered
        end
    end)
    return dataset
end

function publications.markasupdated(name)
    if name == "string" then
        datasets[name].details = nil
    else
        datasets.details = nil
    end
end

setmetatableindex(datasets,function(t,k)
    if type(k) == "table" then
        return k -- so we can use this accessor as checker
    else
        local v = publications.new(k)
        datasets[k] = v
        return v
    end
end)

-- we apply some normalization

local space    = S(" \t\n\r\f") -- / " "

----- command  = P("\\") * Cc("btxcmd{") * (R("az","AZ")^1) * Cc("}")
----- command  = P("\\") * (Carg(1) * C(R("az","AZ")^1) / function(list,c) list[c] = (list[c] or 0) + 1 return "btxcmd{" .. c .. "}" end)
local command  = P("\\") * (Carg(1) * C(R("az","AZ")^1) * space^0 / function(list,c) list[c] = (list[c] or 0) + 1 return "btxcmd{" .. c .. "}" end)
local somemath = P("$") * ((1-P("$"))^1) * P("$") -- let's not assume nested math
local any      = P(1)
local done     = P(-1)
local one_l    = P("{")  / ""
local one_r    = P("}")  / ""
local two_l    = P("{{") / ""
local two_r    = P("}}") / ""
local special  = P("#")  / "\\letterhash"

local filter_0 = S('\\{}')
local filter_1 = (1-filter_0)^0 * filter_0
local filter_2 = Cs(
-- {{...}} ... {{...}}
--     two_l * (command + special + any - two_r - done)^0 * two_r * done +
--     one_l * (command + special + any - one_r - done)^0 * one_r * done +
            (somemath + command + special + any               )^0
)

-- Currently we expand shortcuts and for large ones (like the acknowledgements
-- in tugboat.bib) this is not that efficient. However, eventually strings get
-- hashed again.

local function do_shortcut(key,value,dataset)
    publicationsstats.nofshortcuts = publicationsstats.nofshortcuts + 1
    dataset.shortcuts[key] = value
end

local function getindex(dataset,luadata,tag)
    local found = luadata[tag]
    if found then
        return found.index or 0
    else
        local index = dataset.nofentries + 1
        dataset.nofentries = index
        return index
    end
end

publications.getindex = getindex

-- todo: categories : metatable that lowers and also counts
-- todo: fields     : metatable that lowers

local function do_definition(category,tag,tab,dataset)
    publicationsstats.nofdefinitions = publicationsstats.nofdefinitions + 1
    local fields  = dataset.fields
    local luadata = dataset.luadata
    local found   = luadata[tag]
    local index   = getindex(dataset,luadata,tag)
    local entries = {
        category = lower(category),
        tag      = tag,
        index    = index,
    }
    for i=1,#tab,2 do
        local original   = tab[i]
        local normalized = fields[original]
        if not normalized then
            normalized = lower(original) -- we assume ascii fields
            fields[original] = normalized
        end
        local value = tab[i+1]
        value = textoutf(value)
        if lpegmatch(filter_1,value) then
            value = lpegmatch(filter_2,value,1,dataset.commands) -- we need to start at 1 for { }
        end
        if normalized == "crossref" then
            local parent = luadata[value]
            if parent then
                setmetatableindex(entries,parent)
            else
                -- warning
            end
        end
        entries[normalized] = value
    end
    luadata[tag] = entries
end

local function resolve(s,dataset)
    return dataset.shortcuts[s] or defaultshortcuts[s] or s -- can be number
end

local percent    = P("%")
local start      = P("@")
local comma      = P(",")
local hash       = P("#")
local escape     = P("\\")
local single     = P("'")
local double     = P('"')
local left       = P('{')
local right      = P('}')
local both       = left + right
local lineending = S("\n\r")
local space      = S(" \t\n\r\f") -- / " "
local spacing    = space^0
local equal      = P("=")
----- collapsed  = (space^1)/ " "
local collapsed  = (lpegpatterns.whitespace^1)/" "

----- balanced   = lpegpatterns.balanced

local balanced   = P {
--     [1] = ((escape * (left+right)) + (collapsed + 1 - (left+right)) + V(2))^0,
    [1] = ((escape * (left+right)) + collapsed + (1 - (left+right))^1 + V(2))^0,
    [2] = left * V(1) * right,
}

local unbalanced = P {
    [1] = left * V(2) * right,
    [2] = ((escape * (left+right)) + collapsed + (1 - (left+right))^1 + V(1))^0,
}

local keyword    = C((R("az","AZ","09") + S("@_:-"))^1)
local key        = C((1-space-equal)^1)
local tag        = C((1-space-comma)^1)
local reference  = keyword
local category   = P("@") * C((1-space-left)^1)
local s_quoted   = ((escape*single) + collapsed + (1-single))^0
local d_quoted   = ((escape*double) + collapsed + (1-double))^0

local b_value    = (left  /"") * balanced * (right /"")
local u_value    = (left  /"") * unbalanced * (right /"") -- get rid of outer { }
local s_value    = (single/"") * (u_value + s_quoted) * (single/"")
local d_value    = (double/"") * (u_value + d_quoted) * (double/"")
local r_value    = reference * Carg(1) /resolve

local somevalue  = d_value + b_value + s_value + r_value
local value      = Cs((somevalue * ((spacing * hash * spacing)/"" * somevalue)^0))

local forget     = percent^1 * (1-lineending)^0
local spacing    = spacing * forget^0 * spacing
local assignment = spacing * key * spacing * equal * spacing * value * spacing
local shortcut   = P("@") * (P("string") + P("STRING") + P("String")) * spacing * left * ((assignment * Carg(1))/do_shortcut * comma^0)^0  * spacing * right
local definition = category * spacing * left * spacing * tag * spacing * comma * Ct((assignment * comma^0)^0) * spacing * right * Carg(1) / do_definition
local comment    = keyword * spacing * left * (1-right)^0 * spacing * right

-- todo \%

local bibtotable = (space + forget + shortcut + definition + comment + 1)^0

-- loadbibdata  -> dataset.luadata
-- loadtexdata  -> dataset.luadata
-- loadluadata  -> dataset.luadata

-- converttoxml -> dataset.xmldata from dataset.luadata

function publications.loadbibdata(dataset,content,source,kind)
    if not source then
        report("invalid source for dataset %a",dataset)
        return
    end
    dataset = datasets[dataset]
    local size = #content
    if size == 0 then
        report("empty source %a for dataset %a",source,dataset.name)
    else
        report("adding bib data to set %a from source %a",dataset.name,source)
    end
    statistics.starttiming(publications)
    publicationsstats.nofbytes = publicationsstats.nofbytes + size
    dataset.nofbytes = dataset.nofbytes + size
    if source then
        table.insert(dataset.sources, { filename = source, checksum = md5.HEX(content) })
        dataset.loaded[source] = kind or true
    end
    dataset.newtags  = #dataset.luadata > 0 and { } or dataset.newtags
    publications.markasupdated(dataset)
    lpegmatch(bibtotable,content or "",1,dataset)
    statistics.stoptiming(publications)
end

-- we could use xmlescape again

local cleaner_0 = S('<>&')
local cleaner_1 = (1-cleaner_0)^0 * cleaner_0
local cleaner_2 = Cs ( (
    P("<") / "&lt;" +
    P(">") / "&gt;" +
    P("&") / "&amp;" +
    P(1)
)^0)

local compact = false -- can be a directive but then we also need to deal with newlines ... not now

function publications.converttoxml(dataset,nice,dontstore,usedonly) -- we have fields !
    current = datasets[dataset]
    local luadata = current and current.luadata
    if luadata then
        statistics.starttiming(publications)
        --
        local result, r, n = { }, 0, 0
        local usedonly = usedonly and publications.usedentries(dataset)
        --
        r = r + 1 ; result[r] = "<?xml version='1.0' standalone='yes'?>"
        r = r + 1 ; result[r] = "<bibtex>"
        --
        if nice then
            local f_entry_start = formatters[" <entry tag='%s' category='%s' index='%s'>"]
            local s_entry_stop  = " </entry>"
            local f_field       = formatters["  <field name='%s'>%s</field>"]
            for tag, entry in sortedhash(luadata) do
                if not usedonly or usedonly[tag] then
                    r = r + 1 ; result[r] = f_entry_start(tag,entry.category,entry.index)
                    for key, value in sortedhash(entry) do
                        if key ~= "tag" and key ~= "category" and key ~= "index" then
                            if lpegmatch(cleaner_1,value) then
                                value = lpegmatch(cleaner_2,value)
                            end
                            if value ~= "" then
                                r = r + 1 ; result[r] = f_field(key,value)
                            end
                        end
                    end
                    r = r + 1 ; result[r] = s_entry_stop
                    n = n + 1
                end
            end
        else
            local f_entry_start = formatters["<entry tag='%s' category='%s' index='%s'>"]
            local s_entry_stop  = "</entry>"
            local f_field       = formatters["<field name='%s'>%s</field>"]
            for tag, entry in next, luadata do
                if not usedonly or usedonly[tag] then
                    r = r + 1 ; result[r] = f_entry_start(entry.tag,entry.category,entry.index)
                    for key, value in next, entry do
                        if key ~= "tag" and key ~= "category" and key ~= "index" then
                            if lpegmatch(cleaner_1,value) then
                                value = lpegmatch(cleaner_2,value)
                            end
                            if value ~= "" then
                                r = r + 1 ; result[r] = f_field(key,value)
                            end
                        end
                    end
                    r = r + 1 ; result[r] = s_entry_stop
                    n = n + 1
                end
            end
        end
        --
        r = r + 1 ; result[r] = "</bibtex>"
        --
        result = concat(result,nice and "\n" or nil)
        --
        if dontstore then
            -- indeed
        else
            statistics.starttiming(xml)
            current.xmldata = xmlconvert(result, {
                resolve_entities            = true,
                resolve_predefined_entities = true, -- in case we have escaped entities
             -- unify_predefined_entities   = true, -- &#038; -> &amp;
                utfize_entities             = true,
            } )
            statistics.stoptiming(xml)
            if lxml then
                lxml.register(formatters["btx:%s"](current.name),current.xmldata)
            end
        end
        statistics.stoptiming(publications)
        return result, n
    end
end

local loaders        = publications.loaders or { }
publications.loaders = loaders

local function resolvedname(dataset,filename)
    dataset = datasets[dataset]
    if type(filename) ~= "string" then
        report("invalid filename %a",tostring(filename))
    end
    local fullname = resolvers.findfile(filename,"bib")
    if fullname == "" then
        fullname = resolvers.findfile(filename) -- let's not be too picky
    end
    if not fullname or fullname == "" then
        report("no file %a",filename)
        dataset.fullname = filename
        return dataset, false
    else
        dataset.fullname = fullname
        return dataset, fullname
    end
end

publications.resolvedname = resolvedname

function loaders.bib(dataset,filename,kind)
    local dataset, fullname = resolvedname(dataset,filename)
    if not fullname then
        return
    end
    local data = io.loaddata(filename) or ""
    if data == "" then
        report("empty file %a, nothing loaded",fullname)
        return
    end
    if trace then
        report("loading file",fullname)
    end
    publications.loadbibdata(dataset,data,fullname,kind)
end

function loaders.lua(dataset,filename) -- if filename is a table we load that one
    local data, fullname
    if type(filename) == "table" then
        dataset = datasets[dataset]
        data = filename
    else
        dataset, fullname = resolvedname(dataset,filename)
        if not fullname then
            return
        end
        data = table.load(filename)
    end
    if data then
        local luadata = dataset.luadata
        for tag, entry in next, data do
            if type(entry) == "table" then
                entry.index  = getindex(dataset,luadata,tag)
                entry.tag    = tag
                luadata[tag] = entry -- no cleaning yet
            end
        end
    end
end

function loaders.buffer(dataset,name) -- if filename is a table we load that one
    dataset = datasets[dataset]
    name = file.removesuffix(name)
    local data = buffers.getcontent(name) or ""
    if data == "" then
        report("empty buffer %a, nothing loaded",name)
        return
    end
    if trace then
        report("loading buffer",name)
    end
    publications.loadbibdata(dataset,data,name,"bib")
end

function loaders.xml(dataset,filename)
    local dataset, fullname = resolvedname(dataset,filename)
    if not fullname then
        return
    end
    local luadata = dataset.luadata
    local root = xml.load(filename)
    for bibentry in xmlcollected(root,"/bibtex/entry") do
        local attributes = bibentry.at
        local tag = attributes.tag
        local entry = {
            category = attributes.category,
            tag      = tag, -- afterwards also set, to prevent overload
            index    = 0,   -- prelocated
        }
        for field in xmlcollected(bibentry,"/field") do
            entry[field.at.name] = field.dt[1] -- no cleaning yet | xmltext(field)
        end
        entry.index  = getindex(dataset,luadata,tag)
        entry.tag    = tag
        luadata[tag] = entry
    end
end

setmetatableindex(loaders,function(t,filetype)
    local v = function(dataset,filename)
        report("no loader for file %a with filetype %a",filename,filetype)
    end
    t[k] = v
    return v
end)

function publications.load(dataset,filename,kind)
    dataset = datasets[dataset]
    statistics.starttiming(publications)
    local files = settings_to_array(filename)
    for i=1,#files do
        local filetype, filename = string.splitup(files[i],"::")
        if not filename then
            filename = filetype
            filetype = file.suffix(filename)
        end
        loaders[filetype](dataset,filename)
        if kind then
            dataset.loaded[dataset.fullname or filename] = kind
        end
    end
    statistics.stoptiming(publications)
    return dataset
end

local checked  = function(s,d) d[s] = (d[s] or 0) + 1 end
local checktex = ( (1-P("\\"))^1 + P("\\") * ((C(R("az","AZ")^1)  * Carg(1))/checked))^0

function publications.analyze(dataset)
    dataset = datasets[dataset]
    local data       = dataset.luadata
    local categories = { }
    local fields     = { }
    local commands   = { }
    for k, v in next, data do
        categories[v.category] = (categories[v.category] or 0) + 1
        for k, v in next, v do
            fields[k] = (fields[k] or 0) + 1
            lpegmatch(checktex,v,1,commands)
        end
    end
    dataset.analysis = {
        categories = categories,
        fields     = fields,
        commands   = commands,
    }
end

-- str = [[
--     @COMMENT { CRAP }
--     @STRING{ hans = "h a n s" }
--     @STRING{ taco = "t a c o" }
--     @SOMETHING{ key1, abc = "t a c o" , def = "h a n s" }
--     @SOMETHING{ key2, abc = hans # taco }
--     @SOMETHING{ key3, abc = "hans" # taco }
--     @SOMETHING{ key4, abc = hans # "taco" }
--     @SOMETHING{ key5, abc = hans # taco # "hans" # "taco"}
--     @SOMETHING{ key6, abc =  {oeps {oeps} oeps} }
-- ]]

-- local dataset = publications.new()
-- publications.tolua(dataset,str)
-- publications.toxml(dataset)
-- publications.toxml(dataset)
-- print(dataset.xmldata)
-- inspect(dataset.luadata)
-- inspect(dataset.xmldata)
-- inspect(dataset.shortcuts)
-- print(dataset.nofbytes,statistics.elapsedtime(publications))

-- local dataset = publications.new()
-- publications.load(dataset,"IEEEabrv.bib")
-- publications.load(dataset,"IEEEfull.bib")
-- publications.load(dataset,"IEEEexample.bib")
-- publications.toxml(dataset)
-- print(dataset.nofbytes,statistics.elapsedtime(publications))

-- local dataset = publications.new()
-- publications.load(dataset,"gut.bib")
-- publications.load(dataset,"komoedie.bib")
-- publications.load(dataset,"texbook1.bib")
-- publications.load(dataset,"texbook2.bib")
-- publications.load(dataset,"texbook3.bib")
-- publications.load(dataset,"texgraph.bib")
-- publications.load(dataset,"texjourn.bib")
-- publications.load(dataset,"texnique.bib")
-- publications.load(dataset,"tugboat.bib")
-- publications.toxml(dataset)
-- print(dataset.nofbytes,statistics.elapsedtime(publications))

-- print(table.serialize(dataset.luadata))
-- print(table.serialize(dataset.xmldata))
-- print(table.serialize(dataset.shortcuts))
-- print(xml.serialize(dataset.xmldata))

-- a helper:

function publications.concatstate(i,n)
    if i == 0 then
        return 0
    elseif i == 1 then
        return 1
    elseif i == 2 and n == 2 then
        return 4
    elseif i == n then
        return 3
    else
        return 2
    end
end

-- savers

local savers = { }

local s_preamble = [[
% this is an export from context mkiv

@preamble {
    \ifdefined\btxcmd
        % we're probably in context
    \else
        \def\btxcmd#1{\csname#1\endcsname}
    \fi
}

]]

function savers.bib(dataset,filename,usedonly)
    local current  = datasets[dataset]
    local luadata  = current.luadata or { }
    local usedonly = usedonly and publications.usedentries(dataset)
    local f_start  = formatters["@%s{%s,\n"]
    local f_field  = formatters["  %s = {%s},\n"]
    local s_stop   = "}\n\n"
    local result   = { s_preamble }
    local n, r = 0, 1
    for tag, data in sortedhash(luadata) do
        if not usedonly or usedonly[tag] then
            r = r + 1 ; result[r] = f_start(data.category or "article",tag)
            for key, value in sortedhash(data) do
                r = r + 1 ; result[r] = f_field(key,value)
            end
            r = r + 1 ; result[r] = s_stop
            n = n + 1
        end
    end
    report("%s entries from dataset %a saved in %a",n,dataset,filename)
    io.savedata(filename,concat(result))
end

function savers.lua(dataset,filename,usedonly)
    local current  = datasets[dataset]
    local luadata  = current.luadata or { }
    local usedonly = usedonly and publications.usedentries(dataset)
    if usedonly then
        local list = { }
        for k, v in next, luadata do
            if usedonly[k] then
                list[k] = v
            end
        end
        luadata = list
    end
    report("%s entries from dataset %a saved in %a",table.count(luadata),dataset,filename)
    table.save(filename,luadata)
end

function savers.xml(dataset,filename,usedonly)
    local result, n = publications.converttoxml(dataset,true,true,usedonly)
    report("%s entries from dataset %a saved in %a",n,dataset,filename)
    io.savedata(filename,result)
end

function publications.save(dataset,filename,kind,usedonly)
    statistics.starttiming(publications)
    if not kind or kind == "" then
        kind = file.suffix(filename)
    end
    local saver = savers[kind]
    if saver then
        usedonly = usedonly ~= v_all
        saver(dataset,filename,usedonly)
    else
        report("unknown format %a for saving %a",kind,dataset)
    end
    statistics.stoptiming(publications)
    return dataset
end

commands.btxsavedataset = publications.save

-- loaders.bib("test",resolvers.findfile("mkiv-publications.bib","bibtex"))
--
-- publications.save("test","e:/tmp/foo.bib")
-- publications.save("test","e:/tmp/foo.lua")
-- publications.save("test","e:/tmp/foo.xml")
