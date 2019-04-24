if not modules then modules = { } end modules ['pack-rul'] = {
    version   = 1.001,
    comment   = "companion to pack-rul.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>An explanation is given in the history document <t>mk</t>.</p>
--ldx]]--

-- we need to be careful with display math as it uses shifts

-- \framed[align={lohi,middle}]{$x$}
-- \framed[align={lohi,middle}]{$ $}
-- \framed[align={lohi,middle}]{\hbox{ }}
-- \framed[align={lohi,middle}]{\hbox{}}
-- \framed[align={lohi,middle}]{$\hskip2pt$}

local type = type

local context           = context

local nodecodes         = nodes.nodecodes
local listcodes         = nodes.listcodes

local hlist_code        = nodecodes.hlist
local vlist_code        = nodecodes.vlist

local boxlist_code      = listcodes.box
local linelist_code     = listcodes.line
local equationlist_code = listcodes.equation

local texsetdimen       = tex.setdimen
local texsetcount       = tex.setcount

local implement         = interfaces.implement

local nuts              = nodes.nuts

local getnext           = nuts.getnext
local getprev           = nuts.getprev
local getlist           = nuts.getlist
local setlist           = nuts.setlist
local getwhd            = nuts.getwhd
local getid             = nuts.getid
local getsubtype        = nuts.getsubtype
local getbox            = nuts.getbox
local getdirection      = nuts.getdirection
local setshift          = nuts.setshift
local setwidth          = nuts.setwidth
local getwidth          = nuts.getwidth
local setboxglue        = nuts.setboxglue
local getboxglue        = nuts.getboxglue

local hpack             = nuts.hpack
local getdimensions     = nuts.dimensions
local flush_node        = nuts.flush

local traversers        = nuts.traversers
local nexthlist         = traversers.hlist
local nextvlist         = traversers.vlist
local nextlist          = traversers.list

local checkformath      = false

directives.register("framed.checkmath",function(v) checkformath = v end) -- experiment

-- beware: dir nodes and pseudostruts can end up on lines of their own

local function doreshapeframedbox(n)
    local box            = getbox(n)
    local noflines       = 0
    local nofnonzero     = 0
    local firstheight    = nil
    local lastdepth      = nil
    local lastlinelength = 0
    local minwidth       = 0
    local maxwidth       = 0
    local totalwidth     = 0
    local averagewidth   = 0
    local boxwidth       = getwidth(box)
    if boxwidth ~= 0 then -- and h.subtype == vlist_code
        local list = getlist(box)
        if list then
            local hdone = false
            for n, id, subtype, list in nextlist, list do -- no dir etc needed
                local width, height, depth = getwhd(n)
                if not firstheight then
                    firstheight = height
                end
                lastdepth = depth
                noflines  = noflines + 1
                if list then
                    if id == hlist_code then
                        if subtype == boxlist_code or subtype == linelist_code then
                            lastlinelength = getdimensions(list)
                        else
                            lastlinelength = width
                        end
                        hdone = true
                    else
                        lastlinelength = width
                     -- vdone = true
                    end
                    if lastlinelength > maxwidth then
                        maxwidth = lastlinelength
                    end
                    if lastlinelength < minwidth or minwidth == 0 then
                        minwidth = lastlinelength
                    end
                    if lastlinelength > 0 then
                        nofnonzero = nofnonzero + 1
                    end
                    totalwidth = totalwidth + lastlinelength
                end
            end
            if not firstheight then
                -- done)
            elseif maxwidth ~= 0 then
                if hdone then
                    for h, id, subtype, list in nextlist, list do
                        if list and id == hlist_code then
                            if subtype == boxlist_code or subtype == linelist_code then
                                -- getdirection is irrelevant here so it will go
                                -- somehow a parfillskip also can get influenced
                                local p = hpack(list,maxwidth,'exactly',getdirection(h)) -- multiple return value
                                local set, order, sign = getboxglue(p)
                                setboxglue(h,set,order,sign)
                                setlist(p)
                                flush_node(p)
                            elseif checkformath and subtype == equationlist_code then
                             -- display formulas use a shift
                                if nofnonzero == 1 then
                                    setshift(h,0)
                                end
                            end
                            setwidth(h,maxwidth)
                        end
                    end
                end
             -- if vdone then
             --     for v in nextvlist, list do
             --         local width = getwidth(n)
             --         if width > maxwidth then
             --             setwidth(v,maxwidth)
             --         end
             --     end
             -- end
                setwidth(box,maxwidth)
                averagewidth = noflines > 0 and totalwidth/noflines or 0
            else -- e.g. empty math {$ $} or \hbox{} or ...
                setwidth(box,0)
            end
        end
    end
    texsetcount("global","framednoflines",noflines)
    texsetdimen("global","framedfirstheight",firstheight or 0) -- also signal
    texsetdimen("global","framedlastdepth",lastdepth or 0)
    texsetdimen("global","framedminwidth",minwidth)
    texsetdimen("global","framedmaxwidth",maxwidth)
    texsetdimen("global","framedaveragewidth",averagewidth)
end

local function doanalyzeframedbox(n) -- traverse_list
    local box         = getbox(n)
    local noflines    = 0
    local firstheight = nil
    local lastdepth   = nil
    if getwidth(box) ~= 0 then
        local list = getlist(box)
        if list then
            for n in nexthlist, list do
                local width, height, depth = getwhd(n)
                if not firstheight then
                    firstheight = height
                end
                lastdepth = depth
                noflines  = noflines + 1
            end
            for n in nextvlist, list do
                local width, height, depth = getwhd(n)
                if not firstheight then
                    firstheight = height
                end
                lastdepth = depth
                noflines  = noflines + 1
            end
        end
    end
    texsetcount("global","framednoflines",noflines)
    texsetdimen("global","framedfirstheight",firstheight or 0)
    texsetdimen("global","framedlastdepth",lastdepth or 0)
end

implement { name = "doreshapeframedbox", actions = doreshapeframedbox, arguments = "integer" }
implement { name = "doanalyzeframedbox", actions = doanalyzeframedbox, arguments = "integer" }

local function maxboxwidth(box)
    local boxwidth = getwidth(box)
    if boxwidth == 0 then
        return 0
    end
    local list = getlist(box)
    if not list then
        return 0
    end
    if getid(box) == hlist_code then
        return boxwidth
    end
    local lastlinelength = 0
    local maxwidth       = 0
    for n, subtype in nexthlist, list do -- no dir etc needed
        local l = getlist(n)
        if l then
            if subtype == boxlist_code or subtype == linelist_code then
                lastlinelength = getdimensions(l)
            else
                lastlinelength = getwidth(n)
            end
            if lastlinelength > maxwidth then
                maxwidth = lastlinelength
            end
        end
    end
    for n, subtype in nextvlist, list do -- no dir etc needed
        local l = getlist(n)
        if l then
            lastlinelength = getwidth(n)
            if lastlinelength > maxwidth then
                maxwidth = lastlinelength
            end
        end
    end
    return maxwidth
end

nodes.maxboxwidth = maxboxwidth

implement {
    name      = "themaxboxwidth",
    actions   = function(n) context("%rsp",maxboxwidth(getbox(n))) end, -- r = rounded
    arguments = "integer"
}
