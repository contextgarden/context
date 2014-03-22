if not modules then modules = { } end modules ['back-exp'] = {
    version   = 1.001,
    comment   = "companion to back-exp.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- beware: we run out of the 200 local limit

-- language       -> only mainlanguage, local languages should happen through start/stoplanguage
-- tocs/registers -> maybe add a stripper (i.e. just don't flush entries in final tree)
-- footnotes      -> css 3
-- bodyfont       -> in styles.css
-- delimited      -> left/right string (needs marking)

-- Because we need to look ahead we now always build a tree (this was optional in
-- the beginning). The extra overhead in the frontend is neglectable.
--
-- We can optimize the code ... currently the overhead is some 10% for xml + html so
-- there is no hurry.

-- todo: move critital formatters out of functions
-- todo: delay loading (apart from basic tag stuff)

local next, type = next, type
local format, concat, sub, gsub = string.format, table.concat, string.sub, string.gsub
local validstring = string.valid
local lpegmatch = lpeg.match
local utfchar, utfvalues = utf.char, utf.values
local insert, remove = table.insert, table.remove
local fromunicode16 = fonts.mappings.fromunicode16
local sortedhash = table.sortedhash
local formatters = string.formatters

local trace_export  = false  trackers.register  ("export.trace",         function(v) trace_export  = v end)
local trace_spacing = false  trackers.register  ("export.trace.spacing", function(v) trace_spacing = v end)
local less_state    = false  directives.register("export.lessstate",     function(v) less_state    = v end)
local show_comment  = true   directives.register("export.comment",       function(v) show_comment  = v end)

-- maybe we will also support these:
--
-- local css_hyphens       = false  directives.register("export.css.hyphens",      function(v) css_hyphens      = v end)
-- local css_textalign     = false  directives.register("export.css.textalign",    function(v) css_textalign    = v end)
-- local css_bodyfontsize  = false  directives.register("export.css.bodyfontsize", function(v) css_bodyfontsize = v end)
-- local css_textwidth     = false  directives.register("export.css.textwidth",    function(v) css_textwidth    = v end)

local report_export     = logs.reporter("backend","export")

local nodes             = nodes
local attributes        = attributes
local variables         = interfaces.variables

local settings_to_array = utilities.parsers.settings_to_array

local setmetatableindex = table.setmetatableindex
local tasks             = nodes.tasks
local fontchar          = fonts.hashes.characters
local fontquads         = fonts.hashes.quads
local languagenames     = languages.numbers

local nodecodes         = nodes.nodecodes
local skipcodes         = nodes.skipcodes
local whatsitcodes      = nodes.whatsitcodes
local listcodes         = nodes.listcodes

local hlist_code        = nodecodes.hlist
local vlist_code        = nodecodes.vlist
local glyph_code        = nodecodes.glyph
local glue_code         = nodecodes.glue
local kern_code         = nodecodes.kern
local disc_code         = nodecodes.disc
local insert_code       = nodecodes.insert
local whatsit_code      = nodecodes.whatsit
local refximage_code    = whatsitcodes.pdfrefximage
local localpar_code     = whatsitcodes.localpar

local userskip_code     = skipcodes.userskip
local rightskip_code    = skipcodes.rightskip
local parfillskip_code  = skipcodes.parfillskip
local spaceskip_code    = skipcodes.spaceskip
local xspaceskip_code   = skipcodes.xspaceskip

local line_code         = listcodes.line

local texgetcount       = tex.getcount

local a_characters      = attributes.private('characters')
local a_exportstatus    = attributes.private('exportstatus')

local a_tagged          = attributes.private('tagged')
local a_taggedpar       = attributes.private("taggedpar")
local a_image           = attributes.private('image')
local a_reference       = attributes.private('reference')

local a_textblock       = attributes.private("textblock")

local nuts              = nodes.nuts
local tonut             = nuts.tonut

local getnext           = nuts.getnext
local getsubtype        = nuts.getsubtype
local getfont           = nuts.getfont
local getchar           = nuts.getchar
local getlist           = nuts.getlist
local getid             = nuts.getid
local getfield          = nuts.getfield
local getattr           = nuts.getattr

local setattr           = nuts.setattr

local traverse_id       = nuts.traverse_id
local traverse_nodes    = nuts.traverse

local references        = structures.references
local structurestags    = structures.tags
local taglist           = structurestags.taglist
local properties        = structurestags.properties
local userdata          = structurestags.userdata -- might be combines with taglist
local tagdata           = structurestags.data
local tagmetadata       = structurestags.metadata
local detailedtag       = structurestags.detailedtag

local starttiming       = statistics.starttiming
local stoptiming        = statistics.stoptiming

-- todo: more locals (and optimize)

local exportversion     = "0.30"

local nofcurrentcontent = 0 -- so we don't free (less garbage collection)
local currentcontent    = { }
local currentnesting    = nil
local currentattribute  = nil
local last              = nil
local currentparagraph  = nil

local noftextblocks     = 0

local attributehash     = { } -- to be considered: set the values at the tex end
local hyphencode        = 0xAD
local hyphen            = utfchar(0xAD) -- todo: also emdash etc
local colonsplitter     = lpeg.splitat(":")
local dashsplitter      = lpeg.splitat("-")
local threshold         = 65536
local indexing          = false
local keephyphens       = false

local finetuning        = { }

local treestack         = { }
local nesting           = { }
local currentdepth      = 0

local tree              = { data = { }, fulltag == "root" } -- root
local treeroot          = tree
local treehash          = { }
local extras            = { }
local checks            = { }
local finalizers        = { }
local nofbreaks         = 0
local used              = { }
local exporting         = false
local restart           = false
local specialspaces     = { [0x20] = " "  }               -- for conversion
local somespace         = { [0x20] = true, [" "] = true } -- for testing
local entities          = { ["&"] = "&amp;", [">"] = "&gt;", ["<"] = "&lt;" }
local attribentities    = { ["&"] = "&amp;", [">"] = "&gt;", ["<"] = "&lt;", ['"'] = "quot;" }

local entityremapper    = utf.remapper(entities)

local alignmapping = {
    flushright = "right",
    middle     = "center",
    flushleft  = "left",
}

local numbertoallign = {
    [0] = "justify", ["0"] = "justify", [variables.normal    ] = "justify",
    [1] = "right",   ["1"] = "right",   [variables.flushright] = "right",
    [2] = "center",  ["2"] = "center",  [variables.middle    ] = "center",
    [3] = "left",    ["3"] = "left",    [variables.flushleft ] = "left",
}

local defaultnature = "mixed" -- "inline"

setmetatableindex(used, function(t,k)
    if k then
        local v = { }
        t[k] = v
        return v
    end
end)

setmetatableindex(specialspaces, function(t,k)
    local v = utfchar(k)
    t[k] = v
    entities[v] = formatters["&#x%X;"](k)
    somespace[k] = true
    somespace[v] = true
    return v
end)


local namespaced = {
    -- filled on
}

local namespaces = {
    msubsup    = "m",
    msub       = "m",
    msup       = "m",
    mn         = "m",
    mi         = "m",
    ms         = "m",
    mo         = "m",
    mtext      = "m",
    mrow       = "m",
    mfrac      = "m",
    mroot      = "m",
    msqrt      = "m",
    munderover = "m",
    munder     = "m",
    mover      = "m",
    merror     = "m",
    math       = "m",
    mrow       = "m",
    mtable     = "m",
    mtr        = "m",
    mtd        = "m",
    mfenced    = "m",
    maction    = "m",
    mspace     = "m",
}

setmetatableindex(namespaced, function(t,k)
    if k then
        local namespace = namespaces[k]
        local v = namespace and namespace .. ":" .. k or k
        t[k] = v
        return v
    end
end)

local function attribute(key,value)
    if value and value ~= "" then
        return formatters[' %s="%s"'](key,gsub(value,".",attribentities))
    else
        return ""
    end
end

-- local P, C, Cc = lpeg.P, lpeg.C, lpeg.Cc
--
-- local dash, colon = P("-"), P(":")
--
-- local precolon, predash, rest = P((1-colon)^1), P((1-dash )^1), P(1)^1
--
-- local tagsplitter = C(precolon) * colon * C(predash) * dash * C(rest) +
--                     C(predash)  * dash  * Cc(nil)           * C(rest)

local listdata = { }

local function hashlistdata()
    local c = structures.lists.collected
    for i=1,#c do
        local ci = c[i]
        local tag = ci.references.tag
        if tag then
            local m = ci.metadata
            listdata[m.kind .. ":" .. m.name .. "-" .. tag] = ci
        end
    end
end

local spaces = utilities.strings.newrepeater("  ",-1)

function structurestags.setattributehash(fulltag,key,value) -- public hash
    if type(fulltag) == "number" then
        fulltag = taglist[fulltag]
        if fulltag then
            fulltag = fulltag[#fulltag]
        end
    end
    if fulltag then
        local ah = attributehash[fulltag] -- could be metatable magic
        if not ah then
            ah = { }
            attributehash[fulltag] = ah
        end
        ah[key] = value
    end
end


-- experiment: styles and images
--
-- officially we should convert to bp but we round anyway

local usedstyles = { }

-- /* padding      : ; */
-- /* text-justify : inter-word ; */

local documenttemplate = [[
document {
    font-size  : %s !important ;
    max-width  : %s !important ;
    text-align : %s !important ;
    hyphens    : %s !important ;
}
]]

local styletemplate = [[
%s[detail='%s'] {
    font-style   : %s ;
    font-variant : %s ;
    font-weight  : %s ;
    font-family  : %s ;
    color        : %s ;
}]]

local function allusedstyles(xmlfile)
    local result = { format("/* styles for file %s */",xmlfile) }
    --
    local bodyfont = finetuning.bodyfont
    local width    = finetuning.width
    local hyphen   = finetuning.hyphen
    local align    = finetuning.align
    --
    if not bodyfont or bodyfont == "" then
        bodyfont = "12pt"
    elseif type(bodyfont) == "number" then
        bodyfont = number.todimen(bodyfont,"pt","%ipt") or "12pt"
    end
    if not width or width == "" then
        width = "50em"
    elseif type(width) == "number" then
        width = number.todimen(width,"pt","%ipt") or "50em"
    end
    if hyphen == variables.yes then
        hyphen = "manual"
    else
        hyphen = "inherited"
    end
    if align then
        align = numbertoallign[align]
    end
    if not align then
        align = hyphens and "justify" or "inherited"
    end
    --
    result[#result+1] = format(documenttemplate,bodyfont,width,align,hyphen)
    --
    local colorspecification = xml.css.colorspecification
    local fontspecification = xml.css.fontspecification
    for element, details in sortedhash(usedstyles) do
        for detail, data in sortedhash(details) do
            local s = fontspecification(data.style)
            local c = colorspecification(data.color)
            result[#result+1] = formatters[styletemplate](element,detail,
                s.style   or "inherit",
                s.variant or "inherit",
                s.weight  or "inherit",
                s.family  or "inherit",
                c         or "inherit")
        end
    end
    return concat(result,"\n\n")
end

local usedimages = { }

local imagetemplate = [[
%s[id="%s"] {
    display           : block ;
    background-image  : url(%s) ;
    background-size   : 100%% auto ;
    background-repeat : no-repeat ;
    width             : %s ;
    height            : %s ;
}]]

local function allusedimages(xmlfile)
    local result = { format("/* images for file %s */",xmlfile) }
    for element, details in sortedhash(usedimages) do
        for detail, data in sortedhash(details) do
            local name = data.name
            if file.suffix(name) == "pdf" then
                -- temp hack .. we will have a remapper
                name = file.replacesuffix(name,"svg")
            end
            result[#result+1] = formatters[imagetemplate](element,detail,name,data.width,data.height)
        end
    end
    return concat(result,"\n\n")
end

local function uniqueusedimages()
    local unique = { }
    for element, details in next, usedimages do
        for detail, data in next, details do
            local name = data.name
            if file.suffix(name) == "pdf" then
                unique[file.replacesuffix(name,"svg")] = name
            else
                unique[name] = name
            end
        end
    end
    return unique
end

--

properties.vspace = { export = "break",     nature = "display" }
----------------- = { export = "pagebreak", nature = "display" }

local function makebreaklist(list)
    nofbreaks = nofbreaks + 1
    local t = { }
    if list then
        for i=1,#list do
            t[i] = list[i]
        end
    end
    t[#t+1] = "break-" .. nofbreaks -- maybe no number
    return t
end

local breakattributes = {
    type = "collapse"
}

local function makebreaknode(attributes) -- maybe no fulltag
    nofbreaks = nofbreaks + 1
    return {
        tg         = "break",
        fulltag    = "break-" .. nofbreaks,
        n          = nofbreaks,
        element    = "break",
        nature     = "display",
        attributes = attributes or nil,
     -- data       = { }, -- not needed
     -- attribute  = 0, -- not needed
     -- parnumber  = 0,
    }
end

local fields = { "title", "subtitle", "author", "keywords" }

local function checkdocument(root)
    local data = root.data
    if data then
        for i=1,#data do
            local di = data[i]
            local tg = di.tg
            if tg == "noexport" then
                local ud = userdata[di.fulltag]
                local comment = ud and ud.comment
                if comment then
                    di.element = "comment"
                    di.data = { { content = comment } }
                    ud.comment = nil
                else
                    data[i] = false
                 -- di.element = ""
                 -- di.data = nil
                end
            elseif di.content then
                -- okay
            elseif tg == "ignore" then
                di.element = ""
                checkdocument(di)
            else
                checkdocument(di) -- new, else no noexport handling
            end
        end
    end
end

function extras.document(result,element,detail,n,fulltag,di)
    result[#result+1] = format(" language=%q",languagenames[texgetcount("mainlanguagenumber")])
    if not less_state then
        result[#result+1] = format(" file=%q",tex.jobname)
        result[#result+1] = format(" date=%q",os.date())
        result[#result+1] = format(" context=%q",environment.version)
        result[#result+1] = format(" version=%q",exportversion)
        result[#result+1] = format(" xmlns:m=%q","http://www.w3.org/1998/Math/MathML")
        local identity = interactions.general.getidentity()
        for i=1,#fields do
            local key   = fields[i]
            local value = identity[key]
            if value and value ~= "" then
                result[#result+1] = formatters[" %s=%q"](key,value)
            end
        end
    end
    checkdocument(di)
end

local itemgroups = { }

function structurestags.setitemgroup(current,packed,symbol)
    itemgroups[detailedtag("itemgroup",current)] = {
        packed = packed,
        symbol = symbol,
    }
end

function extras.itemgroup(result,element,detail,n,fulltag,di)
    local hash = itemgroups[fulltag]
    if hash then
        local v = hash.packed
        if v then
            result[#result+1] = " packed='yes'"
        end
        local v = hash.symbol
        if v then
            result[#result+1] = attribute("symbol",v)
        end
    end
end

local synonyms = { }

function structurestags.setsynonym(current,tag)
    synonyms[detailedtag("synonym",current)] = tag
end

function extras.synonym(result,element,detail,n,fulltag,di)
    local tag = synonyms[fulltag]
    if tag then
        result[#result+1] = formatters[" tag='%s'"](tag)
    end
end

local sortings = { }

function structurestags.setsorting(current,tag)
    sortings[detailedtag("sorting",current)] = tag
end

function extras.sorting(result,element,detail,n,fulltag,di)
    local tag = sortings[fulltag]
    if tag then
        result[#result+1] = formatters[" tag='%s'"](tag)
    end
end

usedstyles.highlight = { }

function structurestags.sethighlight(current,style,color) -- we assume global styles
    usedstyles.highlight[current] = {
        style = style, -- xml.css.fontspecification(style),
        color = color, -- xml.css.colorspec(color),
    }
end

local descriptions = { }
local symbols      = { }
local linked       = { }

function structurestags.setdescription(tag,n)
    local nd = structures.notes.get(tag,n) -- todo: use listdata instead
    if nd then
        local references = nd.references
        descriptions[references and references.internal] = detailedtag("description",tag)
    end
end

function structurestags.setdescriptionsymbol(tag,n)
    local nd = structures.notes.get(tag,n) -- todo: use listdata instead
    if nd then
        local references = nd.references
        symbols[references and references.internal] = detailedtag("descriptionsymbol",tag)
    end
end

function finalizers.descriptions(tree)
    local n = 0
    for id, tag in next, descriptions do
        local sym = symbols[id]
        if sym then
            n = n + 1
            linked[tag] = n
            linked[sym] = n
        end
    end
end

function extras.description(result,element,detail,n,fulltag,di)
    local id = linked[fulltag]
    if id then
        result[#result+1] = formatters[" insert='%s'"](id) -- maybe just fulltag
    end
end

function extras.descriptionsymbol(result,element,detail,n,fulltag,di)
    local id = linked[fulltag]
    if id then
        result[#result+1] = formatters[" insert='%s'"](id)
    end
end

usedimages.image = { }

function structurestags.setfigure(name,page,width,height)
    usedimages.image[detailedtag("image")] = {
        name   = name,
        page   = page,
        width  = number.todimen(width, "cm","%0.3Fcm"),
        height = number.todimen(height,"cm","%0.3Fcm"),
    }
end

function extras.image(result,element,detail,n,fulltag,di)
    local data = usedimages.image[fulltag]
    if data then
        result[#result+1] = attribute("name",data.name)
        if tonumber(data.page) > 1 then
            result[#result+1] = formatters[" page='%s'"](data.page)
        end
        result[#result+1] = formatters[" id='%s' width='%s' height='%s'"](fulltag,data.width,data.height)
    end
end

local combinations = { }

function structurestags.setcombination(nx,ny)
    combinations[detailedtag("combination")] = {
        nx = nx,
        ny = ny,
    }
end

function extras.combination(result,element,detail,n,fulltag,di)
    local data = combinations[fulltag]
    if data then
        result[#result+1] = formatters[" nx='%s' ny='%s'"](data.nx,data.ny)
    end
end

-- quite some code deals with exporting references  --

local evaluators = { }
local specials   = { }

evaluators.inner = function(result,var)
    local inner = var.inner
    if inner then
        result[#result+1] = attribute("location",inner)
    end
end

evaluators.outer = function(result,var)
    local file, url = references.checkedfileorurl(var.outer,var.outer)
    if url then
        result[#result+1] = attribute("url",url)
    elseif file then
        result[#result+1] = attribute("file",file)
    end
end

evaluators["outer with inner"] = function(result,var)
    local file = references.checkedfile(var.f)
    if file then
        result[#result+1] = attribute("file",file)
    end
    local inner = var.inner
    if inner then
        result[#result+1] = attribute("location",inner)
    end
end

evaluators.special = function(result,var)
    local handler = specials[var.special]
    if handler then
        handler(result,var)
    end
end

evaluators["special outer with operation"]     = evaluators.special
evaluators["special operation"]                = evaluators.special
evaluators["special operation with arguments"] = evaluators.special

function specials.url(result,var)
    local url = references.checkedurl(var.operation)
    if url then
        result[#result+1] = attribute("url",url)
    end
end

function specials.file(result,var)
    local file = references.checkedfile(var.operation)
    if file then
        result[#result+1] = attribute("file",file)
    end
end

function specials.fileorurl(result,var)
    local file, url = references.checkedfileorurl(var.operation,var.operation)
    if url then
        result[#result+1] = attribute("url",url)
    elseif file then
        result[#result+1] = attribute("file",file)
    end
end

function specials.internal(result,var)
    local internal = references.checkedurl(var.operation)
    if internal then
        result[#result+1] = formatters[" location='aut:%s'"](internal)
    end
end

local referencehash = { }

local function adddestination(result,references) -- todo: specials -> exporters and then concat
    if references then
        local reference = references.reference
        if reference and reference ~= "" then
            local prefix = references.prefix
            if prefix and prefix ~= "" then
                result[#result+1] = formatters[" prefix='%s'"](prefix)
            end
            result[#result+1] = formatters[" destination='%s'"](reference)
            for i=1,#references do
                local r = references[i]
                local e = evaluators[r.kind]
                if e then
                    e(result,r)
                end
            end
        end
    end
end

local function addreference(result,references)
    if references then
        local reference = references.reference
        if reference and reference ~= "" then
            local prefix = references.prefix
            if prefix and prefix ~= "" then
                result[#result+1] = formatters[" prefix='%s'"](prefix)
            end
            result[#result+1] = formatters[" reference='%s'"](reference)
        end
        local internal = references.internal
        if internal and internal ~= "" then
            result[#result+1] = formatters[" location='aut:%s'"](internal)
        end
    end
end

function extras.link(result,element,detail,n,fulltag,di)
    -- for instance in lists a link has nested elements and no own text
    local reference = referencehash[fulltag]
    if reference then
        adddestination(result,structures.references.get(reference))
        return true
    else
        local data = di.data
        if data then
            for i=1,#data do
                local di = data[i]
                if di then
                    local fulltag = di.fulltag
                    if fulltag and extras.link(result,element,detail,n,fulltag,di) then
                        return true
                    end
                end
            end
        end
    end
end

-- no settings, as these are obscure ones

local automathrows   = true  directives.register("backend.export.math.autorows",   function(v) automathrows   = v end)
local automathapply  = true  directives.register("backend.export.math.autoapply",  function(v) automathapply  = v end)
local automathnumber = true  directives.register("backend.export.math.autonumber", function(v) automathnumber = v end)
local automathstrip  = true  directives.register("backend.export.math.autostrip",  function(v) automathstrip  = v end)

local functions      = mathematics.categories.functions

local function collapse(di,i,data,ndata,detail,element)
    local collapsing = di.data
    if data then
        di.element = element
        di.detail = nil
        i = i + 1
        while i <= ndata do
            local dn = data[i]
            if dn.detail == detail then
                collapsing[#collapsing+1] = dn.data[1]
                dn.skip = "ignore"
                i = i + 1
            else
                break
            end
        end
    end
    return i
end

local function collapse_mn(di,i,data,ndata)
    local collapsing = di.data
    if data then
        i = i + 1
        while i <= ndata do
            local dn = data[i]
            local tg = dn.tg
            if tg == "mn" then
                collapsing[#collapsing+1] = dn.data[1]
                dn.skip = "ignore"
                i = i + 1
            elseif tg == "mo" then
                local d = dn.data[1]
                if d == "." then
                    collapsing[#collapsing+1] = d
                    dn.skip = "ignore"
                    i = i + 1
                else
                    break
                end
            else
                break
            end
        end
    end
    return i
end

-- maybe delay __i__ till we need it

local apply_function = {
    {
        element = "mo",
     -- comment = "apply function",
     -- data    = { utfchar(0x2061) },
        data    = { "&#x2061;" },
        nature  = "mixed",
    }
}

local functioncontent = { }

setmetatableindex(functioncontent,function(t,k)
    local v = { { content = k } }
    t[k] = v
    return v
end)

local function checkmath(root) -- we can provide utf.toentities as an option
    local data = root.data
    if data then
        local ndata = #data
        local roottg = root.tg
        if roottg == "msubsup" then
            local nucleus, superscript, subscript
            for i=1,ndata do
                local di = data[i]
                if not di then
                    -- weird
                elseif di.content then
                    -- text
                elseif not nucleus then
                    nucleus = i
                elseif not superscript then
                    superscript = i
                elseif not subscript then
                    subscript = i
                else
                    -- error
                end
            end
            if superscript and subscript then
                local sup, sub = data[superscript], data[subscript]
                data[superscript], data[subscript] = sub, sup
             -- sub.__o__, sup.__o__ = subscript, superscript
                sub.__i__, sup.__i__ = superscript, subscript
            end
        elseif roottg == "mfenced" then
            local new, n = { }, 0
            local attributes = { }
            root.attributes = attributes
            for i=1,ndata do
                local di = data[i]
                if not di then
                    -- weird
                elseif di.content then
                    n = n + 1
                    new[n] = di
                else
                    local tg = di.tg
                    if tg == "mleft" then
                        attributes.left   = tostring(di.data[1].data[1].content)
                    elseif tg == "mmiddle" then
                        attributes.middle = tostring(di.data[1].data[1].content)
                    elseif tg == "mright" then
                        attributes.right  = tostring(di.data[1].data[1].content)
                    else
                        n = n + 1
                        di.__i__ = n
                        new[n] = di
                    end
                end
            end
            root.data = new
            ndata = n
        end
        if ndata == 0 then
            return
        elseif ndata == 1 then
            local d = data[1]
            if not d then
                return
            elseif d.content then
                return
            elseif #root.data == 1 then
                local tg = d.tg
                if automathrows and roottg == "mrow" then
                    -- maybe just always ! check spec first
                    if tg == "mrow" or tg == "mfenced" or tg == "mfrac" or tg == "mroot" or tg == "msqrt"then
                        root.skip = "comment"
                    elseif tg == "mo" then
                        root.skip = "comment"
                    end
                elseif roottg == "mo" then
                    if tg == "mo" then
                        root.skip = "comment"
                    end
                end
            end
        end
        local i = 1
        while i <= ndata do                   -- -- -- TOO MUCH NESTED CHECKING -- -- --
            local di = data[i]
            if di and not di.content then
                local tg = di.tg
                local detail = di.detail
                if tg == "math" then
                 -- di.element = "mrow" -- when properties
                    di.skip = "comment"
                    checkmath(di)
                    i = i + 1
                elseif tg == "mover" or tg == "munder" or tg == "munderover" then
                    if detail == "accent" then
                        di.attributes = { accent = "true" }
                        di.detail = nil
                    end
                    checkmath(di)
                    i = i + 1
                elseif tg == "mroot" then
                    if #di.data == 1 then
                        -- else firefox complains
                        di.element = "msqrt"
                    end
                    checkmath(di)
                    i = i + 1
                elseif tg == "break" then
                    di.skip = "comment"
                    i = i + 1
                elseif tg == "mrow" and detail then
                    di.detail = nil
                    checkmath(di)
                    di = {
                        element    = "maction",
                        nature     = "display",
                        attributes = { actiontype = detail },
                        data       = { di },
                        n          = 0,
                    }
                    data[i] = di
                    i = i + 1
                elseif detail then
                 -- no checkmath(di) here
                    local category = tonumber(detail) or 0
                    if category == 1 then -- mo
                        i = collapse(di,i,data,ndata,detail,"mo")
                    elseif category == 2 then -- mi
                        i = collapse(di,i,data,ndata,detail,"mi")
                    elseif category == 3 then -- mn
                        i = collapse(di,i,data,ndata,detail,"mn")
                    elseif category == 4 then -- ms
                        i = collapse(di,i,data,ndata,detail,"ms")
                    elseif category >= 1000 then
                        local apply = category >= 2000
                        if apply then
                            category = category - 1000
                        end
                        if tg == "mi" then -- function
                            if roottg == "mrow" then
                                root.skip = "comment"
                                root.element = "function"
                            end
                            i = collapse(di,i,data,ndata,detail,"mi")
                            local tag = functions[category]
                            if tag then
                                di.data = functioncontent[tag]
                            end
                            if apply then
                                di.after = apply_function
                            elseif automathapply then -- make function
                                local following
                                if i <= ndata then
                                    -- normally not the case
                                    following = data[i]
                                else
                                    local parent = di.__p__ -- == root
                                    if parent.tg == "mrow" then
                                        parent = parent.__p__
                                    end
                                    local index = parent.__i__
                                    following = parent.data[index+1]
                                end
                                if following then
                                    local tg = following.tg
                                    if tg == "mrow" or tg == "mfenced" then -- we need to figure out the right condition
                                        di.after = apply_function
                                    end
                                end
                            end
                        else -- some problem
                            checkmath(di)
                            i = i + 1
                        end
                    else
                        checkmath(di)
                        i = i + 1
                    end
                elseif automathnumber and tg == "mn" then
                    checkmath(di)
                    i = collapse_mn(di,i,data,ndata)
                else
                    checkmath(di)
                    i = i + 1
                end
            else -- can be string or boolean
                if parenttg ~= "mtext" and di == " " then
                    data[i] = false
                end
                i = i + 1
            end
        end
    end
end

function stripmath(di)
    if not di then
        --
    elseif di.content then
        return di
    else
        local tg = di.tg
        if tg == "mtext" or tg == "ms" then
            return di
        else
            local data = di.data
            local ndata = #data
            local n = 0
            for i=1,ndata do
                local di = data[i]
                if di and not di.content then
                    di = stripmath(di)
                end
                if di then
                    local content = di.content
                    if not content then
                        n = n + 1
                        di.__i__ = n
                        data[n] = di
                    elseif content == " " or content == "" then
                        -- skip
                    else
                        n = n + 1
                        data[n] = di
                    end
                end
            end
            for i=ndata,n+1,-1 do
                data[i] = nil
            end
            if #data > 0 then
                return di
            end
        end
    end
end

function checks.math(di)
    local hash = attributehash[di.fulltag]
    local mode = (hash and hash.mode) == "display" and "block" or "inline"
    di.attributes = {
        display = mode
    }
    -- can be option if needed:
    if mode == "inline" then
        di.nature = "mixed" -- else spacing problem (maybe inline)
    else
        di.nature = "display"
    end
    if automathstrip then
        stripmath(di)
    end
    checkmath(di)
end

local a, z, A, Z = 0x61, 0x7A, 0x41, 0x5A

function extras.mi(result,element,detail,n,fulltag,di) -- check with content
    local str = di.data[1].content
    if str and sub(str,1,1) ~= "&" then -- hack but good enough (maybe gsub op eerste)
        for v in utfvalues(str) do
            if (v >= a and v <= z) or (v >= A and v <= Z) then
                local a = di.attributes
                if a then
                    a.mathvariant = "normal"
                else
                    di.attributes = { mathvariant = "normal" }
                end
            end
        end
    end
end

function extras.section(result,element,detail,n,fulltag,di)
    local data = listdata[fulltag]
    if data then
        addreference(result,data.references)
        return true
    else
        local data = di.data
        if data then
            for i=1,#data do
                local di = data[i]
                if di then
                    local ft = di.fulltag
                    if ft and extras.section(result,element,detail,n,ft,di) then
                        return true
                    end
                end
            end
        end
    end
end

function extras.float(result,element,detail,n,fulltag,di)
    local data = listdata[fulltag]
    if data then
        addreference(result,data.references)
        return true
    else
        local data = di.data
        if data then
            for i=1,#data do
                local di = data[i]
                if di and extras.section(result,element,detail,n,di.fulltag,di) then
                    return true
                end
            end
        end
    end
end

local tabledata = { }

function structurestags.settablecell(rows,columns,align)
    if align > 0 or rows > 1 or columns > 1 then
        tabledata[detailedtag("tablecell")] = {
            rows    = rows,
            columns = columns,
            align   = align,
        }
    end
end

function extras.tablecell(result,element,detail,n,fulltag,di)
    local hash = tabledata[fulltag]
    if hash then
        local v = hash.columns
        if v and v > 1 then
            result[#result+1] = formatters[" columns='%s'"](v)
        end
        local v = hash.rows
        if v and v > 1 then
            result[#result+1] = formatters[" rows='%s'"](v)
        end
        local v = hash.align
        if not v or v == 0 then
            -- normal
        elseif v == 1 then -- use numbertoalign here
            result[#result+1] = " align='flushright'"
        elseif v == 2 then
            result[#result+1] = " align='middle'"
        elseif v == 3 then
            result[#result+1] = " align='flushleft'"
        end
    end
end

local tabulatedata = { }

function structurestags.settabulatecell(align)
    if align > 0 then
        tabulatedata[detailedtag("tabulatecell")] = {
            align = align,
        }
    end
end

local function hascontent(data)
    for i=1,#data do
        local di = data[i]
        if not di then
            --
        elseif di.content then
            return true
        else
            local d = di.data
            if d and #d > 0 and hascontent(d) then
                return true
            end
        end
    end
end

function extras.tabulate(result,element,detail,n,fulltag,di)
    local data = di.data
    for i=1,#data do
        local di = data[i]
        if di.tg == "tabulaterow" and not hascontent(di.data) then
            di.element = "" -- or simply remove
        end
    end
end

function extras.tabulatecell(result,element,detail,n,fulltag,di)
    local hash = tabulatedata[fulltag]
    if hash then
        local v = hash.align
        if not v or v == 0 then
            -- normal
        elseif v == 1 then
            result[#result+1] = " align='flushleft'"
        elseif v == 2 then
            result[#result+1] = " align='flushright'"
        elseif v == 3 then
            result[#result+1] = " align='middle'"
        end
    end
end

-- flusher

local linedone    = false -- can go ... we strip newlines anyway
local inlinedepth = 0

-- todo: #result -> nofresult

local function emptytag(result,element,nature,depth,di) -- currently only break but at some point
    local a = di.attributes                             -- we might add detail etc
    if a then -- happens seldom
        if linedone then
            result[#result+1] = formatters["%w<%s"](depth,namespaced[element])
        else
            result[#result+1] = formatters["\n%w<%s"](depth,namespaced[element])
        end
        for k, v in next, a do
            result[#result+1] = formatters[" %s=%q"](k,v)
        end
        result[#result+1] = "/>\n"
    else
        if linedone then
            result[#result+1] = formatters["%w<%s/>\n"](depth,namespaced[element])
        else
            result[#result+1] = formatters["\n%w<%s/>\n"](depth,namespaced[element])
        end
    end
    linedone = false
end

local function begintag(result,element,nature,depth,di,skip)
    -- if needed we can use a local result with xresult
    local detail  = di.detail
    local n       = di.n
    local fulltag = di.fulltag
    local comment = di.comment
    if nature == "inline" then
        linedone = false
        inlinedepth = inlinedepth + 1
        if show_comment and comment then
            result[#result+1] = formatters["<!-- %s -->"](comment)
        end
    elseif nature == "mixed" then
        if inlinedepth > 0 then
            if show_comment and comment then
                result[#result+1] = formatters["<!-- %s -->"](comment)
            end
        elseif linedone then
            result[#result+1] = spaces[depth]
            if show_comment and comment then
                result[#result+1] = formatters["<!-- %s -->"](comment)
            end
        else
            result[#result+1] = formatters["\n%w"](depth)
            linedone = false
            if show_comment and comment then
                result[#result+1] = formatters["<!-- %s -->\n%w"](comment,depth)
            end
        end
        inlinedepth = inlinedepth + 1
    else
        if inlinedepth > 0 then
            if show_comment and comment then
                result[#result+1] = formatters["<!-- %s -->"](comment)
            end
        elseif linedone then
            result[#result+1] = spaces[depth]
            if show_comment and comment then
                result[#result+1] = formatters["<!-- %s -->"](comment)
            end
        else
            result[#result+1] = formatters["\n%w"](depth) -- can introduced extra line in mixed+mixed (filtered later on)
            linedone = false
            if show_comment and comment then
                result[#result+1] = formatters["<!-- %s -->\n%w"](comment,depth)
            end
        end
    end
    if skip == "comment" then
        if show_comment then
            result[#result+1] = formatters["<!-- begin %s -->"](namespaced[element])
        end
    elseif skip then
        -- ignore
    else
        result[#result+1] = formatters["<%s"](namespaced[element])
        if detail then
            result[#result+1] = formatters[" detail=%q"](detail)
        end
        if indexing and n then
            result[#result+1] = formatters[" n=%q"](n)
        end
        local extra = extras[element]
        if extra then
            extra(result,element,detail,n,fulltag,di)
        end
        local u = userdata[fulltag]
        if u then
            for k, v in next, u do
                result[#result+1] = formatters[" %s=%q"](k,v)
            end
        end
        local a = di.attributes
        if a then
            for k, v in next, a do
                result[#result+1] = formatters[" %s=%q"](k,v)
            end
        end
        result[#result+1] = ">"
    end
    if inlinedepth > 0 then
    elseif nature == "display" then
        result[#result+1] = "\n"
        linedone = true
    end
    used[element][detail or ""] = nature -- for template css
    local metadata = tagmetadata[fulltag]
    if metadata then
        if not linedone then
            result[#result+1] = "\n"
            linedone = true
        end
        result[#result+1] = formatters["%w<metadata>\n"](depth)
        for k, v in table.sortedpairs(metadata) do
            v = entityremapper(v)
            result[#result+1] = formatters["%w<metavariable name=%q>%s</metavariable>\n"](depth+1,k,v)
        end
        result[#result+1] = formatters["%w</metadata>\n"](depth)
    end
end

local function endtag(result,element,nature,depth,skip)
    if nature == "display" then
        if inlinedepth == 0 then
            if not linedone then
                result[#result+1] = "\n"
            end
            if skip == "comment" then
                if show_comment then
                    result[#result+1] = formatters["%w<!-- end %s -->\n"](depth,namespaced[element])
                end
            elseif skip then
                -- ignore
            else
                result[#result+1] = formatters["%w</%s>\n"](depth,namespaced[element])
            end
            linedone = true
        else
            if skip == "comment" then
                if show_comment then
                    result[#result+1] = formatters["<!-- end %s -->"](namespaced[element])
                end
            elseif skip then
                -- ignore
            else
                result[#result+1] = formatters["</%s>"](namespaced[element])
            end
        end
    else
        inlinedepth = inlinedepth - 1
        if skip == "comment" then
            if show_comment then
                result[#result+1] = formatters["<!-- end %s -->"](namespaced[element])
            end
        elseif skip then
            -- ignore
        else
            result[#result+1] = formatters["</%s>"](namespaced[element])
        end
        linedone = false
    end
end

local function flushtree(result,data,nature,depth)
    depth = depth + 1
    local nofdata = #data
    for i=1,nofdata do
        local di = data[i]
        if not di then -- hm, di can be string
            -- whatever
        elseif di.content then
            -- already has breaks
            local content = entityremapper(di.content)
            if i == nofdata and sub(content,-1) == "\n" then -- move check
                -- can be an end of line in par but can also be the last line
                if trace_spacing then
                    result[#result+1] = formatters["<c n='%s'>%s</c>"](di.parnumber or 0,sub(content,1,-2))
                else
                    result[#result+1] = sub(content,1,-2)
                end
                result[#result+1] = " "
            else
                if trace_spacing then
                    result[#result+1] = formatters["<c n='%s'>%s</c>"](di.parnumber or 0,content)
                else
                    result[#result+1] = content
                end
            end
            linedone = false
        elseif not di.collapsed then -- ignore collapsed data (is appended, reconstructed par)
            local element = di.element
            if not element then
                -- skip
            elseif element == "break" then -- or element == "pagebreak"
                emptytag(result,element,nature,depth,di)
            elseif element == "" or di.skip == "ignore" then
                -- skip
            else
                if di.before then
                    flushtree(result,di.before,nature,depth)
                end
                local natu = di.nature
                local skip = di.skip
                if di.breaknode then
                    emptytag(result,"break","display",depth,di)
                end
                begintag(result,element,natu,depth,di,skip)
                flushtree(result,di.data,natu,depth)
             -- if sub(result[#result],-1) == " " and natu ~= "inline" then
             --     result[#result] = sub(result[#result],1,-2)
             -- end
                endtag(result,element,natu,depth,skip)
                if di.after then
                    flushtree(result,di.after,nature,depth)
                end
            end
        end
    end
end

local function breaktree(tree,parent,parentelement) -- also removes double breaks
    local data = tree.data
    if data then
        local nofdata = #data
        local prevelement
        local prevnature
        local prevparnumber
        local newdata = { }
        local nofnewdata = 0
        for i=1,nofdata do
            local di = data[i]
            if not di then
                -- skip
            elseif di.content then
                local parnumber = di.parnumber
                if prevnature == "inline" and prevparnumber and prevparnumber ~= parnumber then
                    nofnewdata = nofnewdata + 1
                    if trace_spacing then
                        newdata[nofnewdata] = makebreaknode { type = "a", p = prevparnumber, n = parnumber }
                    else
                        newdata[nofnewdata] = makebreaknode()
                    end
                end
                prevelement = nil
                prevnature = "inline"
                prevparnumber = parnumber
                nofnewdata = nofnewdata + 1
                newdata[nofnewdata] = di
            elseif not di.collapsed then
                local element = di.element
                if element == "break" then -- or element == "pagebreak"
                    if prevelement == "break" then
                        di.element = ""
                    end
                    prevelement = element
                    prevnature = "display"
                elseif element == "" or di.skip == "ignore" then
                    -- skip
                else
                    local nature = di.nature
                    local parnumber = di.parnumber
                    if prevnature == "inline" and nature == "inline" and prevparnumber and prevparnumber ~= parnumber then
                        nofnewdata = nofnewdata + 1
                        if trace_spacing then
                            newdata[nofnewdata] = makebreaknode { type = "b", p = prevparnumber, n = parnumber }
                        else
                            newdata[nofnewdata] = makebreaknode()
                        end
                    end
                    prevnature = nature
                    prevparnumber = parnumber
                    prevelement = element
                    breaktree(di,tree,element)
                end
                nofnewdata = nofnewdata + 1
                newdata[nofnewdata] = di
            else
                local nature = di.nature
                local parnumber = di.parnumber
                if prevnature == "inline" and nature == "inline" and prevparnumber and prevparnumber ~= parnumber then
                    nofnewdata = nofnewdata + 1
                    if trace_spacing then
                        newdata[nofnewdata] = makebreaknode { type = "c", p = prevparnumber, n = parnumber }
                    else
                        newdata[nofnewdata] = makebreaknode()
                    end
                end
                prevnature = nature
                prevparnumber = parnumber
                nofnewdata = nofnewdata + 1
                newdata[nofnewdata] = di
            end
        end
        tree.data = newdata
    end
end

-- also tabulaterow reconstruction .. maybe better as a checker
-- i.e cell attribute

local function collapsetree()
    for tag, trees in next, treehash do
        local d = trees[1].data
        if d then
            local nd = #d
            if nd > 0 then
                for i=2,#trees do
                    local currenttree = trees[i]
                    local currentdata = currenttree.data
                    local currentpar = currenttree.parnumber
                    local previouspar = trees[i-1].parnumber
                    currenttree.collapsed = true
                    -- is the next ok?
                    if previouspar == 0 or not (di and di.content) then
                        previouspar = nil -- no need anyway so no further testing needed
                    end
                    for j=1,#currentdata do
                        local cd = currentdata[j]
                        if not cd or cd == "" then
                            -- skip
                        elseif cd.content then
                            if not currentpar then
                                -- add space ?
                            elseif not previouspar then
                                -- add space ?
                            elseif currentpar ~= previouspar then
                                nd = nd + 1
                                if trace_spacing then
                                    d[nd] = makebreaknode { type = "d", p = previouspar, n = currentpar }
                                else
                                    d[nd] = makebreaknode()
                                end
                            end
                            previouspar = currentpar
                            nd = nd + 1
                            d[nd] = cd
                        else
                            nd = nd + 1
                            d[nd] = cd
                        end
                        currentdata[j] = false
                    end
                end
            end
        end
    end
end

local function finalizetree(tree)
    for _, finalizer in next, finalizers do
        finalizer(tree)
    end
end

local function indextree(tree)
    local data = tree.data
    if data then
        local n, new = 0, { }
        for i=1,#data do
            local d = data[i]
            if not d then
                -- skip
            elseif d.content then
                n = n + 1
                new[n] = d
            elseif not d.collapsed then
                n = n + 1
                d.__i__ = n
                d.__p__ = tree
                indextree(d)
                new[n] = d
            end
        end
        tree.data = new
    end
end

local function checktree(tree)
    local data = tree.data
    if data then
        for i=1,#data do
            local d = data[i]
            if type(d) == "table" then
                local check = checks[d.tg]
                if check then
                    check(d)
                end
                checktree(d)
            end
        end
    end
end

-- collector code

local function push(fulltag,depth)
    local tag, n = lpegmatch(dashsplitter,fulltag)
    local tg, detail = lpegmatch(colonsplitter,tag)
    local element, nature
    if detail then
        local pd = properties[tag]
        local pt = properties[tg]
        element = pd and pd.export or pt and pt.export or tg
        nature  = pd and pd.nature or pt and pt.nature or defaultnature
    else
        local p = properties[tg]
        element = p and p.export or tg
        nature  = p and p.nature or "inline"
    end
    local treedata = tree.data
    local t = {
        tg         = tg,
        fulltag    = fulltag,
        detail     = detail,
        n          = tonumber(n), -- more efficient
        element    = element,
        nature     = nature,
        data       = { },
        attribute  = currentattribute,
        parnumber  = currentparagraph,
    }
    treedata[#treedata+1] = t
    currentdepth = currentdepth + 1
    nesting[currentdepth] = fulltag
    treestack[currentdepth] = tree
    if trace_export then
        if detail and detail ~= "" then
            report_export("%w<%s trigger=%a paragraph=%a index=%a detail=%a>",currentdepth-1,fulltag,currentattribute or 0,currentparagraph or 0,#treedata,detail)
        else
            report_export("%w<%s trigger=%a paragraph=%a index=%a>",currentdepth-1,fulltag,currentattribute or 0,currentparagraph or 0,#treedata)
        end
    end
    tree = t
    if tg == "break" then
        -- no need for this
    else
        local h = treehash[fulltag]
        if h then
            h[#h+1] = t
        else
            treehash[fulltag] = { t }
        end
    end
end

local function pop()
    local top = nesting[currentdepth]
    tree = treestack[currentdepth]
    currentdepth = currentdepth - 1
    if trace_export then
        if top then
            report_export("%w</%s>",currentdepth,top)
        else
            report_export("</%s>",top)
        end
    end
end

local function continueexport()
    if nofcurrentcontent > 0 then
        if trace_export then
            report_export("%w<!-- injecting pagebreak space -->",currentdepth)
        end
        nofcurrentcontent = nofcurrentcontent + 1
        currentcontent[nofcurrentcontent] = " " -- pagebreak
    end
end

local function pushentry(current)
    if current then
        if restart then
            continueexport()
            restart = false
        end
        local newdepth = #current
        local olddepth = currentdepth
        if trace_export then
            report_export("%w<!-- moving from depth %s to %s (%s) -->",currentdepth,olddepth,newdepth,current[newdepth])
        end
        if olddepth <= 0 then
            for i=1,newdepth do
                push(current[i],i)
            end
        else
            local difference
            if olddepth < newdepth then
                for i=1,olddepth do
                    if current[i] ~= nesting[i] then
                        difference = i
                        break
                    end
                end
            else
                for i=1,newdepth do
                    if current[i] ~= nesting[i] then
                        difference = i
                        break
                    end
                end
            end
            if difference then
                for i=olddepth,difference,-1 do
                    pop()
                end
                for i=difference,newdepth do
                    push(current[i],i)
                end
            elseif newdepth > olddepth then
                for i=olddepth+1,newdepth do
                    push(current[i],i)
                end
            elseif newdepth < olddepth then
                for i=olddepth,newdepth,-1 do
                    pop()
                end
            elseif trace_export then
                report_export("%w<!-- staying at depth %s (%s) -->",currentdepth,newdepth,nesting[newdepth] or "?")
            end
        end
        return olddepth, newdepth
    end
end

local function pushcontent(oldparagraph,newparagraph)
    if nofcurrentcontent > 0 then
        if oldparagraph then
            if currentcontent[nofcurrentcontent] == "\n" then
                if trace_export then
                    report_export("%w<!-- removing newline -->",currentdepth)
                end
                nofcurrentcontent = nofcurrentcontent - 1
            end
        end
        local content = concat(currentcontent,"",1,nofcurrentcontent)
        if content == "" then
            -- omit; when oldparagraph we could push, remove spaces, pop
        elseif somespace[content] and oldparagraph then
            -- omit; when oldparagraph we could push, remove spaces, pop
        else
            local olddepth, newdepth
            local list = taglist[currentattribute]
            if list then
                olddepth, newdepth = pushentry(list)
            end
            local td = tree.data
            local nd = #td
            td[nd+1] = { parnumber = oldparagraph or currentparagraph, content = content }
            if trace_export then
                report_export("%w<!-- start content with length %s -->",currentdepth,#content)
                report_export("%w%s",currentdepth,(gsub(content,"\n","\\n")))
                report_export("%w<!-- stop content -->",currentdepth)
            end
            if olddepth then
                for i=newdepth-1,olddepth,-1 do
                    pop()
                end
            end
        end
        nofcurrentcontent = 0
    end
    if oldparagraph then
        pushentry(makebreaklist(currentnesting))
        if trace_export then
            report_export("%w<!-- break added betweep paragraph %a and %a -->",currentdepth,oldparagraph,newparagraph)
        end
    end
end

local function finishexport()
    if trace_export then
        report_export("%w<!-- start finalizing -->",currentdepth)
    end
    if nofcurrentcontent > 0 then
        if somespace[currentcontent[nofcurrentcontent]] then
            if trace_export then
                report_export("%w<!-- removing space -->",currentdepth)
            end
            nofcurrentcontent = nofcurrentcontent - 1
        end
        pushcontent()
    end
    for i=currentdepth,1,-1 do
        pop()
    end
    currentcontent = { } -- we're nice and do a cleanup
    if trace_export then
        report_export("%w<!-- stop finalizing -->",currentdepth)
    end
end

-- whatsit_code localpar_code

local function collectresults(head,list) -- is last used (we also have currentattribute)
    local p
    for n in traverse_nodes(head) do
        local id = getid(n) -- 14: image, 8: literal (mp)
        if id == glyph_code then
            local at = getattr(n,a_tagged)
            if not at then
             -- we need to tag the pagebody stuff as being valid skippable
             --
             -- report_export("skipping character: %C (no attribute)",n.char)
            else
                -- we could add tonunicodes for ligatures (todo)
                local components =  getfield(n,"components")
                if components then -- we loose data
                    collectresults(components,nil)
                else
                    local c = getchar(n)
                    if last ~= at then
                        local tl = taglist[at]
                        pushcontent()
                        currentnesting = tl
                        currentparagraph = getattr(n,a_taggedpar)
                        currentattribute = at
                        last = at
                        pushentry(currentnesting)
                        if trace_export then
                            report_export("%w<!-- processing glyph %C tagged %a -->",currentdepth,c,at)
                        end
                        -- We need to intercept this here; maybe I will also move this
                        -- to a regular setter at the tex end.
                        local r = getattr(n,a_reference)
                        if r then
                            referencehash[tl[#tl]] = r -- fulltag
                        end
                        --
                    elseif last then
                        local ap = getattr(n,a_taggedpar)
                        if ap ~= currentparagraph then
                            pushcontent(currentparagraph,ap)
                            pushentry(currentnesting)
                            currentattribute = last
                            currentparagraph = ap
                        end
                        if trace_export then
                            report_export("%w<!-- processing glyph %C tagged %a) -->",currentdepth,c,last)
                        end
                    else
                        if trace_export then
                            report_export("%w<!-- processing glyph %C tagged %a) -->",currentdepth,c,at)
                        end
                    end
                    local s = getattr(n,a_exportstatus)
                    if s then
                        c = s
                    end
                    if c == 0 then
                        if trace_export then
                            report_export("%w<!-- skipping last glyph -->",currentdepth)
                        end
                    elseif c == 0x20 then
                        local a = getattr(n,a_characters)
                        nofcurrentcontent = nofcurrentcontent + 1
                        if a then
                            if trace_export then
                                report_export("%w<!-- turning last space into special space %U -->",currentdepth,a)
                            end
                            currentcontent[nofcurrentcontent] = specialspaces[a] -- special space
                        else
                            currentcontent[nofcurrentcontent] = " "
                        end
                    else
                        local fc = fontchar[getfont(n)]
                        if fc then
                            fc = fc and fc[c]
                            if fc then
                                local u = fc.tounicode
                                if u and u ~= "" then
                                    nofcurrentcontent = nofcurrentcontent + 1
                                    currentcontent[nofcurrentcontent] = utfchar(fromunicode16(u))
                                else
                                    nofcurrentcontent = nofcurrentcontent + 1
                                    currentcontent[nofcurrentcontent] = utfchar(c)
                                end
                            else -- weird, happens in hz (we really need to get rid of the pseudo fonts)
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = utfchar(c)
                            end
                        else
                            nofcurrentcontent = nofcurrentcontent + 1
                            currentcontent[nofcurrentcontent] = utfchar(c)
                        end
                    end
                end
            end
        elseif id == disc_code then -- probably too late
            if keephyphens then
                local pre = getfield(n,"pre")
                if pre and not getnext(pre) and getid(pre) == glyph_code and getchar(pre) == hyphencode then
                    nofcurrentcontent = nofcurrentcontent + 1
                    currentcontent[nofcurrentcontent] = hyphen
                end
            end
            local replace = getfield(n,"replace")
            if replace then
                collectresults(replace,nil)
            end
        elseif id == glue_code then
            -- we need to distinguish between hskips and vskips
            local ca = getattr(n,a_characters)
            if ca == 0 then
                -- skip this one ... already converted special character (node-acc)
            elseif ca then
                local a = getattr(n,a_tagged)
                if a then
                    local c = specialspaces[ca]
                    if last ~= a then
                        local tl = taglist[a]
                        if trace_export then
                            report_export("%w<!-- processing space glyph %U tagged %a case 1 -->",currentdepth,ca,a)
                        end
                        pushcontent()
                        currentnesting = tl
                        currentparagraph = getattr(n,a_taggedpar)
                        currentattribute = a
                        last = a
                        pushentry(currentnesting)
                        -- no reference check (see above)
                    elseif last then
                        local ap = getattr(n,a_taggedpar)
                        if ap ~= currentparagraph then
                            pushcontent(currentparagraph,ap)
                            pushentry(currentnesting)
                            currentattribute = last
                            currentparagraph = ap
                        end
                        if trace_export then
                            report_export("%w<!-- processing space glyph %U tagged %a case 2 -->",currentdepth,ca,last)
                        end
                    end
                    -- if somespace[currentcontent[nofcurrentcontent]] then
                    --     if trace_export then
                    --         report_export("%w<!-- removing space -->",currentdepth)
                    --     end
                    --     nofcurrentcontent = nofcurrentcontent - 1
                    -- end
                    nofcurrentcontent = nofcurrentcontent + 1
                    currentcontent[nofcurrentcontent] = c
                end
            else
                local subtype = getsubtype(n)
                if subtype == userskip_code then
                    if getfield(getfield(n,"spec"),"width") > threshold then
                        if last and not somespace[currentcontent[nofcurrentcontent]] then
                            local a = getattr(n,a_tagged)
                            if a == last then
                                if trace_export then
                                    report_export("%w<!-- injecting spacing 5a -->",currentdepth)
                                end
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = " "
                            elseif a then
                                -- e.g LOGO<space>LOGO
                                if trace_export then
                                    report_export("%w<!-- processing glue > threshold tagged %s becomes %s -->",currentdepth,last,a)
                                end
                                pushcontent()
                                if trace_export then
                                    report_export("%w<!-- injecting spacing 5b -->",currentdepth)
                                end
                                last = a
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = " "
                                currentnesting = taglist[last]
                                pushentry(currentnesting)
                                currentattribute = last
                            end
                        end
                    end
                elseif subtype == spaceskip_code or subtype == xspaceskip_code then
                    if not somespace[currentcontent[nofcurrentcontent]] then
                        local a = getattr(n,a_tagged)
                        if a == last then
                            if trace_export then
                                report_export("%w<!-- injecting spacing 7 (stay in element) -->",currentdepth)
                            end
                            nofcurrentcontent = nofcurrentcontent + 1
                            currentcontent[nofcurrentcontent] = " "
                        else
                            if trace_export then
                                report_export("%w<!-- injecting spacing 7 (end of element) -->",currentdepth)
                            end
                            last = a
                            pushcontent()
                            nofcurrentcontent = nofcurrentcontent + 1
                            currentcontent[nofcurrentcontent] = " "
                            currentnesting = taglist[last]
                            pushentry(currentnesting)
                            currentattribute = last
                        end
                    end
                elseif subtype == rightskip_code then
                    -- a line
                    if nofcurrentcontent > 0 then
                        local r = currentcontent[nofcurrentcontent]
                        if r == hyphen then
                            if not keephyphens then
                                nofcurrentcontent = nofcurrentcontent - 1
                            end
                        elseif not somespace[r] then
                            local a = getattr(n,a_tagged)
                            if a == last then
                                if trace_export then
                                    report_export("%w<!-- injecting spacing 1 (end of line, stay in element) -->",currentdepth)
                                end
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = " "
                            else
                                if trace_export then
                                    report_export("%w<!-- injecting spacing 1 (end of line, end of element) -->",currentdepth)
                                end
                                last = a
                                pushcontent()
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = " "
                                currentnesting = taglist[last]
                                pushentry(currentnesting)
                                currentattribute = last
                            end
                        end
                    end
                elseif subtype == parfillskip_code then
                    -- deal with paragaph endings (crossings) elsewhere and we quit here
                    -- as we don't want the rightskip space addition
                    return
                end
            end
        elseif id == hlist_code or id == vlist_code then
            local ai = getattr(n,a_image)
            if ai then
                local at = getattr(n,a_tagged)
                if nofcurrentcontent > 0 then
                    pushcontent()
                    pushentry(currentnesting) -- ??
                end
                pushentry(taglist[at]) -- has an index, todo: flag empty element
                if trace_export then
                    report_export("%w<!-- processing image tagged %a",currentdepth,last)
                end
                last = nil
                currentparagraph = nil
            else
                -- we need to determine an end-of-line
                local list = getlist(n)
                if list then
                    collectresults(list,n)
                end
            end
        elseif id == kern_code then
            local kern = getfield(n,"kern")
            if kern > 0 then
                local limit = threshold
                if p and getid(p) == glyph_code then
                    limit = fontquads[getfont(p)] / 4
                end
                if kern > limit then
                    if last and not somespace[currentcontent[nofcurrentcontent]] then
                        local a = getattr(n,a_tagged)
                        if a == last then
                            if not somespace[currentcontent[nofcurrentcontent]] then
                                if trace_export then
                                    report_export("%w<!-- injecting spacing 8 (kern %p) -->",currentdepth,kern)
                                end
                                nofcurrentcontent = nofcurrentcontent + 1
                                currentcontent[nofcurrentcontent] = " "
                            end
                        elseif a then
                            -- e.g LOGO<space>LOGO
                            if trace_export then
                                report_export("%w<!-- processing kern, threshold %p, tag %s => %s -->",currentdepth,limit,last,a)
                            end
                            last = a
                            pushcontent()
                            if trace_export then
                                report_export("%w<!-- injecting spacing 9 (kern %p) -->",currentdepth,kern)
                            end
                            nofcurrentcontent = nofcurrentcontent + 1
                            currentcontent[nofcurrentcontent] = " "
                            currentnesting = taglist[last]
                            pushentry(currentnesting)
                            currentattribute = last
                        end
                    end
                end
            end
        end
        p = n
    end
end

function nodes.handlers.export(head) -- hooks into the page builder
    starttiming(treehash)
    if trace_export then
        report_export("%w<!-- start flushing page -->",currentdepth)
    end
 -- continueexport()
    restart = true
    collectresults(tonut(head))
    if trace_export then
        report_export("%w<!-- stop flushing page -->",currentdepth)
    end
    stoptiming(treehash)
    return head, true
end

function builders.paragraphs.tag(head)
    noftextblocks = noftextblocks + 1
    for n in traverse_id(hlist_code,tonut(head)) do
        local subtype = getsubtype(n)
        if subtype == line_code then
            setattr(n,a_textblock,noftextblocks)
        elseif subtype == glue_code or subtype == kern_code then
            setattr(n,a_textblock,0)
        end
    end
    return false
end

-- encoding='utf-8'

local xmlpreamble = [[
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>

<!-- input filename   : %- 17s -->
<!-- processing date  : %- 17s -->
<!-- context version  : %- 17s -->
<!-- exporter version : %- 17s -->

]]

local function wholepreamble()
    return format(xmlpreamble,tex.jobname,os.date(),environment.version,exportversion)
end


local csspreamble = [[
<?xml-stylesheet type="text/css" href="%s"?>
]]

local function allusedstylesheets(xmlfile,cssfiles,files)
    local result = { }
    for i=1,#cssfiles do
        local cssfile = cssfiles[i]
        if type(cssfile) ~= "string" or cssfile == variables.yes or cssfile == "" or cssfile == xmlfile then
            cssfile = file.replacesuffix(xmlfile,"css")
        else
            cssfile = file.addsuffix(cssfile,"css")
        end
        files[#files+1] = cssfile
        report_export("adding css reference '%s'",cssfile)
        result[#result+1] = format(csspreamble,cssfile)
    end
    return concat(result)
end

local e_template = [[
%s {
    display: %s ;
}]]

local d_template = [[
%s[detail=%s] {
    display: %s ;
}]]

local displaymapping = {
    inline  = "inline",
    display = "block",
    mixed   = "inline",
}

local function allusedelements(xmlfile)
    local result = { format("/* template for file %s */",xmlfile) }
    for element, details in sortedhash(used) do
        result[#result+1] = format("/* category: %s */",element)
        for detail, nature in sortedhash(details) do
            local d = displaymapping[nature or "display"] or "block"
            if detail == "" then
                result[#result+1] = formatters[e_template](element,d)
            else
                result[#result+1] = formatters[d_template](element,detail,d)
            end
        end
    end
    return concat(result,"\n\n")
end

local function allcontent(tree)
    local result  = { }
    flushtree(result,tree.data,"display",0) -- we need to collect images
    result = concat(result)
    result = gsub(result,"\n *\n","\n")
    result = gsub(result,"\n +([^< ])","\n%1")
    return result
end

-- local xhtmlpreamble = [[
--     <!DOCTYPE html PUBLIC
--         "-//W3C//DTD XHTML 1.1 plus MathML 2.0 plus SVG 1.1//EN"
--         "http://www.w3.org/2002/04/xhtml-math-svg/xhtml-math-svg.dtd"
--     >
-- ]]

local function cleanxhtmltree(xmltree)
    if xmltree then
        local xmlwrap = xml.wrap
        for e in xml.collected(xmltree,"/document") do
            e.at["xmlns:xhtml"] = "http://www.w3.org/1999/xhtml"
            break
        end
        -- todo: inject xhtmlpreamble (xmlns should have be enough)
        local wrapper = { tg = "a", ns = "xhtml", at = { href = "unknown" } }
        for e in xml.collected(xmltree,"link") do
            local at = e.at
            local href
            if at.location then
                href = "#" .. gsub(at.location,":","_")
            elseif at.url then
                href = at.url
            elseif at.file then
                href = at.file
            end
            if href then
                wrapper.at.href = href
                xmlwrap(e,wrapper)
            end
        end
        local wrapper = { tg = "a", ns = "xhtml", at = { name = "unknown" } }
        for e in xml.collected(xmltree,"!link[@location]") do
            local location = e.at.location
            if location then
                wrapper.at.name = gsub(location,":","_")
                xmlwrap(e,wrapper)
            end
        end
        return xmltree
    else
        return xml.convert("<?xml version='1.0'?>\n<error>invalid xhtml tree</error>")
    end
end

local cssfile, xhtmlfile = nil, nil

directives.register("backend.export.css",  function(v) cssfile   = v end)
directives.register("backend.export.xhtml",function(v) xhtmlfile = v end)

local function stopexport(v)
    starttiming(treehash)
    --
    finishexport()
    --
    collapsetree(tree)
    indextree(tree)
    checktree(tree)
    breaktree(tree)
    finalizetree(tree)
    --
    hashlistdata()
    --
    if type(v) ~= "string" or v == variables.yes or v == "" then
        v = tex.jobname
    end
    local basename = file.basename(v)
    local xmlfile = file.addsuffix(basename,"export")
    --
    local imagefilename         = file.addsuffix(file.removesuffix(xmlfile) .. "-images","css")
    local stylefilename         = file.addsuffix(file.removesuffix(xmlfile) .. "-styles","css")
    local templatefilename      = file.replacesuffix(xmlfile,"template")
    local specificationfilename = file.replacesuffix(xmlfile,"specification")
    --
    if xhtml and not cssfile then
        cssfile = true
    end
    local cssfiles = { }
    if cssfile then
        if cssfile == true then
            cssfiles = { "export-example.css" }
        else
            cssfiles = settings_to_array(cssfile or "")
        end
        insert(cssfiles,1,imagefilename)
        insert(cssfiles,1,stylefilename)
    end
    cssfiles = table.unique(cssfiles)
    --
    local result = allcontent(tree) -- also does some housekeeping and data collecting
    --
    local files = {
    }
    local results = concat {
        wholepreamble(),
        allusedstylesheets(xmlfile,cssfiles,files), -- ads to files
        result,
    }
    --
    files = table.unique(files)
    --
    report_export("saving xml data in %a",xmlfile)
    io.savedata(xmlfile,results)
    --
    report_export("saving css image definitions in %a",imagefilename)
    io.savedata(imagefilename,allusedimages(xmlfile))
    --
    report_export("saving css style definitions in %a",stylefilename)
    io.savedata(stylefilename,allusedstyles(xmlfile))
    --
    report_export("saving css template in %a",templatefilename)
    io.savedata(templatefilename,allusedelements(xmlfile))
    --
    if xhtmlfile then
        if type(v) ~= "string" or xhtmlfile == true or xhtmlfile == variables.yes or xhtmlfile == "" or xhtmlfile == xmlfile then
            xhtmlfile = file.replacesuffix(xmlfile,"xhtml")
        else
            xhtmlfile = file.addsuffix(xhtmlfile,"xhtml")
        end
        files[#files+1] = xhtmlfile
        report_export("saving xhtml variant in %a",xhtmlfile)
        local xmltree = cleanxhtmltree(xml.convert(results))
        xml.save(xmltree,xhtmlfile)
        -- looking at identity is somewhat redundant as we also inherit from interaction
        -- at the tex end
        local identity = interactions.general.getidentity()
        local specification = {
            name       = file.removesuffix(v),
            identifier = os.uuid(),
            images     = uniqueusedimages(),
            root       = xhtmlfile,
            files      = files,
            language   = languagenames[texgetcount("mainlanguagenumber")],
            title      = validstring(finetuning.title) or validstring(identity.title),
            subtitle   = validstring(finetuning.subtitle) or validstring(identity.subtitle),
            author     = validstring(finetuning.author) or validstring(identity.author),
            firstpage  = validstring(finetuning.firstpage),
            lastpage   = validstring(finetuning.lastpage),
        }
        report_export("saving specification in %a (mtxrun --script epub --make %s)",specificationfilename,specificationfilename)
        io.savedata(specificationfilename,table.serialize(specification,true))
    end
    stoptiming(treehash)
end

local appendaction = nodes.tasks.appendaction
local enableaction = nodes.tasks.enableaction

function commands.setupexport(t)
    table.merge(finetuning,t)
    keephyphens = finetuning.hyphen == variables.yes
end

local function startexport(v)
    if v and not exporting then
        report_export("enabling export to xml")
     -- not yet known in task-ini
        appendaction("shipouts","normalizers", "nodes.handlers.export")
     -- enableaction("shipouts","nodes.handlers.export")
        enableaction("shipouts","nodes.handlers.accessibility")
        enableaction("math",    "noads.handlers.tags")
     -- appendaction("finalizers","lists","builders.paragraphs.tag")
     -- enableaction("finalizers","builders.paragraphs.tag")
        luatex.registerstopactions(function() stopexport(v) end)
        exporting = true
    end
end

directives.register("backend.export",startexport) -- maybe .name

statistics.register("xml exporting time", function()
    if exporting then
        return format("%s seconds, version %s", statistics.elapsedtime(treehash),exportversion)
    end
end)

-- These are called at the tex end:

commands.settagitemgroup         = structurestags.setitemgroup
commands.settagsynonym           = structurestags.setsynonym
commands.settagsorting           = structurestags.setsorting
commands.settagdescription       = structurestags.setdescription
commands.settagdescriptionsymbol = structurestags.setdescriptionsymbol
commands.settaghighlight         = structurestags.sethighlight
commands.settagfigure            = structurestags.setfigure
commands.settagcombination       = structurestags.setcombination
commands.settagtablecell         = structurestags.settablecell
commands.settagtabulatecell      = structurestags.settabulatecell
