if not modules then modules = { } end modules ['mtx-youless'] = {
    version   = 1.002,
    comment   = "script to fetch data from kwh meter polling device",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE",
    license   = "see context related readme files"
}

-- This script can fetch data from a youless device (http://www.youless.nl/) where data
-- is merged into a file. The data concerns energy consumption (current wattage as well
-- as kwh usage). There is an accompanying module to generate graphics.

require("util-you")

local formatters = string.formatters

-- the script

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-youless</entry>
  <entry name="detail">youless Fetcher</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="collect"><short>collect data from device</short></flag>
    <flag name="nobackup"><short>don't backup old datafile</short></flag>
    <flag name="nofile"><short>don't write data to file (for checking)</short></flag>
    <flag name="kwh"><short>summative kwh data</short></flag>
    <flag name="watt"><short>collected watt data</short></flag>
    <flag name="host"><short>ip address of device</short></flag>
    <flag name="auto"><short>fetch kwh and watt data every hour</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Example</title>
   <subcategory>
    <example><command>mtxrun --script youless --collect --host=192.168.2.50 --kwh</command></example>
    <example><command>mtxrun --script youless --collect --host=192.168.2.50 --watt somefile.lua</command></example>
    <example><command>mtxrun --script youless --collect --host=192.168.2.50 --auto file-prefix</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-youless",
    banner   = "YouLess Fetcher 1.00",
    helpinfo = helpinfo,
}

local report = application.report

scripts         = scripts         or { }
scripts.youless = scripts.youless or { }

function scripts.youless.collect()
    local host     = environment.arguments.host
    local nobackup = environment.arguments.nobackup
    local nofile   = environment.arguments.nofile
    local password = environment.arguments.password
    local filename = environment.files[1]
    local delay    = tonumber(environment.delay) or 12*60*60

    local function fetch(filename,variant)
        local data = utilities.youless.collect {
            filename = filename,
            host     = host,
            variant  = variant,
            nobackup = nobackup,
            password = password,
        }
        if type(data) ~= "table" then
            report("no data collected")
        elseif filename == "" then
            report("data collected but not saved")
        end
        report("using variant %a",variant)
        if filename ~= "" then
            report("using file %a",filename)
        end
        report("current time %a",os.now())
    end

    if not host then
        host = "192.168.2.50"
        report("using default host %a",host)
    else
        report("using host %a",host)
    end
    if nobackup then
        report("not backing up data file")
    end

    if environment.arguments.auto then
        local filename_kwh  = formatters["%s-kwh.lua" ](filename ~= "" and filename or "youless")
        local filename_watt = formatters["%s-watt.lua"](filename ~= "" and filename or "youless")
        while true do
            fetch(filename_kwh,"kwh")
            fetch(filename_watt,"watt")
            report("sleeping for %i seconds",delay)
            io.flush()
            os.sleep(delay)
        end
    else
        local variant  = environment.arguments.kwh and "kwh" or environment.arguments.watt and "watt"
        if not variant then
            report("provide variant --kwh or --watt")
            return
        end
        if nofile then
            filename = ""
        elseif not filename or filename == "" then
            filename = formatters["youless-%s.lua"](variant)
        end
        fetch(filename,variant)
    end
end

if environment.argument("collect") then
    scripts.youless.collect()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
