if not modules then modules = { } end modules ['mtx-colors'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: fc-cache -v en check dirs, or better is: fc-cat -v | grep Directory

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-colors</entry>
  <entry name="detail">ConTeXt Color Management</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="table"><short>show icc table</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Example</title>
   <subcategory>
    <example><command>mtxrun --script color --table somename</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-colors",
    banner   = "ConTeXt Color Management 0.10",
    helpinfo = helpinfo,
}

local report = application.report

if not fontloader then fontloader = fontforge end

dofile(resolvers.findfile("colo-icc.lua","tex"))

scripts        = scripts        or { }
scripts.colors = scripts.colors or { }

function scripts.colors.table()
    local files = environment.files
    if #files > 0 then
        for i=1,#files do
            local profile, okay, message = colors.iccprofile(files[i])
            if not okay then
                report(message)
            else
                report(table.serialize(profile,"profile"))
            end
        end
    else
        local files = resolvers.findfiles("*.icc")
        if #files > 0 then
            for i=1,#files do
                report(files[i])
            end
        else
            report("no file(s) given" )
        end
    end
end

--~ local track = environment.argument("track")
--~ if track then trackers.enable(track) end

if environment.argument("table") then
    scripts.colors.table()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
