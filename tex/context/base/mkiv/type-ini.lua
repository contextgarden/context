if not modules then modules = { } end modules ['type-ini'] = {
    version   = 1.001,
    comment   = "companion to type-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gsub = string.gsub
local lpegmatch, P, Cs = lpeg.match, lpeg.P, lpeg.Cs

-- more code will move here

local commands   = commands
local context    = context
local implement  = interfaces.implement

local uselibrary = resolvers.uselibrary

local name_one   = nil
local name_two   = nil

local p_strip    = Cs((P("type-") * (P("imp-")^0))^0/"" * P(1)^0)

local report     = logs.reporter("fonts","typescripts")

local function action(name,foundname)
    context.loadfoundtypescriptfile(name,foundname)
end

local patterns = {
    "type-imp-%s.mkiv",
    "type-imp-%s.tex"
}

local function failure(name)
    if name == "loc" then
        -- ignore
    else
        report("unknown library %a",name)
    end
end

implement {
    name      = "loadtypescriptfile",
    arguments = "string",
    actions   = function(name) -- a more specific name
        uselibrary {
            name     = lpegmatch(p_strip,name) or name,
            patterns = patterns,
            action   = action,
            failure  = failure,
            onlyonce = false, -- will become true
        }
    end
}

local patterns = {
    "type-imp-%s.mkiv",
    "type-imp-%s.tex",
    -- obsolete
    "type-%s.mkiv",
    "type-%s.tex"
}

-- local function failure_two(name)
--     report("unknown library %a or %a",name_one,name_two)
-- end
--
-- local function failure_one(name)
--     name_two = gsub(name,"%-.*$","")
--     if name == "loc" then
--         -- ignore
--     elseif name_two == name then
--         report("unknown library %a",name_one)
--     else
--         resolvers.uselibrary {
--             name     = name_two,
--             patterns = patterns,
--             action   = action,
--             failure  = failure_two,
--             onlyonce = false, -- will become true
--         }
--     end
-- end
--
-- function commands.doprocesstypescriptfile(name)
--     name_one = lpegmatch(p_strip,name) or name
--     uselibrary {
--         name     = name_one,
--         patterns = patterns,
--         action   = action,
--         failure  = failure_one,
--         onlyonce = false, -- will become true
--     }
-- end

implement {
    name      = "doprocesstypescriptfile",
    arguments = "string",
    actions   = function(name)
        uselibrary {
            name     = lpegmatch(p_strip,name) or name,
            patterns = patterns,
            action   = action,
            failure  = failure,
            onlyonce = false, -- will become true
        }
    end
}
