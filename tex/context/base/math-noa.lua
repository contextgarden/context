if not modules then modules = { } end modules ['math-noa'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- beware: this is experimental code and there will be a more generic (attribute value
-- driven) interface too but for the moment this is ok (sometime in 2015-2016 i will
-- start cleaning up as by then the bigger picture is clear and code has been used for
-- years; the main handlers will get some extensions)
--
-- we will also make dedicated processors (faster)
--
-- beware: names will change as we wil make noads.xxx.handler i.e. xxx
-- subnamespaces

-- 20D6 -> 2190
-- 20D7 -> 2192

-- future luatex will return font for a math char too
--
-- local function getfont(n)
--     return font_of_family(getfield(n,"fam"))
-- end

-- todo: most is math_char so we can have simple dedicated loops

-- nota bene: uunderdelimiter uoverdelimiter etc are radicals (we have 5 types)

local utfchar, utfbyte = utf.char, utf.byte
local formatters = string.formatters
local sortedhash = table.sortedhash
local insert, remove = table.insert, table.remove
local div = math.div

local fonts                = fonts
local nodes                = nodes
local node                 = node
local mathematics          = mathematics
local context              = context

local otf                  = fonts.handlers.otf
local otffeatures          = fonts.constructors.newfeatures("otf")
local registerotffeature   = otffeatures.register

local privateattribute     = attributes.private
local registertracker      = trackers.register
local registerdirective    = directives.register
local logreporter          = logs.reporter

local trace_remapping      = false  registertracker("math.remapping",   function(v) trace_remapping   = v end)
local trace_processing     = false  registertracker("math.processing",  function(v) trace_processing  = v end)
local trace_analyzing      = false  registertracker("math.analyzing",   function(v) trace_analyzing   = v end)
local trace_normalizing    = false  registertracker("math.normalizing", function(v) trace_normalizing = v end)
local trace_collapsing     = false  registertracker("math.collapsing",  function(v) trace_collapsing  = v end)
local trace_patching       = false  registertracker("math.patching",    function(v) trace_patching    = v end)
local trace_goodies        = false  registertracker("math.goodies",     function(v) trace_goodies     = v end)
local trace_variants       = false  registertracker("math.variants",    function(v) trace_variants    = v end)
local trace_alternates     = false  registertracker("math.alternates",  function(v) trace_alternates  = v end)
local trace_italics        = false  registertracker("math.italics",     function(v) trace_italics     = v end)
local trace_domains        = false  registertracker("math.domains",     function(v) trace_domains     = v end)
local trace_families       = false  registertracker("math.families",    function(v) trace_families    = v end)
local trace_fences         = false  registertracker("math.fences",      function(v) trace_fences      = v end)

local check_coverage       = true   registerdirective("math.checkcoverage", function(v) check_coverage = v end)

local report_processing    = logreporter("mathematics","processing")
local report_remapping     = logreporter("mathematics","remapping")
local report_normalizing   = logreporter("mathematics","normalizing")
local report_collapsing    = logreporter("mathematics","collapsing")
local report_patching      = logreporter("mathematics","patching")
local report_goodies       = logreporter("mathematics","goodies")
local report_variants      = logreporter("mathematics","variants")
local report_alternates    = logreporter("mathematics","alternates")
local report_italics       = logreporter("mathematics","italics")
local report_domains       = logreporter("mathematics","domains")
local report_families      = logreporter("mathematics","families")
local report_fences        = logreporter("mathematics","fences")

local a_mathrendering      = privateattribute("mathrendering")
local a_exportstatus       = privateattribute("exportstatus")

local nuts                 = nodes.nuts
local nodepool             = nuts.pool
local tonut                = nuts.tonut
local tonode               = nuts.tonode
local nutstring            = nuts.tostring

local getfield             = nuts.getfield
local setfield             = nuts.setfield
local getnext              = nuts.getnext
local getprev              = nuts.getprev
local getid                = nuts.getid
----- getfont              = nuts.getfont
local getsubtype           = nuts.getsubtype
local getchar              = nuts.getchar
local getattr              = nuts.getattr
local setattr              = nuts.setattr

local insert_node_after    = nuts.insert_after
local insert_node_before   = nuts.insert_before
local free_node            = nuts.free
local new_node             = nuts.new -- todo: pool: math_noad math_sub
local copy_node            = nuts.copy
local slide_nodes          = nuts.slide
local linked_nodes         = nuts.linked
local set_visual           = nuts.setvisual

local mlist_to_hlist       = nodes.mlist_to_hlist

local font_of_family       = node.family_font

local new_kern             = nodepool.kern
local new_rule             = nodepool.rule

local fonthashes           = fonts.hashes
local fontdata             = fonthashes.identifiers
local fontcharacters       = fonthashes.characters
local fontproperties       = fonthashes.properties
local fontitalics          = fonthashes.italics
local fontemwidths         = fonthashes.emwidths
local fontexheights        = fonthashes.exheights

local variables            = interfaces.variables
local texsetattribute      = tex.setattribute
local texgetattribute      = tex.getattribute
local unsetvalue           = attributes.unsetvalue
local implement            = interfaces.implement

local v_reset              = variables.reset

local chardata             = characters.data

noads                      = noads or { }  -- todo: only here
local noads                = noads

noads.processors           = noads.processors or { }
local processors           = noads.processors

noads.handlers             = noads.handlers   or { }
local handlers             = noads.handlers

local tasks                = nodes.tasks

local nodecodes            = nodes.nodecodes
local noadcodes            = nodes.noadcodes
local fencecodes           = nodes.fencecodes

local noad_ord             = noadcodes.ord
local noad_rel             = noadcodes.rel
local noad_bin             = noadcodes.bin
local noad_open            = noadcodes.open
local noad_close           = noadcodes.close
local noad_punct           = noadcodes.punct
local noad_opdisplaylimits = noadcodes.opdisplaylimits
local noad_oplimits        = noadcodes.oplimits
local noad_opnolimits      = noadcodes.opnolimits
local noad_inner           = noadcodes.inner

local math_noad            = nodecodes.noad           -- attr nucleus sub sup
local math_accent          = nodecodes.accent         -- attr nucleus sub sup accent
local math_radical         = nodecodes.radical        -- attr nucleus sub sup left degree
local math_fraction        = nodecodes.fraction       -- attr nucleus sub sup left right
local math_box             = nodecodes.subbox         -- attr list
local math_sub             = nodecodes.submlist       -- attr list
local math_char            = nodecodes.mathchar       -- attr fam char
local math_textchar        = nodecodes.mathtextchar   -- attr fam char
local math_delim           = nodecodes.delim          -- attr small_fam small_char large_fam large_char
local math_style           = nodecodes.style          -- attr style
local math_choice          = nodecodes.choice         -- attr display text script scriptscript
local math_fence           = nodecodes.fence          -- attr subtype

local hlist_code           = nodecodes.hlist
local glyph_code           = nodecodes.glyph

local left_fence_code      = fencecodes.left
local middle_fence_code    = fencecodes.middle
local right_fence_code     = fencecodes.right

-- this initial stuff is tricky as we can have removed and new nodes with the same address
-- the only way out is a free-per-page list of nodes (not bad anyway)

local function process(start,what,n,parent)
    if n then
        n = n + 1
    else
        n = 0
    end
    --
    local initial = start
    --
    slide_nodes(start) -- we still miss a prev in noads -- fences test code
    --
    while start do
        local id = getid(start)
        if trace_processing then
            if id == math_noad then
                report_processing("%w%S, class %a",n*2,nutstring(start),noadcodes[getsubtype(start)])
            elseif id == math_char then
                local char = getchar(start)
                local fam  = getfield(start,"fam")
                local font = font_of_family(fam)
                report_processing("%w%S, family %a, font %a, char %a, shape %c",n*2,nutstring(start),fam,font,char,char)
            else
                report_processing("%w%S",n*2,nutstring(start))
            end
        end
        local proc = what[id]
        if proc then
         -- report_processing("start processing")
            local done, newstart, newinitial = proc(start,what,n,parent) -- prev is bugged:  or getprev(start)
            if newinitial then
                initial = newinitial -- temp hack .. we will make all return head
                if newstart then
                    start = newstart
                 -- report_processing("stop processing (new start)")
                else
                 -- report_processing("quit processing (done)")
                    break
                end
            else
                if newstart then
                    start = newstart
                 -- report_processing("stop processing (new start)")
                else
                 -- report_processing("stop processing")
                end
            end
        elseif id == math_char or id == math_textchar or id == math_delim then
            break
        elseif id == math_noad then
            local noad = getfield(start,"nucleus")      if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"sup")          if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"sub")          if noad then process(noad,what,n,start) end -- list
        elseif id == math_box or id == math_sub then
            local noad = getfield(start,"list")         if noad then process(noad,what,n,start) end -- list (not getlist !)
        elseif id == math_fraction then
            local noad = getfield(start,"num")          if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"denom")        if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"left")         if noad then process(noad,what,n,start) end -- delimiter
                  noad = getfield(start,"right")        if noad then process(noad,what,n,start) end -- delimiter
        elseif id == math_choice then
            local noad = getfield(start,"display")      if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"text")         if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"script")       if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"scriptscript") if noad then process(noad,what,n,start) end -- list
        elseif id == math_fence then
            local noad = getfield(start,"delim")        if noad then process(noad,what,n,start) end -- delimiter
        elseif id == math_radical then
            local noad = getfield(start,"nucleus")      if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"sup")          if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"sub")          if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"left")         if noad then process(noad,what,n,start) end -- delimiter
                  noad = getfield(start,"degree")       if noad then process(noad,what,n,start) end -- list
        elseif id == math_accent then
            local noad = getfield(start,"nucleus")      if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"sup")          if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"sub")          if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"accent")       if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"bot_accent")   if noad then process(noad,what,n,start) end -- list
     -- elseif id == math_style then
     --     -- has a next
     -- else
     --     -- glue, penalty, etc
        end
        start = getnext(start)
    end
    if not parent then
        return initial, true -- only first level -- for now
    end
end

local function processnested(current,what,n)
    local noad = nil
    local id   = getid(current)
    if id == math_noad then
        noad = getfield(current,"nucleus")      if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"sup")          if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"sub")          if noad then process(noad,what,n,current) end -- list
    elseif id == math_box or id == math_sub then
        noad = getfield(current,"list")         if noad then process(noad,what,n,current) end -- list (not getlist !)
    elseif id == math_fraction then
        noad = getfield(current,"num")          if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"denom")        if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"left")         if noad then process(noad,what,n,current) end -- delimiter
        noad = getfield(current,"right")        if noad then process(noad,what,n,current) end -- delimiter
    elseif id == math_choice then
        noad = getfield(current,"display")      if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"text")         if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"script")       if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"scriptscript") if noad then process(noad,what,n,current) end -- list
    elseif id == math_fence then
        noad = getfield(current,"delim")        if noad then process(noad,what,n,current) end -- delimiter
    elseif id == math_radical then
        noad = getfield(current,"nucleus")      if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"sup")          if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"sub")          if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"left")         if noad then process(noad,what,n,current) end -- delimiter
        noad = getfield(current,"degree")       if noad then process(noad,what,n,current) end -- list
    elseif id == math_accent then
        noad = getfield(current,"nucleus")      if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"sup")          if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"sub")          if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"accent")       if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"bot_accent")   if noad then process(noad,what,n,current) end -- list
    end
end

local function processstep(current,process,n,id)
    local noad = nil
    local id   = id or getid(current)
    if id == math_noad then
        noad = getfield(current,"nucleus")      if noad then process(noad,n,current) end -- list
        noad = getfield(current,"sup")          if noad then process(noad,n,current) end -- list
        noad = getfield(current,"sub")          if noad then process(noad,n,current) end -- list
    elseif id == math_box or id == math_sub then
        noad = getfield(current,"list")         if noad then process(noad,n,current) end -- list (not getlist !)
    elseif id == math_fraction then
        noad = getfield(current,"num")          if noad then process(noad,n,current) end -- list
        noad = getfield(current,"denom")        if noad then process(noad,n,current) end -- list
        noad = getfield(current,"left")         if noad then process(noad,n,current) end -- delimiter
        noad = getfield(current,"right")        if noad then process(noad,n,current) end -- delimiter
    elseif id == math_choice then
        noad = getfield(current,"display")      if noad then process(noad,n,current) end -- list
        noad = getfield(current,"text")         if noad then process(noad,n,current) end -- list
        noad = getfield(current,"script")       if noad then process(noad,n,current) end -- list
        noad = getfield(current,"scriptscript") if noad then process(noad,n,current) end -- list
    elseif id == math_fence then
        noad = getfield(current,"delim")        if noad then process(noad,n,current) end -- delimiter
    elseif id == math_radical then
        noad = getfield(current,"nucleus")      if noad then process(noad,n,current) end -- list
        noad = getfield(current,"sup")          if noad then process(noad,n,current) end -- list
        noad = getfield(current,"sub")          if noad then process(noad,n,current) end -- list
        noad = getfield(current,"left")         if noad then process(noad,n,current) end -- delimiter
        noad = getfield(current,"degree")       if noad then process(noad,n,current) end -- list
    elseif id == math_accent then
        noad = getfield(current,"nucleus")      if noad then process(noad,n,current) end -- list
        noad = getfield(current,"sup")          if noad then process(noad,n,current) end -- list
        noad = getfield(current,"sub")          if noad then process(noad,n,current) end -- list
        noad = getfield(current,"accent")       if noad then process(noad,n,current) end -- list
        noad = getfield(current,"bot_accent")   if noad then process(noad,n,current) end -- list
    end
end

local function processnoads(head,actions,banner)
    local h, d
    if trace_processing then
        report_processing("start %a",banner)
        h, d = process(tonut(head),actions)
        report_processing("stop %a",banner)
    else
        h, d = process(tonut(head),actions)
    end
    return h and tonode(h) or head, d == nil and true or d
end

noads.process       = processnoads
noads.processnested = processnested
noads.processouter  = process

--

local unknowns = { }
local checked  = { } -- simple case
local tracked  = false  trackers.register("fonts.missing", function(v) tracked = v end)
local cached   = table.setmetatableindex("table") -- complex case

local function errorchar(font,char)
    local done = unknowns[char]
    if done then
        unknowns[char] = done  + 1
    else
        unknowns[char] = 1
    end
    if tracked then
        -- slower as we check each font too and we always replace as math has
        -- more demands than text
        local fake = cached[font][char]
        if fake then
            return fake
        else
            local kind, fake = fonts.checkers.placeholder(font,char)
            if not fake or kind ~= "char" then
                fake = 0x3F
            end
            cached[font][char] = fake
            return fake
        end
    else
        -- only simple checking, report at the end so one should take
        -- action anyway ... we can miss a few checks but that is ok
        -- as there is at least one reported
        if not checked[char] then
            if trace_normalizing then
                report_normalizing("character %C is not available",char)
            end
            checked[char] = true
        end
        return 0x3F
    end
end

-- experiment (when not present fall back to fam 0) -- needs documentation

-- 0-2 regular
-- 3-5 bold
-- 6-8 pseudobold

-- this could best be integrated in the remapper, and if we run into problems, we
-- might as well do this

local families     = { }
local a_mathfamily = privateattribute("mathfamily")
local boldmap      = mathematics.boldmap

local familymap = { [0] =
    "regular",
    "regular",
    "regular",
    "bold",
    "bold",
    "bold",
    "pseudobold",
    "pseudobold",
    "pseudobold",
}

families[math_char] = function(pointer)
    if getfield(pointer,"fam") == 0 then
        local a = getattr(pointer,a_mathfamily)
        if a and a > 0 then
            setattr(pointer,a_mathfamily,0)
            if a > 5 then
                local char = getchar(pointer)
                local bold = boldmap[char]
                local newa = a - 3
                if not bold then
                    if trace_families then
                        report_families("no bold replacement for %C, family %s with remap %s becomes %s with remap %s",char,a,familymap[a],newa,familymap[newa])
                    end
                    setfield(pointer,"fam",newa)
                elseif not fontcharacters[font_of_family(newa)][bold] then
                    if trace_families then
                        report_families("no bold character for %C, family %s with remap %s becomes %s with remap %s",char,a,familymap[a],newa,familymap[newa])
                    end
                    if newa > 3 then
                        setfield(pointer,"fam",newa-3)
                    end
                else
                    setattr(pointer,a_exportstatus,char)
                    setfield(pointer,"char",bold)
                    if trace_families then
                        report_families("replacing %C by bold %C, family %s with remap %s becomes %s with remap %s",char,bold,a,familymap[a],newa,familymap[newa])
                    end
                    setfield(pointer,"fam",newa)
                end
            else
                local char = getchar(pointer)
                if not fontcharacters[font_of_family(a)][char] then
                    if trace_families then
                        report_families("no bold replacement for %C",char)
                    end
                else
                    if trace_families then
                        report_families("family of %C becomes %s with remap %s",char,a,familymap[a])
                    end
                    setfield(pointer,"fam",a)
                end
            end
        end
    end
end

families[math_delim] = function(pointer)
    if getfield(pointer,"small_fam") == 0 then
        local a = getattr(pointer,a_mathfamily)
        if a and a > 0 then
            setattr(pointer,a_mathfamily,0)
            if a > 5 then
                -- no bold delimiters in unicode
                a = a - 3
            end
            local char = getfield(pointer,"small_char")
            local okay = fontcharacters[font_of_family(a)][char]
            if okay then
                setfield(pointer,"small_fam",a)
            elseif a > 2 then
                setfield(pointer,"small_fam",a-3)
            end
            local char = getfield(pointer,"large_char")
            local okay = fontcharacters[font_of_family(a)][char]
            if okay then
                setfield(pointer,"large_fam",a)
            elseif a > 2 then
                setfield(pointer,"large_fam",a-3)
            end
        else
            setfield(pointer,"small_fam",0)
            setfield(pointer,"large_fam",0)
        end
    end
end

families[math_textchar] = families[math_char]

function handlers.families(head,style,penalties)
    processnoads(head,families,"families")
    return true
end

-- character remapping

local a_mathalphabet = privateattribute("mathalphabet")
local a_mathgreek    = privateattribute("mathgreek")

processors.relocate = { }

local function report_remap(tag,id,old,new,extra)
    report_remapping("remapping %s in font %s from %C to %C%s",tag,id,old,new,extra)
end

local remapalphabets    = mathematics.remapalphabets
local fallbackstyleattr = mathematics.fallbackstyleattr
local setnodecolor      = nodes.tracers.colors.set

local function checked(pointer)
    local char = getchar(pointer)
    local fam = getfield(pointer,"fam")
    local id = font_of_family(fam)
    local tc = fontcharacters[id]
    if not tc[char] then
        local specials = characters.data[char].specials
        if specials and (specials[1] == "char" or specials[1] == "font") then
            newchar = specials[#specials]
            if trace_remapping then
                report_remap("fallback",id,char,newchar)
            end
            if trace_analyzing then
                setnodecolor(pointer,"font:isol")
            end
            setattr(pointer,a_exportstatus,char) -- testcase: exponentiale
            setfield(pointer,"char",newchar)
            return true
        end
    end
end

processors.relocate[math_char] = function(pointer)
    local g          = getattr(pointer,a_mathgreek) or 0
    local a          = getattr(pointer,a_mathalphabet) or 0
    local char       = getchar(pointer)
    local fam        = getfield(pointer,"fam")
    local font       = font_of_family(fam)
    local characters = fontcharacters[font]
    if a > 0 or g > 0 then
        if a > 0 then
            setattr(pointer,a_mathgreek,0)
        end
        if g > 0 then
            setattr(pointer,a_mathalphabet,0)
        end
        local newchar = remapalphabets(char,a,g)
        if newchar then
            if characters[newchar] then
                if trace_remapping then
                    report_remap("char",font,char,newchar)
                end
                if trace_analyzing then
                    setnodecolor(pointer,"font:isol")
                end
                setfield(pointer,"char",newchar)
                return true
            else
                local fallback = fallbackstyleattr(a)
                if fallback then
                    local newchar = remapalphabets(char,fallback,g)
                    if newchar then
                        if characters[newchar] then
                            if trace_remapping then
                                report_remap("char",font,char,newchar," (fallback remapping used)")
                            end
                            if trace_analyzing then
                                setnodecolor(pointer,"font:isol")
                            end
                            setfield(pointer,"char",newchar)
                            return true
                        elseif trace_remapping then
                            report_remap("char",font,char,newchar," fails (no fallback character)")
                        end
                    elseif trace_remapping then
                        report_remap("char",font,char,newchar," fails (no fallback remap character)")
                    end
                elseif trace_remapping then
                    report_remap("char",font,char,newchar," fails (no fallback style)")
                end
            end
        end
    end
    if not characters[char] then
        setfield(pointer,"char",errorchar(font,char))
    end
    if trace_analyzing then
        setnodecolor(pointer,"font:medi")
    end
    if check_coverage then
        return checked(pointer)
    end
end

processors.relocate[math_textchar] = function(pointer)
    if trace_analyzing then
        setnodecolor(pointer,"font:init")
    end
end

processors.relocate[math_delim] = function(pointer)
    if trace_analyzing then
        setnodecolor(pointer,"font:fina")
    end
end

function handlers.relocate(head,style,penalties)
    processnoads(head,processors.relocate,"relocate")
    return true
end

-- rendering (beware, not exported)

processors.render = { }

local rendersets = mathematics.renderings.numbers or { } -- store

processors.render[math_char] = function(pointer)
    local attr = getattr(pointer,a_mathrendering)
    if attr and attr > 0 then
        local char = getchar(pointer)
        local renderset = rendersets[attr]
        if renderset then
            local newchar = renderset[char]
            if newchar then
                local fam        = getfield(pointer,"fam")
                local font       = font_of_family(fam)
                local characters = fontcharacters[font]
                if characters and characters[newchar] then
                    setfield(pointer,"char",newchar)
                    setattr(pointer,a_exportstatus,char)
                end
            end
        end
    end
end

function handlers.render(head,style,penalties)
    processnoads(head,processors.render,"render")
    return true
end

-- some resize options (this works ok because the content is
-- empty and no larger next will be forced)
--
-- beware: we don't use \delcode but \Udelcode and as such have
-- no large_fam; also, we need to check for subtype and/or
-- small_fam not being 0 because \. sits in 0,0 by default
--
-- todo: just replace the character by an ord noad
-- and remove the right delimiter as well

local a_mathsize  = privateattribute("mathsize") -- this might move into other fence code
local resize      = { }
processors.resize = resize

resize[math_fence] = function(pointer)
    local subtype = getsubtype(pointer)
    if subtype == left_fence_code or subtype == right_fence_code then
        local a = getattr(pointer,a_mathsize)
        if a and a > 0 then
            local method, size = div(a,100), a % 100
            setattr(pointer,a_mathsize,0)
            local delimiter = getfield(pointer,"delim")
            local chr = getfield(delimiter,"small_char")
            if chr > 0 then
                local fam = getfield(delimiter,"small_fam")
                local id = font_of_family(fam)
                if id > 0 then
                    setfield(delimiter,"small_char",mathematics.big(fontdata[id],chr,size,method))
                end
            end
        end
    end
end

function handlers.resize(head,style,penalties)
    processnoads(head,resize,"resize")
    return true
end

local a_autofence     = privateattribute("mathautofence")
local autofences      = { }
processors.autofences = autofences
local dummyfencechar  = 0x2E

local function makefence(what,char)
    local d = new_node(math_delim)
    local f = new_node(math_fence)
    if char then
        local sym = getfield(char,"nucleus")
        local chr = getfield(sym,"char")
        local fam = getfield(sym,"fam")
        if chr == dummyfencechar then
            chr = 0
        end
        setfield(d,"small_char",chr)
        setfield(d,"small_fam", fam)
        free_node(sym)
    end
    setfield(f,"subtype",what)
    setfield(f,"delim",d)
    return f
end

local function makelist(noad,f_o,o_next,c_prev,f_c,middle)
    local list = new_node(math_sub)
    setfield(list,"head",f_o)
    setfield(noad,"subtype",noad_inner)
    setfield(noad,"nucleus",list)
    setfield(f_o,"next",o_next)
    setfield(o_next,"prev",f_o)
    setfield(f_c,"prev",c_prev)
    setfield(c_prev,"next",f_c)
    if middle and next(middle) then
        local prev    = f_o
        local current = o_next
        while current ~= f_c do
            local m = middle[current]
            if m then
                local next  = getnext(current)
                local fence = makefence(middle_fence_code,current)
                setfield(current,"nucleus",nil)
                free_node(current)
                middle[current] = nil
                -- replace_node
-- print(">>>",prev,m) -- weird, can differ
                setfield(prev,"next",fence)
                setfield(fence,"prev",prev)
                setfield(next,"prev",fence)
                setfield(fence,"next",next)
                prev    = fence
                current = next
            else
                prev = current
                current = getnext(current)
            end
        end
    end
end

local function convert_both(open,close,middle)
    local o_next = getnext(open)
 -- local o_prev = getprev(open)
    local c_next = getnext(close)
    local c_prev = getprev(close)
    if o_next == close then
        return close
    else
        local f_o = makefence(left_fence_code,open)
        local f_c = makefence(right_fence_code,close)
        makelist(open,f_o,o_next,c_prev,f_c,middle)
        setfield(close,"nucleus",nil)
        free_node(close)
        if c_next then
            setfield(c_next,"prev",open)
        end
        setfield(open,"next",c_next)
        return open
    end
end

local function convert_open(open,last,middle)
    local f_o = makefence(left_fence_code,open)
    local f_c = makefence(right_fence_code)
    local o_next = getnext(open)
 -- local o_prev = getprev(open)
    local l_next = getnext(last)
 -- local l_prev = getprev(last)
    makelist(open,f_o,o_next,last,f_c,middle)
    if l_next then
        setfield(l_next,"prev",open)
    end
    setfield(open,"next",l_next)
    return open
end

local function convert_close(close,first,middle)
    local f_o = makefence(left_fence_code)
    local f_c = makefence(right_fence_code,close)
    local c_prev = getprev(close)
    makelist(close,f_o,first,c_prev,f_c,middle)
    return close
end

local stacks = table.setmetatableindex("table")

local function processfences(pointer,n,parent)
    local current = pointer
    local last    = pointer
    local start   = pointer
    local done    = false
    local initial = pointer
    local stack   = nil
    local middle  = nil -- todo: use properties
    while current do
        local id = getid(current)
        if id == math_noad then
            local a = getattr(current,a_autofence)
            if a and a > 0 then
                local stack = stacks[n]
                setattr(current,a_autofence,0)
                if a == 1 or (a == 4 and (not stack or #stack == 0)) then
                    if trace_fences then
                        report_fences("%2i: pushing open on stack",n)
                    end
                    insert(stack,current)
                elseif a == 2 or a == 4 then
                    local open = remove(stack)
                    if open then
                        if trace_fences then
                            report_fences("%2i: handling %s, stack depth %i",n,"both",#stack)
                        end
                        current = convert_both(open,current,middle)
                    elseif current == start then
                        -- skip
                    else
                        if trace_fences then
                            report_fences("%2i: handling %s, stack depth %i",n,"close",#stack)
                        end
                        current = convert_close(current,initial,middle)
                        if not parent then
                            initial = current
                        end
                    end
                elseif a == 3 then
                    if trace_fences then
                        report_fences("%2i: registering middle",n)
                    end
                    if middle then
                        middle[current] = last
                    else
                        middle = { [current] = last }
                    end
                end
                done = true
            else
                processstep(current,processfences,n+1,id)
            end
        else
            -- next at current level
            processstep(current,processfences,n,id)
        end
        last    = current
        current = getnext(current)
    end
    if done then
        local stack = stacks[n]
        local s = #stack
        if s > 0 then
            if trace_fences then
                report_fences("%2i: handling %s stack levels",n,s)
            end
            for i=1,s do
                local open = remove(stack)
                if trace_fences then
                    report_fences("%2i: handling %s, stack depth %i",n,"open",#stack)
                end
                last = convert_open(open,last,middle)
            end
        end
    end
end

-- we can have a first changed node .. an option is to have a leading dummy node in math
-- lists like the par node as it can save a  lot of mess

local enabled = false

implement {
    name     = "enableautofences",
    onlyonce = true,
    actions  = function()
        tasks.enableaction("math","noads.handlers.autofences")
        enabled = true
    end
}

function handlers.autofences(head,style,penalties)
    if enabled then -- tex.modes.c_math_fences_auto
     -- inspect(nodes.totree(head))
        processfences(tonut(head),1)
     -- inspect(nodes.totree(head))
    end
end

-- normalize scripts

local unscript     = { }  noads.processors.unscript = unscript
local superscripts = characters.superscripts
local subscripts   = characters.subscripts
local fractions    = characters.fractions
local replaced     = { }

local function replace(pointer,what,n,parent)
    pointer = parent -- we're following the parent list (chars trigger this)
    local next = getnext(pointer)
    local start_super, stop_super, start_sub, stop_sub
    local mode = "unset"
    while next and getid(next) == math_noad do
        local nextnucleus = getfield(next,"nucleus")
        if nextnucleus and getid(nextnucleus) == math_char and not getfield(next,"sub") and not getfield(next,"sup") then
            local char = getchar(nextnucleus)
            local s = superscripts[char]
            if s then
                if not start_super then
                    start_super = next
                    mode = "super"
                elseif mode == "sub" then
                    break
                end
                stop_super = next
                next = getnext(next)
                setfield(nextnucleus,"char",s)
                replaced[char] = (replaced[char] or 0) + 1
                if trace_normalizing then
                    report_normalizing("superscript %C becomes %C",char,s)
                end
            else
                local s = subscripts[char]
                if s then
                    if not start_sub then
                        start_sub = next
                        mode = "sub"
                    elseif mode == "super" then
                        break
                    end
                    stop_sub = next
                    next = getnext(next)
                    setfield(nextnucleus,"char",s)
                    replaced[char] = (replaced[char] or 0) + 1
                    if trace_normalizing then
                        report_normalizing("subscript %C becomes %C",char,s)
                    end
                else
                    break
                end
            end
        else
            break
        end
    end
    if start_super then
        if start_super == stop_super then
            setfield(pointer,"sup",getfield(start_super,"nucleus"))
        else
            local list = new_node(math_sub) -- todo attr
            setfield(list,"list",start_super)
            setfield(pointer,"sup",list)
        end
        if mode == "super" then
            setfield(pointer,"next",getnext(stop_super))
        end
        setfield(stop_super,"next",nil)
    end
    if start_sub then
        if start_sub == stop_sub then
            setfield(pointer,"sub",getfield(start_sub,"nucleus"))
        else
            local list = new_node(math_sub) -- todo attr
            setfield(list,"list",start_sub)
            setfield(pointer,"sub",list)
        end
        if mode == "sub" then
            setfield(pointer,"next",getnext(stop_sub))
        end
        setfield(stop_sub,"next",nil)
    end
    -- we could return stop
end

unscript[math_char] = replace -- not noads as we need to recurse

function handlers.unscript(head,style,penalties)
    processnoads(head,unscript,"unscript")
--  processnoads(head,checkers,"checkers")
    return true
end

local function collected(list)
    if list and next(list) then
        local n, t = 0, { }
        for k, v in sortedhash(list) do
            n = n + v
            t[#t+1] = formatters["%C"](k)
        end
        return formatters["% t (n=%s)"](t,n)
    end
end

statistics.register("math script replacements", function()
    return collected(replaced)
end)

statistics.register("unknown math characters", function()
    return collected(unknowns)
end)

-- math alternates: (in xits       lgf: $ABC$ $\cal ABC$ $\mathalternate{cal}\cal ABC$)
-- math alternates: (in lucidanova lgf: $ABC \mathalternate{italic} ABC$)

-- todo: set alternate for specific symbols
-- todo: no need to do this when already loaded

local defaults = {
    dotless = { feature = 'dtls', value = 1, comment = "Mathematical Dotless Forms" },
 -- zero    = { feature = 'zero', value = 1, comment = "Slashed or Dotted Zero" }, -- in no math font (yet)
}

local function initializemathalternates(tfmdata)
    local goodies  = tfmdata.goodies
    local autolist = table.copy(defaults)

    local function setthem(alternates)
        local resources     = tfmdata.resources -- was tfmdata.shared
        local lastattribute = 0
        local attributes    = { }
        for k, v in sortedhash(alternates) do
            lastattribute = lastattribute + 1
            v.attribute   = lastattribute
            attributes[lastattribute] = v
        end
        resources.mathalternates           = alternates -- to be checked if shared is ok here
        resources.mathalternatesattributes = attributes -- to be checked if shared is ok here
    end

    if goodies then
        local done = { }
        for i=1,#goodies do
            -- first one counts
            -- we can consider sharing the attributes ... todo (only once scan)
            local mathgoodies = goodies[i].mathematics
            local alternates  = mathgoodies and mathgoodies.alternates
            if alternates then
                if trace_goodies then
                    report_goodies("loading alternates for font %a",tfmdata.properties.name)
                end
                for k, v in next, autolist do
                    if not alternates[k] then
                        alternates[k] = v
                    end
                end
                setthem(alternates)
                return
            end
        end
    end

    if trace_goodies then
        report_goodies("loading default alternates for font %a",tfmdata.properties.name)
    end
    setthem(autolist)

end

registerotffeature {
    name        = "mathalternates",
    description = "additional math alternative shapes",
    initializers = {
        base = initializemathalternates,
        node = initializemathalternates,
    }
}

-- local getalternate = otf.getalternate (runtime new method so ...)

-- todo: not shared but copies ... one never knows

local a_mathalternate = privateattribute("mathalternate")

local alternate = { } -- processors.alternate = alternate

function mathematics.setalternate(fam,tag)
    local id        = font_of_family(fam)
    local tfmdata   = fontdata[id]
    local resources = tfmdata.resources -- was tfmdata.shared
    if resources then
        local mathalternates = resources.mathalternates
        if mathalternates then
            local m = mathalternates[tag]
            texsetattribute(a_mathalternate,m and m.attribute or unsetvalue)
        end
    end
end

implement {
    name      = "setmathalternate",
    actions   = mathematics.setalternate,
    arguments = { "integer", "string" }
}

alternate[math_char] = function(pointer)
    local a = getattr(pointer,a_mathalternate)
    if a and a > 0 then
        setattr(pointer,a_mathalternate,0)
        local tfmdata   = fontdata[font_of_family(getfield(pointer,"fam"))] -- we can also have a famdata
        local resources = tfmdata.resources -- was tfmdata.shared
        if resources then
            local mathalternatesattributes = resources.mathalternatesattributes
            if mathalternatesattributes then
                local what = mathalternatesattributes[a]
                local alt  = otf.getalternate(tfmdata,getchar(pointer),what.feature,what.value)
                if alt then
                    if trace_alternates then
                        report_alternates("alternate %a, value %a, replacing glyph %U by glyph %U",
                            tostring(what.feature),tostring(what.value),getchar(pointer),alt)
                    end
                    setfield(pointer,"char",alt)
                end
            end
        end
    end
end

function handlers.alternates(head,style,penalties)
    processnoads(head,alternate,"alternate")
    return true
end

-- italics: we assume that only characters matter
--
-- = we check for correction first because accessing nodes is slower
-- = the actual glyph is not that important (we can control it with numbers)

-- Italic correction in luatex math is (was) a mess. There are all kind of assumptions based on
-- old fonts and new fonts. Eventually there should be a flag that can signal to ignore all
-- those heuristics. We want to deal with it ourselves also in the perspective of mixed math
-- and text. Also, for a while in context we had to deal with a mix of virtual math fonts and
-- real ones.

-- in opentype the italic correction of a limop is added to the width and luatex does some juggling
-- that we want to avoid but we need to do something here (in fact, we could better fix the width of
-- the character

local a_mathitalics = privateattribute("mathitalics")

local italics        = { }
local default_factor = 1/20

local setcolor     = nodes.tracers.colors.set
local resetcolor   = nodes.tracers.colors.reset
local italic_kern  = new_kern
local c_positive_d = "trace:dg"
local c_negative_d = "trace:dr"

local function insert_kern(current,kern)
    local sub  = new_node(math_sub)  -- todo: pool
    local noad = new_node(math_noad) -- todo: pool
    setfield(sub,"list",kern)
    setfield(kern,"next",noad)
    setfield(noad,"nucleus",current)
    return sub
end

registertracker("math.italics.visualize", function(v)
    if v then
        italic_kern = function(k)
            local n = new_kern(k)
            set_visual(n,"italic")
            return n
        end
    else
        italic_kern = new_kern
    end
end)

local function getcorrection(method,font,char) -- -- or character.italic -- (this one is for tex)

    local visual = chardata[char].visual

    if method == 1 then
        -- check on state
        local italics = fontitalics[font]
        if italics then
            local character = fontcharacters[font][char]
            if character then
                local correction = character.italic
                if correction and correction ~= 0 then
                    return correction, visual
                end
            end
        end
    elseif method == 2 then
        -- no check
        local character = fontcharacters[font][char]
        if character then
            local correction = character.italic
            if correction and correction ~= 0 then
                return correction, visual
            end
        end
    elseif method == 3 then
        -- check on visual
        if visual == "it" or visual == "bi" then
            local character = fontcharacters[font][char]
            if character then
                local correction = character.italic
                if correction and correction ~= 0 then
                    return correction, visual
                end
            end
        end
    elseif method == 4 then
        -- combination of 1 and 3
        local italics = fontitalics[font]
        if italics and (visual == "it" or visual == "bi") then
            local character = fontcharacters[font][char]
            if character then
                local correction = character.italic
                if correction and correction ~= 0 then
                    return correction, visual
                end
            end
        end
    end

end

italics[math_char] = function(pointer,what,n,parent)
    local method = getattr(pointer,a_mathitalics)
    if method and method > 0 and method < 100 then
        local char = getchar(pointer)
        local font = font_of_family(getfield(pointer,"fam")) -- todo: table
        local correction, visual = getcorrection(method,font,char)
        if correction and correction ~= 0 then
            local next_noad = getnext(parent)
            if not next_noad then
                if n == 1 then -- only at the outer level .. will become an option (always,endonly,none)
                    if trace_italics then
                        report_italics("method %a, flagging italic correction between %C and end math",method,correction,char)
                    end
                    setattr(pointer,a_mathitalics,101)
                    setattr(parent,a_mathitalics,101)
                end
            end
        end
    end
end

function handlers.italics(head,style,penalties)
    processnoads(head,italics,"italics")
    return true
end

local enable

enable = function()
    tasks.enableaction("math", "noads.handlers.italics")
    if trace_italics then
        report_italics("enabling math italics")
    end
    enable = false
end

-- best do this only on math mode (less overhead)

function mathematics.setitalics(name)
    if enable then
        enable()
    end
    texsetattribute(a_mathitalics,name and name ~= v_reset and tonumber(name) or unsetvalue) -- maybe also v_none
end

function mathematics.getitalics(name)
    if enable then
        enable()
    end
    context(name and name ~= v_reset and tonumber(name) or unsetvalue)
end

function mathematics.resetitalics()
    texsetattribute(a_mathitalics,unsetvalue)
end

implement {
    name      = "initializemathitalics",
    actions   = enable,
    onlyonce  = true,
}

implement {
    name      = "setmathitalics",
    actions   = mathematics.setitalics,
    arguments = "string",
}

implement {
    name      = "getmathitalics",
    actions   = mathematics.getitalics,
    arguments = "string",
}

implement {
    name      = "resetmathitalics",
    actions   = mathematics.resetitalics
}

-- primes and such

local collapse = { } processors.collapse = collapse

local mathpairs = characters.mathpairs -- next will move to char-def

mathpairs[0x2032] = { [0x2032] = 0x2033, [0x2033] = 0x2034, [0x2034] = 0x2057 } -- (prime,prime) (prime,doubleprime) (prime,tripleprime)
mathpairs[0x2033] = { [0x2032] = 0x2034, [0x2033] = 0x2057 }                    -- (doubleprime,prime) (doubleprime,doubleprime)
mathpairs[0x2034] = { [0x2032] = 0x2057 }                                       -- (tripleprime,prime)

mathpairs[0x2035] = { [0x2035] = 0x2036, [0x2036] = 0x2037 }                    -- (reversedprime,reversedprime) (reversedprime,doublereversedprime)
mathpairs[0x2036] = { [0x2035] = 0x2037 }                                       -- (doublereversedprime,reversedprime)

mathpairs[0x222B] = { [0x222B] = 0x222C, [0x222C] = 0x222D }
mathpairs[0x222C] = { [0x222B] = 0x222D }

mathpairs[0x007C] = { [0x007C] = 0x2016, [0x2016] = 0x2980 } -- bar+bar=double bar+double=triple
mathpairs[0x2016] = { [0x007C] = 0x2980 }                    -- double+bar=triple

local movesub = {
    -- primes
    [0x2032] = 0xFE932,
    [0x2033] = 0xFE933,
    [0x2034] = 0xFE934,
    [0x2057] = 0xFE957,
    -- reverse primes
    [0x2035] = 0xFE935,
    [0x2036] = 0xFE936,
    [0x2037] = 0xFE937,
}

local validpair = {
    [noad_rel]             = true,
    [noad_ord]             = true,
    [noad_bin]             = true, -- new
    [noad_punct]           = true, -- new
    [noad_opdisplaylimits] = true,
    [noad_oplimits]        = true,
    [noad_opnolimits]      = true,
}

local function movesubscript(parent,current_nucleus,current_char)
    local prev = getfield(parent,"prev")
    if prev and getid(prev) == math_noad then
        if not getfield(prev,"sup") and not getfield(prev,"sub") then
            -- {f} {'}_n => f_n^'
            setfield(current_nucleus,"char",movesub[current_char or getchar(current_nucleus)])
            local nucleus = getfield(parent,"nucleus")
            local sub     = getfield(parent,"sub")
            local sup     = getfield(parent,"sup")
            setfield(prev,"sup",nucleus)
            setfield(prev,"sub",sub)
            local dummy = copy_node(nucleus)
            setfield(dummy,"char",0)
            setfield(parent,"nucleus",dummy)
            setfield(parent,"sub",nil)
            if trace_collapsing then
                report_collapsing("fixing subscript")
            end
        elseif not getfield(prev,"sup") then
            -- {f} {'}_n => f_n^'
            setfield(current_nucleus,"char",movesub[current_char or getchar(current_nucleus)])
            local nucleus = getfield(parent,"nucleus")
            local sup     = getfield(parent,"sup")
            setfield(prev,"sup",nucleus)
            local dummy = copy_node(nucleus)
            setfield(dummy,"char",0)
            setfield(parent,"nucleus",dummy)
            if trace_collapsing then
                report_collapsing("fixing subscript")
            end
        end
    end
end

local function collapsepair(pointer,what,n,parent,nested) -- todo: switch to turn in on and off
    if parent then
        if validpair[getsubtype(parent)] then
            local current_nucleus = getfield(parent,"nucleus")
            if getid(current_nucleus) == math_char then
                local current_char = getchar(current_nucleus)
                if not getfield(parent,"sub") and not getfield(parent,"sup") then
                    local mathpair = mathpairs[current_char]
                    if mathpair then
                        local next_noad = getnext(parent)
                        if next_noad and getid(next_noad) == math_noad then
                            if validpair[getsubtype(next_noad)] then
                                local next_nucleus = getfield(next_noad,"nucleus")
                                local next_char    = getchar(next_nucleus)
                                if getid(next_nucleus) == math_char then
                                    local newchar = mathpair[next_char]
                                    if newchar then
                                        local fam        = getfield(current_nucleus,"fam")
                                        local id         = font_of_family(fam)
                                        local characters = fontcharacters[id]
                                        if characters and characters[newchar] then
                                            if trace_collapsing then
                                                report_collapsing("%U + %U => %U",current_char,next_char,newchar)
                                            end
                                            setfield(current_nucleus,"char",newchar)
                                            local next_next_noad = getnext(next_noad)
                                            if next_next_noad then
                                                setfield(parent,"next",next_next_noad)
                                                setfield(next_next_noad,"prev",parent)
                                            else
                                                setfield(parent,"next",nil)
                                            end
                                            setfield(parent,"sup",getfield(next_noad,"sup"))
                                            setfield(parent,"sub",getfield(next_noad,"sub"))
                                            setfield(next_noad,"sup",nil)
                                            setfield(next_noad,"sub",nil)
                                            free_node(next_noad)
                                            collapsepair(pointer,what,n,parent,true)
                                         -- if not nested and movesub[current_char] then
                                         --     movesubscript(parent,current_nucleus,current_char)
                                         -- end
                                        end
                                    elseif not nested and movesub[current_char] then
                                        movesubscript(parent,current_nucleus,current_char)
                                    end
                                end
                            end
                        elseif not nested and movesub[current_char] then
                            movesubscript(parent,current_nucleus,current_char)
                        end
                    elseif not nested and movesub[current_char] then
                        movesubscript(parent,current_nucleus,current_char)
                    end
                elseif not nested and movesub[current_char] then
                    movesubscript(parent,current_nucleus,current_char)
                end
            end
        end
    end
end

collapse[math_char] = collapsepair

function noads.handlers.collapse(head,style,penalties)
    processnoads(head,collapse,"collapse")
    return true
end

-- variants

local variants = { }

local validvariants = { -- fast check on valid
    [0x2229] = 0xFE00, [0x222A] = 0xFE00,
    [0x2268] = 0xFE00, [0x2269] = 0xFE00,
    [0x2272] = 0xFE00, [0x2273] = 0xFE00,
    [0x228A] = 0xFE00, [0x228B] = 0xFE00,
    [0x2293] = 0xFE00, [0x2294] = 0xFE00,
    [0x2295] = 0xFE00,
    [0x2297] = 0xFE00,
    [0x229C] = 0xFE00,
    [0x22DA] = 0xFE00, [0x22DB] = 0xFE00,
    [0x2A3C] = 0xFE00, [0x2A3D] = 0xFE00,
    [0x2A9D] = 0xFE00, [0x2A9E] = 0xFE00,
    [0x2AAC] = 0xFE00, [0x2AAD] = 0xFE00,
    [0x2ACB] = 0xFE00, [0x2ACC] = 0xFE00,
}

variants[math_char] = function(pointer,what,n,parent) -- also set export value
    local char = getchar(pointer)
    local selector = validvariants[char]
    if selector then
        local next = getnext(parent)
        if next and getid(next) == math_noad then
            local nucleus = getfield(next,"nucleus")
            if nucleus and getid(nucleus) == math_char and getchar(nucleus) == selector then
                local variant
                local tfmdata = fontdata[font_of_family(getfield(pointer,"fam"))] -- we can also have a famdata
                local mathvariants = tfmdata.resources.variants -- and variantdata
                if mathvariants then
                    mathvariants = mathvariants[selector]
                    if mathvariants then
                        variant = mathvariants[char]
                    end
                end
                if variant then
                    setfield(pointer,"char",variant)
                    setattr(pointer,a_exportstatus,char) -- we don't export the variant as it's visual markup
                    if trace_variants then
                        report_variants("variant (%U,%U) replaced by %U",char,selector,variant)
                    end
                else
                    if trace_variants then
                        report_variants("no variant (%U,%U)",char,selector)
                    end
                end
                setfield(next,"prev",pointer)
                setfield(parent,"next",getnext(next))
                free_node(next)
            end
        end
    end
end

function handlers.variants(head,style,penalties)
    processnoads(head,variants,"unicode variant")
    return true
end

-- for manuals

local classes = { }

local colors = {
    [noad_rel]             = "trace:dr",
    [noad_ord]             = "trace:db",
    [noad_bin]             = "trace:dg",
    [noad_open]            = "trace:dm",
    [noad_close]           = "trace:dm",
    [noad_punct]           = "trace:dc",
 -- [noad_opdisplaylimits] = "",
 -- [noad_oplimits]        = "",
 -- [noad_opnolimits]      = "",
 -- [noad_inner            = "",
 -- [noad_under            = "",
 -- [noad_over             = "",
 -- [noad_vcenter          = "",
}

classes[math_char] = function(pointer,what,n,parent)
    local color = colors[getsubtype(parent)]
    if color then
        setcolor(pointer,color)
    else
        resetcolor(pointer)
    end
end

function handlers.classes(head,style,penalties)
    processnoads(head,classes,"classes")
    return true
end

registertracker("math.classes",function(v) tasks.setaction("math","noads.handlers.classes",v) end)

-- experimental

do

 -- mathematics.registerdomain {
 --     name       = "foo",
 --     parents    = { "bar" },
 --     characters = {
 --         [0x123] = { char = 0x234, class = binary },
 --     },
 -- }

    local domains       = { }
    local categories    = { }
    local numbers       = { }
    local mclasses      = mathematics.classes
    local a_mathdomain  = privateattribute("mathdomain")

    mathematics.domains = categories

    local permitted     = {
        ordinary    = noad_ord,
        binary      = noad_bin,
        relation    = noad_rel,
        punctuation = noad_punct,
        inner       = noad_inner,
    }

    function mathematics.registerdomain(data)
        local name = data.name
        if not name then
            return
        end
        local attr       = #numbers + 1
        categories[name] = data
        numbers[attr]    = data
        data.attribute   = attr
        -- we delay hashing
        return attr
    end

    local enable

    enable = function()
        tasks.enableaction("math", "noads.handlers.domains")
        if trace_domains then
            report_domains("enabling math domains")
        end
        enable = false
    end

    function mathematics.setdomain(name)
        if enable then
            enable()
        end
        local data = name and name ~= v_reset and categories[name]
        texsetattribute(a_mathdomain,data and data.attribute or unsetvalue)
    end

    function mathematics.getdomain(name)
        if enable then
            enable()
        end
        local data = name and name ~= v_reset and categories[name]
        context(data and data.attribute or unsetvalue)
    end

    implement {
        name      = "initializemathdomain",
        actions   = enable,
        onlyonce  = true,
    }

    implement {
        name      = "setmathdomain",
        arguments = "string",
        actions   = mathematics.setdomain,
    }

    implement {
        name      = "getmathdomain",
        arguments = "string",
        actions   = mathematics.getdomain,
    }

    local function makehash(data)
        local hash    = { }
        local parents = data.parents
        if parents then
            local function merge(name)
                if name then
                    local c = categories[name]
                    if c then
                        local hash = c.hash
                        if not hash then
                            hash = makehash(c)
                        end
                        for k, v in next, hash do
                            hash[k] = v
                        end
                    end
                end
            end
            if type(parents) == "string" then
                merge(parents)
            elseif type(parents) == "table" then
                for i=1,#parents do
                    merge(parents[i])
                end
            end
        end
        local characters = data.characters
        if characters then
            for k, v in next, characters do
             -- local chr = n.char
                local cls = v.class
                if cls then
                    v.code = permitted[cls]
                else
                    -- invalid class
                end
                hash[k] = v
            end
        end
        data.hash = hash
        return hash
    end

    domains[math_char] = function(pointer,what,n,parent)
        local attr = getattr(pointer,a_mathdomain)
        if attr then
            local domain = numbers[attr]
            if domain then
                local hash = domain.hash
                if not hash then
                    hash = makehash(domain)
                end
                local char = getchar(pointer)
                local okay = hash[char]
                if okay then
                    local chr = okay.char
                    local cls = okay.code
                    if chr and chr ~= char then
                        setfield(pointer,"char",chr)
                    end
                    if cls and cls ~= getsubtype(parent) then
                        setfield(parent,"subtype",cls)
                    end
                end
            end
        end
    end

    function handlers.domains(head,style,penalties)
        processnoads(head,domains,"domains")
        return true
    end

end


-- just for me

function handlers.showtree(head,style,penalties)
    inspect(nodes.totree(head))
end

registertracker("math.showtree",function(v) tasks.setaction("math","noads.handlers.showtree",v) end)

-- the normal builder

function builders.kernel.mlist_to_hlist(head,style,penalties)
    return mlist_to_hlist(head,style,penalties), true
end

-- function builders.kernel.mlist_to_hlist(head,style,penalties)
--     print("!!!!!!! BEFORE",penalties)
--     for n in node.traverse(head) do print(n) end
--     print("!!!!!!!")
--     head = mlist_to_hlist(head,style,penalties)
--     print("!!!!!!! AFTER")
--     for n in node.traverse(head) do print(n) end
--     print("!!!!!!!")
--     return head, true
-- end

tasks.new {
    name      = "math",
    arguments = 2,
    processor = utilities.sequencers.nodeprocessor,
    sequence  = {
        "before",
        "normalizers",
        "builders",
        "after",
    },
}

tasks.freezegroup("math", "normalizers") -- experimental
tasks.freezegroup("math", "builders")    -- experimental

local actions = tasks.actions("math") -- head, style, penalties

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

function processors.mlist_to_hlist(head,style,penalties)
    starttiming(noads)
    local head, done = actions(head,style,penalties)
    stoptiming(noads)
    return head, done
end

callbacks.register('mlist_to_hlist',processors.mlist_to_hlist,"preprocessing math list")

-- tracing

statistics.register("math processing time", function()
    return statistics.elapsedseconds(noads)
end)
