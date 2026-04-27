if not modules then modules = { } end modules ['mtx-synctex'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Test file:
--
-- \setupsynctex[state=repeat,compress=yes]
--
-- \starttext
--
-- first  line of text on page 1 \blank
-- second line of text on page 1 \page
--
-- first  line of text on page 2 \blank
-- second line of text on page 2 \vfill
-- last   line of text on page 2 \page
--
-- first  line of text on page 3 \blank
-- second line of text on page 3 \vfill
-- last   line of text on page 3 \page
--
-- first  line of text on page 4 \blank
-- second line of text on page 4 \page
--
-- first  line of text on page 5 \blank
-- second line of text on page 5 \page
--
-- \stoptext

-- InverseSearchCmdLine = scite.exe "%f" "-goto:%l" $
-- InverseSearchCmdLine = mtxrun.exe --script synctex --edit --name="%f" --line="%l" $

local tonumber = tonumber
local find, match, gsub, formatters = string.find, string.match, string.gsub, string.formatters
local lower = string.lower
local basename = file.basename
local isfile = lfs.isfile
local max = math.max
local longtostring = string.longtostring

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-synctex</entry>
  <entry name="detail">SyncTeX Checker</entry>
  <entry name="version">1.02</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="edit"><short>open file at line: --line=.. --editor=.. [--tolerance=..] sourcefile</short></flag>
    <flag name="list"><short>show all areas: synctexfile [--content]</short></flag>
    <flag name="goto"><short>open file at position: --page=.. --x=.. --y=.. [--tolerance=..] --editor=.. synctexfile</short></flag>
    <flag name="report"><short>show (tex) file and line: [--direct] --page=.. --x=.. --y=.. [--tolerance=] --console synctexfile</short></flag>
    <flag name="find"><short>find (pdf) page and box: [--direct] [--launch] --file=.. --line=.. synctexfile</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-synctex",
    banner   = "ConTeXt SyncTeX Checker 1.01",
    helpinfo = helpinfo,
}

local report = application.report

local template_show = "page=%i llx=%r lly=%r urx=%r ury=%r"
local template_goto = "filename=%a linenumber=%a tolerance=%a"

local function reportdirect(template,...)
    print(formatters[template](...))
end

local editors = {
    console = function(specification)
        print(string.formatters["%q %i %i"](specification.filename,specification.linenumber or 1,specification.tolerance))
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
    emacs = sandbox.registerrunner {
        name     = "emacs",
        program  = {
            windows = "emacsclient",
            unix    = "emacsclient",
        },
        template = longtostring [[
            -c
            -n
            "+%linenumber%"
            "%filename%"
        ]],
    },
}

local launchers = {
--     console = function(specification)
--         print(string.formatters["%q %i %i"](specification.filename,specification.linenumber or 1,specification.tolerance))
--     end,
    sumatrapdf = sandbox.registerrunner {
        name    = "sumatrapdf",
        program = {
            windows = "sumatrapdf",
            unix    = "sumatrapdf", -- let's assume wine
        },
        template = longtostring [[
            -reuse-instance
            -scroll %h%,%v%
            -page %page%
            -zoom fit-width
            "%filename%"
        ]],
    },
    emacsclient = sandbox.registerrunner {
        name    = "emacsclient",
        program = {
            windows = "emacsclient",
            unix = "emacsclient",
        },
     -- emacsclient -c --eval '(progn (find-file "path/to/file.pdf") (pdf-view-goto-page 10))
        template = longtostring [[
            -c
	    -n
            --eval
            "(progn (find-file \"%filename%\") (pdf-view-goto-page %page%))"
        ]],
    },
    acroread = sandbox.registerrunner {
        name    = "acroread",
        program = {
         -- windows = "maybe",
            unix    = "acroread",
        },
        template = longtostring [[
            -openInNewWindow
            /a
            page=%page%
            "%filename%"
        ]],
    },
}

local function validfile(filename)
    if not filename then
        report("no synctex log file given")
        return false
    elseif not isfile(filename) then
        report("invalid synctex log file %a",filename)
        return false
    elseif file.suffix(filename) == "gz" then
        local data = io.loaddata(filename)
        if data then
            filename = file.removesuffix(filename)
            data = gzip.decompress(data)
            if data then
                io.savedata(filename,data)
             -- report("using uncompressed file %a",filename)
            end
        end
    end
    return filename
end

local function editfile(filename,line,tolerance,editor)
    filename = validfile(filename)
    if not filename then
        return
    end
    local runner = editors[editor or "scite"] or editors.scite
    runner {
        filename   = filename,
        linenumber = tonumber(line) or 1,
        tolerance  = tolerance,
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

local function uncompressfile(filename)
    validfile(filename) -- just this will do
end

local function findlocation(filename,page,xpos,ypos,tolerance)
    filename = validfile(filename)
    if not filename then
        return
    end
    page      = tonumber(page) or 1
    tolerance = tonumber(tolerance) or 0
    xpos      = tonumber(xpos)
    ypos      = tonumber(ypos)
    if not xpos or not ypos then
        report("provide x and y coordinates (unit: basepoints)")
        return
    end
    local files = { }
    local found = false
    local skip  = false
    local fi    = 0
    local ln    = 0
    local tl    = 0
    local lines = { }
    for line in io.lines(filename) do
        if found then
            if find(line,"^}") then
                -- hoist this out of the loop
                local function locate(x,y)
                    local dx = false
                    local dy = false
                    local px = (xpos + x) / factor
                    local py = (ypos + y) / factor
                    for i=1,#lines do
                        local line = lines[i]
                        -- we only look at positive cases
                        local f, l, x, y, w, h, d = match(line,"^[hr](.-),(.-):(.-),(.-):(.-),(.-),(.-)$")
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
                                                return
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
                end
                locate(0,0)
                if fi ~= 0 then
                    return files[fi], ln, 0
                end
                if not tolerance then
                    tolerance = 10
                end
                for s=1,tolerance,max(tolerance//10,1) do
                    locate( s, 0) if fi ~= 0 then tl = s ; goto done end
                    locate(-s, 0) if fi ~= 0 then tl = s ; goto done end
                    locate( s, s) if fi ~= 0 then tl = s ; goto done end
                    locate( s,-s) if fi ~= 0 then tl = s ; goto done end
                    locate(-s, s) if fi ~= 0 then tl = s ; goto done end
                    locate(-s,-s) if fi ~= 0 then tl = s ; goto done end
                    locate( 0, s) if fi ~= 0 then tl = s ; goto done end
                    locate( 0,-s) if fi ~= 0 then tl = s ; goto done end
                end
                break
            else
                lines[#lines+1] = line
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
 ::done::
    if fi ~= 0 then
        return files[fi], ln, tl
    end
end

local function showlocation(filename,sourcename,linenumber,direct,launch)
    filename = validfile(filename)
    if not filename then
        return
    end
    local files      = { }
    local bases      = { }
    local data       = environment.arguments.content and { } or false
    local found      = false
    local page       = 0
    local sourcebase = false
    if sourcename then
        sourcename = file.collapsepath(sourcename)
        sourcename = lower(sourcename)
        sourcebase = basename(sourcename)
    end
    linenumber = tonumber(linenumber)
    for line in io.lines(filename) do
        if found then
            if find(line,"^}") then
                found = false
                if not sourcename then
                    report("end page: %i",page)
                end
            else
                local id, l, x, y, w, h, d = match(line,"^[hr](.-),(.-):(.-),(.-):(.-),(.-),(.-)$")
                if id then
                    x = tonumber(x)
                    y = tonumber(y)
                    l = tonumber(l)
                    local llx = factor * ( x               )
                    local lly = factor * ( y - tonumber(d) )
                    local urx = factor * ( x + tonumber(w) )
                    local ury = factor * ( y + tonumber(h) )
                    local f = files[id]
                    if not f then
                        --
                    elseif not sourcename then
                        local d = data
                        if d then
                            d = d[id]
                            if d then
                                d = d[l]
                            end
                        end
                        if d then
                            report("  [% 4r % 4r % 4r % 4r] : % 5i : %s : %s",llx,lly,urx,ury,l,f,d)
                        else
                            report("  [% 4r % 4r % 4r % 4r] : % 5i : %s",llx,lly,urx,ury,l,f)
                        end
                    elseif (f == sourcename or bases[id] == sourcebase) and l >= linenumber then
                        (direct and reportdirect or report)(template_show,page,llx,lly,urx,ury)
                        if launch then
                            launch = launchers[launch] or launchers["sumatrapdf"]
                            if launch then
                                launch {
                                    h        = math.round(llx - 10),
                                    v        = math.round(lly - 10),
                                    page     = page,
                                    filename = file.replacesuffix(sourcename,"pdf"),
                                }
                            end
                        end
                        return
                    end
                end
            end
        elseif find(line,"^{(%d+)") then
            page  = tonumber(match(line,"^{(%d+)"))
            found = true
            if not sourcename then
                report("begin page: %i",page)
            end
        elseif find(line,"^Input:") then
            local id, name = match(line,"^Input:(.-):(.-)$")
            if id and not files[id] then
                name = lower(name)
                files[id] = name
                bases[id] = basename(name)
                if data then
                    data[id] = string.splitlines(io.loaddata(name) or "")
                end
            end
        end
    end
end

local function gotolocation(filename,page,xpos,ypos,editor,direct,tolerance)
    if filename then
        local target, line, t = findlocation(filename,tonumber(page),tonumber(xpos),tonumber(ypos),tonumber(tolerance))
        if target and line then
            if editor then
                editfile(target,line,t,editor)
            else
                (direct and reportdirect or report)(template_goto,target,line,t)
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
    editfile(filename,argument("line"),argument("tolerance"),argument("editor"))
elseif argument("goto") then
    gotolocation(filename,argument("page"),argument("x"),argument("y"),argument("editor"),argument("direct"),argument("tolerance"))
elseif argument("uncompress") then
    uncompressfile(filename)
elseif argument("report") then
    gotolocation(filename,argument("page"),argument("x"),argument("y"),"console",argument("direct"),argument("tolerance"))
elseif argument("list") then
    showlocation(filename)
elseif argument("find") then
    showlocation(filename,argument("file"),argument("line"),argument("direct"),argument("launch"))
elseif argument("exporthelp") then
    application.export(argument("exporthelp"),filename)
else
    application.help()
end

