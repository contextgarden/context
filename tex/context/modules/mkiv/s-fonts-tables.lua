if not modules then modules = { } end modules ['s-fonts-tables'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-tables.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.fonts          = moduledata.fonts        or { }
moduledata.fonts.tables   = moduledata.fonts.tables or { }

local rawget, type = rawget, type

local setmetatableindex   = table.setmetatableindex
local sortedhash          = table.sortedhash
local sortedkeys          = table.sortedkeys
local concat              = table.concat
local insert              = table.insert
local remove              = table.remove
local formatters          = string.formatters

local tabletracers        = moduledata.fonts.tables

local new_glyph           = nodes.pool.glyph
local copy_node           = nodes.copy
local setlink             = nodes.setlink
local hpack               = nodes.hpack
local applyvisuals        = nodes.applyvisuals

local handle_positions    = fonts.handlers.otf.datasetpositionprocessor
local handle_injections   = nodes.injections.handler

local context             = context
local ctx_sequence        = context.formatted.sequence
local ctx_char            = context.char
local ctx_setfontid       = context.setfontid
local ctx_type            = context.formatted.type
local ctx_dontleavehmode  = context.dontleavehmode
local ctx_startPair       = context.startPair
local ctx_stopPair        = context.stopPair
local ctx_startSingle     = context.startSingle
local ctx_stopSingle      = context.stopSingle
local ctx_startSingleKern = context.startSingleKern
local ctx_stopSingleKern  = context.stopSingleKern
local ctx_startPairKern   = context.startPairKern
local ctx_stopPairKern    = context.stopPairKern

local ctx_NC = context.NC
local ctx_NR = context.NR

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

-- scaled boolean string scale string float cardinal

local function checked(specification)
    specification   = interfaces.checkedspecification(specification)
    local id, cs    = fonts.definers.internal(specification,"<module:fonts:features:font>")
    local tfmdata   = fonts.hashes.identifiers[id]
    local resources = tfmdata.resources
    return tfmdata, id, resources
end

local function nothing()
    context("no entries")
    context.par()
end

local function typesettable(t,keys,synonyms,nesting,prefix,depth)
    if t and next(keys) then
        if not prefix then
            context.starttabulate { "|Tl|Tl|Tl|" }
        end
        for k, v in sortedhash(keys) do
            if k == "synonyms" then
            elseif type(v) ~= "table" then
                ctx_NC()
                if prefix then
                    context("%s.%s",prefix,k)
                else
                    context(k)
                end
                ctx_NC()
             -- print(v)
                local tk = t[k]
                if v == "<boolean>" then
                    context(tostring(tk or false))
                elseif not tk then
                    context("<unset>")
                elseif k == "filename" then
                    context(file.basename(tk))
             -- elseif v == "basepoints" then
             --     context("%sbp",tk)
                elseif v == "<scaled>" then
                    context("%p",tk)
                elseif v == "<table>" then
                    context("<table>")
                else
                    context(tostring(tk))
                end
                ctx_NC()
                local synonym = (not prefix and synonyms[k]) or (prefix and synonyms[formatters["%s.%s"](prefix,k)])
                if synonym then
                    context("(% t)",synonym)
                end
                ctx_NC()
                ctx_NR()
            elseif nesting == false then
                context("<table>")
            elseif next(v) then
                typesettable(t[k],v,synonyms,nesting,k,true)
            end
        end
        if not prefix then
            context.stoptabulate()
        end
        return
    end
    if not depth then
        nothing()
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

-- function tabletracers.showproperties(nesting)
--     local tfmdata = fonts.hashes.identifiers[true]
--     typeset(tfmdata.properties,fonts.constructors.keys.properties,nesting)
-- end

-- function tabletracers.showparameters(nesting)
--     local tfmdata = fonts.hashes.identifiers[true]
--     typeset(tfmdata.parameters,fonts.constructors.keys.parameters,nesting)
-- end

function tabletracers.showproperties(specification)
    local tfmdata = checked(specification)
    if tfmdata then
        typeset(tfmdata.properties,fonts.constructors.keys.properties)
    else
        nothing()
    end
end

function tabletracers.showparameters(specification)
    local tfmdata = checked(specification)
    if tfmdata then
        typeset(tfmdata.parameters,fonts.constructors.keys.parameters)
    else
        nothing()
    end
end

local f_u = formatters["%U"]
local f_p = formatters["%p"]

local function morept(t)
    local r = { }
    for i=1,t do
        r[i] = f_p(t[i])
    end
    return concat(r," ")
end

local function noprefix(kind)
    kind = string.gsub(kind,"^gpos_","")
    kind = string.gsub(kind,"^gsub_","")
    return kind
end

local function banner(index,i,format,kind,order,chain)
    if chain then
        ctx_sequence("sequence: %i, step %i, format: %s, kind: %s, features: % t, chain: %s",
            index,i,format,noprefix(kind),order,noprefix(chain))
    else
        ctx_sequence("sequence: %i, step %i, format: %s, kind: %s, features: % t",
            index,i,format,noprefix(kind),order)
    end
end

function tabletracers.showpositionings(specification)

    local tfmdata, fontid, resources = checked(specification)

    if resources then

        local direction = "TLT"

        local sequences = resources.sequences
        local marks     = resources.marks

        if tonumber(direction) == -1 or direction == "TRT"  then
            direction = "TRT"
        else
            direction = "TLT"
        end

        local visuals   = "fontkern,glyph,box"

        local datasets  = fonts.handlers.otf.dataset(tfmdata,fontid,0)

        local function process(dataset,sequence,kind,order,chain)
            local steps = sequence.steps
            local order = sequence.order or order
            local index = sequence.index
            for i=1,#steps do
                local step   = steps[i]
                local format = step.format
                banner(index,i,format,kind,order,chain)
                if kind == "gpos_pair" then
                    local format = step.format
                    if "kern" or format == "move" then
                        for first, seconds in sortedhash(step.coverage) do
                            local done = false
                            local zero = 0
                            for second, kern in sortedhash(seconds) do
                                if kern == 0 then
                                    zero = zero + 1
                                else
                                    if not done then
                                        ctx_startPairKern()
                                    end
                                    local one = new_glyph(fontid,first)
                                    local two = new_glyph(fontid,second)
                                    local raw = setlink(copy_node(one),copy_node(two))
                                    local pos = setlink(done and one or copy_node(one),copy_node(two))
                                    pos, okay = handle_positions(pos,fontid,direction,dataset)
                                    pos = handle_injections(pos)
                                    applyvisuals(raw,visuals)
                                    applyvisuals(pos,visuals)
                                    pos = hpack(pos,"exact",nil,direction)
                                    raw = hpack(raw,"exact",nil,direction)
                                    ctx_NC() if not done then context(f_u(first)) end
                                    ctx_NC() if not done then ctx_dontleavehmode() context(one) end
                                    ctx_NC() context(f_u(second))
                                    ctx_NC() ctx_dontleavehmode() context(two)
                                    ctx_NC() context("%p",kern)
                                    ctx_NC() ctx_dontleavehmode() context(raw)
                                    ctx_NC() ctx_dontleavehmode() context(pos)
                                    ctx_NC() ctx_NR()
                                    done = true
                                end
                            end
                            if done then
                                ctx_stopPairKern()
                            end
                            if zero > 0 then
                                ctx_type("zero: %s",zero)
                            end
                        end
                    elseif format == "pair" then
                        for first, seconds in sortedhash(step.coverage) do
                            local done     = false
                            local allnull  = 0
                            local allzero  = 0
                            local zeronull = 0
                            local nullzero = 0
                            for second, pair in sortedhash(seconds) do
                                local pfirst  = pair[1]
                                local psecond = pair[2]
                                if not pfirst and not psecond then
                                    allnull = allnull + 1
                                elseif pfirst == true and psecond == true then
                                    allzero = allzero + 1
                                elseif pfirst == true and not psecond then
                                    zeronull = zeronull + 1
                                elseif not pfirst and psecond == true then
                                    nullzero = nullzero + 1
                                else
                                    if pfirst == true then
                                        pfirst = "all zero"
                                    elseif pfirst then
                                        pfirst = morept(pfirst)
                                    else
                                        pfirst = "no first"
                                    end
                                    if psecond == true then
                                        psecond = "all zero"
                                    elseif psecond then
                                        psecond = morept(psecond)
                                    else
                                        psecond = "no second"
                                    end
                                    if not done then
                                        ctx_startPair()
                                    end
                                    local one = new_glyph(fontid,first)
                                    local two = new_glyph(fontid,second)
                                    local raw = setlink(copy_node(one),copy_node(two))
                                    local pos = setlink(done and one or copy_node(one),copy_node(two))
                                    pos, okay = handle_positions(pos,fontid,direction,dataset)
                                    pos = handle_injections(pos)
                                    applyvisuals(raw,visuals)
                                    applyvisuals(pos,visuals)
                                    pos = hpack(pos,"exact",nil,direction)
                                    raw = hpack(raw,"exact",nil,direction)
                                    ctx_NC() if not done then context(f_u(first)) end
                                    ctx_NC() if not done then ctx_dontleavehmode() context(one) end
                                    ctx_NC() context(f_u(second))
                                    ctx_NC() ctx_dontleavehmode() context(two)
                                    ctx_NC() context(pfirst)
                                    ctx_NC() context(psecond)
                                    ctx_NC() ctx_dontleavehmode() context(raw)
                                    ctx_NC() ctx_dontleavehmode() context(pos)
                                    ctx_NC() ctx_NR()
                                    done = true
                                end
                            end
                            if done then
                                ctx_stopPair()
                            end
                            if allnull > 0 or allzero > 0 or zeronull > 0 or nullzero > 0 then
                                ctx_type("both null: %s, both zero: %s, zero and null: %s, null and zero: %s",
                                    allnull,allzero,zeronull,nullzero)
                            end
                        end
                    else
                        -- maybe
                    end
                elseif kind == "gpos_single" then
                    local format = step.format
                    if format == "kern" or format == "move" then
                        local done = false
                        local zero = 0
                        for first, kern in sortedhash(step.coverage) do
                            if kern == 0 then
                                zero = zero + 1
                            else
                                if not done then
                                    ctx_startSingleKern()
                                end
                                local one = new_glyph(fontid,first)
                                local raw = copy_node(one)
                                local pos = copy_node(one)
                                pos, okay = handle_positions(pos,fontid,direction,dataset)
                                pos = handle_injections(pos)
                                applyvisuals(raw,visuals)
                                applyvisuals(pos,visuals)
                                pos = hpack(pos,"exact",nil,direction)
                                raw = hpack(raw,"exact",nil,direction)
                                ctx_NC() context(f_u(first))
                                ctx_NC() ctx_dontleavehmode() context(one)
                                ctx_NC() context("%p",kern)
                                ctx_NC() ctx_dontleavehmode() context(raw)
                                ctx_NC() ctx_dontleavehmode() context(pos)
                                ctx_NC() ctx_NR()
                                done = true
                            end
                        end
                        if done then
                            ctx_stopSingleKern()
                        end
                        if zero > 0 then
                            ctx_type("zero: %i",zero)
                        end
                    elseif format == "single" then
                        local done = false
                        local zero = 0
                        local null = 0
                        for first, single in sortedhash(step.coverage) do
                            if single == false then
                                null = null + 1
                            elseif single == true then
                                zero = zero + 1
                            else
                                single = morept(single)
                                if not done then
                                    ctx_startSingle()
                                end
                                local one = new_glyph(fontid,first)
                                local raw = copy_node(one)
                                local pos = copy_node(one)
                                pos, okay = handle_positions(pos,fontid,direction,dataset)
                                pos = handle_injections(pos)
                                applyvisuals(raw,visuals)
                                applyvisuals(pos,visuals)
                                raw = hpack(raw,"exact",nil,direction)
                                pos = hpack(pos,"exact",nil,direction)
                                ctx_NC() context(f_u(first))
                                ctx_NC() ctx_dontleavehmode() context(one)
                                ctx_NC() context(single)
                                ctx_NC() ctx_dontleavehmode() context(raw)
                                ctx_NC() ctx_dontleavehmode() context(pos)
                                ctx_NC() ctx_NR()
                                done = true
                            end
                        end
                        if done then
                            ctx_stopSingle()
                        end
                        if null > 0 then
                            if zero > 0 then
                                ctx_type("null: %i, zero: %i",null,zero)
                            else
                                ctx_type("null: %i",null)
                            end
                        else
                            if null > 0 then
                                ctx_type("both zero: %i",zero)
                            end
                        end
                    else
                        -- todo
                    end
                end
            end
        end

        local done = false

        for d=1,#datasets do
            local dataset  = datasets[d]
            local sequence = dataset[3]
            local kind     = sequence.type
            if kind == "gpos_contextchain" or kind == "gpos_context" then
                local steps = sequence.steps
                for i=1,#steps do
                    local step  = steps[i]
                    local rules = step.rules
                    if rules then
                        for i=1,#rules do
                            local rule = rules[i]
                            local lookups = rule.lookups
                            if lookups then
                                for i=1,#lookups do
                                    local lookup = lookups[i]
                                    if lookup then
                                        local look = lookup[1]
                                        local dnik = look.type
                                        if dnik == "gpos_pair" or dnik == "gpos_single" then
                                            process(dataset,look,dnik,sequence.order,kind)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                done = true
            elseif kind == "gpos_pair" or kind == "gpos_single" then
                process(dataset,sequence,kind)
                done = true
            end
        end

        if done then
            return
        end

    end

    nothing()

end

local dynamics = true

function tabletracers.showsubstitutions(specification)

    local tfmdata, fontid, resources = checked(specification)

    if resources then
        local features = resources.features
        if features then
            local gsub = features.gsub
            if gsub then
                local makes_sense = { }
                for feature, scripts in sortedhash(gsub) do
                    for script, languages in sortedhash(scripts) do
                        for language in sortedhash(languages) do
                            local tag = formatters["dummy-%s-%s-%s"](feature,script,language)
                            local fnt = formatters["file:%s*%s"](file.basename(tfmdata.properties.filename),tag)
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
                        ctx_NC()
                            context(data.feature)
                        ctx_NC()
                            context(script)
                        ctx_NC()
                            context(language)
                        ctx_NC()
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
                        ctx_NC()
                        ctx_NR()
                    end
                    context.stoptabulate()
                    return
                end
            end
        end
    end

    nothing()

end

function tabletracers.showunicodevariants(specification)

    local tfmdata, fontid, resources = checked(specification)

    if resources then

        local variants  = fonts.hashes.variants[fontid]

        if variants then
            context.starttabulate { "|c|c|c|c|c|c|c|" }
            for selector, unicodes in sortedhash(variants) do
                local done = false
                for unicode, variant in sortedhash(unicodes) do
                    ctx_NC()
                    if not done then
                        context("%U",selector)
                        done = true
                    end
                    ctx_NC()
                    context("%U",unicode)
                    ctx_NC()
                    context("%c",unicode)
                    ctx_NC()
                    context("%U",variant)
                    ctx_NC()
                    context("%c",variant)
                    ctx_NC()
                    context("%c%c",unicode,selector)
                    ctx_NC()
                    context.startoverlay()
                        context("{\\color[trace:r]{%c}}{\\color[trace:ds]{%c}}",unicode,variant)
                    context.stopoverlay()
                    ctx_NC()
                    ctx_NR()
                end
            end
            context.stoptabulate()
            return
        end

    end

    nothing()

end


local function collectligatures(steps)

    local series = { }
    local stack  = { }
    local max    = 0

    local function make(tree)
        for k, v in sortedhash(tree) do
            if k == "ligature" then
                local n = #stack
                if n > max then
                    max = n
                end
                series[#series+1] = { v, unpack(stack) }
            else
                insert(stack,k)
                make(v)
                remove(stack)
            end
        end
    end

    for i=1,#steps do
        local step     = steps[i]
        local coverage = step.coverage
        if coverage then
            make(coverage)
        end
    end

    return series, max
end

local function banner(index,kind,order)
    ctx_sequence("sequence: %i, kind: %s, features: % t",index,noprefix(kind),order)
end

function tabletracers.showligatures(specification)

    local tfmdata, fontid, resources = checked(specification)

    if resources then

        local characters   = tfmdata.characters
        local descriptions = tfmdata.descriptions
        local sequences    = resources.sequences
        if sequences then
            local done = true
            for index=1,#sequences do
                local sequence = sequences[index]
                local kind     = sequence.type
                if kind == "gsub_ligature" then
                    local list, max = collectligatures(sequence.steps)
                    if #list > 0 then
                        banner(index,kind,sequence.order or { })
                        context.starttabulate { "|T|" .. string.rep("|",max) .. "|T|T|" }
                        for i=1,#list do
                            local s = list[i]
                            local n = #s
                            local u = s[1]
                            local c = characters[u]
                            local d = descriptions[u]
                            ctx_NC()
                            context("%U",u)
                            ctx_NC()
                            ctx_setfontid(fontid)
                            ctx_char(u)
                            ctx_NC()
                            ctx_setfontid(fontid)
                            for i=2,n do
                                ctx_char(s[i])
                                ctx_NC()
                            end
                            for i=n+1,max do
                                ctx_NC()
                            end
                            context(d.name)
                            ctx_NC()
                            context(c.tounicode)
                            ctx_NC()
                            ctx_NR()
                        end
                        context.stoptabulate()
                        done = true
                    end
                end
            end
            if done then
                return
            end
        end
    end

    nothing()

end
