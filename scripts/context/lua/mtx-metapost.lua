if not modules then modules = { } end modules ['mtx-metapost'] = { -- this was mtx-mptopdf
    version   = 0.100,
    comment   = "companion to mtxrun.lua",
    author    = "Taco Hoekwater & Hans Hagen",
    copyright = "ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: load map files

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-metapost</entry>
  <entry name="detail">MetaPost to PDF processor</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="rawmp"><short>raw metapost run</short></flag>
    <flag name="metafun"><short>use metafun instead of plain</short></flag>
    <flag name="latex"><short>force <ref name="tex=latex"/></short></flag>
    <flag name="texexec"><short>force texexec usage (mkii)</short></flag>
    <flag name="split"><short>split single result file into pages</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Examples</title>
   <subcategory>
    <example><command>mtxrun --script metapost yourfile.mp</command></example>
    <example><command>mtxrun --script metapost --split yourfile.mp</command></example>
    <example><command>mtxrun --script metapost yourfile.123 myfile.mps</command></example>
   </subcategory>
  </category>
 </examples>
 <comments>
  <comment>other usage resembles mptopdf.pl</comment>
 </comments>
</application>
]]

local application = logs.application {
    name     = "mtx-metapost",
    banner   = "MetaPost to PDF processor 0.10",
    helpinfo = helpinfo,
}

local report = application.report

scripts             = scripts             or { }
scripts.mptopdf     = scripts.mptopdf     or { }
scripts.mptopdf.aux = scripts.mptopdf.aux or { }

local format, find, gsub = string.format, string.find, string.gsub

local function assumes_latex(filename)
    local d = io.loaddata(filename) or ""
    return find(d,"\\documentstyle") or find(d,"\\documentclass") or find(d,"\\begin{document}")
end

local basemaps = "original-base.map,original-ams-base.map,original-ams-euler.map,original-public-lm.map"

local wrapper  = "\\starttext\n%s\n%s\\stoptext"
local loadmap  = "\\loadmapfile[%s]\n"
local template = "\\startTEXpage\n\\convertMPtoPDF{%s}{1}{1}\n\\stopTEXpage"
local texified = "\\starttext\n%s\n\\stoptext"
local splitter = "\\startTEXpage\\externalfigure[%s][page=%s]\\stopTEXpage"
local tempname = "mptopdf-temp.tex"

local function do_mapfiles(mapfiles)
    local maps = { }
    for i=1,#mapfiles do
        local mapfile = mapfiles[i]
        application.report("using map file %a",mapfile)
        maps[i] = format(loadmap,mapfile)
    end
    return table.concat(maps)
end

local function do_convert(filename,mapfiles)
    if find(filename,".%d+$") or find(filename,"%.mps$") then
        local body = format(template,filename)
        local maps = do_mapfiles(mapfiles)
        io.savedata(tempname,format(wrapper,maps,body))
        local resultname = format("%s-%s.pdf",file.nameonly(filename),file.suffix(filename))
        local result = os.execute(format([[context --once --batch --purge --result=%s "%s"]],resultname,tempname))
        return lfs.isfile(resultname) and resultname
    end
end

local function do_split(filename,numbers,mapfiles)
    local name = file.nameonly(filename)
    local maps = do_mapfiles(mapfiles)
    for i=1,#numbers do
        local body = format(splitter,file.addsuffix(name,"pdf"),i)
        io.savedata(tempname,format(wrapper,maps,body))
        local resultname = format("%s-%s.pdf",name,numbers[i])
        local result = os.execute(format([[context --once --batch --purge --result=%s "%s"]],resultname,tempname))
    end
end

local function do_texify(str)
    -- This only works for flat mp files i.e. outer beginfigs. Normally a
    -- context user will directly make a tex file. Of course we can make
    -- this script more clever, but why should we as better methods exist.
    local numbers = { }
    str = "\\startMPinclusions\n".. str .. "\n\\stopMPinclusions"
    str = gsub(str,"beginfig%s*%(%s*(.-)%s*%)%s*;%s*",function(s)
        numbers[#numbers+1] = tonumber(s) or 0
        return "\n\\stopMPinclusions\n\\startMPpage\n"
    end)
    str = gsub(str,"%s*endfig%s*;%s*","\n\\stopMPpage\n\\startMPinclusions\n")
    str = gsub(str,"\\startMPinclusions%s*\\stopMPinclusions","")
    str = gsub(str,"[\n\r]+","\n")
    return format(texified,str), numbers
end

local function do_convert_all(filename,mapfiles)
    local results = dir.glob(file.nameonly(filename) .. ".*") -- reset
    local report = { }
    for i=1,#results do
        local filename = results[i]
        local resultname = do_convert(filename,mapfiles)
        if resultname then
            report[#report+1] = { filename, resultname }
        end
    end
    if #report > 0 then
        report("number of converted files: %i", #report)
        report()
        for i=1,#report do
            local r = report[i]
            report("%s => %s", r[1], r[2])
        end
    else
        report("no files are converted for '%s'",filename)
    end
end

local function do_convert_one(filename,mapfiles)
    local resultname = do_convert(filename,mapfiles)
    if resultname then
        report("%s => %s", filename,resultname)
    else
        report("no result for '%s'",filename)
    end
end

function scripts.mptopdf.convertall()
    local rawmp    = environment.arguments.rawmp    or false
    local metafun  = environment.arguments.metafun  or false
    local latex    = environment.arguments.latex    or false
    local pattern  = environment.arguments.pattern  or false
    local split    = environment.arguments.split    or false
    local files    = pattern and dir.glob(file.nameonly(filename)) or environment.files
    local mapfiles = utilities.parsers.settings_to_array(environment.arguments.mapfiles or basemaps)
    if #files > 0 then
        for i=1,#files do
            local filename = files[i]
            if file.suffix(filename) == "mp" then
                local command, convert, texdata, numbers
                if rawmp then
                    if metafun then
                        command, convert = format("mpost --progname=mpost --mem=metafun %s",filename), true
                    else
                        command, convert = format("mpost --mem=mpost %s",filename), true
                    end
                else
                    if latex or assumes_latex(filename) then
                        command, convert = format("mpost --mem=mpost --tex=latex %s",filename), true
                    elseif texexec then
                        command, convert = format("texexec --mptex %s",filename), true
                    else
                        texdata, numbers = do_texify(io.loaddata(filename) or "")
                        io.savedata(tempname,texdata)
                        command, convert = format("context --result=%s --purge --once %s",file.nameonly(filename),tempname), false
                    end
                end
                report("running: %s",command)
                local done = os.execute(command)
                if done then
                    if convert then
                        do_convert_all(filename,mapfiles)
                    elseif split then
                        do_split(filename,numbers,mapfiles)
                        -- already pdf, maybe optionally split
                    end
                else
                    report("error while processing mp file '%s'", filename)
                end
            else
                do_convert_one(filename,mapfiles)
            end
        end
    else
        report("no files match to process")
    end
end

if environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
elseif environment.files[1] then
    scripts.mptopdf.convertall()
else
    if not environment.argument("help") then
        report("provide MP output file (or pattern)")
        report()
    end
    application.help()
end
