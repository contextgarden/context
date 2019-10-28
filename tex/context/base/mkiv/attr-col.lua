if not modules then modules = { } end modules ['attr-col'] = {
    version   = 1.001,
    comment   = "companion to attr-col.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this module is being reconstructed and code will move to other places
-- we can also do the nsnone via a metatable and then also se index 0

-- list could as well refer to the tables (instead of numbers that
-- index into another table) .. depends on what we need

local type, tonumber = type, tonumber
local concat = table.concat
local min, max, floor, mod = math.min, math.max, math.floor, math.mod

local attributes            = attributes
local nodes                 = nodes
local utilities             = utilities
local logs                  = logs
local backends              = backends
local storage               = storage
local context               = context
local tex                   = tex

local variables             = interfaces.variables
local v_yes                 = variables.yes
local v_no                  = variables.no

local p_split_comma         = lpeg.tsplitat(",")
local p_split_colon         = lpeg.splitat(":")
local lpegmatch             = lpeg.match

local allocate              = utilities.storage.allocate
local setmetatableindex     = table.setmetatableindex

local report_attributes     = logs.reporter("attributes","colors")
local report_colors         = logs.reporter("colors","support")
local report_transparencies = logs.reporter("transparencies","support")

-- todo: document this but first reimplement this as it reflects the early
-- days of luatex / mkiv and we have better ways now

-- nb: attributes: color etc is much slower than normal (marks + literals) but ...
-- nb. too many "0 g"s

local states          = attributes.states
local nodeinjections  = backends.nodeinjections
local registrations   = backends.registrations
local unsetvalue      = attributes.unsetvalue

local enableaction    = nodes.tasks.enableaction
local setaction       = nodes.tasks.setaction

local registerstorage = storage.register
local formatters      = string.formatters

local interfaces      = interfaces
local implement       = interfaces.implement

local texgetattribute = tex.getattribute

-- We can distinguish between rules and glyphs but it's not worth the trouble. A
-- first implementation did that and while it saves a bit for glyphs and rules, it
-- costs more resourses for transparencies. So why bother.

--
-- colors
--

-- we can also collapse the two attributes: n, n+1, n+2 and then
-- at the tex end add 0, 1, 2, but this is not faster and less
-- flexible (since sometimes we freeze color attribute values at
-- the lua end of the game)
--
-- we also need to store the colorvalues because we need then in mp
--
-- This is a compromis between speed and simplicity. We used to store the
-- values and data in one array, which made in neccessary to store the
-- converters that need node constructor into strings and evaluate them
-- at runtime (after reading from storage). Think of:
--
-- colors.strings = colors.strings or { }
--
-- if environment.initex then
--     colors.strings[color] = "return colors." .. colorspace .. "(" .. concat({...},",") .. ")"
-- end
--
-- registerstorage("attributes/colors/data", colors.strings, "attributes.colors.data") -- evaluated
--
-- We assume that only processcolors are defined in the format.

attributes.colors = attributes.colors or { }
local colors      = attributes.colors

local a_color     = attributes.private('color')
local a_selector  = attributes.private('colormodel')

colors.data       = allocate()
colors.values     = colors.values or { }
colors.registered = colors.registered or { }
colors.weightgray = true
colors.attribute  = a_color
colors.selector   = a_selector
colors.default    = 1
colors.main       = nil
colors.triggering = true
colors.supported  = true
colors.model      = "all"

local data        = colors.data
local values      = colors.values
local registered  = colors.registered

local cmykrgbmode = 0 -- only for testing, already defined colors are not affected

local numbers     = attributes.numbers
local list        = attributes.list

registerstorage("attributes/colors/values",     values,     "attributes.colors.values")
registerstorage("attributes/colors/registered", registered, "attributes.colors.registered")

directives.register("colors.cmykrgbmode", function(v) cmykrgbmode = tonumber(v) or 0 end)

local f_colors = {
    rgb  = formatters["r:%s:%s:%s"],
    cmyk = formatters["c:%s:%s:%s:%s"],
    gray = formatters["s:%s"],
    spot = formatters["p:%s:%s:%s:%s"],
}

local models = {
    [interfaces.variables.none] = unsetvalue,
    black = unsetvalue,
    bw    = unsetvalue,
    all   = 1,
    gray  = 2,
    rgb   = 3,
    cmyk  = 4,
}

local function rgbtocmyk(r,g,b) -- we could reduce
    if not r then
        return 0, 0, 0
    else
        return 1-r, 1-g, 1-b, 0
    end
end

local function cmyktorgb(c,m,y,k)
    if not c then
        return 0, 0, 0, 1
    elseif cmykrgbmode == 1 then
        local d = 1.0 - k
        return 1.0 - min(1.0,c*d+k), 1.0 - min(1.0,m*d+k), 1.0 - min(1.0,y*d+k)
    else
        return 1.0 - min(1.0,c  +k), 1.0 - min(1.0,m  +k), 1.0 - min(1.0,y  +k)
    end
end

local function rgbtogray(r,g,b)
    if not r then
        return 0
    end
    local w = colors.weightgray
    if w == true then
        return .30*r + .59*g + .11*b
    elseif not w then
        return r/3 + g/3 + b/3
    else
        return w[1]*r + w[2]*g + w[3]*b
    end
end

local function cmyktogray(c,m,y,k)
    return rgbtogray(cmyktorgb(c,m,y,k))
end

-- http://en.wikipedia.org/wiki/HSI_color_space
-- http://nl.wikipedia.org/wiki/HSV_(kleurruimte)

-- 	h /= 60;        // sector 0 to 5
-- 	i = floor( h );
-- 	f = h - i;      // factorial part of h

local function hsvtorgb(h,s,v)
    if s > 1 then
        s = 1
    elseif s < 0 then
        s = 0
    elseif s == 0 then
        return v, v, v
    end
    if v > 1 then
        s = 1
    elseif v < 0 then
        v = 0
    end
    if h < 0 then
        h = 0
    elseif h >= 360 then
        h = mod(h,360)
    end
    local hd = h / 60
    local hi = floor(hd)
    local f =  hd - hi
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    if hi == 0 then
        return v, t, p
    elseif hi == 1 then
        return q, v, p
    elseif hi == 2 then
        return p, v, t
    elseif hi == 3 then
        return p, q, v
    elseif hi == 4 then
        return t, p, v
    elseif hi == 5 then
        return v, p, q
    else
        print("error in hsv -> rgb",h,s,v)
        return 0, 0, 0
    end
end

local function rgbtohsv(r,g,b)
    local offset, maximum, other_1, other_2
    if r >= g and r >= b then
        offset, maximum, other_1, other_2 = 0, r, g, b
    elseif g >= r and g >= b then
        offset, maximum, other_1, other_2 = 2, g, b, r
    else
        offset, maximum, other_1, other_2 = 4, b, r, g
    end
    if maximum == 0 then
        return 0, 0, 0
    end
    local minimum = other_1 < other_2 and other_1 or other_2
    if maximum == minimum then
        return 0, 0, maximum
    end
    local delta = maximum - minimum
    return (offset + (other_1-other_2)/delta)*60, delta/maximum, maximum
end

local function graytorgb(s) -- unweighted
   return 1-s, 1-s, 1-s
end

local function hsvtogray(h,s,v)
    return rgb_to_gray(hsv_to_rgb(h,s,v))
end

local function graytohsv(s)
    return 0, 0, s
end

colors.rgbtocmyk  = rgbtocmyk
colors.rgbtogray  = rgbtogray
colors.cmyktorgb  = cmyktorgb
colors.cmyktogray = cmyktogray
colors.rgbtohsv   = rgbtohsv
colors.hsvtorgb   = hsvtorgb
colors.hsvtogray  = hsvtogray
colors.graytohsv  = graytohsv

-- we can share some *data by using s, rgb and cmyk hashes, but
-- normally the amount of colors is not that large; storing the
-- components costs a bit of extra runtime, but we expect to gain
-- some back because we have them at hand; the number indicates the
-- default color space

function colors.gray(s)
    return { 2, s, s, s, s, 0, 0, 0, 1-s }
end

function colors.rgb(r,g,b)
    local s = rgbtogray(r,g,b)
    local c, m, y, k = rgbtocmyk(r,g,b)
    return { 3, s, r, g, b, c, m, y, k }
end

function colors.cmyk(c,m,y,k)
    local s = cmyktogray(c,m,y,k)
    local r, g, b = cmyktorgb(c,m,y,k)
    return { 4, s, r, g, b, c, m, y, k }
end

--~ function colors.spot(parent,f,d,p)
--~     return { 5, .5, .5, .5, .5, 0, 0, 0, .5, parent, f, d, p }
--~ end

function colors.spot(parent,f,d,p)
 -- inspect(parent) inspect(f) inspect(d) inspect(p)
    if type(p) == "number" then
        local n = list[numbers.color][parent] -- hard coded ref to color number
        if n then
            local v = values[n]
            if v then
                -- the via cmyk hack is dirty, but it scales better
                local c, m, y, k = p*v[6], p*v[7], p*v[8], p*v[9]
                local r, g, b = cmyktorgb(c,m,y,k)
                local s = cmyktogray(c,m,y,k)
                return { 5, s, r, g, b, c, m, y, k, parent, f, d, p }
            end
        end
    else
        -- todo, multitone (maybe p should be a table)
        local ps = lpegmatch(p_split_comma,p)
        local ds = lpegmatch(p_split_comma,d)
        local c, m, y, k = 0, 0, 0, 0
        local done = false
        for i=1,#ps do
            local p = tonumber(ps[i])
            local d = ds[i]
            if p and d then
                local n = list[numbers.color][d] -- hard coded ref to color number
                if n then
                    local v = values[n]
                    if v then
                        c = c + p*v[6]
                        m = m + p*v[7]
                        y = y + p*v[8]
                        k = k + p*v[9]
                        done = true
                    end
                end
            end
        end
        if done then
            local r, g, b = cmyktorgb(c,m,y,k)
            local s = cmyktogray(c,m,y,k)
            local f = tonumber(f)
            return { 5, s, r, g, b, c, m, y, k, parent, f, d, p }
        end
    end
    return { 5, .5, .5, .5, .5, 0, 0, 0, .5, parent, f, d, p }
end

local function graycolor(...) graycolor = nodeinjections.graycolor return graycolor(...) end
local function rgbcolor (...) rgbcolor  = nodeinjections.rgbcolor  return rgbcolor (...) end
local function cmykcolor(...) cmykcolor = nodeinjections.cmykcolor return cmykcolor(...) end
local function spotcolor(...) spotcolor = nodeinjections.spotcolor return spotcolor(...) end

local function extender(colors,key)
    if colors.supported and key == "none" then
        local d = graycolor(0)
        colors.none = d
        return d
    end
end

local function reviver(data,n)
    if colors.supported then
        local v = values[n]
        local d
        if not v then
            local gray = graycolor(0)
            d = { gray, gray, gray, gray }
            report_attributes("unable to revive color %a",n)
        else
            local model = colors.forcedmodel(v[1])
            if model == 2 then
                local gray = graycolor(v[2])
                d = { gray, gray, gray, gray }
            elseif model == 3 then
                local gray = graycolor(v[2])
                local rgb  = rgbcolor(v[3],v[4],v[5])
                local cmyk = cmykcolor(v[6],v[7],v[8],v[9])
                d = { rgb, gray, rgb, cmyk }
            elseif model == 4 then
                local gray = graycolor(v[2])
                local rgb  = rgbcolor(v[3],v[4],v[5])
                local cmyk = cmykcolor(v[6],v[7],v[8],v[9])
                d = { cmyk, gray, rgb, cmyk }
            elseif model == 5 then
                local spot = spotcolor(v[10],v[11],v[12],v[13])
            --  d = { spot, gray, rgb, cmyk }
                d = { spot, spot, spot, spot }
            end
        end
        data[n] = d
        return d
    end
end

setmetatableindex(colors, extender)
setmetatableindex(colors.data, reviver)

function colors.filter(n)
    return concat(data[n],":",5)
end

-- unweighted (flat) gray could be another model but a bit work as we need to check:
--
--   attr-col colo-ini colo-run
--   grph-inc grph-wnd
--   lpdf-col lpdf-fmt lpdf-fld lpdf-grp
--   meta-pdf meta-pdh mlib-pps
--
-- but as we never needed it we happily delay that.

function colors.setmodel(name,weightgray)
    if weightgray == true or weightgray == v_yes then
        weightgray = true
    elseif weightgray == false or weightgray == v_no then
        weightgray = false
    else
        local r, g, b = lpegmatch(p_split_colon,weightgray)
        if r and g and b then
            weightgray = { r, g, b }
        else
            weightgray = true
        end
    end
    local default = models[name] or 1

    colors.model      = name       -- global, not useful that way
    colors.default    = default    -- global
    colors.weightgray = weightgray -- global

    -- avoid selective checking is no need for it

    local forced = colors.forced

    if forced == nil then
        -- unset
        colors.forced = default
    elseif forced == false then
        -- assumed mixed
    elseif forced ~= default then
        -- probably mixed
        colors.forced = false
    else
        -- stil the same
    end

    return default
end

function colors.register(name, colorspace, ...) -- passing 9 vars is faster (but not called that often)
    local stamp = f_colors[colorspace](...)
    local color = registered[stamp]
    if not color then
        color = #values + 1
        values[color] = colors[colorspace](...)
        registered[stamp] = color
    -- colors.reviver(color)
    end
    if name then
        list[a_color][name] = color -- not grouped, so only global colors
    end
    return registered[stamp]
end

function colors.value(id)
    return values[id]
end

attributes.colors.handler = nodes.installattributehandler {
    name        = "color",
    namespace   = colors,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.selective,
    resolver    = function() return colors.main end,
}

function colors.enable(value)
    setaction("shipouts","attributes.colors.handler",not (value == false or not colors.supported))
end

function colors.forcesupport(value) -- can move to attr-div
    colors.supported = value
    report_colors("color is %ssupported",value and "" or "not ")
    colors.enable(value)
end

function colors.toattributes(name)
    local mc = list[a_color][name]
    local mm = texgetattribute(a_selector)
    return (mm == unsetvalue and 1) or mm or 1, mc or list[a_color][1] or unsetvalue
end

-- transparencies

local a_transparency      = attributes.private('transparency')

attributes.transparencies = attributes.transparencies or { }
local transparencies      = attributes.transparencies
transparencies.registered = transparencies.registered or { }
transparencies.data       = allocate()
transparencies.values     = transparencies.values or { }
transparencies.triggering = true
transparencies.attribute  = a_transparency
transparencies.supported  = true

local registered          = transparencies.registered -- we could use a 2 dimensional table instead
local data                = transparencies.data
local values              = transparencies.values
local f_transparency      = formatters["%s:%s"]

registerstorage("attributes/transparencies/registered", registered, "attributes.transparencies.registered")
registerstorage("attributes/transparencies/values",     values,     "attributes.transparencies.values")

local function inject_transparency(...)
    inject_transparency = nodeinjections.transparency
    return inject_transparency(...)
end

local function register_transparency(...)
    register_transparency = registrations.transparency
    return register_transparency(...)
end

function transparencies.register(name,a,t,force) -- name is irrelevant here (can even be nil)
    -- Force needed here for metapost converter. We could always force
    -- but then we'd end up with transparencies resources even if we
    -- would not use transparencies (but define them only). This is
    -- somewhat messy.
    local stamp = f_transparency(a,t)
    local n = registered[stamp]
    if not n then
        n = #values + 1
        values[n] = { a, t }
        registered[stamp] = n
        if force then
            register_transparency(n,a,t)
        end
    elseif force and not data[n] then
        register_transparency(n,a,t)
    end
    if name then
        list[a_transparency][name] = n -- not grouped, so only global transparencies
    end
    return registered[stamp]
end

local function extender(transparencies,key)
    if colors.supported and key == "none" then
        local d = inject_transparency(0)
        transparencies.none = d
        return d
    end
end

local function reviver(data,n)
    if n and transparencies.supported then
        local v = values[n]
        local d
        if not v then
            d = inject_transparency(0)
        else
            d = inject_transparency(n)
            register_transparency(n,v[1],v[2])
        end
        data[n] = d
        return d
    else
        return ""
    end
end

setmetatableindex(transparencies,extender)
setmetatableindex(transparencies.data,reviver) -- register if used

-- check if there is an identity

function transparencies.value(id)
    return values[id]
end

attributes.transparencies.handler = nodes.installattributehandler {
    name        = "transparency",
    namespace   = transparencies,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.process,
}

function transparencies.enable(value) -- nil is enable
    setaction("shipouts","attributes.transparencies.handler",not (value == false or not transparencies.supported))
end

function transparencies.forcesupport(value) -- can move to attr-div
    transparencies.supported = value
    report_transparencies("transparency is %ssupported",value and "" or "not ")
    transparencies.enable(value)
end

function transparencies.toattribute(name)
    return list[a_transparency][name] or unsetvalue
end

--- colorintents: overprint / knockout

attributes.colorintents = attributes.colorintents or  { }
local colorintents      = attributes.colorintents
colorintents.data       = allocate() -- colorintents.data or { }
colorintents.attribute  = attributes.private('colorintent')

colorintents.registered = allocate {
    overprint = 1,
    knockout  = 2,
}

local data, registered = colorintents.data, colorintents.registered

local function extender(colorintents,key)
    if key == "none" then
        local d = data[2]
        colorintents.none = d
        return d
    end
end

local function reviver(data,n)
    if n == 1 then
        local d = nodeinjections.overprint() -- called once
        data[1] = d
        return d
    elseif n == 2 then
        local d = nodeinjections.knockout() -- called once
        data[2] = d
        return d
    end
end

setmetatableindex(colorintents, extender)
setmetatableindex(colorintents.data, reviver)

function colorintents.register(stamp)
    return registered[stamp] or registered.overprint
end

colorintents.handler = nodes.installattributehandler {
    name        = "colorintent",
    namespace   = colorintents,
    initializer = states.initialize,
    finalizer   = states.finalize,
    processor   = states.process,
}

function colorintents.enable()
    enableaction("shipouts","attributes.colorintents.handler")
end

-- interface

implement { name = "enablecolor",        onlyonce = true, actions = colors.enable }
implement { name = "enabletransparency", onlyonce = true, actions = transparencies.enable }
implement { name = "enablecolorintents", onlyonce = true, actions = colorintents.enable }

--------- { name = "registercolor",        actions = { colors        .register, context }, arguments = "string" }
--------- { name = "registertransparency", actions = { transparencies.register, context }, arguments = "string" }
implement { name = "registercolorintent",  actions = { colorintents  .register, context }, arguments = "string" }
