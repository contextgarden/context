if not modules then modules = { } end modules ['typo-rub'] = {
    version   = 1.001,
    comment   = "companion to typo-rub.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: recycle slots better
-- todo: hoffset
-- todo: auto-increase line height
-- todo: only hpack when start <> stop

-- A typical bit of afternoon hackery ... with some breaks for watching
-- Ghost-Note on youtube (Robert Searight and Nate Werth) ... which expands
-- my to-be-had cd/dvd list again.

local lpegmatch         = lpeg.match
local utfcharacters     = utf.characters
local setmetatableindex = table.setmetatableindex

local variables       = interfaces.variables
local implement       = interfaces.implement

local texsetattribute = tex.setattribute

local v_flushleft     = variables.flushleft
local v_middle        = variables.middle
local v_flushright    = variables.flushright
local v_yes           = variables.yes
local v_no            = variables.no
local v_auto          = variables.auto

local nuts            = nodes.nuts

local getid           = nuts.getid
local getsubtype      = nuts.getsubtype
local getattr         = nuts.getattr
local setattr         = nuts.setattr
local getnext         = nuts.getnext
local setnext         = nuts.setnext
local getprev         = nuts.getprev
local setprev         = nuts.setprev
local setlink         = nuts.setlink
local getlist         = nuts.getlist
local setlist         = nuts.setlist
local setshift        = nuts.setshift
local getwidth        = nuts.getwidth
local setwidth        = nuts.setwidth

local hpack           = nuts.hpack
local insert_after    = nuts.insert_after
local takebox         = nuts.takebox

local nexthlist       = nuts.traversers.hlist
local nextvlist       = nuts.traversers.vlist

local nodecodes       = nodes.nodecodes
local glyph_code      = nodecodes.glyph
local disc_code       = nodecodes.disc
local kern_code       = nodecodes.kern
local glue_code       = nodecodes.glue
local penalty_code    = nodecodes.penalty
local hlist_code      = nodecodes.hlist
local vlist_code      = nodecodes.vlist
local localpar_code   = nodecodes.localpar
local dir_code        = nodecodes.dir

local kerncodes       = nodes.kerncodes
local fontkern_code   = kerncodes.font

local nodepool        = nuts.pool
local new_kern        = nodepool.kern

local setprop         = nuts.setprop
local getprop         = nuts.getprop

local enableaction    = nodes.tasks.enableaction

local nofrubies       = 0
local rubylist        = { }

local a_ruby          = attributes.private("ruby")

local rubies          = { }
typesetters.rubies    = rubies

local trace_rubies    = false  trackers.register("typesetters.rubies",function(v) trace_rubies = v end)
local report_rubies   = logs.reporter("rubies")

do

    local shared   = nil
    local splitter = lpeg.tsplitat("|")

    local function enable()
        enableaction("processors","typesetters.rubies.check")
        enableaction("shipouts",  "typesetters.rubies.attach")
        enable = false
    end

    local ctx_setruby = context.core.setruby

    local function ruby(settings)
        local base    = settings.base
        local comment = settings.comment
        shared = settings
        local c = lpegmatch(splitter,comment)
        if #c == 1 then
            ctx_setruby(base,comment)
            if trace_rubies then
                report_rubies("- %s -> %s",base,comment)
            end
        else
            local i = 0
            for b in utfcharacters(base) do
                i = i + 1
                local r = c[i]
                if r then
                    ctx_setruby(b,r)
                    if trace_rubies then
                        report_rubies("%i: %s -> %s",i,b,r)
                    end
                else
                    ctx_setruby(b,"")
                    if trace_rubies then
                        report_rubies("%i: %s",i,b)
                    end
                end
            end
        end
        if enable then
            enable()
        end
    end

    local function startruby(settings)
        shared = settings
        if enable then
            enable()
        end
    end

    implement {
        name      = "ruby",
        actions   = ruby,
        arguments = {
            {
                { "align" },
                { "stretch" },
                { "hoffset", "dimension" },
                { "voffset", "dimension" },
                { "comment" },
                { "base" },
            }
        },
    }

    implement {
        name      = "startruby",
        actions   = startruby,
        arguments = {
            {
                { "align" },
                { "stretch" },
                { "hoffset", "dimension" },
                { "voffset", "dimension" },
            }
        },
    }

    local function setruby(n,m)
        nofrubies = nofrubies + 1
        local r = takebox(n)
        rubylist[nofrubies] = setmetatableindex({
            text      = r,
            width     = getwidth(r),
            basewidth = 0,
            start     = false,
            stop      = false,
        }, shared)
        texsetattribute(a_ruby,nofrubies)
    end

    implement {
        name      = "setruby",
        actions   = setruby,
        arguments = "integer",
    }

end

function rubies.check(head)
    local current = head
    local start   = nil
    local stop    = nil
    local found   = nil

    local function flush(where)
        local r = rubylist[found]
        if r then
            local prev = getprev(start)
            local next = getnext(stop)
            setprev(start)
            setnext(stop)
            local h = hpack(start)
            if start == head then
                head = h
            else
                setlink(prev,h)
            end
            setlink(h,next)
            local bwidth = getwidth(h)
            local rwidth = r.width
            r.basewidth  = bwidth
            r.start      = start
            r.stop       = stop
            setprop(h,"ruby",found)
            if rwidth > bwidth then
                -- ruby is wider
                setwidth(h,rwidth)
            end
        end
    end

    while current do
        local nx = getnext(current)
        local id = getid(current)
        if id == glyph_code then
            local a  = getattr(current,a_ruby)
            if not a then
                if found then
                    flush("flush 1")
                    found = nil
                end
            elseif a == found then
                stop = current
            else
                if found then
                    flush("flush 2")
                end
                found = a
                start = current
                stop  = current
            end
            -- go on
        elseif id == kern_code and getsubtype(current,fontkern_code) then
            -- go on
        elseif found and id == disc_code then
            -- go on (todo: look into disc)
        elseif found then
            flush("flush 3")
            found = nil
        end
        current = nx
    end
    if found then
        flush("flush 4")
    end
    return head, true -- no need for true
end

local attach

local function whatever(current)
    local a = getprop(current,"ruby")
    if a then
        local ruby    = rubylist[a]
        local align   = ruby.align   or v_middle
        local stretch = ruby.stretch or v_no
        local hoffset = ruby.hoffset or 0
        local voffset = ruby.voffset or 0
        local start   = ruby.start
        local stop    = ruby.stop
        local text    = ruby.text
        local rwidth  = ruby.width
        local bwidth  = ruby.basewidth
        local delta   = rwidth - bwidth
        setwidth(text,0)
        if voffset ~= 0 then
            setshift(text,voffset)
        end
        -- center them
        if delta > 0 then
            -- ruby is wider
            if stretch == v_yes then
                setlink(text,start)
                while start and start ~= stop do
                    local s = nodepool.stretch()
                    local n = getnext(start)
                    setlink(start,s,n)
                    start = n
                end
                text = hpack(text,rwidth,"exactly")
            else
                local left  = new_kern(delta/2)
                local right = new_kern(delta/2)
                setlink(text,left,start)
                setlink(stop,right)
            end
            setlist(current,text)
        elseif delta < 0 then
            -- ruby is narrower
            if align == v_auto then
                local l = true
                local c = getprev(current)
                while c do
                    local id = getid(c)
                    if id == glue_code or id == penalty_code or id == kern_code then
                        -- go on
                    elseif id == hlist_code and getwidth(c) == 0 then
                        -- go on
                    elseif id == whatsit_code or id == localpar_code or id == dir_code then
                        -- go on
                    else
                        l = false
                        break
                    end
                    c = getprev(c)
                end
                local r = true
                local c = getnext(current)
                while c do
                    local id = getid(c)
                    if id == glue_code or id == penalty_code or id == kern_code then
                        -- go on
                    elseif id == hlist_code and getwidth(c) == 0 then
                        -- go on
                    else
                        r = false
                        break
                    end
                    c = getnext(c)
                end
                if l and not r then
                    align = v_flushleft
                elseif r and not l then
                    align = v_flushright
                else
                    align = v_middle
                end
            end
            if align == v_flushleft then
                setlink(text,start)
                setlist(current,text)
            elseif align == v_flushright then
                local left  = new_kern(-delta)
                local right = new_kern(delta)
                setlink(left,text,right,start)
                setlist(current,left)
            else
                local left  = new_kern(-delta/2)
                local right = new_kern(delta/2)
                setlink(left,text,right,start)
                setlist(current,left)
            end
        else
            setlink(text,start)
            setlist(current,text)
        end
        setprop(current,"ruby",false)
        rubylist[a] = nil
    else
        local list = getlist(current)
        if list then
            attach(list)
        end
    end
end

attach = function(head) -- traverse_list
    for current in nexthlist, head do
        whatever(current)
    end
    for current in nextvlist, head do
        whatever(current)
    end
    return head
end

rubies.attach = attach

-- for now there is no need to be compact

-- local data          = { }
-- rubies.data         = data
--
-- function rubies.define(settings)
--     data[#data+1] = settings
--     return #data
-- end
--
-- implement {
--     name      = "defineruby",
--     actions   = { rubies.define, context },
--     arguments = {
--         {
--             { "align" },
--             { "stretch" },
--         }
--     }
-- }
