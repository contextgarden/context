if not modules then modules = { } end modules ['mtx-patterns'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find, gsub, match = string.find, string.gsub, string.match
local concat = table.concat
local P, R, S, C, Ct, Cmt, Cc, Cs =  lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cmt, lpeg.Cc, lpeg.Cs
local patterns = lpeg.patterns
local lpegmatch = lpeg.match

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-spell</entry>
  <entry name="detail">ConTeXt Word Filtering</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="expand"><short>expand hunspell dics and aff files</short></flag>
    <flag name="dictionary"><short>word file (.dics)</short></flag>
    <flag name="specification"><short>affix specification file (.aff)</short></flag>
    <flag name="result"><short>destination file</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Examples</title>
   <subcategory>
    <example><command>mtxrun --script spell --expand --dictionary="en_US.dic" --specification="en_US.txt" --result="data-us.txt"</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]


local application = logs.application {
    name     = "mtx-spell",
    banner   = "ConTeXt Word Filtering 0.10",
    helpinfo = helpinfo,
}

local report = application.report
local trace  = false

scripts       = scripts       or { }
scripts.spell = scripts.spell or { }

---------------

require("char-def")
require("char-utf")

-- nl: ĳ => ij

do

    local prefixes, suffixes, affixes, continue, collected

    local function resetall()
        prefixes  = table.setmetatableindex("table")
        suffixes  = table.setmetatableindex("table")
        affixes   = table.setmetatableindex("table")
        continue  = { }
        collected = { }
    end

    local uppers   = { }
    local chardata = characters.data
    for k, v in next, chardata do
        if v.category == "lu" then
            uppers[utf.char(k)] = true
        end
    end

    local newline = patterns.newline
    local digit   = patterns.digit
    local skipped = digit + lpeg.utfchartabletopattern(uppers)
    local ignored = 1 - newline
    local garbage = S("'-")

    local function fixeddata(data)
        data = gsub(data,"ĳ","ij")
        return data
    end

    local function registersuffix(tag,f)
        table.insert(suffixes[tag],f)
        table.insert(affixes [tag],f)
    end

    local function registerprefix(tag,f)
        table.insert(prefixes[tag],f)
        table.insert(affixes [tag],f)
    end

    local function getfixes(specification)

        local data  = fixeddata(io.loaddata(specification) or "")
        local lines = string.splitlines(data)

        -- /* in two
        -- Y/N continuation

        -- [^...] [...] ...

        local p0 = nil

        local p1 = P("[^") * Cs((1-P("]"))^1) * P("]") / function(s)
            local t = utf.split(s)
            local p = 1 - lpeg.utfchartabletopattern(t)
            p0 = p0 and (p0 * p) or p
        end
        local p2 = P("[") * Cs((1-P("]"))^1) * P("]") / function(s)
            local t = utf.split(s)
            local p = lpeg.utfchartabletopattern(t)
            p0 = p0 and (p0 * p) or p
        end
        local p3 = (patterns.utf8char - S("[]"))^1 / function(s)
            local p = P(s)
            p0 = p0 and (p0 * p) or p
        end

        local p = (p1 + p2 + p3)^1

        local function makepattern(s)
            p0 = nil
            lpegmatch(p,s)
            return p0
        end

        local i = 1
        while i <= #lines do
            local line = lines[i]
            local tag, continuation, n = match(line,"PFX%s+(%S+)%s+(%S+)%s+(%d+)")
            if tag then
                n = tonumber(n) or 0
                continue[tag] = continuation == "Y"
                for j=1,n do
                    i = i + 1
                    line = lines[i]
                    if not find(line,"[-']") then
                        local tag, one, two, three = match(line,"PFX%s+(%S+)%s+(%S+)%s+([^%s/]+)%S*%s+(%S+)")
                        if tag then
                            if one == "0" and two and three == "." then
                                -- simple case: PFX A 0 re .
                                registerprefix(tag,function(str)
                                    local new = two .. str
                                    if trace then
                                        print("p 1",str,new)
                                    end
                                    return new
                                end)
                            elseif one == "0" and two and three then
                            -- strip begin
                                if trace then
                                    print('2',line)
                                end
                            elseif one and two and three then
                                if trace then
                                    print('3',line)
                                end
                            else
                                if trace then
                                    print('4',line)
                                end
                            end
                        end
                    end
                end
            end
            local tag, continuation, n = match(line,"SFX%s+(%S+)%s+(%S+)%s+(%S+)")
            if tag then
                n = tonumber(n) or 0
                continue[tag] = continuation == "Y"
                for j=1,n do
                    i = i + 1
                    line = lines[i]
                    if not find(line,"[-']") then
                        local tag, one, two, three = match(line,"SFX%s+(%S+)%s+(%S+)%s+([^%s/]+)%S*%s+(%S+)")
                        if tag then
                            if one == "0" and two and three == "." then
                                -- SFX Y 0 ly .
                                registersuffix(tag,function(str)
                                    local new = str .. two
                                    if trace then
                                        print("s 1",str,new)
                                    end
                                    return new
                                end)
                            elseif one == "0" and two and three then
                                -- SFX G 0 ing [^e]
                                local final = makepattern(three) * P(-1)
                                local check = (1 - final)^0 * final
                                registersuffix(tag,function(str)
                                    if lpegmatch(check,str) then
                                        local new = str .. two
                                        if trace then
                                            print("s 2",str,new)
                                        end
                                        return new
                                    end
                                end)
                            elseif one and two and three then
                                -- SFX G match$ suffix old$ (dutch has sloppy matches, use english as reference)
                                local final   = makepattern(three) * P(-1)
                                local check   = (1 - final)^1 * final
                                local final   = makepattern(one) * P(-1)
                                local replace = Cs((1 - final)^1 * (final/two))
                                registersuffix(tag,function(str)
                                    if lpegmatch(check,str) then
                                        local new = lpegmatch(replace,str)
                                        if new then
                                            if trace then
                                                print("s 3",str,new)
                                            end
                                            return new
                                        end
                                    end
                                end)
                            else
                                if trace then
                                    print('4',line)
                                end
                            end
                        end
                    end
                end
            end
            i = i + 1
        end
    end

    local function expand(_,_,word,spec)
        if spec then
            local w = { word }
            local n = 1
            for i=1,#spec do
                local s = spec[i]
                local affix = affixes[s]
                if affix then
                    for i=1,#affix do
                        local ai = affix[i]
                        local wi = ai(word)
                        if wi then
                            n = n + 1
                            w[n] = wi
                            if not continue[s] then
                                break
                            end
                        end
                    end
                end
            end
            for i=1,n do
                collected[w[i]] = true
            end
        elseif not find(word,"/") then
            collected[word] = true
        end
        return true
    end

    local function getwords(dictionary)
        local data = fixeddata(io.loaddata(dictionary) or "")
        local keys = { }
        for k, v in next, prefixes do
            keys[k] = true
        end
        for k, v in next, suffixes do
            keys[k] = true
        end
        local validkeys = lpeg.utfchartabletopattern(keys)
        local specifier = P("/") * Ct(C(validkeys)^1)^0 * newline
        local pattern   = (
            newline^1
          + skipped * (1-newline)^0
          + Cmt(C((1-specifier-newline-garbage)^1) * specifier^0, expand)
          + ignored^1 * newline^1
        )^0
        lpegmatch(pattern,data)
        collected = table.keys(collected)
        table.sort(collected)
        return collected
    end

    local function saveall(result)
        if result then
            io.savedata(result,concat(collected,"\n"))
        end
    end

    function scripts.spell.expand(arguments)
        if arguments then
            local dictionary    = environment.arguments.dictionary
            local specification = environment.arguments.specification
            local result        = environment.arguments.result
            if type(dictionary) ~= "string" or dictionary == "" then
                report("missing --dictionary=name")
            elseif type(specification) ~= "string" or specification == "" then
                report("missing --specification=name")
            elseif type(result) ~= "string" or result == "" then
                resetall()
                getfixes(specification)
                getwords(dictionary)
                saveall(result)
                return collected
            end
        end
    end

end

-- spell.dicaff {
--     dictionary    = "e:/context/spell/lo/en_US.dic.txt",
--     specification = "e:/context/spell/lo/en_US.aff.txt",
--     result        = "e:/context/spell/lo/data-en.txt",
-- }

-- spell.dicaff {
--     dictionary  = "e:/context/spell/lo/en_GB.dic.txt",
--     specification = "e:/context/spell/lo/en_GB.aff.txt",
--     result      = "e:/context/spell/lo/data-uk.txt",
-- }

-- spell.dicaff {
--     dictionary  = "e:/context/spell/lo/nl_NL.dic.txt",
--     specification = "e:/context/spell/lo/nl_NL.aff.txt",
--     result      = "e:/context/spell/lo/data-nl.txt",
-- }

if environment.argument("expand") then
    scripts.spell.expand(environment.arguments)
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
