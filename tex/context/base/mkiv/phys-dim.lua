if not modules then modules = { } end modules ['phys-dim'] = {
    version   = 1.001,
    comment   = "companion to phys-dim.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is pretty old code that I found back, but let's give it a try
-- in practice. It started out as m-units.lua but as we want to keep that
-- module around we moved the code to the dimensions module.
--
-- todo: maybe also an sciunit command that converts to si units (1 inch -> 0.0254 m)
-- etc .. typical something to do when listening to a news whow or b-movie
--
-- todo: collect used units for logging (and list of units, but then we need
-- associations too).

-- The lists have been checked and completed by Robin Kirkham.

-- dubious/wrong

--  Atom                        = [[u]], -- should be amu (atomic mass unit)
--  Bell                        = [[B]], -- should be bel
--  Sterant                     = [[sr]], -- should be steradian
--  Equivalent                  = [[eql]], -- qualifier?
--  At                          = [[at]], -- qualifier?
--  Force                       = [[f]], -- qualifier?
--  eVolt                       = [[eV]],
--  -- AC or DC voltages should be qualified in the text
--  VoltAC                      = [[V\unitsbackspace\unitslower{ac}]],
--  VoltDC                      = [[V\unitsbackspace\unitslower{dc}]],
--  AC                          = [[V\unitsbackspace\unitslower{ac}]],
--  DC                          = [[V\unitsbackspace\unitslower{dc}]],
--  -- probably not harmful but there are better alternatives
--  -- e.g., revolution per second (rev/s)
--  RPS                         = [[RPS]],
--  RPM                         = [[RPM]],
--  RevPerSec                   = [[RPS]],
--  RevPerMin                   = [[RPM]],

local rawset, next = rawset, next
local V, P, S, R, C, Cc, Cs, matchlpeg = lpeg.V, lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.match
local format, lower = string.format, string.lower
local appendlpeg = lpeg.append
local utfchartabletopattern = lpeg.utfchartabletopattern
local mergetable, mergedtable, keys, loweredkeys = table.merge, table.merged, table.keys, table.loweredkeys
local setmetatablenewindex = table.setmetatablenewindex
local utfchar = utf.char

physics            = physics or { }
physics.units      = physics.units or { }

local allocate     = utilities.storage.allocate

local context      = context
local commands     = commands
local implement    = interfaces.implement

local trace_units  = false
local report_units = logs.reporter("units")

trackers.register("physics.units", function(v) trace_units = v end)

-- digits parser (todo : use patterns)

local math_one       = Cs((P("$")    /"") * (1-P("$"))^1 * (P("$")/"")) / context.m
local math_two       = Cs((P("\\m {")/"") * (1-P("}"))^1 * (P("}")/"")) / context.m -- watch the space after \m

local digit          = R("09")
local sign           = S("+-")
local power          = S("^e")
local digitspace     = S("~@_")
local comma          = P(",")
local period         = P(".")
local semicolon      = P(";")
local colon          = P(":")
local signspace      = P("/")
local positive       = P("++") -- was p
local negative       = P("--") -- was n
local highspace      = P("//") -- was s
local padding        = P("=")
local plus           = P("+")
local minus          = P("-")
local space          = P(" ")
local lparent        = P("(")
local rparent        = P(")")

local lbrace         = P("{")
local rbrace         = P("}")

local digits         = digit^1

local powerdigits    = plus  * C(digits) / context.digitspowerplus
                     + minus * C(digits) / context.digitspowerminus
                     +         C(digits) / context.digitspower

local ddigitspace    = digitspace  / "" / context.digitsspace
local ddigit         = digits           / context.digitsdigit
local dsemicomma     = semicolon   / "" / context.digitsseparatorspace
local dsemiperiod    = colon       / "" / context.digitsseparatorspace
local dfinalcomma    = comma       / "" / context.digitsfinalcomma
local dfinalperiod   = period      / "" / context.digitsfinalperiod
local dintercomma    = comma       / "" / context.digitsintermediatecomma
local dinterperiod   = period      / "" / context.digitsintermediateperiod
local dskipcomma     = comma       / "" / context.digitsseparatorspace
local dskipperiod    = period      / "" / context.digitsseparatorspace
local dsignspace     = signspace   / "" / context.digitssignspace
local dpositive      = positive    / "" / context.digitspositive
local dnegative      = negative    / "" / context.digitsnegative
local dhighspace     = highspace   / "" / context.digitshighspace
local dsomesign      = plus        / "" / context.digitsplus
                     + minus       / "" / context.digitsminus
local dpower         = power       / "" * ( powerdigits + lbrace * powerdigits * rbrace )

local dpadding       = padding     / "" / context.digitszeropadding -- todo

local dleader        = (dpositive + dnegative + dhighspace + dsomesign + dsignspace)^0
local dtrailer       = dpower^0
local dfinal         = P(-1) + #P(1 - comma - period - semicolon - colon)
local dnumber        = (ddigitspace + ddigit)^1

-- ___,000,000  ___,___,000  ___,___,__0  000,000,000  000.00  000,000,000.00  000,000,000.==

-- : ; for the moment not used, maybe for invisible fraction . , when no leading number

-- local c_p = (ddigitspace^1 * dskipcomma)^0            -- ___,
--           * (ddigitspace^0 * ddigit * dintercomma)^0  -- _00, 000,
--           * ddigitspace^0  * ddigit^0                 -- _00 000
--           * (
--              dfinalperiod * ddigit                    -- .00
--            + dskipperiod  * dpadding^1                -- .==
--            + dsemiperiod  * ddigit                    -- :00
--            + dsemiperiod  * dpadding^1                -- :==
--             )^0
--           + ddigit                                    -- 00
--
-- local p_c = (ddigitspace^1 * dskipperiod)^0           -- ___.
--           * (ddigitspace^0 * ddigit * dinterperiod)^0 -- _00. 000.
--           * ddigitspace^0  * ddigit^0                 -- _00 000
--           * (
--              dfinalcomma * ddigit                     -- ,00
--            + dskipcomma  * dpadding^1                 -- ,==
--            + dsemicomma  * ddigit                     -- :00
--            + dsemicomma  * dpadding^1                 -- :==
--             )^0
--           + ddigit                                    -- 00
--
-- fix by WS/SB (needs further testing)

local c_p = (ddigitspace^1 * dskipcomma)^0                    -- ___,
          * (ddigitspace^0 * ddigit * dintercomma)^0          -- _00, 000,
          * ddigitspace^0  * ddigit^0                         -- _00 000
          * (
             dfinalperiod * ddigit * (dintercomma * ddigit)^0 -- .00
           + dskipperiod  * dpadding^1                        -- .==
           + dsemiperiod  * ddigit * (dintercomma * ddigit)^0 -- :00
           + dsemiperiod  * dpadding^1                        -- :==
            )^0
          + ddigit                                            -- 00

local p_c = (ddigitspace^1 * dskipperiod)^0                   -- ___.
          * (ddigitspace^0 * ddigit * dinterperiod)^0         -- _00. 000.
          * ddigitspace^0  * ddigit^0                         -- _00 000
          * (
             dfinalcomma * ddigit * (dinterperiod * ddigit)^0 -- 00
           + dskipcomma  * dpadding^1                         -- ,==
           + dsemicomma  * ddigit * (dinterperiod * ddigit)^0 -- :00
           + dsemicomma  * dpadding^1                         -- :==
            )^0
          + ddigit                                            -- 00

local p_c_dparser = math_one + math_two + dleader * p_c * dtrailer * dfinal
local c_p_dparser = math_one + math_two + dleader * c_p * dtrailer * dfinal

local function makedigits(str,reverse)
    if reverse then
        matchlpeg(p_c_dparser,str)
    else
        matchlpeg(c_p_dparser,str)
    end
end

-- tables:

local long_prefixes = {

    -- Le Système international d'unités (SI) 8e édition (Table 5)

    Yocto = "yocto",  -- 10^{-24}
    Zepto = "zepto",  -- 10^{-21}
    Atto  = "atto",   -- 10^{-18}
    Femto = "femto",  -- 10^{-15}
    Pico  = "pico",   -- 10^{-12}
    Nano  = "nano",   -- 10^{-9}
    Micro = "micro",  -- 10^{-6}
    Milli = "milli",  -- 10^{-3}
    Centi = "centi",  -- 10^{-2}
    Deci  = "deci",   -- 10^{-1}

    Deca  = "deca",   -- 10^{1}
    Hecto = "hecto",  -- 10^{2}
    Kilo  = "kilo",   -- 10^{3}
    Mega  = "mega",   -- 10^{6}
    Giga  = "giga",   -- 10^{9}
    Tera  = "tera",   -- 10^{12}
    Peta  = "peta",   -- 10^{15}
    Exa   = "exa",    -- 10^{18}
    Zetta = "zetta",  -- 10^{21}
    Yotta = "yotta",  -- 10^{24}

    -- IEC 60027-2: 2005, third edition, Part 2

    Kibi  = "kibi", -- 2^{10} (not ki)
    Mebi  = "mebi", -- 2^{20}
    Gibi  = "gibi", -- 2^{30}
    Tebi  = "tebi", -- 2^{40}
    Pebi  = "pebi", -- 2^{50}
    Exbi  = "exbi", -- 2^{60}

    -- not standard

    Zebi  = "zebi", -- binary
    Yobi  = "yobi", -- binary

    Micro = "micro",
    Root  = "root",
}

local long_units = {

    -- Le Système international d'unités (SI) 8e édition (except synonyms)
    -- SI base units (Table 1)

    Meter                       = "meter",
    Gram                        = "gram",
    Second                      = "second",
    Ampere                      = "ampere",
    Kelvin                      = "kelvin",
    Mole                        = "mole",
    Candela                     = "candela",

    -- synonyms

    Mol                         = "mole",
    Metre                       = "meter",

    -- SI derived units with special names (Table 3)

    Radian                      = "radian",
    Steradian                   = "steradian",
    Hertz                       = "hertz",
    Newton                      = "newton",
    Pascal                      = "pascal",
    Joule                       = "joule",
    Watt                        = "watt",
    Coulomb                     = "coulomb",
    Volt                        = "volt",
    Farad                       = "farad",
    Ohm                         = "ohm",
    Siemens                     = "siemens",
    Weber                       = "weber",
    Tesla                       = "tesla",
    Henry                       = "henry",
    Celsius                     = "celsius",
    Lumen                       = "lumen",
    Lux                         = "lux",
    Bequerel                    = "bequerel",
    Gray                        = "gray",
    Sievert                     = "sievert",
    Katal                       = "katal",

    -- non SI units accepted for use with SI (Table 6)

    Minute                      = "minute",
    Hour                        = "hour",
    Day                         = "day",

    -- (degree, minute, second of arc are treated specially later)

    Gon                         = "gon",
    Grad                        = "grad",
    Hectare                     = "hectare",
    Liter                       = "liter",

    Tonne                       = "tonne",

    -- synonyms

    MetricTon                   = "tonne",
    Litre                       = "liter",

    ["Metric Ton"]              = "tonne",

    -- non-SI units whose values must be obtained experimentally (Table 7)

    AtomicMassUnit              = "atomicmassunit",
    AstronomicalUnit            = "astronomicalunit",
    ElectronVolt                = "electronvolt",
    Dalton                      = "dalton",

    ["Atomic Mass Unit"]        = "atomicmassunit",
    ["Astronomical Unit"]       = "astronomicalunit",
    ["Electron Volt"]           = "electronvolt",

    -- special cases (catch doubles, okay, a bit over the top)

    DegreesCelsius              = "celsius",
    DegreesFahrenheit           = "fahrenheit",
    DegreeCelsius               = "celsius",
    DegreeFahrenheit            = "fahrenheit",

    ["Degrees Celsius"]         = "celsius",
    ["Degrees Fahrenheit"]      = "fahrenheit",
    ["Degree Celsius"]          = "celsius",
    ["Degree Fahrenheit"]       = "fahrenheit",

 -- too late as we already have connected symbols catched:
 --
 -- ["° Celsius"]               = "celsius",
 -- ["° Fahrenheit"]            = "fahrenheit",
 -- ["°Celsius"]                = "celsius",
 -- ["°Fahrenheit"]             = "fahrenheit",

    -- the "natural units" and "atomic units" are omitted for now
    -- synonyms

    eV                          = "electronvolt",
    AMU                         = "atomicmassunit",

    -- other non-SI units (Table 8)

    Bar                         = "bar",
    Hg                          = "mercury",
 -- ["Millimetre Of Mercury"]   = [[mmHg]],
    Angstrom                    = "angstrom", -- strictly Ångström
    NauticalMile                = "nauticalmile",
    Barn                        = "barn",
    Knot                        = "knot",
    Neper                       = "neper",
    Bel                         = "bel", -- in practice only decibel used

    ["Nautical Mile"]           = "nauticalmile",

    -- other non-SI units from CGS system (Table 9)

    Erg                         = "erg",
    Dyne                        = "dyne",
    Poise                       = "poise",
    Stokes                      = "stokes",
    Stilb                       = "stilb",
    Phot                        = "phot",
    Gal                         = "gal",
    Maxwell                     = "maxwell",
    Gauss                       = "gauss",
    Oersted                     = "oersted",

    -- end of SI

    -- data: for use with the binary prefixes (except Erlang)

    Bit                         = "bit",
    Byte                        = "byte" ,
    Baud                        = "baud",
    Erlang                      = "erlang",

    -- common units, not part of SI

    Atmosphere                  = "atmosphere",
    Revolution                  = "revolution",

    -- synonyms

    Atm                         = "atmosphere",
    Rev                         = "revolution",

    -- imperial units (very incomplete)

    Fahrenheit                  = "fahrenheit",
    Foot                        = "foot",
    Inch                        = "inch",
    Calorie                     = "calorie",

    -- synonyms

    Cal                         = "calorie",

}

local long_operators = {

    Times   = "times",
    Solidus = "solidus",
    Per     = "per",
    OutOf   = "outof",

}

local long_suffixes = {

    Linear     = "linear",
    Square     = "square",
    Cubic      = "cubic",
    Quadratic  = "quadratic",
    Inverse    = "inverse",
    ILinear    = "ilinear",
    ISquare    = "isquare",
    ICubic     = "icubic",
    IQuadratic = "iquadratic",

}

local short_prefixes = {

    y  = "yocto",
    z  = "zetto",
    a  = "atto",
    f  = "femto",
    p  = "pico",
    n  = "nano",
    u  = "micro",
    m  = "milli",
    c  = "centi",
    d  = "deci",
    da = "deca",
    h  = "hecto",
    k  = "kilo",
    M  = "mega",
    G  = "giga",
    T  = "tera",
    P  = "peta",
    E  = "exa",
    Z  = "zetta",
    Y  = "yotta",

}

local short_units = { -- I'm not sure about casing

    m  = "meter",
    Hz = "hertz",
    hz = "hertz",
    B  = "bel",
    b  = "bel",
    lx = "lux",
 -- da = "dalton",
    h  = "hour",
    s  = "second",
    g  = "gram",
    n  = "newton",
    v  = "volt",
    t  = "tonne",
    l  = "liter",
 -- w  = "watt",
    W  = "watt",
 -- a  = "ampere",
    A  = "ampere",

    min = "minute",

    [utfchar(0x2103)] = "celsius",
    [utfchar(0x2109)] = "fahrenheit",
}

local short_operators = {
    ["."] = "times",
    ["*"] = "times",
    ["/"] = "solidus",
    [":"] = "outof",
}

local short_suffixes = { -- maybe just raw digit match
    ["1"]   = "linear",
    ["2"]   = "square",
    ["3"]   = "cubic",
    ["4"]   = "quadratic",
    ["+1"]  = "linear",
    ["+2"]  = "square",
    ["+3"]  = "cubic",
    ["+4"]  = "quadratic",
    ["-1"]  = "inverse",
    ["-1"]  = "ilinear",
    ["-2"]  = "isquare",
    ["-3"]  = "icubic",
    ["-4"]  = "iquadratic",
    ["^1"]  = "linear",
    ["^2"]  = "square",
    ["^3"]  = "cubic",
    ["^4"]  = "quadratic",
    ["^+1"] = "linear",
    ["^+2"] = "square",
    ["^+3"] = "cubic",
    ["^+4"] = "quadratic",
    ["^-1"] = "inverse",
    ["^-1"] = "ilinear",
    ["^-2"] = "isquare",
    ["^-3"] = "icubic",
    ["^-4"] = "iquadratic",
}

local symbol_units = {
    Degrees    = "degree",
    Degree     = "degree",
 -- Deg        = "degree",
    ["°"]      = "degree",
    ArcMinute  = "arcminute",
    ["′"]      = "arcminute", -- 0x2032
    ArcSecond  = "arcsecond",
    ["″"]      = "arcsecond", -- 0x2033
    Percent    = "percent",
    ["%"]      = "percent",
    Promille   = "permille",
    Permille   = "permille",
}

local packaged_units = {
    Micron = "micron",
    mmHg   = "millimetermercury",
}

-- rendering:

local ctx_unitsPUS    = context.unitsPUS
local ctx_unitsPU     = context.unitsPU
local ctx_unitsPS     = context.unitsPS
local ctx_unitsP      = context.unitsP
local ctx_unitsUS     = context.unitsUS
local ctx_unitsU      = context.unitsU
local ctx_unitsS      = context.unitsS
local ctx_unitsO      = context.unitsO
local ctx_unitsN      = context.unitsN
local ctx_unitsC      = context.unitsC
local ctx_unitsQ      = context.unitsQ
local ctx_unitsNstart = context.unitsNstart
local ctx_unitsNstop  = context.unitsNstop
local ctx_unitsNspace = context.unitsNspace

local labels = languages.data.labels

labels.prefixes = allocate {
    yocto = { labels = { en = [[y]]   } }, -- 10^{-24}
    zepto = { labels = { en = [[z]]   } }, -- 10^{-21}
    atto  = { labels = { en = [[a]]   } }, -- 10^{-18}
    femto = { labels = { en = [[f]]   } }, -- 10^{-15}
    pico  = { labels = { en = [[p]]   } }, -- 10^{-12}
    nano  = { labels = { en = [[n]]   } }, -- 10^{-9}
    micro = { labels = { en = [[\mu]] } }, -- 10^{-6}
    milli = { labels = { en = [[m]]   } }, -- 10^{-3}
    centi = { labels = { en = [[c]]   } }, -- 10^{-2}
    deci  = { labels = { en = [[d]]   } }, -- 10^{-1}
    deca  = { labels = { en = [[da]]  } }, -- 10^{1}
    hecto = { labels = { en = [[h]]   } }, -- 10^{2}
    kilo  = { labels = { en = [[k]]   } }, -- 10^{3}
    mega  = { labels = { en = [[M]]   } }, -- 10^{6}
    giga  = { labels = { en = [[G]]   } }, -- 10^{9}
    tera  = { labels = { en = [[T]]   } }, -- 10^{12}
    peta  = { labels = { en = [[P]]   } }, -- 10^{15}
    exa   = { labels = { en = [[E]]   } }, -- 10^{18}
    zetta = { labels = { en = [[Z]]   } }, -- 10^{21}
    yotta = { labels = { en = [[Y]]   } }, -- 10^{24}
    kibi  = { labels = { en = [[Ki]]  } }, -- 2^{10} (not ki)
    mebi  = { labels = { en = [[Mi]]  } }, -- 2^{20}
    gibi  = { labels = { en = [[Gi]]  } }, -- 2^{30}
    tebi  = { labels = { en = [[Ti]]  } }, -- 2^{40}
    pebi  = { labels = { en = [[Pi]]  } }, -- 2^{50}
    exbi  = { labels = { en = [[Ei]]  } }, -- 2^{60}
    zebi  = { labels = { en = [[Zi]]  } }, -- binary
    yobi  = { labels = { en = [[Yi]]  } }, -- binary
    micro = { labels = { en = [[µ]]   } }, -- 0x00B5 \textmu
    root  = { labels = { en = [[√]]   } }, -- 0x221A
}

labels.units = allocate {
    meter                       = { labels = { en = [[m]]                        } },
    gram                        = { labels = { en = [[g]]                        } }, -- strictly kg is the base unit
    second                      = { labels = { en = [[s]]                        } },
    ampere                      = { labels = { en = [[A]]                        } },
    kelvin                      = { labels = { en = [[K]]                        } },
    mole                        = { labels = { en = [[mol]]                      } },
    candela                     = { labels = { en = [[cd]]                       } },
    mol                         = { labels = { en = [[mol]]                      } },
    radian                      = { labels = { en = [[rad]]                      } },
    steradian                   = { labels = { en = [[sr]]                       } },
    hertz                       = { labels = { en = [[Hz]]                       } },
    newton                      = { labels = { en = [[N]]                        } },
    pascal                      = { labels = { en = [[Pa]]                       } },
    joule                       = { labels = { en = [[J]]                        } },
    watt                        = { labels = { en = [[W]]                        } },
    coulomb                     = { labels = { en = [[C]]                        } },
    volt                        = { labels = { en = [[V]]                        } },
    farad                       = { labels = { en = [[F]]                        } },
    ohm                         = { labels = { en = [[Ω]]                        } }, -- 0x2126 \textohm
    siemens                     = { labels = { en = [[S]]                        } },
    weber                       = { labels = { en = [[Wb]]                       } },
    mercury                     = { labels = { en = [[Hg]]                       } },
    millimetermercury           = { labels = { en = [[mmHg]]                     } }, -- connected
    tesla                       = { labels = { en = [[T]]                        } },
    henry                       = { labels = { en = [[H]]                        } },
    celsius                     = { labels = { en = [[\checkedtextcelsius]]      } }, -- 0x2103
    lumen                       = { labels = { en = [[lm]]                       } },
    lux                         = { labels = { en = [[lx]]                       } },
    bequerel                    = { labels = { en = [[Bq]]                       } },
    gray                        = { labels = { en = [[Gy]]                       } },
    sievert                     = { labels = { en = [[Sv]]                       } },
    katal                       = { labels = { en = [[kat]]                      } },
    minute                      = { labels = { en = [[min]]                      } },
    hour                        = { labels = { en = [[h]]                        } },
    day                         = { labels = { en = [[d]]                        } },
    gon                         = { labels = { en = [[gon]]                      } },
    grad                        = { labels = { en = [[grad]]                     } },
    hectare                     = { labels = { en = [[ha]]                       } },
    liter                       = { labels = { en = [[l]]                        } }, -- symbol l or L
    tonne                       = { labels = { en = [[t]]                        } },
    electronvolt                = { labels = { en = [[eV]]                       } },
    dalton                      = { labels = { en = [[Da]]                       } },
    atomicmassunit              = { labels = { en = [[u]]                        } },
    astronomicalunit            = { labels = { en = [[au]]                       } },
    bar                         = { labels = { en = [[bar]]                      } },
    angstrom                    = { labels = { en = [[Å]]                        } }, -- strictly Ångström
    nauticalmile                = { labels = { en = [[M]]                        } },
    barn                        = { labels = { en = [[b]]                        } },
    knot                        = { labels = { en = [[kn]]                       } },
    neper                       = { labels = { en = [[Np]]                       } },
    bel                         = { labels = { en = [[B]]                        } }, -- in practice only decibel used
    erg                         = { labels = { en = [[erg]]                      } },
    dyne                        = { labels = { en = [[dyn]]                      } },
    poise                       = { labels = { en = [[P]]                        } },
    stokes                      = { labels = { en = [[St]]                       } },
    stilb                       = { labels = { en = [[sb]]                       } },
    phot                        = { labels = { en = [[phot]]                     } },
    gal                         = { labels = { en = [[gal]]                      } },
    maxwell                     = { labels = { en = [[Mx]]                       } },
    gauss                       = { labels = { en = [[G]]                        } },
    oersted                     = { labels = { en = [[Oe]]                       } }, -- strictly Œrsted
    bit                         = { labels = { en = [[bit]]                      } },
    byte                        = { labels = { en = [[B]]                        } },
    baud                        = { labels = { en = [[Bd]]                       } },
    erlang                      = { labels = { en = [[E]]                        } },
    atmosphere                  = { labels = { en = [[atm]]                      } },
    revolution                  = { labels = { en = [[rev]]                      } },
    fahrenheit                  = { labels = { en = [[\checkedtextfahrenheit]]   } }, -- 0x2109
    foot                        = { labels = { en = [[ft]]                       } },
    inch                        = { labels = { en = [[inch]]                     } },
    calorie                     = { labels = { en = [[cal]]                      } },
    --
    degree                      = { labels = { en = [[°]]} },
    arcminute                   = { labels = { en = [[\checkedtextprime]]        } }, -- ′ 0x2032
    arcsecond                   = { labels = { en = [[\checkedtextdoubleprime]]  } }, -- ″ 0x2033
    percent                     = { labels = { en = [[\percent]]                 } },
    permille                    = { labels = { en = [[\promille]]                } },
    --
    micron                      = { labels = { en = [[\textmu m]]                } },
}

labels.operators = allocate {
    times   = { labels = { en = [[\unitsTIMES]]   } },
    solidus = { labels = { en = [[\unitsSOLIDUS]] } },
    per     = { labels = { en = [[\unitsSOLIDUS]] } },
    outof   = { labels = { en = [[\unitsOUTOF]]   } },
}

labels.suffixes = allocate {
    linear     = { labels = { en = [[1]]  } },
    square     = { labels = { en = [[2]]  } },
    cubic      = { labels = { en = [[3]]  } },
    quadratic  = { labels = { en = [[4]]  } },
    inverse    = { labels = { en = [[\mathminus1]] } },
    ilinear    = { labels = { en = [[\mathminus1]] } },
    isquare    = { labels = { en = [[\mathminus2]] } },
    icubic     = { labels = { en = [[\mathminus3]] } },
    iquadratic = { labels = { en = [[\mathminus4]] } },
}

local function dimpus(p,u,s)
    if trace_units then
        report_units("prefix %a, unit %a, suffix %a",p,u,s)
    end    --
    if p ~= "" then
        if u ~= ""  then
            if s ~= ""  then
                ctx_unitsPUS(p,u,s)
            else
                ctx_unitsPU(p,u)
            end
        elseif s ~= ""  then
            ctx_unitsPS(p,s)
        else
            ctx_unitsP(p)
        end
    else
        if u ~= ""  then
            if s ~= ""  then
                ctx_unitsUS(u,s)
         -- elseif c then
         --     ctx_unitsC(u)
            else
                ctx_unitsU(u)
            end
        elseif s ~= ""  then
            ctx_unitsS(s)
        else
            ctx_unitsP(p)
        end
    end
end

local function dimspu(s,p,u)
    return dimpus(p,u,s)
end

local function dimop(o)
    if trace_units then
        report_units("operator %a",o)
    end
    if o then
        ctx_unitsO(o)
    end
end

local function dimsym(s)
    if trace_units then
        report_units("symbol %a",s)
    end
    s = symbol_units[s] or s
    if s then
        ctx_unitsC(s)
    end
end

local function dimpre(p)
    if trace_units then
        report_units("prefix [%a",p)
    end
    p = packaged_units[p] or p
    if p then
        ctx_unitsU(p)
    end
end

-- patterns:
--
-- space inside Cs else funny captures and args to function
--
-- square centi meter per square kilo seconds

-- todo 0x -> rm

local function update_parsers() -- todo: don't remap utf sequences

    local all_long_prefixes  = { }
    local all_long_units     = { }
    local all_long_operators = { }
    local all_long_suffixes  = { }
    local all_symbol_units   = { }
    local all_packaged_units = { }

    for k, v in next, long_prefixes  do all_long_prefixes [k] = v all_long_prefixes [lower(k)] = v end
    for k, v in next, long_units     do all_long_units    [k] = v all_long_units    [lower(k)] = v end
    for k, v in next, long_operators do all_long_operators[k] = v all_long_operators[lower(k)] = v end
    for k, v in next, long_suffixes  do all_long_suffixes [k] = v all_long_suffixes [lower(k)] = v end
    for k, v in next, symbol_units   do all_symbol_units  [k] = v all_symbol_units  [lower(k)] = v end
    for k, v in next, packaged_units do all_packaged_units[k] = v all_packaged_units[lower(k)] = v end

    local somespace        = P(" ")^0/""

    local p_long_prefix    = appendlpeg(all_long_prefixes,nil,true)
    local p_long_unit      = appendlpeg(all_long_units,nil,true)
    local p_long_operator  = appendlpeg(all_long_operators,nil,true)
    local p_long_suffix    = appendlpeg(all_long_suffixes,nil,true)
    local p_symbol         = appendlpeg(all_symbol_units,nil,true)
    local p_packaged       = appendlpeg(all_packaged_units,nil,true)

    local p_short_prefix   = appendlpeg(short_prefixes)
    local p_short_unit     = appendlpeg(short_units)
    local p_short_operator = appendlpeg(short_operators)
    local p_short_suffix   = appendlpeg(short_suffixes)

    -- more efficient but needs testing

--     local p_long_prefix    = utfchartabletopattern(all_long_prefixes)  / all_long_prefixes
--     local p_long_unit      = utfchartabletopattern(all_long_units)     / all_long_units
--     local p_long_operator  = utfchartabletopattern(all_long_operators) / all_long_operators
--     local p_long_suffix    = utfchartabletopattern(all_long_suffixes)  / all_long_suffixes
--     local p_symbol         = utfchartabletopattern(all_symbol_units)   / all_symbol_units
--     local p_packaged       = utfchartabletopattern(all_packaged_units) / all_packaged_units

--     local p_short_prefix   = utfchartabletopattern(short_prefixes)     / short_prefixes
--     local p_short_unit     = utfchartabletopattern(short_units)        / short_units
--     local p_short_operator = utfchartabletopattern(short_operators)    / short_operators
--     local p_short_suffix   = utfchartabletopattern(short_suffixes)     / short_suffixes

    -- we can can cleanup some space issues here (todo)

    local unitparser = P { "unit",
        --
        longprefix    = Cs(V("somespace") * p_long_prefix),
        shortprefix   = Cs(V("somespace") * p_short_prefix),
        longsuffix    = Cs(V("somespace") * p_long_suffix),
        shortsuffix   = Cs(V("somespace") * p_short_suffix),
        shortunit     = Cs(V("somespace") * p_short_unit),
        longunit      = Cs(V("somespace") * p_long_unit),
        longoperator  = Cs(V("somespace") * p_long_operator),
        shortoperator = Cs(V("somespace") * p_short_operator),
        packaged      = Cs(V("somespace") * p_packaged),
        --
        nothing       = Cc(""),
        somespace     = somespace,
        nospace       = (1-somespace)^1, -- was 0
     -- ignore        = P(-1),
        --
        qualifier     = Cs(V("somespace") * (lparent/"") * (1-rparent)^1 * (rparent/"")),
        --
        somesymbol    = V("somespace")
                      * (p_symbol/dimsym)
                      * V("somespace"),
        somepackaged  = V("somespace")
                      * (V("packaged") / dimpre)
                      * V("somespace"),
     -- someunknown   = V("somespace")
     --               * (V("nospace")/ctx_unitsU)
     --               * V("somespace"),
        --
        combination   = V("longprefix")  * V("longunit")   -- centi meter
                      + V("nothing")     * V("longunit")
                      + V("shortprefix") * V("shortunit")  -- c m
                      + V("nothing")     * V("shortunit")
                      + V("longprefix")  * V("shortunit")  -- centi m
                      + V("shortprefix") * V("longunit"),  -- c meter

--         combination   = (   V("longprefix")   -- centi meter
--                           + V("nothing")
--                         ) * V("longunit")
--                       + (   V("shortprefix")  -- c m
--                           + V("nothing")
--                           + V("longprefix")
--                         ) * V("shortunit")    -- centi m
--                       + (   V("shortprefix")  -- c meter
--                         ) * V("longunit"),


        dimension     = V("somespace")
                      * (
                            V("packaged") / dimpre
                          + (V("longsuffix") * V("combination")) / dimspu
                          + (V("combination") * (V("shortsuffix") + V("nothing"))) / dimpus
                        )
                      * (V("qualifier") / ctx_unitsQ)^-1
                      * V("somespace"),
        operator      = V("somespace")
                      * ((V("longoperator") + V("shortoperator")) / dimop)
                      * V("somespace"),
        snippet       = V("dimension")
                      + V("somesymbol"),
        unit          = (   V("snippet") * (V("operator") * V("snippet"))^0
                          + V("somepackaged")
                        )^1,
    }


 -- local number = lpeg.patterns.number

    local number = Cs( P("$")     * (1-P("$"))^1 * P("$")
                     + P([[\m{]]) * (1-P("}"))^1 * P("}")
                     + (1-R("az","AZ")-P(" "))^1 -- todo: catch { } -- not ok
                   ) / ctx_unitsN

    local start  = Cc(nil) / ctx_unitsNstart
    local stop   = Cc(nil) / ctx_unitsNstop
    local space  = Cc(nil) / ctx_unitsNspace

    -- todo: avoid \ctx_unitsNstart\ctx_unitsNstop (weird that it can happen .. now catched at tex end)

    local p_c_combinedparser  = P { "start",
        number = start * dleader * (p_c_dparser + number) * stop,
        rule   = V("number")^-1 * unitparser,
        space  = space,
        start  = V("rule") * (V("space") * V("rule"))^0 + V("number")
    }

    local c_p_combinedparser  = P { "start",
        number = start * dleader * (c_p_dparser + number) * stop,
        rule   = V("number")^-1 * unitparser,
        space  = space,
        start  = V("rule") * (V("space") * V("rule"))^0 + V("number")
    }

    return p_c_combinedparser, c_p_combinedparser
end

local p_c_parser = nil
local c_p_parser = nil
local dirty      = true

local function makeunit(str,reverse)
    if dirty then
        if trace_units then
            report_units("initializing parser")
        end
        p_c_parser, c_p_parser = update_parsers()
        dirty = false
    end
    local ok
    if reverse then
        ok = matchlpeg(p_c_parser,str)
    else
        ok = matchlpeg(c_p_parser,str)
    end
    if not ok then
        report_units("unable to parse: %s",str)
        context(str)
    end
end

local function trigger(t,k,v)
    rawset(t,k,v)
    dirty = true
end

local t_units = {
    prefixes  = setmetatablenewindex(long_prefixes,trigger),
    units     = setmetatablenewindex(long_units,trigger),
    operators = setmetatablenewindex(long_operators,trigger),
    suffixes  = setmetatablenewindex(long_suffixes,trigger),
    symbols   = setmetatablenewindex(symbol_units,trigger),
    packaged  = setmetatablenewindex(packaged_units,trigger),
}

local t_shortcuts = {
    prefixes  = setmetatablenewindex(short_prefixes,trigger),
    units     = setmetatablenewindex(short_units,trigger),
    operators = setmetatablenewindex(short_operators,trigger),
    suffixes  = setmetatablenewindex(short_suffixes,trigger),
}

physics.units.tables = allocate {
    units     = t_units,
    shortcuts = t_shortcuts,
}

local mapping = {
    prefix   = "prefixes",
    unit     = "units",
    operator = "operators",
    suffixe  = "suffixes",
    symbol   = "symbols",
    packaged = "packaged",
}

local function registerunit(category,list)
    if not list or list == "" then
        list = category
        category = "unit"
    end
    local t = t_units[mapping[category]]
    if t then
        for k, v in next, utilities.parsers.settings_to_hash(list or "") do
            t[k] = v
        end
    end
 -- inspect(tables)
end

physics.units.registerunit = registerunit

implement { name = "digits_normal",  actions = makedigits,   arguments = "string" }
implement { name = "digits_reverse", actions = makedigits,   arguments = { "string", true } }
implement { name = "unit_normal",    actions = makeunit,     arguments = "string"}
implement { name = "unit_reverse",   actions = makeunit,     arguments = { "string", true } }
implement { name = "registerunit",   actions = registerunit, arguments = "2 strings" }
