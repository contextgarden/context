if not modules then modules = { } end modules ['lpdf-epd'] = {
    version   = 1.001,
    comment   = "companion to lpdf-epa.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is an experimental layer around the epdf library. The reason for
-- this layer is that I want to be independent of the library (which
-- implements a selection of what a file provides) and also because I
-- want an interface closer to Lua's table model while the API stays
-- close to the original xpdf library. Of course, after prototyping a
-- solution, we can optimize it using the low level epdf accessors.

-- It will be handy when we have a __length and __next that can trigger
-- the resolve till then we will provide .n as #.

-- As there can be references to the parent we cannot expand a tree. I
-- played with some expansion variants but it does to pay off.

-- Maybe we need a close().
-- We cannot access all destinations in one run.

local setmetatable, rawset, rawget, tostring, tonumber = setmetatable, rawset, rawget, tostring, tonumber
local lower, match, char, find, sub = string.lower, string.match, string.char, string.find, string.sub
local concat = table.concat
local toutf = string.toutf

local report_epdf = logs.reporter("epdf")

-- a bit of protection

local limited = false

directives.register("system.inputmode", function(v)
    if not limited then
        local i_limiter = io.i_limiter(v)
        if i_limiter then
            epdf.open = i_limiter.protect(epdf.open)
            limited = true
        end
    end
end)

--

function epdf.type(o)
    local t = lower(match(tostring(o),"[^ :]+"))
    return t or "?"
end

lpdf = lpdf or { }
local lpdf = lpdf

lpdf.epdf  = { }

local checked_access

local function prepare(document,d,t,n,k,mt)
    for i=1,n do
        local v = d:getVal(i)
        local r = d:getValNF(i)
        if r:getTypeName() == "ref" then
            r = r:getRef().num
            local c = document.cache[r]
            if c then
                --
            else
                c = checked_access[v:getTypeName()](v,document,r)
                if c then
                    document.cache[r] = c
                    document.xrefs[c] = r
                end
            end
            t[d:getKey(i)] = c
        else
            t[d:getKey(i)] = checked_access[v:getTypeName()](v,document)
        end
    end
    getmetatable(t).__index = nil -- ?? weird
setmetatable(t,mt)
    return t[k]
end

local function some_dictionary(d,document,r,mt)
    local n = d and d:getLength() or 0
    if n > 0 then
        local t = { }
        setmetatable(t, { __index = function(t,k) return prepare(document,d,t,n,k,mt) end } )
        return t
    end
end

local done = { }

local function prepare(document,a,t,n,k)
    for i=1,n do
        local v = a:get(i)
        local r = a:getNF(i)
        if v:getTypeName() == "null" then
            -- TH: weird, but appears possible
        elseif r:getTypeName() == "ref" then
            r = r:getRef().num
            local c = document.cache[r]
            if c then
                --
            else
                c = checked_access[v:getTypeName()](v,document,r)
                document.cache[r] = c
                document.xrefs[c] = r
            end
            t[i] = c
        else
            t[i] = checked_access[v:getTypeName()](v,document)
        end
    end
    getmetatable(t).__index = nil
    return t[k]
end

local function some_array(a,document,r)
    local n = a and a:getLength() or 0
    if n > 0 then
        local t = { n = n }
        setmetatable(t, { __index = function(t,k) return prepare(document,a,t,n,k) end } )
        return t
    end
end

local function streamaccess(s,_,what)
    if not what or what == "all" or what == "*all" then
        local t, n = { }, 0
        s:streamReset()
        while true do
            local c = s:streamGetChar()
            if c < 0 then
                break
            else
                n = n + 1
                t[n] = char(c)
            end
        end
        return concat(t)
    end
end

local function some_stream(d,document,r)
    if d then
        d:streamReset()
        local s = some_dictionary(d:streamGetDict(),document,r)
        getmetatable(s).__call = function(...) return streamaccess(d,...) end
        return s
    end
end

-- we need epdf.boolean(v) in addition to v:getBool() [dictionary, array, stream, real, integer, string, boolean, name, ref, null]

checked_access = {
    dictionary = function(d,document,r)
        return some_dictionary(d:getDict(),document,r)
    end,
    array = function(a,document,r)
        return some_array(a:getArray(),document,r)
    end,
    stream = function(v,document,r)
        return some_stream(v,document,r)
    end,
    real = function(v)
        return v:getReal()
    end,
    integer = function(v)
        return v:getNum()
    end,
    string = function(v)
        return toutf(v:getString())
    end,
    boolean = function(v)
        return v:getBool()
    end,
    name = function(v)
        return v:getName()
    end,
    ref = function(v)
        return v:getRef()
    end,
    null = function()
        return nil
    end,
}

-- checked_access.real    = epdf.real
-- checked_access.integer = epdf.integer
-- checked_access.string  = epdf.string
-- checked_access.boolean = epdf.boolean
-- checked_access.name    = epdf.name
-- checked_access.ref     = epdf.ref

local function getnames(document,n,target) -- direct
    if n then
        local Names = n.Names
        if Names then
            if not target then
                target = { }
            end
            for i=1,Names.n,2 do
                target[Names[i]] = Names[i+1]
            end
        else
            local Kids = n.Kids
            if Kids then
                for i=1,Kids.n do
                    target = getnames(document,Kids[i],target)
                end
            end
        end
        return target
    end
end

local function getkids(document,n,target) -- direct
    if n then
        local Kids = n.Kids
        if Kids then
            for i=1,Kids.n do
                target = getkids(document,Kids[i],target)
            end
        elseif target then
            target[#target+1] = n
        else
            target = { n }
        end
        return target
    end
end

-- /OCProperties <<
--     /OCGs [ 15 0 R 17 0 R 19 0 R 21 0 R 23 0 R 25 0 R 27 0 R ]
--     /D <<
--         /Order [ 15 0 R 17 0 R 19 0 R 21 0 R 23 0 R 25 0 R 27 0 R ]
--         /ON    [ 15 0 R 17 0 R 19 0 R 21 0 R 23 0 R 25 0 R 27 0 R ]
--         /OFF   [ ]
--     >>
-- >>

local function getlayers(document)
    local properties = document.Catalog.OCProperties
    if properties then
        local layers = properties.OCGs
        if layers then
            local t = { }
            local n = layers.n
            for i=1,n do
                local layer = layers[i]
             -- print(document.xrefs[layer])
                t[i] = layer.Name
            end
            t.n = n
            return t
        end
    end
end

local function getstructure(document)
    -- this might become a tree
    return document.Catalog.StructTreeRoot
end

local function getpages(document,Catalog)
    local data  = document.data
    local xrefs = document.xrefs
    local cache = document.cache
    local cata  = data:getCatalog()
    local xref  = data:getXRef()
    local pages = { }
    local nofpages = cata:getNumPages()
--     local function getpagestuff(pagenumber,k)
--         if k == "MediaBox" then
--             local pageobj = cata:getPage(pagenumber)
--             local pagebox = pageobj:getMediaBox()
--             return { pagebox.x1, pagebox.y1, pagebox.x2, pagebox.y2 }
--         elseif k == "CropBox" then
--             local pageobj = cata:getPage(pagenumber)
--             local pagebox = pageobj:getMediaBox()
--             return { pagebox.x1, pagebox.y1, pagebox.x2, pagebox.y2 }
--         elseif k == "Resources" then
--             print("todo page resources from parent")
--          -- local pageobj = cata:getPage(pagenumber)
--          -- local resources = pageobj:getResources()
--         end
--     end
--     for pagenumber=1,nofpages do
--         local mt = { __index = function(t,k)
--             local v = getpagestuff(pagenumber,k)
--             if v then
--                 t[k] = v
--             end
--             return v
--         end }
    local mt = { __index = Catalog.Pages }
    for pagenumber=1,nofpages do
        local pagereference = cata:getPageRef(pagenumber).num
        local pagedata = some_dictionary(xref:fetch(pagereference,0):getDict(),document,pagereference,mt)
        if pagedata then
            pagedata.number = pagenumber
            pages[pagenumber] = pagedata
            xrefs[pagedata] = pagereference
            cache[pagereference] = pagedata
        else
            report_epdf("missing pagedata at slot %i",i)
        end
    end
    pages.n = nofpages
    return pages
end

-- loader

local function delayed(document,tag,f)
    local t = { }
    setmetatable(t, { __index = function(t,k)
        local result = f()
        if result then
            document[tag] = result
            return result[k]
        end
    end } )
    return t
end

-- local catobj = data:getXRef():fetch(data:getXRef():getRootNum(),data:getXRef():getRootGen())
-- print(catobj:getDict(),data:getXRef():getCatalog():getDict())

local loaded = { }

function lpdf.epdf.load(filename)
    local document = loaded[filename]
    if not document then
        statistics.starttiming(lpdf.epdf)
        local data = epdf.open(filename) -- maybe resolvers.find_file
        if data then
            document = {
                filename = filename,
                cache    = { },
                xrefs    = { },
                data     = data,
            }
            local Catalog    = some_dictionary(data:getXRef():getCatalog():getDict(),document)
            local Info       = some_dictionary(data:getXRef():getDocInfo():getDict(),document)
            document.Catalog = Catalog
            document.Info    = Info
         -- document.catalog = Catalog
            -- a few handy helper tables
            document.pages         = delayed(document,"pages",        function() return getpages(document,Catalog) end)
            document.destinations  = delayed(document,"destinations", function() return getnames(document,Catalog.Names and Catalog.Names.Dests) end)
            document.javascripts   = delayed(document,"javascripts",  function() return getnames(document,Catalog.Names and Catalog.Names.JS) end)
            document.widgets       = delayed(document,"widgets",      function() return getnames(document,Catalog.Names and Catalog.Names.AcroForm) end)
            document.embeddedfiles = delayed(document,"embeddedfiles",function() return getnames(document,Catalog.Names and Catalog.Names.EmbeddedFiles) end)
            document.layers        = delayed(document,"layers",       function() return getlayers(document) end)
            document.structure     = delayed(document,"structure",    function() return getstructure(document) end)
        else
            document = false
        end
        loaded[filename] = document
        statistics.stoptiming(lpdf.epdf)
     -- print(statistics.elapsedtime(lpdf.epdf))
    end
    return document
end

-- for k, v in next, expand(t) do

function lpdf.epdf.expand(t)
    if type(t) == "table" then
        local dummy = t.dummy
    end
    return t
end

-- helpers

-- function lpdf.epdf.getdestinationpage(document,name)
--     local destination = document.data:findDest(name)
--     return destination and destination.number
-- end
