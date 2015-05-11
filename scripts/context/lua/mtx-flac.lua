if not modules then modules = { } end modules ['mtx-flac'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local sub, match, byte, lower = string.sub, string.match, string.byte, string.lower
local readstring, readnumber = io.readstring, io.readnumber
local concat, sortedpairs, sort, keys = table.concat, table.sortedpairs, table.sort, table.keys
local tonumber = tonumber
local tobitstring = number.tobitstring
local lpegmatch = lpeg.match
local p_escaped = lpeg.patterns.xml.escaped

-- rather silly: pack info in bits while a flac file is large anyway

flac = flac or { }

flac.report = string.format

local splitter = lpeg.splitat("=")
local readers  = { }

readers[0] = function(f,size,target) -- not yet ok .. todo: use bit32 lib
    local info = { }
    target.info = info
    info.minimum_block_size = readnumber(f,-2)
    info.maximum_block_size = readnumber(f,-2)
    info.minimum_frame_size = readnumber(f,-3)
    info.maximum_frame_size = readnumber(f,-3)
    local buffer = { }
    for i=1,8 do
        buffer[i] = tobitstring(readnumber(f,1))
    end
    local bytes = concat(buffer)
    info.sample_rate_in_hz  = tonumber(sub(bytes, 1,20),2) -- 20
    info.number_of_channels = tonumber(sub(bytes,21,23),2) --  3
    info.bits_per_sample    = tonumber(sub(bytes,24,28),2) --  5
    info.samples_in_stream  = tonumber(sub(bytes,29,64),2) -- 36
    info.md5_signature = readstring(f,16) -- 128
end

readers[4] = function(f,size,target,banner)
    local tags = { }
    target.tags = tags
    target.vendor = readstring(f,readnumber(f,-4))
    for i=1,readnumber(f,-4) do
        local key, value = lpeg.match(splitter,readstring(f,readnumber(f,-4)))
        tags[lower(key)] = value
    end
end

readers.default = function(f,size,target)
    f:seek("cur",size)
end

local valid = {
    ["fLaC"] = true,
    ["ID3♥"] = false,
}

function flac.getmetadata(filename)
    local f = io.open(filename, "rb")
    if f then
        local banner  = readstring(f,4)
        local whatsit = valid[banner]
        if whatsit ~= nil then
            if whatsit == false then
                flac.report("suspicious flac file: %s (%s)",filename,banner)
            end
            local data = {
                banner   = banner,
                filename = filename,
                filesize = lfs.attributes(filename,"size"),
            }
            while true do
                local flag = readnumber(f,1)
                local size = readnumber(f,3)
                local last = flag > 127
                if last then
                    flag = flag - 128
                end
                local reader = readers[flag] or readers.default
                reader(f,size,data,banner)
                if last then
                    f:close()
                    return data
                end
            end
        else
            flac.report("no flac file: %s (%s)",filename,banner)
        end
        f:close()
    else
        flac.report("no file: %s",filename)
    end
end

function flac.savecollection(pattern,filename)
    pattern = (pattern ~= "" and pattern) or "**/*.flac"
    filename = (filename ~= "" and filename) or "music-collection.xml"
    flac.report("identifying files using pattern %q" ,pattern)
    local files = dir.glob(pattern)
    flac.report("%s files found, analyzing files",#files)
    local music = { }
    sort(files)
    for i=1,#files do
        local name = files[i]
        local data = flac.getmetadata(name)
        if data then
            local tags   = data.tags
            local info   = data.info
            if tags and info then
                local artist = tags.artist or "no-artist"
                local album  = tags.album  or "no-album"
                local albums = music[artist]
                if not albums then
                    albums = { }
                    music[artist] = albums
                end
                local albumx = albums[album]
                if not albumx then
                    albumx = {
                        year   = tags.date,
                        tracks = { },
                    }
                    albums[album] = albumx
                end
                albumx.tracks[tonumber(tags.tracknumber) or 0] = {
                    title  = tags.title,
                    length = math.round((info.samples_in_stream/info.sample_rate_in_hz)),
                }
            else
                flac.report("unable to read file",name)
            end
        end
    end
    --
    local nofartists = 0
    local nofalbums  = 0
    local noftracks  = 0
    local noferrors  = 0
    --
    local allalbums
    local function compare(a,b)
        local ya = allalbums[a].year or 0
        local yb = allalbums[b].year or 0
        if ya == yb then
            return a < b
        else
            return ya < yb
        end
    end
    local function getlist(albums)
        allalbums = albums
        local list = keys(albums)
        sort(list,compare)
        return list
    end
    --
    filename = file.addsuffix(filename,"xml")
    local f = io.open(filename,"wb")
    if f then
        flac.report("saving data in file %q",filename)
        f:write("<?xml version='1.0' standalone='yes'?>\n\n")
        f:write("<collection>\n")
        for artist, albums in sortedpairs(music) do
            nofartists = nofartists + 1
            f:write("\t<artist>\n")
            f:write("\t\t<name>",lpegmatch(p_escaped,artist),"</name>\n")
            f:write("\t\t<albums>\n")
            local list = getlist(albums)
            nofalbums = nofalbums + #list
            for nofalbums=1,#list do
                local album = list[nofalbums]
                local data  = albums[album]
                f:write("\t\t\t<album year='",data.year or 0,"'>\n")
                f:write("\t\t\t\t<name>",lpegmatch(p_escaped,album),"</name>\n")
                f:write("\t\t\t\t<tracks>\n")
                local tracks = data.tracks
                for i=1,#tracks do
                    local track = tracks[i]
                    if track then
                        noftracks = noftracks + 1
                        f:write("\t\t\t\t\t<track length='",track.length,"'>",lpegmatch(p_escaped,track.title),"</track>\n")
                    else
                        noferrors = noferrors + 1
                        flac.report("error in album: %q of %q, no track %s",album,artist,i)
                        f:write("\t\t\t\t\t<error track='",i,"'/>\n")
                    end
                end
                f:write("\t\t\t\t</tracks>\n")
                f:write("\t\t\t</album>\n")
            end
            f:write("\t\t</albums>\n")
            f:write("\t</artist>\n")
        end
        f:write("</collection>\n")
        f:close()
        flac.report("%s tracks of %s albums of %s artists saved in %q (%s errors)",noftracks,nofalbums,nofartists,filename,noferrors)
        -- a secret option for alan braslau
        if environment.argument("bibtex") then
            filename = file.replacesuffix(filename,"bib")
            local f = io.open(filename,"wb")
            if f then
                local n = 0
                for artist, albums in sortedpairs(music) do
                    local list = getlist(albums)
                    for nofalbums=1,#list do
                        n = n + 1
                        local album  = list[nofalbums]
                        local data   = albums[album]
                        local tracks = data.tracks
                        f:write("@cd{entry-",n,",\n")
                        f:write("\tartist   = {",artist,"},\n")
                        f:write("\ttitle    = {",album or "no title","},\n")
                        f:write("\tyear     = {",data.year or 0,"},\n")
                        f:write("\ttracks   = {",#tracks,"},\n")
                        for i=1,#tracks do
                            local track = tracks[i]
                            if track then
                                noftracks = noftracks + 1
                                f:write("\ttrack:",i,"  = {",track.title,"},\n")
                                f:write("\tlength:",i," = {",track.length,"},\n")
                            end
                        end
                        f:write("}\n")
                    end
                end
                f:close()
                flac.report("additional bibtex file generated: %s",filename)
            end
        end
        --
    else
        flac.report("unable to save data in file %q",filename)
    end
end

--

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-flac</entry>
  <entry name="detail">ConTeXt Flac Helpers</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="collect"><short>collect albums in xml file</short></flag>
    <flag name="pattern"><short>use pattern for locating files</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Example</title>
   <subcategory>
    <example><command>mtxrun --script flac --collect somename.flac</command></example>
    <example><command>mtxrun --script flac --collect --pattern="m:/music/**")</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-flac",
    banner   = "ConTeXt Flac Helpers 0.10",
    helpinfo = helpinfo,
}

flac.report = application.report

-- script code

scripts      = scripts      or { }
scripts.flac = scripts.flac or { }

function scripts.flac.collect()
    local files   = environment.files
    local pattern = environment.arguments.pattern
    if #files > 0 then
        for i=1,#files do
            local filename = files[1]
            if file.suffix(filename) == "flac" then
                flac.savecollection(filename,file.replacesuffix(filename,"xml"))
            elseif lfs.isdir(filename) then
                local pattern = filename .. "/**.flac"
                flac.savecollection(pattern,file.addsuffix(file.basename(filename),"xml"))
            else
                flac.savecollection(file.replacesuffix(filename,"flac"),file.replacesuffix(filename,"xml"))
            end
        end
    elseif pattern then
        flac.savecollection(file.addsuffix(pattern,"flac"),"music-collection.xml")
    else
        flac.report("no file(s) or pattern given" )
    end
end

if environment.argument("collect") then
    scripts.flac.collect()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
