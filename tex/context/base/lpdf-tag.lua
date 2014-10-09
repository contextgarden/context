if not modules then modules = { } end modules ['lpdf-tag'] = {
    version   = 1.001,
    comment   = "companion to lpdf-tag.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next
local format, match, concat = string.format, string.match, table.concat
local lpegmatch, P, S, C = lpeg.match, lpeg.P, lpeg.S, lpeg.C
local utfchar = utf.char
local settings_to_hash = utilities.parsers.settings_to_hash
local formatters = string.formatters

local trace_tags = false  trackers.register("structures.tags", function(v) trace_tags = v end)

local report_tags = logs.reporter("backend","tags")

local backends            = backends
local lpdf                = lpdf
local nodes               = nodes

local nodeinjections      = backends.pdf.nodeinjections
local codeinjections      = backends.pdf.codeinjections

local tasks               = nodes.tasks

local pdfdictionary       = lpdf.dictionary
local pdfarray            = lpdf.array
local pdfboolean          = lpdf.boolean
local pdfconstant         = lpdf.constant
local pdfreference        = lpdf.reference
local pdfunicode          = lpdf.unicode
local pdfstring           = lpdf.string
local pdfflushobject      = lpdf.flushobject
local pdfreserveobject    = lpdf.reserveobject
local pdfpagereference    = lpdf.pagereference

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
local tonut               = nuts.tonut
local tonode              = nuts.tonode

local nodepool            = nuts.pool
local pdfliteral          = nodepool.pdfliteral

local getid               = nuts.getid
local getattr             = nuts.getattr
local getprev             = nuts.getprev
local getnext             = nuts.getnext
local getlist             = nuts.getlist
local setfield            = nuts.setfield

local traverse_nodes      = nuts.traverse
local tosequence          = nuts.tosequence
local copy_node           = nuts.copy
local slide_nodelist      = nuts.slide
local insert_before       = nuts.insert_before
local insert_after        = nuts.insert_after

local structure_stack     = { }
local structure_kids      = pdfarray()
local structure_ref       = pdfreserveobject()
local parent_ref          = pdfreserveobject()
local root                = { pref = pdfreference(structure_ref), kids = structure_kids }
local tree                = { }
local elements            = { }
local names               = pdfarray()

local structurestags      = structures.tags
local taglist             = structurestags.taglist
local usedlabels          = structurestags.labels
local properties          = structurestags.properties
local userdata            = structurestags.userdata
local lasttaginchain      = structurestags.lastinchain

local usedmapping         = { }

local colonsplitter       = lpeg.splitat(":")
local dashsplitter        = lpeg.splitat("-")

local add_ids             = false -- true

-- function codeinjections.maptag(original,target,kind)
--     mapping[original] = { target, kind or "inline" }
-- end

local function finishstructure()
    if #structure_kids > 0 then
        local nums, n = pdfarray(), 0
        for i=1,#tree do
            n = n + 1 ; nums[n] = i - 1
            n = n + 1 ; nums[n] = pdfreference(pdfflushobject(tree[i]))
        end
        local parenttree = pdfdictionary {
            Nums = nums
        }
        -- we need to split names into smaller parts (e.g. alphabetic or so)
        -- we already have code for that somewhere
        if add_ids then
            local kids = pdfdictionary {
                Limits = pdfarray { names[1], names[#names-1] },
                Names  = names,
            }
            local idtree = pdfdictionary {
                Kids = pdfarray { pdfreference(pdfflushobject(kids)) },
            }
        end
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
            IDTree     = (add_ids and pdfreference(pdfflushobject(idtree))) or nil,
            RoleMap    = rolemap,
        }
        pdfflushobject(structure_ref,structuretree)
        addtocatalog("StructTreeRoot",pdfreference(structure_ref))
        --
        local markinfo = pdfdictionary {
            Marked         = pdfboolean(true),
         -- UserProperties = pdfboolean(true),
         -- Suspects       = pdfboolean(true),
        }
        addtocatalog("MarkInfo",pdfreference(pdfflushobject(markinfo)))
        --
        for fulltag, element in next, elements do
            pdfflushobject(element.knum,element.kids)
        end
    end
end

lpdf.registerdocumentfinalizer(finishstructure,"document structure")

local index, pageref, pagenum, list = 0, nil, 0, nil

local pdf_mcr            = pdfconstant("MCR")
local pdf_struct_element = pdfconstant("StructElem")

local function initializepage()
    index = 0
    pagenum = texgetcount("realpageno")
    pageref = pdfreference(pdfpagereference(pagenum))
    list = pdfarray()
    tree[pagenum] = list -- we can flush after done, todo
end

local function finishpage()
    -- flush what can be flushed
    addtopageattributes("StructParents",pagenum-1)
end

-- here we can flush and free elements that are finished

local userproperties     = structurestags.userproperties
local pdf_userproperties = pdfconstant("UserProperties")

local function makeattribute(t)
    if t and next(t) then
        local properties = pdfarray()
        for k, v in next, t do
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

local function makeelement(fulltag,parent,attr)
    local tag, n = lpegmatch(dashsplitter,fulltag)
    local tg, detail = lpegmatch(colonsplitter,tag)
    if tg == "ignore" then
        return false
    elseif tg == "mstackertop" or tg == "mstackerbot" or tg == "mstackermid"then
        return true
    elseif tg == "mstacker" then
        local p = properties[fulltag]
        tg = p and p.subtype or tg
    end
    local k = pdfarray()
    local r = pdfreserveobject()
    local a = userproperties[fulltag]
    usedmapping[tg] = true
    tg = usedlabels[tg] or tg
    local d = pdfdictionary {
        Type       = pdf_struct_element,
        S          = pdfconstant(tg),
        ID         = (add_ids and fulltag) or nil,
        T          = detail and detail or nil,
        P          = parent.pref,
        Pg         = pageref,
        K          = pdfreference(r),
        A          = a and makeattribute(a) or nil,
     -- Alt        = " Who cares ",
     -- ActualText = " Hi Hans ",
    }
    local s = pdfreference(pdfflushobject(d))
    if add_ids then
        names[#names+1] = fulltag
        names[#names+1] = s
    end
    local kids = parent.kids
    kids[#kids+1] = s
    local e = { tag = tag, pref = s, kids = k, knum = r, pnum = pagenum }
    elements[fulltag] = e
    return e
end

local f_BDC = formatters["/%s <</MCID %s>>BDC"]

local function makecontent(parent,start,stop,slist,id)
    local tag  = parent.tag
    local kids = parent.kids
    local last = index
    if id == "image" then
        local d = pdfdictionary {
            Type = pdf_mcr,
         -- Pg   = pageref,
            MCID = last,
            Alt  = "image",
        }
        kids[#kids+1] = d
    elseif pagenum == parent.pnum then
        kids[#kids+1] = last
    else
        local d = pdfdictionary {
            Type = pdf_mcr,
         -- Pg   = pageref,
            MCID = last,
        }
     -- kids[#kids+1] = pdfreference(pdfflushobject(d))
        kids[#kids+1] = d
    end
    --
    local bliteral = pdfliteral(f_BDC(tag,last))
    local eliteral = pdfliteral("EMC") -- could be a copy
    -- use insert instead:
    local prev = getprev(start)
    if prev then
        setfield(prev,"next",bliteral)
        setfield(bliteral,"prev",prev)
    end
    setfield(start,"prev",bliteral)
    setfield(bliteral,"next",start)
    -- use insert instead:
    local next = getnext(stop)
    if next then
        setfield(next,"prev",eliteral)
        setfield(eliteral,"next",next)
    end
    setfield(stop,"next",eliteral)
    setfield(eliteral,"prev",stop)
    --
    if slist and getlist(slist) == start then
        setfield(slist,"list",bliteral)
    elseif not getprev(start) then
        report_tags("this can't happen: injection in front of nothing")
    end
    index = index + 1
    list[index] = parent.pref
    return bliteral, eliteral
end

-- -- --

local level, last, ranges, range = 0, nil, { }, nil

local function collectranges(head,list)
    for n in traverse_nodes(head) do
        local id = getid(n) -- 14: image, 8: literal (mp)
        if id == glyph_code then
            local at = getattr(n,a_tagged)
            if not at then
                range = nil
            elseif last ~= at then
                range = { at, "glyph", n, n, list } -- attr id start stop list
                ranges[#ranges+1] = range
                last = at
            elseif range then
                range[4] = n -- stop
            end
        elseif id == hlist_code or id == vlist_code then
            local at = getattr(n,a_image)
            if at then
                local at = getattr(n,a_tagged)
                if not at then
                    range = nil
                else
                    ranges[#ranges+1] = { at, "image", n, n, list } -- attr id start stop list
                end
                last = nil
            else
                local nl = getlist(n)
             -- slide_nodelist(nl) -- temporary hack till math gets slided (tracker item)
                collectranges(nl,n)
            end
        end
    end
end

function nodeinjections.addtags(head)
    -- no need to adapt head, as we always operate on lists
    level, last, ranges, range = 0, nil, { }, nil
    initializepage()
	head = tonut(head)
    collectranges(head)
    if trace_tags then
        for i=1,#ranges do
            local range = ranges[i]
            local attr, id, start, stop = range[1], range[2], range[3], range[4]
            local tags = taglist[attr]
            if tags then -- not ok ... only first lines
                report_tags("%s => %s : %05i % t",tosequence(start,start),tosequence(stop,stop),attr,tags)
            end
        end
    end
    for i=1,#ranges do
        local range = ranges[i]
        local attr, id, start, stop, list = range[1], range[2], range[3], range[4], range[5]
        local tags = taglist[attr]
        local prev = root
        local noftags, tag = #tags, nil
        for j=1,noftags do
            local tag = tags[j]
            local prv = elements[tag] or makeelement(tag,prev,attr)
            if prv == false then
                -- ignore this one
                prev = false
                break
            elseif prv == true then
                -- skip this one
            else
                prev = prv
            end
        end
        if prev then
            local b, e = makecontent(prev,start,stop,list,id)
            if start == head then
                report_tags("this can't happen: parent list gets tagged")
                head = b
            end
        else
            -- ignored content
        end
    end
    finishpage()
    -- can be separate feature
    --
    -- injectspans(tonut(head)) -- does to work yet
    --
    head = tonode(head)
    return head, true
end

-- this belongs elsewhere (export is not pdf related)

function codeinjections.enabletags(tg,lb)
    structures.tags.handler = nodeinjections.addtags
    tasks.enableaction("shipouts","structures.tags.handler")
    tasks.enableaction("shipouts","nodes.handlers.accessibility")
    tasks.enableaction("math","noads.handlers.tags")
    -- maybe also textblock
    if trace_tags then
        report_tags("enabling structure tags")
    end
end
