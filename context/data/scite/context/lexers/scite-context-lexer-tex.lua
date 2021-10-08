local info = {
    version   = 1.002,
    comment   = "scintilla lpeg lexer for context",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local string, table, lpeg = string, table, lpeg
local P, R, S, V, C, Cmt, Cp, Cc, Ct = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cmt, lpeg.Cp, lpeg.Cc, lpeg.Ct
local type, next = type, next
local find, match, lower, upper = string.find, string.match, string.lower, string.upper

local lexers        = require("scite-context-lexer")

local patterns      = lexers.patterns
local token         = lexers.token
local report        = lexers.report

local contextlexer  = lexers.new("tex","scite-context-lexer-tex")
local texwhitespace = contextlexer.whitespace

local cldlexer      = lexers.load("scite-context-lexer-cld")
-- local cldlexer      = lexers.load("scite-context-lexer-lua")
local mpslexer      = lexers.load("scite-context-lexer-mps")

local commands      = { en = { } }
local primitives    = { }
local helpers       = { }
local constants     = { }

do -- todo: only once, store in global

    -- commands helpers primitives

    local definitions = lexers.loaddefinitions("scite-context-data-interfaces")

    if definitions then
        local used = { }
        for interface, list in next, definitions do
            if interface ~= "common" then
                used[#used+1] = interface
                local c = { }
                -- these are shared
                local list = definitions.common
                if list then
                    for i=1,#list do
                        c[list[i]] = true
                    end
                end
                -- normally this one is empty
                list = definitions.en
                if list then
                    for i=1,#list do
                        c[list[i]] = true
                    end
                end
                -- these are interface specific
                if interface ~= "en" then
                    for i=1,#list do
                        c[list[i]] = true
                    end
                end
                commands[interface] = c
            end
        end
        table.sort(used)
        report("context user interfaces '%s' supported",table.concat(used," "))
    end

    local definitions = lexers.loaddefinitions("scite-context-data-context")
    local overloaded  = { }

    if definitions then
        helpers   = definitions.helpers   or { }
        constants = definitions.constants or { }
        for i=1,#helpers do
            overloaded[helpers[i]] = true
        end
        for i=1,#constants do
            overloaded[constants[i]] = true
        end
    end

    local definitions = lexers.loaddefinitions("scite-context-data-tex")

    if definitions then
        local function add(data,normal)
            for k, v in next, data do
                if v ~= "/" and v ~= "-" then
                    if not overloaded[v] then
                        primitives[#primitives+1] = v
                    end
                    if normal then
                        v = "normal" .. v
                        if not overloaded[v] then
                            primitives[#primitives+1] = v
                        end
                    end
                end
            end
        end
        add(definitions.tex,true)
        add(definitions.etex,true)
        add(definitions.pdftex,true)
        add(definitions.aleph,true)
        add(definitions.omega,true)
        add(definitions.luatex,true)
        add(definitions.xetex,true)
    end

end

local currentcommands = commands.en or { }

local cstoken = R("az","AZ","\127\255") + S("@!?_")

local knowncommand = Cmt(cstoken^1, function(_,i,s)
    return currentcommands[s] and i
end)

local utfchar      = lexers.helpers.utfchar
local wordtoken    = lexers.patterns.wordtoken
local iwordtoken   = lexers.patterns.iwordtoken
local wordpattern  = lexers.patterns.wordpattern
local iwordpattern = lexers.patterns.iwordpattern
local invisibles   = lexers.patterns.invisibles
local styleofword  = lexers.styleofword
local setwordlist  = lexers.setwordlist

local validwords   = false
local validminimum = 3

-- % language=uk (space before key is mandate)

contextlexer.preamble = Cmt(P("% ") + P(true), function(input,i)
    currentcommands = false
    validwords      = false
    validminimum    = 3
    local s, e, line = find(input,"^(.-)[\n\r]",1) -- combine with match
    if line then
        local interface = match(line," interface=([a-z][a-z]+)")
        local language  = match(line," language=([a-z][a-z]+)")
        if interface and #interface == 2 then
         -- report("enabling context user interface '%s'",interface)
            currentcommands  = commands[interface]
        end
        if language then
            validwords, validminimum = setwordlist(language)
        end
    end
    if not currentcommands then
        currentcommands = commands.en or { }
    end
    return false -- so we go back and now handle the line as comment
end)

local commentline            = P("%") * (1-S("\n\r"))^0
local endline                = S("\n\r")^1

local space                  = patterns.space -- S(" \n\r\t\f\v")
local any                    = patterns.any
local exactmatch             = patterns.exactmatch
local backslash              = P("\\")
local hspace                 = S(" \t")

local p_spacing              = space^1
local p_rest                 = any

local p_preamble             = knownpreamble
local p_comment              = commentline
----- p_command              = backslash * knowncommand
----- p_constant             = backslash * exactmatch(constants)
----- p_helper               = backslash * exactmatch(helpers)
----- p_primitive            = backslash * exactmatch(primitives)

local p_csdone               = #(1-cstoken) + P(-1)

local p_command              = backslash * lexers.helpers.utfchartabletopattern(currentcommands) * p_csdone
local p_constant             = backslash * lexers.helpers.utfchartabletopattern(constants)       * p_csdone
local p_helper               = backslash * lexers.helpers.utfchartabletopattern(helpers)         * p_csdone
local p_primitive            = backslash * lexers.helpers.utfchartabletopattern(primitives)      * p_csdone

local p_ifprimitive          = P("\\if") * cstoken^1
local p_csname               = backslash * (cstoken^1 + P(1))
local p_grouping             = S("{$}")
local p_special              = S("#()[]<>=\"")
local p_extra                = S("`~%^&_-+/\'|")
local p_text                 = iwordtoken^1 --maybe add punctuation and space

local p_reserved             = backslash * (
                                    P("??") + R("az") * P("!")
                               ) * cstoken^1

local p_number               = lexers.patterns.real
----- p_unit                 = P("pt") + P("bp") + P("sp") + P("mm") + P("cm") + P("cc") + P("dd") + P("dk")
local p_unit                 = lexers.helpers.utfchartabletopattern { "pt", "bp", "sp", "mm", "cm", "cc", "dd", "dk" }

-- no looking back           = #(1-S("[=")) * cstoken^3 * #(1-S("=]"))

local p_word                 = C(iwordpattern) * Cp() / function(s,p) return styleofword(validwords,validminimum,s,p) end -- a bit of a hack

----- p_text                 = (1 - p_grouping - p_special - p_extra - backslash - space + hspace)^1

-- keep key pressed at end-of syst-aux.mkiv:
--
-- 0 : 15 sec
-- 1 : 13 sec
-- 2 : 10 sec
--
-- the problem is that quite some style subtables get generated so collapsing ranges helps

local option = 1

if option == 1 then

    p_comment                = p_comment^1
    p_grouping               = p_grouping^1
    p_special                = p_special^1
    p_extra                  = p_extra^1

    p_command                = p_command^1
    p_constant               = p_constant^1
    p_helper                 = p_helper^1
    p_primitive              = p_primitive^1
    p_ifprimitive            = p_ifprimitive^1
    p_reserved               = p_reserved^1

elseif option == 2 then

    local included           = space^0

    p_comment                = (p_comment     * included)^1
    p_grouping               = (p_grouping    * included)^1
    p_special                = (p_special     * included)^1
    p_extra                  = (p_extra       * included)^1

    p_command                = (p_command     * included)^1
    p_constant               = (p_constant    * included)^1
    p_helper                 = (p_helper      * included)^1
    p_primitive              = (p_primitive   * included)^1
    p_ifprimitive            = (p_ifprimitive * included)^1
    p_reserved               = (p_reserved    * included)^1

end

local p_invisible = invisibles^1

local spacing                = token(texwhitespace, p_spacing    )

local rest                   = token("default",     p_rest       )
local comment                = token("comment",     p_comment    )
local command                = token("command",     p_command    )
local constant               = token("data",        p_constant   )
local helper                 = token("plain",       p_helper     )
local primitive              = token("primitive",   p_primitive  )
local ifprimitive            = token("primitive",   p_ifprimitive)
local reserved               = token("reserved",    p_reserved   )
local csname                 = token("user",        p_csname     )
local grouping               = token("grouping",    p_grouping   )
local number                 = token("number",      p_number     )
                             * token("constant",    p_unit       )
local special                = token("special",     p_special    )
local reserved               = token("reserved",    p_reserved   ) -- reserved internal preproc
local extra                  = token("extra",       p_extra      )
local invisible              = token("invisible",   p_invisible  )
local text                   = token("default",     p_text       )
local word                   = p_word

----- startluacode           = token("grouping",    P("\\startluacode"))
----- stopluacode            = token("grouping",    P("\\stopluacode"))

local luastatus = false
local luatag    = nil
local lualevel  = 0

local function startdisplaylua(_,i,s)
    luatag = s
    luastatus = "display"
    cldlexer.directives.cld_inline = false
    return true
end

local function stopdisplaylua(_,i,s)
    local ok = luatag == s
    if ok then
        cldlexer.directives.cld_inline = false
        luastatus = false
    end
    return ok
end

local function startinlinelua(_,i,s)
    if luastatus == "display" then
        return false
    elseif not luastatus then
        luastatus = "inline"
        cldlexer.directives.cld_inline = true
        lualevel = 1
        return true
    else-- if luastatus == "inline" then
        lualevel = lualevel + 1
        return true
    end
end

local function stopinlinelua_b(_,i,s) -- {
    if luastatus == "display" then
        return false
    elseif luastatus == "inline" then
        lualevel = lualevel + 1 -- ?
        return false
    else
        return true
    end
end

local function stopinlinelua_e(_,i,s) -- }
    if luastatus == "display" then
        return false
    elseif luastatus == "inline" then
        lualevel = lualevel - 1
        local ok = lualevel <= 0 -- was 0
        if ok then
            cldlexer.directives.cld_inline = false
            luastatus = false
        end
        return ok
    else
        return true
    end
end

contextlexer.resetparser = function()
    luastatus = false
    luatag    = nil
    lualevel  = 0
end

local luaenvironment         = P("lua") * (P("setups") + P("code") + P("parameterset") + P(true))
                             + P("ctxfunction") * (P("definition") + P(true))

local inlinelua              = P("\\") * (
                                    P("ctx") * (P("lua") + P("command") + P("late") * (P("lua") + P("command")) + P("function"))
                                  + P("cld") * (P("command") + P("context"))
                                  + P("lua") * (P("expr") + P("script") + P("thread"))
                                  + (P("direct") + P("late")) * P("lua")
                               )

local startlua               = P("\\start") * Cmt(luaenvironment,startdisplaylua)
                             + P("<?lua") * Cmt(P(true),startdisplaylua)
                             + inlinelua * space^0 * ( Cmt(P("{"),startinlinelua) )

local stoplua                = P("\\stop") * Cmt(luaenvironment,stopdisplaylua)
                             + P("?>") * Cmt(P(true),stopdisplaylua)
                             + Cmt(P("{"),stopinlinelua_b)
                             + Cmt(P("}"),stopinlinelua_e)

local startluacode           = token("embedded", startlua)
local stopluacode            = #stoplua * token("embedded", stoplua)

local luacall                = P("clf_") * R("az","__","AZ")^1

local metafuncall            = ( P("reusable") + P("usable") + P("unique") + P("use") + P("reuse") + P("overlay") ) * ("MPgraphic")
                             + P("uniqueMPpagegraphic")
                             + P("MPpositiongraphic")

local metafunenvironment     = metafuncall -- ( P("use") + P("reusable") + P("unique") ) * ("MPgraphic")
                             + P("MP") * ( P("code")+ P("page") + P("inclusions") + P("initializations") + P("definitions") + P("extensions") + P("graphic") + P("calculation") )

local startmetafun           = P("\\start") * metafunenvironment
local stopmetafun            = P("\\stop")  * metafunenvironment -- todo match start

----- subsystem              = token("embedded", P("\\xml") * R("az")^1 + (P("\\st") * (P("art") + P("op")) * P("xmlsetups")))
local subsystemtags          = P("xml") + P("btx") -- will be pluggable or maybe even a proper list of valid commands
local subsystemmacro         = P("\\") * (subsystemtags * R("az")^1 + (R("az")-subsystemtags)^1 * subsystemtags * R("az")^1)
local subsystem              = token("embedded", subsystemmacro)

local openargument           = token("special", P("{"))
local closeargument          = token("special", P("}"))
local argumentcontent        = token("default",(1-P("}"))^0) -- maybe space needs a treatment

local metafunarguments       = (spacing^0 * openargument * argumentcontent * closeargument)^-2

local startmetafuncode       = token("embedded", startmetafun) * metafunarguments
local stopmetafuncode        = token("embedded", stopmetafun)

local callers                = token("embedded", P("\\") * metafuncall) * metafunarguments
                             + token("embedded", P("\\") * luacall)

lexers.embed(contextlexer, mpslexer, startmetafuncode, stopmetafuncode)
lexers.embed(contextlexer, cldlexer, startluacode,     stopluacode)

contextlexer.rules = {
    { "whitespace",  spacing     },
    { "word",        word        },
    { "text",        text        }, -- non words
    { "comment",     comment     },
    { "constant",    constant    },
 -- { "subsystem",   subsystem   },
    { "callers",     callers     },
    { "subsystem",   subsystem   },
    { "ifprimitive", ifprimitive },
    { "helper",      helper      },
    { "command",     command     },
    { "primitive",   primitive   },
 -- { "subsystem",   subsystem   },
    { "reserved",    reserved    },
    { "csname",      csname      },
 -- { "whatever",    specialword }, -- not yet, crashes
    { "grouping",    grouping    },
 -- { "number",      number      },
    { "special",     special     },
    { "extra",       extra       },
    { "invisible",   invisible   },
    { "rest",        rest        },
}

-- Watch the text grabber, after all, we're talking mostly of text (beware,
-- no punctuation here as it can be special). We might go for utf here.

local web = lexers.loadluafile("scite-context-lexer-web-snippets")

if web then

    contextlexer.rules_web = {
        { "whitespace",  spacing     },
        { "text",        text        }, -- non words
        { "comment",     comment     },
        { "constant",    constant    },
        { "callers",     callers     },
        { "ifprimitive", ifprimitive },
        { "helper",      helper      },
        { "command",     command     },
        { "primitive",   primitive   },
        { "reserved",    reserved    },
        { "csname",      csname      },
        { "grouping",    grouping    },
        { "special",     special     },
        { "extra",       extra       },
        { "invisible",   invisible   },
        { "web",         web.pattern },
        { "rest",        rest        },
    }

else

    contextlexer.rules_web = {
        { "whitespace",  spacing     },
        { "text",        text        }, -- non words
        { "comment",     comment     },
        { "constant",    constant    },
        { "callers",     callers     },
        { "ifprimitive", ifprimitive },
        { "helper",      helper      },
        { "command",     command     },
        { "primitive",   primitive   },
        { "reserved",    reserved    },
        { "csname",      csname      },
        { "grouping",    grouping    },
        { "special",     special     },
        { "extra",       extra       },
        { "invisible",   invisible   },
        { "rest",        rest        },
    }

end

contextlexer.folding = {
    ["\\start"] = {
        ["command"]  = 1,
        ["constant"] = 1,
        ["data"]     = 1,
        ["user"]     = 1,
        ["embedded"] = 1,
     -- ["helper"]   = 1,
        ["plain"]    = 1,
    },
    ["\\stop"] = {
        ["command"]  = -1,
        ["constant"] = -1,
        ["data"]     = -1,
        ["user"]     = -1,
        ["embedded"] = -1,
     -- ["helper"]   = -1,
        ["plain"]    = -1,
    },
    ["{"] = {
        ["grouping"] = 1,
    },
    ["}"] = {
        ["grouping"] = -1,
    },
}

return contextlexer
