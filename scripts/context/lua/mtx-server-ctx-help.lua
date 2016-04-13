if not modules then modules = { } end modules ['mtx-server-ctx-help'] = {
    version   = 1.001,
    comment   = "Basic Definition Browser",
    author    = "Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo in lua interface: noargument, oneargument, twoarguments, threearguments
-- todo: pickup translations from mult file

dofile(resolvers.findfile("trac-lmx.lua","tex"))
dofile(resolvers.findfile("util-sci.lua","tex"))

local scite = utilities.scite

local setupstrings = dofile(resolvers.findfile("mult-def.lua","tex")).setupstrings

-- problem ... serialize parent stack

local format, match, gsub, find, lower = string.format, string.match, string.gsub, string.find, string.lower
local concat, sort = table.concat, table.sort

local formatters = string.formatters

local report = logs.reporter("ctx-help")

-- -- -- make this a module: cont-xx.lua

document = document or { }
document.setups = document.setups or { }

document.setups.div = {
    pe = "<div dir='rtl' lang='arabic'>%s</div>"
}

document.setups.span = {
    pe = "<span dir='rtl' lang='arabic'>%s</span>"
}

document.setups.translations = table.setmetatableindex(setupstrings, {
    ["noargument"]     = { en = "\\cs" },
    ["oneargument"]    = { en = "\\cs#1{..}" },
    ["twoarguments"]   = { en = "\\cs#1#2{..}{..}" },
    ["threearguments"] = { en = "\\cs#1#2#3{..}{..}{..}" },
})

document.setups.formats = {
    open_command    = {
        tex = [[\%s]],
        lua = [[context.%s (]],
    },
    close_command   = {
        tex = [[]],
        lua = [[ )]],
    },
    connector       = {
        tex = [[]],
        lua = [[, ]],
    },
    href_in_list    = {
        tex = [[<a href='mtx-server-ctx-help.lua?command=%s&mode=%s'>%s</a>]],
        lua = [[<a href='mtx-server-ctx-help.lua?command=%s&mode=%s'>%s</a>]],
    },
    href_as_command = {
        tex = [[<a href='mtx-server-ctx-help.lua?command=%s&mode=%s'>\%s</a>]],
        lua = [[<a href='mtx-server-ctx-help.lua?command=%s&mode=%s'>context.%s</a>]],
    },
    modes           = {
        tex = [[<a href='mtx-server-ctx-help.lua?mode=lua'>lua mode</a>]],
        lua = [[<a href='mtx-server-ctx-help.lua?mode=tex'>tex mode</a>]],
    },
    optional_single = {
        tex = "[optional string %s]",
        lua = "{optional string %s}",
    },
    optional_list   = {
        tex = "[optional list %s]",
        lua = "{optional table %s}" ,
    } ,
    mandate_single  = {
        tex = "[mandate string %s]",
        lua = "{mandate string %s}",
    },
    mandate_list    = {
        tex = "[mandate list %s]",
        lua = "{mandate list %s}",
    },
    interface       = [[<a href='mtx-server-ctx-help.lua?interface=%s&mode=%s'>%s</a>]],
    source          = [[<a href='mtx-server-ctx-help.lua?source=%s&mode=%s'>%s</a>]],
    parameter       = [[<tr><td width='15%%'>%s</td><td width='15%%'>%s</td><td width='70%%'>%s</td></tr>]],
    parameters      = [[<table width='100%%'>%s</table>]],
    listing         = [[<pre><t>%s</t></listing>]],
    special         = [[<i>%s</i>]],
    default         = [[<u>%s</u>]],
}

local function translate(tag,int,noformat)
    local formats      = document.setups.formats
    local translations = document.setups.translations
    local translation  = translations[tag]
    local translated   = translation and (translation[tag] or translation[tag]) or tag
    if noformat then
        return translated
    else
        return formatters[formats.special](translated)
    end
end

local function translated(e,int)
    local formats    = document.setups.formats
    local attributes = e.at
    local s   = attributes.type or "?"
    local tag = match(s,"^cd:(.*)$")
    if attributes.default == "yes" then
        return formatters[formats.default](tag or "?")
    elseif tag then
        return translate(tag,int)
    else
        return s
    end
end

document.setups.loaded = document.setups.loaded or { }

document.setups.current = { }
document.setups.showsources = true
document.setups.mode = "tex"

function document.setups.load(filename)
    filename = resolvers.findfile(filename) or ""
    if filename ~= "" then
        local current = document.setups.loaded[filename]
        if not current then
            local loaded = xml.load(filename)
            if loaded then
                -- xml.inject(document.setups.root,"/",loaded)
                current = {
                    file = filename,
                    root = loaded,
                    names = { },
                    used = { },
                }
                document.setups.loaded[filename] = current
            end
        end
        document.setups.current = current or { }
    end
end

function document.setups.name(ek)
    local at = ek.at
    local name = at.name
    if at.type == 'environment' then
        name = "start" .. name
    end
    if at.variant then
        name = name .. ":" .. at.variant
    end
    if at.generated == "yes" then
        name = name .. "*"
    end
    return lower(name)
end

local function csname(ek,int)
    local cs = ""
    local at = ek.at or { }
    if at.type == 'environment' then
        cs = translate("start",int,true) .. cs
    end
    local e = xml.first(ek,'cd:sequence/(cd:string|variable)')
    if e then
        if e.tg == "string" then
            cs = cs .. e.at.value
        else
            cs = cs .. e.at.value -- to be translated
        end
    else
        cs = cs .. ek.at.name
    end
    return cs
end

document.setups.csname = csname

function document.setups.names()
    local current = document.setups.current
    local names   = current.names
    if not names or #names == 0 then
        local found = { }
        local name  = document.setups.name
        names = { }
        for e in xml.collected(current.root,'cd:command') do
            local name   = e.at.name
            local csname = csname(e,int)
            local done   = found[csname]
            if not done then
                names[#names+1] = { name, csname }
                found[csname] = name
            else
                -- variant
            end
        end
        sort(names, function(a,b) return lower(a[2]) < lower(b[2]) end)
        current.names = names -- can also become a hash
    end
    return names
end

function document.setups.show(name)
    local current = document.setups.current
    if current.root then
        local name = gsub(name,"[<>]","")
        local setup = xml.first(current.root,"cd:command[@name='" .. name .. "']")
        current.used[#current.used+1] = setup
        xml.sprint(setup)
    end
end

function document.setups.showused()
    local current = document.setups.current
    if current.root and next(current.used) then
        local sorted = table.sortedkeys(current.used)
        for i=1,#sorted do
            xml.sprint(current.used[sorted[i]])
        end
    end
end
function document.setups.showall()
    local current = document.setups.current
    if current.root then
        local list = { }
        for e in xml.collected(current.root,"cd:command") do
            list[document.setups.name(e)] = e
        end
        local sorted = table.sortedkeys(list)
        for i=1,#sorted do
            xml.sprint(list[sorted[i]])
        end
    end
end
function document.setups.resolve(name)
    local current = document.setups.current
    if current.root then
        local e = xml.filter(current.root,formatters["cd:define[@name='%s']/text()"](name))
        if e then
            xml.sprint(e)
        end
    end
end

-- todo: cache definitions

function document.setups.collect(name,int,lastmode)
    local current = document.setups.current
    local formats = document.setups.formats
    local list    = { }
    for command in xml.collected(current.root,formatters["cd:command[@name='%s']"](name)) do
        local attributes = command.at or { }
        local data = {
            command = command,
            category = attributes.category or "",
        }
        if document.setups.showsources then
            data.source = (attributes.file and formatters[formats.source](attributes.file,lastmode,attributes.file)) or ""
        else
            data.source = attributes.file or ""
        end
        local n, sequence, tags = 0, { }, { }
        sequence[#sequence+1] = formatters[formats.open_command[lastmode]](document.setups.csname(command,int))
        local arguments, tag = { }, ""
        for e in xml.collected(command,"(cd:keywords|cd:assignments)") do
            n = n + 1
            local attributes = e.at
            if #sequence > 1 then
                local c = formats.connector[lastmode]
                if c ~= "" then
                    sequence[#sequence+1] = c
                end
            end
            if attributes.optional == 'yes' then
                if attributes.list == 'yes' then
                    tag = formatters[formats.optional_list[lastmode]](n)
                else
                    tag = formatters[formats.optional_single[lastmode]](n)
                end
            else
                if attributes.list == 'yes' then
                    tag = formatters[formats.mandate_list[lastmode]](n)
                else
                    tag = formatters[formats.mandate_single[lastmode]](n)
                end
            end
            sequence[#sequence+1] = tag
            tags[#tags+1] = tag
        end
        sequence[#sequence+1] = formats.close_command[lastmode]
        data.sequence = concat(sequence, " ")
        local parameters, n = { }, 0

        local function process(e)
            for e in xml.collected(e,"(cd:keywords|cd:assignments|cd:resolve)") do
                n = n + 1
                local tag = e.tg
                if tag == "resolve" then
                    local name = e.at.name or ""
                    if name ~= "" then
                        local resolved = xml.first(current.root,formatters["cd:define[@name='%s']"](name))
                        if resolved then
                            process(resolved)
                        end
                    end
                elseif tag == "keywords" then
                    local left  = tags[n]
                    local right = { }
                    for e in xml.collected(e,"(cd:constant|cd:resolve)") do
                        local tag = e.tg
                        if tag == "resolve" then
                            local name = e.at.name or ""
                            if name ~= "" then
                                local resolved = xml.first(current.root,formatters["cd:define[@name='%s']"](name))
                                for e in xml.collected(resolved,"cd:constant") do
                                    right[#right+1] = translated(e,int)
                                end
                            end
                        else
                            right[#right+1] = translated(e,int)
                        end
                    end
                    parameters[#parameters+1] = formatters[formats.parameter](left,"",concat(right, ", "))
                else
                    local what = tags[n]
                    for e in xml.collected(e,"(cd:parameter|cd:inherit|cd:resolve)") do
                        local tag   = e.tg
                        local left  = e.at.name or "?"
                        local right = { }
                        if tag == "resolve" then
                            local name = e.at.name or ""
                            if name ~= "" then
                                local resolved = xml.first(current.root,formatters["cd:define[@name='%s']"](name))
                                if resolved then
                                    process(resolved)
                                end
                            end
                        elseif tag == "inherit" then
                            local name = e.at.name or "?"
                            local url  = formatters[formats.href_as_command[lastmode]](name,lastmode,name)
                            if #parameters > 0 and not find(parameters[#parameters],"<br/>") then
                                parameters[#parameters+1] = formatters[formats.parameter]("<br/>","","")
                            end
                            parameters[#parameters+1] = formatters[formats.parameter](what,formatters[formats.special](translate("inherits",int)),url)
                        else
                            for e in xml.collected(e,"(cd:constant|cd:resolve)") do
                                local tag = e.tg
                                if tag == "resolve" then
                                    local name = e.at.name or ""
                                    if name ~= "" then
                                        local resolved = xml.first(current.root,formatters["cd:define[@name='%s']"](name))
                                        for e in xml.collected(resolved,"cd:constant") do
                                            right[#right+1] = translated(e,int)
                                        end
                                    end
                                else
                                    right[#right+1] = translated(e,int)
                                end
                            end
                            parameters[#parameters+1] = formatters[formats.parameter](what,left,concat(right, ", "))
                        end
                        what = ""
                    end
                end
                parameters[#parameters+1] = formatters[formats.parameter]("<br/>","","")
            end
        end
        process(command)
        data.parameters = parameters or { }
        data.mode = formats.modes[lastmode or "tex"]
        list[#list+1] = data
    end
    return list
end

-- -- --

tex = tex or { }

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

local lastinterface, lastcommand, lastsource, lastmode = "en", "", "", "tex"

local variables = {
    ['color-background-main-left']  = '#3F3F3F',
    ['color-background-main-right'] = '#5F5F5F',
    ['color-background-one']        = lmx.get('color-background-green'),
    ['color-background-two']        = lmx.get('color-background-blue'),
    ['title']                       = 'ConTeXt Help Information',
}

--~ function lmx.loadedfile(filename)
--~     return io.loaddata(resolvers.findfile(filename)) -- return resolvers.texdatablob(filename)
--~ end

local what = { "environment", "category", "source", "mode" }

local function doit(configuration,filename,hashed)

    local start   = os.clock()
    local detail  = hashed.queries or { }
    local formats = document.setups.formats

    if detail then

        lastinterface = detail.interface or lastinterface
        lastcommand   = detail.command   or lastcommand
        lastsource    = detail.source    or lastsource
        lastmode      = detail.mode      or lastmode or "tex"

        lastcommand = gsub(lastcommand,"%s*^\\*(.+)%s*","%1")

        if lastinterface then
            report("checking interface: %s",lastinterface)
         -- document.setups.load(formatters["cont-%s.xml"](lastinterface))
            document.setups.load(formatters["context-%s.xml"](lastinterface))
        end

        local div  = document.setups.div [lastinterface]
        local span = document.setups.span[lastinterface]

        local names, refs, ints = document.setups.names(lastinterface), { }, { }
        for k=1,#names do
            local v = names[k]
            refs[k] = formatters[formats.href_in_list[lastmode]](v[1],lastmode,v[2])
        end
        if lastmode ~= "lua" then
            local sorted = table.sortedkeys(interfaces)
            for k=1,#sorted do
                local v = sorted[k]
                ints[k] = formatters[formats.interface](interfaces[v],lastmode,v)
            end
        end

        local n = concat(refs,"<br/>")
        local i = concat(ints,"<br/><br/>")

        if div then
            variables.names      = formatters[div](n)
            variables.interfaces = formatters[div](i)
        else
            variables.names      = n
            variables.interfaces = i
        end

        -- first we need to add information about mkii/mkiv

        variables.maintitle = "no definition"
        variables.maintext  = ""
        variables.extra     = ""

        if document.setups.showsources and lastsource and lastsource ~= "" then
            -- todo: mkii, mkiv, tex (can be different)
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
                variables.maintext  = formatters[formats.listing]("no source found")
            else
                local data = io.loaddata(full)
                data = scite.html(data,file.suffix(full),true)
                variables.maintitle = name
                variables.maintext  = formatters[formats.listing](data)
            end
            lastsource = ""
        elseif lastcommand and lastcommand ~= "" then
            local list = document.setups.collect(lastcommand,lastinterface,lastmode)
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
                variables.maintext  = formatters[formats.parameters](concat(data.parameters))
                variables.extra     = concat(extra,"&nbsp;&nbsp;&nbsp;")
            else
                variables.maintext = "select command"
            end
        end

    else

        variables.maintitle = "no definition"
        variables.maintext  = "some error"
        variables.extra     = ""

    end

    local content = lmx.convert('context-help.lmx',false,variables)

    report("time spent on page: %0.03f seconds",os.clock()-start)

    return { content = content }
end

return doit, true
