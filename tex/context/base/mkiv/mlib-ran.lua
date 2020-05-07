if not modules then modules = { } end modules ['mlib-ran'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local next = next
local ceil, floor, random, sqrt, cos, sin, pi, max, min = math.ceil, math.floor, math.random, math.sqrt, math.cos, math.sin, math.pi, math.min, math.max
local remove = table.remove

-- Below is a bit of rainy saturday afternoon hobyism, while listening to Judith
-- Owens redisCOVERed (came there via Leland Sklar who I have on a few live blurays;
-- and who is also on YT). (Also nice: https://www.youtube.com/watch?v=GXqasIRaxlA)

-- When Aditya pointed me to an article on mazes I ended up at poison distributions
-- which to me looks nicer than what I normally do, fill a grid and then randomize
-- the resulting positions. With some hooks this can be used for interesting patterns
-- too. A few links:
--
-- https://bost.ocks.org/mike/algorithms/#maze-generation
-- https://extremelearning.com.au/
-- https://www.jasondavies.com/maps/random-points/
-- http://devmag.org.za/2009/05/03/poisson-disk-sampling

-- The next function is quite close to what us discribed in the poisson-disk-sampling
-- link mentioned before. One can either use a one dimensional grid array or a two
-- dimensional one. The example code uses some classes dealing with points. In the
-- process I added some more control.

-- we could do without the samplepoints list

local function poisson(width, height, mindist, newpointscount, initialx, initialy)
    local starttime       = os.clock()
    local cellsize        = mindist / sqrt(2)
    local nofwidth        = ceil(width // cellsize)
    local nofheight       = ceil(height // cellsize)
    local grid            = lua.newtable(nofwidth,0) -- table.setmetatableindex("table")
    local firstx          = initialx or random() * width
    local firsty          = initialy or random() * height
    local firstpoint      = { firstx, firsty, 1 }
 -- local samplepoints    = { firstpoint }
    local processlist     = { firstpoint }
    local nofprocesslist  = 1
    local nofsamplepoints = 1
    local twopi           = 2 * pi

    for i=1,nofwidth do
        local g = lua.newindex(nofheight,false)
        grid[i] = g
    end

    local x = floor(firstx // cellsize) + 1 -- lua indices
    local y = floor(firsty // cellsize) + 1 -- lua indices

    x = max(1, min(x, width  - 1))
    y = max(1, min(y, height - 1))

    grid[x][y] = firstpoint

    -- The website shows graphic for this 5*5 grid snippet, if we use a one dimentional
    -- array then we could have one loop; a first version used a metatable trick so we
    -- had grid[i+gx][j+gy] but we no we also return the grid, so ... we now just check.

    -- There is no need for the samplepoints list as we can get that from the grid but
    -- instead we can store the index with the grid.

    while nofprocesslist > 0 do
        local point = remove(processlist,random(1,nofprocesslist))
        nofprocesslist = nofprocesslist - 1
        for i=1,newpointscount do -- we start at 1
            local radius = mindist * (random() + 1)
            local angle  = twopi * random()
            local nx     = point[1] + radius * cos(angle)
            local ny     = point[2] + radius * sin(angle)
            if nx > 1 and ny > 1 and nx <= width and ny <= height then -- lua indices
                local gx = floor(nx // cellsize)
                local gy = floor(ny // cellsize)
                -- the 5x5 cells around the point
                for i=-2,2 do
                    for j=-2,2 do
                        local cell = grid[i + gx]
                        if cell then
                            cell = cell[j + gy]
                            if cell and sqrt((cell[1] - nx)^2 + (cell[2] - ny)^2) < mindist then
                                goto next
                            end
                        end
                    end
                end
             -- local newpoint  = { nx, ny }
                nofprocesslist  = nofprocesslist + 1
                nofsamplepoints = nofsamplepoints + 1
                local newpoint  = { nx, ny, nofsamplepoints }
                processlist [nofprocesslist]  = newpoint
             -- samplepoints[nofsamplepoints] = newpoint
                grid[gx][gy] = newpoint
            end
            ::next::
        end
    end

    return {
        count  = nofsamplepoints,
     -- points = samplepoints,
        grid   = grid,
        time   = os.clock() - starttime,
    }
end

-- For now:

local randomizers     = utilities.randomizers or { }
utilities.randomizers = randomizers
randomizers.poisson   = poisson

-- The MetaFun interface:

local formatters = string.formatters
local concat = table.concat

local f_macro = formatters["%s(%N,%N);"]

local f_macros = {
    [2] = formatters["%s(%N,%N);"],
    [3] = formatters["%s(%N,%N,%i);"],
    [4] = formatters["%s(%N,%N,%i,%i);"],
}

function grid_to_mp(t,f,n)
    local grid   = t.grid
    local count  = t.count
    local result = { }
    local r      = 0
    local macro  = f or "draw"
    local runner = f_macros[n or 2] or f_macros[2]
    for i=1,#grid do
        local g = grid[i]
        if g then
            for j=1,#g do
                local v = g[j]
                if v then
                    r = r + 1
                    result[r] = runner(macro,v[1],v[2],v[3],count)
                end
            end
        end
    end
    return concat(result, " ")
end

local getparameter = metapost.getparameter

local function lmt_poisson()
    local initialx = getparameter { "initialx" }
    local initialy = getparameter { "initialy" }
    local width    = getparameter { "width" }
    local height   = getparameter { "height" }
    local distance = getparameter { "distance" }
    local count    = getparameter { "count" }

    local result = poisson (
        width, height, distance, count,
        initialx > 0 and initialx or false,
        initialy > 0 and initialy or false
    )

    if result then
        logs.report("poisson","w=%N, h=%N, d=%N, c=%N, n=%i, runtime %.3f",
            width, height, distance, count, result.count, result.time
        )
    end

    return result
end

function mp.lmt_poisson_generate()
    local result = lmt_poisson()
    if result then
        return grid_to_mp (
            result,
            getparameter { "macro" },
            getparameter { "arguments" }
        )
    end
end

-- -- some playing around showed no benefit
--
-- function points_to_mp(t,f)
--     local points = t.points
--     local count  = t.count
--     local result = { }
--     local r      = 0
--     local macro  = f or "draw"
--     local runner = f_macros[n or 2] or f_macros[2]
--     for i=1,count do
--         local v = points[i]
--         r = r + 1
--         result[r] = runner(macro,v[1],v[2],v[3],count)
--     end
--     return concat(result, " ")
-- end
--
-- local result  = false
-- local i, j, n = 0, 0, 0
--
-- function mp.lmt_poison_start()
--     result = lmt_poisson()
-- end
--
-- function mp.lmt_poisson_stop()
--     result = false
-- end
--
-- function mp.lmt_poisson_count()
--     return result and result.count or 0
-- end
--
-- function mp.lmt_poisson_get(i)
--     if result then
--         return mp.pair(result.points[i])
--     end
-- end
--
-- function mp.lmt_poisson_generate()
--     mp.lmt_poisson_start()
--     if result then
--         return grid_to_mp (
--             result,
--             getparameter { "macro" },
--             getparameter { "arguments" }
--         )
--     end
--     mp.lmt_poisson_stop()
-- end
