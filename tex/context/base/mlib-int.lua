if not modules then modules = { } end modules ['mlib-int'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local factor    = number.dimenfactors.bp
local mpprint   = mp.print
local mpboolean = mp.boolean
local mpquoted  = mp.quoted
local getdimen  = tex.getdimen
local getcount  = tex.getcount
local get       = tex.get
local mpcolor   = attributes.colors.mpcolor
local emwidths  = fonts.hashes.emwidths
local exheights = fonts.hashes.exheights

function mp.PaperHeight         () mpprint(getdimen("paperheight")         *factor) end
function mp.PaperWidth          () mpprint(getdimen("paperwidth")          *factor) end
function mp.PrintPaperHeight    () mpprint(getdimen("printpaperheight")    *factor) end
function mp.PrintPaperWidth     () mpprint(getdimen("printpaperwidth")     *factor) end
function mp.TopSpace            () mpprint(getdimen("topspace")            *factor) end
function mp.BottomSpace         () mpprint(getdimen("bottomspace")         *factor) end
function mp.BackSpace           () mpprint(getdimen("backspace")           *factor) end
function mp.CutSpace            () mpprint(getdimen("cutspace")            *factor) end
function mp.MakeupHeight        () mpprint(getdimen("makeupheight")        *factor) end
function mp.MakeupWidth         () mpprint(getdimen("makeupwidth")         *factor) end
function mp.TopHeight           () mpprint(getdimen("topheight")           *factor) end
function mp.TopDistance         () mpprint(getdimen("topdistance")         *factor) end
function mp.HeaderHeight        () mpprint(getdimen("headerheight")        *factor) end
function mp.HeaderDistance      () mpprint(getdimen("headerdistance")      *factor) end
function mp.TextHeight          () mpprint(getdimen("textheight")          *factor) end
function mp.FooterDistance      () mpprint(getdimen("footerdistance")      *factor) end
function mp.FooterHeight        () mpprint(getdimen("footerheight")        *factor) end
function mp.BottomDistance      () mpprint(getdimen("bottomdistance")      *factor) end
function mp.BottomHeight        () mpprint(getdimen("bottomheight")        *factor) end
function mp.LeftEdgeWidth       () mpprint(getdimen("leftedgewidth")       *factor) end
function mp.LeftEdgeDistance    () mpprint(getdimen("leftedgedistance")    *factor) end
function mp.LeftMarginWidth     () mpprint(getdimen("leftmarginwidth")     *factor) end
function mp.LeftMarginDistance  () mpprint(getdimen("leftmargindistance")  *factor) end
function mp.TextWidth           () mpprint(getdimen("textwidth")           *factor) end
function mp.RightMarginDistance () mpprint(getdimen("rightmargindistance") *factor) end
function mp.RightMarginWidth    () mpprint(getdimen("rightmarginwidth")    *factor) end
function mp.RightEdgeDistance   () mpprint(getdimen("rightedgedistance")   *factor) end
function mp.RightEdgeWidth      () mpprint(getdimen("rightedgewidth")      *factor) end
function mp.InnerMarginDistance () mpprint(getdimen("innermargindistance") *factor) end
function mp.InnerMarginWidth    () mpprint(getdimen("innermarginwidth")    *factor) end
function mp.OuterMarginDistance () mpprint(getdimen("outermargindistance") *factor) end
function mp.OuterMarginWidth    () mpprint(getdimen("outermarginwidth")    *factor) end
function mp.InnerEdgeDistance   () mpprint(getdimen("inneredgedistance")   *factor) end
function mp.InnerEdgeWidth      () mpprint(getdimen("inneredgewidth")      *factor) end
function mp.OuterEdgeDistance   () mpprint(getdimen("outeredgedistance")   *factor) end
function mp.OuterEdgeWidth      () mpprint(getdimen("outeredgewidth")      *factor) end
function mp.PageOffset          () mpprint(getdimen("pagebackgroundoffset")*factor) end
function mp.PageDepth           () mpprint(getdimen("pagebackgrounddepth") *factor) end
function mp.LayoutColumns       () mpprint(getcount("layoutcolumns"))               end
function mp.LayoutColumnDistance() mpprint(getdimen("layoutcolumndistance")*factor) end
function mp.LayoutColumnWidth   () mpprint(getdimen("layoutcolumnwidth")   *factor) end

function mp.PageNumber          () mpprint(getcount("pageno"))                      end
function mp.RealPageNumber      () mpprint(getcount("realpageno"))                  end
function mp.NOfPages            () mpprint(getcount("lastpageno"))                  end

function mp.CurrentColumn       () mpprint(getcount("mofcolumns"))                  end
function mp.NOfColumns          () mpprint(getcount("nofcolumns"))                  end

function mp.BaseLineSkip        () mpprint(getdimen("baselineskip")        *factor) end
function mp.LineHeight          () mpprint(getdimen("lineheight")          *factor) end
function mp.BodyFontSize        () mpprint(getdimen("bodyfontsize")        *factor) end

function mp.TopSkip             () mpprint(getdimen("topskip")             *factor) end
function mp.StrutHeight         () mpprint(getdimen("strutht")             *factor) end
function mp.StrutDepth          () mpprint(getdimen("strutdp")             *factor) end

function mp.PageNumber          () mpprint(getcount("pageno"))                      end
function mp.RealPageNumber      () mpprint(getcount("realpageno"))                  end
function mp.NOfPages            () mpprint(getcount("lastpageno"))                  end

function mp.CurrentWidth        () mpprint(get("hsize")                    *factor) end
function mp.CurrentHeight       () mpprint(get("vsize")                    *factor) end

function mp.EmWidth             () mpprint(emwidths [false]*factor) end
function mp.ExHeight            () mpprint(exheights[false]*factor) end

mp.HSize          = mp.CurrentWidth
mp.VSize          = mp.CurrentHeight
mp.LastPageNumber = mp.NOfPages

function mp.PageFraction         ()
    local lastpage = getcount("lastpageno")
    if lastpage > 1 then
        mpprint((getcount("realpageno")-1)/(lastpage-1))
    else
        mpprint(1)
    end
end

-- locals

mp.OnRightPage = function() mpprint(structures.pages.on_right()) end -- needs checking
mp.OnOddPage   = function() mpprint(structures.pages.is_odd  ()) end -- needs checking
mp.InPageBody  = function() mpprint(structures.pages.in_body ()) end -- needs checking

-- mp.CurrentLayout    : \currentlayout

function mp.OverlayWidth     () mpprint(getdimen("d_overlay_width")    *factor) end
function mp.OverlayHeight    () mpprint(getdimen("d_overlay_height")   *factor) end
function mp.OverlayDepth     () mpprint(getdimen("d_overlay_depth")    *factor) end
function mp.OverlayLineWidth () mpprint(getdimen("d_overlay_linewidth")*factor) end
function mp.OverlayOffset    () mpprint(getdimen("d_overlay_offset")   *factor) end

function mp.defaultcolormodel()
    local colormethod = getcount("MPcolormethod")
 -- if colormethod == 0 then
 --     return 1
 -- elseif colormethod == 1 then
 --     return 1
 -- elseif colormethod == 2 then
 --     return 3
 -- else
 --     return 3
 -- end
    return (colormethod == 0 or colormethod == 1) and 1 or 3
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
