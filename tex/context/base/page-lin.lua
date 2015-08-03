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

local nodecodes          = nodes.nodecodes
local skipcodes          = nodes.skipcodes
local whatcodes          = nodes.whatcodes

local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local whatsit_code       = nodecodes.whatsit
local glue_code          = nodecodes.glue
local glyph_code         = nodecodes.glyph
local leftskip_code      = skipcodes.leftskip
local textdir_code       = whatcodes.dir

local a_displaymath      = attributes.private('displaymath')
local a_linenumber       = attributes.private('linenumber')
local a_linereference    = attributes.private('linereference')
local a_verbatimline     = attributes.private('verbatimline')

local current_list       = { }
local cross_references   = { }
local chunksize          = 250 -- not used in boxed

local nuts               = nodes.nuts

local getid              = nuts.getid
local getsubtype         = nuts.getsubtype
local getnext            = nuts.getnext
local getattr            = nuts.getattr
local getlist            = nuts.getlist
local getbox             = nuts.getbox
local getfield           = nuts.getfield

local setfield           = nuts.setfield

local traverse_id        = nuts.traverse_id
local traverse           = nuts.traverse
local copy_node          = nuts.copy
local hpack_nodes        = nuts.hpack
local linked_nodes       = nuts.linked
local insert_node_after  = nuts.insert_after
local insert_node_before = nuts.insert_before
local is_display_math    = nuts.is_display_math
local leftmarginwidth    = nuts.leftmarginwidth

local nodepool           = nuts.pool
local negated_glue       = nodepool.negatedglue
local new_hlist          = nodepool.hlist
local new_kern           = nodepool.kern

local ctx_convertnumber  = context.convertnumber
local ctx_makelinenumber = context.makelinenumber

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
        local tag, skipflag, s = d.tag or "", 0, d.start or 1
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
        ctx_makelinenumber(tag,skipflag,s,getfield(n,"shift"),getfield(n,"width"),leftmarginwidth(getlist(n)),getfield(n,"dir"))
    end
end

-- xlist
--   xlist
--     hlist

local function identify(list)
    if list then
        for n in traverse_id(hlist_code,list) do
            local a = getattr(n,a_linenumber)
            if a then
                return list, a
            end
        end
        local n = list
        while n do
            local id = getid(n)
            if id == hlist_code or id == vlist_code then
                local ok, a = identify(getlist(n))
                if ok then
                    return ok, a
                end
            end
            n = getnext(n)
        end
    end
end

function boxed.stage_zero(n)
    return identify(getlist(getbox(n)))
end

-- reset ranges per page
-- store first and last per page
-- maybe just set marks directly

function boxed.stage_one(n,nested)
    current_list = { }
    local box = getbox(n)
    if box then
        local found = nil
        local list  = getlist(box)
        if list and nested then
            list, found = identify(list)
        end
        if list then
            local last_a, last_v, skip = nil, -1, false
            for n in traverse_id(hlist_code,list) do -- attr test here and quit as soon as zero found
                if getfield(n,"height") == 0 and getfield(n,"depth") == 0 then
                    -- skip funny hlists -- todo: check line subtype
                else
                    local list = getlist(n)
                    local a = getattr(list,a_linenumber)
                    if not a or a == 0 then
                        local n = getnext(list)
                        while n do
                            local id = getid(n)
                            if id == whatsit_code and getsubtype(n) == textdir_code then
                                n = getnext(n)
                            elseif id == glue_code and getsubtype(n) == leftskip_code then
                                n = getnext(n)
                            elseif id == glyph_code then
                                break
                            else
                                -- can be hlist or skip (e.g. footnote line)
                                n = getnext(n)
                            end
                        end
                        a = n and getattr(n,a_linenumber)
                    end
                    if a and a > 0 then
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
                            if is_display_math(n) then
                                check_number(n,a,skip)
                            end
                        else
                            local v = getattr(list,a_verbatimline)
                            if not v or v ~= last_v then
                                last_v = v
                                check_number(n,a,skip)
                            else
                                check_number(n,a,skip,true)
                            end
                        end
                        skip = false
                    end
                end
            end
        end
    end
end

-- todo: a general model for attaching stuff l/r

-- setfield(ti,"next",l)
-- setfield(l,"prev",ti)
-- local h = copy_node(n)
-- -- setfield(h,"dir","TLT")
-- setfield(h,"list",ti) -- the number
-- setfield(n,"list",h)

function boxed.stage_two(n,m)
    if #current_list > 0 then
        m = m or lines.scratchbox
        local t, tn = { }, 0
        for l in traverse_id(hlist_code,getlist(getbox(m))) do
            tn = tn + 1
            t[tn] = copy_node(l) -- use take_box instead
        end
        for i=1,#current_list do
            local li = current_list[i]
            local n, m, ti = li[1], li[2], t[i]
            if ti then
                local d = getfield(n,"dir")
                local l = getlist(n)
                if d == "TRT" then
                    local w = getfield(n,"width")
                    ti = hpack_nodes(linked_nodes(new_kern(-w),ti,new_kern(w)))
                end
                setfield(ti,"next",l)
                setfield(l,"prev",ti)
                setfield(n,"list",ti)
                resolve(n,m)
            else
                report_lines("error in linenumbering (1)")
                return
            end
       end
    end
end

implement {
    name      = "linenumbersstageone",
    actions   = boxed.stage_one,
    arguments = { "integer", "boolean" }
}

implement {
    name      = "linenumbersstagetwo",
    actions   = boxed.stage_two,
    arguments = { "integer", "integer" }
}
