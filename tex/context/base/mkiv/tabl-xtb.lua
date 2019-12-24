if not modules then modules = { } end modules ['tabl-xtb'] = {
    version   = 1.001,
    comment   = "companion to tabl-xtb.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[

This table mechanism is a combination between TeX and Lua. We do process
cells at the TeX end and inspect them at the Lua end. After some analysis
we have a second pass using the calculated widths, and if needed cells
will go through a third pass to get the heights right. This last pass is
avoided when possible which is why some code below looks a bit more
complex than needed. The reason for such optimizations is that each cells
is actually a framed instance and because tables like this can be hundreds
of pages we want to keep processing time reasonable.

To a large extend the behaviour is comparable with the way bTABLE/eTABLE
works and there is a module that maps that one onto this one. Eventually
this mechamism will be improved so that it can replace its older cousin.

]]--

-- todo: use linked list instead of r/c array
-- todo: we can use the sum of previously forced widths for column spans

local tonumber, next = tonumber, next

local commands            = commands
local context             = context
local ctxnode             = context.nodes.flush

local implement           = interfaces.implement

local tex                 = tex
local texgetcount         = tex.getcount
local texsetcount         = tex.setcount
local texgetdimen         = tex.getdimen
local texsetdimen         = tex.setdimen
local texget              = tex.get

local format              = string.format
local concat              = table.concat
local points              = number.points

local todimen             = string.todimen

local ctx_beginvbox       = context.beginvbox
local ctx_endvbox         = context.endvbox
local ctx_blank           = context.blank
local ctx_nointerlineskip = context.nointerlineskip
local ctx_dummyxcell      = context.dummyxcell

local variables           = interfaces.variables

local setmetatableindex   = table.setmetatableindex
local settings_to_hash    = utilities.parsers.settings_to_hash

local nuts                = nodes.nuts -- here nuts gain hardly nothing
local tonut               = nuts.tonut
local tonode              = nuts.tonode

local getnext             = nuts.getnext
local getprev             = nuts.getprev
local getlist             = nuts.getlist
local getwidth            = nuts.getwidth
local getbox              = nuts.getbox
local getwhd              = nuts.getwhd

local setlink             = nuts.setlink
local setdirection        = nuts.setdirection
local setshift            = nuts.setshift

local copy_node_list      = nuts.copy_list
local hpack_node_list     = nuts.hpack
local flush_node_list     = nuts.flush_list
local takebox             = nuts.takebox

local nodepool            = nuts.pool

local new_glue            = nodepool.glue
local new_kern            = nodepool.kern
local new_hlist           = nodepool.hlist

local lefttoright_code    = nodes.dirvalues.lefttoright

local v_stretch           = variables.stretch
local v_normal            = variables.normal
local v_width             = variables.width
local v_height            = variables.height
local v_repeat            = variables["repeat"]
local v_max               = variables.max
local v_fixed             = variables.fixed
----- v_auto              = variables.auto
local v_before            = variables.before
local v_after             = variables.after
local v_both              = variables.both
local v_samepage          = variables.samepage
local v_tight             = variables.tight

local xtables             = { }
typesetters.xtables       = xtables

local trace_xtable        = false
local report_xtable       = logs.reporter("xtable")

trackers.register("xtable.construct", function(v) trace_xtable = v end)

local null_mode = 0
local head_mode = 1
local foot_mode = 2
local more_mode = 3
local body_mode = 4

local namedmodes = { [0] =
    "null",
    "head",
    "foot",
    "next",
    "body",
}

local stack, data = { }, nil

function xtables.create(settings)
    table.insert(stack,data)
    local rows           = { }
    local widths         = { }
    local heights        = { }
    local depths         = { }
 -- local spans          = { }
    local distances      = { }
    local autowidths     = { }
    local modes          = { }
    local fixedrows      = { }
    local fixedcolumns   = { }
 -- local fixedcspans    = { }
    local frozencolumns  = { }
    local options        = { }
    local rowproperties  = { }
    data = {
        rows           = rows,
        widths         = widths,
        heights        = heights,
        depths         = depths,
     -- spans          = spans,
        distances      = distances,
        modes          = modes,
        autowidths     = autowidths,
        fixedrows      = fixedrows,
        fixedcolumns   = fixedcolumns,
     -- fixedcspans    = fixedcspans,
        frozencolumns  = frozencolumns,
        options        = options,
        nofrows        = 0,
        nofcolumns     = 0,
        currentrow     = 0,
        currentcolumn  = 0,
        settings       = settings or { },
        rowproperties  = rowproperties,
    }
    local function add_zero(t,k)
        t[k] = 0
        return 0
    end
    local function add_table(t,k)
        local v = { }
        t[k] = v
        return v
    end
    local function add_cell(row,c)
        local cell = {
            nx     = 0,
            ny     = 0,
            list   = false,
            wd     = 0,
            ht     = 0,
            dp     = 0,
        }
        row[c] = cell
        if c > data.nofcolumns then
            data.nofcolumns = c
        end
        return cell
    end
    local function add_row(rows,r)
        local row = { }
        setmetatableindex(row,add_cell)
        rows[r] = row
        if r > data.nofrows then
            data.nofrows = r
        end
        return row
    end
    setmetatableindex(rows,add_row)
    setmetatableindex(widths,add_zero)
    setmetatableindex(heights,add_zero)
    setmetatableindex(depths,add_zero)
    setmetatableindex(distances,add_zero)
    setmetatableindex(modes,add_zero)
    setmetatableindex(fixedrows,add_zero)
    setmetatableindex(fixedcolumns,add_zero)
    setmetatableindex(options,add_table)
 -- setmetatableindex(fixedcspans,add_table)
    --
    local globaloptions = settings_to_hash(settings.option)
    --
    settings.columndistance      = tonumber(settings.columndistance) or 0
    settings.rowdistance         = tonumber(settings.rowdistance) or 0
    settings.leftmargindistance  = tonumber(settings.leftmargindistance) or 0
    settings.rightmargindistance = tonumber(settings.rightmargindistance) or 0
    settings.options             = globaloptions
    settings.textwidth           = tonumber(settings.textwidth) or texget("hsize")
    settings.lineheight          = tonumber(settings.lineheight) or texgetdimen("lineheight")
    settings.maxwidth            = tonumber(settings.maxwidth) or settings.textwidth/8
 -- if #stack > 0 then
 --     settings.textwidth = texget("hsize")
 -- end
    data.criterium_v =   2 * data.settings.lineheight
    data.criterium_h = .75 * data.settings.textwidth
    --
    data.tight = globaloptions[v_tight] and true or false
end

function xtables.initialize_reflow_width(option,width)
    local r = data.currentrow
    local c = data.currentcolumn + 1
    local drc = data.rows[r][c]
    drc.nx = texgetcount("c_tabl_x_nx")
    drc.ny = texgetcount("c_tabl_x_ny")
    local distances = data.distances
    local distance = texgetdimen("d_tabl_x_distance")
    if distance > distances[c] then
        distances[c] = distance
    end
    if option and option ~= "" then
        local options = settings_to_hash(option)
        data.options[r][c] = options
        if options[v_fixed] then
            data.frozencolumns[c] = true
        end
    end
    data.currentcolumn = c
end

-- todo: we can better set the cell values in one go

function xtables.set_reflow_width()
    local r = data.currentrow
    local c = data.currentcolumn
    local rows = data.rows
    local row = rows[r]
    local cold = c
    while row[c].span do -- can also be previous row ones
        c = c + 1
    end
    -- bah, we can have a span already
    if c > cold then
        local ro = row[cold]
        local rx = ro.nx
        local ry = ro.ny
        if rx > 1 or ry > 1 then
            local rn = row[c]
            rn.nx = rx
            rn.ny = ry
            ro.nx = 1 -- or 0
            ro.ny = 1 -- or 0
            -- do we also need to set ro.span and rn.span
        end
    end
    local tb = getbox("b_tabl_x")
    local drc = row[c]
    --
    drc.list = true -- we don't need to keep the content around as we're in trial mode (no: copy_node_list(tb))
    --
    local width, height, depth = getwhd(tb)
    --
    local widths  = data.widths
    local heights = data.heights
    local depths  = data.depths
    local cspan   = drc.nx
    if cspan < 2 then
        if width > widths[c] then
            widths[c] = width
        end
    else
        local options = data.options[r][c]
        if data.tight then
            -- no check
        elseif not options then
            if width > widths[c] then
                widths[c] = width
            end
        elseif not options[v_tight] then
            if width > widths[c] then
                widths[c] = width
            end
        end
    end
 -- if cspan > 1 then
 --     local f = data.fixedcspans[c]
 --     local w = f[cspan] or 0
 --     if width > w then
 --         f[cspan] = width -- maybe some day a solution for autospanmax and so
 --     end
 -- end
    if drc.ny < 2 then
     -- report_xtable("set width, old: ht=%p, dp=%p",heights[r],depths[r])
     -- report_xtable("set width, new: ht=%p, dp=%p",height,depth)
        if height > heights[r] then
            heights[r] = height
        end
        if depth > depths[r] then
            depths[r] = depth
        end
    end
    --
    drc.wd = width
    drc.ht = height
    drc.dp = depth
    --
    local dimensionstate = texgetcount("frameddimensionstate")
    local fixedcolumns = data.fixedcolumns
    local fixedrows = data.fixedrows
    if dimensionstate == 1 then
        if cspan > 1 then
            -- ignore width
        elseif width > fixedcolumns[c] then -- how about a span here?
            fixedcolumns[c] = width
        end
    elseif dimensionstate == 2 then
        fixedrows[r]    = height
    elseif dimensionstate == 3 then
        fixedrows[r]    = height -- width
        fixedcolumns[c] = width -- height
    elseif width <= data.criterium_h and height >= data.criterium_v then
        -- somewhat tricky branch
        if width > fixedcolumns[c] then -- how about a span here?
            -- maybe an image, so let's fix
             fixedcolumns[c] = width
        end
    end
--
-- -- this fails so not good enough predictor
--
-- -- \startxtable
-- -- \startxrow
-- --     \startxcell knuth        \stopxcell
-- --     \startxcell \input knuth \stopxcell
-- -- \stopxrow
--
--     else
--         local o = data.options[r][c]
--         if o and o[v_auto] then -- new per 5/5/2014 - removed per 15/07/2014
--             data.autowidths[c] = true
--         else
--            -- no dimensions are set in the cell
--            if width <= data.criterium_h and height >= data.criterium_v then
--                -- somewhat tricky branch
--                if width > fixedcolumns[c] then -- how about a span here?
--                    -- maybe an image, so let's fix
--                     fixedcolumns[c] = width
--                end
--             else
--                 -- safeguard as it could be text that can be recalculated
--                 -- and the previous branch could have happened in a previous
--                 -- row and then forces a wrong one-liner in a multiliner
--                 if width > fixedcolumns[c] then
--                     data.autowidths[c] = true -- new per 5/5/2014 - removed per 15/07/2014
--                 end
--             end
--         end
--     end
--
    --
    drc.dimensionstate = dimensionstate
    --
    local nx = drc.nx
    local ny = drc.ny
    if nx > 1 or ny > 1 then
     -- local spans = data.spans -- not used
        local self = true
        for y=1,ny do
            for x=1,nx do
                if self then
                    self = false
                else
                    local ry = r + y - 1
                    local cx = c + x - 1
                 -- if y > 1 then
                 --     spans[ry] = true -- not used
                 -- end
                    rows[ry][cx].span = true
                end
            end
        end
        c = c + nx - 1
    end
    if c > data.nofcolumns then
        data.nofcolumns = c
    end
    data.currentcolumn = c
end

function xtables.initialize_reflow_height()
    local r = data.currentrow
    local c = data.currentcolumn + 1
    local rows = data.rows
    local row = rows[r]
    while row[c].span do -- can also be previous row ones
        c = c + 1
    end
    data.currentcolumn = c
    local widths = data.widths
    local w = widths[c]
    local drc = row[c]
    for x=1,drc.nx-1 do
        w = w + widths[c+x]
    end
    texsetdimen("d_tabl_x_width",w)
    local dimensionstate = drc.dimensionstate or 0
    if dimensionstate == 1 or dimensionstate == 3 then
        -- width was fixed so height is known
        texsetcount("c_tabl_x_skip_mode",1)
    elseif dimensionstate == 2 then
        -- height is enforced
        texsetcount("c_tabl_x_skip_mode",1)
    elseif data.autowidths[c] then
        -- width has changed so we need to recalculate the height
        texsetcount("c_tabl_x_skip_mode",0)
    elseif data.fixedcolumns[c] then
        texsetcount("c_tabl_x_skip_mode",0) -- new
    else
        texsetcount("c_tabl_x_skip_mode",1)
    end
end

function xtables.set_reflow_height()
    local r = data.currentrow
    local c = data.currentcolumn
    local rows = data.rows
    local row = rows[r]
 -- while row[c].span do -- we could adapt drc.nx instead
 --     c = c + 1
 -- end
    local tb  = getbox("b_tabl_x")
    local drc = row[c]
    --
    local width, height, depth = getwhd(tb)
    --
    if drc.ny < 2 then
        if data.fixedrows[r] == 0 then --  and drc.dimensionstate < 2
            if drc.ht + drc.dp <= height + depth then -- new per 2017-12-15
                local heights = data.heights
                local depths  = data.depths
             -- report_xtable("set height, old: ht=%p, dp=%p",heights[r],depths[r])
             -- report_xtable("set height, new: ht=%p, dp=%p",height,depth)
                if height > heights[r] then
                    heights[r] = height
                end
                if depth > depths[r] then
                    depths[r] = depth
                end
            end
        end
    end
    --
    drc.wd = width
    drc.ht = height
    drc.dp = depth
    --
 -- c = c + drc.nx - 1
 -- data.currentcolumn = c
end

function xtables.initialize_construct()
    local r = data.currentrow
    local c = data.currentcolumn + 1
    local rows = data.rows
    local row = rows[r]
    while row[c].span do -- can also be previous row ones
        c = c + 1
    end
    data.currentcolumn = c
    local widths  = data.widths
    local heights = data.heights
    local depths  = data.depths
    --
    local drc = row[c]
    local wd  = drc.wd
    local ht  = drc.ht
    local dp  = drc.dp
    --
    local width  = widths[c]
    local height = heights[r]
    local depth  = depths[r] -- problem: can be the depth of a one liner
    --
    for x=1,drc.nx-1 do
        width = width + widths[c+x]
    end
    --
    local total = height + depth
    local ny = drc.ny
    if ny > 1 then
        for y=1,ny-1 do
            local nxt = r + y
            total = total + heights[nxt] + depths[nxt]
        end
    end
    --
    texsetdimen("d_tabl_x_width",width)
    texsetdimen("d_tabl_x_height",total)
    texsetdimen("d_tabl_x_depth",0) -- for now
end

function xtables.set_construct()
    local r = data.currentrow
    local c = data.currentcolumn
    local rows = data.rows
    local row = rows[r]
 -- while row[c].span do -- can also be previous row ones
 --     c = c + 1
 -- end
    local drc = row[c]
    -- this will change as soon as in luatex we can reset a box list without freeing
    drc.list = takebox("b_tabl_x")
 -- c = c + drc.nx - 1
 -- data.currentcolumn = c
end

local function showwidths(where,widths,autowidths)
    local result = { }
    for i=1,#widths do
        result[#result+1] = format("%12s%s",points(widths[i]),autowidths[i] and "*" or " ")
    end
    return report_xtable("%s widths: %s",where,concat(result," "))
end

function xtables.reflow_width()
    local nofrows = data.nofrows
    local nofcolumns = data.nofcolumns
    local rows = data.rows
    for r=1,nofrows do
        local row = rows[r]
        for c=1,nofcolumns do
            local drc = row[c]
            if drc.list then
             -- flush_node_list(drc.list)
                drc.list = false
            end
        end
    end
    -- spread
    local settings = data.settings
    local options = settings.options
    local maxwidth = settings.maxwidth
    -- calculate width
    local widths = data.widths
    local heights = data.heights
    local depths = data.depths
    local distances = data.distances
    local autowidths = data.autowidths
    local fixedcolumns = data.fixedcolumns
    local frozencolumns = data.frozencolumns
    local width = 0
    local distance = 0
    local nofwide = 0
    local widetotal = 0
    local available = settings.textwidth - settings.leftmargindistance - settings.rightmargindistance
    if trace_xtable then
        showwidths("stage 1",widths,autowidths)
    end
    local noffrozen = 0
    -- here we can also check spans
    if options[v_max] then
        for c=1,nofcolumns do
            width = width + widths[c]
            if width > maxwidth then
                autowidths[c] = true
                nofwide = nofwide + 1
                widetotal = widetotal + widths[c]
            end
            if c < nofcolumns then
                distance = distance + distances[c]
            end
            if frozencolumns[c] then
                noffrozen = noffrozen + 1 -- brr, should be nx or so
            end
        end
    else
        for c=1,nofcolumns do -- also keep track of forced
            local fixedwidth = fixedcolumns[c]
            if fixedwidth > 0 then
                widths[c] = fixedwidth
                width = width + fixedwidth
            else
                local wc = widths[c]
                width = width + wc
             -- if width > maxwidth then
                if wc > maxwidth then -- per 2015-08-09
                    autowidths[c] = true
                    nofwide = nofwide + 1
                    widetotal = widetotal + wc
                end
            end
            if c < nofcolumns then
                distance = distance + distances[c]
            end
            if frozencolumns[c] then
                noffrozen = noffrozen + 1 -- brr, should be nx or so
            end
        end
    end
    if trace_xtable then
        showwidths("stage 2",widths,autowidths)
    end
    local delta = available - width - distance - (nofcolumns-1) * settings.columndistance
    if delta == 0 then
        -- nothing to be done
        if trace_xtable then
            report_xtable("perfect fit")
        end
    elseif delta > 0 then
        -- we can distribute some
        if not options[v_stretch] then
            -- not needed
            if trace_xtable then
                report_xtable("too wide but no stretch, delta %p",delta)
            end
        elseif options[v_width] then
            local factor = delta / width
            if trace_xtable then
                report_xtable("proportional stretch, delta %p, width %p, factor %a",delta,width,factor)
            end
            for c=1,nofcolumns do
                widths[c] = widths[c] + factor * widths[c]
            end
        else
            -- frozen -> a column with option=fixed will not stretch
            local extra = delta / (nofcolumns - noffrozen)
            if trace_xtable then
                report_xtable("normal stretch, delta %p, extra %p",delta,extra)
            end
            for c=1,nofcolumns do
                if not frozencolumns[c] then
                    widths[c] = widths[c] + extra
                end
            end
        end
    elseif nofwide > 0 then
        while true do
            done = false
            local available = (widetotal + delta) / nofwide
            if trace_xtable then
                report_xtable("shrink check, total %p, delta %p, columns %s, fixed %p",widetotal,delta,nofwide,available)
            end
            for c=1,nofcolumns do
                if autowidths[c] and available >= widths[c] then
                    autowidths[c] = nil
                    nofwide = nofwide - 1
                    widetotal = widetotal - widths[c]
                    done = true
                end
            end
            if not done then
                break
            end
        end
        -- maybe also options[v_width] here but tricky as width does not say
        -- much about amount
        if options[v_width] then -- not that much (we could have a clever vpack loop balancing .. no fun)
            local factor = (widetotal + delta) / width
            if trace_xtable then
                report_xtable("proportional shrink used, total %p, delta %p, columns %s, factor %s",widetotal,delta,nofwide,factor)
            end
            for c=1,nofcolumns do
                if autowidths[c] then
                    widths[c] = factor * widths[c]
                end
            end
        else
            local available = (widetotal + delta) / nofwide
            if trace_xtable then
                report_xtable("normal shrink used, total %p, delta %p, columns %s, fixed %p",widetotal,delta,nofwide,available)
            end
            for c=1,nofcolumns do
                if autowidths[c] then
                    widths[c] = available
                end
            end
        end
    end
    if trace_xtable then
        showwidths("stage 3",widths,autowidths)
    end
    --
    data.currentrow = 0
    data.currentcolumn = 0
end

function xtables.reflow_height()
    data.currentrow = 0
    data.currentcolumn = 0
    local settings = data.settings
    --
    -- analyze ny
    --
    local nofrows    = data.nofrows
    local nofcolumns = data.nofcolumns
    local widths     = data.widths
    local heights    = data.heights
    local depths     = data.depths
    --
    for r=1,nofrows do
        for c=1,nofcolumns do
            local drc = data.rows[r][c]
            if drc then
                local ny = drc.ny
                if ny > 1 then
                    local height = heights[r]
                    local depth  = depths[r]
                    local total  = height + depth
                    local htdp   = drc.ht + drc.dp
                    for y=1,ny-1 do
                        local nxt = r + y
                        total = total + heights[nxt] + depths[nxt]
                    end
                    local delta = htdp - total
                    if delta > 0 then
                        delta = delta / ny
                        for y=0,ny-1 do
                            local nxt = r + y
                            heights[nxt] = heights[nxt] + delta
                        end
                    end
                end
            end
        end
    end
    --
    if settings.options[v_height] then
        local totalheight = 0
        local totaldepth = 0
        for i=1,nofrows do
            totalheight = totalheight + heights[i]
            totalheight = totalheight + depths [i]
        end
        local total = totalheight + totaldepth
        local leftover = settings.textheight - total
        if leftover > 0 then
            local leftheight = (totalheight / total) * leftover / #heights
            local leftdepth  = (totaldepth  / total) * leftover / #depths
            for i=1,nofrows do
                heights[i] = heights[i] + leftheight
                depths [i] = depths [i] + leftdepth
            end
        end
    end
end

local function showspans(data)
    local rows = data.rows
    local modes = data.modes
    local nofcolumns = data.nofcolumns
    local nofrows = data.nofrows
    for r=1,nofrows do
        local line = { }
        local row = rows[r]
        for c=1,nofcolumns do
            local cell =row[c]
            if cell.list then
                line[#line+1] = "list"
            elseif cell.span then
                line[#line+1] = "span"
            else
                line[#line+1] = "none"
            end
        end
        report_xtable("%3d : %s : % t",r,namedmodes[modes[r]] or "----",line)
    end
end

function xtables.construct()
    local rows = data.rows
    local heights = data.heights
    local depths = data.depths
    local widths = data.widths
 -- local spans = data.spans
    local distances = data.distances
    local modes = data.modes
    local settings = data.settings
    local nofcolumns = data.nofcolumns
    local nofrows = data.nofrows
    local columndistance = settings.columndistance
    local rowdistance = settings.rowdistance
    local leftmargindistance = settings.leftmargindistance
    local rightmargindistance = settings.rightmargindistance
    local rowproperties = data.rowproperties
    -- ranges can be mixes so we collect

    if trace_xtable then
        showspans(data)
    end

    local ranges = {
        [head_mode] = { },
        [foot_mode] = { },
        [more_mode] = { },
        [body_mode] = { },
    }
    for r=1,nofrows do
        local m = modes[r]
        if m == 0 then
            m = body_mode
        end
        local range = ranges[m]
        range[#range+1] = r
    end
    -- todo: hook in the splitter ... the splitter can ask for a chunk of
    -- a certain size ... no longer a split memory issue then and header
    -- footer then has to happen here too .. target height
    local function packaged_column(r)
        local row = rows[r]
        local start = nil
        local stop = nil
        if leftmargindistance > 0 then
            start = new_kern(leftmargindistance)
            stop = start
        end
        local hasspan = false
        for c=1,nofcolumns do
            local drc = row[c]
            if not hasspan then
                hasspan = drc.span
            end
            local list = drc.list
            if list then
                local w, h, d = getwhd(list)
                setshift(list,h+d)
             -- list = hpack_node_list(list) -- is somehow needed
             -- setwhd(list,0,0,0)
                -- faster:
                local h = new_hlist(list)
                list = h
                --
                if start then
                    setlink(stop,list)
                else
                    start = list
                end
                stop = list
            end
            local step = widths[c]
            if c < nofcolumns then
                step = step + columndistance + distances[c]
            end
            local kern = new_kern(step)
            if stop then
                setlink(stop,kern)
            else -- can be first spanning next row (ny=...)
                start = kern
            end
            stop = kern
        end
        if start then
            if rightmargindistance > 0 then
                local kern = new_kern(rightmargindistance)
                setlink(stop,kern)
             -- stop = kern
            end
            return start, heights[r] + depths[r], hasspan
        end
    end
    local function collect_range(range)
        local result, nofr = { }, 0
        local nofrange = #range
        for i=1,#range do
            local r = range[i]
         -- local row = rows[r]
            local list, size, hasspan = packaged_column(r)
            if list then
                if hasspan and nofr > 0 then
                    result[nofr][4] = true
                end
                nofr = nofr + 1
                local rp = rowproperties[r]
                -- we have a direction issue here but hpack_node_list(list,0,"exactly","TLT") cannot be used
                -- due to the fact that we need the width
                local hbox = hpack_node_list(list)
                setdirection(hbox,lefttoright_code)
                result[nofr] = {
                    hbox,
                    size,
                    i < nofrange and rowdistance > 0 and rowdistance or false, -- might move
                    false,
                    rp or false,
                }
            end
        end
        if nofr > 0 then
            -- the [5] slot gets the after break
            result[1]   [5] = false
            result[nofr][5] = false
            for i=2,nofr-1 do
                local r = result[i][5]
                if r == v_both or r == v_before then
                    result[i-1][5] = true
                elseif r == v_after then
                    result[i][5] = true
                end
            end
        end
        return result
    end
    local body = collect_range(ranges[body_mode])
    data.results = {
        [head_mode] = collect_range(ranges[head_mode]),
        [foot_mode] = collect_range(ranges[foot_mode]),
        [more_mode] = collect_range(ranges[more_mode]),
        [body_mode] = body,
    }
    if #body == 0 then
        texsetcount("global","c_tabl_x_state",0)
        texsetdimen("global","d_tabl_x_final_width",0)
    else
        texsetcount("global","c_tabl_x_state",1)
        texsetdimen("global","d_tabl_x_final_width",getwidth(body[1][1]))
    end
end

-- todo: join as that is as efficient as fushing multiple

local function inject(row,copy,package)
    local list = row[1]
    if copy then
        row[1] = copy_node_list(list)
    end
    if package then
        ctx_beginvbox()
        ctxnode(tonode(list))
        ctxnode(tonode(new_kern(row[2])))
        ctx_endvbox()
        ctx_nointerlineskip() -- figure out a better way
        if row[4] then
            -- nothing as we have a span
        elseif row[5] then
            if row[3] then
                ctx_blank { v_samepage, row[3] .. "sp" }
            else
                ctx_blank { v_samepage }
            end
        elseif row[3] then
            ctx_blank { row[3] .. "sp" } -- why blank ?
        else
            ctxnode(tonode(new_glue(0)))
        end
    else
        ctxnode(tonode(list))
        ctxnode(tonode(new_kern(row[2])))
        if row[3] then
            ctxnode(tonode(new_glue(row[3])))
        end
    end
end

local function total(row,distance)
    local n = #row > 0 and rowdistance or 0
    for i=1,#row do
        local ri = row[i]
        n = n + ri[2] + (ri[3] or 0)
    end
    return n
end

-- local function append(list,what)
--     for i=1,#what do
--         local l = what[i]
--         list[#list+1] = l[1]
--         local k = l[2] + (l[3] or 0)
--         if k ~= 0 then
--             list[#list+1] = new_kern(k)
--         end
--     end
-- end

local function spanheight(body,i)
    local height, n = 0, 1
    while true do
        local bi = body[i]
        if bi then
            height = height + bi[2] + (bi[3] or 0)
            if bi[4] then
                n = n + 1
                i = i + 1
            else
                break
            end
        else
            break
        end
    end
    return height, n
end

function xtables.flush(directives) -- todo split by size / no inbetween then ..  glue list kern blank
    local height       = directives.height
    local method       = directives.method or v_normal
    local settings     = data.settings
    local results      = data.results
    local rowdistance  = settings.rowdistance
    local head         = results[head_mode]
    local foot         = results[foot_mode]
    local more         = results[more_mode]
    local body         = results[body_mode]
    local repeatheader = settings.header == v_repeat
    local repeatfooter = settings.footer == v_repeat
    if height and height > 0 then
        ctx_beginvbox()
        local bodystart = data.bodystart or 1
        local bodystop  = data.bodystop or #body
        if bodystart > 0 and bodystart <= bodystop then
            local bodysize = height
            local footsize = total(foot,rowdistance)
            local headsize = total(head,rowdistance)
            local moresize = total(more,rowdistance)
            local firstsize, firstspans = spanheight(body,bodystart)
            if bodystart == 1 then -- first chunk gets head
                bodysize = bodysize - headsize - footsize
                if headsize > 0 and bodysize >= firstsize then
                    for i=1,#head do
                        inject(head[i],repeatheader)
                    end
                    if rowdistance > 0 then
                        ctxnode(tonode(new_glue(rowdistance)))
                    end
                    if not repeatheader then
                        results[head_mode] = { }
                    end
                end
            elseif moresize > 0 then -- following chunk gets next
                bodysize = bodysize - footsize - moresize
                if bodysize >= firstsize then
                    for i=1,#more do
                        inject(more[i],true)
                    end
                    if rowdistance > 0 then
                        ctxnode(tonode(new_glue(rowdistance)))
                    end
                end
            elseif headsize > 0 and repeatheader then -- following chunk gets head
                bodysize = bodysize - footsize - headsize
                if bodysize >= firstsize then
                    for i=1,#head do
                        inject(head[i],true)
                    end
                    if rowdistance > 0 then
                        ctxnode(tonode(new_glue(rowdistance)))
                    end
                end
            else -- following chunk gets nothing
                bodysize = bodysize - footsize
            end
            if bodysize >= firstsize then
                local i = bodystart
                while i <= bodystop do -- room for improvement
                    local total, spans = spanheight(body,i)
                    local bs = bodysize - total
                    if bs > 0 then
                        bodysize = bs
                        for s=1,spans do
                            inject(body[i])
                            body[i] = nil
                            i = i + 1
                        end
                        bodystart = i
                    else
                        break
                    end
                end
                if bodystart > bodystop then
                    -- all is flushed and footer fits
                    if footsize > 0 then
                        if rowdistance > 0 then
                            ctxnode(tonode(new_glue(rowdistance)))
                        end
                        for i=1,#foot do
                            inject(foot[i])
                        end
                        results[foot_mode] = { }
                    end
                    results[body_mode] = { }
                    texsetcount("global","c_tabl_x_state",0)
                else
                    -- some is left so footer is delayed
                    -- todo: try to flush a few more lines
                    if repeatfooter and footsize > 0 then
                        if rowdistance > 0 then
                            ctxnode(tonode(new_glue(rowdistance)))
                        end
                        for i=1,#foot do
                            inject(foot[i],true)
                        end
                    else
                        -- todo: try to fit more of body
                    end
                    texsetcount("global","c_tabl_x_state",2)
                end
            else
                if firstsize > height then
                    -- get rid of the too large cell
                    for s=1,firstspans do
                        inject(body[bodystart])
                        body[bodystart] = nil
                        bodystart = bodystart + 1
                    end
                end
                texsetcount("global","c_tabl_x_state",2) -- 1
            end
        else
            texsetcount("global","c_tabl_x_state",0)
        end
        data.bodystart = bodystart
        data.bodystop = bodystop
        ctx_endvbox()
    else
        if method == variables.split then
            -- maybe also a non float mode with header/footer repeat although
            -- we can also use a float without caption
            for i=1,#head do
                inject(head[i],false,true)
            end
            if #head > 0 and rowdistance > 0 then
                ctx_blank { rowdistance .. "sp" }
            end
            for i=1,#body do
                inject(body[i],false,true)
            end
            if #foot > 0 and rowdistance > 0 then
                ctx_blank { rowdistance .. "sp" }
            end
            for i=1,#foot do
                inject(foot[i],false,true)
            end
        else -- normal
            ctx_beginvbox()
            for i=1,#head do
                inject(head[i])
            end
            if #head > 0 and rowdistance > 0 then
                ctxnode(tonode(new_glue(rowdistance)))
            end
            for i=1,#body do
                inject(body[i])
            end
            if #foot > 0 and rowdistance > 0 then
                ctxnode(tonode(new_glue(rowdistance)))
            end
            for i=1,#foot do
                inject(foot[i])
            end
            ctx_endvbox()
        end
        results[head_mode] = { }
        results[body_mode] = { }
        results[foot_mode] = { }
        texsetcount("global","c_tabl_x_state",0)
    end
end

function xtables.cleanup()
    for mode, result in next, data.results do
        for _, r in next, result do
            flush_node_list(r[1])
        end
    end

    -- local rows = data.rows
    -- for i=1,#rows do
    --     local row = rows[i]
    --     for i=1,#row do
    --         local cell = row[i]
    --         local list = cell.list
    --         if list then
    --             cell.width, cell.height, cell.depth = getwhd(list)
    --             cell.list = true
    --         end
    --     end
    -- end
    -- data.result = nil

    data = table.remove(stack)
end

function xtables.next_row(specification)
    local r = data.currentrow + 1
    data.modes[r] = texgetcount("c_tabl_x_mode")
    data.currentrow = r
    data.currentcolumn = 0
    data.rowproperties[r] = specification
end

function xtables.finish_row()
    local c = data.currentcolumn
    local r = data.currentrow
    local d = data.rows[r][c]
    local n = data.nofcolumns - c
    if d then
        local nx = d.nx
        if nx > 0 then
            n = n - nx + 1
        end
    end
    if n > 0 then
        for i=1,n do
            ctx_dummyxcell()
        end
    end
end

-- eventually we might only have commands

implement {
    name      = "x_table_create",
    actions   = xtables.create,
    arguments = {
        {
            { "option" },
            { "textwidth", "dimen" },
            { "textheight", "dimen" },
            { "maxwidth", "dimen" },
            { "lineheight", "dimen" },
            { "columndistance", "dimen" },
            { "leftmargindistance", "dimen" },
            { "rightmargindistance", "dimen" },
            { "rowdistance", "dimen" },
            { "header" },
            { "footer" },
        }
    }
}

implement {
    name      = "x_table_flush",
    actions   = xtables.flush,
    arguments = {
        {
            { "method" },
            { "height", "dimen" }
        }
    }
}

implement { name = "x_table_reflow_width",              actions = xtables.reflow_width  }
implement { name = "x_table_reflow_height",             actions = xtables.reflow_height }
implement { name = "x_table_construct",                 actions = xtables.construct }
implement { name = "x_table_cleanup",                   actions = xtables.cleanup }
implement { name = "x_table_next_row",                  actions = xtables.next_row }
implement { name = "x_table_next_row_option",           actions = xtables.next_row, arguments = "string" }
implement { name = "x_table_finish_row",                actions = xtables.finish_row }
implement { name = "x_table_init_reflow_width",         actions = xtables.initialize_reflow_width  }
implement { name = "x_table_init_reflow_height",        actions = xtables.initialize_reflow_height }
implement { name = "x_table_init_reflow_width_option",  actions = xtables.initialize_reflow_width,  arguments = "string" }
implement { name = "x_table_init_reflow_height_option", actions = xtables.initialize_reflow_height, arguments = "string" }
implement { name = "x_table_init_construct",            actions = xtables.initialize_construct }
implement { name = "x_table_set_reflow_width",          actions = xtables.set_reflow_width }
implement { name = "x_table_set_reflow_height",         actions = xtables.set_reflow_height }
implement { name = "x_table_set_construct",             actions = xtables.set_construct }
implement { name = "x_table_r",                         actions = function() context(data.currentrow    or 0) end }
implement { name = "x_table_c",                         actions = function() context(data.currentcolumn or 0) end }

-- experiment:

do

    local context         = context
    local ctxcore         = context.core

    local startxtable     = ctxcore.startxtable
    local stopxtable      = ctxcore.stopxtable

    local startcollecting = context.startcollecting
    local stopcollecting  = context.stopcollecting

    function ctxcore.startxtable(...)
        startcollecting()
        startxtable(...)
    end

    function ctxcore.stopxtable()
        stopxtable()
        stopcollecting()
    end

end
