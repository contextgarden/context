if not modules then modules = { } end modules ['mtx-server-ctx-help'] = {
    version   = 1.001,
    comment   = "Basic Definition Browser",
    author    = "Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gsub, find, lower, match = string.gsub, string.find, string.lower, string.match
local concat, sort = table.concat, table.sort

dofile(resolvers.findfile("trac-lmx.lua","tex"))
dofile(resolvers.findfile("util-sci.lua","tex"))
dofile(resolvers.findfile("char-def.lua","tex"))
dofile(resolvers.findfile("char-ini.lua","tex"))
dofile(resolvers.findfile("char-utf.lua","tex"))

local scite             = utilities.scite
local formatters        = string.formatters
local sortedkeys        = table.sortedkeys
local setmetatableindex = table.setmetatableindex
local lowercase         = characters.lower
local uppercase         = characters.upper
local interfaces        = dofile(resolvers.findfile("mult-def.lua","tex"))
local i_setupstrings    = interfaces.setupstrings
local i_commands        = interfaces.commands
local i_variables       = interfaces.variables
local i_constants       = interfaces.constants
local i_elements        = interfaces.elements
local report            = logs.reporter("ctx-help")
local gettime           = os.gettimeofday or os.clock

local xmlcollected      = xml.collected
local xmlfirst          = xml.first
local xmltext           = xml.text
local xmlload           = xml.load

document                = document or { }
document.setups         = document.setups or { }

local usedsetupfile     = resolvers.findfile("i-context.xml") or ""
local usedsetuproot     = usedsetupfile ~= "" and xmlload(usedsetupfile) or false
local useddefinitions   = { }

if usedsetuproot then
    report("main file loaded: %s",usedsetupfile)
    xml.include(usedsetuproot,"cd:interfacefile","filename",true,function(s)
        local fullname =  resolvers.findfile(s)
        if fullname and fullname ~= "" then
            report("inclusion loaded: %s",fullname)
            return io.loaddata(fullname)
        end
    end)
else
    report("no main file")
    return false, false
end

local defaultinterface  = "en"

-- todo: store mode|interface in field but then we need post

for e in xmlcollected(usedsetuproot,"cd:define") do
    useddefinitions[e.at.name] = e
end

for e in xml.collected(usedsetuproot,"cd:interface/cd:interface") do
    e.at.file = e.__f__ -- nicer
end

local f_divs_t = {
    pe = formatters["<div dir='rtl' lang='arabic'>%s</div>"],
}

local f_spans_t = {
    pe = formatters["<span dir='rtl' lang='arabic'>%s</span>"]
}

local f_href_in_list_t = {
    tex = formatters["<a class='setupmenuurl' href='mtx-server-ctx-help.lua?interface=%s&command=%s&mode=%s'>%s</a>"],
    lua = formatters["<a class='setupmenuurl' href='mtx-server-ctx-help.lua?interface=%s&command=%s&mode=%s'>%s</a>"],
}

local f_href_in_list_i = {
    tex = formatters["<a class='setupmenucmd' href='mtx-server-ctx-help.lua?interface=%s&command=%s&mode=%s' id='#current'>%s</a>"],
    lua = formatters["<a class='setupmenucmd' href='mtx-server-ctx-help.lua?interface=%s&command=%s&mode=%s' id='#current'>%s</a>"],
}

local f_href_as_command_t = {
    tex = formatters["<a class='setuplisturl' href='mtx-server-ctx-help.lua?interface=%s&command=%s&mode=%s'>\\%s</a>"],
    lua = formatters["<a class='setuplisturl' href='mtx-server-ctx-help.lua?interface=%s&command=%s&mode=%s'>context.%s</a>"],
}

local f_modes_t = {
    tex = formatters["<a class='setupmodeurl' href='mtx-server-ctx-help.lua?interface=%s&mode=lua'>lua mode</a>"],
    lua = formatters["<a class='setupmodeurl' href='mtx-server-ctx-help.lua?interface=%s&mode=tex'>tex mode</a>"],
}

local f_views_t = {
    groups = formatters["<a class='setupviewurl' href='mtx-server-ctx-help.lua?interface=%s&view=names'>names</a>"],
    names  = formatters["<a class='setupviewurl' href='mtx-server-ctx-help.lua?interface=%s&view=groups'>groups</a>"],
}

local f_interface   = formatters["<a href='mtx-server-ctx-help.lua?interface=%s&command=%s&mode=%s'>%s</a>"]
local f_source      = formatters["<a href='mtx-server-ctx-help.lua?interface=%s&command=%s&source=%s&mode=%s'>%s</a>"]
local f_keyword     = formatters[" <tr>\n  <td width='15%%'>%s</td>\n  <td width='85%%' colspan='2'>%s</td>\n </tr>\n"]
local f_parameter   = formatters[" <tr>\n  <td width='15%%'>%s</td>\n  <td width='15%%'>%s</td>\n  <td width='70%%'>%s</td>\n </tr>\n"]
local f_url         = formatters[" <tr>\n  <td width='15%%'>%s</td>\n  <td width='85%%' colspan='2'><i>%s</i>: %s</td>\n </tr>\n"]
local f_parameters  = formatters["\n<table width='100%%'>\n%s</table>\n"]
local f_instance    = formatters["<tt>%s</tt>"]
local f_instances   = formatters["\n<div class='setupinstances'><b>predefined instances</b>:&nbsp;%s</div>\n"]
local f_listing     = formatters["<pre><t>%s</t></pre>"]
local f_special     = formatters["<i>%s</i>"]
local f_default     = formatters["<u>%s</u>"]
local f_group       = formatters["<div class='setupmenugroup'>\n<div class='setupmenucategory'>%s</div>%s</div>"]

-- replace('cd:string',    'value',   i_commands, i_elements)
-- replace('cd:variable' , 'value',   i_variables)
-- replace('cd:parameter', 'name',    i_constants)
-- replace('cd:constant',  'type',    i_variables)
-- replace('cd:constant',  'default', i_variables)
-- replace('cd:variable',  'type',    i_variables)
-- replace('cd:inherit',   'name',    i_commands, i_elements)

local function translate(tag,interface,noformat) -- to be checked
    local translation = i_setupstrings[tag]
    local translated  = translation and (translation[interface] or translation[interface]) or tag
    if noformat then
        return translated
    else
        return f_special(translated)
    end
end

local function translatedparameter(e,interface)
    local attributes = e.at
    local s = attributes.type or "?"
    if find(s,"^cd:") then
        local t = i_setupstrings[s]
        local f = t and (t[interface] or t.en) or s
        return f
    else
        local t = i_variables[s]
        local f = t and (t[interface] or t.en) or s
        return f
    end
end

local function translatedkeyword(e,interface)
    local attributes = e.at
    local s = attributes.type or "?"
    if find(s,"^cd:") then
        local t = i_setupstrings[s]
        local f = t and (t[interface] or t.en) or s
        return f
    else
        local t = i_variables[s]
        local f = t and (t[interface] or t.en) or s
        if attributes.default == "yes" then
            return f_default(f)
        else
            return f
        end
    end
end

local function translatedvariable(s,interface)
    local t = i_variables[s]
    return t and (t[interface] or t.en) or s
end

local function translatedconstant(s,interface) -- cache
    local t = i_constants[s]
    return t and (t[interface] or t.en) or s
end

local function translatedelement(s,interface) -- cache
    local t = i_elements[s]
    return t and (t[interface] or t.en) or s
end

local function translatedstring(s,interface) -- cache
    local t = i_commands[s]
    if t then
        t = t[interface] or t.en
    end
    if t then
        return t
    end
    t = i_elements[s]
    return t and (t[interface] or t.en) or s
end

local function translatedcommand(s,interface) -- cache
    local t = i_commands[s]
    return t and (t[interface] or t.en) or s
end

local function makeidname(e)
    local at   = e.at
    local name = at.name
    if at.type == 'environment' then
        name = name .. ":environment"
    end
    if at.generated == "yes" then
        name = name .. ":generated"
    end
    if at.variant then
        name = name .. ":" .. at.variant
    end
    return lower(name)
end

local function makecsname(e,interface,prefix) -- stop ?
    local cs = ""
    local at = e.at
    local ok = false
    local en = at.type == 'environment'
    if prefix and en then
        cs = translatedelement("start",interface)
    end
    for f in xmlcollected(e,'cd:sequence/(cd:string|cd:variable)') do -- always at the start
        local tag = f.tg
        local val = f.at.value or ""
        if tag == "string" then
            cs = cs .. translatedstring(val,interface)
        elseif tag == "variable" then
            cs = cs .. f_special(translatedconstant("name",interface))
        else -- can't happen
            cs = cs .. val
        end
        ok = true
    end
    if not ok then
        if en then
            cs = cs .. translatedstring(at.name,interface)
        else
            cs = cs .. translatedcommand(at.name,interface)
        end
    end
    return cs
end

local function getnames(root,interface)
    local found  = { }
    local names  = { }
    local groups = { }
    local extra  = { }
    for e in xmlcollected(root,'cd:interface/cd:interface') do
        local category = match(e.at.file or "","^i%-(.*)%.xml$")
        local list     = { }
        for e in xmlcollected(e,'cd:command') do
            local idname = makeidname(e)
            local csname = makecsname(e,interface,true)
            if not found[idname] then
                local t = { idname, csname }
                names[#names+1] = t
                list[#list+1]   = t
                found[idname]   = e
                extra[csname]   = e
            else
                -- variant
            end
        end
        if #list > 0 then
            sort(list, function(a,b) return lower(a[2]) < lower(b[2]) end)
            groups[#groups+1] = { category, list }
        end

    end
    sort(names,  function(a,b) return lower(a[2]) < lower(b[2]) end)
    sort(groups, function(a,b) return lower(a[1]) < lower(b[1]) end)
    return names, groups, found, extra
end

local loaded = setmetatableindex(function(loaded,interface)
    local names, groups, found, extra = getnames(usedsetuproot,interface)
    local current = {
        interface   = interface,
        root        = usedsetuproot,
        definitions = useddefinitions,
        names       = names,
        groups      = groups,
        found       = found,
        extra       = extra,
    }
    loaded[interface] = current
    return current
end)

local function collect(current,name,interface,lastmode)
    local command = current.found[name] or current.extra[name]
    if command then
        local definitions = current.definitions
        local attributes  = command.at or { }
        local generated   = attributes.generated == "yes"
        local environment = attributes.type      == "environment"
        local sequence    = { }
        local tags        = { }
        local arguments   = { }
        local parameters  = { }
        local instances   = { }
        local tag         = ""
        local category    = attributes.category or ""
        local source      = attributes.file and f_source(lastinterface,lastcommand,attributes.file,lastmode,attributes.file) or ""

        -- first pass: construct the top line

        local start   = environment and (attributes["begin"] or translatedelement("start",interface)) or ""
        local stop    = environment and (attributes["end"]   or translatedelement("stop" ,interface)) or ""
        local name    = makecsname(command,interface) -- we can use the stored one
        local valid   = true
        local texmode = lastmode == "tex"

        local function process(e)
            for e in xmlcollected(e,"/*") do
                if not e.special then
                    local tag        = e.tg
                    local attributes = e.at
                    if tag == "resolve" then
                        local resolved = definitions[e.at.name or ""]
                        if resolved then
                           process(resolved)
                        end
                    else
                    -- we need a 'lua' tag i.e. we only support a subset of string/table
                        local delimiters = attributes.delimiters or "brackets"
                        local optional   = attributes.optional == "yes"
                        local list       = attributes.list     == "yes"
                        if texmode then
                            local okay
                            if tag == "keywords" then
                             -- todo = optional
                                okay = i_setupstrings["cd:" .. delimiters .. (list and "-l" or "-s")]
                            elseif tag == "assignments" then
                             -- todo = optional
                                okay = i_setupstrings["cd:assignment" .. delimiters .. (list and "-l" or "-s")]
                            elseif tag == "delimiter" then
                                tag = "\\" .. attributes.name
                            elseif tag == "string" then
                                tag = translatedstring(attributes.value,interface)
                            else
                             -- todo = optional
                                okay = i_setupstrings["cd:" .. tag .. (list and "-l" or "-s")]
                                    or i_setupstrings["cd:" .. tag]
                            end
                            if okay then
                                tag = okay.en or tag
                            end
                        else
                            local okay
                            if tag == "keywords" then
                             -- todo = optional
                                okay = i_setupstrings["cd:" .. delimiters .. (list and "-l" or "-s")]
                            elseif tag == "assignments" then
                             -- todo = optional
                                okay = i_setupstrings["cd:assignment" .. delimiters .. (list and "-l" or "-s")]
                            elseif tag == "delimiter" then
                                okay = false
                            elseif tag == "string" then
                                okay = false
                            else
                             -- todo = optional
                                okay = i_setupstrings["cd:" .. tag .. (list and "-l" or "-s")]
                                    or i_setupstrings["cd:" .. tag]
                            end
                            if okay then
                                local luatag = okay.lua
                                if luatag then
                                   tag = luatag
                                else
                                    tag   = "unsupported"
                                    valid = false
                                end
                            else
                                tag   = "unsupported"
                                valid = false
                            end
                        end
                        if tag then
                            sequence[#sequence+1] = tag
                            tags[#tags+1] = tag
                        end
                    end
                end
           end
        end

        if start and start ~= "" then
            if texmode then
                sequence[#sequence+1] = formatters["\\%s%s"](start,name)
            else
                sequence[#sequence+1] = formatters["context.%s%s("](start,name)
            end
        else
            if texmode then
                sequence[#sequence+1] = formatters["\\%s"](name)
            else
                sequence[#sequence+1] = formatters["context.%s("](name)
            end
        end

        for e in xmlcollected(command,"/cd:arguments") do
            process(e)
        end

        if texmode then
            if stop and stop ~= "" then
                sequence[#sequence+1] = "\\" .. stop .. name
            end
        else
            for i=2,#sequence-1 do
                sequence[i] = sequence[i] .. ", "
            end

            if stop and stop ~= "" then
                sequence[#sequence+1] = formatters[") context.%s%s()"](stop,name)
            else
                sequence[#sequence+1] = ")"
            end
        end

        if valid then

            sequence = concat(sequence," ")

            -- second pass: construct the descriptions

            local n          = 0

            local function process(e)
                for e in xmlcollected(e,"/*") do
                    local tag = e.tg

                    if tag == "resolve" then

                        local resolved = definitions[e.at.name or ""]
                        if resolved then
                            process(resolved)
                        end

                    elseif tag == "keywords" then

                        n = n + 1
                        local left  = tags[n]
                        local right = { }

                        local function processkeyword(e)
                            right[#right+1] = translatedkeyword(e,interface)
                        end

                        for e in xmlcollected(e,"/*") do
                            if not e.special then
                                local tag = e.tg
                                if tag == "resolve" then
                                    local resolved = definitions[e.at.name or ""]
                                    if resolved then
                                        processkeyword(resolved)
                                    end
                                elseif tag == "constant" then
                                    processkeyword(e)
                                else
                                    right[#right+1] = "KEYWORD TODO"
                                end
                            end
                        end
                        parameters[#parameters+1] = f_keyword(left,concat(right, ", "))

                    elseif tag == "assignments" then

                        n = n + 1
                        local what = tags[n]
                        local done = false

                        local function processparameter(e,right)
                            for e in xmlcollected(e,"/*") do
                                if not e.special then
                                    local tag = e.tg
                                    if tag == "resolve" then
                                        local resolved = definitions[e.at.name or ""]
                                        if resolved then
                                            processparameter(resolved,right)
                                        end
                                    elseif tag == "constant" then
                                        right[#right+1] = translatedparameter(e,interface)
                                    else
                                        right[#right+1] = "PARAMETER TODO"
                                    end
                                end
                            end
                        end

                        for e in xmlcollected(e,"/*") do
                            if not e.special then
                                local tag   = e.tg
                                local left  = translatedconstant(e.at.name,interface)
                                local right = { }
                                if tag == "resolve" then
                                    local resolved = definitions[e.at.name or ""]
                                    if resolved then
                                        -- todo
                                        process(resolved)
                                    end
                                elseif tag == "inherit" then
                                    local name = e.at.name or "?"
                                    local url  = f_href_as_command_t[lastmode](lastinterface,name,lastmode,name)
                                    parameters[#parameters+1] = f_url(what,translate("cd:inherits",interface),url)
                                elseif tag == "parameter" then
                                    processparameter(e,right)
                                    parameters[#parameters+1] = f_parameter(what,left,concat(right, ", "))
                                else
                                    parameters[#parameters+1] = "PARAMETER TODO"
                                end
                                if not done then
                                    done = true
                                    what = ""
                                end
                            end
                        end

                        what = ""
                    else

                        n = n + 1
                        local left  = tags[n]
                        local right = i_setupstrings["cd:"..tag]

                        if right then
                            right = uppercase(right[interface] or right.en or tag)
                        end

                        parameters[#parameters+1] = f_keyword(left,right)

                    end
                end
            end

            for e in xmlcollected(command,"/cd:arguments") do
                process(e)
            end

        else
            if texmode then
                sequence = formatters["unsupported command '%s%s'"](start or "",name)
            else
                sequence = formatters["unsupported function '%s%s'"](start or "",name)
            end
            parameters = { }
        end


        for e in xmlcollected(command,"/cd:instances/cd:constant") do
            instances[#instances+1] = f_instance(translatedconstant(e.at.value or "?",interface))
        end

        return {
            category   = category,
            source     = source,
            mode       = f_modes_t[lastmode or "tex"](lastinterface),
            view       = f_views_t[lastview or "groups"](lastinterface),
            sequence   = sequence,
            parameters = parameters,
            instances  = instances,
        }
    end
end

-- -- --

local interfaces = {
    czech    = 'cz',
    dutch    = 'nl',
    english  = 'en',
    french   = 'fr',
    german   = 'de',
    italian  = 'it',
    persian  = 'pe',
    romanian = 'ro',
}

local variables = {
    ['color-background-main-left']  = '#3F3F3F',
    ['color-background-main-right'] = '#5F5F5F',
    ['color-background-one']        = lmx.get('color-background-green'),
    ['color-background-two']        = lmx.get('color-background-blue'),
    ['title']                       = 'ConTeXt Help Information',
}

local what = { "environment", "category", "source", "mode", "view" }

local function generate(configuration,filename,hashed)

    local start     = gettime()
    local detail    = hashed.queries or { }
    local variables = setmetatableindex({},variables)

    if detail then
        local lastinterface = detail.interface or defaultinterface or "en"
        local lastcommand   = detail.command   or ""
        local lastview      = detail.view      or "groups"
        local lastsource    = detail.source    or ""
        local lastmode      = detail.mode      or "tex"

        local current       = loaded[lastinterface]

        local title         = variables.title .. ": " .. lastinterface
        variables.title     = title

        lastcommand = gsub(lastcommand,"%s*^\\*(.+)%s*","%1")

        local f_div  = f_divs_t[lastinterface]
        ----- f_span = f_spans[lastinterface]

        local names  = current.names
        local groups = current.groups
        local refs   = { }
        local ints   = { }

        local function addnames(names)
            local target = { }
            for k=1,#names do
                local namedata = names[k]
                local command  = namedata[1]
                local text     = namedata[2]
                if command == lastcommand then
                    target[#target+1] = f_href_in_list_i[lastmode](lastinterface,command,lastmode,text)
                else
                    target[#target+1] = f_href_in_list_t[lastmode](lastinterface,command,lastmode,text)
                end
            end
            return concat(target,"<br/>\n")
        end

        if lastview == "groups" then
            local target = { }
            for i=1,#groups do
                local group = groups[i]
                target[#target+1] = f_group(group[1],addnames(group[2]))
            end
            refs = concat(target,"<br/>\n")
        else
            refs = addnames(names)
        end

        if lastmode ~= "lua" then
            local sorted = sortedkeys(interfaces)
            for k=1,#sorted do
                local v = sorted[k]
                ints[k] = f_interface(interfaces[v],lastcommand,lastmode,v)
            end
        end

        local n = refs
        local i = concat(ints,"<br/><br/>\n")

        if f_div then
            variables.names      = f_div(n)
            variables.interfaces = f_div(i)
        else
            variables.names      = n
            variables.interfaces = i
        end

        -- we only support mkiv

        if lastsource and lastsource ~= "" then

            local name = lastsource
            local full = resolvers.findfile(name)
            if full == "" and file.suffix(lastsource) == "tex" then
                name = file.replacesuffix(lastsource,"mkiv")
                full = resolvers.findfile(name)
                if full  == "" then
                    name = file.replacesuffix(lastsource,"mkvi")
                    full = resolvers.findfile(name)
                end
            end
            if full == "" then
                variables.maintitle = lastsource
                variables.maintext  = f_listing("no source found")
            else
                local data = io.loaddata(full)
                data = scite.html(data,file.suffix(full),true)
                variables.maintitle = name
                variables.maintext  = f_listing(data)
            end
            lastsource      = ""
            variables.extra = "mode: " .. f_modes_t.tex(lastinterface) .. " " .. f_modes_t.lua(lastinterface)

        elseif lastcommand and lastcommand ~= "" then

            local data  = collect(current,lastcommand,lastinterface,lastmode)
            if data then
                local extra = { }
                for k=1,#what do
                    local v = what[k]
                    if data[v] and data[v] ~= "" then
                        lmx.set(v, data[v])
                        extra[#extra+1] = v .. ": " .. data[v]
                    end
                end
                local instances     = data.instances
                variables.maintitle = data.sequence
                variables.maintext  = f_parameters(concat(data.parameters)) .. (#instances > 0 and f_instances(concat(instances,",&nbsp;")) or "")
                variables.extra     = concat(extra,"&nbsp;&nbsp;&nbsp;")
            else
                variables.maintitle = "no definition"
                variables.maintext  = ""
                variables.extra     = ""
            end
        else
            variables.maintitle = "no definition"
            variables.maintext  = ""
            variables.extra     = ""
        end

    else

        variables.maintitle = "no definition"
        variables.maintext  = "some error"
        variables.extra     = ""

    end

    local content = lmx.convert('context-help.lmx',false,variables)

    report("time spent on building page: %0.03f seconds",gettime()-start)

    return { content = content }
end

return generate, true
