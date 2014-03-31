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
local getsubtype         = nuts.getsubtype
local getchar            = nuts.getchar
local getfont            = nuts.getfont
local getid              = nuts.getid
local getfield           = nuts.getfield
local setfield           = nuts.setfield
local getattr            = nuts.getattr
local setattr            = nuts.setattr

local copy_node          = nuts.copy
local copy_nodelist      = nuts.copy_list
local free_node          = nuts.free
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local remove_node        = nuts.remove

local tonodes            = nuts.tonodes

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local nodepool           = nuts.pool
local tasks              = nodes.tasks

local v_reset            = interfaces.variables.reset

local new_penalty        = nodepool.penalty
local new_glue           = nodepool.glue
local new_disc           = nodepool.disc

local nodecodes          = nodes.nodecodes
local kerncodes          = nodes.kerncodes

local glyph_code         = nodecodes.glyph
local kern_code          = nodecodes.kern

local kerning_code       = kerncodes.kerning

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

local function insert_break(head,start,before,after)
    insert_node_before(head,start,new_penalty(before))
    insert_node_before(head,start,new_glue(0))
    insert_node_after(head,start,new_glue(0))
    insert_node_after(head,start,new_penalty(after))
end

methods[1] = function(head,start)
    if getprev(start) and getnext(start) then
        insert_break(head,start,10000,0)
    end
    return head, start
end

methods[2] = function(head,start) -- ( => (-
    if getprev(start) and getnext(start) then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
        setfield(start,"attr",copy_nodelist(getfield(tmp,"attr"))) -- just a copy will do
        setfield(start,"replace",tmp)
        local tmp = copy_node(tmp)
        local hyphen = copy_node(tmp)
        setfield(hyphen,"char",languages.prehyphenchar(getfield(tmp,"lang")))
        setfield(tmp,"next",hyphen)
        setfield(hyphen,"prev",tmp)
        setfield(start,"post",tmp)
        insert_break(head,start,10000,10000)
    end
    return head, start
end

methods[3] = function(head,start) -- ) => -)
    if getprev(start) and getnext(start) then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
        setfield(start,"attr",copy_nodelist(getfield(tmp,"attr"))) -- just a copy will do
        setfield(start,"replace",tmp)
        local tmp = copy_node(tmp)
        local hyphen = copy_node(tmp)
        setfield(hyphen,"char",languages.prehyphenchar(getfield(tmp,"lang")))
        setfield(tmp,"prev",hyphen)
        setfield(hyphen,"next",tmp)
        setfield(start,"pre",hyphen)
        insert_break(head,start,10000,10000)
    end
    return head, start
end

methods[4] = function(head,start) -- - => - - -
    if getprev(start) and getnext(start) then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
        setfield(start,"attr",copy_nodelist(getfield(tmp,"attr"))) -- just a copy will do
        setfield(start,"pre",copy_node(tmp))
        setfield(start,"post",copy_node(tmp))
        setfield(start,"replace",tmp)
        insert_break(head,start,10000,10000)
    end
    return head, start
end

methods[5] = function(head,start,settings) -- x => p q r
    if getprev(start) and getnext(start) then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
        local attr = getfield(tmp,"attr")
        local font = getfont(tmp)
        local left = settings.left
        local right = settings.right
        local middle = settings.middle
        if left then
            setfield(start,"pre",(tonodes(tostring(left),font,attr))) -- was right
        end
        if right then
            setfield(start,"post",(tonodes(tostring(right),font,attr))) -- was left
        end
        if middle then
            setfield(start,"replace",(tonodes(tostring(middle),font,attr)))
        end
        setfield(start,"attr",copy_nodelist(attr)) -- todo: critical only -- just a copy will do
        free_node(tmp)
        insert_break(head,start,10000,10000)
    end
    return head, start
end

function breakpoints.handler(head)
    head = tonut(head)
    local done, numbers = false, languages.numbers
    local start, n = head, 0
    while start do
        local id = getid(start)
        if id == glyph_code then
            local attr = getattr(start,a_breakpoints)
            if attr and attr > 0 then
                setattr(start,a_breakpoints,unsetvalue) -- maybe test for subtype > 256 (faster)
                -- look ahead and back n chars
                local data = mapping[attr]
                if data then
                    local map = data.characters
                    local cmap = map[getchar(start)]
                    if cmap then
                        local lang = getfield(start,"lang")
                        -- we do a sanity check for language
                        local smap = lang and lang >= 0 and lang < 0x7FFF and (cmap[numbers[lang]] or cmap[""])
                        if smap then
                            if n >= smap.nleft then
                                local m = smap.nright
                                local next = getnext(start)
                                while next do -- gamble on same attribute (not that important actually)
                                    local id = getid(next)
                                    if id == glyph_code then -- gamble on same attribute (not that important actually)
                                        if map[getchar(next)] then
                                            break
                                        elseif m == 1 then
                                            local method = methods[smap.type]
                                            if method then
                                                head, start = method(head,start,smap)
                                                done = true
                                            end
                                            break
                                        else
                                            m = m - 1
                                            next = getnext(next)
                                        end
                                    elseif id == kern_code and getsubtype(next) == kerning_code then
                                        next = getnext(next)
                                        -- ignore intercharacter kerning, will go way
                                    else
                                        -- we can do clever and set n and jump ahead but ... not now
                                        break
                                    end
                                end
                            end
                            n = 0
                        else
                            n = n + 1
                        end
                    else
                         n = n + 1
                    end
                else
                    n = 0
                end
            else
             -- n = n + 1 -- if we want single char handling (|-|) then we will use grouping and then we need this
            end
        elseif id == kern_code and getsubtype(start) == kerning_code then
            -- ignore intercharacter kerning, will go way
        else
            n = 0
        end
        start = getnext(start)
    end
    return tonode(head), done
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

commands.definebreakpoints = breakpoints.define
commands.definebreakpoint  = breakpoints.setreplacement
commands.setbreakpoints    = breakpoints.set
