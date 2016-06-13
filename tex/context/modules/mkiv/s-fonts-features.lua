if not modules then modules = { } end modules ['s-fonts-features'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-features.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.fonts          = moduledata.fonts          or { }
moduledata.fonts.features = moduledata.fonts.features or { }

-- for the moment only otf

local sortedhash = table.sortedhash

local NC, NR, bold = context.NC, context.NR, context.bold

function moduledata.fonts.features.showused(specification)

    specification = interfaces.checkedspecification(specification)

 -- local list = utilities.parsers.settings_to_set(specification.list or "all")

    context.starttabulate { "|T|T|T|T|T|" }

        context.HL()

            NC() bold("feature")
            NC()
            NC() bold("description")
            NC() bold("value")
            NC() bold("internal")
            NC() NR()

        context.HL()

            local usedfeatures = fonts.handlers.otf.statistics.usedfeatures
            local features     = fonts.handlers.otf.tables.features
            local descriptions = fonts.handlers.otf.features.descriptions

            for feature, keys in sortedhash(usedfeatures) do
             -- if list.all or (list.otf and rawget(features,feature)) or (list.extra and rawget(descriptions,feature)) then
                    local done = false
                    for k, v in sortedhash(keys) do
                        if done then
                            NC()
                            NC()
                            NC()
                        elseif rawget(descriptions,feature) then
                            NC() context(feature)
                            NC() context("+") -- extra
                            NC() context.escaped(descriptions[feature])
                            done = true
                        elseif rawget(features,feature) then
                            NC() context(feature)
                            NC()              -- otf
                            NC() context.escaped(features[feature])
                            done = true
                        else
                            NC() context(feature)
                            NC() context("-") -- unknown
                            NC()
                            done = true
                        end
                        NC() context(k)
                        NC() context(tostring(v))
                        NC() NR()
                    end
             -- end
            end

        context.HL()

    context.stoptabulate()

end

local function collectkerns(tfmdata,feature)
    local combinations = { }
    local resources    = tfmdata.resources
    local characters   = tfmdata.characters
    local sequences    = resources.sequences
    local lookuphash   = resources.lookuphash
    local feature      = feature or "kern"
    if sequences then
        for i=1,#sequences do
            local sequence = sequences[i]
            if sequence.features and sequence.features[feature] then
                local lookuplist = sequence.subtables
                if lookuplist then
                    for l=1,#lookuplist do
                        local lookupname = lookuplist[l]
                        local lookupdata = lookuphash[lookupname]
                        for unicode, data in next, lookupdata do
                            local kerns = combinations[unicode]
                            if not kerns then
                                kerns = { }
                                combinations[unicode] = kerns
                            end
                            for otherunicode, kern in next, data do
                                if not kerns[otherunicode] and kern ~= 0 then
                                    kerns[otherunicode] = kern
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return combinations
end

local showkernpair = context.showkernpair

function moduledata.fonts.features.showbasekerns(specification)
    -- assumes that the font is loaded in base mode
    specification = interfaces.checkedspecification(specification)
    local id, cs  = fonts.definers.internal(specification,"<module:fonts:features:font>")
    local tfmdata = fonts.hashes.identifiers[id]
    local done    = false
    for unicode, character in sortedhash(tfmdata.characters) do
        local kerns = character.kerns
        if kerns then
            context.par()
            for othercode, kern in sortedhash(kerns) do
                showkernpair(unicode,kern,othercode)
            end
            context.par()
            done = true
        end
    end
    if not done then
        context("no kern pairs found")
        context.par()
    end
end

function moduledata.fonts.features.showallkerns(specification)
    specification    = interfaces.checkedspecification(specification)
    local id, cs     = fonts.definers.internal(specification,"<module:fonts:features:font>")
    local tfmdata    = fonts.hashes.identifiers[id]
    local allkerns   = collectkerns(tfmdata)
    local characters = tfmdata.characters
    if next(allkerns) then
        for first, pairs in sortedhash(allkerns) do
            context.par()
            for second, kern in sortedhash(pairs) do
             -- local kerns = characters[first].kerns
             -- if not kerns and pairs[second] then
             --     -- weird
             -- end
                showkernpair(first,kern,second,0)
            end
            context.par()
        end
    else
        context("no kern pairs found")
        context.par()
    end
end
