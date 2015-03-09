if not modules then modules = { } end modules ['mtx-cache'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat, sort, insert = table.concat, table.sort, table.insert
local gsub, format, gmatch, find = string.gsub, string.format, string.gmatch, string.find
local utfchar, utfgsub = utf.char, utf.gsub

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-interface</entry>
  <entry name="detail">ConTeXt Interface Related Goodies</entry>
  <entry name="version">0.13</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="interfaces"><short>generate context interface files</short></flag>
    <flag name="messages"><short>generate context message files</short></flag>
    <flag name="labels"><short>generate context label files</short></flag>
   </subcategory>
   <subcategory>
    <flag name="context"><short>equals <ref name="interfaces"/> <ref name="messages"/> <ref name="languages"/></short></flag>
   </subcategory>
   <subcategory>
    <flag name="scite"><short>generate scite interface</short></flag>
    <flag name="bbedit"><short>generate bbedit interface files</short></flag>
    <flag name="jedit"><short>generate jedit interface files</short></flag>
    <flag name="textpad"><short>generate textpad interface files</short></flag>
    <flag name="text"><short>create text files for commands and environments</short></flag>
    <flag name="raw"><short>report commands to the console</short></flag>
    <flag name="check"><short>generate check file</short></flag>
   </subcategory>
   <subcategory>
    <flag name="toutf"><short>replace named characters by utf</short></flag>
    <flag name="preprocess"><short>preprocess mkvi files to tex files [force,suffix]</short></flag>
   </subcategory>
   <subcategory>
    <flag name="suffix"><short>use given suffix for output files</short></flag>
    <flag name="force"><short>force action even when in doubt</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-interface",
    banner   = "ConTeXt Interface Related Goodies 0.13",
    helpinfo = helpinfo,
}

local report = application.report

scripts           = scripts           or { }
scripts.interface = scripts.interface or { }

local flushers          = { }
local userinterfaces    = { 'en','cs','de','it','nl','ro','fr','pe' }
local messageinterfaces = { 'en','cs','de','it','nl','ro','fr','pe','no' }

local function collect(filename,class,data)
    if data then
        local result = { }
        for name, list in table.sortedhash(data) do
            result[#result+1] = format("keywordclass.%s.%s=\\\n",class,name)
            for i=1,#list do
                if i%5 == 0 then
                    result[#result+1] = "\\\n"
                end
                result[#result+1] = format("%s ",list[i])
            end
            result[#result+1] = "\n\n"
        end
        io.savedata(file.addsuffix(filename,"properties"),concat(result))
        io.savedata(file.addsuffix(filename,"lua"),       table.serialize(data,true))
    else
        os.remove(filename)
    end
end

function flushers.scite(collected)
    local data = { }
    for interface, whatever in next, collected do
        data[interface] = whatever.commands
    end
    collect("scite-context-data-interfaces", "context",  data)
    collect("scite-context-data-metapost",   "metapost", dofile(resolvers.findfile("mult-mps.lua")))
    collect("scite-context-data-metafun",    "metafun",  dofile(resolvers.findfile("mult-fun.lua")))
    collect("scite-context-data-context",    "context",  dofile(resolvers.findfile("mult-low.lua")))
    collect("scite-context-data-tex",        "tex",      dofile(resolvers.findfile("mult-prm.lua")))
end

function flushers.jedit(collected)
    for interface, whatever in next, collected do
        local commands     = whatever.commands
        local environments = whatever.environments
        local result = { }
        result[#result+1] = "<?xml version='1.0'?>"
        result[#result+1] = "<!DOCTYPE MODE SYSTEM 'xmode.dtd'>\n"
        result[#result+1] = "<MODE>"
        result[#result+1] = "\t<RULES>"
        result[#result+1] = "\t\t<KEYWORDS>"
        for i=1,#commands do
            result[#result+1] = format("\t\t\t<KEYWORD2>%s</KEYWORD2>",commands[i])
        end
        result[#result+1] = "\t\t</KEYWORDS>"
        result[#result+1] = "\t</RULES>"
        result[#result+1] = "</MODE>"
        io.savedata(format("context-jedit-%s.xml",interface), concat(result),"\n")
    end
end

function flushers.bbedit(collected)
    for interface, whatever in next, collected do
        local commands     = whatever.commands
        local environments = whatever.environments
        local result = {}
        result[#result+1] = "<?xml version='1.0'?>"
        result[#result+1] = "<key>BBLMKeywordList</key>"
        result[#result+1] = "<array>"
        for i=1,#commands do
            result[#result+1]  = format("\t<string>\\%s</string>",commands[i])
        end
        result[#result+1] = "</array>"
        io.savedata(format("context-bbedit-%s.xml",interface), concat(result),"\n")
    end
end

function flushers.raw(collected)
    for interface, whatever in next, collected do
        local commands     = whatever.commands
        local environments = whatever.environments
        for i=1,#commands do
            report(commands[i])
        end
    end
end

local textpadcreator = "mtx-interface-textpad.lua"

function flushers.text(collected)
    for interface, whatever in next, collected do
        local commands     = whatever.commands
        local environments = whatever.environments
        local c, cname = { }, format("context-commands-%s.txt",interface)
        local e, ename = { }, format("context-environments-%s.txt",interface)
        report("saving '%s'",cname)
        for i=1,#commands do
            c[#c+1] = format("\\%s",commands[i])
        end
        io.savedata(cname,concat(c,"\n"))
        report("saving '%s'",ename)
        for i=1,#environments do
            e[#e+1] = format("\\start%s",environments[i])
            e[#e+1] = format("\\stop%s", environments[i])
        end
        io.savedata(format("context-environments-%s.txt",interface),concat(e,"\n"))
    end
end

function flushers.textpad(collected)
    flushers.text(collected)
    for interface, whatever in next, collected do
        local commands     = whatever.commands
        local environments = whatever.environments
        --
        -- plugin, this is a rewrite of a file provided by Lukas Prochazka
        --
        local function merge(templatedata,destinationdata,categories)
            report("loading '%s'",templatedata)
            local data = io.loaddata(templatedata)
            local done = 0
            for i=1,#categories do
                local category = categories[i]
                local cpattern = ";%s*category:%s*(" .. category .. ")%s*[\n\r]+"
                local fpattern = ";%s*filename:%s*(" .. "%S+"     .. ")%s*[\n\r]+"
                data = gsub(data,cpattern..fpattern,function(category,filename)
                    local found = resolvers.findfile(filename) or ""
                    local blob = found ~= "" and io.loaddata(found) or ""
                    if blob == ""  then
                        report("category: %s, filename: %s, not found",category,filename)
                    else
                        done = done + 1
                        report("category: %s, filename: %s, merged",category,filename)
                    end
                    return format("; category: %s\n; filename: %s\n%s\n\n",category,filename,blob)
                end)
            end
            if done > 0 then
                report("saving '%s' (%s files merged)",destinationdata,done)
                io.savedata(destinationdata,data)
            else
                report("skipping '%s' (no files merged)",destinationdata)
            end
        end
        local templatename = "textpad-context-template.txt"
        local templatedata = resolvers.findfile(templatename) or ""
        if templatedata == "" then
            report("unable to locate template '%s'",templatename)
        else
            merge(templatedata, "context.syn",       { "tex commands","context commands" })
            if environment.argument("textpad") == "latex" then
                merge(templatedata, "context-latex.syn", { "tex commands","context commands", "latex commands" })
            end
        end
        local r = { }
        local c = io.loaddata("context-commands-en.txt")     or "" -- sits on the same path
        local e = io.loaddata("context-environments-en.txt") or "" -- sits on the same path
        for s in gmatch(c,"\\(.-)%s") do
            r[#r+1] = format("\n!TEXT=%s\n\\%s\n!",s,s)
        end
        for s in gmatch(e,"\\start(.-)%s+\\stop(.-)") do
            r[#r+1] = format("\n!TEXT=%s (start/stop)\n\\start%s \\^\\stop%s\n!",s,s,s)
        end
        sort(r)
        insert(r,1,"!TCL=597,\n!TITLE=ConTeXt\n!SORT=N\n!CHARSET=DEFAULT")
        io.savedata("context.tcl",concat(r,"\n"))
        -- cleanup
        os.remove("context-commands-en.txt")
        os.remove("context-environments-en.txt")
    end
end

function scripts.interface.editor(editor,split,forcedinterfaces)
    local interfaces= forcedinterfaces or environment.files
    if #interfaces == 0 then
        interfaces= userinterfaces
    end
    local xmlfile = resolvers.findfile("cont-en.xml") or ""
    if xmlfile == "" then
        report("unable to locate cont-en.xml")
    end
    local collected = { }
    for i=1,#interfaces do
        local interface = interfaces[i]
        local keyfile = resolvers.findfile(format("keys-%s.xml",interface)) or ""
        if keyfile == "" then
            report("unable to locate keys-*.xml")
        else
            local commands     = { }
            local mappings     = { }
            local environments = { }
            local x = xml.load(keyfile)
            for e, d, k in xml.elements(x,"/cd:interface/cd:commands/cd:command") do -- somehow this was variable
                local at = d[k].at
                local name, value = at.name, at.value
                if name and value then
                    mappings[name] = value
                end
            end
            local x = xml.load(xmlfile)
            for e, d, k in xml.elements(x,"/cd:interface/cd:command") do
                local at = d[k].at
                local name, type = at.name, at["type"]
                if name and name ~= "" then
                    local remapped = mappings[name] or name
                    if type == "environment" then
                        if split then
                            environments[#environments+1] = remapped
                        else
                            commands[#commands+1] = "start" .. remapped
                            commands[#commands+1] = "stop"  .. remapped
                        end
                    else
                        commands[#commands+1] = remapped
                    end
                end
            end
            if #commands > 0 then
                sort(commands)
                sort(environments)
                collected[interface] = {
                    commands     = commands,
                    environments = environments,
                }
            end
        end
    end
    -- awaiting completion of the xml file
    local definitions = dofile(resolvers.findfile("mult-def.lua"))
    if definitions then
        local commands = { en = { } }
        for command, languages in next, definitions.commands do
            commands.en[languages.en or command] = true
            for language, command in next, languages do
                local c = commands[language]
                if c then
                    c[command] = true
                else
                    commands[language] = { [command] = true }
                end
            end
        end
        for language, data in next, commands do
            local fromlua = data
            local fromxml = collected[language].commands
            for i=1,#fromxml do
                local c = fromxml[i]
                if not fromlua[c] then
                 -- print(language,c)
                    fromlua[c] = true
                end
            end
            collected[language].commands = table.sortedkeys(fromlua)
        end
    end
    --
    flushers[editor](collected)
end

function scripts.interface.check()
    local xmlfile = resolvers.findfile("cont-en.xml") or ""
    if xmlfile ~= "" then
        local f = io.open("cont-en-check.tex","w")
        if f then
            f:write("\\starttext\n")
            local x = xml.load(xmlfile)
            for e, d, k in xml.elements(x,"/cd:interface/cd:command") do
                local dk = d[k]
                local at = dk.at
                if at then
                    local name = xml.filter(dk,"cd:sequence/cd:string/attribute(value)")
                    if name and name ~= "" then
                        if at.type == "environment" then
                            name = "start" .. name
                        end
                        f:write(format("\\doifundefined{%s}{\\writestatus{check}{command '%s' is undefined}}\n",name,name))
                    end
                end
            end
            f:write("\\stoptext\n")
            f:close()
        end
    end
end

function scripts.interface.interfaces()
    local filename = resolvers.findfile(environment.files[1] or "mult-def.lua") or ""
    if filename ~= "" then
        local interface = dofile(filename)
        if interface and next(interface) then
            local variables, constants, commands, elements = interface.variables, interface.constants, interface.commands, interface.elements
            local filename = resolvers.findfile("cont-en.xml") or ""
            local xmldata = filename ~= "" and (io.loaddata(filename) or "")
            local function flush(texresult,xmlresult,language,what,tag)
                local t = interface[what]
                texresult[#texresult+1] = format("%% definitions for interface %s for language %s\n%%",what,language)
                xmlresult[#xmlresult+1] = format("\t<!-- definitions for interface %s for language %s -->\n",what,language)
                xmlresult[#xmlresult+1] = format("\t<cd:%s>",what)
                local sorted = table.sortedkeys(t)
                for i=1,#sorted do
                    local key = sorted[i]
                    local v = t[key]
                    local value = v[language] or v["en"]
                    if not value then
                        report("warning, no value for key '%s' for language '%s'",key,language)
                    else
                        local value = t[key][language] or t[key].en
                        texresult[#texresult+1] = format("\\setinterface%s{%s}{%s}",tag,key,value)
                        xmlresult[#xmlresult+1] = format("\t\t<cd:%s name='%s' value='%s'/>",tag,key,value)
                    end
                end
                xmlresult[#xmlresult+1] = format("\t</cd:%s>\n",tag)
            end
            local function replace(str, element, attribute, category, othercategory, language)
                return str:gsub(format("(<%s[^>]-%s=)([\"\'])([^\"\']-)([\"\'])",element,attribute), function(a,b,c)
                    local cc = category[c]
                    if not cc and othercategory then
                        cc = othercategory[c]
                    end
                    if cc then
                        ccl = cc[language]
                        if ccl then
                            return a .. b .. ccl .. b
                        end
                    end
                    return a .. b .. c .. b
                end)
            end
            -- we could just replace attributes
            for language, _ in next, commands.setuplayout do
                local texresult, xmlresult = { }, { }
                texresult[#texresult+1] = format("%% this file is auto-generated, don't edit this file\n%%")
                xmlresult[#xmlresult+1] = format("<?xml version='1.0'?>\n",tag)
                xmlresult[#xmlresult+1] = format("<cd:interface xmlns:cd='http://www.pragma-ade.com/commands' name='context' language='%s' version='2008.10.21 19:42'>\n",language)
                flush(texresult,xmlresult,language,"variables","variable")
                flush(texresult,xmlresult,language,"constants","constant")
                flush(texresult,xmlresult,language,"elements", "element")
                flush(texresult,xmlresult,language,"commands", "command")
                texresult[#texresult+1] = format("%%\n\\endinput")
                xmlresult[#xmlresult+1] = format("</cd:interface>")
                local texfilename = format("mult-%s.mkii",language)
                local xmlfilename = format("keys-%s.xml",language)
                io.savedata(texfilename,concat(texresult,"\n"))
                report("saving interface definitions '%s'",texfilename)
                io.savedata(xmlfilename,concat(xmlresult,"\n"))
                report("saving interface translations '%s'",xmlfilename)
                if language ~= "en" and xmldata ~= "" then
                    local newdata = xmldata:gsub("(<cd:interface.*language=.)en(.)","%1"..language.."%2",1)
-- newdata = replace(newdata, 'cd:command', 'name', interface.commands, interface.elements, language)
                    newdata = replace(newdata, 'cd:string', 'value', interface.commands, interface.elements, language)
                    newdata = replace(newdata, 'cd:variable' , 'value', interface.variables, nil, language)
                    newdata = replace(newdata, 'cd:parameter', 'name', interface.constants, nil, language)
                    newdata = replace(newdata, 'cd:constant', 'type', interface.variables, nil, language)
                    newdata = replace(newdata, 'cd:variable', 'type', interface.variables, nil, language)
                    newdata = replace(newdata, 'cd:inherit', 'name', interface.commands, interface.elements, language)
                    local xmlfilename = format("cont-%s.xml",language)
                    io.savedata(xmlfilename,newdata)
                    report("saving interface specification '%s'",xmlfilename)
                end
            end
        end
    end
end

function scripts.interface.preprocess()
    dofile(resolvers.findfile("luat-mac.lua"))
 -- require("luat-mac.lua")
    local newsuffix = environment.argument("suffix") or "log"
    local force = environment.argument("force")
    for i=1,#environment.files do
        local oldname = environment.files[i]
        local newname = file.replacesuffix(oldname,newsuffix)
        if oldname == newname then
            report("skipping '%s' because old and new name are the same",oldname)
        elseif io.exists(newname) and not force then
            report("skipping '%s' because new file exists, use --force",oldname)
        else
            report("processing '%s' into '%s'",oldname,newname)
            io.savedata(newname,resolvers.macros.preprocessed(io.loaddata(oldname)))
        end
    end
end

-- function scripts.interface.messages()
--     local filename = resolvers.findfile(environment.files[1] or "mult-mes.lua") or ""
--     if filename ~= "" then
--         local messages = dofile(filename)
--         report("messages for * loaded from '%s'",filename)
--         report()
--         for i=1,#messageinterfaces do
--             local interface = messageinterfaces[i]
--             local texresult = { }
--             for category, data in next, messages do
--                 for tag, message in next, data do
--                     if tag ~= "files" then
--                         local msg = message[interface] or message["all"] or message["en"]
--                         if msg then
--                             texresult[#texresult+1] = format("\\setinterfacemessage{%s}{%s}{%s}",category,tag,msg)
--                         end
--                     end
--                 end
--             end
--             texresult[#texresult+1] = format("%%\n\\endinput")
--             local interfacefile = format("mult-m%s.mkii",interface)
--             io.savedata(interfacefile,concat(texresult,"\n"))
--             report("messages for '%s' saved in '%s'",interface,interfacefile)
--         end
--     end
-- end

function scripts.interface.toutf()
    local filename = environment.files[1]
    if filename then
        require("char-def.lua")
        local contextnames = { }
        for unicode, data in next, characters.data do
            local contextname = data.contextname
            if contextname then
                contextnames[contextname] = utf.char(unicode)
            end
            contextnames.uumlaut = contextnames.udiaeresis
            contextnames.Uumlaut = contextnames.Udiaeresis
            contextnames.oumlaut = contextnames.odiaeresis
            contextnames.Oumlaut = contextnames.Odiaeresis
            contextnames.aumlaut = contextnames.adiaeresis
            contextnames.Aumlaut = contextnames.Adiaeresis
        end
        report("loading '%s'",filename)
        local str = io.loaddata(filename) or ""
        local done = { }
        str = gsub(str,"(\\)([a-zA-Z][a-zA-Z][a-zA-Z]+)(%s*)", function(b,s,a)
            local cn = contextnames[s]
            if cn then
                done[s] = (done[s] or 0) + 1
                return cn
            else
                done[s] = (done[s] or 0) - 1
                return b .. s .. a
            end
        end)
        for k, v in table.sortedpairs(done) do
            if v > 0 then
                report("+ %5i : %s => %s",v,k,contextnames[k])
            else
                report("- %5i : %s",-v,k,contextnames[k])
            end
        end
        filename = filename .. ".toutf"
        report("saving '%s'",filename)
        io.savedata(filename,str)
    end
end

-- function scripts.interface.labels()
--     require("char-def.lua")
--     require("lang-txt.lua")
--     local interfaces = require("mult-def.lua")
--     local variables = interfaces.variables
--     local contextnames = { }
--     for unicode, data in next, characters.data do
--         local contextname = data.contextname
--         if contextname then
--             contextnames[utfchar(unicode)] = "\\" .. contextname .. " "
--         end
--     end
--     contextnames["i"] = nil
--     contextnames["'"] = nil
--     contextnames["\\"] = nil
--     local function flush(f,kind,what,expand,namespace,prefix)
--         local whatdata = languages.data.labels[what]
--         f:write("\n")
--         f:write(format("%% %s => %s\n",what,kind))
--         for tag, data in table.sortedpairs(whatdata) do
--             if not data.hidden then
--                 f:write("\n")
--                 for language, text in table.sortedpairs(data.labels) do
--                     if text ~= "" then
--                         if expand then
--                             text = utfgsub(text,".",contextnames)
--                             text = gsub(text,"  ", "\ ")
--                         end
--                         if namespace and namespace[tag] then
--                             tag = prefix .. tag
--                         end
--                         if find(text,",") then
--                             text = "{" .. text .. "}"
--                         end
--                         if text == "" then
--                             -- skip
--                         else
--                             if type(text) == "table" then
--                                 f:write(format("\\setup%stext[\\s!%s][%s={{%s},}]\n",kind,language,tag,text))
--                             else
--                                 f:write(format("\\setup%stext[\\s!%s][%s={{%s},{%s}}]\n",kind,language,tag,text[1],text[2]))
--                             end
--                         end
--                     end
--                 end
--             end
--         end
--     end
--     function flushall(txtname,expand)
--         local f = io.open(txtname,"w")
--         if f then
--             report("saving '%s'",txtname)
--             f:write("% this file is auto-generated, don't edit this file\n")
--             flush(f,"head","titles",expand,variables,"\\v!")
--             flush(f,"label","texts",expand,variables,"\\v!")
--             flush(f,"mathlabel","functions",expand)
--             flush(f,"taglabel","tags",expand)
--             f:write("\n")
--             f:write("\\endinput\n")
--             f:close()
--         end
--     end
--     flushall("lang-txt.mkii",true)
--     flushall("lang-txt.mkiv",false)
-- end

local ea = environment.argument

if ea("context") then
    scripts.interface.interfaces()
 -- scripts.interface.messages()
 -- scripts.interface.labels()
elseif ea("interfaces") or ea("messages") or ea("labels") then
    if ea("interfaces") then
        scripts.interface.interfaces()
    end
 -- if ea("messages") then
 --     scripts.interface.messages()
 -- end
 -- if ea("labels") then
 --     scripts.interface.labels()
 -- end
elseif ea("preprocess") then
    scripts.interface.preprocess()
elseif ea("toutf") then
    scripts.interface.toutf()
elseif ea("check") then
    scripts.interface.check()
elseif ea("scite") or ea("bbedit") or ea("jedit") or ea("textpad") or ea("text") or ea("raw") then
    if ea("scite") then
        scripts.interface.editor("scite")
    end
    if ea("bbedit") then
        scripts.interface.editor("bbedit")
    end
    if ea("jedit") then
        scripts.interface.editor("jedit")
    end
    if ea("textpad") then
        scripts.interface.editor("textpad",true, { "en" })
    end
    if ea("text") then
        scripts.interface.editor("text")
    end
    if ea("raw") then
        scripts.interface.editor("raw")
    end
elseif ea("exporthelp") then
    application.export(ea("exporthelp"),environment.files[1])
else
    application.help()
end
