if not modules then modules = { } end modules ['mlib-int'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local factor         = number.dimenfactors.bp
----- mpprint        = mp.print
local mpnumeric      = mp.numeric
local mpboolean      = mp.boolean
local mpstring       = mp.string
local mpquoted       = mp.quoted
local getdimen       = tex.getdimen
local getcount       = tex.getcount
local getmacro       = tokens.getters.macro
local get            = tex.get
local mpcolor        = attributes.colors.mpcolor
local emwidths       = fonts.hashes.emwidths
local exheights      = fonts.hashes.exheights

local mpgetdimen     = mp.getdimen

local registerscript = metapost.registerscript

local on_right_page  = structures.pages.on_right
local is_odd_page    = structures.pages.is_odd
local in_body_page   = structures.pages.in_body
local page_fraction  = structures.pages.fraction

local function defaultcolormodel() -- can be helper
    local colormethod = getcount("MPcolormethod")
    return (colormethod == 0 or colormethod == 1) and 1 or 3
end

if CONTEXTLMTXMODE > 0 then

    local t = os.date("*t") -- maybe this should be a very early on global

    registerscript("year",   function() return t.year  end)
    registerscript("month",  function() return t.month end)
    registerscript("day",    function() return t.day   end)
    registerscript("hour",   function() return t.hour  end)
    registerscript("minute", function() return t.min   end)
    registerscript("second", function() return t.sec   end)

    registerscript("PaperHeight",          function() return getdimen("paperheight")          * factor end)
    registerscript("PaperWidth",           function() return getdimen("paperwidth")           * factor end)
    registerscript("PrintPaperHeight",     function() return getdimen("printpaperheight")     * factor end)
    registerscript("PrintPaperWidth",      function() return getdimen("printpaperwidth")      * factor end)
    registerscript("TopSpace",             function() return getdimen("topspace")             * factor end)
    registerscript("BottomSpace",          function() return getdimen("bottomspace")          * factor end)
    registerscript("BackSpace",            function() return getdimen("backspace")            * factor end)
    registerscript("CutSpace",             function() return getdimen("cutspace")             * factor end)
    registerscript("MakeupHeight",         function() return getdimen("makeupheight")         * factor end)
    registerscript("MakeupWidth",          function() return getdimen("makeupwidth")          * factor end)
    registerscript("TopHeight",            function() return getdimen("topheight")            * factor end)
    registerscript("TopDistance",          function() return getdimen("topdistance")          * factor end)
    registerscript("HeaderHeight",         function() return getdimen("headerheight")         * factor end)
    registerscript("HeaderDistance",       function() return getdimen("headerdistance")       * factor end)
    registerscript("TextHeight",           function() return getdimen("textheight")           * factor end)
    registerscript("FooterDistance",       function() return getdimen("footerdistance")       * factor end)
    registerscript("FooterHeight",         function() return getdimen("footerheight")         * factor end)
    registerscript("BottomDistance",       function() return getdimen("bottomdistance")       * factor end)
    registerscript("BottomHeight",         function() return getdimen("bottomheight")         * factor end)
    registerscript("LeftEdgeWidth",        function() return getdimen("leftedgewidth")        * factor end)
    registerscript("LeftEdgeDistance",     function() return getdimen("leftedgedistance")     * factor end)
    registerscript("LeftMarginWidth",      function() return getdimen("leftmarginwidth")      * factor end)
    registerscript("LeftMarginDistance",   function() return getdimen("leftmargindistance")   * factor end)
    registerscript("TextWidth",            function() return getdimen("textwidth")            * factor end)
    registerscript("RightMarginDistance",  function() return getdimen("rightmargindistance")  * factor end)
    registerscript("RightMarginWidth",     function() return getdimen("rightmarginwidth")     * factor end)
    registerscript("RightEdgeDistance",    function() return getdimen("rightedgedistance")    * factor end)
    registerscript("RightEdgeWidth",       function() return getdimen("rightedgewidth")       * factor end)
    registerscript("InnerMarginDistance",  function() return getdimen("innermargindistance")  * factor end)
    registerscript("InnerMarginWidth",     function() return getdimen("innermarginwidth")     * factor end)
    registerscript("OuterMarginDistance",  function() return getdimen("outermargindistance")  * factor end)
    registerscript("OuterMarginWidth",     function() return getdimen("outermarginwidth")     * factor end)
    registerscript("InnerEdgeDistance",    function() return getdimen("inneredgedistance")    * factor end)
    registerscript("InnerEdgeWidth",       function() return getdimen("inneredgewidth")       * factor end)
    registerscript("OuterEdgeDistance",    function() return getdimen("outeredgedistance")    * factor end)
    registerscript("OuterEdgeWidth",       function() return getdimen("outeredgewidth")       * factor end)
    registerscript("PageOffset",           function() return getdimen("pagebackgroundoffset") * factor end)
    registerscript("PageDepth",            function() return getdimen("pagebackgrounddepth")  * factor end)
    registerscript("LayoutColumns",        function() return getcount("layoutcolumns")                 end)
    registerscript("LayoutColumnDistance", function() return getdimen("layoutcolumndistance") * factor end)
    registerscript("LayoutColumnWidth",    function() return getdimen("layoutcolumnwidth")    * factor end)
    registerscript("SpineWidth",           function() return getdimen("spinewidth")           * factor end)
    registerscript("PaperBleed",           function() return getdimen("paperbleed")           * factor end)

    registerscript("RealPageNumber",       function() return getcount("realpageno")                    end)
    registerscript("LastPageNumber",       function() return getcount("lastpageno")                    end)

    registerscript("PageNumber",           function() return getcount("pageno")                        end)
    registerscript("NOfPages",             function() return getcount("lastpageno")                    end)

    registerscript("SubPageNumber",        function() return getcount("subpageno")                     end)
    registerscript("NOfSubPages",          function() return getcount("lastsubpageno")                 end)

    registerscript("CurrentColumn",        function() return getcount("mofcolumns")                    end)
    registerscript("NOfColumns",           function() return getcount("nofcolumns")                    end)

    registerscript("BaseLineSkip",         function() return get     ("baselineskip",true)    * factor end)
    registerscript("LineHeight",           function() return getdimen("lineheight")           * factor end)
    registerscript("BodyFontSize",         function() return getdimen("bodyfontsize")         * factor end)

    registerscript("TopSkip",              function() return get     ("topskip",true)         * factor end)
    registerscript("StrutHeight",          function() return getdimen("strutht")              * factor end)
    registerscript("StrutDepth",           function() return getdimen("strutdp")              * factor end)

    registerscript("PageNumber",           function() return getcount("pageno")                        end)
    registerscript("RealPageNumber",       function() return getcount("realpageno")                    end)
    registerscript("NOfPages",             function() return getcount("lastpageno")                    end)

    registerscript("CurrentWidth",         function() return get     ("hsize")                * factor end)
    registerscript("CurrentHeight",        function() return get     ("vsize")                * factor end)

    registerscript("EmWidth",              function() return emwidths [false]                 * factor end)
    registerscript("ExHeight",             function() return exheights[false]                 * factor end)

    registerscript("HSize",                function() return get     ("hsize")                * factor end)
    registerscript("VSize",                function() return get     ("vsize")                * factor end)
    registerscript("LastPageNumber",       function() return getcount("lastpageno")                    end)

    registerscript("OverlayWidth",         function() return getdimen("d_overlay_width")      * factor end)
    registerscript("OverlayHeight",        function() return getdimen("d_overlay_height")     * factor end)
    registerscript("OverlayDepth",         function() return getdimen("d_overlay_depth")      * factor end)
    registerscript("OverlayLineWidth",     function() return getdimen("d_overlay_linewidth")  * factor end)
    registerscript("OverlayOffset",        function() return getdimen("d_overlay_offset")     * factor end)
    registerscript("OverlayRegion",        function() mpstring(getmacro("m_overlay_region"))           end)
    --            ("CurrentLayout",        function() mpstring(getmacro("currentlayout"))              end)

    registerscript("PageFraction",         page_fraction)
    registerscript("OnRightPage",          on_right_page)
    registerscript("OnOddPage",            is_odd_page  )
    registerscript("InPageBody",           in_body_page )

    registerscript("defaultcolormodel",    defaultcolormodel)

else

    function mp.PaperHeight         () mpnumeric(getdimen("paperheight")          * factor) end
    function mp.PaperWidth          () mpnumeric(getdimen("paperwidth")           * factor) end
    function mp.PrintPaperHeight    () mpnumeric(getdimen("printpaperheight")     * factor) end
    function mp.PrintPaperWidth     () mpnumeric(getdimen("printpaperwidth")      * factor) end
    function mp.TopSpace            () mpnumeric(getdimen("topspace")             * factor) end
    function mp.BottomSpace         () mpnumeric(getdimen("bottomspace")          * factor) end
    function mp.BackSpace           () mpnumeric(getdimen("backspace")            * factor) end
    function mp.CutSpace            () mpnumeric(getdimen("cutspace")             * factor) end
    function mp.MakeupHeight        () mpnumeric(getdimen("makeupheight")         * factor) end
    function mp.MakeupWidth         () mpnumeric(getdimen("makeupwidth")          * factor) end
    function mp.TopHeight           () mpnumeric(getdimen("topheight")            * factor) end
    function mp.TopDistance         () mpnumeric(getdimen("topdistance")          * factor) end
    function mp.HeaderHeight        () mpnumeric(getdimen("headerheight")         * factor) end
    function mp.HeaderDistance      () mpnumeric(getdimen("headerdistance")       * factor) end
    function mp.TextHeight          () mpnumeric(getdimen("textheight")           * factor) end
    function mp.FooterDistance      () mpnumeric(getdimen("footerdistance")       * factor) end
    function mp.FooterHeight        () mpnumeric(getdimen("footerheight")         * factor) end
    function mp.BottomDistance      () mpnumeric(getdimen("bottomdistance")       * factor) end
    function mp.BottomHeight        () mpnumeric(getdimen("bottomheight")         * factor) end
    function mp.LeftEdgeWidth       () mpnumeric(getdimen("leftedgewidth")        * factor) end
    function mp.LeftEdgeDistance    () mpnumeric(getdimen("leftedgedistance")     * factor) end
    function mp.LeftMarginWidth     () mpnumeric(getdimen("leftmarginwidth")      * factor) end
    function mp.LeftMarginDistance  () mpnumeric(getdimen("leftmargindistance")   * factor) end
    function mp.TextWidth           () mpnumeric(getdimen("textwidth")            * factor) end
    function mp.RightMarginDistance () mpnumeric(getdimen("rightmargindistance")  * factor) end
    function mp.RightMarginWidth    () mpnumeric(getdimen("rightmarginwidth")     * factor) end
    function mp.RightEdgeDistance   () mpnumeric(getdimen("rightedgedistance")    * factor) end
    function mp.RightEdgeWidth      () mpnumeric(getdimen("rightedgewidth")       * factor) end
    function mp.InnerMarginDistance () mpnumeric(getdimen("innermargindistance")  * factor) end
    function mp.InnerMarginWidth    () mpnumeric(getdimen("innermarginwidth")     * factor) end
    function mp.OuterMarginDistance () mpnumeric(getdimen("outermargindistance")  * factor) end
    function mp.OuterMarginWidth    () mpnumeric(getdimen("outermarginwidth")     * factor) end
    function mp.InnerEdgeDistance   () mpnumeric(getdimen("inneredgedistance")    * factor) end
    function mp.InnerEdgeWidth      () mpnumeric(getdimen("inneredgewidth")       * factor) end
    function mp.OuterEdgeDistance   () mpnumeric(getdimen("outeredgedistance")    * factor) end
    function mp.OuterEdgeWidth      () mpnumeric(getdimen("outeredgewidth")       * factor) end
    function mp.PageOffset          () mpnumeric(getdimen("pagebackgroundoffset") * factor) end
    function mp.PageDepth           () mpnumeric(getdimen("pagebackgrounddepth")  * factor) end
    function mp.LayoutColumns       () mpnumeric(getcount("layoutcolumns"))                 end
    function mp.LayoutColumnDistance() mpnumeric(getdimen("layoutcolumndistance") * factor) end
    function mp.LayoutColumnWidth   () mpnumeric(getdimen("layoutcolumnwidth")    * factor) end
    function mp.SpineWidth          () mpnumeric(getdimen("spinewidth")           * factor) end
    function mp.PaperBleed          () mpnumeric(getdimen("paperbleed")           * factor) end

    function mp.RealPageNumber      () mpnumeric(getcount("realpageno")                   ) end
    function mp.LastPageNumber      () mpnumeric(getcount("lastpageno")                   ) end

    function mp.PageNumber          () mpnumeric(getcount("pageno")                       ) end
    function mp.NOfPages            () mpnumeric(getcount("lastpageno")                   ) end

    function mp.SubPageNumber       () mpnumeric(getcount("subpageno")                    ) end
    function mp.NOfSubPages         () mpnumeric(getcount("lastsubpageno")                ) end

    function mp.CurrentColumn       () mpnumeric(getcount("mofcolumns")                   ) end
    function mp.NOfColumns          () mpnumeric(getcount("nofcolumns")                   ) end

    function mp.BaseLineSkip        () mpnumeric(get     ("baselineskip",true)    * factor) end
    function mp.LineHeight          () mpnumeric(getdimen("lineheight")           * factor) end
    function mp.BodyFontSize        () mpnumeric(getdimen("bodyfontsize")         * factor) end

    function mp.TopSkip             () mpnumeric(get     ("topskip",true)         * factor) end
    function mp.StrutHeight         () mpnumeric(getdimen("strutht")              * factor) end
    function mp.StrutDepth          () mpnumeric(getdimen("strutdp")              * factor) end

    function mp.PageNumber          () mpnumeric(getcount("pageno")                       ) end
    function mp.RealPageNumber      () mpnumeric(getcount("realpageno")                   ) end
    function mp.NOfPages            () mpnumeric(getcount("lastpageno")                   ) end

    function mp.CurrentWidth        () mpnumeric(get     ("hsize")                * factor) end
    function mp.CurrentHeight       () mpnumeric(get     ("vsize")                * factor) end

    function mp.EmWidth             () mpnumeric(emwidths [false]                 * factor) end
    function mp.ExHeight            () mpnumeric(exheights[false]                 * factor) end

    function mp.OverlayWidth        () mpnumeric(getdimen("d_overlay_width")      * factor) end
    function mp.OverlayHeight       () mpnumeric(getdimen("d_overlay_height")     * factor) end
    function mp.OverlayDepth        () mpnumeric(getdimen("d_overlay_depth")      * factor) end
    function mp.OverlayLineWidth    () mpnumeric(getdimen("d_overlay_linewidth")  * factor) end
    function mp.OverlayOffset       () mpnumeric(getdimen("d_overlay_offset")     * factor) end
    function mp.OverlayRegion       () mpstring (getmacro("m_overlay_region")             ) end

    function mp.PageFraction        () mpnumeric(page_fraction()                          ) end
    function mp.OnRightPage         () mpboolean(on_right_page()                          ) end
    function mp.OnOddPage           () mpboolean(is_odd_page  ()                          ) end
    function mp.InPageBody          () mpboolean(in_body_page ()                          ) end

    function mp.OverlayWidth        () mpnumeric(getdimen("d_overlay_width")      * factor) end
    function mp.OverlayHeight       () mpnumeric(getdimen("d_overlay_height")     * factor) end
    function mp.OverlayDepth        () mpnumeric(getdimen("d_overlay_depth")      * factor) end
    function mp.OverlayLineWidth    () mpnumeric(getdimen("d_overlay_linewidth")  * factor) end
    function mp.OverlayOffset       () mpnumeric(getdimen("d_overlay_offset")     * factor) end
    function mp.OverlayRegion       () mpstring (getmacro("m_overlay_region")             ) end
    --       mp.CurrentLayout       () mpstring (getmacro("currentlayout"))                 end

    function mp.defaultcolormodel   () mpnumeric(defaultcolormodel())                       end

    mp.HSize          = mp.CurrentWidth
    mp.VSize          = mp.CurrentHeight
    mp.LastPageNumber = mp.NOfPages

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

end


