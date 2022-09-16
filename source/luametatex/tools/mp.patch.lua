local gsub = string.gsub

return {

    action = function(data,report)

        if true then
            -- we have no patches
            return data
        end

        if not report then
            report = print -- let it look bad
        end

        local n, m = 0, 0

        statistics.starttiming()

        local function okay(i,str)
            n = n + 1
            report("patch %02i ok  : %s",i,str)
        end

        -- not used

     -- data = gsub(data,"(#include <zlib%.h>)",function(s)
     --     okay(1,"zlib header file commented")
     --     return "/* " .. s .. "*/"
     -- end,1)
     --
     -- data = gsub(data,"(#include <png%.h>)",function(s)
     --     okay(2,"png header file commented")
     --     return "/* " .. s .. "*/"
     -- end,1)

        -- patched

     -- data = gsub(data,"calloc%((%w+),%s*(%w+)%)",function(n,m)
     --     okay(3,"calloc replaced by malloc")
     --     return "malloc(" .. n .. "*" .. m .. ")"
     -- end,1)

        -- not used

     -- data = gsub(data,"(mp_show_library_versions%s*%(%s*%w+%s*%)%s*)%b{}",function(s)
     --     okay(4,"reporting library versions removed")
     --     return s .. "\n{\n}"
     -- end,1)

     -- data = gsub(data,"#if INTEGER_MAX == LONG_MAX",function(s)
     --     okay(5,"fix INTEGER_TYPE")
     --     return "#if INTEGER_TYPE == long"
     -- end,1)

        -- done

        statistics.stoptiming()

        report("patching time: %s", statistics.elapsedtime())
        report("patches left : %i", m - n)

        return data
    end

}
