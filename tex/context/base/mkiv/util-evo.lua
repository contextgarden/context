if not modules then modules = { } end modules ['util-evo'] = {
    version   = 1.002,
    comment   = "library for fetching data from an evohome device",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE",
    license   = "see context related readme files"
}

-- When I needed a new boiler for heating I decided to replace a partial
-- (experimental) zwave few-zone solution by the honeywell evohome system that can
-- drive opentherm. I admit that I was not that satified beforehand with the fact
-- that one has to go via some outside portal to communicate with the box but lets
-- hope that this will change (I will experiment with the additional usb interface
-- later). Anyway, apart from integrating it into my home automation setup so that I
-- can add control based on someone present in a zone, I wanted to be able to render
-- statistics. So that's why we have a module in ConTeXt for doing that. It's also
-- an example of Lua.
--
-- As with other scripts, it assumes that mtxrun is used so that we have the usual
-- libraries present.
--
-- The code is not that complex but figuring out the right request takes bit of
-- searching the web. There is an api specification at:
--
-- https://developer.honeywell.com/api-methods?field_smart_method_tags_tid=All
--
-- Details like the application id can be found in several places. There are
-- snippets of (often partial or old) code on discussion platforms so in the one can
-- get there.

-- todo: load everything and keep it in mem and only save it when there are changes
-- todo: use a temp files per month
-- todo: %path% in filenames

require("util-jsn")

local json = utilities.json
local formatters = string.formatters
local floor, div = math.floor, math.div
local resultof, ostime, osdate, ossleep = os.resultof, os.time, os.date, os.sleep
local jsontolua, jsontostring = json.tolua, json.tostring
local savetable, loadtable = table.save, table.load
local setmetatableindex = table.setmetatableindex
local replacer = utilities.templates.replacer

local applicationid = "b013aa26-9724-4dbd-8897-048b9aada249"
----- applicationid = "91db1612-73fd-4500-91b2-e63b069b185c"

local report = logs.reporter("evohome")

local defaultpresets = {
    interval    = 30 * 60,
    credentials = {
      -- username    = "unset",
      -- password    = "unset",
      -- accesstoken = "unset",
      -- userid      = "unset",
    },
 -- everything = "evohome-everything",
 -- history = "evohome-history",
}

local function validpresets(presets)
    if type(presets == "table") and presets.credentials then
        setmetatableindex(presets,defaultpresets)
        setmetatableindex(presets.credentials,defaultpresets.credentials)
        return presets
    else
        report("invalid presets")
    end
end

local function loadedtable(filename)
    for i=1,10 do
        local t = loadtable(filename)
        if t then
            return t
        else
            ossleep(1/4)
        end
    end
    return { }
end

local function loadpresets(filename)
    return loadtable(filename)
end

local function loadhistory(filename)
    if type(filename) == "table" then
        filename = filename.history
    end
    return loadedtable(filename)
end

local function loadeverything(filename)
    if type(filename) == "table" then
        filename = filename.everything
    end
    return loadedtable(filename)
end

local function result(t,fmt,a,b,c)
    if t then
        report(fmt,a or "done",b or "done",c or "done","done")
        return t
    else
        report(fmt,a or "failed",b or "failed",c or "failed","failed")
    end
end

local f = replacer (
    [[curl ]] ..
    [[--silent --insecure ]] ..
    [[-X POST ]] ..
    [[-H "Authorization: Basic YjAxM2FhMjYtOTcyNC00ZGJkLTg4OTctMDQ4YjlhYWRhMjQ5OnRlc3Q=" ]] ..
    [[-H "Accept: application/json, application/xml, text/json, text/x-json, text/javascript, text/xml" ]] ..
    [[-d "Content-Type=application/x-www-form-urlencoded; charset=utf-8" ]] ..
    [[-d "Host=rs.alarmnet.com/" ]] ..
    [[-d "Cache-Control=no-store no-cache" ]] ..
    [[-d "Pragma=no-cache" ]] ..
    [[-d "grant_type=password" ]] ..
    [[-d "scope=EMEA-V1-Basic EMEA-V1-Anonymous EMEA-V1-Get-Current-User-Account" ]] ..
    [[-d "Username=%username%" ]] ..
    [[-d "Password=%password%" ]] ..
    [[-d "Connection=Keep-Alive" ]] ..
    [["https://tccna.honeywell.com/Auth/OAuth/Token"]]
)

local function getaccesstoken(presets)
    if validpresets(presets) then
        local c = presets.credentials
        local s = c and f {
            username      = c.username,
            password      = c.password,
            applicationid = applicationid,
        }
        local r = s and resultof(s)
        local t = r and jsontolua(r)
        return result(t,"getting access token: %s")
    end
    return result(false,"getting access token: %s")
end

local f = replacer (
    [[curl ]] ..
    [[--silent --insecure ]] ..
    [[-H "Authorization: bearer %accesstoken%" ]] ..
    [[-H "Accept: application/json, application/xml, text/json, text/x-json, text/javascript, text/xml" ]] ..
    [[-H "applicationId: %applicationid%" ]] ..
    [["https://tccna.honeywell.com/WebAPI/emea/api/v1/userAccount"]]
)

local function getuserinfo(presets)
    if validpresets(presets) then
        local c = presets.credentials
        local s = c and f {
            accesstoken   = c.accesstoken,
            applicationid = c.applicationid,
        }
        local r = s and resultof(s)
        local t = r and jsontolua(r)
        return result(t,"getting user info: %s")
    end
    return result(false,"getting user info: %s")
end

local f = replacer (
    [[curl ]] ..
    [[--silent --insecure ]] ..
    [[-H "Authorization: bearer %accesstoken%" ]] ..
    [[-H "Accept: application/json, application/xml, text/json, text/x-json, text/javascript, text/xml" ]] ..
    [[-H "applicationId: %applicationid%" ]] ..
    [["https://tccna.honeywell.com/WebAPI/emea/api/v1/location/installationInfo?userId=%userid%&includeTemperatureControlSystems=True"]]
)

local function getlocationinfo(presets)
    if validpresets(presets) then
        local c = presets.credentials
        local s = c and f {
            accesstoken   = c.accesstoken,
            applicationid = applicationid,
            userid        = c.userid,
        }
        local r = s and resultof(s)
        local t = r and jsontolua(r)
        return result(t,"getting location info: %s")
    end
    return result(false,"getting location info: %s")
end

local f = replacer (
    [[curl ]] ..
    [[--silent --insecure ]] ..
    [[-H "Authorization: bearer %accesstoken%" ]] ..
    [[-H "Accept: application/json, application/xml, text/json, text/x-json, text/javascript, text/xml" ]] ..
    [[-H "applicationId: %applicationid%" ]] ..
    [["https://tccna.honeywell.com/WebAPI/emea/api/v1/temperatureZone/%zoneid%/schedule"]]
)

local function getschedule(presets,zoneid,zonename)
    if zoneid and validpresets(presets) then
        local c = presets.credentials
        local s = c and f {
            accesstoken   = c.accesstoken,
            applicationid = applicationid,
            zoneid        = zoneid,
        }
        local r = s and resultof(s)
        local t = r and jsontolua(r)
        return result(t,"getting schedule for zone %s: %s",zonename or "?")
    end
    return result(false,"getting schedule for zone %s: %s",zonename or "?")
end

local f = replacer (
    [[curl ]] ..
    [[--silent --insecure ]] ..
    [[-H "Authorization: bearer %accesstoken%" ]] ..
    [[-H "Accept: application/json, application/xml, text/json, text/x-json, text/javascript, text/xml" ]] ..
    [[-H "applicationId: %applicationid%" ]] ..
    [["https://tccna.honeywell.com/WebAPI/emea/api/v1/location/%locationid%/status?includeTemperatureControlSystems=True" ]]
)

local function getstatus(presets,locationid,locationname)
    if locationid and validpresets(presets) then
        local c = presets.credentials
        local s = c and f {
            accesstoken   = c.accesstoken,
            applicationid = applicationid,
            locationid    = locationid,
        }
        local r = s and resultof(s)
        local t = r and jsontolua(r)
        return result(t and t.gateways and t,"getting status for location %s: %s",locationname or "?")
    end
    return result(false,"getting status for location %s: %s",locationname or "?")
end

local function validated(presets)
    if validpresets(presets) then
        local data = getaccesstoken(presets)
        if data then
            presets.credentials.accesstoken = data.access_token
            local data = getuserinfo(presets)
            if data then
                presets.credentials.userid = data.userId
                return true
            end
        end
    end
end

local function geteverything(presets,filename)
    if validated(presets) then
        local data = getlocationinfo(presets)
        if data then
            for i=1,#data do
                local gateways     = data[i].gateways
                local locationinfo = data[i].locationInfo
                local locationid   = locationinfo and locationinfo.locationId
                if gateways and locationid then
                    local status = getstatus(presets,locationid,locationinfo.name)
                    if status then
                        for i=1,#gateways do
                            local g = status.gateways[i]
                            local gateway = gateways[i]
                            local systems = gateway.temperatureControlSystems
                            if systems then
                                local s = g.temperatureControlSystems
                                for i=1,#systems do
                                    local zones = systems[i].zones
                                    if zones then
                                        local z = s[i].zones
                                        for i=1,#zones do
                                            local zone = zones[i]
                                            if zone.zoneType == "ZoneTemperatureControl" then
                                                local z = z[i]
                                                zone.schedule = getschedule(presets,zone.zoneId,zone.name)
                                                if z.name == zone.name then
                                                    zone.heatSetpointStatus = z.heatSetpointStatus
                                                    zone.temperatureStatus  = z.temperatureStatus
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if not filename then
                filename = presets.everything
            end
            if filename then
                savetable(filename,data)
            end
            return result(data,"getting everything: %s")
        end
    end
    return result(false,"getting everything: %s")
end

local function gettemperatures(presets,filename)
    if validated(presets) then
        local data = loadeverything(filename or presets)
        if data then
            local updated = false
            for i=1,#data do
                local gateways     = data[i].gateways
                local locationinfo = data[i].locationInfo
                local locationid   = locationinfo.locationId
                if gateways then
                    local status = getstatus(presets,locationid,locationinfo.name)
                    if status then
                        for i=1,#gateways do
                            local g = status.gateways[i]
                            local gateway = gateways[i]
                            local systems = gateway.temperatureControlSystems
                            if systems then
                                local s = g.temperatureControlSystems
                                for i=1,#systems do
                                    local zones = systems[i].zones
                                    if zones then
                                        local z = s[i].zones
                                        for i=1,#zones do
                                            local zone = zones[i]
                                            if zone.zoneType == "ZoneTemperatureControl" then
                                                local z = z[i]
                                                if z.name == zone.name then
                                                    zone.temperatureStatus = z.temperatureStatus
                                                    updated = true
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if updated and filename then
                data.time = ostime()
                savetable(filename,data)
            end
            return result(data,"getting temperatures: %s")
        end
    end
    return result(false,"getting temperatures: %s")
end

local function setmoment(target,time,data)
    if not time then
        time = ostime()
    end
    local t = osdate("*t",time )
    local c_year, c_month, c_day, c_hour, c_minute = t.year, t.month, t.day, t.hour, t.min
    --
    local years   = target.years    if not years   then years   = { } target.years    = years   end
    local d_year  = years[c_year]   if not d_year  then d_year  = { } years[c_year]   = d_year  end
    local months  = d_year.months   if not months  then months  = { } d_year.months   = months  end
    local d_month = months[c_month] if not d_month then d_month = { } months[c_month] = d_month end
    local days    = d_month.days    if not days    then days    = { } d_month.days    = days    end
    local d_day   = days[c_day]     if not d_day   then d_day   = { } days[c_day]     = d_day   end
    local hours   = d_day.hours     if not hours   then hours   = { } d_day.hours     = hours   end
    local d_hour  = hours[c_hour]   if not d_hour  then d_hour  = { } hours[c_hour]   = d_hour  end
    --
    c_minute = div(c_minute,15) + 1
    --
    local d_last = d_hour[c_minute]
    if d_last then
        for k, v in next, data do
            local d = d_last[k]
            if d then
                data[k] = (d + v) / 2
            end
        end
    end
    d_hour[c_minute] = data
    --
    target.lasttime = {
        year   = c_year,
        month  = c_month,
        day    = c_day,
        hour   = c_hour,
        minute = c_minute,
    }
end

local function loadtemperatures(filename)
    local status = loadeverything(filename)
    if status then
        setmetatable(status,mt)
        local zones = status[1].gateways[1].temperatureControlSystems[1].zones
        if zones then
            local summary = { time = status.time }
            for i=1,#zones do
                local zone = zones[i]
                if zone.modelType == "HeatingZone" then
                    local temperatureStatus        = zone.temperatureStatus
                    local heatSetpointCapabilities = zone.heatSetpointCapabilities
                    local heatSetpointStatus       = zone.heatSetpointStatus
                    summary[#summary+1] = {
                        name    = zone.name,
                        current = temperatureStatus        and temperatureStatus       .temperature       or 0,
                        min     = heatSetpointCapabilities and heatSetpointCapabilities.minHeatSetpoint   or 0,
                        max     = heatSetpointCapabilities and heatSetpointCapabilities.maxHeatSetpoint   or 0,
                        target  = heatSetpointStatus       and heatSetpointStatus      .targetTemperature or 0,
                    }
                end
            end
            return result(summary,"loading temperatures: %s")
        end
    end
    return result(false,"loading temperatures: %s")
end

local function updatetemperatures(presets,filename,historyname)
    if validpresets(presets) then
        if not filename then
            filename = presets.everything
        end
        if not historyname then
            historyname = presets.history
        end
        gettemperatures(presets,filename)
        local t = loadtemperatures(filename)
        if t then
            local data = { }
            for i=1,#t do
                local ti = t[i]
                data[ti.name] = ti.current
            end
            local history = loadhistory(historyname) or { }
            setmoment(history,ostime(),data)
            savetable(historyname,history)
            return result(t,"updating temperatures: %s")
        end
    end
    return result(false,"updating temperatures: %s")
end

local mt = { __index = { [1] = { gateways = { [1] = { temperatureControlSystems = { [1] = { } } } } } } }

local function findzone(status,name)
    if status then
        setmetatable(status,mt)
        local zones = status[1].gateways[1].temperatureControlSystems[1].zones
        if zones then
            for i=1,#zones do
                local zone = zones[i]
                if zone.modelType == "HeatingZone" and zone.name == name then
                    return zone
                end
            end
        end
    end
end

local function getzonestate(filename,name)
    local status = loadeverything(filename)
    local zone   = findzone(status,name)
    if zone then
        local t = {
            name     = zone.name,
            current  = zone.temperatureStatus.temperature or 0,
            min      = zone.heatSetpointCapabilities.minHeatSetpoint,
            max      = zone.heatSetpointCapabilities.maxHeatSetpoint,
            target   = zone.heatSetpointStatus.targetTemperature,
            mode     = zone.heatSetpointStatus.setpointMode,
            schedule = zone.schedule,
        }
        return result(t,"getting state of zone %s: %s",name)
    end
    return result(false,"getting state of zone %s: %s",name)
end

local f = replacer (
    [[curl ]] ..
    [[-X PUT ]] ..
    [[--silent --insecure ]] ..
    [[-H "Authorization: bearer %accesstoken%" ]] ..
    [[-H "Accept: application/json, application/xml, text/json, text/x-json, text/javascript, text/xml" ]] ..
    [[-H "applicationId: %applicationid%" ]] ..
    [[-H "Content-Type: application/json" ]] ..
    [[-d "%[settings]%" ]] ..
    [["https://tccna.honeywell.com/WebAPI/emea/api/v1/temperatureZone/%zoneid%/heatSetpoint"]]
)

local function setzonestate(presets,name,temperature)
    if validated(presets) then
        local data = loadeverything(presets)
        local zone = findzone(data,name)
        if zone then
            local m = type(temperature) == "number" and temperature > 0 and
                {
                    HeatSetpointValue = temperature,
                    SetpointMode      = "TemporaryOverride",
                    TimeUntil         = osdate("%Y-%m-%dT%H:%M:%SZ",os.time() + 60*60),
                }
            or
                {
                    HeatSetpointValue = 0,
                    SetpointMode      = "FollowSchedule",
                }

            local s = f {
                accesstoken   = presets.credentials.accesstoken,
                applicationid = applicationid,
                zoneid        = zone.zoneId,
                settings      = jsontostring(m),
            }
            local r = s and resultof(s)
            local t = r and jsontolua(r)
            return result(t,"setting state of zone %s: %s",name)
        end
    end
    return result(false,"setting state of zone %s: %s",name)
end

local evohome = {
    helpers = {
        getaccesstoken  = getaccesstoken,
        getuserinfo     = getuserinfo,
        getlocationinfo = getlocationinfo,
        getschedule     = getschedule,
    },
    geteverything      = geteverything,
    gettemperatures    = gettemperatures,
    getzonestate       = getzonestate,
    setzonestate       = setzonestate,
    loadtemperatures   = loadtemperatures,
    updatetemperatures = updatetemperatures,
    loadpresets        = loadpresets,
    loadhistory        = loadhistory,
    loadeverything     = loadeverything,
}

if utilities then
    utilities.evohome = evohome
end

-- local presets = evohome.loadpresets("c:/data/develop/domotica/code/evohome-presets.lua")
-- evohome.setzonestate(presets,"Voorkamer",22)
-- evohome.setzonestate(presets,"Voorkamer")

return evohome

