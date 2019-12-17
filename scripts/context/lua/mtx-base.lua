if not modules then modules = { } end modules ['mtx-base'] = {
    version   = 1.001,
    comment   = "formerly known as luatools",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-base</entry>
  <entry name="detail">ConTeXt TDS Management Tool (aka luatools)</entry>
  <entry name="version">1.35</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="generate"><short>generate file database</short></flag>
    <flag name="variables"><short>show configuration variables</short></flag>
    <flag name="configurations"><short>show configuration order</short></flag>
    <flag name="expand-braces"><short>expand complex variable</short></flag>
    <flag name="expand-path"><short>expand variable (resolve paths)</short></flag>
    <flag name="expand-var"><short>expand variable (resolve references)</short></flag>
    <flag name="show-path"><short>show path expansion of ...</short></flag>
    <flag name="var-value"><short>report value of variable</short></flag>
    <flag name="find-file"><short>report file location</short></flag>
    <flag name="find-path"><short>report path of file</short></flag>
    <flag name="make"><short>[or <ref name="ini"/>] make luatex format</short></flag>
    <flag name="run"><short>[or <ref name="fmt"/>] run luatex format</short></flag>
    <flag name="compile"><short>assemble and compile lua inifile</short></flag>
    <flag name="verbose"><short>give a bit more info</short></flag>
    <flag name="all"><short>show all found files</short></flag>
    <flag name="format" value="str"><short>filter cf format specification (default 'tex', use 'any' for any match)</short></flag>
    <flag name="pattern" value="str"><short>filter variables</short></flag>
    <flag name="trackers" value="list"><short>enable given trackers</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-base",
    banner   = "ConTeXt TDS Management Tool (aka luatools) 1.35",
    helpinfo = helpinfo,
}

local report = application.report

-- private option --noluc for testing errors in the stub

local pattern    = environment.arguments["pattern"]  or nil
local fileformat = environment.arguments["format"]   or "" -- nil ?
local allresults = environment.arguments["all"]      or false
local trace      = environment.arguments["trace"]

if type(pattern) == 'boolean' then
    report("invalid pattern specification")
    pattern = nil
end

if trace then
    resolvers.settrace(trace)  -- move to mtxrun ?
end

if environment.arguments["find-file"] then
    resolvers.load()
    if pattern then
        resolvers.dowithfilesandreport(resolvers.findfiles, { pattern }, fileformat, allresults)
    else
        resolvers.dowithfilesandreport(resolvers.findfiles, environment.files, fileformat, allresults)
    end
elseif environment.arguments["find-path"] then
    resolvers.load()
    local path = resolvers.findpath(environment.files[1], fileformat)
    print(path) -- quite basic, wil become function in logs
elseif environment.arguments["expand-braces"] then
    resolvers.load("nofiles")
    resolvers.dowithfilesandreport(resolvers.expandbraces, environment.files)
elseif environment.arguments["expand-path"] then
    resolvers.load("nofiles")
    resolvers.dowithfilesandreport(resolvers.expandpath, environment.files)
elseif environment.arguments["expand-var"] or environment.arguments["expand-variable"] then
    resolvers.load("nofiles")
    resolvers.dowithfilesandreport(resolvers.expansion, environment.files)
elseif environment.arguments["show-path"] or environment.arguments["path-value"] then
    resolvers.load("nofiles")
    resolvers.dowithfilesandreport(resolvers.showpath, environment.files)
elseif environment.arguments["var-value"] or environment.arguments["show-value"] then
    resolvers.load("nofiles")
    resolvers.dowithfilesandreport(resolvers.variable, environment.files)
elseif environment.arguments["format-path"] then
    resolvers.load()
    report(caches.getwritablepath("format"))
elseif pattern then -- brrr
    resolvers.load()
    resolvers.dowithfilesandreport(resolvers.findfiles, { pattern }, fileformat, allresults)
elseif environment.arguments["generate"] then
    resolvers.renewcache()
    trackers.enable("resolvers.locating")
    resolvers.load()
elseif environment.arguments["make"] or environment.arguments["ini"] or environment.arguments["compile"] then
    resolvers.load()
    trackers.enable("resolvers.locating")
    environment.make_format(environment.files[1] or "")
elseif environment.arguments["variables"] or environment.arguments["show-variables"] or environment.arguments["expansions"] or environment.arguments["show-expansions"] then
    resolvers.load("nofiles")
    resolvers.listers.variables(pattern)
elseif environment.arguments["configurations"] or environment.arguments["show-configurations"] then
    resolvers.load("nofiles")
    resolvers.listers.configurations()
elseif environment.arguments["exporthelp"] then
    application.export(environment.arguments["exporthelp"],environment.files[1])
elseif environment.arguments["help"] or (environment.files[1]=='help') or (#environment.files==0) then
    application.help()
elseif environment.files[1] == 'texmfcnf.lua' then
    resolvers.load("nofiles")
    resolvers.listers.configurations()
else
    resolvers.load()
    resolvers.dowithfilesandreport(resolvers.findfiles, environment.files, fileformat, allresults)
end
