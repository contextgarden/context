if not modules then modules = { } end modules ['x-flow'] = {
    version   = 1.001,
    comment   = "companion to m-flow.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- when we can resolve mpcolor at the lua end we will use metapost.graphic(....) directly

local tonumber = tonumber

moduledata.steps = moduledata.steps or { }

local context    = context
local variables  = interfaces.variables
local formatters = string.formatters
----- mpcolor    = attributes.colors.mpnamedcolor
local concat     = table.concat

local report     = logs.reporter("stepcharts")
local trace      = false

trackers.register("stepcharts",function(v) trace = v end)

local defaults = {
    chart = {
        dx              = 10*65436,
        dy              = 10*65436,
    },
    cell = {
        alternative     = 1,
        offset          = 2*65436,
        rulethickness   = 65436,
        framecolor      = "blue",
        backgroundcolor = "gray",
    },
    text = {
        alternative     = 1,
        offset          = 2*65436,
        distance        = 4*65436,
        rulethickness   = 65436,
        framecolor      = "red",
        backgroundcolor = "gray",
    },
    line = {
        alternative     = 1,
        rulethickness   = 65436,
        height          = 30*65436,
        distance        = 10*65436,
        offset          = 5*65436,
        color           = "green",
    },
}

-- todo : name (no name then direct)
-- maybe: includes
-- maybe: flush ranges

local charts = { } -- not used but we could support nesting
local chart  = nil
local steps  = { }
local count  = 0

local function step_start_chart(name,alternative)
    name = name or ""
    steps = table.setmetatableindex(function(t,k)
        local v = { -- could be metatable
            cell_top = false,
            cell_bot = false,
            text_top = false,
            text_mid = false,
            text_bot = false,
            start_t  = k,
            start_m  = k,
            start_b  = k,
            cell_ali = false,
        }
        t[k] = v
        return v
    end)
    count = 0
    chart = {
        steps       = steps,
        count       = count,
        alternative = alternative,
    }
    charts[name] = chart
end

local function step_stop_chart()
    chart.count = count
end

local function step_make_chart(settings)
    local chartsettings = settings.chart
    if not chartsettings then
        if trace then
            report("no chart")
        end
        return
    end
    local chartname = chartsettings.name
    if not chartname then
        if trace then
            report("no name given")
        end
        return
    end
    local chart = charts[chartname]
    if not chart then
        if trace then
            report("no such chart: %s",chartname)
        end
        return
    end
    local steps = chart.steps or { }
    --
    table.setmetatableindex(settings,defaults)
    --
    if trace then
        report(table.serialize(steps,"chartdata"))
    end
    --
    local textsettings = settings.text
    local cellsettings = settings.cell
    local linesettings = settings.line

    local start = nil
    local stop  = nil
    local flush = nil

    if false then

        -- some 2% faster at most, so neglectable as this kind of graphics
        -- is hardly used in quantity but it saves mem and tokens in tracing
        -- and we lose some aspects, like outer color and so (currently)

        local mpcode = false

        start = function()
            mpcode = { }
        end
        stop = function()
            local code = concat(mpcode,"\n")
         -- print(code)
            metapost.graphic {
             -- instance        = "metafun",
                instance        = "steps",
                format          = "metafun",
                data            = code,
             -- initializations = "",
             -- extensions      = "",
             -- inclusions      = "",
                definitions     = 'loadmodule "step" ;',
             -- figure          = "",
                method          = "double",
            }
            mpcode = false
        end
        flush = function(fmt,first,...)
            if first then
                mpcode[#mpcode+1] = formatters[fmt](first,...)
            else
                mpcode[#mpcode+1] = fmt
            end
        end

    else

        start = function() context.startMPcode("steps") end
        stop  = context.stopMPcode
        flush = context

    end
    --
    start()
    flush("step_begin_chart ;")
    --
    local alternative = chartsettings.alternative
    if not alternative or alternative == "" then
        alternative = chart.alternative
    end
    if not alternative or alternative == "" then
        alternative = variables.horizontal
    end
    local alternative = utilities.parsers.settings_to_hash(alternative)
    local vertical    = alternative[variables.vertical]
    local align       = alternative[variables.three]
    local category    = chartsettings.category
    --
    flush('chart_category := "%s" ;',category)
    --
    if vertical then
        flush("chart_vertical := true ;")
    end
    if align then
        flush("chart_align := true ;")
    end
    --
    flush("text_line_color   := %q ;", textsettings.framecolor)
    flush("text_line_width   := %p ;", textsettings.rulethickness)
    flush("text_fill_color   := %q ;", textsettings.backgroundcolor)
    flush("text_offset       := %p ;", textsettings.offset)
    flush("text_distance_set := %p ;", textsettings.distance)
    --
    flush("cell_line_color := %q ;", cellsettings.framecolor)
    flush("cell_line_width := %p ;", cellsettings.rulethickness)
    flush("cell_fill_color := %q ;", cellsettings.backgroundcolor)
    flush("cell_offset     := %p ;", cellsettings.offset)
    flush("cell_distance_x := %p ;", cellsettings.dx)
    flush("cell_distance_y := %p ;", cellsettings.dy)
    --
    flush("line_line_color := %q ;", linesettings.color)
    flush("line_line_width := %p ;", linesettings.rulethickness)
    flush("line_distance   := %p ;", linesettings.distance)
    flush("line_offset     := %p ;", linesettings.offset)
    flush("line_height     := %p ;", linesettings.height)
    --
    for i=1,chart.count do
        local step = steps[i]
        flush("step_begin_cell ;")
        local ali = step.cell_ali
        local top = step.cell_top
        local bot = step.cell_bot
        if ali then
            local text = ali.text
            local shape = ali.shape
            flush('step_cell_ali(%s,%s,%s,%q,%q,%p,%i) ;',
                tonumber(text.left) or 0,
                tonumber(text.middle) or 0,
                tonumber(text.right) or 0,
                shape.framecolor,
                shape.backgroundcolor,
                shape.rulethickness,
                tonumber(shape.alternative) or 24
            )
        end
        if top then
            local shape = top.shape
            flush('step_cell_top(%s,%q,%q,%p,%i) ;',
                tonumber(top.text.top) or 0,
                shape.framecolor,
                shape.backgroundcolor,
                shape.rulethickness,
                tonumber(shape.alternative) or 24
            )
        end
        if bot then
            local shape = bot.shape
            flush('step_cell_bot(%s,%q,%q,%p,%i) ;',
                tonumber(bot.text.bot) or 0,
                shape.framecolor,
                shape.backgroundcolor,
                shape.rulethickness,
                tonumber(shape.alternative) or 24
            )
        end
        local top = step.text_top
        local mid = step.text_mid
        local bot = step.text_bot
        local s_t = step.start_t
        local s_m = step.start_m
        local s_b = step.start_b
        if top then
            local shape = top.shape
            local line  = top.line
            flush('step_text_top(%s,%q,%q,%p,%i,%q,%p,%i) ;',
                tonumber(top.text.top) or 0,
                shape.framecolor,
                shape.backgroundcolor,
                shape.rulethickness,
                tonumber(shape.alternative) or 24,
                line.color,
                line.rulethickness,
                tonumber(line.alternative) or 1
            )
        end
        if mid then -- used ?
            local shape = mid.shape
            local line  = mid.line
            flush('step_text_mid(%s,%q,%q,%p,%i,%q,%p,%i) ;',
                tonumber(mid.text.mid) or 0,
                shape.framecolor,
                shape.backgroundcolor,
                shape.rulethickness,
                tonumber(shape.alternative) or 24,
                line.color,
                line.rulethickness,
                tonumber(line.alternative) or 1
            )
        end
        if bot then
            local shape = bot.shape
            local line  = bot.line
            flush('step_text_bot(%s,%q,%q,%p,%i,%q,%p,%i) ;',
                tonumber(bot.text.bot) or 0,
                shape.framecolor,
                shape.backgroundcolor,
                shape.rulethickness,
                tonumber(shape.alternative) or 24,
                line.color,
                line.rulethickness,
                tonumber(line.alternative) or 1
            )
        end
        flush('start_t[%i] := %i ;',i,s_t)
        flush('start_m[%i] := %i ;',i,s_m)
        flush('start_b[%i] := %i ;',i,s_b)
        flush("step_end_cell ;")
    end
    --
    flush("step_end_chart ;")
    stop()
end

local function step_cells(spec)
    count = count + 1
    local step = steps[count]
    step.cell_top = spec
    step.cell_bot = spec
end

local function step_cells_three(spec)
    count = count + 1
    local step = steps[count]
    step.cell_ali = spec
end

local function step_texts(spec)
    if count > 0 then
        local step = steps[count]
        step.text_top = spec
        step.text_bot = spec
    end
end

local function step_cell(spec)
    count = count + 1
    steps[count].cell_top = spec
end

local function step_text(spec)
    if count > 0 then
        local c = count
        while true do
            local step = steps[c]
            if step.text_top then
                c = c + 1
                step = steps[c]
            else
                step.text_top = spec
                step.start_b  = count
                break
            end
        end
    end
end

local function step_start_cell()
    count = count + 1
    local step = steps[count] -- creates
end

local function step_stop_cell()
end

local function step_text_top(spec)
    if count > 0 then
        steps[count].text_top = spec
    end
end

local function step_text_mid(spec)
    if count > 0 then
        steps[count].text_mid = spec
    end
end

local function step_text_bot(spec)
    if count > 0 then
        steps[count].text_bot = spec
    end
end

local function step_cell_top(spec)
    if count > 0 then
        steps[count].cell_top = spec
    end
end

local function step_cell_bot(spec)
    if count > 0 then
        steps[count].cell_bot = spec
    end
end

--

interfaces.implement {
    name      = "step_start_chart",
    arguments = { "string", "string" },
    actions   = step_start_chart,
}

interfaces.implement {
    name      = "step_stop_chart",
    actions   = step_stop_chart,
}

interfaces.implement {
    name      = "step_make_chart",
    actions   = step_make_chart,
    arguments = {
        {
            { "chart", {
                    { "category" },
                    { "name" },
                    { "alternative" },
                }
            },
            { "cell", {
                { "alternative" },
                { "offset", "dimension" },
                { "rulethickness", "dimension" },
                { "framecolor" },
                { "backgroundcolor" },
                { "dx", "dimension" },
                { "dy", "dimension" },
                }
            },
            { "text", {
                { "alternative" },
                { "offset", "dimension" },
                { "distance", "dimension" },
                { "rulethickness", "dimension" },
                { "framecolor" },
                { "backgroundcolor" },
                }
            },
            { "line", {
                { "alternative" },
                { "rulethickness", "dimension" },
                { "height", "dimension" },
                { "distance", "dimension" },
                { "offset", "dimension" },
                { "color" },
                }
            }
        }
    }
}

local step_spec = {
    {
        { "text", {
                { "top" },
                { "middle" },
                { "mid" },
                { "bot" },
                { "left" },
                { "right" },
            }
        },
        { "shape", {
                { "rulethickness", "dimension" },
                { "alternative" },
                { "framecolor" },
                { "backgroundcolor" },
            }
        },
        { "line", {
                { "alternative" },
                { "rulethickness", "dimension" },
                { "color" },
                { "offset", "dimension" },
            }
        }
    }
}

interfaces.implement {
    name      = "step_cell",
    arguments = step_spec,
    actions   = step_cell,
}

interfaces.implement {
    name      = "step_text",
    arguments = step_spec,
    actions   = step_text,
}

interfaces.implement {
    name      = "step_text_top",
    arguments = step_spec,
    actions   = step_text_top,
}

interfaces.implement {
    name      = "step_text_mid",
    arguments = step_spec,
    actions   = step_text_mid,
}

interfaces.implement {
    name      = "step_text_bot",
    arguments = step_spec,
    actions   = step_text_bot,
}

interfaces.implement {
    name      = "step_cell_top",
    arguments = step_spec,
    actions   = step_cell_top,
}

interfaces.implement {
    name      = "step_cell_bot",
    arguments = step_spec,
    actions   = step_cell_bot,
}

interfaces.implement {
    name      = "step_start_cell",
    actions   = step_start_cell,
}

interfaces.implement {
    name      = "step_stop_cell",
    actions   = step_stop_cell,
}

interfaces.implement {
    name      = "step_texts",
    arguments = step_spec,
    actions   = step_texts,
}

interfaces.implement {
    name      = "step_cells",
    arguments = step_spec,
    actions   = step_cells,
}

interfaces.implement {
    name      = "step_cells_three",
    arguments = step_spec,
    actions   = step_cells_three,
}
