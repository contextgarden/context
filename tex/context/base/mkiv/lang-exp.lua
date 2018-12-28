if not modules then modules = { } end modules ['lang-exp'] = {
    version   = 1.001,
    comment   = "companion to lang-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module contains snippets that were used before we expanded
-- discretionaries in the engine which makes way more sense. This
-- code is nod used any more.

if true then
    return
end

-- lang-dis.lua:

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

if LUATEXVERSION < 1.005 then -- not loaded any more

    -- some shortcuts go here

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

-- lang-hyp.lua:

----- expanders          = languages.expanders -- gone in 1.005
----- expand_explicit    = expanders and expanders[explicit_code]
----- expand_automatic   = expanders and expanders[automatic_code]

-- if LUATEXVERSION < 1.005 then -- not loaded any more
--
--     expanded = function(head)
--         local done = hyphenate(head)
--         if done then
--             for d in traverse_id(disc_code,head) do
--                 local s = getsubtype(d)
--                 if s ~= discretionary_code then
--                     expanders[s](d,template)
--                     done = true
--                 end
--             end
--         end
--         return head, done
--     end
--
-- end

--                 if id == disc_code then
--                     if expanded then
--                         -- pre 1.005
--                         local subtype = getsubtype(current)
--                         if subtype == discretionary_code then -- \discretionary
--                             size = 0
--                         elseif subtype == explicit_code then -- \- => only here
--                             -- automatic (-) : the old parser makes negative char entries
--                             size = 0
--                             expand_explicit(current)
--                         elseif subtype == automatic_code then -- - => only here
--                             -- automatic (-) : the old hyphenator turns an exhyphen into glyph+disc
--                             size = 0
--                             expand_automatic(current)
--                         else
--                             -- first         : done by the hyphenator
--                             -- second        : done by the hyphenator
--                             -- regular       : done by the hyphenator
--                             size = 0
--                         end
--                     else
--                         size = 0
--                     end
--                     current = getnext(current)
--                     if hyphenonly then
--                         skipping = true
--                     end
