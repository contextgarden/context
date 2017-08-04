if not modules then modules = { } end modules ['node-res'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gmatch, format = string.gmatch, string.format

--[[ldx--
<p>The next function is not that much needed but in <l n='context'/> we use
for debugging <l n='luatex'/> node management.</p>
--ldx]]--

local report_nodes = logs.reporter("nodes","housekeeping")

local nodes, node = nodes, node

nodes.pool          = nodes.pool or { }
local nodepool      = nodes.pool

local whatsitcodes  = nodes.whatsitcodes
local skipcodes     = nodes.skipcodes
local kerncodes     = nodes.kerncodes
local rulecodes     = nodes.rulecodes
local nodecodes     = nodes.nodecodes
local gluecodes     = nodes.gluecodes
local boundarycodes = nodes.boundarycodes
local usercodes     = nodes.usercodes

local glyph_code    = nodecodes.glyph

local allocate      = utilities.storage.allocate

local texgetcount   = tex.getcount

local reserved, nofreserved = { }, 0

-- user nodes

local userids = allocate()
local lastid  = 0

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

local nuts       = nodes.nuts
local nutpool    = { }
nuts.pool        = nutpool

local tonut      = nuts.tonut
local tonode     = nuts.tonode

local getbox     = nuts.getbox
local getfield   = nuts.getfield
local getid      = nuts.getid
local getlist    = nuts.getlist
local getglue    = nuts.getglue

local setfield   = nuts.setfield
local setchar    = nuts.setchar
local setlist    = nuts.setlist
local setwhd     = nuts.setwhd
local setglue    = nuts.setglue
local setdisc    = nuts.setdisc
local setfont    = nuts.setfont
local setkern    = nuts.setkern
local setpenalty = nuts.setpenalty
local setdir     = nuts.setdir
local setshift   = nuts.setshift
local setwidth   = nuts.setwidth
local setsubtype = nuts.setsubtype
local setleader  = nuts.setleader

local copy_nut   = nuts.copy
local new_nut    = nuts.new
local flush_nut  = nuts.flush

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

local disc              = register_nut(new_nut("disc"))
local kern              = register_nut(new_nut("kern",kerncodes.userkern))
local fontkern          = register_nut(new_nut("kern",kerncodes.fontkern))
local italickern        = register_nut(new_nut("kern",kerncodes.italiccorrection))
local penalty           = register_nut(new_nut("penalty"))
local glue              = register_nut(new_nut("glue")) -- glue.spec = nil
local glue_spec         = register_nut(new_nut("glue_spec"))
local glyph             = register_nut(new_nut("glyph",0))

local textdir           = register_nut(new_nut("dir"))

local latelua           = register_nut(new_nut("whatsit",whatsitcodes.latelua))
local special           = register_nut(new_nut("whatsit",whatsitcodes.special))

local user_node         = new_nut("whatsit",whatsitcodes.userdefined)

local user_number       = register_nut(copy_nut(user_node)) setfield(user_number,    "type",usercodes.number)
local user_nodes        = register_nut(copy_nut(user_node)) setfield(user_nodes,     "type",usercodes.nodes)
local user_string       = register_nut(copy_nut(user_node)) setfield(user_string,    "type",usercodes.string)
local user_tokens       = register_nut(copy_nut(user_node)) setfield(user_tokens,    "type",usercodes.tokens)
----- user_lua          = register_nut(copy_nut(user_node)) setfield(user_lua,       "type",usercodes.lua) -- in > 0.95
local user_attributes   = register_nut(copy_nut(user_node)) setfield(user_attributes,"type",usercodes.attributes)

local left_margin_kern  = register_nut(new_nut("margin_kern",0))
local right_margin_kern = register_nut(new_nut("margin_kern",1))

local lineskip          = register_nut(new_nut("glue",skipcodes.lineskip))
local baselineskip      = register_nut(new_nut("glue",skipcodes.baselineskip))
local leftskip          = register_nut(new_nut("glue",skipcodes.leftskip))
local rightskip         = register_nut(new_nut("glue",skipcodes.rightskip))

local temp              = register_nut(new_nut("temp",0))

local noad              = register_nut(new_nut("noad"))
local delimiter         = register_nut(new_nut("delim"))
local fence             = register_nut(new_nut("fence"))
local submlist          = register_nut(new_nut("sub_mlist"))
local accent            = register_nut(new_nut("accent"))
local radical           = register_nut(new_nut("radical"))
local fraction          = register_nut(new_nut("fraction"))
local subbox            = register_nut(new_nut("sub_box"))
local mathchar          = register_nut(new_nut("math_char"))
local mathtextchar      = register_nut(new_nut("math_text_char"))
local choice            = register_nut(new_nut("choice"))

local boundary          = register_nut(new_nut("boundary",boundarycodes.user))
local wordboundary      = register_nut(new_nut("boundary",boundarycodes.word))

local cleader           = register_nut(copy_nut(glue)) setsubtype(cleader,gluecodes.cleaders) setglue(cleader,0,65536,0,2,0)

-- the dir field needs to be set otherwise crash:

local rule              = register_nut(new_nut("rule"))                  setdir(rule, "TLT")
local emptyrule         = register_nut(new_nut("rule",rulecodes.empty))  setdir(rule, "TLT")
local userrule          = register_nut(new_nut("rule",rulecodes.user))   setdir(rule, "TLT")
local hlist             = register_nut(new_nut("hlist"))                 setdir(hlist,"TLT")
local vlist             = register_nut(new_nut("vlist"))                 setdir(vlist,"TLT")

function nutpool.glyph(fnt,chr)
    local n = copy_nut(glyph)
    if fnt then
        setfont(n,fnt,chr)
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
        setfield(n,"value",v)
    end
    return n
end

function nutpool.wordboundary(v)
    local n = copy_nut(wordboundary)
    if v and v ~= 0 then
        setfield(n,"value",v)
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

function nutpool.gluespec(width,stretch,shrink,stretch_order,shrink_order)
    -- maybe setglue
    local s = copy_nut(glue_spec)
    if width or stretch or shrink or stretch_order or shrink_order then
        setglue(s,width,stretch,shrink,stretch_order,shrink_order)
    end
    return s
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

function nutpool.textdir(dir)
    local t = copy_nut(textdir)
    if dir then
        setdir(t,dir)
    end
    return t
end

function nutpool.rule(width,height,depth,dir) -- w/h/d == nil will let them adapt
    local n = copy_nut(rule)
    if width or height or depth then
        setwhd(n,width,height,depth)
    end
    if dir then
        setdir(n,dir)
    end
    return n
end

function nutpool.emptyrule(width,height,depth,dir) -- w/h/d == nil will let them adapt
    local n = copy_nut(emptyrule)
    if width or height or depth then
        setwhd(n,width,height,depth)
    end
    if dir then
        setdir(n,dir)
    end
    return n
end

function nutpool.userrule(width,height,depth,dir) -- w/h/d == nil will let them adapt
    local n = copy_nut(userrule)
    if width or height or depth then
        setwhd(n,width,height,depth)
    end
    if dir then
        setdir(n,dir)
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

function nutpool.latelua(code)
    local n = copy_nut(latelua)
    setfield(n,"string",code)
    return n
end

nutpool.lateluafunction = nutpool.latelua

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

-- local num = userids["my id"]
-- local str = userids[num]

function nutpool.usernumber(id,num)
    local n = copy_nut(user_number)
    if num then
        setfield(n,"user_id",id)
        setfield(n,"value",num)
    elseif id then
        setfield(n,"value",id)
    end
    return n
end

function nutpool.userlist(id,list)
    local n = copy_nut(user_nodes)
    if list then
        setfield(n,"user_id",id)
        setfield(n,"value",list)
    else
        setfield(n,"value",id)
    end
    return n
end

function nutpool.userstring(id,str)
    local n = copy_nut(user_string)
    if str then
        setfield(n,"user_id",id)
        setfield(n,"value",str)
    else
        setfield(n,"value",id)
    end
    return n
end

function nutpool.usertokens(id,tokens)
    local n = copy_nut(user_tokens)
    if tokens then
        setfield(n,"user_id",id)
        setfield(n,"value",tokens)
    else
        setfield(n,"value",id)
    end
    return n
end

function nutpool.userlua(id,code)
    local n = copy_nut(user_lua)
    if code then
        setfield(n,"user_id",id)
        setfield(n,"value",code)
    else
        setfield(n,"value",id)
    end
    return n
end

function nutpool.userattributes(id,attr)
    local n = copy_nut(user_attributes)
    if attr then
        setfield(n,"user_id",id)
        setfield(n,"value",attr)
    else
        setfield(n,"value",id)
    end
    return n
end

function nutpool.special(str)
    local n = copy_nut(special)
    setfield(n,"data",str)
    return n
end

-- housekeeping

local function cleanup(nofboxes) -- todo
    if nodes.tracers.steppers then -- to be resolved
        nodes.tracers.steppers.reset() -- todo: make a registration subsystem
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


local function usage()
    local t = { }
    for n, tag in gmatch(status.node_mem_usage,"(%d+) ([a-z_]+)") do
        t[tag] = n
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
    local usage = status.node_mem_usage
    if usage ~= "" then
        return usage
    end
end)

lua.registerfinalizer(cleanup, "cleanup reserved nodes")
