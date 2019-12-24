if not modules then modules = { } end modules ["page-cst"] = {
    version   = 1.001,
    comment   = "companion to page-cst.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: check what is used

local next, type, tonumber, rawget = next, type, tonumber, rawget
local ceil, odd, round = math.ceil, math.odd, math.round
local lower = string.lower
local copy = table.copy

local trace_state   = false  trackers.register("columnsets.trace",   function(v) trace_state  = v end)
local trace_details = false  trackers.register("columnsets.details", function(v) trace_details = v end)
local trace_cells   = false  trackers.register("columnsets.cells",   function(v) trace_cells  = v end)

local report       = logs.reporter("column sets")

local setmetatableindex = table.setmetatableindex

local properties        = nodes.properties.data

local nodecodes         = nodes.nodecodes

local hlist_code        = nodecodes.hlist
local vlist_code        = nodecodes.vlist
local kern_code         = nodecodes.kern
local glue_code         = nodecodes.glue
local penalty_code      = nodecodes.penalty
local rule_code         = nodecodes.rule

local nuts              = nodes.nuts
local tonode            = nuts.tonode
local tonut             = nuts.tonut

local vpack             = nuts.vpack
local flushlist         = nuts.flush_list
----- removenode        = nuts.remove

local setlink           = nuts.setlink
local setlist           = nuts.setlist
local setnext           = nuts.setnext
local setprev           = nuts.setprev
local setsubtype        = nuts.setsubtype
local setbox            = nuts.setbox
local getwhd            = nuts.getwhd
local setwhd            = nuts.setwhd
local getkern           = nuts.getkern
local getpenalty        = nuts.getpenalty
local getwidth          = nuts.getwidth
local getheight         = nuts.getheight

local getnext           = nuts.getnext
local getprev           = nuts.getprev
local getid             = nuts.getid
local getlist           = nuts.getlist
local getsubtype        = nuts.getsubtype
local takebox           = nuts.takebox
local takelist          = nuts.takelist
local splitbox          = nuts.splitbox
local getattribute      = nuts.getattribute
local copylist          = nuts.copy_list

local getbox            = nuts.getbox
local getcount          = tex.getcount
local getdimen          = tex.getdimen

local texsetbox         = tex.setbox
local texsetcount       = tex.setcount
local texsetdimen       = tex.setdimen

local theprop           = nuts.theprop

local nodepool          = nuts.pool

local new_vlist         = nodepool.vlist
local new_trace_rule    = nodepool.rule
local new_empty_rule    = nodepool.emptyrule

local context           = context
local implement         = interfaces.implement

local variables         = interfaces.variables
local v_here            = variables.here
local v_fixed           = variables.fixed
local v_top             = variables.top
local v_bottom          = variables.bottom
local v_repeat          = variables["repeat"]
local v_yes             = variables.yes
local v_page            = variables.page
local v_first           = variables.first
local v_last            = variables.last
----- v_wide            = variables.wide

pagebuilders            = pagebuilders or { } -- todo: pages.builders
pagebuilders.columnsets = pagebuilders.columnsets or { }
local columnsets        = pagebuilders.columnsets

local data = { [""] = { } }

-- todo: use state

local function setstate(t,start)
    if start or not t.firstcolumn then
        t.firstcolumn = odd(getcount("realpageno")) and 1 or 2
    end
    if t.firstcolumn > 1 then
        t.firstcolumn = 1
        t.lastcolumn  = t.nofleft
        t.state       = "left"
    else
        t.firstcolumn = t.nofleft + 1
        t.lastcolumn  = t.firstcolumn + t.nofright - 1
        t.state       = "right"
    end
    t.currentcolumn = t.firstcolumn
    t.currentrow    = 1
end

function columnsets.define(t)
    local name            = t.name
    local nofleft         = t.nofleft or 1
    local nofright        = t.nofright or 1
    local nofcolumns      = nofleft + nofright
    local dataset         = data[name] or { }
    data[name]            = dataset
    dataset.nofleft       = nofleft
    dataset.nofright      = nofright
    dataset.nofcolumns    = nofcolumns
    dataset.nofrows       = t.nofrows or 1
    dataset.distance      = t.distance or getdimen("bodyfontsize")
    dataset.maxwidth      = t.maxwidth or getdimen("makeupwidth")
    dataset.lineheight    = t.lineheight or getdimen("globalbodyfontstrutheight")
    dataset.linedepth     = t.linedepth or getdimen("globalbodyfontstrutdepth")
    --
    dataset.cells         = { }
    dataset.currentcolumn = 1
    dataset.currentrow    = 1
    --
    dataset.lines         = dataset.lines or setmetatableindex("table")
    dataset.start         = dataset.start or setmetatableindex("table")
    --
    dataset.page          = 1
    --
    local distances = dataset.distances or setmetatableindex(function(t,k)
        return dataset.distance
    end)
    dataset.distances = distances
    --
    local widths = dataset.widths or setmetatableindex(function(t,k)
        return dataset.width
    end)
    dataset.widths = widths
    --
    local width = t.width
    if not width or width == 0 then
        local dl = 0
        local dr = 0
        for i=1,nofleft-1 do
            dl = dl + distances[i]
        end
        for i=1,nofright-1 do
            dr = dr + distances[nofleft+i]
        end
        local nl = nofleft
        local nr = nofright
        local wl = dataset.maxwidth
        local wr = wl
        for i=1,nofleft do
            local w = rawget(widths,i)
            if w then
                nl = nl - 1
                wl = wl - w
            end
        end
        for i=1,nofright do
            local w = rawget(widths,nofleft+i)
            if w then
                nr = nr - 1
                wr = wr - w
            end
        end
        dl = (wl - dl) / nl
        dr = (wr - dr) / nr
        if dl > dr then
            report("using %s page column width %p in columnset %a","right",dr,name)
            width = dr
        elseif dl < dr then
            report("using %s page column width %p in columnset %a","left",dl,name)
            width = dl
        else
            width = dl
        end
    end
 -- report("width %p, nleft %i, nright %i",width,nofleft,nofright)
    width         = round(width)
    dataset.width = width
    local spans   = { }
    dataset.spans = spans
    for i=1,nofleft do
        local s = { }
        local d = 0
        for j=1,nofleft-i+1 do
            d = d + width
            s[j] = round(d)
            d = d + distances[j]
        end
        spans[i]  = s
    end
    for i=1,nofright do
        local s = { }
        local d = 0
        for j=1,nofright-i+1 do
            d = d + width
            s[j] = round(d)
            d = d + distances[j]
        end
        spans[nofleft+i]  = s
    end
    --
    local spreads   = copy(spans)
    dataset.spreads = spreads
    local gap       = 2 * getdimen("backspace")
    for l=1,nofleft do
        local s = spreads[l]
        local n = #s
        local o = s[n] + gap
        for r=1,nofright do
            n = n + 1
            s[n] = s[r] + o
        end
    end
    --
    texsetdimen("d_page_grd_column_width",dataset.width)
    --
    setstate(dataset,true)
    --
    return dataset
end

local function check(dataset)
    local cells  = dataset.cells
    local page   = dataset.page
    local offset = odd(page) and dataset.nofleft or 0
    local start  = dataset.start
    local list   = rawget(start,page)
    if list then
        for c, n in next, list do
            local column = cells[offset + c]
            if column then
                for r=1,n do
                    column[r] = true
                end
            end
        end
        start[page] = nil
    end
    local lines = dataset.lines
    local list  = rawget(lines,page)
    local rows  = dataset.nofrows
    if list then
        for c, n in next, list do
            local column = cells[offset + c]
            if column then
                if n > 0 then
                    for r=n+1,rows do
                        column[r] = true
                    end
                elseif n < 0 then
                    for r=rows,rows+n+1,-1 do
                        column[r] = true
                    end
                end
            end
        end
        lines[page] = nil
    end
end

local function erase(dataset,all)
    local cells   = dataset.cells
    local nofrows = dataset.nofrows
    local first   = 1
    local last    = dataset.nofcolumns
    --
    if not all then
        first = dataset.firstcolumn or first
        last  = dataset.lastcolumn  or last
    end
    for c=first,last do
        local column = { }
        for r=1,nofrows do
            if column[r] then
                report("slot (%i,%i) is not empty",c,r)
            end
            column[r] = false -- not used
        end
        cells[c] = column
    end
end

function columnsets.reset(t)
    local dataset = columnsets.define(t)
    erase(dataset,true)
    check(dataset)
end

function columnsets.prepareflush(name)
    local dataset     = data[name]
    local cells       = dataset.cells
    local firstcolumn = dataset.firstcolumn
    local lastcolumn  = dataset.lastcolumn
    local nofrows     = dataset.nofrows
    local lineheight  = dataset.lineheight
    local linedepth   = dataset.linedepth
    local widths      = dataset.widths
    local height      = (lineheight+linedepth)*nofrows -- - linedepth
    --
    local columns     = { }
    dataset.columns   = columns
    --
    for c=firstcolumn,lastcolumn do
        local column = cells[c]
        for r=1,nofrows do
            local cell = column[r]
            if (cell == false) or (cell == true) then
                if trace_cells then
                    column[r] = new_trace_rule(65536*2,lineheight,linedepth)
                else
                    column[r] = new_empty_rule(0,lineheight,linedepth)
                end
            end
        end
        for r=1,nofrows-1 do
            setlink(column[r],column[r+1])
        end
        columns[c] = new_vlist(column[1],widths[c],height,0) -- linedepth
    end
    --
    texsetcount("c_page_grd_first_column",firstcolumn)
    texsetcount("c_page_grd_last_column",lastcolumn)
end

function columnsets.flushcolumn(name,column)
    local dataset = data[name]
    local columns = dataset.columns
    local packed  = columns[column]
    setbox("b_page_grd_column",packed)
    columns[column] = nil
end

function columnsets.finishflush(name)
    local dataset     = data[name]
    local cells       = dataset.cells
    local firstcolumn = dataset.firstcolumn
    local lastcolumn  = dataset.lastcolumn
    local nofrows     = dataset.nofrows
    for c=firstcolumn,lastcolumn do
        local column = { }
        for r=1,nofrows do
            column[r] = false -- not used
        end
        cells[c] = column
    end
    dataset.page = dataset.page + 1
    check(dataset)
    setstate(dataset)
end

function columnsets.block(t)
    local dataset    = data[t.name]
    local cells      = dataset.cells
    local nofcolumns = dataset.nofcolumns
    local nofrows    = dataset.nofrows
    --
    local c = t.c or 0
    local r = t.r or 0
    if c == 0 or r == 0 or c > nofcolumns or r > nofrows then
        return
    end
    local nc = t.nc or 0
    local nr = t.nr or 0
    if nc == 0 then
        return
    end
    if nr == 0 then
        return
    end
    local rr = r + nr - 1
    local cc = c + nc - 1
    if rr > nofrows then
        rr = nofrows
    end
    if cc > nofcolumns then
        cc = nofcolumns
    end
    for i=c,cc do
        local column = cells[i]
        for j=r,rr do
            column[j] = true
        end
    end
end

local function here(c,r,nr,nofcolumns,nofrows,cells,width,spans)
    local rr = r + nr - 1
    if rr > nofrows then
        return false
    end
    local cc = 0
    local wd = spans[c]
    local wc = 0
    local nc = 0
    for i=c,nofcolumns do
        nc = nc + 1
        wc = wd[nc]
        if not wc then
            break
        elseif wc >= width then
            cc = i
            break
        end
    end
    if cc == 0 or cc > nofcolumns then
     -- report("needed %p, no slot free at (%i,%i)",width,c,r)
        return false
    end
    for i=c,cc do
        local column = cells[i]
        for j=r,rr do
            if column[j] then
             -- report("width %p, needed %p, checking (%i,%i) x (%i,%i), %s",width,wc,c,r,nc,nr,"quit")
                return false
            end
        end
    end
 -- report("width %p, needed %p, checking (%i,%i) x (%i,%i), %s",width,wc,c,r,nc,nr,"match")
    return c, r, nc
end

-- we use c/r as range limiters

local methods = {
    [v_here] = here,
    [v_fixed] = here,
    tblr = function(c,r,nr,nofcolumns,nofrows,cells,width,spans)
        for j=r,nofrows-nr+1 do
            for i=c,nofcolumns do
                if not cells[i][j] then
                    local c, r, cc = here(i,j,nr,nofcolumns,nofrows,cells,width,spans)
                    if c then
                        return c, r, cc
                    end
                end
            end
        end
    end,
    lrtb = function(c,r,nr,nofcolumns,nofrows,cells,width,spans)
        for i=c,nofcolumns do
            for j=r,nofrows-nr+1 do
                if not cells[i][j] then
                    local c, r, cc = here(i,j,nr,nofcolumns,nofrows,cells,width,spans)
                    if c then
                        return c, r, cc
                    end
                end
            end
        end
    end,
    tbrl = function(c,r,nr,nofcolumns,nofrows,cells,width,spans)
        for j=r,nofrows-nr+1 do
            for i=nofcolumns,c,-1 do
                if not cells[i][j] then
                    local c, r, cc = here(i,j,nr,nofcolumns,nofrows,cells,width,spans)
                    if c then
                        return c, r, cc
                    end
                end
            end
        end
    end,
    rltb = function(c,r,nr,nofcolumns,nofrows,cells,width,spans)
        for i=nofcolumns,c,-1 do
            for j=r,nofrows-nr+1 do
                if not cells[i][j] then
                    local c, r, cc = here(i,j,nr,nofcolumns,nofrows,cells,width,spans)
                    if c then
                        return c, r, cc
                    end
                end
            end
        end
    end,
    btlr = function(c,r,nr,nofcolumns,nofrows,cells,width,spans)
     -- for j=nofrows-nr+1,1,-1 do
        for j=nofrows-nr+1-r+1,1,-1 do
            for i=c,nofcolumns do
                if not cells[i][j] then
                    local c, r, cc = here(i,j,nr,nofcolumns,nofrows,cells,width,spans)
                    if c then
                        return c, r, cc
                    end
                end
            end
        end
    end,
    lrbt = function(c,r,nr,nofcolumns,nofrows,cells,width,spans)
        for i=c,nofcolumns do
         -- for j=nofrows-nr+1,1,-1 do
            for j=nofrows-nr+1-r+1,1,-1 do
                if not cells[i][j] then
                    local c, r, cc = here(i,j,nr,nofcolumns,nofrows,cells,width,spans)
                    if c then
                        return c, r, cc
                    end
                end
            end
        end
    end,
    btrl = function(c,r,nr,nofcolumns,nofrows,cells,width,spans)
     -- for j=nofrows-nr+1,1,-1 do
        for j=nofrows-nr+1-r+1,1,-1 do
            for i=nofcolumns,c,-1 do
                if not cells[i][j] then
                    local c, r, cc = here(i,j,nr,nofcolumns,nofrows,cells,width,spans)
                    if c then
                        return c, r, cc
                    end
                end
            end
        end
    end,
    rlbt = function(c,r,nr,nofcolumns,nofrows,cells,width,spans)
        for i=nofcolumns,c,-1 do
         -- for j=nofrows-nr+1,1,-1 do
            for j=nofrows-nr+1-r+1,1,-1 do
                if not cells[i][j] then
                    local c, r, cc = here(i,j,nr,nofcolumns,nofrows,cells,width,spans)
                    if c then
                        return c, r, cc
                    end
                end
            end
        end
    end,
    fxtb = function(c,r,nr,nofcolumns,nofrows,cells,width,spans)
        for i=c,nofcolumns do
            for j=r,nofrows-nr+1 do
                if not cells[i][j] then
                    local c, r, cc = here(i,j,nr,nofcolumns,nofrows,cells,width,spans)
                    if c then
                        return c, r, cc
                    end
                end
                r = 1
            end
        end
    end,
    fxbt = function(c,r,nr,nofcolumns,nofrows,cells,width,spans)
        for i=c,nofcolumns do
            for j=nofrows-nr+1,r,-1 do
                if not cells[i][j] then
                    local c, r, cc = here(i,j,nr,nofcolumns,nofrows,cells,width,spans)
                    if c then
                        return c, r, cc
                    end
                end
            end
            r = 1
        end
    end,
    [v_top] = function(c,r,nr,nofcolumns,nofrows,cells,width,spans)
        for i=c,nofcolumns do
            for j=1,nofrows-nr+1 do
                if cells[i][j] then
                    break
                else
                    local c, r, cc = here(i,j,nr,nofcolumns,nofrows,cells,width,spans)
                    if c then
                        return c, r, cc
                    end
                end
            end
        end
    end,
    [v_bottom] = function(c,r,nr,nofcolumns,nofrows,cells,width,spans)
        for i=c,nofcolumns do
            for j=1,nofrows-nr+1 do
                if cells[i][j] then
                    break
                else
                    local c, r, cc = here(i,j,nr,nofcolumns,nofrows,cells,width,spans)
                    if c then
                        return c, r, cc
                    end
                end
            end
        end
    end,
}

local threshold = 50

function columnsets.check(t)
    local dataset    = data[t.name]
    local cells      = dataset.cells
    local nofcolumns = dataset.nofcolumns
    local nofrows    = dataset.nofrows
    local widths     = dataset.widths
    local lineheight = dataset.lineheight
    local linedepth  = dataset.linedepth
    local distances  = dataset.distances
    local spans      = dataset.spans
    --
    local method     = lower(t.method or "tblr")
    local boxwidth   = t.width  or 0
    local boxheight  = t.height or 0
    local boxnumber  = t.box
    local box        = boxnumber and getbox(boxnumber)
    --
    if boxwidth > 0 and boxheight > 0 then
        -- we're ok
    elseif box then
        local wd, ht, dp = getwhd(box)
        boxwidth  = wd
        boxheight = ht + dp
    else
        report("empty box")
        return
    end
    --
    local c = t.c or 0
    local r = t.r or 0
    if c == 0 then
        c = dataset.currentcolumn
    end
    if r == 0 then
        r = dataset.currentrow
    end
    if c == 0 or r == 0 or c > nofcolumns or r > nofrows then
        texsetcount("c_page_grd_reserved_state",5)
        return
    end
 -- report("checking width %p, height %p, depth %p, slot (%i,%i)",boxwidth,boxheight,boxdepth,c,r)
    local nr = ceil(boxheight/(lineheight+linedepth))
    --
    local action = methods[method]
    local cfound = false
    local rfound = false
    local lastcolumn = dataset.lastcolumn
 -- if t.option == v_wide then
 --     lastcolumn = nofcolumns
 --     spans = dataset.spreads
 -- end
    if action then
        cfound, rfound, nc = action(c,r,nr,lastcolumn,nofrows,cells,boxwidth-threshold,spans)
    end
    if not cfound and method ~= v_here then
        cfound, rfound, nc = here(c,r,nr,lastcolumn,nofrows,cells,boxwidth-threshold,spans)
    end
    if cfound then
        local ht = nr*(lineheight+linedepth)
        local wd = spans[cfound][nc]
        dataset.reserved_ht = ht
        dataset.reserved_wd = wd
        dataset.reserved_c  = cfound
        dataset.reserved_r  = rfound
        dataset.reserved_nc = nc
        dataset.reserved_nr = nr
        texsetcount("c_page_grd_reserved_state",0)
        texsetdimen("d_page_grd_reserved_height",ht)
        texsetdimen("d_page_grd_reserved_width",wd)
     -- report("using (%i,%i) x (%i,%i) @ (%p,%p)",cfound,rfound,nc,nr,wd,ht)
    else
        dataset.reserved_ht = false
        dataset.reserved_wd = false
        dataset.reserved_c  = false
        dataset.reserved_r  = false
        dataset.reserved_nc = false
        dataset.reserved_nr = false
        texsetcount("c_page_grd_reserved_state",4)
     -- texsetdimen("d_page_grd_reserved_height",0)
     -- texsetdimen("d_page_grd_reserved_width",0)
     -- report("no slot found")
    end
end

function columnsets.put(t)
    local dataset    = data[t.name]
    local cells      = dataset.cells
    local widths     = dataset.widths
    local lineheight = dataset.lineheight
    local linedepth  = dataset.linedepth
    local boxnumber  = t.box
    local box        = boxnumber and takebox(boxnumber)
    --
    local c = t.c or dataset.reserved_c
    local r = t.r or dataset.reserved_r
    if not c or not r then
     -- report("no reserved slot (%i,%i)",c,r)
        return
    end
    local lastc = c + dataset.reserved_nc - 1
    local lastr = r + dataset.reserved_nr - 1
    --
    for i=c,lastc do
        local column = cells[i]
        for j=r,lastr do
            column[j] = true
        end
    end
    cells[c][r] = box
    setwhd(box,widths[c],lineheight,linedepth)
    dataset.reserved_c  = false
    dataset.reserved_r  = false
    dataset.reserved_nc = false
    dataset.reserved_nr = false
    --
end

local function findgap(dataset)
    local cells         = dataset.cells
    local nofcolumns    = dataset.nofcolumns
    local nofrows       = dataset.nofrows
    local currentrow    = dataset.currentrow
    local currentcolumn = dataset.currentcolumn
    --
    local foundc = 0
    local foundr = 0
    local foundn = 0
    for c=currentcolumn,dataset.lastcolumn do
        local column = cells[c]
foundn = 0
        for r=currentrow,nofrows do
            if not column[r] then
                if foundc == 0 then
                    foundc = c
                    foundr = r
                end
                foundn = foundn + 1
            elseif foundn > 0 then
                return foundc, foundr, foundn
            end
        end
        if foundn > 0 then
            return foundc, foundr, foundn
        end
        currentrow = 1
    end
end

-- we can enforce grid snapping

-- local function checkroom(head,available,row)
--     if row == 1 then
--         while head do
--             local id = getid(head)
--             if id == glue_code then
--                 head = getnext(head)
--             else
--                 break
--             end
--         end
--     end
--     local used = 0
--     local line = false
--     while head do
--         local id = getid(head)
--         if id == hlist_code or id == vlist_code or id == rule_code then -- <= rule_code
--             local wd, ht, dp = getwhd(head)
--             used = used + ht + dp
--             line = true
--         elseif id == glue_code then
--             if line then
--                 break
--             end
--             used = used + getwidth(head)
--         elseif id == kern_code then
--             used = used +  getkern(head)
--         elseif id == penalty_code then
--         end
--         if used > available then
--             break
--         end
--         head = getnext(head)
--     end
--     return line, used
-- end

local function checkroom(head,available,row)
    if row == 1 then
        while head do
            local id = getid(head)
            if id == glue_code then
                head = getnext(head)
            else
                break
            end
        end
    end
    local used = 0
    local line = false
    while head do
        local id = getid(head)
        if id == hlist_code or id == vlist_code or id == rule_code then -- <= rule_code
            local wd, ht, dp = getwhd(head)
            used = used + ht + dp
            line = true
            if used > available then
                break
            end
        elseif id == glue_code then
            if line then
                break
            end
            used = used + getwidth(head)
            if used > available then
                break
            end
        elseif id == kern_code then
            used = used + getkern(head)
            if used > available then
                break
            end
        elseif id == penalty_code then
            -- not good enough ... we need to look bakck too
            if getpenalty(head) >= 10000 then
                line = false
            else
                break
            end
        end
        head = getnext(head)
    end
    return line, used
end

-- we could preroll on a cheap copy .. in fact, a split loop normally works on
-- a copy ... then we could also stepsise make the height smaller .. slow but nice

-- local function findslice(dataset,head,available,column,row)
--     local used       = 0
--     local first      = nil
--     local last       = nil
--     local line       = false
--     local lineheight = dataset.lineheight
--     local linedepth  = dataset.linedepth
--     if row == 1 then
--         while head do
--             local id = getid(head)
--             if id == glue_code then
--                 head = removenode(head,head,true)
--             else
--                 break
--             end
--         end
--     end
--     while head do
--         -- no direction yet, if so use backend code
--         local id = getid(head)
--         local hd = 0
--         if id == hlist_code or id == vlist_code or id == rule_code then -- <= rule_code
--             local wd, ht, dp = getwhd(head)
--             hd = ht + dp
--         elseif id == glue_code then
--             hd = getwidth(head)
--         elseif id == kern_code then
--             hd = getkern(head)
--         elseif id == penalty_code then
--         end
--         if used + hd > available then
--             if first then
--                 setnext(last)
--                 setprev(head)
--                 return used, first, head
--             else
--                 return 0
--             end
--         else
--             if not first then
--                 first = head
--             end
--             used = used + hd
--             last = head
--             head = getnext(head)
--         end
--     end
--     return used, first
-- end

--  todo
--
--                 first = takelist(done)
--                 head = takelist(rest)
--                 local tail = nuts.tail(first)
--                 if false then
--                     local disc = tex.lists.split_discards_head
--                     if disc then
--                         disc = tonut(disc)
--                         setlink(tail,disc)
--                         tail = nuts.tail(disc)
--                         tex.lists.split_discards_head = nil
--                     end
--                 end
--                 setlink(tail,head)

-- We work on a copy because we need to keep properties. We can make faster copies
-- by only doing a one-level deep copy.

local function findslice(dataset,head,available,column,row)
    local first      = nil
    local lineheight = dataset.lineheight
    local linedepth  = dataset.linedepth
    local linetotal  = lineheight + linedepth
    local slack      = 65536 -- 1pt
    local copy       = copylist(head)
    local attempts   = 0
    local usedsize   = available
    while true do
        attempts = attempts + 1
        texsetbox("scratchbox",tonode(new_vlist(copy)))
        local done = splitbox("scratchbox",usedsize,"additional")
        local used = getheight(done)
        local rest = takebox("scratchbox")
        if used > (usedsize+slack) then
            if trace_details then
                report("at (%i,%i) available %p, used %p, overflow %p",column,row,usedsize,used,used-usedsize)
            end
            -- flush copy
            flushlist(takelist(done))
            flushlist(takelist(rest))
            -- check it we can try again
            usedsize = usedsize - linetotal
            if usedsize > linetotal then
                copy = copylist(head)
            else
                return 0, nil, head
            end
        else
            -- flush copied box
            flushlist(takelist(done))
            flushlist(takelist(rest))
            -- deal with real data
            texsetbox("scratchbox",tonode(new_vlist(head)))
            done  = splitbox("scratchbox",usedsize,"additional")
            rest  = takebox("scratchbox")
            used  = getheight(done)
            if attempts > 1 then
                used = available
            end
            first = takelist(done)
            head  = takelist(rest)
            -- return result
            return used, first, head
        end
    end
end

local nofcolumngaps = 0

function columnsets.add(name,box)
    local dataset       = data[name]
    local cells         = dataset.cells
    local nofcolumns    = dataset.nofcolumns
    local nofrows       = dataset.nofrows
    local currentrow    = dataset.currentrow
    local currentcolumn = dataset.currentcolumn
    local lineheight    = dataset.lineheight
    local linedepth     = dataset.linedepth
    local widths        = dataset.widths
    --
    local b = getbox(box)
    local l = getlist(b)
-- dataset.rest = l
    if l then
        setlist(b,nil)
        local hd = lineheight + linedepth
        while l do
            local foundc, foundr, foundn = findgap(dataset)
            if foundc then
                local available = foundn * hd
                local used, first, last = findslice(dataset,l,available,foundc,foundr)
                if first then
                    local v
                    if used == available or (foundr+foundn > nofrows) then
                        v = vpack(first,available,"exactly")
                    else
                        v = new_vlist(first)
                    end
                    nofcolumngaps = nofcolumngaps + 1
                    -- getmetatable(v).columngap = nofcolumngaps
                    properties[v] = { columngap = nofcolumngaps }
                 -- report("setting gap %a at (%i,%i)",nofcolumngaps,foundc,foundr)
                    setwhd(v,widths[currentcolumn],lineheight,linedepth)
                    local column = cells[foundc]
                    --
                    column[foundr] = v
                    used = used - hd
                    if used > 0 then
                        for r=foundr+1,foundr+foundn-1 do
                            used = used - hd
                            foundr = foundr + 1
                            column[r] = true
                            if used <= 0 then
                                break
                            end
                        end
                    end
                    currentcolumn = foundc
                    currentrow    = foundr
                    dataset.currentcolumn = currentcolumn
                    dataset.currentrow    = currentrow
                    l = last
                    dataset.rest = l
                else
                    local column = cells[foundc]
                    for i=foundr,foundr+foundn-1 do
                        column[i] = true
                    end
                    l = last
                end
            else
                dataset.rest = l
                return -- save and flush
            end
        end
    end
end

do

    -- A split approach is more efficient than a context(followup) inside
    -- followup itself as we need less (internal) housekeeping.

    local followup = nil
    local splitter = lpeg.splitter("*",tonumber)

    columnsets["noto"] = function(t)
        return followup()
    end

    columnsets["goto"] = function(name,target)
        local dataset    = data[name]
        local nofcolumns = dataset.nofcolumns
        if target == v_yes or target == "" then
            local currentcolumn = dataset.currentcolumn
            followup = function()
                context(dataset.currentcolumn == currentcolumn and 1 or 0)
            end
            return followup()
        end
        if target == v_first then
            if dataset.currentcolumn > 1  then
                target = v_page
            else
                return context(0)
            end
        end
        if target == v_page then
            if dataset.currentcolumn == 1 and dataset.currentrow == 1 then
                return context(0)
            else
                local currentpage = dataset.page
                followup = function()
                    context(dataset.page == currentpage and 1 or 0)
                end
                return followup()
            end
        end
        if target == v_last then
            target = dataset.nofcolumns
            if dataset.currentcolumn ~= target then
                followup = function()
                    context(dataset.currentcolumn ~= target and 1 or 0)
                end
                return followup()
            end
            return
        end
        local targetpage = tonumber(target)
        if targetpage then
            followup = function()
                context(dataset.currentcolumn ~= targetpage and 1 or 0)
            end
            return followup()
        end
        local targetcolumn, targetrow = lpeg.match(splitter,target)
        if targetcolumn and targetrow then
            if dataset.currentcolumn ~= targetcolumn and dataset.currentrow ~= targetrow then
                followup = function()
                    if dataset.currentcolumn ~= targetcolumn then
                        context(1)
                        return
                    end
                    if dataset.currentcolumn == targetcolumn then
                        context(dataset.currentrow ~= targetrow and 1 or 0)
                    else
                        context(0)
                    end
                end
                return followup()
            end
        end
    end

end

function columnsets.currentcolumn(name)
    local dataset = data[name]
    context(dataset.currentcolumn)
end

function columnsets.flushrest(name,box)
    local dataset = data[name]
    local rest    = dataset.rest
    if rest then
        dataset.rest = nil
        setbox("global",box,new_vlist(rest))
    end
end

function columnsets.setvsize(name)
    local dataset = data[name]
    local c, r, n = findgap(dataset)
    if n then
        dataset.currentcolumn = c
        dataset.currentrow    = r
    else
        dataset.currentcolumn = 1
        dataset.currentrow    = 1
        n = 0
    end
    local gap = n*(dataset.lineheight+dataset.linedepth)
    texsetdimen("d_page_grd_gap_height",gap)
    -- can be integrated
 -- report("state %a, n %a, column %a, row %a",dataset.state,n,dataset.currentcolumn,dataset.currentrow)
end

function columnsets.sethsize(name)
    local dataset = data[name]
    texsetdimen("d_page_grd_column_width",dataset.widths[dataset.currentcolumn])
end

function columnsets.sethspan(name,span)
    -- no checking if there is really space, so we assume it can be
    -- placed which makes spans a very explicit feature
    local dataset   = data[name]
    local column    = dataset.currentcolumn
    local available = dataset.lastcolumn - column + 1
    if span > available then
        span = available
    end
    local width = dataset.spans[column][span]
    texsetdimen("d_page_grd_span_width",width)
end

function columnsets.setlines(t)
    local dataset = data[t.name]
    dataset.lines[t.page][t.column] = t.value
end

function columnsets.setstart(t)
    local dataset = data[t.name]
    dataset.start[t.page][t.column] = t.value
end

function columnsets.setproperties(t)
    local dataset = data[t.name]
    local column  = t.column
    dataset.distances[column] = t.distance
    dataset.widths[column] = t.width
end

local areas = { }

function columnsets.registerarea(t)
    -- maybe metatable with values
    areas[#areas+1] = t
end

-- state : repeat | start

local ctx_page_grd_set_area = context.protected.page_grd_set_area

function columnsets.flushareas(name)
    local nofareas = #areas
    if nofareas == 0 then
        return
    end
    local dataset = data[name]
    local page    = dataset.page
    if odd(page) then
     -- report("checking %i areas",#areas)
        local kept = { }
        for i=1,nofareas do
            local area = areas[i]
         -- local page = area.page -- maybe use page counter in columnset
         -- local type = area.type
            local okay = false
            --
            local nofcolumns = area.nc
            local nofrows    = area.nr
            local column     = area.c
            local row        = area.r
            columnsets.block {
                name = name,
                c    = column,
                r    = row,
                nc   = nofcolumns,
                nr   = nofrows,
            }
            local left     = 0
            local start    = dataset.nofleft + 1
            local overflow = (column + nofcolumns - 1) - dataset.nofleft
            local height   = nofrows * (dataset.lineheight + dataset.linedepth)
            local width    = dataset.spreads[column][nofcolumns]
         -- report("span, width %p, overflow %i",width,overflow)
            if overflow > 0 then
                local used = nofcolumns - overflow
                left  = dataset.spreads[column][used] + getdimen("backspace")
            end
            ctx_page_grd_set_area(name,area.name,column,row,width,height,start,left) -- or via counters / dimens
            if area.state ~= v_repeat then
                area = nil
            end
            if area then
                kept[#kept+1] = area
            end
        end
        areas = kept
    end
end

function columnsets.setarea(t)
    local dataset = data[t.name]
    local cells   = dataset.cells
    local box     = takebox(t.box)
    local column  = t.c
    local row     = t.r
    if column and row then
        setwhd(box,dataset.widths[column],dataset.lineheight,dataset.linedepth)
        cells[column][row] = box
    end
end

-- The interface.

interfaces.implement {
    name      = "definecolumnset",
    actions   = columnsets.define,
    arguments = { {
        { "name", "string" },
    } }
}

interfaces.implement {
    name      = "resetcolumnset",
    actions   = columnsets.reset,
    arguments = { {
        { "name", "string" },
        { "nofleft", "integer" },
        { "nofright", "integer" },
        { "nofrows", "integer" },
        { "lineheight", "dimension" },
        { "linedepth", "dimension" },
        { "width", "dimension" },
        { "distance", "dimension" },
        { "maxwidth", "dimension" },
    } }
}

interfaces.implement {
    name      = "preparecolumnsetflush",
    actions   = columnsets.prepareflush,
    arguments = "string",
}

interfaces.implement {
    name      = "finishcolumnsetflush",
    actions   = columnsets.finishflush,
    arguments = "string",
}

interfaces.implement {
    name      = "flushcolumnsetcolumn",
    actions   = columnsets.flushcolumn,
    arguments = { "string" ,"integer" },
}

interfaces.implement {
    name      = "setvsizecolumnset",
    actions   = columnsets.setvsize,
    arguments = "string",
}

interfaces.implement {
    name      = "sethsizecolumnset",
    actions   = columnsets.sethsize,
    arguments = "string",
}

interfaces.implement {
    name      = "sethsizecolumnspan",
    actions   = columnsets.sethspan,
    arguments = { "string" ,"integer" },
}

interfaces.implement {
    name      = "flushcolumnsetrest",
    actions   = columnsets.flushrest,
    arguments = { "string", "integer" },
}

interfaces.implement {
    name      = "blockcolumnset",
    actions   = columnsets.block,
    arguments = { {
        { "name", "string" },
        { "c", "integer" },
        { "r", "integer" },
        { "nc", "integer" },
        { "nr", "integer" },
        { "method", "string" },
        { "box", "integer" },
    } }
}

interfaces.implement {
    name      = "checkcolumnset",
    actions   = columnsets.check,
    arguments = { {
        { "name", "string" },
        { "method", "string" },
        { "c", "integer" },
        { "r", "integer" },
        { "method", "string" },
        { "box", "integer" },
        { "width", "dimension" },
        { "height", "dimension" },
        { "option", "string" },
    } }
}

interfaces.implement {
    name      = "putincolumnset",
    actions   = columnsets.put,
    arguments = { {
        { "name", "string" },
        { "c", "integer" },
        { "r", "integer" },
        { "method", "string" },
        { "box", "integer" },
    } }
}

interfaces.implement {
    name    = "addtocolumnset",
    actions = columnsets.add,
    arguments = { "string", "integer" },
}

interfaces.implement {
    name    = "setcolumnsetlines",
    actions = columnsets.setlines,
    arguments = { {
        { "name", "string" },
        { "page", "integer" },
        { "column", "integer" },
        { "value", "integer" },
    } }
}

interfaces.implement {
    name    = "setcolumnsetstart",
    actions = columnsets.setstart,
    arguments = { {
        { "name", "string" },
        { "page", "integer" },
        { "column", "integer" },
        { "value", "integer" },
    } }
}

interfaces.implement {
    name    = "setcolumnsetproperties",
    actions = columnsets.setproperties,
    arguments = { {
        { "name", "string" },
        { "column", "integer" },
        { "distance", "dimension" },
        { "width", "dimension" },
    } }
}

interfaces.implement {
    name      = "registercolumnsetarea",
    actions   = columnsets.registerarea,
    arguments = { {
        { "name", "string" },
        { "type", "string" },
        { "page", "integer" },
        { "state", "string" },
        { "c", "integer" },
        { "r", "integer" },
        { "nc", "integer" },
        { "nr", "integer" },
    } }
}

interfaces.implement {
    name      = "flushcolumnsetareas",
    actions   = columnsets.flushareas,
    arguments = "string",
}

interfaces.implement {
    name      = "setcolumnsetarea",
    actions   = columnsets.setarea,
    arguments = { {
        { "name", "string" },
        { "c", "integer" },
        { "r", "integer" },
        { "method", "string" },
        { "box", "integer" },
    } }
}

interfaces.implement {
    name      = "columnsetgoto",
    actions   = columnsets["goto"],
    arguments = "2 strings",
}

interfaces.implement {
    name      = "columnsetnoto",
    actions   = columnsets["noto"],
}

interfaces.implement {
    name      = "columnsetcurrentcolumn",
    actions   = columnsets.currentcolumn,
    arguments = "string",
}
