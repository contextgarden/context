if not modules then modules = { } end modules ['x-flow'] = {
    version   = 1.001,
    comment   = "companion to m-flow.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- when we can resolve mpcolor at the lua end we will
-- use metapost.graphic(....) directly

-- todo: labels
-- todo: named colors

local type, tonumber, rawget, next = type, tonumber, rawget, next
local gsub, find, lower = string.gsub, string.find, string.lower
local P, S, C, Cc, lpegmatch = lpeg.P, lpeg.S, lpeg.C, lpeg.Cc, lpeg.match

local context           = context

local ctx_startgraphic  = metapost.startgraphic
local ctx_stopgraphic   = metapost.stopgraphic
local ctx_tographic     = metapost.tographic

local formatters        = string.formatters
local setmetatableindex = table.setmetatableindex
local settings_to_hash  = utilities.parsers.settings_to_hash

moduledata.charts       = moduledata.charts or { }

local report_chart      = logs.reporter("chart")

local variables         = interfaces.variables
local implement         = interfaces.implement

local v_yes             = variables.yes
local v_no              = variables.no
local v_none            = variables.none
local v_standard        = variables.standard
local v_overlay         = variables.overlay
local v_round           = variables.round
local v_test            = variables.test

local defaults = {
    chart = {
        name            = "",
        option          = "",
        backgroundcolor = "",
        width           = 100*65536,
        height          = 50*65536,
        dx              = 30*65536,
        dy              = 30*65536,
        offset          = 0,
        bodyfont        = "",
        dot             = "",
        hcompact        = variables_no,
        vcompact        = variables_no,
        autofocus       = "",
        focus           = "",
        labeloffset     = 5*65536,
        commentoffset   = 5*65536,
        exitoffset      = 0,

    },
    shape = { -- FLOS
        rulethickness   = 65536,
        default         = "",
        framecolor      = "darkblue",
        backgroundcolor = "lightgray",
    },
    focus = { -- FLOF
        rulethickness   = 65536,
        framecolor      = "darkred",
        backgroundcolor = "gray",
    },
    line = { -- FLOL
        rulethickness   = 65536,
        radius          = 10*65536,
        color           = "darkgreen",
        corner          = "",
        dash            = "",
        arrow           = "",
        offset          = "",
    },
    set = { -- FLOX
    },
    split = {
        nx      = 3,
        ny      = 3,
        command = "",
        marking = "",
        before  = "",
        after   = "",
    }
}

local validshapes = {
    ["node"]            = { kind = "shape", number =  0 },
    ["action"]          = { kind = "shape", number = 24 },
    ["procedure"]       = { kind = "shape", number =  5 },
    ["product"]         = { kind = "shape", number = 12 },
    ["decision"]        = { kind = "shape", number = 14 },
    ["archive"]         = { kind = "shape", number = 19 },
    ["loop"]            = { kind = "shape", number = 35 },
    ["wait"]            = { kind = "shape", number =  6 },
    ["subprocedure"]    = { kind = "shape", number = 20 },
    ["singledocument"]  = { kind = "shape", number = 32 },
    ["multidocument"]   = { kind = "shape", number = 33 },

    ["right"]           = { kind = "line",  number = 66 },
    ["left"]            = { kind = "line",  number = 67 },
    ["up"]              = { kind = "line",  number = 68 },
    ["down"]            = { kind = "line",  number = 69 },
}

local validlabellocations = {
    l  = "l",  left   = "l",
    r  = "r",  right  = "r",
    t  = "t",  top    = "t",
    b  = "b",  bottom = "b",
    lt = "lt",
    rt = "rt",
    lb = "lb",
    rb = "rb",
    tl = "tl",
    tr = "tr",
    bl = "bl",
    br = "br",
}

local validcommentlocations = {
    l  = "l",  left   = "l",
    r  = "r",  right  = "r",
    t  = "t",  top    = "t",
    b  = "b",  bottom = "b",
    lt = "lt",
    rt = "rt",
    lb = "lb",
    rb = "rb",
    tl = "tl",
    tr = "tr",
    bl = "bl",
    br = "br",
}

local validtextlocations = {
    l  = "l",  left   = "l",
    r  = "r",  right  = "r",
    t  = "t",  top    = "t",
    b  = "b",  bottom = "b",
    c  = "c",  center = "c",
    m  = "c",  middle = "m",
    lt = "lt",
    rt = "rt",
    lb = "lb",
    rb = "rb",
    tl = "lt",
    tr = "rt",
    bl = "lb",
    br = "rb",
}

setmetatableindex(validshapes,function(t,k)
    local l = gsub(lower(k)," ","")
    local v = rawget(t,l)
    if not v then
        local n = tonumber(k)
        if n then
            v = { kind = "shape", number = n }
        else
            v = rawget(t,"action")
        end
    end
    t[k] = v
    return v
end)

local charts = { }

local data, hash, temp, last_x, last_y, name

implement {
    name      = "flow_start_chart",
    arguments = "string",
    actions   = function(chartname)
        data = { }
        hash = { }
        last_x, last_y = 0, 0
        name = chartname
    end
}

implement {
    name      = "flow_stop_chart",
    actions   = function()
        charts[name] = {
            data = data,
            hash = hash,
            last_x = last_x,
            last_y = last_y,
        }
        data, hash, temp = nil, nil, nil
    end
}

-- function commands.flow_set(chartname,chartdata)
--     local hash = { }
--     local data = { }
--     charts[name] = {
--         data = data,
--         hash = hash,
--     }
--     for i=1,#chartdata do
--         local di = data[i]
--         local name = di.name or ""
--         if name then
--             data[#data+1] = {
--                 name        = name,
--                 labels      = di.labels      or { },
--                 comments    = di.comments    or { },
--                 exits       = di.exits       or { },
--                 connections = di.connections or { },
--                 settings    = di.settings    or { },
--                 x           = di.x           or 1,
--                 y           = di.y           or 1,
--             }
--             hash[name] = i
--         end
--      end
-- end

implement {
    name    = "flow_reset",
    actions = function()
        charts[name] = nil
    end
}

implement {
    name      = "flow_set_current_cell",
    arguments = "integer",
    actions   = function(n)
        temp = data[n] or { }
    end
}

implement {
    name      = "flow_start_cell",
    arguments = {
        {
            { "shape", {
                    { "rulethickness", "dimension" },
                    { "default" },
                    { "framecolor" },
                    { "backgroundcolor" },
                },
            },
            { "focus", {
                    { "rulethickness", "dimension" },
                    { "framecolor" },
                    { "backgroundcolor" },
                },
            },
            { "line", {
                    { "rulethickness", "dimension" },
                    { "radius", "dimension" },
                    { "color" },
                    { "corner" },
                    { "dash" },
                    { "arrow" },
                    { "offset", "dimension" },
                },
            },
        },
    },
    actions   = function(settings)
        temp = {
            texts       = { },
            labels      = { },
            exits       = { },
            connections = { },
            settings    = settings,
            x           = 1,
            y           = 1,
            realx       = 1,
            realy       = 1,
            name        = "",
        }
    end
}

implement {
    name    = "flow_stop_cell",
    actions = function()
        data[#data+1] = temp
        hash[temp.name or #data] = temp
    end
}

implement {
    name      = "flow_set_name",
    arguments = "string",
    actions   = function(str)
        temp.name = str
    end
}

implement {
    name      = "flow_set_shape",
    arguments = "string",
    actions   = function(str)
        temp.shape = str
    end
}

implement {
    name      = "flow_set_destination",
    arguments = "string",
    actions   = function(str)
        temp.destination = str
    end
}

implement {
    name      = "flow_set_text",
    arguments = { "string", "string" },
    actions   = function(align,str)
        temp.texts[#temp.texts+1] = {
            align = align,
            text  = str,
        }
    end
}

implement {
    name      = "flow_set_overlay",
    arguments = "string",
    actions   = function(str)
        temp.overlay = str
    end
}

implement {
    name      = "flow_set_focus",
    arguments = "string",
    actions   = function(str)
        temp.focus = str
    end
}

implement {
    name      = "flow_set_figure",
    arguments = "string",
    actions   = function(str)
        temp.figure = str
    end
}

implement {
    name      = "flow_set_label",
    arguments = { "string", "string" },
    actions   = function(location,text)
        temp.labels[#temp.labels+1] = {
            location = location,
            text = text,
        }
    end
}

implement {
    name      = "flow_set_comment",
    arguments = { "string", "string" },
    actions   = function(location,text)
        local connections = temp.connections
        if connections then
            local connection = connections[#connections]
            if connection then
                local comments = connection.comments
                if comments then
                    comments[#comments+1] = {
                        location = location,
                        text = text,
                    }
                end
            end
        end
    end
}

implement {
    name      = "flow_set_exit",
    arguments = { "string", "string" },
    actions   = function(location,text)
        temp.exits[#temp.exits+1] = {
            location = location,
            text = text,
        }
    end
}

implement {
    name      = "flow_set_include",
    arguments = { "string", "integer", "integer", "string" },
    actions   = function(name,x,y,settings)
        data[#data+1] = {
            include  = name,
            x        = x,
            y        = y,
         -- settings = settings,
        }
    end
}

local function inject(includedata,data,hash)
    local subchart = charts[includedata.include]
    if not subchart then
        return
    end
    local subdata = subchart.data
    if not subdata then
        return
    end
    local xoffset  = (includedata.x or 1) - 1
    local yoffset  = (includedata.y or 1) - 1
    local settings = includedata.settings
    for i=1,#subdata do
        local si = subdata[i]
        if si.include then
            inject(si,data,hash)
        else
            local x = si.x + xoffset
            local y = si.y + yoffset
            local t = {
                x        = x,
                y        = y,
                realx    = x,
                realy    = y,
                settings = settings,
            }
            setmetatableindex(t,si)
            data[#data+1] = t
            hash[si.name or #data] = t
        end
    end
end

local function pack(data,field)
    local list, max = { }, 0
    for e=1,#data do
        local d = data[e]
        local f = d[field]
        list[f] = true
        if f > max then
            max = f
        end
    end
    for i=1,max do
        if not list[i] then
            for e=1,#data do
                local d = data[e]
                local f = d[field]
                if f > i then
                    d[field] = f - 1
                end
            end
        end
    end
end

local function expanded(chart,chartsettings)
    local expandeddata = { }
    local expandedhash = { }
    local expandedchart = {
        data = expandeddata,
        hash = expandedhash,
    }
    setmetatableindex(expandedchart,chart)
    local data = chart.data
    local hash = chart.hash
    for i=1,#data do
        local di = data[i]
        if di.include then
            inject(di,expandeddata,expandedhash)
        else
            expandeddata[#expandeddata+1]  = di
            expandedhash[di.name or #expandeddata] = di
        end
    end
    --
    expandedchart.settings = chartsettings or { }
    -- make locals
    chartsettings.shape = chartsettings.shape or { }
    chartsettings.focus = chartsettings.focus or { }
    chartsettings.line  = chartsettings.line  or { }
    chartsettings.set   = chartsettings.set   or { }
    chartsettings.split = chartsettings.split or { }
    chartsettings.chart = chartsettings.chart or { }
    setmetatableindex(chartsettings.shape,defaults.shape)
    setmetatableindex(chartsettings.focus,defaults.focus)
    setmetatableindex(chartsettings.line ,defaults.line )
    setmetatableindex(chartsettings.set  ,defaults.set  )
    setmetatableindex(chartsettings.split,defaults.split)
    setmetatableindex(chartsettings.chart,defaults.chart)
    --
    if chartsettings.chart.vcompact == v_yes then
        pack(expandeddata,"y")
    end
    if chartsettings.chart.hcompact == v_yes then
        pack(expandeddata,"x")
    end
    --
    for i=1,#expandeddata do
        local cell = expandeddata[i]
        local settings = cell.settings
        if not settings then
            cell.settings = chartsettings
        else
            settings.shape = settings.shape or { }
            settings.focus = settings.focus or { }
            settings.line  = settings.line  or { }
            setmetatableindex(settings.shape,chartsettings.shape)
            setmetatableindex(settings.focus,chartsettings.focus)
            setmetatableindex(settings.line ,chartsettings.line)
        end
    end
    return expandedchart
end

local splitter = lpeg.splitat(",")

implement {
    name      = "flow_set_location",
    arguments = "string",
    actions   = function(x,y)
        if type(x) == "string" and not y then
            x, y = lpegmatch(splitter,x)
        end
        local oldx, oldy = x, y
        if not x or x == "" then
            x = last_x
        elseif type(x) == "number" then
            -- ok
        elseif x == "+" then
            x = last_x + 1
        elseif x == "-" then
            x = last_x - 1
        elseif find(x,"^[%+%-]") then
            x = last_x + (tonumber(x) or 0)
        else
            x = tonumber(x)
        end
        if not y or y == "" then
            y = last_y
        elseif type(y) == "number" then
            -- ok
        elseif y == "+" then
            y = last_y + 1
        elseif x == "-" then
            y = last_y - 1
        elseif find(y,"^[%+%-]") then
            y = last_y + (tonumber(y) or 0)
        else
            y = tonumber(y)
        end
        if x < 1 or y < 1 then
            report_chart("the cell (%s,%s) ends up at (%s,%s) and gets relocated to (1,1)",oldx or"?", oldy or "?", x,y)
            if x < 1 then
                x = 1
            end
            if y < 1 then
                y = 1
            end
        end
        temp.x     = x or 1
        temp.y     = y or 1
        temp.realx = x or 1
        temp.realy = y or 1
        last_x     = x or last_x
        last_y     = y or last_y
    end
}

implement {
    name      = "flow_set_connection",
    arguments = { "string", "string", "string" },
    actions   = function(location,displacement,name)
        local dx, dy = lpegmatch(splitter,displacement)
        dx = tonumber(dx)
        dy = tonumber(dy)
        temp.connections[#temp.connections+1] = {
            location = location,
            dx       = dx or 0,
            dy       = dy or 0,
            name     = name,
            comments = { },
        }
    end
}

local function visible(chart,cell)
    local x, y = cell.x, cell.y
    return
        x >= chart.from_x and x <= chart.to_x and
        y >= chart.from_y and y <= chart.to_y and cell
end

local function process_cells(g,chart,xoffset,yoffset)
    local data = chart.data
    if not data then
        return
    end
    local focus = settings_to_hash(chart.settings.chart.focus or "")
    for i=1,#data do
        local cell = visible(chart,data[i])
        if cell then
            local settings = cell.settings
            local shapesettings = settings.shape
            local shape = cell.shape
            if not shape or shape == "" then
                shape = shapesettings.default or "none"
            end
            if shape ~= v_none then
                local shapedata = validshapes[shape]
                ctx_tographic(g,"flow_begin_sub_chart ;") -- when is this needed
                if shapedata.kind == "line" then
                    local linesettings = settings.line
                    ctx_tographic(g,"flow_shape_line_color := %q ;", linesettings.color)
                    ctx_tographic(g,"flow_shape_fill_color := %q ;","black")
                    ctx_tographic(g,"flow_shape_line_width := %p ; ",linesettings.rulethickness)
                elseif focus[cell.focus] or focus[cell.name] then
                    local focussettings = settings.focus
                    ctx_tographic(g,"flow_shape_line_color := %q ;", focussettings.framecolor)
                    ctx_tographic(g,"flow_shape_fill_color := %q ;", focussettings.backgroundcolor)
                    ctx_tographic(g,"flow_shape_line_width := %p ; ",focussettings.rulethickness)
                else
                    local shapesettings = settings.shape
                    ctx_tographic(g,"flow_shape_line_color := %q ;", shapesettings.framecolor)
                    ctx_tographic(g,"flow_shape_fill_color := %q ;", shapesettings.backgroundcolor)
                    ctx_tographic(g,"flow_shape_line_width := %p ; ",shapesettings.rulethickness)
                end
                ctx_tographic(g,"flow_peepshape := false ;")   -- todo
                ctx_tographic(g,"flow_new_shape(%s,%s,%s) ;",cell.x+xoffset,cell.y+yoffset,shapedata.number)
                ctx_tographic(g,"flow_end_sub_chart ;")
            end
        end
    end
end

-- todo : make lpeg for splitter

local sign  = S("+p")  /  "1"
            + S("-mn") / "-1"

local full  = C(P("left"))
            + C(P("right"))
            + C(P("top"))
            + C(P("bottom"))

local char  = P("l") / "left"
            + P("r") / "right"
            + P("t") / "top"
            + P("b") / "bottom"

local space = P(" ")^0

local what  = space
            * (sign + Cc("0"))
            * space
            * (full + char)
            * space
            * (sign + Cc("0"))
            * space
            * (full + char)
            * space
            * P(-1)

-- print(lpegmatch(what,"lr"))
-- print(lpegmatch(what,"+l+r"))
-- print(lpegmatch(what,"+l"))
-- print(lpegmatch(what,"+ left+r     "))

local function process_connections(g,chart,xoffset,yoffset)
    local data = chart.data
    local hash = chart.hash
    if not data then
        return
    end
    local settings = chart.settings
    for i=1,#data do
        local cell = visible(chart,data[i])
        if cell then
            local connections = cell.connections
            for j=1,#connections do
                local connection = connections[j]
                local othername = connection.name
                local othercell = hash[othername]
                if othercell then -- and visible(chart,data[i]) then
                    local cellx, celly = cell.x, cell.y
                    local otherx, othery, location = othercell.x, othercell.y, connection.location
                    if otherx > 0 and othery > 0 and cellx > 0 and celly > 0 and location then
                        local what_cell, where_cell, what_other, where_other = lpegmatch(what,location)
                        if what_cell and where_cell and what_other and where_other then
                            local linesettings = settings.line
                            ctx_tographic(g,"flow_smooth := %s ;", linesettings.corner == v_round and "true" or "false")
                            ctx_tographic(g,"flow_dashline := %s ;", linesettings.dash == v_yes and "true" or "false")
                            ctx_tographic(g,"flow_arrowtip := %s ;", linesettings.arrow == v_yes and "true" or "false")
                            ctx_tographic(g,"flow_touchshape := %s ;", linesettings.offset == v_none and "true" or "false")
                            ctx_tographic(g,"flow_dsp_x := %s ; flow_dsp_y := %s ;",connection.dx or 0, connection.dy or 0)
                            ctx_tographic(g,"flow_connection_line_color := %q ;",linesettings.color)
                            ctx_tographic(g,"flow_connection_line_width := %p ;",linesettings.rulethickness)
                            ctx_tographic(g,"flow_connect_%s_%s (%s) (%s,%s,%s) (%s,%s,%s) ;",where_cell,where_other,j,cellx,celly,what_cell,otherx,othery,what_other)
                            ctx_tographic(g,"flow_dsp_x := 0 ; flow_dsp_y := 0 ;")
                        end
                    end
                end
            end
        end
    end
end

local f_texttemplate_t = formatters["\\setvariables[flowcell:text][x=%s,y=%s,n=%i,align={%s},figure={%s},overlay={%s},destination={%s}]"]
local f_texttemplate_l = formatters["\\doFLOWlabel{%i}{%i}{%i}"]

local splitter   = lpeg.splitat(":")
local charttexts = { } -- permits " etc in mp

implement {
    name      = "flow_get_text",
    arguments = "integer",
    actions   = function(n)
        if n > 0 then
            context(charttexts[n])
        end
    end
}

local function process_texts(g,chart,xoffset,yoffset)
    local data = chart.data
    local hash = chart.hash
    if not data then
        return
    end
    charttexts = { }
    for i=1,#data do
        local cell = visible(chart,data[i])
        if cell then
            local x           = cell.x or 1
            local y           = cell.y or 1
            local figure      = cell.figure or ""
            local overlay     = cell.overlay or ""
            local destination = cell.destination or ""
            local texts       = cell.texts
            local noftexts    = #texts
            if noftexts > 0 then
                for i=1,noftexts do
                    local text  = texts[i]
                    local data  = text.text
                    local align = text.align or ""
                    local align = validlabellocations[align] or align
                    charttexts[#charttexts+1] = data
                    ctx_tographic(g,'flow_chart_draw_text(%s,%s,textext("%s")) ;',x,y,f_texttemplate_t(x,y,#charttexts,align,figure,overlay,destination))
                    if i == 1 then
                        figure      = ""
                        overlay     = ""
                        destination = ""
                    end
                end
            elseif figure ~= "" or overlay ~= "" or destination ~= "" then
                ctx_tographic(g,'flow_chart_draw_text(%s,%s,textext("%s")) ;',x,y,f_texttemplate_t(x,y,0,"",figure,overlay,destination))
            end
            local labels = cell.labels
            for i=1,#labels do
                local label    = labels[i]
                local text     = label.text
                local location = label.location or ""
                local location = validlabellocations[location] or location
                if text and text ~= "" then
                    charttexts[#charttexts+1] = text
                    ctx_tographic(g,'flow_chart_draw_label(%s,%s,"%s",textext("%s")) ;',x,y,location,f_texttemplate_l(x,y,#charttexts))
                end
            end
            local exits = cell.exits
            for i=1,#exits do
                local exit     = exits[i]
                local text     = exit.text
                local location = exit.location or ""
                local location = validlabellocations[location] or location
                if text ~= "" then
                    -- maybe make autoexit an option
                    if location == "l" and x == chart.from_x + 1 or
                       location == "r" and x == chart.to_x   - 1 or
                       location == "t" and y == chart.to_y   - 1 or
                       location == "b" and y == chart.from_y + 1 then
                        charttexts[#charttexts+1] = text
                        ctx_tographic(g,'flow_chart_draw_exit(%s,%s,"%s",textext("%s")) ;',x,y,location,f_texttemplate_l(x,y,#charttexts))
                    end
                end
            end
            local connections = cell.connections
            for i=1,#connections do
                local comments = connections[i].comments
                for j=1,#comments do
                    local comment  = comments[j]
                    local text     = comment.text
                    local location = comment.location or ""
                    local length   = 0
                    -- "tl" "tl:*" "tl:0.5"
                    local loc, len = lpegmatch(splitter,location) -- do the following in lpeg
                    if len == "*" then
                        location = validcommentlocations[loc] or ""
                        if location == "" then
                            location = "*"
                        else
                            location = location .. ":*"
                        end
                    elseif loc then
                        location = validcommentlocations[loc] or "*"
                        length   = tonumber(len) or 0
                    else
                        location = validcommentlocations[location] or ""
                    end
                    if text and text ~= "" then
                        charttexts[#charttexts+1] = text
                        ctx_tographic(g,'flow_chart_draw_comment(%s,%s,%s,"%s",%s,textext("%s")) ;',x,y,i,location,length,f_texttemplate_l(x,y,#charttexts))
                    end
                end
            end
        end
    end
end

local function getchart(settings,forced_x,forced_y,forced_nx,forced_ny)
    if not settings then
        print("no settings given")
        return
    end
    local chartname = settings.chart.name
    if not chartname then
        print("no name given")
        return
    end
    local chart = charts[chartname]
    if not chart then
        print("no such chart",chartname)
        return
    end
    chart = expanded(chart,settings)
    local chartsettings = chart.settings.chart
    local autofocus = chart.settings.chart.autofocus
    if autofocus then
        autofocus = settings_to_hash(autofocus)
        if not next(autofocus) then
            autofocus = false
        end
    end
    -- check natural window
    local x  = forced_x  or tonumber(chartsettings.x)
    local y  = forced_y  or tonumber(chartsettings.y)
    local nx = forced_nx or tonumber(chartsettings.nx)
    local ny = forced_ny or tonumber(chartsettings.ny)
    --
    local minx, miny, maxx, maxy = 0, 0, 0, 0
    local data = chart.data
    for i=1,#data do
        local cell = data[i]
        if not autofocus or autofocus[cell.name] then -- offsets probably interfere with autofocus
            local x = cell.realx -- was bug: .x
            local y = cell.realy -- was bug: .y
            if minx == 0 or x < minx then minx = x end
            if miny == 0 or y < miny then miny = y end
            if minx == 0 or x > maxx then maxx = x end
            if miny == 0 or y > maxy then maxy = y end
        end
    end
    -- optional:
    if x + nx > maxx then
        nx = maxx - x + 1
    end
    if y + ny > maxy then
        ny = maxy - y + 1
    end
    --
    -- check if window should be larger (maybe autofocus + nx/ny?)
    if autofocus then
        -- x and y are ignored
        if nx and nx > 0 then
            maxx = minx + nx - 1
        end
        if ny and ny > 0 then
            maxy = miny + ny - 1
        end
    else
        if x and x > 0 then
            minx = x
        end
        if y and y > 0 then
            miny = y
        end
        if nx and nx > 0 then
            maxx = minx + nx - 1
        end
        if ny and ny > 0 then
            maxy = miny + ny - 1
        end
    end
-- print("3>",minx, miny, maxx, maxy)
    --
    local nx = maxx - minx + 1
    local ny = maxy - miny + 1
    -- relocate cells
    for i=1,#data do
        local cell = data[i]
        cell.x = cell.realx - minx + 1
        cell.y = cell.realy - miny + 1
    end
    chart.from_x = 1
    chart.from_y = 1
    chart.to_x   = nx
    chart.to_y   = ny
    chart.nx     = nx
    chart.ny     = ny
    --
    chart.shift_x = minx + 1
    chart.shift_y = miny + 1
    --
    return chart
end

local function makechart_indeed(chart)
    local settings      = chart.settings
    local chartsettings = settings.chart
    --
    local g = ctx_startgraphic {
        instance    = "metafun",
        format      = "metafun",
        method      = "scaled",
        definitions = "",
        wrapped     = true,
    }
    --
    ctx_tographic(g,"if unknown context_flow : input mp-char.mpiv ; fi ;")
    ctx_tographic(g,"flow_begin_chart(0,%s,%s);",chart.nx,chart.ny)
    --
    if chartsettings.option == v_test or chartsettings.dot == v_yes then
        ctx_tographic(g,"flow_show_con_points := true ;")
        ctx_tographic(g,"flow_show_mid_points := true ;")
        ctx_tographic(g,"flow_show_all_points := true ;")
    elseif chartsettings.dot ~= "" then -- no checking done, private option
        ctx_tographic(g,"flow_show_%s_points := true ;",chartsettings.dot)
    end
    --
    local backgroundcolor = chartsettings.backgroundcolor
    if backgroundcolor and backgroundcolor ~= "" then
        ctx_tographic(g,"flow_chart_background_color := %q ;",backgroundcolor)
    end
    --
    local shapewidth    = chartsettings.width
    local gridwidth     = shapewidth + 2*chartsettings.dx
    local shapeheight   = chartsettings.height
    local gridheight    = shapeheight + 2*chartsettings.dy
    local chartoffset   = chartsettings.offset
    local labeloffset   = chartsettings.labeloffset
    local exitoffset    = chartsettings.exitoffset
    local commentoffset = chartsettings.commentoffset
    local clipoffset    = chartsettings.clipoffset
    ctx_tographic(g,"flow_grid_width     := %p ;", gridwidth)
    ctx_tographic(g,"flow_grid_height    := %p ;", gridheight)
    ctx_tographic(g,"flow_shape_width    := %p ;", shapewidth)
    ctx_tographic(g,"flow_shape_height   := %p ;", shapeheight)
    ctx_tographic(g,"flow_chart_offset   := %p ;", chartoffset)
    ctx_tographic(g,"flow_label_offset   := %p ;", labeloffset)
    ctx_tographic(g,"flow_exit_offset    := %p ;", exitoffset)
    ctx_tographic(g,"flow_comment_offset := %p ;", commentoffset)
    --
    local radius = settings.line.radius
    local rulethickness = settings.line.rulethickness
    local dx = chartsettings.dx
    local dy = chartsettings.dy
    if radius < rulethickness then
        radius = 2.5*rulethickness
        if radius > dx then
            radius = dx
        end
        if radius > dy then
            radius = dy
        end
    end
    ctx_tographic(g,"flow_connection_line_width  := %p ;", rulethickness)
    ctx_tographic(g,"flow_connection_smooth_size := %p ;", radius)
    ctx_tographic(g,"flow_connection_arrow_size  := %p ;", radius)
    ctx_tographic(g,"flow_connection_dash_size   := %p ;", radius)
    --
    local offset = chartsettings.offset -- todo: pass string
    if offset == v_none or offset == v_overlay or offset == "" then
        offset = -2.5 * radius -- or rulethickness?
    elseif offset == v_standard then
        offset = radius -- or rulethickness?
    end
    ctx_tographic(g,"flow_chart_offset := %p ;",offset)
    ctx_tographic(g,"flow_chart_clip_offset := %p ;",clipoffset)
    --
    ctx_tographic(g,"flow_reverse_y := true ;")
    if chartsettings.option == v_test then
        ctx_tographic(g,"flow_draw_test_shapes ;")
    end
    --
    process_cells(g,chart,0,0)
    process_connections(g,chart,0,0)
    process_texts(g,chart,0,0)
    --
 -- ctx_tographic(g,"clip_chart(%s,%s,%s,%s) ;",x,y,nx,ny) -- todo: draw lines but not shapes
    ctx_tographic(g,"flow_end_chart ;")
    ctx_stopgraphic(g)
    --
end

-- We need to wrap because of tex.runtoks!

local function makechart(chart)
    context.hbox()
    context.bgroup()
    context.forgetall()
    context(function() makechart_indeed(chart) end)
    context.egroup()
end

local function splitchart(chart)
    local settings      = chart.settings
    local splitsettings = settings.split
    local chartsettings = settings.chart
    --
    local name = chartsettings.name
    --
    local from_x = chart.from_x
    local from_y = chart.from_y
    local to_x   = chart.to_x
    local to_y   = chart.to_y
    --
    local step_x  = splitsettings.nx or to_x
    local step_y  = splitsettings.ny or to_y
    local delta_x = splitsettings.dx or 0
    local delta_y = splitsettings.dy or 0
    --
    report_chart("spliting %a from (%s,%s) upto (%s,%s) with steps (%s,%s) and overlap (%s,%s)",
        name,from_x,from_y,to_x,to_y,step_x,step_y,delta_x,delta_y)
    --
    local part_x = 0
    local first_x = from_x
    while true do
        part_x = part_x + 1
        local last_x = first_x + step_x - 1
        local done = last_x >= to_x
        if done then
            last_x = to_x
        end
     -- if first_x >= to_x then
     --     break
     -- end
        local part_y = 0
        local first_y = from_y
        while true do
            part_y = part_y + 1
            local last_y = first_y + step_y - 1
            local done = last_y >= to_y
            if done then
                last_y = to_y
            end
         -- if first_y >= to_y then
         --     break
         -- end
            --
            local data = chart.data
            for i=1,#data do
                local cell = data[i]
            --     inspect(cell)
                local cx, cy = cell.x, cell.y
                if cx >= first_x and cx <= last_x then
                    if cy >= first_y and cy <= last_y then
                        report_chart("part (%s,%s) of %a is split from (%s,%s) -> (%s,%s)",part_x,part_y,name,first_x,first_y,last_x,last_y)
                        local x  = first_x
                        local y  = first_y
                        local nx = last_x - first_x + 1
                        local ny = last_y - first_y + 1
                        context.beforeFLOWsplit()
                        context.handleFLOWsplit(function()
                            makechart(getchart(settings,x,y,nx,ny)) -- we need to pass frozen settings !
                        end)
                        context.afterFLOWsplit()
                        break
                    end
                end
            end
            --
            if done then
                break
            else
                first_y = last_y + 1 - delta_y
            end
        end
        if done then
            break
        else
            first_x = last_x + 1 - delta_x
        end
    end
end

implement {
    name      = "flow_make_chart",
    arguments = {
        {
            { "chart", {
                    { "name" },
                    { "option" },
                    { "backgroundcolor" },
                    { "width", "dimension" },
                    { "height", "dimension" },
                    { "dx", "dimension" },
                    { "dy", "dimension" },
                    { "offset", "dimension" },
                 -- { "bodyfont" },
                    { "dot" },
                    { "hcompact" },
                    { "vcompact" },
                    { "focus" },
                    { "autofocus" },
                    { "nx", "integer" },
                    { "ny", "integer" },
                    { "x", "integer" },
                    { "y", "integer" },
                    { "clipoffset", "dimension" },
                    { "labeloffset", "dimension" },
                    { "commentoffset", "dimension" },
                    { "exitoffset", "dimension" },
                    { "split" },
                },
            },
            { "shape", {
                    { "rulethickness", "dimension" },
                    { "default" },
                    { "framecolor" },
                    { "backgroundcolor" },
                },
            },
            { "focus", {
                    { "rulethickness", "dimension" },
                    { "framecolor" },
                    { "backgroundcolor" },
                },
            },
            { "line", {
                    { "rulethickness", "dimension" },
                    { "radius", "dimension" },
                    { "color" },
                    { "corner" },
                    { "dash" },
                    { "arrow" },
                    { "offset" },
                },
            },
            { "split", {
                    { "nx", "integer" },
                    { "ny", "integer" },
                    { "dx", "integer" },
                    { "dy", "integer" },
                    { "command" },
                    { "marking" },
                    { "before" },
                    { "after" },
                },
            },
         -- { "set" },
        }
    },
    actions   = function(settings)
        local chart = getchart(settings)
        if chart then
            local settings = chart.settings
            if settings then
                local chartsettings = settings.chart
                if chartsettings and chartsettings.split == v_yes then
                    splitchart(chart)
                else
                    makechart(chart)
                end
            else
                makechart(chart)
            end
        end
    end
}
