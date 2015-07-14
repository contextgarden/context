if not modules then modules = { } end modules ['font-mps'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat     = table.concat
local formatters = string.formatters

-- QP0 [QP1] QP2 => CP0 [CP1 CP2] CP3

-- CP0 = QP0
-- CP3 = QP2
--
-- CP1 = QP0 + 2/3 *(QP1-QP0)
-- CP2 = QP2 + 2/3 *(QP1-QP2)

fonts               = fonts or { }
local metapost      = fonts.metapost or { }
fonts.metapost      = metapost

local trace_skips   = false  trackers.register("metapost.outlines.skips",function(v) trace_skips = v end)

local f_moveto      = formatters["(%.4F,%.4F)"]
local f_lineto      = formatters["--(%.4F,%.4F)"]
local f_curveto     = formatters["..controls(%.4F,%.4F)and(%.4F,%.4F)..(%.4F,%.4F)"]
local s_cycle       = "--cycle"

local f_nofill      = formatters["nofill %s;"]
local f_dofill      = formatters["fill %s;"]

local f_draw_trace  = formatters["drawpathonly %s;"]
local f_draw        = formatters["draw %s;"]

local f_boundingbox = formatters["((%.4F,%.4F)--(%.4F,%.4F)--(%.4F,%.4F)--(%.4F,%.4F)--cycle)"]
local f_vertical    = formatters["((%.4F,%.4F)--(%.4F,%.4F))"]

function metapost.boundingbox(d,factor)
    local bounds = d.boundingbox
    local factor = factor or 1
    local llx    = factor*bounds[1]
    local lly    = factor*bounds[2]
    local urx    = factor*bounds[3]
    local ury    = factor*bounds[4]
    return f_boundingbox(llx,lly,urx,lly,urx,ury,llx,ury)
end

function metapost.widthline(d,factor)
    local bounds = d.boundingbox
    local factor = factor or 1
    local lly    = factor*bounds[2]
    local ury    = factor*bounds[4]
    local width  = factor*d.width
    return f_vertical(width,lly,width,ury)
end

function metapost.zeroline(d,factor)
    local bounds = d.boundingbox
    local factor = factor or 1
    local lly    = factor*bounds[2]
    local ury    = factor*bounds[4]
    return f_vertical(0,lly,0,ury)
end

function metapost.paths(d,factor)
    local sequence = d.sequence
    local segments = d.segments
    local list     = { }
    local path     = { } -- recycled
    local size     = 0
    local factor   = factor or 1
    if sequence then
        local i = 1
        local n = #sequence
        while i < n do
            local operator = sequence[i]
            if operator == "m" then -- "moveto"
                if size > 0 then
                    size = size + 1
                    path[size] = s_cycle
                    list[#list+1] = concat(path,"",1,size)
                    size = 1
                else
                    size = size + 1
                end
                path[size] = f_moveto(factor*sequence[i+1],factor*sequence[i+2])
                i = i + 3
            elseif operator == "l" then -- "lineto"
                size = size + 1
                path[size] = f_lineto(factor*sequence[i+1],factor*sequence[i+2])
                i = i + 3
            elseif operator == "c" then -- "curveto"
                size = size + 1
                path[size] = f_curveto(factor*sequence[i+1],factor*sequence[i+2],factor*sequence[i+3],factor*sequence[i+4],factor*sequence[i+5],factor*sequence[i+6])
                i = i + 7
            elseif operator =="q" then -- "quadraticto"
                size = size + 1
                -- first is always a moveto
                local l_x, l_y = factor*sequence[i-2], factor*sequence[i-1]
                local m_x, m_y = factor*sequence[i+1], factor*sequence[i+2]
                local r_x, r_y = factor*sequence[i+3], factor*sequence[i+4]
                path[size] = f_curveto (
                    l_x + 2/3 * (m_x-l_x),
                    l_y + 2/3 * (m_y-l_y),
                    r_x + 2/3 * (m_x-r_x),
                    r_y + 2/3 * (m_y-r_y),
                    r_x, r_y
                )
                i = i + 5
            else
                -- weird
                i = i + 1
            end
        end
    elseif segments then
        for i=1,#segments do
            local segment  = segments[i]
            local operator = segment[#segment]
            if operator == "m" then -- "moveto"
                if size > 0 then
                    size = size + 1
                    path[size] = s_cycle
                    list[#list+1] = concat(path,"",1,size)
                    size = 1
                else
                    size = size + 1
                end
                path[size] = f_moveto(factor*segment[1],factor*segment[2])
            elseif operator == "l" then -- "lineto"
                size = size + 1
                path[size] = f_lineto(factor*segment[1],factor*segment[2])
            elseif operator == "c" then -- "curveto"
                size = size + 1
                path[size] = f_curveto(factor*segment[1],factor*segment[2],factor*segment[3],factor*segment[4],factor*segment[5],factor*segment[6])
            elseif operator =="q" then -- "quadraticto"
                size = size + 1
                -- first is always a moveto
                local prev = segments[i-1]
                local l_x, l_y = factor*prev[#prev-2], factor*prev[#prev-1]
                local m_x, m_y = factor*segment[1], factor*segment[2]
                local r_x, r_y = factor*segment[3], factor*segment[4]
                path[size] = f_curveto (
                    l_x + 2/3 * (m_x-l_x),
                    l_y + 2/3 * (m_y-l_y),
                    r_x + 2/3 * (m_x-r_x),
                    r_y + 2/3 * (m_y-r_y),
                    r_x, r_y
                )
            else
                -- weird
            end
        end
    else
        return
    end
    if size > 0 then
        size = size + 1
        path[size] = s_cycle
        list[#list+1] = concat(path,"",1,size)
    end
    return list
end

function metapost.fill(paths)
    local r = { }
    local n = #paths
    for i=1,n do
        if i < n then
            r[i] = f_nofill(paths[i])
        else
            r[i] = f_dofill(paths[i])
        end
    end
    return concat(r)
end

function metapost.draw(paths,trace)
    local r = { }
    local n = #paths
    for i=1,n do
        if trace then
            r[i] = f_draw_trace(paths[i])
        else
            r[i] = f_draw(paths[i])
        end
    end
    return concat(r)
end

function metapost.maxbounds(data,index,factor)
    local maxbounds   = data.maxbounds
    local factor      = factor or 1
    local glyphs      = data.glyphs
    local glyph       = glyphs[index]
    local boundingbox = glyph.boundingbox
    local xmin, ymin, xmax, ymax
    if not maxbounds then
        xmin, ymin, xmax, ymax = 0, 0, 0, 0
        for i=1,#glyphs do
            local d = glyphs[i]
            if d then
                local b = d.boundingbox
                if b then
                    if b[1] < xmin then xmin = b[1] end
                    if b[2] < ymin then ymin = b[2] end
                    if b[3] > xmax then xmax = b[3] end
                    if b[4] > ymax then ymax = b[4] end
                end
            end
        end
        maxbounds = { xmin, ymin, xmax, ymax }
        data.maxbounds = maxbounds
    else
        xmin = maxbounds[1]
        ymin = maxbounds[2]
        xmax = maxbounds[3]
        ymax = maxbounds[4]
    end
    local llx   = boundingbox[1]
    local lly   = boundingbox[2]
    local urx   = boundingbox[3]
    local ury   = boundingbox[4]
    local width = glyph.width
    if llx > 0 then
        llx = 0
    end
    if width > urx then
        urx = width
    end
    return f_boundingbox(
        factor*llx,factor*ymin,
        factor*urx,factor*ymin,
        factor*urx,factor*ymax,
        factor*llx,factor*ymax
    )
end

----- formatters   = string.formatters
----- concat       = table.concat

local nodecodes    = nodes.nodecodes -- no nuts yet

local glyph_code   = nodecodes.glyph
local disc_code    = nodecodes.disc
local kern_code    = nodecodes.kern
local glue_code    = nodecodes.glue
local hlist_code   = nodecodes.hlist
local vlist_code   = nodecodes.vlist
local rule_code    = nodecodes.rule
local penalty_code = nodecodes.penalty

local find_tail    = nodes.tail

----- metapost     = fonts.glyphs.metapost

local characters   = fonts.hashes.characters
local shapes       = fonts.hashes.shapes
local topaths      = fonts.metapost.paths

local f_code       = formatters["mfun_do_outline_text_flush(%q,%i,%.4F,%.4F)(%,t);"]
local s_nothing    = "(origin scaled 10)"

local sc = 10
local fc = number.dimenfactors.bp * sc / 10

-- todo: make the next more efficient:

function metapost.output(kind,font,char,advance,shift)
    local character = characters[font][char]
    if char then
        local index = character.index
        if index then
            local shapedata = shapes[font]
            local glyphs    = shapedata.glyphs -- todo: subfonts fonts.shapes.indexed(font,sub)
            if glyphs then
                local glyf = data.glyphs[index]
                if glyf then
                    local units   = data.fontheader and data.fontheader.units or data.units or 1000
                    local factor  = sc/units
                    local shift   = shift or 0
                    local advance = advance or 0
                    local paths   = topaths(glyf,factor)
                    local code    = f_code(kind,#paths,advance,shift,paths)
                 -- return code, glyf.width * factor
                    return code, character.width * fc
                end
            end
        end
    end
    return s_nothing, 10 * sc/1000
end

-- shifted hboxes

local signal = -0x3FFFFFFF - 1

function fonts.metapost.boxtomp(n,kind)

    local result   = { }
    local advance  = 0   -- in bp
    local distance = 0

    local llx, lly, urx, ury = 0, 0, 0, 0

    local boxtomp

    local function horizontal(current,shift,glue_sign,glue_set,glue_order,ht,dp)
        shift = shift or 0
        while current do
            local id = current.id
            if id == glyph_code then
                local code, width = metapost.output(kind,current.font,current.char,advance,-shift*fc)
                result[#result+1] = code
                advance = advance + width
            elseif id == disc_code then
                local replace = current.replace
                if replace then
                    horizontal(replace,shift,glue_sign,glue_set,glue_order,ht,dp)
                end
            elseif id == kern_code then
                local kern = current.kern * fc
                if trace_skips then -- todo: shift
                    result[#result+1] = formatters["draw rule(%3F,%3F,%3F) shifted (%3F,%3F) withcolor .5white;"](kern,0.8*ht*fc,0.8*dp*fc,advance,-shift*fc)
                end
                advance = advance + kern
            elseif id == glue_code then
                local spec  = current.spec
                local width = spec.width
                if glue_sign == 1 then
                    if spec.stretch_order == glue_order then
                        width = (width + spec.stretch * glue_set) * fc
                    else
                        width = width * fc
                    end
                elseif glue_sign == 2 then
                    if spec.shrink_order == glue_order then
                        width = (width - spec.shrink * glue_set) * fc
                    else
                        width = width * fc
                    end
                else
                    width = width * fc
                end
                if trace_skips then -- todo: shift
                    result[#result+1] = formatters["draw rule(%3F,%3F,%3F) shifted (%3F,%3F) withcolor .5white;"](width,0.1*ht*fc,0.1*dp*fc,advance,-shift*fc)
                end
                advance = advance + width
            elseif id == hlist_code then
                local a = advance
                boxtomp(current,shift+current.shift,current.glue_sign,current.glue_set,current.glue_order)
                advance = a + current.width * fc
            elseif id == vlist_code then
                boxtomp(current) -- ,distance + shift,current.glue_set*current.glue_sign)
            elseif id == rule_code then
                local wd = current.width
                local ht = current.height
                local dp = current.depth
                if not (ht == signal or dp == signal or wd == signal) then
                    ht = ht - shift
                    dp = dp - shift
                    if wd == 0 then
                        result[#result+1] = formatters["strut(%3F,%3F);"](ht*fc,-dp*fc)
                    else
                        result[#result+1] = formatters["draw rule(%3F,%3F,%3F);"](wd*fc,ht*fc,-dp*fc)
                    end
                end
            else
             -- print("horizontal >>>",nodecodes[id])
            end
            current = current.next
        end
    end

    local function vertical(current,shift)
        shift = shift or 0
        current = find_tail(current) -- otherwise bad bbox
        while current do
            local id = current.id
            if id == hlist_code then
                distance = distance - current.depth
                boxtomp(current,distance + shift,current.glue_set*current.glue_sign)
                distance = distance - current.height
            elseif id == vlist_code then
                print("vertical >>>",nodecodes[id])
            elseif id == kern_code then
                distance = distance - current.kern
                advance  = 0
            elseif id == glue_code then
                distance = distance - current.spec.width
                advance  = 0
            end
            current = current.prev
        end
    end

    boxtomp = function(list,shift)
        local current = list.list
        if current then
            if list.id == hlist_code then
                horizontal(current,shift,list.glue_sign,list.glue_set,list.glue_order,list.height,list.depth)
            else
                vertical(current,shift)
            end
        end
    end

    local box = tex.box[n]

    boxtomp(box,box.shift,box.glue_sign,box.glue_set,box.glue_order)

    local wd = box.width
    local ht = box.height
    local dp = box.depth
    local sh = box.shift

    result[#result+1] = formatters["checkbounds(%3F,%3F,%3F,%3F);"](0,-dp*fc,wd*fc,ht*fc)

    return concat(result)

end
