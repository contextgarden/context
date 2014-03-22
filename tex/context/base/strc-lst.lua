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

local format, gmatch, gsub = string.format, string.gmatch, string.gsub
local tonumber, type = tonumber, type
local concat, insert, remove = table.concat, table.insert, table.remove
local lpegmatch = lpeg.match
local simple_hash_to_string, settings_to_hash = utilities.parsers.simple_hash_to_string, utilities.parsers.settings_to_hash
local allocate, checked = utilities.storage.allocate, utilities.storage.checked

local trace_lists       = false  trackers.register("structures.lists", function(v) trace_lists = v end)

local report_lists      = logs.reporter("structure","lists")

local context           = context
local commands          = commands

local texgetcount       = tex.getcount

local structures        = structures
local lists             = structures.lists
local sections          = structures.sections
local helpers           = structures.helpers
local documents         = structures.documents
local pages             = structures.pages
local tags              = structures.tags
local references        = structures.references

local collected         = allocate()
local tobesaved         = allocate()
local cached            = allocate()
local pushed            = allocate()

lists.collected         = collected
lists.tobesaved         = tobesaved

lists.enhancers         = lists.enhancers or { }
-----.internals         = allocate(lists.internals or { }) -- to be checked
lists.ordered           = allocate(lists.ordered   or { }) -- to be checked
lists.cached            = cached
lists.pushed            = pushed

local sectionblocks     = allocate()
lists.sectionblocks     = sectionblocks

references.specials     = references.specials or { }

local variables         = interfaces.variables
local matchingtilldepth = sections.matchingtilldepth
local numberatdepth     = sections.numberatdepth

-- -- -- -- -- --

local function zerostrippedconcat(t,separator) -- for the moment not public
    local f, l = 1, #t
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
    local collected = lists.collected
    local internals = checked(references.internals)
    local ordered   = lists.ordered
    local usedinternals = references.usedinternals
    local blockdone = { }
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
                if block and not blockdone[block] then
                    blockdone[block] = true
                    sectionblocks[#sectionblocks+1] = block
                end
            end
            -- access by order in list
            local kind, name = m.kind, m.name
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
            end
        end
        if r then
            r.listindex = i -- handy to have
        end
    end
end

local function finalizer()
    local flaginternals = references.flaginternals
    for i=1,#tobesaved do
        local r = tobesaved[i].references
        if r and flaginternals[r.internal] then
            r.used = true
        end
    end
end

job.register('structures.lists.collected', tobesaved, initializer, finalizer)

local groupindices = table.setmetatableindex("table")

function lists.groupindex(name,group)
    local groupindex = groupindices[name]
    return groupindex and groupindex[group] or 0
end

-- we could use t (as hash key) in order to check for dup entries

function lists.addto(t)
    local m = t.metadata
    local u = t.userdata
    if u and type(u) == "string" then
        t.userdata = helpers.touserdata(u) -- nicer at the tex end
    end
    local numberdata = t.numberdata
    local group = numberdata and numberdata.group
    local name = m.name
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
    local r = t.references
    local i = r and r.internal or 0 -- brrr
    local p = pushed[i]
    if not p then
        p = #cached + 1
        cached[p] = helpers.simplify(t)
        pushed[i] = p
        r.listindex = p
    end
    local setcomponent = references.setcomponent
    if setcomponent then
        setcomponent(t) -- might move to the tex end
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
        n = n -1
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

function lists.enhance(n)
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
        references.realpage = texgetcount("realpageno")
        -- tags
        local kind = metadata.kind
        local name = metadata.name
        if trace_lists then
            report_lists("enhancing %a, name %a",n,name)
        end
        if references then
            -- is this used ?
            local tag = tags.getid(kind,name)
            if tag and tag ~= "?" then
                references.tag = tag
            end
        end
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

-- we can use level instead but we can also decide to remove level from the metadata

local nesting = { }

function lists.pushnesting(i)
    local parent = lists.result[i]
    local name = parent.metadata.name
    local numberdata = parent and parent.numberdata
    local numbers = numberdata and numberdata.numbers
    local number = numbers and numbers[sections.getlevel(name)] or 0
    insert(nesting, { number = number, name = name, result = lists.result, parent = parent })
end

function lists.popnesting()
    local old = remove(nesting)
    lists.result = old.result
end

-- will be split

-- Historically we had blocks but in the mkiv approach that could as well be a level
-- which would simplify things a bit.

local splitter = lpeg.splitat(":")

-- this will become filtercollected(specification) and then we'll also have sectionblock as key

local sorters = {
    [variables.command] = function(a,b)
        if a.metadata.kind == "command" or b.metadata.kind == "command" then
            return a.references.internal < b.references.internal
        else
            return a.references.order < b.references.order
        end
    end,
    [variables.all] = function(a,b)
        return a.references.internal < b.references.internal
    end,
}

-- some day soon we will pass a table .. also split the function

local function filtercollected(names, criterium, number, collected, forced, nested, sortorder) -- names is hash or string
    local numbers, depth = documents.data.numbers, documents.data.depth
    local result, nofresult, detail = { }, 0, nil
    local block = false -- all
    criterium = gsub(criterium or ""," ","") -- not needed
    -- new, will be applied stepwise
    local wantedblock, wantedcriterium = lpegmatch(splitter,criterium) -- block:criterium
    if wantedblock == "" or wantedblock == variables.all or wantedblock == variables.text then
        criterium = wantedcriterium ~= "" and wantedcriterium or criterium
    elseif not wantedcriterium then
        block = documents.data.block
    else
        block, criterium = wantedblock, wantedcriterium
    end
    if block == "" then
        block = false
    end
-- print(">>",block,criterium)
    --
    forced = forced or { } -- todo: also on other branched, for the moment only needed for bookmarks
    if type(names) == "string" then
        names = settings_to_hash(names)
    end
    local all = not next(names) or names[variables.all] or false
    if trace_lists then
        report_lists("filtering names %a, criterium %a, block %a, number %a",names,criterium,block or "*",number)
    end
    if criterium == variables.intro then
        -- special case, no structure yet
        for i=1,#collected do
            local v = collected[i]
            local r = v.references
            if r and r.section == 0 then
                nofresult = nofresult + 1
                result[nofresult] = v
            end
        end
    elseif all or criterium == variables.all or criterium == variables.text then
        for i=1,#collected do
            local v = collected[i]
            local r = v.references
            if r and (not block or not r.block or block == r.block) then
                local metadata = v.metadata
                if metadata then
                    local name = metadata.name or false
                    local sectionnumber = (r.section == 0) or sections.collected[r.section]
                    if forced[name] or (sectionnumber and not metadata.nolist and (all or names[name])) then -- and not sectionnumber.hidenumber then
                        nofresult = nofresult + 1
                        result[nofresult] = v
                    end
                end
            end
        end
    elseif criterium == variables.current then
        if depth == 0 then
            return filtercollected(names,variables.intro,number,collected,forced,false,sortorder)
        else
            for i=1,#collected do
                local v = collected[i]
                local r = v.references
                if r and (not block or not r.block or block == r.block) then
                    local sectionnumber = sections.collected[r.section]
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
        end
    elseif criterium == variables.here then
        -- this is quite dirty ... as cnumbers is not sparse we can misuse #cnumbers
        if depth == 0 then
            return filtercollected(names,variables.intro,number,collected,forced,false,sortorder)
        else
            for i=1,#collected do
                local v = collected[i]
                local r = v.references
                if r then -- and (not block or not r.block or block == r.block) then
                    local sectionnumber = sections.collected[r.section]
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
        end
    elseif criterium == variables.previous then
        if depth == 0 then
            return filtercollected(names,variables.intro,number,collected,forced,false,sortorder)
        else
            for i=1,#collected do
                local v = collected[i]
                local r = v.references
                if r and (not block or not r.block or block == r.block) then
                    local sectionnumber = sections.collected[r.section]
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
        end
    elseif criterium == variables["local"] then -- not yet ok
        local nested = nesting[#nesting]
        if nested then
            return filtercollected(names,nested.name,nested.number,collected,forced,nested,sortorder)
        elseif sections.autodepth(documents.data.numbers) == 0 then
            return filtercollected(names,variables.all,number,collected,forced,false,sortorder)
        else
            return filtercollected(names,variables.current,number,collected,forced,false,sortorder)
        end
    elseif criterium == variables.component then
        -- special case, no structure yet
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
    else -- sectionname, number
        -- not the same as register
        local depth = sections.getlevel(criterium)
        local number = tonumber(number) or numberatdepth(depth) or 0
        if trace_lists then
            local t = sections.numbers()
            detail = format("depth %s, number %s, numbers %s, startset %s",depth,number,(#t>0 and concat(t,".",1,depth)) or "?",#collected)
        end
        if number > 0 then
            local pnumbers = nil
            local pblock = block
            local parent = nested and nested.parent
            if parent then
                pnumbers = parent.numberdata.numbers or pnumbers -- so local as well as nested
                pblock = parent.references.block or pblock
            end
            for i=1,#collected do
                local v = collected[i]
                local r = v.references
                if r and (not block or not r.block or pblock == r.block) then
                    local sectionnumber = sections.collected[r.section]
                    if sectionnumber then
                        local metadata = v.metadata
                        local cnumbers = sectionnumber.numbers
                        if cnumbers then
                            if (all or names[metadata.name or false]) and #cnumbers >= depth and matchingtilldepth(depth,cnumbers,pnumbers) then
                                nofresult = nofresult + 1
                                result[nofresult] = v
                            end
                        end
                    end
                end
            end
        end
    end
    if trace_lists then
        report_lists("criterium %a, block %a, found %a, detail %a",criterium,block or "*",#result,detail)
    end

    if sortorder then -- experiment
        local sorter = sorters[sortorder]
        if sorter then
            if trace_lists then
                report_lists("sorting list using method %a",sortorder)
            end
            for i=1,#result do
                result[i].references.order = i
            end
            table.sort(result,sorter)
        end
    end

    return result
end

lists.filtercollected = filtercollected

function lists.filter(specification)
    return filtercollected(
        specification.names,
        specification.criterium,
        specification.number,
        lists.collected,
        specification.forced,
        false,
        specification.order
    )
end

lists.result = { }

function lists.process(specification)
    lists.result = lists.filter(specification)
    local specials = utilities.parsers.settings_to_hash(specification.extras or "")
    specials = next(specials) and specials or nil
    for i=1,#lists.result do
        local r = lists.result[i]
        local m = r.metadata
        local s = specials and r.numberdata and specials[zerostrippedconcat(r.numberdata.numbers,".")] or ""
        context.strclistsentryprocess(m.name,m.kind,i,s)
    end
end

function lists.analyze(specification)
    lists.result = lists.filter(specification)
end

function lists.userdata(name,r,tag) -- to tex (todo: xml)
    local result = lists.result[r]
    if result then
        local userdata, metadata = result.userdata, result.metadata
        local str = userdata and userdata[tag]
        if str then
            return str, metadata
        end
    end
end

function lists.uservalue(name,r,tag,default) -- to lua
    local str = lists.result[r]
    str = str and str.userdata
    str = str and str[tag]
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
    sections.typesetnumber(sectiondata,"prefix",spec,sectiondata) -- data happens to contain the spec too
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
            return (titledata[tag] or titledata.title or "") == ""
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
        if numberdata and not numberdata.hidenumber then -- th ehide number is true
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
            sections.typesetnumber(numberdata,"number",spec or false,numberdata or false)
        end
    end
end

function lists.prefixednumber(name,n,prefixspec,numberspec)
    local data = lists.result[n]
    if data then
        helpers.prefix(data,prefixspec)
        local numberdata = data.numberdata
        if numberdata then
            sections.typesetnumber(numberdata,"number",numberspec or false,numberdata or false)
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

commands.pushlist           = lists.pushnesting
commands.poplist            = lists.popnesting
commands.enhancelist        = lists.enhance
commands.processlist        = lists.process
commands.analyzelist        = lists.analyze
commands.listtitle          = lists.title
commands.listprefixednumber = lists.prefixednumber
commands.listprefixedpage   = lists.prefixedpage


function commands.addtolist       (...) context(lists.addto     (...)) end
function commands.listsize        (...) context(lists.size      (...)) end
function commands.listlocation    (...) context(lists.location  (...)) end
function commands.listlabel       (...) context(lists.label     (...)) end
function commands.listrealpage    (...) context(lists.realpage  (...)) end
function commands.listgroupindex  (...) context(lists.groupindex(...)) end

function commands.currentsectiontolist()
    context(lists.addto(sections.current()))
end

function commands.listuserdata(...)
    local str, metadata = lists.userdata(...)
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

-- we could also set variables .. names will change (when this module is done)
-- maybe strc_lists_savedtitle etc

function commands.doiflisthastitleelse (...) commands.doifelse(lists.hastitledata (...)) end
function commands.doiflisthaspageelse  (...) commands.doifelse(lists.haspagedata  (...)) end
function commands.doiflisthasnumberelse(...) commands.doifelse(lists.hasnumberdata(...)) end
function commands.doiflisthasentry     (n)   commands.doifelse(lists.iscached     (n  )) end

function commands.savedlistnumber(name,n)
    local data = cached[tonumber(n)]
    if data then
        local numberdata = data.numberdata
        if numberdata then
            sections.typesetnumber(numberdata,"number",numberdata or false)
        end
    end
end

function commands.savedlisttitle(name,n,tag)
    local data = cached[tonumber(n)]
    if data then
        local titledata = data.titledata
        if titledata then
            helpers.title(titledata[tag] or titledata.title or "",data.metadata)
        end
    end
end

-- function commands.savedlistprefixednumber(name,n)
--     local data = cached[tonumber(n)]
--     if data then
--         local numberdata = data.numberdata
--         if numberdata then
--             helpers.prefix(data,data.prefixdata)
--             sections.typesetnumber(numberdata,"number",numberdata or false)
--         end
--     end
-- end

if not lists.reordered then
    function lists.reordered(data)
        return data.numberdata
    end
end

function commands.savedlistprefixednumber(name,n)
    local data = cached[tonumber(n)]
    if data then
        local numberdata = lists.reordered(data)
        if numberdata then
            helpers.prefix(data,data.prefixdata)
            sections.typesetnumber(numberdata,"number",numberdata or false)
        end
    end
end

commands.discardfromlist = lists.discard

-- new and experimental and therefore off by default

local sort, setmetatableindex = table.sort, table.setmetatableindex

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
