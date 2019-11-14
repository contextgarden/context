 if not modules then modules = { } end modules ['spac-prf'] = {
    version   = 1.001,
    comment   = "companion to spac-prf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is a playground, a byproduct of some experiments in a project where
-- we needed something like this where it works ok, but nevertheless it's
-- still experimental code. It is very likely to change (or extended).

local unpack, rawget = unpack, rawget

local formatters        = string.formatters

local nodecodes         = nodes.nodecodes
local gluecodes         = nodes.gluecodes
local listcodes         = nodes.listcodes
local leadercodes       = nodes.leadercodes

local glyph_code        = nodecodes.glyph
local disc_code         = nodecodes.disc
local kern_code         = nodecodes.kern
local penalty_code      = nodecodes.penalty
local glue_code         = nodecodes.glue
local hlist_code        = nodecodes.hlist
local vlist_code        = nodecodes.vlist
local unset_code        = nodecodes.unset
local math_code         = nodecodes.math
local rule_code         = nodecodes.rule
local marginkern_code   = nodecodes.marginkern

local leaders_code      = leadercodes.leaders

local lineskip_code     = gluecodes.lineskip
local baselineskip_code = gluecodes.baselineskip

local linelist_code     = listcodes.line

local texlists          = tex.lists
local settexattribute   = tex.setattribute

local nuts              = nodes.nuts
local tonut             = nodes.tonut
local tonode            = nuts.tonode

local getreplace        = nuts.getreplace
local getattr           = nuts.getattr
local getid             = nuts.getid
local getnext           = nuts.getnext
local getprev           = nuts.getprev
local getsubtype        = nuts.getsubtype
local getlist           = nuts.getlist
local gettexbox         = nuts.getbox
local getwhd            = nuts.getwhd
local getglue           = nuts.getglue
local getkern           = nuts.getkern
local getshift          = nuts.getshift
local getwidth          = nuts.getwidth
local getheight         = nuts.getheight
local getdepth          = nuts.getdepth
local getboxglue        = nuts.getboxglue

local setlink           = nuts.setlink
local setlist           = nuts.setlist
local setattr           = nuts.setattr
local setwhd            = nuts.setwhd
local setshift          = nuts.setshift
local setwidth          = nuts.setwidth
local setheight         = nuts.setheight
local setdepth          = nuts.setdepth

local properties        = nodes.properties.data
local setprop           = nuts.setprop
local getprop           = nuts.getprop
local theprop           = nuts.theprop

local floor             = math.floor
local ceiling           = math.ceil

local new_rule          = nuts.pool.rule
local new_glue          = nuts.pool.glue
local new_kern          = nuts.pool.kern
local hpack_nodes       = nuts.hpack
local find_node_tail    = nuts.tail
local setglue           = nuts.setglue

local a_visual          = attributes.private("visual")
local a_snapmethod      = attributes.private("snapmethod")
local a_profilemethod   = attributes.private("profilemethod")
----- a_specialcontent  = attributes.private("specialcontent")

local variables         = interfaces.variables
local v_none            = variables.none
local v_fixed           = variables.fixed
local v_strict          = variables.strict

local setcolor          = nodes.tracers.colors.set
local settransparency   = nodes.tracers.transparencies.set

local enableaction      = nodes.tasks.enableaction

local profiling         = { }
builders.profiling      = profiling

local report            = logs.reporter("profiling")

local show_profile      = false  trackers.register("profiling.show", function(v) show_profile  = v end)
local trace_profile     = false  trackers.register("profiling.trace",function(v) trace_profile = v end)

local function getprofile(line,step)

    -- only l2r
    -- no hz yet

    local line    = tonut(line)
    local current = getlist(line)

    if not current then
        return
    end

    local glue_set, glue_order, glue_sign  = getboxglue(line)

    local heights  = { }
    local depths   = { }
    local width    = 0
    local position = 0
    local step     = step or 65536 -- * 2 -- 2pt
    local margin   = step / 4
    local min      = 0
    local max      = ceiling(getwidth(line)/step) + 1
    local wd       = 0
    local ht       = 0
    local dp       = 0

    for i=min,max do
        heights[i] = 0
        depths [i] = 0
    end

    -- remember p

    local function progress()
        position = width
        width    = position + wd
            p = floor((position - margin)/step + 0.5)
            w = floor((width    + margin)/step - 0.5)
        if p < 0 then
            p = 0
        end
        if w < 0 then
            w = 0
        end
        if p > w then
            w, p = p, w
        end
        if w > max then
            for i=max+1,w+1 do
                heights[i] = 0
                depths [i] = 0
            end
            max = w
        end
        for i=p,w do
            if ht > heights[i] then
                heights[i] = ht
            end
            if dp > depths[i] then
                depths[i] = dp
            end
        end
    end

    local function process(current) -- called nested in disc replace
        while current do
            local id = getid(current)
            if id == glyph_code then
                wd, ht, dp = getwhd(current)
                progress()
            elseif id == kern_code then
                wd = getkern(current)
                ht = 0
                dp = 0
                progress()
            elseif id == disc_code then
                local replace = getreplace(current)
                if replace then
                    process(replace)
                end
            elseif id == glue_code then
                local width, stretch, shrink, stretch_order, shrink_order = getglue(current)
                if glue_sign == 1 then
                    if stretch_order == glue_order then
                        wd = width + stretch * glue_set
                    else
                        wd = width
                    end
                elseif glue_sign == 2 then
                    if shrink_order == glue_order then
                        wd = width - shrink * glue_set
                    else
                        wd = width
                    end
                else
                    wd = width
                end
                if getsubtype(current) >= leaders_code then
                    local leader = getleader(current)
                    local w
                    w, ht, dp = getwhd(leader) -- can become getwhd(current) after 1.003
                else
                    ht = 0
                    dp = 0
                end
                progress()
            elseif id == hlist_code then
                -- we could do a nested check .. but then we need to push / pop glue
                local shift = getshift(current)
                local w, h, d = getwhd(current)
             -- if getattr(current,a_specialcontent) then
                if getprop(current,"specialcontent") then
                    -- like a margin note, maybe check for wd
                    wd = w
                    ht = 0
                    dp = 0
                else
                    wd = w
                    ht = h - shift
                    dp = d + shift
                end
                progress()
            elseif id == vlist_code or id == unset_code then
                local shift = getshift(current) -- todo
                wd, ht, dp = getwhd(current)
                progress()
            elseif id == rule_code then
                wd, ht, dp = getwhd(current)
                progress()
            elseif id == math_code then
                wd = getkern(current) + getwidth(current) -- surround
                ht = 0
                dp = 0
                progress()
            elseif id == marginkern_code then
                wd = getwidth(current)
                ht = 0
                dp = 0
                progress()
            else
--     print(nodecodes[id])
            end
            current = getnext(current)
        end
    end

    process(current)

    return {
        heights = heights,
        depths  = depths,
        min     = min, -- not needed
        max     = max,
        step    = step,
    }

end

profiling.get = getprofile

local function getpagelist()
    local pagehead = texlists.page_head
    if pagehead then
        pagehead = tonut(texlists.page_head)
        pagetail = find_node_tail(pagehead)
    else
        pagetail = nil
    end
    return pagehead, pagetail
end

local function setprofile(n,step)
    local p = rawget(properties,n)
    if p then
        local pp = p.profile
        if not pp then
            pp = getprofile(n,step)
            p.profile = pp
        end
        return pp
    else
        local pp = getprofile(n,step)
        properties[n] = { profile = pp }
        return pp
    end
end

local function hasprofile(n)
    local p = rawget(properties,n)
    if p then
        return p.profile
    end
end

local function addstring(height,depth)
    local typesetters = nuts.typesetters
    local hashes   = fonts.hashes
    local infofont = fonts.infofont()
    local emwidth  = hashes.emwidths [infofont]
    local exheight = hashes.exheights[infofont]
    local httext   = height
    local dptext   = depth
    local httext   = typesetters.tohpack(height,infofont)
    local dptext   = typesetters.tohpack(depth,infofont)
    setshift(httext,- 1.2 * exheight)
    setshift(dptext,  0.6 * exheight)
    local text = hpack_nodes(setlink(
        new_kern(-getwidth(httext)-emwidth),
        httext,
        new_kern(-getwidth(dptext)),
        dptext
    ))
    setwhd(text,0,0,0)
    return text
end

local function addprofile(node,profile,step)

    local line = tonut(node)

    if not profile then
        profile = setprofile(line,step)
    end

    if not profile then
        report("some error")
        return node
    end

    if profile.shown then
        return node
    end

    local list    = getlist(line)
    profile.shown = true

    local heights = profile.heights
    local depths  = profile.depths
    local step    = profile.step

    local head    = nil
    local tail    = nil

    local lastht  = 0
    local lastdp  = 0
    local lastwd  = 0

    local visual  = "f:s:t" -- this can change !

    local function progress()
        if lastwd == 0 then
            return
        end
        local what = nil
        if lastht == 0 and lastdp == 0 then
            what = new_kern(lastwd)
        else
            what = new_rule(lastwd,lastht,lastdp)
            setcolor(what,visual)
            settransparency(what,visual)
        end
        if tail then
            setlink(tail,what)
        else
            head = what
        end
        tail = what
    end

-- inspect(profile)

    for i=profile.min,profile.max do
        local ht = heights[i]
        local dp = depths[i]
        if ht ~= lastht or dp ~= lastdp and lastwd > 0 then
            progress()
            lastht = ht
            lastdp = dp
            lastwd = step
        else
            lastwd = lastwd + step
        end
    end
    if lastwd > 0 then
        progress()
    end

    local rule = hpack_nodes(head)

    setwhd(rule,0,0,0)

 -- if texttoo then
 --
 --     local text = addstring(
 --         formatters["%0.4f"](getheight(rule)/65536),
 --         formatters["%0.4f"](getdepth(rule) /65536)
 --     )
 --
 --     setlink(text,rule)
 --
 --     rule = text
 --
 -- end

    setlink(rule,list)
    setlist(line,rule)

end

profiling.add = addprofile

local methods = { }

local function getdelta(t_profile,b_profile)
    local t_heights  = t_profile.heights
    local t_depths   = t_profile.depths
    local t_max      = t_profile.max
    local b_heights  = b_profile.heights
    local b_depths   = b_profile.depths
    local b_max      = b_profile.max

    local max        = t_max
    local delta      = 0

    if t_max > b_max then
        for i=b_max+1,t_max do
            b_depths [i] = 0
            b_heights[i] = 0
        end
        max = t_max
    elseif b_max > t_max then
        for i=t_max+1,b_max do
            t_depths [i] = 0
            t_heights[i] = 0
        end
        max = b_max
    end

    for i=0,max do
        local ht = b_heights[i]
        local dp = t_depths[i]
        local hd = ht + dp
        if hd > delta then
            delta = hd
        end
    end

    return delta
end

-- local properties = theprop(bot)
-- local unprofiled = properties.unprofiled
-- if not unprofiled then -- experiment
--     properties.unprofiled = {
--         height  = height,
--         strutht = strutht,
--     }
-- end

-- lineskip | lineskiplimit

local function inject(top,bot,amount) -- todo: look at penalties
    local glue = new_glue(amount)
    --
    setattr(glue,a_profilemethod,0)
    setattr(glue,a_visual,getattr(top,a_visual))
    --
    setlink(top,glue,bot)
end

methods[v_none] = function()
    return false
end

methods[v_strict] = function(top,bot,t_profile,b_profile,specification)

    local top        = tonut(top)
    local bot        = tonut(bot)

    local strutht    = specification.height or texdimen.strutht
    local strutdp    = specification.depth  or texdimen.strutdp
    local lineheight = strutht + strutdp

    local depth      = getdepth(top)
    local height     = getheight(bot)
    local total      = depth + height
    local distance   = specification.distance or 0
    local delta      = lineheight - total

    -- there is enough room between the lines so we don't need
    -- to add extra distance

    if delta >= distance then
        inject(top,bot,delta)
        return true
    end

    local delta = getdelta(t_profile,b_profile)
    local skip  = delta - total + distance

    -- we don't want to be too tight so we limit the skip and
    -- make sure we have at least lineheight

    inject(top,bot,skip)
    return true

end

-- todo: also set ht/dp of first / last (but what is that)

methods[v_fixed] = function(top,bot,t_profile,b_profile,specification)

    local top        = tonut(top)
    local bot        = tonut(bot)

    local strutht    = specification.height or texdimen.strutht
    local strutdp    = specification.depth  or texdimen.strutdp
    local lineheight = strutht + strutdp

    local depth      = getdepth(top)
    local height     = getheight(bot)
    local total      = depth + height
    local distance   = specification.distance or 0
    local delta      = lineheight - total

    local snapmethod = getattr(top,a_snapmethod)

    if snapmethod then

        -- no distance (yet)

        if delta < lineheight then
            setdepth(top,strutdp)
            setheight(bot,strutht)
            return true
        end

        local delta  = getdelta(t_profile,b_profile)

        local dp = strutdp
        while depth > lineheight - strutdp do
            depth = depth - lineheight
            dp = dp + lineheight
        end
        setdepth(top,dp)
        local ht = strutht
        while height > lineheight - strutht do
            height = height - lineheight
            ht = ht + lineheight
        end
        setheight(bot,ht)
        local lines = floor(delta/lineheight)
        if lines > 0 then
            inject(top,bot,-lines * lineheight)
        end

        return true

    end

    if total < lineheight then
        setdepth(top,strutdp)
        setheight(bot,strutht)
        return true
    end

    if depth < strutdp then
        setdepth(top,strutdp)
        total = total - depth + strutdp
    end
    if height < strutht then
        setheight(bot,strutht)
        total = total - height + strutht
    end

    local delta      = getdelta(t_profile,b_profile)

    local target     = total - delta
    local factor     = specification.factor or 1
    local step       = lineheight / factor
    local correction = 0
    local nofsteps   = 0
    while correction < target - step - distance do -- a loop is more accurate, for now
        correction = correction + step
        nofsteps   = nofsteps + 1
    end

    if trace_profile then
        report("top line     : %s %05i > %s",t_profile.shown and "+" or "-",top,nodes.toutf(getlist(top)))
        report("bottom line  : %s %05i > %s",b_profile.shown and "+" or "-",bot,nodes.toutf(getlist(bot)))
        report("  depth      : %p",depth)
        report("  height     : %p",height)
        report("  total      : %p",total)
        report("  lineheight : %p",lineheight)
        report("  delta      : %p",delta)
        report("  target     : %p",target)
        report("  factor     : %i",factor)
        report("  distance   : %p",distance)
        report("  step       : %p",step)
        report("  nofsteps   : %i",nofsteps)
     -- report("  max lines  : %s",lines == 0 and "unset" or lines)
        report("  correction : %p",correction)
    end

    inject(top,bot,-correction) -- we could mess with the present glue (if present)

    return true -- remove interlineglue

end

function profiling.distance(top,bot,specification)
    local step   = specification.step
    local method = specification.method
    local ptop   = getprofile(top,step)
    local pbot   = getprofile(bot,step)
    local action = methods[method or v_strict] or methods[v_strict]
    return action(top,bot,ptop,pbot,specification)
end

local specifications = { } -- todo: save these !

function profiling.fixedprofile(current)
    local a = getattr(current,a_profilemethod)
    if a then
        local s = specifications[a]
        if s then
            return s.method == v_fixed
        end
    end
    return false
end

local function profilelist(line,mvl)

    local current       = line

    local top           = nil
    local bot           = nil

    local t_profile     = nil
    local b_profile     = nil

    local specification = nil
    local lastattr      = nil
    local method        = nil
    local action        = nil

    local distance      = 0
    local lastglue      = nil

    local pagehead      = nil
    local pagetail      = nil

    if mvl then

        pagehead, pagetail = getpagelist()

        if pagetail then
            local current = pagetail
            while current do
                local id = getid(current)
                if id == hlist_code then
                    local subtype = getsubtype(current)
                    if subtype == linelist_code then
                        t_profile = hasprofile(current)
                        if t_profile then
                            top = current
                        end
                    end
                    break
                elseif id == glue_code then
                    local wd = getwidth(current)
                    if not wd or wd == 0 then
                        -- go on
                    else
                        break
                    end
                elseif id == penalty_code then
                    -- ok
                else
                    break
                end
                current = getnext(current)
            end
        end

    end

    while current do

        local attr = getattr(current,a_profilemethod)

        if attr then

            if attr ~= lastattr then
                specification = specifications[attr]
                method        = specification and specification.method
                action        = method and methods[method] or methods[v_strict]
                lastattr      = attr
            end

            local id = getid(current)

            if id == hlist_code then -- check subtype
                local subtype = getsubtype(current)
                if subtype == linelist_code then
                    if top == current then
                        -- skip
                        bot = nil -- to be sure
                    elseif top then
                        bot       = current
                        b_profile = setprofile(bot)
                        if show_profile then
                            addprofile(bot,b_profile)
                        end
                        if not t_profile.done then
                            if action then
                                local ok = action(top,bot,t_profile,b_profile,specification)
                                if ok and lastglue and distance ~= 0 then
                                    setglue(lastglue)
                                end
                            end
                            t_profile.done = true
                        end
                        top       = bot
                        bot       = nil
                        t_profile = b_profile
                        b_profile = nil
                        distance  = 0
                    else
                        top       = current
                        t_profile = setprofile(top)
                        bot       = nil
                        if show_profile then
                            addprofile(top,t_profile)
                        end
                    end
                else
                    top = nil
                    bot = nil
                end
            elseif id == glue_code then
                if top then
                    local subtype = getsubtype(current)
                 -- if subtype == lineskip_code or subtype == baselineskip_code then
                        local wd   = getwidth(current)
                        if wd > 0 then
                            distance = wd
                            lastglue = current
                        elseif wd < 0 then
                            top = nil
                            bot = nil
                        else
                            -- ok
                        end
                 -- else
                 --     top = nil
                 --     bot = nil
                 -- end
                else
                    top = nil
                    bot = nil
                end
            elseif id == penalty_code then
                -- okay
            else
                top = nil
                bot = nil
            end
        else
            top = nil
            bot = nil
        end
        current = getnext(current)
    end
    if top then
        t_profile = setprofile(top)
        if show_profile then
            addprofile(top,t_profile)
        end
    end
end

profiling.list = profilelist

local enabled = false

function profiling.set(specification)
    if not enabled then
        enableaction("mvlbuilders", "builders.profiling.pagehandler")
     -- too expensive so we expect that this happens explicitly, we keep for reference:
     -- enableaction("vboxbuilders","builders.profiling.vboxhandler")
        enabled = true
    end
    local n = #specifications + 1
    specifications[n] = specification
    settexattribute(a_profilemethod,n)
end

function profiling.profilebox(specification)
    local boxnumber = specification.box
    local current   = getlist(gettexbox(boxnumber))
    local top       = nil
    local bot       = nil
    local t_profile = nil
    local b_profile = nil
    local method    = specification and specification.method
    local action    = method and methods[method] or methods[v_strict]
    local lastglue  = nil
    local distance  = 0
    while current do
        local id = getid(current)
        if id == hlist_code then
            local subtype = getsubtype(current)
            if subtype == linelist_code then
                if top then
                    bot       = current
                    b_profile = setprofile(bot)
                    if show_profile then
                        addprofile(bot,b_profile)
                    end
                    if not t_profile.done then
                        if action then
                            local ok = action(top,bot,t_profile,b_profile,specification)
                            if ok and lastglue and distance ~= 0 then
                                setglue(lastglue)
                            end
                        end
                        t_profile.done = true
                    end
                    top       = bot
                    t_profile = b_profile
                    b_profile = nil
                    distance  = 0
                else
                    top       = current
                    t_profile = setprofile(top)
                    if show_profile then
                        addprofile(top,t_profile)
                    end
                    bot       = nil
                end
            else
                top = nil
                bot = nil
            end
        elseif id == glue_code then
            local subtype = getsubtype(current)
            if subtype == lineskip_code or subtype == baselineskip_code then
                if top then
                    local wd   = getwidth(current)
                    if wd > 0 then
                        distance = wd
                        lastglue = current
                    elseif wd < 0 then
                        top = nil
                        bot = nil
                    else
                        -- ok
                    end
                else
                    top = nil
                    bot = nil
                end
            else
                top = nil
                bot = nil
            end
        elseif id == penalty_code then
            -- okay
        else
            top = nil
            bot = nil
        end
        current = getnext(current)
    end

    if top then
        t_profile = setprofile(top) -- not needed
        if show_profile then
            addprofile(top,t_profile)
        end
    end

end

-- local ignore = table.tohash {
--     "split_keep",
--     "split_off",
--  -- "vbox",
-- }
--
-- function profiling.vboxhandler(head,where)
--     if head and not ignore[where] then
--         if getnext(head) then
--             profilelist(head)
--         end
--     end
--     return head
-- end

function profiling.pagehandler(head)
    if head then
        profilelist(head,true)
    end
    return head
end

interfaces.implement {
    name      = "setprofile",
    actions   = profiling.set,
    arguments = {
        {
            { "name" },
            { "height", "dimen" },
            { "depth", "dimen" },
            { "distance", "dimen" },
            { "factor", "integer" },
            { "lines", "integer" },
            { "method" }
        }
    }
}

interfaces.implement {
    name      = "profilebox",
    actions   = profiling.profilebox,
    arguments = {
        {
            { "box", "integer" },
            { "height", "dimen" },
            { "depth", "dimen" },
            { "distance", "dimen" },
            { "factor", "integer" },
            { "lines", "integer" },
            { "method" }
        }
    }
}
