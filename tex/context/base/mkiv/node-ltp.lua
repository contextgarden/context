if not modules then modules = { } end modules ['node-par'] = {
    version   = 1.001,
    comment   = "companion to node-par.mkiv",
    author    = "Hans Hagen",
    copyright = "ConTeXt Development Team",
    license   = "see context related readme files",
    comment   = "a translation of the built in parbuilder, initial convertsin by Taco Hoekwater",
}

-- todo: remove nest_stack from linebreak.w
-- todo: permit global steps i.e. using an attribute that sets min/max/step and overloads the font parameters
-- todo: split the three passes into three functions
-- todo: see if we can do without delta nodes (needs thinking)
-- todo: add more mkiv like tracing
-- todo: add a couple of plugin hooks
-- todo: fix line numbers (cur_list.pg_field needed)
-- todo: optimize a bit more (less par.*)

-- issue: ls / rs added when zero content and normalize

--[[

    This code is derived from traditional TeX and has bits of pdfTeX, Aleph (Omega), and of course LuaTeX. So,
    the basic algorithm for sure is not our work. On the other hand, the directional model in LuaTeX is cleaned
    up as is other code. And of course there are hooks for callbacks.

    The first version of the code below was a conversion of the C code that in turn was a conversion from the
    original Pascal code. Around September 2008 we experimented with cq. discussed possible approaches to improved
    typesetting of Arabic and as our policy is that extensions happen in Lua this means that we need a parbuilder
    in Lua. Taco's first conversion still looked quite C-ish and in the process of cleaning up we uncovered some odd
    bits and pieces in the original code as well. I did some first cleanup to get rid of C-artefacts, and Taco and I
    spent the usual amount of Skyping to sort out problems. At that point we diverted to other LuaTeX issues.

    A while later I decided to pick up this thread and decided to look into better ways to deal with font expansion
    (aka hz). I got it running using a simpler method. One reason why the built-in mechanims is slow is that there is
    lots of redudancy in calculations. Expanded widths are recalculated each time and because the hpakc routine does
    it again that gives some overhead. In the process extra fonts are created with different dimensions so that the
    backend can deal with it. The alternative method doesn't create fonts but passes an expansion factor to the
    pdf generator. The small patch needed for the backend code worked more or less okay but was never intergated into
    LuaTeX due to lack of time.

    This all happened in 2010 while listening to Peter Gabriels "Scratch My Back" and Camels "Rayaz" so it was a
    rather relaxed job.

    In 2012 I picked up this thread. Because both languages are similar but also quite different it took some time
    to get compatible output. Because the C code uses macros, careful checking was needed. Of course Lua's table model
    and local variables brought some work as well. And still the code looks a bit C-ish. We could not divert too much
    from the original model simply because it's well documented but future versions (or variants) might as well look
    different.

    Eventually I'll split this code into passes so that we can better see what happens, but first we need to reach
    a decent level of stability. The current expansion results are not the same as the built-in but that was never
    the objective. It all has to do with slightly different calculations.

    The original C-code related to protrusion and expansion is not that efficient as many (redundant) function
    calls take place in the linebreaker and packer. As most work related to fonts is done in the backend, we
    can simply stick to width calculations here. Also, it is no problem at all that we use floating point
    calculations (as Lua has only floats). The final result will look ok as the hpack will nicely compensate
    for rounding errors as it will normally distribute the content well enough. And let's admit: most texies
    won't see it anyway. As long as we're cross platform compatible it's fine.

    We use the table checked_expansion to keep track of font related parameters (per paragraph). The table is
    also the signal that we have adjustments > 1. In retrospect one might wonder if adjusting kerns is such a
    good idea because other spacing is also not treated. If we would stick to the regular hpack routine
    we do have to follow the same logic, but I decided to use a Lua hpacker so that constraint went away. And
    anyway, instead of doing a lookup in the kern table (that we don't have in node mode) the set kern value
    is used. Disabling kern scaling will become an option in Luatex some day. You can blame me for all errors
    that crept in and I know that there are some.

    To be honest, I slowly start to grasp the magic here as normally I start from scratch when implementing
    something (as it's the only way I can understand things). This time I had a recently acquired stack of
    Porcupine Tree disks to get me through, although I must admit that watching their dvd's is more fun
    than coding.

    Picking up this effort was inspired by discussions between Luigi Scarso and me about efficiency of Lua
    code and we needed some stress tests to compare regular LuaTeX and LuajitTeX. One of the tests was
    processing tufte.tex as that one has lots of hyphenations and is a tough one to get right.

    tufte: boxed 1000 times, no flushing in backend:

                           \testfeatureonce{1000}{\setbox0\hbox{\tufte}}
                           \testfeatureonce{1000}{\setbox0\vbox{\tufte}}
    \startparbuilder[basic]\testfeatureonce{1000}{\setbox0\vbox{\tufte}}\stopparbuilder

                method     normal   hz      comment

    luatex      tex hbox    9.64     9.64   baseline font feature processing, hyphenation etc: 9.74
                tex vbox    9.84    10.16   0.20 linebreak / 0.52 with hz -> 0.32 hz overhead (150pct more)
                lua vbox   17.28    18.43   7.64 linebreak / 8.79 with hz -> 1.33 hz overhead ( 20pct more)

    new laptop | no nuts
                            3.42            baseline
                            3.63            0.21 linebreak
                            7.38            3.96 linebreak

    new laptop | most nuts
                            2.45            baseline
                            2.53            0.08 linebreak
                            6.16            3.71 linebreak
                 ltp nuts   5.45            3.00 linebreak

    luajittex   tex hbox    6.33     6.33   baseline font feature processing, hyphenation etc: 6.33
                tex vbox    6.53     6.81   0.20 linebreak / 0.48 with hz -> 0.28 hz overhead (expected 0.32)
                lua vbox   11.06    11.81   4.53 linebreak / 5.28 with hz -> 0.75 hz overhead

    new laptop | no nuts
                            2.06            baseline
                            2.27            0.21 linebreak
                            3.95            1.89 linebreak

    new laptop | most nuts
                            1.25            baseline
                            1.30            0.05 linebreak
                            3.03            1.78 linebreak
                 ltp nuts   2.47            1.22 linebreak

    Interesting is that the runtime for the built-in parbuilder indeed increases much when expansion
    is enabled, but in the Lua variant the extra overhead is way less significant. This means that when we
    retrofit the same approach into the core, the overhead of expansion can be sort of nilled.

    In 2013 the expansion factor method became also used at the TeX end so then I could complete the code
    here, and indeed, expansions works quite well now (not compatible of course because we use floats at
    the Lua end. The Lua base variant is still slower but quite ok, especially if we go nuts.

    A next iteration will provide plug-ins and more control. I will also explore the possibility to avoid
    the redundant hpack calculations (easier now, although I've only done some quick and dirty experiments.)

    The code has been adapted to the more reasonable and simplified direction model.

    In case I forget when I added the normalization code: it was november 2019 and it took me way more time
    than usual because I got distracted after discovering Alyona Yarushina on YT (in november 2019) which
    blew some fuses in the musical aware part of my brain in a similar way as when I discovered Kate Bush,
    so I had to watch a whole lot of her perfect covers (multiple times and for sure many more times). A
    new benchmark.

]]--

local unpack = unpack

-- local fonts, nodes, node = fonts, nodes, node -- too many locals

local trace_basic         = false  trackers.register("builders.paragraphs.basic",       function(v) trace_basic       = v end)
local trace_lastlinefit   = false  trackers.register("builders.paragraphs.lastlinefit", function(v) trace_lastlinefit = v end)
local trace_adjusting     = false  trackers.register("builders.paragraphs.adjusting",   function(v) trace_adjusting   = v end)
local trace_protruding    = false  trackers.register("builders.paragraphs.protruding",  function(v) trace_protruding  = v end)
local trace_expansion     = false  trackers.register("builders.paragraphs.expansion",   function(v) trace_expansion   = v end)

local report_parbuilders  = logs.reporter("nodes","parbuilders")
----- report_hpackers     = logs.reporter("nodes","hpackers")

local calculate_badness   = tex.badness
local texlists            = tex.lists
local texget              = tex.get
local texset              = tex.set
local texgetglue          = tex.getglue

-- (t == 0 and 0) or (s <= 0 and 10000) or calculate_badness(t,s)

-- local function calculate_badness(t,s)
--     if t == 0 then
--         return 0
--     elseif s <= 0 then
--         return 10000 -- infinite_badness
--     else
--         local r
--         if t <= 7230584 then
--             r = (t * 297) / s
--         elseif s >= 1663497 then
--             r = t / (s / 297)
--         else
--             r = t
--         end
--         if r > 1290 then
--             return 10000 -- infinite_badness
--         else
--             return (r * r * r + 0x20000) / 0x40000
--         end
--     end
-- end

local parbuilders             = builders.paragraphs
local constructors            = parbuilders.constructors

local setmetatableindex       = table.setmetatableindex

local fonthashes              = fonts.hashes
local chardata                = fonthashes.characters
local quaddata                = fonthashes.quads
local parameters              = fonthashes.parameters

local nuts                    = nodes.nuts
local tonut                   = nuts.tonut

local getfield                = nuts.getfield
local getid                   = nuts.getid
local getsubtype              = nuts.getsubtype
local getnext                 = nuts.getnext
local getprev                 = nuts.getprev
local getboth                 = nuts.getboth
local getlist                 = nuts.getlist
local getdisc                 = nuts.getdisc
local getattr                 = nuts.getattr
local getdisc                 = nuts.getdisc
local getglue                 = nuts.getglue
local getwhd                  = nuts.getwhd
local getkern                 = nuts.getkern
local getpenalty              = nuts.getpenalty
local getdirection            = nuts.getdirection
local getshift                = nuts.getshift
local getwidth                = nuts.getwidth
local getheight               = nuts.getheight
local getdepth                = nuts.getdepth
local getdata                 = nuts.getdata
local getreplace              = nuts.getreplace
local setreplace              = nuts.setreplace
local getpost                 = nuts.getpost
local setpost                 = nuts.setpost
local getpre                  = nuts.getpre
local setpre                  = nuts.setpre

local isglyph                 = nuts.isglyph
local start_of_par            = nuts.start_of_par

local setfield                = nuts.setfield
local setlink                 = nuts.setlink
local setlist                 = nuts.setlist
local setboth                 = nuts.setboth
local setnext                 = nuts.setnext
local setprev                 = nuts.setprev
local setdisc                 = nuts.setdisc
local setsubtype              = nuts.setsubtype
local setglue                 = nuts.setglue
local setwhd                  = nuts.setwhd
local setkern                 = nuts.setkern
local setdirection            = nuts.setdirection
local setshift                = nuts.setshift
local setwidth                = nuts.setwidth
local setexpansion            = nuts.setexpansion

local find_tail               = nuts.tail
local copy_node               = nuts.copy
local flush_node              = nuts.flush
local flush_node_list         = nuts.flush_list
----- hpack_nodes             = nuts.hpack
local xpack_nodes             = nuts.hpack
local replace_node            = nuts.replace
local remove_node             = nuts.remove
local insert_node_after       = nuts.insert_after
local insert_node_before      = nuts.insert_before
local is_zero_glue            = nuts.is_zero_glue
local is_skipable             = nuts.protrusion_skippable
local setattributelist        = nuts.setattributelist
local find_node               = nuts.find_node

local nextnode                = nuts.traversers.node
local nextglue                = nuts.traversers.glue

local nodepool                = nuts.pool

local nodecodes               = nodes.nodecodes
local kerncodes               = nodes.kerncodes
local margincodes             = nodes.margincodes
local disccodes               = nodes.disccodes
local mathcodes               = nodes.mathcodes
local fillcodes               = nodes.fillcodes
local gluecodes               = nodes.gluecodes

local temp_code               = nodecodes.temp
local glyph_code              = nodecodes.glyph
local ins_code                = nodecodes.ins
local mark_code               = nodecodes.mark
local adjust_code             = nodecodes.adjust
local penalty_code            = nodecodes.penalty
local disc_code               = nodecodes.disc
local math_code               = nodecodes.math
local kern_code               = nodecodes.kern
local glue_code               = nodecodes.glue
local hlist_code              = nodecodes.hlist
local vlist_code              = nodecodes.vlist
local unset_code              = nodecodes.unset
local marginkern_code         = nodecodes.marginkern
local dir_code                = nodecodes.dir
local boundary_code           = nodecodes.boundary
local localpar_code           = nodecodes.localpar

local protrusionboundary_code = nodes.boundarycodes.protrusion
local leaders_code            = nodes.leadercodes.leaders
local indentlist_code         = nodes.listcodes.indent
local ligatureglyph_code      = nodes.glyphcodes.ligature
local cancel_code             = nodes.dircodes.cancel

local userkern_code           = kerncodes.userkern
local italickern_code         = kerncodes.italiccorrection
local fontkern_code           = kerncodes.fontkern
local accentkern_code         = kerncodes.accentkern

local leftmargin_code         = margincodes.left
----- rightmargin_code        = margincodes.right

local automaticdisc_code      = disccodes.automatic
local regulardisc_code        = disccodes.regular
local firstdisc_code          = disccodes.first
local seconddisc_code         = disccodes.second

local spaceskip_code          = gluecodes.spaceskip
local xspaceskip_code         = gluecodes.xspaceskip
local rightskip_code          = gluecodes.rightskip

local endmath_code            = mathcodes.endmath

local righttoleft_code        = nodes.dirvalues.righttoleft

local nosubtype_code          = 0

local unhyphenated_code       = nodecodes.unhyphenated or 1
local hyphenated_code         = nodecodes.hyphenated   or 2
local delta_code              = nodecodes.delta        or 3
local passive_code            = nodecodes.passive      or 4

local maxdimen                = number.maxdimen

local max_halfword            = 0x7FFFFFFF
local infinite_penalty        =  10000
local eject_penalty           = -10000
local infinite_badness        =  10000
local awful_badness           = 0x3FFFFFFF
local ignore_depth            = -65536000

local fit_very_loose_class    = 0  -- fitness for lines stretching more than their stretchability
local fit_loose_class         = 1  -- fitness for lines stretching 0.5 to 1.0 of their stretchability
local fit_decent_class        = 2  -- fitness for all other lines
local fit_tight_class         = 3  -- fitness for lines shrinking 0.5 to 1.0 of their shrinkability

local new_penalty             = nodepool.penalty
local new_direction           = nodepool.direction
local new_leftmarginkern      = nodepool.leftmarginkern
local new_rightmarginkern     = nodepool.rightmarginkern
local new_leftskip            = nodepool.leftskip
local new_rightskip           = nodepool.rightskip
local new_lefthangskip        = nodepool.lefthangskip
local new_righthangskip       = nodepool.righthangskip
local new_indentskip          = nodepool.indentskip
local new_correctionskip      = nodepool.correctionskip
local new_lineskip            = nodepool.lineskip
local new_baselineskip        = nodepool.baselineskip
local new_temp                = nodepool.temp
local new_rule                = nodepool.rule
local new_hlist               = nodepool.hlist

local getnormalizeline        = nuts.getnormalizeline

-- helpers --

-- It makes more sense to move the somewhat messy dir state tracking
-- out of the main functions. First we create a stack allocator.

-- The next function checks a dir node and returns the new dir state. By
-- using a static table we are quite efficient. This function is used
-- in the parbuilder.

local function checked_line_dir(stack,current) -- can be inlined now
    local direction, pop = getdirection(current)
    local n = stack.n
    if not pop then
        n = n + 1
        stack.n = n
        stack[n] = direction
        return direction
    elseif n > 0 then
        n = n - 1
        stack.n = n
        return stack[n]
    else
        report_parbuilders("warning: missing pop node (%a)",1) -- in line ...
    end
end

-- The next function checks dir nodes in a list and injects dir nodes
-- that are currently needed.

local function inject_dirs_at_begin_of_line(stack,current)
    local n = stack.n
    if n > 0 then
        local h = current
        for i=1,n do
            local d = new_direction(stack[i])
            setattributelist(d,current)
            h, current = insert_node_after(h,current,d)
        end
        stack.n = 0
        return h
    else
        return current
    end
end

local function inject_dirs_at_end_of_line(stack,current,start,stop)
    local n = stack.n
    while start and start ~= stop do
        local id = getid(start)
        if id == dir_code then
            local direction, pop = getdirection(start)
            if not pop then
                n = n + 1
                stack[n] = direction
            elseif n > 0 then
if direction == stack[n] then
    -- like in the engine
                n = n - 1
end
            else
                report_parbuilders("warning: missing pop node (%a)",2) -- in line ...
            end
        end
        start = getnext(start)
    end
    if n > 0 then
        -- from 1,n and before
        local h = start
        for i=n,1,-1 do
            local d = new_direction(stack[i],true)
            setattributelist(d,start)
            h, current = insert_node_after(h,current,d)
        end
    end
    stack.n = n
    return current
end

local ignore_math_skip = node.direct.ignore_math_skip or function(current)
    local mode = texget("mathskipmode")
    if mode == 6 or mode == 7 then
        local b = true
        local n = getsubtype(current) == endmath_code and getnext(current) or getprev(current)
        if n and getid(n) == glue_code then
            local s = getsubtype(n)
            if s == spaceskip_code or s == xspaceskip_code then
                b = false
            end
        end
        if mode == 7 then
            b = not b
        end
        if b then
            setglue(current)
            return true
        end
    end
    return false
end

-- diagnostics --

local dummy = function() end

local diagnostics = {
    start          = dummy,
    stop           = dummy,
    current_pass   = dummy,
    break_node     = dummy,
    feasible_break = dummy,
}

-- statistics --

local nofpars, noflines, nofprotrudedlines, nofadjustedlines = 0, 0, 0, 0

local function register_statistics(par)
    local statistics  = par.statistics
    nofpars           = nofpars           + 1
    noflines          = noflines          + statistics.noflines
    nofprotrudedlines = nofprotrudedlines + statistics.nofprotrudedlines
    nofadjustedlines  = nofadjustedlines  + statistics.nofadjustedlines
end

-- expansion etc --

local function calculate_fraction(x,n,d,max_answer)
    local the_answer = x * n/d + 1/2 -- round ?
    if the_answer > max_answer then
        return  max_answer
    elseif the_answer < -max_answer then
        return -max_answer
    else
        return  the_answer
    end
end

local function infinite_shrinkage_error(par)
    if par.no_shrink_error_yet then
        par.no_shrink_error_yet = false
        report_parbuilders("infinite glue shrinkage found in a paragraph and removed")
    end
end

-- It doesn't really speed up much but the additional memory usage is
-- rather small so it doesn't hurt too much.

local expansions = { }
local nothing    = { stretch = 0, shrink = 0 } -- or just true or so

-- setmetatableindex(expansions,function(t,font) -- we can store this in tfmdata if needed
--     local expansion = parameters[font].expansion -- can be an extra hash
--     if expansion and expansion.step ~= 0 then
--         local stretch = expansion.stretch
--         local shrink  = expansion.shrink
--         if shrink ~= 0 or stretch ~= 0 then
--             local factors = { }
--             local c = chardata[font]
--             setmetatableindex(factors,function(t,char)
--                 local fc = c[char]
--                 local ef = fc.expansion_factor
--                 if ef and ef > 0 then
--                     if stretch ~= 0 or shrink ~= 0 then
--                         -- todo in lmtx: get rid of quad related scaling
--                         local factor  = ef / 1000
--                         local ef_quad = factor * quaddata[font] / 1000
--                         local v = {
--                             glyphstretch = stretch * ef_quad,
--                             glyphshrink  = shrink  * ef_quad,
--                             factor       = factor,  -- do we need these, if not then we
--                             stretch      = stretch, -- can as well use the chardata table
--                             shrink       = shrink,  -- to store the two above
--                         }
--                         t[char] = v
--                         return v
--                     end
--                 end
--                 t[char] = nothing
--                 return nothing
--             end)
--             t[font] = factors
--             return factors
--         end
--     end
--     t[font] = false
--     return false
-- end)

-- local function kern_stretch_shrink(p,d)
--     local left = getprev(p)
--     if left then
--         local char, font = isglyph(left)
--         if char then
--             local data = expansions[font]
--             if data then
--                 data = data[char]
--                 if data then
--                     local stretch = data.stretch
--                     local shrink  = data.shrink
--                     if stretch ~= 0 then
--                         stretch = data.factor * d * (stretch - 1)
--                     end
--                     if shrink ~= 0 then
--                         shrink = data.factor  * d * (shrink  - 1)
--                     end
--                     return stretch, shrink
--                 end
--             end
--         end
--     end
--     return 0, 0
-- end

setmetatableindex(expansions,function(t,font) -- we can store this in tfmdata if needed
    local expansion = parameters[font].expansion -- can be an extra hash
    if expansion and expansion.step ~= 0 then
        local stretch = expansion.stretch
        local shrink  = expansion.shrink
        if shrink ~= 0 or stretch ~= 0 then
            local factors = {
                stretch = stretch,
                shrink  = shrink,
            }
            local c = chardata[font]
            setmetatableindex(factors,function(t,char)
                local fc = c[char]
                local ef = fc.expansion_factor
                if ef and ef > 0 and stretch ~= 0 or shrink ~= 0 then
                    -- todo in lmtx: get rid of quad related scaling
                    local factor  = ef / 1000
                    local ef_quad = factor * quaddata[font] / 1000
                    local v = {
                        glyphstretch = stretch * ef_quad,
                        glyphshrink  = shrink  * ef_quad,
                        factor       = factor,
                    }
                    t[char] = v
                    return v
                end
                t[char] = nothing
                return nothing
            end)
            t[font] = factors
            return factors
        end
    end
    t[font] = false
    return false
end)

local function kern_stretch_shrink(p,d)
    local left = getprev(p)
    if left then
        local char, font = isglyph(left)
        if char then
            local fdata = expansions[font]
            if fdata then
                local cdata = fdata[char]
                if cdata then
                    local stretch = fdata.stretch
                    local shrink  = fdata.shrink
                    local factor  = cdata.factor * d
                    if stretch ~= 0 then
                        stretch = factor * (stretch - 1)
                    end
                    if shrink ~= 0 then
                        shrink = factor * (shrink  - 1)
                    end
                    return stretch, shrink
                end
            end
        end
    end
    return 0, 0
end

local expand_kerns_mode = false
local expand_kerns      = false

directives.register("builders.paragraphs.adjusting.kerns",function(v)
    if not v then
        expand_kerns_mode = false
    elseif v == "stretch" or v == "shrink" then
        expand_kerns_mode = v
    elseif v == "both" then
        expand_kerns_mode = true
    else
        expand_kerns_mode = toboolean(v,true) or false
    end
end)

-- state:

-- the step criterium is no longer an issue, we can be way more tolerant in
-- luatex as we act per glyph

local function check_expand_pars(checked_expansion,f)
    local expansion = parameters[f].expansion
    if not expansion then
        checked_expansion[f] = false
        return false
    end
-- expansion.step = 1
    local step    = expansion.step    or 0
    local stretch = expansion.stretch or 0
    local shrink  = expansion.shrink  or 0
    if step == 0 or (stretch == 0 and schrink == 0) then
        checked_expansion[f] = false
        return false
    end
    local par = checked_expansion.par
    if par.cur_font_step < 0 then
        par.cur_font_step = step
    elseif par.cur_font_step ~= step then
        report_parbuilders("using fonts with different step of expansion in one paragraph is not allowed")
        checked_expansion[f] = false
        return false
    end
    if stretch == 0 then
        -- okay
    elseif par.max_stretch_ratio < 0 then
        par.max_stretch_ratio = stretch -- expansion_factor
    elseif par.max_stretch_ratio ~= stretch then
        report_parbuilders("using fonts with different stretch limit of expansion in one paragraph is not allowed")
        checked_expansion[f] = false
        return false
    end
    if shrink == 0 then
        -- okay
    elseif par.max_shrink_ratio < 0 then
        par.max_shrink_ratio = shrink -- - expansion_factor
    elseif par.max_shrink_ratio ~= shrink then
        report_parbuilders("using fonts with different shrink limit of expansion in one paragraph is not allowed")
        checked_expansion[f] = false
        return false
    end
    if trace_adjusting then
        report_parbuilders("expanding font %a using step %a, shrink %a and stretch %a",f,step,stretch,shrink)
    end
    local e = expansions[f]
    checked_expansion[f] = e
    return e
end

local function check_expand_lines(checked_expansion,f)
    local expansion = parameters[f].expansion
    if not expansion then
        checked_expansion[f] = false
        return false
    end
-- expansion.step = 1
    local step    = expansion.step    or 0
    local stretch = expansion.stretch or 0
    local shrink  = expansion.shrink  or 0
    if step == 0 or (stretch == 0 and schrink == 0) then
        checked_expansion[f] = false
        return false
    end
    if trace_adjusting then
        report_parbuilders("expanding font %a using step %a, shrink %a and stretch %a",f,step,stretch,shrink)
    end
    local e = expansions[f]
    checked_expansion[f] = e
    return e
end

-- protrusion

local function find(head) -- do we really want to recurse into an hlist?
    while head do
        local id = getid(head)
        if id == glyph_code then
            return head
        elseif id == hlist_code then
            local found = find(getlist(head))
            if found then
                return found
            else
                head = getnext(head)
            end
        elseif id == boundary_code then
            if getsubtype(head) == protrusionboundary_code then
                local v = getdata(head)
                if v == 1 or v == 3 then -- brrr
                    head = getnext(head)
                    if head then
                        head = getnext(head)
                    end
                else
                    return head
                end
            else
                return head
            end
        elseif is_skipable(head) then
            head = getnext(head)
        else
            return head
        end
    end
    return nil
end

local function find_protchar_left(l) -- weird function
    local ln = getnext(l)
    if ln and getid(ln) == hlist_code and not getlist(ln) then
        local w, h, d = getwhd(ln)
        if w == 0 and h == 0 and d == 0 then
            l = getnext(l)
            return find(l) or l
        end
    end -- if d then -- was always true
    local id = getid(l)
    while ln and not (id == glyph_code or id < math_code) do -- is there always a glyph?
        l = ln
        ln = getnext(l)
        id = getid(ln)
    end
    return find(l) or l
end

local function find(head,tail)
    local tail = tail or find_tail(head)
    while tail do
        local id = getid(tail)
        if id == glyph_code then
            return tail
        elseif id == hlist_code then
            local found = find(getlist(tail))
            if found then
                return found
            else
                tail = getprev(tail)
            end
        elseif id == boundary_code then
            if getsubtype(head) == protrusionboundary_code then
                local v = getdata(tail)
                if v == 2 or v == 3 then
                    tail = getprev(tail)
                    if tail then
                        tail = getprev(tail)
                    end
                else
                    return tail
                end
            else
                return tail
            end
        elseif is_skipable(tail) then
            tail = getprev(tail)
        else
            return tail
        end
    end
    return nil
end

local function find_protchar_right(l,r)
    return r and find(l,r) or r
end

local function left_pw(p)
    local char, font = isglyph(p)
    local prot = chardata[font][char].left_protruding
    if not prot or prot == 0 then
        return 0
    end
    return prot, p
end

local function right_pw(p)
    local char, font = isglyph(p)
    local prot = chardata[font][char].right_protruding
    if not prot or prot == 0 then
        return 0
    end
    return prot, p
end

-- par parameters

local function reset_meta(par)
    local active = {
        id          = hyphenated_code,
        line_number = max_halfword,
    }
    active.next = par.active -- head of metalist
    par.active  = active
    par.passive = nil
end

local function add_to_width(line_break_dir,checked_expansion,s) -- split into two loops (normal and expansion)
    local size           = 0
    local adjust_stretch = 0
    local adjust_shrink  = 0
    while s do
        local char, id = isglyph(s)
        if char then
            size = size + getwidth(s)
            if checked_expansion then
                local data = checked_expansion[id] -- id == font
                if data then
                    data = data[char]
                    if data then
                        adjust_stretch = adjust_stretch + data.glyphstretch
                        adjust_shrink  = adjust_shrink  + data.glyphshrink
                    end
                end
            end
        elseif id == hlist_code or id == vlist_code then
            size = size + getwidth(s)
        elseif id == kern_code then
            local kern = getkern(s)
            if kern ~= 0 then
                if checked_expansion and expand_kerns and getsubtype(s) == fontkern_code then
                    local stretch, shrink = kern_stretch_shrink(s,kern)
                    if expand_kerns == "stretch" then
                        adjust_stretch = adjust_stretch + stretch
                    elseif expand_kerns == "shrink" then
                        adjust_shrink  = adjust_shrink  + shrink
                    else
                        adjust_stretch = adjust_stretch + stretch
                        adjust_shrink  = adjust_shrink  + shrink
                    end
                end
                size = size + kern
            end
        elseif id == rule_code then
            size = size + getwidth(s)
        elseif trace_unsupported then
            report_parbuilders("unsupported node at location %a",6)
        end
        s = getnext(s)
    end
    return size, adjust_stretch, adjust_shrink
end

-- We can actually make par local to this module as we never break inside a break call and that way the
-- array is reused. At some point the information will be part of the paragraph spec as passed.

local hztolerance = 2500
local hzwarned    = false

do

    local function compute_break_width(par,break_type,p) -- split in two
        local break_width = par.break_width
        if break_type > unhyphenated_code then
            local disc_width           = par.disc_width
            local checked_expansion    = par.checked_expansion
            local line_break_dir       = par.line_break_dir
            local break_size           = break_width.size           + disc_width.size
            local break_adjust_stretch = break_width.adjust_stretch + disc_width.adjust_stretch
            local break_adjust_shrink  = break_width.adjust_shrink  + disc_width.adjust_shrink
            local pre, post, replace = getdisc(p)
            if replace then
                local size, adjust_stretch, adjust_shrink = add_to_width(line_break_dir,checked_expansion,replace)
                break_size           = break_size           - size
                break_adjust_stretch = break_adjust_stretch - adjust_stretch
                break_adjust_shrink  = break_adjust_shrink  - adjust_shrink
            end
            if post then
                local size, adjust_stretch, adjust_shrink = add_to_width(line_break_dir,checked_expansion,post)
                break_size           = break_size           + size
                break_adjust_stretch = break_adjust_stretch + adjust_stretch
                break_adjust_shrink  = break_adjust_shrink  + adjust_shrink
            end
            break_width.size           = break_size
            break_width.adjust_stretch = break_adjust_stretch
            break_width.adjust_shrink  = break_adjust_shrink
            if not post then
                p = getnext(p)
            else
                return
            end
        end
        while p do -- skip spacing etc
            local id = getid(p)
            if id == glyph_code then
                return -- happens often
            elseif id == glue_code then
                local wd, stretch, shrink, stretch_order = getglue(p)
                local order = fillcodes[stretch_order]
                break_width.size   = break_width.size   - wd
                break_width[order] = break_width[order] - stretch
                break_width.shrink = break_width.shrink - shrink
            elseif id == penalty_code then
                -- do nothing
            elseif id == kern_code then
                local s = getsubtype(p)
                if s == userkern_code or s == italickern_code then
                    break_width.size = break_width.size - getkern(p)
                else
                    return
                end
            elseif id == math_code then
                break_width.size = break_width.size - getkern(p) -- surround
                -- new in luatex
                local wd, stretch, shrink, stretch_order = getglue(p)
                local order = fillcodes[stretch_order]
                break_width.size   = break_width.size   - wd
                break_width[order] = break_width[order] - stretch
                break_width.shrink = break_width.shrink - shrink
            else
                return
            end
            p = getnext(p)
        end
    end

    local function append_to_vlist(par, b)
        local prev_depth = par.prev_depth
        local head_field = par.head_field
        local tail_field = head_field and find_tail(head_field)
        local is_hlist   = getid(b) == hlist_code
        if prev_depth > ignore_depth then
            if is_hlist then
                -- we can fetch the skips values earlier if needed
                local width, stretch, shrink, stretch_order, shrink_order = unpack(par.baseline_skip)
                local delta = width - prev_depth - getheight(b) -- deficiency of space between baselines
                local skip = nil
                if delta < par.line_skip_limit then
                    width, stretch, shrink, stretch_order, shrink_order = unpack(par.lineskip)
                    skip = new_lineskip(width, stretch, shrink, stretch_order, shrink_order)
                else
                    skip = new_baselineskip(delta, stretch, shrink, stretch_order, shrink_order)
                end
                setattributelist(skip,par.head)
                if head_field then
                    setlink(tail_field,skip)
                else
                    par.head_field = skip
                    head_field = skip
                end
                tail_field = skip
            end
        end
        if head_field then
            setlink(tail_field,b)
        else
            par.head_field = b
        end
        if is_hlist then
            local pd = getdepth(b)
            par.prev_depth = pd
            texset("prevdepth",pd)
        end
    end

    local function append_list(par, b)
        local head_field = par.head_field
        if head_field then
            local n = find_tail(head_field)
            setlink(n,b)
        else
            par.head_field = b
        end
    end

    local function used_skip(s)
        return s and not is_zero_glue(s) and s
    end

    local function initialize_line_break(head,display)

        local hang_indent    = texget("hangindent")
        local hsize          = texget("hsize")
        local hang_after     = texget("hangafter")
        local par_shape_ptr  = texget("parshape")
        local left_skip      = { texgetglue("leftskip") }
        local right_skip     = { texgetglue("rightskip") }
        local pretolerance   = texget("pretolerance")
        local tolerance      = texget("tolerance")
        local adjust_spacing = texget("adjustspacing")
        local protrude_chars = texget("protrudechars")
        local last_line_fit  = texget("lastlinefit")
        local par_dir        = texget("pardirection")

        local newhead = new_temp()
        setnext(newhead,head)

        local adjust_spacing_status = adjust_spacing > 1 and -1 or 0

        -- metatables

        local par = {
            head                         = newhead,
            head_field                   = nil,
            display                      = display,
            font_in_short_display        = 0,
            no_shrink_error_yet          = true,   -- have we complained about infinite shrinkage?
            second_pass                  = false,  -- is this our second attempt to break this paragraph?
            final_pass                   = false,  -- is this our final attempt to break this paragraph?
            threshold                    = 0,      -- maximum badness on feasible lines

            passive                      = nil,    -- most recent node on passive list
            printed_node                 = head,   -- most recent node that has been printed
            pass_number                  = 0,      -- the number of passive nodes allocated on this pass
            auto_breaking                = 0,      -- make auto_breaking accessible out of line_break

            active_width                 = { size = 0, normal = 0, fi = 0, fil = 0, fill = 0, filll = 0, shrink = 0, adjust_stretch = 0, adjust_shrink = 0 },
            break_width                  = { size = 0, normal = 0, fi = 0, fil = 0, fill = 0, filll = 0, shrink = 0, adjust_stretch = 0, adjust_shrink = 0 },
            disc_width                   = { size = 0,                                                               adjust_stretch = 0, adjust_shrink = 0 },
            fill_width                   = {           normal = 0, fi = 0, fil = 0, fill = 0, filll = 0, shrink = 0                                        },
            background                   = { size = 0, normal = 0, fi = 0, fil = 0, fill = 0, filll = 0, shrink = 0                                        },

            hang_indent                  = hang_indent,
            hsize                        = hsize,
            hang_after                   = hang_after,
            par_shape_ptr                = par_shape_ptr,
            left_skip                    = left_skip,
            right_skip                   = right_skip,
            pretolerance                 = pretolerance,
            tolerance                    = tolerance,

            protrude_chars               = protrude_chars,
            adjust_spacing               = adjust_spacing,
            max_stretch_ratio            = adjust_spacing_status,
            max_shrink_ratio             = adjust_spacing_status,
            cur_font_step                = adjust_spacing_status,
            checked_expansion            = false,
            tracing_paragraphs           = texget("tracingparagraphs") > 0,

            emergency_stretch            = texget("emergencystretch")     or 0,
            looseness                    = texget("looseness")            or 0,
            line_penalty                 = texget("linepenalty")          or 0,
            broken_penalty               = texget("brokenpenalty")        or 0,
            inter_line_penalty           = texget("interlinepenalty")     or 0,
            club_penalty                 = texget("clubpenalty")          or 0,
            widow_penalty                = texget("widowpenalty")         or 0,
            display_widow_penalty        = texget("displaywidowpenalty")  or 0,

            adj_demerits                 = texget("adjdemerits")          or 0,
            double_hyphen_demerits       = texget("doublehyphendemerits") or 0,
            final_hyphen_demerits        = texget("finalhyphendemerits")  or 0,

            first_line                   = texget("prevgraf"),
            prev_depth                   = texget("prevdepth"),

            baseline_skip                = { texgetglue("baselineskip") },
            lineskip                     = { texgetglue("lineskip") },
            line_skip_limit              = texget("lineskiplimit"),

            final_par_glue               = find_tail(head),

            par_break_dir                = par_dir,
            line_break_dir               = par_dir,

            internal_pen_inter           = 0,   -- running localinterlinepenalty
            internal_pen_broken          = 0,   -- running localbrokenpenalty
            internal_left_box            = nil, -- running localleftbox
            internal_left_box_width      = 0,   -- running localleftbox width
            init_internal_left_box       = nil, -- running localleftbox
            init_internal_left_box_width = 0,   -- running localleftbox width
            internal_right_box           = nil, -- running localrightbox
            internal_right_box_width     = 0,   -- running localrightbox width

            best_place                   = { }, -- how to achieve minimal_demerits
            best_pl_line                 = { }, -- corresponding line number
            easy_line                    = 0,   -- line numbers easy_line are equivalent in break nodes
            last_special_line            = 0,   -- line numbers last_special_line all have the same width
            first_width                  = 0,   -- the width of all lines last_special_line, if no parshape has been specified
            second_width                 = 0,   -- the width of all lines last_special_line
            first_indent                 = 0,   -- left margin to go with first_width
            second_indent                = 0,   -- left margin to go with second_width

            best_bet                     = nil, -- use this passive node and its predecessors
            fewest_demerits              = 0,   -- the demerits associated with best_bet
            best_line                    = 0,   -- line number following the last line of the new paragraph
            line_diff                    = 0,   -- the difference between the current line number and the optimum best_line

            -- not yet used

            best_pl_short                = { }, -- shortfall corresponding to minimal_demerits
            best_pl_glue                 = { }, -- corresponding glue stretch or shrink
            do_last_line_fit             = false,
            last_line_fit                = last_line_fit,

            minimum_demerits             = awful_badness,

            minimal_demerits             = {

                [fit_very_loose_class] = awful_badness,
                [fit_loose_class]      = awful_badness,
                [fit_decent_class]     = awful_badness,
                [fit_tight_class]      = awful_badness,

            },

            prev_char_p                  = nil,

            statistics                   = {

                noflines          = 0,
                nofprotrudedlines = 0,
                nofadjustedlines  = 0,

            },

         -- -- just a thought ... parshape functions ... it would be nice to
         -- -- also store the height so far (probably not too hard) although
         -- -- in most cases we work on grids in such cases
         --
         -- adapt_width = function(par,line)
         --     -- carry attribute, so that we can accumulate
         --     local left  = 655360 * (line - 1)
         --     local right = 655360 * (line - 1)
         --     return left, right
         -- end

        }

        -- so far

        if adjust_spacing > 1 then
            local checked_expansion = { par = par }
            setmetatableindex(checked_expansion,check_expand_pars)
            par.checked_expansion = checked_expansion

            if par.tolerance < hztolerance then
                if not hzwarned then
                    report_parbuilders("setting tolerance to %a for hz",hztolerance)
                    hzwarned = true
                end
                par.tolerance = hztolerance
            end

            expand_kerns = expand_kerns_mode or (adjust_spacing == 2) -- why not > 1 ?

        end

        -- we need par for the error message

        local background = par.background

        local lwidth, lstretch, lshrink, lstretch_order, lshrink_order = unpack(left_skip)
        local rwidth, rstretch, rshrink, rstretch_order, rshrink_order = unpack(right_skip)

        if lshrink_order ~= 0 and lshrink ~= 0 then
            infinite_shrinkage_error(par)
            lshrink_order = 0
        end
        if rshrink_order ~= 0 and rshrink ~= 0 then
            infinite_shrinkage_error(par)
            rshrink_order = 0
        end

        local l_order = fillcodes[lstretch_order]
        local r_order = fillcodes[rstretch_order]

        background.size     = lwidth   + rwidth
        background.shrink   = lshrink  + rshrink
        background[l_order] = lstretch
        background[r_order] = rstretch + background[r_order]

        -- this will move up so that we can assign the whole par table

        if not par_shape_ptr then
            if hang_indent == 0 then
                par.second_width  = hsize
                par.second_indent = 0
            else
                local abs_hang_after  = hang_after  > 0 and hang_after  or -hang_after
                local abs_hang_indent = hang_indent > 0 and hang_indent or -hang_indent
                par.last_special_line = abs_hang_after
                if hang_after < 0 then
                    par.first_width = hsize - abs_hang_indent
                    if hang_indent >= 0 then
                        par.first_indent = hang_indent
                    else
                        par.first_indent = 0
                    end
                    par.second_width  = hsize
                    par.second_indent = 0
                else
                    par.first_width  = hsize
                    par.first_indent = 0
                    par.second_width = hsize - abs_hang_indent
                    if hang_indent >= 0 then
                        par.second_indent = hang_indent
                    else
                        par.second_indent = 0
                    end
                end
            end
        else
            local last_special_line = #par_shape_ptr
            par.last_special_line = last_special_line
            local parshape = par_shape_ptr[last_special_line]
            par.second_width  = parshape[2]
            par.second_indent = parshape[1]
        end

        if par.looseness == 0 then
            par.easy_line = par.last_special_line
        else
            par.easy_line = max_halfword
        end

        if pretolerance >= 0 then
            par.threshold   = pretolerance
            par.second_pass = false
            par.final_pass  = false
        else
            par.threshold   = tolerance
            par.second_pass = true
            par.final_pass  = par.emergency_stretch <= 0
            if trace_basic then
                if par.final_pass then
                    report_parbuilders("enabling second and final pass")
                else
                    report_parbuilders("enabling second pass")
                end
            end
        end

        if last_line_fit > 0 then
            local final_par_glue = par.final_par_glue
            local stretch        = getfield(final_par_glue,"stretch")
            local stretch_order  = getfield(final_par_glue,"stretch_order")
            if stretch > 0 and stretch_order > 0 and background.fi == 0 and background.fil == 0 and background.fill == 0 and background.filll == 0 then
                par.do_last_line_fit = true
                local si = fillcodes[stretch_order]
                if trace_lastlinefit or trace_basic then
                    report_parbuilders("enabling last line fit, stretch order %a set to %a, linefit is %a",si,stretch,last_line_fit)
                end
                par.fill_width[si] = stretch
            end
        end

        return par
    end

    -- there are still all kind of artefacts in here (a side effect I guess of pdftex,
    -- etex, omega and other extensions that got obscured by patching)

    local function post_line_break(par)

        local prevgraf       = par.first_line -- or texget("prevgraf")
        local current_line   = prevgraf + 1 -- the current line number being justified
        local adjust_spacing = par.adjust_spacing
        local protrude_chars = par.protrude_chars
        local statistics     = par.statistics
        local leftskip       = par.left_skip
        local rightskip      = par.right_skip
        local parshape       = par.par_shape_ptr
     -- local adapt_width    = par.adapt_width
        local hsize          = par.hsize

        local dirstack       = par.dirstack
        local normalize      = getnormalizeline()

        -- reverse the links of the relevant passive nodes, goto first breakpoint

        local current_break  = nil

        local break_node = par.best_bet.break_node
        repeat
            local first_break = break_node
            break_node = break_node.prev_break
            first_break.prev_break = current_break
            current_break = first_break
        until not break_node

        local head = par.head

        -- when we normalize and have no content still ls/rs gets appended while
        -- the engine doesnt' do that so there is some test missing that prevents
        -- entering here

        while current_break do

            -- hm, here we have head == localpar and in the engine it's a temp node

            head = inject_dirs_at_begin_of_line(dirstack,head)

            local disc_break      = false
            local post_disc_break = false
            local glue_break      = false

            local lineend         = nil                     -- lineend : the last node of the line (and paragraph)
            local lastnode        = current_break.cur_break -- lastnode: the node after which the dir nodes should be closed
            if not lastnode then
                -- only at the end
                lastnode = find_tail(head)
                if lastnode == par.final_par_glue then
                    lineend  = lastnode
                    lastnode = getprev(lastnode)
                end
            else -- todo: use insert_list_after
                local id = getid(lastnode)
                if id == glue_code then
                    local r = new_rightskip(unpack(rightskip))
                    setattributelist(r,lastnode)
                    lastnode   = replace_node(lastnode,r)
                    glue_break = true
                    lineend    = lastnode
                    lastnode   = getprev(lastnode)
                elseif id == disc_code then
                    local prevlast, nextlast = getboth(lastnode)
                    local pre, post, replace, pretail, posttail, replacetail = getdisc(lastnode,true)
                    local subtype = getsubtype(lastnode)
                    if subtype == seconddisc_code then
                        if not (getid(prevlast) == disc_code and getsubtype(prevlast) == firstdisc_code) then
                            report_parbuilders('unsupported disc at location %a',3)
                        end
                        if pre then
                            flush_node_list(pre)
                            pre = nil -- signal
                        end
                        if replace then
                            setlink(prevlast,replace)
                            setlink(replacetail,lastnode)
                            replace = nil -- signal
                        end
                        setdisc(lastnode,pre,post,replace)
                        local pre, post, replace = getdisc(prevlast)
                        if pre then
                            flush_node_list(pre)
                        end
                        if replace then
                            flush_node_list(replace)
                        end
                        if post then
                            flush_node_list(post)
                        end
                        setdisc(prevlast) -- nil,nil,nil
                    elseif subtype == firstdisc_code then
                        -- what is v ... next probably
                        if not (getid(v) == disc_code and getsubtype(v) == seconddisc_code) then
                            report_parbuilders('unsupported disc at location %a',4)
                        end
                        setsubtype(nextlast,regulardisc_code)
                        setreplace(nextlast,post)
                        setpost(lastnode)
                    end
                    if replace then
                        flush_node_list(replace)
                    end
                    if pre then
                        setlink(prevlast,pre)
                        setlink(pretail,lastnode)
                    end
                    if post then
                        setlink(lastnode,post)
                        setlink(posttail,nextlast)
                        post_disc_break = true
                    end
                    setdisc(lastnode) -- nil, nil, nil
                    disc_break = true
                elseif id == kern_code then
                    setkern(lastnode,0)
                elseif id == math_code then
                    setkern(lastnode,0) -- surround
                    -- new in luatex
                    setglue(lastnode) -- zeros
                end
            end
            -- todo: clean up this mess which results from all kind of engine merges
            -- (start/end nodes)
            -- hm, head ?
            lastnode = inject_dirs_at_end_of_line(dirstack,lastnode,getnext(head),current_break.cur_break)
            local rightbox = current_break.passive_right_box
            if rightbox then
                lastnode = insert_node_after(lastnode,lastnode,copy_node(rightbox))
            end
            if not lineend then
                lineend = lastnode
            end
            if lineend and lineend ~= head and protrude_chars > 0 then
                if par.line_break_dir == righttoleft_code then
                    if protrude_chars > 2 then
                        local p = lineend
                        local l = nil
                        -- Backtrack over the last zero glues and dirs.
                        while p do
                            local id = getid(p)
                            if id == dir_code then
                                 if getsubtype(p) ~= cancel_code then
                                     break
                                 end
                                 p = getprev(p)
                            elseif id == glue_code then
                                if getwidth(p) == 0 then
                                    p = getprev(p)
                                else
                                    p = nil
                                    break
                                end
                            elseif id == glyph_code then
                                 break
                            else
                                 p = nil
                                 break
                            end
                        end
                         -- When |p| is non zero we have something.
                        while p do
                            local id = getid(p)
                            if id == glyph_code then
                                l = p
                            elseif id == glue_code then
                                if getwidth(p) == 0 then
                                    -- No harm done.
                                else
                                    l = nil
                                end
                            elseif id == dir_code then
                                if getdirection(p) ~= righttoleft_code then
                                    p = nil
                                end
                                break
                            elseif id == localpar_code then
                                break
                            elseif id == temp_code then
                                -- Go on.
                            else
                                l = nil
                            end
                            p = getprev(p)
                        end
                        if l and p then
                            local w, last_rightmost_char = right_pw(l)
                            if last_rightmost_char and w ~= 0 then
                                local k = new_rightmarginkern(copy_node(last_rightmost_char),-w)
                                setattributelist(k,l)
                                setlink(p,k,l)
                            end
                        end
                    end
                else
                    local id = getid(lineend)
                    local c = nil
                    if disc_break and (id == glyph_code or id ~= disc_code) then
                        c = lineend
                    else
                        c = getprev(lineend)
                    end
                    local p = find_protchar_right(getnext(head),c)
                    if p and getid(p) == glyph_code then
                        local w, last_rightmost_char = right_pw(p)
                        if last_rightmost_char and w ~= 0 then
                            -- so we inherit attributes, lineend is new pseudo head
                            local k = new_rightmarginkern(copy_node(last_rightmost_char),-w)
                            setattributelist(k,p)
--                             insert_node_after(c,c,k)
                            insert_node_after(p,p,k)
--                             if c == lineend then
--                                 lineend = getnext(c)
--                             end
                        end
                    end
                end
            end
            -- we finish the line
            local r = getnext(lineend)
            setnext(lineend) -- lineend moves on as pseudo head
            local start = getnext(head)
            setlink(head,r)
            if not glue_break then
                local rs = new_rightskip(unpack(rightskip))
                setattributelist(rs,lineend)
                start, lineend = insert_node_after(start,lineend,rs)
            end
            local rs = lineend
            -- insert leftbox (if needed after parindent)
            local leftbox = current_break.passive_left_box
            if leftbox then
                local first = getnext(start)
                if first and current_line == (par.first_line + 1) and getid(first) == hlist_code and not getlist(first) then
                    insert_node_after(start,start,copy_node(leftbox))
                else
                    start = insert_node_before(start,start,copy_node(leftbox))
                end
            end
            if protrude_chars > 0 then
                if par.line_break_dir == righttoleft_code then
                    if protrude_chars > 2 then
                        local p = find_protchar_left(start)
                        if p then
                            local w, last_leftmost_char = right_pw(p)
                            if last_leftmost_char and w ~= 0 then
                                local k = new_rightmarginkern(copy_node(last_leftmost_char),-w)
                                setattributelist(k,p)
                                start = insert_node_before(start,start,k)
                            end
                        end
                    end
                else
                    local p = find_protchar_left(start)
                    if p and getid(p) == glyph_code then
                        local w, last_leftmost_char = left_pw(p)
                        if last_leftmost_char and w ~= 0 then
                            -- so we inherit attributes, start is pseudo head and moves back
                            local k = new_leftmarginkern(copy_node(last_leftmost_char),-w)
                            setattributelist(k,p)
                            start = insert_node_before(start,start,k)
                        end
                    end
                end
            end
            local ls
            if leftskip or normalize > 0 then
                -- we could check for non zero but we will normalize anyway
                ls = new_leftskip(unpack(leftskip))
                setattributelist(ls,start)
                start = insert_node_before(start,start,ls)
            end
            if normalize > 0 then
                local localpar  = nil
                local localdir  = nil
                local indent    = nil
                local localpars = nil
                local notflocal = 0
                for n, id, subtype in nextnode, start do
                    if id == hlist_code then
                        if normalize > 1 and subtype == indentlist_code then
                            indent = n
                        end
                    elseif id == localpar_code then
                        if start_of_par(n) then --- maybe subtype check instead
                            localpar = n
                        elseif noflocals then
                            noflocals = noflocals + 1
                            localpars[noflocals] = n
                        else
                            noflocals = 1
                            localpars = { n }
                        end
                    elseif id == dir_code then
                        if localpar and not localdir and subtype(n) == cancel_code then
                            localdir = n
                        end
                    end
                end
                if indent then
                    local i = new_indentskip(getwidth(indent))
                    setattributelist(i,start)
                    replace_node(indent,i)
                end
                if localdir then
                    local d = new_direction((getdirection(localpar)))
                    setattributelist(d,start)
                    replace_node(localpar,d)
                end
                if localpars then
                    for i=1,noflocals do
                        start = remove_node(start,localpars[i],true)
                    end
                end
            end
            local cur_width, cur_indent
            if current_line > par.last_special_line then
                cur_indent = par.second_indent
                cur_width  = par.second_width
            elseif parshape then
                local shape = parshape[current_line]
                cur_indent = shape[1]
                cur_width  = shape[2]
            else
                cur_indent = par.first_indent
                cur_width  = par.first_width
            end
            -- extension
         -- if adapt_width then
         --     local l, r = adapt_width(par,current_line)
         --     cur_indent = cur_indent + l
         --     cur_width  = cur_width  - l - r
         -- end
            --
            if normalize > 2 then
                local l = new_lefthangskip()
                local r = new_righthangskip()
                if cur_width ~= hsize then
                    cur_indent = hsize - cur_width
                end
                if cur_indent > 0 then
                    setwidth(l,cur_indent)
                elseif cur_indent < 0 then
                    setwidth(r,-cur_indent)
                end
                setattributelist(l,start)
                setattributelist(r,start)
                if normalize > 3 then
                    -- makes most sense
                    start = insert_node_after(start,ls,l)
                    start = insert_node_before(start,rs,r)
                else
                    start = insert_node_before(start,ls,l)
                    start = insert_node_after(start,rs,r)
                end
                cur_width = hsize
                cur_indent = 0
            end
            --
            statistics.noflines = statistics.noflines + 1
            --
            -- here we could cleanup: remove all if we have (zero) skips only
            --
            local finished_line = nil
            if adjust_spacing > 0 then
                statistics.nofadjustedlines = statistics.nofadjustedlines + 1
                finished_line = xpack_nodes(start,cur_width,"cal_expand_ratio",par.par_break_dir,par.first_line,current_line) -- ,current_break.analysis)
            else
                finished_line = xpack_nodes(start,cur_width,"exactly",par.par_break_dir,par.first_line,current_line) -- ,current_break.analysis)
            end
            if protrude_chars > 0 then
                statistics.nofprotrudedlines = statistics.nofprotrudedlines + 1
            end
            -- wrong:
            local adjust_head     = texlists.adjust_head
            local pre_adjust_head = texlists.pre_adjust_head
            --
            setshift(finished_line,cur_indent)
            --
            if texlists.pre_adjust_head ~= pre_adjust_head then
                append_list(par, texlists.pre_adjust_head)
                texlists.pre_adjust_head = pre_adjust_head
            end
            append_to_vlist(par,finished_line)
            if texlists.adjust_head ~= adjust_head then
                append_list(par, texlists.adjust_head)
                texlists.adjust_head = adjust_head
            end
            --
            local pen
            if current_line + 1 ~= par.best_line then
                if current_break.passive_pen_inter then
                    pen = current_break.passive_pen_inter
                else
                    pen = par.inter_line_penalty
                end
                if current_line == prevgraf + 1 then
                    pen = pen + par.club_penalty
                end
                if current_line + 2 == par.best_line then
                    if par.display then
                        pen = pen + par.display_widow_penalty
                    else
                        pen = pen + par.widow_penalty
                    end
                end
                if disc_break then
                    if current_break.passive_pen_broken ~= 0 then
                        pen = pen + current_break.passive_pen_broken
                    else
                        pen = pen + par.broken_penalty
                    end
                end
                if pen ~= 0 then
                    local p = new_penalty(pen)
                    setattributelist(p,par.head)
                    append_to_vlist(par,p)
                end
            end
            current_line  = current_line + 1
            current_break = current_break.prev_break
            if current_break and not post_disc_break then
                local current = head
                local next    = nil
                while true do
                    next = getnext(current)
                    if next == current_break.cur_break then
                        break
                    end
                    local id = getid(next)
                    if id == glyph_code then
                        break
                    elseif id == localpar_code then
                        -- nothing
                    elseif id < math_code then
                        -- messy criterium
                        break
                    elseif id == math_code then
                        -- keep the math node
                        setkern(next,0) -- surround
                        -- new in luatex
                        setglue(lastnode) -- zeros
                        break
                    elseif id == kern_code then
                        local subtype = getsubtype(next)
                        if subtype == fontkern_code or subtype == accentkern_code then
                            -- fontkerns and accent kerns as well as otf injections
                            break
                        end
                    end
                    current = next
                end
                if current ~= head then
                    setnext(current)
                    flush_node_list(getnext(head))
                    setlink(head,next)
                end
            end
par.head = head
        end
     -- if current_line ~= par.best_line then
     --     report_parbuilders("line breaking")
     -- end
        local h = par.head -- hm, head
        if h then
            if trace_basic then
                if getnext(h) then
                    report_parbuilders("something is left over")
                end
                if getid(h) ~= localpar_code then
                    report_parbuilders("no local par node")
                end
            end
            flush_node(h)
            par.head = nil -- needs checking
        end
        current_line = current_line - 1
        if trace_basic then
            report_parbuilders("paragraph broken into %a lines",current_line)
        end
        texset("prevgraf",current_line)
    end

    local function wrap_up(par)
        if par.tracing_paragraphs then
            diagnostics.stop()
        end
        if par.do_last_line_fit then
            local best_bet     = par.best_bet
            local active_short = best_bet.active_short
            local active_glue  = best_bet.active_glue
            if active_short == 0 then
                if trace_lastlinefit then
                    report_parbuilders("disabling last line fit, no active_short")
                end
                par.do_last_line_fit = false
            else
                local glue = par.final_par_glue
                setwidth(glue,getwidth(glue) + active_short - active_glue)
                setfield(glue,"stretch",0)
                if trace_lastlinefit then
                    report_parbuilders("applying last line fit, short %a, glue %p",active_short,active_glue)
                end
            end
        end
        -- This differs from the engine, where the temp node is removed elsewhere.
        local head = par.head
        if head and getid(head) == temp_code then
            local next = getnext(head)
            par.head = next
            if next then
                setprev(next)
            end
            flush_node(head)
        end
        post_line_break(par)
        reset_meta(par)
        register_statistics(par)
        return par.head_field
    end

    -- we could do active nodes differently ... table instead of linked list or a list
    -- with prev nodes but it doesn't save much (as we still need to keep indices then
    -- in next)

    local function deactivate_node(par,prev_prev_r,prev_r,r,cur_active_width,checked_expansion) -- no need for adjust if disabled
        local active = par.active
        local active_width = par.active_width
        prev_r.next = r.next
        -- removes r
        -- r = nil
        if prev_r == active then
            r = active.next
            if r.id == delta_code then
                local aw = active_width.size   + r.size    active_width.size   = aw  cur_active_width.size   = aw
                local aw = active_width.normal + r.normal  active_width.normal = aw  cur_active_width.normal = aw
                local aw = active_width.fi     + r.fi      active_width.fi     = aw  cur_active_width.fi     = aw
                local aw = active_width.fil    + r.fil     active_width.fil    = aw  cur_active_width.fil    = aw
                local aw = active_width.fill   + r.fill    active_width.fill   = aw  cur_active_width.fill   = aw
                local aw = active_width.filll  + r.filll   active_width.filll  = aw  cur_active_width.filll  = aw
                local aw = active_width.shrink + r.shrink  active_width.shrink = aw  cur_active_width.shrink = aw
                if checked_expansion then
                    local aw = active_width.adjust_stretch + r.adjust_stretch  active_width.adjust_stretch = aw  cur_active_width.adjust_stretch = aw
                    local aw = active_width.adjust_shrink  + r.adjust_shrink   active_width.adjust_shrink  = aw  cur_active_width.adjust_shrink  = aw
                end
                active.next = r.next
                -- removes r
                -- r = nil
            end
        elseif prev_r.id == delta_code then
            r = prev_r.next
            if r == active then
                cur_active_width.size   = cur_active_width.size   - prev_r.size
                cur_active_width.normal = cur_active_width.normal - prev_r.normal
                cur_active_width.fi     = cur_active_width.fi     - prev_r.fi
                cur_active_width.fil    = cur_active_width.fil    - prev_r.fil
                cur_active_width.fill   = cur_active_width.fill   - prev_r.fill
                cur_active_width.filll  = cur_active_width.filll  - prev_r.filll
                cur_active_width.shrink = cur_active_width.shrink - prev_r.shrink
                if checked_expansion then
                    cur_active_width.adjust_stretch = cur_active_width.adjust_stretch - prev_r.adjust_stretch
                    cur_active_width.adjust_shrink  = cur_active_width.adjust_shrink  - prev_r.adjust_shrink
                end
                prev_prev_r.next = active
                -- removes prev_r
                -- prev_r = nil
                prev_r = prev_prev_r
            elseif r.id == delta_code then
                local rn = r.size     cur_active_width.size   = cur_active_width.size   + rn  prev_r.size   = prev_r.size    + rn
                local rn = r.normal   cur_active_width.normal = cur_active_width.normal + rn  prev_r.normal = prev_r.normal  + rn
                local rn = r.fi       cur_active_width.fi     = cur_active_width.fi     + rn  prev_r.fi     = prev_r.fi      + rn
                local rn = r.fil      cur_active_width.fil    = cur_active_width.fil    + rn  prev_r.fil    = prev_r.fil     + rn
                local rn = r.fill     cur_active_width.fill   = cur_active_width.fill   + rn  prev_r.fill   = prev_r.fill    + rn
                local rn = r.filll    cur_active_width.filll  = cur_active_width.filll  + rn  prev_r.filll  = prev_r.fill    + rn
                local rn = r.shrink   cur_active_width.shrink = cur_active_width.shrink + rn  prev_r.shrink = prev_r.shrink  + rn
                if checked_expansion then
                    local rn = r.adjust_stretch  cur_active_width.adjust_stretch = cur_active_width.adjust_stretch + rn  prev_r.adjust_stretch = prev_r.adjust_stretch    + rn
                    local rn = r.adjust_shrink   cur_active_width.adjust_shrink  = cur_active_width.adjust_shrink  + rn  prev_r.adjust_shrink  = prev_r.adjust_shrink     + rn
                end
                prev_r.next = r.next
                -- removes r
                -- r = nil
            end
        end
        return prev_r, r
    end

    local function lastlinecrap(shortfall,active_short,active_glue,cur_active_width,fill_width,last_line_fit)
        if active_short == 0 or active_glue <= 0 then
            return false, 0, fit_decent_class, 0, 0
        end
        if cur_active_width.fi ~= fill_width.fi or cur_active_width.fil ~= fill_width.fil or cur_active_width.fill ~= fill_width.fill or cur_active_width.filll ~= fill_width.filll then
            return false, 0, fit_decent_class, 0, 0
        end
        local adjustment = active_short > 0 and cur_active_width.normal or cur_active_width.shrink
        if adjustment <= 0 then
            return false, 0, fit_decent_class, adjustment, 0
        end
        adjustment = calculate_fraction(adjustment,active_short,active_glue,maxdimen)
        if last_line_fit < 1000 then
            adjustment = calculate_fraction(adjustment,last_line_fit,1000,maxdimen) -- uses previous adjustment
        end
        local fit_class = fit_decent_class
        if adjustment > 0 then
            local stretch = cur_active_width.normal
            if adjustment > shortfall then
                adjustment = shortfall
            end
            if adjustment > 7230584 and stretch < 1663497 then
                return true, fit_very_loose_class, shortfall, adjustment, infinite_badness
            end
         -- if adjustment == 0 then -- badness = 0
         --     return true, shortfall, fit_decent_class, 0, 0
         -- elseif stretch <= 0 then -- badness = 10000
         --     return true, shortfall, fit_very_loose_class, adjustment, 10000
         -- end
         -- local badness = (adjustment == 0 and 0) or (stretch <= 0 and 10000) or calculate_badness(adjustment,stretch)
            local badness = calculate_badness(adjustment,stretch)
            if badness > 99 then
                return true, shortfall, fit_very_loose_class, adjustment, badness
            elseif badness > 12 then
                return true, shortfall, fit_loose_class, adjustment, badness
            else
                return true, shortfall, fit_decent_class, adjustment, badness
            end
        elseif adjustment < 0 then
            local shrink = cur_active_width.shrink
            if -adjustment > shrink then
                adjustment = -shrink
            end
            local badness = calculate_badness(-adjustment,shrink)
            if badness > 12 then
                return true, shortfall, fit_tight_class, adjustment, badness
            else
                return true, shortfall, fit_decent_class, adjustment, badness
            end
        else
            return false, 0, fit_decent_class, 0, 0
        end
    end

    -- todo: statistics .. count tries and so

    local trialcount = 0

    local function try_break(pi, break_type, par, first_p, current, checked_expansion)

    -- trialcount = trialcount + 1
    -- print(trialcount,pi,break_type,current,nuts.tostring(current))

        if pi >= infinite_penalty then          -- this breakpoint is inhibited by infinite penalty
            local p_active = par.active
            return p_active, p_active and p_active.next
        elseif pi <= -infinite_penalty then     -- this breakpoint will be forced
            pi = eject_penalty
        end

        local prev_prev_r         = nil         -- a step behind prev_r, if type(prev_r)=delta_code
        local prev_r              = par.active  -- stays a step behind r
        local r                   = nil         -- runs through the active list
        local no_break_yet        = true        -- have we found a feasible break at current?
        local node_r_stays_active = false       -- should node r remain in the active list?
        local line_width          = 0           -- the current line will be justified to this width
        local line_number         = 0           -- line number of current active node
        local old_line_number     = 0           -- maximum line number in current equivalence class of lines

        local protrude_chars      = par.protrude_chars
        local checked_expansion   = par.checked_expansion
        local break_width         = par.break_width
        local active_width        = par.active_width
        local background          = par.background
        local minimal_demerits    = par.minimal_demerits
        local best_place          = par.best_place
        local best_pl_line        = par.best_pl_line
        local best_pl_short       = par.best_pl_short
        local best_pl_glue        = par.best_pl_glue
        local do_last_line_fit    = par.do_last_line_fit
        local final_pass          = par.final_pass
        local tracing_paragraphs  = par.tracing_paragraphs
     -- local par_active          = par.active

     -- local adapt_width         = par.adapt_width

        local parshape            = par.par_shape_ptr

        local cur_active_width = checked_expansion and { -- distance from current active node
            size           = active_width.size,
            normal         = active_width.normal,
            fi             = active_width.fi,
            fil            = active_width.fil,
            fill           = active_width.fill,
            filll          = active_width.filll,
            shrink         = active_width.shrink,
            adjust_stretch = active_width.adjust_stretch,
            adjust_shrink  = active_width.adjust_shrink,
        } or {
            size           = active_width.size,
            normal         = active_width.normal,
            fi             = active_width.fi,
            fil            = active_width.fil,
            fill           = active_width.fill,
            filll          = active_width.filll,
            shrink         = active_width.shrink,
        }

        while true do
            r = prev_r.next
            if r.id == delta_code then
                cur_active_width.size   = cur_active_width.size   + r.size
                cur_active_width.normal = cur_active_width.normal + r.normal
                cur_active_width.fi     = cur_active_width.fi     + r.fi
                cur_active_width.fil    = cur_active_width.fil    + r.fil
                cur_active_width.fill   = cur_active_width.fill   + r.fill
                cur_active_width.filll  = cur_active_width.filll  + r.filll
                cur_active_width.shrink = cur_active_width.shrink + r.shrink
                if checked_expansion then
                    cur_active_width.adjust_stretch = cur_active_width.adjust_stretch + r.adjust_stretch
                    cur_active_width.adjust_shrink  = cur_active_width.adjust_shrink  + r.adjust_shrink
                end
                prev_prev_r = prev_r
                prev_r = r
            else
                line_number = r.line_number
                if line_number > old_line_number then
                    local minimum_demerits = par.minimum_demerits
                    if minimum_demerits < awful_badness and (old_line_number ~= par.easy_line or r == par.active) then
                        if no_break_yet then
                            no_break_yet = false
                            break_width.size   = background.size
                            break_width.normal = background.normal
                            break_width.fi     = background.fi
                            break_width.fil    = background.fil
                            break_width.fill   = background.fill
                            break_width.filll  = background.filll
                            break_width.shrink = background.shrink
                            if checked_expansion then
                                break_width.adjust_stretch = 0
                                break_width.adjust_shrink  = 0
                            end
                            if current then
                                compute_break_width(par,break_type,current)
                            end
                        end
                        if prev_r.id == delta_code then
                            prev_r.size   = prev_r.size   - cur_active_width.size   + break_width.size
                            prev_r.normal = prev_r.normal - cur_active_width.normal + break_width.normal
                            prev_r.fi     = prev_r.fi     - cur_active_width.fi     + break_width.fi
                            prev_r.fil    = prev_r.fil    - cur_active_width.fil    + break_width.fil
                            prev_r.fill   = prev_r.fill   - cur_active_width.fill   + break_width.fill
                            prev_r.filll  = prev_r.filll  - cur_active_width.filll  + break_width.filll
                            prev_r.shrink = prev_r.shrink - cur_active_width.shrink + break_width.shrink
                            if checked_expansion then
                                prev_r.adjust_stretch = prev_r.adjust_stretch - cur_active_width.adjust_stretch + break_width.adjust_stretch
                                prev_r.adjust_shrink  = prev_r.adjust_shrink  - cur_active_width.adjust_shrink  + break_width.adjust_shrink
                            end
                        elseif prev_r == par.active then
                            active_width.size   = break_width.size
                            active_width.normal = break_width.normal
                            active_width.fi     = break_width.fi
                            active_width.fil    = break_width.fil
                            active_width.fill   = break_width.fill
                            active_width.filll  = break_width.filll
                            active_width.shrink = break_width.shrink
                            if checked_expansion then
                                active_width.adjust_stretch = break_width.adjust_stretch
                                active_width.adjust_shrink  = break_width.adjust_shrink
                            end
                        else
                            local q = checked_expansion and {
                                id             = delta_code,
                                subtype        = nosubtype_code,
                                next           = r,
                                size           = break_width.size           - cur_active_width.size,
                                normal         = break_width.normal         - cur_active_width.normal,
                                fi             = break_width.fi             - cur_active_width.fi,
                                fil            = break_width.fil            - cur_active_width.fil,
                                fill           = break_width.fill           - cur_active_width.fill,
                                filll          = break_width.filll          - cur_active_width.filll,
                                shrink         = break_width.shrink         - cur_active_width.shrink,
                                adjust_stretch = break_width.adjust_stretch - cur_active_width.adjust_stretch,
                                adjust_shrink  = break_width.adjust_shrink  - cur_active_width.adjust_shrink,
                            } or {
                                id      = delta_code,
                                subtype = nosubtype_code,
                                next    = r,
                                size    = break_width.size   - cur_active_width.size,
                                normal  = break_width.normal - cur_active_width.normal,
                                fi      = break_width.fi     - cur_active_width.fi,
                                fil     = break_width.fil    - cur_active_width.fil,
                                fill    = break_width.fill   - cur_active_width.fill,
                                filll   = break_width.filll  - cur_active_width.filll,
                                shrink  = break_width.shrink - cur_active_width.shrink,
                            }
                            prev_r.next = q
                            prev_prev_r = prev_r
                            prev_r = q
                        end
                        local adj_demerits     = par.adj_demerits
                        local abs_adj_demerits = adj_demerits > 0 and adj_demerits or -adj_demerits
                        if abs_adj_demerits >= awful_badness - minimum_demerits then
                            minimum_demerits = awful_badness - 1
                        else
                            minimum_demerits = minimum_demerits + abs_adj_demerits
                        end
                        for fit_class = fit_very_loose_class, fit_tight_class do
                            if minimal_demerits[fit_class] <= minimum_demerits then
                                -- insert a new active node from best_place[fit_class] to current
                                par.pass_number = par.pass_number + 1
                                local prev_break = best_place[fit_class]
                                local passive = {
                                    id                          = passive_code,
                                    subtype                     = nosubtype_code,
                                    next                        = par.passive,
                                    cur_break                   = current,
                                    serial                      = par.pass_number,
                                    prev_break                  = prev_break,
                                    passive_pen_inter           = par.internal_pen_inter,
                                    passive_pen_broken          = par.internal_pen_broken,
                                    passive_last_left_box       = par.internal_left_box,
                                    passive_last_left_box_width = par.internal_left_box_width,
                                    passive_left_box            = prev_break and prev_break.passive_last_left_box or par.init_internal_left_box,
                                    passive_left_box_width      = prev_break and prev_break.passive_last_left_box_width or par.init_internal_left_box_width,
                                    passive_right_box           = par.internal_right_box,
                                    passive_right_box_width     = par.internal_right_box_width,
                                }
                                par.passive = passive
                                local q = {
                                    id             = break_type,
                                    subtype        = fit_class,
                                    break_node     = passive,
                                    line_number    = best_pl_line[fit_class] + 1,
                                    total_demerits = minimal_demerits[fit_class], --  or 0,
                                    next           = r,
                                }
                                if do_last_line_fit then
                                    local active_short = best_pl_short[fit_class]
                                    local active_glue  = best_pl_glue[fit_class]
                                    q.active_short = active_short
                                    q.active_glue  = active_glue
                                    if trace_lastlinefit then
                                        report_parbuilders("setting short to %i and glue to %p using class %a",active_short,active_glue,fit_class)
                                    end
                                end
                             -- q.next = r -- already done
                                prev_r.next = q
                                prev_r = q
                                if tracing_paragraphs then
                                    diagnostics.break_node(par,q,fit_class,break_type,current)
                                end
                            end
                            minimal_demerits[fit_class] = awful_badness
                        end
                        par.minimum_demerits = awful_badness
                        if r ~= par.active then
                            local q = checked_expansion and {
                                id             = delta_code,
                                subtype        = nosubtype_code,
                                next           = r,
                                size           = cur_active_width.size           - break_width.size,
                                normal         = cur_active_width.normal         - break_width.normal,
                                fi             = cur_active_width.fi             - break_width.fi,
                                fil            = cur_active_width.fil            - break_width.fil,
                                fill           = cur_active_width.fill           - break_width.fill,
                                filll          = cur_active_width.filll          - break_width.filll,
                                shrink         = cur_active_width.shrink         - break_width.shrink,
                                adjust_stretch = cur_active_width.adjust_stretch - break_width.adjust_stretch,
                                adjust_shrink  = cur_active_width.adjust_shrink  - break_width.adjust_shrink,
                            } or {
                                id      = delta_code,
                                subtype = nosubtype_code,
                                next    = r,
                                size    = cur_active_width.size   - break_width.size,
                                normal  = cur_active_width.normal - break_width.normal,
                                fi      = cur_active_width.fi     - break_width.fi,
                                fil     = cur_active_width.fil    - break_width.fil,
                                fill    = cur_active_width.fill   - break_width.fill,
                                filll   = cur_active_width.filll  - break_width.filll,
                                shrink  = cur_active_width.shrink - break_width.shrink,
                            }
                         -- q.next = r -- already done
                            prev_r.next = q
                            prev_prev_r = prev_r
                            prev_r = q
                        end
                    end
                    if r == par.active then
                        return r, r and r.next -- p_active, n_active
                    end
                    if line_number > par.easy_line then
                        old_line_number = max_halfword - 1
                        line_width = par.second_width
                    else
                        old_line_number = line_number
                        if line_number > par.last_special_line then
                            line_width = par.second_width
                        elseif parshape then
                            line_width = parshape[line_number][2]
                        else
                            line_width = par.first_width
                        end
                    end
                 -- if adapt_width then
                 --     local l, r = adapt_width(par,line_number)
                 --     line_width = line_width  - l - r
                 -- end
                end
                local artificial_demerits = false -- has d been forced to zero
                local shortfall = line_width - cur_active_width.size - par.internal_right_box_width -- used in badness calculations
                if not r.break_node then
                    shortfall = shortfall - par.init_internal_left_box_width
                else
                    shortfall = shortfall - (r.break_node.passive_last_left_box_width or 0)
                end
                if protrude_chars > 1 then
                    if par.line_break_dir == righttoleft_code then
                        -- not now, we need to keep more track
                    else
                        -- this is quite time consuming
                        local b = r.break_node
                        local l = b and b.cur_break or first_p
                        local o = current and getprev(current)
                        if current and getid(current) == disc_code then
                            local pre, _, _, pretail = getdisc(current,true)
                            if pre then
                                o = pretail
                            else
                                o = find_protchar_right(l,o)
                            end
                        else
                            o = find_protchar_right(l,o)
                        end
                        if o and getid(o) == glyph_code then
                            shortfall = shortfall + right_pw(o)
                        end
                        local id = getid(l)
                        if id == glyph_code then
                            -- ok ?
                        elseif id == disc_code and getpost(l) then
                            l = getpost(l) -- TODO: first char could be a disc
                        else
                            l = find_protchar_left(l)
                        end
                        if l and getid(l) == glyph_code then
                            shortfall = shortfall + left_pw(l)
                        end
                    end
                end
                if checked_expansion and shortfall ~= 0 then
                    if shortfall > 0 then
                        local total = cur_active_width.adjust_stretch
                        if total > 0 then
                            if total > shortfall then
                                shortfall = total / (par.max_stretch_ratio / par.cur_font_step) / 2
                            else
                                shortfall = shortfall - total
                            end
                        end
                    elseif shortfall < 0 then
                        local total = cur_active_width.adjust_shrink
                        if total > 0 then
                            if total > - shortfall then
                                shortfall = - total / (par.max_shrink_ratio / par.cur_font_step) / 2
                            else
                                shortfall = shortfall + total
                            end
                        end
                    end
                end
                local b = 0
                local g = 0
                local fit_class = fit_decent_class
                local found = false
                if shortfall > 0  then
                    if cur_active_width.fi ~= 0 or cur_active_width.fil ~= 0 or cur_active_width.fill ~= 0 or cur_active_width.filll ~= 0 then
                        if not do_last_line_fit then
                            -- okay
                        elseif not current then
                            found, shortfall, fit_class, g, b = lastlinecrap(shortfall,r.active_short,r.active_glue,cur_active_width,par.fill_width,par.last_line_fit)
                        else
                            shortfall = 0
                        end
                    else
                        local stretch = cur_active_width.normal
                        if shortfall > 7230584 and stretch < 1663497 then
                            b = infinite_badness
                            fit_class = fit_very_loose_class
                        else
                            b = calculate_badness(shortfall,stretch)
                            if b > 99 then
                                fit_class = fit_very_loose_class
                            elseif b > 12 then
                                fit_class = fit_loose_class
                            else
                                fit_class = fit_decent_class
                            end
                        end
                    end
                else
                    local shrink = cur_active_width.shrink
                    if -shortfall > shrink then
                        b = infinite_badness + 1
                    else
                        b = calculate_badness(-shortfall,shrink)
                    end
                    if b > 12 then
                        fit_class = fit_tight_class
                    else
                        fit_class = fit_decent_class
                    end
                end
                if do_last_line_fit and not found then
                    if not current then
                     -- g = 0
                        shortfall = 0
                    elseif shortfall > 0 then
                        g = cur_active_width.normal
                    elseif shortfall < 0 then
                        g = cur_active_width.shrink
                    else
                        g = 0
                    end
                end
                -- ::FOUND::
                local continue_only = false -- brrr
                if b > infinite_badness or pi == eject_penalty then
                    if final_pass and par.minimum_demerits == awful_badness and r.next == par.active and prev_r == par.active then
                        artificial_demerits = true -- set demerits zero, this break is forced
                        node_r_stays_active = false
                    elseif b > par.threshold then
                        prev_r, r = deactivate_node(par,prev_prev_r,prev_r,r,cur_active_width,checked_expansion)
                        continue_only = true
                    else
                        node_r_stays_active = false
                    end
                else
                    prev_r = r
                    if b > par.threshold then
                        continue_only = true
                    else
                        node_r_stays_active = true
                    end
                end
                if not continue_only then
                    local d = 0
                    if not artificial_demerits then
                        d = par.line_penalty + b
                        if (d >= 0 and d or -d) >= 10000 then -- abs(d)
                            d = 100000000
                        else
                            d = d * d
                        end
                        if pi == 0 then
                            -- nothing
                        elseif pi > 0 then
                            d = d + pi * pi
                        elseif pi > eject_penalty then
                            d = d - pi * pi
                        end
                        if break_type == hyphenated_code and r.id == hyphenated_code then
                            if current then
                                d = d + par.double_hyphen_demerits
                            else
                                d = d + par.final_hyphen_demerits
                            end
                        end
                        local delta = fit_class - r.subtype
                        if (delta >= 0 and delta or -delta) > 1 then -- abs(delta)
                            d = d + par.adj_demerits
                        end
                    end
                    if tracing_paragraphs then
                        diagnostics.feasible_break(par,current,r,b,pi,d,artificial_demerits)
                    end
                    d = d + r.total_demerits -- this is the minimum total demerits from the beginning to current via r
                    if d <= minimal_demerits[fit_class] then
                        minimal_demerits[fit_class] = d
                        best_place      [fit_class] = r.break_node
                        best_pl_line    [fit_class] = line_number
                        if do_last_line_fit then
                            best_pl_short[fit_class] = shortfall
                            best_pl_glue [fit_class] = g
                            if trace_lastlinefit then
                                report_parbuilders("storing last line fit short %a and glue %p in class %a",shortfall,g,fit_class)
                            end
                        end
                        if d < par.minimum_demerits then
                            par.minimum_demerits = d
                        end
                    end
                    if not node_r_stays_active then
                        prev_r, r = deactivate_node(par,prev_prev_r,prev_r,r,cur_active_width,checked_expansion)
                    end
                end
            end
        end
    end

    -- we can call the normal one for simple box building in the otr so we need
    -- frequent enabling/disabling

    local temp_head = new_temp()

    function constructors.methods.basic(head,d)
        if trace_basic then
            report_parbuilders("starting at %a",head)
        end
        local par = initialize_line_break(head,d)

        local checked_expansion  = par.checked_expansion
        local active_width       = par.active_width
        local disc_width         = par.disc_width
        local background         = par.background
        local tracing_paragraphs = par.tracing_paragraphs
        local dirstack           = { n = 0 }

        par.dirstack = dirstack

        if tracing_paragraphs then
            diagnostics.start()
            if par.pretolerance >= 0 then
                diagnostics.current_pass(par,"firstpass")
            end
        end

        while true do
            reset_meta(par)
            if par.threshold > infinite_badness then
                par.threshold = infinite_badness
            end
            par.active.next = {
                id             = unhyphenated_code,
                subtype        = fit_decent_class,
                next           = par.active,
                break_node     = nil,
                line_number    = par.first_line + 1,
                total_demerits = 0,
                active_short   = 0,
                active_glue    = 0,
            }
            active_width.size   = background.size
            active_width.normal = background.normal
            active_width.fi     = background.fi
            active_width.fil    = background.fil
            active_width.fill   = background.fill
            active_width.filll  = background.filll
            active_width.shrink = background.shrink

            if checked_expansion then
                active_width.adjust_stretch = 0
                active_width.adjust_shrink  = 0
            end

            par.passive                 = nil -- = 0
            par.printed_node            = temp_head -- only when tracing, shared
            par.pass_number             = 0
         -- par.auto_breaking           = true

            setnext(temp_head,head)

            local current               = head
            local first_p               = current
            local auto_breaking         = true

            par.font_in_short_display   = 0

            if current then
                local id = getid(current)
                if id == localpar_code then
                    par.init_internal_left_box       = getfield(current,"box_left")
                    par.init_internal_left_box_width = getfield(current,"box_left_width")
                    par.internal_pen_inter           = getfield(current,"pen_inter")
                    par.internal_pen_broken          = getfield(current,"pen_broken")
                    par.internal_left_box            = par.init_internal_left_box
                    par.internal_left_box_width      = par.init_internal_left_box_width
                    par.internal_right_box           = getfield(current,"box_right")
                    par.internal_right_box_width     = getfield(current,"box_right_width")
                end
            end

            -- all passes are combined in this loop so maybe we should split this into
            -- three function calls; we then also need to do the wrap_up elsewhere

            -- split into normal and expansion loop

            -- use an active local

            local fontexp, lastfont -- we can pass fontexp to calculate width if needed

            -- i flattened the inner loop over glyphs .. it looks nicer and the extra p_active ~= n_active
            -- test is fast enough (and try_break now returns the updated values); the kern helper has been
            -- inlined as it did a double check on id so in fact we had hardly any code to share

            local p_active    = par.active
            local n_active    = p_active and p_active.next
            local second_pass = par.second_pass

            trialcount = 0

            while current and p_active ~= n_active do
                local char, id = isglyph(current)
                if char then
                    active_width.size = active_width.size + getwidth(current)
                    if checked_expansion then
                        local font = id -- == font
                        local data = checked_expansion[font]
                        if data then
                            if font ~= lastfont then
                                fontexps = checked_expansion[font] -- a bit redundant for the par line packer
                                lastfont = currentfont
                            end
                            if fontexps then
                                local expansion = fontexps[char]
                                if expansion then
                                    active_width.adjust_stretch = active_width.adjust_stretch + expansion.glyphstretch
                                    active_width.adjust_shrink  = active_width.adjust_shrink  + expansion.glyphshrink
                                end
                            end
                        end
                    end
                elseif id == hlist_code or id == vlist_code then
                    active_width.size = active_width.size + getwidth(current)
                elseif id == glue_code then
                    goto glue
                elseif id == disc_code then
                    local subtype = getsubtype(current)
                    if subtype ~= seconddisc_code then
                        local line_break_dir = par.line_break_dir
                        if second_pass or subtype <= automaticdisc_code then
                            local actual_pen = getpenalty(current)
                            local pre, post, replace = getdisc(current)
                            if not pre then    --  trivial pre-break
                                disc_width.size = 0
                                if checked_expansion then
                                    disc_width.adjust_stretch = 0
                                    disc_width.adjust_shrink  = 0
                                end
                                p_active, n_active = try_break(actual_pen, hyphenated_code, par, first_p, current, checked_expansion)
                            else
                                local size, adjust_stretch, adjust_shrink = add_to_width(line_break_dir,checked_expansion,pre)
                                disc_width.size   = size
                                active_width.size = active_width.size + size
                                if checked_expansion then
                                    disc_width.adjust_stretch   = adjust_stretch
                                    disc_width.adjust_shrink    = adjust_shrink
                                    active_width.adjust_stretch = active_width.adjust_stretch + adjust_stretch
                                    active_width.adjust_shrink  = active_width.adjust_shrink  + adjust_shrink
                                else
                                 -- disc_width.adjust_stretch = 0
                                 -- disc_width.adjust_shrink  = 0
                                end
                                p_active, n_active = try_break(actual_pen, hyphenated_code, par, first_p, current, checked_expansion)
                                if subtype == firstdisc_code then
                                    local cur_p_next = getnext(current)
                                    if getid(cur_p_next) ~= disc_code or getsubtype(cur_p_next) ~= seconddisc_code then
                                        report_parbuilders("unsupported disc at location %a",1)
                                    else
                                        local pre = getpre(cur_p_next)
                                        if pre then
                                            local size, adjust_stretch, adjust_shrink = add_to_width(line_break_dir,checked_expansion,pre)
                                            disc_width.size = disc_width.size + size
                                            if checked_expansion then
                                                disc_width.adjust_stretch = disc_width.adjust_stretch + adjust_stretch
                                                disc_width.adjust_shrink  = disc_width.adjust_shrink  + adjust_shrink
                                            end
                                            p_active, n_active = try_break(actual_pen, hyphenated_code, par, first_p, cur_p_next, checked_expansion)
                                            -- there is a comment about something messy here in the source
                                        else
                                            report_parbuilders("unsupported disc at location %a",2)
                                        end
                                    end
                                end
                                -- beware, we cannot restore to a saved value as the try_break adapts active_width
                                active_width.size = active_width.size - disc_width.size
                                if checked_expansion then
                                    active_width.adjust_stretch = active_width.adjust_stretch - disc_width.adjust_stretch
                                    active_width.adjust_shrink  = active_width.adjust_shrink  - disc_width.adjust_shrink
                                end
                            end
                        end
                        if replace then
                            local size, adjust_stretch, adjust_shrink = add_to_width(line_break_dir,checked_expansion,replace)
                            active_width.size = active_width.size + size
                            if checked_expansion then
                                active_width.adjust_stretch = active_width.adjust_stretch + adjust_stretch
                                active_width.adjust_shrink  = active_width.adjust_shrink  + adjust_shrink
                            end
                        end
                    end
                elseif id == kern_code then
                    local s = getsubtype(current)
                    local kern = getkern(current)
                    if s == userkern_code or s == italickern_code then
                        local v = getnext(current)
                        if auto_breaking and getid(v) == glue_code then
                            p_active, n_active = try_break(0, unhyphenated_code, par, first_p, current, checked_expansion)
                        end
                        local active_width = par.active_width
                        active_width.size = active_width.size + kern
                    elseif kern ~= 0 then
                        active_width.size = active_width.size + kern
                        if checked_expansion and expand_kerns and s == fontkern_code then
                            local stretch, shrink = kern_stretch_shrink(current,kern)
                            if expand_kerns == "stretch" then
                                active_width.adjust_stretch = active_width.adjust_stretch + stretch
                            elseif expand_kerns == "shrink" then
                                active_width.adjust_shrink  = active_width.adjust_shrink  + shrink
                            else
                                active_width.adjust_stretch = active_width.adjust_stretch + stretch
                                active_width.adjust_shrink  = active_width.adjust_shrink  + shrink
                            end
                        end
                    end
                elseif id == math_code then
                    auto_breaking = getsubtype(current) == endmath_code
                    if is_zero_glue(current) or ignore_math_skip(current) then
                        local v = getnext(current)
                        if auto_breaking and getid(v) == glue_code then
                            p_active, n_active = try_break(0, unhyphenated_code, par, first_p, current, checked_expansion)
                        end
                        local active_width = par.active_width
                        active_width.size = active_width.size + getkern(current) + getwidth(current)
                    else
                        goto glue
                    end
                elseif id == rule_code then
                    active_width.size = active_width.size + getwidth(current)
                elseif id == penalty_code then
                    p_active, n_active = try_break(getpenalty(current), unhyphenated_code, par, first_p, current, checked_expansion)
                elseif id == dir_code then
                    par.line_break_dir = checked_line_dir(dirstack,current) or par.line_break_dir
                elseif id == localpar_code then
                    par.internal_pen_inter       = getfield(current,"pen_inter")
                    par.internal_pen_broken      = getfield(current,"pen_broken")
                    par.internal_left_box        = getfield(current,"box_left")
                    par.internal_left_box_width  = getfield(current,"box_left_width")
                    par.internal_right_box       = getfield(current,"box_right")
                    par.internal_right_box_width = getfield(current,"box_right_width")
                elseif trace_unsupported then
                    if id == mark_code or id == ins_code or id == adjust_code then
                        -- skip
                    else
                        report_parbuilders("node of type %a found in paragraph",type(id))
                    end
                end
                goto done
              ::glue::
                do
                    if auto_breaking then
                        local prev_p = getprev(current)
                        if prev_p and prev_p ~= temp_head then
                            local id = getid(prev_p)
                            -- we need to check this with the latest patches to the tex kernel
                            if (id == glyph_code) or (id < math_code) then
                                p_active, n_active = try_break(0, unhyphenated_code, par, first_p, current, checked_expansion)
                            elseif id == kern_code then
                                local s = getsubtype(prev_p)
                                if s ~= userkern_code and s ~= italickern_code then
                                    p_active, n_active = try_break(0, unhyphenated_code, par, first_p, current, checked_expansion)
                                end
                            end
                        end
                    end
                    local width, stretch, shrink, stretch_order, shrink_order = getglue(current)
                    if shrink_order ~= 0 and shrink ~= 0 then
                        infinite_shrinkage_error(par)
                        shrink_order = 0
                    end
                    local order = fillcodes[stretch_order]
                    active_width.size   = active_width.size   + width
                    active_width[order] = active_width[order] + stretch
                    active_width.shrink = active_width.shrink + shrink
                end
              ::done::
                current = getnext(current)
            end
            if not current then
                local p_active, n_active = try_break(eject_penalty, hyphenated_code, par, first_p, current, checked_expansion)
                if n_active ~= p_active then
                    local r = n_active
                    par.fewest_demerits = awful_badness
                    repeat -- use local d
                        if r.id ~= delta_code and r.total_demerits < par.fewest_demerits then
                            par.fewest_demerits = r.total_demerits
                            par.best_bet = r
                        end
                        r = r.next
                    until r == p_active
                    par.best_line = par.best_bet.line_number
                    local asked_looseness = par.looseness
                    if asked_looseness == 0 then
                        return wrap_up(par)
                    end
                    local r = n_active
                    local actual_looseness = 0
                    -- minimize assignments to par but happens seldom
                    repeat
                        if r.id ~= delta_code then
                            local line_diff = r.line_number - par.best_line
                            par.line_diff = line_diff
                            if (line_diff < actual_looseness and asked_looseness <= line_diff)   or
                               (line_diff > actual_looseness and asked_looseness >= line_diff) then
                                par.best_bet = r
                                actual_looseness = line_diff
                                par.fewest_demerits = r.total_demerits
                            elseif line_diff == actual_looseness and r.total_demerits < par.fewest_demerits then
                                par.best_bet = r
                                par.fewest_demerits = r.total_demerits
                            end
                        end
                        r = r.next
                    until r == p_active
                    par.best_line = par.best_bet.line_number
                    if actual_looseness == asked_looseness or par.final_pass then
                        return wrap_up(par)
                    end
                end
            end
            reset_meta(par) -- clean up the memory by removing the break nodes
            if not second_pass then
                if tracing_paragraphs then
                    diagnostics.current_pass(par,"secondpass")
                end
                par.threshold   = par.tolerance
                par.second_pass = true
                par.final_pass  = par.emergency_stretch <= 0
            else
                if tracing_paragraphs then
                    diagnostics.current_pass(par,"emergencypass")
                end
                par.background.normal = par.background.normal + par.emergency_stretch
                par.final_pass        = true
            end
        end
        return wrap_up(par)
    end

end

-- standard tex logging .. will be adapted ..

do

    local tonumber   = tonumber
    local utfchar    = utf.char
    local write      = texio.write
    local write_nl   = texio.write_nl
    local formatters = string.formatters

    local function write_esc(cs)
        local esc = texget("escapechar")
        if esc then
            write("log",utfchar(esc),cs)
        else
            write("log",cs)
        end
    end

    function diagnostics.start()
    end

    function diagnostics.stop()
        write_nl("log",'')
    end

    function diagnostics.current_pass(par,what)
        write_nl("log",formatters["@%s"](what))
    end

    local verbose = false -- true

    local function short_display(target,a,font_in_short_display)
        while a do
            local char, id = isglyph(a)
            if char then
                -- id == font
                if id ~= font_in_short_display then
                    write(target,tex.fontidentifier(id) .. ' ')
                    font_in_short_display = id
                end
                local u = chardata[id][char]
                local u = u.unicode or char
                if type(u) == "table" then
                    for i=1,#u do
                        write(target,utfchar(u[i]))
                    end
                else
                    write(target,utfchar(u))
                end
            elseif id == disc_code then
                local pre, post, replace = getdisc(a)
                font_in_short_display = short_display(target,pre,font_in_short_display)
                font_in_short_display = short_display(target,post,font_in_short_display)
            elseif verbose then
                write(target,formatters["[%s]"](nodecodes[id]))
            elseif id == rule_code then
                write(target,"|")
            elseif id == glue_code then
                write(target," ")
            elseif id == kern_code then
                local s = getsubtype(a)
                if s == fontkern_code or s == accentkern_code then
                    if verbose then
                        write(target,"[|]")
                 -- else
                 --     write(target,"")
                    end
                else
                    write(target,"[]")
                end
            elseif id == math_code then
                write(target,"$")
            else
                write(target,"[]")
            end
            a = getnext(a)
        end
        return font_in_short_display
    end

    diagnostics.short_display = short_display

    function diagnostics.break_node(par, q, fit_class, break_type, current) -- %d ?
        local passive = par.passive
        local typ_ind = break_type == hyphenated_code and '-' or ""
        if par.do_last_line_fit then
            local s = q.active_short
            local g = q.active_glue
            if current then
                write_nl("log",formatters["@@%d: line %d.%d%s t=%s s=%p g=%p"](
                    passive.serial or 0,q.line_number-1,fit_class,typ_ind,q.total_demerits,s,g))
            else
                write_nl("log",formatters["@@%d: line %d.%d%s t=%s s=%p a=%p"](
                    passive.serial or 0,q.line_number-1,fit_class,typ_ind,q.total_demerits,s,g))
            end
        else
            write_nl("log",formatters["@@%d: line %d.%d%s t=%s"](
                passive.serial or 0,q.line_number-1,fit_class,typ_ind,q.total_demerits))
        end
        if not passive.prev_break then
            write("log"," -> @0")
        else
            write("log",formatters[" -> @%d"](passive.prev_break.serial or 0))
        end
    end

    function diagnostics.feasible_break(par, current, r, b, pi, d, artificial_demerits)
        local printed_node = par.printed_node
        if printed_node ~= current then
            write_nl("log","")
            if not current then
                par.font_in_short_display = short_display("log",getnext(printed_node),par.font_in_short_display)
            else
                local save_link = getnext(current)
                setnext(current)
                write_nl("log","")
                par.font_in_short_display = short_display("log",getnext(printed_node),par.font_in_short_display)
                setnext(current,save_link)
            end
            par.printed_node = current
        end
        write_nl("log","@")
        if not current then
            write_esc("par")
        else
            local id = getid(current)
            if id == glue_code then
                -- print nothing
            elseif id == penalty_code then
                write_esc("penalty")
            elseif id == disc_code then
                write_esc("discretionary")
            elseif id == kern_code then
                write_esc("kern")
            elseif id == math_code then
                write_esc("math")
            else
                write_esc("unknown")
            end
        end
        local via, badness, demerits = 0, '*', '*'
        if r.break_node then
            via = r.break_node.serial or 0
        end
        if b <= infinite_badness then
            badness = tonumber(d)
        end
        if not artificial_demerits then
            demerits = tonumber(d)
        end
        write("log",formatters[" via @%d b=%s p=%s d=%s"](via,badness,pi,demerits))
    end

    --

    local function common_message(hlist,line,str)
        write_nl("")
        if status.output_active then -- unset
            write(str," has occurred while \\output is active")
        else
            write(str)
        end
        local fileline = status.linenumber
        if line > 0 then
            write(formatters[" in paragraph at lines %s--%s"](fileline,"--",fileline+line-1))
        elseif line < 0 then
            write(formatters[" in alignment at lines "](fileline,"--",fileline-line-1))
        else
            write(formatters[" detected at line %s"](fileline))
        end
        write_nl("")
        diagnostics.short_display(getlist(hlist),false)
        write_nl("")
     -- diagnostics.start()
     -- show_box(getlist(hlist))
     -- diagnostics.stop()
    end

    function diagnostics.overfull_hbox(hlist,line,d)
        common_message(hlist,line,formatters["Overfull \\hbox (%p too wide)"](d))
    end

    function diagnostics.bad_hbox(hlist,line,b)
        common_message(hlist,line,formatters["Tight \\hbox (badness %i)"](b))
    end

    function diagnostics.underfull_hbox(hlist,line,b)
        common_message(hlist,line,formatters["Underfull \\hbox (badness %i)"](b))
    end

    function diagnostics.loose_hbox(hlist,line,b)
        common_message(hlist,line,formatters["Loose \\hbox (badness %i)"](b))
    end

    -- reporting --

    statistics.register("alternative parbuilders", function()
        if nofpars > 0 then
            return formatters["%s paragraphs, %s lines (%s protruded, %s adjusted)"](nofpars,noflines,nofprotrudedlines,nofadjustedlines)
        end
    end)

end

do

    -- actually scaling kerns is not such a good idea and it will become
    -- configureable

    -- This is no way a replacement for the built in (fast) packer
    -- it's just an alternative for special (testing) purposes.
    --
    -- We could use two hpacks: one to be used in the par builder
    -- and one to be used for other purposes. The one in the par
    -- builder is much more simple as it does not need the expansion
    -- code but only need to register the effective expansion factor
    -- with the glyph.

    local setnodecolor = nodes.tracers.colors.set

    local function hpack(head,width,method,direction,firstline,line) -- fast version when head = nil

        -- we can pass the adjust_width and adjust_height so that we don't need to recalculate them but
        -- with the glue mess it's less trivial as we lack detail .. challenge

        local hlist = new_hlist()

        setdirection(hlist,direction)
        setattributelist(hlist,head)

        if head == nil then
            setwidth(hlist,width)
            return hlist, 0
        else
            setlist(hlist,head)
        end

        local cal_expand_ratio  = method == "cal_expand_ratio" or method == "subst_ex_font"

        direction               = direction or texget("textdir")

        local line              = 0

        local height            = 0
        local depth             = 0
        local natural           = 0
        local font_stretch      = 0
        local font_shrink       = 0
        local font_expand_ratio = 0
        local last_badness      = 0
        local expansion_stack   = cal_expand_ratio and { } -- todo: optionally pass this
        local expansion_index   = 0
        local total_stretch     = { [0] = 0, 0, 0, 0, 0 }
        local total_shrink      = { [0] = 0, 0, 0, 0, 0 }

        local hpack_dir         = direction

        local adjust_head       = texlists.adjust_head
        local pre_adjust_head   = texlists.pre_adjust_head
        local adjust_tail       = adjust_head and find_tail(adjust_head)
        local pre_adjust_tail   = pre_adjust_head and find_tail(pre_adjust_head)

        local checked_expansion = false

        if cal_expand_ratio then
            checked_expansion = { }
            setmetatableindex(checked_expansion,check_expand_lines)
        end

        -- this one also needs to check the font, so in the end indeed we might end up with two variants

        -- we now have fast loops so maybe no longer a need for an expansion stack

        local fontexps, lastfont

        local function process(current) -- called nested in disc replace
            while current do
                local char, id = isglyph(current)
                if char then
                    if cal_expand_ratio then
                        local font = id -- == font
                        if font ~= lastfont then
                            fontexps = checked_expansion[font] -- a bit redundant for the par line packer
                            lastfont = font
                        end
                        if fontexps then
                            local expansion = fontexps[char]
                            if expansion then
                                font_stretch = font_stretch + expansion.glyphstretch
                                font_shrink  = font_shrink  + expansion.glyphshrink
                                expansion_index = expansion_index + 1
                                expansion_stack[expansion_index] = current
                            end
                        end
                    end
                    local wd, ht, dp = getwhd(current)
                    if ht > height then
                        height = ht
                    end
                    if dp > depth then
                        depth = dp
                    end
                    natural = natural + wd
                elseif id == kern_code then
                    local kern = getkern(current)
                    if kern == 0 then
                        -- no kern
                    elseif getsubtype(current) == fontkern_code then
                        if cal_expand_ratio then
                            local stretch, shrink = kern_stretch_shrink(current,kern)
                            font_stretch = font_stretch + stretch
                            font_shrink  = font_shrink + shrink
                            expansion_index = expansion_index + 1
                            expansion_stack[expansion_index] = current
                        end
                        natural = natural + kern
                    else
                        natural = natural + kern
                    end
                elseif id == disc_code then
                    local subtype = getsubtype(current)
                    if subtype ~= seconddisc_code then
                        -- todo : local stretch, shrink = char_stretch_shrink(s)
                        local replace = getreplace(current)
                        if replace then
                            process(replace)
                        end
                    end
                elseif id == glue_code then
                    local wd, stretch, shrink, stretch_order, shrink_order = getglue(current)
                    total_stretch[stretch_order] = total_stretch[stretch_order] + stretch
                    total_shrink [shrink_order]  = total_shrink[shrink_order]   + shrink
                    if getsubtype(current) >= leaders_code then
                        local wd, ht, dp = getwhd(leader)
                        local leader = getleader(current)
                        if ht > height then
                            height = ht
                        end
                        if dp > depth then
                            depth = dp
                        end
                    end
                    natural = natural + wd
                elseif id == hlist_code or id == vlist_code then
                    local wd, ht, dp = getwhd(current)
                    local sh = getshift(current)
                    local hs = ht - sh
                    local ds = dp + sh
                    if hs > height then
                        height = hs
                    end
                    if ds > depth then
                        depth = ds
                    end
                    natural = natural + wd
                elseif id == rule_code or id == unset_code then
                    local wd, ht, dp = getwhd(current)
                    if ht > height then
                        height = ht
                    end
                    if dp > depth then
                        depth = dp
                    end
                    natural = natural + wd
                elseif id == math_code then
                    if is_zero_glue(current) or ignore_math_skip(current) then
                        natural = natural + getkern(current)
                    else
                        local wd, stretch, shrink, stretch_order, shrink_order = getglue(current)
                        total_stretch[stretch_order] = total_stretch[stretch_order] + stretch
                        total_shrink [shrink_order]  = total_shrink[shrink_order]   + shrink
                        natural = natural + wd
                    end
                elseif id == ins_code or id == mark_code then
                    local prev, next = getboth(current)
                    if adjust_tail then -- todo
                        setlink(prev,next)
                        setlink(adjust_tail,current)
                        setnext(current)
                        adjust_tail = current
                    else
                        adjust_head = current
                        adjust_tail = current
                        setboth(current)
                    end
                elseif id == adjust_code then
                    local list = getlist(current)
                    if adjust_tail then
                        setnext(adjust_tail,list)
                    else
                        adjust_head = list
                    end
                    adjust_tail = find_tail(list)
                elseif id == dir_code then
                    -- no need to deal with directions here (as we only support two)
                elseif id == marginkern_code then
                     natural = natural + getwidth(current)
                end
                current = getnext(current)
            end

        end

        process(head)

        if adjust_tail then
            adjust_tail.next = nil -- todo
        end
        if pre_adjust_tail then
            pre_adjust_tail.next = nil -- todo
        end
        if method == "additional" then
            width = width + natural
        end
        setwhd(hlist,width,height,depth)
        local delta  = width - natural
        if delta == 0 then
            setglue(hlist,0,0,0) -- set order sign
        elseif delta > 0 then
            -- natural width smaller than requested width
            local order = (total_stretch[4] ~= 0 and 4) or (total_stretch[3] ~= 0 and 3) or
                          (total_stretch[2] ~= 0 and 2) or (total_stretch[1] ~= 0 and 1) or 0
            if cal_expand_ratio and order == 0 and font_stretch > 0 then -- check sign of font_stretch
                font_expand_ratio = delta/font_stretch
                if font_expand_ratio > 1 then
                    font_expand_ratio = 1
                elseif font_expand_ratio < -1 then
                    font_expand_ratio = -1
                end
                local fontexps, lastfont
                for i=1,expansion_index do
                    local g = expansion_stack[i]
                    local e = 0
                    local char, font = isglyph(g)
                    if char then
                        if font ~= lastfont then
                            fontexps = expansions[font]
                            lastfont = font
                        end
                        local data = fontexps[char]
                        if data then
                            if trace_expansion then
                                setnodecolor(g,"hz:positive")
                            end
                            e = font_expand_ratio * data.glyphstretch
                        end
                    else
                        local kern = getkern(g)
                        local stretch, shrink = kern_stretch_shrink(g,kern)
                        e = font_expand_ratio * stretch
                    end
                    setexpansion(g,e)
                end
                font_stretch = font_expand_ratio * font_stretch
                delta = delta - font_stretch
            end
            local tso = total_stretch[order]
            if tso ~= 0 then
                setglue(hlist,delta/tso,order,1) -- set order sign
            else
                setglue(hlist,0,order,0) -- set order sign
            end
            if font_expand_ratio ~= 0 then
                -- todo
            elseif order == 0 then -- and getlist(hlist) then
                last_badness = calculate_badness(delta,total_stretch[0])
                if last_badness > texget("hbadness") then
                    if last_badness > 100 then
                        diagnostics.underfull_hbox(hlist,line,last_badness)
                    else
                        diagnostics.loose_hbox(hlist,line,last_badness)
                    end
                end
            end
        else
            -- natural width larger than requested width
            local order = (total_shrink[4] ~= 0 and 4) or (total_shrink[3] ~= 0 and 3)
                       or (total_shrink[2] ~= 0 and 2) or (total_shrink[1] ~= 0 and 1) or 0
            if cal_expand_ratio and order == 0 and font_shrink > 0 then -- check sign of font_shrink
                font_expand_ratio = delta/font_shrink
                if font_expand_ratio > 1 then
                    font_expand_ratio = 1
                elseif font_expand_ratio < -1 then
                    font_expand_ratio = -1
                end
                local fontexps, lastfont
                for i=1,expansion_index do
                    local g = expansion_stack[i]
                    local e = 0
                    local char, font = isglyph(g)
                    if char then
                        if font ~= lastfont then
                            fontexps = expansions[font]
                            lastfont = font
                        end
                        local data = fontexps[char]
                        if data then
                            if trace_expansion then
                                setnodecolor(g,"hz:negative")
                            end
                            e = font_expand_ratio * data.glyphshrink
                        end
                    else
                        local kern = getkern(g)
                        local stretch, shrink = kern_stretch_shrink(g,kern)
                        e = font_expand_ratio * shrink
                    end
                    setexpansion(g,e)
                end
                font_shrink = font_expand_ratio * font_shrink
                delta = delta - font_shrink
            end
            local tso = total_shrink[order]
            if tso ~= 0 then
                setglue(hlist,-delta/tso,order,2) -- set order sign
            else
                setglue(hlist,0,order,0) -- set order sign
            end
            if font_expand_ratio ~= 0 then
                -- todo
            elseif tso < -delta and order == 0 then
                last_badness = 1000000
                setfield(hlist,"glue_set",1)
                local fuzz  = - delta - tso
                local hfuzz = texget("hfuzz")
                if fuzz > hfuzz or texget("hbadness") < 100 then
                    local overfullrule = texget("overfullrule")
                    if fuzz > hfuzz and overfullrule > 0 then
                        -- weird, is always called and no rules shows up
                        setnext(find_tail(list),new_rule(overfullrule,nil,nil,getdirection(hlist)))
                    end
                    diagnostics.overfull_hbox(hlist,line,fuzz)
                    if head and getnormalizeline() > 4 then
                        -- we need to get rid of this one when we unpack a box but on the
                        -- other hand, we only do this when a specific width is set so
                        -- probably we have a fixed box then
                        local h = getnext(head)
                        if h then
                            local found = find_node(glue_code,rightskip_code)
                            if found then
                                local p = getprev(found)
                                local g = new_correctionskip(-fuzz)
                                setattributelist(g,found)
                                if p and getid(p) == marginkern_code then
                                    found = p
                                end
                                insert_node_before(head,found,g)
                            end
                        end
                    end
                end
            elseif order == 0 and getlist(hlist) and last_badness > texget("hbadness") then
                diagnostics.bad_hbox(hlist,line,last_badness)
            end
        end
        return hlist, last_badness
    end

    xpack_nodes = hpack -- comment this for old fashioned expansion (we need to fix float mess)

    constructors.methods.hpack = hpack

end
