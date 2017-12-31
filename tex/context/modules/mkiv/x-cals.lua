if not modules then modules = { } end modules ['x-cals'] = {
    version   = 1.001,
    comment   = "companion to x-cals.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type = next, type
local format, lower = string.format, string.lower
local xmlcprint, xmlcollected, xmlelements = xml.cprint, xml.collected, xml.elements
local n_todimen, s_todimen = number.todimen, string.todimen

-- there is room for speedups as well as cleanup (using context functions)

local cals      = { }
moduledata.cals = cals
lxml.mathml     = cals -- for the moment

cals.ignore_widths  = false
cals.shrink_widths  = false
cals.stretch_widths = false

-- the following flags only apply to columns that have a specified width
--
-- proportional : shrink or stretch proportionally to the width
-- equal        : shrink or stretch equaly distributed
-- n < 1        : shrink or stretch proportionally to the width but multiplied by n
--
-- more clever things, e.g. the same but applied to unspecified widths
-- has to happen at the core-ntb level (todo)

local halignments = {
    left    = "flushleft",
    right   = "flushright",
    center  = "middle",
    centre  = "middle",
    justify = "normal",
}

local valignments = {
    top    = "high",
    bottom = "low",
    middle = "lohi",
}

local function adapt(widths,b,w,delta,sum,n,what)
    if b == "equal" then
        delta = delta/n
        for k, v in next, w do
            widths[k] = n_todimen(v - delta)
        end
    elseif b == "proportional" then
        delta = delta/sum
        for k, v in next, w do
            widths[k] = n_todimen(v - v*delta)
        end
    elseif type(b) == "number" and b < 1 then
        delta = b*delta/sum
        for k, v in next, w do
            widths[k] = n_todimen(v - v*delta)
        end
    end
end

local function getspecs(root, pattern, names, widths)
    -- here, but actually we need this in core-ntb.tex
    -- but ideally we need an mkiv enhanced core-ntb.tex
    local ignore_widths  = cals.ignore_widths
--     local shrink_widths  = at.option == "shrink"  or cals.shrink_widths
--     local stretch_widths = at.option == "stretch" or cals.stretch_widths
    local shrink_widths  = cals.shrink_widths
    local stretch_widths = cals.stretch_widths
    for e in xmlcollected(root,pattern) do
        local at = e.at
        local column = at.colnum
        if column then
            if not ignore_widths then
                local width = at.colwidth
                if width then
                    widths[tonumber(column)] = lower(width)
                end
            end
            local name = at.colname
            if name then
                names[name] = tonumber(column)
            end
        end
    end
    if ignore_width then
        -- forget about it
    elseif shrink_widths or stretch_widths then
        local sum, n, w = 0, 0, { }
        for _, v in next, widths do
            n = n + 1
            v = (type(v) == "string" and s_todimen(v)) or v
            if v then
                w[n] = v
                sum = sum + v
            end
        end
        local hsize = tex.hsize
        if type(hsize) == "string" then
            hsize = s_todimen(hsize)
        end
        local delta = sum - hsize
        if shrink_widths and delta > 0 then
            adapt(widths,shrink_widths,w,delta,sum,n,"shrink")
        elseif stretch_widths and delta < 0 then
            adapt(widths,stretch_widths,w,delta,sum,n,"stretch")
        end
    end
end

local function getspans(root, pattern, names, spans)
    for e in xmlcollected(root,pattern) do
        local at = e.at
        local name, namest, nameend = at.colname, names[at.namest or "?"], names[at.nameend or "?"]
        if name and namest and nameend then
            spans[name] = tonumber(nameend) - tonumber(namest) + 1
        end
    end
end

local bTR, eTR, bTD, eTD = context.bTR, context.eTR, context.bTD, context.eTD

function cals.table(root,namespace)

    local prefix = (namespace or "cals") .. ":"

    local prefix = namespace and namespace ~= "" and (namespace .. ":") or ""
    local p = "/" .. prefix

    local tgroupspec = p .. "tgroup"
    local colspec    = p .. "colspec"
    local spanspec   = p .. "spanspec"
    local hcolspec   = p .. "thead" .. p .. "colspec"
    local bcolspec   = p .. "tbody" .. p .. "colspec"
    local fcolspec   = p .. "tfoot" .. p .. "colspec"
    local entryspec  = p .. "entry" .. "|" .. prefix .. "entrytbl" -- shouldn't that be p ?
    local hrowspec   = p .. "thead" .. p .. "row"
    local browspec   = p .. "tbody" .. p .. "row"
    local frowspec   = p .. "tfoot" .. p .. "row"

    local function tablepart(root, xcolspec, xrowspec, before, after) -- move this one outside
        before()
        local at = root.at
        local pphalign, ppvalign = at.align, at.valign
        local names, widths, spans = { }, { }, { }
        getspecs(root, colspec , names, widths)
        getspecs(root, xcolspec, names, widths)
        getspans(root, spanspec, names, spans)
        for r, d, k in xmlelements(root,xrowspec) do
            bTR()
            local dk = d[k]
            local at = dk.at
            local phalign, pvalign = at.align or pphalign, at.valign or ppvalign -- todo: __p__ test
            local col = 1
            for rr, dd, kk in xmlelements(dk,entryspec) do
                local dk = dd[kk]
                if dk.tg == "entrytbl" then
                 -- bTD(function() cals.table(dk) end)
                    bTD()
                    context("{")
                    cals.table(dk)
                    context("}")
                    eTD()
                    col = col + 1
                else
                    local at = dk.at
                    local b, e, s, m = names[at.namest or "?"], names[at.nameend or "?"], spans[at.spanname or "?"], at.morerows
                    local halign, valign = at.align or phalign, at.valign or pvalign
                    if b and e then
                        s = e - b + 1
                    end
                    if halign then
                        halign = halignments[halign]
                    end
                    if valign then
                        valign = valignments[valign]
                    end
                    local width = widths[col]
                    if s or m or halign or valign or width then -- currently only english interface !
                        bTD {
                            nx    = s or 1,
                            ny    = (m or 0) + 1,
                            align = format("{%s,%s}",halign or "flushleft",valign or "high"),
                            width = width or "fit",
                        }
                    else
                        bTD {
                            align = "{flushleft,high}",
                            width = "fit", -- else problems with vertical material
                        }
                    end
                    xmlcprint(dk)
                    eTD()
                    col = col + (s or 1)
                end
            end
            eTR()
        end
        after()
    end

    for tgroup in lxml.collected(root,tgroupspec) do
        context.directsetup("cals:table:before")
        lxml.directives.before(root,"cdx") -- "cals:table"
        context.bgroup()
        lxml.directives.setup(root,"cdx") -- "cals:table"
        context.bTABLE()
        tablepart(tgroup, hcolspec, hrowspec, context.bTABLEhead, context.eTABLEhead)
        tablepart(tgroup, bcolspec, browspec, context.bTABLEbody, context.eTABLEbody)
        tablepart(tgroup, fcolspec, frowspec, context.bTABLEfoot, context.eTABLEfoot)
        context.eTABLE()
        context.egroup()
        lxml.directives.after(root,"cdx") -- "cals:table"
        context.directsetup("cals:table:after")
    end

end
