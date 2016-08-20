if not modules then modules = { } end modules ['mlib-ctx'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- for the moment we have the scanners here but they migh tbe moved to
-- the other modules

local type, tostring = type, tostring
local format, concat = string.format, table.concat
local settings_to_hash = utilities.parsers.settings_to_hash

local report_metapost = logs.reporter("metapost")

local starttiming        = statistics.starttiming
local stoptiming         = statistics.stoptiming

local mplib              = mplib

metapost                 = metapost or {}
local metapost           = metapost

local context            = context

local setters            = tokens.setters
local setmacro           = setters.macro
local implement          = interfaces.implement

local v_no               = interfaces.variables.no

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

-- function commands.getmpextensions(instance,state)
--     context(metapost.getextensions(instance,state))
-- end

implement {
    name      = "setmpextensions",
    actions   = metapost.setextensions,
    arguments = { "string", "string" }
}

implement {
    name      = "getmpextensions",
    actions   = { metapost.getextensions, context } ,
    arguments = "string"
}

local report_metapost = logs.reporter ("metapost")
local status_metapost = logs.messenger("metapost")

local patterns = {
    "meta-imp-%s.mkiv",
    "meta-imp-%s.tex",
    -- obsolete:
    "meta-%s.mkiv",
    "meta-%s.tex"
}

local function action(name,foundname)
    status_metapost("library %a is loaded",name)
    context.startreadingfile()
    context.input(foundname)
    context.stopreadingfile()
end

local function failure(name)
    report_metapost("library %a is unknown or invalid",name)
end

implement {
    name      = "useMPlibrary",
    arguments = "string",
    actions   = function(name)
        resolvers.uselibrary {
            name     = name,
            patterns = patterns,
            action   = action,
            failure  = failure,
            onlyonce = true,
        }
    end
}

-- metapost.variables  = { } -- to be stacked

implement {
    name      = "mprunvar",
    arguments = "string",
    actions   = function(name)
        local value = metapost.variables[name]
        if value ~= nil then
            local tvalue = type(value)
            if tvalue == "table" then
                context(concat(value," "))
            elseif tvalue == "number" or tvalue == "boolean" then
                context(tostring(value))
            elseif tvalue == "string" then
                context(value)
            end
        end
    end
}

implement {
    name      = "mpruntab",
    arguments = { "string", "integer" },
    actions   = function(name,n)
        local value = metapost.variables[name]
        if value ~= nil then
            local tvalue = type(value)
            if tvalue == "table" then
                context(value[n])
            elseif tvalue == "number" or tvalue == "boolean" then
                context(tostring(value))
            elseif tvalue == "string" then
                context(value)
            end
        end
    end
}

implement {
    name      = "mprunset",
    arguments = { "string", "string" },
    actions   = function(name,connector)
        local value = metapost.variables[name]
        if value ~= nil then
            local tvalue = type(value)
            if tvalue == "table" then
                context(concat(value,connector))
            elseif tvalue == "number" or tvalue == "boolean" then
                context(tostring(value))
            elseif tvalue == "string" then
                context(value)
            end
        end
    end
}

-- we need to move more from pps to here as pps is the plugin .. the order is a mess
-- or just move the scanners to pps

function metapost.graphic(specification)
    metapost.graphic_base_pass(setmpsformat(specification))
end

implement {
    name      = "mpgraphic",
    actions   = metapost.graphic,
    arguments = {
        {
            { "instance" },
            { "format" },
            { "data" },
            { "initializations" },
            { "extensions" },
            { "inclusions" },
            { "definitions" },
            { "figure" },
            { "method" },
        }
    }
}

implement {
    name      = "mpsetoutercolor",
    actions   = function(...) metapost.setoutercolor(...) end, -- not yet implemented
    arguments = { "integer", "integer", "integer", "integer" }
}

implement {
    name      = "mpflushreset",
    actions   = function() metapost.flushreset() end -- not yet implemented
}

implement {
    name      = "mpflushliteral",
    actions   = function(str) metapost.flushliteral(str) end, -- not yet implemented
    arguments = "string",
}

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
        return concat(metapost.flushnormalpath(result)," ")
    else
        return ""
    end
end

implement {
    name      = "mpsetclippath",
    actions   = function(specification)
        setmacro("MPclippath",metapost.theclippath(specification),"global")
    end,
    arguments = {
        {
            { "instance" },
            { "format" },
            { "data" },
            { "initializations" },
            { "useextensions" },
            { "inclusions" },
            { "method" },
        },
    }
}

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
local mptex  = metapost.tex

local environments = { }

function mptex.set(str)
    environments[#environments+1] = str
end

function mptex.setfrombuffer(name)
    environments[#environments+1] = buffers.getcontent(name)
end

function mptex.get()
    return concat(environments,"\n")
end

function mptex.reset()
    environments = { }
end

implement {
    name      = "mppushvariables",
    actions   = metapost.pushvariables,
}

implement {
    name      = "mppopvariables",
    actions   = metapost.popvariables,
}

implement {
    name      = "mptexset",
    arguments = "string",
    actions   = mptex.set
}

implement {
    name      = "mptexsetfrombuffer",
    arguments = "string",
    actions   = mptex.setfrombuffer
}

implement {
    name      = "mptexget",
    actions   = { mptex.get, context }
}

implement {
    name      = "mptexreset",
    actions   = mptex.reset
}
