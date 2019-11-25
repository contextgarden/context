if not modules then modules = { } end modules ['spac-ver'] = {
    version   = 1.001,
    comment   = "companion to spac-ver.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- we also need to call the spacer for inserts!

-- somehow lists still don't always have proper prev nodes so i need to
-- check all of the luatex code some day .. maybe i should replece the
-- whole mvl handler by lua code .. why not

-- todo: use lua nodes with lua data (>0.79)
-- see ** can go when 0.79

-- needs to be redone, too many calls and tests now ... still within some
-- luatex limitations

-- this code dates from the beginning and is kind of experimental; it
-- will be optimized and improved soon .. it's way too complex now but
-- dates from less possibilities
--
-- the collapser will be redone with user nodes; also, we might get make
-- parskip into an attribute and appy it explicitly thereby getting rid
-- of automated injections; eventually i want to get rid of the currently
-- still needed tex -> lua -> tex > lua chain (needed because we can have
-- expandable settings at the tex end

-- todo: strip baselineskip around display math

local next, type, tonumber = next, type, tonumber
local gmatch, concat = string.gmatch, table.concat
local ceil, floor = math.ceil, math.floor
local lpegmatch = lpeg.match
local unpack = unpack or table.unpack
local allocate = utilities.storage.allocate
local todimen = string.todimen
local formatters = string.formatters

local nodes        =  nodes
local trackers     =  trackers
local attributes   =  attributes
local context      =  context
local tex          =  tex

local texlists     = tex.lists
local texget       = tex.get
local texgetcount  = tex.getcount
local texgetdimen  = tex.getdimen
local texset       = tex.set
local texsetdimen  = tex.setdimen
local texsetcount  = tex.setcount
local texnest      = tex.nest
local texgetbox    = tex.getbox

local buildpage    = tex.triggerbuildpage

local variables    = interfaces.variables
local implement    = interfaces.implement

local v_local      = variables["local"]
local v_global     = variables["global"]
local v_box        = variables.box
----- v_page       = variables.page -- reserved for future use
local v_split      = variables.split
local v_min        = variables.min
local v_max        = variables.max
local v_none       = variables.none
local v_line       = variables.line
local v_noheight   = variables.noheight
local v_nodepth    = variables.nodepth
local v_line       = variables.line
local v_halfline   = variables.halfline
local v_line_m     = "-" .. v_line
local v_halfline_m = "-" .. v_halfline
local v_first      = variables.first
local v_last       = variables.last
local v_top        = variables.top
local v_bottom     = variables.bottom
local v_minheight  = variables.minheight
local v_maxheight  = variables.maxheight
local v_mindepth   = variables.mindepth
local v_maxdepth   = variables.maxdepth
local v_offset     = variables.offset
local v_strut      = variables.strut

local v_hfraction  = variables.hfraction
local v_dfraction  = variables.dfraction
local v_bfraction  = variables.bfraction
local v_tlines     = variables.tlines
local v_blines     = variables.blines

-- vertical space handler

local trace_vbox_vspacing    = false  trackers.register("vspacing.vbox",     function(v) trace_vbox_vspacing    = v end)
local trace_page_vspacing    = false  trackers.register("vspacing.page",     function(v) trace_page_vspacing    = v end)
local trace_page_builder     = false  trackers.register("builders.page",     function(v) trace_page_builder     = v end)
local trace_collect_vspacing = false  trackers.register("vspacing.collect",  function(v) trace_collect_vspacing = v end)
local trace_vspacing         = false  trackers.register("vspacing.spacing",  function(v) trace_vspacing         = v end)
local trace_vsnapping        = false  trackers.register("vspacing.snapping", function(v) trace_vsnapping        = v end)
local trace_specials         = false  trackers.register("vspacing.specials", function(v) trace_specials         = v end)

local remove_math_skips   = true  directives.register("vspacing.removemathskips", function(v) remnove_math_skips = v end)

local report_vspacing     = logs.reporter("vspacing","spacing")
local report_collapser    = logs.reporter("vspacing","collapsing")
local report_snapper      = logs.reporter("vspacing","snapping")
local report_specials     = logs.reporter("vspacing","specials")

local a_skipcategory      = attributes.private('skipcategory')
local a_skippenalty       = attributes.private('skippenalty')
local a_skiporder         = attributes.private('skiporder')
local a_snapmethod        = attributes.private('snapmethod')
local a_snapvbox          = attributes.private('snapvbox')

local nuts                = nodes.nuts
local tonut               = nuts.tonut
local tonode              = nuts.tonode

local getnext             = nuts.getnext
local setlink             = nuts.setlink
local getprev             = nuts.getprev
local getid               = nuts.getid
local getlist             = nuts.getlist
local setlist             = nuts.setlist
local getattr             = nuts.getattr
local setattr             = nuts.setattr
local getsubtype          = nuts.getsubtype
local getbox              = nuts.getbox
local getwhd              = nuts.getwhd
local setwhd              = nuts.setwhd
local getprop             = nuts.getprop
local setprop             = nuts.setprop
local getglue             = nuts.getglue
local setglue             = nuts.setglue
local getkern             = nuts.getkern
local getpenalty          = nuts.getpenalty
local setshift            = nuts.setshift
local setwidth            = nuts.setwidth
local getwidth            = nuts.getwidth
local setheight           = nuts.setheight
local getheight           = nuts.getheight
local setdepth            = nuts.setdepth
local getdepth            = nuts.getdepth

local find_node_tail      = nuts.tail
local flush_node          = nuts.flush_node
local insert_node_after   = nuts.insert_after
local insert_node_before  = nuts.insert_before
local remove_node         = nuts.remove
local count_nodes         = nuts.countall
local hpack_node          = nuts.hpack
local vpack_node          = nuts.vpack
local start_of_par        = nuts.start_of_par

local nextnode            = nuts.traversers.node
local nexthlist           = nuts.traversers.hlist

local nodereference       = nuts.reference

local theprop             = nuts.theprop

local listtoutf           = nodes.listtoutf
local nodeidstostring     = nodes.idstostring

local nodepool            = nuts.pool

local new_penalty         = nodepool.penalty
local new_kern            = nodepool.kern
local new_glue            = nodepool.glue
local new_rule            = nodepool.rule

local nodecodes           = nodes.nodecodes
local gluecodes           = nodes.gluecodes
----- penaltycodes        = nodes.penaltycodes
----- listcodes           = nodes.listcodes

local penalty_code        = nodecodes.penalty
local kern_code           = nodecodes.kern
local glue_code           = nodecodes.glue
local insert_code         = nodecodes.ins
local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local rule_code           = nodecodes.rule
local localpar_code       = nodecodes.localpar

local userskip_code       = gluecodes.userskip
local lineskip_code       = gluecodes.lineskip
local baselineskip_code   = gluecodes.baselineskip
local parskip_code        = gluecodes.parskip
local topskip_code        = gluecodes.topskip
local splittopskip_code   = gluecodes.splittopskip

local linelist_code       = nodes.listcodes.line

local abovedisplayskip_code      = gluecodes.abovedisplayskip
local belowdisplayskip_code      = gluecodes.belowdisplayskip
local abovedisplayshortskip_code = gluecodes.abovedisplayshortskip
local belowdisplayshortskip_code = gluecodes.belowdisplayshortskip

local properties          = nodes.properties.data

local vspacing            = builders.vspacing or { }
builders.vspacing         = vspacing

local vspacingdata        = vspacing.data or { }
vspacing.data             = vspacingdata

local snapmethods         = vspacingdata.snapmethods or { }
vspacingdata.snapmethods  = snapmethods

storage.register("builders/vspacing/data/snapmethods", snapmethods, "builders.vspacing.data.snapmethods")

do

    local default = {
        [v_maxheight] = true,
        [v_maxdepth]  = true,
        [v_strut]     = true,
        [v_hfraction] = 1,
        [v_dfraction] = 1,
        [v_bfraction] = 0.25,
    }

    local fractions = {
        [v_minheight] = v_hfraction, [v_maxheight] = v_hfraction,
        [v_mindepth]  = v_dfraction, [v_maxdepth]  = v_dfraction,
        [v_box]       = v_bfraction,
        [v_top]       = v_tlines,    [v_bottom]    = v_blines,
    }

    local values = {
        offset = "offset"
    }

    local colonsplitter = lpeg.splitat(":")

    local function listtohash(str)
        local t = { }
        for s in gmatch(str,"[^, ]+") do
            local key, detail = lpegmatch(colonsplitter,s)
            local v = variables[key]
            if v then
                t[v] = true
                if detail then
                    local k = fractions[key]
                    if k then
                        detail = tonumber("0" .. detail)
                        if detail then
                            t[k] = detail
                        end
                    else
                        k = values[key]
                        if k then
                            detail = todimen(detail)
                            if detail then
                                t[k] = detail
                            end
                        end
                    end
                end
            else
                detail = tonumber("0" .. key)
                if detail then
                    t[v_hfraction] = detail
                    t[v_dfraction] = detail
                end
            end
        end
        if next(t) then
            t[v_hfraction] = t[v_hfraction] or 1
            t[v_dfraction] = t[v_dfraction] or 1
            return t
        else
            return default
        end
    end

    function vspacing.definesnapmethod(name,method)
        local n = #snapmethods + 1
        local t = listtohash(method)
        snapmethods[n] = t
        t.name          = name   -- not interfaced
        t.specification = method -- not interfaced
        context(n)
    end

end

local function validvbox(parentid,list)
    if parentid == hlist_code then
        local id = getid(list)
        if id == localpar_code and start_of_par(list) then
            list = getnext(list)
            if not next then
                return nil
            end
        end
        local done = nil
        for n, id in nextnode, list do
            if id == vlist_code or id == hlist_code then
                if done then
                    return nil
                else
                    done = n
                end
            elseif id == glue_code or id == penalty_code then
                -- go on
            else
                return nil -- whatever
            end
        end
        if done then
            local id = getid(done)
            if id == hlist_code then
                return validvbox(id,getlist(done))
            end
        end
        return done -- only one vbox
    end
end

-- we can use a property

local function already_done(parentid,list,a_snapmethod) -- todo: done when only boxes and all snapped
    -- problem: any snapped vbox ends up in a line
    if list and parentid == hlist_code then
        local id = getid(list)
        if id == localpar_code and start_of_par(list) then
            list = getnext(list)
            if not list then
                return false
            end
        end
        for n, id in nextnode, list do
            if id == hlist_code or id == vlist_code then
             -- local a = getattr(n,a_snapmethod)
             -- if not a then
             --  -- return true -- not snapped at all
             -- elseif a == 0 then
             --     return true -- already snapped
             -- end
                local p = getprop(n,"snapper")
                if p then
                    return p
                end
            elseif id == glue_code or id == penalty_code then -- or id == kern_code then
                -- go on
            else
                return false -- whatever
            end
        end
    end
    return false
end

-- quite tricky: ceil(-something) => -0

local function ceiled(n)
    if n < 0 or n < 0.01 then
        return 0
    else
        return ceil(n)
    end
end

local function floored(n)
    if n < 0 or n < 0.01 then
        return 0
    else
        return floor(n)
    end
end

-- check variables.none etc

local function fixedprofile(current)
    local profiling = builders.profiling
    return profiling and profiling.fixedprofile(current)
end

-- local function onlyoneentry(t)
--     local n = 1
--     for k, v in next, t do
--         if n > 1 then
--             return false
--         end
--         n = n + 1
--     end
--     return true
-- end

local function snap_hlist(where,current,method,height,depth) -- method[v_strut] is default
    if fixedprofile(current) then
        return
    end
    local list = getlist(current)
    local t = trace_vsnapping and { }
    if t then
        t[#t+1] = formatters["list content: %s"](listtoutf(list))
        t[#t+1] = formatters["snap method: %s"](method.name) -- not interfaced
        t[#t+1] = formatters["specification: %s"](method.specification) -- not interfaced
    end
    local snapht, snapdp
    if method[v_local] then
        -- snapping is done immediately here
        snapht = texgetdimen("bodyfontstrutheight")
        snapdp = texgetdimen("bodyfontstrutdepth")
        if t then
            t[#t+1] = formatters["local: snapht %p snapdp %p"](snapht,snapdp)
        end
    elseif method[v_global] then
        snapht = texgetdimen("globalbodyfontstrutheight")
        snapdp = texgetdimen("globalbodyfontstrutdepth")
        if t then
            t[#t+1] = formatters["global: snapht %p snapdp %p"](snapht,snapdp)
        end
    else
        -- maybe autolocal
        -- snapping might happen later in the otr
        snapht = texgetdimen("globalbodyfontstrutheight")
        snapdp = texgetdimen("globalbodyfontstrutdepth")
        local lsnapht = texgetdimen("bodyfontstrutheight")
        local lsnapdp = texgetdimen("bodyfontstrutdepth")
        if snapht ~= lsnapht and snapdp ~= lsnapdp then
            snapht, snapdp = lsnapht, lsnapdp
        end
        if t then
            t[#t+1] = formatters["auto: snapht %p snapdp %p"](snapht,snapdp)
        end
    end

    local wd, ht, dp = getwhd(current)

    local h        = (method[v_noheight] and 0) or height or ht
    local d        = (method[v_nodepth]  and 0) or depth  or dp
    local hr       = method[v_hfraction] or 1
    local dr       = method[v_dfraction] or 1
    local br       = method[v_bfraction] or 0
    local ch       = h
    local cd       = d
    local tlines   = method[v_tlines] or 1
    local blines   = method[v_blines] or 1
    local done     = false
    local plusht   = snapht
    local plusdp   = snapdp
    local snaphtdp = snapht + snapdp
    local extra    = 0

    if t then
        t[#t+1] = formatters["hlist: wd %p ht %p (used %p) dp %p (used %p)"](wd,ht,h,dp,d)
        t[#t+1] = formatters["fractions: hfraction %s dfraction %s bfraction %s tlines %s blines %s"](hr,dr,br,tlines,blines)
    end

    if method[v_box] then
        local br = 1 - br
        if br < 0 then
            br = 0
        elseif br > 1 then
            br = 1
        end
        local n = ceiled((h+d-br*snapht-br*snapdp)/snaphtdp)
        local x = n * snaphtdp - h - d
        plusht = h + x / 2
        plusdp = d + x / 2
        if t then
            t[#t+1] = formatters["%s: plusht %p plusdp %p"](v_box,plusht,plusdp)
        end
    elseif method[v_max] then
        local n = ceiled((h+d)/snaphtdp)
        local x = n * snaphtdp - h - d
        plusht = h + x / 2
        plusdp = d + x / 2
        if t then
            t[#t+1] = formatters["%s: plusht %p plusdp %p"](v_max,plusht,plusdp)
        end
    elseif method[v_min] then
        -- we catch a lone min
        if method.specification ~= v_min then
            local n = floored((h+d)/snaphtdp)
            local x = n * snaphtdp - h - d
            plusht = h + x / 2
            plusdp = d + x / 2
            if plusht < 0 then
                plusht = 0
            end
            if plusdp < 0 then
                plusdp = 0
            end
        end
        if t then
            t[#t+1] = formatters["%s: plusht %p plusdp %p"](v_min,plusht,plusdp)
        end
    elseif method[v_none] then
        plusht, plusdp = 0, 0
        if t then
            t[#t+1] = formatters["%s: plusht %p plusdp %p"](v_none,0,0)
        end
    end
    -- for now, we actually need to tag a box and then check at several points if something ended up
    -- at the top of a page
    if method[v_halfline] then -- extra halfline
        extra  = snaphtdp/2
        plusht = plusht + extra
        plusdp = plusdp + extra
        if t then
            t[#t+1] = formatters["%s: plusht %p plusdp %p"](v_halfline,plusht,plusdp)
        end
    end
    if method[v_line] then -- extra line
        extra  = snaphtdp
        plusht = plusht + extra
        plusdp = plusdp + extra
        if t then
            t[#t+1] = formatters["%s: plusht %p plusdp %p"](v_line,plusht,plusdp)
        end
    end
    if method[v_halfline_m] then -- extra halfline
        extra  = - snaphtdp/2
        plusht = plusht + extra
        plusdp = plusdp + extra
        if t then
            t[#t+1] = formatters["%s: plusht %p plusdp %p"](v_halfline_m,plusht,plusdp)
        end
    end
    if method[v_line_m] then -- extra line
        extra  = - snaphtdp
        plusht = plusht + extra
        plusdp = plusdp + extra
        if t then
            t[#t+1] = formatters["%s: plusht %p plusdp %p"](v_line_m,plusht,plusdp)
        end
    end
    if method[v_first] then
        local thebox = current
        local id = getid(thebox)
        if id == hlist_code then
            thebox = validvbox(id,getlist(thebox))
            id = thebox and getid(thebox)
        end
        if thebox and id == vlist_code then
            local list = getlist(thebox)
            local lw, lh, ld
            for n in nexthlist, list do
                lw, lh, ld = getwhd(n)
                break
            end
            if lh then
                local wd, ht, dp = getwhd(thebox)
                if t then
                    t[#t+1] = formatters["first line: height %p depth %p"](lh,ld)
                    t[#t+1] = formatters["dimensions: height %p depth %p"](ht,dp)
                end
                local delta = h - lh
                ch, cd = lh, delta + d
                h, d = ch, cd
                local shifted = hpack_node(getlist(current))
                setshift(shifted,delta)
                setlist(current,shifted)
                done = true
                if t then
                    t[#t+1] = formatters["first: height %p depth %p shift %p"](ch,cd,delta)
                end
            elseif t then
                t[#t+1] = "first: not done, no content"
            end
        elseif t then
            t[#t+1] = "first: not done, no vbox"
        end
    elseif method[v_last] then
        local thebox = current
        local id = getid(thebox)
        if id == hlist_code then
            thebox = validvbox(id,getlist(thebox))
            id = thebox and getid(thebox)
        end
        if thebox and id == vlist_code then
            local list = getlist(thebox)
            local lw, lh, ld
            for n in nexthlist, list do
                lw, lh, ld = getwhd(n)
            end
            if lh then
                local wd, ht, dp = getwhd(thebox)
                if t then
                    t[#t+1] = formatters["last line: height %p depth %p" ](lh,ld)
                    t[#t+1] = formatters["dimensions: height %p depth %p"](ht,dp)
                end
                local delta = d - ld
                cd, ch = ld, delta + h
                h, d = ch, cd
                local shifted = hpack_node(getlist(current))
                setshift(shifted,delta)
                setlist(current,shifted)
                done = true
                if t then
                    t[#t+1] = formatters["last: height %p depth %p shift %p"](ch,cd,delta)
                end
            elseif t then
                t[#t+1] = "last: not done, no content"
            end
        elseif t then
            t[#t+1] = "last: not done, no vbox"
        end
    end
    if method[v_minheight] then
        ch = floored((h-hr*snapht)/snaphtdp)*snaphtdp + plusht
        if t then
            t[#t+1] = formatters["minheight: %p"](ch)
        end
    elseif method[v_maxheight] then
        ch = ceiled((h-hr*snapht)/snaphtdp)*snaphtdp + plusht
        if t then
            t[#t+1] = formatters["maxheight: %p"](ch)
        end
    else
        ch = plusht
        if t then
            t[#t+1] = formatters["set height: %p"](ch)
        end
    end
    if method[v_mindepth] then
        cd = floored((d-dr*snapdp)/snaphtdp)*snaphtdp + plusdp
        if t then
            t[#t+1] = formatters["mindepth: %p"](cd)
        end
    elseif method[v_maxdepth] then
        cd = ceiled((d-dr*snapdp)/snaphtdp)*snaphtdp + plusdp
        if t then
            t[#t+1] = formatters["maxdepth: %p"](cd)
        end
    else
        cd = plusdp
        if t then
            t[#t+1] = formatters["set depth: %p"](cd)
        end
    end
    if method[v_top] then
        ch = ch + tlines * snaphtdp
        if t then
            t[#t+1] = formatters["top height: %p"](ch)
        end
    end
    if method[v_bottom] then
        cd = cd + blines * snaphtdp
        if t then
            t[#t+1] = formatters["bottom depth: %p"](cd)
        end
    end
    local offset = method[v_offset]
    if offset then
        -- we need to set the attr
        if t then
            local wd, ht, dp = getwhd(current)
            t[#t+1] = formatters["before offset: %p (width %p height %p depth %p)"](offset,wd,ht,dp)
        end
        local shifted = hpack_node(getlist(current))
        setshift(shifted,offset)
        setlist(current,shifted)
        if t then
            local wd, ht, dp = getwhd(current)
            t[#t+1] = formatters["after offset: %p (width %p height %p depth %p)"](offset,wd,ht,dp)
        end
        setattr(shifted,a_snapmethod,0)
        setattr(current,a_snapmethod,0)
    end
    if not height then
        setheight(current,ch)
        if t then
            t[#t+1] = formatters["forced height: %p"](ch)
        end
    end
    if not depth then
        setdepth(current,cd)
        if t then
            t[#t+1] = formatters["forced depth: %p"](cd)
        end
    end
    local lines = (ch+cd)/snaphtdp
    if t then
        local original = (h+d)/snaphtdp
        local whatever = (ch+cd)/(texgetdimen("globalbodyfontstrutheight") + texgetdimen("globalbodyfontstrutdepth"))
        t[#t+1] = formatters["final lines : %p -> %p (%p)"](original,lines,whatever)
        t[#t+1] = formatters["final height: %p -> %p"](h,ch)
        t[#t+1] = formatters["final depth : %p -> %p"](d,cd)
    end
-- todo:
--
--     if h < 0 or d < 0 then
--         h = 0
--         d = 0
--     end
    if t then
        report_snapper("trace: %s type %s\n\t%\n\tt",where,nodecodes[getid(current)],t)
    end
    if not method[v_split] then
        -- so extra will not be compensated at the top of a page
        extra = 0
    end
    return h, d, ch, cd, lines, extra
end

local function snap_topskip(current,method)
    local w = getwidth(current)
    setwidth(current,0)
    return w, 0
end

local categories = {
     [0] = "discard",
     [1] = "largest",
     [2] = "force",
     [3] = "penalty",
     [4] = "add",
     [5] = "disable",
     [6] = "nowhite",
     [7] = "goback",
     [8] = "packed",
     [9] = "overlay",
    [10] = "enable",
    [11] = "notopskip",
}

categories          = allocate(table.swapped(categories,categories))
vspacing.categories = categories

function vspacing.tocategories(str)
    local t = { }
    for s in gmatch(str,"[^, ]") do -- use lpeg instead
        local n = tonumber(s)
        if n then
            t[categories[n]] = true
        else
            t[b] = true
        end
    end
    return t
end

function vspacing.tocategory(str) -- can be optimized
    if type(str) == "string" then
        return set.tonumber(vspacing.tocategories(str))
    else
        return set.tonumber({ [categories[str]] = true })
    end
end

vspacingdata.map  = vspacingdata.map  or { } -- allocate ?
vspacingdata.skip = vspacingdata.skip or { } -- allocate ?

storage.register("builders/vspacing/data/map",  vspacingdata.map,  "builders.vspacing.data.map")
storage.register("builders/vspacing/data/skip", vspacingdata.skip, "builders.vspacing.data.skip")

do -- todo: interface.variables and properties

    local P, C, R, S, Cc, Cs = lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.Cc, lpeg.Cs

    vspacing.fixed   = false

    local map        = vspacingdata.map
    local skip       = vspacingdata.skip

    local sign       = S("+-")^0
    local multiplier = C(sign * R("09")^1) * P("*")
    local singlefier = Cs(sign * Cc(1))
    local separator  = S(", ")
    local category   = P(":") * C((1-separator)^1)
    local keyword    = C((1-category-separator)^1)
    local splitter   = (multiplier + Cc(1)) * keyword * (category + Cc(false))

    local k_fixed    = variables.fixed
    local k_flexible = variables.flexible
    local k_category = "category"
    local k_penalty  = "penalty"
    local k_order    = "order"

    -- This will change: just node.write and we can store the values in skips which
    -- then obeys grouping .. but .. we miss the amounts then as they live at the tex
    -- end so we then also need to change that bit ... it would be interesting if we
    -- could store in properties

    local ctx_fixedblankskip         = context.fixedblankskip
    local ctx_flexibleblankskip      = context.flexibleblankskip
    local ctx_setblankcategory       = context.setblankcategory
    local ctx_setblankorder          = context.setblankorder
    local ctx_setblankpenalty        = context.setblankpenalty
    ----- ctx_setblankhandling       = context.setblankhandling
    local ctx_flushblankhandling     = context.flushblankhandling
    local ctx_addpredefinedblankskip = context.addpredefinedblankskip
    local ctx_addaskedblankskip      = context.addaskedblankskip
    local ctx_setblankpacked         = context.setblankpacked

    local ctx_pushlogger             = context.pushlogger
    local ctx_startblankhandling     = context.startblankhandling
    local ctx_stopblankhandling      = context.stopblankhandling
    local ctx_poplogger              = context.poplogger

    local pattern = nil

    local packed  = categories.packed

    local function handler(amount, keyword, detail)
        if not keyword then
            report_vspacing("unknown directive %a",s)
        else
            local mk = map[keyword]
            if mk then
                lpegmatch(pattern,mk)
            elseif keyword == k_fixed then
                ctx_fixedblankskip()
            elseif keyword == k_flexible then
                ctx_flexibleblankskip()
            elseif keyword == k_category then
                local category = tonumber(detail)
                if category == packed then
                    ctx_setblankpacked()
                elseif category then
                    ctx_setblankcategory(category)
                    ctx_flushblankhandling()
                end
            elseif keyword == k_order and detail then
                local order = tonumber(detail)
                if order then
                    ctx_setblankorder(order)
                end
            elseif keyword == k_penalty and detail then
                local penalty = tonumber(detail)
                if penalty then
                    ctx_setblankpenalty(penalty)
                end
            else
                amount = tonumber(amount) or 1
                local sk = skip[keyword]
                if sk then
                    ctx_addpredefinedblankskip(amount,keyword)
                else -- no check
                    ctx_addaskedblankskip(amount,keyword)
                end
            end
        end
    end

    local splitter = ((multiplier + singlefier) * keyword * (category + Cc(false))) / handler
          pattern  = (splitter + separator^1)^0

    function vspacing.analyze(str)
        if trace_vspacing then
            ctx_pushlogger(report_vspacing)
            ctx_startblankhandling()
            lpegmatch(pattern,str)
            ctx_stopblankhandling()
            ctx_poplogger()
        else
            ctx_startblankhandling()
            lpegmatch(pattern,str)
            ctx_stopblankhandling()
        end
    end

    --

    function vspacing.setmap(from,to)
        map[from] = to
    end

    function vspacing.setskip(key,value,grid)
        if value ~= "" then
            if grid == "" then grid = value end
            skip[key] = { value, grid }
        end
    end

end

-- implementation

local trace_list, tracing_info, before, after = { }, false, "", ""

local function nodes_to_string(head)
    local current = head
    local t       = { }
    while current do
        local id = getid(current)
        local ty = nodecodes[id]
        if id == penalty_code then
            t[#t+1] = formatters["%s:%s"](ty,getpenalty(current))
        elseif id == glue_code then
            t[#t+1] = formatters["%s:%s:%p"](ty,gluecodes[getsubtype(current)],getwidth(current))
        elseif id == kern_code then
            t[#t+1] = formatters["%s:%p"](ty,getkern(current))
        else
            t[#t+1] = ty
        end
        current = getnext(current)
    end
    return concat(t," + ")
end

local function reset_tracing(head)
    trace_list, tracing_info, before, after = { }, false, nodes_to_string(head), ""
end

local function trace_skip(str,sc,so,sp,data)
    trace_list[#trace_list+1] = { "skip", formatters["%s | %p | category %s | order %s | penalty %s"](str, getwidth(data), sc or "-", so or "-", sp or "-") }
    tracing_info = true
end

local function trace_natural(str,data)
    trace_list[#trace_list+1] = { "skip", formatters["%s | %p"](str, getwidth(data)) }
    tracing_info = true
end

local function trace_info(message, where, what)
    trace_list[#trace_list+1] = { "info", formatters["%s: %s/%s"](message,where,what) }
end

local function trace_node(what)
    local nt = nodecodes[getid(what)]
    local tl = trace_list[#trace_list]
    if tl and tl[1] == "node" then
        trace_list[#trace_list] = { "node", formatters["%s + %s"](tl[2],nt) }
    else
        trace_list[#trace_list+1] = { "node", nt }
    end
end

local function trace_done(str,data)
    if getid(data) == penalty_code then
        trace_list[#trace_list+1] = { "penalty", formatters["%s | %s"](str,getpenalty(data)) }
    else
        trace_list[#trace_list+1] = { "glue", formatters["%s | %p"](str,getwidth(data)) }
    end
    tracing_info = true
end

local function show_tracing(head)
    if tracing_info then
        after = nodes_to_string(head)
        for i=1,#trace_list do
            local tag, text = unpack(trace_list[i])
            if tag == "info" then
                report_collapser(text)
            else
                report_collapser("  %s: %s",tag,text)
            end
        end
        report_collapser("before: %s",before)
        report_collapser("after : %s",after)
    end
end

-- alignment box begin_of_par vmode_par hmode_par insert penalty before_display after_display

function vspacing.snapbox(n,how)
    local sv = snapmethods[how]
    if sv then
        local box = getbox(n)
        local list = getlist(box)
        if list then
            local s = getattr(list,a_snapmethod)
            if s == 0 then
                if trace_vsnapping then
                --  report_snapper("box list not snapped, already done")
                end
            else
                local wd, ht, dp = getwhd(box)
                if false then -- todo: already_done
                    -- assume that the box is already snapped
                    if trace_vsnapping then
                        report_snapper("box list already snapped at (%p,%p): %s",
                            ht,dp,listtoutf(list))
                    end
                else
                    local h, d, ch, cd, lines, extra = snap_hlist("box",box,sv,ht,dp)
                    setprop(box,"snapper",{
                        ht = h,
                        dp = d,
                        ch = ch,
                        cd = cd,
                        extra = extra,
                        current = current,
                    })
                    setwhd(box,wd,ch,cd)
                    if trace_vsnapping then
                        report_snapper("box list snapped from (%p,%p) to (%p,%p) using method %a (%s) for %a (%s lines): %s",
                            h,d,ch,cd,sv.name,sv.specification,"direct",lines,listtoutf(list))
                    end
                    setattr(box,a_snapmethod,0)  --
                    setattr(list,a_snapmethod,0) -- yes or no
                end
            end
        end
    end
end

-- I need to figure out how to deal with the prevdepth that crosses pages. In fact,
-- prevdepth is often quite interfering (even over a next paragraph) so I need to
-- figure out a trick. Maybe use something other than a rule. If we visualize we'll
-- see the baselineskip in action:
--
-- \blank[force,5*big] { \baselineskip1cm xxxxxxxxx \par } \page
-- \blank[force,5*big] { \baselineskip1cm xxxxxxxxx \par } \page
-- \blank[force,5*big] { \baselineskip5cm xxxxxxxxx \par } \page

-- We can register and copy the rule instead.

do

    local w, h, d = 0, 0, 0
    ----- w, h, d = 100*65536, 65536, 65536

    local function forced_skip(head,current,width,where,trace) -- looks old ... we have other tricks now
        if head == current then
            if getsubtype(head) == baselineskip_code then
                width = width - getwidth(head)
            end
        end
        if width == 0 then
            -- do nothing
        elseif where == "after" then
            head, current = insert_node_after(head,current,new_rule(w,h,d))
            head, current = insert_node_after(head,current,new_kern(width))
            head, current = insert_node_after(head,current,new_rule(w,h,d))
        else
            local c = current
            head, current = insert_node_before(head,current,new_rule(w,h,d))
            head, current = insert_node_before(head,current,new_kern(width))
            head, current = insert_node_before(head,current,new_rule(w,h,d))
            current = c
        end
        if trace then
            report_vspacing("inserting forced skip of %p",width)
        end
        return head, current
    end

    -- penalty only works well when before skip

    local discard   = categories.discard
    local largest   = categories.largest
    local force     = categories.force
    local penalty   = categories.penalty
    local add       = categories.add
    local disable   = categories.disable
    local nowhite   = categories.nowhite
    local goback    = categories.goback
    local packed    = categories.packed
    local overlay   = categories.overlay
    local enable    = categories.enable
    local notopskip = categories.notopskip

    -- [whatsits][hlist][glue][glue][penalty]

    local special_penalty_min = 32250
    local special_penalty_max = 35000
    local special_penalty_xxx =     0

    -- this is rather messy and complex: we want to make sure that successive
    -- header don't break but also make sure that we have at least a decent
    -- break when we have succesive ones (often when testing)

    -- todo: mark headers as such so that we can recognize them

    local specialmethods = { }
    local specialmethod  = 1

    specialmethods[1] = function(pagehead,pagetail,start,penalty)
        --
        if not pagehead or penalty < special_penalty_min or penalty > special_penalty_max then
            return
        end
        local current  = pagetail
        --
        -- nodes.showsimplelist(pagehead,0)
        --
        if trace_specials then
            report_specials("checking penalty %a",penalty)
        end
        while current do
            local id = getid(current)
            if id == penalty_code then
                local p = properties[current]
                if p then
                    local p = p.special_penalty
                    if not p then
                        if trace_specials then
                            report_specials("  regular penalty, continue")
                        end
                    elseif p == penalty then
                        if trace_specials then
                            report_specials("  context penalty %a, same level, overloading",p)
                        end
                        return special_penalty_xxx
                    elseif p > special_penalty_min and p < special_penalty_max then
                        if penalty < p then
                            if trace_specials then
                                report_specials("  context penalty %a, lower level, overloading",p)
                            end
                            return special_penalty_xxx
                        else
                            if trace_specials then
                                report_specials("  context penalty %a, higher level, quitting",p)
                            end
                            return
                        end
                    elseif trace_specials then
                        report_specials("  context penalty %a, higher level, continue",p)
                    end
                else
                    local p = getpenalty(current)
                    if p < 10000 then
                        -- assume some other mechanism kicks in so we seem to have content
                        if trace_specials then
                            report_specials("  regular penalty %a, quitting",p)
                        end
                        break
                    else
                        if trace_specials then
                            report_specials("  regular penalty %a, continue",p)
                        end
                    end
                end
            end
            current = getprev(current)
        end
        -- none found, so no reson to be special
        if trace_specials then
            if pagetail then
                report_specials("  context penalty, discarding, nothing special")
            else
                report_specials("  context penalty, discarding, nothing preceding")
            end
        end
        return special_penalty_xxx
    end

    -- This will be replaced after 0.80+ when we have a more robust look-back and
    -- can look at the bigger picture.

    -- todo: look back and when a special is there before a list is seen penalty keep ut

    -- we now look back a lot, way too often

    -- userskip
    -- lineskip
    -- baselineskip
    -- parskip
    -- abovedisplayskip
    -- belowdisplayskip
    -- abovedisplayshortskip
    -- belowdisplayshortskip
    -- topskip
    -- splittopskip

    -- we could inject a vadjust to force a recalculation .. a mess
    --
    -- So, the next is far from robust and okay but for the moment this overlaying
    -- has to do. Always test this with the examples in spac-ver.mkvi!

    local function check_experimental_overlay(head,current)
        local p = nil
        local c = current
        local n = nil
        local function overlay(p,n,mvl)
            local p_wd, p_ht, p_dp = getwhd(p)
            local n_wd, n_ht, n_dp = getwhd(n)
            local skips = 0
            --
            -- We deal with this at the tex end .. we don't see spacing .. enabling this code
            -- is probably harmless but then we need to test it.
            --
            -- we could calculate this before we call
            --
            -- problem: prev list and next list can be unconnected
            --
            local c = getnext(p)
            local l = c
            while c and c ~= n do
                local id = getid(c)
                if id == glue_code then
                    skips = skips + getwidth(c)
                elseif id == kern_code then
                    skips = skips + getkern(c)
                end
                l = c
                c = getnext(c)
            end
            local c = getprev(n)
            while c and c ~= n and c ~= l do
                local id = getid(c)
                if id == glue_code then
                    skips = skips + getwidth(c)
                elseif id == kern_code then
                    skips = skips + getkern(c)
                end
                c = getprev(c)
            end
            --
            local delta = n_ht + skips + p_dp
            texsetdimen("global","d_spac_overlay",-delta) -- for tracing
            -- we should adapt pagetotal ! (need a hook for that) .. now we have the wrong pagebreak
            local k = new_kern(-delta)
            head = insert_node_before(head,n,k)
            if n_ht > p_ht then
                local k = new_kern(n_ht-p_ht)
                head = insert_node_before(head,p,k)
            end
            if trace_vspacing then
                report_vspacing("overlaying, prev height: %p, prev depth: %p, next height: %p, skips: %p, move up: %p",p_ht,p_dp,n_ht,skips,delta)
            end
            return remove_node(head,current,true)
        end

        -- goto next line
        while c do
            local id = getid(c)
            if id == glue_code or id == penalty_code or id == kern_code then
                -- skip (actually, remove)
                c = getnext(c)
            elseif id == hlist_code then
                n = c
                break
            else
                break
            end
        end
        if n then
            -- we have a next line, goto prev line
            c = current
            while c do
                local id = getid(c)
                if id == glue_code or id == penalty_code then -- kern ?
                    c = getprev(c)
                elseif id == hlist_code then
                    p = c
                    break
                else
                    break
                end
            end
            if not p then
                if a_snapmethod == a_snapvbox then
                    -- quit, we're not on the mvl
                else
                    -- inefficient when we're at the end of a page
                    local c = tonut(texlists.page_head)
                    while c and c ~= n do
                        local id = getid(c)
                        if id == hlist_code then
                            p = c
                        end
                        c = getnext(c)
                    end
                    if p and p ~= n then
                        return overlay(p,n,true)
                    end
                end
            elseif p ~= n then
                return overlay(p,n,false)
            end
        end
        -- in fact, we could try again later ... so then no remove (a few tries)
        return remove_node(head, current, true)
    end

    local function collapser(head,where,what,trace,snap,a_snapmethod) -- maybe also pass tail
        if trace then
            reset_tracing(head)
        end
        local current           = head
        local oldhead           = head
        local glue_order        = 0
        local glue_data
        local force_glue        = false
        local penalty_order     = 0
        local penalty_data
        local natural_penalty
        local special_penalty
        local parskip
        local ignore_parskip    = false
        local ignore_following  = false
        local ignore_whitespace = false
        local keep_together     = false
        local lastsnap
        local pagehead
        local pagetail
        --
        -- todo: keep_together: between headers
        --
        local function getpagelist()
            if not pagehead then
                pagehead = texlists.page_head
                if pagehead then
                    pagehead = tonut(pagehead)
                    pagetail = find_node_tail(pagehead) -- no texlists.page_tail yet-- no texlists.page_tail yet
                end
            end
        end
        --
        local function compensate(n)
            local g = 0
            while n and getid(n) == glue_code do
                g = g + getwidth(n)
                n = getnext(n)
            end
            if n then
                local p = getprop(n,"snapper")
                if p then
                    local extra = p.extra
                    if extra and extra < 0 then -- hm, extra can be unset ... needs checking
                        local h = p.ch -- getheight(n)
                        -- maybe an extra check
                     -- if h - extra < g then
                            setheight(n,h-2*extra)
                            p.extra = 0
                            if trace_vsnapping then
                                report_snapper("removed extra space at top: %p",extra)
                            end
                     -- end
                    end
                end
                return n
            end
        end
        --
        local function removetopsnap()
            getpagelist()
            if pagehead then
                local n = pagehead and compensate(pagehead)
                if n and n ~= pagetail then
                    local p = getprop(pagetail,"snapper")
                    if p then
                        local e = p.extra
                        if e and e < 0 then
                            local t = texget("pagetotal")
                            if t > 0 then
                                local g = texget("pagegoal") -- 1073741823 is signal
                                local d = g - t
                                if d < -e then
                                    local penalty = new_penalty(1000000)
                                    setlink(penalty,head)
                                    head = penalty
                                    report_snapper("force pagebreak due to extra space at bottom: %p",e)
                                end
                            end
                        end
                    end
                end
            elseif head then
                compensate(head)
            end
        end
        --
        local function getavailable()
            getpagelist()
            if pagehead then
                local t = texget("pagetotal")
                if t > 0 then
                    local g = texget("pagegoal")
                    return g - t
                end
            end
            return false
        end
        --
        local function flush(why)
            if penalty_data then
                local p = new_penalty(penalty_data)
                if trace then
                    trace_done("flushed due to " .. why,p)
                end
                if penalty_data >= 10000 then -- or whatever threshold?
                    local prev = getprev(current)
                    if getid(prev) == glue_code then -- maybe go back more, or maybe even push back before any glue
                            -- tricky case: spacing/grid-007.tex: glue penalty glue
                        head = insert_node_before(head,prev,p)
                    else
                        head = insert_node_before(head,current,p)
                    end
                else
                    head = insert_node_before(head,current,p)
                end
             -- if penalty_data > special_penalty_min and penalty_data < special_penalty_max then
                local props = properties[p]
                if props then
                    props.special_penalty = special_penalty or penalty_data
                else
                    properties[p] = {
                        special_penalty = special_penalty or penalty_data
                    }
                end
             -- end
            end
            if glue_data then
                if force_glue then
                    if trace then
                        trace_done("flushed due to forced " .. why,glue_data)
                    end
                    head = forced_skip(head,current,getwidth(glue_data,width),"before",trace)
                    flush_node(glue_data)
                else
                    local width, stretch, shrink = getglue(glue_data)
                    if width ~= 0 then
                        if trace then
                            trace_done("flushed due to non zero " .. why,glue_data)
                        end
                        head = insert_node_before(head,current,glue_data)
                    elseif stretch ~= 0 or shrink ~= 0 then
                        if trace then
                            trace_done("flushed due to stretch/shrink in" .. why,glue_data)
                        end
                        head = insert_node_before(head,current,glue_data)
                    else
                     -- report_vspacing("needs checking (%s): %p",gluecodes[getsubtype(glue_data)],w)
                        flush_node(glue_data)
                    end
                end
            end

            if trace then
                trace_node(current)
            end
            glue_order, glue_data, force_glue = 0, nil, false
            penalty_order, penalty_data, natural_penalty = 0, nil, nil
            parskip, ignore_parskip, ignore_following, ignore_whitespace = nil, false, false, false
        end
        --
        if trace_vsnapping then
            report_snapper("global ht/dp = %p/%p, local ht/dp = %p/%p",
                texgetdimen("globalbodyfontstrutheight"),
                texgetdimen("globalbodyfontstrutdepth"),
                texgetdimen("bodyfontstrutheight"),
                texgetdimen("bodyfontstrutdepth")
            )
        end
        if trace then
            trace_info("start analyzing",where,what)
        end
        if snap and where == "page" then
            removetopsnap()
        end
        while current do
            local id = getid(current)
            if id == hlist_code or id == vlist_code then
                -- needs checking, why so many calls
                if snap then
                    lastsnap = nil
                    local list = getlist(current)
                    local s = getattr(current,a_snapmethod)
                    if not s then
                    --  if trace_vsnapping then
                    --      report_snapper("mvl list not snapped")
                    --  end
                    elseif s == 0 then
                        if trace_vsnapping then
                            report_snapper("mvl %a not snapped, already done: %s",nodecodes[id],listtoutf(list))
                        end
                    else
                        local sv = snapmethods[s]
                        if sv then
                            -- check if already snapped
                            local done = list and already_done(id,list,a_snapmethod)
                            if done then
                                -- assume that the box is already snapped
                                if trace_vsnapping then
                                    local w, h, d = getwhd(current)
                                    report_snapper("mvl list already snapped at (%p,%p): %s",h,d,listtoutf(list))
                                end
                            else
                                local h, d, ch, cd, lines, extra = snap_hlist("mvl",current,sv,false,false)
                                lastsnap = {
                                    ht = h,
                                    dp = d,
                                    ch = ch,
                                    cd = cd,
                                    extra = extra,
                                    current = current,
                                }
                                setprop(current,"snapper",lastsnap)
                                if trace_vsnapping then
                                    report_snapper("mvl %a snapped from (%p,%p) to (%p,%p) using method %a (%s) for %a (%s lines): %s",
                                        nodecodes[id],h,d,ch,cd,sv.name,sv.specification,where,lines,listtoutf(list))
                                end
                            end
                        elseif trace_vsnapping then
                            report_snapper("mvl %a not snapped due to unknown snap specification: %s",nodecodes[id],listtoutf(list))
                        end
                        setattr(current,a_snapmethod,0)
                    end
                else
                    --
                end
            --  tex.prevdepth = 0
                flush("list")
                current = getnext(current)
            elseif id == penalty_code then
             -- natural_penalty = getpenalty(current)
             -- if trace then
             --     trace_done("removed penalty",current)
             -- end
             -- head, current = remove_node(head, current, true)
                current = getnext(current)
            elseif id == kern_code then
                if snap and trace_vsnapping and getkern(current) ~= 0 then
                    report_snapper("kern of %p kept",getkern(current))
                end
                flush("kern")
                current = getnext(current)
            elseif id == glue_code then
                local subtype = getsubtype(current)
                if subtype == userskip_code then
                    local sc = getattr(current,a_skipcategory)   -- has no default, no unset (yet)
                    local so = getattr(current,a_skiporder) or 1 -- has  1 default, no unset (yet)
                    local sp = getattr(current,a_skippenalty)    -- has no default, no unset (yet)
                    if sp and sc == penalty then
                        if where == "page" then
                            getpagelist()
                            local p = specialmethods[specialmethod](pagehead,pagetail,current,sp)
                            if p then
                             -- todo: other tracer
                             --
                             -- if trace then
                             --     trace_skip("previous special penalty %a is changed to %a using method %a",sp,p,specialmethod)
                             -- end
                                special_penalty = sp
                                sp = p
                            end
                        end
                        if not penalty_data then
                            penalty_data = sp
                        elseif penalty_order < so then
                            penalty_order, penalty_data = so, sp
                        elseif penalty_order == so and sp > penalty_data then
                            penalty_data = sp
                        end
                        if trace then
                            trace_skip("penalty in skip",sc,so,sp,current)
                        end
                        head, current = remove_node(head, current, true)
                    elseif not sc then  -- if not sc then
                        if glue_data then
                            if trace then
                                trace_done("flush",glue_data)
                            end
                            head = insert_node_before(head,current,glue_data)
                            if trace then
                                trace_natural("natural",current)
                            end
                            current = getnext(current)
                        else
                            -- not look back across head
                            -- todo: prev can be whatsit (latelua)
                            local previous = getprev(current)
                            if previous and getid(previous) == glue_code and getsubtype(previous) == userskip_code then
                                local pwidth, pstretch, pshrink, pstretch_order, pshrink_order = getglue(previous)
                                local cwidth, cstretch, cshrink, cstretch_order, cshrink_order = getglue(current)
                                if pstretch_order == 0 and pshrink_order == 0 and cstretch_order == 0 and cshrink_order == 0 then
                                    setglue(previous,pwidth + cwidth, pstretch + cstretch, pshrink  + cshrink)
                                    if trace then
                                        trace_natural("removed",current)
                                    end
                                    head, current = remove_node(head, current, true)
                                    if trace then
                                        trace_natural("collapsed",previous)
                                    end
                                else
                                    if trace then
                                        trace_natural("filler",current)
                                    end
                                    current = getnext(current)
                                end
                            else
                                if trace then
                                    trace_natural("natural (no prev)",current)
                                end
                                current = getnext(current)
                            end
                        end
                        glue_order, glue_data = 0, nil
                    elseif sc == disable or sc == enable then
                        local next = getnext(current)
                        if next then
                            ignore_following = sc == disable
                            if trace then
                                trace_skip(sc == disable and "disable" or "enable",sc,so,sp,current)
                            end
                            head, current = remove_node(head, current, true)
                        else
                            current = next
                        end
                    elseif sc == packed then
                        if trace then
                            trace_skip("packed",sc,so,sp,current)
                        end
                        -- can't happen !
                        head, current = remove_node(head, current, true)
                    elseif sc == nowhite then
                        local next = getnext(current)
                        if next then
                            ignore_whitespace = true
                            head, current = remove_node(head, current, true)
                        else
                            current = next
                        end
                    elseif sc == discard then
                        if trace then
                            trace_skip("discard",sc,so,sp,current)
                        end
                        head, current = remove_node(head, current, true)
                    elseif sc == overlay then
                        -- todo (overlay following line over previous
                        if trace then
                            trace_skip("overlay",sc,so,sp,current)
                        end
                            -- beware: head can actually be after the affected nodes as
                            -- we look back ... some day head will the real head
                        head, current = check_experimental_overlay(head,current,a_snapmethod)
                    elseif ignore_following then
                        if trace then
                            trace_skip("disabled",sc,so,sp,current)
                        end
                        head, current = remove_node(head, current, true)
                    elseif not glue_data then
                        if trace then
                            trace_skip("assign",sc,so,sp,current)
                        end
                        glue_order = so
                        head, current, glue_data = remove_node(head, current)
                    elseif glue_order < so then
                        if trace then
                            trace_skip("force",sc,so,sp,current)
                        end
                        glue_order = so
                        flush_node(glue_data)
                        head, current, glue_data = remove_node(head, current)
                    elseif glue_order == so then
                        -- is now exclusive, maybe support goback as combi, else why a set
                        if sc == largest then
                            local cw = getwidth(current)
                            local gw = getwidth(glue_data)
                            if cw > gw then
                                if trace then
                                    trace_skip("largest",sc,so,sp,current)
                                end
                                flush_node(glue_data)
                                head, current, glue_data = remove_node(head,current)
                            else
                                if trace then
                                    trace_skip("remove smallest",sc,so,sp,current)
                                end
                                head, current = remove_node(head, current, true)
                            end
                        elseif sc == goback then
                            if trace then
                                trace_skip("goback",sc,so,sp,current)
                            end
                            flush_node(glue_data)
                            head, current, glue_data = remove_node(head,current)
                        elseif sc == force then
                            -- last one counts, some day we can provide an accumulator and largest etc
                            -- but not now
                            if trace then
                                trace_skip("force",sc,so,sp,current)
                            end
                            flush_node(glue_data)
                            head, current, glue_data = remove_node(head, current)
                        elseif sc == penalty then
                            if trace then
                                trace_skip("penalty",sc,so,sp,current)
                            end
                            flush_node(glue_data)
                            glue_data = nil
                            head, current = remove_node(head, current, true)
                        elseif sc == add then
                            if trace then
                                trace_skip("add",sc,so,sp,current)
                            end
                            local cwidth, cstretch, cshrink = getglue(current)
                            local gwidth, gstretch, gshrink = getglue(glue_data)
                            setglue(old,gwidth + cwidth, gstretch + cstretch, gshrink + cshrink)
                            -- toto: order
                            head, current = remove_node(head, current, true)
                        else
                            if trace then
                                trace_skip("unknown",sc,so,sp,current)
                            end
                            head, current = remove_node(head, current, true)
                        end
                    else
                        if trace then
                            trace_skip("unknown",sc,so,sp,current)
                        end
                        head, current = remove_node(head, current, true)
                    end
                    if sc == force then
                        force_glue = true
                    end
                elseif subtype == lineskip_code then
                    if snap then
                        local s = getattr(current,a_snapmethod)
                        if s and s ~= 0 then
                            setattr(current,a_snapmethod,0)
                            setwidth(current,0)
                            if trace_vsnapping then
                                report_snapper("lineskip set to zero")
                            end
                        else
                            if trace then
                                trace_skip("lineskip",sc,so,sp,current)
                            end
                            flush("lineskip")
                        end
                    else
                        if trace then
                            trace_skip("lineskip",sc,so,sp,current)
                        end
                        flush("lineskip")
                    end
                    current = getnext(current)
                elseif subtype == baselineskip_code then
                    if snap then
                        local s = getattr(current,a_snapmethod)
                        if s and s ~= 0 then
                            setattr(current,a_snapmethod,0)
                            setwidth(current,0)
                            if trace_vsnapping then
                                report_snapper("baselineskip set to zero")
                            end
                        else
                            if trace then
                                trace_skip("baselineskip",sc,so,sp,current)
                            end
                            flush("baselineskip")
                        end
                    else
                        if trace then
                            trace_skip("baselineskip",sc,so,sp,current)
                        end
                        flush("baselineskip")
                    end
                    current = getnext(current)
                elseif subtype == parskip_code then
                    -- parskip always comes later
                    if ignore_whitespace then
                        if trace then
                            trace_natural("ignored parskip",current)
                        end
                        head, current = remove_node(head, current, true)
                    elseif glue_data then
                        local w = getwidth(current)
                        if (w ~= 0) and (w > getwidth(glue_data)) then
                            glue_data = current
                            if trace then
                                trace_natural("taking parskip",current)
                            end
                            head, current = remove_node(head, current)
                        else
                            if trace then
                                trace_natural("removed parskip",current)
                            end
                            head, current = remove_node(head, current, true)
                        end
                    else
                        if trace then
                            trace_natural("honored parskip",current)
                        end
                        head, current, glue_data = remove_node(head, current)
                    end
                elseif subtype == topskip_code or subtype == splittopskip_code then
                    local next = getnext(current)
                    if next and getattr(next,a_skipcategory) == notopskip then
                        nuts.setglue(current) -- zero
                    end
                    if snap then
                        local s = getattr(current,a_snapmethod)
                        if s and s ~= 0 then
                            setattr(current,a_snapmethod,0)
                            local sv = snapmethods[s]
                            local w, cw = snap_topskip(current,sv)
                            if trace_vsnapping then
                                report_snapper("topskip snapped from %p to %p for %a",w,cw,where)
                            end
                        else
                            if trace then
                                trace_skip("topskip",sc,so,sp,current)
                            end
                            flush("topskip")
                        end
                    else
                        if trace then
                            trace_skip("topskip",sc,so,sp,current)
                        end
                        flush("topskip")
                    end
                    current = getnext(current)
                elseif subtype == abovedisplayskip_code and remove_math_skips then
                    --
                    if trace then
                        trace_skip("above display skip (normal)",sc,so,sp,current)
                    end
                    flush("above display skip (normal)")
                    current = getnext(current)
                    --
                elseif subtype == belowdisplayskip_code and remove_math_skips then
                    --
                    if trace then
                        trace_skip("below display skip (normal)",sc,so,sp,current)
                    end
                    flush("below display skip (normal)")
                    current = getnext(current)
                   --
                elseif subtype == abovedisplayshortskip_code and remove_math_skips then
                    --
                    if trace then
                        trace_skip("above display skip (short)",sc,so,sp,current)
                    end
                    flush("above display skip (short)")
                    current = getnext(current)
                    --
                elseif subtype == belowdisplayshortskip_code and remove_math_skips then
                    --
                    if trace then
                        trace_skip("below display skip (short)",sc,so,sp,current)
                    end
                    flush("below display skip (short)")
                    current = getnext(current)
                    --
                else -- other glue
                    if snap and trace_vsnapping then
                        local w = getwidth(current)
                        if w ~= 0 then
                            report_snapper("glue %p of type %a kept",w,gluecodes[subtype])
                        end
                    end
                    if trace then
                        trace_skip(formatters["glue of type %a"](subtype),sc,so,sp,current)
                    end
                    flush("some glue")
                    current = getnext(current)
                end
            else
                flush(formatters["node with id %a"](id))
                current = getnext(current)
            end
        end
        if trace then
            trace_info("stop analyzing",where,what)
        end
     -- if natural_penalty and (not penalty_data or natural_penalty > penalty_data) then
     --     penalty_data = natural_penalty
     -- end
        if trace and (glue_data or penalty_data) then
            trace_info("start flushing",where,what)
        end
        local tail
        if penalty_data then
            tail = find_node_tail(head)
            local p = new_penalty(penalty_data)
            if trace then
                trace_done("result",p)
            end
            setlink(tail,p)
         -- if penalty_data > special_penalty_min and penalty_data < special_penalty_max then
                local props = properties[p]
                if props then
                    props.special_penalty = special_penalty or penalty_data
                else
                    properties[p] = {
                        special_penalty = special_penalty or penalty_data
                    }
                end
         -- end
        end
        if glue_data then
            if not tail then tail = find_node_tail(head) end
            if trace then
                trace_done("result",glue_data)
            end
            if force_glue then
                head, tail = forced_skip(head,tail,getwidth(glue_data),"after",trace)
                flush_node(glue_data)
                glue_data = nil
            elseif tail then
                setlink(tail,glue_data)
            else
                head = glue_data
            end
            texnest[texnest.ptr].prevdepth = 0 -- appending to the list bypasses tex's prevdepth handler
        end
        if trace then
            if glue_data or penalty_data then
                trace_info("stop flushing",where,what)
            end
            show_tracing(head)
            if oldhead ~= head then
                trace_info("head has been changed from %a to %a",nodecodes[getid(oldhead)],nodecodes[getid(head)])
            end
        end
        return head
    end

    -- alignment after_output end box new_graf vmode_par hmode_par insert penalty before_display after_display
    -- \par -> vmode_par
    --
    -- status.best_page_break
    -- tex.lists.best_page_break
    -- tex.lists.best_size (natural size to best_page_break)
    -- tex.lists.least_page_cost (badness of best_page_break)
    -- tex.lists.page_head
    -- tex.lists.contrib_head

    -- do

    local stackhead, stacktail, stackhack = nil, nil, false

    local function report(message,where,lst)
        if lst and where then
            report_vspacing(message,where,count_nodes(lst,true),nodeidstostring(lst))
        else
            report_vspacing(message,count_nodes(lst,true),nodeidstostring(lst))
        end
    end

    -- ugly code: we get partial lists (check if this stack is still okay) ... and we run
    -- into temp nodes (sigh)

    local forceflush = false

    function vspacing.pagehandler(newhead,where)
        -- local newhead = texlists.contrib_head
        if newhead then
            local newtail = find_node_tail(newhead) -- best pass that tail, known anyway
            local flush = false
            stackhack = true -- todo: only when grid snapping once enabled
            -- todo: fast check if head = tail
            for n, id, subtype in nextnode, newhead do -- we could just look for glue nodes
                if id ~= glue_code then
                    flush = true
                elseif subtype == userskip_code then
                    if getattr(n,a_skipcategory) then
                        stackhack = true
                    else
                        flush = true
                    end
                elseif subtype == parskip_code then
                    -- if where == new_graf then ... end
                    if texgetcount("c_spac_vspacing_ignore_parskip") > 0 then
                     -- texsetcount("c_spac_vspacing_ignore_parskip",0)
                        setglue(n)
                     -- maybe removenode
                    end
                end
            end
            texsetcount("c_spac_vspacing_ignore_parskip",0)

            if forceflush then
                forceflush = false
                flush      = true
            end

            if flush then
                if stackhead then
                    if trace_collect_vspacing then report("%s > appending %s nodes to stack (final): %s",where,newhead) end
                    setlink(stacktail,newhead)
                    newhead   = stackhead
                    stackhead = nil
                    stacktail = nil
                end
                if stackhack then
                    stackhack = false
                    if trace_collect_vspacing then report("%s > processing %s nodes: %s",where,newhead) end
                 -- texlists.contrib_head = collapser(newhead,"page",where,trace_page_vspacing,true,a_snapmethod)
                    newhead = collapser(newhead,"page",where,trace_page_vspacing,true,a_snapmethod)
                else
                    if trace_collect_vspacing then report("%s > flushing %s nodes: %s",where,newhead) end
                 -- texlists.contrib_head = newhead
                end
                return newhead
            else
                if stackhead then
                    if trace_collect_vspacing then report("%s > appending %s nodes to stack (intermediate): %s",where,newhead) end
                    setlink(stacktail,newhead)
                else
                    if trace_collect_vspacing then report("%s > storing %s nodes in stack (initial): %s",where,newhead) end
                    stackhead = newhead
                end
                stacktail = newtail
            end
        end
        return nil
    end

 -- function vspacing.flushpagestack()
 --     if stackhead then
 --         local head = texlists.contrib_head
 --         if head then
 --             local tail = find_node_tail(head)
 --             setlink(tail,stackhead)
 --         else
 --             texlists.contrib_head = tonode(stackhead)
 --         end
 --         stackhead, stacktail = nil, nil
 --     end
 --
 -- end

    function vspacing.pageoverflow()
        local h = 0
        if stackhead then
            for n, id in nextnode, stackhead do
                if id == glue_code then
                    h = h + getwidth(n)
                elseif id == kern_code then
                    h = h + getkern(n)
                end
            end
        end
        return h
    end

    function vspacing.forcepageflush()
        forceflush = true
    end

    local ignore = table.tohash {
        "split_keep",
        "split_off",
     -- "vbox",
    }

    function vspacing.vboxhandler(head,where)
        if head and not ignore[where] and getnext(head) then
            if getnext(head) then -- what if a one liner and snapping?
                head = collapser(head,"vbox",where,trace_vbox_vspacing,true,a_snapvbox) -- todo: local snapper
                return head
            end
        end
        return head
    end

    function vspacing.collapsevbox(n,aslist) -- for boxes but using global a_snapmethod
        local box = getbox(n)
        if box then
            local list = getlist(box)
            if list then
                list = collapser(list,"snapper","vbox",trace_vbox_vspacing,true,a_snapmethod)
                if aslist then
                    setlist(box,list) -- beware, dimensions of box are wrong now
                else
                    setlist(box,vpack_node(list))
                end
            end
        end
    end

end

-- This one is needed to prevent bleeding of prevdepth to the next page
-- which doesn't work well with forced skips. I'm not that sure if the
-- following is a good way out.

do

    local outer   = texnest[0]

    local enabled = true
    local trace   = false
    local report  = logs.reporter("vspacing")

    trackers.register("vspacing.synchronizepage",function(v)
        trace = v
    end)

    directives.register("vspacing.synchronizepage",function(v)
        enabled = v
    end)

    local ignoredepth = -65536000

    -- A previous version analyzed the number of lines moved to the next page in
    -- synchronizepage because prevgraf is unreliable in that case. However, we cannot
    -- tweak that parameter because it is also used in postlinebreak and hangafter, so
    -- there is a danger for interference. Therefore we now do it dynamically.

    -- We can also support other lists but there prevgraf probably is ok.

    function vspacing.getnofpreviouslines(head)
        if enabled then
            if not thead then
                head = texlists.page_head
            end
            local noflines = 0
            if head then
                local tail = find_node_tail(tonut(head))
                while tail do
                    local id = getid(tail)
                    if id == hlist_code then
                        if getsubtype(tail) == linelist_code then
                            noflines = noflines + 1
                        else
                            break
                        end
                    elseif id == vlist_code then
                        break
                    elseif id == glue_code then
                        local subtype = getsubtype(tail)
                        if subtype == baselineskip_code or subtype == lineskip_code then
                            -- we're ok
                        elseif subtype == parskip_code then
                            if getwidth(tail) > 0 then
                                break
                            else
                                -- we assume we're ok
                            end
                        end
                    elseif id == penalty_code then
                        -- we're probably ok
                    elseif id == rule_code or id == kern_code then
                        break
                    else
                        -- ins, mark, boundary, whatsit
                    end
                    tail = getprev(tail)
                end
            end
            return noflines
        end
    end

    interfaces.implement {
        name    = "getnofpreviouslines",
        public  = true,
        actions = vspacing.getnofpreviouslines,
    }

    function vspacing.synchronizepage()
        if enabled then
            if trace then
                local newdepth = outer.prevdepth
                local olddepth = newdepth
                if not texlists.page_head then
                    newdepth = ignoredepth
                    texset("prevdepth",ignoredepth)
                    outer.prevdepth = ignoredepth
                end
                report("page %i, prevdepth %p => %p",texgetcount("realpageno"),olddepth,newdepth)
             -- report("list %s",nodes.idsandsubtypes(head))
            else
                if not texlists.page_head then
                    texset("prevdepth",ignoredepth)
                    outer.prevdepth = ignoredepth
                end
            end
        end
    end

    local trace = false

    trackers.register("vspacing.forcestrutdepth",function(v) trace = v end)

    local last = nil

 -- function vspacing.forcestrutdepth(n,depth,trace_mode,plus)
 --     local box = texgetbox(n)
 --     if box then
 --         box = tonut(box)
 --         local head = getlist(box)
 --         if head then
 --             local tail = find_node_tail(head)
 --             if tail and getid(tail) == hlist_code then
 --                 local dp = getdepth(tail)
 --                 if dp < depth then
 --                     setdepth(tail,depth)
 --                     outer.prevdepth = depth
 --                     if trace or trace_mode > 0 then
 --                         nuts.setvisual(tail,"depth")
 --                     end
 --                 end
 --             end
 --         end
 --     end
 -- end

    function vspacing.forcestrutdepth(n,depth,trace_mode,plus)
        local box = texgetbox(n)
        if box then
            box = tonut(box)
            local head = getlist(box)
            if head then
                local tail = find_node_tail(head)
                if tail then
                    if getid(tail) == hlist_code then
                        local dp = getdepth(tail)
                        if dp < depth then
                            setdepth(tail,depth)
                            outer.prevdepth = depth
                            if trace or trace_mode > 0 then
                                nuts.setvisual(tail,"depth")
                            end
                        end
                    end
                    last = nil
                    if plus then
                        -- penalty / skip ...
                        local height = 0
                        local sofar  = 0
                        local same   = false
                        local seen   = false
                        local list   = { }
                              last   = nil
                        while tail do
                            local id = getid(tail)
                            if id == hlist_code or id == vlist_code then
                                local w, h, d = getwhd(tail)
                                height = height + h + d + sofar
                                sofar  = 0
                                last   = tail
                            elseif id == kern_code then
                                sofar = sofar + getkern(tail)
                            elseif id == glue_code then
                                if seen then
                                    sofar = sofar + getwidth(tail)
                                    seen  = false
                                else
                                    break
                                end
                            elseif id == penalty_code then
                                local p = getpenalty(tail)
                                if p >= 10000 then
                                    same = true
                                    seen = true
                                else
                                    break
                                end
                            else
                                break
                            end
                            tail = getprev(tail)
                        end
                        texsetdimen("global","d_spac_prevcontent",same and height or 0)
                    end
                end
            end
        end
    end

    function vspacing.pushatsame()
        -- needs better checking !
        if last then -- setsplit
            nuts.setnext(getprev(last))
            nuts.setprev(last)
        end
    end

    function vspacing.popatsame()
        -- needs better checking !
        nuts.write(last)
    end

end

-- interface

do

    implement {
        name      = "vspacing",
        actions   = vspacing.analyze,
        scope     = "private",
        arguments = "string"
    }

    implement {
        name      = "synchronizepage",
        actions   = vspacing.synchronizepage,
        scope     = "private"
    }

    implement {
        name      = "forcestrutdepth",
        arguments = { "integer", "dimension", "integer" },
        actions   = vspacing.forcestrutdepth,
        scope     = "private"
    }

    implement {
        name      = "forcestrutdepthplus",
        arguments = { "integer", "dimension", "integer", true },
        actions   = vspacing.forcestrutdepth,
        scope     = "private"
    }

    implement {
        name      = "pushatsame",
        actions   = vspacing.pushatsame,
        scope     = "private"
    }

    implement {
        name      = "popatsame",
        actions   = vspacing.popatsame,
        scope     = "private"
    }

    implement {
        name      = "vspacingsetamount",
        actions   = vspacing.setskip,
        scope     = "private",
        arguments = "string",
    }

    implement {
        name      = "vspacingdefine",
        actions   = vspacing.setmap,
        scope     = "private",
        arguments = "2 strings",
    }

    implement {
        name      = "vspacingcollapse",
        actions   = vspacing.collapsevbox,
        scope     = "private",
        arguments = "integer"
    }

    implement {
        name      = "vspacingcollapseonly",
        actions   = vspacing.collapsevbox,
        scope     = "private",
        arguments = { "integer", true }
    }

    implement {
        name      = "vspacingsnap",
        actions   = vspacing.snapbox,
        scope     = "private",
        arguments = { "integer", "integer" }
    }

    implement {
        name      = "definesnapmethod",
        actions   = vspacing.definesnapmethod,
        scope     = "private",
        arguments = "2 strings",
    }

 -- local remove_node    = nodes.remove
 -- local find_node_tail = nodes.tail
 --
 -- interfaces.implement {
 --     name    = "fakenextstrutline",
 --     actions = function()
 --         local head = texlists.page_head
 --         if head then
 --             local head = remove_node(head,find_node_tail(head),true)
 --             texlists.page_head = head
 --             buildpage()
 --         end
 --     end
 -- }

    implement {
        name    = "removelastline",
        actions = function()
            local head = texlists.page_head
            if head then
                local tail = find_node_tail(head)
                if tail then
                    -- maybe check for hlist subtype 1
                    local head = remove_node(head,tail,true)
                    texlists.page_head = head
                    buildpage()
                end
            end
        end
    }

    implement {
        name    = "showpagelist", -- will improve
        actions = function()
            local head = texlists.page_head
            if head then
                print("start")
                while head do
                    print("  " .. tostring(head))
                    head = head.next
                end
            end
        end
    }

    implement {
        name    = "pageoverflow",
        actions = { vspacing.pageoverflow, context }
    }

    implement {
        name    = "forcepageflush",
        actions = vspacing.forcepageflush
    }

end
