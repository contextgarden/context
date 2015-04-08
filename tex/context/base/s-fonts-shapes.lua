if not modules then modules = { } end modules['s-fonts-shapes'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-shapes.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.fonts        = moduledata.fonts        or { }
moduledata.fonts.shapes = moduledata.fonts.shapes or { }

local fontdata = fonts.hashes.identifiers

local context = context
local NC, NR = context.NC, context.NR
local space, dontleavehmode, glyph, getvalue = context.space, context.dontleavehmode, context.glyph, context.getvalue
local formatters = string.formatters

function char(id,k)
    dontleavehmode()
    glyph(id,k)
end

local function special(id,specials)
    if specials and #specials > 1 then
        context("%s:",specials[1])
        if #specials > 5 then
            space() char(id,specials[2])
            space() char(id,specials[3])
            space() context("...")
            space() char(id,specials[#specials-1])
            space() char(id,specials[#specials])
        else
            for i=2,#specials do
                space() char(id,specials[i])
            end
        end
    end
end

function moduledata.fonts.shapes.showlist(specification) -- todo: ranges
    specification = interfaces.checkedspecification(specification)
    local id, cs = fonts.definers.internal(specification,"<module:fonts:shapes:font>")
    local chrs = fontdata[id].characters
    context.begingroup()
    context.tt()
    context.starttabulate { "|l|c|c|c|c|l|l|" }
        context.FL()
            NC() context.bold("unicode")
            NC() context.bold("glyph")
            NC() context.bold("shape")
            NC() context.bold("lower")
            NC() context.bold("upper")
            NC() context.bold("specials")
            NC() context.bold("description")
            NC() NR()
        context.TL()
        for k, v in next, characters.data do
            if chrs[k] then
                NC() context("0x%05X",k)
                NC() char(id,k) -- getvalue(cs) context.char(k)
                NC() char(id,v.shcode)
                NC() char(id,v.lccode or k)
                NC() char(id,v.uccode or k)
                NC() special(id,v.specials)
                NC() context.tx(v.description)
                NC() NR()
            end
        end
    context.stoptabulate()
    context.endgroup()
end

function moduledata.fonts.shapes.showlist(specification) -- todo: ranges
    specification = interfaces.checkedspecification(specification)
    local id, cs = fonts.definers.internal(specification,"<module:fonts:shapes:font>")
    local chrs = fontdata[id].characters
    context.begingroup()
    context.tt()
    context.starttabulate { "|l|c|c|c|c|l|l|" }
        context.FL()
            NC() context.bold("unicode")
            NC() context.bold("glyph")
            NC() context.bold("shape")
            NC() context.bold("lower")
            NC() context.bold("upper")
            NC() context.bold("specials")
            NC() context.bold("description")
            NC() NR()
        context.TL()
        for k, v in next, characters.data do
            if chrs[k] then
                NC() context("0x%05X",k)
                NC() char(id,k)
                NC() char(id,v.shcode)
                NC() char(id,v.lccode or k)
                NC() char(id,v.uccode or k)
                NC() special(id,v.specials)
                NC() context.tx(v.description)
                NC() NR()
            end
        end
    context.stoptabulate()
    context.endgroup()
end

local descriptions = nil
local characters   = nil

local function showglyphshape(specification)
    specification = interfaces.checkedspecification(specification)
    local id, cs = fonts.definers.internal(specification,"<module:fonts:shapes:font>")
    local tfmdata = fontdata[id]
    local charnum = tonumber(specification.character)
    if not charnum then
        charnum = fonts.helpers.nametoslot(n)
    end
    context.start()
    context.dontleavehmode()
    context.obeyMPboxdepth()
    local characters   = tfmdata.characters
    local descriptions = tfmdata.descriptions
    local parameters   = tfmdata.parameters
    local c = characters[charnum]
    local d = descriptions[charnum]
    if d then
        local factor = (parameters.size/parameters.units)*((7200/7227)/65536)
        local llx, lly, urx, ury = unpack(d.boundingbox)
        llx, lly, urx, ury = llx*factor, lly*factor, urx*factor, ury*factor
        local width, italic = (d.width or 0)*factor, (d.italic or 0)*factor
        local top_accent, bot_accent = (d.top_accent or 0)*factor, (d.bot_accent or 0)*factor
        local anchors, math = d.anchors, d.math
        context.startMPcode()
        context("numeric lw ; lw := .125bp ;")
        context("pickup pencircle scaled lw ;")
        context('picture p ; p := image(draw textext.drt("\\getuvalue{%s}\\gray\\char%s");); draw p ;',cs,charnum)
        context('draw (%s,%s)--(%s,%s)--(%s,%s)--(%s,%s)--cycle withcolor green ;',llx,lly,urx,lly,urx,ury,llx,ury)
        context('draw (%s,%s)--(%s,%s) withcolor green ;',llx,0,urx,0)
        context('draw boundingbox p withcolor .2white withpen pencircle scaled .065bp ;')
        context("defaultscale := 0.05 ; ")
        -- inefficient but non critical
        local function slant_1(v,dx,dy,txt,xsign,ysign,loc,labloc)
            if #v > 0 then
                local l = { }
                for kk, vv in ipairs(v) do
                    local h, k = vv.height, vv.kern
                    if h and k then
                        l[#l+1] = formatters["((%s,%s) shifted (%s,%s))"](xsign*k*factor,ysign*h*factor,dx,dy)
                    end
                end
                context("draw ((%s,%s) shifted (%s,%s))--%s dashed (evenly scaled 1/16) withcolor .5white;", xsign*v[1].kern*factor,lly,dx,dy,l[1])
                context("draw laddered (%s) withcolor .5white ;",table.concat(l,".."))
                context("draw ((%s,%s) shifted (%s,%s))--%s dashed (evenly scaled 1/16) withcolor .5white;", xsign*v[#v].kern*factor,ury,dx,dy,l[#l])
                for k, v in ipairs(l) do
                    context("draw %s withcolor blue withpen pencircle scaled 2lw ;",v)
                end
            end
        end
        local function slant_2(v,dx,dy,txt,xsign,ysign,loc,labloc)
            if #v > 0 then
                local l = { }
                for kk, vv in ipairs(v) do
                    local h, k = vv.height, vv.kern
                    if h and k then
                        l[#l+1] = formatters["((%s,%s) shifted (%s,%s))"](xsign*k*factor,ysign*h*factor,dx,dy)
                    end
                end
                if loc == "top" then
                    context('label.%s("\\type{%s}",%s shifted (0,-1bp)) ;',loc,txt,l[#l])
                else
                    context('label.%s("\\type{%s}",%s shifted (0,2bp)) ;',loc,txt,l[1])
                end
                for kk, vv in ipairs(v) do
                    local h, k = vv.height, vv.kern
                    if h and k then
                        context('label.top("(%s,%s)",%s shifted (0,-2bp));',k,h,l[kk])
                    end
                end
            end
        end
        if math then
            local kerns = math.kerns
            if kerns then
                for _, slant in ipairs { slant_1, slant_2 } do
                    for k,v in pairs(kerns) do
                        if k == "top_right" then
                            slant(v,width+italic,0,k,1,1,"top","ulft")
                        elseif k == "bottom_right" then
                            slant(v,width,0,k,1,1,"bot","lrt")
                        elseif k == "top_left" then
                            slant(v,0,0,k,-1,1,"top","ulft")
                        elseif k == "bottom_left" then
                            slant(v,0,0,k,-1,1,"bot","lrt")
                        end
                    end
                end
            end
        end
        local function show(x,y,txt)
            local xx, yy = x*factor, y*factor
            context("draw (%s,%s) withcolor blue withpen pencircle scaled 2lw ;",xx,yy)
            context('label.top("\\type{%s}",(%s,%s-2bp)) ;',txt,xx,yy)
            context('label.bot("(%s,%s)",(%s,%s+2bp)) ;',x,y,xx,yy)
        end
        if anchors then
            local a = anchors.baselig
            if a then
                for k, v in pairs(a) do
                    for kk, vv in ipairs(v) do
                        show(vv[1],vv[2],k .. ":" .. kk)
                    end
                end
            end
            local a = anchors.mark
            if a then
                for k, v in pairs(a) do
                    show(v[1],v[2],k)
                end
            end
            local a = anchors.basechar
            if a then
                for k, v in pairs(a) do
                    show(v[1],v[2],k)
                end
            end
            local ba = anchors.centry
            if a then
                for k, v in pairs(a) do
                    show(v[1],v[2],k)
                end
            end
            local a = anchors.cexit
            if a then
                for k, v in pairs(a) do
                    show(v[1],v[2],k)
                end
            end
        end
        if italic ~= 0 then
            context('draw (%s,%s-1bp)--(%s,%s-0.5bp) withcolor blue ;',width,ury,width,ury)
            context('draw (%s,%s-1bp)--(%s,%s-0.5bp) withcolor blue ;',width+italic,ury,width+italic,ury)
            context('draw (%s,%s-1bp)--(%s,%s-1bp) withcolor blue ;',width,ury,width+italic,ury)
            context('label.lft("\\type{%s}",(%s+2bp,%s-1bp));',"italic",width,ury)
            context('label.rt("%s",(%s-2bp,%s-1bp));',d.italic,width+italic,ury)
        end
        if top_accent ~= 0 then
            context('draw (%s,%s+1bp)--(%s,%s-1bp) withcolor blue;',top_accent,ury,top_accent,ury)
            context('label.bot("\\type{%s}",(%s,%s+1bp));',"top_accent",top_accent,ury)
            context('label.top("%s",(%s,%s-1bp));',d.top_accent,top_accent,ury)
        end
        if bot_accent ~= 0 then
            context('draw (%s,%s+1bp)--(%s,%s-1bp) withcolor blue;',bot_accent,lly,bot_accent,lly)
            context('label.top("\\type{%s}",(%s,%s-1bp));',"bot_accent",top_accent,ury)
            context('label.bot("%s",(%s,%s+1bp));',d.bot_accent,bot_accent,lly)
        end
        context('draw origin withcolor red withpen pencircle scaled 2lw;')
        context("setbounds currentpicture to boundingbox currentpicture enlarged 1bp ;")
        context("currentpicture := currentpicture scaled 8 ;")
        context.stopMPcode()
 -- elseif c then
 --     lastdata, lastunicode = nil, nil
 --     local factor = (7200/7227)/65536
 --     context.startMPcode()
 --     context("pickup pencircle scaled .25bp ; ")
 --     context('picture p ; p := image(draw textext.drt("\\gray\\char%s");); draw p ;',charnum)
 --     context('draw boundingbox p withcolor .2white withpen pencircle scaled .065bp ;')
 --     context("defaultscale := 0.05 ; ")
 --     local italic, top_accent, bot_accent = (c.italic or 0)*factor, (c.top_accent or 0)*factor, (c.bot_accent or 0)*factor
 --     local width, height, depth = (c.width or 0)*factor, (c.height or 0)*factor, (c.depth or 0)*factor
 --     local ury = height
 --     if italic ~= 0 then
 --         context('draw (%s,%s-1bp)--(%s,%s-0.5bp) withcolor blue;',width,ury,width,ury)
 --         context('draw (%s,%s-1bp)--(%s,%s-0.5bp) withcolor blue;',width+italic,ury,width+italic,ury)
 --         context('draw (%s,%s-1bp)--(%s,%s-1bp) withcolor blue;',width,ury,width+italic,height)
 --         context('label.lft("\\type{%s}",(%s+2bp,%s-1bp));',"italic",width,height)
 --         context('label.rt("%6.3f bp",(%s-2bp,%s-1bp));',italic,width+italic,height)
 --     end
 --     if top_accent ~= 0 then
 --         context('draw (%s,%s+1bp)--(%s,%s-1bp) withcolor blue;',top_accent,ury,top_accent,height)
 --         context('label.bot("\\type{%s}",(%s,%s+1bp));',"top_accent",top_accent,height)
 --         context('label.top("%6.3f bp",(%s,%s-1bp));',top_accent,top_accent,height)
 --     end
 --     if bot_accent ~= 0 then
 --         context('draw (%s,%s+1bp)--(%s,%s-1bp) withcolor blue;',bot_accent,lly,bot_accent,height)
 --         context('label.top("\\type{%s}",(%s,%s-1bp));',"bot_accent",top_accent,height)
 --         context('label.bot("%6.3f bp",(%s,%s+1bp));',bot_accent,bot_accent,height)
 --     end
 --     context('draw origin withcolor red withpen pencircle scaled 1bp;')
 --     context("setbounds currentpicture to boundingbox currentpicture enlarged 1bp ;")
 --     context("currentpicture := currentpicture scaled 8 ;")
 --     context.stopMPcode()
    else
        lastdata, lastunicode = nil, nil
        context("no such shape: 0x%05X",charnum)
    end
    context.stop()
end

moduledata.fonts.shapes.showglyphshape = showglyphshape

function moduledata.fonts.shapes.showallglypshapes(specification)
    specification = interfaces.checkedspecification(specification)
    local id, cs = fonts.definers.internal(specification,"<module:fonts:shapes:font>")
    local descriptions = fontdata[id].descriptions
    for unicode, description in fonts.iterators.descriptions(tfmdata) do
        context.modulefontsstartshowglyphshape(unicode,description.name)
        showglyphshape { number = id, character = unicode }
        context.modulefontsstopshowglyphshape()
    end
end

function moduledata.fonts.shapes.showlastglyphshapefield(unicode,name)
    if not descriptions then
        -- bad news
    elseif name == "unicode" then
        context("U+%05X",descriptions.unicode)
    else
        local d = descriptions[name]
        if d then
            context(d)
        end
    end
end
