if not modules then modules = { } end modules ['strc-mat'] = {
    version   = 1.001,
    comment   = "companion to strc-mat.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

----- copytable  = table.copy

local structures = structures

local lists      = structures.lists
local sections   = structures.sections
local floats     = structures.floats
local helpers    = structures.helpers
local formulas   = structures.formulas -- not used but reserved

----- context    = context
----- simplify   = helpers.simplify

-- maybe we want to do clever things with formulas, the store might go away

-- local formuladata = { }
--
-- function formulas.store(data)
--     formuladata[#formuladata+1] = data
--     context(#formuladata)
-- end
--
-- function formulas.current()
--     return formuladata[#formuladata]
-- end

-- function formulas.simplify(entry)
--     return simplify(copytable(entry or formuladata[#formuladata]))
-- end

function helpers.formulanumber(data,spec)
    if data then
        local formulanumber = data.formulanumber
        if formulanumber then
            sections.number(data,spec,"formulanumber","formulanumber",'number')
        end
    end
end

function lists.formulanumber(name,n,spec)
    local result = lists.result
    if result then
        helpers.formulanumber(result[n])
    end
end
