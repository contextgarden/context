if not modules then modules = { } end modules ['font-mps'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tostring   = tostring
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

local f_moveto      = formatters["(%N,%N)"]
local f_lineto      = formatters["--(%N,%N)"]
local f_curveto     = formatters["..controls(%N,%N)and(%N,%N)..(%N,%N)"]
local s_cycle       = "--cycle"

local f_nofill      = formatters["nofill %s;"]
local f_dofill      = formatters["fill %s;"]

local f_draw_trace  = formatters["drawpathonly %s;"]
local f_draw        = formatters["draw %s;"]

local f_boundingbox = formatters["((%N,%N)--(%N,%N)--(%N,%N)--(%N,%N)--cycle)"]
local f_vertical    = formatters["((%N,%N)--(%N,%N))"]

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

function metapost.paths(d,xfactor,yfactor)
    local sequence = d.sequence
    local segments = d.segments
    local list     = { }
    local path     = { } -- recycled
    local size     = 0
    local xfactor  = xfactor or 1
    local yfactor  = yfactor or xfactor
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
                path[size] = f_moveto(xfactor*sequence[i+1],yfactor*sequence[i+2])
                i = i + 3
            elseif operator == "l" then -- "lineto"
                size = size + 1
                path[size] = f_lineto(xfactor*sequence[i+1],yfactor*sequence[i+2])
                i = i + 3
            elseif operator == "c" then -- "curveto"
                size = size + 1
                path[size] = f_curveto(xfactor*sequence[i+1],yfactor*sequence[i+2],xfactor*sequence[i+3],yfactor*sequence[i+4],xfactor*sequence[i+5],yfactor*sequence[i+6])
                i = i + 7
            elseif operator =="q" then -- "quadraticto"
                size = size + 1
                -- first is always a moveto
                local l_x = xfactor*sequence[i-2]
                local l_y = yfactor*sequence[i-1]
                local m_x = xfactor*sequence[i+1]
                local m_y = yfactor*sequence[i+2]
                local r_x = xfactor*sequence[i+3]
                local r_y = yfactor*sequence[i+4]
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
                path[size] = f_moveto(xfactor*segment[1],yfactor*segment[2])
            elseif operator == "l" then -- "lineto"
                size = size + 1
                path[size] = f_lineto(xfactor*segment[1],yfactor*segment[2])
            elseif operator == "c" then -- "curveto"
                size = size + 1
                path[size] = f_curveto(xfactor*segment[1],yfactor*segment[2],xfactor*segment[3],yfactor*segment[4],xfactor*segment[5],yfactor*segment[6])
            elseif operator =="q" then -- "quadraticto"
                size = size + 1
                -- first is always a moveto
                local prev = segments[i-1]
                local l_x = xfactor*prev[#prev-2]
                local l_y = yfactor*prev[#prev-1]
                local m_x = xfactor*segment[1]
                local m_y = yfactor*segment[2]
                local r_x = xfactor*segment[3]
                local r_y = yfactor*segment[4]
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
        xmin = 0
        ymin = 0
        xmax = 0
        ymax = 0
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

-- This is a nice example of tex, metapost and lua working in tandem. Each kicks in at the
-- right time. It's probably why I like watching https://www.youtube.com/watch?v=c5FqpddnJmc
-- so much: precisely (and perfectly) timed too.

local nodecodes       = nodes.nodecodes -- no nuts yet
local rulecodes       = nodes.rulecodes

local glyph_code      = nodecodes.glyph
local disc_code       = nodecodes.disc
local kern_code       = nodecodes.kern
local glue_code       = nodecodes.glue
local hlist_code      = nodecodes.hlist
local vlist_code      = nodecodes.vlist
local rule_code       = nodecodes.rule

local normalrule_code = rulecodes.normal

local nuts            = nodes.nuts
local getnext         = nuts.getnext
local getid           = nuts.getid
local getlist         = nuts.getlist
local getsubtype      = nuts.getsubtype
local getreplace      = nuts.getreplace
local getbox          = nuts.getbox
local getwhd          = nuts.getwhd
local getkern         = nuts.getkern
local getshift        = nuts.getshift
local getwidth        = nuts.getwidth
local getheight       = nuts.getheight
local getdepth        = nuts.getdepth
local getexpansion    = nuts.getexpansion
local isglyph         = nuts.isglyph

local effective_glue  = nuts.effective_glue

local characters      = fonts.hashes.characters
local parameters      = fonts.hashes.parameters
local shapes          = fonts.hashes.shapes
local topaths         = metapost.paths

local f_code          = formatters["mfun_do_outline_text_flush(%q,%i,%N,%N,%q)(%,t);"]
local f_rule          = formatters["mfun_do_outline_rule_flush(%q,%N,%N,%N,%N);"]
local f_bounds        = formatters["checkbounds(%N,%N,%N,%N);"]
local s_nothing       = "(origin scaled 10)"

local sc              = 10
local fc              = number.dimenfactors.bp * sc / sc

-- todo: make the next more efficient:

function metapost.output(kind,font,char,advance,shift,ex)
    local character = characters[font][char]
    if character then
        local index = character.index
        if index then
            local shapedata = shapes[font]
            local glyphs    = shapedata.glyphs -- todo: subfonts fonts.shapes.indexed(font,sub)
            if glyphs then
                local glyf = glyphs[index]
                if glyf then
                    local units     = 1000 -- factor already takes shapedata.units into account
                    local yfactor   = (sc/units) * parameters[font].factor / 655.36
                    local xfactor   = yfactor
                    local shift     = shift or 0
                    local advance   = advance or 0
                    local exfactor  = ex or 0
                    local wfactor   = 1
                    local detail    = kind == "p" and tostring(char) or ""
                    if exfactor ~= 0 then
                        wfactor = (1+(ex/units)/1000)
                        xfactor = xfactor * wfactor
                    end
                    local paths = topaths(glyf,xfactor,yfactor)
                    if paths then
                        local code = f_code(kind,#paths,advance,shift,detail,paths)
                        return code, character.width * fc * wfactor
                    else
                        return "", 0
                    end
                end
            end
        end
    end
    return s_nothing, 10 * sc/1000
end

-- not ok yet: leftoffset in framed not handled well

local signal = -0x3FFFFFFF - 1

function fonts.metapost.boxtomp(n,kind)

    local result   = { }
    local advance  = 0   -- in bp
    local distance = 0

    local llx, lly, urx, ury = 0, 0, 0, 0

    local horizontal, vertical

    horizontal = function(parent,current,xoffset,yoffset)
        local dx = 0
        while current do
            local char, id = isglyph(current)
            if char then
                local code, width = metapost.output(kind,id,char,xoffset+dx,yoffset,getexpansion(current))
                result[#result+1] = code
                dx = dx + width
            elseif id == disc_code then
                local replace = getreplace(current)
                if replace then
                    dx = dx + horizontal(parent,replace,xoffset+dx,yoffset)
                end
            elseif id == kern_code then
                dx = dx + getkern(current) * fc
            elseif id == glue_code then
                dx = dx + effective_glue(current,parent) * fc
            elseif id == hlist_code then
                local list = getlist(current)
                if list then
                    horizontal(current,list,xoffset+dx,yoffset-getshift(current)*fc)
                end
                dx = dx + getwidth(current) * fc
            elseif id == vlist_code then
                local list = getlist(current)
                if list then
                    vertical(current,list,xoffset+dx,yoffset-getshift(current)*fc)
                end
                dx = dx + getwidth(current) * fc
            elseif id == rule_code then
                local wd, ht, dp = getwhd(current)
                if wd ~= 0 then
                    wd = wd * fc
                    if ht == signal then
                        ht = getheight(parent)
                    end
                    if dp == signal then
                        dp = getdepth(parent)
                    end
                    local hd = (ht + dp) * fc
                    if hd ~= 0 and getsubtype(current) == normalrule_code then
                        result[#result+1] = f_rule(kind,xoffset+dx+wd/2,yoffset+hd/2,wd,hd)
                    end
                    dx = dx + wd
                end
            end
            current = getnext(current)
        end
        return dx
    end

    vertical = function(parent,current,xoffset,yoffset)
        local dy = getheight(parent) * fc
        while current do
            local id = getid(current)
            if id == hlist_code then
                local _, ht, dp = getwhd(current)
                dy = dy - ht * fc
                local list = getlist(current)
                if list then
                    horizontal(current,list,xoffset+getshift(current)*fc,yoffset+dy)
                end
                dy = dy - dp * fc
            elseif id == vlist_code then
                local wd, ht, dp = getwhd(current)
                dy = dy - ht * fc
                local list = getlist(current)
                if list then
                    vertical(current,list,xoffset+getshift(current)*fc,yoffset+dy)
                end
                dy = dy - dp * fc
            elseif id == kern_code then
                dy = dy - getkern(current) * fc
            elseif id == glue_code then
                dy = dy - effective_glue(current,parent) * fc
            elseif id == rule_code then
                local wd, ht, dp = getwhd(current)
                local hd = (ht + dp) * fc
                if hd ~= 0  then
                    if wd == signal then
                        wd = getwidth(parent) * fc
                    else
                        wd = wd * fc
                    end
                    dy = dy - ht * fc
                    if wd ~= 0 and getsubtype(current) == 0 then
                        result[#result+1] = f_rule(kind,xoffset+wd/2,yoffset+dy+hd/2,wd,hd)
                    end
                    dy = dy - dp * fc
                end
            end
            current = getnext(current)
        end
        return dy
    end

    local box  = getbox(n)
    local list = box and getlist(box)
    if list then
        (getid(box) == hlist_code and horizontal or vertical)(box,list,0,0)
    end

    local wd, ht, dp = getwhd(box)

    result[#result+1] = f_bounds(0,-dp*fc,wd*fc,ht*fc)

    return concat(result)

end
