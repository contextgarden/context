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

implement { name = "lxmlid",               public = true, actions = lxml.getid,             arguments = "string" }

implement { name = "xmldoif",              public = true, actions = lxml.doif,              arguments = "2 strings" }
implement { name = "xmldoifnot",           public = true, actions = lxml.doifnot,           arguments = "2 strings" }
implement { name = "xmldoifelse",          public = true, actions = lxml.doifelse,          arguments = "2 strings" }
implement { name = "xmldoiftext",          public = true, actions = lxml.doiftext,          arguments = "2 strings" }
implement { name = "xmldoifnottext",       public = true, actions = lxml.doifnottext,       arguments = "2 strings" }
implement { name = "xmldoifelsetext",      public = true, actions = lxml.doifelsetext,      arguments = "2 strings" }

implement { name = "xmldoifempty",         public = true, actions = lxml.doifempty,         arguments = "2 strings" }
implement { name = "xmldoifnotempty",      public = true, actions = lxml.doifnotempty,      arguments = "2 strings" }
implement { name = "xmldoifelseempty",     public = true, actions = lxml.doifelseempty,     arguments = "2 strings" }
implement { name = "xmldoifselfempty",     public = true, actions = lxml.doifempty,         arguments = "string" } -- second arg is not passed (used)
implement { name = "xmldoifnotselfempty",  public = true, actions = lxml.doifnotempty,      arguments = "string" } -- second arg is not passed (used)
implement { name = "xmldoifelseselfempty", public = true, actions = lxml.doifelseempty,     arguments = "string" } -- second arg is not passed (used)

--------- { name = "xmlcontent",                          actions = lxml.content,           arguments = "string" }
--------- { name = "xmlflushstripped",                    actions = lxml.strip,             arguments = { "string", true } }

implement { name = "xmlall",               public = true, actions = lxml.all,               arguments = "2 strings" }
implement { name = "xmlatt",               public = true, actions = lxml.att,               arguments = "2 strings" }
implement { name = "xmlattdef",            public = true, actions = lxml.att,               arguments = "3 strings" }
implement { name = "xmlattribute",         public = true, actions = lxml.attribute,         arguments = "3 strings" }
implement { name = "xmlattributedef",      public = true, actions = lxml.attribute,         arguments = "4 strings" }
implement { name = "xmlbadinclusions",     public = true, actions = lxml.badinclusions,     arguments = "string" }
implement { name = "xmlchainatt",          public = true, actions = lxml.chainattribute,    arguments = { "string", "'/'", "string" } }
implement { name = "xmlchainattdef",       public = true, actions = lxml.chainattribute,    arguments = { "string", "'/'", "string", "string"  } }
implement { name = "xmlchecknamespace",    public = true, actions =  xml.checknamespace,    arguments = { "lxmlid", "string", "string" } }
implement { name = "xmlcommand",           public = true, actions = lxml.command,           arguments = "3 strings" }
implement { name = "xmlconcat",                           actions = lxml.concat,            arguments = "3 strings" } --  \detokenize{#3}
implement { name = "xmlconcatrange",                      actions = lxml.concatrange,       arguments = "5 strings" } --  \detokenize{#5}
--------- { name = "xmlconcat",                           actions = lxml.concat,            arguments = { "string", "string", "verbatim" } }
--------- { name = "xmlconcatrange",                      actions = lxml.concatrange,       arguments = { "string", "string", "string", "string", "verbatim" } }
implement { name = "xmlcontext",           public = true, actions = lxml.context,           arguments = "2 strings" }
implement { name = "xmlcount",             public = true, actions = lxml.count,             arguments = "2 strings" }
implement { name = "xmldepth",             public = true, actions = lxml.depth,             arguments = "string" }
implement { name = "xmldelete",            public = true, actions = lxml.delete,            arguments = "2 strings" }
implement { name = "xmldirect",            public = true, actions = lxml.direct,            arguments = "string" }
implement { name = "xmldirectives",        public = true, actions = lxml.directives.setup,  arguments = "string" }
implement { name = "xmldirectivesafter",   public = true, actions = lxml.directives.after,  arguments = "string" }
implement { name = "xmldirectivesbefore",  public = true, actions = lxml.directives.before, arguments = "string" }
implement { name = "xmldisplayverbatim",   public = true, actions = lxml.displayverbatim,   arguments = "string" }
implement { name = "xmlelement",           public = true, actions = lxml.element,           arguments = "2 strings" } -- could be integer but now we can alias
implement { name = "xmlfilter",            public = true, actions = lxml.filter,            arguments = "2 strings" }
implement { name = "xmlfilterlist",        public = true, actions = lxml.filterlist,        arguments = "2 strings" }
implement { name = "xmlfirst",             public = true, actions = lxml.first,             arguments = "2 strings" }
implement { name = "xmlflush",             public = true, actions = lxml.flush,             arguments = "string" }
implement { name = "xmlflushcontext",      public = true, actions = lxml.context,           arguments = "string" }
implement { name = "xmlflushlinewise",     public = true, actions = lxml.flushlinewise,     arguments = "string" }
implement { name = "xmlflushpure",         public = true, actions = lxml.pure,              arguments = "string" }
implement { name = "xmlflushspacewise",    public = true, actions = lxml.flushspacewise,    arguments = "string" }
implement { name = "xmlflushtext",         public = true, actions = lxml.text,              arguments = "string" }
implement { name = "xmlfunction",          public = true, actions = lxml.applyfunction,     arguments = "2 strings" }
implement { name = "xmlinclude",           public = true, actions = lxml.include,           arguments = { "string", "string", "string", true } }
implement { name = "xmlincludeoptions",    public = true, actions = lxml.include,           arguments = "4 strings" }
implement { name = "xmlinclusion",         public = true, actions = lxml.inclusion,         arguments = "string" }
implement { name = "xmlinclusionbase",     public = true, actions = lxml.inclusion,         arguments = { "string", false, true } }
implement { name = "xmlinclusions",        public = true, actions = lxml.inclusions,        arguments = "string" }
implement { name = "xmlindex",             public = true, actions = lxml.index,             arguments = "3 strings" } -- can be integer but now we can alias
implement { name = "xmlinlineverbatim",    public = true, actions = lxml.inlineverbatim,    arguments = "string" }
implement { name = "xmllast",              public = true, actions = lxml.last,              arguments = "2 strings" }
implement { name = "xmllastatt",           public = true, actions = lxml.lastatt }
implement { name = "xmllastmatch",         public = true, actions = lxml.lastmatch }
implement { name = "xmllastpar",           public = true, actions = lxml.lastpar }
implement { name = "xmlloadfile",                         actions = lxml.load,              arguments = "3 strings" }
implement { name = "xmlloadbuffer",                       actions = lxml.loadbuffer,        arguments = "3 strings" }
implement { name = "xmlloaddata",                         actions = lxml.loaddata,          arguments = "3 strings" }
implement { name = "xmlloaddirectives",    public = true, actions = lxml.directives.load,   arguments = "string" }
implement { name = "xmlmain",              public = true, actions = lxml.main,              arguments = "string" }
implement { name = "xmlmatch",             public = true, actions = lxml.match,             arguments = "string" }
implement { name = "xmlname",              public = true, actions = lxml.name,              arguments = "string" }
implement { name = "xmlnamespace",         public = true, actions = lxml.namespace,         arguments = "string" }
implement { name = "xmlnonspace",          public = true, actions = lxml.nonspace,          arguments = "2 strings" }
implement { name = "xmlpar",               public = true, actions = lxml.par,               arguments = "2 strings" }
implement { name = "xmlparam",             public = true, actions = lxml.param,             arguments = "3 strings" }
implement { name = "xmlpath",              public = true, actions = lxml.path,              arguments = { "string", "'/'" } }
implement { name = "xmlpopmatch",          public = true, actions = lxml.popmatch }
implement { name = "xmlpos",               public = true, actions = lxml.pos,               arguments = "string" }
implement { name = "xmlpure",              public = true, actions = lxml.pure,              arguments = "2 strings" }
implement { name = "xmlpushmatch",         public = true, actions = lxml.pushmatch }
implement { name = "xmlraw",               public = true, actions = lxml.raw,               arguments = "2 strings" }
implement { name = "xmlrawtex",                           actions = lxml.rawtex,            arguments = "2 strings" }
implement { name = "xmlrefatt",            public = true, actions = lxml.refatt,            arguments = "2 strings" }
implement { name = "xmlregisterns",        public = true, actions =  xml.registerns,        arguments = "2 strings" }
implement { name = "xmlremapname",         public = true, actions =  xml.remapname,         arguments = { "lxmlid", "string","string","string" } }
implement { name = "xmlremapnamespace",    public = true, actions =  xml.renamespace,       arguments = { "lxmlid", "string", "string" } }
implement { name = "xmlsave",              public = true, actions = lxml.save,              arguments = "2 strings" }
implement { name = "xmlsetatt",            public = true, actions = lxml.setatt,            arguments = "3 strings" }
implement { name = "xmlsetattribute",      public = true, actions = lxml.setattribute,      arguments = "4 strings" }
implement { name = "xmlsetpar",            public = true, actions = lxml.setpar,            arguments = "3 strings" }
implement { name = "xmlsetparam",          public = true, actions = lxml.setparam,          arguments = "4 strings" }
implement { name = "xmlsetsetup",          public = true, actions = lxml.setsetup,          arguments = "3 strings" }
implement { name = "xmlsnippet",           public = true, actions = lxml.snippet,           arguments = "2 strings" }
implement { name = "xmlstrip",             public = true, actions = lxml.strip,             arguments = "2 strings" }
implement { name = "xmlstripanywhere",     public = true, actions = lxml.strip,             arguments = { "string", "string", true, true } }
implement { name = "xmlstripnolines",      public = true, actions = lxml.strip,             arguments = { "string", "string", true } }
implement { name = "xmlstripped",          public = true, actions = lxml.stripped,          arguments = "2 strings" }
implement { name = "xmlstrippednolines",   public = true, actions = lxml.stripped,          arguments = { "string", "string", true } }
implement { name = "xmltag",               public = true, actions = lxml.tag,               arguments = "string" }
implement { name = "xmltext",              public = true, actions = lxml.text,              arguments = "2 strings" }
implement { name = "xmltobuffer",          public = true, actions = lxml.tobuffer,          arguments = "3 strings" }
implement { name = "xmltobuffertextonly",  public = true, actions = lxml.tobuffer,          arguments = { "string", "string", "string", false } }
implement { name = "xmltobufferverbose",   public = true, actions = lxml.tobuffer,          arguments = { "string", "string", "string", true, true } }
implement { name = "xmltofile",            public = true, actions = lxml.tofile,            arguments = "3 strings" }
implement { name = "xmltoparameters",      public = true, actions = lxml.toparameters,      arguments = "string" }
implement { name = "xmlverbatim",          public = true, actions = lxml.verbatim,          arguments = "string" }

implement { name = "xmlstartraw",                         actions = lxml.startraw }
implement { name = "xmlstopraw",                          actions = lxml.stopraw  }

implement { name = "xmlprependsetup",                     actions = lxml.installsetup,      arguments = { 1, "string", "string" } }           -- 2:*
implement { name = "xmlappendsetup",                      actions = lxml.installsetup,      arguments = { 2, "string", "string" } }           -- 2:*
implement { name = "xmlbeforesetup",                      actions = lxml.installsetup,      arguments = { 3, "string", "string", "string" } } -- 2:*
implement { name = "xmlaftersetup",                       actions = lxml.installsetup,      arguments = { 4, "string", "string", "string" } } -- 2:*
implement { name = "xmlremovesetup",                      actions = lxml.removesetup,       arguments = "2 strings" }              -- 1:*
implement { name = "xmlflushsetups",                      actions = lxml.flushsetups,       arguments = "3 strings" }    -- 2:*
implement { name = "xmlresetsetups",                      actions = lxml.resetsetups,       arguments = "string" }

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
