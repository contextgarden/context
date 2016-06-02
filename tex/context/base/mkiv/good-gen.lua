if not modules then modules = { } end modules ['good-gen'] = {
    version   = 1.000,
    comment   = "companion to font-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- depends on ctx

local type, next = type, next
local lower = string.lower

local fonts = fonts

----- trace_goodies  = false  trackers.register("fonts.goodies", function(v) trace_goodies = v end)
----- report_goodies = logs.reporter("fonts","goodies")

local allocate       = utilities.storage.allocate
local texsp          = tex.sp
local fontgoodies    = fonts.goodies or { }
local findfile       = resolvers.findfile


local typefaces      = fonts.typefaces or { }
fonts.typefaces      = typefaces

-- the following takes care of explicit file specifications
--
-- files = {
--     name = "antykwapoltawskiego",
--     list = {
--         ["AntPoltLtCond-Regular.otf"] = {
--          -- name   = "antykwapoltawskiego",
--             style  = "regular",
--             weight = "light",
--             width  = "condensed",
--         },
--     },
-- }

-- files

local function initialize(goodies)
    local files = goodies.files
    if files then
        fonts.names.register(files)
    end
end

fontgoodies.register("files", initialize)

-- some day we will have a define command and then we can also do some
-- proper tracing
--
-- fonts.typefaces["antykwapoltawskiego-condensed"] = {
--     shortcut     = "rm",
--     shape        = "serif",
--     fontname     = "antykwapoltawskiego",
--     normalweight = "light",
--     boldweight   = "medium",
--     width        = "condensed",
--     size         = "default",
--     features     = "default",
-- }

local function initialize(goodies)
    local typefaces = goodies.typefaces
    if typefaces then
        local ft = fonts.typefaces
        for k, v in next, typefaces do
            ft[k] = v
        end
    end
end

fontgoodies.register("typefaces", initialize)

local compositions = { }

function fontgoodies.getcompositions(tfmdata)
    return compositions[file.nameonly(tfmdata.properties.filename or "")]
end

local function initialize(goodies)
    local gc = goodies.compositions
    if gc then
        for k, v in next, gc do
            compositions[k] = v
        end
    end
end

fontgoodies.register("compositions", initialize)

-- extra treatments (on top of defaults): \loadfontgoodies[mytreatments]

local treatmentdata = fonts.treatments.data

local function initialize(goodies)
    local treatments = goodies.treatments
    if treatments then
        for name, data in next, treatments do
            treatmentdata[name] = data -- always wins
        end
    end
end

fontgoodies.register("treatments", initialize)

local filenames       = fontgoodies.filenames or allocate()
fontgoodies.filenames = filenames

local filedata        = filenames.data or allocate()
filenames.data        = filedata

local function initialize(goodies) -- design sizes are registered global
    local fn = goodies.filenames
    if fn then
        for usedname, alternativenames in next, fn do
            filedata[usedname] = alternativenames
        end
    end
end

fontgoodies.register("filenames", initialize)

function fontgoodies.filenames.resolve(name)
    local fd = filedata[name]
    if fd and findfile(name) == "" then
        for i=1,#fd do
            local fn = fd[i]
            if findfile(fn) ~= "" then
                return fn
            end
        end
    else
        -- no lookup, just use the regular mechanism
    end
    return name
end

local designsizes       = fontgoodies.designsizes or allocate()
fontgoodies.designsizes = designsizes

local designdata        = designsizes.data or allocate()
designsizes.data        = designdata

local function initialize(goodies) -- design sizes are registered global
    local gd = goodies.designsizes
    if gd then
        for name, data in next, gd do
            local ranges = { }
            for size, file in next, data do
                if size ~= "default" then
                    ranges[#ranges+1] =  { texsp(size), file } -- also lower(file)
                end
            end
            table.sort(ranges,function(a,b) return a[1] < b[1] end)
            designdata[lower(name)] = { -- overloads, doesn't merge!
                default = data.default,
                ranges  = ranges,
            }
        end
    end
end

fontgoodies.register("designsizes", initialize)

function fontgoodies.designsizes.register(name,size,specification)
    local d = designdata[name]
    if not d then
        d = {
            ranges  = { },
            default = nil, -- so we have no default set
        }
        designdata[name] = d
    end
    if size == "default" then
        d.default = specification
    else
        if type(size) == "string" then
            size = texsp(size) -- hm
        end
        local ranges = d.ranges
        ranges[#ranges+1] = { size, specification }
    end
end

function fontgoodies.designsizes.filename(name,spec,size) -- returns nil of no match
    local data = designdata[lower(name)]
    if data then
        if not spec or spec == "" or spec == "default" then
            return data.default
        elseif spec == "auto" then
            local ranges = data.ranges
            if ranges then
                for i=1,#ranges do
                    local r = ranges[i]
                    if r[1] >= size then -- todo: rounding so maybe size - 100
                        return r[2]
                    end
                end
            end
            return data.default or (ranges and ranges[#ranges][2])
        end
    end
end
