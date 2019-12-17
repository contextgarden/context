if not modules then modules = { } end modules ['luat-mac'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Sometimes we run into situations like:
--
-- \def\foo#1{\expandafter\def\csname#1\endcsname}
--
-- As this confuses the parser, the following should be used instead:
--
-- \def\foo#1{\expandafter\normaldef\csname#1\endcsname}

local P, V, S, R, C, Cs, Cmt, Carg = lpeg.P, lpeg.V, lpeg.S, lpeg.R, lpeg.C, lpeg.Cs, lpeg.Cmt, lpeg.Carg
local lpegmatch, patterns = lpeg.match, lpeg.patterns

local insert, remove = table.insert, table.remove
local rep, sub = string.rep, string.sub
local setmetatable = setmetatable
local filesuffix = file.suffix
local convertlmxstring = lmx and lmx.convertstring
local savedata = io.savedata

local pushtarget, poptarget = logs.pushtarget, logs.poptarget

local report_macros = logs.reporter("interface","macros")

local stack, top, n, hashes = { }, nil, 0, { }

local function set(s)
    if top then
        n = n + 1
        if n > 9 then
            report_macros("number of arguments > 9, ignoring %s",s)
        else
            local ns = #stack
            local h = hashes[ns]
            if not h then
                h = rep("#",2^(ns-1))
                hashes[ns] = h
            end
            local m = h .. n
            top[s] = m
            return m
        end
    end
end

local function get(s)
    if not top then
        report_macros("keeping #%s, no stack",s)
        return "#" .. s -- can be lua
    end
    local m = top[s]
    if m then
        return m
    else
        report_macros("keeping #%s, not on stack",s)
        return "#" .. s -- quite likely an error
    end
end

local function push()
    top = { }
    n = 0
    local s = stack[#stack]
    if s then
        setmetatable(top,{ __index = s })
    end
    insert(stack,top)
end

local function pop()
    top = remove(stack)
end

local leftbrace      = P("{")   -- will be in patterns
local rightbrace     = P("}")
local escape         = P("\\")

local space          = patterns.space
local spaces         = space^1
local newline        = patterns.newline
local nobrace        = 1 - leftbrace - rightbrace

local longleft       = leftbrace  -- P("(")
local longright      = rightbrace -- P(")")
local nolong         = 1 - longleft - longright

local utf8character  = P(1) * R("\128\191")^1 -- unchecked but fast

local name           = (R("AZ","az") + utf8character)^1
local csname         = (R("AZ","az") + S("@?!_:-*") + utf8character)^1
local longname       = (longleft/"") * (nolong^1) * (longright/"")
local variable       = P("#") * Cs(name + longname)
local escapedname    = escape * csname
local definer        = escape * (P("def") + S("egx") * P("def"))                  -- tex
local setter         = escape * P("set") * (P("u")^-1 * S("egx")^-1) * P("value") -- context specific
---                  + escape * P("install") * (1-P("handler"))^1 * P("handler")  -- context specific
local startcode      = P("\\starttexdefinition")                                  -- context specific
local stopcode       = P("\\stoptexdefinition")                                   -- context specific
local anything       = patterns.anything
local always         = patterns.alwaysmatched

local definer        = escape * (P("u")^-1 * S("egx")^-1 * P("def"))             -- tex

-- The comment nilling can become an option but it nicely compensates the Lua
-- parsing here with less parsing at the TeX end. We keep lines so the errors
-- get reported all right, but comments are never seen there anyway. We keep
-- comment that starts inline as it can be something special with a % (at some
-- point we can do that as well, esp if we never use \% or `% somewhere
-- unpredictable). We need to skip comments anyway. Hm, too tricky, this
-- stripping as we can have Lua code etc.

local commenttoken   = P("%")
local crorlf         = S("\n\r")
----- commentline    = commenttoken * ((Carg(1) * C((1-crorlf)^0))/function(strip,s) return strip and "" or s end)
local commentline    = commenttoken * ((1-crorlf)^0)
local leadingcomment = (commentline * crorlf^1)^1
local furthercomment = (crorlf^1 * commentline)^1

local pushlocal      = always   / push
local poplocal       = always   / pop
local declaration    = variable / set
local identifier     = variable / get

local argument       = P { leftbrace * ((identifier + V(1) + (1 - leftbrace - rightbrace))^0) * rightbrace }

local function matcherror(str,pos)
    report_macros("runaway definition at: %s",sub(str,pos-30,pos))
end

local csname_endcsname = P("\\csname") * (identifier + (1 - P("\\endcsname")))^1

local grammar = { "converter",
    texcode     = pushlocal
                * startcode
                * spaces
                * (csname * spaces)^1 -- new: multiple, new:csname instead of name
             -- * (declaration + furthercomment + (1 - newline - space))^0
                * ((declaration * (space^0/""))^1 + furthercomment + (1 - newline - space))^0 -- accepts #a #b #c
                * V("texbody")
                * stopcode
                * poplocal,
    texbody     = (
                      leadingcomment -- new per 2015-03-03 (ugly)
                    + V("definition")
                    + identifier
                    + V("braced")
                    + (1 - stopcode)
                  )^0,
    definition  = pushlocal
                * definer
                * spaces^0
                * escapedname
--                 * (declaration + furthercomment + commentline + (1-leftbrace))^0
                * (declaration + furthercomment + commentline + csname_endcsname + (1-leftbrace))^0
                * V("braced")
                * poplocal,
    setcode     = pushlocal
                * setter
                * argument
                * (declaration + furthercomment + commentline + (1-leftbrace))^0
                * V("braced")
                * poplocal,
    braced      = leftbrace
                * (   V("definition")
                    + identifier
                    + V("setcode")
                    + V("texcode")
                    + V("braced")
                    + furthercomment
                    + leadingcomment -- new per 2012-05-15 (message on mailing list)
                    + nobrace
                  )^0
             -- * rightbrace^-1, -- the -1 catches errors
                * (rightbrace + Cmt(always,matcherror)),

    pattern     = leadingcomment
                + V("definition")
                + V("setcode")
                + V("texcode")
                + furthercomment
                + anything,

    converter   = V("pattern")^1,
}

local parser = Cs(grammar)

local checker = P("%") * (1 - newline - P("macros"))^0
              * P("macros") * space^0 * P("=") * space^0 * C(patterns.letter^1)

-- maybe namespace

local resolvers  = resolvers

local macros     = { }
resolvers.macros = macros

local loadtexfile = resolvers.loadtexfile

function macros.preprocessed(str,strip)
    return lpegmatch(parser,str,1,strip)
end

function macros.convertfile(oldname,newname) -- beware, no testing on oldname == newname
    local data = loadtexfile(oldname)
    data = interfaces.preprocessed(data) or "" -- interfaces not yet defined
    savedata(newname,data)
end

function macros.version(data)
    return lpegmatch(checker,data)
end

-- the document variables hack is temporary

local processors = { }

function processors.mkvi(str,filename)
    local oldsize = #str
    str = lpegmatch(parser,str,1,true) or str
    pushtarget("logfile")
    report_macros("processed mkvi file %a, delta %s",filename,oldsize-#str)
    poptarget()
    return str
end

function processors.mkix(str,filename) -- we could intercept earlier so that caching works better
    if not document then               -- because now we hash the string as well as the
        document = { }
    end
    if not document.variables then
        document.variables = { }
    end
    local oldsize = #str
    str = convertlmxstring(str,document.variables,false) or str
    pushtarget("logfile")
    report_macros("processed mkix file %a, delta %s",filename,oldsize-#str)
    poptarget()
    return str
end

function processors.mkxi(str,filename)
    if not document then
        document = { }
    end
    if not document.variables then
        document.variables = { }
    end
    local oldsize = #str
    str = convertlmxstring(str,document.variables,false) or str
    str = lpegmatch(parser,str,1,true) or str
    pushtarget("logfile")
    report_macros("processed mkxi file %a, delta %s",filename,oldsize-#str)
    poptarget()
    return str
end

processors.mklx = processors.mkvi
processors.mkxl = processors.mkiv

function macros.processmk(str,filename)
    if filename then
        local suffix = filesuffix(filename)
        local processor = processors[suffix] or processors[lpegmatch(checker,str)]
        if processor then
            str = processor(str,filename)
        end
    end
    return str
end

local function validvi(filename,str)
    local suffix = filesuffix(filename)
    if suffix == "mkvi" or suffix == "mklx" then
        return true
    else
        local check = lpegmatch(checker,str)
        return check == "mkvi" or check == "mklx"
    end
end

function macros.processmkvi(str,filename)
    if filename and filename ~= "" and validvi(filename,str) then
        local oldsize = #str
        str = lpegmatch(parser,str,1,true) or str
        pushtarget("logfile")
        report_macros("processed mkvi file %a, delta %s",filename,oldsize-#str)
        poptarget()
    end
    return str
end

macros.processmklx = macros.processmkvi

-- bonus

local schemes = resolvers.schemes

if schemes then

    local function handler(protocol,name,cachename)
        local hashed = url.hashed(name)
        local path = hashed.path
        if path and path ~= "" then
            local str = loadtexfile(path)
            if validvi(path,str) then
                -- already done automatically
                savedata(cachename,str)
            else
                local result = lpegmatch(parser,str,1,true) or str
                pushtarget("logfile")
                report_macros("processed scheme %a, delta %s",filename,#str-#result)
                poptarget()
                savedata(cachename,result)
            end
        end
        return cachename
    end

    schemes.install('mkvi',handler,1)
    schemes.install('mklx',handler,1)

end

-- print(macros.preprocessed(
-- [[
--     \starttexdefinition unexpanded test #aa #bb #cc
--         test
--     \stoptexdefinition
-- ]]))

-- print(macros.preprocessed([[\checked \def \bla #bla{bla#{bla}}]]))
-- print(macros.preprocessed([[\def\bla#bla{#{bla}bla}]]))
-- print(macros.preprocessed([[\def\blä#{blá}{blà:#{blá}}]]))
-- print(macros.preprocessed([[\def\blä#bla{blà:#bla}]]))
-- print(macros.preprocessed([[\setvalue{xx}#bla{blà:#bla}]]))
-- print(macros.preprocessed([[\def\foo#bar{\setvalue{xx#bar}{#bar}}]]))
-- print(macros.preprocessed([[\def\bla#bla{bla:#{bla}}]]))
-- print(macros.preprocessed([[\def\bla_bla#bla{bla:#bla}]]))
-- print(macros.preprocessed([[\def\test#oeps{test:#oeps}]]))
-- print(macros.preprocessed([[\def\test_oeps#oeps{test:#oeps}]]))
-- print(macros.preprocessed([[\def\test#oeps{test:#{oeps}}]]))
-- print(macros.preprocessed([[\def\test#{oeps:1}{test:#{oeps:1}}]]))
-- print(macros.preprocessed([[\def\test#{oeps}{test:#oeps}]]))
-- print(macros.preprocessed([[\def\x[#a][#b][#c]{\setvalue{\y{#a}\z{#b}}{#c}}]]))
-- print(macros.preprocessed([[\def\test#{oeps}{test:#oeps \halign{##\cr #oeps\cr}]]))
-- print(macros.preprocessed([[\def\test#{oeps}{test:#oeps \halign{##\cr #oeps\cr}}]]))
-- print(macros.preprocessed([[% test
-- \def\test#oeps{#oeps} % {test}
-- % test
--
-- % test
-- two
-- %test]]))
-- print(macros.preprocessed([[
-- \def\scrn_button_make_normal#namespace#current#currentparameter#text%
--   {\ctxlua{structures.references.injectcurrentset(nil,nil)}%
-- %    \hbox attr \referenceattribute \lastreferenceattribute {\localframed[#namespace:#current]{#text}}}
--    \hbox attr \referenceattribute \lastreferenceattribute {\directlocalframed[#namespace:#current]{#text}}}
-- ]]))
--
-- print(macros.preprocessed([[
-- \def\definefoo[#name]%
--  {\setvalue{start#name}{\dostartfoo{#name}}}
-- \def\dostartfoo#name%
--   {\def\noexpand\next#content\expandafter\noexpand\csname stop#name\endcsname{#name : #content}%
--   \next}
-- \def\dostartfoo#name%
--  {\normalexpanded{\def\noexpand\next#content\expandafter\noexpand\csname stop#name\endcsname}{#name : #content}%
--   \next}
-- ]]))
--
-- print(macros.preprocessed([[
-- \def\dosomething#content{%%% {{
--     % { }{{ %%
--     \bgroup\italic#content\egroup
--   }
-- ]]))
--
-- print(macros.preprocessed([[
-- \unexpanded\def\start#tag#stoptag%
--   {\initialize{#tag}%
--    \normalexpanded
--      {\def\yes[#one]#two\csname\e!stop#stoptag\endcsname{\command_yes[#one]{#two}}%
--       \def\nop      #one\csname\e!stop#stoptag\endcsname{\command_nop      {#one}}}%
--    \doifelsenextoptional\yes\nop}
-- ]]))
--
-- print(macros.preprocessed([[
-- \normalexpanded{\long\def\expandafter\noexpand\csname\e!start\v!interactionmenu\endcsname[#tag]#content\expandafter\noexpand\csname\e!stop\v!interactionmenu\endcsname}%
--   {\def\currentinteractionmenu{#tag}%
--    \expandafter\settrue\csname\??menustate\interactionmenuparameter\c!category\endcsname
--    \setinteractionmenuparameter\c!menu{#content}}
-- ]]))
--
-- Just an experiment:
--
-- \catcode\numexpr"10FF25=\commentcatcode %% > 110000 is invalid
--
-- We could have a push/pop mechanism but binding to txtcatcodes
-- is okay too.

local txtcatcodes   = false -- also signal and yet unknown

local commentsignal = utf.char(0x10FF25)

local encodecomment = P("%%") / commentsignal --
----- encodepattern = Cs(((1-encodecomment)^0 * encodecomment)) -- strips but not nice for verbatim
local encodepattern = Cs((encodecomment + 1)^0)
local decodecomment = P(commentsignal) / "%%%%" -- why doubles here?
local decodepattern = Cs((decodecomment + 1)^0)

function macros.encodecomment(str)
    if txtcatcodes and tex.catcodetable == txtcatcodes then
        return lpegmatch(encodepattern,str) or str
    else
        return str
    end
end

function macros.decodecomment(str) -- normally not needed
    return txtcatcodes and lpegmatch(decodepattern,str) or str
end

-- resolvers.macros.commentsignal        = commentsignal
-- resolvers.macros.encodecommentpattern = encodepattern
-- resolvers.macros.decodecommentpattern = decodepattern

local sequencers   = utilities.sequencers
local appendaction = sequencers and sequencers.appendaction

if appendaction then

    local textlineactions = resolvers.openers.helpers.textlineactions
    local textfileactions = resolvers.openers.helpers.textfileactions

    appendaction(textfileactions,"system","resolvers.macros.processmk")
    appendaction(textfileactions,"system","resolvers.macros.processmkvi")

    function macros.enablecomment(thecatcodes)
        if not txtcatcodes then
            txtcatcodes = thecatcodes or catcodes.numbers.txtcatcodes
            appendaction(textlineactions,"system","resolvers.macros.encodecomment")
        end
    end

end
