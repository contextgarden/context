if not modules then modules = { } end modules ['x-mathml'] = {
    version   = 1.001,
    comment   = "companion to x-mathml.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This needs an upgrade to the latest greatest mechanisms. But ... it
-- probably doesn't pay back as no mathml support ever did.

local type, next = type, next
local formatters, lower, find, gsub, match = string.formatters, string.lower, string.find, string.gsub, string.match
local strip = string.strip
local xmlsprint, xmlcprint, xmltext, xmlcontent, xmlempty = xml.sprint, xml.cprint, xml.text, xml.content, xml.empty
local lxmlcollected, lxmlfilter = lxml.collected, lxml.filter
local getid = lxml.getid
local utfchar, utfcharacters, utfvalues, utfsplit, utflen = utf.char, utf.characters, utf.values, utf.split, utf.len
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local P, Cs = lpeg.P, lpeg.Cs

local mathml      = { }
moduledata.mathml = mathml
lxml.mathml       = mathml -- for the moment

local context = context

local ctx_enabledelimiter      = context.enabledelimiter
local ctx_disabledelimiter     = context.disabledelimiter
local ctx_xmlflush             = context.xmlflush -- better xmlsprint

local ctx_halign               = context.halign
local ctx_noalign              = context.noalign
local ctx_bgroup               = context.bgroup
local ctx_egroup               = context.egroup
local ctx_crcr                 = context.crcr

local ctx_bTABLE               = context.bTABLE
local ctx_eTABLE               = context.eTABLE
local ctx_bTR                  = context.bTR
local ctx_eTR                  = context.eTR
local ctx_bTD                  = context.bTD
local ctx_eTD                  = context.eTD

local ctx_mn                   = context.mn
local ctx_mi                   = context.mi
local ctx_mo                   = context.mo
local ctx_startimath           = context.startimath
local ctx_ignorespaces         = context.ignorespaces
local ctx_removeunwantedspaces = context.removeunwantedspaces
local ctx_stopimath            = context.stopimath

local ctx_mmlapplycsymbol      = context.mmlapplycsymbol

local ctx_mathopnolimits       = context.mathopnolimits
local ctx_left                 = context.left
local ctx_right                = context.right

-- an alternative is to remap to private codes, where we can have
-- different properties .. to be done; this will move and become
-- generic; we can then make the private ones active in math mode

-- todo: handle opening/closing mo's here ... presentation mml is such a mess ...

-- characters.registerentities()

local doublebar = utfchar(0x2016)

local n_replacements = {
--  [" "]              = utfchar(0x2002),  -- "&textspace;" -> tricky, no &; in mkiv
    ["."]              = "{.}",
    [","]              = "{,}",
    [" "]              = "",
}

local l_replacements = { -- in main table
    ["|"]              = "\\mmlleftdelimiter\\vert",
    ["{"]              = "\\mmlleftdelimiter\\lbrace",
    ["("]              = "\\mmlleftdelimiter(",
    ["["]              = "\\mmlleftdelimiter[",
    ["<"]              = "\\mmlleftdelimiter<",
    [doublebar]        = "\\mmlleftdelimiter\\Vert",
}
local r_replacements = { -- in main table
    ["|"]              = "\\mmlrightdelimiter\\vert",
    ["}"]              = "\\mmlrightdelimiter\\rbrace",
    [")"]              = "\\mmlrightdelimiter)",
    ["]"]              = "\\mmlrightdelimiter]",
    [">"]              = "\\mmlrightdelimiter>",
    [doublebar]        = "\\mmlrightdelimiter\\Vert",
}

-- todo: play with asciimode and avoid mmlchar

-- we can use the proper names now! todo

local o_replacements = { -- in main table
    ["@l"]             = "\\mmlleftdelimiter.",
    ["@r"]             = "\\mmlrightdelimiter.",
    ["{"]              = "\\mmlleftdelimiter \\lbrace",
    ["}"]              = "\\mmlrightdelimiter\\rbrace",
    ["|"]              = "\\mmlleftorrightdelimiter\\vert",
 -- ["."]              = "\\mmlleftorrightdelimiter.",
    ["/"]              = "\\mmlleftorrightdelimiter\\solidus",
    [doublebar]        = "\\mmlleftorrightdelimiter\\Vert",
    ["("]              = "\\mmlleftdelimiter(",
    [")"]              = "\\mmlrightdelimiter)",
    ["["]              = "\\mmlleftdelimiter[",
    ["]"]              = "\\mmlrightdelimiter]",
 -- ["<"]              = "\\mmlleftdelimiter<",
 -- [">"]              = "\\mmlrightdelimiter>",
    ["#"]              = "\\mmlchar{35}",
    ["$"]              = "\\mmlchar{36}", -- $
    ["%"]              = "\\mmlchar{37}",
    ["&"]              = "\\mmlchar{38}",
    ["^"]              = "\\mmlchar{94}{}", -- strange, sometimes luatex math sees the char instead of \char so we
    ["_"]              = "\\mmlchar{95}{}", -- need the {} ... has to do with active mess feedback into scanner
    ["~"]              = "\\mmlchar{126}",
    [" "]              = "",
    ["°"]              = "^\\circ", -- hack

 -- [utfchar(0xF103C)] = "\\mmlleftdelimiter<",
    [utfchar(0xF1026)] = "\\mmlchar{38}",
    [utfchar(0x02061)]  = "", -- function applicator sometimes shows up in font
 -- [utfchar(0xF103E)] = "\\mmlleftdelimiter>",
 -- [utfchar(0x000AF)] = '\\mmlchar{"203E}', -- 0x203E
}

local simpleoperatorremapper = utf.remapper(o_replacements)

--~ languages.data.labels.functions

local i_replacements = {
    ["sin"]         = "\\sin",
    ["cos"]         = "\\cos",
    ["abs"]         = "\\abs",
    ["arg"]         = "\\arg",
    ["codomain"]    = "\\codomain",
    ["curl"]        = "\\curl",
    ["determinant"] = "\\det",
    ["divergence"]  = "\\div",
    ["domain"]      = "\\domain",
    ["gcd"]         = "\\gcd",
    ["grad"]        = "\\grad",
    ["identity"]    = "\\id",
    ["image"]       = "\\image",
    ["lcm"]         = "\\lcm",
    ["lim"]         = "\\lim",
    ["max"]         = "\\max",
    ["median"]      = "\\median",
    ["min"]         = "\\min",
    ["mode"]        = "\\mode",
    ["mod"]         = "\\mod",
    ["polar"]       = "\\Polar",
    ["exp"]         = "\\exp",
    ["ln"]          = "\\ln",
    ["log"]         = "\\log",
    ["sin"]         = "\\sin",
    ["arcsin"]      = "\\arcsin",
    ["sinh"]        = "\\sinh",
    ["arcsinh"]     = "\\arcsinh",
    ["cos"]         = "\\cos",
    ["arccos"]      = "\\arccos",
    ["cosh"]        = "\\cosh",
    ["arccosh"]     = "\\arccosh",
    ["tan"]         = "\\tan",
    ["arctan"]      = "\\arctan",
    ["tanh"]        = "\\tanh",
    ["arctanh"]     = "\\arctanh",
    ["cot"]         = "\\cot",
    ["arccot"]      = "\\arccot",
    ["coth"]        = "\\coth",
    ["arccoth"]     = "\\arccoth",
    ["csc"]         = "\\csc",
    ["arccsc"]      = "\\arccsc",
    ["csch"]        = "\\csch",
    ["arccsch"]     = "\\arccsch",
    ["sec"]         = "\\sec",
    ["arcsec"]      = "\\arcsec",
    ["sech"]        = "\\sech",
    ["arcsech"]     = "\\arcsech",
    [" "]           = "",

    ["false"]       = "{\\mathrm false}",
    ["notanumber"]  = "{\\mathrm NaN}",
    ["otherwise"]   = "{\\mathrm otherwise}",
    ["true"]        = "{\\mathrm true}",
    ["declare"]     = "{\\mathrm declare}",
    ["as"]          = "{\\mathrm as}",

}

-- we could use a metatable or when accessing fallback on the
-- key but at least we now have an overview

local csymbols = {
    arith1 = {
        lcm                 = "lcm",
        big_lcm             = "lcm",
        gcd                 = "gcd",
        big_gcd             = "big_gcd",
        plus                = "plus",
        unary_minus         = "minus",
        minus               = "minus",
        times               = "times",
        divide              = "divide",
        power               = "power",
        abs                 = "abs",
        root                = "root",
        sum                 = "sum",
        product             = "product",
    },
    fns = {
        domain              = "domain",
        range               = "codomain",
        image               = "image",
        identity            = "ident",
     -- left_inverse        = "",
     -- right_inverse       = "",
        inverse             = "inverse",
        left_compose        = "compose",
        lambda              = "labmda",
    },
    linalg1 = {
        vectorproduct       = "vectorproduct",
        scalarproduct       = "scalarproduct",
        outerproduct        = "outerproduct",
        transpose           = "transpose",
        determinant         = "determinant",
        vector_selector     = "selector",
     -- matrix_selector     = "matrix_selector",
    },
    logic1 = {
        equivalent          = "equivalent",
        ["not"]             = "not",
        ["and"]             = "and",
     -- big_and             = "",
        ["xor"]             = "xor",
     -- big_xor             = "",
        ["or"]              = "or",
     -- big-or              =  "",
        implies             = "implies",
        ["true"]            = "true",
        ["false"]           = "false",
    },
    nums1 = {
     -- based_integer       = "based_integer"
        rational            = "rational",
        inifinity           = "infinity",
        e                   = "expenonentiale",
        i                   = "imaginaryi",
        pi                  = "pi",
        gamma               = "gamma",
        NaN                 = "NaN",
    },
    relation1 = {
        eq                  = "eq",
        lt                  = "lt",
        gt                  = "gt",
        neq                 = "neq",
        leq                 = "leq",
        geq                 = "geq",
        approx              = "approx",
    },
    set1 = {
        cartesian_product   = "cartesianproduct",
        empty_set           = "emptyset",
        map                 = "map",
        size                = "card",
    -- suchthat             = "suchthat",
        set                 = "set",
        intersect           = "intersect",
    -- big_intersect        = "",
        union               = "union",
    -- big_union            = "",
        setdiff             = "setdiff",
        subset              = "subset",
        ["in"]              = "in",
        notin               = "notin",
        prsubset            = "prsubset",
        notsubset           = "notsubset",
        notprsubset         = "notprsubset",
    },
    veccalc1 = {
        divergence          = "divergence",
        grad                = "grad",
        curl                = "curl",
        laplacian           = "laplacian",
        Laplacian           = "laplacian",
    },
    calculus1 = {
        diff                = "diff",
     -- nthdiff             = "",
        partialdiff         = "partialdiff",
        int                 = "int",
     -- defint              = "defint",
    },
    integer1 = {
        factorof            = "factorof",
        factorial           = "factorial",
        quotient            = "quotient",
        remainder           = "rem",
    },
    linalg2 = {
        vector              = "vector",
        matrix              = "matrix",
        matrixrow           = "matrixrow",
    },
    mathmkeys = {
     -- equiv               = "",
     -- contentequiv        =  "",
     -- contentequiv_strict = "",
    },
    rounding1 = {
        ceiling             = "ceiling",
        floor               = "floor",
     -- trunc               = "trunc",
     -- round               = "round",
    },
    setname1 = {
        P                   = "primes",
        N                   = "naturalnumbers",
        Z                   = "integers",
        rationals           = "rationals",
        R                   = "reals",
        complexes           = "complexes",
    },
    complex1 = {
     -- complex_cartesian   = "complex_cartesian", -- ci ?
        real                = "real",
        imaginary           = "imaginary",
     -- complex_polar       = "complex_polar", -- ci ?
        argument            = "arg",
        conjugate           = "conjugate",
    },
    interval1 = { -- not an apply
     -- integer_interval    = "integer_interval",
        interval            = "interval",
        interval_oo         = { tag = "interval", closure = "open" },
        interval_cc         = { tag = "interval", closure = "closed" },
        interval_oc         = { tag = "interval", closure = "open-closed" },
        interval_co         = { tag = "interval", closure = "closed-open" },
    },
    linalg3 = {
     -- vector              = "vector.column",
     -- matrixcolumn        = "matrixcolumn",
     -- matrix              = "matrix.column",
    },
    minmax1 = {
        min                 = "min",
     -- big_min             = "",
        max                 = "max",
     -- big_max             = "",
    },
    piece1 = {
        piecewise           = "piecewise",
        piece               = "piece",
        otherwise           = "otherwise",
    },
    error1 = {
     -- unhandled_symbol    = "",
     -- unexpected_symbol   = "",
     -- unsupported_CD      = "",
    },
    limit1 = {
     -- limit               = "limit",
     -- both_sides          = "both_sides",
     -- above               = "above",
     -- below               = "below",
     -- null                = "null",
        tendsto             = "tendsto",
    },
    list1 = {
     -- map                 = "",
     -- suchthat            = "",
     -- list                = "list",
    },
    multiset1 = {
        size                = { tag = "card",             type = "multiset" },
        cartesian_product   = { tag = "cartesianproduct", type = "multiset" },
        empty_set           = { tag = "emptyset",         type = "multiset" },
     -- multi_set           = { tag = "multiset",         type = "multiset" },
        intersect           = { tag = "intersect",        type = "multiset" },
     -- big_intersect       = "",
        union               = { tag = "union",            type = "multiset" },
     -- big_union           = "",
        setdiff             = { tag = "setdiff",          type = "multiset" },
        subset              = { tag = "subset",           type = "multiset" },
        ["in"]              = { tag = "in",               type = "multiset" },
        notin               = { tag = "notin",            type = "multiset" },
        prsubset            = { tag = "prsubset",         type = "multiset" },
        notsubset           = { tag = "notsubset",        type = "multiset" },
        notprsubset         = { tag = "notprsubset",      type = "multiset" },
    },
    quant1 = {
        forall              = "forall",
        exists              = "exists",
    },
    s_dist = {
     -- mean                = "mean.dist",
     -- sdev                = "sdev.dist",
     -- variance            = "variance.dist",
     -- moment              = "moment.dist",
    },
    s_data = {
        mean                = "mean",
        sdev                = "sdev",
        variance            = "vriance",
        mode                = "mode",
        median              = "median",
        moment              = "moment",
    },
    transc1 = {
        log                 = "log",
        ln                  = "ln",
        exp                 = "exp",
        sin                 = "sin",
        cos                 = "cos",
        tan                 = "tan",
        sec                 = "sec",
        csc                 = "csc",
        cot                 = "cot",
        sinh                = "sinh",
        cosh                = "cosh",
        tanh                = "tanh",
        sech                = "sech",
        csch                = "cscs",
        coth                = "coth",
        arcsin              = "arcsin",
        arccos              = "arccos",
        arctan              = "arctan",
        arcsec              = "arcsec",
        arcscs              = "arccsc",
        arccot              = "arccot",
        arcsinh             = "arcsinh",
        arccosh             = "arccosh",
        arctanh             = "arstanh",
        arcsech             = "arcsech",
        arccsch             = "arccsch",
        arccoth             = "arccoth",
    },
}

function xml.functions.remapmmlcsymbol(e)
    local at = e.at
    local cd = at.cd
    if cd then
        cd = csymbols[cd]
        if cd then
            local tx = e.dt[1]
            if tx and tx ~= "" then
                local tg = cd[tx]
                if tg then
                    at.cd = nil
                    at.cdbase = nil
                    e.dt = { }
                    if type(tg) == "table" then
                        for k, v in next, tg do
                            if k == "tag" then
                                e.tg = v
                            else
                                at[k] = v
                            end
                        end
                    else
                        e.tg = tg
                    end
                end
            end
        end
    end
end

function xml.functions.remapmmlbind(e)
    e.tg = "apply"
end

function xml.functions.remapopenmath(e)
    local tg = e.tg
    if tg == "OMOBJ" then
        e.tg = "math"
    elseif tg == "OMA" then
        e.tg = "apply"
    elseif tg == "OMB" then
        e.tg = "apply"
    elseif tg == "OMS" then
        local at = e.at
        e.tg = "csymbol"
        e.dt = { at.name or "unknown" }
        at.name = nil
    elseif tg == "OMV" then
        local at = e.at
        e.tg = "ci"
        e.dt = { at.name or "unknown" }
        at.name = nil
    elseif tg == "OMI" then
        e.tg = "ci"
    end
    e.rn = "mml"
end

function mathml.checked_operator(str)
    context(simpleoperatorremapper(str))
end

function mathml.stripped(str)
    context(strip(str))
end

local p_entity  = (P("&") * ((1-P(";"))^0) * P(";"))
local p_utfchar = lpegpatterns.utf8character
local p_spacing = lpegpatterns.whitespace^1

local p_mn      =  Cs((p_entity/"" + p_spacing/utfchar(0x205F) + p_utfchar/n_replacements)^0)
local p_strip   =  Cs((p_entity/""                             + p_utfchar               )^0)
local p_mi      =  Cs((p_entity/""                             + p_utfchar/i_replacements)^0)

-- function mathml.mn(id,pattern)
--     -- maybe at some point we need to interpret the number, but
--     -- currently we assume an upright font
--     local str = xmlcontent(getid(id)) or ""
--     local rep = gsub(str,"&.-;","")
--     local rep = gsub(rep,"(%s+)",utfchar(0x205F)) -- medspace e.g.: twenty one (nbsp is not seen)
--     local rep = gsub(rep,".",n_replacements)
--     ctx_mn(rep)
-- end

function mathml.mn(id,pattern)
    -- maybe at some point we need to interpret the number, but
    -- currently we assume an upright font
    ctx_mn(lpegmatch(p_mn,xmlcontent(getid(id)) or ""))
end

-- function mathml.mo(id)
--     local str = xmlcontent(getid(id)) or ""
--     local rep = gsub(str,"&.-;","") -- todo
--     context(simpleoperatorremapper(rep) or rep)
-- end

function mathml.mo(id)
    local str = lpegmatch(p_strip,xmlcontent(getid(id)) or "")
    context(simpleoperatorremapper(str) or str)
end

function mathml.mi(id)
    -- we need to strip comments etc .. todo when reading in tree
    local e = getid(id)
    local str = e.dt
    if type(str) == "table" then
        local n = #str
        if n == 0 then
            -- nothing to do
        elseif n == 1 then
            local first = str[1]
            if type(first) == "string" then
                -- local str = gsub(first,"&.-;","") -- bah
                -- local rep = i_replacements[str]
                -- if not rep then
                --     rep = gsub(str,".",i_replacements)
                -- end
                local str = lpegmatch(p_strip,first)
                local rep = i_replacements[str] or lpegmatch(p_mi,str)
                context(rep)
             -- ctx_mi(rep)
            else
                ctx_xmlflush(id) -- xmlsprint or so
            end
        else
            ctx_xmlflush(id) -- xmlsprint or so
        end
    else
        ctx_xmlflush(id) -- xmlsprint or so
    end
end

function mathml.mfenced(id) -- multiple separators
    id = getid(id)
    local at         = id.at
    local left       = at.open       or "("
    local right      = at.close      or ")"
    local separators = at.separators or ","
    local l          = l_replacements[left]
    local r          = r_replacements[right]
    ctx_enabledelimiter()
    if l then
        context(l_replacements[left] or o_replacements[left] or "")
    else
        context(o_replacements["@l"])
        context(left)
    end
    ctx_disabledelimiter()
    local collected = lxmlfilter(id,"/*") -- check the *
    if collected then
        local n = #collected
        if n == 0 then
            -- skip
        elseif n == 1 then
            xmlsprint(collected[1]) -- to be checked
        else
            local t = utfsplit(separators,true)
            for i=1,n do
                xmlsprint(collected[i]) -- to be checked
                if i < n then
                    local m = t[i] or t[#t] or ""
                    if m == "|" then
                        m = "\\enabledelimiter\\middle|\\relax\\disabledelimiter"
                    elseif m == doublebar then
                        m = "\\enabledelimiter\\middle|\\relax\\disabledelimiter"
                    elseif m == "{" then
                        m = "\\{"
                    elseif m == "}" then
                        m = "\\}"
                    end
                    context(m)
                end
            end
        end
    end
    ctx_enabledelimiter()
    if r then
        context(r_replacements[right] or o_replacements[right] or "")
    else
        context(right)
        context(o_replacements["@r"])
    end
    ctx_disabledelimiter()
end

local function flush(e,tag,toggle)
    if tag == "none" then
     -- if not toggle then
        context("{}") -- {} starts a new ^_ set
     -- end
    elseif toggle then
        context("^{")
        xmlsprint(e.dt)
        context("}{}") -- {} starts a new ^_ set
    else
        context("_{")
        xmlsprint(e.dt)
        context("}")
    end
    return not toggle
end

function mathml.mmultiscripts(id)
    local done, toggle = false, false
    for e in lxmlcollected(id,"/*") do
        local tag = e.tg
        if tag == "mprescripts" then
            context("{}")
            done = true
        elseif done then
            toggle = flush(e,tag,toggle)
        end
    end
    local done, toggle = false, false
    for e in lxmlcollected(id,"/*") do
        local tag = e.tg
        if tag == "mprescripts" then
            break
        elseif done then
            toggle = flush(e,tag,toggle)
        else
            xmlsprint(e)
            done = true
        end
    end
end

local columnalignments = {
    left   = "flushleft",
    right  = "flushright",
    center = "middle",
}

local rowalignments = {
    top      = "high",
    bottom   = "low",
    center   = "lohi",
    baseline = "top",
    axis     = "lohi",
}

local frametypes = {
    none   = "off",
    solid  = "on",
    dashed = "on",
}

-- crazy element ... should be a proper structure instead of such a mess

function mathml.mcolumn(root)
    root = getid(root)
    local matrix, numbers = { }, 0
    local function collect(m,e)
        local tag = e.tg
        if tag == "mi" or tag == "mn" or tag == "mo" or tag == "mtext" then
            local str = xmltext(e)
            str = lpegmatch(p_strip,str)
            for s in utfcharacters(str) do
                m[#m+1] = { tag, s }
            end
            if tag == "mn" then
                local n = utflen(str)
                if n > numbers then
                    numbers = n
                end
            end
        elseif tag == "mspace" or tag == "mline" then
            local str = e.at.spacing or ""
            for s in utfcharacters(str) do
                m[#m+1] = { tag, s }
            end
     -- elseif tag == "mline" then
     --     m[#m+1] = { tag, e }
        end
    end
    for e in lxmlcollected(root,"/*") do
        local m = { }
        matrix[#matrix+1] = m
        if e.tg == "mrow" then
            -- only one level
            for e in lxmlcollected(e,"/*") do
                collect(m,e)
            end
        else
            collect(m,e)
        end
    end
    ctx_halign()
    ctx_bgroup()
    context([[\hss\startimath\alignmark\stopimath\aligntab\startimath\alignmark\stopimath\cr]])
    for i=1,#matrix do
        local m = matrix[i]
        local mline = true
        for j=1,#m do
            if m[j][1] ~= "mline" then
                mline = false
                break
            end
        end
        if mline then
            ctx_noalign([[\obeydepth\nointerlineskip]])
        end
        for j=1,#m do
            local mm = m[j]
            local tag, chr = mm[1], mm[2]
            if tag == "mline" then
                -- This code is under construction ... I need some real motivation
                -- to deal with this kind of crap.
--~                 local n, p = true, true
--~                 for c=1,#matrix do
--~                     local mc = matrix[c][j]
--~                     if mc then
--~                         mc = mc[2]
--~                         if type(mc) ~= "string" then
--~                             n, p = false, false
--~                             break
--~                         elseif find(mc,"^[%d ]$") then -- rangecheck is faster
--~                             -- digit
--~                         elseif not find(mc,"^[%.%,]$") then -- rangecheck is faster
--~                             -- punctuation
--~                         else
--~                             n = false
--~                             break
--~                         end
--~                     end
--~                 end
--~                 if n then
--~                     chr = "\\mmlmcolumndigitrule"
--~                 elseif p then
--~                     chr = "\\mmlmcolumnpunctuationrule"
--~                 else
--~                     chr = "\\mmlmcolumnsymbolrule" -- should be widest char
--~                 end
                chr = "\\hrulefill"
            elseif tag == "mspace" then
                chr = "\\mmlmcolumndigitspace" -- utfchar(0x2007)
            end
            if j == numbers + 1 then
                context("\\aligntab")
            end
            local nchr = n_replacements[chr]
            context(nchr or chr)
        end
        ctx_crcr()
    end
    ctx_egroup()
end

local spacesplitter = lpeg.tsplitat(" ")

function mathml.mtable(root)
    -- todo: align, rowspacing, columnspacing, rowlines, columnlines
    root = getid(root)
    local at           = root.at
    local rowalign     = at.rowalign
    local columnalign  = at.columnalign
    local frame        = at.frame
    local rowaligns    = rowalign    and lpegmatch(spacesplitter,rowalign)
    local columnaligns = columnalign and lpegmatch(spacesplitter,columnalign)
    local frames       = frame       and lpegmatch(spacesplitter,frame)
    local framespacing = at.framespacing or "0pt"
    local framespacing = at.framespacing or "-\\ruledlinewidth" -- make this an option

    ctx_bTABLE { frame = frametypes[frame or "none"] or "off", offset = framespacing, background = "" } -- todo: use xtables and definextable
    for e in lxmlcollected(root,"/(mml:mtr|mml:mlabeledtr)") do
        ctx_bTR()
        local at = e.at
        local col = 0
        local rfr = at.frame       or (frames       and frames      [#frames])
        local rra = at.rowalign    or (rowaligns    and rowaligns   [#rowaligns])
        local rca = at.columnalign or (columnaligns and columnaligns[#columnaligns])
        local ignorelabel = e.tg == "mlabeledtr"
        for e in lxmlcollected(e,"/mml:mtd") do -- nested we can use xml.collected
            col = col + 1
            if ignorelabel and col == 1 then
                -- get rid of label, should happen at the document level
            else
                local at = e.at
                local rowspan    = at.rowspan    or 1
                local columnspan = at.columnspan or 1
                local cra = rowalignments   [at.rowalign    or (rowaligns    and rowaligns   [col]) or rra or "center"] or "lohi"
                local cca = columnalignments[at.columnalign or (columnaligns and columnaligns[col]) or rca or "center"] or "middle"
                local cfr = frametypes      [at.frame       or (frames       and frames      [col]) or rfr or "none"  ] or "off"
                ctx_bTD { align = formatters["{%s,%s}"](cra,cca), frame = cfr, nx = columnspan, ny = rowspan }
                if xmlempty(e,".") then
                    -- nothing, else hsize max
                else
                    ctx_startimath()
                 -- ctx_ignorespaces()
                    xmlcprint(e)
                 -- ctx_removeunwantedspaces()
                    ctx_stopimath()
                end
                ctx_eTD()
            end
        end
     -- if e.tg == "mlabeledtr" then
     --     ctx_bTD()
     --     xmlcprint(xml.first(e,"/!mml:mtd"))
     --     ctx_eTD()
     -- end
        ctx_eTR()
    end
    ctx_eTABLE()
end

function mathml.csymbol(root)
    root = getid(root)
    local at = root.at
    local encoding = at.encoding or ""
    local hash = url.hashed(lower(at.definitionUrl or ""))
    local full = hash.original or ""
    local base = hash.path or ""
    local text = strip(xmltext(root) or "")
    ctx_mmlapplycsymbol(full,base,encoding,text)
end

local p = lpeg.Cs(((1-lpegpatterns.whitespace)^1 / "mml:enclose:%0"  + (lpegpatterns.whitespace^1)/",")^1)

function mathml.menclosepattern(root)
    root = getid(root)
    local a = root.at.notation
    if a and a ~= "" then
        context(lpegmatch(p,a))
    end
end

function xml.is_element(e,name)
    return type(e) == "table" and (not name or e.tg == name)
end

function mathml.cpolar_a(root)
    root = getid(root)
    local dt = root.dt
    ctx_mathopnolimits("Polar")
    ctx_left(false,"(")
    for k=1,#dt do
        local dk = dt[k]
        if xml.is_element(dk,"sep") then
            context(",")
        else
            xmlsprint(dk)
        end
    end
    ctx_right(false,")")
end

-- crap .. maybe in char-def a mathml overload

local mathmleq = {
    [utfchar(0x00AF)] = utfchar(0x203E),
}

function mathml.extensible(chr)
    context(mathmleq[chr] or chr)
end
