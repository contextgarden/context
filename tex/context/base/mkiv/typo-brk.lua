if not modules then modules = { } end modules ['typo-brk'] = {
    version   = 1.001,
    comment   = "companion to typo-brk.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this code dates from the beginning and is kind of experimental; it
-- will be optimized and improved soon

local next, type, tonumber, tostring = next, type, tonumber, tostring
local utfbyte, utfchar = utf.byte, utf.char
local format = string.format

local trace_breakpoints = false  trackers.register("typesetters.breakpoints", function(v) trace_breakpoints = v end)

local report_breakpoints = logs.reporter("typesetting","breakpoints")

local nodes, node = nodes, node

local settings_to_array  = utilities.parsers.settings_to_array

local nuts               = nodes.nuts
local tonut              = nuts.tonut

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getboth            = nuts.getboth
local getsubtype         = nuts.getsubtype
local getfont            = nuts.getfont
local getid              = nuts.getid
----- getattr            = nuts.getattr
local getattrlist        = nuts.getattrlist
local takeattr           = nuts.takeattr
local getlang            = nuts.getlang
local isglyph            = nuts.isglyph

local setattr            = nuts.setattr
local setattrlist        = nuts.setattrlist
local setlink            = nuts.setlink
local setchar            = nuts.setchar
local setdisc            = nuts.setdisc
local setnext            = nuts.setnext
local setprev            = nuts.setprev
local setboth            = nuts.setboth
local setsubtype         = nuts.setsubtype

local copy_node          = nuts.copy_node
local copy_node_list     = nuts.copy_list
local flush_node         = nuts.flush_node
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local remove_node        = nuts.remove
local end_of_math        = nuts.end_of_math

local tonodes            = nuts.tonodes

local texsetattribute    = tex.setattribute
local unsetvalue         = attributes.unsetvalue

local nodepool           = nuts.pool
local enableaction       = nodes.tasks.enableaction

local v_reset            = interfaces.variables.reset
local v_yes              = interfaces.variables.yes

local implement          = interfaces.implement

local new_penalty        = nodepool.penalty
local new_glue           = nodepool.glue
local new_disc           = nodepool.disc
local new_wordboundary   = nodepool.wordboundary

local nodecodes          = nodes.nodecodes
local kerncodes          = nodes.kerncodes

local kern_code          = nodecodes.kern
local math_code          = nodecodes.math

local fontkern_code      = kerncodes.fontkern
local italickern_code    = kerncodes.italiccorrection

local is_letter          = characters.is_letter

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

-- this needs a cleanup ... maybe make all of them disc nodes

-- todo: use boundaries

local function insert_break(head,start,stop,before,after,kern)
    if not kern then
        local p = new_penalty(before)
        local g = new_glue()
        setattrlist(p,start)
        setattrlist(g,start)
        insert_node_before(head,start,p)
        insert_node_before(head,start,g)
    end
    local p = new_penalty(after)
    local g = new_glue()
    setattrlist(p,start)
    setattrlist(g,start)
    insert_node_after(head,stop,g)
    insert_node_after(head,stop,p)
end

methods[1] = function(head,start,stop,settings,kern)
    local p, n = getboth(stop)
    if p and n then
        insert_break(head,start,stop,10000,0,kern)
    end
    return head, stop
end

methods[6] = function(head,start,stop,settings,kern)
    local p = getprev(start)
    local n = getnext(stop)
    if p and n then
        if kern then
            insert_break(head,start,stop,10000,0,kern)
        else
            local l = new_wordboundary()
            local d = new_disc()
            local r = new_wordboundary()
            setattrlist(d,start) -- otherwise basemode is forced and we crash
            setlink(p,l,d,r,n)
            if start == stop then
                setboth(start)
                setdisc(d,start,nil,copy_node(start))
            else
                setprev(start)
                setnext(stop)
                setdisc(d,start,nil,copy_node_list(start))
            end
            stop = r
        end
    end
    return head, stop
end

methods[2] = function(head,start) -- ( => (-
    local p, n = getboth(start)
    if p and n then
        local replace
        head, start, replace = remove_node(head,start)
        local post   = copy_node(replace)
        local hyphen = copy_node(post)
        setchar(hyphen,languages.prehyphenchar(getlang(post)))
        setlink(post,hyphen)
        head, start = insert_node_before(head,start,new_disc(nil,post,replace))
        setattrlist(start,replace)
        insert_break(head,start,start,10000,10000)
    end
    return head, start
end

methods[3] = function(head,start) -- ) => -)
    local p, n = getboth(start)
    if p and n then
        local replace
        head, start, replace = remove_node(head,start)
        local pre    = copy_node(replace)
        local hyphen = copy_node(pre)
        setchar(hyphen,languages.prehyphenchar(getlang(pre)))
        setlink(hyphen,pre)
        head, start = insert_node_before(head,start,new_disc(hyphen,nil,replace)) -- so not pre !
        setattrlist(start,tmp)
        insert_break(head,start,start,10000,10000)
    end
    return head, start
end

methods[4] = function(head,start) -- - => - - -
    local p, n = getboth(start)
    if p and n then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start = insert_node_before(head,start,new_disc())
        setattrlist(start,tmp)
        setdisc(start,copy_node(tmp),copy_node(tmp),tmp)
        insert_break(head,start,start,10000,10000)
    end
    return head, start
end

methods[5] = function(head,start,stop,settings) -- x => p q r
    local p, n = getboth(start)
    if p and n then
        local tmp
        head, start, tmp = remove_node(head,start)
        head, start  = insert_node_before(head,start,new_disc())
        local attr   = getattrlist(tmp)
        local font   = getfont(tmp)
        local left   = settings.left
        local right  = settings.right
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
        setattrlist(start,attr)
        flush_node(tmp)
        insert_break(head,start,start,10000,10000)
    end
    return head, start
end

-- we know we have a limited set
-- what if characters are replaced by the font handler
-- do we need to go into disc nodes (or do it as first step but then we need a pre/post font handler)

function breakpoints.handler(head)
    local done    = false
    local attr    = nil
    local map     = nil
    local current = head
    while current do
        local char, id = isglyph(current)
        if char then
         -- local a = getattr(current,a_breakpoints)
            local a = takeattr(current,a_breakpoints)
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
                    local cmap = map[char]
                    if cmap then
                     -- setattr(current,a_breakpoints,unsetvalue) -- should not be needed
                        -- for now we collect but when found ok we can move the handler here
                        -- although it saves nothing in terms of performance
                        local lang = getlang(current)
                        local smap = lang and lang >= 0 and lang < 0x7FFF and (cmap[languages.numbers[lang]] or cmap[""])
                        if smap then
                            local skip  = smap.skip
                            local start = current
                            local stop  = current
                            current = getnext(current)
                            if skip then
                                while current do
                                    local c = isglyph(current)
                                    if c == char then
                                        stop    = current
                                        current = getnext(current)
                                    else
                                        break
                                    end
                                end
                            end
                            local d = { start, stop, cmap, smap, char }
                            if done then
                                done[#done+1] = d
                            else
                                done = { d }
                            end
                        else
                            current = getnext(current)
                        end
                    else
                        current = getnext(current)
                    end
                else
                    current = getnext(current)
                end
            else
                current = getnext(current)
            end
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
        return head
    end
    -- we have hits
 -- local numbers = languages.numbers
    for i=1,#done do
        local data  = done[i]
        local start = data[1]
        local stop  = data[2]
        local cmap  = data[3]
        local smap  = data[4]
        -- we do a sanity check for language
     -- local lang  = getlang(start)
     -- local smap = lang and lang >= 0 and lang < 0x7FFF and (cmap[numbers[lang]] or cmap[""])
     -- if smap then
            local nleft = smap.nleft
            local cleft = 0
            local prev  = getprev(start)
            local kern  = nil
            while prev and nleft ~= cleft do
                local char, id = isglyph(prev)
                if char then
                    if not is_letter[char] then
                        cleft = -1
                        break
                    end
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
                local next   = getnext(stop) -- getnext(start)
                while next and nright ~= cright do
                    local char, id = isglyph(next)
                    if char then
                        if not is_letter[char] then
                            cright = -1
                            break
                        end
                        if cright == 1 and cmap[char] then
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
                        head, start = method(head,start,stop,smap,kern)
                    end
                end
         -- end
        end
    end
    return head
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
            skip   = settings.range == v_yes,
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
                enableaction("processors","typesetters.breakpoints.handler")
            end
            n = n.number
        end
    end
    texsetattribute(a_breakpoints,n)
end

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
            { "range" },
        }
    }
}

implement {
    name      = "setbreakpoints",
    actions   = breakpoints.set,
    arguments = "string"
}
