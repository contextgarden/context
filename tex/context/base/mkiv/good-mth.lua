if not modules then modules = { } end modules ['good-mth'] = {
    version   = 1.000,
    comment   = "companion to font-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next = type, next
local ceil = math.ceil

local fonts = fonts

local trace_goodies      = false  trackers.register("fonts.goodies", function(v) trace_goodies = v end)
local report_goodies     = logs.reporter("fonts","goodies")

local registerotffeature = fonts.handlers.otf.features.register

local fontgoodies        = fonts.goodies or { }

local fontcharacters     = fonts.hashes.characters

local nuts               = nodes.nuts

local setlink            = nuts.setlink

local nodepool           = nuts.pool

local new_kern           = nodepool.kern
local new_glyph          = nodepool.glyph
local new_hlist          = nodepool.hlist
local new_vlist          = nodepool.vlist

local insert_node_after  = nuts.insert_after

-- experiment, we have to load the definitions immediately as they precede
-- the definition so they need to be initialized in the typescript

local function finalize(tfmdata,feature,value)
    mathematics.overloaddimensions(tfmdata,tfmdata,value)
end

registerotffeature {
    name         = "mathdimensions",
    description  = "manipulate math dimensions",
 -- default      = true,
    manipulators = {
        base = finalize,
        node = finalize,
    }
}

local function initialize(goodies)
    local mathgoodies = goodies.mathematics
    if mathgoodies then
        local virtuals = mathgoodies.virtuals
        local mapfiles = mathgoodies.mapfiles
        local maplines = mathgoodies.maplines
        if virtuals then
            for name, specification in next, virtuals do
                -- beware, they are all constructed
                mathematics.makefont(name,specification,goodies)
            end
        end
        if mapfiles then
            for i=1,#mapfiles do
                fonts.mappings.loadfile(mapfiles[i]) -- todo: backend function
            end
        end
        if maplines then
            for i=1,#maplines do
                fonts.mappings.loadline(maplines[i]) -- todo: backend function
            end
        end
    end
end

fontgoodies.register("mathematics", initialize)

local enabled = false   directives.register("fontgoodies.mathkerning",function(v) enabled = v end)

local function initialize(tfmdata)
    if enabled and tfmdata.mathparameters then -- funny, cambria text has this
        local goodies = tfmdata.goodies
        if goodies then
            local characters = tfmdata.characters
            if characters[0x1D44E] then -- 119886
                -- we have at least an italic a
                for i=1,#goodies do
                    local mathgoodies = goodies[i].mathematics
                    if mathgoodies then
                        local kerns = mathgoodies.kerns
                        if kerns then
                            for unicode, specification in next, kerns do
                                local chardata = characters[unicode]
                                if chardata and (not chardata.mathkerns or specification.force) then
                                    chardata.mathkerns = specification
                                end
                            end
                            return
                        end
                    end
                end
            else
                return -- no proper math font anyway
            end
        end
    end
end

registerotffeature {
    name        = "mathkerns",
    description = "math kerns",
    default     = true,
    initializers = {
        base = initialize,
        node = initialize,
    }
}

-- math italics (not really needed)
--
-- it would be nice to have a \noitalics\font option

local function initialize(tfmdata)
    local goodies = tfmdata.goodies
    if goodies then
        local shared = tfmdata.shared
        for i=1,#goodies do
            local mathgoodies = goodies[i].mathematics
            if mathgoodies then
                local mathitalics = mathgoodies.italics
                if mathitalics then
                    local properties = tfmdata.properties
                    if properties.setitalics then
                        mathitalics = mathitalics[file.nameonly(properties.name)] or mathitalics
                        if mathitalics then
                            if trace_goodies then
                                report_goodies("loading mathitalics for font %a",properties.name)
                            end
                            local corrections   = mathitalics.corrections
                            local defaultfactor = mathitalics.defaultfactor
                         -- properties.mathitalic_defaultfactor = defaultfactor -- we inherit outer one anyway (name will change)
                            if corrections then
                                fontgoodies.registerpostprocessor(tfmdata, function(tfmdata) -- this is another tfmdata (a copy)
                                    -- better make a helper so that we have less code being defined
                                    local properties = tfmdata.properties
                                    local parameters = tfmdata.parameters
                                    local characters = tfmdata.characters
                                    properties.mathitalic_defaultfactor = defaultfactor
                                    properties.mathitalic_defaultvalue  = defaultfactor * parameters.quad
                                    if trace_goodies then
                                        report_goodies("assigning mathitalics for font %a",properties.name)
                                    end
                                    local quad    = parameters.quad
                                    local hfactor = parameters.hfactor
                                    for k, v in next, corrections do
                                        local c = characters[k]
                                        if c then
                                            if v > -1 and v < 1 then
                                                c.italic = v * quad
                                            else
                                                c.italic = v * hfactor
                                            end
                                        else
                                            report_goodies("invalid mathitalics entry %U for font %a",k,properties.name)
                                        end
                                    end
                                end)
                            end
                            return -- maybe not as these can accumulate
                        end
                    end
                end
            end
        end
    end
end

registerotffeature {
    name         = "mathitalics",
    description  = "additional math italic corrections",
 -- default      = true,
    initializers = {
        base = initialize,
        node = initialize,
    }
}

-- fontgoodies.register("mathitalics", initialize)

local function mathradicalaction(n,h,v,font,mchar,echar)
    local characters = fontcharacters[font]
    local mchardata  = characters[mchar]
    local echardata  = characters[echar]
    local ewidth     = echardata.width
    local mwidth     = mchardata.width
    local delta      = h - ewidth
    local glyph      = new_glyph(font,echar)
    local head       = glyph
    if delta > 0 then
        local count = ceil(delta/mwidth)
        local kern  = (delta - count * mwidth) / count
        for i=1,count do
            local k = new_kern(kern)
            local g = new_glyph(font,mchar)
            setlink(k,head)
            setlink(g,k)
            head = g
        end
    end
    local height = mchardata.height
    local list   = new_hlist(head)
    local kern   = new_kern(height-v)
    list = setlink(kern,list)
    local list = new_vlist(kern)
    insert_node_after(n,n,list)
end

local function mathhruleaction(n,h,v,font,bchar,mchar,echar)
    local characters = fontcharacters[font]
    local bchardata  = characters[bchar]
    local mchardata  = characters[mchar]
    local echardata  = characters[echar]
    local bwidth     = bchardata.width
    local mwidth     = mchardata.width
    local ewidth     = echardata.width
    local delta      = h - ewidth - bwidth
    local glyph      = new_glyph(font,echar)
    local head       = glyph
    if delta > 0 then
        local count = ceil(delta/mwidth)
        local kern  = (delta - count * mwidth) / (count+1)
        for i=1,count do
            local k = new_kern(kern)
            local g = new_glyph(font,mchar)
            setlink(k,head)
            setlink(g,k)
            head = g
        end
        local k = new_kern(kern)
        setlink(k,head)
        head = k
    end
    local g = new_glyph(font,bchar)
    setlink(g,head)
    head = g
    local height = mchardata.height
    local list   = new_hlist(head)
    local kern   = new_kern(height-v)
    list = setlink(kern,list)
    local list = new_vlist(kern)
    insert_node_after(n,n,list)
end

local function initialize(tfmdata)
    local goodies = tfmdata.goodies
    if goodies then
        local resources = tfmdata.resources
        local ruledata  = { }
        for i=1,#goodies do
            local mathematics = goodies[i].mathematics
            if mathematics then
                local rules = mathematics.rules
                if rules then
                    for tag, name in next, rules do
                        ruledata[tag] = name
                    end
                end
            end
        end
        if next(ruledata) then
            local characters = tfmdata.characters
            local unicodes   = resources.unicodes
            if characters and unicodes then
                local mathruleactions = resources.mathruleactions
                if not mathruleactions then
                    mathruleactions = { }
                    resources.mathruleactions = mathruleactions
                end
                --
                local mchar = unicodes[ruledata["radical.extender"] or false]
                local echar = unicodes[ruledata["radical.end"]      or false]
                if mchar and echar then
                    mathruleactions.radicalaction = function(n,h,v,font)
                        mathradicalaction(n,h,v,font,mchar,echar)
                    end
                end
                --
                local bchar = unicodes[ruledata["hrule.begin"]    or false]
                local mchar = unicodes[ruledata["hrule.extender"] or false]
                local echar = unicodes[ruledata["hrule.end"]      or false]
                if bchar and mchar and echar then
                    mathruleactions.hruleaction = function(n,h,v,font)
                        mathhruleaction(n,h,v,font,bchar,mchar,echar)
                    end
                end
                -- not that nice but we need to register it at the tex end
             -- context.enablemathrules("\\fontclass")
            end
        end
    end
end

registerotffeature {
    name         = "mathrules",
    description  = "check math rules",
    default      = true,
    initializers = {
        base = initialize,
        node = initialize,
    }
}
