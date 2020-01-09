if not modules then modules = { } end modules ['libs-imp-ghostscript'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkxl",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local libname = "zint"
local libfile = "libzint" -- what on unix?
-- local libfile = "/usr/local/lib/libzint.so"

local zintlib = resolvers.libraries.validoptional(libname)

if not zintlib then return end

local function okay()
    if resolvers.libraries.optionalloaded(libname,libfile) then
        okay = function() return true end
    else
        okay = function() return false end
    end
    return okay()
end

local zint     = utilities.zint or { }
utilities.zint = zint

local zintlib_execute = zintlib.execute

local next, type, unpack = next, type, unpack
local lower, gsub = string.lower, string.gsub

local mapping = {
    ["code 11"]           =  1, ["pharma one-track"]       = 51, ["aztec code"]              =  92,
    ["standard 2of5"]     =  2, ["pzn"]                    = 52, ["daft code"]               =  93,
    ["interleaved 2of5"]  =  3, ["pharma two-track"]       = 53, ["micro qr code"]           =  97,
    ["iata 2of5"]         =  4, ["pdf417"]                 = 55, ["hibc code 128"]           =  98,
    ["data logic"]        =  6, ["pdf417 trunc"]           = 56, ["hibc code 39"]            =  99,
    ["industrial 2of5"]   =  7, ["maxicode"]               = 57, ["hibc data matrix"]        = 102,
    ["code 39"]           =  8, ["qr code"]                = 58, ["hibc qr code"]            = 104,
    ["extended code 39"]  =  9, ["code 128-b"]             = 60, ["hibc pdf417"]             = 106,
    ["ean"]               = 13, ["ap standard customer"]   = 63, ["hibc micropdf417"]        = 108,
    ["ean + check"]       = 14, ["ap reply paid"]          = 66, ["hibc codablock-f"]        = 110,
    ["gs1-128"]           = 16, ["ap routing"]             = 67, ["hibc aztec code"]         = 112,
    ["codabar"]           = 18, ["ap redirection"]         = 68, ["dotcode"]                 = 115,
    ["code 128"]          = 20, ["isbn"]                   = 69, ["han xin code"]            = 116,
    ["leitcode"]          = 21, ["rm4scc"]                 = 70, ["rm mailmark"]             = 121,
    ["identcode"]         = 22, ["data matrix"]            = 71, ["aztec runes"]             = 128,
    ["code 16k"]          = 23, ["ean-14"]                 = 72, ["code 32"]                 = 129,
    ["code 49"]           = 24, ["vin (north america)"]    = 73, ["comp ean"]                = 130,
    ["code 93"]           = 25, ["codablock-f"]            = 74, ["comp gs1-128"]            = 131,
    ["flattermarken"]     = 28, ["nve-18"]                 = 75, ["comp databar omni"]       = 132,
    ["gs1 databar omni"]  = 29, ["japanese post"]          = 76, ["comp databar ltd"]        = 133,
    ["gs1 databar ltd"]   = 30, ["korea post"]             = 77, ["comp databar expom"]      = 134,
    ["gs1 databar expom"] = 31, ["gs1 databar stack"]      = 79, ["comp upc-a"]              = 135,
    ["telepen alpha"]     = 32, ["gs1 databar stack omni"] = 80, ["comp upc-e"]              = 136,
    ["upc-a"]             = 34, ["gs1 databar eso"]        = 81, ["comp databar stack"]      = 137,
    ["upc-a + check"]     = 35, ["planet"]                 = 82, ["comp databar stack omni"] = 138,
    ["upc-e"]             = 37, ["micropdf"]               = 84, ["comp databar eso"]        = 139,
    ["upc-e + check"]     = 38, ["usps onecode"]           = 85, ["channel code"]            = 140,
    ["postnet"]           = 40, ["uk plessey"]             = 86, ["code one"]                = 141,
    ["msi plessey"]       = 47, ["telepen numeric"]        = 87, ["grid matrix"]             = 142,
    ["fim"]               = 49, ["itf-14"]                 = 89, ["upnqr"]                   = 143,
    ["logmars"]           = 50, ["kix code"]               = 90, ["rmqr"]                    = 145,
}

table.setmetatableindex(mapping,function(t,k)
    local s = gsub(lower(k),"[^a-z0-9]","")
    local v = rawget(t,s) or false
    t[k] = v
    return v
end)

local report  = logs.reporter("zint")
local context = context
local shown   = false

----- f_rectangle = string.formatters["%sofill unitsquare xysized (%N,%N) shifted (%N,%N);"]

function zint.execute(specification)
    if okay() then
        local code = specification.code
        local text = specification.text
        if code then
            local id = mapping[code]
            if id then
                specification.code = id
                local result = zintlib_execute(specification)
                if result then
                    -- not that fast but if needed we can speed it up
                    context.startMPcode()
                    local rectangles = result.rectangles
                    local hexagons   = result.hexagons
                    local circles    = result.circles
                    local strings    = result.strings
                    if rectangles then
                        local n = #rectangles
                        for i=1,n do
                            local r = rectangles[i]
                            context("%sofill unitsquare xysized (%N,%N) shifted (%N,%N);",
                                i == n and "d" or "n",r[3],r[4],r[1],r[2])
                         -- rectangles[i] = f_rectangle(i == n and "d" or "n",r[3],r[4],r[1],r[2])
                        end
                     -- context("% t",rectangles)
                    end
                    if hexagons then
                        local n = #hexagons
                        for i=1,#hexagons do
                            context("%sofill (%N,%N)--(%N,%N)--(%N,%N)--(%N,%N)--(%N,%N)--(%N,%N)--cycle;",
                                i == n and "d" or "n",unpack(hexagons[i]))
                        end
                    end
                    if circles then
                        local n = #circles
                        for i=1,#circles do
                            local c = circles[i]
                            context("%sofill unitcircle scaled %N shifted (%N,%N);",
                                i == n and "d" or "n",c[3],c[1],c[2])
                        end
                    end
                    if strings then
                        -- We set the font at the encapsulating level.
                        for i=1,#strings do
                            local s = strings[i]
                            context('draw textext("%s") scaled (%N/10) shifted (%N,%N);',
                                s[4],s[3],s[1],s[2])
                        end
                    end
                    context.stopMPcode()
                end
            else
                report("unknown barcode alternative %a",code)
                if not shown then
                    report("")
                    report("valid barcode alternatives:")
                    report("")
                    local list = table.sortedkeys(mapping)
                    for i=1,#list do
                        report("  %s", list[i])
                    end
                    report("")
                    shown = true
                end
            end
        end
    end
end
