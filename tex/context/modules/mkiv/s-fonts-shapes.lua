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
    --
    local specification = interfaces.checkedspecification(specification)
    local id, cs        = fonts.definers.internal(specification,"<module:fonts:shapes:font>")
    local tfmdata       = fontdata[id]
    local characters    = tfmdata.characters
    local descriptions  = tfmdata.descriptions
    local parameters    = tfmdata.parameters
    local tfmfactor     = parameters.scaledpoints/10
-- inspect(tfmdata.parameters)
-- inspect(tfmdata.properties)
    local anchors       = fonts.helpers.collectanchors(tfmdata)

    local function showonecharacter(unicode,krn,tight)
        local c = characters  [unicode]
        local d = descriptions[unicode]
        if c and d then
            local factor = (parameters.size/parameters.units)*((7200/7227)/65536)
            local llx, lly, urx, ury = unpack(d.boundingbox)
            local height = ury
            local depth  = lly
            llx, lly, urx, ury = llx*factor, lly*factor, urx*factor, ury*factor
            local width  = (d.width or 0)*factor
            context.start()
            context.dontleavehmode()
            context.obeyMPboxdepth()
            context.startMPcode()
            context("numeric lw ; lw := .125bp ;")
            context("pickup pencircle scaled lw ;")
            if width < 0.01 then
                -- catches zero width marks
                context('picture p ; p := textext.drt("\\hskip5sp\\getuvalue{%s}\\gray\\char%s"); draw p ;',cs,unicode)
            else
                context('picture p ; p := textext.drt("\\getuvalue{%s}\\gray\\char%s"); draw p ;',cs,unicode)
            end
            context('draw (%s,%s)--(%s,%s)--(%s,%s)--(%s,%s)--cycle withcolor green ;',llx,lly,urx,lly,urx,ury,llx,ury)
            context('draw (%s,%s)--(%s,%s) withcolor green ;',llx,0,urx,0)
            context('draw boundingbox p withcolor .2white withpen pencircle scaled .065bp ;')
            context("defaultscale := 0.05 ; ")
            -- inefficient but non critical
            function slant(v,dx,dy,txt,xsign,ysign,loc,labloc,shift)
                local n = #v
                if n > 0 then
                    local l = { }
                    local t = { }
                    for i=1,n do
                        local c = v[i]
                        local h = c.height or height or 0
                        local d = depth or 0
                        local k = c.kern or 0
                        if i == 1 then
                            l[1] = formatters["((%s,%s) shifted (%s,%s))"](xsign*k*factor,d*factor,dx,dy)
                            t[1] = formatters['draw textext.%s("\\tttf(%s,%s)") scaled .025 shifted %s shifted (%i/4,%i/3);'](labloc,k,d,l[1],shift,shift);
                        end
                        l[i+1] = formatters["((%s,%s) shifted (%s,%s))"](xsign*k*factor,ysign*h*factor,dx,dy)
                        t[i+1] = formatters['draw textext.%s("\\tttf(%s,%s)") scaled .025 shifted %s shifted (%i/4,%i/3);'](labloc,k,h,l[i+1],shift,shift);
                    end
                    context("draw laddered (%--t) withcolor .5white ;",l)
                    for i=1,#l do
                        context("draw %s withcolor blue withpen pencircle scaled 2lw ;",l[i])
                        context(t[i])
                    end
                end
            end
            --
            local math = d.math
            if math then
                local kerns = math.kerns
                if kerns then
                    for k, v in next, kerns do
                        if k == "topright" and (krn == "all" or krn == k) then
                            slant(v,width,0,k,1,1,"top","lrt",1)
                        elseif k == "bottomright" and (krn == "all" or krn == k) then
                            slant(v,width,0,k,1,1,"bot","ulft",-1)
                        elseif k == "topleft" and (krn == "all" or krn == k) then
                            slant(v,0,0,k,-1,1,"top","lrt",1)
                        elseif k == "bottomleft" and (krn == "all" or krn == k) then
                            slant(v,0,0,k,-1,1,"bot","ulft",-1)
                        end
                    end
                end
                local accent = math.topanchor or math.accent
                if accent and accent ~= 0 then
                    local a = accent * factor
                    context('draw (%s,%s+1/4)--(%s,%s-1/4) withcolor blue;',a,ury,a,ury)
                    context('draw textext.top("\\tttf%s") scaled .025 shifted (%s,%s+2/4);',accent,a,ury)
                end
            end
            --
            local anchordata = anchors[unicode]
            if anchordata then
                local function show(txt,list)
                    if list then
                        for i=1,#list do
                            local li = list[i]
                            local x, y = li[1], li[2]
                            local xx, yy = x*factor, y*factor
                            context("draw (%s,%s) withcolor blue withpen pencircle scaled 2lw ;",xx,yy)
                            context('label.top("\\infofont %s",(%s,%s-2.75bp)) ;',txt .. i,xx,yy)
                            context('label.bot("\\infofont (%s,%s)",(%s,%s+2.75bp)) ;',x,y,xx,yy)
                        end
                    end
                end
                --
                show("b",anchordata.base)
                show("m",anchordata.mark)
                show("l",anchordata.ligature)
                show("e",anchordata.entry)
                show("x",anchordata.exit)
            end
            --
            local italic = d.italic
            if italic and italic ~= 0 then
                local i = italic * factor
                context('draw (%s,%s-1bp)--(%s,%s-0.5bp) withcolor blue ;',width,ury,width,ury)
                context('draw (%s,%s-1bp)--(%s,%s-0.5bp) withcolor blue ;',width+i,ury,width+i,ury)
                context('draw (%s,%s-1bp)--(%s,%s-1bp) withcolor blue ;',width,ury,width+i,ury)
                context('label.lft("\\type{%s}",(%s+2bp,%s-1bp));',"italic",width,ury)
                context('label.rt("%s",(%s-2bp,%s-1bp));',italic,width+i,ury)
            end
            context('draw origin withcolor red withpen pencircle scaled 2lw;')
            local kern  = c.topright
            if kern and kern ~= 0 then
                local k = kern * factor / tfmfactor
                context('draw (%s,%s) withcolor "orange" withpen pencircle scaled .2 ;',width+k,ury)
            end
            local kern  = c.bottomright
            if kern and kern ~= 0 then
                local k = kern * factor / tfmfactor
                context('draw (%s,%s) withcolor "orange" withpen pencircle scaled .2 ;',width+k,lly)
            end
            local kern  = c.topleft
            if kern and kern ~= 0 then
                local k = kern * factor / tfmfactor
                context('draw (%s,%s) withcolor "orange" withpen pencircle scaled .2 ;',-k,ury)
            end
            local kern  = c.bottomleft
            if kern and kern ~= 0 then
                local k = kern * factor / tfmfactor
                context('draw (%s,%s) withcolor "orange" withpen pencircle scaled .2 ;',-k,lly)
            end
            if not tight then
                context("setbounds currentpicture to boundingbox currentpicture enlarged 1bp ;")
            end
            context("currentpicture := currentpicture scaled 8 ;")
            context.stopMPcode()
            context.stop()
        end
    end

    local unicode = tonumber(specification.character) or
                    fonts.helpers.nametoslot(specification.character)

    if unicode then
        showonecharacter(unicode,"all",true)
    else
        context.modulefontsstartshowglyphshapes()
        for unicode, description in fonts.iterators.descriptions(tfmdata) do
            if unicode >= 0x110000 then
                break
            end
            local kerns = specification.kerns
            if kerns then
                local k = description and description.math and description.math.kerns
                if k then
                    if not (kerns == "all" or k[kerns]) then
                        goto DONE
                    end
                else
                    goto DONE
                end
            end
            context.modulefontsstartshowglyphshape(unicode,description.name or "",description.index or 0)
                showonecharacter(unicode,kerns,false)
            context.modulefontsstopshowglyphshape()
          ::DONE::
        end
        context.modulefontsstopshowglyphshapes()
    end

end

moduledata.fonts.shapes.showglyphshape    = showglyphshape
moduledata.fonts.shapes.showallglypshapes = showglyphshape

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
