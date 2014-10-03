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
-- optimize it using the low level epdf accessors. However, not all are accessible (this will
-- be fixed).
--
-- It will be handy when we have a __length and __next that can trigger the resolve till then
-- we will provide .n as #; maybe in Lua 5.3 or later.
--
-- As there can be references to the parent we cannot expand a tree. I played with some
-- expansion variants but it does not pay off; adding extra checks is nto worth the trouble.
--
-- The document stays over. In order to free memory one has to explicitly onload the loaded
-- document.
--
-- We have much more checking then needed in the prepare functions because occasionally
-- we run into bugs in poppler or the epdf interface. It took us a while to realize that
-- there was a long standing gc issue the on long runs with including many pages could
-- crash the analyzer.
--
-- - we cannot access all destinations in one run.
-- - v:getTypeName(), versus types[v:getType()], the last variant is about twice as fast
--
-- A potential speedup is to use local function instead of colon accessors. This will be done
-- in due time. Normally this code is not really speed sensitive but one never knows.

-- __newindex = function(t,k,v)
--     local tk = rawget(t,k)
--     if not tk then
--         local o = epdf.Object()
--         o:initString(v)
--         d:add(k,o)
--     end
--     rawset(t,k,v)
-- end,

local setmetatable, rawset, rawget, type = setmetatable, rawset, rawget, type
local tostring, tonumber = tostring, tonumber
local lower, match, char, utfchar = string.lower, string.match, string.char, utf.char
local concat = table.concat
local toutf = string.toutf

local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local P, C, S, R, Ct, Cc, V = lpeg.P, lpeg.C, lpeg.S, lpeg.R, lpeg.Ct, lpeg.Cc, lpeg.V

local epdf           = epdf
      lpdf           = lpdf or { }
local lpdf           = lpdf
lpdf.epdf            = { }

local report_epdf    = logs.reporter("epdf")

local getDict, getArray, getReal, getNum, getString, getBool, getName, getRef, getRefNum
local getType, getTypeName
local dictGetLength, dictGetVal, dictGetValNF, dictGetKey
local arrayGetLength, arrayGetNF, arrayGet
local streamReset, streamGetDict, streamGetChar

do
    local object     = epdf.Object()
    --
    getDict          = object.getDict
    getArray         = object.getArray
    getReal          = object.getReal
    getNum           = object.getNum
    getString        = object.getString
    getBool          = object.getBool
    getName          = object.getName
    getRef           = object.getRef
    getRefNum        = object.getRefNum
    --
    getType          = object.getType
    getTypeName      = object.getTypeName
    --
    streamReset      = object.streamReset
    streamGetDict    = object.streamGetDict
    streamGetChar    = object.streamGetChar
    --
end

local function initialize_methods(xref)
    local dictionary = epdf.Dict(xref)
    local array      = epdf.Array(xref)
    --
    dictGetLength    = dictionary.getLength
    dictGetVal       = dictionary.getVal
    dictGetValNF     = dictionary.getValNF
    dictGetKey       = dictionary.getKey
    --
    arrayGetLength   = array.getLength
    arrayGetNF       = array.getNF
    arrayGet         = array.get
    --
 -- report_epdf("initializing lpdf.epdf library")
    --
    initialize_methods = function()
        -- already done
    end
end

local typenames      = { [0] =
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

local typenumbers    = table.swapped(typenames)

local null_code      = typenumbers.null
local ref_code       = typenumbers.ref

local function fatal_error(...)
    report_epdf(...)
    report_epdf("aborting job in order to avoid crash")
    os.exit()
end

local limited = false -- a bit of protection

directives.register("system.inputmode", function(v)
    if not limited then
        local i_limiter = io.i_limiter(v)
        if i_limiter then
            epdf.open = i_limiter.protect(epdf.open)
            limited = true
        end
    end
end)

-- epdf is the built-in library

function epdf.type(o)
    local t = lower(match(tostring(o),"[^ :]+"))
    return t or "?"
end

local checked_access

-- dictionaries (can be optimized: ... resolve and redefine when all locals set)

local function prepare(document,d,t,n,k,mt)
    for i=1,n do
        local v = dictGetVal(d,i)
        if v then
            local r = dictGetValNF(d,i)
            local kind = getType(v)
            if kind == null_code then
                -- ignore
            else
                local key = dictGetKey(d,i)
                if kind then
                    if r and getType(r) == ref_code then
                        local objnum = getRefNum(r)
                        local cached = document.__cache__[objnum]
                        if not cached then
                            cached = checked_access[kind](v,document,objnum)
                            if c then
                                document.__cache__[objnum] = cached
                                document.__xrefs__[cached] = objnum
                            end
                        end
                        t[key] = cached
                     -- rawset(t,key,cached)
                    else
                        t[key] = checked_access[kind](v,document)
                     -- rawset(t,key,checked_access[kind](v,document))
                    end
                else
                    report_epdf("warning: nil value for key %a in dictionary",key)
                end
            end
        else
            fatal_error("error: invalid value at index %a in dictionary of %a",i,document.filename)
        end
    end
    setmetatable(t,mt)
    return t[k]
end

local function some_dictionary(d,document,r,mt)
    local n = d and dictGetLength(d) or 0
    if n > 0 then
        local t = { }
        setmetatable(t, {
            __index = function(t,k)
                return prepare(document,d,t,n,k,mt)
            end
        } )
        return t
    end
end

local function get_dictionary(object,document,r,mt)
    local d = getDict(object)
    local n = d and dictGetLength(d) or 0
    if n > 0 then
        local t = { }
        setmetatable(t, {
            __index = function(t,k)
                return prepare(document,d,t,n,k,mt)
            end,
        } )
        return t
    end
end

-- arrays (can be optimized: ... resolve and redefine when all locals set)

local function prepare(document,a,t,n,k)
    for i=1,n do
        local v = arrayGet(a,i)
        if v then
            local kind = getType(v)
            if kind == null_code then
                -- ignore
            elseif kind then
                local r = arrayGetNF(a,i)
                if r and getType(r) == ref_code then
                    local objnum = getRefNum(r)
                    local cached = document.__cache__[objnum]
                    if not cached then
                        cached = checked_access[kind](v,document,objnum)
                        document.__cache__[objnum] = cached
                        document.__xrefs__[cached] = objnum
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
    local n = a and arrayGetLength(a) or 0
    if n > 0 then
        local t = { n = n }
        setmetatable(t, {
            __index = function(t,k)
                return prepare(document,a,t,n,k)
            end
        } )
        return t
    end
end

local function get_array(object,document,r)
    local a = getArray(object)
    local n = a and arrayGetLength(a) or 0
    if n > 0 then
        local t = { n = n }
        setmetatable(t, {
            __index = function(t,k)
                return prepare(document,a,t,n,k)
            end
        } )
        return t
    end
end

local function streamaccess(s,_,what)
    if not what or what == "all" or what == "*all" then
        local t, n = { }, 0
        streamReset(s)
        while true do
            local c = streamGetChar(s)
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

local function get_stream(d,document,r)
    if d then
        streamReset(d)
        local s = some_dictionary(streamGetDict(d),document,r)
        getmetatable(s).__call = function(...) return streamaccess(d,...) end
        return s
    end
end

local function get_string(v)
    return toutf(getString(v))
end

local function get_null()
    return nil
end

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

checked_access[typenumbers.boolean]    = getBool
checked_access[typenumbers.integer]    = getNum
checked_access[typenumbers.real]       = getReal
checked_access[typenumbers.string]     = get_string
checked_access[typenumbers.name]       = getName
checked_access[typenumbers.null]       = get_null
checked_access[typenumbers.array]      = get_array      -- d,document,r
checked_access[typenumbers.dictionary] = get_dictionary -- d,document,r
checked_access[typenumbers.stream]     = get_stream
checked_access[typenumbers.ref]        = getRef

for i=0,#typenames do
    local checker = checked_access[i]
    if not checker then
        checker = function()
            return function(v,document)
                invalidaccess(i,document)
            end
        end
        checked_access[i] = checker
    end
    checked_access[typenames[i]] = checker
end

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
    local __data__  = document.__data__
    local __xrefs__ = document.__xrefs__
    local __cache__ = document.__cache__
    local __xref__  = document.__xref__
    --
    local catalog   = __data__:getCatalog()
    local pages     = { }
    local nofpages  = catalog:getNumPages()
    local metatable = { __index = Catalog.Pages }
    --
    for pagenumber=1,nofpages do
        local pagereference = catalog:getPageRef(pagenumber).num
        local pageobject    = __xref__:fetch(pagereference,0)
        local pagedata      = get_dictionary(pageobject,document,pagereference,metatable)
        if pagedata then
         -- rawset(pagedata,"number",pagenumber)
            pagedata.number          = pagenumber
            pages[pagenumber]        = pagedata
            __xrefs__[pagedata]      = pagereference
            __cache__[pagereference] = pagedata
        else
            report_epdf("missing pagedata at slot %i",i)
        end
    end
    --
    pages.n = nofpages
    --
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
        local __data__ = epdf.open(filename) -- maybe resolvers.find_file
        if __data__ then
            local __xref__ = __data__:getXRef()
            document = {
                filename  = filename,
                __cache__ = { },
                __xrefs__ = { },
                __fonts__ = { },
                __data__  = __data__,
                __xref__  = __xref__,
            }
            --
            initialize_methods(__xref__)
            --
            local Catalog          = some_dictionary(__xref__:getCatalog():getDict(),document)
            local Info             = some_dictionary(__xref__:getDocInfo():getDict(),document)
			--
            document.Catalog       = Catalog
            document.Info          = Info
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

local function expand(t)
    if type(t) == "table" then
        local dummy = t.dummy
    end
    return t
end

-- for k, v in expanded(t) do

local function expanded(t)
    if type(t) == "table" then
        local dummy = t.dummy
    end
    return next, t
end

lpdf.epdf.expand   = expand
lpdf.epdf.expanded = expanded

-- experiment .. will be finished when there is a real need

local hexdigit  = R("09","AF")
local hexword   = hexdigit*hexdigit*hexdigit*hexdigit / function(s) return tonumber(s,16) end
local numchar   = ( P("\\") * ( (R("09")^3/tonumber) + C(1) ) ) + C(1)
local number    = lpegpatterns.number / tonumber
local spaces    = lpegpatterns.whitespace^1
local keyword   = P("/") * C(R("AZ","az","09")^1)
local operator  = C((R("AZ","az")+P("'")+P('"'))^1)

local grammar   = P { "start",
    start      = (keyword + number + V("dictionary") + V("unicode") + V("string") + V("unicode")+ V("array") + spaces)^1,
    array      = P("[")  * Ct(V("start")^1)            * P("]"),
    dictionary = P("<<") * Ct(V("start")^1)            * P(">>"),
    unicode    = P("<")  * Ct(hexword^1)               * P(">"),
    string     = P("(")  * Ct((V("string")+numchar)^1) * P(")"), -- untested
}

local operation = Ct(grammar^1 * operator)
local parser    = Ct((operation + P(1))^1)

-- beginbfrange : <start> <stop> <firstcode>
--                <start> <stop> [ <firstsequence> <firstsequence> <firstsequence> ]
-- beginbfchar  : <code> <newcode>

-- todo: utf16 -> 8
-- we could make range more efficient but it's seldom seen anyway

local optionals   = spaces^0
local whatever    = optionals * P("<") * hexword       * P(">")
local hexstring   = optionals * P("<") * C(hexdigit^1) * P(">")
local bfchar      = Cc(1) * whatever * whatever
local bfrange     = Cc(2) * whatever * whatever * whatever
                  + Cc(3) * whatever * whatever * optionals * P("[") * hexstring^1 * optionals * P("]")
local fromunicode = Ct ( (
    P("beginbfchar" ) * Ct(bfchar )^1 * optionals * P("endbfchar" ) +
    P("beginbfrange") * Ct(bfrange)^1 * optionals * P("endbfrange") +
    spaces +
    P(1)
)^1 )

local utf16_to_utf8_be = utf.utf16_to_utf8_be
local utfchar           = utfchar

local function analyzefonts(document,resources) -- unfinished
    local fonts = document.__fonts__
    if resources then
        local fontlist = resources.Font
        if fontlist then
            for id, data in expanded(fontlist) do
                if not fonts[id] then
                    --  a quck hack ... I will look into it more detail if I find a real
                    -- -application for it
                    local tounicode = data.ToUnicode()
                    if tounicode then
                        tounicode = lpegmatch(fromunicode,tounicode)
                    end
                    if type(tounicode) == "table" then
                        local t = { }
                        for i=1,#tounicode do
                            local u = tounicode[i]
                            local w = u[1]
                            if w == 1 then
                                t[u[2]] = utfchar(u[3])
                            elseif w == 2 then
                                local m = u[4]
                                for i=u[2],u[3] do
                                    t[i] = utfchar(m)
                                    m = m + 1
                                end
                            elseif w == 3 then
                                local m = 4
                                for i=u[2],u[3] do
                                    t[i] = utf16_to_utf8_be(u[m])
                                    m = m + 1
                                end
                            end
                        end
                        fonts[id] = {
                            tounicode = t
                        }
                    else
                        fonts[id] = {
                            tounicode = { }
                        }
                    end
                end
            end
        end
    end
    return fonts
end

function lpdf.epdf.getpagecontent(document,pagenumber)

    local page = document.pages[pagenumber]

    if not page then
        return
    end

    local fonts   = analyzefonts(document,page.Resources)

    local content = page.Contents() or ""
    local list    = lpegmatch(parser,content)
    local font    = nil
    local unic    = nil

    for i=1,#list do
        local entry    = list[i]
        local size     = #entry
        local operator = entry[size]
        if operator == "Tf" then
            font = fonts[entry[1]]
            unic = font.tounicode
        elseif operator == "TJ" then -- { array,  TJ }
            local list = entry[1]
            for i=1,#list do
                local li = list[i]
                if type(li) == "table" then
                    for i=1,#li do
                        local c = li[i]
                        local u = unic[c]
                        li[i] = u or utfchar(c)
                    end
                    list[i] = concat(li)
                end
            end
        elseif operator == "Tj" or operator == "'" or operator == '"' then -- { string,  Tj } { string, ' } { n, m, string, " }
            local li = entry[size-1]
            for i=1,#li do
                local c = li[i]
                local u = unic[c]
                li[i] = utfchar(u or c)
            end
            entry[1] = concat(li)
        end
    end

 -- for i=1,#list do
 --     local entry    = list[i]
 --     local size     = #entry
 --     local operator = entry[size]
 --     if operator == "TJ" then -- { array,  TJ }
 --         local list = entry[1]
 --         for i=1,#list do
 --             local li = list[i]
 --             if type(li) == "string" then
 --                 --
 --             elseif li < -50 then
 --                 list[i] = " "
 --             else
 --                 list[i] = ""
 --             end
 --         end
 --         entry[1] = concat(list)
 --     elseif operator == "Tf" then
 --         -- already concat
 --     elseif operator == "cm" then
 --         local e = entry[1]
 --         local sx, rx, ry, sy, tx, ty = e[1], e[2], e[3], e[4], e[5], e[6]
 --         -- if dy ... newline
 --     end
 -- end

    return list

end

-- document.Catalog.StructTreeRoot.ParentTree.Nums[2][1].A.P[1])

-- helpers

-- function lpdf.epdf.getdestinationpage(document,name)
--     local destination = document.__data__:findDest(name)
--     return destination and destination.number
-- end
