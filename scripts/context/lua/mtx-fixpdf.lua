if not modules then modules = { } end modules ['mtx-fixpdf'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find, lower = string.find, string.lower
local formatters = string.formatters
local nameonly, suffix = file.nameonly, file.suffix

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-tools</entry>
  <entry name="detail">Some File Related Goodies</entry>
  <entry name="version">1.01</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="uncompress"><short>uncompress using qpdf</short></flag>
    <flag name="validate"><short>validate using verapdf</short></flag>
    <flag name="check"><short>check verification result </short></flag>
    <flag name="convert"><short>convert using context</short></flag>
    <flag name="compare"><short>compare result with original</short></flag>
    <flag name="compactor"><short>use given compactor</short></flag>
    <flag name="standard"><short>use given standard</short></flag>
   </subcategory>
   <subcategory>
    <flag name="pattern"><short>processs files according to pattern</short></flag>
    <flag name="silent"><short>suppress messages</short></flag>
    <flag name="once"><short>run only once</short></flag>
    <flag name="resolution"><short>use this resolution when comparing</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-fixpdfs",
    banner   = "Making PDF files more compliant",
    helpinfo = helpinfo,
}

local report  = application.report
local writeln = (logs and logs.writer) or (texio and texio.write_nl) or print

scripts        = scripts        or { }
scripts.fixpdf = scripts.fixpdf or { }

local function getfiles()
    local pattern = environment.arguments.pattern
    if pattern then
        return dir.glob(pattern) or { }
    else
        return environment.files
    end
end

local function validfile(filename)
    name = nameonly(filename)
    return suffix(filename) == "pdf" and not find(name,"%-out$") and not find(name,"%-uncompressed$") and name or false
end

function scripts.fixpdf.uncompress()
    local files = environment.files
    for i=1,#files do
        local name = validfile(files[i])
        if name then
            local command = formatters["qpdf --stream-data=uncompress --object-streams=disable %s.pdf %s-uncompressed.pdf"](name,name)
            report("uncompressing %s.pdf -> %s-uncompressed.pdf",name,name)
            os.execute(command)
        end
    end
end

function scripts.fixpdf.validate()
    local files = getfiles()
    for i=1,#files do
        local name = validfile(files[i])
        if name then
            local command = formatters["verapdf %s-out.pdf > %s-out.txt"](name,name)
            report("validating %s-out.pdf -> %s-out.txt",name,name)
            os.execute(command)
        end
    end
end

function scripts.fixpdf.check()
    local files = getfiles()
    for i=1,#files do
        local name = validfile(files[i])
        if name then
            local data = io.loaddata(formatters["%s-out.txt"](name))
            local atad = data and lower(data)
            local t = { }
            local compliant = atad and find(atad,"pdf file is compliant with validation profile requirements")
            local hasmasks  = atad and find(atad,"smask")
            local fontissue = atad and find(atad,"errormessage.*font")
            if compliant then
                t = { "okay" }
            else
                if fontissue then
                    t[#t+1] = "font"
                end
                if hasmasks then
                    t[#t+1] = "mask"
                end
            end
            if #t == 0 then
                t = { "issue" }
            end
            report("checking %s-out.pdf : % t",name,t)
        end
    end
end

function scripts.fixpdf.convert()
    local files         = getfiles()
    local compactor     = environment.arguments.compactor
    local standard      = environment.arguments.standard
    local silent        = environment.arguments.silent and "--batch --silent" or ""
    local once          = environment.arguments.silent and "--once " or ""
    local nocompression = environment.arguments.nocompression and "--nocompression" or ""
    local extrastyle    = environment.arguments.extrastyle or ""
    if type(compactor) ~= "string" then
        compactor = "yes"
    end
    if type(standard) ~= "string" then
        standard = "PDF/A-1a:2005"
    end
    for i=1,#files do
        local name = validfile(files[i])
        if name then
            -- "--batch --silent --once" can speed up if needed
            local command = formatters["context --global s-pdf-fix.mkxl --compactor=%s --extrastyle=%s --standard=%s %s %s %s --pdffile=%s.pdf --result=%s-out"](compactor,extrastyle,standard,once,silent,nocompression,name,name)
            report("converting %s.pdf -> %s-out.pdf",name,name)
            os.execute(command)
        end
    end
end

function scripts.fixpdf.compare()
    local files      = getfiles()
    local resolution = tonumber(environment.arguments.resolution) or 72
    local tempdir    = "temp-compare"
    local workdir = lfs.currentdir()
    dir.makedirs(tempdir)
    if lfs.chdir(tempdir) then
        for i=1,#files do
            local name = validfile(files[i])
            if name then
                local files = dir.glob("*.png")
                for i=1,#files do
                    os.remove(files[i])
                end
                print(oldname)
                local command = string.format('mutool draw -c gray -o temp-old-%%d.png -r %i -A 0/0 -N ../%s.pdf',resolution,name)
                print(command)
                os.execute(command)
                print(newname)
                local command = string.format('mutool draw -c gray -o temp-new-%%d.png -r %i -A 0/0 -N ../%s-out.pdf',resolution,name)
                print(command)
                os.execute(command)
                local files = dir.glob(string.format("temp-new-*.png",newpngname))
                for i=1,#files do
                    local command = string.format('gm compare -colorspace gray -highlight-color red -file temp-diff-%i.png temp-old-%i.png temp-new-%i.png',i,i,i)
                    print(command)
                    os.execute(command)
                end
                os.remove("context-extra.pdf")
                command = string.format('context --extra=convert --pattern="temp-diff-*.png" --once --purgeall --result=%s-compare',name)
                print(command)
                os.execute(command)
                local files = dir.glob("*.png")
                for i=1,#files do
                    os.remove(files[i])
                end
                -- we keep the file on temp-compare
            end
        end
    end
end

if environment.argument("uncompress") then
    scripts.fixpdf.uncompress()
elseif environment.argument("validate") then
    scripts.fixpdf.validate()
elseif environment.argument("check") then
    scripts.fixpdf.check()
elseif environment.argument("convert") then
    scripts.fixpdf.convert()
elseif environment.argument("compare") then
    scripts.fixpdf.compare()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
