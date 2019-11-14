if not modules then modules = { } end modules ['strc-bkm'] = {
    version   = 0.200,
    comment   = "companion to strc-bkm.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Future version will support adding arbitrary bookmarks with
-- associated complex actions (rather trivial to implement).

-- this should become proper separated backend code

-- we should hook the placement into everystoptext ... needs checking

-- todo: make an lpeg for stripped

local next, type = next, type
local gsub, lower = string.gsub, string.lower
local concat = table.concat
local settings_to_hash = utilities.parsers.settings_to_hash

local trace_bookmarks  = false  trackers.register("references.bookmarks", function(v) trace_bookmarks = v end)
local report_bookmarks = logs.reporter("structure","bookmarks")

local structures     = structures

structures.bookmarks = structures.bookmarks or { }

local bookmarks      = structures.bookmarks
local sections       = structures.sections
local lists          = structures.lists
local levelmap       = sections.levelmap
local variables      = interfaces.variables
local implement      = interfaces.implement
local codeinjections = backends.codeinjections

bookmarks.method     = "internal" -- or "page"

local names          = { }
local opened         = { }
local forced         = { }
local numbered       = { }

function bookmarks.setopened(key,value)
    if value == nil then
        value = true
    end
    if type(key) == "table" then
        for i=1,#key do
            opened[key[i]] = value
        end
    else
        opened[key] = value
    end
end

function bookmarks.register(settings)
    local force = settings.force == variables.yes
    local number = settings.number == variables.yes
    local allopen = settings.opened == variables.all
    for k, v in next, settings_to_hash(settings.names or "") do
        names[k] = true
        if force then
            forced[k] = true
            if allopen then
                opened[k] = true
            end
        end
        if number then
            numbered[k] = true
        end
    end
    if not allopen then
        for k, v in next, settings_to_hash(settings.opened or "") do
            opened[k] = true
        end
    end
end

function bookmarks.overload(name,text)
    local l, ls = lists.tobesaved, nil
    if #l == 0 then
        -- no entries
    elseif name == "" then
        ls = l[#l]
    else
        for i=#l,0,-1 do
            local li = l[i]
            local metadata = li.metadata
            if metadata and not metadata.nolist and metadata.name == name then
                ls = li
                break
            end
        end
    end
    if ls then
        local titledata = ls.titledata
        if titledata then
            titledata.bookmark = text
        end
    end
    -- last resort
 -- context.writetolist({name},text,"")
end

local function stripped(str) -- kind of generic
    str = gsub(str,"\\([A-Z]+)","%1")            -- \LOGO
    str = gsub(str,"\\ "," ")                    -- \
    str = gsub(str,"\\([A-Za-z]+) *{(.-)}","%2") -- \bla{...}
    str = gsub(str," +"," ")                     -- spaces
    return str
end

-- todo: collect specs and collect later i.e. multiple places

local numberspec = { }

function bookmarks.setup(spec)
 -- table.merge(numberspec,spec)
    for k, v in next, spec do
        numberspec[k] = v
    end
end

function bookmarks.place()
    if next(names) then
        local levels         = { }
        local noflevels      = 0
        local lastlevel      = 1
        local nofblocks      = #lists.sectionblocks -- always >= 1
        local showblocktitle = toboolean(numberspec.showblocktitle,true)
--         local allsections    = sections.collected
        local allblocks      = sections.sectionblockdata
        for i=1,nofblocks do
            local block     = lists.sectionblocks[i]
            local blockdone = nofblocks == 1
            local list      = lists.filter {
                names     = names,
                criterium = block .. ":all",
                forced    = forced,
            }
            for i=1,#list do
                local li = list[i]
                local metadata = li.metadata
                local name = metadata.name
                if not metadata.nolist or forced[name] then -- and levelmap[name] then
                    local titledata = li.titledata
                    --
                    if not titledata then
                        local userdata = li.userdata
                        if userdata then
                            local first  = userdata.first
                            local second = userdata.second
                            if first then
                                if second then
                                    titledata = { title = first .. " " .. second }
                                else
                                    titledata = { title = first }
                                end
                            elseif second then
                                titledata = { title = second }
                            else
                                -- ignoring (command and so)
                            end
                        end
                    end
                    --
                    if titledata then
                        if not blockdone then
                            if showblocktitle then
                                -- add block entry
                                local blockdata  = allblocks[block]
                                local references = li.references
                                noflevels = noflevels + 1
                                levels[noflevels] = {
                                    level     = 1, -- toplevel
                                    title     = stripped(blockdata.bookmark ~= "" and blockdata.bookmark or block),
                                    reference = references,
                                    opened    = allopen or opened[name], -- same as first entry
                                    realpage  = references and references.realpage or 0, -- handy for later
                                    usedpage  = true,
                                }
                            end
                            blockdone = true
                        end
                        local structural = levelmap[name]
                        lastlevel = structural or lastlevel
                        if nofblocks > 1 then
                            -- we have a block so increase the level
                            lastlevel = lastlevel + 1
                        end
                        local title = titledata.bookmark
                        if not title or title == "" then
                            -- We could typeset the title and then convert it.
                         -- if not structural then
                         --     title = titledata.title or "?")
                         -- else
                                title = titledata.title or "?"
                         -- end
                        end
--                         if numbered[name] then
--                             local sectiondata = allsections[li.references.section]
--                             if sectiondata then
--                                 local numberdata = li.numberdata
--                                 if numberdata and not numberdata.hidenumber then
--                                  -- we could typeset the number and convert it
--                                     local number = sections.typesetnumber(sectiondata,"direct",numberspec,sectiondata)
--                                     if number and #number > 0 then
--                                         title = concat(number) .. " " .. title
--                                     end
--                                 end
--                             end
--                         end
if numbered[name] then
    local numberdata = li.numberdata
    if numberdata and not numberdata.hidenumber then
     -- we could typeset the number and convert it
        local number = sections.typesetnumber(numberdata,"direct",numberspec,numberdata)
        if number and #number > 0 then
            title = concat(number) .. " " .. title
        end
    end
end
                        noflevels = noflevels + 1
                        local references = li.references
                        levels[noflevels] = {
                            level      = lastlevel,
                            title      = stripped(title), -- can be replaced by converter
                            reference  = references,   -- has internal and realpage
                            opened     = allopen or opened[name],
                            realpage   = references and references.realpage or 0, -- handy for later
                            usedpage   = true,
                            structural = structural,
                            name       = name,
                        }
                    end
                end
            end
        end
-- inspect(levels)
        bookmarks.finalize(levels)
        function bookmarks.place() end -- prevent second run
    end
end

function bookmarks.flatten(levels)
    if not levels then
        -- a plugin messed up
        return { }
    end
    -- This function promotes leading structurelements with a higher level
    -- to the next lower level. Such situations are the result of lack of
    -- structure: a subject preceding a chapter in a sectionblock. So, the
    -- following code runs over section blocks as well. (bookmarks-007.tex)
    local noflevels = #levels
    if noflevels > 1 then
        local function showthem()
            for i=1,noflevels do
                local level = levels[i]
             -- if level.structural then
             --     report_bookmarks("%i > %s > %s",level.level,level.reference.block,level.title)
             -- else
                    report_bookmarks("%i > %s > %s > %s",level.level,level.reference.block,level.name,level.title)
             -- end
            end
        end
        if trace_bookmarks then
            report_bookmarks("checking structure")
            showthem()
        end
        local skip  = false
        local done  = 0
        local start = 1
        local one   = levels[1]
        local first = one.level
        local block = one.reference.block
        for i=2,noflevels do
            local current   = levels[i]
            local new       = current.level
            local reference = current.reference
            local newblock  = type(reference) == "table" and current.reference.block or block
            if newblock ~= block then
                first = new
                block = newblock
                start = i
                skip  = false
            elseif skip then
                -- go on
            elseif new > first then
                skip = true
            elseif new < first then
                for j=start,i-1 do
                    local previous = levels[j]
                    local old      = previous.level
                    previous.level = new
                    if trace_bookmarks then
                        report_bookmarks("promoting entry %a from level %a to %a: %s",j,old,new,previous.title)
                    end
                    done = done + 1
                end
                skip = true
            end
        end
        if trace_bookmarks then
            if done > 0 then
                report_bookmarks("%a entries promoted")
                showthem()
            else
                report_bookmarks("nothing promoted")
            end
        end
    end
    return levels
end

local extras = { }
local lists  = { }
local names  = { }

bookmarks.extras = extras

local function cleanname(name)
    return lower(file.basename(name))
end

function extras.register(name,levels)
    if name and levels then
        name = cleanname(name)
        local found = names[name]
        if found then
            lists[found].levels = levels
        else
            lists[#lists+1] = {
                name   = name,
                levels = levels,
            }
            names[name] = #lists
        end
    end
end

function extras.get(name)
    if name then
        local found = names[cleanname(name)]
        if found then
            return lists[found].levels
        end
    else
        return lists
    end
end

function extras.reset(name)
    local l, n = { }, { }
    if name then
        name = cleanname(name)
        for i=1,#lists do
            local li = lists[i]
            local ln = li.name
            if name == ln then
                -- skip
            else
                local m = #l + 1
                l[m]  = li
                n[ln] = m
            end
        end
    end
    lists, names = l, n
end

local function checklists()
    for i=1,#lists do
        local levels = lists[i].levels
        for j=1,#levels do
            local entry     = levels[j]
            local pageindex = entry.pageindex
            if pageindex then
                entry.reference = figures.getrealpage(pageindex)
                entry.pageindex = nil
            end
        end
    end
end

function extras.tosections(levels)
    local sections = { }
    local noflists = #lists
    for i=1,noflists do
        local levels = lists[i].levels
        local data   = { }
        sections[i]  = data
        for j=1,#levels do
            local entry = levels[j]
            if entry.usedpage then
                local section = entry.section
                local d = data[section]
                if d then
                    d[#d+1] = entry
                else
                    data[section] = { entry }
                end
            end
        end
    end
    return sections
end

function extras.mergesections(levels,sections)
    if not sections or #sections == 0 then
        return levels
    elseif not levels then
        return { }
    else
        local merge    = { }
        local noflists = #lists
        if #levels == 0 then
            local level   = 0
            local section = 0
            for i=1,noflists do
                local entries = sections[i][0]
                if entries then
                    for i=1,#entries do
                        local entry = entries[i]
                        merge[#merge+1] = entry
                        entry.level = entry.level + level
                    end
                end
            end
        else
            for j=1,#levels do
                local entry     = levels[j]
                merge[#merge+1] = entry
                local section   = entry.reference.section
                local level     = entry.level
                entry.section   = section -- for tracing
                for i=1,noflists do
                    local entries = sections[i][section]
                    if entries then
                        for i=1,#entries do
                            local entry = entries[i]
                            merge[#merge+1] = entry
                            entry.level = entry.level + level
                        end
                    end
                end
            end
        end
        return merge
    end
end

function bookmarks.merge(levels,mode)
    return extras.mergesections(levels,extras.tosections())
end

local sequencers   = utilities.sequencers
local appendgroup  = sequencers.appendgroup
local appendaction = sequencers.appendaction

local bookmarkactions = sequencers.new {
    arguments    = "levels,method",
    returnvalues = "levels",
    results      = "levels",
}

appendgroup(bookmarkactions,"before") -- user
appendgroup(bookmarkactions,"system") -- private
appendgroup(bookmarkactions,"after" ) -- user

appendaction(bookmarkactions,"system",bookmarks.flatten)
appendaction(bookmarkactions,"system",bookmarks.merge)

function bookmarks.finalize(levels)
    local method = bookmarks.method or "internal"
    checklists() -- so that plugins have the adapted page number
    levels = bookmarkactions.runner(levels,method)
    if levels and #levels > 0 then
        -- normally this is not needed
        local purged = { }
        for i=1,#levels do
            local l = levels[i]
            if l.usedpage ~= false then
                purged[#purged+1] = l
            end
        end
        --
        codeinjections.addbookmarks(purged,method)
    else
        -- maybe a plugin messed up
    end
end

function bookmarks.installhandler(what,where,func)
    if not func then
        where, func = "after", where
    end
    if where == "before" or where == "after" then
        sequencers.appendaction(bookmarkactions,where,func)
    else
        report_tex("installing bookmark %a handlers in %a is not possible",what,tostring(where))
    end
end

-- interface

implement {
    name      = "setupbookmarks",
    actions   = bookmarks.setup,
    arguments = {
        {
            { "separatorset" },
            { "conversionset" },
            { "starter" },
            { "stopper" },
            { "segments" },
            { "showblocktitle" },
        }
    }
}

implement {
    name      = "registerbookmark",
    actions   = bookmarks.register,
    arguments = {
        {
            { "names" },
            { "opened" },
            { "force" },
            { "number" },
        }
    }
}

implement {
    name      = "overloadbookmark",
    actions   = bookmarks.overload,
    arguments = "2 strings",
}
