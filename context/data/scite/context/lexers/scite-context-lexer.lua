local info = {
    version   = 1.400,
    comment   = "basics for scintilla lpeg lexer for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "contains copyrighted code from mitchell.att.foicica.com",

}

-- There is some history behind these lexers. When LPEG came around, we immediately adopted that in CONTEXT
-- and one of the first things to show up were the verbatim plugins. There we have several models: line based
-- and syntax based. The way we visualize the syntax for TEX, METAPOST and LUA relates closely to the way the
-- CONTEXT user interface evolved. We have LPEG all over the place.
--
-- When at some point it became possible to have an LPEG lexer in SCITE (by using the TEXTADEPT dll) I figured
-- out a mix of what we had and what is needed there. The lexers that came with the dll were quite slow so in
-- order to deal with the large \LUA\ data files I rewrote the lexing so that it did work with the dll but was
-- useable otherwise too. There are quite some comments in the older files that explain these steps. However, it
-- never became pretty and didn't always looked the way I wanted (read: more in tune with how we use LUA in
-- CONTEXT). Over time the plugin evolved and the code was adapted (to some extend it became more like we already
-- had) but when SCITE moved to version 5 (as part of a C++ update) and the dll again changed it became clear
-- that we had to come up with a different approach. Not only the dll had to be kept in sync, but we also had to
-- keep adapting interfaces. When SCITE changed to a new lexer framework some of the properties setup changed
-- but after adapting that it still failed to load. I noticed some new directory scanning in the dll code which
-- probably interferes with the weay we load. (I probably need to look into that but adapting the directory
-- structure and adding some cheats is not what I like to do.)
--
-- The original plan was to have TEXTADEPT as fallback but at the pace it was evolving it was not something we
-- could use yet. Because it was meant to be configurable we even had a stripped down, tuned for CONTEXT related
-- document processing, interface defined. After all it is good to have a fallback in case SCITE fails. But keeping
-- up with the changing interfaces made clear that it was not really meant for this (replacing components is hard
-- and I assume it's more about adding stuff to the shipped editor, but more and more features is not what we need:
-- editors quickly become too loaded by confusing features that make no sense when editing documents. We need
-- something that is easy to use for novice (and occasional) users and SCITE always has been perfect for that. The
-- nice thing about TEXTADEPT is that it supports more platforms, the nice thing about SCITE is that it is stable
-- and small. I understand that the interplay between the scintilla and lexzilla and lexlpeg is subtle but because
-- of that using it generic (other than texadept) is hard.
--
-- So, the question was: how to proceed. The main component missing in SCITE's LUA interface is LPEG. By adding
-- that, plus a few bytewise styler helpers, I was able to use the lexers without the dll. The advantage of using
-- the built in methods is that we (1) can use the same LUA instance that other script use, (2) have access to all
-- kind of properties, (3) can have a cleaner implementation (for loading), (4) can make the code look better. In
-- retrospect I should have done that long ago. In the end it turned out that the new implementaion is just as
-- fast but also more memory efficient (the dll could occasionally crash on many open files and loading many files
-- when restarting was pretty slow too probably because of excessive immediate lexing).
--
-- It will take a while to strip out all the artifacts needed for the dll based lexer but we'll get there. Because
-- we also supported the regular lexers that came with the dll some keys got the names needed there but it no
-- longer makes sense: we can use the built-in SCITE lexers for those. One of the things that is gone is the
-- whitespace trickery: we always lex the whole document, as we already did most of the time (the only possible
-- gain is when one is at the end of a document and then we observed side effects of not enough backtracking).
--
-- I will keep the old files archived so we can always use the (optimized) helpers from those if we ever need
-- them. I could go back to the code we had before the dll came around but it makes no sense, so for now I just
-- pruned and rewrote. The lexer definitions are still such that we could load other lexers but that compatbility
-- has now been dropped so I might clean up that bit too. It's not that hard to write additional lexers if I need
-- them.
--
-- We assume at least LUA 5.3 now (tests with LUA 5.4 demonstrated a 10% performance gain). I will also make a
-- helper module that has all the nice CONTEXT functions available. Logging to file is gone because in SCITE we
-- can write to the output pane. Actually: I'm still waiting for scite to overload that output pain lexer.
--
-- As mentioned, the dll based lexer uses whitespace to determine where to start and then only lexes what comes
-- after it. In the mixed lexing that we use that hardly makes sense, because editing before the end still needs
-- to backtrack. The question then becomes if we really save runtime. Also, we can be nested inside nested which
-- never worked well but we can do that now. We also use one thems so there is no need to be more clever. We no
-- longer keep the styles in a lexer simply because we use a consistent set and have plenty of styles in SCITE now.
--
-- The previous versions had way more code because we also could load the lexers shipped with the dll, had quite
-- some optimizations and caching for older dll's and SCITE limitations, so the real tricks are in these old files.
--
-- We now can avoid the intermediate tables in SCITE and only use them when we lex in CONTEXT. So in the end we're
-- back where we started more than a decade ago. It's a pitty that we dropped TEXTADEPT support but it was simply
-- too hard to keep up. So be it. Maybe some day ... after all we still have the old code.
--
-- We had the lexers namespace plus additional tables and functions in the lexerx.context namespace in order not to
-- overload 'original' functionality but the context subtable could go away.
--
-- Performance: I decided to go for whole document lexing every time which is fast enough for what we want. If a
-- file is very (!) large one can always choose to "none" lexer in the interface. The advantage of whole parsing
-- is that it is more robust than wildguessing on whitespace (which can fail occasionally), that we are less likely
-- to crash after being in the editor for a whole day, and that preamble scanning etc is now more reliable. If
-- needed I can figure out some gain (but a new and faster machine makes more sense). There is optional partial
-- document lexing (under testing). In any case, the former slow loading many documents at startup delay is gone
-- now (somehow it looked like all tabs were lexed when a document was opened).

local global = _G

local lpeg  = require("lpeg")

if lpeg.setmaxstack then lpeg.setmaxstack(1000) end

local gmatch, match, lower, upper, gsub, format = string.gmatch, string.match, string.lower, string.upper, string.gsub, string.format
local concat, sort = table.concat, table.sort
local type, next, setmetatable, tostring = type, next, setmetatable, tostring
local R, P, S, C, Cp, Ct, Cmt, Cc, Cf, Cg, Cs = lpeg.R, lpeg.P, lpeg.S, lpeg.C, lpeg.Cp, lpeg.Ct, lpeg.Cmt, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Cs
local lpegmatch = lpeg.match

local usage    = resolvers and "context" or "scite"
local trace    = false
local collapse = false -- can save some 15% (maybe easier on scintilla)

local lexers     = { }
local styles     = { }
local numbers    = { }
local helpers    = { }
local patterns   = { }
local usedlexers = { }

lexers.usage     = usage

lexers.helpers   = helpers
lexers.styles    = styles
lexers.numbers   = numbers
lexers.patterns  = patterns

-- Maybe at some point I will just load the basic mtx toolkit which gives a lot of benefits but for now we
-- do with poor mans copies.
--
-- Some basic reporting.

local report = logs and logs.reporter("scite lpeg lexer") or function(fmt,str,...)
    if str then
        fmt = format(fmt,str,...)
    end
    print(format("scite lpeg lexer > %s",fmt))
end

report("loading context lexer module")

lexers.report = report

local function sortedkeys(hash) -- simple version, good enough for here
    local t, n = { }, 0
    for k, v in next, hash do
        t[#t+1] = k
        local l = #tostring(k)
        if l > n then
            n = l
        end
    end
    sort(t)
    return t, n
end

helpers.sortedkeys = sortedkeys

-- begin of patterns (we should take them from l-lpeg.lua)

do

    local anything             = P(1)
    local idtoken              = R("az","AZ","\127\255","__")
    local digit                = R("09")
    local sign                 = S("+-")
    local period               = P(".")
    local octdigit             = R("07")
    local hexdigit             = R("09","AF","af")
    local lower                = R("az")
    local upper                = R("AZ")
    local alpha                = upper + lower
    local space                = S(" \n\r\t\f\v")
    local eol                  = S("\r\n")
    local backslash            = P("\\")
    local decimal              = digit^1
    local octal                = P("0")
                               * octdigit^1
    local hexadecimal          = P("0") * S("xX")
                               * (hexdigit^0 * period * hexdigit^1 + hexdigit^1 * period * hexdigit^0 + hexdigit^1)
                               * (S("pP") * sign^-1 * hexdigit^1)^-1 -- *
    local integer              = sign^-1
                               * (hexadecimal + octal + decimal)
    local float                = sign^-1
                               * (digit^0 * period * digit^1 + digit^1 * period * digit^0 + digit^1)
                               * S("eE") * sign^-1 * digit^1 -- *

    patterns.idtoken           = idtoken
    patterns.digit             = digit
    patterns.sign              = sign
    patterns.period            = period
    patterns.octdigit          = octdigit
    patterns.hexdigit          = hexdigit
    patterns.ascii             = R("\000\127") -- useless
    patterns.extend            = R("\000\255") -- useless
    patterns.control           = R("\000\031")
    patterns.lower             = lower
    patterns.upper             = upper
    patterns.alpha             = alpha
    patterns.decimal           = decimal
    patterns.octal             = octal
    patterns.hexadecimal       = hexadecimal
    patterns.float             = float
    patterns.cardinal          = decimal

    patterns.signeddecimal     = sign^-1 * decimal
    patterns.signedoctal       = sign^-1 * octal
    patterns.signedhexadecimal = sign^-1 * hexadecimal
    patterns.integer           = integer
    patterns.real              =
        sign^-1 * (                    -- at most one
            digit^1 * period * digit^0 -- 10.0 10.
          + digit^0 * period * digit^1 -- 0.10 .10
          + digit^1                    -- 10
       )

    patterns.anything          = anything
    patterns.any               = anything
    patterns.restofline        = (1-eol)^1
    patterns.space             = space
    patterns.spacing           = space^1
    patterns.nospacing         = (1-space)^1
    patterns.eol               = eol
    patterns.newline           = P("\r\n") + eol
    patterns.backslash         = backslash

    local endof                = S("\n\r\f")

    patterns.startofline       = P(function(input,index)
        return (index == 1 or lpegmatch(endof,input,index-1)) and index
    end)

end

do

    local char     = string.char
    local byte     = string.byte
    local format   = format

    local function utfchar(n)
        if n < 0x80 then
            return char(n)
        elseif n < 0x800 then
            return char(
                0xC0 + (n//0x00040),
                0x80 +  n           % 0x40
            )
        elseif n < 0x10000 then
            return char(
                0xE0 + (n//0x01000),
                0x80 + (n//0x00040) % 0x40,
                0x80 +  n           % 0x40
            )
        elseif n < 0x40000 then
            return char(
                0xF0 + (n//0x40000),
                0x80 + (n//0x01000),
                0x80 + (n//0x00040) % 0x40,
                0x80 +  n           % 0x40
            )
        else
         -- return char(
         --     0xF1 + (n//0x1000000),
         --     0x80 + (n//0x0040000),
         --     0x80 + (n//0x0001000),
         --     0x80 + (n//0x0000040) % 0x40,
         --     0x80 +  n             % 0x40
         -- )
            return "?"
        end
    end

    helpers.utfchar = utfchar

    local utf8next         = R("\128\191")
    local utf8one          = R("\000\127")
    local utf8two          = R("\194\223") * utf8next
    local utf8three        = R("\224\239") * utf8next * utf8next
    local utf8four         = R("\240\244") * utf8next * utf8next * utf8next

    local utfidentifier    = utf8two + utf8three + utf8four
    helpers.utfidentifier  = (R("AZ","az","__")      + utfidentifier)
                           * (R("AZ","az","__","09") + utfidentifier)^0

    helpers.utfcharpattern = P(1) * utf8next^0 -- unchecked but fast
    helpers.utfbytepattern = utf8one   / byte
                           + utf8two   / function(s) local c1, c2         = byte(s,1,2) return   c1 * 64 + c2                       -    12416 end
                           + utf8three / function(s) local c1, c2, c3     = byte(s,1,3) return  (c1 * 64 + c2) * 64 + c3            -   925824 end
                           + utf8four  / function(s) local c1, c2, c3, c4 = byte(s,1,4) return ((c1 * 64 + c2) * 64 + c3) * 64 + c4 - 63447168 end

    local p_false          = P(false)
    local p_true           = P(true)

    local function make(t)
        local function making(t)
            local p    = p_false
            local keys = sortedkeys(t)
            for i=1,#keys do
                local k = keys[i]
                if k ~= "" then
                    local v = t[k]
                    if v == true then
                        p = p + P(k) * p_true
                    elseif v == false then
                        -- can't happen
                    else
                        p = p + P(k) * making(v)
                    end
                end
            end
            if t[""] then
                p = p + p_true
            end
            return p
        end
        local p    = p_false
        local keys = sortedkeys(t)
        for i=1,#keys do
            local k = keys[i]
            if k ~= "" then
                local v = t[k]
                if v == true then
                    p = p + P(k) * p_true
                elseif v == false then
                    -- can't happen
                else
                    p = p + P(k) * making(v)
                end
            end
        end
        return p
    end

    local function collapse(t,x)
        if type(t) ~= "table" then
            return t, x
        else
            local n = next(t)
            if n == nil then
                return t, x
            elseif next(t,n) == nil then
                -- one entry
                local k = n
                local v = t[k]
                if type(v) == "table" then
                    return collapse(v,x..k)
                else
                    return v, x .. k
                end
            else
                local tt = { }
                for k, v in next, t do
                    local vv, kk = collapse(v,k)
                    tt[kk] = vv
                end
                return tt, x
            end
        end
    end

    function helpers.utfchartabletopattern(list)
        local tree = { }
        local n = #list
        if n == 0 then
            for s in next, list do
                local t = tree
                local p, pk
                for c in gmatch(s,".") do
                    if t == true then
                        t = { [c] = true, [""] = true }
                        p[pk] = t
                        p = t
                        t = false
                    elseif t == false then
                        t = { [c] = false }
                        p[pk] = t
                        p = t
                        t = false
                    else
                        local tc = t[c]
                        if not tc then
                            tc = false
                            t[c] = false
                        end
                        p = t
                        t = tc
                    end
                    pk = c
                end
                if t == false then
                    p[pk] = true
                elseif t == true then
                    -- okay
                else
                    t[""] = true
                end
            end
        else
            for i=1,n do
                local s = list[i]
                local t = tree
                local p, pk
                for c in gmatch(s,".") do
                    if t == true then
                        t = { [c] = true, [""] = true }
                        p[pk] = t
                        p = t
                        t = false
                    elseif t == false then
                        t = { [c] = false }
                        p[pk] = t
                        p = t
                        t = false
                    else
                        local tc = t[c]
                        if not tc then
                            tc = false
                            t[c] = false
                        end
                        p = t
                        t = tc
                    end
                    pk = c
                end
                if t == false then
                    p[pk] = true
                elseif t == true then
                    -- okay
                else
                    t[""] = true
                end
            end
        end
        collapse(tree,"")
        return make(tree)
    end

    patterns.invisibles = helpers.utfchartabletopattern {
        utfchar(0x00A0), -- nbsp
        utfchar(0x2000), -- enquad
        utfchar(0x2001), -- emquad
        utfchar(0x2002), -- enspace
        utfchar(0x2003), -- emspace
        utfchar(0x2004), -- threeperemspace
        utfchar(0x2005), -- fourperemspace
        utfchar(0x2006), -- sixperemspace
        utfchar(0x2007), -- figurespace
        utfchar(0x2008), -- punctuationspace
        utfchar(0x2009), -- breakablethinspace
        utfchar(0x200A), -- hairspace
        utfchar(0x200B), -- zerowidthspace
        utfchar(0x202F), -- narrownobreakspace
        utfchar(0x205F), -- math thinspace
    }

    -- now we can make:

    patterns.wordtoken    = R("az","AZ","\127\255")
    patterns.wordpattern  = patterns.wordtoken^3 -- todo: if limit and #s < limit then

    patterns.iwordtoken   = patterns.wordtoken - patterns.invisibles
    patterns.iwordpattern = patterns.iwordtoken^3

end

-- end of patterns

-- begin of scite properties

-- Because we use a limited number of lexers we can provide a new whitespace on demand. If needed
-- we can recycle from a pool or we can just not reuse a lexer and load anew. I'll deal with that
-- when the need is there. At that moment I might as well start working with nested tables (so that
-- we have a langauge tree.

local whitespace = function() return "whitespace" end

local maxstyle    = 127 -- otherwise negative values in editor object -- 255
local nesting     = 0
local style_main  = 0
local style_white = 0

if usage == "scite" then

    local names = { }
    local props = { }
    local count = 1

    -- 32 -- 39 are reserved; we want to avoid holes so we preset:

    for i=0,maxstyle do
        numbers[i] = "default"
    end

    whitespace = function()
        return style_main -- "mainspace"
    end

    function lexers.loadtheme(theme)
        styles = theme or { }
        for k, v in next, styles do
            names[#names+1] = k
        end
        sort(names)
        for i=1,#names do
            local name = names[i]
            styles[name].n = count
            numbers[name] = count
            numbers[count] = name
            if count == 31 then
                count = 40
            else
                count = count + 1
            end
        end
        for i=1,#names do
            local t = { }
            local s = styles[names[i]]
            local n = s.n
            local fore = s.fore
            local back = s.back
            local font = s.font
            local size = s.size
            local bold = s.bold
            if fore then
                if #fore == 1 then
                    t[#t+1] = format("fore:#%02X%02X%02X",fore[1],fore[1],fore[1])
                elseif #fore == 3 then
                    t[#t+1] = format("fore:#%02X%02X%02X",fore[1],fore[2],fore[3])
                end
            end
            if back then
                if #back == 1 then
                    t[#t+1] = format("back:#%02X%02X%02X",back[1],back[1],back[1])
                elseif #back == 3 then
                    t[#t+1] = format("back:#%02X%02X%02X",back[1],back[2],back[3])
                else
                    t[#t+1] = "back:#000000"
                end
            end
            if bold then
                t[#t+1] = "bold"
            end
            if font then
                t[#t+1] = format("font:%s",font)
            end
            if size then
                t[#t+1] = format("size:%s",size)
            end
            if #t > 0 then
                props[n] = concat(t,",")
            end
        end
        setmetatable(styles, {
            __index =
                function(target,name)
                    if name then
                        count = count + 1
                        if count > maxstyle then
                            count = maxstyle
                        end
                        numbers[name] = count
                        local style = { n = count }
                        target[name] = style
                        return style
                    end
                end
        } )
        lexers.styles  = styles
        lexers.numbers = numbers

        style_main  = styles.mainspace.n
        style_white = styles.whitespace.n
    end

    function lexers.registertheme(properties,name)
        for n, p in next, props do
            local tag = "style.script_" .. name .. "." .. n
            properties[tag] = p
        end
    end

end

-- end of scite properties

-- begin of word matchers

do

  -- function patterns.exactmatch(words,case_insensitive)
  --     local characters = concat(words)
  --     local pattern = S(characters) + patterns.idtoken
  --     if case_insensitive then
  --         pattern = pattern + S(upper(characters)) + S(lower(characters))
  --     end
  --     if case_insensitive then
  --         local list = { }
  --         if #words == 0 then
  --             for k, v in next, words do
  --                 list[lower(k)] = v
  --             end
  --         else
  --             for i=1,#words do
  --                 list[lower(words[i])] = true
  --             end
  --         end
  --         return Cmt(pattern^1, function(_,i,s)
  --             return list[lower(s)] -- and i or nil
  --         end)
  --     else
  --         local list = { }
  --         if #words == 0 then
  --             for k, v in next, words do
  --                 list[k] = v
  --             end
  --         else
  --             for i=1,#words do
  --                 list[words[i]] = true
  --             end
  --         end
  --         return Cmt(pattern^1, function(_,i,s)
  --             return list[s] -- and i or nil
  --         end)
  --     end
  -- end
  --
  -- function patterns.justmatch(words)
  --     local p = P(words[1])
  --     for i=2,#words do
  --         p = p + P(words[i])
  --     end
  --     return p
  -- end

    -- we could do camelcase but that is not what users use for keywords

    local p_finish = #(1 - R("az","AZ","__"))

    patterns.finishmatch = p_finish

    function patterns.exactmatch(words,ignorecase)
        local list = { }
        if ignorecase then
            if #words == 0 then
                for k, v in next, words do
                    list[lower(k)] = v
                end
            else
                for i=1,#words do
                    list[lower(words[i])] = true
                end
            end
            return Cmt(pattern^1, function(_,i,s)
                return list[lower(s)] -- and i or nil
            end)
        else
            if #words == 0 then
                for k, v in next, words do
                    list[k] = v
                end
            else
                for i=1,#words do
                    list[words[i]] = true
                end
            end
        end
        return helpers.utfchartabletopattern(list) * p_finish
    end

    patterns.justmatch = patterns.exactmatch

end

-- end of word matchers

-- begin of loaders

do

    local cache = { }

    function lexers.loadluafile(name)
        local okay, data = pcall(require, name)
        if data then
            if trace then
                report("lua file '%s' has been loaded",name)
            end
            return data, name
        end
        if trace then
            report("unable to load lua file '%s'",name)
        end
    end

    function lexers.loaddefinitions(name)
        local data = cache[name]
        if data then
            if trace then
                report("reusing definitions '%s'",name)
            end
            return data
        elseif trace and data == false then
            report("definitions '%s' were not found",name)
        end
        local okay, data = pcall(require, name)
        if not data then
            report("unable to load definition file '%s'",name)
            data = false
        elseif trace then
            report("definition file '%s' has been loaded",name)
        end
        cache[name] = data
        return type(data) == "table" and data
    end

end

-- end of loaders

-- begin of spell checking (todo: pick files from distribution instead)

do

    -- spell checking (we can only load lua files)
    --
    -- return {
    --     min   = 3,
    --     max   = 40,
    --     n     = 12345,
    --     words = {
    --         ["someword"]    = "someword",
    --         ["anotherword"] = "Anotherword",
    --     },
    -- }

    local lists    = { }
    local disabled = false

    function lexers.disablewordcheck()
        disabled = true
    end

    function lexers.setwordlist(tag,limit) -- returns hash (lowercase keys and original values)
        if not tag or tag == "" then
            return false, 3
        end
        local list = lists[tag]
        if not list then
            list = lexers.loaddefinitions("spell-" .. tag)
            if not list or type(list) ~= "table" then
                report("invalid spell checking list for '%s'",tag)
                list = { words = false, min = 3 }
            else
                list.words = list.words or false
                list.min   = list.min or 3
            end
            lists[tag] = list
        end
        if trace then
            report("enabling spell checking for '%s' with minimum '%s'",tag,list.min)
        end
        return list.words, list.min
    end

    if usage ~= "scite" then

        function lexers.styleofword(validwords,validminimum,s,p)
            if not validwords or #s < validminimum then
                return "text", p
            else
                -- keys are lower
                local word = validwords[s]
                if word == s then
                    return "okay", p -- exact match
                elseif word then
                    return "warning", p -- case issue
                else
                    local word = validwords[lower(s)]
                    if word == s then
                        return "okay", p -- exact match
                    elseif word then
                        return "warning", p -- case issue
                    elseif upper(s) == s then
                        return "warning", p -- probably a logo or acronym
                    else
                        return "error", p
                    end
                end
            end
        end

    end

end

-- end of spell checking

-- begin lexer management

lexers.structured = false
-- lexers.structured = true -- the future for the typesetting end

do

    function lexers.new(name,filename)
        if not filename then
            filename = false
        end
        local lexer = {
            name       = name,
            filename   = filename,
            whitespace = whitespace()
        }
        if trace then
            report("initializing lexer tagged '%s' from file '%s'",name,filename or name)
        end
        return lexer
    end

    if usage == "scite" then

        -- overloaded later

        function lexers.token(name, pattern)
            local s = styles[name] -- always something anyway
            return pattern * Cc(s and s.n or 32) * Cp()
        end

    else

        function lexers.token(name, pattern)
            return pattern * Cc(name) * Cp()
        end

    end

    -- todo: variant that directly styles

    local function append(pattern,step)
        if not step then
            return pattern
        elseif pattern then
            return pattern + P(step)
        else
            return P(step)
        end
    end

    local function prepend(pattern,step)
        if not step then
            return pattern
        elseif pattern then
            return P(step) + pattern
        else
            return P(step)
        end
    end

    local wrapup = usage == "scite" and
        function(name,pattern)
            return pattern
        end
    or
        function(name,pattern,nested)
            if lexers.structured then
                return Cf ( Ct("") * Cg(Cc("name") * Cc(name)) * Cg(Cc("data") * Ct(pattern)), rawset)
            elseif nested then
                return pattern
            else
                return Ct (pattern)
            end
        end

    local function construct(namespace,lexer,level)
        if lexer then
            local rules    = lexer.rules
            local embedded = lexer.embedded
            local grammar  = nil
            if embedded then
                for i=1,#embedded do
                    local embed = embedded[i]
                    local done  = embed.done
                    if not done then
                        local lexer = embed.lexer
                        local start = embed.start
                        local stop  = embed.stop
                        if usage == "scite" then
                            start = start / function() nesting = nesting + 1 end
                            stop  = stop  / function() nesting = nesting - 1 end
                        end
                        if trace then
                            start = start / function() report("    nested lexer %s: start",lexer.name) end
                            stop  = stop  / function() report("    nested lexer %s: stop", lexer.name) end
                        end
                        done = start * (construct(namespace,lexer,level+1) - stop)^0 * stop
                        done = wrapup(lexer.name,done,true)
                    end
               -- grammar = prepend(grammar, done)
                  grammar = append(grammar, done)
                end
            end
            if rules then
                for i=1,#rules do
                    grammar = append(grammar,rules[i][2])
                end
            end
            return grammar
        end
    end

    function lexers.load(filename,namespace)
        if not namespace then
            namespace = filename
        end
        local lexer = usedlexers[namespace] -- we load by filename but the internal name can be short
        if lexer then
            if trace then
                report("reusing lexer '%s'",namespace)
            end
            return lexer
        elseif trace then
            report("loading lexer '%s' from '%s'",namespace,filename)
        end
        local lexer, name = lexers.loadluafile(filename)
        if not lexer then
            report("invalid lexer file '%s'",filename)
        elseif type(lexer) ~= "table" then
            if trace then
                report("lexer file '%s' gets a dummy lexer",filename)
            end
            return lexers.new(filename)
        end
        local grammar = construct(namespace,lexer,1)
        if grammar then
            grammar = wrapup(namespace,grammar^0)
            lexer.grammar = grammar
        end
        --
        local backtracker = lexer.backtracker
        local foretracker = lexer.foretracker
        if backtracker then
            local start    = 1
            local position = 1
            local pattern  = (Cmt(Cs(backtracker),function(s,p,m) if p > start then return #s else position = p - #m end end) + P(1))^1
            lexer.backtracker = function(str,offset)
                position = 1
                start    = offset
                lpegmatch(pattern,str,1)
                return position
            end
        end
        if foretracker then
            local start    = 1
            local position = 1
            local pattern  = (Cmt(Cs(foretracker),function(s,p,m) position = p - #m return #s end) + P(1))^1
            lexer.foretracker = function(str,offset)
                position = offset
                start    = offset
                lpegmatch(pattern,str,position)
                return position
            end
        end
        --
        usedlexers[filename] = lexer
        return lexer
    end

    function lexers.embed(parent, embed, start, stop, rest)
        local embedded = parent.embedded
        if not embedded then
            embedded        = { }
            parent.embedded = embedded
        end
        embedded[#embedded+1] = {
            lexer = embed,
            start = start,
            stop  = stop,
            rest  = rest,
        }
    end

end

-- end lexer management

-- This will become a configurable option (whole is more reliable but it can
-- be slow on those 5 megabyte lua files):

-- begin of context typesetting lexer

if usage ~= "scite" then

    local function collapsed(t)
        local lasttoken = nil
        local lastindex = nil
        for i=1,#t,2 do
            local token    = t[i]
            local position = t[i+1]
            if token == lasttoken then
                t[lastindex] = position
            elseif lastindex then
                lastindex = lastindex + 1
                t[lastindex] = token
                lastindex = lastindex + 1
                t[lastindex] = position
                lasttoken = token
            else
                lastindex = i+1
                lasttoken = token
            end
        end
        for i=#t,lastindex+1,-1 do
            t[i] = nil
        end
        return t
    end

    function lexers.lex(lexer,text) -- get rid of init_style
        local grammar = lexer.grammar
        if grammar then
            nesting = 0
            if trace then
                report("lexing '%s' string with length %i",lexer.name,#text)
            end
            local t = lpegmatch(grammar,text)
            if collapse then
                t = collapsed(t)
            end
            return t
        else
            return { }
        end
    end

end

-- end of context typesetting lexer

-- begin of scite editor lexer

if usage == "scite" then

    -- For char-def.lua we need some 0.55 s with Lua 5.3 and 10% less with Lua 5.4 (timed on a 2013
    -- Dell precision with i7-3840QM). That test file has 271540 lines of Lua (table) code and is
    -- 5.312.665 bytes large (dd 2021.09.29). The three methods perform about the same but the more
    -- direct approach saves some tables. Using the new Lua garbage collector makes no difference.
    --
    -- We can actually integrate folding in here if we want but it might become messy as we then
    -- also need to deal with specific newlines. We can also (in scite) store some extra state wrt
    -- the language used.
    --
    -- Operating on a range (as in the past) is faster when editing very large documents but we
    -- don't do that often. The problem is that backtracking over whitespace is tricky for some
    -- nested lexers.

    local editor       = false
    local startstyling = false   -- editor:StartStyling(position,style)
    local setstyling   = false   -- editor:SetStyling(slice,style)
    local getlevelat   = false   -- editor.StyleAt[position] or StyleAt(editor,position)
    local getlineat    = false
    local thestyleat   = false   -- editor.StyleAt[position]
    local thelevelat   = false

    local styleoffset  = 1
    local foldoffset   = 0

    local function seteditor(usededitor)
        editor       = usededitor
        startstyling = editor.StartStyling
        setstyling   = editor.SetStyling
        getlevelat   = editor.FoldLevel        -- GetLevelAt
        getlineat    = editor.LineFromPosition
        thestyleat   = editor.StyleAt
        thelevelat   = editor.FoldLevel        -- SetLevelAt
    end

    function lexers.token(style, pattern)
        if type(style) ~= "number" then
            style = styles[style] -- always something anyway
            style = style and style.n or 32
        end
        return pattern * Cp() / function(p)
            local n = p - styleoffset
            if nesting > 0 and style == style_main then
                style = style_white
            end
            setstyling(editor,n,style)
            styleoffset = styleoffset + n
        end
    end

    -- used in: tex txt xml

    function lexers.styleofword(validwords,validminimum,s,p)
        local style
        if not validwords or #s < validminimum then
            style = numbers.text
        else
            -- keys are lower
            local word = validwords[s]
            if word == s then
                style = numbers.okay -- exact match
            elseif word then
                style = numbers.warning -- case issue
            else
                local word = validwords[lower(s)]
                if word == s then
                    style = numbers.okay -- exact match
                elseif word then
                    style = numbers.warning -- case issue
                elseif upper(s) == s then
                    style = numbers.warning -- probably a logo or acronym
                else
                    style = numbers.error
                end
            end
        end
        local n = p - styleoffset
        setstyling(editor,n,style)
        styleoffset = styleoffset + n
    end

    -- when we have an embedded language we can not rely on the range that
    -- scite provides because we need to look further

    -- it looks like scite starts before the cursor / insert

    local function scite_range(lexer,size,start,length,partial) -- set editor
        if partial then
            local backtracker = lexer.backtracker
            local foretracker = lexer.foretracker
            if start == 0 and size == length then
                -- see end
            elseif (backtracker or foretracker) and start > 0 then
                local snippet = editor:textrange(0,size)
                if size ~= length then
                    -- only lstart matters, the rest is statistics; we operate on 1-based strings
                    local lstart = backtracker and backtracker(snippet,start+1) or 0
                    local lstop  = foretracker and foretracker(snippet,start+1+length) or size
                    if lstart > 0 then
                        lstart = lstart - 1
                    end
                    if lstop > size then
                        lstop = size - 1
                    end
                    local stop    = start + length
                    local back    = start - lstart
                    local fore    = lstop - stop
                    local llength = lstop - lstart + 1
                 -- snippet = string.sub(snippet,lstart+1,lstop+1) -- we can return the initial position in the lpegmatch
                 -- return back, fore, lstart, llength, snippet, lstart + 1
                    return back, fore, 0, llength, snippet, lstart + 1
                else
                    return 0, 0, 0, size, snippet, 1
                end
            else
                -- still not entirely okay (nested mp)
                local stop   = start + length
                local lstart = start
                local lstop  = stop
                while lstart > 0 do
                    if thestyleat[lstart] == style_main then
                        break
                    else
                        lstart = lstart - 1
                    end
                end
                if lstart < 0 then
                    lstart = 0
                end
                while lstop < size do
                    if thestyleat[lstop] == style_main then
                        break
                    else
                        lstop = lstop + 1
                    end
                end
                if lstop > size then
                    lstop = size
                end
                local back    = start - lstart
                local fore    = lstop - stop
                local llength = lstop - lstart + 1
                local snippet = editor:textrange(lstart,lstop)
                if llength > #snippet then
                    llength = #snippet
                end
                return back, fore, lstart, llength, snippet, 1
            end
        end
        local snippet = editor:textrange(0,size)
        return 0, 0, 0, size, snippet, 1
    end

    local function scite_lex(lexer,text,offset,initial)
        local grammar = lexer.grammar
        if grammar then
            styleoffset = 1
            nesting     = 0
            startstyling(editor,offset,32)
            local preamble = lexer.preamble
            if preamble then
                lpegmatch(preamble,offset == 0 and text or editor:textrange(0,500))
            end
            lpegmatch(grammar,text,initial)
        end
    end

    -- We can assume sane definitions that is: must languages use similar constructs for the start
    -- and end of something. So we don't need to waste much time on nested lexers.

    local newline           = patterns.newline

    local scite_fold_base   = SC_FOLDLEVELBASE       or 0
    local scite_fold_header = SC_FOLDLEVELHEADERFLAG or 0
    local scite_fold_white  = SC_FOLDLEVELWHITEFLAG  or 0
    local scite_fold_number = SC_FOLDLEVELNUMBERMASK or 0

    local function styletonumbers(folding,hash)
        if not hash then
            hash = { }
        end
        if folding then
            for k, v in next, folding do
                local s = hash[k] or { }
                for k, v in next, v do
                    local n = numbers[k]
                    if n then
                        s[n] = v
                    end
                end
                hash[k] = s
            end
        end
        return hash
    end

    local folders = setmetatable({ }, { __index = function(t, lexer)
        local folding = lexer.folding
        if folding then
            local foldmapping = styletonumbers(folding)
            local embedded    = lexer.embedded
            if embedded then
                for i=1,#embedded do
                    local embed = embedded[i]
                    local lexer = embed.lexer
                    if lexer then
                        foldmapping = styletonumbers(lexer.folding,foldmapping)
                    end
                end
            end
            local foldpattern = helpers.utfchartabletopattern(foldmapping)
            local resetparser = lexer.resetparser
            local line        = 0
            local current     = scite_fold_base
            local previous    = scite_fold_base
            --
            foldpattern = Cp() * (foldpattern/foldmapping) / function(s,match)
                if match then
                    local l = match[thestyleat[s + foldoffset - 1]]
                    if l then
                        current = current + l
                    end
                end
            end
            local action_yes = function()
                if current > previous then
                    previous = previous | scite_fold_header
                elseif current < scite_fold_base then
                    current = scite_fold_base
                end
                thelevelat[line] = previous
                previous = current
                line = line + 1
            end
            local action_nop = function()
                previous = previous | scite_fold_white
                thelevelat[line] = previous
                previous = current
                line = line + 1
            end
            --
            foldpattern = ((foldpattern + (1-newline))^1 * newline/action_yes + newline/action_nop)^0
            --
            folder = function(text,offset,initial)
                if reset_parser then
                    reset_parser()
                end
                foldoffset = offset
                nesting    = 0
                --
                previous   = scite_fold_base -- & scite_fold_number
                if foldoffset == 0 then
                    line = 0
                else
                    line = getlineat(editor,offset) & scite_fold_number -- scite is at the beginning of a line
                 -- previous = getlevelat(editor,line) -- alas
                    previous = thelevelat[line] -- zero/one
                end
                current = previous
                lpegmatch(foldpattern,text,initial)
            end
        else
            folder = function() end
        end
        t[lexer] = folder
        return folder
    end } )

    -- can somehow be called twice (idem for the lexer)

    local function scite_fold(lexer,text,offset,initial)
        if text ~= "" then
            return folders[lexer](text,offset,initial)
        end
    end

    -- We cannot use the styler style setters so we use the editor ones. This has to do with the fact
    -- that the styler sees the (utf) encoding while we are doing bytes. There is also some initial
    -- skipping over characters. First versions uses those callers and had to offset by -2, but while
    -- that works with whole document lexing it doesn't work with partial lexing (one can also get
    -- multiple OnStyle calls per edit.
    --
    -- The backtracking here relates to the fact that we start at the outer lexer (otherwise embedded
    -- lexers can have occasional side effects. It also makes it possible to do better syntax checking
    -- on the fly (some day).
    --
    -- The (old) editor:textrange cannot handle nul characters. It that doesn't get patched in scite we
    -- need to use the styler variant (which is not in scite).

    -- lexer    : context lexer
    -- editor   : scite editor object (needs checking every update)
    -- language : scite lexer language id
    -- filename : current file
    -- size     : size of current file
    -- start    ; first position where to edit
    -- length   : length stripe to edit
    -- trace    : flag that signals tracing

    -- After quite some experiments with the styler methods I settled on the editor methods because
    -- these are not sensitive for utf and have no side effects like the two forward cursor positions.

    function lexers.scite_onstyle(lexer,editor,partial,language,filename,size,start,length,trace)
        seteditor(editor)
        local clock   = trace and os.clock()
        local back, fore, lstart, llength, snippet, initial = scite_range(lexer,size,start,length,partial)
        if clock then
            report("lexing %s", language)
            report("  document file : %s", filename)
            report("  document size : %i", size)
            report("  styler start  : %i", start)
            report("  styler length : %i", length)
            report("  backtracking  : %i", back)
            report("  foretracking  : %i", fore)
            report("  lexer start   : %i", lstart)
            report("  lexer length  : %i", llength)
            report("  text length   : %i", #snippet)
            report("  lexing method : %s", partial and "partial" or "whole")
            report("  after copying : %0.3f seconds",os.clock()-clock)
        end
        scite_lex(lexer,snippet,lstart,initial)
        if clock then
            report("  after lexing  : %0.3f seconds",os.clock()-clock)
        end
        scite_fold(lexer,snippet,lstart,initial)
        if clock then
            report("  after folding : %0.3f seconds",os.clock()-clock)
        end
    end

end

-- end of scite editor lexer

lexers.context = lexers -- for now

return lexers
