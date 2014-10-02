if not modules then modules = { } end modules ['lpdf-epd'] = {
    version   = 1.001,
    comment   = "companion to lpdf-epa.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is an experimental layer around the epdf library. The reason for this layer is that
-- I want to be independent of the library (which implements a selection of what a file
-- provides) and also because I want an interface closer to Lua's table model while the API
-- stays close to the original xpdf library. Of course, after prototyping a solution, we can
-- optimize it using the low level epdf accessors.

-- It will be handy when we have a __length and __next that can trigger the resolve till then
-- we will provide .n as #.

-- As there can be references to the parent we cannot expand a tree. I played with some
-- expansion variants but it does to pay off.

-- Maybe we need a close(). In fact, nilling the document root will result in a gc at some
-- point.

-- We cannot access all destinations in one run.

-- We have much more checking then needed in the prepare functions because occasionally
-- we run into bugs in poppler or the epdf interface. It took us a while to realize that
-- there was a long standing gc issue the on long runs with including many pages could
-- crash the analyzer.

local setmetatable, rawset, rawget, tostring, tonumber = setmetatable, rawset, rawget, tostring, tonumber
local lower, match, char, find, sub = string.lower, string.match, string.char, string.find, string.sub
local concat = table.concat
local toutf = string.toutf

local report_epdf = logs.reporter("epdf")

-- v:getTypeName(), versus types[v:getType()], the last variant is about twice as fast

local typenames = { [0] =
  "boolean",
  "integer",
  "real",
  "string",
  "name",
  "null",
  "array",
  "dictionary",
  "stream",
  "ref",
  "cmd",
  "error",
  "eof",
  "none",
  "integer64",
}

local typenumbers = table.swapped(typenames)

local null_code = typenumbers.null
local ref_code  = typenumbers.ref

local function fatal_error(...)
    report_epdf(...)
    -- we exit as we will crash anyway
    report_epdf("aborting job in order to avoid crash")
    os.exit()
end

local limited = false -- abit of protection

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

-- dictionaries

-- local function prepare(document,d,t,n,k,mt)
--     for i=1,n do
--         local v = d:getVal(i)
--         local r = d:getValNF(i)
--         local key = d:getKey(i)
--         if r and r:getTypeName() == "ref" then
--             r = r:getRef().num
--             local c = document.cache[r]
--             if c then
--                 --
--             else
--                 c = checked_access[v:getTypeName()](v,document,r)
--                 if c then
--                     document.cache[r] = c
--                     document.xrefs[c] = r
--                 end
--             end
--             t[key] = c
--         elseif v then
--             t[key] = checked_access[v:getTypeName()](v,document)
--         else
--             fatal_error("fatal error: no data for key %s in dictionary",key)
--         end
--     end
--     getmetatable(t).__index = nil -- ?? weird
--     setmetatable(t,mt)
--     return t[k]
-- end

local function prepare(document,d,t,n,k,mt)
--     print("start prepare dict, requesting key ",k,"out of",n)
    for i=1,n do
        local v = d:getVal(i)
        if v then
            local r = d:getValNF(i)
            local kind = v:getType()
--             print("checking",i,d:getKey(i),v:getTypeName())
            if kind == null_code then
             -- report_epdf("warning: null value for key %a in dictionary",key)
            else
                local key = d:getKey(i)
                if kind then
                    if r and r:getType() == ref_code then
                        local objnum = r:getRef().num
                        local cached = document.cache[objnum]
                        if not cached then
                            cached = checked_access[kind](v,document,objnum)
                            if c then
                                document.cache[objnum] = cached
                                document.xrefs[cached] = objnum
                            end
                        end
                        t[key] = cached
                    else
                        t[key] = checked_access[kind](v,document)
                    end
                else
                    report_epdf("warning: nil value for key %a in dictionary",key)
                end
            end
        else
            fatal_error("error: invalid value at index %a in dictionary of %a",i,document.filename)
        end
    end
--     print("done")
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

-- arrays

local done = { }

-- local function prepare(document,a,t,n,k)
--     for i=1,n do
--         local v = a:get(i)
--         local r = a:getNF(i)
--         local kind = v:getTypeName()
--         if kind == "null" then
--             -- TH: weird, but appears possible
--         elseif r:getTypeName() == "ref" then
--             r = r:getRef().num
--             local c = document.cache[r]
--             if c then
--                 --
--             else
--                 c = checked_access[kind](v,document,r)
--                 document.cache[r] = c
--                 document.xrefs[c] = r
--             end
--             t[i] = c
--         else
--             t[i] = checked_access[kind](v,document)
--         end
--     end
--     getmetatable(t).__index = nil
--     return t[k]
-- end

local function prepare(document,a,t,n,k)
    for i=1,n do
        local v = a:get(i)
        if v then
            local kind = v:getType()
            if kind == null_code then
             -- report_epdf("warning: null value for index %a in array",i)
            elseif kind then
                local r = a:getNF(i)
                if r and r:getType() == ref_code then
                    local objnum = r:getRef().num
                    local cached = document.cache[objnum]
                    if not cached then
                        cached = checked_access[kind](v,document,objnum)
                        document.cache[objnum] = cached
                        document.xrefs[cached] = objnum
                    end
                    t[i] = cached
                else
                    t[i] = checked_access[kind](v,document)
                end
            else
                report_epdf("warning: nil value for index %a in array",i)
            end
        else
            fatal_error("error: invalid value at index %a in array of %a",i,document.filename)
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

-- checked_access = {
--     dictionary = function(d,document,r)
--         return some_dictionary(d:getDict(),document,r)
--     end,
--     array = function(a,document,r)
--         return some_array(a:getArray(),document,r)
--     end,
--     stream = function(v,document,r)
--         return some_stream(v,document,r)
--     end,
--     real = function(v)
--         return v:getReal()
--     end,
--     integer = function(v)
--         return v:getNum()
--     end,
--  -- integer64 = function(v)
--  --     return v:getNum()
--  -- end,
--     string = function(v)
--         return toutf(v:getString())
--     end,
--     boolean = function(v)
--         return v:getBool()
--     end,
--     name = function(v)
--         return v:getName()
--     end,
--     ref = function(v)
--         return v:getRef()
--     end,
--     null = function()
--         return nil
--     end,
--     none = function()
--         -- why not null
--         return nil
--     end,
--  -- error = function()
--  --     -- shouldn't happen
--  --     return nil
--  -- end,
--  -- eof = function()
--  --     -- we don't care
--  --     return nil
--  -- end,
--  -- cmd = function()
--  --     -- shouldn't happen
--  --     return nil
--  -- end
-- }

-- a bit of a speedup in case we want to play with large pdf's and have millions
-- of access .. it might not be worth the trouble

-- we have dual access: by typenumber and by typename

local function invalidaccess(k,document)
    local fullname = type(document) == "table" and document.fullname
    if fullname then
        fatal_error("error, asking for key %a in checker of %a",k,fullname)
    else
        fatal_error("error, asking for key %a in checker",k)
    end
end

checked_access = table.setmetatableindex(function(t,k)
    return function(v,document)
        invalidaccess(k,document)
    end
end)

for i=0,#typenames do
    checked_access[i] = function()
        return function(v,document)
            invalidaccess(i,document)
        end
    end
end

checked_access[typenumbers.dictionary] = function(d,document,r)
    local getDict = d.getDict
    local getter  = function(d,document,r)
        return some_dictionary(getDict(d),document,r)
    end
    checked_access.dictionary              = getter
    checked_access[typenumbers.dictionary] = getter
    return getter(d,document,r)
end

checked_access[typenumbers.array] = function(a,document,r)
    local getArray = a.getArray
    local getter = function(a,document,r)
        return some_array(getArray(a),document,r)
    end
    checked_access.array              = getter
    checked_access[typenumbers.array] = getter
    return getter(a,document,r)
end

checked_access[typenumbers.stream] = function(v,document,r)
    return some_stream(v,document,r) -- or just an equivalent
end

checked_access[typenumbers.real] = function(v)
    local getReal = v.getReal
    checked_access.real              = getReal
    checked_access[typenumbers.real] = getReal
    return getReal(v)
end

checked_access[typenumbers.integer] = function(v)
    local getNum = v.getNum
    checked_access.integer              = getNum
    checked_access[typenumbers.integer] = getNum
    return getNum(v)
end

checked_access[typenumbers.string] = function(v)
    local getString = v.getString
    local function getter(v)
        return toutf(getString(v))
    end
    checked_access.string              = getter
    checked_access[typenumbers.string] = getter
    return toutf(getString(v))
end

checked_access[typenumbers.boolean] = function(v)
    local getBool = v.getBool
    checked_access.boolean              = getBool
    checked_access[typenumbers.boolean] = getBool
    return getBool(v)
end

checked_access[typenumbers.name] = function(v)
    local getName = v.getName
    checked_access.name              = getName
    checked_access[typenumbers.name] = getName
    return getName(v)
end

checked_access[typenumbers.ref] = function(v)
    local getRef = v.getRef
    checked_access.ref              = getRef
    checked_access[typenumbers.ref] = getRef
    return getRef(v)
end

checked_access[typenumbers.null] = function()
    return nil
end

checked_access[typenumbers.none] = function()
    -- is actually an error
    return nil
end

for i=0,#typenames do
    checked_access[typenames[i]] = checked_access[i]
end

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
         -- table.setmetatablenewindex(document.cache,function(t,k,v)
         --     if rawget(t,k) then
         --         report_epdf("updating object %a in cache",k)
         --     else
         --         report_epdf("storing object %a in cache",k)
         --     end
         --     rawset(t,k,v)
         -- end)
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
        loaded[document] = document
        statistics.stoptiming(lpdf.epdf)
     -- print(statistics.elapsedtime(lpdf.epdf))
    end
    return document or nil
end

function lpdf.epdf.unload(filename)
    local document = loaded[filename]
    if document then
        loaded[document] = nil
        loaded[filename] = nil
    end
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
