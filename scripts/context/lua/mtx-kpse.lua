if not modules then modules = { } end modules ['mtx-kpse'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- I decided to make this module after a report on the mailing list about
-- a clash with texmf-var on a system that had texlive installed. One way
-- to figure that out is to use kpse. We had the code anyway.
--
-- mtxrun --script kpse --progname=pdftex --findfile context.mkii

trackers.enable("resolvers.lib.silent")

local kpse = LUATEXENGINE == "luametatex" and require("libs-imp-kpse")

if type(kpse) ~= "table" then
    return
end

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-kpse</entry>
  <entry name="detail">ConTeXt KPSE checking utility</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="progname"><short>mandate, set the program name (e.g. pdftex)</short></flag>
    <flag name="findfile"><short>report the fully qualified path of the given file</short></flag>
    <flag name="expandpath"><short>expand the given path variable</short></flag>
    <flag name="expandvar"><short>expand a variable</short></flag>
    <flag name="expandbraces"><short>expand a complex variable specification</short></flag>
    <flag name="varvalue"><short>show the value of a variable</short></flag>
    <flag name="readablefile"><short>report if a file is readable</short></flag>
    <flag name="filetypes"><short>list all supported formats</short></flag>
   </subcategory>
   <subcategory>
    <flag name="fonts"><short>only wipe fonts</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-kpse",
    banner   = "ConTeXt KPSE checking utility",
    helpinfo = helpinfo,
}

local report   = application.report
local argument = environment.argument
local target   = environment.files[1]

if argument("progname") or argument("programname") then
    kpse.set_program_name(argument("progname"))
else
    application.help()
    return
end

if argument("exporthelp") then
    application.export(environment.argument("exporthelp"),target)
elseif argument("filetypes") or argument("formats") then
    print(table.concat(kpse.get_file_types()," "))
elseif type(target) == "string" and target ~= "" then
    if argument("findfile") or argument("find-file") then
        print(kpse.find_file(target,argument("format")))
    elseif argument("expandpath") or argument("expand-path") then
        print(kpse.expand_path(target))
    elseif argument("expandvar") or argument("expand-var") then
        print(kpse.expand_var(target))
    elseif argument("expandbraces") or argument("expand-braces") then
        print(kpse.expand_braces(target))
    elseif argument("varvalue") or argument("var-value") then
        print(kpse.var_value(target))
    elseif argument("readablefile") or argument("readable-file") then
        print(kpse.readable_file(target))
    else
        application.help()
    end
else
    application.help()
end
