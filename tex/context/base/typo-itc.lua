if not modules then modules = { } end modules ['typo-itc'] = {
    version   = 1.001,
    comment   = "companion to typo-itc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utfchar = utf.char

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

local tasks               = nodes.tasks

local nuts                = nodes.nuts
local nodepool            = nuts.pool

local tonode              = nuts.tonode
local tonut               = nuts.tonut

local getfield            = nuts.getfield
local getnext             = nuts.getnext
local getid               = nuts.getid
local getfont             = nuts.getfont
local getchar             = nuts.getchar
local getattr             = nuts.getattr
local setattr             = nuts.setattr

local insert_node_after   = nuts.insert_after
local delete_node         = nuts.delete
local end_of_math         = nuts.end_of_math
local find_tail           = nuts.tail

local texgetattribute     = tex.getattribute
local texsetattribute     = tex.setattribute
local a_italics           = attributes.private("italics")
local unsetvalue          = attributes.unsetvalue

local new_correction_kern = nodepool.fontkern
local new_correction_glue = nodepool.glue

local fonthashes          = fonts.hashes
local fontdata            = fonthashes.identifiers
local italicsdata         = fonthashes.italics
local exheights           = fonthashes.exheights

local forcedvariant       = false

function typesetters.italics.forcevariant(variant)
    forcedvariant = variant
end

local function setitalicinfont(font,char)
    local tfmdata = fontdata[font]
    local character = tfmdata.characters[char]
    if character then
        local italic = character.italic_correction
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
            character.italic_correction = italic or 0
        end
        return italic
    else
        return 0
    end
end

-- todo: clear attribute

local function okay(data,current,font,prevchar,previtalic,char,what)
    if not data then
        if trace_italics then
            report_italics("ignoring %p between %s italic %C and italic %C",previtalic,what,prevchar,char)
        end
        return false
    end
    if threshold then
        local ht = getfield(current,"height")
        local ex = exheights[font]
        local th = threshold * ex
        if ht <= th then
            if trace_italics then
                report_italics("ignoring correction between %s italic %C and regular %C, height %p less than threshold %p",prevchar,what,char,ht,th)
            end
            return false
        end
    end
    if trace_italics then
        report_italics("inserting %p between %s italic %C and regular %C",previtalic,what,prevchar,char)
    end
    return true
end

function italics.handler(head)

    local prev            = nil
    local prevchar        = nil
    local prevhead        = tonut(head)
    local previtalic      = 0
    local previnserted    = nil

    local replace         = nil
    local replacechar     = nil
    local replacehead     = nil
    local replaceitalic   = 0
    local replaceinserted = nil

    local post            = nil
    local postchar        = nil
    local posthead        = nil
    local postitalic      = 0
    local postinserted    = nil

    local current         = prevhead
    local done            = false
    local lastfont        = nil
    local lastattr        = nil

    while current do
        local id = getid(current)
        if id == glyph_code then
            local font = getfont(current)
            local char = getchar(current)
            local data = italicsdata[font]
            if font ~= lastfont then
                if previtalic ~= 0 then
                    if okay(data,current,font,prevchar,previtalic,char,"glyph") then
                        insert_node_after(prevhead,prev,new_correction_kern(previtalic))
                        done = true
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
                            insert_node_after(replacehead,replace,new_correction_kern(replaceitalic))
                            done = true
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
                            insert_node_after(posthead,post,new_correction_kern(postitalic))
                            done = true
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
                        previtalic = cd.italic or cd.italic_correction
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
            replace = getfield(current,"replace")
            if replace then
                local current = find_tail(replace)
                local font = getfont(current)
                local char = getchar(current)
                local data = italicsdata[font]
                if data then
                    local attr = forcedvariant or getattr(current,a_italics)
                    if attr and attr > 0 then
                        local cd = data[char]
                        if not cd then
                            -- this really can happen
                            replaceitalic = 0
                        else
                            replaceitalic = cd.italic or cd.italic_correction
                            if not replaceitalic then
                                replaceitalic = setitalicinfont(font,char) -- calculated once
                             -- replaceitalic = 0
                            end
                            if replaceitalic ~= 0 then
                                lastfont    = font
                                lastattr    = attr
                                replacechar = char
                                replacehead = replace
                                replace     = current
                            end
                        end
                    else
                        replaceitalic = 0
                    end
                else
                    replaceitalic = 0
                end
                replaceinserted = nil
            end
            local post = getfield(current,"post")
            if post then
                local current = find_tail(post)
                local font = getfont(current)
                local char = getchar(current)
                local data = italicsdata[font]
                if data then
                    local attr = forcedvariant or getattr(current,a_italics)
                    if attr and attr > 0 then
                        local cd = data[char]
                        if not cd then
                            -- this really can happen
                            postitalic = 0
                        else
                            postitalic = cd.italic or cd.italic_correction
                            if not postitalic then
                                postitalic = setitalicinfont(font,char) -- calculated once
                             -- postitalic = 0
                            end
                            if postitalic ~= 0 then
                                lastfont = font
                                lastattr = attr
                                postchar = char
                                posthead = post
                                post     = current
                            end
                        end
                    else
                        postitalic = 0
                    end
                else
                    postitalic = 0
                end
                postinserted = nil
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
                previnserted = new_correction_glue(previtalic) -- maybe just add ? else problem with penalties
                previtalic   = 0
                done         = true
                insert_node_after(prevhead,prev,previnserted)
            else
                if replaceitalic ~= 0 then
                    if trace_italics then
                        report_italics("inserting %p between %s italic %C and glue",replaceitalic,"replace",replacechar)
                    end
                    replaceinserted = new_correction_kern(replaceitalic) -- needs to be a kern
                    replaceitalic   = 0
                    done            = true
                    insert_node_after(replacehead,replace,replaceinserted)
                end
                if postitalic ~= 0 then
                    if trace_italics then
                        report_italics("inserting %p between %s italic %C and glue",postitalic,"post",postchar)
                    end
                    postinserted = new_correction_kern(postitalic) -- needs to be a kern
                    postitalic   = 0
                    done         = true
                    insert_node_after(posthead,post,postinserted)
                end
            end
        elseif id == math_code then
            current = end_of_math(current)
        else
            if previtalic ~= 0 then
                if trace_italics then
                    report_italics("inserting %p between %s italic %C and whatever",previtalic,"glyph",prevchar)
                end
                insert_node_after(prevhead,prev,new_correction_kern(previtalic))
                previnserted = nil
                previtalic   = 0
                done         = true
            else
                if replaceitalic ~= 0 then
                    if trace_italics then
                        report_italics("inserting %p between %s italic %C and whatever",replaceritalic,"replace",replacechar)
                    end
                    insert_node_after(replacehead,replace,new_correction_kern(replaceitalic))
                    replaceitalic   = 0
                    replaceinserted = nil
                    done            = true
                end
                if postitalic ~= 0 then
                    if trace_italics then
                        report_italics("inserting %p between %s italic %C and whatever",postitalic,"post",postchar)
                    end
                    insert_node_after(posthead,post,new_correction_kern(postitalic))
                    postinserted = nil
                    postitalic   = 0
                    done         = true
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
            insert_node_after(prevhead,prev,new_correction_kern(previtalic))
            done = true
        else
            if replaceitalic ~= 0 then
                if trace_italics then
                    report_italics("inserting %p between %s italic %C and end of list",replaceitalic,"replace",replacechar)
                end
                insert_node_after(replacehead,replace,new_correction_kern(replaceitalic))
                done = true
            end
            if postitalic ~= 0 then
                if trace_italics then
                    report_italics("inserting %p between %s italic %C and end of list",postitalic,"post",postchar)
                end
                insert_node_after(posthead,post,new_correction_kern(postitalic))
                done = true
            end
        end
    end
    return head, done
end

local enable

enable = function()
    tasks.enableaction("processors","typesetters.italics.handler")
    if trace_italics then
        report_italics("enabling text italics")
    end
    enable = false
end

function italics.set(n)
    if enable then
        enable()
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

local variables        = interfaces.variables
local settings_to_hash = utilities.parsers.settings_to_hash

function commands.setupitaliccorrection(option) -- no grouping !
    if enable then
        enable()
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
        report_italics("forcing %a, variant %a",forcedvariant,variant ~= unsetvalue and variant)
    end
end

-- for manuals:

local stack = { }

function commands.pushitaliccorrection()
    table.insert(stack,{forcedvariant, texgetattribute(a_italics) })
end

function commands.popitaliccorrection()
    local top = table.remove(stack)
    forcedvariant = top[1]
    texsetattribute(a_italics,top[2])
end
