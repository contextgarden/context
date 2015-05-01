if not modules then modules = { } end modules ['x-math-svg'] = {
    version   = 1.001,
    comment   = "companion to x-math-svg.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tostring, type, next = tostring, type, next
local lpegmatch, P, Cs = lpeg.match, lpeg.P, lpeg.Cs

local xmlfirst      = xml.first
local xmlconvert    = xml.convert
local xmlload       = xml.load
local xmlsave       = xml.save
local xmlcollected  = xml.collected
local xmldelete     = xml.delete

local loadtable     = table.load
local savetable     = table.save

local replacesuffix = file.replacesuffix
local addsuffix     = file.addsuffix
local removefile    = os.remove
local isfile        = lfs.isfile

local formatters    = string.formatters

moduledata          = moduledata or table.setmetatableindex("table")
local svgmath       = moduledata.svgmath -- autodefined

local namedata      = { }
local pagedata      = { }

local statusname    = "x-math-svg-status.lua"
local pdfname       = "x-math-svg.pdf"

local pdftosvg      = os.which("mudraw")

local f_make_tex    = formatters[ [[context --global kpse:x-math-svg.mkvi --inputfile="%s" --svgstyle="%s" --batch --noconsole --once --purgeall]] ]
local f_make_svg    = formatters[ [[mudraw -o "math-%%d.svg" "%s" 1-9999]] ]

----- f_inline      = formatters[ [[<div class='math-inline' style='vertical-align:%p'></div>]] ]
local f_inline      = formatters[ [[<div class='math-inline'></div>]] ]
local f_display     = formatters[ [[<div class='math-display'></div>]] ]
local f_style       = formatters[ [[vertical-align:%p]] ]

local f_math_tmp    = formatters[ [[math-%i]] ]

function svgmath.process(filename)
    if not filename then
        -- no filename given
        return
    elseif not isfile(filename) then
        -- invalid filename
        return
    end
    local index = 0
    local page  = 0
    local blobs = { }
    local root  = xmlload(filename)
    for mth in xmlcollected(root,"math") do
        index = index + 1
        local blob = tostring(mth)
        if blobs[blob] then
            context.ReuseSVGMath(index,blobs[blob])
        else
            page = page + 1
            buffers.assign(f_math_tmp(page),blob)
            context.MakeSVGMath(index,page,mth.at.display)
            blobs[blob] = page
        end
    end
    context(function()
        -- for tracing purposes:
        for mathdata, pagenumber in next, blobs do
            local p  = pagedata[pagenumber]
            p.mathml = mathdata
            p.number = pagenumber
        end
        --
        savetable(statusname, {
            pagedata = pagedata,
            namedata = namedata,
        })
    end)
end

function svgmath.register(index,page,specification)
    if specification then
        pagedata[page] = specification
    end
    namedata[index] = page
end

function svgmath.convert(filename,svgstyle)
    if not filename then
        -- no filename given
        return false, "no filename"
    elseif not isfile(filename) then
        -- invalid filename
        return false, "invalid filename"
    elseif not pdftosvg then
        return false, "mudraw is not installed"
    end

    os.execute(f_make_tex(filename,svgstyle))

    local data = loadtable(statusname)
    if not data then
        -- invalid tex run
        return false, "invalid tex run"
    elseif not next(data) then
        return false, "no converson needed"
    end

    local pagedata = data.pagedata
    local namedata = data.namedata

    os.execute(f_make_svg(pdfname))

    local root   = xmlload(filename)
    local index  = 0
    local done   = { }
    local unique = 0

    local between = (1-P("<"))^1/""
    local strip = Cs((
        (P("<text") * ((1-P("</text>"))^1) * P("</text>")) * between^0 / "" +
        P(">") * between +
        P(1)
    )^1)

    for mth in xmlcollected(root,"m:math") do
        index = index + 1
        local page = namedata[index]
        if done[page] then
            mth.__p__.dt[mth.ni] = done[page]
        else
            local info    = pagedata[page]
            local depth   = info.depth
            local mode    = info.mode
            local svgname = addsuffix(f_math_tmp(page),"svg")
            local action  = mode == "inline" and f_inline or f_display
         -- local x_div   = xmlfirst(xmlconvert(action(-depth)),"/div")
            local x_div   = xmlfirst(xmlconvert(action()),"/div")
            local svgdata = io.loaddata(svgname)
            if not svgdata or svgdata == "" then
                print("error in:",svgname,tostring(mth))
            else
             -- svgdata = string.gsub(svgdata,">%s<","")
                svgdata = lpegmatch(strip,svgdata)
                local x_svg = xmlfirst(xmlconvert(svgdata),"/svg")
             -- xmldelete(x_svg,"text")
if mode == "inline" then
    x_svg.at.style = f_style(-depth)
end

                x_div.dt = { x_svg }
                mth.__p__.dt[mth.ni] = x_div -- use helper
            end
            done[page] = x_div
            unique = unique + 1
        end
    end

--     for k, v in next, data do
--         removefile(addsuffix(k,"svg"))
--     end
--     removefile(statusname)
--     removefile(pdfname)

    xmlsave(root,filename)

    return true, index, unique
end
