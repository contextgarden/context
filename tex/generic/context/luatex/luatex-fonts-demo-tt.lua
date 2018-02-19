if not modules then modules = { } end modules ['luatex-fonts-demo-tt'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- Someone asked on the list if we could fake bad typewriters. Actually there are
-- already enough examples in successive articles and it's not too complex to mess
-- with fonts. There is a nicer way to do this (with a bit of metapost) but I have
-- no time now. After all, features like this are never used in practice, so it's a
-- waste of time to code them.
--
-- Todo: force emwidth/5 for fonts > 1 ... only when requested.
--
-- \starttext
--
-- \raggedright
--
-- \definefontfeature[badtypewritera][ttgrayness=.5]
-- \definefontfeature[badtypewriterb][ttshift=.5]
-- \definefontfeature[badtypewriterc][ttthickness=2]
-- \definefontfeature[badtypewriterd][ttgrayness=.5,ttshift=.5,ttthickness=2,ttfont={dejavusansmono}]
-- \definefontfeature[badtypewritere][ttgrayness=.5,ttthickness=2,ttstep=2,ttmax=1.5]
--
-- \definefont[MyFontA][file:luatex-fonts-demo-tt.lua*badtypewritera]
-- \definefont[MyFontB][file:luatex-fonts-demo-tt.lua*badtypewriterb]
-- \definefont[MyFontC][file:luatex-fonts-demo-tt.lua*badtypewriterc]
-- \definefont[MyFontD][file:luatex-fonts-demo-tt.lua*badtypewriterd @ 10pt]
-- \definefont[MyFontE][file:luatex-fonts-demo-tt.lua*badtypewritere @ 10pt]
--
-- \MyFontA \input tufte \blank {\righttoleft  لَيْسَ لَدَيَّ أَيُّ فِكْرَةٍ عَمَّا يَعْنِيهِ هٰذَا.} \page
-- \MyFontB \input tufte \blank {\righttoleft  لَيْسَ لَدَيَّ أَيُّ فِكْرَةٍ عَمَّا يَعْنِيهِ هٰذَا.} \page
-- \MyFontC \input tufte \blank {\righttoleft  لَيْسَ لَدَيَّ أَيُّ فِكْرَةٍ عَمَّا يَعْنِيهِ هٰذَا.} \page
-- \MyFontD \input tufte \blank {\righttoleft  لَيْسَ لَدَيَّ أَيُّ فِكْرَةٍ عَمَّا يَعْنِيهِ هٰذَا.} \page
-- \MyFontE \input tufte \blank {\righttoleft  لَيْسَ لَدَيَّ أَيُّ فِكْرَةٍ عَمَّا يَعْنِيهِ هٰذَا.} \page
--
-- \stoptext

local random, sin = math.random, math.sin
local formatters = string.formatters

local now  = 0
local max  = 2 * math.pi
local step = max/20

-- The sin trick is first shown by Hartmut in 2005 when we had a few more plugs into
-- the backend. His demo was a rather colorful sheet that looked like it was crumpled.
-- There were no virtual fonts involved the, just pdf.print hooked into an always
-- applied Lua function.

function fonts.helpers.FuzzyFontStart(exheight,ttgrayness,ttthickness,ttshift,ttstep,ttmax)
    local grayness  = ttgrayness  * random(0,5)/10
    local thickness = ttthickness * random(1,2)/10
    local shift     = 0
    if ttstep > 0 then
        if now > max then
            now = 0
        else
            now = now + step * ttstep
        end
        shift = ttmax * sin(now) * exheight/5
    else
        shift = ttshift * random(-1,1) * exheight/20
    end
    -- We can optimize for one of them being zero or the default but no one will
    -- use this in production so efficiency hardly matters.
    local template = formatters["pdf:page:q %0.2F g %.2F G %0.2F w 2 Tr %.3F Ts"](
        grayness, grayness, thickness, shift
    )
    vf.special(template)
    -- will be:
 -- local template = formatters["q %0.2F g %.2F G %0.2F w 2 Tr %.3F Ts"](
 --     grayness, grayness, thickness, shift
 -- )
 -- vf.pdf("page",template)
end

function fonts.helpers.FuzzyFontStop()
    vf.special("pdf:page:Q")
    -- will be:
 -- vf.pdf("page","Q")
end

return function(specification)
    local features = specification.features.normal
    local list = features.ttfont
    if list then
        list = utilities.parsers.settings_to_array(list)
    else
        list = {
            'lmtypewriter10-regular',
            'almfixed',
        }
    end
    local f  = { }
    local id = { }
    for i=1,#list do
        f[i], id[i] = fonts.constructors.readanddefine(list[i],specification.size)
    end
    local f1 = f[1]
    if f1 then
        f1.name = specification.name -- needs checking (second time used an error)
        f1.properties.name = specification.name
        f1.properties.virtualized = true
        f1.fonts = { }
        local target = f1.characters
        local exbp = f1.parameters.exheight * number.dimenfactors.bp
        local stop = {
            "lua",
            "fonts.helpers.FuzzyFontStop()",
        }
        local start = {
            "lua",
            formatters["fonts.helpers.FuzzyFontStart(%.3F,%.2F,%.2F,%.2F,%.2F,%.2F)"](
                exbp,
                tonumber(features.ttgrayness)  or 1,
                tonumber(features.ttthickness) or 1,
                tonumber(features.ttshift)     or 1,
                tonumber(features.ttstep)      or 0,
                tonumber(features.ttmax)       or 1
            ),
        }
        for i=1,#list do
            f1.fonts[i] = { id = id[i] }
            local characters = f[i].characters
            for u, v in next, characters do
                v.commands = { start, { "slot", i, u }, stop }
                if characters ~= target then
                    target[u] = v
                end
            end
        end
    end
    return f1
end
