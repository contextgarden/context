if not modules then modules = { } end modules ['util-prs'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lpeg, table, string = lpeg, table, string
local P, R, V, S, C, Ct, Cs, Carg, Cc, Cg, Cf, Cp = lpeg.P, lpeg.R, lpeg.V, lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cs, lpeg.Carg, lpeg.Cc, lpeg.Cg, lpeg.Cf, lpeg.Cp
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local concat, gmatch, find = table.concat, string.gmatch, string.find
local tostring, type, next, rawset = tostring, type, next, rawset
local mod, div = math.mod, math.div

utilities         = utilities or {}
local parsers     = utilities.parsers or { }
utilities.parsers = parsers
local patterns    = parsers.patterns or { }
parsers.patterns  = patterns

local setmetatableindex = table.setmetatableindex
local sortedhash        = table.sortedhash

-- we share some patterns

local digit       = R("09")
local space       = P(' ')
local equal       = P("=")
local comma       = P(",")
local lbrace      = P("{")
local rbrace      = P("}")
local lparent     = P("(")
local rparent     = P(")")
local period      = S(".")
local punctuation = S(".,:;")
local spacer      = lpegpatterns.spacer
local whitespace  = lpegpatterns.whitespace
local newline     = lpegpatterns.newline
local anything    = lpegpatterns.anything
local endofstring = lpegpatterns.endofstring

local nobrace     = 1 - (lbrace  + rbrace )
local noparent    = 1 - (lparent + rparent)

-- we could use a Cf Cg construct

local escape, left, right = P("\\"), P('{'), P('}')

lpegpatterns.balanced = P {
    [1] = ((escape * (left+right)) + (1 - (left+right)) + V(2))^0,
    [2] = left * V(1) * right
}

local nestedbraces  = P { lbrace * (nobrace + V(1))^0 * rbrace }
local nestedparents = P { lparent * (noparent + V(1))^0 * rparent }
local spaces        = space^0
local argument      = Cs((lbrace/"") * ((nobrace + nestedbraces)^0) * (rbrace/""))
local content       = (1-endofstring)^0

lpegpatterns.nestedbraces  = nestedbraces  -- no capture
lpegpatterns.nestedparents = nestedparents -- no capture
lpegpatterns.nested        = nestedbraces  -- no capture
lpegpatterns.argument      = argument      -- argument after e.g. =
lpegpatterns.content       = content       -- rest after e.g =

local value     = P(lbrace * C((nobrace + nestedbraces)^0) * rbrace) + C((nestedbraces + (1-comma))^0)

local key       = C((1-equal-comma)^1)
local pattern_a = (space+comma)^0 * (key * equal * value + key * C(""))
local pattern_c = (space+comma)^0 * (key * equal * value)

local key       = C((1-space-equal-comma)^1)
local pattern_b = spaces * comma^0 * spaces * (key * ((spaces * equal * spaces * value) + C("")))

-- "a=1, b=2, c=3, d={a{b,c}d}, e=12345, f=xx{a{b,c}d}xx, g={}" : outer {} removes, leading spaces ignored

-- todo: rewrite to fold etc
--
-- parse = lpeg.Cf(lpeg.Carg(1) * lpeg.Cg(key * equal * value) * separator^0,rawset)^0 -- lpeg.match(parse,"...",1,hash)

local hash = { }

local function set(key,value)
    hash[key] = value
end

local pattern_a_s = (pattern_a/set)^1
local pattern_b_s = (pattern_b/set)^1
local pattern_c_s = (pattern_c/set)^1

patterns.settings_to_hash_a = pattern_a_s
patterns.settings_to_hash_b = pattern_b_s
patterns.settings_to_hash_c = pattern_c_s

function parsers.make_settings_to_hash_pattern(set,how)
    if type(str) == "table" then
        return set
    elseif how == "strict" then
        return (pattern_c/set)^1
    elseif how == "tolerant" then
        return (pattern_b/set)^1
    else
        return (pattern_a/set)^1
    end
end

function parsers.settings_to_hash(str,existing)
    if type(str) == "table" then
        if existing then
            for k, v in next, str do
                existing[k] = v
            end
            return exiting
        else
            return str
        end
    elseif str and str ~= "" then
        hash = existing or { }
        lpegmatch(pattern_a_s,str)
        return hash
    else
        return { }
    end
end

function parsers.settings_to_hash_tolerant(str,existing)
    if type(str) == "table" then
        if existing then
            for k, v in next, str do
                existing[k] = v
            end
            return exiting
        else
            return str
        end
    elseif str and str ~= "" then
        hash = existing or { }
        lpegmatch(pattern_b_s,str)
        return hash
    else
        return { }
    end
end

function parsers.settings_to_hash_strict(str,existing)
    if type(str) == "table" then
        if existing then
            for k, v in next, str do
                existing[k] = v
            end
            return exiting
        else
            return str
        end
    elseif str and str ~= "" then
        hash = existing or { }
        lpegmatch(pattern_c_s,str)
        return next(hash) and hash
    else
        return nil
    end
end

local separator = comma * space^0
local value     = P(lbrace * C((nobrace + nestedbraces)^0) * rbrace)
                + C((nestedbraces + (1-comma))^0)
local pattern   = spaces * Ct(value*(separator*value)^0)

-- "aap, {noot}, mies" : outer {} removes, leading spaces ignored

patterns.settings_to_array = pattern

-- we could use a weak table as cache

function parsers.settings_to_array(str,strict)
    if type(str) == "table" then
        return str
    elseif not str or str == "" then
        return { }
    elseif strict then
        if find(str,"{",1,true) then
            return lpegmatch(pattern,str)
        else
            return { str }
        end
    elseif find(str,",",1,true) then
        return lpegmatch(pattern,str)
    else
        return { str }
    end
end

-- this one also strips end spaces before separators
--
-- "{123} , 456  " -> "123" "456"

local separator = space^0 * comma * space^0
local value     = P(lbrace * C((nobrace + nestedbraces)^0) * rbrace)
                + C((nestedbraces + (1-(space^0*(comma+P(-1)))))^0)
local withvalue = Carg(1) * value / function(f,s) return f(s) end
local pattern_a = spaces * Ct(value*(separator*value)^0)
local pattern_b = spaces * withvalue * (separator*withvalue)^0

function parsers.stripped_settings_to_array(str)
    if not str or str == "" then
        return { }
    else
        return lpegmatch(pattern_a,str)
    end
end

function parsers.process_stripped_settings(str,action)
    if not str or str == "" then
        return { }
    else
        return lpegmatch(pattern_b,str,1,action)
    end
end

-- parsers.process_stripped_settings("{123} , 456  ",function(s) print("["..s.."]") end)
-- parsers.process_stripped_settings("123 , 456  ",function(s) print("["..s.."]") end)

--

local function set(t,v)
    t[#t+1] = v
end

local value   = P(Carg(1)*value) / set
local pattern = value*(separator*value)^0 * Carg(1)

function parsers.add_settings_to_array(t,str)
    return lpegmatch(pattern,str,nil,t)
end

function parsers.hash_to_string(h,separator,yes,no,strict,omit)
    if h then
        local t, tn, s = { }, 0, table.sortedkeys(h)
        omit = omit and table.tohash(omit)
        for i=1,#s do
            local key = s[i]
            if not omit or not omit[key] then
                local value = h[key]
                if type(value) == "boolean" then
                    if yes and no then
                        if value then
                            tn = tn + 1
                            t[tn] = key .. '=' .. yes
                        elseif not strict then
                            tn = tn + 1
                            t[tn] = key .. '=' .. no
                        end
                    elseif value or not strict then
                        tn = tn + 1
                        t[tn] = key .. '=' .. tostring(value)
                    end
                else
                    tn = tn + 1
                    t[tn] = key .. '=' .. value
                end
            end
        end
        return concat(t,separator or ",")
    else
        return ""
    end
end

function parsers.array_to_string(a,separator)
    if a then
        return concat(a,separator or ",")
    else
        return ""
    end
end

function parsers.settings_to_set(str,t) -- tohash? -- todo: lpeg -- duplicate anyway
    t = t or { }
--  for s in gmatch(str,"%s*([^, ]+)") do -- space added
    for s in gmatch(str,"[^, ]+") do -- space added
        t[s] = true
    end
    return t
end

function parsers.simple_hash_to_string(h, separator)
    local t, tn = { }, 0
    for k, v in sortedhash(h) do
        if v then
            tn = tn + 1
            t[tn] = k
        end
    end
    return concat(t,separator or ",")
end

-- for mtx-context etc: aaaa bbbb cccc=dddd eeee=ffff

local str      = C((1-whitespace-equal)^1)
local setting  = Cf( Carg(1) * (whitespace^0 * Cg(str * whitespace^0 * (equal * whitespace^0 * str + Cc(""))))^1,rawset)
local splitter = setting^1

function utilities.parsers.options_to_hash(str,target)
    return str and lpegmatch(splitter,str,1,target or { }) or { }
end

-- for chem (currently one level)

local value     = P(lbrace * C((nobrace + nestedbraces)^0) * rbrace)
                + C(digit^1 * lparent * (noparent + nestedparents)^1 * rparent)
                + C((nestedbraces + (1-comma))^1)
local pattern_a = spaces * Ct(value*(separator*value)^0)

local function repeater(n,str)
    if not n then
        return str
    else
        local s = lpegmatch(pattern_a,str)
        if n == 1 then
            return unpack(s)
        else
            local t, tn = { }, 0
            for i=1,n do
                for j=1,#s do
                    tn = tn + 1
                    t[tn] = s[j]
                end
            end
            return unpack(t)
        end
    end
end

local value     = P(lbrace * C((nobrace + nestedbraces)^0) * rbrace)
                + (C(digit^1)/tonumber * lparent * Cs((noparent + nestedparents)^1) * rparent) / repeater
                + C((nestedbraces + (1-comma))^1)
local pattern_b = spaces * Ct(value*(separator*value)^0)

function parsers.settings_to_array_with_repeat(str,expand) -- beware: "" =>  { }
    if expand then
        return lpegmatch(pattern_b,str) or { }
    else
        return lpegmatch(pattern_a,str) or { }
    end
end

--

local value   = lbrace * C((nobrace + nestedbraces)^0) * rbrace
local pattern = Ct((space + value)^0)

function parsers.arguments_to_table(str)
    return lpegmatch(pattern,str)
end

-- temporary here (unoptimized)

function parsers.getparameters(self,class,parentclass,settings)
    local sc = self[class]
    if not sc then
        sc = { }
        self[class] = sc
        if parentclass then
            local sp = self[parentclass]
            if not sp then
                sp = { }
                self[parentclass] = sp
            end
            setmetatableindex(sc,sp)
        end
    end
    parsers.settings_to_hash(settings,sc)
end

function parsers.listitem(str)
    return gmatch(str,"[^, ]+")
end

--

local pattern = Cs { "start",
    start    = V("one") + V("two") + V("three"),
    rest     = (Cc(",") * V("thousand"))^0 * (P(".") + endofstring) * anything^0,
    thousand = digit * digit * digit,
    one      = digit * V("rest"),
    two      = digit * digit * V("rest"),
    three    = V("thousand") * V("rest"),
}

lpegpatterns.splitthousands = pattern -- maybe better in the parsers namespace ?

function parsers.splitthousands(str)
    return lpegmatch(pattern,str) or str
end

-- print(parsers.splitthousands("11111111111.11"))

local optionalwhitespace = whitespace^0

lpegpatterns.words      = Ct((Cs((1-punctuation-whitespace)^1) + anything)^1)
lpegpatterns.sentences  = Ct((optionalwhitespace * Cs((1-period)^0 * period))^1)
lpegpatterns.paragraphs = Ct((optionalwhitespace * Cs((whitespace^1*endofstring/"" + 1 - (spacer^0*newline*newline))^1))^1)

-- local str = " Word1 word2. \n Word3 word4. \n\n Word5 word6.\n "
-- inspect(lpegmatch(lpegpatterns.paragraphs,str))
-- inspect(lpegmatch(lpegpatterns.sentences,str))
-- inspect(lpegmatch(lpegpatterns.words,str))

-- handy for k="v" [, ] k="v"

local dquote    = P('"')
local equal     = P('=')
local escape    = P('\\')
local separator = S(' ,')

local key       = C((1-equal)^1)
local value     = dquote * C((1-dquote-escape*dquote)^0) * dquote

----- pattern   = Cf(Ct("") * Cg(key * equal * value) * separator^0,rawset)^0 * P(-1) -- was wrong
local pattern   = Cf(Ct("") * (Cg(key * equal * value) * separator^0)^1,rawset)^0 * P(-1)

function parsers.keq_to_hash(str)
    if str and str ~= "" then
        return lpegmatch(pattern,str)
    else
        return { }
    end
end

-- inspect(lpeg.match(pattern,[[key="value" foo="bar"]]))

local defaultspecification = { separator = ",", quote = '"' }

-- this version accepts multiple separators and quotes as used in the
-- database module

function parsers.csvsplitter(specification)
    specification   = specification and table.setmetatableindex(specification,defaultspecification) or defaultspecification
    local separator = specification.separator
    local quotechar = specification.quote
    local separator = S(separator ~= "" and separator or ",")
    local whatever  = C((1 - separator - newline)^0)
    if quotechar and quotechar ~= "" then
        local quotedata = nil
        for chr in gmatch(quotechar,".") do
            local quotechar = P(chr)
            local quoteword = quotechar * C((1 - quotechar)^0) * quotechar
            if quotedata then
                quotedata = quotedata + quoteword
            else
                quotedata = quoteword
            end
        end
        whatever = quotedata + whatever
    end
    local parser = Ct((Ct(whatever * (separator * whatever)^0) * S("\n\r")^1)^0 )
    return function(data)
        return lpegmatch(parser,data)
    end
end

-- and this is a slightly patched version of a version posted by Philipp Gesang

-- local mycsvsplitter = utilities.parsers.rfc4180splitter()

-- local crap = [[
-- first,second,third,fourth
-- "1","2","3","4"
-- "a","b","c","d"
-- "foo","bar""baz","boogie","xyzzy"
-- ]]

-- local list, names = mycsvsplitter(crap,true)   inspect(list) inspect(names)
-- local list, names = mycsvsplitter(crap)        inspect(list) inspect(names)

function parsers.rfc4180splitter(specification)
    specification     = specification and table.setmetatableindex(specification,defaultspecification) or defaultspecification
    local separator   = specification.separator --> rfc: COMMA
    local quotechar   = P(specification.quote)  -->      DQUOTE
    local dquotechar  = quotechar * quotechar   -->      2DQUOTE
                      / specification.quote
    local separator   = S(separator ~= "" and separator or ",")
    local escaped     = quotechar
                      * Cs((dquotechar + (1 - quotechar))^0)
                      * quotechar
    local non_escaped = C((1 - quotechar - newline - separator)^1)
    local field       = escaped + non_escaped + Cc("")
    local record      = Ct(field * (separator * field)^1)
    local headerline  = record * Cp()
    local wholeblob   = Ct((newline^-1 * record)^0)
    return function(data,getheader)
        if getheader then
            local header, position = lpegmatch(headerline,data)
            local data = lpegmatch(wholeblob,data,position)
            return data, header
        else
            return lpegmatch(wholeblob,data)
        end
    end
end

-- utilities.parsers.stepper("1,7-",9,function(i) print(">>>",i) end)
-- utilities.parsers.stepper("1-3,7,8,9")
-- utilities.parsers.stepper("1-3,6,7",function(i) print(">>>",i) end)
-- utilities.parsers.stepper(" 1 : 3, ,7 ")
-- utilities.parsers.stepper("1:4,9:13,24:*",30)

local function ranger(first,last,n,action)
    if not first then
        -- forget about it
    elseif last == true then
        for i=first,n or first do
            action(i)
        end
    elseif last then
        for i=first,last do
            action(i)
        end
    else
        action(first)
    end
end

local cardinal    = lpegpatterns.cardinal / tonumber
local spacers     = lpegpatterns.spacer^0
local endofstring = lpegpatterns.endofstring

local stepper  = spacers * ( C(cardinal) * ( spacers * S(":-") * spacers * ( C(cardinal) + Cc(true) ) + Cc(false) )
               * Carg(1) * Carg(2) / ranger * S(", ")^0 )^1

local stepper  = spacers * ( C(cardinal) * ( spacers * S(":-") * spacers * ( C(cardinal) + (P("*") + endofstring) * Cc(true) ) + Cc(false) )
               * Carg(1) * Carg(2) / ranger * S(", ")^0 )^1 * endofstring -- we're sort of strict (could do without endofstring)

function parsers.stepper(str,n,action)
    if type(n) == "function" then
        lpegmatch(stepper,str,1,false,n or print)
    else
        lpegmatch(stepper,str,1,n,action or print)
    end
end

--

local pattern_math = Cs((P("%")/"\\percent " +  P("^")           * Cc("{") * lpegpatterns.integer * Cc("}") + P(1))^0)
local pattern_text = Cs((P("%")/"\\percent " + (P("^")/"\\high") * Cc("{") * lpegpatterns.integer * Cc("}") + P(1))^0)

patterns.unittotex = pattern

function parsers.unittotex(str,textmode)
    return lpegmatch(textmode and pattern_text or pattern_math,str)
end

local pattern = Cs((P("^") / "<sup>" * lpegpatterns.integer * Cc("</sup>") + P(1))^0)

function parsers.unittoxml(str)
    return lpegmatch(pattern,str)
end

-- print(utilities.parsers.unittotex("10^-32 %"),utilities.parsers.unittoxml("10^32 %"))

local cache   = { }
local spaces  = lpeg.patterns.space^0
local dummy   = function() end

table.setmetatableindex(cache,function(t,k)
    local separator = P(k)
    local value     = (1-separator)^0
    local pattern   = spaces * C(value) * separator^0 * Cp()
    t[k] = pattern
    return pattern
end)

local commalistiterator = cache[","]

function utilities.parsers.iterator(str,separator)
    local n = #str
    if n == 0 then
        return dummy
    else
        local pattern = separator and cache[separator] or commalistiterator
        local p = 1
        return function()
            if p <= n then
                local s, e = lpegmatch(pattern,str,p)
                if e then
                    p = e
                    return s
                end
            end
        end
    end
end

-- for s in utilities.parsers.iterator("a b c,b,c") do
--     print(s)
-- end

local function initialize(t,name)
    local source = t[name]
    if source then
        local result = { }
        for k, v in next, t[name] do
            result[k] = v
        end
        return result
    else
        return { }
    end
end

local function fetch(t,name)
    return t[name] or { }
end

local function process(result,more)
    for k, v in next, more do
        result[k] = v
    end
    return result
end

local name   = C((1-S(", "))^1)
local parser = (Carg(1) * name / initialize) * (S(", ")^1 * (Carg(1) * name / fetch))^0
local merge  = Cf(parser,process)

function utilities.parsers.mergehashes(hash,list)
    return lpegmatch(merge,list,1,hash)
end

-- local t = {
--     aa = { alpha = 1, beta = 2, gamma = 3, },
--     bb = { alpha = 4, beta = 5, delta = 6, },
--     cc = { epsilon = 3 },
-- }
--
-- inspect(utilities.parsers.mergehashes(t,"aa, bb, cc"))

function utilities.parsers.runtime(time)
    if not time then
        time = os.runtime()
    end
    local days = div(time,24*60*60)
    time = mod(time,24*60*60)
    local hours = div(time,60*60)
    time = mod(time,60*60)
    local minutes = div(time,60)
    local seconds = mod(time,60)
    return days, hours, minutes, seconds
end
