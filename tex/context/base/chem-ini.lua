if not modules then modules = { } end modules ['chem-ini'] = {
    version   = 1.001,
    comment   = "companion to chem-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local lpegmatch, patterns = lpeg.match, lpeg.patterns

local trace_molecules = false  trackers.register("chemistry.molecules",  function(v) trace_molecules = v end)

local report_chemistry = logs.reporter("chemistry")

local context   = context
local cpatterns = patterns.context

chemistry       = chemistry or { }
local chemistry = chemistry

--[[
<p>The next code started out as adaptation of code from Wolfgang Schuster as
posted on the mailing list. The current version supports nested braces and
unbraced integers as scripts.</p>
]]--

local moleculeparser     = cpatterns.scripted
chemistry.moleculeparser = moleculeparser

function chemistry.molecule(str)
    return lpegmatch(moleculeparser,str)
end

interfaces.implement {
    name      = "molecule",
    arguments = "string",
    actions   = function(str)
        if trace_molecules then
            local rep = lpegmatch(moleculeparser,str)
            report_chemistry("molecule %a becomes %a",str,rep)
            context(rep)
        else
            context(lpegmatch(moleculeparser,str))
        end
    end,
}

-- interfaces.implement {
--     name      = "molecule",
--     scope     = "private",
--     action    = function()
--         local str = scanstring()
--         if trace_molecules then
--             local rep = lpegmatch(moleculeparser,str)
--             report_chemistry("molecule %a becomes %a",str,rep)
--             context(rep)
--         else
--             context(lpegmatch(moleculeparser,str))
--         end
--     end,
-- }
