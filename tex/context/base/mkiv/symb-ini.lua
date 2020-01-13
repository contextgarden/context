if not modules then modules = { } end modules ['symb-ini'] = {
    version   = 1.001,
    comment   = "companion to symb-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local context        = context
local variables      = interfaces.variables

fonts                = fonts or { } -- brrrr

local symbols        = fonts.symbols or { }
fonts.symbols        = symbols

local listitem       = utilities.parsers.listitem
local uselibrary     = resolvers.uselibrary

local report_symbols = logs.reporter ("fonts","symbols")
local status_symbols = logs.messenger("fonts","symbols")

local patterns = {
    CONTEXTLMTXMODE > 0 and "symb-imp-%s.mkxl" or "",
    "symb-imp-%s.mkiv",
    "symb-imp-%s.tex",
    -- obsolete:
    "symb-%s.mkiv",
    "symb-%s.tex"
}

local function action(name,foundname)
    commands.loadlibrary(name,foundname,false)
    status_symbols("library %a loaded",name)
end

local function failure(name)
    report_symbols("library %a is unknown",name)
end

function symbols.uselibrary(name)
    if name ~= variables.reset then
        for name in listitem(name) do
            uselibrary {
                name     = name,
                patterns = patterns,
                action   = action,
                failure  = failure,
                onlyonce = true,
            }
        end
    end
end

interfaces.implement {
    name      = "usesymbols",
    actions   = symbols.uselibrary,
    arguments = "string",
}
