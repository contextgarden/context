if not modules then modules = { } end modules ['mtx-unzip'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- maybe --pattern

local format, find = string.format, string.find

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
    <flag name="extract"><short>extract files [--silent --steps]</short></flag>
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

local function validfile()
    local filename = environment.files[1]
    if filename and filename ~= "" then
        filename = file.addsuffix(filename,'zip')
        if lfs.isfile(filename) then
            return filename
        else
            report("invalid zip file: %s",filename)
        end
    else
        report("no zip file")
    end
    return false
end

function scripts.unzipper.list()
    local filename = validfile()
    if filename then
        local zipfile = utilities.zipfiles.open(filename)
        if zipfile then
            local list = utilities.zipfiles.list(zipfile)
            if list then
                local n = 0
                for i=1,#list do
                    local l = list[i]
                    if #l.filename > n then
                        n = #l.filename
                    end
                end
                local files, paths, compressed, uncompressed = 0, 0, 0, 0
                local template_a =   "%-" .. n .."s"
                local template_b =   "%-" .. n .."s  % 9i  % 9i"
                local template_c = "\n%-" .. n .."s  % 9i  % 9i"
                for i=1,#list do
                    local l = list[i]
                    local f = l.filename
                    if find(f,"/$") then
                        paths = paths + 1
                        print(format(template_a, f))
                    else
                        files = files + 1
                        local cs = l.compressed
                        local us = l.uncompressed
                        if cs > compressed then
                            compressed = cs
                        end
                        if us > uncompressed then
                            uncompressed = us
                        end
                        print(format(template_b,f,cs,us))
                    end
                end -- check following pattern, n is not enough
                print(format(template_c,files .. " files, " .. paths .. " directories",compressed,uncompressed))
            end
            utilities.zipfiles.close(zipfile)
        else
            report("invalid zip file: %s",filename)
        end
    end
end

function scripts.unzipper.extract()
    local filename = validfile()
    if validfile then
        -- todo --junk
        local silent = environment.arguments["silent"]
        local steps  = environment.arguments["steps"]
        utilities.zipfiles.unzipdir {
            zipname = filename,
            path    = ".",
            verbose = not silent and (steps and "steps" or true),
        }
    end
end

if environment.arguments["list"] then
    scripts.unzipper.list()
elseif environment.arguments["extract"] then
    scripts.unzipper.extract()
elseif environment.arguments["exporthelp"] then
    application.export(environment.arguments["exporthelp"],environment.files[1])
else
    application.help()
end
