if not modules then modules = { } end modules ['scrp-tib'] = {
    version   = 1.001,
    comment   = "companion to scrp-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local nuts               = nodes.nuts

local getnext            = nuts.getnext
local getattr            = nuts.getattr
local ischar             = nuts.ischar

local getscriptstatus    = scripts.getstatus

local inserters          = scripts.inserters
local colors             = scripts.colors

local injectors = {
    breaking_tsheg = inserters.space_after
}

colors.breaking_tsheg    = "trace:1"
colors.nonbreaking_tsheg = "trace:2"

local function process(head,first,last)
    if first ~= last then
        local current = first
        while current do
            local char, id = ischar(current)
            if char then
                local category = getscriptstatus(current)
                if category then
                    local injector = injectors[category]
                    if injector then
                        head, current = injector(head,current)
                    end
                end
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
    name     = "tibetan",
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
