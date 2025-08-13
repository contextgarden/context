if not modules then modules = { } end modules ['util-sig-imp-runner'] = {
    version   = 1.002,
    comment   = "companion to util-sig.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type

-- hue    (in local hue network, will do)
-- conbee (stand alone on machine, done)
-- fritz  (only when i have a test setup)
-- serial (in prototyping stage)

-- Interfaces:

local enable   = false
local disable  = false
local wipe     = false
local prune    = false

local trace    = environment.arguments.verbose

local signals  = utilities.signals
local report   = signals.report or logs.reporter("signal")
local state    = signals.loadstate()

local server   = state and state.servers[state.usage.server or "default"]
local protocol = server and server.protocol or "hue"
local lamps_8  = { 1, 2, 3, 4, 5, 6, 7, 8 }
local lamps_4  = { 1, 2, 3, 4 }
local lamps    = protocol == "serial" and lamps_8 or lamps_4

-- protocol = "hack" -- generate table

local serialwrite = serial and serial.write or os.serialwrite

if protocol == "serial" and serialwrite then

    local states = {
        reset    = "r",
        off      = "r",
        on       = "r",
        busy     = "b",
        error    = "e",
        done     = "d",
        maxruns  = "p",
        problem  = "p",
        finished = "f",
    }

    local port = false
    local baud = 115200

    if server then
        port = server.port or port
        baud = server.baud or baud
    end

    if not port then
        report("unknown serial post")
        return
    end

    if state.signals and state.signals.runner then
     -- lamps = state.signals.runner.lamps or lamps
    end

    if #lamps ~= 4 or #lamps ~= 8 then
        lamps = lamps_8
    end

    local prefix = signals.serialprefix

    enable = function(state,first,last)
        local command = states[state]
        if command then
            local count = #lamps
            for i=first,last do
                -- q=squid k=quadrant s=segment a=all
                local cmd = prefix .. (count == 8 and "s" or "k") .. command .. i
--                 .. "\n"
--                 .. " "
--                 print(cmd)
                serialwrite(port,baud,cmd)
            end
        end
    end

    disable = function(state,first,last)
        enable("reset",first,last)
    end

elseif protocol == "hue" or protocol == "deconz" or protocol == "hack" then

    -- A few helpers:

    local round = math.round

    local function rgbtohsv(r,g,b)
        local offset, maximum, other_1, other_2
        local hue        = 0
        local saturation = 0
        local brightness = 0
        if r >= g and r >= b then
            offset, maximum, other_1, other_2 = 0, r, g, b
        elseif g >= r and g >= b then
            offset, maximum, other_1, other_2 = 2, g, b, r
        else
            offset, maximum, other_1, other_2 = 4, b, r, g
        end
        if maximum == 0 then
            ---
        else
            local minimum = other_1 < other_2 and other_1 or other_2
            if maximum == minimum then
                brightness = maximum
            else
                local delta = maximum - minimum
                hue        = (offset + (other_1-other_2)/delta)*60
                saturation = delta/maximum
                brightness = maximum
if hue < 0 then
    hue = hue + 360
end
hue        = round(hue*65536/360)
saturation = round(saturation*256 - 1)
            end
        end
        return {
            hue        = hue,
            saturation = saturation,
            brightness = brightness,
        }
    end

    local function rgbtoxyz(r,g,b)
        r = 100 * ((r > 0.04045) and ((r + 0.055)/1.055)^2.4 or (r / 12.92))
        g = 100 * ((g > 0.04045) and ((g + 0.055)/1.055)^2.4 or (g / 12.92))
        b = 100 * ((b > 0.04045) and ((b + 0.055)/1.055)^2.4 or (b / 12.92))
        return {
            x = r * 0.4124 + g * 0.3576 + b * 0.1805,
            y = r * 0.2126 + g * 0.7152 + b * 0.0722,
            z = r * 0.0193 + g * 0.1192 + b * 0.9505,
        }
    end

    -- tasklist /V /FO CSV
    -- last column Window Title

    -- We use a Phoscon Conbee II usb stick as zigbee hub with 4 Hue color lamps and
    -- also two Ikea switches to turn them off.

    -- get an access token:
    --
    -- curl -X POST -i "http://127.0.0.1/api" --data "{ \"devicetype\" : \"password\" }"
    --
    -- local u  = "XXXXXXXXXX"

    -- todo: switches

    local next, dofile, type = next, dofile, type
    local format, gsub, find = string.format, string.gsub, string.find

    local jsontostring = utilities.json.tostring
    local jsontolua    = utilities.json.tolua

    local url   = "http://127.0.0.1/"
    local token = "XXXXXXXXXX"

    if state then
        if server then
            url   = server.url   or url
            token = server.token or token
        end
        if state.signals and state.signals.runner then
            lamps = state.signals.runner.lamps or lamps
        end
        url = gsub(url,"/+$","")
    end

    url = file.join(url,"api",token)

    local how = {
        red     = { 1, 0,   0 },
        green   = { 0, 1,   0 },
        blue    = { 0, 0,   1 },
        cyan    = { 0, 1,   1 },
        magenta = { 1, 0,   1 },
        yellow  = { 1, 1,   0 },
        white   = { 1, 1,   1 },
        orange  = { 1, .65, 0 },
        off     = { 0, 0,   0 },
        reset   = { 0, 0,   0 },
        on      = { 1, 1,   1 },
    }

    if protocol == "hack" then

        for k, v in next, how do
            local hsv = rgbtohsv(unpack(v))
            local xyz = rgbtoxyz(unpack(v))
            local sum = xyz.x + xyz.y + xyz.z
            local nop = rgbtoxyz(1,1,1)
            local som = nop.x + nop.y + nop.z
            v.x  = xyz.x
            v.y  = xyz.y
            v.z  = xyz.z
            v.h  = hsv.hue
            v.s  = hsv.saturation
            v.v  = hsv.brightness
            v.xz = sum == 0 and nop.x/som or xyz.x/sum
            v.yx = sum == 0 and nop.y/som or xyz.y/sum
        end

        inspect(how)

        os.exit()

    end

    for key, value in next, how do
        local hsv = rgbtohsv(value[1],value[2],value[3])
        local xyz = rgbtoxyz(value[1],value[2],value[3])
        local sum = xyz.x + xyz.y + xyz.z
        local nop = rgbtoxyz(1,1,1)
        local som = nop.x + nop.y + nop.z
        how[key] = {
            hue        = hsv.hue,
            saturation = hsv.saturation,
            brightness = hsv.brightness,
            x          = xyz.x,
            y          = xyz.y,
            z          = xyz.z,
            xz         = sum == 0 and nop.x/som or xyz.x/sum,
            yz         = sum == 0 and nop.y/som or xyz.y/sum,
        }
    end

    local states = {
        reset    = how.reset,
        off      = how.off,
        on       = how.on,
        busy     = how.blue,
        error    = how.red,
        done     = how.green,
        maxruns  = how.orange,
        problem  = how.orange,
        finished = how.yellow,
    }

    local curl  = false
    local fetch = false

    local name = resolvers.findfile("libs-imp-curl.lmt") or ""
    local curl = name ~= "" and dofile(name)

    -- todo: protocol = hue | deconz

    -- print(curl)

    if curl and curl.getversion and curl.getversion() then

        fetch = function(t)
            local kind   = t.kind
            local result = "unsupported method"
            local detail = nil
            if kind == "put" then
                result, detail = curl.fetch {
                    url           = t.url,
                    postfields    = t.data,
                    customrequest = "PUT",
                    sslverifypeer = false,
                    sslverifyhost = false,
                    timeout       = 1,
                }
            elseif kind == "get" then
                result, detail = curl.fetch {
                    url           = t.url,
                    sslverifypeer = false,
                    sslverifyhost = false,
                    timeout       = 1,
                }
            elseif kind == "delete" then
                result, detail = curl.fetch {
                    url           = t.url,
                    customrequest = "DELETE",
                    sslverifypeer = false,
                    sslverifyhost = false,
                    timeout       = 1,
                }
                print(t.url,detail)
            elseif kind == "post" then
                result, detail = curl.fetch {
                    url           = t.url,
                    postfields    = t.data,
                    customrequest = "POST",
                    sslverifypeer = false,
                    sslverifyhost = false,
                    timeout       = 1,
                }
            end
         -- local t = type(result) == "string" and jsontolua(result)
         -- return type(t) == "table" and t or result
    --         print(detail)
            return result
        end

    else

     -- local trigger = trace and os.execute or os.resultof
        local trigger = os.execute

        local getfmt    = [[curl -k -s           -i "%s"]]
        local putfmt    = [[curl -k -s -X PUT    -i "%s" --data "%s"]]
        local postfmt   = [[curl -k -s -X POST   -i "%s" --data "%s"]]
        local deletefmt = [[curl -k -s -X DELETE -i "%s"]]

        fetch = function(t)
            local kind   = t.kind
            local result = "unsupported method"
            if kind == "put" then
                local dat = gsub(t.data,'"','\\"')
                local cmd = format(putfmt,t.url,dat)
                result = trigger(cmd)
            elseif kind == "get" then
                local cmd = format(putfmt,t.url)
                result = trigger(cmd)
            elseif kind == "delete" then
                local cmd = format(deletefmt,t.url)
                result = trigger(cmd)
            elseif kind == "post" then
                local dat = gsub(t.data,'"','\\"')
                local cmd = format(deletefmt,t.url,dat)
                result = trigger(cmd)
            end
         -- local t = type(result) == "string" and jsontolua(result)
         -- return type(t) == "table" and t or result
            return result
        end

    end

    local function action(state,url,data,time,kind)
        statistics.starttiming("signals")
        local result = fetch {
            url  = url,
            data = data,
            kind = kind or "put",
        }
        if trace then
            if type(result) == "table" then
                result = table.serialized(result,false)
            end
            report("result: %s",tostring(result))
        end
        statistics.stoptiming("signals")
        local seconds = statistics.elapsedseconds("signals")
        if time and seconds and seconds ~= "" then
            report("last state %a, total time spent: %s",state,seconds)
        end
        return result
    end

    enable = function(state,first,last)
        local spec = states[state] or states.reset
        if spec then
            local lampdata = jsontostring {
                on  = true,
                bri = 255,
                -- normally okay
                sat = spec.saturation,
                hue = spec.hue,
                -- needed for hive lamp
--                 xy  = { spec.xz, spec.yz },
            }
            local plugdata = jsontostring {
                on  = true,
            }
            for lamp=first,last do
                local valid = lamps[lamp]
                if valid then
                    local url = format(
                        "%s/lights/%i/state",
                        url,
                        valid < 0 and -valid or valid
                    )
                    action(
                        state,
                        url,
                        valid < 0 and plugdate or lampdata,
                        lamp==last
                    )
                end
            end
        end
    end

    disable = function(state,first,last)
        local spec = states[state] or states.reset
        if spec then
            local lampdata = jsontostring {
                on  = false,
                bri = 255,
                -- normally okay
                sat = spec.saturation,
                hue = spec.hue,
                -- needed for hive lamp
--                 xy  = { spec.xz, spec.yz },
            }
            local plugdata = jsontostring {
                on  = false,
            }
            for lamp=first,last do
                local valid = lamps[lamp]
                if valid then
                    local url = format(
                        "%s/lights/%i/state",
                        url,
                        valid < 0 and -valid or valid
                    )
                    action(
                        state,
                        url,
                        valid < 0 and plugdate or lampdata,
                        lamp==last
                    )
                end
            end
        end
    end

    -- This is only for Hue (where we can actually run out of rules). This is
    -- for configuring the hub, not for users.

    prune = protocol == "hue" and function(state,id,max)
        -- Only for the administrator, removes all rules. We check the state again.
        if state == "prune" then
            id  = tonumber(id)
            max = tonumber(max)
            if id or max then
                local first = id or 1
                local last  = id or max
                for i=first,last do
                    --
                    -- DELETE /rules/ResetState3
                    --
                    local wipeurl = format(
                        "%s/rules/%i",
                        url,
                        i
                    )
                    action(
                        "prune",
                        wipeurl,
                        "",
                        false,
                        "delete"
                    )
                end
            end
        end
    end or false

    wipe = protocol == "hue" and function(state,lamp,minutes)
        -- Only for the administrator, sets a timer. We check the state again.
        if state == "wipe" and type(lamp) == "number" then
            local spec = states.reset
            if spec then
                local wipe = jsontostring {
                    name = format("ResetState%i",lamp),
                    conditions = {
                        {
                            address  = format("/lights/%i/state/on",lamp),
                            operator = "eq",
                            value    = "true",
                        },
                        {
                            address  = format("/lights/%i/state/on",lamp),
                            operator = "ddx",
                            value    = format("PT00:%02i:00",tonumber(minutes) or 5)
                        }
                    },
                    actions = {
                        {
                            address = format("/lights/%i/state",lamp),
                            method  = "PUT",
                            body    = {
                                on  = false,
                                bri = 255,
                                sat = spec.saturation,
                                hue = spec.hue,
                                -- needed for hive lamp
--                                 xy  = { spec.xz, spec.yz },
                            }
                        }
                    }
                }
                --
                -- POST /rules/Reset_State_3
                --
                local wipeurl = format(
                    "%s/rules",
                    url
                )
                local result = action(
                    "wipe",
                    wipeurl,
                    wipe,
                    lamp==last,
                    "post"
                )
                if type(result) == "string" then
                    result = jsontolua(result)
                    if result then
                        for i=1,#result do
                            local r = result[i]
                            if type(r) == "table" and r.success then
                                return r.success.id
                            end
                        end
                    end
                end
            end
        end
    end or false

end

if not enable then
    report("unknown protocol %a",protocol)
end

local function trigger(state,run,all)
    if state == "wipe" then
        if wipe then
            return wipe("wipe",run,all)
        end
    elseif state == "prune" then
        if prune then
            prune("prune",run,all)
        end
    else
        local noflamps = #lamps
        local usedrun  = tonumber(run) or 0
        if type(run) == "boolean" then
            all     = run
            usedrun = 0
        end
        if usedrun == 0 then
            all     = true
            usedrun = noflamps
        elseif usedrun > noflamps then
            usedrun = noflamps
        end
        if state == "reset" or state == "off" then
            disable(state,1,usedrun)
        elseif all then
            enable(state,1,noflamps)
        elseif state == "finished" then
            enable("finished",1,usedrun)
        else
            enable(state,usedrun,usedrun)
        end
    end
end

-- if no server set then quit

-- local how = {
--     blue   = { 0, 0,   1 },
--     yellow = { 1, 1,   0 },
--     red    = { 1, 0,   0 },
--     green  = { 0, 1,   0 },
--     white  = { 1, 1,   1 },
--     orange = { 1, .65, 0 },
--     off    = { 0, 0,   0 },
--     reset  = { 0, 0,   0 },
--     on     = { 1, 1,   1 },
-- }
--
-- for k, v in next, how do
--     local hsv = rgbtohsv(v.r,v.g,v.b)
--     local xyz = rgbtoxyz(v.r,v.g,v.b)
--     local sum = xyz.x + xyz.y + xyz.z
--     local nop = rgbtoxyz(1,1,1)
--     local som = nop.x + nop.y + nop.z
--     v.x  = xyz.x
--     v.y  = xyz.y
--     v.z  = xyz.z
--     v.h  = hsv.hue
--     v.s  = hsv.saturation
--     v.v  = hsv.brightness
--     v.xz =sum == 0 and nop.x/som or xyz.x/sum
--     v.yx = sum == 0 and nop.y/som or xyz.y/sum
-- end
--
-- inspect(how)

return {
    name    = "runner",
    report  = report,
    trigger = trigger,
}

