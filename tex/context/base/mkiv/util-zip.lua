if not modules then modules = { } end modules ['util-zip'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module is mostly meant for relative simple zip and unzip tasks. We can read
-- and write zip files but with limitations. Performance is quite good and it makes
-- us independent of zip tools, which (for some reason) are not always installed.
--
-- This is an lmtx module and at some point will be lmtx only but for a while we
-- keep some hybrid functionality.

local type, tostring, tonumber = type, tostring, tonumber
local sort = table.sort

local find, format, sub, gsub = string.find, string.format, string.sub, string.gsub
local osdate, ostime, osclock = os.date, os.time, os.clock
local ioopen = io.open
local loaddata, savedata = io.loaddata, io.savedata
local filejoin, isdir, dirname, mkdirs = file.join, lfs.isdir, file.dirname, dir.mkdirs

local files         = utilities.files
local openfile      = files.open
local closefile     = files.close
local readstring    = files.readstring
local readcardinal2 = files.readcardinal2le
local readcardinal4 = files.readcardinal4le
local setposition   = files.setposition
local getposition   = files.getposition

local band          = bit32.band
local rshift        = bit32.rshift
local lshift        = bit32.lshift

local decompress, expandsize, calculatecrc

-- if flate then
--
--     decompress   = flate.flate_decompress
--     calculatecrc = flate.update_crc32
--
-- else

    local zlibdecompress = zlib.decompress
    local zlibexpandsize = zlib.expandsize
    local zlibchecksum   = zlib.crc32

    decompress = function(source)
        return zlibdecompress(source,-15) -- auto
    end

    expandsize = zlibexpandsize and function(source,targetsize)
        return zlibexpandsize(source,targetsize,-15) -- auto
    end or decompress

    calculatecrc = function(buffer,initial)
        return zlibchecksum(initial or 0,buffer)
    end

-- end

local zipfiles      = { }
utilities.zipfiles  = zipfiles

local openzipfile, closezipfile, unzipfile, foundzipfile, getziphash, getziplist  do

    function openzipfile(name)
        return {
            name   = name,
            handle = openfile(name,0),
        }
    end

    local function collect(z)
        if not z.list then
            local list     = { }
            local hash     = { }
            local position = 0
            local index    = 0
            local handle   = z.handle
            while true do
                setposition(handle,position)
                local signature = readstring(handle,4)
                if signature == "PK\3\4" then
                    -- [local file header 1]
                    -- [encryption header 1]
                    -- [file data 1]
                    -- [data descriptor 1]
                    local version      = readcardinal2(handle)
                    local flag         = readcardinal2(handle)
                    local method       = readcardinal2(handle)
                    local filetime     = readcardinal2(handle)
                    local filedate     = readcardinal2(handle)
                    local crc32        = readcardinal4(handle)
                    local compressed   = readcardinal4(handle)
                    local uncompressed = readcardinal4(handle)
                    local namelength   = readcardinal2(handle)
                    local extralength  = readcardinal2(handle)
                    local filename     = readstring(handle,namelength)
                    local descriptor   = band(flag,8) ~= 0
                    local encrypted    = band(flag,1) ~= 0
                    local acceptable   = method == 0 or method == 8
                    -- 30 bytes of header including the signature
                    local skipped      = 0
                    local size         = 0
                    if encrypted then
                        size = readcardinal2(handle)
                        skipbytes(size)
                        skipped = skipped + size + 2
                        skipbytes(8)
                        skipped = skipped + 8
                        size = readcardinal2(handle)
                        skipbytes(size)
                        skipped = skipped + size + 2
                        size = readcardinal4(handle)
                        skipbytes(size)
                        skipped = skipped + size + 4
                        size = readcardinal2(handle)
                        skipbytes(size)
                        skipped = skipped + size + 2
                    end
                    position = position + 30 + namelength + extralength + skipped
                    if descriptor then
                        setposition(handle,position + compressed)
                        crc32        = readcardinal4(handle)
                        compressed   = readcardinal4(handle)
                        uncompressed = readcardinal4(handle)
                    end
                    if acceptable then
                        index = index + 1
                        local data = {
                            filename     = filename,
                            index        = index,
                            position     = position,
                            method       = method,
                            compressed   = compressed,
                            uncompressed = uncompressed,
                            crc32        = crc32,
                            encrypted    = encrypted,
                        }
                        hash[filename] = data
                        list[index]    = data
                    else
                        -- maybe a warning when encrypted
                    end
                    position = position + compressed
                else
                    break
                end
                z.list = list
                z.hash = hash
            end
        end
    end

    function getziplist(z)
        local list = z.list
        if not list then
            collect(z)
        end
        return z.list
    end

    function getziphash(z)
        local hash = z.hash
        if not hash then
            collect(z)
        end
        return z.hash
    end

    function foundzipfile(z,name)
        return getziphash(z)[name]
    end

    function closezipfile(z)
        local f = z.handle
        if f then
            closefile(f)
            z.handle = nil
        end
    end

    function unzipfile(z,filename,check)
        local hash = z.hash
        if not hash then
            hash = zipfiles.hash(z)
        end
        local data = hash[filename] -- normalize
        if not data then
            -- lower and cleanup
            -- only name
        end
        if data then
            local handle     = z.handle
            local position   = data.position
            local compressed = data.compressed
            if compressed > 0 then
                setposition(handle,position)
                local result = readstring(handle,compressed)
                if data.method == 8 then
                    if expandsize then
                        result = expandsize(result,data.uncompressed)
                    else
                        result = decompress(result)
                    end
                end
                if check and data.crc32 ~= calculatecrc(result) then
                    print("checksum mismatch")
                    return ""
                end
                return result
            else
                return ""
            end
        end
    end

    zipfiles.open  = openzipfile
    zipfiles.close = closezipfile
    zipfiles.unzip = unzipfile
    zipfiles.hash  = getziphash
    zipfiles.list  = getziplist
    zipfiles.found = foundzipfile

end

if xzip then -- flate then do

    local writecardinal1 = files.writebyte
    local writecardinal2 = files.writecardinal2le
    local writecardinal4 = files.writecardinal4le

    local logwriter      = logs.writer

    local globpattern    = dir.globpattern
--     local compress       = flate.flate_compress
--     local checksum       = flate.update_crc32
    local compress       = xzip.compress
    local checksum       = xzip.crc32

 -- local function fromdostime(dostime,dosdate)
 --     return ostime {
 --         year  = (dosdate >>  9) + 1980, -- 25 .. 31
 --         month = (dosdate >>  5) & 0x0F, -- 21 .. 24
 --         day   = (dosdate      ) & 0x1F, -- 16 .. 20
 --         hour  = (dostime >> 11)       , -- 11 .. 15
 --         min   = (dostime >>  5) & 0x3F, --  5 .. 10
 --         sec   = (dostime      ) & 0x1F, --  0 ..  4
 --     }
 -- end
 --
 -- local function todostime(time)
 --     local t = osdate("*t",time)
 --     return
 --         ((t.year - 1980) <<  9) + (t.month << 5) +  t.day,
 --          (t.hour         << 11) + (t.min   << 5) + (t.sec >> 1)
 -- end

    local function fromdostime(dostime,dosdate)
        return ostime {
            year  =      rshift(dosdate, 9) + 1980,  -- 25 .. 31
            month = band(rshift(dosdate, 5),  0x0F), -- 21 .. 24
            day   = band(      (dosdate   ),  0x1F), -- 16 .. 20
            hour  = band(rshift(dostime,11)       ), -- 11 .. 15
            min   = band(rshift(dostime, 5),  0x3F), --  5 .. 10
            sec   = band(      (dostime   ),  0x1F), --  0 ..  4
        }
    end

    local function todostime(time)
        local t = osdate("*t",time)
        return
            lshift(t.year - 1980, 9) + lshift(t.month,5) +        t.day,
            lshift(t.hour       ,11) + lshift(t.min  ,5) + rshift(t.sec,1)
    end

    local function openzip(filename,level,comment,verbose)
        local f = ioopen(filename,"wb")
        if f then
            return {
                filename     = filename,
                handle       = f,
                list         = { },
                level        = tonumber(level) or 3,
                comment      = tostring(comment),
                verbose      = verbose,
                uncompressed = 0,
                compressed   = 0,
            }
        end
    end

    local function writezip(z,name,data,level,time)
        local f        = z.handle
        local list     = z.list
        local level    = tonumber(level) or z.level or 3
        local method   = 8
        local zipped   = compress(data,level)
        local checksum = checksum(data)
        local verbose  = z.verbose
        --
        if not zipped then
            method = 0
            zipped = data
        end
        --
        local start        = f:seek()
        local compressed   = #zipped
        local uncompressed = #data
        --
        z.compressed   = z.compressed   + compressed
        z.uncompressed = z.uncompressed + uncompressed
        --
        if verbose then
            local pct = 100 * compressed/uncompressed
            if pct >= 100 then
                logwriter(format("%10i        %s",uncompressed,name))
            else
                logwriter(format("%10i  %02.1f  %s",uncompressed,pct,name))
            end
        end
        --
        f:write("\x50\x4b\x03\x04") -- PK..  0x04034b50
        --
        writecardinal2(f,0)            -- minimum version
        writecardinal2(f,0)            -- flag
        writecardinal2(f,method)       -- method
        writecardinal2(f,0)            -- time
        writecardinal2(f,0)            -- date
        writecardinal4(f,checksum)     -- crc32
        writecardinal4(f,compressed)   -- compressed
        writecardinal4(f,uncompressed) -- uncompressed
        writecardinal2(f,#name)        -- namelength
        writecardinal2(f,0)            -- extralength
        --
        f:write(name)                  -- name
        f:write(zipped)
        --
        list[#list+1] = { #zipped, #data, name, checksum, start, time or 0 }
    end

    local function closezip(z)
        local f       = z.handle
        local list    = z.list
        local comment = z.comment
        local verbose = z.verbose
        local count   = #list
        local start   = f:seek()
        --
        for i=1,count do
            local l = list[i]
            local compressed   = l[1]
            local uncompressed = l[2]
            local name         = l[3]
            local checksum     = l[4]
            local start        = l[5]
            local time         = l[6]
            local date, time   = todostime(time)
            f:write('\x50\x4b\x01\x02')
            writecardinal2(f,0)            -- version made by
            writecardinal2(f,0)            -- version needed to extract
            writecardinal2(f,0)            -- flags
            writecardinal2(f,8)            -- method
            writecardinal2(f,time)         -- time
            writecardinal2(f,date)         -- date
            writecardinal4(f,checksum)     -- crc32
            writecardinal4(f,compressed)   -- compressed
            writecardinal4(f,uncompressed) -- uncompressed
            writecardinal2(f,#name)        -- namelength
            writecardinal2(f,0)            -- extralength
            writecardinal2(f,0)            -- commentlength
            writecardinal2(f,0)            -- nofdisks -- ?
            writecardinal2(f,0)            -- internal attr (type)
            writecardinal4(f,0)            -- external attr (mode)
            writecardinal4(f,start)        -- local offset
            f:write(name)                  -- name
        end
        --
        local stop = f:seek()
        local size = stop - start
        --
        f:write('\x50\x4b\x05\x06')
        writecardinal2(f,0)            -- disk
        writecardinal2(f,0)            -- disks
        writecardinal2(f,count)        -- entries
        writecardinal2(f,count)        -- entries
        writecardinal4(f,size)         -- dir size
        writecardinal4(f,start)        -- dir offset
        if type(comment) == "string" and comment ~= "" then
            writecardinal2(f,#comment) -- comment length
            f:write(comment)           -- comemnt
        else
            writecardinal2(f,0)
        end
        --
        if verbose then
            local compressed   = z.compressed
            local uncompressed = z.uncompressed
            local filename     = z.filename
            --
            local pct = 100 * compressed/uncompressed
            logwriter("")
            if pct >= 100 then
                logwriter(format("%10i        %s",uncompressed,filename))
            else
                logwriter(format("%10i  %02.1f  %s",uncompressed,pct,filename))
            end
        end
        --
        f:close()
    end

    local function zipdir(zipname,path,level,verbose)
        if type(zipname) == "table" then
            verbose = zipname.verbose
            level   = zipname.level
            path    = zipname.path
            zipname = zipname.zipname
        end
        if not zipname or zipname == "" then
            return
        end
        if not path or path == "" then
            path = "."
        end
        if not isdir(path) then
            return
        end
        path = gsub(path,"\\+","/")
        path = gsub(path,"/+","/")
        local list  = { }
        local count = 0
        globpattern(path,"",true,function(name,size,time)
            count = count + 1
            list[count] = { name, time }
        end)
        sort(list,function(a,b)
            return a[1] < b[1]
        end)
        local zipf = openzip(zipname,level,comment,verbose)
        if zipf then
            local p = #path + 2
            for i=1,count do
                local li   = list[i]
                local name = li[1]
                local time = li[2]
                local data = loaddata(name)
                local name = sub(name,p,#name)
                writezip(zipf,name,data,level,time,verbose)
            end
            closezip(zipf)
        end
    end

    local function unzipdir(zipname,path,verbose)
        if type(zipname) == "table" then
            verbose = zipname.verbose
            path    = zipname.path
            zipname = zipname.zipname
        end
        if not zipname or zipname == "" then
            return
        end
        if not path or path == "" then
            path = "."
        end
        local z = openzipfile(zipname)
        if z then
            local list = getziplist(z)
            if list then
                local total = 0
                local count = #list
                local step  = number.idiv(count,10)
                local done  = 0
                local steps = verbose == "steps"
                local time  = steps and osclock()
                for i=1,count do
                    local l = list[i]
                    local n = l.filename
                    local d = unzipfile(z,n) -- true for check
                    if d then
                        local p = filejoin(path,n)
                        if mkdirs(dirname(p)) then
                            if steps then
                                total = total + #d
                                done = done + 1
                                if done >= step then
                                    done = 0
                                    logwriter(format("%4i files of %4i done, %10i bytes, %0.3f seconds",i,count,total,osclock()-time))
                                end
                            elseif verbose then
                                logwriter(n)
                            end
                            savedata(p,d)
                        end
                    else
                        logwriter(format("problem with file %s",n))
                    end
                end
                if steps then
                    logwriter(format("%4i files of %4i done, %10i bytes, %0.3f seconds",count,count,total,osclock()-time))
                end
                closezipfile(z)
                return true
            else
                closezipfile(z)
            end
        end
    end

    zipfiles.zipdir   = zipdir
    zipfiles.unzipdir = unzipdir

end

zipfiles.gunzipfile = gzip.load

-- if flate then
--
--     local streams       = utilities.streams
--     local openfile      = streams.open
--     local closestream   = streams.close
--     local setposition   = streams.setposition
--     local getsize       = streams.size
--     local readcardinal4 = streams.readcardinal4le
--     local getstring     = streams.getstring
--     local decompress    = flate.gz_decompress
--
--     -- id1=1 id2=1 method=1 flags=1 mtime=4(le) extra=1 os=1
--     -- flags:8 comment=...<nul> flags:4 name=...<nul> flags:2 extra=...<nul> flags:1 crc=2
--     -- data:?
--     -- crc=4 size=4
--
--     function zipfiles.gunzipfile(filename)
--         local strm = openfile(filename)
--         if strm then
--             setposition(strm,getsize(strm) - 4 + 1)
--             local size = readcardinal4(strm)
--             local data = decompress(getstring(strm),size)
--             closestream(strm)
--             return data
--         end
--     end
--
-- elseif gzip then
--
--     local openfile = gzip.open
--
--     function zipfiles.gunzipfile(filename)
--         local g = openfile(filename,"rb")
--         if g then
--             local d = g:read("*a")
--             d:close()
--             return d
--         end
--     end
--
-- end

return zipfiles
