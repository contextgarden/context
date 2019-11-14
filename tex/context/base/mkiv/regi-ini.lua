if not modules then modules = { } end modules ['regi-ini'] = {
    version   = 1.001,
    comment   = "companion to regi-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Regimes take care of converting the input characters into
<l n='utf'/> sequences. The conversion tables are loaded at
runtime.</p>
--ldx]]--

-- Todo: use regi-imp*.lua instead

local commands, context = commands, context


local tostring = tostring
local utfchar = utf.char
local P, Cs, Cc, lpegmatch = lpeg.P, lpeg.Cs, lpeg.Cc, lpeg.match
local char, gsub, format, gmatch, byte, match, lower = string.char, string.gsub, string.format, string.gmatch, string.byte, string.match, string.lower
local next = next
local insert, remove, fastcopy = table.insert, table.remove, table.fastcopy
local concat = table.concat
local totable = string.totable

local allocate          = utilities.storage.allocate
local sequencers        = utilities.sequencers
local textlineactions   = resolvers.openers.helpers.textlineactions
local setmetatableindex = table.setmetatableindex

--[[ldx--
<p>We will hook regime handling code into the input methods.</p>
--ldx]]--

local trace_translating = false  trackers.register("regimes.translating", function(v) trace_translating = v end)

local report_loading     = logs.reporter("regimes","loading")
local report_translating = logs.reporter("regimes","translating")

regimes        = regimes or { }
local regimes  = regimes

local mapping  = allocate {
    utf = false
}

local backmapping = allocate {
}

-- regimes.mapping  = mapping

local synonyms = { -- backward compatibility list

    ["windows-1250"] = "cp1250",
    ["windows-1251"] = "cp1251",
    ["windows-1252"] = "cp1252",
    ["windows-1253"] = "cp1253",
    ["windows-1254"] = "cp1254",
    ["windows-1255"] = "cp1255",
    ["windows-1256"] = "cp1256",
    ["windows-1257"] = "cp1257",
    ["windows-1258"] = "cp1258",

    ["il1"]          = "8859-1",
    ["il2"]          = "8859-2",
    ["il3"]          = "8859-3",
    ["il4"]          = "8859-4",
    ["il5"]          = "8859-9",
    ["il6"]          = "8859-10",
    ["il7"]          = "8859-13",
    ["il8"]          = "8859-14",
    ["il9"]          = "8859-15",
    ["il10"]         = "8859-16",

    ["iso-8859-1"]   = "8859-1",
    ["iso-8859-2"]   = "8859-2",
    ["iso-8859-3"]   = "8859-3",
    ["iso-8859-4"]   = "8859-4",
    ["iso-8859-9"]   = "8859-9",
    ["iso-8859-10"]  = "8859-10",
    ["iso-8859-13"]  = "8859-13",
    ["iso-8859-14"]  = "8859-14",
    ["iso-8859-15"]  = "8859-15",
    ["iso-8859-16"]  = "8859-16",

    ["latin1"]       = "8859-1",
    ["latin2"]       = "8859-2",
    ["latin3"]       = "8859-3",
    ["latin4"]       = "8859-4",
    ["latin5"]       = "8859-9",
    ["latin6"]       = "8859-10",
    ["latin7"]       = "8859-13",
    ["latin8"]       = "8859-14",
    ["latin9"]       = "8859-15",
    ["latin10"]      = "8859-16",

    ["utf-8"]        = "utf",
    ["utf8"]         = "utf",
    [""]             = "utf",

    ["windows"]      = "cp1252",

    ["pdf"]          = "pdfdoc",

    ["437"]          = "ibm",
}

local currentregime = "utf"

local function loadregime(mapping,regime)
    regime = lower(tostring(regime))
    regime = synonyms[regime] or synonyms["windows-"..regime] or regime
    local name = resolvers.findfile(format("regi-%s.lua",regime)) or ""
    local data = name ~= "" and dofile(name)
    if data then
        vector = { }
        for eightbit, unicode in next, data do
            vector[char(eightbit)] = utfchar(unicode)
        end
        report_loading("vector %a is loaded",regime)
    else
        vector = false
        report_loading("vector %a is unknown",regime)
    end
    mapping[regime] = vector
    return vector
end

local function loadreverse(t,k)
    local t = { }
    local m = mapping[k]
    if m then
        for k, v in next, m do
            t[v] = k
        end
    end
    backmapping[k] = t
    return t
end

setmetatableindex(mapping,    loadregime)
setmetatableindex(backmapping,loadreverse)

regimes.mapping     = mapping
regimes.backmapping = backmapping

local function fromregime(regime,line)
    if line and #line > 0 then
--         local map = mapping[regime and synonyms[regime] or regime or currentregime]
        local map = mapping[regime or currentregime]
        if map then
            line = gsub(line,".",map)
        end
    end
    return line
end

-- local remappers = { }
--
-- local function toregime(vector,str,default) -- toregime('8859-1',"abcde Ä","?")
--     local t = backmapping[vector]
--     local remapper = remappers[vector]
--     if not remapper then
--         remapper = utf.remapper(t)
--         remappers[t] = remapper
--     end
--     local m = getmetatable(t)
--     setmetatableindex(t, function(t,k)
--         local v = default or "?"
--         t[k] = v
--         return v
--     end)
--     str = remapper(str)
--     setmetatable(t,m)
--     return str
-- end
--
-- -- much faster (but only matters when we have > 10K calls

local cache = { } -- if really needed we can copy vectors and hash defaults

setmetatableindex(cache, function(t,k)
    local v = { remappers = { } }
    t[k] = v
    return v
end)

local function toregime(vector,str,default) -- toregime('8859-1',"abcde Ä","?")
    local d = default or "?"
    local c = cache[vector].remappers
    local r = c[d]
    if not r then
        local t = fastcopy(backmapping[vector])
     -- r = utf.remapper(t) -- not good for defaults here
        local pattern = Cs((lpeg.utfchartabletopattern(t)/t + lpeg.patterns.utf8character/d + P(1)/d)^0)
        r = function(str)
            if not str or str == "" then
                return ""
            else
                return lpegmatch(pattern,str)
            end
        end
        c[d]  = r
    end
    return r(str)
end

local function disable()
    currentregime = "utf"
    sequencers.disableaction(textlineactions,"regimes.process")
    return currentregime
end

local function enable(regime)
    regime = synonyms[regime] or regime
    if mapping[regime] == false then
        disable()
    else
        currentregime = regime
        sequencers.enableaction(textlineactions,"regimes.process")
    end
    return currentregime
end

regimes.toregime   = toregime
regimes.fromregime = fromregime
regimes.translate  = function(str,regime) return fromregime(regime,str) end
regimes.enable     = enable
regimes.disable    = disable

-- The following function can be used when we want to make sure that
-- utf gets passed unharmed. This is needed for modules.

local level = 0

function regimes.process(str,filename,currentline,noflines,coding)
    if level == 0 and coding ~= "utf-8" then
        str = fromregime(currentregime,str)
        if trace_translating then
            report_translating("utf: %s",str)
        end
    end
    return str
end

local function push()
    level = level + 1
    if trace_translating then
        report_translating("pushing level %s",level)
    end
end

local function pop()
    if level > 0 then
        if trace_translating then
            report_translating("popping level %s",level)
        end
        level = level - 1
    end
end

regimes.push = push
regimes.pop  = pop

function regimes.list()
    local name = resolvers.findfile(format("regi-ini.lua",regime)) or ""
    local okay = { }
    if name then
        local list = dir.glob(file.join(file.dirname(name),"regi-*.lua"))
        for i=1,#list do
            local name = list[i]
            if name ~= "regi-ini.lua" then
                okay[#okay+1] = match(name,"regi%-(.-)%.lua")
            end
            table.sort(okay)
        end
    end
    return okay
end

if sequencers then

    sequencers.prependaction(textlineactions,"system","regimes.process")
    sequencers.disableaction(textlineactions,"regimes.process")

end

-- Next we provide some hacks. Unfortunately we run into crappy encoded
-- (read : mixed) encoded xml files that have these Ã« Ã¤ Ã¶ Ã¼ sequences
-- instead of ë ä ö ü

local patterns = { }

-- function regimes.cleanup(regime,str)
--     local p = patterns[regime]
--     if p == nil then
--         regime = regime and synonyms[regime] or regime or currentregime
--         local vector = regime ~= "utf" and mapping[regime]
--         if vector then
--             local list = { }
--             for k, uchar in next, vector do
--                 local stream = totable(uchar)
--                 for i=1,#stream do
--                     stream[i] = vector[stream[i]]
--                 end
--                 list[concat(stream)] = uchar
--             end
--             p = lpeg.append(list,nil,true)
--             p = Cs((p+1)^0)
--          -- lpeg.print(p) -- size 1604
--         else
--             p = false
--         end
--         patterns[vector] = p
--     end
--     return p and lpegmatch(p,str) or str
-- end
--
-- twice as fast and much less lpeg bytecode

-- function regimes.cleanup(regime,str)
--     if not str or str == "" then
--         return str
--     end
--     local p = patterns[regime]
--     if p == nil then
--         regime = regime and synonyms[regime] or regime or currentregime
--         local vector = regime ~= "utf" and regime ~= "utf-8" and mapping[regime]
--         if vector then
--             local utfchars = { }
--             local firsts = { }
--             for k, uchar in next, vector do
--                 local stream = { }
--                 local split = totable(uchar)
--                 local nofsplits = #split
--                 if nofsplits > 1 then
--                     local first
--                     for i=1,nofsplits do
--                         local u = vector[split[i]]
--                         if not first then
--                             first = firsts[u]
--                             if not first then
--                                 first = { }
--                                 firsts[u] = first
--                             end
--                         end
--                         stream[i] = u
--                     end
--                     local nofstream = #stream
--                     if nofstream > 1 then
--                         first[#first+1] = concat(stream,2,nofstream)
--                         utfchars[concat(stream)] = uchar
--                     end
--                 end
--             end
--             p = P(false)
--             for k, v in next, firsts do
--                 local q = P(false)
--                 for i=1,#v do
--                     q = q + P(v[i])
--                 end
--                 p = p + P(k) * q
--             end
--             p = Cs(((p+1)/utfchars)^1)
--          -- lpeg.print(p) -- size: 1042
--         else
--             p = false
--         end
--         patterns[regime] = p
--     end
--     return p and lpegmatch(p,str) or str
-- end
--
-- 5 times faster:

function regimes.cleanup(regime,str)
    if not str or str == "" then
        return str
    end
    local p = patterns[regime]
    if p == nil then
        regime = regime and synonyms[regime] or regime or currentregime
        local vector = regime ~= "utf" and regime ~= "utf-8" and mapping[regime]
        if vector then
            local mapping = { }
            for k, v in next, vector do
                local split = totable(v)
                for i=1,#split do
                    split[i] = utfchar(byte(split[i]))
                end
                split = concat(split)
                if v ~= split then
                    mapping[split] = v
                end
            end
            p = Cs((lpeg.utfchartabletopattern(mapping)/mapping+P(1))^0)
        else
            p = false
        end
        patterns[regime] = p
    end
    return p and lpegmatch(p,str) or str
end

-- local old = [[test Ã« Ã¤ Ã¶ Ã¼ crap]]
-- local new = regimes.cleanup("cp1252",old)
-- report_translating("%s -> %s",old,new)
-- local old = "Pozn" .. char(0xE1) .. "mky"
-- local new = fromregime("cp1250",old)
-- report_translating("%s -> %s",old,new)

-- interface (might move to regi-tex.lua)

if interfaces then

    local implement = interfaces.implement
    local setmacro  = interfaces.setmacro

    implement {
        name      = "enableregime",
        arguments = "string",
        actions   = function(regime) setmacro("currentregime",enable(regime)) end
    }

    implement {
        name      = "disableregime",
        actions   = function() setmacro("currentregime",disable()) end
    }

    implement {
        name      = "pushregime",
        actions   = push
    }

    implement {
        name      = "popregime",
        actions   = pop
    }

    local stack = { }

    implement {
        name      = "startregime",
        arguments = "string",
        actions   = function(regime)
            insert(stack,currentregime)
            if trace_translating then
                report_translating("start using %a",regime)
            end
            setmacro("currentregime",enable(regime))
        end
    }

    implement {
        name      = "stopregime",
        actions   = function()
            if #stack > 0 then
                local regime = remove(stack)
                if trace_translating then
                    report_translating("stop using %a",regime)
                end
                setmacro("currentregime",enable(regime))
            end
        end
    }

end

-- Actually we can have a function returned from the lookup but we don't
-- really use this code so I'm in no hurry.

-- if os.getcodepage then
--     local cod, acp, map
--     function os.tocodepage(name)
--         if map == nil then
--             cod, acp = os.getcodepage()
--             map = cod and cod ~= 65001 and regimes.toregime
--         end
--         return map and map(cod,name) or name
--     end
-- else
--     function os.tocodepage(name)
--         return name
--     end
-- end
