if not modules then modules = { } end modules ['s-fonts-tables'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-tables.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.fonts        = moduledata.fonts        or { }
moduledata.fonts.tables = moduledata.fonts.tables or { }

local setmetatableindex = table.setmetatableindex
local sortedhash        = table.sortedhash
local sortedkeys        = table.sortedkeys
local format            = string.format
local concat            = table.concat

local tabletracers = moduledata.fonts.tables

local digits = {
    dflt = {
        dflt = "1234567890 1/2",
    },
    arab = {
        dflt = "",
    },
    latn = {
        dflt = "1234567890 1/2",
    }
}

local punctuation = {
    dflt = {
        dflt = ". , : ; ? ! ‹ › « »",
    },
}

local symbols = {
    dflt = {
        dflt = "@ # $ % & * () [] {} <> + - = / |",
    },
}

local LATN = "abcdefghijklmnopqrstuvwxyz"

local uppercase = {
    latn = {
        dflt = LATN,
        fra  = LATN .. " ÀÁÂÈÉÊÒÓÔÙÚÛÆÇ",
    },
    grek = {
        dftl = "ΑΒΓΔΕΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ",
    },
    cyrl= {
        dflt = "АБВГДЕЖЗИІЙКЛМНОПРСТУФХЦЧШЩЪЫЬѢЭЮЯѲ"
    },
}

local latn = "abcdefghijklmnopqrstuvwxyz"

local lowercase = {
    latn = {
        dftl = latn,
        nld  = latn .. " ïèéë",
        deu  = latn .. " äöüß",
        fra  = latn .. " àáâèéêòóôùúûæç",
    },
    grek = {
        dftl = "αβγδεηθικλμνξοπρστυφχψω",
    },
    cyrl= {
        dflt = "абвгдежзиійклмнопрстуфхцчшщъыьѣэюяѳ"
    },
    arab = {
        dflt = "ابجدهوزحطيكلمنسعفصقرشتثخذضظغ"
    },
}

local samples = {
    digits      = digits,
    punctuation = punctuation,
    symbols     = symbols,
    uppercase   = uppercase,
    lowercase   = lowercase,
}

tabletracers.samples = samples

setmetatableindex(uppercase,        function(t,k) return rawget(t,"latn") end)
setmetatableindex(lowercase,        function(t,k) return rawget(t,"latn") end)
setmetatableindex(digits,           function(t,k) return rawget(t,"dflt") end)
setmetatableindex(symbols,          function(t,k) return rawget(t,"dflt") end)
setmetatableindex(punctuation,      function(t,k) return rawget(t,"dflt") end)

setmetatableindex(uppercase.latn,   function(t,k) return rawget(t,"dflt") end)
setmetatableindex(uppercase.grek,   function(t,k) return rawget(t,"dflt") end)
setmetatableindex(uppercase.cyrl,   function(t,k) return rawget(t,"dflt") end)

setmetatableindex(lowercase.latn,   function(t,k) return rawget(t,"dflt") end)
setmetatableindex(lowercase.grek,   function(t,k) return rawget(t,"dflt") end)
setmetatableindex(lowercase.cyrl,   function(t,k) return rawget(t,"dflt") end)

setmetatableindex(digits.dflt,      function(t,k) return rawget(t,"dflt") end)
setmetatableindex(symbols.dflt,     function(t,k) return rawget(t,"dflt") end)
setmetatableindex(punctuation.dflt, function(t,k) return rawget(t,"dflt") end)

local function typesettable(t,keys,synonyms,nesting,prefix)
    if t then
        if not prefix then
            context.starttabulate { "|Tl|Tl|Tl|" }
        end
        for k, v in sortedhash(keys) do
            if k == "synonyms" then
            elseif type(v) ~= "table" then
                context.NC()
                if prefix then
                    context("%s.%s",prefix,k)
                else
                    context(k)
                end
                context.NC()
                local tk = t[k]
                if v == "boolean" then
                    context(tostring(tk or false))
                elseif not tk then
                    context("<unset>")
                elseif v == "filename" then
                    context(file.basename(tk))
                elseif v == "basepoints" then
                    context("%sbp",tk)
                elseif v == "scaledpoints" then
                    context("%p",tk)
                elseif v == "table" then
                    context("<table>")
                else -- if v == "integerscale" then
                    context(tostring(tk))
                end
                context.NC()
                local synonym = (not prefix and synonyms[k]) or (prefix and synonyms[format("%s.%s",prefix,k)])
                if synonym then
                    context(format("(%s)",concat(synonym," ")))
                end
                context.NC()
                context.NR()
            elseif nesting == false then
                context("<table>")
            else -- true or nil
                typesettable(t[k],v,synonyms,nesting,k)
            end
        end
        if not prefix then
            context.stoptabulate()
        end
    end
end

local function typeset(t,keys,nesting,prefix)
    local synonyms = keys.synonyms or { }
    local collected = { }
    for k, v in next, synonyms do
        local c = collected[v]
        if not c then
            c = { }
            collected[v] = c
        end
        c[#c+1] = k
    end
    for k, v in next, collected do
        table.sort(v)
    end
    typesettable(t,keys,collected,nesting,prefix)
end

tabletracers.typeset = typeset

function tabletracers.showproperties(nesting)
    local tfmdata = fonts.hashes.identifiers[font.current()]
    typeset(tfmdata.properties,fonts.constructors.keys.properties,nesting)
end

function tabletracers.showparameters(nesting)
    local tfmdata = fonts.hashes.identifiers[font.current()]
    typeset(tfmdata.parameters,fonts.constructors.keys.parameters,nesting)
end

function tabletracers.showpositionings()
    local tfmdata = fonts.hashes.identifiers[font.current()]
    local resources = tfmdata.resources
    if resources then
        local features = resources.features
        if features then
            local gpos = features.gpos
            if gpos and next(gpos) then
                context.starttabulate { "|Tl|Tl|Tlp|" }
                for feature, scripts in sortedhash(gpos) do
                    for script, languages in sortedhash(scripts) do
                        context.NC()
                        context(feature)
                        context.NC()
                        context(script)
                        context.NC()
                        context(concat(sortedkeys(languages)," "))
                        context.NC()
                        context.NR()
                    end
                end
                context.stoptabulate()
            else
                context("no entries")
                context.par()
            end
        end
    end
end

local dynamics = true

function tabletracers.showsubstitutions()
    local tfmdata = fonts.hashes.identifiers[font.current()]
    local resources = tfmdata.resources
    if resources then
        local features = resources.features
        if features then
            local gsub = features.gsub
            if gsub then
                local makes_sense = { }
                for feature, scripts in sortedhash(gsub) do
                    for script, languages in sortedhash(scripts) do
                        for language in sortedhash(languages) do
                            local tag = format("dummy-%s-%s-%s",feature,script,language)
                            local fnt = format("file:%s*%s",file.basename(tfmdata.properties.filename),tag)
                            context.definefontfeature (
                                { tag },
                                {
                                    mode      = "node",
                                    script    = script,
                                    language  = language,
                                    [feature] = "yes"
                                }
                            )
                            if not dynamics then
                                context.definefont( { fnt }, { fnt } )
                            end
                            makes_sense[#makes_sense+1] = {
                                feature    = feature,
                                tag        = tag,
                                script     = script,
                                language   = language,
                                fontname   = fnt,
                            }
                        end
                    end
                end
                if #makes_sense > 0 then
                    context.starttabulate { "|Tl|Tl|Tl|p|" }
                    for i=1,#makes_sense do
                        local data     = makes_sense[i]
                        local script   = data.script
                        local language = data.language
                        context.NC()
                            context(data.feature)
                        context.NC()
                            context(script)
                        context.NC()
                            context(language)
                        context.NC()
                            if not dynamics then
                                context.startfont { data.fontname }
                            else
                                context.addff(data.tag)
                            end
                            context.verbatim(samples.lowercase  [script][language]) context.par()
                            context.verbatim(samples.uppercase  [script][language]) context.par()
                            context.verbatim(samples.digits     [script][language]) context.par()
                            context.verbatim(samples.punctuation[script][language]) context.quad()
                            context.verbatim(samples.symbols    [script][language])
                            if not dynamics then
                                context.stopfont()
                            end
                        context.NC()
                        context.NR()
                    end
                    context.stoptabulate()
                else
                    context("no entries")
                    context.par()
                end
            end
        end
    end
end

function tabletracers.showall(specification) -- not interfaced

    specification = interfaces.checkedspecification(specification)

    if specification.title then
        context.starttitle { title = specification.title }
    end

    context.startsubject { title = "Properties" }
        tabletracers.showproperties()
    context.stopsubject()

    context.startsubject { title = "Parameters" }
        tabletracers.showparameters()
    context.stopsubject()

    context.startsubject { title = "Positioning features" }
        tabletracers.showpositionings()
    context.stopsubject()

    context.startsubject { title = "Substitution features" }
        tabletracers.showsubstitutions()
    context.stopsubject()

    if title then
        context.stoptitle()
    end

end
