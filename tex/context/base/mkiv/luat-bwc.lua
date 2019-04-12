if not modules then modules = { } end modules ['luat-bwc'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- backward compatibility

-- if not tex.wd then
--
--     local box = tex.box
--
--     local wd = { } setmetatable(wd, {
--         __index    = function(t,k)   local bk = box[k] return bk and bk.width or 0 end,
--         __newindex = function(t,k,v) local bk = box[k] if bk then bk.width = v end end,
--     } )
--
--     local ht = { } setmetatable(ht, {
--         __index    = function(t,k)   local bk = box[k] return bk and bk.height or 0 end,
--         __newindex = function(t,k,v) local bk = box[k] if bk then bk.height = v end end,
--     } )
--
--     local dp = { } setmetatable(dp, {
--         __index    = function(t,k)   local bk = box[k] return bk and bk.depth or 0 end,
--         __newindex = function(t,k,v) local bk = box[k] if bk then bk.depth = v end end,
--     } )
--
--     tex.wd, tex.ht, tex.dp = wd, ht, dp
--
-- end
