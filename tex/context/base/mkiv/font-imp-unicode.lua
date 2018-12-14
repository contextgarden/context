if not modules then modules = { } end modules ['font-imp-unicode'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then return end

local next = next

local fonts              = fonts
local helpers            = fonts.helpers
local constructors       = fonts.constructors
local registerotffeature = fonts.handlers.otf.features.register

local extraprivates      = helpers.extraprivates
local addprivate         = helpers.addprivate

local function initialize(tfmdata)
    for i=1,#extraprivates do
        local e = extraprivates[i]
        local c = e[2](tfmdata)
        if c then
            addprivate(tfmdata, e[1], c)
        end
    end
end

constructors.newfeatures.otf.register {
    name        = "extraprivates",
    description = "extra privates",
    default     = true,
    manipulators = {
        base = initialize,
        node = initialize,
    }
}

local tounicode = fonts.mappings.tounicode

local function initialize(tfmdata,key,value)
    if value == "ligatures" then
        local private   = fonts.constructors and fonts.constructors.privateoffset or 0xF0000
        local collected = fonts.handlers.otf.readers.getcomponents(tfmdata.shared.rawdata)
        if collected and next(collected)then
            for unicode, char in next, tfmdata.characters do
                local u = collected[unicode]
                if u then
                    local n = #u
                    for i=1,n do
                        if u[i] > private then
                            n = 0
                            break
                        end
                    end
                    if n > 0 then
                        if n == 1 then
                            u = u[1]
                        end
                        char.unicode   = u
                        char.tounicode = tounicode(u)
                    end
                end
            end
        end
    end
end

-- forceunicodes=ligatures : aggressive lig resolving (e.g. for emoji)
--
-- kind of like: \enabletrackers[fonts.mapping.forceligatures]

registerotffeature {
    name         = "forceunicodes",
    description  = "forceunicodes",
    manipulators = {
        base = initialize,
        node = initialize,
    }
}
