if not modules then modules = { } end modules ['publ-tra'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type

local sortedhash, sortedkeys = table.sortedhash, table.sortedkeys
local settings_to_array = utilities.parsers.settings_to_array
local formatters = string.formatters

local tracers  = publications.tracers or { }
local datasets = publications.datasets

local context = context

local ctx_NC, ctx_NR, ctx_HL, ctx_FL, ctx_ML, ctx_LL = context.NC, context.NR, context.HL, context.FL, context.ML, context.LL
local ctx_bold, ctx_rotate, ctx_llap = context.bold, context.rotate, context.llap
local ctx_darkgreen, ctx_darkred, ctx_darkblue = context.darkgreen, context.darkred, context.darkblue
local ctx_starttabulate, ctx_stoptabulate = context.starttabulate, context.stoptabulate

local categories = table.setmetatableindex(function(t,name)
    local filename      = resolvers.findfile(formatters["publ-imp-%s.lua"](name))
    local fields        = { }
    local specification = filename and filename ~= "" and table.load(filename) or {
        name       = name,
        version    = "1.00",
        comment    = "unknown specification.",
        author     = "anonymous",
        copyright  = "no one",
        categories = { },
    }
    --
    specification.fields = fields
    for category, data in next, specification.categories do
        local list = { }
        fields[category]  = list
        local required = data.required
        local optional = data.optional
        for i=1,#required do
            list[required[i]] = "required"
        end
        for i=1,#optional do
            list[optional[i]] = "optional"
        end
    end
    t[name] = specification
    return specification
end)

publications.tracers.categories = categories

-- -- --

local private = {
    category = true,
    tag      = true,
    index    = true,
}

function tracers.showdatasetfields(settings)
    local dataset = settings.dataset
    local current = datasets[dataset]
    local luadata = current.luadata
    if next(luadata) then
        local kind       = settings.kind
        local fielddata  = kind and categories[kind] or categories.apa
        local categories = fielddata.categories
        local fieldspecs = fielddata.fields
        ctx_starttabulate { "|lT|lT|pT|" }
            ctx_NC() ctx_bold("tag")
            ctx_NC() ctx_bold("category")
            ctx_NC() ctx_bold("fields")
            ctx_NC() ctx_NR()
            ctx_FL()
            for k, v in sortedhash(luadata) do
                local category = v.category
                local fields   = fieldspecs[category] or { }
                ctx_NC() context(k)
                ctx_NC() context(category)
                ctx_NC()
                for k, v in sortedhash(v) do
                    if not private[k] then
                        local f = fields[k]
                        if f == "required" then
                            ctx_darkgreen(k)
                        elseif not f then
                            ctx_darkred(k)
                        else
                            context(k)
                        end
                        context(" ")
                    end
                end
                ctx_NC() ctx_NR()
            end
        ctx_stoptabulate()
    end
end

function tracers.showdatasetcompleteness(settings)
    local dataset    = settings.dataset
    local current    = datasets[dataset]
    local luadata    = current.luadata
    local kind       = settings.kind
    local fielddata  = kind and categories[kind] or categories.apa
    local categories = fielddata.categories
    local fieldspecs = fielddata.fields

    local preamble = { "|lBTw(10em)|p|" }

    local function required(foundfields,key,value,indirect)
        ctx_NC() ctx_darkgreen(key)
        ctx_NC() if indirect then
                ctx_darkblue(value)
             elseif value then
                context(value)
             else
                ctx_darkred("\\tttf [missing]")
             end
        ctx_NC() ctx_NR()
        foundfields[key] = nil
    end

    local function optional(foundfields,key,value,indirect)
        ctx_NC() context(key)
        ctx_NC() if indirect then
                ctx_darkblue(value)
             elseif value then
                context(value)
             end
        ctx_NC() ctx_NR()
        foundfields[key] = nil
    end

    local function identified(tag,category,crossref)
        ctx_NC() context(category)
        ctx_NC() if crossref then
                context("\\tttf %s\\hfill\\darkblue => %s",tag,crossref)
             else
                context("\\tttf %s",tag)
             end
        ctx_NC() ctx_NR()
    end

    local function extra(key,value)
        ctx_NC() ctx_llap("+") context(key)
        ctx_NC() context(value)
        ctx_NC() ctx_NR()
    end

    if next(luadata) then
        for tag, entry in sortedhash(luadata) do
            local category    = entry.category
            local fields      = categories[category]
            local foundfields = { }
            for k, v in next, entry do
                foundfields[k] = true
            end
            ctx_starttabulate(preamble)
            identified(tag,category,entry.crossref)
            ctx_FL()
            if fields then
                local requiredfields = fields.required
                local optionalfields = fields.optional
                if requiredfields then
                    for i=1,#requiredfields do
                        local r = requiredfields[i]
                        if type(r) == "table" then
                            local okay = true
                            for i=1,#r do
                                local ri = r[i]
                                if rawget(entry,ri) then
                                    required(foundfields,ri,entry[ri])
                                    okay = true
                                elseif entry[ri] then
                                    required(foundfields,ri,entry[ri],true)
                                    okay = true
                                end
                            end
                            if not okay then
                                required(foundfields,table.concat(r,"\\letterbar "))
                            end
                        elseif rawget(entry,r) then
                            required(foundfields,r,entry[r])
                        elseif entry[r] then
                            required(foundfields,r,entry[r],true)
                        else
                            required(foundfields,r)
                        end
                    end
                end
                if optionalfields then
                    for i=1,#optionalfields do
                        local o = optionalfields[i]
                        if type(o) == "table" then
                            for i=1,#o do
                                local oi = o[i]
                                if rawget(entry,oi) then
                                    optional(foundfields,oi,entry[oi])
                                elseif entry[oi] then
                                    optional(foundfields,oi,entry[oi],true)
                                end
                            end
                        elseif rawget(entry,o) then
                            optional(foundfields,o,entry[o])
                        elseif entry[o] then
                            optional(foundfields,o,entry[o],true)
                        end
                    end
                end
            end
            for k, v in sortedhash(foundfields) do
                if not private[k] then
                    extra(k,entry[k])
                end
            end
            ctx_stoptabulate()
        end
    end

end

function tracers.showfields(settings)
    local rotation    = settings.rotation
    local kind        = settings.kind
    local fielddata   = kind and categories[kind] or categories.apa
    local categories  = fielddata.categories
    local fieldspecs  = fielddata.fields
    local swapped     = { }
    local validfields = { }
    for category, fields in next, categories do
        local categoryfields = { }
        for name, list in next, fields do
            for i=1,#list do
                local field = list[i]
                if type(field) == "table" then
                    field = table.concat(field," + ")
                end
                validfields[field] = true
                if swapped[field] then
                    swapped[field][category] = true
                else
                    swapped[field] = { [category] = true }
                end
            end
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
        local fields = swapped[field]
        ctx_NC()
        ctx_bold(field)
        for j=1,#s_categories do
            ctx_NC()
            if fields[s_categories[j]] then
                context("*")
            end
        end
        ctx_NC() ctx_NR()
    end
    ctx_LL()
    ctx_stoptabulate()
end

commands.showbtxdatasetfields       = tracers.showdatasetfields
commands.showbtxdatasetcompleteness = tracers.showdatasetcompleteness
commands.showbtxfields              = tracers.showfields
