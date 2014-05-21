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
local P, R, C, Ct, Cs = lpeg.P, lpeg.R, lpeg.C, lpeg.Ct, lpeg.Cs

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
local setmetatableindex = table.setmetatableindex
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
local v_yes          = variables.yes
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

local ctx_setvalue                = context.setvalue
local ctx_firstoftwoarguments     = context.firstoftwoarguments
local ctx_secondoftwoarguments    = context.secondoftwoarguments
local ctx_firstofoneargument      = context.firstofoneargument
local ctx_gobbleoneargument       = context.gobbleoneargument
----- ctx_directsetup             = context.directsetup

local ctx_btxlistparameter        = context.btxlistparameter
local ctx_btxcitevariantparameter = context.btxcitevariantparameter
local ctx_btxlistvariantparameter = context.btxlistvariantparameter
local ctx_btxdomarkcitation       = context.btxdomarkcitation
local ctx_btxdirectlink           = context.btxdirectlink
local ctx_btxhandlelistentry      = context.btxhandlelistentry
local ctx_btxchecklistentry       = context.btxchecklistentry
local ctx_btxchecklistcombi       = context.btxchecklistcombi
local ctx_btxsetcitereference     = context.btxsetcitereference
local ctx_btxsetlistreference     = context.btxsetlistreference
local ctx_btxmissing              = context.btxmissing

local ctx_btxsettag               = context.btxsettag
local ctx_btxcitesetup            = context.btxcitesetup
local ctx_btxsetfirst             = context.btxsetfirst
local ctx_btxsetsecond            = context.btxsetsecond
local ctx_btxsetinternal          = context.btxsetinternal
local ctx_btxsetconcat            = context.btxsetconcat
local ctx_btxstartsubcite         = context.btxstartsubcite
local ctx_btxstopsubcite          = context.btxstopsubcite

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

setmetatableindex(usedentries,function(t,k)
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

local reported = { }
local finder   = publications.finder

local function findallused(dataset,reference,block,section)
local finder = publications.finder
    local find  = finder and finder(reference)
    local tags  = not find and settings_to_array(reference)
    local todo  = { }
    local okay  = { } -- only if mark
    local set   = usedentries[dataset]
    local valid = datasets[dataset].luadata
    if set then
        local function register(tag)
            local entry = set[tag]
            if entry then
                -- only once in a list
                if #entry == 1 then
                    entry = entry[1]
                else
                    -- find best match (todo)
                    entry = entry[1] -- for now
                end
                okay[#okay+1] = entry
            end
            todo[tag] = true
        end
        if find then
            tags = { }
            for tag, entry in next, valid do
                local found = find(entry)
                if found then
                    register(tag)
                    tags[#tags+1] = tag
                end
            end
        else
            for i=1,#tags do
                local tag  = tags[i]
                if valid[tag] then
                    register(tag)
                elseif not reported[tag] then
                    reported[tag] = true
                    report_cite("non-existent entry %a in %a",tag,dataset)
                end
            end
        end
    else
        if find then
            tags = { }
            for tag, entry in next, valid do
                local found = find(entry)
                if found then
                    todo[tag] = true
                    tags[#tags+1] = tag
                end
            end
        else
            for i=1,#tags do
                local tag = tags[i]
                if valid[tag] then
                    todo[tag] = true
                elseif not reported[tag] then
                    reported[tag] = true
                    report_cite("non-existent entry %a in %a",tag,dataset)
                end
            end
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
                local suffixes = dataset.suffixes[tag]
                if suffixes then
                    local suffix = suffixes[field]
                    if suffix then
                        value = value .. converters.characters(suffix)
                    end
                end
                context(manipulator and manipulated(manipulator,value) or value)
                return
            end
            local details = dataset.details[tag]
            if details then
                local value = details[field]
                if type(value) == "string" then
                    local suffixes = dataset.suffixes[tag]
                    if suffixes then
                        local suffix = suffixes[field]
                        if suffix then
                            value = value .. converters.characters(suffix)
                        end
                    end
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
                local suffixes = dataset.suffixes[tag]
                if suffixes then
                    local suffix = suffixes[field]
                    if suffix then
                        value = value .. converters.characters(suffix)
                    end
                end
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
                local suffixes = dataset.suffixes[tag]
                if suffixes then
                    local suffix = suffixes[field]
                    if suffix then
                        value = value .. converters.characters(suffix)
                    end
                end
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

setmetatableindex(renderings,function(t,k)
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
     -- we can pass i here too ... more efficient to avoid the setvalue
        local tag = list[i][1]
        local entry = datasets[dataset].luadata[tag]
        if entry then
            ctx_setvalue("currentbtxindex",i) -- todo: helper
            local combined = entry.combined
            if combined then
                ctx_setvalue("currentbtxcombis",concat(combined,","))
            else
                ctx_setvalue("currentbtxcombis","")
            end
            ctx_btxhandlelistentry(tag) -- pas i instead
        end
     end
end

function lists.fetchentries(dataset)
    local list = renderings[dataset].list
    for i=1,#list do
        local tag = list[i][1]
        local entry = datasets[dataset].luadata[tag]
        if entry then
            ctx_btxchecklistentry(tag) -- integrate doifalreadyplaced here
        end
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

-- local f_citereference = formatters["btx:%s:%s"]       -- dataset, instance (block), tag, order
-- local f_listreference = formatters["btx:%s:%s:%s:%s"] -- dataset, instance (block), tag, order
--
-- -- local done = { }
-- local last = 0
--
-- function commands.btxcitereference(internal)
--     last = last + 1
--     local ref = f_citereference(internal,last) -- we just need a unique key
-- --     local don = done[ref]
-- --     if don == nil then
--         if trace_references then
--             report_reference("cite: %s",ref)
--         end
-- --         done[ref] = true
--         ctx_btxsetcitereference(ref,internal)
-- --     elseif don then
-- --         report_reference("duplicate cite: %s, skipped",ref)
-- --         done[ref] = false
-- --  -- else
-- --         -- no more messages
-- --     end
-- end
--
-- -- we just need a unique key, so we could also use btx:<number> but this
-- -- way we have a bit of a check for duplicates
--
-- -- local done = { }
-- local last = 0
--
-- function commands.btxlistreference(dataset,block,tag,data)
--     last = last + 1
--     local ref = f_listreference(dataset,block,tag,last)
-- --     local don = done[ref]
-- --     if don == nil then
--         if trace_references then
--             report_reference("list: %s",ref)
--         end
-- --         done[ref] = true
--         ctx_btxsetlistreference(dataset,tag,ref,data)
-- --     elseif don then
-- --         report_reference("duplicate link: %s, skipped",ref)
-- --         done[ref] = false
-- --  -- else
-- --         -- no more messages
-- --     end
-- end


local f_citereference = formatters["btx:cite:%s"]
local f_listreference = formatters["btx:list:%s"]

local nofcite = 0
local noflist = 0

function commands.btxcitereference(internal)
    nofcite = nofcite + 1
    local ref = f_citereference(nofcite)
    if trace_references then
        report_reference("cite: %s",ref)
    end
    ctx_btxsetcitereference(ref,internal)
end

function commands.btxlistreference(dataset,block,tag,data)
    noflist = noflist + 1
    local ref = f_listreference(noflist)
    if trace_references then
        report_reference("list: %s",ref)
    end
    ctx_btxsetlistreference(dataset,tag,ref,data)
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

local optionalspace  = lpeg.patterns.whitespace^0
local prefixsplitter = optionalspace * lpeg.splitat(optionalspace * P("::") * optionalspace)

function commands.btxhandlecite(specification)
    local tag = specification.reference
    if not tag or tag == "" then
        return
    end
    --
    local dataset   = specification.dataset or ""
    local mark      = specification.markentry ~= false
    local variant   = specification.variant or "num"
    local sorttype  = specification.sorttype
    local compress  = specification.compress == v_yes
    --
    local prefix, rest = lpegmatch(prefixsplitter,tag)
    if rest then
        dataset = prefix
    else
        rest = tag
    end
    local action = citevariants[variant] -- there is always fallback on default
    if trace_cite then
        report_cite("inject, dataset: %s, tag: %s, variant: %s, compressed",dataset or "-",rest,variant)
    end
    ctx_setvalue("currentbtxdataset",dataset)
    action(dataset,rest,mark,compress,variant)
end

function commands.btxhandlenocite(specification)
    local mark = specification.markentry ~= false
    if not mark then
        return
    end
    local tag = specification.reference
    if not tag or tag == "" then
        return
    end
    local dataset = specification.dataset or ""
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

-- function commands.btxcitevariant(dataset,block,tags,variant) -- uses? specification ?
--     local action = citevariants[variant]
--     if action then
--         action(dataset,tags,variant)
--     end
-- end

-- sorter

local keysorter = function(a,b) return a.sortkey < b.sortkey end

local function compresslist(source)
    for i=1,#source do
        if type(source[i].sortkey) ~= "number" then
            return source
        end
    end
    local first, last, firstr, lastr
    local target, noftarget, tags = { }, 0, { }
    sort(source,keysorter)
    -- suffixes
    local oldvalue = nil
    local suffix   = 0
    local function setsuffix(entry,suffix,sortfld)
        entry.suffix  = suffix
        local dataset = datasets[entry.dataset]
        if dataset then
            local suffixes = dataset.suffixes[entry.tag]
            if suffixes then
                suffixes[sortfld] = suffix
            else
                dataset.suffixes[entry.tag] = { [sortfld] = suffix }
            end
        end
    end
    for i=1,#source do
        local entry   = source[i]
        local sortfld = entry.sortfld
        if sortfld then
            local value = entry.sortkey
            if value == oldvalue then
                if suffix == 0 then
                    suffix = 1
                    local entry = source[i-1]
                    setsuffix(entry,suffix,sortfld)
                end
                suffix = suffix + 1
                setsuffix(entry,suffix,sortfld)
            else
                oldvalue = value
                suffix   = 0
            end
        else
            break
        end
    end
    --
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
        local current = entry.sortkey
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
-- local target = compresslist(source)

local numberonly = R("09")^1 / tonumber + P(1)^0
local f_missing  = formatters["<%s>"]

-- maybe also sparse (e.g. pages)

local function processcite(dataset,reference,mark,compress,setup,getter,setter,compressor)
    reference = publications.parenttag(dataset,reference)
    local found, todo, list = findallused(dataset,reference)
    if found and setup then
        local source = { }
        local badkey = false
        for i=1,#found do
            local entry    = found[i]
            local tag      = entry.userdata.btxref
            local internal = entry.references.internal
            local data     = getter(dataset,tag,entry,internal)
            if compress and not compressor then
                local sortkey = data.sortkey
                if sortkey then
                    local key = lpegmatch(numberonly,sortkey)
                    if key then
                        data.sortkey = key
                    else
                        badkey = true
                    end
                else
                    badkey = true
                end
            end
            source[i] = data
        end
        if compress and not badkey then
            local target  = (compressor or compresslist)(source)
            local function flush(i,state)
                local entry = target[i]
                local first = entry.first
                if first then
                    local tags = entry.tags
                    if mark then
                        for i=1,#tags do
                            local tag = tags[i]
                            markcite(dataset,tag)
                            todo[tag] = false
                        end
                    end
                    ctx_btxsettag(tags[1])
                    local internal = first.internal
                    if internal then
                        ctx_btxsetinternal(internal)
                    end
                    if not setter(first,entry.last) then
                        ctx_btxsetfirst(f_missing(first.tag))
                    end
                else
                    local tag = entry.tag
                    if mark then
                        markcite(dataset,tag)
                        todo[tag] = false
                    end
                    ctx_btxsettag(tag)
                    local internal = entry.internal
                    if internal then
                        ctx_btxsetinternal(internal)
                    end
                    if not setter(entry) then
                        ctx_btxsetfirst(f_missing(tag))
                    end
                end
                ctx_btxsetconcat(state)
                ctx_btxcitesetup(setup)
            end
            flushcollected(flush,#target)
        else
            local function flush(i,state)
                local entry = source[i]
                local tag   = entry.tag
                if mark then
                    markcite(dataset,tag)
                    todo[tag] = false
                end
                ctx_btxsettag(tag)
                local internal = entry.internal
                if internal then
                    ctx_btxsetinternal(internal)
                end
                ctx_btxsetconcat(state)
                if not setter(entry) then
                    ctx_btxsetfirst(f_missing(entry.tag))
                end
                ctx_btxcitesetup(setup)
            end
            flushcollected(flush,#source)
        end
    end
    if mark then
        flushmarked(dataset,list,todo)
    end
end

local function simplegetter(first,last,field)
    local value = first[field]
    if value then
        ctx_btxsetfirst(value)
        if last then
            ctx_btxsetsecond(last[field])
        end
        return true
    end
end

local setters = setmetatableindex({},function(t,k)
    local v = function(dataset,tag,entry,internal)
        local value = getfield(dataset,tag,k)
        return {
            tag      = tag,
            internal = internal,
            [k]      = value,
            sortkey  = value,
            sortfld  = k,
        }
    end
    t[k] = v
    return v
end)

local getters = setmetatableindex({},function(t,k)
    local v = function(first,last)
        return simplegetter(first,last,k)
    end
    t[k] = v
    return v
end)

-- default

setmetatableindex(citevariants,function(t,k)
    local v = t.default
    t[k] = v
    return v
end)

function citevariants.default(dataset,reference,mark,compress,variant,setup)
    processcite(dataset,reference,mark,compress,setup or variant,setters[variant],getters[variant])
end

-- short

local function setter(dataset,tag,entry,internal)
    return {
        tag      = tag,
        internal = internal,
        short    = getfield(dataset,tag,"short"),
        suffix   = getfield(dataset,tag,"suffix"),
    }
end

local function getter(first,last) -- last not used
    local short = first.short
    if short then
        local suffix = first.suffix
        if suffix then
            ctx_btxsetfirst(short .. suffix)
        else
            ctx_btxsetfirst(short)
        end
        return true
    end
end

function citevariants.short(dataset,reference,mark,compress)
    processcite(dataset,reference,mark,false,"short",setter,getter)
end

-- pages (no compress)

local function setter(dataset,tag,entry,internal)
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        pages    = getdetail(dataset,tag,"pages"),
    }
end

local function getter(first,last)
    local pages = first.pages
    if pages then
        if type(pages) == "table" then
            ctx_btxsetfirst(pages[1])
            ctx_btxsetsecond(pages[2])
        else
            ctx_btxsetfirst(pages)
        end
        return true
    end
end

function citevariants.page(dataset,reference,mark,compress)
    processcite(dataset,reference,mark,compress,"page",setter,getter)
end

-- num

local function setter(dataset,tag,entry,internal)
    local text = entry.entries.text
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        num      = text,
        sortkey  = text,
    }
end

local function getter(first,last)
    return simplegetter(first,last,"num")
end

function citevariants.num(dataset,reference,mark,compress)
    processcite(dataset,reference,mark,compress,"num",setter,getter)
end

-- year

local function setter(dataset,tag,entry,internal)
    local year = getfield(dataset,tag,"year")
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        year     = year,
        sortkey  = year,
        sortfld  = "year",
    }
end

local function getter(first,last)
    return simplegetter(first,last,"year")
end

function citevariants.year(dataset,reference,mark,compress)
    processcite(dataset,reference,mark,compress,"year",setter,getter)
end

-- index | serial

local function setter(dataset,tag,entry,internal)
    local index = getfield(dataset,tag,"index")
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        index    = index,
        sortkey  = index,
    }
end

local function getter(first,last)
    return simplegetter(first,last,"index")
end

function citevariants.index(dataset,reference,mark,compress)
    processcite(dataset,reference,mark,compress,"index",setter,getter)
end

function citevariants.serial(dataset,reference,mark,compress)
    processcite(dataset,reference,mark,compress,"serial",setter,getter)
end

-- category | type

local function setter(dataset,tag,entry,internal)
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        category = getfield(dataset,tag,"category"),
    }
end

local function getter(first,last)
    return simplegetter(first,last,"category")
end

function citevariants.category(dataset,reference,mark,compress)
    processcite(dataset,reference,mark,compress,"category",setter,getter)
end

function citevariants.type(dataset,reference,mark,compress)
    processcite(dataset,reference,mark,compress,"type",setter,getter)
end

-- key | tag

local function setter(dataset,tag,entry,internal)
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
    }
end

local function getter(first,last)
    ctx_btxsetfirst(first.tag)
    return true
end

function citevariants.key(dataset,reference,mark,compress) return
    processcite(dataset,reference,mark,compress,"key",setter,getter)
end

function citevariants.tag(dataset,reference,mark,compress) return
    processcite(dataset,reference,mark,compress,"tag",setter,getter)
end

-- author

local function setter(dataset,tag,entry,internal)
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        author   = getfield(dataset,tag,"author"),
    }
end

local function getter(first,last)
    ctx_btxsetfirst(first.author) -- todo: formatted
    return true
end

function citevariants.author(dataset,reference,mark,compress)
    processcite(dataset,reference,mark,false,"author",setter,getter)
end

-- todo : sort
-- todo : choose between publications or commands namespace
-- todo : use details.author
-- todo : sort details.author
-- (name, name and name) .. how names? how sorted?
-- todo: we loop at the tex end .. why not here
-- \cite[{hh,afo},kvm]

-- common

local function authorcompressor(found,key)
    local result  = { }
    local entries = { }
    for i=1,#found do
        local entry    = found[i]
        local author   = entry.author
        local aentries = entries[author]
        if aentries then
            aentries[#aentries+1] = entry
        else
            entries[author] = { entry }
        end
    end
    for i=1,#found do
        local entry    = found[i]
        local author   = entry.author
        local aentries = entries[author]
        if not aentries then
            result[#result+1] = entry
        elseif aentries == true then
            -- already done
        else
            result[#result+1] = entry
            entry.entries = aentries
            entries[author] = true
        end
    end
    -- todo: add letters (should we then tag all?)
    return result
end

local function authorconcat(target,key,setup)
    local function flush(i,state)
        local entry = target[i]
        local first = entry.first
        if first then
            local internal = first.internal
            if internal then
                ctx_btxsetinternal(internal)
            end
            ctx_btxsetfirst(first[key] or f_missing(first.tag))
            local suffix = entry.suffix
            local value  = entry.last[key]
            if suffix then
                ctx_btxsetsecond(value .. converters.characters(suffix))
            else
                ctx_btxsetsecond(value)
            end
        else
            local internal = entry.internal
            if internal then
                ctx_btxsetinternal(internal)
            end
            local suffix = entry.suffix
            local value  = entry[key] or f_missing(entry.tag)
            if suffix then
                ctx_btxsetfirst(value .. converters.characters(suffix))
            else
                ctx_btxsetfirst(value)
            end
        end
        ctx_btxsetconcat(state)
        ctx_btxcitesetup(setup)
    end
    ctx_btxstartsubcite(setup)
    flushcollected(flush,#target)
    ctx_btxstopsubcite()
end

local function authorsingle(entry,key,setup)
    ctx_btxstartsubcite(setup)
    local internal = entry.internal
    if internal then
        ctx_btxsetinternal(internal)
    end
    ctx_btxsetfirst(entry[key] or f_missing(entry.tag))
    ctx_btxcitesetup(setup) -- ??
    ctx_btxstopsubcite()
end

local function authorgetter(first,last,key,setup) -- only first
    ctx_btxsetfirst(first.author) -- todo: reformat
    local entries = first.entries
    if entries then
        local c = compresslist(entries)
        ctx_btxsetsecond(function() authorconcat(c,key,setup) end)
    else
        ctx_btxsetsecond(function() authorsingle(first,key,setup) end)
    end
    return true
end

-- authornum

local function setter(dataset,tag,entry,internal)
    local text = entry.entries.text
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        author   = getfield(dataset,tag,"author"),
        num      = text,
        sortkey  = text and lpegmatch(numberonly,text)
    }
end

local function getter(first,last)
    authorgetter(first,last,"num","author:num")
    return true
end

local function compressor(found)
    return authorcompressor(found,"num")
end

function citevariants.authornum(dataset,reference,mark,compress)
    processcite(dataset,reference,mark,compress,"authornum",setter,getter,compressor)
end

-- authoryear | authoryears

local function setter(dataset,tag,entry,internal)
    local year = getfield(dataset,tag,"year")
    return {
        dataset  = dataset,
        tag      = tag,
        internal = internal,
        author   = getfield(dataset,tag,"author"),
        year     = year,
        sortkey  = year and lpegmatch(numberonly,year),
        sortfld  = "year",
    }
end

local function getter(first,last)
    authorgetter(first,last,"year","author:year")
    return true
end

local function compressor(found)
    return authorcompressor(found,"year")
end

function citevariants.authoryear(dataset,reference,mark,compress)
    processcite(dataset,reference,mark,compress,"authoryear",setter,getter,compressor)
end

local function getter(first,last)
    authorgetter(first,last,"year","author:years")
    return true
end

function citevariants.authoryears(dataset,reference,mark,compress)
    processcite(dataset,reference,mark,compress,"authoryears",setter,getter,compressor)
end

-- List variants

local listvariants        = { }
publications.listvariants = listvariants

function commands.btxlistvariant(dataset,block,tag,variant,listindex)
    local action = listvariants[variant] or listvariants.default
    if action then
        action(dataset,block,tag,variant,tonumber(listindex) or 0)
    end
end

function listvariants.default(dataset,block,tag,variant)
    context("?")
end

-- function listvariants.num(dataset,block,tag,variant,listindex)
--     local lst = f_listentry(dataset,block,tag)
--     local ref = f_reference(dataset,block,tag)
--     if trace_references then
--         report_reference("list: %s",lst)
--     end
--     -- todo
--     ctx_btxdirectlink(ref,listindex) -- a goto
-- end

function listvariants.num(dataset,block,tag,variant,listindex)
    context(listindex) -- a goto
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
