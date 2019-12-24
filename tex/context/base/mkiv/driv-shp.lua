if not modules then modules = { } end modules ['driv-shp'] = {
    version   = 1.001,
    comment   = "companion to driv-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next = type, next
local round = math.round

local setmetatableindex = table.setmetatableindex
local formatters        = string.formatters
local concat            = table.concat
local keys              = table.keys
local sortedhash        = table.sortedhash
local splitstring       = string.split
local idiv              = number.idiv
local extract           = bit32.extract
local nuts              = nodes.nuts

local tonut             = nodes.tonut
local tonode            = nodes.tonode

local getdirection      = nuts.getdirection
local getlist           = nuts.getlist
local getoffsets        = nuts.getoffsets
local getorientation    = nuts.getorientation
local getfield          = nuts.getfield
local getwhd            = nuts.getwhd
local getkern           = nuts.getkern
local getheight         = nuts.getheight
local getdepth          = nuts.getdepth
----- getwidth          = nuts.getwidth
local getnext           = nuts.getnext
local getsubtype        = nuts.getsubtype
local getid             = nuts.getid
local getleader         = nuts.getleader
----- getglue           = nuts.getglue
local getshift          = nuts.getshift
local getdata           = nuts.getdata
----- getexpansion      = nuts.getexpansion
local getreplace        = nuts.getreplace
local setreplace        = nuts.setreplace
local getfont           = nuts.getfont

local setdirection      = nuts.setdirection
local setfield          = nuts.setfield
local setlink           = nuts.setlink

local isglyph           = nuts.isglyph
local findtail          = nuts.tail
local nextdir           = nuts.traversers.dir
local nextnode          = nuts.traversers.node

local rangedimensions   = node.direct.rangedimensions -- nuts ?
local effectiveglue     = nuts.effective_glue
local start_of_par      = nuts.start_of_par
local dirdimensions     = nuts.dirdimensions

local texget            = tex.get

local fonthashes        = fonts.hashes
local fontdata          = fonthashes.identifiers
local characters        = fonthashes.characters
local parameters        = fonthashes.parameters

local nodecodes         = nodes.nodecodes
local whatsitcodes      = nodes.whatsitcodes
local leadercodes       = nodes.leadercodes
local gluecodes         = nodes.gluecodes
local dircodes          = nodes.dircodes
local dirvalues         = nodes.dirvalues
local subtypes          = nodes.subtypes

local normaldir_code          <const> = dircodes.normal

local lefttoright_code        <const> = dirvalues.lefttoright
local righttoleft_code        <const> = dirvalues.righttoleft

local glyph_code              <const> = nodecodes.glyph
local kern_code               <const> = nodecodes.kern
local glue_code               <const> = nodecodes.glue
local hlist_code              <const> = nodecodes.hlist
local vlist_code              <const> = nodecodes.vlist
local dir_code                <const> = nodecodes.dir
local disc_code               <const> = nodecodes.disc
local math_code               <const> = nodecodes.math
local rule_code               <const> = nodecodes.rule
local marginkern_code         <const> = nodecodes.marginkern
local whatsit_code            <const> = nodecodes.whatsit
----- penalty_code            <const> = nodecodes.penalty
----- boundary_code           <const> = nodecodes.boundary

local leaders_code            <const> = leadercodes.leaders
local cleaders_code           <const> = leadercodes.cleaders
local xleaders_code           <const> = leadercodes.xleaders
local gleaders_code           <const> = leadercodes.gleaders

local spaceskip_code          <const> = gluecodes.spaceskip

local saveposwhatsit_code     <const> = whatsitcodes.savepos
local userdefinedwhatsit_code <const> = whatsitcodes.userdefined
local openwhatsit_code        <const> = whatsitcodes.open
local writewhatsit_code       <const> = whatsitcodes.write
local closewhatsit_code       <const> = whatsitcodes.close
local lateluawhatsit_code     <const> = whatsitcodes.latelua
local literalwhatsit_code     <const> = whatsitcodes.literal
local setmatrixwhatsit_code   <const> = whatsitcodes.setmatrix
local savewhatsit_code        <const> = whatsitcodes.save
local restorewhatsit_code     <const> = whatsitcodes.restore

local getpagedimensions  getpagedimensions = function()
    getpagedimensions = backends.codeinjections.getpagedimensions
    return getpagedimensions()
end

local drivers   = drivers
local instances = drivers.instances

local report    = logs.reporter("drivers")

---------------------------------------------------------------------------------------

local lastfont         = nil
local fontcharacters   = nil

local magicconstants   = tex.magicconstants
local trueinch         = magicconstants.trueinch
local maxdimen         = magicconstants.maxdimen
local running          = magicconstants.running

local pos_h            = 0
local pos_v            = 0
local pos_r            = lefttoright_code
local shippingmode     = "none"

local abs_max_v        = 0
local abs_max_h        = 0

local shipbox_h        = 0
local shipbox_v        = 0
local page_size_h      = 0
local page_size_v      = 0
----- page_h_origin    = 0 -- trueinch
----- page_v_origin    = 0 -- trueinch

local initialize
local finalize
local updatefontstate
local pushorientation
local poporientation
local flushcharacter
local flushfontchar
local flushrule
local flushliteral
local flushsetmatrix
local flushsave
local flushrestore
local flushspecial
----- flushimage

-- make local

function drivers.getpos () return round(pos_h), round(pos_v) end
function drivers.getrpos() return round(pos_h), round(pos_v), pos_r end
function drivers.gethpos() return round(pos_h) end
function drivers.getvpos() return round(pos_v) end

-- characters

local flush_character

local stack   = setmetatableindex("table")
local level   = 0
local nesting = 0
local main    = 0

-- experiment (smaller page stream but might be fragile)

local tospace = false  directives.register("backends.spaces", function(v) tospace = v end)

-- todo: cache streams

local function flush_vf_packet(pos_h,pos_v,pos_r,font,char,data,factor,vfcommands)

    if nesting > 100 then
        return
    elseif nesting == 0 then
        main = font
    end

    nesting = nesting + 1

    local saved_h = pos_h
    local saved_v = pos_v
    local saved_r = pos_r
            pos_r = lefttoright_code

    local data  = fontdata[font]
    local fnt   = font
    local fonts = data.fonts
    local siz   = (data.parameters.factor or 1)/65536

    local function flushchar(font,char,fnt,chr,f,e)
        if fnt then
            local nest = char ~= chr or font ~= fnt
            if fnt == 0 then
                fnt = main
            end
            return flush_character(false,fnt,chr,factor,nest,pos_h,pos_v,pos_r,f,e)
        else
            return 0
        end
    end

    -- we assume resolved fonts: id mandate but maybe also size

    for i=1,#vfcommands do
        local packet  = vfcommands[i]
        local command = packet[1]
        if command == "char" then
            local chr = packet[2]
            local f   = packet[3]
            local e   = packet[4]
            pos_h = pos_h + flushchar(font,char,fnt,chr,f,e)
        elseif command == "slot" then
            local index = packet[2]
            local chr   = packet[3]
            local f     = packet[4]
            local e     = packet[5]
            if index == 0 then
                pos_h = pos_h + flushchar(font,char,font,chr,f,e)
            else
                local okay = fonts and fonts[index]
                if okay then
                    local fnt = okay.id
                    if fnt then
                        pos_h = pos_h + flushchar(font,char,fnt,chr,f,e)
                    end
                else
                    -- safeguard, we assume the font itself (often index 1)
                    pos_h = pos_h + flushchar(font,char,font,chr,f,e)
                end
            end
        elseif command == "use" then
            local index = packet[2]
            if index then
                local fnt
                if index == 0 then
                    fnt = font
                else
                    local okay = fonts and fonts[index]
                    if okay then
                        fnt = okay.id
                    end
                end
                if fnt then
                    -- not efficient but ok for now as experiment
                    local d = characters[fnt]
                    if d then
                        for i=3,#packet do
                            local chr = packet[i]
                            local dat = d[chr]
                            if dat then
                                flushfontchar(fnt,chr,dat)
                            end
                        end
                    end
                end
            end
        elseif command == "right" then
            local h = packet[2] -- * siz
            if factor ~= 0 and h ~= 0 then
                h = h + h * factor / 1000 -- expansion
            end
            pos_h = pos_h + h
        elseif command == "down" then
            local v = packet[2] -- * siz
            pos_v = pos_v - v
        elseif command == "push" then
            level = level + 1
            local s = stack[level]
            s[1] = pos_h
            s[2] = pos_v
        elseif command == "pop" then
            if level > 0 then
                local s = stack[level]
                pos_h = s[1]
                pos_v = s[2]
                level = level - 1
            end
        elseif command == "pdf" then
            flushliteral(false,pos_h,pos_v,packet[2],packet[3])
        elseif command == "rule" then
            local size_v = packet[2]
            local size_h = packet[3]
            if factor ~= 0 and size_h > 0 then
                size_h = size_h + size_h * factor / 1000
            end
            if size_h > 0 and size_v > 0 then
                flushsimplerule(pos_h,pos_v,pos_r,size_h,size_v)
                pos_h = pos_h + size_h
            end
        elseif command == "font" then
            local index = packet[2]
            local okay  = fonts and fonts[index]
            if okay then
                fnt = okay.id or fnt -- or maybe just return
            end
        elseif command == "lua" then
            local code = packet[2]
            if type(code) ~= "function" then
                code = loadstring(code)
            end
            if type(code) == "function" then
                code(font,char,pos_h,pos_v)
            end
        elseif command == "node" then
            hlist_out(packet[2])
        elseif command == "image" then
            -- doesn't work because intercepted by engine so we use a different
            -- mechanism (for now)
            local image = packet[2]
            -- to do
        elseif command == "pdfmode" then
            -- doesn't happen
     -- elseif command == "special" then
     --     -- not supported
     -- elseif command == "nop" then
     --     -- nothing to do|
     -- elseif command == "scale" then
     --     -- not supported
        end
    end

    pos_h = saved_h
    pos_v = saved_v
    pos_r = saved_r

    nesting = nesting - 1
end

local onetimemessage -- could be defined later (todo: make plug for this)

flush_character = function(current,font,char,factor,vfcommands,pos_h,pos_v,pos_r,f,e)

    if font ~= lastfont then
        lastfont       = font
        fontcharacters = characters[font]
        updatefontstate(font)
    end

    local data = fontcharacters[char]
    if not data then
        if char > 0 then
            if not onetimemessage then
                onetimemessage = fonts.loggers.onetimemessage
            end
            onetimemessage(font,char,"missing")
        end
        return 0, 0, 0
    end

    local width, height, depth, naturalwidth
    if current then
        naturalwidth, height, depth, factor = getwhd(current,true)
        if factor == 0 then
            width = naturalwidth
        else
         -- width = (1.0 + factor/1000000.0) * naturalwidth
            width = naturalwidth + naturalwidth * factor/1000000.0
         -- width = naturalwidth + naturalwidth * 0.000001 * factor
        end
    else
        width  = data.width or 0
        height = data.height or 0
        depth  = data.depth or 0
        naturalwidth = width
        if not factor then
            factor = 0
        end
    end
    if pos_r == righttoleft_code then
        pos_h = pos_h - width
    end
    if vfcommands then
        vfcommands = data.commands
    end
    if vfcommands then
        flush_vf_packet(pos_h,pos_v,pos_r,font,char,data,factor,vfcommands) -- also f ?
    else
        local orientation = data.orientation
        if orientation and (orientation == 1 or orientation == 3) then
            local x = data.xoffset
            local y = data.yoffset
            if x then
                pos_h = pos_h + x
            end
            if y then
                pos_v = pos_v + y
            end
            pushorientation(orientation,pos_h,pos_v)
            flushcharacter(current,pos_h,pos_v,pos_r,font,char,data,naturalwidth,factor,width,f,e)
            poporientation(orientation,pos_h,pos_v)
        else
            flushcharacter(current,pos_h,pos_v,pos_r,font,char,data,naturalwidth,factor,width,f,e)
        end
    end
    return width, height, depth
end

-- end of characters

local function reset_state()
    pos_h         = 0
    pos_v         = 0
    pos_r         = lefttoright_code
    shipbox_h     = 0
    shipbox_v     = 0
    shippingmode  = "none"
    page_size_h   = 0
    page_size_v   = 0
 -- page_h_origin = 0 -- trueinch
 -- page_v_origin = 0 -- trueinch
end

-- local function dirstackentry(t,k)
--     local v = {
--         cur_h = 0,
--         cur_v = 0,
--         ref_h = 0,
--         ref_v = 0,
--     }
--     t[k] = v
--     return v
-- end

----- dirstack = { }
local dirstack = setmetatableindex(dirstackentry)

local function reset_dir_stack()
 -- dirstack = setmetatableindex(dirstackentry)
    dirstack = { }
end

local function flushlatelua(current,h,v)
    return backends.latelua(current,h,v)
end

local function flushwriteout(current)
    if not doing_leaders then
        backends.writeout(current)
    end
end

local function flushopenout(current)
    if not doing_leaders then
        backends.openout(current)
    end
end

local function flushcloseout(current)
    if not doing_leaders then
        backends.closeout(current)
    end
end

local hlist_out, vlist_out  do

    local function applyanchor(orientation,x,y,width,height,depth,woffset,hoffset,doffset,xoffset,yoffset)
        local ot = extract(orientation, 0,4)
        local ay = extract(orientation, 4,4)
        local ax = extract(orientation, 8,4)
        local of = extract(orientation,12,4)
        if ot == 4 then
            ot, ay = 0, 1
        elseif ot == 5 then
            ot, ay = 0, 2
        end
        if ot == 0 or ot == 2 then
            if     ax == 1 then x = x - width
            elseif ax == 2 then x = x + width
            elseif ax == 3 then x = x - width/2
            elseif ax == 4 then x = x + width/2
            end
            if ot == 2 then
                doffset, hoffset = hoffset, doffset
            end
            if     ay == 1 then y = y - doffset
            elseif ay == 2 then y = y + hoffset
            elseif ay == 3 then y = y + (doffset + hoffset)/2 - doffset
            end
        elseif ot == 1 or ot == 3 then
            if     ay == 1 then y = y - height
            elseif ay == 2 then y = y + height
            elseif ay == 3 then y = y - height/2
            end
            if ot == 1 then
                doffset, hoffset = hoffset, doffset
            end
            if     ax == 1 then x = x - width
            elseif ax == 2 then x = x + width
            elseif ax == 3 then x = x - width/2
            elseif ax == 4 then x = x + width/2
            elseif ax == 5 then x = x - hoffset
            elseif ax == 6 then x = x + doffset
            end
        end
        return ot, x + xoffset, y - yoffset
    end

    -- to be checked: begin- or enddir kan nil zijn, weird

 -- local function calculate_width_to_enddir(this_box,begindir) -- can be a helper
 --     local dir_nest = 1
 --     local enddir   = begindir
 --     for current, subtype in nextdir, getnext(begindir) do
 --         if subtype == normaldir_code then -- todo
 --             dir_nest = dir_nest + 1
 --         else
 --             dir_nest = dir_nest - 1
 --         end
 --         if dir_nest == 0 then -- does the type matter
 --             enddir = current
 --             local width = rangedimensions(this_box,begindir,enddir)
 --             return enddir, width
 --         end
 --     end
 --     if enddir == begindir then
 --         local width = rangedimensions(this_box,begindir) -- ,enddir)
 --         return enddir, width
 --     end
 --     return enddir, 0
 -- end

    -- check frequencies of nodes

    hlist_out = function(this_box,current)
        local outer_doing_leaders = false

        local ref_h = pos_h
        local ref_v = pos_v
        local ref_r = pos_r
              pos_r = getdirection(this_box)
        local boxwidth,
              boxheight,
              boxdepth   = getwhd(this_box)

        local cur_h      = 0
        local cur_v      = 0

        if not current then
            current = getlist(this_box)
        end

        -- we can encounter localpar, boundary and penalty nodes but a special
        -- iterator over content nodes won't save much

        for current, id, subtype in nextnode, current do
            if id == glyph_code then
                local char, font = isglyph(current)
                local x_offset, y_offset = getoffsets(current)
                if x_offset ~= 0 or y_offset ~= 0 then
                    if pos_r == righttoleft_code then
                        pos_h = ref_h - (cur_h + x_offset)
                    else
                        pos_h = ref_h + (cur_h + x_offset)
                    end
                    pos_v = ref_v - (cur_v - y_offset)
                    -- synced
                end
             -- local wd, ht, dp = flush_character(current,font,char,false,true,pos_h,pos_v,pos_r)
                local wd = flush_character(current,font,char,false,true,pos_h,pos_v,pos_r)
                cur_h = cur_h + wd
            elseif id == glue_code then
                local gluewidth = effectiveglue(current,this_box)
                if gluewidth ~= 0 then
                    if subtype >= leaders_code then
                        local leader = getleader(current)
                        if leader then
                            local width, height, depth = getwhd(leader)
                            if getid(leader) == rule_code then
                                if gluewidth > 0 then
                                    if height == running then
                                        height = boxheight
                                    end
                                    if depth == running then
                                        depth = boxdepth
                                    end
                                    local total = height + depth
                                    if total > 0 then
                                        if pos_r == righttoleft_code then
                                            pos_h = pos_h - gluewidth
                                        end
                                        pos_v = pos_v - depth
                                        flushrule(leader,pos_h,pos_v,pos_r,gluewidth,total,getsubtype(leader))
                                    end
                                    cur_h = cur_h + gluewidth
                                end
                            elseif width > 0 and gluewidth > 0 then
                                local boxdir = getdirection(leader) or lefttoright_code
                                gluewidth = gluewidth + 10
                                local edge = cur_h + gluewidth
                                local lx = 0
                                if subtype == gleaders_code then
                                    local save_h = cur_h
                                    if pos_r == righttoleft_code then
                                        cur_h = ref_h - shipbox_h - cur_h
                                        cur_h = width * (cur_h / width)
                                        cur_h = ref_h - shipbox_h - cur_h
                                    else
                                        cur_h = cur_h + ref_h - shipbox_h
                                        cur_h = width * (cur_h / width)
                                        cur_h = cur_h - ref_h - shipbox_h
                                    end
                                    if cur_h < save_h then
                                        cur_h = cur_h + width
                                    end
                                elseif subtype == leaders_code then
                                    local save_h = cur_h
                                    cur_h = width * (cur_h / width)
                                    if cur_h < save_h then
                                        cur_h = cur_h + width
                                    end
                                else
                                    lq = gluewidth / width
                                    lr = gluewidth % width
                                    if subtype == cleaders_code then
                                        cur_h = cur_h + lr / 2
                                    else
                                        lx = lr / (lq + 1)
                                        cur_h = cur_h + (lr - (lq - 1) * lx) / 2
                                    end
                                end
                                local shift = getshift(leader)
                                while cur_h + width <= edge do
                                    local basepoint_h = 0
                                 -- local basepoint_v = shift
                                    if boxdir ~= pos_r then
                                        basepoint_h = boxwidth
                                    end
                                    -- synch_pos_with_cur(ref_h,ref_v,cur_h + basepoint_h,shift)
                                    if pos_r == righttoleft_code then
                                        pos_h = ref_h - (cur_h + basepoint_h)
                                    else
                                        pos_h = ref_h + (cur_h + basepoint_h)
                                    end
                                    pos_v = ref_v - shift
                                    -- synced
                                    outer_doing_leaders = doing_leaders
                                    doing_leaders       = true
                                    if getid(leader) == vlist_code then
                                        vlist_out(leader)
                                    else
                                        hlist_out(leader)
                                    end
                                    doing_leaders = outer_doing_leaders
                                    cur_h = cur_h + width + lx
                                end
                                cur_h = edge - 10
                            else
                                cur_h = cur_h + gluewidth
                            end
                        else
                            cur_h = cur_h + gluewidth
                        end
                    else
                        if tospace and subtype == spaceskip_code then
                            -- todo: flush_space
                            flush_character(false,getfont(current),32,false,true,pos_h,pos_v,pos_r)
                        end
                        cur_h = cur_h + gluewidth
                    end
                end
            elseif id == hlist_code or id == vlist_code then
                local boxdir = getdirection(current) or lefttoright_code
                local width, height, depth = getwhd(current)
                local list = getlist(current)
                if list then
                    local shift, orientation = getshift(current)
                    if not orientation then
                        local basepoint_h = boxdir ~= pos_r and width or 0
                     -- local basepoint_v = shift
                        if pos_r == righttoleft_code then
                            pos_h = ref_h - (cur_h + basepoint_h)
                        else
                            pos_h = ref_h + (cur_h + basepoint_h)
                        end
                        pos_v = ref_v - shift
                        -- synced
                        if id == vlist_code then
                            vlist_out(current,list)
                        else
                            hlist_out(current,list)
                        end
                    elseif orientation == 0x1000 then
                        local orientation, xoffset, yoffset = getorientation(current)
                        local basepoint_h = boxdir ~= pos_r and width or 0
                     -- local basepoint_v = shift
                        if pos_r == righttoleft_code then
                            pos_h = ref_h - (cur_h + basepoint_h + xoffset)
                        else
                            pos_h = ref_h + (cur_h + basepoint_h + xoffset)
                        end
                        pos_v = ref_v - (shift - yoffset)
                        -- synced
                        if id == vlist_code then
                            vlist_out(current,list)
                        else
                            hlist_out(current,list)
                        end
                    else
                        local orientation, xoffset, yoffset, woffset, hoffset, doffset = getorientation(current)
                        local orientation, basepoint_h, basepoint_v = applyanchor(orientation,0,shift,width,height,depth,woffset,hoffset,doffset,xoffset,yoffset)
                        if orientation == 1 then
                            basepoint_h = basepoint_h + doffset
                            if boxdir == pos_r then
                                basepoint_v = basepoint_v - height
                            end
                        elseif orientation == 2 then
                            if boxdir == pos_r then
                                basepoint_h = basepoint_h + width
                            end
                        elseif orientation == 3 then
                            basepoint_h = basepoint_h + hoffset
                            if boxdir ~= pos_r then
                                basepoint_v = basepoint_v - height
                            end
                        end
                        if pos_r == righttoleft_code then
                            pos_h = ref_h - (cur_h + basepoint_h)
                        else
                            pos_h = ref_h + (cur_h + basepoint_h)
                        end
                        pos_v = ref_v - (cur_v + basepoint_v)
                        -- synced
                        pushorientation(orientation,pos_h,pos_v,pos_r)
                        if id == vlist_code then
                            vlist_out(current,list)
                        else
                            hlist_out(current,list)
                        end
                        poporientation(orientation,pos_h,pos_v,pos_r)
                    end
                end
                cur_h = cur_h + width
            elseif id == disc_code then
                local replace, tail = getreplace(current)
                if replace and subtype ~= select_disc then
                    -- we could flatten .. no gain
                    setlink(tail,getnext(current))
                    setlink(current,replace)
                    setreplace(current)
                end
            elseif id == kern_code then
                local kern, factor = getkern(current,true)
                if kern ~= 0 then
                    if factor and factor ~= 0 then
                        cur_h = cur_h + (1.0 + factor/1000000.0) * kern
                    else
                        cur_h = cur_h + kern
                    end
                end
            elseif id == rule_code then
                local width, height, depth = getwhd(current)
                if width > 0 then
                    if height == running then
                        height = boxheight
                    end
                    if depth == running then
                        depth = boxdepth
                    end
                    local total = height + depth
                    if total > 0 then
                        local xoffset, yoffset, left, right = getoffsets(current) -- top bottom
                        if left ~= 0 then
                            pos_v  = pos_v + left
                            total  = total - left
                        end
                        if right ~= 0 then
                            depth = depth - right
                            total = total - right
                        end
                        if pos_r == righttoleft_code then
                            pos_h   = pos_h - width
                            xoffset = - xoffset
                        end
                        pos_v = pos_v - depth
                        flushrule(current,pos_h + xoffset,pos_v + yoffset,pos_r,width,total,subtype)
                    end
                    cur_h = cur_h + width
                end
            elseif id == math_code then
             -- local kern = getkern(current)
             -- if kern ~= 0 then
             --     cur_h = cur_h + kern
             -- else
                  cur_h = cur_h + effectiveglue(current,this_box)
             -- end
            elseif id == dir_code then
             -- We normally have proper begin-end pairs. A begin without end is (silently) handled
             -- and an end without a begin will be (silently) skipped we only need to move forward
             -- so we then have a faster calculation.
                local dir, cancel = getdirection(current)
                if cancel then
                    local ds = dirstack[current]
                    if ds then
                        ref_h = ds.ref_h
                        ref_v = ds.ref_v
                        cur_h = ds.cur_h
                        cur_v = ds.cur_v
                    else
                        -- pardir
                    end
                    pos_r = dir
                else
                    local width, enddir = dirdimensions(this_box,current)
                    local new_h = cur_h + width
                    if dir ~= pos_r then
                        cur_h = new_h
                    end
                    if enddir ~= current then
                        dirstack[enddir] = {
                            cur_h = new_h,
                            cur_v = cur_v,
                            ref_h = ref_h,
                            ref_v = ref_v,
                        }
                        setdirection(enddir,pos_r)
                    end
                    if pos_r == righttoleft_code then
                        pos_h = ref_h - cur_h
                    else
                        pos_h = ref_h + cur_h
                    end
                    pos_v = ref_v - cur_v
                    -- synced
                    ref_h = pos_h
                    ref_v = pos_v
                    cur_h = 0
                    cur_v = 0
                    pos_r = dir
                    goto synced
                end
            elseif id == whatsit_code then
                if subtype == literalwhatsit_code then
                    flushliteral(current,pos_h,pos_v)
                elseif subtype == lateluawhatsit_code then
                    flushlatelua(current,pos_h,pos_v)
                elseif subtype == setmatrixwhatsit_code then
                    flushsetmatrix(current,pos_h,pos_v)
                elseif subtype == savewhatsit_code then
                    flushsave(current,pos_h,pos_v)
                elseif subtype == restorewhatsit_code then
                    flushrestore(current,pos_h,pos_v)
                elseif subtype == saveposwhatsit_code then
                    last_position_x = pos_h
                    last_position_y = pos_v
                elseif subtype == writewhatsit_code then
                    flushwriteout(current)
                elseif subtype == closewhatsit_code then
                    flushcloseout(current)
                elseif subtype == openwhatsit_code then
                    flushopenout(current)
                end
            elseif id == marginkern_code then
                cur_h = cur_h + getkern(current)
         -- elseif id == localpar_code and start_of_par(current) then
         --     local pardir = getdirection(current) or lefttoright_code
         --     if pardir == righttoleft_code then
         --     end
         -- end
            end
            -- There is no gain in skipping over this when we have zero progression
            -- and such.
            if pos_r == righttoleft_code then
                pos_h = ref_h - cur_h
            else
                pos_h = ref_h + cur_h
            end
            pos_v = ref_v - cur_v
            ::synced::
        end
        pos_h = ref_h
        pos_v = ref_v
        pos_r = ref_r
    end

    vlist_out = function(this_box,current)
        local outer_doing_leaders = false

        local ref_h = pos_h
        local ref_v = pos_v
        local ref_r = pos_r
              pos_r = getdirection(this_box)

        local boxwidth,
              boxheight,
              boxdepth   = getwhd(this_box)

        local cur_h      = 0
        local cur_v      = - boxheight

        local top_edge   = cur_v

        if pos_r == righttoleft_code then
            pos_h = ref_h - cur_h
        else
            pos_h = ref_h + cur_h
        end
        pos_v = ref_v - cur_v
        -- synced

        if not current then
            current = getlist(this_box)
        end

     -- while current do
     --     local id = getid(current)
        for current, id, subtype in nextnode, current do
            if id == glue_code then
                local glueheight = effectiveglue(current,this_box)
                if glueheight ~= 0 then
                    if subtype >= leaders_code then
                        local leader = getleader(current)
                        if leader then
                            local width, height, depth = getwhd(leader)
                            local total = height + depth
                            if getid(leader) == rule_code then
                                depth = 0 -- hm
                                if total > 0 then
                                    if width == running then
                                        width = boxwidth
                                    end
                                    if width > 0 then
                                        if pos_r == righttoleft_code then
                                            cur_h = cur_h - width
                                        end
                                        flushrule(leader,pos_h,pos_v - total,pos_r,width,total,getsubtype(leader))
                                    end
                                    cur_v = cur_v + total
                                end
                            elseif total > 0 and glueheight > 0 then
                                glueheight = glueheight + 10
                                local edge = cur_v + glueheight
                                local ly   = 0
                                if subtype == gleaders_code then
                                    save_v = cur_v
                                    cur_v  = ref_v - shipbox_v - cur_v
                                    cur_v  = total * (cur_v / total)
                                    cur_v  = ref_v - shipbox_v - cur_v
                                    if cur_v < save_v then
                                        cur_v = cur_v + total
                                    end
                                elseif subtype == leaders_code then -- aleader
                                    save_v = cur_v
                                    cur_v = top_edge + total * ((cur_v - top_edge) / total)
                                    if cur_v < save_v then
                                        cur_v = cur_v + total
                                    end
                                else
                                    lq = glueheight / total
                                    lr = glueheight % total
                                    if subtype == cleaders_code then
                                        cur_v = cur_v + lr / 2
                                    else
                                        ly = lr / (lq + 1)
                                        cur_v = cur_v + (lr - (lq - 1) * ly) / 2
                                    end
                                end
                                local shift = getshift(leader)
                                while cur_v + total <= edge do -- todo: <= edge - total
                                    -- synch_pos_with_cur(ref_h, ref_v, getshift(leader), cur_v + height)
                                    if pos_r == righttoleft_code then
                                        pos_h = ref_h - shift
                                    else
                                        pos_h = ref_h + shift
                                    end
                                    pos_v = ref_v - (cur_v + height)
                                    -- synced
                                    outer_doing_leaders = doing_leaders
                                    doing_leaders = true
                                    if getid(leader) == vlist_code then
                                        vlist_out(leader)
                                    else
                                        hlist_out(leader)
                                    end
                                    doing_leaders = outer_doing_leaders
                                    cur_v = cur_v + total + ly
                                end
                                cur_v = edge - 10
                            else
                                cur_v = cur_v + glueheight
                            end
                        end
                    else
                        cur_v = cur_v + glueheight
                    end
                end
            elseif id == hlist_code or id == vlist_code then
                local boxdir = getdirection(current) or lefttoright_code
                local width, height, depth = getwhd(current)
                local list = getlist(current)
                if list then
                    local shift, orientation = getshift(current)
                    if not orientation then
                     -- local basepoint_h = shift
                     -- local basepoint_v = height
                        if boxdir ~= pos_r then
                            shift = shift + width
                        end
                        if pos_r == righttoleft_code then
                            pos_h = ref_h - shift
                        else
                            pos_h = ref_h + shift
                        end
                        pos_v = ref_v - (cur_v + height)
                        -- synced
                        if id == vlist_code then
                            vlist_out(current,list)
                        else
                            hlist_out(current,list)
                        end
                    elseif orientation == 0x1000 then
                        local orientation, xoffset, yoffset = getorientation(current)
                     -- local basepoint_h = shift
                     -- local basepoint_v = height
                        if boxdir ~= pos_r then
                            shift = shift + width
                        end
                        if pos_r == righttoleft_code then
                            pos_h = ref_h - (shift + xoffset)
                        else
                            pos_h = ref_h + (shift + xoffset)
                        end
                        pos_v = ref_v - (cur_v + height - yoffset)
                        -- synced
                        if id == vlist_code then
                            vlist_out(current,list)
                        else
                            hlist_out(current,list)
                        end
                    else
                        local orientation, xoffset, yoffset, woffset, hoffset, doffset = getorientation(current)
                        local orientation, basepoint_h, basepoint_v = applyanchor(orientation,shift,height,width,height,depth,woffset,hoffset,doffset,xoffset,yoffset)
                        if orientation == 1 then
                            basepoint_h = basepoint_h + width - height
                            basepoint_v = basepoint_v - height
                        elseif orientation == 2 then
                            basepoint_h = basepoint_h + width
                            basepoint_v = basepoint_v + depth - height
                        elseif orientation == 3 then -- weird
                            basepoint_h = basepoint_h + height
                        end
                        if pos_r == righttoleft_code then
                            pos_h = ref_h - basepoint_h
                        else
                            pos_h = ref_h + basepoint_h
                        end
                        pos_v = ref_v - (cur_v + basepoint_v)
                        -- synced
                        pushorientation(orientation,pos_h,pos_v,pos_r)
                        if id == vlist_code then
                            vlist_out(current,list)
                        else
                            hlist_out(current,list)
                        end
                        poporientation(orientation,pos_h,pos_v,pos_r)
                    end
                end
                cur_v = cur_v + height + depth
            elseif id == kern_code then
                cur_v = cur_v + getkern(current)
            elseif id == rule_code then
                local width, height, depth = getwhd(current)
                local total = height + depth
                if total > 0 then
                    if width == running then
                        width = boxwidth
                    end
                    if width > 0 then
                        local xoffset, yoffset, left, right = getoffsets(current)
                        if left ~= 0 then
                            width = width - left
                            xoffset = left
                        end
                        if right ~= 0 then
                            width = width - right
                        end
                        if pos_r == righttoleft_code then
                            xoffset = - xoffset - width
                        end
                        flushrule(current,pos_h + xoffset,pos_v - total - yoffset,pos_r,width,total,subtype)
                    end
                    cur_v = cur_v + total
                end
            elseif id == whatsit_code then
                if subtype == literalwhatsit_code then
                    flushliteral(current,pos_h,pos_v)
                elseif subtype == lateluawhatsit_code then
                    flushlatelua(current,pos_h,pos_v)
                elseif subtype == setmatrixwhatsit_code then
                    flushsetmatrix(current,pos_h,pos_v)
                elseif subtype == savewhatsit_code then
                    flushsave(current,pos_h,pos_v)
                elseif subtype == restorewhatsit_code then
                    flushrestore(current,pos_h,pos_v)
                elseif subtype == saveposwhatsit_code then
                    last_position_x = pos_h
                    last_position_y = pos_v
                elseif subtype == writewhatsit_code then
                    flushwriteout(current)
                elseif subtype == closewhatsit_code then
                    flushcloseout(current)
                elseif subtype == openwhatsit_code then
                    flushopenout(current)
                end
            end
            if pos_r == righttoleft_code then
                pos_h = ref_h - cur_h
            else
                pos_h = ref_h + cur_h
            end
            pos_v = ref_v - cur_v
            ::synced::
        end
        pos_h = ref_h
        pos_v = ref_v
        pos_r = ref_r
    end

end

function drivers.converters.lmtx(driver,box,smode,objnum,specification)

    if not driver then
        report("error in converter, no driver")
        return
    end

    if box then
        box = tonut(box)
    else
        report("error in converter, no box")
        return
    end

    local actions     = driver.actions
    local flushers    = driver.flushers

    initialize        = actions.initialize
    finalize          = actions.finalize

    updatefontstate   = flushers.updatefontstate

    pushorientation   = flushers.pushorientation
    poporientation    = flushers.poporientation

    flushcharacter    = flushers.character
    flushfontchar     = flushers.fontchar
    flushrule         = flushers.rule
    flushsimplerule   = flushers.simplerule
    flushspecial      = flushers.special
    flushliteral      = flushers.literal
    flushsetmatrix    = flushers.setmatrix
    flushsave         = flushers.save
    flushrestore      = flushers.restore
 -- flushimage        = flushers.image

    reset_dir_stack()
    reset_state()

    shippingmode = smode

    local details = nil -- must be outside labels

    local width, height, depth = getwhd(box)

    local total = height + depth

    ----- v_offset_par    = 0
    ----- h_offset_par    = 0

    local max_v = total -- + v_offset_par
    local max_h = width -- + h_offset_par

    if height > maxdimen or depth > maxdimen or width > maxdimen then
        goto DONE
    end

    if max_v > maxdimen then
        goto DONE
    elseif max_v > abs_max_v then
        abs_max_v = max_v
    end

    if max_h > maxdimen then
        goto DONE
    elseif max_h > abs_max_h then
        abs_max_h = max_h
    end

    if shippingmode == "page" then

        -- We have zero offsets in ConTeXt.

        local pagewidth, pageheight = getpagedimensions()

     -- local h_offset_par = texget("hoffset")
     -- local v_offset_par = texget("voffset")

     -- page_h_origin = trueinch
     -- page_v_origin = trueinch

        pos_r = lefttoright_code

        if pagewidth > 0 then
            page_size_h = pagewidth
        else
            page_size_h = width
        end

        if page_size_h == 0 then
            page_size_h = width
        end

        if pageheight > 0 then
            page_size_v = pageheight
        else
            page_size_v = total
        end

        if page_size_v == 0 then
            page_size_v = total
        end

        local refpoint_h = 0           -- + page_h_origin + h_offset_par
        local refpoint_v = page_size_v -- - page_v_origin - v_offset_par

        pos_h = refpoint_h
        pos_v = refpoint_v - height
        -- synced

    else

     -- page_h_origin = 0
     -- page_v_origin = 0
        page_size_h   = width
        page_size_v   = total
        pos_r         = getdirection(box)
        pos_v         = depth
        pos_h         = pos_r == righttoleft_code and width or 0

    end

    shipbox_ref_h = pos_h
    shipbox_ref_v = pos_v

    details = {
        shippingmode  = smode, -- target
        boundingbox   = { 0, 0, page_size_h, page_size_v },
        objectnumber  = smode ~= "page" and objnum or nil,
        pagenumber    = smode == "page" and objnum or nil,
        specification = specification,
    }

    initialize(driver,details)

    lastfont = nil -- this forces a sync each page / object

    if getid(box) == vlist_code then
        vlist_out(box)
    else
        hlist_out(box)
    end

    ::DONE::

    finalize(driver,details)

    shippingmode = "none"
end

-- This will move to back-out.lua eventually.

do

    ----- sortedhash = table.sortedhash

    ----- tonut      = nodes.tonut
    local properties = nodes.properties.data
    local flush      = texio.write_nl

    local periods    = utilities.strings.newrepeater(".")

    local function showdetails(n,l)
        local p = properties[tonut(n)]
        if p then
            local done = false
            for k, v in sortedhash(p) do
                if done then
                    flush("\n")
                else
                    done = true
                end
                flush(periods[l+1] .. " " .. k .. " = " .. tostring(v))
            end
        end
    end

    local whatsittracers = {
        latelua = showdetails,
        literal = showdetails,
    }

    callback.register("show_whatsit",function(n,l)
        local s = nodes.whatsitcodes[n.subtype]
        texio.write(" [" .. s .. "]")
        local w = whatsittracers[s]
        if w then
            w(n,l)
        end
    end)

end
