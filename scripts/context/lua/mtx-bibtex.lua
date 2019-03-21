if not modules then modules = { } end modules ['mtx-bibtex'] = {
    version   = 1.002,
    comment   = "this script is part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE",
    license   = "see context related readme files"
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-bibtex</entry>
  <entry name="detail">bibtex helpers</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="toxml"><short>convert bibtex database(s) to xml</short></flag>
    <flag name="tolua"><short>convert bibtex database(s) to lua</short></flag>
    <flag name="search"><short>seatch bibtex database(s)</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Example</title>
   <subcategory>
    <example><command>mtxrun --script bibtex --tolua bibl-001.bib</command></example>
    <example><command>mtxrun --script bibtex --tolua --simple bibl-001.bib</command></example>
    <example><command>mtxrun --script bibtex --toxml bibl-001.bib bibl-002.bib bibl-003.bib biblio.xml</command></example>
    <example><command>mtxrun --script bibtex --search --list --pattern=match(author:foo) bar.bib</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-bibtex",
    banner   = "bibtex helpers",
    helpinfo = helpinfo,
}

local report = application.report

require("util-seq")
require("publ-dat")
require("publ-fnd")

scripts        = scripts        or { }
scripts.bibtex = scripts.bibtex or { }

function scripts.bibtex.toxml(files)
    local instance = bibtex.new()
    local target   = "mtx-bibtex-output.xml"
    for i=1,#files do
        local filename = files[i]
        local filetype = file.suffix(filename)
        if filetype == "xml" then
            target = filename
        elseif filetype == "bib" then
            bibtex.load { dataset = instance, filename = filename }
        else
            -- not supported
        end
    end
    bibtex.converttoxml(instance,true)
    instance.shortcuts = nil
    instance.luadata   = nil
    xml.save(instance.xmldata,target)
end

function scripts.bibtex.tolua(files)
    local instance = bibtex.new()
    local target = "mtx-bibtex-output.lua"
    for i=1,#files do
        local filename = files[i]
        local filetype = file.suffix(filename)
        if filetype == "lua" then
            target = filename
        elseif filetype == "bib" then
            bibtex.load { dataset = instance, filename = filename }

        else
            -- not supported
        end
    end
    instance.shortcuts = nil
    instance.xmldata   = nil
    bibtex.analyze(instance)
    if environment.arguments.simple then
        table.save(target,instance)
    else
        table.save(target,instance.luadata)
    end
end

function scripts.bibtex.search(files,pattern,list)
    if pattern then
        local dataset = publications.datasets["whatever"]
        for i=1,#files do
            local filename = resolvers.findfile(files[i])
            if filename and filename ~= "" then
                publications.load { dataset = "whatever", filename = filename }
            end
        end
        local found = publications.search(dataset,pattern)
        local tags  = table.sortedkeys(found)
        if #tags == 0 then
            report("no match")
        elseif list then
            report("%s matches:",#tags)
            local result  = { }
            local luadata = dataset.luadata
            for i=1,#tags do
                local tag   = tags[i]
                local entry = luadata[tag]
                result[i] = {
                    tag,
                    entry.year,
                    entry.author,
                    entry.title,
                }
            end
            utilities.formatters.formatcolumns(result)
            logs.newline()
            for i=1,#result do
                logs.writer(result[i])
            end
            logs.newline()
        else
            report("%s matches: % t",#tags,tags)
        end
    end
end

if environment.arguments.search then
    scripts.bibtex.search(environment.files,environment.arguments.pattern,environment.arguments.list)
elseif environment.arguments.toxml then
    scripts.bibtex.toxml(environment.files)
elseif environment.arguments.tolua then
    scripts.bibtex.tolua(environment.files)
elseif environment.arguments.exporthelp then
    application.export(environment.arguments.exporthelp,environment.files[1])
else
    application.help()
end

-- scripts.bibtex.toxml { "tugboat.bib" }
-- scripts.bibtex.tolua { "tugboat.bib" }
