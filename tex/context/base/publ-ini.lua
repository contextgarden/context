if not modules then modules = { } end modules ['publ-ini'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we could store the destinations in the user list entries

-- will move:

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

local next, rawget, type, tostring, tonumber = next, rawget, type, tostring, tonumber
local match, gmatch, format, gsub = string.match, string.gmatch, string.format, string.gsub
local concat, sort, tohash = table.concat, table.sort, table.tohash
local utfsub = utf.sub
local formatters = string.formatters
local allocate = utilities.storage.allocate
local settings_to_array, settings_to_set = utilities.parsers.settings_to_array, utilities.parsers.settings_to_set
local sortedkeys, sortedhash = table.sortedkeys, table.sortedhash
local lpegmatch = lpeg.match
local P, C, Ct = lpeg.P, lpeg.C, lpeg.Ct

local report           = logs.reporter("publications")
local report_cite      = logs.reporter("publications","cite")
local report_reference = logs.reporter("publications","reference")

local trace            = false  trackers.register("publications",                 function(v) trace            = v end)
local trace_cite       = false  trackers.register("publications.cite",            function(v) trace_cite       = v end)
local trace_missing    = false  trackers.register("publications.cite.missing",    function(v) trace_missing    = v end)
local trace_references = false  trackers.register("publications.cite.references", function(v) trace_references = v end)

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

local settings_to_array = utilities.parsers.settings_to_array

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
----- ctx_dodirectfullreference   = context.dodirectfullreference
local ctx_btxsetreference         = context.btxsetreference
local ctx_directsetup             = context.directsetup
local ctx_btxmissing              = context.btxmissing

local ctx_btxcitesetup            = context.btxcitesetup
local ctx_btxsetfirst             = context.btxsetfirst
local ctx_btxsetsecond            = context.btxsetsecond
local ctx_btxsetinternal          = context.btxsetinternal
local ctx_btxsetconcat            = context.btxsetconcat

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

local usedentries = { }
local initialized = false

--  {
--   ["metadata"]=1,
--   ["references"]={
--    ["block"]="bodypart",
--    ["internal"]=2,
--    ["realpage"]=1,
--    ["section"]=0,
--   },
--   ["userdata"]={
--    ["btxref"]="Cleveland1985",
--    ["btxset"]="standard",
--   },
--  },

table.setmetatableindex(usedentries,function(t,k)
    if not initialized then
        usedentries = { }
        local internals = structures.references.internals
        for i=1,#internals do
            local entry = internals[i]
            local metadata = entry.metadata
            if metadata.kind == "full" then
                local userdata = entry.userdata
                if userdata then
                    local set = userdata.btxset
                    if set then
                        local tag = userdata.btxref
                        local s = usedentries[set]
                        if s then
                            local u = s[tag]
                            if u then
                                u[#u+1] = entry
                            else
                                u = { entry }
                                s[tag] = u
                            end
                        else
                            usedentries[set] = { [tag] = { entry } }
                        end
                    end
                end
            end
        end
        return usedentries[k]
    end
end)

--     local subsets   = nil
--     local block     = tex.count.btxblock
--     local collected = references.collected
--     local prefix    = nil -- todo: dataset ?
--     if prefix and prefix ~= "" then
--         subsets = { collected[prefix] or collected[""] }
--     else
--         local components = references.productdata.components
--         local subset = collected[""]
--         if subset then
--             subsets = { subset }
--         else
--             subsets = { }
--         end
--         for i=1,#components do
--             local subset = collected[components[i]]
--             if subset then
--                 subsets[#subsets+1] = subset
--             end
--         end
--     end
--     if #subsets == 0 then
--         subsets = { collected[""] }
--     end
--     local list = type(reference) == "string" and settings_to_array(reference) or reference
--     local todo = table.tohash(list)
--     if #subsets > 0 then
--         local result, nofresult, done = { }, 0, { }
--         for i=1,#subsets do
--             local subset = subsets[i]
--             for i=1,#list do
--                 local rest = list[i]
--                 local blk, tag, found = block, nil, nil
--                 if block then
--                     tag = f_destination(dataset,blk,rest)
--                     found = subset[tag]
--                     if not found then
--                         for i=block-1,1,-1 do
--                             tag = f_destination(dataset,i,rest)
--                             found = subset[tag]
--                             if found then
--                                 blk = i
--                                 break
--                             end
--                         end
--                     end
--                 end
--                 if not found then
--                     blk = "*"
--                     tag = f_destination(dataset,blk,rest)
--                     found = subset[tag]
--                 end
--                 if found then
--                     local entries = found.entries
--                     if entries then
--                         local current = tonumber(entries.text) -- todo: no ranges when no tonumber
--                         if current and not done[current] then
--                             nofresult = nofresult + 1
--                             result[nofresult] = { blk, rest, current, found.references.internal }
--                             done[current] = true
--                         end
--                     end
--                 end
--             end
--         end

local function findallused(dataset,reference,block,section)
    local tags = settings_to_array(reference)
    local todo = { }
    local okay = { } -- only if mark
    local set = usedentries[dataset]
    if set then
        for i=1,#tags do
            local tag = tags[i]
            local entry = set[tag]
            if entry then
                -- only once in a list
                if #entry == 1 then
                    entry = entry[1]
                else
                    -- find best match
                    entry = entry[1] -- for now
                end
                okay[#okay+1] = entry
            end
            todo[tag] = true
        end
    else
        for i=1,#tags do
            todo[tags[i]] = true
        end
    end
    return okay, todo, tags
end

local function flushcollected(flush,nofcollected)
    if nofcollected > 0 then
        flush(1,1)
        if nofcollected > 2 then
            for i=2,nofcollected-1 do
                flush(i,2)
            end
            flush(nofcollected,3)
        elseif nofcollected > 1 then
            flush(nofcollected,4)
        end
    end
end

local function markcite(dataset,tag)
    if trace_cite then
        report_cite("mark, dataset: %s, tag: %s",dataset,tag)
    end
    ctx_btxdomarkcitation(dataset,tag)
end

local function flushmarked(dataset,list,todo)
    if todo then
        for i=1,#list do
            local tag = list[i]
            if todo[tag] then
                markcite(dataset,tag)
            end
        end
    end
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
             -- details[tags[i]].short = short .. numbertochar(i)
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

-- local manipulation = utilities.parsers.manipulation
-- local manipulators = utilities.parsers.manipulators
--
-- local function checked(field)
--     local m, f = lpegmatch(manipulation,field)
--     if m then
--         return manipulators[m], f or field
--     else
--         return nil, field
--     end
-- end

local manipulation = Ct((C((1-P("->"))^1) * P("->"))^1) * C(P(1)^0)
local manipulators = utilities.parsers.manipulators

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
                context(manipulator and manipulated(manipulator,value) or value)
                return
            end
            local details = dataset.details[tag]
            if details then
                local value = details[field]
                if type(value) == "string" then
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

function publications.singularorplural(singular,plural)
    if lastconcatsize and lastconcatsize > 1 then
        context(plural)
    else
        context(singular)
    end
end

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
    local method = rendering.method
    if method == v_none then
        return
    end
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

-- rendering ?

-- todo: nicer refs

local f_reference   = formatters["r:%s:%s:%s"] -- dataset, instance (block), tag
local f_destination = formatters["d:%s:%s:%s"] -- dataset, instance (block), tag
local f_listentry   = formatters["d:%s:%s:%s"] -- dataset, instance (block), tag
local f_internal    = formatters["internal(%s)"] -- dataset, instance (block), tag

local done = { }

function commands.btxreference(dataset,block,tag,data)
    local ref = f_reference(dataset,block,tag) -- we just need a unique key
    if not done[ref] then
        if trace_references then
            report_reference("link: %s",ref)
        end
        done[ref] = true
        ctx_btxsetreference(dataset,tag,ref,data)
    end
end

local done = { }

function commands.btxdestination(dataset,block,tag,data)
    local ref = f_destination(dataset,block,tag) -- we just need a unique key
    if not done[ref] then
        if trace_references then
            report_reference("link: %s",ref)
        end
        done[ref] = true
        ctx_btxsetreference(dataset,tag,ref,data)
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

--     if sorttype and sorttype ~= "" then
--         tags = sortedtags(dataset,tags,sorttype)
--     end


local prefixsplitter = lpeg.splitat("::")

function commands.btxhandlecite(dataset,tag,mark,variant,sorttype,compress)
    local prefix, rest = lpegmatch(prefixsplitter,tag)
    if rest then
        dataset = prefix
    else
        rest = tag
    end
    local action = citevariants[variant]
    if action then
        if trace_cite then
            report_cite("inject, dataset: %s, tag: %s, variant: %s, compressed",dataset or "-",rest,variant)
        end
        ctx_setvalue("currentbtxdataset",dataset)
-- print(variant,sorttype,compress)
        action(dataset,rest,mark ~= false,compress,variant)
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
        if trace_cite then
            report_cite("mark, dataset: %s, tags: % | t",dataset or "-",tags)
        end
        for i=1,#tags do
            markcite(dataset,tags[i])
        end
    end
end

function commands.btxcitevariant(dataset,block,tags,variant)
    local action = citevariants[variant]
    if action then
        action(dataset,tags,variant)
    end
end

-- sorter

local function compresslist(source,key)
    local first, last, firstr, lastr
    local target, noftarget, tags = { }, 0, { }
    local function flushrange()
        noftarget = noftarget + 1
        if last > first + 1 then
            target[noftarget] = {
                first = firstr,
                last  = lastr,
                tags  = tags,
            }
        else
            target[noftarget] = firstr
            if last > first then
                noftarget = noftarget + 1
                target[noftarget] = lastr
            end
        end
        tags = { }
    end
    for i=1,#source do
        local entry = source[i]
        local current = entry[key]
        if not first then
            first, last, firstr, lastr = current, current, entry, entry
        elseif current == last + 1 then
            last, lastr = current, entry
        else
            flushrange()
            first, last, firstr, lastr = current, current, entry, entry
        end
        tags[#tags+1] = entry.tag
    end
    if first and last then
        flushrange()
    end
    return target
end

-- local source = {
--     { tag = "one",   internal = 1, value = "foo", page = 1 },
--     { tag = "two",   internal = 2, value = "bar", page = 2 },
--     { tag = "three", internal = 3, value = "gnu", page = 3 },
-- }
--
-- local target = compresslist(source,"page")

function citevariants.default(dataset,reference,mark,compress,variant,setup)
    local found, todo, list = findallused(dataset,reference)
    if found then
        local valid = { }
        for i=1,#found do
            local entry = found[i]
            local tag   = entry.userdata.btxref
            local value = getfield(dataset,tag,variant)
            if value then
                valid[#valid+1] = { tag, entry.references.internal, value }
            end
        end
        local function flush(i,state)
            local data = valid[i]
            if mark then
                local tag = data[1]
                markcite(dataset,tag)
                todo[tag] = false
            end
            ctx_btxsetinternal(data[2])
            ctx_btxsetconcat(state)
            ctx_btxsetfirst(data[3])
            ctx_btxcitesetup(setup or variant)
        end
        flushcollected(flush,#valid)
        if mark and #valid == #found then
            mark = false
        end
    end
    if mark then
        flushmarked(dataset,list,todo)
    end
end

table.setmetatableindex(citevariants,function(t,k)
    local v = t.default
    t[k] = v
    return v
end)

function citevariants.short(dataset,reference,mark,compress)
    local found, todo, list = findallused(dataset,reference)
    if found then
        local valid = { }
        for i=1,#found do
            local entry  = found[i]
            local tag    = entry.userdata.btxref
            local short  = getdetail(dataset,tag,"short")
            if short then
                valid[#valid+1] = { tag, entry.references.internal, short, getdetail(dataset,tag,"suffix") }
            end
        end
        local function flush(i,state)
            local data   = valid[i]
            local short  = data[3]
            local suffix = data[4]
            if mark then
                local tag = data[1]
                markcite(dataset,tag)
                todo[tag] = false
            end
            ctx_btxsetinternal(data[2])
            ctx_btxsetconcat(state)
            if suffix then
                ctx_btxsetfirst(short .. suffix)
            else
                ctx_btxsetfirst(short)
            end
            ctx_btxcitesetup("short")
        end
        flushcollected(flush,#valid)
        if mark and #valid == #found then
            mark = false
        end
    end
    if mark then
        flushmarked(dataset,list,todo)
    end
end

-- no compress

function citevariants.page(dataset,reference,mark,compress)
    local found, todo, list = findallused(dataset,reference)
    if found then
        local valid = { }
        for i=1,#found do
            local entry = found[i]
            local tag   = entry.userdata.btxref
            local pages = getdetail(dataset,tag,"pages")
            if pages then
                valid[#valid+1] = { tag, entry.references.internal, pages }
            end
        end
        local function flush(i,state)
            local data  = valid[i]
            local pages = data[3]
            if mark then
                local tag = data[1]
                markcite(dataset,tag)
                todo[tag] = false
            end
            ctx_btxsetinternal(data[2])
            ctx_btxsetconcat(state)
            if type(pages) == "table" then
                ctx_btxsetfirst(pages[1])
                ctx_btxsetsecond(pages[2])
            else
                ctx_btxsetfirst(pages)
            end
            ctx_btxcitesetup("page")
        end
        flushcollected(flush,#valid)
        if mark and #valid == #found then
            mark = false
        end
    end
    if mark then
        flushmarked(dataset,list,todo)
    end
end

-- compress: 1-4, 5, 8-10

-- local source = {
--     { tag = "one",   internal = 1, value = "foo", page = 1 },
--     { tag = "two",   internal = 2, value = "bar", page = 2 },
--     { tag = "three", internal = 3, value = "gnu", page = 3 },
-- }
--
-- local target = compress(source,"page")

function citevariants.num(dataset,reference,mark,compress)
    local found, todo, list = findallused(dataset,reference)
    if found then
        if compress then
            local source = { }
            for i=1,#found do
                local entry = found[i]
                local text  = entry.entries.text
                local key   = tonumber(text)
                if not key then
                    source = false
                    break
                end
                source[i] = {
                    tag      = entry.userdata.btxref,
                    internal = entry.references.internal,
                    text     = text,
                    sortkey  = key,
                }
            end
            if source then
                local target = compresslist(source,"sortkey")
                local function flush(i,state)
                    local entry = target[i]
                    local first = entry.first
                    if first then
                        if mark then
                            local tags = entry.tags
                            for i=1,#tags do
                                local tag = tags[i]
                                markcite(dataset,tag)
                                todo[tag] = false
                            end
                        end
                        ctx_btxsetinternal(first.internal)
                        ctx_btxsetfirst(first.text)
                        ctx_btxsetsecond(entry.last.text)
                    else
                        if mark then
                            local tag = entry.tag
                            markcite(dataset,tag)
                            todo[tag] = false
                        end
                        ctx_btxsetinternal(entry.internal)
                        ctx_btxsetfirst(entry.text)
                    end
                    ctx_btxsetconcat(state)
                    ctx_btxcitesetup("num")
                end
                flushcollected(flush,#target)
                return
            else
                -- fall through
            end
        end
        local function flush(i,state)
            local entry = found[i]
            if mark then
                local tag = entry.userdata.btxref
                markcite(dataset,tag)
                todo[tag] = false
            end
            ctx_btxsetinternal(entry.references.internal)
            ctx_btxsetconcat(state)
            ctx_btxsetfirst(entry.entries.text)
            ctx_btxcitesetup("num")
        end
        flushcollected(flush,#found)
    end
    if mark then
        flushmarked(dataset,list,todo)
    end
end

function citevariants.type  (dataset,reference,mark,compress) return citevariants.default(dataset,reference,mark,compress,"category","type") end -- synonyms
function citevariants.key   (dataset,reference,mark,compress) return citevariants.default(dataset,reference,mark,compress,"tag","key")       end -- synonyms
function citevariants.serial(dataset,reference,mark,compress) return citevariants.default(dataset,reference,mark,compress,"index","serial")  end -- synonyms

-- todo : sort
-- todo : choose between publications or commands namespace
-- todo : use details.author
-- todo : sort details.author

local function collectauthoryears(dataset,tag)
    local luadata = datasets[dataset].luadata
    local list    = settings_to_array(tag)
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

function citevariants.author(dataset,reference,mark,compress)
    local found, todo, list = findallused(dataset,reference)
    if found then
        local function flush(i,state)
            local entry = found[i]
            local tag   = entry.userdata.btxref
            if mark then
                markcite(dataset,tag)
                todo[tag] = false
            end
            ctx_btxsetinternal(entry.references.internal)
            ctx_btxsetconcat(state)
            ctx_btxsetfirst(getfield(dataset,tag,"author")) -- todo: reformat
            ctx_btxcitesetup("author")
        end
        flushcollected(flush,#found)
    end
    if mark then
        flushmarked(dataset,list,todo)
    end
end

function citevariants.authornum(dataset,reference,mark,compress)
    local found, todo, list = findallused(dataset,reference)
    if found then
        local function flush(i,state)
            local entry = found[i]
            local tag   = entry.userdata.btxref
            if mark then
                markcite(dataset,tag)
                todo[tag] = false
            end
            ctx_btxsetinternal(entry.references.internal)
            ctx_btxsetconcat(state)
            ctx_btxsetfirst(getfield(dataset,tag,"author")) -- todo: reformat
            ctx_btxsetsecond(entry.entries.text)
            ctx_btxcitesetup("authornum")
        end
        flushcollected(flush,#found)
    end
    if mark then
        flushmarked(dataset,list,todo)
    end
end

-- local result, order = collectauthoryears(dataset,tag) -- we can have a collectauthors

local function authorandyear(dataset,reference,mark,compress,setup)
    local found, todo, list = findallused(dataset,reference)
    if found then
        local function flush(i,state)
            local entry = found[i]
            local tag   = entry.userdata.btxref
            if mark then
                markcite(dataset,tag)
                todo[tag] = false
            end
            ctx_btxsetinternal(entry.references.internal)
            ctx_btxsetconcat(state)
            ctx_btxsetfirst(getfield(dataset,tag,"author")) -- todo: reformat
            ctx_btxsetsecond(getfield(dataset,tag,"year"))
            ctx_btxcitesetup(setup)
        end
        flushcollected(flush,#found)
    end
    if mark then
        flushmarked(dataset,list,todo)
    end
end

function citevariants.authoryear(dataset,reference,mark,compress)
    authorandyear(dataset,reference,mark,compress,"authoryear")
end

function citevariants.authoryears(dataset,reference,mark,compress)
    authorandyear(dataset,reference,mark,compress,"authoryears")
end

-- List variants

local listvariants        = { }
publications.listvariants = listvariants

-- function commands.btxhandlelist(dataset,block,tag,variant,setup)
--     if sorttype and sorttype ~= "" then
--         tag = sortedtags(dataset,tag,sorttype)
--     end
--     ctx_setvalue("currentbtxtag",tag)
--     ctx_btxlistvariantparameter(v_left)
--     ctx_directsetup(setup)
--     ctx_btxlistvariantparameter(v_right)
-- end

function commands.btxlistvariant(dataset,block,tag,variant,listindex)
    local action = listvariants[variant] or listvariants.default
    if action then
        action(dataset,block,tag,variant,tonumber(listindex) or 0)
    end
end

function listvariants.default(dataset,block,tag,variant)
    context("?")
end

function listvariants.num(dataset,block,tag,variant,listindex)
    local lst = f_listentry(dataset,block,tag)
    local ref = f_reference(dataset,block,tag)
    if trace_references then
        report_reference("list: %s",lst)
    end
    -- todo
    ctx_btxdirectlink(ref,listindex) -- a goto
end

function listvariants.short(dataset,block,tag,variant,listindex)
    local short  = getdetail(dataset,tag,"short","short")
    local suffix = getdetail(dataset,tag,"suffix","suffix")
    if suffix then
        context(short .. suffix)
    elseif short then
        context(short)
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

-- function publications.citeconcat(t)
--     local n = #t
--     if n > 0 then
--         context(t[1])
--         if n > 1 then
--             if n > 2 then
--                 for i=2,n-1 do
--                     ctx_btxcitevariantparameter("sep")
--                     context(t[i])
--                 end
--                 ctx_btxcitevariantparameter("finalsep")
--             else
--                 ctx_btxcitevariantparameter("lastsep")
--             end
--             context(t[n])
--         end
--     end
-- end

-- function publications.listconcat(t)
--     local n = #t
--     if n > 0 then
--         context(t[1])
--         if n > 1 then
--             if n > 2 then
--                 for i=2,n-1 do
--                     ctx_btxlistparameter("sep")
--                     context(t[i])
--                 end
--                 ctx_btxlistparameter("finalsep")
--             else
--                 ctx_btxlistparameter("lastsep")
--             end
--             context(t[n])
--         end
--     end
-- end
