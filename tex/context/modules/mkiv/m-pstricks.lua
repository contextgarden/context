if not modules then modules = { } end modules ['m-pstricks'] = {
    version   = 1.001,
    comment   = "companion to m-pstricks.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The following will be done when I need ps tricks figures
-- in large quantities:
--
-- + hash graphics and only process them once
-- + save md5 checksums in tuc file
--
-- It's no big deal but has a low priority.

local format, lower, concat, gmatch = string.format, string.lower, table.concat, string.gmatch
local variables = interfaces.variables

moduledata.pstricks = moduledata.pstricks or { }

local report_pstricks = logs.reporter("pstricks")

local template = [[
\starttext
    \pushcatcodetable
    \setcatcodetable\texcatcodes
    \usemodule[pstric]
    %s
    \popcatcodetable
    \startTEXpage
        \hbox\bgroup
            \ignorespaces
            %s
            \removeunwantedspaces
        \egroup
        \obeydepth %% temp hack as we need to figure this out
    \stopTEXpage
\stoptext
]]

local loaded   = { }
local graphics = 0

function moduledata.pstricks.usemodule(names)
    for name in gmatch(names,"([^%s,]+)") do
        loaded[#loaded+1] = format([[\readfile{%s}{}{}]],name)
    end
end

function moduledata.pstricks.process(n)
    graphics = graphics + 1
    local name = format("%s-pstricks-%04i",tex.jobname,graphics)
    local data = buffers.collectcontent("def-"..n)
    local tmpfile = name .. ".tmp"
    local epsfile = name .. ".ps"
    local pdffile = name .. ".pdf"
    local loaded = concat(loaded,"\n")
    os.remove(epsfile)
    os.remove(pdffile)
    io.savedata(tmpfile,format(template,loaded,data))
    os.execute(format("mtxrun --script texexec %s --once --dvips",tmpfile))
    if lfs.isfile(epsfile) then
        os.execute(format("ps2pdf %s %s",epsfile,pdffile))
        -- todo: direct call but not now
        if lfs.isfile(pdffile) then
            context.externalfigure( { pdffile }, { object = variables.no } )
        else
            report_pstricks("run failed, no pdf file")
        end
    else
        report_pstricks("run failed, no ps file")
    end
end
