if not modules then modules = { } end modules ['util-tar'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, tonumber = type, tonumber
local gsub, escapedpattern = string.gsub, string.escapedpattern
local nameonly, dirname, makedirs = file.nameonly, file.dirname, dir.makedirs
local savedata = io.savedata
local newreader = io.newreader

local report = logs.reporter("tar")

local types = {
    ["0"]  = "file",
    ["\0"] = "regular",
    ["1"]  = "link",
    ["2"]  = "symbolic",     -- reserved
    ["3"]  = "character",
    ["4"]  = "block",
    ["5"]  = "directory",
    ["6"]  = "fifo",
    ["7"]  = "continuation", -- reserved
    ["x"]  = "extended",     -- header
}

local function asstring(str)
    return str and gsub(str,"[\0 ]+$","") or nil
end

local function asnumber(str)
    str = gsub(str,"\0$","")
    return tonumber(str,8)
end

local function opentar(whatever,filename)
    local f = newreader(filename,whatever)
    if f then
        f.metadata = {
            nofpaths = 0,
            noffiles = 0,
            noflinks = 0,
            nofbytes = 0,
        }
        return f
    end
end

local function readheader(t)
    -- checksum
    local p = t:getposition()
    local h = t:readbytetable(512)
    t:setposition(p)
    for i=149,156 do -- nasty, one less
        h[i] = 0
    end
    local c = 256
    for i=1,512 do
        c = c + h[i]
    end
    --
    local header = {
        name     = asstring(t:readstring(100)),    --   0
        mode     = asnumber(t:readstring(  8)), -- 100 -- when we write: 0775 octal
        uid      = asnumber(t:readstring(  8)), -- 108
        gid      = asnumber(t:readstring(  8)), -- 116
        size     = asnumber(t:readstring( 12)), -- 124
        mtime    = asnumber(t:readstring( 12)), -- 136
        checksum = asnumber(t:readstring(  6)), -- 148 -- actually 6 with space and \0
        dummy    =          t:skip        (2) ,
        typeflag =          t:readstring(  1) , -- 156
        linkname = asstring(t:readstring(100)), -- 157
     -- magic    = asstring(t:readstring(  6)), -- 257 -- ustar\0
     -- version  =                         2    -- 263
     -- uname    =                        32    -- 265
     -- gname    =                        32    -- 297
     -- devmajor =                         8    -- 329
     -- devminor =                         8    -- 337
     -- prefix   =                       155    -- 345
        padding  =          t:skip      (255) , -- 500
    }
    local typeflag = header.typeflag
    if typeflag then
        header.filetype = types[typeflag]
        if c == header.checksum then
            return header
        end
    end
end

local readers = {

    directory = function(t,h)
        local metadata = t.metadata
        local filename = h.name
        if metadata.verbose then
            report("%8s   %s","",filename)
        end
        metadata.nofpaths = metadata.nofpaths + 1
        return true
    end,

    file = function(t,h)
        local metadata = t.metadata
        local filename = h.name
        local filesize = h.size
        local pathname = dirname(filename)
        if metadata.verbose then
            report("% 8i : %s",filesize,filename)
        end
        if makedirs(pathname) then
            savedata(filename,t:readstring(filesize))
        else
            t.skip(filesize)
        end
        local position = t:getposition()
        local target   = position + (512 - position % 512) % 512
        t:setposition(target)
        metadata.noffiles = metadata.noffiles + 1
        metadata.nofbytes = metadata.nofbytes + filesize
        return true
    end,

    link = function(t,h)
        local metadata = t.metadata
        local filename = h.name
        local linkname = h.linkname
        if metadata.verbose then
            report("%8s   %s => %s","",linkname,filename)
        end
        metadata.noflinks = metadata.noflinks + 1
        return true
    end,

}

local skippers = {

    directory = function(t,h)
        return true
    end,

    file = function(t,h)
        local filesize   = h.size
        local fileoffset = t:getposition()
        local position   = filesize + fileoffset
        local target     = position + (512 - position % 512) % 512
        t:setposition(target)
        return fileoffset
    end,

    link = function(t,h)
        return true
    end,

}

local writers = {
    -- nothing here (yet)
}

local function saveheader(t,h)
    local filetype = h.filetype
    local reader   = readers[filetype]
    if reader then
        return filetype, reader(t,h)
    else
        report("no reader for %s",filetype)
    end
end

local function skipheader(t,h)
    local filetype = h.filetype
    local skipper  = skippers[filetype]
    if skipper then
        return filetype, skipper(t,h)
    else
        report("no skipper for %s",filetype)
    end
end

local function unpacktar(whatever,filename,verbose)
    local t = opentar(whatever,filename)
    if t then
        local metadata = t.metadata
        statistics.starttiming(metadata)
        if verbose then
            if whatever == "string" then
                report("unpacking: %i bytes",#filename)
            else
                report("unpacking: %s",filename)
            end
            report("")
            metadata.verbose = verbose
        end
        while true do
            local h = readheader(t)
            if not h then
                break
            else
                local filetype, saved = saveheader(t,h)
                if not saved then
                    break
                end
            end
        end
        statistics.stoptiming(metadata)
        metadata.runtime = statistics.elapsed(metadata)
        if verbose then
            report("")
            report("number of paths : %i",metadata.nofpaths)
            report("number of files : %i",metadata.noffiles)
            report("number of links : %i",metadata.noflinks)
            report("number of bytes : %i",metadata.nofbytes)
            report("")
            report("runtime needed  : %s",statistics.elapsedseconds(metadata))
            report("")
        end
        t.close()
        return metadata
    end
end

local function listtar(whatever,filename,onlyfiles)
    local t = opentar(whatever,filename)
    if t then
        local list, n = { }, 0
        while true do
            local h = readheader(t)
            if not h then
                break
            else
                local filetype, offset = skipheader(t,h)
                if not offset then
                    break
                elseif filetype == "file" then
                    n = n + 1 ; list[n] = { filetype, h.name, h.size }
                elseif filetype == "link" then
                    n = n + 1 ; list[n] = { filetype, h.name, h.linkfile }
                elseif not onlyfiles then
                    n = n + 1 ; list[n] = { filetype, h.name }
                end
            end
        end
        t.close()
        -- can be an option
        table.sort(list,function(a,b) return a[2] < b[2] end)
        return list
    end
end

local function hashtar(whatever,filename,strip)
    local t = opentar(whatever,filename)
    if t then
        local list = { }
        if strip then
            strip = "^" .. escapedpattern(nameonly(nameonly(strip))) .. "/"
        end
        while true do
            local h = readheader(t)
            if not h then
                break
            else
                local filetype, offset = skipheader(t,h)
                if not offset then
                    break
                else
                    local name = h.name
                    if strip then
                        name = gsub(name,strip,"")
                    end
                    if filetype == "file" then
                        list[name] = { offset, h.size }
                    elseif filetype == "link" then
                        list[name] = h.linkname
                    end
                end
            end
        end
        t.close()
        return list
    end
end

-- weak table ?

local function fetchtar(whatever,archive,filename,list)
    if not list then
        list = hashtar(whatever,archive)
    end
    if list then
        local what = list[filename]
        if type(what) == "string" then
            what = list[what] -- a link
        end
        if what then
            local t = opentar(whatever,archive)
            if t then
                t:setposition(what[1])
                return t:readstring(what[2])
            end
        end
    end
end

local function packtar(whatever,filename,verbose)
    report("packing will be implemented when we need it")
end

local tar = {
    files = {
        unpack = function(...) return unpacktar("file",  ...) end,
        pack   = function(...) return packtar  ("file",  ...) end,
        list   = function(...) return listtar  ("file",  ...) end,
        hash   = function(...) return hashtar  ("file",  ...) end,
        fetch  = function(...) return fetchtar ("file",  ...) end,
    },
    strings = {
        unpack = function(...) return unpacktar("string",...) end,
        pack   = function(...) return packtar  ("string",...) end,
        list   = function(...) return listtar  ("string",...) end,
        hash   = function(...) return hashtar  ("string",...) end,
        fetch  = function(...) return fetchtar ("string",...) end,
    },
    streams = {
        unpack = function(...) return unpacktar("stream",...) end,
        pack   = function(...) return packtar  ("stream",...) end,
        list   = function(...) return listtar  ("stream",...) end,
        hash   = function(...) return hashtar  ("stream",...) end,
        fetch  = function(...) return fetchtar ("stream",...) end,
    },
}

utilities.tar = tar

-- tar.files  .unpack("e:/luatex/luametatex-source.tar",true)
-- tar.streams.unpack("e:/luatex/luametatex-source.tar",true)
-- tar.strings.unpack(io.loaddata("e:/luatex/luametatex-source.tar"),true)

-- inspect(tar.files  .unpack("e:/luatex/luametatex-source.tar"))
-- inspect(tar.streams.unpack("e:/luatex/luametatex-source.tar"))
-- inspect(tar.strings.unpack(io.loaddata("e:/luatex/luametatex-source.tar")))

-- inspect(tar.files  .list("e:/luatex/luametatex-source.tar",true))
-- inspect(tar.streams.list("e:/luatex/luametatex-source.tar",true))
-- inspect(tar.strings.list(io.loaddata("e:/luatex/luametatex-source.tar"),true))

-- local c = os.clock()
-- local l = tar.files.hash("e:/luatex/luametatex-source.tar")
-- for i=1,500 do
--     local s = tar.files.fetch("e:/luatex/luametatex-source.tar", "luametatex-source/source/tex/texbuildpage.c", l)
--     local s = tar.files.fetch( "e:/luatex/luametatex-source.tar","luametatex-source/source/lua/lmtlibrary.c",   l)
-- end
-- print(os.clock()-c)

return tar
