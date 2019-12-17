if not modules then modules = { } end modules ['font-fbk'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local cos, tan, rad, format = math.cos, math.tan, math.rad, string.format
local utfbyte, utfchar = utf.byte, utf.char
local next = next

--[[ldx--
<p>This is very experimental code!</p>
--ldx]]--

local trace_visualize    = false  trackers.register("fonts.composing.visualize", function(v) trace_visualize = v end)
local trace_define       = false  trackers.register("fonts.composing.define",    function(v) trace_define    = v end)

local report             = logs.reporter("fonts","combining")

local allocate           = utilities.storage.allocate

local fonts              = fonts
local handlers           = fonts.handlers
local constructors       = fonts.constructors
local helpers            = fonts.helpers

local otf                = handlers.otf
local afm                = handlers.afm
local registerotffeature = otf.features.register
local registerafmfeature = afm.features.register

local addotffeature      = otf.addfeature

local unicodecharacters  = characters.data
local unicodefallbacks   = characters.fallbacks

local vfcommands         = helpers.commands
local charcommand        = vfcommands.char
local rightcommand       = vfcommands.right
local downcommand        = vfcommands.down
local upcommand          = vfcommands.up
local push               = vfcommands.push
local pop                = vfcommands.pop

local force_combining    = false -- just for demo purposes (see mk)
local fraction           = 0.15  -- 30 units for lucida

-- todo: we also need to update the feature hashes ... i'll do that when i'm in the mood
-- and/or when i need it

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
        if trace_visualize then
            red   = vfspecials.startcolor("red")
            green = vfspecials.startcolor("green")
            blue  = vfspecials.startcolor("blue")
            black = vfspecials.stopcolor
        end
        local compose = fonts.goodies.getcompositions(tfmdata)
        if compose and trace_visualize then
            report("using compose information from goodies file")
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
                         -- local ca = charsacc.category
                         -- if ca == "mn" then
                         --     -- mark nonspacing
                         -- elseif ca == "ms" then
                         --     -- mark spacing combining
                         -- elseif ca == "me" then
                         --     -- mark enclosing
                         -- else
                            if not charsacc then -- fallback accents
                                acc = unicodefallbacks[acc]
                                charsacc = acc and characters[acc]
                            end
                            local chr_t = charcommand[chr]
                            if charsacc then
                                if trace_define then
                                    report("composed %C, base %C, accent %C",i,chr,acc)
                                end
                                local acc_t = charcommand[acc]
                                local cb = descriptions[chr].boundingbox
                                local ab = descriptions[acc].boundingbox
                                -- todo: adapt height
                                if cb and ab then
                                    local c_llx = scale*cb[1]
                                    local c_lly = scale*cb[2]
                                    local c_urx = scale*cb[3]
                                    local c_ury = scale*cb[4]
                                    local a_llx = scale*ab[1]
                                    local a_lly = scale*ab[2]
                                    local a_urx = scale*ab[3]
                                    local a_ury = scale*ab[4]
                                    local done  = false
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
                                                    if trace_define then
                                                        report("building %C from %C and %C",i,chr,acc)
                                                        report("  boundingbox:")
                                                        report("    chr: %3i %3i %3i %3i",unpack(cb))
                                                        report("    acc: %3i %3i %3i %3i",unpack(ab))
                                                        report("  anchors:")
                                                        report("    chr: %3i %3i",cx,cy)
                                                        report("    acc: %3i %3i",ax,ay)
                                                        report("  delta:")
                                                        report("    %s: %3i %3i",i_anchored,dx,dy)
                                                    end
                                                    local right = rightcommand[scale*dx]
                                                    local down  = upcommand[scale*dy]
                                                    if trace_visualize then
                                                        t.commands = {
                                                            push, right, down,
                                                            green, acc_t, black,
                                                            pop, chr_t,
                                                        }
                                                    else
                                                        t.commands = {
                                                            push, right, down,
                                                            acc_t, pop, chr_t,
                                                        }
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
                                            local right = rightcommand[dx-dd]
                                            if trace_visualize then
                                                t.commands = {
                                                    push, right, red, acc_t,
                                                    black, pop, chr_t,
                                                }
                                            else
                                                t.commands = {
                                                    push, right, acc_t, pop,
                                                    chr_t,
                                                }
                                            end
t.depth = a_ury
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
t.height = a_ury-dy
                                            local right = rightcommand[dx+dd]
                                            local down  = downcommand[dy]
                                            if trace_visualize then
                                                t.commands = {
                                                    push, right, down, green,
                                                    acc_t, black, pop, chr_t,
                                                }
                                            else
                                                t.commands = {
                                                    push, right, down, acc_t,
                                                    pop, chr_t,
                                                }
                                            end
                                        else
                                            local right = rightcommand[dx+dd]
                                            if trace_visualize then
                                                t.commands = {
                                                    push, right, blue, acc_t,
                                                    black, pop, chr_t,
                                                }
                                            else
                                                t.commands = {
                                                    push, right, acc_t, pop,
                                                    chr_t,
                                                }
                                            end
t.height = a_ury
                                        end
                                    end
                                else
                                    t.commands = {
                                        chr_t, -- else index mess
                                    }
                                end
                            else
                                if trace_define then
                                    report("%C becomes simplified %C",i,chr)
                                end
                                t.commands = {
                                    chr_t, -- else index mess
                                }
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

local specification = {
    name        = "compose",
    description = "additional composed characters",
    manipulators = {
        base = composecharacters,
        node = composecharacters,
    }
}

registerotffeature(specification)
registerafmfeature(specification)

addotffeature {
    name     = "char-ligatures",
    type     = "ligature",
    data     = characters.splits.char,
    order    = { "char-ligatures" },
    prepend  = true,
}

addotffeature {
    name     = "compat-ligatures",
    type     = "ligature",
    data     = characters.splits.compat,
    order    = { "compat-ligatures" },
    prepend  = true,
}

registerotffeature {
    name        = 'char-ligatures',
    description = 'unicode char specials to ligatures',
}

registerotffeature {
    name        = 'compat-ligatures',
    description = 'unicode compat specials to ligatures',
}

do

    -- This installs the builder into the regular virtual font builder,
    -- which only makes sense as demo.

    local vf       = handlers.vf
    local commands = vf.combiner.commands

    vf.helpers.composecharacters = composecharacters

    commands["compose.trace.enable"] = function()
        trace_visualize = true
    end

    commands["compose.trace.disable"] = function()
        trace_visualize = false
    end

    commands["compose.force.enable"] = function()
        force_combining = true
    end

    commands["compose.force.disable"] = function()
        force_combining = false
    end

    commands["compose.trace.set"] = function(g,v)
        if v[2] == nil then
            trace_visualize = true
        else
            trace_visualize = v[2]
        end
    end

    commands["compose.apply"] = function(g,v)
        composecharacters(g)
    end

end
