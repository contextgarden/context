if not modules then modules = { } end modules ['lpdf-epd'] = {
    version   = 1.001,
    comment   = "companion to lpdf-epa.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    history   = "this one replaces the poppler/pdfe binding",
}

-- maximum integer : +2^32
-- maximum real    : +2^15
-- minimum real    : 1/(2^16)

-- get_flagged : does that still work

-- ppdoc_permissions (ppdoc *pdf);

-- PPSTRING_ENCODED        1 <<  0
-- PPSTRING_DECODED        1 <<  1
-- PPSTRING_EXEC           1 <<  2   postscript only
-- PPSTRING_PLAIN                0
-- PPSTRING_BASE16         1 <<  3
-- PPSTRING_BASE85         1 <<  4
-- PPSTRING_UTF16BE        1 <<  5
-- PPSTRING_UTF16LE        1 <<  6

-- PPDOC_ALLOW_PRINT       1 <<  2   printing
-- PPDOC_ALLOW_MODIFY      1 <<  3   filling form fields, signing, creating template pages
-- PPDOC_ALLOW_COPY        1 <<  4   copying, copying for accessibility
-- PPDOC_ALLOW_ANNOTS      1 <<  5   filling form fields, copying, signing
-- PPDOC_ALLOW_EXTRACT     1 <<  9   contents copying for accessibility
-- PPDOC_ALLOW_ASSEMBLY    1 << 10   no effect
-- PPDOC_ALLOW_PRINT_HIRES 1 << 11   no effect

-- PPCRYPT_NONE                  0   no encryption, go ahead
-- PPCRYPT_DONE                  1   encryption present but password succeeded, go ahead
-- PPCRYPT_PASS                 -1   encryption present, need non-empty password
-- PPCRYPT_FAIL                 -2   invalid or unsupported encryption (eg. undocumented in pdf spec)

local setmetatable, rawset, rawget, type, next = setmetatable, rawset, rawget, type, next
local tostring, tonumber, unpack = tostring, tonumber, unpack
local char, byte, find = string.char, string.byte, string.find
local abs = math.abs
local concat, swapped = table.concat, table.swapped
local utfchar = string.char
local setmetatableindex = table.setmetatableindex

local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local P, C, S, R, Ct, Cc, V, Carg, Cs, Cf, Cg = lpeg.P, lpeg.C, lpeg.S, lpeg.R, lpeg.Ct, lpeg.Cc, lpeg.V, lpeg.Carg, lpeg.Cs, lpeg.Cf, lpeg.Cg

if not lpdf then require("lpdf-aux") end

local epdf              = pdfe
      lpdf              = lpdf or { }
local lpdf              = lpdf
local lpdf_epdf         = { }
lpdf.epdf               = lpdf_epdf

local openPDF           = epdf.open
local closePDF          = epdf.close

local getcatalog        = epdf.getcatalog
local getinfo           = epdf.getinfo
local gettrailer        = epdf.gettrailer
local getnofpages       = epdf.getnofpages
local getversion        = epdf.getversion
local getbox            = epdf.getbox
local getstatus         = epdf.getstatus
local unencrypt         = epdf.unencrypt

local dictionarytotable = epdf.dictionarytotable
local arraytotable      = epdf.arraytotable
local pagestotable      = epdf.pagestotable
local readwholestream   = epdf.readwholestream

local getfromreference  = pdfe.getfromreference

local report_epdf       = logs.reporter("epdf")

local allocate          = utilities.storage.allocate

local objectcodes = {
     [0] = "none",
           "null",
           "bool",
           "integer",
           "number",
           "name",
           "string",
           "array",
           "dictionary",
           "stream",
           "reference",
}

local encryptioncodes = {
     [0] = "notencrypted",
     [1] = "unencrypted",
    [-1] = "protected",
    [-2] = "failure",
}

objectcodes           = allocate(swapped(objectcodes,objectcodes))
encryptioncodes       = allocate(swapped(encryptioncodes,encryptioncodes))

pdfe.objectcodes      = objectcodes
pdfe.encryptioncodes  = encryptioncodes

local null_code       = objectcodes.null
local reference_code  = objectcodes.reference

local none_code       = objectcodes.none
local null_code       = objectcodes.null
local bool_code       = objectcodes.bool
local integer_code    = objectcodes.integer
local number_code     = objectcodes.number
local name_code       = objectcodes.name
local string_code     = objectcodes.string
local array_code      = objectcodes.array
local dictionary_code = objectcodes.dictionary
local stream_code     = objectcodes.stream
local reference_code  = objectcodes.reference

local checked_access
local get_flagged     -- from pdfe -> lpdf

if lpdf.dictionary then

    -- we're in context

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
        return t[k]
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

local some_dictionary
local some_array
local some_stream
local some_reference

local some_string = lpdf.frombytes

local function get_value(document,t,key)
    if not key then
        return
    end
    local value = t[key]
    if not value then
        return
    end
    if type(value) ~= "table" then
        return value
    end
    -- we can assume names to be simple and strings to be tables
    local kind = value[1]
    if kind == name_code then
        return value[2]
    elseif kind == string_code then
        return some_string(value[2],value[3])
    elseif kind == array_code then
        return some_array(value[2],document)
    elseif kind == dictionary_code then
        return some_dictionary(value[2],document)
    elseif kind == stream_code then
        return some_stream(value,document)
    elseif kind == reference_code then
        return some_reference(value,document)
    end
    return value
end

some_dictionary = function (d,document)
    local f = dictionarytotable(d,true)
    local t = setmetatable({ __raw__ = f, __type__ = dictionary_code }, {
       __index = function(t,k)
           return get_value(document,f,k)
       end,
       __call = function(t,k)
           return get_flagged(t,f,k)
       end,
    } )
    return t, "dictionary"
end

some_array = function (a,document)
    local f = arraytotable(a,true)
    local n = #f
    local t = setmetatable({ __raw__ = f, __type__ = array_code, n = n }, {
        __index = function(t,k)
            return get_value(document,f,k)
        end,
        __call = function(t,k)
            return get_flagged(t,f,k)
        end,
        __len = function(t,k)
            return n
        end,
    } )
    return t, "array"
end

some_stream = function(s,d,document)
    local f = dictionarytotable(d,true)
    local t = setmetatable({ __raw__ = f, __type__ = stream_code }, {
        __index = function(t,k)
            return get_value(document,f,k)
        end,
        __call = function(t,raw)
            if raw == false then
                return readwholestream(s,false) -- original
            else
                return readwholestream(s,true)  -- uncompressed
            end
        end,
    } )
    return t, "stream"
end

some_reference = function(r,document)
    local objnum = r[3]
    local cached = document.__cache__[objnum]
    if not cached then
        local kind, object, b, c = getfromreference(r[2])
        if kind == dictionary_code then
            cached = some_dictionary(object,document)
        elseif kind == array_code then
            cached = some_array(object,document)
        elseif kind == stream_code then
            cached = some_stream(object,b,document)
        else
            cached = { kind, object, b, c }
            -- really cache this?
        end
        document.__cache__[objnum] = cached
        document.__xrefs__[cached] = objnum
    end
    return cached
end

local resolvers     = { }
lpdf_epdf.resolvers = resolvers

local function resolve(document,k)
    local resolver = resolvers[k]
    if resolver then
        local entry = resolver(document)
        document[k] = entry
        return entry
    end
end

local function getnames(document,n,target) -- direct
    if n then
        local Names = n.Names
        if Names then
            if not target then
                target = { }
            end
            for i=1,#Names,2 do
                target[Names[i]] = Names[i+1]
            end
        else
            local Kids = n.Kids
            if Kids then
                for i=1,#Kids do
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
            for i=1,#Kids do
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

function resolvers.destinations(document)
    local Names = document.Catalog.Names
    return getnames(document,Names and Names.Dests)
end

function resolvers.javascripts(document)
    local Names = document.Catalog.Names
    return getnames(document,Names and Names.JS)
end

function resolvers.widgets(document)
    local Names = document.Catalog.Names
    return getnames(document,Names and Names.AcroForm)
end

function resolvers.embeddedfiles(document)
    local Names = document.Catalog.Names
    return getnames(document,Names and Names.EmbeddedFiles)
end

-- /OCProperties <<
--     /OCGs [ 15 0 R 17 0 R 19 0 R 21 0 R 23 0 R 25 0 R 27 0 R ]
--     /D <<
--         /Order [ 15 0 R 17 0 R 19 0 R 21 0 R 23 0 R 25 0 R 27 0 R ]
--         /ON    [ 15 0 R 17 0 R 19 0 R 21 0 R 23 0 R 25 0 R 27 0 R ]
--         /OFF   [ ]
--     >>
-- >>

function resolvers.layers(document)
    local properties = document.Catalog.OCProperties
    if properties then
        local layers = properties.OCGs
        if layers then
            local t = { }
            for i=1,#layers do
                local layer = layers[i]
                t[i] = layer.Name
            end
         -- t.n = n
            return t
        end
    end
end

function resolvers.structure(document)
    -- this might become a tree
    return document.Catalog.StructTreeRoot
end

function resolvers.pages(document)
    local __data__  = document.__data__
    local __xrefs__ = document.__xrefs__
    local __cache__ = document.__cache__
    --
    local nofpages = document.nofpages
    local pages    = { }
    local rawpages = pagestotable(__data__)
    document.pages = pages
    --
    for pagenumber=1,nofpages do
        local rawpagedata   = rawpages[pagenumber]
        local pagereference = rawpagedata[3]
        local pageobject    = rawpagedata[1]
        local pagedata      = some_dictionary(pageobject,document)
        if pagedata and pageobject then
            pagedata.number   = pagenumber
            pagedata.MediaBox = getbox(pageobject,"MediaBox")
            pagedata.CropBox  = getbox(pageobject,"CropBox")
            pagedata.BleedBox = getbox(pageobject,"BleedBox")
            pagedata.ArtBox   = getbox(pageobject,"ArtBox")
            pagedata.TrimBox  = getbox(pageobject,"TrimBox")
            pages[pagenumber] = pagedata
            __xrefs__[pagedata]      = pagereference
            __cache__[pagereference] = pagedata
        else
            report_epdf("missing pagedata for page %i",i)
        end
    end
    --
 -- pages.n = nofpages
    --
    return pages
end

local loaded    = { }
local nofloaded = 0

function lpdf_epdf.load(filename,userpassword,ownerpassword)
    local document = loaded[filename]
    if not document then
        statistics.starttiming(lpdf_epdf)
        local __data__ = openPDF(filename) -- maybe resolvers.find_file
        if __data__ then
-- nofloaded = nofloaded + 1
-- report_epdf("%04i opened: %s",nofloaded,filename)
            if userpassword and getstatus(__data__) < 0 then
                unencrypt(__data__,userpassword,nil)
            end
            if ownerpassword and getstatus(__data__) < 0 then
                unencrypt(__data__,nil,ownerpassword)
            end
            if getstatus(__data__) < 0 then
                report_epdf("the document is encrypted, provide proper passwords",getstatus(__data__))
            end
            if __data__ then
                document = {
                    filename   = filename,
                    __cache__  = { },
                    __xrefs__  = { },
                    __fonts__  = { },
                    __copied__ = { },
                    __data__   = __data__,
                }
                document.Catalog = some_dictionary(getcatalog(__data__),document)
                document.Info    = some_dictionary(getinfo(__data__),document)
                document.Trailer = some_dictionary(gettrailer(__data__),document)
                --
                setmetatableindex(document,resolve)
                --
                document.majorversion, document.minorversion = getversion(__data__)
                --
                document.nofpages = getnofpages(__data__)
            else
                document = false
            end
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
    if type(filename) == "table" then
        filename = filename.filename
    end
    if type(filename) == "string" then
        local document = loaded[filename]
        if document then
-- report_epdf("%04i closed: %s",nofloaded,filename)
-- nofloaded = nofloaded - 1
            loaded[document] = nil
            loaded[filename] = nil
        end
    end
end

-- for k, v in expanded(t) do

local function expanded(t)
    local function iterator(raw,k)
        local k, v = next(raw,k)
        if v then
            return k, t[k]
        end
    end
    return iterator, t.__raw__, nil
end

---------.expand   = expand
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
            report_epdf("%w%s : %s",depth,entry[1] or "?",entry[2] and entry[2].MCID or "?")
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

if img then do

    -- This can be made a bit faster (just get raw data and pass it) but I will
    -- do that later. In the end the benefit is probably neglectable.

    local recompress           = true
    local recompress           = false

    local copydictionary       = nil
    local copyarray            = nil

    local pdfreserveobject     = lpdf.reserveobject
    local shareobjectreference = lpdf.shareobjectreference
    local pdfflushobject       = lpdf.flushobject
    local pdfflushstreamobject = lpdf.flushstreamobject
    local pdfreference         = lpdf.reference
    local pdfconstant          = lpdf.constant
    local pdfarray             = lpdf.array
    local pdfdictionary        = lpdf.dictionary
    local pdfnull              = lpdf.null
    local pdfliteral           = lpdf.literal

    local report               = logs.reporter("backend","xobjects")

    local factor               = 65536 / (7200/7227) -- 1/number.dimenfactors.bp

    local newimage             = img.new

    local function scaledbbox(b)
        return { b[1]*factor, b[2]*factor, b[3]*factor, b[4]*factor }
    end

    local function deepcopyobject(xref,copied,value)
        -- no need for tables, just nested loop with obj
        local objnum = xref[value]
        if objnum then
            local usednum = copied[objnum]
            if usednum then
             -- report("%s object %i is reused",kind,objnum)
            else
                usednum = pdfreserveobject()
                copied[objnum] = usednum
                local entry = value
                local kind  = entry.__type__
                if kind == array_code then
                    local a = copyarray(xref,copied,entry)
                    pdfflushobject(usednum,tostring(a))
                elseif kind == dictionary_code then
                    local d = copydictionary(xref,copied,entry)
                    pdfflushobject(usednum,tostring(d))
                elseif kind == stream_code then
                    local d = copydictionary(xref,copied,entry)
                    if recompress then
                        -- recompress
                        d.Filter      = nil
                        d.Length      = nil
                        d.DecodeParms = nil -- not relevant
                        d.DL          = nil -- needed?
                        local s = entry()                        -- get uncompressed stream
                        pdfflushstreamobject(s,d,true,usednum)   -- compress stream
                    else
                        -- keep as-is, even Length which indicates the
                        -- decompressed length
                        local s = entry(false)                        -- get compressed stream
                     -- pdfflushstreamobject(s,d,false,usednum,true)  -- don't compress stream
                        pdfflushstreamobject(s,d,"raw",usednum)       -- don't compress stream
                    end
                else
                    local t = type(value)
                    if t == "string" then
                        value = pdfconstant(value)
                    elseif t == "table" then
                        local kind  = value[1]
                        local entry = value[2]
                        if kind == name_code then
                            value = pdfconstant(entry)
                        elseif kind == string_code then
                            value = pdfliteral(entry,value[3])
                        elseif kind == null_code then
                            value = pdfnull()
                        elseif kind == reference_code then
                            value = deepcopyobject(xref,copied,entry)
                        else
                            value = tostring(entry)
                        end
                    end
                    pdfflushobject(usednum,value)
                end
            end
            return pdfreference(usednum)
        elseif kind == stream_code then
            report("stream not done: %s", objectcodes[kind] or "?")
        else
            report("object not done: %s", objectcodes[kind] or "?")
        end
    end

    local function copyobject(xref,copied,object,key,value)
        if not value then
            value = object.__raw__[key]
        end
        local t = type(value)
        if t == "string" then
            return pdfconstant(value)
        elseif t ~= "table" then
            return value
        end
        local kind = value[1]
        if kind == name_code then
            return pdfconstant(value[2])
        elseif kind == string_code then
            return pdfliteral(value[2],value[3])
        elseif kind == array_code then
            return copyarray(xref,copied,object[key])
        elseif kind == dictionary_code then
            return copydictionary(xref,copied,object[key])
        elseif kind == null_code then
            return pdfnull()
        elseif kind == reference_code then
            -- expand
            return deepcopyobject(xref,copied,object[key])
        else
            report("weird: %s", objecttypes[kind] or "?")
        end
    end

    copyarray = function (xref,copied,object)
        local target = pdfarray()
        local source = object.__raw__
        for i=1,#source do
            target[i] = copyobject(xref,copied,object,i,source[i])
        end
        return target
    end

    local plugins = nil

    copydictionary = function (xref,copied,object)
        local target = pdfdictionary()
        local source = object.__raw__
        for key, value in next, source do
            if plugins then
                local p = plugins[key]
                if p then
                    target[key] = p(xref,copied,object,key,value,copyobject) -- maybe a table of methods
                else
                    target[key] = copyobject(xref,copied,object,key,value)
                end
            else
                target[key] = copyobject(xref,copied,object,key,value)
            end
        end
        return target
    end

 -- local function copyresources(pdfdoc,xref,copied,pagedata)
 --     local Resources = pagedata.Resources
 --     if Resources then
 --         local r = pdfreserveobject()
 --         local d = copydictionary(xref,copied,Resources)
 --         pdfflushobject(r,tostring(d))
 --         return pdfreference(r)
 --     end
 -- end

    local function copyresources(pdfdoc,xref,copied,pagedata)
        local Resources = pagedata.Resources
     --
     -- -- This needs testing:
     --
     -- if not Resources then
     --     local Parent = page.Parent
     --     while (Parent and (Parent.__type__ == dictionary_code or Parent.__type__ == reference_code) do
     --         Resources = Parent.Resources
     --         if Resources then
     --             break
     --         end
     --         Parent = Parent.Parent
     --     end
     -- end
        if Resources then
            local d = copydictionary(xref,copied,Resources)
            return shareobjectreference(d)
        end
    end

    local openpdf  = lpdf_epdf.load
    local closepdf = lpdf_epdf.unload

    local function querypdf(pdfdoc,pagenumber)
        if pdfdoc then
            if not pagenumber then
                pagenumber = 1
            end
            local root = pdfdoc.Catalog
            local page = pdfdoc.pages[pagenumber]
            if page then
                -- todo
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

    local function copypage(pdfdoc,pagenumber,attributes,compact)
        if pdfdoc then
            local root     = pdfdoc.Catalog
            local page     = pdfdoc.pages[pagenumber or 1]
            local pageinfo = querypdf(pdfdoc,pagenumber)
            local contents = page.Contents
            local xref     = pdfdoc.__xrefs__
            local copied   = pdfdoc.__copied__
            if compact and lpdf_epdf.plugin then
                plugins = lpdf_epdf.plugin(pdfdoc,xref,copied,page)
            end
            local xobject  = pdfdictionary {
                Group          = copyobject(xref,copied,page,"Group"),
                LastModified   = copyobject(xref,copied,page,"LastModified"),
                Metadata       = copyobject(xref,copied,page,"Metadata"),
                PieceInfo      = copyobject(xref,copied,page,"PieceInfo"),
                Resources      = copyresources(pdfdoc,xref,copied,page),
                SeparationInfo = copyobject(xref,copied,page,"SeparationInfo"),
            }
            if attributes then
                for k, v in expanded(attributes) do
                    page[k] = v -- maybe nested
                end
            end
            local content  = ""
            local nolength = nil
            local ctype    = contents.__type__
            -- we always recompress because image object streams can not be
            -- influenced (yet)
            if ctype == stream_code then
                if recompress then
                    content = contents() -- uncompressed
                else
                    local Filter = copyobject(xref,copied,contents,"Filter")
                    local Length = copyobject(xref,copied,contents,"Length")
                    if Length and Filter then
                        nolength = true
                        xobject.Length = Length
                        xobject.Filter = Filter
                        content = contents(false) -- uncompressed
                    else
                        content = contents() -- uncompressed
                    end
                end
            elseif ctype == array_code then
                content = { }
                for i=1,#contents do
                    content[i] = contents[i]() -- uncompressed
                end
                content = concat(content," ")
            end
            -- still not nice: we double wrap now
            plugins = nil
            return newimage {
                bbox     = pageinfo.boundingbox,
                nolength = nolength,
                stream   = content, -- todo: no compress, pass directly also length, filter etc
                attr     = xobject(),
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

-- local d = lpdf_epdf.load("e:/tmp/oeps.pdf")
-- inspect(d)
-- inspect(d.Catalog.Lang)
-- inspect(d.Catalog.OCProperties.D.AS[1].Event)
-- inspect(d.Catalog.Metadata())
-- inspect(d.Catalog.Pages.Kids[1])
-- inspect(d.layers)
-- inspect(d.pages)
-- inspect(d.destinations)
-- inspect(lpdf_epdf.getpagecontent(d,1))
-- inspect(lpdf_epdf.contenttotext(document,lpdf_epdf.getpagecontent(d,1)))
-- inspect(lpdf_epdf.getstructure(document,lpdf_epdf.getpagecontent(d,1)))
