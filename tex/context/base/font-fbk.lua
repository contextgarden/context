if not modules then modules = { } end modules ['font-fbk'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local cos, tan, rad, format = math.cos, math.tan, math.rad, string.format
local utfbyte, utfchar = utf.byte, utf.char

--[[ldx--
<p>This is very experimental code!</p>
--ldx]]--

local trace_combining_visualize = false  trackers.register("fonts.composing.visualize", function(v) trace_combining_visualize = v end)
local trace_combining_define    = false  trackers.register("fonts.composing.define",    function(v) trace_combining_define    = v end)

trackers.register("fonts.combining",     "fonts.composing.define") -- for old times sake (and manuals)
trackers.register("fonts.combining.all", "fonts.composing.*")      -- for old times sake (and manuals)

local report_combining   = logs.reporter("fonts","combining")

local force_combining    = false -- just for demo purposes (see mk)

local allocate           = utilities.storage.allocate

local fonts              = fonts
local handlers           = fonts.handlers
local constructors       = fonts.constructors

local otf                = handlers.otf
local afm                = handlers.afm
local registerotffeature = otf.features.register
local registerafmfeature = afm.features.register

local unicodecharacters  = characters.data
local unicodefallbacks   = characters.fallbacks

local vf                 = handlers.vf
local commands           = vf.combiner.commands
local push               = vf.predefined.push
local pop                = vf.predefined.pop

local force_composed     = false
local cache              = { }  -- we could make these weak
local fraction           = 0.15 -- 30 units for lucida

local function composecharacters(tfmdata)
    -- this assumes that slot 1 is self, there will be a proper self some day
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local parameters   = tfmdata.parameters
    local properties   = tfmdata.properties
    local Xdesc        = descriptions[utfbyte("X")]
    local xdesc        = descriptions[utfbyte("x")]
    if Xdesc and xdesc then
        local scale        = parameters.factor or 1
        local deltaxheight = scale * (Xdesc.boundingbox[4] - xdesc.boundingbox[4])
        local extraxheight = fraction * deltaxheight -- maybe use compose value
        local italicfactor = parameters.italicfactor or 0
        local vfspecials   = backends.tables.vfspecials --brr
        local red, green, blue, black
        if trace_combining_visualize then
            red   = vfspecials.red
            green = vfspecials.green
            blue  = vfspecials.blue
            black = vfspecials.black
        end
        local compose = fonts.goodies.getcompositions(tfmdata)
        if compose and trace_combining_visualize then
            report_combining("using compose information from goodies file")
        end
        local done = false
        for i, c in next, unicodecharacters do -- loop over all characters ... not that efficient but a specials hash takes memory
            if force_combining or not characters[i] then
                local s = c.specials
                if s and s[1] == 'char' then
                    local chr = s[2]
                    local charschr = characters[chr]
                    if charschr then
                        local cc = c.category
                        if cc == 'll' or cc == 'lu' or cc == 'lt' then -- characters.is_letter[cc]
                            local acc = s[3]
                            local t = { }
                            for k, v in next, charschr do
                                if k ~= "commands" then
                                    t[k] = v
                                end
                            end
                            local charsacc = characters[acc]
                        --~ local ca = charsacc.category
                        --~ if ca == "mn" then
                        --~     -- mark nonspacing
                        --~ elseif ca == "ms" then
                        --~     -- mark spacing combining
                        --~ elseif ca == "me" then
                        --~     -- mark enclosing
                        --~ else
                            if not charsacc then -- fallback accents
                                acc = unicodefallbacks[acc]
                                charsacc = acc and characters[acc]
                            end
                            local chr_t = cache[chr]
                            if not chr_t then
                                chr_t = {"slot", 1, chr}
                                cache[chr] = chr_t
                            end
                            if charsacc then
                                if trace_combining_define then
                                    report_combining("composed %C, base %C, accent %C",i,chr,acc)
                                end
                                local acc_t = cache[acc]
                                if not acc_t then
                                    acc_t = {"slot", 1, acc}
                                    cache[acc] = acc_t
                                end
                                local cb = descriptions[chr].boundingbox
                                local ab = descriptions[acc].boundingbox
                                -- todo: adapt height
                                if cb and ab then
                                    local c_llx, c_lly, c_urx, c_ury = scale*cb[1], scale*cb[2], scale*cb[3], scale*cb[4]
                                    local a_llx, a_lly, a_urx, a_ury = scale*ab[1], scale*ab[2], scale*ab[3], scale*ab[4]
                                    local done = false
                                    if compose then
                                        local i_compose = compose[i]
                                        local i_anchored = i_compose and i_compose.anchored
                                        if i_anchored then
                                            local c_compose = compose[chr]
                                            local a_compose = compose[acc]
                                            local c_anchors = c_compose and c_compose.anchors
                                            local a_anchors = a_compose and a_compose.anchors
                                            if c_anchors and a_anchors then
                                                local c_anchor = c_anchors[i_anchored]
                                                local a_anchor = a_anchors[i_anchored]
                                                if c_anchor and a_anchor then
                                                    local cx = c_anchor.x or 0
                                                    local cy = c_anchor.y or 0
                                                    local ax = a_anchor.x or 0
                                                    local ay = a_anchor.y or 0
                                                    local dx = cx - ax
                                                    local dy = cy - ay
                                                    if trace_combining_define then
                                                        report_combining("building %C from %C and %C",i,chr,acc)
                                                        report_combining("  boundingbox:")
                                                        report_combining("    chr: %3i %3i %3i %3i",unpack(cb))
                                                        report_combining("    acc: %3i %3i %3i %3i",unpack(ab))
                                                        report_combining("  anchors:")
                                                        report_combining("    chr: %3i %3i",cx,cy)
                                                        report_combining("    acc: %3i %3i",ax,ay)
                                                        report_combining("  delta:")
                                                        report_combining("    %s: %3i %3i",i_anchored,dx,dy)
                                                    end
                                                    if trace_combining_visualize then
                                                        t.commands = { push, {"right", scale*dx}, {"down",-scale*dy}, green, acc_t, black, pop, chr_t }
                                                     -- t.commands = {
                                                     --     push, {"right", scale*cx}, {"down", -scale*cy}, red,   {"rule",10000,10000,10000}, pop,
                                                     --     push, {"right", scale*ax}, {"down", -scale*ay}, blue,  {"rule",10000,10000,10000}, pop,
                                                     --     push, {"right", scale*dx}, {"down", -scale*dy}, green, acc_t, black,               pop, chr_t
                                                     -- }
                                                    else
                                                        t.commands = { push, {"right", scale*dx}, {"down",-scale*dy},        acc_t,        pop, chr_t }
                                                    end
                                                    done = true
                                                end
                                            end
                                        end
                                    end
                                    if not done then
                                        -- can be sped up for scale == 1
                                        local dx = (c_urx - a_urx - a_llx + c_llx)/2
                                        local dd = (c_urx - c_llx)*italicfactor
                                        if a_ury < 0  then
                                            if trace_combining_visualize then
                                                t.commands = { push, {"right", dx-dd}, red, acc_t, black, pop, chr_t }
                                            else
                                                t.commands = { push, {"right", dx-dd},      acc_t,        pop, chr_t }
                                            end
                                        elseif c_ury > a_lly then -- messy test
                                            local dy
                                            if compose then
                                                -- experimental: we could use sx but all that testing
                                                -- takes time and code
                                                dy = compose[i]
                                                if dy then
                                                    dy = dy.dy
                                                end
                                                if not dy then
                                                    dy = compose[acc]
                                                    if dy then
                                                        dy = dy and dy.dy
                                                    end
                                                end
                                                if not dy then
                                                    dy = compose.dy
                                                end
                                                if not dy then
                                                    dy = - deltaxheight + extraxheight
                                                elseif dy > -1.5 and dy < 1.5 then
                                                    -- we assume a fraction of (percentage)
                                                    dy = - dy * deltaxheight
                                                else
                                                    -- we assume fontunits (value smaller than 2 make no sense)
                                                    dy = - dy * scale
                                                end
                                            else
                                                dy = - deltaxheight + extraxheight
                                            end
                                            if trace_combining_visualize then
                                                t.commands = { push, {"right", dx+dd}, {"down", dy}, green, acc_t, black, pop, chr_t }
                                            else
                                                t.commands = { push, {"right", dx+dd}, {"down", dy},        acc_t,        pop, chr_t }
                                            end
                                        else
                                            if trace_combining_visualize then
                                                t.commands = { push, {"right", dx+dd},               blue,  acc_t, black, pop, chr_t }
                                            else
                                                t.commands = { push, {"right", dx+dd},                      acc_t,        pop, chr_t }
                                            end
                                        end
                                    end
                                else
                                    t.commands = { chr_t } -- else index mess
                                end
                            else
                                if trace_combining_define then
                                    report_combining("%C becomes simplfied %C",i,chr)
                                end
                                t.commands = { chr_t } -- else index mess
                            end
                            done = true
                            characters[i] = t
                            local d = { }
                            for k, v in next, descriptions[chr] do
                                d[k] = v
                            end
                            descriptions[i] = d
                        end
                    end
                end
            end
        end
        if done then
            properties.virtualized = true
        end
    end
end

registerotffeature {
    name        = "compose",
    description = "additional composed characters",
    manipulators = {
        base = composecharacters,
        node = composecharacters,
    }
}

registerafmfeature {
    name        = "compose",
    description = "additional composed characters",
    manipulators = {
        base = composecharacters,
        node = composecharacters,
    }
}

vf.helpers.composecharacters = composecharacters

-- This installs the builder into the regular virtual font builder,
-- which only makes sense as demo.

commands["compose.trace.enable"] = function()
    trace_combining_visualize = true
end

commands["compose.trace.disable"] = function()
    trace_combining_visualize = false
end

commands["compose.force.enable"] = function()
    force_combining = true
end

commands["compose.force.disable"] = function()
    force_combining = false
end

commands["compose.trace.set"] = function(g,v)
    if v[2] == nil then
        trace_combining_visualize = true
    else
        trace_combining_visualize = v[2]
    end
end

commands["compose.apply"] = function(g,v)
    composecharacters(g)
end

-- vf builder

-- {'special', 'pdf: q ' .. s .. ' 0 0 '.. s .. ' 0 0 cm'},
-- {'special', 'pdf: q 1 0 0 1 ' .. -w .. ' ' .. -h .. ' cm'},
-- {'special', 'pdf: /Fm\XX\space Do'},
-- {'special', 'pdf: Q'},
-- {'special', 'pdf: Q'},

-- new and experimental

local everywhere = { ["*"] = { ["*"] = true } } -- or: { ["*"] = { "*" } }
local noflags    = { }

local char_specification = {
    type     = "ligature",
    features = everywhere,
    data     = characters.splits.char,
    order    = { "char-ligatures" },
    flags    = noflags,
    prepend  = true,
}

local compat_specification = {
    type     = "ligature",
    features = everywhere,
    data     = characters.splits.compat,
    order    = { "compat-ligatures" },
    flags    = noflags,
    prepend  = true,
}

otf.addfeature("char-ligatures",  char_specification)
otf.addfeature("compat-ligatures",compat_specification)

registerotffeature { name = 'char-ligatures',   description = 'unicode char specials to ligatures' }
registerotffeature { name = 'compat-ligatures', description = 'unicode compat specials to ligatures' }
