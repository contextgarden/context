if not modules then modules = { } end modules ['node-ini'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Most of the code that had accumulated here is now separated in modules.</p>
--ldx]]--

-- I need to clean up this module as it's a bit of a mess now. The latest luatex
-- has most tables but we have a few more in luametatex. Also, some are different
-- between these engines. We started out with hardcoded tables, that then ended
-- up as comments and are now gone (as they differ per engine anyway).

local next, type, tostring = next, type, tostring
local gsub = string.gsub
local concat, remove = table.concat, table.remove
local sortedhash, sortedkeys, swapped = table.sortedhash, table.sortedkeys, table.swapped

--[[ldx--
<p>Access to nodes is what gives <l n='luatex'/> its power. Here we implement a
few helper functions. These functions are rather optimized.</p>
--ldx]]--

--[[ldx--
<p>When manipulating node lists in <l n='context'/>, we will remove nodes and
insert new ones. While node access was implemented, we did quite some experiments
in order to find out if manipulating nodes in <l n='lua'/> was feasible from the
perspective of performance.</p>

<p>First of all, we noticed that the bottleneck is more with excessive callbacks
(some gets called very often) and the conversion from and to <l n='tex'/>'s
datastructures. However, at the <l n='lua'/> end, we found that inserting and
deleting nodes in a table could become a bottleneck.</p>

<p>This resulted in two special situations in passing nodes back to <l n='tex'/>:
a table entry with value <type>false</type> is ignored, and when instead of a
table <type>true</type> is returned, the original table is used.</p>

<p>Insertion is handled (at least in <l n='context'/> as follows. When we need to
insert a node at a certain position, we change the node at that position by a
dummy node, tagged <type>inline</type> which itself has_attribute the original
node and one or more new nodes. Before we pass back the list we collapse the
list. Of course collapsing could be built into the <l n='tex'/> engine, but this
is a not so natural extension.</p>

<p>When we collapse (something that we only do when really needed), we also
ignore the empty nodes. [This is obsolete!]</p>
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

local listcodes     = mark(getsubtypes("list"))
local rulecodes     = mark(getsubtypes("rule"))
local dircodes      = mark(getsubtypes("dir"))
local glyphcodes    = mark(getsubtypes("glyph"))
local disccodes     = mark(getsubtypes("disc"))
local gluecodes     = mark(getsubtypes("glue"))
local leadercodes   = mark(getsubtypes("leader"))
local fillcodes     = mark(getsubtypes("fill"))
local boundarycodes = mark(getsubtypes("boundary"))
local penaltycodes  = mark(getsubtypes("penalty"))
local kerncodes     = mark(getsubtypes("kern"))
local margincodes   = mark(getsubtypes("marginkern"))
local mathcodes     = mark(getsubtypes("math"))
local noadcodes     = mark(getsubtypes("noad"))
local radicalcodes  = mark(getsubtypes("radical"))
local accentcodes   = mark(getsubtypes("accent"))
local fencecodes    = mark(getsubtypes("fence"))
----- fractioncodes = mark(getsubtypes("fraction"))
local localparcodes = allocate { [0] = "new_graf", "local_box", "hmode_par", "penalty", "math" } -- only in luametatex now

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
localparcodes    = allocate(swapped(localparcodes,localparcodes))
rulecodes        = allocate(swapped(rulecodes,rulecodes))
leadercodes      = allocate(swapped(leadercodes,leadercodes))
usercodes        = allocate(swapped(usercodes,usercodes))
noadoptions      = allocate(swapped(noadoptions,noadoptions))
dirvalues        = allocate(swapped(dirvalues,dirvalues))
gluevalues       = allocate(swapped(gluevalues,gluevalues))
literalvalues    = allocate(swapped(literalvalues,literalvalues))

if not gluecodes.indentskip then
    gluecodes.indentskip     = gluecodes.userskip
    gluecodes.lefthangskip   = gluecodes.userskip
    gluecodes.righthangskip  = gluecodes.userskip
    gluecodes.correctionskip = gluecodes.userskip
    gluecodes.intermathskip  = gluecodes.userskip
end

if CONTEXTLMTXMODE > 0 then
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
nodes.localparcodes        = localparcodes
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
    [nodecodes.localpar]   = localparcodes,
    [nodecodes.marginkern] = margincodes,
    [nodecodes.math]       = mathcodes,
    [nodecodes.noad]       = noadcodes,
    [nodecodes.penalty]    = penaltycodes,
    [nodecodes.radical]    = radicalcodes,
    [nodecodes.rule]       = rulecodes,
 -- [nodecodes.user]       = usercodes,
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

localparcodes.vmode_par    = localparcodes.new_graf

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

-- We don't need this sanitize-after-callback in ConTeXt and by disabling it we
-- also have a way to check if LuaTeX itself does the right thing.

if node.fix_node_lists then
    node.fix_node_lists(false)
end

-- We use the real node code numbers.

if CONTEXTLMTXMODE > 0 then

    local texchardef = tex.chardef

    if texchardef then
        for i=0,nodecodes.glyph do
            texchardef(nodecodes[i] .. "nodecode",i)
        end
        tex.set("internalcodesmode",1)
    end

end
