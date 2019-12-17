if not modules then modules = { } end modules ['l-pdfview'] = {
    version   = 1.001,
    comment   = "companion to mtx-context.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Todo: add options in cnf file

-- Todo: figure out pdfopen/pdfclose on linux. Calling e.g. okular directly
-- doesn't work in linux when issued from scite as it blocks the editor (no
-- & possible or so). Unfortunately pdfopen keeps changing with not keeping
-- downward compatibility (command line arguments and so).

-- no 2>&1 any more, needs checking on windows

local format, concat = string.format, table.concat

local report  = logs.reporter("pdfview")
local replace = utilities.templates.replace

pdfview = pdfview or { }

local opencalls  -- a table with templates that open a given pdf document
local closecalls -- a table with templates that close a given pdf document
local allcalls   -- a table with templates that close all open pdf documents
local runner     -- runner function
local expander   -- filename cleanup function

if os.type == "windows" then

    -- os.setenv("path",os.getenv("path") .. ";" .. "c:/data/system/pdf-xchange")
    -- os.setenv("path",os.getenv("path") .. ";" .. "c:/data/system/sumatrapdf")

    -- start is more flexible as it locates binaries in more places and doesn't lock

    opencalls = {
        ['default']     = [[pdfopen --rxi --file "%filename%"]],
        ['acrobat']     = [[pdfopen --rxi --file "%filename%"]],
        ['fullacrobat'] = [[pdfopen --axi --file "%filename%"]],
        ['okular']      = [[start "test" okular.exe --unique "%filename%"]],
        ['pdfxcview']   = [[start "test" pdfxcview.exe /A "nolock=yes=OpenParameters" "%filename%"]],
        ['sumatra']     = [[start "test" sumatrapdf.exe -reuse-instance -bg-color 0xCCCCCC "%filename%"]],
        ['auto']        = [[start "" "%filename%"]],
    }
    closecalls= {
        ['default']     = [[pdfclose --file "%filename%"]],
        ['acrobat']     = [[pdfclose --file "%filename%"]],
        ['okular']      = false,
        ['pdfxcview']   = false, -- [[pdfxcview.exe /close:discard "%filename%"]],
        ['sumatra']     = false,
        ['auto']        = false,
    }
    allcalls = {
        ['default']     = [[pdfclose --all]],
        ['acrobat']     = [[pdfclose --all]],
        ['okular']      = false,
        ['pdfxcview']   = false,
        ['sumatra']     = false,
        ['auto']        = false,
    }

    pdfview.method = "acrobat" -- no longer useful due to green pop up line and clashing reader/full
 -- pdfview.method = "pdfxcview"
    pdfview.method = "sumatra"

    runner = function(template,variables)
        local cmd = replace(template,variables)
     -- cmd = cmd  .. " > /null"
        report("command: %s",cmd)
        os.execute(cmd)
    end

    expander = function(name)
        -- We need to avoid issues with chdir to UNC paths and therefore expand
        -- the path when we're current. (We could use one of the helpers instead)
        if file.pathpart(name) == "" then
            return file.collapsepath(file.join(lfs.currentdir(),name))
        else
            return name
        end
    end

else

    opencalls = {
        ['default']   = [[pdfopen "%filename%"]],
        ['okular']    = [[okular --unique "%filename%"]],
        ['sumatra']   = [[wine "sumatrapdf.exe" -reuse-instance -bg-color 0xCCCCCC "%filename%"]],
        ['pdfxcview'] = [[wine "pdfxcview.exe" /A "nolock=yes=OpenParameters" "%filename%"]],
        ['auto']      = [[open "%filename%"]], -- linux: xdg-open
    }
    closecalls= {
        ['default']   = [[pdfclose --file "%filename%"]],
        ['okular']    = false,
        ['sumatra']   = false,
        ['auto']      = false,
    }
    allcalls = {
        ['default']   = [[pdfclose --all]],
        ['okular']    = false,
        ['sumatra']   = false,
        ['auto']      = false,
    }

    pdfview.method = "okular"
    pdfview.method = "sumatra" -- faster and more complete

    runner = function(template,variables)
        local cmd = replace(template,variables)
        cmd = cmd .. " 1>/dev/null 2>/dev/null &"
        report("command: %s",cmd)
        os.execute(cmd)
    end

    expander = function(name)
        return name
    end

end

directives.register("pdfview.method", function(v)
    pdfview.method = (opencalls[v] and v) or 'default'
end)

function pdfview.setmethod(method)
    if method and opencalls[method] then
        pdfview.method = method
    end
end

function pdfview.methods()
    return concat(table.sortedkeys(opencalls), " ")
end

function pdfview.status()
    return format("pdfview methods: %s, current method: %s (directives_pdfview_method)",pdfview.methods(),tostring(pdfview.method))
end

local function fullname(name)
    return file.addsuffix(name,"pdf")
end

function pdfview.open(...)
    local opencall = opencalls[pdfview.method]
    if opencall then
        local t = { ... }
        for i=1,#t do
            local name = expander(fullname(t[i]))
            if io.exists(name) then
                runner(opencall,{ filename = name })
            end
        end
    end
end

function pdfview.close(...)
    local closecall = closecalls[pdfview.method]
    if closecall then
        local t = { ... }
        for i=1,#t do
            local name = expander(fullname(t[i]))
            if io.exists(name) then
                runner(closecall,{ filename = name })
            end
        end
    end
end

function pdfview.closeall()
    local allcall = allcalls[pdfview.method]
    if allcall then
        runner(allcall)
    end
end

return pdfview
