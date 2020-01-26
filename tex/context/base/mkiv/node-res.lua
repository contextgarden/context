if not modules then modules = { } end modules ['node-res'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next = type, next
local gmatch, format = string.gmatch, string.format

--[[ldx--
<p>The next function is not that much needed but in <l n='context'/> we use
for debugging <l n='luatex'/> node management.</p>
--ldx]]--

local nodes, node = nodes, node

local report_nodes   = logs.reporter("nodes","housekeeping")

nodes.pool           = nodes.pool or { }
local nodepool       = nodes.pool

local whatsitcodes   = nodes.whatsitcodes
local gluecodes      = nodes.gluecodes
local kerncodes      = nodes.kerncodes
local rulecodes      = nodes.rulecodes
local nodecodes      = nodes.nodecodes
local leadercodes    = nodes.leadercodes
local boundarycodes  = nodes.boundarycodes
local usercodes      = nodes.usercodes

local nodeproperties = nodes.properties.data

local glyph_code     = nodecodes.glyph
local rule_code      = nodecodes.rule
local kern_code      = nodecodes.kern
local glue_code      = nodecodes.glue
local whatsit_code   = nodecodes.whatsit

local currentfont    = font.current
local texgetcount    = tex.getcount

local allocate       = utilities.storage.allocate

local reserved       = { }
local nofreserved    = 0
local userids        = allocate()
local lastid         = 0

setmetatable(userids, {
    __index = function(t,k)
        if type(k) == "string" then
            lastid = lastid + 1
            rawset(userids,lastid,k)
            rawset(userids,k,lastid)
            return lastid
        else
            rawset(userids,k,k)
            return k
        end
    end,
    __call = function(t,k)
        return t[k]
    end
} )

-- nuts overload

local nuts         = nodes.nuts
local nutpool      = { }
nuts.pool          = nutpool

local tonut        = nuts.tonut
local tonode       = nuts.tonode

local getbox       = nuts.getbox
local getid        = nuts.getid
local getlist      = nuts.getlist
local getglue      = nuts.getglue

local setfield     = nuts.setfield
local setchar      = nuts.setchar
local setlist      = nuts.setlist
local setwhd       = nuts.setwhd
local setglue      = nuts.setglue
local setdisc      = nuts.setdisc
local setfont      = nuts.setfont
local setkern      = nuts.setkern
local setpenalty   = nuts.setpenalty
local setdir       = nuts.setdir
local setdirection = nuts.setdirection
local setshift     = nuts.setshift
local setwidth     = nuts.setwidth
local setsubtype   = nuts.setsubtype
local setleader    = nuts.setleader

local setdata      = nuts.setdata
local setruledata  = nuts.setruledata
local setvalue     = nuts.setvalue

local copy_nut     = nuts.copy_only or nuts.copy
local new_nut      = nuts.new
local flush_nut    = nuts.flush

-- at some point we could have a dual set (the overhead of tonut is not much larger than
-- metatable associations at the lua/c end esp if we also take assignments into account

-- table.setmetatableindex(nodepool,function(t,k,v)
--  -- report_nodes("defining nodepool[%s] instance",k)
--     local f = nutpool[k]
--     local v = function(...)
--         return tonode(f(...))
--     end
--     t[k] = v
--     return v
-- end)
--
-- -- we delay one step because that permits us a forward reference
-- -- e.g. in pdfsetmatrix

table.setmetatableindex(nodepool,function(t,k,v)
 -- report_nodes("defining nodepool[%s] instance",k)
    local v = function(...)
        local f = nutpool[k]
        local v = function(...)
            return tonode(f(...))
        end
        t[k] = v
        return v(...)
    end
    t[k] = v
    return v
end)

local function register_nut(n)
    nofreserved = nofreserved + 1
    reserved[nofreserved] = n
    return n
end

local function register_node(n)
    nofreserved = nofreserved + 1
    if type(n) == "number" then -- isnut(n)
        reserved[nofreserved] = n
    else
        reserved[nofreserved] = tonut(n)
    end
    return n
end

nodepool.userids  = userids
nodepool.register = register_node

nutpool.userids   = userids
nutpool.register  = register_node -- could be register_nut

-- so far

local disc              = register_nut(new_nut(nodecodes.disc))
local kern              = register_nut(new_nut(kern_code,kerncodes.userkern))
local fontkern          = register_nut(new_nut(kern_code,kerncodes.fontkern))
local italickern        = register_nut(new_nut(kern_code,kerncodes.italiccorrection))
local penalty           = register_nut(new_nut(nodecodes.penalty))
local glue              = register_nut(new_nut(glue_code))
local glyph             = register_nut(new_nut(glyph_code,0))

local textdir           = register_nut(new_nut(nodecodes.dir))

local latelua           = register_nut(new_nut(whatsit_code,whatsitcodes.latelua))
local savepos           = register_nut(new_nut(whatsit_code,whatsitcodes.savepos))

local user_node         = new_nut(whatsit_code,whatsitcodes.userdefined)

if CONTEXTLMTXMODE == 0 then
    setfield(user_node,"type",usercodes.number)
end

local left_margin_kern  = register_nut(new_nut(nodecodes.marginkern,0))
local right_margin_kern = register_nut(new_nut(nodecodes.marginkern,1))

local lineskip          = register_nut(new_nut(glue_code,gluecodes.lineskip))
local baselineskip      = register_nut(new_nut(glue_code,gluecodes.baselineskip))
local leftskip          = register_nut(new_nut(glue_code,gluecodes.leftskip))
local rightskip         = register_nut(new_nut(glue_code,gluecodes.rightskip))
local lefthangskip      = register_nut(new_nut(glue_code,gluecodes.lefthangskip))
local righthangskip     = register_nut(new_nut(glue_code,gluecodes.righthangskip))
local indentskip        = register_nut(new_nut(glue_code,gluecodes.indentskip))
local correctionskip    = register_nut(new_nut(glue_code,gluecodes.correctionskip))

local temp              = register_nut(new_nut(nodecodes.temp,0))

local noad              = register_nut(new_nut(nodecodes.noad))
local delimiter         = register_nut(new_nut(nodecodes.delim))
local fence             = register_nut(new_nut(nodecodes.fence))
local submlist          = register_nut(new_nut(nodecodes.submlist))
local accent            = register_nut(new_nut(nodecodes.accent))
local radical           = register_nut(new_nut(nodecodes.radical))
local fraction          = register_nut(new_nut(nodecodes.fraction))
local subbox            = register_nut(new_nut(nodecodes.subbox))
local mathchar          = register_nut(new_nut(nodecodes.mathchar))
local mathtextchar      = register_nut(new_nut(nodecodes.mathtextchar))
local choice            = register_nut(new_nut(nodecodes.choice))

local boundary          = register_nut(new_nut(nodecodes.boundary,boundarycodes.user))
local wordboundary      = register_nut(new_nut(nodecodes.boundary,boundarycodes.word))

local cleader           = register_nut(copy_nut(glue)) setsubtype(cleader,leadercodes.cleaders) setglue(cleader,0,65536,0,2,0)

-- the dir field needs to be set otherwise crash:

local lefttoright_code  = nodes.dirvalues.lefttoright

local rule              = register_nut(new_nut(rule_code))                   setdirection(rule, lefttoright_code)
local emptyrule         = register_nut(new_nut(rule_code,rulecodes.empty))   setdirection(rule, lefttoright_code)
local userrule          = register_nut(new_nut(rule_code,rulecodes.user))    setdirection(rule, lefttoright_code)
local outlinerule       = register_nut(new_nut(rule_code,rulecodes.outline)) setdirection(rule, lefttoright_code)
local hlist             = register_nut(new_nut(nodecodes.hlist))             setdirection(hlist,lefttoright_code)
local vlist             = register_nut(new_nut(nodecodes.vlist))             setdirection(vlist,lefttoright_code)

function nutpool.glyph(fnt,chr)
    local n = copy_nut(glyph)
    if fnt then
        setfont(n,fnt == true and currentfont() or fnt,chr)
    elseif chr then
        setchar(n,chr)
    end
    return n
end

function nutpool.penalty(p)
    local n = copy_nut(penalty)
    if p and p ~= 0 then
        setpenalty(n,p)
    end
    return n
end

function nutpool.kern(k)
    local n = copy_nut(kern)
    if k and k ~= 0 then
        setkern(n,k)
    end
    return n
end

function nutpool.boundary(v)
    local n = copy_nut(boundary)
    if v and v ~= 0 then
        setvalue(n,v)
    end
    return n
end

function nutpool.wordboundary(v)
    local n = copy_nut(wordboundary)
    if v and v ~= 0 then
        setvalue(n,v)
    end
    return n
end

function nutpool.fontkern(k)
    local n = copy_nut(fontkern)
    if k and k ~= 0 then
        setkern(n,k)
    end
    return n
end

function nutpool.italickern(k)
    local n = copy_nut(italickern)
    if k and k ~= 0 then
        setkern(n,k)
    end
    return n
end

local function someskip(skip,width,stretch,shrink,stretch_order,shrink_order)
    -- maybe setglue
    local n = copy_nut(skip)
    if width or stretch or shrink or stretch_order or shrink_order then
        setglue(n,width,stretch,shrink,stretch_order,shrink_order)
    end
    return n
end

function nutpool.stretch(a,b)
    -- width stretch shrink stretch_order shrink_order
    local n = copy_nut(glue)
    if not b then
        a, b = 1, a or 1
    end
    setglue(n,0,a,0,b,0)
    return n
end

function nutpool.shrink(a,b)
    local n = copy_nut(glue)
    if not b then
        a, b = 1, a or 1
    end
    setglue(n,0,0,a,0,0,b)
    return n
end

function nutpool.glue(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(glue,width,stretch,shrink,stretch_order,shrink_order)
end

function nutpool.negatedglue(glue)
    local n = copy_nut(glue)
    local width, stretch, shrink = getglue(n)
    setglue(n,-width,-stretch,-shrink)
    return n
end

function nutpool.leftskip(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(leftskip,width,stretch,shrink,stretch_order,shrink_order)
end

function nutpool.rightskip(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(rightskip,width,stretch,shrink,stretch_order,shrink_order)
end

function nutpool.lefthangskip(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(lefthangskip,width,stretch,shrink,stretch_order,shrink_order)
end

function nutpool.righthangskip(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(righthangskip,width,stretch,shrink,stretch_order,shrink_order)
end

function nutpool.indentskip(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(indentskip,width,stretch,shrink,stretch_order,shrink_order)
end

function nutpool.lineskip(width,stretch,shrink,stretch_order,shrink_order)
    return someskip(lineskip,width,stretch,shrink,stretch_order,shrink_order)
end

function nutpool.baselineskip(width,stretch,shrink)
    return someskip(baselineskip,width,stretch,shrink)
end

function nutpool.disc(pre,post,replace)
    local d = copy_nut(disc)
    if pre or post or replace then
        setdisc(d,pre,post,replace)
    end
    return d
end

function nutpool.direction(dir,swap)
    local t = copy_nut(textdir)
    if not dir then
        -- just a l2r start node
    elseif swap then
        setdirection(t,dir,true)
    else
        setdirection(t,dir,false)
    end
    return t
end

function nutpool.rule(width,height,depth) -- w/h/d == nil will let them adapt
    local n = copy_nut(rule)
    if width or height or depth then
        setwhd(n,width,height,depth)
    end
    return n
end

function nutpool.emptyrule(width,height,depth) -- w/h/d == nil will let them adapt
    local n = copy_nut(emptyrule)
    if width or height or depth then
        setwhd(n,width,height,depth)
    end
    return n
end

function nutpool.userrule(width,height,depth) -- w/h/d == nil will let them adapt
    local n = copy_nut(userrule)
    if width or height or depth then
        setwhd(n,width,height,depth)
    end
    return n
end

function nutpool.outlinerule(width,height,depth,line) -- w/h/d == nil will let them adapt
    local n = copy_nut(outlinerule)
    if width or height or depth then
        setwhd(n,width,height,depth)
    end
    if line then
        setruledata(n,line)
    end
    return n
end

function nutpool.leader(width,list)
    local n = copy_nut(cleader)
    if width then
        setwidth(n,width)
    end
    if list then
        setleader(n,list)
    end
    return n
end

function nutpool.savepos()
    return copy_nut(savepos)
end

if CONTEXTLMTXMODE == 0 then

    function nutpool.latelua(code)
        local n = copy_nut(latelua)
        if type(code) == "table" then
            local action        = code.action
            local specification = code.specification or code
            code = function() action(specification) end
        end
        setdata(n,code)
        return n
    end

else

    function nutpool.latelua(code)
        local n = copy_nut(latelua)
        nodeproperties[n] = { data = code }
        return n
    end

end

function nutpool.leftmarginkern(glyph,width)
    local n = copy_nut(left_margin_kern)
    if not glyph then
        report_nodes("invalid pointer to left margin glyph node")
    elseif getid(glyph) ~= glyph_code then
        report_nodes("invalid node type %a for %s margin glyph node",nodecodes[glyph],"left")
    else
        setfield(n,"glyph",glyph)
    end
    if width and width ~= 0 then
        setwidth(n,width)
    end
    return n
end

function nutpool.rightmarginkern(glyph,width)
    local n = copy_nut(right_margin_kern)
    if not glyph then
        report_nodes("invalid pointer to right margin glyph node")
    elseif getid(glyph) ~= glyph_code then
        report_nodes("invalid node type %a for %s margin glyph node",nodecodes[p],"right")
    else
        setfield(n,"glyph",glyph)
    end
    if width and width ~= 0 then
        setwidth(n,width)
    end
    return n
end

function nutpool.temp()
    return copy_nut(temp)
end

function nutpool.noad()         return copy_nut(noad)         end
function nutpool.delimiter()    return copy_nut(delimiter)    end  nutpool.delim = nutpool.delimiter
function nutpool.fence()        return copy_nut(fence)        end
function nutpool.submlist()     return copy_nut(submlist)     end
function nutpool.noad()         return copy_nut(noad)         end
function nutpool.fence()        return copy_nut(fence)        end
function nutpool.accent()       return copy_nut(accent)       end
function nutpool.radical()      return copy_nut(radical)      end
function nutpool.fraction()     return copy_nut(fraction)     end
function nutpool.subbox()       return copy_nut(subbox)       end
function nutpool.mathchar()     return copy_nut(mathchar)     end
function nutpool.mathtextchar() return copy_nut(mathtextchar) end
function nutpool.choice()       return copy_nut(choice)       end

local function new_hlist(list,width,height,depth,shift)
    local n = copy_nut(hlist)
    if list then
        setlist(n,list)
    end
    if width or height or depth then
        setwhd(n,width,height,depth)
    end
    if shift and shift ~= 0 then
        setshift(n,shift)
    end
    return n
end

local function new_vlist(list,width,height,depth,shift)
    local n = copy_nut(vlist)
    if list then
        setlist(n,list)
    end
    if width or height or depth then
        setwhd(n,width,height,depth)
    end
    if shift and shift ~= 0 then
        setshift(n,shift)
    end
    return n
end

nutpool.hlist = new_hlist
nutpool.vlist = new_vlist

function nodepool.hlist(list,width,height,depth,shift)
    return tonode(new_hlist(list and tonut(list),width,height,depth,shift))
end

function nodepool.vlist(list,width,height,depth,shift)
    return tonode(new_vlist(list and tonut(list),width,height,depth,shift))
end

function nutpool.usernode(id,data)
    local n = copy_nut(user_node)
    nodeproperties[n] = {
        id   = id,
        data = data,
    }
    return n
end

-- housekeeping

local function cleanup(nofboxes) -- todo
    local tracers = nodes.tracers
    if tracers and tracers.steppers then -- to be resolved
        tracers.steppers.reset() -- todo: make a registration subsystem
    end
    local nl = 0
    local nr = nofreserved
    for i=1,nofreserved do
        local ri = reserved[i]
        flush_nut(reserved[i])
    end
    if nofboxes then
        for i=0,nofboxes do
            local l = getbox(i)
            if l then
                flush_nut(l) -- also list ?
                nl = nl + 1
            end
        end
    end
    reserved    = { }
    nofreserved = 0
    return nr, nl, nofboxes -- can be nil
end

local usage = CONTEXTLMTXMODE > 0 and node.inuse or function()
    local t = { }
    for n, tag in gmatch(status.node_mem_usage,"(%d+) ([a-z_]+)") do
        t[tag] = tonumber(n) or 0
    end
    return t
end

nutpool .cleanup = cleanup
nodepool.cleanup = cleanup

nutpool .usage   = usage
nodepool.usage   = usage

-- end

statistics.register("cleaned up reserved nodes", function()
    return format("%s nodes, %s lists of %s", cleanup(texgetcount("c_syst_last_allocated_box")))
end) -- \topofboxstack

statistics.register("node memory usage", function() -- comes after cleanup !
    local used = usage()
    if next(used) then
        local t, n = { }, 0
        for k, v in table.sortedhash(used) do
            n = n + 1 ; t[n] = format("%s %s",v,k)
        end
        return table.concat(t,", ")
    end
end)

lua.registerfinalizer(cleanup, "cleanup reserved nodes")

-- experiment

do

    local glyph       = tonode(glyph)
    local traverse_id = nodes.traverse_id

    local traversers  = table.setmetatableindex(function(t,k)
        local v = traverse_id(type(k) == "number" and k or nodecodes[k],glyph)
        t[k] = v
        return v
    end)

                                traversers.node  = nodes.traverse      (glyph)
                                traversers.char  = nodes.traverse_char (glyph)
    if nuts.traverse_glyph then traversers.glyph = nodes.traverse_glyph(glyph) end
    if nuts.traverse_list  then traversers.list  = nodes.traverse_list (glyph) end

    nodes.traversers = traversers

end

do

    local glyph       = glyph
    local traverse_id = nuts.traverse_id

    local traversers  = table.setmetatableindex(function(t,k)
        local v = traverse_id(type(k) == "number" and k or nodecodes[k],glyph)
        t[k] = v
        return v
    end)

                                traversers.node  = nuts.traverse      (glyph)
                                traversers.char  = nuts.traverse_char (glyph)
    if nuts.traverse_glyph then traversers.glyph = nuts.traverse_glyph(glyph) end
    if nuts.traverse_list  then traversers.list  = nuts.traverse_list (glyph) end

    nuts.traversers = traversers

end
