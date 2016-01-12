if not modules then modules = { } end modules ['buff-imp-escaped'] = {
    version   = 1.001,
    comment   = "companion to buff-imp-escaped.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

visualizers.registerescapepattern("/BTEX/ETEX","/BTEX","/ETEX")

visualizers.register("escaped", {
    parser  = visualizers.escapepatterns["/BTEX/ETEX"],
    handler = visualizers.newhandler(),
})
