if not modules then modules = { } end modules ['strc-pag'] = {
    version   = 1.001,
    comment   = "companion to strc-pag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local trace_pages         = false  trackers.register("structures.pages", function(v) trace_pages = v end)

local report_pages        = logs.reporter("structure","pages")

local structures          = structures

local helpers             = structures.helpers
local sections            = structures.sections
local pages               = structures.pages
local sets                = structures.sets
local counters            = structures.counters

local counterdata         = counters.data

local variables           = interfaces.variables
local context             = context
local commands            = commands
local implement           = interfaces.implement

local processors          = typesetters.processors
local applyprocessor      = processors.apply
local startapplyprocessor = processors.startapply
local stopapplyprocessor  = processors.stopapply

local texsetcount         = tex.setcount
local texgetcount         = tex.getcount

local ctx_convertnumber   = context.convertnumber

-- storage

local collected, tobesaved = allocate(), allocate()

pages.collected = collected
pages.tobesaved = tobesaved
pages.nofpages  = 0

-- utilitydata.structures.counters.collected.realpage[1]

local function initializer()
    collected = pages.collected
    tobesaved = pages.tobesaved
    -- tricky, with pageinjection we can have holes
 -- pages.nofpages = #collected
 -- pages.nofpages = table.count(collected) -- could be a helper
    local n = 0
    for k in next, collected do
        if k > n then
            n = k
        end
    end
    pages.nofpages = n
end

job.register('structures.pages.collected', tobesaved, initializer)

local specification = { } -- to be checked

function pages.save(prefixdata,numberdata,extradata)
    local realpage = texgetcount("realpageno")
    local userpage = texgetcount("userpageno")
    if realpage > 0 then
        if trace_pages then
            report_pages("saving page %s.%s",realpage,userpage)
        end
        local viewerprefix = extradata.viewerprefix
        local state = extradata.state
        local data = {
            number       = userpage,
            viewerprefix = viewerprefix ~= "" and viewerprefix or nil,
            state        = state ~= "" and state or nil, -- maybe let "start" be default
            block        = sections.currentblock(),
            prefixdata   = prefixdata and helpers.simplify(prefixdata),
            numberdata   = numberdata and helpers.simplify(numberdata),
        }
        tobesaved[realpage] = data
        if not collected[realpage] then
            collected[realpage] = data
        end
    elseif trace_pages then
        report_pages("not saving page %s.%s",realpage,userpage)
    end
end

-- We can set the pagenumber but as it only get incremented in the page
-- builder we have to make sure it starts at least at 1.

function counters.specials.userpage()
    local r = texgetcount("realpageno")
    if r > 0 then
        local t = tobesaved[r]
        if t then
            t.number = texgetcount("userpageno")
            if trace_pages then
                report_pages("forcing pagenumber of realpage %s to %s",r,t.number)
            end
            return
        end
    end
    local u = texgetcount("userpageno")
    if u == 0 then
        if trace_pages then
            report_pages("forcing pagenumber of realpage %s to %s (probably a bug)",r,1)
        end
        counters.setvalue("userpage",1)
        texsetcount("userpageno",1) -- not global ?
    end
end

-- local f_convert = string.formatters["\\convertnumber{%s}{%s}"]
--
-- local function convertnumber(str,n)
--     return f_convert(str or "numbers",n)
-- end

function pages.number(realdata,pagespec)
    local userpage      = realdata.number
    local block         = realdata.block or "" -- sections.currentblock()
    local numberspec    = realdata.numberdata
    local conversionset = (pagespec and pagespec.conversionset ~= "" and pagespec.conversionset) or (numberspec and numberspec.conversionset ~= "" and numberspec.conversionset) or ""
    local conversion    = (pagespec and pagespec.conversion    ~= "" and pagespec.conversion   ) or (numberspec and numberspec.conversion    ~= "" and numberspec.conversion   ) or ""
    local starter       = (pagespec and pagespec.starter       ~= "" and pagespec.starter      ) or (numberspec and numberspec.starter       ~= "" and numberspec.starter      ) or ""
    local stopper       = (pagespec and pagespec.stopper       ~= "" and pagespec.stopper      ) or (numberspec and numberspec.stopper       ~= "" and numberspec.stopper      ) or ""
    if starter ~= "" then
        applyprocessor(starter)
    end
    if conversion ~= "" then
        ctx_convertnumber(conversion,userpage)
    else
        if conversionset == "" then conversionset = "default" end
        local theconversion = sets.get("structure:conversions",block,conversionset,1,"numbers") -- to be checked: 1
        local data = startapplyprocessor(theconversion)
        ctx_convertnumber(data or "number",userpage)
        stopapplyprocessor()
    end
    if stopper ~= "" then
        applyprocessors(stopper)
    end
end

-- (pagespec.prefix == yes|unset) and (pages.prefix == yes) => prefix

function pages.analyze(entry,pagespecification)
    -- safeguard
    if not entry then
        return false, false, "no entry"
    end
    local references = entry.references
    if not references then
        return false, false, "no references"
    end
    local pagedata = references.pagedata -- sometimes resolved (external)
    if not pagedata then
        local realpage = references.realpage
        if realpage then
            pagedata = collected[realpage]
        else
            return false, false, "no realpage"
        end
    end
    if not pagedata then
        return false, false, "no pagedata"
    end
    local sectiondata = references.sectiondata -- sometimes resolved (external)
    if not sectiondata then
        local section = references.section
        if section then
            sectiondata = sections.collected[section]
        else
            return pagedata, false, "no section"
        end
    end
    if not sectiondata then
        return pagedata, false, "no sectiondata"
    end
    local v_no = variables.no
    -- local preferences
    if pagespecification and pagespecification.prefix == v_no then
        return pagedata, false, "current spec blocks prefix"
    end
    -- stored preferences
 -- if entry.prefix == v_no then
 --     return pagedata, false, "entry blocks prefix"
 -- end
    -- stored page state
    pagespecification = pagedata.prefixdata
    if pagespecification and pagespecification.prefix == v_no then
        return pagedata, false, "pagedata blocks prefix"
    end
    -- final verdict
    return pagedata, sectiondata, "okay"
end

function helpers.page(data,pagespec)
    if data then
        local pagedata = pages.analyze(data,pagespec)
        if pagedata then
            pages.number(pagedata,pagespec)
        end
    end
end

function helpers.prefixpage(data,prefixspec,pagespec)
    if data then
        local pagedata, prefixdata, e = pages.analyze(data,pagespec)
        if pagedata then
            if prefixdata then
                sections.typesetnumber(prefixdata,"prefix",prefixspec or false,prefixdata or false,pagedata.prefixdata or false)
            end
            pages.number(pagedata,pagespec)
        end
    end
end

function helpers.prefixlastpage(data,prefixspec,pagespec)
    if data then
        local r  = data.references
        local ls = r.section
        local lr = r.realpage
        r.section  = r.lastsection or r.section
        r.realpage = r.lastrealpage or r.realpage
        helpers.prefixpage(data,prefixspec,pagespec)
        r.section, r.realpage = ls, lr
    end
end

--

function helpers.analyze(entry,specification)
    -- safeguard
    if not entry then
        return false, false, "no entry"
    end
    local yes = variables.yes
    local no  = variables.no
    -- section data
    local references = entry.references
    if not references then
        return entry, false, "no references"
    end
    local section = references.section
    if not section then
        return entry, false, "no section"
    end
    local sectiondata = sections.collected[references.section]
    if not sectiondata then
        return entry, false, "no section data"
    end
    -- local preferences
    if specification and specification.prefix == no then
        return entry, false, "current spec blocks prefix"
    end
    -- stored preferences (not used)
    local prefixdata = entry.prefixdata
    if prefixdata and prefixdata.prefix == no then
        return entry, false, "entry blocks prefix"
    end
    -- final verdict
    return entry, sectiondata, "okay"
end

function helpers.prefix(data,prefixspec,nosuffix)
    if data then
        local _, prefixdata, status = helpers.analyze(data,prefixspec)
        if prefixdata then
            if nosuffix and prefixspec then
                local connector = prefixspec.connector
                prefixspec.connector = nil
                sections.typesetnumber(prefixdata,"prefix",prefixspec or false,data.prefixdata or false,prefixdata or false)
                prefixspec.connector = connector
            else
                sections.typesetnumber(prefixdata,"prefix",prefixspec or false,data.prefixdata or false,prefixdata or false)
            end
        end
    end
end

function helpers.pageofinternal(n,prefixspec,pagespec)
    local data = structures.references.internals[n]
    if not data then
        -- error
    elseif prefixspec then
        helpers.prefixpage(data,prefixspec,pagespec)
    else
        helpers.prefix(data,pagespec)
    end
end

function pages.is_odd(n)
    n = n or texgetcount("realpageno")
    if texgetcount("pagenoshift") % 2 == 0 then
        return n % 2 ~= 0
    else
        return n % 2 == 0
    end
end

function pages.on_right(n)
    local pagemode = texgetcount("pageduplexmode")
    if pagemode == 2 or pagemode == 1 then
        n = n or texgetcount("realpageno")
        if texgetcount("pagenoshift") % 2 == 0 then
            return n % 2 ~= 0
        else
            return n % 2 == 0
        end
    else
        return true
    end
end

function pages.in_body(n)
    return texgetcount("pagebodymode") > 0
end

function pages.fraction(n)
    local lastpage = texgetcount("lastpageno") -- can be cached
    return lastpage > 1 and (texgetcount("realpageno")-1)/(lastpage-1) or 1
end

-- move to strc-pag.lua

function counters.analyze(name,counterspecification)
    local cd = counterdata[name]
    -- safeguard
    if not cd then
        return false, false, "no counter data"
    end
    -- section data
    local sectiondata = sections.current()
    if not sectiondata then
        return cd, false, "not in section"
    end
    local references = sectiondata.references
    if not references then
        return cd, false, "no references"
    end
    local section = references.section
    if not section then
        return cd, false, "no section"
    end
    sectiondata = sections.collected[references.section]
    if not sectiondata then
        return cd, false, "no section data"
    end
    -- local preferences
    local no = variables.no
    if counterspecification and counterspecification.prefix == no then
        return cd, false, "current spec blocks prefix"
    end
    -- stored preferences (not used)
    if cd.prefix == no then
        return cd, false, "entry blocks prefix"
    end
    -- sectioning
    -- if sectiondata.prefix == no then
    --     return false, false, "sectiondata blocks prefix"
    -- end
    -- final verdict
    return cd, sectiondata, "okay"
end

function sections.prefixedconverted(name,prefixspec,numberspec)
    local cd, prefixdata, result = counters.analyze(name,prefixspec)
    if cd then
        if prefixdata then
            sections.typesetnumber(prefixdata,"prefix",prefixspec or false,cd or false)
        end
        counters.converted(name,numberspec)
    end
end

--

implement {
    name      = "savepagedata",
    actions   = pages.save,
    arguments = {
        {
            { "prefix" },
            { "separatorset" },
            { "conversionset" },
            { "conversion" },
            { "set" },
            { "segments" },
            { "connector" },
        },
        {
            { "conversionset" },
            { "conversion" },
            { "starter" },
            { "stopper" },
        },
        {
            { "viewerprefix" },
            { "state" },
        }
    }
}

implement { -- weird place
    name      = "prefixedconverted",
    actions   = sections.prefixedconverted,
    arguments = {
        "string",
        {
            { "prefix" },
            { "separatorset" },
            { "conversionset" },
            { "conversion" },
            { "starter" },
            { "stopper" },
            { "set" },
            { "segments" },
            { "connector" },
        },
        {
            { "order" },
            { "separatorset" },
            { "conversionset" },
            { "conversion" },
            { "starter" },
            { "stopper" },
            { "segments" },
            { "type" },
            { "criterium" },
        }
    }
}

interfaces.implement {
    name      = "pageofinternal",
    arguments = { "integer" },
    actions   = helpers.pageofinternal,
}
