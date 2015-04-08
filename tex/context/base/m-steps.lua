if not modules then modules = { } end modules ['x-flow'] = {
    version   = 1.001,
    comment   = "companion to m-flow.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- when we can resolve mpcolor at the lua end we will use metapost.graphic(....) directly

moduledata.steps = moduledata.steps or { }

local variables    = interfaces.variables

local trace_charts = false

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

local charts = { }
local steps  = { }

function commands.step_start_chart(name)
    name = name or ""
    steps = { }
    charts[name] = {
        steps = steps,
    }
end

function commands.step_stop_chart()
end

function commands.step_make_chart(settings)
    local chartsettings = settings.chart
    if not chartsettings then
        print("no chart")
        return
    end
    local chartname = chartsettings.name
    if not chartname then
        print("no name given")
        return
    end
    local chart = charts[chartname]
    if not chart then
        print("no such chart",chartname)
        return
    end
    local steps = chart.steps or { }
    --
    table.setmetatableindex(settings,defaults)
    --
    if trace_charts then
        inspect(steps)
    end
    --
    local textsettings = settings.text
    local cellsettings = settings.cell
    local linesettings = settings.line
    --
    context.startMPcode()
    context("if unknown context_cell : input mp-step.mpiv ; fi ;")
    context("step_begin_chart ;")
    --
    if chartsettings.alternative == variables.vertical then
        context("chart_vertical := true ;")
    end
    --
    context("text_line_color   := \\MPcolor{%s} ;", textsettings.framecolor)
    context("text_line_width   := %p ;", textsettings.rulethickness)
    context("text_fill_color   := \\MPcolor{%s} ;", textsettings.backgroundcolor)
    context("text_offset       := %p ;", textsettings.offset)
    context("text_distance_set := %p ;", textsettings.distance)
    --
    context("cell_line_color := \\MPcolor{%s} ;", cellsettings.framecolor)
    context("cell_line_width := %p ;", cellsettings.rulethickness)
    context("cell_fill_color := \\MPcolor{%s} ;", cellsettings.backgroundcolor)
    context("cell_offset     := %p ;", cellsettings.offset)
    context("cell_distance_x := %p ;", cellsettings.dx)
    context("cell_distance_y := %p ;", cellsettings.dy)
    --
    context("line_line_color := \\MPcolor{%s} ;", linesettings.color)
    context("line_line_width := %p ;", linesettings.rulethickness)
    context("line_distance   := %p ;", linesettings.distance)
    context("line_offset     := %p ;", linesettings.offset)
    --
    for i=1,#steps do
        local step = steps[i]
        context("step_begin_cell ;")
        if step.cell_top ~= "" then
            context('step_cell_top("%s") ;',string.strip(step.cell_top))
        end
        if step.cell_bot ~= "" then
            context('step_cell_bot("%s") ;',string.strip(step.cell_bot))
        end
        if step.text_top ~= "" then
            context('step_text_top("%s") ;',string.strip(step.text_top))
        end
        if step.text_mid ~= "" then
            context('step_text_mid("%s") ;',string.strip(step.text_mid))
        end
        if step.text_bot ~= "" then
            context('step_text_bot("%s") ;',string.strip(step.text_bot))
        end
        context("step_end_cell ;")
    end
    --
    context("step_end_chart ;")
    context.stopMPcode()
end

function commands.step_cells(top,bot)
    steps[#steps+1] = {
        cell_top = top or "",
        cell_bot = bot or "",
        text_top = "",
        text_mid = "",
        text_bot = "",
    }
end

function commands.step_texts(top,bot)
    if #steps > 0 then
        steps[#steps].text_top = top or ""
        steps[#steps].text_bot = bot or ""
    end
end

function commands.step_cell(top)
    steps[#steps+1] = {
        cell_top = top or "",
        cell_bot = "",
        text_top = "",
        text_mid = "",
        text_bot = "",
    }
end

function commands.step_text(top)
    if #steps > 0 then
        steps[#steps].text_top = top or ""
    end
end

function commands.step_textset(left,middle,right)
    if #steps > 0 then
        steps[#steps].text_top = left   or ""
        steps[#steps].text_mid = middle or ""
        steps[#steps].text_bot = right  or ""
    end
end

function commands.step_start_cell()
    steps[#steps+1] = {
        cell_top = "",
        cell_bot = "",
        text_top = "",
        text_mid = "",
        text_bot = "",
    }
end

function commands.step_stop_cell()
end

function commands.step_text_top(str)
    if #steps > 0 then
        steps[#steps].text_top = str or ""
    end
end

function commands.step_text_mid(str)
    if #steps > 0 then
        steps[#steps].text_mid = str or ""
    end
end

function commands.step_text_bot(str)
    if #steps > 0 then
        steps[#steps].text_bot = str or ""
    end
end

function commands.step_cell_top(str)
    if #steps > 0 then
        steps[#steps].cell_top = str or ""
    end
end

function commands.step_cell_bot(str)
    if #steps > 0 then
        steps[#steps].cell_bot = str or ""
    end
end
