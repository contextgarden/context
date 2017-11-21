if not modules then modules = { } end modules ['mtx-synctex'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- InverseSearchCmdLine = scite.exe "%f" "-goto:%l" $
-- InverseSearchCmdLine = mtxrun.exe --script synctex --edit --name="%f" --line="%l" $

local tonumber = tonumber
local find, match, gsub = string.find, string.match, string.gsub
local isfile = lfs.isfile
local longtostring = string.longtostring

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-synctex</entry>
  <entry name="detail">SyncTeX Checker</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="edit"><short>open file at line: --line=.. --editor=.. sourcefile</short></flag>
    <flag name="list"><short>show blob: synctexfile</short></flag>
    <flag name="goto"><short>open file at position: --page=.. --x=.. --y=.. --editor=.. synctexfile</short></flag>
    <flag name="report"><short>show file and line: --page=.. --x=.. --y=.. --console synctexfile</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-synctex",
    banner   = "ConTeXt SyncTeX Checker 1.00",
    helpinfo = helpinfo,
}

local report = application.report

local editors = {
    console = function(specification)
        print(string.formatters["%q %i"](specification.filename,specification.linenumber or 1))
    end,
    scite = sandbox.registerrunner {
        name     = "scite",
        program  = {
            windows = "scite",
            unix    = "SciTE",
        },
        template = longtostring [[
            "%filename%"
            "-goto:%linenumber%"
        ]],
    },
}

local function validfile(filename)
    if not filename or not isfile(filename) then
        report("invalid synctex log file %a",filename)
        return false
    else
        return true
    end
end

local function editfile(filename,line,editor)
    if not validfile(filename) then
        return
    end
    local runner = editors[editor or "scite"] or editors.scite
    runner {
        filename   = filename,
        linenumber = tonumber(line) or 1,
    }
end

-- In context we only care about explicitly marked horizontal blobs. And this is
-- only a check script. I know of no viewer that calls the synctex command line
-- version. Otherwise we could provide our own simplified variant and even
-- consider a more compact format (for instance we could use an "=" when the value
-- of x y w h d is the same as before, which is actually often the case for y, h
-- and d).

local factor = (7200/7227)/65536 -- we assume unit 1
local quit   = true              -- we only have one hit anyway

local function findlocation(filename,page,xpos,ypos)
    if not validfile(filename) then
        return
    elseif not page then
        page = 1
    elseif not xpos or not ypos then
        report("provide x and y coordinates (unit: basepoints)")
        return
    end
    local files = { }
    local found = false
    local skip  = false
    local dx    = false
    local dy    = false
    local px    = xpos / factor
    local py    = ypos / factor
    local fi    = 0
    local ln    = 0
    for line in io.lines(filename) do
        if found then
            if find(line,"^}") then
                break
            else
                -- we only look at positive cases
                local f, l, x, y, w, h, d = match(line,"^h(.-),(.-):(.-),(.-):(.-),(.-),(.-)$")
                if f and f ~= 0 then
                    x = tonumber(x)
                    if px >= x then
                        w = tonumber(w)
                        if px <= x + w then
                            y = tonumber(y)
                            d = tonumber(d)
                            if py >= y - d then
                                h = tonumber(h)
                                if py <= y + h then
                                    if quit then
                                        -- we have no overlapping boxes
                                        fi = f
                                        ln = l
                                        break
                                    else
                                        local lx = px - x
                                        local rx = x + w - px
                                        local by = py - y + d
                                        local ty = y + h - py
                                        mx = lx < rx and lx or rx
                                        my = by < ty and by or ty
                                        if not dx then
                                            dx = mx
                                            dy = my
                                            fi = f
                                            ln = l
                                        else
                                            if mx < dx then
                                                dx = mx
                                                di = f
                                                ln = l
                                            end
                                            if my < dy then
                                                dy = my
                                                fi = f
                                                ln = l
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        elseif skip then
            if find(line,"^}") then
                skip = false
            end
        elseif find(line,"^{(%d+)") then
            local p = tonumber(match(line,"^{(%d+)"))
            if p == page then
                found = true
            else
                skip = true
            end
        elseif find(line,"^Input:") then
            local id, name = match(line,"^Input:(.-):(.-)$")
            if id then
                files[id] = name
            end
        end
    end
    if fi ~= 0 then
        return files[fi], ln
    end
end

local function showlocation(filename)
    if not validfile(filename) then
        return
    end
    local files = { }
    local found = false
    local page  = 0
    for line in io.lines(filename) do
        if found then
            if find(line,"^}") then
                found = false
                report("end page: %i",page)
            else
                local f, l, x, y, w, h, d = match(line,"^h(.-),(.-):(.-),(.-):(.-),(.-),(.-)$")
                if f then
                    x = tonumber(x)
                    y = tonumber(y)
                    local llx = factor * ( x               )
                    local lly = factor * ( y - tonumber(d) )
                    local urx = factor * ( x + tonumber(w) )
                    local ury = factor * ( y + tonumber(h) )
                    f = files[f]
                    if f then
                        report("  [% 4r % 4r % 4r % 4r] : % 5i : %s",llx,lly,urx,ury,l,f)
                    end
                end
            end
        elseif find(line,"^{(%d+)") then
            page  = tonumber(match(line,"^{(%d+)"))
            found = true
            report("begin page: %i",page)
        elseif find(line,"^Input:") then
            local id, name = match(line,"^Input:(.-):(.-)$")
            if id then
                files[id] = name
            end
        end
    end
end

local function gotolocation(filename,page,xpos,ypos,editor)
    if filename then
        local target, line = findlocation(filename,tonumber(page),tonumber(xpos),tonumber(ypos))
        if target and line then
            if editor then
                editfile(target,line,editor)
            else
                report("filename=%a linenumber=%a",target,line)
            end
        end
    end
end

-- print(findlocation("oeps.synctex",4,318,348))
-- print(findlocation("oeps.synctex",40,378,348))
-- print(gotolocation("oeps.synctex",4,318,348,"scite"))
-- print(showlocation("oeps.synctex"))

local argument = environment.argument
local filename = environment.files[1]

if argument("edit") then
    editfile(filename,argument("line"),argument("editor"))
elseif argument("goto") then
    gotolocation(filename,argument("page"),argument("x"),argument("y"),argument("editor"))
elseif argument("report") then
    gotolocation(filename,argument("page"),argument("x"),argument("y"),"console")
elseif argument("list") then
    showlocation(filename)
elseif argument("exporthelp") then
    application.export(argument("exporthelp"),filename)
else
    application.help()
end

