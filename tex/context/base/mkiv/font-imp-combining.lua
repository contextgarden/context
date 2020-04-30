if not modules then modules = { } end modules ['font-imp-combining'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA ADE",
    copyright = "ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then return end

local next, unpack = next, unpack
local sort, copy, insert = table.sort, table.copy, table.insert
local setmetatableindex = table.setmetatableindex

local fontdata  = fonts.hashes.identifiers
local otf       = fonts.handlers.otf

local nuts      = nodes.nuts

local nextnode  = nuts.traversers.node
local ischar    = nuts.ischar
local getprev   = nuts.getprev
local getnext   = nuts.getnext
local setprev   = nuts.setprev
local setnext   = nuts.setnext
local setboth   = nuts.setboth
local setlink   = nuts.setlink
local exchange  = nuts.exchange

local class     = { } -- reused
local point     = { } -- reused
local classes   = { }
local sorters   = { }
local slide     = { }
local count     = 0

-- List provided by Joey McCollum (Hebrew Layout Intelligence):
--
-- 1. The consonants (Unicode points 05D0-05EA) have no combining class and are never reordered; this is typographically correct.
-- 2. Shin dot and sin dot (05C1-05C2) should be next, but Unicode places them in combining classes 24 and 25, after the characters in recommended classes 3-5 and many of the characters in recommended class 6.
-- 3. Dagesh / mapiq (05BC) should be next, but Unicode assigns it a combining class of 21. This means that it will be incorrectly ordered before characters in recommended class 2 and after characters in recommended classes 4-6 after Unicode normalization.
-- 4. Rafe (05BF) should be next, but Unicode assigns it a combining class of 23. Thus, it will be correctly placed after characters in recommended class 3, but incorrectly placed before characters in recommended class 2 after Unicode normalization.
-- 5. The holam and holam haser vowel points (05B9-05BA) should be next, but Unicode places them in combining class 19. This means that it will be placed incorrectly before characters in recommended classes 2-4 and after all characters in recommended class 6 except 05BB after Unicode normalization.
-- 6. The characters in 0591, 0596, 059B, 05A2-05A7, 05AA, 05B0-05B8, 05BB, 05BD, 05C5, 05C7 should be treated as being in the same class, but Unicode places them in combining classes 10-18, 20, 22, and 220.
-- 7. The prepositive marks yetiv and dehi (059A, 05AD) should be next; Unicode places them in combining class 222, so they should correctly come after all characters in recommended classes 1-6.
-- 8. The characters 0307, 0593-0595, 0597-0598, 059C-05A1, 05A8, 05AB-05AC, 05AF, 05C4 should be treated as being in the same class; Unicode places them in combining class 230, so they should correctly come after all characters in recommended classes 1-7.
-- 9. The postpositive marks segolta, pashta, telisha qetana, and zinor (0592, 0599, 05A9, 05AE) should be next; Unicode places them in combining class 230, so they will need to be reordered after the characters in recommended class 8.
--
-- Some tests by Joey:
--
-- Arial, Calibri, and Times New Roman will correctly typeset most combinations of points even in Unicode's canonical order, but they typeset the normalized sequences (hiriq, shin dot, tipeha) and (qamatz, dagesh, shin dot) incorrectly and their typographically recommended reorderings correctly.
-- Cardo will correctly typeset most combinations of points even in Unicode's canonical order, but it typesets the normalized sequences (hiriq, shin dot, tipeha) incorrectly and its typographically recommended reorderings correctly.
-- Frank Ruehl CLM typesets most combinations of points even in Unicode's canonical order, but it consistently does a poor job positioning cantillation marks even when they are placed in the typographically recommended position. Taamey Frank CLM is another version of the same font that handles this correctly, so it is possible that  Frank Ruehl CLM is just an obsolete font that did not have well-implemented Hebrew font features for cantillation marks to begin with.
-- For Linux Libertine, the text samples with both the normalized mark ordering and the typographically recommended mark ordering were typeset poorly. I think that this is just because that font does not have full support for the Hebrew glyph set (it lacks cantillation marks) or Hebrew font features (it does not place Hebrew diacritical marks intelligently), so no mark reordering would fix its problems.
-- Taamey David CLM and Taamey Frank CLM exhibits the same typographical mistakes as SBL Hebrew when the input is in Unicode canonical order, and these mistakes go away if the marks are ordered in the typographically recommended way.
--
-- SBL Hebrew is used as reference font.

classes.hebr = {
    [0x05C1] = 1, [0x05C2] = 1,
    [0x05BC] = 2,
    [0x05BF] = 3,
    [0x05B9] = 4, [0x05BA] = 4,
    [0x0591] = 5, [0x0596] = 5, [0x059B] = 5, [0x05A2] = 5, [0x05A3] = 5, [0x05A4] = 5,
    [0x05A5] = 5, [0x05A6] = 5, [0x05A7] = 5, [0x05AA] = 5, [0x05B0] = 5, [0x05B1] = 5,
    [0x05B2] = 5, [0x05B3] = 5, [0x05B4] = 5, [0x05B5] = 5, [0x05B6] = 5, [0x05B7] = 5,
    [0x05B8] = 5, [0x05BB] = 5, [0x05BD] = 5, [0x05C5] = 5, [0x05C7] = 5,
    [0x059A] = 6, [0x05AD] = 6,
    [0x0307] = 7, [0x0593] = 7, [0x0594] = 7, [0x0595] = 7, [0x0597] = 7, [0x0598] = 7,
    [0x059C] = 7, [0x059D] = 7, [0x059E] = 7, [0x059F] = 7, [0x05A0] = 7, [0x05A1] = 7,
    [0x05A8] = 7, [0x05AB] = 7, [0x05AC] = 7, [0x05AF] = 7, [0x05C4] = 7,
    [0x0592] = 8, [0x0599] = 8, [0x05A9] = 8, [0x05AE] = 8,
}

sorters.hebr = function(a,b)
    return class[a] < class[b]
end

-- local dflt = setmetatableindex(function(t,k,v)
--     for k, v in next, characters.data do
--         local c = v.combining
--         if c then
--             t[k] = c
--         end
--     end
--     setmetatableindex(t,nil)
--     return t[k]
-- end)
--
-- classes.dflt = dflt
-- sorters.dflt = function(a,b) return class[b] < class[a] end

-- see analyzeprocessor in case we want scripts

local function reorder(head)
    if count == 2 then
        local first = slide[1]
        local last  = slide[2]
        if sorter(last,first) then
            head = exchange(head,first,last)
        end
    elseif count > 1 then
        local first  = slide[1]
        local last   = slide[count]
        local before = getprev(first)
        local after  = getnext(last)
        setprev(first)
        setnext(last)
        sort(slide,sorter)
        setlink(unpack(slide))
        local first = slide[1]
        local last  = slide[count]
        if before then
            setlink(before,first)
        end
        setlink(last,after)
        if first == head then
            head = first
        end
    end
    count = 0
    return head
end

local function reorderprocessor(head,font,attr)
    local tfmdata = fontdata[font]
    local script  = otf.scriptandlanguage(tfmdata,attr)
    sorter  = sorters[script]
    if sorter then
        local classes = classes[script]
        for n in nextnode, head do
            local char, id = ischar(n,font)
            if char then
                local c = classes[char]
                if c then
                    if count == 0 then
                        count = 1
                        slide = { n }
                    else
                        count = count + 1
                        slide[count] = n
                    end
                    class[n] = c
                    point[n] = char
                elseif count > 0 then
                    head = reorder(head)
                end
            elseif count > 0 then
                head = reorder(head)
            end
        end
        if count > 0 then
            head = reorder(head)
        end
    end
    return head
end

fonts.constructors.features.otf.register {
    name         = "reordercombining",
    description  = "reorder combining characters",
--  default      = true,
--  initializers = {
--      node     = reorderinitializer,
--  },
    processors = {
        position = 1,
        node     = reorderprocessor,
    }
}
