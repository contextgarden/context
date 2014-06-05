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

local trace_mapping = false  if trackers then trackers.register("modules.asciimath.mapping", function(v) trace_mapping = v end) end
local trace_detail  = false  if trackers then trackers.register("modules.asciimath.detail",  function(v) trace_detail  = v end) end

local asciimath      = { }
local moduledata     = moduledata or { }
moduledata.asciimath = asciimath

if not characters then
    require("char-def")
    require("char-ini")
    require("char-ent")
end

local entities = characters.entities or { }

local report_asciimath = logs.reporter("mathematics","asciimath")

local type, rawget = type, rawget
local lpegmatch, patterns = lpeg.match, lpeg.patterns
local S, P, R, C, V, Cc, Ct, Cs = lpeg.S, lpeg.P, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc, lpeg.Ct, lpeg.Cs
local concat, sortedhash, sortedkeys = table.concat, table.sortedhash, table.sortedkeys
local rep, gmatch, gsub, find = string.rep, string.gmatch, string.gsub, string.find
local formatters = string.formatters

local reserved = {
 -- ["aleph"]     = "\\aleph",
 -- ["vdots"]     = "\\vdots",
 -- ["ddots"]     = "\\ddots",
 -- ["oint"]      = "\\oint",
 -- ["grad"]      = "\\nabla",
    ["prod"]      = "\\prod",
 -- ["prop"]      = "\\propto",
 -- ["sube"]      = "\\subseteq",
 -- ["supe"]      = "\\supseteq",
    ["sinh"]      = "\\sinh",
    ["cosh"]      = "\\cosh",
    ["tanh"]      = "\\tanh",
    ["sum"]       = "\\sum",
 -- ["vvv"]       = "\\vee",
 -- ["nnn"]       = "\\cap",
 -- ["uuu"]       = "\\cup",
 -- ["sub"]       = "\\subset",
 -- ["sup"]       = "\\supset",
 -- ["iff"]       = "\\Leftrightarrow",
    ["int"]       = "\\int",
 -- ["del"]       = "\\partial",
    ["sin"]       = "\\sin",
    ["cos"]       = "\\cos",
    ["tan"]       = "\\tan",
    ["csc"]       = "\\csc",
    ["sec"]       = "\\sec",
    ["cot"]       = "\\cot",
    ["log"]       = "\\log",
    ["det"]       = "\\det",
    ["lim"]       = "\\lim",
    ["mod"]       = "\\mod",
    ["gcd"]       = "\\gcd",
 -- ["lcm"]       = "\\lcm", -- undefined in context
    ["min"]       = "\\min",
    ["max"]       = "\\max",
 -- ["xx"]        = "\\times",
    ["in"]        = "\\in",
 -- ["ox"]        = "\\otimes",
 -- ["vv"]        = "\\vee",
 -- ["nn"]        = "\\cap",
 -- ["uu"]        = "\\cup",
 -- ["oo"]        = "\\infty",
    ["ln"]        = "\\ln",

 -- ["not"]       = "\\not",
    ["and"]       = "\\text{and}",
    ["or"]        = "\\text{or}",
    ["if"]        = "\\text{if}",

 -- ["AA"]        = "\\forall",
 -- ["EE"]        = "\\exists",
 -- ["TT"]        = "\\top",

    ["sqrt"]      = "\\rootradical{}",
    ["root"]      = "\\rootradical",
    ["frac"]      = "\\frac",
    ["stackrel"]  = "\\stackrel",
 -- ["text"]      = "\\mathoptext",
 -- ["bb"]        = "\\bb",
    ["hat"]       = "\\widehat",
    ["overbar"]   = "\\overbar",
    ["underline"] = "\\underline",
    ["vec"]       = "\\overrightarrow",
    ["dot"]       = "\\dot",
    ["ddot"]      = "\\ddot",

    -- binary operators

 -- ["+"]     = "+",
 -- ["-"]     = "-",
    ["*"]     = "⋅",
    ["**"]    = "⋆",
    ["//"]    = "/",
    ["\\"]    = "\\",
    ["xx"]    = "×",
    ["times"] = "×",
    ["-:"]    = "÷",
    ["@"]     = "∘",
    ["o+"]    = "⊕",
    ["ox"]    = "⊗",
    ["o."]    = "⊙",
    ["^^"]    = "∧",
    ["vv"]    = "∨",
    ["nn"]    = "∩",
    ["uu"]    = "∪",

    -- big operators

 -- ["sum"]  = "∑",
 -- ["prod"] = "∏",
    ["^^^"]  = "⋀",
    ["vvv"]  = "⋁",
    ["nnn"]  = "⋂",
    ["uuu"]  = "⋃",
    ["int"]  = "∫",
    ["oint"] = "∮",

    -- brackets

--     ["("]  = "(,
--     [")"]  = "),
--     ["["]  = "[,
--     ["]"]  = "],
--     ["{"]  = "{,
--     ["}"]  = "},
--     ["(:"] = "〈",
--     [":)"] = "〉",

    -- binary relations

    ["="]    = "=",
    ["!="]   = "≠",
    ["<"]    = "<",
    [">"]    = ">",
    ["<="]   = "≤",
    [">="]   = "≥",
    ["-<"]   = "≺",
    [">-"]   = "≻",
    ["in"]   = "∈",
    ["!in"]  = "∉",
    ["sub"]  = "⊂",
    ["sup"]  = "⊃",
    ["sube"] = "⊆",
    ["supe"] = "⊇",
    ["-="]   = "≡",
    ["~="]   = "≅",
    ["~~"]   = "≈",
    ["prop"] = "∝",

    -- arrows

    ["rarr"] = "→",
    ["->"]   = "→",
    ["larr"] = "←",
    ["harr"] = "↔",
    ["uarr"] = "↑",
    ["darr"] = "↓",
    ["rArr"] = "⇒",
    ["lArr"] = "⇐",
    ["hArr"] = "⇔",
    ["|->"]  = "↦",

    -- logical

 -- ["and"] = "and",
 -- ["or"]  = "or",
 -- ["if"]  = "if",
    ["not"] = "¬",
    ["=>"]  = "⇒",
    ["iff"] = "⇔",
    ["AA"]  = "∀",
    ["EE"]  = "∃",
    ["_|_"] = "⊥",
    ["TT"]  = "⊤",
    ["|--"] = "⊢",
    ["|=="] = "⊨",

    -- miscellaneous

    ["del"]     = "∂",
    ["grad"]    = "∇",
    ["+-"]      = "±",
    ["O/"]      = "∅",
    ["oo"]      = "∞",
    ["aleph"]   = "ℵ",
    ["angle"]   = "∠",
    ["/_"]      = "∠",
    [":."]      = "∴",
    ["..."]     = "...",               -- ldots
    ["ldots"]   = "...",               -- ldots
    ["cdots"]   = "⋯",
    ["vdots"]   = "⋮",
    ["ddots"]   = "⋱",
    ["diamond"] = "⋄",
    ["square"]  = "□",
    ["|__"]     = "⌊",
    ["__|"]     = "⌋",
    ["|~"]      = "⌈",
    ["~|"]      = "⌉",

    -- more
    ["_="]      = "≡",

    -- blackboard

    ["CC"] = "ℂ",
    ["NN"] = "ℕ",
    ["QQ"] = "ℚ",
    ["RR"] = "ℝ",
    ["ZZ"] = "ℤ",

    -- greek lowercase

    alpha      = "α",
    beta       = "β",
    gamma      = "γ",
    delta      = "δ",
    epsilon    = "ε",
    varepsilon = "ɛ",
    zeta       = "ζ",
    eta        = "η",
    theta      = "θ",
    vartheta   = "ϑ",
    iota       = "ι",
    kappa      = "κ",
    lambda     = "λ",
    mu         = "μ",
    nu         = "ν",
    xi         = "ξ",
    pi         = "π",
    rho        = "ρ",
    sigma      = "σ",
    tau        = "τ",
    upsilon    = "υ",
    phi        = "φ",
    varphi     = "ϕ",
    chi        = "χ",
    psi        = "ψ",
    omega      = "ω",

    -- greek uppercase

    Gamma  = "Γ",
    Delta  = "Δ",
    Theta  = "Θ",
    Lambda = "Λ",
    Xi     = "Ξ",
    Pi     = "Π",
    Sigma  = "Σ",
    Phi    = "Φ",
    Psi    = "Ψ",
    Omega  = "Ω",

    -- alternatively we could just inject a style switch + following character

    -- blackboard

    ["bbb a"] = "𝕒",
    ["bbb b"] = "𝕓",
    ["bbb c"] = "𝕔",
    ["bbb d"] = "𝕕",
    ["bbb e"] = "𝕖",
    ["bbb f"] = "𝕗",
    ["bbb g"] = "𝕘",
    ["bbb h"] = "𝕙",
    ["bbb i"] = "𝕚",
    ["bbb j"] = "𝕛",
    ["bbb k"] = "𝕜",
    ["bbb l"] = "𝕝",
    ["bbb m"] = "𝕞",
    ["bbb n"] = "𝕟",
    ["bbb o"] = "𝕠",
    ["bbb p"] = "𝕡",
    ["bbb q"] = "𝕢",
    ["bbb r"] = "𝕣",
    ["bbb s"] = "𝕤",
    ["bbb t"] = "𝕥",
    ["bbb u"] = "𝕦",
    ["bbb v"] = "𝕧",
    ["bbb w"] = "𝕨",
    ["bbb x"] = "𝕩",
    ["bbb y"] = "𝕪",
    ["bbb z"] = "𝕫",

    ["bbb A"] = "𝔸",
    ["bbb B"] = "𝔹",
    ["bbb C"] = "ℂ",
    ["bbb D"] = "𝔻",
    ["bbb E"] = "𝔼",
    ["bbb F"] = "𝔽",
    ["bbb G"] = "𝔾",
    ["bbb H"] = "ℍ",
    ["bbb I"] = "𝕀",
    ["bbb J"] = "𝕁",
    ["bbb K"] = "𝕂",
    ["bbb L"] = "𝕃",
    ["bbb M"] = "𝕄",
    ["bbb N"] = "ℕ",
    ["bbb O"] = "𝕆",
    ["bbb P"] = "ℙ",
    ["bbb Q"] = "ℚ",
    ["bbb R"] = "ℝ",
    ["bbb S"] = "𝕊",
    ["bbb T"] = "𝕋",
    ["bbb U"] = "𝕌",
    ["bbb V"] = "𝕍",
    ["bbb W"] = "𝕎",
    ["bbb X"] = "𝕏",
    ["bbb Y"] = "𝕐",
    ["bbb Z"] = "ℤ",

    -- fraktur

    ["fr a"] = "𝔞",
    ["fr b"] = "𝔟",
    ["fr c"] = "𝔠",
    ["fr d"] = "𝔡",
    ["fr e"] = "𝔢",
    ["fr f"] = "𝔣",
    ["fr g"] = "𝔤",
    ["fr h"] = "𝔥",
    ["fr i"] = "𝔦",
    ["fr j"] = "𝔧",
    ["fr k"] = "𝔨",
    ["fr l"] = "𝔩",
    ["fr m"] = "𝔪",
    ["fr n"] = "𝔫",
    ["fr o"] = "𝔬",
    ["fr p"] = "𝔭",
    ["fr q"] = "𝔮",
    ["fr r"] = "𝔯",
    ["fr s"] = "𝔰",
    ["fr t"] = "𝔱",
    ["fr u"] = "𝔲",
    ["fr v"] = "𝔳",
    ["fr w"] = "𝔴",
    ["fr x"] = "𝔵",
    ["fr y"] = "𝔶",
    ["fr z"] = "𝔷",

    ["fr A"] = "𝔄",
    ["fr B"] = "𝔅",
    ["fr C"] = "ℭ",
    ["fr D"] = "𝔇",
    ["fr E"] = "𝔈",
    ["fr F"] = "𝔉",
    ["fr G"] = "𝔊",
    ["fr H"] = "ℌ",
    ["fr I"] = "ℑ",
    ["fr J"] = "𝔍",
    ["fr K"] = "𝔎",
    ["fr L"] = "𝔏",
    ["fr M"] = "𝔐",
    ["fr N"] = "𝔑",
    ["fr O"] = "𝔒",
    ["fr P"] = "𝔓",
    ["fr Q"] = "𝔔",
    ["fr R"] = "ℜ",
    ["fr S"] = "𝔖",
    ["fr T"] = "𝔗",
    ["fr U"] = "𝔘",
    ["fr V"] = "𝔙",
    ["fr W"] = "𝔚",
    ["fr X"] = "𝔛",
    ["fr Y"] = "𝔜",
    ["fr Z"] = "ℨ",

    -- script

    ["cc a"] = "𝒶",
    ["cc b"] = "𝒷",
    ["cc c"] = "𝒸",
    ["cc d"] = "𝒹",
    ["cc e"] = "ℯ",
    ["cc f"] = "𝒻",
    ["cc g"] = "ℊ",
    ["cc h"] = "𝒽",
    ["cc i"] = "𝒾",
    ["cc j"] = "𝒿",
    ["cc k"] = "𝓀",
    ["cc l"] = "𝓁",
    ["cc m"] = "𝓂",
    ["cc n"] = "𝓃",
    ["cc o"] = "ℴ",
    ["cc p"] = "𝓅",
    ["cc q"] = "𝓆",
    ["cc r"] = "𝓇",
    ["cc s"] = "𝓈",
    ["cc t"] = "𝓉",
    ["cc u"] = "𝓊",
    ["cc v"] = "𝓋",
    ["cc w"] = "𝓌",
    ["cc x"] = "𝓍",
    ["cc y"] = "𝓎",
    ["cc z"] = "𝓏",

    ["cc A"] = "𝒜",
    ["cc B"] = "ℬ",
    ["cc C"] = "𝒞",
    ["cc D"] = "𝒟",
    ["cc E"] = "ℰ",
    ["cc F"] = "ℱ",
    ["cc G"] = "𝒢",
    ["cc H"] = "ℋ",
    ["cc I"] = "ℐ",
    ["cc J"] = "𝒥",
    ["cc K"] = "𝒦",
    ["cc L"] = "ℒ",
    ["cc M"] = "ℳ",
    ["cc N"] = "𝒩",
    ["cc O"] = "𝒪",
    ["cc P"] = "𝒫",
    ["cc Q"] = "𝒬",
    ["cc R"] = "ℛ",
    ["cc S"] = "𝒮",
    ["cc T"] = "𝒯",
    ["cc U"] = "𝒰",
    ["cc V"] = "𝒱",
    ["cc W"] = "𝒲",
    ["cc X"] = "𝒳",
    ["cc Y"] = "𝒴",
    ["cc Z"] = "𝒵",

    -- bold

    ["bb a"] = "𝒂",
    ["bb b"] = "𝒃",
    ["bb c"] = "𝒄",
    ["bb d"] = "𝒅",
    ["bb e"] = "𝒆",
    ["bb f"] = "𝒇",
    ["bb g"] = "𝒈",
    ["bb h"] = "𝒉",
    ["bb i"] = "𝒊",
    ["bb j"] = "𝒋",
    ["bb k"] = "𝒌",
    ["bb l"] = "𝒍",
    ["bb m"] = "𝒎",
    ["bb n"] = "𝒏",
    ["bb o"] = "𝒐",
    ["bb p"] = "𝒑",
    ["bb q"] = "𝒒",
    ["bb r"] = "𝒓",
    ["bb s"] = "𝒔",
    ["bb t"] = "𝒕",
    ["bb u"] = "𝒖",
    ["bb v"] = "𝒗",
    ["bb w"] = "𝒘",
    ["bb x"] = "𝒙",
    ["bb y"] = "𝒚",
    ["bb z"] = "𝒛",

    ["bb A"] = "𝑨",
    ["bb B"] = "𝑩",
    ["bb C"] = "𝑪",
    ["bb D"] = "𝑫",
    ["bb E"] = "𝑬",
    ["bb F"] = "𝑭",
    ["bb G"] = "𝑮",
    ["bb H"] = "𝑯",
    ["bb I"] = "𝑰",
    ["bb J"] = "𝑱",
    ["bb K"] = "𝑲",
    ["bb L"] = "𝑳",
    ["bb M"] = "𝑴",
    ["bb N"] = "𝑵",
    ["bb O"] = "𝑶",
    ["bb P"] = "𝑷",
    ["bb Q"] = "𝑸",
    ["bb R"] = "𝑹",
    ["bb S"] = "𝑺",
    ["bb T"] = "𝑻",
    ["bb U"] = "𝑼",
    ["bb V"] = "𝑽",
    ["bb W"] = "𝑾",
    ["bb X"] = "𝑿",
    ["bb Y"] = "𝒀",
    ["bb Z"] = "𝒁",

    -- sans

    ["sf a"] = "𝖺",
    ["sf b"] = "𝖻",
    ["sf c"] = "𝖼",
    ["sf d"] = "𝖽",
    ["sf e"] = "𝖾",
    ["sf f"] = "𝖿",
    ["sf g"] = "𝗀",
    ["sf h"] = "𝗁",
    ["sf i"] = "𝗂",
    ["sf j"] = "𝗃",
    ["sf k"] = "𝗄",
    ["sf l"] = "𝗅",
    ["sf m"] = "𝗆",
    ["sf n"] = "𝗇",
    ["sf o"] = "𝗈",
    ["sf p"] = "𝗉",
    ["sf q"] = "𝗊",
    ["sf r"] = "𝗋",
    ["sf s"] = "𝗌",
    ["sf t"] = "𝗍",
    ["sf u"] = "𝗎",
    ["sf v"] = "𝗏",
    ["sf w"] = "𝗐",
    ["sf x"] = "𝗑",
    ["sf y"] = "𝗒",
    ["sf z"] = "𝗓",

    ["sf A"] = "𝖠",
    ["sf B"] = "𝖡",
    ["sf C"] = "𝖢",
    ["sf D"] = "𝖣",
    ["sf E"] = "𝖤",
    ["sf F"] = "𝖥",
    ["sf G"] = "𝖦",
    ["sf H"] = "𝖧",
    ["sf I"] = "𝖨",
    ["sf J"] = "𝖩",
    ["sf K"] = "𝖪",
    ["sf L"] = "𝖫",
    ["sf M"] = "𝖬",
    ["sf N"] = "𝖭",
    ["sf O"] = "𝖮",
    ["sf P"] = "𝖯",
    ["sf Q"] = "𝖰",
    ["sf R"] = "𝖱",
    ["sf S"] = "𝖲",
    ["sf T"] = "𝖳",
    ["sf U"] = "𝖴",
    ["sf V"] = "𝖵",
    ["sf W"] = "𝖶",
    ["sf X"] = "𝖷",
    ["sf Y"] = "𝖸",
    ["sf Z"] = "𝖹",

    -- monospace

    ["tt a"] = "𝚊",
    ["tt b"] = "𝚋",
    ["tt c"] = "𝚌",
    ["tt d"] = "𝚍",
    ["tt e"] = "𝚎",
    ["tt f"] = "𝚏",
    ["tt g"] = "𝚐",
    ["tt h"] = "𝚑",
    ["tt i"] = "𝚒",
    ["tt j"] = "𝚓",
    ["tt k"] = "𝚔",
    ["tt l"] = "𝚕",
    ["tt m"] = "𝚖",
    ["tt n"] = "𝚗",
    ["tt o"] = "𝚘",
    ["tt p"] = "𝚙",
    ["tt q"] = "𝚚",
    ["tt r"] = "𝚛",
    ["tt s"] = "𝚜",
    ["tt t"] = "𝚝",
    ["tt u"] = "𝚞",
    ["tt v"] = "𝚟",
    ["tt w"] = "𝚠",
    ["tt x"] = "𝚡",
    ["tt y"] = "𝚢",
    ["tt z"] = "𝚣",

    ["tt A"] = "𝙰",
    ["tt B"] = "𝙱",
    ["tt C"] = "𝙲",
    ["tt D"] = "𝙳",
    ["tt E"] = "𝙴",
    ["tt F"] = "𝙵",
    ["tt G"] = "𝙶",
    ["tt H"] = "𝙷",
    ["tt I"] = "𝙸",
    ["tt J"] = "𝙹",
    ["tt K"] = "𝙺",
    ["tt L"] = "𝙻",
    ["tt M"] = "𝙼",
    ["tt N"] = "𝙽",
    ["tt O"] = "𝙾",
    ["tt P"] = "𝙿",
    ["tt Q"] = "𝚀",
    ["tt R"] = "𝚁",
    ["tt S"] = "𝚂",
    ["tt T"] = "𝚃",
    ["tt U"] = "𝚄",
    ["tt V"] = "𝚅",
    ["tt W"] = "𝚆",
    ["tt X"] = "𝚇",
    ["tt Y"] = "𝚈",
    ["tt Z"] = "𝚉",

    -- some more undocumented

    ["dx"]     = { "d", "x" }, -- "{dx}" "\\left(dx\\right)"
    ["dy"]     = { "d", "y" }, -- "{dy}" "\\left(dy\\right)"
    ["dz"]     = { "d", "z" }, -- "{dz}" "\\left(dz\\right)"

    ["atan"]   = "\\atan",
    ["acos"]   = "\\acos",
    ["asin"]   = "\\asin",

    ["arctan"] = "\\arctan",
    ["arccos"] = "\\arccos",
    ["arcsin"] = "\\arcsin",

    ["prime"]  = "′",
    ["'"]      = "′",
    ["''"]     = "″",
    ["'''"]    = "‴",
}

local isbinary = {
    ["\\frac"]        = true,
    ["\\root"]        = true,
    ["\\rootradical"] = true,
    ["\\stackrel"]    = true,
}

local isunary = {
    ["\\sqrt"]           = true,
    ["\\rootradical{}"]  = true,
 -- ["\\bb"]             = true,
    ["\\text"]           = true, --  mathoptext
    ["\\mathoptext"]     = true, --  mathoptext
    ["\\hat"]            = true, --  widehat
    ["\\widehat"]        = true, --  widehat
    ["\\overbar"]        = true, --
    ["\\underline"]      = true, --
    ["\\vec"]            = true, --  overrightarrow
    ["\\overrightarrow"] = true, --  overrightarrow
    ["\\dot"]            = true, --
    ["\\ddot"]           = true, --

    ["^"]                = true,
    ["_"]                = true,

}

-- local isinfix = {
--     ["\\slash"] = true
-- }

local isleft = {
    ["\\left\\lparent"]  = true,
    ["\\left\\lbrace"]   = true,
    ["\\left\\lbracket"] = true,
}
local isright = {
    ["\\right\\rparent"]  = true,
    ["\\right\\rbrace"]   = true,
    ["\\right\\rbracket"] = true,
}

local issimplified = {
}

local p_number_base = patterns.cpnumber or patterns.cnumber or patterns.number
local p_number      = C(p_number_base)
local p_spaces      = patterns.whitespace

----- p_number = Cs((patterns.cpnumber or patterns.cnumber or patterns.number)/function(s) return (gsub(s,",","{,}")) end)

local sign    = P("-")^-1
local digits  = R("09")^1
local integer = sign * digits
----- real    = sign * digits * (S(".,") * digits)^-1
local real    = digits * (S(".,") * digits)^-1
local float   = real * (P("E") * integer)^-1

-- local number  = C(float + integer)
local p_number  = C(float)

local p_open   = S("{[") * P(":")
local p_close  = P(":") * S("]}")

local p_utf_base =
    patterns.utf8character
local p_utf =
    C(p_utf_base)

local p_entity_base =
    P("&") * ((1-P(";"))^2) * P(";")
local p_entity =
    P("&") * (((1-P(";"))^2) / entities) * P(";")

-- This is (given the large match):
--
-- local s = sortedkeys(reserved)
-- local p = P(false)
-- for i=#s,1,-1 do
--     local k = s[i]
--     p = p + P(k)
-- end
-- local p_reserved = p / reserved
--
-- twice as slow as:

local k_reserved = sortedkeys(reserved)

asciimath.keys = {
    reserved = k_reserved
}

local k_reserved_different = { }
local k_reserved_words     = { }

for k, v in sortedhash(reserved) do
    if k ~= v then
        k_reserved_different[#k_reserved_different+1] = k
    end
    if not find(k,"[^a-zA-Z]") then
        k_reserved_words[#k_reserved_words+1] = k
    end
end

local p_reserved =
    lpeg.utfchartabletopattern(k_reserved_different) / reserved

-- local p_text =
--     P("text")
--   * p_spaces^0
--   * Cc("\\mathoptext")
--   * ( -- maybe balanced
--         Cs((P("{")    ) * (1-P("}"))^0 *  P("}")     )
--       + Cs((P("(")/"{") * (1-P(")"))^0 * (P(")")/"}"))
--     )
--   + Cc("\\mathoptext") * Cs(Cc("{") * patterns.undouble * Cc("}"))

local p_text =
    P("text")
  * p_spaces^0
  * Cc("\\mathoptext")
  * ( -- maybe balanced
        Cs( P("{")      * (1-P("}"))^0 *  P("}")     )
      + Cs((P("(")/"{") * (1-P(")"))^0 * (P(")")/"}"))
    )
  + Cc("\\mathoptext") * Cs(Cc("{") * patterns.undouble * Cc("}"))

-- either map to \left<utf> or map to \left\name

local p_left   =
    P("(:") / "\\left\\langle"
  + P("(")  / "\\left\\lparent"
  + P("[")  / "\\left\\lbracket"
  + P("{")  / "\\left\\lbrace"
  + P("<<") / "\\left\\langle"     -- why not <:
  + P("|_") / "\\left\\lfloor"
  + P("|~") / "\\left\\lceil"

  + P("⟨")  / "\\left\\langle"

local p_right  =
    P(")")  / "\\right\\rparent"
  + P(":)") / "\\right\\rangle"
  + P("]")  / "\\right\\rbracket"
  + P("}")  / "\\right\\rbrace"
  + P(">>") / "\\right\\rangle"    -- why not :>
  + P("~|") / "\\right\\rceil"
  + P("_|") / "\\right\\rfloor"

  + P("⟩")  / "\\right\\rangle"

-- special cases

-- local p_special =
--     C("/")
--   + P("\\ ")  * Cc("{}") * p_spaces^0 * C(S("^_"))
--   + P("\\ ")  * Cc("\\space")
--   + P("\\\\") * Cc("\\backslash")
--   + P("\\")   * (R("az","AZ")^1/entities)
--   + P("|")    * Cc("\\|") -- "\\middle\\|" -- maybe always add left / right as in mml ?
--
-- faster bug also uglier:

local p_special =
    C("/")
  + P("|")    * Cc("\\|") -- "\\middle\\|" -- maybe always add left / right as in mml ?
  + P("\\") * (
        (
            P(" ") * (
                  Cc("{}") * p_spaces^0 * C(S("^_"))
                + Cc("\\space")
            )
        )
      + P("\\") * Cc("\\backslash")
      + (R("az","AZ")^1/entities)
    )

local parser = Ct { "tokenizer",
    tokenizer = (
        p_spaces
      + p_number
      + p_text
      + Ct(p_open * V("tokenizer") * p_close)
      + Ct(p_left * V("tokenizer") * p_right)
      + p_special
      + p_reserved
      + p_entity
      + p_utf - p_close - p_right
    )^1,
}

local function show_state(state,level,t)
    state = state + 1
    report_asciimath(table.serialize(t,formatters["stage %s:%s"](level,state)))
    return state
end

local function show_result(str,result)
    report_asciimath("input  > %s",str)
    report_asciimath("result > %s",result)
end

local function collapse(t,level)
    if not t then
        return ""
    end
    local state = 0
    if trace_detail then
        if level then
            level = level + 1
        else
            level = 1
        end
        state = show_state(state,level,t)
    end
    --
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
                        t[1] = l1 .. "\\startmatrix"
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
                        t[n] = "\\NR\\stopmatrix" .. r1
                    end
                end
            end
        end
    end
    --
    if trace_detail then
        state = show_state(state,level,t)
    end
    --
    local n = #t
    local i = 1
    while i < n do
        local current = t[i]
        if current == "/" and i > 1 then
            local tl = t[i-1]
            local tr = t[i+1]
            if type(tl) == "table" then
                if isleft[tl[1]] and isright[tl[#tl]] then
                    tl[1]   = "" -- todo: remove
                    tl[#tl] = nil
                end
            end
            if type(tr) == "table" then
                if isleft[tr[1]] and isright[tr[#tr]] then
                    tr[1]   = "" -- todo: remove
                    tr[#tr] = nil
                end
            end
            i = i + 2
        elseif current == "," or current == ";" then
            t[i] = current .. "\\thinspace"
            i = i + 1
        else
            i = i + 1
        end
    end
    --
    if trace_detail then
        state = show_state(state,level,t)
    end
    --
    local n = #t
    local i = 1
    if n > 2 then
        while i < n do
            local current = t[i]
            if type(current) == "table" and isleft[t[i-1]] and isright[t[i+1]] then
                local c = #current
                if c > 2 and isleft[current[1]] and isright[current[c]] then
                    current[1] = ""
                    current[c] = nil
                end
                i = i + 3
            else
                i = i + 1
            end
        end
    end
    --
    if trace_detail then
        state = show_state(state,level,t)
    end
    --
    local n = #t
    local i = 1
    local m = 0
    while i <= n do
        m = m + 1
        local current = t[i]
        if isbinary[current] then
            local one = t[i+1]
            local two = t[i+2]
            if not one then
                t[m] = current .. "{}{}" -- error
                break
            end
            if type(one) == "table" then
                if isleft[one[1]] and isright[one[#one]] then
                    one[1]   = ""
                    one[#one] = nil
                end
                one = collapse(one,level)
            end
            if not two then
                t[m] = current .. "{" .. one .. "}{}"
                break
            end
            if type(two) == "table" then
                if isleft[two[1]] and isright[two[#two]] then
                    two[1]   = ""
                    two[#two] = nil
                end
                two = collapse(two,level)
            end
            t[m] = current .. "{" .. one .. "}{" .. two .. "}"
            i = i + 3
        elseif isunary[current] then
            local one = t[i+1]
            if not one then
                m = m + 1
                t[m] = current .. "{}" -- error
                break
            end
            if type(one) == "table" then
                if isleft[one[1]] and isright[one[#one]] then
                    one[1]   = ""
                    one[#one] = nil
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
        elseif type(current) == "table" then
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
    --
    if trace_detail then
        state = show_state(state,level,t)
    end
    --
    local n = #t
    local m = 0
    local i = 1
    while i < n do
        local current = t[i]
        if current == "/" and i > 1 then
            local tl = t[i-1]
            local tr = t[i+1]
         -- if type(tl) == "table" then
         --     if isleft[tl[1]] and isright[tl[#tl]] then
         --         tl[1]   = ""
         --         tl[#tl] = ""
         --     end
         -- end
         -- if type(tr) == "table" then
         --     if isleft[tr[1]] and isright[tr[#tr]] then
         --         tr[1]   = ""
         --         tr[#tr] = ""
         --     end
         -- end
            t[m] = "\\frac{" .. tl .. "}{" .. tr .. "}"
            i = i + 2
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
    --
    if trace_detail then
        state = show_state(state,level,t)
    end
    --
    local n = #t
    local m = 0
    local i = 1
    while i < n do
        local current = t[i]
        if current == "\\slash" and i > 1 then
            t[m] = "{\\left(" .. t[i-1] .. "\\middle/" .. t[i+1] .. "\\right)}"
            i = i + 2
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
    --
    if trace_detail then
        state = show_state(state,level,t)
    end
    --
    local result = concat(t," ")
    --
    return result
end

-- todo: cache simple ones, say #str < 10, maybe weak

local ctx_mathematics = context and context.mathematics or report_asciimath
local ctx_type        = context and context.type        or function() end
local ctx_inleft      = context and context.inleft      or function() end

local function convert(str,totex)
    local texcode = collapse(lpegmatch(parser,str))
    if trace_mapping then
        show_result(str,texcode)
    end
    if totex then
        ctx_mathematics(texcode)
    else
        return texcode
    end
end

local n = 0
local p = (
    (S("{[(") + P("\\left" )) / function() n = n + 1 end
  + (S("}])") + P("\\right")) / function() n = n - 1 end
  + P(1)
)^0

local function invalidtex(str)
    n = 0
    local result = lpegmatch(p,str)
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

local p_expand   = Cs((p_text + p_reserved_spaced + p_entity_base + p_utf_base)^0)
local p_compress = patterns.collapser

local function cleanedup(str)
    return lpegmatch(p_compress,lpegmatch(p_expand,str)) or str
end

-- so far

function collect(fpattern,element,collected,indexed)
    local element   = element or "am"
    local mpattern  = formatters["<%s>(.-)</%s>"](element,element)
    local filenames = dir.glob(fpattern)
    local wildcard  = string.split(fpattern,"*")[1]
    if not collected then
        collected = { }
        indexed   = { }
    end
    for i=1,#filenames do
        filename = filenames[i]
        local splitname = string.split(filename,wildcard)
        local shortname  = temp and temp[2] or file.basename(filename)
        for s in gmatch(io.loaddata(filename),mpattern) do
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
                local texcode = convert(s)
                local message = invalidtex(texcode)
                if message then
                    report_asciimath("%s: %s",message,s)
                end
                collected[c] = {
                    count     = 1,
                    files     = { [shortname] = 1 },
                    texcode   = texcode,
                    message   = message,
                    cleanedup = s ~= c and 1 or 0,
                    dirty     = { [s] = 1 }
                }
            end
        end
    end
    local n = 0
    for k, v in sortedhash(collected) do
        n = n + 1
        v.n= n
        indexed[n] = k
    end
    return collected, indexed
end

asciimath.convert    = convert
asciimath.reserved   = reserved
asciimath.collect    = collect
asciimath.invalidtex = invalidtex
asciimath.cleanedup  = cleanedup

-- sin(x) = 1 : 3.3 uncached 1.2 cached , so no real gain (better optimize the converter then)

local function convert(str)
    if #str == 1 then
        ctx_mathematics(str)
    else
        local texcode = collapse(lpegmatch(parser,str))
        if trace_mapping then
            show_result(str,texcode)
        end
        if #texcode == 0 then
            report_asciimath("error in asciimath: %s",str)
        else
            local message = invalidtex(texcode)
            if message then
                report_asciimath("%s: %s",message,str)
                ctx_type(formatters["<%s>"](message))
            else
                ctx_mathematics(texcode)
            end
        end
    end
end

commands.asciimath = convert

if not context then

--     trace_mapping = true
--     trace_detail  = true

    report_asciimath(cleanedup([[ac+sinx+xsqrtx+sinsqrtx+sinsqrt(x)]]))
    report_asciimath(cleanedup([[a "αsinsqrtx" b]]))
    report_asciimath(cleanedup([[a "α" b]]))

    convert([[ac+sinx+xsqrtx]])
    convert([[ac+\alpha x+xsqrtx-cc b*pi**psi-3alephx / bb X]])
    convert([[ac+\ ^ x+xsqrtx]])
    convert([[d/dx(x^2+1)]])
    convert([[a "αsinsqrtx" b]])
    convert([[a "α" b]])

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

local context         = context

local ctx_typebuffer  = context.typebuffer
local ctx_mathematics = context.mathematics
local ctx_color       = context.color

local sequenced       = table.sequenced
local assign_buffer   = buffers.assign

asciimath.show = { }

local collected, indexed, ignored = { }, { }, { }

local color = { "darkred" }

function asciimath.show.ignore(n)
    if type(n) == "string" then
        local c = collected[n]
        n = c and c.n
    end
    if n then
        ignored[n] = true
    end
end

function asciimath.show.count(n,showcleanedup)
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

local h = { }

function asciimath.show.nofdirty(n)
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

function asciimath.show.dirty(m,wrapped)
    local d = h[m]
    if d then
        ctx_inleft(d[2])
        if wrapped then
            assign_buffer("am",'"' .. d[1] .. '"')
        else
            assign_buffer("am",d[1])
        end
        ctx_typebuffer { "am" }
    end
end

function asciimath.show.files(n)
    context(sequenced(collected[indexed[n]].files," "))
end

function asciimath.show.input(n,wrapped)
    if wrapped then
        assign_buffer("am",'"' .. indexed[n] .. '"')
    else
        assign_buffer("am",indexed[n])
    end
    ctx_typebuffer { "am" }
end

function asciimath.show.result(n)
    local v = collected[indexed[n]]
    if ignored[n] then
        context("ignored")
    elseif v.message then
        ctx_color(color, v.message)
    else
        ctx_mathematics(v.texcode)
    end
end

function asciimath.show.load(str,element)
    collected, indexed, ignored = { }, { }, { }
    local t = utilities.parsers.settings_to_array(str)
    for i=1,#t do
        asciimath.collect(t[i],element or "am",collected,indexed)
    end
end

function asciimath.show.max()
    context(#indexed)
end

function asciimath.show.statistics()
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
    context.starttabulate { "|B||" }
        context.NC() context("files")     context.EQ() context(noffiles)       context.NC() context.NR()
        context.NC() context("formulas")  context.EQ() context(nofokay+nofbad) context.NC() context.NR()
        context.NC() context("uniques")   context.EQ() context(#indexed)       context.NC() context.NR()
        context.NC() context("cleanedup") context.EQ() context(nofcleanedup)   context.NC() context.NR()
        context.NC() context("errors")    context.EQ() context(nofbad)         context.NC() context.NR()
    context.stoptabulate()
end

function asciimath.show.save(name)
    table.save(name ~= "" and name or "dummy.lua",collected)
end

-- maybe:

-- \backslash \
-- \times     ×
-- \divide    ÷
-- \circ      ∘
-- \oplus     ⊕
-- \otimes    ⊗
-- \sum       ∑
-- \prod      ∏
-- \wedge     ∧
-- \bigwedge  ⋀
-- \vee       ∨
-- \bigvee    ⋁
-- \cup       ∪
-- \bigcup    ⋃
-- \cap       ∩
-- \bigcap    ⋂

-- \ne        ≠
-- \le        ≤
-- \leq       ≤
-- \ge        ≥
-- \geq       ≥
-- \prec      ≺
-- \succ      ≻
-- \in        ∈
-- \notin     ∉
-- \subset    ⊂
-- \supset    ⊃
-- \subseteq  ⊆
-- \supseteq  ⊇
-- \equiv     ≡
-- \cong      ≅
-- \approx    ≈
-- \propto    ∝
--
-- \neg       ¬
-- \implies   ⇒
-- \iff       ⇔
-- \forall    ∀
-- \exists    ∃
-- \bot       ⊥
-- \top       ⊤
-- \vdash     ⊢
-- \models    ⊨
--
-- \int       ∫
-- \oint      ∮
-- \partial   ∂
-- \nabla     ∇
-- \pm        ±
-- \emptyset  ∅
-- \infty     ∞
-- \aleph     ℵ
-- \ldots     ...
-- \cdots     ⋯
-- \quad
-- \diamond   ⋄
-- \square    □
-- \lfloor    ⌊
-- \rfloor    ⌋
-- \lceiling  ⌈
-- \rceiling  ⌉
--
-- \sin       sin
-- \cos       cos
-- \tan       tan
-- \csc       csc
-- \sec       sec
-- \cot       cot
-- \sinh      sinh
-- \cosh      cosh
-- \tanh      tanh
-- \log       log
-- \ln        ln
-- \det       det
-- \dim       dim
-- \lim       lim
-- \mod       mod
-- \gcd       gcd
-- \lcm       lcm
--
-- \uparrow        ↑
-- \downarrow      ↓
-- \rightarrow     →
-- \to             →
-- \leftarrow      ←
-- \leftrightarrow ↔
-- \Rightarrow     ⇒
-- \Leftarrow      ⇐
-- \Leftrightarrow ⇔
--
-- \mathbf
-- \mathbb
-- \mathcal
-- \mathtt
-- \mathfrak
