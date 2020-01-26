if not modules then modules = { } end modules ['mtx-babel'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- If needed this one can be optimized for speed as well as use some existing
-- helpers. We can quit faster on max, and probably use lpeg instead of find.

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-grep</entry>
  <entry name="detail">Simple Grepper</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="pattern"><short>search for pattern (optional)</short></flag>
    <flag name="count"><short>count matches only</short></flag>
    <flag name="nocomment"><short>skip lines that start with %% or #</short></flag>
    <flag name="n"><short>show at most n matches</short></flag>
    <flag name="first"><short>only show first match</short></flag>
    <flag name="match"><short>return the match (if it is one)</short></flag>
    <flag name="xml"><short>pattern is lpath expression</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Examples</title>
   <subcategory>
    <example><command>mtxrun --script grep --pattern=module *.mkiv</command></example>
    <example><command>mtxrun --script grep --pattern="modules.-%['(.-)'%]" char-*.lua --first</command></example>
    <example><command>mtxrun --script grep --pattern=module --count *.mkiv</command></example>
    <example><command>mtxrun --script grep --pattern=module --first *.mkiv</command></example>
    <example><command>mtxrun --script grep --pattern=module --nocomment *.mkiv</command></example>
    <example><command>mtxrun --script grep --pattern=module --n=10 *.mkiv</command></example>
   </subcategory>
  </category>
 </examples>
 <comments>
    <comment>patterns are lua patterns and need to be escaped accordingly</comment>
 </comments>
</application>
]]

local application = logs.application {
    name     = "mtx-grep",
    banner   = "Simple Grepper 0.10",
    helpinfo = helpinfo,
}

local report = application.report

scripts      = scripts      or { }
scripts.grep = scripts.grep or { }

local find, match, format = string.find, string.match, string.format
local lpegmatch = lpeg.match

local cr       = lpeg.P("\r")
local lf       = lpeg.P("\n")
local crlf     = cr * lf
local newline  = crlf + cr + lf
local content  = lpeg.C((1-newline)^0) * newline + lpeg.C(lpeg.P(1)^1)

local write_nl = (logs and logs.writer) or (texio and texio.write_nl) or print

-- local pattern = "LIJST[@TYPE='BULLET']/LIJSTITEM[contains(text(),'Kern')]"

-- 'Cc%(\\\"\\\"%)'

function scripts.grep.find(pattern, files, offset)
    if pattern and pattern ~= "" then
        statistics.starttiming(scripts.grep)
        local nofmatches, noffiles, nofmatchedfiles = 0, 0, 0
        local n, m, check = 0, 0, nil
        local name = ""
        local count = environment.argument("count")
        local nocomment = environment.argument("nocomment")
        local max = tonumber(environment.argument("n")) or (environment.argument("first") and 1) or false
        local domatch = environment.argument("match")
        if environment.argument("xml") then
            for i=offset or 1, #files do
                local globbed = dir.glob(files[i])
                for i=1,#globbed do
                    name = globbed[i]
                    local data = xml.load(name)
                    if data and not data.error then
                        n, m, noffiles = 0, 0, noffiles + 1
                        if count then
                            for c in xml.collected(data,pattern) do
                                m = m + 1
                            end
                            if m > 0 then
                                nofmatches = nofmatches + m
                                nofmatchedfiles = nofmatchedfiles + 1
                                write_nl(format("%5i  %s",m,name))
                                io.flush()
                            end
                        else
                            for c in xml.collected(data,pattern) do
                                m = m + 1
                                if not max or m <= max then
                                    write_nl(format("%s: %s",name,xml.tostring(c)))
                                end
                            end
                        end
                    end
                end
            end
        else
            if nocomment then
                if count then
                    check = function(line)
                        n = n + 1
                        if find(line,"^[%%#]") then
                            -- skip
                        elseif find(line,pattern) then
                            m = m + 1
                        end
                    end
                else
                    check = function(line)
                        n = n + 1
                        if find(line,"^[%%#]") then
                            -- skip
                        elseif find(line,pattern) then
                            m = m + 1
                            if not max or m <= max then
                                if domatch then
                                    write_nl(match(line,pattern))
                                else
                                    write_nl(format("%s %6i: %s",name,n,line))
                                end
                                io.flush()
                            end
                        end
                    end
                end
            else
                if count then
                    check = function(line)
                        n = n + 1
                        if find(line,pattern) then
                            m = m + 1
                        end
                    end
                else
                    check = function(line)
                        n = n + 1
                        if find(line,pattern) then
                            m = m + 1
                            if not max or m <= max then
                                if domatch then
                                    write_nl(match(line,pattern))
                                else
                                    write_nl(format("%s %6i: %s",name,n,line))
                                end
                                io.flush()
                            end
                        end
                    end
                end
            end
            local capture = (content/check)^0 -- todo: break out when max
            for i=offset or 1, #files do
                local globbed = dir.glob(files[i])
                for i=1,#globbed do
                    name = globbed[i]
                    if not find(name,"/%.") then
                        local data = io.loaddata(name)
                        if data then
                            n, m, noffiles = 0, 0, noffiles + 1
                            lpegmatch(capture,data)
                            if count and m > 0 then
                                nofmatches = nofmatches + m
                                nofmatchedfiles = nofmatchedfiles + 1
                                write_nl(format("%5i  %s",m,name))
                                io.flush()
                            end
                        end
                    end
                end
            end
        end
        statistics.stoptiming(scripts.grep)
        if count and nofmatches > 0 then
            write_nl(format("\nfiles: %s, matches: %s, matched files: %s, runtime: %0.3f seconds",noffiles,nofmatches,nofmatchedfiles,statistics.elapsedtime(scripts.grep)))
        end
    end
end

local pattern = environment.argument("pattern")
local files   = environment.files and #environment.files > 0 and environment.files

if environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),files[1])
elseif pattern and files then
    scripts.grep.find(pattern, files)
elseif files then
    scripts.grep.find(files[1], files, 2)
else
    application.help()
end
