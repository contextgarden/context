if not modules then modules = { } end modules ['publ-tra'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local sortedhash = table.sortedhash

local tracers        = { }
publications.tracers = tracers
local datasets       = publications.datasets

local context = context
local NC, NR = context.NC, context.NR
local bold = context.bold
local darkgreen, darkred, darkblue = context.darkgreen, context.darkred, context.darkblue

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
        context.starttabulate { "|lT|lT|pT|" }
            NC() bold("tag")
            NC() bold("category")
            NC() bold("fields")
            NC() NR() context.FL() -- HL()
            for k, v in sortedhash(luadata) do
                NC() context(k)
                NC() context(v.category)
                NC()
                for k, v in sortedhash(v) do
                    if k ~= "details" and k ~= "tag" and k ~= "category" then
                        context("%s ",k)
                    end
                end
                NC() NR()
            end
        context.stoptabulate()
    end
end

function tracers.showdatasetcompleteness(dataset)

    dataset = datasets[dataset]

    local preamble = { "|lBTw(10em)|p|" }

    local function required(key,value,indirect)
        NC() darkgreen(key)
        NC() if indirect then
                darkblue(value)
             elseif value then
                context(value)
             else
                darkred("\\tttf [missing]")
             end
        NC() NR()
    end

    local function optional(key,value,indirect)
        NC() context(key)
        NC() if indirect then
                darkblue(value)
             elseif value then
                context(value)
             end
        NC() NR()
    end

    local function identified(tag,crossref)
        NC() context("tag")
        NC() if crossref then
                context("\\tttf %s\\hfill\\darkblue => %s",tag,crossref)
             else
                context("\\tttf %s",tag)
             end
        NC() NR()
    end

    local luadata = datasets[dataset].luadata

    if next(luadata) then
        for tag, entry in table.sortedhash(luadata) do
            local category = entry.category
            local fields = categories[category]
            if fields then
                context.starttabulate(preamble)
                identified(tag,entry.crossref)
                context.HL()
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
                context.stoptabulate()
            else
                -- error
            end
        end
    end

end

commands.showbtxdatasetfields       = tracers.showdatasetfields
commands.showbtxdatasetcompleteness = tracers.showdatasetcompleteness
