if not modules then modules = { } end modules ['strc-ini'] = {
    version   = 1.001,
    comment   = "companion to strc-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[
The restructuring is the (intermediate) result of quite some experiments. I started
with the basic structure, followed by lists, numbers, enumerations, itemgroups
and floats. All these have something in common, like pagenumbers and section
prefixes. I played with some generic datastructure (in order to save space) but
the code at both the lua and tex end then quickly becomes messy due to the fact
that access to variables is too different. So, eventually I ended up with
dedicated structures combined with sharing data. In lua this is quite efficient
because tables are referenced. However, some precautions are to be taken in
order to keep the utility file small. Utility data and process data share much
but it does not make sense to store all processdata.

]]--

local lpegmatch = lpeg.match
local type, next, tonumber, select = type, next, tonumber, select

local formatters        = string.formatters
local settings_to_array = utilities.parsers.settings_to_array
local settings_to_hash  = utilities.parsers.settings_to_hash
local allocate          = utilities.storage.allocate

local catcodenumbers    = catcodes.numbers -- better use the context(...) way to switch

local ctxcatcodes       = catcodenumbers.ctxcatcodes
local xmlcatcodes       = catcodenumbers.xmlcatcodes
local notcatcodes       = catcodenumbers.notcatcodes
local txtcatcodes       = catcodenumbers.txtcatcodes

local context           = context
local commands          = commands

local trace_processors  = false
local report_processors = logs.reporter("processors","structure")

trackers.register("typesetters.processors", function(v) trace_processors = v end)

local xmlconvert = lxml.convert
local xmlstore   = lxml.store

local ctx_pushcatcodes     = context.pushcatcodes
local ctx_popcatcodes      = context.popcatcodes
local ctx_xmlsetup         = context.xmlsetup
local ctx_xmlprocessbuffer = context.xmlprocessbuffer

-- -- -- namespace -- -- --

-- This is tricky: we have stored and initialized already some of
-- the job.registered tables so we have a forward reference!

structures       = structures or { }
local structures = structures

structures.blocks       = structures.blocks       or { }
structures.sections     = structures.sections     or { }
structures.pages        = structures.pages        or { }
structures.registers    = structures.registers    or { }
structures.references   = structures.references   or { }
structures.lists        = structures.lists        or { }
structures.helpers      = structures.helpers      or { }
structures.documents    = structures.documents    or { }
structures.notes        = structures.notes        or { }
structures.descriptions = structures.descriptions or { }
structures.itemgroups   = structures.itemgroups   or { }
structures.specials     = structures.specials     or { }
structures.counters     = structures.counters     or { }
structures.tags         = structures.tags         or { }
structures.formulas     = structures.formulas     or { } -- not used but reserved
structures.sets         = structures.sets         or { }
structures.marks        = structures.marks        or { }
structures.floats       = structures.floats       or { }
structures.synonyms     = structures.synonyms     or { }

--~ table.print(structures)

local processors        = typesetters.processors

-- -- -- specials -- -- --

-- we can store information and get back a reference; this permits
-- us to store rather raw data in references

local specials = structures.specials

local collected    = allocate()
local tobesaved    = allocate()

specials.collected = collected
specials.tobesaved = tobesaved

local function initializer()
    collected = specials.collected
    tobesaved = specials.tobesaved
end

if job then
    job.register('structures.specials.collected', tobesaved, initializer)
end

function specials.store(class,data)
    if class and data then
        local s = tobesaved[class]
        if not s then
            s = { }
            tobesaved[class] = s
        end
        s[#s+1] = data
        context(#s)
    else
        context(0)
    end
end

function specials.retrieve(class,n)
    if class and n then
        local c = collected[class]
        return c and c[n]
    end
end

-- -- -- helpers -- -- --

local helpers = structures.helpers

-- function helpers.touserdata(str)
--     local hash = str and str ~= "" and settings_to_hash(str)
--     if hash and next(hash) then
--         return hash
--     end
-- end

function helpers.touserdata(data)
    if type(data) == "string" then
        if data == "" then
            return nil
        else
            data = settings_to_hash(data)
        end
    end
    if data and next(data) then
        return data
    end
end

local function simplify(d,nodefault)
    if d then
        local t = { }
        for k, v in next, d do
            local tv = type(v)
            if tv == "table" then
                if next(v) then
                    t[k] = simplify(v)
                end
            elseif tv == "string" then
                if v ~= "" then
                    t[k] = v
                end
            elseif tv == "boolean" then
                if v then
                    t[k] = v
                end
            else
                t[k] = v
            end
        end
        return next(t) and t
    elseif nodefault then
        return nil
    else
        return { }
    end
end

-- we only care about the tuc file so this would do too:
--
-- local function simplify(d,nodefault)
--     if d then
--         for k, v in next, d do
--             local tv = type(v)
--             if tv == "string" then
--                 if v == "" or v == "default" then
--                     d[k] = nil
--                 end
--             elseif tv == "table" then
--                 if next(v) then
--                     simplify(v)
--                 end
--             elseif tv == "boolean" then
--                 if not v then
--                     d[k] = nil
--                 end
--             end
--         end
--         return d
--     elseif nodefault then
--         return nil
--     else
--         return { }
--     end
-- end

helpers.simplify = simplify

function helpers.merged(...)
    local t = { }
    for k=1, select("#",...) do
        local v = select(k,...)
        if v and v ~= "" and not t[k] then
            t[k] = v
        end
    end
    return t
end

local tags = {
    generic = "ctx:genericentry",
    section = "ctx:sectionentry",
    entry   = "ctx:registerentry",
}

--  We had the following but it overloads the main document so it's a no-go as we
--  no longer push and pop. So now we use the tag as buffername, namespace and also
--  (optionally) as a setups to be applied but keep in mind that document setups
--  also get applied (when they use #1's).
--
--  local command = formatters["\\xmlprocessbuffer{%s}{%s}{}"](metadata.xmlroot or "main",tag)

local overload_catcodes = true

directives.register("typesetters.processors.overloadcatcodes",function(v)
    -- number | true | false | string
    overload_catcodes = v
end)

local experiment = true

function helpers.title(title,metadata) -- coding is xml is rather old and not that much needed now
    if title and title ~= "" then      -- so it might disappear
        if metadata then
            local xmlsetup = metadata.xmlsetup
            if metadata.coding == "xml" then
                -- title can contain raw xml
                local tag = tags[metadata.kind] or tags.generic
                local xmldata = formatters["<?xml version='1.0'?><%s>%s</%s>"](tag,title,tag)
                if not experiment then
                    buffers.assign(tag,xmldata)
                end
                if trace_processors then
                    report_processors("putting xml data in buffer: %s",xmldata)
                    report_processors("processing buffer with setup %a and tag %a",xmlsetup,tag)
                end
                if experiment then
                    -- the question is: will this be forgotten ... better store in a via file
                    local xmltable = xmlconvert("temp",xmldata or "")
                    xmlstore("temp",xmltable)
                    ctx_xmlsetup("temp",xmlsetup or "")
                else
                    ctx_xmlprocessbuffer("dummy",tag,xmlsetup or "")
                end
            elseif xmlsetup then -- title is reference to node (so \xmlraw should have been used)
                if trace_processors then
                    report_processors("feeding xmlsetup %a using node %a",xmlsetup,title)
                end
                ctx_xmlsetup(title,metadata.xmlsetup)
            else
                local catcodes = metadata.catcodes
                if overload_catcodes == false then
                    if trace_processors then
                        report_processors("catcodetable %a, text %a",catcodes,title)
                    end
                    --
                    -- context.sprint(catcodes,title)
                    --
                    -- doesn't work when a newline is in there \section{Test\ A} so we do
                    -- it this way:
                    --
                    ctx_pushcatcodes(catcodes)
                    context(title)
                    ctx_popcatcodes()
                elseif overload_catcodes == true then
                    if catcodes == notcatcodes or catcodes == xmlcatcodes then
                        -- when was this needed
                        if trace_processors then
                            report_processors("catcodetable %a, overloads %a, text %a",ctxcatcodes,catcodes,title)
                        end
                        context(title)
                    else
                        ctx_pushcatcodes(catcodes)
                        context(title)
                        ctx_popcatcodes()
                    end
                else
                    if trace_processors then
                        report_processors("catcodetable %a, overloads %a, text %a",catcodes,overload_catcodes,title)
                    end
                    ctx_pushcatcodes(overload_catcodes)
                    context(title)
                    ctx_popcatcodes()
                end
            end
        else
            -- no catcode switch, was: texsprint(title)
            context(title)
        end
    end
end

-- -- -- sets -- -- --

local sets = structures.sets

sets.setlist = sets.setlist or { }

storage.register("structures/sets/setlist", structures.sets.setlist, "structures.sets.setlist")

local setlist = sets.setlist

function sets.define(namespace,name,values,default,numbers)
    local dn = setlist[namespace]
    if not dn then
        dn = { }
        setlist[namespace] = dn
    end
    if values == "" then
        dn[name] = { { }, default }
    else
        local split = settings_to_array(values)
        if numbers then
            -- convert to numbers (e.g. for reset)
            for i=1,#split do
                split[i] = tonumber(split[i]) or 0
            end
        end
        dn[name] = { split, default }
    end
end

function sets.getall(namespace,block,name)
    local ds = setlist[namespace]
    if not ds then
        return { }
    else
        local dn
        if block and block ~= "" then
            dn = ds[block..":"..name] or ds[name] or ds[block] or ds.default
        else
            dn = ds[name] or ds.default
        end
        return (dn and dn[1]) or { }
    end
end

-- messy (will be another keyword, fixedconversion) .. needs to be documented too
-- maybe we should cache

local splitter = lpeg.splitat("::")

function sets.get(namespace,block,name,level,default) -- check if name is passed
    --fixed::R:a: ...
    local kind, rest = lpegmatch(splitter,name)
    if rest and kind == "fixed" then -- fixed::n,a,i
        local s = settings_to_array(rest)
        return s[level] or s[#s] or default
    end
    --
    local ds = setlist[namespace]
    if not ds then
        return default
    end
    local dn
    if name and name ~= "" then
        if block and block ~= "" then
            dn = ds[block..":"..name] or ds[name] or ds[block] or ds.default
        else
            dn = ds[name] or ds.default
        end
    else
        if block and block ~= "" then
            dn = ds[block] or ds[block..":default"] or ds.default
        else
            dn = ds.default
        end
    end
    if not dn then
        return default
    end
    local dl = dn[1][level]
    return dl or dn[2] or default
end

-- interface

interfaces.implement {
    name      = "definestructureset",
    actions   = sets.define,
    arguments = { "string", "string", "string", "string", "boolean" }
}
