if not modules then modules = { } end modules ['scrp-tib'] = {
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
local getfont            = nuts.getfont
----- getid              = nuts.getid
local getattr            = nuts.getattr
local ischar             = nuts.ischar

local insert_node_after  = nuts.insert_after
local insert_node_before = nuts.insert_before

local nodepool           = nuts.pool

local new_glue           = nodepool.glue
local new_penalty        = nodepool.penalty

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph

local a_scriptstatus     = attributes.private('scriptstatus')
local a_scriptinjection  = attributes.private('scriptinjection')

local categorytonumber   = scripts.categorytonumber
local numbertocategory   = scripts.numbertocategory
local hash               = scripts.hash
local numbertodataset    = scripts.numbertodataset

-- can be shared:

local fonthashes         = fonts.hashes
local parameters         = fonthashes.parameters

local space, stretch, shrink, lastfont

local inter_character_space_factor   = 1
local inter_character_stretch_factor = 1
local inter_character_shrink_factor  = 1

local function space_glue(current)
    local data = numbertodataset[getattr(current,a_scriptinjection)]
    if data then
        inter_character_space_factor   = data.inter_character_space_factor   or 1
        inter_character_stretch_factor = data.inter_character_stretch_factor or 1
        inter_character_shrink_factor  = data.inter_character_shrink_factor  or 1
    end
    local font = getfont(current)
    if lastfont ~= font then
        local pf = parameters[font]
        space    = pf.space
        stretch  = pf.space_stretch
        shrink   = pf.space_shrink
        lastfont = font
    end
    return new_glue(
        inter_character_space_factor   * space,
        inter_character_stretch_factor * stretch,
        inter_character_shrink_factor  * shrink
    )
end

local function insert_space_after(head,current)
    return insert_node_after(head,current,space_glue(current))
end

-- local function insert_space_before(head,current)
--     return insert_node_before(head,current,space_glue(current))
-- end

local function insert_zerowidthspace_before(head,current)
    return insert_node_before(head,current,new_glue(0))
end

local function insert_nobreakspace_before(head,current)
    head, current = insert_node_before(head,current,new_penalty(10000))
    return insert_node_before(head,current,space_glue(current))
end

-- more efficient is to check directly
--
-- local b_tsheg = 0x0F0B -- breaking
-- local n_tsheg = 0x0F0C -- nonbreaking
--
-- if char == b_tsheg then
--     head, current = insert_space_after(head,current)
-- end
--
-- but this is more general

local injectors = {
    breaking_tsheg = insert_space_after,
}

local function process(head,first,last)
    if first ~= last then
        local current = first
        while current do
            local char, id = ischar(current)
            local scriptstatus = getattr(current,a_scriptstatus)
            if scriptstatus and scriptstatus > 0 then
                local category = numbertocategory[scriptstatus]
                if category then
                    local injector = injectors[category]
                    if injector then
                        head, current = insert_space_after(head,current)
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
