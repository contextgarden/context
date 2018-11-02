if not modules then modules = { } end modules ['mtx-evohome'] = {
    version   = 1.002,
    comment   = "script to fetch data from a evohome device",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE",
    license   = "see context related readme files"
}

local evohome = require("util-evo")

local formatters = string.formatters

-- the script

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-evohome</entry>
  <entry name="detail">Evohome Fetcher</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="collect"><short>collect data from device</short></flag>
    <flag name="update"><short>update data from device</short></flag>
    <flag name="presets"><short>file with authenciation data</short></flag>
    <flag name="auto"><short>fetch temperature data every hour</short></flag>
    <flag name="port"><short>server port when running the service, default: 8068</short></flag>
    <flag name="host"><short>server host when running the service, default: localhost</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Example</title>
   <subcategory>
    <example><command>mtxrun --script evohome --collect --presets=c:/data/develop/domotica/code/evohome-presets.lua</command></example>
    <example><command>mtxrun --script evohome --server --presets=c:/data/develop/domotica/code/evohome-presets.lua</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-evohome",
    banner   = "Evohome Fetcher 1.00",
    helpinfo = helpinfo,
}

local report = application.report

scripts         = scripts         or { }
scripts.evohome = scripts.evohome or { }

local arguments = environment.arguments
local files     = environment.files

function scripts.evohome.collect()
    local presets = arguments.presets
    local delay   = tonumber(arguments.delay) or 15*60*60
    if presets then
        presets = evohome.helpers.loadpresets(presets)
    end
    if presets then
        local function fetch()
            report("current time %a",os.now())
            evohome.helpers.updatetemperatures(presets)
        end
        if arguments.auto then
            while true do
                fetch()
                report("sleeping for %i seconds",delay)
                io.flush()
                os.sleep(delay)
            end
        else
            fetch(presets)
        end
    else
        report("invalid preset file")
    end
end

function scripts.evohome.update()
    local presets = arguments.presets
    if presets then
        presets = evohome.helpers.loadpresets(presets)
    end
    if presets then
        evohome.helpers.geteverything(presets)
    else
        report("invalid preset file")
    end
end

function scripts.evohome.server()
    local presets = arguments.presets
    if presets then
        require("util-evo-imp-server")
        evohome.server {
            filename = presets, -- e:/domotica/code/evohome-presets.lua
            host     = arguments.host,
            port     = tonumber(arguments.port),
        }
    else
        report("invalid preset file")
    end
end

if environment.argument("collect") then
    scripts.evohome.collect()
elseif environment.argument("update") then
    scripts.evohome.update()
elseif environment.argument("server") then
    scripts.evohome.server()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
