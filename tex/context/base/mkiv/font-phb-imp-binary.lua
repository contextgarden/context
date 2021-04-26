if not modules then modules = { } end modules ['font-phb-imp-binary'] = {
    version   = 1.000, -- 2016.10.10,
    comment   = "companion to font-txt.mkiv",
    author    = "Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- The hb library comes in versions and the one I tested in 2016 was part of the inkscape
-- suite. In principle one can have incompatibilities due to updates but that is the nature
-- of a library. When a library ie expected one has better use the system version, if only
-- to make sure that different programs behave the same.
--
-- The main reason for testing this approach was that when Idris was working on his fonts,
-- we wanted to know how different shapers deal with it and the hb command line program
-- could provide uniscribe output. For the context shaper uniscribe is the reference, also
-- because Idris started out with Volt a decade ago.
--
-- This file uses the indirect approach by calling the executable. This file uses context
-- features and is not generic.

local next, tonumber, pcall = next, tonumber, pcall

local concat      = table.concat
local reverse     = table.reverse
local formatters  = string.formatters
local removefile  = os.remove
local resultof    = os.resultof
local savedata    = io.savedata

local report      = utilities.hb.report or print
local packtoutf8  = utilities.hb.helpers.packtoutf8

if not context then
    report("the binary runner is only supported in context")
    return
end

-- output : [index=cluster@x_offset,y_offset+x_advance,y_advance|...]
-- result : { index, cluster, x_offset, y_offset, x_advance, y_advance }

local P, Ct, Cc = lpeg.P, lpeg.Ct, lpeg.Cc
local lpegmatch = lpeg.match

local zero      = Cc(0)
local number    = lpeg.patterns.integer / tonumber + zero
local index     = lpeg.patterns.cardinal / tonumber
local cluster   = index
local offset    = (P("@") * number * (P(",") * number + zero)) + zero * zero
local advance   = (P("+") * number * (P(",") * number + zero)) + zero * zero
local glyph     = Ct(index * P("=") * cluster * offset * advance)
local pattern   = Ct(P("[") * (glyph * P("|")^-1)^0 * P("]"))

local shapers = {
    native    = "ot,uniscribe,fallback",
    uniscribe = "uniscribe,ot,fallback",
    fallback  = "fallback"
}

local runner = sandbox.registerrunner {
    method     = "resultof",
    name       = "harfbuzz",
 -- program    = {
 --     windows = "hb-shape.exe",
 --     unix    = "hb-shape"
 -- },
    program    = "hb-shape",
    checkers   = {
        shaper    = "string",
        features  = "string",
        script    = "string",
        language  = "string",
        direction = "string",
        textfile  = "writable",
        fontfile  = "readable",
    },
    template   = string.longtostring [[
        --shaper=%shaper%
        --output-format=text
        --no-glyph-names
        --features="%features%"
        --script=%script%
        --language=%language%
        --direction=%direction%
        --text-file=%textfile%
        --font-file=%fontfile%
    ]],
}

local tempfile = "font-phb.tmp"
local reported = false

function utilities.hb.methods.binary(font,data,rlmode,text,leading,trailing)
    if runner then
        savedata(tempfile,packtoutf8(text,leading,trailing))
        local result  = runner {
            shaper    = shapers[data.shaper] or shapers.native,
            features  = data.features,
            script    = data.script or "dflt",
            language  = data.language or "dflt",
            direction = rlmode < 0 and "rtl" or "ltr",
            textfile  = tempfile,
            fontfile  = data.filename,
        }
        removefile(tempfile)
        if result then
         -- return jsontolua(result)
            result = lpegmatch(pattern,result) -- { index cluster xo yo xa ya }
            if rlmode < 0 then
                return reverse(result) -- we can avoid this
            else
                return result
            end
        end
    elseif reported then
        report("no runner available")
        reported = true
    end
end
