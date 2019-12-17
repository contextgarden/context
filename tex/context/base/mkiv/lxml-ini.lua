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

implement { name = "lxmlid",               actions = lxml.getid,             arguments = "string" }

implement { name = "xmldoif",              actions = lxml.doif,              arguments = "2 strings" }
implement { name = "xmldoifnot",           actions = lxml.doifnot,           arguments = "2 strings" }
implement { name = "xmldoifelse",          actions = lxml.doifelse,          arguments = "2 strings" }
implement { name = "xmldoiftext",          actions = lxml.doiftext,          arguments = "2 strings" }
implement { name = "xmldoifnottext",       actions = lxml.doifnottext,       arguments = "2 strings" }
implement { name = "xmldoifelsetext",      actions = lxml.doifelsetext,      arguments = "2 strings" }

implement { name = "xmldoifempty",         actions = lxml.doifempty,         arguments = "2 strings" }
implement { name = "xmldoifnotempty",      actions = lxml.doifnotempty,      arguments = "2 strings" }
implement { name = "xmldoifelseempty",     actions = lxml.doifelseempty,     arguments = "2 strings" }
implement { name = "xmldoifselfempty",     actions = lxml.doifempty,         arguments = "string" } -- second arg is not passed (used)
implement { name = "xmldoifnotselfempty",  actions = lxml.doifnotempty,      arguments = "string" } -- second arg is not passed (used)
implement { name = "xmldoifelseselfempty", actions = lxml.doifelseempty,     arguments = "string" } -- second arg is not passed (used)

--------- { name = "xmlcontent",           actions = lxml.content,           arguments = "string" }
--------- { name = "xmlflushstripped",     actions = lxml.strip,             arguments = { "string", true } }

implement { name = "xmlall",               actions = lxml.all,               arguments = "2 strings" }
implement { name = "xmlatt",               actions = lxml.att,               arguments = "2 strings" }
implement { name = "xmlattdef",            actions = lxml.att,               arguments = "3 strings" }
implement { name = "xmlattribute",         actions = lxml.attribute,         arguments = "3 strings" }
implement { name = "xmlattributedef",      actions = lxml.attribute,         arguments = "4 strings" }
implement { name = "xmlbadinclusions",     actions = lxml.badinclusions,     arguments = "string" }
implement { name = "xmlchainatt",          actions = lxml.chainattribute,    arguments = { "string", "'/'", "string" } }
implement { name = "xmlchainattdef",       actions = lxml.chainattribute,    arguments = { "string", "'/'", "string", "string"  } }
implement { name = "xmlchecknamespace",    actions =  xml.checknamespace,    arguments = { "lxmlid", "string", "string" } }
implement { name = "xmlcommand",           actions = lxml.command,           arguments = "3 strings" }
implement { name = "xmlconcat",            actions = lxml.concat,            arguments = "3 strings" }                     --  \detokenize{#3}
implement { name = "xmlconcatrange",       actions = lxml.concatrange,       arguments = { "string", "string", "string", "string", "string" } } --  \detokenize{#5}
implement { name = "xmlcontext",           actions = lxml.context,           arguments = "2 strings" }
implement { name = "xmlcount",             actions = lxml.count,             arguments = "2 strings" }
implement { name = "xmldelete",            actions = lxml.delete,            arguments = "2 strings" }
implement { name = "xmldirect",            actions = lxml.direct,            arguments = "string" }
implement { name = "xmldirectives",        actions = lxml.directives.setup,  arguments = "string" }
implement { name = "xmldirectivesafter",   actions = lxml.directives.after,  arguments = "string" }
implement { name = "xmldirectivesbefore",  actions = lxml.directives.before, arguments = "string" }
implement { name = "xmldisplayverbatim",   actions = lxml.displayverbatim,   arguments = "string" }
implement { name = "xmlelement",           actions = lxml.element,           arguments = "2 strings" } -- could be integer but now we can alias
implement { name = "xmlfilter",            actions = lxml.filter,            arguments = "2 strings" }
implement { name = "xmlfilterlist",        actions = lxml.filterlist,        arguments = "2 strings" }
implement { name = "xmlfirst",             actions = lxml.first,             arguments = "2 strings" }
implement { name = "xmlflush",             actions = lxml.flush,             arguments = "string" }
implement { name = "xmlflushcontext",      actions = lxml.context,           arguments = "string" }
implement { name = "xmlflushlinewise",     actions = lxml.flushlinewise,     arguments = "string" }
implement { name = "xmlflushpure",         actions = lxml.pure,              arguments = "string" }
implement { name = "xmlflushspacewise",    actions = lxml.flushspacewise,    arguments = "string" }
implement { name = "xmlflushtext",         actions = lxml.text,              arguments = "string" }
implement { name = "xmlfunction",          actions = lxml.applyfunction,     arguments = "2 strings" }
implement { name = "xmlinclude",           actions = lxml.include,           arguments = { "string", "string", "string", true } }
implement { name = "xmlincludeoptions",    actions = lxml.include,           arguments = "4 strings" }
implement { name = "xmlinclusion",         actions = lxml.inclusion,         arguments = "string" }
implement { name = "xmlinclusionbase",     actions = lxml.inclusion,         arguments = { "string", false, true } }
implement { name = "xmlinclusions",        actions = lxml.inclusions,        arguments = "string" }
implement { name = "xmlindex",             actions = lxml.index,             arguments = "3 strings" } -- can be integer but now we can alias
implement { name = "xmlinlineverbatim",    actions = lxml.inlineverbatim,    arguments = "string" }
implement { name = "xmllast",              actions = lxml.last,              arguments = "2 strings" }
implement { name = "xmllastatt",           actions = lxml.lastatt }
implement { name = "xmllastmatch",         actions = lxml.lastmatch }
implement { name = "xmllastpar",           actions = lxml.lastpar }
implement { name = "xmlloadfile",          actions = lxml.load,              arguments = "3 strings" }
implement { name = "xmlloadbuffer",        actions = lxml.loadbuffer,        arguments = "3 strings" }
implement { name = "xmlloaddata",          actions = lxml.loaddata,          arguments = "3 strings" }
implement { name = "xmlloaddirectives",    actions = lxml.directives.load,   arguments = "string" }
implement { name = "xmlmain",              actions = lxml.main,              arguments = "string" }
implement { name = "xmlmatch",             actions = lxml.match,             arguments = "string" }
implement { name = "xmlname",              actions = lxml.name,              arguments = "string" }
implement { name = "xmlnamespace",         actions = lxml.namespace,         arguments = "string" }
implement { name = "xmlnonspace",          actions = lxml.nonspace,          arguments = "2 strings" }
implement { name = "xmlpar",               actions = lxml.par,               arguments = "2 strings" }
implement { name = "xmlparam",             actions = lxml.param,             arguments = "3 strings" }
implement { name = "xmlpath",              actions = lxml.path,              arguments = { "string", "'/'" } }
implement { name = "xmlpopmatch",          actions = lxml.popmatch }
implement { name = "xmlpos",               actions = lxml.pos,               arguments = "string" }
implement { name = "xmlpure",              actions = lxml.pure,              arguments = "2 strings" }
implement { name = "xmlpushmatch",         actions = lxml.pushmatch }
implement { name = "xmlraw",               actions = lxml.raw,               arguments = "2 strings" }
implement { name = "xmlrawtex",            actions = lxml.rawtex,            arguments = "2 strings" }
implement { name = "xmlrefatt",            actions = lxml.refatt,            arguments = "2 strings" }
implement { name = "xmlregisterns",        actions =  xml.registerns,        arguments = "2 strings" }
implement { name = "xmlremapname",         actions =  xml.remapname,         arguments = { "lxmlid", "string","string","string" } }
implement { name = "xmlremapnamespace",    actions =  xml.renamespace,       arguments = { "lxmlid", "string", "string" } }
implement { name = "xmlsave",              actions = lxml.save,              arguments = "2 strings" }
implement { name = "xmlsetatt",            actions = lxml.setatt,            arguments = "3 strings" }
implement { name = "xmlsetattribute",      actions = lxml.setattribute,      arguments = "4 strings" }
implement { name = "xmlsetpar",            actions = lxml.setpar,            arguments = "3 strings" }
implement { name = "xmlsetparam",          actions = lxml.setparam,          arguments = "4 strings" }
implement { name = "xmlsetsetup",          actions = lxml.setsetup,          arguments = "3 strings" }
implement { name = "xmlsnippet",           actions = lxml.snippet,           arguments = "2 strings" }
implement { name = "xmlstrip",             actions = lxml.strip,             arguments = "2 strings" }
implement { name = "xmlstripanywhere",     actions = lxml.strip,             arguments = { "string", "string", true, true } }
implement { name = "xmlstripnolines",      actions = lxml.strip,             arguments = { "string", "string", true } }
implement { name = "xmlstripped",          actions = lxml.stripped,          arguments = "2 strings" }
implement { name = "xmlstrippednolines",   actions = lxml.stripped,          arguments = { "string", "string", true } }
implement { name = "xmltag",               actions = lxml.tag,               arguments = "string" }
implement { name = "xmltext",              actions = lxml.text,              arguments = "2 strings" }
implement { name = "xmltobuffer",          actions = lxml.tobuffer,          arguments = "3 strings" }
implement { name = "xmltobuffertextonly",  actions = lxml.tobuffer,          arguments = { "string", "string", "string", false } }
implement { name = "xmltobufferverbose",   actions = lxml.tobuffer,          arguments = { "string", "string", "string", true, true } }
implement { name = "xmltofile",            actions = lxml.tofile,            arguments = "3 strings" }
implement { name = "xmltoparameters",      actions = lxml.toparameters,      arguments = "string" }
implement { name = "xmlverbatim",          actions = lxml.verbatim,          arguments = "string" }

implement { name = "xmlstartraw",          actions = lxml.startraw }
implement { name = "xmlstopraw",           actions = lxml.stopraw  }

implement { name = "xmlprependsetup",      actions = lxml.installsetup,      arguments = { 1, "string", "string" } }           -- 2:*
implement { name = "xmlappendsetup",       actions = lxml.installsetup,      arguments = { 2, "string", "string" } }           -- 2:*
implement { name = "xmlbeforesetup",       actions = lxml.installsetup,      arguments = { 3, "string", "string", "string" } } -- 2:*
implement { name = "xmlaftersetup",        actions = lxml.installsetup,      arguments = { 4, "string", "string", "string" } } -- 2:*
implement { name = "xmlremovesetup",       actions = lxml.removesetup,       arguments = "2 strings" }              -- 1:*
implement { name = "xmlflushsetups",       actions = lxml.flushsetups,       arguments = "3 strings" }    -- 2:*
implement { name = "xmlresetsetups",       actions = lxml.resetsetups,       arguments = "string" }

implement { name = "xmlgetindex",          actions = lxml.getindex,          arguments = "2 strings" }
implement { name = "xmlwithindex",         actions = lxml.withindex,         arguments = "3 strings" }

implement { name = "xmlsetentity",         actions =  xml.registerentity,    arguments = "2 strings" }
implement { name = "xmltexentity",         actions = lxml.registerentity,    arguments = "2 strings" }

implement { name = "xmlsetcommandtotext",  actions = lxml.setcommandtotext,  arguments = "string" }
implement { name = "xmlsetcommandtonone",  actions = lxml.setcommandtonone,  arguments = "string" }

implement { name = "xmlstarttiming",       actions = function() statistics.starttiming(lxml) end }
implement { name = "xmlstoptiming",        actions = function() statistics.stoptiming (lxml) end }

implement { name = "xmlloadentities",      actions = characters.registerentities, onceonly = true }

-- kind of special (3rd argument is a function)

commands.xmlsetfunction = lxml.setaction
