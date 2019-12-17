if not modules then modules = { } end modules ['typo-lin'] = {
    version   = 1.001,
    comment   = "companion to typo-lin.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is experimental code. The idea is to create an anchor point in a line but there are
-- some considerations:
--
-- * if we normalize in order to have more easy access later on, we need to normalize all
--   lines and we cannot catch all without losing efficiency
--
-- * if we normalize too soon, we might have issues with changed properties later on
--
-- * if we normalize too late, we have no knowledge of the current hsize
--
-- * if we always create an anchor we also create unwanted overhead if it is not used later
--   on (more nodes)
--
-- The question is: do we mind of at the first access an anchor is created? As we cannot know
-- that now, I choose some middle ground but this might change. if we don't assume direct
-- access but only helpers, we can decide later.
--
-- Because of right2left mess it makes sense to use helpers so that we only need to deal with
-- this mess once, in helpers. The more abstraction there the better. And so, after a week of
-- experimenting, yet another abstraction was introduced.
--
-- The danger of adding the anchor later is that we adapt the head and so the caller needs to
-- check that ... real messy. On the other hand, we soldom traverse the line. And other
-- mechanisms can push stuff in front too. Actually that alone can mess up analysis when we
-- delay too much. So in the end we need to accept the slow down.
--
-- We only need to normalize the left side because when we mess around we keep the page stream
-- order (and adding content to the right of the line is a no-go for tagged etc. For the same
-- reason we don't use two left anchors (each side fo leftskip) because there can be stretch.
-- But, maybe there are good reasons for having just that anchor (mostly for educational purposes
-- I guess.)
--
-- At this stage the localpar node is no longer of any use so we remove it (each line has the
-- direction attached). We might at some point also strip the disc nodes as they no longer serve
-- a purpose but that can better be a helper. Anchoring left has advantage of keeping page
-- stream.
--
-- This looks a bit messy but we want to keep the box as it is so \showboxes still visualizes as
-- expected. Normally left and rightskips end up in the line while hangindents become shifts and
-- hsize corrections. We could normalize this to a line with

-- indent     : hlist type 3
-- hangindent : shift and width

local type = type

local trace_anchors  = false  trackers.register("paragraphs.anchors", function(v) trace_anchors = v end)

local report = logs.reporter("anchors")

local nuts              = nodes.nuts
local nodecodes         = nodes.nodecodes
local gluecodes         = nodes.gluecodes
local listcodes         = nodes.listcodes

local hlist_code        = nodecodes.hlist
local glue_code         = nodecodes.glue
local kern_code         = nodecodes.kern
local linelist_code     = listcodes.line
----- localpar_code     = nodecodes.localpar
local leftskip_code     = gluecodes.leftskip
local rightskip_code    = gluecodes.rightskip
local parfillskip_code  = gluecodes.parfillskip

local tonut             = nodes.tonut
local tonode            = nodes.tonode

local nexthlist         = nuts.traversers.hlist
local insert_before     = nuts.insert_before
local insert_after      = nuts.insert_after
local find_tail         = nuts.tail
local rehpack           = nuts.rehpack
----- remove_node       = nuts.remove

local getsubtype        = nuts.getsubtype
local getlist           = nuts.getlist
local setlist           = nuts.setlist
local getid             = nuts.getid
local getnext           = nuts.getnext
local getprev           = nuts.getprev
local getboth           = nuts.getboth
local setlink           = nuts.setlink
local setkern           = nuts.setkern
local getkern           = nuts.getkern
local getdirection      = nuts.getdirection
local getshift          = nuts.getshift
local setshift          = nuts.setshift
local getwidth          = nuts.getwidth
local setwidth          = nuts.setwidth

local setprop           = nuts.setprop
local getprop           = nuts.rawprop -- getprop

local effectiveglue     = nuts.effective_glue

local nodepool          = nuts.pool
local new_kern          = nodepool.kern
local new_leftskip      = nodepool.leftskip
local new_rightskip     = nodepool.rightskip
local new_hlist         = nodepool.hlist
local new_rule          = nodepool.rule
local new_glue          = nodepool.glue

local righttoleft_code  = nodes.dirvalues.righttoleft

local texgetcount       = tex.getcount
local texgetglue        = tex.getglue
local setmetatableindex = table.setmetatableindex
local formatters        = string.formatters

local jobpositions      = job.positions
local getposition       = jobpositions.get
local getreserved       = jobpositions.getreserved

local paragraphs        = { }
typesetters.paragraphs  = paragraphs

local addskips          = false
local noflines          = 0

-- This is the third version, a mix between immediate (prestice lines) and delayed
-- as we don't want anchors that are not used.

-- I will make a better variant once lmtx is stable i.e. less clutter.

local function finalize(prop,key) -- delayed calculations
    local line     = prop.line
    local hsize    = prop.hsize
    local width    = prop.width
    local shift    = getshift(line) -- dangerous as it can be vertical as well
    local reverse  = getdirection(line) == righttoleft_code or false
    local pack     = new_hlist()
    local head     = getlist(line)
    local delta    = 0
    if reverse then
        delta = - shift + (hsize - width)
    else
        delta =   shift
    end
    local kern1 = new_kern(delta)
    local kern2 = new_kern(-delta)
    head = insert_before(head,head,kern1)
    head = insert_before(head,head,pack)
    head = insert_before(head,head,kern2)
    setlist(line,head)
    local where = {
        pack = pack,
        head = nil,
        tail = nil,
    }
    prop.where   = where
    prop.reverse = reverse
    prop.shift   = shift
    setmetatableindex(prop,nil)
    return prop[key]
end

local function normalize(line,islocal) -- assumes prestine lines, nothing pre/appended
    local oldhead   = getlist(line)
    local head      = oldhead
    local leftskip  = nil
    local rightskip = nil
    local width     = getwidth(line)
    local hsize     = islocal and width or tex.hsize
    local lskip     = 0
    local rskip     = 0
    local pskip     = 0
    local current   = head
    local id        = getid(current)
    if id == glue_code then
        local subtype = getsubtype(head)
        if subtype == leftskip_code then
            leftskip = head
            lskip    = getwidth(head) or 0
        end
        current = getnext(head)
        id      = getid(current)
    end
    -- no:
 -- if id == localpar_code then
 --     head = remove_node(head,head,true)
 -- end
    local tail    = find_tail(head)
    local current = tail
    local id      = getid(current)
    if id == glue_code then
        if getsubtype(current) == rightskip_code then
            rightskip  = tail
            rskip      = getwidth(current) or 0
            current    = getprev(tail)
            id         = getid(current)
        end
        if id == glue_code then
            if getsubtype(current) == parfillskip_code then
                pskip = effectiveglue(current,line)
            end
        end
    end
    if addskips then
        if rightskip and not leftskip then
            leftskip = new_leftskip(lskip)
            head     = insert_before(head,head,leftskip)
        end
        if leftskip and not rightskip then
            rightskip = new_rightskip(0)
            head, tail = insert_after(head,tail,rightskip)
        end
    end
    if head ~= oldhead then
        setlist(line,head)
    end
    noflines = noflines + 1
    local prop = {
        width       = width,
        hsize       = hsize,
        leftskip    = lskip,
        rightskip   = rskip,
        parfillskip = pskip,
        line        = line,
        number      = noflines,
    }
    setprop(line,"line",prop)
    setmetatableindex(prop,finalize)
    return prop
end

function paragraphs.checkline(n)
    return getprop(n,"line") or normalize(n,true)
end

function paragraphs.normalize(head,islocal)
    if texgetcount("pagebodymode") > 0 then
        -- can be an option, maybe we need a proper state in lua itself ... is this check still needed?
        return head, false
    end
    -- this can become a separate handler but it makes sense to integrate it here
    local mode = texgetcount("parfillleftmode")
    if mode > 0 then
        local l_width, l_stretch, l_shrink = texgetglue("parfillleftskip")
        if l_width ~= 0 or l_stretch ~= 0 or l_shrink ~= 0 then
            local last = nil -- a nut
            local done = mode == 2 -- false
            for line, subtype in nexthlist, head do
                if subtype == linelist_code and not getprop(line,"line") then
                    if done then
                        last = line
                    else
                        done = true
                    end
                end
            end
            if last then -- only if we have more than one line
                local head    = getlist(last)
                local current = head
                if current then
                    if getid(current) == glue_code and getsubtype(current,leftskip_code) then
                        current = getnext(current)
                    end
                    if current then
                        head, current = insert_before(head,current,new_glue(l_width,l_stretch,l_shrink))
                        if head == current then
                            setlist(last,head)
                        end
                        -- can be a 'rehpack(h  )'
                        rehpack(last)
                    end
                end
            end
        end
    end
    -- normalizer
    for line, subtype in nexthlist, head do
        if subtype == linelist_code and not getprop(line,"line") then
            normalize(line)
        end
    end
    return head, true -- true is obsolete
end

-- print(nodes.idstostring(head))

-- We do only basic positioning and leave compensation for directions and distances
-- to the caller as that one knows the circumstances better.

-- todo: only in mvl or explicitly, e.g. framed or so, not in all lines

local function addtoline(n,list,option)
    local line = getprop(n,"line")
    if not line then
        line = normalize(n,true)
    end
    if line then
        if trace_anchors and not line.traced then
            line.traced = true
            local rule = new_rule(2*65536,2*65536,1*65536)
            local list = insert_before(rule,rule,new_kern(-1*65536))
            addtoline(n,list)
            local rule = new_rule(2*65536,6*65536,-3*65536)
            local list = insert_before(rule,rule,new_kern(-1*65536))
            addtoline(n,list,"internal")
        else
            line.traced = true
        end
        local list  = tonut(list)
        local where = line.where
        local head  = where.head
        local tail  = where.tail
        local blob  = new_hlist(list)
        local delta = 0
        if option == "internal" then
            if line.reverse then
                delta = line.shift - line.leftskip - (line.hsize - line.width)
            else
                delta = line.shift + line.leftskip
            end
        end
        -- always kerns, also when 0 so that we can adapt but we can optimize if needed
        -- by keeping a hash as long as we use the shiftinline helper .. no need to
        -- optimize now .. we can also decide to put each blob in a hlist
        local kern = new_kern(delta)
        if tail then
            head, tail = insert_after(head,tail,kern)
        else
            head, tail = kern, kern
            setlist(where.pack,head)
        end
        head, tail = insert_after(head,tail,blob)
        local kern = new_kern(-delta)
        head, tail = insert_after(head,tail,kern)
        --
        where.head = head
        where.tail = tail
        return line, blob
    else
     -- report("unknown anchor")
    end
end

local function addanchortoline(n,anchor)
    local line = type(n) ~= "table" and getprop(n,"line") or n
    if not line then
        line = normalize(n,true)
    end
    if line then
        local anchor = tonut(anchor)
        local where  = line.where
        if trace_anchors then
            anchor = new_hlist(setlink(
                anchor,
                new_kern(-65536/4),
                new_rule(65536/2,4*65536,4*65536),
                new_kern(-65536/4-4*65536),
                new_rule(8*65536,65536/4,65536/4)
            ))
            setwidth(anchor,0)
        end
        if where.tail then
            local head = where.head
            insert_before(head,head,anchor)
        else
            where.tail = anchor
        end
        setlist(where.pack,anchor)
        where.head = anchor
        return line
    end
end

paragraphs.addtoline       = addtoline
paragraphs.addanchortoline = addanchortoline

function paragraphs.moveinline(n,blob,dx,dy)
    if not blob then
        return
    end
    if not dx then
        dx = 0
    end
    if not dy then
        dy = 0
    end
    if dx ~= 0 or dy ~= 0 then
        local line = type(n) ~= "table" and getprop(n,"line") or n
        if line then
            if dx ~= 0 then
                local prev, next = getboth(blob)
                if prev and getid(prev) == kern_code then
                    setkern(prev,getkern(prev) + dx)
                end
                if next and getid(next) == kern_code then
                    setkern(next,getkern(next) - dx)
                end
            end
            if dy ~= 0 then
                if getid(blob) == hlist_code then
                    setshift(blob,getshift(blob) + dy)
                end
            end
        else
--             report("no line")
        end
    end
end

local latelua     = nodepool.latelua
local setposition = jobpositions.setspec

local function setanchor(h_anchor)
    return latelua {
        action = setposition,
        name   = "md:h",
        index  = h_anchor,
        value  = { x = true, c = true },
    }
end

function paragraphs.calculatedelta(n,width,delta,atleft,islocal,followshape,area)
    local line = type(n) ~= "table" and getprop(n,"line") or n
    if not line then
        line = normalize(n,true)
    end
    local hmove = 0
    if line then
        local reverse = line.reverse
        -- basic hsize based anchoring
        if atleft then
            if reverse then
             -- delta =   delta
            else
                delta = - delta - width
            end
        else
            if reverse then
                delta = - delta - width - line.hsize
            else
                delta =   delta         + line.hsize
            end
        end
        if islocal then
            -- relative to hsize with leftskip / rightskip compensation
            if atleft then
                if reverse then
                    delta = delta - line.leftskip
                else
                    delta = delta + line.leftskip
                end
            else
                if reverse then
                    delta = delta + line.rightskip
                else
                    delta = delta - line.rightskip
                end
            end
            if followshape then
                -- shape compensation
                if atleft then
                    if reverse then
                        delta = delta + line.shift - line.hsize + line.width
                    else
                        delta = delta + line.shift
                    end
                else
                    if reverse then
                        delta = delta + line.shift                           + line.parfillskip
                    else
                        delta = delta + line.shift - line.hsize + line.width - line.parfillskip
                    end
                end
            end
        end
        if area then
            local number = line.number
            if not line.hanchor then
                addanchortoline(line,setanchor(number))
                line.hanchor = true
            end
            local blob = getposition(s_anchor,number)
            if blob then
                local reference = getreserved(area,blob.c)
                if reference then
                    hmove = (reference.x or 0) - (blob.x or 0)
                    if atleft then
                        if reverse then
                            hmove = hmove + (reference.w or 0)
                        else
                         -- hmove = hmove
                        end
                    else
                        if reverse then
                            hmove = hmove                      + line.hsize
                        else
                            hmove = hmove + (reference.w or 0) - line.hsize
                        end
                    end
                end
            end
        end
    end
    return delta, hmove
end
