if not modules then modules = { } end modules ['node-syn'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Because we have these fields in some node that are used by sunctex, I decided (because
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

local type, rawset = type, rawset
local concat = table.concat
local formatters = string.formatters

local trace = false  trackers.register("system.syntex.visualize", function(v) trace = v end)

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
local set_syntex_tag     = nodes.set_synctex_tag

local getpos             = function()
                               getpos = backends.codeinjections.getpos
                               return getpos()
                           end

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

local synctex            = { }
luatex.synctex           = synctex

-- the file name stuff

local noftags            = 0
local stnums             = { }
local sttags             = table.setmetatableindex(function(t,name)
    noftags = noftags + 1
    t[name] = noftags
    stnums[noftags] = name
    return noftags
end)

function synctex.setfilename(name)
    if set_syntex_tag and name then
        set_syntex_tag(sttags[name])
    end
end

function synctex.resetfilename()
    if set_syntex_tag then
        local name = luatex.currentfile()
        if name then
            set_syntex_tag(name)
        end
    end
end

-- the node stuff

local result             = { }
local r                  = 0
local f                  = nil
local nofsheets          = 0
local nofobjects         = 0
local last               = 0
local filesdone          = 0
local enabled            = false
local compact            = true

local function writeanchor()
    local size = f:seek("end")
    f:write("!" .. (size-last) .. "\n")
    last = size
end

local function writefiles()
    local total = #stnums
    if filesdone < total then
        for i=filesdone+1,total do
            f:write("Input:"..i..":"..stnums[i].."\n")
        end
        filesdone = total
    end
end

local function flushpreamble()
    local jobname = tex.jobname
    stnums[0] = jobname
    f = io.open(file.replacesuffix(jobname,"syncctx"),"w")
    f:write("SyncTeX Version:1\n")
    f:write("Input:0:"..jobname.."\n")
    writefiles()
    f:write("Output:pdf\n")
    f:write("Magnification:1000\n")
    f:write("Unit:1\n")
    f:write("X Offset:0\n")
    f:write("Y Offset:0\n")
    f:write("Content:\n")
    flushpreamble = writefiles
end

local function flushpostamble()
    writeanchor()
    f:write("Postamble:\n")
    f:write("Count:"..nofobjects.."\n")
    writeanchor()
    f:write("Post scriptum:\n")
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

local function collect(head,t,l)
    local current = head
    while current do
        local id = getid(current)
        if id == glyph_code then
            local first = current
            local last  = current
            while true do
                id = getid(current)
                if id == glyph_code or id == disc_code then
                    last = current
                elseif id == kern_code and (getsubtype(current) == fontkern_code or getattr(current,a_fontkern)) then
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
                    if trace then
                        -- color is already handled so no colors
                        head = insert_before(head,first,new_hlist(new_rule(w,32768,32768)))
                    end
if h < 655360 then
    h = 655360
end
if d < 327680 then
    d = 327680
end
                    head = x_hlist(head,first,t,l,w,h,d)
                    break
                end
                current = getnext(current)
                if not current then
                    local w, h, d = getdimensions(first,getnext(last))
                 -- local w, h, d = getrangedimensions(head,first,getnext(last))
                    if trace then
                        -- color is already handled so no colors
                        head = insert_before(head,first,new_hlist(new_rule(w,32768,32768)))
                    end
if h < 655360 then
    h = 655360
end
if d < 327680 then
    d = 327680
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
                    head = b_hlist(head,current,0,0,w,h,d)
                    local l = collect(list,t,l)
                    if l ~= list then
                        setlist(current,l)
                    end
                    head, current = e_hlist(head,current)
                else
                 -- head = x_hlist(head,current,t,l,w,h,d)
                    head = x_hlist(head,current,0,0,w,h,d)
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
        f:write("{"..nofsheets.."\n")
        if compact then
            f:write(f_vlist(0,0,0,0,tex.pagewidth,tex.pageheight,0))
            f:write("\n")
        end
        f:write(concat(result,"\n"))
        if compact then
            f:write("\n")
            f:write(s_vlist)
        end
        f:write("\n")
        writeanchor()
        f:write("}"..nofsheets.."\n")
        nofobjects = nofobjects + 2
        result, r = { }, 0
    end
end

function synctex.enable()
    if not enabled and node.set_synctex_mode then
        enabled = true
        node.set_synctex_mode(1)
        tex.normalsynctex = 0
        nodes.tasks.appendaction("shipouts", "after", "nodes.synctex.collect")
    end
end

function synctex.finish()
    if enabled then
        flushpostamble()
    end
end

-- not the best place

luatex.registerstopactions(synctex.finish)

nodes.tasks.appendaction("shipouts", "after", "luatex.synctex.collect")

-- moved here

local report_system = logs.reporter("system")
local synctex       = false

directives.register("system.synctex", function(v)
    if v == "context" then
        luatex.synctex.enable()
        tex.normalsynctex = 0
        synctex = true
    else
        v = tonumber(v) or (toboolean(v,true) and 1) or (v == "zipped" and 1) or (v == "unzipped" and -1) or 0
        tex.normalsynctex = v
        synctex = v ~= 0
    end
    if synctex then
        report_system("synctex functionality is enabled (%s), expect runtime overhead!",tostring(v))
    else
        report_system("synctex functionality is disabled!")
    end
end)

statistics.register("synctex tracing",function()
    if synctex or tex.normalsynctex ~= 0 then
        return "synctex has been enabled (extra log file generated)"
    end
end)
