if not modules then modules = { } end modules ['font-ext'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type, tonumber = next, type, tonumber
local byte, find, formatters = string.byte, string.find, string.formatters
local utfchar = utf.char
local sortedhash, sortedkeys, sort = table.sortedhash, table.sortedkeys, table.sort

local context            = context
local fonts              = fonts
local utilities          = utilities

local trace_protrusion   = false  trackers.register("fonts.protrusion", function(v) trace_protrusion = v end)
local trace_expansion    = false  trackers.register("fonts.expansion",  function(v) trace_expansion  = v end)

local report_expansions  = logs.reporter("fonts","expansions")
local report_protrusions = logs.reporter("fonts","protrusions")

--[[ldx--
<p>When we implement functions that deal with features, most of them
will depend of the font format. Here we define the few that are kind
of neutral.</p>
--ldx]]--

local handlers           = fonts.handlers
local hashes             = fonts.hashes
local otf                = handlers.otf

local registerotffeature = handlers.otf.features.register
local registerafmfeature = handlers.afm.features.register

local fontdata           = hashes.identifiers
local fontproperties     = hashes.properties

local constructors       = fonts.constructors
local getprivate         = constructors.getprivate

local allocate           = utilities.storage.allocate
local settings_to_array  = utilities.parsers.settings_to_array
local settings_to_hash   = utilities.parsers.settings_to_hash
local getparameters      = utilities.parsers.getparameters
local gettexdimen        = tex.getdimen
local family_font        = node.family_font

local setmetatableindex  = table.setmetatableindex

local implement          = interfaces.implement
local variables          = interfaces.variables


local v_background       = variables.background
local v_frame            = variables.frame
local v_empty            = variables.empty
local v_none             = variables.none

-- -- -- -- -- --
-- shared
-- -- -- -- -- --

local function get_class_and_vector(tfmdata,value,where) -- "expansions"
    local g_where = tfmdata.goodies and tfmdata.goodies[where]
    local f_where = fonts[where]
    local g_classes = g_where and g_where.classes
    local f_classes = f_where and f_where.classes
    local class = (g_classes and g_classes[value]) or (f_classes and f_classes[value])
    if class then
        local class_vector = class.vector
        local g_vectors = g_where and g_where.vectors
        local f_vectors = f_where and f_where.vectors
        local vector = (g_vectors and g_vectors[class_vector]) or (f_vectors and f_vectors[class_vector])
        return class, vector
    end
end

-- -- -- -- -- --
-- expansion (hz)
-- -- -- -- -- --

local expansions   = fonts.expansions or allocate()

fonts.expansions   = expansions

local classes      = expansions.classes or allocate()
local vectors      = expansions.vectors or allocate()

expansions.classes = classes
expansions.vectors = vectors

-- beware, pdftex itself uses percentages * 10
--
-- todo: get rid of byte() here

classes.preset = { stretch = 2, shrink = 2, step = .5, factor = 1 }

classes['quality'] = {
    stretch = 2, shrink = 2, step = .5, vector = 'default', factor = 1
}

vectors['default'] = {
    [byte('A')] = 0.5, [byte('B')] = 0.7, [byte('C')] = 0.7, [byte('D')] = 0.5, [byte('E')] = 0.7,
    [byte('F')] = 0.7, [byte('G')] = 0.5, [byte('H')] = 0.7, [byte('K')] = 0.7, [byte('M')] = 0.7,
    [byte('N')] = 0.7, [byte('O')] = 0.5, [byte('P')] = 0.7, [byte('Q')] = 0.5, [byte('R')] = 0.7,
    [byte('S')] = 0.7, [byte('U')] = 0.7, [byte('W')] = 0.7, [byte('Z')] = 0.7,
    [byte('a')] = 0.7, [byte('b')] = 0.7, [byte('c')] = 0.7, [byte('d')] = 0.7, [byte('e')] = 0.7,
    [byte('g')] = 0.7, [byte('h')] = 0.7, [byte('k')] = 0.7, [byte('m')] = 0.7, [byte('n')] = 0.7,
    [byte('o')] = 0.7, [byte('p')] = 0.7, [byte('q')] = 0.7, [byte('s')] = 0.7, [byte('u')] = 0.7,
    [byte('w')] = 0.7, [byte('z')] = 0.7,
    [byte('2')] = 0.7, [byte('3')] = 0.7, [byte('6')] = 0.7, [byte('8')] = 0.7, [byte('9')] = 0.7,
}

vectors['quality'] = vectors['default'] -- metatable ?

local function initializeexpansion(tfmdata,value)
    if value then
        local class, vector = get_class_and_vector(tfmdata,value,"expansions")
        if class then
            if vector then
                local stretch = class.stretch or 0
                local shrink  = class.shrink  or 0
                local step    = class.step    or 0
                local factor  = class.factor  or 1
                if trace_expansion then
                    report_expansions("setting class %a, vector %a, factor %a, stretch %a, shrink %a, step %a",
                        value,class.vector,factor,stretch,shrink,step)
                end
                tfmdata.parameters.expansion = {
                    stretch = 10 * stretch,
                    shrink  = 10 * shrink,
                    step    = 10 * step,
                    factor  = factor,
                }
                local data = characters and characters.data
                for i, chr in next, tfmdata.characters do
                    local v = vector[i]
                    if data and not v then -- we could move the data test outside (needed for plain)
                        local d = data[i]
                        if d then
                            local s = d.shcode
                            if not s then
                                -- sorry
                            elseif type(s) == "table" then
                                v = ((vector[s[1]] or 0) + (vector[s[#s]] or 0)) / 2
                            else
                                v = vector[s] or 0
                            end
                        end
                    end
                    if v and v ~= 0 then
                        chr.expansion_factor = v*factor
                    else -- can be option
                        chr.expansion_factor = factor
                    end
                end
            elseif trace_expansion then
                report_expansions("unknown vector %a in class %a",class.vector,value)
            end
        elseif trace_expansion then
            report_expansions("unknown class %a",value)
        end
    end
end

local expansion_specification = {
    name        = "expansion",
    description = "apply hz optimization",
    initializers = {
        base = initializeexpansion,
        node = initializeexpansion,
    }
}

registerotffeature(expansion_specification)
registerafmfeature(expansion_specification)

fonts.goodies.register("expansions",  function(...) return fonts.goodies.report("expansions", trace_expansion, ...) end)

implement {
    name      = "setupfontexpansion",
    arguments = { "string", "string" },
    actions   = function(class,settings) getparameters(classes,class,'preset',settings) end
}

-- -- -- -- -- --
-- protrusion
-- -- -- -- -- --

fonts.protrusions   = allocate()
local protrusions   = fonts.protrusions

protrusions.classes = allocate()
protrusions.vectors = allocate()

local classes       = protrusions.classes
local vectors       = protrusions.vectors

-- the values need to be revisioned

classes.preset = { factor = 1, left = 1, right = 1 }

classes['pure'] = {
    vector = 'pure', factor = 1
}
classes['punctuation'] = {
    vector = 'punctuation', factor = 1
}
classes['alpha'] = {
    vector = 'alpha', factor = 1
}
classes['quality'] = {
    vector = 'quality', factor = 1
}

vectors['pure'] = {

    [0x002C] = { 0, 1    }, -- comma
    [0x002E] = { 0, 1    }, -- period
    [0x003A] = { 0, 1    }, -- colon
    [0x003B] = { 0, 1    }, -- semicolon
    [0x002D] = { 0, 1    }, -- hyphen
    [0x00AD] = { 0, 1    }, -- also hyphen
    [0x2013] = { 0, 0.50 }, -- endash
    [0x2014] = { 0, 0.33 }, -- emdash
    [0x3001] = { 0, 1    }, -- ideographic comma      、
    [0x3002] = { 0, 1    }, -- ideographic full stop  。
    [0x060C] = { 0, 1    }, -- arabic comma           ،
    [0x061B] = { 0, 1    }, -- arabic semicolon       ؛
    [0x06D4] = { 0, 1    }, -- arabic full stop       ۔

}

vectors['punctuation'] = {

    [0x003F] = { 0,    0.20 }, -- ?
    [0x00BF] = { 0,    0.20 }, -- ¿
    [0x0021] = { 0,    0.20 }, -- !
    [0x00A1] = { 0,    0.20 }, -- ¡
    [0x0028] = { 0.05, 0    }, -- (
    [0x0029] = { 0,    0.05 }, -- )
    [0x005B] = { 0.05, 0    }, -- [
    [0x005D] = { 0,    0.05 }, -- ]
    [0x002C] = { 0,    0.70 }, -- comma
    [0x002E] = { 0,    0.70 }, -- period
    [0x003A] = { 0,    0.50 }, -- colon
    [0x003B] = { 0,    0.50 }, -- semicolon
    [0x002D] = { 0,    0.70 }, -- hyphen
    [0x00AD] = { 0,    0.70 }, -- also hyphen
    [0x2013] = { 0,    0.30 }, -- endash
    [0x2014] = { 0,    0.20 }, -- emdash
    [0x060C] = { 0,    0.70 }, -- arabic comma
    [0x061B] = { 0,    0.50 }, -- arabic semicolon
    [0x06D4] = { 0,    0.70 }, -- arabic full stop
    [0x061F] = { 0,    0.20 }, -- ؟

    -- todo: left and right quotes: .5 double, .7 single

    [0x2039] = { 0.70, 0.70 }, -- left single guillemet   ‹
    [0x203A] = { 0.70, 0.70 }, -- right single guillemet  ›
    [0x00AB] = { 0.50, 0.50 }, -- left guillemet          «
    [0x00BB] = { 0.50, 0.50 }, -- right guillemet         »

    [0x2018] = { 0.70, 0.70 }, -- left single quotation mark             ‘
    [0x2019] = { 0,    0.70 }, -- right single quotation mark            ’
    [0x201A] = { 0.70, 0    }, -- single low-9 quotation mark            ,
    [0x201B] = { 0.70, 0    }, -- single high-reversed-9 quotation mark  ‛
    [0x201C] = { 0.50, 0.50 }, -- left double quotation mark             “
    [0x201D] = { 0,    0.50 }, -- right double quotation mark            ”
    [0x201E] = { 0.50, 0    }, -- double low-9 quotation mark            „
    [0x201F] = { 0.50, 0    }, -- double high-reversed-9 quotation mark  ‟

}

vectors['alpha'] = {

    [byte("A")] = { .05, .05 },
    [byte("F")] = {   0, .05 },
    [byte("J")] = { .05,   0 },
    [byte("K")] = {   0, .05 },
    [byte("L")] = {   0, .05 },
    [byte("T")] = { .05, .05 },
    [byte("V")] = { .05, .05 },
    [byte("W")] = { .05, .05 },
    [byte("X")] = { .05, .05 },
    [byte("Y")] = { .05, .05 },

    [byte("k")] = {   0, .05 },
    [byte("r")] = {   0, .05 },
    [byte("t")] = {   0, .05 },
    [byte("v")] = { .05, .05 },
    [byte("w")] = { .05, .05 },
    [byte("x")] = { .05, .05 },
    [byte("y")] = { .05, .05 },

}

vectors['quality'] = table.merged(
    vectors['punctuation'],
    vectors['alpha']
)

-- As this is experimental code, users should not depend on it. The implications are still
-- discussed on the ConTeXt Dev List and we're not sure yet what exactly the spec is (the
-- next code is tested with a gyre font patched by / fea file made by Khaled Hosny). The
-- double trick should not be needed it proper hanging punctuation is used in which case
-- values < 1 can be used.
--
-- preferred (in context, usine vectors):
--
-- \definefontfeature[whatever][default][mode=node,protrusion=quality]
--
-- using lfbd and rtbd, with possibibility to enable only one side :
--
-- \definefontfeature[whocares][default][mode=node,protrusion=yes,  opbd=yes,script=latn]
-- \definefontfeature[whocares][default][mode=node,protrusion=right,opbd=yes,script=latn]
--
-- idem, using multiplier
--
-- \definefontfeature[whocares][default][mode=node,protrusion=2,opbd=yes,script=latn]
-- \definefontfeature[whocares][default][mode=node,protrusion=double,opbd=yes,script=latn]
--
-- idem, using named feature file (less frozen):
--
-- \definefontfeature[whocares][default][mode=node,protrusion=2,opbd=yes,script=latn,featurefile=texgyrepagella-regularxx.fea]

classes['double'] = { -- for testing opbd
    factor = 2, left = 1, right = 1,
}

local function map_opbd_onto_protrusion(tfmdata,value,opbd)
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local properties   = tfmdata.properties
    local resources    = tfmdata.resources
    local rawdata      = tfmdata.shared.rawdata
    local lookuphash   = rawdata.lookuphash
    local lookuptags   = resources.lookuptags
    local script       = properties.script
    local language     = properties.language
    local done, factor, left, right = false, 1, 1, 1
    local class = classes[value]
    if class then
        factor = class.factor or 1
        left   = class.left   or 1
        right  = class.right  or 1
    else
        factor = tonumber(value) or 1
    end
    if opbd ~= "right" then
        local validlookups, lookuplist = otf.collectlookups(rawdata,"lfbd",script,language)
        if validlookups then
            for i=1,#lookuplist do
                local lookup = lookuplist[i]
                local steps  = lookup.steps
                if steps then
                    if trace_protrusion then
                        report_protrusions("setting left using lfbd")
                    end
                    for i=1,#steps do
                        local step     = steps[i]
                        local coverage = step.coverage
                        if coverage then
                            for k, v in next, coverage do
                            --  local p = - v[3] / descriptions[k].width-- or 1 ~= 0 too but the same
                                local p = - (v[1] / 1000) * factor * left
                                characters[k].left_protruding = p
                                if trace_protrusion then
                                    report_protrusions("lfbd -> %C -> %p",k,p)
                                end
                            end
                        end
                    end
                    done = true
                end
            end
        end
    end
    if opbd ~= "left" then
        local validlookups, lookuplist = otf.collectlookups(rawdata,"rtbd",script,language)
        if validlookups then
            for i=1,#lookuplist do
                local lookup = lookuplist[i]
                local steps  = lookup.steps
                if steps then
                    if trace_protrusion then
                        report_protrusions("setting right using rtbd")
                    end
                    for i=1,#steps do
                        local step     = steps[i]
                        local coverage = step.coverage
                        if coverage then
                            for k, v in next, coverage do
                            --  local p = v[3] / descriptions[k].width -- or 3
                                local p = (v[1] / 1000) * factor * right
                                characters[k].right_protruding = p
                                if trace_protrusion then
                                    report_protrusions("rtbd -> %C -> %p",k,p)
                                end
                            end
                        end
                    end
                end
                done = true
            end
        end
    end
end

-- The opbd test is just there because it was discussed on the context development list. However,
-- the mentioned fxlbi.otf font only has some kerns for digits. So, consider this feature not supported
-- till we have a proper test font.

local function initializeprotrusion(tfmdata,value)
    if value then
        local opbd = tfmdata.shared.features.opbd
        if opbd then
            -- possible values: left right both yes no (experimental)
            map_opbd_onto_protrusion(tfmdata,value,opbd)
        else
            local class, vector = get_class_and_vector(tfmdata,value,"protrusions")
            if class then
                if vector then
                    local factor = class.factor or 1
                    local left   = class.left   or 1
                    local right  = class.right  or 1
                    if trace_protrusion then
                        report_protrusions("setting class %a, vector %a, factor %a, left %a, right %a",
                            value,class.vector,factor,left,right)
                    end
                    local data = characters.data
                    local emwidth = tfmdata.parameters.quad
                    tfmdata.parameters.protrusion = {
                        factor = factor,
                        left   = left,
                        right  = right,
                    }
                    for i, chr in next, tfmdata.characters do
                        local v, pl, pr = vector[i], nil, nil
                        if v then
                            pl, pr = v[1], v[2]
                        else
                            local d = data[i]
                            if d then
                                local s = d.shcode
                                if not s then
                                    -- sorry
                                elseif type(s) == "table" then
                                    local vl, vr = vector[s[1]], vector[s[#s]]
                                    if vl then pl = vl[1] end
                                    if vr then pr = vr[2] end
                                else
                                    v = vector[s]
                                    if v then
                                        pl, pr = v[1], v[2]
                                    end
                                end
                            end
                        end
                        if pl and pl ~= 0 then
                            chr.left_protruding  = left *pl*factor
                        end
                        if pr and pr ~= 0 then
                            chr.right_protruding = right*pr*factor
                        end
                    end
                elseif trace_protrusion then
                    report_protrusions("unknown vector %a in class %a",class.vector,value)
                end
            elseif trace_protrusion then
                report_protrusions("unknown class %a",value)
            end
        end
    end
end

local protrusion_specification = {
    name         = "protrusion",
    description  = "l/r margin character protrusion",
    initializers = {
        base = initializeprotrusion,
        node = initializeprotrusion,
    }
}

registerotffeature(protrusion_specification)
registerafmfeature(protrusion_specification)

fonts.goodies.register("protrusions", function(...) return fonts.goodies.report("protrusions", trace_protrusion, ...) end)

implement {
    name      = "setupfontprotrusion",
    arguments = { "string", "string" },
    actions   = function(class,settings) getparameters(classes,class,'preset',settings) end
}

-- -- --

local function initializenostackmath(tfmdata,value)
    tfmdata.properties.nostackmath = value and true
end

registerotffeature {
    name        = "nostackmath",
    description = "disable math stacking mechanism",
    initializers = {
        base = initializenostackmath,
        node = initializenostackmath,
    }
}

local function initializerealdimensions(tfmdata,value)
    tfmdata.properties.realdimensions = value and true
end

registerotffeature {
    name        = "realdimensions",
    description = "accept negative dimenions",
    initializers = {
        base = initializerealdimensions,
        node = initializerealdimensions,
    }
}

local function initializeitlc(tfmdata,value) -- hm, always value
    if value then
        -- the magic 40 and it formula come from Dohyun Kim but we might need another guess
        local parameters = tfmdata.parameters
        local italicangle = parameters.italicangle
        if italicangle and italicangle ~= 0 then
            local properties = tfmdata.properties
            local factor = tonumber(value) or 1
            properties.hasitalics = true
            properties.autoitalicamount = factor * (parameters.uwidth or 40)/2
        end
    end
end

local italic_specification = {
    name         = "itlc",
    description  = "italic correction",
    initializers = {
        base = initializeitlc,
        node = initializeitlc,
    }
}

registerotffeature(italic_specification)
registerafmfeature(italic_specification)

local function initializetextitalics(tfmdata,value) -- yes no delay
    tfmdata.properties.textitalics = toboolean(value)
end

local textitalics_specification = {
    name         = "textitalics",
    description  = "use alternative text italic correction",
    initializers = {
        base = initializetextitalics,
        node = initializetextitalics,
    }
}

registerotffeature(textitalics_specification)
registerafmfeature(textitalics_specification)

-- local function initializemathitalics(tfmdata,value) -- yes no delay
--     tfmdata.properties.mathitalics = toboolean(value)
-- end
--
-- local mathitalics_specification = {
--     name         = "mathitalics",
--     description  = "use alternative math italic correction",
--     initializers = {
--         base = initializemathitalics,
--         node = initializemathitalics,
--     }
-- }

-- registerotffeature(mathitalics_specification)
-- registerafmfeature(mathitalics_specification)

-- slanting

local function initializeslant(tfmdata,value)
    value = tonumber(value)
    if not value then
        value =  0
    elseif value >  1 then
        value =  1
    elseif value < -1 then
        value = -1
    end
    tfmdata.parameters.slantfactor = value
end

local slant_specification = {
    name        = "slant",
    description = "slant glyphs",
    initializers = {
        base = initializeslant,
        node = initializeslant,
    }
}

registerotffeature(slant_specification)
registerafmfeature(slant_specification)

local function initializeextend(tfmdata,value)
    value = tonumber(value)
    if not value then
        value =  0
    elseif value >  10 then
        value =  10
    elseif value < -10 then
        value = -10
    end
    tfmdata.parameters.extendfactor = value
end

local extend_specification = {
    name        = "extend",
    description = "scale glyphs horizontally",
    initializers = {
        base = initializeextend,
        node = initializeextend,
    }
}

registerotffeature(extend_specification)
registerafmfeature(extend_specification)

-- For Wolfgang Schuster:
--
-- \definefontfeature[thisway][default][script=hang,language=zhs,dimensions={2,2,2}]
-- \definedfont[file:kozminpr6nregular*thisway]
--
-- For the moment we don't mess with the descriptions.

local function manipulatedimensions(tfmdata,key,value)
    if type(value) == "string" and value ~= "" then
        local characters = tfmdata.characters
        local parameters = tfmdata.parameters
        local emwidth    = parameters.quad
        local exheight   = parameters.xheight
        local width      = 0
        local height     = 0
        local depth      = 0
        if value == "strut" then
            height = gettexdimen("strutht")
            depth  = gettexdimen("strutdp")
        else
            local spec = settings_to_array(value)
            width  = (spec[1] or 0) * emwidth
            height = (spec[2] or 0) * exheight
            depth  = (spec[3] or 0) * exheight
        end
        if width > 0 then
            local additions = { }
            for unicode, old_c in next, characters do
                local oldwidth = old_c.width
                if oldwidth ~= width then
                    -- Defining the tables in one step is more efficient
                    -- than adding fields later.
                    local private = getprivate(tfmdata)
                    local new_c
                    local commands = {
                        { "right", (width - oldwidth) / 2 },
                        { "slot", 1, private },
                     -- { "slot", 0, private },
                    }
                    if height > 0 then
                        if depth > 0 then
                            new_c = {
                                width    = width,
                                height   = height,
                                depth    = depth,
                                commands = commands,
                            }
                        else
                            new_c = {
                                width    = width,
                                height   = height,
                                commands = commands,
                            }
                        end
                    else
                        if depth > 0 then
                            new_c = {
                                width    = width,
                                depth    = depth,
                                commands = commands,
                            }
                        else
                            new_c = {
                                width    = width,
                                commands = commands,
                            }
                        end
                    end
                    setmetatableindex(new_c,old_c)
                    characters[unicode] = new_c
                    additions[private]  = old_c
                end
            end
            for k, v in next, additions do
                characters[k] = v
            end
        elseif height > 0 and depth > 0 then
            for unicode, old_c in next, characters do
                old_c.height = height
                old_c.depth  = depth
            end
        elseif height > 0 then
            for unicode, old_c in next, characters do
                old_c.height = height
            end
        elseif depth > 0 then
            for unicode, old_c in next, characters do
                old_c.depth = depth
            end
        end
    end
end

local dimensions_specification = {
    name        = "dimensions",
    description = "force dimensions",
    manipulators = {
        base = manipulatedimensions,
        node = manipulatedimensions,
    }
}

registerotffeature(dimensions_specification)
registerafmfeature(dimensions_specification)

-- for zhichu chen (see mailing list archive): we might add a few more variants
-- in due time
--
-- \definefontfeature[boxed][default][boundingbox=yes] % paleblue
--
-- maybe:
--
-- \definecolor[DummyColor][s=.75,t=.5,a=1] {\DummyColor test} \nopdfcompression
--
-- local gray  = { "pdf", "origin", "/Tr1 gs .75 g" }
-- local black = { "pdf", "origin", "/Tr0 gs 0 g" }


-- boundingbox={yes|background|frame|empty|<color>}

local push  = { "push" }
local pop   = { "pop" }

----- gray  = { "pdf", "origin", ".75 g .75 G" }
----- black = { "pdf", "origin", "0 g 0 G" }
----- gray  = { "pdf", ".75 g" }
----- black = { "pdf", "0 g"   }

-- local bp = number.dimenfactors.bp
--
-- local downcache = setmetatableindex(function(t,d)
--     local v = { "down", d }
--     t[d] = v
--     return v
-- end)
--
-- local backcache = setmetatableindex(function(t,h)
--     local h = h * bp
--     local v = setmetatableindex(function(t,w)
--      -- local v = { "rule", h, w }
--         local v = { "pdf", "origin", formatters["0 0 %.6F %.6F re F"](w*bp,h) }
--         t[w] = v
--         return v
--     end)
--     t[h] = v
--     return v
-- end)
--
-- local forecache = setmetatableindex(function(t,h)
--     local h = h * bp
--     local v = setmetatableindex(function(t,w)
--         local v = { "pdf", "origin", formatters["%.6F w 0 0 %.6F %.6F re S"](0.25*65536*bp,w*bp,h) }
--         t[w] = v
--         return v
--     end)
--     t[h] = v
--     return v
-- end)

local bp = number.dimenfactors.bp
local r  = 16384 * bp -- 65536 // 4

local backcache = setmetatableindex(function(t,h)
    local h = h * bp
    local v = setmetatableindex(function(t,d)
        local d = d * bp
        local v = setmetatableindex(function(t,w)
            local v = { "pdf", "origin", formatters["%.6F w 0 %.6F %.6F %.6F re f"](r,-d,w*bp,h+d) }
            t[w] = v
            return v
        end)
        t[d] = v
        return v
    end)
    t[h] = v
    return v
end)

local forecache = setmetatableindex(function(t,h)
    local h = h * bp
    local v = setmetatableindex(function(t,d)
        local d = d * bp
        local v = setmetatableindex(function(t,w)
            -- the frame goes through the boundingbox
         -- local v = { "pdf", "origin", formatters["[] 0 d 0 J %.6F w %.6F %.6F %.6F re S"](r,-d,w*bp,h+d) }
            local v = { "pdf", "origin", formatters["[] 0 d 0 J %.6F w %.6F %.6F %.6F %.6F re S"](r,r/2,-d+r/2,w*bp-r,h+d-r) }
            t[w] = v
            return v
        end)
        t[d] = v
        return v
    end)
    t[h] = v
    return v
end)

local startcolor = nil
local stopcolor  = nil

local function showboundingbox(tfmdata,key,value)
    if value then
        if not backcolors then
            local vfspecials = backends.pdf.tables.vfspecials
            startcolor = vfspecials.startcolor
            stopcolor  = vfspecials.stopcolor
        end
        local characters = tfmdata.characters
        local additions  = { }
        local rulecache  = backcache
        local showchar   = true
        local color      = "palegray"
        if type(value) == "string" then
            value = settings_to_array(value)
            for i=1,#value do
                local v = value[i]
                if v == v_frame then
                    rulecache = forecache
                elseif v == v_background then
                    rulecache = backcache
                elseif v == v_empty then
                    showchar = false
                elseif v == v_none then
                    color = nil
                else
                    color = v
                end
            end
        end
        local gray  = color and startcolor(color) or nil
        local black = gray and stopcolor or nil
        for unicode, old_c in next, characters do
            local private = getprivate(tfmdata)
            local width   = old_c.width  or 0
            local height  = old_c.height or 0
            local depth   = old_c.depth  or 0
            local char    = showchar and { "slot", 1, private } or nil -- { "slot", 0, private }
         -- local new_c
         -- if depth == 0 then
         --     new_c = {
         --         width    = width,
         --         height   = height,
         --         commands = {
         --             push,
         --             gray,
         --             rulecache[height][width],
         --             black,
         --             pop,
         --             char,
         --         }
         --     }
         -- else
         --     new_c = {
         --         width    = width,
         --         height   = height,
         --         depth    = depth,
         --         commands = {
         --             push,
         --             downcache[depth],
         --             gray,
         --             rulecache[height+depth][width],
         --             black,
         --             pop,
         --             char,
         --         }
         --     }
         -- end
            local rule  = rulecache[height][depth][width]
            local new_c = {
                width    = width,
                height   = height,
                depth    = depth,
                commands = gray and {
                 -- push,
                    gray,
                    rule,
                    black,
                 -- pop,
                    char,
                } or {
                    rule,
                    char,
                }
            }
            setmetatableindex(new_c,old_c)
            characters[unicode] = new_c
            additions[private] = old_c
        end
        for k, v in next, additions do
            characters[k] = v
        end
    end
end

registerotffeature {
    name        = "boundingbox",
    description = "show boundingbox",
    manipulators = {
        base = showboundingbox,
        node = showboundingbox,
    }
}

-- -- for notosans but not general
--
-- do
--
--     local v_local = interfaces and interfaces.variables and interfaces.variables["local"] or "local"
--
--     local utfbyte = utf.byte
--
--     local function initialize(tfmdata,key,value)
--         local characters = tfmdata.characters
--         local parameters = tfmdata.parameters
--         local oldchar    = 32
--         local newchar    = 32
--         if value == "locl" or value == v_local then
--             newchar = fonts.handlers.otf.getsubstitution(tfmdata,oldchar,"locl",true) or oldchar
--         elseif value == true then
--             -- use normal space
--         elseif value then
--             newchar = utfbyte(value)
--         else
--             return
--         end
--         local newchar  = newchar and characters[newchar]
--         local newspace = newchar and newchar.width
--         if newspace > 0 then
--             parameters.space         = newspace
--             parameters.space_stretch = newspace/2
--             parameters.space_shrink  = newspace/3
--             parameters.extra_space   = parameters.space_shrink
--         end
--     end
--
--     registerotffeature {
--         name        = 'space', -- true|false|locl|character
--         description = 'space settings',
--         manipulators = {
--             base = initialize,
--             node = initialize,
--         }
--     }
--
-- end

-- -- historic stuff, move from font-ota (handled differently, typo-rep)
--
-- local delete_node = nodes.delete
-- local fontdata    = fonts.hashes.identifiers
--
-- local nodecodes  = nodes.nodecodes
-- local glyph_code = nodecodes.glyph
--
-- local strippables = allocate()
-- fonts.strippables = strippables
--
-- strippables.joiners = table.tohash {
--     0x200C, -- zwnj
--     0x200D, -- zwj
-- }
--
-- strippables.all = table.tohash {
--     0x000AD, 0x017B4, 0x017B5, 0x0200B, 0x0200C, 0x0200D, 0x0200E, 0x0200F, 0x0202A, 0x0202B,
--     0x0202C, 0x0202D, 0x0202E, 0x02060, 0x02061, 0x02062, 0x02063, 0x0206A, 0x0206B, 0x0206C,
--     0x0206D, 0x0206E, 0x0206F, 0x0FEFF, 0x1D173, 0x1D174, 0x1D175, 0x1D176, 0x1D177, 0x1D178,
--     0x1D179, 0x1D17A, 0xE0001, 0xE0020, 0xE0021, 0xE0022, 0xE0023, 0xE0024, 0xE0025, 0xE0026,
--     0xE0027, 0xE0028, 0xE0029, 0xE002A, 0xE002B, 0xE002C, 0xE002D, 0xE002E, 0xE002F, 0xE0030,
--     0xE0031, 0xE0032, 0xE0033, 0xE0034, 0xE0035, 0xE0036, 0xE0037, 0xE0038, 0xE0039, 0xE003A,
--     0xE003B, 0xE003C, 0xE003D, 0xE003E, 0xE003F, 0xE0040, 0xE0041, 0xE0042, 0xE0043, 0xE0044,
--     0xE0045, 0xE0046, 0xE0047, 0xE0048, 0xE0049, 0xE004A, 0xE004B, 0xE004C, 0xE004D, 0xE004E,
--     0xE004F, 0xE0050, 0xE0051, 0xE0052, 0xE0053, 0xE0054, 0xE0055, 0xE0056, 0xE0057, 0xE0058,
--     0xE0059, 0xE005A, 0xE005B, 0xE005C, 0xE005D, 0xE005E, 0xE005F, 0xE0060, 0xE0061, 0xE0062,
--     0xE0063, 0xE0064, 0xE0065, 0xE0066, 0xE0067, 0xE0068, 0xE0069, 0xE006A, 0xE006B, 0xE006C,
--     0xE006D, 0xE006E, 0xE006F, 0xE0070, 0xE0071, 0xE0072, 0xE0073, 0xE0074, 0xE0075, 0xE0076,
--     0xE0077, 0xE0078, 0xE0079, 0xE007A, 0xE007B, 0xE007C, 0xE007D, 0xE007E, 0xE007F,
-- }
--
-- strippables[true] = strippables.joiners
--
-- local function processformatters(head,font)
--     local subset = fontdata[font].shared.features.formatters
--     local vector = subset and strippables[subset]
--     if vector then
--         local current, done = head, false
--         while current do
--             if current.id == glyph_code and current.subtype<256 and current.font == font then
--                 local char = current.char
--                 if vector[char] then
--                     head, current = delete_node(head,current)
--                     done = true
--                 else
--                     current = current.next
--                 end
--             else
--                 current = current.next
--             end
--         end
--         return head, done
--     else
--         return head, false
--     end
-- end
--
-- registerotffeature {
--     name        = "formatters",
--     description = "hide formatting characters",
--     methods = {
--         base = processformatters,
--         node = processformatters,
--     }
-- }

-- not to be used! experimental code, only needed when testing

local is_letter = characters.is_letter
local always    = true

local function collapseitalics(tfmdata,key,value)
    local threshold = value == true and 100 or tonumber(value)
    if threshold and threshold > 0 then
        if threshold > 100 then
            threshold = 100
        end
        for unicode, data in next, tfmdata.characters do
            if always or is_letter[unicode] or is_letter[data.unicode] then
                local italic = data.italic
                if italic and italic ~= 0 then
                    local width = data.width
                    if width and width ~= 0 then
                        local delta = threshold * italic / 100
                        data.width  = width  + delta
                        data.italic = italic - delta
                    end
                end
            end
        end
    end
end

local dimensions_specification = {
    name        = "collapseitalics",
    description = "collapse italics",
    manipulators = {
        base = collapseitalics,
        node = collapseitalics,
    }
}

registerotffeature(dimensions_specification)
registerafmfeature(dimensions_specification)

-- a handy helper (might change or be moved to another namespace)

local nodepool       = nodes.pool
local new_glyph      = nodepool.glyph

local helpers        = fonts.helpers
local currentfont    = font.current

local currentprivate = 0xE000
local maximumprivate = 0xEFFF

-- if we run out of space we can think of another range but by sharing we can
-- use these privates for mechanisms like alignments-on-character and such

local sharedprivates = setmetatableindex(function(t,k)
    v = currentprivate
    if currentprivate < maximumprivate then
        currentprivate = currentprivate + 1
    else
        -- reuse last slot, todo: warning
    end
    t[k] = v
    return v
end)

function helpers.addprivate(tfmdata,name,characterdata)
    local properties = tfmdata.properties
    local characters = tfmdata.characters
    local privates   = properties.privates
    if not privates then
        privates = { }
        properties.privates = privates
    end
    if not name then
        name = formatters["anonymous_private_0x%05X"](currentprivate)
    end
    local usedprivate = sharedprivates[name]
    privates[name] = usedprivate
    characters[usedprivate] = characterdata
    return usedprivate
end

local function getprivateslot(id,name)
    if not name then
        name = id
        id   = currentfont()
    end
    local properties = fontproperties[id]
    local privates   = properties and properties.privates
    return privates and privates[name]
end

local function getprivatenode(tfmdata,name)
    if type(tfmdata) == "number" then
        tfmdata = fontdata[tfmdata]
    end
    local properties = tfmdata.properties
    local font = properties.id
    local slot = getprivateslot(font,name)
    if slot then
        -- todo: set current attribibutes
        local char   = tfmdata.characters[slot]
        local tonode = char.tonode
        if tonode then
            return tonode(font,char)
        else
            return new_glyph(font,slot)
        end
    end
end

local function getprivatecharornode(tfmdata,name)
    if type(tfmdata) == "number" then
        tfmdata = fontdata[tfmdata]
    end
    local properties = tfmdata.properties
    local font = properties.id
    local slot = getprivateslot(font,name)
    if slot then
        -- todo: set current attribibutes
        local char   = tfmdata.characters[slot]
        local tonode = char.tonode
        if tonode then
            return "node", tonode(tfmdata,char)
        else
            return "char", slot
        end
    end
end

helpers.getprivateslot       = getprivateslot
helpers.getprivatenode       = getprivatenode
helpers.getprivatecharornode = getprivatecharornode

function helpers.getprivates(tfmdata)
    if type(tfmdata) == "number" then
        tfmdata = fontdata[tfmdata]
    end
    local properties = tfmdata.properties
    return properties and properties.privates
end

function helpers.hasprivate(tfmdata,name)
    if type(tfmdata) == "number" then
        tfmdata = fontdata[tfmdata]
    end
    local properties = tfmdata.properties
    local privates = properties and properties.privates
    return privates and privates[name] or false
end

-- relatively new:

do

    local extraprivates = { }

    function fonts.helpers.addextraprivate(name,f)
        extraprivates[#extraprivates+1] = { name, f }
    end

    local function addextraprivates(tfmdata)
        for i=1,#extraprivates do
            local e = extraprivates[i]
            local c = e[2](tfmdata)
            if c then
                fonts.helpers.addprivate(tfmdata, e[1], c)
            end
        end
    end

    constructors.newfeatures.otf.register {
        name        = "extraprivates",
        description = "extra privates",
        default     = true,
        manipulators = {
            base = addextraprivates,
            node = addextraprivates,
        }
    }

end

implement {
    name      = "getprivatechar",
    arguments = "string",
    actions   = function(name)
        local p = getprivateslot(name)
        if p then
            context(utfchar(p))
        end
    end
}

implement {
    name      = "getprivatemathchar",
    arguments = "string",
    actions   = function(name)
        local p = getprivateslot(family_font(0),name)
        if p then
            context(utfchar(p))
        end
    end
}

implement {
    name      = "getprivateslot",
    arguments = "string",
    actions   = function(name)
        local p = getprivateslot(name)
        if p then
            context(p)
        end
    end
}

-- requested for latex but not supported unless really needed in context:
--
-- registerotffeature {
--     name         = "ignoremathconstants",
--     description  = "ignore math constants table",
--     initializers = {
--         base = function(tfmdata,value)
--             if value then
--                 tfmdata.mathparameters = nil
--             end
--         end
--     }
-- }

-- tfmdata.properties.mathnolimitsmode = tonumber(value) or 0

do

    local splitter  = lpeg.splitat(",",tonumber)
    local lpegmatch = lpeg.match

    local function initialize(tfmdata,value)
        local mathparameters = tfmdata.mathparameters
        if mathparameters then
            local sup, sub
            if type(value) == "string" then
                sup, sub = lpegmatch(splitter,value)
                if not sup then
                    sub, sup = 0, 0
                elseif not sub then
                    sub, sup = sup, 0
                end
            elseif type(value) == "number" then
                sup, sub = 0, value
            end
            mathparameters.NoLimitSupFactor = sup
            mathparameters.NoLimitSubFactor = sub
        end
    end

    registerotffeature {
        name         = "mathnolimitsmode",
        description  = "influence nolimits placement",
        initializers = {
            base = initialize,
            node = initialize,
        }
    }

end

do

    local function initialize(tfmdata,value)
        local properties = tfmdata.properties
        if properties then
            properties.identity = value == "vertical" and "vertical" or "horizontal"
        end
    end

    registerotffeature {
        name         = "identity",
        description  = "set font identity",
        initializers = {
            base = initialize,
            node = initialize,
        }
    }

    local function initialize(tfmdata,value)
        local properties = tfmdata.properties
        if properties then
            properties.writingmode = value == "vertical" and "vertical" or "horizontal"
        end
    end

    registerotffeature {
        name         = "writingmode",
        description  = "set font direction",
        initializers = {
            base = initialize,
            node = initialize,
        }
    }

end

do -- another hack for a crappy font

    local function additalictowidth(tfmdata,key,value)
        local characters = tfmdata.characters
        local additions  = { }
        for unicode, old_c in next, characters do
            -- maybe check for math
            local oldwidth  = old_c.width
            local olditalic = old_c.italic
            if olditalic and olditalic ~= 0 then
                local private = getprivate(tfmdata)
                local new_c = {
                    width    = oldwidth + olditalic,
                    height   = old_c.height,
                    depth    = old_c.depth,
                    commands = {
                     -- { "slot", 1, private },
                     -- { "slot", 0, private },
                        { "char", private },
                        { "right", olditalic },
                    },
                }
                setmetatableindex(new_c,old_c)
                characters[unicode] = new_c
                additions[private]  = old_c
            end
        end
        for k, v in next, additions do
            characters[k] = v
        end
    end

    registerotffeature {
        name        = "italicwidths",
        description = "add italic to width",
        manipulators = {
            base = additalictowidth,
         -- node = additalictowidth, -- only makes sense for math
        }
    }

end

do

    local tounicode = fonts.mappings.tounicode

    local function check(tfmdata,key,value)
        if value == "ligatures" then
            local private   = fonts.constructors and fonts.constructors.privateoffset or 0xF0000
            local collected = fonts.handlers.otf.readers.getcomponents(tfmdata.shared.rawdata)
            if collected and next(collected)then
                for unicode, char in next, tfmdata.characters do
                    if true then -- if unicode >= private or (unicode >= 0xE000 and unicode <= 0xF8FF) then
                        local u = collected[unicode]
                        if u then
                            local n = #u
                            for i=1,n do
                                if u[i] > private then
                                    n = 0
                                    break
                                end
                            end
                            if n > 0 then
                                if n == 1 then
                                    u = u[1]
                                end
                                char.unicode   = u
                                char.tounicode = tounicode(u)
                            end
                        end
                    end
                end
            end
        end
    end

    -- forceunicodes=ligatures : aggressive lig resolving (e.g. for emoji)
    --
    -- kind of like: \enabletrackers[fonts.mapping.forceligatures]

    registerotffeature {
        name         = "forceunicodes",
        description  = "forceunicodes",
        manipulators = {
            base = check,
            node = check,
        }
    }

end

do

    -- This is a rather special test-only feature that I added for the sake of testing
    -- Idris's husayni. We wanted to know if uniscribe obeys the order of lookups in a
    -- font, in spite of what the description of handling arabic suggests. And indeed,
    -- mixed-in lookups of other features (like all these ss* in husayni) are handled
    -- the same in context as in uniscribe. If one sets reorderlookups=arab then we sort
    -- according to the "assumed" order so e.g. the ss* move to after the standard
    -- features. The observed difference in rendering is an indication that uniscribe is
    -- quite faithful to the font (while e.g. tests with the hb plugin demonstrate some
    -- interference, apart from some hard coded init etc expectations). Anyway, it means
    -- that we're okay with the (generic) node processor. A pitfall is that in context
    -- we can actually control more, so we can trigger an analyze pass with e.g.
    -- dflt/dflt while the libraries depend on the script settings for that. Uniscribe
    -- probably also parses the string and when seeing arabic will follow a different
    -- code path, although it seems to treat all features equal.

    local trace_reorder  = trackers.register("fonts.reorderlookups",function(v) trace_reorder = v end)
    local report_reorder = logs.reporter("fonts","reorder")

    local vectors = { }

    vectors.arab = {
        gsub = {
            ccmp =  1,
            isol =  2,
            fina =  3,
            medi =  4,
            init =  5,
            rlig =  6,
            rclt =  7,
            calt =  8,
            liga =  9,
            dlig = 10,
            cswh = 11,
            mset = 12,
        },
        gpos = {
            curs =  1,
            kern =  2,
            mark =  3,
            mkmk =  4,
        },
    }

    function otf.reorderlookups(tfmdata,vector)
        local order = vectors[vector]
        if not order then
            return
        end
        local oldsequences = tfmdata.resources.sequences
        if oldsequences then
            local sequences = { }
            for i=1,#oldsequences do
                sequences[i] = oldsequences[i]
            end
            for i=1,#sequences do
                local s = sequences[i]
                local features = s.features
                local kind     = s.type
                local index    = s.index
                if features then
                    local when
                    local what
                    for feature in sortedhash(features) do
                        if not what then
                            what = find(kind,"^gsub") and "gsub" or "gpos"
                        end
                        local newwhen = order[what][feature]
                        if not newwhen then
                            -- skip
                        elseif not when then
                            when = newwhen
                        elseif newwhen < when then
                            when = newwhen
                        end
                    end
                    s.ondex = s.index
                    s.index = i
                    s.what  = what == "gsub" and 1 or 2
                    s.when  = when or 99
                else
                    s.ondex = s.index
                    s.index = i
                    s.what  = 1
                    s.when  = 99
                end
            end
            sort(sequences,function(a,b)
                local what_a = a.what
                local what_b = b.what
                if what_a ~= what_b then
                    return a.index < b.index
                end
                local when_a = a.when
                local when_b = b.when
                if when_a == when_b then
                    return a.index < b.index
                else
                    return when_a < when_b
                end
            end)
            local swapped = 0
            for i=1,#sequences do
                local sequence = sequences[i]
                local features = sequence.features
                if features then
                    local index = sequence.index
                    if index ~= i then
                        swapped = swapped + 1
                    end
                    if trace_reorder then
                        if swapped == 1 then
                            report_reorder()
                            report_reorder("start swapping lookups in font %!font:name!",tfmdata)
                            report_reorder()
                            report_reorder("gsub order: % t",table.swapped(order.gsub))
                            report_reorder("gpos order: % t",table.swapped(order.gpos))
                            report_reorder()
                        end
                        report_reorder("%03i : lookup %03i, type %s, sorted %2i, moved %s, % t",
                            i,index,sequence.what == 1 and "gsub" or "gpos",sequence.when or 99,
                            (index > i and "-") or (index < i and "+") or "=",sortedkeys(features))
                    end
                end
                sequence.what  = nil
                sequence.when  = nil
                sequence.index = sequence.ondex
            end
            if swapped > 0 then
                if trace_reorder then
                    report_reorder()
                    report_reorder("stop swapping lookups, %i lookups swapped",swapped)
                    report_reorder()
                end
--                 tfmdata.resources.sequences = sequences
                tfmdata.shared.reorderedsequences = sequences
            end
        end
    end

    -- maybe delay till ra is filled

    local function reorderlookups(tfmdata,key,value)
        if value then
            otf.reorderlookups(tfmdata,value)
        end
    end

    registerotffeature {
        name        = "reorderlookups",
        description = "reorder lookups",
        manipulators = {
            base = reorderlookups,
            node = reorderlookups,
        }
    }

end
