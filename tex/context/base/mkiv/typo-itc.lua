if not modules then modules = { } end modules ['typo-itc'] = {
    version   = 1.001,
    comment   = "companion to typo-itc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber

local trace_italics       = false  trackers.register("typesetters.italics", function(v) trace_italics = v end)

local report_italics      = logs.reporter("nodes","italics")

local threshold           = 0.5   trackers.register("typesetters.threshold", function(v) threshold = v == true and 0.5 or tonumber(v) end)

typesetters.italics       = typesetters.italics or { }
local italics             = typesetters.italics

local nodecodes           = nodes.nodecodes
local glyph_code          = nodecodes.glyph
local kern_code           = nodecodes.kern
local glue_code           = nodecodes.glue
local disc_code           = nodecodes.disc
local math_code           = nodecodes.math

local enableaction        = nodes.tasks.enableaction

local nuts                = nodes.nuts
local nodepool            = nuts.pool

local getprev             = nuts.getprev
local getnext             = nuts.getnext
local getid               = nuts.getid
local getchar             = nuts.getchar
local getdisc             = nuts.getdisc
local getattr             = nuts.getattr
local setattr             = nuts.setattr
local getattrlist         = nuts.getattrlist
local setattrlist         = nuts.setattrlist
local setdisc             = nuts.setdisc
local isglyph             = nuts.isglyph
local setkern             = nuts.setkern
local getkern             = nuts.getkern
local getheight           = nuts.getheight

local insert_node_after   = nuts.insert_after
local delete_node         = nuts.delete
local end_of_math         = nuts.end_of_math

local texgetattribute     = tex.getattribute
local texsetattribute     = tex.setattribute
local a_italics           = attributes.private("italics")
local a_mathitalics       = attributes.private("mathitalics")

local unsetvalue          = attributes.unsetvalue

local new_correction_kern = nodepool.italickern
local new_correction_glue = nodepool.glue

local fonthashes          = fonts.hashes
local fontdata            = fonthashes.identifiers
local italicsdata         = fonthashes.italics
local exheights           = fonthashes.exheights
local chardata            = fonthashes.characters

local is_punctuation      = characters.is_punctuation

local implement           = interfaces.implement

local forcedvariant       = false

function typesetters.italics.forcevariant(variant)
    forcedvariant = variant
end

-- We use the same key as the tex font handler. So, if a valua has already be set, we
-- use that one.

local function setitalicinfont(font,char)
    local tfmdata = fontdata[font]
    local character = tfmdata.characters[char]
    if character then
        local italic = character.italic
        if not italic then
            local autoitalicamount = tfmdata.properties.autoitalicamount or 0
            if autoitalicamount ~= 0 then
                local description = tfmdata.descriptions[char]
                if description then
                    italic = description.italic
                    if not italic then
                        local boundingbox = description.boundingbox
                        italic = boundingbox[3] - description.width + autoitalicamount
                        if italic < 0 then -- < 0 indicates no overshoot or a very small auto italic
                            italic = 0
                        end
                    end
                    if italic ~= 0 then
                        italic = italic * tfmdata.parameters.hfactor
                    end
                end
            end
            if trace_italics then
                report_italics("setting italic correction of %C of font %a to %p",char,font,italic)
            end
            if not italic then
                italic = 0
            end
            character.italic = italic
        end
        return italic
    else
        return 0
    end
end

-- todo: clear attribute

local function okay(data,current,font,prevchar,previtalic,char,what)
    if data then
        if trace_italics then
            report_italics("ignoring %p between %s italic %C and italic %C",previtalic,what,prevchar,char)
        end
        return false
    end
    if threshold then
     -- if getid(current) == glyph_code then
        while current and getid(current) ~= glyph_code do
            current = getprev(current)
        end
        if current then
            local ht = getheight(current)
            local ex = exheights[font]
            local th = threshold * ex
            if ht <= th then
                if trace_italics then
                    report_italics("ignoring correction between %s italic %C and regular %C, height %p less than threshold %p",prevchar,what,char,ht,th)
                end
                return false
            end
        else
            -- maybe backtrack to glyph
        end
    end
    if trace_italics then
        report_italics("inserting %p between %s italic %C and regular %C",previtalic,what,prevchar,char)
    end
    return true
end

-- maybe: with_attributes(current,n) :
--
-- local function correction_kern(kern,n)
--     return with_attributes(new_correction_kern(kern),n)
-- end

local function correction_kern(kern,n)
    local k = new_correction_kern(kern)
    if n then
        local a = getattrlist(n)
        if a then -- maybe not
            setattrlist(k,a) -- can be a marked content (border case)
        end
    end
    return k
end

local function correction_glue(glue,n)
    local g = new_correction_glue(glue)
    if n then
        local a = getattrlist(n)
        if a then -- maybe not
            setattrlist(g,a) -- can be a marked content (border case)
        end
    end
    return g
end

local mathokay   = false
local textokay   = false
local enablemath = false
local enabletext = false

local function domath(head,current)
    current    = end_of_math(current)
    local next = getnext(current)
    if next then
        local char, id = isglyph(next)
        if char then
            -- we can have an old font where italic correction has been applied
            -- or a new one where it hasn't been done
            local kern = getprev(current)
            if kern and getid(kern) == kern_code then
                local glyph = getprev(kern)
                if glyph and getid(glyph) == glyph_code then
                    -- [math: <glyph><kern>]<glyph> : we remove the correction when we have
                    -- punctuation
                    if is_punctuation[char] then
                        local a = getattr(glyph,a_mathitalics)
                        if a and (a < 100 or a > 100) then
                            if a > 100 then
                                a = a - 100
                            else
                                a = a + 100
                            end
                            local i = getkern(kern)
                            local c, f = isglyph(glyph)
                            if getheight(next) < 1.25*exheights[f] then
                                if i == 0 then
                                    if trace_italics then
                                        report_italics("%s italic %p between math %C and punctuation %C","ignoring",i,c,char)
                                    end
                                else
                                    if trace_italics then
                                        report_italics("%s italic between math %C and punctuation %C","removing",i,c,char)
                                    end
                                    setkern(kern,0) -- or maybe a small value or half the ic
                                end
                            elseif i == 0 then
                                local d = chardata[f][c]
                                local i = d.italic
                                if i == 0 then
                                    if trace_italics then
                                        report_italics("%s italic %p between math %C and punctuation %C","ignoring",i,c,char)
                                    end
                                else
                                    setkern(kern,i)
                                    if trace_italics then
                                        report_italics("%s italic %p between math %C and punctuation %C","setting",i,c,char)
                                    end
                                end
                            elseif trace_italics then
                                report_italics("%s italic %p between math %C and punctuation %C","keeping",k,c,char)
                            end
                        end
                    end
                end
            else
                local glyph = kern
                if glyph and getid(glyph) == glyph_code then
                    -- [math: <glyph>]<glyph> : we add the correction when we have
                    -- no punctuation
                    if not is_punctuation[char] then
                        local a = getattr(glyph,a_mathitalics)
                        if a and (a < 100 or a > 100) then
                            if a > 100 then
                                a = a - 100
                            else
                                a = a + 100
                            end
                            if trace_italics then
                                report_italics("%s italic %p between math %C and non punctuation %C","adding",a,getchar(glyph),char)
                            end
                            insert_node_after(head,glyph,correction_kern(a,glyph))
                        end
                    end
                end
            end
        end
    end
    return current
end

local function mathhandler(head)
    local current = head
    while current do
        if getid(current) == math_code then
            current = domath(head,current)
        end
        current = getnext(current)
    end
    return head
end

local function texthandler(head)

    local prev            = nil
    local prevchar        = nil
    local prevhead        = head
    local previtalic      = 0
    local previnserted    = nil

    local pre             = nil
    local pretail         = nil

    local post            = nil
    local posttail        = nil
    local postchar        = nil
    local posthead        = nil
    local postitalic      = 0
    local postinserted    = nil

    local replace         = nil
    local replacetail     = nil
    local replacechar     = nil
    local replacehead     = nil
    local replaceitalic   = 0
    local replaceinserted = nil

    local current         = prevhead
    local lastfont        = nil
    local lastattr        = nil

    while current do
        local char, id = isglyph(current)
        if char then
            local font = id
            local data = italicsdata[font]
            if font ~= lastfont then
                if previtalic ~= 0 then
                    if okay(data,current,font,prevchar,previtalic,char,"glyph") then
                        insert_node_after(prevhead,prev,correction_kern(previtalic,current))
                    end
                elseif previnserted and data then
                    if trace_italics then
                        report_italics("deleting last correction before %s %C",char,"glyph")
                    end
                    delete_node(prevhead,previnserted)
                else
                    --
                    if replaceitalic ~= 0 then
                        if okay(data,replace,font,replacechar,replaceitalic,char,"replace") then
                            insert_node_after(replacehead,replace,correction_kern(replaceitalic,current))
                        end
                        replaceitalic = 0
                    elseif replaceinserted and data then
                        if trace_italics then
                            report_italics("deleting last correction before %s %C","replace",char)
                        end
                        delete_node(replacehead,replaceinserted)
                    end
                    --
                    if postitalic ~= 0 then
                        if okay(data,post,font,postchar,postitalic,char,"post") then
                            insert_node_after(posthead,post,correction_kern(postitalic,current))
                        end
                        postitalic = 0
                    elseif postinserted and data then
                        if trace_italics then
                            report_italics("deleting last correction before %s %C","post",char)
                        end
                        delete_node(posthead,postinserted)
                    end
                end
                --
                lastfont = font
            end
            if data then
                local attr = forcedvariant or getattr(current,a_italics)
                if attr and attr > 0 then
                    local cd = data[char]
                    if not cd then
                        -- this really can happen
                        previtalic = 0
                    else
                        previtalic = cd.italic
                        if not previtalic then
                            previtalic = setitalicinfont(font,char) -- calculated once
                         -- previtalic = 0
                        end
                        if previtalic ~= 0 then
                            lastfont = font
                            lastattr = attr
                            prev     = current
                         -- prevhead = head
                            prevchar = char
                        end
                    end
                else
                    previtalic = 0
                end
            else
                previtalic = 0
            end
            previnserted    = nil
            replaceinserted = nil
            postinserted    = nil
        elseif id == disc_code then
            previnserted    = nil
            previtalic      = 0
            replaceinserted = nil
            replaceitalic   = 0
            postinserted    = nil
            postitalic      = 0
            updated         = false
            replacefont     = nil
            postfont        = nil
            pre, post, replace, pretail, posttail, replacetail = getdisc(current,true)
            if replace then
                local current = replacetail
                while current do
                    local char, id = isglyph(current)
                    if char then
                        local font = id
                        if font ~= lastfont then
                            local data = italicsdata[font]
                            if data then
                                local attr = forcedvariant or getattr(current,a_italics)
                                if attr and attr > 0 then
                                    local cd = data[char]
                                    if not cd then
                                        -- this really can happen
                                        replaceitalic = 0
                                    else
                                        replaceitalic = cd.italic
                                        if not replaceitalic then
                                            replaceitalic = setitalicinfont(font,char) -- calculated once
                                         -- replaceitalic = 0
                                        end
                                        if replaceitalic ~= 0 then
                                            lastfont    = font
                                            lastattr    = attr
                                            replacechar = char
                                            replacehead = replace
                                            updated     = true
                                        end
                                    end
                                end
                            end
                            replacefont = font
                        end
                        break
                    else
                        current = getprev(current)
                    end
                end
            end
            if post then
                local current = posttail
                while current do
                    local char, id = isglyph(current)
                    if char then
                        local font = id
                        if font ~= lastfont then
                            local data = italicsdata[font]
                            if data then
                                local attr = forcedvariant or getattr(current,a_italics)
                                if attr and attr > 0 then
                                    local cd = data[char]
                                    if not cd then
                                        -- this really can happen
                                        -- postitalic = 0
                                    else
                                        postitalic = cd.italic
                                        if not postitalic then
                                            postitalic = setitalicinfont(font,char) -- calculated once
                                         -- postitalic = 0
                                        end
                                        if postitalic ~= 0 then
                                            lastfont = font
                                            lastattr = attr
                                            postchar = char
                                            posthead = post
                                            updated  = true
                                        end
                                    end
                                end
                            end
                            postfont = font
                        end
                        break
                    else
                        current = getprev(current)
                    end
                end
            end
            if replacefont or postfont then
                lastfont = replacefont or postfont
            end
            if updated then
                setdisc(current,pre,post,replace)
            end
        elseif id == kern_code then -- how about fontkern ?
            previnserted    = nil
            previtalic      = 0
            replaceinserted = nil
            replaceitalic   = 0
            postinserted    = nil
            postitalic      = 0
        elseif id == glue_code then
            if previtalic ~= 0 then
                if trace_italics then
                    report_italics("inserting %p between %s italic %C and glue",previtalic,"glyph",prevchar)
                end
                previnserted = correction_glue(previtalic,current) -- maybe just add ? else problem with penalties
                previtalic   = 0
                insert_node_after(prevhead,prev,previnserted)
            else
                if replaceitalic ~= 0 then
                    if trace_italics then
                        report_italics("inserting %p between %s italic %C and glue",replaceitalic,"replace",replacechar)
                    end
                    replaceinserted = correction_kern(replaceitalic,current) -- needs to be a kern
                    replaceitalic   = 0
                    insert_node_after(replacehead,replace,replaceinserted)
                end
                if postitalic ~= 0 then
                    if trace_italics then
                        report_italics("inserting %p between %s italic %C and glue",postitalic,"post",postchar)
                    end
                    postinserted = correction_kern(postitalic,current) -- needs to be a kern
                    postitalic   = 0
                    insert_node_after(posthead,post,postinserted)
                end
            end
        elseif id == math_code then
            -- is this still needed ... the current engine implementation has been redone
            previnserted    = nil
            previtalic      = 0
            replaceinserted = nil
            replaceitalic   = 0
            postinserted    = nil
            postitalic      = 0
            if mathokay then
                current = domath(head,current)
            else
                current = end_of_math(current)
            end
        else
            if previtalic ~= 0 then
                if trace_italics then
                    report_italics("inserting %p between %s italic %C and whatever",previtalic,"glyph",prevchar)
                end
                insert_node_after(prevhead,prev,correction_kern(previtalic,current))
                previnserted    = nil
                previtalic      = 0
                replaceinserted = nil
                replaceitalic   = 0
                postinserted    = nil
                postitalic      = 0
            else
                if replaceitalic ~= 0 then
                    if trace_italics then
                        report_italics("inserting %p between %s italic %C and whatever",replaceitalic,"replace",replacechar)
                    end
                    insert_node_after(replacehead,replace,correction_kern(replaceitalic,current))
                    previnserted    = nil
                    previtalic      = 0
                    replaceinserted = nil
                    replaceitalic   = 0
                    postinserted    = nil
                    postitalic      = 0
                end
                if postitalic ~= 0 then
                    if trace_italics then
                        report_italics("inserting %p between %s italic %C and whatever",postitalic,"post",postchar)
                    end
                    insert_node_after(posthead,post,correction_kern(postitalic,current))
                    previnserted    = nil
                    previtalic      = 0
                    replaceinserted = nil
                    replaceitalic   = 0
                    postinserted    = nil
                    postitalic      = 0
                end
            end
        end
        current = getnext(current)
    end
    if lastattr and lastattr > 1 then -- more control is needed here
        if previtalic ~= 0 then
            if trace_italics then
                report_italics("inserting %p between %s italic %C and end of list",previtalic,"glyph",prevchar)
            end
            insert_node_after(prevhead,prev,correction_kern(previtalic,current))
        else
            if replaceitalic ~= 0 then
                if trace_italics then
                    report_italics("inserting %p between %s italic %C and end of list",replaceitalic,"replace",replacechar)
                end
                insert_node_after(replacehead,replace,correction_kern(replaceitalic,current))
            end
            if postitalic ~= 0 then
                if trace_italics then
                    report_italics("inserting %p between %s italic %C and end of list",postitalic,"post",postchar)
                end
                insert_node_after(posthead,post,correction_kern(postitalic,current))
            end
        end
    end
    return head
end

function italics.handler(head)
    if textokay then
        return texthandler(head)
    elseif mathokay then
        return mathhandler(head)
    else
        return head, false
    end
end

enabletext = function()
    enableaction("processors","typesetters.italics.handler")
    if trace_italics then
        report_italics("enabling text/text italics")
    end
    enabletext = false
    textokay   = true
end

enablemath = function()
    enableaction("processors","typesetters.italics.handler")
    if trace_italics then
        report_italics("enabling math/text italics")
    end
    enablemath = false
    mathokay   = true
end

function italics.enabletext()
    if enabletext then
        enabletext()
    end
end

function italics.enablemath()
    if enablemath then
        enablemath()
    end
end

function italics.set(n)
    if enabletext then
        enabletext()
    end
    if n == variables.reset then
        texsetattribute(a_italics,unsetvalue)
    else
        texsetattribute(a_italics,tonumber(n) or unsetvalue)
    end
end

function italics.reset()
    texsetattribute(a_italics,unsetvalue)
end

implement {
    name      = "setitaliccorrection",
    actions   = italics.set,
    arguments = "string"
}

implement {
    name      = "resetitaliccorrection",
    actions   = italics.reset,
}

local variables        = interfaces.variables
local settings_to_hash = utilities.parsers.settings_to_hash

local function setupitaliccorrection(option) -- no grouping !
    if enabletext then
        enabletext()
    end
    local options = settings_to_hash(option)
    local variant = unsetvalue
    if options[variables.text] then
        variant = 1
    elseif options[variables.always] then
        variant = 2
    end
    -- maybe also keywords for threshold
    if options[variables.global] then
        forcedvariant = variant
        texsetattribute(a_italics,unsetvalue)
    else
        forcedvariant = false
        texsetattribute(a_italics,variant)
    end
    if trace_italics then
        report_italics("forcing %a, variant %a",forcedvariant or "-",variant ~= unsetvalue and variant)
    end
end

implement {
    name      = "setupitaliccorrection",
    actions   = setupitaliccorrection,
    arguments = "string"
}

-- for manuals:

local stack = { }

implement {
    name    = "pushitaliccorrection",
    actions = function()
        table.insert(stack,{forcedvariant, texgetattribute(a_italics) })
    end
}

implement {
    name    = "popitaliccorrection",
    actions = function()
        local top = table.remove(stack)
        forcedvariant = top[1]
        texsetattribute(a_italics,top[2])
    end
}
