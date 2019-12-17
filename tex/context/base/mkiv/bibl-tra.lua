if not modules then modules = { } end modules ['bibl-tra'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- also see bibl-tra-new !

-- temporary hack, needed for transition

if not publications then

    local hacks = utilities.storage.allocate()

    job.register('publications.collected',hacks,function(t) publications.collected = t end)

end

-- end of hack


local gmatch, format = string.gmatch, string.format
local sort = table.sort
local savedata = io.savedata

bibtex       = bibtex or { }
local bibtex = bibtex

bibtex.hacks = bibtex.hacks or { }
local hacks  = bibtex.hacks

local trace_bibtex = false  trackers.register("publications.bibtex", function(v) trace_bibtex = v end)

local report_tex = logs.reporter("publications","tex")

local context     = context
local structures  = structures

local references  = structures.references
local sections    = structures.sections

local variables   = interfaces.variables

local v_short     = variables.short
local v_cite      = variables.cite
local v_default   = variables.default
local v_reference = variables.default

local list        = { }
local done        = { }
local alldone     = { }
local used        = { }
local registered  = { }
local ordered     = { }
local shorts      = { }
local mode        = 0

local template = [[
\citation{*}
\bibstyle{cont-%s}
\bibdata{%s}
]]

local runners = {
    bibtex = sandbox.registerrunner {
        name     = "bibtex",
        method   = "execute",
        program  = "bibtex",
        template = "%filename%",
        checkers = {
            filename = "readable",
        }
    },
    mlbibtex = sandbox.registerrunner {
        name     = "mlbibtex",
        method   = "execute",
        program  = "mlbibcontext",
        template = "%filename%",
        checkers = {
            filename = "readable",
        }
    }
}

local runner = environment.arguments.mlbibtex and runners.mlbibtex or runners.bibtex

directives.register("publications.usemlbibtex", function(v)
    runner = v and runners.mlbibtex or runners.bibtex
end)

function hacks.process(settings)
    local style = settings.style or ""
    local database = settings.database or ""
    local jobname = tex.jobname
    if database ~= "" then
        local targetfile = file.addsuffix(jobname,"aux")
        interfaces.showmessage("publications",3,targetfile)
        savedata(targetfile,format(template,style,database))
        if trace_bibtex then
            report_tex("processing bibtex file %a using %a",jobname,bibtexbin)
        end
        runner { filename = jobname }
        -- purge 'm
    end
end

function hacks.register(tag,short)
    if not short or short == "" then
        short = tag
    end
    if trace_bibtex then
        report_tex("registering bibtex entry %a with shortcut %a",tag,short)
    end
    local top = #registered + 1
    registered[top] = tag
    ordered   [tag] = top
    shorts    [tag] = short
end

function hacks.nofregistered()
    return #registered
end

function hacks.reset(m)
    mode, list, done = m, { }, { }
end

function hacks.add(str,listindex)
    if not str or mode == 0 then
        -- skip
    elseif mode == 1 then
        -- all locals but no duplicates
        local sc = sections.currentid()
        if done[str] ~= sc then
            done[str], alldone[str] = sc, true
            list[#list+1] = { str, listindex }
        end
    elseif mode == 2 then
        -- all locals but no preceding
        local sc = sections.currentid()
        if not alldone[str] and done[str] ~= sc then
            done[str], alldone[str] = sc, true
            list[#list+1] = { str, listindex }
        end
    end
end

function hacks.flush(sortvariant)
    local compare -- quite some checking for non-nil
    if sortvariant == "" or sortvariant == v_cite or sortvariant == v_default then
        -- order is cite order i.e. same as list
    elseif sortvariant == v_short then
        compare = function(a,b)
            local aa, bb = a and a[1], b and b[1]
            if aa and bb then
                local oa, ob = shorts[aa], shorts[bb]
                return oa and ob and oa < ob
            end
            return false
        end
    elseif sortvariant == v_reference then
        compare = function(a,b)
            local aa, bb = a and a[1], b and b[1]
            if aa and bb then
                return aa and bb and aa < bb
            end
            return false
        end
    else
        compare = function(a,b)
            local aa, bb = a and a[1], b and b[1]
            if aa and bb then
                local oa, ob = ordered[aa], ordered[bb]
                return oa and ob and oa < ob
            end
            return false
        end
    end
    if compare then
        sort(list,compare)
    end
    for i=1,#list do
        context.doprocessbibtexentry(list[i][1])
    end
end

function hacks.filterall()
    for i=1,#registered do
        list[i] = { registered[i], i }
    end
end

function hacks.registerplaced(str)
    used[str] = true
end

function hacks.doifalreadyplaced(str)
    commands.doifelse(used[str])
end

-- we ask for <n>:tag but when we can't find it we go back
-- to look for previous definitions, and when not found again
-- we look forward

local function compare(a,b)
    local aa, bb = a and a[3], b and b[3]
    return aa and bb and aa < bb
end

function hacks.resolve(prefix,block,reference) -- maybe already feed it split
    -- needs checking (the prefix in relation to components)
    local subsets
    local collected = references.collected
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
    if #subsets > 0 then
        local result, nofresult, done = { }, 0, { }
        block = tonumber(block)
        for i=1,#subsets do
            local subset = subsets[i]
            for rest in gmatch(reference,"[^, ]+") do
                local blk, tag, found = block, nil, nil
                if block then
                    tag = blk .. ":" .. rest
                    found = subset[tag]
                    if not found then
                        for i=block-1,1,-1 do
                            tag = i .. ":" .. rest
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
                    tag = blk .. ":" .. rest
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
        -- todo: ranges so the interface will change
        sort(result,compare)
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
                    collected[nofcollected] = { firstr[1], firstr[2], lastr[1], lastr[2] }
                else
                    nofcollected = nofcollected + 1
                    collected[nofcollected] = { firstr[1], firstr[2] }
                    if last > first then
                        nofcollected = nofcollected + 1
                        collected[nofcollected] = { lastr[1], lastr[2] }
                    end
                end
                first, last, firsti, lasti, firstr, lastr = current, current, i, i, r, r
            end
        end
        if first and last then
            if last > first + 1 then
                nofcollected = nofcollected + 1
                collected[nofcollected] = { firstr[1], firstr[2], lastr[1], lastr[2] }
            else
                nofcollected = nofcollected + 1
                collected[nofcollected] = { firstr[1], firstr[2] }
                if last > first then
                    nofcollected = nofcollected + 1
                    collected[nofcollected] = { lastr[1], lastr[2] }
                end
            end
        end
        if nofcollected > 0 then
            for i=1,nofcollected do
                local c = collected[i]
                if c[3] then
                    context.dowithbibtexnumrefrange(#collected,i,prefix,c[1],c[2],c[3],c[4])
                else
-- print(#collected,i,prefix,c[1],c[2])
                    context.dowithbibtexnumref(#collected,i,prefix,c[1],c[2])
                end
            end
        else
            context.nobibtexnumref("error 1")
        end
    else
        context.nobibtexnumref("error 2")
    end
end
