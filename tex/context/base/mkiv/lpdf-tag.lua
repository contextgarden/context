if not modules then modules = { } end modules ['lpdf-tag'] = {
    version   = 1.001,
    comment   = "companion to lpdf-tag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local format, match, gmatch = string.format, string.match, string.gmatch
local concat, sortedhash = table.concat, table.sortedhash
local lpegmatch, P, S, C = lpeg.match, lpeg.P, lpeg.S, lpeg.C
local settings_to_hash = utilities.parsers.settings_to_hash
local formatters = string.formatters

local trace_tags = false  trackers.register("structures.tags",      function(v) trace_tags = v end)
local trace_info = false  trackers.register("structures.tags.info", function(v) trace_info = v end)

local report_tags = logs.reporter("backend","tags")

local backends            = backends
local lpdf                = lpdf
local nodes               = nodes

local nodeinjections      = backends.pdf.nodeinjections
local codeinjections      = backends.pdf.codeinjections

local enableaction        = nodes.tasks.enableaction
local disableaction       = nodes.tasks.disableaction

local pdfdictionary       = lpdf.dictionary
local pdfarray            = lpdf.array
local pdfboolean          = lpdf.boolean
local pdfconstant         = lpdf.constant
local pdfreference        = lpdf.reference
local pdfunicode          = lpdf.unicode
local pdfflushobject      = lpdf.flushobject
local pdfreserveobject    = lpdf.reserveobject
local pdfpagereference    = lpdf.pagereference
local pdfmakenametree     = lpdf.makenametree

local addtocatalog        = lpdf.addtocatalog
local addtopageattributes = lpdf.addtopageattributes

local texgetcount         = tex.getcount

local nodecodes           = nodes.nodecodes

local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local glyph_code          = nodecodes.glyph

local a_tagged            = attributes.private('tagged')
local a_image             = attributes.private('image')

local nuts                = nodes.nuts

local nodepool            = nuts.pool
local pageliteral         = nodepool.pageliteral
local register            = nodepool.register

local getid               = nuts.getid
local getattr             = nuts.getattr
local getprev             = nuts.getprev
local getnext             = nuts.getnext
local getlist             = nuts.getlist
local getchar             = nuts.getchar

local setlink             = nuts.setlink
local setlist             = nuts.setlist

local copy_node           = nuts.copy
local tosequence          = nuts.tosequence

local nextnode            = nuts.traversers.node

local structure_kids   -- delayed
local structure_ref    -- delayed
local parent_ref       -- delayed
local root             -- delayed
local names               = { }
local tree                = { }
local elements            = { }

local structurestags      = structures.tags
local taglist             = structurestags.taglist
local specifications      = structurestags.specifications
local usedlabels          = structurestags.labels
local properties          = structurestags.properties
local usewithcare         = structurestags.usewithcare

local usedmapping         = { }

----- tagsplitter         = structurestags.patterns.splitter

local embeddedtags        = false -- true will id all, for tracing, otherwise table
local f_tagid             = formatters["%s-%04i"]
local embeddedfilelist    = pdfarray() -- /AF crap

-- for testing, not that it was ever used:

directives.register("structures.tags.embed",function(v)
    if type(v) == "string" then
        if type(embeddedtags) ~= "table" then
            embeddedtags = { }
        end
        for s in gmatch(v,"([^, ]+)") do
            embeddedtags[s] = true
        end
    elseif v and not embeddedtags then
        embeddedtags = true
    end
end)

-- for old times sake, not that it was ever used:

directives.register("structures.tags.embedmath",function(v)
    if not v then
        -- only enable
    elseif embeddedtags == true then
        -- already all tagged
    elseif embeddedtags then
        embeddedtags.math = true
    else
        embeddedtags = { math = true }
    end
end)

function codeinjections.maptag(original,target,kind)
    mapping[original] = { target, kind or "inline" }
end

-- mostly the same as the annotations tree

local function finishstructure()
    if root and #structure_kids > 0 then
        local nums   = pdfarray()
        local n      = 0
        for i=1,#tree do
            n = n + 1 ; nums[n] = i - 1
            n = n + 1 ; nums[n] = pdfreference(pdfflushobject(tree[i]))
        end
        local parenttree = pdfdictionary {
            Nums = nums
        }
        local idtree = pdfmakenametree(names)
        --
        local rolemap = pdfdictionary()
        for k, v in next, usedmapping do
            k = usedlabels[k] or k
            local p = properties[k]
            rolemap[k] = pdfconstant(p and p.pdf or "Span") -- or "Div"
        end
        local structuretree = pdfdictionary {
            Type       = pdfconstant("StructTreeRoot"),
            K          = pdfreference(pdfflushobject(structure_kids)),
            ParentTree = pdfreference(pdfflushobject(parent_ref,parenttree)),
            IDTree     = idtree,
            RoleMap    = rolemap, -- sorted ?
        }
        pdfflushobject(structure_ref,structuretree)
        addtocatalog("StructTreeRoot",pdfreference(structure_ref))
        --
        if lpdf.majorversion() == 1 then
            local markinfo = pdfdictionary {
                Marked         = pdfboolean(true) or nil,
             -- UserProperties = pdfboolean(true), -- maybe some day
             -- Suspects       = pdfboolean(true) or nil,
             -- AF             = #embeddedfilelist > 0 and pdfreference(pdfflushobject(embeddedfilelist)) or nil,
            }
            addtocatalog("MarkInfo",pdfreference(pdfflushobject(markinfo)))
        end
        --
        for fulltag, element in sortedhash(elements) do -- sorting is easier on comparing pdf
            pdfflushobject(element.knum,element.kids)
        end
    end
end

lpdf.registerdocumentfinalizer(finishstructure,"document structure")

local index, pageref, pagenum, list = 0, nil, 0, nil

local pdf_mcr            = pdfconstant("MCR")
local pdf_struct_element = pdfconstant("StructElem")
local pdf_s              = pdfconstant("S")

local function initializepage()
    index   = 0
    pagenum = texgetcount("realpageno")
    pageref = pdfreference(pdfpagereference(pagenum))
    list    = pdfarray()
    tree[pagenum] = list -- we can flush after done, todo
end

local function finishpage()
    -- flush what can be flushed
    addtopageattributes("StructParents",pagenum-1)
    -- there might be more
    addtopageattributes("Tabs",s)
end

-- here we can flush and free elements that are finished

local pdf_userproperties = pdfconstant("UserProperties")

-- /O /Table
-- /Headers [ ]

local function makeattribute(t)
    if t and next(t) then
        local properties = pdfarray()
        for k, v in sortedhash(t) do -- easier on comparing pdf
            properties[#properties+1] = pdfdictionary {
                N = pdfunicode(k),
                V = pdfunicode(v),
            }
        end
        return pdfdictionary {
            O = pdf_userproperties,
            P = properties,
        }
    end
end

local function makeelement(fulltag,parent)
    local specification = specifications[fulltag]
    local tagname       = specification.tagname
    local tagnameused   = tagname
    local attributes    = nil
    if tagname == "ignore" then
        return false
    elseif tagname == "mstackertop" or tagname == "mstackerbot" or tagname == "mstackermid"then
        -- TODO
        return true
    elseif tagname == "tabulatecell" then
        local d = structurestags.gettabulatecell(fulltag)
        if d and d.kind == 1 then
            tagnameused = "tabulateheadcell"
        end
    elseif tagname == "tablecell" then
        -- will become a plugin model
        local d = structurestags.gettablecell(fulltag)
        if d then
            if d.kind == 1 then
                tagnameused = "tableheadcell"
            end
            local rows = d.rows    or 1
            local cols = d.columns or 1
            if rows > 1 or cols > 1 then
                attributes = pdfdictionary {
                    O       = pdfconstant("Table"),
                    RowSpan = rows > 1 and rows or nil,
                    ColSpan = cols > 1 and cols or nil,
                }
            end

        end
    end
    --
    local detail   = specification.detail
    local userdata = specification.userdata
    --
    usedmapping[tagname] = true
    --
    -- specification.attribute is unique
    --
    local id = nil
    local af = nil
    if embeddedtags then
        local tagindex = specification.tagindex
        if embeddedtags == true or embeddedtags[tagname] then
            id = f_tagid(tagname,tagindex)
            af = job.fileobjreferences.collected[id]
            if af then
                local r = pdfreference(af)
                af = pdfarray { r }
             -- embeddedfilelist[#embeddedfilelist+1] = r
            end
        end
    end
    --
    local k = pdfarray()
    local r = pdfreserveobject()
    local t = usedlabels[tagnameused] or tagnameused
 -- local a = nil
    local d = pdfdictionary {
        Type       = pdf_struct_element,
        S          = pdfconstant(t),
        ID         = id,
        T          = detail and detail or nil,
        P          = parent.pref,
        Pg         = pageref,
        K          = pdfreference(r),
     -- A          = a and makeattribute(a) or nil,
        A          = attributes,
     -- Alt        = " Who cares ",
     -- ActualText = " Hi Hans ",
        AF         = af,
    }
    local s = pdfreference(pdfflushobject(d))
    if id and names then
        names[id] = s
    end
    local kids = parent.kids
    kids[#kids+1] = s
    local e = {
        tag  = t,
        pref = s,
        kids = k,
        knum = r,
        pnum = pagenum
    }
    elements[fulltag] = e
    return e
end

local f_BDC = formatters["/%s <</MCID %s>> BDC"]

local function makecontent(parent,id,specification)
    local tag  = parent.tag
    local kids = parent.kids
    local last = index
    if id == "image" then
        local list  = specification.taglist
        local data  = usewithcare.images[list[#list]]
        local label = data and data.label
        local d = pdfdictionary {
            Type = pdf_mcr,
            Pg   = pageref,
            MCID = last,
            Alt  = pdfunicode(label ~= "" and label or "image"),
        }
        kids[#kids+1] = d
    elseif pagenum == parent.pnum then
        kids[#kids+1] = last
    else
        local d = pdfdictionary {
            Type = pdf_mcr,
            Pg   = pageref,
            MCID = last,
        }
     -- kids[#kids+1] = pdfreference(pdfflushobject(d))
        kids[#kids+1] = d
    end
    --
    index = index + 1
    list[index] = parent.pref -- page related list
    --
    return f_BDC(tag,last)
end

local function makeignore(specification)
    return "/Artifact BMC"
end

-- no need to adapt head, as we always operate on lists

local EMCliteral = nil
local visualize  = nil

function nodeinjections.addtags(head)

    if not EMCliteral then
        EMCliteral = register(pageliteral("EMC"))
    end

    local last   = nil
    local ranges = { }
    local range  = nil

    if not root then
        structure_kids = pdfarray()
        structure_ref  = pdfreserveobject()
        parent_ref     = pdfreserveobject()
        root           = { pref = pdfreference(structure_ref), kids = structure_kids }
        names          = pdfarray()
    end

    local function collectranges(head,list)
        for n, id in nextnode, head do
            if id == glyph_code then
                -- maybe also disc
if getchar(n) ~= 0 then
                local at = getattr(n,a_tagged) or false -- false: pagebody or so, so artifact
             -- if not at then
             --     range = nil
             -- elseif ...
                if last ~= at then
                    range = { at, "glyph", n, n, list } -- attr id start stop list
                    ranges[#ranges+1] = range
                    last = at
                elseif range then
                    range[4] = n -- stop
                end
end
            elseif id == hlist_code or id == vlist_code then
                local at = getattr(n,a_image)
                if at then
                    local at = getattr(n,a_tagged) or false -- false: pagebody or so, so artifact
                 -- if not at then
                 --     range = nil
                 -- else
                        ranges[#ranges+1] = { at, "image", n, n, list } -- attr id start stop list
                 -- end
                    last = nil
                else
                    local list = getlist(n)
                    if list then
                        collectranges(list,n)
                    end
                end
            end
        end
    end

    initializepage()

    collectranges(head)

    if trace_tags then
        for i=1,#ranges do
            local range = ranges[i]
            local attr  = range[1]
            local id    = range[2]
            local start = range[3]
            local stop  = range[4]
            local tags  = taglist[attr]
            if tags then -- not ok ... only first lines
                report_tags("%s => %s : %05i % t",tosequence(start,start),tosequence(stop,stop),attr,tags.taglist)
            end
        end
    end

    local top    = nil
    local noftop = 0

    local function inject(start,stop,list,literal,left,right)
        local prev = getprev(start)
        if prev then
            setlink(prev,literal)
        end
        if left then
            setlink(literal,left,start)
        else
            setlink(literal,start)
        end
        if list and not prev then
            setlist(list,literal)
        end
        local literal = copy_node(EMCliteral)
        -- use insert instead:
        local next = getnext(stop)
        if next then
            setlink(literal,next)
        end
        if right then
            setlink(stop,right,literal)
        else
            setlink(stop,literal)
        end
    end

    for i=1,#ranges do

        local range = ranges[i]
        local attr  = range[1]
        local id    = range[2]
        local start = range[3]
        local stop  = range[4]
        local list  = range[5]

        if attr then

            local specification = taglist[attr]
            local taglist       = specification.taglist
            local noftags       = #taglist
            local common        = 0
            local literal       = nil
            local ignore        = false

            if top then
                for i=1,noftags >= noftop and noftop or noftags do
                    if top[i] == taglist[i] then
                        common = i
                    else
                        break
                    end
                end
            end

            local prev = common > 0 and elements[taglist[common]] or root

            for j=common+1,noftags do
                local tag = taglist[j]
                local prv = elements[tag] or makeelement(tag,prev)
                if prv == false then
                    -- ignore this one
                    prev   = false
                    ignore = true
                    break
                elseif prv == true then
                    -- skip this one
                else
                    prev = prv
                end
            end
            if prev then
                literal = pageliteral(makecontent(prev,id,specification))
            elseif ignore then
                literal = pageliteral(makeignore(specification))
            else
                -- maybe also ignore or maybe better: comment or so
            end

            if literal then
                local left,right
                if trace_info then
                    local name = specification.tagname
                    if name then
                        if not visualize then
                            visualize = nodes.visualizers.register("tags")
                        end
                        left  = visualize(name)
                        right = visualize()
                    end
                end
                inject(start,stop,list,literal,left,right)
            end

            top    = taglist
            noftop = noftags

        else

            local literal = pageliteral(makeignore(specification))

            inject(start,stop,list,literal)

        end

    end

    finishpage()

    return head

end

-- variant: more structure but funny collapsing in viewer

-- function nodeinjections.addtags(head)
--
--     local last, ranges, range = nil, { }, nil
--
--     local function collectranges(head,list)
--         for n, id in nextnode, head do
--             if id == glyph_code then
--                 local at = getattr(n,a_tagged)
--                 if not at then
--                     range = nil
--                 elseif last ~= at then
--                     range = { at, "glyph", n, n, list } -- attr id start stop list
--                     ranges[#ranges+1] = range
--                     last = at
--                 elseif range then
--                     range[4] = n -- stop
--                 end
--             elseif id == hlist_code or id == vlist_code then
--                 local at = getattr(n,a_image)
--                 if at then
--                     local at = getattr(n,a_tagged)
--                     if not at then
--                         range = nil
--                     else
--                         ranges[#ranges+1] = { at, "image", n, n, list } -- attr id start stop list
--                     end
--                     last = nil
--                 else
--                     local nl = getlist(n)
--                     collectranges(nl,n)
--                 end
--             end
--         end
--     end
--
--     initializepage()
--
--     collectranges(head)
--
--     if trace_tags then
--         for i=1,#ranges do
--             local range = ranges[i]
--             local attr  = range[1]
--             local id    = range[2]
--             local start = range[3]
--             local stop  = range[4]
--             local tags  = taglist[attr]
--             if tags then -- not ok ... only first lines
--                 report_tags("%s => %s : %05i % t",tosequence(start,start),tosequence(stop,stop),attr,tags.taglist)
--             end
--         end
--     end
--
--     local top    = nil
--     local noftop = 0
--     local last   = nil
--
--     for i=1,#ranges do
--         local range         = ranges[i]
--         local attr          = range[1]
--         local id            = range[2]
--         local start         = range[3]
--         local stop          = range[4]
--         local list          = range[5]
--         local specification = taglist[attr]
--         local taglist       = specification.taglist
--         local noftags       = #taglist
--         local tag           = nil
--         local common        = 0
--      -- local prev          = root
--
--         if top then
--             for i=1,noftags >= noftop and noftop or noftags do
--                 if top[i] == taglist[i] then
--                     common = i
--                 else
--                     break
--                 end
--             end
--         end
--
--         local result        = { }
--         local r             = noftop - common
--         if r > 0 then
--             for i=1,r do
--                 result[i] = "EMC"
--             end
--         end
--
--         local prev   = common > 0 and elements[taglist[common]] or root
--
--         for j=common+1,noftags do
--             local tag = taglist[j]
--             local prv = elements[tag] or makeelement(tag,prev)
--          -- if prv == false then
--          --     -- ignore this one
--          --     prev = false
--          --     break
--          -- elseif prv == true then
--          --     -- skip this one
--          -- else
--                 prev = prv
--                 r = r + 1
--                 result[r] = makecontent(prev,id)
--          -- end
--         end
--
--         if r > 0 then
--             local literal = pageliteral(concat(result,"\n"))
--             -- use insert instead:
--             local literal = pageliteral(result)
--             local prev = getprev(start)
--             if prev then
--                 setlink(prev,literal)
--             end
--             setlink(literal,start)
--             if list and getlist(list) == start then
--                 setlist(list,literal)
--             end
--         end
--
--         top    = taglist
--         noftop = noftags
--         last   = stop
--
--     end
--
--     if last and noftop > 0 then
--         local result = { }
--         for i=1,noftop do
--             result[i] = "EMC"
--         end
--         local literal = pageliteral(concat(result,"\n"))
--         -- use insert instead:
--         local next = getnext(last)
--         if next then
--             setlink(literal,next)
--         end
--         setlink(last,literal)
--     end
--
--     finishpage()
--
--     return head
--
-- end

-- this belongs elsewhere (export is not pdf related)

local permitted = true
local enabled   = false

function codeinjections.settaggingsupport(option)
    if option == false then
        if enabled then
            disableaction("shipouts","structures.tags.handler")
            disableaction("shipouts","nodes.handlers.accessibility") -- maybe not this one
            disableaction("math","noads.handlers.tags")
            enabled = false
        end
        if permitted then
            if trace_tags then
                report_tags("blocking structure tags")
            end
            permitted = false
        end
    end
end

function codeinjections.enabletags()
    if permitted and not enabled then
        structures.tags.handler = nodeinjections.addtags
        enableaction("shipouts","structures.tags.handler")
        enableaction("shipouts","nodes.handlers.accessibility")
        enableaction("math","noads.handlers.tags")
        -- maybe also textblock
        if trace_tags then
            report_tags("enabling structure tags")
        end
        enabled = true
    end
end
