if not modules then modules = { } end modules ['mtx-movie'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- For Keith McKay, why makes wonderful movies with the latest greatest
-- LuaMetaFun extensions that we (Mikael Sundqvist, Keith McKay and Hans
-- Hagen) work on and enjoy.

-- todo: eps and svg

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-movie</entry>
  <entry name="detail">ConTeXT Movie Conversion Helpers</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="convert"><short>convert given file</short></flag>
    <flag name="mp4"><short>try to make mp4 (instead of gif), needs even h/v pixel</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-movie",
    banner   = "ConTeXT Movie Conversion Helpers 0.10",
    helpinfo = helpinfo,
}

local report  = application.report

scripts       = scripts or { }
scripts.movie = scripts.movie or { }
local movie   = scripts.movie

local mutool  = os.type == "windows" and os.which("mutool.exe") or "mutool"
local convert = os.type == "windows" and os.which("im.exe")     or "convert"

if environment.arguments.convertcommand then
    convert = environment.arguments.convertcommand
end

function movie.convert()
    if not mutool or mutool == "" then
        report("mutool is not installed")
        return
    end
    if not convert or convert == "" then
        report("convert (aka imagemagick) is not installed")
        return
    end

    local name   = file.nameonly(environment.files[1] or "")
    local suffix = "gif"
    local path   = "temp-video-lmtx"

    if environment.arguments.mp4 then
        suffix = "mp4"
    end

    local source  = file.addsuffix(name,"pdf")
    local target  = file.addsuffix(name,suffix)
    local interim = file.addsuffix("temp",suffix)

    if name == "" or not lfs.isfile(source) then
        report("no valid file given")
        return
    end
    if lfs.isdir(path) then
        report("directory %a already exists",path)
        return
    end
    if lfs.mkdirs(path) then
        report("directory %a cannot be created",path)
        return
    end
    if not dir.push(path) then
        report("unable to change to directory %a",path)
        return
    end

    report("working on directory %a",path)
    local command = "mutool convert -O width=600 -o " .. "temp-%5d.png ../" .. source
    report("making png files with %a",command)
    os.execute(command)

    local command = "convert " .. "temp-*.png " .. interim
    report("making movie with %a",command)
    os.execute(command)

    report("copying to file %a",target)
    file.copy(interim,"../" .. target)

    report("wiping path %a",path)
    local files = dir.glob("*")
    for i=1,#files do
        os.remove(files[i])
    end

    dir.pop()
    if not lfs.isdir(path) then
        report("something is wrong with path %a",path)
    else
        lfs.rmdir(path)
    end

    if lfs.isfile(target) then
        report("result available in %a",target)
    else
        report("something is wrong with result %a",target)
    end
end

if environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
elseif environment.argument("convert") then
    movie.convert()
else
    application.help()
end
