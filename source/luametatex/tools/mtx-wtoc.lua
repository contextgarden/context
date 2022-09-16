if not modules then modules = { } end modules ['mtx-wtoc'] = {
    version   = 1.001,
    comment   = "a hack to avoid a dependency on cweb / web2c",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is a hack. When I have time and motivation I'll make a better version. Sorry
-- for the mess. It's not an example of proper coding. It's also not that efficient.
-- It is not general purpose too, just a helper for luametatex in order to not be
-- dependent on installing the cweb infrastructure (which normally gets compiled as
-- part of the complex tl build). Okay, we do have a dependency on luametatex as lua
-- runner although this script can be easily turned into a pure lua variant (not
-- needing mtxrun helpers). If really needed one could build luametatex without
-- mplib and then do the first bootstrap, but there's always a c to start with
-- anyway; only when mp.w cum suis get updated we need to convert.
--
-- The w files get converted to into in .25 seconds which is not that bad.

-- @, @/ @| @# @+ @; @[ @]
-- @.text @>(monospaced) | @:text @>(macro driven) | @= verbose@> | @! underlined @>| @t text @> (hbox) | @q ignored @>
-- @^index@>
-- @f text renderclass
-- @s idem | @p idem | @& strip (spaces before) | @h
-- @'char' (ascii code)
-- @l nonascii
-- @x @y @z changefile | @i webfile
-- @* title.
-- @  explanation (not ok ... stops at outer @
--
-- The comment option doesn't really work so one needs to do some manual work
-- afterwards but I'll only use that when we move away from w files.

local next = next
local lower, find, gsub = string.lower, string.find, string.gsub
local topattern = string.topattern
local striplines = utilities.strings.striplines
local concat = table.concat

local P, R, S, C, Cs, Ct, Cc = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cc
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local newline    = lpegpatterns.newline
local space      = lpegpatterns.space -- S(" \n\r\t\f\v")
local restofline = (1-newline)^0

local cweb = { }

-- We have several ways to look at and filter the data so we have different
-- lpegs. The output looks ugly but that is the whole idea I think as cweb.

local report  = logs.reporter("cweb to normal c")
local verbose = false
-- local verbose = true

-- common

local p_beginofweb = P("@")
local p_endofweb   = P("@>")
local p_noweb      = (1-p_endofweb)^1
local p_squote     = P("'")
local p_period     = P(".")
local p_noperiod   = (1-p_period)^1
local p_spacing    = space^1
local p_nospacing  = (1-space)^1
local p_equal      = P("=")
local p_noequal    = (1-p_equal)^1
local p_rest       = P(1)
local p_escape     = p_beginofweb * p_beginofweb
local c_unescape   = p_escape / "@"
local p_structure  = p_beginofweb * (S("*dc \t\n\r"))
local p_content    = (p_escape + (1 - p_structure))^1
local c_noweb      = C(p_noweb)
local c_content    = C(p_content)
local c_nospacing  = C(p_nospacing)
local c_noperiod   = C(p_noperiod)

local function clean(s)
    s = lower(s)
    s = gsub(s,"%s+"," ")
    s = gsub(s,"%s+$","")
    s = gsub(s,"%s*%.%.%.$","...")
    return s
end

local cleanup do

    local p_ignore_1  = S(",/|#+;[]sp&")
    local p_ignore_2  = S("^.:=!tq") * p_noweb * p_endofweb
    local p_ignore_3  = S("f") * p_spacing * p_nospacing * p_spacing * p_nospacing
    local p_ignore_4  = p_squote * (1-p_squote)^0 * p_squote
    local p_ignore_5  = S("l") * p_spacing * p_nospacing

    local p_replace_1 = P("h") / "\n@<header goes here@>\n"
    local p_replace_2 = (P("#") * space^0) / "\n"

    local p_strip_1   = (newline * space^1) / "\n"

    local p_whatever  = (
        p_beginofweb / ""
      * (
            p_replace_1
          + p_replace_2
          + Cs(
                p_ignore_1
              + p_ignore_2
              + p_ignore_3
              + p_ignore_4
              + p_ignore_5
            ) / ""
        )
    )

    local p_whatever =
        (newline * space^1) / ""
      * p_whatever
      * (space^0 * newline) / "\n"
      + p_whatever

    local pattern = Cs ( (
        p_escape
      + p_whatever
      + p_rest
    )^1 )

    cleanup = function(s)
        return lpegmatch(pattern,s)
    end

end

local finalize do

    -- The reason why we need to strip leading spaces it that compilers complain about this:
    --
    -- if (what)
    --   this;
    --   that;
    --
    -- with the 'that' being confusingly indented. The fact that it has to be mentioned is of
    -- course a side effect of compact c coding which can introduce 'errors'. Now, this
    -- 'confusing' indentatoin is a side effect of
    --
    -- if (what)
    --   this;
    --   @<that@>;
    --
    --
    -- or actually:
    --
    --   @<this is what@>;
    --   this;
    --   @<that@>;
    --
    -- which then lead to the conclusion that @<that@> should not be indented! But ... cweb
    -- removes all leading spaces in lines, so that obscured the issue. Bad or not? It is
    -- anyway a very strong argument for careful coding and matbe using some more { } in case
    -- of snippets because web2c obscures some warnings!

    ----- strip_display = (P("/*") * (1 - P("*/"))^1 * P("*/")) / " "
    local strip_inline  = (P("//") * (1 - newline)^0)           / ""
    local keep_inline   = P("//") * space^0 * P("fall through")

    local strip_display = (P("/*") * (1 - P("*/"))^1 * P("*/"))

    strip_display =
        (newline * space^0 * strip_display * newline) / "\n"
        + strip_display / " "

    local strip_spaces  = (space^1 * newline)             / "\n"
    ----- strip_lines   = (space^0 * newline * space^0)^3 / "\n\n"
    local strip_lines   = newline * (space^0 * newline)^3 / "\n\n"

    local strip_empties = newline/"" * newline * space^1 * P("}")
                        + space^2 * P("}")   * (newline * space^0 * newline / "\n")
                        + space^2 * R("AZ") * R("AZ","__","09")^1 * P(":") * (space^0 * newline * space^0 * newline / "\n")

    local finalize_0 = Cs((c_unescape + p_rest)^0)
    local finalize_1 = Cs((strip_display + keep_inline + strip_inline + c_unescape + p_rest)^0)
    local finalize_2 = Cs((strip_lines                  + p_rest)^0)
    local finalize_3 = Cs((c_unescape + strip_spaces    + p_rest)^1)
    local finalize_4 = Cs((c_unescape + strip_empties   + p_rest)^1)

    finalize = function(s,keepcomment)
        s = keepcomment and lpegmatch(finalize_0,s) or lpegmatch(finalize_1,s)
        s = lpegmatch(finalize_2,s)
        s = lpegmatch(finalize_3,s)
        s = lpegmatch(finalize_4,s)
        -- maybe also empty lines after a LABEL:
        return s
    end

end

local function fixdefine(s)
    s = finalize(s)
    s = gsub(s,"[\n\r\t ]+$","")
    s = gsub(s,"[\t ]*[\n\r]+"," \\\n")
    return s
end

local function addcomment(c,s)
    if c ~= "" then
        c = striplines(c)
        if find(c,"\n") then
            c = "\n\n/*\n" .. c .. "\n*/\n\n"
        else
            c = "\n\n/* " .. c .. " */\n\n"
        end
        return c .. s
    else
        return s
    end
end

do

    local result = { }

    local p_nothing   = Cc("")
    local p_comment   = Cs(((p_beginofweb * (space + newline + P("*")))/"" * c_content)^1)
                      + p_nothing

    local p_title     = c_noperiod * (p_period/"")
    local p_skipspace = newline + space
    local c_skipspace = p_skipspace / ""
    local c_title     = c_skipspace * p_title * c_skipspace * Cc("\n\n")
    local c_obeyspace = p_skipspace / "\n\n"

    local p_comment   = Cs( (
                            ((p_beginofweb * p_skipspace)/""           * c_content)
                          + ((p_beginofweb * P("*")^1   )/"" * c_title * c_content)
                          + c_obeyspace
                        )^1 )
                      + p_nothing

    local p_define    = C(p_beginofweb * P("d")) * Cs(Cc("# define ") * p_content)
    local p_code      = C(p_beginofweb * P("c")) * c_content
    local p_header    = C(p_beginofweb * P("(")) * c_noweb * C(p_endofweb * p_equal) * c_content
    local p_snippet   = C(p_beginofweb * S("<")) * c_noweb * C(p_endofweb * p_equal) * c_content
    local p_reference = C(p_beginofweb * S("<")) * c_noweb * C(p_endofweb          ) * #(1-p_equal)
    local p_preset    =   p_beginofweb * S("<")  * c_noweb *   p_endofweb

    local p_indent    = C(space^0)
    local p_reference = p_indent * p_reference

    local p_c_define  = p_comment * p_define
    local p_c_code    = p_comment * p_code
    local p_c_header  = p_comment * p_header
    local p_c_snippet = p_comment * p_snippet

    local p_n_define  = p_nothing * p_define
    local p_n_code    = p_nothing * p_code
    local p_n_header  = p_nothing * p_header
    local p_n_snippet = p_nothing * p_snippet

    local function preset(tag)
        tag = clean(tag)
        if find(tag,"%.%.%.$") then
            result.dottags[tag] = false
        end
        result.alltags[tag] = tag
    end

    local p_preset = (p_preset / preset + p_rest)^1

    -- we can have both definitions and references with trailing ... and this is imo
    -- a rather error prone feature: i'd expect the definitions to be the expanded one
    -- so that references can be shorter ... anyway, we're stuck with this (also with
    -- inconsistent usage of "...", " ...", "... " and such.

    local function getpresets(data)

        local alltags = result.alltags
        local dottags = result.dottags

        lpegmatch(p_preset,data)

        local list = table.keys(alltags)

        table.sort(list,function(a,b)
            a = gsub(a,"%.+$"," ") -- slow
            b = gsub(b,"%.+$"," ") -- slow
            return a < b
        end)

        for k, v in next, dottags do
            local s = gsub(k,"%.%.%.$","")
            local p = "^" .. topattern(s,false,"all")
            for i=1,#list do
                local a = list[i]
                if a ~= k and find(a,p) then
                    dottags[k] = true
                    alltags[k] = a
                end
            end
        end

        for k, v in next, alltags do
            local t = alltags[v]
            if t then
                alltags[k] = t
            end
        end

    end

    local function addsnippet(c,b,tag,e,s)
        if c ~= "" then
            s = addcomment(c,s)
        end
        local alltags  = result.alltags
        local snippets = result.snippets
        local tag  = clean(tag)
        local name = alltags[tag]
        if snippets[name] then
            if verbose then
                report("add snippet  : %s",name)
            end
            s = snippets[name] .. "\n" .. s
        else
            if verbose then
                report("new snippet  : %s",name)
            end
            s = "/* snippet: " .. name .. " */\n" .. s
        end
        snippets[name] = s
        result.nofsnippets = result.nofsnippets + 1
        return ""
    end

    local function addheader(c,b,tag,e,s)
        if c ~= "" then
            s = addcomment(c,s)
        end
        local headers     = result.headers
        local headerorder = result.headerorder
        if headers[tag] then
            if verbose then
                report("add header   : %s",tag)
            end
            s = headers[tag] .. "\n" .. s
        else
            if verbose then
                report("new header   : %s",tag)
            end
            headerorder[#headerorder+1] = tag
        end
        headers[tag] = s
        result.nofheaders = result.nofheaders + 1
        return ""
    end

    local function addcode(c,b,s)
        if c ~= "" then
            s = addcomment(c,s)
        end
        local nofcode = result.nofcode + 1
        result.codes[nofcode] = s
        result.nofcode = nofcode
        return ""
    end

    local function adddefine(c,b,s)
        s = fixdefine(s)
        if c ~= "" then
            s = addcomment(c,s)
        end
        nofdefines = result.nofdefines + 1
        result.defines[nofdefines] = s
        result.nofdefines = nofdefines
        return ""
    end

    local p_n_collect_1 = Cs ( (
        p_n_snippet / addsnippet
      + p_n_header  / addheader
      + p_rest
    )^1 )

    local p_n_collect_2 = Cs ( (
        p_n_code   / addcode
      + p_n_define / adddefine
      + p_rest
    )^1 )

    local p_c_collect_1 = Cs ( (
        p_c_snippet / addsnippet
      + p_c_header  / addheader
      + p_rest
    )^1 )

    local p_c_collect_2 = Cs ( (
        p_c_code   / addcode
      + p_c_define / adddefine
      + p_rest
    )^1 )

    local function getcontent_1(data)
        return lpegmatch(result.keepcomment and p_c_collect_1 or p_n_collect_1,data)
    end

    local function getcontent_2(data)
        return lpegmatch(result.keepcomment and p_c_collect_2 or p_n_collect_2,data)
    end

 -- local function dereference(b,tag,e)
    local function dereference(indent,b,tag,e)
        local tag  = clean(tag)
        local name = result.alltags[tag]
        if name then
            local data = result.snippets[name]
            if data then
                result.usedsnippets[name] = true
                result.unresolved[name] = nil
                result.nofresolved = result.nofresolved + 1
                if verbose then
                    report("resolved     : %s",tag)
                end
            --  return data
                return indent .. string.gsub(data,"[\n\r]+","\n" .. indent)
            elseif tag == "header goes here" then
                return "@<header goes here@>"
            else
                result.nofunresolved = result.nofunresolved + 1
                result.unresolved[name] = name
                report("unresolved   : %s",tag)
                return "\n/* unresolved: " .. tag .. " */\n"
            end
        else
            report("fatal error  : invalid tag")
            os.exit()
        end
    end

    local p_resolve = Cs((p_reference / dereference + p_rest)^1)

    local function resolve(data)
        local iteration = 0
        while true do
            iteration = iteration + 1
            if data == "" then
                if verbose then
                    report("warning      : empty code at iteration %i",iteration)
                end
                return data
            else
                local done = lpegmatch(p_resolve,data)
                if not done then
                    report("fatal error  : invalid code at iteration %i",iteration)
                    os.exit()
                elseif done == data then
                    return done
                else
                    data = done
                end
            end
        end
        return data
    end

    local function patch(filename,data)
        local patchfile = file.replacesuffix(filename,"patch.lua")
        local patches   = table.load(patchfile)
        if not patches then
            patchfile = file.basename(patchfile)
            patches   = table.load(patchfile)
        end
        if patches then
            local action = patches.action
            if type(action) == "function" then
                if verbose then
                    report("patching     : %s", filename)
                end
                data = action(data,report)
            end
        end
        return data
    end

    function cweb.convert(filename,target)

        statistics.starttiming(filename)

        result = {
            snippets      = { },
            usedsnippets  = { },
            alltags       = { },
            dottags       = { },
            headers       = { },
            headerorder   = { },
            defines       = { },
            codes         = { },
            unresolved    = { },
            nofsnippets   = 0,
            nofheaders    = 0,
            nofdefines    = 0,
            nofcode       = 0,
            nofresolved   = 0,
            nofunresolved = 0,

         -- keepcomment   = true, - not okay but good enough for a rough initial

        }

        local data   = io.loaddata(filename)
        local banner = '/* This file is generated by "mtxrun --script "mtx-wtoc.lua" from the metapost cweb files. */\n\n'

        report("main file    : %s", filename)
        report("main size    : %i bytes", #data)

        data = patch(filename,data)
        data = cleanup(data)

        result.alltags["header goes here"] = clean("header goes here")

        getpresets(data) -- into result

        data = getcontent_1(data) -- into result
        data = getcontent_2(data) -- into result

        result.defines = concat(result.defines,"\n\n")
        result.codes   = concat(result.codes,"\n\n")

        result.snippets["header goes here"] = result.defines

        result.codes = resolve(result.codes)
        result.codes = finalize(result.codes,result.keepcomment)

        for i=1,#result.headerorder do
            local name = result.headerorder[i]
            local code = result.headers[name]
            report("found header : %s", name)
            code = resolve(code)
            code = finalize(code,result.keepcomment)
            result.headers[name] = code
        end

        local fullname = file.join(target,file.addsuffix(file.nameonly(filename),"c"))

        report("result file  : %s", fullname)
        report("result size  : %i bytes", result.codes and #result.codes or 0)

        if result.keepcomment then
            report("unprocessed  : %i bytes", #data)
            print(data)
        end

        io.savedata(fullname,banner .. result.codes)

        -- save header files

        for i=1,#result.headerorder do
            local name = result.headerorder[i]
            local code = result.headers[name]
            local fullname = file.join(target,name)
            report("extra file %i : %s", i, fullname)
            report("extra size %i : %i bytes", i, #code)
            io.savedata(fullname,banner .. code)
        end

        -- some statistics

        report("nofsnippets  : %i", result.nofsnippets)
        report("nofheaders   : %i", result.nofheaders)
        report("nofdefines   : %i", result.nofdefines)
        report("nofcode      : %i", result.nofcode)
        report("nofresolved  : %i", result.nofresolved)
        report("nofunresolved: %i", result.nofunresolved)

        for tag in table.sortedhash(result.unresolved) do
            report("fuzzy tag    : %s",tag)
        end

        for tag in table.sortedhash(result.snippets) do
            if not result.usedsnippets[tag] then
                report("unused tag   : %s",tag)
            end
        end

        statistics.stoptiming(filename)

        report("run time     : %s", statistics.elapsedtime(filename))

    end

end

function cweb.convertfiles(source,target)

    report("source path  : %s", source)
    report("target path  : %s", target)

    report()

    local files = dir.glob(file.join(source,"*.w"))

    statistics.starttiming(files)
    for i=1,#files do
        cweb.convert(files[i],target)
        report()
    end
    statistics.stoptiming(files)

    report("total time   : %s", statistics.elapsedtime(files))

end

-- We sort of hard code the files that we convert. In principle we can make a more
-- general converter but I don't need to convert cweb files other than these. The
-- converter tries to make the H/C files look kind of good so that I can expect then
-- in (for instance) Visual Studio.

local source = file.join(dir.current(),"../source/mp/mpw")
local target = file.join(dir.current(),"../source/mp/mpc")

-- local source = file.join("e:/luatex/luatex-experimental-export/source/texk/web2c/mplibdir/")
-- local target = file.join("e:/luatex/luatex-experimental-export/source/texk/web2c")

cweb.convertfiles(source,target)

-- -- inefficient but good enough
--
-- local function strip(s)
--
--     local newline = lpeg.patterns.newline
--     local spaces  = S(" \t")
--
--     local strip_comment  = (P("/*") * (1-P("*/"))^1 * P("*/")) / ""
--     local strip_line     = (P("#line") * (1 - newline)^1 * newline * spaces^0) / ""
--     local strip_spaces   = spaces^1 / " "
--     local strip_trailing = (P("//") * (1 - newline)^0) / ""
--     local strip_final    = (spaces^0 * P("\\") * spaces^0) / "" * newline
--     local strip_lines    = (spaces^0 / "") * newline^1 * (spaces^0 / "") / "\n"
--     local strip_weird    = (spaces + newline)^0 * (P("{") * (spaces + newline)^0 * P("}")) * (spaces + newline)^0 / "{}\n"
--     local strip_singles  = (spaces^0 / "") * S("^`'\"&%|()[]#?!<>\\/{}=,.*+-;:") * (spaces^0 / "")
--
--     local pattern_1 = Cs ( (
--         strip_singles +
--         P(1)
--     )^1 )
--
--     local pattern_2 = Cs ( (
--         strip_weird +
--         strip_comment +
--         strip_line +
--         strip_trailing +
--         strip_lines +
--         strip_final +
--         strip_spaces +
--         P(1)
--     )^1 )
--
--     while true do
--         local r = lpegmatch(pattern_1,s)
--         local r = lpegmatch(pattern_2,r)
--         if s == r then
--             break
--         else
--             s = r
--         end
--     end
--
--     return s
--
-- end
