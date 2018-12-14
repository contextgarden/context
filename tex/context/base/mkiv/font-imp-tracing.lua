if not modules then modules = { } end modules ['font-imp-tracing'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv and hand-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not context then return end

local next, type = next, type
local concat = table.concat
local formatters = string.formatters

local fonts              = fonts

local handlers           = fonts.handlers
local registerotffeature = handlers.otf.features.register
local registerafmfeature = handlers.afm.features.register

local settings_to_array  = utilities.parsers.settings_to_array
local setmetatableindex  = table.setmetatableindex

local helpers            = fonts.helpers
local appendcommandtable = helpers.appendcommandtable
local prependcommands    = helpers.prependcommands
local charcommand        = helpers.commands.char

local variables          = interfaces.variables

local v_background       = variables.background
local v_frame            = variables.frame
local v_empty            = variables.empty
local v_none             = variables.none

-- for zhichu chen (see mailing list archive): we might add a few more variants
-- in due time
--
-- \definefontfeature[boxed][default][boundingbox=yes] % paleblue
--
-- maybe:
--
-- \definecolor[DummyColor][s=.75,t=.5,a=1] {\DummyColor test} \nopdfcompression
--
-- local gray  = { "pdf", "origin", "/Tr1 gs .75 g" }
-- local black = { "pdf", "origin", "/Tr0 gs 0 g" }

-- boundingbox={yes|background|frame|empty|<color>}

local bp  = number.dimenfactors.bp
local r   = 16384 * bp -- 65536 // 4
local f_1 = formatters["%.6F w 0 %.6F %.6F %.6F re f"]
local f_2 = formatters["[] 0 d 0 J %.6F w %.6F %.6F %.6F %.6F re S"]

-- change this into w h d instead of h d w

local backcache = setmetatableindex(function(t,h)
    local h = h * bp
    local v = setmetatableindex(function(t,d)
        local d = d * bp
        local v = setmetatableindex(function(t,w)
            local v = { "pdf", "origin", f_1(r,-d,w*bp,h+d) }
            t[w] = v
            return v
        end)
        t[d] = v
        return v
    end)
    t[h] = v
    return v
end)

local forecache = setmetatableindex(function(t,h)
    local h = h * bp
    local v = setmetatableindex(function(t,d)
        local d = d * bp
        local v = setmetatableindex(function(t,w)
            -- the frame goes through the boundingbox
            local v = { "pdf", "origin", f_2(r,r/2,-d+r/2,w*bp-r,h+d-r) }
            t[w] = v
            return v
        end)
        t[d] = v
        return v
    end)
    t[h] = v
    return v
end)

local startcolor = nil
local stopcolor  = nil

local function initialize(tfmdata,key,value)
    if value then
        if not backcolors then
            local vfspecials = backends.pdf.tables.vfspecials
            startcolor = vfspecials.startcolor
            stopcolor  = vfspecials.stopcolor
        end
        local characters = tfmdata.characters
        local rulecache  = backcache
        local showchar   = true
        local color      = "palegray"
        if type(value) == "string" then
            value = settings_to_array(value)
            for i=1,#value do
                local v = value[i]
                if v == v_frame then
                    rulecache = forecache
                elseif v == v_background then
                    rulecache = backcache
                elseif v == v_empty then
                    showchar = false
                elseif v == v_none then
                    color = nil
                else
                    color = v
                end
            end
        end
        local gray  = color and startcolor(color) or nil
        local black = gray and stopcolor or nil
        for unicode, character in next, characters do
            local width  = character.width  or 0
            local height = character.height or 0
            local depth  = character.depth  or 0
            local rule   = rulecache[height][depth][width]
            if showchar then
                local commands = character.commands
                if commands then
                    if gray then
                        character.commands = prependcommands (
                            commands, gray, rule, black
                        )
                    else
                        character.commands = prependcommands (
                            commands, rule
                        )
                    end
                else
                    local char = charcommand[unicode]
                    if gray then
                        character.commands = {
                            gray, rule, black, char
                        }
                     else
                        character.commands = {
                            rule, char
                        }
                    end
                end
            else
                if gray then
                    character.commands = {
                        gray, rule, black
                    }
                else
                    character.commands = {
                        rule
                    }
                end
            end
        end
    end
end

local specification = {
    name        = "boundingbox",
    description = "show boundingbox",
    manipulators = {
        base = initialize,
        node = initialize,
    }
}

registerotffeature(specification)
registerafmfeature(specification)

local f_m = formatters["%F %F m"]
local f_l = formatters["%F %F l"]
local f_b = formatters["[] 0 d 0 J %.6F w"]
local f_e = formatters["s"]

local function ladder(list,docolor,nocolor,lst,offset,sign,default)
    local l  = lst[1]
    local x1 = bp * (offset + l.kern) * sign
    local y1 = bp * l.height
    local t  = { f_b(r,r/2), f_m(x1,y1) }
    local n  = 2
    local m  = #lst
    if default > 0 then
        default = default * bp + r
    else
        default = default * bp - r
    end
    if m == 1 then
        n = n + 1 t[n] = f_l(x1,default)
    else
        for i=1,m do
            local l  = lst[i]
            local x2 = bp * (offset + l.kern) * sign
            local y2 = bp * l.height
            if i > 1 and y2 == 0 then
                y2 = default
            end
            n = n + 1 t[n] = f_l(x2,y1)
            n = n + 1 t[n] = f_l(x2,y2)
            x1, y1 = x2, y2
        end
    end
    n = n + 1 t[n] = f_e()
    list[#list+1] = docolor
    list[#list+1] = { "pdf", "origin", concat(t," ") }
    list[#list+1] = nocolor
end

local function initialize(tfmdata,key,value)
    if value then
        if not backcolors then
            local vfspecials = backends.pdf.tables.vfspecials
            startcolor = vfspecials.startcolor
            stopcolor  = vfspecials.stopcolor
        end
        local characters = tfmdata.characters
        local brcolor    = startcolor("darkred")
        local trcolor    = startcolor("darkgreen")
        local blcolor    = startcolor("darkblue")
        local tlcolor    = startcolor("darkyellow")
        local black      = stopcolor
        for unicode, character in next, characters do
            local mathkern = character.mathkern
            if mathkern then
                -- more efficient would be co collect more in one pdf
                -- directive but this is hardly used so not worth the
                -- effort
                local width  = character.width  or 0
                local height = character.height or 0
                local depth  = character.depth  or 0
                local list   = { }
                local br     = mathkern.bottom_right
                local tr     = mathkern.top_right
                local bl     = mathkern.bottom_left
                local tl     = mathkern.top_left
                if br then
                    ladder(list,brcolor,black,br,width,1,height)
                end
                if tr then
                    ladder(list,trcolor,black,tr,width,1,-depth)
                end
                if bl then
                    ladder(list,blcolor,black,bl,0,-1,height)
                end
                if tl then
                    ladder(list,tlcolor,black,tl,0,-1,-depth)
                end
                if #list > 0 then
                    local commands = character.commands
                    if commands then
                        character.commands = appendcommandtable(commands,list)
                    else
                        list[#list+1] = charcommand[unicode]
                        character.commands = list
                    end
                end
            end
        end
    end
end

local specification = {
    name        = "staircase",
    description = "show staircase kerns",
    position=1,
    manipulators = {
        base = initialize,
        node = initialize,
    }
}

registerotffeature(specification)
registerafmfeature(specification)
