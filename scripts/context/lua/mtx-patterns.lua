if not modules then modules = { } end modules ['mtx-patterns'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, find, concat, gsub, match, gmatch = string.format, string.find, table.concat, string.gsub, string.match, string.gmatch
local byte, char = utf.byte, utf.char
local addsuffix = file.addsuffix
local lpegmatch, lpegsplit, lpegpatterns, validutf8 = lpeg.match, lpeg.split, lpeg.patterns, lpeg.patterns.validutf8
local P, V, Cs = lpeg.P, lpeg.V, lpeg.Cs

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-patterns</entry>
  <entry name="detail">ConTeXt Pattern File Management</entry>
  <entry name="version">0.20</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="convert"><short>generate context language files (mnemonic driven, if not given then all)</short></flag>
    <flag name="check"><short>check pattern file (or those used by context when no file given)</short></flag>
    <flag name="path"><short>source path where hyph-foo.tex files are stored</short></flag>
    <flag name="destination"><short>destination path</short></flag>
    <flag name="specification"><short>additional patterns: e.g.: =cy,hyph-cy,welsh</short></flag>
    <flag name="compress"><short>compress data</short></flag>
    <flag name="words"><short>update words in given file</short></flag>
    <flag name="hyphenate"><short>show hypephenated words</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Examples</title>
   <subcategory>
    <example><command>mtxrun --script pattern --check hyph-*.tex</command></example>
    <example><command>mtxrun --script pattern --check   --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns</command></example>
    <example><command>mtxrun --script pattern --convert --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns/tex --destination=e:/tmp/patterns</command></example>
    <example><command>mtxrun --script pattern --convert --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns/txt --destination=e:/tmp/patterns</command></example>
    <example><command>mtxrun --script pattern --hyphenate --language=nl --left=3 nogalwiedes inderdaad</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-patterns",
    banner   = "ConTeXt Pattern File Management 0.20",
    helpinfo = helpinfo,
}

local report = application.report

scripts          = scripts          or { }
scripts.patterns = scripts.patterns or { }

local permitted_characters = table.tohash {
    0x0009, -- tab
    0x0027, -- apostrofe
    0x02BC, -- modifier apostrofe (used in greek)
    0x002D, -- hyphen
    0x200C, -- zwnj
    0x2019, -- quote right
    0x1FBD, -- greek, but no letter: symbol modifier
    0x1FBF, -- greek, but no letter: symbol modifier
}

local ignored_ancient_greek = table.tohash {
    0x1FD3, -- greekiotadialytikatonos (also 0x0390)
    0x1FE3, -- greekupsilondialytikatonos (also 0x03B0)
    0x1FBD, -- greek, but no letter: symbol modifier
    0x1FBF, -- greek, but no letter: symbol modifier
    0x03F2, -- greeksigmalunate
    0x02BC, -- modifier apostrofe)
}

local ignored_french = table.tohash {
    0x02BC, -- modifier apostrofe
}

local replaced_whatever =  {
    [char(0x2019)] = char(0x0027)
}

scripts.patterns.list = {
    { mnemonic = "af",  name = "hyph-af",            comment = "afrikaans" },
 -- { mnemonic = "ar",  name = "hyph-ar",            comment = "arabic" },
 -- { mnemonic = "as",  name = "hyph-as",            comment = "assamese" },
    { mnemonic = "bg",  name = "hyph-bg",            comment = "bulgarian" },
    { mnemonic = "bn",  name = "hyph-bn",            comment = "bengali" },
    { mnemonic = "ca",  name = "hyph-ca",            comment = "catalan" },
 -- { mnemonic = "??",  name = "hyph-cop",           comment = "coptic" },
    { mnemonic = "cs",  name = "hyph-cs",            comment = "czech" },
    { mnemonic = "cy",  name = "hyph-cy",            comment = "welsh" },
    { mnemonic = "da",  name = "hyph-da",            comment = "danish" },
    { mnemonic = "deo", name = "hyph-de-1901",       comment = "german, old spelling" },
    { mnemonic = "de",  name = "hyph-de-1996",       comment = "german, new spelling" },
 -- { mnemonic = "??",  name = "hyph-de-ch-1901",    comment = "swiss german" },
 -- { mnemonic = "??",  name = "hyph-el-polyton",    comment = "greek" },
    { mnemonic = "gr",  name = "hyph-el-monoton",    comment = "greek" },
    { mnemonic = "agr", name = "hyph-grc",           comment = "ancient greek", ignored = ignored_ancient_greek },
    { mnemonic = "gb",  name = "hyph-en-gb",         comment = "british english" },
    { mnemonic = "us",  name = "hyph-en-us",         comment = "american english", lefthyphenmin = 3, righthyphenmin = 2 },
    { mnemonic = "eo",  name = "hyph-eo",            comment = "esperanto" },
    { mnemonic = "es",  name = "hyph-es",            comment = "spanish" },
    { mnemonic = "et",  name = "hyph-et",            comment = "estonian" },
    { mnemonic = "eu",  name = "hyph-eu",            comment = "basque" },
 -- { mnemonic = "fa",  name = "hyph-fa",            comment = "farsi" },
    { mnemonic = "fi",  name = "hyph-fi",            comment = "finnish" },
    { mnemonic = "fr",  name = "hyph-fr",            comment = "french", ignored = ignored_french },
 -- { mnemonic = "??",  name = "hyph-ga",            comment = "irish" },
 -- { mnemonic = "??",  name = "hyph-gl",            comment = "galician" },
    { mnemonic = "gu",  name = "hyph-gu",            comment = "gujarati" },
    { mnemonic = "hi",  name = "hyph-hi",            comment = "hindi" },
    { mnemonic = "hr",  name = "hyph-hr",            comment = "croatian" },
 -- { mnemonic = "??",  name = "hyph-hsb",           comment = "upper sorbian" },
    { mnemonic = "hu",  name = "hyph-hu",            comment = "hungarian" },
    { mnemonic = "hy",  name = "hyph-hy",            comment = "armenian" },
 -- { mnemonic = "??",  name = "hyph-ia",            comment = "interlingua" },
    { mnemonic = "id",  name = "hyph-id",            comment = "indonesian" },
    { mnemonic = "is",  name = "hyph-is",            comment = "icelandic" },
    { mnemonic = "it",  name = "hyph-it",            comment = "italian" },
 -- { mnemonic = "??",  name = "hyph-kmr",           comment = "kurmanji" },
    { mnemonic = "kn",  name = "hyph-kn",            comment = "kannada" },
    { mnemonic = "la",  name = "hyph-la",            comment = "latin" },
    { mnemonic = "ala", name = "hyph-la-x-classic",  comment = "ancient latin" },
 -- { mnemonic = "lo",  name = "hyph-lo",            comment = "lao" },
    { mnemonic = "lt",  name = "hyph-lt",            comment = "lithuanian" },
    { mnemonic = "lv",  name = "hyph-lv",            comment = "latvian" },
    { mnemonic = "mk",  name = "hyph-mk",            comment = "macedonian" },
    { mnemonic = "ml",  name = "hyph-ml",            comment = "malayalam" },
    { mnemonic = "mn",  name = "hyph-mn-cyrl",       comment = "mongolian, cyrillic script" },
 -- { mnemonic = "mr",  name = "hyph-mr",            comment = "..." },
    { mnemonic = "nb",  name = "hyph-nb",            comment = "norwegian bokmål" },
    { mnemonic = "nl",  name = "hyph-nl",            comment = "dutch" },
    { mnemonic = "nn",  name = "hyph-nn",            comment = "norwegian nynorsk" },
 -- { mnemonic = "or",  name = "hyph-or",            comment = "oriya" },
 -- { mnemonic = "pa",  name = "hyph-pa",            comment = "panjabi" },
 -- { mnemonic = "",    name = "hyph-",              comment = "" },
    { mnemonic = "pl",  name = "hyph-pl",            comment = "polish" },
    { mnemonic = "pt",  name = "hyph-pt",            comment = "portuguese" },
    { mnemonic = "ro",  name = "hyph-ro",            comment = "romanian" },
    { mnemonic = "ru",  name = "hyph-ru",            comment = "russian" },
    { mnemonic = "sa",  name = "hyph-sa",            comment = "sanskrit" },
    { mnemonic = "sk",  name = "hyph-sk",            comment = "slovak" },
    { mnemonic = "sl",  name = "hyph-sl",            comment = "slovenian" },
    { mnemonic = "sq",  name = "hyph-sq",            comment = "albanian" },
    { mnemonic = "sr",  name = "hyph-sr",            comment = "serbian", merged = { "hyph-sh-cyrl", "hyph-sh-latn" }, },
 -- { mnemonic = "sr",  name = "hyph-sr-cyrl",       comment = "serbian", },
 -- { mnemonic = "sr",  name = "hyph-sr-latn",       comment = "serbian" },
    { mnemonic = "sv",  name = "hyph-sv",            comment = "swedish" },
    { mnemonic = "ta",  name = "hyph-ta",            comment = "tamil" },
    { mnemonic = "te",  name = "hyph-te",            comment = "telugu" },
    { mnemonic = "th",  name = "hyph-th",            comment = "thai" },
    { mnemonic = "tk",  name = "hyph-tk",            comment = "turkmen" },
    { mnemonic = "tr",  name = "hyph-tr",            comment = "turkish" },
    { mnemonic = "uk",  name = "hyph-uk",            comment = "ukrainian" },
    { mnemonic = "zh",  name = "hyph-zh-latn-pinyin",comment = "zh-latn, chinese pinyin" },
}

-- stripped down from lpeg example:

function utf.check(str)
    return lpegmatch(lpegpatterns.validutf8,str)
end

-- *.tex
-- *.hyp.txt *.pat.txt *.lic.txt *.chr.txt

function scripts.patterns.load(path,name,mnemonic,ignored,merged)
    local fullname = file.join(path,name)
    local basename = name
    local texfile  = addsuffix(fullname,"tex")
    local hypfile  = addsuffix(fullname,"hyp.txt")
    local patfile  = addsuffix(fullname,"pat.txt")
    local licfile  = addsuffix(fullname,"lic.txt")
 -- local chrfile  = addsuffix(fullname,"chr.txt")
    local okay = true
    local hyphenations, patterns, comment, stripset = "", "", "", ""
    local splitpatternsnew, splithyphenationsnew = { }, { }
    local splitpatternsold, splithyphenationsold = { }, { }
    local usedpatterncharactersnew, usedhyphenationcharactersnew = { }, { }
    if merged then
        -- no version info
        report("using merged txt files %s.[hyp|pat|lic].txt",name)
        for i=1,#merged do
            local fullname = file.join(path,merged[i])
            comment      = comment       .. (io.loaddata(addsuffix(fullname,"lic.txt")) or "") .. "\n\n"
            patterns     = patterns      .. (io.loaddata(addsuffix(fullname,"pat.txt")) or "") .. "\n\n"
            hyphenations = hyphenations  .. (io.loaddata(addsuffix(fullname,"hyp.txt")) or "") .. "\n\n"
        end
    elseif lfs.isfile(patfile) then
        -- no version info
        report("using txt files %s.[hyp|pat|lic].txt",name)
        comment      = io.loaddata(licfile) or ""
        patterns     = io.loaddata(patfile) or ""
        hyphenations = io.loaddata(hypfile) or ""
    elseif lfs.isfile(texfile) then
        -- version info in comment blob
        report("using tex file %s.txt",name)
        local data = io.loaddata(texfile) or ""
        if data ~= "" then
            data = gsub(data,"([\n\r])\\input ([^ \n\r]+)", function(previous,subname)
                local subname = addsuffix(subname,"tex")
                local subfull = file.join(file.dirname(texfile),subname)
                local subdata = io.loaddata(subfull) or ""
                if subdata == "" then
                    report("%s: no subfile %s",basename,subname)
                end
                return previous .. subdata
            end)
            data = gsub(data,"%%.-[\n\r]","")
            data = gsub(data," *[\n\r]+","\n")
            patterns     = match(data,"\\patterns[%s]*{[%s]*(.-)[%s]*}") or ""
            hyphenations = match(data,"\\hyphenation[%s]*{[%s]*(.-)[%s]*}") or ""
            comment      = match(data,"^(.-)[\n\r]\\patterns") or ""
        else
            okay = false
        end
    else
        okay = false
    end
    if okay then
        -- split into lines
        local how = lpegpatterns.whitespace^1
        splitpatternsnew = lpegsplit(how,patterns)
        splithyphenationsnew = lpegsplit(how,hyphenations)
    end
    if okay then
        -- remove comments
        local function check(data,splitdata,name)
            if find(data,"%%") then
                for i=1,#splitdata do
                    local line = splitdata[i]
                    if find(line,"%%") then
                        splitdata[i] = gsub(line,"%%.*$","")
                        report("%s: removing comment: %s",basename,line)
                    end
                end
            end
        end
        check(patterns,splitpatternsnew,patfile)
        check(hyphenations,splithyphenationsnew,hypfile)
    end
    if okay then
        -- remove lines with commands
        local function check(data,splitdata,name)
            if find(data,"\\") then
                for i=1,#splitdata do
                    local line = splitdata[i]
                    if find(line,"\\") then
                        splitdata[i] = ""
                        report("%s: removing line with command: %s",basename,line)
                    end
                end
            end
        end
        check(patterns,splitpatternsnew,patfile)
        check(hyphenations,splithyphenationsnew,hypfile)
    end
    if okay then
        -- check for valid utf
        local function check(data,splitdata,name)
            for i=1,#splitdata do
                local line = splitdata[i]
                local ok = lpegmatch(validutf8,line)
                if not ok then
                    splitdata[i] = ""
                    report("%s: removing line with invalid utf: %s",basename,line)
                end
            end
            -- check for commands being used in comments
        end
        check(patterns,splitpatternsnew,patfile)
        check(hyphenations,splithyphenationsnew,hypfile)
    end
    if okay then
        -- remove funny lines
        local cd = characters.data
        local stripped = { }
        local function check(splitdata,special,name)
            local used = { }
            for i=1,#splitdata do
                local line = splitdata[i]
                for b in line:utfvalues() do -- could be an lpeg
                    if b == special then
                        -- not registered
                    elseif permitted_characters[b] then
                        used[char(b)] = true
                    else
                        local cdb = cd[b]
                        if not cdb then
                            report("%s: no entry in chardata for character %C",basename,b)
                        else
                            local ct = cdb.category
                            if ct == "lu" or ct == "ll" or ct == "lo" or ct == "mn" or ct == "mc" then -- hm, really mn and mc ?
                                used[char(b)] = true
                            elseif ct == "nd" then
                                -- number
                            elseif ct == "cf" then
                                report("%s: %s line with suspected utf character %C, category %s: %s",basename,"keeping",b,ct,line)
                                used[char(b)] = true
                            else -- maybe accent cf  (200D)
                                report("%s: %s line with suspected utf character %C, category %s: %s",basename,"removing",b,ct,line)
                                splitdata[i] = ""
                                break
                            end
                        end
                    end
                end
            end
            return used
        end
        usedpatterncharactersnew = check(splitpatternsnew,byte("."))
        usedhyphenationcharactersnew = check(splithyphenationsnew,byte("-"))
        for k, v in next, stripped do
            report("%s: entries that contain character %C have been omitted",basename,k)
        end
    end
    if okay then
        local function stripped(what,ignored)
            -- ignored (per language)
            local p = nil
            if ignored then
                for k, v in next, ignored do
                    if p then
                        p = p + P(char(k))
                    else
                        p = P(char(k))
                    end
                end
                p = P{ p + 1 * V(1) } -- anywhere
            end
            -- replaced (all languages)
            local r = nil
            for k, v in next, replaced_whatever do
                if r then
                    r = r + P(k)/v
                else
                    r = P(k)/v
                end
            end
            r = Cs((r + 1)^0)
            local result = { }
            for i=1,#what do
                local line = what[i]
                if p and lpegmatch(p,line) then
                    report("%s: discarding conflicting pattern: %s",basename,line)
                else -- we can speed this up by testing for replacements in the string
                    local l = lpegmatch(r,line)
                    if l ~= line then
                        report("%s: sanitizing pattern: %s -> %s (for old patterns)",basename,line,l)
                    end
                    result[#result+1] = l
                end
            end
            return result
        end
        splitpatternsold = stripped(splitpatternsnew,ignored)
        splithyphenationsold = stripped(splithyphenationsnew,ignored)

    end
    if okay then
        -- discarding duplicates
        local function check(data,splitdata,name)
            local used, collected = { }, { }
            for i=1,#splitdata do
                local line = splitdata[i]
                if line == "" then
                    -- discard
                elseif used[line] then
                    -- discard
                    report("%s: discarding duplicate pattern: %s",basename,line)
                else
                    used[line] = true
                    collected[#collected+1] = line
                end
            end
            return collected
        end
        splitpatternsnew = check(patterns,splitpatternsnew,patfile)
        splithyphenationsnew = check(hyphenations,splithyphenationsnew,hypfile)
        splitpatternsold = check(patterns,splitpatternsold,patfile)
        splithyphenationsold = check(hyphenations,splithyphenationsold,hypfile)
    end
    if not okay then
        report("no valid file %s.*",name)
    end

    local function getused(t)
        local u = { }
        for k, v in next, t do
            if ignored and ignored[k] then
            elseif replaced_whatever[k] then
            else
                u[k] = v
            end
        end
        return u
    end
    local usedpatterncharactersold = getused(usedpatterncharactersnew)
    local usedhyphenationcharactersold = getused(usedhyphenationcharactersnew)

    return okay,
        splitpatternsnew, splithyphenationsnew, splitpatternsold, splithyphenationsold, comment, stripset,
        usedpatterncharactersnew, usedhyphenationcharactersnew, usedpatterncharactersold, usedhyphenationcharactersold
end

function scripts.patterns.save(destination,mnemonic,name,patternsnew,hyphenationsnew,patternsold,hyphenationsold,comment,stripped,
        pusednew,husednew,pusedold,husedold,ignored,lefthyphenmin,righthyphenmin)
    local nofpatternsnew, nofhyphenationsnew = #patternsnew, #hyphenationsnew
    local nofpatternsold, nofhyphenationsold = #patternsold, #hyphenationsold
    report("language %s has %s old and %s new patterns and %s old and %s new exceptions",mnemonic,nofpatternsold,nofpatternsnew,nofhyphenationsold,nofhyphenationsnew)
    if mnemonic ~= "??" then
        local punew = concat(table.sortedkeys(pusednew), " ")
        local hunew = concat(table.sortedkeys(husednew), " ")
        local puold = concat(table.sortedkeys(pusedold), " ")
        local huold = concat(table.sortedkeys(husedold), " ")

        local rmefile = file.join(destination,"lang-"..mnemonic..".rme")
        local patfile = file.join(destination,"lang-"..mnemonic..".pat")
        local hypfile = file.join(destination,"lang-"..mnemonic..".hyp")
        local luafile = file.join(destination,"lang-"..mnemonic..".lua") -- suffix might change to llg

        local topline = "% generated by mtxrun --script pattern --convert"
        local banner = "% for comment and copyright, see " .. file.basename(rmefile)
        report("saving language data for %s",mnemonic)
        if not comment or comment == "" then comment = "% no comment" end
        if not type(destination) == "string" then destination = "." end

        local compression = environment.arguments.compress and "zlib" or nil

        local lines = string.splitlines(comment)
        for i=1,#lines do
            if not find(lines[i],"^%%") then
                lines[i] = "% " .. lines[i]
            end
        end

        local metadata = {
         -- texcomment = comment,
            texcomment = concat(lines,"\n"),
            source     = name,
            mnemonic   = mnemonic,
        }

        local patterndata, hyphenationdata
        if nofpatternsnew > 0 then
            local data = concat(patternsnew," ")
            patterndata = {
                n              = nofpatternsnew,
                compression    = compression,
                length         = #data,
                data           = compression and zlib.compress(data,9) or data,
                characters     = concat(table.sortedkeys(pusednew),""),
                lefthyphenmin  = lefthyphenmin  or 1, -- determined by pattern author, sometimes set
                righthyphenmin = righthyphenmin or 1,
            }
        else
            patterndata = {
                n = 0,
            }
        end
        if nofhyphenationsnew > 0 then
            local data = concat(hyphenationsnew," ")
            hyphenationdata = {
                n           = nofhyphenationsnew,
                compression = compression,
                length      = #data,
                data        = compression and zlib.compress(data,9) or data,
                characters  = concat(table.sortedkeys(husednew),""),
            }
        else
            hyphenationdata = {
                n = 0,
            }
        end
        local data = {
            -- a prelude to language goodies, like we have font goodies and in
            -- mkiv we can use this file directly
            version    = "1.001",
            comment    = topline,
            metadata   = metadata,
            patterns   = patterndata,
            exceptions = hyphenationdata,
        }

        os.remove(rmefile)
        os.remove(patfile)
        os.remove(hypfile)
        os.remove(luafile)

        io.savedata(rmefile,format("%s\n\n%s",topline,comment))
        io.savedata(patfile,format("%s\n\n%s\n\n%% used: %s\n\n\\patterns{\n%s}",topline,banner,puold,concat(patternsold,"\n")))
        io.savedata(hypfile,format("%s\n\n%s\n\n%% used: %s\n\n\\hyphenation{\n%s}",topline,banner,huold,concat(hyphenationsold,"\n")))
        io.savedata(luafile,table.serialize(data,true))
    end
end

function scripts.patterns.prepare()
    --
    dofile(resolvers.findfile("char-def.lua"))
    --
    local specification = environment.argument("specification")
    if specification then
        local components = utilities.parsers.settings_to_array(specification)
        if #components == 3 then
            table.insert(scripts.patterns.list,1,components)
            report("specification added: %s %s %s",table.unpack(components))
        else
            report('invalid specification: %q, "xx,lang-yy,zzzz" expected',specification)
        end
    end
end

function scripts.patterns.check()
    local path = environment.argument("path") or "."
    local files = environment.files
    local only  = false
    if #files > 0 then
        only = table.tohash(files)
    end
    for k, v in next, scripts.patterns.list do
        local mnemonic = v.mnemonic
        local name     = v.name
        local comment  = v.comment
        local ignored  = v.ignored
        local merged   = v.merged
        if not only or only[mnemonic] then
            report("checking language %s, file %s", mnemonic, name)
            local okay = scripts.patterns.load(path,name,mnemonic,ignored,merged)
            if not okay then
                report("there are errors that need to be fixed")
            end
            report()
        end
    end
end

function scripts.patterns.convert()
    local path = environment.argument("path") or "."
    if path == "" then
        report("provide sourcepath using --path ")
    else
        local destination = environment.argument("destination") or "."
        if path == destination then
            report("source path and destination path should differ (use --path and/or --destination)")
        else
            local files = environment.files
            local only  = false
            if #files > 0 then
                only = table.tohash(files)
            end
            for k, v in next, scripts.patterns.list do
                local mnemonic = v.mnemonic
                local name     = v.name
                local comment  = v.comment
                local ignored  = v.ignored
                local merged   = v.merged
                if not only or only[mnemonic] then
                    report("converting language %s, file %s", mnemonic, name)
                    local okay, patternsnew, hyphenationsnew, patternsold, hyphenationsold, comment, stripped,
                        pusednew, husednew, pusedold, husedold = scripts.patterns.load(path,name,mnemonic,ignored,merged)
                    if okay then
                        scripts.patterns.save(
                            destination,mnemonic,name,
                            patternsnew,hyphenationsnew,patternsold,hyphenationsold,
                            comment,stripped,
                            pusednew,husednew,pusedold,husedold,ignored,
                            v.lefthyphenmin,v.righthyphenmin
                        )
                    else
                        report("convertion aborted due to error(s)")
                    end
                    report()
                end
            end
        end
    end
end

local function valid(filename)
    local specification = table.load(filename)
    if not specification then
        return false
    end
    local lists = specification.lists
    if not lists then
        return false
    end
    return specification, lists
end

function scripts.patterns.words()
    if environment.arguments.update then
        local compress = environment.arguments.compress
        for i=1,#environment.files do
            local filename = environment.files[i]
            local fullname = resolvers.findfile(filename)
            if fullname and fullname ~= "" then
                report("checking file %a",fullname)
                local specification, lists = valid(fullname)
                if specification and #lists> 0 then
                    report("updating %a of language %a",filename,specification.language)
                    for i=1,#lists do
                        local entry = lists[i]
                        local filename = entry.filename
                        if filename then
                            local fullname = resolvers.findfile(filename)
                            if fullname then
                                report("adding words from %a",fullname)
                                local data = io.loaddata(fullname) or ""
                                data = string.strip(data)
                                data = string.gsub(data,"%s+"," ")
                                if compress then
                                    entry.data        = zlib.compress(data,9)
                                    entry.compression = "zlib"
                                    entry.length      = #data
                                else
                                    entry.data        = data
                                    entry.compression = nil
                                    entry.length      = #data
                                end
                            else
                                entry.data        = ""
                                entry.compression = nil
                                entry.length      = 0
                            end
                        else
                            entry.data        = ""
                            entry.compression = nil
                            entry.length      = 0
                        end
                    end
                    specification.version   = "1.00"
                    specification.timestamp =  os.localtime()
                    report("updated file %a is saved",filename)
                    table.save(filename,specification)
                else
                    report("no file %a",filename)
                end
            else
                report("nothing done")
            end
        end
    else
        report("provide --update")
    end
end

-- mtxrun --script patterns --hyphenate --language=nl nogalwiedes --left=3
--
-- hyphenator      |
-- hyphenator      | . n o g a l w i e d e s .         . n o g a l w i e d e s .
-- hyphenator      | .0n4                               0 4 0 0 0 0 0 0 0 0 0 0
-- hyphenator      |    0o0g0a4l0                       0 4 0 0 4 0 0 0 0 0 0 0
-- hyphenator      |      1g0a0                         0 4 1 0 4 0 0 0 0 0 0 0
-- hyphenator      |          0l1w0                     0 4 1 0 4 1 0 0 0 0 0 0
-- hyphenator      |              4i0e0                 0 4 1 0 4 1 4 0 0 0 0 0
-- hyphenator      |              0i0e3d0e0             0 4 1 0 4 1 4 0 3 0 0 0
-- hyphenator      |                0e1d0               0 4 1 0 4 1 4 0 3 0 0 0
-- hyphenator      |                  1d0e0             0 4 1 0 4 1 4 0 3 0 0 0
-- hyphenator      |                  0d0e2s0           0 4 1 0 4 1 4 0 3 0 2 0
-- hyphenator      |                      4s0.          0 4 1 0 4 1 4 0 3 0 4 0
-- hyphenator      | .0n4o1g0a4l1w4i0e3d0e4s0.         . n o-g a l-w i e-d e s .
-- hyphenator      |
-- mtx-patterns    | nl 3 3 : nogalwiedes : nogal-wie-des

function scripts.patterns.hyphenate()
    require("lang-hyp")
    local traditional   = languages.hyphenators.traditional
    local language      = environment.arguments.language or "us"
    local dictionary    = traditional.loadpatterns(language)
    local left          = tonumber(environment.arguments.left)  or dictionary.lefthyphenmin  or 3
    local right         = tonumber(environment.arguments.right) or dictionary.righthyphenmin or 3
    local words         = environment.files
    local specification = {
        leftcharmin     = left,
        rightcharmin    = right,
        leftchar        = false,
        rightchar       = false,
    }
    if environment.argument("direct") then
        for i=1,#words do
            words[i] = traditional.injecthyphens(dictionary,words[i],specification)
        end
        words = concat(words," ")
        if environment.argument("soft") then
            words = gsub(words,"%-",utf.char(0xAD))
        end
        print(words)
    else
        trackers.enable("hyphenator.steps")
        for i=1,#words do
            local word = words[i]
            report("%s %s %s : %s : %s",
                language, left, right,
                word,
                traditional.injecthyphens(dictionary,word,specification)
            )
        end
    end
end

if environment.argument("check") then
    scripts.patterns.prepare()
    scripts.patterns.check()
elseif environment.argument("convert") then
    scripts.patterns.prepare()
    scripts.patterns.convert()
elseif environment.argument("words") then
    scripts.patterns.words() -- for the moment here
elseif environment.argument("hyphenate") then
    scripts.patterns.hyphenate() -- for the moment here
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end

-- mtxrun --script pattern --check   hyph-*.tex
-- mtxrun --script pattern --check   --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns
-- mtxrun --script pattern --convert --path=c:/data/develop/svn-hyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns/txt --destination=e:/tmp/patterns
-- mtxrun --script pattern --convert --path=c:/data/repositories/tex-hyphen/hyph-utf8/tex/generic/hyph-utf8/patterns/txt --destination=e:/tmp/patterns
--
-- use this call:
--
-- setlocal
--
-- rem tugsvn checkout:
--
-- set patternsroot=c:/data/develop/svn-hyphen/trunk
--
-- rem github checkout:
--
-- set patternsroot=c:/data/repositories/tex-hyphen
--
-- del /q c:\data\develop\tex-context\tex\texmf-local\tex\context\patterns\*
-- del /q c:\data\develop\tex-context\tex\texmf-mine\tex\context\patterns\*
-- del /q c:\data\develop\tex-context\tex\texmf-context\tex\context\patterns\*
--
-- mtxrun --script pattern --convert --path=%patternsroot%/hyph-utf8/tex/generic/hyph-utf8/patterns/txt --destination=c:/data/develop/tmp/patterns
--
-- copy /Y lang*.hyp c:\data\develop\tex-context\tex\texmf-context\tex\context\patterns
-- copy /Y lang*.pat c:\data\develop\tex-context\tex\texmf-context\tex\context\patterns
-- copy /Y lang*.rme c:\data\develop\tex-context\tex\texmf-context\tex\context\patterns
-- copy /Y lang*.lua c:\data\develop\tex-context\tex\texmf-context\tex\context\patterns
--
-- move /Y lang*.hyp c:\data\develop\tex-context\tex\texmf-mine\tex\context\patterns
-- move /Y lang*.pat c:\data\develop\tex-context\tex\texmf-mine\tex\context\patterns
-- move /Y lang*.rme c:\data\develop\tex-context\tex\texmf-mine\tex\context\patterns
-- move /Y lang*.lua c:\data\develop\tex-context\tex\texmf-mine\tex\context\patterns
--
-- mtxrun --script pattern --words --update word-th.lua --compress
--
-- copy /Y word*.lua c:\data\develop\tex-context\tex\texmf-context\tex\context\patterns
-- move /Y word*.lua c:\data\develop\tex-context\tex\texmf-mine\tex\context\patterns
--
-- mtxrun --generate
--
-- endlocal
