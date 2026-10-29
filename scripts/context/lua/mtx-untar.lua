if not modules then modules = { } end modules ['mtx-untar'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- maybe --pattern

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-untar</entry>
  <entry name="detail">Simple Untarballer</entry>
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
    name     = "mtx-untar",
    banner   = "Simple Untarballer 0.10",
    helpinfo = helpinfo,
}

local report     = application.report
local tar        = utilities.tar
local formatted  = string.formatted

-- if not xz then
--     report("this only works with luametatex (lmtx)")
--     return
-- end

scripts          = scripts          or { }
scripts.unballer = scripts.unballer or { }

local function validfile()
    local filename = environment.files[1]
    if filename and filename ~= "" then
        filename = file.addsuffix(filename,'tar')
        if lfs.isfile(filename) then
            return filename
        else
            report("invalid tar file: %s",filename)
        end
    else
        report("no tar file")
    end
    return false
end

function scripts.unballer.list()
    local filename = validfile()
    if filename then
        local list = tar.files.list(filename)
        if list then
            local d = 0
            local f = 0
            local s = 0
            local l = 0
            for i=1,#list do
                local entry = list[i]
                local kind  = entry[1]
                if kind == "file" then
                    local name = entry[2]
                    local size = entry[3]
                    print(formatted("% 9i  %s",size,name))
                    f = f + 1
                    s = s + size
                elseif kind == "directory" then
                    d = d + 1
                elseif kind == "link" then
                    l = l + 1
                end
            end
            if not environment.arguments.silent then
                print("")
                print(formatted(
                    "% 9i  %i files, %i directories, %i links",
                    s,f,d,l
                ))
            end
        end
    end
end

function scripts.unballer.extract(verbose)
    local filename = validfile()
    if filename then
        local done = tar.files.unpack(filename,verbose)
        if not environment.arguments.silent then
            local dtime = done.decompresstime or 0
            print(formatted(
                dtime > 0 and
                    "%i files, %i directories, %i links, %i bytes, %0.3f seconds, %0.3f seconds decompression"
                or
                    "%i files, %i directories, %i links, %i bytes, %0.3f seconds"
                ,
                done.nofpaths,done.noffiles,done.noflinks,done.nofbytes,
                done.runtime, dtime
            ))
        end
    end
end

if environment.arguments["list"] then
    scripts.unballer.list()
elseif environment.arguments["extract"] then
    scripts.unballer.extract(environment.arguments["verbose"])
elseif environment.arguments["exporthelp"] then
    application.export(environment.arguments["exporthelp"],environment.files[1])
else
    application.help()
end
