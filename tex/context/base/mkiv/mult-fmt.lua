if not modules then modules = { } end modules ['mult-fmt'] = {
    version   = 1.001,
    comment   = "companion to mult-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next
local concat, sortedhash = table.concat, table.sortedhash
local sub, formatters = string.sub, string.formatters
local utfsplit = utf.split

local prtcatcodes     = catcodes.numbers.prtcatcodes
local contextsprint   = context.sprint
local implement       = interfaces.implement

local setmacro        = token.set_macro
local definedmacro    = token.is_defined

local report             = logs.reporter("interface")
local report_interface   = logs.reporter("interface","initialization")
local report_variable    = logs.reporter("variable")
local report_constant    = logs.reporter("constant")
local report_command     = logs.reporter("command")
local report_element     = logs.reporter("element")
local report_format      = logs.reporter("format")
local report_messagetag  = logs.reporter("messagetag")
local report_setupstring = logs.reporter("setupstring")

local function limit(str,n)
    if n > 6 and #str > n then
        n = n - 4
        local t = utfsplit(str)
        local m = #t
        if m > n then
            t[n] = " ..."
            str = concat(t,"",1,n)
        end
    end
    return str
end

-- function interfaces.setuserinterface(interface,response)
--     local variables     = interfaces.variables
--     local constants     = interfaces.constants
--     local elements      = interfaces.elements
--     local formats       = interfaces.formats
--     local translations  = interfaces.translations
--     local setupstrings  = interfaces.setupstrings
--     local complete      = interfaces.complete
--     local sharedstorage = storage.shared
--     --
--     sharedstorage.currentinterface, currentinterface = interface, interface
--     sharedstorage.currentresponse, currentresponse = response, response
--     --
--     if environment.initex then
--         local nofconstants    = 0
--         local nofvariables    = 0
--         local nofelements     = 0
--         local nofcommands     = 0
--         local nofformats      = 0
--         local noftranslations = 0
--         local nofsetupstrings = 0
--         --
--         do
--             local list = complete.constants -- forces the load
--             local t    = { }
--             local f    = formatters["\\ui_c{%s}{%s}"]
--             local s    = formatters["\\ui_s{%s}"]
--             logs.startfilelogging(report,"translated constants")
--             for given, constant in sortedhash(list) do
--                 constant = constant[interface] or constant.en or given
--                 constants[constant] = given -- breedte -> width
--                 nofconstants = nofconstants + 1
--                 if given == constant then
--                     t[nofconstants] = s(given)
--                 else
--                     t[nofconstants] = f(given,constant)
--                 end
--                 report_constant("%-40s: %s",given,constant)
--             end
--             logs.stopfilelogging()
--             contextsprint(prtcatcodes,concat(t))
--         end
--         do
--             local list = complete.variables -- forces the load
--             local t    = { }
--             local f    = formatters["\\ui_v{%s}{%s}"]
--             logs.startfilelogging(report,"translated variables")
--             for given, variable in sortedhash(list) do
--                 variable = variable[interface] or variable.en or given
--                 variables[given] = variable -- ja -> yes
--                 nofvariables = nofvariables + 1
--                 t[nofvariables] = f(given,variable)
--                 report_variable("%-40s: %s",given,variable)
--             end
--             logs.stopfilelogging()
--             contextsprint(prtcatcodes,concat(t))
--         end
--         do
--             local list = complete.elements -- forces the load
--             local t    = { }
--             local f    = formatters["\\ui_e{%s}{%s}"]
--             logs.startfilelogging(report,"translated elements")
--             for given, element in sortedhash(list) do
--                 element = element[interface] or element.en or given
--                 elements[element] = given
--                 nofelements = nofelements + 1
--                 t[nofelements] = f(given,element)
--                 report_element("%-40s: %s",given,element)
--             end
--             logs.stopfilelogging()
--             contextsprint(prtcatcodes,concat(t))
--         end
--         do
--             local list = complete.commands -- forces the load
--             local t    = { }
--             local n    = 0
--             local f    = formatters["\\ui_a\\%s\\%s"] -- formatters["\\ui_m{%s}{%s}"]
--             logs.startfilelogging(report,"translated commands")
--             for given, command in sortedhash(list) do
--                 command = command[interface] or command.en or given
--                 if command ~= given then
--                     n = n + 1
--                     t[n] = f(given,command)
--                     report_command("%-40s: %s",given,command)
--                 end
--                 nofcommands = nofcommands + 1
--             end
--             logs.stopfilelogging()
--             contextsprint(prtcatcodes,"\\toksapp\\everydump{"..concat(t).."}")
--         end
--         do
--             local list = complete.messages.formats
--             logs.startfilelogging(report,"translated message formats")
--             for given, format in sortedhash(list) do
--                 local found = format[interface] or format.en or given
--                 formats[given] = found
--                 nofformats = nofformats + 1
--                 report_messagetag("%-40s: %s",limit(given,38),limit(found,38))
--             end
--             logs.stopfilelogging()
--         end
--         do
--             local list = complete.messages.translations
--             logs.startfilelogging(report,"translated message tags")
--             for given, translation in sortedhash(list) do
--                 local found = translation[interface] or translation.en or given
--                 translations[given] = found
--                 noftranslations = noftranslations + 1
--                 report_messagetag("%-40s: %s",given,found)
--             end
--             logs.stopfilelogging()
--         end
--         do
--             local list = complete.setupstrings
--             logs.startfilelogging(report,"translated setupstrings")
--             for given, setupstring in sortedhash(list) do
--                 local found = setupstring[interface] or setupstring.en or given
--                 setupstrings[given] = found
--                 nofsetupstrings = nofsetupstrings + 1
--                 report_setupstring("%-40s: %s",given,found)
--             end
--             logs.stopfilelogging()
--         end
--         report_interface("definitions: %a constants, %a variables, %a elements, %a commands, %a formats, %a translations, %a setupstrings",
--             nofconstants,nofvariables,nofelements,nofcommands,nofformats,noftranslations,nofsetupstrings)
--     else
--         report_interface("the language(s) can only be set when making the format")
--     end
--     interfaces.currentinterface = currentinterface
--     interfaces.currentresponse  = currentresponse
-- end

-- different per interface
--
-- en:
--
-- ui_c macro:#1#2 -> \immutable \gdefcsname \c!prefix! #1\endcsname {#1}
-- ui_v macro:#1#2 -> \immutable \gdefcsname \v!prefix! #1\endcsname {#2}
-- ui_e macro:#1#2 -> \immutable \gdefcsname \e!prefix! #1\endcsname {#2}
-- ui_a macro:#1#2 -> \frozen \protected \def #2{#1}
--
-- otherwise:
--
-- ui_c macro:#1#2 -> \immutable \gdefcsname \c!prefix! #1\endcsname {#1}
--                    \immutable \gdefcsname \k!prefix! #2\endcsname {#1}

function interfaces.setuserinterface(interface,response)
    local variables     = interfaces.variables
    local constants     = interfaces.constants
    local elements      = interfaces.elements
    local formats       = interfaces.formats
    local translations  = interfaces.translations
    local setupstrings  = interfaces.setupstrings
    local complete      = interfaces.complete
    local sharedstorage = storage.shared
    --
    sharedstorage.currentinterface, currentinterface = interface, interface
    sharedstorage.currentresponse, currentresponse = response, response
    --
    if environment.initex then
        local nofconstants    = 0
        local nofvariables    = 0
        local nofelements     = 0
        local nofcommands     = 0
        local nofformats      = 0
        local noftranslations = 0
        local nofsetupstrings = 0
        local reversetoo      = interface ~= "en"
        --
        do
            local list = complete.constants -- forces the load
            logs.startfilelogging(report,"translated constants")
            for given, constant in sortedhash(list) do
                constant = constant[interface] or constant.en or given
                constants[constant] = given -- breedte -> width
                nofconstants = nofconstants + 1
                setmacro("c!" .. given,given,"immutable")
                if reversetoo then
                    setmacro("k!" .. constant,given,"immutable")
                end
                report_constant("%-40s: %s",given,constant)
            end
            logs.stopfilelogging()
        end
        do
            local list = complete.variables -- forces the load
            logs.startfilelogging(report,"translated variables")
            for given, variable in sortedhash(list) do
                variable = variable[interface] or variable.en or given
                variables[given] = variable -- ja -> yes
                nofvariables = nofvariables + 1
                setmacro("v!" .. given,variable,"immutable")
                report_variable("%-40s: %s",given,variable)
            end
            logs.stopfilelogging()
        end
        do
            local list = complete.elements -- forces the load
            logs.startfilelogging(report,"translated elements")
            for given, element in sortedhash(list) do
                element = element[interface] or element.en or given
                elements[element] = given
                nofelements = nofelements + 1
                setmacro("e!" .. given,element,"immutable")
                report_element("%-40s: %s",given,element)
            end
            logs.stopfilelogging()
        end
--         do
--             local list = complete.commands -- forces the load
--             local todo = { } -- normally a small list
--             logs.startfilelogging(report,"translated commands")
--             for given, command in sortedhash(list) do
--                 command = command[interface] or command.en or given
--                 if command ~= given then
--                     report_command("%-40s: %s",given,command)
--                     todo[given] = command
--                 end
--                 nofcommands = nofcommands + 1
--             end
--             logs.stopfilelogging()
--             -- For some reason we get corrupted definitions.
--             luatex.registerdumpactions(function()
--                 for given, command in sortedhash(todo) do
--                  -- if definedmacro(given) then
--                         setmacro(command,"\\"..given,"frozen","protected","global")
--                  -- end
--                 end
--             end)
--         end
        do
            local list = complete.commands -- forces the load
            local t    = { }
            local n    = 0
            local f    = formatters["\\frozen\\protected\\def\\%s{\\%s}"] -- formatters["\\ui_m{%s}{%s}"]
            logs.startfilelogging(report,"translated commands")
            for given, command in sortedhash(list) do
                command = command[interface] or command.en or given
                if command ~= given then
                    n = n + 1
                    t[n] = f(command,given)
                    report_command("%-40s: %s",given,command)
                end
                nofcommands = nofcommands + 1
            end
            logs.stopfilelogging()
            contextsprint(prtcatcodes,"\\toksapp\\everydump{"..concat(t).."}")
        end
        do
            local list = complete.messages.formats
            logs.startfilelogging(report,"translated message formats")
            for given, format in sortedhash(list) do
                local found = format[interface] or format.en or given
                formats[given] = found
                nofformats = nofformats + 1
                report_messagetag("%-40s: %s",limit(given,38),limit(found,38))
            end
            logs.stopfilelogging()
        end
        do
            local list = complete.messages.translations
            logs.startfilelogging(report,"translated message tags")
            for given, translation in sortedhash(list) do
                local found = translation[interface] or translation.en or given
                translations[given] = found
                noftranslations = noftranslations + 1
                report_messagetag("%-40s: %s",given,found)
            end
            logs.stopfilelogging()
        end
        do
            local list = complete.setupstrings
            logs.startfilelogging(report,"translated setupstrings")
            for given, setupstring in sortedhash(list) do
                local found = setupstring[interface] or setupstring.en or given
                setupstrings[given] = found
                nofsetupstrings = nofsetupstrings + 1
                report_setupstring("%-40s: %s",given,found)
            end
            logs.stopfilelogging()
        end
        report_interface("definitions: %a constants, %a variables, %a elements, %a commands, %a formats, %a translations, %a setupstrings",
            nofconstants,nofvariables,nofelements,nofcommands,nofformats,noftranslations,nofsetupstrings)
    else
        report_interface("the language(s) can only be set when making the format")
    end
    interfaces.currentinterface = currentinterface
    interfaces.currentresponse  = currentresponse
end

interfaces.implement {
    name      = "setuserinterface",
    actions   = interfaces.setuserinterface,
    arguments = "2 strings",
}
