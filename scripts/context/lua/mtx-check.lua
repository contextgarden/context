if not modules then modules = { } end modules ['mtx-check'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, R, S, V, C, CP, CC, lpegmatch = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cp, lpeg.Cc, lpeg.match
local gsub, sub, format = string.gsub, string.sub, string.format
local insert, remove = table.insert, table.remove

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-check</entry>
  <entry name="detail">Basic ConTeXt Syntax Checking</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="check"><short>check tex file for errors</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-check",
    banner   = "Basic ConTeXt Syntax Checking 0.10",
    helpinfo = helpinfo,
}

local report      = application.report

scripts           = scripts         or { }
scripts.checker   = scripts.checker or { }

local validator   = { }

validator.n       = 1
validator.errors  = { }
validator.trace   = false
validator.direct  = false

validator.printer = print
validator.tracer  = print

local message = function(position, kind, extra)
    local ve = validator.errors
    ve[#ve+1] = { kind, position, validator.n, extra }
    if validator.direct then
        position = position or "eof"
        if extra then
            validator.printer(format("%s error at position %s (line %s) (%s)",kind,position,validator.n,extra))
        else
            validator.printer(format("%s error at position %s (line %s)",kind,position,validator.n))
        end
    end
end

local progress = function(position, data, kind)
    if validator.trace then
        validator.tracer(format("%s at position %s: %s", kind, position, data or ""))
    end
end

local i_m, d_m     = P("$"), P("$$")
local l_s, r_s     = P("["), P("]")
local l_g, r_g     = P("{"), P("}")

local okay         = lpeg.P("{[}") + lpeg.P("{]}")

local esc          = P("\\")
local space        = S(" \t\f\v")
local newline      = lpeg.patterns.newline

local line         = newline / function() validator.n = validator.n + 1 end

local startluacode = P("\\startluacode")
local stopluacode  = P("\\stopluacode")

local somecode     = startluacode * (1-stopluacode)^1 * stopluacode

local stack        = { }

local function push(p,s)
-- print("start",p,s)
    insert(stack,{ p, s, validator.n })
end

local function pop(p,s)
-- print("stop",p,s)
    local top = remove(stack)
    if not top then
        message(p,"missing start")
    elseif top[2] ~= s then
        message(p,"missing stop",format("see line %s",top[3]))
    else
        -- okay
    end
end

local cstoken = R("az","AZ","\127\255")

local start   = CP() * P("\\start") * C(cstoken^0) / push
local stop    = CP() * P("\\stop")  * C(cstoken^0) / pop

local contextgrammar = P { "tokens",
    ["tokens"]      = (V("ignore") + V("start") + V("stop") + V("whatever") + V("grouped") + V("setup") + V("display") + V("inline") + V("errors") + 1)^0,
    ["start"]       = start,
    ["stop"]        = stop,
    ["whatever"]    = line + esc * 1 + C(P("%") * (1-line)^0),
    ["grouped"]     = l_g * (V("start") + V("stop") + V("whatever") + V("grouped") + V("setup") + V("display") + V("inline") + line + (1 - l_g - r_g))^0 * r_g,
    ["setup"]       = l_s * (okay + V("whatever") + V("grouped") + V("setup") + V("display") + V("inline") + (1 - l_s - r_s))^0 * r_s,
    ["display"]     = d_m * (V("whatever") + V("grouped") + (1 - d_m))^0 * d_m,
    ["inline"]      = i_m * (V("whatever") + V("grouped") + (1 - i_m))^0 * i_m,
    ["errors"]      = V("gerror") + V("serror") + V("derror") + V("ierror"),
    ["gerror"]      = CP() * (l_g + r_g) * CC("grouping error") / message,
    ["serror"]      = CP() * (l_s + r_g) * CC("setup error") / message,
    ["derror"]      = CP() * d_m * CC("display math error") / message,
    ["ierror"]      = CP() * i_m * CC("inline math error") / message,
    ["ignore"]      = somecode,
}

-- metafun variant

local function push(p,s)
    insert(stack,{ p, s, validator.n })
end

local function pop(p,s)
    local top = remove(stack)
    if not top then
        message(p,"missing <some>def")
    end
end

local function finish(p)
    local bot = stack[1]
    if bot then
        message(false,format("missing enddef for %s",bot[2]),format("see line %s",bot[3]))
    end
    stack = { }
end

local l_b, r_b  = P("["), P("]")
local l_g, r_g  = P("{"), P("}")
local l_p, r_p  = P("("), P(")")

local start     = CP() * C( P("vardef") + P("primarydef") + P("secondarydef") + P("tertiarydef") + P("def") ) / push
local stop      = CP() * C( P("enddef") )                                                                     / pop

local dstring   = P('"') * (1-P('"'))^0 * P('"')
local semicolon = P(";")

local separator = line + space + semicolon

-- todo: start/stop also in ()

local metafungrammar = P { "tokens",
    ["tokens"]      = (V("start") + V("stop") + V("string") + V("whatever") + V("braces") + V("brackets") + V("parentheses") + V("errors") + 1)^0
                    * (CP() / finish),
    ["start"]       = separator * start * #separator,
    ["stop"]        = separator * stop  * #separator,
    ["string"]      = dstring,
    ["whatever"]    = line + C(P("%") * (1-line)^0),
    ["braces"]      = l_g * (V("whatever") + V("string") + V("braces") + V("brackets") + V("parentheses") + (1 - l_g - r_g))^0 * r_g,
    ["brackets"]    = l_b * (V("whatever") + V("string") + V("braces") + V("brackets") + V("parentheses") + (1 - l_b - r_b))^0 * r_b,
    ["parentheses"] = l_p * (V("whatever") + V("string") + V("braces") + V("brackets") + V("parentheses") + (1 - l_p - r_p))^0 * r_p,
    ["errors"]      = V("gerror") + V("berror") + V("perror"),
    ["gerror"]      = CP() * (l_g + r_g) * CC("braces error") / message,
    ["berror"]      = CP() * (l_b + r_b) * CC("brackets error") / message,
    ["perror"]      = CP() * (l_p + r_p) * CC("parentheses error") / message,
}

local grammars = {
    mp   = metafungrammar,
    mpii = metafungrammar,
    mpiv = metafungrammar,
    tex  = contextgrammar,
    mkii = contextgrammar,
    mkiv = contextgrammar,
    mkvi = contextgrammar,
    mkil = contextgrammar,
    mkli = contextgrammar,
}

function validator.check(str,filetype)
    validator.n = 1
    validator.errors = { }
    local grammar = grammars[filetype] or grammars.tex
    lpegmatch(grammar,str)
end

--~ str = [[
--~ a{oeps {oe\{\}ps} }
--~ test { oeps \} \[\] oeps \setupxxx[oeps=bla]}
--~ test $$ \hbox{$ oeps \} \[\] oeps $} $$
--~ {$x\$xx$ $
--~ ]]
--~ str = string.rep(str,10)

local remapper = {
    ["\n"] = " <lf> ",
    ["\r"] = " <cr> ",
    ["\t"] = " <tab> ",
}

function scripts.checker.check(filename)
    local str = io.loaddata(filename)
    if str then
        validator.check(str,file.suffix(filename))
        local errors = validator.errors
        if #errors > 0 then
            for k=1,#errors do
                local v = errors[k]
                local kind, position, line, extra = v[1], v[2], v[3], v[4]
                if not position then
                    position = #str
                end
                local data = sub(str,position-30,position+30)
                data = gsub(data,".", remapper)
                data = gsub(data,"^ *","")
                if extra then
                    print(format("% 5i  %-10s  %s (%s)", line, kind, data, extra))
                else
                    print(format("% 5i  %-10s  %s", line, kind, data))
                end
            end
        else
            print("no error")
        end
    else
        print("no file")
    end
end

if environment.argument("check") then
    scripts.checker.check(environment.files[1])
elseif environment.argument("help") then
    application.help()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
elseif environment.files[1] then
    scripts.checker.check(environment.files[1])
else
    application.help()
end

