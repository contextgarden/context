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

local format, byte = string.format, string.byte
local insert, remove, concat = table.insert, table.remove, table.concat
local unpack, type = unpack or table.unpack, type

local catcodenumbers = catcodes.numbers

local ctxcatcodes    = catcodenumbers.ctxcatcodes
local vrbcatcodes    = catcodenumbers.vrbcatcodes

local context        = context
local contextsprint  = context.sprint

local trace_define   = false  trackers.register("context.define", function(v) trace_define = v end)

interfaces           = interfaces or { }
local implement      = interfaces.implement
local estart         = interfaces.elements.start
local estop          = interfaces.elements.stop

if CONTEXTLMTXMODE > 0 then

    local scanners  = tokens.scanners
    local shortcuts = tokens.shortcuts

    local scanpeek  = scanners.peek
    local scankey   = scanners.key
    local scanvalue = scanners.value
    local scanskip  = scanners.skip

    local open      = byte('[')
    local close     = byte(']')
    local equal     = byte('=')
    local comma     = byte(',')

    function scanhash(scanners)
        if scanpeek() == open then
            local data = { }
            scanskip()
            while true do
                local c = scanpeek()
                if c == comma then
                    scanskip()
                elseif c == close then
                    scanskip()
                    break
                else
                    local key = scankey(equal)
                    if key then
                        if scanpeek() == equal then
                            scanskip()
                            if scanners then
                                local scanner = scanners[key]
                                if scanner then
                                    data[key] = scanner()
                                else
                                    data[key] = scanvalue(comma,close) or ""
                                end
                            else
                                data[key] = scanvalue(comma,close) or ""
                            end
                        else
                            break
                        end
                    else
                        break
                    end
                end
            end
            return data
        end
    end

    function scanarray()
        if scanpeek() == open then
            local data = { }
            local d = 0
            scanskip()
            while true do
                local c = scanpeek()
                if c == comma then
                    scanskip()
                elseif c == close then
                    scanskip()
                    break
                else
                    local v = scanvalue(comma,close) or ""
                    d = d + 1
                    data[d] = v
                end
            end
            return data
        end
    end

    shortcuts.scanhash  = scanhash
    shortcuts.scanarray = scanarray

    scanners.hash  = scanhash
    scanners.array = scanarray

    local function remap(arguments)
        -- backward compatibility
        if type(arguments) == "table" then
            for i=1,#arguments do
                local a = arguments[i]
                if type(a) == "table" then
                    local t = a[2]
                    arguments[i] = t == "list" and "array" or t
                end
            end
            return arguments
        end
    end

    function interfaces.definecommand(name,specification) -- name is optional
        if type(name) == "table" then
            specification = name
            name = specification.name
        end
        if name and specification then
            local environment = specification.environment
            local arguments   = remap(specification.arguments)
            if environment then
                local starter = specification.starter
                local stopper = specification.stopper
                if starter and stopper then
                    implement {
                        name      = estart .. name,
                        arguments = arguments,
                        public    = true,
                        protected = true,
                        actions   = starter,
                    }
                    implement {
                        name      = estop .. name,
                        public    = true,
                        protected = true,
                        actions   = stopper,
                    }
                else
                    -- message
                end
            end
            if not environment or environment == "both" then
                local macro = specification.macro
                if macro then
                    implement {
                        name      = name,
                        arguments = arguments,
                        public    = true,
                        protected = true,
                        actions   = macro,
                    }
                else
                    -- message
                end
            end
        else
            -- message
        end
    end


else

    _clmh_ = utilities.parsers.settings_to_hash
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

    -- this is a bit old definition ... needs to be modernized

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
                local opt      = 0
                local done     = false
                local snippets = { } -- we can reuse it
                local mkivdo   = "\\mkivdo" .. name -- maybe clddo
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
                        snippets[#snippets+1] = ",_clma_([==[#"
                        snippets[#snippets+1] = i
                        snippets[#snippets+1] = "]==])"
                    elseif variant == "hash" then
                        snippets[#snippets+1] = ",_clmh_([==[#"
                        snippets[#snippets+1] = i
                        snippets[#snippets+1] = "]==])"
                    elseif variant == "number" then
                        snippets[#snippets+1] = ",_clmn_([==[#"
                        snippets[#snippets+1] = i
                        snippets[#snippets+1] = "]==])"
                    else
                        snippets[#snippets+1] = ",[==[#"
                        snippets[#snippets+1] = i
                        snippets[#snippets+1] = "]==]"
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

-- \startluacode
-- function test(opt_1, opt_2, arg_1)
--     context.startnarrower()
--     context("options 1: %s",interfaces.tolist(opt_1))
--     context.par()
--     context("options 2: %s",interfaces.tolist(opt_2))
--     context.par()
--     context("argument 1: %s",arg_1)
--     context.stopnarrower()
-- end
--
-- interfaces.definecommand {
--     name = "test",
--     arguments = {
--         { "option", "list" },
--         { "option", "hash" },
--         { "content", "string" },
--     },
--     macro = test,
-- }
-- \stopluacode
--
-- test: \test[1][a=3]{whatever}
--
-- \startluacode
-- local function startmore(opt_1)
--     context.startnarrower()
--     context("start more, options: %s",interfaces.tolist(opt_1))
--     context.startnarrower()
-- end
--
-- local function stopmore(opt_1)
--     context.stopnarrower()
--     context("stop more, options: %s",interfaces.tolist(opt_1))
--     context.stopnarrower()
-- end
--
-- interfaces.definecommand ( "more", {
--     environment = true,
--     arguments = {
--         { "option", "list" },
--     },
--     starter = startmore,
--     stopper = stopmore,
-- } )
-- \stopluacode
--
-- more: \startmore[1] one \startmore[2] two \stopmore one \stopmore
--
-- More modern (no need for option or content):
--
-- \startluacode
-- interfaces.definecommand {
--     name = "test",
--     arguments = {
--         "array", -- or list
--         "hash",
--         "string",
--         "number",
--     },
--     macro = test,
-- }
-- \stopluacode
--

