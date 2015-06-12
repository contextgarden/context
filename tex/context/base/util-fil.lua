if not modules then modules = { } end modules ['util-fil'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local byte    = string.byte
local extract = bit32.extract

-- Here are a few helpers (the starting point were old ones I used for parsing
-- flac files). In Lua 5.3 we can probably do this better. Some code will move
-- here.

utilities       = utilities or { }
local files     = { }
utilities.files = files

function files.readbyte(f)
    return byte(f:read(1))
end

function files.readchar(f)
    return f:read(1)
end

function files.readbytes(f,n)
    return byte(f:read(n),1,n)
end

function files.skipbytes(f,n)
    f:read(n or 1) -- or a seek
end

function files.readinteger1(f)  -- one byte
    local n = byte(f:read(1))
    if n  >= 0x80 then
        return n - 0xFF - 1
    else
        return n
    end
end

files.readcardinal1 = files.readbyte  -- one byte
files.readcardinal  = files.readcardinal1
files.readinteger   = files.readinteger1

function files.readcardinal2(f)
    local a, b = byte(f:read(2),1,2)
    return 0x100 * a + b
end

function files.readinteger2(f)
    local a, b = byte(f:read(2),1,2)
    local n = 0x100 * a + b
    if n  >= 0x8000 then
        return n - 0xFFFF - 1
    else
        return n
    end
end

function files.readcardinal3(f)
    local a, b, c = byte(f:read(3),1,3)
    return 0x10000 * a + 0x100 * b + c
end

function files.readcardinal4(f)
    local a, b, c, d = byte(f:read(4),1,4)
    return 0x1000000 * a + 0x10000 * b + 0x100 * c + d
end

function files.readinteger4(f)
    local a, b, c, d = byte(f:read(4),1,4)
    local n = 0x1000000 * a + 0x10000 * b + 0x100 * c + d
    if n  >= 0x8000000 then
        return n - 0xFFFFFFFF - 1
    else
        return n
    end
end

function files.readfixed4(f)
    local a, b, c, d = byte(f:read(4),1,4)
    local n = 0x100 * a + b
    if n  >= 0x8000 then
        return n - 0xFFFF - 1 + (0x100 * c + d)/0xFFFF
    else
        return n              + (0x100 * c + d)/0xFFFF
    end
end

function files.readstring(f,n)
    return f:read(n or 1)
end

function files.read2dot14(f)
    local a, b = byte(f:read(2),1,2)
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
