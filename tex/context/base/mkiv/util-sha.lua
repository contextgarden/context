if not modules then modules = { } end modules ['util-sha'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    comment2  = "derived from Wikipedia and Lua support websites",
    comment3  = "due to bit operators this code only works in lua(tex) 5.3",
}

if sha2 then
    if utilities then
        utilities.sha2 = sha2
    end
    return sha2
end

-- This doesn't work in luajittex ... maybe some day it will have bit operators too.
-- I'm not really in the mood for making this module aware (by compiling the
-- function depending on the engine that I use but I probably won't use luajittex in
-- cases where I need this.)
--
-- Hm, it actually makes a case for the macro subsystem but we then also need to
-- make an unpack/pack replacement ... too boring.
--
-- This code is derived from:
--
--     http://lua-users.org/wiki/SecureHashAlgorithmBw
--
-- which in turn was a 5.3 variant of a 5.2 implementation by Roberto but it also
-- looks like a more or less direct translation of:
--
--     https://en.wikipedia.org/wiki/SHA-2
--
-- I optimized the code bit and added 512 support. For an explanation see the
-- mentioned websites. We don't do chunks here as we only need it for hashing
-- relatively small blobs (and even an image is not that large).
--
-- On short strings 256 seems faster than 512 while on a megabyte blob 512 wins
-- from 256 (64 bit internals).
--
-- Using the stream reader we can probably speed up the following code a bit
-- because it's faster than unpack.

local packstring, unpackstring, formatstring = string.pack, string.unpack, string.format
local repstring = string.rep

local constants256 = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local constants512 = {
    0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc, 0x3956c25bf348b538,
    0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118, 0xd807aa98a3030242, 0x12835b0145706fbe,
    0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2, 0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235,
    0xc19bf174cf692694, 0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
    0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5, 0x983e5152ee66dfab,
    0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4, 0xc6e00bf33da88fc2, 0xd5a79147930aa725,
    0x06ca6351e003826f, 0x142929670a0e6e70, 0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed,
    0x53380d139d95b3df, 0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
    0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30, 0xd192e819d6ef5218,
    0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8, 0x19a4c116b8d2d0c8, 0x1e376c085141ab53,
    0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8, 0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373,
    0x682e6ff3d6b2b8a3, 0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
    0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b, 0xca273eceea26619c,
    0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178, 0x06f067aa72176fba, 0x0a637dc5a2c898a6,
    0x113f9804bef90dae, 0x1b710b35131c471b, 0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc,
    0x431d67c49c100d4c, 0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817,
}

local prepare = { }

if utilities and utilities.strings then

    local r = utilities.strings.newrepeater("\0")

    prepare[256] = function(str,len)
        return str .. "\128" .. r[-(1 +  8 + len) %  64] .. packstring(">I8",  8 * len)
    end
    prepare[512] = function(str,len)
        return str .. "\128" .. r[-(1 + 16 + len) % 128] .. packstring(">I16", 8 * len)
    end

else

    prepare[256] = function(str,len)
        return str .. "\128" .. repstring("\0",-(1 +  8 + len) %  64) .. packstring(">I8",  8 * len)
    end
    prepare[512] = function(str,len)
        return str .. "\128" .. repstring("\0",-(1 + 16 + len) % 128) .. packstring(">I16", 8 * len)
    end

end

prepare[224] = prepare[256]
prepare[384] = prepare[512]

local initialize = {
    [224] = function(hash)
        hash[1] = 0xc1059ed8 hash[2] = 0x367cd507
        hash[3] = 0x3070dd17 hash[4] = 0xf70e5939
        hash[5] = 0xffc00b31 hash[6] = 0x68581511
        hash[7] = 0x64f98fa7 hash[8] = 0xbefa4fa4
        return hash
    end,
    [256] = function(hash)
        hash[1] = 0x6a09e667 hash[2] = 0xbb67ae85
        hash[3] = 0x3c6ef372 hash[4] = 0xa54ff53a
        hash[5] = 0x510e527f hash[6] = 0x9b05688c
        hash[7] = 0x1f83d9ab hash[8] = 0x5be0cd19
        return hash
    end,
    [384] = function(hash)
        hash[1] = 0xcbbb9d5dc1059ed8 hash[2] = 0x629a292a367cd507
        hash[3] = 0x9159015a3070dd17 hash[4] = 0x152fecd8f70e5939
        hash[5] = 0x67332667ffc00b31 hash[6] = 0x8eb44a8768581511
        hash[7] = 0xdb0c2e0d64f98fa7 hash[8] = 0x47b5481dbefa4fa4
        return hash
    end,
    [512] = function(hash)
        hash[1] = 0x6a09e667f3bcc908 hash[2] = 0xbb67ae8584caa73b
        hash[3] = 0x3c6ef372fe94f82b hash[4] = 0xa54ff53a5f1d36f1
        hash[5] = 0x510e527fade682d1 hash[6] = 0x9b05688c2b3e6c1f
        hash[7] = 0x1f83d9abfb41bd6b hash[8] = 0x5be0cd19137e2179
        return hash
    end,
}

local digest = { }
local list   = { } -- some 5% faster

digest[256] = function(str,i,hash)

    local hash1, hash2, hash3, hash4 = hash[1], hash[2], hash[3], hash[4]
    local hash5, hash6, hash7, hash8 = hash[5], hash[6], hash[7], hash[8]

    for i=1,#str,64 do

        list[ 1], list[ 2], list[ 3], list[ 4], list[ 5], list[ 6], list[ 7], list[ 8],
        list[ 9], list[10], list[11], list[12], list[13], list[14], list[15], list[16] =
            unpackstring(">I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4",str,i)

        for j=17,64 do
            local v0 = list[j - 15]
            local s0 = ((v0 >>  7) | (v0 << 25)) -- rrotate(v,  7)
                     ~ ((v0 >> 18) | (v0 << 14)) -- rrotate(v, 18)
                     ~  (v0 >>  3)
            local v1 = list[j -  2]
            local s1 = ((v1 >> 17) | (v1 << 15)) -- rrotate(v, 17)
                     ~ ((v1 >> 19) | (v1 << 13)) -- rrotate(v, 19)
                     ~  (v1 >> 10)
            list[j]  = (list[j - 16] + s0 + list[j - 7] + s1)
                     & 0xffffffff
        end

        local a, b, c, d, e, f, g, h =
            hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7], hash[8]

        for i=1,64 do
            local s0  = ((a >>  2) | (a << 30)) -- rrotate(a,  2)
                      ~ ((a >> 13) | (a << 19)) -- rrotate(a, 13)
                      ~ ((a >> 22) | (a << 10)) -- rrotate(a, 22)
            local maj = (a & b) ~ (a & c) ~ (b & c)
            local t2  = s0 + maj
            local s1  = ((e >>  6) | (e << 26)) -- rrotate(e,  6)
                      ~ ((e >> 11) | (e << 21)) -- rrotate(e, 11)
                      ~ ((e >> 25) | (e <<  7)) -- rrotate(e, 25)
            local ch  = (e & f)
                      ~ (~e & g)
            local t1  = h + s1 + ch + constants256[i] + list[i]
            h = g
            g = f
            f = e
            e = (d + t1) & 0xffffffff
            d = c
            c = b
            b = a
            a = (t1 + t2) & 0xffffffff
        end

        hash1 = (hash1 + a) & 0xffffffff
        hash2 = (hash2 + b) & 0xffffffff
        hash3 = (hash3 + c) & 0xffffffff
        hash4 = (hash4 + d) & 0xffffffff
        hash5 = (hash5 + e) & 0xffffffff
        hash6 = (hash6 + f) & 0xffffffff
        hash7 = (hash7 + g) & 0xffffffff
        hash8 = (hash8 + h) & 0xffffffff

    end

    return hash1, hash2, hash3, hash4, hash5, hash6, hash7, hash8

end

digest[512] = function(str,i,hash)

    local hash1, hash2, hash3, hash4 = hash[1], hash[2], hash[3], hash[4]
    local hash5, hash6, hash7, hash8 = hash[5], hash[6], hash[7], hash[8]

    for i=1,#str,128 do

        list[ 1], list[ 2], list[ 3], list[ 4], list[ 5], list[ 6], list[ 7], list[ 8],
        list[ 9], list[10], list[11], list[12], list[13], list[14], list[15], list[16] =
            unpackstring(">I8I8I8I8I8I8I8I8I8I8I8I8I8I8I8I8",str,i)

        for j=17,80 do
            local v0 = list[j - 15]
            local s0 = ((v0 >>  1) | (v0 << 63)) -- rrotate(v,  1)
                     ~ ((v0 >>  8) | (v0 << 56)) -- rrotate(v,  8)
                     ~  (v0 >>  7)
            local v1 = list[j -  2]
            local s1 = ((v1 >> 19) | (v1 << 45)) -- rrotate(v, 19)
                     ~ ((v1 >> 61) | (v1 <<  3)) -- rrotate(v, 61)
                     ~  (v1 >>  6)
            list[j]  = (list[j - 16] + s0 + list[j - 7] + s1)
                  -- & 0xffffffffffffffff
        end

        local a, b, c, d, e, f, g, h =
            hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7], hash[8]

        for i=1,80 do
            local s0  = ((a >> 28) | (a << 36)) -- rrotate(a, 28)
                      ~ ((a >> 34) | (a << 30)) -- rrotate(a, 34)
                      ~ ((a >> 39) | (a << 25)) -- rrotate(a, 39)
            local maj = (a & b) ~ (a & c) ~ (b & c)
            local t2  = s0 + maj
            local s1  = ((e >> 14) | (e << 50)) -- rrotate(e, 14)
                      ~ ((e >> 18) | (e << 46)) -- rrotate(e, 18)
                      ~ ((e >> 41) | (e << 23)) -- rrotate(e, 41)
            local ch  = (e & f)
                      ~ (~e & g)
            local t1  = h + s1 + ch + constants512[i] + list[i]
            h = g
            g = f
            f = e
            e = (d + t1) -- & 0xffffffffffffffff
            d = c
            c = b
            b = a
            a = (t1 + t2) -- & 0xffffffffffffffff
        end

        hash1 = (hash1 + a) -- & 0xffffffffffffffff
        hash2 = (hash2 + b) -- & 0xffffffffffffffff
        hash3 = (hash3 + c) -- & 0xffffffffffffffff
        hash4 = (hash4 + d) -- & 0xffffffffffffffff
        hash5 = (hash5 + e) -- & 0xffffffffffffffff
        hash6 = (hash6 + f) -- & 0xffffffffffffffff
        hash7 = (hash7 + g) -- & 0xffffffffffffffff
        hash8 = (hash8 + h) -- & 0xffffffffffffffff

    end

    return hash1, hash2, hash3, hash4, hash5, hash6, hash7, hash8

end

digest[224] = digest[256]
digest[384] = digest[512]

local hash = { }

local function hashed(str,method,convert,pattern)
    local s = prepare[method](str,#str)
    local h = initialize[method](hash)
    return convert(pattern,digest[method](s,i,h))
end

local sha2 = {
    digest224 = function(str) return hashed(str,224,packstring,">I4I4I4I4I4I4I4")   end,
    digest256 = function(str) return hashed(str,256,packstring,">I4I4I4I4I4I4I4I4") end,
    digest384 = function(str) return hashed(str,384,packstring,">I8I8I8I8I8I8")     end,
    digest512 = function(str) return hashed(str,512,packstring,">I8I8I8I8I8I8I8I8") end,
    hash224   = function(str) return hashed(str,224,formatstring,"%0x04%0x04%0x04%0x04%0x04%0x04%0x04")      end,
    hash256   = function(str) return hashed(str,256,formatstring,"%0x04%0x04%0x04%0x04%0x04%0x04%0x04%0x04") end,
    hash384   = function(str) return hashed(str,384,formatstring,"%0x08%0x08%0x08%0x08%0x08%0x08")           end,
    hash512   = function(str) return hashed(str,512,formatstring,"%0x08%0x08%0x08%0x08%0x08%0x08%0x08%0x08") end,
    HASH224   = function(str) return hashed(str,224,formatstring,"%0X04%0X04%0X04%0X04%0X04%0X04%0X04")      end,
    HASH256   = function(str) return hashed(str,256,formatstring,"%0X04%0X04%0X04%0X04%0X04%0X04%0X04%0X04") end,
    HASH384   = function(str) return hashed(str,384,formatstring,"%0X08%0X08%0X08%0X08%0X08%0X08")           end,
    HASH512   = function(str) return hashed(str,512,formatstring,"%0X08%0X08%0X08%0X08%0X08%0X08%0X08%0X08") end,
}

-- The wikipedia provides the code:
--
--   https://en.wikipedia.org/wiki/SHA-1
--
-- and (nor being in th emood to writ it myself) a bit of googling gave a decent
-- starting point:
--
--   https://github.com/gdyr/LuaSHA1/blob/master/sha1.lua
--
-- and after that it was just a matter of optimizing the code a bit. I just put
-- it here as reference as we probably don't use it. We could use a repeater as
-- we do with sha2.

local function digest(str)

    local h1 = 0x67452301
    local h2 = 0xEFCDAB89
    local h3 = 0x98BADCFE
    local h4 = 0x10325476
    local h5 = 0xC3D2E1F0

    local len  = #str
    local list = { } -- we can even move this outside the function

    str = str .. "\128" .. repstring("\0", (120 - ((len + 1) % 64)) % 64) .. packstring(">I8", 8 * len)

    for i=1,#str,64 do

        list[ 1], list[ 2], list[ 3], list[ 4], list[ 5], list[ 6], list[ 7], list[ 8],
        list[ 9], list[10], list[11], list[12], list[13], list[14], list[15], list[16] =
            unpackstring(">I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4",str,i)

        for i=17,80 do
            local v = list[i-3] ~ list[i-8] ~ list[i-14] ~ list[i-16]
            list[i] = ((v << 1) | (v >> 31)) & 0xFFFFFFFF
        end

        local a, b, c, d, e = h1, h2, h3, h4, h5

        for i=1,20 do
            local f = (b & c) | ((~b) & d)
            local r = (a << 5) | (a >> 27)
            local s = (f + r + e + 0x5A827999 + list[i]) & 0xFFFFFFFF
            e = d
            d = c
            c = (b << 30) | (b >> 2)
            b = a
            a = s
        end

        for i=21,40 do
            local f = b ~ c ~ d
            local r = (a << 5) | (a >> 27)
            local s = (f + r + e + 0x6ED9EBA1 + list[i]) & 0xFFFFFFFF
            e = d
            d = c
            c = (b << 30) | (b >> 2)
            b = a
            a = s
        end

        for i=41,60 do
            local f = (b & c) | (b & d) | (c & d)
            local r = (a << 5) | (a >> 27)
            local s = (f + r + e + 0x8F1BBCDC + list[i]) & 0xFFFFFFFF
            e = d
            d = c
            c = (b << 30) | (b >> 2)
            b = a
            a = s
        end

        for i=61,80 do
            local f = b ~ c ~ d
            local r = (a << 5) | (a >> 27)
            local s = (f + r + e + 0xCA62C1D6 + list[i]) & 0xFFFFFFFF
            e = d
            d = c
            c = (b << 30) | (b >> (32 - 30))
            b = a
            a = s
        end

        h1 = (h1 + a) & 0xFFFFFFFF
        h2 = (h2 + b) & 0xFFFFFFFF
        h3 = (h3 + c) & 0xFFFFFFFF
        h4 = (h4 + d) & 0xFFFFFFFF
        h5 = (h5 + e) & 0xFFFFFFFF

    end

    return h1, h2, h3, h4, h5

end

-- A similar wrapper as we use for sha2:

local sha1 = {
    digest = function(str)
        return packstring(">I4I4I4I4I4",digest(str))
    end,
    hash = function(str)
        return formatstring("%08x%08x%08x%08x%08x",digest(str))
    end,
    HASH = function(str)
        return formatstring("%08X%08X%08X%08X%08X",digest(str))
    end,
}

if utilities then
    utilities.sha2 = sha2
    utilities.sha1 = sha1
end

return sha2
