if not modules then modules = { } end modules ['data-dec'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local loaddata = io.loaddata
local suffix   = file.suffix
local resultof = os.resultof

local decompressors     = { }
resolvers.decompressors = decompressors

local decompresslzma = nil
local decompressgzip = gzip.decompress

local function decompressed(k)
    local s = suffix(k)
    if s == "xz" then
        if decompresslzma == nil then
            local lzma = require(resolvers.findfile("libs-imp-lzma.lmt"))
            if lzma then
                local decompress = lzma.decompress
                decompresslzma = function(name)
                    return decompress(loaddata(k))
                end
            else
                decompresslzma = function(name)
                    -- todo: use a proper runner
                    return resultof("xz -d -c -q -q " .. name)
                end
            end
        end
        return decompresslzma(k)
    elseif s == "gz" then
        return decompressgzip(loaddata(k))
    end
end

local cache = table.setmetatableindex(function(t,k)
    local v = decompressed(k) or false
    t[k] = v
    return v
end)

decompressors.decompress = decompress

function decompressors.register(filename)
    return cache[filename]
end

function decompressors.unregister(filename)
    cache[filename] = nil
end
