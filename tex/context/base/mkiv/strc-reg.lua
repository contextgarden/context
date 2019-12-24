if not modules then modules = { } end modules ['strc-reg'] = {
    version   = 1.001,
    comment   = "companion to strc-reg.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type, tonumber, rawget = next, type, tonumber, rawget
local char, format, gmatch = string.char, string.format, string.gmatch
local equal, concat, remove = table.are_equal, table.concat, table.remove
local lpegmatch, P, C, Ct = lpeg.match, lpeg.P, lpeg.C, lpeg.Ct
local allocate = utilities.storage.allocate

local trace_registers    = false  trackers.register("structures.registers", function(v) trace_registers = v end)

local report_registers     = logs.reporter("structure","registers")

local structures           = structures
local registers            = structures.registers
local helpers              = structures.helpers
local sections             = structures.sections
local documents            = structures.documents
local pages                = structures.pages
local references           = structures.references

local usedinternals        = references.usedinternals

local mappings             = sorters.mappings
local entries              = sorters.entries
local replacements         = sorters.replacements

local processors           = typesetters.processors
local splitprocessor       = processors.split

local texgetcount          = tex.getcount

local variables            = interfaces.variables
local v_forward            = variables.forward
local v_all                = variables.all
local v_no                 = variables.no
local v_yes                = variables.yes
local v_packed             = variables.packed
local v_current            = variables.current
local v_previous           = variables.previous
local v_first              = variables.first
local v_last               = variables.last
local v_text               = variables.text
local v_section            = variables.section

local context              = context
local ctx_latelua          = context.latelua

local implement            = interfaces.implement

local matchingtilldepth    = sections.matchingtilldepth
local numberatdepth        = sections.numberatdepth
local currentlevel         = sections.currentlevel
local currentid            = sections.currentid

local touserdata           = helpers.touserdata

local internalreferences   = references.internals
local setinternalreference = references.setinternalreference

local setmetatableindex    = table.setmetatableindex

local absmaxlevel          = 5 -- \c_strc_registers_maxlevel

local h_prefixpage              = helpers.prefixpage
local h_prefixlastpage          = helpers.prefixlastpage
local h_title                   = helpers.title
local h_prefix                  = helpers.prefix

local ctx_startregisteroutput   = context.startregisteroutput
local ctx_stopregisteroutput    = context.stopregisteroutput
local ctx_startregistersection  = context.startregistersection
local ctx_stopregistersection   = context.stopregistersection
local ctx_startregisterentries  = context.startregisterentries
local ctx_stopregisterentries   = context.stopregisterentries
local ctx_startregisterentry    = context.startregisterentry
local ctx_stopregisterentry     = context.stopregisterentry
local ctx_startregisterpages    = context.startregisterpages
local ctx_stopregisterpages     = context.stopregisterpages
local ctx_startregisterseewords = context.startregisterseewords
local ctx_stopregisterseewords  = context.stopregisterseewords

local ctx_registerentry         = context.registerentry
local ctx_registerseeword       = context.registerseeword
local ctx_registerpagerange     = context.registerpagerange
local ctx_registeronepage       = context.registeronepage
local ctx_registersection       = context.registersection
local ctx_registerpacked        = context.registerpacked

-- possible export, but ugly code (overloads)
--
-- local output, section, entries, nofentries, pages, words, rawtext
--
-- h_title = function(a,b) rawtext = a end
--
-- local function ctx_startregisteroutput()
--     output     = { }
--     section    = nil
--     entries    = nil
--     nofentries = nil
--     pages      = nil
--     words      = nil
--     rawtext    = nil
-- end
-- local function ctx_stopregisteroutput()
--     inspect(output)
--     output     = nil
--     section    = nil
--     entries    = nil
--     nofentries = nil
--     pages      = nil
--     words      = nil
--     rawtext    = nil
-- end
-- local function ctx_startregistersection(tag)
--     section = { }
--     output[#output+1] = {
--         section = section,
--         tag     = tag,
--     }
-- end
-- local function ctx_stopregistersection()
-- end
-- local function ctx_startregisterentries(n)
--     entries = { }
--     nofentries = 0
--     section[#section+1] = entries
-- end
-- local function ctx_stopregisterentries()
-- end
-- local function ctx_startregisterentry(n) -- or subentries (nested?)
--     nofentries = nofentries + 1
--     entry = { }
--     entries[nofentries] = entry
-- end
-- local function ctx_stopregisterentry()
--     nofentries = nofentries - 1
--     entry = entries[nofentries]
-- end
-- local function ctx_startregisterpages()
--     pages = { }
--     entry.pages = pages
-- end
-- local function ctx_stopregisterpages()
-- end
-- local function ctx_startregisterseewords()
--     words = { }
--     entry.words = words
-- end
-- local function ctx_stopregisterseewords()
-- end
-- local function ctx_registerentry(processor,internal,seeparent,text)
--     text()
--     entry.text = {
--         processor = processor,
--         internal  = internal,
--         seeparent = seeparent,
--         text      = rawtext,
--     }
-- end
-- local function ctx_registerseeword(i,n,processor,internal,seeindex,seetext)
--     seetext()
--     entry.words[i] = {
--         processor = processor,
--         internal  = internal,
--         seeparent = seeparent,
--         seetext   = rawtext,
--     }
-- end
-- local function ctx_registerpagerange(fprocessor,finternal,frealpage,lprocessor,linternal,lrealpage)
--     pages[#pages+1] = {
--         first = {
--             processor = fprocessor,
--             internal  = finternal,
--             realpage  = frealpage,
--         },
--         last = {
--             processor = lprocessor,
--             internal  = linternal,
--             realpage  = lrealpage,
--         },
--     }
-- end
-- local function ctx_registeronepage(processor,internal,realpage)
--     pages[#pages+1] = {
--         processor = processor,
--         internal  = internal,
--         realpage  = realpage,
--     }
-- end

-- some day we will share registers and lists (although there are some conceptual
-- differences in the application of keywords)

local function filtercollected(names,criterium,number,collected,prevmode)
    if not criterium or criterium == "" then
        criterium = v_all
    end
    local data      = documents.data
    local numbers   = data.numbers
    local depth     = data.depth
    local hash      = { }
    local result    = { }
    local nofresult = 0
    local all       = not names or names == "" or names == v_all
    local detail    = nil
    if not all then
        for s in gmatch(names,"[^, ]+") do
            hash[s] = true
        end
    end
    if criterium == v_all or criterium == v_text then
        for i=1,#collected do
            local v = collected[i]
            if all then
                nofresult = nofresult + 1
                result[nofresult] = v
            else
                local vmn = v.metadata and v.metadata.name
                if hash[vmn] then
                    nofresult = nofresult + 1
                    result[nofresult] = v
                end
            end
        end
    elseif criterium == v_current then
        local collectedsections = sections.collected
        for i=1,#collected do
            local v = collected[i]
            local sectionnumber = collectedsections[v.references.section]
            if sectionnumber then
                local cnumbers = sectionnumber.numbers
                if prevmode then
                    if (all or hash[v.metadata.name]) and #cnumbers >= depth then -- is the = ok for lists as well?
                        local ok = true
                        for d=1,depth do
                            if not (cnumbers[d] == numbers[d]) then -- no zero test
                                ok = false
                                break
                            end
                        end
                        if ok then
                            nofresult = nofresult + 1
                            result[nofresult] = v
                        end
                    end
                else
                    if (all or hash[v.metadata.name]) and #cnumbers > depth then
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
    elseif criterium == v_previous then
        local collectedsections = sections.collected
        for i=1,#collected do
            local v = collected[i]
            local sectionnumber = collectedsections[v.references.section]
            if sectionnumber then
                local cnumbers = sectionnumber.numbers
                if (all or hash[v.metadata.name]) and #cnumbers >= depth then
                    local ok = true
                    if prevmode then
                        for d=1,depth do
                            if not (cnumbers[d] == numbers[d]) then
                                ok = false
                                break
                            end
                        end
                    else
                        for d=1,depth do
                            local cnd = cnumbers[d]
                            if not (cnd == 0 or cnd == numbers[d]) then
                                ok = false
                                break
                            end
                        end
                    end
                    if ok then
                        nofresult = nofresult + 1
                        result[nofresult] = v
                    end
                end
            end
        end
    elseif criterium == variables["local"] then
        if sections.autodepth(data.numbers) == 0 then
            return filtercollected(names,v_all,number,collected,prevmode)
        else
            return filtercollected(names,v_current,number,collected,prevmode)
        end
    else -- sectionname, number
        -- beware, this works ok for registers
        -- to be redone with reference instead
        local depth = sections.getlevel(criterium)
        local number = tonumber(number) or numberatdepth(depth) or 0
        if trace_registers then
            detail = format("depth: %s, number: %s, numbers: %s, startset: %s",depth,number,concat(sections.numbers(),".",1,depth),#collected)
        end
        if number > 0 then
            for i=1,#collected do
                local v = collected[i]
                local r = v.references
                if r then
                    local sectionnumber = sections.collected[r.section]
                    if sectionnumber then
                        local metadata = v.metadata
                        local cnumbers = sectionnumber.numbers
                        if cnumbers then
                            if (all or hash[metadata.name or false]) and #cnumbers >= depth and matchingtilldepth(depth,cnumbers) then
                                nofresult = nofresult + 1
                                result[nofresult] = v
                            end
                        end
                    end
                end
            end
        end
    end
    if trace_registers then
        if detail then
            report_registers("criterium %a, detail %a, found %a",criterium,detail,#result)
        else
            report_registers("criterium %a, detail %a, found %a",criterium,nil,#result)
        end
    end
    return result
end

local tobesaved           = allocate()
local collected           = allocate()

registers.collected       = collected
registers.tobesaved       = tobesaved
registers.filtercollected = filtercollected

-- we follow a different strategy than by lists, where we have a global
-- result table; we might do that here as well but since sorting code is
-- older we delay that decision

-- maybe store the specification in the format (although we predefine only
-- saved registers)

local function checker(t,k)
    local v = {
        metadata = {
            language = 'en',
            sorted   = false,
            class    = class,
        },
        entries  = { },
    }
    t[k] = v
    return v
end

local function initializer()
    tobesaved = registers.tobesaved
    collected = registers.collected
    setmetatableindex(tobesaved,checker)
    setmetatableindex(collected,checker)
    local usedinternals = references.usedinternals
    for name, list in next, collected do
        local entries = list.entries
        if not list.metadata.notsaved then
            for e=1,#entries do
                local entry = entries[e]
                local r = entry.references
                if r then
                    local internal = r and r.internal
                    if internal then
                        internalreferences[internal] = entry
                        usedinternals[internal] = r.used
                    end
                end
            end
        end
    end
 -- references.sortedinternals = sortedkeys(internalreferences) -- todo: when we need it more than once
end

local function finalizer()
    local flaginternals = references.flaginternals
    local usedviews     = references.usedviews
    for k, v in next, tobesaved do
        local entries = v.entries
        if entries then
            for i=1,#entries do
                local r = entries[i].references
                if r then
                    local i = r.internal
                    local f = flaginternals[i]
                    if f then
                        r.used = usedviews[i] or true
                    end
                end
            end
        end
    end
end

job.register('structures.registers.collected', tobesaved, initializer, finalizer)

setmetatableindex(tobesaved,checker)
setmetatableindex(collected,checker)

local function defineregister(class,method)
    local d = tobesaved[class]
    if method == v_forward then
        d.metadata.notsaved = true
    end
end

registers.define           = defineregister -- 4 times is somewhat over the top but we want consistency
registers.setmethod        = defineregister -- and we might have a difference some day

implement {
    name      = "defineregister",
    actions   = defineregister,
    arguments = "2 strings",
}

implement {
    name      = "setregistermethod",
    actions   = defineregister, -- duplicate use
    arguments = "2 strings",
}


local p_s = P("+")
local p_e = P("&") * (1-P(";"))^0 * P(";")
local p_r = C((p_e + (1-p_s))^0)

local entrysplitter_xml = Ct(p_r * (p_s * p_r)^0) -- bah
local entrysplitter_tex = lpeg.tsplitat('+')      -- & obsolete in mkiv

local tagged = { }

-- this whole splitting is an inheritance of mkii

local function preprocessentries(rawdata)
    local entries = rawdata.entries
    if entries then
        local processors = rawdata.processors
        local et         = entries.entries
        local kt         = entries.keys
        local entryproc  = processors and processors.entry
        local pageproc   = processors and processors.page
        local coding     = rawdata.metadata.coding
        if entryproc == "" then
            entryproc = nil
        end
        if pageproc == "" then
            pageproc = nil
        end
        if not et then
            local p, e = splitprocessor(entries.entry or "")
            if p then
                entryproc = p
            end
            et = lpegmatch(coding == "xml" and entrysplitter_xml or entrysplitter_tex,e)
        end
        if not kt then
            local p, k = splitprocessor(entries.key or "")
            if p then
                pageproc = p
            end
            kt = lpegmatch(coding == "xml" and entrysplitter_xml or entrysplitter_tex,k)
        end
        --
        entries = { }
        local ok = false
        for k=#et,1,-1 do
            local etk = et[k]
            local ktk = kt[k]
            if not ok and etk == "" then
                entries[k] = nil
            else
                entries[k] = { etk or "", ktk ~= "" and ktk or nil }
                ok = true
            end
        end
        rawdata.list = entries
        if pageproc or entryproc then
            rawdata.processors = { entryproc, pageproc } -- old way: indexed .. will be keys
        end
        rawdata.entries = nil
    end
    local seeword = rawdata.seeword
    if seeword then
        seeword.processor, seeword.text = splitprocessor(seeword.text or "")
    end
end

local function storeregister(rawdata) -- metadata, references, entries
    local references = rawdata.references
    local metadata   = rawdata.metadata
    -- checking
    if not metadata then
        metadata = { }
        rawdata.metadata = metadata
    end
    --
    if not metadata.kind then
        metadata.kind = "entry"
    end
    --
    --
    if not metadata.catcodes then
        metadata.catcodes = tex.catcodetable -- get
    end
    --
    local name     = metadata.name
    local notsaved = tobesaved[name].metadata.notsaved
    --
    if not references then
        references         = { }
        rawdata.references = references
    end
    --
    local internal = references.internal
    if not internal then
        internal = texgetcount("locationcount") -- we assume that it has been set
        references.internal = internal
    end
    --
    if notsaved then
        usedinternals[internal] = references.used -- todo view (we assume that forward references index entries are used)
    end
    --
    if not references.realpage then
        references.realpage = 0 -- just to be sure as it can be refered to
    end
    --
    local userdata = rawdata.userdata
    if userdata then
        rawdata.userdata = touserdata(userdata)
    end
    --
    references.section = currentid()
    metadata.level     = currentlevel()
    --
    local data     = notsaved and collected[name] or tobesaved[name]
    local entries  = data.entries
    internalreferences[internal] = rawdata
    preprocessentries(rawdata)
    entries[#entries+1] = rawdata
    local label = references.label
    if label and label ~= "" then
        tagged[label] = #entries
    else
        references.label = nil
    end
    return #entries
end

local function enhanceregister(specification)
    local name  = specification.name
    local n     = specification.n
    local saved = tobesaved[name]
    local data  = saved.metadata.notsaved and collected[name] or saved
    local entry = data.entries[n]
    if entry then
        entry.references.realpage = texgetcount("realpageno")
    end
end

-- This can become extendregister(specification)!

local function extendregister(name,tag,rawdata) -- maybe do lastsection internally
    if type(tag) == "string" then
        tag = tagged[tag]
    end
    if tag then
        local data = tobesaved[name].metadata.notsaved and collected[name] or tobesaved[name]
        local entry = data.entries[tag]
        if entry then
            local references = entry.references
            references.lastrealpage = texgetcount("realpageno")
            references.lastsection = currentid()
            if rawdata then
                local userdata = rawdata.userdata
                if userdata then
                    rawdata.userdata = touserdata(userdata)
                end
                if rawdata.entries then
                    preprocessentries(rawdata)
                end
                local metadata = rawdata.metadata
                if metadata and not metadata.catcodes then
                    metadata.catcodes = tex.catcodetable -- get
                end
                for k, v in next, rawdata do
                    local rk = references[k]
                    if not rk then
                        references[k] = v
                    else
                        for kk, vv in next, v do
                            if type(vv) == "table" then
                                if next(vv) then
                                    rk[kk] = vv
                                end
                            elseif vv ~= "" then
                                rk[kk] = vv
                            end
                        end
                    end
                end
            end
        end
    end
end

registers.store   = storeregister
registers.enhance = enhanceregister
registers.extend  = extendregister

function registers.get(tag,n)
    local list = tobesaved[tag]
    return list and list.entries[n]
end

implement {
    name      = "enhanceregister",
    arguments = { "string", "integer" },
    actions   = function(name,n)
        enhanceregister { name = name, n = n } -- todo: move to scanner
    end,
}

implement {
    name      = "deferredenhanceregister",
    arguments = { "string", "integer" },
    protected = true,
    actions   = function(name,n)
        ctx_latelua { action = enhanceregister, name = name, n = n }
    end,
}

implement {
    name      = "extendregister",
    actions   = extendregister,
    arguments = "2 strings",
}

implement {
    name      = "storeregister",
 -- actions   = function(rawdata)
 --     local nofentries = storeregister(rawdata)
 --     setinternalreference { internal = rawdata.references.internal }
 --     context(nofentries)
 -- end,
    actions   = { storeregister, context },
    arguments = {
        {
            { "metadata", {
                    { "kind" },
                    { "name" },
                    { "coding" },
                    { "level", "integer" },
                    { "catcodes", "integer" },
                    { "own" },
                    { "xmlroot" },
                    { "xmlsetup" }
                }
            },
            { "entries", {
                    { "entries", "list" },
                    { "keys", "list" },
                    { "entry" },
                    { "key" }
                }
            },
            { "references", {
                    { "internal", "integer" },
                    { "section", "integer" },
                    { "view" },
                    { "label" }
                }
            },
            { "seeword", {
                    { "text" }
                }
            },
            { "processors", {
                    { "entry" },
                    { "key" },
                    { "page" }
                }
            },
            { "userdata" },
        }
    }
}

-- sorting and rendering

local compare = sorters.comparers.basic

function registers.compare(a,b)
    local result = compare(a,b)
    if result ~= 0 then
        return result
    else
        local ka = a.metadata.kind
        local kb = b.metadata.kind
        if ka == kb then
            local ra = a.references
            local rb = b.references
            local pa = ra.realpage
            local pb = rb.realpage
            if not pa or not pb then
                return 0
            elseif pa < pb then
                return -1
            elseif pa > pb then
                return  1
            else
                -- new, we need to pick the right one of multiple and
                -- we want to prevent oscillation in the tuc file so:
                local ia = ra.internal
                local ib = rb.internal
                if not ia or not ib then
                    return 0
                elseif ia < ib then
                    return -1
                elseif ia > ib then
                    return  1
                else
                    return 0
                end
            end
        elseif ka == "see" then
            return 1
        elseif kb == "see" then
            return -1
        end
    end
    return 0
end

function registers.filter(data,options)
    data.result = registers.filtercollected(nil,options.criterium,options.number,data.entries,true)
end

local seeindex = 0

-- meerdere loops, seewords, dan words, anders seewords

-- todo: split seeword

local function crosslinkseewords(result,check) -- all words
    -- collect all seewords
    local seewords = { }
    for i=1,#result do
        local data = result[i]
        local seeword = data.seeword
        if seeword then
            local seetext = seeword.text
            if seetext and not seewords[seetext] then
                seeindex = seeindex + 1
                seewords[seetext] = seeindex
                if trace_registers then
                    report_registers("see word %03i: %s",seeindex,seetext)
                end
            end
        end
    end

    -- mark seeparents

 -- local seeparents = { }
 -- for i=1,#result do
 --     local data = result[i]
 --     local word = data.list[1]
 --     local okay = word and word[1]
 --     if okay then
 --         local seeindex = seewords[okay]
 --         if seeindex then
 --             seeparents[okay] = data
 --             data.references.seeparent = seeindex
 --             if trace_registers then
 --                 report_registers("see parent %03i: %s",seeindex,okay)
 --             end
 --         end
 --     end
 -- end

    local entries    = { }
    local keywords   = { }
    local seeparents = { }
    for i=1,#result do
        local data = result[i]
        local word = data.list
        local size = #word
        if data.seeword then
            -- beware: a seeword has an extra entry for sorting purposes
            size = size - 1
        end
        for i=1,size do
            local w = word[i]
            local e = w[1]
            local k = w[2] or e
            entries [i] = e
            keywords[i] = k
        end
        -- first try the keys
        local okay, seeindex
        for n=size,1,-1 do
            okay = concat(keywords,"+",1,n)
            seeindex = seewords[okay]
            -- first try the entries
            if seeindex then
                break
            end
            okay = concat(entries,"+",1,n)
            seeindex = seewords[okay]
            if seeindex then
                break
            end
        end
        if seeindex then
            seeparents[okay] = data
            data.references.seeparent = seeindex
            if trace_registers then
                report_registers("see parent %03i: %s",seeindex,okay)
            end
        end
    end

    -- mark seewords and extend sort list
    for i=1,#result do
        local data = result[i]
        local seeword = data.seeword
        if seeword then
            local text = seeword.text
            if text then
                local seeparent = seeparents[text]
                if seeparent then
                    local seeindex = seewords[text]
                    data.references.seeindex = seeindex
                    if trace_registers then
                        report_registers("see crosslink %03i: %s",seeindex,text)
                    end
                    seeword.valid = true
                elseif check then
                    report_registers("invalid crosslink : %s, %s",text,"ignored")
                    seeword.valid = false
                else
                    report_registers("invalid crosslink : %s, %s",text,"passed")
                    seeword.valid = true
                end
            end
        end
    end
end

local function removeemptyentries(result)
    local i, n, m = 1, #result, 0
    while i <= n do
        local entry = result[i]
        if #entry.list == 0 or #entry.split == 0 then
            remove(result,i)
            n = n - 1
            m = m + 1
        else
            i = i + 1
        end
    end
    if m > 0 then
        report_registers("%s empty entries removed in register",m)
    end
end

function registers.prepare(data,options)
    -- data has 'list' table
    local strip    = sorters.strip
    local splitter = sorters.splitters.utf
    local result   = data.result
    if result then
        local seeprefix = char(0)
        for i=1, #result do
            local entry = result[i]
            local split = { }
            local list  = entry.list
            if list then
                if entry.seeword then
                    -- we can have multiple seewords, only two levels supported
                    list[#list+1] = { seeprefix .. strip(entry.seeword.text) }
                end
                for l=1,#list do
                    local ll   = list[l]
                    local word = ll[1]
                    local key  = ll[2]
                    if not key or key == "" then
                        key = word
                    end
                    split[l] = splitter(strip(key))
                end
            end
            entry.split = split
        end
        removeemptyentries(result)
        crosslinkseewords(result,options.check ~= v_no)
    end
end

function registers.sort(data,options)
 -- if options.pagenumber == false then
 --     sorters.sort(data.result,compare)
 -- else
        sorters.sort(data.result,registers.compare)
 -- end
end

function registers.unique(data,options)
    local result     = { }
    local nofresult  = 0
    local prev       = nil
    local dataresult = data.result
    local bysection  = options.pagemethod == v_section -- normally page
    for k=1,#dataresult do
        local v = dataresult[k]
        if prev then
            local vr = v.references
            local pr = prev.references
            if not equal(prev.list,v.list) then
                -- ok
            elseif bysection and vr.section == pr.section then
                v = nil
                -- ok
            elseif pr.realpage ~= vr.realpage then
                -- ok
            else
                local pl = pr.lastrealpage
                local vl = vr.lastrealpage
                if pl or vl then
                    if not vl then
                        -- ok
                    elseif not pl then
                        -- ok
                    elseif pl ~= vl then
                        -- ok
                    else
                        v = nil
                    end
                else
                    v = nil
                end
            end
        end
        if v then
            nofresult = nofresult + 1
            result[nofresult] = v
            prev = v
        end
    end
    data.result = result
end

function registers.finalize(data,options) -- maps character to index (order)
    local result = data.result
    data.metadata.nofsorted = #result
    local split    = { }
    local nofsplit = 0
    local lasttag  = nil
    local done     = nil
    local nofdone  = 0
    local firstofsplit = sorters.firstofsplit
    for k=1,#result do
        local v = result[k]
        local entry, tag = firstofsplit(v)
        if tag ~= lasttag then
            if trace_registers then
                report_registers("splitting at %a",tag)
            end
            done     = { }
            nofdone  = 0
            nofsplit = nofsplit + 1
            lasttag  = tag
            split[nofsplit] = { tag = tag, data = done }
        end
        nofdone = nofdone + 1
        done[nofdone] = v
    end
    data.result = split
end

-- local function analyzeregister(class,options)
--     local data = collected[class]
--     if data and data.entries then
--         options = options or { }
--         sorters.setlanguage(options.language,options.method,options.numberorder)
--         registers.filter(data,options)   -- filter entries into results (criteria)
--         registers.prepare(data,options)  -- adds split table parallel to list table
--         registers.sort(data,options)     -- sorts results
--         registers.unique(data,options)   -- get rid of duplicates
--         registers.finalize(data,options) -- split result in ranges
--         data.metadata.sorted = true
--         return data.metadata.nofsorted or 0
--     else
--         return 0
--     end
-- end

local function analyzeregister(class,options)
    local data = rawget(collected,class)
    if not data then
        local list     = utilities.parsers.settings_to_array(class)
        local entries  = { }
        local metadata = false
        for i=1,#list do
            local l = list[i]
            local d = collected[l]
            local e = d.entries
            for i=1,#e do
                entries[#entries+1] = e[i]
            end
            if not metadata then
                metadata = d.metadata
            end
        end
        data = {
            metadata = metadata or { },
            entries  = entries,
        }
        collected[class] = data
    end
    if data and data.entries then
        options = options or { }
        sorters.setlanguage(options.language,options.method,options.numberorder)
        registers.filter(data,options)   -- filter entries into results (criteria)
        registers.prepare(data,options)  -- adds split table parallel to list table
        registers.sort(data,options)     -- sorts results
        registers.unique(data,options)   -- get rid of duplicates
        registers.finalize(data,options) -- split result in ranges
        data.metadata.sorted = true
        return data.metadata.nofsorted or 0
    else
        return 0
    end
end

registers.analyze = analyzeregister

implement {
    name      = "analyzeregister",
    actions   = { analyzeregister, context },
    arguments = {
        "string",
        {
            { "language" },
            { "method" },
            { "numberorder" },
            { "compress" },
            { "criterium" },
            { "pagenumber", "boolean" },
        }
    }
}

-- todo take conversion from index

function registers.userdata(index,name)
    local data = references.internals[tonumber(index)]
    return data and data.userdata and data.userdata[name] or nil
end

implement {
    name      = "registeruserdata",
    actions   = { registers.userdata, context },
    arguments = { "integer", "string" }
}

-- todo: ownnumber

local function pagerange(f_entry,t_entry,is_last,prefixspec,pagespec)
    local fer = f_entry.references
    local ter = t_entry.references
    ctx_registerpagerange(
        f_entry.metadata.name or "",
        f_entry.processors and f_entry.processors[2] or "",
        fer.internal or 0,
        fer.realpage or 0,
        function()
            h_prefixpage(f_entry,prefixspec,pagespec)
        end,
        ter.internal or 0,
        ter.lastrealpage or ter.realpage or 0,
        function()
            if is_last then
                h_prefixlastpage(t_entry,prefixspec,pagespec) -- swaps page and realpage keys
            else
                h_prefixpage    (t_entry,prefixspec,pagespec)
            end
        end
    )
end

local function pagenumber(entry,prefixspec,pagespec)
    local er = entry.references
    ctx_registeronepage(
        entry.metadata.name or "",
        entry.processors and entry.processors[2] or "",
        er.internal or 0,
        er.realpage or 0,
        function() h_prefixpage(entry,prefixspec,pagespec) end
    )
end

local function packed(f_entry,t_entry)
    local fer = f_entry.references
    local ter = t_entry.references
    ctx_registerpacked(
        fer.internal or 0,
        ter.internal or 0
    )
end

local function collapsedpage(pages)
    for i=2,#pages do
        local first             = pages[i-1]
        local second            = pages[i]
        local first_first       = first[1]
        local first_last        = first[2]
        local second_first      = second[1]
        local second_last       = second[2]
        local first_last_pn     = first_last  .references.realpage
        local second_first_pn   = second_first.references.realpage
        local second_last_pn    = second_last .references.realpage
        local first_last_last   = first_last  .references.lastrealpage
        local second_first_last = second_first.references.lastrealpage
        if first_last_last then
            first_last_pn = first_last_last
            if second_first == second_last and second_first_pn <= first_last_pn then
                -- 2=8, 5 -> 12=8
                remove(pages,i)
                return true
            elseif second_first == second_last and second_first_pn > first_last_pn then
                -- 2=8, 9 -> 2-9
                pages[i-1] = { first_first, second_last }
                remove(pages,i)
                return true
            elseif second_last_pn < first_last_pn then
                -- 2=8, 3-4 -> 2=8
                remove(pages,i)
                return true
            elseif first_last_pn < second_last_pn then
                -- 2=8, 3-9 -> 2-9
                pages[i-1] = { first_first, second_last }
                remove(pages,i)
                return true
            elseif first_last_pn + 1 == second_first_pn and second_last_pn > first_last_pn then
                -- 2=8, 9-11 -> 2-11
                pages[i-1] = { first_first, second_last }
                remove(pages,i)
                return true
            elseif second_first.references.lastrealpage then
                -- 2=8, 9=11 -> 2-11
                pages[i-1] = { first_first, second_last }
                remove(pages,i)
                return true
            end
        elseif second_first_last then
            second_first_pn = second_first_last
            if first_last_pn == second_first_pn then
                -- 2-4, 5=9 -> 2-9
                pages[i-1] = { first_first, second_last }
                remove(pages,i)
                return true
            end
        elseif first_last_pn == second_first_pn then
            -- 2-3, 3-4 -> 2-4
            pages[i-1] = { first_last, second_last }
            remove(pages,i)
            return true
        end
    end
    return false
end

local function collapsepages(pages)
    while collapsedpage(pages) do end
    return #pages
end

-- todo: create an intermediate structure and flush that

function registers.flush(data,options,prefixspec,pagespec)
    local compress         = options.compress
    local collapse_singles = compress == v_yes
    local collapse_ranges  = compress == v_all
    local collapse_packed  = compress == v_packed
    local show_page_number = options.pagenumber ~= false -- true or false
    local bysection        = options.pagemethod == v_section
    local result = data.result
    local maxlevel = 0
    --
    for i=1,#result do
        local data = result[i].data
        for d=1,#data do
            local m = #data[d].list
            if m > maxlevel then
                maxlevel = m
            end
        end
    end
    if maxlevel > absmaxlevel then
        maxlevel = absmaxlevel
        report_registers("limiting level to %a",maxlevel)
    end
    --
    ctx_startregisteroutput()
    local done    = { }
    local started = false
    for i=1,#result do
     -- ranges need checking !
        local sublist = result[i]
     -- local done = { false, false, false, false }
        for i=1,maxlevel do
            done[i] = false
        end
        local data = sublist.data
        local d    = 0
        local n    = 0
        ctx_startregistersection(sublist.tag)
        for d=1,#data do
            local entry = data[d]
            if entry.metadata.kind == "see" then
                local list = entry.list
                if #list > 1 then
                    list[#list] = nil
                else
                 -- we have an \seeindex{Foo}{Bar} without Foo being defined anywhere .. somehow this message is wrong
                 -- report_registers("invalid see entry in register %a, reference %a",entry.metadata.name,list[1][1])
                end
            end
        end
        -- ok, this is tricky: we use e[i] delayed so we need it to be local
        -- but we don't want to allocate too many entries so there we go

        while d < #data do
            d = d + 1
            local entry    = data[d]
            local metadata = entry.metadata
            local kind     = metadata.kind
            local list     = entry.list
            local e = { false, false, false }
            for i=3,maxlevel do
                e[i] = false
            end
            for i=1,maxlevel do
                if list[i] then
                    e[i] = list[i][1]
                end
                if e[i] == done[i] then
                    -- skip
                elseif not e[i] then
                    -- see ends up here
                    -- can't happen any more
                    done[i] = false
                    for j=i+1,maxlevel do
                        done[j] = false
                    end
                elseif e[i] == "" then
                    done[i] = false
                    for j=i+1,maxlevel do
                        done[j] = false
                    end
                else
                    done[i] = e[i]
                    for j=i+1,maxlevel do
                        done[j] = false
                    end
                    if started then
                        ctx_stopregisterentry()
                        started = false
                    end
                    if n == i then
                     -- ctx_stopregisterentries()
                     -- ctx_startregisterentries(n)
                    else
                        while n > i do
                            n = n - 1
                            ctx_stopregisterentries()
                        end
                        while n < i do
                            n = n + 1
                            ctx_startregisterentries(n)
                        end
                    end
                    local references = entry.references
                    local processors = entry.processors
                    local internal   = references.internal or 0
                    local seeparent  = references.seeparent or ""
                    local processor  = processors and processors[1] or ""
                    -- so, we need to keep e as is (local), or we need local title = e[i] ... which might be
                    -- more of a problem
                    ctx_startregisterentry(0) -- will become a counter
                    started = true
                    if metadata then
                        ctx_registerentry(metadata.name or "",processor,internal,seeparent,function() h_title(e[i],metadata) end)
                    else
                        -- can this happen?
                        ctx_registerentry("",processor,internal,seeindex,e[i])
                    end
                end
            end

            local function case_1()
                -- we collapse ranges and keep existing ranges as they are
                -- so we get prebuilt as well as built ranges
                local first, last, prev, pages, dd, nofpages = entry, nil, entry, { }, d, 0
                while dd < #data do
                    dd = dd + 1
                    local next = data[dd]
                    if next and next.metadata.kind == "see" then
                        dd = dd - 1
                        break
                    else
                        local el, nl = entry.list, next.list
                        if not equal(el,nl) then
                            dd = dd - 1
                        --~ first = nil
                            break
                        elseif next.references.lastrealpage then
                            nofpages = nofpages + 1
                            pages[nofpages] = first and { first, last or first } or { entry, entry }
                            nofpages = nofpages + 1
                            pages[nofpages] = { next, next }
                            first, last, prev = nil, nil, nil
                        elseif not first then
                            first, prev = next, next
                        elseif next.references.realpage - prev.references.realpage == 1 then -- 1 ?
                            last, prev = next, next
                        else
                            nofpages = nofpages + 1
                            pages[nofpages] = { first, last or first }
                            first, last, prev = next, nil, next
                        end
                    end
                end
                if first then
                    nofpages = nofpages + 1
                    pages[nofpages] = { first, last or first }
                end
                if collapse_ranges and nofpages > 1 then
                    nofpages = collapsepages(pages)
                end
                if nofpages > 0 then -- or 0
                    d = dd
                    for p=1,nofpages do
                        local first, last = pages[p][1], pages[p][2]
                        if first == last then
                            if first.references.lastrealpage then
                                pagerange(first,first,true,prefixspec,pagespec)
                            else
                                pagenumber(first,prefixspec,pagespec)
                            end
                        elseif last.references.lastrealpage then
                            pagerange(first,last,true,prefixspec,pagespec)
                        else
                            pagerange(first,last,false,prefixspec,pagespec)
                        end
                    end
                elseif entry.references.lastrealpage then
                    pagerange(entry,entry,true,prefixspec,pagespec)
                else
                    pagenumber(entry,prefixspec,pagespec)
                end
            end

            local function case_2()
                local first = nil
                local last  = nil
                while true do
                    if not first then
                        first = entry
                    end
                    last  = entry
                    if d == #data then
                        break
                    else
                        d = d + 1
                        local next = data[d]
                        if next.metadata.kind == "see" or not equal(entry.list,next.list) then
                            d = d - 1
                            break
                        else
                            entry = next
                        end
                    end
                end
                packed(first,last) -- returns internals
            end

            local function case_3()
                while true do
                    if entry.references.lastrealpage then
                        pagerange(entry,entry,true,prefixspec,pagespec)
                    else
                        pagenumber(entry,prefixspec,pagespec)
                    end
                    if d == #data then
                        break
                    else
                        d = d + 1
                        local next = data[d]
                        if next.metadata.kind == "see" or not equal(entry.list,next.list) then
                            d = d - 1
                            break
                        else
                            entry = next
                        end
                    end
                end
            end

            local function case_4()
                local t  = { }
                local nt = 0
                while true do
                    if entry.seeword and entry.seeword.valid then
                        nt = nt + 1
                        t[nt] = entry
                    end
                    if d == #data then
                        break
                    else
                        d = d + 1
                        local next = data[d]
                        if next.metadata.kind ~= "see" or not equal(entry.list,next.list) then
                            d = d - 1
                            break
                        else
                            entry = next
                        end
                    end
                end
                for i=1,nt do
                    local entry     = t[i]
                    local seeword   = entry.seeword
                    local seetext   = seeword.text or ""
                    local processor = seeword.processor or (entry.processors and entry.processors[1]) or ""
                    local seeindex  = entry.references.seeindex or ""
                    ctx_registerseeword(
                        metadata.name or "",
                        i,
                        nt,
                        processor,
                        0,
                        seeindex,
                        function() h_title(seetext,metadata) end
                    )
                end
            end

            local function case_5()
                local first = d
                while true do
                    if d == #data then
                        break
                    else
                        d = d + 1
                        local next = data[d]
                        if next.metadata.kind == "see" or not equal(entry.list,next.list) then
                            d = d - 1
                            break
                        else
                            entry = next
                        end
                    end
                end
                local last      = d
                local n         = last - first + 1
                local i         = 0
                local name      = metadata.name or ""
                local processor = entry.processors and entry.processors[1] or ""
                for e=first,last do
                    local d = data[e]
                    local sectionindex = d.references.internal or 0
                    i = i + 1
                    ctx_registersection(
                        name,
                        i,
                        n,
                        processor,
                        0,
                        sectionindex,
                        function() h_prefix(d,prefixspec,true) end
                    )
                end
            end

            if kind == "entry" then
                if show_page_number then
                    ctx_startregisterpages()
                    if bysection then
                        case_5()
                    elseif collapse_singles or collapse_ranges then
                        case_1()
                    elseif collapse_packed then
                        case_2()
                    else
                        case_3()
                    end
                    ctx_stopregisterpages()
                end
            elseif kind == "see" then
                ctx_startregisterseewords()
                case_4()
                ctx_stopregisterseewords()
            end

        end

        if started then
            ctx_stopregisterentry()
            started = false
        end
        while n > 0 do
            ctx_stopregisterentries()
            n = n - 1
        end
        ctx_stopregistersection()
    end
    ctx_stopregisteroutput()
    -- for now, maybe at some point we will do a multipass or so
    data.result = nil
    data.metadata.sorted = false
    -- temp hack for luajittex :
    local entries = data.entries
    for i=1,#entries do
        entries[i].split = nil
    end
 -- collectgarbage("collect")
end

function registers.process(class,...)
    if analyzeregister(class,...) > 0 then
        local data = collected[class]
        registers.flush(data,...)
    end
end

implement {
    name      = "processregister",
    actions   = registers.process,
    arguments = {
        "string",
        {
            { "language" },
            { "method" },
            { "numberorder" },
            { "compress" },
            { "criterium" },
            { "check" },
            { "pagemethod" },
            { "pagenumber", "boolean" },
        },
        {
            { "separatorset" },
            { "conversionset" },
            { "starter" },
            { "stopper" },
            { "set" },
            { "segments" },
            { "connector" },
        },
        {
            { "prefix" },
            { "separatorset" },
            { "conversionset" },
            { "starter" },
            { "stopper" },
            { "segments" },
        }
    }
}

-- linked registers

function registers.findinternal(tag,where,n)
 -- local collected = registers.collected
    local current   = collected[tag]
    if not current then
        return 0
    end
    local entries = current.entries
    if not entries then
        return 0
    end
    local entry = entries[n]
    if not entry then
        return 0
    end
    local list = entry.list
    local size = #list
    --
    local start, stop, step
    if where == v_previous then
        start = n - 1
        stop  = 1
        step  = -1
    elseif where == v_first then
        start = 1
        stop  = #entries
        step  = 1
    elseif where == v_last then
        start = #entries
        stop  = 1
        step  = -1
    else
        start = n + 1
        stop  = #entries
        step  = 1
    end
    --
    for i=start,stop,step do
        local r = entries[i]
        local l = r.list
        local s = #l
        if s == size then
            local ok = true
            for i=1,size do
                if list[i][1] ~= l[i][1] then
                    ok = false
                    break
                end
            end
            if ok then
                return r.references.internal or 0
            end
        end
    end
    return 0
end

interfaces.implement {
    name      = "findregisterinternal",
    arguments = { "string", "string", "integer" },
    actions   = { registers.findinternal, context },
}
