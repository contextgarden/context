if not modules then modules = { } end modules ['lxml-xml'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber, next = tonumber, next
local concat = table.concat
local find, lower, upper = string.find, string.lower, string.upper

local xml = xml

local finalizers     = xml.finalizers.xml
local xmlfilter      = xml.filter -- we could inline this one for speed
local xmltostring    = xml.tostring
local xmlserialize   = xml.serialize
local xmlcollected   = xml.collected
local xmlnewhandlers = xml.newhandlers

local reparsedentity  = xml.reparsedentitylpeg   -- \Ux{...}
local unescapedentity = xml.unescapedentitylpeg
local parsedentity    = reparsedentity

local function first(collected) -- wrong ?
    return collected and collected[1]
end

local function last(collected)
    return collected and collected[#collected]
end

local function all(collected)
    return collected
end

-- local function reverse(collected)
--     if collected then
--         local nc = #collected
--         if nc > 0 then
--             local reversed, r = { }, 0
--             for c=nc,1,-1 do
--                 r = r + 1
--                 reversed[r] = collected[c]
--             end
--             return reversed
--         else
--             return collected
--         end
--     end
-- end

local reverse = table.reversed

local function attribute(collected,name)
    if collected and #collected > 0 then
        local at = collected[1].at
        return at and at[name]
    end
end

local function att(id,name)
    local at = id.at
    return at and at[name]
end

local function count(collected)
    return collected and #collected or 0
end

local function position(collected,n)
    if not collected then
        return 0
    end
    local nc = #collected
    if nc == 0 then
        return 0
    end
    n = tonumber(n) or 0
    if n < 0 then
        return collected[nc + n + 1]
    elseif n > 0 then
        return collected[n]
    else
        return collected[1].mi or 0
    end
end

local function match(collected)
    return collected and #collected > 0 and collected[1].mi or 0 -- match
end

local function index(collected)
    return collected and #collected > 0 and collected[1].ni or 0 -- 0 is new
end

local function attributes(collected,arguments)
    if collected and #collected > 0 then
        local at = collected[1].at
        if arguments then
            return at[arguments]
        elseif next(at) then
            return at -- all of them
        end
    end
end

local function chainattribute(collected,arguments) -- todo: optional levels
    if collected and #collected > 0 then
        local e = collected[1]
        while e do
            local at = e.at
            if at then
                local a = at[arguments]
                if a then
                    return a
                end
            else
                break -- error
            end
            e = e.__p__
        end
    end
    return ""
end

local function raw(collected) -- hybrid (not much different from text so it might go)
    if collected and #collected > 0 then
        local e = collected[1] or collected
        return e and xmltostring(e) or "" -- only first as we cannot concat function
    else
        return ""
    end
end

--

local xmltexthandler = xmlnewhandlers {
    name       = "string",
    initialize = function()
        result = { }
        return result
    end,
    finalize   = function()
        return concat(result)
    end,
    handle     = function(...)
        result[#result+1] = concat { ... }
    end,
    escape     = false,
}

local function xmltotext(root)
    local dt = root.dt
    if not dt then
        return ""
    end
    local nt = #dt -- string or table
    if nt == 0 then
        return ""
    elseif nt == 1 and type(dt[1]) == "string" then
        return dt[1] -- no escaping of " ' < > &
    else
        return xmlserialize(root,xmltexthandler) or ""
    end
end

function xml.serializetotext(root)
    return root and xmlserialize(root,xmltexthandler) or ""
end

--

local function text(collected) -- hybrid
    if collected then -- no # test here !
        local e = collected[1] or collected -- why fallback to element, how about cdata
        return e and xmltotext(e) or ""
    else
        return ""
    end
end

local function texts(collected)
    if not collected then
        return { } -- why no nil
    end
    local nc = #collected
    if nc == 0 then
        return { } -- why no nil
    end
    local t, n = { }, 0
    for c=1,nc do
        local e = collected[c]
        if e and e.dt then
            n = n + 1
            t[n] = e.dt
        end
    end
    return t
end

local function tag(collected,n)
    if not collected then
        return
    end
    local nc = #collected
    if nc == 0 then
        return
    end
    local c
    if n == 0 or not n then
        c = collected[1]
    elseif n > 1 then
        c = collected[n]
    else
        c = collected[nc-n+1]
    end
    return c and c.tg
end

local function name(collected,n)
    if not collected then
        return
    end
    local nc = #collected
    if nc == 0 then
        return
    end
    local c
    if n == 0 or not n then
        c = collected[1]
    elseif n > 1 then
        c = collected[n]
    else
        c = collected[nc-n+1]
    end
    if not c then
        -- sorry
    elseif c.ns == "" then
        return c.tg
    else
        return c.ns .. ":" .. c.tg
    end
end

local function tags(collected,nonamespace)
    if not collected then
        return
    end
    local nc = #collected
    if nc == 0 then
        return
    end
    local t, n = { }, 0
    for c=1,nc do
        local e = collected[c]
        local ns, tg = e.ns, e.tg
        n = n + 1
        if nonamespace or ns == "" then
            t[n] = tg
        else
            t[n] = ns .. ":" .. tg
        end
    end
    return t
end

local function empty(collected,spacesonly)
    if not collected then
        return true
    end
    local nc = #collected
    if nc == 0 then
        return true
    end
    for c=1,nc do
        local e = collected[c]
        if e then
            local edt = e.dt
            if edt then
                local n = #edt
                if n == 1 then
                    local edk = edt[1]
                    local typ = type(edk)
                    if typ == "table" then
                        return false
                    elseif edk ~= "" then
                        return false
                    elseif spacesonly and not find(edk,"%S") then
                        return false
                    end
                elseif n > 1 then
                    return false
                end
            end
        end
    end
    return true
end

finalizers.first          = first
finalizers.last           = last
finalizers.all            = all
finalizers.reverse        = reverse
finalizers.elements       = all
finalizers.default        = all
finalizers.attribute      = attribute
finalizers.att            = att
finalizers.count          = count
finalizers.position       = position
finalizers.match          = match
finalizers.index          = index
finalizers.attributes     = attributes
finalizers.chainattribute = chainattribute
finalizers.text           = text
finalizers.texts          = texts
finalizers.tag            = tag
finalizers.name           = name
finalizers.tags           = tags
finalizers.empty          = empty

-- shortcuts -- we could support xmlfilter(id,pattern,first)

function xml.first(id,pattern)
    return first(xmlfilter(id,pattern))
end

function xml.last(id,pattern)
    return last(xmlfilter(id,pattern))
end

function xml.count(id,pattern)
    return count(xmlfilter(id,pattern))
end

function xml.attribute(id,pattern,a,default)
    return attribute(xmlfilter(id,pattern),a,default)
end

function xml.raw(id,pattern)
    if pattern then
        return raw(xmlfilter(id,pattern))
    else
        return raw(id)
    end
end

function xml.text(id,pattern) -- brrr either content or element (when cdata)
    if pattern then
     -- return text(xmlfilter(id,pattern))
        local collected = xmlfilter(id,pattern)
        return collected and #collected > 0 and xmltotext(collected[1]) or ""
    elseif id then
     -- return text(id)
        return xmltotext(id) or ""
    else
        return ""
    end
end

function xml.pure(id,pattern)
    if pattern then
        local collected = xmlfilter(id,pattern)
        if collected and #collected > 0 then
            parsedentity = unescapedentity
            local s = collected and #collected > 0 and xmltotext(collected[1]) or ""
            parsedentity = reparsedentity
            return s
        else
            return ""
        end
    else
        parsedentity = unescapedentity
        local s = xmltotext(id) or ""
        parsedentity = reparsedentity
        return s
    end
end

xml.content = text

--

function xml.position(id,pattern,n) -- element
    return position(xmlfilter(id,pattern),n)
end

function xml.match(id,pattern) -- number
    return match(xmlfilter(id,pattern))
end

function xml.empty(id,pattern,spacesonly)
    return empty(xmlfilter(id,pattern),spacesonly)
end

xml.all    = xml.filter
xml.index  = xml.position
xml.found  = xml.filter

-- a nice one:

local function totable(x)
    local t = { }
    for e in xmlcollected(x[1] or x,"/*") do
        t[e.tg] = xmltostring(e.dt) or ""
    end
    return next(t) and t or nil
end

xml.table        = totable
finalizers.table = totable

local function textonly(e,t)
    if e then
        local edt = e.dt
        if edt then
            for i=1,#edt do
                local e = edt[i]
                if type(e) == "table" then
                    textonly(e,t)
                else
                    t[#t+1] = e
                end
            end
        end
    end
    return t
end

function xml.textonly(e) -- no pattern
    return concat(textonly(e,{}))
end

--

-- local x = xml.convert("<x><a x='+'>1<B>2</B>3</a></x>")
-- xml.filter(x,"**/lowerall()") print(x)
-- xml.filter(x,"**/upperall()") print(x)

function finalizers.lowerall(collected)
    for c=1,#collected do
        local e = collected[c]
        if not e.special then
            e.tg = lower(e.tg)
            local eat = e.at
            if eat then
                local t = { }
                for k,v in next, eat do
                    t[lower(k)] = v
                end
                e.at = t
            end
        end
    end
end

function finalizers.upperall(collected)
    for c=1,#collected do
        local e = collected[c]
        if not e.special then
            e.tg = upper(e.tg)
            local eat = e.at
            if eat then
                local t = { }
                for k,v in next, eat do
                    t[upper(k)] = v
                end
                e.at = t
            end
        end
    end
end
