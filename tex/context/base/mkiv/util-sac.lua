if not modules then modules = { } end modules ['util-sac'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- experimental string access (some 3 times faster than file access when messing
-- with bytes)

local byte, sub = string.byte, string.sub
local extract = bit32 and bit32.extract

utilities         = utilities or { }
local streams     = { }
utilities.streams = streams

function streams.open(filename,zerobased)
    local f = io.loaddata(filename)
    return { f, 1, #f, zerobased or false }
end

function streams.close()
    -- dummy
end

function streams.size(f)
    return f and f[3] or 0
end

function streams.setposition(f,i)
    if f[4] then
        -- zerobased
        if i <= 0 then
            f[2] = 1
        else
            f[2] = i + 1
        end
    else
        if i <= 1 then
            f[2] = 1
        else
            f[2] = i
        end
    end
end

function streams.getposition(f)
    if f[4] then
        -- zerobased
        return f[2] - 1
    else
        return f[2]
    end
end

function streams.look(f,n,chars)
    local b = f[2]
    local e = b + n - 1
    if chars then
        return sub(f[1],b,e)
    else
        return byte(f[1],b,e)
    end
end

function streams.skip(f,n)
    f[2] = f[2] + n
end

function streams.readbyte(f)
    local i = f[2]
    f[2] = i + 1
    return byte(f[1],i)
end

function streams.readbytes(f,n)
    local i = f[2]
    local j = i + n
    f[2] = j
    return byte(f[1],i,j-1)
end

function streams.readbytetable(f,n)
    local i = f[2]
    local j = i + n
    f[2] = j
    return { byte(f[1],i,j-1) }
end

function streams.skipbytes(f,n)
    f[2] = f[2] + n
end

function streams.readchar(f)
    local i = f[2]
    f[2] = i + 1
    return sub(f[1],i,i)
end

function streams.readstring(f,n)
    local i = f[2]
    local j = i + n
    f[2] = j
    return sub(f[1],i,j-1)
end

function streams.readinteger1(f)  -- one byte
    local i = f[2]
    f[2] = i + 1
    local n = byte(f[1],i)
    if n  >= 0x80 then
     -- return n - 0xFF - 1
        return n - 0x100
    else
        return n
    end
end

streams.readcardinal1 = streams.readbyte  -- one byte
streams.readcardinal  = streams.readcardinal1
streams.readinteger   = streams.readinteger1

function streams.readcardinal2(f)
    local i = f[2]
    local j = i + 1
    f[2] = j + 1
    local a, b = byte(f[1],i,j)
    return 0x100 * a + b
end

function streams.readinteger2(f)
    local i = f[2]
    local j = i + 1
    f[2] = j + 1
    local a, b = byte(f[1],i,j)
    local n = 0x100 * a + b
    if n  >= 0x8000 then
     -- return n - 0xFFFF - 1
        return n - 0x10000
    else
        return n
    end
end

function streams.readcardinal3(f)
    local i = f[2]
    local j = i + 2
    f[2] = j + 1
    local a, b, c = byte(f[1],i,j)
    return 0x10000 * a + 0x100 * b + c
end

function streams.readcardinal4(f)
    local i = f[2]
    local j = i + 3
    f[2] = j + 1
    local a, b, c, d = byte(f[1],i,j)
    return 0x1000000 * a + 0x10000 * b + 0x100 * c + d
end

function streams.readinteger4(f)
    local i = f[2]
    local j = i + 3
    f[2] = j + 1
    local a, b, c, d = byte(f[1],i,j)
    local n = 0x1000000 * a + 0x10000 * b + 0x100 * c + d
    if n  >= 0x8000000 then
     -- return n - 0xFFFFFFFF - 1
        return n - 0x100000000
    else
        return n
    end
end

function streams.readfixed4(f)
    local i = f[2]
    local j = i + 3
    f[2] = j + 1
    local a, b, c, d = byte(f[1],i,j)
    local n = 0x100 * a + b
    if n  >= 0x8000 then
     -- return n - 0xFFFF - 1 + (0x100 * c + d)/0xFFFF
        return n - 0x10000    + (0x100 * c + d)/0xFFFF
    else
        return n              + (0x100 * c + d)/0xFFFF
    end
end

if extract then

    function streams.read2dot14(f)
        local i = f[2]
        local j = i + 1
        f[2] = j + 1
        local a, b = byte(f[1],i,j)
        local n = 0x100 * a + b
        local m = extract(n,0,30)
        if n > 0x7FFF then
            n = extract(n,30,2)
            return m/0x4000 - 4
        else
            n = extract(n,30,2)
            return n + m/0x4000
        end
    end

end

function streams.skipshort(f,n)
    f[2] = f[2] + 2*(n or 1)
end

function streams.skiplong(f,n)
    f[2] = f[2] + 4*(n or 1)
end
