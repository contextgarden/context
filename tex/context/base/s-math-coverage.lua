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

moduledata.math            = moduledata.math          or { }
moduledata.math.coverage   = moduledata.math.coverage or { }

local context              = context

local ctx_NC               = context.NC
local ctx_NR               = context.NR
local ctx_HL               = context.HL

local ctx_rawmathematics   = context.formatted.rawmathematics
local ctx_mathematics      = context.formatted.mathematics
local ctx_startimath       = context.startimath
local ctx_stopimath        = context.stopimath
local ctx_setmathattribute = context.setmathattribute
local ctx_underbar         = context.underbar
local ctx_getglyph         = context.getglyph

local styles               = mathematics.styles
local alternatives         = mathematics.alternatives
local charactersets        = mathematics.charactersets

local getboth              = mathematics.getboth
local remapalphabets       = mathematics.remapalphabets

local chardata             = characters.data
local superscripts         = characters.superscripts
local subscripts           = characters.subscripts

context.writestatus("math coverage","underline: not remapped")

function moduledata.math.coverage.showalphabets()
    context.starttabulate { "|lT|l|Tl|" }
    for i=1,#styles do
        local style = styles[i]
        for i=1,#alternatives do
            local alternative = alternatives[i]
            for i=1,#charactersets do
                local alphabet = charactersets[i]
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
    context.stoptabulate()
end

function moduledata.math.coverage.showcharacters()
    context.startmixedcolumns()
    context.setupalign { "nothyphenated" }
    context.starttabulate { "|T|i2|Tpl|" }
    for u, d in table.sortedhash(chardata) do
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
    context.stoptabulate()
    context.stopmixedcolumns()
end

-- This is a somewhat tricky table as we need to bypass the math machinery.

function moduledata.math.coverage.showscripts()
    context.starttabulate { "|cT|c|cT|c|c|c|l|" }
    for k, v in table.sortedhash(table.merged(superscripts,subscripts)) do
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
    context.stoptabulate()
end

-- Handy too.

function moduledata.math.coverage.showbold()
    context.starttabulate { "|lT|cm|lT|cm|lT|" }
    for k, v in table.sortedhash(mathematics.boldmap) do
        ctx_NC() context("%U",k)
        ctx_NC() context("%c",k)
        ctx_NC() context("%U",v)
        ctx_NC() context("%c",v)
        ctx_NC() context(chardata[k].description)
        ctx_NC() ctx_NR()
    end
    context.stoptabulate()
end
