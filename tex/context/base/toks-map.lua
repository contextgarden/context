if not modules then modules = { } end modules ['toks-map'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Even more experimental ... this used to be part of toks-ini but as
-- this kind of remapping has not much use it is not loaded in the
-- core. We just keep it here for old times sake.

-- local remapper      = { }  -- namespace
-- collectors.remapper = remapper
--
-- local remapperdata  = { }  -- user mappings
-- remapper.data       = remapperdata
--
-- function remapper.store(tag,class,key)
--     local s = remapperdata[class]
--     if not s then
--         s = { }
--         remapperdata[class] = s
--     end
--     s[key] = collectordata[tag]
--     collectordata[tag] = nil
-- end
--
-- function remapper.convert(tag,toks)
--     local data         = remapperdata[tag]
--     local leftbracket  = utfbyte('[')
--     local rightbracket = utfbyte(']')
--     local skipping     = 0
--     -- todo: math
--     if data then
--         local t, n = { }, 0
--         for s=1,#toks do
--             local tok = toks[s]
--             local one, two = tok[1], tok[2]
--             if one == 11 or one == 12 then
--                 if two == leftbracket then
--                     skipping = skipping + 1
--                     n = n + 1 ; t[n] = tok
--                 elseif two == rightbracket then
--                     skipping = skipping - 1
--                     n = n + 1 ; t[n] = tok
--                 elseif skipping == 0 then
--                     local new = data[two]
--                     if new then
--                         if #new > 1 then
--                             for n=1,#new do
--                                 n = n + 1 ; t[n] = new[n]
--                             end
--                         else
--                             n = n + 1 ; t[n] = new[1]
--                         end
--                     else
--                         n = n + 1 ; t[n] = tok
--                     end
--                 else
--                     n = n + 1 ; t[n] = tok
--                 end
--             else
--                 n = n + 1 ; t[n] = tok
--             end
--         end
--         return t
--     else
--         return toks
--     end
-- end
