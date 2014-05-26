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

local tracers        = { }
publications.tracers = tracers
local datasets       = publications.datasets

local context = context

local ctx_NC, ctx_NR, ctx_HL, ctx_FL, ctx_ML, ctx_LL = context.NC, context.NR, context.HL, context.FL, context.ML, context.LL
local ctx_bold, ctx_rotate = context.bold, context.rotate
local ctx_darkgreen, ctx_darkred, ctx_darkblue = context.darkgreen, context.darkred, context.darkblue
local ctx_starttabulate, ctx_stoptabulate = context.starttabulate, context.stoptabulate

-- TEXT hyperlink author number date

local fields = table.sorted {
    "abstract",
    "address",
    "annotate",
    "author",
    "booktitle",
    "chapter",
    "comment",
    "country",
    "doi",
    "edition",
    "editor",
    "eprint",
    "howpublished",
    "institution",
    "isbn",
    "issn",
    "journal",
    "key",
    "keyword",
    "keywords",
    "language",
    "lastchecked",
    "month",
    "names",
    "note",
    "notes",
    "number",
    "organization",
    "pages",
    "publisher",
    "school",
    "series",
    "size",
    "title",
    "type",
    "url",
    "volume",
    "year",
    "nationality",
    "assignee",
    "bibnumber",
    "day",
    "dayfiled",
    "monthfiled",
    "yearfiled",
    "revision",
}

local citevariants = table.sorted {
    "author",
    "authoryear",
    "authoryears",
    "authornum",
    "year",
    "short",
    "serial",
    "key",
    "doi",
    "url",
    "type",
    "page",
    "none",
    "num",
}

local listvariants = table.sorted {
    "author",
    "editor",
    "artauthor",
}

local categories = {
    article = {
        required = { "author", "title", "journal", "year" },
        optional = { "volume", "number", "pages", "month", "note" },
    },
    book = {
        required = { { "author", "editor" }, "title", "publisher", "year" },
        optional = { { "volume", "number" }, "series", "address", "edition", "month","note" },
    },
    booklet = {
        required = { "title" },
        optional = { "author", "howpublished", "address", "month", "year", "note" },
    },
    inbook = {
        required = { { "author", "editor" }, "title", { "chapter", "pages" }, "publisher","year" },
        optional = { { "volume", "number" }, "series", "type", "address", "edition", "month", "note" },
    },
    incollection = {
        required = { "author", "title", "booktitle", "publisher", "year" },
        optional = { "editor", { "volume", "number" }, "series", "type", "chapter", "pages", "address", "edition", "month", "note" },
    },
    inproceedings = {
        required = { "author", "title", "booktitle", "year" },
        optional = { "editor", { "volume", "number" }, "series", "pages", "address", "month","organization", "publisher", "note" },
    },
    manual = {
        required = { "title" },
        optional = { "author", "organization", "address", "edition", "month", "year", "note" },
    },
    mastersthesis = {
        required = { "author", "title", "school", "year" },
        optional = { "type", "address", "month", "note" },
    },
    misc = {
        required = { "author", "title", "howpublished", "month", "year", "note" },
        optional = { "author", "title", "howpublished", "month", "year", "note" },
    },
    phdthesis = {
        required = { "author", "title", "school", "year" },
        optional = { "type", "address", "month", "note" },
    },
    proceedings = {
        required = { "title", "year" },
        optional = { "editor", { "volume", "number" }, "series", "address", "month", "organization", "publisher", "note" },
    },
    techreport = {
        required = { "author", "title", "institution", "year" },
        optional = { "type", "number", "address", "month", "note" },
    },
    unpublished = {
        required = { "author", "title", "note" },
        optional = { "month", "year" },
    },
}


publications.tracers.fields       = fields
publications.tracers.categories   = categories
publications.tracers.citevariants = citevariants
publications.tracers.listvariants = listvariants

-- -- --

function tracers.showdatasetfields(dataset)
    local luadata = datasets[dataset].luadata
    if next(luadata) then
        ctx_starttabulate { "|lT|lT|pT|" }
            ctx_NC() bold("tag")
            ctx_NC() bold("category")
            ctx_NC() bold("fields")
            ctx_NC() ctx_NR()
            ctx_FL()
            for k, v in sortedhash(luadata) do
                ctx_NC() context(k)
                ctx_NC() context(v.category)
                ctx_NC()
                for k, v in sortedhash(v) do
                    if k ~= "details" and k ~= "tag" and k ~= "category" then
                        context("%s ",k)
                    end
                end
                ctx_NC() ctx_NR()
            end
        ctx_stoptabulate()
    end
end

function tracers.showdatasetcompleteness(dataset)

    dataset = datasets[dataset]

    local preamble = { "|lBTw(10em)|p|" }

    local function required(key,value,indirect)
        ctx_NC() ctx_darkgreen(key)
        ctx_NC() if indirect then
                ctx_darkblue(value)
             elseif value then
                context(value)
             else
                ctx_darkred("\\tttf [missing]")
             end
        ctx_NC() ctx_NR()
    end

    local function optional(key,value,indirect)
        ctx_NC() context(key)
        ctx_NC() if indirect then
                ctx_darkblue(value)
             elseif value then
                context(value)
             end
        ctx_NC() ctx_NR()
    end

    local function identified(tag,crossref)
        ctx_NC() context("tag")
        ctx_NC() if crossref then
                context("\\tttf %s\\hfill\\darkblue => %s",tag,crossref)
             else
                context("\\tttf %s",tag)
             end
        ctx_NC() ctx_NR()
    end

    local luadata = datasets[dataset].luadata

    if next(luadata) then
        for tag, entry in table.sortedhash(luadata) do
            local category = entry.category
            local fields = categories[category]
            if fields then
                ctx_starttabulate(preamble)
                identified(tag,entry.crossref)
                ctx_HL()
                local requiredfields = fields.required
                local optionalfields = fields.optional
                for i=1,#requiredfields do
                    local r = requiredfields[i]
                    if type(r) == "table" then
                        local okay = true
                        for i=1,#r do
                            local ri = r[i]
                            if rawget(entry,ri) then
                                required(ri,entry[ri])
                                okay = true
                            elseif entry[ri] then
                                required(ri,entry[ri],true)
                                okay = true
                            end
                        end
                        if not okay then
                            required(table.concat(r,"\\letterbar "))
                        end
                    elseif rawget(entry,r) then
                        required(r,entry[r])
                    elseif entry[r] then
                        required(r,entry[r],true)
                    else
                        required(r)
                    end
                end
                for i=1,#optionalfields do
                    local o = optionalfields[i]
                    if type(o) == "table" then
                        for i=1,#o do
                            local oi = o[i]
                            if rawget(entry,oi) then
                                optional(oi,entry[oi])
                            elseif entry[oi] then
                                optional(oi,entry[oi],true)
                            end
                        end
                    elseif rawget(entry,o) then
                        optional(o,entry[o])
                    elseif entry[o] then
                        optional(o,entry[o],true)
                    end
                end
                ctx_stoptabulate()
            else
                -- error
            end
        end
    end

end

function tracers.showfields(settings)
    local rotation    = settings.rotation
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

function tracers.addfield(f,c)
    -- no checking now
    if type(f) == "string" then
        f = settings_to_array(f)
        if #f == 1 then
            f = f[1]
        end
    end
    if type(c) == "string" then
        c = settings_to_array(c)
    end
    for i=1,#c do
        local ci = c[i]
        local category = categories[ci]
        if category then
            local optional = category.optional
            if optional then
                optional[#optional+1] = f
            else
                categories[ci] = { optional = { f } }
            end
        else
            categories[ci] = { optional = { f } }
        end
    end
end


commands.showbtxdatasetfields       = tracers.showdatasetfields
commands.showbtxdatasetcompleteness = tracers.showdatasetcompleteness
commands.showbtxfields              = tracers.showfields
commands.btxaddfield                = tracers.addfield
