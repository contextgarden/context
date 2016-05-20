if not modules then modules = { } end modules ['syst-lua'] = {
    version   = 1.001,
    comment   = "companion to syst-lua.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find, match = string.find, string.match
local tonumber = tonumber
local S, C, P, lpegmatch, lpegtsplitat = lpeg.S, lpeg.C, lpeg.P, lpeg.match, lpeg.tsplitat


commands          = commands or { }
local commands    = commands

local implement   = interfaces.implement

local two_strings = interfaces.strings[2]

local context     = context
----- csprint     = context.sprint

local prtcatcodes = tex.prtcatcodes

implement { -- will b eoverloaded later
    name      = "writestatus",
    arguments = two_strings,
    actions   = logs.status,
}

local ctx_firstoftwoarguments  = context.firstoftwoarguments  -- context.constructcsonly("firstoftwoarguments" )
local ctx_secondoftwoarguments = context.secondoftwoarguments -- context.constructcsonly("secondoftwoarguments")
local ctx_firstofoneargument   = context.firstofoneargument   -- context.constructcsonly("firstofoneargument"  )
local ctx_gobbleoneargument    = context.gobbleoneargument    -- context.constructcsonly("gobbleoneargument"   )

-- contextsprint(prtcatcodes,[[\ui_fo]]) -- ctx_firstofonearguments
-- contextsprint(prtcatcodes,[[\ui_go]]) -- ctx_gobbleonearguments
-- contextsprint(prtcatcodes,[[\ui_ft]]) -- ctx_firstoftwoarguments
-- contextsprint(prtcatcodes,[[\ui_st]]) -- ctx_secondoftwoarguments

function commands.doifelse(b)
    if b then
        ctx_firstoftwoarguments()
     -- csprint(prtcatcodes,[[\ui_ft]]) -- ctx_firstoftwoarguments
    else
        ctx_secondoftwoarguments()
     -- csprint(prtcatcodes,[[\ui_st]]) -- ctx_secondoftwoarguments
    end
end

function commands.doifelsesomething(b)
    if b and b ~= "" then
        ctx_firstoftwoarguments()
     -- csprint(prtcatcodes,[[\ui_ft]]) -- ctx_firstoftwoarguments
    else
        ctx_secondoftwoarguments()
     -- csprint(prtcatcodes,[[\ui_st]]) -- ctx_secondoftwoarguments
    end
end

function commands.doif(b)
    if b then
        ctx_firstofoneargument()
-- context.__flushdirect(prtcatcodes,[[\ui_fo]]) -- ctx_firstofonearguments
    else
        ctx_gobbleoneargument()
-- context.__flushdirect(prtcatcodes,[[\ui_go]]) -- ctx_gobbleonearguments
    end
end

function commands.doifsomething(b)
    if b and b ~= "" then
        ctx_firstofoneargument()
     -- context.__flushdirect(prtcatcodes,[[\ui_fo]]) -- ctx_firstofonearguments
    else
        ctx_gobbleoneargument()
     -- context.__flushdirect(prtcatcodes,[[\ui_go]]) -- ctx_gobbleonearguments
    end
end

function commands.doifnot(b)
    if b then
        ctx_gobbleoneargument()
     -- csprint(prtcatcodes,[[\ui_go]]) -- ctx_gobbleonearguments
    else
        ctx_firstofoneargument()
     -- csprint(prtcatcodes,[[\ui_fo]]) -- ctx_firstofonearguments
    end
end

function commands.doifnotthing(b)
    if b and b ~= "" then
        ctx_gobbleoneargument()
     -- csprint(prtcatcodes,[[\ui_go]]) -- ctx_gobbleonearguments
    else
        ctx_firstofoneargument()
     -- csprint(prtcatcodes,[[\ui_fo]]) -- ctx_firstofonearguments
    end
end

commands.testcase = commands.doifelse -- obsolete

function commands.boolcase(b)
    context(b and 1 or 0)
end

function commands.doifelsespaces(str)
    if find(str,"^ +$") then
        ctx_firstoftwoarguments()
    else
        ctx_secondoftwoarguments()
    end
end

local pattern = lpeg.patterns.validdimen

function commands.doifelsedimenstring(str)
    if lpegmatch(pattern,str) then
        ctx_firstoftwoarguments()
    else
        ctx_secondoftwoarguments()
    end
end

local p_first = C((1-P(",")-P(-1))^0)

implement {
    name      = "firstinset",
    arguments = "string",
    actions   = function(str) context(lpegmatch(p_first,str or "")) end
}

implement {
    name      = "ntimes",
    arguments = { "string", "integer" },
    actions   = { string.rep, context }
}

implement {
    name      = "execute",
    arguments = "string",
    actions   = os.execute -- wrapped in sandbox
}

implement {
    name      = "doifelsesame",
    arguments = two_strings,
    actions   = function(a,b)
        if a == b then
            ctx_firstoftwoarguments()
        else
            ctx_secondoftwoarguments()
        end
    end
}

implement {
    name      = "doifsame",
    arguments = two_strings,
    actions   = function(a,b)
        if a == b then
            ctx_firstofoneargument()
        else
            ctx_gobbleoneargument()
        end
    end
}

implement {
    name      = "doifnotsame",
    arguments = two_strings,
    actions   = function(a,b)
        if a == b then
            ctx_gobbleoneargument()
        else
            ctx_firstofoneargument()
        end
    end
}
