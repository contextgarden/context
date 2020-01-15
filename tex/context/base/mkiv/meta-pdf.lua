if not modules then modules = { } end modules ['meta-pdf'] = {
    version   = 1.001,
    comment   = "companion to meta-pdf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module is not used in practice but we keep it around for historic
-- reasons.

-- Finally we used an optimized version. The test code can be found in
-- meta-pdh.lua but since we no longer want to overload functione we use
-- more locals now. This module keeps changing as it is also a testbed.
--
-- We can make it even more efficient if needed, but as we don't use this
-- code often in \MKIV\ it makes no sense.

local tonumber = tonumber
local concat, unpack = table.concat, table.unpack
local gsub, find, byte, gmatch, match = string.gsub, string.find, string.byte, string.gmatch, string.match
local lpegmatch = lpeg.match
local round = math.round
local formatters, format = string.formatters, string.format

local mplib                     = mplib
local metapost                  = metapost
local lpdf                      = lpdf
local context                   = context

local report_mptopdf            = logs.reporter("graphics","mptopdf")

local texgetattribute           = tex.getattribute

local pdfrgbcode                = lpdf.rgbcode
local pdfcmykcode               = lpdf.cmykcode
local pdfgraycode               = lpdf.graycode
local pdfspotcode               = lpdf.spotcode
local pdftransparencycode       = lpdf.transparencycode
local pdffinishtransparencycode = lpdf.finishtransparencycode

metapost.mptopdf = metapost.mptopdf or { }
local mptopdf    = metapost.mptopdf

mptopdf.nofconverted = 0

local f_translate = formatters["1 0 0 0 1 %.6N %.6N cm"]
local f_concat    = formatters["%.6N %.6N %.6N %.6N %.6N %.6N cm"]

local m_path, m_stack, m_texts, m_version, m_date, m_shortcuts = { }, { }, { }, 0, 0, false

local m_stack_close, m_stack_path, m_stack_concat = false, { }, nil
local extra_path_data, ignore_path = nil, false
local specials = { }

local function resetpath()
    m_stack_close, m_stack_path, m_stack_concat = false, { }, nil
end

local function resetall()
    m_path, m_stack, m_texts, m_version, m_shortcuts = { }, { }, { }, 0, false
    extra_path_data, ignore_path = nil, false
    specials = { }
    resetpath()
end

resetall()

local pdfcode = context.pdfliteral

local function mpscode(str)
    if ignore_path then
        pdfcode("h W n")
        if extra_path_data then
            pdfcode(extra_path_data)
            extra_path_data = nil
        end
        ignore_path = false
    else
        pdfcode(str)
    end
end

-- auxiliary functions

local function flushconcat()
    if m_stack_concat then
        mpscode(f_concat(unpack(m_stack_concat)))
        m_stack_concat = nil
    end
end

local function flushpath(cmd)
    if #m_stack_path > 0 then
        local path = { }
        if m_stack_concat then
            local sx = m_stack_concat[1]
            local sy = m_stack_concat[4]
            local rx = m_stack_concat[2]
            local ry = m_stack_concat[3]
            local tx = m_stack_concat[5]
            local ty = m_stack_concat[6]
            local d = (sx*sy) - (rx*ry)
            for k=1,#m_stack_path do
                local v  = m_stack_path[k]
                local px = v[1]
                local py = v[2]
                v[1] = (sy*(px-tx)-ry*(py-ty))/d
                v[2] = (sx*(py-ty)-rx*(px-tx))/d
                if #v == 7 then
                    px = v[3]
                    py = v[4]
                    v[3] = (sy*(px-tx)-ry*(py-ty))/d
                    v[4] = (sx*(py-ty)-rx*(px-tx))/d
                    px = v[5]
                    py = v[6]
                    v[5] = (sy*(px-tx)-ry*(py-ty))/d
                    v[6] = (sx*(py-ty)-rx*(px-tx))/d
                end
                path[k] = concat(v," ")
            end
        else
            for k=1,#m_stack_path do
                path[k] = concat(m_stack_path[k]," ")
            end
        end
        flushconcat()
        pdfcode(concat(path," "))
        if m_stack_close then
            mpscode("h " .. cmd)
        else
            mpscode(cmd)
        end
    end
    resetpath()
end

-- mp interface

local mps = { }

function mps.creator(a, b, c)
    m_version = tonumber(b)
end

function mps.creationdate(a)
    m_date = a
end

function mps.newpath()
    m_stack_path = { }
end

function mps.boundingbox(llx, lly, urx, ury)
    context.setMPboundingbox(llx,lly,urx,ury)
end

function mps.moveto(x,y)
    m_stack_path[#m_stack_path+1] = { x, y, "m" }
end

function mps.curveto(ax, ay, bx, by, cx, cy)
    m_stack_path[#m_stack_path+1] = { ax, ay, bx, by, cx, cy, "c" }
end

function mps.lineto(x,y)
    m_stack_path[#m_stack_path+1] = { x, y, "l" }
end

function mps.rlineto(x,y)
    local dx = 0
    local dy = 0
    local topofstack = #m_stack_path
    if topofstack > 0 then
        local msp = m_stack_path[topofstack]
        dx = msp[1]
        dy = msp[2]
    end
    m_stack_path[topofstack+1] = { dx, dy, "l" }
end

function mps.translate(tx,ty)
    mpscode(f_translate(tx,ty))
end

function mps.scale(sx,sy)
    m_stack_concat = { sx, 0, 0, sy, 0, 0 }
end

function mps.concat(sx, rx, ry, sy, tx, ty)
    m_stack_concat = { sx, rx, ry, sy, tx, ty }
end

function mps.setlinejoin(d)
    mpscode(d .. " j")
end

function mps.setlinecap(d)
    mpscode(d .. " J")
end

function mps.setmiterlimit(d)
    mpscode(d .. " M")
end

function mps.gsave()
    mpscode("q")
end

function mps.grestore()
    mpscode("Q")
end

function mps.setdash(...) -- can be made faster, operate on t = { ... }
    local n = select("#",...)
    mpscode("[" .. concat({...}," ",1,n-1) .. "] " .. select(n,...) .. " d")
 -- mpscode("[" .. concat({select(1,n-1)}," ") .. "] " .. select(n,...) .. " d")
end

function mps.resetdash()
    mpscode("[ ] 0 d")
end

function mps.setlinewidth(d)
    mpscode(d .. " w")
end

function mps.closepath()
    m_stack_close = true
end

function mps.fill()
    flushpath('f')
end

function mps.stroke()
    flushpath('S')
end

function mps.both()
    flushpath('B')
end

function mps.clip()
    flushpath('W n')
end

function mps.textext(font, scale, str) -- old parser
    local dx = 0
    local dy = 0
    if #m_stack_path > 0 then
        dx, dy = m_stack_path[1][1], m_stack_path[1][2]
    end
    flushconcat()
    context.MPtextext(font,scale,str,dx,dy)
    resetpath()
end

local handlers = { }

handlers[1] = function(s)
    pdfcode(pdffinishtransparencycode())
    pdfcode(pdfcmykcode(mps.colormodel,s[3],s[4],s[5],s[6]))
end
handlers[2] = function(s)
    pdfcode(pdffinishtransparencycode())
    pdfcode(pdfspotcode(mps.colormodel,s[3],s[4],s[5],s[6]))
end
handlers[3] = function(s)
    pdfcode(pdfrgbcode(mps.colormodel,s[4],s[5],s[6]))
    pdfcode(pdftransparencycode(s[2],s[3]))
end
handlers[4] = function(s)
    pdfcode(pdfcmykcode(mps.colormodel,s[4],s[5],s[6],s[7]))
    pdfcode(pdftransparencycode(s[2],s[3]))
end
handlers[5] = function(s)
    pdfcode(pdfspotcode(mps.colormodel,s[4],s[5],s[6],s[7]))
    pdfcode(pdftransparencycode(s[2],s[3]))
end

-- todo: color conversion

local nofshades, tn = 0, tonumber

local function linearshade(colorspace,domain,ca,cb,coordinates)
    pdfcode(pdffinishtransparencycode())
    nofshades = nofshades + 1
    local name = formatters["MpsSh%s"](nofshades)
    lpdf.linearshade(name,domain,ca,cb,1,colorspace,coordinates)
    extra_path_data, ignore_path = formatters["/%s sh Q"](name), true
    pdfcode("q /Pattern cs")
end

local function circularshade(colorspace,domain,ca,cb,coordinates)
    pdfcode(pdffinishtransparencycode())
    nofshades = nofshades + 1
    local name = formatters["MpsSh%s"](nofshades)
    lpdf.circularshade(name,domain,ca,cb,1,colorspace,coordinates)
    extra_path_data, ignore_path = formatters["/%s sh Q"](name), true
    pdfcode("q /Pattern cs")
end

handlers[30] = function(s)
    linearshade("DeviceRGB", { tn(s[ 2]), tn(s[ 3]) },
        { tn(s[ 5]), tn(s[ 6]), tn(s[ 7]) }, { tn(s[10]), tn(s[11]), tn(s[12]) },
        { tn(s[ 8]), tn(s[ 9]), tn(s[13]), tn(s[14]) } )
end

handlers[31] = function(s)
    circularshade("DeviceRGB", { tn(s[ 2]), tn(s[ 3]) },
        { tn(s[ 5]), tn(s[ 6]), tn(s[ 7]) }, { tn(s[11]), tn(s[12]), tn(s[13]) },
        { tn(s[ 8]), tn(s[ 9]), tn(s[10]), tn(s[14]), tn(s[15]), tn(s[16]) } )
end

handlers[32] = function(s)
    linearshade("DeviceCMYK", { tn(s[ 2]), tn(s[ 3]) },
        { tn(s[ 5]), tn(s[ 6]), tn(s[ 7]), tn(s[ 8]) }, { tn(s[11]), tn(s[12]), tn(s[13]), tn(s[14]) },
        { tn(s[ 9]), tn(s[10]), tn(s[15]), tn(s[16]) } )
end

handlers[33] = function(s)
    circularshade("DeviceCMYK", { tn(s[ 2]), tn(s[ 3]) },
        { tn(s[ 5]), tn(s[ 6]), tn(s[ 7]), tn(s[ 8]) }, { tn(s[12]), tn(s[13]), tn(s[14]), tn(s[15]) },
        { tn(s[ 9]), tn(s[10]), tn(s[11]), tn(s[16]), tn(s[17]), tn(s[18]) } )
end

handlers[34] = function(s) -- todo (after further cleanup)
    linearshade("DeviceGray", { tn(s[ 2]), tn(s[ 3]) }, { 0 }, { 1 }, { tn(s[9]), tn(s[10]), tn(s[15]), tn(s[16]) } )
end

handlers[35] = function(s) -- todo (after further cleanup)
    circularshade("DeviceGray",  { tn(s[ 2]), tn(s[ 3]) }, { 0 }, { 1 }, { tn(s[9]), tn(s[10]), tn(s[15]), tn(s[16]) } )
end

-- not supported in mkiv , use mplib instead

handlers[10] = function() report_mptopdf("skipping special %s",10) end
handlers[20] = function() report_mptopdf("skipping special %s",20) end
handlers[50] = function() report_mptopdf("skipping special %s",50) end

--end of not supported

function mps.setrgbcolor(r,g,b) -- extra check
    r = tonumber(r) -- needed when we use lpeg
    g = tonumber(g) -- needed when we use lpeg
    b = tonumber(b) -- needed when we use lpeg
    if r == 0.0123 and g < 0.1 then
        g = round(g*10000)
        b = round(b*10000)
        local s = specials[b]
        local h = round(s[#s])
        local handler = handlers[h]
        if handler then
            handler(s)
        else
            report_mptopdf("unknown special handler %s (1)",h)
        end
    elseif r == 0.123 and g < 0.1 then
        g = round(g*1000)
        b = round(b*1000)
        local s = specials[b]
        local h = round(s[#s])
        local handler = handlers[h]
        if handler then
            handler(s)
        else
            report_mptopdf("unknown special handler %s (2)",h)
        end
    else
        pdfcode(pdffinishtransparencycode())
        pdfcode(pdfrgbcode(mps.colormodel,r,g,b))
    end
end

function mps.setcmykcolor(c,m,y,k)
    pdfcode(pdffinishtransparencycode())
    pdfcode(pdfcmykcode(mps.colormodel,c,m,y,k))
end

function mps.setgray(s)
    pdfcode(pdffinishtransparencycode())
    pdfcode(pdfgraycode(mps.colormodel,s))
end

function mps.specials(version,signal,factor) -- 2.0 123 1000
end

function mps.special(...) -- 7 1 0.5 1 0 0 1 3
    local t = { ... }
    local n = tonumber(t[#t-1])
    specials[n] = t
end

function mps.begindata()
end

function mps.enddata()
end

function mps.showpage()
end

-- lpeg parser

-- The lpeg based parser is rather optimized for the kind of output
-- that MetaPost produces. It's my first real lpeg code, which may
-- show. Because the parser binds to functions, we define it last.

local lpegP, lpegR, lpegS, lpegC, lpegCc, lpegCs = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cc, lpeg.Cs

local digit    = lpegR("09")
local eol      = lpegS('\r\n')^1
local sp       = lpegP(' ')^1
local space    = lpegS(' \r\n')^1
local number   = lpegS('0123456789.-+')^1
local nonspace = lpegP(1-lpegS(' \r\n'))^1

local spec  = digit^2 * lpegP("::::") * digit^2
local text  = lpegCc("{") * (
        lpegP("\\") * ( (digit * digit * digit) / function(n) return "c" .. tonumber(n,8) end) +
                         lpegP(" ")             / function(n) return "\\c32" end + -- never in new mp
                         lpegP(1)               / function(n) return "\\c" .. byte(n) end
    ) * lpegCc("}")
local package = lpegCs(spec + text^0)

function mps.fshow(str,font,scale) -- lpeg parser
    mps.textext(font,scale,lpegmatch(package,str))
end

----- cnumber = lpegC(number)
local cnumber = number/tonumber -- we now expect numbers (feeds into %F)
local cstring = lpegC(nonspace)

local specials           = (lpegP("%%MetaPostSpecials:") * sp * (cstring * sp^0)^0 * eol) / mps.specials
local special            = (lpegP("%%MetaPostSpecial:")  * sp * (cstring * sp^0)^0 * eol) / mps.special
local boundingbox        = (lpegP("%%BoundingBox:")      * sp * (cnumber * sp^0)^4 * eol) / mps.boundingbox
local highresboundingbox = (lpegP("%%HiResBoundingBox:") * sp * (cnumber * sp^0)^4 * eol) / mps.boundingbox

local setup              = lpegP("%%BeginSetup")  * (1 - lpegP("%%EndSetup") )^1
local prolog             = lpegP("%%BeginProlog") * (1 - lpegP("%%EndProlog"))^1
local comment            = lpegP('%')^1 * (1 - eol)^1

local curveto            = ((cnumber * sp)^6 * lpegP("curveto")            ) / mps.curveto
local lineto             = ((cnumber * sp)^2 * lpegP("lineto")             ) / mps.lineto
local rlineto            = ((cnumber * sp)^2 * lpegP("rlineto")            ) / mps.rlineto
local moveto             = ((cnumber * sp)^2 * lpegP("moveto")             ) / mps.moveto
local setrgbcolor        = ((cnumber * sp)^3 * lpegP("setrgbcolor")        ) / mps.setrgbcolor
local setcmykcolor       = ((cnumber * sp)^4 * lpegP("setcmykcolor")       ) / mps.setcmykcolor
local setgray            = ((cnumber * sp)^1 * lpegP("setgray")            ) / mps.setgray
local newpath            = (                   lpegP("newpath")            ) / mps.newpath
local closepath          = (                   lpegP("closepath")          ) / mps.closepath
local fill               = (                   lpegP("fill")               ) / mps.fill
local stroke             = (                   lpegP("stroke")             ) / mps.stroke
local clip               = (                   lpegP("clip")               ) / mps.clip
local both               = (                   lpegP("gsave fill grestore")) / mps.both
local showpage           = (                   lpegP("showpage")           )
local setlinejoin        = ((cnumber * sp)^1 * lpegP("setlinejoin")        ) / mps.setlinejoin
local setlinecap         = ((cnumber * sp)^1 * lpegP("setlinecap")         ) / mps.setlinecap
local setmiterlimit      = ((cnumber * sp)^1 * lpegP("setmiterlimit")      ) / mps.setmiterlimit
local gsave              = (                   lpegP("gsave")              ) / mps.gsave
local grestore           = (                   lpegP("grestore")           ) / mps.grestore

local setdash            = (lpegP("[") * (cnumber * sp^0)^0 * lpegP("]") * sp * cnumber * sp * lpegP("setdash")) / mps.setdash
local concat             = (lpegP("[") * (cnumber * sp^0)^6 * lpegP("]")                * sp * lpegP("concat") ) / mps.concat
local scale              = (             (cnumber * sp^0)^6                             * sp * lpegP("concat") ) / mps.concat

local fshow              = (lpegP("(") * lpegC((1-lpegP(")"))^1) * lpegP(")") * space * cstring * space * cnumber * space * lpegP("fshow")) / mps.fshow
local fshow              = (lpegP("(") * lpegCs( ( lpegP("\\(")/"\\050" + lpegP("\\)")/"\\051" + (1-lpegP(")")) )^1 )
                            * lpegP(")") * space * cstring * space * cnumber * space * lpegP("fshow")) / mps.fshow

local setlinewidth_x     = (lpegP("0") * sp * cnumber * sp * lpegP("dtransform truncate idtransform setlinewidth pop")) / mps.setlinewidth
local setlinewidth_y     = (cnumber * sp * lpegP("0 dtransform exch truncate exch idtransform pop setlinewidth")  ) / mps.setlinewidth

local c   = ((cnumber * sp)^6 * lpegP("c")  ) / mps.curveto -- ^6 very inefficient, ^1 ok too
local l   = ((cnumber * sp)^2 * lpegP("l")  ) / mps.lineto
local r   = ((cnumber * sp)^2 * lpegP("r")  ) / mps.rlineto
local m   = ((cnumber * sp)^2 * lpegP("m")  ) / mps.moveto
local vlw = ((cnumber * sp)^1 * lpegP("vlw")) / mps.setlinewidth
local hlw = ((cnumber * sp)^1 * lpegP("hlw")) / mps.setlinewidth

local R   = ((cnumber * sp)^3 * lpegP("R")  ) / mps.setrgbcolor
local C   = ((cnumber * sp)^4 * lpegP("C")  ) / mps.setcmykcolor
local G   = ((cnumber * sp)^1 * lpegP("G")  ) / mps.setgray

local lj  = ((cnumber * sp)^1 * lpegP("lj") ) / mps.setlinejoin
local ml  = ((cnumber * sp)^1 * lpegP("ml") ) / mps.setmiterlimit
local lc  = ((cnumber * sp)^1 * lpegP("lc") ) / mps.setlinecap

local n   = lpegP("n") / mps.newpath
local p   = lpegP("p") / mps.closepath
local S   = lpegP("S") / mps.stroke
local F   = lpegP("F") / mps.fill
local B   = lpegP("B") / mps.both
local W   = lpegP("W") / mps.clip
local P   = lpegP("P") / mps.showpage

local q   = lpegP("q") / mps.gsave
local Q   = lpegP("Q") / mps.grestore

local sd  = (lpegP("[") * (cnumber * sp^0)^0 * lpegP("]") * sp * cnumber * sp * lpegP("sd")) / mps.setdash
local rd  = (                                                                   lpegP("rd")) / mps.resetdash

local s   = (             (cnumber * sp^0)^2                   * lpegP("s") ) / mps.scale
local t   = (lpegP("[") * (cnumber * sp^0)^6 * lpegP("]") * sp * lpegP("t") ) / mps.concat

-- experimental

local preamble = (
    prolog + setup +
    boundingbox + highresboundingbox + specials + special +
    comment
)

local procset = (
    lj + ml + lc +
    c + l + m + n + p + r +
    R + C + G +
    S + F + B + W +
    vlw + hlw +
    Q + q +
    sd + rd +
    t + s +
    fshow +
    P
)

local verbose = (
    curveto + lineto + moveto + newpath + closepath + rlineto +
    setrgbcolor + setcmykcolor + setgray +
    setlinejoin + setmiterlimit + setlinecap +
    stroke + fill + clip + both +
    setlinewidth_x + setlinewidth_y +
    gsave + grestore +
    concat + scale +
    fshow +
    setdash + -- no resetdash
    showpage
)

-- order matters in terms of speed / we could check for procset first

local captures_old = ( space + verbose + preamble           )^0
local captures_new = ( space + verbose + procset + preamble )^0

local function parse(m_data)
    if find(m_data,"%%BeginResource: procset mpost",1,true) then
     -- report_mptopdf("using sparse scanner, case 1")
        lpegmatch(captures_new,m_data)
    elseif find(m_data,"%%%%BeginProlog%s*%S+(.-)%%%%EndProlog") then
     -- report_mptopdf("using sparse scanner, case 2")
        lpegmatch(captures_new,m_data)
    else
     -- report_mptopdf("using verbose ps scanner")
        lpegmatch(captures_old,m_data)
    end
end

-- main converter

local a_colormodel = attributes.private('colormodel')

function mptopdf.convertmpstopdf(name)
    resetall()
    local ok, m_data, n = resolvers.loadbinfile(name, 'tex') -- we need a binary load !
    if ok then
        mps.colormodel = texgetattribute(a_colormodel)
        statistics.starttiming(mptopdf)
        mptopdf.nofconverted = mptopdf.nofconverted + 1
        pdfcode(formatters["\\letterpercent\\space mptopdf begin: n=%s, file=%s"](mptopdf.nofconverted,file.basename(name)))
        pdfcode("q 1 0 0 1 0 0 cm")
        parse(m_data)
        pdfcode(pdffinishtransparencycode())
        pdfcode("Q")
        pdfcode("\\letterpercent\\space mptopdf end")
        resetall()
        statistics.stoptiming(mptopdf)
    else
        report_mptopdf("file %a not found",name)
    end
end

-- status info

statistics.register("mps conversion time",function()
    local n = mptopdf.nofconverted
    if n > 0 then
        return format("%s seconds, %s conversions", statistics.elapsedtime(mptopdf),n)
    else
        return nil
    end
end)

-- interface

interfaces.implement {
    name      = "convertmpstopdf",
    arguments = "string",
    actions   = mptopdf.convertmpstopdf
}
