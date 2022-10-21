if not modules then modules = { } end modules ['luatex-math'] = {
    version   = 1.001,
    comment   = "companion to luatex-math.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gaps = {
    [0x1D455] = 0x0210E,
    [0x1D49D] = 0x0212C,
    [0x1D4A0] = 0x02130,
    [0x1D4A1] = 0x02131,
    [0x1D4A3] = 0x0210B,
    [0x1D4A4] = 0x02110,
    [0x1D4A7] = 0x02112,
    [0x1D4A8] = 0x02133,
    [0x1D4AD] = 0x0211B,
    [0x1D4BA] = 0x0212F,
    [0x1D4BC] = 0x0210A,
    [0x1D4C4] = 0x02134,
    [0x1D506] = 0x0212D,
    [0x1D50B] = 0x0210C,
    [0x1D50C] = 0x02111,
    [0x1D515] = 0x0211C,
    [0x1D51D] = 0x02128,
    [0x1D53A] = 0x02102,
    [0x1D53F] = 0x0210D,
    [0x1D545] = 0x02115,
    [0x1D547] = 0x02119,
    [0x1D548] = 0x0211A,
    [0x1D549] = 0x0211D,
    [0x1D551] = 0x02124,
}

local function fixmath(tfmdata,key,value)
    if value then
        local characters = tfmdata.characters
        for gap, mess in pairs(gaps) do
            characters[gap] = characters[mess]
        end
    end
end

fonts.handlers.otf.features.register {
    name         = "fixmath",
    description  = "math font fixing",
    manipulators = {
        base = fixmath,
        node = fixmath,
    }
}

-- This emulation is experimental and work in progress. This plain support is
-- for testing only anyway. If needed disable the feature which is there mostly
-- for MS and HH (a side effect of their math project).

local emulate = true

local integrals = table.tohash { 8747, 8748, 8749, 8750, 8751, 8752, 8753, 8754,
8755, 8992, 8993, 10763, 10764, 10765, 10766, 10767, 10768, 10769, 10770, 10771,
10772, 10773, 10774, 10775, 10776, 10777, 10778, 10779, 10780 }

local italics = table.tohash { 8458, 8459, 8462, 8464, 8466, 8475, 8492, 8495,
8496, 8497, 8499, 8500, 119860, 119861, 119862, 119863, 119864, 119865, 119866,
119867, 119868, 119869, 119870, 119871, 119872, 119873, 119874, 119875, 119876,
119877, 119878, 119879, 119880, 119881, 119882, 119883, 119884, 119885, 119886,
119887, 119888, 119889, 119890, 119891, 119892, 119893, 119894, 119895, 119896,
119897, 119898, 119899, 119900, 119901, 119902, 119903, 119904, 119905, 119906,
119907, 119908, 119909, 119910, 119911, 119912, 119913, 119914, 119915, 119916,
119917, 119918, 119919, 119920, 119921, 119922, 119923, 119924, 119925, 119926,
119927, 119928, 119929, 119930, 119931, 119932, 119933, 119934, 119935, 119936,
119937, 119938, 119939, 119940, 119941, 119942, 119943, 119944, 119945, 119946,
119947, 119948, 119949, 119950, 119951, 119952, 119953, 119954, 119955, 119956,
119957, 119958, 119959, 119960, 119961, 119962, 119963, 119964, 119965, 119966,
119967, 119968, 119969, 119970, 119971, 119972, 119973, 119974, 119975, 119976,
119977, 119978, 119979, 119980, 119981, 119982, 119983, 119984, 119985, 119986,
119987, 119988, 119989, 119990, 119991, 119992, 119993, 119994, 119995, 119996,
119997, 119998, 119999, 120000, 120001, 120002, 120003, 120004, 120005, 120006,
120007, 120008, 120009, 120010, 120011, 120012, 120013, 120014, 120015, 120016,
120017, 120018, 120019, 120020, 120021, 120022, 120023, 120024, 120025, 120026,
120027, 120028, 120029, 120030, 120031, 120032, 120033, 120034, 120035, 120036,
120037, 120038, 120039, 120040, 120041, 120042, 120043, 120044, 120045, 120046,
120047, 120048, 120049, 120050, 120051, 120052, 120053, 120054, 120055, 120056,
120057, 120058, 120059, 120060, 120061, 120062, 120063, 120064, 120065, 120066,
120067, 120328, 120329, 120330, 120331, 120332, 120333, 120334, 120335, 120336,
120337, 120338, 120339, 120340, 120341, 120342, 120343, 120344, 120345, 120346,
120347, 120348, 120349, 120350, 120351, 120352, 120353, 120354, 120355, 120356,
120357, 120358, 120359, 120360, 120361, 120362, 120363, 120364, 120365, 120366,
120367, 120368, 120369, 120370, 120371, 120372, 120373, 120374, 120375, 120376,
120377, 120378, 120379, 120380, 120381, 120382, 120383, 120384, 120385, 120386,
120387, 120388, 120389, 120390, 120391, 120392, 120393, 120394, 120395, 120396,
120397, 120398, 120399, 120400, 120401, 120402, 120403, 120404, 120405, 120406,
120407, 120408, 120409, 120410, 120411, 120412, 120413, 120414, 120415, 120416,
120417, 120418, 120419, 120420, 120421, 120422, 120423, 120424, 120425, 120426,
120427, 120428, 120429, 120430, 120431, 120546, 120547, 120548, 120549, 120550,
120551, 120552, 120553, 120554, 120555, 120556, 120557, 120558, 120559, 120560,
120561, 120562, 120563, 120564, 120565, 120566, 120567, 120568, 120569, 120570,
120571, 120572, 120573, 120574, 120575, 120576, 120577, 120578, 120579, 120580,
120581, 120582, 120583, 120584, 120585, 120586, 120587, 120588, 120589, 120590,
120591, 120592, 120593, 120594, 120595, 120596, 120597, 120604, 120605, 120606,
120607, 120608, 120609, 120610, 120611, 120612, 120613, 120614, 120615, 120616,
120617, 120618, 120619, 120620, 120621, 120622, 120623, 120624, 120625, 120626,
120627, 120628, 120629, 120630, 120631, 120632, 120633, 120634, 120635, 120636,
120637, 120638, 120639, 120640, 120641, 120642, 120643, 120644, 120645, 120646,
120647, 120648, 120649, 120650, 120651, 120652, 120653, 120654, 120655, 120720,
120721, 120722, 120723, 120724, 120725, 120726, 120727, 120728, 120729, 120730,
120731, 120732, 120733, 120734, 120735, 120736, 120737, 120738, 120739, 120740,
120741, 120742, 120743, 120744, 120745, 120746, 120747, 120748, 120749, 120750,
120751, 120752, 120753, 120754, 120755, 120756, 120757, 120758, 120759, 120760,
120761, 120762, 120763, 120764, 120765, 120766, 120767, 120768, 120769, 120770,
120771 }

local function emulatelmtx(tfmdata,key,value)
    if tfmdata.mathparameters and not tfmdata.emulatedlmtx then
        tfmdata.fonts = { { id = 0 } }
        tfmdata.type = "virtual"
        tfmdata.properties.virtualized = true
    end
end

fonts.handlers.otf.features.register {
    name         = "emulate lmtx",
    description  = "emulate lmtx mode",
    default      = emulate,
    manipulators = { base = emulatelmtx },
}

local function emulatelmtx(tfmdata,key,value)
    if tfmdata.mathparameters and not tfmdata.emulatedlmtx then
        local targetcharacters   = tfmdata.characters
        local targetdescriptions = tfmdata.descriptions
        local factor             = tfmdata.parameters.factor
        local function getllx(u)
            local d = targetdescriptions[u]
            if d then
                local b = d.boundingbox
                if b then
                    local llx = b[1]
                    if llx < 0 then
                        return - llx
                    end
                end
            end
            return false
        end
        for u, c in next, targetcharacters do
            local uc = c.unicode or u
            if integrals[uc] then
                -- skip this one
            else
                local accent = c.top_accent
                local italic = c.italic
                local width  = c.width  or 0
                local llx    = getllx(u)
                local bl, br, tl, tr
                if llx then
                    llx   = llx * factor
                    width = width + llx
                    bl    = - llx
                    tl    = bl
                    c.commands = { { "right", llx }, { "slot", 0, u } }
                    if accent then
                        accent = accent + llx
                    end
                end
                if accent then
                    if italics[uc] then
                        c.top_accent = accent
                    else
                        c.top_accent = nil
                    end
                end
                if italic and italic ~= 0 then
                    width = width + italic
                    br    = - italic
                end
                c.width = width
                if italic then
                    c.italic = nil
                end
                if bl or br or tl or tr then
                    -- watch out: singular and _ because we are post copying / scaling
                    c.mathkern = {
                        bottom_left  = bl and { { height = 0,             kern = bl } } or nil,
                        bottom_right = br and { { height = 0,             kern = br } } or nil,
                        top_left     = tl and { { height = c.height or 0, kern = tl } } or nil,
                        top_right    = tr and { { height = c.height or 0, kern = tr } } or nil,
                    }
                end
            end
        end
        tfmdata.fonts = { { id = 0 } }
        tfmdata.type = "virtual"
        tfmdata.properties.virtualized = true
        tfmdata.emulatedlmtx = true
    end
end

fonts.handlers.otf.features.register {
    name         = "emulate lmtx",
    description  = "emulate lmtx mode",
    default      = emulate,
    manipulators = { base = emulatelmtx },
}
