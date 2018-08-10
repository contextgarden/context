if not modules then modules = { } end modules ['scrp-eth'] = {
    version   = 1.001,
    comment   = "companion to scrp-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- at some point I will review the script code but for the moment we
-- do it this way; so space settings like with cjk yet

local nuts               = nodes.nuts

local getnext            = nuts.getnext
local ischar             = nuts.ischar
local getattr            = nuts.getattr

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph

local a_scriptstatus     = attributes.private('scriptstatus')

local numbertocategory   = scripts.numbertocategory
local inserters          = scripts.inserters

-- syllable [zerowidthspace] syllable
-- syllable [zerowidthspace] word
-- syllable [zerowidthspace] sentence
-- word     [nobreakspace]   syllable
-- word     [space]          word
-- word     [space]          sentence
-- sentence [nobreakspace]   syllable
-- sentence [space]          word
-- sentence [space]          sentence


local injectors = { -- [previous] [current]
    ethiopic_syllable = {
        ethiopic_syllable = inserters.zerowidthspace_before,
        ethiopic_word     = inserters.nobreakspace_before,
        ethiopic_sentence = inserters.nobreakspace_before,
    },
    ethiopic_word = {
        ethiopic_syllable = inserters.space_before,
        ethiopic_word     = inserters.space_before,
        ethiopic_sentence = inserters.space_before,
    },
    ethiopic_sentence = {
        ethiopic_syllable = inserters.space_before,
        ethiopic_word     = inserters.space_before,
        ethiopic_sentence = inserters.space_before,
    },
}

local function process(head,first,last)
    if first ~= last then
        local injector = false
        local current = first
        while current do
            local char, id = ischar(current)
            if char then
                local scriptstatus = getattr(current,a_scriptstatus)
                local category     = numbertocategory[scriptstatus]
                if injector then
                    local action = injector[category]
                    if action then
                        action(head,current)
                    end
                end
                injector = injectors[category]
            end
            if current == last then
                break
            else
                current = getnext(current)
            end
        end
    end
end

scripts.installmethod {
    name     = "ethiopic",
    injector = process,
    datasets = {
        default = {
            inter_character_space_factor   = 1,
            inter_character_stretch_factor = 1,
            inter_character_shrink_factor  = 1,
        },
        half = {
            inter_character_space_factor   = 0.5,
            inter_character_stretch_factor = 0.5,
            inter_character_shrink_factor  = 0.5,
        },
        quarter = {
            inter_character_space_factor   = 0.25,
            inter_character_stretch_factor = 0.25,
            inter_character_shrink_factor  = 0.25,
        },
    },
}
