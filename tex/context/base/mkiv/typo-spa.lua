if not modules then modules = { } end modules ['typo-spa'] = {
    version   = 1.001,
    comment   = "companion to typo-spa.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type

local trace_spacing = false  trackers.register("typesetters.spacing", function(v) trace_spacing = v end)

local report_spacing = logs.reporter("typesetting","spacing")

local nodes, fonts, node = nodes, fonts, node

local fonthashes         = fonts.hashes
local quaddata           = fonthashes.quads

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local v_reset            = interfaces.variables.reset

local nuts               = nodes.nuts

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local takeattr           = nuts.takeattr
local isglyph            = nuts.isglyph

local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local remove_node        = nuts.remove
local end_of_math        = nuts.end_of_math

local nodepool           = nuts.pool
local new_penalty        = nodepool.penalty
local new_glue           = nodepool.glue

local nodecodes          = nodes.nodecodes
local math_code          = nodecodes.math

local somespace          = nodes.somespace
local somepenalty        = nodes.somepenalty

local enableaction       = nodes.tasks.enableaction

typesetters              = typesetters or { }
local typesetters        = typesetters

typesetters.spacings     = typesetters.spacings or { }
local spacings           = typesetters.spacings

spacings.mapping         = spacings.mapping or { }
spacings.numbers         = spacings.numbers or { }

local a_spacings         = attributes.private("spacing")

storage.register("typesetters/spacings/mapping", spacings.mapping, "typesetters.spacings.mapping")

local mapping = spacings.mapping
local numbers = spacings.numbers

for i=1,#mapping do
    local m = mapping[i]
    numbers[m.name] = m
end

-- todo cache lastattr

function spacings.handler(head)
    local start = head
    -- head is always begin of par (whatsit), so we have at least two prev nodes
    -- penalty followed by glue
    while start do
        local char, id = isglyph(start)
        if char then
            local attr = takeattr(start,a_spacings)
            if attr and attr > 0 then
                local data = mapping[attr]
                if data then
                    local map = data.characters[char]
                    if map then
                        local font = id
                        local left = map.left
                        local right = map.right
                        local alternative = map.alternative
                        local quad = quaddata[font]
                        local prev = getprev(start)
                        if left and left ~= 0 and prev then
                            local ok = false
                            local prevprev = getprev(prev)
                            if alternative == 1 then
                                local somespace = somespace(prev,true)
                                if somespace then
                                    local somepenalty = somepenalty(prevprev,10000)
                                    if somepenalty then
                                        if trace_spacing then
                                            report_spacing("removing penalty and space before %C (left)",char)
                                        end
                                        head = remove_node(head,prev,true)
                                        head = remove_node(head,prevprev,true)
                                    else
                                        if trace_spacing then
                                            report_spacing("removing space before %C (left)",char)
                                        end
                                        head = remove_node(head,prev,true)
                                    end
                                end
                                ok = true
                            else
                                ok = not (somespace(prev,true) and somepenalty(prevprev,true)) or somespace(prev,true)
                            end
                            if ok then
                                if trace_spacing then
                                    report_spacing("inserting penalty and space before %C (left)",char)
                                end
                                insert_node_before(head,start,new_penalty(10000))
                                insert_node_before(head,start,new_glue(left*quad))
                            end
                        end
                        local next = getnext(start)
                        if right and right ~= 0 and next then
                            local ok = false
                            local nextnext = getnext(next)
                            if alternative == 1 then
                                local somepenalty = somepenalty(next,10000)
                                if somepenalty then
                                    local somespace = somespace(nextnext,true)
                                    if somespace then
                                        if trace_spacing then
                                            report_spacing("removing penalty and space after %C right",char)
                                        end
                                        head = remove_node(head,next,true)
                                        head = remove_node(head,nextnext,true)
                                    end
                                else
                                    local somespace = somespace(next,true)
                                    if somespace then
                                        if trace_spacing then
                                            report_spacing("removing space after %C (right)", char)
                                        end
                                        head = remove_node(head,next,true)
                                    end
                                end
                                ok = true
                            else
                                ok = not (somepenalty(next,10000) and somespace(nextnext,true)) or somespace(next,true)
                            end
                            if ok then
                                if trace_spacing then
                                    report_spacing("inserting penalty and space after %C (right)",char)
                                end
                                insert_node_after(head,start,new_glue(right*quad))
                                insert_node_after(head,start,new_penalty(10000))
                            end
                        end
                    end
                end
            end
        elseif id == math_code then
            start = end_of_math(start) -- weird, can return nil .. no math end?
        end
        if start then
            start = getnext(start)
        end
    end
    return head
end

local enabled = false

function spacings.define(name)
    local data = numbers[name]
    if data then
        -- error
    else
        local number = #mapping + 1
        local data = {
            name       = name,
            number     = number,
            characters = { },
        }
        mapping[number] = data
        numbers[name]   = data
    end
end

function spacings.setup(name,char,settings)
    local data = numbers[name]
    if not data then
        -- error
    else
        data.characters[char] = settings
    end
end

function spacings.set(name)
    local n = unsetvalue
    if name ~= v_reset then
        local data = numbers[name]
        if data then
            if not enabled then
                enableaction("processors","typesetters.spacings.handler")
                enabled = true
            end
            n = data.number or unsetvalue
        end
    end
    texsetattribute(a_spacings,n)
end

function spacings.reset()
    texsetattribute(a_spacings,unsetvalue)
end

-- interface

local implement = interfaces.implement

implement {
    name      = "definecharacterspacing",
    actions   = spacings.define,
    arguments = "string"
}

implement {
    name      = "setupcharacterspacing",
    actions   = spacings.setup,
    arguments = {
        "string",
        "integer",
        {
            { "left",        "number" },
            { "right",       "number" },
            { "alternative", "integer" },
        }
    }
}

implement {
    name      = "setcharacterspacing",
    actions   = spacings.set,
    arguments = "string"
}
