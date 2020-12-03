if not modules then modules = { } end modules ['typo-mar'] = {
    version   = 1.001,
    comment   = "companion to typo-mar.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo:
--
-- * autoleft/right depending on available space (or distance to margin)
-- * floating margin data, with close-to-call anchoring

local format, validstring = string.format, string.valid
local insert, remove, sortedkeys, fastcopy = table.insert, table.remove, table.sortedkeys, table.fastcopy
local setmetatable, next, tonumber = setmetatable, next, tonumber
local formatters = string.formatters
local toboolean = toboolean
local settings_to_hash = utilities.parsers.settings_to_hash

local attributes         = attributes
local nodes              = nodes
local variables          = variables
local context            = context

local trace_margindata   = false  trackers.register("typesetters.margindata",       function(v) trace_margindata  = v end)
local trace_marginstack  = false  trackers.register("typesetters.margindata.stack", function(v) trace_marginstack = v end)
local trace_margingroup  = false  trackers.register("typesetters.margindata.group", function(v) trace_margingroup = v end)

local report_margindata  = logs.reporter("margindata")

local tasks              = nodes.tasks
local prependaction      = tasks.prependaction
local disableaction      = tasks.disableaction
local enableaction       = tasks.enableaction

local variables          = interfaces.variables

local conditionals       = tex.conditionals
local systemmodes        = tex.systemmodes

local v_top              = variables.top
local v_depth            = variables.depth
local v_local            = variables["local"]
local v_global           = variables["global"]
local v_left             = variables.left
local v_right            = variables.right
local v_inner            = variables.inner
local v_outer            = variables.outer
local v_margin           = variables.margin
local v_edge             = variables.edge
local v_default          = variables.default
local v_normal           = variables.normal
local v_yes              = variables.yes
local v_continue         = variables.continue
local v_first            = variables.first
local v_text             = variables.text
local v_paragraph        = variables.paragraph
local v_line             = variables.line

local nuts               = nodes.nuts
local tonode             = nuts.tonode

local hpack_nodes        = nuts.hpack
local traverse_id        = nuts.traverse_id
local flush_node_list    = nuts.flush_list

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local getsubtype         = nuts.getsubtype
local getlist            = nuts.getlist
local getwhd             = nuts.getwhd
local setlist            = nuts.setlist
local setlink            = nuts.setlink
local getshift           = nuts.getshift
local setshift           = nuts.setshift
local getwidth           = nuts.getwidth
local setwidth           = nuts.setwidth
local getheight          = nuts.getheight

local setattrlist        = nuts.setattrlist

local getbox             = nuts.getbox
local takebox            = nuts.takebox

local setprop            = nuts.setprop
local getprop            = nuts.getprop

local nodecodes          = nodes.nodecodes
local listcodes          = nodes.listcodes
local whatsitcodes       = nodes.whatsitcodes

local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local whatsit_code       = nodecodes.whatsit
local userdefined_code   = whatsitcodes.userdefined

local nodepool           = nuts.pool

local new_hlist          = nodepool.hlist
local new_usernode       = nodepool.usernode
local latelua            = nodepool.latelua

local texgetdimen        = tex.getdimen
local texgetcount        = tex.getcount
local texget             = tex.get

local isleftpage         = layouts.status.isleftpage
local registertogether   = builders.paragraphs.registertogether

local paragraphs         = typesetters.paragraphs
local addtoline          = paragraphs.addtoline
local moveinline         = paragraphs.moveinline
local calculatedelta     = paragraphs.calculatedelta

local a_linenumber       = attributes.private('linenumber')

local inline_mark        = nodepool.userids["margins.inline"]

local jobpositions       = job.positions
local getposition        = jobpositions.get
local setposition        = jobpositions.set
local getreserved        = jobpositions.getreserved

local margins            = { }
typesetters.margins      = margins

local locations          = { v_left, v_right, v_inner, v_outer } -- order might change
local categories         = { }
local displaystore       = { } -- [category][location][scope]
local inlinestore        = { } -- [number]
local nofsaved           = 0
local nofstored          = 0
local nofinlined         = 0
local nofdelayed         = 0
local nofinjected        = 0
local h_anchors          = 0
local v_anchors          = 0

local mt1 = {
    __index = function(t,location)
        local v = { [v_local] = { }, [v_global] = { } }
        t[location] = v
        return v
    end
}

local mt2 = {
    __index = function(stores,category)
        categories[#categories+1] = category
        local v = { }
        setmetatable(v,mt1)
        stores[category] = v
        return v
    end
}

setmetatable(displaystore,mt2)

local defaults = {
    __index  = {
        location  = v_left,
        align     = v_normal, -- not used
        method    = "",
        name      = "",
        threshold = 0, -- .25ex
        margin    = v_normal,
        scope     = v_global,
        distance  = 0,
        hoffset   = 0,
        voffset   = 0,
        category  = v_default,
        line      = 0,
        vstack    = 0,
        dy        = 0,
        baseline  = false,
        inline    = false,
        leftskip  = 0,
        rightskip = 0,
        option    = { }
    }
}

local enablelocal, enableglobal -- forward reference (delayed initialization)

local function showstore(store,banner,location)
    if next(store) then
        for i, si in table.sortedpairs(store) do
            local si =store[i]
            report_margindata("%s: stored in %a at %s: %a => %s",banner,location,i,validstring(si.name,"no name"),nodes.toutf(getlist(si.box)))
        end
    else
        report_margindata("%s: nothing stored in location %a",banner,location)
    end
end

function margins.save(t)
    setmetatable(t,defaults)
    local content  = takebox(t.number)
    local location = t.location
    local category = t.category
    local inline   = t.inline
    local scope    = t.scope
    local name     = t.name
    local option   = t.option
    local stack    = t.stack
    if option then
        option   = settings_to_hash(option)
        t.option = option
    end
    if not content then
        report_margindata("ignoring empty margin data %a",location or "unknown")
        return
    end
    setprop(content,"specialcontent","margindata")
    local store
    if inline then
        store = inlinestore
    else
        store = displaystore[category][location]
        if not store then
            report_margindata("invalid location %a",location)
            return
        end
        store = store[scope]
    end
    if not store then
        report_margindata("invalid scope %a",scope)
        return
    end
    if enablelocal and scope == v_local then
        enablelocal()
        if enableglobal then
            enableglobal() -- is the fallback
        end
    elseif enableglobal and scope == v_global then
        enableglobal()
    end
    nofsaved  = nofsaved + 1
    nofstored = nofstored + 1
    if trace_marginstack then
        showstore(store,"before",location)
    end
    if name and name ~= "" then
        -- this can be used to overload
        if inlinestore then -- todo: inline store has to be done differently (not sparse)
            local t = sortedkeys(store) for j=#t,1,-1 do local i = t[j]
                local si = store[i]
                if si.name == name then
                    local s = remove(store,i)
                    flush_node_list(s.box)
                end
            end
        else
            for i=#store,1,-1 do
                local si = store[i]
                if si.name == name then
                    local s = remove(store,i)
                    flush_node_list(s.box)
                end
            end
        end
        if trace_marginstack then
            showstore(store,"between",location)
        end
    end
    if t.number then
        local leftmargindistance  = texgetdimen("naturalleftmargindistance")
        local rightmargindistance = texgetdimen("naturalrightmargindistance")
        local strutbox            = getbox("strutbox")
        local _, strutht, strutdp = getwhd(strutbox)
        -- better make a new table and make t entry in t
        t.box                 = content
        t.n                   = nofsaved
        -- used later (we will clean up this natural mess later)
        -- nice is to make a special status table mechanism
        t.strutheight         = strutht
        t.strutdepth          = strutdp
        -- beware: can be different from the applied one (we're not in forgetall)
        t.leftskip            = texget("leftskip",false)
        t.rightskip           = texget("rightskip",false)
        --
        t.leftmargindistance  = leftmargindistance -- todo:layoutstatus table
        t.rightmargindistance = rightmargindistance
        t.leftedgedistance    = texgetdimen("naturalleftedgedistance")
                              + texgetdimen("leftmarginwidth")
                              + leftmargindistance
        t.rightedgedistance   = texgetdimen("naturalrightedgedistance")
                              + texgetdimen("rightmarginwidth")
                              + rightmargindistance
        t.lineheight          = texgetdimen("lineheight")
        --
     -- t.realpageno          = texgetcount("realpageno")
        if inline then
            local n = new_usernode(inline_mark,nofsaved)
            setattrlist(n,true)
            context(tonode(n)) -- or use a normal node
            store[nofsaved] = t -- no insert
            nofinlined = nofinlined + 1
        else
            insert(store,t)
        end
    end
    if trace_marginstack then
        showstore(store,"after",location)
    end
    if trace_margindata then
        report_margindata("saved %a, location %a, scope %a, inline %a",nofsaved,location,scope,inline)
    end
end

-- Actually it's an advantage to have them all anchored left (tags and such)
-- we could keep them in store and flush in stage two but we might want to
-- do more before that so we need the content to be there unless we can be
-- sure that we flush this first which might not be the case in the future.
--
-- When the prototype inner/outer code that was part of this proved to be
-- okay it was moved elsewhere.

local function realign(current,candidate)
    local location      = candidate.location
    local margin        = candidate.margin
    local hoffset       = candidate.hoffset
    local distance      = candidate.distance
    local hsize         = candidate.hsize
    local width         = candidate.width
    local align         = candidate.align
    local inline        = candidate.inline
    local anchor        = candidate.anchor
    local hook          = candidate.hook
    local scope         = candidate.scope
    local option        = candidate.option
    local reverse       = hook.reverse
    local atleft        = true
    local hmove         = 0
    local delta         = 0
    local leftpage      = isleftpage()
    local leftdelta     = 0
    local rightdelta    = 0
    local leftdistance  = distance
    local rightdistance = distance
    --
    if not anchor or anchor == "" then
        anchor = v_text -- this has to become more clever: region:0|column:n|column
    end
    if margin == v_normal then
        --
    elseif margin == v_local then
        leftdelta  = - candidate.leftskip
        rightdelta =   candidate.rightskip
    elseif margin == v_margin then
        leftdistance  = candidate.leftmargindistance
        rightdistance = candidate.rightmargindistance
    elseif margin == v_edge then
        leftdistance  = candidate.leftedgedistance
        rightdistance = candidate.rightedgedistance
    end
    if leftpage then
        leftdistance, rightdistance = rightdistance, leftdistance
    end
    if location == v_right then
        atleft = false
    elseif location == v_inner then
        if leftpage then
            atleft = false
        end
    elseif location == v_outer then
        if not leftpage then
            atleft = false
        end
    else
        -- v_left
    end

    local islocal = scope == v_local
    local area    = (not islocal or option[v_text]) and anchor or nil

    if atleft then
        delta = hoffset + leftdelta  + leftdistance
    else
        delta = hoffset + rightdelta + rightdistance
    end

    local delta, hmove = calculatedelta (
        hook,                -- the line
        width,               -- width of object
        delta,               -- offset
        atleft,
        islocal,             -- islocal
        option[v_paragraph], -- followshape
        area                 -- relative to area
    )

    if hmove ~= 0 then
        delta = delta + hmove
        if trace_margindata then
            report_margindata("realigned %a, location %a, margin %a, move %p",candidate.n,location,margin,hmove)
        end
    else
        if trace_margindata then
            report_margindata("realigned %a, location %a, margin %a",candidate.n,location,margin)
        end
    end
    moveinline(hook,candidate.node,delta)
end

local function realigned(current,candidate)
    realign(current,candidate)
    nofdelayed = nofdelayed - 1
    setprop(current,"margindata",false)
    return true
end

-- Stacking is done in two ways: the v_yes option stacks per paragraph (or line,
-- depending on what gets by) and mostly concerns margin data dat got set at more or
-- less the same time. The v_continue option uses position tracking and works on
-- larger range. However, crossing pages is not part of it. Anyway, when you have
-- such messed up margin data you'd better think twice.
--
-- The stacked table keeps track (per location) of the offsets (the v_yes case). This
-- table gets saved when the v_continue case is active. We use a special variant
-- of position tracking, after all we only need the page number and vertical position.

local validstacknames = {
    [v_left ] = v_left ,
    [v_right] = v_right,
    [v_inner] = v_inner,
    [v_outer] = v_outer,
}

local cache   = { }
local stacked = { [v_yes] = { }, [v_continue] = { } }
local anchors = { [v_yes] = { }, [v_continue] = { } }

local function resetstacked(all)
    stacked[v_yes] = { }
    anchors[v_yes] = { }
    if all then
        stacked[v_continue] = { }
        anchors[v_continue] = { }
    end
end

-- anchors are only set for lines that have a note

local function sa(specification) -- maybe l/r keys ipv left/right keys
    local tag = specification.tag
    local p   = cache[tag]
    if p then
        if trace_marginstack then
            report_margindata("updating anchor %a",tag)
        end
        p.p = true
        p.y = true
        -- maybe settobesaved first
        setposition("md:v",tag,p)
        cache[tag] = nil -- do this later, per page a cleanup
    end
end

local function setanchor(v_anchor) -- freezes the global here
    return latelua { action = sa, tag = v_anchor }
end

local function aa(specification) -- maybe l/r keys ipv left/right keys
    local tag = specification.tag
    local n   = specification.n
    local p   = jobpositions.gettobesaved('md:v',tag)
    if p then
        if trace_marginstack then
            report_margindata("updating injected %a",tag)
        end
        local pages = p.pages
        if not pages then
            pages = { }
            p.pages = pages
        end
        pages[n] = texgetcount("realpageno")
    elseif trace_marginstack then
        report_margindata("not updating injected %a",tag)
    end
end

local function addtoanchor(v_anchor,n) -- freezes the global here
    return latelua { action = aa, tag = v_anchor, n = n }
end

local function markovershoot(current) -- todo: alleen als offset > line
    v_anchors = v_anchors + 1
    cache[v_anchors] = fastcopy(stacked)
    local anchor = setanchor(v_anchors)
 -- local list = hpack_nodes(setlink(anchor,getlist(current))) -- not ok, we need to retain width
 -- local list = setlink(anchor,getlist(current)) -- why not this ... better play safe
    local list = hpack_nodes(setlink(anchor,getlist(current)),getwidth(current),"exactly")--
    if trace_marginstack then
        report_margindata("marking anchor %a",v_anchors)
    end
    setlist(current,list)
end

local function inject(parent,head,candidate)
    local box = candidate.box
    if not box then
        return head, nil, false -- we can have empty texts
    end
    local width, height, depth
                       = getwhd(box)
    local shift        = getshift(box)
    local stack        = candidate.stack
    local stackname    = candidate.stackname
    local location     = candidate.location
    local method       = candidate.method
    local voffset      = candidate.voffset
    local line         = candidate.line
    local baseline     = candidate.baseline
    local strutheight  = candidate.strutheight
    local strutdepth   = candidate.strutdepth
    local inline       = candidate.inline
    local psubtype     = getsubtype(parent)
    -- This stackname is experimental and therefore undocumented and basically
    -- unsupported. It was introduced when we needed to support overlapping
    -- of different anchors.
    if not stackname or stackname == "" then
        stackname = location
    else
        stackname = validstacknames[stackname] or location
    end
    local isstacked    = stack == v_continue or stack == v_yes
    local offset       = isstacked and stacked[stack][stackname]
    local firstonstack = offset == false or offset == nil
    nofinjected        = nofinjected + 1
    nofdelayed         = nofdelayed + 1
    -- yet untested
    baseline = tonumber(baseline)
    if not baseline then
        baseline = toboolean(baseline)
    end
    --
    if baseline == true then
        baseline = false
    else
        baseline = tonumber(baseline)
        if not baseline or baseline <= 0 then
            -- in case we have a box of width 0 that is not analyzed
            baseline = false -- strutheight -- actually a hack
        end
    end
    candidate.width     = width
    candidate.hsize     = getwidth(parent) -- we can also pass textwidth
    candidate.psubtype  = psubtype
    candidate.stackname = stackname
    if trace_margindata then
        report_margindata("processing, index %s, height %p, depth %p, parent %a, method %a",candidate.n,height,depth,listcodes[psubtype],method)
    end
    -- Overlap detection is somewhat complex because we have display and inline
    -- notes mixed as well as inner and outer positioning. We do need to
    -- handle it in the stream because we also keep lines together so we keep
    -- track of page numbers of notes.

    if isstacked then
        firstonstack = true
        local anchor = getposition("md:v")
        if anchor and (location == v_inner or location == v_outer) then
            local pages = anchor.pages
            if pages then
                local page = pages[nofinjected]
                if page then
                    if isleftpage(page) then
                        stackname = location == v_inner and v_right or v_left
                    else
                        stackname = location == v_inner and v_left or v_right
                    end
                    candidate.stackname = stackname
                    offset              = stack and stack ~= "" and stacked[stack][stackname]
                end
            end
        end
        local current  = v_anchors + 1
        local previous = anchors[stack][stackname]
        if trace_margindata then
            report_margindata("anchor %i, offset so far %p",current,offset or 0)
        end
        local ap = anchor and anchor[previous]
        local ac = anchor and anchor[current]
        if not previous then
        elseif previous == current then
            firstonstack = false
        elseif ap and ac and ap.p == ac.p then
            local distance = (ap.y or 0) - (ac.y or 0)
            if trace_margindata then
                report_margindata("distance %p",distance)
            end
            if offset > distance then
                -- we already overflow
                offset = offset - distance
                firstonstack = false
            else
                offset = 0
            end
        else
            -- what to do
        end
        anchors[v_yes]     [stackname] = current
        anchors[v_continue][stackname] = current
        if firstonstack then
            offset = 0
        end
        offset = offset + candidate.dy -- always
        shift  = shift + offset
    else
        if firstonstack then
            offset = 0
        end
        offset = offset + candidate.dy -- always
        shift  = shift + offset
    end
    -- Maybe we also need to patch offset when we apply methods, but how ...
    -- This needs a bit of playing as it depends on the stack setting of the
    -- following which we don't know yet ... so, consider stacking partially
    -- experimental.
    if method == v_top then
        local delta = height - getheight(parent)
        if trace_margindata then
            report_margindata("top aligned by %p",delta)
        end
        if delta < candidate.threshold then -- often we need a negative threshold here
            shift = shift + voffset + delta
        end
    elseif method == v_line then
        local _, ph, pd = getwhd(parent)
        if pd == 0 then
            local delta = height - ph
            if trace_margindata then
                report_margindata("top aligned by %p (no depth)",delta)
            end
            if delta < candidate.threshold then -- often we need a negative threshold here
                shift = shift + voffset + delta
            end
        end
    elseif method == v_first then
        if baseline then
            shift = shift + voffset + height - baseline -- option
        else
            shift = shift + voffset -- normal
        end
        if trace_margindata then
            report_margindata("first aligned")
        end
    elseif method == v_depth then
        local delta = strutdepth
        if trace_margindata then
            report_margindata("depth aligned by %p",delta)
        end
        shift = shift + voffset + delta
    elseif method == v_height then
        local delta = - strutheight
        if trace_margindata then
            report_margindata("height aligned by %p",delta)
        end
        shift = shift + voffset + delta
    elseif voffset ~= 0 then
        if trace_margindata then
            report_margindata("voffset %p applied",voffset)
        end
        shift = shift + voffset
    end
    -- -- --
    if line ~= 0 then
        local delta = line * candidate.lineheight
        if trace_margindata then
            report_margindata("offset %p applied to line %s",delta,line)
        end
        shift  = shift + delta
        offset = offset + delta
    end
    setshift(box,shift)
    setwidth(box,0) -- not needed when wrapped
    --
    if isstacked then
        setlink(box,addtoanchor(v_anchors,nofinjected))
        box = new_hlist(box)
        -- set height / depth ?
    end
    --
    candidate.hook, candidate.node = addtoline(parent,box)
    --
    setprop(box,"margindata",candidate)
    if trace_margindata then
        report_margindata("injected, location %a, stack %a, shift %p",location,stackname,shift)
    end
    -- we need to add line etc to offset as well
    offset = offset + depth
    local room = {
        height     = height,
        depth      = offset,
        slack      = candidate.bottomspace, -- todo: 'depth' => strutdepth
        lineheight = candidate.lineheight,  -- only for tracing
        stacked    = inline and isstacked,
    }
    offset = offset + height
    -- we need a restart ... when there is no overlap at all
    stacked[v_yes]     [stackname] = offset
    stacked[v_continue][stackname] = offset
    -- todo: if no real depth then zero
    if trace_margindata then
        report_margindata("status, offset %s",offset)
    end
    return getlist(parent), room, inline and isstacked or (stack == v_continue)
end

local function flushinline(parent,head)
    local current = head
    local done = false
    local continue = false
    local room, don, con, list
    while current and nofinlined > 0 do
        local id = getid(current)
        if id == whatsit_code then
            if getsubtype(current) == userdefined_code and getprop(current,"id") == inline_mark then
                local n = getprop(current,"data")
                local candidate = inlinestore[n]
                if candidate then -- no vpack, as we want to realign
                    inlinestore[n] = nil
                    nofinlined = nofinlined - 1
                    head, room, con = inject(parent,head,candidate) -- maybe return applied offset
                    done      = true
                    continue  = continue or con
                    nofstored = nofstored - 1
                    if room and room.stacked then
                        -- for now we also check for inline+yes/continue, maybe someday no such check
                        -- will happen; we can assume most inlines are one line heigh; also this
                        -- together feature can become optional
                        registertogether(parent,room)
                    end
                end
            end
        elseif id == hlist_code or id == vlist_code then
            -- optional (but sometimes needed)
            list, don, con = flushinline(current,getlist(current))
            setlist(current,list)
            continue = continue or con
            done = done or don
        end
        current = getnext(current)
    end
    return head, done, continue
end

local function flushed(scope,parent) -- current is hlist
    local head = getlist(parent)
    local done = false
    local continue = false
    local room, con, don
    for c=1,#categories do
        local category = categories[c]
        for l=1,#locations do
            local location = locations[l]
            local store = displaystore[category][location][scope]
            if store then
                while true do
                    local candidate = remove(store,1) -- brr, local stores are sparse
                    if candidate then -- no vpack, as we want to realign
                        head, room, con = inject(parent,head,candidate)
                        done      = true
                        continue  = continue or con
                        nofstored = nofstored - 1
                        if room then
                            registertogether(parent,room)
                        end
                    else
                        break
                    end
                end
            else
             -- report_margindata("fatal error: invalid category %a",category or "?")
            end
        end
    end
    if nofinlined > 0 then
        if done then
            setlist(parent,head)
        end
        head, don, con = flushinline(parent,head)
        continue = continue or con
        done = done or don
    end
    if done then
        local a = getattr(head,a_linenumber) -- hack .. we need a more decent critical attribute inheritance mechanism
        if false then
            local l = hpack_nodes(head,getwidth(parent),"exactly")
            setlist(parent,l)
            if a then
                setattr(l,a_linenumber,a)
            end
        else
            -- because packing messes up profiling
            setlist(parent,head)
            if a then
                setattr(parent,a_linenumber,a)
            end
        end
    end
    return done, continue
end

-- only when group   : vbox|vmode_par
-- only when subtype : line, box (no indent alignment cell)

local function handler(scope,head,group)
   if nofstored > 0 then
        if trace_margindata then
            report_margindata("flushing stage one, stored %s, scope %s, delayed %s, group %a",nofstored,scope,nofdelayed,group)
        end
        local current = head
        local done    = false -- for tracing only
        while current do
            local id = getid(current)
            if (id == vlist_code or id == hlist_code) and getprop(current,"margindata") == nil then
                local don, continue = flushed(scope,current)
                if don then
                    done = true
                    setprop(current,"margindata",false) -- signal to prevent duplicate processing
                    if continue then
                        markovershoot(current)
                    end
                    if nofstored <= 0 then
                        break
                    end
                end
            end
            current = getnext(current)
        end
        if trace_margindata then
            if done then
                report_margindata("flushing stage one, done, %s left",nofstored)
            else
                report_margindata("flushing stage one, nothing done, %s left",nofstored)
            end
        end
        resetstacked()
    end
    return head
end

local trialtypesetting = context.trialtypesetting

-- maybe change this to an action applied to the to be shipped out box (that is
-- the mvl list in there so that we don't need to traverse global

function margins.localhandler(head,group) -- sometimes group is "" which is weird

    if trialtypesetting() then
        return head
    end

    local inhibit = conditionals.inhibitmargindata
    if inhibit then
        if trace_margingroup then
            report_margindata("ignored 3, group %a, stored %s, inhibit %a",group,nofstored,inhibit)
        end
        return head
    end
    if nofstored > 0 then
        return handler(v_local,head,group)
    end
    if trace_margingroup then
        report_margindata("ignored 4, group %a, stored %s, inhibit %a",group,nofstored,inhibit)
    end
    return head
end

function margins.globalhandler(head,group) -- check group

    if trialtypesetting() then
        return head, false
    end

    local inhibit = conditionals.inhibitmargindata
    if inhibit or nofstored == 0 then
        if trace_margingroup then
            report_margindata("ignored 1, group %a, stored %s, inhibit %a",group,nofstored,inhibit)
        end
        return head
    elseif group == "hmode_par" then
        return handler(v_global,head,group)
    elseif group == "vmode_par" then              -- experiment (for alignments)
        return handler(v_global,head,group)
     -- this needs checking as we then get quite some one liners to process and
     -- we cannot look ahead then:
    elseif group == "box" then                    -- experiment (for alignments)
        return handler(v_global,head,group)
    elseif group == "alignment" then              -- experiment (for alignments)
        return handler(v_global,head,group)
    else
        if trace_margingroup then
            report_margindata("ignored 2, group %a, stored %s, inhibit %a",group,nofstored,inhibit)
        end
        return head
    end
end

local function finalhandler(head)
    if nofdelayed > 0 then
        local current = head
        while current and nofdelayed > 0 do -- traverse_list
            local id = getid(current)
            if id == hlist_code then -- only lines?
                local a = getprop(current,"margindata")
                if not a then
                    finalhandler(getlist(current))
                elseif realigned(current,a) then
                    if nofdelayed == 0 then
                        return head, true
                    end
                end
            elseif id == vlist_code then
                finalhandler(getlist(current))
            end
            current = getnext(current)
        end
    end
    return head
end

function margins.finalhandler(head)
    if nofdelayed > 0 then
        if trace_margindata then
            report_margindata("flushing stage two, instore: %s, delayed: %s",nofstored,nofdelayed)
        end
        head = finalhandler(head)
        resetstacked(nofdelayed==0)
    else
        resetstacked()
    end
    return head
end

-- Somehow the vbox builder (in combinations) gets pretty confused and decides to
-- go horizontal. So this needs more testing.

enablelocal = function()
    enableaction("finalizers", "typesetters.margins.localhandler")
    enableaction("shipouts",   "typesetters.margins.finalhandler")
    enablelocal = nil
end

enableglobal = function()
    enableaction("mvlbuilders", "typesetters.margins.globalhandler")
    enableaction("shipouts",    "typesetters.margins.finalhandler")
    enableglobal = nil
end

statistics.register("margin data", function()
    if nofsaved > 0 then
        return format("%s entries, %s pending",nofsaved,nofdelayed)
    else
        return nil
    end
end)

interfaces.implement {
    name      = "savemargindata",
    actions   = margins.save,
    arguments = {
        {
           { "location" },
           { "method" },
           { "category" },
           { "name" },
           { "scope" },
           { "number", "integer" },
           { "margin" },
           { "distance", "dimen" },
           { "hoffset", "dimen" },
           { "voffset", "dimen" },
           { "dy", "dimen" },
           { "bottomspace", "dimen" },
           { "baseline"}, -- dimen or string or
           { "threshold", "dimen" },
           { "inline", "boolean" },
           { "anchor" },
        -- { "leftskip", "dimen" },
        -- { "rightskip", "dimen" },
           { "align" },
           { "option" },
           { "line", "integer" },
           { "index", "integer" },
           { "stackname" },
           { "stack" },
        }
    }
}
