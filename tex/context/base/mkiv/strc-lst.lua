if not modules then modules = { } end modules ['strc-lst'] = {
    version   = 1.001,
    comment   = "companion to strc-lst.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- when all datastructures are stable a packer will be added which will
-- bring down memory consumption a bit; we can use for instance a pagenumber,
-- section, metadata cache (internal then has to move up one level) or a
-- shared cache [we can use a fast and stupid serializer]

-- todo: tag entry in list is crap
--
-- move more to commands

local tonumber, type, next = tonumber, type, next
local concat, insert, remove, sort = table.concat, table.insert, table.remove, table.sort
local lpegmatch = lpeg.match

local setmetatableindex = table.setmetatableindex
local sortedkeys        = table.sortedkeys

local settings_to_set   = utilities.parsers.settings_to_set
local allocate          = utilities.storage.allocate
local checked           = utilities.storage.checked

local trace_lists       = false  trackers.register("structures.lists", function(v) trace_lists = v end)

local report_lists      = logs.reporter("structure","lists")

local context           = context
local commands          = commands
local implement         = interfaces.implement
local conditionals      = tex.conditionals

local ctx_latelua       = context.latelua

local structures        = structures
local lists             = structures.lists
local sections          = structures.sections
local helpers           = structures.helpers
local documents         = structures.documents
local tags              = structures.tags
local counters          = structures.counters
local references        = structures.references

local collected         = allocate()
local tobesaved         = allocate()
local cached            = allocate()
local pushed            = allocate()
local kinds             = allocate()
local names             = allocate()

lists.collected         = collected
lists.tobesaved         = tobesaved

lists.enhancers         = lists.enhancers or { }
-----.internals         = allocate(lists.internals or { }) -- to be checked
lists.ordered           = allocate(lists.ordered   or { }) -- to be checked
lists.cached            = cached
lists.pushed            = pushed
lists.kinds             = kinds
lists.names             = names

local sorters           = sorters
local sortstripper      = sorters.strip
local sortsplitter      = sorters.splitters.utf
local sortcomparer      = sorters.comparers.basic

local sectionblocks     = allocate()
lists.sectionblocks     = sectionblocks

references.specials     = references.specials or { }

local matchingtilldepth = sections.matchingtilldepth
local numberatdepth     = sections.numberatdepth
local getsectionlevel   = sections.getlevel
local typesetnumber     = sections.typesetnumber
local autosectiondepth  = sections.autodepth

local variables         = interfaces.variables

local v_all             = variables.all
local v_reference       = variables.reference
local v_title           = variables.title
local v_command         = variables.command
local v_text            = variables.text
local v_current         = variables.current
local v_previous        = variables.previous
local v_intro           = variables.intro
local v_here            = variables.here
local v_component       = variables.component
local v_reference       = variables.reference
local v_local           = variables["local"]
local v_default         = variables.default

-- for the moment not public --

local function zerostrippedconcat(t,separator)
    local f = 1
    local l = #t
    for i=f,l do
        if t[i] == 0 then
            f = f + 1
        end
    end
    for i=l,f,-1 do
        if t[i] == 0 then
            l = l - 1
        end
    end
    return concat(t,separator,f,l)
end

-- -- -- -- -- --

local function initializer()
    -- create a cross reference between internal references
    -- and list entries
    local collected     = lists.collected
    local internals     = checked(references.internals)
    local ordered       = lists.ordered
    local usedinternals = references.usedinternals
    local blockdone     = { }
    local lastblock     = nil
    for i=1,#collected do
        local c = collected[i]
        local m = c.metadata
        local r = c.references
        if m then
            -- access by internal reference
            if r then
                local internal = r.internal
                if internal then
                    internals[internal] = c
                    usedinternals[internal] = r.used
                end
                local block = r.block
                if not block then
                    -- shouldn't happen
                elseif lastblock == block then
                    -- we're okay
                elseif lastblock then
                    if blockdone[block] then
                        report_lists("out of order sectionsblocks, maybe use \\setsectionblock")
                    else
                        blockdone[block] = true
                        sectionblocks[#sectionblocks+1] = block
                    end
                    lastblock = block
                elseif not blockdone[block] then
                    blockdone[block] = true
                    sectionblocks[#sectionblocks+1] = block
                    lastblock = block
                end
            end
            -- access by order in list
            local kind = m.kind
            local name = m.name
            if kind and name then
                local ok = ordered[kind]
                if ok then
                    local on = ok[name]
                    if on then
                        on[#on+1] = c
                    else
                        ok[name] = { c }
                    end
                else
                    ordered[kind] = { [name] = { c } }
                end
                kinds[kind] = true
                names[name] = true
            elseif kind then
                kinds[kind] = true
            elseif name then
                names[name] = true
            end
        end
        if r then
            r.listindex = i -- handy to have
        end
    end
end

local function finalizer()
    local flaginternals = references.flaginternals
    local usedviews     = references.usedviews
    for i=1,#tobesaved do
        local r = tobesaved[i].references
        if r then
            local i = r.internal
            local f = flaginternals[i]
            if f then
                r.used = usedviews[i] or true
            end
        end
    end
end

job.register('structures.lists.collected', tobesaved, initializer, finalizer)

local groupindices = setmetatableindex("table")

function lists.groupindex(name,group)
    local groupindex = groupindices[name]
    return groupindex and groupindex[group] or 0
end

-- we could use t (as hash key) in order to check for dup entries

function lists.addto(t) -- maybe more more here (saves parsing at the tex end)
    local metadata   = t.metadata
    local userdata   = t.userdata
    local numberdata = t.numberdata
    if userdata and type(userdata) == "string" then
        t.userdata = helpers.touserdata(userdata)
    end
    if not metadata.level then
        metadata.level = structures.sections.currentlevel() -- this is not used so it will go away
    end
    --
 -- if not conditionals.inlinelefttoright then
 --     metadata.idir = "r2l"
 -- end
 -- if not conditionals.displaylefttoright then
 --     metadata.ddir = "r2l"
 -- end
    --
    if numberdata then
        local numbers = numberdata.numbers
        if type(numbers) == "string" then
            numberdata.numbers = counters.compact(numbers,nil,true)
        end
    end
    local group = numberdata and numberdata.group
    local name  = metadata.name
    local kind  = metadata.kind
    if not group then
        -- forget about it
    elseif group == "" then
        group, numberdata.group = nil, nil
    else
        local groupindex = groupindices[name][group]
        if groupindex then
            numberdata.numbers = cached[groupindex].numberdata.numbers
        end
    end
    local setcomponent = references.setcomponent
    if setcomponent then
        setcomponent(t) -- can be inlined
    end
    local r = t.references
    if r and not r.section then
        r.section = structures.sections.currentid()
    end
    local i = r and r.internal or 0 -- brrr
    if r and kind and name then
        local tag = tags.getid(kind,name)
        if tag and tag ~= "?" then
            r.tag = tag -- todo: use internal ... is unique enough
        end
    end
    local p = pushed[i]
    if not p then
        p = #cached + 1
        cached[p] = helpers.simplify(t)
        pushed[i] = p
        if r then
            r.listindex = p
        end
    end
    if group then
        groupindices[name][group] = p
    end
    if trace_lists then
        report_lists("added %a, internal %a",name,p)
    end
    return p
end

function lists.discard(n)
    n = tonumber(n)
    if not n then
        -- maybe an error message
    elseif n == #cached then
        cached[n] = nil
        n = n - 1
        while n > 0 and cached[n] == false do
            cached[n] = nil -- collect garbage
            n = n - 1
        end
    else
        cached[n] = false
    end
end

function lists.iscached(n)
    return cached[tonumber(n)]
end

-- this is the main pagenumber enhancer

local enhanced = { }

local synchronizepage = function(r)  -- bah ... will move
    synchronizepage = references.synchronizepage
    return synchronizepage(r)
end

local function enhancelist(specification)
    local n = specification.n
    local l = cached[n]
    if not l then
        report_lists("enhancing %a, unknown internal",n)
    elseif enhanced[n] then
        if trace_lists then
            report_lists("enhancing %a, name %a, duplicate ignored",n,name)
        end
    else
        local metadata   = l.metadata
        local references = l.references
        --
        l.directives = nil -- might change
        -- save in the right order (happens at shipout)
        lists.tobesaved[#lists.tobesaved+1] = l
        -- default enhancer (cross referencing)
        synchronizepage(references)
        -- tags
        local kind = metadata.kind
        local name = metadata.name
        if trace_lists then
            report_lists("enhancing %a, name %a, page %a",n,name,references.realpage or 0)
        end
--         if references then
--             -- is this used ?
--             local tag = tags.getid(kind,name)
--             if tag and tag ~= "?" then
--                 references.tag = tag
--             end
--         end
        -- specific enhancer (kind of obsolete)
        local enhancer = kind and lists.enhancers[kind]
        if enhancer then
            enhancer(l)
        end
        --
        enhanced[n] = true
        return l
    end
end

lists.enhance = enhancelist

-- we can use level instead but we can also decide to remove level from the metadata

local nesting = { }

function lists.pushnesting(i)
    local parent     = lists.result[i]
    local name       = parent.metadata.name
    local numberdata = parent and parent.numberdata
    local numbers    = numberdata and numberdata.numbers
    local number     = numbers and numbers[getsectionlevel(name)] or 0
    insert(nesting, {
        number = number,
        name   = name,
        result = lists.result,
        parent = parent
    })
end

function lists.popnesting()
    local old = remove(nesting)
    if old then
        lists.result = old.result
    else
        report_lists("nesting error")
    end
end

-- Historically we had blocks but in the mkiv approach that could as well be a level
-- which would simplify things a bit.

local splitter = lpeg.splitat(":") -- maybe also :: or have a block parameter

local listsorters = {
    [v_command] = function(a,b)
        if a.metadata.kind == "command" or b.metadata.kind == "command" then
            return a.references.internal < b.references.internal
        else
            return a.references.order < b.references.order
        end
    end,
    [v_all] = function(a,b)
        return a.references.internal < b.references.internal
    end,
    [v_title] = function(a,b)
        local da = a.titledata
        local db = b.titledata
        if da and db then
            local ta = da.title
            local tb = db.title
            if ta and tb then
                local sa = da.split
                if not sa then
                    sa = sortsplitter(sortstripper(ta))
                    da.split = sa
                end
                local sb = db.split
                if not sb then
                    sb = sortsplitter(sortstripper(tb))
                    db.split = sb
                end
                return sortcomparer(da,db) == -1
            end
        end
        return a.references.internal < b.references.internal
    end
}

-- was: names, criterium, number, collected, forced, nested, sortorder

local filters = setmetatableindex(function(t,k) return t[v_default] end)

local function filtercollected(specification)
    --
    local names     = specification.names     or { }
    local criterium = specification.criterium or v_default
    local number    = 0 -- specification.number
    local reference = specification.reference or ""
    local collected = specification.collected or lists.collected
    local forced    = specification.forced    or { }
    local nested    = specification.nested    or false
    local sortorder = specification.sortorder or specification.order
    --
    local numbers   = documents.data.numbers
    local depth     = documents.data.depth
    local block     = false -- all
    local wantedblock, wantedcriterium = lpegmatch(splitter,criterium) -- block:criterium
    if wantedblock == "" or wantedblock == v_all or wantedblock == v_text then
        criterium = wantedcriterium ~= "" and wantedcriterium or criterium
    elseif not wantedcriterium then
        block = documents.data.block
    else
        block, criterium = wantedblock, wantedcriterium
    end
    if block == "" then
        block = false
    end
    if type(names) == "string" then
        names = settings_to_set(names)
    end
    local all = not next(names) or names[v_all] or false
    --
    specification.names     = names
    specification.criterium = criterium
    specification.number    = 0 -- obsolete
    specification.reference = reference -- new
    specification.collected = collected
    specification.forced    = forced -- todo: also on other branched, for the moment only needed for bookmarks
    specification.nested    = nested
    specification.sortorder = sortorder
    specification.numbers   = numbers
    specification.depth     = depth
    specification.block     = block
    specification.all       = all
    --
    if trace_lists then
        report_lists("filtering names %,t, criterium %a, block %a",sortedkeys(names), criterium, block or "*")
    end
    local result = filters[criterium](specification)
    if trace_lists then
        report_lists("criterium %a, block %a, found %a",specification.criterium, specification.block or "*", #result)
    end
    --
    if sortorder then -- experiment
        local sorter = listsorters[sortorder]
        if sorter then
            if trace_lists then
                report_lists("sorting list using method %a",sortorder)
            end
            for i=1,#result do
                result[i].references.order = i
            end
            sort(result,sorter)
        end
    end
    --
    return result
end

filters[v_intro] = function(specification)
    local collected = specification.collected
    local result    = { }
    local nofresult = #result
    local all       = specification.all
    local names     = specification.names
    for i=1,#collected do
        local v = collected[i]
        local metadata = v.metadata
        if metadata and (all or names[metadata.name or false]) then
            local r = v.references
            if r and r.section == 0 then
                nofresult = nofresult + 1
                result[nofresult] = v
            end
        end
    end
    return result
end

filters[v_reference] = function(specification)
    local collected = specification.collected
    local result    = { }
    local nofresult = #result
    local names     = specification.names
    local sections  = sections.collected
    local reference = specification.reference
    if reference ~= "" then
        local prefix, rest = lpegmatch(references.prefixsplitter,reference) -- p::r
        local r = prefix and rest and references.derived[prefix][rest] or references.derived[""][reference]
        local s = r and r.numberdata -- table ref !
        if s then
            local depth   = getsectionlevel(r.metadata.name)
            local numbers = s.numbers
            for i=1,#collected do
                local v = collected[i]
                local r = v.references
                if r and (not block or not r.block or block == r.block) then
                    local metadata = v.metadata
                    if metadata and names[metadata.name or false] then
                        local sectionnumber = (r.section == 0) or sections[r.section]
                        if sectionnumber then
                            if matchingtilldepth(depth,numbers,sectionnumber.numbers) then
                                nofresult = nofresult + 1
                                result[nofresult] = v
                            end
                        end
                    end
                end
            end
        else
            report_lists("unknown reference %a specified",reference)
        end
    else
        report_lists("no reference specified")
    end
    return result
end

filters[v_all] = function(specification)
    local collected = specification.collected
    local result    = { }
    local nofresult = #result
    local block     = specification.block
    local all       = specification.all
    local forced    = specification.forced
    local names     = specification.names
    local sections  = sections.collected
    for i=1,#collected do
        local v = collected[i]
        local r = v.references
        if r and (not block or not r.block or block == r.block) then
            local metadata = v.metadata
            if metadata then
                local name = metadata.name or false
                local sectionnumber = (r.section == 0) or sections[r.section]
                if forced[name] or (sectionnumber and not metadata.nolist and (all or names[name])) then -- and not sectionnumber.hidenumber then
                    nofresult = nofresult + 1
                    result[nofresult] = v
                end
            end
        end
    end
    return result
end

filters[v_text] = filters[v_all]

filters[v_current] = function(specification)
    if specification.depth == 0 then
        specification.nested    = false
        specification.criterium = v_intro
        return filters[v_intro](specification)
    end
    local collected = specification.collected
    local result    = { }
    local nofresult = #result
    local depth     = specification.depth
    local block     = specification.block
    local all       = specification.all
    local names     = specification.names
    local numbers   = specification.numbers
    local sections  = sections.collected
    for i=1,#collected do
        local v = collected[i]
        local r = v.references
        if r and (not block or not r.block or block == r.block) then
            local sectionnumber = sections[r.section]
            if sectionnumber then -- and not sectionnumber.hidenumber then
                local cnumbers = sectionnumber.numbers
                local metadata = v.metadata
                if cnumbers then
                    if metadata and not metadata.nolist and (all or names[metadata.name or false]) and #cnumbers > depth then
                        local ok = true
                        for d=1,depth do
                            local cnd = cnumbers[d]
                            if not (cnd == 0 or cnd == numbers[d]) then
                                ok = false
                                break
                            end
                        end
                        if ok then
                            nofresult = nofresult + 1
                            result[nofresult] = v
                        end
                    end
                end
            end
        end
    end
    return result
end

filters[v_here] = function(specification)
    -- this is quite dirty ... as cnumbers is not sparse we can misuse #cnumbers
    if specification.depth == 0 then
        specification.nested    = false
        specification.criterium = v_intro
        return filters[v_intro](specification)
    end
    local collected = specification.collected
    local result    = { }
    local nofresult = #result
    local depth     = specification.depth
    local block     = specification.block
    local all       = specification.all
    local names     = specification.names
    local numbers   = specification.numbers
    local sections  = sections.collected
    for i=1,#collected do
        local v = collected[i]
        local r = v.references
        if r then -- and (not block or not r.block or block == r.block) then
            local sectionnumber = sections[r.section]
            if sectionnumber then -- and not sectionnumber.hidenumber then
                local cnumbers = sectionnumber.numbers
                local metadata = v.metadata
                if cnumbers then
                    if metadata and not metadata.nolist and (all or names[metadata.name or false]) and #cnumbers >= depth then
                        local ok = true
                        for d=1,depth do
                            local cnd = cnumbers[d]
                            if not (cnd == 0 or cnd == numbers[d]) then
                                ok = false
                                break
                            end
                        end
                        if ok then
                            nofresult = nofresult + 1
                            result[nofresult] = v
                        end
                    end
                end
            end
        end
    end
    return result
end

filters[v_previous] = function(specification)
    if specification.depth == 0 then
        specification.nested    = false
        specification.criterium = v_intro
        return filters[v_intro](specification)
    end
    local collected = specification.collected
    local result    = { }
    local nofresult = #result
    local block     = specification.block
    local all       = specification.all
    local names     = specification.names
    local numbers   = specification.numbers
    local sections  = sections.collected
    local depth     = specification.depth
    for i=1,#collected do
        local v = collected[i]
        local r = v.references
        if r and (not block or not r.block or block == r.block) then
            local sectionnumber = sections[r.section]
            if sectionnumber then -- and not sectionnumber.hidenumber then
                local cnumbers = sectionnumber.numbers
                local metadata = v.metadata
                if cnumbers then
                    if metadata and not metadata.nolist and (all or names[metadata.name or false]) and #cnumbers >= depth then
                        local ok = true
                        for d=1,depth-1 do
                            local cnd = cnumbers[d]
                            if not (cnd == 0 or cnd == numbers[d]) then
                                ok = false
                                break
                            end
                        end
                        if ok then
                            nofresult = nofresult + 1
                            result[nofresult] = v
                        end
                    end
                end
            end
        end
    end
    return result
end

filters[v_local] = function(specification)
    local numbers = specification.numbers
    local nested  = nesting[#nesting]
    if nested then
        return filtercollected {
            names     = specification.names,
            criterium = nested.name,
            collected = specification.collected,
            forced    = specification.forced,
            nested    = nested,
            sortorder = specification.sortorder,
        }
    else
        specification.criterium = autosectiondepth(numbers) == 0 and v_all or v_current
        specification.nested    = false
        return filtercollected(specification) -- rechecks, so better (for determining all)
    end
end


filters[v_component] = function(specification)
    -- special case, no structure yet
    local collected = specification.collected
    local result    = { }
    local nofresult = #result
    local all       = specification.all
    local names     = specification.names
    local component = resolvers.jobs.currentcomponent() or ""
    if component ~= "" then
        for i=1,#collected do
            local v = collected[i]
            local r = v.references
            local m = v.metadata
            if r and r.component == component and (m and names[m.name] or all) then
                nofresult = nofresult + 1
                result[nofresult] = v
            end
        end
    end
    return result
end

-- local number = tonumber(number) or numberatdepth(depth) or 0
-- if number > 0 then
--     ...
-- end

filters[v_default] = function(specification) -- is named
    local collected = specification.collected
    local result    = { }
    local nofresult = #result
    ----- depth     = specification.depth
    local block     = specification.block
    local criterium = specification.criterium
    local all       = specification.all
    local names     = specification.names
    local numbers   = specification.numbers
    local sections  = sections.collected
    local reference = specification.reference
    local nested    = specification.nested
    --
    if reference then
        reference = tonumber(reference)
    end
    --
    local depth     = getsectionlevel(criterium)
    local pnumbers  = nil
    local pblock    = block
    local parent    = nested and nested.parent
    --
    if parent then
        pnumbers = parent.numberdata.numbers or pnumbers -- so local as well as nested
        pblock   = parent.references.block or pblock
        if trace_lists then
            report_lists("filtering by block %a and section %a",pblock,criterium)
        end
    end
    --
    for i=1,#collected do
        local v = collected[i]
        local r = v.references
        if r and (not block or not r.block or pblock == r.block) then
            local sectionnumber = sections[r.section]
            if sectionnumber then
                local metadata = v.metadata
                local cnumbers = sectionnumber.numbers
                if cnumbers then
                    if all or names[metadata.name or false] then
                        if reference then
                            -- filter by number
                            if reference == cnumbers[depth] then
                                nofresult = nofresult + 1
                                result[nofresult] = v
                            end
                        else
                            if #cnumbers >= depth and matchingtilldepth(depth,cnumbers,pnumbers) then
                                nofresult = nofresult + 1
                                result[nofresult] = v
                            end
                        end
                    end
                end
            end
        end
    end
    return result
end

-- names, criterium, number, collected, forced, nested, sortorder) -- names is hash or string

lists.filter = filtercollected

lists.result = { }

function lists.getresult(r)
    return lists.result[r]
end

function lists.process(specification)
    lists.result = filtercollected(specification)
    local specials = settings_to_set(specification.extras or "")
    specials = next(specials) and specials or nil
    for i=1,#lists.result do
        local r = lists.result[i]
        local m = r.metadata
        local s = specials and r.numberdata and specials[zerostrippedconcat(r.numberdata.numbers,".")] or ""
        context.strclistsentryprocess(m.name,m.kind,i,s)
    end
end

function lists.analyze(specification)
    lists.result = filtercollected(specification)
end

function lists.userdata(name,r,tag) -- to tex (todo: xml)
    local result = lists.result[r]
    if result then
        local userdata = result.userdata
        local str = userdata and userdata[tag]
        if str then
            return str, result.metadata
        end
    end
end

function lists.uservalue(name,r,tag,default) -- to lua
    local str = lists.result[r]
    if str then
        str = str.userdata
    end
    if str then
        str = str[tag]
    end
    return str or default
end

function lists.size()
    return #lists.result
end

function lists.location(n)
    local l = lists.result[n]
    return l and l.references.internal or n
end

function lists.label(n,default)
    local l = lists.result[n]
    local t = l.titledata
    return t and t.label or default or ""
end

function lists.sectionnumber(name,n,spec)
    local data = lists.result[n]
    local sectiondata = sections.collected[data.references.section]
    -- hm, prefixnumber?
    typesetnumber(sectiondata,"prefix",spec,sectiondata) -- data happens to contain the spec too
end

-- some basics (todo: helpers for pages)

function lists.title(name,n,tag) -- tag becomes obsolete
    local data = lists.result[n]
    if data then
        local titledata = data.titledata
        if titledata then
            helpers.title(titledata[tag] or titledata.list or titledata.title or "",data.metadata)
        end
    end
end

function lists.hastitledata(name,n,tag)
    local data = cached[tonumber(n)]
    if data then
        local titledata = data.titledata
        if titledata then
            return (titledata[tag] or titledata.title or "") ~= ""
        end
    end
    return false
end

function lists.haspagedata(name,n)
    local data = lists.result[n]
    if data then
        local references = data.references
        if references and references.realpage then -- or references.pagedata
            return true
        end
    end
    return false
end

function lists.hasnumberdata(name,n)
    local data = lists.result[n]
    if data then
        local numberdata = data.numberdata
        if numberdata and not numberdata.hidenumber then -- the hide number is true
            return true
        end
    end
    return false
end

function lists.prefix(name,n,spec)
    helpers.prefix(lists.result[n],spec)
end

function lists.page(name,n,pagespec)
    helpers.page(lists.result[n],pagespec)
end

function lists.prefixedpage(name,n,prefixspec,pagespec)
    helpers.prefixpage(lists.result[n],prefixspec,pagespec)
end

function lists.realpage(name,n)
    local data = lists.result[n]
    if data then
        local references = data.references
        return references and references.realpage or 0
    else
        return 0
    end
end

-- numbers stored in entry.numberdata + entry.numberprefix

function lists.number(name,n,spec)
    local data = lists.result[n]
    if data then
        local numberdata = data.numberdata
        if numberdata then
            typesetnumber(numberdata,"number",spec or false,numberdata or false)
        end
    end
end

function lists.prefixednumber(name,n,prefixspec,numberspec,forceddata)
    local data = lists.result[n]
    if data then
        helpers.prefix(data,prefixspec)
        local numberdata = data.numberdata or forceddata
        if numberdata then
            typesetnumber(numberdata,"number",numberspec or false,numberdata or false)
        end
    end
end

-- todo, do this in references namespace ordered instead (this is an experiment)
--
-- also see lpdf-ano (maybe move this there)

local splitter = lpeg.splitat(":")

function references.specials.order(var,actions) -- references.specials !
    local operation = var.operation
    if operation then
        local kind, name, n = lpegmatch(splitter,operation)
        local order = lists.ordered[kind]
        order = order and order[name]
        local v = order[tonumber(n)]
        local r = v and v.references.realpage
        if r then
            actions.realpage = r
            var.operation = r -- brrr, but test anyway
            return references.specials.page(var,actions)
        end
    end
end

-- interface (maybe strclistpush etc)

if not lists.reordered then
    function lists.reordered(data)
        return data.numberdata
    end
end

implement { name = "pushlist", actions = lists.pushnesting, arguments = "integer" }
implement { name = "poplist",  actions = lists.popnesting  }

implement {
    name      = "addtolist",
    actions   = { lists.addto, context },
    arguments = {
        {
            { "references", {
                    { "internal", "integer" },
                    { "block" },
                    { "section", "integer" },
                    { "location" },
                    { "prefix" },
                    { "reference" },
                    { "view" },
                    { "order", "integer" },
                }
            },
            { "metadata", {
                    { "kind" },
                    { "name" },
                    { "level", "integer" },
                    { "catcodes", "integer" },
                    { "coding" },
                    { "xmlroot" },
                    { "setup" },
                }
            },
            { "userdata" },
            { "titledata", {
                    { "label" },
                    { "title" },
                    { "bookmark" },
                    { "marking" },
                    { "list" },
                }
            },
            { "prefixdata", {
                    { "prefix" },
                    { "separatorset" },
                    { "conversionset" },
                    { "conversion" },
                    { "set" },
                    { "segments" },
                    { "connector" },
                }
            },
            { "numberdata", {
                    { "numbers" },
                    { "groupsuffix" },
                    { "group" },
                    { "counter" },
                    { "separatorset" },
                    { "conversionset" },
                    { "conversion" },
                    { "starter" },
                    { "stopper" },
                    { "segments" },
                }
            }
        }
    }
}

implement {
    name      = "enhancelist",
    arguments = "integer",
    actions   = function(n)
        enhancelist { n = n }
    end
}

implement {
    name      = "deferredenhancelist",
    arguments = "integer",
    protected = true, -- for now, pre 1.09
    actions   = function(n)
        ctx_latelua { action = enhancelist, n = n }
    end,
}

implement {
    name      = "processlist",
    actions   = lists.process,
    arguments = {
        {
            { "names" },
            { "criterium" },
            { "reference" },
            { "extras" },
            { "order" },
        }
    }
}

implement {
    name      = "analyzelist",
    actions   = lists.analyze,
    arguments = {
        {
            { "names" },
            { "criterium" },
            { "reference" },
        }
    }
}

implement {
    name      = "listtitle",
    actions   = lists.title,
    arguments = { "string", "integer" }
}

implement {
    name      = "listprefixednumber",
    actions   = lists.prefixednumber,
    arguments = {
        "string",
        "integer",
        {
            { "prefix" },
            { "separatorset" },
            { "conversionset" },
            { "starter" },
            { "stopper" },
            { "set" },
            { "segments" },
            { "connector" },
        },
        {
            { "separatorset" },
            { "conversionset" },
            { "starter" },
            { "stopper" },
            { "segments" },
        }
    }
}

implement {
    name      = "listprefixedpage",
    actions   = lists.prefixedpage,
    arguments = {
        "string",
        "integer",
        {
            { "separatorset" },
            { "conversionset" },
            { "set" },
            { "segments" },
            { "connector" },
        },
        {
            { "prefix" },
            { "conversionset" },
            { "starter" },
            { "stopper" },
        }
    }
}

implement { name = "listsize",       actions = { lists.size, context } }
implement { name = "listlocation",   actions = { lists.location, context }, arguments = "integer" }
implement { name = "listlabel",      actions = { lists.label, context }, arguments = { "integer", "string" } }
implement { name = "listrealpage",   actions = { lists.realpage, context }, arguments = { "string", "integer" } }
implement { name = "listgroupindex", actions = { lists.groupindex, context }, arguments = "2 strings", }

implement {
    name    = "currentsectiontolist",
    actions = { sections.current, lists.addto, context }
}

local function userdata(name,r,tag)
    local str, metadata = lists.userdata(name,r,tag)
    if str then
     -- local catcodes = metadata and metadata.catcodes
     -- if catcodes then
     --     context.sprint(catcodes,str)
     -- else
     --     context(str)
     -- end
        helpers.title(str,metadata)
    end
end

implement {
    name      = "listuserdata",
    actions   = userdata,
    arguments = { "string", "integer", "string" }
}

-- we could also set variables .. names will change (when this module is done)
-- maybe strc_lists_savedtitle etc

implement { name = "doifelselisthastitle",  actions = { lists.hastitledata,  commands.doifelse }, arguments = { "string", "integer" } }
implement { name = "doifelselisthaspage",   actions = { lists.haspagedata,   commands.doifelse }, arguments = { "string", "integer" } }
implement { name = "doifelselisthasnumber", actions = { lists.hasnumberdata, commands.doifelse }, arguments = { "string", "integer" } }
implement { name = "doifelselisthasentry",  actions = { lists.iscached,      commands.doifelse }, arguments = { "integer" } }

local function savedlisttitle(name,n,tag)
    local data = cached[tonumber(n)]
    if data then
        local titledata = data.titledata
        if titledata then
            helpers.title(titledata[tag] or titledata.title or "",data.metadata)
        end
    end
end

local function savedlistnumber(name,n)
    local data = cached[tonumber(n)]
    if data then
        local numberdata = data.numberdata
        if numberdata then
            typesetnumber(numberdata,"number",numberdata or false)
        end
    end
end

local function savedlistprefixednumber(name,n)
    local data = cached[tonumber(n)]
    if data then
        local numberdata = lists.reordered(data)
        if numberdata then
            helpers.prefix(data,data.prefixdata)
            typesetnumber(numberdata,"number",numberdata or false)
        end
    end
end

lists.savedlisttitle          = savedlisttitle
lists.savedlistnumber         = savedlistnumber
lists.savedlistprefixednumber = savedlistprefixednumber

implement {
    name      = "savedlistnumber",
    actions   = savedlistnumber,
    arguments = { "string", "integer" }
}

implement {
    name      = "savedlisttitle",
    actions   = savedlisttitle,
    arguments = { "string", "integer" }
}

implement {
    name      = "savedlistprefixednumber",
    actions   = savedlistprefixednumber,
    arguments = { "string", "integer" }
}

implement {
    name      = "discardfromlist",
    actions   = lists.discard,
    arguments = { "integer" }
}

-- new and experimental and therefore off by default

lists.autoreorder = false -- true

local function addlevel(t,k)
    local v = { }
    setmetatableindex(v,function(t,k)
        local v = { }
        t[k] = v
        return v
    end)
    t[k] = v
    return v
end

local internals = setmetatableindex({ }, function(t,k)

    local sublists = setmetatableindex({ },addlevel)

    local collected = lists.collected or { }

    for i=1,#collected do
        local entry = collected[i]
        local numberdata = entry.numberdata
        if numberdata then
            local metadata = entry.metadata
            if metadata then
                local references = entry.references
                if references then
                    local kind = metadata.kind
                    local name = numberdata.counter or metadata.name
                    local internal = references.internal
                    if kind and name and internal then
                        local sublist = sublists[kind][name]
                        sublist[#sublist + 1] = { internal, numberdata }
                    end
                end
            end
        end
    end

    for k, v in next, sublists do
        for k, v in next, v do
            local tmp = { }
            for i=1,#v do
                tmp[i] = v[i]
            end
            sort(v,function(a,b) return a[1] < b[1] end)
            for i=1,#v do
                t[v[i][1]] = tmp[i][2]
            end
        end
    end

    setmetatableindex(t,nil)

    return t[k]

end)

function lists.reordered(entry)
    local numberdata = entry.numberdata
    if lists.autoreorder then
        if numberdata then
            local metadata = entry.metadata
            if metadata then
                local references = entry.references
                if references then
                    local kind = metadata.kind
                    local name = numberdata.counter or metadata.name
                    local internal = references.internal
                    if kind and name and internal then
                        return internals[internal] or numberdata
                    end
                end
            end
        end
    else
        function lists.reordered(entry)
            return entry.numberdata
        end
    end
    return numberdata
end
