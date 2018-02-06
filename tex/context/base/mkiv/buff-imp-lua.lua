if not modules then modules = { } end modules ['buff-imp-lua'] = {
    version   = 1.001,
    comment   = "companion to buff-imp-lua.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- borrowed from ctx scite lexers
-- add goto/label scanning
--
-- deprecated:
--
-- gcinfo unpack getfenv setfenv loadlib
-- table.maxn table.getn table.setn
-- math.log10 math.mod math.modf math.fmod

local format, tohash = string.format, table.tohash
local P, S, V, patterns = lpeg.P, lpeg.S, lpeg.V, lpeg.patterns
local C, Cs, Cg, Cb, Cmt, Carg = lpeg.C, lpeg.Cs, lpeg.Cg, lpeg.Cb, lpeg.Cmt, lpeg.Carg

local core = tohash {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
    "true", "until", "while"
}

local base = tohash {
    "assert", "collectgarbage", "dofile", "error", "loadfile",
    "loadstring", "load", "print", "rawget", "rawset", "require", "tonumber",
    "tostring", "type", "_G", "getmetatable", "ipairs", "next", "pairs",
    "pcall", "rawequal", "setmetatable", "xpcall", "module", "select", "goto",
}

local libraries = {
    coroutine = tohash {
        "create", "resume", "status", "wrap", "yield", "running",
    },
    package = tohash{
        "cpath", "loaded", "loadlib", "path", "config", "preload", "seeall",
    },
    io = tohash{
        "close", "flush", "input", "lines", "open", "output", "read", "tmpfile",
        "type", "write", "stdin", "stdout", "stderr", "popen",
    },
    math = tohash{
        "abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "deg", "exp",
        "floor ", "ldexp", "log", "max", "min", "pi", "pow", "rad", "random",
        "randomseed", "sin", "sqrt", "tan", "cosh", "sinh", "tanh", "huge",
    },
    string = tohash{
        "byte", "char", "dump", "find", "len", "lower", "rep", "sub", "upper",
        "format", "gfind", "gsub", "gmatch", "match", "reverse",
    },
    table = tohash{
        "concat", "foreach", "foreachi", "sort", "insert", "remove", "pack",
        "unpack",
    },
    os = tohash{
        "clock", "date", "difftime", "execute", "exit", "getenv", "remove",
        "rename", "setlocale", "time", "tmpname",
    },
    lpeg = tohash{
        "print", "match", "locale", "type", "version", "setmaxstack",
        "P", "R", "S", "C", "V", "Cs", "Ct", "Cs", "Cc", "Cp", "Carg",
        "Cg", "Cb", "Cmt", "Cf", "B",
    },
    -- bit
    -- debug
}

local context                 = context
local verbatim                = context.verbatim
local makepattern             = visualizers.makepattern

local LuaSnippet              = context.LuaSnippet
local startLuaSnippet         = context.startLuaSnippet
local stopLuaSnippet          = context.stopLuaSnippet

local LuaSnippetBoundary      = verbatim.LuaSnippetBoundary
local LuaSnippetQuote         = verbatim.LuaSnippetQuote
local LuaSnippetString        = verbatim.LuaSnippetString
local LuaSnippetSpecial       = verbatim.LuaSnippetSpecial
local LuaSnippetComment       = verbatim.LuaSnippetComment
local LuaSnippetCommentText   = verbatim.LuaSnippetCommentText
local LuaSnippetNameCore      = verbatim.LuaSnippetNameCore
local LuaSnippetNameBase      = verbatim.LuaSnippetNameBase
local LuaSnippetNameLibraries = verbatim.LuaSnippetNameLibraries
local LuaSnippetName          = verbatim.LuaSnippetName

local namespace

local function visualizename_a(s)
    if core[s] then
        namespace = nil
        LuaSnippetNameCore(s)
    elseif base[s] then
        namespace = nil
        LuaSnippetNameBase(s)
    else
        namespace = libraries[s]
        if namespace then
            LuaSnippetNameLibraries(s)
        else
            LuaSnippetName(s)
        end
    end
end

local function visualizename_b(s)
    if namespace and namespace[s] then
        namespace = nil
        LuaSnippetNameLibraries(s)
    else
        LuaSnippetName(s)
    end
end

local function visualizename_c(s)
    LuaSnippetName(s)
end

local handler = visualizers.newhandler {
    startinline  = function() LuaSnippet(false,"{") end,
    stopinline   = function() context("}") end,
    startdisplay = function() startLuaSnippet() end,
    stopdisplay  = function() stopLuaSnippet() end ,
    boundary     = function(s) LuaSnippetBoundary(s) end,
    special      = function(s) LuaSnippetSpecial(s) end,
    comment      = function(s) LuaSnippetComment(s) end,
    commenttext  = function(s) LuaSnippetCommentText(s) end,
    quote        = function(s) LuaSnippetQuote(s) end,
    string       = function(s) LuaSnippetString(s) end,
    period       = function(s) verbatim(s) end,
    name_a       = visualizename_a,
    name_b       = visualizename_b,
    name_c       = visualizename_c,
}

----- comment     = P("--")
local comment     = P("--") * (patterns.anything - patterns.newline)^0
local comment_lb  = P("--[[")
local comment_le  = P("--]]")
local comment_lt  = patterns.utf8char - comment_le - patterns.newline

local name        = (patterns.letter + patterns.underscore)
                  * (patterns.letter + patterns.underscore + patterns.digit)^0
local boundary    = S('()[]{}')
local special     = S("-+/*^%=#~|<>") + P("..")

-- The following longstring parser is taken from Roberto's documentation
-- that can be found at http://www.inf.puc-rio.br/~roberto/lpeg/lpeg.html.

local equals      = P("=")^0
local open        = P("[") * Cg(equals, "init") * P("[") * P("\n")^-1 -- maybe better: patterns.newline^-1
local close       = P("]") * C(equals) * P("]")
local closeeq     = Cmt(close * Cb("init"), function(s,i,a,b) return a == b end) -- wrong return value
local longstring  = open * Cs((P(1) - closeeq)^0) * close * Carg(1)

local function long(content,equals,settings)
    handler.boundary(format("[%s[",equals or ""))
    visualizers.write(content,settings) -- unhandled
    handler.boundary(format("]%s]",equals or ""))
end

local grammar = visualizers.newgrammar("default", { "visualizer",
    sstring =
        makepattern(handler,"quote",patterns.dquote)
      * (V("whitespace") + makepattern(handler,"string",(1-patterns.dquote-V("whitespace"))^1))^0 -- patterns.nodquote
      * makepattern(handler,"quote",patterns.dquote),
    dstring =
        makepattern(handler,"quote",patterns.squote)
      * (V("whitespace") + makepattern(handler,"string",(1-patterns.squote-V("whitespace"))^1))^0 -- patterns.nosquote
      * makepattern(handler,"quote",patterns.squote),
    longstring =
        longstring / long,
    comment =
        makepattern(handler, "comment", comment_lb)
      * (   makepattern(handler, "commenttext", comment_lt)
          + V("whitespace")
        )^0
      * makepattern(handler, "comment", comment_le)
      + makepattern(handler,"comment",comment),
    name =
        makepattern(handler,"name_a",name)
      * (   V("optionalwhitespace")
          * makepattern(handler,"default",patterns.period)
          * V("optionalwhitespace")
          * makepattern(handler,"name_b",name)
        )^-1
      * (   V("optionalwhitespace")
          * makepattern(handler,"default",patterns.period)
          * V("optionalwhitespace")
          * makepattern(handler,"name_c",name)
        )^0,

    pattern =
        V("comment")
      + V("longstring")
      + V("dstring")
      + V("sstring")
      + V("name")
      + makepattern(handler,"boundary",boundary)
      + makepattern(handler,"special",special)

      + V("space")
      + V("line")
      + V("default"),

    visualizer =
        V("pattern")^1
} )

local parser = P(grammar)

visualizers.register("lua", { parser = parser, handler = handler, grammar = grammar } )
