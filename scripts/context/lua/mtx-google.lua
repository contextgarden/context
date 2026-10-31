if not modules then modules = { } end modules ['mtx-google'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-google</entry>
  <entry name="detail">Google Fonts Downloader</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="list"><short>list fonts by id</short></flag>
    <flag name="download"><short>download fonts by id [--force]</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-google",
    banner   = "Google Fonts Downloader 0.10",
    helpinfo = helpinfo,
}

scripts         = scripts        or { }
scripts.google  = scripts.google or { }

local report    = logs.reporter("google fonts")
local formatted = string.formatted

if not client then
    report("this only works with luametatex")
end

local baseurl  = "https://gwfh.mranftl.com/api/fonts"

-----------------------------------------------------------------

local suffixes = { "lmt", "lua" }

local function loadmodule(nameonly,s)
    local s = s and { s } or suffixes
    for i=1,#s do
        local filename = file.addsuffix(nameonly,s [i])
        local fullname = resolvers.findfile(filename,"tex")
        if fullname and fullname ~= "" then
            dofile(fullname)
            return
        end
    end
end

if false then

    loadmodule("char-def","lua")
    loadmodule("char-utf")

    loadmodule("supp-ran")

    loadmodule("font-ini")
    loadmodule("font-log")
    loadmodule("font-con") -- we need to move some more to ini
    loadmodule("font-cft")
    ----------("font-enc")
    ----------("font-agl")
    loadmodule("font-cid")
    ----------("font-map")
    ----------("font-oti") -- needed ?

    loadmodule("font-otr")
    ----------("font-cff")
    ----------("font-ttf")
    ----------("font-tmp")
    loadmodule("font-dsp")
    ----------("font-oup")

    loadmodule("font-otl")
    ----------("font-onr")
    loadmodule("font-ott")

    loadmodule("font-syn")
    ----------("font-trt")
    ----------("font-mis")

else

    loadmodule("char-def","lua")
    loadmodule("char-utf")

    loadmodule("supp-ran")

    loadmodule("font-ini")
    loadmodule("font-log")
    loadmodule("font-con") -- we need to move some more to ini
    loadmodule("font-cft")
    loadmodule("font-enc")
    loadmodule("font-agl")
    loadmodule("font-cid")
    loadmodule("font-map")
    loadmodule("font-oti") -- needed ?

    loadmodule("font-otr")
    loadmodule("font-cff")
    loadmodule("font-ttf")
    loadmodule("font-tmp")
    loadmodule("font-dsp")
    loadmodule("font-oup")

    loadmodule("font-otl")
    loadmodule("font-onr")
    loadmodule("font-ott")

    loadmodule("font-syn")
    loadmodule("font-trt")
    loadmodule("font-mis")


end

-----------------------------------------------------------------

local function getlist(pattern)
    if not pattern or pattern == "" then
        pattern = "."
    else
        pattern = string.topattern(pattern)
    end
    local status, data = client.httprequest {
        url = baseurl,
    }
    if status == 200 then
        local list    = utilities.json.tolua(data)
        if list then
            local hash    = { }
            local size    = 0
            for i=1,#list do
                local li = list[i]
                local id = li.id
                if id and string.find(id,pattern) then
                    if #id > size then
                        size = #id
                    end
                    hash[id] = li
                end
            end
            return hash, table.sortedkeys(hash), size, #list
        end
    end
end

local function getdetails(id)
    local url = baseurl .. "/" .. id
    local status, data = client.httprequest {
        url = url,
    }
    if status == 200 then
        local d = utilities.json.tolua(data)
        local v = d and d.variants
        if v then
            local l = { }
            for i=1,#v do
                local vi = v[i]
                l[i] = {
                    ["family"] = vi["fontFamily"] or "",
                    ["style"]  = vi["fontStyle"]  or "",
                    ["weight"] = vi["fontWeight"] or "",
                    ["ttf"]    = vi["ttf"],
                    ["otf"]    = vi["otf"],
                }
            end
            return l
        end
    end
end

local function getfont(fullurl,d)
    local family = d.family
    local style  = d.style
    local weight = d.weight
    local suffix = file.suffix(fullurl)
    local hash   = url.hashed(fullurl)
    local name   = hash.path:match("^s/([^/]+)/")
    if style and style ~= "" then
        name = name .. "-" .. style
    end
    if weight and weight ~= "" then
        name = name .. "-" .. weight
    end
    name = file.addsuffix(name,suffix)
    local status, data = client.httprequest {
        url = fullurl,
    }
    if status == 200 then
        io.savedata(name,data)
        local info = fonts.names.filters.otf(name)
        local base = info.fontname
        if base then
            local newname = file.addsuffix(base,file.suffix(name))
            os.rename(name,newname)
            return true, #data, newname
        else
            return true, #data, name
        end
    else
        return false, 0, ""
    end
end

function scripts.google.list(pattern)
    local t = timer.new()
    timer.start(t)
    local hash, keys, size, total = getlist(pattern)
    local fmt = "%".. (#keys > 10000 and 5 or 4) .. "i  %s  %-" .. size .. "s  %s"
    for i=1,#keys do
        local id = keys[i]
        local h  = hash[id]
        report(fmt,i," ",id,h.family)
    end
    timer.stop(t)
    report()
    report("%i fonts, %0.3f seconds",total,timer.elapsed(t))
end

function scripts.google.download(pattern,force)
    local t = timer.new()
    timer.start(t)
    local hash, keys, size, total = getlist(pattern)
    local fmt = "%".. (#keys > 10000 and 5 or 4) .. "i %2i  %s  %-" .. size .. "s  %s"
    local yes = 0
    local nop = 0
    local siz = 0
    for i=1,#keys do
        local id = keys[i]
        local h  = hash[id]
        local d  = getdetails(id)
        if d then
            local lfgname = id .. ".lfg"
            if lfs.isfile(lfgname) then
                local g = table.load(lfgname)
                local f = g.googlefont
                if f and d.modified ~= f.modified then
                    force = true
                end
            else
                force = true
            end
            if force then
                local g = {
                    name       = formatted("%s %s %s",family or "?",style or "?",weight or "?"),
                    version    = "1.00",
                    comment    = "Goodie file used for checking existence.",
                    author     = "ConTeXt LMTX",
                    copyright  = "ConTeXt development team",
                    googlefont = d,
                }
                table.save(lfgname,g)
                for j=1,#d do
                    local d = d[j]
                    local u = d.otf or d.ttf
                    if u then
                        local okay, n, name = getfont(u,d,force)
                        if okay then
                            yes = yes + 1
                            siz = siz + n
                        else
                            nop = nop + 1
                        end
                        report(fmt,i,j,okay and "+" or "-",id,name)
                    end
                end
            else
                report("collection %a is up-to-date",id)
            end
        end
    end
    timer.stop(t)
    report()
    report("%i downloaded, %i skipped, %i bytes, %0.3f seconds",yes,nop,siz,timer.elapsed(t))
end

if environment.arguments["list"] then
    scripts.google.list(
        environment.arguments["pattern"] or environment.files[1]
    )
elseif environment.arguments["download"] then
    scripts.google.download(
        environment.arguments["pattern"] or environment.files[1],
        environment.arguments["force"]
    )
elseif environment.arguments["exporthelp"] then
    application.export(
        environment.arguments["exporthelp"],
        environment.files[1]
    )
else
    application.help()
end
