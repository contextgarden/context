if not modules then modules = { } end modules ['mult-ini'] = {
    version   = 1.001,
    comment   = "companion to mult-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gmatch, match, find, sub = string.format, string.gmatch, string.match, string.find, string.sub
local lpegmatch = lpeg.match
local serialize, concat = table.serialize, table.concat
local rawget, type, tonumber, next = rawget, type, tonumber, next

local context             = context
local commands            = commands
local implement           = interfaces.implement

local allocate            = utilities.storage.allocate
local mark                = utilities.storage.mark
local prtcatcodes         = catcodes.numbers.prtcatcodes
local vrbcatcodes         = catcodes.numbers.vrbcatcodes
local contextsprint       = context.sprint
local setmetatableindex   = table.setmetatableindex
local formatters          = string.formatters

local report_interface    = logs.reporter("interface","initialization")

interfaces                = interfaces                     or { }
interfaces.constants      = mark(interfaces.constants      or { })
interfaces.variables      = mark(interfaces.variables      or { })
interfaces.elements       = mark(interfaces.elements       or { })
interfaces.formats        = mark(interfaces.formats        or { })
interfaces.translations   = mark(interfaces.translations   or { })
interfaces.setupstrings   = mark(interfaces.setupstrings   or { })
interfaces.corenamespaces = mark(interfaces.corenamespaces or { })
interfaces.usednamespaces = mark(interfaces.usednamespaces or { })

local registerstorage     = storage.register
local sharedstorage       = storage.shared

local constants           = interfaces.constants
local variables           = interfaces.variables
local elements            = interfaces.elements
local formats             = interfaces.formats
local translations        = interfaces.translations
local setupstrings        = interfaces.setupstrings
local corenamespaces      = interfaces.corenamespaces
local usednamespaces      = interfaces.usednamespaces
local reporters           = { } -- just an optimization

registerstorage("interfaces/constants",      constants,      "interfaces.constants")
registerstorage("interfaces/variables",      variables,      "interfaces.variables")
registerstorage("interfaces/elements",       elements,       "interfaces.elements")
registerstorage("interfaces/formats",        formats,        "interfaces.formats")
registerstorage("interfaces/translations",   translations,   "interfaces.translations")
registerstorage("interfaces/setupstrings",   setupstrings,   "interfaces.setupstrings")
registerstorage("interfaces/corenamespaces", corenamespaces, "interfaces.corenamespaces")
registerstorage("interfaces/usednamespaces", usednamespaces, "interfaces.usednamespaces")

interfaces.interfaces = {
    "cs", "de", "en", "fr", "it", "nl", "ro", "pe",
}

sharedstorage.currentinterface = sharedstorage.currentinterface or "en"
sharedstorage.currentresponse  = sharedstorage.currentresponse  or "en"

local currentinterface = sharedstorage.currentinterface
local currentresponse  = sharedstorage.currentresponse

interfaces.currentinterface = currentinterface
interfaces.currentresponse  = currentresponse

local complete      = allocate()
interfaces.complete = complete

local function resolve(t,k) -- one access needed to get loaded (not stored!)
    report_interface("loading interface definitions from 'mult-def.lua'")
    complete = dofile(resolvers.findfile("mult-def.lua"))
    report_interface("loading interface messages from 'mult-mes.lua'")
    complete.messages = dofile(resolvers.findfile("mult-mes.lua"))
    interfaces.complete = complete
    return rawget(complete,k)
end

setmetatableindex(complete, resolve)

local function valueiskey(t,k) -- will be helper
    t[k] = k
    return k
end

setmetatableindex(variables,    valueiskey)
setmetatableindex(constants,    valueiskey)
setmetatableindex(elements,     valueiskey)
setmetatableindex(formats,      valueiskey)
setmetatableindex(translations, valueiskey)
setmetatableindex(setupstrings, valueiskey)

function interfaces.registernamespace(n,namespace)
    corenamespaces[n] = namespace
    usednamespaces[namespace] = n
end

function interfaces.getnamespace(n)
    return usednamespaces[n] .. ">"
end

if documentdata then

    local prefix, getmacro

    function documentdata.variable(name)
        if not prefix then
            prefix = usednamespaces.variables .. ">document:"
        end
        if not getmacro then
            getmacro = tokens.getters.macro
        end
        return getmacro(prefix..name)
    end

end

local function resolve(t,k)
    local v = logs.reporter(k)
    t[k] = v
    return v
end

setmetatableindex(reporters,resolve)

for category, _ in next, translations do
    -- We pre-create reporters for already defined messages
    -- because otherwise listing is incomplete and we want
    -- to use that for checking so delaying makes not much
    -- sense there.
    local r = reporters[category]
end

-- adding messages

local function add(target,tag,values)
    local t = target[tag]
    if not f then
        target[tag] = values
    else
        for k, v in next, values do
            if f[k] then
                -- error
            else
                f[k] = v
            end
        end
    end
end

function interfaces.settranslation(tag,values)
    add(translations,tag,values)
end

function interfaces.setformat(tag,values)
    add(formats,tag,values)
end

local function getsetupstring(tag)
    return setupstrings[tag] or tag
end

interfaces.getsetupstring = getsetupstring

-- the old method:

local replacer = lpeg.replacer { { "--", "%%a" } }

local function fulltag(category,tag)
    return formatters["%s:%s"](category,lpegmatch(replacer,tag))
end

function interfaces.setmessages(category,str)
    for tag, message in gmatch(str,"(%S+) *: *(.-) *[\n\r]") do
        if tag == "title" then
            translations[tag] = translations[tag] or tag
        else
            formats[fulltag(category,tag)] = lpegmatch(replacer,message)
        end
    end
end

function interfaces.setmessage(category,tag,message)
    formats[fulltag(category,tag)] = lpegmatch(replacer,message)
end

function interfaces.getmessage(category,tag,default)
    return formats[fulltag(category,tag)] or default or "unknown message"
end

function interfaces.doifelsemessage(category,tag)
    return rawget(formats,fulltag(category,tag))
end

local splitter = lpeg.splitat(",")

function interfaces.showmessage(category,tag,arguments)
    local r = reporters[category]
    local f = formats[fulltag(category,tag)]
    local t = type(arguments)
    if t == "string" and #arguments > 0 then
        r(f,lpegmatch(splitter,arguments))
    elseif t == "table" then
        r(f,unpack(arguments))
    elseif arguments then
        r(f,arguments)
    else
        r(f)
    end
end

-- till here

function interfaces.setvariable(variable,given)
    variables[given] = variable
end

function interfaces.setconstant(constant,given)
    constants[given] = constant
end

function interfaces.setelement(element,given)
    elements[given] = element
end

-- the real thing:

logs.setmessenger(context.verbatim.ctxreport)

-- todo: use setmacro

function interfaces.setuserinterface(interface,response)
    sharedstorage.currentinterface, currentinterface = interface, interface
    sharedstorage.currentresponse, currentresponse = response, response
    if environment.initex then
        local setmacro        = false
     -- local setmacro        = interfaces.setmacro -- cleaner (but we need to test first)
        local nofconstants    = 0
        local nofvariables    = 0
        local nofelements     = 0
        local nofcommands     = 0
        local nofformats      = 0
        local noftranslations = 0
        local nofsetupstrings = 0
        --
        if setmacro then
            for given, constant in next, complete.constants do
                constant = constant[interface] or constant.en or given
                constants[constant] = given -- breedte -> width
                nofconstants = nofconstants + 1
                setmacro("c!"..given,given)
                if currentinterface ~= "en" then
                    setmacro("k!"..constant,given)
                end
            end
        else
            local t, f, s = { }, formatters["\\ui_c{%s}{%s}"], formatters["\\ui_s{%s}"]
            for given, constant in next, complete.constants do
                constant = constant[interface] or constant.en or given
                constants[constant] = given -- breedte -> width
                nofconstants = nofconstants + 1
                if given == constant then
                    t[nofconstants] = s(given)
                else
                    t[nofconstants] = f(given,constant)
                end
            end
            contextsprint(prtcatcodes,concat(t))
        end
        --
        if setmacro then
            for given, variable in next, complete.variables do
                variable = variable[interface] or variable.en or given
                variables[given] = variable -- ja -> yes
                nofvariables = nofvariables + 1
                setmacro("v!"..given,variable)
            end
        else
            local t, f = { }, formatters["\\ui_v{%s}{%s}"]
            for given, variable in next, complete.variables do
                variable = variable[interface] or variable.en or given
                variables[given] = variable -- ja -> yes
                nofvariables = nofvariables + 1
                t[nofvariables] = f(given,variable)
            end
            contextsprint(prtcatcodes,concat(t))
        end
        --
        if setmacro then
            for given, element in next, complete.elements do
                element = element[interface] or element.en or given
                elements[element] = given
                nofelements = nofelements + 1
                setmacro("e!"..given,element)
            end
        else
            local t, f = { }, formatters["\\ui_e{%s}{%s}"]
            for given, element in next, complete.elements do
                element = element[interface] or element.en or given
                elements[element] = given
                nofelements = nofelements + 1
                t[nofelements] = f(given,element)
            end
            contextsprint(prtcatcodes,concat(t))
        end
        --
        if setmacro then
            -- this can only work ok when we already have defined the command
            luatex.registerdumpactions(function()
                for given, command in next, complete.commands do
                    command = command[interface] or command.en or given
                    if command ~= given then
                        setmacro(prtcatcodes,given,"\\"..command)
                    end
                    nofcommands = nofcommands + 1
                end
            end)
        else
            local t, n, f = { }, 0, formatters["\\ui_m{%s}{%s}"]
            for given, command in next, complete.commands do
                command = command[interface] or command.en or given
                if command ~= given then
                    n = n + 1
                    t[n] = f(given,command)
                end
                nofcommands = nofcommands + 1
            end
            contextsprint(prtcatcodes,concat(t))
        end
        --
        for given, format in next, complete.messages.formats do
            formats[given] = format[interface] or format.en or given
            nofformats = nofformats + 1
        end
        --
        for given, translation in next, complete.messages.translations do
            translations[given] = translation[interface] or translation.en or given
            noftranslations = noftranslations + 1
        end
        --
        for given, setupstring in next, complete.setupstrings do
            setupstring = setupstring[interface] or setupstring.en or given
            setupstrings[given] = setupstring
            nofsetupstrings = nofsetupstrings + 1
        end
        --
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

interfaces.cachedsetups = interfaces.cachedsetups or { }
interfaces.hashedsetups = interfaces.hashedsetups or { }

local cachedsetups = interfaces.cachedsetups
local hashedsetups = interfaces.hashedsetups

storage.register("interfaces/cachedsetups", cachedsetups, "interfaces.cachedsetups")
storage.register("interfaces/hashedsetups", hashedsetups, "interfaces.hashedsetups")

function interfaces.cachesetup(t)
    local hash = serialize(t)
    local done = hashedsetups[hash]
    if done then
        return cachedsetups[done]
    else
        done = #cachedsetups + 1
        cachedsetups[done] = t
        hashedsetups[hash] = done
        return t
    end
end

function interfaces.interfacedcommand(name)
    local command = complete.commands[name]
    return command and command[currentinterface] or name
end

-- interface

function interfaces.writestatus(category,message)
    reporters[category](message) -- could also be a setmetatablecall
end

function interfaces.message(str)
    texio.write(str) -- overloaded
end

implement { name = "registernamespace",    actions = interfaces.registernamespace, arguments = { "integer", "string" } }
implement { name = "setinterfaceconstant", actions = interfaces.setconstant,       arguments = "2 strings" }
implement { name = "setinterfacevariable", actions = interfaces.setvariable,       arguments = "2 strings" }
implement { name = "setinterfaceelement",  actions = interfaces.setelement,        arguments = "2 strings" }
implement { name = "setinterfacemessage",  actions = interfaces.setmessage,        arguments = "3 strings" }
implement { name = "setinterfacemessages", actions = interfaces.setmessages,       arguments = "2 strings" }
implement { name = "showmessage",          actions = interfaces.showmessage,       arguments = "3 strings" }

implement {
    name      = "doifelsemessage",
    actions   = { interfaces.doifelsemessage, commands.doifelse },
    arguments = "2 strings",
}

implement {
    name      = "getmessage",
    actions   = { interfaces.getmessage, context },
    arguments = "3 strings",
}

implement {
    name      = "writestatus",
    overload  = true,
    actions   = interfaces.writestatus,
    arguments = "2 strings",
}

implement {
    name      = "message",
    overload  = true,
    actions   = interfaces.message,
    arguments = "string",
}

local function gss(s)
        contextsprint(vrbcatcodes,getsetupstring(s))
    end

implement { -- will b eoverloaded
    name      = "getsetupstring",
    actions   = gss,
    arguments = "string",
}

implement {
    name      = "rawsetupstring",
    actions   = gss,
    arguments = "string",
}


local function showassignerror(namespace,key,line)
    local ns, instance = match(namespace,"^(%d+)[^%a]+(%a*)")
    if ns then
        namespace = corenamespaces[tonumber(ns)] or ns
    end
    -- injected in the stream for timing:
    if instance and instance ~= "" then
        context.writestatus("setup",formatters["error in line %a, namespace %a, instance %a, key %a"](line,namespace,instance,key))
    else
        context.writestatus("setup",formatters["error in line %a, namespace %a, key %a"](line,namespace,key))
    end
end

implement {
    name      = "showassignerror",
    actions   = showassignerror,
    arguments = { "string", "string", "integer" },
}

-- a simple helper

local settings_to_hash = utilities.parsers.settings_to_hash

local makesparse = function(t)
    for k, v in next, t do
        if not v or v == "" then
            t[k] = nil
        end
    end
    return t
end

function interfaces.checkedspecification(specification)
    local kind = type(specification)
    if kind == "table" then
        return makesparse(specification)
    elseif kind == "string" and specification ~= "" then
        return makesparse(settings_to_hash(specification))
    else
        return { }
    end
end
