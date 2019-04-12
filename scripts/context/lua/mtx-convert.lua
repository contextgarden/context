if not modules then modules = { } end modules ['mtx-convert'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: eps and svg

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-convert</entry>
  <entry name="detail">ConTeXT Graphic Conversion Helpers</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="convertall"><short>convert all graphics on path</short></flag>
    <flag name="inputpath" value="string"><short>original graphics path</short></flag>
    <flag name="outputpath" value="string"><short>converted graphics path</short></flag>
    <flag name="watch"><short>watch folders</short></flag>
    <flag name="force"><short>force conversion (even if older)</short></flag>
    <flag name="delay"><short>time between sweeps</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-convert",
    banner   = "ConTeXT Graphic Conversion Helpers 0.10",
    helpinfo = helpinfo,
}

local format, find = string.format, string.find
local concat = table.concat

local report = application.report

scripts              = scripts or { }
scripts.convert      = scripts.convert or { }
local convert        = scripts.convert
convert.converters   = convert.converters or { }
local converters     = convert.converters

local gsprogram      = (os.type == "windows" and (os.which("gswin64c.exe") or os.which("gswin32c.exe"))) or "gs"

if string.find(gsprogram," ") then
    -- c:/program files/...../gswinNNc.exe"
    gsprogram = '"' .. gsprogram .. '"'
end

local gstemplate_eps = "%s -q -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -dEPSCrop -dNOPAUSE -dSAFER -dNOCACHE -dBATCH -dAutoRotatePages=/None -dProcessColorModel=/DeviceCMYK -sOutputFile=%s %s -c quit"
local gstemplate_ps  = "%s -q -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -dNOPAUSE -dSAFER -dNOCACHE -dBATCH -dAutoRotatePages=/None -dProcessColorModel=/DeviceCMYK -sOutputFile=%s %s -c quit"

function converters.eps(oldname,newname)
    return format(gstemplate_eps,gsprogram,newname,oldname)
end

function converters.ps(oldname,newname)
    return format(gstemplate_ps,gsprogram,newname,oldname)
end

local improgram  = "convert"
local imtemplate = {
    low    = "%s -quality   0 -compress zip %s pdf:%s",
    medium = "%s -quality  75 -compress zip %s pdf:%s",
    high   = "%s -quality 100 -compress zip %s pdf:%s",
}

function converters.jpg(oldname,newname)
    local ea = environment.arguments
    local quality = (ea.high and 'high') or (ea.medium and 'medium') or (ea.low and 'low') or 'high'
    return format(imtemplate[quality],improgram,oldname,newname)
end

converters.gif  = converters.jpg
converters.tif  = converters.jpg
converters.tiff = converters.jpg
converters.png  = converters.jpg

function converters.convertgraphic(kind,oldname,newname)
    if converters[kind] then -- extra test
        local tmpname = file.replacesuffix(newname,"tmp")
        local command = converters[kind](oldname,tmpname)
        report("command: %s",command)
        io.flush()
        os.execute(command)
        os.remove(newname)
        os.rename(tmpname,newname)
        if lfs.attributes(newname,"size") == 0 then
            os.remove(newname)
        end
    end
end

function converters.convertpath(inputpath,outputpath)
    inputpath  = inputpath  or "."
    outputpath = outputpath or "."
    for name in lfs.dir(inputpath) do
        local suffix = file.suffix(name)
        if find(name,"%.$") then
            -- skip . and ..
        elseif converters[suffix] then
            local oldname = file.join(inputpath,name)
            local newname = file.join(outputpath,file.replacesuffix(name,"pdf"))
            local et = lfs.attributes(oldname,"modification")
            local pt = lfs.attributes(newname,"modification")
            if not pt or et > pt then
                dir.mkdirs(outputpath)
                converters.convertgraphic(suffix,oldname,newname)
            end
        elseif lfs.isdir(inputpath .. "/".. name) then
            converters.convertpath(inputpath .. "/".. name,outputpath .. "/".. name)
        end
    end
end

function converters.convertfile(oldname)
    local suffix = file.suffix(oldname)
    if converters[suffix] then
        local newname = file.replacesuffix(oldname,"pdf")
        if oldname == newname then
            -- todo: downsample, crop etc
        elseif environment.argument("force") then
            converters.convertgraphic(suffix,oldname,newname)
        else
            local et = lfs.attributes(oldname,"modification")
            local pt = lfs.attributes(newname,"modification")
            if not pt or et > pt then
                converters.convertgraphic(suffix,oldname,newname)
            end
        end
    end
end

if environment.ownscript then
    -- stand alone
else
    report(application.banner)
    return convert
end

convert.delay = 5 * 60 -- 5 minutes

function convert.convertall()
    local watch  = environment.arguments.watch      or false
    local delay  = environment.arguments.delay      or convert.delay
    local input  = environment.arguments.inputpath  or "."
    local output = environment.arguments.outputpath or "."
    while true do
        converters.convertpath(input, output)
        if watch then
            os.sleep(delay)
        else
            break
        end
    end
end

function convert.convertgiven()
    local files = environment.files
    for i=1,#files do
        converters.convertfile(files[i])
    end
end

if environment.arguments.convertall then
    convert.convertall()
elseif environment.files[1] then
    convert.convertgiven()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
