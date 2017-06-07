if not modules then modules = { } end modules ['node-syn'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Because we have these fields in some node that are used by synctex, I decided (because
-- some users seem to like that feature) to implement a variant that might work out better
-- for ConTeXt. This is experimental code. I don't use it myself so it will take a while
-- to mature. There will be some helpers that one can use in more complex situations like
-- included xml files.
--
-- It is unclear how the output gets interpreted. For instance, we only need to be able to
-- go back to a place where text is entered, but still we need all that redundant box
-- wrapping.
--
-- Possible optimizations: pack whole lines.

-- InverseSearchCmdLine = mtxrun.exe --script synctex --edit --name="%f" --line="%l" $

-- Unfortunately syntex always removes the files at the end and not at the start (it
-- happens in synctexterminate). This forces us to use an intermediate file, no big deal
-- in context (which has a runner) but definitely not nice.

local type, rawset = type, rawset
local concat = table.concat
local formatters = string.formatters
local replacesuffix = file.replacesuffix

local trace = false  trackers.register("system.synctex.visualize", function(v) trace = v end)

local report_system = logs.reporter("system")

local nuts               = nodes.nuts
local tonut              = nuts.tonut
local tonode             = nuts.tonode

local getid              = nuts.getid
local getlist            = nuts.getlist
local setlist            = nuts.setlist
local getnext            = nuts.getnext
local getwhd             = nuts.getwhd
local getwidth           = nuts.getwidth
local getsubtype         = nuts.getsubtype
local getattr            = nuts.getattr

local nodecodes          = nodes.nodecodes
local kerncodes          = nodes.kerncodes

local glue_code          = nodecodes.glue
local kern_code          = nodecodes.kern
local kern_disc          = nodecodes.disc
local rule_code          = nodecodes.rule
----- math_code          = nodecodes.math
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local glyph_code         = nodecodes.glyph
local fontkern_code      = kerncodes.fontkern

local insert_before      = nuts.insert_before
local insert_after       = nuts.insert_after

local nodepool           = nuts.pool
local new_latelua        = nodepool.latelua
local new_rule           = nodepool.rule
local new_hlist          = nodepool.hlist

local getdimensions      = nuts.dimensions
local getrangedimensions = nuts.rangedimensions

local a_fontkern         = attributes.private("fontkern")

local get_synctex_fields = nuts.get_synctex_fields
local set_synctex_fields = nuts.set_synctex_fields
local set_synctex_line   = tex.set_synctex_line
local set_synctex_tag    = tex.set_synctex_tag
local force_synctex_tag  = tex.force_synctex_tag
local force_synctex_line = tex.force_synctex_line
----- get_synctex_tag    = tex.get_synctex_tag
----- get_synctex_line   = tex.get_synctex_line

local getcount           = tex.getcount
local setcount           = tex.setcount

local getpos             = function()
                               getpos = backends.codeinjections.getpos
                               return getpos()
                           end


local eol                = "\010"

local f_glue             = formatters["g%i,%i:%i,%i"]
local f_glyph            = formatters["x%i,%i:%i,%i"]
local f_kern             = formatters["k%i,%i:%i,%i:%i"]
local f_rule             = formatters["r%i,%i:%i,%i:%i,%i,%i"]
local f_hlist            = formatters["[%i,%i:%i,%i:%i,%i,%i"]
local f_vlist            = formatters["(%i,%i:%i,%i:%i,%i,%i"]
local s_hlist            = "]"
local s_vlist            = ")"
local f_hvoid            = formatters["h%i,%i:%i,%i:%i,%i,%i"]
local f_vvoid            = formatters["v%i,%i:%i,%i:%i,%i,%i"]

local characters         = fonts.hashes.characters

local foundintree        = resolvers.foundintree
local suffixonly         = file.suffix
local nameonly           = file.nameonly

local synctex            = { }
luatex.synctex           = synctex

-- the file name stuff

local noftags            = 0
local stnums             = { }
local nofblocked         = 0
local blockedfilenames   = { }
local blockedsuffixes    = {
    mkii = true,
    mkiv = true,
    mkvi = true,
    mkix = true,
    mkxi = true,
 -- lfg  = true,
}


local sttags = table.setmetatableindex(function(t,name)
    if blockedsuffixes[suffixonly(name)] then
        -- Just so that I don't get the ones on my development tree.
        nofblocked = nofblocked + 1
        return 0
    elseif blockedfilenames[nameonly(name)] then
        -- So we can block specific files.
        nofblocked = nofblocked + 1
        return 0
    elseif foundintree(name) then
        -- One shouldn't edit styles etc this way.
        nofblocked = nofblocked + 1
        return 0
    else
        noftags = noftags + 1
        t[name] = noftags
        stnums[noftags] = name
        return noftags
    end
end)

function synctex.blockfilename(name)
    blockedfilenames[nameonly(name)] = name
end

function synctex.setfilename(name,line)
    if force_synctex_tag and name then
        force_synctex_tag(sttags[name])
        if line then
            force_synctex_line(line)
        end
    end
end

function synctex.resetfilename()
    if force_synctex_tag then
        force_synctex_tag(0)
        force_synctex_line(0)
    end
end

-- the node stuff

local result     = { }
local r          = 0
local f          = nil
local nofsheets  = 0
local nofobjects = 0
local last       = 0
local filesdone  = 0
local enabled    = false
local compact    = true
local fulltrace  = false
local logfile    = false
local used       = false

local function writeanchor()
    local size = f:seek("end")
    f:write("!" .. (size-last) ..eol)
    last = size
end

local function writefiles()
    local total = #stnums
    if filesdone < total then
        for i=filesdone+1,total do
            f:write("Input:"..i..":"..stnums[i]..eol)
        end
        filesdone = total
    end
end

local function flushpreamble()
    logfile = replacesuffix(tex.jobname,"syncctx")
    f = io.open(logfile,"wb")
    f:write("SyncTeX Version:1"..eol)
    writefiles()
    f:write("Output:pdf"..eol)
    f:write("Magnification:1000"..eol)
    f:write("Unit:1"..eol)
    f:write("X Offset:0"..eol)
    f:write("Y Offset:0"..eol)
    f:write("Content:"..eol)
    flushpreamble = writefiles
end

function synctex.wrapup()
    if logfile then
        os.rename(logfile,replacesuffix(logfile,"synctex"))
    end
end

local function flushpostamble()
    if not f then
        return
    end
    writeanchor()
    f:write("Postamble:"..eol)
    f:write("Count:"..nofobjects..eol)
    writeanchor()
    f:write("Post scriptum:"..eol)
    f:close()
    enabled = false
end

local pageheight = 0 -- todo: set before we do this!

local function b_hlist(head,current,t,l,w,h,d)
    return insert_before(head,current,new_latelua(function()
        local x, y = getpos()
        r = r + 1
        result[r] = f_hlist(t,l,x,tex.pageheight-y,w,h,d)
        nofobjects = nofobjects + 1
    end))
end

local function b_vlist(head,current,t,l,w,h,d)
    return insert_before(head,current,new_latelua(function()
        local x, y = getpos()
        r = r + 1
        result[r] = f_vlist(t,l,x,tex.pageheight-y,w,h,d)
        nofobjects = nofobjects + 1
    end))
end

local function e_hlist(head,current)
    return insert_after(head,current,new_latelua(function()
        r = r + 1
        result[r] = s_hlist
        nofobjects = nofobjects + 1
    end))
end

local function e_vlist(head,current)
    return insert_after(head,current,new_latelua(function()
        r = r + 1
        result[r] = s_vlist
        nofobjects = nofobjects + 1
    end))
end

local function x_hlist(head,current,t,l,w,h,d)
    return insert_before(head,current,new_latelua(function()
        local x, y = getpos()
        r = r + 1
        result[r] = f_hvoid(t,l,x,tex.pageheight-y,w,h,d)
        nofobjects = nofobjects + 1
    end))
end

local function x_vlist(head,current,t,l,w,h,d)
    return insert_before(head,current,new_latelua(function()
        local x, y = getpos()
        r = r + 1
        result[r] = f_vvoid(t,l,x,tex.pageheight-y,w,h,d)
        nofobjects = nofobjects + 1
    end))
end

-- local function x_glyph(head,current,t,l)
--     return insert_before(head,current,new_latelua(function()
--         local x, y = getpos()
--         r = r + 1
--         result[r] = f_glyph(t,l,x,tex.pageheight-y)
--         nofobjects = nofobjects + 1
--     end))
-- end

-- local function x_glue(head,current,t,l)
--     return insert_before(head,current,new_latelua(function()
--         local x, y = getpos()
--         r = r + 1
--         result[r] = f_glue(t,l,x,tex.pageheight-y)
--         nofobjects = nofobjects + 1
--     end))
-- end

-- local function x_kern(head,current,t,l,k)
--     return insert_before(head,current,new_latelua(function()
--         local x, y = getpos()
--         r = r + 1
--         result[r] = f_kern(t,l,x,tex.pageheight-y,k)
--         nofobjects = nofobjects + 1
--     end))
-- end

-- local function x_rule(head,current,t,l,w,h,d)
--     return insert_before(head,current,new_latelua(function()
--         local x, y = getpos()
--         r = r + 1
--         result[r] = f_rule(t,l,x,tex.pageheight-y,w,h,d)
--         nofobjects = nofobjects + 1
--     end))
-- end

-- todo: why not only lines
-- todo: larger ranges

-- color is already handled so no colors

-- we can have ranges .. more efficient but a bit more complex to analyze ... some day

local function collect(head,t,l,dp,ht)
    local current = head
    while current do
        local id = getid(current)
        if id == glyph_code then
            local first = current
            local last  = current
            while true do
                id = getid(current)
                -- traditionally glyphs have no synctex code which works sort of ok
                -- but not when we don't leave hmode cq. have no par
                --
                if id == glyph_code or id == disc_code then
                    local tc, lc = get_synctex_fields(current)
                    if tc and tc > 0 then
                        t, l = tc, lc
                    end
                    last = current
                elseif id == kern_code and (getsubtype(current) == fontkern_code or getattr(current,a_fontkern)) then
                    local tc, lc = get_synctex_fields(current)
                    if tc and tc > 0 then
                        t, l = tc, lc
                    end
                    last = current
                else
                    if id == glue_code then
                        -- we could go on when we're in the same t/l run
                        local tc, lc = get_synctex_fields(current)
                        if tc > 0 then
                            t, l = tc, lc
                        end
                        id = nil -- so no test later on
                    end
                    local w, h, d = getdimensions(first,getnext(last))
                 -- local w, h, d = getrangedimensions(head,first,getnext(last))
                    if dp and d < dp then d = dp end
                    if ht and h < ht then h = ht end
                    if h < 655360 then h = 655360 end
                    if d < 327680 then d = 327680 end
                    if trace then
                        head = insert_before(head,first,new_hlist(new_rule(w,fulltrace and h or 32768,fulltrace and d or 32768)))
                    end
                    head = x_hlist(head,first,t,l,w,h,d)
                    break
                end
                current = getnext(current)
                if not current then
                    local w, h, d = getdimensions(first,getnext(last))
                 -- local w, h, d = getrangedimensions(head,first,getnext(last))
                    if dp and d < dp then d = dp end
                    if ht and h < ht then h = ht end
                    if h < 655360 then h = 655360 end
                    if d < 327680 then d = 327680 end
                    if trace then
                        head = insert_before(head,first,new_hlist(new_rule(w,fulltrace and h or 32768,fulltrace and d or 32768)))
                    end
                    head = x_hlist(head,first,t,l,w,h,d)
                    return head
                end
            end
        end
        if id == hlist_code then
            local list = getlist(current)
            local tc, lc = get_synctex_fields(current)
            if tc > 0 then
                t, l = tc, lc
            end
            if compact then
                if list then
                    local l = collect(list,t,l)
                    if l ~= list then
                        setlist(current,l)
                    end
                end
            else
                local w, h, d = getwhd(current)
                if w == 0 or (h == 0 and d == 0) then
                    if list then
                        local l = collect(list,t,l)
                        if l ~= list then
                            setlist(current,l)
                        end
                    end
                elseif list then
                 -- head = b_hlist(head,current,t,l,w,h,d)
                    head = b_hlist(head,current,0,0,w,h,d) -- todo: only d h when line
                    local l = collect(list,t,l,d,h)
                    if l ~= list then
                        setlist(current,l)
                    end
                    head, current = e_hlist(head,current)
                else
                 -- head = x_hlist(head,current,t,l,w,h,d)
                    head = x_hlist(head,current,0,0,w,h,d) -- todo: only d h when line
                end
            end
        elseif id == vlist_code then
            local list = getlist(current)
            local tc, lc = get_synctex_fields(current)
            if tc > 0 then
                t, l = tc, lc
            end
            if compact then
                if list then
                    local l = collect(list,t,l)
                    if l ~= list then
                        setlist(current,l)
                    end
                end
            else
                local w, h, d = getwhd(current)
                if w == 0 or (h == 0 and d == 0) then
                    if list then
                        local l = collect(list,t,l)
                        if l ~= list then
                            setlist(current,l)
                        end
                    end
                elseif list then
                 -- head = b_vlist(head,current,t,l,w,h,d)
                    head = b_vlist(head,current,0,0,w,h,d)
                    local l = collect(list,t,l)
                    if l ~= list then
                        setlist(current,l)
                    end
                    head, current = e_vlist(head,current)
                else
                 -- head = x_vlist(head,current,t,l,w,h,d)
                    head = x_vlist(head,current,0,0,w,h,d)
                end
            end
        elseif id == glue_code then
            local tc, lc = get_synctex_fields(current)
            if tc > 0 then
                t, l = tc, lc
            end
         -- head = x_glue(head,current,t,l)
     -- elseif id == kern_code then
     --     local tc, lc = get_synctex_fields(current)
     --     if tc > 0 then
     --         t, l = tc, lc
     --     end
     --  -- local k = getwidth(current)
     --  -- if k ~= 0 then
     --  --     head = x_kern(head,current,t,l,k)
     --  -- end
     -- elseif id == rule_code then
     --     local tc, lc = get_synctex_fields(current)
     --     if tc > 0 then
     --         t, l = tc, lc
     --     end
     --  -- if t > 0 and l > 0 then
     --  -- local w, h, d = getwhd(current)
     --  --     head = x_rule(head,current,t,l,w,h,d)
     --  -- end
        end
        current = getnext(current)
    end
    return head
end

-- range of same numbers

function synctex.collect(head)
    if enabled then
        result, r = { }, 0
        head = collect(tonut(head),0,0)
        return tonode(head), true
    else
        return head, false
    end
end

-- also no solution for bad first file resolving in sumatra

function synctex.flush()
    if enabled then
        nofsheets = nofsheets + 1 -- could be realpageno
        flushpreamble()
        writeanchor()
        f:write("{"..nofsheets..eol)
        if compact then
         -- f:write(f_vlist(0,0,0,0,tex.pagewidth,tex.pageheight,0))
            f:write(f_hlist(0,0,0,0,0,0,0))
            f:write(eol)
            f:write(f_vlist(0,0,0,0,0,0,0))
            f:write(eol)
        end
        f:write(concat(result,eol))
        if compact then
            f:write(eol)
            f:write(s_vlist)
            f:write(eol)
            f:write(s_hlist)
        end
        f:write(eol)
        writeanchor()
        f:write("}"..nofsheets..eol)
        nofobjects = nofobjects + 2
        result, r = { }, 0
    end
end

local details = 1
local state   = 0

directives.register("system.synctex.details",function(v)
    details = tonumber(v) or 1
end)

local set_synctex_mode = tex.set_synctex_mode

if set_synctex_mode then

    function synctex.enable()
        if not enabled then
            enabled = true
            state   = details or 1
            set_synctex_mode(state)
            if not used then
                directives.enable("system.synctex.xml")
                nodes.tasks.appendaction("shipouts", "after", "nodes.synctex.collect")
                report_system("synctex functionality is enabled, expect runtime overhead!")
                used = true
            end
        elseif state > 0 then
            set_synctex_mode(state)
        end
    end

    function synctex.disable()
        if enabled then
            set_synctex_mode(0)
            report_system("synctex functionality is disabled!")
            enabled = false
        end
    end

    function synctex.finish()
        if enabled then
            flushpostamble()
        else
            os.remove(replacesuffix(tex.jobname,"syncctx"))
            os.remove(replacesuffix(tex.jobname,"synctex"))
        end
    end

    function synctex.pause()
        if enabled then
            set_synctex_mode(0)
        end
    end

    function synctex.resume()
        if enabled then
            set_synctex_mode(state)
        end
    end

else

    function synctex.enable () end
    function synctex.disable() end
    function synctex.finish () end
    function synctex.pause  () end
    function synctex.resume () end

end

-- not the best place

luatex.registerstopactions(synctex.finish)

nodes.tasks.appendaction("shipouts", "after", "luatex.synctex.collect")

directives.register("system.synctex", function(v)
    if v then
        synctex.enable()
    else
        synctex.disable()
    end
end)

statistics.register("synctex tracing",function()
    if used then
        return string.format("%i referenced files, %i files ignored, logfile: %s",noftags,nofblocked,logfile)
    end
end)

interfaces.implement {
    name      = "synctexblockfilename",
    arguments = "string",
    actions   = synctex.blockfilename,
}

interfaces.implement {
    name      = "synctexsetfilename",
    arguments = "string",
    actions   = synctex.setfilename,
}

interfaces.implement {
    name      = "synctexresetfilename",
    actions   = synctex.resetfilename,
}

interfaces.implement {
    name      = "synctexenable",
    actions   = synctex.enable,
}

interfaces.implement {
    name      = "synctexdisable",
    actions   = synctex.disable,
}

interfaces.implement {
    name      = "synctexpause",
    actions   = synctex.pause,
}

interfaces.implement {
    name      = "synctexresume",
    actions   = synctex.resume,
}
