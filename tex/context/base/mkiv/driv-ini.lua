if not modules then modules = { } end modules ['driv-ini'] = {
    version   = 1.001,
    comment   = "companion to driv-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type
local addsuffix = file.addsuffix

local setmetatableindex = table.setmetatableindex
local formatters        = string.formatters

local starttiming       = statistics.starttiming
local stoptiming        = statistics.stoptiming

local report            = logs.reporter("drivers")

local instances         = { }
local helpers           = { }
local converters        = { }
local prepared          = { }
local wrappedup         = { }
local cleanedup         = { }
local currentdriver     = "default"
local currentinstance   = nil

local shipout           = tex.shipout
local texgetbox         = tex.getbox
local texgetcount       = tex.getcount

function converters.engine(driver,boxnumber,mode,number,specification)
    return shipout(boxnumber)
end

local prepare           = nil
local convert           = nil
local wrapup            = nil
local cleanup           = nil
local outputfilename    = nil

drivers = drivers or {
    instances   = instances,
    helpers     = helpers,
    converters  = converters,
    lmtxversion = 0.10,
    report      = report,
}

local dummy = function() end

local defaulthandlers = {
    prepare         = dummy,
    initialize      = dummy,
    finalize        = dummy,
    updatefontstate = dummy,
    wrapup          = dummy,
    cleanup         = dummy,
    convert         = dummy,
    outputfilename  = dummy,
}

function drivers.install(specification)
    local name = specification.name
    if not name then
        report("missing driver name")
        return
    end
    local actions = specification.actions
    if not actions then
        report("no actions for driver %a",name)
        return
    end
    local flushers = specification.flushers
    if not flushers then
        report("no flushers for driver %a",name)
        return
    end
 -- report("driver %a is installed",name)
    setmetatableindex(actions, defaulthandlers)
    setmetatableindex(flushers, function() return dummy end)
    instances[name] = specification
end

function drivers.convert(boxnumber)
    if currentinstance then
        callbacks.functions.start_page_number()
        starttiming(drivers)
        convert(currentinstance,boxnumber,texgetcount("realpageno"))
        stoptiming(drivers)
        callbacks.functions.stop_page_number()
    end
end

function drivers.outputfilename()
    if currentinstance then
        return outputfilename(currentinstance)
    end
end

luatex.wrapup(function()
    if currentinstance and wrapup and not wrappedup[currentdriver] then
        starttiming(drivers)
        wrapup(currentinstance)
        stoptiming(drivers)
        wrappedup[currentdriver] = true
        cleanedup[currentdriver] = true
    end
end)

luatex.cleanup(function()
    if currentinstance and cleanup and not cleanedup[currentdriver] then
        starttiming(drivers)
        cleanup(currentinstance)
        stoptiming(drivers)
        wrappedup[currentdriver] = true
        cleanedup[currentdriver] = true
    end
end)

function drivers.enable(name)
    if name ~= currentdriver then
        if currentinstance then
            starttiming(drivers)
            cleanup(currentinstance)
            stoptiming(drivers)
        end
        currentdriver   = name or "default"
        currentinstance = instances[currentdriver]
        if currentinstance then
            local actions   = currentinstance.actions
            prepare         = actions.prepare
            wrapup          = actions.wrapup
            cleanup         = actions.cleanup
            convert         = actions.convert
            outputfilename  = actions.outputfilename
            --
            if prepare and not prepared[currentdriver] then
                starttiming(drivers)
                prepare(currentinstance)
                stoptiming(drivers)
                prepared[currentdriver] = true
            end
        else
            report("bad driver")
        end
    end
end

statistics.register("driver time",function()
    return statistics.elapsedseconds(drivers)
end)

interfaces.implement {
    name      = "shipoutpage",
    arguments = "integer",
    actions   = drivers.convert,
}

interfaces.implement {
    name      = "enabledriver",
    arguments = "string",
    actions   = drivers.enable,
}

-- The default driver:

do

    local filename = nil

    drivers.install {
        name     = "default",
        actions  = {
            convert        = drivers.converters.engine,
            outputfilename = function(driver)
                if not filename then
                    filename = addsuffix(tex.jobname,"pdf")
                end
                return filename
            end,
        },
        flushers = {
            -- we always need this entry
        },
    }

end

-- No driver:

do

    drivers.install {
        name     = "none",
        actions  = { },
        flushers = { },
    }

end

do

    local function prepare(driver)
        converter = drivers.converters.lmtx
    end

    local function convert(driver,boxnumber,pagenumber)
        converter(driver,texgetbox(boxnumber),"page",pagenumber)
    end

    drivers.install {
        name     = "empty",
        actions  = {
            prepare = prepare,
            convert = convert,
        },
        flushers = { },
    }

end

--

setmetatableindex(instances,function() return instances.default end)

-- for now:

drivers.enable("default")

-- helpers

local s_matrix_0 = "1 0 0 1"
local f_matrix_2 = formatters["%.6N 0 0 %.6N"]
local f_matrix_4 = formatters["%.6N %.6N %.6N %.6N"]

function helpers.tomatrix(rx,sx,sy,ry,tx,ty) -- todo: tx ty
    if type(rx) == "string" then
        return rx
    else
        if not rx then
            rx = 1
        elseif rx == 0 then
            rx = 0.0001
        end
        if not ry then
            ry = 1
        elseif ry == 0 then
            ry = 0.0001
        end
        if not sx then
            sx = 0
        end
        if not sy then
            sy = 0
        end
        if sx == 0 and sy == 0 then
            if rx == 1 and ry == 1 then
                return s_matrix_0
            else
                return f_matrix_2(rx,ry)
            end
        else
            return f_matrix_4(rx,sx,sy,ry)
        end
    end
end
