if not modules then modules = { } end modules ['mult-ini'] = {
    version   = 1.001,
    comment   = "companion to mult-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gmatch, match = string.format, string.gmatch, string.match
local lpegmatch = lpeg.match
local serialize = table.serialize

local context             = context
local commands            = commands

local allocate            = utilities.storage.allocate
local mark                = utilities.storage.mark
local prtcatcodes         = catcodes.numbers.prtcatcodes
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
interfaces.corenamespaces = mark(interfaces.corenamespaces or { })

local registerstorage     = storage.register
local sharedstorage       = storage.shared

local constants           = interfaces.constants
local variables           = interfaces.variables
local elements            = interfaces.elements
local formats             = interfaces.formats
local translations        = interfaces.translations
local corenamespaces      = interfaces.corenamespaces
local reporters           = { } -- just an optimization

registerstorage("interfaces/constants",      constants,      "interfaces.constants")
registerstorage("interfaces/variables",      variables,      "interfaces.variables")
registerstorage("interfaces/elements",       elements,       "interfaces.elements")
registerstorage("interfaces/formats",        formats,        "interfaces.formats")
registerstorage("interfaces/translations",   translations,   "interfaces.translations")
registerstorage("interfaces/corenamespaces", corenamespaces, "interfaces.corenamespaces")

interfaces.interfaces = {
    "cs", "de", "en", "fr", "it", "nl", "ro", "pe",
}

sharedstorage.currentinterface = sharedstorage.currentinterface or "en"
sharedstorage.currentresponse  = sharedstorage.currentresponse  or "en"

local currentinterface = sharedstorage.currentinterface
local currentresponse  = sharedstorage.currentresponse

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

function interfaces.registernamespace(n,namespace)
    corenamespaces[n] = namespace
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
    return formats[fulltag(category,tag)]
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

-- initialization

function interfaces.setuserinterface(interface,response)
    sharedstorage.currentinterface, currentinterface = interface, interface
    sharedstorage.currentresponse, currentresponse  = response, response
    if environment.initex then
        local nofconstants = 0
        for given, constant in next, complete.constants do
            constant = constant[interface] or constant.en or given
            constants[constant] = given -- breedte -> width
            contextsprint(prtcatcodes,"\\ui_c{",given,"}{",constant,"}") -- user interface constant
            nofconstants = nofconstants + 1
        end
        local nofvariables = 0
        for given, variable in next, complete.variables do
            variable = variable[interface] or variable.en or given
            variables[given] = variable -- ja -> yes
            contextsprint(prtcatcodes,"\\ui_v{",given,"}{",variable,"}") -- user interface variable
            nofvariables = nofvariables + 1
        end
        local nofelements = 0
        for given, element in next, complete.elements do
            element = element[interface] or element.en or given
            elements[element] = given
            contextsprint(prtcatcodes,"\\ui_e{",given,"}{",element,"}") -- user interface element
            nofelements = nofelements + 1
        end
        local nofcommands = 0
        for given, command in next, complete.commands do
            command = command[interface] or command.en or given
            if command ~= given then
                contextsprint(prtcatcodes,"\\ui_m{",given,"}{",command,"}") -- user interface macro
            end
            nofcommands = nofcommands + 1
        end
        local nofformats = 0
        for given, format in next, complete.messages.formats do
            formats[given] = format[interface] or format.en or given
            nofformats = nofformats + 1
        end
        local noftranslations = 0
        for given, translation in next, complete.messages.translations do
            translations[given] = translation[interface] or translation.en or given
            noftranslations = noftranslations + 1
        end
        report_interface("definitions: %a constants, %a variables, %a elements, %a commands, %a formats, %a translations",
            nofconstants,nofvariables,nofelements,nofcommands,nofformats,noftranslations)
    end
end

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

function interfaces.is_command(str)
    return (str and str ~= "" and token.csname_name(token.create(str)) ~= "") or false -- there will be a proper function for this
end

function interfaces.interfacedcommand(name)
    local command = complete.commands[name]
    return command and command[currentinterface] or name
end

-- interface

function commands.writestatus(category,message,...)
    local r = reporters[category]
    if r then
        r(message,...)
    end
end

commands.registernamespace    = interfaces.registernamespace
commands.setinterfaceconstant = interfaces.setconstant
commands.setinterfacevariable = interfaces.setvariable
commands.setinterfaceelement  = interfaces.setelement
commands.setinterfacemessage  = interfaces.setmessage
commands.setinterfacemessages = interfaces.setmessages
commands.showmessage          = interfaces.showmessage

function commands.doifelsemessage(category,tag)
    commands.doifelse(interfaces.doifelsemessage(category,tag))
end

function commands.getmessage(category,tag,default)
    context(interfaces.getmessage(category,tag,default))
end

function commands.showassignerror(namespace,key,line)
    local ns, instance = match(namespace,"^(%d+)[^%a]+(%a*)")
    if ns then
        namespace = corenamespaces[tonumber(ns)] or ns
    end
    if instance and instance ~= "" then
        context.writestatus("setup",formatters["error in line %a, namespace %a, instance %a, key %a"](line,namespace,instance,key))
    else
        context.writestatus("setup",formatters["error in line %a, namespace %a, key %a"](line,namespace,key))
    end
end

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
