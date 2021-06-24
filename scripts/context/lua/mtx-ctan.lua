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
    <flag name="packages"><short>list available packages</short></flag>
    <flag name="topics"><short>list available topics</short></flag>
    <flag name="detail"><short>show details about package</short></flag>
    <flag name="pattern" value="string"><short>use this pattern, otherwise first argument</short></flag>
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

scripts      = scripts      or { }
scripts.ctan = scripts.ctan or { }

local okay, json = pcall(require,"util-jsn")
local okay, curl = pcall(require,"libs-imp-curl")
                   pcall(require,"char-ini")

local jsontolua = json and json.tolua
local shaped    = characters and characters.shaped or lower

-- local ignore = {
--     "latex",
--     "plain",
--     "xetex",
-- }

-- what is the url to fetch a zip

-- We cannot use the socket library because we don't compile that massive amount of
-- ssl code into lua(meta)tex. aybe some day one fo these small embedded libraries
-- makes sense but there are so many changes in all that security stuff that it
-- defeats long term stability of the ecosystem anyway ... just like some of my old
-- devices suddenly are no longer accessible with modern browsers I expect it to
-- happen everywhere. I'm not sure why ctan can't support http because I see no
-- added value in the 's' here.

local ctanurl = "https://www.ctan.org/" .. (json and "json" or "xml") .. "/2.0/"

local fetched = curl and

    function(str)
        local data, message = curl.fetch {
            url           = ctanurl .. str,
            sslverifyhost = false,
            sslverifypeer = false,
        }
        if not data then
            report("some error: %s",message)
        end
        return data
    end

or

    function(str)
        -- So, no redirect to http, which means that we cannot use the built in socket
        -- library. What if the client is happy with http?
        local data = os.resultof("curl -sS " .. ctanurl .. str)
        -- print(data)
        return data
    end

-- for j=1,#ignore do
--     if find(str,ignore[j]) then
--         return false
--     end
-- end

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
                report("path    : %s",data.ctan.path or "-")
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

    function(pattern)
        local data = validdata(fetched("packages"))
        if data then
            local found = {
                { "key", "name", "caption" },
                { "",    "",     ""        },
            }
            pattern = checkedpattern(pattern)
            for i=1,#data do
                local entry = data[i]
                if strfound(pattern,entry.caption) then
                    found[#found+1] = { entry.key, entry.name, entry.caption }
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
                local entry = data[i]
                if strfound(pattern,entry.details) then
                    found[#found+1] = { entry.key or entry.name, entry.details } -- inconsistency between json and xml
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

local function whatever()
    report("")
    report("using %s interface", json and "json"    or "xml")
    report("using curl %s",      curl and "library" or "binary")
    report("")
end

if environment.argument("packages") then
    whatever()
    scripts.ctan.packages(environment.argument("pattern") or environment.files[1])
elseif environment.argument("topics") then
    whatever()
    scripts.ctan.topics(environment.argument("pattern") or environment.files[1])
elseif environment.argument("details") then
    whatever()
    scripts.ctan.details(environment.files[1])
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end

-- scripts.ctan.packages(environment.argument("pattern") or environment.files[1])
-- scripts.ctan.packages("font")
-- scripts.ctan.details("tex")
-- scripts.ctan.details("ipaex")

-- scripts.ctan.packages("Półtawskiego")
-- scripts.ctan.packages("Poltawskiego")

-- scripts.ctan.topics("font")
-- scripts.ctan.topics()
