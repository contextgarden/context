if not modules then modules = { } end modules ['publ-tra'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: use context.tt .. more efficient, less code

local next, type, rawget = next, type, rawget

local sortedhash        = table.sortedhash
local sortedkeys        = table.sortedkeys
local settings_to_array = utilities.parsers.settings_to_array
local formatters        = string.formatters
local concat            = table.concat

local context           = context
local commands          = commands

local v_default         = interfaces.variables.default

local publications      = publications
local tracers           = publications.tracers
local tables            = publications.tables
local datasets          = publications.datasets
local specifications    = publications.specifications
local citevariants      = publications.citevariants

local getfield          = publications.getfield
local getcasted         = publications.getcasted

local ctx_NC, ctx_NR, ctx_HL, ctx_FL, ctx_ML, ctx_LL, ctx_EQ = context.NC, context.NR, context.HL, context.FL, context.ML, context.LL, context.EQ

local ctx_starttabulate = context.starttabulate
local ctx_stoptabulate  = context.stoptabulate

local ctx_formatted     = context.formatted
local ctx_bold          = ctx_formatted.monobold
local ctx_monobold      = ctx_formatted.monobold
local ctx_verbatim      = ctx_formatted.verbatim

local ctx_rotate        = context.rotate
local ctx_rlap          = context.rlap
local ctx_page          = context.page

local privates = tables.privates
local specials = tables.specials

local report   = logs.reporter("publications","tracers")

function tracers.showdatasetfields(settings)
    local dataset       = settings.dataset
    local current       = datasets[dataset]
    local luadata       = current.luadata
    local specification = settings.specification
    local fielddata     = specification and specifications[specification] or specifications.apa
    local categories    = fielddata.categories
    if next(luadata) then
        ctx_starttabulate { "|lT|lT|pTl|" }
            ctx_NC() ctx_bold("tag")
            ctx_NC() ctx_bold("category")
            ctx_NC() ctx_bold("fields")
            ctx_NC() ctx_NR()
            ctx_FL()
            for tag, entry in sortedhash(luadata) do
                local category = entry.category
                local catedata = categories[category]
                local fields   = catedata and catedata.fields or { }
                ctx_NC() context(tag)
                ctx_NC() context(category)
                ctx_NC() -- grouping around colors needed
                for key, value in sortedhash(entry) do
                    if privates[key] then
                        -- skip
                    elseif specials[key] then
                        context("{\\darkblue %s} ",key)
                    else
                        local kind = fields[key]
                        if kind == "required" then
                            context("{\\darkgreen %s} ",key)
                        elseif kind == "optional" then
                            context("%s ",key)
                        else
                            context("{\\darkyellow %s} ",key)
                        end
                    end
                end
                ctx_NC() ctx_NR()
            end
        ctx_stoptabulate()
    end
end

function tracers.showdatasetcompleteness(settings)
    local dataset       = settings.dataset
    local current       = datasets[dataset]
    local luadata       = current.luadata
    local specification = settings.specification
    local fielddata     = specification and specifications[specification] or specifications.apa
    local categories    = fielddata.categories

    local preamble = { "|lTBw(5em)|lBTp(10em)|plT|" }

    local function do_identified(tag,category,crossref,index)
        ctx_NC() ctx_monobold(index)
        ctx_NC() ctx_monobold(category)
        ctx_NC() if crossref then
                ctx_monobold("%s\\hfill\\darkblue => %s",tag,crossref)
             else
                ctx_monobold(tag)
             end
        ctx_NC() ctx_NR()
    end

    local function do_required(done,found,key,value,indirect)
        ctx_NC() if not done then ctx_monobold("required") end
        ctx_NC() context(key)
        ctx_NC()
            if indirect then
                if value then
                    context("\\darkblue")
                    ctx_verbatim(value)
                else
                    context("\\darkred\\tttf [missing crossref]")
                end
            elseif value then
                ctx_verbatim(value)
            else
                context("\\darkred\\tttf [missing value]")
            end
        ctx_NC() ctx_NR()
        found[key] = nil
        return done or true
    end

    local function do_optional(done,found,key,value,indirect)
        ctx_NC() if not done then ctx_monobold("optional") end
        ctx_NC() context(key)
        ctx_NC()
            if indirect then
                context("\\darkblue")
            end
            if value then
                ctx_verbatim(value)
            end
        ctx_NC() ctx_NR()
        found[key] = nil
        return done or true
    end

    local function do_special(done,key,value)
        ctx_NC() if not done then ctx_monobold("special") end
        ctx_NC() context(key)
        ctx_NC() if value then ctx_verbatim(value) end
        ctx_NC() ctx_NR()
        return done or true
    end

    local function do_extra(done,key,value)
        ctx_NC() if not done then ctx_monobold("extra") end
        ctx_NC() context(key)
        ctx_NC() if value then ctx_verbatim(value) end
        ctx_NC() ctx_NR()
        return done or true
    end

    if next(luadata) then
        for tag, entry in sortedhash(luadata) do
            local category = entry.category
            local fields   = categories[category]
            local found    = { }
            local flushed  = { }
            for k, v in next, entry do
                found[k] = true
            end
            ctx_starttabulate(preamble)
            do_identified(tag,category,entry.crossref,entry.index)
            ctx_FL()
            if fields then
                local required = fields.required
                local sets     = fields.sets or { }
                local done     = false
                if required then
                    for i=1,#required do
                        local r = required[i]
                        local r = sets[r] or r
                        if type(r) == "table" then
                            local okay = false
                            for i=1,#r do
                                local ri = r[i]
                                if not flushed[ri] then
                                    -- already done
                                    if rawget(entry,ri) then
                                        done = do_required(done,found,ri,entry[ri])
                                        okay = true
                                        flushed[ri] = true
                                    elseif entry[ri] then
                                        done = do_required(done,found,ri,entry[ri],true)
                                        okay = true
                                        flushed[ri] = true
                                    end
                                end
                            end
                            if not okay and not flushed[r] then
                                done = do_required(done,found,concat(r," {\\letterbar} "))
                                flushed[r] = true
                            end
                        elseif rawget(entry,r) then
                            if not flushed[r] then
                                done = do_required(done,found,r,entry[r])
                                flushed[r] = true
                            end
                        elseif entry[r] then
                            if not flushed[r] then
                                done = do_required(done,found,r,entry[r],true)
                                flushed[r] = true
                            end
                        else
                            if not flushed[r] then
                                done = do_required(done,found,r)
                                flushed[r] = true
                            end
                        end
                    end
                end
                local optional = fields.optional
                local done     = false
                if optional then
                    for i=1,#optional do
                        local o = optional[i]
                        local o = sets[o] or o
                        if type(o) == "table" then
                            for i=1,#o do
                                local oi = o[i]
                                if not flushed[oi] then
                                    if rawget(entry,oi) then
                                        done = do_optional(done,found,oi,entry[oi])
                                        flushed[oi] = true
                                    elseif entry[oi] then
                                        done = do_optional(done,found,oi,entry[oi],true)
                                        flushed[oi] = true
                                    end
                                end
                            end
                        elseif rawget(entry,o) then
                            if not flushed[o] then
                                done = do_optional(done,found,o,entry[o])
                                flushed[o] = true
                            end
                        elseif entry[o] then
                            if not flushed[o] then
                                done = do_optional(done,found,o,entry[o],true)
                                flushed[o] = true
                            end
                        end
                    end
                end
            end
            local done = false
            for k, v in sortedhash(found) do
                if privates[k] then
                    -- skip
                elseif specials[k] and not flushed[k] then
                    done = do_special(done,k,entry[k])
                    flushed[k] = true
                end
            end
            local done = false
            for k, v in sortedhash(found) do
                if privates[k] then
                    -- skip
                elseif not specials[k] and not flushed[k] then
                    done = do_extra(done,k,entry[k])
                    flushed[k] = true
                end
            end
            ctx_stoptabulate()
        end
    end

end

function tracers.showfields(settings)
    local rotation      = settings.rotation
    local specification = settings.specification
    local fielddata     = specification and specifications[specification] or specifications.apa
    local categories    = fielddata.categories
    local validfields   = { }
    for category, data in next, categories do
        local sets   = data.sets
        local fields = data.fields
        for name, list in next, fields do
            validfields[name] = true
        end
    end
    local s_categories = sortedkeys(categories)
    local s_fields     = sortedkeys(validfields)
    ctx_starttabulate { "|l" .. string.rep("|c",#s_categories) .. "|" }
    ctx_FL()
    ctx_NC()
    if rotation then
        rotation = { rotation = rotation }
    end
    for i=1,#s_categories do
        ctx_NC()
        local txt = formatters["\\bf %s"](s_categories[i])
        if rotation then
            ctx_rotate(rotation,txt)
        else
            context(txt)
        end
    end
    ctx_NC() ctx_NR()
    ctx_FL()
    for i=1,#s_fields do
        local field  = s_fields[i]
        ctx_NC()
        ctx_bold(field)
        for j=1,#s_categories do
            ctx_NC()
            local kind = categories[s_categories[j]].fields[field]
            if kind == "required" then
                context("\\darkgreen*")
            elseif kind == "optional" then
                context("*")
            end
        end
        ctx_NC() ctx_NR()
    end
    ctx_LL()
    ctx_stoptabulate()
end

function tracers.showtables(settings)
    for name, list in sortedhash(tables) do
        ctx_starttabulate { "|Tl|Tl|" }
        ctx_FL()
        ctx_NC()
        ctx_rlap(function() ctx_bold(name) end)
        ctx_NC()
        ctx_NC()
        ctx_NR()
        ctx_FL()
        for k, v in sortedhash(list) do
            ctx_NC()
            context(k)
            ctx_NC()
            if type(v) == "table" then
                context("% t",v)
            else
                context(tostring(v))
            end
            ctx_NC()
            ctx_NR()
        end
        ctx_LL()
        ctx_stoptabulate()
    end
end

function tracers.showdatasetauthors(settings)

    local dataset = settings.dataset
    local field   = settings.field

    local sortkey = publications.writers.author

    if not dataset or dataset == "" then dataset = v_default end
    if not field   or field   == "" then field   = "author"  end

    local function row(i,k,v)
        ctx_NC()
        if i then
            ctx_verbatim(i)
        end
        ctx_NC()
        if k then
            ctx_verbatim(k)
        end
        ctx_EQ()
        if type(v) == "table" then
            local t = { }
            for i=1,#v do
                local vi = v[i]
                if type(vi) == "table" then
                    t[i] = concat(vi,"-")
                else
                    t[i] = vi
                end
            end
            v = concat(t, " | ")
        end
        if v then
            ctx_verbatim(v)
        end
        ctx_NC()
        ctx_NR()
    end

    local function authorrow(ai,k,i)
        local v = ai[k]
        if v then
            row(i,k,v)
        end
    end

    local function commonrow(key,value)
        ctx_NC() if key then ctx_rlap(function() ctx_verbatim(key) end) end
        ctx_NC()
        ctx_EQ() if value then ctx_verbatim(value) end
        ctx_NC() ctx_NR()
    end

    local d = datasets[dataset].luadata

    local trialtypesetting = context.trialtypesetting()

    for tag, entry in sortedhash(d) do

        local a, f, k = getcasted(dataset,tag,field)

        if type(a) == "table" and #a > 0 and k == "author" then
            context.start()
            context.tt()
            ctx_starttabulate { "|B|Bl|p|" }
                ctx_FL()
                local original = getfield(dataset,tag,field)
                commonrow("tag",tag)
                commonrow("field",field)
                commonrow("original",original)
                commonrow("sortkey",sortkey(a))
                for i=1,#a do
                    ctx_ML()
                    local ai = a[i]
                    if ai then
                        authorrow(ai,"original",i)
                        authorrow(ai,"snippets")
                        authorrow(ai,"initials")
                        authorrow(ai,"firstnames")
                        authorrow(ai,"vons")
                        authorrow(ai,"surnames")
                        authorrow(ai,"juniors")
                        local options = ai.options
                        if options then
                            row(false,"options",sortedkeys(options))
                        end
                    elseif not trialtypesetting then
                        report("bad author name: %s",original or "?")
                    end
                end
                ctx_LL()
            ctx_stoptabulate()
            context.stop()
        end

    end

end

function tracers.showentry(dataset,tag)
    local dataset = datasets[dataset]
    if dataset then
        local entry = dataset.luadata[tag]
        local done  = false
        for k, v in sortedhash(entry) do
            if not privates[k] then
                ctx_verbatim("%w[%s: %s]",done and 1 or 0,k,v)
                done = true
            end
        end
    end
end

local skipped = { index = true, default = true }

function tracers.showvariants(dataset,pages)
    local variants = sortedkeys(citevariants)
    for tag in publications.sortedentries(dataset or v_default) do
        if pages then
            ctx_page()
        end
        ctx_starttabulate { "|T||" }
        for i=1,#variants do
            local variant = variants[i]
            if not skipped[variant] then
                ctx_NC() context(variant)
             -- ctx_EQ() citevariants[variant] { dataset = v_default, reference = tag, variant = variant }
                ctx_EQ() context.cite({variant},{dataset .. "::" .. tag})
                ctx_NC() ctx_NR()
            end
        end
        ctx_stoptabulate()
        if pages then
            ctx_page()
        end
    end
end

function tracers.showhashedauthors(dataset,pages)
    local components = publications.components.author
    ctx_starttabulate { "|T|T|T|T|T|T|" }
    ctx_NC() ctx_bold("hash")
    ctx_NC() ctx_bold("vons")
    ctx_NC() ctx_bold("surnames")
    ctx_NC() ctx_bold("initials")
    ctx_NC() ctx_bold("firstnames")
    ctx_NC() ctx_bold("juniors")
    ctx_NC() ctx_NR() ctx_HL()
    for hash, data in sortedhash(publications.authorcache) do
        local vons, surnames, initials, firstnames, juniors = components(data)
        ctx_NC() context(hash)
        ctx_NC() context(vons)
        ctx_NC() context(surnames)
        ctx_NC() context(initials)
        ctx_NC() context(firstnames)
        ctx_NC() context(juniors)
        ctx_NC() ctx_NR()
    end
    ctx_stoptabulate()
end

commands.showbtxdatasetfields       = tracers.showdatasetfields
commands.showbtxdatasetcompleteness = tracers.showdatasetcompleteness
commands.showbtxfields              = tracers.showfields
commands.showbtxtables              = tracers.showtables
commands.showbtxdatasetauthors      = tracers.showdatasetauthors
commands.showbtxhashedauthors       = tracers.showhashedauthors
commands.showbtxentry               = tracers.showentry
commands.showbtxvariants            = tracers.showvariants
