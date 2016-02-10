if not modules then modules = { } end modules ['typo-brk'] = {
    version   = 1.001,
    comment   = "companion to typo-brk.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this code dates from the beginning and is kind of experimental; it
-- will be optimized and improved soon

local next, type, tonumber = next, type, tonumber
local utfbyte, utfchar = utf.byte, utf.char
local format = string.format

local trace_breakpoints = false  trackers.register("typesetters.breakpoints", function(v) trace_breakpoints = v end)

local report_breakpoints = logs.reporter("typesetting","breakpoints")

local nodes, node = nodes, node

local settings_to_array  = utilities.parsers.settings_to_array

local nuts               = nodes.nuts
local tonut              = nuts.tonut
local tonode             = nuts.tonode

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getboth            = nuts.getboth
local getsubtype         = nuts.getsubtype
local getchar            = nuts.getchar
local getfont            = nuts.getfont
local getid              = nuts.getid
local getfield           = nuts.getfield
local getattr            = nuts.getattr

local setfield           = nuts.setfield
local setattr            = nuts.setattr
local setlink            = nuts.setlink
local setchar            = nuts.setchar
local setdisc            = nuts.setdisc
local setsubtype         = nuts.setsubtype

local copy_node          = nuts.copy
local copy_nodelist      = nuts.copy_list
local free_node          = nuts.free
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local remove_node        = nuts.remove
local end_of_math        = nuts.end_of_math

local tonodes            = nuts.tonodes

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local nodepool           = nuts.pool
local tasks              = nodes.tasks

local v_reset            = interfaces.variables.reset

local implement          = interfaces.implement

local new_penalty        = nodepool.penalty
local new_glue           = nodepool.glue
local new_disc           = nodepool.disc

local nodecodes          = nodes.nodecodes
local kerncodes          = nodes.kerncodes

local glyph_code         = nodecodes.glyph
local kern_code          = nodecodes.kern
local math_code          = nodecodes.math

local fontkern_code      = kerncodes.fontkern
local userkern_code      = kerncodes.userkern
local italickern_code    = kerncodes.italiccorrection

local typesetters        = typesetters

typesetters.breakpoints  = typesetters.breakpoints or {}
local breakpoints        = typesetters.breakpoints

breakpoints.mapping      = breakpoints.mapping or { }
breakpoints.numbers      = breakpoints.numbers or { }

breakpoints.methods      = breakpoints.methods or { }
local methods            = breakpoints.methods

local a_breakpoints      = attributes.private("breakpoint")

storage.register("typesetters/breakpoints/mapping", breakpoints.mapping, "typesetters.breakpoints.mapping")

local mapping            = breakpoints.mapping
local numbers            = breakpoints.mapping

for i=1,#mapping do
    local m = mapping[i]
    numbers[m.name] = m
end

local function insert_break(head,start,before,after,kern)
    if not kern then
        insert_node_before(head,start,new_penalty(before))
        insert_node_before(head,start,new_glue(0))
    end
    insert_node_after(head,start,new_glue(0))
    insert_node_after(head,start,new_penalty(after))
end

methods[1] = function(head,start,_,kern)
    local p, n = getboth(start)
    if p and n then
        insert_break(head,start,10000,0,kern)
    end
    return head, start
end

methods[2] = function(head,start) -- ( => (-
    local p, n = getboth(start)
    if p and n then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
     -- setfield(start,"attr",copy_nodelist(getfield(tmp,"attr"))) -- just a copy will do
        setfield(start,"attr",getfield(tmp,"attr"))
        setfield(start,"replace",tmp)
        local tmp = copy_node(tmp)
        local hyphen = copy_node(tmp)
        setchar(hyphen,languages.prehyphenchar(getfield(tmp,"lang")))
        setlink(tmp,hyphen)
        setfield(start,"post",tmp)
        insert_break(head,start,10000,10000)
    end
    return head, start
end

methods[3] = function(head,start) -- ) => -)
    local p, n = getboth(start)
    if p and n then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
     -- setfield(start,"attr",copy_nodelist(getfield(tmp,"attr"))) -- just a copy will do
        setfield(start,"attr",getfield(tmp,"attr"))
        setfield(start,"replace",tmp)
        local tmp = copy_node(tmp)
        local hyphen = copy_node(tmp)
        setchar(hyphen,languages.prehyphenchar(getfield(tmp,"lang")))
        setlink(hyphen,tmp)
        setfield(start,"pre",hyphen)
        insert_break(head,start,10000,10000)
    end
    return head, start
end

methods[4] = function(head,start) -- - => - - -
    local p, n = getboth(start)
    if p and n then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
     -- setfield(start,"attr",copy_nodelist(getfield(tmp,"attr"))) -- just a copy will do
        setfield(start,"attr",getfield(tmp,"attr"))
        setdisc(start,copy_node(tmp),copy_node(tmp),tmp)
        insert_break(head,start,10000,10000)
    end
    return head, start
end

methods[5] = function(head,start,settings) -- x => p q r
    local p, n = getboth(start)
    if p and n then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
        local attr = getfield(tmp,"attr")
        local font = getfont(tmp)
        local left = settings.left
        local right = settings.right
        local middle = settings.middle
        if left then
             left = tonodes(tostring(left),font,attr)
        end
        if right then
             right = tonodes(tostring(right),font,attr)
        end
        if middle then
            middle = tonodes(tostring(middle),font,attr)
        end
        setdisc(start,left,right,middle)
     -- setfield(start,"attr",copy_nodelist(attr)) -- todo: critical only -- just a copy will do
        setfield(start,"attr",attr) -- todo: critical only -- just a copy will do
        free_node(tmp)
        insert_break(head,start,10000,10000)
    end
    return head, start
end

-- we know we have a limited set
-- what if characters are replaced by the font handler
-- do we need to go into disc nodes (or do it as first step but then we need a pre/post font handler)

function breakpoints.handler(head)
    local done    = false
    local nead    = tonut(head)
    local attr    = nil
    local map     = nil
    local current = nead
    while current do
        local id = getid(current)
        if id == glyph_code then
            local a = getattr(current,a_breakpoints)
            if a and a > 0 then
                if a ~= attr then
                    local data = mapping[a]
                    if data then
                        map = data.characters
                    else
                        map = nil
                    end
                    attr = a
                end
                if map then
                    local cmap = map[getchar(current)]
                    if cmap then
                        -- for now we collect but when found ok we can move the handler here
                        -- although it saves nothing in terms of performance
                        local d = { current, cmap }
                        if done then
                            done[#done+1] = d
                        else
                            done = { d }
                        end
                        setattr(current,a_breakpoints,unsetvalue) -- should not be needed
                    end
                end
            end
            current = getnext(current)
        elseif id == math_code then
            attr    = nil
            current = end_of_math(current)
            if current then
                current = getnext(current)
            end
        else
            current = getnext(current)
        end
    end
    if not done then
        return head, false
    end
    -- we have hits
    local numbers = languages.numbers
    for i=1,#done do
        local data    = done[i]
        local current = data[1]
        local cmap    = data[2]
        local lang    = getfield(current,"lang")
        -- we do a sanity check for language
        local smap = lang and lang >= 0 and lang < 0x7FFF and (cmap[numbers[lang]] or cmap[""])
        if smap then
            local nleft = smap.nleft
            local cleft = 0
            local prev  = getprev(current)
            local kern   = nil
            while prev and nleft ~= cleft do
                local id = getid(prev)
                if id == glyph_code then
                    cleft = cleft + 1
                    prev  = getprev(prev)
                elseif id == kern_code then
                    local s = getsubtype(prev)
                    if s == fontkern_code or s == italickern_code then
                        if cleft == 0 then
                            kern = prev
                            prev = getprev(prev)
                        else
                            break
                        end
                    else
                        break
                    end
                else
                    break
                end
            end
            if nleft == cleft then
                local nright = smap.nright
                local cright = 0
                local next   = getnext(current)
                while next and nright ~= cright do
                    local id = getid(next)
                    if id == glyph_code then
                        if cright == 1 and cmap[getchar(next)] then
                            -- let's not make it too messy
                            break
                        end
                        cright = cright + 1
                        next   = getnext(next)
                    elseif id == kern_code then
                        local s = getsubtype(next)
                        if s == fontkern_code or s == italickern_code then
                            if cleft == 0 then
                                next = getnext(next)
                            else
                                break
                            end
                        else
                            break
                        end
                    else
                        break
                    end
                end
                if nright == cright then
                    local method = methods[smap.type]
                    if method then
                        nead, start = method(nead,current,smap,kern)
                    end
                end
            end
        end
    end
    return tonode(nead), true
end

local enabled = false

function breakpoints.define(name)
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

function breakpoints.setreplacement(name,char,language,settings)
    char = utfbyte(char)
    local data = numbers[name]
    if data then
        local characters = data.characters
        local cmap = characters[char]
        if not cmap then
            cmap = { }
            characters[char] = cmap
        end
        local left, right, middle = settings.left, settings.right, settings.middle
        cmap[language or ""] = {
            type   = tonumber(settings.type)   or 1,
            nleft  = tonumber(settings.nleft)  or 1,
            nright = tonumber(settings.nright) or 1,
            left   = left   ~= "" and left     or nil,
            right  = right  ~= "" and right    or nil,
            middle = middle ~= "" and middle   or nil,
        } -- was { type or 1, before or 1, after or 1 }
    end
end

function breakpoints.set(n)
    if n == v_reset then
        n = unsetvalue
    else
        n = mapping[n]
        if not n then
            n = unsetvalue
        else
            if not enabled then
                if trace_breakpoints then
                    report_breakpoints("enabling breakpoints handler")
                end
                tasks.enableaction("processors","typesetters.breakpoints.handler")
            end
            n = n.number
        end
    end
    texsetattribute(a_breakpoints,n)
end

-- function breakpoints.enable()
--     tasks.enableaction("processors","typesetters.breakpoints.handler")
-- end

-- interface

implement {
    name      = "definebreakpoints",
    actions   = breakpoints.define,
    arguments = "string"
}

implement {
    name      = "definebreakpoint",
    actions   = breakpoints.setreplacement,
    arguments = {
        "string",
        "string",
        "string",
        {
            { "type", "integer" },
            { "nleft", "integer" },
            { "nright", "integer" },
            { "right" },
            { "left" },
            { "middle" },
        }
    }
}

implement {
    name      = "setbreakpoints",
    actions   = breakpoints.set,
    arguments = "string"
}
