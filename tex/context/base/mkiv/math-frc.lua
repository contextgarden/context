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
local v_hidden  = variables.hidden

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
    elseif how == v_yes or how == v_hidden then
        local norule = how == v_hidden and LUATEXFUNCTIONALITY > 7361 and " norule " or ""
        if left == 0x002E and right == 0x002E then
            context("\\normalabove%s%s%ssp",norule,width)
        else
            context("\\abovewithdelims%s%s%s%s%ssp",norule,resolved[left],resolved[right],width)
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

-- experimental code in lmtx

if CONTEXTLMTXMODE > 0 then

    local ctx_Uatop = context.Uatop
    local ctx_Uover = context.Uover

    local function umathfraction(how,left,right,width)
        if how == v_no then
            if left == 0x002E and right == 0x002E then
                ctx_Uatop()
            else
                context("\\Uatopwithdelims%s%s",resolved[left],resolved[right])
            end
        elseif how == v_yes or how == v_hidden then
            local norule = how == v_hidden and " norule " or ""
            if left == 0x002E and right == 0x002E then
                context("\\Uabove%s%ssp",norule,width)
            else
                context("\\Uabovewithdelims%s%s%s%ssp",norule,resolved[left],resolved[right],width)
            end
        else -- v_auto
            if left == 0x002E and right == 0x002E then
                ctx_Uover()
            else
                context("\\Uoverwithdelims%s%s",resolved[left],resolved[right])
            end
        end
    end

    interfaces.implement {
        name      = "umathfraction",
        actions   = umathfraction,
        arguments = { "string", "number", "number", "dimen" }
    }

end
