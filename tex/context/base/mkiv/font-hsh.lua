if not modules then modules = { } end modules ['font-hsh'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local rawget = rawget

local setmetatableindex = table.setmetatableindex
local currentfont       = font.current
local allocate          = utilities.storage.allocate

local fonts         = fonts
local hashes        = fonts.hashes or allocate()
fonts.hashes        = hashes

-- todo: autoallocate ... just create on the fly .. use constructors.keys (problem: plurals)

local identifiers    = hashes.identifiers    or allocate()
local characters     = hashes.characters     or allocate() -- chardata
local descriptions   = hashes.descriptions   or allocate()
local parameters     = hashes.parameters     or allocate()
local mathparameters = hashes.mathparameters or allocate()
local properties     = hashes.properties     or allocate()
local resources      = hashes.resources      or allocate()
local spacings       = hashes.spacings       or allocate()
local spaces         = hashes.spaces         or allocate()
local quads          = hashes.quads          or allocate() -- maybe also spacedata
local xheights       = hashes.xheights       or allocate()
local csnames        = hashes.csnames        or allocate() -- namedata
local features       = hashes.features       or allocate()
local marks          = hashes.marks          or allocate()
local classes        = hashes.classes        or allocate()
local italics        = hashes.italics        or allocate()
local lastmathids    = hashes.lastmathids    or allocate()
local dynamics       = hashes.dynamics       or allocate()
local unicodes       = hashes.unicodes       or allocate()
local originals      = hashes.originals      or allocate()
local modes          = hashes.modes          or allocate()
local variants       = hashes.variants       or allocate()

hashes.characters     = characters
hashes.descriptions   = descriptions
hashes.parameters     = parameters
hashes.mathparameters = mathparameters
hashes.properties     = properties
hashes.resources      = resources
hashes.spacings       = spacings
hashes.spaces         = spaces
hashes.quads          = quads                 hashes.emwidths  = quads
hashes.xheights       = xheights              hashes.exheights = xheights
hashes.csnames        = csnames
hashes.features       = features
hashes.marks          = marks
hashes.classes        = classes
hashes.italics        = italics
hashes.lastmathids    = lastmathids
hashes.dynamics       = dynamics
hashes.unicodes       = unicodes
hashes.originals      = originals
hashes.modes          = modes
hashes.variants       = variants

local nodepool      = nodes and nodes.pool
local dummyglyph    = nodepool and nodepool.register(nodepool.glyph())

local nulldata = allocate {
    name         = "nullfont",
    characters   = { },
    descriptions = { },
    properties   = {
        designsize = 786432,
    },
    parameters   = { -- lmromanregular @ 12pt
        slantperpoint =      0,
        spacing       = {
            width   = 256377,
            stretch = 128188,
            shrink  = 85459,
            extra   = 85459,
        },
        quad          = 786432,
        xheight       = 338952,
        -- compatibility:
        slant         =      0, -- 1
        space         = 256377, -- 2
        space_stretch = 128188, -- 3
        space_shrink  =  85459, -- 4
        x_height      = 338952, -- 5
        quad          = 786432, -- 6
        extra_space   =  85459, -- 7
        size          = 786432,
    },
}

fonts.nulldata = nulldata

fonts.constructors.enhanceparameters(nulldata.parameters) -- official copies for us

setmetatableindex(identifiers, function(t,k)
    return k == true and identifiers[currentfont()] or nulldata
end)

do

    -- to be used

    local define  = font.define
    local setfont = font.setfont
    local frozen  = font.frozen

    function fonts.reserveid(fontdata)
        return define(fontdata or nulldata)
    end

    function fonts.enhanceid(id,fontdata)
        if not frozen(id) then
            setfont(id,fontdata)
        end
    end

end

setmetatableindex(characters, function(t,k)
    if k == true then
        return characters[currentfont()]
    else
        local characters = identifiers[k].characters
        t[k] = characters
        return characters
    end
end)

setmetatableindex(descriptions, function(t,k)
    if k == true then
        return descriptions[currentfont()]
    else
        local descriptions = identifiers[k].descriptions
        t[k] = descriptions
        return descriptions
    end
end)

setmetatableindex(parameters, function(t,k)
    if k == true then
        return parameters[currentfont()]
    else
        local parameters = identifiers[k].parameters
        t[k] = parameters
        return parameters
    end
end)

setmetatableindex(mathparameters, function(t,k)
    if k == true then
        return mathparameters[currentfont()]
    else
        local mathparameters = identifiers[k].mathparameters
        t[k] = mathparameters
        return mathparameters
    end
end)

setmetatableindex(properties, function(t,k)
    if k == true then
        return properties[currentfont()]
    else
        local properties = identifiers[k].properties
        t[k] = properties
        return properties
    end
end)

setmetatableindex(resources, function(t,k)
    if k == true then
        return resources[currentfont()]
    else
        local shared    = identifiers[k].shared
        local rawdata   = shared and shared.rawdata
        local resources = rawdata and rawdata.resources
        t[k] = resources or false -- better than resolving each time
        return resources
    end
end)

setmetatableindex(features, function(t,k)
    if k == true then
        return features[currentfont()]
    else
        local shared = identifiers[k].shared
        local features = shared and shared.features or { }
        t[k] = features
        return features
    end
end)

local nospacing = {
    width   = 0,
    stretch = 0,
    shrink  = 0,
    extra   = 0,
}

setmetatableindex(spacings, function(t,k)
    if k == true then
        return spacings[currentfont()]
    else
        local parameters = parameters[k]
        local spacing = parameters and parameters.spacing or nospacing
        t[k] = spacing
        return spacing
    end
end)

setmetatableindex(spaces, function(t,k)
    if k == true then
        return spaces[currentfont()]
    else
        local space = spacings[k].width
        t[k] = space
        return space
    end
end)

setmetatableindex(marks, function(t,k)
    if k == true then
        return marks[currentfont()]
    else
        local resources = identifiers[k].resources or { }
        local marks     = resources.marks or { }
        t[k] = marks
        return marks
    end
end)

setmetatableindex(classes, function(t,k)
    if k == true then
        return classes[currentfont()]
    else
        local resources = identifiers[k].resources or { }
        local classes   = resources.classes or { }
        t[k] = classes
        return classes
    end
end)

setmetatableindex(quads, function(t,k)
    if k == true then
        return quads[currentfont()]
    else
        local parameters = rawget(parameters,k)
        local quad
        if parameters then
            quad = parameters.quad
        elseif dummyglyph then
            dummyglyph.font = k
            dummyglyph.char = 0x2014  -- emdash
            quad            = dummyglyph.width -- dirty trick
        end
        if not quad or quad == 0 then
            quad = 655360 -- lm 10pt
        end
        t[k] = quad
        return quad
    end
end)

setmetatableindex(xheights, function(t,k)
    if k == true then
        return xheights[currentfont()]
    else
        local parameters = rawget(parameters,k)
        local xheight
        if parameters then
            xheight = parameters.xheight
        elseif dummyglyph then
            dummyglyph.font = k
            dummyglyph.char = 0x78     -- x
            xheight         = dummyglyph.height -- dirty trick
        end
        if not xheight or xheight == 0 then
            xheight = 282460 -- lm 10pt
        end
        t[k] = xheight
        return xheight
    end
end)

setmetatableindex(italics, function(t,k) -- is test !
    if k == true then
        return italics[currentfont()]
    else
        local properties = identifiers[k].properties
        local hasitalics = properties and properties.hasitalics
        if hasitalics then
            hasitalics = characters[k] -- convenient return
        else
            hasitalics = false
        end
        t[k] = hasitalics
        return hasitalics
    end
end)

setmetatableindex(dynamics, function(t,k)
    if k == true then
        return dynamics[currentfont()]
    else
        local shared = identifiers[k].shared
        local dynamics = shared and shared.dynamics or false
        t[k] = dynamics
        return dynamics
    end
end)

setmetatableindex(unicodes, function(t,k) -- always a unicode
    if k == true then
        return unicodes[currentfont()]
    else
        local resources = resources[k]
        local unicodes  = resources and resources.unicodes or { }
        t[k] = unicodes
        return unicodes
    end
end)

setmetatableindex(originals, function(t,k) -- always a unicode
    if k == true then
        return originals[currentfont()]
    else
        local resolved = { }
        setmetatableindex(resolved,function(t,name)
            local u = unicodes[k][name]
            local d = u and descriptions[k][u]
            local v = d and d.unicode or u or 0 -- so we return notdef (at least for the moment)
            t[name] = u
            return v
        end)
        t[k] = resolved
        return resolved
    end
end)

setmetatableindex(modes, function(t,k)
    if k == true then
        return modes[currentfont()]
    else
        local mode = properties[k].mode or "base"
        t[k] = mode
        return mode
    end
end)

setmetatableindex(variants, function(t,k)
    if k == true then
        return variants[currentfont()]
    else
        local resources = resources[k]
        if resources then
            local variants = resources.variants
            if variants and next(variants) then
                t[k] = variants
                return variants
            end
        end
        t[k] = false
        return false
    end
end)

function font.getfont(id)
    return identifiers[id]
end

-- font.setfont = currentfont -- bah, no native 'setfont' as name
