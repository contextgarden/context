if not modules then modules = { } end modules ['strc-mar'] = {
    version   = 1.001,
    comment   = "companion to strc-mar.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: cleanup stack (structures.marks.reset(v_all) also does the job)
-- todo: only commands.* print to tex, native marks return values

local insert, concat = table.insert, table.concat
local tostring, next, rawget, type = tostring, next, rawget, type
local lpegmatch = lpeg.match

local context             = context
local commands            = commands

local implement           = interfaces.implement

local allocate            = utilities.storage.allocate
local setmetatableindex   = table.setmetatableindex

local nuts                = nodes.nuts
local tonut               = nuts.tonut

local getid               = nuts.getid
local getlist             = nuts.getlist
local getattr             = nuts.getattr
local getbox              = nuts.getbox

local nextnode            = nuts.traversers.node

local nodecodes           = nodes.nodecodes
local whatsitcodes        = nodes.whatsitcodes

local glyph_code          = nodecodes.glyph
local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local whatsit_code        = nodecodes.whatsit

local lateluawhatsit_code = whatsitcodes.latelua

local texsetattribute     = tex.setattribute

local a_marks             = attributes.private("structure","marks")

local trace_set     = false  trackers.register("marks.set",     function(v) trace_set     = v end)
local trace_get     = false  trackers.register("marks.get",     function(v) trace_get     = v end)
local trace_details = false  trackers.register("marks.details", function(v) trace_details = v end)

local report_marks        = logs.reporter("structure","marks")

local variables           = interfaces.variables

local v_first             = variables.first
local v_last              = variables.last
local v_previous          = variables.previous
local v_next              = variables.next
local v_top               = variables.top
local v_bottom            = variables.bottom
local v_current           = variables.current
local v_default           = variables.default
local v_page              = variables.page
local v_all               = variables.all
local v_keep              = variables.keep

local v_nocheck_suffix    = ":" .. variables.nocheck

local v_first_nocheck     = variables.first    .. v_nocheck_suffix
local v_last_nocheck      = variables.last     .. v_nocheck_suffix
local v_previous_nocheck  = variables.previous .. v_nocheck_suffix
local v_next_nocheck      = variables.next     .. v_nocheck_suffix
local v_top_nocheck       = variables.top      .. v_nocheck_suffix
local v_bottom_nocheck    = variables.bottom   .. v_nocheck_suffix

local structures          = structures
local marks               = structures.marks
local lists               = structures.lists

local settings_to_array   = utilities.parsers.settings_to_array

local boxes_too           = false -- at some point we can also tag boxes or use a zero char

directives.register("marks.boxestoo", function(v) boxes_too = v end)

local data = marks.data or allocate()
marks.data = data

storage.register("structures/marks/data", marks.data, "structures.marks.data")

local stack, topofstack = { }, 0

local ranges = {
    [v_page] = {
        first = 0,
        last  = 0,
    },
}

local function resolve(t,k)
    if k then
        if trace_set or trace_get then
            report_marks("undefined mark, name %a",k)
        end
        local crap = { autodefined = true } -- maybe set = 0 and reset = 0
        t[k] = crap
        return crap
    else
        -- weird: k is nil
    end
end

setmetatableindex(data, resolve)

function marks.exists(name)
    return rawget(data,name) ~= nil
end

-- identify range

local function sweep(head,first,last)
    for n, id, subtype in nextnode, head do
        -- we need to handle empty heads so we test for latelua
        if id == glyph_code or (id == whatsit_code and subtype == lateluawhatsit_code) then
            local a = getattr(n,a_marks)
            if not a then
                -- next
            elseif first == 0 then
                first, last = a, a
            elseif a > last then
                last = a
            end
        elseif id == hlist_code or id == vlist_code then
            if boxes_too then
                local a = getattr(n,a_marks)
                if not a then
                    -- next
                elseif first == 0 then
                    first, last = a, a
                elseif a > last then
                    last = a
                end
            end
            local list = getlist(n)
            if list then
                first, last = sweep(list,first,last)
            end
        end
    end
    return first, last
end

local classes = { }

setmetatableindex(classes, function(t,k) local s = settings_to_array(k) t[k] = s return s end)

local lasts = { }

function marks.synchronize(class,n,option)
    local box = getbox(n)
    if box then
        local first, last = sweep(getlist(box),0,0)
        if option == v_keep and first == 0 and last == 0 then
            if trace_get or trace_set then
                report_marks("action %a, class %a, box %a","retain at synchronize",class,n)
            end
            -- todo: check if still valid firts/last in range
            first = lasts[class] or 0
            last = first
        else
            lasts[class] = last
            local classlist = classes[class]
            for i=1,#classlist do
                local class = classlist[i]
                local range = ranges[class]
                if range then
                    range.first = first
                    range.last  = last
                else
                    range = {
                        first = first,
                        last  = last,
                    }
                    ranges[class] = range
                end
                if trace_get or trace_set then
                    report_marks("action %a, class %a, first %a, last %a","synchronize",class,range.first,range.last)
                end
            end
        end
    elseif trace_get or trace_set then
        report_marks("action %s, class %a, box %a","synchronize without content",class,n)
    end
end

-- define etc

local function resolve(t,k)
    if k == "fullchain" then
        local fullchain = { }
        local chain = t.chain
        while chain and chain ~= "" do
            insert(fullchain,1,chain)
            chain = data[chain].chain
        end
        t[k] = fullchain
        return fullchain
    elseif k == "chain" then
        t[k] = ""
        return ""
    elseif k == "reset" or k == "set" then
        t[k] = 0
        return 0
    elseif k == "parent" then
        t[k] = false
        return false
    end
end

function marks.define(name,settings)
    if not settings then
        settings = { }
    elseif type(settings) == "string" then
        settings = { parent = settings }
    end
    data[name] = settings
    local parent = settings.parent
    if parent == nil or parent == "" or parent == name then
        settings.parent = false
    else
        local dp = data[parent]
        if not dp then
            settings.parent = false
        elseif dp.parent then
            settings.parent = dp.parent
        end
    end
    setmetatableindex(settings, resolve)
end

for k, v in next, data do
    setmetatableindex(v,resolve) -- runtime loaded table
end

local function parentname(name)
    local dn = data[name]
    return dn and dn.parent or name
end

function marks.relate(name,chain)
    local dn = data[name]
    if dn and not dn.parent then
        if chain and chain ~= "" then
            dn.chain = chain
            local dc = data[chain]
            if dc then
                local children = dc.children
                if not children then
                    children = { }
                    dc.children = children
                end
                children[#children+1] = name
            end
        elseif trace_set then
            report_marks("error: invalid relation, name %a, chain %a",name,chain)
        end
    end
end

local function resetchildren(new,name)
    local dn = data[name]
    if dn and not dn.parent then
        local children = dn.children
        if children then
            for i=1,#children do
                local ci = children[i]
                new[ci] = false
                if trace_set then
                    report_marks("action %a, parent %a, child %a","reset",name,ci)
                end
                resetchildren(new,ci)
            end
        end
    end
end

function marks.set(name,value)
    local dn = data[name]
    if dn then
        local child = name
        local parent = dn.parent
        if parent then
            name = parent
            dn = data[name]
        end
        dn.set = topofstack
        if not dn.reset then
            dn.reset = 0 -- in case of selfdefined
        end
        local top = stack[topofstack]
        local new = { }
        if top then
            for k, v in next, top do
                local d = data[k]
                local r = d.reset or 0
                local s = d.set or 0
                if r <= topofstack and s < r then
                    new[k] = false
                else
                    new[k] = v
                end
            end
        end
        resetchildren(new,name)
        new[name] = value
        topofstack = topofstack + 1
        stack[topofstack] = new
        if trace_set then
            if name == child then
                report_marks("action %a, name %a, index %a, value %a","set",name,topofstack,value)
            else
                report_marks("action %a, parent %a, child %a, index %a, value %a","set",parent,child,topofstack,value)
            end
        end
        texsetattribute("global",a_marks,topofstack)
    end
end

local function reset(name)
    if v_all then
        if trace_set then
            report_marks("action %a","reset all")
        end
        stack = { }
        for name, dn in next, data do
            local parent = dn.parent
            if parent then
                dn.reset = 0
                dn.set = 0
            end
        end
    else
        local dn = data[name]
        if dn then
            local parent = dn.parent
            if parent then
                name = parent
                dn = data[name]
            end
            if trace_set then
                report_marks("action %a, name %a, index %a","reset",name,topofstack)
            end
            dn.reset = topofstack
            local children = dn.children
            if children then
                for i=1,#children do
                    local ci = children[i]
                    reset(ci)
                end
            end
        end
    end
end

marks.reset = reset

function marks.get(n,name,value)
    local dn = data[name]
    if dn then
        name = dn.parent or name
        local top = stack[n]
        if top then
            context(top[name])
        end
    end
end

function marks.show(first,last)
    if first and last then
        for k=first,last do
            local v = stack[k]
            if v then
                report_marks("% 4i: %s",k,table.sequenced(v))
            end
        end
    else
        for k, v in table.sortedpairs(stack) do
            report_marks("% 4i: %s",k,table.sequenced(v))
        end
    end
end

local function resolve(name,first,last,strict,quitonfalse,notrace)
    local dn = data[name]
    if dn then
        local child = name
        local parent = dn.parent
        name = parent or child
        dn = data[name]
        local step, method
        if first > last then
            step, method = -1, "bottom-up"
        else
            step, method = 1, "top-down"
        end
        if trace_get and not notrace then
            report_marks("action %a, strategy %a, name %a, parent %a, strict %a","request",method,child,parent,strict or false)
        end
        if trace_details and not notrace then
            marks.show(first,last)
        end
        local r = dn.reset
        local s = dn.set
        if first <= last and first <= r then
            if trace_get and not notrace then
                report_marks("action %a, name %a, first %a, last %a, reset %a, index %a","reset first",name,first,last,r,first)
            end
        elseif first >= last and last <= r then
            if trace_get and not notrace then
                report_marks("action %a, name %a, first %a, last %a, reset %a, index %a","reset last",name,first,last,r,last)
            end
        elseif not stack[first] or not stack[last] then
            if trace_get and not notrace then
                -- a previous or next method can give an out of range, which is valid
                report_marks("error: out of range, name %a, reset %a, index %a",name,r,first)
            end
        elseif strict then
            local top = stack[first]
            local fullchain = dn.fullchain
            if not fullchain or #fullchain == 0 then
                if trace_get and not notrace then
                    report_marks("warning: no full chain, trying again, name %a, first %a, last %a",name,first,last)
                end
                return resolve(name,first,last)
            else
                if trace_get and not notrace then
                    report_marks("found chain [ % => T ]",fullchain)
                end
                local chaindata   = { }
                local chainlength = #fullchain
                for i=1,chainlength do
                    local cname = fullchain[i]
                    if data[cname].set > 0 then
                        local value = resolve(cname,first,last,false,false,true)
                        if value == "" then
                            if trace_get and not notrace then
                                report_marks("quitting chain, name %a, reset %a, start %a",name,r,first)
                            end
                            return ""
                        else
                            chaindata[i] = value
                        end
                    end
                end
                if trace_get and not notrace then
                    report_marks("using chain  [ % => T ]",chaindata)
                end
                local value, index, found = resolve(name,first,last,false,false,true)
                if value ~= ""  then
                    if trace_get and not notrace then
                        report_marks("following chain  [ % => T ]",chaindata)
                    end
                    for i=1,chainlength do
                        local cname = fullchain[i]
                        if data[cname].set > 0 and chaindata[i] ~= found[cname] then
                            if trace_get and not notrace then
                                report_marks("quiting chain, name %a, reset %a, index %a",name,r,first)
                            end
                            return ""
                        end
                    end
                    if trace_get and not notrace then
                        report_marks("found in chain, name %a, reset %a, start %a, index %a, value %a",name,r,first,index,value)
                    end
                    return value, index, found
                elseif trace_get and not notrace then
                    report_marks("not found, name %a, reset %a",name,r)
                end
            end
        else
            for i=first,last,step do
                local current = stack[i]
                local value = current and current[name]
                if value == nil then
                    -- search on
                elseif value == false then
                    if quitonfalse then
                        return ""
                    end
                elseif value == true then
                    if trace_get and not notrace then
                        report_marks("quitting steps, name %a, reset %a, start %a, index %a",name,r,first,i)
                    end
                    return ""
                elseif value ~= "" then
                    if trace_get and not notrace then
                        report_marks("found in steps, name %a, reset %a, start %a, index %a, value %a",name,r,first,i,value)
                    end
                    return value, i, current
                end
            end
            if trace_get and not notrace then
                report_marks("not found in steps, name %a, reset %a",name,r)
            end
        end
    end
    return ""
end

-- todo: column:first column:last

local methods  = { }

local function doresolve(name,rangename,swap,df,dl,strict)
    local range = ranges[rangename] or ranges[v_page]
    local first = range.first
    local last  = range.last
    if trace_get then
        report_marks("action %a, name %a, range %a, swap %a, first %a, last %a, df %a, dl %a, strict %a",
            "resolving",name,rangename,swap or false,first,last,df,dl,strict or false)
    end
    if swap then
        first, last = last + df, first + dl
    else
        first, last = first + df, last + dl
    end
    local value, index, found = resolve(name,first,last,strict)
    -- maybe something more
    return value, index, found
end

-- previous : last before sync
-- next     : first after sync

-- top      : first in sync
-- bottom   : last in sync

-- first    : first not top in sync
-- last     : last not bottom in sync

methods[v_previous]         = function(name,range) return doresolve(name,range,false,-1,0,true ) end -- strict
methods[v_top]              = function(name,range) return doresolve(name,range,false, 0,0,true ) end -- strict
methods[v_bottom]           = function(name,range) return doresolve(name,range,true , 0,0,true ) end -- strict
methods[v_next]             = function(name,range) return doresolve(name,range,true , 0,1,true ) end -- strict

methods[v_previous_nocheck] = function(name,range) return doresolve(name,range,false,-1,0,false) end
methods[v_top_nocheck]      = function(name,range) return doresolve(name,range,false, 0,0,false) end
methods[v_bottom_nocheck]   = function(name,range) return doresolve(name,range,true , 0,0,false) end
methods[v_next_nocheck]     = function(name,range) return doresolve(name,range,true , 0,1,false) end

local function do_first(name,range,check)
    if trace_get then
        report_marks("action %a, name %a, range %a","resolving first",name,range)
    end
    local f_value, f_index, f_found = doresolve(name,range,false,0,0,check)
    if f_found then
        if trace_get then
            report_marks("action %a, name %a, range %a","resolving last",name,range)
        end
        local l_value, l_index, l_found = doresolve(name,range,true ,0,0,check)
        if l_found and l_index > f_index then
            local name = parentname(name)
            for i=f_index,l_index,1 do
                local si = stack[i]
                local sn = si[name]
                if sn and sn ~= false and sn ~= true and sn ~= "" and sn ~= f_value then
                    if trace_get then
                        report_marks("action %a, name %a, range %a, index %a, value %a","resolving",name,range,i,sn)
                    end
                    return sn, i, si
                end
            end
        end
    end
    if trace_get then
        report_marks("resolved, name %a, range %a, using first",name,range)
    end
    return f_value, f_index, f_found
end

local function do_last(name,range,check)
    if trace_get then
        report_marks("action %a, name %a, range %a","resolving last",name,range)
    end
    local l_value, l_index, l_found = doresolve(name,range,true ,0,0,check)
    if l_found then
        if trace_get then
            report_marks("action %a, name %a, range %a","resolving first",name,range)
        end
        local f_value, f_index, f_found = doresolve(name,range,false,0,0,check)
        if f_found and l_index > f_index then
            local name = parentname(name)
            for i=l_index,f_index,-1 do
                local si = stack[i]
                local sn = si[name]
                if sn and sn ~= false and sn ~= true and sn ~= "" and sn ~= l_value then
                    if trace_get then
                        report_marks("action %a, name %a, range %a, index %a, value %a","resolving",name,range,i,sn)
                    end
                    return sn, i, si
                end
            end
        end
    end
    if trace_get then
        report_marks("resolved, name %a, range %a, using first",name,range)
    end
    return l_value, l_index, l_found
end

methods[v_first        ] = function(name,range) return do_first(name,range,true ) end
methods[v_last         ] = function(name,range) return do_last (name,range,true ) end
methods[v_first_nocheck] = function(name,range) return do_first(name,range,false) end
methods[v_last_nocheck ] = function(name,range) return do_last (name,range,false) end

methods[v_current] = function(name,range) -- range is ignored here
    local top = stack[topofstack]
    return top and top[parentname(name)] or ""
end

local function fetched(name,range,method)
    local value = (methods[method] or methods[v_first])(name,range) or ""
    if not trace_get then
        -- no report
    elseif value == "" then
        report_marks("nothing fetched, name %a, range %a, method %a",name,range,method)
    else
        report_marks("marking fetched, name %a, range %a, method %a, value %a",name,range,method,value)
    end
    return value or ""
end

-- can be used at the lua end:

marks.fetched = fetched

-- this will move to a separate runtime modules

marks.tracers = marks.tracers or { }

function marks.tracers.showtable()
    context.starttabulate { "|l|l|l|lp|lp|" }
    context.tabulaterowbold("name","parent","chain","children","fullchain")
    context.ML()
    for k, v in table.sortedpairs(data) do
        local parent    = v.parent    or ""
        local chain     = v.chain     or ""
        local children  = v.children  or { }
        local fullchain = v.fullchain or { }
        table.sort(children) -- in-place but harmless
        context.tabulaterowtyp(k,parent,chain,concat(children," "),concat(fullchain," "))
    end
    context.stoptabulate()
end

-- pushing to context:

-- local separator = context.nested.markingseparator
-- local command   = context.nested.markingcommand
-- local ctxconcat = context.concat

-- local function fetchonemark(name,range,method)
--     context(command(name,fetched(name,range,method)))
-- end

-- local function fetchtwomarks(name,range)
--     ctxconcat( {
--         command(name,fetched(name,range,v_first)),
--         command(name,fetched(name,range,v_last)),
--     }, separator(name))
-- end

-- local function fetchallmarks(name,range)
--     ctxconcat( {
--         command(name,fetched(name,range,v_previous)),
--         command(name,fetched(name,range,v_first)),
--         command(name,fetched(name,range,v_last)),
--     }, separator(name))
-- end

    local ctx_separator = context.markingseparator
    local ctx_command   = context.markingcommand

    local function fetchonemark(name,range,method)
        ctx_command(name,fetched(name,range,method))
    end

    local function fetchtwomarks(name,range)
        ctx_command(name,fetched(name,range,v_first))
        ctx_separator(name)
        ctx_command(name,fetched(name,range,v_last))
    end

    local function fetchallmarks(name,range)
        ctx_command(name,fetched(name,range,v_previous))
        ctx_separator(name)
        ctx_command(name,fetched(name,range,v_first))
        ctx_separator(name)
        ctx_command(name,fetched(name,range,v_last))
    end

function marks.fetch(name,range,method) -- chapter page first | chapter column:1 first
    if trace_get then
        report_marks("marking requested, name %a, range %a, method %a",name,range,method)
    end
    if method == "" or method == v_default then
        fetchonemark(name,range,v_first)
    elseif method == v_both then
        fetchtwomarks(name,range)
    elseif method == v_all then
        fetchallmarks(name,range)
    else
        fetchonemark(name,range,method)
    end
end

function marks.fetchonemark (name,range,method) fetchonemark (name,range,method) end
function marks.fetchtwomarks(name,range)        fetchtwomarks(name,range       ) end
function marks.fetchallmarks(name,range)        fetchallmarks(name,range       ) end

-- here we have a few helpers .. will become commands.*

local pattern = lpeg.afterprefix("li::")

function marks.title(tag,n)
    local listindex = lpegmatch(pattern,n)
    if listindex then
        commands.savedlisttitle(tag,listindex,"marking")
    else
        context(n)
    end
end

function marks.number(tag,n) -- no spec
    local listindex = lpegmatch(pattern,n)
    if listindex then
        commands.savedlistnumber(tag,listindex)
    else
        -- no prefix (as it is the prefix)
        context(n)
    end
end

-- interface

implement { name = "markingtitle",       actions = marks.title,         arguments = "2 strings" }
implement { name = "markingnumber",      actions = marks.number,        arguments = "2 strings" }

implement { name = "definemarking",      actions = marks.define,        arguments = "2 strings" }
implement { name = "relatemarking",      actions = marks.relate,        arguments = "2 strings" }
implement { name = "setmarking",         actions = marks.set,           arguments = "2 strings" }
implement { name = "resetmarking",       actions = marks.reset,         arguments = "string" }
implement { name = "synchronizemarking", actions = marks.synchronize,   arguments = { "string", "integer", "string" } }
implement { name = "getmarking",         actions = marks.fetch,         arguments = "3 strings" }
implement { name = "fetchonemark",       actions = marks.fetchonemark,  arguments = "3 strings" }
implement { name = "fetchtwomarks",      actions = marks.fetchtwomarks, arguments = "2 strings" }
implement { name = "fetchallmarks",      actions = marks.fetchallmarks, arguments = "2 strings" }

implement { name = "doifelsemarking",    actions = { marks.exists, commands.doifelse }, arguments = "string" }
