if not modules then modules = { } end modules ['char-cjk'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local setmetatable = setmetatable
local insert = table.insert
local floor = math.floor
local formatters = string.formatters
local utfchar = utf.char

local ranges   = characters.ranges
local allocate = utilities.storage.allocate

-- Hangul Syllable

-- The following conversion is taken from unicode.org/reports/tr15/tr15-23.html#Hangul
-- but adapted to our needs.

-- local SBase = 0xAC00
--
-- local LBase, LCount = 0x1100, 19
-- local VBase, VCount = 0x1161, 21
-- local TBase, TCount = 0x11A7, 28
--
-- local NCount = VCount * TCount
-- local SCount = LCount * NCount
--
-- local function decomposed(unicode)
--     local SIndex = unicode - SBase
--     if SIndex >= 0 and SIndex < SCount then
--         local lead_consonant = LBase + floor( SIndex / NCount)
--         local medial_vowel   = VBase + floor((SIndex % NCount) / TCount)
--         local tail_consonant = TBase +        SIndex % TCount
--         if tail_consonant ~= TBase then
--             return lead_consonant, medial_vowel, tail_consonant
--         else
--             return lead_consonant, medial_vowel
--         end
--     end
-- end
--
-- Lua will optimize the inline constants so the next variant is
-- 10% faster. In practice this will go unnoticed, but it's also less
-- code, so let's do it. Pushing the constant section into the
-- function body saves 5%.

local function decomposed(unicode)
    local index = unicode - 0xAC00
    if index >= 0 and index < 19 * 21 * 28 then
        local lead_consonant = 0x1100 + floor( index / (21 * 28))
        local medial_vowel   = 0x1161 + floor((index % (21 * 28)) / 28)
        local tail_consonant = 0x11A7 +        index % 28
        if tail_consonant ~= 0x11A7 then
            return lead_consonant, medial_vowel, tail_consonant
        else
            return lead_consonant, medial_vowel
        end
    end
end

local lead_consonants = { [0] =
    "G", "GG", "N", "D", "DD", "R", "M", "B", "BB",
    "S", "SS", "", "J", "JJ", "C", "K", "T", "P", "H"
}

local medial_vowels = { [0] =
    "A", "AE", "YA", "YAE", "EO", "E", "YEO", "YE", "O",
    "WA", "WAE", "OE", "YO", "U", "WEO", "WE", "WI",
    "YU", "EU", "YI", "I"
}

local tail_consonants = { [0] =
    "", "G", "GG", "GS", "N", "NJ", "NH", "D", "L", "LG", "LM",
    "LB", "LS", "LT", "LP", "LH", "M", "B", "BS",
    "S", "SS", "NG", "J", "C", "K", "T", "P", "H"
}

-- local function description(unicode)
--     local index = unicode - 0xAC00
--     if index >= 0 and index < 19 * 21 * 28 then
--         local lead_consonant = floor( index / NCount)
--         local medial_vowel   = floor((index % NCount) / TCount)
--         local tail_consonant =        index % TCount
--         return formatters["HANGUL SYLLABLE %s%s%s"](
--             lead_consonants[lead_consonant],
--             medial_vowels  [medial_vowel  ],
--             tail_consonants[tail_consonant]
--         )
--     end
-- end

local function description(unicode)
    local index = unicode - 0xAC00
    if index >= 0 and index < 19 * 21 * 28 then
        local lead_consonant = floor( index / (21 * 28))
        local medial_vowel   = floor((index % (21 * 28)) / 28)
        local tail_consonant =        index % 28
        return formatters["HANGUL SYLLABLE %s%s%s"](
            lead_consonants[lead_consonant],
            medial_vowels  [medial_vowel  ],
            tail_consonants[tail_consonant]
        )
    end
end

-- so far

-- We have a [lead consonant,medial vowel,tail consonant] where the last one
-- is optional. For sort ranges we need the first one but some are collapsed.
-- Beware, we map to modern so the font should support it.

local function leadconsonant(unicode)
    return
 -- unicode  < 0xAC00 and nil       -- original
 -- unicode  > 0xD7AF and nil    or -- original
    unicode >= 0xD558 and 0x314E or -- 하 => ㅎ
    unicode >= 0xD30C and 0x314D or -- 파 => ㅍ
    unicode >= 0xD0C0 and 0x314C or -- 타 => ㅌ
    unicode >= 0xCE74 and 0x314B or -- 카 => ㅋ
    unicode >= 0xCC28 and 0x314A or -- 차 => ㅊ
    unicode >= 0xC790 and 0x3148 or -- 자 => ㅈ
    unicode >= 0xC544 and 0x3147 or -- 아 => ㅇ
    unicode >= 0xC0AC and 0x3145 or -- 사 => ㅅ
    unicode >= 0xBC14 and 0x3142 or -- 바 => ㅂ
    unicode >= 0xB9C8 and 0x3141 or -- 마 => ㅁ
    unicode >= 0xB77C and 0x3139 or -- 라 => ㄹ
    unicode >= 0xB2E4 and 0x3137 or -- 다 => ㄷ
    unicode >= 0xB098 and 0x3134 or -- 나 => ㄴ
    unicode >= 0xAC00 and 0x3131 or -- 가 => ㄱ
                          nil       -- can't happen
end

local remapped = { -- this might be merged into char-def.lua
    [0x1100] = 0x3131, -- G
    [0x1101] = 0x3132, -- GG
    [0x1102] = 0x3134, -- N
    [0x1103] = 0x3137, -- D
    [0x1104] = 0x3138, -- DD
    [0x1105] = 0x3139, -- R
 -- [0X111A] = 0x3140, -- LH used for last sound
    [0x1106] = 0x3141, -- M
    [0x1107] = 0x3142, -- B
    [0x1108] = 0x3143, -- BB
 -- [0x1121] = 0x3144, -- BS used for last sound
    [0x1109] = 0x3145, -- S
    [0x110A] = 0x3146, -- SS
    [0x110B] = 0x3147, -- (IEUNG) no sound but has form
    [0x110C] = 0x3148, -- J
    [0x110D] = 0x3149, -- JJ
    [0x110E] = 0x314A, -- C
    [0x110F] = 0x314B, -- K
    [0x1110] = 0x314C, -- T
    [0x1111] = 0x314D, -- P
    [0x1112] = 0x314E, -- H

    [0x1161] = 0x314F, -- A
    [0x1162] = 0x3150, -- AE
    [0x1163] = 0x3151, -- YA
    [0x1164] = 0x3152, -- YAE
    [0x1165] = 0x3153, -- EO
    [0x1166] = 0x3154, -- E
    [0x1167] = 0x3155, -- YEO
    [0x1168] = 0x3156, -- YE
    [0x1169] = 0x3157, -- O
    [0x116A] = 0x3158, -- WA
    [0x116B] = 0x3159, -- WAE
    [0x116C] = 0x315A, -- OE
    [0x116D] = 0x315B, -- YO
    [0x116E] = 0x315C, -- U
    [0x116F] = 0x315D, -- WEO
    [0x1170] = 0x315E, -- WE
    [0x1171] = 0x315F, -- WI
    [0x1172] = 0x3160, -- YU
    [0x1173] = 0x3161, -- EU
    [0x1174] = 0x3162, -- YI
    [0x1175] = 0x3163, -- I

    [0x11A8] = 0x3131, -- G
    [0x11A9] = 0x3132, -- GG
    [0x11AA] = 0x3133, -- GS
    [0x11AB] = 0x3134, -- N
    [0x11AC] = 0x3135, -- NJ
	[0x11AD] = 0x3136, -- NH
    [0x11AE] = 0x3137, -- D
    [0x11AF] = 0x3139, -- L
    [0x11B0] = 0x313A, -- LG
    [0x11B1] = 0x313B, -- LM
    [0x11B2] = 0x313C, -- LB
    [0x11B3] = 0x313D, -- LS
    [0x11B4] = 0x313E, -- LT
    [0x11B5] = 0x313F, -- LP
    [0x11B6] = 0x3140, -- LH
    [0x11B7] = 0x3141, -- M
    [0x11B8] = 0x3142, -- B
    [0x11B9] = 0x3144, -- BS
    [0x11BA] = 0x3145, -- S
    [0x11BB] = 0x3146, -- SS
    [0x11BC] = 0x3147, -- NG
    [0x11BD] = 0x3148, -- J
    [0x11BE] = 0x314A, -- C
    [0x11BF] = 0x314B, -- K
    [0x11C0] = 0x314C, -- T
    [0x11C1] = 0x314D, -- P
    [0x11C2] = 0x314E, -- H
}

characters.hangul = allocate {
    decomposed    = decomposed,
    description   = description,
    leadconsonant = leadconsonant,
    remapped      = remapped,
}

-- so far

local hangul_syllable_basetable = {
    category    = "lo",
    cjkwd       = "w",
    description = "<Hangul Syllable>",
    direction   = "l",
    linebreak   = "h2",
}

local hangul_syllable_metatable = {
    __index = function(t,k)
        local u = t.unicodeslot
        if k == "fscode" or k == "leadconsonant" then
            return leadconsonant(u)
        elseif k == "decomposed" then
            return { decomposed(u) }
        elseif k == "specials" then
            return { "char", decomposed(u) }
        elseif k == "description" then
            return description(u)
        else
            return hangul_syllable_basetable[k]
        end
    end
}

function characters.remap_hangul_syllabe(t)
    local tt = type(t)
    if tt == "number" then
        return remapped[t] or t
    elseif tt == "table" then
        local r = { }
        for i=1,#t do
            local ti = t[i]
            r[i] = remapped[ti] or ti
        end
        return r
    else
        return t
    end
end

local hangul_syllable_extender = function(k,v)
    local t = {
        unicodeslot = k,
    }
    setmetatable(t,hangul_syllable_metatable)
    return t
end

local hangul_syllable_range = {
    first    = 0xAC00,
    last     = 0xD7A3,
    extender = hangul_syllable_extender,
}

setmetatable(hangul_syllable_range, hangul_syllable_metatable)

-- CJK Ideograph

local cjk_ideograph_metatable = {
    __index = {
        category    = "lo",
        cjkwd       = "w",
        description = "<CJK Ideograph>",
        direction   = "l",
        linebreak   = "id",
    }
}

local cjk_ideograph_extender = function(k,v)
    local t = {
     -- shcode      = shcode,
        unicodeslot = k,
    }
    setmetatable(t,cjk_ideograph_metatable)
    return t
end

local cjk_ideograph_range = {
    first    = 0x4E00,
    last     = 0x9FBB,
    extender = cjk_ideograph_extender,
}

-- CJK Ideograph Extension A

local cjk_ideograph_extension_a_metatable = {
    __index = {
        category    = "lo",
        cjkwd       = "w",
        description = "<CJK Ideograph Extension A>",
        direction   = "l",
        linebreak   = "id",
    }
}

local cjk_ideograph_extension_a_extender = function(k,v)
    local t = {
     -- shcode      = shcode,
        unicodeslot = k,
    }
    setmetatable(t,cjk_ideograph_extension_a_metatable)
    return t
end

local cjk_ideograph_extension_a_range = {
    first    = 0x3400,
    last     = 0x4DB5,
    extender = cjk_ideograph_extension_a_extender,
}

-- CJK Ideograph Extension B

local cjk_ideograph_extension_b_metatable = {
    __index = {
        category    = "lo",
        cjkwd       = "w",
        description = "<CJK Ideograph Extension B>",
        direction   = "l",
        linebreak   = "id",
    }
}

local cjk_ideograph_extension_b_extender = function(k,v)
    local t = {
     -- shcode      = shcode,
        unicodeslot = k,
    }
    setmetatable(t,cjk_ideograph_extension_b_metatable)
    return t
end

local cjk_ideograph_extension_b_range = {
    first    = 0x20000,
    last     = 0x2A6D6,
    extender = cjk_ideograph_extension_b_extender,
}

-- Ranges

insert(ranges, hangul_syllable_range)
insert(ranges, cjk_ideograph_range)
insert(ranges, cjk_ideograph_extension_a_range)
insert(ranges, cjk_ideograph_extension_b_range)

-- Japanese
