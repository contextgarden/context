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
-- expansion variants but it does not pay off; adding extra checks is not worth the trouble.
--
-- The document stays open. In order to free memory one has to explicitly unload the loaded
-- document.
--
-- We have much more checking then needed in the prepare functions because occasionally
-- we run into bugs in poppler or the epdf interface. It took us a while to realize that
-- there was a long standing gc issue the on long runs with including many pages could
-- crash the analyzer.
--
-- Normally a value is fetched by key, as in foo.Title but as it can be in pdfdoc encoding
-- a safer bet is foo("Title") which will return a decoded string (or the original if it
-- already was unicode).

local setmetatable, rawset, rawget, type, next = setmetatable, rawset, rawget, type, next
local tostring, tonumber, unpack = tostring, tonumber, unpack
local lower, match, char, byte, find = string.lower, string.match, string.char, string.byte, string.find
local abs = math.abs
local concat = table.concat
local toutf, toeight, utfchar = string.toutf, utf.toeight, utf.char
local setmetatableindex = table.setmetatableindex

local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local P, C, S, R, Ct, Cc, V, Carg, Cs, Cf, Cg = lpeg.P, lpeg.C, lpeg.S, lpeg.R, lpeg.Ct, lpeg.Cc, lpeg.V, lpeg.Carg, lpeg.Cs, lpeg.Cf, lpeg.Cg

local epdf      = epdf
      lpdf      = lpdf or { }
local lpdf      = lpdf
local lpdf_epdf = { }
lpdf.epdf       = lpdf_epdf

-- local getDict, getArray, getReal, getNum, getString, getBool, getName, getRef, getRefNum
-- local getType, getTypeName
-- local dictGetLength, dictGetVal, dictGetValNF, dictGetKey
-- local arrayGetLength, arrayGetNF, arrayGet
-- local streamReset, streamGetDict, streamGetChar

-- We use as little as possible and also not an object interface. After all, we
-- don't know how the library (and its api) evolves so we better can be prepared
-- for wrappers.

local registry         = debug.getregistry()

local object           = registry["epdf.Object"]
local dictionary       = registry["epdf.Dict"]
local array            = registry["epdf.Array"]
local xref             = registry["epdf.XRef"]
local catalog          = registry["epdf.Catalog"]
local pdfdoc           = registry["epdf.PDFDoc"]

if not (object and dictionary and array and xref and catalog and pdfdoc) then
    logs.report("fatal error","invalid pdf inclusion library (%s)",1)
    os.exit()
end

local openPDF          = epdf.open

local getMajorVersion  = pdfdoc.getPDFMajorVersion
local getMinorVersion  = pdfdoc.getPDFMinorVersion
local getXRef          = pdfdoc.getXRef
local getRawCatalog    = pdfdoc.getCatalog

if not (openPDF and getMajorVersion and getMinorVersion and getXRef and getRawCatalog) then
    logs.report("fatal error","invalid pdf inclusion library (%s)",2)
    os.exit()
end

local getDict          = object.getDict
local getArray         = object.getArray
local getReal          = object.getReal
local getInt           = object.getInt
local getString        = object.getString
local getBool          = object.getBool
local getName          = object.getName
local getRef           = object.getRef
local getRefNum        = object.getRefNum

local getType          = object.getType

if not (getDict and getArray and getReal and getInt and getString and getBool and getName and getRef and getRefNum and getType) then
    logs.report("fatal error","invalid pdf inclusion library (%s)",3)
    os.exit()
end

local streamReset      = object.streamReset
local streamGetDict    = object.streamGetDict
local streamGetChar    = object.streamGetChar
local streamGetAll     = object.streamGetAll

if not (streamReset and streamGetDict and streamGetChar) then
    logs.report("fatal error","invalid pdf inclusion library (%s)",3)
    os.exit()
end

local dictGetLength    = dictionary.getLength
local dictGetVal       = dictionary.getVal
local dictGetValNF     = dictionary.getValNF
local dictGetKey       = dictionary.getKey

if not (dictGetLength and dictGetVal and dictGetValNF and dictGetKey) then
    logs.report("fatal error","invalid pdf inclusion library (%s)",4)
    os.exit()
end

local arrayGetLength   = array.getLength
local arrayGetNF       = array.getNF
local arrayGet         = array.get

if not (arrayGetLength and arrayGetNF and arrayGet) then
    logs.report("fatal error","invalid pdf inclusion library (%s)",5)
    os.exit()
end

-- these are kind of weird as they can't be accessed by (root) object

local getNumPages      = catalog.getNumPages
local getPageRef       = catalog.getPageRef

local fetch            = xref.fetch
local getCatalog       = xref.getCatalog
local getDocInfo       = xref.getDocInfo

if not (getNumPages and getPageRef and fetch and getCatalog and getDocInfo) then
    logs.report("fatal error","invalid pdf inclusion library (%s)",6)
    os.exit()
end

-- we're done with library shortcuts

local report_epdf      = logs.reporter("epdf")

local typenames        = { [0] =
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

-- epdf is the built-in library

function epdf.type(o)
    local t = lower(match(tostring(o),"[^ :]+"))
    return t or "?"
end

local checked_access

-- dictionaries (can be optimized: ... resolve and redefine when all locals set)

local frompdfdoc = lpdf.frompdfdoc

local get_flagged

if lpdf.dictionary then

    local pdfdictionary = lpdf.dictionary
    local pdfarray      = lpdf.array
    local pdfconstant   = lpdf.constant
    local pdfstring     = lpdf.string
    local pdfunicode    = lpdf.unicode

    get_flagged = function(t,f,k)
        local tk = t[k] -- triggers resolve
        local fk = f[k]
        if not fk then
            return tk
        elseif fk == "name" then
            return pdfconstant(tk)
        elseif fk == "array" then
            return pdfarray(tk)
        elseif fk == "dictionary" then
            return pdfarray(tk)
        elseif fk == "rawtext" then
            return pdfstring(tk)
        elseif fk == "unicode" then
            return pdfunicode(tk)
        else
            return tk
        end
    end

else

    get_flagged = function(t,f,k)
        local tk = t[k] -- triggers resolve
        local fk = f[k]
        if not fk then
            return tk
        elseif fk == "rawtext" then
            return frompdfdoc(tk)
        else
            return tk
        end
    end

end

local function prepare(document,d,t,n,k,mt,flags)
    for i=1,n do
        local v = dictGetVal(d,i)
        if v then
            local r = dictGetValNF(d,i)
            local kind = getType(v)
            if kind == null_code then
                -- ignore
            elseif kind then
                local key = dictGetKey(d,i)
                if r and getType(r) == ref_code then
                    local objnum = getRefNum(r)
                    local cached = document.__cache__[objnum]
                    if not cached then
                        cached = checked_access[kind](v,document,objnum,mt)
                        if cached then
                            document.__cache__[objnum] = cached
                            document.__xrefs__[cached] = objnum
                        end
                    end
                    t[key] = cached
                else
                    local v, flag = checked_access[kind](v,document)
                    t[key] = v
                    if flag and flags then
                        flags[key] = flag -- flags
                    end
                end
            else
                report_epdf("warning: nil value for key %a in dictionary",key)
            end
        else
            fatal_error("error: invalid value at index %a in dictionary of %a",i,document.filename)
        end
    end
    if mt then
        setmetatable(t,mt)
    else
        getmetatable(t).__index = nil
    end
    return t[k]
end

--     local function prepare(document,d,t,n,k,mt,flags)
--         for i=1,n do
--             local v = dictGetValNF(d,i)
--             if v then
--                 local key  = dictGetKey(d,i)
--                 local kind = getType(v)
--                 if kind == ref_code then
--                     local objnum = getRefNum(v)
--                     local cached = document.__cache__[objnum]
--                     if not cached then
--                         local v = dictGetVal(d,i)
--                         local kind = getType(v)
--                         cached = checked_access[kind](v,document,objnum,mt)
--                         if cached then
--                             document.__cache__[objnum] = cached
--                             document.__xrefs__[cached] = objnum
--                         end
--                     end
--                     t[key] = cached
--                 else
--                     local v, flag = checked_access[kind](v,document)
--                     t[key] = v
--                     if flag and flags then
--                         flags[key] = flag -- flags
--                     end
--                 end
--             end
--         end
--         if mt then
--             setmetatable(t,mt)
--         else
--             getmetatable(t).__index = nil
--         end
--         return t[k]
--     end

local function some_dictionary(d,document)
    local n = d and dictGetLength(d) or 0
    if n > 0 then
        local t = { }
        local f = { }
        setmetatable(t, {
            __index = function(t,k)
                return prepare(document,d,t,n,k,_,_,f)
            end,
            __call = function(t,k)
                return get_flagged(t,f,k)
            end,
         -- __kind = function(k)
         --     return f[k] or type(t[k])
         -- end,
        } )
        return t, "dictionary"
    end
end

local function get_dictionary(object,document,r,mt)
    local d = getDict(object)
    local n = d and dictGetLength(d) or 0
    if n > 0 then
        local t = { }
        local f = { }
        setmetatable(t, {
            __index = function(t,k)
                return prepare(document,d,t,n,k,mt,f)
            end,
            __call = function(t,k)
                return get_flagged(t,f,k)
            end,
         -- __kind = function(k)
         --     return f[k] or type(t[k])
         -- end,
        } )
        return t, "dictionary"
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
    local m = getmetatable(t)
    if m then
        m.__index = nil
        m.__len   = nil
    end
    if k then
        return t[k]
    end
end

--     local function prepare(document,a,t,n,k)
--         for i=1,n do
--             local v = arrayGetNF(a,i)
--             if v then
--                 local kind = getType(v)
--                 if kind == ref_code then
--                     local objnum = getRefNum(v)
--                     local cached = document.__cache__[objnum]
--                     if not cached then
--                         local v = arrayGet(a,i)
--                         local kind = getType(v)
--                         cached = checked_access[kind](v,document,objnum)
--                         document.__cache__[objnum] = cached
--                         document.__xrefs__[cached] = objnum
--                     end
--                     t[i] = cached
--                 else
--                     t[i] = checked_access[kind](v,document)
--                 end
--             end
--         end
--         local m = getmetatable(t)
--         if m then
--             m.__index = nil
--             m.__len   = nil
--         end
--         if k then
--             return t[k]
--         end
--     end

local function some_array(a,document)
    local n = a and arrayGetLength(a) or 0
    if n > 0 then
        local t = { n = n }
        setmetatable(t, {
            __index = function(t,k)
                return prepare(document,a,t,n,k,_,_,f)
            end,
            __len = function(t)
                prepare(document,a,t,n,_,_,f)
                return n
            end,
            __call = function(t,k)
                return get_flagged(t,f,k)
            end,
         -- __kind = function(k)
         --     return f[k] or type(t[k])
         -- end,
        } )
        return t, "array"
    end
end

local function get_array(object,document)
    local a = getArray(object)
    local n = a and arrayGetLength(a) or 0
    if n > 0 then
        local t = { n = n }
        local f = { }
        setmetatable(t, {
            __index = function(t,k)
                return prepare(document,a,t,n,k,_,_,f)
            end,
            __len = function(t)
                prepare(document,a,t,n,_,_,f)
                return n
            end,
            __call = function(t,k)
                return get_flagged(t,f,k)
            end,
         -- __kind = function(k)
         --     return f[k] or type(t[k])
         -- end,
        } )
        return t, "array"
    end
end

-- todo: collect chunks

-- local function streamaccess(s,_,what)
--     if not what or what == "all" or what == "*all" then
--         local t, n = { }, 0
--         streamReset(s)
--         while true do
--             local c = streamGetChar(s)
--             if c < 0 then
--                 break
--             else
--                 n = n + 1
--                 t[n] = char(c)
--             end
--         end
--         return concat(t,"",1,n)
--     end
-- end

local function getstream(s)
    streamReset(s)
    if streamGetAll then
        return streamGetAll(s)
    else
        local t, b, n = { }, { }, 0
        while true do
            local c = streamGetChar(s)
            if c < 0 then
                break
            else
                n = n + 1
                b[n] = c
            end
            if n == 2000 then
                t[#t+1] = char(unpack(b,1,n))
                n = 1
            end
        end
        t[#t+1] = char(unpack(b,1,n))
        return concat(t)
    end
end

local function streamaccess(s,_,what)
    if not what or what == "all" or what == "*all" then
        return getstream(s)
    end
end

local function get_stream(d,document)
    if d then
        streamReset(d)
        local s = some_dictionary(streamGetDict(d),document)
        getmetatable(s).__call = function(...) return streamaccess(d,...) end
        return s
    end
end

-- We need to convert the string from utf16 although there is no way to
-- check if we have a regular string starting with a bom. So, we have
-- na dilemma here: a pdf doc encoded string can be invalid utf.

-- <hex encoded>   : implicit 0 appended if odd
-- (byte encoded)  : \( \) \\ escaped
--
-- <FE><FF> : utf16be
--
-- \r \r \t \b \f \( \) \\ \NNN and \<newline> : append next line
--
-- the getString function gives back bytes so we don't need to worry about
-- the hex aspect.

local u_pattern = lpeg.patterns.utfbom_16_be * lpeg.patterns.utf16_to_utf8_be
----- b_pattern = lpeg.patterns.hextobytes

local function get_string(v)
    -- the toutf function only converts a utf16 string and leaves the original
    -- untouched otherwise; one might want to apply lpdf.frompdfdoc to a
    -- non-unicode string
    local s = getString(v)
    if not s or s == "" then
        return ""
    end
    local u = lpegmatch(u_pattern,s)
    if u then
        return u, "unicode"
    end
    -- this is too tricky and fails on e.g. reload of url www.pragma-ade.com)
 -- local b = lpegmatch(b_pattern,s)
 -- if b then
 --     return b, "rawtext"
 -- end
    return s, "rawtext"
end

local function get_name(v)
    return getName(v), "name"
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

checked_access = setmetatableindex(function(t,k)
    return function(v,document)
        invalidaccess(k,document)
    end
end)

checked_access[typenumbers.boolean]    = getBool
checked_access[typenumbers.integer]    = getInt
checked_access[typenumbers.real]       = getReal
checked_access[typenumbers.string]     = get_string     -- getString
checked_access[typenumbers.name]       = get_name
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

-- This is the only messy helper. We can't access the root as any object (it seems)
-- so we need a few low level acessors. It's anyway sort of simple enough to deal
-- with but it won't win a beauty contest.

local function getpages(document,Catalog)
    local __data__     = document.__data__
    local __xrefs__    = document.__xrefs__
    local __cache__    = document.__cache__
    local __xref__     = document.__xref__
    --
    local rawcatalog   = getRawCatalog(__data__)
    local nofpages     = getNumPages(rawcatalog)
    --
    local majorversion = getMajorVersion(__data__)
    local minorversion = getMinorVersion(__data__)
    --
    local pages        = { }
    local metatable    = { __index = Catalog.Pages } -- somewhat empty
    --
    for pagenumber=1,nofpages do
        local pagereference = getPageRef(rawcatalog,pagenumber).num
        local pageobject    = fetch(__xref__,pagereference,0)
        local pagedata      = get_dictionary(pageobject,document,pagereference,metatable)
        if pagedata then
         -- rawset(pagedata,"number",pagenumber)
            pagedata.number          = pagenumber
            pagedata.object          = pageobject
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
    document.pages        = pages
    document.majorversion = majorversion
    document.minorversion = minorversion
    --
    return pages
end

local function resolve(document,k)
    local entry   = nil
    local Catalog = document.Catalog
    local Names   = Catalog.Names
    if     k == "pages" then
        entry = getpages(document,Catalog)
    elseif k == "destinations" then
        entry = getnames(document,Names and Names.Dests)
    elseif k == "javascripts" then
        entry = getnames(document,Names and Names.JS)
    elseif k == "widgets" then
        entry = getnames(document,Names and Names.AcroForm)
    elseif k == "embeddedfiles" then
        entry = getnames(document,Names and Names.EmbeddedFiles)
    elseif k == "layers" then
        entry = getlayers(document)
    elseif k == "structure" then
        entry = getstructure(document)
    end
    document[k] = entry
    return entry
end

local loaded = { }

function lpdf_epdf.load(filename)
    local document = loaded[filename]
    if not document then
        statistics.starttiming(lpdf_epdf)
        local __data__ = openPDF(filename) -- maybe resolvers.find_file
        if __data__ then
            local __xref__ = getXRef(__data__)
            document = {
                filename  = filename,
                __cache__ = { },
                __xrefs__ = { },
                __fonts__ = { },
                __data__  = __data__,
                __xref__  = __xref__
            }
            document.Catalog = some_dictionary(getDict(getCatalog(__xref__)),document)
            document.Info    = some_dictionary(getDict(getDocInfo(__xref__)),document)
            setmetatableindex(document,resolve)
            --
            document.nofpages = getNumPages(getRawCatalog(__data__))
        else
            document = false
        end
        loaded[filename] = document
        loaded[document] = document
        statistics.stoptiming(lpdf_epdf)
     -- print(statistics.elapsedtime(lpdf_epdf))
    end
    return document or nil
end

function lpdf_epdf.unload(filename)
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

lpdf_epdf.expand   = expand
lpdf_epdf.expanded = expanded

-- we could resolve the text stream in one pass if we directly handle the
-- font but why should we complicate things

local hexdigit  = R("09","AF")
local numchar   = ( P("\\") * ( (R("09")^3/tonumber) + C(1) ) ) + C(1)
local number    = lpegpatterns.number / tonumber
local spaces    = lpegpatterns.whitespace^1
local optspaces = lpegpatterns.whitespace^0
local keyword   = P("/") * C(R("AZ","az","09")^1)
local operator  = C((R("AZ","az")+P("'")+P('"'))^1)

local grammar   = P { "start",
    start      = (keyword + number + V("dictionary") + V("unicode") + V("string") + V("unicode")+ V("array") + spaces)^1,
 -- keyvalue   = (keyword * spaces * V("start") + spaces)^1,
    keyvalue   = optspaces * Cf(Ct("") * Cg(keyword * optspaces * V("start") * optspaces)^1,rawset),
    array      = P("[")  * Ct(V("start")^1) * P("]"),
    dictionary = P("<<") *    V("keyvalue") * P(">>"),
    unicode    = P("<")  * Ct(Cc("hex") * C((1-P(">"))^1))            * P(">"),
    string     = P("(")  * Ct(Cc("dec") * C((V("string")+numchar)^1)) * P(")"), -- untested
}

local operation = Ct(grammar^1 * operator)
local parser    = Ct((operation + P(1))^1)

-- beginbfrange : <start> <stop> <firstcode>
--                <start> <stop> [ <firstsequence> <firstsequence> <firstsequence> ]
-- beginbfchar  : <code> <newcodes>

local fromsixteen = lpdf.fromsixteen -- maybe inline the lpeg ... but not worth it

local function f_bfchar(t,a,b)
    t[tonumber(a,16)] = fromsixteen(b)
end

local function f_bfrange_1(t,a,b,c)
    print("todo 1",a,b,c)
    -- c is string
    -- todo t[tonumber(a,16)] = fromsixteen(b)
end

local function f_bfrange_2(t,a,b,c)
    print("todo 2",a,b,c)
    -- c is table
    -- todo t[tonumber(a,16)] = fromsixteen(b)
end

local optionals   = spaces^0
local hexstring   = optionals * P("<") * C((1-P(">"))^1) * P(">")
local bfchar      = Carg(1) * hexstring * hexstring / f_bfchar
local bfrange     = Carg(1) * hexstring * hexstring * hexstring / f_bfrange_1
                  + Carg(1) * hexstring * hexstring * optionals * P("[") * Ct(hexstring^1) * optionals * P("]") / f_bfrange_2
local fromunicode = (
    P("beginbfchar" ) * bfchar ^1 * optionals * P("endbfchar" ) +
    P("beginbfrange") * bfrange^1 * optionals * P("endbfrange") +
    spaces +
    P(1)
)^1  * Carg(1)

local function analyzefonts(document,resources) -- unfinished, see mtx-pdf for better code
    local fonts = document.__fonts__
    if resources then
        local fontlist = resources.Font
        if fontlist then
            for id, data in expanded(fontlist) do
                if not fonts[id] then
                    --  a quick hack ... I will look into it more detail if I find a real
                    -- -application for it
                    local tounicode = data.ToUnicode()
                    if tounicode then
                        tounicode = lpegmatch(fromunicode,tounicode,1,{})
                    end
                    fonts[id] = {
                        tounicode = type(tounicode) == "table" and tounicode or { }
                    }
                    setmetatableindex(fonts[id],"self")
                end
            end
        end
    end
    return fonts
end

local more = 0
local unic = nil -- cheaper than passing each time as Carg(1)

local p_hex_to_utf = C(4) / function(s) -- needs checking !
    local now = tonumber(s,16)
    if more > 0 then
        now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000 -- the 0x10000 smells wrong
        more = 0
        return unic[now] or utfchar(now)
    elseif now >= 0xD800 and now <= 0xDBFF then
        more = now
     -- return ""
    else
        return unic[now] or utfchar(now)
    end
end

local p_dec_to_utf = C(1) / function(s) -- needs checking !
    local now = byte(s)
    return unic[now] or utfchar(now)
end

local p_hex_to_utf = P(true) / function() more = 0 end * Cs(p_hex_to_utf^1)
local p_dec_to_utf = P(true) / function() more = 0 end * Cs(p_dec_to_utf^1)

function lpdf_epdf.getpagecontent(document,pagenumber)

    local page = document.pages[pagenumber]

    if not page then
        return
    end

    local fonts   = analyzefonts(document,page.Resources)

    local content = page.Contents() or ""
    local list    = lpegmatch(parser,content)
    local font    = nil
 -- local unic    = nil

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
                    if li[1] == "hex" then
                        list[i] = lpegmatch(p_hex_to_utf,li[2])
                    else
                        list[i] = lpegmatch(p_dec_to_utf,li[2])
                    end
                else
                    -- kern
                end
            end
        elseif operator == "Tj" or operator == "'" or operator == '"' then -- { string,  Tj } { string, ' } { n, m, string, " }
            local list = entry[size-1]
            if list[1] == "hex" then
                list[2] = lpegmatch(p_hex_to_utf,li[2])
            else
                list[2] = lpegmatch(p_dec_to_utf,li[2])
            end
        end
    end

    unic = nil -- can be collected

    return list

end

-- This is also an experiment. When I really need it I can improve it, for instance
-- with proper position calculating. It might be usefull for some search or so.

local softhyphen = utfchar(0xAD) .. "$"
local linefactor = 1.3

function lpdf_epdf.contenttotext(document,list) -- maybe signal fonts
    local last_y = 0
    local last_f = 0
    local text   = { }
    local last   = 0

    for i=1,#list do
        local entry    = list[i]
        local size     = #entry
        local operator = entry[size]
        if operator == "Tf" then
            last_f = entry[2]
        elseif operator == "TJ" then
            local list = entry[1]
            for i=1,#list do
                local li = list[i]
                if type(li) == "string" then
                    last = last + 1
                    text[last] = li
                elseif li < -50 then
                    last = last + 1
                    text[last] = " "
                end
            end
            line = concat(list)
        elseif operator == "Tj" then
            last = last + 1
            text[last] = entry[size-1]
        elseif operator == "cm" or operator == "Tm" then
            local ty = entry[6]
            local dy = abs(last_y - ty)
            if dy > linefactor*last_f then
                if last > 0 then
                    if find(text[last],softhyphen,1,true) then
                        -- ignore
                    else
                        last = last + 1
                        text[last] = "\n"
                    end
                end
            end
            last_y = ty
        end
    end

    return concat(text)
end

function lpdf_epdf.getstructure(document,list) -- just a test
    local depth = 0
    for i=1,#list do
        local entry    = list[i]
        local size     = #entry
        local operator = entry[size]
        if operator == "BDC" then
            report_epdf("%w%s : %s",depth,entry[1] or "?",entry[2].MCID or "?")
            depth = depth + 1
        elseif operator == "EMC" then
            depth = depth - 1
        elseif operator == "TJ" then
            local list = entry[1]
            for i=1,#list do
                local li = list[i]
                if type(li) == "string" then
                    report_epdf("%w > %s",depth,li)
                elseif li < -50 then
                    report_epdf("%w >",depth,li)
                end
            end
        elseif operator == "Tj" then
            report_epdf("%w > %s",depth,entry[size-1])
        end
    end
end

-- document.Catalog.StructTreeRoot.ParentTree.Nums[2][1].A.P[1])

-- helpers

-- function lpdf_epdf.getdestinationpage(document,name)
--     local destination = document.__data__:findDest(name)
--     return destination and destination.number
-- end

-- This is experimental code that we need for testing the transition from
-- poppler to a new lightweight library. Don't rely on this code to remain
-- as it is now. Interesting is that performance of this variant is the same
-- as the natural page includer.

if img then do

    local copydictionary       = nil
    local copyarray            = nil

    local ref_code             = typenumbers.ref
    local boolean_code         = typenumbers.boolean
    local integer_code         = typenumbers.integer
    local real_code            = typenumbers.real
    local string_code          = typenumbers.string
    local name_code            = typenumbers.name
    local null_code            = typenumbers.null
    local array_code           = typenumbers.array
    local dictionary_code      = typenumbers.dictionary
    local stream_code          = typenumbers.stream
    local cmd_code             = typenumbers.cmd

    local pdfreserveobject     = lpdf.reserveobject
    local pdfflushobject       = lpdf.flushobject
    local pdfflushstreamobject = lpdf.flushstreamobject
    local pdfreference         = lpdf.reference
    local pdfconstant          = lpdf.constant
    local pdfarray             = lpdf.array
    local pdfdictionary        = lpdf.dictionary
    local pdfunicode           = lpdf.unicode
    local pdfstring            = lpdf.string
    local pdfnull              = lpdf.null

    local report               = logs.reporter("backend","xobjects")

    local factor               = 65536 / (7200/7227) -- 1/number.dimenfactors.bp

    local newimage             = img.new

    local function scaledbbox(b)
        return { b[1]*factor, b[2]*factor, b[3]*factor, b[4]*factor }
    end

    local function copyobject(xref,copied,kind,r,v)
        if kind == null_code then
            return pdfnull()
        elseif r and getType(r) == ref_code then
            local objnum = getRefNum(r)
            local r = copied[objnum]
            if r then
             -- report("%s object %i is reused",kind,objnum)
            else
                local o
                r = pdfreserveobject()
                copied[objnum] = r
                if kind == array_code then
                    local a = copyarray(xref,copied,fetch(xref,objnum,0))
                    pdfflushobject(r,tostring(a))
                elseif kind == dictionary_code then
                    local d = copydictionary(xref,copied,fetch(xref,objnum,0))
                    pdfflushobject(r,tostring(d))
                elseif kind == stream_code then
                    local f = fetch(xref,objnum,0)
                    local d = copydictionary(xref,copied,false,streamGetDict(f))
                    local s = getstream(f)
                    --
                    d.Filter      = nil
                    d.Length      = nil
                    d.DecodeParms = nil
                    d.DL          = nil
                    --
                    pdfflushstreamobject(s,d,true,r)
                else
                    report("reference not done: %s", kind)
                end
            end
            return pdfreference(r)
        elseif kind == array_code then
            return copyarray(xref,copied,v)
        elseif kind == dictionary_code then
            return copydictionary(xref,copied,v)
        elseif kind == integer_code then
            return getInt(v)
        elseif kind == real_code then
            return getReal(v)
        elseif kind == name_code then
            return pdfconstant(getName(v))
        elseif kind == string_code then
            local s = getString(v)
            if not s or s == "" then
                return ""
            end
            local u = lpegmatch(u_pattern,s)
            if u then
                return pdfunicode(s)
            end
            return pdfstring(s)
        elseif kind == boolean_code then
            return getBool(v)
        elseif kind == stream_code then
            -- hm ...
            return getStream(v)
        else
            report("object not done: %s", kind)
        end
    end

    copyarray = function (xref,copied,object)
        local a = getArray(object)
        local n = a and arrayGetLength(a) or 0
        if n > 0 then
            local target = pdfarray()
            for i=1,n do
                local v = arrayGet(a,i)
                if v then
                    local kind = getType(v)
                    local r    = arrayGetNF(a,i)
                    target[i]  = copyobject(xref,copied,kind,r,v)
                end
            end
            return target
        end
    end

    copydictionary = function (xref,copied,object,d)
        local d = d or getDict(object)
        local n = d and dictGetLength(d) or 0
        if n > 0 then
            local target = pdfdictionary()
            for i=1,n do
                local v = dictGetVal(d,i)
                if v then
                    local kind  = getType(v)
                    local key   = dictGetKey(d,i)
                    local r     = dictGetValNF(d,i)
                    target[key] = copyobject(xref,copied,kind,r,v)
                end
            end
            return target
        end
    end

    local function copy_resources(pdfdoc,xref,copied,pagedata)
        local object = pagedata.object
        if object then
            local d = getDict(object)
            local n = d and dictGetLength(d) or 0
            for i=1,n do
                local k = dictGetKey(d,i)
                if v and k == "Resources" then
                    local v    = dictGetVal(d,i)
                    local kind = getType(v)
                    local r    = dictGetValNF(d,i)
                    return copyobject(xref,copied,kind,r,v)
                end
            end
        end
    end

    local function openpdf(filename)
        local pdfdoc = lpdf_epdf.load(filename)
        if pdfdoc then
            pdfdoc.__copied__ = pdfdoc.__copied__ or { }
            pdfdoc.filename   = filename
            return pdfdoc
        end
    end

    local function closepdf(pdfdoc)
        if pdfdoc then
            lpdf_epdf.unload(pdfdoc.filename)
        end
    end

    local function querypdf(pdfdoc,pagenumber)
        if pdfdoc then
            if not pagenumber then
                pagenumber = 1
            end
            local root = pdfdoc.Catalog
            local page = pdfdoc.pages[pagenumber]
            if page then
                local mediabox = page.MediaBox or { 0, 0, 0, 0 }
                local cropbox  = page.CropBox or mediabox
                return {
                    filename    = pdfdoc.filename,
                    pagenumber  = pagenumber,
                    nofpages    = pdfdoc.nofpages,
                    boundingbox = scaledbbox(cropbox),
                    cropbox     = cropbox,
                    mediabox    = mediabox,
                    bleedbox    = page.BleedBox or cropbox,
                    trimbox     = page.TrimBox or cropbox,
                    artbox      = page.ArtBox or cropbox,
                }
            end
        end
    end

    local function copypage(pdfdoc,pagenumber,attributes)
        if pdfdoc then
            local root     = pdfdoc.Catalog
            local page     = pdfdoc.pages[pagenumber or 1]
            local pageinfo = querypdf(pdfdoc,pagenumber)
            local contents = page.Contents
            local xref     = pdfdoc.__xref__
            local copied   = pdfdoc.__copied__
            --
            local xobject  = pdfdictionary {
                Type           = pdfconstant("XObject"),
                Subtype        = pdfconstant("Form"),
             -- image attributes
                FormType       = 1,
                BBox           = pageinfo.cropbox,
             -- MetaData       = copy(xref,copied,root,"MetaData"),
             -- Group          = copy(xref,copied,page,"Group"),
             -- LastModified   = copy(xref,copied,page,"LastModified"),
             -- Metadata       = copy(xref,copied,page,"Metadata"),
             -- PieceInfo      = copy(xref,copied,page,"PieceInfo"),
                Resources      = copy_resources(pdfdoc,xref,copied,page),
             -- SeparationInfo = copy(xref,copied,page,"SeparationInfo"),
            }
            if attributes then
                for k, v in next, expand(attributes) do
                    page[k] = v -- maybe nested
                end
            end
            return newimage {
                bbox   = pageinfo.boundingbox,
                stream = contents(),
                attr   = xobject(),
            }
        end
    end

    lpdf_epdf.image = {
        open  = openpdf,
        close = closepdf,
        query = querypdf,
        copy  = copypage,
    }

end end
