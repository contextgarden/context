if not modules then modules = { } end modules ['font-imp-quality'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then return end

local next, type, tonumber = next, type, tonumber
local byte = string.byte
local insert = table.insert

local fonts              = fonts
local utilities          = utilities

local handlers           = fonts.handlers
local otf                = handlers.otf
local afm                = handlers.afm
local registerotffeature = otf.features.register
local registerafmfeature = afm.features.register

local allocate           = utilities.storage.allocate
local getparameters      = utilities.parsers.getparameters

local implement          = interfaces and interfaces.implement

local trace_protrusion   = false  trackers.register("fonts.protrusion", function(v) trace_protrusion = v end)
local trace_expansion    = false  trackers.register("fonts.expansion",  function(v) trace_expansion  = v end)

local report_expansions  = logs.reporter("fonts","expansions")
local report_protrusions = logs.reporter("fonts","protrusions")

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

local function initialize(tfmdata,value)
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

local specification = {
    name        = "expansion",
    description = "apply hz optimization",
    initializers = {
        base = initialize,
        node = initialize,
    }
}

registerotffeature(specification)
registerafmfeature(specification)

fonts.goodies.register("expansions",  function(...) return fonts.goodies.report("expansions", trace_expansion, ...) end)

if context then

    implement {
        name      = "setupfontexpansion",
        arguments = "2 strings",
        actions   = function(class,settings) getparameters(classes,class,'preset',settings) end
    }

end

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
    [0x00BF] = { 0.20, 0    }, -- ¿
    [0x0021] = { 0,    0.20 }, -- !
    [0x00A1] = { 0.20, 0,   }, -- ¡
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
    local parameters   = tfmdata.parameters
    local resources    = tfmdata.resources
    local rawdata      = tfmdata.shared.rawdata
    local lookuphash   = rawdata.lookuphash
    local lookuptags   = resources.lookuptags
    local script       = properties.script
    local language     = properties.language
    local units        = parameters.units
    local done, factor, left, right = false, 1, 1, 1
    local class = classes[value]
    if class then
        factor = class.factor or 1
        left   = class.left   or 1
        right  = class.right  or 1
    else
        factor = tonumber(value) or 1
    end
    local lfactor = left  * factor
    local rfactor = right * factor
    if trace_protrusion then
        report_protrusions("left factor %0.3F, right factor %0.3F",lfactor,rfactor)
    end
    tfmdata.parameters.protrusion = {
        factor = factor,
        left   = left,
        right  = right,
    }
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
                                if v == true then
                                    -- zero
                                else
                                    local w = descriptions[k].width
                                    local d = - v[1]
                                    if w == 0 or d == 0 then
                                        -- ignored
                                    else
                                        local p = lfactor * d/units
                                        characters[k].left_protruding = p
                                        if trace_protrusion then
                                            report_protrusions("lfbd -> %0.3F %C",p,k)
                                        end
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
                                if v == true then
                                    -- zero
                                else
                                    local w = descriptions[k].width
                                    local d = - v[3]
                                    if w == 0 or d == 0 then
                                        -- ignored
                                    else
                                        local p = rfactor * d/units
                                        characters[k].right_protruding = p
                                        if trace_protrusion then
                                            report_protrusions("rtbd -> %0.3F %C",p,k)
                                        end
                                    end
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

local function initialize(tfmdata,value)
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
                    local lfactor = left  * factor
                    local rfactor = right * factor
                    if trace_protrusion then
                        report_protrusions("left factor %0.3F, right factor %0.3F",lfactor,rfactor)
                    end
                    tfmdata.parameters.protrusion = {
                        factor = factor,
                        left   = left,
                        right  = right,
                    }
                    for i, chr in next, tfmdata.characters do
                        local v  = vector[i]
                        local pl = nil
                        local pr = nil
                        if v then
                            pl = v[1]
                            pr = v[2]
                        else
                            local d = data[i]
                            if d then
                                local s = d.shcode
                                if not s then
                                    -- sorry
                                elseif type(s) == "table" then
                                    local vl = vector[s[1]]
                                    local vr = vector[s[#s]]
                                    if vl then pl = vl[1] end
                                    if vr then pr = vr[2] end
                                else
                                    v = vector[s]
                                    if v then
                                        pl = v[1]
                                        pr = v[2]
                                    end
                                end
                            end
                        end
                        if pl and pl ~= 0 then
                            local p = pl * lfactor
                            chr.left_protruding  = p
                            if trace_protrusion then
                                report_protrusions("left  -> %0.3F %C ",p,i)
                            end
                        end
                        if pr and pr ~= 0 then
                            local p = pr * rfactor
                            chr.right_protruding = p
                            if trace_protrusion then
                                report_protrusions("right -> %0.3F %C",p,i)
                            end
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

local specification = {
    name         = "protrusion",
    description  = "l/r margin character protrusion",
    initializers = {
        base = initialize,
        node = initialize,
    }
}

registerotffeature(specification)
registerafmfeature(specification)

fonts.goodies.register("protrusions", function(...) return fonts.goodies.report("protrusions", trace_protrusion, ...) end)

if context then

    implement {
        name      = "setupfontprotrusion",
        arguments = "2 strings",
        actions   = function(class,settings) getparameters(classes,class,'preset',settings) end
    }

end
