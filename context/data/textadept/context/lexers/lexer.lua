local info = {
    version   = 1.400,
    comment   = "basics for scintilla lpeg lexer for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "contains copyrighted code from mitchell.att.foicica.com",

}

-- We need a copy of this file to lexer.lua in the same path. This was not needed
-- before version 10 but I can't figure out what else to do. It looks like there
-- is some loading of lexer.lua but I can't see where.

if lpeg.setmaxstack then lpeg.setmaxstack(1000) end

local log      = false
local trace    = false
local detail   = false
local show     = false -- nice for tracing (also for later)
local collapse = false -- can save some 15% (maybe easier on scintilla)
local inspect  = false -- can save some 15% (maybe easier on scintilla)

-- local log      = true
-- local trace    = true

-- GET GOING
--
-- You need to copy this file over lexer.lua. In principle other lexers could work
-- too but not now. Maybe some day. All patterns will move into the patterns name
-- space. I might do the same with styles. If you run an older version of SciTE you
-- can take one of the archives. Pre 3.41 versions can just be copied to the right
-- path, as there we still use part of the normal lexer. Below we mention some
-- issues with different versions of SciTE. We try to keep up with changes but best
-- check careful if the version that yuou install works as expected because SciTE
-- and the scintillua dll need to be in sync.
--
-- REMARK
--
-- We started using lpeg lexing as soon as it came available. Because we had rather
-- demanding files and also wanted to use nested lexers, we ended up with our own
-- variant. At least at that time this was more robust and also much faster (as we
-- have some pretty large Lua data files and also work with large xml files). As a
-- consequence successive versions had to be adapted to changes in the (at that time
-- still unstable) api. In addition to lexing we also have spell checking and such.
-- Around version 3.60 things became more stable so I don't expect to change much.
--
-- LEXING
--
-- When pc's showed up we wrote our own editor (texedit) in MODULA 2. It was fast,
-- had multiple overlapping (text) windows, could run in the at most 1M memory at
-- that time, etc. The realtime file browsing with lexing that we had at that time
-- is still on my current wish list. The color scheme and logic that we used related
-- to the logic behind the ConTeXt user interface that evolved.
--
-- Later I rewrote the editor in perl/tk. I don't like the perl syntax but tk
-- widgets are very powerful and hard to beat. In fact, TextAdept reminds me of
-- that: wrap your own interface around a framework (tk had an edit control that one
-- could control completely not that different from scintilla). Last time I checked
-- it still ran fine so I might try to implement something like its file handling in
-- TextAdept.
--
-- In the end I settled for SciTE for which I wrote TeX and MetaPost lexers that
-- could handle keyword sets. With respect to lexing (syntax highlighting) ConTeXt
-- has a long history, if only because we need it for manuals. Anyway, in the end we
-- arrived at lpeg based lexing (which is quite natural as we have lots of lpeg
-- usage in ConTeXt). The basic color schemes haven't changed much. The most
-- prominent differences are the nested lexers.
--
-- In the meantime I made the lexer suitable for typesetting sources which was no
-- big deal as we already had that in place (ConTeXt used lpeg from the day it
-- showed up so we have several lexing options there too).
--
-- Keep in mind that in ConTeXt (typesetting) lexing can follow several approached:
-- line based (which is handy for verbatim mode), syntax mode (which is nice for
-- tutorials), and tolerant mode (so that one can also show bad examples or errors).
-- These demands can clash.
--
-- HISTORY
--
-- The remarks below are more for myself so that I keep track of changes in the
-- way we adapt to the changes in the scintillua and scite.
--
-- The fold and lex functions are copied and patched from original code by Mitchell
-- (see lexer.lua) in the scintillua distribution. So whatever I say below, assume
-- that all errors are mine. The ability to use lpeg in scintilla is a real nice
-- addition and a brilliant move. The code is a byproduct of the (mainly Lua based)
-- TextAdept which at the time I ran into it was a rapidly moving target so I
-- decided to stick ot SciTE. When I played with it, it had no realtime output pane
-- although that seems to be dealt with now (2017). I need to have a look at it in
-- more detail but a first test again made the output hang and it was a bit slow too
-- (and I also want the log pane as SciTE has it, on the right, in view). So, for
-- now I stick to SciTE even when it's somewhat crippled by the fact that we cannot
-- hook our own (language dependent) lexer into the output pane (somehow the
-- errorlist lexer is hard coded into the editor). Hopefully that will change some
-- day. The ConTeXt distribution has cmd runner for textdept that will plug in the
-- lexers discussed here as well as a dedicated runner. Considere it an experiment.
--
-- The basic code hasn't changed much but we had to adapt a few times to changes in
-- the api and/or work around bugs. Starting with SciTE version 3.20 there was an
-- issue with coloring. We still lacked a connection with SciTE itself (properties
-- as well as printing to the log pane) and we could not trace this (on windows).
-- However on unix we can see messages! As far as I can see, there are no
-- fundamental changes in lexer.lua or LexLPeg.cxx so it must be/have been in
-- Scintilla itself. So we went back to 3.10. Indicators of issues are: no lexing of
-- 'next' and 'goto <label>' in the Lua lexer and no brace highlighting either.
-- Interesting is that it does work ok in the cld lexer (so the Lua code is okay).
-- All seems to be ok again in later versions, so, when you update best check first
-- and just switch back to an older version as normally a SciTE update is not
-- critital. When char-def.lua lexes real fast this is a signal that the lexer quits
-- somewhere halfway. Maybe there are some hard coded limitations on the amount of
-- styles and/or length of names.
--
-- Anyway, after checking 3.24 and adapting to the new lexer tables things are okay
-- again. So, this version assumes 3.24 or higher. In 3.24 we have a different token
-- result, i.e. no longer a { tag, pattern } but just two return values. I didn't
-- check other changes but will do that when I run into issues. I had already
-- optimized these small tables by hashing which was much more efficient (and maybe
-- even more efficient than the current approach) but this is no longer needed. For
-- the moment we keep some of that code around as I don't know what happens in
-- future versions. I'm anyway still happy with this kind of lexing.
--
-- In 3.31 another major change took place: some helper constants (maybe they're no
-- longer constants) and functions were moved into the lexer modules namespace but
-- the functions are assigned to the Lua module afterward so we cannot alias them
-- beforehand. We're probably getting close to a stable interface now. At that time
-- for the first time I considered making a whole copy and patch the other functions
-- too as we need an extra nesting model. However, I don't want to maintain too
-- much. An unfortunate change in 3.03 is that no longer a script can be specified.
-- This means that instead of loading the extensions via the properties file, we now
-- need to load them in our own lexers, unless of course we replace lexer.lua
-- completely (which adds another installation issue).
--
-- Another change has been that _LEXERHOME is no longer available. It looks like
-- more and more functionality gets dropped so maybe at some point we need to ship
-- our own dll/so files. For instance, I'd like to have access to the current
-- filename and other SciTE properties. We could then cache some info with each
-- file, if only we had knowledge of what file we're dealing with. This all makes a
-- nice installation more complex and (worse) makes it hard to share files between
-- different editors usign s similar directory structure.
--
-- For huge files folding can be pretty slow and I do have some large ones that I
-- keep open all the time. Loading is normally no ussue, unless one has remembered
-- the status and the cursor is at the last line of a 200K line file. Optimizing the
-- fold function brought down loading of char-def.lua from 14 sec => 8 sec.
-- Replacing the word_match function and optimizing the lex function gained another
-- 2+ seconds. A 6 second load is quite ok for me. The changed lexer table structure
-- (no subtables) brings loading down to a few seconds.
--
-- When the lexer path is copied to the TextAdept lexer path, and the theme
-- definition to theme path (as lexer.lua), the lexer works there as well. Although
-- ... when I decided to check the state of TextAdept I had to adapt some loader
-- code. The solution is not pretty but works and also permits overloading. When I
-- have time and motive I will make a proper setup file to tune the look and feel a
-- bit more than we do now. The TextAdept editor nwo has tabs and a console so it
-- has become more useable for me (it's still somewhat slower than SciTE).
-- Interesting is that the jit version of TextAdept crashes on lexing large files
-- (and does not feel faster either; maybe a side effect of known limitations as we
-- know that Luajit is more limited than stock Lua).
--
-- Function load(lexer_name) starts with _lexers.WHITESPACE = lexer_name ..
-- '_whitespace' which means that we need to have it frozen at the moment we load
-- another lexer. Because spacing is used to revert to a parent lexer we need to
-- make sure that we load children as late as possible in order not to get the wrong
-- whitespace trigger. This took me quite a while to figure out (not being that
-- familiar with the internals). The lex and fold functions have been optimized. It
-- is a pitty that there is no proper print available. Another thing needed is a
-- default style in our own theme style definition, as otherwise we get wrong nested
-- lexers, especially if they are larger than a view. This is the hardest part of
-- getting things right.
--
-- It's a pitty that there is no scintillua library for the OSX version of SciTE.
-- Even better would be to have the scintillua library as integral part of SciTE as
-- that way I could use OSX alongside windows and linux (depending on needs). Also
-- nice would be to have a proper interface to SciTE then because currently the
-- lexer is rather isolated and the Lua version does not provide all standard
-- libraries. It would also be good to have lpeg support in the regular SciTE Lua
-- extension (currently you need to pick it up from someplace else). I keep hoping.
--
-- With 3.41 the interface changed again so it became time to look into the C++ code
-- and consider compiling and patching myself, something that I like to avoid.
-- Loading is more complicated now as the lexer gets loaded automatically so we have
-- little control over extending the code now. After a few days trying all kind of
-- solutions I decided to follow a different approach: drop in a complete
-- replacement. This of course means that I need to keep track of even more changes
-- (which for sure will happen) but at least I get rid of interferences. Till 3.60
-- the api (lexing and configuration) was simply too unstable across versions which
-- is a pitty because we expect authors to install SciTE without hassle. Maybe in a
-- few years things will have stabelized. Maybe it's also not really expected that
-- one writes lexers at all. A side effect is that I now no longer will use shipped
-- lexers for languages that I made no lexer for, but just the built-in ones in
-- addition to the ConTeXt lpeg lexers. Not that it matters much as the ConTeXt
-- lexers cover what I need (and I can always write more). For editing TeX files one
-- only needs a limited set of lexers (TeX, MetaPost, Lua, BibTeX, C/W, PDF, SQL,
-- etc). I can add more when I want.
--
-- In fact, the transition to 3.41 was triggered by an unfateful update of Ubuntu
-- which left me with an incompatible SciTE and lexer library and updating was not
-- possible due to the lack of 64 bit libraries. We'll see what the future brings.
-- For now I can use SciTE under wine on linux. The fact that scintillua ships
-- independently is a showstopper.
--
-- Promissing is that the library now can use another Lua instance so maybe some day
-- it will get properly in SciTE and we can use more clever scripting.
--
-- In some lexers we use embedded ones even if we could do it directly, The reason
-- is that when the end token is edited (e.g. -->), backtracking to the space before
-- the begin token (e.g. <!--) results in applying the surrounding whitespace which
-- in turn means that when the end token is edited right, backtracking doesn't go
-- back. One solution (in the dll) would be to backtrack several space categories.
-- After all, lexing is quite fast (applying the result is much slower).
--
-- For some reason the first blob of text tends to go wrong (pdf and web). It would
-- be nice to have 'whole doc' initial lexing. Quite fishy as it makes it impossible
-- to lex the first part well (for already opened documents) because only a partial
-- text is passed.
--
-- So, maybe I should just write this from scratch (assuming more generic usage)
-- because after all, the dll expects just tables, based on a string. I can then
-- also do some more aggressive resource sharing (needed when used generic).
--
-- I think that nested lexers are still bugged (esp over longer ranges). It never
-- was robust or maybe it's simply not meant for too complex cases (well, it
-- probably *is* tricky material). The 3.24 version was probably the best so far.
-- The fact that styles bleed between lexers even if their states are isolated is an
-- issue. Another issus is that zero characters in the text passed to the lexer can
-- mess things up (pdf files have them in streams).
--
-- For more complex 'languages', like web or xml, we need to make sure that we use
-- e.g. 'default' for spacing that makes up some construct. Ok, we then still have a
-- backtracking issue but less.
--
-- Good news for some ConTeXt users: there is now a scintillua plugin for notepad++
-- and we ship an ini file for that editor with some installation instructions
-- embedded. Also, TextAdept has a console so that we can run realtime. The spawner
-- is still not perfect (sometimes hangs) but it was enough reason to spend time on
-- making our lexer work with TextAdept and create a setup.
--
-- Some bad news. The interface changed (again) in textadept 10, some for the better
-- (but a bit different from what happens here) and some for the worse, especially
-- moving some code to the init file so we now need some bad hacks. I decided to
-- stay with the old method of defining lexers and because the lexer cannot be run
-- in parallel any more (some change in the binary?) I will probably also cleanup
-- code below as we no longer need to be compatible. Unfortunately textadept is too
-- much a moving target to simply kick in some (tex related) production flow (apart
-- from the fact that it doesn't yet have the scite like realtime console). I'll
-- keep an eye on it. Because we don't need many added features I might as well decide
-- to make a lean and mean instance (after all the license permits forking).

-- TRACING
--
-- The advantage is that we now can check more easily with regular Lua(TeX). We can
-- also use wine and print to the console (somehow stdout is intercepted there.) So,
-- I've added a bit of tracing. Interesting is to notice that each document gets its
-- own instance which has advantages but also means that when we are spellchecking
-- we reload the word lists each time. (In the past I assumed a shared instance and
-- took some precautions. But I can fix this.)
--
-- TODO
--
-- It would be nice if we could load some ConTeXt Lua modules (the basic set) and
-- then use resolvers and such. But it might not work well with scite.
--
-- The current lexer basics are still a mix between old and new. Maybe I should redo
-- some more. This is probably easier in TextAdept than in SciTE.
--
-- We have to make sure we don't overload ConTeXt definitions when this code is used
-- in ConTeXt. I still have to add some of the goodies that we have there in lexers
-- into these.
--
-- Maybe I should use a special stripped on the one hand and extended version of the
-- dll (stable api) and at least add a bit more interfacing to scintilla.
--
-- I need to investigate if we can use the already built in Lua instance so that we
-- can combine the power of lexing with extensions.
--
-- I need to play with hotspot and other properties like indicators (whatever they
-- are).
--
-- I want to get rid of these lexers.STYLE_XX and lexers.XX things. This is possible
-- when we give up compatibility. Generalize the helpers that I wrote for SciTE so
-- that they also can be used TextAdept.
--
-- I can make an export to ConTeXt, but first I'll redo the code that makes the
-- grammar, as we only seem to need
--
--   lexer._TOKENSTYLES : table
--   lexer._CHILDREN    : flag
--   lexer._EXTRASTYLES : table
--   lexer._GRAMMAR     : flag
--
--   lexers.load        : function
--   lexers.lex         : function
--
-- So, if we drop compatibility with other lex definitions, we can make things
-- simpler. However, in the meantime one can just do this:
--
--    context --extra=listing --scite [--compact --verycompact] somefile.tex
--
-- and get a printable document. So, this todo is a bit obsolete.
--
-- Properties is an ugly mess ... due to chages in the interface we're now left
-- with some hybrid that sort of works ok

-- textadept: buffer:colourise(0,-1)

local lpeg  = require("lpeg")

local global = _G
local find, gmatch, match, lower, upper, gsub, sub, format, byte = string.find, string.gmatch, string.match, string.lower, string.upper, string.gsub, string.sub, string.format, string.byte
local concat, sort = table.concat, table.sort
local type, next, setmetatable, rawset, tonumber, tostring = type, next, setmetatable, rawset, tonumber, tostring
local R, P, S, V, C, Cp, Cs, Ct, Cmt, Cc, Cf, Cg, Carg = lpeg.R, lpeg.P, lpeg.S, lpeg.V, lpeg.C, lpeg.Cp, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Carg
local lpegmatch = lpeg.match

local usage   = (textadept and "textadept") or (resolvers and "context") or "scite"
local nesting = 0
local output  = nil

----- print   = textadept and ui and ui.print or print -- crashes when ui is not yet defined

local function print(...)
    if not output then
        output = io.open("lexer.log","w")
    end
    output:write(...,"\n")
    output:flush()
end

local function report(fmt,str,...)
    if log then
        if str then
            fmt = format(fmt,str,...)
        end
        print(format("scite lpeg lexer > %s > %s",nesting == 0 and "-" or nesting,fmt))
    end
end

local function inform(...)
    if log and trace then
        report(...)
    end
end

inform("loading context lexer module (global table: %s)",tostring(global))

do

    local floor    = math and math.floor
    local format   = format
    local tonumber = tonumber

    if not floor then

        if tonumber(string.match(_VERSION,"%d%.%d")) < 5.3 then
            floor = function(n)
                return tonumber(format("%d",n))
            end
        else
            -- 5.3 has a mixed number system and format %d doesn't work with
            -- floats any longer ... no fun
            floor = function(n)
                return (n - n % 1)
            end
        end

        math = math or { }

        math.floor = floor

    end

end

local floor = math.floor

if not package.searchpath then

    -- Unfortunately the io library is only available when we end up
    -- in this branch of code.

    inform("using adapted function 'package.searchpath' (if used at all)")

    function package.searchpath(name,path)
        local tried = { }
        for part in gmatch(path,"[^;]+") do
            local filename = gsub(part,"%?",name)
            local f = io.open(filename,"r")
            if f then
                inform("file found on path: %s",filename)
                f:close()
                return filename
            end
            tried[#tried + 1] = format("no file '%s'",filename)
        end
        -- added: local path .. for testing
        local f = io.open(filename,"r")
        if f then
            inform("file found on current path: %s",filename)
            f:close()
            return filename
        end
        --
        tried[#tried + 1] = format("no file '%s'",filename)
        return nil, concat(tried,"\n")
    end

end

local lexers              = { }
local context             = { }
local helpers             = { }
lexers.context            = context
lexers.helpers            = helpers

local patterns            = { }
context.patterns          = patterns -- todo: lexers.patterns

context.report            = report
context.inform            = inform

lexers.LEXERPATH          = package.path -- can be multiple paths separated by ;

if resolvers then
    -- todo: set LEXERPATH
    -- todo: set report
end

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

local usedlexers          = { }
local parent_lexer        = nil

-- The problem with styles is that there is some nasty interaction with scintilla
-- and each version of lexer dll/so has a different issue. So, from now on we will
-- just add them here. There is also a limit on some 30 styles. Maybe I should
-- hash them in order to reuse.

-- todo: work with proper hashes and analyze what styles are really used by a
-- lexer

local default = {
    "nothing", "whitespace", "comment", "string", "number", "keyword",
    "identifier", "operator", "error", "preprocessor", "constant", "variable",
    "function", "type", "label",  "embedded",
    "quote", "special", "extra", "reserved", "okay", "warning",
    "command", "internal", "preamble", "grouping", "primitive", "plain",
    "user",
    -- not used (yet) .. we cross the 32 boundary so had to patch the initializer, see (1)
    "char", "class", "data", "definition", "invisible", "regex",
    "standout", "tag",
    "text",
}

local predefined = {
    "default", "linenumber", "bracelight", "bracebad", "controlchar",
    "indentguide", "calltip",
    -- seems new
    "folddisplaytext"
}

-- Bah ... ugly ... nicer would be a proper hash .. we now have properties
-- as well as STYLE_* and some connection between them ... why .. ok, we
-- could delay things but who cares. Anyway, at this moment the properties
-- are still unknown.

local function preparestyles(list)
    local reverse = { }
    for i=1,#list do
        local k = list[i]
        local K = upper(k)
        local s = "style." .. k
        lexers[K] = k -- is this used
        lexers["STYLE_"..K] = "$(" .. k .. ")"
        reverse[k] = true
    end
    return reverse
end

local defaultstyles    = preparestyles(default)
local predefinedstyles = preparestyles(predefined)

-- These helpers are set afterwards so we delay their initialization ... there
-- is no need to alias each time again and this way we can more easily adapt
-- to updates.

-- These keep changing (values, functions, tables ...) so we nee to check these
-- with each update. Some of them are set in the loader (the require 'lexer' is
-- in fact not a real one as the lexer code is loaded in the dll). It's also not
-- getting more efficient.

-- FOLD_BASE         = lexers.FOLD_BASE         or SC_FOLDLEVELBASE
-- FOLD_HEADER       = lexers.FOLD_HEADER       or SC_FOLDLEVELHEADERFLAG
-- FOLD_BLANK        = lexers.FOLD_BLANK        or SC_FOLDLEVELWHITEFLAG
-- get_style_at      = lexers.get_style_at      or GetStyleAt
-- get_indent_amount = lexers.get_indent_amount or GetIndentAmount
-- get_property      = lexers.get_property      or GetProperty
-- get_fold_level    = lexers.get_fold_level    or GetFoldLevel

-- It needs checking: do we have access to all properties now? I'll clean
-- this up anyway as I want a simple clean and stable model.

-- This is somewhat messy. The lexer dll provides some virtual fields:
--
-- + property
-- + property_int
-- + style_at
-- + fold_level
-- + indent_amount
--
-- but for some reasons not:
--
-- + property_expanded
--
-- As a consequence we need to define it here because otherwise the
-- lexer will crash. The fuzzy thing is that we don't have to define
-- the property and property_int tables but we do have to define the
-- expanded beforehand. The folding properties are no longer interfaced
-- so the interface to scite is now rather weak (only a few hard coded
-- properties).

local FOLD_BASE     = 0
local FOLD_HEADER   = 0
local FOLD_BLANK    = 0

local style_at      = { }
local indent_amount = { }
local fold_level    = { }

local function check_main_properties()
    if not lexers.property then
        lexers.property = { }
    end
    if not lexers.property_int then
        lexers.property_int = setmetatable({ }, {
            __index    = function(t,k)
                -- why the tostring .. it relies on lua casting to a number when
                -- doing a comparison
                return tonumber(lexers.property[k]) or 0 -- tostring removed
            end,
         -- __newindex = function(t,k,v)
         --     report("properties are read-only, '%s' is not changed",k)
         -- end,
        })
    end
end

lexers.property_expanded = setmetatable({ }, {
    __index   = function(t,k)
        -- better be safe for future changes .. what if at some point this is
        -- made consistent in the dll ... we need to keep an eye on that
        local property = lexers.property
        if not property then
            check_main_properties()
        end
        --
--         return gsub(property[k],"[$%%]%b()", function(k)
--             return t[sub(k,3,-2)]
--         end)
        local v = property[k]
        if v then
            v = gsub(v,"[$%%]%b()", function(k)
                return t[sub(k,3,-2)]
            end)
        end
        return v
    end,
    __newindex = function(t,k,v)
        report("properties are read-only, '%s' is not changed",k)
    end,
})

-- A downward compatible feature but obsolete:

-- local function get_property(tag,default)
--     return lexers.property_int[tag] or lexers.property[tag] or default
-- end

-- We still want our own properties (as it keeps changing so better play
-- safe from now on). At some point I can freeze them.

local function check_properties(lexer)
    if lexer.properties then
        return lexer
    end
    check_main_properties()
    -- we use a proxy
    local mainproperties = lexers.property
    local properties = { }
    local expanded = setmetatable({ }, {
        __index = function(t,k)
            return gsub(properties[k] or mainproperties[k],"[$%%]%b()", function(k)
                return t[sub(k,3,-2)]
            end)
        end,
    })
    lexer.properties = setmetatable(properties, {
        __index = mainproperties,
        __call = function(t,k,default) -- expands
            local v = expanded[k]
            local t = type(default)
            if t == "number" then
                return tonumber(v) or default
            elseif t == "boolean" then
                return v == nil and default or v
            else
                return v or default
            end
        end,
    })
    return lexer
end

-- do
--     lexers.property = { foo = 123, red = "R" }
--     local a = check_properties({})  print("a.foo",a.properties.foo)
--     a.properties.foo = "bar"        print("a.foo",a.properties.foo)
--     a.properties.foo = "bar:$(red)" print("a.foo",a.properties.foo) print("a.foo",a.properties("foo"))
-- end

local function set(value,default)
    if value == 0 or value == false or value == "0" then
        return false
    elseif value == 1 or value == true or value == "1" then
        return true
    else
        return default
    end
end

local function check_context_properties()
    local property = lexers.property -- let's hope that this stays
    log      = set(property["lexer.context.log"],     log)
    trace    = set(property["lexer.context.trace"],   trace)
    detail   = set(property["lexer.context.detail"],  detail)
    show     = set(property["lexer.context.show"],    show)
    collapse = set(property["lexer.context.collapse"],collapse)
    inspect  = set(property["lexer.context.inspect"], inspect)
end

function context.registerproperties(p) -- global
    check_main_properties()
    local property = lexers.property -- let's hope that this stays
    for k, v in next, p do
        property[k] = v
    end
    check_context_properties()
end

context.properties = setmetatable({ }, {
    __index    = lexers.property,
    __newindex = function(t,k,v)
        check_main_properties()
        lexers.property[k] = v
        check_context_properties()
    end,
})

-- We want locals to we set them delayed. Once.

local function initialize()
    FOLD_BASE     = lexers.FOLD_BASE
    FOLD_HEADER   = lexers.FOLD_HEADER
    FOLD_BLANK    = lexers.FOLD_BLANK
    --
    style_at      = lexers.style_at      -- table
    indent_amount = lexers.indent_amount -- table
    fold_level    = lexers.fold_level    -- table
    --
    check_main_properties()
    --
    initialize = nil
end

-- Style handler.
--
-- The property table will be set later (after loading) by the library. The
-- styleset is not needed any more as we predefine all styles as defaults
-- anyway (too bug sensitive otherwise).

local function tocolors(colors)
    local colorset     = { }
    local property_int = lexers.property_int or { }
    for k, v in next, colors do
        if type(v) == "table" then
            local r, g, b = v[1], v[2], v[3]
            if r and g and b then
                v = tonumber(format("%02X%02X%02X",b,g,r),16) or 0 -- hm
            elseif r then
                v = tonumber(format("%02X%02X%02X",r,r,r),16) or 0
            else
                v = 0
            end
        end
        colorset[k] = v
        property_int["color."..k] = v
    end
    return colorset
end

local function toproperty(specification)
    local serialized = { }
    for key, value in next, specification do
        if value == true then
            serialized[#serialized+1] = key
        elseif type(value) == "table" then
            local r, g, b = value[1], value[2], value[3]
            if r and g and b then
                value = format("#%02X%02X%02X",r,g,b) or "#000000"
            elseif r then
                value = format("#%02X%02X%02X",r,r,r) or "#000000"
            else
                value = "#000000"
            end
            serialized[#serialized+1] = key .. ":" .. value
        else
            serialized[#serialized+1] = key .. ":" .. tostring(value)
        end
    end
    return concat(serialized,",")
end

local function tostyles(styles)
    local styleset = { }
    local property = lexers.property or { }
    for k, v in next, styles do
        v = toproperty(v)
        styleset[k] = v
        property["style."..k] = v
    end
    return styleset
end

context.toproperty = toproperty
context.tostyles   = tostyles
context.tocolors   = tocolors

-- If we had one instance/state of Lua as well as all regular libraries
-- preloaded we could use the context base libraries. So, let's go poor-
-- mans solution now.

function context.registerstyles(styles)
    local styleset   = tostyles(styles)
    context.styles   = styles
    context.styleset = styleset
    if detail then
        local t, n = sortedkeys(styleset)
        local template = "  %-" .. n .. "s : %s"
        report("initializing styleset:")
        for i=1,#t do
            local k = t[i]
            report(template,k,styleset[k])
        end
    elseif trace then
        report("initializing styleset")
    end
end

function context.registercolors(colors) -- needed for textadept
    local colorset   = tocolors(colors)
    context.colors   = colors
    context.colorset = colorset
    if detail then
        local t, n = sortedkeys(colorset)
        local template = "  %-" .. n .. "s : %i"
        report("initializing colorset:")
        for i=1,#t do
            local k = t[i]
            report(template,k,colorset[k])
        end
    elseif trace then
        report("initializing colorset")
    end
end

-- Some spell checking related stuff. Unfortunately we cannot use a path set
-- by property. This will get a hook for resolvers.

local locations = {
   "context/lexers",      -- context lexers
   "context/lexers/data", -- context lexers
   "../lexers",           -- original lexers
   "../lexers/data",      -- original lexers
   ".",                   -- whatever
   "./data",              -- whatever
}

-- local function collect(name)
--     local root = gsub(lexers.LEXERPATH or ".","/.-lua$","") .. "/" -- this is a horrible hack
--  -- report("module '%s' locating '%s'",tostring(lexers),name)
--     for i=1,#locations do
--         local fullname =  root .. locations[i] .. "/" .. name .. ".lua" -- so we can also check for .luc
--         if trace then
--             report("attempt to locate '%s'",fullname)
--         end
--         local okay, result = pcall(function () return dofile(fullname) end)
--         if okay then
--             return result, fullname
--         end
--     end
-- end

local collect

if usage == "context" then

    collect = function(name)
        return require(name), name
    end

else

    collect = function(name)
        local rootlist = lexers.LEXERPATH or "."
        for root in gmatch(rootlist,"[^;]+") do
            local root = gsub(root,"/[^/]-lua$","")
            for i=1,#locations do
                local fullname =  root .. "/" .. locations[i] .. "/" .. name .. ".lua" -- so we can also check for .luc
                if trace then
                    report("attempt to locate '%s'",fullname)
                end
                local okay, result = pcall(function () return dofile(fullname) end)
                if okay then
                    return result, fullname
                end
            end
        end
    --     return require(name), name
    end

end

function context.loadluafile(name)
    local data, fullname = collect(name)
    if data then
        if trace then
            report("lua file '%s' has been loaded",fullname)
        end
        return data, fullname
    end
    if not textadept then
        report("unable to load lua file '%s'",name)
    end
end

-- in fact we could share more as we probably process the data but then we need
-- to have a more advanced helper

local cache = { }

function context.loaddefinitions(name)
    local data = cache[name]
    if data then
        if trace then
            report("reusing definitions '%s'",name)
        end
        return data
    elseif trace and data == false then
        report("definitions '%s' were not found",name)
    end
    local data, fullname = collect(name)
    if not data then
        if not textadept then
            report("unable to load definition file '%s'",name)
        end
        data = false
    elseif trace then
        report("definition file '%s' has been loaded",fullname)
        if detail then
            local t, n = sortedkeys(data)
            local template = "  %-" .. n .. "s : %s"
            for i=1,#t do
                local k = t[i]
                local v = data[k]
                if type(v) ~= "table" then
                    report(template,k,tostring(v))
                elseif #v > 0 then
                    report(template,k,#v)
                else
                    -- no need to show hash
                end
            end
        end
    end
    cache[name] = data
    return type(data) == "table" and data
end

-- A bit of regression in textadept > 10 so updated ... done a bit different.
-- We don't use this in the context lexers anyway.

function context.word_match(words,word_chars,case_insensitive)
    -- used to be proper tables ...
    if type(words) == "string" then
        local clean = gsub(words,"%-%-[^\n]+","")
        local split = { }
        for s in gmatch(clean,"%S+") do
            split[#split+1] = s
        end
        words = split
    end
    local list = { }
    for i=1,#words do
        list[words[i]] = true
    end
    if case_insensitive then
        for i=1,#words do
            list[lower(words[i])] = true
        end
    end
    local chars = S(word_chars or "")
    for i=1,#words do
        chars = chars + S(words[i])
    end
    local match = case_insensitive and
            function(input,index,word)
                -- We can speed mixed case if needed.
                return (list[word] or list[lower(word)]) and index or nil
            end
        or
            function(input,index,word)
                return list[word] and index or nil
            end
    return Cmt(chars^1,match)
end

-- Patterns are grouped in a separate namespace but the regular lexers expect
-- shortcuts to be present in the lexers library. Maybe I'll incorporate some
-- of l-lpeg later.

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

    -- These are the expected ones for other lexers. Maybe all in own namespace
    -- and provide compatibility layer. or should I just remove them?

    lexers.any            = anything
    lexers.ascii          = ascii
    lexers.extend         = extend
    lexers.alpha          = alpha
    lexers.digit          = digit
    lexers.alnum          = alpha + digit
    lexers.lower          = lower
    lexers.upper          = upper
    lexers.xdigit         = hexdigit
    lexers.cntrl          = control
    lexers.graph          = R("!~")
    lexers.print          = R(" ~")
    lexers.punct          = R("!/", ":@", "[\'", "{~")
    lexers.space          = space
    lexers.newline        = S("\r\n\f")^1
    lexers.nonnewline     = 1 - lexers.newline
    lexers.nonnewline_esc = 1 - (lexers.newline + '\\') + backslash * anything
    lexers.dec_num        = decimal
    lexers.oct_num        = octal
    lexers.hex_num        = hexadecimal
    lexers.integer        = integer
    lexers.float          = float
    lexers.word           = (alpha + "_") * (alpha + digit + "_")^0 -- weird, why digits

end

-- end of patterns

function context.exact_match(words,word_chars,case_insensitive)
    local characters = concat(words)
    local pattern -- the concat catches _ etc
    if word_chars == true or word_chars == false or word_chars == nil then
        word_chars = ""
    end
    if type(word_chars) == "string" then
        pattern = S(characters) + patterns.idtoken
        if case_insensitive then
            pattern = pattern + S(upper(characters)) + S(lower(characters))
        end
        if word_chars ~= "" then
            pattern = pattern + S(word_chars)
        end
    elseif word_chars then
        pattern = word_chars
    end
    if case_insensitive then
        local list = { }
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
        local list = { }
        if #words == 0 then
            for k, v in next, words do
                list[k] = v
            end
        else
            for i=1,#words do
                list[words[i]] = true
            end
        end
        return Cmt(pattern^1, function(_,i,s)
            return list[s] -- and i or nil
        end)
    end
end

function context.just_match(words)
    local p = P(words[1])
    for i=2,#words do
        p = p + P(words[i])
    end
    return p
end

-- spell checking (we can only load lua files)
--
-- return {
--     min = 3,
--     max = 40,
--     n = 12345,
--     words = {
--         ["someword"]    = "someword",
--         ["anotherword"] = "Anotherword",
--     },
-- }

local lists    = { }
local disabled = false

function context.disablewordcheck()
    disabled = true
end

function context.setwordlist(tag,limit) -- returns hash (lowercase keys and original values)
    if not tag or tag == "" then
        return false, 3
    end
    local list = lists[tag]
    if not list then
        list = context.loaddefinitions("spell-" .. tag)
        if not list or type(list) ~= "table" then
            if not textadept then
                report("invalid spell checking list for '%s'",tag)
            end
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

patterns.wordtoken   = R("az","AZ","\127\255")
patterns.wordpattern = patterns.wordtoken^3 -- todo: if limit and #s < limit then

function context.checkedword(validwords,validminimum,s,i) -- ,limit
    if not validwords then -- or #s < validminimum then
        return true, "text", i -- true, "default", i
    else
        -- keys are lower
        local word = validwords[s]
        if word == s then
            return true, "okay", i -- exact match
        elseif word then
            return true, "warning", i -- case issue
        else
            local word = validwords[lower(s)]
            if word == s then
                return true, "okay", i -- exact match
            elseif word then
                return true, "warning", i -- case issue
            elseif upper(s) == s then
                return true, "warning", i -- probably a logo or acronym
            else
                return true, "error", i
            end
        end
    end
end

function context.styleofword(validwords,validminimum,s) -- ,limit
    if not validwords or #s < validminimum then
        return "text"
    else
        -- keys are lower
        local word = validwords[s]
        if word == s then
            return "okay" -- exact match
        elseif word then
            return "warning" -- case issue
        else
            local word = validwords[lower(s)]
            if word == s then
                return "okay" -- exact match
            elseif word then
                return "warning" -- case issue
            elseif upper(s) == s then
                return "warning" -- probably a logo or acronym
            else
                return "error"
            end
        end
    end
end

-- overloaded functions

local h_table, b_table, n_table = { }, { }, { } -- from the time small tables were used (optimization)

setmetatable(h_table, { __index = function(t,level) local v = { level, FOLD_HEADER } t[level] = v return v end })
setmetatable(b_table, { __index = function(t,level) local v = { level, FOLD_BLANK  } t[level] = v return v end })
setmetatable(n_table, { __index = function(t,level) local v = { level              } t[level] = v return v end })

local newline = patterns.newline
local p_yes   = Cp() * Cs((1-newline)^1) * newline^-1
local p_nop   = newline

local folders = { }

-- Snippets from the > 10 code .. but we do things different so ...

local function fold_by_parsing(text,start_pos,start_line,start_level,lexer)
    local folder = folders[lexer]
    if not folder then
        --
        local pattern, folds, text, start_pos, line_num, prev_level, current_level
        --
        local fold_symbols = lexer._foldsymbols
        local fold_pattern = lexer._foldpattern -- use lpeg instead (context extension)
        --
        -- textadept >= 10
        --
     -- local zerosumlines = lexer.property_int["fold.on.zero.sum.lines"] > 0 -- not done
     -- local compact      = lexer.property_int['fold.compact'] > 0           -- not done
     -- local lowercase    = lexer._CASEINSENSITIVEFOLDPOINTS                 -- useless (utf will distort)
        --
        if fold_pattern then
            -- if no functions are found then we could have a faster one
            fold_pattern = Cp() * C(fold_pattern) / function(s,match)
                local symbols = fold_symbols[style_at[start_pos + s]]
                if symbols then
                    local l = symbols[match]
                    if l then
                        current_level = current_level + l
                    end
                end
            end
            local action_y = function()
                folds[line_num] = prev_level
                if current_level > prev_level then
                    folds[line_num] = prev_level + FOLD_HEADER
                end
                if current_level < FOLD_BASE then
                    current_level = FOLD_BASE
                end
                prev_level = current_level
                line_num = line_num + 1
            end
            local action_n = function()
                folds[line_num] = prev_level + FOLD_BLANK
                line_num = line_num + 1
            end
            pattern = ((fold_pattern + (1-newline))^1 * newline / action_y + newline/action_n)^0

         else
            -- the traditional one but a bit optimized
            local fold_symbols_patterns = fold_symbols._patterns
            local action_y = function(pos,line)
                for j=1, #fold_symbols_patterns do
                    for s, match in gmatch(line,fold_symbols_patterns[j]) do -- "()(" .. patterns[i] .. ")"
                        local symbols = fold_symbols[style_at[start_pos + pos + s - 1]]
                        local l = symbols and symbols[match]
                        local t = type(l)
                        if t == "number" then
                            current_level = current_level + l
                        elseif t == "function" then
                            current_level = current_level + l(text, pos, line, s, match)
                        end
                    end
                end
                folds[line_num] = prev_level
                if current_level > prev_level then
                    folds[line_num] = prev_level + FOLD_HEADER
                end
                if current_level < FOLD_BASE then
                    current_level = FOLD_BASE
                end
                prev_level = current_level
                line_num = line_num + 1
            end
            local action_n = function()
                folds[line_num] = prev_level + FOLD_BLANK
                line_num = line_num + 1
            end
            pattern = (p_yes/action_y + p_nop/action_n)^0
        end
        --
        local reset_parser = lexer._reset_parser
        --
        folder = function(_text_,_start_pos_,_start_line_,_start_level_)
            if reset_parser then
                reset_parser()
            end
            folds         = { }
            text          = _text_
            start_pos     = _start_pos_
            line_num      = _start_line_
            prev_level    = _start_level_
            current_level = prev_level
            lpegmatch(pattern,text)
         -- make folds collectable
            local t = folds
            folds = nil
            return t
        end
        folders[lexer] = folder
    end
    return folder(text,start_pos,start_line,start_level,lexer)
end

local folds, current_line, prev_level

local function action_y()
    local current_level = FOLD_BASE + indent_amount[current_line]
    if current_level > prev_level then -- next level
        local i = current_line - 1
        local f
        while true do
            f = folds[i]
            if not f then
                break
            elseif f[2] == FOLD_BLANK then
                i = i - 1
            else
                f[2] = FOLD_HEADER -- low indent
                break
            end
        end
        folds[current_line] = { current_level } -- high indent
    elseif current_level < prev_level then -- prev level
        local f = folds[current_line - 1]
        if f then
            f[1] = prev_level -- high indent
        end
        folds[current_line] = { current_level } -- low indent
    else -- same level
        folds[current_line] = { prev_level }
    end
    prev_level = current_level
    current_line = current_line + 1
end

local function action_n()
    folds[current_line] = { prev_level, FOLD_BLANK }
    current_line = current_line + 1
end

local pattern = ( S("\t ")^0 * ( (1-patterns.eol)^1 / action_y + P(true) / action_n) * newline )^0

local function fold_by_indentation(text,start_pos,start_line,start_level)
    -- initialize
    folds        = { }
    current_line = start_line
    prev_level   = start_level
    -- define
    -- -- not here .. pattern binds and local functions are not frozen
    -- analyze
    lpegmatch(pattern,text)
    -- flatten
    for line, level in next, folds do
        folds[line] = level[1] + (level[2] or 0)
    end
    -- done, make folds collectable
    local t = folds
    folds = nil
    return t
end

local function fold_by_line(text,start_pos,start_line,start_level)
    local folds = { }
    -- can also be lpeg'd
    for _ in gmatch(text,".-\r?\n") do
        folds[start_line] = n_table[start_level] -- { start_level } -- stile tables ? needs checking
        start_line = start_line + 1
    end
    return folds
end

local threshold_by_lexer       =  512 * 1024 -- we don't know the filesize yet
local threshold_by_parsing     =  512 * 1024 -- we don't know the filesize yet
local threshold_by_indentation =  512 * 1024 -- we don't know the filesize yet
local threshold_by_line        =  512 * 1024 -- we don't know the filesize yet

function context.fold(lexer,text,start_pos,start_line,start_level) -- hm, we had size thresholds .. where did they go
    if text == "" then
        return { }
    end
    if initialize then
        initialize()
    end
    local fold_by_lexer   = lexer._fold
    local fold_by_symbols = lexer._foldsymbols
    local filesize        = 0 -- we don't know that
    if fold_by_lexer then
        if filesize <= threshold_by_lexer then
            return fold_by_lexer(text,start_pos,start_line,start_level,lexer)
        end
    elseif fold_by_symbols then -- and lexer.properties("fold.by.parsing",1) > 0 then
        if filesize <= threshold_by_parsing then
            return fold_by_parsing(text,start_pos,start_line,start_level,lexer)
        end
    elseif lexer._FOLDBYINDENTATION or lexer.properties("fold.by.indentation",1) > 0 then
        if filesize <= threshold_by_indentation then
            return fold_by_indentation(text,start_pos,start_line,start_level,lexer)
        end
    elseif lexer._FOLDBYLINE or lexer.properties("fold.by.line",1) > 0 then
        if filesize <= threshold_by_line then
            return fold_by_line(text,start_pos,start_line,start_level,lexer)
        end
    end
    return { }
end

-- The following code is mostly unchanged:

local function add_rule(lexer,id,rule) -- unchanged
    if not lexer._RULES then
        lexer._RULES     = { }
        lexer._RULEORDER = { }
    end
    lexer._RULES[id] = rule
    lexer._RULEORDER[#lexer._RULEORDER + 1] = id
end

local function modify_rule(lexer,id,rule) -- needed for textadept > 10
    if lexer._lexer then
        lexer = lexer._lexer
    end
    lexer._RULES[id] = rule
end

local function get_rule(lexer,id) -- needed for textadept > 10
    if lexer._lexer then
        lexer = lexer._lexer
    end
    return lexer._RULES[id]
end

-- I finally figured out that adding more styles was an issue because of several
-- reasons:
--
-- + in old versions there was a limit in the amount, so we overran the built-in
--   hard coded scintilla range
-- + then, the add_style function didn't check for already known ones, so again
--   we had an overrun (with some magic that could be avoided)
-- + then, when I messed with a new default set I realized that there is no check
--   in initializing _TOKENSTYLES (here the inspect function helps)
-- + of course it was mostly a side effect of passing all the used styles to the
--   _tokenstyles instead of only the not-default ones but such a thing should not
--   matter (read: intercepted)
--
-- This finally removed a head-ache and was revealed by lots of tracing, which I
-- should have built in way earlier.

local function add_style(lexer,token_name,style) -- changed a bit around 3.41
    -- We don't add styles that are already defined as this can overflow the
    -- amount possible (in old versions of scintilla).
    if defaultstyles[token_name] then
        if trace and detail then
            report("default style '%s' is ignored as extra style",token_name)
        end
        if textadept then
            -- go on, stored per buffer
        else
            return
        end
    elseif predefinedstyles[token_name] then
        if trace and detail then
            report("predefined style '%s' is ignored as extra style",token_name)
        end
        if textadept then
            -- go on, stored per buffer
        else
            return
        end
    else
        if trace and detail then
            report("adding extra style '%s' as '%s'",token_name,style)
        end
    end
    -- This is unchanged. We skip the dangerous zone.
    local num_styles = lexer._numstyles
    if num_styles == 32 then
        num_styles = num_styles + 8
    end
    if num_styles >= 255 then
        report("there can't be more than %s styles",255)
    end
    lexer._TOKENSTYLES[token_name] = num_styles
    lexer._EXTRASTYLES[token_name] = style
    lexer._numstyles = num_styles + 1
    -- hm, the original (now) also copies to the parent ._lexer
end

local function check_styles(lexer)
    -- Here we also use a check for the dangerous zone. That way we can have a
    -- larger default set. The original code just assumes that #default is less
    -- than the dangerous zone's start.
    local numstyles   = 0
    local tokenstyles = { }
    for i=1, #default do
        if numstyles == 32 then
            numstyles = numstyles + 8
        end
        tokenstyles[default[i]] = numstyles
        numstyles = numstyles + 1
    end
    -- Unchanged.
    for i=1, #predefined do
        tokenstyles[predefined[i]] = i + 31
    end
    lexer._TOKENSTYLES  = tokenstyles
    lexer._numstyles    = numstyles
    lexer._EXTRASTYLES  = { }
    return lexer
end

-- At some point an 'any' append showed up in the original code ...
-- but I see no need to catch that case ... beter fix the specification.
--
-- hm, why are many joined twice

local function join_tokens(lexer) -- slightly different from the original (no 'any' append)
    local patterns = lexer._RULES
    local order    = lexer._RULEORDER
 -- report("lexer: %s, tokens: %s",lexer._NAME,table.concat(order," + "))
    if patterns and order then
        local token_rule = patterns[order[1]] -- normally whitespace
        for i=2,#order do
            token_rule = token_rule + patterns[order[i]]
        end
        if lexer._TYPE ~= "context" then
           token_rule = token_rule + lexers.token(lexers.DEFAULT, patterns.any)
        end
        lexer._TOKENRULE = token_rule
        return token_rule
    else
        return P(1)
    end
end

-- hm, maybe instead of a grammer just a flat one

local function add_lexer(grammar, lexer) -- mostly the same as the original
    local token_rule = join_tokens(lexer)
    local lexer_name = lexer._NAME
    local children   = lexer._CHILDREN
    for i=1,#children do
        local child = children[i]
        if child._CHILDREN then
            add_lexer(grammar, child)
        end
        local child_name        = child._NAME
        local rules             = child._EMBEDDEDRULES[lexer_name]
        local rules_token_rule  = grammar["__" .. child_name] or rules.token_rule
        local pattern           = (-rules.end_rule * rules_token_rule)^0 * rules.end_rule^-1
        grammar[child_name]     = pattern * V(lexer_name)
        local embedded_child    = "_" .. child_name
        grammar[embedded_child] = rules.start_rule * pattern
        token_rule              = V(embedded_child) + token_rule
    end
    if trace then
        report("adding lexer '%s' with %s children",lexer_name,#children)
    end
    grammar["__" .. lexer_name] = token_rule
    grammar[lexer_name]         = token_rule^0
end

local function build_grammar(lexer,initial_rule) -- same as the original
    local children   = lexer._CHILDREN
    local lexer_name = lexer._NAME
    local preamble   = lexer._preamble
    local grammar    = lexer._grammar
 -- if grammar then
 --     -- experiment
 -- elseif children then
    if children then
        if not initial_rule then
            initial_rule = lexer_name
        end
        grammar = { initial_rule }
        add_lexer(grammar, lexer)
        lexer._INITIALRULE = initial_rule
        grammar = Ct(P(grammar))
        if trace then
            report("building grammar for '%s' with whitespace '%s'and %s children",lexer_name,lexer.whitespace or "?",#children)
        end
    else
        grammar = Ct(join_tokens(lexer)^0)
        if trace then
            report("building grammar for '%s' with whitespace '%s'",lexer_name,lexer.whitespace or "?")
        end
    end
    if preamble then
        grammar = preamble^-1 * grammar
    end
    lexer._GRAMMAR = grammar
end

-- So far. We need these local functions in the next one.

local lineparsers = { }

local maxmatched  = 100

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

local function matched(lexer,grammar,text)
 -- text = string.gsub(text,"\z","!")
    local t = lpegmatch(grammar,text)
    if trace then
        if show then
            report("output of lexer: %s (max %s entries)",lexer._NAME,maxmatched)
            local s = lexer._TOKENSTYLES
            local p = 1
            for i=1,2*maxmatched,2 do
                local n = i + 1
                local ti = t[i]
                local tn = t[n]
                if ti then
                    local txt = sub(text,p,tn-1)
                    if txt then
                        txt = gsub(txt,"[%s]"," ")
                    else
                        txt = "!no text!"
                    end
                    report("%4i : %s > %s (%s) (%s)",floor(n/2),ti,tn,s[ti] or "!unset!",txt)
                    p = tn
                else
                    break
                end
            end
        end
        report("lexer results: %s, length: %s, ranges: %s",lexer._NAME,#text,floor(#t/2))
        if collapse then
            t = collapsed(t)
            report("lexer collapsed: %s, length: %s, ranges: %s",lexer._NAME,#text,floor(#t/2))
        end
    elseif collapse then
        t = collapsed(t)
    end
    return t
end

-- Todo: make nice generic lexer (extra argument with start/stop commands) for
-- context itself.
--
-- In textadept >= 10 grammar building seem to have changed a bit. So, in retrospect
-- I could better have just dropped compatibility and stick to ctx lexers only.

function context.lex(lexer,text,init_style)
 -- local lexer = global._LEXER
    local grammar = lexer._GRAMMAR
    if initialize then
        initialize()
    end
    if not grammar then
        return { }
    elseif lexer._LEXBYLINE then -- we could keep token
        local tokens = { }
        local offset = 0
        local noftokens = 0
        local lineparser = lineparsers[lexer]
        if not lineparser then -- probably a cmt is more efficient
            lineparser = C((1-newline)^0 * newline) / function(line)
                local length = #line
                local line_tokens = length > 0 and lpegmatch(grammar,line)
                if line_tokens then
                    for i=1,#line_tokens,2 do
                        noftokens = noftokens + 1
                        tokens[noftokens] = line_tokens[i]
                        noftokens = noftokens + 1
                        tokens[noftokens] = line_tokens[i + 1] + offset
                    end
                end
                offset = offset + length
                if noftokens > 0 and tokens[noftokens] ~= offset then
                    noftokens = noftokens + 1
                    tokens[noftokens] = "default"
                    noftokens = noftokens + 1
                    tokens[noftokens] = offset + 1
                end
            end
            lineparser = lineparser^0
            lineparsers[lexer] = lineparser
        end
        lpegmatch(lineparser,text)
        return tokens
    elseif lexer._CHILDREN then
        local hash = lexer._HASH -- hm, was _hash
        if not hash then
            hash = { }
            lexer._HASH = hash
        end
        grammar = hash[init_style]
        if grammar then
            lexer._GRAMMAR = grammar
         -- lexer._GRAMMAR = lexer._GRAMMAR or grammar
        else
            for style, style_num in next, lexer._TOKENSTYLES do
                if style_num == init_style then
                    -- the name of the lexers is filtered from the whitespace
                    -- specification .. weird code, should be a reverse hash
                    local lexer_name = match(style,"^(.+)_whitespace") or lexer._NAME
                    if lexer._INITIALRULE ~= lexer_name then
                        grammar = hash[lexer_name]
                        if not grammar then
                            build_grammar(lexer,lexer_name)
                            grammar = lexer._GRAMMAR
                            hash[lexer_name] = grammar
                        end
                    end
                    break
                end
            end
            grammar = grammar or lexer._GRAMMAR
            hash[init_style] = grammar
        end
        if trace then
            report("lexing '%s' with initial style '%s' and %s children", lexer._NAME,init_style,#lexer._CHILDREN or 0)
        end
        return matched(lexer,grammar,text)
    else
        if trace then
            report("lexing '%s' with initial style '%s'",lexer._NAME,init_style)
        end
        return matched(lexer,grammar,text)
    end
end

-- hm, changed in 3.24 .. no longer small table but one table (so we could remove our
-- agressive optimization which worked quite well)

function context.token(name, patt)
    return patt * Cc(name) * Cp()
end

-- The next ones were mostly unchanged (till now), we moved it here when 3.41
-- became close to impossible to combine with cq. overload and a merge was
-- the only solution. It makes later updates more painful but the update to
-- 3.41 was already a bit of a nightmare anyway.

-- Loading lexers is rather interwoven with what the dll/so sets and
-- it changes over time. So, we need to keep an eye on changes. One
-- problem that we always faced were the limitations in length of
-- lexer names (as they get app/prepended occasionally to strings with
-- a hard coded limit). So, we always used alternative names and now need
-- to make sure this doesn't clash. As I no longer intend to use shipped
-- lexers I could strip away some of the code in the future, but keeping
-- it as reference makes sense.

-- I spend quite some time figuring out why 3.41 didn't work or crashed which
-- is hard when no stdout is available and when the io library is absent. In
-- the end of of the problems was in the _NAME setting. We set _NAME
-- to e.g. 'tex' but load from a file with a longer name, which we do
-- as we don't want to clash with existing files, we end up in
-- lexers not being found.

local whitespaces = { }

local function push_whitespace(name)
    table.insert(whitespaces,lexers.WHITESPACE or "whitespace")
    lexers.WHITESPACE = name .. "_whitespace"
end

local function pop_whitespace()
    lexers.WHITESPACE = table.remove(whitespaces) or "whitespace"
end

local function check_whitespace(lexer,name)
    if lexer then
        lexer.whitespace = (name or lexer.name or lexer._NAME) .. "_whitespace"
    end
end

function context.new(name,filename)
    local lexer = {
        _TYPE        = "context",
        --
        _NAME        = name,       -- used for token building
        _FILENAME    = filename,   -- for diagnostic purposed
        --
        name         = name,
        filename     = filename,
    }
    if trace then
        report("initializing lexer tagged '%s' from file '%s'",name,filename or name)
    end
    check_whitespace(lexer)
    check_styles(lexer)
    check_properties(lexer)
    lexer._tokenstyles = context.styleset
    return lexer
end

local function nolexer(name)
    local lexer = {
        _TYPE  = "unset",
        _NAME  = name,
     -- _rules = { },
    }
    check_styles(lexer)
    check_whitespace(lexer)
    check_properties(lexer)
    return lexer
end

local function load_lexer(name,namespace)
    if trace then
        report("loading lexer file '%s'",name)
    end
    push_whitespace(namespace or name) -- for traditional lexers .. no alt_name yet
    local lexer, fullname = context.loadluafile(name)
    pop_whitespace()
    if not lexer then
        report("invalid lexer file '%s'",name)
    elseif trace then
        report("lexer file '%s' has been loaded",fullname)
    end
    if type(lexer) ~= "table" then
        if trace then
            report("lexer file '%s' gets a dummy lexer",name)
        end
        return nolexer(name)
    end
    if lexer._TYPE ~= "context" then
        lexer._TYPE = "native"
        check_styles(lexer)
        check_whitespace(lexer,namespace or name)
        check_properties(lexer)
    end
    if not lexer._NAME then
        lexer._NAME = name -- so: filename
    end
    if name ~= namespace then
        lexer._NAME = namespace
    end
    return lexer
end

-- tracing ...

local function inspect_lexer(lexer,level)
    -- If we had the regular libs available I could use the usual
    -- helpers.
    local parent = lexer._lexer
    lexer._lexer = nil -- prevent endless recursion
    local name = lexer._NAME
    local function showstyles_1(tag,styles)
        local numbers = { }
        for k, v in next, styles do
            numbers[v] = k
        end
        -- sort by number and make number hash too
        local keys = sortedkeys(numbers)
        for i=1,#keys do
            local k = keys[i]
            local v = numbers[k]
            report("[%s %s] %s %s = %s",level,name,tag,k,v)
        end
    end
    local function showstyles_2(tag,styles)
        local keys = sortedkeys(styles)
        for i=1,#keys do
            local k = keys[i]
            local v = styles[k]
            report("[%s %s] %s %s = %s",level,name,tag,k,v)
        end
    end
    local keys = sortedkeys(lexer)
    for i=1,#keys do
        local k = keys[i]
        local v = lexer[k]
        report("[%s %s] root key : %s = %s",level,name,k,tostring(v))
    end
    showstyles_1("token style",lexer._TOKENSTYLES)
    showstyles_2("extra style",lexer._EXTRASTYLES)
    local children = lexer._CHILDREN
    if children then
        for i=1,#children do
            inspect_lexer(children[i],level+1)
        end
    end
    lexer._lexer = parent
end

function context.inspect(lexer)
    inspect_lexer(lexer,0)
end

-- An optional second argument has been introduced so that one can embed a lexer
-- more than once ... maybe something to look into (as not it's done by remembering
-- the start sequence ... quite okay but maybe suboptimal ... anyway, never change
-- a working solution).

-- namespace can be automatic: if parent then use name of parent (chain)

-- The original lexer framework had a rather messy user uinterface (e.g. moving
-- stuff from _rules to _RULES at some point but I could live with that. Now it uses
-- add_ helpers. But the subsystem is still not clean and pretty. Now, I can move to
-- the add_ but there is no gain in it so we support a mix which gives somewhat ugly
-- code. In fact, there should be proper subtables for this. I might actually do
-- this because we now always overload the normal lexer (parallel usage seems no
-- longer possible). For SciTE we can actually do a conceptual upgrade (more the
-- context way) because there is no further development there. That way we could
-- make even more advanced lexers.

local savedrequire = require

local escapes = {
    ["%"] = "%%",
    ["."] = "%.",
    ["+"] = "%+", ["-"] = "%-", ["*"] = "%*",
    ["["] = "%[", ["]"] = "%]",
    ["("] = "%(", [")"] = "%)",
 -- ["{"] = "%{", ["}"] = "%}"
 -- ["^"] = "%^", ["$"] = "%$",
}

function context.loadlexer(filename,namespace)

    if textadept then
        require = function(name)
            return savedrequire(name == "lexer" and "scite-context-lexer" or name)
        end
    end

    nesting = nesting + 1
    if not namespace then
        namespace = filename
    end
    local lexer = usedlexers[namespace] -- we load by filename but the internal name can be short
    if lexer then
        if trace then
            report("reusing lexer '%s'",namespace)
        end
        nesting = nesting - 1
        return lexer
    elseif trace then
        report("loading lexer '%s'",namespace)
    end
    --
    if initialize then
        initialize()
    end
    --
    parent_lexer = nil
    --
    lexer = load_lexer(filename,namespace) or nolexer(filename,namespace)
    usedlexers[filename] = lexer
    --
    if not lexer._rules and not lexer._lexer and not lexer_grammar then -- hmm should be lexer._grammar
        lexer._lexer = parent_lexer
    end
    --
    if lexer._lexer then
        local _l = lexer._lexer
        local _r = lexer._rules
        local _s = lexer._tokenstyles
        if not _l._tokenstyles then
            _l._tokenstyles = { }
        end
        if _r then
            local rules = _l._rules
            local name  = lexer.name
            for i=1,#_r do
                local rule = _r[i]
                rules[#rules + 1] = {
                    name .. "_" .. rule[1],
                    rule[2],
                }
            end
        end
        if _s then
            local tokenstyles = _l._tokenstyles
            for token, style in next, _s do
                tokenstyles[token] = style
            end
        end
        lexer = _l
    end
    --
    local _r = lexer._rules
    local _g = lexer._grammar
 -- if _r or _g then
    if _r then
        local _s = lexer._tokenstyles
        if _s then
            for token, style in next, _s do
                add_style(lexer, token, style)
            end
        end
        if _r then
            for i=1,#_r do
                local rule = _r[i]
                add_rule(lexer, rule[1], rule[2])
            end
        end
        build_grammar(lexer)
    else
        -- other lexers
        build_grammar(lexer)
    end
    --
    add_style(lexer, lexer.whitespace, lexers.STYLE_WHITESPACE)
    --
    local foldsymbols = lexer._foldsymbols
    if foldsymbols then
        local patterns = foldsymbols._patterns
        if patterns then
            for i = 1, #patterns do
                patterns[i] = "()(" .. gsub(patterns[i],".",escapes) .. ")"
            end
        end
    end
    --
    lexer.lex  = lexers.lex
    lexer.fold = lexers.fold
    --
    nesting = nesting - 1
    --
    if inspect then
        context.inspect(lexer)
    end
    --
    if textadept then
        require = savedrequire
    end
    --
    return lexer
end

-- I probably need to check this occasionally with the original as I've messed around a bit
-- in the past to get nesting working well as one can hit the max number of styles, get
-- clashes due to fuzzy inheritance etc. so there is some interplay with the other patched
-- code.

function context.embed_lexer(parent, child, start_rule, end_rule) -- mostly the same as the original
    local embeddedrules = child._EMBEDDEDRULES
    if not embeddedrules then
        embeddedrules = { }
        child._EMBEDDEDRULES = embeddedrules
    end
    if not child._RULES then
        local rules = child._rules
        if not rules then
            report("child lexer '%s' has no rules",child._NAME or "unknown")
            rules = { }
            child._rules = rules
        end
        for i=1,#rules do
            local rule = rules[i]
            add_rule(child, rule[1], rule[2])
        end
    end
    embeddedrules[parent._NAME] = {
        ["start_rule"] = start_rule,
        ["token_rule"] = join_tokens(child),
        ["end_rule"]   = end_rule
    }
    local children = parent._CHILDREN
    if not children then
        children = { }
        parent._CHILDREN = children
    end
    children[#children + 1] = child
    local tokenstyles = parent._tokenstyles
    if not tokenstyles then
        tokenstyles = { }
        parent._tokenstyles = tokenstyles
    end
    local childname = child._NAME
    local whitespace = childname .. "_whitespace"
    tokenstyles[whitespace] = lexers.STYLE_WHITESPACE -- all these STYLE_THINGS will go .. just a proper hash
    if trace then
        report("using whitespace '%s' as trigger for '%s' with property '%s'",whitespace,childname,lexers.STYLE_WHITESPACE)
    end
    local childstyles = child._tokenstyles
    if childstyles then
        for token, style in next, childstyles do
            tokenstyles[token] = style
        end
    end
    -- new, a bit redone, untested, no clue yet what it is for
    local parentsymbols = parent._foldsymbols
    local childsymbols  = child ._foldsymbols
    if not parentsymbols then
        parentsymbols = { }
        parent._foldsymbols = parentsymbols
    end
    if childsymbols then
        for token, symbols in next, childsymbols do
            local tokensymbols = parentsymbols[token]
            if not tokensymbols then
                tokensymbols = { }
                parentsymbols[token] = tokensymbols
            end
            for k, v in next, symbols do
                if type(k) == 'number' then
                    tokensymbols[#tokensymbols + 1] = v
                elseif not tokensymbols[k] then
                    tokensymbols[k] = v
                end
            end
        end
    end
    --
    child._lexer = parent
    parent_lexer = parent
end

-- we now move the adapted code to the lexers namespace

lexers.new         = context.new
lexers.load        = context.loadlexer
------.loadlexer   = context.loadlexer
lexers.loadluafile = context.loadluafile
lexers.embed_lexer = context.embed_lexer
lexers.fold        = context.fold
lexers.lex         = context.lex
lexers.token       = context.token
lexers.word_match  = context.word_match
lexers.exact_match = context.exact_match
lexers.just_match  = context.just_match
lexers.inspect     = context.inspect
lexers.report      = context.report
lexers.inform      = context.inform

-- helper .. alas ... in scite the lexer's lua instance is rather crippled .. not
-- even math is part of it

do

    local floor    = math and math.floor
    local char     = string.char
    local format   = format
    local tonumber = tonumber

    local function utfchar(n)
        if n < 0x80 then
            return char(n)
        elseif n < 0x800 then
            return char(
                0xC0 + floor(n/0x40),
                0x80 + (n % 0x40)
            )
        elseif n < 0x10000 then
            return char(
                0xE0 + floor(n/0x1000),
                0x80 + (floor(n/0x40) % 0x40),
                0x80 + (n % 0x40)
            )
        elseif n < 0x40000 then
            return char(
                0xF0 + floor(n/0x40000),
                0x80 + floor(n/0x1000),
                0x80 + (floor(n/0x40) % 0x40),
                0x80 + (n % 0x40)
            )
        else
         -- return char(
         --     0xF1 + floor(n/0x1000000),
         --     0x80 + floor(n/0x40000),
         --     0x80 + floor(n/0x1000),
         --     0x80 + (floor(n/0x40) % 0x40),
         --     0x80 + (n % 0x40)
         -- )
            return "?"
        end
    end

    context.utfchar = utfchar

 -- -- the next one is good enough for use here but not perfect (see context for a
 -- -- better one)
 --
 -- local function make(t)
 --     local p
 --     for k, v in next, t do
 --         if not p then
 --             if next(v) then
 --                 p = P(k) * make(v)
 --             else
 --                 p = P(k)
 --             end
 --         else
 --             if next(v) then
 --                 p = p + P(k) * make(v)
 --             else
 --                 p = p + P(k)
 --             end
 --         end
 --     end
 --     return p
 -- end
 --
 -- function lpeg.utfchartabletopattern(list)
 --     local tree = { }
 --     for i=1,#list do
 --         local t = tree
 --         for c in gmatch(list[i],".") do
 --             if not t[c] then
 --                 t[c] = { }
 --             end
 --             t = t[c]
 --         end
 --     end
 --     return make(tree)
 -- end

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
    --     inspect(tree)
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

    patterns.iwordtoken   = patterns.wordtoken - patterns.invisibles
    patterns.iwordpattern = patterns.iwordtoken^3

end

-- The following helpers are not used, partially replaced by other mechanisms and
-- when needed I'll first optimize them. I only made them somewhat more readable.

function lexers.delimited_range(chars, single_line, no_escape, balanced) -- unchanged
    local s = sub(chars,1,1)
    local e = #chars == 2 and sub(chars,2,2) or s
    local range
    local b = balanced and s or ""
    local n = single_line and "\n" or ""
    if no_escape then
        local invalid = S(e .. n .. b)
        range = patterns.any - invalid
    else
        local invalid = S(e .. n .. b) + patterns.backslash
        range = patterns.any - invalid + patterns.backslash * patterns.any
    end
    if balanced and s ~= e then
        return P {
            s * (range + V(1))^0 * e
        }
    else
        return s * range^0 * P(e)^-1
    end
end

function lexers.starts_line(patt) -- unchanged
    return P ( function(input, index)
        if index == 1 then
            return index
        end
        local char = sub(input,index - 1,index - 1)
        if char == "\n" or char == "\r" or char == "\f" then
            return index
        end
    end ) * patt
end

function lexers.last_char_includes(s) -- unchanged
    s = "[" .. gsub(s,"[-%%%[]", "%%%1") .. "]"
    return P ( function(input, index)
        if index == 1 then
            return index
        end
        local i = index
        while match(sub(input,i - 1,i - 1),"[ \t\r\n\f]") do
            i = i - 1
        end
        if match(sub(input,i - 1,i - 1),s) then
            return index
        end
    end)
end

function lexers.nested_pair(start_chars, end_chars) -- unchanged
    local s = start_chars
    local e = P(end_chars)^-1
    return P {
        s * (patterns.any - s - end_chars + V(1))^0 * e
    }
end

local function prev_line_is_comment(prefix, text, pos, line, s) -- unchanged
    local start = find(line,"%S")
    if start < s and not find(line,prefix,start,true) then
        return false
    end
    local p = pos - 1
    if sub(text,p,p) == "\n" then
        p = p - 1
        if sub(text,p,p) == "\r" then
            p = p - 1
        end
        if sub(text,p,p) ~= "\n" then
            while p > 1 and sub(text,p - 1,p - 1) ~= "\n"
                do p = p - 1
            end
            while find(sub(text,p,p),"^[\t ]$") do
                p = p + 1
            end
            return sub(text,p,p + #prefix - 1) == prefix
        end
    end
    return false
end

local function next_line_is_comment(prefix, text, pos, line, s)
    local p = find(text,"\n",pos + s)
    if p then
        p = p + 1
        while find(sub(text,p,p),"^[\t ]$") do
            p = p + 1
        end
        return sub(text,p,p + #prefix - 1) == prefix
    end
    return false
end

function lexers.fold_line_comments(prefix)
    local property_int = lexers.property_int
    return function(text, pos, line, s)
        if property_int["fold.line.comments"] == 0 then
            return 0
        end
        if s > 1 and match(line,"^%s*()") < s then
            return 0
        end
        local prev_line_comment = prev_line_is_comment(prefix, text, pos, line, s)
        local next_line_comment = next_line_is_comment(prefix, text, pos, line, s)
        if not prev_line_comment and next_line_comment then
            return 1
        end
        if prev_line_comment and not next_line_comment then
            return -1
        end
        return 0
    end
end

-- There are some fundamental changes in textadept version 10 and I don't want to
-- adapt again so we go the reverse route: map new to old. This is needed because
-- we need to load other lexers which is teh result of not being able to load the
-- lexer framework in parallel. Something happened in 10 that makes the main lexer
-- always enforced so now we need to really replace that one (and even then it loads
-- twice (i can probably sort that out). Maybe there's now some hard coded magic
-- in the binary.

if textadept then

    -- Folds are still somewhat weak because of the end condition not being
    -- bound to a start .. probably to complex and it seems to work anyhow. As
    -- we have extended thinsg we just remap.

    local function add_fold_point(lexer,token_name,start_symbol,end_symbol)
        if type(start_symbol) == "string" then
            local foldsymbols = lexer._foldsymbols
            if not foldsymbols then
                foldsymbols        = { }
                lexer._foldsymbols = foldsymbols
            end
            local patterns = foldsymbols._patterns
            if not patterns then
                patterns              = { }
                usedpatt              = { } -- > 10 uses a mixed index/hash (we don't use patterns)
                foldsymbols._patterns = patterns
                foldsymbols._usedpatt = usedpatt
            end
            local foldsymbol = foldsymbols[token_name]
            if not foldsymbol then
                foldsymbol = { }
                foldsymbols[token_name] = foldsymbol
            end
            if not usedpatt[start_symbol] then
                patterns[#patterns+1] = start_symbol
                usedpatt[start_symbol] = true
            end
            if type(end_symbol) == "string" then
                foldsymbol[start_symbol] =  1
                foldsymbol[end_symbol]  = -1
                if not usedpatt[end_symbol] then
                    patterns[#patterns+1] = end_symbol
                    usedpatt[end_symbol]  = true
                end
            else
                foldsymbol[start_symbol] = end_symbol
            end
        end
    end

    local function add_style(lexer,name,style)
        local tokenstyles = lexer._tokenstyles
        if not tokenstyles then
            tokenstyles        = { }
            lexer._tokenstyles = tokenstyles
        end
        tokenstyles[name] = style
    end

    local function add_rule(lexer,id,rule)
        local rules = lexer._rules
        if not rules then
            rules        = { }
            lexer._rules = rules
        end
        rules[#rules+1] = { id, rule }
    end

    local function modify_rule(lexer,id,rule) -- needed for textadept > 10
        if lexer._lexer then
            lexer = lexer._lexer
        end
        local RULES = lexer._RULES
        if RULES then
            RULES[id] = rule
        end
    end

    local function get_rule(lexer,id) -- needed for textadept > 10
        if lexer._lexer then
            lexer = lexer._lexer
        end
        local RULES = lexer._RULES
        if RULES then
            return RULES[id]
        end
    end

    local new = context.new
    local lmt = {
        __index = {

            add_rule       = add_rule,
            modify_rule    = modify_rule,
            get_rule       = get_rule,
            add_style      = add_style,
            add_fold_point = add_fold_point,

            join_tokens    = join_tokens,
            build_grammar  = build_grammar,

            embed          = lexers.embed,
            lex            = lexers.lex,
            fold           = lexers.fold

        }
    }

    function lexers.new(name,options)
        local lexer = new(name)
        if options then
            lexer._LEXBYLINE                 = options['lex_by_line']
            lexer._FOLDBYINDENTATION         = options['fold_by_indentation']
            lexer._CASEINSENSITIVEFOLDPOINTS = options['case_insensitive_fold_points']
            lexer._lexer                     = options['inherit']
        end
        setmetatable(lexer,lmt)
        return lexer
    end

end

-- done

return lexers
