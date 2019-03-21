if not modules then modules = { } end modules ['mlib-int'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local factor    = number.dimenfactors.bp
----- mpprint   = mp.print
local mpnumeric = mp.numeric
local mpboolean = mp.boolean
local mpstring  = mp.string
local mpquoted  = mp.quoted
local getdimen  = tex.getdimen
local getcount  = tex.getcount
local getmacro  = tokens.getters.macro
local get       = tex.get
local mpcolor   = attributes.colors.mpcolor
local emwidths  = fonts.hashes.emwidths
local exheights = fonts.hashes.exheights

local mpgetdimen = mp.getdimen

function mp.PaperHeight         () mpnumeric(getdimen("paperheight")         *factor) end
function mp.PaperWidth          () mpnumeric(getdimen("paperwidth")          *factor) end
function mp.PrintPaperHeight    () mpnumeric(getdimen("printpaperheight")    *factor) end
function mp.PrintPaperWidth     () mpnumeric(getdimen("printpaperwidth")     *factor) end
function mp.TopSpace            () mpnumeric(getdimen("topspace")            *factor) end
function mp.BottomSpace         () mpnumeric(getdimen("bottomspace")         *factor) end
function mp.BackSpace           () mpnumeric(getdimen("backspace")           *factor) end
function mp.CutSpace            () mpnumeric(getdimen("cutspace")            *factor) end
function mp.MakeupHeight        () mpnumeric(getdimen("makeupheight")        *factor) end
function mp.MakeupWidth         () mpnumeric(getdimen("makeupwidth")         *factor) end
function mp.TopHeight           () mpnumeric(getdimen("topheight")           *factor) end
function mp.TopDistance         () mpnumeric(getdimen("topdistance")         *factor) end
function mp.HeaderHeight        () mpnumeric(getdimen("headerheight")        *factor) end
function mp.HeaderDistance      () mpnumeric(getdimen("headerdistance")      *factor) end
function mp.TextHeight          () mpnumeric(getdimen("textheight")          *factor) end
function mp.FooterDistance      () mpnumeric(getdimen("footerdistance")      *factor) end
function mp.FooterHeight        () mpnumeric(getdimen("footerheight")        *factor) end
function mp.BottomDistance      () mpnumeric(getdimen("bottomdistance")      *factor) end
function mp.BottomHeight        () mpnumeric(getdimen("bottomheight")        *factor) end
function mp.LeftEdgeWidth       () mpnumeric(getdimen("leftedgewidth")       *factor) end
function mp.LeftEdgeDistance    () mpnumeric(getdimen("leftedgedistance")    *factor) end
function mp.LeftMarginWidth     () mpnumeric(getdimen("leftmarginwidth")     *factor) end
function mp.LeftMarginDistance  () mpnumeric(getdimen("leftmargindistance")  *factor) end
function mp.TextWidth           () mpnumeric(getdimen("textwidth")           *factor) end
function mp.RightMarginDistance () mpnumeric(getdimen("rightmargindistance") *factor) end
function mp.RightMarginWidth    () mpnumeric(getdimen("rightmarginwidth")    *factor) end
function mp.RightEdgeDistance   () mpnumeric(getdimen("rightedgedistance")   *factor) end
function mp.RightEdgeWidth      () mpnumeric(getdimen("rightedgewidth")      *factor) end
function mp.InnerMarginDistance () mpnumeric(getdimen("innermargindistance") *factor) end
function mp.InnerMarginWidth    () mpnumeric(getdimen("innermarginwidth")    *factor) end
function mp.OuterMarginDistance () mpnumeric(getdimen("outermargindistance") *factor) end
function mp.OuterMarginWidth    () mpnumeric(getdimen("outermarginwidth")    *factor) end
function mp.InnerEdgeDistance   () mpnumeric(getdimen("inneredgedistance")   *factor) end
function mp.InnerEdgeWidth      () mpnumeric(getdimen("inneredgewidth")      *factor) end
function mp.OuterEdgeDistance   () mpnumeric(getdimen("outeredgedistance")   *factor) end
function mp.OuterEdgeWidth      () mpnumeric(getdimen("outeredgewidth")      *factor) end
function mp.PageOffset          () mpnumeric(getdimen("pagebackgroundoffset")*factor) end
function mp.PageDepth           () mpnumeric(getdimen("pagebackgrounddepth") *factor) end
function mp.LayoutColumns       () mpnumeric(getcount("layoutcolumns"))               end
function mp.LayoutColumnDistance() mpnumeric(getdimen("layoutcolumndistance")*factor) end
function mp.LayoutColumnWidth   () mpnumeric(getdimen("layoutcolumnwidth")   *factor) end
function mp.SpineWidth          () mpnumeric(getdimen("spinewidth")          *factor) end
function mp.PaperBleed          () mpnumeric(getdimen("paperbleed")          *factor) end

function mp.RealPageNumber      () mpnumeric(getcount("realpageno"))                  end
function mp.LastPageNumber      () mpnumeric(getcount("lastpageno"))                  end

function mp.PageNumber          () mpnumeric(getcount("pageno"))                      end
function mp.NOfPages            () mpnumeric(getcount("lastpageno"))                  end

function mp.SubPageNumber       () mpnumeric(getcount("subpageno"))                   end
function mp.NOfSubPages         () mpnumeric(getcount("lastsubpageno"))               end

function mp.CurrentColumn       () mpnumeric(getcount("mofcolumns"))                  end
function mp.NOfColumns          () mpnumeric(getcount("nofcolumns"))                  end

function mp.BaseLineSkip        () mpnumeric(get     ("baselineskip",true)   *factor) end
function mp.LineHeight          () mpnumeric(getdimen("lineheight")          *factor) end
function mp.BodyFontSize        () mpnumeric(getdimen("bodyfontsize")        *factor) end

function mp.TopSkip             () mpnumeric(get     ("topskip",true)        *factor) end
function mp.StrutHeight         () mpnumeric(getdimen("strutht")             *factor) end
function mp.StrutDepth          () mpnumeric(getdimen("strutdp")             *factor) end

function mp.PageNumber          () mpnumeric(getcount("pageno"))                      end
function mp.RealPageNumber      () mpnumeric(getcount("realpageno"))                  end
function mp.NOfPages            () mpnumeric(getcount("lastpageno"))                  end

function mp.CurrentWidth        () mpnumeric(get     ("hsize")               *factor) end
function mp.CurrentHeight       () mpnumeric(get     ("vsize")               *factor) end

function mp.EmWidth             () mpnumeric(emwidths [false]*factor) end
function mp.ExHeight            () mpnumeric(exheights[false]*factor) end

mp.HSize          = mp.CurrentWidth
mp.VSize          = mp.CurrentHeight
mp.LastPageNumber = mp.NOfPages

function mp.PageFraction()
    local lastpage = getcount("lastpageno")
    if lastpage > 1 then
        mpnumeric((getcount("realpageno")-1)/(lastpage-1))
    else
        mpnumeric(1)
    end
end

-- locals

local on_right = structures.pages.on_right
local is_odd   = structures.pages.is_odd
local in_body  = structures.pages.in_body

mp.OnRightPage = function() mpboolean(on_right()) end -- needs checking
mp.OnOddPage   = function() mpboolean(is_odd  ()) end -- needs checking
mp.InPageBody  = function() mpboolean(in_body ()) end -- needs checking

-- mp.CurrentLayout    : \currentlayout

function mp.OverlayWidth    () mpnumeric(getdimen("d_overlay_width")     * factor) end
function mp.OverlayHeight   () mpnumeric(getdimen("d_overlay_height")    * factor) end
function mp.OverlayDepth    () mpnumeric(getdimen("d_overlay_depth")     * factor) end
function mp.OverlayLineWidth() mpnumeric(getdimen("d_overlay_linewidth") * factor) end
function mp.OverlayOffset   () mpnumeric(getdimen("d_overlay_offset")    * factor) end
function mp.OverlayRegion   () mpstring(getmacro("m_overlay_region")) end

function mp.mf_default_color_model()
    local colormethod = getcount("MPcolormethod")
    return mpnumeric((colormethod == 0 or colormethod == 1) and 1 or 3)
end

-- not much difference (10000 calls in a graphic neither as expansion seems to win
-- over defining the macro etc) so let's not waste counters then

-- function mp.OverlayColor()
--     local c = mpcolor(
--         getcount("c_overlay_colormodel"),
--         getcount("c_overlay_color"),
--         getcount("c_overlay_transparency")
--     )
--     mpquoted(c)
-- end
--
-- function mp.OverlayLineColor()
--     local c = mpcolor(
--         getcount("c_overlay_colormodel"),
--         getcount("c_overlay_linecolor"),
--         getcount("c_overlay_linetransparency")
--     )
--     mpquoted(c)
-- end
