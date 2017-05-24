if not modules then modules = { } end modules ['lang-exc'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen",
    copyright = "ConTeXt Development Team",
    license   = "see context related readme files",
    dataonly  = true,
}

-- Here we add common exceptions. This file can grow. For now we keep it
-- in the main base tree. We actually need a generic (shared) pattern or
-- exception file I guess.

return {
    "lua-jit",
}
