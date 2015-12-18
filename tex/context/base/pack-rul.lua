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
-- challenge: adapt glue_set
-- setfield(h,"glue_set", getfield(h,"glue_set") * getfield(h,"width")/maxwidth -- interesting ... doesn't matter much

-- \framed[align={lohi,middle}]{$x$}
-- \framed[align={lohi,middle}]{$ $}
-- \framed[align={lohi,middle}]{\hbox{ }}
-- \framed[align={lohi,middle}]{\hbox{}}
-- \framed[align={lohi,middle}]{$\hskip2pt$}

local type = type

local hlist_code      = nodes.nodecodes.hlist
local vlist_code      = nodes.nodecodes.vlist
local box_code        = nodes.listcodes.box
local line_code       = nodes.listcodes.line

local texsetdimen     = tex.setdimen
local texsetcount     = tex.setcount

local implement       = interfaces.implement

local nuts            = nodes.nuts

local getfield        = nuts.getfield
local setfield        = nuts.setfield
local getnext         = nuts.getnext
local getprev         = nuts.getprev
local getlist         = nuts.getlist
local setlist         = nuts.setlist
local getid           = nuts.getid
local getsubtype      = nuts.getsubtype
local getbox          = nuts.getbox

local hpack           = nuts.hpack
local traverse_id     = nuts.traverse_id
local node_dimensions = nuts.dimensions
local free_node       = nuts.free

local function doreshapeframedbox(n)
    local box            = getbox(n)
    local noflines       = 0
    local firstheight    = nil
    local lastdepth      = nil
    local lastlinelength = 0
    local minwidth       = 0
    local maxwidth       = 0
    local totalwidth     = 0
    local averagewidth   = 0
    local boxwidth       = getfield(box,"width")
    if boxwidth ~= 0 then -- and h.subtype == vlist_code
        local list = getlist(box)
        if list then
            local function check(n,repack)
                if not firstheight then
                    firstheight = getfield(n,"height")
                end
                lastdepth = getfield(n,"depth")
                noflines = noflines + 1
                local l = getlist(n)
                if l then
                    if repack then
                        local subtype = getsubtype(n)
                        if subtype == box_code or subtype == line_code then
                         -- used to be: hpack(copy(l)).width
                            lastlinelength = node_dimensions(l,getfield(n,"dir"))
                        else
                            lastlinelength = getfield(n,"width")
                        end
                    else
                        lastlinelength = getfield(n,"width")
                    end
                    if lastlinelength > maxwidth then
                        maxwidth = lastlinelength
                    end
                    if lastlinelength < minwidth or minwidth == 0 then
                        minwidth = lastlinelength
                    end
                    totalwidth = totalwidth + lastlinelength
                end
            end
            local hdone = false
            for h in traverse_id(hlist_code,list) do -- no dir etc needed
                check(h,true)
                hdone = true
            end
         -- local vdone = false
            for v in traverse_id(vlist_code,list) do -- no dir etc needed
                check(v,false)
             -- vdone = true
            end
            if not firstheight then
                -- done)
            elseif maxwidth ~= 0 then
                if hdone then
                    for h in traverse_id(hlist_code,list) do
                        local l = getlist(h)
                        if l then
                            local subtype = getsubtype(h)
                            if subtype == box_code or subtype == line_code then
                                local p = hpack(l,maxwidth,'exactly',getfield(h,"dir")) -- multiple return value
                                if false then
                                    setlist(h,p)
                                    setfield(h,"shift",0) -- needed for display math, so no width check possible
                                 -- setfield(p,"attr",getfield(h,"attr"))
                                else
                                    setfield(h,"glue_set",getfield(p,"glue_set"))
                                    setfield(h,"glue_order",getfield(p,"glue_order"))
                                    setfield(h,"glue_sign",getfield(p,"glue_sign"))
                                    setlist(p)
                                    free_node(p)
                                end
                            end
                            setfield(h,"width",maxwidth)
                        end
                    end
                end
             -- if vdone then
             --     for v in traverse_id(vlist_code,list) do
             --         local width = getfield(n,"width")
             --         if width > maxwidth then
             --             setfield(v,"width",maxwidth)
             --         end
             --     end
             -- end
                setfield(box,"width",maxwidth)
                averagewidth = noflines > 0 and totalwidth/noflines or 0
            else -- e.g. empty math {$ $} or \hbox{} or ...
setfield(box,"width",0)
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

local function doanalyzeframedbox(n)
    local box         = getbox(n)
    local noflines    = 0
    local firstheight = nil
    local lastdepth   = nil
    if getfield(box,"width") ~= 0 then
        local list = getlist(box)
        if list then
            local function check(n)
                if not firstheight then
                    firstheight = getfield(n,"height")
                end
                lastdepth = getfield(n,"depth")
                noflines = noflines + 1
            end
            for h in traverse_id(hlist_code,list) do
                check(h)
            end
            for v in traverse_id(vlist_code,list) do
                check(v)
            end
        end
    end
    texsetcount("global","framednoflines",noflines)
    texsetdimen("global","framedfirstheight",firstheight or 0)
    texsetdimen("global","framedlastdepth",lastdepth or 0)
end

implement { name = "doreshapeframedbox", actions = doreshapeframedbox, arguments = "integer" }
implement { name = "doanalyzeframedbox", actions = doanalyzeframedbox, arguments = "integer" }

function nodes.maxboxwidth(box)
    local boxwidth = getfield(box,"width")
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
    local function check(n,repack)
        local l = getlist(n)
        if l then
            if repack then
                local subtype = getsubtype(n)
                if subtype == box_code or subtype == line_code then
                    lastlinelength = node_dimensions(l,getfield(n,"dir"))
                else
                    lastlinelength = getfield(n,"width")
                end
            else
                lastlinelength = getfield(n,"width")
            end
            if lastlinelength > maxwidth then
                maxwidth = lastlinelength
            end
        end
    end
    for h in traverse_id(hlist_code,list) do -- no dir etc needed
        check(h,true)
    end
    for v in traverse_id(vlist_code,list) do -- no dir etc needed
        check(v,false)
    end
end
