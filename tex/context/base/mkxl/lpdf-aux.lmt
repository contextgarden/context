if not modules then modules = { } end modules ['lpdf-aux'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber
local format, concat = string.format, table.concat
local utfchar, utfbyte, char = utf.char, utf.byte, string.char
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local P, C, R, S, Cc, Cs, V = lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.Cc, lpeg.Cs, lpeg.V
local rshift = bit32.rshift

lpdf = lpdf or { }

-- tosixteen --

local cache = table.setmetatableindex(function(t,k) -- can be made weak
    local v = utfbyte(k)
    if v < 0x10000 then
        v = format("%04x",v)
    else
        v = format("%04x%04x",rshift(v,10),v%1024+0xDC00)
    end
    t[k] = v
    return v
end)

local unified = Cs(Cc("<feff") * (lpegpatterns.utf8character/cache)^1 * Cc(">"))

function lpdf.tosixteen(str) -- an lpeg might be faster (no table)
    if not str or str == "" then
        return "<feff>" -- not () as we want an indication that it's unicode
    else
        return lpegmatch(unified,str)
    end
end

-- fromsixteen --

-- local zero = S(" \n\r\t") + P("\\ ")
-- local one  = C(4)
-- local two  = P("d") * R("89","af") * C(2) * C(4)
--
-- local pattern = P { "start",
--     start     = V("wrapped") + V("unwrapped") + V("original"),
--     original  = Cs(P(1)^0),
--     wrapped   = P("<") * V("unwrapped") * P(">") * P(-1),
--     unwrapped = P("feff")
--               * Cs( (
--                     zero  / ""
--                   + two   / function(a,b)
--                                 a = (tonumber(a,16) - 0xD800) * 1024
--                                 b = (tonumber(b,16) - 0xDC00)
--                                 return utfchar(a+b)
--                             end
--                   + one   / function(a)
--                                 return utfchar(tonumber(a,16))
--                             end
--                 )^1 ) * P(-1)
-- }
--
-- function lpdf.fromsixteen(s)
--     return lpegmatch(pattern,s) or s
-- end

local more = 0

local pattern = C(4) / function(s) -- needs checking !
    local now = tonumber(s,16)
    if more > 0 then
        now = (more-0xD800)*0x400 + (now-0xDC00) + 0x10000 -- the 0x10000 smells wrong
        more = 0
        return utfchar(now)
    elseif now >= 0xD800 and now <= 0xDBFF then
        more = now
        return "" -- else the c's end up in the stream
    else
        return utfchar(now)
    end
end

local pattern = P(true) / function() more = 0 end * Cs(pattern^0)

function lpdf.fromsixteen(str)
    if not str or str == "" then
        return ""
    else
        return lpegmatch(pattern,str)
    end
end

-- frombytes --

local b_pattern = Cs((P("\\")/"" * (
    S("()")
  + S("nrtbf")/ { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f" }
  + lpegpatterns.octdigit^-3 / function(s) return char(tonumber(s,8)) end)
+ P(1))^0)

local u_pattern = lpegpatterns.utfbom_16_be * lpegpatterns.utf16_to_utf8_be -- official
                + lpegpatterns.utfbom_16_le * lpegpatterns.utf16_to_utf8_le -- we've seen these

local h_pattern = lpegpatterns.hextobytes

local zero = S(" \n\r\t") + P("\\ ")
local one  = C(4)
local two  = P("d") * R("89","af") * C(2) * C(4)

local x_pattern = P { "start",
    start     = V("wrapped") + V("unwrapped") + V("original"),
    original  = Cs(P(1)^0),
    wrapped   = P("<") * V("unwrapped") * P(">") * P(-1),
    unwrapped = P("feff")
              * Cs( (
                    zero  / ""
                  + two   / function(a,b)
                                a = (tonumber(a,16) - 0xD800) * 1024
                                b = (tonumber(b,16) - 0xDC00)
                                return utfchar(a+b)
                            end
                  + one   / function(a)
                                return utfchar(tonumber(a,16))
                            end
                )^1 ) * P(-1)
}

function lpdf.frombytes(s,hex)
    if not s or s == "" then
        return ""
    end
    if hex then
        local x = lpegmatch(x_pattern,s)
        if x then
            return x
        end
        local h = lpegmatch(h_pattern,s)
        if h then
            return h
        end
    else
        local u = lpegmatch(u_pattern,s)
        if u then
            return u
        end
    end
    return lpegmatch(b_pattern,s)
end

-- done --
