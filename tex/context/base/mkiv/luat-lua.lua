if not modules then modules = { } end modules ['luat-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if lua then do

    local delayed = { }

    function lua.flushdelayed(...)
        local t = delayed
        delayed = { }
        for i=1, #t do
            t[i](...)
        end
    end

    function lua.delay(f)
        delayed[#delayed+1] = f
    end

    function lua.flush(...)
        context.directlua("lua.flushdelayed(%,t)",{...})
    end

end end

-- See mk.pdf for an explanation of the following code:
--
-- function test(n)
--     lua.delay(function(...)
--         context("pi: %s %s %s",...)
--         context.par()
--     end)
--     lua.delay(function(...)
--         context("more pi: %s %s %s",...)
--         context.par()
--     end)
--     context("\\setbox0=\\hbox{%s}",math.pi*n)
--     local box = tex.box[0]
--     lua.flush(box.width,box.height,box.depth)
-- end
