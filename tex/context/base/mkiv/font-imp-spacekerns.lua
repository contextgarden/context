if not modules then modules = { } end modules ['font-imp-spacekerns'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then return end

-- This is an experiment. See font-ots.lua for original implementation.

local type, next = type, next
local insert, setmetatableindex = table.insert, table.setmetatableindex

local fonts              = fonts
local otf                = fonts.handlers.otf
local fontdata           = fonts.hashes.identifiers
local fontfeatures       = fonts.hashes.features
local otffeatures        = fonts.constructors.features.otf
local registerotffeature = otffeatures.register
local handlers           = otf.handlers
local setspacekerns      = nodes.injections.setspacekerns

function handlers.trigger_space_kerns(head,dataset,sequence,initialrl,font,attr)
    local features = fontfeatures[font]
    local enabled  = features and features.spacekern
    if enabled then
        setspacekerns(font,sequence) -- called quite often, each glyphrun
    end
    return head, enabled
end

local function hasspacekerns(data)
    local resources = data.resources
    local sequences = resources.sequences
    local validgpos = resources.features.gpos
    if validgpos and sequences then
        for i=1,#sequences do
            local sequence = sequences[i]
            local steps    = sequence.steps
            if steps then -- and sequence.features[tag] then
                local kind = sequence.type
                if kind == "gpos_pair" then -- or kind == "gpos_single" then
                    for i=1,#steps do
                        local step     = steps[i]
                        local coverage = step.coverage
                        local rules    = step.rules
                     -- if rules then
                     --     -- not now: analyze (simple) rules
                     -- elseif not coverage then
                     --     -- nothing to do
                     -- elseif kind == "gpos_single" then
                     --     -- maybe a message that we ignore
                     -- elseif kind == "gpos_pair" then
                        if coverage and not rules then
                            local format = step.format
                            if format == "move" or format == "kern" then
                                local kerns  = coverage[32]
                                if kerns then
                                    return true
                                end
                                for k, v in next, coverage do
                                    if v[32] then
                                        return true
                                    end
                                end
                            elseif format == "pair" then
                                local kerns  = coverage[32]
                                if kerns then
                                    for k, v in next, kerns do
                                        local one = v[1]
                                        if one and one ~= true then
                                            return true
                                        end
                                    end
                                end
                                for k, v in next, coverage do
                                    local kern = v[32]
                                    if kern then
                                        local one = kern[1]
                                        if one and one ~= true then
                                            return true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

otf.readers.registerextender {
    name   = "spacekerns",
    action = function(data)
        data.properties.hasspacekerns = hasspacekerns(data)
    end
}

local function newdata(t,k)
    local v = {
        left  = { },
        right = { },
        last  = 0,
        feat  = nil,
    }
    t[k] = v
    return v
end

local function spaceinitializer(tfmdata,value) -- attr
    local resources  = tfmdata.resources
    local spacekerns = resources and resources.spacekerns
    if value and spacekerns == nil then
        local rawdata    = tfmdata.shared and tfmdata.shared.rawdata
        local properties = rawdata.properties
        if properties and properties.hasspacekerns then
            local sequences = resources.sequences
            local validgpos = resources.features.gpos
            if validgpos and sequences then
                local data = setmetatableindex(newdata)
                for i=1,#sequences do
                    local sequence = sequences[i]
                    local steps    = sequence.steps
                    if steps then
                        -- we don't support space kerns in other features
                     -- local kern = sequence.features[tag]
                     -- if kern then
                        for tag, kern in next, sequence.features do

                            local d     = data[tag]
                            local left  = d.left
                            local right = d.right
                            local last  = d.last
                            local feat  = d.feat

                            local kind = sequence.type
                            if kind == "gpos_pair" then -- or kind == "gpos_single" then
                                if feat then
                                    for script, languages in next, kern do
                                        local f = feat[script]
                                        if f then
                                            for l in next, languages do
                                                f[l] = true
                                            end
                                        else
                                            feat[script] = languages
                                        end
                                    end
                                else
                                    feat = kern
    d.feat = feat
                                end
                                for i=1,#steps do
                                    local step     = steps[i]
                                    local coverage = step.coverage
                                    local rules    = step.rules
                                 -- if rules then
                                 --     -- not now: analyze (simple) rules
                                 -- elseif not coverage then
                                 --     -- nothing to do
                                 -- elseif kind == "gpos_single" then
                                 --     -- makes no sense in TeX
                                 -- elseif kind == "gpos_pair" then
                                    if coverage and not rules then
                                        local format = step.format
                                        if format == "move" or format == "kern" then
                                            local kerns  = coverage[32]
                                            if kerns then
                                                for k, v in next, kerns do
                                                    right[k] = v
                                                end
                                            end
                                            for k, v in next, coverage do
                                                local kern = v[32]
                                                if kern then
                                                    left[k] = kern
                                                end
                                            end
                                        elseif format == "pair" then
                                            local kerns  = coverage[32]
                                            if kerns then
                                                for k, v in next, kerns do
                                                    local one = v[1]
                                                    if one and one ~= true then
                                                        right[k] = one[3]
                                                    end
                                                end
                                            end
                                            for k, v in next, coverage do
                                                local kern = v[32]
                                                if kern then
                                                    local one = kern[1]
                                                    if one and one ~= true then
                                                        left[k] = one[3]
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                last = i
                            end
d.last = last
                        end
                    end
                end

                for tag, d in next, data do
                    local left  = d.left
                    local right = d.right
                    left  = next(left)  and left  or false
                    right = next(right) and right or false
                    if left or right then

                        local last  = d.last
                        local feat  = d.feat

                        if last > 0 then
                            local triggersequence = {
                                -- no steps, see (!!)
                                features = { [tag] = feat or { dflt = { dflt = true, } } },
                                flags    = noflags,
                                name     = "trigger_space_kerns",
                                order    = { tag },
                                type     = "trigger_space_kerns",
                                left     = left,
                                right    = right,
                            }
                            insert(sequences,last,triggersequence)
                            d.last = d.last + 1
                            spacekerns = true
                        end
                    end

                end
            end
        end
        if not spacekerns then
            spacekerns = false
        end
        resources.spacekerns = spacekerns
    end
    return spacekerns
end

registerotffeature {
    name         = "spacekern",
    description  = "space kern injection",
    default      = true,
    initializers = {
        node     = spaceinitializer,
    },
}
