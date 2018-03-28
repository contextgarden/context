if not modules then modules = { } end modules ['scrn-but'] = {
    version   = 1.001,
    comment   = "companion to scrn-but.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local context     = context
local f_two_colon = string.formatters["%s:%s:%s"]
local v_section   = interfaces.variables.section

local function registerbuttons(tag,register,language)
    local data = sorters.definitions[language]
    local orders = data and data.orders or sorters.definitions.default.orders
    for i=1,#orders do
        local order = orders[i]
        context.doregistermenubutton(tag, order, f_two_colon(register,v_section,order) )
    end
end

interfaces.implement {
    name      = "registerbuttons",
    actions   = registerbuttons,
    arguments = "3 strings",
}
