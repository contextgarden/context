if not modules then modules = { } end modules ['math-ext'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local basename = file.basename
local sortedhash  = table.sortedhash

local mathematics     = mathematics
local extras          = mathematics.extras or { }
mathematics.extras    = extras

local characters      = characters
local chardata        = characters.data
local mathpairs       = characters.mathpairs

local trace_virtual   = false
local report_math     = logs.reporter("mathematics")

trackers.register("math.virtual", function(v) trace_virtual = v end)

local mathplus        = { }

-- todo: store them and skip storage if already stored
-- todo: make a char-ctx.lua (or is this already side effect of save in format)

local function addextra(unicode)
    local min = mathematics.extrabase
    local max = min + 0xFFF
    if unicode >= min and unicode <= max then
        if chardata[unicode] then
            mathplus[unicode] = true
        else
            report_math("extra %U is not a registered code point",unicode)
        end
    else
        report_math("extra %U should be in range %U - %U",unicode,min,max)
    end
end

extras.add = addextra

function extras.copy(target,original)
    local characters = target.characters
    local properties = target.properties
    local parameters = target.parameters
    for unicode in sortedhash(mathplus) do
        local extradesc  = chardata[unicode]
        local nextinsize = extradesc.nextinsize
        if nextinsize then
            local extrachar = characters[unicode]
            local first     = 1
            local charused  = unicode
            if not extrachar then
                for i=1,#nextinsize do
                    local slot = nextinsize[i]
                    extrachar = characters[slot]
                    if extrachar then
                        characters[unicode] = extrachar
                        first = i + 1
                        charused = slot
                        break
                    end
                end
            end
            if not extrachar then
                if trace_virtual then
                    report_math("extra %U in %a at %p with class %a and name %a is not mapped",
                        unicode,basename(properties.fullname),parameters.size,
                        extradesc.mathclass,extradesc.mathname)
                end
            elseif not extrachar.next then
                local nextused = false
                for i=first,#nextinsize do
                    local nextslot = nextinsize[i]
                    local nextbase = characters[nextslot]
                    if nextbase then
                        local nextnext = nextbase and nextbase.next
                        if nextnext then
                            local nextchar = characters[nextnext]
                            if nextchar then
                                extrachar.next = nextchar
                                nextused = nextslot
                                break
                            end
                        end
                    end
                end
                if trace_virtual then
                    if nextused then
                        report_math("extra %U in %a at %p with class %a and name %a maps onto %U with next %U",
                            unicode,basename(properties.fullname),parameters.size,charused,
                            extradesc.mathclass,extradesc.mathname,nextused)
                    else
                        report_math("extra %U in %a at %p with class %a and name %a maps onto %U with no next",
                            unicode,basename(properties.fullname),parameters.size,charused,
                            extradesc.mathclass,extradesc.mathname)
                    end
                end
            else
                if trace_virtual then
                    report_math("extra %U in %a at %p with class %a and name %a maps onto %U with no next", -- own next
                        unicode,basename(properties.fullname),parameters.size,charused,
                        extradesc.mathclass,extradesc.mathname)
                end
            end
        end
    end
end

utilities.sequencers.appendaction(mathactions,"system","mathematics.extras.copy")

extras.add(0xFE321)
extras.add(0xFE322)
extras.add(0xFE323)
extras.add(0xFE324)
