if not modules then modules = { } end modules ['mlib-ctx'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- todo

local format, concat = string.format, table.concat
local settings_to_hash = utilities.parsers.settings_to_hash

local report_metapost = logs.reporter("metapost")

local starttiming, stoptiming = statistics.starttiming, statistics.stoptiming

local mplib = mplib

metapost       = metapost or {}
local metapost = metapost

local v_no = interfaces.variables.no

metapost.defaultformat   = "metafun"
metapost.defaultinstance = "metafun"
metapost.defaultmethod   = "default"

local function setmpsformat(specification)
    local instance = specification.instance
    local format   = specification.format
    local method   = specification.method
    if not instance or instance == "" then
        instance = metapost.defaultinstance
        specification.instance = instance
    end
    if not format or format == "" then
        format = metapost.defaultformat
        specification.format = format
    end
    if not method or method == "" then
        method = metapost.defaultmethod
        specification.method = method
    end
    specification.mpx = metapost.format(instance,format,method)
    return specification
end

local extensiondata    = metapost.extensiondata or storage.allocate { }
metapost.extensiondata = extensiondata

storage.register("metapost/extensiondata",extensiondata,"metapost.extensiondata")

function metapost.setextensions(instances,data)
    if data and data ~= "" then
        extensiondata[#extensiondata+1] = {
            usedinall  = not instances or instances == "",
            instances  = settings_to_hash(instances or ""),
            extensions = data,
        }
    end
end

function metapost.getextensions(instance,state)
    if state and state == v_no then
        return ""
    else
        local t = { }
        for i=1,#extensiondata do
            local e = extensiondata[i]
            local status = e.instances[instance]
            if (status ~= true) and (e.usedinall or status) then
                t[#t+1] = e.extensions
                e.instances[instance] = true
            end
        end
        return concat(t," ")
    end
end

function commands.getmpextensions(instance,state)
    context(metapost.getextensions(instance,state))
end

function metapost.graphic(specification)
    setmpsformat(specification)
    metapost.graphic_base_pass(specification)
end

function metapost.getclippath(specification) -- why not a special instance for this
    setmpsformat(specification)
    local mpx = specification.mpx
    local data = specification.data or ""
    if mpx and data ~= "" then
        starttiming(metapost)
        starttiming(metapost.exectime)
        local result = mpx:execute ( format ( "%s;%s;beginfig(1);%s;%s;endfig;",
            specification.extensions or "",
            specification.inclusions or "",
            specification.initializations or "",
            data
        ) )
        stoptiming(metapost.exectime)
        if result.status > 0 then
            report_metapost("%s: %s", result.status, result.error or result.term or result.log)
            result = nil
        else
            result = metapost.filterclippath(result)
        end
        stoptiming(metapost)
        return result
    end
end

function metapost.filterclippath(result)
    if result then
        local figures = result.fig
        if figures and #figures > 0 then
            local figure = figures[1]
            local objects = figure:objects()
            if objects then
                local lastclippath
                for o=1,#objects do
                    local object = objects[o]
                    if object.type == "start_clip" then
                        lastclippath = object.path
                    end
                end
                return lastclippath
            end
        end
    end
end

function metapost.theclippath(...)
    local result = metapost.getclippath(...)
    if result then -- we could just print the table
        result = concat(metapost.flushnormalpath(result),"\n")
        context(result)
    end
end

statistics.register("metapost processing time", function()
    local n =  metapost.n
    if n and n > 0 then
        local nofconverted = metapost.makempy.nofconverted
        local elapsedtime = statistics.elapsedtime
        local elapsed = statistics.elapsed
        local instances, memory = metapost.getstatistics(true)
        local str = format("%s seconds, loading: %s, execution: %s, n: %s, average: %s, instances: %i, memory: %0.3f M",
            elapsedtime(metapost), elapsedtime(mplib), elapsedtime(metapost.exectime), n,
            elapsedtime((elapsed(metapost) + elapsed(mplib) + elapsed(metapost.exectime)) / n),
            instances, memory/(1024*1024))
        if nofconverted > 0 then
            return format("%s, external: %s (%s calls)",
                str, elapsedtime(metapost.makempy), nofconverted)
        else
            return str
        end
    else
        return nil
    end
end)

-- only used in graphictexts

metapost.tex = metapost.tex or { }

local environments = { }

function metapost.tex.set(str)
    environments[#environments+1] = str
end

function metapost.tex.reset()
    environments = { }
end

function metapost.tex.get()
    return concat(environments,"\n")
end
