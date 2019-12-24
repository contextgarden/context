if not modules then modules = { } end modules ['node-pro'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_callbacks  = false  trackers  .register("nodes.callbacks",        function(v) trace_callbacks  = v end)
local force_processors = false  directives.register("nodes.processors.force", function(v) force_processors = v end)

local report_nodes = logs.reporter("nodes","processors")

local nodes        = nodes
local tasks        = nodes.tasks
local nuts         = nodes.nuts
local tonut        = nodes.tonut

nodes.processors   = nodes.processors or { }
local processors   = nodes.processors

-- vbox: grouptype: vbox vtop output split_off split_keep  | box_type: exactly|aditional
-- hbox: grouptype: hbox adjusted_hbox(=hbox_in_vmode)     | box_type: exactly|aditional

local actions = tasks.actions("processors")

do

    local isglyph = nuts.isglyph
    local getnext = nuts.getnext

    local utfchar = utf.char
    local concat  = table.concat

    local n = 0

    local function reconstruct(head) -- we probably have a better one
        local t, n, h = { }, 0, head
        while h do
            n = n + 1
            local char, id = isglyph(h)
            if char then -- todo: disc etc
                t[n] = utfchar(char)
            else
                t[n] = "[]"
            end
            h = getnext(h)
        end
        return concat(t)
    end

    function processors.tracer(what,head,groupcode,before,after,show)
        if not groupcode then
            groupcode = "unknown"
        elseif groupcode == "" then
            groupcode = "mvl"
        end
        n = n + 1
        if show then
            report_nodes("%s: location %a, group %a, # before %a, # after %s, stream: %s",what,n,groupcode,before,after,reconstruct(head))
        else
            report_nodes("%s: location %a, group %a, # before %a, # after %s",what,n,groupcode,before,after)
        end
    end

end

processors.enabled = true -- this will become a proper state (like trackers)

do

    local has_glyph   = nodes.has_glyph
    local count_nodes = nodes.countall

    local texget      = tex.get

    local tracer      = processors.tracer

    local function pre_linebreak_filter(head,groupcode)
        local found = force_processors or has_glyph(head)
        if found then
            if trace_callbacks then
                local before = count_nodes(head,true)
                head = actions(head,groupcode)
                local after = count_nodes(head,true)
                tracer("pre_linebreak",head,groupcode,before,after,true)
            else
                head = actions(head,groupcode)
            end
        elseif trace_callbacks then
            local n = count_nodes(head,false)
            tracer("pre_linebreak",head,groupcode,n,n)
        end
        return head
    end

    local function hpack_filter(head,groupcode,size,packtype,direction,attributes)
        local found = force_processors or has_glyph(head)
        if found then
            --
            -- yes or no or maybe an option
            --
            if not direction then
                direction = texget("textdir")
            end
            --
            if trace_callbacks then
                local before = count_nodes(head,true)
                head = actions(head,groupcode,size,packtype,direction,attributes)
                local after = count_nodes(head,true)
                tracer("hpack",head,groupcode,before,after,true)
            else
                head = actions(head,groupcode,size,packtype,direction,attributes)
            end
        elseif trace_callbacks then
            local n = count_nodes(head,false)
            tracer("hpack",head,groupcode,n,n)
        end
        return head
    end

    processors.pre_linebreak_filter = pre_linebreak_filter
    processors.hpack_filter         = hpack_filter

    do

        local hpack = nodes.hpack

        function nodes.fullhpack(head,...)
            return hpack((hpack_filter(head)),...)
        end

    end

    do

        local hpack = nuts.hpack

        function nuts.fullhpack(head,...)
            return hpack(tonut(hpack_filter(tonode(head))),...)
        end

    end

    callbacks.register('pre_linebreak_filter', pre_linebreak_filter, "horizontal manipulations (before par break)")
    callbacks.register('hpack_filter'        , hpack_filter,         "horizontal manipulations (before hbox creation)")

end

do
    -- Beware, these are packaged boxes so no first_glyph test needed. Maybe some day I'll add a hash
    -- with valid groupcodes. Watch out, much can pass twice, for instance vadjust passes two times,

    local actions     = tasks.actions("finalizers") -- head, where
    local count_nodes = nodes.countall

    local tracer      = processors.tracer

    local function post_linebreak_filter(head,groupcode)
        if trace_callbacks then
            local before = count_nodes(head,true)
            head = actions(head,groupcode)
            local after = count_nodes(head,true)
            tracer("post_linebreak",head,groupcode,before,after,true)
        else
            head = actions(head,groupcode)
        end
        return head
    end

    processors.post_linebreak_filter = post_linebreak_filter

    callbacks.register("post_linebreak_filter", post_linebreak_filter,"horizontal manipulations (after par break)")

end

do

    ----- texnest       = tex.nest
    local getnest       = tex.getnest

    local getlist       = nuts.getlist
    local setlist       = nuts.setlist
    local getsubtype    = nuts.getsubtype

    local linelist_code = nodes.listcodes.line

    local actions       = tasks.actions("contributers")

    function processors.contribute_filter(groupcode)
        if groupcode == "box" then -- "pre_box"
            local whatever = getnest()
            if whatever then
                local line = whatever.tail
                if line then
                    line = tonut(line)
                    if getsubtype(line) == linelist_code then
                        local head = getlist(line)
                        if head then
                            local result = actions(head,groupcode,line)
                            if result and result ~= head then
                                setlist(line,result)
                            end
                        end
                    end
                end
            end
        end
    end

    callbacks.register("contribute_filter", processors.contribute_filter,"things done with lines")

end

statistics.register("h-node processing time", function()
    return statistics.elapsedseconds(nodes,"including kernel") -- hm, ok here?
end)
