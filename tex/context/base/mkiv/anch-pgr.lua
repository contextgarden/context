if not modules then modules = { } end modules ['anch-pgr'] = {
    version   = 1.001,
    comment   = "companion to anch-pgr.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is a bit messy module but backgrounds are messy anyway. Especially when we want to
-- follow shapes. This will always be work in progress as it also depends on new features
-- in context.
--
-- Alas, shapes and inline didn't work as expected end of 2016 so I had to pick up this
-- thread again. But with regular excursions to listening to Brad Mehldau's Mehliana I
-- could keep myself motivated. Some old stuff has been removed, some suboptimal code has
-- been replaced. Background code is still not perfect, but some day ... the details manual
-- will discuss this issue.

local tonumber = tonumber
local sort, concat = table.sort, table.concat
local splitter = lpeg.splitat(":")
local lpegmatch = lpeg.match

local jobpositions      = job.positions
local formatters        = string.formatters
local setmetatableindex = table.setmetatableindex

local enableaction      = nodes.tasks.enableaction

local commands          = commands
local context           = context

local implement         = interfaces.implement

local report_graphics   = logs.reporter("backgrounds")
local report_shapes     = logs.reporter("backgrounds","shapes")
local report_free       = logs.reporter("backgrounds","free")

local trace_shapes      = false  trackers.register("backgrounds.shapes",       function(v) trace_shapes = v end)
local trace_ranges      = false  trackers.register("backgrounds.shapes.ranges",function(v) trace_ranges = v end)
local trace_free        = false  trackers.register("backgrounds.shapes.free",  function(v) trace_free   = v end)

local f_b_tag           = formatters["b:%s"]
local f_e_tag           = formatters["e:%s"]
local f_p_tag           = formatters["p:%s"]

local f_tag_two         = formatters["%s:%s"]

local f_point           = formatters["%p"]
local f_pair            = formatters["(%p,%p)"]
local f_path            = formatters["%--t--cycle"]
local f_pair_i          = formatters["(%r,%r)"] -- rounded

graphics                = graphics or { }
local backgrounds       = { }
graphics.backgrounds    = backgrounds

-- -- --

local texsetattribute   = tex.setattribute

local a_textbackground  = attributes.private("textbackground")

local nuts              = nodes.nuts

local new_latelua       = nuts.pool.latelua
local new_rule          = nuts.pool.rule
local new_kern          = nuts.pool.kern
local new_hlist         = nuts.pool.hlist

local getbox            = nuts.getbox
local getid             = nuts.getid
----- getlist           = nuts.getlist
local setlink           = nuts.setlink
local getheight         = nuts.getheight
local getdepth          = nuts.getdepth

local nodecodes         = nodes.nodecodes
local localpar_code     = nodecodes.localpar

local start_of_par      = nuts.start_of_par
local insert_before     = nuts.insert_before
local insert_after      = nuts.insert_after

local processranges     = nuts.processranges

local unsetvalue        = attributes.unsetvalue

local jobpositions      = job.positions
local getpos            = jobpositions.getpos
local getfree           = jobpositions.getfree

local data              = { }
local realpage          = 1
local recycle           = 1000 -- only tables can overflow this
local enabled           = false

-- Freeing the data is somewhat tricky as we can have backgrounds spanning
-- many pages but for an arbitrary background shape that is not so common.

local function check(specification)
    local a     = specification.attribute
    local index = specification.index
    local depth = specification.depth
    local d     = specification.data
    local where = specification.where
    local ht    = specification.ht
    local dp    = specification.dp
    -- this is not yet r2l ready
    local w = d.shapes[realpage]
    local x, y = getpos()
    if trace_ranges then
        report_shapes("attribute %i, index %i, depth %i, location %s, position (%p,%p)",
            a,index,depth,where,x,y)
    end
    local n = #w
    if d.index ~= index then
        n = n + 1
        d.index = index
        d.depth = depth
     -- w[n] = { x, x, y, ht, dp }
        w[n] = { y, ht, dp, x, x }
    else
        local wn = w[n]
        local wh = wn[2]
        local wd = wn[3]
        if depth < d.depth then
            local wy = wn[1]
            wn[1] = y
            d.depth = depth
            local dy = wy - y
            wh = wh - dy
            wd = wd - dy
        end
        if where == "r" then
            if x > wn[5] then
                wn[5] = x
            end
        else
            if x < wn[4] then
                wn[4] = x
            end
        end
        if ht > wh then
            wn[2] = ht
        end
        if dp > wd then
            wn[3] = dp
        end
    end
 -- inspect(w)
end

local index = 0

local function flush(head,f,l,a,parent,depth)
    local d = data[a]
    if d then
        local ix = index
        local ht = getheight(parent)
        local dp = getdepth(parent)
        local ln = new_latelua { action = check, attribute = a, index = ix, depth = depth, data = d, where = "l", ht = ht, dp = dp }
        local rn = new_latelua { action = check, attribute = a, index = ix, depth = depth, data = d, where = "r", ht = ht, dp = dp }
        if trace_ranges then
            ln = new_hlist(setlink(new_rule(65536,65536*4,0),new_kern(-65536),ln))
            rn = new_hlist(setlink(new_rule(65536,0,65536*4),new_kern(-65536),rn))
        end
        if getid(f) == localpar_code and start_of_par(f) then -- we need to clean this mess
            insert_after(head,f,ln)
        else
            head, f = insert_before(head,f,ln)
        end
        insert_after(head,l,rn)
    end
    return head, true
end

local function registerbackground(name)
    local n = #data + 1
    if n > recycle then
        -- we could also free all e: that are beyond a page but we don't always
        -- know the page so a recycle is nicer and the s lists are kept anyway
        -- so the amount of kept data is not that large
        n = 1
    end
    local b = jobpositions.tobesaved["b:"..name]
    if b then
        local s = setmetatableindex("table")
        b.s = s
        data[n] = {
            bpos   = b,
            name   = name,
            n      = n,
            shapes = s,
            count  = 0,
            sindex = 0,
        }
        texsetattribute(a_textbackground,n)
        if not enabled then
            enableaction("contributers", "nodes.handlers.textbackgrounds")
            enabled = true
        end
    else
        texsetattribute(a_textbackground,unsetvalue)
    end
end

-- local function collectbackgrounds(r,n)
--     if enabled then
--         local parent = getbox(n)
--         local head   = getlist(parent)
--         realpage     = r
--         processranges(a_textbackground,flush,head) -- ,parent)
--     end
-- end
--
-- interfaces.implement {
--     name      = "collectbackgrounds",
--     actions   = collectbackgrounds,
--     arguments = { "integer", "integer" }
-- }

nodes.handlers.textbackgrounds = function(head,where,parent) -- we have hlistdir and local dir
    -- todo enable action in register
    index = index + 1
    return processranges(a_textbackground,flush,head,parent)
end

interfaces.implement {
    name      = "registerbackground",
    actions   = registerbackground,
    arguments = "string",
}

-- optimized already but we can assume a cycle i.e. prune the last point and then
-- even less code .. we could merge some loops but his is more robust

-- use idiv here

local function topairs(t,n)
    local r = { }
    for i=1,n do
        local ti = t[i]
        r[i] = f_pair_i(ti[1]/65556,ti[2]/65536)
    end
    return concat(r," ")
end

local eps = 65536 / 4
local pps =   eps
local nps = - pps

local function unitvector(x,y)
    if x < pps and x > nps then
        x = 0
    elseif x < 0 then
        x = -1
    else
        x = 1
    end
    if y < pps and y > nps then
        y = 0
    elseif y < 0 then
        y = -1
    else
        y = 1
    end
    return x, y
end

local function finish(t)
    local tm = #t
    if tm < 2 then
        return
    end
    if trace_ranges then
        report_shapes("initial list: %s",topairs(t,tm))
    end
    -- remove similar points
    local n  = 1
    local tn = tm
    local tf = t[1]
    local tx = tf[1]
    local ty = tf[2]
    for i=2,#t do
        local ti = t[i]
        local ix = ti[1]
        local iy = ti[2]
        local dx = ix - tx
        local dy = iy - ty
        if dx > eps or dx < - eps or dy > eps or dy < - eps then
            n = n + 1
            t[n] = ti
            tx = ix
            ty = iy
        end
    end
    if trace_shapes then
        report_shapes("removing similar points: %s",topairs(t,n))
    end
    if n > 2 then
        -- remove redundant points
        repeat
            tn = n
            n  = 0
            local tm  = t[tn]
            local tmx = tm[1]
            local tmy = tm[2]
            local tp  = t[1]
            local tpx = tp[1]
            local tpy = tp[2]
            for i=1,tn do        -- while and only step when done
                local ti  = tp
                local tix = tpx
                local tiy = tpy
                if i == tn then
                    tp = t[1]
                else
                    tp = t[i+1]
                end
                tpx = tp[1]
                tpy = tp[2]

                local vx1, vx2 = unitvector(tix - tmx,tpx - tix)
                if vx1 ~= vx2 then
                    n = n + 1
                    t[n] = ti
                else
                    local vy1, vy2 = unitvector(tiy - tmy,tpy - tiy)
                    if vy1 ~= vy2 then
                        n = n + 1
                        t[n] = ti
                    end
                end

                tmx = tix
                tmy = tiy
            end
        until n == tn or n <= 2
        if trace_shapes then
            report_shapes("removing redundant points: %s",topairs(t,n))
        end
        -- remove spikes
        if n > 2 then
            repeat
                tn = n
                n  = 0
                local tm  = t[tn]
                local tmx = tm[1]
                local tmy = tm[2]
                local tp  = t[1]
                local tpx = tp[1]
                local tpy = tp[2]
                for i=1,tn do        -- while and only step when done
                    local ti  = tp
                    local tix = tpx
                    local tiy = tpy
                    if i == tn then
                        tp = t[1]
                    else
                        tp = t[i+1]
                    end
                    tpx = tp[1]
                    tpy = tp[2]

                    local vx1, vx2 = unitvector(tix - tmx,tpx - tix)
                    if vx1 ~= - vx2 then
                        n = n + 1
                        t[n] = ti
                    else
                        local vy1, vy2 = unitvector(tiy - tmy,tpy - tiy)
                        if vy1 ~= - vy2 then
                            n = n + 1
                            t[n] = ti
                        end
                    end

                    tmx = tix
                    tmy = tiy
                end
            until n == tn or n <= 2
            if trace_shapes then
                report_shapes("removing spikes: %s",topairs(t,n))
            end
        end
    end
    -- prune trailing points
    if tm > n then
        for i=tm,n+1,-1 do
            t[i] = nil
        end
    end
    if n > 1 then
        local tf = t[1]
        local tl = t[n]
        local dx = tf[1] - tl[1]
        local dy = tf[2] - tl[2]
        if dx > eps or dx < - eps or dy > eps or dy < - eps then
            -- different points
        else
            -- saves a point (as we -- cycle anyway)
            t[n] = nil
            n = n -1
        end
        if trace_shapes then
            report_shapes("removing cyclic endpoints: %s",topairs(t,n))
        end
    end
    return t
end

local eps = 65536

-- The next function can introduce redundant points but these are removed later on
-- in the unspiker. It makes checking easier.

local function shape(kind,b,p,realpage,xmin,xmax,ymin,ymax,fh,ld)
    local s = b.s
    if not s then
        if trace_shapes then
            report_shapes("calculating %s area, no shape",kind)
        end
        return
    end
    s = s[realpage]
    if not s then
        if trace_shapes then
            report_shapes("calculating %s area, no shape for page %s",kind,realpage)
        end
        return
    end
    local ns = #s
    if ns == 0 then
        if trace_shapes then
            report_shapes("calculating %s area, empty shape for page %s",kind,realpage)
        end
        return
    end
    --
    if trace_shapes then
        report_shapes("calculating %s area, using shape for page %s",kind,realpage)
    end
    -- it's a bit inefficient to use the par values and later compensate for b and
    -- e but this keeps the code (loop) cleaner
    local ph = p and p.h or 0
    local pd = p and p.d or 0
    --
    xmax = xmax + eps
    xmin = xmin - eps
    ymax = ymax + eps
    ymin = ymin - eps
    local ls = { } -- left shape
    local rs = { } -- right shape
    local pl = nil -- previous left x
    local pr = nil -- previous right x
    local n  = 0
    local xl = nil
    local xr = nil
    local mh = ph -- min
    local md = pd -- min
    for i=1,ns do
        local si = s[i]
        local y  = si[1]
        local ll = si[4] -- can be sparse
        if ll then
            xl = ll
            local rr = si[5] -- can be sparse
            if rr then
                xr = rr
            end
        end
        if trace_ranges then
            report_shapes("original  : [%02i]  xl=%p  xr=%p  y=%p",i,xl,xr,y)
        end
        if xl ~= xr then -- could be catched in the finalizer
            local xm = xl + (xr - xl)/2 -- midpoint should be in region
            if xm >= xmin and xm <= xmax and y >= ymin and y <= ymax then
                local ht = si[2] -- can be sparse
                if ht then
                    ph = ht
                    local dp = si[3] -- can be sparse
                    if dp then
                        pd = dp
                    end
                end
                local h = y + (ph < mh and mh or ph)
                local d = y - (pd < md and md or pd)
                if pl then
                    n = n + 1
                    ls[n] = { pl, h }
                    rs[n] = { pr, h }
                    if trace_ranges then
                        report_shapes("paragraph : [%02i]  xl=%p  xr=%p  y=%p",i,pl,pr,h)
                    end
                end
                n = n + 1
                ls[n] = { xl, h }
                rs[n] = { xr, h }
                if trace_ranges then
                    report_shapes("height    : [%02i]  xl=%p  xr=%p  y=%p",i,xl,xr,h)
                end
                n = n + 1
                ls[n] = { xl, d }
                rs[n] = { xr, d }
                if trace_ranges then
                    report_shapes("depth     : [%02i]  xl=%p  xr=%p  y=%p",i,xl,xr,d)
                end
            end
            pl, pr = xl, xr
        else
            if trace_ranges then
                report_shapes("ignored   : [%02i]  xl=%p  xr=%p  y=%p",i,xl,xr,y)
            end
        end
    end
    --
    if true and n > 0 then
        -- use height of b and depth of e, maybe check for weird border
        -- cases here
        if fh then
            local lsf = ls[1]
            local rsf = rs[1]
            if lsf[2] < fh then
                lsf[2] = fh
            end
            if rsf[2] < fh then
                rsf[2] = fh
            end
        end
        if fd then
            local lsl = ls[n]
            local rsl = rs[n]
            if lsl[2] > fd then
                lsl[2] = fd
            end
            if rsl[2] > fd then
                rsl[2] = fd
            end
        end
    end
    --
    for i=n,1,-1 do
        n = n + 1 rs[n] = ls[i]
    end
    return rs
end

local function singlepart(b,e,p,realpage,r,left,right)
    local bx = b.x
    local by = b.y
    local ex = e.x
    local ey = e.y
    local rx = r.x
    local ry = r.y
    local bh = by + b.h
    local bd = by - b.d
    local eh = ey + e.h
    local ed = ey - e.d
    local rh = ry + r.h
    local rd = ry - r.d
    local rw = rx + r.w
    if left then
        rx = rx + left
        rw = rw - right
    end
    if ex == rx then
        -- We probably have a strut at the next line so we force a width
        -- although of course it is better to move up. But as we have whitespace
        -- (at least visually) injected then it's best to stress the issue.
        ex = rw
    end
    local area
    if by == ey then
        if trace_shapes then
            report_shapes("calculating single area, partial line")
        end
        area = {
            { bx, bh },
            { ex, eh },
            { ex, ed },
            { bx, bd },
        }
    elseif b.k == 2 then
        area = {
            { rx, bh },
            { rw, bh },
            { rw, ed },
            { rx, ed },
        }
    else
        area = shape("single",b,p,realpage,rx,rw,rd,rh,bh,ed)
    end
    if not area then
        area = {
            { bx, bh },
            { rw, bh },
            { rw, eh },
            { ex, eh },
            { ex, ed },
            { rx, ed },
            { rx, bd },
            { bx, bd },
        }
    end
    return {
        location = "single",
        region   = r,
        area     = finish(area),
    }
end

local function firstpart(b,e,p,realpage,r,left,right)
    local bx = b.x
    local by = b.y
    local rx = r.x
    local ry = r.y
    local bh = by + b.h
    local bd = by - b.d
    local rh = ry + r.h
    local rd = ry - r.d
    local rw = rx + r.w
    if left then
        rx = rx + left
        rw = rw - right
    end
    local area = shape("first",b,p,realpage,rx,rw,rd,rh,bh,false)
    if not area then
        if b.k == 2 then
            area = {
                { rx, bh },
                { rw, bh },
                { rw, rd },
                { rx, rd },
            }
        else
            area = {
                { bx, bh },
                { rw, bh },
                { rw, rd }, -- { rw, eh },
                { rx, rd }, -- { rx, ed },
                { rx, bd },
                { bx, bd },
            }
        end
    end
    return {
        location = "first",
        region   = r,
        area     = finish(area),
    }
end

local function middlepart(b,e,p,realpage,r,left,right)
    local rx = r.x
    local ry = r.y
    local rh = ry + r.h
    local rd = ry - r.d
    local rw = rx + r.w
    if left then
        rx = rx + left
        rw = rw - right
    end
    local area = shape("middle",b,p,realpage,rx,rw,rd,rh,false,false)
    if not area then
        area = {
            { rw, rh },
            { rw, rd },
            { rx, rd },
            { rx, rh },
        }
    end
    return {
        location = "middle",
        region   = r,
        area     = finish(area),
    }
end

local function lastpart(b,e,p,realpage,r,left,right)
    local ex = e.x
    local ey = e.y
    local rx = r.x
    local ry = r.y
    local eh = ey + e.h
    local ed = ey - e.d
    local rh = ry + r.h
    local rd = ry - r.d
    local rw = rx + r.w
    if left then
        rx = rx + left
        rw = rw - right
    end
    local area  = shape("last",b,p,realpage,rx,rw,rd,rh,false,ed)
    if not area then
        if b.k == 2 then
            area = {
                { rw, rh },
                { rw, ed },
                { rx, ed },
                { rx, rh },
            }
        else
            area = {
                { rw, rh }, -- { rw, bh },
                { rw, eh },
                { ex, eh },
                { ex, ed },
                { rx, ed },
                { rx, rh }, -- { rx, bd },
            }
        end
    end
    return {
        location = "last",
        region   = r,
        area     = finish(area),
    }
end

local function calculatemultipar(tag)
    local collected = jobpositions.collected
    local b = collected[f_b_tag(tag)]
    local e = collected[f_e_tag(tag)]
    if not b or not e then
        report_shapes("invalid tag %a",tag)
        return { }
    end
    local br = b.r
    local er = e.r
    if not br or not er then
        report_shapes("invalid region for %a",tag)
        return { }
    end
    local btag, bindex = lpegmatch(splitter,br)
    local etag, eindex = lpegmatch(splitter,er)
    if not bindex or not eindex or btag ~= etag then
        report_shapes("invalid indices for %a",tag)
        return { }
    end
    local bindex = tonumber(bindex)
    local eindex = tonumber(eindex)
    -- Here we compensate for columns (in tables): a table can have a set of column
    -- entries and these are shared. We compensate left/right based on the columns
    -- x and w but need to take the region into acount where the specification was
    -- flushed and not the begin pos's region, because otherwise we get the wrong
    -- compensation for asymetrical doublesided layouts.
    local left  = 0
    local right = 0
    local bc    = b.c
    local rc    = bc and collected[bc]
    if rc then
        local tb = collected[rc.r]
        if tb then
            left  = -(tb.x - rc.x)
            right =  (tb.w - rc.w - left)
        end
    end
    -- Obeying intermediate changes of left/rightskip makes no sense as it will
    -- look bad, so we only look at the begin situation.
    local bn = b.n
    local p  = bn and collected[f_p_tag(bn)] -- par
    if p then
        left  = left  + (p.ls or 0)
        right = right + (p.rs or 0)
    end
    --
    local bp = b.p -- page
    if trace_shapes then
        report_shapes("tag %a, left %p, right %p, par %s, page %s, column %s",
            tag,left,right,bn or "-",bp or "-",bc or "-")
    end
    --
    if bindex == eindex then
        return {
            list = { [bp] = { singlepart(b,e,p,bp,collected[br],left,right) } },
            bpos = b,
            epos = e,
        }
    else
        local list = {
            [bp] = { firstpart(b,e,p,bp,collected[br],left,right) },
        }
        for i=bindex+1,eindex-1 do
            br = f_tag_two(btag,i)
            local r = collected[br]
            if not r then
               report_graphics("invalid middle for %a",br)
            else
                local rp = r.p -- page
                local pp = list[rp]
                local mp = middlepart(b,e,p,rp,r,left,right)
                if pp then
                    pp[#pp+1] = mp
                else
                    list[rp] = { mp }
                end
            end
        end
        local ep = e.p -- page
        local pp = list[ep]
        local lp = lastpart(b,e,p,ep,collected[er],left,right)
        if pp then
            pp[#pp+1] = lp
        else
            list[ep] = { lp }
        end
        return {
            list = list,
            bpos = b,
            epos = e,
        }
    end
end

local pbg = { } -- will move to pending

local multilocs = {
    single = 1, -- maybe 0
    first  = 1,
    middle = 2,
    last   = 3,
}

-- if unknown context_abck : input mp-abck.mpiv ; fi ;

local f_template_a = formatters[ [[
path multiregs[], multipars[], multibox ;
string multikind[] ;
numeric multilocs[], nofmultipars ;
nofmultipars := %s ;
multibox := unitsquare xyscaled (%p,%p) ;
numeric par_strut_height, par_strut_depth, par_line_height ;
par_strut_height := %p ;
par_strut_depth := %p ;
par_line_height := %p ;
]] ]

local f_template_b = formatters[ [[
multilocs[%s] := %s ;
multikind[%s] := "%s" ;
multipars[%s] := (%--t--cycle) shifted - (%p,%p) ;
]] ]

-- unspiked(simplified(%--t--cycle)) shifted - (%p,%p) ;

local f_template_c = formatters[ [[
setbounds currentpicture to multibox ;
]] ]

local function freemultipar(pagedata,frees) -- ,k
 -- if k == 3 then
 --     -- tables have local regions
 --     return
 -- end
    if not frees then
        return
    end
    local nfree = #frees
    if nfree == 0 then
        return
    end
    for i=1,#pagedata do
        local data  = pagedata[i]
        local area  = data.area

        if area then

            local region = data.region
            local y      = 0 -- region.y
         -- local x      = region.x
            local areas  = { }
            data.areas   = areas

            local f_1 = { }
            local n_1 = 0
            local f_2 = { }
            local n_2 = 0
            for i=1,#frees do
                local f = frees[i]
                local k = f.k
                if k == 1 then               -- pag
                    n_1 = n_1 + 1
                    f_1[n_1] = f
                elseif k == 2 or k == 3 then -- par
                    n_2 = n_2 + 1
                    f_2[n_2] = f
                end
            end

            local lineheight = tex.dimen.lineheight

            -- page floats

            local function check_one(free1,free2)
                local temp = { }
                local some = false
                local top  = (free2 and (y + free2.y + free2.h + (free2.to or 0))) or false
                local bot  = (free1 and (y + free1.y - free1.d - (free1.bo or 0))) or false
                for i=1,#area do
                    local a = area[i]
                    local x = a[1]
                    local y = a[2]
                    if free2 and y <= top then
                        y = top
                    end
                    if free1 and y >= bot then
                        y = bot
                    end
                    if not some then
                        some = y
                    elseif some == true then
                        -- done
                    elseif y ~= some then
                        some = true
                    end
                    temp[i] = { x, y }
                end
                if some == true then
                    areas[#areas+1] = temp
                end
            end

            if n_1 > 0 then
                check_one(false,f_1[1])
                for i=2,n_1 do
                    check_one(f_1[i-1],f_1[i])
                end
                check_one(f_1[n_1],false)
            end

            -- par floats

            if #areas == 0 then
                areas[1] = area
            end

            -- we can collect the coordinates first

            local function check_two(area,frees)
                local ul  = area[1]
                local ur  = area[2]
                local lr  = area[3]
                local ll  = area[4]
                local ulx = ul[1]
                local uly = ul[2]
                local urx = ur[1]
                local ury = ur[2]
                local lrx = lr[1]
                local lry = lr[2]
                local llx = ll[1]
                local lly = ll[2]

                local temp = { }
                local n    = 0
                local done = false

                for i=1,#frees do
                    local free = frees[i]
                    local fx   = free.x
                    local fy   = free.y
                    local ymax = y + fy + free.h + (free.to or 0)
                    local ymin = y + fy - free.d - (free.bo or 0)
                    local xmin =     fx          - (free.lo or 0)
                    local xmax =     fx + free.w + (free.ro or 0)
                    if free.k == 3 then
                        if uly <= ymax and uly >= ymin and lly <= ymin then
                            if trace_free then
                                report_free("case 1, top, right") -- ok
                            end
                            n = n + 1  temp[n] = { xmin, ury  }
                            n = n + 1  temp[n] = { xmin, ymin }
                            n = n + 1  temp[n] = { lrx,  ymin }
                            n = n + 1  temp[n] = { lrx,  lry  }
                            done = true
                        elseif uly >= ymax and lly <= ymin then
                            if trace_free then
                                report_free("case 2, outside, right") -- ok
                            end
                            if uly - ymax < lineheight then
                                n = n + 1  temp[n] = { xmin,  ury  }
                            else
                                n = n + 1  temp[n] = { urx,  ury  }
                                n = n + 1  temp[n] = { urx,  ymax }
                            end
                            n = n + 1  temp[n] = { xmin, ymax }
                            n = n + 1  temp[n] = { xmin, ymin }
                            n = n + 1  temp[n] = { lrx,  ymin }
                            n = n + 1  temp[n] = { lrx,  lry  }
                            done = true
                        elseif lly <= ymax and lly >= ymin and uly >= ymax then
                            if trace_free then
                                report_free("case 3, bottom, right")
                            end
                            if uly - ymax < lineheight then
                                n = n + 1  temp[n] = { xmin,  ury  }
                            else
                                n = n + 1  temp[n] = { urx,  ury  }
                                n = n + 1  temp[n] = { urx,  ymax }
                            end
                            n = n + 1  temp[n] = { xmin, ymax }
                            n = n + 1  temp[n] = { xmin, lry  }
                            done = true
                        elseif uly <= ymax and lly >= ymin then
                            if trace_free then
                                report_free("case 4, inside, right")
                            end
                            n = n + 1  temp[n] = { xmin, uly }
                            n = n + 1  temp[n] = { xmin, lly }
                            done = true
                        else
                            -- case 0
                            if trace_free then
                                report_free("case 0, nothing")
                            end
                        end
                    end
                end

                if not done then
                    if trace_free then
                        report_free("no right shape")
                    end
                    n = n + 1  temp[n] = { urx, ury }
                    n = n + 1  temp[n] = { lrx, lry }
                    n = n + 1  temp[n] = { llx, lly }
                else
                    done = false
                end

                for i=#frees,1,-1 do
                    local free = frees[i]
                    local fx   = free.x
                    local fy   = free.y
                    local ymax = y + fy + free.h + (free.to or 0)
                    local ymin = y + fy - free.d - (free.bo or 0)
                    local xmin =     fx          - (free.lo or 0)
                    local xmax =     fx + free.w + (free.ro or 0)
                    if free.k == 2 then
                        if uly <= ymax and uly >= ymin and lly <= ymin then
                            if trace_free then
                                report_free("case 1, top, left") -- ok
                            end
                            n = n + 1  temp[n] = { ulx,  ymin }
                            n = n + 1  temp[n] = { xmax, ymin }
                            n = n + 1  temp[n] = { xmax, uly  }
                            done = true
                        elseif uly >= ymax and lly <= ymin then
                            if trace_free then
                                report_free("case 2, outside, left") -- ok
                            end
                            n = n + 1  temp[n] = { llx,  lly  }
                            n = n + 1  temp[n] = { llx,  ymin }
                            n = n + 1  temp[n] = { xmax, ymin }
                            n = n + 1  temp[n] = { xmax, ymax }
                            if uly - ymax < lineheight then
                                n = n + 1  temp[n] = { xmax,  uly }
                            else
                                n = n + 1  temp[n] = { llx,  ymax }
                                n = n + 1  temp[n] = { llx,  uly  }
                            end
                            done = true
                        elseif lly <= ymax and lly >= ymin and uly >= ymax then
                            if trace_free then
                                report_free("case 3, bottom, left")
                            end
                            n = n + 1  temp[n] = { xmax, lly }
                            n = n + 1  temp[n] = { xmax, ymax }
                            if uly - ymax < lineheight then
                                n = n + 1  temp[n] = { xmax,  uly }
                            else
                                n = n + 1  temp[n] = { llx,  ymax }
                                n = n + 1  temp[n] = { llx,  uly }
                            end
                            done = true
                        elseif uly <= ymax and lly >= ymin then
                            if trace_free then
                                report_free("case 4, inside, left")
                            end
                            n = n + 1  temp[n] = { xmax, lly }
                            n = n + 1  temp[n] = { xmax, uly }
                            done = true
                        else
                            -- case 0
                        end
                    end
                end

                if not done then
                    if trace_free then
                        report_free("no left shape")
                    end
                    n = n + 1  temp[n] = { llx, lly }
                end
                n = n + 1  temp[n] = { ulx, uly }

                return temp
            end

            if n_2 > 0 then
                for i=1,#areas do
                    local area = areas[i]
                    if #area == 4 then -- and also check type, must be pargaraph
                        areas[i] = check_two(area,f_2)
                    else
                        -- message that not yet supported
                    end
                end
            end

            for i=1,#areas do
                finish(areas[i]) -- again
            end

        end

    end
end

local function fetchmultipar(n,anchor,page)
    local a = jobpositions.collected[anchor]
    if not a then
        report_graphics("missing anchor %a",anchor)
    else
        local data = pbg[n]
        if not data then
            data = calculatemultipar(n)
            pbg[n] = data -- can be replaced by register
         -- register(data.list,n,anchor)
        end
        local list = data and data.list
        if list then
            local pagedata = list[page]
            if pagedata then
                local k = data.bpos.k
                if k ~= 3 then
                    -- to be checked: no need in txt mode
                    freemultipar(pagedata,getfree(page))
                end
                local nofmultipars = #pagedata
                if trace_shapes then
                    report_graphics("fetching %a at page %s using anchor %a containing %s multipars",
                        n,page,anchor,nofmultipars)
                end
                local x      = a.x
                local y      = a.y
                local w      = a.w
                local h      = a.h
                local d      = a.d
                local bpos   = data.bpos
                local bh     = bpos.h
                local bd     = bpos.d
                local result = { false } -- slot 1 will be set later
                local n      = 0
                for i=1,nofmultipars do
                    local data     = pagedata[i]
                    local location = data.location
                    local region   = data.region
                    local areas    = data.areas
                    if not areas then
                        areas = { data.area }
                    end
                    for i=1,#areas do
                        local area = areas[i]
                        for i=1,#area do
                            local a = area[i]
                            area[i] = f_pair(a[1],a[2])
                        end
                        n = n + 1
                        result[n+1] = f_template_b(n,multilocs[location],n,location,n,area,x,y)
                    end
                end
                data[page]  = nil
                result[1]   = f_template_a(n,w,h+d,bh,bd,bh+bd) -- was delayed
                result[n+2] = f_template_c()
                return concat(result,"\n")
            end
        end
    end
    return f_template_a(0,0,0,0,0,0);
end

backgrounds.fetchmultipar = fetchmultipar

backgrounds.point = f_point
backgrounds.pair  = f_pair
backgrounds.path  = f_path

-- n anchor page

implement {
    name      = "fetchmultipar",
    actions   = { fetchmultipar, context },
    arguments = { "string", "string", "integer" }
}

local f_template_a = formatters[ [[
path posboxes[], posregions[] ;
numeric pospages[] ;
numeric nofposboxes ;
nofposboxes := %s ;
%t ;
]] ]

local f_template_b = formatters[ [[
pospages[%s] := %s ;
posboxes[%s] := (%p,%p)--(%p,%p)--(%p,%p)--(%p,%p)--cycle ;
posregions[%s] := (%p,%p)--(%p,%p)--(%p,%p)--(%p,%p)--cycle ;
]] ]

implement {
    name      = "fetchposboxes",
    arguments = { "string", "string", "integer" },
    actions   = function(tags,anchor,page)  -- no caching (yet) / todo: anchor, page
        local collected = jobpositions.collected
        if type(tags) == "string" then
            tags = utilities.parsers.settings_to_array(tags)
        end
        local list     = { }
        local nofboxes = 0
        for i=1,#tags do
            local tag= tags[i]
            local c = collected[tag]
            if c then
                local r = c.r
                if r then
                    r = collected[r]
                    if r then
                        local rx = r.x
                        local ry = r.y
                        local rw = r.w
                        local rh = r.h
                        local rd = r.d
                        local cx = c.x - rx
                        local cy = c.y
                        local cw = cx + c.w
                        local ch = cy + c.h
                        local cd = cy - c.d
                        nofboxes = nofboxes + 1
                        list[nofboxes] = f_template_b(
                            nofboxes,c.p,
                            nofboxes,cx,ch,cw,ch,cw,cd,cx,cd,
                            nofboxes,0,rh,rw,rh,rw,rd,0,rd
                        )
                    end
                end
            else
             -- print("\n missing",tag)
            end
        end
        context(f_template_a(nofboxes,list))
    end
}

local doifelse = commands.doifelse

implement {
    name      = "doifelserangeonpage",
    arguments = { "string", "string", "integer" },
    actions   = function(first,last,page)
        local c = jobpositions.collected
        local f = c[first]
        if f then
            f = f.p
            if f and f ~= true and page >= f then
                local l = c[last]
                if l then
                    l = l.p
                    doifelse(l and l ~= true and page <= l)
                    return
                end
            end
        end
        doifelse(false)
    end
}
