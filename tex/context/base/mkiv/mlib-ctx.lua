if not modules then modules = { } end modules ['mlib-ctx'] = {
    version   = 1.001,
    comment   = "companion to mlib-ctx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local type, tostring = type, tostring
local format, concat = string.format, table.concat
local settings_to_hash = utilities.parsers.settings_to_hash
local formatters = string.formatters

local report_metapost = logs.reporter ("metapost")
local status_metapost = logs.messenger("metapost")

local starttiming     = statistics.starttiming
local stoptiming      = statistics.stoptiming

local trace_graphic   = false

trackers.register("metapost.graphics",
    function(v) trace_graphic = v end
);

local mplib            = mplib

metapost               = metapost or { }
local metapost         = metapost
local context          = context

local setters          = tokens.setters
local setmacro         = setters.macro
local implement        = interfaces.implement

local v_no             = interfaces.variables.no

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

implement {
    name      = "setmpextensions",
    actions   = metapost.setextensions,
    arguments = "2 strings",
}

implement {
    name      = "getmpextensions",
    actions   = { metapost.getextensions, context } ,
    arguments = "string"
}

local patterns = {
    CONTEXTLMTXMODE > 0 and "meta-imp-%s.mkxl" or "",
    "meta-imp-%s.mkiv",
    "meta-imp-%s.tex",
    -- obsolete:
    "meta-%s.mkiv",
    "meta-%s.tex"
}

local function action(name,foundname)
    commands.loadlibrary(name,foundname,false)
    status_metapost("library %a is loaded",name)
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

-- metapost.variables = { } -- to be stacked

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
    arguments = "2 strings",
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
    metapost.pushformat(specification)
    metapost.graphic_base_pass(specification)
    metapost.popformat()
end

function metapost.startgraphic(t)
    if not t then
        t = { }
    end
    if not t.instance then
        t.instance = metapost.defaultinstance
    end
    if not t.format then
        t.format = metapost.defaultformat
    end
    if not t.method then
        t.method = metapost.defaultmethod
    end
    t.data = { }
    return t
end

function metapost.stopgraphic(t)
    if t then
        t.data = concat(t.data or { },"\n")
        if trace_graphic then
            report_metapost("\n"..t.data.."\n")
        end
        metapost.graphic(t)
    end
end

function metapost.tographic(t,f,s,...)
    local d = t.data
    d[#d+1] = s and formatters[f](s,...) or f
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
            { "namespace" },
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

-- this has to become a codeinjection

function metapost.getclippath(specification) -- why not a special instance for this
    local mpx  = metapost.pushformat(specification)
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
        metapost.pushformat()
        return result
    else
        metapost.pushformat()
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
        local p = specification.data and metapost.theclippath(specification)
        if not p or p == "" then
            local b = number.dimenfactors.bp
            local w = b * (specification.width or 0)
            local h = b * (specification.height or 0)
            p = formatters["0 0 m %.6N 0 l %.6N %.6N l 0 %.6N l"](w,w,h,h)
        end
        setmacro("MPclippath",p,"global")
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
            { "namespace" },
            { "width", "dimension" },
            { "height", "dimension" },
        },
    }
}

statistics.register("metapost", function()
    local n = metapost.nofruns
    if n and n > 0 then
        local elapsedtime = statistics.elapsedtime
        local elapsed     = statistics.elapsed
        local instances,
              memory      = metapost.getstatistics(true)
        return format("%s seconds, loading: %s, execution: %s, n: %s, average: %s, instances: %i, luacalls: %i, memory: %0.3f M",
            elapsedtime(metapost), elapsedtime(mplib), elapsedtime(metapost.exectime), n,
            elapsedtime((elapsed(metapost) + elapsed(mplib) + elapsed(metapost.exectime)) / n),
            instances, metapost.nofscriptruns(),memory/(1024*1024))
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
