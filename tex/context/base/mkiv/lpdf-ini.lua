if not modules then modules = { } end modules ['lpdf-ini'] = {
    version   = 1.001,
    comment   = "companion to lpdf-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- beware of "too many locals" here

local setmetatable, getmetatable, type, next, tostring, tonumber, rawset = setmetatable, getmetatable, type, next, tostring, tonumber, rawset
local char, byte, format, gsub, concat, match, sub, gmatch = string.char, string.byte, string.format, string.gsub, table.concat, string.match, string.sub, string.gmatch
local utfchar, utfbyte, utfvalues = utf.char, utf.byte, utf.values
local sind, cosd, max, min = math.sind, math.cosd, math.max, math.min
local sort, sortedhash = table.sort, table.sortedhash
local P, C, R, S, Cc, Cs, V = lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.Cc, lpeg.Cs, lpeg.V
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local formatters = string.formatters
local isboolean = string.is_boolean
local rshift = bit32.rshift
local osdate, ostime = os.date, os.time

local report_objects    = logs.reporter("backend","objects")
local report_finalizing = logs.reporter("backend","finalizing")
local report_blocked    = logs.reporter("backend","blocked")

local implement         = interfaces.implement
local two_strings       = interfaces.strings[2]

local context           = context

-- In ConTeXt MkIV we use utf8 exclusively so all strings get mapped onto a hex
-- encoded utf16 string type between <>. We could probably save some bytes by using
-- strings between () but then we end up with escaped ()\ too.

pdf                     = type(pdf) == "table" and pdf or { }
local factor            = number.dimenfactors.bp

local codeinjections    = { }
local nodeinjections    = { }

local backends          = backends

local pdfbackend        = {
    comment        = "backend for directly generating pdf output",
    nodeinjections = nodeinjections,
    codeinjections = codeinjections,
    registrations  = { },
    tables         = { },
}

backends.pdf = pdfbackend

lpdf       = lpdf or { }
local lpdf = lpdf
lpdf.flags = lpdf.flags or { } -- will be filled later

local trace_finalizers = false  trackers.register("backend.finalizers", function(v) trace_finalizers = v end)
local trace_resources  = false  trackers.register("backend.resources",  function(v) trace_resources  = v end)
local trace_objects    = false  trackers.register("backend.objects",    function(v) trace_objects    = v end)
local trace_details    = false  trackers.register("backend.details",    function(v) trace_details    = v end)

do

    local pdfsetmajorversion, pdfsetminorversion, pdfgetmajorversion, pdfgetminorversion
    local pdfsetcompresslevel, pdfsetobjectcompresslevel, pdfgetcompresslevel, pdfgetobjectcompresslevel
    local pdfsetsuppressoptionalinfo, pdfsetomitcidset, pdfsetomitcharset

    updaters.register("backend.update.lpdf",function()
        pdfsetmajorversion         = pdf.setmajorversion
        pdfsetminorversion         = pdf.setminorversion
        pdfgetmajorversion         = pdf.getmajorversion
        pdfgetminorversion         = pdf.getminorversion

        pdfsetcompresslevel        = pdf.setcompresslevel
        pdfsetobjectcompresslevel  = pdf.setobjcompresslevel
        pdfgetcompresslevel        = pdf.getcompresslevel
        pdfgetobjectcompresslevel  = pdf.getobjcompresslevel

        pdfsetsuppressoptionalinfo = pdf.setsuppressoptionalinfo
        pdfsetomitcidset           = pdf.setomitcidset
        pdfsetomitcharset          = pdf.setomitcharset
    end)

    function lpdf.setversion(major,minor)
        pdfsetmajorversion(major or 1)
        pdfsetminorversion(minor or 7)
    end

    function lpdf.getversion(major,minor)
        return pdfgetmajorversion(), pdfgetminorversion()
    end

    function lpdf.majorversion() return pdfgetmajorversion() end
    function lpdf.minorversion() return pdfgetminorversion() end

    local frozen = false
    local clevel = 3
    local olevel = 1

    function lpdf.setcompression(level,objectlevel,freeze)
        if not frozen then
            if pdfsetcompresslevel then
                pdfsetcompresslevel(level or 3)
                pdfsetobjectcompresslevel(objectlevel or level or 3)
            else
                clevel = level
                olevel = objectlevel
            end
            frozen = freeze
        end
    end

    function lpdf.getcompression()
        if pdfgetcompresslevel then
            return pdfgetcompresslevel(), pdfgetobjectcompresslevel()
        else
            return clevel, olevel
        end
    end

    function lpdf.compresslevel()
        if pdfgetcompresslevel then
            return pdfgetcompresslevel()
        else
            return clevel
        end
    end

    function lpdf.objectcompresslevel()
        if pdfgetobjectcompresslevel then
            return pdfgetobjectcompresslevel()
        else
            return olevel
        end
    end

    function lpdf.setsuppressoptionalinfo(n)
        if pdfsetsuppressoptionalinfo then
            pdfsetsuppressoptionalinfo(n) -- todo
        end
    end

    function lpdf.setomitcidset(v)
        return pdfsetomitcidset(v)
    end

    function lpdf.setomitcharset(v)
        return pdfsetomitcharset(v)
    end

end

do

    local pdfgetxformname, pdfincludeimage

    updaters.register("backend.update.lpdf",function()
        pdfgetxformname = pdf.getxformname
        pdfincludeimage = pdf.includeimage
    end)

    function lpdf.getxformname(id) return pdfgetxformname(id) end
    function lpdf.includeimage(id) return pdfincludeimage(id) end

end

    local pdfsetpageresources, pdfsetpageattributes, pdfsetpagesattributes
    local pdfreserveobject, pdfimmediateobject, pdfdeferredobject, pdfreferenceobject
    local pdfgetpagereference

    updaters.register("backend.update.lpdf",function()
        pdfreserveobject      = pdf.reserveobj
        pdfimmediateobject    = pdf.immediateobj
        pdfdeferredobject     = pdf.obj
        pdfreferenceobject    = pdf.refobj

        pdfgetpagereference   = pdf.getpageref

        pdfsetpageresources   = pdf.setpageresources
        pdfsetpageattributes  = pdf.setpageattributes
        pdfsetpagesattributes = pdf.setpagesattributes
    end)

local jobpositions = job.positions
local getpos       = jobpositions.getpos
local getrpos      = jobpositions.getrpos

jobpositions.registerhandlers {
    getpos  = pdf.getpos,
 -- getrpos = pdf.getrpos,
    gethpos = pdf.gethpos,
    getvpos = pdf.getvpos,
}

do

    local pdfgetmatrix, pdfhasmatrix, pdfprint

    updaters.register("backend.update.lpdf",function()
        pdfgetmatrix = pdf.getmatrix
        pdfhasmatrix = pdf.hasmatrix
        pdfprint     = pdf.print
    end)

    function lpdf.print(...)
        return pdfprint(...)
    end

    -- local function transform(llx,lly,urx,ury,rx,sx,sy,ry)
    --     local x1 = llx * rx + lly * sy
    --     local y1 = llx * sx + lly * ry
    --     local x2 = llx * rx + ury * sy
    --     local y2 = llx * sx + ury * ry
    --     local x3 = urx * rx + lly * sy
    --     local y3 = urx * sx + lly * ry
    --     local x4 = urx * rx + ury * sy
    --     local y4 = urx * sx + ury * ry
    --     llx = min(x1,x2,x3,x4);
    --     lly = min(y1,y2,y3,y4);
    --     urx = max(x1,x2,x3,x4);
    --     ury = max(y1,y2,y3,y4);
    --     return llx, lly, urx, ury
    -- end
    --
    -- function lpdf.transform(llx,lly,urx,ury) -- not yet used so unchecked
    --     if pdfhasmatrix() then
    --         local sx, rx, ry, sy = pdfgetmatrix()
    --         local w, h = urx - llx, ury - lly
    --         return llx, lly, llx + sy*w - ry*h, lly + sx*h - rx*w
    --      -- return transform(llx,lly,urx,ury,sx,rx,ry,sy)
    --     else
    --         return llx, lly, urx, ury
    --     end
    -- end

    -- funny values for tx and ty

    function lpdf.rectangle(width,height,depth,offset)
        local tx, ty = getpos() -- pdfgetpos, maybe some day use dir here
        if offset then
            tx     = tx     -   offset
            ty     = ty     +   offset
            width  = width  + 2*offset
            height = height +   offset
            depth  = depth  +   offset
        end
        if pdfhasmatrix() then
            local rx, sx, sy, ry = pdfgetmatrix()
            return
                factor *  tx,
                factor * (ty - ry*depth  + sx*width),
                factor * (tx + rx*width  - sy*height),
                factor * (ty + ry*height - sx*width)
        else
            return
                factor *  tx,
                factor * (ty - depth),
                factor * (tx + width),
                factor * (ty + height)
        end
    end

end

-- we could use a hash of predefined unicodes

-- local function tosixteen(str) -- an lpeg might be faster (no table)
--     if not str or str == "" then
--         return "<feff>" -- not () as we want an indication that it's unicode
--     else
--         local r, n = { "<feff" }, 1
--         for b in utfvalues(str) do
--             n = n + 1
--             if b < 0x10000 then
--                 r[n] = format("%04x",b)
--             else
--                 r[n] = format("%04x%04x",rshift(b,10),b%1024+0xDC00)
--             end
--         end
--         n = n + 1
--         r[n] = ">"
--         return concat(r)
--     end
-- end

local tosixteen, fromsixteen, topdfdoc, frompdfdoc, toeight, fromeight

do

    local escaped = Cs(Cc("(") * (S("\\()\n\r\t\b\f")/"\\%0" + P(1))^0 * Cc(")"))

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

    local unified = Cs(Cc("<feff") * (lpeg.patterns.utf8character/cache)^1 * Cc(">"))

    tosixteen = function(str) -- an lpeg might be faster (no table)
        if not str or str == "" then
            return "<feff>" -- not () as we want an indication that it's unicode
        else
            return lpegmatch(unified,str)
        end
    end

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

    fromsixteen = function(str)
        if not str or str == "" then
            return ""
        else
            return lpegmatch(pattern,str)
        end
    end

    local toregime   = regimes.toregime
    local fromregime = regimes.fromregime

    topdfdoc = function(str,default)
        if not str or str == "" then
            return ""
        else
            return lpegmatch(escaped,toregime("pdfdoc",str,default)) -- could be combined if needed
        end
    end

    frompdfdoc = function(str)
        if not str or str == "" then
            return ""
        else
            return fromregime("pdfdoc",str)
        end
    end

    if not toregime   then topdfdoc   = function(s) return s end end
    if not fromregime then frompdfdoc = function(s) return s end end

    toeight = function(str)
        if not str or str == "" then
            return "()"
        else
            return lpegmatch(escaped,str)
        end
    end

    local b_pattern = Cs((P("\\")/"" * (
        S("()")
      + S("nrtbf") / { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f" }
      + lpegpatterns.octdigit^-3 / function(s) return char(tonumber(s,8)) end)
    + P(1))^0)

    fromeight = function(str)
        if not str or str == "" then
            return ""
        else
            return lpegmatch(unescape,str)
        end
    end

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

    lpdf.tosixteen   = tosixteen
    lpdf.toeight     = toeight
    lpdf.topdfdoc    = topdfdoc
    lpdf.fromsixteen = fromsixteen
    lpdf.fromeight   = fromeight
    lpdf.frompdfdoc  = frompdfdoc

end

local tostring_a, tostring_d

do

    local f_key_null       = formatters["/%s null"]
    local f_key_value      = formatters["/%s %s"]
    local f_key_dictionary = formatters["/%s << % t >>"]
    local f_dictionary     = formatters["<< % t >>"]
    local f_key_array      = formatters["/%s [ % t ]"]
    local f_array          = formatters["[ % t ]"]
    local f_key_number     = formatters["/%s %N"]  -- always with max 9 digits and integer is possible
    local f_tonumber       = formatters["%N"]      -- always with max 9 digits and integer is possible

    tostring_d = function(t,contentonly,key)
        if next(t) then
            local r = { }
            local n = 0
            local e
            for k, v in next, t do
                if k == "__extra__" then
                    e = v
                elseif k == "__stream__" then
                    -- do nothing (yet)
                else
                    n = n + 1
                    r[n] = k
                end
            end
            if n > 1 then
                sort(r)
            end
            for i=1,n do
                local k  = r[i]
                local v  = t[k]
                local tv = type(v)
                -- mostly tables
                if tv == "table" then
                 -- local mv = getmetatable(v)
                 -- if mv and mv.__lpdftype then
                    if v.__lpdftype__ then
                     -- if v == t then
                     --     report_objects("ignoring circular reference in dirctionary")
                     --     r[i] = f_key_null(k)
                     -- else
                            r[i] = f_key_value(k,tostring(v))
                     -- end
                    elseif v[1] then
                        r[i] = f_key_value(k,tostring_a(v))
                    else
                        r[i] = f_key_value(k,tostring_d(v))
                    end
                elseif tv == "string" then
                    r[i] = f_key_value(k,toeight(v))
                elseif tv == "number" then
                    r[i] = f_key_number(k,v)
                else
                    r[i] = f_key_value(k,tostring(v))
                end
            end
            if e then
                r[n+1] = e
            end
            if contentonly then
                return concat(r," ")
            elseif key then
                return f_key_dictionary(key,r)
            else
                return f_dictionary(r)
            end
        elseif contentonly then
            return ""
        else
            return "<< >>"
        end
    end

    tostring_a = function(t,contentonly,key)
        local tn = #t
        if tn ~= 0 then
            local r = { }
            for k=1,tn do
                local v = t[k]
                local tv = type(v)
                -- mostly numbers and tables
                if tv == "number" then
                    r[k] = f_tonumber(v)
                elseif tv == "table" then
                 -- local mv = getmetatable(v)
                 -- if mv and mv.__lpdftype then
                    if v.__lpdftype__ then
                     -- if v == t then
                     --     report_objects("ignoring circular reference in array")
                     --     r[k] = "null"
                     -- else
                            r[k] = tostring(v)
                     -- end
                    elseif v[1] then
                        r[k] = tostring_a(v)
                    else
                        r[k] = tostring_d(v)
                    end
                elseif tv == "string" then
                    r[k] = toeight(v)
                else
                    r[k] = tostring(v)
                end
            end
            local e = t.__extra__
            if e then
                r[tn+1] = e
            end
            if contentonly then
                return concat(r, " ")
            elseif key then
                return f_key_array(key,r)
            else
                return f_array(r)
            end
        elseif contentonly then
            return ""
        else
            return "[ ]"
        end
    end

end

local f_tonumber = formatters["%N"]

local tostring_x = function(t) return concat(t," ")       end
local tostring_s = function(t) return toeight(t[1])       end
local tostring_p = function(t) return topdfdoc(t[1],t[2]) end
local tostring_u = function(t) return tosixteen(t[1])     end
----- tostring_n = function(t) return tostring(t[1])      end -- tostring not needed
local tostring_n = function(t) return f_tonumber(t[1])    end -- tostring not needed
local tostring_c = function(t) return t[1]                end -- already prefixed (hashed)
local tostring_z = function()  return "null"              end
local tostring_t = function()  return "true"              end
local tostring_f = function()  return "false"             end
local tostring_r = function(t) local n = t[1] return n and n > 0 and (n .. " 0 R") or "null" end

local tostring_v = function(t)
    local s = t[1]
    if type(s) == "table" then
        return concat(s)
    else
        return s
    end
end

local tostring_l = function(t)
    local s = t[1]
    if not s or s == "" then
        return "()"
    elseif t[2] then
        return "<" .. s .. ">"
    else
        return "(" .. s .. ")"
    end
end

local function value_x(t) return t                  end
local function value_s(t) return t[1]               end
local function value_p(t) return t[1]               end
local function value_u(t) return t[1]               end
local function value_n(t) return t[1]               end
local function value_c(t) return sub(t[1],2)        end
local function value_d(t) return tostring_d(t,true) end
local function value_a(t) return tostring_a(t,true) end
local function value_z()  return nil                end
local function value_t(t) return t.value or true    end
local function value_f(t) return t.value or false   end
local function value_r(t) return t[1] or 0          end -- null
local function value_v(t) return t[1]               end
local function value_l(t) return t[1]               end

local function add_to_d(t,v)
    local k = type(v)
    if k == "string" then
        if t.__extra__ then
            t.__extra__ = t.__extra__ .. " " .. v
        else
            t.__extra__ = v
        end
    elseif k == "table" then
        for k, v in next, v do
            t[k] = v
        end
    end
    return t
end

local function add_to_a(t,v)
    local k = type(v)
    if k == "string" then
        if t.__extra__ then
            t.__extra__ = t.__extra__ .. " " .. v
        else
            t.__extra__ = v
        end
    elseif k == "table" then
        local n = #t
        for i=1,#v do
            n = n + 1
            t[n] = v[i]
        end
    end
    return t
end

local function add_x(t,k,v) rawset(t,k,tostring(v)) end

-- local mt_x = { __index = { __lpdftype__ = "stream"     }, __lpdftype = "stream",     __tostring = tostring_x, __call = value_x, __newindex = add_x }
-- local mt_d = { __index = { __lpdftype__ = "dictionary" }, __lpdftype = "dictionary", __tostring = tostring_d, __call = value_d, __add = add_to_d }
-- local mt_a = { __index = { __lpdftype__ = "array"      }, __lpdftype = "array",      __tostring = tostring_a, __call = value_a, __add = add_to_a }
-- local mt_u = { __index = { __lpdftype__ = "unicode"    }, __lpdftype = "unicode",    __tostring = tostring_u, __call = value_u }
-- local mt_s = { __index = { __lpdftype__ = "string"     }, __lpdftype = "string",     __tostring = tostring_s, __call = value_s }
-- local mt_p = { __index = { __lpdftype__ = "docstring"  }, __lpdftype = "docstring",  __tostring = tostring_p, __call = value_p }
-- local mt_n = { __index = { __lpdftype__ = "number"     }, __lpdftype = "number",     __tostring = tostring_n, __call = value_n }
-- local mt_c = { __index = { __lpdftype__ = "constant"   }, __lpdftype = "constant",   __tostring = tostring_c, __call = value_c }
-- local mt_z = { __index = { __lpdftype__ = "null"       }, __lpdftype = "null",       __tostring = tostring_z, __call = value_z }
-- local mt_t = { __index = { __lpdftype__ = "true"       }, __lpdftype = "true",       __tostring = tostring_t, __call = value_t }
-- local mt_f = { __index = { __lpdftype__ = "false"      }, __lpdftype = "false",      __tostring = tostring_f, __call = value_f }
-- local mt_r = { __index = { __lpdftype__ = "reference"  }, __lpdftype = "reference",  __tostring = tostring_r, __call = value_r }
-- local mt_v = { __index = { __lpdftype__ = "verbose"    }, __lpdftype = "verbose",    __tostring = tostring_v, __call = value_v }
-- local mt_l = { __index = { __lpdftype__ = "literal"    }, __lpdftype = "literal",    __tostring = tostring_l, __call = value_l }

local mt_x = { __index = { __lpdftype__ = "stream"     }, __tostring = tostring_x, __call = value_x, __newindex = add_x }
local mt_d = { __index = { __lpdftype__ = "dictionary" }, __tostring = tostring_d, __call = value_d, __add = add_to_d }
local mt_a = { __index = { __lpdftype__ = "array"      }, __tostring = tostring_a, __call = value_a, __add = add_to_a }
local mt_u = { __index = { __lpdftype__ = "unicode"    }, __tostring = tostring_u, __call = value_u }
local mt_s = { __index = { __lpdftype__ = "string"     }, __tostring = tostring_s, __call = value_s }
local mt_p = { __index = { __lpdftype__ = "docstring"  }, __tostring = tostring_p, __call = value_p }
local mt_n = { __index = { __lpdftype__ = "number"     }, __tostring = tostring_n, __call = value_n }
local mt_c = { __index = { __lpdftype__ = "constant"   }, __tostring = tostring_c, __call = value_c }
local mt_z = { __index = { __lpdftype__ = "null"       }, __tostring = tostring_z, __call = value_z }
local mt_t = { __index = { __lpdftype__ = "true"       }, __tostring = tostring_t, __call = value_t }
local mt_f = { __index = { __lpdftype__ = "false"      }, __tostring = tostring_f, __call = value_f }
local mt_r = { __index = { __lpdftype__ = "reference"  }, __tostring = tostring_r, __call = value_r }
local mt_v = { __index = { __lpdftype__ = "verbose"    }, __tostring = tostring_v, __call = value_v }
local mt_l = { __index = { __lpdftype__ = "literal"    }, __tostring = tostring_l, __call = value_l }

local function pdfstream(t) -- we need to add attributes
    if t then
        local tt = type(t)
        if tt == "table" then
            for i=1,#t do
                t[i] = tostring(t[i])
            end
        elseif tt == "string" then
            t = { t }
        else
            t = { tostring(t) }
        end
    end
    return setmetatable(t or { },mt_x)
end

local function pdfdictionary(t)
    return setmetatable(t or { },mt_d)
end

local function pdfarray(t)
    if type(t) == "string" then
        return setmetatable({ t },mt_a)
    else
        return setmetatable(t or { },mt_a)
    end
end

local function pdfstring(str,default)
    return setmetatable({ str or default or "" },mt_s)
end

local function pdfdocstring(str,default,defaultchar)
    return setmetatable({ str or default or "", defaultchar or " " },mt_p)
end

local function pdfunicode(str,default)
    return setmetatable({ str or default or "" },mt_u) -- could be a string
end

local function pdfliteral(str,hex) -- can also produce a hex <> instead of () literal
    return setmetatable({ str, hex },mt_l)
end

local pdfnumber, pdfconstant

do

    local cache = { } -- can be weak

    pdfnumber = function(n,default) -- 0-10
        if not n then
            n = default
        end
        local c = cache[n]
        if not c then
            c = setmetatable({ n },mt_n)
        --  cache[n] = c -- too many numbers
        end
        return c
    end

    for i=-1,9 do cache[i] = pdfnumber(i) end

    local replacer = S("\0\t\n\r\f ()[]{}/%%#\\") / {
        ["\00"]="#00",
        ["\09"]="#09",
        ["\10"]="#0a",
        ["\12"]="#0c",
        ["\13"]="#0d",
        [ " " ]="#20",
        [ "#" ]="#23",
        [ "%" ]="#25",
        [ "(" ]="#28",
        [ ")" ]="#29",
        [ "/" ]="#2f",
        [ "[" ]="#5b",
        [ "\\"]="#5c",
        [ "]" ]="#5d",
        [ "{" ]="#7b",
        [ "}" ]="#7d",
    } + P(1)

    local escaped = Cs(Cc("/") * replacer^0)

    local cache = table.setmetatableindex(function(t,k)
        local v = setmetatable({ lpegmatch(escaped,k) }, mt_c)
        t[k] = v
        return v
    end)

    pdfconstant = function(str,default)
        if not str then
            str = default or "none"
        end
        return cache[str]
    end

    local escaped = Cs(replacer^0)

    function lpdf.escaped(str)
        return lpegmatch(escaped,str) or str
    end

end

local pdfnull, pdfboolean, pdfreference, pdfverbose

do

    local p_null  = { } setmetatable(p_null, mt_z)
    local p_true  = { } setmetatable(p_true, mt_t)
    local p_false = { } setmetatable(p_false,mt_f)

    pdfnull = function()
        return p_null
    end

    pdfboolean = function(b,default)
        if type(b) == "boolean" then
            return b and p_true or p_false
        else
            return default and p_true or p_false
        end
    end

    -- print(pdfboolean(false),pdfboolean(false,false),pdfboolean(false,true))
    -- print(pdfboolean(true),pdfboolean(true,false),pdfboolean(true,true))
    -- print(pdfboolean(nil,true),pdfboolean(nil,false))

    local r_zero = setmetatable({ 0 },mt_r)

    pdfreference = function(r)  -- maybe make a weak table
        if r and r ~= 0 then
            return setmetatable({ r },mt_r)
        else
            return r_zero
        end
    end

    local v_zero  = setmetatable({ 0  },mt_v)
    local v_empty = setmetatable({ "" },mt_v)

    pdfverbose = function(t) -- maybe check for type
        if t == 0 then
            return v_zero
        elseif t == "" then
            return v_empty
        else
            return setmetatable({ t },mt_v)
        end
    end

end

lpdf.stream      = pdfstream -- THIS WILL PROBABLY CHANGE
lpdf.dictionary  = pdfdictionary
lpdf.array       = pdfarray
lpdf.docstring   = pdfdocstring
lpdf.string      = pdfstring
lpdf.unicode     = pdfunicode
lpdf.number      = pdfnumber
lpdf.constant    = pdfconstant
lpdf.null        = pdfnull
lpdf.boolean     = pdfboolean
lpdf.reference   = pdfreference
lpdf.verbose     = pdfverbose
lpdf.literal     = pdfliteral

local names, cache = { }, { }

function lpdf.reserveobject(name)
    local r = pdfreserveobject() -- we don't support "annot"
    if name then
        names[name] = r
        if trace_objects then
            report_objects("reserving number %a under name %a",r,name)
        end
    elseif trace_objects then
        report_objects("reserving number %a",r)
    end
    return r
end

local nofpages = 0

local texgetcount = tex.getcount

function lpdf.pagereference(n,complete) -- true | false | nil | n [true,false]
    if nofpages == 0 then
        nofpages = structures.pages.nofpages
        if nofpages == 0 then
            nofpages = 1
        end
    end
    if n == true or not n then
        complete = n
        n = texgetcount("realpageno")
    end
    local r = n > nofpages and pdfgetpagereference(nofpages) or pdfgetpagereference(n)
    return complete and pdfreference(r) or r
end

function lpdf.nofpages()
    return structures.pages.nofpages
end

function lpdf.obj(...)
    pdfdeferredobject(...)
end

function lpdf.immediateobj(...)
    pdfimmediateobject(...)
end

function lpdf.delayedobject(data,n)
    if n then
        pdfdeferredobject(n,data)
    else
        n = pdfdeferredobject(data)
    end
    pdfreferenceobject(n)
    return n
end

function lpdf.flushobject(name,data)
    if data then
        local named = names[name]
        if named then
            if not trace_objects then
            elseif trace_details then
                report_objects("flushing data to reserved object with name %a, data: %S",name,data)
            else
                report_objects("flushing data to reserved object with name %a",name)
            end
            return pdfimmediateobject(named,tostring(data))
        else
            if not trace_objects then
            elseif trace_details then
                report_objects("flushing data to reserved object with number %s, data: %S",name,data)
            else
                report_objects("flushing data to reserved object with number %s",name)
            end
            return pdfimmediateobject(name,tostring(data))
        end
    else
        if trace_objects and trace_details then
            report_objects("flushing data: %S",name)
        end
        return pdfimmediateobject(tostring(name))
    end
end

function lpdf.flushstreamobject(data,dict,compressed,objnum) -- default compressed
    if trace_objects then
        report_objects("flushing stream object of %s bytes",#data)
    end
    local dtype    = type(dict)
    local kind     = compressed == "raw" and "raw" or "stream"
    local nolength = nil
    if compressed == "raw" then
        compressed = nil
        nolength   = true
     -- data       = string.formatters["<< %s >>stream\n%s\nendstream"](attr,data)
    end
    return pdfdeferredobject {
        objnum        = objnum,
        immediate     = true,
        nolength      = nolength,
        compresslevel = compressed == false and 0 or nil,
        type          = "stream",
        string        = data,
        attr          = (dtype == "string" and dict) or (dtype == "table" and dict()) or nil,
    }
end

function lpdf.flushstreamfileobject(filename,dict,compressed,objnum) -- default compressed
    if trace_objects then
        report_objects("flushing stream file object %a",filename)
    end
    local dtype = type(dict)
    return pdfdeferredobject {
        objnum        = objnum,
        immediate     = true,
        compresslevel = compressed == false and 0 or nil,
        type          = "stream",
        file          = filename,
        attr          = (dtype == "string" and dict) or (dtype == "table" and dict()) or nil,
    }
end

local shareobjectcache, shareobjectreferencecache = { }, { }

function lpdf.shareobject(content)
    if content == nil then
        -- invalid object not created
    else
        content = tostring(content)
        local o = shareobjectcache[content]
        if not o then
            o = pdfimmediateobject(content)
            shareobjectcache[content] = o
        end
        return o
    end
end

function lpdf.shareobjectreference(content)
    if content == nil then
        -- invalid object not created
    else
        content = tostring(content)
        local r = shareobjectreferencecache[content]
        if not r then
            local o = shareobjectcache[content]
            if not o then
                o = pdfimmediateobject(content)
                shareobjectcache[content] = o
            end
            r = pdfreference(o)
            shareobjectreferencecache[content] = r
        end
        return r
    end
end

-- three priority levels, default=2

local pagefinalizers     = { { }, { }, { } }
local documentfinalizers = { { }, { }, { } }

local pageresources, pageattributes, pagesattributes

local function resetpageproperties()
    pageresources   = pdfdictionary()
    pageattributes  = pdfdictionary()
    pagesattributes = pdfdictionary()
end

function lpdf.getpageproperties()
    return {
        pageresources   = pageresources,
        pageattributes  = pageattributes,
        pagesattributes = pagesattributes,
    }
end

resetpageproperties()

local function setpageproperties()
    pdfsetpageresources  (pageresources  ())
    pdfsetpageattributes (pageattributes ())
    pdfsetpagesattributes(pagesattributes())
end

local function addtopageresources  (k,v) pageresources  [k] = v end
local function addtopageattributes (k,v) pageattributes [k] = v end
local function addtopagesattributes(k,v) pagesattributes[k] = v end

lpdf.addtopageresources   = addtopageresources
lpdf.addtopageattributes  = addtopageattributes
lpdf.addtopagesattributes = addtopagesattributes

local function set(where,what,f,when,comment)
    if type(when) == "string" then
        when, comment = 2, when
    elseif not when then
        when = 2
    end
    local w = where[when]
    w[#w+1] = { f, comment }
    if trace_finalizers then
        report_finalizing("%s set: [%s,%s]",what,when,#w)
    end
end

local function run(where,what)
    if trace_finalizers then
        report_finalizing("start backend, category %a, n %a",what,#where)
    end
    for i=1,#where do
        local w = where[i]
        for j=1,#w do
            local wj = w[j]
            if trace_finalizers then
                report_finalizing("%s finalizer: [%s,%s] %s",what,i,j,wj[2] or "")
            end
            wj[1]()
        end
    end
    if trace_finalizers then
        report_finalizing("stop finalizing")
    end
end

local function registerpagefinalizer(f,when,comment)
    set(pagefinalizers,"page",f,when,comment)
end

local function registerdocumentfinalizer(f,when,comment)
    set(documentfinalizers,"document",f,when,comment)
end

lpdf.registerpagefinalizer     = registerpagefinalizer
lpdf.registerdocumentfinalizer = registerdocumentfinalizer

function lpdf.finalizepage(shipout)
    if shipout and not environment.initex then
     -- resetpageproperties() -- maybe better before
        run(pagefinalizers,"page")
        setpageproperties()
        resetpageproperties() -- maybe better before
    end
end

function lpdf.finalizedocument()
    if not environment.initex then
        run(documentfinalizers,"document")
        function lpdf.finalizedocument()
         -- report_finalizing("serious error: the document is finalized multiple times")
            function lpdf.finalizedocument() end
        end
    end
end

callbacks.register("finish_pdfpage", lpdf.finalizepage)
callbacks.register("finish_pdffile", lpdf.finalizedocument)

do

    local pdfsetinfo, pdfsetcatalog, pdfsettrailerid -- pdfsetnames pdfsettrailer

    updaters.register("backend.update.lpdf",function()
        pdfsetinfo                 = pdf.setinfo
        pdfsetcatalog              = pdf.setcatalog
        pdfsettrailerid            = pdf.settrailerid
    end)

    function lpdf.settrailerid(id)
        pdfsettrailerid(id)
    end

    -- some minimal tracing, handy for checking the order

    local function trace_set(what,key)
        if trace_resources then
            report_finalizing("setting key %a in %a",key,what)
        end
    end

    local function trace_flush(what)
        if trace_resources then
            report_finalizing("flushing %a",what)
        end
    end

    lpdf.protectresources = true

    local catalog = pdfdictionary { Type = pdfconstant("Catalog") } -- nicer, but when we assign we nil the Type
    local info    = pdfdictionary { Type = pdfconstant("Info")    } -- nicer, but when we assign we nil the Type
    ----- names   = pdfdictionary { Type = pdfconstant("Names")   } -- nicer, but when we assign we nil the Type

    local function checkcatalog()
        if not environment.initex then
            trace_flush("catalog")
            return true
        end
    end

    local function checkinfo()
        if not environment.initex then
            trace_flush("info")
            if lpdf.majorversion() > 1 then
                for k, v in next, info do
                    if k == "CreationDate" or k == "ModDate" then
                        -- mandate >= 2.0
                    else
                        info[k] = nil
                    end
                end
            end
            return true
        end
    end

    local function flushcatalog()
        if checkcatalog() then
            catalog.Type = nil
            pdfsetcatalog(catalog())
        end
    end

    local function flushinfo()
        if checkinfo() then
            info.Type = nil
            pdfsetinfo(info())
        end
    end

    function lpdf.getcatalog()
        if checkcatalog() then
            catalog.Type = pdfconstant("Catalog")
            return pdfreference(pdfimmediateobject(tostring(catalog)))
        end
    end

    function lpdf.getinfo()
        if checkinfo() then
            return pdfreference(pdfimmediateobject(tostring(info)))
        end
    end

    function lpdf.addtocatalog(k,v)
        if not (lpdf.protectresources and catalog[k]) then
            trace_set("catalog",k)
            catalog[k] = v
        end
    end

    function lpdf.addtoinfo(k,v)
        if not (lpdf.protectresources and info[k]) then
            trace_set("info",k)
            info[k] = v
        end
    end

    -- local function lpdf.addtonames(k,v)
    --     if not (lpdf.protectresources and names[k]) then
    --         trace_set("names",k)
    --         names[k] = v
    --     end
    -- end

    local names = pdfdictionary {
     -- Type = pdfconstant("Names")
    }

    local function flushnames()
        if next(names) and not environment.initex then
            names.Type = pdfconstant("Names")
            trace_flush("names")
            lpdf.addtocatalog("Names",pdfreference(pdfimmediateobject(tostring(names))))
        end
    end

    function lpdf.addtonames(k,v)
        if not (lpdf.protectresources and names[k]) then
            trace_set("names",  k)
            names  [k] = v
        end
    end

    local r_extgstates, r_colorspaces, r_patterns, r_shades
    local d_extgstates, d_colorspaces, d_patterns, d_shades
    local p_extgstates, p_colorspaces, p_patterns, p_shades

    local function checkextgstates () if d_extgstates  then addtopageresources("ExtGState", p_extgstates ) end end
    local function checkcolorspaces() if d_colorspaces then addtopageresources("ColorSpace",p_colorspaces) end end
    local function checkpatterns   () if d_patterns    then addtopageresources("Pattern",   p_patterns   ) end end
    local function checkshades     () if d_shades      then addtopageresources("Shading",   p_shades     ) end end

    local function flushextgstates () if d_extgstates  then trace_flush("extgstates")  pdfimmediateobject(r_extgstates, tostring(d_extgstates )) end end
    local function flushcolorspaces() if d_colorspaces then trace_flush("colorspaces") pdfimmediateobject(r_colorspaces,tostring(d_colorspaces)) end end
    local function flushpatterns   () if d_patterns    then trace_flush("patterns")    pdfimmediateobject(r_patterns,   tostring(d_patterns   )) end end
    local function flushshades     () if d_shades      then trace_flush("shades")      pdfimmediateobject(r_shades,     tostring(d_shades     )) end end

    -- patterns are special as they need resources to so we can get recursive references and in that case
    -- acrobat doesn't show anything (other viewers handle it well)
    --
    -- todo: share them
    -- todo: force when not yet set

    local f_font = formatters["%s%d"]

    function lpdf.collectedresources(options)
        local ExtGState  = d_extgstates  and next(d_extgstates ) and p_extgstates
        local ColorSpace = d_colorspaces and next(d_colorspaces) and p_colorspaces
        local Pattern    = d_patterns    and next(d_patterns   ) and p_patterns
        local Shading    = d_shades      and next(d_shades     ) and p_shades
        local Font
        if options and options.patterns == false then
            Pattern = nil
        end
        local fonts = options and options.fonts
        if fonts and next(fonts) then
            local pdfgetfontobjnumber = lpdf.getfontobjnumber
            if pdfgetfontobjnumber then
                local prefix = options.fontprefix or "F"
                Font = pdfdictionary { }
                for k, v in sortedhash(fonts) do
                    Font[f_font(prefix,v)] = pdfreference(pdfgetfontobjnumber(k))
                end
            end
        end
        if ExtGState or ColorSpace or Pattern or Shading or Font then
            local collected = pdfdictionary {
                ExtGState  = ExtGState,
                ColorSpace = ColorSpace,
                Pattern    = Pattern,
                Shading    = Shading,
                Font       = Font,
            }
            if options and options.serialize == false then
                return collected
            else
                return collected()
            end
        elseif options and options.notempty then
            return nil
        elseif options and options.serialize == false then
            return pdfdictionary { }
        else
            return ""
        end
    end

    function lpdf.adddocumentextgstate (k,v)
        if not d_extgstates then
            r_extgstates = pdfreserveobject()
            d_extgstates = pdfdictionary()
            p_extgstates = pdfreference(r_extgstates)
        end
        d_extgstates[k] = v
    end

    function lpdf.adddocumentcolorspace(k,v)
        if not d_colorspaces then
            r_colorspaces = pdfreserveobject()
            d_colorspaces = pdfdictionary()
            p_colorspaces = pdfreference(r_colorspaces)
        end
        d_colorspaces[k] = v
    end

    function lpdf.adddocumentpattern(k,v)
        if not d_patterns then
            r_patterns = pdfreserveobject()
            d_patterns = pdfdictionary()
            p_patterns = pdfreference(r_patterns)
        end
        d_patterns[k] = v
    end

    function lpdf.adddocumentshade(k,v)
        if not d_shades then
            r_shades = pdfreserveobject()
            d_shades = pdfdictionary()
            p_shades = pdfreference(r_shades)
        end
        d_shades[k] = v
    end

    registerdocumentfinalizer(flushextgstates,3,"extended graphic states")
    registerdocumentfinalizer(flushcolorspaces,3,"color spaces")
    registerdocumentfinalizer(flushpatterns,3,"patterns")
    registerdocumentfinalizer(flushshades,3,"shades")

    registerdocumentfinalizer(flushnames,3,"names") -- before catalog
    registerdocumentfinalizer(flushcatalog,3,"catalog")
    registerdocumentfinalizer(flushinfo,3,"info")

    registerpagefinalizer(checkextgstates,3,"extended graphic states")
    registerpagefinalizer(checkcolorspaces,3,"color spaces")
    registerpagefinalizer(checkpatterns,3,"patterns")
    registerpagefinalizer(checkshades,3,"shades")

end

-- in strc-bkm: lpdf.registerdocumentfinalizer(function() structures.bookmarks.place() end,1)

function lpdf.rotationcm(a)
    local s = sind(a)
    local c = cosd(a)
    return format("%.6F %.6F %.6F %.6F 0 0 cm",c,s,-s,c)
end

-- ! -> universaltime

do

    -- It's a bit of a historical mess here.

    local metadata  = nil
    local timestamp = backends.timestamp()

    function lpdf.getmetadata()
        if not metadata then
            local contextversion      = environment.version
            local luatexversion       = format("%1.2f",LUATEXVERSION)
            local luatexfunctionality = tostring(LUATEXFUNCTIONALITY)
            metadata = {
                producer            = format("LuaTeX-%s",luatexversion),
                creator             = format("LuaTeX %s %s + ConTeXt MkIV %s",luatexversion,luatexfunctionality,contextversion),
                luatexversion       = luatexversion,
                contextversion      = contextversion,
                luatexfunctionality = luatexfunctionality,
                luaversion          = tostring(LUAVERSION),
                platform            = os.platform,
                time                = timestamp,
            }
        end
        return metadata
    end

    function lpdf.settime(n)
        if n then
            n = converters.totime(n)
            if n then
                converters.settime(n)
                timestamp = backends.timestamp()
            end
        end
        if metadata then
            metadata.time = timestamp
        end
        return timestamp
    end

    lpdf.settime(tonumber(resolvers.variable("start_time")) or tonumber(resolvers.variable("SOURCE_DATE_EPOCH"))) -- bah

    function lpdf.pdftimestamp(str)
        local t = type(str)
        if t == "string" then
            local Y, M, D, h, m, s, Zs, Zh, Zm = match(str,"^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)([%+%-])(%d%d):(%d%d)$")
            return Y and format("D:%s%s%s%s%s%s%s%s'%s'",Y,M,D,h,m,s,Zs,Zh,Zm)
        else
            return osdate("D:%Y%m%d%H%M%S",t == "number" and str or ostime()) -- maybe "!D..." : universal time
        end
    end

    function lpdf.id(date)
        local banner = environment.jobname or tex.jobname or "unknown"
        if not date then
            return banner
        else
            return format("%s | %s",banner,timestamp)
        end
    end

end

-- return nil is nicer in test prints

function lpdf.checkedkey(t,key,variant)
    local pn = t and t[key]
    if pn ~= nil then
        local tn = type(pn)
        if tn == variant then
            if variant == "string" then
                if pn ~= "" then
                    return pn
                end
            elseif variant == "table" then
                if next(pn) then
                    return pn
                end
            else
                return pn
            end
        elseif tn == "string" then
            if variant == "number" then
                return tonumber(pn)
            elseif variant == "boolean" then
                return isboolean(pn,nil,true)
            end
        end
    end
 -- return nil
end

function lpdf.checkedvalue(value,variant) -- code not shared
    if value ~= nil then
        local tv = type(value)
        if tv == variant then
            if variant == "string" then
                if value ~= "" then
                    return value
                end
            elseif variant == "table" then
                if next(value) then
                    return value
                end
            else
                return value
            end
        elseif tv == "string" then
            if variant == "number" then
                return tonumber(value)
            elseif variant == "boolean" then
                return isboolean(value,nil,true)
            end
        end
    end
end

function lpdf.limited(n,min,max,default)
    if not n then
        return default
    else
        n = tonumber(n)
        if not n then
            return default
        elseif n > max then
            return max
        elseif n < min then
            return min
        else
            return n
        end
    end
end

-- The next variant of ActualText is what Taco and I could come up with
-- eventually. As of September 2013 Acrobat copies okay, Sumatra copies a
-- question mark, pdftotext injects an extra space and Okular adds a
-- newline plus space.

-- return formatters["BT /Span << /ActualText (CONTEXT) >> BDC [<feff>] TJ % t EMC ET"](code)

do

    local f_actual_text_p     = formatters["BT /Span << /ActualText <feff%s> >> BDC %s EMC ET"]
    local f_actual_text_b     = formatters["BT /Span << /ActualText <feff%s> >> BDC"]
    local s_actual_text_e     = "EMC ET"
    local f_actual_text_b_not = formatters["/Span << /ActualText <feff%s> >> BDC"]
    local s_actual_text_e_not = "EMC"
    local f_actual_text       = formatters["/Span <</ActualText %s >> BDC"]

    local context   = context
    local pdfdirect = nodes.pool.directliteral -- we can use nuts.write deep down
    local tounicode = fonts.mappings.tounicode

    function codeinjections.unicodetoactualtext(unicode,pdfcode)
        return f_actual_text_p(type(unicode) == "string" and unicode or tounicode(unicode),pdfcode)
    end

    function codeinjections.startunicodetoactualtext(unicode)
        return f_actual_text_b(type(unicode) == "string" and unicode or tounicode(unicode))
    end

    function codeinjections.stopunicodetoactualtext()
        return s_actual_text_e
    end

    function codeinjections.startunicodetoactualtextdirect(unicode)
        return f_actual_text_b_not(type(unicode) == "string" and unicode or tounicode(unicode))
    end

    function codeinjections.stopunicodetoactualtextdirect()
        return s_actual_text_e_not
    end

    implement {
        name      = "startactualtext",
        arguments = "string",
        actions   = function(str)
            context(pdfdirect(f_actual_text(tosixteen(str))))
        end
    }

    implement {
        name      = "stopactualtext",
        actions   = function()
            context(pdfdirect("EMC"))
        end
    }

end

-- interface

implement { name = "lpdf_collectedresources",                             actions = { lpdf.collectedresources, context } }
implement { name = "lpdf_addtocatalog",          arguments = two_strings, actions = lpdf.addtocatalog }
implement { name = "lpdf_addtoinfo",             arguments = two_strings, actions = function(a,b,c) lpdf.addtoinfo(a,b,c) end } -- gets adapted
implement { name = "lpdf_addtonames",            arguments = two_strings, actions = lpdf.addtonames }
implement { name = "lpdf_addtopageattributes",   arguments = two_strings, actions = lpdf.addtopageattributes }
implement { name = "lpdf_addtopagesattributes",  arguments = two_strings, actions = lpdf.addtopagesattributes }
implement { name = "lpdf_addtopageresources",    arguments = two_strings, actions = lpdf.addtopageresources }
implement { name = "lpdf_adddocumentextgstate",  arguments = two_strings, actions = function(a,b) lpdf.adddocumentextgstate (a,pdfverbose(b)) end }
implement { name = "lpdf_adddocumentcolorspace", arguments = two_strings, actions = function(a,b) lpdf.adddocumentcolorspace(a,pdfverbose(b)) end }
implement { name = "lpdf_adddocumentpattern",    arguments = two_strings, actions = function(a,b) lpdf.adddocumentpattern   (a,pdfverbose(b)) end }
implement { name = "lpdf_adddocumentshade",      arguments = two_strings, actions = function(a,b) lpdf.adddocumentshade     (a,pdfverbose(b)) end }

-- more helpers: copy from lepd to lpdf

function lpdf.copyconstant(v)
    if v ~= nil then
        return pdfconstant(v)
    end
end

function lpdf.copyboolean(v)
    if v ~= nil then
        return pdfboolean(v)
    end
end

function lpdf.copyunicode(v)
    if v then
        return pdfunicode(v)
    end
end

function lpdf.copyarray(a)
    if a then
        local t = pdfarray()
        for i=1,#a do
            t[i] = a(i)
        end
        return t
    end
end

function lpdf.copydictionary(d)
    if d then
        local t = pdfdictionary()
        for k, v in next, d do
            t[k] = d(k)
        end
        return t
    end
end

function lpdf.copynumber(v)
    return v
end

function lpdf.copyinteger(v)
    return v -- maybe checking or round ?
end

function lpdf.copyfloat(v)
    return v
end

function lpdf.copystring(v)
    if v then
        return pdfstring(v)
    end
end

do

    local pdfincludechar, pdfincludecharlist, pdfincludefont
    local pdfgetfontname, pdfgetfontobjnum
    local pdfsetmapfile, pdfsetmapline

    updaters.register("backend.update.lpdf",function()
        pdfincludechar     = pdf.includechar
        pdfincludefont     = pdf.includefont
        pdfincludecharlist = pdf.includecharlist
        pdfgetfontname     = pdf.getfontname
        pdfgetfontobjnum   = pdf.getfontobjnum
        pdfsetmapfile      = pdf.mapfile
        pdfsetmapline      = pdf.mapline
    end)

    function lpdf.includechar(f,c) pdfincludechar(f,c) end
    function lpdf.includefont(...) pdfincludefont(...) end

    function lpdf.includecharlist(f,c) pdfincludecharlist(f,c) end -- can be disabled

    function lpdf.getfontname     (id) return pdfgetfontname  (id) end
    function lpdf.getfontobjnumber(id) return pdfgetfontobjnum(id) end

    function lpdf.setmapfile(...) pdfsetmapfile(...) end
    function lpdf.setmapline(...) pdfsetmapline(...) end

end

do

    -- This is obsolete but old viewers might still use it as directive
    -- for what to send to a postscript printer.

    local a_procset, d_procset

    function lpdf.procset(dict)
        if not a_procset then
            a_procset = pdfarray {
                pdfconstant("PDF"),
                pdfconstant("Text"),
                pdfconstant("ImageB"),
                pdfconstant("ImageC"),
                pdfconstant("ImageI"),
            }
            a_procset = pdfreference(pdfimmediateobject(tostring(a_procset)))
        end
        if dict then
            if not d_procset then
                d_procset = pdfdictionary {
                    ProcSet = a_procset
                }
                d_procset = pdfreference(pdfimmediateobject(tostring(d_procset)))
            end
            return d_procset
        else
            return a_procset
        end
    end

end

-- a left-over

if environment.arguments.nocompression then
    lpdf.setcompression(0,0,true)
end
