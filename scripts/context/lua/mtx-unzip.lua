if not modules then modules = { } end modules ['mtx-unzip'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- maybe --pattern

local format = string.format

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-unzip</entry>
  <entry name="detail">Simple Unzipper</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="list"><short>list files in archive</short></flag>
    <flag name="junk"><short>flatten unzipped directory structure</short></flag>
    <flag name="extract"><short>extract files</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-unzip",
    banner   = "Simple Unzipper 0.10",
    helpinfo = helpinfo,
}

local report = application.report

scripts          = scripts          or { }
scripts.unzipper = scripts.unzipper or { }

function scripts.unzipper.opened()
    local filename = environment.files[1]
    if filename and filename ~= "" then
        filename = file.addsuffix(filename,'zip')
        local zipfile = zip.open(filename)
        if zipfile then
            return zipfile
        end
    end
    report("no zip file: %s",filename)
    return false
end

function scripts.unzipper.list()
    local zipfile = scripts.unzipper.opened()
    if zipfile then
        local n = 0
        for k in zipfile:files() do
            if #k.filename > n then n = #k.filename end
        end
        local files, paths, compressed, uncompressed = 0, 0, 0, 0
        local template_a =   "%-"..n.."s"
        local template_b =   "%-"..n.."s  % 9i  % 9i"
        local template_c = "\n%-"..n.."s  % 9i  % 9i"
        for k in zipfile:files() do
            if k.filename:find("/$") then
                paths = paths + 1
                print(format(template_a, k.filename))
            else
                files = files + 1
                local cs, us = k.compressed_size, k.uncompressed_size
                if cs > compressed then
                    compressed = cs
                end
                if us > uncompressed then
                    uncompressed = us
                end
                print(format(template_b,k.filename,cs,us))
            end
        end -- check following pattern, n is not enough
        print(format(template_c,files .. " files, " .. paths .. " directories",compressed,uncompressed))
    end
end

function zip.loaddata(zipfile,filename)
    local f = zipfile:open(filename)
    if f then
        local data = f:read("*a")
        f:close()
        return data
    end
    return nil
end

function scripts.unzipper.extract()
    local zipfile = scripts.unzipper.opened()
    if zipfile then
        local junk = environment.arguments["j"] or environment.arguments["junk"]
        for k in zipfile:files() do
            local filename = k.filename
            if filename:find("/$") then
                if not junk then
                    lfs.mkdir(filename)
                end
            else
                local data = zip.loaddata(zipfile,filename)
                if data then
                    if junk then
                        filename = file.basename(filename)
                    end
                    io.savedata(filename,data)
                    print(filename)
                end
            end
        end
    end
end

if environment.arguments["h"] or environment.arguments["help"] then
    application.help()
elseif environment.arguments["l"] or environment.arguments["list"] then
    scripts.unzipper.list(zipfile)
elseif environment.arguments["exporthelp"] then
    application.export(environment.arguments["exporthelp"],environment.files[1])
elseif environment.files[1] then -- implicit --extract
    scripts.unzipper.extract(zipfile)
else
    application.help()
end
