if not modules then modules = { } end modules ['font-otl'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- After some experimenting with an alternative loader (one that is needed for
-- getting outlines in mp) I decided not to be compatible with the old (built-in)
-- one. The approach used in font-otn is as follows: we load the font in a compact
-- format but still very compatible with the ff data structures. From there we
-- create hashes to access the data efficiently. The implementation of feature
-- processing is mostly based on looking at the data as organized in the glyphs and
-- lookups as well as the specification. Keeping the lookup data in the glyphs is
-- very instructive and handy for tracing. On the other hand hashing is what brings
-- speed. So, the in the new approach (the old one will stay around too) we no
-- longer keep data in the glyphs which saves us (what in retrospect looks a bit
-- like) a reconstruction step. It also means that the data format of the cached
-- files changes. What method is used depends on that format. There is no fundamental
-- change in processing, and not even in data organation. Most has to do with
-- loading and storage.

-- This file is mostly used for experiments (on my machine) before they make it into
-- the core.
