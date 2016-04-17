if not modules then modules = { } end modules ['mtx-server-ctx-help'] = {
    version   = 1.001,
    comment   = "Basic Definition Browser",
    author    = "Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gsub, find, lower = string.gsub, string.find, string.lower
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
local setupstrings      = dofile(resolvers.findfile("mult-def.lua","tex")).setupstrings
local report            = logs.reporter("ctx-help")
local gettime           = os.gettimeofday or os.clock

local xmlcollected      = xml.collected
local xmlfirst          = xml.first
local xmltext           = xml.text
local xmlload           = xml.load

document        = document or { }
document.setups = document.setups or { }

local f_divs_t = {
    pe = formatters["<div dir='rtl' lang='arabic'>%s</div>"],
}

local f_spans_t = {
    pe = formatters["<span dir='rtl' lang='arabic'>%s</span>"]
}

local f_href_in_list_t = {
    tex = formatters[ [[<a class="setupmenuurl" href='mtx-server-ctx-help.lua?command=%s&mode=%s'>%s</a>]] ],
    lua = formatters[ [[<a class="setupmenuurl" href='mtx-server-ctx-help.lua?command=%s&mode=%s'>%s</a>]] ],
}

local f_href_as_command_t = {
    tex = formatters[ [[<a class="setuplisturl" href='mtx-server-ctx-help.lua?command=%s&mode=%s'>\%s</a>]] ],
    lua = formatters[ [[<a class="setuplisturl" href='mtx-server-ctx-help.lua?command=%s&mode=%s'>context.%s</a>]] ],
}

local s_modes_t = {
    tex = [[<a class="setupmodeurl" href='mtx-server-ctx-help.lua?mode=lua'>lua mode</a>]],
    lua = [[<a class="setupmodeurl" href='mtx-server-ctx-help.lua?mode=tex'>tex mode</a>]],
}

local f_interface  = formatters[ [[<a href='mtx-server-ctx-help.lua?interface=%s&mode=%s'>%s</a>]] ]
local f_source     = formatters[ [[<a href='mtx-server-ctx-help.lua?source=%s&mode=%s'>%s</a>]] ]
local f_keyword    = formatters[ [[<tr><td width='15%%'>%s</td><td width='85%%' colspan='2'>%s</td></tr>]] ]
local f_parameter  = formatters[ [[<tr><td width='15%%'>%s</td><td width='15%%'>%s</td><td width='70%%'>%s</td></tr>]] ]
local f_parameters = formatters[ [[<table width='100%%'>%s</table>]] ]
local f_listing    = formatters[ [[<pre><t>%s</t></listing>]] ]
local f_special    = formatters[ [[<i>%s</i>]] ]
local f_url        = formatters[ [[<tr><td width='15%%'>%s</td><td width='85%%' colspan='2'><i>%s</i>: %s</td></tr>]] ]
local f_default    = formatters[ [[<u>%s</u>]] ]

local function translate(tag,int,noformat) -- to be checked
    local translation = setupstrings[tag]
    local translated  = translation and (translation[tag] or translation[tag]) or tag
    if noformat then
        return translated
    else
        return f_special(translated)
    end
end

local function translated(e,int) -- to be checked
    local attributes = e.at
    local s   = attributes.type or "?"
    if find(s,"^cd:") then
        local t = setupstrings[s]
        local f = t and (t[int] or t.en) or s
        if attributes.default == "yes" then
            return f_default(f)
        elseif tag then
            return f_default(f)
        else
            return f
        end
    else
        if attributes.default == "yes" then
            return f_default(translate(s,int) or "?")
        elseif tag then
            return translate(s,int)
        else
            return s
        end
    end
end

local function makename(e) -- to be checked
    local at   = e.at
    local name = at.name
    if at.type == 'environment' then
        name = "start" .. name -- todo: elements.start
    end
    if at.variant then
        name = name .. ":" .. at.variant
    end
    if at.generated == "yes" then
        name = name .. "*"
    end
    return lower(name)
end

local function csname(e,int) -- to be checked
    local cs = ""
    local at = e.at
    if at.type == 'environment' then
        cs = "start" .. cs -- todo: elements.start
    end
    local f = xmlfirst(e,'cd:sequence/(cd:string|variable)')
    if f then
        if f.tg == "string" then
            cs = cs .. f.at.value
        else
            cs = cs .. f.at.value -- to be translated
        end
    else
        cs = cs .. at.name
    end
    return cs
end

local function getnames(root)
    local found = { }
    local names = { }
    for e in xmlcollected(root,'cd:command') do
        local name   = e.at.name
        local csname = csname(e,int)
        if not found[csname] then
            names[#names+1] = { name, csname }
            found[csname] = name
        else
            -- variant
        end
    end
    sort(names, function(a,b) return lower(a[2]) < lower(b[2]) end)
    return names
end

local function getdefinitions(root)
    local definitions = { }
    for e in xmlcollected(root,"cd:define") do
        definitions[e.at.name] = e
    end
    return definitions
end

local loaded = setmetatableindex(function(loaded,interface)
    local starttime = gettime()
    local filename  = formatters["context-%s.xml"](interface)
    local fullname  = resolvers.findfile(filename) or ""
    local current   = false
    if fullname ~= "" then
        local root = xmlload(fullname)
        if root then
            current = {
                intercace   = interface,
                filename    = filename,
                fullname    = fullname,
                root        = root,
                names       = getnames(root),
                definitions = getdefinitions(root),
            }
        end
    end
    if current then
        report("data file %a loaded for interface %a in %0.3f seconds",filename,interface,gettime()-starttime)
    else
        report("no valid interface file for %a",interface)
    end
    loaded[filename] = current
    return current
end)

local function collect(current,name,int,lastmode)
    local list = { }
    for command in xmlcollected(current.root,formatters["cd:command[@name='%s']"](name)) do
        local attributes = command.at or { }
        local data = {
            command  = command,
            category = attributes.category or "",
            source   = attributes.file and f_source(attributes.file,lastmode,attributes.file) or ""
        }

        local sequence  = { }
        local tags      = { }
        local arguments = { }
        local tag       = ""

        local generated   = attributes.generated == "yes"
        local environment = attributes.type      == "environment"

        -- first pass: construct the top line

        local start   = environment and (attributes["begin"] or "start") or "" -- elements.start
        local stop    = environment and (attributes["end"]   or "stop" ) or "" -- elements.stop
        local name    = attributes.name
        local valid   = true
        local texmode = lastmode == "tex"

        local first = xmlfirst(command,"/sequence")

        if first then
            name = xmltext(xmlfirst(first))
        end

        -- translate name

        local function process(e)
            for e in xmlcollected(e,"/*") do
                if not e.special then
                    local tag        = e.tg
                    local attributes = e.at
                    if tag == "resolve" then
                        local resolved = current.definitions[e.at.name or ""]
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
                                okay = setupstrings["cd:" .. delimiters .. (list and "-l" or "-s")]
                            elseif tag == "assignments" then
                             -- todo = optional
                                okay = setupstrings["cd:assignment" .. delimiters .. (list and "-l" or "-s")]
                            elseif tag == "delimiter" then
                                tag = "\\" .. attributes.name
                            elseif tag == "string" then
                                tag = attributes.value
                            else
                             -- todo = optional
                                okay = setupstrings["cd:" .. tag .. (list and "-l" or "-s")]
                                    or setupstrings["cd:" .. tag]
                            end
                            if okay then
                                tag = okay.en or tag
                            end
                        else
                            local okay
                            if tag == "keywords" then
                             -- todo = optional
                                okay = setupstrings["cd:" .. delimiters .. (list and "-l" or "-s")]
                            elseif tag == "assignments" then
                             -- todo = optional
                                okay = setupstrings["cd:assignment" .. delimiters .. (list and "-l" or "-s")]
                            elseif tag == "delimiter" then
                                okay = false
                            elseif tag == "string" then
                                okay = false
                            else
                             -- todo = optional
                                okay = setupstrings["cd:" .. tag .. (list and "-l" or "-s")]
                                    or setupstrings["cd:" .. tag]
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

            data.sequence = concat(sequence," ")

            -- second pass: construct the descriptions

            local parameters = { }
            local n          = 0

            local function process(e)
                for e in xmlcollected(e,"/*") do
                    local tag = e.tg

                    if tag == "resolve" then

                        local resolved = current.definitions[e.at.name or ""]
                        if resolved then
                            process(resolved)
                        end

                    elseif tag == "keywords" then

                        n = n + 1
                        local left  = tags[n]
                        local right = { }

                        local function processkeyword(e)
                            right[#right+1] = translated(e,int)
                        end

                        for e in xmlcollected(e,"/*") do
                            if not e.special then
                                local tag = e.tg
                                if tag == "resolve" then
                                    local resolved = current.definitions[e.at.name or ""]
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
                                        local resolved = current.definitions[e.at.name or ""]
                                        if resolved then
                                            processparameter(resolved,right)
                                        end
                                    elseif tag == "constant" then
                                        right[#right+1] = translated(e,int)
                                    else
                                        right[#right+1] = "PARAMETER TODO"
                                    end
                                end
                            end
                        end

                        for e in xmlcollected(e,"/*") do
                            if not e.special then
                                local tag   = e.tg
                                local left  = e.at.name or "?"
                                local right = { }
                                if tag == "resolve" then
                                    local resolved = current.definitions[e.at.name or ""]
                                    if resolved then
                                        -- todo
                                        process(resolved)
                                    end
                                elseif tag == "inherit" then
                                    local name = e.at.name or "?"
                                    local url  = f_href_as_command_t[lastmode](name,lastmode,name)
                                    parameters[#parameters+1] = f_url(what,translate("inherits",int),url)
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
                        local right = setupstrings["cd:"..tag]

                        if right then
                            right = uppercase(right[int] or right.en or tag)
                        end

                        parameters[#parameters+1] = f_keyword(left,right)

                    end
                end
            end

            for e in xmlcollected(command,"/cd:arguments") do
                process(e)
            end

            data.parameters = parameters
        else
            if texmode then
                data.sequence = formatters["unsupported command '%s%s'"](start or "",name)
            else
                data.sequence = formatters["unsupported function '%s%s'"](start or "",name)
            end
            data.parameters = { }
        end

        data.mode = s_modes_t[lastmode or "tex"]
        list[#list+1] = data

    end
    return list
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

local what = { "environment", "category", "source", "mode" }

local function generate(configuration,filename,hashed)

    local start   = gettime()
    local detail  = hashed.queries or { }

    if detail then

        local lastinterface = detail.interface or "en"
        local lastcommand   = detail.command   or ""
        local lastsource    = detail.source    or ""
        local lastmode      = detail.mode      or "tex"

        local current       = loaded[lastinterface]

        lastcommand = gsub(lastcommand,"%s*^\\*(.+)%s*","%1")

        local f_div  = f_divs_t[lastinterface]
        ----- f_span = f_spans[lastinterface]

        local names = current.names
        local refs  = { }
        local ints  = { }

        for k=1,#names do
            local v = names[k]
            refs[k] = f_href_in_list_t[lastmode](v[1],lastmode,v[2])
        end

        if lastmode ~= "lua" then
            local sorted = sortedkeys(interfaces)
            for k=1,#sorted do
                local v = sorted[k]
                ints[k] = f_interface(interfaces[v],lastmode,v)
            end
        end

        local n = concat(refs,"<br/>")
        local i = concat(ints,"<br/><br/>")

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
            variables.extra = "mode: " .. s_modes_t.tex .. " " .. s_modes_t.lua

        elseif lastcommand and lastcommand ~= "" then

            local list = collect(current,lastcommand,lastinterface,lastmode)
            if list and #list > 0 then
                local data  = list[1]
                local extra = { }
                for k=1,#what do
                    local v = what[k]
                    if data[v] and data[v] ~= "" then
                        lmx.set(v, data[v])
                        extra[#extra+1] = v .. ": " .. data[v]
                    end
                end
                variables.maintitle = data.sequence
                variables.maintext  = f_parameters(concat(data.parameters))
                variables.extra     = concat(extra,"&nbsp;&nbsp;&nbsp;")
            else
                variables.maintitle = "no command"
                variables.maintext  = "select command"
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
