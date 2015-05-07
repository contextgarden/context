if not modules then modules = { } end modules ['char-utf'] = {
    version   = 1.001,
    comment   = "companion to char-utf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>When a sequence of <l n='utf'/> characters enters the application, it may be
neccessary to collapse subsequences into their composed variant.</p>

<p>This module implements methods for collapsing and expanding <l n='utf'/>
sequences. We also provide means to deal with characters that are special to
<l n='tex'/> as well as 8-bit characters that need to end up in special kinds
of output (for instance <l n='pdf'/>).</p>

<p>We implement these manipulations as filters. One can run multiple filters
over a string.</p>
--ldx]]--

local gsub, find = string.gsub, string.find
local concat, sortedhash, keys, sort = table.concat, table.sortedhash, table.keys, table.sort
local utfchar, utfbyte, utfcharacters, utfvalues = utf.char, utf.byte, utf.characters, utf.values
local P, Cs, Cmt, Ct = lpeg.P, lpeg.Cs, lpeg.Cmt, lpeg.Ct

if not characters        then require("char-def") end
if not characters.blocks then require("char-ini") end

local lpegmatch             = lpeg.match
local lpegpatterns          = lpeg.patterns
local p_utf8character       = lpegpatterns.utf8character
local p_utf8byte            = lpegpatterns.utf8byte
local utfchartabletopattern = lpeg.utfchartabletopattern

local formatters            = string.formatters

local allocate              = utilities.storage.allocate or function() return { } end

local charfromnumber        = characters.fromnumber

characters                  = characters or { }
local characters            = characters

local graphemes             = allocate()
characters.graphemes        = graphemes

local collapsed             = allocate()
characters.collapsed        = collapsed

local combined              = allocate()
characters.combined         = combined

local decomposed            = allocate()
characters.decomposed       = decomposed

local mathpairs             = allocate()
characters.mathpairs        = mathpairs

local filters               = allocate()
characters.filters          = filters

local utffilters            = { }
characters.filters.utf      = utffilters

local data                  = characters.data

-- is characters.combined cached?

--[[ldx--
<p>It only makes sense to collapse at runtime, since we don't expect source code
to depend on collapsing.</p>
--ldx]]--

-- for the moment, will be entries in char-def.lua .. this is just a subset that for
-- typographic (font) reasons we want to have split ... if we decompose all, we get
-- problems with fonts

local decomposed = allocate {
    ["Ĳ"] = "IJ",
    ["ĳ"] = "ij",
    ["և"] = "եւ",
    ["ﬀ"] = "ff",
    ["ﬁ"] = "fi",
    ["ﬂ"] = "fl",
    ["ﬃ"] = "ffi",
    ["ﬄ"] = "ffl",
    ["ﬅ"] = "ſt",
    ["ﬆ"] = "st",
    ["ﬓ"] = "մն",
    ["ﬔ"] = "մե",
    ["ﬕ"] = "մի",
    ["ﬖ"] = "վն",
    ["ﬗ"] = "մխ",
}

characters.decomposed = decomposed

-- local function initialize() -- maybe only 'mn'
--     local data = characters.data
--     for unicode, v in next, data do
--         -- using vs and first testing for length is faster (.02->.01 s)
--         local vs = v.specials
--         if vs and #vs == 3 then
--             local vc = vs[1]
--             if vc == "char" then
--                 local one, two = vs[2], vs[3]
--                 if data[two].category == "mn" then
--                     local cgf = combined[one]
--                     if not cgf then
--                         cgf = { [two] = unicode }
--                         combined[one]  = cgf
--                     else
--                         cgf[two] = unicode
--                     end
--                 end
--                 local first, second, combination = utfchar(one), utfchar(two), utfchar(unicode)
--                 local cgf = graphemes[first]
--                 if not cgf then
--                     cgf = { [second] = combination }
--                     graphemes[first] = cgf
--                 else
--                     cgf[second] = combination
--                 end
--                 if v.mathclass or v.mathspec then
--                     local mps = mathpairs[two]
--                     if not mps then
--                         mps = { [one] = unicode }
--                         mathpairs[two] = mps
--                     else
--                         mps[one] = unicode -- here unicode
--                     end
--                     local mps = mathpairs[second]
--                     if not mps then
--                         mps = { [first] = combination }
--                         mathpairs[second] = mps
--                     else
--                         mps[first] = combination
--                     end
--                 end
--          -- elseif vc == "compat" then
--          -- else
--          --     local description = v.description
--          --     if find(description,"LIGATURE") then
--          --         if vs then
--          --             local t = { }
--          --             for i=2,#vs do
--          --                 t[#t+1] = utfchar(vs[i])
--          --             end
--          --             decomposed[utfchar(unicode)] = concat(t)
--          --         else
--          --             local vs = v.shcode
--          --             if vs then
--          --                 local t = { }
--          --                 for i=1,#vs do
--          --                     t[i] = utfchar(vs[i])
--          --                 end
--          --                 decomposed[utfchar(unicode)] = concat(t)
--          --             end
--          --         end
--          --     end
--             end
--         end
--     end
--     initialize = false
--     characters.initialize = function() end -- when used outside tex
-- end

local function initialize()
    local data = characters.data
    local function backtrack(v,last,target)
        local vs = v.specials
        if vs and #vs == 3 and vs[1] == "char" then
            local one, two = vs[2], vs[3]
            local first, second = utfchar(one), utfchar(two) .. last
            collapsed[first..second] = target
            backtrack(data[one],second,target)
        end
    end
    for unicode, v in next, data do
        local vs = v.specials
        if vs and #vs == 3 and vs[1] == "char" then
            --
            local one, two = vs[2], vs[3]
            local first, second, combination = utfchar(one), utfchar(two), utfchar(unicode)
            --
            collapsed[first..second] = combination
            backtrack(data[one],second,combination)
            -- sort of obsolete:
            local cgf = graphemes[first]
            if not cgf then
                cgf = { [second] = combination }
                graphemes[first] = cgf
            else
                cgf[second] = combination
            end
            --
            if v.mathclass or v.mathspec then
                local mps = mathpairs[two]
                if not mps then
                    mps = { [one] = unicode }
                    mathpairs[two] = mps
                else
                    mps[one] = unicode -- here unicode
                end
                local mps = mathpairs[second]
                if not mps then
                    mps = { [first] = combination }
                    mathpairs[second] = mps
                else
                    mps[first] = combination
                end
            end
        end
    end
    initialize = false
    characters.initialize = function() end
end

characters.initialize = initialize

--[[ldx--
<p>The next variant has lazy token collecting, on a 140 page mk.tex this saves
about .25 seconds, which is understandable because we have no graphemes and
not collecting tokens is not only faster but also saves garbage collecting.
</p>
--ldx]]--

local skippable  = { }
local filesuffix = file.suffix

function utffilters.setskippable(suffix,value)
    if value == nil then
        value = true
    end
    if type(suffix) == "table" then
        for i=1,#suffix do
            skippable[suffix[i]] = value
        end
    else
        skippable[suffix] = value
    end
end

-- function utffilters.collapse(str,filename)   -- we can make high a seperate pass (never needed with collapse)
--     if skippable[filesuffix(filename)] then
--         return str
--  -- elseif find(filename,"^virtual://") then
--  --     return str
--  -- else
--  --  -- print("\n"..filename)
--     end
--     if str and str ~= "" then
--         local nstr = #str
--         if nstr > 1 then
--             if initialize then -- saves a call
--                 initialize()
--             end
--             local tokens, t, first, done, n = { }, 0, false, false, 0
--             for second in utfcharacters(str) do
--                 if done then
--                     if first then
--                         if second == " " then
--                             t = t + 1
--                             tokens[t] = first
--                             first = second
--                         else
--                          -- local crs = high[second]
--                          -- if crs then
--                          --     t = t + 1
--                          --     tokens[t] = first
--                          --     first = crs
--                          -- else
--                                 local cgf = graphemes[first]
--                                 if cgf and cgf[second] then
--                                     first = cgf[second]
--                                 else
--                                     t = t + 1
--                                     tokens[t] = first
--                                     first = second
--                                 end
--                          -- end
--                         end
--                     elseif second == " " then
--                         first = second
--                     else
--                      -- local crs = high[second]
--                      -- if crs then
--                      --     first = crs
--                      -- else
--                             first = second
--                      -- end
--                     end
--                 elseif second == " " then
--                     first = nil
--                     n = n + 1
--                 else
--                  -- local crs = high[second]
--                  -- if crs then
--                  --     for s in utfcharacters(str) do
--                  --         if n == 1 then
--                  --             break
--                  --         else
--                  --             t = t + 1
--                  --             tokens[t] = s
--                  --             n = n - 1
--                  --         end
--                  --     end
--                  --     if first then
--                  --         t = t + 1
--                  --         tokens[t] = first
--                  --     end
--                  --     first = crs
--                  --     done = true
--                  -- else
--                         local cgf = graphemes[first]
--                         if cgf and cgf[second] then
--                             for s in utfcharacters(str) do
--                                 if n == 1 then
--                                     break
--                                 else
--                                     t = t + 1
--                                     tokens[t] = s
--                                     n = n - 1
--                                 end
--                             end
--                             first = cgf[second]
--                             done = true
--                         else
--                             first = second
--                             n = n + 1
--                         end
--                  -- end
--                 end
--             end
--             if done then
--                 if first then
--                     t = t + 1
--                     tokens[t] = first
--                 end
--                 return concat(tokens) -- seldom called
--             end
--         elseif nstr > 0 then
--             return high[str] or str -- this will go from here
--         end
--     end
--     return str
-- end

-- this is about twice as fast

local p_collapse = nil -- so we can reset if needed

local function prepare()
    if initialize then
        initialize()
    end
    local tree = utfchartabletopattern(collapsed)
    p_collapse = Cs((tree/collapsed + p_utf8character)^0 * P(-1)) -- the P(1) is needed in order to accept non utf
end

function utffilters.collapse(str,filename)
    if not p_collapse then
        prepare()
    end
    if not str or #str == "" or #str == 1 then
        return str
    elseif filename and skippable[filesuffix(filename)] then -- we could hash the collapsables or do a quicker test
        return str
    else
        return lpegmatch(p_collapse,str) or str
    end
end

-- function utffilters.decompose(str)
--     if str and str ~= "" then
--         local nstr = #str
--         if nstr > 1 then
--          -- if initialize then -- saves a call
--          --     initialize()
--          -- end
--             local tokens, t, done, n = { }, 0, false, 0
--             for s in utfcharacters(str) do
--                 local dec = decomposed[s]
--                 if dec then
--                     if not done then
--                         if n > 0 then
--                             for s in utfcharacters(str) do
--                                 if n == 0 then
--                                     break
--                                 else
--                                     t = t + 1
--                                     tokens[t] = s
--                                     n = n - 1
--                                 end
--                             end
--                         end
--                         done = true
--                     end
--                     t = t + 1
--                     tokens[t] = dec
--                 elseif done then
--                     t = t + 1
--                     tokens[t] = s
--                 else
--                     n = n + 1
--                 end
--             end
--             if done then
--                 return concat(tokens) -- seldom called
--             end
--         end
--     end
--     return str
-- end

-- local replacer = nil
-- local finder   = nil
--
-- function utffilters.decompose(str) -- 3 to 4 times faster than the above
--     if not replacer then
--         if initialize then
--             initialize()
--         end
--         local tree = utfchartabletopattern(decomposed)
--         finder   = lpeg.finder(tree,false,true)
--         replacer = lpeg.replacer(tree,decomposed,false,true)
--     end
--     if str and str ~= "" and #str > 1 and lpegmatch(finder,str) then
--         return lpegmatch(replacer,str)
--     end
--     return str
-- end

local p_decompose = nil

local function prepare()
    if initialize then
        initialize()
    end
    local tree = utfchartabletopattern(decomposed)
    p_decompose = Cs((tree/decomposed + p_utf8character)^0 * P(-1))
end

function utffilters.decompose(str,filename) -- 3 to 4 times faster than the above
    if not p_decompose then
        prepare()
    end
    if str and str ~= "" and #str > 1 then
        return lpegmatch(p_decompose,str)
    end
    if not str or #str == "" or #str < 2 then
        return str
    elseif filename and skippable[filesuffix(filename)] then
        return str
    else
        return lpegmatch(p_decompose,str) or str
    end
    return str
end

-- utffilters.addgrapheme(utfchar(318),'l','\string~')
-- utffilters.addgrapheme('c','a','b')

function utffilters.addgrapheme(result,first,second) -- can be U+ 0x string or utf or number
    local result = charfromnumber(result)
    local first  = charfromnumber(first)
    local second = charfromnumber(second)
    if not graphemes[first] then
        graphemes[first] = { [second] = result }
    else
        graphemes[first][second] = result
    end
    local pair = first .. second
    if not composed[pair] then
        composed[pair] = result
        p_composed = nil
    end
end

if interfaces then -- eventually this goes to char-ctx.lua

    interfaces.implement {
        name      = "addgrapheme",
        actions   = utffilters.addgrapheme,
        arguments = { "string", "string", "string" }
    }

end

-- --

local p_reorder = nil

-- local sorter = function(a,b) return b[2] < a[2] end
--
-- local function swapper(s,p,t)
--     local old = { }
--     for i=1,#t do
--         old[i] = t[i][1]
--     end
--     old = concat(old)
--     sort(t,sorter)
--     for i=1,#t do
--         t[i] = t[i][1]
--     end
--     local new = concat(t)
--     if old ~= new then
--         print("reordered",old,"->",new)
--     end
--     return p, new
-- end

-- -- the next one isnto stable for similar weights

local sorter = function(a,b)
    return b[2] < a[2]
end

local function swapper(s,p,t)
    sort(t,sorter)
    for i=1,#t do
        t[i] = t[i][1]
    end
    return p, concat(t)
end

-- -- the next one keeps similar weights in the original order
--
-- local sorter = function(a,b)
--     local b2, a2 = b[2], a[2]
--     if a2 == b2 then
--         return b[3] > a[3]
--     else
--         return b2 < a2
--     end
-- end
--
-- local function swapper(s,p,t)
--     for i=1,#t do
--         t[i][3] = i
--     end
--     sort(t,sorter)
--     for i=1,#t do
--         t[i] = t[i][1]
--     end
--     return p, concat(t)
-- end

-- at some point exceptions will become an option, for now it's an experiment
-- to overcome bugs (that have become features) in unicode .. or we might decide
-- for an extra ordering key in char-def that takes precedence over combining

local exceptions = {
    -- frozen unicode bug
    ["َّ"] = "َّ", -- U+64E .. U+651 => U+651 .. U+64E
}

local function prepare()
    local hash = { }
    for k, v in sortedhash(characters.data) do
        local combining = v.combining -- v.ordering or v.combining
        if combining then
            hash[utfchar(k)] = { utfchar(k), combining, 0 } -- slot 3 can be used in sort
        end
    end
    local e = utfchartabletopattern(exceptions)
    local p = utfchartabletopattern(hash)
    p_reorder = Cs((e/exceptions + Cmt(Ct((p/hash)^2),swapper) + p_utf8character)^0) * P(-1)
end

function utffilters.reorder(str,filename)
    if not p_reorder then
        prepare()
    end
    if not str or #str == "" or #str < 2 then
        return str
    elseif filename and skippable[filesuffix(filename)] then
        return str
    else
        return lpegmatch(p_reorder,str) or str
    end
    return str
end

-- local collapse   = utffilters.collapse
-- local decompose  = utffilters.decompose
-- local preprocess = utffilters.preprocess
--
-- local c1, c2, c3 = "a", "̂", "̃"
-- local r2, r3 = "â", "ẫ"
-- local l1 = "ﬄ"
--
-- local str  = c1..c2..c3 .. " " .. c1..c2 .. " " .. l1
-- local res  = r3 .. " " .. r2 .. " " .. "ffl"
--
-- local text  = io.loaddata("t:/sources/tufte.tex")
--
-- local function test(n)
--     local data = text .. string.rep(str,100) .. text
--     local okay = text .. string.rep(res,100) .. text
--     local t = os.clock()
--     for i=1,10000 do
--         collapse(data)
--         decompose(data)
--      -- preprocess(data)
--     end
--     print(os.clock()-t,decompose(collapse(data))==okay,decompose(collapse(str)))
-- end
--
-- test(050)
-- test(150)
--
-- local old = "foo" .. string.char(0xE1) .. "bar"
-- local new = collapse(old)
-- print(old,new)

-- local one_old = "فَأَصَّدَّقَ دَّ" local one_new = utffilters.reorder(one_old)
-- local two_old = "فَأَصَّدَّقَ دَّ" local two_new = utffilters.reorder(two_old)
--
-- print(one_old,two_old,one_old==two_old,false)
-- print(one_new,two_new,one_new==two_new,true)
--
-- local test = "foo" .. utf.reverse("ؚ" .. "ً" .. "ٌ" .. "ٍ" .. "َ" .. "ُ" .. "ِ" .. "ّ" .. "ْ" ) .. "bar"
-- local done = utffilters.reorder(test)
--
-- print(test,done,test==done,false)

local f_default     = formatters["[%U] "]
local f_description = formatters["[%s] "]

local function convert(n)
    local d = data[n]
    d = d and d.description
    if d then
        return f_description(d)
    else
        return f_default(n)
    end
end

local pattern = Cs((p_utf8byte / convert)^1)

function utffilters.verbose(data)
    return data and lpegmatch(pattern,data) or ""
end

return characters
