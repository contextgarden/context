if not modules then modules = { } end modules ['lxml-ini'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local xml  = xml
local lxml = lxml

-- this defines an extra scanner lxmlid:

local scanners   = tokens.scanners
local scanstring = scanners.string
local getid      = lxml.id

scanners.lxmlid  = function() return getid(scanstring()) end

local implement  = interfaces.implement

-- lxml.id

implement { name = "lxmlid",                  actions = lxml.getid,             arguments = "string" }

implement { name = "xmldoif",                 actions = lxml.doif,              arguments = { "string", "string" } }
implement { name = "xmldoifnot",              actions = lxml.doifnot,           arguments = { "string", "string" } }
implement { name = "xmldoifelse",             actions = lxml.doifelse,          arguments = { "string", "string" } }
implement { name = "xmldoiftext",             actions = lxml.doiftext,          arguments = { "string", "string" } }
implement { name = "xmldoifnottext",          actions = lxml.doifnottext,       arguments = { "string", "string" } }
implement { name = "xmldoifelsetext",         actions = lxml.doifelsetext,      arguments = { "string", "string" } }

implement { name = "xmldoifempty",            actions = lxml.doifempty,         arguments = { "string", "string" } }
implement { name = "xmldoifnotempty",         actions = lxml.doifnotempty,      arguments = { "string", "string" } }
implement { name = "xmldoifelseempty",        actions = lxml.doifelseempty,     arguments = { "string", "string" } }
implement { name = "xmldoifselfempty",        actions = lxml.doifempty,         arguments = "string" }
implement { name = "xmldoifnotselfempty",     actions = lxml.doifnotempty,      arguments = "string" }
implement { name = "xmldoifelseselfempty",    actions = lxml.doifelseempty,     arguments = "string" }

--------- { name = "xmlcontent",              actions = lxml.content,           arguments = "string" }
--------- { name = "xmlflushstripped",        actions = lxml.strip,             arguments = { "string", true } }
implement { name = "xmlall",                  actions = lxml.all,               arguments = { "string", "string" } }
implement { name = "xmlatt",                  actions = lxml.att,               arguments = { "string", "string" } }
implement { name = "xmlattdef",               actions = lxml.att,               arguments = { "string", "string", "string" } }
implement { name = "xmlattribute",            actions = lxml.attribute,         arguments = { "string", "string", "string" } }
implement { name = "xmlattributedef",         actions = lxml.attribute,         arguments = { "string", "string", "string", "string" } }
implement { name = "xmlchainatt",             actions = lxml.chainattribute,    arguments = { "string", "'/'", "string" } }
implement { name = "xmlchainattdef",          actions = lxml.chainattribute,    arguments = { "string", "'/'", "string", "string"  } }
implement { name = "xmlrefatt",               actions = lxml.refatt,            arguments = { "string", "string" } }
implement { name = "xmlchecknamespace",       actions =  xml.checknamespace,    arguments = { "lxmlid", "string", "string" } }
implement { name = "xmlcommand",              actions = lxml.command,           arguments = { "string", "string", "string" } }
implement { name = "xmlconcat",               actions = lxml.concat,            arguments = { "string", "string", "string" } }                     --  \detokenize{#3}
implement { name = "xmlconcatrange",          actions = lxml.concatrange,       arguments = { "string", "string", "string", "string", "string" } } --  \detokenize{#5}
implement { name = "xmlcontext",              actions = lxml.context,           arguments = { "string", "string" } }
implement { name = "xmlcount",                actions = lxml.count,             arguments = { "string", "string" } }
implement { name = "xmldelete",               actions = lxml.delete,            arguments = { "string", "string" } }
implement { name = "xmldirect",               actions = lxml.direct,            arguments = "string" }
implement { name = "xmldirectives",           actions = lxml.directives.setup,  arguments = "string" }
implement { name = "xmldirectivesafter",      actions = lxml.directives.after,  arguments = "string" }
implement { name = "xmldirectivesbefore",     actions = lxml.directives.before, arguments = "string" }
implement { name = "xmldisplayverbatim",      actions = lxml.displayverbatim,   arguments = "string" }
implement { name = "xmlelement",              actions = lxml.element,           arguments = { "string", "string" } } -- could be integer but now we can alias
implement { name = "xmlfilter",               actions = lxml.filter,            arguments = { "string", "string" } }
implement { name = "xmlfilterlist",           actions = lxml.filterlist,        arguments = { "string", "string" } }
implement { name = "xmlfirst",                actions = lxml.first,             arguments = { "string", "string" } }
implement { name = "xmlflush",                actions = lxml.flush,             arguments = "string" }
implement { name = "xmlflushcontext",         actions = lxml.context,           arguments = "string" }
implement { name = "xmlflushlinewise",        actions = lxml.flushlinewise,     arguments = "string" }
implement { name = "xmlflushspacewise",       actions = lxml.flushspacewise,    arguments = "string" }
implement { name = "xmlfunction",             actions = lxml.applyfunction,     arguments = { "string", "string" } }
implement { name = "xmlinclude",              actions = lxml.include,           arguments = { "string", "string", "string", true } }
implement { name = "xmlincludeoptions",       actions = lxml.include,           arguments = { "string", "string", "string", "string" } }
implement { name = "xmlinclusion",            actions = lxml.inclusion,         arguments = "string" }
implement { name = "xmlinclusions",           actions = lxml.inclusions,        arguments = "string" }
implement { name = "xmlbadinclusions",        actions = lxml.badinclusions,     arguments = "string" }
implement { name = "xmlindex",                actions = lxml.index,             arguments = { "string", "string", "string" } } -- can be integer but now we can alias
implement { name = "xmlinfo",                 actions = lxml.info,              arguments = "string" }
implement { name = "xmlinlineverbatim",       actions = lxml.inlineverbatim,    arguments = "string" }
implement { name = "xmllast",                 actions = lxml.last,              arguments = "string" }
implement { name = "xmlload",                 actions = lxml.load,              arguments = { "string", "string", "string", "string" } }
implement { name = "xmlloadbuffer",           actions = lxml.loadbuffer,        arguments = { "string", "string", "string", "string" } }
implement { name = "xmlloaddata",             actions = lxml.loaddata,          arguments = { "string", "string", "string", "string" } }
implement { name = "xmlloaddirectives",       actions = lxml.directives.load,   arguments = "string" }
implement { name = "xmlloadregistered",       actions = lxml.loadregistered,    arguments = { "string", "string", "string" } }
implement { name = "xmlmain",                 actions = lxml.main,              arguments = "string" }
implement { name = "xmlmatch",                actions = lxml.match,             arguments = "string" }
implement { name = "xmlname",                 actions = lxml.name,              arguments = "string" }
implement { name = "xmlnamespace",            actions = lxml.namespace,         arguments = "string" }
implement { name = "xmlnonspace",             actions = lxml.nonspace,          arguments = { "string", "string" } }
implement { name = "xmlpos",                  actions = lxml.pos,               arguments = "string" }
implement { name = "xmlraw",                  actions = lxml.raw,               arguments = { "string", "string" } }
implement { name = "xmlregisterns",           actions =  xml.registerns,        arguments = { "string", "string" } }
implement { name = "xmlremapname",            actions =  xml.remapname,         arguments = { "lxmlid", "string","string","string" } }
implement { name = "xmlremapnamespace",       actions =  xml.renamespace,       arguments = { "lxmlid", "string", "string" } }
implement { name = "xmlsave",                 actions = lxml.save,              arguments = { "string", "string" } }
implement { name = "xmlsetfunction",          actions = lxml.setaction,         arguments = { "string", "string", "string" } }
implement { name = "xmlsetsetup",             actions = lxml.setsetup,          arguments = { "string", "string", "string" } }
implement { name = "xmlsnippet",              actions = lxml.snippet,           arguments = { "string", "string" } }
implement { name = "xmlstrip",                actions = lxml.strip,             arguments = { "string", "string" } }
implement { name = "xmlstripanywhere",        actions = lxml.strip,             arguments = { "string", "string", true, true } }
implement { name = "xmlstripnolines",         actions = lxml.strip,             arguments = { "string", "string", true } }
implement { name = "xmlstripped",             actions = lxml.stripped,          arguments = { "string", "string" } }
implement { name = "xmlstrippednolines",      actions = lxml.stripped,          arguments = { "string", "string", true } }
implement { name = "xmltag",                  actions = lxml.tag,               arguments = "string" }
implement { name = "xmltext",                 actions = lxml.text,              arguments = { "string", "string" } }
implement { name = "xmltobuffer",             actions = lxml.tobuffer,          arguments = { "string", "string", "string" } }
implement { name = "xmltobufferverbose",      actions = lxml.tobuffer,          arguments = { "string", "string", "string", true } }
implement { name = "xmltofile",               actions = lxml.tofile,            arguments = { "string", "string", "string" } }
implement { name = "xmltoparameters",         actions = lxml.toparameters,      arguments = "string" }
implement { name = "xmlverbatim",             actions = lxml.verbatim,          arguments = "string" }

implement { name = "xmlstartraw",             actions = lxml.startraw }
implement { name = "xmlstopraw",              actions = lxml.stopraw  }

implement { name = "xmlprependsetup",         actions = lxml.installsetup,      arguments = { 1, "string", "string" } }           -- 2:*
implement { name = "xmlappendsetup",          actions = lxml.installsetup,      arguments = { 2, "string", "string" } }           -- 2:*
implement { name = "xmlbeforesetup",          actions = lxml.installsetup,      arguments = { 3, "string", "string", "string" } } -- 2:*
implement { name = "xmlaftersetup",           actions = lxml.installsetup,      arguments = { 4, "string", "string", "string" } } -- 2:*
implement { name = "xmlprependdocumentsetup", actions = lxml.installsetup,      arguments = { 1, "string", "string" } }
implement { name = "xmlappenddocumentsetup",  actions = lxml.installsetup,      arguments = { 2, "string", "string" } }
implement { name = "xmlbeforedocumentsetup",  actions = lxml.installsetup,      arguments = { 3, "string", "string", "string" } }
implement { name = "xmlafterdocumentsetup",   actions = lxml.installsetup,      arguments = { 4, "string", "string" } }
implement { name = "xmlremovesetup",          actions = lxml.removesetup,       arguments = { "string", "string" } }              -- 1:*
implement { name = "xmlremovedocumentsetup",  actions = lxml.removesetup,       arguments = { "string", "string" } }
implement { name = "xmlflushdocumentsetups",  actions = lxml.flushsetups,       arguments = { "string", "string", "string" } }    -- 2:*
implement { name = "xmlresetdocumentsetups",  actions = lxml.resetsetups,       arguments = "string" }

implement { name = "xmlgetindex",             actions = lxml.getindex,          arguments = { "string", "string" } }
implement { name = "xmlwithindex",            actions = lxml.withindex,         arguments = { "string", "string", "string" } }

implement { name = "xmlsetentity",            actions =  xml.registerentity,    arguments = { "string", "string" } }
implement { name = "xmltexentity",            actions = lxml.registerentity,    arguments = { "string", "string" } }

implement { name = "xmlsetcommandtotext",     actions = lxml.setcommandtotext,  arguments = "string" }
implement { name = "xmlsetcommandtonone",     actions = lxml.setcommandtonone,  arguments = "string" }

implement { name = "xmlstarttiming",          actions = function() statistics.starttiming(lxml) end }
implement { name = "xmlstoptiming",           actions = function() statistics.stoptiming (lxml) end }
