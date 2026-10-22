if not modules then modules = { } end modules ['lang-exp'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module contains snippets that were used before we expanded
-- discretionaries in the engine which makes way more sense. This
-- code is not used any more. It was pre 1.00.5 code.

if true then
    return
end

-- lang-dis.lua:

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

-- some shortcuts go here

local expanders = {
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
                flushlist(pre)
                pre = nil
            end
        end
        if post then
            local char = isglyph(post)
            if char and char <= 0 then
                done = true
                flushlist(post)
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
                local language = template and getlanguage(template)
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

languages.expanders = expanders

-- rest (even older) removed
