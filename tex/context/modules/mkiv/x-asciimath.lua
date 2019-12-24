if not modules then modules = { } end modules ['x-asciimath'] = {
    version   = 1.001,
    comment   = "companion to x-asciimath.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Some backgrounds are discussed in <t>x-asciimath.mkiv</t>. This is a third version. I first
tried a to make a proper expression parser but it's not that easy. First we have to avoid left
recursion, which is not that trivial (maybe a future version of lpeg will provide that), and
second there is not really a syntax but a mix of expressions and sequences with some fuzzy logic
applied. Most problematic are fractions and we also need to handle incomplete expressions. So,
instead we (sort of) tokenize the string and then do some passes over the result. Yes, it's real
ugly and unsatisfying code mess down here. Don't take this as an example.</p>
--ldx]]--

-- todo: spaces around all elements in cleanup?
-- todo: filter from files listed in tuc file

local trace_mapping    = false  if trackers then trackers.register("modules.asciimath.mapping", function(v) trace_mapping = v end) end
local trace_details    = false  if trackers then trackers.register("modules.asciimath.details", function(v) trace_details = v end) end
local trace_digits     = false  if trackers then trackers.register("modules.asciimath.digits",  function(v) trace_digits  = v end) end

local report_asciimath = logs.reporter("mathematics","asciimath")

local asciimath        = { }
local moduledata       = moduledata or { }
moduledata.asciimath   = asciimath

if not characters then
    require("char-def")
    require("char-ini")
    require("char-ent")
end

local next, type = next, type
local concat, insert, remove = table.concat, table.insert, table.remove
local rep, gmatch, gsub, find = string.rep, string.gmatch, string.gsub, string.find
local utfchar, utfbyte = utf.char, utf.byte

local lpegmatch, patterns = lpeg.match, lpeg.patterns
local S, P, R, C, V, Cc, Ct, Cs, Carg = lpeg.S, lpeg.P, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc, lpeg.Ct, lpeg.Cs, lpeg.Carg

local sortedhash   = table.sortedhash
local sortedkeys   = table.sortedkeys
local formatters   = string.formatters

local entities     = characters.entities or { }

local xmltext      = xml.text
local xmlpure      = xml.pure
local xmlinclusion = xml.inclusion
local xmlcollected = xml.collected

local lxmlgetid    = lxml.getid

-- todo: use private unicodes as temporary slots ... easier to compare

local s_lparent  = "\\left\\lparent"
local s_lbrace   = "\\left\\lbrace"
local s_lbracket = "\\left\\lbracket"
local s_langle   = "\\left\\langle"
local s_lfloor   = "\\left\\lfloor"
local s_lceil    = "\\left\\lceil"
local s_left     = "\\left."

local s_rparent  = "\\right\\rparent"
local s_rbrace   = "\\right\\rbrace"
local s_rbracket = "\\right\\rbracket"
local s_rangle   = "\\right\\rangle"
local s_rfloor   = "\\right\\rfloor"
local s_rceil    = "\\right\\rceil"
local s_right    = "\\right."

local s_mslash   = "\\middle/"

local s_lbar     = "\\left\\|"
local s_mbar     = "\\middle\\|"
local s_rbar     = "\\right\\|"

local s_lnothing = "\\left ."  -- space fools checker
local s_rnothing = "\\right ." -- space fools checker

local reserved = {

    ["prod"]      = { false, "\\prod" },
    ["sinh"]      = { false, "\\sinh" },
    ["cosh"]      = { false, "\\cosh" },
    ["tanh"]      = { false, "\\tanh" },
    ["sum"]       = { false, "\\sum" },
    ["int"]       = { false, "\\int" },
    ["sin"]       = { false, "\\sin" },
    ["cos"]       = { false, "\\cos" },
    ["tan"]       = { false, "\\tan" },
    ["csc"]       = { false, "\\csc" },
    ["sec"]       = { false, "\\sec" },
    ["cot"]       = { false, "\\cot" },
    ["log"]       = { false, "\\log" },
    ["det"]       = { false, "\\det" },
    ["lim"]       = { false, "\\lim" },
    ["mod"]       = { false, "\\mod" },
    ["gcd"]       = { false, "\\gcd" },
    ["min"]       = { false, "\\min" },
    ["max"]       = { false, "\\max" },
    ["ln"]        = { false, "\\ln" },

 -- ["atan"]      = { false, "\\atan" }, -- extra
 -- ["acos"]      = { false, "\\acos" }, -- extra
 -- ["asin"]      = { false, "\\asin" }, -- extra

    ["arctan"]    = { false, "\\arctan" }, -- extra
    ["arccos"]    = { false, "\\arccos" }, -- extra
    ["arcsin"]    = { false, "\\arcsin" }, -- extra

    ["arctanh"]   = { false, "\\arctanh" }, -- extra
    ["arccosh"]   = { false, "\\arccosh" }, -- extra
    ["arcsinh"]   = { false, "\\arcsinh" }, -- extra

    ["and"]       = { false, "\\text{and}" },
    ["or"]        = { false, "\\text{or}" },
    ["if"]        = { false, "\\text{if}" },

    ["sqrt"]      = { false, "\\asciimathsqrt",     "unary" },
    ["root"]      = { false, "\\asciimathroot",     "binary" },
 -- ["\\frac"]    = { false, "\\frac",              "binary" },
    ["frac"]      = { false, "\\frac",              "binary" },
    ["stackrel"]  = { false, "\\asciimathstackrel", "binary" },
    ["hat"]       = { false, "\\widehat",           "unary" },
    ["bar"]       = { false, "\\overline",          "unary" },
    ["overbar"]   = { false, "\\overline",          "unary" },
    ["overline"]  = { false, "\\overline",          "unary" },
    ["underline"] = { false, "\\underline",         "unary" },
    ["overbrace"] = { false, "\\overbrace",         "unary" },
    ["underbrace"]= { false, "\\underbrace",        "unary" },
    ["overset"]   = { false, "\\overset",           "unary" },
    ["underset"]  = { false, "\\underset",          "unary" },
    ["obrace"]    = { false, "\\overbrace",         "unary" },
    ["ubrace"]    = { false, "\\underbrace",        "unary" },
    ["ul"]        = { false, "\\underline",         "unary" },
    ["vec"]       = { false, "\\overrightarrow",    "unary" },
    ["dot"]       = { false, "\\dot",               "unary" }, -- 0x2D9
    ["ddot"]      = { false, "\\ddot",              "unary" }, -- 0xA8

    -- binary operators

    ["+"]         = { true,  "+" },
    ["-"]         = { true,  "-" },
    ["*"]         = { true,  "⋅" },
    ["**"]        = { true,  "⋆" },
    ["////"]      = { true,  "⁄⁄" }, -- crap
    ["//"]        = { true,  "⁄" }, -- \slash
    ["\\"]        = { true,  "\\" },
    ["xx"]        = { true,  "×" },
    ["times"]     = { true,  "×" },
    ["-:"]        = { true,  "÷" },
    ["@"]         = { true,  "∘" },
    ["circ"]      = { true,  "∘" },
    ["o+"]        = { true,  "⊕" },
    ["ox"]        = { true,  "⊗" },
    ["o."]        = { true,  "⊙" },
    ["^^"]        = { true,  "∧" },
    ["vv"]        = { true,  "∨" },
    ["nn"]        = { true,  "∩" },
    ["uu"]        = { true,  "∪" },

    -- big operators

    ["^^^"]       = { true,  "⋀" },
    ["vvv"]       = { true,  "⋁" },
    ["nnn"]       = { true,  "⋂" },
    ["uuu"]       = { true,  "⋃" },
    ["int"]       = { true,  "∫" },
    ["oint"]      = { true,  "∮" },

    -- brackets

    ["("]         = { true, "(" },
    [")"]         = { true, ")" },
    ["["]         = { true, "[" },
    ["]"]         = { true, "]" },
    ["{"]         = { true, "{" },
    ["}"]         = { true, "}" },

    -- binary relations

    ["="]         = { true,  "=" },
    ["eq"]        = { true,  "=" },
    ["!="]        = { true,  "≠" },
    ["ne"]        = { true,  "≠" },
    ["neq"]       = { true,  "≠" },
    ["<"]         = { true,  "<" },
    ["lt"]        = { true,  "<" },
    [">"]         = { true,  ">" },
    ["gt"]        = { true,  ">" },
    ["<="]        = { true,  "≤" },
    ["le"]        = { true,  "≤" },
    ["leq"]       = { true,  "≤" },
    [">="]        = { true,  "≥" },
    ["ge"]        = { true,  "≥" },
    ["geq"]       = { true,  "≥" },
    ["-<"]        = { true,  "≺" },
    [">-"]        = { true,  "≻" },
    ["in"]        = { true,  "∈" },
    ["!in"]       = { true,  "∉" },
    ["sub"]       = { true,  "⊂" },
    ["sup"]       = { true,  "⊃" },
    ["sube"]      = { true,  "⊆" },
    ["supe"]      = { true,  "⊇" },
    ["-="]        = { true,  "≡" },
    ["~="]        = { true,  "≅" },
    ["~~"]        = { true,  "≈" },
    ["prop"]      = { true,  "∝" },

    -- arrows

    ["rarr"]      = { true,  "→" },
    ["->"]        = { true,  "→" },
    ["larr"]      = { true,  "←" },
    ["harr"]      = { true,  "↔" },
    ["uarr"]      = { true,  "↑" },
    ["darr"]      = { true,  "↓" },
    ["rArr"]      = { true,  "⇒" },
    ["lArr"]      = { true,  "⇐" },
    ["hArr"]      = { true,  "⇔" },
    ["|->"]       = { true,  "↦" },

    -- logical

    ["not"]       = { true,  "¬" },
    ["=>"]        = { true,  "⇒" },
    ["iff"]       = { true,  "⇔" },
    ["AA"]        = { true,  "∀" },
    ["EE"]        = { true,  "∃" },
    ["_|_"]       = { true,  "⊥" },
    ["TT"]        = { true,  "⊤" },
    ["|--"]       = { true,  "⊢" },
    ["|=="]       = { true,  "⊨" },

    -- miscellaneous

    ["del"]       = { true,  "∂" },
    ["grad"]      = { true,  "∇" },
    ["+-"]        = { true,  "±" },
    ["O/"]        = { true,  "∅" },
    ["oo"]        = { true,  "∞" },
    ["aleph"]     = { true,  "ℵ" },
    ["angle"]     = { true,  "∠" },
    ["/_"]        = { true,  "∠" },
    [":."]        = { true,  "∴" },
    ["..."]       = { true,  "..." }, -- ldots
    ["ldots"]     = { true,  "..." }, -- ldots
    ["cdots"]     = { true,  "⋯" },
    ["vdots"]     = { true,  "⋮" },
    ["ddots"]     = { true,  "⋱" },
    ["diamond"]   = { true,  "⋄" },
    ["square"]    = { true,  "□" },
    ["|__"]       = { true,  "⌊" },
    ["__|"]       = { true,  "⌋" },
    ["|~"]        = { true,  "⌈" },
    ["~|"]        = { true,  "⌉" },

    -- more

    ["_="]        = { true, "≡" },

    -- bonus

    ["prime"]     = { true,  "′" }, -- bonus
    ["'"]         = { true,  "′" }, -- bonus
    ["''"]        = { true,  "″" }, -- bonus
    ["'''"]       = { true,  "‴" }, -- bonus

    -- special

    ["%"]         = { false, "\\mathpercent" },
    ["&"]         = { false, "\\mathampersand" },
    ["#"]         = { false, "\\mathhash" },
    ["$"]         = { false, "\\mathdollar" },

    -- blackboard

    ["CC"]        = { true, "ℂ" },
    ["NN"]        = { true, "ℕ" },
    ["QQ"]        = { true, "ℚ" },
    ["RR"]        = { true, "ℝ" },
    ["ZZ"]        = { true, "ℤ" },

    -- greek lowercase

    ["alpha"]      = { true, "α" },
    ["beta"]       = { true, "β" },
    ["gamma"]      = { true, "γ" },
    ["delta"]      = { true, "δ" },
    ["epsilon"]    = { true, "ε" },
    ["varepsilon"] = { true, "ɛ" },
    ["zeta"]       = { true, "ζ" },
    ["eta"]        = { true, "η" },
    ["theta"]      = { true, "θ" },
    ["vartheta"]   = { true, "ϑ" },
    ["iota"]       = { true, "ι" },
    ["kappa"]      = { true, "κ" },
    ["lambda"]     = { true, "λ" },
    ["mu"]         = { true, "μ" },
    ["nu"]         = { true, "ν" },
    ["xi"]         = { true, "ξ" },
    ["pi"]         = { true, "π" },
    ["rho"]        = { true, "ρ" },
    ["sigma"]      = { true, "σ" },
    ["tau"]        = { true, "τ" },
    ["upsilon"]    = { true, "υ" },
    ["phi"]        = { true, "ϕ" },
    ["varphi"]     = { true, "φ" },
    ["chi"]        = { true, "χ" },
    ["psi"]        = { true, "ψ" },
    ["omega"]      = { true, "ω" },

    -- greek uppercase

    ["Gamma"]  = { true, "Γ" },
    ["Delta"]  = { true, "Δ" },
    ["Theta"]  = { true, "Θ" },
    ["Lambda"] = { true, "Λ" },
    ["Xi"]     = { true, "Ξ" },
    ["Pi"]     = { true, "Π" },
    ["Sigma"]  = { true, "Σ" },
    ["Phi"]    = { true, "Φ" },
    ["Psi"]    = { true, "Ψ" },
    ["Omega"]  = { true, "Ω" },

    -- blackboard

    ["bbb a"] = { true, "𝕒" },
    ["bbb b"] = { true, "𝕓" },
    ["bbb c"] = { true, "𝕔" },
    ["bbb d"] = { true, "𝕕" },
    ["bbb e"] = { true, "𝕖" },
    ["bbb f"] = { true, "𝕗" },
    ["bbb g"] = { true, "𝕘" },
    ["bbb h"] = { true, "𝕙" },
    ["bbb i"] = { true, "𝕚" },
    ["bbb j"] = { true, "𝕛" },
    ["bbb k"] = { true, "𝕜" },
    ["bbb l"] = { true, "𝕝" },
    ["bbb m"] = { true, "𝕞" },
    ["bbb n"] = { true, "𝕟" },
    ["bbb o"] = { true, "𝕠" },
    ["bbb p"] = { true, "𝕡" },
    ["bbb q"] = { true, "𝕢" },
    ["bbb r"] = { true, "𝕣" },
    ["bbb s"] = { true, "𝕤" },
    ["bbb t"] = { true, "𝕥" },
    ["bbb u"] = { true, "𝕦" },
    ["bbb v"] = { true, "𝕧" },
    ["bbb w"] = { true, "𝕨" },
    ["bbb x"] = { true, "𝕩" },
    ["bbb y"] = { true, "𝕪" },
    ["bbb z"] = { true, "𝕫" },

    ["bbb A"] = { true, "𝔸" },
    ["bbb B"] = { true, "𝔹" },
    ["bbb C"] = { true, "ℂ" },
    ["bbb D"] = { true, "𝔻" },
    ["bbb E"] = { true, "𝔼" },
    ["bbb F"] = { true, "𝔽" },
    ["bbb G"] = { true, "𝔾" },
    ["bbb H"] = { true, "ℍ" },
    ["bbb I"] = { true, "𝕀" },
    ["bbb J"] = { true, "𝕁" },
    ["bbb K"] = { true, "𝕂" },
    ["bbb L"] = { true, "𝕃" },
    ["bbb M"] = { true, "𝕄" },
    ["bbb N"] = { true, "ℕ" },
    ["bbb O"] = { true, "𝕆" },
    ["bbb P"] = { true, "ℙ" },
    ["bbb Q"] = { true, "ℚ" },
    ["bbb R"] = { true, "ℝ" },
    ["bbb S"] = { true, "𝕊" },
    ["bbb T"] = { true, "𝕋" },
    ["bbb U"] = { true, "𝕌" },
    ["bbb V"] = { true, "𝕍" },
    ["bbb W"] = { true, "𝕎" },
    ["bbb X"] = { true, "𝕏" },
    ["bbb Y"] = { true, "𝕐" },
    ["bbb Z"] = { true, "ℤ" },

    -- fraktur

    ["fr a"] = { true, "𝔞" },
    ["fr b"] = { true, "𝔟" },
    ["fr c"] = { true, "𝔠" },
    ["fr d"] = { true, "𝔡" },
    ["fr e"] = { true, "𝔢" },
    ["fr f"] = { true, "𝔣" },
    ["fr g"] = { true, "𝔤" },
    ["fr h"] = { true, "𝔥" },
    ["fr i"] = { true, "𝔦" },
    ["fr j"] = { true, "𝔧" },
    ["fr k"] = { true, "𝔨" },
    ["fr l"] = { true, "𝔩" },
    ["fr m"] = { true, "𝔪" },
    ["fr n"] = { true, "𝔫" },
    ["fr o"] = { true, "𝔬" },
    ["fr p"] = { true, "𝔭" },
    ["fr q"] = { true, "𝔮" },
    ["fr r"] = { true, "𝔯" },
    ["fr s"] = { true, "𝔰" },
    ["fr t"] = { true, "𝔱" },
    ["fr u"] = { true, "𝔲" },
    ["fr v"] = { true, "𝔳" },
    ["fr w"] = { true, "𝔴" },
    ["fr x"] = { true, "𝔵" },
    ["fr y"] = { true, "𝔶" },
    ["fr z"] = { true, "𝔷" },

    ["fr A"] = { true, "𝔄" },
    ["fr B"] = { true, "𝔅" },
    ["fr C"] = { true, "ℭ" },
    ["fr D"] = { true, "𝔇" },
    ["fr E"] = { true, "𝔈" },
    ["fr F"] = { true, "𝔉" },
    ["fr G"] = { true, "𝔊" },
    ["fr H"] = { true, "ℌ" },
    ["fr I"] = { true, "ℑ" },
    ["fr J"] = { true, "𝔍" },
    ["fr K"] = { true, "𝔎" },
    ["fr L"] = { true, "𝔏" },
    ["fr M"] = { true, "𝔐" },
    ["fr N"] = { true, "𝔑" },
    ["fr O"] = { true, "𝔒" },
    ["fr P"] = { true, "𝔓" },
    ["fr Q"] = { true, "𝔔" },
    ["fr R"] = { true, "ℜ" },
    ["fr S"] = { true, "𝔖" },
    ["fr T"] = { true, "𝔗" },
    ["fr U"] = { true, "𝔘" },
    ["fr V"] = { true, "𝔙" },
    ["fr W"] = { true, "𝔚" },
    ["fr X"] = { true, "𝔛" },
    ["fr Y"] = { true, "𝔜" },
    ["fr Z"] = { true, "ℨ" },

    -- script

    ["cc a"] = { true, "𝒶" },
    ["cc b"] = { true, "𝒷" },
    ["cc c"] = { true, "𝒸" },
    ["cc d"] = { true, "𝒹" },
    ["cc e"] = { true, "ℯ" },
    ["cc f"] = { true, "𝒻" },
    ["cc g"] = { true, "ℊ" },
    ["cc h"] = { true, "𝒽" },
    ["cc i"] = { true, "𝒾" },
    ["cc j"] = { true, "𝒿" },
    ["cc k"] = { true, "𝓀" },
    ["cc l"] = { true, "𝓁" },
    ["cc m"] = { true, "𝓂" },
    ["cc n"] = { true, "𝓃" },
    ["cc o"] = { true, "ℴ" },
    ["cc p"] = { true, "𝓅" },
    ["cc q"] = { true, "𝓆" },
    ["cc r"] = { true, "𝓇" },
    ["cc s"] = { true, "𝓈" },
    ["cc t"] = { true, "𝓉" },
    ["cc u"] = { true, "𝓊" },
    ["cc v"] = { true, "𝓋" },
    ["cc w"] = { true, "𝓌" },
    ["cc x"] = { true, "𝓍" },
    ["cc y"] = { true, "𝓎" },
    ["cc z"] = { true, "𝓏" },

    ["cc A"] = { true, "𝒜" },
    ["cc B"] = { true, "ℬ" },
    ["cc C"] = { true, "𝒞" },
    ["cc D"] = { true, "𝒟" },
    ["cc E"] = { true, "ℰ" },
    ["cc F"] = { true, "ℱ" },
    ["cc G"] = { true, "𝒢" },
    ["cc H"] = { true, "ℋ" },
    ["cc I"] = { true, "ℐ" },
    ["cc J"] = { true, "𝒥" },
    ["cc K"] = { true, "𝒦" },
    ["cc L"] = { true, "ℒ" },
    ["cc M"] = { true, "ℳ" },
    ["cc N"] = { true, "𝒩" },
    ["cc O"] = { true, "𝒪" },
    ["cc P"] = { true, "𝒫" },
    ["cc Q"] = { true, "𝒬" },
    ["cc R"] = { true, "ℛ" },
    ["cc S"] = { true, "𝒮" },
    ["cc T"] = { true, "𝒯" },
    ["cc U"] = { true, "𝒰" },
    ["cc V"] = { true, "𝒱" },
    ["cc W"] = { true, "𝒲" },
    ["cc X"] = { true, "𝒳" },
    ["cc Y"] = { true, "𝒴" },
    ["cc Z"] = { true, "𝒵" },

    -- bold

    ["bb a"] = { true, "𝒂" },
    ["bb b"] = { true, "𝒃" },
    ["bb c"] = { true, "𝒄" },
    ["bb d"] = { true, "𝒅" },
    ["bb e"] = { true, "𝒆" },
    ["bb f"] = { true, "𝒇" },
    ["bb g"] = { true, "𝒈" },
    ["bb h"] = { true, "𝒉" },
    ["bb i"] = { true, "𝒊" },
    ["bb j"] = { true, "𝒋" },
    ["bb k"] = { true, "𝒌" },
    ["bb l"] = { true, "𝒍" },
    ["bb m"] = { true, "𝒎" },
    ["bb n"] = { true, "𝒏" },
    ["bb o"] = { true, "𝒐" },
    ["bb p"] = { true, "𝒑" },
    ["bb q"] = { true, "𝒒" },
    ["bb r"] = { true, "𝒓" },
    ["bb s"] = { true, "𝒔" },
    ["bb t"] = { true, "𝒕" },
    ["bb u"] = { true, "𝒖" },
    ["bb v"] = { true, "𝒗" },
    ["bb w"] = { true, "𝒘" },
    ["bb x"] = { true, "𝒙" },
    ["bb y"] = { true, "𝒚" },
    ["bb z"] = { true, "𝒛" },

    ["bb A"] = { true, "𝑨" },
    ["bb B"] = { true, "𝑩" },
    ["bb C"] = { true, "𝑪" },
    ["bb D"] = { true, "𝑫" },
    ["bb E"] = { true, "𝑬" },
    ["bb F"] = { true, "𝑭" },
    ["bb G"] = { true, "𝑮" },
    ["bb H"] = { true, "𝑯" },
    ["bb I"] = { true, "𝑰" },
    ["bb J"] = { true, "𝑱" },
    ["bb K"] = { true, "𝑲" },
    ["bb L"] = { true, "𝑳" },
    ["bb M"] = { true, "𝑴" },
    ["bb N"] = { true, "𝑵" },
    ["bb O"] = { true, "𝑶" },
    ["bb P"] = { true, "𝑷" },
    ["bb Q"] = { true, "𝑸" },
    ["bb R"] = { true, "𝑹" },
    ["bb S"] = { true, "𝑺" },
    ["bb T"] = { true, "𝑻" },
    ["bb U"] = { true, "𝑼" },
    ["bb V"] = { true, "𝑽" },
    ["bb W"] = { true, "𝑾" },
    ["bb X"] = { true, "𝑿" },
    ["bb Y"] = { true, "𝒀" },
    ["bb Z"] = { true, "𝒁" },

    -- sans

    ["sf a"] = { true, "𝖺" },
    ["sf b"] = { true, "𝖻" },
    ["sf c"] = { true, "𝖼" },
    ["sf d"] = { true, "𝖽" },
    ["sf e"] = { true, "𝖾" },
    ["sf f"] = { true, "𝖿" },
    ["sf g"] = { true, "𝗀" },
    ["sf h"] = { true, "𝗁" },
    ["sf i"] = { true, "𝗂" },
    ["sf j"] = { true, "𝗃" },
    ["sf k"] = { true, "𝗄" },
    ["sf l"] = { true, "𝗅" },
    ["sf m"] = { true, "𝗆" },
    ["sf n"] = { true, "𝗇" },
    ["sf o"] = { true, "𝗈" },
    ["sf p"] = { true, "𝗉" },
    ["sf q"] = { true, "𝗊" },
    ["sf r"] = { true, "𝗋" },
    ["sf s"] = { true, "𝗌" },
    ["sf t"] = { true, "𝗍" },
    ["sf u"] = { true, "𝗎" },
    ["sf v"] = { true, "𝗏" },
    ["sf w"] = { true, "𝗐" },
    ["sf x"] = { true, "𝗑" },
    ["sf y"] = { true, "𝗒" },
    ["sf z"] = { true, "𝗓" },

    ["sf A"] = { true, "𝖠" },
    ["sf B"] = { true, "𝖡" },
    ["sf C"] = { true, "𝖢" },
    ["sf D"] = { true, "𝖣" },
    ["sf E"] = { true, "𝖤" },
    ["sf F"] = { true, "𝖥" },
    ["sf G"] = { true, "𝖦" },
    ["sf H"] = { true, "𝖧" },
    ["sf I"] = { true, "𝖨" },
    ["sf J"] = { true, "𝖩" },
    ["sf K"] = { true, "𝖪" },
    ["sf L"] = { true, "𝖫" },
    ["sf M"] = { true, "𝖬" },
    ["sf N"] = { true, "𝖭" },
    ["sf O"] = { true, "𝖮" },
    ["sf P"] = { true, "𝖯" },
    ["sf Q"] = { true, "𝖰" },
    ["sf R"] = { true, "𝖱" },
    ["sf S"] = { true, "𝖲" },
    ["sf T"] = { true, "𝖳" },
    ["sf U"] = { true, "𝖴" },
    ["sf V"] = { true, "𝖵" },
    ["sf W"] = { true, "𝖶" },
    ["sf X"] = { true, "𝖷" },
    ["sf Y"] = { true, "𝖸" },
    ["sf Z"] = { true, "𝖹" },

    -- monospace

    ["tt a"] = { true, "𝚊" },
    ["tt b"] = { true, "𝚋" },
    ["tt c"] = { true, "𝚌" },
    ["tt d"] = { true, "𝚍" },
    ["tt e"] = { true, "𝚎" },
    ["tt f"] = { true, "𝚏" },
    ["tt g"] = { true, "𝚐" },
    ["tt h"] = { true, "𝚑" },
    ["tt i"] = { true, "𝚒" },
    ["tt j"] = { true, "𝚓" },
    ["tt k"] = { true, "𝚔" },
    ["tt l"] = { true, "𝚕" },
    ["tt m"] = { true, "𝚖" },
    ["tt n"] = { true, "𝚗" },
    ["tt o"] = { true, "𝚘" },
    ["tt p"] = { true, "𝚙" },
    ["tt q"] = { true, "𝚚" },
    ["tt r"] = { true, "𝚛" },
    ["tt s"] = { true, "𝚜" },
    ["tt t"] = { true, "𝚝" },
    ["tt u"] = { true, "𝚞" },
    ["tt v"] = { true, "𝚟" },
    ["tt w"] = { true, "𝚠" },
    ["tt x"] = { true, "𝚡" },
    ["tt y"] = { true, "𝚢" },
    ["tt z"] = { true, "𝚣" },

    ["tt A"] = { true, "𝙰" },
    ["tt B"] = { true, "𝙱" },
    ["tt C"] = { true, "𝙲" },
    ["tt D"] = { true, "𝙳" },
    ["tt E"] = { true, "𝙴" },
    ["tt F"] = { true, "𝙵" },
    ["tt G"] = { true, "𝙶" },
    ["tt H"] = { true, "𝙷" },
    ["tt I"] = { true, "𝙸" },
    ["tt J"] = { true, "𝙹" },
    ["tt K"] = { true, "𝙺" },
    ["tt L"] = { true, "𝙻" },
    ["tt M"] = { true, "𝙼" },
    ["tt N"] = { true, "𝙽" },
    ["tt O"] = { true, "𝙾" },
    ["tt P"] = { true, "𝙿" },
    ["tt Q"] = { true, "𝚀" },
    ["tt R"] = { true, "𝚁" },
    ["tt S"] = { true, "𝚂" },
    ["tt T"] = { true, "𝚃" },
    ["tt U"] = { true, "𝚄" },
    ["tt V"] = { true, "𝚅" },
    ["tt W"] = { true, "𝚆" },
    ["tt X"] = { true, "𝚇" },
    ["tt Y"] = { true, "𝚈" },
    ["tt Z"] = { true, "𝚉" },

    -- some more undocumented

    ["dx"] = { false, { "d", "x" } }, -- "{dx}" "\\left(dx\\right)"
    ["dy"] = { false, { "d", "y" } }, -- "{dy}" "\\left(dy\\right)"
    ["dz"] = { false, { "d", "z" } }, -- "{dz}" "\\left(dz\\right)"

    -- fences

    ["(:"] = { true, "(:" },
    ["{:"] = { true, "{:" },
    ["[:"] = { true, "[:" },
    ["("]  = { true, "(" },
    ["["]  = { true, "[" },
    ["{"]  = { true, "{" },
    ["<<"] = { true, "⟨" },     -- why not <:
    ["|_"] = { true, "⌊" },
    ["|~"] = { true, "⌈" },
    ["⟨"]  = { true, "⟨" },
    ["〈"]  = { true, "⟨" },
    ["〈"]  = { true, "⟨" },

    [":)"] = { true, ":)" },
    [":}"] = { true, ":}" },
    [":]"] = { true, ":]" },
    [")"]  = { true, ")" },
    ["]"]  = { true, "]" },
    ["}"]  = { true, "}" },
    [">>"] = { true, "⟩" },   -- why not :>
    ["~|"] = { true, "⌉" },
    ["_|"] = { true, "⌋" },
    ["⟩"]  = { true, "⟩" },
    ["〉"]  = { true, "⟩" },
    ["〉"]  = { true, "⟩" },

    ["lparent"]  = { true, "(" },
    ["lbracket"] = { true, "[" },
    ["lbrace"]   = { true, "{" },
    ["langle"]   = { true, "⟨" },
    ["lfloor"]   = { true, "⌊" },
    ["lceil"]    = { true, "⌈" },

    ["rparent"]  = { true, ")" },
    ["rbracket"] = { true, "]" },
    ["rbrace"]   = { true, "}" },
    ["rangle"]   = { true, "⟩" },
    ["rfloor"]   = { true, "⌋" },
    ["rceil"]    = { true, "⌉" },

    -- a bit special:

--     ["\\frac"]   = { true, "frac" },

    -- now it gets real crazy, only these two:

    ["&gt;"]     = { true, ">" },
    ["&lt;"]     = { true, "<" },

    -- extra:

    -- also, invisible times

    ["dd"]       = { false, "{\\tf d}" },
    ["ee"]       = { false, "{\\tf e}" },
    ["xxx"]      = { true, utfchar(0x2063) }, -- invisible times

}

-- a..z A..Z : allemaal op italic alphabet
-- en dan default naar upright "upr a"

for k, v in next, characters.data do
    local name = v.mathname
    if name and not reserved[name] then
        local char = { true, utfchar(k) }
        reserved[        name] = char
     -- reserved["\\" .. name] = char
    end
 -- local spec = v.mathspec
 -- if spec then
 --     for i=1,#spec do
 --         local name = spec[i].name
 --         if name and not reserved[name] then
 --             reserved[name] = { true, utfchar(k) }
 --         end
 --     end
 -- end
end

reserved.P  = nil
reserved.S  = nil


local isbinary = {
    ["\\frac"]              = true,
    ["\\root"]              = true,
    ["\\asciimathroot"]     = true,
    ["\\asciimathstackrel"] = true,
    ["\\overset"]           = true,
    ["\\underset"]          = true,
}

local isunary = { -- can be taken from reserved
    ["\\sqrt"]            = true,
    ["\\asciimathsqrt"]   = true,
    ["\\text"]            = true, --  mathoptext
    ["\\mathoptext"]      = true, --  mathoptext
    ["\\asciimathoptext"] = true, --  mathoptext
    ["\\hat"]             = true, --  widehat
    ["\\widehat"]         = true, --  widehat
    ["\\bar"]             = true, --
    ["\\overbar"]         = true, --
    ["\\overline"]        = true, --
    ["\\underline"]       = true, --
    ["\\vec"]             = true, --  overrightarrow
    ["\\overrightarrow"]  = true, --  overrightarrow
    ["\\dot"]             = true, --
    ["\\ddot"]            = true, --

    ["\\overbrace"]       = true,
    ["\\underbrace"]      = true,
    ["\\obrace"]          = true,
    ["\\ubrace"]          = true,
}

local isfunny = {
    ["\\sin"]           = true,
}

local isinfix = {
    ["^"] = true,
    ["_"] = true,
}

local isstupid = {
    ["\\prod"]      = true,
    ["\\sinh"]      = true,
    ["\\cosh"]      = true,
    ["\\tanh"]      = true,
    ["\\sum"]       = true,
    ["\\int"]       = true,
    ["\\sin"]       = true,
    ["\\cos"]       = true,
    ["\\tan"]       = true,
    ["\\csc"]       = true,
    ["\\sec"]       = true,
    ["\\cot"]       = true,
    ["\\log"]       = true,
    ["\\det"]       = true,
    ["\\lim"]       = true,
    ["\\mod"]       = true,
    ["\\gcd"]       = true,
    ["\\min"]       = true,
    ["\\max"]       = true,
    ["\\ln"]        = true,

 -- ["\\atan"]      = true,
 -- ["\\acos"]      = true,
 -- ["\\asin"]      = true,

    ["\\arctan"]    = true,
    ["\\arccos"]    = true,
    ["\\arcsin"]    = true,

    ["\\arctanh"]   = true,
    ["\\arccosh"]   = true,
    ["\\arcsinh"]   = true,

    ["f"]           = true,
    ["g"]           = true,
}

local isleft = {
    [s_lparent]  = true,
    [s_lbrace]   = true,
    [s_lbracket] = true,
    [s_langle]   = true,
    [s_lfloor]   = true,
    [s_lceil]    = true,
    [s_left]     = true,
}

local isright = {
    [s_rparent]  = true,
    [s_rbrace]   = true,
    [s_rbracket] = true,
    [s_rangle]   = true,
    [s_rfloor]   = true,
    [s_rceil]    = true,
    [s_right]    = true,
}

local issimplified = {
}

--

-- special mess (we have a generic one now but for the moment keep this)
-- special mess (we have a generic one now but for the moment keep this)

local d_one         = R("09")
local d_two         = d_one * d_one
local d_three       = d_two * d_one
local d_four        = d_three * d_one
local d_split       = P(-1) + Carg(2) * (S(".") /"")

local d_spaced      = (Carg(1) * d_three)^1

local digitized_1   = Cs ( (
                        d_three * d_spaced * d_split +
                        d_two   * d_spaced * d_split +
                        d_one   * d_spaced * d_split +
                        P(1)
                      )^1 )

local p_fourbefore  = d_four * d_split
local p_fourafter   = d_four * P(-1)

local p_beforecomma = d_three * d_spaced^0 * d_split
                    + d_two   * d_spaced^0 * d_split
                    + d_one   * d_spaced^0 * d_split
                    + d_one   * d_split

local p_aftercomma  = p_fourafter
                    + d_three * d_spaced
                    + d_two   * d_spaced
                    + d_one   * d_spaced

local digitized_2   = Cs (
                         p_fourbefore  *   (p_aftercomma^0) +
                         p_beforecomma * ((p_aftercomma + d_one^1)^0)
                      )

local p_fourbefore  = d_four * d_split
local p_fourafter   = d_four
local d_spaced      = (Carg(1) * (d_three + d_two + d_one))^1
local p_aftercomma  = p_fourafter * P(-1)
                    + d_three * d_spaced * P(1)^0
                    + d_one^1

-- local digitized_3   = Cs (
--                          p_fourbefore  * p_aftercomma^0 +
--                          p_beforecomma * p_aftercomma^0
--                       )

local digitized_3   = Cs((p_fourbefore + p_beforecomma) * p_aftercomma^0)

local splitmethods = {
    digitized_1,
    digitized_2,
    digitized_3,
}

local splitmethod    = nil
local symbolmethod   = nil
local digitseparator = utfchar(0x2008)
local digitsymbol    = "."

local v_yes_digits   = interfaces and interfaces.variables.yes or true

function asciimath.setup(settings)
    splitmethod = splitmethods[tonumber(settings.splitmethod) or 0]
    if splitmethod then
        digitsymbol = settings.symbol
        if not digitsymbol or digitsymbol == "" then
             digitsymbol = "."
        end
        local separator = settings.separator
     -- if separator == true or not interfaces or interfaces.variables.yes then
        if separator == true or separator == nil or separator == v_yes_digits then
            digitseparator = utfchar(0x2008)
        elseif type(separator) == "string" and separator ~= "" then
            digitseparator = separator
        else
            splitmethod = nil
        end
        if digitsymbol ~= "." then
            symbolmethod = lpeg.replacer(".",digitsymbol)
        else
            symbolmethod = nil
        end
    end
end

local collected_digits   = { }
local collected_filename = "asciimath-digits.lua"

function numbermess(s)
    if splitmethod then
        local d = lpegmatch(splitmethod,s,1,digitseparator,digitsymbol)
        if not d and symbolmethod then
            d = lpegmatch(symbolmethod,s)
        end
        if d then
            if trace_digits and s ~= d then
                collected_digits[s] = d
            end
            return d
        end
    end
    return s
end

-- asciimath.setup { splitmethod = 3, symbol = "," }
-- local t = {
--     "0.00002",
--     "1", "12", "123", "1234", "12345", "123456", "1234567", "12345678", "123456789",
--     "1.1",
--     "12.12",
--     "123.123",
--     "1234.123",
--     "1234.1234",
--     "12345.1234",
--     "1234.12345",
--     "12345.12345",
--     "123456.123456",
--     "1234567.1234567",
--     "12345678.12345678",
--     "123456789.123456789",
--     "0.1234",
--     "1234.0",
--     "1234.00",
--     "0.123456789",
--     "100.00005",
--     "0.80018",
--     "10.80018",
--     "100.80018",
--     "1000.80018",
--     "10000.80018",
-- }
-- for i=1,#t do print(formatters["%-20s : [%s]"](t[i],numbermess(t[i]))) end

statistics.register("asciimath",function()
    if trace_digits then
        local n = table.count(collected_digits)
        if n > 0 then
            table.save(collected_filename,collected_digits)
            return string.format("%s digit conversions saved in %s",n,collected_filename)
        else
            os.remove(collected_filename)
        end
    end
end)

local p_number_base = patterns.cpnumber or patterns.cnumber or patterns.number
local p_number      = C(p_number_base)
----- p_number      = p_number_base
local p_spaces      = patterns.whitespace

local p_utf_base    = patterns.utf8character
local p_utf         = C(p_utf_base)
-- local p_entity      = (P("&") * C((1-P(";"))^2) * P(";"))/ entities

-- entities["gt"]    = ">"
-- entities["lt"]    = "<"
-- entities["amp"]   = "&"
-- entities["dquot"] = '"'
-- entities["quot"]  = "'"

local p_onechar     = p_utf_base * P(-1)

----- p_number = Cs((patterns.cpnumber or patterns.cnumber or patterns.number)/function(s) return (gsub(s,",","{,}")) end)

local sign    = P("-")^-1
local digits  = R("09")^1
local integer = sign * digits
local real    = digits * (S(".") * digits)^-1
local float   = real * (P("E") * integer)^-1

-- local number  = C(float + integer)
-- local p_number  = C(float)
local p_number  = float / numbermess

local k_reserved = sortedkeys(reserved)
local k_commands = { }
local k_unicode  = { }

asciimath.keys = {
    reserved = k_reserved
}

local k_reserved_different = { }
local k_reserved_words     = { }

for k, v in sortedhash(reserved) do
    local replacement = v[2]
    if v[1] then
        k_unicode[k] = replacement
    else
        k_unicode[k] = k -- keep them ... later we remap these
        if k ~= replacement then
            k_reserved_different[#k_reserved_different+1] = k
        end
    end
    if find(k,"^[a-zA-Z]+$") then
        k_unicode["\\"..k] = replacement
    else
        k_unicode["\\"..k] = k  -- dirty trick, no real unicode (still needed ?)
    end
    if not find(k,"[^a-zA-Z]") then
        k_reserved_words[#k_reserved_words+1] = k
    end
    k_commands[k] = replacement
end

local p_reserved =
    lpeg.utfchartabletopattern(k_reserved_different) / k_commands

local p_unicode =
--     lpeg.utfchartabletopattern(table.keys(k_unicode)) / k_unicode
    lpeg.utfchartabletopattern(k_unicode) / k_unicode

local p_texescape = patterns.texescape

local function texescaped(s)
    return lpegmatch(p_texescape,s) or s
end

local p_text =
    P("text")
  * p_spaces^0
  * Cc("\\asciimathoptext")
  * ( -- maybe balanced
        Cs( P("{")      * ((1-P("}"))^0/texescaped) *  P("}")     )
      + Cs((P("(")/"{") * ((1-P(")"))^0/texescaped) * (P(")")/"}"))
    )
  + Cc("\\asciimathoptext") * Cs(Cc("{") * (C(patterns.undouble)/texescaped) * Cc("}"))

local m_left = {
    ["(:"] = s_langle,
    ["{:"] = s_left,
    ["[:"] = s_left,
    ["("]  = s_lparent,
    ["["]  = s_lbracket,
    ["{"]  = s_lbrace,
    ["⟨"]  = s_langle,
    ["⌈"] = s_lceil,
    ["⌊"] = s_lfloor,

 -- ["<<"] = s_langle,     -- why not <:
 -- ["|_"] = s_lfloor,
 -- ["|~"] = s_lceil,
 -- ["〈"]  = s_langle,
 -- ["〈"]  = s_langle,

 -- ["lparent"]  = s_lparent,
 -- ["lbracket"] = s_lbracket,
 -- ["lbrace"]   = s_lbrace,
 -- ["langle"]   = s_langle,
 -- ["lfloor"]   = s_lfloor,
 -- ["lceil"]    = s_lceil,
}

local m_right = {
    [":)"] = s_rangle,
    [":}"] = s_right,
    [":]"] = s_right,
    [")"]  = s_rparent,
    ["]"]  = s_rbracket,
    ["}"]  = s_rbrace,
    ["⟩"]  = s_rangle,
    ["⌉"]  = s_rceil,
    ["⌋"]  = s_rfloor,

 -- [">>"] = s_rangle,   -- why not :>
 -- ["~|"] = s_rceil,
 -- ["_|"] = s_rfloor,
 -- ["〉"]  = s_rangle,
 -- ["〉"]  = s_rangle,

 -- ["rparent"]  = s_rparent,
 -- ["rbracket"] = s_rbracket,
 -- ["rbrace"]   = s_rbrace,
 -- ["rangle"]   = s_rangle,
 -- ["rfloor"]   = s_rfloor,
 -- ["rceil"]    = s_rceil,
}

local islimits = {
    ["\\sum"]  = true,
 -- ["∑"]      = true,
    ["\\prod"] = true,
 -- ["∏"]      = true,
    ["\\lim"]  = true,
}

local p_left =
    lpeg.utfchartabletopattern(m_left) / m_left
local p_right =
    lpeg.utfchartabletopattern(m_right) / m_right

-- special cases

-- local p_special =
--     C("/")
--   + P("\\ ")  * Cc("{}") * p_spaces^0 * C(S("^_"))
--   + P("\\ ")  * Cc("\\space")
--   + P("\\\\") * Cc("\\backslash")
--   + P("\\")   * (R("az","AZ")^1/entities)
--   + P("|")    * Cc("\\|")
--
-- faster bug also uglier:

local p_special =
    P("|")  * Cc("\\|") -- s_mbar -- maybe always add left / right as in mml ?
  + P("\\") * (
        (
            P(" ") * (
                  Cc("{}") * p_spaces^0 * C(S("^_"))
                + Cc("\\space")
            )
        )
      + P("\\") * Cc("\\backslash")
   -- + (R("az","AZ")^1/entities)
      + C(R("az","AZ")^1)
    )

-- open | close :: {: | :}

local u_parser = Cs ( (
    patterns.doublequoted +
    P("text") * p_spaces^0 * P("(") * (1-P(")"))^0 * P(")") + -- -- todo: balanced
    P("\\frac") / "frac" + -- bah
    p_unicode +
    p_utf_base
)^0 )

local a_parser = Ct { "tokenizer",
    tokenizer = (
        p_spaces
      + p_number
      + p_text
   -- + Ct(p_open * V("tokenizer") * p_close)        -- {: (a+b,=,1),(a+b,=,7) :}
   -- + Ct(p_open * V("tokenizer") * p_close_right)  -- {  (a+b,=,1),(a+b,=,7) :}
   -- + Ct(p_open_left * V("tokenizer") * p_right)   -- {: (a+b,=,1),(a+b,=,7)  }
      + Ct(p_left * V("tokenizer") * p_right)        -- {  (a+b,=,1),(a+b,=,7)  }
      + p_special
      + p_reserved
  --  + p_utf - p_close - p_right
      + (p_utf - p_right)
    )^1,
}

local collapse  = nil
local serialize = table.serialize
local f_state   = formatters["level %s : %s : intermediate"]

local function show_state(t,level,state)
    report_asciimath(serialize(t,f_state(level,state)))
end

local function show_result(original,unicoded,texcoded)
    report_asciimath("original > %s",original)
    report_asciimath("unicoded > %s",unicoded)
    report_asciimath("texcoded > %s",texcoded)
end

local function collapse_matrices(t)
    local n = #t
    if n > 4 and t[3] == "," then
        local l1 = t[1]
        local r1 = t[n]
        if isleft[l1] and isright[r1] then
            local l2 = t[2]
            local r2 = t[n-1]
            if type(l2) == "table" and type(r2) == "table" then
                -- we have a matrix
                local valid = true
                for i=3,n-2,2 do
                    if t[i] ~= "," then
                        valid = false
                        break
                    end
                end
                if valid then
                    for i=2,n-1,2 do
                        local ti = t[i]
                        local tl = ti[1]
                        local tr = ti[#ti]
                        if isleft[tl] and isright[tr] then
                            -- ok
                        else
                            valid = false
                            break
                        end
                    end
                    if valid then
                        local omit = l1 == s_left and r1 == s_right
                        if omit then
                            t[1] = "\\startmatrix"
                        else
                            t[1] = l1 .. "\\startmatrix"
                        end
                        for i=2,n-1 do
                            if t[i] == "," then
                                t[i] = "\\NR"
                            else
                                local ti = t[i]
                                ti[1] = "\\NC"
                                for i=2,#ti-1 do
                                    if ti[i] == "," then
                                        ti[i] = "\\NC"
                                    end
                                end
                                ti[#ti] = nil
                            end
                        end
                        if omit then
                            t[n] = "\\NR\\stopmatrix"
                        else
                            t[n] = "\\NR\\stopmatrix" .. r1
                        end
                    end
                end
            end
        end
    end
    return t
end

local function collapse_bars(t)
    local n, i, l, m = #t, 1, false, 0
    while i <= n do
        local current = t[i]
        if current == "\\|" then
            if l then
                m = m + 1
                t[l] = s_lbar
                t[i] = s_rbar
                t[m] = { unpack(t,l,i) }
                l = false
            else
                l = i
            end
        elseif not l then
            m = m + 1
            t[m] = current
        end
        i = i + 1
    end
    if l then
        -- problem: we can have a proper nesting
local d = false
for i=1,m do
    local ti = t[i]
    if type(ti) == "string" and find(ti,"\\left",1,true) then
        d = true
        break
    end
end
if not d then
        local tt = { s_lnothing } -- space fools final checker
        local tm  = 1
        for i=1,m do
            tm = tm + 1
            tt[tm] = t[i]
        end
        tm = tm + 1
        tt[tm] = s_mbar
        for i=l+1,n do
            tm = tm + 1
            tt[tm] = t[i]
        end
        tm = tm + 1
        tt[tm] = s_rnothing -- space fools final checker
        m = tm
        t = tt
end
    elseif m < n then
        for i=n,m+1,-1 do
            t[i] = nil
        end
    end
    return t
end

local function collapse_pairs(t)
    local n, i = #t, 1
    while i < n do
        local current = t[i]
        if current == "/" and i > 1 then
            local tl = t[i-1]
            local tr = t[i+1]
            local tn = t[i+2]
            if type(tl) == "table" then
                if isleft[tl[1]] and isright[tl[#tl]] then
                    tl[1]   = "" -- todo: remove
                    tl[#tl] = nil
                end
            end
            if type(tr) == "table" then
                if tn == "^" then
                    -- brr 1/(1+x)^2
                elseif isleft[tr[1]] and isright[tr[#tr]] then
                    tr[1]   = "" -- todo: remove
                    tr[#tr] = nil
                end
            end
            i = i + 2
        elseif current == "," or current == ";" then
         -- t[i] = current .. "\\thinspace" -- look sbad in (a,b)
            i = i + 1
        else
            i = i + 1
        end
    end
    return t
end

local function collapse_parentheses(t)
    local n, i = #t, 1
    if n > 2 then
        while i < n do
            local current = t[i]
            if type(current) == "table" and isleft[t[i-1]] and isright[t[i+1]] then
                local c = #current
                if c > 2 and isleft[current[1]] and isright[current[c]] then
                    remove(current,c)
                    remove(current,1)
                end
                i = i + 3
            else
                i = i + 1
            end
        end
    end
    return t
end

local function collapse_stupids(t)
    local n, m, i = #t, 0, 1
    while i <= n do
        m = m + 1
        local current = t[i]
        if isstupid[current] then
            local one = t[i+1]
            if type(one) == "table" then
                one = collapse(one,level)
                t[m] = current .. "{" .. one .. "}"
                i = i + 2
            else
                t[m] = current
                i = i + 1
            end
        else
            t[m] = current
            i = i + 1
        end
    end
    if i == n then -- yes?
        m = m + 1
        t[m] = t[n]
    end
    if m < n then
        for i=n,m+1,-1 do
            t[i] = nil
        end
    end
    return t
end

local function collapse_signs(t)
    local n, m, i = #t, 0, 1
    while i <= n do
        m = m + 1
        local current = t[i]
        if isunary[current] then
            local one = t[i+1]
            if not one then
--                 m = m + 1
                t[m] = current .. "{}" -- error
                return t
--                 break
            end
            if type(one) == "table" then
                if isleft[one[1]] and isright[one[#one]] then
                    remove(one,#one)
                    remove(one,1)
                end
                one = collapse(one,level)
            elseif one == "-" and i + 2 <= n then -- or another sign ? or unary ?
                local t2 = t[i+2]
                if type(t2) == "string" then
                    one = one .. t2
                    i = i + 1
                end
            end
            t[m] = current .. "{" .. one .. "}"
            i = i + 2
        elseif i + 2 <= n and isfunny[current] then
            local one = t[i+1]
            if isinfix[one] then
                local two = t[i+2]
                if two == "-" then -- or another sign ? or unary ?
                    local three = t[i+3]
                    if three then
                        if type(three) == "table" then
                            three = collapse(three,level)
                        end
                        t[m] = current .. one .. "{" .. two .. three .. "}"
                        i = i + 4
                    else
                        t[m] = current
                        i = i + 1
                    end
                else
                    t[m] = current
                    i = i + 1
                end
            else
                t[m] = current
                i = i + 1
            end
        else
            t[m] = current
            i = i + 1
        end
    end
    if i == n then -- yes?
        m = m + 1
        t[m] = t[n]
    end
    if m < n then
        for i=n,m+1,-1 do
            t[i] = nil
        end
    end
    return t
end

local function collapse_binaries(t)
    local n, m, i = #t, 0, 1
    while i <= n do
        m = m + 1
        local current = t[i]
        if isbinary[current] then
            local one = t[i+1]
            local two = t[i+2]
            if not one then
                t[m] = current .. "{}{}" -- error
return t
--                 break
            end
            if type(one) == "table" then
                if isleft[one[1]] and isright[one[#one]] then
                    remove(one,#one)
                    remove(one,1)
                end
                one = collapse(one,level)
            end
            if not two then
                t[m] = current .. "{" .. one .. "}{}"
return t
--                 break
            end
            if type(two) == "table" then
                if isleft[two[1]] and isright[two[#two]] then
                    remove(two,#two)
                    remove(two,1)
                end
                two = collapse(two,level)
            end
            t[m] = current .. "{" .. one .. "}{" .. two .. "}"
            i = i + 3
        else
            t[m] = current
            i = i + 1
        end
    end
    if i == n then -- yes?
        m = m + 1
        t[m] = t[n]
    end
    if m < n then
        for i=n,m+1,-1 do
            t[i] = nil
        end
    end
    return t
end

local function collapse_infixes_1(t)
    local n, i = #t, 1
    while i <= n do
        local current = t[i]
        if isinfix[current] then
            local what = t[i+1]
            if what then
                if type(what) == "table" then
                    local f, l = what[1], what[#what]
                    if isleft[f] and isright[l] then
                        remove(what,#what)
                        remove(what,1)
                    end
                    t[i+1] = collapse(what,level) -- collapse ?
                end
                i = i + 2
            else
                break
            end
        else
            i = i + 1
        end
    end
    return t
end

function collapse_limits(t)
    local n, m, i = #t, 0, 1
    while i <= n do
        m = m + 1
        local current = t[i]
        if islimits[current] then
            local one, two, first, second = nil, nil, t[i+1], t[i+3]
            if first and isinfix[first] then
                one = t[i+2]
                if one then
                 -- if type(one) == "table" then
                 --     if isleft[one[1]] and isright[one[#one]] then
                 --         remove(one,#one)
                 --         remove(one,1)
                 --     end
                 --     one = collapse(one,level)
                 -- end
                    if second and isinfix[second] then
                        two = t[i+4]
                     -- if type(two) == "table" then
                     --     if isleft[two[1]] and isright[two[#two]] then
                     --         remove(two,#two)
                     --         remove(two,1)
                     --     end
                     --     two = collapse(two,level)
                     -- end
                    end
                    if two then
                        t[m] = current .. "\\limits" .. first .. "{" .. one .. "}" .. second .. "{" .. two .. "}"
                        i = i + 5
                    else
                        t[m] = current .. "\\limits" .. first .. "{" .. one .. "}"
                        i = i + 3
                    end
                else
                    t[m] = current
                    i = i + 1
                end
            else
                t[m] = current
                i = i + 1
            end
        else
            t[m] = current
            i = i + 1
        end
    end
    if i == n then -- yes?
        m = m + 1
        t[m] = t[n]
    end
    if m < n then
        for i=n,m+1,-1 do
            t[i] = nil
        end
    end
    return t
end

local function collapse_tables(t)
    local n, m, i = #t, 0, 1
    while i <= n do
        m = m + 1
        local current = t[i]
        if type(current) == "table" then
            if current[1] == "\\NC" then
                t[m] = collapse(current,level)
            else
                t[m] = "{" .. collapse(current,level) .. "}"
            end
            i = i + 1
        else
            t[m] = current
            i = i + 1
        end
    end
    if i == n then -- yes?
        m = m + 1
        t[m] = t[n]
    end
    if m < n then
        for i=n,m+1,-1 do
            t[i] = nil
        end
    end
    return t
end

local function collapse_infixes_2(t)
    local n, m, i = #t, 0, 1
    while i < n do
        local current = t[i]
        if isinfix[current] and i > 1 then
            local tl = t[i-1]
            local tr = t[i+1]
            local ti = t[i+2]
            local tn = t[i+3]
            if ti and tn and isinfix[ti] then
                t[m] = tl .. current .. "{" .. tr .. "}" .. ti .. "{" .. tn .. "}"
                i = i + 4
            else
                t[m] = tl .. current .. "{" .. tr .. "}"
                i = i + 2
            end
        else
            m = m + 1
            t[m] = current
            i = i + 1
        end
    end
    if i == n then
        m = m + 1
        t[m] = t[n]
    end
    if m < n then
        for i=n,m+1,-1 do
            t[i] = nil
        end
    end
    return t
end

local function collapse_fractions_1(t)
    local n, m, i = #t, 0, 1
    while i < n do
        local current = t[i]
        if current == "/" and i > 1 then
            local tl = t[i-1]
            local tr = t[i+1]
            t[m] = "\\frac{" .. tl .. "}{" .. tr .. "}"
            i = i + 2
            if i < n then
                m = m + 1
                t[m] = t[i]
                i = i + 1
            end
        else
            m = m + 1
            t[m] = current
            i = i + 1
        end
    end
    if i == n then
        m = m + 1
        t[m] = t[n]
    end
    if m < n then
        for i=n,m+1,-1 do
            t[i] = nil
        end
    end
    return t
end

local function collapse_fractions_2(t)
    local n, m, i = #t, 0, 1
    while i < n do
        local current = t[i]
        if current == "⁄" and i > 1 then -- \slash
            if i < n and t[i+1] == "⁄" then
                -- crap for
                t[m] = "{" .. s_left .. t[i-1] .. s_mslash .. s_mslash .. t[i+2] .. s_right .. "}"
                i = i + 3
            else
                t[m] = "{" .. s_left .. t[i-1] .. s_mslash .. t[i+1] .. s_right .. "}"
                i = i + 2
            end
            if i < n then
                m = m + 1
                t[m] = t[i]
                i = i + 1
            end
        else
            m = m + 1
            t[m] = current
            i = i + 1
        end
    end
    if i == n then
        m = m + 1
        t[m] = t[n]
    end
    if m < n then
        for i=n,m+1,-1 do
            t[i] = nil
        end
    end
    return t
end

local function collapse_result(t)
    local n = #t
    if t[1] == s_left and t[n] == s_right then -- see bar .. space needed there
        return concat(t," ",2,n-1)
    else
        return concat(t," ")
    end
end

collapse = function(t,level)
    -- check
    if not t then
        return ""
    end
    -- tracing
    if trace_details then
        if level then
            level = level + 1
        else
            level = 1
        end
        show_state(t,level,"parsed")
    end
    -- steps
    t = collapse_matrices   (t) if trace_details then show_state(t,level,"matrices")      end
    t = collapse_bars       (t) if trace_details then show_state(t,level,"bars")          end
    t = collapse_stupids    (t) if trace_details then show_state(t,level,"stupids")         end
    t = collapse_pairs      (t) if trace_details then show_state(t,level,"pairs")         end
    t = collapse_parentheses(t) if trace_details then show_state(t,level,"parentheses")   end
    t = collapse_signs      (t) if trace_details then show_state(t,level,"signs")         end
    t = collapse_binaries   (t) if trace_details then show_state(t,level,"binaries")      end
    t = collapse_infixes_1  (t) if trace_details then show_state(t,level,"infixes (1)")   end
    t = collapse_limits     (t) if trace_details then show_state(t,level,"limits")        end
    t = collapse_tables     (t) if trace_details then show_state(t,level,"tables")        end
    t = collapse_infixes_2  (t) if trace_details then show_state(t,level,"infixes (2)")   end
    t = collapse_fractions_1(t) if trace_details then show_state(t,level,"fractions (1)") end
    t = collapse_fractions_2(t) if trace_details then show_state(t,level,"fractions (2)") end
    -- done
    return collapse_result(t)
end

-- todo: cache simple ones, say #str < 10, maybe weak

local context         = context
local ctx_mathematics = context and context.mathematics or report_asciimath
local ctx_type        = context and context.type        or function() end
local ctx_inleft      = context and context.inleft      or function() end

local function convert(str,totex)
    local unicoded = lpegmatch(u_parser,str) or str
    local texcoded = collapse(lpegmatch(a_parser,unicoded))
    if trace_mapping then
        show_result(str,unicoded,texcoded)
    end
    if totex then
        ctx_mathematics(texcoded)
    else
        return texcoded
    end
end

local n = 0
local p = (
    (S("{[(") + P("\\left" )) / function() n = n + 1 end
  + (S("}])") + P("\\right")) / function() n = n - 1 end
  + p_utf_base
)^0

-- faster:
--
-- local p = (
--     (S("{[(") + P("\\left" )) * Cc(function() n = n + 1 end)
--   + (S("}])") + P("\\right")) * Cc(function() n = n - 1 end)
--   + p_utf_base
-- )^0

local function invalidtex(str)
    n = 0
    lpegmatch(p,str)
    if n == 0 then
        return false
    elseif n < 0 then
        return formatters["too many left fences: %s"](-n)
    elseif n > 0 then
        return formatters["not enough right fences: %s"](n)
    end
end

local collected = { }
local indexed   = { }

-- bonus

local p_reserved_spaced =
    C(lpeg.utfchartabletopattern(k_reserved_words)) / " %1 "

local p_text =
    C(P("text")) / " %1 "
  * p_spaces^0
  * ( -- maybe balanced
        (P("{") * (1-P("}"))^0 * P("}"))
      + (P("(") * (1-P(")"))^0 * P(")"))
    )
  + patterns.doublequoted

local p_expand   = Cs((p_text + p_reserved_spaced + p_utf_base)^0)
local p_compress = patterns.collapser

local function cleanedup(str)
    return lpegmatch(p_compress,lpegmatch(p_expand,str)) or str
end

-- so far

local function register(s,cleanedup,collected,shortname)
    local c = cleanedup(s)
    local f = collected[c]
    if f then
        f.count = f.count + 1
        f.files[shortname] = (f.files[shortname] or 0) + 1
        if s ~= c then
            f.cleanedup = f.cleanedup + 1
        end
        f.dirty[s] = (f.dirty[s] or 0) + 1
    else
        local texcoded = convert(s)
        local message  = invalidtex(texcoded)
        if message then
            report_asciimath("%s: %s : %s",message,s,texcoded)
        end
        collected[c] = {
            count     = 1,
            files     = { [shortname] = 1 },
            texcoded  = texcoded,
            message   = message,
            cleanedup = s ~= c and 1 or 0,
            dirty     = { [s] = 1 }
        }
    end
end

local function wrapup(collected,indexed)
    local n = 0
    for k, v in sortedhash(collected) do
        n = n + 1
        v.n= n
        indexed[n] = k
    end
end

function collect(fpattern,element,collected,indexed)
    local element   = element or "am"
    local mpattern  = formatters["<%s>(.-)</%s>"](element,element)
    local filenames = resolvers.findtexfile(fpattern)
    if filenames and filenames ~= "" then
        filenames = { filenames }
    else
        filenames = dir.glob(fpattern)
    end
    local cfpattern = gsub(fpattern,"^%./",lfs.currentdir())
    local cfpattern = gsub(cfpattern,"\\","/")
    local wildcard  = string.split(cfpattern,"*")[1]
    if not collected then
        collected = { }
        indexed   = { }
    end
    for i=1,#filenames do
        filename = gsub(filenames[i],"\\","/")
        local splitname = (wildcard and wildcard ~= "" and string.split(filename,wildcard)[2]) or filename
        local shortname = gsub(splitname or file.basename(filename),"^%./","")
        if shortname == "" then
            shortname = filename
        end
        local fullname = resolvers.findtexfile(filename) or filename
        if fullname ~= "" then
            for s in gmatch(io.loaddata(fullname),mpattern) do
                register(s,cleanedup,collected,shortname)
            end
        end
    end
    wrapup(collected,indexed)
    return collected, indexed
end

function filter(root,pattern,collected,indexed)
    if not pattern or pattern == "" then
        pattern = "am"
    end
    if not collected then
        collected = { }
        indexed   = { }
    end
    for c in xmlcollected(root,pattern) do
        register(xmltext(c),cleanedup,collected,xmlinclusion(c) or "" )
    end
    wrapup(collected,indexed)
    return collected, indexed
end

asciimath.convert    = convert
asciimath.reserved   = reserved
asciimath.collect    = collect
asciimath.filter     = filter
asciimath.invalidtex = invalidtex
asciimath.cleanedup  = cleanedup

-- sin(x) = 1 : 3.3 uncached 1.2 cached , so no real gain (better optimize the converter then)

local uncrapped = {
    ["%"] = "\\mathpercent",
    ["&"] = "\\mathampersand",
    ["#"] = "\\mathhash",
    ["$"] = "\\mathdollar",
    ["^"] = "\\Hat{\\enspace}", -- terrible hack ... tex really does it sbest to turn any ^ into a superscript
    ["_"] = "\\underline{\\enspace}",
}

local function convert(str,nowrap)
    if str ~= "" then
        local unicoded = lpegmatch(u_parser,str) or str
        if lpegmatch(p_onechar,unicoded) then
            ctx_mathematics(uncrapped[unicoded] or unicoded)
        else
            local texcoded = collapse(lpegmatch(a_parser,unicoded))
            if trace_mapping then
                show_result(str,unicoded,texcoded)
            end
            if #texcoded == 0 then
                report_asciimath("error in asciimath: %s",str)
            else
                local message = invalidtex(texcoded)
                if message then
                    report_asciimath("%s: %s : %s",message,str,texcoded)
                    ctx_type(formatters["<%s>"](message))
                elseif nowrap then
                     context(texcoded)
                else
                    ctx_mathematics(texcoded)
                end
            end
        end
    end
end

local context = context

if not context then

--     trace_mapping = true
--     trace_details = true

--     report_asciimath(cleanedup([[ac+sinx+xsqrtx+sinsqrtx+sinsqrt(x)]]))
--     report_asciimath(cleanedup([[a "αsinsqrtx" b]]))
--     convert([[a "αsinsqrtx" b]])
--     report_asciimath(cleanedup([[a "α" b]]))
--     report_asciimath(cleanedup([[//4]]))

-- convert("leq\\leq")
-- convert([[\^{1/5}log]])
-- convert("sqrt")
-- convert("^")

-- convert[[\frac{a}{b}]]
-- convert[[frac{a}{b}]]

-- convert("frac{a}{b}")
-- convert("\\sin{a}{b}")
-- convert("sin{a}{b}")
-- convert("1: rightarrow")
-- convert("2: \\rightarrow")

-- convert("((1,2,3),(4,5,6),(7,8,9))")

-- convert("1/(t+x)^2")

--     convert("AA a > 0 ^^ b > 0 | {:log_g:} a + {:log_g:} b")
--     convert("AA a &gt; 0 ^^ b > 0 | {:log_g:} a + {:log_g:} b")

--     convert("10000,00001")
--     convert("4/18*100text(%)~~22,2")
--     convert("4/18*100text(%)≈22,2")
--     convert("62541/(197,6)≈316,05")

--     convert([[sum x]])
--     convert([[sum^(1)_(2) x]])
--     convert([[lim_(1)^(2) x]])
--     convert([[lim_(1) x]])
--     convert([[lim^(2) x]])

--     convert([[{: rangle]])
--     convert([[\langle\larr]])
--     convert([[langlelarr]])
--     convert([[D_f=[0 ,→〉]])
--     convert([[ac+sinx+xsqrtx]])
--     convert([[ac+\alpha x+xsqrtx-cc b*pi**psi-3alephx / bb X]])
--     convert([[ac+\ ^ x+xsqrtx]])
--     convert([[d/dx(x^2+1)]])
--     convert([[a "αsinsqrtx" b]])
--     convert([[a "α" b]])
--     convert([[//4]])
--     convert([[ {(a+b,=,1),(a+b,=,7)) ]])

--     convert([[ 2/a // 5/b = (2 b) / ( a b) // ( 5 a ) / ( a b ) = (2 b ) / ( 5 a ) ]])
--     convert([[ (2+x)/a // 5/b  ]])

--     convert([[ ( 2/a ) // ( 5/b ) = ( (2 b) / ( a b) ) // ( ( 5 a ) / ( a b ) ) = (2 b ) / ( 5 a ) ]])

--     convert([[ (x/y)^3 = x^3/y^3 ]])

--     convert([[ {: (1,2) :} ]])
--     convert([[ {: (a+b,=,1),(a+b,=,7) :} ]])
--     convert([[ {  (a+b,=,1),(a+b,=,7) :} ]])
--     convert([[ {: (a+b,=,1),(a+b,=,7)  } ]])
--     convert([[ {  (a+b,=,1),(a+b,=,7)  } ]])

--     convert([[(1,5 ±sqrt(1,25 ),0 )]])
--     convert([[1//2]])
--     convert([[(p)/sqrt(p)]])
--     convert([[u_tot]])
--     convert([[u_tot=4,4 L+0,054 T]])

--     convert([[ [←;0,2] ]])
--     convert([[ [←;0,2⟩ ]])
--     convert([[ ⟨←;0,2 ) ]])
--     convert([[ ⟨←;0,2 ] ]])
--     convert([[ ⟨←;0,2⟩ ]])

--     convert([[ x^2(x-1/16)=0 ]])
--     convert([[ y = ax + 3 - 3a ]])
--     convert([[ y= ((1/4)) ^x ]])
--     convert([[ x=\ ^ (1/4) log(0 ,002 )= log(0,002) / (log(1/4) ]])
--     convert([[ x=\ ^glog(y) ]])
--     convert([[ x^ (-1 1/2) =1/x^ (1 1/2)=1/ (x^1*x^ (1/2)) =1/ (xsqrt(x)) ]])
--     convert([[ x^2(10 -x)&gt;2 x^2 ]])
--     convert([[ x^4&gt;x ]])

    return

end

interfaces.implement {
    name      = "asciimath",
    actions   = convert,
    arguments = "string"
}

interfaces.implement {
    name      = "justasciimath",
    actions   = convert,
    arguments = { "string", true },
}

interfaces.implement {
    name      = "xmlasciimath",
    actions   = function(id)
        convert(xmlpure(lxmlgetid(id)))
    end,
    arguments = "string"
}

local ctx_typebuffer  = context.typebuffer
local ctx_mathematics = context.mathematics
local ctx_color       = context.color

local sequenced       = table.sequenced
local assign_buffer   = buffers.assign

local show     = { }
asciimath.show = show

local collected, indexed, ignored = { }, { }, { }

local color = { "darkred" }

function show.ignore(n)
    if type(n) == "string" then
        local c = collected[n]
        n = c and c.n
    end
    if n then
        ignored[n] = true
    end
end

function show.count(n,showcleanedup)
    local v = collected[indexed[n]]
    local count = v.count
    local cleanedup = v.cleanedup
    if not showcleanedup or cleanedup == 0 then
        context(count)
    elseif count == cleanedup then
        ctx_color(color,count)
    else
        context("%s+",count-cleanedup)
        ctx_color(color,cleanedup)
    end
end

local h  = { }
local am = { "am" }

function show.nofdirty(n)
    local k = indexed[n]
    local v = collected[k]
    local n = v.cleanedup
    h = { }
    if n > 0 then
        for d, n in sortedhash(v.dirty) do
            if d ~= k then
                h[#h+1] = { d, n }
            end
        end
    end
    context(#h)
end

function show.dirty(m,wrapped)
    local d = h[m]
    if d then
        ctx_inleft(d[2])
        if wrapped then
            assign_buffer("am",'"' .. d[1] .. '"')
        else
            assign_buffer("am",d[1])
        end
        ctx_typebuffer(am)
    end
end

function show.files(n)
    context(sequenced(collected[indexed[n]].files," "))
end

function show.input(n,wrapped)
    if wrapped then
        assign_buffer("am",'"' .. indexed[n] .. '"')
    else
        assign_buffer("am",indexed[n])
    end
    ctx_typebuffer(am)
end

function show.result(n)
    local v = collected[indexed[n]]
    if ignored[n] then
        context("ignored")
    elseif v.message then
        ctx_color(color, v.message)
    else
        ctx_mathematics(v.texcoded)
    end
end

function show.load(str,element)
    collected, indexed, ignored = { }, { }, { }
    local t = utilities.parsers.settings_to_array(str)
    for i=1,#t do
        asciimath.collect(t[i],element or "am",collected,indexed)
    end
end

function show.filter(id,element)
    collected, indexed, ignored = { }, { }, { }
    asciimath.filter(lxmlgetid(id),element or "am",collected,indexed)
end

function show.max()
    context(#indexed)
end

function show.statistics()
    local usedfiles    = { }
    local noffiles     = 0
    local nofokay      = 0
    local nofbad       = 0
    local nofcleanedup = 0
    for k, v in next, collected do
        if ignored[v.n] then
            nofbad = nofbad + v.count
        elseif v.message then
            nofbad = nofbad + v.count
        else
            nofokay = nofokay + v.count
        end
        nofcleanedup = nofcleanedup + v.cleanedup
        for k, v in next, v.files do
            local u = usedfiles[k]
            if u then
                usedfiles[k] = u + 1
            else
                noffiles = noffiles + 1
                usedfiles[k] = 1
            end
        end
    end
    local NC = context.NC
    local NR = context.NR
    local EQ = context.EQ
    context.starttabulate { "|B||" }
        NC() context("files")     EQ() context(noffiles)       NC() NR()
        NC() context("formulas")  EQ() context(nofokay+nofbad) NC() NR()
        NC() context("uniques")   EQ() context(#indexed)       NC() NR()
        NC() context("cleanedup") EQ() context(nofcleanedup)   NC() NR()
        NC() context("errors")    EQ() context(nofbad)         NC() NR()
    context.stoptabulate()
end

function show.save(name)
    table.save(name ~= "" and name or "dummy.lua",collected)
end
