if not modules then modules = { } end modules ['math-ext'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_virtual = false trackers.register("math.virtual", function(v) trace_virtual = v end)

local basename = file.basename

local mathematics = mathematics
local characters  = characters

local report_math = logs.reporter("mathematics")

mathematics.extras = mathematics.extras or { }
local extras       = mathematics.extras

characters.math    = characters.math or { }
local mathdata     = characters.math
local chardata     = characters.data

function extras.add(unicode,t) -- todo: if already stored ...
    local min, max = mathematics.extrabase, mathematics.privatebase - 1
 -- if mathdata[unicode] or chardata[unicode] then
 --     report_math("extra %U overloads existing character",unicode)
 -- end
    if unicode >= min and unicode <= max then
        mathdata[unicode], chardata[unicode] = t, t
    else
        report_math("extra %U should be in range %U - %U",unicode,min,max)
    end
end

function extras.copy(target,original)
    local characters = target.characters
    local properties = target.properties
    local parameters = target.parameters
    for unicode, extradesc in next, mathdata do
        -- always, because in an intermediate step we can have a non math font
        local extrachar = characters[unicode]
        local nextinsize = extradesc.nextinsize
        if nextinsize then
            local first = 1
            local charused = unicode
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

-- 0xFE302 -- 0xFE320 for accents (gone with new lm/gyre)
--
-- extras.add(0xFE302, {
--     category="mn",
--     description="WIDE MATHEMATICAL HAT",
--     direction="nsm",
--     linebreak="cm",
--     mathclass="topaccent",
--     mathname="widehat",
--     mathstretch="h",
--     unicodeslot=0xFE302,
--     nextinsize={ 0x00302, 0x0005E },
-- } )
--
-- extras.add(0xFE303, {
--     category="mn",
--     cjkwd="a",
--     description="WIDE MATHEMATICAL TILDE",
--     direction="nsm",
--     linebreak="cm",
--     mathclass="topaccent",
--     mathname="widetilde",
--     mathstretch="h",
--     unicodeslot=0xFE303,
--     nextinsize={ 0x00303, 0x0007E },
-- } )

-- 0xFE321 -- 0xFE340 for missing characters

extras.add(0xFE321, {
    category="sm",
    description="MATHEMATICAL SHORT BAR",
 -- direction="on",
 -- linebreak="nu",
    mathclass="relation",
    mathname="mapstochar",
    unicodeslot=0xFE321,
} )

extras.add(0xFE322, {
    category="sm",
    description="MATHEMATICAL LEFT HOOK",
    mathclass="relation",
    mathname="lhook",
    unicodeslot=0xFE322,
} )

extras.add(0xFE323, {
    category="sm",
    description="MATHEMATICAL RIGHT HOOK",
    mathclass="relation",
    mathname="rhook",
    unicodeslot=0xFE323,
} )

extras.add(0xFE324, {
    category="sm",
    description="MATHEMATICAL SHORT BAR MIRRORED",
--  direction="on",
--  linebreak="nu",
    mathclass="relation",
    mathname="mapsfromchar",
    unicodeslot=0xFE324,
} )

--~ extras.add(0xFE304, {
--~   category="sm",
--~   description="TOP AND BOTTOM PARENTHESES",
--~   direction="on",
--~   linebreak="al",
--~   mathclass="doubleaccent",
--~   mathname="doubleparent",
--~   unicodeslot=0xFE304,
--~   accents={ 0x023DC, 0x023DD },
--~ } )

--~ extras.add(0xFE305, {
--~   category="sm",
--~   description="TOP AND BOTTOM BRACES",
--~   direction="on",
--~   linebreak="al",
--~   mathclass="doubleaccent",
--~   mathname="doublebrace",
--~   unicodeslot=0xFE305,
--~   accents={ 0x023DE, 0x023DF },
--~ } )

--~ \Umathchardef\braceld="0 "1 "FF07A
--~ \Umathchardef\bracerd="0 "1 "FF07B
--~ \Umathchardef\bracelu="0 "1 "FF07C
--~ \Umathchardef\braceru="0 "1 "FF07D
