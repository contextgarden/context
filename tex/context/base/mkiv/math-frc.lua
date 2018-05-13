if not modules then modules = { } end modules ['math-frc'] = {
    version   = 1.001,
    comment   = "companion to math-frc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utfchar   = utf.char

local context   = context
local variables = interfaces.variables

local v_no      = variables.no
local v_yes     = variables.yes

local resolved  = {
    [0x007B] = "\\{",
    [0x007D] = "\\}",
}

table.setmetatableindex(resolved, function(t,k)
    local v = utfchar(k)
    t[k] = v
    return v
end)

local ctx_normalatop = context.normalatop
local ctx_normalover = context.normalover

local function mathfraction(how,left,right,width)
    if how == v_no then
        if left == 0x002E and right == 0x002E then
            ctx_normalatop()
        else
            context("\\atopwithdelims%s%s",resolved[left],resolved[right])
        end
    elseif how == v_yes then
        if left == 0x002E and right == 0x002E then
            context("\\normalabove%ssp",width)
        else
            context("\\abovewithdelims%s%s%ssp",resolved[left],resolved[right],width)
        end
    else -- v_auto
        if left == 0x002E and right == 0x002E then
            ctx_normalover()
        else
            context("\\overwithdelims%s%s",resolved[left],resolved[right])
        end
    end
end

interfaces.implement {
    name      = "mathfraction",
    actions   = mathfraction,
    arguments = { "string", "number", "number", "dimen" }
}
