if not modules then modules = { } end modules ['buff-imp-nested'] = {
    version   = 1.001,
    comment   = "companion to buff-imp-nested.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lpegmatch, patterns = lpeg.match, lpeg.patterns
local P, V, Carg = lpeg.P, lpeg.V, lpeg.Carg

local context       = context
local verbatim      = context.verbatim
local variables     = interfaces.variables

local makepattern   = visualizers.makepattern
local getvisualizer = visualizers.getvisualizer

local nested = nil

local donestedtypingstart = context.donestedtypingstart
local donestedtypingstop  = context.donestedtypingstop

local v_none    = variables.none
local v_slanted = variables.slanted

local handler = visualizers.newhandler {
    initialize = function(settings)
        local option = settings and settings.option
        if not option or option == "" then
            nested = nil
        elseif option == v_slanted then
            nested = nil
        elseif option == v_none then
            nested = nil
        else
            nested = getvisualizer(option,"direct")
        end
    end,
    open = function()
        donestedtypingstart()
    end,
    close = function()
        donestedtypingstop()
    end,
    content = function(s)
        if nested then
            nested(s)
        else
            verbatim(s)
        end
    end,
}

local open  = P("<<")
local close = P(">>")
local rest  = (1 - open - close - patterns.space - patterns.newline)^1

local grammar = visualizers.newgrammar("default", {

    initialize = patterns.beginofstring * Carg(1) / handler.initialize,

    open       = makepattern(handler,"open",open),
    close      = makepattern(handler,"close",close),
    rest       = makepattern(handler,"content",rest),

    nested     = V("open") * (V("pattern")^0) * V("close"),
    pattern    = V("line") + V("space") + V("nested") + V("rest"),

    visualizer = V("initialize") * (V("pattern")^1)

} )

local parser = P(grammar)

visualizers.register("nested", { parser = parser, handler = handler, grammar = grammar } )

-- lpeg.match(parser,[[<<tf<<sl>>tf<<sl>>tf>>]]) context.par()
-- lpeg.match(parser,[[<<tf<<sl<<tf>>sl>>tf>>]]) context.par()
-- lpeg.match(parser,[[sl<<tf<<sl>>tf>>sl]])     context.par()
