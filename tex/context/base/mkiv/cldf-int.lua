if not modules then modules = { } end modules ['cldf-int'] = {
    version   = 1.001,
    comment   = "companion to mult-clm.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- another experiment
-- needs upgrading
-- needs checking
-- todo: multilingual

local format, insert, remove, concat = string.format, table.insert, table.remove, table.concat
local unpack = unpack or table.unpack

local catcodenumbers = catcodes.numbers

local ctxcatcodes    = catcodenumbers.ctxcatcodes
local vrbcatcodes    = catcodenumbers.vrbcatcodes

local context        = context
local contextsprint  = context.sprint

local trace_define   = false  trackers.register("context.define", function(v) trace_define = v end)

interfaces = interfaces or { }

_clmh_ = utilities.parsers.settings_to_array
_clma_ = utilities.parsers.settings_to_array

local starters, stoppers, macros, stack = { }, { }, { }, { }

local checkers = {
    [0] = "",
    "\\dosingleempty",
    "\\dodoubleempty",
    "\\dotripleempty",
    "\\doquadrupleempty",
    "\\doquintupleempty",
    "\\dosixtupleempty",
}

function _clmm_(name,...)
    macros[name](...)
end

function _clmb_(name,...)
    local sn = stack[name]
    insert(sn,{...})
    starters[name](...)
end

function _clme_(name)
    local sn = stack[name]
    local sv = remove(sn)
    if sv then
        stoppers[name](unpack(sv))
    else
        -- nesting error
    end
end

_clmn_ = tonumber

local estart = interfaces.elements.start
local estop  = interfaces.elements.stop

function interfaces.definecommand(name,specification) -- name is optional
    if type(name) == "table" then
        specification = name
        name = specification.name
    end
    if name and specification then
        local arguments = specification.arguments
        local na = (arguments and #arguments) or 0
        local environment = specification.environment
        if na == 0 then
            if environment then
                contextsprint(ctxcatcodes,"\\setuvalue{",estart,name,"}{\\ctxlua{_clmb_('",name,"')}}")
                contextsprint(ctxcatcodes,"\\setuvalue{",estop, name,"}{\\ctxlua{_clme_('",name,"')}}")
            end
            if not environment or environment == "both" then
                contextsprint(ctxcatcodes,"\\setuvalue{",       name,"}{\\ctxlua{_clmm_('",name,"')}}")
            end
        else
            -- we could flush immediate but tracing is bad then
            stack[name] = { }
            local opt, done = 0, false
            local snippets = { } -- we can reuse it
            local mkivdo = "\\mkivdo" .. name -- maybe clddo
            snippets[#snippets+1] = "\\def"
            snippets[#snippets+1] = mkivdo
            for i=1,na do
                local a = arguments[i]
                local variant = a[1]
                if variant == "option" then
                    snippets[#snippets+1] = "[#"
                    snippets[#snippets+1] = i
                    snippets[#snippets+1] = "]"
                    if not done then
                        opt = opt + 1
                    end
                else
                    done = true -- no more optional checking after this
                    snippets[#snippets+1] = "#"
                    snippets[#snippets+1] = i
                end
            end
            if environment then
                snippets[#snippets+1] = "{\\ctxlua{_clmb_('"
                snippets[#snippets+1] = name
                snippets[#snippets+1] = "'"
            else
                snippets[#snippets+1] = "{\\ctxlua{_clmm_('"
                snippets[#snippets+1] = name
                snippets[#snippets+1] = "'"
            end
            for i=1,na do
                local a = arguments[i]
                local variant = a[2]
                if variant == "list" then
                    snippets[#snippets+1] = ",_clma_([[#"
                    snippets[#snippets+1] = i
                    snippets[#snippets+1] = "]])"
                elseif variant == "hash" then
                    snippets[#snippets+1] = ",_clmh_([[#"
                    snippets[#snippets+1] = i
                    snippets[#snippets+1] = "]])"
                elseif variant == "number" then
                    snippets[#snippets+1] = ",_clmn_([[#"
                    snippets[#snippets+1] = i
                    snippets[#snippets+1] = "]])"
                else
                    snippets[#snippets+1] = ",[[#"
                    snippets[#snippets+1] = i
                    snippets[#snippets+1] = "]]"
                end
            end
            snippets[#snippets+1] = ")}}"
            contextsprint(ctxcatcodes,unpack(snippets))
            if environment then
                -- needs checking
                contextsprint(ctxcatcodes,"\\setuvalue{",estart,name,"}{",checkers[opt],mkivdo,"}")
                contextsprint(ctxcatcodes,"\\setuvalue{",estop, name,"}{\\ctxlua{_clme_('",name,"')}}")
            end
            if not environment or environment == "both" then
                contextsprint(ctxcatcodes,"\\setuvalue{",       name,"}{",checkers[opt],mkivdo,"}")
            end
        end
        if environment then
            starters[name] = specification.starter
            stoppers[name] = specification.stopper
        else
            macros[name] = specification.macro
        end
    end
end

function interfaces.tolist(t)
    local r = { }
    for i=1,#t do
        r[i] = t[i]
    end
    local n = #r
    for k,v in table.sortedhash(t) do
        if type(k) ~= "number" then
            n = n + 1
            r[n] = k .. "=" .. v
        end
    end
    return concat(r,", ")
end

--~ \startluacode
--~ function test(opt_1, opt_2, arg_1)
--~     context.startnarrower()
--~     context("options 1: %s",interfaces.tolist(opt_1))
--~     context.par()
--~     context("options 2: %s",interfaces.tolist(opt_2))
--~     context.par()
--~     context("argument 1: %s",arg_1)
--~     context.stopnarrower()
--~ end

--~ interfaces.definecommand {
--~     name = "test",
--~     arguments = {
--~         { "option", "list" },
--~         { "option", "hash" },
--~         { "content", "string" },
--~     },
--~     macro = test,
--~ }
--~ \stopluacode

--~ test: \test[1][a=3]{whatever}

--~ \startluacode
--~ local function startmore(opt_1)
--~     context.startnarrower()
--~     context("start more, options: %s",interfaces.tolist(opt_1))
--~     context.startnarrower()
--~ end

--~ local function stopmore(opt_1)
--~     context.stopnarrower()
--~     context("stop more, options: %s",interfaces.tolist(opt_1))
--~     context.stopnarrower()
--~ end

--~ interfaces.definecommand ( "more", {
--~     environment = true,
--~     arguments = {
--~         { "option", "list" },
--~     },
--~     starter = startmore,
--~     stopper = stopmore,
--~ } )
--~ \stopluacode

--~ more: \startmore[1] one \startmore[2] two \stopmore one \stopmore
