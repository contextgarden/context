if not modules then modules = { } end modules ['char-scr'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber

characters.scripthash = { -- we could put these presets in char-def.lua
    --
    -- half width opening parenthesis
    --
    [0x0028] = "half_width_open",
    [0x005B] = "half_width_open",
    [0x007B] = "half_width_open",
    [0x2018] = "half_width_open", -- ‘
    [0x201C] = "half_width_open", -- “
    --
    -- full width opening parenthesis
    --
    [0x3008] = "full_width_open", -- 〈   Left book quote
    [0x300A] = "full_width_open", -- 《   Left double book quote
    [0x300C] = "full_width_open", -- 「   left quote
    [0x300E] = "full_width_open", -- 『   left double quote
    [0x3010] = "full_width_open", -- 【   left double book quote
    [0x3014] = "full_width_open", -- 〔   left book quote
    [0x3016] = "full_width_open", --〖   left double book quote
    [0x3018] = "full_width_open", --     left tortoise bracket
    [0x301A] = "full_width_open", --     left square bracket
    [0x301D] = "full_width_open", --     reverse double prime qm
    [0xFF08] = "full_width_open", -- （   left parenthesis
    [0xFF3B] = "full_width_open", -- ［   left square brackets
    [0xFF5B] = "full_width_open", -- ｛   left curve bracket
    --
    -- half width closing parenthesis
    --
    [0x0029] = "half_width_close",
    [0x005D] = "half_width_close",
    [0x007D] = "half_width_close",
    [0x2019] = "half_width_close", -- ’   right quote, right
    [0x201D] = "half_width_close", -- ”   right double quote
    --
    -- full width closing parenthesis
    --
    [0x3009] = "full_width_close", -- 〉   book quote
    [0x300B] = "full_width_close", -- 》   double book quote
    [0x300D] = "full_width_close", -- 」   right quote, right
    [0x300F] = "full_width_close", -- 』   right double quote
    [0x3011] = "full_width_close", -- 】   right double book quote
    [0x3015] = "full_width_close", -- 〕   right book quote
    [0x3017] = "full_width_close", -- 〗  right double book quote
    [0x3019] = "full_width_close", --     right tortoise bracket
    [0x301B] = "full_width_close", --     right square bracket
    [0x301E] = "full_width_close", --     double prime qm
    [0x301F] = "full_width_close", --     low double prime qm
    [0xFF09] = "full_width_close", -- ）   right parenthesis
    [0xFF3D] = "full_width_close", -- ］   right square brackets
    [0xFF5D] = "full_width_close", -- ｝   right curve brackets
    --
    [0xFF62] = "half_width_open", --     left corner bracket
    [0xFF63] = "half_width_close", --     right corner bracket
    --
    -- vertical opening vertical
    --
    -- 0xFE35, 0xFE37, 0xFE39,  0xFE3B,  0xFE3D,  0xFE3F,  0xFE41,  0xFE43,  0xFE47,
    --
    -- vertical closing
    --
    -- 0xFE36, 0xFE38, 0xFE3A,  0xFE3C,  0xFE3E,  0xFE40,  0xFE42,  0xFE44,  0xFE48,
    --
    -- half width opening punctuation
    --
    -- <empty>
    --
    -- full width opening punctuation
    --
    --  0x2236, -- ∶
    --  0xFF0C, -- ，
    --
    -- half width closing punctuation_hw
    --
    [0x0021] = "half_width_close", -- !
    [0x002C] = "half_width_close", -- ,
    [0x002E] = "half_width_close", -- .
    [0x003A] = "half_width_close", -- :
    [0x003B] = "half_width_close", -- ;
    [0x003F] = "half_width_close", -- ?
    [0xFF61] = "half_width_close", -- hw full stop
    --
    -- full width closing punctuation
    --
    [0x3001] = "full_width_close", -- 、
    [0x3002] = "full_width_close", -- 。
    [0xFF0C] = "full_width_close", -- ，
    [0xFF0E] = "full_width_close", --
    --
    -- depends on font
    --
    [0xFF01] = "full_width_close", -- ！
    [0xFF1F] = "full_width_close", -- ？
    --
    [0xFF1A] = "full_width_punct", -- ：
    [0xFF1B] = "full_width_punct", -- ；
    --
    -- non starter
    --
    [0x3005] = "non_starter", [0x3041] = "non_starter", [0x3043] = "non_starter", [0x3045] = "non_starter", [0x3047] = "non_starter",
    [0x3049] = "non_starter", [0x3063] = "non_starter", [0x3083] = "non_starter", [0x3085] = "non_starter", [0x3087] = "non_starter",
    [0x308E] = "non_starter", [0x3095] = "non_starter", [0x3096] = "non_starter", [0x309B] = "non_starter", [0x309C] = "non_starter",
    [0x309D] = "non_starter", [0x309E] = "non_starter", [0x30A0] = "non_starter", [0x30A1] = "non_starter", [0x30A3] = "non_starter",
    [0x30A5] = "non_starter", [0x30A7] = "non_starter", [0x30A9] = "non_starter", [0x30C3] = "non_starter", [0x30E3] = "non_starter",
    [0x30E5] = "non_starter", [0x30E7] = "non_starter", [0x30EE] = "non_starter", [0x30F5] = "non_starter", [0x30F6] = "non_starter",
    [0x30FC] = "non_starter", [0x30FD] = "non_starter", [0x30FE] = "non_starter", [0x31F0] = "non_starter", [0x31F1] = "non_starter",
    [0x31F2] = "non_starter", [0x31F3] = "non_starter", [0x31F4] = "non_starter", [0x31F5] = "non_starter", [0x31F6] = "non_starter",
    [0x31F7] = "non_starter", [0x31F8] = "non_starter", [0x31F9] = "non_starter", [0x31FA] = "non_starter", [0x31FB] = "non_starter",
    [0x31FC] = "non_starter", [0x31FD] = "non_starter", [0x31FE] = "non_starter", [0x31FF] = "non_starter",
    --
    [0x301C] = "non_starter", [0x303B] = "non_starter", [0x303C] = "non_starter", [0x309B] = "non_starter", [0x30FB] = "non_starter",
    [0x30FE] = "non_starter",
    -- hyphenation
    --
    [0x2026] = "hyphen", -- …   ellipsis
    [0x2014] = "hyphen", -- —   hyphen
    --
    [0x1361] = "ethiopic_word",
    [0x1362] = "ethiopic_sentence",
    --
    -- tibetan:
    --
    [0x0F0B] = "breaking_tsheg",
    [0x0F0C] = "nonbreaking_tsheg",

}

table.setmetatableindex(characters.scripthash, function(t,k)
    local v
    if not tonumber(k)                     then v = false
    elseif (k >= 0x03040 and k <= 0x030FF)
        or (k >= 0x031F0 and k <= 0x031FF)
        or (k >= 0x032D0 and k <= 0x032FE)
        or (k >= 0x0FF00 and k <= 0x0FFEF) then v = "katakana"
    elseif (k >= 0x03400 and k <= 0x04DFF)
        or (k >= 0x04E00 and k <= 0x09FFF)
        or (k >= 0x0F900 and k <= 0x0FAFF)
        or (k >= 0x20000 and k <= 0x2A6DF)
        or (k >= 0x2F800 and k <= 0x2FA1F) then v = "chinese"
    elseif (k >= 0x0AC00 and k <= 0x0D7A3) then v = "korean"
    elseif (k >= 0x01100 and k <= 0x0115F) then v = "jamo_initial"
    elseif (k >= 0x01160 and k <= 0x011A7) then v = "jamo_medial"
    elseif (k >= 0x011A8 and k <= 0x011FF) then v = "jamo_final"
    elseif (k >= 0x01200 and k <= 0x0139F) then v = "ethiopic_syllable"
    elseif (k >= 0x00F00 and k <= 0x00FFF) then v = "tibetan"
                                           else v = false
    end
    t[k] = v
    return v
end)

-- storage.register("characters/scripthash", hash, "characters.scripthash")
