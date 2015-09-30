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
local nodepool           = nuts.pool

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
local getchar            = nuts.getchar
local getdisc            = nuts.getdisc
local setdisc            = nuts.setdisc

local copy_node          = nuts.copy
local free_node          = nuts.free
local remove_node        = nuts.remove
local traverse_id        = nuts.traverse_id
local traverse_nodes     = nuts.traverse

local nodecodes          = nodes.nodecodes
local disccodes          = nodes.disccodes

local disc_code          = nodecodes.disc
local glyph_code         = nodecodes.glyph
local discretionary_code = disccodes.discretionary

local a_visualize        = attributes.private("visualizediscretionary")
local setattribute       = tex.setattribute

local getlanguagedata    = languages.getdata

local check_regular      = true

local expanders = {
    [disccodes.discretionary] = function(d,template)
        -- \discretionary
        return template
    end,
    [disccodes.explicit] = function(d,template)
        -- \-
        local pre, post, replace = getdisc(d)
        local done = false
        if pre and getid(pre) == glyph_code and getchar(pre) <= 0 then
            done = true
            pre  = nil
        end
        if post and getid(post) == glyph_code and getchar(post) <= 0 then
            done = true
            post = nil
        end
        if done then
            setdisc(d,pre,post,replace,discretionary_code,tex.exhyphenpenalty)
        end
        return template
    end,
    [disccodes.automatic] = function(d,template)
        -- following a - : the pre and post chars are already appended and set
        -- so we have pre=preex and post=postex .. however, the previous
        -- hyphen is already injected ... downside: the font handler sees this
        -- so this is another argument for doing a hyphenation pass in context
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
                setdisc(d,pre,post,replace,discretionary_code,tex.hyphenpenalty)
            else
             -- print("lone regular discretionary ignored")
            end
        else
            setdisc(d,pre,post,replace,discretionary_code,tex.hyphenpenalty)
        end
        return template
    end,
    [disccodes.regular] = function(d,template)
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
                local language = template and getfield(template,"lang")
                local data     = getlanguagedata(language)
                local prechar  = data.prehyphenchar
                local postchar = data.posthyphenchar
                local pre, post, replace = getdisc(d) -- pre can be set
                local done     = false
                if prechar and prechar > 0 then
                    done = true
                    pre  = copy_node(template)
                 -- setfield(pre,"char",prechar)
                    setchar(pre,prechar)
                end
                if postchar and postchar > 0 then
                    done = true
                    post = copy_node(template)
                 -- setfield(post,"char",postchar)
                    setchar(post,postchar)
                end
                if done then
                    setdisc(d,pre,post,replace,discretionary_code,tex.hyphenpenalty)
                end
            else
             -- print("lone regular discretionary ignored")
            end
            return template
        else
            -- maybe also set penalty here
            setfield(d,"subtype",discretionary_code)
        end
    end,
    [disccodes.first] = function()
        -- forget about them
    end,
    [disccodes.second] = function()
        -- forget about them
    end,
}

languages.expanders = expanders

function languages.expand(d,template,subtype)
    if not subtype then
        subtype = getsubtype(d)
    end
    if subtype ~= discretionary_code then
        return expanders[subtype](d,template)
    end
end

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
            nodes.tasks.enableaction("processors","languages.visualizediscretionaries")
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

