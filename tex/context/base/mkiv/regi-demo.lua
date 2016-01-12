if not modules then modules = { } end modules ['regi-demo'] = {
    version   = 1.001,
    comment   = "companion to regi-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- digits -> *

return {
    [0x0030] = 0x002A,
    [0x0031] = 0x002A,
    [0x0032] = 0x002A,
    [0x0033] = 0x002A,
    [0x0034] = 0x002A,
    [0x0035] = 0x002A,
    [0x0036] = 0x002A,
    [0x0037] = 0x002A,
    [0x0038] = 0x002A,
    [0x0039] = 0x002A,
}
