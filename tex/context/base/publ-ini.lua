if not modules then modules = { } end modules ['publ-ini'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- for the moment here

local lpegmatch  = lpeg.match
local P, C, Ct, Cs = lpeg.P, lpeg.C, lpeg.Ct, lpeg.Cs

local lpegmatch  = lpeg.match
local pattern    = Cs((1 - P(1) * P(-1))^0 * (P(".")/"" + P(1)))

local manipulators = {
    stripperiod = function(str) return lpegmatch(pattern,str) end,
    uppercase   = characters.upper,
    lowercase   = characters.lower,
}

local manipulation = C((1-P("->"))^1) * P("->") * C(P(1)^0)

local pattern = manipulation / function(operation,str)
    local manipulator = manipulators[operation]
    return manipulator and manipulator(str) or str
end

local function manipulated(str)
    return lpegmatch(pattern,str) or str
end

utilities.parsers.manipulation = manipulation
utilities.parsers.manipulators = manipulators
utilities.parsers.manipulated  = manipulated

function commands.manipulated(str)
    context(manipulated(str))
end

-- use: for rest in gmatch(reference,"[^, ]+") do

local next, rawget, type = next, rawget, type
local match, gmatch, format, gsub = string.match, string.gmatch, string.format, string.gsub
local concat, sort = table.concat, table.sort
local utfsub = utf.sub
local formatters = string.formatters
local allocate = utilities.storage.allocate
local settings_to_array, settings_to_set = utilities.parsers.settings_to_array, utilities.parsers.settings_to_set
local sortedkeys, sortedhash = table.sortedkeys, table.sortedhash
local lpegmatch = lpeg.match
local P, C, Ct = lpeg.P, lpeg.C, lpeg.Ct

local report         = logs.reporter("publications")
local trace          = false  trackers.register("publications", function(v) trace = v end)

local datasets       = publications.datasets

local variables      = interfaces.variables

local v_local        = variables["local"]
local v_global       = variables["global"]

local v_force        = variables.force
local v_standard     = variables.standard
local v_start        = variables.start
local v_none         = variables.none
local v_left         = variables.left
local v_right        = variables.right
local v_middle       = variables.middle
local v_inbetween    = variables.inbetween

local v_short        = variables.short
local v_cite         = variables.cite
local v_default      = variables.default
local v_reference    = variables.reference
local v_dataset      = variables.dataset
local v_author       = variables.author or "author"
local v_editor       = variables.editor or "editor"

local numbertochar   = converters.characters

local logsnewline    = logs.newline
local logspushtarget = logs.pushtarget
local logspoptarget  = logs.poptarget
local csname_id      = token.csname_id

local basicsorter    = sorters.basicsorter -- (a,b)
local sortcomparer   = sorters.comparers.basic -- (a,b)
local sortstripper   = sorters.strip
local sortsplitter   = sorters.splitters.utf

local context                     = context

local ctx_btxlistparameter        = context.btxlistparameter
local ctx_btxcitevariantparameter = context.btxcitevariantparameter
local ctx_btxlistvariantparameter = context.btxlistvariantparameter
local ctx_btxdomarkcitation       = context.btxdomarkcitation
local ctx_setvalue                = context.setvalue
local ctx_firstoftwoarguments     = context.firstoftwoarguments
local ctx_secondoftwoarguments    = context.secondoftwoarguments
local ctx_firstofoneargument      = context.firstofoneargument
local ctx_gobbleoneargument       = context.gobbleoneargument
local ctx_btxdirectlink           = context.btxdirectlink
local ctx_btxhandlelistentry      = context.btxhandlelistentry
local ctx_btxchecklistentry       = context.btxchecklistentry
local ctx_dodirectfullreference   = context.dodirectfullreference
local ctx_directsetup             = context.directsetup

statistics.register("publications load time", function()
    local publicationsstats = publications.statistics
    local nofbytes = publicationsstats.nofbytes
    if nofbytes > 0 then
        return string.format("%s seconds, %s bytes, %s definitions, %s shortcuts",
            statistics.elapsedtime(publications),nofbytes,publicationsstats.nofdefinitions,publicationsstats.nofshortcuts)
    else
        return nil
    end
end)

luatex.registerstopactions(function()
    local done = false
    local undefined = csname_id("undefined*crap")
    for name, dataset in sortedhash(datasets) do
        for command, n in sortedhash(dataset.commands) do
            if not done then
                logspushtarget("logfile")
                logsnewline()
                report("start used btx commands")
                logsnewline()
                done = true
            end
            local c = csname_id(command)
            if c and c ~= undefined then
                report("%-20s %-20s % 5i %s",name,command,n,"known")
            else
                local u = csname_id(utf.upper(command))
                if u and u ~= undefined then
                    report("%-20s %-20s % 5i %s",name,command,n,"KNOWN")
                else
                    report("%-20s %-20s % 5i %s",name,command,n,"unknown")
                end
            end
        end
    end
    if done then
        logsnewline()
        report("stop used btx commands")
        logsnewline()
        logspoptarget()
    end
end)

-- multipass, we need to sort because hashing is random per run and not per
-- version (not the best changed feature of lua)

local collected = allocate()
local tobesaved = allocate()

-- we use a a dedicated (and efficient as it know what it deals with) serializer,
-- also because we need to ignore the 'details' field

local function serialize(t)
    local f_key_table  = formatters[" [%q] = {"]
    local f_key_string = formatters["  %s = %q,"]
    local r = { "return {" }
    local m = 1
    for tag, entry in sortedhash(t) do
        m = m + 1
        r[m] = f_key_table(tag)
        local s = sortedkeys(entry)
        for i=1,#s do
            local k = s[i]
         -- if k ~= "details" then
                m = m + 1
                r[m] = f_key_string(k,entry[k])
         -- end
        end
        m = m + 1
        r[m] = " },"
    end
    r[m] = "}"
    return concat(r,"\n")
end

local function finalizer()
    local prefix = tex.jobname -- or environment.jobname
    local setnames = sortedkeys(datasets)
    for i=1,#setnames do
        local name     = setnames[i]
        local dataset  = datasets[name]
        local userdata = dataset.userdata
        local checksum = nil
        local username = file.addsuffix(file.robustname(formatters["%s-btx-%s"](prefix,name)),"lua")
        if userdata and next(userdata) then
            if job.passes.first then
                local newdata = serialize(userdata)
                checksum = md5.HEX(newdata)
                io.savedata(username,newdata)
            end
        else
            os.remove(username)
            username = nil
        end
        local loaded = dataset.loaded
        local sources = dataset.sources
        local used   = { }
        for i=1,#sources do
            local source = sources[i]
            if loaded[source.filename] ~= "previous" then -- or loaded[source.filename] == "current"
                used[#used+1] = source
            end
        end
        tobesaved[name] = {
            usersource = {
                filename = username,
                checksum = checksum,
            },
            datasources = used,
        }
    end
end

local function initializer()
    statistics.starttiming(publications)
collected = publications.collected or collected -- for the moment as we load runtime
    for name, state in next, collected do
        local dataset     = datasets[name]
        local datasources = state.datasources
        local usersource  = state.usersource
        if datasources then
            for i=1,#datasources do
                local filename = datasources[i].filename
                publications.load(dataset,filename,"previous")
            end
        end
        if usersource then
            dataset.userdata = table.load(usersource.filename) or { }
        end
    end
    statistics.stoptiming(publications)
    function initializer() end -- will go, for now, runtime loaded
end

job.register('publications.collected',tobesaved,initializer,finalizer)

if not publications.authors then
    initializer() -- for now, runtime loaded
end

-- basic access

local function getfield(dataset,tag,name)
    local d = datasets[dataset].luadata[tag]
    return d and d[name]
end

local function getdetail(dataset,tag,name)
    local d = datasets[dataset].details[tag]
    return d and d[name]
end

function commands.btxsingularorplural(dataset,tag,name) -- todo: make field dependent
    local d = datasets[dataset].details[tag]
    if d then
        d = d[name]
    end
    if d then
        d = #d <= 1
    end
    commands.doifelse(d)
end

-- basic loading

function commands.usebtxdataset(name,filename)
    publications.load(datasets[name],filename,"current")
end

function commands.convertbtxdatasettoxml(name,nice)
    publications.converttoxml(datasets[name],nice)
end

-- enhancing

local splitauthorstring = publications.authors.splitstring

local pagessplitter = lpeg.splitat(P("-")^1)

-- maybe not redo when already done

function publications.enhance(dataset) -- for the moment split runs (maybe publications.enhancers)
    statistics.starttiming(publications)
    if type(dataset) == "string" then
        dataset = datasets[dataset]
    end
    local luadata = dataset.luadata
    local details = dataset.details
    -- author, editor
    for tag, entry in next, luadata do
        local author = entry.author
        local editor = entry.editor
        details[tag] = {
            author = author and splitauthorstring(author),
            editor = editor and splitauthorstring(editor),
        }
    end
    -- short
    local shorts = { }
    for tag, entry in next, luadata do
        local author = details[tag].author
        if author then
            -- number depends on sort order
            local t = { }
            if #author == 0 then
                -- what
            else
                local n = #author == 1 and 3 or 1
                for i=1,#author do
                    local surnames = author[i].surnames
                    if not surnames or #surnames == 0 then
                        -- error
                    else
                        t[#t+1] = utfsub(surnames[1],1,n)
                    end
                end
            end
            local year = tonumber(entry.year) or 0
            local short = formatters["%t%02i"](t,math.mod(year,100))
            local s = shorts[short]
            if not s then
                shorts[short] = tag
            elseif type(s) == "string" then
                shorts[short] = { s, tag }
            else
                s[#s+1] = tag
            end
        else
            --
        end
    end
    for short, tags in next, shorts do
        if type(tags) == "table" then
            sort(tags)
            for i=1,#tags do
--                 details[tags[i]].short = short .. numbertochar(i)
local detail = details[tags[i]]
detail.short  = short
detail.suffix = numbertochar(i)
            end
        else
            details[tags].short = short
        end
    end
    -- pages
    for tag, entry in next, luadata do
        local pages = entry.pages
        if pages then
            local first, last = lpegmatch(pagessplitter,pages)
            details[tag].pages = first and last and { first, last } or pages
        end
    end
    -- keywords
    for tag, entry in next, luadata do
        local keyword = entry.keyword
        if keyword then
            details[tag].keyword = settings_to_set(keyword)
        end
    end
    statistics.stoptiming(publications)
end

function commands.addbtxentry(name,settings,content)
    local dataset = datasets[name]
    if dataset then
        publications.addtexentry(dataset,settings,content)
    end
end

function commands.setbtxdataset(name)
    local dataset = rawget(datasets,name)
    if dataset then
        context(name)
    else
        report("unknown dataset %a",name)
    end
end

function commands.setbtxentry(name,tag)
    local dataset = rawget(datasets,name)
    if dataset then
        if dataset.luadata[tag] then
            context(tag)
        else
            report("unknown tag %a in dataset %a",tag,name)
        end
    else
        report("unknown dataset %a",name)
    end
end

-- rendering of fields (maybe multiple manipulators)

local manipulation = utilities.parsers.manipulation
local manipulators = utilities.parsers.manipulators

-- local function checked(field)
--     local m, f = lpegmatch(manipulation,field)
--     if m then
--         return manipulators[m], f or field
--     else
--         return nil, field
--     end
-- end

local manipulation = Ct((C((1-P("->"))^1) * P("->"))^1) * C(P(1)^0)

local function checked(field)
    local m, f = lpegmatch(manipulation,field)
    if m then
        return m, f or field
    else
        return nil, field
    end
end

local function manipulated(actions,str)
    for i=1,#actions do
        local action = manipulators[actions[i]]
        if action then
            str = action(str) or str
        end
    end
    return str
end

function commands.btxflush(name,tag,field)
    local dataset = rawget(datasets,name)
    if dataset then
        local fields = dataset.luadata[tag]
        if fields then
            local manipulator, field = checked(field)
            local value = fields[field]
            if type(value) == "string" then
             -- context(manipulator and manipulator(value) or value)
                context(manipulator and manipulated(manipulator,value) or value)
                return
            end
            local details = dataset.details[tag]
            if details then
                local value = details[field]
                if type(value) == "string" then
                 -- context(manipulator and manipulator(value) or value)
                    context(manipulator and manipulated(manipulator,value) or value)
                    return
                end
            end
            report("unknown field %a of tag %a in dataset %a",field,tag,name)
        else
            report("unknown tag %a in dataset %a",tag,name)
        end
    else
        report("unknown dataset %a",name)
    end
end

function commands.btxdetail(name,tag,field)
    local dataset = rawget(datasets,name)
    if dataset then
        local details = dataset.details[tag]
        if details then
            local manipulator, field = checked(field)
            local value = details[field]
            if type(value) == "string" then
             -- context(manipulator and manipulator(value) or value)
                context(manipulator and manipulated(manipulator,value) or value)
            else
                report("unknown detail %a of tag %a in dataset %a",field,tag,name)
            end
        else
            report("unknown tag %a in dataset %a",tag,name)
        end
    else
        report("unknown dataset %a",name)
    end
end

function commands.btxfield(name,tag,field)
    local dataset = rawget(datasets,name)
    if dataset then
        local fields = dataset.luadata[tag]
        if fields then
            local manipulator, field = checked(field)
            local value = fields[field]
            if type(value) == "string" then
             -- context(manipulator and manipulator(value) or value)
                context(manipulator and manipulated(manipulator,value) or value)
            else
                report("unknown field %a of tag %a in dataset %a",field,tag,name)
            end
        else
            report("unknown tag %a in dataset %a",tag,name)
        end
    else
        report("unknown dataset %a",name)
    end
end

-- testing: to be speed up with testcase

function commands.btxdoifelse(name,tag,field)
    local dataset = rawget(datasets,name)
    if dataset then
        local data  = dataset.luadata[tag]
        local value = data and data[field]
        if value and value ~= "" then
            ctx_firstoftwoarguments()
            return
        end
    end
    ctx_secondoftwoarguments()
end

function commands.btxdoif(name,tag,field)
    local dataset = rawget(datasets,name)
    if dataset then
        local data  = dataset.luadata[tag]
        local value = data and data[field]
        if value and value ~= "" then
            ctx_firstofoneargument()
            return
        end
    end
    ctx_gobbleoneargument()
end

function commands.btxdoifnot(name,tag,field)
    local dataset = rawget(datasets,name)
    if dataset then
        local data  = dataset.luadata[tag]
        local value = data and data[field]
        if value and value ~= "" then
            ctx_gobbleoneargument()
            return
        end
    end
    ctx_firstofoneargument()
end

-- -- alternative approach: keep data at the tex end

function publications.listconcat(t)
    local n = #t
    if n > 0 then
        context(t[1])
        if n > 1 then
            if n > 2 then
                for i=2,n-1 do
                    ctx_btxlistparameter("sep")
                    context(t[i])
                end
                ctx_btxlistparameter("finalsep")
            else
                ctx_btxlistparameter("lastsep")
            end
            context(t[n])
        end
    end
end

function publications.citeconcat(t)
    local n = #t
    if n > 0 then
        context(t[1])
        if n > 1 then
            if n > 2 then
                for i=2,n-1 do
                    ctx_btxcitevariantparameter("sep")
                    context(t[i])
                end
                ctx_btxcitevariantparameter("finalsep")
            else
                ctx_btxcitevariantparameter("lastsep")
            end
            context(t[n])
        end
    end
end

function publications.singularorplural(singular,plural)
    if lastconcatsize and lastconcatsize > 1 then
        context(plural)
    else
        context(singular)
    end
end

-- function commands.makebibauthorlist(settings) -- ?
--     if not settings then
--         return
--     end
--     local dataset = datasets[settings.dataset]
--     if not dataset or dataset == "" then
--         return
--     end
--     local tag = settings.tag
--     if not tag or tag == "" then
--         return
--     end
--     local asked = settings_to_array(tag)
--     if #asked == 0 then
--         return
--     end
--     local compress    = settings.compress
--     local interaction = settings.interactionn == v_start
--     local limit       = tonumber(settings.limit)
--     local found       = { }
--     local hash        = { }
--     local total       = 0
--     local luadata     = dataset.luadata
--     for i=1,#asked do
--         local tag  = asked[i]
--         local data = luadata[tag]
--         if data then
--             local author = data.a or "Xxxxxxxxxx"
--             local year   = data.y or "0000"
--             if not compress or not hash[author] then
--                 local t = {
--                     author = author,
--                     name   = name, -- first
--                     year   = { [year] = name },
--                 }
--                 total = total + 1
--                 found[total] = t
--                 hash[author] = t
--             else
--                 hash[author].year[year] = name
--             end
--         end
--     end
--     for i=1,total do
--         local data = found[i]
--         local author = data.author
--         local year = table.keys(data.year)
--         table.sort(year)
--         if interaction then
--             for i=1,#year do
--                 year[i] = formatters["\\bibmaybeinteractive{%s}{%s}"](data.year[year[i]],year[i])
--             end
--         end
--         ctx_setvalue("currentbibyear",concat(year,","))
--         if author == "" then
--             ctx_setvalue("currentbibauthor","")
--         else -- needs checking
--             local authors = settings_to_array(author) -- {{}{}},{{}{}}
--             local nofauthors = #authors
--             if nofauthors == 1 then
--                 if interaction then
--                     author = formatters["\\bibmaybeinteractive{%s}{%s}"](data.name,author)
--                 end
--                 ctx_setvalue("currentbibauthor",author)
--             else
--                 limit = limit or nofauthors
--                 if interaction then
--                     for i=1,#authors do
--                         authors[i] = formatters["\\bibmaybeinteractive{%s}{%s}"](data.name,authors[i])
--                     end
--                 end
--                 if limit == 1 then
--                     ctx_setvalue("currentbibauthor",authors[1] .. "\\bibalternative{otherstext}")
--                 elseif limit == 2 and nofauthors == 2 then
--                     ctx_setvalue("currentbibauthor",concat(authors,"\\bibalternative{andtext}"))
--                 else
--                     for i=1,limit-1 do
--                         authors[i] = authors[i] .. "\\bibalternative{namesep}"
--                     end
--                     if limit < nofauthors then
--                         authors[limit+1] = "\\bibalternative{otherstext}"
--                         ctx_setvalue("currentbibauthor",concat(authors,"",1,limit+1))
--                     else
--                         authors[limit-1] = authors[limit-1] .. "\\bibalternative{andtext}"
--                         ctx_setvalue("currentbibauthor",concat(authors))
--                     end
--                 end
--             end
--         end
--         -- the following use: currentbibauthor and currentbibyear
--         if i == 1 then
--             context.ixfirstcommand()
--         elseif i == total then
--             context.ixlastcommand()
--         else
--             context.ixsecondcommand()
--         end
--     end
-- end

local patterns = { "publ-imp-%s.mkiv", "publ-imp-%s.tex" }

local function failure(name)
    report("unknown library %a",name)
end

local function action(name,foundname)
    context.input(foundname)
end

function commands.loadbtxdefinitionfile(name) -- a more specific name
    commands.uselibrary {
        name     = gsub(name,"^publ%-",""),
        patterns = patterns,
        action   = action,
        failure  = failure,
        onlyonce = false,
    }
end

-- lists:

publications.lists = publications.lists or { }
local lists        = publications.lists

local context     = context
local structures  = structures

local references  = structures.references
local sections    = structures.sections

-- per rendering

local renderings = { } --- per dataset

table.setmetatableindex(renderings,function(t,k)
    local v = {
        list         = { },
        done         = { },
        alldone      = { },
        used         = { },
        registered   = { },
        ordered      = { },
        shorts       = { },
        method       = v_none,
        currentindex = 0,
    }
    t[k] = v
    return v
end)

-- why shorts vs tags: only for sorting

function lists.register(dataset,tag,short) -- needs checking now that we split
    local r = renderings[dataset]
    if not short or short == "" then
        short = tag
    end
    if trace then
        report("registering publication entry %a with shortcut %a",tag,short)
    end
    local top = #r.registered + 1
    -- do we really need these
    r.registered[top] = tag
    r.ordered   [tag] = top
    r.shorts    [tag] = short
end

function lists.nofregistered(dataset)
    return #renderings[dataset].registered
end

function lists.setmethod(dataset,method)
    local r  = renderings[dataset]
    r.method = method or v_none
    r.list   = { }
    r.done   = { }
end

local function validkeyword(dataset,tag,keyword)
    local ds = datasets[dataset]
    if not ds then
        report("unknown dataset %a",dataset)
        return
    end
    local dt = ds.details[tag]
    if not dt then
        report("no details for tag %a",tag)
        return
    end
    local kw = dt.keyword
    if kw then
-- inspect(keyword)
-- inspect(kw)
        for k in next, keyword do
            if kw[k] then
                return true
            end
        end
    end
end

function lists.collectentries(specification)
    local dataset = specification.btxdataset
    if not dataset then
        return
    end
    local rendering = renderings[dataset]
-- specification.names = "btx"
    local method = rendering.method
    if method == v_none then
        return
    end
-- method=v_local --------------------
    local result  = structures.lists.filter(specification)
    --
    local keyword = specification.keyword
    if keyword and keyword ~= "" then
        keyword = settings_to_set(keyword)
    else
        keyword = nil
    end
    lists.result  = result
    local section = sections.currentid()
    local list    = rendering.list
    local done    = rendering.done
    local alldone = rendering.alldone
    if method == v_local then
        for listindex=1,#result do
            local r = result[listindex]
            local u = r.userdata
            if u and u.btxset == dataset then
                local tag = u.btxref
                if tag and done[tag] ~= section then
                    if not keyword or validkeyword(dataset,tag,keyword) then
                        done[tag]     = section
                        alldone[tag]  = true
                        list[#list+1] = { tag, listindex }
                    end
                end
            end
        end
    elseif method == v_global then
        for listindex=1,#result do
            local r = result[listindex]
            local u = r.userdata
            if u and u.btxset == dataset then
                local tag = u.btxref
                if tag and not alldone[tag] and done[tag] ~= section then
                    if not keyword or validkeyword(dataset,tag,keyword) then
                        done[tag]     = section
                        alldone[tag]  = true
                        list[#list+1] = { tag, listindex }
                    end
                end
            end
        end
    elseif method == v_force then
        -- only for checking, can have duplicates, todo: collapse page numbers, although
        -- we then also needs deferred writes
        for listindex=1,#result do
            local r = result[listindex]
            local u = r.userdata
            if u and u.btxset == dataset then
                local tag = u.btxref
                if tag then
                    if not keyword or validkeyword(dataset,tag,keyword) then
                        list[#list+1] = { tag, listindex }
                    end
                end
            end
        end
    elseif method == v_dataset then
        local luadata = datasets[dataset].luadata
        for tag, data in table.sortedhash(luadata) do
            if not keyword or validkeyword(dataset,tag,keyword) then
                list[#list+1] = { tag }
            end
        end
    end
end

lists.sorters = {
    [v_short] = function(dataset,rendering,list)
        local shorts = rendering.shorts
        local function compare(a,b)
            local aa, bb = a and a[1], b and b[1]
            if aa and bb then
                aa, bb = shorts[aa], shorts[bb]
                return aa and bb and aa < bb
            end
            return false
        end
        sort(list,compare)
    end,
    [v_reference] = function(dataset,rendering,list)
        local function compare(a,b)
            local aa, bb = a and a[1], b and b[1]
            if aa and bb then
                return aa and bb and aa < bb
            end
            return false
        end
        sort(list,compare)
    end,
    [v_dataset] = function(dataset,rendering,list)
        local function compare(a,b)
            local aa, bb = a and a[1], b and b[1]
            if aa and bb then
                aa, bb = list[aa].index or 0, list[bb].index or 0
                return aa and bb and aa < bb
            end
            return false
        end
        sort(list,compare)
    end,
 -- [v_default] = function(dataset,rendering,list) -- not really needed
 --     local ordered = rendering.ordered
 --     local function compare(a,b)
 --         local aa, bb = a and a[1], b and b[1]
 --         if aa and bb then
 --             aa, bb = ordered[aa], ordered[bb]
 --             return aa and bb and aa < bb
 --         end
 --         return false
 --     end
 --     sort(list,compare)
 -- end,
    [v_author] = function(dataset,rendering,list)
        local valid = publications.authors.preparedsort(dataset,list,v_author,v_editor)
        if #valid == 0 or #valid ~= #list then
            -- nothing to sort
        else
            -- if needed we can wrap compare and use the list directly but this is cleaner
            sorters.sort(valid,sortcomparer)
            for i=1,#valid do
                local v = valid[i]
                valid[i] = list[v.index]
            end
            return valid
        end
    end,
}

function lists.flushentries(dataset,sortvariant)
    local rendering = renderings[dataset]
    local list = rendering.list
    local sort = lists.sorters[sortvariant] or lists.sorters[v_default]
    if type(sort) == "function" then
        list = sort(dataset,rendering,list) or list
    end
    for i=1,#list do
        ctx_setvalue("currentbtxindex",i)
        ctx_btxhandlelistentry(list[i][1]) -- we can pass i here too ... more efficient to avoid the setvalue
    end
end

function lists.fetchentries(dataset)
    local list = renderings[dataset].list
    for i=1,#list do
        ctx_setvalue("currentbtxindex",i)
        ctx_btxchecklistentry(list[i][1])
    end
end

function lists.filterall(dataset)
    local r = renderings[dataset]
    local list = r.list
    local registered = r.registered
    for i=1,#registered do
        list[i] = { registered[i], i }
    end
end

function lists.registerplaced(dataset,tag)
    renderings[dataset].used[tag] = true
end

function lists.doifalreadyplaced(dataset,tag)
    commands.doifelse(renderings[dataset].used[tag])
end

-- we ask for <n>:tag but when we can't find it we go back
-- to look for previous definitions, and when not found again
-- we look forward

local function compare(a,b)
    local aa, bb = a and a[3], b and b[3]
    return aa and bb and aa < bb
end

-- maybe hash subsets
-- how efficient is this? old leftovers?

-- rendering ?

local f_reference   = formatters["r:%s:%s:%s"] -- dataset, instance (block), tag
local f_destination = formatters["d:%s:%s:%s"] -- dataset, instance (block), tag

function lists.resolve(dataset,reference) -- maybe already feed it split
    -- needs checking (the prefix in relation to components)
    local subsets   = nil
    local block     = tex.count.btxblock
    local collected = references.collected
    local prefix    = nil -- todo: dataset ?
    if prefix and prefix ~= "" then
        subsets = { collected[prefix] or collected[""] }
    else
        local components = references.productdata.components
        local subset = collected[""]
        if subset then
            subsets = { subset }
        else
            subsets = { }
        end
        for i=1,#components do
            local subset = collected[components[i]]
            if subset then
                subsets[#subsets+1] = subset
            end
        end
    end
-- inspect(subsets)
    if #subsets > 0 then
        local result, nofresult, done = { }, 0, { }
        for i=1,#subsets do
            local subset = subsets[i]
            for rest in gmatch(reference,"[^, ]+") do
                local blk, tag, found = block, nil, nil
                if block then
                    tag = f_destination(dataset,blk,rest)
                    found = subset[tag]
                    if not found then
                        for i=block-1,1,-1 do
                            tag = f_destination(dataset,blk,rest)
--                             tag = i .. ":" .. rest
                            found = subset[tag]
                            if found then
                                blk = i
                                break
                            end
                        end
                    end
                end
                if not found then
                    blk = "*"
                    tag = f_destination(dataset,blk,rest)
                    found = subset[tag]
                end
                if found then
                    local current = tonumber(found.entries and found.entries.text) -- tonumber needed
                    if current and not done[current] then
                        nofresult = nofresult + 1
                        result[nofresult] = { blk, rest, current }
                        done[current] = true
                    end
                end
            end
        end
        local first, last, firsti, lasti, firstr, lastr
        local collected, nofcollected = { }, 0
        for i=1,nofresult do
            local r = result[i]
            local current = r[3]
            if not first then
                first, last, firsti, lasti, firstr, lastr = current, current, i, i, r, r
            elseif current == last + 1 then
                last, lasti, lastr = current, i, r
            else
                if last > first + 1 then
                    nofcollected = nofcollected + 1
                    collected[nofcollected] = { firstr, lastr }
                else
                    nofcollected = nofcollected + 1
                    collected[nofcollected] = firstr
                    if last > first then
                        nofcollected = nofcollected + 1
                        collected[nofcollected] = lastr
                    end
                end
                first, last, firsti, lasti, firstr, lastr = current, current, i, i, r, r
            end
        end
        if first and last then
            if last > first + 1 then
                nofcollected = nofcollected + 1
                collected[nofcollected] = { firstr, lastr }
            else
                nofcollected = nofcollected + 1
                collected[nofcollected] = firstr
                if last > first then
                    nofcollected = nofcollected + 1
                    collected[nofcollected] = lastr
                end
            end
        end
        if nofcollected > 0 then
-- inspect(reference)
-- inspect(result)
-- inspect(collected)
            for i=1,nofcollected do
                local c = collected[i]
                if i == nofcollected then
                    ctx_btxlistvariantparameter("lastpubsep")
                elseif i > 1 then
                    ctx_btxlistvariantparameter("pubsep")
                end
                if #c == 3 then -- a range (3 is first or last)
                    ctx_btxdirectlink(f_reference(dataset,c[1],c[2]),c[3])
                else
                    local f, l = c[2], c[2]
                    ctx_btxdirectlink(f_reference(dataset,f[1],f[2]),f[3])
                    context.endash() -- to do
                    ctx_btxdirectlink(f_reference(dataset,l[4],l[5]),l[6])
                end
            end
        else
            context("[btx error 1]")
        end
    else
        context("[btx error 2]")
    end
end

local done = { }

function commands.btxreference(dataset,block,tag,data)
    local ref = f_reference(dataset,block,tag)
    if not done[ref] then
        done[ref] = true
-- context("<%s>",data)
        ctx_dodirectfullreference(ref,data)
    end
end

local done = { }

function commands.btxdestination(dataset,block,tag,data)
    local ref = f_destination(dataset,block,tag)
    if not done[ref] then
        done[ref] = true
-- context("<<%s>>",data)
        ctx_dodirectfullreference(ref,data)
    end
end

commands.btxsetlistmethod           = lists.setmethod
commands.btxresolvelistreference    = lists.resolve
commands.btxregisterlistentry       = lists.registerplaced
commands.btxaddtolist               = lists.addentry
commands.btxcollectlistentries      = lists.collectentries
commands.btxfetchlistentries        = lists.fetchentries
commands.btxflushlistentries        = lists.flushentries
commands.btxdoifelselistentryplaced = lists.doifalreadyplaced

local citevariants        = { }
publications.citevariants = citevariants

-- helper

local function sortedtags(dataset,list,sorttype)
    local luadata = datasets[dataset].luadata
    local valid = { }
    for i=1,#list do
        local tag = list[i]
        local entry = luadata[tag]
        if entry then
            local key = entry[sorttype]
            if key then
                valid[#valid+1] = {
                    tag   = tag,
                    split = sortsplitter(sortstripper(key))
                }
            else
            end
        end
    end
    if #valid == 0 or #valid ~= #list then
        return list
    else
        sorters.sort(valid,basicsorter)
        for i=1,#valid do
            valid[i] = valid[i].tag
        end
        return valid
    end
end

-- todo: standard : current

local prefixsplitter = lpeg.splitat("::")

-- num is special

function commands.btxhandlecite(dataset,tag,mark,variant,sorttype,setup) -- variant for tracing
    local prefix, rest = lpegmatch(prefixsplitter,tag)
    if rest then
        dataset = prefix
    else
        rest = tag
    end
    ctx_setvalue("currentbtxdataset",dataset)
    local tags = settings_to_array(rest)
    if #tags > 0 then
        if sorttype and sorttype ~= "" then
            tags = sortedtags(dataset,tags,sorttype)
        end
        ctx_btxcitevariantparameter(v_left)
        for i=1,#tags do
            local tag = tags[i]
            ctx_setvalue("currentbtxtag",tag)
            if i > 1 then
                ctx_btxcitevariantparameter(v_middle)
            end
            if mark ~= false then
                ctx_btxdomarkcitation(dataset,tag)
            end
            ctx_directsetup(setup) -- cite can become alternative
        end
        ctx_btxcitevariantparameter(v_right)
    else
        -- error
    end
end

function commands.btxhandlenocite(dataset,tag,mark)
    if mark ~= false then
        local prefix, rest = lpegmatch(prefixsplitter,tag)
        if rest then
            dataset = prefix
        else
            rest = tag
        end
        ctx_setvalue("currentbtxdataset",dataset)
        local tags = settings_to_array(rest)
        for i=1,#tags do
            ctx_btxdomarkcitation(dataset,tags[i])
        end
    end
end

function commands.btxcitevariant(dataset,block,tags,variant)
    local action = citevariants[variant] or citevariants.default
    if action then
        action(dataset,tags,variant)
    end
end

function citevariants.default(dataset,tags,variant)
    local content = getfield(dataset,tags,variant)
    if content then
        context(content)
    end
end

-- todo : sort
-- todo : choose between publications or commands namespace
-- todo : use details.author
-- todo : sort details.author

local function collectauthoryears(dataset,tags)
    local luadata = datasets[dataset].luadata
    local list    = settings_to_array(tags)
    local found   = { }
    local result  = { }
    local order   = { }
    for i=1,#list do
        local tag   = list[i]
        local entry = luadata[tag]
        if entry then
            local year   = entry.year
            local author = entry.author
            if author and year then
                local a = found[author]
                if not a then
                    a = { }
                    found[author] = a
                    order[#order+1] = author
                end
                local y = a[year]
                if not y then
                    y = { }
                    a[year] = y
                end
                y[#y+1] = tag
            end
        end
    end
    -- found = { author = { year_1 = { e1, e2, e3 } } }
    for i=1,#order do
        local author = order[i]
        local years  = found[author]
        local yrs    = { }
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
        result[i] = { author = author, years = yrs }
    end
    return result, order
end

-- (name, name and name) .. how names? how sorted?
-- todo: we loop at the tex end .. why not here
-- \cite[{hh,afo},kvm]

-- maybe we will move this tex anyway

function citevariants.author(dataset,tags)
    local result, order = collectauthoryears(dataset,tags,method,what) -- we can have a collectauthors
    publications.citeconcat(order)
end

local function authorandyear(dataset,tags,formatter)
    local result, order = collectauthoryears(dataset,tags,method,what) -- we can have a collectauthors
    for i=1,#result do
        local r = result[i]
        order[i] = formatter(r.author,r.years) -- reuse order
    end
    publications.citeconcat(order)
end

function citevariants.authoryear(dataset,tags)
    authorandyear(dataset,tags,formatters["%s (%, t)"])
end

function citevariants.authoryears(dataset,tags)
    authorandyear(dataset,tags,formatters["%s, %, t"])
end

function citevariants.authornum(dataset,tags)
    local result, order = collectauthoryears(dataset,tags,method,what) -- we can have a collectauthors
    publications.citeconcat(order)
    ctx_btxcitevariantparameter(v_inbetween)
    lists.resolve(dataset,tags) -- left/right ?
end

-- function citevariants.short(dataset,tags)
--     local short = getdetail(dataset,tags,"short")
--     if short then
--         context(short)
--     end
-- end

function citevariants.short(dataset,tags)
    local short = getdetail(dataset,tags,"short")
    local suffix = getdetail(dataset,tags,"suffix")
    if suffix then
        context(short .. suffix)
    elseif short then
        context(short)
    end
end

function citevariants.page(dataset,tags)
    local pages = getdetail(dataset,tags,"pages")
    if not pages then
        -- nothing
    elseif type(pages) == "table" then
        context(pages[1])
        ctx_btxcitevariantparameter(v_inbetween)
        context(pages[2])
    else
        context(pages)
    end
end

function citevariants.serial(dataset,tags) -- the traditional fieldname is "serial" and not "index"
    local index = getfield(dataset,tags,"index")
    if index then
        context(index)
    end
end

-- num is somewhat special as it can be more and we need to deal with ranges here

function citevariants.num(dataset,tags)
--     ctx_btxdirectlink(f_destination(dataset,block,tags),listindex) -- not okay yet
    lists.resolve(dataset,tags)
end

-- List variants

local listvariants        = { }
publications.listvariants = listvariants

-- function commands.btxhandlelist(dataset,block,tag,variant,setup)
--     if sorttype and sorttype ~= "" then
--         tags = sortedtags(dataset,tags,sorttype)
--     end
--     ctx_setvalue("currentbtxtag",tag)
--     ctx_btxlistvariantparameter(v_left)
--     ctx_directsetup(setup)
--     ctx_btxlistvariantparameter(v_right)
-- end

function commands.btxlistvariant(dataset,block,tags,variant,listindex)
    local action = listvariants[variant] or listvariants.default
    if action then
        action(dataset,block,tags,variant,tonumber(listindex) or 0)
    end
end

function listvariants.default(dataset,block,tags,variant)
    context("?")
end

function listvariants.num(dataset,block,tags,variant,listindex)
    ctx_btxdirectlink(f_destination(dataset,block,tags),listindex) -- not okay yet
end

-- function listvariants.short(dataset,block,tags,variant,listindex)
--     local short = getdetail(dataset,tags,variant,variant)
--     if short then
--         context(short)
--     end
-- end

function listvariants.short(dataset,block,tags,variant,listindex)
    local short  = getdetail(dataset,tags,"short","short")
    local suffix = getdetail(dataset,tags,"suffix","suffix")
    if suffix then
        context(short .. suffix)
    elseif short then
        context(short)
    end
end
