if not modules then modules = { } end modules ['strc-doc'] = {
    version   = 1.001,
    comment   = "companion to strc-doc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: associate counter with head
-- we need to better split the lua/tex end
-- we need to freeze and document this module

-- keep this as is:
--
-- in section titles by default a zero aborts, so there we need: sectionset=bagger with \definestructureprefixset [bagger] [section-2,section-4] []
-- in lists however zero's are ignored, so there numbersegments=2:4 gives result

local next, type, tonumber, select = next, type, tonumber, select
local format, gsub, find, gmatch, match = string.format, string.gsub, string.find, string.gmatch, string.match
local concat, fastcopy = table.concat, table.fastcopy
local max, min = math.max, math.min
local allocate, mark, accesstable = utilities.storage.allocate, utilities.storage.mark, utilities.tables.accesstable
local setmetatableindex = table.setmetatableindex

local catcodenumbers      = catcodes.numbers
local ctxcatcodes         = catcodenumbers.ctxcatcodes
local variables           = interfaces.variables

local v_last              = variables.last
local v_first             = variables.first
local v_previous          = variables.previous
local v_next              = variables.next
local v_auto              = variables.auto
local v_strict            = variables.strict
local v_all               = variables.all
local v_positive          = variables.positive
local v_by                = variables.by

local trace_sectioning    = false  trackers.register("structures.sectioning", function(v) trace_sectioning = v end)
local trace_detail        = false  trackers.register("structures.detail",     function(v) trace_detail     = v end)

local report_structure    = logs.reporter("structure","sectioning")

local context             = context
local commands            = commands

local structures          = structures
local helpers             = structures.helpers
local documents           = structures.documents
local sections            = structures.sections
local lists               = structures.lists
local counters            = structures.counters
local sets                = structures.sets
local tags                = structures.tags

local processors          = typesetters.processors
local applyprocessor      = processors.apply
local startapplyprocessor = processors.startapply
local stopapplyprocessor  = processors.stopapply
local strippedprocessor   = processors.stripped

local a_internal          = attributes.private('internal')

local ctx_convertnumber   = context.convertnumber
local ctx_sprint          = context.sprint
local ctx_finalizeauto    = context.finalizeautostructurelevel

-- -- -- document -- -- --

local data -- the current state

function documents.initialize()
    data = allocate { -- whole data is marked
        numbers    = { },
        forced     = { },
        ownnumbers = { },
        status     = { },
        checkers   = { },
        depth      = 0,
        blocks     = { },
        block      = "",
    }
    documents.data = data
end

function documents.reset()
    data.numbers    = { }
    data.forced     = { }
    data.ownnumbers = { }
    data.status     = { }
 -- data.checkers   = { }
    data.depth      = 0
end

documents.initialize()

-- -- -- components -- -- --

function documents.preset(numbers)
    local nofnumbers = #numbers
    local ownnumbers = { }
    data.numbers     = numbers
    data.ownnumbers  = ownnumbers
    data.depth       = nofnumbers
    for i=1,nofnumbers do
        ownnumbers[i] = ""
    end
    sections.setnumber(nofnumbers,"-1")
end

-- -- -- sections -- -- --

local collected  = allocate()
local tobesaved  = allocate()

sections.collected  = collected
sections.tobesaved  = tobesaved

-- local function initializer()
--     collected = sections.collected
--     tobesaved = sections.tobesaved
-- end
--
-- job.register('structures.sections.collected', tobesaved, initializer)

sections.registered = sections.registered or allocate()
local registered    = sections.registered

storage.register("structures/sections/registered", registered, "structures.sections.registered")

local function update(name,level,section)
    for k, v in next, registered do
        if k ~= name and v.coupling == name then
            report_structure("updating section level %a to level of %a",k,name)
            context.doredefinehead(k,name)
            update(k,level,section)
        end
    end
end

function sections.register(name,specification)
    registered[name] = specification
    local level   = specification.level
    local section = specification.section
    update(name,level,section)
end

function sections.currentid()
    return #tobesaved
end

local lastsaved = 0

function sections.save(sectiondata)
--  local sectionnumber = helpers.simplify(section.sectiondata) -- maybe done earlier
    local numberdata = sectiondata.numberdata
    local ntobesaved = #tobesaved
    if not numberdata or sectiondata.metadata.nolist then
        -- stay
    else
        ntobesaved = ntobesaved + 1
        tobesaved[ntobesaved] = numberdata
        if not collected[ntobesaved] then
            collected[ntobesaved] = numberdata
        end
    end
    lastsaved = ntobesaved
    return ntobesaved
end

function sections.currentsectionindex()
    return lastsaved -- only for special controlled situations
end

function sections.load()
    setmetatableindex(collected,nil)
    local lists = lists.collected
    for i=1,#lists do
        local list = lists[i]
        local metadata = list.metadata
        if metadata and metadata.kind == "section" and not metadata.nolist then
            local numberdata = list.numberdata
            if numberdata then
                collected[#collected+1] = numberdata
            end
        end
    end
    sections.load = functions.dummy
end

table.setmetatableindex(collected, function(t,i)
    sections.load()
    return collected[i] or { }
end)

--

sections.verbose          = true

local sectionblockdata    = sections.sectionblockdata or { }
sections.sectionblockdata = sectionblockdata

local levelmap            = sections.levelmap or { }
sections.levelmap         = levelmap
levelmap.block            = -1

storage.register("structures/sections/levelmap", sections.levelmap, "structures.sections.levelmap")

function sections.setlevel(name,level) -- level can be number or parent (=string)
    local l = tonumber(level)
    if not l then
        l = levelmap[level]
    end
    if l and l > 0 then
        levelmap[name] = l
    else
        -- error
    end
end

function sections.getlevel(name)
    return levelmap[name] or 0
end

table.setmetatableindex(sectionblockdata,"table")

function sections.setblock(name,settings)
    local block = name or data.block or "unknown" -- can be used to set the default
    data.block = block
    sectionblockdata[block] = settings
    return block
end

function sections.pushblock(name,settings)
    counters.check(0) -- we assume sane usage of \page between blocks
    local block = name or data.block
    data.blocks[#data.blocks+1] = block
    data.block = block
    sectionblockdata[block] = settings
    documents.reset()
    return block
end

function sections.popblock()
    data.blocks[#data.blocks] = nil
    local block = data.blocks[#data.blocks] or data.block
    data.block = block
    documents.reset()
    return block
end

function sections.currentblock()
    return data.block or data.blocks[#data.blocks] or "unknown"
end

function sections.currentlevel()
    return data.depth
end

function sections.getcurrentlevel()
    context(data.depth)
end

local saveset = { } -- experiment, see sections/tricky-001.tex

function sections.setentry(given)
    -- old number
    local numbers     = data.numbers

    local ownnumbers  = data.ownnumbers
    local forced      = data.forced
    local status      = data.status
    local olddepth    = data.depth
    local givenname   = given.metadata.name
    local mappedlevel = levelmap[givenname]
    local newdepth    = tonumber(mappedlevel or (olddepth > 0 and olddepth) or 1) -- hm, levelmap only works for section-*
    local directives  = given.directives
    local resetset    = directives and directives.resetset or ""
 -- local resetter = sets.getall("structure:resets",data.block,resetset)
    -- a trick to permit userdata to overload title, ownnumber and reference
    -- normally these are passed as argument but nowadays we provide several
    -- interfaces (we need this because we want to be compatible)
    if trace_detail then
        report_structure("name %a, mapped level %a, old depth %a, new depth %a, reset set %a",
            givenname,mappedlevel,olddepth,newdepth,resetset)
    end
    local u = given.userdata
    if u then
        -- kind of obsolete as we can pass them directly anyway
        if u.reference and u.reference ~= "" then given.metadata.reference   = u.reference ; u.reference = nil end
        if u.ownnumber and u.ownnumber ~= "" then given.numberdata.ownnumber = u.ownnumber ; u.ownnumber = nil end
        if u.title     and u.title     ~= "" then given.titledata.title      = u.title     ; u.title     = nil end
        if u.bookmark  and u.bookmark  ~= "" then given.titledata.bookmark   = u.bookmark  ; u.bookmark  = nil end
        if u.label     and u.label     ~= "" then given.titledata.label      = u.label     ; u.label     = nil end
    end
    -- so far for the trick
    if saveset then
        saveset[newdepth] = (resetset ~= "" and resetset) or saveset[newdepth] or ""
    end
    if newdepth > olddepth then
        for i=olddepth+1,newdepth do
            local s = tonumber(sets.get("structure:resets",data.block,saveset and saveset[i] or resetset,i))
            if trace_detail then
                report_structure("new depth %s, old depth %s, reset set %a, reset value %a, current %a",olddepth,newdepth,resetset,s,numbers[i])
            end
            if not s or s == 0 then
                numbers[i] = numbers[i] or 0
                ownnumbers[i] = ownnumbers[i] or ""
            else
                numbers[i] = s - 1
                ownnumbers[i] = ""
            end
            status[i] = { }
        end
    elseif newdepth < olddepth then
        for i=olddepth,newdepth+1,-1 do
            local s = tonumber(sets.get("structure:resets",data.block,saveset and saveset[i] or resetset,i))
            if trace_detail then
                report_structure("new depth %s, old depth %s, reset set %a, reset value %a, current %a",olddepth,newdepth,resetset,s,numbers[i])
            end
            if not s or s == 0 then
                numbers[i] = numbers[i] or 0
                ownnumbers[i] = ownnumbers[i] or ""
            else
                numbers[i] = s - 1
                ownnumbers[i] = ""
            end
            status[i] = nil
        end
    end
    counters.check(newdepth)
    ownnumbers[newdepth] = given.numberdata.ownnumber or ""
    given.numberdata.ownnumber = nil
    data.depth = newdepth
    -- new number
    olddepth = newdepth
    if given.metadata.increment then
        local oldn, newn = numbers[newdepth] or 0, 0
        local fd = forced[newdepth]
        if fd then
            if fd[1] == "add" then
                newn = oldn + fd[2] + 1
            else
                newn = fd[2] + 1
            end
            if newn < 0 then
                newn = 1 -- maybe zero is nicer
            end
            forced[newdepth] = nil
            if trace_detail then
                report_structure("old depth %a, new depth %a, old n %a, new n %a, forced %t",olddepth,newdepth,oldn,newn,fd)
            end
        else
            newn = oldn + 1
            if trace_detail then
                report_structure("old depth %a, new depth %a, old n %a, new n %a, increment",olddepth,newdepth,oldn,newn)
            end
        end
        numbers[newdepth] = newn
    end
    status[newdepth] = given or { }
    for k, v in next, data.checkers do
        if v[1] == newdepth and v[2] then
            v[2](k)
        end
    end
    local numberdata= given.numberdata
    if not numberdata then
        -- probably simplified to nothing
        numberdata = { }
        given.numberdata = numberdata
    end

    local n = { }
    for i=1,newdepth do
        n[i] = numbers[i]
    end
    numberdata.numbers = n
--     numberdata.numbers = fastcopy(numbers)

    if #ownnumbers > 0 then
        numberdata.ownnumbers = fastcopy(ownnumbers)
    end
    if trace_detail then
        report_structure("name %a, numbers % a, own numbers % a",givenname,numberdata.numbers,numberdata.ownnumbers)
    end

    local metadata   = given.metadata
    local references = given.references

    local tag = references.tag or tags.getid(metadata.kind,metadata.name)
    if tag and tag ~= "" and tag ~= "?" then
        references.tag = tag
    end

    local setcomponent = structures.references.setcomponent
    if setcomponent then
        setcomponent(given) -- might move to the tex end
    end

    references.section = sections.save(given)
 -- given.numberdata = nil
end

function sections.reportstructure()
    if sections.verbose then
        local numbers, ownnumbers, status, depth = data.numbers, data.ownnumbers, data.status, data.depth
        local d = status[depth]
        local o = concat(ownnumbers,".",1,depth)
        local n = (numbers and concat(numbers,".",1,min(depth,#numbers))) or 0
        local l = d.titledata.title or ""
        local t = (l ~= "" and l) or d.titledata.title or "[no title]"
        local m = d.metadata.name
        if o and not find(o,"^%.*$") then
            report_structure("%s @ level %i : (%s) %s -> %s",m,depth,n,o,t)
        elseif d.directives and d.directives.hidenumber then
            report_structure("%s @ level %i : (%s) -> %s",m,depth,n,t)
        else
            report_structure("%s @ level %i : %s -> %s",m,depth,n,t)
        end
    end
end

function sections.setnumber(depth,n)
    local forced, depth, new = data.forced, depth or data.depth, tonumber(n)
    if type(n) == "string" then
        if find(n,"^[%+%-]") then
            forced[depth] = { "add", new }
        else
            forced[depth] = { "set", new }
        end
    else
        forced[depth] = { "set", new }
    end
end

function sections.numberatdepth(depth)
    return data.numbers[tonumber(depth) or sections.getlevel(depth) or 0] or 0
end

function sections.numbers()
    return data.numbers
end

function sections.matchingtilldepth(depth,numbers,parentnumbers)
    local dn = parentnumbers or data.numbers
    local ok = false
    for i=1,depth do
        if dn[i] == numbers[i] then
            ok = true
        else
            return false
        end
    end
    return ok
end

function sections.getnumber(depth) -- redefined later ...
    context(data.numbers[depth] or 0)
end

function sections.set(key,value)
    data.status[data.depth][key] = value -- may be nil for a reset
end

function sections.cct()
    local metadata = data.status[data.depth].metadata
    context(metadata and metadata.catcodes or ctxcatcodes)
end

-- this one will become: return catcode, d (etc)

function sections.structuredata(depth,key,default,honorcatcodetable) -- todo: spec table and then also depth
    if depth then
        depth = levelmap[depth] or tonumber(depth)
    end
    if not depth or depth == 0 then
        depth = data.depth
    end
    local data = data.status[depth]
    local d
    if data then
        if find(key,".",1,true) then
            d = accesstable(key,data)
        else
            d = data.titledata
            d = d and d[key]
        end
    end
    if d and type(d) ~= "table" then
        if honorcatcodetable == true or honorcatcodetable == v_auto then
            local metadata = data.metadata
            local catcodes = metadata and metadata.catcodes
            if catcodes then
                ctx_sprint(catcodes,d)
            else
                context(d)
            end
        elseif not honorcatcodetable or honorcatcodetable == "" then
            context(d)
        else
            local catcodes = catcodenumbers[honorcatcodetable]
            if catcodes then
                ctx_sprint(catcodes,d)
            else
                context(d)
            end
        end
    elseif default then
        context(default)
    end
end

function sections.userdata(depth,key,default)
    if depth then
        depth = levelmap[depth] or tonumber(depth)
    end
    if not depth or depth == 0 then
        depth = data.depth
    end
    if depth > 0 then
        local userdata = data.status[depth]
        userdata = userdata and userdata.userdata
        userdata = (userdata and userdata[key]) or default
        if userdata then
            context(userdata)
        end
    end
end

function sections.setchecker(name,level,command) -- hm, checkers are not saved
    data.checkers[name] = (name and command and level >= 0 and { level, command }) or nil
end

function sections.current()
    return data.status[data.depth]
end

local function depthnumber(n)
    local depth = data.depth
    if not n or n == 0 then
        n = depth
    elseif n < 0 then
        n = depth + n
    end
    return data.numbers[n] or 0
end

sections.depthnumber = depthnumber

function commands.depthnumber(n)
    return context(depthnumber(n))
end

function sections.autodepth(numbers)
    for i=#numbers,1,-1 do
        if numbers[i] ~= 0 then
            return i
        end
    end
    return 0
end

--

function structures.currentsectionnumber() -- brr, namespace wrong
    local sc = sections.current()
    return sc and sc.numberdata
end

-- \dorecurse{3} {
--     \chapter{Blabla}                 \subsection{bla 1 1} \subsection{bla 1 2}
--                      \section{bla 2} \subsection{bla 2 1} \subsection{bla 2 2}
-- }

-- sign=all      => also zero and negative
-- sign=positive => also zero
-- sign=hang     => llap sign

-- this can be a local function

local function process(index,numbers,ownnumbers,criterium,separatorset,conversion,conversionset,entry,result,preceding,done,language)
    -- todo: too much (100 steps)
    local number = numbers and (numbers[index] or 0)
    local ownnumber = ownnumbers and ownnumbers[index] or ""
    if number > criterium or (ownnumber ~= "") then
        local block = (entry.block ~= "" and entry.block) or sections.currentblock() -- added
        if preceding then
            local separator = sets.get("structure:separators",block,separatorset,preceding,".")
            if separator then
                if result then
                    result[#result+1] = strippedprocessor(separator)
                else
                    applyprocessor(separator)
                end
            end
            preceding = false
        end
        if result then
            if ownnumber ~= "" then
                result[#result+1] = ownnumber
            elseif conversion and conversion ~= "" then -- traditional (e.g. used in itemgroups) .. inherited!
                result[#result+1] = converters.convert(conversion,number,language)
            else
                local theconversion = sets.get("structure:conversions",block,conversionset,index,"numbers")
                result[#result+1] = converters.convert(theconversion,number,language)
            end
        else
            if ownnumber ~= "" then
                applyprocessor(ownnumber)
            elseif conversion and conversion ~= "" then -- traditional (e.g. used in itemgroups)
                ctx_convertnumber(conversion,number)
            else
                local theconversion = sets.get("structure:conversions",block,conversionset,index,"numbers")
                local data = startapplyprocessor(theconversion)
                ctx_convertnumber(data or "numbers",number)
                stopapplyprocessor()
            end
        end
        return index, true
    else
        return preceding or false, done
    end
end

function sections.typesetnumber(entry,kind,...) -- kind='section','number','prefix'
    if entry and entry.hidenumber ~= true then -- can be nil
        local separatorset  = ""
        local conversionset = ""
        local conversion    = ""
        local groupsuffix   = ""
        local stopper       = ""
        local starter       = ""
        local connector     = ""
        local set           = ""
        local segments      = ""
        local criterium     = ""
        local language      = ""
        for d=1,select("#",...) do
            local data = select(d,...) -- can be multiple parametersets
            if data then
                if separatorset  == "" then separatorset  = data.separatorset  or "" end
                if conversionset == "" then conversionset = data.conversionset or "" end
                if conversion    == "" then conversion    = data.conversion    or "" end
                if groupsuffix   == "" then groupsuffix   = data.groupsuffix   or "" end
                if stopper       == "" then stopper       = data.stopper       or "" end
                if starter       == "" then starter       = data.starter       or "" end
                if connector     == "" then connector     = data.connector     or "" end
                if set           == "" then set           = data.set           or "" end
                if segments      == "" then segments      = data.segments      or "" end
                if criterium     == "" then criterium     = data.criterium     or "" end
                if language      == "" then language      = data.language      or "" end
            end
        end
        if separatorset  == "" then separatorset  = "default"  end
        if conversionset == "" then conversionset = "default"  end -- not used
        if conversion    == "" then conversion    = nil        end
        if groupsuffix   == "" then groupsuffix   = nil        end
        if stopper       == "" then stopper       = nil        end
        if starter       == "" then starter       = nil        end
        if connector     == "" then connector     = nil        end
        if set           == "" then set           = "default"  end
        if segments      == "" then segments      = nil        end
        if language      == "" then language      = nil        end
        --
        if criterium == v_strict then
            criterium = 0
        elseif criterium == v_positive then
            criterium = -1
        elseif criterium == v_all then
            criterium = -1000000
        else
            criterium = 0
        end
        --
        local firstprefix, lastprefix = 0, 16 -- too much, could max found level
        if segments then
            local f, l = match(tostring(segments),"^(.-):(.+)$")
            if l == "*" or l == v_all then
                l = 100 -- new
            end
            if f and l then
                -- 0:100, chapter:subsubsection
                firstprefix = tonumber(f) or sections.getlevel(f) or 0
                lastprefix  = tonumber(l) or sections.getlevel(l) or 100
            else
                -- 3, section
                local fl = tonumber(segments) or sections.getlevel(segments) -- generalize
                if fl then
                    firstprefix = fl
                    lastprefix  = fl
                end
            end
        end
        --
        local numbers, ownnumbers = entry.numbers, entry.ownnumbers
        if numbers then
            local done, preceding = false, false
            --
            local result = kind == "direct" and { }
            if result then
                connector = false
            end
            --
            local prefixlist = set and sets.getall("structure:prefixes","",set) -- "" == block
            if starter then
                if result then
                    result[#result+1] = strippedprocessor(starter)
                else
                    applyprocessor(starter)
                end
            end
            if prefixlist and (kind == "section" or kind == "prefix" or kind == "direct") then
                -- find valid set (problem: for sectionnumber we should pass the level)
                -- no holes
                local b, e, bb, ee = 1, #prefixlist, 0, 0
                -- find last valid number
                for k=e,b,-1 do
                    local prefix = prefixlist[k]
                    local index = sections.getlevel(prefix) or k
                    if index >= firstprefix and index <= lastprefix then
                        local number = numbers and numbers[index]
                        if number then
                            local ownnumber = ownnumbers and ownnumbers[index] or ""
                            if number > 0 or (ownnumber ~= "") then
                                break
                            else
                                e = k -1
                            end
                        end
                    end
                end
                -- find valid range
                for k=b,e do
                    local prefix = prefixlist[k]
                    local index = sections.getlevel(prefix) or k
                    if index >= firstprefix and index <= lastprefix then
                        local number = numbers and numbers[index]
                        if number then
                            local ownnumber = ownnumbers and ownnumbers[index] or ""
                            if number > 0 or (ownnumber ~= "") then
                                if bb == 0 then bb = k end
                                ee = k
                            else
                                bb, ee = 0, 0
                            end
                        else
                            break
                        end
                    end
                end
                -- print valid range
                for k=bb,ee do
                    local prefix = prefixlist[k]
                    local index = sections.getlevel(prefix) or k
                    if index >= firstprefix and index <= lastprefix then
                        preceding, done = process(index,numbers,ownnumbers,criterium,separatorset,conversion,conversionset,entry,result,preceding,done,language)
                    end
                end
            else
                -- also holes check
                for index=firstprefix,lastprefix do
                    preceding, done = process(index,numbers,ownnumbers,criterium,separatorset,conversion,conversionset,entry,result,preceding,done,language)
                end
            end
            --
            if done then
                if connector and kind == 'prefix' then
                    if result then
                        -- can't happen as we're in 'direct'
                    else
                        applyprocessor(connector)
                    end
                else
                    if groupsuffix and kind ~= "prefix" then
                        if result then
                            result[#result+1] = strippedprocessor(groupsuffix)
                        else
                           applyprocessor(groupsuffix)
                        end
                    end
                    if stopper then
                        if result then
                            result[#result+1] = strippedprocessor(stopper)
                        else
                            applyprocessor(stopper)
                        end
                    end
                end
            end
            return result -- a table !
        else
        --  report_structure("error: no numbers")
        end
    end
end

function sections.title()
    local sc = sections.current()
    if sc then
        helpers.title(sc.titledata.title,sc.metadata)
    end
end

function sections.findnumber(depth,what) -- needs checking (looks wrong and slow too)
    local data = data.status[depth or data.depth]
    if not data then
        return
    end
    local references = data.references
    if not references then
        return
    end
    local index       = references.section
    local collected   = sections.collected
    local sectiondata = collected[index]
    if sectiondata and sectiondata.hidenumber ~= true then -- can be nil
        local quit = what == v_previous or what == v_next
        if what == v_first or what == v_previous then
            for i=index,1,-1 do
                local s = collected[i]
                if s then
                    local n = s.numbers
                    if #n == depth and n[depth] and n[depth] ~= 0 then
                        sectiondata = s
                        if quit then
                            break
                        end
                    elseif #n < depth then
                        break
                    end
                end
            end
        elseif what == v_last or what == v_next then
            for i=index,#collected do
                local s = collected[i]
                if s then
                    local n = s.numbers
                    if #n == depth and n[depth] and n[depth] ~= 0 then
                        sectiondata = s
                        if quit then
                            break
                        end
                    elseif #n < depth then
                        break
                    end
                end
            end
        end
        return sectiondata
    end
end

function sections.finddata(depth,what)
    local data = data.status[depth or data.depth]
    if not data then
        return
    end
    local references = data.references
    if not references then
        return
    end
    local index = references.listindex
    if not index then
        return
    end
    local collected = structures.lists.collected
    local quit      = what == v_previous or what == v_next
    if what == v_first or what == v_previous then
        for i=index-1,1,-1 do
            local s = collected[i]
            if not s then
                break
            elseif s.metadata.kind == "section" then -- maybe check on name
                local n = s.numberdata.numbers
                if #n == depth and n[depth] and n[depth] ~= 0 then
                    data = s
                    if quit then
                        break
                    end
                elseif #n < depth then
                    break
                end
            end
        end
    elseif what == v_last or what == v_next then
        for i=index+1,#collected do
            local s = collected[i]
            if not s then
                break
            elseif s.metadata.kind == "section" then -- maybe check on name
                local n = s.numberdata.numbers
                if #n == depth and n[depth] and n[depth] ~= 0 then
                    data = s
                    if quit then
                        break
                    end
                elseif #n < depth then
                    break
                end
            end
        end
    end
    return data
end

function sections.internalreference(sectionname,what) -- to be used in pagebuilder (no marks used)
    local r = type(sectionname) == "number" and sectionname or registered[sectionname]
    if r then
        local data = sections.finddata(r.level,what)
        return data and data.references and data.references.internal
    end
end

function sections.fullnumber(depth,what)
    local sectiondata = sections.findnumber(depth,what)
    if sectiondata then
        sections.typesetnumber(sectiondata,'section',sectiondata)
    end
end

function sections.getnumber(depth,what) -- redefined here
    local sectiondata = sections.findnumber(depth,what)
    context((sectiondata and sectiondata.numbers[depth]) or 0)
end

-- experimental

local levels = { }

--~ function commands.autonextstructurelevel(level)
--~     if level > #levels then
--~         for i=#levels+1,level do
--~             levels[i] = ""
--~         end
--~     end
--~     local finish = concat(levels,"\n",level) or ""
--~     for i=level+1,#levels do
--~         levels[i] = ""
--~     end
--~     levels[level] = [[\finalizeautostructurelevel]]
--~     context(finish)
--~ end

--~ function commands.autofinishstructurelevels()
--~     local finish = concat(levels,"\n") or ""
--~     levels = { }
--~     context(finish)
--~ end

function commands.autonextstructurelevel(level)
    if level > #levels then
        for i=#levels+1,level do
            levels[i] = false
        end
    else
        for i=level,#levels do
            if levels[i] then
                ctx_finalizeauto()
                levels[i] = false
            end
        end
    end
    levels[level] = true
end

function commands.autofinishstructurelevels()
    for i=1,#levels do
        if levels[i] then
            ctx_finalizeauto()
        end
    end
    levels = { }
end

-- interface (some are actually already commands, like sections.fullnumber)

commands.structurenumber            = sections.fullnumber
commands.structuretitle             = sections.title

commands.structurevariable          = function(name)         sections.structuredata(nil,name)             end
commands.structureuservariable      = function(name)         sections.userdata     (nil,name)             end
commands.structurecatcodedget       = function(name)         sections.structuredata(nil,name,nil,true)    end
commands.structuregivencatcodedget  = function(name,catcode) sections.structuredata(nil,name,nil,catcode) end
commands.structureautocatcodedget   = function(name,catcode) sections.structuredata(nil,name,nil,catcode) end

commands.namedstructurevariable     = sections.structuredata
commands.namedstructureuservariable = sections.userdata

commands.setsectionlevel            = sections.setlevel
commands.setsectionnumber           = sections.setnumber
commands.getsectionnumber           = sections.getnumber
commands.getfullsectionnumber       = sections.fullnumber
commands.getstructuredata           = sections.structuredata
commands.getcurrentsectionlevel     = sections.getcurrentlevel

commands.setsectionblock            = sections.setblock
commands.pushsectionblock           = sections.pushblock
commands.popsectionblock            = sections.popblock

commands.registersection            = sections.register
commands.setsectionentry            = sections.setentry
commands.reportstructure            = sections.reportstructure
--

local byway = "^" .. v_by -- ugly but downward compatible

function commands.way(way)
    context((gsub(way,byway,"")))
end
