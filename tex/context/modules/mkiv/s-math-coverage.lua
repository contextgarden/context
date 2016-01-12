if not modules then modules = { } end modules ['s-math-coverage'] = {
    version   = 1.001,
    comment   = "companion to s-math-coverage.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utfchar, utfbyte = utf.char, utf.byte
local formatters, lower = string.formatters, string.lower
local concat = table.concat
local sortedhash = table.sortedhash

moduledata.math             = moduledata.math          or { }
moduledata.math.coverage    = moduledata.math.coverage or { }

local context               = context

local ctx_NC                = context.NC
local ctx_NR                = context.NR
local ctx_HL                = context.HL

local ctx_startmixedcolumns = context.startmixedcolumns
local ctx_stopmixedcolumns  = context.stopmixedcolumns
local ctx_setupalign        = context.setupalign
local ctx_starttabulate     = context.starttabulate
local ctx_stoptabulate      = context.stoptabulate
local ctx_rawmathematics    = context.formatted.rawmathematics
local ctx_mathematics       = context.formatted.mathematics
local ctx_startimath        = context.startimath
local ctx_stopimath         = context.stopimath
local ctx_setmathattribute  = context.setmathattribute
local ctx_underbar          = context.underbar
local ctx_getglyph          = context.getglyph

local styles                = mathematics.styles
local alternatives          = mathematics.alternatives
local charactersets         = mathematics.charactersets

local getboth               = mathematics.getboth
local remapalphabets        = mathematics.remapalphabets

local chardata              = characters.data
local superscripts          = characters.superscripts
local subscripts            = characters.subscripts

context.writestatus("math coverage","underline: not remapped")

function moduledata.math.coverage.showalphabets()
    ctx_starttabulate { "|lT|l|Tl|" }
    for i=1,#styles do
        local style = styles[i]
        for i=1,#alternatives do
            local alternative = alternatives[i]
            for _, alphabet in sortedhash(charactersets) do
                ctx_NC()
                    if i == 1 then
                        context("%s %s",style,alternative)
                    end
                ctx_NC()
                    ctx_startimath()
                    ctx_setmathattribute(style,alternative)
                    for i=1,#alphabet do
                        local letter = alphabet[i]
                        local id = getboth(style,alternative)
                        local unicode = remapalphabets(letter,id)
                        if not unicode then
                            ctx_underbar(utfchar(letter))
                        elseif unicode == letter then
                            context(utfchar(unicode))
                        else
                            context(utfchar(unicode))
                        end
                    end
                    ctx_stopimath()
                ctx_NC()
                    local first = alphabet[1]
                    local last = alphabet[#alphabet]
                    local id = getboth(style,alternative)
                    local f_unicode = remapalphabets(first,id) or utfbyte(first)
                    local l_unicode = remapalphabets(last,id) or utfbyte(last)
                    context("%05X - %05X",f_unicode,l_unicode)
                ctx_NC()
                ctx_NR()
            end
        end
    end
    ctx_stoptabulate()
end

function moduledata.math.coverage.showcharacters()
    ctx_startmixedcolumns { balance = "yes" }
    ctx_setupalign { "nothyphenated" }
    ctx_starttabulate { "|T|i2|Tpl|" }
    for u, d in sortedhash(chardata) do
        local mathclass = d.mathclass
        local mathspec = d.mathspec
        if mathclass or mathspec then
            ctx_NC()
                context("%05X",u)
            ctx_NC()
                ctx_getglyph("MathRoman",u)
            ctx_NC()
                if mathspec then
                    local t = { }
                    for i=1,#mathspec do
                        t[mathspec[i].class] = true
                    end
                    t = table.sortedkeys(t)
                    context("% t",t)
                else
                    context(mathclass)
                end
            ctx_NC()
            ctx_NR()
        end
    end
    ctx_stoptabulate()
    ctx_stopmixedcolumns()
end

-- This is a somewhat tricky table as we need to bypass the math machinery.

function moduledata.math.coverage.showscripts()
    ctx_starttabulate { "|cT|c|cT|c|c|c|l|" }
    for k, v in sortedhash(table.merged(superscripts,subscripts)) do
        local ck = utfchar(k)
        local cv = utfchar(v)
        local ss = superscripts[k] and "^" or "_"
        ctx_NC() context("%05X",k)
        ctx_NC() context(ck)
        ctx_NC() context("%05X",v)
        ctx_NC() context(cv)
        ctx_NC() ctx_rawmathematics("x%s = x%s%s",ck,ss,cv)
        ctx_NC() ctx_mathematics("x%s = x%s%s",ck,ss,cv)
        ctx_NC() context(lower(chardata[k].description))
        ctx_NC() ctx_NR()
    end
    ctx_stoptabulate()
end

-- Handy too.

function moduledata.math.coverage.showbold()
    ctx_starttabulate { "|lT|cm|lT|cm|lT|" }
    for k, v in sortedhash(mathematics.boldmap) do
        ctx_NC() context("%U",k)
        ctx_NC() context("%c",k)
        ctx_NC() context("%U",v)
        ctx_NC() context("%c",v)
        ctx_NC() context(chardata[k].description)
        ctx_NC() ctx_NR()
    end
    ctx_stoptabulate()
end

-- function moduledata.math.coverage.showentities()
--     ctx_startmixedcolumns { balance = "yes" }
--     ctx_starttabulate { "|Tl|c|Tl|" }
--     for k, v in sortedhash(characters.entities) do
--         local b = utf.byte(v)
--         local d = chardata[b]
--         local m = d.mathname
--         local c = d.contextname
--         local s = ((m and "\\"..m) or (c and "\\".. c) or v) .. "{}{}{}"
--         ctx_NC()
--         context("%U",b)
--         ctx_NC()
--         ctx_mathematics(s)
--         ctx_NC()
--         context(k)
--         ctx_NC()
--         ctx_NR()
--     end
--     ctx_stoptabulate()
--     ctx_stopmixedcolumns()
-- end

function moduledata.math.coverage.showentities()
    ctx_startmixedcolumns { balance = "yes" }
    ctx_starttabulate { "|T||T|T|" }
    for k, v in sortedhash(characters.entities) do
        local d = chardata[v]
        if d then
            local m = d.mathclass or d.mathspec
            local u = d.unicodeslot
            ctx_NC() context(m and "m" or "t")
            ctx_NC() ctx_getglyph("MathRoman",u)
            ctx_NC() context("%05X",u)
            ctx_NC() context(k)
            ctx_NC() ctx_NR()
        end
    end
    ctx_stoptabulate()
    ctx_stopmixedcolumns()
end

