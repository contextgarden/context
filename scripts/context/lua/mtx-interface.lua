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
local sortedkeys = table.sortedkeys

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
    <flag name="interfaces"><short>generate context mkii interface files</short></flag>
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
    <flag name="meaning"><short>report the mening of commands</short></flag>
   </subcategory>
   <subcategory>
    <flag name="toutf"><short>replace named characters by utf</short></flag>
    <flag name="preprocess"><short>preprocess mkvi files to tex files [force,suffix]</short></flag>
   </subcategory>
   <subcategory>
    <flag name="suffix"><short>use given suffix for output files</short></flag>
    <flag name="force"><short>force action even when in doubt</short></flag>
   </subcategory>
   <subcategory>
    <flag name="pattern"><short>a pattern for meaning lookups</short></flag>
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
--     for interface, whatever in next, collected do
--         data[interface] = whatever.commands
--     end
    local function add(target,origin,field)
        if origin then
            local list = origin[field]
            if list then
                for i=1,#list do
                    target[list[i]] = true
                end
            end
        end
    end
    --
    for interface, whatever in next, collected do
        local combined = { }
        add(combined,whatever,"commands")
        add(combined,whatever,"environments")
        if interface == "common" then
            add(combined,whatever,"textnames")
            add(combined,whatever,"mathnames")
        end
        data[interface] = sortedkeys(combined)
    end
    --
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
    require("char-def")

    local interfaces = forcedinterfaces or environment.files
    if #interfaces == 0 then
        interfaces= userinterfaces
    end
    --
 -- local filename = "i-context.xml"
    local filename = "context-en.xml"
    local xmlfile  = resolvers.findfile(filename) or ""
    if xmlfile == "" then
        report("unable to locate %a",filename)
        return
    end
    --
    local filename = "mult-def.lua"
    local deffile  = resolvers.findfile(filename) or ""
    if deffile == "" then
        report("unable to locate %a",filename)
        return
    end
    local interface = dofile(deffile)
    if not interface or not next(interface) then
        report("invalid file %a",filename)
        return
    end
    local variables = interface.variables
    local constants = interface.constants
    local commands  = interface.commands
    local elements  = interface.elements
    --
    local collected = { }
    --
    report("generating files for %a",editor)
    report("loading %a",xmlfile)
    local xmlroot = xml.load(xmlfile)
 -- xml.include(xmlroot,"cd:interfacefile","filename",true,function(s)
 --     local fullname = resolvers.findfile(s)
 --     if fullname and fullname ~= "" then
 --         report("including %a",fullname)
 --         return io.loaddata(fullname)
 --     end
 -- end)
 -- local definitions = { }
 -- for e in xml.collected(xmlroot,"cd:interface/cd:define") do
 --     definitions[e.at.name] = e.dt
 -- end
 -- local function resolve(root)
 --     for e in xml.collected(root,"*") do
 --         if e.tg == "resolve" then
 --             local resolved = definitions[e.at.name or ""]
 --             if resolved then
 --                 -- use proper replace helper
 --                 e.__p__.dt[e.ni] = resolved
 --                 resolved.__p__ = e.__p__
 --                 resolve(resolved)
 --             end
 --         end
 --     end
 -- end
 -- resolve(xmlroot)

    -- todo: use sequence

    for i=1,#interfaces do
        local interface      = interfaces[i]
        local i_commands     = { }
        local i_environments = { }
        local start = elements.start[interface] or elements.start.en
        local stop  = elements.stop [interface] or elements.stop .en
        for e in xml.collected(xmlroot,"cd:interface/cd:command") do
            local at   = e.at
            local name = at["name"] or ""
            local type = at["type"]
            if name ~= "" then
                local c = commands[name]
                local n = c and (c[interface] or c.en) or name
                local sequence = xml.all(e,"/cd:sequence/*")
                if at.generated == "yes" then
                    for e in xml.collected(e,"/cd:instances/cd:constant") do
                        local name = e.at.value
                        if name then
                            local c = variables[name]
                            local n = c and (c[interface] or c.en) or name
                            if sequence then
                                local done = { }
                                for i=1,#sequence do
                                    local e = sequence[i]
                                    if e.tg == "string" then
                                        local value = e.at.value
                                        if value then
                                            done[i] = value
                                        else
                                            done = false
                                            break
                                        end
                                    else
                                        local tg = e.tg
                                        if tg == "instance" or tg == "instance:assignment" or tg == "instance:ownnumber" then
                                            done[i] = name
                                        else
                                            done = false
                                            break
                                        end
                                    end
                                end
                                if done then
                                    n = concat(done)
                                end
                            end
                            if type ~= "environment" then
                                i_commands[n] = true
                            elseif split then
                                i_environments[n] = true
                            else
                                i_commands[start..n] = true
                                i_commands[stop ..n] = true
                            end
                        end
                    end
                    -- skip (for now)
                elseif type ~= "environment" then
                    i_commands[n] = true
                elseif split then
                    i_environments[n] = true
                else
                    -- variables ?
                    i_commands[start..n] = true
                    i_commands[stop ..n] = true
                end
            end
        end
        if next(i_commands) then
            collected[interface] = {
                commands     = i_commands,
                environments = i_environments,
            }
        end
    end
    --
    local commoncommands     = { }
    local commonenvironments = { }
    for k, v in next, collected do
        local c = v.commands
        local e = v.environments
        if k == "en" then
            for k, v in next, c do
                commoncommands[k] = true
            end
            for k, v in next, e do
                commonenvironments[k] = true
            end
        else
            for k, v in next, c do
                if not commoncommands[k] then
                    commoncommands[k] = nil
                end
            end
            for k, v in next, e do
                if not commonenvironments[k] then
                    commonenvironments[k] = nil
                end
            end
        end
    end
    for k, v in next, collected do
        local c = v.commands
        local e = v.environments
        for k, v in next, commoncommands do
            c[k] = nil
        end
        for k, v in next, commonenvironments do
            e[k] = nil
        end
        v.commands     = sortedkeys(c)
        v.environments = sortedkeys(e)
    end
    --
    local mathnames = { }
    local textnames = { }
    for k, v in next, characters.data do
        local name = v.contextname
        if name then
            textnames[name] = true
        end
        local name = v.mathname
        if name then
            mathnames[name] = true
        end
        local spec = v.mathspec
        if spec then
            for i=1,#spec do
                local s = spec[i]
                local name = s.name
                if name then
                    mathnames[name] = true
                end
            end
        end
    end
    --
    collected.common = {
        textnames    = sortedkeys(textnames),
        mathnames    = sortedkeys(mathnames),
        commands     = sortedkeys(commoncommands),
        environments = sortedkeys(commonenvironments),
    }
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

function scripts.interface.mkii()
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
                local sorted = sortedkeys(t)
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
                xmlresult[#xmlresult+1] = format("\t</cd:%s>\n",what)
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
                -- keyword files
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
                -- mkii files
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
                -- mkiv is generated otherwise
            end
        end
    end
end

function scripts.interface.preprocess()
    require("luat-mac")

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

function scripts.interface.bidi()
    require("char-def")

    local directiondata  = { }
    local mirrordata     = { }
    local textclassdata  = { }

    local data = {
        comment    = "generated by: mtxrun -- script interface.lua --bidi",
        direction  = directions,
        mirror     = mirrors,
        textclass  = textclasses,
    }

    for k, d in next, characters.data do
        local direction = d.direction
        local mirror    = d.mirror
        local textclass = d.textclass
        if direction and direction ~= "l" then
            directiondata[k] = direction
        end
        if mirror then
            mirrordata[k] = mirror
        end
        if textclass then
            textclassdata[k] = textclass
        end
    end

    local filename = "scite-context-data-bidi.lua"

    report("saving %a",filename)
    table.save(filename,data)
end

function scripts.interface.toutf()
    local filename = environment.files[1]
    if filename then
        require("char-def")
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
        report("loading %a",filename)
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
        report("saving %a",filename)
        io.savedata(filename,str)
    end
end

function scripts.interface.meaning()
    local runner  = "mtxrun --silent --script context --extra=meaning --once --noconsole --nostatistics"
    local pattern = environment.arguments.pattern
    local files   = environment.files
    if type(pattern) == "string" then
        runner = runner .. ' --pattern="' .. pattern .. '"'
    elseif files and #files > 0 then
        for i=1,#files do
            runner = runner .. ' "' .. files[i] .. '"'
        end
    else
        return
    end
    local r = os.resultof(runner)
    if type(r) == "string" then
        r = gsub(r,"^.-(meaning%s+>)","\n%1")
        print(r)
    end
end

local ea = environment.argument

if ea("mkii") then
    scripts.interface.mkii()
elseif ea("preprocess") then
    scripts.interface.preprocess()
elseif ea("meaning") then
    scripts.interface.meaning()
elseif ea("toutf") then
    scripts.interface.toutf()
elseif ea("bidi") then
    scripts.interface.bidi()
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
