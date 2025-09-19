if not modules then modules = { } end modules ['mtx-squid'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- mtxrun --script squid  --configure --wifi --ssid  string
-- mtxrun --script squid  --configure --wifi --psk   string
-- mtxrun --script squid  --configure --wifi --reset

-- mtxrun --script squid  --configure --save
-- mtxrun --script squid  --configure --format

-- mtxrun --script squid  --configure --color 0|1|2
-- mtxrun --script squid  --configure --mode  serial|wifi|bluetooth|hue
-- mtxrun --script squid  --configure --leds  1|12|16|24|30|40|60|144

-- mtxrun --script squid  --signal [--test] --[reset|busy|done|finished|problem|error|on|off] N
-- mtxrun --script squid  --squid  [--test] --[reset|busy|done|finished|problem|error|on|off]

-- mtxrun --script squid  --squid  --test
-- mtxrun --script squid  --signal --test --quadrant
-- mtxrun --script squid  --signal --test --steps
-- mtxrun --script squid  --signal --test --quadrant --steps

local type, tonumber = type, tonumber
local format = string.format
local concat = table.concat

local osserialwrite = serial and serial.write or os.serialwrite
local ossleep       = os.sleep

-- function osserialwrite(port,baud,str)
--     local s = serial.open(port,baud)
--     if s then
--         serial.send(s,str)
--         serial.close(s)
--         return true
--     end
-- end

-- function osserialwrite(port,baud,str)
--     serial.open(port,baud)
--     serial.write(s,str)
-- end


local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-squid</entry>
  <entry name="detail">ConTeXt State Reporting Plus</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="configure"><short>create configuration</short></flag>
    <flag name="signal"><short>set segments state</short></flag>
    <flag name="squid"><short>set page state</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Examples</title>
   <subcategory>
    <example><command>mtxrun --script squid ... todo ...</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local arguments = environment.arguments
local files     = environment.files

local application = logs.application {
    name     = "mtx-squid",
    banner   = "ConTeXt State Reporting Plus 1.00",
    helpinfo = helpinfo,
}

scripts       = scripts       or { }
scripts.squid = scripts.squid or { }

local verbose = arguments.verbose
local signals = utilities.signals
local report  = application.report
local state   = signals.loadstate()
local server  = state and state.servers.squid or state.servers.gadget
local baud    = arguments.baud or (server and server.baud) or 115200
local port    = arguments.port or (server and server.port)

local prefix  = signals.serialprefix

if not osserialwrite then
    report("no support for serial communication")
    return
elseif not server then
    report("missing configuration file (see mtxrun --script signal)")
    return
elseif not port then
    report("unknown port variable")
    return
end

local function loadconfiguration(create)
    local data, name = utilities.signals.loadstate()
    if not data then
        if create then
            report("creating configuration file %a",utilities.signals.configuration)
            data = { }
        else
            report("no configuration file %a found",utilities.signals.configuration)
            return
        end
    end
    -- sanity check
    if not data.version then data.version = utilities.signals.version end
    if not data.comment then data.comment = "signal setup file" end
    if not data.servers then data.servers = { } end
    if not data.signals then data.signals = { } end
    if not data.usage   then data.usage   = { } end
    return data, name
end

local function saveconfiguration(data)
    return utilities.signals.savestate(data)
end

-- local validleds = {
--     [  1] = true,
--     [ 12] = true,
--     [ 16] = true,
--     [ 24] = true, -- best
--     [ 30] = true,
--     [ 40] = true,
--     [ 60] = true,
--     [144] = true,
-- }

-- We can save the device configuration in the main configuration file if
-- needed.

local function checksleep()
    local sleep = arguments.sleep
    if sleep then
        ossleep(tonumber(sleep) or 2)
    end
end

if verbose then
    report("port  : %s",port)
    report("speed : %s baud",baud)
    report("delay : %s seconds",arguments.delay or (arguments.text and 0.2 or 2))
    report("")
end

local function send(str)
    str = prefix .. str
    local r = osserialwrite(port,baud,str)
    if verbose then
        report("%s : %s",r and "sent" or "fail",str)
    end
end

function scripts.squid.configure()
    --
    -- configuration on using machine
    --
    if arguments.port then
        -- todo
    end
    if arguments.baud then
        -- todo
    end
    --
    -- configuration on device:
    --
    if arguments.format then
        send("cf")
    end
    local mode = arguments.mode
    if type(mode) == "string" then
        if mode == "serial" then
            send("cms")
        elseif mode == "hue" then
            send("cmh")
        elseif mode == "wifi" then
            send("cmw")
        elseif mode == "access" then
            send("cma")
        elseif mode == "bluetooth" then
            send("cmb")
        end
    end
    if arguments.remote then
        if arguments.reset then
            send("crr")
        elseif arguments.enable then
            send("cre")
        elseif arguments.disable then
            send("crd")
        end
        local address = arguments.address
        if type(address) == "string" then
            send(format("cra%s\r",address))
        end
     -- if arguments.server then
     --     send("crs")
     -- end
     -- if arguments.client then
     --     send("crc")
     -- end
    elseif arguments.hue then
        local token = arguments.token
        local hub   = arguments.hub
        local light = arguments.light or arguments.lamps
        if not token and not hub and not light then
            local h = state and state.servers and state.servers.hue
            if h then
                token = h.token
                hun   = h.url
                light = h.lamps
            end
        end
        if arguments.reset then
            send("chr")
        end
        if type(token) == "string" then
            send("cht"..token.."\r")
        end
        if type(hub) == "string" then
            send("chh"..hub.."\r")
        end
        if type(light) == "string" then
            light = utilities.parsers.settings_to_array(light)
        end
        if type(light) == "table" then
            local n = #light
            if n >= 1 and n <= 4 then
                for i=1,n do
                    light[i] = format("%04i",tonumber(light[i] or 0) or 0)
                end
                send(format("chl%i%s\r",n,concat(light,"")))
            end
        end
    elseif arguments.wifi then
        local ssid = arguments.ssid
        local psk  = arguments.psk
        if arguments.reset then
            send("cwr")
        end
        if type(ssid) == "string" then
            send(format("cws%s\r",ssid))
        end
        if type(psk) == "string" then
            send(format("cwp%s\r",psk))
        end
        if arguments.connect then
            send("cwc")
        end
    elseif arguments.bluetooth then
        --
    elseif arguments.color then
        local palette = tonumber(arguments.color) or 0
        if palette >= 0 and palette <= 9 then
            send(format("cc%i",palette))
        end
 -- elseif arguments.leds then
 --     local leds = validleds[tonumber(files[1]) or 24] or 24
 --     -- todo
    end
    if arguments.save then
        send("cs")
    end
    if arguments.load then
        send("cl")
    end
end

function scripts.squid.signal()
    if arguments.test then
        local n = arguments.quadrant and 4 or 8
        local h = arguments.quadrant and "k" or "s"
        if arguments.hue then
            n = 1
            h = "h"
        end
        send(h.."r")
        ossleep(1)
        if not arguments.hue and arguments.steps then
            for i=1,n do
                if i > 1 then
                    send(h.."d"..(i-1))
                end
                for j=1,15 do
                    send(h.."s"..i)
                    ossleep(.2)
                end
            end
        else
            for i=1,n do
                if i > 1 then
                    send(h.."d"..(i-1))
                end
                send(h.."b"..i)
                ossleep(.5)
            end
        end
        if arguments.error then
            send(h.."e")
        elseif arguments.problem then
            send(h.."p")
        else
            send(h.."f")
        end
    else
        local pre = arguments.quadrant and "k" or "s"
        local cmd = "r"
        local seg = tonumber(files[1]) or 0
        if arguments.busy then
            cmd = "b"
        elseif arguments.done then
            cmd = "d"
        elseif arguments.finished then
            cmd = "f"
        elseif arguments.problem then
            cmd = "p"
        elseif arguments.error then
            cmd = "e"
        end
        send(pre..cmd..seg)
        checksleep()
    end
end

function scripts.squid.forward()
    send("wf")
end


function scripts.squid.address()
    send("wa")
end

function scripts.squid.text()
    local text  = string.upper(environment.files[1] or "")
    local delay = tonumber(arguments.delay) or .2
    local pause = tonumber(arguments.pause) or delay/2
    send("ar")
    for c in string.gmatch(text,".") do
        send("tf"..c)
        ossleep(delay)
        send("ar")
        ossleep(pause)
    end
    ossleep(1)
    send("ar")
end

function scripts.squid.number()
    local str = string.upper(environment.files[1] or "1:25")
    send("ar")
    utilities.parsers.stepper(str,99,function(i)
        if i >= 0 and i <= 99 then
            send("nf"..i)
            ossleep(tonumber(arguments.delay) or 1)
        end
    end)
    ossleep(1)
    send("ar")
end

function scripts.squid.squid()
    if arguments.test then
        local cmd = "qf"
        if arguments.error then
            cmd = "qe"
        elseif arguments.problem then
            cmd = "qp"
        end
        send("qr")
        ossleep(1)
        for i=1,65 do
            send("qs")
            ossleep(.02)
        end
        send(cmd)
    else
        local cmd = "qr"
        if arguments.busy then
            cmd = "qb"
        elseif arguments.done then
            cmd = "qd"
        elseif arguments.finished then
            cmd = "qf"
        elseif arguments.problem then
            cmd = "qp"
        elseif arguments.error then
            cmd = "qe"
        end
        send(cmd)
        checksleep()
    end
end

function scripts.squid.reset()
    send("r")
end

function scripts.squid.show()
    local data, name = loadconfiguration()
    if data then
        report("file: %s",name)
        report("data:\n\n%s\n",table.serialize(data,false))
    end
end

function scripts.squid.sleep()
    checksleep()
end

function scripts.squid.info()
    report("port : %s",port)
    report("baud : %s",baud)
end

if arguments.configure then
    scripts.squid.configure()
elseif arguments.signal then
    scripts.squid.signal()
elseif arguments.squid then
    scripts.squid.squid()
elseif arguments.forward then
    scripts.squid.forward()
elseif arguments.text then
    scripts.squid.text()
elseif arguments.number then
    scripts.squid.number()
elseif arguments.info then
    scripts.squid.info()
elseif arguments.show then
    scripts.squid.show()
elseif arguments.reset then
    scripts.squid.reset()
elseif arguments.sleep then
    scripts.squid.sleep()
elseif arguments.address then
    scripts.squid.address()
elseif arguments.exporthelp then
    application.export(arguments.exporthelp,environment.files[1])
else
    application.help()
end

-- table = {
--     blue    = { r = 0, g = 0,    b =  1, h = 43691, s = 255, v = 1, x = 18.05, y =   7.22, z =  95.05, xz = 0.15, yx = 0.06, },
--     green   = { r = 0, g = 1,    b =  0, h = 21845, s = 255, v = 1, x = 35.76, y =  71.52, z =  11.92, xz = 0.30, yx = 0.60, },
--     off     = { r = 0, g = 0,    b =  0, h =     0, s =   0, v = 0, x =  0.00, y =   0.00, z =   0.0,  xz = 0.31, yx = 0.33, },
--     on      = { r = 1, g = 1,    b =  1, h =     0, s =   0, v = 1, x = 95.05, y = 100.00, z = 108.90, xz = 0.31, yx = 0.33, },,
--     orange  = { r = 1, g = 0.65, b =  0, h =  7100, s = 255, v = 1, x = 54.83, y =  48.44, z =   6.46, xz = 0.50, yx = 0.44, },
--     red     = { r = 1, g = 0,    b =  0, h =     0, s = 255, v = 1, x = 41.24, y =  21.26, z =   1.93, xz = 0.64, yx = 0.33, },
--     reset   = { r = 0, g = 0,    b =  0, h =     0, s =   0, v = 0, x =  0.00, y =   0.00, z =   0.0,  xz = 0.31, yx = 0.33, },
--     white   = { r = 1, g = 1,    b =  1, h =     0, s =   0, v = 1, x = 95.05, y = 100.00, z = 108.90, xz = 0.31, yx = 0.33, },
--     yellow  = { r = 1, g = 1,    b =  0, h = 10923, s = 255, v = 1, x = 77.00, y =  92.78, z =  13.85, xz = 0.42, yx = 0.51, },
-- }
