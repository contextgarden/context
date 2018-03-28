if not modules then modules = { } end modules ['math-map'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: make sparse .. if self

--[[ldx--
<p>Remapping mathematics alphabets.</p>
--ldx]]--

-- oldstyle: not really mathematics but happened to be part of
-- the mathematics fonts in cmr
--
-- persian: we will also provide mappers for other
-- scripts

-- todo: alphabets namespace
-- maybe: script/scriptscript dynamic,

-- superscripped primes get unscripted !

-- to be looked into once the fonts are ready (will become font
-- goodie):
--
-- (U+2202,U+1D715) : upright
-- (U+2202,U+1D715) : italic
-- (U+2202,U+1D715) : upright
--
-- plus add them to the regular vectors below so that they honor \it etc

local type, next = type, next
local merged, sortedhash = table.merged, table.sortedhash
local extract = bit32.extract

local allocate            = utilities.storage.allocate

local otffeatures         = fonts.constructors.features.otf
local registerotffeature  = otffeatures.register

local setmetatableindex   = table.setmetatableindex

local texgetattribute     = tex.getattribute
local texsetattribute     = tex.setattribute

local trace_greek         = false  trackers.register("math.greek",  function(v) trace_greek = v end)
local report_remapping    = logs.reporter("mathematics","remapping")

mathematics               = mathematics or { }
local mathematics         = mathematics

local implement           = interfaces.implement

-- Unfortunately some alphabets have gaps (thereby troubling all applications that
-- need to deal with math). Somewhat strange considering all those weird symbols that
-- were added afterwards. The following trickery (and data) is only to be used for
-- diagnostics and quick and dirty alphabet tracing (s-mat-10.mkiv) as we deal with
-- it otherwise.

-- todo: allocate

mathematics.styles       = allocate { "regular", "sansserif", "monospaced", "fraktur", "script", "blackboard" }
mathematics.alternatives = allocate { "normal", "bold", "italic", "bolditalic" }
mathematics.sets         = allocate { "ucletters", "lcletters", "digits", "ucgreek", "lcgreek", "symbols" }

mathematics.charactersets = allocate {
    ucletters = {
        0x00041, 0x00042, 0x00043, 0x00044, 0x00045,
        0x00046, 0x00047, 0x00048, 0x00049, 0x0004A,
        0x0004B, 0x0004C, 0x0004D, 0x0004E, 0x0004F,
        0x00050, 0x00051, 0x00052, 0x00053, 0x00054,
        0x00055, 0x00056, 0x00057, 0x00058, 0x00059,
        0x0005A,
    },
    lcletters = {
        0x00061, 0x00062, 0x00063, 0x00064, 0x00065,
        0x00066, 0x00067, 0x00068, 0x00069, 0x0006A,
        0x0006B, 0x0006C, 0x0006D, 0x0006E, 0x0006F,
        0x00070, 0x00071, 0x00072, 0x00073, 0x00074,
        0x00075, 0x00076, 0x00077, 0x00078, 0x00079,
        0x0007A,
    },
    digits = {
        0x00030, 0x00031, 0x00032, 0x00033, 0x00034,
        0x00035, 0x00036, 0x00037, 0x00038, 0x00039,
    },
    ucgreek = {
        0x0391, 0x0392, 0x0393, 0x0394, 0x0395,
        0x0396, 0x0397, 0x0398, 0x0399, 0x039A,
        0x039B, 0x039C, 0x039D, 0x039E, 0x039F,
        0x03A0, 0x03A1, 0x03A3, 0x03A4, 0x03A5,
        0x03A6, 0x03A7, 0x03A8, 0x03A9
    },
    lcgreek = {
        0x03B1, 0x03B2, 0x03B3, 0x03B4, 0x03B5,
        0x03B6, 0x03B7, 0x03B8, 0x03B9, 0x03BA,
        0x03BB, 0x03BC, 0x03BD, 0x03BE, 0x03BF,
        0x03C0, 0x03C1, 0x03C2, 0x03C3, 0x03C4,
        0x03C5, 0x03C6, 0x03C7, 0x03C8, 0x03C9,
        0x03D1, 0x03D5, 0x03D6, 0x03F0, 0x03F1,
        0x03F4, 0x03F5
    },
}

mathematics.gaps = allocate {
    [0x1D455] = 0x0210E, -- ℎ h
    [0x1D49D] = 0x0212C, -- ℬ script B
    [0x1D4A0] = 0x02130, -- ℰ script E
    [0x1D4A1] = 0x02131, -- ℱ script F
    [0x1D4A3] = 0x0210B, -- ℋ script H
    [0x1D4A4] = 0x02110, -- ℐ script I
    [0x1D4A7] = 0x02112, -- ℒ script L
    [0x1D4A8] = 0x02133, -- ℳ script M
    [0x1D4AD] = 0x0211B, -- ℛ script R
    [0x1D4BA] = 0x0212F, -- ℯ script e
    [0x1D4BC] = 0x0210A, -- ℊ script g
 -- [0x1D4C1] = 0x02113, -- exception: liter
    [0x1D4C4] = 0x02134, -- ℴ script o
    [0x1D506] = 0x0212D, -- ℭ fraktur C
    [0x1D50B] = 0x0210C, -- ℌ fraktur H
    [0x1D50C] = 0x02111, -- ℑ fraktur I
    [0x1D515] = 0x0211C, -- ℜ fraktur R
    [0x1D51D] = 0x02128, -- ℨ fraktur Z
    [0x1D53A] = 0x02102, -- ℂ bb C
    [0x1D53F] = 0x0210D, -- ℍ bb H
    [0x1D545] = 0x02115, -- ℕ bb N
    [0x1D547] = 0x02119, -- ℙ bb P
    [0x1D548] = 0x0211A, -- ℚ bb Q
    [0x1D549] = 0x0211D, -- ℝ bb R
    [0x1D551] = 0x02124, -- ℤ bb Z
}

local function fillinmathgaps(tfmdata,key,value)
    local mathgaps     = mathematics.gaps
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    for gap, original in next, mathgaps do
        if characters[original] and not characters[gap] then
            characters  [gap] = characters  [original]
            descriptions[gap] = descriptions[original]
        end
    end
end

registerotffeature {
    name         = "mathgaps",
    description  = "plug gaps in math alphabets",
    comment      = "regular document sources should not depend on this",
    manipulators = {
        base = fillinmathgaps,
        node = fillinmathgaps,
    }
}

-- we could use one level less and have tf etc be tables directly but the
-- following approach permits easier remapping of a-a, A-Z and 0-9 to
-- fallbacks; symbols is currently mostly greek

local function todigit (n) local t = { } for i=0, 9 do t[0x00030+i] = n+i end return t end
local function toupper (n) local t = { } for i=0,25 do t[0x00041+i] = n+i end return t end
local function tolower (n) local t = { } for i=0,25 do t[0x00061+i] = n+i end return t end
local function tovector(t)                                                    return t end

-- how about 0x2A (ast)    cq. 0x2217
--           0x2D (hyphen) cq. 0x2212
--           0x3A (colon)  cq. 0x2236

local regular_tf = {
    digits    = todigit(0x00030),
    ucletters = toupper(0x00041),
    lcletters = tolower(0x00061),
    ucgreek   = {
        [0x0391]=0x0391, [0x0392]=0x0392, [0x0393]=0x0393, [0x0394]=0x0394, [0x0395]=0x0395,
        [0x0396]=0x0396, [0x0397]=0x0397, [0x0398]=0x0398, [0x0399]=0x0399, [0x039A]=0x039A,
        [0x039B]=0x039B, [0x039C]=0x039C, [0x039D]=0x039D, [0x039E]=0x039E, [0x039F]=0x039F,
        [0x03A0]=0x03A0, [0x03A1]=0x03A1, [0x03A3]=0x03A3, [0x03A4]=0x03A4, [0x03A5]=0x03A5,
        [0x03A6]=0x03A6, [0x03A7]=0x03A7, [0x03A8]=0x03A8, [0x03A9]=0x03A9,
        },
    lcgreek   = {
        [0x03B1]=0x03B1, [0x03B2]=0x03B2, [0x03B3]=0x03B3, [0x03B4]=0x03B4, [0x03B5]=0x03B5,
        [0x03B6]=0x03B6, [0x03B7]=0x03B7, [0x03B8]=0x03B8, [0x03B9]=0x03B9, [0x03BA]=0x03BA,
        [0x03BB]=0x03BB, [0x03BC]=0x03BC, [0x03BD]=0x03BD, [0x03BE]=0x03BE, [0x03BF]=0x03BF,
        [0x03C0]=0x03C0, [0x03C1]=0x03C1, [0x03C2]=0x03C2, [0x03C3]=0x03C3, [0x03C4]=0x03C4,
        [0x03C5]=0x03C5, [0x03C6]=0x03C6, [0x03C7]=0x03C7, [0x03C8]=0x03C8, [0x03C9]=0x03C9,
        [0x03D1]=0x03D1, [0x03D5]=0x03D5, [0x03D6]=0x03D6, [0x03F0]=0x03F0, [0x03F1]=0x03F1,
        [0x03F4]=0x03F4, [0x03F5]=0x03F5,
    },
    symbols   = {
        [0x2202]=0x2202, [0x2207]=0x2207,
        [0x0027]=0x2032,  -- prime
    },
}

local regular_it = {
    digits    = tovector(regular_tf.digits),
    ucletters = toupper(0x1D434),
    lcletters = { -- H
        [0x00061]=0x1D44E, [0x00062]=0x1D44F, [0x00063]=0x1D450, [0x00064]=0x1D451, [0x00065]=0x1D452,
        [0x00066]=0x1D453, [0x00067]=0x1D454, [0x00068]=0x0210E, [0x00069]=0x1D456, [0x0006A]=0x1D457,
        [0x0006B]=0x1D458, [0x0006C]=0x1D459, [0x0006D]=0x1D45A, [0x0006E]=0x1D45B, [0x0006F]=0x1D45C,
        [0x00070]=0x1D45D, [0x00071]=0x1D45E, [0x00072]=0x1D45F, [0x00073]=0x1D460, [0x00074]=0x1D461,
        [0x00075]=0x1D462, [0x00076]=0x1D463, [0x00077]=0x1D464, [0x00078]=0x1D465, [0x00079]=0x1D466,
        [0x0007A]=0x1D467,
        -- arabic
        [0x00627] = 0x1EE00, [0x00628] = 0x1EE21, [0x0062A] = 0x1EE15, [0x0062B] = 0x1EE16,
        [0x0062C] = 0x1EE22, [0x0062D] = 0x1EE07, [0x0062E] = 0x1EE17, [0x0062F] = 0x1EE03,
        [0x00630] = 0x1EE18, [0x00631] = 0x1EE13, [0x00632] = 0x1EE06, [0x00633] = 0x1EE0E,
        [0x00634] = 0x1EE14, [0x00635] = 0x1EE11, [0x00636] = 0x1EE19, [0x00637] = 0x1EE08,
        [0x00638] = 0x1EE1A, [0x00639] = 0x1EE0F, [0x0063A] = 0x1EE1B, [0x00641] = 0x1EE10,
        [0x00642] = 0x1EE12, [0x00643] = 0x1EE0A, [0x00644] = 0x1EE0B, [0x00645] = 0x1EE0C,
        [0x00646] = 0x1EE0D, [0x00647] = 0x1EE24, [0x00648] = 0x1EE05, [0x0064A] = 0x1EE09,
        [0x0066E] = 0x1EE1C, [0x0066F] = 0x1EE1F, [0x006A1] = 0x1EE1E, [0x006BA] = 0x1EE1D,
    },
    ucgreek   = {
        [0x0391]=0x1D6E2, [0x0392]=0x1D6E3, [0x0393]=0x1D6E4, [0x0394]=0x1D6E5, [0x0395]=0x1D6E6,
        [0x0396]=0x1D6E7, [0x0397]=0x1D6E8, [0x0398]=0x1D6E9, [0x0399]=0x1D6EA, [0x039A]=0x1D6EB,
        [0x039B]=0x1D6EC, [0x039C]=0x1D6ED, [0x039D]=0x1D6EE, [0x039E]=0x1D6EF, [0x039F]=0x1D6F0,
        [0x03A0]=0x1D6F1, [0x03A1]=0x1D6F2, [0x03A3]=0x1D6F4, [0x03A4]=0x1D6F5, [0x03A5]=0x1D6F6,
        [0x03A6]=0x1D6F7, [0x03A7]=0x1D6F8, [0x03A8]=0x1D6F9, [0x03A9]=0x1D6FA,
        },
    lcgreek   = {
        [0x03B1]=0x1D6FC, [0x03B2]=0x1D6FD, [0x03B3]=0x1D6FE, [0x03B4]=0x1D6FF, [0x03B5]=0x1D700,
        [0x03B6]=0x1D701, [0x03B7]=0x1D702, [0x03B8]=0x1D703, [0x03B9]=0x1D704, [0x03BA]=0x1D705,
        [0x03BB]=0x1D706, [0x03BC]=0x1D707, [0x03BD]=0x1D708, [0x03BE]=0x1D709, [0x03BF]=0x1D70A,
        [0x03C0]=0x1D70B, [0x03C1]=0x1D70C, [0x03C2]=0x1D70D, [0x03C3]=0x1D70E, [0x03C4]=0x1D70F,
        [0x03C5]=0x1D710, [0x03C6]=0x1D711, [0x03C7]=0x1D712, [0x03C8]=0x1D713, [0x03C9]=0x1D714,
        [0x03D1]=0x1D717, [0x03D5]=0x1D719, [0x03D6]=0x1D71B, [0x03F0]=0x1D718, [0x03F1]=0x1D71A,
        [0x03F4]=0x1D6F3, [0x03F5]=0x1D716,
    },
    symbols   = {
        [0x2202]=0x1D715, [0x2207]=0x1D6FB,
        [0x0027]=0x2032, -- prime
    },
}

local regular_bf= {
    digits    = todigit(0x1D7CE),
    ucletters = toupper(0x1D400),
    lcletters = tolower(0x1D41A),
    ucgreek   = {
        [0x0391]=0x1D6A8, [0x0392]=0x1D6A9, [0x0393]=0x1D6AA, [0x0394]=0x1D6AB, [0x0395]=0x1D6AC,
        [0x0396]=0x1D6AD, [0x0397]=0x1D6AE, [0x0398]=0x1D6AF, [0x0399]=0x1D6B0, [0x039A]=0x1D6B1,
        [0x039B]=0x1D6B2, [0x039C]=0x1D6B3, [0x039D]=0x1D6B4, [0x039E]=0x1D6B5, [0x039F]=0x1D6B6,
        [0x03A0]=0x1D6B7, [0x03A1]=0x1D6B8, [0x03A3]=0x1D6BA, [0x03A4]=0x1D6BB, [0x03A5]=0x1D6BC,
        [0x03A6]=0x1D6BD, [0x03A7]=0x1D6BE, [0x03A8]=0x1D6BF, [0x03A9]=0x1D6C0,
        },
    lcgreek   = {
        [0x03B1]=0x1D6C2, [0x03B2]=0x1D6C3, [0x03B3]=0x1D6C4, [0x03B4]=0x1D6C5, [0x03B5]=0x1D6C6,
        [0x03B6]=0x1D6C7, [0x03B7]=0x1D6C8, [0x03B8]=0x1D6C9, [0x03B9]=0x1D6CA, [0x03BA]=0x1D6CB,
        [0x03BB]=0x1D6CC, [0x03BC]=0x1D6CD, [0x03BD]=0x1D6CE, [0x03BE]=0x1D6CF, [0x03BF]=0x1D6D0,
        [0x03C0]=0x1D6D1, [0x03C1]=0x1D6D2, [0x03C2]=0x1D6D3, [0x03C3]=0x1D6D4, [0x03C4]=0x1D6D5,
        [0x03C5]=0x1D6D6, [0x03C6]=0x1D6D7, [0x03C7]=0x1D6D8, [0x03C8]=0x1D6D9, [0x03C9]=0x1D6DA,
        [0x03D1]=0x1D6DD, [0x03D5]=0x1D6DF, [0x03D6]=0x1D6E1, [0x03F0]=0x1D6DE, [0x03F1]=0x1D6E0,
        [0x03F4]=0x1D6B9, [0x03F5]=0x1D6DC,
    },
    symbols   = {
        [0x2202]=0x1D6DB, [0x2207]=0x1D6C1,
        [0x0027]=0x2032, -- prime
    },
}

local regular_bi = {
    digits    = tovector(regular_bf.digits),
    ucletters = toupper(0x1D468),
    lcletters = tolower(0x1D482),
    ucgreek   = {
        [0x0391]=0x1D71C, [0x0392]=0x1D71D, [0x0393]=0x1D71E, [0x0394]=0x1D71F, [0x0395]=0x1D720,
        [0x0396]=0x1D721, [0x0397]=0x1D722, [0x0398]=0x1D723, [0x0399]=0x1D724, [0x039A]=0x1D725,
        [0x039B]=0x1D726, [0x039C]=0x1D727, [0x039D]=0x1D728, [0x039E]=0x1D729, [0x039F]=0x1D72A,
        [0x03A0]=0x1D72B, [0x03A1]=0x1D72C, [0x03A3]=0x1D72E, [0x03A4]=0x1D72F, [0x03A5]=0x1D730,
        [0x03A6]=0x1D731, [0x03A7]=0x1D732, [0x03A8]=0x1D733, [0x03A9]=0x1D734,
        },
    lcgreek   = {
        [0x03B1]=0x1D736, [0x03B2]=0x1D737, [0x03B3]=0x1D738, [0x03B4]=0x1D739, [0x03B5]=0x1D73A,
        [0x03B6]=0x1D73B, [0x03B7]=0x1D73C, [0x03B8]=0x1D73D, [0x03B9]=0x1D73E, [0x03BA]=0x1D73F,
        [0x03BB]=0x1D740, [0x03BC]=0x1D741, [0x03BD]=0x1D742, [0x03BE]=0x1D743, [0x03BF]=0x1D744,
        [0x03C0]=0x1D745, [0x03C1]=0x1D746, [0x03C2]=0x1D747, [0x03C3]=0x1D748, [0x03C4]=0x1D749,
        [0x03C5]=0x1D74A, [0x03C6]=0x1D74B, [0x03C7]=0x1D74C, [0x03C8]=0x1D74D, [0x03C9]=0x1D74E,
        [0x03D1]=0x1D751, [0x03D5]=0x1D753, [0x03D6]=0x1D755, [0x03F0]=0x1D752, [0x03F1]=0x1D754,
        [0x03F4]=0x1D72D, [0x03F5]=0x1D750,
    },
    symbols   = {
        [0x2202]=0x1D74F, [0x2207]=0x1D735,
        [0x0027]=0x2032, -- prime
    },
}

local regular = {
    tf = regular_tf,
    it = regular_it,
    bf = regular_bf,
    bi = regular_bi,
}

local sansserif_tf = {
    digits    = todigit(0x1D7E2),
    ucletters = toupper(0x1D5A0),
    lcletters = tolower(0x1D5BA),
    lcgreek   = tovector(regular_tf.lcgreek),
    ucgreek   = tovector(regular_tf.ucgreek),
    symbols   = tovector(regular_tf.symbols),
}

local sansserif_it = {
    digits    = tovector(regular_tf.digits),
    ucletters = toupper(0x1D608),
    lcletters = tolower(0x1D622),
    lcgreek   = tovector(regular_tf.lcgreek),
    ucgreek   = tovector(regular_tf.ucgreek),
    symbols   = tovector(regular_tf.symbols),
}

local sansserif_bf = {
    digits    = todigit(0x1D7EC),
    ucletters = toupper(0x1D5D4),
    lcletters = tolower(0x1D5EE),
    ucgreek   = {
        [0x0391]=0x1D756, [0x0392]=0x1D757, [0x0393]=0x1D758, [0x0394]=0x1D759, [0x0395]=0x1D75A,
        [0x0396]=0x1D75B, [0x0397]=0x1D75C, [0x0398]=0x1D75D, [0x0399]=0x1D75E, [0x039A]=0x1D75F,
        [0x039B]=0x1D760, [0x039C]=0x1D761, [0x039D]=0x1D762, [0x039E]=0x1D763, [0x039F]=0x1D764,
        [0x03A0]=0x1D765, [0x03A1]=0x1D766, [0x03A3]=0x1D768, [0x03A4]=0x1D769, [0x03A5]=0x1D76A,
        [0x03A6]=0x1D76B, [0x03A7]=0x1D76C, [0x03A8]=0x1D76D, [0x03A9]=0x1D76E,
        },
    lcgreek   = {
        [0x03B1]=0x1D770, [0x03B2]=0x1D771, [0x03B3]=0x1D772, [0x03B4]=0x1D773, [0x03B5]=0x1D774,
        [0x03B6]=0x1D775, [0x03B7]=0x1D776, [0x03B8]=0x1D777, [0x03B9]=0x1D778, [0x03BA]=0x1D779,
        [0x03BB]=0x1D77A, [0x03BC]=0x1D77B, [0x03BD]=0x1D77C, [0x03BE]=0x1D77D, [0x03BF]=0x1D77E,
        [0x03C0]=0x1D77F, [0x03C1]=0x1D780, [0x03C2]=0x1D781, [0x03C3]=0x1D782, [0x03C4]=0x1D783,
        [0x03C5]=0x1D784, [0x03C6]=0x1D785, [0x03C7]=0x1D786, [0x03C8]=0x1D787, [0x03C9]=0x1D788,
        [0x03D1]=0x1D78B, [0x03D5]=0x1D78D, [0x03D6]=0x1D78F, [0x03F0]=0x1D78C, [0x03F1]=0x1D78E,
        [0x03F4]=0x1D767, [0x03F5]=0x1D78A,
    },
    symbols   = {
        [0x2202]=0x1D789, [0x2207]=0x1D76F,
        [0x0027]=0x2032, -- prime
    },
}

local sansserif_bi = {
    digits    = tovector(sansserif_bf.digits),
    ucletters = toupper(0x1D63C),
    lcletters = tolower(0x1D656),
    ucgreek   = {
        [0x0391]=0x1D790, [0x0392]=0x1D791, [0x0393]=0x1D792, [0x0394]=0x1D793, [0x0395]=0x1D794,
        [0x0396]=0x1D795, [0x0397]=0x1D796, [0x0398]=0x1D797, [0x0399]=0x1D798, [0x039A]=0x1D799,
        [0x039B]=0x1D79A, [0x039C]=0x1D79B, [0x039D]=0x1D79C, [0x039E]=0x1D79D, [0x039F]=0x1D79E,
        [0x03A0]=0x1D79F, [0x03A1]=0x1D7A0, [0x03A3]=0x1D7A2, [0x03A4]=0x1D7A3, [0x03A5]=0x1D7A4,
        [0x03A6]=0x1D7A5, [0x03A7]=0x1D7A6, [0x03A8]=0x1D7A7, [0x03A9]=0x1D7A8,
        },
    lcgreek   = {
        [0x03B1]=0x1D7AA, [0x03B2]=0x1D7AB, [0x03B3]=0x1D7AC, [0x03B4]=0x1D7AD, [0x03B5]=0x1D7AE,
        [0x03B6]=0x1D7AF, [0x03B7]=0x1D7B0, [0x03B8]=0x1D7B1, [0x03B9]=0x1D7B2, [0x03BA]=0x1D7B3,
        [0x03BB]=0x1D7B4, [0x03BC]=0x1D7B5, [0x03BD]=0x1D7B6, [0x03BE]=0x1D7B7, [0x03BF]=0x1D7B8,
        [0x03C0]=0x1D7B9, [0x03C1]=0x1D7BA, [0x03C2]=0x1D7BB, [0x03C3]=0x1D7BC, [0x03C4]=0x1D7BD,
        [0x03C5]=0x1D7BE, [0x03C6]=0x1D7BF, [0x03C7]=0x1D7C0, [0x03C8]=0x1D7C1, [0x03C9]=0x1D7C2,
        [0x03D1]=0x1D7C5, [0x03D5]=0x1D7C7, [0x03D6]=0x1D7C9, [0x03F0]=0x1D7C6, [0x03F1]=0x1D7C8,
        [0x03F4]=0x1D7A1, [0x03F5]=0x1D7C4,
    },
    symbols   = {
        [0x2202]=0x1D7C3, [0x2207]=0x1D7A9,
        [0x0027]=0x2032, -- prime
    },
}

local sansserif = {
    tf = sansserif_tf,
    it = sansserif_it,
    bf = sansserif_bf,
    bi = sansserif_bi,
}

local monospaced_tf = {
    digits    = todigit(0x1D7F6),
    ucletters = toupper(0x1D670),
    lcletters = tolower(0x1D68A),
    lcgreek   = tovector(sansserif_tf.lcgreek),
    ucgreek   = tovector(sansserif_tf.ucgreek),
    symbols   = tovector(sansserif_tf.symbols),
}

local monospaced_it = tovector(sansserif_it)
local monospaced_bf = tovector(sansserif_bf)
local monospaced_bi = tovector(sansserif_bi)

local monospaced = {
    tf = monospaced_tf,
    it = monospaced_tf,
    bf = monospaced_tf,
    bi = monospaced_bf,
}

local blackboard_tf = {
    digits    = todigit(0x1D7D8),
    ucletters = { -- C H N P Q R Z
        [0x00041]=0x1D538, [0x00042]=0x1D539, [0x00043]=0x02102, [0x00044]=0x1D53B, [0x00045]=0x1D53C,
        [0x00046]=0x1D53D, [0x00047]=0x1D53E, [0x00048]=0x0210D, [0x00049]=0x1D540, [0x0004A]=0x1D541,
        [0x0004B]=0x1D542, [0x0004C]=0x1D543, [0x0004D]=0x1D544, [0x0004E]=0x02115, [0x0004F]=0x1D546,
        [0x00050]=0x02119, [0x00051]=0x0211A, [0x00052]=0x0211D, [0x00053]=0x1D54A, [0x00054]=0x1D54B,
        [0x00055]=0x1D54C, [0x00056]=0x1D54D, [0x00057]=0x1D54E, [0x00058]=0x1D54F, [0x00059]=0x1D550,
        [0x0005A]=0x02124,
    },
    lcletters = {
        -- tolower(0x1D552) :
        [0x00061] = 0x1D552, [0x00062] = 0x1D553, [0x00063] = 0x1D554, [0x00064] = 0x1D555,
        [0x00065] = 0x1D556, [0x00066] = 0x1D557, [0x00067] = 0x1D558, [0x00068] = 0x1D559,
        [0x00069] = 0x1D55A, [0x0006A] = 0x1D55B, [0x0006B] = 0x1D55C, [0x0006C] = 0x1D55D,
        [0x0006D] = 0x1D55E, [0x0006E] = 0x1D55F, [0x0006F] = 0x1D560, [0x00070] = 0x1D561,
        [0x00071] = 0x1D562, [0x00072] = 0x1D563, [0x00073] = 0x1D564, [0x00074] = 0x1D565,
        [0x00075] = 0x1D566, [0x00076] = 0x1D567, [0x00077] = 0x1D568, [0x00078] = 0x1D569,
        [0x00079] = 0x1D56A, [0x0007A] = 0x1D56B,
        -- arabic
        [0x00628] = 0x1EEA1, [0x0062A] = 0x1EEB5, [0x0062B] = 0x1EEB6, [0x0062C] = 0x1EEA2,
        [0x0062D] = 0x1EEA7, [0x0062E] = 0x1EEB7, [0x0062F] = 0x1EEA3, [0x00630] = 0x1EEB8,
        [0x00631] = 0x1EEB3, [0x00632] = 0x1EEA6, [0x00633] = 0x1EEAE, [0x00634] = 0x1EEB4,
        [0x00635] = 0x1EEB1, [0x00636] = 0x1EEB9, [0x00637] = 0x1EEA8, [0x00638] = 0x1EEBA,
        [0x00639] = 0x1EEAF, [0x0063A] = 0x1EEBB, [0x00641] = 0x1EEB0, [0x00642] = 0x1EEB2,
        [0x00644] = 0x1EEAB, [0x00645] = 0x1EEAC, [0x00646] = 0x1EEAD, [0x00648] = 0x1EEA5,
        [0x0064A] = 0x1EEA9,
    },
    lcgreek   = { -- gamma pi
        [0x03B3]=0x0213C, [0x03C0]=0x0213D,
    },
    ucgreek   = { -- Gamma pi
        [0x0393]=0x0213E, [0x03A0]=0x0213F,
    },
    symbols   = { -- sum
        [0x2211]=0x02140,
        [0x0027]=0x2032, -- prime
    },
}

blackboard_tf.lcgreek = merged(regular_tf.lcgreek, blackboard_tf.lcgreek)
blackboard_tf.ucgreek = merged(regular_tf.ucgreek, blackboard_tf.ucgreek)
blackboard_tf.symbols = merged(regular_tf.symbols, blackboard_tf.symbols)

local blackboard = {
    tf = blackboard_tf,
    it = blackboard_tf,
    bf = blackboard_tf,
    bi = blackboard_tf,
}

local fraktur_tf= {
    digits    = tovector(regular_tf.digits),
    ucletters = { -- C H I R Z
        [0x00041]=0x1D504, [0x00042]=0x1D505, [0x00043]=0x0212D, [0x00044]=0x1D507, [0x00045]=0x1D508,
        [0x00046]=0x1D509, [0x00047]=0x1D50A, [0x00048]=0x0210C, [0x00049]=0x02111, [0x0004A]=0x1D50D,
        [0x0004B]=0x1D50E, [0x0004C]=0x1D50F, [0x0004D]=0x1D510, [0x0004E]=0x1D511, [0x0004F]=0x1D512,
        [0x00050]=0x1D513, [0x00051]=0x1D514, [0x00052]=0x0211C, [0x00053]=0x1D516, [0x00054]=0x1D517,
        [0x00055]=0x1D518, [0x00056]=0x1D519, [0x00057]=0x1D51A, [0x00058]=0x1D51B, [0x00059]=0x1D51C,
        [0x0005A]=0x02128,
    },
    lcletters = tolower(0x1D51E),
    lcgreek   = tovector(regular_tf.lcgreek),
    ucgreek   = tovector(regular_tf.ucgreek),
    symbols   = tovector(regular_tf.symbols),
}

local fraktur_bf = {
    digits    = tovector(regular_bf.digits),
    ucletters = toupper(0x1D56C),
    lcletters = tolower(0x1D586),
    lcgreek   = tovector(regular_bf.lcgreek),
    ucgreek   = tovector(regular_bf.ucgreek),
    symbols   = tovector(regular_bf.symbols),
}

local fraktur = { -- ok
    tf = fraktur_tf,
    bf = fraktur_bf,
    it = fraktur_tf,
    bi = fraktur_bf,
}

local script_tf = {
    digits    = tovector(regular_tf.digits),
    ucletters = { -- B E F H I L M R -- P 2118
        [0x00041]=0x1D49C, [0x00042]=0x0212C, [0x00043]=0x1D49E, [0x00044]=0x1D49F, [0x00045]=0x02130,
        [0x00046]=0x02131, [0x00047]=0x1D4A2, [0x00048]=0x0210B, [0x00049]=0x02110, [0x0004A]=0x1D4A5,
        [0x0004B]=0x1D4A6, [0x0004C]=0x02112, [0x0004D]=0x02133, [0x0004E]=0x1D4A9, [0x0004F]=0x1D4AA,
        [0x00050]=0x1D4AB, [0x00051]=0x1D4AC, [0x00052]=0x0211B, [0x00053]=0x1D4AE, [0x00054]=0x1D4AF,
        [0x00055]=0x1D4B0, [0x00056]=0x1D4B1, [0x00057]=0x1D4B2, [0x00058]=0x1D4B3, [0x00059]=0x1D4B4,
        [0x0005A]=0x1D4B5,
    },
    lcletters = { -- E G O -- L 2113
        [0x00061]=0x1D4B6, [0x00062]=0x1D4B7, [0x00063]=0x1D4B8, [0x00064]=0x1D4B9, [0x00065]=0x0212F,
        [0x00066]=0x1D4BB, [0x00067]=0x0210A, [0x00068]=0x1D4BD, [0x00069]=0x1D4BE, [0x0006A]=0x1D4BF,
        [0x0006B]=0x1D4C0, [0x0006C]=0x1D4C1, [0x0006D]=0x1D4C2, [0x0006E]=0x1D4C3, [0x0006F]=0x02134,
        [0x00070]=0x1D4C5, [0x00071]=0x1D4C6, [0x00072]=0x1D4C7, [0x00073]=0x1D4C8, [0x00074]=0x1D4C9,
        [0x00075]=0x1D4CA, [0x00076]=0x1D4CB, [0x00077]=0x1D4CC, [0x00078]=0x1D4CD, [0x00079]=0x1D4CE,
        [0x0007A]=0x1D4CF,
    },
    lcgreek = tovector(regular_tf.lcgreek),
    ucgreek = tovector(regular_tf.ucgreek),
    symbols = tovector(regular_tf.symbols),
}

local script_bf = {
    digits    = tovector(regular_bf.digits),
    ucletters = toupper(0x1D4D0),
    lcletters = tolower(0x1D4EA),
    lcgreek   = tovector(regular_bf.lcgreek),
    ucgreek   = tovector(regular_bf.ucgreek),
    symbols   = tovector(regular_bf.symbols),
}

local script = {
    tf = script_tf,
    bf = script_bf,
    it = script_tf,
    bi = script_bf,
}

local alphabets = allocate {
    regular    = regular,
    sansserif  = sansserif,
    monospaced = monospaced,
    blackboard = blackboard,
    fraktur    = fraktur,
    script     = script,
}

alphabets.tt          = tovector(monospaced)
alphabets.ss          = tovector(sansserif)
alphabets.rm          = tovector(regular)
alphabets.bb          = tovector(blackboard)
alphabets.fr          = tovector(fraktur)
alphabets.sr          = tovector(script)

monospaced.normal     = tovector(monospaced_tf)
monospaced.italic     = tovector(monospaced_it)
monospaced.bold       = tovector(monospaced_bf)
monospaced.bolditalic = tovector(monospaced_bi)

sansserif.normal      = tovector(sansserif_tf)
sansserif.italic      = tovector(sansserif_it)
sansserif.bold        = tovector(sansserif_bf)
sansserif.bolditalic  = tovector(sansserif_bi)

regular.normal        = tovector(regular_tf)
regular.italic        = tovector(regular_it)
regular.bold          = tovector(regular_bf)
regular.bolditalic    = tovector(regular_bi)

alphabets.serif       = tovector(regular)
alphabets.type        = tovector(monospaced)
alphabets.teletype    = tovector(monospaced)

mathematics.alphabets = alphabets

local mathremap       = allocate { }
mathematics.mapremap  = mathremap

local boldmap         = allocate { }
mathematics.boldmap   = boldmap

-- all math (a bit of redundancy here) (sorted for tracing)

for alphabet, styles in sortedhash(alphabets) do -- per 9/6/2011 we also have attr for missing
    for style, data in sortedhash(styles) do
     -- let's keep the long names (for tracing)
        local n = #mathremap + 1
        local d = {
            attribute = n,
            alphabet  = alphabet,
            style     = style,
        }
        styles[style] = d
        setmetatableindex(d,data) -- we could use a alphadata table
        mathremap[n] = d
    end
end

-- bold math

local function remapbold(tf,bf)
    local styles = mathematics.styles
    local sets   = mathematics.sets
    for i=1,#styles do
        for j=1,#sets do
            local one = styles[i]
            local two = sets[j]
            local a  = alphabets[one]
            local tf = a[tf][two]
            local bf = a[bf][two]
            if tf and bf then
                for k, v in next, tf do
                    boldmap[v] = bf[k]
                end
            end
        end
    end
end

remapbold("tf","bf")
remapbold("it","bi")

-- table.save("e:/tmp/a.lua",alphabets)
-- table.save("e:/tmp/b.lua",boldmap)

function mathematics.tostyle(attribute)
    local r = mathremap[attribute]
    return r and r.style or "tf"
end

function mathematics.toname(attribute)
    local r = mathremap[attribute]
    return r and r.alphabet or "regular"
end

-- of course we could do some div/mod trickery instead

local mathalphabet = attributes.private("mathalphabet")

function mathematics.getboth(alphabet,style)
    local data = alphabet and alphabets[alphabet] or regular
    data = data[style or "tf"] or data.tf
    return data and data.attribute
end

function mathematics.getstyle(style)
    local r = mathremap[texgetattribute(mathalphabet)]
    local alphabet = r and r.alphabet or "regular"
    local data = alphabets[alphabet][style]
    return data and data.attribute
end

function mathematics.syncboth(alphabet,style)
    local data = alphabet and alphabets[alphabet] or regular
    data = style and data[style] or data.tf
    texsetattribute(mathalphabet,data and data.attribute or texattribute[mathalphabet])
end

function mathematics.syncstyle(style)
    local r = mathremap[texgetattribute(mathalphabet)]
    local alphabet = r and r.alphabet or "regular"
    local data = alphabets[alphabet][style]
    texsetattribute(mathalphabet,data and data.attribute or texattribute[mathalphabet])
end

function mathematics.syncname(alphabet)
 -- local r = mathremap[mathalphabet]
    local r = mathremap[texgetattribute(mathalphabet)]
    local style = r and r.style or "tf"
    local data = alphabets[alphabet][style]
    texsetattribute(mathalphabet,data and data.attribute or texattribute[mathalphabet])
end

implement {
    name      = "setmathattribute",
    arguments = "2 strings",
    actions   = function(alphabet,style)
        local data = alphabets[alphabet] or regular
        data = data[style] or data.tf
        texsetattribute(mathalphabet,data and data.attribute or texattribute[mathalphabet])
    end
}

implement {
    name      = "setmathstyle",
    arguments = "string",
    actions   = function(style)
        local r = mathremap[texgetattribute(mathalphabet)]
        local alphabet = r and r.alphabet or "regular"
        local data = alphabets[alphabet][style]
        texsetattribute(mathalphabet,data and data.attribute or texattribute[mathalphabet])
    end
}

implement {
    name      = "setmathalphabet",
    arguments = "string",
    actions   = function(alphabet)
     -- local r = mathremap[mathalphabet]
        local r = mathremap[texgetattribute(mathalphabet)]
        local style = r and r.style or "tf"
        local data = alphabets[alphabet][style]
        texsetattribute(mathalphabet,data and data.attribute or texattribute[mathalphabet])
    end
}

local islcgreek = regular_tf.lcgreek
local isucgreek = regular_tf.ucgreek
local issygreek = regular_tf.symbols
local isgreek   = merged(islcgreek,isucgreek,issygreek)

local greekremapping = {
    [1] = { what = "unchanged" }, -- upright
    [2] = { what = "upright", it = "tf", bi = "bf" }, -- upright
    [3] = { what = "italic",  tf = "it", bf = "bi" }, -- italic
}

local usedremap = { }

local function resolver(map)
    return function (t,k)
        local v =
            map.digits   [k] or
            map.lcletters[k] or map.ucletters[k] or
            map.lcgreek  [k] or map.ucgreek  [k] or
            map.symbols  [k] or k
        t[k] = v
        return v
    end
end

for k, v in next, mathremap do
    local t = { }
    setmetatableindex(t,resolver(v))
    usedremap[k] = t
end

local function remapgreek(mathalphabet,how,detail,char)
    local r = mathremap[mathalphabet] -- what if 0
    local alphabet = r and r.alphabet or "regular"
    local style = r and r.style or "tf"
    local remapping = greekremapping[how]
    if trace_greek then
        report_remapping("greek %s, %s char %C, alphabet %a %a, method %a","before",detail,char,alphabet,style,remapping.what)
    end
    local newstyle = remapping[style]
    if newstyle then
        local data = alphabets[alphabet][newstyle] -- always something
        mathalphabet = data and data.attribute or mathalphabet
        style        = newstyle
    end
    if trace_greek then
        report_remapping("greek %s, %s char %C, alphabet %a %a, method %a","after",detail,char,alphabet,style,remapping.what)
    end
    return mathalphabet, style
end

function mathematics.remapalphabets(char,mathalphabet,mathgreek)
    if not mathalphabet then
        return
    end
    if mathgreek and mathgreek > 0 then
        if not isgreek[char] then
            -- nothing needed
        elseif islcgreek[char] then
            local lc = extract(mathgreek,4,4) --  (mathgreek >> 4) & ~(-1 << 4)
            if lc > 1 then
                mathalphabet = remapgreek(mathalphabet,lc,"lowercase",char)
            end
        elseif isucgreek[char] then
            local uc = extract(mathgreek,0,4) --  (mathgreek >> 0) & ~(-1 << 4)
            if uc > 1 then
                mathalphabet = remapgreek(mathalphabet,uc,"uppercase",char)
            end
        elseif issygreek[char] then
            local sy = extract(mathgreek,8,4) --  (mathgreek >> 8) & ~(-1 << 4)
            if sy > 1 then
                mathalphabet = remapgreek(mathalphabet,sy,"symbol",char)
            end
        end
    end
    if mathalphabet > 0 then
        local remap = usedremap[mathalphabet] -- redundant check
        if remap then
            local newchar = remap[char]
            return newchar ~= char and newchar
        end
    end
 -- return nil
end

-- begin of experiment

local fallback = {
    tf = "bf",
    it = "bi",
    bf = "tf",
    bi = "it",
}

function mathematics.fallbackstyleattr(attribute)
    local r = mathremap[attribute]
    local alphabet = r.alphabet or "regular"
    local style = r.style or "tf"
    local fback = fallback[style]
    if fback then
        local data = alphabets[alphabet][fback]
        if data then
            local attr = data.attribute
            return attribute ~= attr and attr
        end
    end
end

-- end of experiment

local function checkedcopy(characters,child,parent)
    for k, v in next, child do
        if not characters[v] then
            characters[v] = characters[parent[k]]
        end
    end
end

function mathematics.addfallbacks(main)
    local characters = main.characters
    checkedcopy(characters,regular.bf.ucgreek,regular.tf.ucgreek)
    checkedcopy(characters,regular.bf.lcgreek,regular.tf.lcgreek)
    checkedcopy(characters,regular.bi.ucgreek,regular.it.ucgreek)
    checkedcopy(characters,regular.bi.lcgreek,regular.it.lcgreek)
end
