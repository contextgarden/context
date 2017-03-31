if not modules then modules = { } end modules ['lang-dis'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat = table.concat

local nodes              = nodes

local tasks              = nodes.tasks
local nuts               = nodes.nuts

local enableaction       = tasks.enableaction
local setaction          = tasks.setaction

local tonode             = nuts.tonode
local tonut              = nuts.tonut

local getfield           = nuts.getfield
local setfield           = nuts.setfield
local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getfont            = nuts.getfont
local getattr            = nuts.getattr
local getsubtype         = nuts.getsubtype
local setsubtype         = nuts.setsubtype
local getchar            = nuts.getchar
local setchar            = nuts.setchar
local getdisc            = nuts.getdisc
local setdisc            = nuts.setdisc
local getlang            = nuts.setlang
local getboth            = nuts.getboth
local setlist            = nuts.setlist
local setlink            = nuts.setlink
local isglyph            = nuts.isglyph

local copy_node          = nuts.copy
local remove_node        = nuts.remove
local traverse_id        = nuts.traverse_id
local flush_list         = nuts.flush_list
local flush_node         = nuts.flush_node

local nodecodes          = nodes.nodecodes
local disccodes          = nodes.disccodes

local disc_code          = nodecodes.disc
local glyph_code         = nodecodes.glyph

local discretionary_code = disccodes.discretionary
local explicit_code      = disccodes.explicit
local automatic_code     = disccodes.automatic
local regular_code       = disccodes.regular

local a_visualize        = attributes.private("visualizediscretionary")
local setattribute       = tex.setattribute

local getlanguagedata    = languages.getdata

local check_regular      = true

local expanders -- this will go away

-- the penalty has been determined by the mode (currently we force 1):
--
-- 0 : exhyphenpenalty
-- 1 : hyphenpenalty
-- 2 : automatichyphenpenalty
--
-- following a - : the pre and post chars are already appended and set
-- so we have pre=preex and post=postex .. however, the previous
-- hyphen is already injected ... downside: the font handler sees this
-- so this is another argument for doing a hyphenation pass in context

if LUATEXVERSION < 1.005 then

    expanders = {
        [discretionary_code] = function(d,template)
            -- \discretionary
            return template
        end,
        [explicit_code] = function(d,template)
            -- \-
            local pre, post, replace = getdisc(d)
            local done = false
            if pre then
                local char = isglyph(pre)
                if char and char <= 0 then
                    done = true
                    flush_list(pre)
                    pre = nil
                end
            end
            if post then
                local char = isglyph(post)
                if char and char <= 0 then
                    done = true
                    flush_list(post)
                    post = nil
                end
            end
            if done then
                -- todo: take existing penalty
                setdisc(d,pre,post,replace,explicit_code,tex.exhyphenpenalty)
            else
                setsubtype(d,explicit_code)
            end
            return template
        end,
        [automatic_code] = function(d,template)
            local pre, post, replace = getdisc(d)
            if pre then
                -- we have a preex characters and want that one to replace the
                -- character in front which is the trigger
                if not template then
                    -- can there be font kerns already?
                    template = getprev(d)
                    if template and getid(template) ~= glyph_code then
                        template = getnext(d)
                        if template and getid(template) ~= glyph_code then
                            template = nil
                        end
                    end
                end
                if template then
                    local pseudohead = getprev(template)
                    if pseudohead then
                        while template ~= d do
                            pseudohead, template, removed = remove_node(pseudohead,template)
                            -- free old replace ?
                            replace = removed
                            -- break ?
                        end
                    else
                        -- can't happen
                    end
                    setdisc(d,pre,post,replace,automatic_code,tex.hyphenpenalty)
                else
                 -- print("lone regular discretionary ignored")
                end
            else
                setdisc(d,pre,post,replace,automatic_code,tex.hyphenpenalty)
            end
            return template
        end,
        [regular_code] = function(d,template)
            if check_regular then
                -- simple
                if not template then
                    -- can there be font kerns already?
                    template = getprev(d)
                    if template and getid(template) ~= glyph_code then
                        template = getnext(d)
                        if template and getid(template) ~= glyph_code then
                            template = nil
                        end
                    end
                end
                if template then
                    local language = template and getlang(template)
                    local data     = getlanguagedata(language)
                    local prechar  = data.prehyphenchar
                    local postchar = data.posthyphenchar
                    local pre, post, replace = getdisc(d) -- pre can be set
                    local done     = false
                    if prechar and prechar > 0 then
                        done = true
                        pre  = copy_node(template)
                        setchar(pre,prechar)
                    end
                    if postchar and postchar > 0 then
                        done = true
                        post = copy_node(template)
                        setchar(post,postchar)
                    end
                    if done then
                        setdisc(d,pre,post,replace,regular_code,tex.hyphenpenalty)
                    end
                else
                 -- print("lone regular discretionary ignored")
                end
                return template
            end
        end,
        [disccodes.first] = function()
            -- forget about them
        end,
        [disccodes.second] = function()
            -- forget about them
        end,
    }

    function languages.expand(d,template,subtype)
        if not subtype then
            subtype = getsubtype(d)
        end
        if subtype ~= discretionary_code then
            return expanders[subtype](d,template)
        end
    end

else

    function languages.expand()
        -- nothing to be fixed
    end

end

languages.expanders = expanders

-- -- -- -- --

local setlistcolor = nodes.tracers.colors.setlist

function languages.visualizediscretionaries(head)
    for d in traverse_id(disc_code,tonut(head)) do
        if getattr(d,a_visualize) then
            local pre, post, replace = getdisc(d)
            if pre then
                setlistcolor(pre,"darkred")
            end
            if post then
                setlistcolor(post,"darkgreen")
            end
            if replace then
                setlistcolor(replace,"darkblue")
            end
        end
    end
end

local enabled = false

function languages.showdiscretionaries(v)
    if v == false then
        setattribute(a_visualize,unsetvalue)
    else -- also nil
        if not enabled then
            enableaction("processors","languages.visualizediscretionaries")
            enabled = true
        end
        setattribute(a_visualize,1)
    end
end

interfaces.implement {
    name    = "showdiscretionaries",
    actions = languages.showdiscretionaries
}

local toutf = nodes.listtoutf

function languages.serializediscretionary(d) -- will move to tracer
    local pre, post, replace = getdisc(d)
    return string.formatters["{%s}{%s}{%s}"](
        pre     and toutf(pre)     or "",
        post    and toutf(post)    or "",
        replace and toutf(replace) or ""
    )
end

-- --

local wiped = 0

local function wipe(head,delayed)
    local p, n = getboth(delayed)
    local _, _, h, _, _, t = getdisc(delayed,true)
    if p or n then
        if h then
            setlink(p,h)
            setlink(t,n)
            setfield(delayed,"replace")
        else
            setlink(p,n)
        end
    end
    if head == delayed then
        head = h
    end
    wiped = wiped + 1
    flush_node(delayed)
    return head
end

function languages.flatten(head)
    local nuthead = tonut(head)
    local delayed = nil
    for d in traverse_id(disc_code,nuthead) do
        if delayed then
            nuthead = wipe(nuthead,delayed)
        end
        delayed = d
    end
    if delayed then
        return tonode(wipe(nuthead,delayed)), true
    else
        return head, false
    end
end

function languages.nofflattened()
    return wiped -- handy for testing
end

-- experiment

local flatten = languages.flatten
local getlist = nodes.getlist

nodes.handlers.flattenline = flatten

function nodes.handlers.flatten(head,where)
    if head and (where == "box" or where == "adjusted_hbox") then
        return flatten(head)
    end
    return true
end

directives.register("hyphenator.flatten",function(v)
    setaction("processors","nodes.handlers.flatten",v)
    setaction("contributers","nodes.handlers.flattenline",v)
end)
