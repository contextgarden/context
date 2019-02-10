if not modules then modules = { } end modules ['node-ini'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Most of the code that had accumulated here is now separated in
modules.</p>
--ldx]]--

-- this module is being reconstructed
--
-- todo: datatype table per node type

-- todo: query names with new node.subtypes

local next, type, tostring = next, type, tostring
local gsub = string.gsub
local concat, remove = table.concat, table.remove
local sortedhash, sortedkeys, swapped = table.sortedhash, table.sortedkeys, table.swapped

--[[ldx--
<p>Access to nodes is what gives <l n='luatex'/> its power. Here we
implement a few helper functions. These functions are rather optimized.</p>
--ldx]]--

--[[ldx--
<p>When manipulating node lists in <l n='context'/>, we will remove
nodes and insert new ones. While node access was implemented, we did
quite some experiments in order to find out if manipulating nodes
in <l n='lua'/> was feasible from the perspective of performance.</p>

<p>First of all, we noticed that the bottleneck is more with excessive
callbacks (some gets called very often) and the conversion from and to
<l n='tex'/>'s datastructures. However, at the <l n='lua'/> end, we
found that inserting and deleting nodes in a table could become a
bottleneck.</p>

<p>This resulted in two special situations in passing nodes back to
<l n='tex'/>: a table entry with value <type>false</type> is ignored,
and when instead of a table <type>true</type> is returned, the
original table is used.</p>

<p>Insertion is handled (at least in <l n='context'/> as follows. When
we need to insert a node at a certain position, we change the node at
that position by a dummy node, tagged <type>inline</type> which itself
has_attribute the original node and one or more new nodes. Before we pass
back the list we collapse the list. Of course collapsing could be built
into the <l n='tex'/> engine, but this is a not so natural extension.</p>

<p>When we collapse (something that we only do when really needed), we
also ignore the empty nodes. [This is obsolete!]</p>
--ldx]]--

-- local gf = node.direct.getfield
-- local n = table.setmetatableindex("number")
-- function node.direct.getfield(a,b) n[b] = n[b] + 1  print(b,n[b]) return gf(a,b) end

nodes               = nodes or { }
local nodes         = nodes
nodes.handlers      = nodes.handlers or { }

local mark          = utilities.storage.mark
local allocate      = utilities.storage.allocate
local formatcolumns = utilities.formatters.formatcolumns

local getsubtypes   = node.subtypes
local getvalues     = node.values

tex.magicconstants = { -- we use tex.constants for something else
    running  = -1073741824,
    maxdimen =  1073741823, -- 0x3FFFFFFF or 2^30-1
    trueinch =     4736286,
}

-- local listcodes = allocate {
--     [0] = "unknown",
--     [1] = "line",
--     [2] = "box",
--     [3] = "indent",
--     [4] = "alignment", -- row or column
--     [5] = "cell",
--     [6] = "equation",
--     [7] = "equationnumber",
-- }

local listcodes = mark(getsubtypes("list"))

-- local rulecodes = allocate {
--     [0] = "normal",
--     [1] = "box",
--     [2] = "image",
--     [3] = "empty",
--     [4] = "user",
-- }

local rulecodes = mark(getsubtypes("rule"))

if not rulecodes[5] then
    rulecodes[5] = "over"
    rulecodes[6] = "under"
    rulecodes[7] = "fraction"
    rulecodes[8] = "radical"
end

-- local dircodes =  mark(getsubtypes("dir"))

dircodes = allocate {
    [0] = "normal",
    [1] = "cancel",
}

-- local glyphcodes = allocate {
--     [ 1] = "character",
--     [ 2] = "ligature",
--     [ 4] = "ghost",
--     [ 8] = "left",
--     [16] = "right",
-- }

local glyphcodes = mark(getsubtypes("glyph"))

-- local disccodes = allocate {
--     [0] = "discretionary", -- \discretionary
--     [1] = "explicit",      -- \-
--     [2] = "automatic",     -- following a -
--     [3] = "regular",       -- by hyphenator: simple
--     [4] = "first",         -- by hyphenator: hard first item
--     [5] = "second",        -- by hyphenator: hard second item
-- }

local disccodes = mark(getsubtypes("disc"))

-- local gluecodes = allocate {
--     [  0] = "userskip",
--     [  1] = "lineskip",
--     [  2] = "baselineskip",
--     [  3] = "parskip",
--     [  4] = "abovedisplayskip",
--     [  5] = "belowdisplayskip",
--     [  6] = "abovedisplayshortskip",
--     [  7] = "belowdisplayshortskip",
--     [  8] = "leftskip",
--     [  9] = "rightskip",
--     [ 10] = "topskip",
--     [ 11] = "splittopskip",
--     [ 12] = "tabskip",
--     [ 13] = "spaceskip",
--     [ 14] = "xspaceskip",
--     [ 15] = "parfillskip",
--     [ 16] = "mathskip", -- experiment
--     [ 17] = "thinmuskip",
--     [ 18] = "medmuskip",
--     [ 19] = "thickmuskip",
--     [ 98] = "conditionalmathglue",
--     [ 99] = "muskip",
--     [100] = "leaders",
--     [101] = "cleaders",
--     [102] = "xleaders",
--     [103] = "gleaders",
-- }

local gluecodes = mark(getsubtypes("glue"))

-- local leadercodes = allocate {
--     [100] = "leaders",
--     [101] = "cleaders",
--     [102] = "xleaders",
--     [103] = "gleaders",
-- }

local leadercodes = mark(getsubtypes("leader"))

-- local fillcodes = allocate {
--     [0] = "stretch",
--     [1] = "fi",
--     [2] = "fil",
--     [3] = "fill",
--     [4] = "filll",
-- }

local fillcodes = mark(getsubtypes("fill"))

-- for now:

local boundarycodes = allocate {
    [0] = "cancel",
    [1] = "user",
    [2] = "protrusion",
    [3] = "word",
}

-- local boundarycodes = mark(getsubtypes("boundary"))

-- local penaltycodes = allocate { -- unfortunately not used (yet)
--     [ 0] = "userpenalty",
-- }

local penaltycodes = mark(getsubtypes("penalty"))

table.setmetatableindex(penaltycodes,function(t,k) return "userpenalty" end) -- not used anyway

-- local kerncodes = allocate {
--     [0] = "fontkern",
--     [1] = "userkern",
--     [2] = "accentkern",
--     [3] = "italiccorrection",
-- }

local kerncodes = mark(getsubtypes("kern"))

-- local margincodes = allocate {
--     [0] = "left",
--     [1] = "right",
-- }

local margincodes = mark(getsubtypes("marginkern"))

-- local mathcodes = allocate {
--     [0] = "beginmath",
--     [1] = "endmath",
-- }

local mathcodes = mark(getsubtypes("math"))

-- local noadcodes = allocate { -- simple nodes
--     [ 0] = "ord",
--     [ 1] = "opdisplaylimits",
--     [ 2] = "oplimits",
--     [ 3] = "opnolimits",
--     [ 4] = "bin",
--     [ 5] = "rel",
--     [ 6] = "open",
--     [ 7] = "close",
--     [ 8] = "punct",
--     [ 9] = "inner",
--     [10] = "under",
--     [11] = "over",
--     [12] = "vcenter",
-- }

local noadcodes = mark(getsubtypes("noad"))

-- local radicalcodes = allocate {
--     [0] = "radical",
--     [1] = "uradical",
--     [2] = "uroot",
--     [3] = "uunderdelimiter",
--     [4] = "uoverdelimiter",
--     [5] = "udelimiterunder",
--     [6] = "udelimiterover",
-- }

local radicalcodes = mark(getsubtypes("radical"))

-- local accentcodes = allocate {
--     [0] = "bothflexible",
--     [1] = "fixedtop",
--     [2] = "fixedbottom",
--     [3] = "fixedboth",
-- }

local accentcodes = mark(getsubtypes("accent"))

-- local fencecodes = allocate {
--     [0] = "unset",
--     [1] = "left",
--     [2] = "middle",
--     [3] = "right",
--     [4] = "no",
-- }

local fencecodes = mark(getsubtypes("fence"))

-- maybe we also need fractioncodes

local function simplified(t)
    local r = { }
    for k, v in next, t do
        r[k] = gsub(v,"_","")
    end
    return r
end

local nodecodes = simplified(node.types())
local whatcodes = simplified(node.whatsits and node.whatsits() or { })

local usercodes = allocate {
    [ 97] = "attribute",  -- a
    [100] = "number",     -- d
    [102] = "float",      -- f
    [108] = "lua",        -- l
    [110] = "node",       -- n
    [115] = "string",     -- s
    [116] = "token"       -- t
}

local noadoptions = allocate {
    set      =        0x08,
    unused_1 = 0x00 + 0x08,
    unused_2 = 0x01 + 0x08,
    axis     = 0x02 + 0x08,
    no_axis  = 0x04 + 0x08,
    exact    = 0x10 + 0x08,
    left     = 0x11 + 0x08,
    middle   = 0x12 + 0x08,
    right    = 0x14 + 0x08,
}

-- local directionvalues  = mark(getvalues("dir"))
-- local gluevalues       = mark(getvalues("glue"))
-- local literalvalues    = mark(getvalues("literal"))

local dirvalues = allocate {
    [0] = "TLT",
    [1] = "TRT",
    [2] = "LTL",
    [3] = "RTT",
}

local gluevalues = allocate {
    [0] = "normal",
    [1] = "fi",
    [2] = "fil",
    [3] = "fill",
    [4] = "filll",
}

local literalvalues = allocate {
    [0] = "origin",
    [1] = "page",
    [2] = "always",
    [3] = "raw",
    [4] = "text",
    [5] = "font",
    [6] = "special",
}

gluecodes        = allocate(swapped(gluecodes,gluecodes))
dircodes         = allocate(swapped(dircodes,dircodes))
boundarycodes    = allocate(swapped(boundarycodes,boundarycodes))
noadcodes        = allocate(swapped(noadcodes,noadcodes))
radicalcodes     = allocate(swapped(radicalcodes,radicalcodes))
nodecodes        = allocate(swapped(nodecodes,nodecodes))
whatcodes        = allocate(swapped(whatcodes,whatcodes))
listcodes        = allocate(swapped(listcodes,listcodes))
glyphcodes       = allocate(swapped(glyphcodes,glyphcodes))
kerncodes        = allocate(swapped(kerncodes,kerncodes))
penaltycodes     = allocate(swapped(penaltycodes,penaltycodes))
mathcodes        = allocate(swapped(mathcodes,mathcodes))
fillcodes        = allocate(swapped(fillcodes,fillcodes))
margincodes      = allocate(swapped(margincodes,margincodes))
disccodes        = allocate(swapped(disccodes,disccodes))
accentcodes      = allocate(swapped(accentcodes,accentcodes))
fencecodes       = allocate(swapped(fencecodes,fencecodes))
rulecodes        = allocate(swapped(rulecodes,rulecodes))
leadercodes      = allocate(swapped(leadercodes,leadercodes))
usercodes        = allocate(swapped(usercodes,usercodes))
noadoptions      = allocate(swapped(noadoptions,noadoptions))
dirvalues        = allocate(swapped(dirvalues,dirvalues))
gluevalues       = allocate(swapped(gluevalues,gluevalues))
literalvalues    = allocate(swapped(literalvalues,literalvalues))

if CONTEXTLMTXMODE then
    whatcodes.literal     = 0x1  whatcodes[0x1] = "literal"
    whatcodes.latelua     = 0x2  whatcodes[0x2] = "latelua"
    whatcodes.userdefined = 0x3  whatcodes[0x3] = "userdefined"
    whatcodes.savepos     = 0x4  whatcodes[0x4] = "savepos"
    whatcodes.save        = 0x5  whatcodes[0x5] = "save"
    whatcodes.restore     = 0x6  whatcodes[0x6] = "restore"
    whatcodes.setmatrix   = 0x7  whatcodes[0x7] = "setmatrix"
    whatcodes.open        = 0x8  whatcodes[0x8] = "open"
    whatcodes.close       = 0x9  whatcodes[0x9] = "close"
    whatcodes.write       = 0xA  whatcodes[0xA] = "write"
elseif not whatcodes.literal then
    whatcodes.literal     = whatcodes.pdfliteral
    whatcodes.save        = whatcodes.pdfsave
    whatcodes.restore     = whatcodes.pdfrestore
    whatcodes.setmatrix   = whatcodes.pdfsetmatrix
end

nodes.gluecodes            = gluecodes
nodes.dircodes             = dircodes
nodes.boundarycodes        = boundarycodes
nodes.noadcodes            = noadcodes
nodes.nodecodes            = nodecodes
nodes.whatcodes            = whatcodes
nodes.listcodes            = listcodes
nodes.glyphcodes           = glyphcodes
nodes.kerncodes            = kerncodes
nodes.penaltycodes         = penaltycodes
nodes.mathcodes            = mathcodes
nodes.fillcodes            = fillcodes
nodes.margincodes          = margincodes
nodes.disccodes            = disccodes
nodes.accentcodes          = accentcodes
nodes.radicalcodes         = radicalcodes
nodes.fencecodes           = fencecodes
nodes.rulecodes            = rulecodes
nodes.leadercodes          = leadercodes
nodes.usercodes            = usercodes
nodes.noadoptions          = noadoptions
nodes.dirvalues            = dirvalues
nodes.gluevalues           = gluevalues
nodes.literalvalues        = literalvalues

dirvalues.lefttoright = 0
dirvalues.righttoleft = 1

nodes.subtypes = allocate {
    [nodecodes.accent]     = accentcodes,
    [nodecodes.boundary]   = boundarycodes,
    [nodecodes.dir]        = dircodes,
    [nodecodes.disc]       = disccodes,
    [nodecodes.fence]      = fencecodes,
    [nodecodes.glue]       = gluecodes,
    [nodecodes.glyph]      = glyphcodes,
    [nodecodes.hlist]      = listcodes,
    [nodecodes.kern]       = kerncodes,
    [nodecodes.marginkern] = margincodes,
    [nodecodes.math]       = mathcodes,
    [nodecodes.noad]       = noadcodes,
    [nodecodes.penalty]    = penaltycodes,
    [nodecodes.radical]    = radicalcodes,
    [nodecodes.rule]       = rulecodes,
    [nodecodes.vlist]      = listcodes,
    [nodecodes.whatsit]    = whatcodes,
}

table.setmetatableindex(nodes.subtypes,function(t,k)
    local v = { }
    t[k] = v
    return v
end)

nodes.skipcodes            = gluecodes     -- more friendly
nodes.directioncodes       = dircodes      -- more friendly
nodes.whatsitcodes         = whatcodes     -- more official
nodes.marginkerncodes      = margincodes
nodes.discretionarycodes   = disccodes
nodes.directionvalues      = dirvalues     -- more friendly
nodes.skipvalues           = gluevalues    -- more friendly
nodes.literalvalues        = literalvalues -- more friendly

glyphcodes.glyph           = glyphcodes.character

listcodes.row              = listcodes.alignment
listcodes.column           = listcodes.alignment

kerncodes.kerning          = kerncodes.fontkern

kerncodes.italiccorrection = kerncodes.italiccorrection or 1 -- new

literalvalues.direct       = literalvalues.always

nodes.codes = allocate { -- mostly for listing
    glue        = skipcodes,
    boundary    = boundarycodes,
    noad        = noadcodes,
    node        = nodecodes,
    hlist       = listcodes,
    vlist       = listcodes,
    glyph       = glyphcodes,
    kern        = kerncodes,
    penalty     = penaltycodes,
    math        = mathnodes,
    fill        = fillcodes,
    margin      = margincodes,
    disc        = disccodes,
    whatsit     = whatcodes,
    accent      = accentcodes,
    fence       = fencecodes,
    rule        = rulecodes,
    leader      = leadercodes,
    user        = usercodes,
    noadoptions = noadoptions,
}

nodes.noadoptions = {
    set      =        0x08,
    unused_1 = 0x00 + 0x08,
    unused_2 = 0x01 + 0x08,
    axis     = 0x02 + 0x08,
    no_axis  = 0x04 + 0x08,
    exact    = 0x10 + 0x08,
    left     = 0x11 + 0x08,
    middle   = 0x12 + 0x08,
    right    = 0x14 + 0x08,
}

local report_codes = logs.reporter("nodes","codes")

function nodes.showcodes()
    local t = { }
    for name, codes in sortedhash(nodes.codes) do
        local sorted = sortedkeys(codes)
        for i=1,#sorted do
            local s = sorted[i]
            if type(s) ~= "number" then
                t[#t+1] = { name, s, codes[s] }
            end
        end
    end
    formatcolumns(t)
    for k=1,#t do
        report_codes (t[k])
    end
end

trackers.register("system.showcodes", nodes.showcodes)

if not nodecodes.dir then
    report_codes("use a newer version of luatex")
    os.exit()
end

-- We don't need this sanitize-after-callback in ConTeXt and by disabling it we
-- also have a way to check if LuaTeX itself does the right thing.

if node.fix_node_lists then
    node.fix_node_lists(false)
end
