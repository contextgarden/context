if not modules then modules = { } end modules ['scrp-cjk'] = {
    version   = 1.001,
    comment   = "companion to scrp-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We can speed this up by preallocating nodes and copying them but the gain is not
-- that large.
--
-- If needed we can speed this up (traversers and prev next and such) but cjk
-- documents don't have that many glyphs and certainly not much font processing so
-- there not much gain in it.
--
-- The input line endings: there is no way to distinguish between inline spaces and
-- endofline turned into spaces (would not make sense either because otherwise a
-- wanted space at the end of a line would have to be a hard coded ones.

local nuts               = nodes.nuts

local insert_node_after  = nuts.insert_after
local insert_node_before = nuts.insert_before
local copy_node          = nuts.copy
local remove_node        = nuts.remove
local nextglyph          = nuts.traversers.glyph

local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getfont            = nuts.getfont
local getchar            = nuts.getchar
local getid              = nuts.getid
local getattr            = nuts.getattr
local getsubtype         = nuts.getsubtype
local getwidth           = nuts.getwidth

local setchar            = nuts.setchar

local nodepool           = nuts.pool
local new_glue           = nodepool.glue
local new_kern           = nodepool.kern
local new_penalty        = nodepool.penalty

local nodecodes          = nodes.nodecodes
local gluecodes          = nodes.gluecodes

local glyph_code         = nodecodes.glyph
local glue_code          = nodecodes.glue

local userskip_code      = gluecodes.userskip
local spaceskip_code     = gluecodes.spaceskip
local xspaceskip_code    = gluecodes.xspaceskip

local a_scriptstatus     = attributes.private('scriptstatus')
local a_scriptinjection  = attributes.private('scriptinjection')

local categorytonumber   = scripts.categorytonumber
local numbertocategory   = scripts.numbertocategory
local hash               = scripts.hash
local numbertodataset    = scripts.numbertodataset

local fonthashes         = fonts.hashes
local quaddata           = fonthashes.quads
local spacedata          = fonthashes.spaces

local decomposed         = characters.hangul.decomposed

local trace_details      = false  trackers.register("scripts.details", function(v) trace_details = v end)

local report_details     = logs.reporter("scripts","detail")

-- raggedleft is controlled by leftskip and we might end up with a situation where
-- the intercharacter spacing interferes with this; the solution is to patch the
-- nodelist but better is to use veryraggedleft

local inter_char_shrink          = 0
local inter_char_stretch         = 0
local inter_char_half_shrink     = 0
local inter_char_half_stretch    = 0
local inter_char_quarter_shrink  = 0
local inter_char_quarter_stretch = 0

local full_char_width            = 0
local half_char_width            = 0
local quarter_char_width         = 0

local inter_char_hangul_penalty  = 0

local function set_parameters(font,data)
    -- beware: parameters can be nil in e.g. punk variants
    local quad = quaddata[font]
    full_char_width            = quad
    half_char_width            = quad/2
    quarter_char_width         = quad/4
    inter_char_shrink          = data.inter_char_shrink_factor          * quad
    inter_char_stretch         = data.inter_char_stretch_factor         * quad
    inter_char_half_shrink     = data.inter_char_half_shrink_factor     * quad
    inter_char_half_stretch    = data.inter_char_half_stretch_factor    * quad
    inter_char_quarter_shrink  = data.inter_char_quarter_shrink_factor  * quad
    inter_char_quarter_stretch = data.inter_char_quarter_stretch_factor * quad
    inter_char_hangul_penalty  = data.inter_char_hangul_penalty
end

-- a test version did compensate for crappy halfwidth but we can best do that
-- at font definition time and/or just assume a correct font

local function trace_detail(current,what)
    local prev = getprev(current)
    local c_id = getid(current)
    local p_id = prev and getid(prev)
    if c_id == glyph_code then
        local c_ch = getchar(current)
        if p_id == glyph_code then
            local p_ch = p_id and getchar(prev)
            report_details("[%C %a] [%s] [%C %a]",p_ch,hash[p_ch],what,c_ch,hash[c_ch])
        else
            report_details("[%s] [%C %a]",what,c_ch,hash[c_ch])
        end
    else
        if p_id == glyph_code then
            local p_ch = p_id and getchar(prev)
            report_details("[%C %a] [%s]",p_ch,hash[p_ch],what)
        else
            report_details("[%s]",what)
        end
    end
end

local function trace_detail_between(p,n,what)
    local p_ch = getchar(p)
    local n_ch = getchar(n)
    report_details("[%C %a] [%s] [%C %a]",p_ch,hash[p_ch],what,n_ch,hash[n_ch])
end

local function nobreak(head,current)
    if trace_details then
        trace_detail(current,"break")
    end
    insert_node_before(head,current,new_penalty(10000))
end

local function stretch_break(head,current)
    if trace_details then
        trace_detail(current,"stretch break")
    end
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function shrink_break(head,current)
    if trace_details then
        trace_detail(current,"shrink break")
    end
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_stretch(head,current)
    if trace_details then
        trace_detail(current,"no break stretch")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function korean_break(head,current)
    if trace_details then
        trace_detail(current,"korean break")
    end
    insert_node_before(head,current,new_penalty(inter_char_hangul_penalty))
end

local function nobreak_shrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak shrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_autoshrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak autoshrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_stretch_nobreak_shrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak stretch nobreak shrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_stretch_nobreak_autoshrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak stretch nobreak autoshrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_shrink_nobreak_stretch(head,current)
    if trace_details then
        trace_detail(current,"nobreak shrink nobreak stretch")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_autoshrink_nobreak_stretch(head,current)
    if trace_details then
        trace_detail(current,"nobreak autoshrink nobreak stretch")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_shrink_break_stretch(head,current)
    if trace_details then
        trace_detail(current,"nobreak shrink break stretch")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_autoshrink_break_stretch(head,current)
    if trace_details then
        trace_detail(current,"nobreak autoshrink break stretch")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_shrink_break_stretch_nobreak_shrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak shrink break stretch nobreak shrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function japanese_between_full_close_open(head,current) -- todo: check width
    if trace_details then
        trace_detail(current,"japanese between full close open")
    end
    insert_node_before(head,current,new_kern(-half_char_width))
    insert_node_before(head,current,new_glue(half_char_width,0,inter_char_half_shrink))
    insert_node_before(head,current,new_kern(-half_char_width))
end

local function japanese_between_full_close_full_close(head,current) -- todo: check width
    if trace_details then
        trace_detail(current,"japanese between full close full close")
    end
    insert_node_before(head,current,new_kern(-half_char_width))
 -- insert_node_before(head,current,new_glue(half_char_width,0,inter_char_half_shrink))
end

local function japanese_before_full_width_punct(head,current) -- todo: check width
    if trace_details then
        trace_detail(current,"japanese before full width punct")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(quarter_char_width,0,inter_char_quarter_shrink))
    insert_node_before(head,current,new_kern(-quarter_char_width))
end

local function japanese_after_full_width_punct(head,current) -- todo: check width
    if trace_details then
        trace_detail(current,"japanese after full width punct")
    end
    insert_node_before(head,current,new_kern(-quarter_char_width))
    insert_node_before(head,current,new_glue(quarter_char_width,0,inter_char_quarter_shrink))
end

local function nobreak_autoshrink_break_stretch_nobreak_autoshrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak autoshrink break stretch nobreak autoshrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_autoshrink_break_stretch_nobreak_shrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak autoshrink break stretch nobreak shrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_shrink_break_stretch_nobreak_autoshrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak shrink break stretch nobreak autoshrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
end

local function nobreak_stretch_break_shrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak stretch break shrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

local function nobreak_stretch_break_autoshrink(head,current)
    if trace_details then
        trace_detail(current,"nobreak stretch break autoshrink")
    end
    insert_node_before(head,current,new_penalty(10000))
    insert_node_before(head,current,new_glue(0,inter_char_stretch,0))
    insert_node_before(head,current,new_glue(0,0,inter_char_half_shrink))
end

-- Korean: hangul

local korean_0 = {
}

local korean_1 = {
    jamo_initial     = korean_break,
    korean           = korean_break,
    chinese          = korean_break,
    hiragana         = korean_break,
    katakana         = korean_break,
    half_width_open  = stretch_break,
    half_width_close = nobreak,
    full_width_open  = stretch_break,
    full_width_close = nobreak,
    full_width_punct = nobreak,
--  hyphen           = nil,
    non_starter      = korean_break,
    other            = korean_break,
}

local korean_2 = {
    jamo_initial     = stretch_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = stretch_break,
    half_width_close = nobreak,
    full_width_open  = stretch_break,
    full_width_close = nobreak,
    full_width_punct = nobreak,
--  hyphen           = nil,
    non_starter      = stretch_break,
    other            = stretch_break,
}

local korean_3 = {
    jamo_initial     = stretch_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = stretch_break,
    half_width_close = nobreak,
    full_width_open  = stretch_break,
    full_width_close = nobreak,
    full_width_punct = nobreak,
--  hyphen           = nil,
    non_starter      = nobreak,
    other            = nobreak,
}

local korean_4 = {
    jamo_initial     = nobreak,
    korean           = nobreak,
    chinese          = nobreak,
    hiragana         = nobreak,
    katakana         = nobreak,
    half_width_open  = nobreak,
    half_width_close = nobreak,
    full_width_open  = nobreak,
    full_width_close = nobreak,
    full_width_punct = nobreak,
    hyphen           = nobreak,
    non_starter      = nobreak,
    other            = nobreak,
}

local korean_5 = {
    jamo_initial     = stretch_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = stretch_break,
    half_width_close = nobreak_stretch,
    full_width_open  = stretch_break,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
    hyphen           = nobreak_stretch,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local injectors = { -- [previous] [current]
    jamo_final       = korean_1,
    korean           = korean_1,
    chinese          = korean_1,
    hiragana         = korean_1,
    katakana         = korean_1,
    hyphen           = korean_2,
    start            = korean_0,
    other            = korean_2,
    non_starter      = korean_3,
    full_width_open  = korean_4,
    half_width_open  = korean_4,
    full_width_close = korean_5,
    full_width_punct = korean_5,
    half_width_close = korean_5,
}

local function process(head,first,last)
    if first ~= last then
        local lastfont = nil
        local previous = "start"
        local last     = nil
        while true do
            local upcoming = getnext(first)
            local id       = getid(first)
            if id == glyph_code then
                local a       = getattr(first,a_scriptstatus)
                local current = numbertocategory[a]
                local action  = injectors[previous]
                if action then
                    action = action[current]
                    if action then
                        local font = getfont(first)
                        if font ~= lastfont then
                            lastfont = font
                            set_parameters(font,numbertodataset[getattr(first,a_scriptinjection)])
                        end
                        action(head,first)
                    end
                end
                previous = current
            else -- glue
                local p = getprev(first)
                local n = upcoming
                if p and n then
                    local pid = getid(p)
                    local nid = getid(n)
                    if pid == glyph_code and nid == glyph_code then
                        local pa = getattr(p,a_scriptstatus)
                        local na = getattr(n,a_scriptstatus)
                        local pcjk = pa and numbertocategory[pa]
                        local ncjk = na and numbertocategory[na]
                        if not pcjk                 or not ncjk
                            or pcjk == "korean"     or ncjk == "korean"
                            or pcjk == "other"      or ncjk == "other"
                            or pcjk == "jamo_final" or ncjk == "jamo_initial" then
                            previous = "start"
                        else -- if head ~= first then
                            remove_node(head,first,true)
                            previous = pcjk
                    --    else
                    --        previous = pcjk
                        end
                    else
                        previous = "start"
                    end
                else
                    previous = "start"
                end
            end
            if upcoming == last then -- was stop
                break
            else
                first = upcoming
            end
        end
    end
end

scripts.installmethod {
    name     = "hangul",
    injector = process,
    datasets = { -- todo: metatables
        default = {
            inter_char_shrink_factor          = 0.50, -- of quad
            inter_char_stretch_factor         = 0.50, -- of quad
            inter_char_half_shrink_factor     = 0.50, -- of quad
            inter_char_half_stretch_factor    = 0.50, -- of quad
            inter_char_quarter_shrink_factor  = 0.50, -- of quad
            inter_char_quarter_stretch_factor = 0.50, -- of quad
            inter_char_hangul_penalty         =   50,
        },
    },
}

function scripts.decomposehangul(head)
    local done = false
    for current, char in nextglyph, head do
        local lead_consonant, medial_vowel, tail_consonant = decomposed(char)
        if lead_consonant then
            setchar(current,lead_consonant)
            local m = copy_node(current)
            setchar(m,medial_vowel)
            head, current = insert_node_after(head,current,m)
            if tail_consonant then
                local t = copy_node(current)
                setchar(t,tail_consonant)
                head, current = insert_node_after(head,current,t)
            end
            done = true
        end
    end
    return head, done
end

-- nodes.tasks.prependaction("processors","normalizers","scripts.decomposehangul")

local otffeatures         = fonts.constructors.features.otf
local registerotffeature  = otffeatures.register

registerotffeature {
    name         = "decomposehangul",
    description  = "decompose hangul",
    processors = {
        position = 1,
        node     = scripts.decomposehangul,
    }
}

-- Chinese: hanzi

local chinese_0 = {
}

local chinese_1 = {
    jamo_initial     = korean_break,
    korean           = korean_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
--  hyphen           = nil,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local chinese_2 = {
    jamo_initial     = korean_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
    hyphen           = nobreak_stretch,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local chinese_3 = {
    jamo_initial     = korean_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
--  hyphen           = nil,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local chinese_4 = {
--  jamo_initial     = nil,
--  korean           = nil,
--  chinese          = nil,
--  hiragana         = nil,
--  katakana         = nil,
    half_width_open  = nobreak_autoshrink,
    half_width_close = nil,
    full_width_open  = nobreak_shrink,
    full_width_close = nobreak,
    full_width_punct = nobreak,
--  hyphen           = nil,
    non_starter      = nobreak,
--  other            = nil,
}

local chinese_5 = {
    jamo_initial     = stretch_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
--  hyphen           = nil,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local chinese_6 = {
    jamo_initial     = nobreak_stretch,
    korean           = nobreak_stretch,
    chinese          = nobreak_stretch,
    hiragana         = nobreak_stretch,
    katakana         = nobreak_stretch,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
    hyphen           = nobreak_stretch,
    non_starter      = nobreak_stretch,
    other            = nobreak_stretch,
}

local chinese_7 = {
    jami_initial     = nobreak_shrink_break_stretch,
    korean           = nobreak_shrink_break_stretch,
    chinese          = stretch_break, -- nobreak_shrink_break_stretch,
    hiragana         = stretch_break, -- nobreak_shrink_break_stretch,
    katakana         = stretch_break, -- nobreak_shrink_break_stretch,
    half_width_open  = nobreak_shrink_break_stretch_nobreak_autoshrink,
    half_width_close = nobreak_shrink_nobreak_stretch,
    full_width_open  = nobreak_shrink_break_stretch_nobreak_shrink,
    full_width_close = nobreak_shrink_nobreak_stretch,
    full_width_punct = nobreak_shrink_nobreak_stretch,
    hyphen           = nobreak_shrink_break_stretch,
    non_starter      = nobreak_shrink_break_stretch,
    other            = nobreak_shrink_break_stretch,
}

local chinese_8 = {
    jami_initial     = nobreak_shrink_break_stretch,
    korean           = nobreak_autoshrink_break_stretch,
    chinese          = stretch_break, -- nobreak_autoshrink_break_stretch,
    hiragana         = stretch_break, -- nobreak_autoshrink_break_stretch,
    katakana         = stretch_break, -- nobreak_autoshrink_break_stretch,
    half_width_open  = nobreak_autoshrink_break_stretch_nobreak_autoshrink,
    half_width_close = nobreak_autoshrink_nobreak_stretch,
    full_width_open  = nobreak_autoshrink_break_stretch_nobreak_shrink,
    full_width_close = nobreak_autoshrink_nobreak_stretch,
    full_width_punct = nobreak_autoshrink_nobreak_stretch,
    hyphen           = nobreak_autoshrink_break_stretch,
    non_starter      = nobreak_autoshrink_break_stretch,
    other            = nobreak_autoshrink_break_stretch,
}

local injectors = { -- [previous] [current]
    jamo_final       = chinese_1,
    korean           = chinese_1,
    chinese          = chinese_2,
    hiragana         = chinese_2,
    katakana         = chinese_2,
    hyphen           = chinese_3,
    start            = chinese_4,
    other            = chinese_5,
    non_starter      = chinese_5,
    full_width_open  = chinese_6,
    half_width_open  = chinese_6,
    full_width_close = chinese_7,
    full_width_punct = chinese_7,
    half_width_close = chinese_8,
}

local function process(head,first,last)
    if first ~= last then
        local lastfont = nil
        local previous = "start"
        local last     = nil
        while true do
            local upcoming = getnext(first)
            local id       = getid(first)
            if id == glyph_code then
                local a       = getattr(first,a_scriptstatus)
                local current = numbertocategory[a]
                local action  = injectors[previous]
                if action then
                    action = action[current]
                    if action then
                        local font = getfont(first)
                        if font ~= lastfont then
                            lastfont = font
                            set_parameters(font,numbertodataset[getattr(first,a_scriptinjection)])
                        end
                        action(head,first)
                    end
                end
                previous = current
            else -- glue
                local p = getprev(first)
                local n = upcoming
                if p and n then
                    local pid = getid(p)
                    local nid = getid(n)
                    if pid == glyph_code and nid == glyph_code then
                        local pa = getattr(p,a_scriptstatus)
                        local na = getattr(n,a_scriptstatus)
                        local pcjk = pa and numbertocategory[pa]
                        local ncjk = na and numbertocategory[na]
                        if not pcjk                       or not ncjk
                            or pcjk == "korean"           or ncjk == "korean"
                            or pcjk == "other"            or ncjk == "other"
                            or pcjk == "jamo_final"       or ncjk == "jamo_initial"
                            or pcjk == "half_width_close" or ncjk == "half_width_open" then -- extra compared to korean
                            previous = "start"
                        else -- if head ~= first then
                            remove_node(head,first,true)
                            previous = pcjk
                    --    else
                    --        previous = pcjk
                        end
                    else
                        previous = "start"
                    end
                else
                    previous = "start"
                end
            end
            if upcoming == last then -- was stop
                break
            else
                first = upcoming
            end
        end
    end
end

scripts.installmethod {
    name     = "hanzi",
    injector = process,
    datasets = {
        default = {
            inter_char_shrink_factor          = 0.50, -- of quad
            inter_char_stretch_factor         = 0.50, -- of quad
            inter_char_half_shrink_factor     = 0.50, -- of quad
            inter_char_half_stretch_factor    = 0.50, -- of quad
            inter_char_quarter_shrink_factor  = 0.50, -- of quad
            inter_char_quarter_stretch_factor = 0.50, -- of quad
            inter_char_hangul_penalty         =   50,
        },
    },
}

-- Japanese: idiographic, hiragana, katakana, romanji / jis

local japanese_0 = {
}

local japanese_1 = {
    jamo_initial     = korean_break,
    korean           = korean_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
--  hyphen           = nil,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local japanese_2 = {
    jamo_initial     = korean_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = japanese_before_full_width_punct, -- nobreak_stretch,
    hyphen           = nobreak_stretch,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local japanese_3 = {
    jamo_initial     = korean_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
--  hyphen           = nil,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local japanese_4 = {
--  jamo_initial     = nil,
--  korean           = nil,
--  chinese          = nil,
--  hiragana         = nil,
--  katakana         = nil,
    half_width_open  = nobreak_autoshrink,
    half_width_close = nil,
    full_width_open  = nobreak_shrink,
    full_width_close = nobreak,
    full_width_punct = nobreak,
--  hyphen           = nil,
    non_starter      = nobreak,
--  other            = nil,
}

local japanese_5 = {
    jamo_initial     = stretch_break,
    korean           = stretch_break,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
--  hyphen           = nil,
    non_starter      = nobreak_stretch,
    other            = stretch_break,
}

local japanese_6 = {
    jamo_initial     = nobreak_stretch,
    korean           = nobreak_stretch,
    chinese          = nobreak_stretch,
    hiragana         = nobreak_stretch,
    katakana         = nobreak_stretch,
    half_width_open  = nobreak_stretch_break_autoshrink,
    half_width_close = nobreak_stretch,
    full_width_open  = nobreak_stretch_break_shrink,
    full_width_close = nobreak_stretch,
    full_width_punct = nobreak_stretch,
    hyphen           = nobreak_stretch,
    non_starter      = nobreak_stretch,
    other            = nobreak_stretch,
}

local japanese_7 = {
    jami_initial     = nobreak_shrink_break_stretch,
    korean           = nobreak_shrink_break_stretch,
    chinese          = japanese_after_full_width_punct, -- stretch_break
    hiragana         = japanese_after_full_width_punct, -- stretch_break
    katakana         = japanese_after_full_width_punct, -- stretch_break
    half_width_open  = nobreak_shrink_break_stretch_nobreak_autoshrink,
    half_width_close = nobreak_shrink_nobreak_stretch,
    full_width_open  = japanese_between_full_close_open, -- !!
    full_width_close = japanese_between_full_close_full_close, -- nobreak_shrink_nobreak_stretch,
    full_width_punct = nobreak_shrink_nobreak_stretch,
    hyphen           = nobreak_shrink_break_stretch,
    non_starter      = nobreak_shrink_break_stretch,
    other            = nobreak_shrink_break_stretch,
}

local japanese_8 = {
    jami_initial     = nobreak_shrink_break_stretch,
    korean           = nobreak_autoshrink_break_stretch,
    chinese          = stretch_break,
    hiragana         = stretch_break,
    katakana         = stretch_break,
    half_width_open  = nobreak_autoshrink_break_stretch_nobreak_autoshrink,
    half_width_close = nobreak_autoshrink_nobreak_stretch,
    full_width_open  = nobreak_autoshrink_break_stretch_nobreak_shrink,
    full_width_close = nobreak_autoshrink_nobreak_stretch,
    full_width_punct = nobreak_autoshrink_nobreak_stretch,
    hyphen           = nobreak_autoshrink_break_stretch,
    non_starter      = nobreak_autoshrink_break_stretch,
    other            = nobreak_autoshrink_break_stretch,
}

local injectors = { -- [previous] [current]
    jamo_final       = japanese_1,
    korean           = japanese_1,
    chinese          = japanese_2,
    hiragana         = japanese_2,
    katakana         = japanese_2,
    hyphen           = japanese_3,
    start            = japanese_4,
    other            = japanese_5,
    non_starter      = japanese_5,
    full_width_open  = japanese_6,
    half_width_open  = japanese_6,
    full_width_close = japanese_7,
    full_width_punct = japanese_7,
    half_width_close = japanese_8,
}

local function process(head,first,last)
    if first ~= last then
        local lastfont = nil
        local previous = "start"
        local last     = nil
        while true do
            local upcoming = getnext(first)
            local id       = getid(first)
            if id == glyph_code then
                local a       = getattr(first,a_scriptstatus)
                local current = numbertocategory[a]
                local action  = injectors[previous]
                if action then
                    action = action[current]
                    if action then
                        local font = getfont(first)
                        if font ~= lastfont then
                            lastfont = font
                            set_parameters(font,numbertodataset[getattr(first,a_scriptinjection)])
                        end
                        action(head,first)
                    end
                end
                previous = current
         -- elseif id == math_code then
         --     upcoming = getnext(end_of_math(current))
         --     previous = "start"
            else -- glue
                local p = getprev(first)
                local n = upcoming
                if p and n then
                    local pid = getid(p)
                    local nid = getid(n)
                    if pid == glyph_code and nid == glyph_code then
                        local pa = getattr(p,a_scriptstatus)
                        local na = getattr(n,a_scriptstatus)
                        local pcjk = pa and numbertocategory[pa]
                        local ncjk = na and numbertocategory[na]
                        if not pcjk                       or not ncjk
                            or pcjk == "korean"           or ncjk == "korean"
                            or pcjk == "other"            or ncjk == "other"
                            or pcjk == "jamo_final"       or ncjk == "jamo_initial"
                            or pcjk == "half_width_close" or ncjk == "half_width_open" then -- extra compared to korean
                            previous = "start"
                        else -- if head ~= first then
                            if id == glue_code then
                                -- also scriptstatus check?
                                local subtype = getsubtype(first)
                                if subtype == userskip_code or subtype == spaceskip_code or subtype == xspaceskip_code then
                                    -- for the moment no distinction possible between space and userskip
                                    local w = getwidth(first)
                                    local s = spacedata[getfont(p)]
                                    if w == s then -- could be option
                                        if trace_details then
                                            trace_detail_between(p,n,"space removed")
                                        end
                                        remove_node(head,first,true)
                                    end
                                end
                            end
                            previous = pcjk
                    --    else
                    --        previous = pcjk
                        end
                    else
                        previous = "start"
                    end
                else
                    previous = "start"
                end
            end
            if upcoming == last then -- was stop
                break
            else
                first = upcoming
            end
        end
    end
end

scripts.installmethod {
    name     = "nihongo", -- what name to use?
    injector = process,
    datasets = {
        default = {
            inter_char_shrink_factor          = 0.50, -- of quad
            inter_char_stretch_factor         = 0.50, -- of quad
            inter_char_half_shrink_factor     = 0.50, -- of quad
            inter_char_half_stretch_factor    = 0.50, -- of quad
            inter_char_quarter_shrink_factor  = 0.25, -- of quad
            inter_char_quarter_stretch_factor = 0.25, -- of quad
            inter_char_hangul_penalty         =   50,
        },
    },
}
