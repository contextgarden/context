if not modules then modules = { } end modules ['mtx-ctan'] = {
    version   = 1.00,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is just an experiment. Some day I want to be able to install fonts this way
-- but maybe fetching tex live packages is also an option (I need to check if there
-- is an api for that ... in wintertime). Normally fonts come from the web but I had
-- to fetch newcm from ctan, so ...
--
-- mtxrun --script ctan --packages --pattern=computermodern

-- http://www.ctan.org/json/2.0/packages
-- http://www.ctan.org/json/2.0/pkg/name
-- http://www.ctan.org/json/2.0/topics              : key details
-- http://www.ctan.org/json/2.0/topic/name          : key details
-- http://www.ctan.org/json/2.0/topic/name?ref=true : key details packages

local lower, find, gsub = string.lower, string.find, string.gsub
local write_nl = (logs and logs.writer) or (texio and texio.write_nl) or print
local xmlconvert, xmltext, xmlattr, xmlcollected = xml.convert, xml.text, xml.attribute, xml.collected

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-ctan</entry>
  <entry name="detail">Dealing with CTAN</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="pattern" value="string"><short>use this pattern, otherwise first argument</short></flag>
    <flag name="download" value="string"><short>install (fonts) from texlive</short></flag>
    <flag name="force" value="string"><short>force installation even when present</short></flag>
    <flag name="all" value="string"><short>also install when multiple packages</short></flag>
   </subcategory>
   <subcategory>
    <flag name="packages"><short>list available ctan packages [--field=key|name|caption]</short></flag>
    <flag name="topics"><short>list available ctan topics [--field=key|name|details]</short></flag>
    <flag name="details"><short>show details about a ctan package</short></flag>
   </subcategory>
   <subcategory>
    <flag name="texlive"><short>install a texlive package [--download] [--force] [--all]</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-ctan",
    banner   = "Dealing with CTAN",
    helpinfo = helpinfo,
}

local report = application.report

if not client then
    report("this only works with luametatex (lmtx)")
    return
end

scripts      = scripts      or { }
scripts.ctan = scripts.ctan or { }

local json      = utilities.json
local jsontolua = json.tolua
local shaped    = characters and characters.shaped or lower

-- local ignore = {
--     "latex",
--     "plain",
--     "xetex",
-- }

-- what is the url to fetch a zip

-- We cannot use the socket library because we don't compile that massive amount of
-- ssl code into lua(meta)tex. Maybe some day one fo these small embedded libraries
-- makes sense but there are so many changes in all that security stuff that it
-- defeats long term stability of the ecosystem anyway ... just like some of my old
-- devices suddenly are no longer accessible with modern browsers I expect it to
-- happen everywhere. I'm not sure why ctan can't support http because I see no
-- added value in the 's' here.

do

    local ctanurl = "https://www.ctan.org/" .. (json and "json" or "xml") .. "/2.0/"

    local function fetched(str)
        local status, data = client.httprequest {
            url = ctanurl .. str
        }
        if not data then
            report("some error: %s",message)
        end
        return data
    end

    local function strfound(pattern,str)
        if not pattern then
            return true
        else
            local str = lower(shaped(str))
            if find(str,pattern) then
                return true
            else
                str = gsub(str,"[^a-zA-Z0-9]","")
                if find(str,pattern) then
                    return true
                else
                    return false
                end
            end
        end
    end

    local function showresult(found)
        if #found > 2 then
            utilities.formatters.formatcolumns(found)
            report("")
            for k=1,#found do
                report(found[k])
            end
            report("")
        end
    end

    local function checkedpattern(pattern)
        if pattern then
            pattern = string.topattern(pattern,true)
            return lower(shaped(pattern))
        end
    end

    local validdata = json and

        function(data)
            if data then
                data = jsontolua(data)
                if type(data) == "table" then
                    return data
                else
                    report("unable to handle this json data")
                end
            else
                report("unable to fetch packages")
            end
        end

    or

        function(data)
            if data then
                data = xmlconvert(data)
                if data.error then
                    report("unable to handle this json data")
                else
                    return data
                end
            else
                report("unable to fetch packages")
            end
        end

    scripts.ctan.details = json and

        function(name)
            if name then
                local data = validdata(fetched("pkg/" .. name))
                if data then
                    report("")
                 -- report("key     : %s",data.key or "-")
                    report("name    : %s",data.name or "-")
                    report("caption : %s",data.caption or "-")
                    report("path    : %s",data.ctan and data.ctan.path or "-")
                    report("")
                end
            end
        end

    or

        function (name)
            if name then
                local data = validdata(fetched("pkg/" .. name))
                report("")
             -- report("key     : %s",data.key or "-")
                report("name    : %s",xmltext(data,"/entry/name"))
                report("caption : %s",xmltext(data,"/entry/caption"))
                report("path    : %s",xmlattr(data,"/entry/ctan","path"))
                report("")
            end
        end

    scripts.ctan.packages = json and

        function(pattern,field)
            local data = validdata(fetched("packages"))
            if data then
                local found = {
                    { "key", "name", "caption" },
                    { "",    "",     ""        },
                }
                pattern = checkedpattern(pattern)
                for i=1,#data do
                    local entry   = data[i]
                    local key     = entry.key
                    local name    = entry.name
                    local caption = entry.caption
                    local where
                    if field == "name" then
                        where = name
                    elseif field == "caption" then
                        where = caption
                    elseif field == "key" then
                        where = key
                    end
                    if where then
                        if strfound(pattern,where) then
                            found[#found+1] = { key, name, caption }
                        end
                    else
                        if strfound(pattern,name) or strfound(pattern,caption) then
                            found[#found+1] = { key, name, caption }
                        end
                    end
                end
                showresult(found)
            end
        end

    or

        function(pattern)
            local data = validdata(fetched("packages"))
            if data then
                local found = {
                    { "key", "name", "caption" },
                    { "",    "",     ""        },
                }
                pattern = checkedpattern(pattern)
                for c in xmlcollected(data,"/packages/package") do
                    local at = c.at
                    if strfound(pattern,at.caption) then
                        found[#found+1] = { at.key, at.name, at.caption }
                    end
                end
                showresult(found)
            end
        end

    scripts.ctan.topics = json and

        function (pattern)
            local data = validdata(fetched("topics"))
            if data then
                local found = {
                    { "key", "details" },
                    { "",    ""        },
                }
                pattern = checkedpattern(pattern)
                for i=1,#data do
                    -- inconsistency between json and xml
                    local entry   = data[i]
                    local key     = entry.key
                    local name    = entry.name
                    local details = entry.details
                    local where
                    if field == "name" then
                        where = name or key
                    elseif field == "details" then
                        where = details
                    elseif field == "key" then
                        where = key or name
                    end
                    if where then
                        if strfound(pattern,where) then
                            found[#found+1] = { key or name, details }
                        end
                    else
                        if strfound(pattern,key or name) or strfound(pattern,details) then
                            found[#found+1] = { key or name, details }
                        end
                    end
                end
                showresult(found)
            end
        end

    or

        function(pattern)
            local data = validdata(fetched("topics"))
            if data then
                local found = {
                    { "name", "details" },
                    { "",     ""        },
                }
                pattern = checkedpattern(pattern)
                for c in xmlcollected(data,"/topics/topic") do
                    local at = c.at
                    if strfound(pattern,at.caption) then
                        found[#found+1] = { at.key or at.name, at.details } -- inconsistency between json and xml
                    end
                end
                showresult(found)
            end
        end


end

local function whatever()
--     report("")
--     report("using %s interface", json and "json"    or "xml")
--     report("")
end

-- scripts.ctan.packages(environment.argument("pattern") or environment.files[1])
-- scripts.ctan.packages("font")
-- scripts.ctan.details("tex")
-- scripts.ctan.details("ipaex")

-- scripts.ctan.packages("Półtawskiego")
-- scripts.ctan.packages("Poltawskiego")

-- scripts.ctan.topics("font")
-- scripts.ctan.topics()

do

    -- Because there is no way to get the archives from ctan, we can try to
    -- use the texlive way. Here we need to fetch a big descriptive file that
    -- we then scan for filenames. We're only interested in fonts. At some
    -- point texlive started using .xz files (smaller, maybe because of the dvd)
    -- but .gz files are actually more suitable: they are not that much larger
    -- (many files are binary) and they decompress about 5 times faster which
    -- with todays fast internet connections wins over the few MB extra that
    -- one has to download.

    local lower   = string.lower
    local find    = string.find

    local report = logs.reporter("texlive")

    local tar = utilities.tar

    local function downloaded(name)
        local url = "https://mirror.ctan.org/systems/texlive/tlnet/" .. name
        report("fetching archive   : %a",url)
        local status, db = client.httprequest {
            url = url,
        }
        if not db then
            report("no archive found   : %i",status)
            return false
        end
        report("compressed size    : %i",#db)
        db = xz.decompress(db)
        report("uncompressed size  : %i",db and #db or 0)
        return db
    end

    local filters = {
        fonts = function(result,name,files,pattern)
            for i=1,#files do
                local fi = files[i]
                if find(fi,"%.otf$") or find(fi,"%.ttf$") then
                    if find(lower(fi),pattern) then
                        result[name] = fi
                        break
                    end
                end
            end
        end
    }

    local function locate(pattern)
        local db = downloaded("tlpkg/texlive.tlpdb.xz")
        if not db then
            return
        end
        -- io.savedata("crap",db)
        local newline  = lpeg.patterns.newline
        local package  = lpeg.P("name ") * lpeg.C((1-newline)^1) * newline
                       * (lpeg.P("category ") * lpeg.P("Package") * newline)
        local rubish   = (1 - lpeg.P("runfiles") - newline * newline)^1 * (1 - newline)^0 * newline
        local runfile  = lpeg.P(" ") * lpeg.Cs((1-newline)^1) * newline
        local runfiles = lpeg.Ct ( runfile^1 )
        local whatever = (1 - newline)^1 * newline
        local result   = table.setmetatableindex("table")
        local filter   = filters.fonts
        local query    = (
            (package * rubish * runfiles) / function(name,files)
                if files then
                    filter(result,name,files,pattern)
                end
            end
          + lpeg.P(1) -- whatever
        )^1

        lpeg.match(query,db)
        return result
    end

    local function fetch(name,download,force)
        local db = downloaded("archive/" .. name .. ".tar.xz")
        if not db then
            return 0
        end
        local done = 0
        report("")
        tar.strings.traverse(db,function(name)
            local s = file.suffix(name)
            if s == "otf" or s == "ttf" then
                local b = file.basename(name)
                local f = resolvers.findfile(b)
                if f and f ~= "" then
                    report("present : %s",f)
                    if not force then
                        return false
                    end
                else
                    report("not yet : %s",b)
                end
                if download then
                    done = done + 1
                end
                return download and b or false
            else
                return false
            end
        end)
        return done
    end

    function scripts.ctan.texlive(pattern,all,download,force)
        if not pattern then
            pattern = "."
        else
            pattern = string.topattern(pattern)
        end
        local result = locate(pattern)
        local count  = not result and 0 or table.count(result)
        report("number of packages : %i",count)
        if count == 0 then
            print("not found")
        elseif count > 1 and not all then
            report("")
            local p = 0
            local f = 0
            for k, v in table.sortedhash(result) do
                report("% 3i  %s",#v,k)
                p = p + 1
                f = f + #v
            end
            report("")
            report("number of packages : %i",p)
            report("number of files    : %i",f)
        else
            for name, list in table.sortedhash(result) do
                report("")
                report("package name        : %s",name)
                report("")
                local done = fetch(name,download,force)
                report("")
                report("number of downloads : %i",done)
            end
        end
    end

end

if environment.argument("packages") then
    whatever()
    scripts.ctan.packages(environment.argument("pattern") or environment.files[1], environment.argument("field"))
elseif environment.argument("topics") then
    whatever()
    scripts.ctan.topics(
        environment.argument("pattern") or environment.files[1]
    )
elseif environment.argument("details") then
    whatever()
    scripts.ctan.details(
        environment.files[1]
    )
elseif environment.argument("texlive") then
 -- whatever()
    scripts.ctan.texlive(
        environment.argument("pattern") or environment.files[1],
        environment.argument("all"),
        environment.argument("download"),
        environment.argument("force")
    )
elseif environment.argument("exporthelp") then
    application.export(
        environment.argument("exporthelp"),
        environment.files[1]
    )
else
    application.help()
end
