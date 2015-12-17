if not modules then modules = { } end modules ['page-otr'] = {
    version   = 1.001,
    comment   = "companion to page-otr.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

interfaces.implement {
    name    = "triggerpagebuilder",
    actions = tex.triggerbuildpage,
}
