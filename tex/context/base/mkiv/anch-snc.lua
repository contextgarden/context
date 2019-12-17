if not modules then modules = { } end modules ['anch-snc'] = {
    version   = 1.001,
    comment   = "companion to anch-snc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}


-- use factors as in mlib-int.lua

local tonumber, next, setmetatable = tonumber, next, setmetatable
local concat, sort, remove, copy = table.concat, table.sort, table.remove, table.copy
local match, find = string.match, string.find
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

local P, Cc = lpeg.P, lpeg.Cc

local setmetatableindex = table.setmetatableindex

local factor            = number.dimenfactors.bp
local mpprint           = mp.print
local mpnumeric         = mp.numeric
local mppoints          = mp.points
local texgetdimen       = tex.getdimen

local p_number = patterns.cardinal/tonumber
local p_space  = patterns.whitespace^0
local p_tag    = P("syncpos:") * p_number * P(":") * p_number
local p_option = p_number * ((P(",") * p_space * P("reset") * Cc(true)) + Cc(false)) -- for now

local list     = { }
local colors   = setmetatableindex("table")

local kinds    = {
    above    = 1,
    continue = 2,
    nothing  = 3,
    normal   = 4,
    below    = 5,
}

local allentries = setmetatableindex(function(t,category)
    setmetatable(t,nil)
    for tag, pos in next, job.positions.collected do
        local c, n = lpegmatch(p_tag,tag)
        if c then
            local tc = t[c]
            if tc then
                tc[n] = pos
            else
                t[c] = { [n] = pos }
            end
        end
    end
    for k, list in next, t do
        sort(list,function(a,b)
            local ap = a.p
            local bp = b.p
            if ap == bp then
                return b.y < a.y
            else
                return ap < bp
            end
        end)
        list.start = 1
    end
    setmetatableindex(t,"table")
    return t[category]
end)

local lastdone = { }

function mp.sync_collect(category,realpage,useregion)
    local all = allentries[category]
    local m   = 0
    local n   = #all
    list = { }
    if useregion then
        -- successive can be optimized when we sort by region
        local start = 1
        local done  = false
        local last, rtop, rbot
        for i=start,n do
            local pos = all[i]
            local p = pos.p
            local r = pos.r
            if r == useregion then
                if not done then
                    local region = job.positions.collected[r]
                    list.region  = region
                    list.page    = region
                    rtop = (region.y or 0) + (region.h or 0)
                    rbot = (region.y or 0) - (region.d or 0)
                    last = { kind = "nothing", top = rtop, bottom = 0, task = 0 }
                    m = m + 1 ; list[m] = last
                    done = true
                end
                local top = pos.y + pos.h
                last.bottom = top
                local task, reset = lpegmatch(p_option,pos.e)
                last = { kind = "normal", top = top, bottom = 0, task = task }
                m = m + 1 ; list[m] = last
            end
        end
        if done then
            last.bottom = rbot
        end
    else
        local start = all.start or 1
        local done  = false
        local last, rtop, rbot, ptop, pbot
        for i=start,n do
            local pos = all[i]
            local p = pos.p
            if p == realpage then
                if not done then
                    local region = job.positions.collected[pos.r]
                    local page   = job.positions.collected["page:"..realpage] or region
                    list.region  = region
                    list.page    = page
                    rtop = (region.y or 0) + (region.h or 0)
                    rbot = (region.y or 0) - (region.d or 0)
                    ptop = (page  .y or 0) + (page  .h or 0)
                    pbot = (page  .y or 0) - (page  .d or 0)
                    last = { kind = "above", top = ptop, bottom = rtop, task = 0 }
                    m = m + 1 ; list[m] = last
                    if i > 1 then
                        local task, reset = lpegmatch(p_option,all[i-1].e)
                        last = { kind = "continue", top = rtop, bottom = 0, task = task }
                        m = m + 1 ; list[m] = last
                    else
                        last = { kind = "nothing", top = rtop, bottom = 0, task = 0 }
                        m = m + 1 ; list[m] = last
                    end
                    done = true
                end
                local top = pos.y + pos.h
                last.bottom = top
                local task, reset = lpegmatch(p_option,pos.e)
                if reset then
                    local l = list[2]
                    l.kind = "nothing"
                    l.task = 0
                end
                last = { kind = "normal", top = top, bottom = 0, task = task }
                m = m + 1 ; list[m] = last
            elseif p > realpage then
                all.start = i -- tricky, only for page
                break
            end
        end
        if done then
            last.bottom = rbot
            last = { kind = "below", top = rbot, bottom = pbot, task = 0 }
            m = m + 1 ; list[m] = last
            lastdone[category] = {
                { kind = "above", top = ptop, bottom = rtop, task = 0 },
                { kind = "continue", top = rtop, bottom = rbot, task = list[#list-1].task }, -- lasttask
                { kind = "below", top = rbot, bottom = pbot, task = 0 },
                region = list.region,
                page   = list.page,
            }
        else
            local l = lastdone[category]
            if l then
                list = copy(l) -- inefficient, mayb emetatable for region/page
                m    = 3
            end
        end
    end
    mpnumeric(m)
end

function mp.sync_extend()
     local n = #list
     if n > 0 then
        for i=1,n do
            local l = list[i]
            local k = l.kind
            if k == "nothing" then
                local ll = list[i+1]
                if ll and ll.kind == "normal" then
                    ll.top = l.top
                    remove(list,i)
                    n = #list
                    break
                end
            end
        end
    end
    mpnumeric(n)
end

function mp.sync_prune()
     local n = #list
     if n > 0 then
        if list[1].kind == "above" then
            remove(list,1)
        end
        if list[1].kind == "nothing" then
            remove(list,1)
        end
        if list[#list].kind == "below" then
            remove(list,#list)
        end
        n = #list
    end
    mpnumeric(n)
end

function mp.sync_collapse()
    local n = #list
    if n > 0 then
        local m = 0
        local p = nil
        for i=1,n do
            local l = list[i]
            local t = l.task
            if p == t then
                list[m].bottom = l.bottom
            else
                m = m + 1
                list[m] = l
            end
            p = t
        end
        for i=n,m+1,-1 do
            list[i] = nil
        end
        n = m
    end
    mpnumeric(n)
end

function mp.sync_set_color(category,n,v)
    colors[category][n] = v
end

function mp.sync_get_color(category,n)
    mpprint(colors[category][n])
end

-- function mp.sync_get_size  ()  mpnumeric(#list) end
-- function mp.sync_get_top   (n) mppoints (list[n].top) end
-- function mp.sync_get_bottom(n) mppoints (list[n].bottom) end
-- function mp.sync_get_kind  (n) mpnumeric(kinds[list[n].kind]) end
-- function mp.sync_get_task  (n) mpnumeric(list[n].task) end

-- function mp.sync_get_x() mppoints(list.page.x or 0) end
-- function mp.sync_get_y() mppoints(list.page.y or 0) end
-- function mp.sync_get_w() mppoints(list.page.w or 0) end
-- function mp.sync_get_h() mppoints(list.page.h or 0) end
-- function mp.sync_get_d() mppoints(list.page.d or 0) end

function mp.sync_get_size  ()  mpnumeric(#list) end
function mp.sync_get_top   (n) mpnumeric(list[n].top * factor) end
function mp.sync_get_bottom(n) mpnumeric(list[n].bottom * factor) end
function mp.sync_get_kind  (n) mpnumeric(kinds[list[n].kind]) end
function mp.sync_get_task  (n) mpnumeric(list[n].task) end

function mp.sync_get_x() mpnumeric((list.page.x or 0)*factor) end
function mp.sync_get_y() mpnumeric((list.page.y or 0)*factor) end
function mp.sync_get_w() mpnumeric((list.page.w or 0)*factor) end
function mp.sync_get_h() mpnumeric((list.page.h or 0)*factor) end
function mp.sync_get_d() mpnumeric((list.page.d or 0)*factor) end

-- function mp.xxOverlayRegion()
--     local r = tokens.getters.macro("m_overlay_region")
--     mp.quoted('"'.. r .. '"')
-- end

