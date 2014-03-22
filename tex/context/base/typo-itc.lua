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

function italics.handler(head)
    head = tonut(head)
    local done     = false
    local italic   = 0
    local lastfont = nil
    local lastattr = nil
    local previous = nil
    local prevchar = nil
    local current  = head
    local inserted = nil
    while current do
        local id = getid(current)
        if id == glyph_code then
            local font = getfont(current)
            local char = getchar(current)
            local data = italicsdata[font]
            if font ~= lastfont then
                if italic ~= 0 then
                    if data then
                        if trace_italics then
                            report_italics("ignoring %p between italic %C and italic %C",italic,prevchar,char)
                        end
                    else
                        local okay = true
                        if threshold then
                            local ht = getfield(current,"height")
                            local ex = exheights[font]
                            local th = threshold * ex
                            if ht <= th then
                                if trace_italics then
                                    report_italics("ignoring correction between italic %C and regular %C, height %p less than threshold %p",prevchar,char,ht,th)
                                end
                                okay = false
                            end
                        end
                        if okay then
                            if trace_italics then
                                report_italics("inserting %p between italic %C and regular %C",italic,prevchar,char)
                            end
                            insert_node_after(head,previous,new_correction_kern(italic))
                            done = true
                        end
                    end
                elseif inserted and data then
                    if trace_italics then
                        report_italics("deleting last correction before %C",char)
                    end
                    delete_node(head,inserted)
                else
                    -- nothing
                end
                lastfont = font
            end
            if data then
                local attr = forcedvariant or getattr(current,a_italics)
                if attr and attr > 0 then
                    local cd = data[char]
                    if not cd then
                        -- this really can happen
                        italic = 0
                    else
                        italic = cd.italic or cd.italic_correction
                        if not italic then
                            italic = setitalicinfont(font,char) -- calculated once
                         -- italic = 0
                        end
                        if italic ~= 0 then
                            lastfont = font
                            lastattr = attr
                            previous = current
                            prevchar = char
                        end
                    end
                else
                    italic = 0
                end
            else
                italic = 0
            end
            inserted = nil
        elseif id == disc_code then
            -- skip
        elseif id == kern_code then
            inserted = nil
            italic = 0
        elseif id == glue_code then
            if italic ~= 0 then
                if trace_italics then
                    report_italics("inserting %p between italic %C and glue",italic,prevchar)
                end
                inserted = new_correction_glue(italic) -- maybe just add ? else problem with penalties
                insert_node_after(head,previous,inserted)
                italic = 0
                done = true
            end
        elseif id == math_code then
            current = end_of_math(current)
        elseif italic ~= 0 then
            if trace_italics then
                report_italics("inserting %p between italic %C and whatever",italic,prevchar)
            end
            inserted = nil
            insert_node_after(head,previous,new_correction_kern(italic))
            italic = 0
            done = true
        end
        current = getnext(current)
    end
    if italic ~= 0 and lastattr > 1 then -- more control is needed here
        if trace_italics then
            report_italics("inserting %p between italic %C and end of list",italic,prevchar)
        end
        insert_node_after(head,previous,new_correction_kern(italic))
        done = true
    end
    return tonode(head), done
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
