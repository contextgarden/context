if not modules then modules = { } end modules ['mtx-signal'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Using wipe and prune is only for experiments. One can better use a switch
-- because onless (in HH's case) a dedicated lamp is used for the non runner
-- processes. So mostly for feature for AFO running on the same hub as HH.

-- mtxrun --script signal --signals --lamps=2,3                 runner
-- mtxrun --script signal --signals --lamps=1,2,3,4             runner
-- mtxrun --script signal --servers --url=https://192.168.2.1/  hue
-- mtxrun --script signal --servers --url=http://192.168.2.1/   conbee
-- mtxrun --script signal --servers --token=XXXXXXXXXX          conbee
-- mtxrun --script signal --servers --protocol=deconz           conbee

-- local connect = [[curl --silent --insecure -X POST -i "http://127.0.0.1/api" --data "{ \"devicetype\" : \"demohans\" }"]]
-- local s = os.resultof(connect)
-- local u  = "A1EDC09865"
-- curl -X GET -i "http://127.0.0.1/api/E2FB3528DA/lights" --data "{ \"devicetype\" : \"test-prive\" }"
-- curl -X GET -i "http://127.0.0.1/api/E2FB3528DA/sensors"

-- tasklist /V /FO CSV
-- last column Window Title

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-signal</entry>
  <entry name="detail">ConTeXt State Reporting</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="create"><short>create configuration</short></flag>
    <flag name="show"><short>show configuration</short></flag>
    <flag name="info"><short>show enabled servers and signals</short></flag>
   </subcategory>
   <subcategory>
    <flag name="servers"><short>set parameter in server entry</short></flag>
    <flag name="signals"><short>set parameter in signal entry</short></flag>
   </subcategory>
   <subcategory>
    <flag name="enable"><short>enable a given signal category</short></flag>
    <flag name="disable"><short>disable a given signal category</short></flag>
    <flag name="usage"><short>use the given server</short></flag>
   </subcategory>
   <subcategory>
    <flag name="run"><short>current run (lamp) number</short></flag>
    <flag name="lamp"><short>current lamp (run) number</short></flag>
    <flag name="state"><short>reset, busy, error, done, maxruns, problem, finished</short></flag>
    <flag name="all"><short>set all devices</short></flag>
    <flag name="reset"><short>turn them off</short></flag>
   </subcategory>
   <subcategory>
    <flag name="wipe"><short>set timer on --lamp=n (use with care or not, administrator !)</short></flag>
    <flag name="prune"><short>reset --max=n timer (use with care or not, administrator !)</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Examples</title>
   <subcategory>
    <example><command>mtxrun --script signal --servers --url=http://127.0.0.1 --token=ABC --protocol=hue huehub</command></example>
    <example><command>mtxrun --script signal --usage huehub</command></example>
    <example><command>mtxrun --script signal --enable runner</command></example>
    <example><command>mtxrun --script signal --disable</command></example>
    <example><command>mtxrun --script signal --info</command></example>
    <example><command>mtxrun --script signal --state=busy runner</command></example>
    <example><command>mtxrun --script signal --state=busy --run=2 runner</command></example>
    <example><command>mtxrun --script signal --state=off runner</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local arguments = environment.arguments
local files     = environment.files

local application = logs.application {
    name     = "mtx-signal",
    banner   = "ConTeXt State Reporting 1.00",
    helpinfo = helpinfo,
}

scripts        = scripts        or { }
scripts.signal = scripts.signal or { }

-- This only handles "runner" but we might add more later. I also use it for
-- configuring "distribution" and "teststuite" but there we don't wipe
-- lights and use switches. Wiping is fragile anyway. And there's also the
--
--   mtxrun --script --reset
--
-- that one can use to turn of the runner lamps.

do

    local function gettrigger()
        local signal  = (type(arguments.signal) == "string" and arguments.signal) or files[1] or "runner"
        local trigger = utilities.signals.initialize(signal)
        if trigger then
            return trigger
        else
            application.report("no trigger %a",signal)
        end
    end

    function scripts.signal.trigger()
        local trigger = gettrigger()
        if trigger then
            trigger(
                arguments.state or "reset",
                arguments.run or arguments.lamp or 0,
                arguments.all or false
            )
        end
    end

    function scripts.signal.wipe() -- set timer on lamp
        local trigger = gettrigger()
        if trigger then
            local lamp = tonumber(arguments.lamp)
            if lamp and arguments.force then
                local id = trigger("wipe",lamp,tonumber(arguments.minutes) or 5)
                application.report("wiping lamp %a has id %a",lamp,id)
                --
                -- rather hue specific so let's not do it now
                --
             -- if id then
             --     local data = utilities.signals.loadstate(true)
             --     local timers = data.usage.timers or { }
             --     data.usage.timers = timers
             --     timers[id] = true
             --     utilities.signals.savestate(data)
             -- end
                --
            else
                application.report("setting timer on lamp %a needs --lamp=l [--minutes=m] and --force",lamp)
            end
        end
    end

    function scripts.signal.prune() -- resets timer on lamp
        local trigger = gettrigger()
        if trigger then
            --
            -- rather hue specific so let's not do it now
            --
         -- local data = utilities.signals.loadstate(true)
         -- for id in table.sortedhash(data.usage.timers or { }) do
         --     trigger("prune",timers[i])
         -- end
         -- data.usage.timers = nil
         -- utilities.signals.savestate(data)
            --
            local id  = tonumber(arguments.id)
            local max = tonumber(arguments.max)
            if (id or max) and arguments.force then
                trigger("prune",id,max)
            else
                application.report("pruning %i rules needs --id=i or --max=m and --force",max)
            end
        end
    end

end

local function loadconfiguration(create)
    local data, name = utilities.signals.loadstate()
    if not data then
        if create then
            application.report("creating configuration file %a",utilities.signals.configuration)
            data = { }
        else
            application.report("no configuration file %a found",utilities.signals.configuration)
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

function scripts.signal.reset()
    local data    = loadconfiguration(true)
    local signals = data.signals
    if signals then
        for signal in table.sortedhash(signals) do
            local trigger = utilities.signals.initialize(signal)
            if trigger then
                trigger(
                    "reset",
                    0,
                    true
                )
            end
        end
    end
end

do

    function scripts.signal.create()
        local data, name = loadconfiguration()
        if data then
            application.report("configuration found in %a",name)
        else
            local data = loadconfiguration(true)
            local name = saveconfiguration(data)
            application.report("configuration saved in %a",name)
        end
    end

    function scripts.signal.servers()
        local server  = files[1] or "default"
        local data    = loadconfiguration(true)
        local servers = data.servers
        local usage   = data.usage
        local target  = servers[server] or { }
        local update  = false
        if arguments.delete then
            if usage.server == server then
                usage.server = nil
            end
            target = nil
        else
            if type(arguments.url) == "string" then
                target.url = arguments.url
                update = true
            end
            if type(arguments.token) == "string" then
                target.token = arguments.token
                update = true
            end
            if type(arguments.protocol) == "string" then
                target.protocol = arguments.protocol
                update = true
            end
            if type(arguments.baud) == "string" then
                target.baud = tonumber(arguments.baud) or 115200
                update = true
            end
            if type(arguments.port) == "string" then
                target.port = port
                update = true
            end
            if update or not usage.server then
                usage.server = server
            end
        end
        servers[server] = target
        saveconfiguration(data)
    end

    function scripts.signal.usage()
        local data  = loadconfiguration(true)
        local usage = data.usage
        if type(arguments.server) == "string" then
            usage.server = arguments.server
        elseif files[1] then
            usage.server = files[1]
        end
        if type(arguments.enable) == "boolean" then
            usage.enabled = arguments.enable
        elseif type(arguments.disable) == "boolean" then
            usage.enabled = not arguments.disable
        end
        saveconfiguration(data)
    end

    function scripts.signal.signals()
        local signal  = files[1] or "default"
        local data    = loadconfiguration(true)
        local signals = data.signals
        local target  = signals[signal] or { }
        if arguments.delete then
            target = nil
        else
            if type(arguments.lamps) == "string" then
                local lamps = utilities.parsers.settings_to_array(arguments.lamps)
                local clean = { }
                for i=1,#lamps do
                    clean[#clean+1] = tonumber(lamps[i])
                end
                if #clean == 0 then
                    clean = nil
                end
                target.lamps = clean
            end
        end
        signals[signal] = target
        saveconfiguration(data)
    end

end

do

    local function set(what)
        local data   = loadconfiguration(true)
        local signal = arguments.signal or environment.files[1]
        if signal then
            local signals = data.signals
            if signals then
                local specific = signals[signal]
                if specific then
                    if type(what) == "boolean" then
                        specific.enabled = what
                        saveconfiguration(data)
                    else
                        return specific.enabled and "enabled" or "disabled"
                    end
                end
            end
        elseif type(what) == "boolean" then
            data.usage.enabled = what
            saveconfiguration(data)
        end
    end

    function scripts.signal.enable ()       set(true )  end
    function scripts.signal.disable()       set(false)  end
    function scripts.signal.enabled() print(set(     )) end

end

function scripts.signal.show()
    local data, name = loadconfiguration()
    if data then
        application.report("file: %s",name)
        application.report("data:\n\n%s\n",table.serialize(data,false))
    end
end

function scripts.signal.sleep()
    os.sleep(tonumber(arguments.sleep) or 2)
end

function scripts.signal.info()
    local data, name = loadconfiguration()
    if data then
        local t = { }
        local s = { }
        local u = data.usage.server
        local e = data.usage.enabled
        for k, v in table.sortedhash(data.servers) do
            if k == u then
                t[#t+1] = k
            else
                t[#t+1] = "[" .. k .. "]"
            end
        end
        for k, v in table.sortedhash(data.signals) do
            local l = v.lamps
            if l then
                l = table.concat(l,",")
            else
                l = "?"
            end
            l = k .. ":" .. l
            if k == v.enabled then
                s[#s+1] = "[" .. l .. "]"
            else
                s[#s+1] = l
            end
        end
        application.report("servers : % t",t)
        application.report("signals : % t",s)
        if type(e) == "boolean" then
            application.report("usage   : %s",e and "enabled" or "disabled")
        end
    end
end

if not scripts.signal.trigger then
    return
elseif arguments.create then
    scripts.signal.create()
elseif arguments.servers then
    scripts.signal.servers()
elseif arguments.signals then
    scripts.signal.signals()
elseif arguments.usage then
    scripts.signal.usage()
elseif arguments.enable then
    scripts.signal.enable()
elseif arguments.disable then
    scripts.signal.disable()
elseif arguments.reset then
    scripts.signal.reset()
elseif arguments.show then
    scripts.signal.show()
elseif arguments.wipe then
    scripts.signal.wipe()
elseif arguments.prune then
    scripts.signal.prune()
elseif arguments.state then
    scripts.signal.trigger()
elseif arguments.enabled then
    scripts.signal.enabled()
elseif arguments.info then
    scripts.signal.info()
elseif arguments.sleep then
    scripts.signal.sleep()
elseif arguments.exporthelp then
    application.export(arguments.exporthelp,environment.files[1])
else
    application.help()
end
