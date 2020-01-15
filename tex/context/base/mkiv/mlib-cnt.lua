if not modules then modules = { } end modules ['mlib-cnt'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- The only useful reference that I could find about this topic is in wikipedia:
--
--     https://en.wikipedia.org/wiki/Marching_squares
--
-- I derived the edge code from:
--
--     https://physiology.arizona.edu/people/secomb/contours
--
-- and also here:
--
--     https://github.com/secomb/GreensV4
--
-- which has the banner:
--
--     TWS, November 1989. Converted to C September 2007. Revised February 2009.
--
-- and has a liberal licence. I optimized the code so that it runs a bit faster in Lua and
-- there's probably more room for optimization (I tried several variants). For instance I
-- don't use that many tables because access is costly. We don't have a compiler that does
-- some optimizing (even then the c code can probably be made more efficient).
--
-- We often have the same node so it's cheaper to reuse the wsp tables and reconstruct
-- the point in the path then to alias the original point. We can be more clever:
-- straighten, but it's more work so maybe I will do that later; for now I only added
-- a test for equality. There are some experiments in this file too and not all might
-- work. It's a playground for me.
--
-- The code is meant for metafun so it is not general purpose. The bitmap variant is
-- relatively fast and bitmaps compress well. When all is settled I might make a couple
-- of helpers in C for this purpose but not now.
--
-- I removed optimization code (more aggressive flattening and such because it didn't really
-- pay off now that we use combined paths with just line segments. I also moved some other
-- code to a experimental copy. So we now only have the bare helpers needed here.

-- Todo: look into zero case (lavel 1) for shapes ... omiting the background calculation
-- speeds up quite a bit.

local next, type, tostring = next, type, tostring
local round, abs, min, max, floor = math.round, math.abs, math.min, math.max, math.floor
local concat, move = table.concat, table.move

local bor = bit32.bor -- it's really time to ditch support for luajit

local starttiming       = statistics.starttiming
local stoptiming        = statistics.stoptiming
local elapsedtime       = statistics.elapsedtime

local formatters        = string.formatters
local setmetatableindex = table.setmetatableindex
local sortedkeys        = table.sortedkeys
local sequenced         = table.sequenced

local metapost          = metapost or { }
local mp                = mp or { }

local getparameterset   = metapost.getparameterset

local mpflush           = mp.flush
local mpcolor           = mp.color
local mpstring          = mp.string
local mpdraw            = mp.draw
local mpfill            = mp.fill
local mpflatten         = mp.flatten

local report            = logs.reporter("mfun contour")

local version           = 0.007

-- we iterate using integers so that we get a better behaviour at zero

local f_function_n = formatters [ [[
    local math  = math
    local round = math.round
    %s
    return function(data,nx,ny,nxmin,nxmax,xstep,nymin,nymax,ystep)
        local sx = nxmin
        for mx=1,nx do
            local dx = data[mx]
            local x  = sx * xstep
            local sy = nymin
            for my=1,ny do
                local y  = sy * ystep
                dx[my] = %s
                sy = sy + 1
            end
            sx = sx + 1
        end
        return 0
    end
]] ]

local f_function_y = formatters [ [[
    local math  = math
    local round = math.round
    local nan   = NaN
    local inf   = math.huge
    %s
    return function(data,nx,ny,nxmin,nxmax,xstep,nymin,nymax,ystep,dnan,dinf,report)
        local sx = nxmin
        local er = 0
        for mx=nxmin,nxmax do
            local dx = data[mx]
            local x  = sx * xstep
            local sy = nymin
            for my=nymin,nymax do
                local y = sy * ystep
                local n = %s
                if n == nan then
                    er = er + 1
                    if er < 10 then
                        report("nan at (%s,%s)",x,y)
                    end
                    n = dnan
                elseif n == inf then
                    er = er + 1
                    if er < 10 then
                        report("inf at (%s,%s)",x,y)
                    end
                    n = dinf
                end
                dx[my] = n
                sy = sy + 1
            end
            sx = sx + 1
        end
        return er
    end
]] ]

local f_color = formatters [ [[
    local math = math
    local min  = math.min
    local max  = math.max
    local n    = %s
    local minz = %s
    local maxz = %s

    local color_value = 0
    local color_step  = mp.lmt_color_functions.step
    local color_shade = mp.lmt_color_functions.shade

    local function step(...)
        return color_step(color_value,n,...)
    end
    local function shade(...)
        return color_shade(color_value,n,...)
    end
    local function lin(l)
        return l/n
    end
    %s
    return function(l)
        color_value = l
        return %s
    end
]] ]

local inbetween = attributes and attributes.colors.helpers.inbetween

mp.lmt_color_functions = {
    step = function(l,n,r,g,b,s)
        if not s then
            s = 1
        end
        local f = l / n
        local r = s * 1.5 - 4 * abs(f-r)
        local g = s * 1.5 - 4 * abs(f-g)
        local b = s * 1.5 - 4 * abs(f-b)
        return min(max(r,0),1), min(max(g,0),1), min(max(b,0),1)
    end,
    shade = function(l,n,one,two)
        local f = l / n
        local r = inbetween(one,two,1,f)
        local g = inbetween(one,two,2,f)
        local b = inbetween(one,two,3,f)
        return min(max(r,0),1), min(max(g,0),1), min(max(b,0),1)
    end,
}

local f_box = formatters [ [[draw rawtexbox("contour",%s) xysized (%s,%s) ;]] ]

local n_box = 0

-- todo: remove old one, so we need to store old hashes

local nofcontours = 0

-- We don't want cosmetics like axis and labels to trigger a  calculation,
-- especially a slow one.

local hashfields = {
    "xmin", "xmax", "xstep", "ymin", "ymax", "ystep",
    "levels", "colors", "level", "preamble", "function", "functions", "color", "values",
    "background", "foreground", "linewidth", "backgroundcolor", "linecolor",
}

local function prepare(p)
    local h = { }
    for i=1,#hashfields do
        local f = hashfields[i]
        h[f] = p[f]
    end
    local hash = md5.HEX(sequenced(h))
    local name = formatters["%s-m-c-%03i.lua"](tex.jobname,nofcontours)
    return name, hash
end

local function getcache(p)
    local cache = p.cache
    if cache then
        local name, hash = prepare(p)
        local data = table.load(name)
        if data and data.hash == hash and data.version == version then
            p.result = data
            return true
        else
            return false, hash, name
        end
    end
    return false, nil, nil
end

local function setcache(p)
    local result = p.result
    local name   = result.name
    if name then
        if result.bitmap then
            result.bitmap = nil
        else
            result.data = nil
        end
        result.color  = nil
        result.action = nil
        result.cached = nil
        io.savedata(name, table.fastserialize(result))
    else
        os.remove((prepare(p)))
    end
end

function mp.lmt_contours_start()

    starttiming("lmt_contours")

    nofcontours = nofcontours + 1

    local p = getparameterset()

    local xmin    = p.xmin
    local xmax    = p.xmax
    local ymin    = p.ymin
    local ymax    = p.ymax
    local xstep   = p.xstep
    local ystep   = p.ystep
    local levels  = p.levels
    local colors  = p.colors
    local nx      = 0
    local ny      = 0
    local means   = setmetatableindex("number")
    local values  = setmetatableindex("number")
    local data    = setmetatableindex("table")
    local minmean = false
    local maxmean = false

    local cached, hash, name = getcache(p)

    local function setcolors(preamble,levels,minz,maxz,color,nofvalues)
        if colors then
            local function f(k)
                return #colors[1] == 1 and 0 or { 0, 0, 0 }
            end
            setmetatableindex(colors, function(t,k)
                local v = f(k)
                t[k] = v
                return v
            end)
            local c = { }
            local n = 1
            for i=1,nofvalues do
                c[i] = colors[n]
                n = n + 1
            end
            return c, f
        else
            local tcolor = f_color(levels,minz,maxz,preamble,color)
            local colors = { }
            local fcolor = load(tcolor)
            if type(fcolor) ~= "function" then
                report("error in color function, case %i: %s",1,color)
                fcolor = false
            else
                fcolor = fcolor()
                if type(fcolor) ~= "function" then
                    report("error in color function, case %i: %s",2,color)
                    fcolor = false
                end
            end
            if not fcolor then
                local color_step  = mp.lmt_color_functions.step
                fcolor = function(l)
                    return color_step(l,levels,0.25,0.50,0.75)
                end
            end
            for i=1,nofvalues do
                colors[i] = { fcolor(i) }
            end
            if attributes.colors.model == "cmyk" then
                for i=1,#colors do
                    local c = colors[i]
                    colors[i] = { 1 - c[1], 1 - c[2], 1 - c[3], 0 }
                end
            end
            return colors, fcolor
        end
    end

    if cached then
        local result = p.result
        local colors, color = setcolors(
            p.preamble,
            p.levels,
            result.minz,
            result.maxz,
            p.color,
            result.nofvalues
        )
        result.color  = color
        result.colors = colors
        result.cached = true
        return
    end

    local functioncode  = p["function"]
    local functionrange = p.range
    local functionlist  = functionrange and p.functions
    local preamble      = p.preamble

    if xstep == 0 then xstep = (xmax - xmin)/100 end
    if ystep == 0 then ystep = (ymax - ymin)/100 end

    local nxmin = round(xmin/xstep)
    local nxmax = round(xmax/xstep)
    local nymin = round(ymin/ystep)
    local nymax = round(ymax/ystep)
    local nx    = nxmax - nxmin + 1
    local ny    = nymax - nymin + 1

    local function executed(data,code)
        local fcode = p.check and f_function_y or f_function_n
        fcode = fcode(preamble,code)
        fcode = load(fcode)
        if type(fcode) == "function" then
            fcode = fcode()
        end
        if type(fcode) == "function" then
            local er = fcode(
                data, nx, ny,
                nxmin, nxmax, xstep,
                nymin, nymax, ystep,
                p.defaultnan, p.defaultinf, report
            )
            if er > 0 then
                report("%i errors in: %s",er,code)
            end
            return true
        else
            return false -- fatal error
        end
    end

 -- for i=1,nx do
 --     data[i] = lua.newtable(ny,0)
 -- end

    if functionlist then

        local datalist = { }
        local minr     = functionrange[1]
        local maxr     = functionrange[2] or minr
        local size     = #functionlist

        for l=1,size do

            local func = setmetatableindex("table")
            if not executed(func,functionlist[l]) then
                report("error in executing function %i from functionlist",l)
                return
            end

            local bit = l -- + 1

            if l == 1 then
                for i=1,nx do
                    local di = data[i]
                    local fi = func[i]
                    for j=1,ny do
                        local f = fi[j]
                        if f >= minr and f <= maxr then
                            di[j] = bit
                        else
                            di[j] = 0
                        end
                    end
                end
            else
                for i=1,nx do
                    local di = data[i]
                    local fi = func[i]
                    for j=1,ny do
                        local f = fi[j]
                        if f >= minr and f <= maxr then
                            di[j] = bor(di[j],bit)
                        end
                    end
                end
            end

        end

        -- we can simplify the value mess below

    elseif functioncode then

        if not executed(data,functioncode) then
            report("error in executing function")
            return -- fatal error
        end

    else

        report("no valid function(s)")
        return -- fatal error

    end

    minz = data[1][1]
    maxz = minz

    for i=1,nx do
        local d = data[i]
        for j=1,ny do
            local v = d[j]
            if v < minz then
                minz = v
            elseif v > maxz then
                maxz = v
            end
        end
    end

    if functionlist then

        for i=minz,maxz do
            values[i] = i
        end

        levels = maxz

        minmean = minz
        maxmean = maxz

    else

        local snap = (maxz - minz + 1) / levels

        for i=1,nx do
            local d = data[i]
            for j=1,ny do
                local dj = d[j]
                local v  = round((dj - minz) / snap)
                values[v] = values[v] + 1
                means [v] = means [v] + dj
                d[j] = v
            end
        end

        local list  = sortedkeys(values)
        local count = values
        local remap = { }

        values = { }

        for i=1,#list do
            local v = list[i]
            local m = means[v] / count[v]
            remap [v] = i
            values[i] = m
            if not minmean then
                minmean = m
                maxmean = m
            elseif m < minmean then
                minmean = m
            elseif m > maxmean then
                maxmean = m
            end
        end

        for i=1,nx do
            local d = data[i]
            for j=1,ny do
                d[j] = remap[d[j]]
            end
        end

    end

    -- due to rounding we have values + 1 so we can have a floor, ceil, round
    -- option as well as levels -1

    local nofvalues = #values

    local colors = setcolors(
        p.preamble,levels,minz,maxz,p.color,nofvalues
    )

    p.result = {
        version   = version,
        values    = values,
        nofvalues = nofvalues,
        minz      = minz,
        maxz      = maxz,
        minmean   = minmean,
        maxmean   = maxmean,
        data      = data,
        color     = color,
        nx        = nx,
        ny        = ny,
        colors    = colors,
        name      = name,
        hash      = hash,
        islist    = functionlist and true or false,
    }

    report("index %i, nx %i, ny %i, levels %i", nofcontours, nx, ny, nofvalues)
end

function mp.lmt_contours_stop()
    local p = getparameterset()
    local e = stoptiming("lmt_contours")
    setcache(p)
    p.result = nil
    local f = p["function"]
    local l = p.functions
    report("index %i, %0.3f seconds for: %s",
        nofcontours, e, "[ " .. concat(l or { f } ," ] [ ") .. " ]"
    )
end

function mp.lmt_contours_bitmap_set()
    local p          = getparameterset()
    local result     = p.result

    local values     = result.values
    local nofvalues  = result.nofvalues
    local rawdata    = result.data
    local nx         = result.nx
    local ny         = result.ny
    local colors     = result.colors
    local depth      = #colors[1] -- == 3 and "rgb" or "gray"

    -- i need to figure out this offset of + 1

    local bitmap    = graphics.bitmaps.new(
        nx, ny,
        (depth == 3 and "rgb") or (depth == 4 and "cmyk") or "gray",
        1, false, true
    )

    local palette   = bitmap.index or { } -- has to start at 0
    local data      = bitmap.data
    local p         = 0

    if depth == 3 or depth == 4 then
        for i=1,nofvalues do
            local c = colors[i]
            local r = round((c[1] or 0) * 255)
            local g = round((c[2] or 0) * 255)
            local b = round((c[3] or 0) * 255)
            local k = depth == 4 and round((c[4] or 0) * 255) or nil
            palette[p] = {
                (r > 255 and 255) or (r < 0 and 0) or r,
                (g > 255 and 255) or (g < 0 and 0) or g,
                (b > 255 and 255) or (b < 0 and 0) or b,
                k
            }
            p = p + 1
        end
    else
        for i=1,nofvalues do
            local s = colors[i][1]
            local s = round((s or 0) * 255)
            palette[p] = (
                (s > 255 and 255) or (s < 0 and 0) or s
            )
            p = p + 1
        end
    end

    -- As (1,1) is the left top corner so we need to flip of we start in
    -- the left bottom (we cannot loop reverse because we want a properly
    -- indexed table.

    local k = 0
    for y=ny,1,-1 do
        k = k + 1
        local d = data[k]
        for x=1,nx do
            d[x] = rawdata[x][y] - 1
        end
    end

    result.bitmap = bitmap
end

function mp.lmt_contours_bitmap_get()
    local p      = getparameterset()
    local result = p.result
    local bitmap = result.bitmap
    local box    = nodes.hpack(graphics.bitmaps.flush(bitmap))
    n_box = n_box + 1
    nodes.boxes.savenode("contour",tostring(n_box),box)
    return f_box(n_box,bitmap.xsize,bitmap.ysize)
end

function mp.lmt_contours_cleanup()
    nodes.boxes.reset("contour")
    n_box = 0
end

function mp.lmt_contours_edge_set()
    local p         = getparameterset()
    local result    = p.result

    if result.cached then return end

    local values    = result.values
    local nofvalues = result.nofvalues
    local data      = result.data
    local nx        = result.nx
    local ny        = result.ny

    local xmin      = p.xmin
    local xmax      = p.xmax
    local ymin      = p.ymin
    local ymax      = p.ymax
    local xstep     = p.xstep
    local ystep     = p.ystep

    local wsp       = { }
    local edges     = { }

    for value=1,nofvalues do

        local iwsp = 0
        local di   = data[1]
        local dc
        local edge = { }
        local e    = 0
        -- the next loop is fast
        for i=1,nx do
            local di1 = data[i+1]
            local dij = di[1]
            local d   = dij - value
            local dij1
            for j=1,ny do
                if j < ny then
                    dij1 = di[j+1]
                    dc = dij1 - value
                    if (d >= 0 and dc < 0) or (d < 0 and dc >= 0) then
                        iwsp = iwsp + 1
                        local y = (d * (j+1) - dc * j) / (d - dc)
                        if i == 1 then
                            wsp[iwsp] = { i, y, 0, (i + (j-1)*nx) }
                        elseif i == nx then
                            wsp[iwsp] = { i, y, (i - 1 + (j-1)*nx), 0 }
                        else
                            local jx = (i + (j-1)*nx)
                            wsp[iwsp] = { i, y, jx - 1, jx }
                        end
                    end
                end
                if i < nx then
                    local dc = di1[j] - value
                    if (d >= 0 and dc < 0) or (d < 0 and dc >= 0) then
                        iwsp = iwsp + 1
                        local x = (d * (i+1) - dc * i) / (d - dc)
                        if j == 1 then
                            wsp[iwsp] = { x, j, 0, (i + (j-1)*nx) }
                        elseif j == ny then
                            wsp[iwsp] = { x, j, (i + (j-2)*nx), 0 }
                        else
                            local jx = i + (j-1)*nx
                            wsp[iwsp] = { x, j, jx - nx, jx }
                        end
                    end
                end
                dij = dij1
                d   = dc
            end
            di = di1
        end
        -- the next loop takes time
        for i=1,iwsp do
            local wspi = wsp[i]
            for isq=3,4 do
                local nsq = wspi[isq]
                if nsq ~= 0 then
                    local px = wspi[1]
                    local py = wspi[2]
                    local p  = { px, py }
                    local pn = 2
                    wspi[isq] = 0
                    while true do
                        for ii=1,iwsp do
                            local w = wsp[ii]
                            local n1 = w[3]
                            local n2 = w[4]
                            if n1 == nsq then
                                local x = w[1]
                                local y = w[2]
                                if x ~= px or y ~= py then
                                    pn    = pn + 1
                                    p[pn] = x
                                    pn    = pn + 1
                                    p[pn] = y
                                    px    = x
                                    py    = y
                                end
                                nsq   = n2
                                w[3]  = 0
                                w[4]  = 0
                                if nsq == 0 then
                                    if pn == 1 then
                                        pn    = pn + 1
                                        p[pn] = w
                                    end
                                    goto flush
                                end
                            elseif n2 == nsq then
                                local x = w[1]
                                local y = w[2]
                                if x ~= px or y ~= py then
                                    pn    = pn + 1
                                    p[pn] = x
                                    pn    = pn + 1
                                    p[pn] = y
                                    px    = x
                                    py    = y
                                end
                                nsq   = n1
                                w[3]  = 0
                                w[4]  = 0
                                if nsq == 0 then
                                    goto flush
                                end
                            end
                        end
                    end
                ::flush::
                    e = e + 1
                    edge[e] = p
                    if mpflatten then
                        mpflatten(p)
                    end
                end
            end
        end


        edges[value] = edge

    end

    result.edges = edges

end

function mp.lmt_contours_shade_set(edgetoo)
    local p        = getparameterset()
    local result   = p.result

    if result.cached then return end

    local values    = result.values
    local nofvalues = result.nofvalues
    local data      = result.data
    local nx        = result.nx
    local ny        = result.ny
    local color     = result.color

    local edges     = setmetatableindex("table")
    local shades    = setmetatableindex("table")

    local sqtype    = setmetatableindex("table")

    local xspoly    = { 0, 0, 0, 0, 0, 0 }
    local yspoly    = { 0, 0, 0, 0, 0, 0 }
    local xrpoly    = { }
    local yrpoly    = { }

    local xrpoly    = { } -- lua.newtable(2000,0)
    local yrpoly    = { } -- lua.newtable(2000,0)

 -- for i=1,2000 do
 --     xrpoly[i] = 0
 --     yrpoly[i] = 0
 -- end

    -- Unlike a c compiler lua will not optimize loops to run in parallel so we expand
    -- some of the loops and make sure we don't calculate when not needed. Not that nice
    -- but not that bad either. Maybe I should just write this from scratch.

--     local i = 0
--     local j = 0

    -- Analyze each rectangle separately. Overwrite lower colors

    -- Unrolling the loops and copying code and using constants is faster and doesn't
    -- produce much more code in the end, also because we then can leave out the not
    -- seen branches. One can argue about the foundit2* blobs but by stepwise optimizing
    -- this is the result.

    shades[1] = { { 0, 0, nx - 1, 0, nx - 1, ny - 1, 0, ny - 1 } }
    edges [1] = { { } }

    -- this is way too slow ... i must have messed up some loop .. what is this with value 1

    for value=1,nofvalues do
--     for value=2,nofvalues do

        local edge  = { }
        local nofe  = 0
        local shade = { }
        local nofs  = 0

        for i=1,nx-1 do
            local s = sqtype[i]
            for j=1,ny-1 do
                s[j] = 0
            end
        end

        local nrp = 0

        local function addedge(a,b,c,d)
            nofe = nofe + 1 edge[nofe] = a
            nofe = nofe + 1 edge[nofe] = b
            nofe = nofe + 1 edge[nofe] = c
            nofe = nofe + 1 edge[nofe] = d
        end
        while true do
            -- search for a square of type 0 with >= 1 corner above contour level
            local i
            local j
            local d0 = data[1]
            local d1 = data[2]
            for ii=1,nx do
                local s = sqtype[ii]
                for jj=1,ny do
                    if s[jj] == 0 then
                        if d0[jj] > value then i = ii j = jj goto foundit end
                        if d1[jj] > value then i = ii j = jj goto foundit end
                        local j1 = jj + 1
                        if d1[j1] > value then i = ii j = jj goto foundit end
                        if d0[j1] > value then i = ii j = jj goto foundit end
                    end
                end
                d0 = d1
                d1 = data[ii+1]
            end
            break
        ::foundit::
            -- initialize r-polygon (nrp seems to be 1 or 2)
            nrp = nrp + 1

            local first  = true
            local nrpoly = 0
            local nspoly = 0
            local nrpm   = -nrp
            -- this is the main loop
            while true do
                -- search for a square of type -nrp
                if first then
                    first = false
                    if sqtype[i][j] == 0 then -- true anyway
                        goto foundit1
                    end
                end
                for ii=1,nx do
                    local s = sqtype[ii]
                    for jj=1,ny do
                        if s[jj] == nrpm then
                            i = ii
                            j = jj
                            goto foundit1
                        end
                    end
                end
                break
            ::foundit1::
                while true do

                     -- search current then neighboring squares for square type 0, with a corner in common with current square above contour level

                    -- top/bottom ... a bit cheating here

                    local i_l, i_c, i_r    -- i left   current right
                    local j_b, j_c, j_t    -- j bottom current top

                    local i_n = i + 1      -- i next (right)
                    local j_n = j + 1      -- j next (top)

                    local i_p = i - 1      -- i previous (bottom)
                    local j_p = j - 1      -- j previous (right)

                    local d_c = data[i]
                    local d_r = data[i_n]

                    local sq

                    i_c = i ; j_c = j ; if i_c < nx and j_c < ny then sq = sqtype[i_c] if sq[j_c] == 0 then
                        if d_c[j_c] > value then i_l = i_p ; i_r = i_n ; j_b = j_p ; j_t = j_n ; goto foundit21 end
                        if d_c[j_n] > value then i_l = i_p ; i_r = i_n ; j_b = j_p ; j_t = j_n ; goto foundit22 end
                        if d_r[j_c] > value then i_l = i_p ; i_r = i_n ; j_b = j_p ; j_t = j_n ; goto foundit23 end
                        if d_r[j_n] > value then i_l = i_p ; i_r = i_n ; j_b = j_p ; j_t = j_n ; goto foundit24 end
                    end  end

                    i_c = i_n ; j_c = j ; if i_c < nx and j_c < ny then sq = sqtype[i_c] if sq[j_c] == 0 then
                        if d_r[j_c] > value then i_l = i ; i_r = i_n + 1 ; j_b = j_p ; j_t = j_n ; d_c = d_r ; d_r = data[i_r] ; goto foundit21 end
                        if d_r[j_n] > value then i_l = i ; i_r = i_n + 1 ; j_b = j_p ; j_t = j_n ; d_c = d_r ; d_r = data[i_r] ; goto foundit22 end
                    end end

                    i_c = i ; j_c = j_n ; if i_c < nx and j_c < ny then sq = sqtype[i_c] if sq[j_c] == 0 then
                        if d_c[j_n] > value then i_l = i_p ; i_r = i_n ; j_b = j ; j_t = j_n + 1 ; goto foundit21 end
                        if d_r[j_n] > value then i_l = i_p ; i_r = i_n ; j_b = j ; j_t = j_n + 1 ; goto foundit23 end
                    end end

                    i_c = i_p ; j_c = j ; if i_c > 0 and j_c < ny then sq = sqtype[i_c] if sq[j_c] == 0 then
                        if d_c[j_c] > value then i_l = i_p - 1 ; i_r = i ; j_b = j_p ; j_t = j_n ; d_r = d_c ; d_c = data[i_p] ; goto foundit23 end
                        if d_c[j_n] > value then i_l = i_p - 1 ; i_r = i ; j_b = j_p ; j_t = j_n ; d_r = d_c ; d_c = data[i_p] ; goto foundit24 end
                    end end

                    i_c = i ; j_c = j_p ;  if i < nx and j_c > 0 then sq = sqtype[i_c] if sq[j_c] == 0 then
                        if d_c[j] > value then i_l = i_p ; i_r = i_n ; j_b = j_p - 1 ; j_t = j ; goto foundit22 end
                        if d_r[j] > value then i_l = i_p ; i_r = i_n ; j_b = j_p - 1 ; j_t = j ; goto foundit24 end
                    end end

                    -- not found

                    sqtype[i][j] = nrp

                    break

                    -- define s-polygon for found square (i_c,j_c) - may have up to 6 sides

                ::foundit21:: -- 1 2 3 4

                    sq[j_c] = nrpm

                    xspoly[1] = i_l ; yspoly[1] = j_b
                    xspoly[2] = i_c ; yspoly[2] = j_b
                    if d_r[j_c] > value then -- dd2
                        xspoly[3] = i_c ; yspoly[3] = j_c
                        if d_r[j_t] > value then -- dd3
                            xspoly[4] = i_l ; yspoly[4] = j_c
                            if d_c[j_t] > value then -- dd4
                                nspoly = 4
                            else
                                xspoly[5] = i_l ; yspoly[5] = j_c ; nspoly = 5
                            end
                        elseif d_c[j_t] > value then -- dd4
                            xspoly[4] = i_c ; yspoly[4] = j_c ;
                            xspoly[5] = i_l ; yspoly[5] = j_c ; nspoly = 5
                        else
                            xspoly[4] = i_l ; yspoly[4] = j_c ; nspoly = 4
                            if edgetoo then addedge(i_c, j_c, i_l, j_c) end
                        end
                    elseif d_r[j_t] > value then -- dd3
                        xspoly[3] = i_c ; yspoly[3] = j_b
                        xspoly[4] = i_c ; yspoly[4] = j_c
                        if d_c[j_t] > value then -- dd4
                            xspoly[5] = i_l ; yspoly[5] = j_c ; nspoly = 5
                        else
                            xspoly[5] = i_l ; yspoly[5] = j_c ;
                            xspoly[6] = i_l ; yspoly[6] = j_c ; nspoly = 6
                        end
                    elseif d_c[j_t] > value then -- dd4
                        if edgetoo then addedge(i_c, j_b, i_c, j_c) end
                        xspoly[3] = i_c ; yspoly[3] = j_c ;
                        xspoly[4] = i_l ; yspoly[4] = j_c ; nspoly = 4
                    else
                        if edgetoo then addedge(i_c, j_b, i_l, j_c) end
                        xspoly[3] = i_l ; yspoly[3] = j_c ; nspoly = 3
                    end
                    goto done

                ::foundit22:: -- 4 1 2 3

                    sq[j_c] = nrpm

                    xspoly[1] = i_l ; yspoly[1] = j_c
                    xspoly[2] = i_l ; yspoly[2] = j_b
                    if d_c[j_c] > value then -- dd2
                        xspoly[3] = i_c ; yspoly[3] = j_b
                        if d_r[j_c] > value then -- dd3
                            xspoly[4] = i_c ; yspoly[4] = j_c
                            if d_r[j_t] > value then -- dd4
                                nspoly = 4
                            else
                                xspoly[5] = i_c ; yspoly[5] = j_c ; nspoly = 5 -- suspicious, the same
                            end
                        elseif d_r[j_t] > value then -- dd4
                            xspoly[4] = i_c ; yspoly[4] = j_b ;
                            xspoly[5] = i_c ; yspoly[5] = j_c ; nspoly = 5
                        else
                            if edgetoo then addedge(i_c, j_b, i_c, j_c) end
                            xspoly[4] = i_c ; yspoly[4] = j_c ;  nspoly = 4
                        end
                    elseif d_r[j_c] > value then -- dd3
                        xspoly[3] = i_l ; yspoly[3] = j_b
                        xspoly[4] = i_c ; yspoly[4] = j_b
                        xspoly[5] = i_c ; yspoly[5] = j_c
                        if d_r[j_t] > value then -- dd4
                            nspoly = 5
                        else
                            xspoly[6] = i_c ; yspoly[6] = j_c ; nspoly = 6
                        end
                    elseif d_r[j_t] > value then -- dd4
                        if edgetoo then addedge(i_l, j_b, i_c, j_b) end
                        xspoly[3] = i_c ; yspoly[3] = j_b
                        xspoly[4] = i_c ; yspoly[4] = j_c ; nspoly = 4
                    else
                        if edgetoo then addedge(i_l, j_b, i_c, j_c) end
                        xspoly[3] = i_c ; yspoly[3] = j_c ; nspoly = 3
                    end
                    goto done

                ::foundit23:: -- 2 3 4 1

                    sq[j_c] = nrpm

                    xspoly[1] = i_c ; yspoly[1] = j_b
                    xspoly[2] = i_c ; yspoly[2] = j_c
                    if d_r[j_t] > value then -- dd2
                        xspoly[3] = i_l ; yspoly[3] = j_c
                        if d_c[j_t] > value then -- dd3
                            xspoly[4] = i_l ; yspoly[4] = j_b
                            if d_c[j_c] > value then -- dd4
                                nspoly = 4
                            else
                                xspoly[5] = i_l ; yspoly[5] = j_b ; nspoly = 5
                            end
                        elseif d_c[j_c] > value then -- dd4
                            xspoly[4] = i_l ; yspoly[4] = j_c
                            xspoly[5] = i_l ; yspoly[5] = j_b ; nspoly = 5
                        else
                            if edgetoo then addedge(i_l, j_c, i_l, j_b) end
                            xspoly[4] = i_l ; yspoly[4] = j_b ; nspoly = 4
                        end
                    elseif d_c[j_t] > value then -- dd3
                        xspoly[3] = i_c ; yspoly[3] = j_c
                        xspoly[4] = i_l ; yspoly[4] = j_c
                        xspoly[5] = i_l ; yspoly[5] = j_b
                        if d_c[j_c] > value then -- dd4
                            nspoly = 5
                        else
                            xspoly[6] = i_l ; yspoly[6] = j_b ; nspoly = 6
                        end
                    elseif d_c[j_c] > value then -- dd4
                        if edgetoo then addedge(i_c, j_c, i_l, j_c) end
                        xspoly[3] = i_l ; yspoly[3] = j_c ;
                        xspoly[4] = i_l ; yspoly[4] = j_b ; nspoly = 4
                    else
                        if edgetoo then addedge(i_c, j_c, i_l, j_b) end
                        xspoly[3] = i_l ; yspoly[3] = j_b ; nspoly = 3
                    end
                    goto done

                ::foundit24:: -- 3 4 1 2

                    sq[j_c] = nrpm

                    xspoly[1] = i_c ; yspoly[1] = j_c
                    xspoly[2] = i_l ; yspoly[2] = j_c
                    if d_c[j_t] > value then -- dd2
                        if d_c[j_c] > value then -- dd3
                            xspoly[3] = i_l ; yspoly[3] = j_b
                            xspoly[4] = i_c ; yspoly[4] = j_b
                            if d_r[j_c] > value then -- dd4
                                nspoly = 4
                            else
                                xspoly[5] = i_c ; yspoly[5] = j_b ; nspoly = 5
                            end
                        else
                            xspoly[3] = i_l ; yspoly[3] = j_b
                            if d_r[j_c] > value then -- dd4

                                local xv34 = (dd3*i_c-dd4*i_l)/(dd3 - dd4) -- probably i_l
                                print("4.4 : xv34",xv34,i_c,i_l)

                             -- if edgetoo then addedge(i_l, j_b, xv34, j_b) end
                                xspoly[4] = xv34 ; yspoly[4] = j_b ;
                                xspoly[5] = i_c ; yspoly[5] = j_b ; nspoly = 5
                            else
                                if edgetoo then addedge(i_l, j_b, i_c, j_b) end
                                xspoly[4] = i_c ; yspoly[4] = j_b ; nspoly = 4
                            end
                        end
                    elseif d_c[j_c] > value then -- dd3
                        xspoly[3] = i_l ; yspoly[3] = j_b
                        xspoly[4] = i_l ; yspoly[4] = j_b
                        xspoly[5] = i_c ; yspoly[5] = j_b
                        if d_r[j_c] > value then -- dd4
                            nspoly = 5
                        else
                            xspoly[6] = i_c ; yspoly[6] = j_b ; nspoly = 6
                        end
                    elseif d_r[j_c] > value then -- dd4
                        if edgetoo then addedge(i_l, j_c, i_l, j_b) end
                        xspoly[3] = i_l ; yspoly[3] = j_b
                        xspoly[4] = i_c ; yspoly[4] = j_b ; nspoly = 4
                    else
                        if edgetoo then addedge(i_l, j_c, i_c, j_b) end
                        xspoly[3] = i_c ; yspoly[3] = j_b ; nspoly = 3
                    end
                 -- goto done

                ::done::
                    -- combine s-polygon with existing r-polygon, eliminating redundant segments

                    if nrpoly == 0 then
                        -- initiate r-polygon
                        for i=1,nspoly do
                            xrpoly[i] = xspoly[i]
                            yrpoly[i] = yspoly[i]
                        end
                        nrpoly = nspoly
                    else
                        -- search r-polygon and s-polygon for one side that matches
                        --
                        -- this is a bottleneck ... we keep this variant here but next go for a faster
                        -- alternative
                        --
                     -- local ispoly, irpoly
                     -- for r=nrpoly,1,-1 do
                     --     local r1
                     --     for s=1,nspoly do
                     --         local s1 = s % nspoly + 1
                     --         if xrpoly[r] == xspoly[s1] and yrpoly[r] == yspoly[s1] then
                     --             if not r1 then
                     --                 r1 = r % nrpoly + 1
                     --             end
                     --             if xrpoly[r1] == xspoly[s] and yrpoly[r1] == yspoly[s] then
                     --                 ispoly = s
                     --                 irpoly = r
                     --                 goto foundit3
                     --             end
                     --         end
                     --     end
                     -- end
                        --
                     -- local ispoly, irpoly
                     -- local xr1 = xrpoly[1]
                     -- local yr1 = yrpoly[1]
                     -- for r0=nrpoly,1,-1 do
                     --     for s0=1,nspoly do
                     --         if xr1 == xspoly[s0] and yr1 == yspoly[s0] then
                     --             if s0 == nspoly then
                     --                 if xr0 == xspoly[1] and yr0 == yspoly[1] then
                     --                     ispoly = s0
                     --                     irpoly = r0
                     --                     goto foundit3
                     --                 end
                     --             else
                     --                 local s1 = s0 + 1
                     --                 if xr0 == xspoly[s1] and yr0 == yspoly[s1] then
                     --                     ispoly = s0
                     --                     irpoly = r0
                     --                     goto foundit3
                     --                 end
                     --             end
                     --         end
                     --     end
                     --     xr1 = xrpoly[r0]
                     --     yr1 = yrpoly[r0]
                     -- end
                        --
                        -- but ...
                        --
                        local minx = xspoly[1]
                        local miny = yspoly[1]
                        local maxx = xspoly[1]
                        local maxy = yspoly[1]
                        for i=1,nspoly do
                            local y = yspoly[i]
                            if y < miny then
                                miny = y
                            elseif y > maxy then
                                maxy = y
                            end
                            local x = xspoly[i]
                            if x < minx then
                                minx = y
                            elseif x > maxx then
                                maxx = x
                            end
                        end
                        -- we can delay accessing y ...
                        local ispoly, irpoly
                        local xr1 = xrpoly[1]
                        local yr1 = yrpoly[1]
                        for r0=nrpoly,1,-1 do
                            if xr1 >= minx and xr1 <= maxx and yr1 >= miny and yr1 <= maxy then
                                local xr0 = xrpoly[r0]
                                local yr0 = yrpoly[r0]
                                for s0=1,nspoly do
                                    if xr1 == xspoly[s0] and yr1 == yspoly[s0] then
                                        if s0 == nspoly then
                                            if xr0 == xspoly[1] and yr0 == yspoly[1] then
                                                ispoly = s0
                                                irpoly = r0
                                                goto foundit3
                                            end
                                        else
                                            local s1 = s0 + 1
                                            if xr0 == xspoly[s1] and yr0 == yspoly[s1] then
                                                ispoly = s0
                                                irpoly = r0
                                                goto foundit3
                                            end
                                        end
                                    end
                                end
                                xr1 = xr0
                                yr1 = yr0
                            else
                                xr1 = xrpoly[r0]
                                yr1 = yrpoly[r0]
                            end
                        end
                        --
                        goto nomatch3
                    ::foundit3::
                        local match1 = 0
                        local rpoly1 = irpoly + nrpoly
                        local spoly1 = ispoly - 1
                        for i=2,nspoly-1 do
                            -- search for further matches nearby
                            local ir = (rpoly1 - i) % nrpoly + 1
                            local is = (spoly1 + i) % nspoly + 1
                            if xrpoly[ir] == xspoly[is] and yrpoly[ir] == yspoly[is] then
                                match1 = match1 + 1
                            else
                                break -- goto nomatch1
                            end
                        end
                    ::nomatch1::
                        local match2 = 0
                        local rpoly2 = irpoly - 1
                        local spoly2 = ispoly + nspoly
                        for i=2,nspoly-1 do
                            -- search other way for further matches nearby
                            local ir = (rpoly2 + i) % nrpoly + 1
                            local is = (spoly2 - i) % nspoly + 1
                            if xrpoly[ir] == xspoly[is] and yrpoly[ir] == yspoly[is] then
                                match2 = match2 + 1
                            else
                                break -- goto nomatch2
                            end
                        end
                    ::nomatch2::
                     -- local dnrpoly     = nspoly - 2 - 2*match1 - 2*match2
                        local dnrpoly     = nspoly - 2*(match1 + match2 + 1)
                        local ispolystart = (ispoly + match1) % nspoly + 1              -- first node of s-polygon to include
                        local irpolyend   = (rpoly1 - match1 - 1) % nrpoly + 1          -- last node of s-polygon to include
                        if dnrpoly ~= 0 then
                            local irpolystart = (irpoly + match2) % nrpoly + 1          -- first node of s-polygon to include
                            if irpolystart > irpolyend then
                             -- local ispolyend = (spoly1 - match2 + nspoly)%nspoly + 1 -- last node of s-polygon to include
                                if dnrpoly > 0 then
                                    -- expand the arrays xrpoly and yrpoly
                                    for i=nrpoly,irpolystart,-1 do
                                        local k = i + dnrpoly
                                        xrpoly[k] = xrpoly[i]
                                        yrpoly[k] = yrpoly[i]
                                    end
                                else -- if dnrpoly < 0 then
                                    -- contract the arrays xrpoly and yrpoly
                                    for i=irpolystart,nrpoly do
                                        local k = i + dnrpoly
                                        xrpoly[k] = xrpoly[i]
                                        yrpoly[k] = yrpoly[i]
                                    end
                                end
                            end
                            nrpoly = nrpoly + dnrpoly
                        end
                        if nrpoly < irpolyend then
                            for i=irpolyend,nrpoly+1,-1 do
                                -- otherwise these values get lost!
                                local k = i - nrpoly
                                xrpoly[k] = xrpoly[i]
                                yrpoly[k] = yrpoly[i]
                            end
                        end
                        local n = nspoly - 2 - match1 - match2
                        if n == 1 then
                            local irpoly1 = irpolyend   % nrpoly + 1
                            local ispoly1 = ispolystart % nspoly + 1
                            xrpoly[irpoly1] = xspoly[ispoly1]
                            yrpoly[irpoly1] = yspoly[ispoly1]
                        elseif n > 0 then
                            -- often 2
                            for i=1,n do
                                local ii = i - 1
                                local ir = (irpolyend   + ii) % nrpoly + 1
                                local is = (ispolystart + ii) % nspoly + 1
                                xrpoly[ir] = xspoly[is]
                                yrpoly[ir] = yspoly[is]
                            end
                        end
                ::nomatch3::
                    end
                end
            end

            if nrpoly > 0 then
                local t = { }
                local n = 0
                for i=1,nrpoly do
                    n = n + 1 t[n] = xrpoly[i]
                    n = n + 1 t[n] = yrpoly[i]
                end
                if mpflatten then
                    mpflatten(t) -- maybe integrate
                end
                nofs = nofs + 1
                shade[nofs] = t
             -- print(value,nrpoly,#t,#t-nrpoly*2)
            end

        end

        edges [value+1] = edge
        shades[value+1] = shade
--         edges [value] = edge
--         shades[value] = shade
    end

    result.shades = shades
    result.shapes = edges

end

-- accessors

function mp.lmt_contours_nx       (i) return getparameterset().result.nx end
function mp.lmt_contours_ny       (i) return getparameterset().result.ny end

function mp.lmt_contours_nofvalues()  return getparameterset().result.nofvalues end
function mp.lmt_contours_value    (i) return getparameterset().result.values[i] end

function mp.lmt_contours_minz     (i) return getparameterset().result.minz end
function mp.lmt_contours_maxz     (i) return getparameterset().result.maxz end

function mp.lmt_contours_minmean  (i) return getparameterset().result.minmean end
function mp.lmt_contours_maxmean  (i) return getparameterset().result.maxmean end

function mp.lmt_contours_xrange   ()  local p = getparameterset() mpstring(formatters["x = [%.3N,%.3N] ;"](p.xmin,p.xmax)) end
function mp.lmt_contours_yrange   ()  local p = getparameterset() mpstring(formatters["y = [%.3N,%.3N] ;"](p.ymin,p.ymax)) end

function mp.lmt_contours_format()
    local p = getparameterset()
    return mpstring(p.result.islist and "@i" or p.zformat or p.format)
end

function mp.lmt_contours_function()
    local p = getparameterset()
    return mpstring(p.result.islist and concat(p["functions"], ", ") or p["function"])
end

function mp.lmt_contours_range()
    local p = getparameterset()
    local r = p.result.islist and p.range
    if not r or #r == 0 then
        return mpstring("")
    elseif #r == 1 then
        return mpstring(r[1])
    else
        return mpstring(formatters["z = [%s,%s]"](r[1],r[2]))
    end
end

function mp.lmt_contours_edge_paths(value)
    mpdraw(getparameterset().result.edges[value],true)
    mpflush()
end

function mp.lmt_contours_shape_paths(value)
    mpdraw(getparameterset().result.shapes[value],false)
    mpflush()
end

function mp.lmt_contours_shade_paths(value)
    mpfill(getparameterset().result.shades[value],true)
    mpflush()
end

function mp.lmt_contours_color(value)
    local p     = getparameterset()
    local color = p.result.colors[value]
    if color then
        mpcolor(color)
    end
end

-- The next code is based on the wikipedia page. It was a bit tedius job to define the
-- coordinates but hupefully I made no errors. I rendered all shapes independently and
-- tripple checked bit one never knows ...

-- maybe some day write from scatch, like this (axis are swapped):

local d = 1/2

local paths = {
    { 0, d, d, 0 },
    { 1, d, d, 0 },
    { 0, d, 1, d },
    { 1, d, d, 1 },
    { 0, d, d, 1, d, 0, 1, d }, -- saddle
    { d, 0, d, 1 },
    { 0, d, d, 1 },
    { 0, d, d, 1 },
    { d, 0, d, 1 },
    { 0, d, d, 0, 1, d, d, 1 }, -- saddle
    { 1, d, d, 1 },
    { 0, d, 1, d },
    { d, 0, 1, d },
    { d, 0, 0, d },
}

local function whatever(data,nx,ny,threshold)
    local edges = { }
    local e     = 0
    local d0 = data[1]
    for j=1,ny-1 do
        local d1 = data[j+1]
        local k = j + 1
        for i=1,nx-1 do
            local v = 0
            local l = i + 1
            local c1 = d0[i]
            if c1 < threshold then
                v = v + 8
            end
            local c2 = d0[l]
            if c2 < threshold then
                v = v + 4
            end
            local c3 = d1[l]
            if c3 < threshold then
                v = v + 2
            end
            local c4 = d1[i]
            if c4 < threshold then
                v = v + 1
            end
            if v > 0 and v < 15 then
                if v == 5 or v == 10 then
                    local a = (c1 + c2 + c3 + c4) / 4
                    if a < threshold then
                        v = v == 5 and 10 or 5
                    end
                    local p = paths[v]
                    e = e + 1 edges[e] = k - p[2]
                    e = e + 1 edges[e] = i + p[1]
                    e = e + 1 edges[e] = k - p[4]
                    e = e + 1 edges[e] = i + p[3]
                    e = e + 1 edges[e] = k - p[6]
                    e = e + 1 edges[e] = i + p[5]
                    e = e + 1 edges[e] = k - p[8]
                    e = e + 1 edges[e] = i + p[7]
                else
                    local p = paths[v]
                    e = e + 1 edges[e] = k - p[2]
                    e = e + 1 edges[e] = i + p[1]
                    e = e + 1 edges[e] = k - p[4]
                    e = e + 1 edges[e] = i + p[3]
                end
            end
        end
        d0 = d1
    end
    return edges
end

-- todo: just fetch when needed, no need to cache

function mp.lmt_contours_edge_set_by_cell()
    local p         = getparameterset()
    local result    = p.result

    if result.cached then return end

    local values    = result.values
    local nofvalues = result.nofvalues
    local data      = result.data
    local nx        = result.nx
    local ny        = result.ny
    local lines     = { }
    result.lines    = lines
    for value=1,nofvalues do
        lines[value] = whatever(data,ny,nx,value)
    end
end

function mp.lmt_contours_edge_get_cell(value)
    mpdraw(getparameterset().result.lines[value])
    mpflush()
end

local singles = {
    { d, 0, 0, 0, 0, d },                   --  1  0001
    { d, 0, 0, d },                         --  2  0002
    { 1, d, 1, 0, d, 0 },                   --  3  0010
    { 1, d, 1, 0, 0, 0, 0, d },             --  4  0011
    { 1, d, 1, 0, d, 0, 0, d },             --  5  0012
    { 1, d, d, 0 },                         --  6  0020
    { 1, d, d, 0, 0, 0, 0, d },             --  7  0021
    { 1, d, 0, d },                         --  8  0022
    { d, 1, 1, 1, 1, d },                   --  9  0100
    false,                                  -- 10  0101
    false,                                  -- 11  0102
    { d, 1, 1, 1, 1, 0, d, 0 },             -- 12  0110
    { d, 1, 1, 1, 1, 0, 0, 0, 0, d },       -- 13  0111
    { d, 1, 1, 1, 1, 0, d, 0, 0, d },       -- 14  0112
    { d, 1, 1, 1, 1, d, d, 0 },             -- 15  0120
    { d, 1, 1, 1, 1, d, d, 0, 0, 0, 0, d }, -- 16  0121
    { d, 1, 1, 1, 1, d, 0, d },             -- 17  0122
    { d, 1, 1, d },                         -- 18  0200
    false,                                  -- 19  0201
    false,                                  -- 20  0202
    { d, 1, 1, d, 1, 0, d, 0 },             -- 21  0210
    { d, 1, 1, d, 1, 0, 0, 0, 0, d },       -- 22  0211
    false,                                  -- 23  0212
    { d, 1, d, 0 },                         -- 24  0220
    { d, 1, d, 0, 0, 0, 0, d },             -- 25  0221
    { d, 1, 0, d },                         -- 26  0222
    { 0, 1, d, 1, 0, d },                   -- 27  1000
    { 0, 1, d, 1, d, 0, 0, 0 },             -- 28  1001
    { 0, 1, d, 1, d, 0, 0, d },             -- 29  1002
    false,                                  -- 30  1010
    { 0, 1, d, 1, 1, d, 1, 0, 0, 0 },       -- 31  1011
    { 0, 1, d, 1, 1, d, 1, 0, d, 0, 0, d }, -- 32  1012
    false,                                  -- 33  1020
    { 0, 1, d, 1, 1, d, d, 0, 0, 0 },       -- 34  1021
    { 0, 1, d, 1, 1, d, 0, d },             -- 35  1022
    { 0, 1, 1, 1, 1, d, 0, d },             -- 36  1100
    { 0, 1, 1, 1, 1, d, d, 0, 0, 0 },       -- 37  1101
    { 0, 1, 1, 1, 1, d, d, 0, 0, d },       -- 38  1102
    { 0, 1, 1, 1, 1, 0, d, 0, 0, d },       -- 39  1110
    { 0, 1, 1, 1, 1, 0, 0, 0 },             -- 40  1111
    { 0, 1, 1, 1, 1, 0, d, 0, 0, d },       -- 41  1112
    { 0, 1, 1, 1, 1, d, d, 0, 0, d },       -- 42  1120
    { 0, 1, 1, 1, 1, d, d, 0, 0, 0 },       -- 43  1121
    { 0, 1, 1, 1, 1, d, 0, d },             -- 44  1122
    { 0, 1, d, 1, 1, d, 0, d },             -- 45  1200
    { 0, 1, d, 1, 1, d, d, 0, 0, 0 },       -- 46  1201
    false,                                  -- 47  1202
    { 0, 1, d, 1, 1, d, 1, 0, d, 0, 0, d }, -- 48  1210
    { 0, 1, d, 1, 1, d, 1, 0, 0, 0 },       -- 49  1211
    false,                                  -- 50  1212
    { 0, 1, d, 1, d, 0, 0, d },             -- 51  1220
    { 0, 1, d, 1, d, 0, 0, 0 },             -- 52  1221
    { 0, 1, d, 1, 0, d },                   -- 53  1222
    { d, 1, 0, d },                         -- 54  2000
    { d, 1, d, 0, 0, 0, 0, d },             -- 55  2001
    { d, 1, d, 0 },                         -- 56  2002
    false,                                  -- 57  2010
    { d, 1, 1, d, 1, 0, 0, 0, 0, d },       -- 58  2011
    { d, 1, 1, d, 1, 0, d, 0 },             -- 59  2012
    false,                                  -- 60  2020
    false,                                  -- 61  2021
    { d, 1, 1, d },                         -- 62  2022
    { d, 1, 1, 1, 1, d, 0, d },             -- 63  2100
    { d, 1, 1, 1, 1, d, d, 0, 0, 0, 0, d }, -- 64  2101
    { d, 1, 1, 1, 1, d, d, 0 },             -- 65  2102
    { d, 1, 1, 1, 1, 0, d, 0, 0, d },       -- 66  2110
    { d, 1, 1, 1, 1, 0, 0, 0, 0, d },       -- 67  2111
    { d, 1, 1, 1, 1, 0, d, 0 },             -- 68  2112
    false,                                  -- 69  2120
    false,                                  -- 70  2121
    { d, 1, 1, 1, 1, d },                   -- 71  2122
    { 1, d, 0, d },                         -- 72  2200
    { 1, d, d, 0, 0, 0, 0, d },             -- 73  2201
    { 1, d, d, 0 },                         -- 74  2202
    { 1, d, 1, 0, d, 0, 0, d },             -- 75  2210
    { 1, d, 1, 0, 0, 0, 0, d },             -- 76  2211
    { 1, d, 1, 0, d, 0 },                   -- 77  2212
    { d, 0, 0, d },                         -- 78  2220
    { 0, d, 0, 0, d, 0 },                   -- 79  2221
}

local sadles = {
    false, false, false, false, false, false, false, false, false,
    { { d, 1, 1, 1, 1, d }, { d, 0, 0, 0, 0, d }, { d, 1, 1, 1, 1, d, d, 0, 0, 0, 0, d }, false, false, false },  -- 10  0101
    { { d, 1, 1, 1, 1, d }, { d, 0, 0, d }, { d, 1, 1, 1, 1, d, d, 0, 0, d }, false, false, false },              -- 11  0102
    false, false, false, false, false, false, false,
    { { d, 1, 1, d }, { d, 0, 0, 0, 0, d }, { d, 1, 1, d, d, 0, 0, 0, 0, d }, false, false, false },              -- 19  0201
    { { d, 1, 1, d }, { d, 0, 0, d }, { d, 1, 1, d, d, 0, 0, d }, false, { d, 1, 0, d }, { 1, d, d, 0 } },        -- 20  0202
    false, false,
    { false, false, { d, 1, 1, d, 1, 0, d, 0, 0, d }, false, { d, 1, 0,d, }, { 1, d, 1, 0,d, 0 } },               -- 23  0212
    false, false, false, false, false, false,
    { { 0, 1, d, 1, 0, d }, { 1, d, 1, 0, d, 0 }, { 0, 1, d, 1, 1, d, 1, 0, d, 0, 0, d }, false, false, false  }, -- 30  1010
    false, false,
    { { 1, 0, d, 0, 0, d, }, { 1, d, d, 0 }, { 0, 1, d, 1, 1, d, d, 0, 0, d }, false, false, false },             -- 33  1020
    false, false, false, false, false, false, false, false, false, false, false, false, false,
    { false, false, { 0,1, d, 1, 1, d, d, 0, 0, d }, false, { 0,1, d, 1, 0, d }, {1, d, d, 0 } },                 -- 47  1202
    false, false,
    { false, false, { 0, 1, d, 1, 1, d, 1, 0, d, 0, 0, d }, false, { 0, 1, d, 1, 0, d }, { 1, d, 1, 0, d, 0 } },  -- 50  1212
    false, false, false, false, false, false,
    { { d, 1, 0, d }, { 1, d, 1, 0, 0, d }, { d, 1, 1, d, 1, 0, d, 0, 0, d }, false,  false, false },             -- 57  2010
    false, false,
    { { d, 1, 0,d }, { 1, d, d, 0 }, { d, 1, 1, d, d, 0, 0, d }, false, { d, 1, 1, d }, { d, 0, 0, d } },         -- 60  2020
    { false, false, { d, 1, 1, d, d, 0, 0, 0, 0, d }, false, { d, 1, 1, d }, { d, 0, 0, 0, 0, d } },              -- 61  2021
    false, false, false, false, false, false, false,
    { false, false, { d, 1, 1, 1, 1, d, d, 0, 0, d }, false, { d, 1, 1, 1, 1, d }, { d, 0,0,d } },                -- 69  2120
    { false, false, { d, 1, 1, 1, 1, d, d, 0, 0, 0, 0, d }, false, { d, 1, 1, 1, 1, d }, { d, 0, 0, 0, 0, d } },  -- 70  2121
}

local function whatever(data,nx,ny,threshold,background)

    if background then

        local llx = 1/2
        local lly = llx
        local urx = ny + llx
        local ury = nx + lly

        return { { llx, lly, urx, 0, urx, ury, 0, ury } }

    else

        local bands = { }
        local b     = 0

        local function band(s,n,x,y) -- simple. no closure so fast
            if n == 6 then
                return {
                    x - s[ 2], y + s[ 1], x - s[ 4], y + s[ 3], x - s[ 6], y + s[ 5],
                }
            elseif n == 8 then
                return {
                    x - s[ 2], y + s[ 1], x - s[ 4], y + s[ 3], x - s[ 6], y + s[ 5],
                    x - s[ 8], y + s[ 7],
                }
            elseif n == 10 then
                return {
                    x - s[ 2], y + s[ 1], x - s[ 4], y + s[ 3], x - s[ 6], y + s[ 5],
                    x - s[ 8], y + s[ 7], x - s[10], y + s[ 9],
                }
            elseif n == 4 then
                return {
                    x - s[ 2], y + s[ 1], x - s[ 4], y + s[ 3],
                }
            else -- 12
                return {
                    x - s[ 2], y + s[ 1], x - s[ 4], y + s[ 3], x - s[ 6], y + s[ 5],
                    x - s[ 8], y + s[ 7], x - s[10], y + s[ 9], x - s[12], y + s[11],
                }
            end
        end

        local pp = { }

        local d0 = data[1]
        for j=1,ny-1 do
            local d1 = data[j+1]
            local k = j + 1
            local p = false
            for i=1,nx-1 do
                local v = 0
                local l = i + 1
                local c1 = d0[i]
                if c1 == threshold then
                    v = v + 27
                elseif c1 > threshold then
                    v = v + 54
                end
                local c2 = d0[l]
                if c2 == threshold then
                    v = v + 9
                elseif c2 > threshold then
                    v = v + 18
                end
                local c3 = d1[l]
                if c3 == threshold then
                    v = v + 3
                elseif c3 > threshold then
                    v = v + 6
                end
                local c4 = d1[i]
                if c4 == threshold then
                    v = v + 1
                elseif c4 > threshold then
                    v = v + 2
                end
                if v > 0 and v < 80 then
                    if v == 40 then
                        -- a little optimization: full areas appended horizontally
                        if p then
                            p[4] = l -- i + 1
                            p[6] = l -- i + 1
                        else
                            -- x-0 y+1 x-1 y+1 x-1 y+0 x-0 y+0
                            p = { j, i, j, l, k, l, k, i }
                            b = b + 1 ; bands[b] = p
                        end
                    else
                        local s = singles[v]
                        if s then
                            b = b + 1 ; bands[b] = band(s,#s,k,i)
                        else
                            local s = sadles[v]
                            if s then
                                local m = (c1 + c2 + c3 + c4) / 4
                                if m < threshold then
                                    local s1 = s[1] if s1 then b = b + 1 ; bands[b] = band(s1,#s1,i,j) end
                                    local s2 = s[2] if s2 then b = b + 1 ; bands[b] = band(s2,#s2,i,j) end
                                elseif m == threshold then
                                    local s3 = s[3] if s3 then b = b + 1 ; bands[b] = band(s3,#s3,i,j) end
                                    local s4 = s[4] if s4 then b = b + 1 ; bands[b] = band(s4,#s4,i,j) end
                                else
                                    local s5 = s[5] if s5 then b = b + 1 ; bands[b] = band(s5,#s5,i,j) end
                                    local s6 = s[6] if s6 then b = b + 1 ; bands[b] = band(s6,#s6,i,j) end
                                end
                            end
                        end
                        p = false
                    end
                else
                    p = false
                end
            end
            d0 = d1
        end
        return bands
    end
end

function mp.lmt_contours_edge_set_by_band(value)
    local p         = getparameterset()
    local result    = p.result

    if result.cached then return end

    local values    = result.values
    local nofvalues = result.nofvalues
    local data      = result.data
    local nx        = result.nx
    local ny        = result.ny
    local bands     = { }
    result.bands    = bands
    for value=1,nofvalues do
        bands[value] = whatever(data,ny,nx,value,value == 1)
    end
end

function mp.lmt_contours_edge_get_band(value)
    mpfill(getparameterset().result.bands[value],true)
    mpflush()
end

-- Because we share some code surface plots also end up here. When working on the
-- contour macros by concidence I ran into a 3D plot in
--
-- https://staff.science.uva.nl/a.j.p.heck/Courses/mptut.pdf
--
-- The code is pure MetaPost and works quite well. With a bit of optimization
-- performance is also ok, but in the end a Lua solution is twice as fast and also
-- permits some more tweaking at no cost. So, below is an adaptation of an example
-- in the mentioned link. It's one of these cases where access to pseudo arrays
-- is slowing down MP.

local sqrt, sin, cos = math.sqrt, math.sin, math.cos

local f_fill_rgb = formatters["F (%.6N,%.6N)--(%.6N,%.6N)--(%.6N,%.6N)--(%.6N,%.6N)--C withcolor (%.3N,%.3N,%.3N) ;"]
local f_draw_rgb = formatters["D (%.6N,%.6N)--(%.6N,%.6N)--(%.6N,%.6N)--(%.6N,%.6N)--C withcolor %.3F ;"]
local f_mesh_rgb = formatters["U (%.6N,%.6N)--(%.6N,%.6N)--(%.6N,%.6N)--(%.6N,%.6N)--C withcolor (%.3N,%.3N,%.3N) ;"]
local f_fill_cmy = formatters["F (%.6N,%.6N)--(%.6N,%.6N)--(%.6N,%.6N)--(%.6N,%.6N)--C withcolor (%.3N,%.3N,%.3N,0) ;"]
local f_draw_cmy = formatters["D (%.6N,%.6N)--(%.6N,%.6N)--(%.6N,%.6N)--(%.6N,%.6N)--C withcolor %.3F ;"]
local f_mesh_cmy = formatters["U (%.6N,%.6N)--(%.6N,%.6N)--(%.6N,%.6N)--(%.6N,%.6N)--C withcolor (%.3N,%.3N,%.3N,0) ;"]

local f_function_n = formatters [ [[
    local math  = math
    local round = math.round
    %s
    return function(x,y)
        return %s
    end
]] ]

local f_function_y = formatters [ [[
    local math  = math
    local round = math.round
    local nan   = NaN
    local inf   = math.huge
    local er    = 0
    %s
    return function(x,y,dnan,dinf,report)
        local n = %s
        if n == nan then
            er = er + 1
            if er < 10 then
                report("nan at (%s,%s)",x,y)
            end
            n = dnan
        elseif n == inf then
            er = er + 1
            if er < 10 then
                report("inf at (%s,%s)",x,y)
            end
            n = dinf
        end
        dx[my] = n
        sy = sy + 1
    end
    return n, er
end
]] ]

local f_color = formatters [ [[
    local math = math
    return function(f)
        return %s
    end
]] ]

function mp.lmt_surface_do(specification)
    --
    -- The projection and color brightness calculation have been inlined. We also store
    -- differently.
    --
    -- todo: ignore weird paths
    --
    -- The prototype is now converted to use lmt parameter sets.
    --
    local p = getparameterset("surface")
    --
    local preamble  = p.preamble   or ""
    local code      = p.code       or "return x + y"
    local colorcode = p.color      or "return f, f, f"
    local linecolor = p.linecolor  or 1
    local xmin      = p.xmin       or -1
    local xmax      = p.xmax       or  1
    local ymin      = p.ymin       or -1
    local ymax      = p.ymax       or  1
    local xstep     = p.xstep      or .1
    local ystep     = p.ystep      or .1
    local bf        = p.brightness or 100
    local clip      = p.clip       or false
    local lines     = p.lines
    local ha        = p.snap       or 0.01
    local hb        = 2 * ha
    --
    if lines == nil then lines = true end
    --
    if xstep == 0 then xstep = (xmax - xmin)/100 end
    if ystep == 0 then ystep = (ymax - ymin)/100 end

    local nxmin = round(xmin/xstep)
    local nxmax = round(xmax/xstep)
    local nymin = round(ymin/ystep)
    local nymax = round(ymax/ystep)
    local nx    = nxmax - nxmin + 1
    local ny    = nymax - nymin + 1
    --
    local xvector = p.xvector    or { -0.7, -0.7 }
    local yvector = p.yvector    or { 1, 0 }
    local zvector = p.zvector    or { 0, 1 }
    local light   = p.light      or { 3, 3, 10 }
    --
    local xrx, xry   = xvector[1], xvector[2]
    local yrx, yry   = yvector[1], yvector[2]
    local zrx, zry   = zvector[1], zvector[2]
    local xp, yp, zp = light[1], light[2], light[3]
    --
    local data = setmetatableindex("table")
    local dx   = (xmax - xmin) / nx
    local dy   = (ymax - ymin) / ny
    local xt   = xmin
    --
    local minf, maxf
    --
    -- similar as contours but no data loop here
    --
    local fcode = load((p.check and f_function_y or f_function_n)(preamble,code))
    local func  = type(fcode) == "function" and fcode()
    if type(func) ~= "function" then
        return false -- fatal error
    end
    --
    local ccode = load(f_color(colorcode))
    local color = type(ccode) == "function" and ccode()
    if type(color) ~= "function" then
        return false -- fatal error
    end
    --
    for i=0,nx do
        local yt = ymin
        for j=0,ny do
            local zt = func(xt,yt)
            -- projection from 3D to 2D coordinates
            local x = xt * xrx + yt * yrx + zt * zrx
            local y = xt * xry + yt * yry + zt * zry
            local z = zt
            -- numerical derivatives by central differences
            local dfx = (func(xt+ha,yt) - func(xt-ha,yt)) / hb
            local dfy = (func(xt,yt+ha) - func(xt,yt-ha)) / hb
            -- compute brightness factor at a point
            local ztp = zt - zp
            local ytp = yt - yp
            local xtp = xt - xp
            local ztp = zt - zp
            local ytp = yt - yp
            local xtp = xt - xp
            local ca  = -ztp + dfy*ytp + dfx*xtp
            local cb  = sqrt(1+dfx*dfx+dfy*dfy)
            local cc  = sqrt(ztp*ztp + ytp*ytp + xtp*xtp)
            local fac = bf*ca/(cb*cc*cc*cc)
            -- addition: check range
            if not minf then
                minf = fac
                maxf = fac
            elseif fac < minf then
                minf = fac
            elseif fac > maxf then
                maxf = fac
            end
            --
            data[i][j] = { x, y, fac }
            --
            yt = yt + dy
        end
        xt = xt + dx
    end
    local result  = { }
    local r       = 0
    local range   = maxf - minf
    local cl      = linecolor or 1
    local enforce = attributes.colors.model == "cmyk"
    for i=0,nx-1 do
        for j=0,ny-1 do
            -- points
            local z1 = data[i]  [j]
            local z2 = data[i]  [j+1]
            local z3 = data[i+1][j+1]
            local z4 = data[i+1][j]
            -- color
            local cf = z1[3]
            if clip then
                -- best clip here if needed
                if cf < 0 then
                    cf = 0
                elseif cf > 1 then
                    cf = 1
                end
            else
                -- or remap when we want to
                cf = (z1[3] - minf) / range
            end
            local z11 = z1[1]
            local z12 = z1[2]
            local z21 = z2[1]
            local z22 = z2[2]
            local z31 = z3[1]
            local z32 = z3[2]
            local z41 = z4[1]
            local z42 = z4[2]
         -- if lines then
         --     -- fill first and draw then, previous shapes can be covered
         -- else
         --     -- fill and draw in one go to prevent artifacts
         -- end
            local cr, cg, cb = color(cf)
            if not cr then cr = 0 end
            if not cg then cg = 0 end
            if not cb then cb = 0 end
            if enforce then
                cr, cg, cb = 1 - cr, 1 - cg, 1 - cb
                r = r + 1
                if lines then
                    result[r] = f_fill_cmy(z11,z12,z21,z22,z31,z32,z41,z42,cr,cg,cb)
                    r = r + 1
                    result[r] = f_draw_cmy(z11,z12,z21,z22,z31,z32,z41,z42,cl)
                else
                    result[r] = f_mesh_cmy(z11,z12,z21,z22,z31,z32,z41,z42,cr,cg,cb)
                end
            else
                r = r + 1
                if lines then
                    result[r] = f_fill_rgb(z11,z12,z21,z22,z31,z32,z41,z42,cr,cg,cb)
                    r = r + 1
                    result[r] = f_draw_rgb(z11,z12,z21,z22,z31,z32,z41,z42,cl)
                else
                    result[r] = f_mesh_rgb(z11,z12,z21,z22,z31,z32,z41,z42,cr,cg,cb)
                end
            end
        end
    end
    mp.direct(concat(result))
end
