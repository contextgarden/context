if not modules then modules = { } end modules ['font-imp-reorder'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then return end

local next = next
local find = string.find
local sortedhash, sortedkeys, sort = table.sortedhash, table.sortedkeys, table.sort

local fonts              = fonts
local otf                = fonts.handlers.otf
local registerotffeature = otf.features.register

-- This is a rather special test-only feature that I added for the sake of testing
-- Idris's husayni. We wanted to know if uniscribe obeys the order of lookups in a
-- font, in spite of what the description of handling arabic suggests. And indeed,
-- mixed-in lookups of other features (like all these ss* in husayni) are handled
-- the same in context as in uniscribe. If one sets reorderlookups=arab then we sort
-- according to the "assumed" order so e.g. the ss* move to after the standard
-- features. The observed difference in rendering is an indication that uniscribe is
-- quite faithful to the font (while e.g. tests with the hb plugin demonstrate some
-- interference, apart from some hard coded init etc expectations). Anyway, it means
-- that we're okay with the (generic) node processor. A pitfall is that in context
-- we can actually control more, so we can trigger an analyze pass with e.g.
-- dflt/dflt while the libraries depend on the script settings for that. Uniscribe
-- probably also parses the string and when seeing arabic will follow a different
-- code path, although it seems to treat all features equal.

local trace_reorder  = trackers.register("fonts.reorderlookups",function(v) trace_reorder = v end)
local report_reorder = logs.reporter("fonts","reorder")

local vectors = { }

vectors.arab = {
    gsub = {
        ccmp =  1,
        isol =  2,
        fina =  3,
        medi =  4,
        init =  5,
        rlig =  6,
        rclt =  7,
        calt =  8,
        liga =  9,
        dlig = 10,
        cswh = 11,
        mset = 12,
    },
    gpos = {
        curs =  1,
        kern =  2,
        mark =  3,
        mkmk =  4,
    },
}

local function compare(a,b)
    local what_a = a.what
    local what_b = b.what
    if what_a ~= what_b then
        return a.index < b.index
    end
    local when_a = a.when
    local when_b = b.when
    if when_a == when_b then
        return a.index < b.index
    else
        return when_a < when_b
    end
end

function otf.reorderlookups(tfmdata,vector)
    local order = vectors[vector]
    if not order then
        return
    end
    local oldsequences = tfmdata.resources.sequences
    if oldsequences then
        local sequences = { }
        for i=1,#oldsequences do
            sequences[i] = oldsequences[i]
        end
        for i=1,#sequences do
            local s = sequences[i]
            local features = s.features
            local kind     = s.type
            local index    = s.index
            if features then
                local when
                local what
                for feature in sortedhash(features) do
                    if not what then
                        what = find(kind,"^gsub") and "gsub" or "gpos"
                    end
                    local newwhen = order[what][feature]
                    if not newwhen then
                        -- skip
                    elseif not when then
                        when = newwhen
                    elseif newwhen < when then
                        when = newwhen
                    end
                end
                s.ondex = s.index
                s.index = i
                s.what  = what == "gsub" and 1 or 2
                s.when  = when or 99
            else
                s.ondex = s.index
                s.index = i
                s.what  = 1
                s.when  = 99
            end
        end
        sort(sequences,compare)
        local swapped = 0
        for i=1,#sequences do
            local sequence = sequences[i]
            local features = sequence.features
            if features then
                local index = sequence.index
                if index ~= i then
                    swapped = swapped + 1
                end
                if trace_reorder then
                    if swapped == 1 then
                        report_reorder()
                        report_reorder("start swapping lookups in font %!font:name!",tfmdata)
                        report_reorder()
                        report_reorder("gsub order: % t",table.swapped(order.gsub))
                        report_reorder("gpos order: % t",table.swapped(order.gpos))
                        report_reorder()
                    end
                    report_reorder("%03i : lookup %03i, type %s, sorted %2i, moved %s, % t",
                        i,index,sequence.what == 1 and "gsub" or "gpos",sequence.when or 99,
                        (index > i and "-") or (index < i and "+") or "=",sortedkeys(features))
                end
            end
            sequence.what  = nil
            sequence.when  = nil
            sequence.index = sequence.ondex
        end
        if swapped > 0 then
            if trace_reorder then
                report_reorder()
                report_reorder("stop swapping lookups, %i lookups swapped",swapped)
                report_reorder()
            end
            tfmdata.shared.reorderedsequences = sequences
        end
    end
end

-- maybe delay till ra is filled

local function initialize(tfmdata,key,value)
    if value then
        otf.reorderlookups(tfmdata,value)
    end
end

registerotffeature {
    name        = "reorderlookups",
    description = "reorder lookups",
    manipulators = {
        base = initialize,
        node = initialize,
    }
}
