if not modules then modules = { } end modules ['page-lin'] = {
    version   = 1.001,
    comment   = "companion to page-lin.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- experimental -> will become builders

-- if there is demand for it, we can support multiple numbering streams
-- and use more than one attibute

local next, tonumber = next, tonumber

local trace_numbers      = false  trackers.register("lines.numbers",  function(v) trace_numbers = v end)

local report_lines       = logs.reporter("lines")

local attributes         = attributes
local nodes              = nodes
local context            = context

local implement          = interfaces.implement

nodes.lines              = nodes.lines or { }
local lines              = nodes.lines

lines.data               = lines.data or { } -- start step tag
local data               = lines.data
local last               = #data

lines.scratchbox         = lines.scratchbox or 0

storage.register("lines/data", data, "nodes.lines.data")

local variables          = interfaces.variables

local v_next             = variables.next
local v_page             = variables.page
local v_no               = variables.no

local properties         = nodes.properties.data

local nodecodes          = nodes.nodecodes
local listcodes          = nodes.listcodes

local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local whatsit_code       = nodecodes.whatsit
local glyph_code         = nodecodes.glyph

local linelist_code      = listcodes.line

local a_displaymath      = attributes.private('displaymath')
local a_linenumber       = attributes.private('linenumber')
local a_linereference    = attributes.private('linereference')
----- a_verbatimline     = attributes.private('verbatimline')

local current_list       = { }
local cross_references   = { }
local chunksize          = 250 -- not used in boxed

local nuts               = nodes.nuts

local getid              = nuts.getid
local getsubtype         = nuts.getsubtype
local getnext            = nuts.getnext
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local getlist            = nuts.getlist
local getbox             = nuts.getbox
----- getdirection       = nuts.getdirection
----- getwidth           = nuts.getwidth
local getheight          = nuts.getheight
local getdepth           = nuts.getdepth

local setprop            = nuts.setprop
local getprop            = nuts.getprop

local nexthlist          = nuts.traversers.hlist
local nextvlist          = nuts.traversers.vlist

local copy_node          = nuts.copy
----- hpack_nodes        = nuts.hpack
local is_display_math    = nuts.is_display_math
local leftmarginwidth    = nuts.leftmarginwidth

----- nodepool           = nuts.pool
----- new_kern           = nodepool.kern

local ctx_convertnumber  = context.convertnumber
local ctx_makelinenumber = context.makelinenumber

local paragraphs         = typesetters.paragraphs
local addtoline          = paragraphs.addtoline
local checkline          = paragraphs.checkline
local moveinline         = paragraphs.moveinline

-- cross referencing

function lines.number(n)
    n = tonumber(n)
    local cr = cross_references[n] or 0
    cross_references[n] = nil
    return cr
end

local function resolve(n,m) -- we can now check the 'line' flag (todo)
    while n do
        local id = getid(n)
        if id == whatsit_code then -- why whatsit
            local a = getattr(n,a_linereference)
            if a then
                cross_references[a] = m
            end
        elseif id == hlist_code or id == vlist_code then
            resolve(getlist(n),m)
        end
        n = getnext(n)
    end
end

function lines.finalize(t)
    local getnumber = lines.number
    for _,p in next, t do
        for _,r in next, p do
            local m = r.metadata
            if m and m.kind == "line" then
                local e = r.entries
                local u = r.userdata
                e.linenumber = getnumber(e.text or 0) -- we can nil e.text
                e.conversion = u and u.conversion
                r.userdata = nil -- hack
            end
        end
    end
end

local filters = structures.references.filters
local helpers = structures.helpers

structures.references.registerfinalizer(lines.finalize)

filters.line = filters.line or { }

function filters.line.default(data)
--  helpers.title(data.entries.linenumber or "?",data.metadata)
    ctx_convertnumber(data.entries.conversion or "numbers",data.entries.linenumber or "0")
end

function filters.line.page(data,prefixspec,pagespec) -- redundant
    helpers.prefixpage(data,prefixspec,pagespec)
end

function filters.line.linenumber(data) -- raw
    context(data.entries.linenumber or "0")
end

-- boxed variant, todo: use number mechanism

lines.boxed = { }
local boxed = lines.boxed

-- todo: cache setups, and free id no longer used
-- use interfaces.cachesetup(t)

function boxed.register(configuration)
    last = last + 1
    data[last] = configuration
    if trace_numbers then
        report_lines("registering setup %a",last)
    end
    return last
end

implement {
    name      = "registerlinenumbering",
    actions   = { boxed.register, context },
    arguments = {
        {
            { "continue" },
            { "start", "integer" },
            { "step", "integer" },
            { "method" },
            { "tag" },
        }
    }
}

function boxed.setup(n,configuration)
    local d = data[n]
    if d then
        if trace_numbers then
            report_lines("updating setup %a",n)
        end
        for k,v in next, configuration do
            d[k] = v
        end
    else
        if trace_numbers then
            report_lines("registering setup %a (br)",n)
        end
        data[n] = configuration
    end
    return n
end

implement {
    name      = "setuplinenumbering",
    actions   = boxed.setup,
    arguments = {
        "integer",
        {
            { "continue" },
            { "start", "integer" },
            { "step", "integer" },
            { "method" },
            { "tag" },
        }
    }
}

local function check_number(n,a,skip,sameline)
    local d = data[a]
    if d then
        local tag      = d.tag or ""
        local skipflag = 0
        local s        = d.start or 1
        current_list[#current_list+1] = { n, s }
        if sameline then
            skipflag = 0
            if trace_numbers then
                report_lines("skipping broken line number %s for setup %a: %s (%s)",#current_list,a,s,d.continue or v_no)
            end
        elseif not skip and s % d.step == 0 then
            skipflag, d.start = 1, s + 1 -- (d.step or 1)
            if trace_numbers then
                report_lines("making number %s for setup %a: %s (%s)",#current_list,a,s,d.continue or v_no)
            end
        else
            skipflag, d.start = 0, s + 1 -- (d.step or 1)
            if trace_numbers then
                report_lines("skipping line number %s for setup %a: %s (%s)",#current_list,a,s,d.continue or v_no)
            end
        end
        local p = checkline(n)
        if p then
            ctx_makelinenumber(tag,skipflag,s,p.hsize,p.reverse and 1 or 0)
        else
            report_lines("needs checking")
        end
    end
end

-- print(nodes.idstostring(list))

-- hlists of type line will only have an attribute when the line number attribute
-- still set at par building time which is not always the case unless we explicitly
-- do a par before we end the line

-- todo: check for a: when <= 0 then false

local function lineisnumbered(n)
    local n = getlist(n)
    while n do
        local id = getid(n)
        if id == hlist_code or id == vlist_code then
            -- this can hit fast as we inherit anchor attributes from parent
            local a = getattr(n,a_linenumber)
            if a and a > 0 then
                return a
            end
        elseif id == glyph_code then
            local a = getattr(n,a_linenumber)
            if a and a > 0 then
                return a
            else
                return false
            end
        end
        n = getnext(n)
    end
end

local function listisnumbered(list)
    if list then
        for n, subtype in nexthlist, list do
            if subtype == linelist_code then
                local a = getattr(n,a_linenumber)
                if a then
                    -- a quick test for lines (only valid when \par before \stoplinenumbering)
                    return a > 0 and list or false
                else
                    -- a bit slower one, assuming that we have normalized and anchored
                    if lineisnumbered(n) then
                        return list
                    end
                end
            end
        end
    end
end

local function findnumberedlist(list)
    -- we assume wrapped boxes, only one with numbers
    local n = list
    while n do
        local id = getid(n)
        if id == hlist_code then
            if getsubtype(n) == linelist_code then
                local a = getattr(n,a_linenumber)
                if a then
                    return a > 0 and list
                end
                return
            else
                local list = getlist(n)
                if lineisnumbered(list) then
                    return n
                end
                local okay = findnumberedlist(list)
                if okay then
                    return okay
                end
            end
        elseif id == vlist_code then
            local list = getlist(n)
            if listisnumbered(list) then
                return list
            end
            local okay = findnumberedlist(list)
            if okay then
                return okay
            end
        elseif id == glyph_code then
            return
        end
        n = getnext(n)
    end
end

-- reset ranges per page
-- store first and last per page
-- maybe just set marks directly

local function findcolumngap(list)
    -- we assume wrapped boxes, only one with numbers
    local n = list
    while n do
        local id = getid(n)
        if id == hlist_code or id == vlist_code then
            local p = properties[n]
            if p and p.columngap then
                if trace_numbers then
                    report_lines("first column gap %a",p.columngap)
                end
                return n
            else
                local list = getlist(n)
                if list then
                    local okay = findcolumngap(list)
                    if okay then
                        return okay
                    end
                end
            end
        end
        n = getnext(n)
    end
end

function boxed.stage_one(n,nested)
    current_list = { }
    local box = getbox(n)
    if not box then
        return
    end
    local list = getlist(box)
    if not list then
        return
    end
    local last_a = nil
    local last_v = -1
    local skip   = false

    local function check()
        for n, subtype in nexthlist, list do
            if subtype ~= linelist_code then
                -- go on
            elseif getheight(n) == 0 and getdepth(n) == 0 then
                -- skip funny hlists -- todo: check line subtype
            else
                local a = lineisnumbered(n)
                if a then
                    if last_a ~= a then
                        local da = data[a]
                        local ma = da.method
                        if ma == v_next then
                            skip = true
                        elseif ma == v_page then
                            da.start = 1 -- eventually we will have a normal counter
                        end
                        last_a = a
                        if trace_numbers then
                            report_lines("starting line number range %s: start %s, continue %s",a,da.start,da.continue or v_no)
                        end
                    end
                    if getattr(n,a_displaymath) then
                        -- this probably needs to be adapted !
                        if is_display_math(n) then
                            check_number(n,a,skip)
                        end
                    else
                     -- -- we now prevent nesting anyway .. maybe later we need to check again
                     -- local v = getattr(list,a_verbatimline)
                     -- if not v or v ~= last_v then
                     --     last_v = v
                            check_number(n,a,skip)
                     -- else
                     --     check_number(n,a,skip,true)
                     -- end
                    end
                    skip = false
                end
            end
        end
    end

    if nested == 0 then
        if list then
            check()
        end
    elseif nested == 1 then
        local id = getid(box)
        if id == vlist_code then
            if listisnumbered(list) then
                -- ok
            else
                list = findnumberedlist(list)
            end
        else -- hlist
            list = findnumberedlist(list)
        end
        if list then
            check()
        end
    elseif nested == 2 then
        list = findcolumngap(list)
        -- we assume we have a vlist
        if not list then
            return
        end
        for n in nextvlist, list do
            local p = properties[n]
            if p and p.columngap then
                if trace_numbers then
                    report_lines("found column gap %a",p.columngap)
                end
                list = getlist(n)
                if list then
                    check()
                end
            end
        end
    else
        -- bad call
    end
end

-- column attribute

function boxed.stage_two(n,m)
    if #current_list > 0 then
        m = m or lines.scratchbox
        local t  = { }
        local tn = 0
        for l in nexthlist, getlist(getbox(m)) do
            tn = tn + 1
            t[tn] = copy_node(l) -- use take_box instead
        end
        for i=1,#current_list do
            local li = current_list[i]
            local n  = li[1]
            local m  = li[2]
            local ti = t[i]
            if ti then
             -- local d = getdirection(n)
             -- local l = getlist(n)
             -- if d == 1 then
             --     local w = getwidth(n)
             --     ti = hpack_nodes(linked_nodes(new_kern(-w),ti,new_kern(w)))
             -- end
             -- setnext(ti,l)
             -- setprev(l,ti)
             -- setlist(n,ti)
                addtoline(n,ti)
                resolve(n,m)
            else
                report_lines("error in linenumbering (1)")
                return
            end
       end
    end
end

-- function boxed.stage_zero(n) -- not used
--     return identify(getlist(getbox(n)))
-- end

implement {
    name      = "linenumbersstageone",
    actions   = boxed.stage_one,
    arguments = { "integer", "integer" }
}

implement {
    name      = "linenumbersstagetwo",
    actions   = boxed.stage_two,
    arguments = { "integer", "integer" }
}
