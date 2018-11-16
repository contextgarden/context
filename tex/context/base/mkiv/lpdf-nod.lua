if not modules then modules = { } end modules ['lpdf-nod'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type

local formatters       = string.formatters

local nodecodes        = nodes.nodecodes
local whatsit_code     = nodecodes.whatsit

local whatsitcodes     = nodes.whatsitcodes
local pdfliteralcode   = whatsitcodes.pdfliteral
local pdfsavecode      = whatsitcodes.pdfsave
local pdfrestorecode   = whatsitcodes.pdfrestore
local pdfsetmatrixcode = whatsitcodes.pdfsetmatrix

local nodeinjections   = backends.nodeinjections

local nuts             = nodes.nuts
local tonut            = nuts.tonut

local setfield         = nuts.setfield
local setdata          = nuts.setdata

local copy_node        = nuts.copy
local new_node         = nuts.new

local nodepool         = nuts.pool
local register         = nodepool.register

local literalvalues    = nodes.literalvalues
local originliteral    = literalvalues.origin
local pageliteral      = literalvalues.page
local directliteral    = literalvalues.direct
local rawliteral       = literalvalues.raw

local pdforiginliteral = register(new_node(whatsit_code, pdfliteralcode))  setfield(pdforiginliteral,"mode",originliteral)
local pdfpageliteral   = register(new_node(whatsit_code, pdfliteralcode))  setfield(pdfpageliteral,  "mode",pageliteral)
local pdfdirectliteral = register(new_node(whatsit_code, pdfliteralcode))  setfield(pdfdirectliteral,"mode",directliteral)
local pdfrawliteral    = register(new_node(whatsit_code, pdfliteralcode))  setfield(pdfrawliteral,   "mode",rawliteral)

local pdfsave          = register(new_node(whatsit_code, pdfsavecode))
local pdfrestore       = register(new_node(whatsit_code, pdfrestorecode))
local pdfsetmatrix     = register(new_node(whatsit_code, pdfsetmatrixcode))

local variables        = interfaces.variables

function nodepool.pdforiginliteral(str) local t = copy_node(pdforiginliteral) setdata(t,str) return t end
function nodepool.pdfpageliteral  (str) local t = copy_node(pdfpageliteral  ) setdata(t,str) return t end
function nodepool.pdfdirectliteral(str) local t = copy_node(pdfdirectliteral) setdata(t,str) return t end
function nodepool.pdfrawliteral   (str) local t = copy_node(pdfrawliteral   ) setdata(t,str) return t end

-- best is to use a specific one: origin | page | direct | raw

-- nodepool.pdfliteral = nodepool.pdfpageliteral -- or is origin the default ?

local pdfliterals = {
    -- by number
    [originliteral] = pdforiginliteral,
    [pageliteral]   = pdfpageliteral,
    [directliteral] = pdfdirectliteral,
    [rawliteral]    = pdfrawliteral,
    -- by name
    [literalvalues[originliteral]] = pdforiginliteral,
    [literalvalues[pageliteral]]   = pdfpageliteral,
    [literalvalues[directliteral]] = pdfdirectliteral,
    [literalvalues[rawliteral]]    = pdfrawliteral,
}

function nodepool.pdfliteral(mode,str)
    if str then
        local t = copy_node(pdfliterals[mode] or pdfpageliteral)
        setdata(t,str)
        return t
    else
        local t = copy_node(pdfpageliteral)
        setdata(t,mode)
        return t
    end
end

function nodepool.pdfsave()
    return copy_node(pdfsave)
end

function nodepool.pdfrestore()
    return copy_node(pdfrestore)
end

local s_matrix_0 = "1 0 0 1"
local f_matrix_2 = formatters["%.6F 0 0 %.6F"]
local f_matrix_4 = formatters["%.6F %.6F %.6F %.6F"]

directives.register("pdf.stripzeros",function()
    f_matrix_2 = formatters["%.6N 0 0 %.6N"]
    f_matrix_4 = formatters["%.6N %.6N %.6N %.6N"]
end)

function nodepool.pdfsetmatrix(rx,sx,sy,ry,tx,ty) -- todo: tx ty
    local t = copy_node(pdfsetmatrix)
    if type(rx) == "string" then
        setdata(t,rx)
    else
        if not rx then
            rx = 1
        elseif rx == 0 then
            rx = 0.0001
        end
        if not ry then
            ry = 1
        elseif ry == 0 then
            ry = 0.0001
        end
        if not sx then
            sx = 0
        end
        if not sy then
            sy = 0
        end
        if sx == 0 and sy == 0 then
            if rx == 1 and ry == 1 then
                setdata(t,s_matrix_0)
            else
                setdata(t,f_matrix_2(rx,ry))
            end
        else
            setdata(t,f_matrix_4(rx,sx,sy,ry))
        end
    end
    return t
end

nodeinjections.save      = nodepool.pdfsave
nodeinjections.restore   = nodepool.pdfrestore
nodeinjections.transform = nodepool.pdfsetmatrix

-- the next one is implemented differently, using latelua

function nodepool.pdfannotation(w,h,d,data,n)
    report("don't use node based annotations!")
    os.exit()
 -- local t = copy_node(pdfannot)
 -- if w and w ~= 0 then
 --     setfield(t,"width",w)
 -- end
 -- if h and h ~= 0 then
 --     setfield(t,"height",h)
 -- end
 -- if d and d ~= 0 then
 --     setfield(t,"depth",d)
 -- end
 -- if n then
 --     setfield(t,"objnum",n)
 -- end
 -- if data and data ~= "" then
 --     setfield(t,"data",data)
 -- end
 -- return t
end

-- (!) The next code in pdfdest.w is wrong:
--
-- case pdf_dest_xyz:
--     if (matrixused()) {
--         set_rect_dimens(pdf, p, parent_box, cur, alt_rule, pdf_dest_margin) ;
--     } else {
--         pdf_ann_left(p) = pos.h ;
--         pdf_ann_top (p) = pos.v ;
--     }
--     break ;
--
-- so we need to force a matrix.

-- local views = { -- beware, we do support the pdf keys but this is *not* official
--     xyz   = 0, [variables.standard]  = 0,
--     fit   = 1, [variables.fit]       = 1,
--     fith  = 2, [variables.width]     = 2,
--     fitv  = 3, [variables.height]    = 3,
--     fitb  = 4,
--     fitbh = 5, [variables.minwidth]  = 5,
--     fitbv = 6, [variables.minheight] = 6,
--     fitr  = 7,
-- }

function nodepool.pdfdestination(w,h,d,name,view,n)
    report("don't use node based destinations!")
    os.exit()
 -- local t = copy_node(pdfdest)
 -- local hasdimensions = false
 -- if w and w ~= 0 then
 --     setfield(t,"width",w)
 --     hasdimensions = true
 -- end
 -- if h and h ~= 0 then
 --     setfield(t,"height",h)
 --     hasdimensions = true
 -- end
 -- if d and d ~= 0 then
 --     setfield(t,"depth",d)
 --     hasdimensions = true
 -- end
 -- if n then
 --     setfield(t,"objnum",n)
 -- end
 -- view = views[view] or view or 1 -- fit is default
 -- setfield(t,"dest_id",name)
 -- setfield(t,"dest_type",view)
 -- if hasdimensions and view == 0 then -- xyz
 --     -- see (!) s -> m -> t -> r
 --     -- linked
 --     local s = copy_node(pdfsave)
 --     local m = copy_node(pdfsetmatrix)
 --     local r = copy_node(pdfrestore)
 --     setfield(m,"data","1 0 0 1")
 --     setfield(s,"next",m)
 --     setfield(m,"next",t)
 --     setfield(t,"next",r)
 --     setfield(m,"prev",s)
 --     setfield(t,"prev",m)
 --     setfield(r,"prev",t)
 --     return s -- a list
 -- else
 --     return t
 -- end
end
