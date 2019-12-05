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

-- todo: most is mathchar_code so we can have simple dedicated loops

-- nota bene: uunderdelimiter uoverdelimiter etc are radicals (we have 5 types)

local next, tonumber = next, tonumber
local utfchar, utfbyte = utf.char, utf.byte
local formatters, gmatch = string.formatters, string.gmatch
local sortedhash = table.sortedhash
local insert, remove = table.insert, table.remove
local div, round = math.div, math.round
local bor, band = bit32.bor, bit32.band

local fonts              = fonts
local nodes              = nodes
local node               = node
local mathematics        = mathematics
local context            = context

local otf                = fonts.handlers.otf
local otffeatures        = fonts.constructors.features.otf
local registerotffeature = otffeatures.register

local privateattribute   = attributes.private
local registertracker    = trackers.register
local registerdirective  = directives.register
local logreporter        = logs.reporter
local setmetatableindex  = table.setmetatableindex

local colortracers       = nodes.tracers.colors

local trace_remapping    = false  registertracker("math.remapping",   function(v) trace_remapping   = v end)
local trace_processing   = false  registertracker("math.processing",  function(v) trace_processing  = v end)
local trace_analyzing    = false  registertracker("math.analyzing",   function(v) trace_analyzing   = v end)
local trace_normalizing  = false  registertracker("math.normalizing", function(v) trace_normalizing = v end)
local trace_collapsing   = false  registertracker("math.collapsing",  function(v) trace_collapsing  = v end)
local trace_fixing       = false  registertracker("math.fixing",      function(v) trace_foxing      = v end)
local trace_patching     = false  registertracker("math.patching",    function(v) trace_patching    = v end)
local trace_goodies      = false  registertracker("math.goodies",     function(v) trace_goodies     = v end)
local trace_variants     = false  registertracker("math.variants",    function(v) trace_variants    = v end)
local trace_alternates   = false  registertracker("math.alternates",  function(v) trace_alternates  = v end)
local trace_italics      = false  registertracker("math.italics",     function(v) trace_italics     = v end)
local trace_kernpairs    = false  registertracker("math.kernpairs",   function(v) trace_kernpairs   = v end)
local trace_domains      = false  registertracker("math.domains",     function(v) trace_domains     = v end)
local trace_families     = false  registertracker("math.families",    function(v) trace_families    = v end)
local trace_fences       = false  registertracker("math.fences",      function(v) trace_fences      = v end)
local trace_unstacking   = false  registertracker("math.unstack",     function(v) trace_unstacking  = v end)

local check_coverage     = true   registerdirective("math.checkcoverage",  function(v) check_coverage  = v end)

local report_processing  = logreporter("mathematics","processing")
local report_remapping   = logreporter("mathematics","remapping")
local report_normalizing = logreporter("mathematics","normalizing")
local report_collapsing  = logreporter("mathematics","collapsing")
local report_fixing      = logreporter("mathematics","fixing")
local report_patching    = logreporter("mathematics","patching")
local report_goodies     = logreporter("mathematics","goodies")
local report_variants    = logreporter("mathematics","variants")
local report_alternates  = logreporter("mathematics","alternates")
local report_italics     = logreporter("mathematics","italics")
local report_kernpairs   = logreporter("mathematics","kernpairs")
local report_domains     = logreporter("mathematics","domains")
local report_families    = logreporter("mathematics","families")
local report_fences      = logreporter("mathematics","fences")
local report_unstacking  = logreporter("mathematics","unstack")

local a_mathrendering    = privateattribute("mathrendering")
local a_exportstatus     = privateattribute("exportstatus")

local nuts               = nodes.nuts
local nodepool           = nuts.pool
local tonut              = nuts.tonut
local nutstring          = nuts.tostring

local setfield           = nuts.setfield
local setlink            = nuts.setlink
local setlist            = nuts.setlist
local setnext            = nuts.setnext
local setprev            = nuts.setprev
local setchar            = nuts.setchar
local setfam             = nuts.setfam
local setsubtype         = nuts.setsubtype
local setattr            = nuts.setattr
local setattrlist        = nuts.setattrlist
local setwidth           = nuts.setwidth
local setheight          = nuts.setheight
local setdepth           = nuts.setdepth

local getfield           = nuts.getfield
local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getboth            = nuts.getboth
local getid              = nuts.getid
local getsubtype         = nuts.getsubtype
local getchar            = nuts.getchar
local getfont            = nuts.getfont
local getfam             = nuts.getfam
local getattr            = nuts.getattr
local getlist            = nuts.getlist
local getwidth           = nuts.getwidth
local getheight          = nuts.getheight
local getdepth           = nuts.getdepth

local getnucleus         = nuts.getnucleus
local getsub             = nuts.getsub
local getsup             = nuts.getsup

local setnucleus         = nuts.setnucleus
local setsub             = nuts.setsub
local setsup             = nuts.setsup

local flush_node         = nuts.flush
local copy_node          = nuts.copy
local slide_nodes        = nuts.slide
local set_visual         = nuts.setvisual

local mlist_to_hlist     = nuts.mlist_to_hlist

local new_kern           = nodepool.kern
local new_submlist       = nodepool.submlist
local new_noad           = nodepool.noad
local new_delimiter      = nodepool.delimiter
local new_fence          = nodepool.fence

local fonthashes         = fonts.hashes
local fontdata           = fonthashes.identifiers
local fontcharacters     = fonthashes.characters
local fontitalics        = fonthashes.italics

local variables          = interfaces.variables
local texsetattribute    = tex.setattribute
local texgetattribute    = tex.getattribute
local getfontoffamily    = tex.getfontoffamily
local unsetvalue         = attributes.unsetvalue
local implement          = interfaces.implement

local v_reset            = variables.reset

local chardata           = characters.data

noads                    = noads or { }  -- todo: only here
local noads              = noads

noads.processors         = noads.processors or { }
local processors         = noads.processors

noads.handlers           = noads.handlers   or { }
local handlers           = noads.handlers

local tasks              = nodes.tasks
local enableaction       = tasks.enableaction
local setaction          = tasks.setaction

local nodecodes          = nodes.nodecodes
local noadcodes          = nodes.noadcodes
local fencecodes         = nodes.fencecodes

local ordnoad_code             = noadcodes.ord
local opdisplaylimitsnoad_code = noadcodes.opdisplaylimits
local oplimitsnoad_code        = noadcodes.oplimits
local opnolimitsnoad_code      = noadcodes.opnolimits
local binnoad_code             = noadcodes.bin
local relnode_code             = noadcodes.rel
local opennoad_code            = noadcodes.open
local closenoad_code           = noadcodes.close
local punctnoad_code           = noadcodes.punct
local innernoad_code           = noadcodes.inner
local undernoad_code           = noadcodes.under
local overnoad_code            = noadcodes.over
local vcenternoad_code         = noadcodes.vcenter
local ordlimitsnoad_code       = noadcodes.ordlimits or oplimitsnoad_code

local noad_code          = nodecodes.noad           -- attr nucleus sub sup
local accent_code        = nodecodes.accent         -- attr nucleus sub sup accent
local radical_code       = nodecodes.radical        -- attr nucleus sub sup left degree
local fraction_code      = nodecodes.fraction       -- attr nucleus sub sup left right
local subbox_code        = nodecodes.subbox         -- attr list
local submlist_code      = nodecodes.submlist       -- attr list
local mathchar_code      = nodecodes.mathchar       -- attr fam char
local mathtextchar_code  = nodecodes.mathtextchar   -- attr fam char
local delim_code         = nodecodes.delim          -- attr small_fam small_char large_fam large_char
----- style_code         = nodecodes.style          -- attr style
----- parameter_code     = nodecodes.parameter      -- attr style
local math_choice        = nodecodes.choice         -- attr display text script scriptscript
local fence_code         = nodecodes.fence          -- attr subtype

local leftfence_code     = fencecodes.left
local middlefence_code   = fencecodes.middle
local rightfence_code    = fencecodes.right

-- local mathclasses          = mathematics.classes
-- local fenceclasses         = {
--     [leftfence_code]   = mathclasses.open,
--     [middlefence_code] = mathclasses.middle,
--     [rightfence_code]  = mathclasses.close,
-- }

-- this initial stuff is tricky as we can have removed and new nodes with the same address
-- the only way out is a free-per-page list of nodes (not bad anyway)

-- local gf = getfield local gt = setmetatableindex("number") getfield = function(n,f)   gt[f] = gt[f] + 1 return gf(n,f)   end mathematics.GETFIELD = gt
-- local sf = setfield local st = setmetatableindex("number") setfield = function(n,f,v) st[f] = st[f] + 1        sf(n,f,v) end mathematics.SETFIELD = st

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
            if id == noad_code then
                report_processing("%w%S, class %a",n*2,nutstring(start),noadcodes[getsubtype(start)])
            elseif id == mathchar_code then
                local char = getchar(start)
                local font = getfont(start)
                local fam  = getfam(start)
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
        elseif id == noad_code then
            -- single characters are like this
            local noad = getnucleus(start)              if noad then process(noad,what,n,start) end -- list
                  noad = getsup    (start)              if noad then process(noad,what,n,start) end -- list
                  noad = getsub    (start)              if noad then process(noad,what,n,start) end -- list
        elseif id == mathchar_code or id == mathtextchar_code or id == delim_code then
            break
        elseif id == subbox_code or id == submlist_code then
            local noad = getlist(start)                 if noad then process(noad,what,n,start) end -- list (not getlist !)
        elseif id == fraction_code then
            local noad = getfield(start,"num")          if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"denom")        if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"left")         if noad then process(noad,what,n,start) end -- delimiter
                  noad = getfield(start,"right")        if noad then process(noad,what,n,start) end -- delimiter
        elseif id == math_choice then
            local noad = getfield(start,"display")      if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"text")         if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"script")       if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"scriptscript") if noad then process(noad,what,n,start) end -- list
        elseif id == fence_code then
            local noad = getfield(start,"delim")        if noad then process(noad,what,n,start) end -- delimiter
        elseif id == radical_code then
            local noad = getnucleus(start)              if noad then process(noad,what,n,start) end -- list
                  noad = getsup    (start)              if noad then process(noad,what,n,start) end -- list
                  noad = getsub    (start)              if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"left")         if noad then process(noad,what,n,start) end -- delimiter
                  noad = getfield(start,"degree")       if noad then process(noad,what,n,start) end -- list
        elseif id == accent_code then
            local noad = getnucleus(start)              if noad then process(noad,what,n,start) end -- list
                  noad = getsup    (start)              if noad then process(noad,what,n,start) end -- list
                  noad = getsub    (start)              if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"accent")       if noad then process(noad,what,n,start) end -- list
                  noad = getfield(start,"bot_accent")   if noad then process(noad,what,n,start) end -- list
     -- elseif id == style_code then
     --     -- has a next
     -- elseif id == parameter_code then
     --     -- has a next
     -- else
     --     -- glue, penalty, etc
        end
        start = getnext(start)
    end
    if not parent then
        return initial -- only first level -- for now
    end
end

local function processnested(current,what,n)
    local noad = nil
    local id   = getid(current)
    if id == noad_code then
        noad = getnucleus(current)              if noad then process(noad,what,n,current) end -- list
        noad = getsup    (current)              if noad then process(noad,what,n,current) end -- list
        noad = getsub    (current)              if noad then process(noad,what,n,current) end -- list
    elseif id == subbox_code or id == submlist_code then
        noad = getlist(current)                 if noad then process(noad,what,n,current) end -- list (not getlist !)
    elseif id == fraction_code then
        noad = getfield(current,"num")          if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"denom")        if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"left")         if noad then process(noad,what,n,current) end -- delimiter
        noad = getfield(current,"right")        if noad then process(noad,what,n,current) end -- delimiter
    elseif id == math_choice then
        noad = getfield(current,"display")      if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"text")         if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"script")       if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"scriptscript") if noad then process(noad,what,n,current) end -- list
    elseif id == fence_code then
        noad = getfield(current,"delim")        if noad then process(noad,what,n,current) end -- delimiter
    elseif id == radical_code then
        noad = getnucleus(current)              if noad then process(noad,what,n,current) end -- list
        noad = getsup    (current)              if noad then process(noad,what,n,current) end -- list
        noad = getsub    (current)              if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"left")         if noad then process(noad,what,n,current) end -- delimiter
        noad = getfield(current,"degree")       if noad then process(noad,what,n,current) end -- list
    elseif id == accent_code then
        noad = getnucleus(current)              if noad then process(noad,what,n,current) end -- list
        noad = getsup    (current)              if noad then process(noad,what,n,current) end -- list
        noad = getsub    (current)              if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"accent")       if noad then process(noad,what,n,current) end -- list
        noad = getfield(current,"bot_accent")   if noad then process(noad,what,n,current) end -- list
    end
end

local function processstep(current,process,n,id)
    local noad = nil
    local id   = id or getid(current)
    if id == noad_code then
        noad = getnucleus(current)              if noad then process(noad,n,current) end -- list
        noad = getsup    (current)              if noad then process(noad,n,current) end -- list
        noad = getsub    (current)              if noad then process(noad,n,current) end -- list
    elseif id == subbox_code or id == submlist_code then
        noad = getlist(current)                 if noad then process(noad,n,current) end -- list (not getlist !)
    elseif id == fraction_code then
        noad = getfield(current,"num")          if noad then process(noad,n,current) end -- list
        noad = getfield(current,"denom")        if noad then process(noad,n,current) end -- list
        noad = getfield(current,"left")         if noad then process(noad,n,current) end -- delimiter
        noad = getfield(current,"right")        if noad then process(noad,n,current) end -- delimiter
    elseif id == math_choice then
        noad = getfield(current,"display")      if noad then process(noad,n,current) end -- list
        noad = getfield(current,"text")         if noad then process(noad,n,current) end -- list
        noad = getfield(current,"script")       if noad then process(noad,n,current) end -- list
        noad = getfield(current,"scriptscript") if noad then process(noad,n,current) end -- list
    elseif id == fence_code then
        noad = getfield(current,"delim")        if noad then process(noad,n,current) end -- delimiter
    elseif id == radical_code then
        noad = getnucleus(current)              if noad then process(noad,n,current) end -- list
        noad = getsup    (current)              if noad then process(noad,n,current) end -- list
        noad = getsub    (current)              if noad then process(noad,n,current) end -- list
        noad = getfield(current,"left")         if noad then process(noad,n,current) end -- delimiter
        noad = getfield(current,"degree")       if noad then process(noad,n,current) end -- list
    elseif id == accent_code then
        noad = getnucleus(current)              if noad then process(noad,n,current) end -- list
        noad = getsup    (current)              if noad then process(noad,n,current) end -- list
        noad = getsub    (current)              if noad then process(noad,n,current) end -- list
        noad = getfield(current,"accent")       if noad then process(noad,n,current) end -- list
        noad = getfield(current,"bot_accent")   if noad then process(noad,n,current) end -- list
    end
end

local function processnoads(head,actions,banner)
    if trace_processing then
        report_processing("start %a",banner)
        head = process(head,actions)
        report_processing("stop %a",banner)
    else
        head = process(head,actions)
    end
    return head
end

noads.process       = processnoads
noads.processnested = processnested
noads.processouter  = process

-- experiment (when not present fall back to fam 0) -- needs documentation

local unknowns = { }
local checked  = { } -- simple case
local tracked  = false  trackers.register("fonts.missing", function(v) tracked = v end)
local cached   = setmetatableindex("table") -- complex case

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

-- 0-2 regular
-- 3-5 bold
-- 6-8 pseudobold

-- this could best be integrated in the remapper, and if we run into problems, we
-- might as well do this

do

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

    families[fraction_code] = function(pointer,what,n,parent)
        local a = getattr(pointer,a_mathfamily)
        if a and a >= 0 then
            if a > 0 then
                setattr(pointer,a_mathfamily,0)
                if a > 5 then
                    a = a - 3
                end
            end
            setfam(pointer,a)
        end
        processnested(pointer,families,n+1)
    end

    families[noad_code] = function(pointer,what,n,parent)
        local a = getattr(pointer,a_mathfamily)
        if a and a >= 0 then
            if a > 0 then
                setattr(pointer,a_mathfamily,0)
                if a > 5 then
                    a = a - 3
                end
            end
            setfam(pointer,a)
        end
        processnested(pointer,families,n+1)
    end

    families[mathchar_code] = function(pointer)
        if getfam(pointer) == 0 then
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
                        setfam(pointer,newa)
                    elseif not fontcharacters[getfontoffamily(newa)][bold] then
                        if trace_families then
                            report_families("no bold character for %C, family %s with remap %s becomes %s with remap %s",char,a,familymap[a],newa,familymap[newa])
                        end
                        if newa > 3 then
                            setfam(pointer,newa-3)
                        end
                    else
                        setattr(pointer,a_exportstatus,char)
                        setchar(pointer,bold)
                        if trace_families then
                            report_families("replacing %C by bold %C, family %s with remap %s becomes %s with remap %s",char,bold,a,familymap[a],newa,familymap[newa])
                        end
                        setfam(pointer,newa)
                    end
                else
                    local char = getchar(pointer)
                    if not fontcharacters[getfontoffamily(a)][char] then
                        if trace_families then
                            report_families("no bold replacement for %C",char)
                        end
                    else
                        if trace_families then
                            report_families("family of %C becomes %s with remap %s",char,a,familymap[a])
                        end
                        setfam(pointer,a)
                    end
                end
            end
        end
    end
    families[delim_code] = function(pointer)
        if getfield(pointer,"small_fam") == 0 then
            local a = getattr(pointer,a_mathfamily)
            if a and a > 0 then
                setattr(pointer,a_mathfamily,0)
                if a > 5 then
                    -- no bold delimiters in unicode
                    a = a - 3
                end
                local char = getfield(pointer,"small_char")
                local okay = fontcharacters[getfontoffamily(a)][char]
                if okay then
                    setfield(pointer,"small_fam",a)
                elseif a > 2 then
                    setfield(pointer,"small_fam",a-3)
                end
                local char = getfield(pointer,"large_char")
                local okay = fontcharacters[getfontoffamily(a)][char]
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

    -- will become:

    -- families[delim_code] = function(pointer)
    --     if getfam(pointer) == 0 then
    --         local a = getattr(pointer,a_mathfamily)
    --         if a and a > 0 then
    --             setattr(pointer,a_mathfamily,0)
    --             if a > 5 then
    --                 -- no bold delimiters in unicode
    --                 a = a - 3
    --             end
    --             local char = getchar(pointer)
    --             local okay = fontcharacters[getfontoffamily(a)][char]
    --             if okay then
    --                 setfam(pointer,a)
    --             elseif a > 2 then
    --                 setfam(pointer,a-3)
    --             end
    --         else
    --             setfam(pointer,0)
    --         end
    --     end
    -- end

    families[mathtextchar_code] = families[mathchar_code]

    function handlers.families(head,style,penalties)
        processnoads(head,families,"families")
        return true -- not needed
    end

end

-- character remapping

do

    local a_mathalphabet    = privateattribute("mathalphabet")
    local a_mathgreek       = privateattribute("mathgreek")

    local relocate          = { }

    local remapalphabets    = mathematics.remapalphabets
    local fallbackstyleattr = mathematics.fallbackstyleattr
    local setnodecolor      = colortracers.set

    local function report_remap(tag,id,old,new,extra)
        report_remapping("remapping %s in font (%s,%s) from %C to %C%s",
            tag,id,fontdata[id].properties.fontname or "",old,new,extra)
    end

    local function checked(pointer)
        local char = getchar(pointer)
        local font = getfont(pointer)
        local data = fontcharacters[font]
        if not data[char] then
            local specials = characters.data[char].specials
            if specials and (specials[1] == "char" or specials[1] == "font") then
                local newchar = specials[#specials]
                if trace_remapping then
                    report_remap("fallback",font,char,newchar)
                end
                if trace_analyzing then
                    setnodecolor(pointer,"font:isol")
                end
                setattr(pointer,a_exportstatus,char) -- testcase: exponentiale
                setchar(pointer,newchar)
                return true
            end
        end
    end

    relocate[mathchar_code] = function(pointer)
        local g          = getattr(pointer,a_mathgreek) or 0
        local a          = getattr(pointer,a_mathalphabet) or 0
        local char       = getchar(pointer)
        local font       = getfont(pointer)
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
                local newchardata = characters[newchar]
                if newchardata then
                    if trace_remapping then
                        report_remap("char",font,char,newchar,newchardata.commands and " (virtual)" or "")
                    end
                    if trace_analyzing then
                        setnodecolor(pointer,"font:isol")
                    end
                    setchar(pointer,newchar)
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
                                setchar(pointer,newchar)
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
            elseif trace_remapping then
                local chardata = characters[char]
                if chardata and chardata.commands then
                    report_remap("char",font,char,char," (virtual)")
                end
            end
        end
        if not characters[char] then
            setchar(pointer,errorchar(font,char))
        end
        if trace_analyzing then
            setnodecolor(pointer,"font:medi")
        end
        if check_coverage then
            return checked(pointer)
        end
    end

    relocate[mathtextchar_code] = function(pointer)
        if trace_analyzing then
            setnodecolor(pointer,"font:init")
        end
    end

    relocate[delim_code] = function(pointer)
        if trace_analyzing then
            setnodecolor(pointer,"font:fina")
        end
    end

    function handlers.relocate(head,style,penalties)
        processnoads(head,relocate,"relocate")
        return true -- not needed
    end

end

-- rendering (beware, not exported)

do

    local render     = { }

    local rendersets = mathematics.renderings.numbers or { } -- store

    render[mathchar_code] = function(pointer)
        local attr = getattr(pointer,a_mathrendering)
        if attr and attr > 0 then
            local char = getchar(pointer)
            local renderset = rendersets[attr]
            if renderset then
                local newchar = renderset[char]
                if newchar then
                    local font       = getfont(pointer)
                    local characters = fontcharacters[font]
                    if characters and characters[newchar] then
                        setchar(pointer,newchar)
                        setattr(pointer,a_exportstatus,char)
                    end
                end
            end
        end
    end

    function handlers.render(head,style,penalties)
        processnoads(head,render,"render")
        return true -- not needed
    end

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

do

    local a_mathsize  = privateattribute("mathsize") -- this might move into other fence code
    local resize      = { }

    resize[fence_code] = function(pointer)
        local subtype = getsubtype(pointer)
        if subtype == leftfence_code or subtype == rightfence_code then
            local a = getattr(pointer,a_mathsize)
            if a and a > 0 then
                local method = div(a,100)
                local size   = a % 100
                setattr(pointer,a_mathsize,0)
                local delimiter = getfield(pointer,"delim")
                local chr = getchar(delimiter)
                if chr > 0 then
                    local fam = getfam(delimiter)
                    local id = getfontoffamily(fam)
                    if id > 0 then
                        local data = fontdata[id]
                        local char = mathematics.big(data,chr,size,method)
                        local ht   = getheight(pointer)
                        local dp   = getdepth(pointer)
                        if ht == 1 or dp == 1 then -- 1 scaled point is a signal
                            local chardata = data.characters[char]
                            if ht == 1 then
                                setheight(pointer,chardata.height)
                            end
                            if dp == 1 then
                                setdepth(pointer,chardata.depth)
                            end
                        end
                        if trace_fences then
                            report_fences("replacing %C by %C using method %a and size %a",chr,char,method,size)
                        end
                        setchar(delimiter,char)
                    end
                end
            end
        end
    end

    function handlers.resize(head,style,penalties)
        processnoads(head,resize,"resize")
        return true -- not needed
    end

end

-- still not perfect:

do

    local a_autofence     = privateattribute("mathautofence")
    local autofences      = { }
    local dummyfencechar  = 0x2E

    local function makefence(what,char)
        local d = new_delimiter() -- todo: attr
        local f = new_fence()     -- todo: attr
        if char then
            local sym = getnucleus(char)
            local chr = getchar(sym)
            local fam = getfam(sym)
            if chr == dummyfencechar then
                chr = 0
            end
            setchar(d,chr)
            setfam(d,fam)
            flush_node(sym)
        end
        setattrlist(d,char)
        setattrlist(f,char)
        setsubtype(f,what)
        setfield(f,"delim",d)
        setfield(f,"class",-1) -- tex itself does this, so not fenceclasses[what]
        return f
    end

    local function show(where,pointer)
        print("")
        local i = 0
        for n in nuts.traverse(pointer) do
            i = i + 1
            print(i,where,nuts.tonode(n))
        end
        print("")
    end

    local function makelist(middle,noad,f_o,o_next,c_prev,f_c)
-- report_fences(
--     "middle %s, noad %s, open %s, opennext %s, closeprev %s, close %s",
--     middle or "?",
--     noad   or "?",
--     f_o    or "?",
--     o_next or "?",
--     c_prev or "?",
--     f_c    or "?"
-- )
        local list = new_submlist()
        setsubtype(noad,innernoad_code)
        setnucleus(noad,list)
        setlist(list,f_o)
        setlink(f_o,o_next) -- prev of list is nil
        setlink(c_prev,f_c) -- next of list is nil
-- show("list",f_o)
        if middle and next(middle) then
            local prev    = f_o
            local current = o_next
            while current ~= f_c do
                local midl = middle[current]
                local next = getnext(current)
                if midl then
                    local fence = makefence(middlefence_code,current)
                    setnucleus(current)
                    flush_node(current)
                    middle[current] = nil
                    -- replace_node
                    setlink(prev,fence,next)
                    prev = fence
                else
                    prev = current
                end
                current = next
            end
        end
        return noad
    end

    -- relinking is now somewhat overdone

    local function convert_both(open,close,middle)
        local o_next = getnext(open)
        if o_next == close then
            return close
        else
            local c_prev, c_next = getboth(close)
            local f_o = makefence(leftfence_code,open)
            local f_c = makefence(rightfence_code,close)
            makelist(middle,open,f_o,o_next,c_prev,f_c)
            setnucleus(close)
            flush_node(close)
            -- open is now a list
            setlink(open,c_next)
            return open
        end
    end

    local function convert_open(open,last,middle) -- last is really last (final case)
        local f_o = makefence(leftfence_code,open)
        local f_c = makefence(rightfence_code)
        local o_next = getnext(open)
        makelist(middle,open,f_o,o_next,last,nil)
        -- open is now a list
        setlink(open,l_next)
        return open
    end

    local function convert_close(first,close,middle)
        local f_o = makefence(leftfence_code)
        local f_c = makefence(rightfence_code,close)
        local c_prev = getprev(close)
        local f_next = getnext(first)
        makelist(middle, close, f_o,f_next,c_prev,f_c)
        -- close is now a list
        if c_prev ~= first then
            setlink(first,close)
        end
        return close
    end

    local stacks = setmetatableindex("table")

    -- 1=open 2=close 3=middle 4=both

    local function processfences(pointer,n,parent)
        local current = pointer
        local last    = pointer
        local start   = pointer
        local done    = false
        local initial = pointer
        local stack   = nil
        local middle  = nil -- todo: use properties
        while current do
-- show("before",pointer)
            local id = getid(current)
            if id == noad_code then
                local a = getattr(current,a_autofence)
                if a and a > 0 then
                    local stack = stacks[n]
                    setattr(current,a_autofence,0) -- hm, better use a property
                    local level = #stack
                    if a == 1 then
                        if trace_fences then
                            report_fences("%2i: level %i, handling %s, action %s",n,level,"open","open")
                        end
                        insert(stack,current)
                    elseif a == 2 then
                        local open = remove(stack)
                        if open then
                            if trace_fences then
                                report_fences("%2i: level %i, handling %s, action %s",n,level,"close","both")
                            end
                            current = convert_both(open,current,middle)
                        elseif current == start then
                            if trace_fences then
                                report_fences("%2i: level %i, handling %s, action %s",n,level,"close","skip")
                            end
                        else
                            if trace_fences then
                                report_fences("%2i: level %i, handling %s, action %s",n,level,"close","close")
                            end
                            current = convert_close(initial,current,middle)
                            if not parent then
                                initial = current
                            end
                        end
                    elseif a == 3 then
                        if trace_fences then
                            report_fences("%2i: level %i, handling %s, action %s",n,level,"middle","middle")
                        end
                        if middle then
                            middle[current] = last
                        else
                            middle = { [current] = last }
                        end
                    elseif a == 4 then
                        if not stack or #stack == 0 then
                            if trace_fences then
                                report_fences("%2i: level %i, handling %s, action %s",n,level,"both","open")
                            end
                            insert(stack,current)
                        else
                            local open = remove(stack)
                            if open then
                                if trace_fences then
                                    report_fences("%2i: level %i, handling %s, action %s",n,level,"both","both")
                                end
                                current = convert_both(open,current,middle)
                            elseif current == start then
                                if trace_fences then
                                    report_fences("%2i: level %i, handling %s, action %s",n,level,"both","skip")
                                end
                            else
                                if trace_fences then
                                    report_fences("%2i: level %i, handling %s, action %s",n,level,"both","close")
                                end
                                current = convert_close(initial,current,middle)
                                if not parent then
                                    initial = current
                                end
                            end
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
-- show("after",pointer)
            last    = current
            current = getnext(current)
        end
        if done then
            local stack = stacks[n]
            local s = #stack
            if s > 0 then
                for i=1,s do
                    local open = remove(stack)
                    if trace_fences then
                        report_fences("%2i: level %i, handling %s, action %s",n,#stack,"flush","open")
                    end
                    last = convert_open(open,last,middle)
                end
-- show("done",pointer)
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
            enableaction("math","noads.handlers.autofences")
            enabled = true
        end
    }

    function handlers.autofences(head,style,penalties)
        if enabled then -- tex.modes.c_math_fences_auto
         -- inspect(nodes.totree(head))
            processfences(head,1)
         -- inspect(nodes.totree(head))
        end
    end

end

-- normalize scripts

do

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
        while next and getid(next) == noad_code do
            local nextnucleus = getnucleus(next)
            if nextnucleus and getid(nextnucleus) == mathchar_code and not getsub(next) and not getsup(next) then
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
                    setchar(nextnucleus,s)
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
                        setchar(nextnucleus,s)
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
                setsup(pointer,getnucleus(start_super))
            else
                local list = new_submlist() -- todo attr
                setlist(list,start_super)
                setsup(pointer,list)
            end
            if mode == "super" then
                setnext(pointer,getnext(stop_super))
            end
            setnext(stop_super)
        end
        if start_sub then

--             if mode == "sub" then
--                 local sup = getsup(pointer)
--                 if sup and not getsub(pointer) then
--                     local nxt = getnext(pointer)
--                     local new = new_noad(pointer)
--                     setnucleus(new,new_submlist())
--                     setlink(pointer,new,nxt)
--                     pointer = new
--                 end
--             end

            if start_sub == stop_sub then
                setsub(pointer,getnucleus(start_sub))
            else
                local list = new_submlist() -- todo attr
                setlist(list,start_sub)
                setsub(pointer,list)
            end
            if mode == "sub" then
                setnext(pointer,getnext(stop_sub))
            end
            setnext(stop_sub)
        end
        -- we could return stop
    end

    unscript[mathchar_code] = replace -- not noads as we need to recurse

    function handlers.unscript(head,style,penalties)
        processnoads(head,unscript,"unscript")
        return true -- not needed
    end

end

do

    local unstack   = { }    noads.processors.unstack = unstack
    local enabled   = false
    local a_unstack = privateattribute("mathunstack")

    unstack[noad_code] = function(pointer)
        if getattr(pointer,a_unstack) then
            local sup = getsup(pointer)
            local sub = getsub(pointer)
            if sup and sub then
             -- if trace_unstacking then
             --     report_unstacking() -- todo ... what to show ...
             -- end
                local nxt = getnext(pointer)
                local new = new_noad(pointer)
                setnucleus(new,new_submlist())
                setsub(pointer)
                setsub(new,sub)
                setlink(pointer,new,nxt)
            end
        end
    end

    function handlers.unstack(head,style,penalties)
        if enabled then
            processnoads(head,unstack,"unstack")
            return true -- not needed
        end
    end

    implement {
        name     = "enablescriptunstacking",
        onlyonce = true,
        actions  = function()
            enableaction("math","noads.handlers.unstack")
            enabled = true
        end
    }

end

do

    local function collected(list)
        if list and next(list) then
            local n, t = 0, { }
            for k, v in sortedhash(list) do
                n = n + 1
                t[n] = formatters["%C"](k)
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

end

-- math alternates: (in xits     lgf: $ABC$ $\cal ABC$ $\mathalternate{cal}\cal ABC$)
-- math alternates: (in lucidaot lgf: $ABC \mathalternate{italic} ABC$)

-- todo: set alternate for specific symbols
-- todo: no need to do this when already loaded
-- todo: use a fonts.hashes.mathalternates

do

    local last = 0

    local known = setmetatableindex(function(t,k)
        local v = bor(0,2^last)
        t[k] = v
        last = last + 1
        return v
    end)

    local defaults = {
        dotless = { feature = 'dtls', value = 1, comment = "Mathematical Dotless Forms" },
     -- zero    = { feature = 'zero', value = 1, comment = "Slashed or Dotted Zero" }, -- in no math font (yet)
    }

    local function initializemathalternates(tfmdata)
        local goodies  = tfmdata.goodies
        local autolist = defaults -- table.copy(defaults)

        local function setthem(newalternates)
            local resources      = tfmdata.resources -- was tfmdata.shared
            local mathalternates = resources.mathalternates
            local alternates, attributes, registered, presets
            if mathalternates then
                alternates = mathalternates.alternates
                attributes = mathalternates.attributes
                registered = mathalternates.registered
            else
                alternates, attributes, registered = { }, { }, { }
                mathalternates = {
                    attributes = attributes,
                    alternates = alternates,
                    registered = registered,
                    presets    = { },
                    resets     = { },
                    hashes     = setmetatableindex("table")
                }
                resources.mathalternates = mathalternates
            end
            --
            for name, data in sortedhash(newalternates) do
                if alternates[name] then
                    -- ignore
                else
                    local attr = known[name]
                    attributes[attr] = data
                    alternates[name] = attr
                    registered[#registered+1] = attr
                end
            end
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
    local alternate       = { } -- processors.alternate = alternate
    local fontdata        = fonts.hashes.identifiers
    local fontresources   = fonts.hashes.resources

    local function getalternate(fam,tag,current)
        local resources = fontresources[getfontoffamily(fam)]
        local attribute = unsetvalue
        if resources then
            local mathalternates = resources.mathalternates
            if mathalternates then
                local presets = mathalternates.presets
                if presets then
                    local resets = mathalternates.resets
                    attribute = presets[tag]
                    if not attribute then
                        attribute = 0
                        local alternates = mathalternates.alternates
                        for s in gmatch(tag,"[^, ]+") do
                            if s == v_reset then
                                resets[tag] = true
                                current = unsetvalue
                            else
                                local a = alternates[s] -- or known[s]
                                if a then
                                    attribute = bor(attribute,a)
                                end
                            end
                        end
                        if attribute == 0 then
                            attribute = unsetvalue
                        end
                        presets[tag] = attribute
                    elseif resets[tag] then
                        current = unsetvalue
                    end
                end
            end
        end
        if attribute > 0 and current and current > 0 then
            return bor(current,attribute)
        else
            return attribute
        end
    end

    local function presetalternate(fam,tag)
        texsetattribute(a_mathalternate,getalternate(fam,tag))
    end

    implement {
        name      = "presetmathalternate",
        actions   = presetalternate,
        arguments = { "integer", "string" }
    }

    local function setalternate(fam,tag)
        local a = texgetattribute(a_mathalternate)
        local v = getalternate(fam,tag,a)
        texsetattribute(a_mathalternate,v)
    end

    implement {
        name      = "setmathalternate",
        actions   = setalternate,
        arguments = { "integer", "string" }
    }

    alternate[mathchar_code] = function(pointer) -- slow
        local a = getattr(pointer,a_mathalternate)
        if a and a > 0 then
            setattr(pointer,a_mathalternate,0)
            local fontid    = getfont(pointer)
            local resources = fontresources[fontid]
            if resources then
                local mathalternates = resources.mathalternates
                if mathalternates then
                    local attributes = mathalternates.attributes
                    local registered = mathalternates.registered
                    local hashes     = mathalternates.hashes
                    for i=1,#registered do
                        local r = registered[i]
                        if band(a,r) ~= 0 then
                            local char = getchar(pointer)
                            local alt  = hashes[i][char]
                            if alt == nil then
                                local what = attributes[r]
                                alt = otf.getalternate(fontdata[fontid],char,what.feature,what.value) or false
                                if alt == char then
                                    alt = false
                                end
                                hashes[i][char] = alt
                            end
                            if alt then
                                if trace_alternates then
                                    local what = attributes[r]
                                    report_alternates("alternate %a, value %a, replacing glyph %U by glyph %U",
                                        tostring(what.feature),tostring(what.value),getchar(pointer),alt)
                                end
                                setchar(pointer,alt)
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    function handlers.alternates(head,style,penalties)
        processnoads(head,alternate,"alternate")
        return true -- not needed
    end

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

-- in opentype the italic correction of a limop is added to the width and luatex does
-- some juggling that we want to avoid but we need to do something here (in fact, we could
-- better fix the width of the character)

do

    local a_mathitalics = privateattribute("mathitalics")

    local italics        = { }
    local default_factor = 1/20

    local setcolor     = colortracers.set
    local resetcolor   = colortracers.reset
    local italic_kern  = new_kern

    local c_positive_d = "trace:dg"
    local c_negative_d = "trace:dr"

    local function insert_kern(current,kern)
        local sub  = new_submlist() -- todo: attr
        local noad = new_noad()     -- todo: attr
        setlist(sub,kern)
        setnext(kern,noad)
        setnucleus(noad,current)
        return sub
    end

    registertracker("math.italics.visualize", function(v)
        if v then
            italic_kern = function(k)
                local n = new_kern(k) -- todo: attr
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

    italics[mathchar_code] = function(pointer,what,n,parent)
        local method = getattr(pointer,a_mathitalics)
        if method and method > 0 and method < 100 then
            local char = getchar(pointer)
            local font = getfont(pointer)
            local correction, visual = getcorrection(method,font,char)
            if correction and correction ~= 0 then
                local next_noad = getnext(parent)
                if not next_noad then
                    if n == 1 then
                        -- only at the outer level .. will become an option (always,endonly,none)
                        if trace_italics then
                            report_italics("method %a, flagging italic correction %p between %C and end math",method,correction,char)
                        end
                        if correction > 0 then
                            correction = correction + 100
                        else
                            correction = correction - 100
                        end
                        correction = round(correction)
                        setattr(pointer,a_mathitalics,correction)
                        setattr(parent,a_mathitalics,correction)
                        return -- so no reset later on
                    end
                end
            end
        end
        setattr(pointer,a_mathitalics,unsetvalue)
    end

    function handlers.italics(head,style,penalties)
        processnoads(head,italics,"italics")
        return true -- not needed
    end

    local enable = function()
        enableaction("math", "noads.handlers.italics")
        if trace_italics then
            report_italics("enabling math italics")
        end
        -- we enable math (unless already enabled elsewhere)
        typesetters.italics.enablemath()
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

end

do

    -- math kerns (experiment) in goodies:
    --
    -- mathematics = {
    --     kernpairs = {
    --         [0x1D44E] = {
    --             [0x1D44F] = 400, -- 𝑎𝑏
    --         }
    --     },
    -- }

    local a_kernpairs = privateattribute("mathkernpairs")
    local kernpairs   = { }

    local function enable()
        enableaction("math", "noads.handlers.kernpairs")
        if trace_kernpairs then
            report_kernpairs("enabling math kern pairs")
        end
        enable = false
    end

    implement {
        name      = "initializemathkernpairs",
        actions   = enable,
        onlyonce  = true,
    }

    local hash = setmetatableindex(function(t,font)
        local g = fontdata[font].goodies
        local m = g and g[1] and g[1].mathematics
        local k = m and m.kernpairs
        t[font] = k
        return k
    end)

    -- no correction after prime because that moved to a superscript

    kernpairs[mathchar_code] = function(pointer,what,n,parent)
        if getattr(pointer,a_kernpairs) == 1 then
            local font = getfont(pointer)
            local list = hash[font]
            if list then
                local first = getchar(pointer)
                local found = list[first]
                if found then
                    local next = getnext(parent)
                    if next and getid(next) == noad_code then
                        pointer = getnucleus(next)
                        if pointer then
                            if getfont(pointer) == font then
                                local second = getchar(pointer)
                                local kern   = found[second]
                                if kern then
                                    kern = kern * fonts.hashes.parameters[font].hfactor
                                    if trace_kernpairs then
                                        report_kernpairs("adding %p kerning between %C and %C",kern,first,second)
                                    end
                                    setlink(parent,new_kern(kern),getnext(parent)) -- todo: attr
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    function handlers.kernpairs(head,style,penalties)
        processnoads(head,kernpairs,"kernpairs")
        return true -- not needed
    end

end

-- primes and such

do

    -- is validpair stil needed?

    local a_mathcollapsing = privateattribute("mathcollapsing")
    local collapse         = { }
    local mathlists        = characters.mathlists
    local validpair        = {
        [ordnoad_code]             = true,
        [opdisplaylimitsnoad_code] = true,
        [oplimitsnoad_code]        = true,
        [opnolimitsnoad_code]      = true,
        [binnoad_code]             = true, -- new
        [relnode_code]             = true,
        [opennoad_code]            = true, -- new
        [closenoad_code]           = true, -- new
        [punctnoad_code]           = true, -- new
        [innernoad_code]           = false,
        [undernoad_code]           = false,
        [overnoad_code]            = false,
        [vcenternoad_code]         = false,
        [ordlimitsnoad_code]       = true,
    }

    local reported = setmetatableindex("table")

    collapse[mathchar_code] = function(pointer,what,n,parent)

        if parent and mathlists[getchar(pointer)] then
            local found, last, lucleus, lsup, lsub, category
            local tree    = mathlists
            local current = parent
            while current and validpair[getsubtype(current)] do
                local nucleus = getnucleus(current) -- == pointer
                local sub     = getsub(current)
                local sup     = getsup(current)
                local char    = getchar(nucleus)
                if char then
                    local match = tree[char]
                    if match then
                        local method = getattr(current,a_mathcollapsing)
                        if method and method > 0 and method <= 3 then
                            local specials = match.specials
                            local mathlist = match.mathlist
                            local ligature
                            if method == 1 then
                                ligature = specials
                            elseif method == 2 then
                                ligature = specials or mathlist
                            else -- 3
                                ligature = mathlist or specials
                            end
                            if ligature then
                                category = mathlist and "mathlist" or "specials"
                                found    = ligature
                                last     = current
                                lucleus  = nucleus
                                lsup     = sup
                                lsub     = sub
                            end
                            tree = match
                            if sub or sup then
                                break
                            else
                                current = getnext(current)
                            end
                        else
                            break
                        end
                    else
                        break
                    end
                else
                    break
                end
            end
            if found and last and lucleus then
                local id         = getfont(lucleus)
                local characters = fontcharacters[id]
                local replace    = characters and characters[found]
                if not replace then
                    if not reported[id][found] then
                        reported[id][found] = true
                        report_collapsing("%s ligature %C from %s","ignoring",found,category)
                    end
                elseif trace_collapsing then
                    report_collapsing("%s ligature %C from %s","creating",found,category)
                end
                setchar(pointer,found)
                local l = getnext(last)
                local c = getnext(parent)
                if lsub then
                    setsub(parent,lsub)
                    setsub(last)
                end
                if lsup then
                    setsup(parent,lsup)
                    setsup(last)
                end
                while c ~= l do
                    local n = getnext(c)
                    flush_node(c)
                    c = n
                end
                setlink(parent,l)
            end
        end
    end

    function noads.handlers.collapse(head,style,penalties)
        processnoads(head,collapse,"collapse")
        return true -- not needed
    end

    local enable = function()
        enableaction("math", "noads.handlers.collapse")
        if trace_collapsing then
            report_collapsing("enabling math collapsing")
        end
        enable = false
    end

    implement {
        name      = "initializemathcollapsing",
        actions   = enable,
        onlyonce  = true,
    }

end

do
    -- inner under over vcenter

    local fixscripts = { }
    local movesub    = {
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

    mathematics.virtualize(movesub)

    local options_supported = tokens.defined("Unosuperscript")

    local function fixsupscript(parent,current,current_char,new_char)
        if new_char ~= current_char and new_char ~= true then
            setchar(current,new_char)
            if trace_fixing then
                report_fixing("fixing subscript, replacing superscript %U by %U",current_char,new_char)
            end
        else
            if trace_fixing then
                report_fixing("fixing subscript, superscript %U",current_char)
            end
        end
        if options_supported then
            setfield(parent,"options",0x08+0x22)
        end
    end

 -- local function movesubscript(parent,current_nucleus,oldchar,newchar)
 --     local prev = getprev(parent)
 --     if prev and getid(prev) == noad_code then
 --         local psup = getsup(prev)
 --         local psub = getsub(prev)
 --         if not psup and not psub then
 --             fixsupscript(prev,current_nucleus,oldchar,newchar)
 --             local nucleus = getnucleus(parent)
 --             local sub     = getsub(parent)
 --             setsup(prev,nucleus)
 --             setsub(prev,sub)
 --             local dummy = copy_node(nucleus)
 --             setchar(dummy,0)
 --             setnucleus(parent,dummy)
 --             setsub(parent)
 --         elseif not psup then
 --             fixsupscript(prev,current_nucleus,oldchar,newchar)
 --             local nucleus = getnucleus(parent)
 --             setsup(prev,nucleus)
 --             local dummy = copy_node(nucleus)
 --             setchar(dummy,0)
 --             setnucleus(parent,dummy)
 --         end
 --     end
 -- end

    local function move_none_none(parent,prev,nuc,oldchar,newchar)
        fixsupscript(prev,nuc,oldchar,newchar)
        local sub = getsub(parent)
        setsup(prev,nuc)
        setsub(prev,sub)
        local dummy = copy_node(nuc)
        setchar(dummy,0)
        setnucleus(parent,dummy)
        setsub(parent)
    end

    local function move_none_psub(parent,prev,nuc,oldchar,newchar)
        fixsupscript(prev,nuc,oldchar,newchar)
        setsup(prev,nuc)
        local dummy = copy_node(nuc)
        setchar(dummy,0)
        setnucleus(parent,dummy)
    end

    fixscripts[mathchar_code] = function(pointer,what,n,parent,nested) -- todo: switch to turn in on and off
        if parent then
            local oldchar = getchar(pointer)
            local newchar = movesub[oldchar]
            if newchar then
                local nuc = getnucleus(parent)
                if pointer == nuc then
                    local sub = getsub(pointer)
                    local sup = getsup(pointer)
                    if sub then
                        if sup then
                            -- print("[char] sub sup")
                        else
                            -- print("[char] sub ---")
                        end
                    elseif sup then
                        -- print("[char] --- sup")
                    else
                        local prev = getprev(parent)
                        if prev and getid(prev) == noad_code then
                            local psub = getsub(prev)
                            local psup = getsup(prev)
                            if psub then
                                if psup then
                                    -- print("sub sup [char] --- ---")
                                else
                                    -- print("sub --- [char] --- ---")
                                    move_none_psub(parent,prev,nuc,oldchar,newchar)
                                end
                            elseif psup then
                                -- print("--- sup [char] --- ---")
                            else
                                -- print("[char] --- ---")
                                move_none_none(parent,prev,nuc,oldchar,newchar)
                            end
                        else
                            -- print("no prev [char]")
                        end
                    end
                else
                    -- print("[char]")
                end
            end
        end
    end

    function noads.handlers.fixscripts(head,style,penalties)
        processnoads(head,fixscripts,"fixscripts")
        return true -- not needed
    end

end

-- variants

do

    local variants      = { }
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

    variants[mathchar_code] = function(pointer,what,n,parent) -- also set export value
        local char = getchar(pointer)
        local selector = validvariants[char]
        if selector then
            local next = getnext(parent)
            if next and getid(next) == noad_code then
                local nucleus = getnucleus(next)
                if nucleus and getid(nucleus) == mathchar_code and getchar(nucleus) == selector then
                    local variant
                    local tfmdata = fontdata[getfont(pointer)]
                    local mathvariants = tfmdata.resources.variants -- and variantdata
                    if mathvariants then
                        mathvariants = mathvariants[selector]
                        if mathvariants then
                            variant = mathvariants[char]
                        end
                    end
                    if variant then
                        setchar(pointer,variant)
                        setattr(pointer,a_exportstatus,char) -- we don't export the variant as it's visual markup
                        if trace_variants then
                            report_variants("variant (%U,%U) replaced by %U",char,selector,variant)
                        end
                    else
                        if trace_variants then
                            report_variants("no variant (%U,%U)",char,selector)
                        end
                    end
                    setprev(next,pointer)
                    setnext(parent,getnext(next))
                    flush_node(next)
                end
            end
        end
    end

    function handlers.variants(head,style,penalties)
        processnoads(head,variants,"unicode variant")
        return true -- not needed
    end

end

-- for manuals

do

    local classes = { }
    local colors  = {
        [relnode_code]             = "trace:dr",
        [ordnoad_code]             = "trace:db",
        [binnoad_code]             = "trace:dg",
        [opennoad_code]            = "trace:dm",
        [closenoad_code]           = "trace:dm",
        [punctnoad_code]           = "trace:dc",
     -- [opdisplaylimitsnoad_code] = "",
     -- [oplimitsnoad_code]        = "",
     -- [opnolimitsnoad_code]      = "",
     -- [ordlimitsnoad_code]       = "",
     -- [innernoad_code            = "",
     -- [undernoad_code]           = "",
     -- [overnoad_code]            = "",
     -- [vcenternoad_code]         = "",
    }

    local setcolor   = colortracers.set
    local resetcolor = colortracers.reset

    classes[mathchar_code] = function(pointer,what,n,parent)
        local color = colors[getsubtype(parent)]
        if color then
            setcolor(pointer,color)
        else
            resetcolor(pointer)
        end
    end

    function handlers.classes(head,style,penalties)
        processnoads(head,classes,"classes")
        return true -- not needed
    end

    registertracker("math.classes",function(v)
        setaction("math","noads.handlers.classes",v)
    end)

end

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
    local a_mathdomain  = privateattribute("mathdomain")
    mathematics.domains = categories
    local permitted     = {
        ordinary    = ordnoad_code,
        binary      = binnoad_code,
        relation    = relnode_code,
        punctuation = punctnoad_code,
        inner       = innernoad_code,
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
        enableaction("math", "noads.handlers.domains")
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

    domains[mathchar_code] = function(pointer,what,n,parent)
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
                        setchar(pointer,chr)
                    end
                    if cls and cls ~= getsubtype(parent) then
                        setsubtype(parent,cls)
                    end
                end
            end
        end
    end

    function handlers.domains(head,style,penalties)
        processnoads(head,domains,"domains")
        return true -- not needed
    end

end

-- just for me

function handlers.showtree(head,style,penalties)
    inspect(nodes.totree(tonut(head)))
end

registertracker("math.showtree",function(v)
    setaction("math","noads.handlers.showtree",v)
end)

-- also for me

do

    local applyvisuals = nuts.applyvisuals
    local visual       = false

    function handlers.makeup(head)
        applyvisuals(head,visual)
    end

    registertracker("math.makeup",function(v)
        visual = v
        setaction("math","noads.handlers.makeup",v)
    end)

end

-- the normal builder

do

    local force_penalties = false

 -- registertracker("math.penalties",function(v)
 --     force_penalties = v
 -- end)

    function builders.kernel.mlist_to_hlist(head,style,penalties)
        return mlist_to_hlist(head,style,force_penalties or penalties)
    end

 -- function builders.kernel.mlist_to_hlist(head,style,penalties)
 --     local h = mlist_to_hlist(head,style,force_penalties or penalties)
 --     inspect(nodes.totree(h,true,true,true))
 --     return h
 -- end

    implement {
        name      = "setmathpenalties",
        arguments = "integer",
        actions   = function(p)
            force_penalties = p > 0
        end,
    }

end

local actions = tasks.actions("math") -- head, style, penalties

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

function processors.mlist_to_hlist(head,style,penalties)
    starttiming(noads)
    head = actions(head,style,penalties)
    stoptiming(noads)
    return head
end

callbacks.register('mlist_to_hlist',processors.mlist_to_hlist,"preprocessing math list")

-- tracing

statistics.register("math processing time", function()
    return statistics.elapsedseconds(noads)
end)
