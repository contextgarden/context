if not modules then modules = { } end modules ['char-enc'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
 -- dataonly  = true,
}

-- Thanks to tex4ht for these mappings.

local next = next

local allocate, setinitializer = utilities.storage.allocate, utilities.storage.setinitializer

characters       = characters or { }
local characters = characters

characters.synonyms = allocate { -- afm mess
    angle              = 0x2220,
    anticlockwise      = 0x21BA,
    arrowaxisleft      = 0x2190,
    arrowaxisright     = 0x2192,
    arrowparrleftright = 0x21C6,
    arrowparrrightleft = 0x21C4,
    arrowtailleft      = 0x21A2,
    arrowtailright     = 0x21A3,
    arrowtripleleft    = 0x21DA,
    arrowtripleright   = 0x21DB,
    axisshort          = 0x2212,
    because            = 0x2235,
    between            = 0x226C,
    check              = 0x2713,
    circleasteris      = 0x229B,
    circleequal        = 0x2257,
    circleminus        = 0x229D,
    circleR            = 0x24C7,
    circlering         = 0x229A,
    circleS            = 0x24C8,
    clockwise          = 0x21BB,
    complement         = 0x2201,
    curlyleft          = 0x21AB,
    curlyright         = 0x21AC,
    dblarrowdwn        = 0x21CA,
    dblarrowheadleft   = 0x219E,
    dblarrowheadright  = 0x21A0,
    dblarrowleft       = 0x21C7,
    dblarrowright      = 0x21C9,
    dblarrowup         = 0x21C8,
    defines            = 0x225C,
    diamond            = 0x2662,
    diamondsolid       = 0x2666,
    difference         = 0x224F,
    dotplus            = 0x2214,
    downfall           = 0x22CE,
    equaldotleftright  = 0x2252,
    equaldotrightleft  = 0x2253,
    equalorfollows     = 0x22DF,
    equalorgreater     = 0x22DD,
    equalorless        = 0x22DC,
    equalorprecedes    = 0x22DE,
    equalsdots         = 0x2251,
    followsorcurly     = 0x227D,
    followsorequal     = 0x227F,
    forces             = 0x22A9,
    forcesbar          = 0x22AA,
    fork               = 0x22D4,
    frown              = 0x2322,
    geomequivalent     = 0x224E,
    greaterdbleqlless  = 0x22Da,
    greaterdblequal    = 0x2267,
    greaterlessequal   = 0x22DA,
    greaterorapproxeql = 0x227F,
    greaterorequalslant= 0x2265,
    greaterorless      = 0x2277,
    greaterorsimilar   = 0x2273,
    harpoondownleft    = 0x21C3,
    harpoondownright   = 0x21C2,
    harpoonleftright   = 0x21CC,
    harpoonrightleft   = 0x21CB,
    harpoonupleft      = 0x21BF,
    harpoonupright     = 0x21BE,
    intercal           = 0x22BA,
    intersectiondbl    = 0x22D2,
    lessdbleqlgreater  = 0x22DB,
    lessdblequal       = 0x2266,
    lessequalgreater   = 0x22DB,
    lessorapproxeql    = 0x227E,
    lessorequalslant   = 0x2264,
    lessorgreater      = 0x2276,
    lessorsimilar      = 0x2272,
    maltesecross       = 0xFFFD,
    measuredangle      = 0x2221,
    muchgreater        = 0x22D9,
    muchless           = 0x22D8,
    multimap           = 0x22B8,
    multiopenleft      = 0x22CB,
    multiopenright     = 0x22CC,
    nand               = 0x22BC,
    orunderscore       = 0x22BB,
    perpcorrespond     = 0x2259,
    precedesorcurly    = 0x227C,
    precedesorequal    = 0x227E,
    primereverse       = 0x2035,
    proportional       = 0x221D,
    revasymptequal     = 0x2243,
    revsimilar         = 0x223D,
    rightanglene       = 0x231D,
    rightanglenw       = 0x231C,
    rightanglese       = 0x231F,
    rightanglesw       = 0x231E,
    ringinequal        = 0x2256,
    satisfies          = 0x22A8,
    shiftleft          = 0x21B0,
    shiftright         = 0x21B1,
    smile              = 0x2323,
    sphericalangle     = 0x2222,
    square             = 0x25A1,
    squaredot          = 0x22A1,
    squareimage        = 0x228F,
    squareminus        = 0x229F,
    squaremultiply     = 0x22A0,
    squareoriginal     = 0x2290,
    squareplus         = 0x229E,
    squaresmallsolid   = 0x25AA,
    squaresolid        = 0x25A0,
    squiggleleftright  = 0x21AD,
    squiggleright      = 0x21DD,
    star               = 0x22C6,
    subsetdbl          = 0x22D0,
    subsetdblequal     = 0x2286,
    supersetdbl        = 0x22D1,
    supersetdblequa    = 0x2287,
    therefore          = 0x2234,
    triangle           = 0x25B5,
    triangledownsld    = 0x25BE,
    triangleinv        = 0x25BF,
    triangleleft       = 0x25C3,
    triangleleftequal  = 0x22B4,
    triangleleftsld    = 0x25C2,
    triangleright      = 0x25B9,
    trianglerightequal = 0x22B5,
    trianglerightsld   = 0x25B8,
    trianglesolid      = 0x25B4,
    uniondbl           = 0x22D3,
    uprise             = 0x22CF,
    Yen                = 0x00A5,
}

-- if not characters.enccodes then
--
--     local enccodes = { } characters.enccodes  = enccodes
--
--     for unicode, data in next, characters.data do
--         local encname = data.adobename or data.contextname
--         if encname then
--             enccodes[encname] = unicode
--         end
--     end
--
--     for name, unicode in next, characters.synonyms do
--         if not enccodes[name] then enccodes[name] = unicode end
--     end
--
-- end
--
-- storage.register("characters.enccodes", characters.enccodes, "characters.enccodes")

-- As this table is seldom used, we can delay its definition. Beware, this means
-- that table.print would not work on this file unless it is accessed once. This
-- why the serializer does a dummy access.

local enccodes      = allocate()
characters.enccodes = enccodes

 -- maybe omit context name -> then same as encodings.make_unicode_vector

local function initialize()
    for unicode, data in next, characters.data do
        local encname = data.adobename or data.contextname
        if encname then
            enccodes[encname] = unicode
        end
    end
    for name, unicode in next, characters.synonyms do
        if not enccodes[name] then
            enccodes[name] = unicode
        end
    end
end

setinitializer(enccodes,initialize)
