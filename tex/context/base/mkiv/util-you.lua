if not modules then modules = { } end modules ['util-you'] = {
    version   = 1.002,
    comment   = "library for fetching data from youless kwh meter polling device",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE",
    license   = "see context related readme files"
}

-- See mtx-youless.lua and s-youless.mkiv for examples of usage.
--
-- todo: already calculate min, max and average per hour and discard
--       older data, or maybe a condense option
--
-- maybe just a special parser but who cares about speed here
--
-- curl -c pw.txt http://192.168.2.50/L?w=pwd
-- curl -b pw.txt http://192.168.2.50/V?...
--
-- the socket library barks on an (indeed) invalid header ... unfortunately we cannot
-- pass a password with each request ... although the youless is a rather nice gadget,
-- the weak part is in the http polling

require("util-jsn")

-- the library variant:

utilities         = utilities or { }
local youless     = { }
utilities.youless = youless

local lpegmatch  = lpeg.match
local formatters = string.formatters

-- dofile("http.lua")

local http = socket.http

local f_normal   = formatters["http://%s/V?%s=%i&f=j"]
local f_password = formatters["http://%s/L?w=%s"]

local function fetch(url,password,what,i)
    local url     = f_normal(url,what,i)
    local data, h = http.request(url)
    local result  = data and utilities.json.tolua(data)
    return result
end

-- "123"  "  1,234"

local tovalue = lpeg.Cs((lpeg.R("09") + lpeg.P(1)/"")^1) / tonumber

-- "2013-11-12T06:40:00"

local totime = (lpeg.C(4) / tonumber) * lpeg.P("-")
             * (lpeg.C(2) / tonumber) * lpeg.P("-")
             * (lpeg.C(2) / tonumber) * lpeg.P("T")
             * (lpeg.C(2) / tonumber) * lpeg.P(":")
             * (lpeg.C(2) / tonumber) * lpeg.P(":")
             * (lpeg.C(2) / tonumber)

local function get(url,password,what,i,data,average,variant)
    if not data then
        data = { }
    end
    while true do
        local d = fetch(url,password,what,i)
        if d and next(d) then
            local c_year, c_month, c_day, c_hour, c_minute, c_seconds = lpegmatch(totime,d.tm)
            if c_year and c_seconds then
                local delta = tonumber(d.dt)
                local tnum = os.time { year = c_year, month = c_month, day = c_day, hour = c_hour, minute = c_minute }
                local v = d.val
                for i=1,#v do
                    local newvalue = lpegmatch(tovalue,v[i])
                    if newvalue then
                        local t = tnum + (i-1)*delta
                        local current = os.date("%Y-%m-%dT%H:%M:%S",t)
                        local c_year, c_month, c_day, c_hour, c_minute, c_seconds = lpegmatch(totime,current)
                        if c_year and c_seconds then
                            local years   = data.years      if not years   then years   = { } data.years      = years   end
                            local d_year  = years[c_year]   if not d_year  then d_year  = { } years[c_year]   = d_year  end
                            local months  = d_year.months   if not months  then months  = { } d_year.months   = months  end
                            local d_month = months[c_month] if not d_month then d_month = { } months[c_month] = d_month end
                            local days    = d_month.days    if not days    then days    = { } d_month.days    = days    end
                            local d_day   = days[c_day]     if not d_day   then d_day   = { } days[c_day]     = d_day   end
                            if average then
                                d_day.average  = newvalue
                            else
                                local hours   = d_day.hours     if not hours   then hours   = { } d_day.hours     = hours   end
                                local d_hour  = hours[c_hour]   if not d_hour  then d_hour  = { } hours[c_hour]   = d_hour  end
                                d_hour[c_minute] = newvalue
                            end
                        end
                    end
                end
            end
        else
            return data
        end
        i = i + 1
    end
    return data
end

-- day of month (kwh)
--     url = http://192.168.1.14/V?m=2
--     m = the number of month (jan = 1, feb = 2, ..., dec = 12)

-- hour of day (watt)
--     url = http://192.168.1.14/V?d=1
--     d = the number of days ago (today = 0, yesterday = 1, etc.)

-- 10 minutes (watt)
--     url = http://192.168.1.14/V?w=1
--     w = 1 for the interval now till 8 hours ago.
--     w = 2 for the interval 8 till 16 hours ago.
--     w = 3 for the interval 16 till 24 hours ago.

-- 1 minute (watt)
--     url = http://192.168.1.14/V?h=1
--     h = 1 for the interval now till 30 minutes ago.
--     h = 2 for the interval 30 till 60 minutes ago

function youless.collect(specification)
    if type(specification) ~= "table" then
        return
    end
    local host     = specification.host     or ""
    local data     = specification.data     or { }
    local filename = specification.filename or ""
    local variant  = specification.variant  or "kwh"
    local detail   = specification.detail   or false
    local nobackup = specification.nobackup or false
    local password = specification.password or ""
    if host == "" then
        return
    end
    if filename == "" then
        return
    else
        data = table.load(filename) or data
    end
    if variant == "kwh" then
        get(host,password,"m",1,data,true)
    elseif variant == "watt" then
        get(host,password,"d",0,data,true)
        get(host,password,"w",1,data)
        if detail then
            get(host,password,"h",1,data) -- todo: get this for calculating the precise max
        end
    else
        return
    end
    local path = file.dirname(filename)
    local base = file.basename(filename)
    data.variant = variant
    data.host    = host
    data.updated = os.now()
    if nobackup then
        -- saved but with checking
        local tempname = file.join(path,"youless.tmp")
        table.save(tempname,data)
        local check = table.load(tempname)
        if type(check) == "table" then
            local keepname = file.replacesuffix(filename,"old")
            os.remove(keepname)
            if not lfs.isfile(keepname) then
                os.rename(filename,keepname)
                os.rename(tempname,filename)
            end
        end
    else
        local keepname = file.join(path,formatters["%s-%s"](os.date("%Y-%m-%d-%H-%M-%S",os.time()),base))
        os.rename(filename,keepname)
        if not lfs.isfile(filename) then
            table.save(filename,data)
        end
    end
    return data
end

-- local data = youless.collect {
--     host     = "192.168.2.50",
--     variant  = "watt",
--     filename = "youless-watt.lua"
-- }

-- inspect(data)

-- local data = youless.collect {
--     host    = "192.168.2.50",
--     variant = "kwh",
--     filename = "youless-kwh.lua"
-- }

-- inspect(data)

function youless.analyze(data)
    if data and data.variant == "watt" and data.years then
        for y, year in next, data.years do
            local a_year, n_year, m_year = 0, 0, 0
            if year.months then
                for m, month in next, year.months do
                    local a_month, n_month = 0, 0
                    if month.days then
                        for d, day in next, month.days do
                            local a_day, n_day = 0, 0
                            if day.hours then
                                for h, hour in next, day.hours do
                                    local a_hour, n_hour, m_hour = 0, 0, 0
                                    for k, v in next, hour do
                                        if type(k) == "number" then
                                            a_hour = a_hour + v
                                            n_hour = n_hour + 1
                                            if v > m_hour then
                                                m_hour = v
                                            end
                                        end
                                    end
                                    n_day = n_day + n_hour
                                    a_day = a_day + a_hour
                                    hour.maxwatt = m_hour
                                    hour.watt = a_hour / n_hour
                                    if m_hour > m_year then
                                        m_year = m_hour
                                    end
                                end
                            end
                            if n_day > 0 then
                                a_month = a_month + a_day
                                n_month = n_month + n_day
                                day.watt = a_day / n_day
                            else
                                day.watt = 0
                            end
                        end
                    end
                    if n_month > 0 then
                        a_year = a_year + a_month
                        n_year = n_year + n_month
                        month.watt = a_month / n_month
                    else
                        month.watt = 0
                    end
                end
            end
            if n_year > 0 then
                year.watt    = a_year / n_year
                year.maxwatt = m_year
            else
                year.watt    = 0
                year.maxwatt = 0
            end
        end
    end
end
