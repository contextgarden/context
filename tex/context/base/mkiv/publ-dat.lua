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
-- todo: maybe split this file

--[[ldx--
<p>This is a prelude to integrated bibliography support. This file just loads
bibtex files and converts them to xml so that the we access the content
in a convenient way. Actually handling the data takes place elsewhere.</p>
--ldx]]--

if not characters then
    dofile(resolvers.findfile("char-utf.lua"))
    dofile(resolvers.findfile("char-tex.lua"))
end

if not utilities.sequencers then
    dofile(resolvers.findfile("util-seq.lua"))
end

local lower, find, sub = string.lower, string.find, string.sub
local concat, copy, tohash = table.concat, table.copy, table.tohash
local next, type, rawget, tonumber = next, type, rawget, tonumber
local utfchar = utf.char
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local textoutf = characters and characters.tex.toutf
local settings_to_hash, settings_to_array = utilities.parsers.settings_to_hash, utilities.parsers.settings_to_array
local formatters = string.formatters
local sortedkeys, sortedhash, keys, sort = table.sortedkeys, table.sortedhash, table.keys, table.sort
local xmlcollected, xmltext, xmlconvert = xml.collected, xml.text, xml.convert
local setmetatableindex = table.setmetatableindex

-- todo: more allocate

local P, R, S, V, C, Cc, Cs, Ct, Carg, Cmt, Cp = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Carg, lpeg.Cmt, lpeg.Cp

local p_whitespace      = lpegpatterns.whitespace
local p_utf8character   = lpegpatterns.utf8character

local trace             = false  trackers.register("publications",            function(v) trace = v end)
local trace_duplicates  = true   trackers.register("publications.duplicates", function(v) trace = v end)
local trace_strings     = false  trackers.register("publications.strings",    function(v) trace = v end)

local report            = logs.reporter("publications")
local report_duplicates = logs.reporter("publications","duplicates")
local report_strings    = logs.reporter("publications","strings")

local allocate          = utilities.storage.allocate

local commands          = commands
local implement         = interfaces and interfaces.implement

publications            = publications or { }
local publications      = publications

local datasets          = publications.datasets or { }
publications.datasets   = datasets

local writers           = publications.writers or { }
publications.writers    = writers

local tables            = publications.tables or { }
publications.tables     = tables

publications.statistics = publications.statistics or { }
local publicationsstats = publications.statistics

local loaders           = publications.loaders or { }
publications.loaders    = loaders

local casters           = { }
publications.casters    = casters

-- local sorters           = { }
-- publications.sorters    = sorters
--
-- local indexers          = { }
-- publications.indexers   = indexers

local components        = { }
publications.components = components -- register components

local enhancers         = publications.enhancers or { }
publications.enhancers  = enhancers

local enhancer          = publications.enhancer or utilities.sequencers.new { arguments = "dataset" }
publications.enhancer   = enhancer

utilities.sequencers.appendgroup(enhancer,"system") -- private

publicationsstats.nofbytes       = 0
publicationsstats.nofdefinitions = 0
publicationsstats.nofshortcuts   = 0
publicationsstats.nofdatasets    = 0

local privates = allocate {
    category      = true,
    tag           = true,
    index         = true,
    suffix        = true,
    specification = true,
}

local specials = allocate {
    key      = true,
    crossref = true,
    keywords = true,
    language = true,
    comment  = true,
}

local implicits = allocate {
    category = "implicit",
    tag      = "implicit",
    key      = "implicit",
    keywords = "implicit",
    language = "implicit",
    crossref = "implicit",
}

local origins = allocate {
    "optional",
    "extra",
    "required",
    "virtual",
}

local virtuals = allocate {
    "authoryear",
    "authoryears",
    "authornum",
    "num",
    "suffix",
}

local defaulttypes = allocate {
    author     = "author",
    editor     = "author",
    translator = "author",
 -- publisher  = "author",
    page       = "pagenumber",
    pages      = "pagenumber",
    keywords   = "keyword",
    doi        = "url",
    url        = "url",
}

local defaultsets = allocate {
    page = { "page", "pages" },
}

tables.implicits = implicits
tables.origins   = origins
tables.virtuals  = virtuals
tables.types     = defaulttypes
tables.sets      = defaultsets
tables.privates  = privates
tables.specials  = specials

local variables  = interfaces and interfaces.variables or setmetatableindex("self")

local v_all      = variables.all
local v_default  = variables.default

if not publications.usedentries then
    function publications.usedentries()
        return { }
    end
end

local xmlplaceholder = "<?xml version='1.0' standalone='yes'?>\n<bibtex></bibtex>"

local defaultshortcuts = allocate {
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

local space      = p_whitespace^0
local separator  = space * "+" * space
local p_splitter = lpeg.tsplitat(separator)

local unknownfield = function(t,k)
    local v = "extra"
    t[k] = v
    return v
end

local unknowncategory = function(t,k)
    local v = {
        required = false,
        optional = false,
        virtual  = false,
        fields   = setmetatableindex(unknownfield), -- this will remember them
        types    = unknowntypes,
        sets     = setmetatableindex(defaultsets),  -- new, but rather small
    }
    t[k] = v
    return v
end

local unknowntype = function(t,k)
    local v = "string"
    t[k] = v
    return v
end

local default = {
    name       = name,
    version    = "1.00",
    comment    = "unknown specification.",
    author     = "anonymous",
    copyright  = "no one",
    categories = setmetatableindex(unknowncategory),
    types      = setmetatableindex(defaulttypes,unknowntype),
}

-- maybe at some point we can have a handlers table with per field
-- a found, fetch, ... method

local function checkfield(specification,category,data)
    local list    = setmetatableindex({},implicits)
    data.fields   = list
    data.category = category
    local sets    = data.sets or { }
    for i=1,#origins do
        local t = origins[i]
        local d = data[t]
        if d then
            for i=1,#d do
                local di = d[i]
                di = sets[di] or di
                if type(di) == "table" then
                    for i=1,#di do
                        list[di[i]] = t
                    end
                else
                    list[di] = t
                end
            end
        else
            data[t] = { }
        end
    end
    return data
end

local specifications = setmetatableindex(function(t,name)
    if not name then
        return default -- initializer
    end
    local filename = formatters["publ-imp-%s.lua"](name)
    local fullname = resolvers.findfile(filename) or ""
    if fullname == "" then
        report("no data definition file %a for %a",filename,name)
        t[name] = default
        return default
    end
    local specification = table.load(fullname)
    if not specification then
        report("invalid data definition file %a for %a",fullname,name)
        t[name] = default
        return default
    end
    --
    local categories = specification.categories
    if not categories then
        categories = { }
        specification.categories = categories
    end
    setmetatableindex(categories,unknowncategory)
    --
    local types = specification.types
    if not types then
        types = defaulttypes
        specification.types = types
    end
    setmetatableindex(types,unknowntype)
    --
    local fields = setmetatableindex(unknownfield)
    specification.fields = fields
    --
    local virtual = specification.virtual
    if virtual == nil then -- so false is valid
        virtual = { }
    elseif virtual == false then
        virtual = { }
    elseif type(virtual) ~= table then
        virtual = virtuals
    end
    specification.virtual = virtual
    specification.virtualfields = tohash(virtual)
    --
    for category, data in next, categories do
        categories[category] = checkfield(specification,category,copy(data)) -- we make sure we have no clones
    end
    --
    t[name] = specification
    --
    return specification
end)

publications.specifications = specifications

function publications.setcategory(target,category,data)
    local specification = specifications[target]
    specification.categories[category] = checkfield(specification,category,data)
end

function publications.parenttag(dataset,tag)
    if not dataset or not tag then
        report("error in specification, dataset %a, tag %a",dataset,tag)
    elseif find(tag,"+",1,true) then
        local tags    = lpegmatch(p_splitter,tag)
        local parent  = tags[1]
        local current = datasets[dataset]
        local luadata = current.luadata
        local details = current.details
        local first   = luadata[parent]
        if first then
            local detail   = details[parent]
            local children = detail.children
            if not children then
                children = { }
                detail.children = children
            end
            -- add new ones but only once
            for i=2,#tags do
                local tag = tags[i]
                for j=1,#children do
                    if children[j] == tag then
                        tag = false
                    end
                end
                if tag then
                    local entry = luadata[tag]
                    if entry then
                        local detail = details[tag]
                        children[#children+1] = tag
                        if detail.parent then
                            report("error in combination, dataset %a, tag %a, parent %a, ignored %a",dataset,tag,detail.parent,parent)
                        else
                            report("combining, dataset %a, tag %a, parent %a",dataset,tag,parent)
                            detail.parent = parent
                        end
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
        details    = { },
        ordered    = { },
        nofbytes   = 0,
        entries    = nil, -- empty == all
        sources    = { },
        loaded     = { },
        fields     = { },
        userdata   = { },
        used       = { },
        commands   = { }, -- for statistical purposes
        citestate  = { },
        status     = {
            resources = false,
            userdata  = false,
        },
        specifications = {
            -- used specifications
        },
        suffixed   = false,
    }
    -- we delay details till we need it (maybe we just delay the
    -- individual fields but that is tricky as there can be some
    -- depedencies)
    return dataset
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

local function getindex(dataset,luadata,tag)
    local found = luadata[tag]
    if found then
        local index = found.index or 0
        dataset.ordered[tag] = index
        return index
    else
        local index = dataset.nofentries + 1
        dataset.nofentries = index
        dataset.ordered[index] = tag
        return index
    end
end

publications.getindex = getindex

do

    -- we apply some normalization

    local space     = S(" \t\n\r\f") -- / " "
    local collapsed = space^1/" "
    local csletter  = lpegpatterns.csletter or R("az","AZ")

    ----- command   = P("\\") * Cc("btxcmd{") * (R("az","AZ")^1) * Cc("}")
    ----- command   = P("\\") * (Carg(1) * C(R("az","AZ")^1) / function(list,c) list[c] = (list[c] or 0) + 1 return "btxcmd{" .. c .. "}" end)
    ----- command   = P("\\") * (Carg(1) * C(R("az","AZ")^1) * space^0 / function(list,c) list[c] = (list[c] or 0) + 1 return "btxcmd{" .. c .. "}" end)
    local command   = P("\\") * (Carg(1) * C(csletter^1) * space^0 / function(list,c) list[c] = (list[c] or 0) + 1 return "btxcmd{" .. c .. "}" end)
    local whatever  = P("\\") * P(" ")^1 / " "
    -----           + P("\\") * ( P("hbox") + P("raise") ) -- bah -- no longer
    local somemath  = P("$") * ((1-P("$"))^1) * P("$") -- let's not assume nested math
    ----- character = lpegpatterns.utf8character
    local any       = P(1)
    local done      = P(-1)
 -- local one_l     = P("{")  / ""
 -- local one_r     = P("}")  / ""
 -- local two_l     = P("{{") / ""
 -- local two_r     = P("}}") / ""
    local zero_l_r  = P("{}") / "" * #P(1)
    local special   = P("#")  / "\\letterhash "

    local filter_0  = S('\\{}#')
    local filter_1  = (1-filter_0)^0 * filter_0
    local filter_2  = Cs(
    -- {{...}} ... {{...}}
    --     two_l * (command + special + any - two_r - done)^0 * two_r * done +
    --     one_l * (command + special + any - one_r - done)^0 * one_r * done +
                (
                    somemath +
                    whatever +
                    command +
                    special +
                    collapsed +
                    zero_l_r +
                    any
                )^0
    )

    -- Currently we expand shortcuts and for large ones (like the acknowledgements
    -- in tugboat.bib) this is not that efficient. However, eventually strings get
    -- hashed again.

    local function do_shortcut(key,value,dataset)
        publicationsstats.nofshortcuts = publicationsstats.nofshortcuts + 1
        dataset.shortcuts[key] = value
    end

    -- todo: categories : metatable that lowers and also counts
    -- todo: fields     : metatable that lowers

    local tags = table.setmetatableindex("table")

    local indirectcrossrefs = true

    local function do_definition(category,tag,tab,dataset)
        publicationsstats.nofdefinitions = publicationsstats.nofdefinitions + 1
        if tag == "" then
            tag = "no-tag-set"
        end
        local fields  = dataset.fields
        local luadata = dataset.luadata
        local hashtag = tag
        if luadata[tag] then
            local t = tags[tag]
            local d = dataset.name
            local n = (t[d] or 0) + 1
            t[d] = n
            hashtag = tag .. "-" .. n
            if trace_duplicates then
                local p = { }
                for k, v in sortedhash(t) do
                    p[#p+1] = formatters["%s:%s"](k,v)
                end
                report_duplicates("tag %a is present multiple times: % t, assigning hashtag %a",tag,p,hashtag)
            end
        end
        local index  = getindex(dataset,luadata,hashtag)
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
         -- if entries[normalized] then
            if rawget(entries,normalized) then
                if trace_duplicates then
                    report_duplicates("redundant field %a is ignored for tag %a in dataset %a",normalized,tag,dataset.name)
                end
            else
                local value = tab[i+1]
                value = textoutf(value)
                if lpegmatch(filter_1,value) then
                    value = lpegmatch(filter_2,value,1,dataset.commands) -- we need to start at 1 for { }
                end
                if normalized == "crossref" then
                    if indirectcrossrefs then
                        setmetatableindex(entries,function(t,k)
                            local parent = rawget(luadata,value)
                            if parent == entries then
                                report_duplicates("bad parent %a for %a in dataset %s",value,hashtag,dataset.name)
                                setmetatableindex(entries,nil)
                                return entries
                            elseif parent then
                                setmetatableindex(entries,parent)
                                return entries[k]
                            else
                                report_duplicates("no valid parent %a for %a in dataset %s",value,hashtag,dataset.name)
                                setmetatableindex(entries,nil)
                            end
                        end)
                    else
                        dataset.nofcrossrefs = dataset.nofcrossrefs +1
                    end
                end
                entries[normalized] = value
            end
        end
        luadata[hashtag] = entries
    end

    local f_invalid = formatters["<invalid: %s>"]

    local function resolve(s,dataset)
        local e = dataset.shortcuts[s]
        if e then
            if trace_strings then
                report_strings("%a resolves to %a",s,e)
            end
            return e
        end
        e = defaultshortcuts[s]
        if e then
            if trace_strings then
                report_strings("%a resolves to default %a",s,e)
            end
            return e
        end
        if tonumber(s) then
            return s
        end
        report("error in database, invalid value %a",s)
        return f_invalid(s)
    end

    local pattern = p_whitespace^0
                  * C(P("message") + P("warning") + P("error") + P("comment")) * p_whitespace^0 * P(":")
                  * p_whitespace^0
                  * C(P(1)^1)

    local function do_comment(s,dataset)
        local how, what = lpegmatch(pattern,s)
        if how and what then
            local t = string.splitlines(utilities.strings.striplines(what))
            local b = file.basename(dataset.fullname or dataset.name or "unset")
            for i=1,#t do
                report("%s > %s : %s",b,how,t[i])
            end
        end
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
    local collapsed  = p_whitespace^1/" "
    local nospaces   = p_whitespace^1/""

    local p_left     = (p_whitespace^0 * left) / ""
    local p_right    = (right * p_whitespace^0) / ""

    local keyword    = C((R("az","AZ","09") + S("@_:-"))^1)
    local key        = C((1-space-equal)^1)
    local tag        = C((1-space-comma)^0)
    local category   = C((1-space-left)^1)
    local s_quoted   = ((escape*single) + collapsed + (1-single))^0
    local d_quoted   = ((escape*double) + collapsed + (1-double))^0

    local reference  = P("@{") * C((R("az","AZ","09") + S("_:-"))^1) * P("}")
    local r_value    = reference * Carg(1) / resolve

    local balanced   = P {
        [1] = ((escape * (left+right)) + (collapsed + r_value + 1 - (left+right))^1 + V(2))^0,
        [2] = left * V(1) * right,
    }

 -- local unbalanced = P {
 --     [1] = left * V(2) * right,
 --     [2] = ((escape * (left+right)) + (collapsed + 1 - (left+right))^1 + V(1))^0,
 -- }

    local unbalanced = (left/"") * balanced * (right/"") * P(-1)

    local reference  = C((R("az","AZ","09") + S("_:-"))^1)
    local b_value    = p_left * balanced * p_right
    local s_value    = (single/"") * (unbalanced + s_quoted) * (single/"")
    local d_value    = (double/"") * (unbalanced + d_quoted) * (double/"")
    local r_value    = P("@") * reference * Carg(1) / resolve
                     +          reference * Carg(1) / resolve
    local n_value    = C(R("09")^1)

    local e_value    = Cs((left * balanced * right + (1 - S(",}")))^0) * Carg(1) / function(s,dataset)
        return resolve(s,dataset)
    end

    local somevalue  = d_value + b_value + s_value + r_value + n_value + e_value
    local value      = Cs((somevalue * ((spacing * hash * spacing)/"" * somevalue)^0))

    local stripper   = lpegpatterns.collapser
    local stripped   = value / function(s) return lpegmatch(stripper,s) end

    local forget     = percent^1 * (1-lineending)^0
    local spacing    = spacing * forget^0 * spacing
    local replacement= spacing * key * spacing * equal * spacing * value    * spacing
    local assignment = spacing * key * spacing * equal * spacing * stripped * spacing
    local definition = category * spacing * left * spacing * tag * spacing * comma * Ct((assignment * comma^0)^0) * spacing * right * Carg(1) / do_definition

    local crapword   = C((1-space-left)^1)
    local shortcut   = Cmt(crapword,function(_,p,s) return lower(s) == "string"  and p end) * spacing * left * ((replacement * Carg(1))/do_shortcut * comma^0)^0  * spacing * right
    local comment    = Cmt(crapword,function(_,p,s) return lower(s) == "comment" and p end) * spacing * lpegpatterns.argument * Carg(1) / do_comment

    local casecrap   = #S("sScC") * (shortcut + comment)

    local bibtotable = (space + forget + P("@") * (casecrap + definition) + 1)^0

    -- todo \%

    -- loadbibdata  -> dataset.luadata
    -- loadtexdata  -> dataset.luadata
    -- loadluadata  -> dataset.luadata

    -- converttoxml -> dataset.xmldata from dataset.luadata

    -- author = "al-" # @AHSAI # "," # @SHAYKH # " " # @AHMAD # " Ibn " # @ZAYNIDDIN
    -- author = {al-@{AHSAI}, @{SHAYKH} @{AHMAD} Ibn @{ZAYNIDDIN}}

    function publications.loadbibdata(dataset,content,source,kind)
        if not source then
            report("invalid source for dataset %a",dataset)
            return
        end
        local current = datasets[dataset]
        local size = #content
        if size == 0 then
            report("empty source %a for dataset %a",source,current.name)
        else
            report("adding bib data to set %a from source %a",current.name,source)
        end
        statistics.starttiming(publications)
        publicationsstats.nofbytes = publicationsstats.nofbytes + size
        current.nofbytes = current.nofbytes + size
        current.nofcrossrefs = 0
        if source then
            table.insert(current.sources, { filename = source, checksum = md5.HEX(content) })
            current.loaded[source] = kind or true
        end
        local luadata = current.luadata
        current.newtags = #luadata > 0 and { } or current.newtags
        lpegmatch(bibtotable,content or "",1,current)
        if current.nofcrossrefs > 0 then
            for tag, entries in next, luadata do
                local value = entries.crossref
                if value then
                    local parent = luadata[value]
                    if parent == entries then
                        report_duplicates("bad parent %a for %a in dataset %s",value,hashtag,dataset.name)
                    elseif parent then
                        local t = { }
                        for k, v in next, parent do
                            if not entries[k] then
                                entries[k] = v
                                t[#t+1] = k
                            end
                        end
                        sort(t)
                        entries.inherited = concat(t,",")
                    else
                        report_duplicates("no valid parent %a for %a in dataset %s",value,hashtag,dataset.name)
                    end
                end
            end
        end
        statistics.stoptiming(publications)
    end

end

do

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

    function publications.converttoxml(dataset,nice,dontstore,usedonly,subset,noversion,rawtoo) -- we have fields !
        local current = datasets[dataset]
        local luadata = subset or (current and current.luadata)
        if luadata then
            statistics.starttiming(publications)
            --
            local result, r, n = { }, 0, 0
            if usedonly then
                usedonly = publications.usedentries()
                usedonly = usedonly[current.name]
            end
            --
            r = r + 1 ; result[r] = "<?xml version='1.0' standalone='yes'?>"
            r = r + 1 ; result[r] = formatters["<bibtex dataset='%s'>"](current.name)
            --
            if nice then -- will be default
                local f_entry_start = formatters[" <entry tag='%s' category='%s' index='%s'>"]
                local s_entry_stop  = " </entry>"
                local f_field       = formatters["  <field name='%s'>%s</field>"]
                local f_cdata       = formatters["  <field name='rawbibtex'><![CDATA[%s]]></field>"]

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
                        if rawtoo then
                            local s = publications.savers.bib(current,false,{ [tag] = entry })
                            s = utilities.strings.striplines(s,"prune and collapse")
                            r = r + 1 ; result[r] = f_cdata(s)
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
            result = concat(result,nice and "\n" or nil,noversion and 2 or 1,#result)
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

end

do

    local function resolvedname(dataset,filename)
        local current = datasets[dataset]
        if type(filename) ~= "string" then
            report("invalid filename %a",tostring(filename))
        end
        local fullname = resolvers.findfile(filename,"bib")
        if fullname == "" then
            fullname = resolvers.findfile(filename) -- let's not be too picky
        end
        if not fullname or fullname == "" then
            report("no file %a",filename)
            current.fullname = filename
            return current, false
        else
            current.fullname = fullname
            return current, fullname
        end
    end

    publications.resolvedname = resolvedname

    local cleaner = false
    local cleaned = false

    function loaders.registercleaner(what,fullname)
        if not fullname or fullname == "" then
            report("no %s file %a",what,fullname)
            return
        end
        local list = table.load(fullname)
        if not list then
            report("invalid %s file %a",what,fullname)
            return
        end
        list = list.replacements
        if not list then
            report("no replacement table in %a",fullname)
            return
        end
        if cleaned then
            report("adding replacements from %a",fullname)
            for k, v in next, list do
                cleaned[k] = v
            end
        else
            report("using replacements from %a",fullname)
            cleaned = list
        end
        cleaner = true
    end

    function loaders.bib(dataset,filename,kind)
        local dataset, fullname = resolvedname(dataset,filename)
        if not fullname then
            return
        end
        local data = io.loaddata(fullname) or ""
        if data == "" then
            report("empty file %a, nothing loaded",fullname)
            return
        end
        if cleaner == true then
            cleaner = Cs((lpeg.utfchartabletopattern(keys(cleaned)) / cleaned + p_utf8character)^1)
        end
        if cleaner ~= false then
            data = lpegmatch(cleaner,data)
        end
        if trace then
            report("loading file %a",fullname)
        end
        publications.loadbibdata(dataset,data,fullname,kind)
    end

    function loaders.lua(dataset,filename,loader) -- if filename is a table we load that one
        local current, data, fullname
        if type(filename) == "table" then
            current = datasets[dataset]
            data    = filename
        else
            dataset, fullname = resolvedname(dataset,filename)
            if not fullname then
                return
            end
            current = datasets[dataset]
            data    = (loader or table.load)(fullname)
        end
        if data then
            local luadata = current.luadata
            -- we want the same index each run
            for tag, entry in sortedhash(data) do
                if type(entry) == "table" then
                    entry.index  = getindex(current,luadata,tag)
                    entry.tag    = tag
                    luadata[tag] = entry -- no cleaning yet
                end
            end
        end
    end

    function loaders.json(dataset,filename)
        loaders.lua(dataset,filename,utilities.json.load)
    end

    function loaders.buffer(dataset,name) -- if filename is a table we load that one
        local current  = datasets[dataset]
        local barename = file.removesuffix(name)
        local data     = buffers.getcontent(barename) or ""
        if data == "" then
            report("empty buffer %a, nothing loaded",barename)
            return
        end
        if trace then
            report("loading buffer",barename)
        end
        publications.loadbibdata(current,data,barename,"bib")
    end

    function loaders.xml(dataset,filename)
        local dataset, fullname = resolvedname(dataset,filename)
        if not fullname then
            return
        end
        local current = datasets[dataset]
        local luadata = current.luadata
        local root    = xml.load(fullname)
        for bibentry in xmlcollected(root,"/bibtex/entry") do
            local attributes = bibentry.at
            local tag        = attributes.tag
            local entry      = {
                category = attributes.category,
                tag      = tag, -- afterwards also set, to prevent overload
                index    = 0,   -- prelocated
            }
            for field in xmlcollected(bibentry,"/field") do
                entry[field.at.name] = field.dt[1] -- no cleaning yet | xmltext(field)
            end
            entry.index  = getindex(current,luadata,tag)
            entry.tag    = tag
            luadata[tag] = entry
        end
    end

    setmetatableindex(loaders,function(t,filetype)
        local v = function(dataset,filename)
            report("no loader for file %a with filetype %a",filename,filetype)
        end
        t[filetype] = v
        return v
    end)

    local done = setmetatableindex("table")

    function publications.load(specification)
        local name     = specification.dataset or v_default
        local current  = datasets[name]
        local files    = settings_to_array(specification.filename)
        local kind     = specification.kind
        local dataspec = specification.specification
        statistics.starttiming(publications)
        local somedone = false
        for i=1,#files do
            local filetype, filename = string.splitup(files[i],"::")
            if not filename then
                filename = filetype
                filetype = file.suffix(filename)
            end
            if filename then
                if not filetype or filetype == "" then
                    filetype = "bib"
                end
                if file.suffix(filename) == "" then
                    file.addsuffix(filename,filetype)
                end
                if done[current][filename] then
                    report("file %a is already loaded in dataset %a",filename,name)
                else
                    loaders[filetype](current,filename)
                    done[current][filename] = true
                    somedone = true
                end
                if kind then
                    current.loaded[current.fullname or filename] = kind
                end
                if dataspec then
                    current.specifications[dataspec] = true
                end
            end
        end
        if somedone then
            local runner = enhancer.runner
            if runner then
                runner(current)
            end
        end
        statistics.stoptiming(publications)
        return current
    end

end

do

    function enhancers.order(dataset)
        local luadata = dataset.luadata
        local ordered = dataset.ordered
        for i=1,#ordered do
            local tag = ordered[i]
            if type(tag) == "string" then
                ordered[i] = luadata[tag]
            end
        end
    end

    function enhancers.details(dataset)
        local luadata = dataset.luadata
        local details = dataset.details
        for tag, entry in next, luadata do
            if not details[tag] then
                details[tag] = { }
            end
        end
    end

    utilities.sequencers.appendaction(enhancer,"system","publications.enhancers.order")
    utilities.sequencers.appendaction(enhancer,"system","publications.enhancers.details")

end

do

    local checked  = function(s,d) d[s] = (d[s] or 0) + 1 end
    local checktex = ( (1-P("\\"))^1 + P("\\") * ((C(R("az","AZ")^1)  * Carg(1))/checked))^0

    function publications.analyze(dataset)
        local current    = datasets[dataset]
        local data       = current.luadata
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
        current.analysis = {
            categories = categories,
            fields     = fields,
            commands   = commands,
        }
    end

end

function publications.tags(dataset)
    return sortedkeys(datasets[dataset].luadata)
end

function publications.sortedentries(dataset)
    return sortedhash(datasets[dataset].luadata)
end

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

do

    local savers = { }

    local s_preamble = [[
% this is an export from context mkiv

@preamble{
    \ifdefined\btxcmd
        % we're probably in context
    \else
        \def\btxcmd#1{\begincsname#1\endcsname}
    \fi
}

]]

    function savers.bib(dataset,filename,tobesaved)
        local f_start = formatters["@%s{%s,\n"]
        local f_field = formatters["  %s = {%s},\n"]
        local s_stop  = "}\n\n"
        local result  = { }
        local n, r = 0, 0
        for tag, data in sortedhash(tobesaved) do
            r = r + 1 ; result[r] = f_start(data.category or "article",tag)
            for key, value in sortedhash(data) do
                if not privates[key] then
                    r = r + 1 ; result[r] = f_field(key,value)
                end
            end
            r = r + 1 ; result[r] = s_stop
            n = n + 1
        end
        result = concat(result)
        if find(result,"\\btxcmd") then
            result = s_preamble .. result
        end
        if filename then
            report("%s entries from dataset %a saved in %a",n,dataset,filename)
            io.savedata(filename,result)
        else
            return result
        end
    end

    function savers.lua(dataset,filename,tobesaved)
        local list = { }
        local n = 0
        for tag, data in next, tobesaved do
            local t = { }
            for key, value in next, data do
                if not privates[key] then
                    d[key] = value
                end
            end
            list[tag] = t
            n = n + 1
        end
        report("%s entries from dataset %a saved in %a",n,dataset,filename)
        table.save(filename,list)
    end

    function savers.xml(dataset,filename,tobesaved,rawtoo)
        local result, n = publications.converttoxml(dataset,true,true,false,tobesaved,false,rawtoo)
        report("%s entries from dataset %a saved in %a",n,dataset,filename)
        io.savedata(filename,result)
    end

    function publications.save(specification)
        local dataset   = specification.dataset
        local filename  = specification.filename
        local filetype  = specification.filetype
        local criterium = specification.criterium
        statistics.starttiming(publications)
        if not filename or filename == "" then
            report("no filename for saving given")
            return
        end
        if not filetype or filetype == "" then
            filetype = file.suffix(filename)
        end
        if not criterium or criterium == "" then
            criterium = v_all
        end
        local saver = savers[filetype]
        if saver then
            local current   = datasets[dataset]
            local luadata   = current.luadata or { }
            local tobesaved = { }
            local result  = structures.lists.filter({criterium = criterium, names = "btx"}) or { }
            for i=1,#result do
                local userdata = result[i].userdata
                if userdata then
                    local set = userdata.btxset or v_default
                    if set == dataset then
                        local tag = userdata.btxref
                        if tag then
                            tobesaved[tag] = luadata[tag]
                        end
                    end
                end
            end
            saver(dataset,filename,tobesaved)
        else
            report("unknown format %a for saving %a",filetype,dataset)
        end
        statistics.stoptiming(publications)
        return dataset
    end

    publications.savers = savers

    if implement then

        implement {
            name      = "btxsavedataset",
            actions   = publications.save,
            arguments = {
                {
                    { "dataset" },
                    { "filename" },
                    { "filetype" },
                    { "criterium" },
                }
            }
        }

    end

end

-- casters

do

    publications.detailed = setmetatableindex(function(detailed,kind)
        local values = setmetatableindex(function(values,value)
            local caster = casters[kind]
            local cast   = caster and caster(value) or value
            values[value] = cast
            return cast
        end)
        detailed[kind] = values
        return values
    end)

    local keywordsplitter = utilities.parsers.groupedsplitat(";,")

    casters.keyword = function(str)
        return lpegmatch(keywordsplitter,str)
    end


    writers.keyword = function(k)
        if type(k) == "table" then
            return concat(p,";")
        else
            return k
        end
    end

    local pagessplitter = lpeg.splitat((
        P("-") + -- hyphen
        P("—") + -- U+2014
        P("–") + -- U+2013
        P("‒")   -- U+2012
    )^1)

    casters.range = function(str)
        local first, last = lpegmatch(pagessplitter,str)
        return first and last and { first, last } or str
    end

    writers.range = function(p)
        if type(p) == "table" then
            return concat(p,"-")
        else
            return p
        end
    end

    casters.pagenumber = casters.range
    writers.pagenumber = writers.range

end

if implement then

    implement {
        name      = "btxshortcut",
        arguments = "2 strings",
        actions   = function(instance,key)
            local d = publications.datasets[instance]
            context(d and d.shortcuts[key] or "?")
        end,
    }

end

-- inspect(publications.load { filename = "e:/tmp/oeps.bib" })
