if not modules then modules = { } end modules ['math-tag'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- use lpeg matchers

local find, match = string.find, string.match
local insert, remove = table.insert, table.remove

local attributes          = attributes
local nodes               = nodes

local nuts                = nodes.nuts
local tonut               = nuts.tonut

local getnext             = nuts.getnext
local getid               = nuts.getid
local getchar             = nuts.getchar
local getlist             = nuts.getlist
local getfield            = nuts.getfield
local getattr             = nuts.getattr
local setattr             = nuts.setattr

local set_attributes      = nuts.setattributes
local traverse_nodes      = nuts.traverse

local nodecodes           = nodes.nodecodes

local math_noad_code      = nodecodes.noad           -- attr nucleus sub sup
local math_accent_code    = nodecodes.accent         -- attr nucleus sub sup accent
local math_radical_code   = nodecodes.radical        -- attr nucleus sub sup left degree
local math_fraction_code  = nodecodes.fraction       -- attr nucleus sub sup left right
local math_box_code       = nodecodes.subbox         -- attr list
local math_sub_code       = nodecodes.submlist       -- attr list
local math_char_code      = nodecodes.mathchar       -- attr fam char
local math_textchar_code  = nodecodes.mathtextchar   -- attr fam char
local math_delim_code     = nodecodes.delim          -- attr small_fam small_char large_fam large_char
local math_style_code     = nodecodes.style          -- attr style
local math_choice_code    = nodecodes.choice         -- attr display text script scriptscript
local math_fence_code     = nodecodes.fence          -- attr subtype

local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local glyph_code          = nodecodes.glyph
local glue_code           = nodecodes.glue

local a_tagged            = attributes.private('tagged')
local a_exportstatus      = attributes.private('exportstatus')
local a_mathcategory      = attributes.private('mathcategory')
local a_mathmode          = attributes.private('mathmode')

local tags                = structures.tags

local start_tagged        = tags.start
local restart_tagged      = tags.restart
local stop_tagged         = tags.stop
local taglist             = tags.taglist

local chardata            = characters.data

local getmathcode         = tex.getmathcode
local mathcodes           = mathematics.codes
local ordinary_code       = mathcodes.ordinary
local variable_code       = mathcodes.variable

local process

local function processsubsup(start)
    -- At some point we might need to add an attribute signaling the
    -- super- and subscripts because TeX and MathML use a different
    -- order.
    local nucleus = getfield(start,"nucleus")
    local sup     = getfield(start,"sup")
    local sub     = getfield(start,"sub")
    if sub then
        if sup then
            setattr(start,a_tagged,start_tagged("msubsup"))
            process(nucleus)
            process(sub)
            process(sup)
            stop_tagged()
        else
            setattr(start,a_tagged,start_tagged("msub"))
            process(nucleus)
            process(sub)
            stop_tagged()
        end
    elseif sup then
        setattr(start,a_tagged,start_tagged("msup"))
        process(nucleus)
        process(sup)
        stop_tagged()
    else
        process(nucleus)
    end
end

-- todo: check function here and keep attribute the same

-- todo: variants -> original

local actionstack = { }

process = function(start) -- we cannot use the processor as we have no finalizers (yet)
    while start do
        local id = getid(start)
        if id == math_char_code then
            local char = getchar(start)
            -- check for code
            local a = getattr(start,a_mathcategory)
            if a then
                a = { detail = a }
            end
            local code = getmathcode(char)
            if code then
                code = code[1]
            end
            local tag
            if code == ordinary_code or code == variable_code then
                local ch = chardata[char]
                local mc = ch and ch.mathclass
                if mc == "number" then
                    tag = "mn"
                elseif mc == "variable" or not mc then -- variable is default
                    tag = "mi"
                else
                    tag = "mo"
                end
            else
                tag = "mo"
            end
            setattr(start,a_tagged,start_tagged(tag,a))
            stop_tagged()
            break -- okay?
        elseif id == math_textchar_code then
            -- check for code
            local a = getattr(start,a_mathcategory)
            if a then
                setattr(start,a_tagged,start_tagged("ms",{ detail = a }))
            else
                setattr(start,a_tagged,start_tagged("ms"))
            end
            stop_tagged()
            break
        elseif id == math_delim_code then
            -- check for code
            setattr(start,a_tagged,start_tagged("mo"))
            stop_tagged()
            break
        elseif id == math_style_code then
            -- has a next
        elseif id == math_noad_code then
            processsubsup(start)
        elseif id == math_box_code or id == hlist_code or id == vlist_code then
            -- keep an eye on math_box_code and see what ends up in there
            local attr = getattr(start,a_tagged)
            local last = attr and taglist[attr]
            if last and find(last[#last],"formulacaption[:%-]") then
                -- leave alone, will nicely move to the outer level
            else
                local text = start_tagged("mtext")
                setattr(start,a_tagged,text)
                local list = getfield(start,"list")
                if not list then
                    -- empty list
                elseif not attr then
                    -- box comes from strange place
                    set_attributes(list,a_tagged,text)
                else
                    -- Beware, the first node in list is the actual list so we definitely
                    -- need to nest. This approach is a hack, maybe I'll make a proper
                    -- nesting feature to deal with this at another level. Here we just
                    -- fake structure by enforcing the inner one.
                    local tagdata = taglist[attr]
                    local common = #tagdata + 1
                    local function runner(list) -- quite inefficient
                        local cache = { } -- we can have nested unboxed mess so best local to runner
                        for n in traverse_nodes(list) do
                            local id = getid(n)
                            local aa = getattr(n,a_tagged)
                            if aa then
                                local ac = cache[aa]
                                if not ac then
                                    local tagdata = taglist[aa]
                                    local extra = #tagdata
                                    if common <= extra then
                                        for i=common,extra do
                                            ac = restart_tagged(tagdata[i]) -- can be made faster
                                        end
                                        for i=common,extra do
                                            stop_tagged() -- can be made faster
                                        end
                                    else
                                        ac = text
                                    end
                                    cache[aa] = ac
                                end
                                setattr(n,a_tagged,ac)
                            else
                                setattr(n,a_tagged,text)
                            end
                            if id == hlist_code or id == vlist_code then
                                runner(getlist(n))
                            end
                        end
                    end
                    runner(list)
                end
                stop_tagged()
            end
        elseif id == math_sub_code then
            local list = getfield(start,"list")
            if list then
                local attr = getattr(start,a_tagged)
                local last = attr and taglist[attr]
                local action = last and match(last[#last],"maction:(.-)%-")
                if action and action ~= "" then
                    if actionstack[#actionstack] == action then
                        setattr(start,a_tagged,start_tagged("mrow"))
                        process(list)
                        stop_tagged()
                    else
                        insert(actionstack,action)
                        setattr(start,a_tagged,start_tagged("mrow",{ detail = action }))
                        process(list)
                        stop_tagged()
                        remove(actionstack)
                    end
                else
                    setattr(start,a_tagged,start_tagged("mrow"))
                    process(list)
                    stop_tagged()
                end
            end
        elseif id == math_fraction_code then
            local num   = getfield(start,"num")
            local denom = getfield(start,"denom")
            local left  = getfield(start,"left")
            local right = getfield(start,"right")
            if left then
               setattr(left,a_tagged,start_tagged("mo"))
               process(left)
               stop_tagged()
            end
            setattr(start,a_tagged,start_tagged("mfrac"))
            process(num)
            process(denom)
            stop_tagged()
            if right then
                setattr(right,a_tagged,start_tagged("mo"))
                process(right)
                stop_tagged()
            end
        elseif id == math_choice_code then
            local display      = getfield(start,"display")
            local text         = getfield(start,"text")
            local script       = getfield(start,"script")
            local scriptscript = getfield(start,"scriptscript")
            if display then
                process(display)
            end
            if text then
                process(text)
            end
            if script then
                process(script)
            end
            if scriptscript then
                process(scriptscript)
            end
        elseif id == math_fence_code then
            local delim   = getfield(start,"delim")
            local subtype = getfield(start,"subtype")
         -- setattr(start,a_tagged,start_tagged("mfenced")) -- needs checking
            if subtype == 1 then
                -- left
                if delim then
                    setattr(start,a_tagged,start_tagged("mleft"))
                    process(delim)
                    stop_tagged()
                end
            elseif subtype == 2 then
                -- middle
                if delim then
                    setattr(start,a_tagged,start_tagged("mmiddle"))
                    process(delim)
                    stop_tagged()
                end
            elseif subtype == 3 then
                if delim then
                    setattr(start,a_tagged,start_tagged("mright"))
                    process(delim)
                    stop_tagged()
                end
            else
                -- can't happen
            end
         -- stop_tagged()
        elseif id == math_radical_code then
            local left   = getfield(start,"left")
            local degree = getfield(start,"degree")
            if left then
                start_tagged("ignore")
                process(left) -- root symbol, ignored
                stop_tagged()
            end
            if degree then -- not good enough, can be empty mlist
                setattr(start,a_tagged,start_tagged("mroot"))
                processsubsup(start)
                process(degree)
                stop_tagged()
            else
                setattr(start,a_tagged,start_tagged("msqrt"))
                processsubsup(start)
                stop_tagged()
            end
        elseif id == math_accent_code then
            local accent     = getfield(start,"accent")
            local bot_accent = getfield(start,"bot_accent")
            if bot_accent then
                if accent then
                    setattr(start,a_tagged,start_tagged("munderover",{ detail = "accent" }))
                    processsubsup(start)
                    process(bot_accent)
                    process(accent)
                    stop_tagged()
                else
                    setattr(start,a_tagged,start_tagged("munder",{ detail = "accent" }))
                    processsubsup(start)
                    process(bot_accent)
                    stop_tagged()
                end
            elseif accent then
                setattr(start,a_tagged,start_tagged("mover",{ detail = "accent" }))
                processsubsup(start)
                process(accent)
                stop_tagged()
            else
                processsubsup(start)
            end
        elseif id == glue_code then
            setattr(start,a_tagged,start_tagged("mspace"))
            stop_tagged()
        else
            setattr(start,a_tagged,start_tagged("merror", { detail = nodecodes[i] }))
            stop_tagged()
        end
        start = getnext(start)
    end
end

function noads.handlers.tags(head,style,penalties)
    head = tonut(head)
    local v_math = start_tagged("math")
    local v_mrow = start_tagged("mrow")
    local v_mode = getattr(head,a_mathmode)
 -- setattr(head,a_tagged,v_math)
    setattr(head,a_tagged,v_mrow)
    tags.setattributehash(v_math,"mode",v_mode == 1 and "display" or "inline")
    process(head)
    stop_tagged()
    stop_tagged()
    return true
end
