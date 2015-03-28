if not modules then modules = { } end modules ['math-ren'] = {
    version   = 1.001,
    comment   = "companion to math-ren.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next
local gsub = string.gsub

local settings_to_array = utilities.parsers.settings_to_array
local allocate          = storage.allocate

local renderings        = { }
mathematics.renderings  = renderings

local mappings          = allocate()
renderings.mappings     = mappings

local numbers           = allocate()
renderings.numbers      = numbers

local sets              = allocate()
renderings.sets         = sets

mappings["blackboard-to-bold"] = {
    [0x1D538] = 0x1D400, [0x1D539] = 0x1D401, [0x02102] = 0x1D402, [0x1D53B] = 0x1D403, [0x1D53C] = 0x1D404,
    [0x1D53D] = 0x1D405, [0x1D53E] = 0x1D406, [0x0210D] = 0x1D407, [0x1D540] = 0x1D408, [0x1D541] = 0x1D409,
    [0x1D542] = 0x1D40A, [0x1D543] = 0x1D40B, [0x1D544] = 0x1D40C, [0x02115] = 0x1D40D, [0x1D546] = 0x1D40E,
    [0x02119] = 0x1D40F, [0x0211A] = 0x1D410, [0x0211D] = 0x1D411, [0x1D54A] = 0x1D412, [0x1D54B] = 0x1D413,
    [0x1D54C] = 0x1D414, [0x1D54D] = 0x1D415, [0x1D54E] = 0x1D416, [0x1D54F] = 0x1D417, [0x1D550] = 0x1D418,
    [0x02124] = 0x1D419,
}

local function renderset(list) -- order matters
    local tag = gsub(list," ","")
    local n = sets[tag]
    if not n then
        local list = settings_to_array(tag)
        local mapping = { }
        for i=1,#list do
            local m = mappings[list[i]]
            if m then
                for k, v in next, m do
                    mapping[k] = v
                end
            end
        end
        if next(mapping) then
            n = #numbers + 1
            numbers[n] = mapping
        else
            n = attributes.unsetvalue
        end
        sets[tag] = n
    end
    return n
end

mathematics.renderset = renderset

interfaces.implement {
    name      = "mathrenderset",
    actions   = { renderset, context },
    arguments = "string",
}
