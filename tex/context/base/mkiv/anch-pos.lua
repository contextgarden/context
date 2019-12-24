if not modules then modules = { } end modules ['anch-pos'] = {
    version   = 1.001,
    comment   = "companion to anch-pos.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>We save positional information in the main utility table. Not only
can we store much more information in <l n='lua'/> but it's also
more efficient.</p>
--ldx]]--

-- plus (extra) is obsolete but we will keep it for a while

-- maybe replace texsp by our own converter (stay at the lua end)
-- eventually mp will have large numbers so we can use sp there too

-- this is one of the first modules using scanners and we need to replace
-- it by implement and friends

-- we could have namespaces, like p, page, region, columnarea, textarea but then
-- we need virtual table accessors as well as have tag/id accessors ... we don't
-- save much here (at least not now)

local tostring, next, setmetatable, tonumber = tostring, next, setmetatable, tonumber
local sort = table.sort
local format, gmatch = string.format, string.gmatch
local lpegmatch = lpeg.match
local insert, remove = table.insert, table.remove
local allocate = utilities.storage.allocate

local report            = logs.reporter("positions")

local scanners          = tokens.scanners
local scanstring        = scanners.string
local scaninteger       = scanners.integer
local scandimen         = scanners.dimen

local compilescanner    = tokens.compile
local scanners          = interfaces.scanners

local commands          = commands
local context           = context

local ctx_latelua       = context.latelua

local tex               = tex
local texgetcount       = tex.getcount
local texsetcount       = tex.setcount
local texget            = tex.get
local texsp             = tex.sp
----- texsp             = string.todimen -- because we cache this is much faster but no rounding

local setmetatableindex    = table.setmetatableindex
local setmetatablenewindex = table.setmetatablenewindex

local nuts              = nodes.nuts

local setlink           = nuts.setlink
local getlist           = nuts.getlist
local setlist           = nuts.setlist
local getbox            = nuts.getbox
local getid             = nuts.getid
local getwhd            = nuts.getwhd

local hlist_code        = nodes.nodecodes.hlist

local find_tail         = nuts.tail
----- hpack             = nuts.hpack

local new_latelua       = nuts.pool.latelua

local variables         = interfaces.variables
local v_text            = variables.text
local v_column          = variables.column

local pt                = number.dimenfactors.pt
local pts               = number.pts
local formatters        = string.formatters

local collected         = allocate()
local tobesaved         = allocate()

local jobpositions = {
    collected = collected,
    tobesaved = tobesaved,
}

job.positions = jobpositions

local default = { -- not r and paragraphs etc
    __index = {
        x   = 0,     -- x position baseline
        y   = 0,     -- y position baseline
        w   = 0,     -- width
        h   = 0,     -- height
        d   = 0,     -- depth
        p   = 0,     -- page
        n   = 0,     -- paragraph
        ls  = 0,     -- leftskip
        rs  = 0,     -- rightskip
        hi  = 0,     -- hangindent
        ha  = 0,     -- hangafter
        hs  = 0,     -- hsize
        pi  = 0,     -- parindent
        ps  = false, -- parshape
        dir = 0,
    }
}

local f_b_tag     = formatters["b:%s"]
local f_e_tag     = formatters["e:%s"]
local f_p_tag     = formatters["p:%s"]
local f_w_tag     = formatters["w:%s"]

local f_region    = formatters["region:%s"]

local f_tag_three = formatters["%s:%s:%s"]
local f_tag_two   = formatters["%s:%s"]

local nofregular  = 0
local nofspecial  = 0
local splitter    = lpeg.splitat(":",true)

local pagedata   = { }
local columndata = setmetatableindex("table") -- per page
local freedata   = setmetatableindex("table") -- per page

local function initializer()
    tobesaved = jobpositions.tobesaved
    collected = jobpositions.collected
    for tag, data in next, collected do
        local prefix, rest = lpegmatch(splitter,tag)
        if prefix == "p" then
            nofregular = nofregular + 1
        elseif prefix == "page" then
            nofregular = nofregular + 1
            pagedata[tonumber(rest) or 0] = data
        elseif prefix == "free" then
            nofspecial = nofspecial + 1
            local t = freedata[data.p or 0]
            t[#t+1] = data
        elseif prefix == "columnarea" then
            columndata[data.p or 0][data.c or 0] = data
        end
        setmetatable(data,default)
    end
    --
    local pages = structures.pages.collected
    if pages then
        local last = nil
        for p=1,#pages do
            local region = "page:" .. p
            local data   = pagedata[p]
            local free   = freedata[p]
            if free then
                sort(free,function(a,b) return b.y < a.y end) -- order matters !
            end
            if data then
                last      = data
                last.free = free
            elseif last then
                local t = setmetatableindex({ free = free, p = p },last)
                if not collected[region] then
                    collected[region] = t
                else
                    -- something is wrong
                end
                pagedata[p] = t
            end
        end
    end
    jobpositions.pagedata   = pagedata
end

function jobpositions.used()
    return next(collected) -- we can safe it
end

function jobpositions.getfree(page)
    return freedata[page]
end

-- we can gain a little when we group positions but then we still have to
-- deal with regions and cells so we either end up with lots of extra small
-- tables pointing to them and/or assembling/disassembling so in the end
-- it makes no sense to do it (now) and still have such a mix
--
-- proof of concept code removed ... see archive

local function finalizer()
    -- We make the (possible extensive) shape lists sparse working
    -- from the end. We could also drop entries here that have l and
    -- r the same which saves testing later on.
    for k, v in next, tobesaved do
        local s = v.s
        if s then
            for p, data in next, s do
                local n = #data
                if n > 1 then
                    local ph = data[1][2]
                    local pd = data[1][3]
                    local xl = data[1][4]
                    local xr = data[1][5]
                    for i=2,n do
                        local di = data[i]
                        local h = di[2]
                        local d = di[3]
                        local l = di[4]
                        local r = di[5]
                        if r == xr then
                            di[5] = nil
                            if l == xl then
                                di[4] = nil
                                if d == pd then
                                    di[3] = nil
                                    if h == ph then
                                        di[2] = nil
                                    else
                                        ph = h
                                    end
                                else
                                    pd, ph = d, h
                                end
                            else
                                ph, pd, xl = h, d, l
                            end
                        else
                            ph, pd, xl, xr = h, d, l, r
                        end
                    end
                end
            end
        end
    end
end

job.register('job.positions.collected', tobesaved, initializer, finalizer)

local regions    = { }
local nofregions = 0
local region     = nil

local columns    = { }
local nofcolumns = 0
local column     = nil

local nofpages   = nil

-- beware ... we're not sparse here as lua will reserve slots for the nilled

local getpos, gethpos, getvpos

function jobpositions.registerhandlers(t)
    getpos  = t and t.getpos  or function() return 0, 0 end
    getrpos = t and t.getrpos or function() return 0, 0, 0 end
    gethpos = t and t.gethpos or function() return 0 end
    getvpos = t and t.getvpos or function() return 0 end
end

function jobpositions.getpos () return getpos () end
function jobpositions.getrpos() return getrpos() end
function jobpositions.gethpos() return gethpos() end
function jobpositions.getvpos() return getvpos() end

-------- jobpositions.getcolumn() return column end

jobpositions.registerhandlers()

local function setall(name,p,x,y,w,h,d,extra)
    tobesaved[name] = {
        p = p,
        x = x ~= 0 and x or nil,
        y = y ~= 0 and y or nil,
        w = w ~= 0 and w or nil,
        h = h ~= 0 and h or nil,
        d = d ~= 0 and d or nil,
        e = extra ~= "" and extra or nil,
        r = region,
        c = column,
        r2l = texgetcount("inlinelefttoright") == 1 and true or nil,
    }
end

local function enhance(data)
    if not data then
        return nil
    end
    if data.r == true then -- or ""
        data.r = region
    end
    if data.x == true then
        if data.y == true then
            local x, y = getpos()
            data.x = x ~= 0 and x or nil
            data.y = y ~= 0 and y or nil
        else
            local x = gethpos()
            data.x = x ~= 0 and x or nil
        end
    elseif data.y == true then
        local y = getvpos()
        data.y = y ~= 0 and y or nil
    end
    if data.p == true then
        data.p = texgetcount("realpageno") -- we should use a variable set in otr
    end
    if data.c == true then
        data.c = column
    end
    if data.w == 0 then
        data.w = nil
    end
    if data.h == 0 then
        data.h = nil
    end
    if data.d == 0 then
        data.d = nil
    end
    return data
end

-- analyze some files (with lots if margindata) and then when one key optionally
-- use that one instead of a table (so, a 3rd / 4th argument: key, e.g. "x")

local function set(name,index,value) -- ,key
    -- officially there should have been a settobesaved
    local data = enhance(value or {})
    if value then
        container = tobesaved[name]
        if not container then
            tobesaved[name] = {
                [index] = data
            }
        else
            container[index] = data
        end
    else
        tobesaved[name] = data
    end
end

local function setspec(specification)
    local name  = specification.name
    local index = specification.index
    local value = specification.value
    local data  = enhance(value or {})
    if value then
        container = tobesaved[name]
        if not container then
            tobesaved[name] = {
                [index] = data
            }
        else
            container[index] = data
        end
    else
        tobesaved[name] = data
    end
end

local function get(id,index)
    if index then
        local container = collected[id]
        return container and container[index]
    else
        return collected[id]
    end
end

------------.setdim  = setdim
jobpositions.setall  = setall
jobpositions.set     = set
jobpositions.setspec = setspec
jobpositions.get     = get

scanners.dosaveposition = compilescanner {
    actions   = setall, -- name p x y
    arguments = { "string", "integer", "dimen", "dimen" }
}

scanners.dosavepositionwhd = compilescanner { -- somehow fails
    actions   = setall, -- name p x y w h d
    arguments = { "string", "integer", "dimen", "dimen", "dimen", "dimen", "dimen" }
}

scanners.dosavepositionplus = compilescanner {
    actions   = setall,  -- name p x y w h d extra
    arguments = { "string", "integer", "dimen", "dimen", "dimen", "dimen", "dimen", "string" }
}

-- will become private table (could also become attribute driven but too nasty
-- as attributes can bleed e.g. in margin stuff)

-- not much gain in keeping stack (inc/dec instead of insert/remove)

local function b_column(specification)
    local tag = specification.tag
    local x = gethpos()
    tobesaved[tag] = {
        r = true,
        x = x ~= 0 and x or nil,
     -- w = 0,
    }
    insert(columns,tag)
    column = tag
end

local function e_column()
    local t = tobesaved[column]
    if not t then
        -- something's wrong
    else
        local x = gethpos() - t.x
        t.w = x ~= 0 and x or nil
        t.r = region
    end
    remove(columns)
    column = columns[#columns]
end

jobpositions.b_column = b_column
jobpositions.e_column = e_column

scanners.bposcolumn = function() -- tag
    local tag = scanstring()
    insert(columns,tag)
    column = tag
end

scanners.bposcolumnregistered = function() -- tag
    local tag = scanstring()
    insert(columns,tag)
    column = tag
    ctx_latelua { action = b_column, tag = tag }
end

scanners.eposcolumn = function()
    remove(columns)
    column = columns[#columns]
end

scanners.eposcolumnregistered = function()
    ctx_latelua { action = e_column }
    remove(columns)
    column = columns[#columns]
end

-- regions

local function b_region(specification)
    local tag  = specification.tag or specification
    local last = tobesaved[tag]
    local x, y = getpos()
    last.x = x ~= 0 and x or nil
    last.y = y ~= 0 and y or nil
    last.p = texgetcount("realpageno")
    insert(regions,tag) -- todo: fast stack
    region = tag
end

local function e_region(specification)
    local last = tobesaved[region]
    local y = getvpos()
    local x, y = getpos()
    if specification.correct then
        local h = (last.y or 0) - y
        last.h = h ~= 0 and h or nil
    end
    last.y = y ~= 0 and y or nil
    remove(regions) -- todo: fast stack
    region = regions[#regions]
end

jobpositions.b_region = b_region
jobpositions.e_region = e_region

local lastregion

local function setregionbox(n,tag,k,lo,ro,to,bo,column) -- kind
    if not tag or tag == "" then
        nofregions = nofregions + 1
        tag = f_region(nofregions)
    end
    local box = getbox(n)
    local w, h, d = getwhd(box)
    tobesaved[tag] = {
     -- p  = texgetcount("realpageno"), -- we copy them
        x  = 0,
        y  = 0,
        w  = w  ~= 0 and w  or nil,
        h  = h  ~= 0 and h  or nil,
        d  = d  ~= 0 and d  or nil,
        k  = k  ~= 0 and k  or nil,
        lo = lo ~= 0 and lo or nil,
        ro = ro ~= 0 and ro or nil,
        to = to ~= 0 and to or nil,
        bo = bo ~= 0 and bo or nil,
        c  = column         or nil,
    }
    lastregion = tag
    return tag, box
end

local function markregionbox(n,tag,correct,...) -- correct needs checking
    local tag, box = setregionbox(n,tag,...)
     -- todo: check if tostring is needed with formatter
    local push = new_latelua { action = b_region, tag = tag }
    local pop  = new_latelua { action = e_region, correct = correct }
    -- maybe we should construct a hbox first (needs experimenting) so that we can avoid some at the tex end
    local head = getlist(box)
    -- no, this fails with \framed[region=...] .. needs thinking
 -- if getid(box) ~= hlist_code then
 --  -- report("mark region box assumes a hlist, fix this for %a",tag)
 --     head = hpack(head)
 -- end
    if head then
        local tail = find_tail(head)
        setlink(push,head)
        setlink(tail,pop)
    else -- we can have a simple push/pop
        setlink(push,pop)
    end
    setlist(box,push)
end

jobpositions.markregionbox = markregionbox
jobpositions.setregionbox  = setregionbox

function jobpositions.enhance(name)
    enhance(tobesaved[name])
end

function jobpositions.gettobesaved(name,tag)
    local t = tobesaved[name]
    if t and tag then
        return t[tag]
    else
        return t
    end
end

function jobpositions.settobesaved(name,tag,data)
    local t = tobesaved[name]
    if t and tag and data then
        t[tag] = data
    end
end

local nofparagraphs = 0

scanners.parpos = function()
    nofparagraphs = nofparagraphs + 1
    texsetcount("global","c_anch_positions_paragraph",nofparagraphs)
    local box = getbox("strutbox")
    local w, h, d = getwhd(box)
    local t = {
        p  = true,
        c  = true,
        r  = true,
        x  = true,
        y  = true,
        h  = h,
        d  = d,
        hs = texget("hsize"),             -- never 0
    }
    local leftskip   = texget("leftskip",false)
    local rightskip  = texget("rightskip",false)
    local hangindent = texget("hangindent")
    local hangafter  = texget("hangafter")
    local parindent  = texget("parindent")
    local parshape   = texget("parshape")
    if leftskip ~= 0 then
        t.ls = leftskip
    end
    if rightskip ~= 0 then
        t.rs = rightskip
    end
    if hangindent ~= 0 then
        t.hi = hangindent
    end
    if hangafter ~= 1 and hangafter ~= 0 then -- can not be zero .. so it needs to be 1 if zero
        t.ha = hangafter
    end
    if parindent ~= 0 then
        t.pi = parindent
    end
    if parshape and #parshape > 0 then
        t.ps = parshape
    end
    local name = f_p_tag(nofparagraphs)
    tobesaved[name] = t
    ctx_latelua { action = enhance, specification = t }
end

scanners.dosetposition = function() -- name
    local name = scanstring()
    local spec = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        n = nofparagraphs > 0 and nofparagraphs or nil,
        r2l = texgetcount("inlinelefttoright") == 1 or nil,
    }
    tobesaved[name] = spec
    ctx_latelua { action = enhance, specification = spec }
end

scanners.dosetpositionwhd = function() -- name w h d extra
    local name = scanstring()
    local w    = scandimen()
    local h    = scandimen()
    local d    = scandimen()
    local spec = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        w = w ~= 0 and w or nil,
        h = h ~= 0 and h or nil,
        d = d ~= 0 and d or nil,
        n = nofparagraphs > 0 and nofparagraphs or nil,
        r2l = texgetcount("inlinelefttoright") == 1 or nil,
    }
    tobesaved[name] = spec
    ctx_latelua { action = enhance, specification = spec }
end

scanners.dosetpositionbox = function() -- name box
    local name = scanstring()
    local box  = getbox(scaninteger())
    local w, h, d = getwhd(box)
    local spec = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        w = w ~= 0 and w or nil,
        h = h ~= 0 and h or nil,
        d = d ~= 0 and d or nil,
        n = nofparagraphs > 0 and nofparagraphs or nil,
        r2l = texgetcount("inlinelefttoright") == 1 or nil,
    }
    tobesaved[name] = spec
    ctx_latelua { action = enhance, specification = spec }
end

scanners.dosetpositionplus = function() -- name w h d extra
    local name = scanstring()
    local w    = scandimen()
    local h    = scandimen()
    local d    = scandimen()
    local spec = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        w = w ~= 0 and w or nil,
        h = h ~= 0 and h or nil,
        d = d ~= 0 and d or nil,
        n = nofparagraphs > 0 and nofparagraphs or nil,
        e = scanstring(),
        r2l = texgetcount("inlinelefttoright") == 1 or nil,
    }
    tobesaved[name] = spec
    ctx_latelua { action = enhance, specification = spec }
end

scanners.dosetpositionstrut = function() -- name
    local name = scanstring()
    local box  = getbox("strutbox")
    local w, h, d = getwhd(box)
    local spec = {
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        h = h ~= 0 and h or nil,
        d = d ~= 0 and d or nil,
        n = nofparagraphs > 0 and nofparagraphs or nil,
        r2l = texgetcount("inlinelefttoright") == 1 or nil,
    }
    tobesaved[name] = spec
    ctx_latelua { action = enhance, specification = spec }
end

scanners.dosetpositionstrutkind = function() -- name
    local name = scanstring()
    local kind = scaninteger()
    local box  = getbox("strutbox")
    local w, h, d = getwhd(box)
    local spec = {
        k = kind,
        p = true,
        c = column,
        r = true,
        x = true,
        y = true,
        h = h ~= 0 and h or nil,
        d = d ~= 0 and d or nil,
        n = nofparagraphs > 0 and nofparagraphs or nil,
        r2l = texgetcount("inlinelefttoright") == 1 or nil,
    }
    tobesaved[name] = spec
    ctx_latelua { action = enhance, specification = spec }
end

function jobpositions.getreserved(tag,n)
    if tag == v_column then
        local fulltag = f_tag_three(tag,texgetcount("realpageno"),n or 1)
        local data = collected[fulltag]
        if data then
            return data, fulltag
        end
        tag = v_text
    end
    if tag == v_text then
        local fulltag = f_tag_two(tag,texgetcount("realpageno"))
        return collected[fulltag] or false, fulltag
    end
    return collected[tag] or false, tag
end

function jobpositions.copy(target,source)
    collected[target] = collected[source]
end

function jobpositions.replace(id,p,x,y,w,h,d)
    collected[id] = { p = p, x = x, y = y, w = w, h = h, d = d } -- c g
end

local function getpage(id)
    local jpi = collected[id]
    return jpi and jpi.p
end

local function getcolumn(id)
    local jpi = collected[id]
    return jpi and jpi.c or false
end

local function getparagraph(id)
    local jpi = collected[id]
    return jpi and jpi.n
end

local function getregion(id)
    local jpi = collected[id]
    if jpi then
        local r = jpi.r
        if r then
            return r
        end
        local p = jpi.p
        if p then
            return "page:" .. p
        end
    end
    return false
end

jobpositions.page      = getpage
jobpositions.column    = getcolumn
jobpositions.paragraph = getparagraph
jobpositions.region    = getregion

jobpositions.p = getpage      -- not used, kind of obsolete
jobpositions.c = getcolumn    -- idem
jobpositions.n = getparagraph -- idem
jobpositions.r = getregion    -- idem

function jobpositions.x(id)
    local jpi = collected[id]
    return jpi and jpi.x
end

function jobpositions.y(id)
    local jpi = collected[id]
    return jpi and jpi.y
end

function jobpositions.width(id)
    local jpi = collected[id]
    return jpi and jpi.w
end

function jobpositions.height(id)
    local jpi = collected[id]
    return jpi and jpi.h
end

function jobpositions.depth(id)
    local jpi = collected[id]
    return jpi and jpi.d
end

function jobpositions.whd(id)
    local jpi = collected[id]
    if jpi then
        return jpi.h, jpi.h, jpi.d
    end
end

function jobpositions.leftskip(id)
    local jpi = collected[id]
    return jpi and jpi.ls
end

function jobpositions.rightskip(id)
    local jpi = collected[id]
    return jpi and jpi.rs
end

function jobpositions.hsize(id)
    local jpi = collected[id]
    return jpi and jpi.hs
end

function jobpositions.parindent(id)
    local jpi = collected[id]
    return jpi and jpi.pi
end

function jobpositions.hangindent(id)
    local jpi = collected[id]
    return jpi and jpi.hi
end

function jobpositions.hangafter(id)
    local jpi = collected[id]
    return jpi and jpi.ha or 1
end

function jobpositions.xy(id)
    local jpi = collected[id]
    if jpi then
        return jpi.x, jpi.y
    else
        return 0, 0
    end
end

function jobpositions.lowerleft(id)
    local jpi = collected[id]
    if jpi then
        return jpi.x, jpi.y - jpi.d
    else
        return 0, 0
    end
end

function jobpositions.lowerright(id)
    local jpi = collected[id]
    if jpi then
        return jpi.x + jpi.w, jpi.y - jpi.d
    else
        return 0, 0
    end
end

function jobpositions.upperright(id)
    local jpi = collected[id]
    if jpi then
        return jpi.x + jpi.w, jpi.y + jpi.h
    else
        return 0, 0
    end
end

function jobpositions.upperleft(id)
    local jpi = collected[id]
    if jpi then
        return jpi.x, jpi.y + jpi.h
    else
        return 0, 0
    end
end

function jobpositions.position(id)
    local jpi = collected[id]
    if jpi then
        return jpi.p, jpi.x, jpi.y, jpi.w, jpi.h, jpi.d
    else
        return 0, 0, 0, 0, 0, 0
    end
end

local splitter = lpeg.splitat(",")

function jobpositions.extra(id,n,default) -- assume numbers
    local jpi = collected[id]
    if jpi then
        local e = jpi.e
        if e then
            local split = jpi.split
            if not split then
                split = lpegmatch(splitter,jpi.e)
                jpi.split = split
            end
            return texsp(split[n]) or default -- watch the texsp here
        end
    end
    return default
end

local function overlapping(one,two,overlappingmargin) -- hm, strings so this is wrong .. texsp
    one = collected[one]
    two = collected[two]
    if one and two and one.p == two.p then
        if not overlappingmargin then
            overlappingmargin = 2
        end
        local x_one = one.x
        local x_two = two.x
        local w_two = two.w
        local llx_one = x_one         - overlappingmargin
        local urx_two = x_two + w_two + overlappingmargin
        if llx_one > urx_two then
            return false
        end
        local w_one = one.w
        local urx_one = x_one + w_one + overlappingmargin
        local llx_two = x_two         - overlappingmargin
        if urx_one < llx_two then
            return false
        end
        local y_one = one.y
        local y_two = two.y
        local d_one = one.d
        local h_two = two.h
        local lly_one = y_one - d_one - overlappingmargin
        local ury_two = y_two + h_two + overlappingmargin
        if lly_one > ury_two then
            return false
        end
        local h_one = one.h
        local d_two = two.d
        local ury_one = y_one + h_one + overlappingmargin
        local lly_two = y_two - d_two - overlappingmargin
        if ury_one < lly_two then
            return false
        end
        return true
    end
end

local function onsamepage(list,page)
    for id in gmatch(list,"(, )") do
        local jpi = collected[id]
        if jpi then
            local p = jpi.p
            if not p then
                return false
            elseif not page then
                page = p
            elseif page ~= p then
                return false
            end
        end
    end
    return page
end

local function columnofpos(realpage,xposition)
    local p = columndata[realpage]
    if p then
        for i=1,#p do
            local c = p[i]
            local x = c.x or 0
            local w = c.w or 0
            if xposition >= x and xposition <= (x + w) then
                return i
            end
        end
    end
    return 1
end

jobpositions.overlapping = overlapping
jobpositions.onsamepage  = onsamepage
jobpositions.columnofpos = columnofpos

-- interface

scanners.replacepospxywhd = function() -- name page x y w h d
    collected[scanstring()] = {
        p = scaninteger(),
        x = scandimen(),
        y = scandimen(),
        w = scandimen(),
        h = scandimen(),
        d = scandimen(),
    }
end

scanners.copyposition = function() -- target source
    collected[scanstring()] = collected[scanstring()]
end

scanners.MPp = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local p = jpi.p
        if p and p ~= true then
            context(p)
            return
        end
    end
    context('0')
end

scanners.MPx = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local x = jpi.x
        if x and x ~= true and x ~= 0 then
            context("%.5Fpt",x*pt)
            return
        end
    end
    context('0pt')
end

scanners.MPy = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local y = jpi.y
        if y and y ~= true and y ~= 0 then
            context("%.5Fpt",y*pt)
            return
        end
    end
    context('0pt')
end

scanners.MPw = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local w = jpi.w
        if w and w ~= 0 then
            context("%.5Fpt",w*pt)
            return
        end
    end
    context('0pt')
end

scanners.MPh = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local h = jpi.h
        if h and h ~= 0 then
            context("%.5Fpt",h*pt)
            return
        end
    end
    context('0pt')
end

scanners.MPd = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local d = jpi.d
        if d and d ~= 0 then
            context("%.5Fpt",d*pt)
            return
        end
    end
    context('0pt')
end

scanners.MPxy = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context('(%.5Fpt,%.5Fpt)',
            jpi.x*pt,
            jpi.y*pt
        )
    else
        context('(0,0)')
    end
end

scanners.MPwhd = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local w = jpi.w or 0
        local h = jpi.h or 0
        local d = jpi.d or 0
        if w ~= 0 or h ~= 0 or d ~= 0 then
            context("%.5Fpt,%.5Fpt,%.5Fpt",w*pt,h*pt,d*pt)
            return
        end
    end
    context('0pt,0pt,0pt')
end

scanners.MPll = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context('(%.5Fpt,%.5Fpt)',
             jpi.x       *pt,
            (jpi.y-jpi.d)*pt
        )
    else
        context('(0,0)') -- for mp only
    end
end

scanners.MPlr = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context('(%.5Fpt,%.5Fpt)',
            (jpi.x + jpi.w)*pt,
            (jpi.y - jpi.d)*pt
        )
    else
        context('(0,0)') -- for mp only
    end
end

scanners.MPur = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context('(%.5Fpt,%.5Fpt)',
            (jpi.x + jpi.w)*pt,
            (jpi.y + jpi.h)*pt
        )
    else
        context('(0,0)') -- for mp only
    end
end

scanners.MPul = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context('(%.5Fpt,%.5Fpt)',
             jpi.x         *pt,
            (jpi.y + jpi.h)*pt
        )
    else
        context('(0,0)') -- for mp only
    end
end

local function MPpos(id)
    local jpi = collected[id]
    if jpi then
        local p = jpi.p
        if p then
            context("%s,%.5Fpt,%.5Fpt,%.5Fpt,%.5Fpt,%.5Fpt",
                p,
                jpi.x*pt,
                jpi.y*pt,
                jpi.w*pt,
                jpi.h*pt,
                jpi.d*pt
            )
            return
        end
    end
    context('0,0,0,0,0,0') -- for mp only
end

scanners.MPpos = function() -- name
    MPpos(scanstring())
end

scanners.MPn = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local n = jpi.n
        if n then
            context(n)
            return
        end
    end
    context(0)
end

scanners.MPc = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local c = jpi.c
        if c and c ~= true  then
            context(c)
            return
        end
    end
    context('0') -- okay ?
end

scanners.MPr = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        local r = jpi.r
        if r and r ~= true  then
            context(r)
            return
        end
        local p = jpi.p
        if p then
            context("page:" .. p)
        end
    end
end

local function MPpardata(n)
    local t = collected[n]
    if not t then
        local tag = f_p_tag(n)
        t = collected[tag]
    end
    if t then
        context("%.5Fpt,%.5Fpt,%.5Fpt,%.5Fpt,%s,%.5Fpt",
            t.hs*pt,
            t.ls*pt,
            t.rs*pt,
            t.hi*pt,
            t.ha,
            t.pi*pt
        )
    else
        context("0,0,0,0,0,0") -- for mp only
    end
end

scanners.MPpardata = function() -- name
    MPpardata(scanstring())
end

scanners.MPposset = function() -- name (special helper, used in backgrounds)
    local name = scanstring()
    local b = f_b_tag(name)
    local e = f_e_tag(name)
    local w = f_w_tag(name)
    local p = f_p_tag(getparagraph(b))
    MPpos(b) context(",") MPpos(e) context(",") MPpos(w) context(",") MPpos(p) context(",") MPpardata(p)
end

scanners.MPls = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context("%.5Fpt",jpi.ls*pt)
    else
        context("0pt")
    end
end

scanners.MPrs = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context("%.5Fpt",jpi.rs*pt)
    else
        context("0pt")
    end
end

local splitter = lpeg.tsplitat(",")

scanners.MPplus = function() -- name n default
    local jpi     = collected[scanstring()]
    local n       = scaninteger()
    local default = scanstring()
    if jpi then
        local e = jpi.e
        if e then
            local split = jpi.split
            if not split then
                split = lpegmatch(splitter,jpi.e)
                jpi.split = split
            end
            context(split[n] or default)
            return
        end
    end
    context(default)
end

scanners.MPrest = function() -- name default
    local jpi     = collected[scanstring()]
    local default = scanstring()
    context(jpi and jpi.e or default)
end

scanners.MPxywhd = function() -- name
    local jpi = collected[scanstring()]
    if jpi then
        context("%.5Fpt,%.5Fpt,%.5Fpt,%.5Fpt,%.5Fpt",
            jpi.x*pt,
            jpi.y*pt,
            jpi.w*pt,
            jpi.h*pt,
            jpi.d*pt
        )
    else
        context("0,0,0,0,0") -- for mp only
    end
end

local doif     = commands.doif
local doifelse = commands.doifelse

scanners.doifelseposition = function() -- name
    doifelse(collected[scanstring()])
end

scanners.doifposition = function() -- name
    doif(collected[scanstring()])
end

-- local ctx_iftrue  = context.protected.cs.iftrue
-- local ctx_iffalse = context.protected.cs.iffalse
--
-- scanners.ifknownposition = function() -- name
--     (collected[scanstring()] and ctx_iftrue or ctx_iffalse)()
-- end

scanners.doifelsepositiononpage = function() -- name page -- probably always realpageno
    local c = collected[scanstring()]
    local p = scaninteger()
    doifelse(c and c.p == p)
end

scanners.doifelseoverlapping = function() -- one two
    doifelse(overlapping(scanstring(),scanstring()))
end

scanners.doifelsepositionsonsamepage = function() -- list
    doifelse(onsamepage(scanstring()))
end

scanners.doifelsepositionsonthispage = function() -- list
    doifelse(onsamepage(scanstring(),tostring(texgetcount("realpageno"))))
end

-- scanners.columnofpos = function()
--     context(columnofpos(scaninteger(),scandimen())
-- end

scanners.doifelsepositionsused = function()
    doifelse(next(collected))
end

scanners.markregionbox = function() -- box
    markregionbox(scaninteger())
end

scanners.setregionbox = function() -- box
    setregionbox(scaninteger())
end

scanners.markregionboxtagged = function() -- box tag
    markregionbox(scaninteger(),scanstring())
end

scanners.markregionboxtaggedn = function() -- box tag n
    markregionbox(scaninteger(),scanstring(),nil,
        nil,nil,nil,nil,nil,scaninteger())
end

scanners.setregionboxtagged = function() -- box tag
    setregionbox(scaninteger(),scanstring())
end

scanners.markregionboxcorrected = function() -- box tag
    markregionbox(scaninteger(),scanstring(),true)
end

scanners.markregionboxtaggedkind = function() -- box tag kind
    markregionbox(scaninteger(),scanstring(),nil,
        scaninteger(),scandimen(),scandimen(),scandimen(),scandimen())
end

scanners.reservedautoregiontag = function()
    nofregions = nofregions + 1
    context(f_region(nofregions))
end

-- statistics (at least for the moment, when testing)

-- statistics.register("positions", function()
--     local total = nofregular + nofusedregions + nofmissingregions
--     if total > 0 then
--         return format("%s collected, %s regulars, %s regions, %s unresolved regions",
--             total, nofregular, nofusedregions, nofmissingregions)
--     else
--         return nil
--     end
-- end)

statistics.register("positions", function()
    local total = nofregular + nofspecial
    if total > 0 then
        return format("%s collected, %s regular, %s special",total,nofregular,nofspecial)
    else
        return nil
    end
end)

-- We support the low level positional commands too:

local newsavepos = nodes.pool.savepos
local implement  = interfaces.implement

implement { name = "savepos",  actions = function() context(newsavepos()) end }
implement { name = "lastxpos", actions = function() context(gethpos()) end }
implement { name = "lastypos", actions = function() context(getvpos()) end }
