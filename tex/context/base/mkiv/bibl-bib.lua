if not modules then modules = { } end modules ['bibl-bib'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This is a prelude to integrated bibliography support. This file just loads
bibtex files and converts them to xml so that the we access the content
in a convenient way. Actually handling the data takes place elsewhere.</p>
--ldx]]--

local lower, format, gsub, concat = string.lower, string.format, string.gsub, table.concat
local next = next
local utfchar = utf.char
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local textoutf = characters and characters.tex.toutf
local variables = interfaces and interfaces.variables
local settings_to_hash = utilities.parsers.settings_to_hash
local finalizers = xml.finalizers.tex
local xmlfilter, xmltext, getid = xml.filter, xml.text, lxml.getid
local formatters = string.formatters

local P, R, S, C, Cc, Cs, Ct = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct

local trace_bibxml = false  trackers.register("publications.bibxml", function(v) trace_bibtex = v end)

local report_xml = logs.reporter("publications","xml")

bibtex       = bibtex or { }
local bibtex = bibtex

bibtex.statistics = bibtex.statistics or { }
local bibtexstats = bibtex.statistics

bibtexstats.nofbytes       = 0
bibtexstats.nofdefinitions = 0
bibtexstats.nofshortcuts   = 0

local defaultshortcuts = {
    jan = "1",
    feb = "2",
    mar = "3",
    apr = "4",
    may = "5",
    jun = "6",
    jul = "7",
    aug = "8",
    sep = "9",
    oct = "10",
    nov = "11",
    dec = "12",
}

local shortcuts = { }
local data = { }
local entries

-- Currently we expand shortcuts and for large ones (like the acknowledgements
-- in tugboat.bib this is not that efficient. However, eventually strings get
-- hashed again.

local function do_shortcut(tag,key,value)
    bibtexstats.nofshortcuts = bibtexstats.nofshortcuts + 1
    if lower(tag) == "@string" then
        shortcuts[key] = value
    end
end

local function do_definition(tag,key,tab) -- maybe check entries here (saves memory)
    if not entries or entries[key] then
        bibtexstats.nofdefinitions = bibtexstats.nofdefinitions + 1
        local t = { }
        for i=1,#tab,2 do
            t[tab[i]] = tab[i+1]
        end
        local p = data[tag]
        if not p then
            data[tag] = { [key] = t }
        else
            p[key] = t
        end
    end
end

local function resolve(s)
    return shortcuts[s] or defaultshortcuts[s] or s -- can be number
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
local space      = S(" \t\n\r\f")
local spacing    = space^0
local equal      = P("=")
local collapsed  = (space^1)/ " "

----- function add(a,b) if b then return a..b else return a end end

local keyword    = C((R("az","AZ","09") + S("@_:-"))^1)  -- C((1-space)^1)
local s_quoted   = ((escape*single) + collapsed + (1-single))^0
local d_quoted   = ((escape*double) + collapsed + (1-double))^0
local balanced   = lpegpatterns.balanced

local s_value    = (single/"") * s_quoted * (single/"")
local d_value    = (double/"") * d_quoted * (double/"")
local b_value    = (left  /"") * balanced * (right /"")
local r_value    = keyword/resolve

local somevalue  = s_value + d_value + b_value + r_value
local value      = Cs((somevalue * ((spacing * hash * spacing)/"" * somevalue)^0))

local assignment = spacing * keyword * spacing * equal * spacing * value * spacing
local shortcut   = keyword * spacing * left * spacing * (assignment * comma^0)^0 * spacing * right
local definition = keyword * spacing * left * spacing * keyword * comma * Ct((assignment * comma^0)^0) * spacing * right
local comment    = keyword * spacing * left * (1-right)^0 * spacing * right
local forget     = percent^1 * (1-lineending)^0

-- todo \%

local grammar = (space + forget + shortcut/do_shortcut + definition/do_definition + comment + 1)^0

function bibtex.convert(session,content)
    statistics.starttiming(bibtex)
    data, shortcuts, entries = session.data, session.shortcuts, session.entries
    bibtexstats.nofbytes = bibtexstats.nofbytes + #content
    session.nofbytes = session.nofbytes + #content
    lpegmatch(grammar,content or "")
    statistics.stoptiming(bibtex)
end

function bibtex.load(session,filename)
    statistics.starttiming(bibtex)
    local filename = resolvers.findfile(filename,"bib")
    if filename ~= "" then
        local data = io.loaddata(filename) or ""
        if data == "" then
            report_xml("empty file %a, no conversion to xml",filename)
        elseif trace_bibxml then
            report_xml("converting file %a to xml",filename)
        end
        bibtex.convert(session,data)
    end
    statistics.stoptiming(bibtex)
end

function bibtex.new()
    return {
        data      = { },
        shortcuts = { },
        xml       = xml.convert("<?xml version='1.0' standalone='yes'?>\n<bibtex></bibtex>"),
        nofbytes  = 0,
        entries   = nil,
        loaded    = false,
    }
end

local p_escaped = lpegpatterns.xml.escaped

local ihatethis = {
    f = "\\f",
    n = "\\n",
    r = "\\r",
    s = "\\s",
    t = "\\t",
    v = "\\v",
    z = "\\z",
}

local command = P("\\")/"" * Cc("\\bibtexcommand{") * (R("az","AZ")^1) * Cc("}")
local any     = P(1)
local done    = P(-1)
local one_l   = P("{")  / ""
local one_r   = P("}")  / ""
local two_l   = P("{{") / ""
local two_r   = P("}}") / ""

local filter = Cs(
    two_l * (command + any - two_r - done)^0 * two_r * done +
    one_l * (command + any - one_r - done)^0 * one_r * done +
            (command + any               )^0
)

function bibtex.toxml(session,options)
    if session.loaded then
        return
    else
        session.loaded = true
    end
    -- we can always speed this up if needed
    -- format slows down things a bit but who cares
    statistics.starttiming(bibtex)
    local result, r = { }, 0
    local options = settings_to_hash(options)
    local convert = options.convert -- todo: interface
    local strip = options.strip -- todo: interface
    local entries = session.entries
    r = r + 1 ; result[r] = "<?xml version='1.0' standalone='yes'?>"
    r = r + 1 ; result[r] = "<bibtex>"
    for id, categories in next, session.data do
        id = lower(gsub(id,"^@",""))
        for name, entry in next, categories do
            if not entries or entries[name] then
                r = r + 1 ; result[r] = formatters["<entry tag='%s' category='%s'>"](lower(name),id)
                for key, value in next, entry do
                    value = gsub(value,"\\(.)",ihatethis) -- this really needs checking
                    value = lpegmatch(p_escaped,value)
                    if value ~= "" then
                        if convert then
                            value = textoutf(value,true)
                        end
                        if strip then
                            -- as there is no proper namespace in bibtex we need this
                            -- kind of hackery ... bibtex databases are quite unportable
                            value = lpegmatch(filter,value) or value
                        end
                        r = r + 1 ; result[r] = formatters[" <field name='%s'>%s</field>"](key,value)
                    end
                end
                r = r + 1 ; result[r] = "</entry>"
            end
        end
    end
    r = r + 1 ; result[r] = "</bibtex>"
    result = concat(result,"\n")
    -- alternatively we could use lxml.convert
    session.xml = xml.convert(result, {
        resolve_entities            = true,
        resolve_predefined_entities = true, -- in case we have escaped entities
     -- unify_predefined_entities   = true, -- &#038; -> &amp;
        utfize_entities             = true,
    } )
    session.data = nil
    session.shortcuts = nil
    statistics.stoptiming(bibtex)
end

statistics.register("bibtex load time", function()
    local nofbytes = bibtexstats.nofbytes
    if nofbytes > 0 then
        return format("%s seconds, %s bytes, %s definitions, %s shortcuts",
            statistics.elapsedtime(bibtex),nofbytes,bibtexstats.nofdefinitions,bibtexstats.nofshortcuts)
    else
        return nil
    end
end)

--~ str = [[
--~     @COMMENT { CRAP }
--~     @STRING{ hans = "h a n s" }
--~     @STRING{ taco = "t a c o" }
--~     @SOMETHING{ key1, abc = "t a c o" , def = "h a n s" }
--~     @SOMETHING{ key2, abc = hans # taco }
--~     @SOMETHING{ key3, abc = "hans" # taco }
--~     @SOMETHING{ key4, abc = hans # "taco" }
--~     @SOMETHING{ key5, abc = hans # taco # "hans" # "taco"}
--~     @SOMETHING{ key6, abc =  {oeps {oeps} oeps} }
--~ ]]

--~ local session = bibtex.new()
--~ bibtex.convert(session,str)
--~ bibtex.toxml(session)
--~ print(session.nofbytes,statistics.elapsedtime(bibtex))

--~ local session = bibtex.new()
--~ bibtex.load(session,"IEEEabrv.bib")
--~ bibtex.load(session,"IEEEfull.bib")
--~ bibtex.load(session,"IEEEexample.bib")
--~ bibtex.toxml(session)
--~ print(session.nofbytes,statistics.elapsedtime(bibtex))

--~ local session = bibtex.new()
--~ bibtex.load(session,"gut.bib")
--~ bibtex.load(session,"komoedie.bib")
--~ bibtex.load(session,"texbook1.bib")
--~ bibtex.load(session,"texbook2.bib")
--~ bibtex.load(session,"texbook3.bib")
--~ bibtex.load(session,"texgraph.bib")
--~ bibtex.load(session,"texjourn.bib")
--~ bibtex.load(session,"texnique.bib")
--~ bibtex.load(session,"tugboat.bib")
--~ bibtex.toxml(session)
--~ print(session.nofbytes,statistics.elapsedtime(bibtex))

--~ print(table.serialize(session.data))
--~ print(table.serialize(session.shortcuts))
--~ print(xml.serialize(session.xml))

if not characters then dofile(resolvers.findfile("char-def.lua")) end

local chardata = characters.data
local concat = table.concat

local lpeg = lpeg

local P, Ct, lpegmatch, lpegpatterns = lpeg.P, lpeg.Ct, lpeg.match, lpeg.patterns

local space, comma = P(" "), P(",")

local andsplitter    = lpeg.tsplitat(space^1 * "and" * space^1)
local commasplitter  = lpeg.tsplitat(space^0 * comma * space^0)
local spacesplitter  = lpeg.tsplitat(space^1)
local firstcharacter = lpegpatterns.utf8byte

local function is_upper(str)
    local first = lpegmatch(firstcharacter,str)
    local okay = chardata[first]
    return okay and okay.category == "lu"
end

local function splitauthors(str)
    local authors = lpegmatch(andsplitter,str)
    for i=1,#authors do
        local firstnames, vons, surnames, initials, juniors, words
        local author = authors[i]
        local split = lpegmatch(commasplitter,author)
        local n = #split
        if n == 1 then
            --~ First von Last
            words = lpegmatch(spacesplitter,author)
            firstnames, vons, surnames = { }, { }, { }
            local i, n = 1, #words
            while i <= n do
                local w = words[i]
                if is_upper(w) then
                    firstnames[#firstnames+1], i = w, i + 1
                else
                    break
                end
            end
            while i <= n do
                local w = words[i]
                if is_upper(w) then
                    break
                else
                    vons[#vons+1], i = w, i + 1
                end
            end
            while i <= n do
                surnames[#surnames+1], i = words[i], i + 1
            end
        elseif n == 2 then
            --~ von Last, First
            words    = lpegmatch(spacesplitter,split[2])
            surnames = lpegmatch(spacesplitter,split[1])
            firstnames, vons = { }, { }
            local i, n = 1, #words
            while i <= n do
                local w = words[i]
                if is_upper(w) then
                    firstnames[#firstnames+1], i = w, i + 1
                else
                    break
                end
            end
            while i <= n do
                vons[#vons+1], i = words[i], i + 1
            end
        else
            --~ von Last, Jr ,First
            firstnames = lpegmatch(spacesplitter,split[1])
            juniors    = lpegmatch(spacesplitter,split[2])
            surnames   = lpegmatch(spacesplitter,split[3])
            if n > 3 then
                -- error
            end
        end
        if #surnames == 0 then
            surnames[1] = firstnames[#firstnames]
            firstnames[#firstnames] = nil
        end
        if firstnames then
            initials = { }
            for i=1,#firstnames do
                initials[i] = utfchar(lpegmatch(firstcharacter,firstnames[i]))
            end
        end
        authors[i] = {
            original   = author,
            firstnames = firstnames,
            vons       = vons,
            surnames   = surnames,
            initials   = initials,
            juniors    = juniors,
        }
    end
    authors.original = str
    return authors
end

local function the_initials(initials,symbol)
    local t, symbol = { }, symbol or "."
    for i=1,#initials do
        t[i] = initials[i] .. symbol
    end
    return t
end

-- authors

bibtex.authors = bibtex.authors or { }

local authors = bibtex.authors

local defaultsettings = {
    firstnamesep        = " ",
    vonsep              = " ",
    surnamesep          = " ",
    juniorsep           = " ",
    surnamejuniorsep    = ", ",
    juniorjuniorsep     = ", ",
    surnamefirstnamesep = ", ",
    surnameinitialsep   = ", ",
    namesep             = ", ",
    lastnamesep         = " and ",
    finalnamesep        = " and ",
}

function authors.normal(author,settings)
    local firstnames, vons, surnames, juniors = author.firstnames, author.vons, author.surnames, author.juniors
    local result, settings = { }, settings or defaultsettings
    if firstnames and #firstnames > 0 then
        result[#result+1] = concat(firstnames," ")
        result[#result+1] = settings.firstnamesep or defaultsettings.firstnamesep
    end
    if vons and #vons > 0 then
        result[#result+1] = concat(vons," ")
        result[#result+1] = settings.vonsep or defaultsettings.vonsep
    end
    if surnames then
        result[#result+1] = concat(surnames," ")
    end
    if juniors and #juniors > 0 then
        result[#result+1] = concat(juniors," ")
        result[#result+1] = settings.surnamesep or defaultsettings.surnamesep
    end
    return concat(result)
end

function authors.normalshort(author,settings)
    local firstnames, vons, surnames, juniors = author.firstnames, author.vons, author.surnames, author.juniors
    local result, settings = { }, settings or defaultsettings
    if firstnames and #firstnames > 0 then
        result[#result+1] = concat(firstnames," ")
        result[#result+1] = settings.firstnamesep or defaultsettings.firstnamesep
    end
    if vons and #vons > 0 then
        result[#result+1] = concat(vons," ")
        result[#result+1] = settings.vonsep or defaultsettings.vonsep
    end
    if surnames then
        result[#result+1] = concat(surnames," ")
    end
    if juniors and #juniors > 0 then
        result[#result+1] = concat(juniors," ")
        result[#result+1] = settings.surnamejuniorsep or defaultsettings.surnamejuniorsep
    end
    return concat(result)
end

function authors.inverted(author,settings)
    local firstnames, vons, surnames, juniors = author.firstnames, author.vons, author.surnames, author.juniors
    local result, settings = { }, settings or defaultsettings
    if vons and #vons > 0 then
        result[#result+1] = concat(vons," ")
        result[#result+1] = settings.vonsep or defaultsettings.vonsep
    end
    if surnames then
        result[#result+1] = concat(surnames," ")
    end
    if juniors and #juniors > 0 then
        result[#result+1] = settings.juniorjuniorsep or defaultsettings.juniorjuniorsep
        result[#result+1] = concat(juniors," ")
    end
    if firstnames and #firstnames > 0 then
        result[#result+1] = settings.surnamefirstnamesep or defaultsettings.surnamefirstnamesep
        result[#result+1] = concat(firstnames," ")
    end
    return concat(result)
end

function authors.invertedshort(author,settings)
    local vons, surnames, initials, juniors = author.vons, author.surnames, author.initials, author.juniors
    local result, settings = { }, settings or defaultsettings
    if vons and #vons > 0 then
        result[#result+1] = concat(vons," ")
        result[#result+1] = settings.vonsep or defaultsettings.vonsep
    end
    if surnames then
        result[#result+1] = concat(surnames," ")
    end
    if juniors and #juniors > 0 then
        result[#result+1] = settings.juniorjuniorsep or defaultsettings.juniorjuniorsep
        result[#result+1] = concat(juniors," ")
    end
    if initials and #initials > 0 then
        result[#result+1] = settings.surnameinitialsep or defaultsettings.surnameinitialsep
        result[#result+1] = concat(the_initials(initials)," ")
    end
    return concat(result)
end

local lastconcatsize = 1

local function bibtexconcat(t,settings)
    local namesep      = settings.namesep      or defaultsettings.namesep      or ", "
    local lastnamesep  = settings.lastnamesep  or defaultsettings.lastnamesep  or namesep
    local finalnamesep = settings.finalnamesep or defaultsettings.finalnamesep or lastnamesep
    local lastconcatsize = #t
    if lastconcatsize > 2 then
        local s = { }
        for i=1,lastconcatsize-2 do
            s[i] = t[i] .. namesep
        end
        s[lastconcatsize-1], s[lastconcatsize] = t[lastconcatsize-1] .. finalnamesep, t[lastconcatsize]
        return concat(s)
    elseif lastconcatsize > 1 then
        return concat(t,lastnamesep)
    elseif lastconcatsize > 0 then
        return t[1]
    else
        return ""
    end
end

function authors.concat(author,combiner,what,settings)
    if type(combiner) == "string" then
        combiner = authors[combiner or "normal"] or authors.normal
    end
    local split = splitauthors(author)
    local setting = settings[what]
    local etallimit, etaldisplay, etaltext = 1000, 1000, ""
    if setting then
        etallimit   = settings.etallimit   or 1000
        etaldisplay = settings.etaldisplay or etallimit
        etalltext   = settings.etaltext    or ""
    end
    local max = #split
    if max > etallimit and etaldisplay < max then
        max = etaldisplay
    end
    for i=1,max do
        split[i] = combiner(split[i],settings)
    end
    local result = bibtexconcat(split,settings)
    if max < #split then
        return result
    else
        return result .. etaltext
    end
end

function authors.short(author,year)
    local result = { }
    if author then
        local authors = splitauthors(author)
        for a=1,#authors do
            local aa = authors[a]
            local initials = aa.initials
            for i=1,#initials do
                result[#result+1] = initials[i]
            end
            local surnames = aa.surnames
            for s=1,#surnames do
                result[#result+1] = utfchar(lpegmatch(firstcharacter,surnames[s]))
            end
        end
    end
    if year then
        result[#result+1] = year
    end
    return concat(result)
end

-- We can consider creating a hashtable key -> entry but I wonder if
-- pays off.

local function collectauthoryears(id,list)
    list = settings_to_hash(list)
    id = getid(id)
    local found = { }
    for e in xml.collected(id,"/bibtex/entry") do
        if list[e.at.tag] then
            local year   = xmlfilter(e,"xml:///field[@name='year']/text()")
            local author = xmlfilter(e,"xml:///field[@name='author']/text()")
            if author and year then
                local a = found[author]
                if not a then
                    a = { }
                    found[author] = a
                end
                local y = a[year]
                if not y then
                    y = { }
                    a[year] = y
                end
                y[#y+1] = e
            end
        end
    end
    -- found = { author = { year_1 = { e1, e2, e3 } } }
    local done = { }
    for author, years in next, found do
        local yrs = { }
        for year, entries in next, years do
            if subyears then
             -- -- add letters to all entries of an author and if so shouldn't
             -- -- we tag all years of an author as soon as we do this?
             -- if #entries > 1 then
             --     for i=1,#years do
             --         local entry = years[i]
             --         -- years[i] = year .. string.char(i + string.byte("0") - 1)
             --     end
             -- end
            else
                yrs[#yrs+1] = year
            end
        end
        done[author] = yrs
    end
    return done
end

local method, settings = "normal", { }

function authors.setsettings(s)
    settings = s or settings
end

if commands then

    local sessions = { }

    function commands.definebibtexsession(name)
        sessions[name] = bibtex.new()
    end

    function commands.preparebibtexsession(name,xmlname,options)
        bibtex.toxml(sessions[name],options)
        lxml.register(xmlname,sessions[name].xml)
    end

    function commands.registerbibtexfile(name,filename)
        bibtex.load(sessions[name],filename)
    end

    function commands.registerbibtexentry(name,entry)
        local session = sessions[name]
        local entries = session.entries
        if not entries then
            session.entries = { [entry] = true } -- here we can keep more info
        else
            entries[entry] = true
        end
    end

    -- commands.bibtexconcat = bibtexconcat

    -- finalizers can be rather dumb as we have just text and no embedded xml

    function finalizers.bibtexconcat(collected,method,what)
        if collected then
            local author = collected[1].dt[1] or ""
            if author ~= "" then
                context(authors.concat(author,method,what,settings))
            end
        end
    end

    function finalizers.bibtexshort(collected)
        if collected then
            local c = collected[1]
            local year   = xmlfilter(c,"xml://field[@name='year']/text()")
            local author = xmlfilter(c,"xml://field[@name='author']/text()")
            context(authors.short(author,year))
        end
    end

    -- experiment:

    --~ -- alternative approach: keep data at the tex end

    --~ local function xbibtexconcat(t,sep,finalsep,lastsep)
    --~     local n = #t
    --~     if n > 0 then
    --~         context(t[1])
    --~         if n > 1 then
    --~             if n > 2 then
    --~                 for i=2,n-1 do
    --~                     context.bibtexpublicationsparameter("sep")
    --~                     context(t[i])
    --~                 end
    --~                 context.bibtexpublicationsparameter("finalsep")
    --~             else
    --~                 context.bibtexpublicationsparameter("lastsep")
    --~             end
    --~             context(t[n])
    --~         end
    --~     end
    --~ end

    -- todo : sort

    -- todo: choose between bibtex or commands namespace

    function bibtex.authorref(id,list)
        local result = collectauthoryears(id,list,method,what)
        for author, years in next, result do
            context(authors.concat(author,method,what,settings))
        end
    end

    function bibtex.authoryearref(id,list)
        local result = collectauthoryears(id,list,method,what)
        for author, years in next, result do
            context("%s (%s)",authors.concat(author,method,what,settings),concat(years,", "))
        end
    end

    function bibtex.authoryearsref(id,list)
        local result = collectauthoryears(id,list,method,what)
        for author, years in next, result do
            context("(%s, %s)",authors.concat(author,method,what,settings),concat(years,", "))
        end
    end

    function bibtex.singularorplural(singular,plural)
        if lastconcatsize and lastconcatsize > 1 then
            context(plural)
        else
            context(singular)
        end
    end

end


--~ local function test(sample)
--~     local authors = splitauthors(sample)
--~     print(table.serialize(authors))
--~     for i=1,#authors do
--~         local author = authors[i]
--~         print(normalauthor       (author,settings))
--~         print(normalshortauthor  (author,settings))
--~         print(invertedauthor     (author,settings))
--~         print(invertedshortauthor(author,settings))
--~     end
--~     print(concatauthors(sample,settings,normalauthor))
--~     print(concatauthors(sample,settings,normalshortauthor))
--~     print(concatauthors(sample,settings,invertedauthor))
--~     print(concatauthors(sample,settings,invertedshortauthor))
--~ end

--~ local sample_a = "Hagen, Hans and Hoekwater, Taco Whoever T. Ex. and Henkel Hut, Hartmut Harald von der"
--~ local sample_b = "Hans Hagen  and Taco Whoever T. Ex. Hoekwater  and Hartmut Harald von der Henkel Hut"

--~ test(sample_a)
--~ test(sample_b)
