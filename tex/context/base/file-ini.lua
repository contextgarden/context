if not modules then modules = { } end modules ['file-ini'] = {
    version   = 1.001,
    comment   = "companion to file-ini.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>It's more convenient to manipulate filenames (paths) in <l n='lua'/> than in
<l n='tex'/>. These methods have counterparts at the <l n='tex'/> end.</p>
--ldx]]--

resolvers.jobs          = resolvers.jobs or { }

local texsetcount       = tex.setcount

local context_setvalue  = context.setvalue
local commands_doifelse = commands.doifelse

function commands.splitfilename(fullname)
    local t = file.nametotable(fullname)
    local path = t.path
    texsetcount("splitoffkind",(path == "" and 0) or (path == '.' and 1) or 2)
    context_setvalue("splitofffull",fullname)
    context_setvalue("splitoffpath",path)
    context_setvalue("splitoffname",t.name)
    context_setvalue("splitoffbase",t.base)
    context_setvalue("splitofftype",t.suffix)
end

function commands.doifparentfileelse(n)
    commands_doifelse(n == environment.jobname or n == environment.jobname .. '.tex' or n == environment.outputfilename)
end

function commands.doiffileexistelse(name)
    local foundname = resolvers.findtexfile(name)
    commands_doifelse(foundname and foundname ~= "")
end
