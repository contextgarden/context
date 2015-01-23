if not modules then modules = { } end modules ['math-tag'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: have a local list with local tags that then get appended

-- use lpeg matchers

local find, match = string.find, string.match
local insert, remove, concat = table.insert, table.remove, table.concat

local attributes          = attributes
local nodes               = nodes

local nuts                = nodes.nuts
local tonut               = nuts.tonut

local getnext             = nuts.getnext
local getid               = nuts.getid
local getchar             = nuts.getchar
local getlist             = nuts.getlist
local getfield            = nuts.getfield
local getsubtype          = nuts.getsubtype
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

local accentcodes         = nodes.accentcodes

local math_fixed_top      = accentcodes.fixedtop
local math_fixed_bottom   = accentcodes.fixedbottom
local math_fixed_both     = accentcodes.fixedboth

local kerncodes           = nodes.kerncodes

local fontkern_code       = kerncodes.fontkern

local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local glyph_code          = nodecodes.glyph
local disc_code           = nodecodes.disc
local glue_code           = nodecodes.glue
local kern_code           = nodecodes.kern
local math_code           = nodecodes.math

local processnoads        = noads.process

local a_tagged            = attributes.private('tagged')
local a_taggedpar         = attributes.private('taggedpar')
local a_exportstatus      = attributes.private('exportstatus')
local a_mathcategory      = attributes.private('mathcategory')
local a_mathmode          = attributes.private('mathmode')
local a_fontkern          = attributes.private('fontkern')

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

local fromunicode16       = fonts.mappings.fromunicode16
local font_of_family      = node.family_font
local fontcharacters      = fonts.hashes.characters

local report_tags         = logs.reporter("structure","tags")

local process

local function processsubsup(start)
    -- At some point we might need to add an attribute signaling the
    -- super- and subscripts because TeX and MathML use a different
    -- order. The mrows are needed to keep mn's separated.
    local nucleus = getfield(start,"nucleus")
    local sup     = getfield(start,"sup")
    local sub     = getfield(start,"sub")
    if sub then
        if sup then
            setattr(start,a_tagged,start_tagged("msubsup"))
         -- start_tagged("mrow")
            process(nucleus)
         -- stop_tagged()
            start_tagged("mrow")
            process(sub)
            stop_tagged()
            start_tagged("mrow")
            process(sup)
            stop_tagged()
            stop_tagged()
        else
            setattr(start,a_tagged,start_tagged("msub"))
         -- start_tagged("mrow")
            process(nucleus)
         -- stop_tagged()
            start_tagged("mrow")
            process(sub)
            stop_tagged()
            stop_tagged()
        end
    elseif sup then
        setattr(start,a_tagged,start_tagged("msup"))
     -- start_tagged("mrow")
        process(nucleus)
     -- stop_tagged()
        start_tagged("mrow")
        process(sup)
        stop_tagged()
        stop_tagged()
    else
        process(nucleus)
    end
end

-- todo: check function here and keep attribute the same

-- todo: variants -> original

local actionstack = { }
local fencesstack = { }

-- glyph nodes and such can happen in under and over stuff

local function getunicode(n) -- instead of getchar
    local char = getchar(n)
    local font = font_of_family(getfield(n,"fam")) -- font_of_family
    local data = fontcharacters[font][char]
    return data.unicode or char
end

-------------------

local content = { }
local found   = false

content[math_char_code] = function() found = true end

local function hascontent(head)
    found = false
    processnoads(head,content,"content")
    return found
end

--------------------

local function showtag(n,id)
    local attr = getattr(n,a_tagged)
    report_tags("%s = %s",nodecodes[id or getid(n)],attr and taglist[attr].tagname or "?")
end

process = function(start) -- we cannot use the processor as we have no finalizers (yet)
    local mtexttag = nil
    while start do
        local id = getid(start)

-- showtag(start,id)

        if id == glyph_code or id == disc_code then
            if not mtexttag then
                mtexttag = start_tagged("mtext")
            end
            setattr(start,a_tagged,mtexttag)
        elseif mtexttag and id == kern_code and (getsubtype(start) == fontkern_code or getattr(start,a_fontkern)) then
            setattr(start,a_tagged,mtexttag)
        else
            if mtexttag then
                stop_tagged()
                mtexttag = nil
            end
            if id == math_char_code then
                local char = getchar(start)
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
                local a = getattr(start,a_mathcategory)
                if a then
                    setattr(start,a_tagged,start_tagged(tag,{ mathcategory = a }))
                else
                    setattr(start,a_tagged,start_tagged(tag)) -- todo: a_mathcategory
                end
                stop_tagged()
                break -- okay?
            elseif id == math_textchar_code then -- or id == glyph_code
                -- check for code
                local a = getattr(start,a_mathcategory)
                if a then
                    setattr(start,a_tagged,start_tagged("ms",{ mathcategory = a })) -- mtext
                else
                    setattr(start,a_tagged,start_tagged("ms")) -- mtext
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
                local specification = taglist[attr]
                local tag = specification.tagname
                if tag == "formulacaption" then
                    -- skip
                elseif tag == "mstacker" then
                    local list = getfield(start,"list")
                    if list then
                        process(list)
                    end
                else
                    if tag ~= "mstackertop" and tag ~= "mstackermid" and tag ~= "mstackerbot" then
                        tag = "mtext"
                    end
                    local text = start_tagged(tag)
                    setattr(start,a_tagged,text)
                    local list = getfield(start,"list")
                    if not list then
                        -- empty list
                    elseif not attr then
                        -- box comes from strange place
                        set_attributes(list,a_tagged,text) -- only the first node ?
                    else
                        -- Beware, the first node in list is the actual list so we definitely
                        -- need to nest. This approach is a hack, maybe I'll make a proper
                        -- nesting feature to deal with this at another level. Here we just
                        -- fake structure by enforcing the inner one.
                        --
                        -- todo: have a local list with local tags that then get appended
                        --
                        local tagdata = specification.taglist
                        local common = #tagdata + 1
                        local function runner(list,depth) -- quite inefficient
                            local cache = { } -- we can have nested unboxed mess so best local to runner
                            local keep = nil
                         -- local keep = { } -- win case we might need to move keep outside
                            for n in traverse_nodes(list) do
                                local id = getid(n)
                                local mth = id == math_code and getsubtype(n)
                                if mth == 0 then
                                 -- insert(keep,text)
                                    keep = text
                                    text = start_tagged("mrow")
                                    common = common + 1
                                end
                                local aa = getattr(n,a_tagged)
                                if aa then
                                    local ac = cache[aa]
                                    if not ac then
                                        local tagdata = taglist[aa].taglist
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
                                    runner(getlist(n),depth+1)
                                elseif id == glyph_code then
                                    runner(getfield(n,"components"),depth+1) -- this should not be needed
                                elseif id == disc_node then
                                    runner(getfield(n,"pre"),depth+1)        -- idem
                                    runner(getfield(n,"post"),depth+1)       -- idem
                                    runner(getfield(n,"replace"),depth+1)    -- idem
                                end
                                if mth == 1 then
                                    stop_tagged()
                                 -- text = remove(keep)
                                    text = keep
                                    common = common - 1
                                end
                            end
                        end
                        runner(list,0)
                    end
                    stop_tagged()
                end
            elseif id == math_sub_code then -- normally a hbox
                local list = getfield(start,"list")
                if list then
                    local attr = getattr(start,a_tagged)
                    local last = attr and taglist[attr]
                    if last then
                        local tag    = last.tagname
                        local detail = last.detail
                        if tag == "maction" then
                            if detail == "" then
                                setattr(start,a_tagged,start_tagged("mrow"))
                                process(list)
                                stop_tagged()
                            elseif actionstack[#actionstack] == action then
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
                        elseif tag == "mstacker" then -- or tag == "mstackertop" or tag == "mstackermid" or tag == "mstackerbot" then
                            -- looks like it gets processed twice
-- do we still end up here ?
                            setattr(start,a_tagged,restart_tagged(attr)) -- so we just reuse the attribute
                            process(list)
                            stop_tagged()
                        else
                            setattr(start,a_tagged,start_tagged("mrow"))
                            process(list)
                            stop_tagged()
                        end
                    else -- never happens, we're always document
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
                if subtype == 1 then
                    -- left
                    local properties = { }
                    insert(fencesstack,properties)
                    setattr(start,a_tagged,start_tagged("mfenced",{ properties = properties })) -- needs checking
                    if delim then
                        start_tagged("ignore")
                        local chr = getfield(delim,"small_char")
                        if chr ~= 0 then
                            properties.left = chr
                        end
                        process(delim)
                        stop_tagged()
                    end
                    start_tagged("mrow") -- begin of subsequence
                elseif subtype == 2 then
                    -- middle
                    if delim then
                        start_tagged("ignore")
                        local top = fencesstack[#fencesstack]
                        local chr = getfield(delim,"small_char")
                        if chr ~= 0 then
                            local mid = top.middle
                            if mid then
                                mid[#mid+1] = chr
                            else
                                top.middle = { chr }
                            end
                        end
                        process(delim)
                        stop_tagged()
                    end
                    stop_tagged()        -- end of subsequence
                    start_tagged("mrow") -- begin of subsequence
                elseif subtype == 3 then
                    local properties = remove(fencesstack)
                    if not properties then
                        report_tags("missing right fence")
                        properties = { }
                    end
                    if delim then
                        start_tagged("ignore")
                        local chr = getfield(delim,"small_char")
                        if chr ~= 0 then
                            properties.right = chr
                        end
                        process(delim)
                        stop_tagged()
                    end
                    stop_tagged() -- end of subsequence
                    stop_tagged()
                else
                    -- can't happen
                end
            elseif id == math_radical_code then
                local left   = getfield(start,"left")
                local degree = getfield(start,"degree")
                if left then
                    start_tagged("ignore")
                    process(left) -- root symbol, ignored
                    stop_tagged()
                end
                if degree and hascontent(degree) then
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
                local subtype    = getsubtype(start)
                if bot_accent then
                    if accent then
                        setattr(start,a_tagged,start_tagged("munderover", {
                            accent      = true,
                            top         = getunicode(accent),
                            bottom      = getunicode(bot_accent),
                            topfixed    = subtype == math_fixed_top or subtype == math_fixed_both,
                            bottomfixed = subtype == math_fixed_bottom or subtype == math_fixed_both,
                        }))
                        processsubsup(start)
                        process(bot_accent)
                        process(accent)
                        stop_tagged()
                    else
                        setattr(start,a_tagged,start_tagged("munder", {
                            accent      = true,
                            bottom      = getunicode(bot_accent),
                            bottomfixed = subtype == math_fixed_bottom or subtype == math_fixed_both,
                        }))
                        processsubsup(start)
                        process(bot_accent)
                        stop_tagged()
                    end
                elseif accent then
                    setattr(start,a_tagged,start_tagged("mover", {
                        accent   = true,
                        top      = getunicode(accent),
                        topfixed = subtype == math_fixed_top or subtype == math_fixed_both,
                    }))
                    processsubsup(start)
                    process(accent)
                    stop_tagged()
                else
                    processsubsup(start)
                end
            elseif id == glue_code then
             -- local spec = getfield(start,"spec")
             -- setattr(start,a_tagged,start_tagged("mspace",{ width = getfield(spec,"width") }))
                setattr(start,a_tagged,start_tagged("mspace"))
                stop_tagged()
            else
                setattr(start,a_tagged,start_tagged("merror", { detail = nodecodes[i] }))
                stop_tagged()
            end
        end
        start = getnext(start)
    end
    if mtexttag then
        stop_tagged()
    end
end

function noads.handlers.tags(head,style,penalties)
    head = tonut(head)
    local v_mode = getattr(head,a_mathmode)
    local v_math = start_tagged("math", { mode = v_mode == 1 and "display" or "inline" })
    setattr(head,a_tagged,start_tagged("mrow"))
    process(head)
    stop_tagged()
    stop_tagged()
    return true
end
