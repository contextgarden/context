if not modules then modules = { } end modules ['mtx-package'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, gsub, gmatch = string.format, string.gsub, string.gmatch

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-package</entry>
  <entry name="detail">Distribution Related Goodies</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="merge"><short>merge 'loadmodule' into merge file</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-package",
    banner   = "Distribution Related Goodies 0.10",
    helpinfo = helpinfo,
}

local report = application.report

scripts         = scripts         or { }
messages        = messages        or { }
scripts.package = scripts.package or { }

function scripts.package.merge_luatex_files(name)
    local oldname = resolvers.findfile(name) or ""
    oldname = file.replacesuffix(oldname,"lua")
    if oldname == "" then
        report("missing %q",name)
    else
        local newname = file.removesuffix(oldname) .. "-merged.lua"
        local data = io.loaddata(oldname) or ""
        if data == "" then
            report("missing %q",newname)
        else
            report("loading %q",oldname)
            local collected = { }
            collected[#collected+1] = format("-- merged file : %s\n",newname)
            collected[#collected+1] = format("-- parent file : %s\n",oldname)
            collected[#collected+1] = format("-- merge date  : %s\n",os.date())
            -- loadmodule can have extra arguments
            for lib in gmatch(data,"loadmodule *%([\'\"](.-)[\'\"]") do -- todo: not -- lines
                if file.basename(lib) ~= file.basename(newname) then
                    local fullname = resolvers.findfile(lib) or ""
                    if fullname == "" then
                        report("missing %q",lib)
                    else
                        report("fetching %q",fullname)
                        local data = io.loaddata(fullname)
                        collected[#collected+1] = "\ndo -- begin closure to overcome local limits and interference\n\n"
                        collected[#collected+1] = utilities.merger.compact(data)
                        collected[#collected+1] = "\nend -- closure\n"
                    end
                end
            end
            report("saving %q",newname)
            io.savedata(newname,table.concat(collected))
        end
    end
end

if environment.argument("merge") then
    scripts.package.merge_luatex_files(environment.files[1] or "")
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
