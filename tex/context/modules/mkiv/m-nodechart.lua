if not modules then modules = { } end modules ['m-nodechart'] = {
    version   = 1.001,
    comment   = "companion to m-nodechart.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format       = string.format
local points       = number.nopts
local ptfactor     = number.dimenfactors.pt

local nodecodes    = nodes.nodecodes
local kerncodes    = nodes.kerncodes
local penaltycodes = nodes.penaltycodes
local gluecodes    = nodes.gluecodes
local whatsitcodes = nodes.whatsitcodes

moduledata.charts       = moduledata.charts       or { }
moduledata.charts.nodes = moduledata.charts.nodes or { }

local formatters = { }

-- subtype font char lang left right uchyph components xoffset yoffset width height depth

function formatters.glyph(n,comment)
    return format("\\doFLOWglyphnode{%s}{%s}{%s}{%s}{U+%05X}",comment,n.subtype,n.font,n.char,n.char)
end

-- pre post replace

function formatters.disc(n,comment)
    return format("\\doFLOWdiscnode{%s}{%s}",comment,n.subtype)
end

-- subtype kern

function formatters.kern(n,comment)
 -- return format("\\doFLOWkernnode{%s}{%s}{%s}",comment,kerncodes[n.subtype],points(n.kern))
    return format("\\doFLOWkernnode{%s}{%s}{%.4f}",comment,kerncodes[n.subtype],n.kern*ptfactor)
end

-- subtype penalty

function formatters.penalty(n,comment)
    return format("\\doFLOWpenaltynode{%s}{%s}{%s}",comment,"penalty",n.penalty)
end

-- subtype width leader spec (stretch shrink ...

function formatters.glue(n,comment)
    return format("\\doFLOWgluenode{%s}{%s}{%.4f}{%.4f}{%.4f}",comment,gluecodes[n.subtype],n.width*ptfactor,n.stretch*ptfactor,n.shrink*ptfactor)
end

-- subtype width leader spec (stretch shrink ...

function formatters.whatsit(n,comment)
    return whatsitcodes[n.id] or "unknown whatsit"
end

function formatters.dir(n,comment)
    return format("\\doFLOWdirnode{%s}{%s}{%s}",comment,"dir",n.dir)
end

function formatters.localpar(n,comment)
    return format("\\doFLOWdirnode{%s}{%s}{%s}",comment,"localpar",n.dir)
end

-- I will make a dedicated set of shapes for this.

local shapes = {
    glyph   = "procedure",
    disc    = "procedure",
    kern    = "action",
    penalty = "action",
    glue    = "action",
}

local function flow_nodes_to_chart(specification)
    local head    = specification.head
    local box     = specification.box
    local comment = specification.comment or ""
    local x       = specification.x or 1
    local y       = specification.y or 0
    --
    if box then
          box  = tex.getbox(tonumber(box))
          head = box and box.list
    end
    --
    local current = head
    --
    while current do
        local nodecode  = nodecodes[current.id]
        local formatter = formatters[nodecode]
        local shape     = shapes[nodecode]
        y = y + 1
        local next = current.next
        commands.flow_start_cell { shape = { framecolor = "nodechart:" .. nodecode } }
        commands.flow_set_name(tostring(current))
        commands.flow_set_location(x,y)
        if shape then
            commands.flow_set_shape(shape)
        end
        if formatter then
            commands.flow_set_text("node",formatter(current,comment))
        else
            commands.flow_set_text("node",nodecode)
        end
        if next then
            commands.flow_set_connection("bt","",tostring(next))
        end
        if nodecode == "glyph" then
            local components = current.components
            if components then
                commands.flow_set_connection("rl","",tostring(components))
                commands.flow_stop_cell()
                n = flow_nodes_to_chart { head = components, comment = "component",x = x+2, y = y-1 }
            else
                commands.flow_stop_cell()
            end
        elseif nodecode == "disc" then
            local pre = current.pre
            local pos = current.post
            local rep = current.replace
            if pre and not rep and not rep then
                if pre then
                    commands.flow_set_connection("rl","",tostring(pre))
                end
                commands.flow_stop_cell()
                if pre then
                    n = flow_nodes_to_chart { head = pre, comment = "prebreak", x = x+1, y = y-1 }
                end
            else
                if pre then
                    commands.flow_set_connection("rl","",tostring(pre))
                end
                if rep then
                    commands.flow_set_connection("+rl","",tostring(rep))
                end
                if pos then
                    commands.flow_set_connection("-rl","",tostring(pos))
                end
                commands.flow_stop_cell()
                if pre then
                    n = flow_nodes_to_chart{ head = pre, comment = "prebreak", x = x+1, y = y-1 }
                end
                if rep then
                    n = flow_nodes_to_chart{ head = rep, comment = "replacement", x = x+3, y = y-1 }
                end
                if pos then
                    n = flow_nodes_to_chart{ head = pos, comment = "postbreak", x = x+2, y = y-1 }
                end
            end
        elseif nodecode == "hlist" then
            local list = current.list
            if list then
                commands.flow_set_connection("rl","",tostring(list))
                commands.flow_stop_cell()
                n = flow_nodes_to_chart { head = list, comment = "list", x = x+2, y = y-1 }
            else
                commands.flow_stop_cell()
            end
        else
            commands.flow_stop_cell()
        end
        current = next
    end
end

function moduledata.charts.nodes.chart(specification)
    commands.flow_start_chart(specification.name)
    flow_nodes_to_chart(specification)
    commands.flow_stop_chart()
end
