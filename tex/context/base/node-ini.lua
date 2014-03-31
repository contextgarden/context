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

nodes               = nodes or { }
local nodes         = nodes
nodes.handlers      = nodes.handlers or { }

local allocate      = utilities.storage.allocate
local formatcolumns = utilities.formatters.formatcolumns

-- there will be more of this:

local skipcodes = allocate {
    [  0] = "userskip",
    [  1] = "lineskip",
    [  2] = "baselineskip",
    [  3] = "parskip",
    [  4] = "abovedisplayskip",
    [  5] = "belowdisplayskip",
    [  6] = "abovedisplayshortskip",
    [  7] = "belowdisplayshortskip",
    [  8] = "leftskip",
    [  9] = "rightskip",
    [ 10] = "topskip",
    [ 11] = "splittopskip",
    [ 12] = "tabskip",
    [ 13] = "spaceskip",
    [ 14] = "xspaceskip",
    [ 15] = "parfillskip",
    [ 16] = "thinmuskip",
    [ 17] = "medmuskip",
    [ 18] = "thickmuskip",
    [100] = "leaders",
    [101] = "cleaders",
    [102] = "xleaders",
    [103] = "gleaders",
}

local penaltycodes = allocate { -- unfortunately not used
    [ 0] = "userpenalty",
}

table.setmetatableindex(penaltycodes,function(t,k) return "userpenalty" end) -- not used anyway

local noadcodes = allocate { -- simple nodes
    [ 0] = "ord",
    [ 1] = "opdisplaylimits",
    [ 2] = "oplimits",
    [ 3] = "opnolimits",
    [ 4] = "bin",
    [ 5] = "rel",
    [ 6] = "open",
    [ 7] = "close",
    [ 8] = "punct",
    [ 9] = "inner",
    [10] = "under",
    [11] = "over",
    [12] = "vcenter",
}

local listcodes = allocate {
    [ 0] = "unknown",
    [ 1] = "line",
    [ 2] = "box",
    [ 3] = "indent",
    [ 4] = "alignment", -- row or column
    [ 5] = "cell",
}

local glyphcodes = allocate {
    [0] = "character",
    [1] = "glyph",
    [2] = "ligature",
    [3] = "ghost",
    [4] = "left",
    [5] = "right",
}

local kerncodes = allocate {
    [0] = "fontkern",
    [1] = "userkern",
    [2] = "accentkern",
}

local mathcodes = allocate {
    [0] = "beginmath",
    [1] = "endmath",
}

local fillcodes = allocate {
    [0] = "stretch",
    [1] = "fi",
    [2] = "fil",
    [3] = "fill",
    [4] = "filll",
}

local margincodes = allocate {
    [0] = "left",
    [1] = "right",
}

local disccodes = allocate {
    [0] = "discretionary", -- \discretionary
    [1] = "explicit",      -- \-
    [2] = "automatic",     -- following a -
    [3] = "regular",       -- simple
    [4] = "first",         -- hard first item
    [5] = "second",        -- hard second item
}

local accentcodes = allocate {
    [0] = "bothflexible",
    [1] = "fixedtop",
    [2] = "fixedbottom",
    [3] = "fixedboth",
}

local fencecodes = allocate {
    [0] = "unset",
    [1] = "left",
    [2] = "middle",
    [3] = "right",
}

local function simplified(t)
    local r = { }
    for k, v in next, t do
        r[k] = gsub(v,"_","")
    end
    return r
end

local nodecodes = simplified(node.types())
local whatcodes = simplified(node.whatsits())

skipcodes    = allocate(swapped(skipcodes,skipcodes))
noadcodes    = allocate(swapped(noadcodes,noadcodes))
nodecodes    = allocate(swapped(nodecodes,nodecodes))
whatcodes    = allocate(swapped(whatcodes,whatcodes))
listcodes    = allocate(swapped(listcodes,listcodes))
glyphcodes   = allocate(swapped(glyphcodes,glyphcodes))
kerncodes    = allocate(swapped(kerncodes,kerncodes))
penaltycodes = allocate(swapped(penaltycodes,penaltycodes))
mathcodes    = allocate(swapped(mathcodes,mathcodes))
fillcodes    = allocate(swapped(fillcodes,fillcodes))
margincodes  = allocate(swapped(margincodes,margincodes))
disccodes    = allocate(swapped(disccodes,disccodes))
accentcodes  = allocate(swapped(accentcodes,accentcodes))
fencecodes   = allocate(swapped(fencecodes,fencecodes))

nodes.skipcodes    = skipcodes     nodes.gluecodes    = skipcodes -- more official
nodes.noadcodes    = noadcodes
nodes.nodecodes    = nodecodes
nodes.whatcodes    = whatcodes     nodes.whatsitcodes = whatcodes -- more official
nodes.listcodes    = listcodes
nodes.glyphcodes   = glyphcodes
nodes.kerncodes    = kerncodes
nodes.penaltycodes = kerncodes
nodes.mathcodes    = mathcodes
nodes.fillcodes    = fillcodes
nodes.margincodes  = margincodes
nodes.disccodes    = disccodes     nodes.discretionarycodes = disccodes
nodes.accentcodes  = accentcodes
nodes.fencecodes   = fencecodes

listcodes.row              = listcodes.alignment
listcodes.column           = listcodes.alignment

kerncodes.italiccorrection = kerncodes.userkern
kerncodes.kerning          = kerncodes.fontkern

whatcodes.textdir          = whatcodes.dir

nodes.codes = allocate { -- mostly for listing
    glue    = skipcodes,
    noad    = noadcodes,
    node    = nodecodes,
    hlist   = listcodes,
    vlist   = listcodes,
    glyph   = glyphcodes,
    kern    = kerncodes,
    penalty = penaltycodes,
    math    = mathnodes,
    fill    = fillcodes,
    margin  = margincodes,
    disc    = disccodes,
    whatsit = whatcodes,
    accent  = accentcodes,
    fence   = fencecodes,
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
