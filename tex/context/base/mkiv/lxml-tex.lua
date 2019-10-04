if not modules then modules = { } end modules ['lxml-tex'] = {
    version   = 1.001,
    comment   = "companion to lxml-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Because we split and resolve entities we use the direct printing
-- interface and not the context one. If we ever do that there will
-- be an cldf-xml helper library.

local concat, insert, remove, sortedkeys, reversed = table.concat, table.insert, table.remove, table.sortedkeys, table.reverse
local format, sub, gsub, find, gmatch, match = string.format, string.sub, string.gsub, string.find, string.gmatch, string.match
local type, next, tonumber, tostring, select = type, next, tonumber, tostring, select
local lpegmatch = lpeg.match
local P, S, C, Cc, Cs = lpeg.P, lpeg.S, lpeg.C, lpeg.Cc, lpeg.Cs
local patterns = lpeg.patterns
local setmetatableindex = table.setmetatableindex
local formatters, strip = string.formatters, string.strip

local tex, xml = tex, xml
local lowerchars, upperchars, lettered = characters.lower, characters.upper, characters.lettered
local basename, dirname, joinfile = file.basename, file.dirname, file.join

lxml = lxml or { }
local lxml = lxml

local catcodenumbers     = catcodes.numbers
local ctxcatcodes        = catcodenumbers.ctxcatcodes -- todo: use different method
local notcatcodes        = catcodenumbers.notcatcodes -- todo: use different method

local commands           = commands
local context            = context
local contextsprint      = context.sprint             -- with catcodes (here we use fast variants, but with option for tracing)

local synctex            = luatex.synctex

local implement          = interfaces.implement

local xmlelements        = xml.elements
local xmlcollected       = xml.collected
local xmlsetproperty     = xml.setproperty
local xmlwithelements    = xml.withelements
local xmlserialize       = xml.serialize
local xmlcollect         = xml.collect
local xmltext            = xml.text
local xmltostring        = xml.tostring
local xmlapplylpath      = xml.applylpath
local xmlunspecialized   = xml.unspecialized
local xmldespecialized   = xml.despecialized -- nicer in expanded xml
local xmlprivatetoken    = xml.privatetoken
local xmlstripelement    = xml.stripelement
local xmlinclusion       = xml.inclusion
local xmlinclusions      = xml.inclusions
local xmlbadinclusions   = xml.badinclusions
local xmlcontent         = xml.content
local xmllastmatch       = xml.lastmatch
local xmlpushmatch       = xml.pushmatch
local xmlpopmatch        = xml.popmatch
local xmlstring          = xml.string
local xmlserializetotext = xml.serializetotext
local xmlrename          = xml.rename

local variables          = interfaces and interfaces.variables or { }

local parsers            = utilities.parsers
local settings_to_hash   = parsers.settings_to_hash
local settings_to_set    = parsers.settings_to_set
local options_to_hash    = parsers.options_to_hash
local options_to_array   = parsers.options_to_array

local insertbeforevalue  = utilities.tables.insertbeforevalue
local insertaftervalue   = utilities.tables.insertaftervalue

local resolveprefix      = resolvers.resolve

local starttiming        = statistics.starttiming
local stoptiming         = statistics.stoptiming

local trace_setups       = false  trackers.register("lxml.setups",   function(v) trace_setups    = v end)
local trace_loading      = false  trackers.register("lxml.loading",  function(v) trace_loading   = v end)
local trace_access       = false  trackers.register("lxml.access",   function(v) trace_access    = v end)
local trace_comments     = false  trackers.register("lxml.comments", function(v) trace_comments  = v end)
local trace_entities     = false  trackers.register("xml.entities",  function(v) trace_entities  = v end)
local trace_selectors    = false  trackers.register("lxml.selectors",function(v) trace_selectors = v end)

local report_lxml        = logs.reporter("lxml","tex")
local report_xml         = logs.reporter("xml","tex")

local forceraw           = false

local p_texescape        = patterns.texescape

local tokenizedxmlw      = context.tokenizedcs and context.tokenizedcs.xmlw

directives.enable("xml.path.keeplastmatch")

-- tex entities

lxml.entities = lxml.entities or { }

storage.register("lxml/entities",lxml.entities,"lxml.entities")

local xmlentities     = xml.entities             -- these are more or less standard entities
local texentities     = lxml.entities            -- these are specific for a tex run
local reparsedentity  = xml.reparsedentitylpeg   -- \Ux{...}
local unescapedentity = xml.unescapedentitylpeg
local parsedentity    = reparsedentity
local useelement      = false                    -- probably no longer needed / used

function lxml.startunescaped()
    parsedentity = unescapedentity
end

function lxml.stopunescaped()
    parsedentity = reparsedentity
end

directives.register("lxml.entities.useelement",function(v)
    useelement = v
end)

function lxml.registerentity(key,value)
    texentities[key] = value
    if trace_entities then
        report_xml("registering tex entity %a as %a",key,value)
    end
end

function lxml.resolvedentity(str)
    if forceraw then
        -- should not happen as we then can as well bypass this function
        if trace_entities then
            report_xml("passing entity %a as &%s;",str,str)
        end
        context("&%s;",str)
    else
        local e = texentities[str]
        if e then
            local te = type(e)
            if te == "function" then
                if trace_entities then
                    report_xml("passing entity %a using function",str)
                end
                e(str)
            elseif e then
                if trace_entities then
                    report_xml("passing entity %a as %a using %a",str,e,"ctxcatcodes")
                end
                context(e)
            end
            return
        end
        local e = xmlentities[str]
        if e then
            local te = type(e)
            if te == "function" then
                e = e(str)
            end
            if e then
                if trace_entities then
                    report_xml("passing entity %a as %a using %a",str,e,"notcatcodes")
                end
                contextsprint(notcatcodes,e)
                return
            end
        end
        -- resolve hex and dec, todo: escape # & etc for ctxcatcodes
        -- normally this is already solved while loading the file
        local chr, err = lpegmatch(parsedentity,str)
        if chr then
            if parsedentity == reparsedentity then
                if trace_entities then
                    report_xml("passing entity %a as %a using %a",str,chr,"ctxcatcodes")
                end
                context(chr)
            else
                contextsprint(notcatcodes,chr)
                if trace_entities then
                    report_xml("passing entity %a as %a using %a",str,chr,"notcatcodes")
                end
            end
        elseif err then
            if trace_entities then
                report_xml("passing faulty entity %a as %a",str,err)
            end
            context(err)
        elseif useelement then
            local tag = upperchars(str)
            if trace_entities then
                report_xml("passing entity %a to \\xmle using tag %a",str,tag)
            end
            contextsprint(texcatcodes,"\\xmle{")
            contextsprint(notcatcodes,e)
            contextsprint(texcatcodes,"}")
        else
            if trace_entities then
                report_xml("passing entity %a as %a using %a",str,str,"notcatcodes")
            end
            contextsprint(notcatcodes,str)
        end
    end
end

-- tex interface

local loaded    = lxml.loaded or { }
lxml.loaded     = loaded

-- print(contextdirective("context-mathml-directive function reduction yes "))
-- print(contextdirective("context-mathml-directive function "))

xml.defaultprotocol = "tex"

local finalizers  = xml.finalizers

finalizers.xml = finalizers.xml or { }
finalizers.tex = finalizers.tex or { }

local xmlfinalizers = finalizers.xml
local texfinalizers = finalizers.tex

-- serialization with entity handling

local ampersand  = P("&")
local semicolon  = P(";")

local entity     = (ampersand * C((1-semicolon)^1) * semicolon) / lxml.resolvedentity -- context.bold

local _, xmltextcapture_yes = context.newtexthandler {
    catcodes  = notcatcodes,
    exception = entity,
}
local _, xmltextcapture_nop = context.newtexthandler {
    catcodes  = notcatcodes,
}

local _, xmlspacecapture_yes = context.newtexthandler {
    endofline  = context.xmlcdataobeyedline,
    emptyline  = context.xmlcdataobeyedline,
    simpleline = context.xmlcdataobeyedline,
    space      = context.xmlcdataobeyedspace,
    catcodes   = notcatcodes,
    exception  = entity,
}
local _, xmlspacecapture_nop = context.newtexthandler {
    endofline  = context.xmlcdataobeyedline,
    emptyline  = context.xmlcdataobeyedline,
    simpleline = context.xmlcdataobeyedline,
    space      = context.xmlcdataobeyedspace,
    catcodes   = notcatcodes,
}

local _, xmllinecapture_yes = context.newtexthandler {
    endofline  = context.xmlcdataobeyedline,
    emptyline  = context.xmlcdataobeyedline,
    simpleline = context.xmlcdataobeyedline,
    catcodes   = notcatcodes,
    exception  = entity,
}
local _, xmllinecapture_nop = context.newtexthandler {
    endofline  = context.xmlcdataobeyedline,
    emptyline  = context.xmlcdataobeyedline,
    simpleline = context.xmlcdataobeyedline,
    catcodes   = notcatcodes,
}

local _, ctxtextcapture_yes = context.newtexthandler {
    catcodes  = ctxcatcodes,
    exception = entity,
}
local _, ctxtextcapture_nop = context.newtexthandler {
    catcodes  = ctxcatcodes,
}

local xmltextcapture    = xmltextcapture_yes
local xmlspacecapture   = xmlspacecapture_yes
local xmllinecapture    = xmllinecapture_yes
local ctxtextcapture    = ctxtextcapture_yes

directives.register("lxml.entities.escaped",function(v)
    if v then
        xmltextcapture  = xmltextcapture_yes
        xmlspacecapture = xmlspacecapture_yes
        xmllinecapture  = xmllinecapture_yes
        ctxtextcapture  = ctxtextcapture_yes
    else
        xmltextcapture  = xmltextcapture_nop
        xmlspacecapture = xmlspacecapture_nop
        xmllinecapture  = xmllinecapture_nop
        ctxtextcapture  = ctxtextcapture_nop
    end
end)

-- cdata

local toverbatim = context.newverbosehandler {
    line   = context.xmlcdataobeyedline,
    space  = context.xmlcdataobeyedspace,
    before = context.xmlcdatabefore,
    after  = context.xmlcdataafter,
}

lxml.toverbatim = context.newverbosehandler {
    line   = context.xmlcdataobeyedline,
    space  = context.xmlcdataobeyedspace,
    before = context.xmlcdatabefore,
    after  = context.xmlcdataafter,
    strip  = true,
}

-- raw flushing

function lxml.startraw()
    forceraw = true
end

function lxml.stopraw()
    forceraw = false
end

function lxml.rawroot()
    return rawroot
end

-- storage

do

    local noferrors    = 0
    local errors       = setmetatableindex("number")
    local errorhandler = xml.errorhandler

    function xml.errorhandler(message,filename)
        if filename and filename ~= "" then
            noferrors = noferrors + 1
            errors[filename] = errors[filename] + 1
        end
        errorhandler(message) -- (filename)
    end

    logs.registerfinalactions(function()
        if noferrors > 0 then
            local report = logs.startfilelogging("lxml","problematic xml files")
            for k, v in table.sortedhash(errors) do
                report("%4i  %s",v,k)
            end
            logs.stopfilelogging()
            --
            if logs.loggingerrors() then
                logs.starterrorlogging(report,"problematic xml files")
                for k, v in table.sortedhash(errors) do
                    report("%4i  %s",v,k)
                end
                logs.stoperrorlogging()
            end
        end
    end)

end

function lxml.store(id,root,filename)
    loaded[id] = root
    xmlsetproperty(root,"name",id)
    if filename then
        xmlsetproperty(root,"filename",filename)
    end
end

local splitter = lpeg.splitat("::")

lxml.idsplitter = splitter

function lxml.splitid(id)
    local d, i = lpegmatch(splitter,id)
    if d then
        return d, i
    else
        return "", id
    end
end

local function getid(id, qualified)
    if id then
        local lid = loaded[id]
        if lid then
            return lid
        elseif type(id) == "table" then
            return id
        else
            local d, i = lpegmatch(splitter,id)
            if d then
                local ld = loaded[d]
                if ld then
                    local ldi = ld.index
                    if ldi then
                        local root = ldi[tonumber(i)]
                        if root then
                            if qualified then -- we need this else two args that confuse others
                                return root, d
                            else
                                return root
                            end
                        elseif trace_access then
                            report_lxml("%a has no index entry %a",d,i)
                        end
                    elseif trace_access then
                        report_lxml("%a has no index",d)
                    end
                elseif trace_access then
                    report_lxml("%a is not loaded",d)
                end
            elseif trace_access then
                report_lxml("%a is not loaded",i)
            end
        end
    elseif trace_access then
        report_lxml("invalid id (nil)")
    end
end

lxml.id    = getid -- we provide two names as locals can already use such
lxml.getid = getid -- names and we don't want clashes

function lxml.root(id)
    return loaded[id]
end

-- index

local nofindices = 0

local function addindex(name,check_sum,force)
    local root = getid(name)
    if root and (not root.index or force) then -- weird, only called once
        local n, index, maxindex, check = 0, root.index or { }, root.maxindex or 0, root.check or { }
        local function nest(root)
            local dt = root.dt
            if not root.ix then
                maxindex = maxindex + 1
                root.ix = maxindex
                check[maxindex] = root.tg -- still needed ?
                index[maxindex] = root
                n = n + 1
            end
            if dt then
                for k=1,#dt do
                    local dk = dt[k]
                    if type(dk) == "table" then
                        nest(dk)
                    end
                end
            end
        end
        nest(root)
        nofindices = nofindices + n
        --
        if type(name) ~= "string" then
            name = "unknown"
        end
        root.index = index
        root.maxindex = maxindex
        if trace_access then
            report_lxml("indexed entries %a, found nodes %a",tostring(name),maxindex)
        end
    end
end

lxml.addindex = addindex

implement {
    name      = "xmladdindex",
    arguments = "string",
    actions   = addindex,
}

-- another cache

local function lxmlapplylpath(id,pattern) -- better inline, saves call
    return xmlapplylpath(getid(id),pattern)
end

lxml.filter = lxmlapplylpath

function lxml.filterlist(list,pattern)
    for s in gmatch(list,"[^, ]+") do -- we could cache a table
        xmlapplylpath(getid(s),pattern)
    end
end

function lxml.applyfunction(id,name)
    local f = xml.functions[name]
    return f and f(getid(id))
end

-- rather new, indexed storage (backward refs), maybe i will merge this

function lxml.checkindex(name)
    local root = getid(name)
    return root and root.index or 0
end

if tokenizedxmlw then

    function lxml.withindex(name,n,command) -- will change as name is always there now
        local i, p = lpegmatch(splitter,n)
        if p then
            contextsprint(ctxcatcodes,tokenizedxmlw,"{",command,"}{",n,"}")
        else
            contextsprint(ctxcatcodes,tokenizedxmlw,"{",command,"}{",name,"::",n,"}")
        end
    end

else

    function lxml.withindex(name,n,command) -- will change as name is always there now
        local i, p = lpegmatch(splitter,n)
        if p then
            contextsprint(ctxcatcodes,"\\xmlw{",command,"}{",n,"}")
        else
            contextsprint(ctxcatcodes,"\\xmlw{",command,"}{",name,"::",n,"}")
        end
    end

end

function lxml.getindex(name,n) -- will change as name is always there now
    local i, p = lpegmatch(splitter,n)
    if p then
        contextsprint(ctxcatcodes,n)
    else
        contextsprint(ctxcatcodes,name,"::",n)
    end
end

-- loading (to be redone, no overload) .. best use different methods and
-- keep raw xml (at least as option)

xml.originalload = xml.originalload or xml.load

local noffiles     = 0
local nofconverted = 0
local linenumbers  = false

synctex.registerenabler (function() linenumbers = true  end)
synctex.registerdisabler(function() linenumbers = false end)

function xml.load(filename,settings)
    noffiles, nofconverted = noffiles + 1, nofconverted + 1
    starttiming(xml)
    local ok, data = resolvers.loadbinfile(filename)
    settings = settings or { }
    settings.linenumbers = linenumbers
    settings.currentresource = filename
    local xmltable = xml.convert((ok and data) or "",settings)
    settings.currentresource = nil
    stoptiming(xml)
    return xmltable
end

local function entityconverter(id,str,ent) -- todo: disable tex entities when raw
    -- tex driven entity
    local t = texentities[str]
    if t then
        local p = xmlprivatetoken(str)
-- only once
-- context.xmlprivate(p,t)
        return p
    end
    -- dtd determined entity
    local e = ent and ent[str]
    if e then
        return e
    end
    -- predefined entity (mathml and so)
    local x = xmlentities[str]
    if x then
        return x
    end
    -- keep original somehow
    return xmlprivatetoken(str)
end

lxml.preprocessor = nil

local function lxmlconvert(id,data,compress,currentresource)
    local settings = { -- we're now roundtrip anyway
        unify_predefined_entities   = false, -- is also default
        utfize_entities             = true,  -- is also default
        resolve_predefined_entities = true,  -- is also default
        resolve_entities            = function(str,ent) return entityconverter(id,str,ent) end,
        currentresource             = tostring(currentresource or id),
        preprocessor                = lxml.preprocessor,
        linenumbers                 = linenumbers,
    }
    if compress and compress == variables.yes then
        settings.strip_cm_and_dt = true
    end
    return xml.convert(data,settings)
end

lxml.convert = lxmlconvert

function lxml.load(id,filename,compress)
    filename = ctxrunner.preparedfile(filename)
    if trace_loading then
        report_lxml("loading file %a as %a",filename,id)
    end
    noffiles, nofconverted = noffiles + 1, nofconverted + 1
    starttiming(xml)
    local ok, data = resolvers.loadbinfile(filename)
 -- local xmltable = lxmlconvert(id,(ok and data) or "",compress,formatters["id: %s, file: %s"](id,filename))
    local xmltable = lxmlconvert(id,(ok and data) or "",compress,filename)
    stoptiming(xml)
    lxml.store(id,xmltable,filename)
    return xmltable, filename
end

function lxml.register(id,xmltable,filename)
    lxml.store(id,xmltable,filename)
    return xmltable
end

-- recurse prepare rootpath resolve basename

local options_true = { "recurse", "prepare", "rootpath" }
local options_nil  = { "prepare", "rootpath" }

function lxml.include(id,pattern,attribute,options)
    starttiming(xml)
    local root = getid(id)
    if options == true then
        -- downward compatible
        options = options_true
    elseif not options then
        -- downward compatible
        options = options_nil
    else
        options = settings_to_hash(options) or { }
    end
    xml.include(root,pattern,attribute,options.recurse,function(filename)
        if filename then
            -- preprocessing
            if options.prepare then
                filename = commands.preparedfile(filename)
            end
            -- handy if we have a flattened structure
            if options.basename then
                filename = basename(filename)
            end
            if options.resolve then
                filename = resolveprefix(filename) or filename
            end
            -- some protection
            if options.rootpath and dirname(filename) == "" and root.filename then
                local dn = dirname(root.filename)
                if dn ~= "" then
                    filename = joinfile(dn,filename)
                end
            end
            if trace_loading then
                report_lxml("including file %a",filename)
            end
            noffiles, nofconverted = noffiles + 1, nofconverted + 1
            return
                resolvers.loadtexfile(filename) or "",
                resolvers.findtexfile(filename) or ""
        else
            return ""
        end
    end)
    stoptiming(xml)
end

function lxml.inclusion(id,default,base)
    local inclusion = xmlinclusion(getid(id),default)
    if inclusion then
        context(base and basename(inclusion) or inclusion)
    end
end

function lxml.inclusions(id,sorted)
    local inclusions = xmlinclusions(getid(id),sorted)
    if inclusions then
        context(concat(inclusions,","))
    end
end

function lxml.badinclusions(id,sorted)
    local badinclusions = xmlbadinclusions(getid(id),sorted)
    if badinclusions then
        context(concat(badinclusions,","))
    end
end

function lxml.save(id,name)
    xml.save(getid(id),name)
end

function xml.getbuffer(name,compress) -- we need to make sure that commands are processed
    if not name or name == "" then
        name = tex.jobname
    end
    nofconverted = nofconverted + 1
    local data = buffers.getcontent(name)
    xmltostring(lxmlconvert(name,data,compress,format("buffer: %s",tostring(name or "?")))) -- one buffer
end

function lxml.loadbuffer(id,name,compress)
    starttiming(xml)
    nofconverted = nofconverted + 1
    local data = buffers.collectcontent(name or id) -- name can be list
    local xmltable = lxmlconvert(id,data,compress,format("buffer: %s",tostring(name or id or "?")))
    lxml.store(id,xmltable)
    stoptiming(xml)
    return xmltable, name or id
end

function lxml.loaddata(id,str,compress)
    starttiming(xml)
    nofconverted = nofconverted + 1
    local xmltable = lxmlconvert(id,str or "",compress,format("id: %s",id))
    lxml.store(id,xmltable)
    stoptiming(xml)
    return xmltable, id
end

-- e.command:
--
-- string   : setup
-- true     : text (no <self></self>)
-- false    : ignore
-- function : call

local function tex_doctype(e,handlers)
    -- ignore
end

local function tex_comment(e,handlers)
    if trace_comments then
        report_lxml("comment %a",e.dt[1])
    end
end

local default_element_handler = xml.gethandlers("verbose").functions["@el@"]

local setfilename = false
local trace_name  = false
local report_name = logs.reporter("lxml")

synctex.registerenabler (function() setfilename = synctex.setfilename end)
synctex.registerdisabler(function() setfilename = false end)

local function syncfilename(e,where)
    local cf = e.cf
    if cf then
        local cl = e.cl or 1
        if trace_name then
            report_name("set filename, case %a, tag %a, file %a, line %a",where,e.tg,cf,cl)
        end
        setfilename(cf,cl);
    end
end

trackers.register("system.synctex.xml",function(v)
    trace_name = v
end)

local tex_element

if tokenizedxmlw then

    tex_element = function(e,handlers)
        if setfilename then
            syncfilename(e,"element")
        end
        local command = e.command
        if command == nil then
            default_element_handler(e,handlers)
        elseif command == true then
            -- text (no <self></self>) / so, no mkii fallback then
            handlers.serialize(e.dt,handlers)
        elseif command == false then
            -- ignore
        else
            local tc = type(command)
            if tc == "string" then
                local rootname, ix = e.name, e.ix
                if rootname then
                    if not ix then
                        addindex(rootname,false,true)
                        ix = e.ix
                    end
                    contextsprint(ctxcatcodes,tokenizedxmlw,"{",command,"}{",rootname,"::",ix,"}")
                else
                    report_lxml("fatal error: no index for %a",command)
                    contextsprint(ctxcatcodes,tokenizedxmlw,"{",command,"}{",ix or 0,"}")
                end
            elseif tc == "function" then
                command(e)
            end
        end
    end

else

    tex_element = function(e,handlers)
        if setfilename then
            syncfilename(e,"element")
        end
        local command = e.command
        if command == nil then
            default_element_handler(e,handlers)
        elseif command == true then
            -- text (no <self></self>) / so, no mkii fallback then
            handlers.serialize(e.dt,handlers)
        elseif command == false then
            -- ignore
        else
            local tc = type(command)
            if tc == "string" then
                local rootname, ix = e.name, e.ix
                if rootname then
                    if not ix then
                        addindex(rootname,false,true)
                        ix = e.ix
                    end
                 -- faster than context.xmlw
                    contextsprint(ctxcatcodes,"\\xmlw{",command,"}{",rootname,"::",ix,"}")
                 -- contextsprint(ctxcatcodes,xmlw[command][rootname],ix,"}")
                else
                    report_lxml("fatal error: no index for %a",command)
                    contextsprint(ctxcatcodes,"\\xmlw{",command,"}{",ix or 0,"}")
                 -- contextsprint(ctxcatcodes,xmlw[command][false],ix or 0,"}")
                end
            elseif tc == "function" then
                command(e)
            end
        end
    end

end

-- <?context-directive foo ... ?>
-- <?context-foo-directive ... ?>

local pihandlers = { }  xml.pihandlers = pihandlers

local space    = S(" \n\r")
local spaces   = space^0
local class    = C((1-space)^0)
local key      = class
local rest     = C(P(1)^0)
local value    = C(P(1-(space * -1))^0)
local category = P("context-") * (
                    C((1-P("-"))^1) * P("-directive")
                  + P("directive") * spaces * key
                 )

local c_parser = category * spaces * value -- rest
local k_parser = class * spaces * key * spaces * rest --value

implement {
    name      = "xmlinstalldirective",
    arguments = "2 strings",
    actions   = function(name,csname)
        if csname then
            local keyvalueparser  = k_parser / context[csname]
            local keyvaluechecker = function(category,rest,e)
                lpegmatch(keyvalueparser,rest)
            end
            pihandlers[name] = keyvaluechecker
        end
    end
}

local function tex_pi(e,handlers)
    local str = e.dt[1]
    if str and str ~= "" then
        local category, rest = lpegmatch(c_parser,str)
        if category and rest and #rest > 0 then
            local handler = pihandlers[category]
            if handler then
                handler(category,rest,e)
            end
        end
    end
end

local obeycdata = true

function lxml.setcdata()
    obeycdata = true
end

function lxml.resetcdata()
    obeycdata = false
end

local function tex_cdata(e,handlers)
    if obeycdata then
        toverbatim(e.dt[1])
    end
end

-- we could try to merge the conversion and flusher but we don't gain much and it makes tracing
-- harder: xunspecialized = utf.remapper(xml.specialcodes,"dynamic",lxml.resolvedentity)

local function tex_text(e)
    e = xmlunspecialized(e)
    lpegmatch(xmltextcapture,e)
end

--

local function ctx_text(e) -- can be just context(e) as we split there
    lpegmatch(ctxtextcapture,e)
end

local function tex_handle(...)
    contextsprint(ctxcatcodes,...) -- notcatcodes is active anyway
end

local xmltexhandler = xml.newhandlers {
    name       = "tex",
    handle     = tex_handle,
    functions  = {
     -- ["@dc@"]   = tex_document,
        ["@dt@"]   = tex_doctype,
     -- ["@rt@"]   = tex_root,
        ["@el@"]   = tex_element,
        ["@pi@"]   = tex_pi,
        ["@cm@"]   = tex_comment,
        ["@cd@"]   = tex_cdata,
        ["@tx@"]   = tex_text,
    }
}

lxml.xmltexhandler = xmltexhandler

-- begin of test

local function tex_space(e)
    e = xmlunspecialized(e)
    lpegmatch(xmlspacecapture,e)
end

local xmltexspacehandler = xml.newhandlers {
    name       = "texspace",
    handle     = tex_handle,
    functions  = {
        ["@dt@"]   = tex_doctype,
        ["@el@"]   = tex_element,
        ["@pi@"]   = tex_pi,
        ["@cm@"]   = tex_comment,
        ["@cd@"]   = tex_cdata,
        ["@tx@"]   = tex_space,
    }
}

local function tex_line(e)
    e = xmlunspecialized(e)
    lpegmatch(xmllinecapture,e)
end

local xmltexlinehandler = xml.newhandlers {
    name       = "texline",
    handle     = tex_handle,
    functions  = {
        ["@dt@"]   = tex_doctype,
        ["@el@"]   = tex_element,
        ["@pi@"]   = tex_pi,
        ["@cm@"]   = tex_comment,
        ["@cd@"]   = tex_cdata,
        ["@tx@"]   = tex_line,
    }
}

function lxml.flushspacewise(id) -- keeps spaces and lines
    id = getid(id)
    local dt = id and id.dt
    if dt then
        xmlserialize(dt,xmltexspacehandler)
    end
end

function lxml.flushlinewise(id) -- keeps lines
    id = getid(id)
    local dt = id and id.dt
    if dt then
        xmlserialize(dt,xmltexlinehandler)
    end
end

-- end of test

function lxml.serialize(root)
    xmlserialize(root,xmltexhandler)
end

function lxml.setaction(id,pattern,action)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                collected[c].command = action
            end
        end
    end
end

local function sprint(root,p) -- check rawroot usage
    if root then
        local tr = type(root)
        if tr == "string" then -- can also be result of lpath
         -- rawroot = false -- ?
            if setfilename and p then
                syncfilename(p,"sprint s")
            end
            root = xmlunspecialized(root)
            lpegmatch(xmltextcapture,root)
        elseif tr == "table" then
            if forceraw then
                rawroot = root
             -- contextsprint(ctxcatcodes,xmltostring(root)) -- goes wrong with % etc
             -- root = xmlunspecialized(xmltostring(root))   -- we loose < > &
                root = xmldespecialized(xmltostring(root))
                lpegmatch(xmltextcapture,root) -- goes to toc
            else
if setfilename and p then -- and not root.cl
    syncfilename(p,"sprint t")
end
                xmlserialize(root,xmltexhandler)
            end
        end
    end
end

-- local function tprint(root) -- we can move sprint inline
--     local tr = type(root)
--     if tr == "table" then
--         local n = #root
--         if n == 0 then
--             -- skip
--         else
--             for i=1,n do
--                 sprint(root[i])
--             end
--         end
--     elseif tr == "string" then
--         root = xmlunspecialized(root)
--         lpegmatch(xmltextcapture,root)
--     end
-- end

local function tprint(root) -- we can move sprint inline
    local tr = type(root)
    if tr == "table" then
        local n = #root
        if n == 0 then
            -- skip
        else
            for i=1,n do
             -- sprint(root[i]) -- inlined because of filename:
                local ri = root[i]
                local tr = type(ri)
                if tr == "string" then -- can also be result of lpath
                    if setfilename then
                        syncfilename(ri,"tprint")
                    end
                    root = xmlunspecialized(ri)
                    lpegmatch(xmltextcapture,ri)
                elseif tr == "table" then
                    if forceraw then
                        rawroot = ri
                        root = xmldespecialized(xmltostring(ri))
                        lpegmatch(xmltextcapture,ri) -- goes to toc
                    else
                        xmlserialize(ri,xmltexhandler)
                    end
                end
            end
        end
    elseif tr == "string" then
        root = xmlunspecialized(root)
        lpegmatch(xmltextcapture,root)
    end
end

local function cprint(root) -- content
    if not root then
     -- rawroot = false
        -- quit
    elseif type(root) == 'string' then
     -- rawroot = false
        root = xmlunspecialized(root)
        lpegmatch(xmltextcapture,root)
    else
        if setfilename then
            syncfilename(root,"cprint")
        end
        local rootdt = root.dt
        if forceraw then
            rawroot = root
         -- contextsprint(ctxcatcodes,xmltostring(rootdt or root))
            root = xmlunspecialized(xmltostring(root))
            lpegmatch(xmltextcapture,root) -- goes to toc
        else
            xmlserialize(rootdt or root,xmltexhandler)
        end
    end
end

xml.sprint = sprint local xmlsprint = sprint  -- calls ct mathml   -> will be replaced
xml.tprint = tprint local xmltprint = tprint  -- only used here
xml.cprint = cprint local xmlcprint = cprint  -- calls ct  mathml  -> will be replaced

-- now we can flush

function lxml.main(id)
    local root = getid(id)
    xmlserialize(root,xmltexhandler) -- the real root (@rt@)
end

-- -- lines (untested)
--
-- local buffer = { }
--
-- local xmllinescapture = (
--     newline^2 / function()  buffer[#buffer+1] = "" end +
--     newline   / function()  buffer[#buffer] = buffer[#buffer] .. " " end +
--     content   / function(s) buffer[#buffer] = buffer[#buffer] ..  s  end
-- )^0
--
-- local xmllineshandler = table.copy(xmltexhandler)
--
-- xmllineshandler.handle = function(...) lpegmatch(xmllinescapture,concat{ ... }) end
--
-- function lines(root)
--     if not root then
--      -- rawroot = false
--      -- quit
--     elseif type(root) == 'string' then
--      -- rawroot = false
--         lpegmatch(xmllinescapture,root)
--     elseif next(root) then -- tr == 'table'
--         xmlserialize(root,xmllineshandler)
--     end
-- end
--
-- function xml.lines(root) -- used at all?
--     buffer = { "" }
--     lines(root)
--     return result
-- end

local function to_text(e)
    if e.command == nil then
        local etg = e.tg
        if etg and e.special and etg ~= "@rt@" then
            e.command = false -- i.e. skip
        else
            e.command = true  -- i.e. no <self></self>
        end
    end
end

local function to_none(e)
    if e.command == nil then
        e.command = false -- i.e. skip
    end
end

-- setups

local setups = { }

function lxml.setcommandtotext(id)
    xmlwithelements(getid(id),to_text)
end

function lxml.setcommandtonone(id)
    xmlwithelements(getid(id),to_none)
end

function lxml.installsetup(what,document,setup,where)
    document = document or "*"
    local sd = setups[document]
    if not sd then sd = { } setups[document] = sd end
    for k=1,#sd do
        if sd[k] == setup then sd[k] = nil break end
    end
    if what == 1 then
        if trace_loading then
            report_lxml("prepending setup %a for %a",setup,document)
        end
        insert(sd,1,setup)
    elseif what == 2 then
        if trace_loading then
            report_lxml("appending setup %a for %a",setup,document)
        end
        insert(sd,setup)
    elseif what == 3 then
        if trace_loading then
            report_lxml("inserting setup %a for %a before %a",setup,document,where)
        end
        insertbeforevalue(sd,setup,where)
    elseif what == 4 then
        if trace_loading then
            report_lxml("inserting setup %a for %a after %a",setup,document,where)
        end
        insertaftervalue(sd,setup,where)
    end
end

function lxml.flushsetups(id,...)
    local done = { }
    for i=1,select("#",...) do
        local document = select(i,...)
        local sd = setups[document]
        if sd then
            for k=1,#sd do
                local v = sd[k]
                if not done[v] then
                    if trace_loading then
                        report_lxml("applying setup %02i : %a to %a",k,v,document)
                    end
                    contextsprint(ctxcatcodes,"\\xmlsetup{",id,"}{",v,"}")
                    done[v] = true
                end
            end
        elseif trace_loading then
            report_lxml("no setups for %a",document)
        end
    end
end

function lxml.resetsetups(document)
    if trace_loading then
        report_lxml("resetting all setups for %a",document)
    end
    setups[document] = { }
end

function lxml.removesetup(document,setup)
    local s = setups[document]
    if s then
        for i=1,#s do
            if s[i] == setup then
                if trace_loading then
                    report_lxml("removing setup %a for %a",setup,document)
                end
                remove(t,i)
                break
            end
        end
    end
end

function lxml.setsetup(id,pattern,setup)
    if not setup or setup == "" or setup == "*" or setup == "-" or setup == "+" then
        local collected = xmlapplylpath(getid(id),pattern)
        if collected then
            local nc = #collected
            if nc > 0 then
                if trace_setups then
                    for c=1,nc do
                        local e = collected[c]
                        local ix = e.ix or 0
                        if setup == "-" then
                            e.command = false
                            report_lxml("lpath matched (a) %5i: %s = %s -> skipped",c,ix,setup)
                        elseif setup == "+" then
                            e.command = true
                            report_lxml("lpath matched (b) %5i: %s = %s -> text",c,ix,setup)
                        else
                            local tg = e.tg
                            if tg then -- to be sure
                                e.command = tg
                                local ns = e.rn or e.ns
                                if ns == "" then
                                    report_lxml("lpath matched (c) %5i: %s = %s -> %s",c,ix,tg,tg)
                                else
                                    report_lxml("lpath matched (d) %5i: %s = %s:%s -> %s",c,ix,ns,tg,tg)
                                end
                            end
                        end
                    end
                elseif setup == "-" then
                    for c=1,nc do
                        collected[c].command = false
                    end
                elseif setup == "+" then
                    for c=1,nc do
                        collected[c].command = true
                    end
                else
                    for c=1,nc do
                        local e = collected[c]
                        e.command = e.tg
                    end
                end
            elseif trace_setups then
                report_lxml("%s lpath matches for pattern: %s","zero",pattern)
            end
        elseif trace_setups then
            report_lxml("%s lpath matches for pattern: %s","no",pattern)
        end
    else
        local a, b = match(setup,"^(.+:)([%*%-%+])$")
        if a and b then
            local collected = xmlapplylpath(getid(id),pattern)
            if collected then
                local nc = #collected
                if nc > 0 then
                    if trace_setups then
                        for c=1,nc do
                            local e = collected[c]
                            local ns, tg, ix = e.rn or e.ns, e.tg, e.ix or 0
                            if b == "-" then
                                e.command = false
                                if ns == "" then
                                    report_lxml("lpath matched (e) %5i: %s = %s -> skipped",c,ix,tg)
                                else
                                    report_lxml("lpath matched (f) %5i: %s = %s:%s -> skipped",c,ix,ns,tg)
                                end
                            elseif b == "+" then
                                e.command = true
                                if ns == "" then
                                    report_lxml("lpath matched (g) %5i: %s = %s -> text",c,ix,tg)
                                else
                                    report_lxml("lpath matched (h) %5i: %s = %s:%s -> text",c,ix,ns,tg)
                                end
                            else
                                e.command = a .. tg
                                if ns == "" then
                                    report_lxml("lpath matched (i) %5i: %s = %s -> %s",c,ix,tg,e.command)
                                else
                                    report_lxml("lpath matched (j) %5i: %s = %s:%s -> %s",c,ix,ns,tg,e.command)
                                end
                            end
                        end
                    elseif b == "-" then
                        for c=1,nc do
                            collected[c].command = false
                        end
                    elseif b == "+" then
                        for c=1,nc do
                            collected[c].command = true
                        end
                    else
                        for c=1,nc do
                            local e = collected[c]
                            e.command = a .. e.tg
                        end
                    end
                elseif trace_setups then
                    report_lxml("%s lpath matches for pattern: %s","zero",pattern)
                end
            elseif trace_setups then
                report_lxml("%s lpath matches for pattern: %s","no",pattern)
            end
        else
            local collected = xmlapplylpath(getid(id),pattern)
            if collected then
                local nc = #collected
                if nc > 0 then
                    if trace_setups then
                        for c=1,nc do
                            local e = collected[c]
                            e.command = setup
                            local ns, tg, ix = e.rn or e.ns, e.tg, e.ix or 0
                            if ns == "" then
                                report_lxml("lpath matched (k) %5i: %s = %s -> %s",c,ix,tg,setup)
                            else
                                report_lxml("lpath matched (l) %5i: %s = %s:%s -> %s",c,ix,ns,tg,setup)
                            end
                        end
                    else
                        for c=1,nc do
                            collected[c].command = setup
                        end
                    end
                elseif trace_setups then
                    report_lxml("%s lpath matches for pattern: %s","zero",pattern)
                end
            elseif trace_setups then
                report_lxml("%s lpath matches for pattern: %s","no",pattern)
            end
        end
    end
end

-- finalizers

local function first(collected)
    if collected and #collected > 0 then
        xmlsprint(collected[1])
    end
end

local function last(collected)
    if collected then
        local nc = #collected
        if nc > 0 then
            xmlsprint(collected[nc])
        end
    end
end

local function all(collected)
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                xmlsprint(collected[c])
            end
        end
    end
end

local function reverse(collected)
    if collected then
        local nc = #collected
        if nc >0 then
            for c=nc,1,-1 do
                xmlsprint(collected[c])
            end
        end
    end
end

local function count(collected)
    contextsprint(ctxcatcodes,(collected and #collected) or 0) -- why ctxcatcodes
end

local function position(collected,n)
    -- todo: if not n then == match
    if collected then
        local nc = #collected
        if nc > 0 then
            n = tonumber(n) or 0
            if n < 0 then
                n = nc + n + 1
            end
            if n > 0 then
                local cn = collected[n]
                if cn then
                    xmlsprint(cn)
                    return
                end
            end
        end
    end
end

local function match(collected) -- is match in preceding collected, never change, see bibxml
    local m = collected and collected[1]
    contextsprint(ctxcatcodes,m and m.mi or 0) -- why ctxcatcodes
end

local function index(collected,n)
    if collected then
        local nc = #collected
        if nc > 0 then
            n = tonumber(n) or 0
            if n < 0 then
                n = nc + n + 1 -- brrr
            end
            if n > 0 then
                local cn = collected[n]
                if cn then
                    contextsprint(ctxcatcodes,cn.ni or 0) -- why ctxcatcodes
                    return
                end
            end
        end
    end
    contextsprint(ctxcatcodes,0) -- why ctxcatcodes
end

-- the number of commands is often relative small but there can be many calls
-- to this finalizer

local command

if tokenizedxmlw then

    command = function(collected,cmd,otherwise)
        local n = collected and #collected
        if n and n > 0 then
            local wildcard = find(cmd,"*",1,true)
            for c=1,n do -- maybe optimize for n=1
                local e = collected[c]
                local ix = e.ix
                local name = e.name
                if name and not ix then
                    addindex(name,false,true)
                    ix = e.ix
                end
                if not ix or not name then
                    report_lxml("no valid node index for element %a using command %s",name or "?",cmd)
                elseif wildcard then
                    contextsprint(ctxcatcodes,tokenizedxmlw,"{",(gsub(cmd,"%*",e.tg)),"}{",name,"::",ix,"}")
                else
                    contextsprint(ctxcatcodes,tokenizedxmlw,"{",cmd,"}{",name,"::",ix,"}")
                end
            end
        elseif otherwise then
            contextsprint(ctxcatcodes,tokenizedxmlw,"{",otherwise,"}{#1}")
        end
    end

else

    command = function(collected,cmd,otherwise)
        local n = collected and #collected
        if n and n > 0 then
            local wildcard = find(cmd,"*",1,true)
            for c=1,n do -- maybe optimize for n=1
                local e = collected[c]
                local ix = e.ix
                local name = e.name
                if name and not ix then
                    addindex(name,false,true)
                    ix = e.ix
                end
                if not ix or not name then
                    report_lxml("no valid node index for element %a using command %s",name or "?",cmd)
                elseif wildcard then
                    contextsprint(ctxcatcodes,"\\xmlw{",(gsub(cmd,"%*",e.tg)),"}{",name,"::",ix,"}")
                else
                    contextsprint(ctxcatcodes,"\\xmlw{",cmd,"}{",name,"::",ix,"}")
                end
            end
        elseif otherwise then
            contextsprint(ctxcatcodes,"\\xmlw{",otherwise,"}{#1}")
        end
    end

end

-- local wildcards = setmetatableindex(function(t,k)
--     local v = false
--     if find(k,"*",1,true) then
--         v = setmetatableindex(function(t,kk)
--             local v = gsub(k,"%*",kk)
--             t[k] = v
--          -- report_lxml("wildcard %a key %a value %a",kk,k,v)
--             return v
--         end)
--     end
--     t[k] = v
--     return v
-- end)
--
-- local function command(collected,cmd,otherwise)
--     local n = collected and #collected
--     if n and n > 0 then
--         local wildcard = wildcards[cmd]
--         for c=1,n do -- maybe optimize for n=1
--             local e = collected[c]
--             local ix = e.ix
--             local name = e.name
--             if name and not ix then
--                 addindex(name,false,true)
--                 ix = e.ix
--             end
--             if not ix or not name then
--                 report_lxml("no valid node index for element %a using command %s",name or "?",cmd)
--             elseif wildcard then
--                 contextsprint(ctxcatcodes,"\\xmlw{",wildcard[e.tg],"}{",name,"::",ix,"}")
--             else
--                 contextsprint(ctxcatcodes,"\\xmlw{",cmd,"}{",name,"::",ix,"}")
--             end
--         end
--     elseif otherwise then
--         contextsprint(ctxcatcodes,"\\xmlw{",otherwise,"}{#1}")
--     end
-- end

local function attribute(collected,a,default)
    if collected and #collected > 0 then
        local at = collected[1].at
        local str = (at and at[a]) or default
        if str and str ~= "" then
            contextsprint(notcatcodes,str)
        end
    elseif default then
        contextsprint(notcatcodes,default)
    end
end

local function parameter(collected,p,default)
    if collected and #collected > 0 then
        local pa = collected[1].pa
        local str = (pa and pa[p]) or default
        if str and str ~= "" then
            contextsprint(notcatcodes,str)
        end
    elseif default then
        contextsprint(notcatcodes,default)
    end
end

local function chainattribute(collected,arguments,default) -- todo: optional levels
    if collected and #collected > 0 then
        local e = collected[1]
        while e do
            local at = e.at
            if at then
                local a = at[arguments]
                if a then
                    contextsprint(notcatcodes,a)
                    return
                end
            else
                break -- error
            end
            e = e.__p__
        end
    end
    if default then
        contextsprint(notcatcodes,default)
    end
end

local function chainpath(collected,nonamespace)
    if collected and #collected > 0 then
        local e = collected[1]
        local t = { }
        while e do
            local tg = e.tg
            local rt = e.__p__
            local ns = e.ns
            if tg == "@rt@" then
                break
            elseif rt.tg == "@rt@" then
                if nonamespace or not ns or ns == "" then
                    t[#t+1] = tg
                else
                    t[#t+1] = ns .. ":" .. tg
                end
            else
                if nonamespace or not ns or ns == "" then
                    t[#t+1] = tg .. "[" .. e.ei .. "]"
                else
                    t[#t+1] = ns .. ":" .. tg .. "[" .. e.ei .. "]"
                end
            end
            e = rt
        end
        contextsprint(notcatcodes,concat(reversed(t),"/"))
    end
end

local function text(collected)
    if collected then
        local nc = #collected
        if nc == 0 then
            -- nothing
        elseif nc == 1 then -- hardly any gain so this will go
            cprint(collected[1])
        else for c=1,nc do
            cprint(collected[c])
        end end
    end
end

local function ctxtext(collected)
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                contextsprint(ctxcatcodes,collected[c].dt)
            end
        end
    end
end

local function stripped(collected) -- tricky as we strip in place
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                cprint(xmlstripelement(collected[c]))
            end
        end
    end
end

local function lower(collected)
    if not collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                contextsprint(ctxcatcodes,lowerchars(collected[c].dt[1]))
            end
        end
    end
end

local function upper(collected)
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                contextsprint(ctxcatcodes,upperchars(collected[c].dt[1]))
            end
        end
    end
end

local function number(collected)
    local nc = collected and #collected or 0
    local n = 0
    if nc > 0 then
        for c=1,nc do
            n = n + tonumber(collected[c].dt[1] or 0)
        end
    end
    contextsprint(ctxcatcodes,n)
end

local function concatrange(collected,start,stop,separator,lastseparator,textonly) -- test this on mml
    if collected then
        local nofcollected = #collected
        if nofcollected > 0 then
            local separator = separator or ""
            local lastseparator = lastseparator or separator or ""
            start, stop = (start == "" and 1) or tonumber(start) or 1, (stop == "" and nofcollected) or tonumber(stop) or nofcollected
            if stop < 0 then stop = nofcollected + stop end -- -1 == last-1
            for i=start,stop do
                if textonly then
                    xmlcprint(collected[i])
                else
                    xmlsprint(collected[i])
                end
                if i == nofcollected then
                    -- nothing
                elseif i == nofcollected-1 and lastseparator ~= "" then
                    contextsprint(ctxcatcodes,lastseparator)
                elseif separator ~= "" then
                    contextsprint(ctxcatcodes,separator)
                end
            end
        end
    end
end

local function concatlist(collected,separator,lastseparator,textonly) -- test this on mml
    concatrange(collected,false,false,separator,lastseparator,textonly)
end

texfinalizers.first          = first
texfinalizers.last           = last
texfinalizers.all            = all
texfinalizers.reverse        = reverse
texfinalizers.count          = count
texfinalizers.command        = command
texfinalizers.attribute      = attribute
texfinalizers.param          = parameter
texfinalizers.parameter      = parameter
texfinalizers.text           = text
texfinalizers.stripped       = stripped
texfinalizers.lower          = lower
texfinalizers.upper          = upper
texfinalizers.ctxtext        = ctxtext
texfinalizers.context        = ctxtext
texfinalizers.position       = position
texfinalizers.match          = match
texfinalizers.index          = index
texfinalizers.concat         = concatlist
texfinalizers.concatrange    = concatrange
texfinalizers.chainattribute = chainattribute
texfinalizers.chainpath      = chainpath
texfinalizers.default        = all -- !!

function texfinalizers.tag(collected,n)
    if collected then
        local nc = #collected
        if nc > 0 then
            n = tonumber(n) or 0
            local c
            if n == 0 then
                c = collected[1]
            elseif n > 1 then
                c = collected[n]
            else
                c = collected[nc-n+1]
            end
            if c then
                contextsprint(ctxcatcodes,c.tg)
            end
        end
    end
end

function texfinalizers.name(collected,n)
    if collected then
        local nc = #collected
        if nc > 0 then
            local c
            if n == 0 or not n then
                c = collected[1]
            elseif n > 1 then
                c = collected[n]
            else
                c = collected[nc-n+1]
            end
            if c then
                local ns = c.ns
                if not ns or ns == "" then
                    contextsprint(ctxcatcodes,c.tg)
                else
                    contextsprint(ctxcatcodes,ns,":",c.tg)
                end
            end
        end
    end
end

function texfinalizers.tags(collected,nonamespace)
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                local e = collected[c]
                local ns = e.ns
                if nonamespace or (not ns or ns == "") then
                    contextsprint(ctxcatcodes,e.tg)
                else
                    contextsprint(ctxcatcodes,ns,":",e.tg)
                end
            end
        end
    end
end

--

local function verbatim(id,before,after)
    local e = getid(id)
    if e then
        if before then contextsprint(ctxcatcodes,before,"[",e.tg or "?","]") end
        lxml.toverbatim(xmltostring(e.dt)) -- lxml.toverbatim(xml.totext(e.dt))
        if after then contextsprint(ctxcatcodes,after) end
    end
end

function lxml.inlineverbatim(id)
    verbatim(id,"\\startxmlinlineverbatim","\\stopxmlinlineverbatim")
end

function lxml.displayverbatim(id)
    verbatim(id,"\\startxmldisplayverbatim","\\stopxmldisplayverbatim")
end

lxml.verbatim = verbatim

-- helpers

function lxml.first(id,pattern)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        first(collected)
    end
end

function lxml.last(id,pattern)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        last(collected)
    end
end

function lxml.all(id,pattern)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        all(collected)
    end
end

function lxml.count(id,pattern)
    -- always needs to produce a result so no test here
    count(xmlapplylpath(getid(id),pattern))
end

function lxml.attribute(id,pattern,a,default)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        attribute(collected,a,default)
    end
end

function lxml.parameter(id,pattern,p,default)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        parameter(collected,p,default)
    end
end

lxml.param = lxml.parameter

function lxml.raw(id,pattern) -- the content, untouched by commands
    local collected = (pattern and xmlapplylpath(getid(id),pattern)) or getid(id)
    if collected and #collected > 0 then
        local s = xmltostring(collected[1].dt)
        if s ~= "" then
            contextsprint(notcatcodes,s)
        end
    end
end

-- templates

function lxml.rawtex(id,pattern) -- the content, untouched by commands
    local collected = (pattern and xmlapplylpath(getid(id),pattern)) or getid(id)
    if collected and #collected > 0 then
        local s = xmltostring(collected[1].dt)
        if s ~= "" then
            contextsprint(notcatcodes,lpegmatch(p_texescape,s) or s)
        end
    end
end

function lxml.context(id,pattern) -- the content, untouched by commands
    if pattern then
        local collected = xmlapplylpath(getid(id),pattern)
        if collected and #collected > 0 then
            ctx_text(collected[1].dt[1])
        end
    else
        local collected = getid(id)
        if collected then
            local dt = collected.dt
            if dt and #dt > 0 then
                ctx_text(dt[1])
            end
        end
    end
end

function lxml.text(id,pattern)
    if pattern then
        local collected = xmlapplylpath(getid(id),pattern)
        if collected and #collected > 0 then
            text(collected)
        end
    else
        local e = getid(id)
        if e then
            text(e.dt)
        end
    end
end

function lxml.pure(id,pattern)
    if pattern then
        local collected = xmlapplylpath(getid(id),pattern)
        if collected and #collected > 0 then
            parsedentity = unescapedentity
            text(collected)
            parsedentity = reparsedentity
        end
    else
        parsedentity = unescapedentity
        local e = getid(id)
        if e then
            text(e.dt)
        end
        parsedentity = reparsedentity
    end
end

lxml.content = text

function lxml.position(id,pattern,n)
    position(xmlapplylpath(getid(id),pattern),tonumber(n))
end

function lxml.chainattribute(id,pattern,a,default)
    chainattribute(xmlapplylpath(getid(id),pattern),a,default)
end

function lxml.path(id,pattern,nonamespace)
    chainpath(xmlapplylpath(getid(id),pattern),nonamespace)
end

function lxml.concatrange(id,pattern,start,stop,separator,lastseparator,textonly) -- test this on mml
    concatrange(xmlapplylpath(getid(id),pattern),start,stop,separator,lastseparator,textonly)
end

function lxml.concat(id,pattern,separator,lastseparator,textonly)
    concatrange(xmlapplylpath(getid(id),pattern),false,false,separator,lastseparator,textonly)
end

function lxml.element(id,n)
    position(xmlapplylpath(getid(id),"/*"),tonumber(n)) -- tonumber handy
end

lxml.index = lxml.position

function lxml.pos(id)
    local e = getid(id)
    contextsprint(ctxcatcodes,e and e.ni or 0)
end

do

    local att

    function lxml.att(id,a,default)
        local e = getid(id)
        if e then
            local at = e.at
            if at then
                -- normally always true
                att = at[a]
                if not att then
                    if default and default ~= "" then
                        att = default
                        contextsprint(notcatcodes,default)
                    end
                elseif att ~= "" then
                    contextsprint(notcatcodes,att)
                else
                    -- explicit empty is valid
                end
            elseif default and default ~= "" then
                att = default
                contextsprint(notcatcodes,default)
            end
        elseif default and default ~= "" then
            att = default
            contextsprint(notcatcodes,default)
        else
            att = ""
        end
    end

    function lxml.refatt(id,a)
        local e = getid(id)
        if e then
            local at = e.at
            if at then
                att = at[a]
                if att and att ~= "" then
                    att = gsub(att,"^#+","")
                    if att ~= "" then
                        contextsprint(notcatcodes,att)
                        return
                    end
                end
            end
        end
        att = ""
    end

    function lxml.lastatt()
        contextsprint(notcatcodes,att)
    end

    local ctx_doif     = commands.doif
    local ctx_doifnot  = commands.doifnot
    local ctx_doifelse = commands.doifelse

    implement {
        name      = "xmldoifatt",
        arguments = "3 strings",
        actions = function(id,k,v)
            local e = getid(id)
            ctx_doif(e and e.at[k] == v or false)
        end
    }

    implement {
        name      = "xmldoifnotatt",
        arguments = "3 strings",
        actions = function(id,k,v)
            local e = getid(id)
            ctx_doifnot(e and e.at[k] == v or false)
        end
    }

    implement {
        name      = "xmldoifelseatt",
        arguments = "3 strings",
        actions = function(id,k,v)
            local e = getid(id)
            ctx_doifelse(e and e.at[k] == v or false)
        end
    }

end

do

    local par

    function lxml.par(id,p,default)
        local e = getid(id)
        if e then
            local pa = e.pa
            if pa then
                -- normally always true
                par = pa[p]
                if not par then
                    if default and default ~= "" then
                        par = default
                        contextsprint(notcatcodes,default)
                    end
                elseif par ~= "" then
                    contextsprint(notcatcodes,par)
                else
                    -- explicit empty is valid
                end
            elseif default and default ~= "" then
                par = default
                contextsprint(notcatcodes,default)
            end
        elseif default and default ~= "" then
            par = default
            contextsprint(notcatcodes,default)
        else
            par = ""
        end
    end

    function lxml.lastpar()
        contextsprint(notcatcodes,par)
    end

end

function lxml.name(id)
    local e = getid(id)
    if e then
        local ns = e.rn or e.ns
        if ns and ns ~= "" then
            contextsprint(ctxcatcodes,ns,":",e.tg)
        else
            contextsprint(ctxcatcodes,e.tg)
        end
    end
end

function lxml.match(id)
    local e = getid(id)
    contextsprint(ctxcatcodes,e and e.mi or 0)
end

function lxml.tag(id) -- tag vs name -> also in l-xml tag->name
    local e = getid(id)
    if e then
        local tg = e.tg
        if tg and tg ~= "" then
            contextsprint(ctxcatcodes,tg)
        end
    end
end

function lxml.namespace(id)
    local e = getid(id)
    if e then
        local ns = e.rn or e.ns
        if ns and ns ~= "" then
            contextsprint(ctxcatcodes,ns)
        end
    end
end

function lxml.flush(id)
    local e = getid(id)
    if e then
        local dt = e.dt
        if dt then
            xmlsprint(dt,e)
        end
    end
end

function lxml.lastmatch()
    local collected = xmllastmatch()
    if collected then
        all(collected)
    end
end

lxml.pushmatch = xmlpushmatch
lxml.popmatch  = xmlpopmatch

function lxml.snippet(id,i)
    local e = getid(id)
    if e then
        local dt = e.dt
        if dt then
            local dti = dt[i]
            if dti then
                xmlsprint(dti,e)
            end
        end
    end
end

function lxml.direct(id)
    local e = getid(id)
    if e then
        xmlsprint(e)
    end
end

if tokenizedxmlw then

    function lxml.command(id,pattern,cmd)
        local i, p = getid(id,true)
        local collected = xmlapplylpath(getid(i),pattern) -- again getid?
        if collected then
            local nc = #collected
            if nc > 0 then
                local rootname = p or i.name
                for c=1,nc do
                    local e = collected[c]
                    local ix = e.ix
                    if not ix then
                        addindex(rootname,false,true)
                        ix = e.ix
                    end
                    contextsprint(ctxcatcodes,tokenizedxmlw,"{",cmd,"}{",rootname,"::",ix,"}")
                end
            end
        end
    end

else

    function lxml.command(id,pattern,cmd)
        local i, p = getid(id,true)
        local collected = xmlapplylpath(getid(i),pattern) -- again getid?
        if collected then
            local nc = #collected
            if nc > 0 then
                local rootname = p or i.name
                for c=1,nc do
                    local e = collected[c]
                    local ix = e.ix
                    if not ix then
                        addindex(rootname,false,true)
                        ix = e.ix
                    end
                    contextsprint(ctxcatcodes,"\\xmlw{",cmd,"}{",rootname,"::",ix,"}")
                end
            end
        end
    end

end

-- loops

function lxml.collected(id,pattern,reverse)
    return xmlcollected(getid(id),pattern,reverse)
end

function lxml.elements(id,pattern,reverse)
    return xmlelements(getid(id),pattern,reverse)
end

-- testers

do

    local found, empty = xml.found, xml.empty

    local doif, doifnot, doifelse = commands.doif, commands.doifnot, commands.doifelse

    function lxml.doif         (id,pattern) doif    (found(getid(id),pattern)) end
    function lxml.doifnot      (id,pattern) doifnot (found(getid(id),pattern)) end
    function lxml.doifelse     (id,pattern) doifelse(found(getid(id),pattern)) end
    function lxml.doiftext     (id,pattern) doif    (not empty(getid(id),pattern)) end
    function lxml.doifnottext  (id,pattern) doifnot (not empty(getid(id),pattern)) end
    function lxml.doifelsetext (id,pattern) doifelse(not empty(getid(id),pattern)) end

    -- special case: "*" and "" -> self else lpath lookup

    local function checkedempty(id,pattern)
        local e = getid(id)
        if not pattern or pattern == "" then
            local dt = e.dt
            local nt = #dt
            return (nt == 0) or (nt == 1 and dt[1] == "")
        else
            return empty(getid(id),pattern)
        end
    end

    function lxml.doifempty    (id,pattern) doif    (checkedempty(id,pattern)) end
    function lxml.doifnotempty (id,pattern) doifnot (checkedempty(id,pattern)) end
    function lxml.doifelseempty(id,pattern) doifelse(checkedempty(id,pattern)) end

end

-- status info

statistics.register("xml load time", function()
    if noffiles > 0 or nofconverted > 0 then
        return format("%s seconds, %s files, %s converted", statistics.elapsedtime(xml), noffiles, nofconverted)
    else
        return nil
    end
end)

statistics.register("lxml preparation time", function()
    if noffiles > 0 or nofconverted > 0 then
        local calls  = xml.lpathcalls()
        local cached = xml.lpathcached()
        if calls > 0 or cached > 0 then
            return format("%s seconds, %s nodes, %s lpath calls, %s cached calls",
                statistics.elapsedtime(lxml), nofindices, calls, cached)
        else
            return nil
        end
    else
        -- pretty close to zero so not worth mentioning
    end
end)

statistics.register("lxml lpath profile", function()
    local p = xml.profiled
    if p and next(p) then
        local s = table.sortedkeys(p)
        local tested, matched, finalized = 0, 0, 0
        logs.pushtarget("logfile")
        logs.writer("\nbegin of lxml profile\n")
        logs.writer("\n   tested    matched  finalized    pattern\n\n")
        for i=1,#s do
            local pattern = s[i]
            local pp = p[pattern]
            local t, m, f = pp.tested, pp.matched, pp.finalized
            tested, matched, finalized = tested + t, matched + m, finalized + f
            logs.writer(format("%9i  %9i  %9i    %s",t,m,f,pattern))
        end
        logs.writer("\nend of lxml profile\n")
        logs.poptarget()
        return format("%s patterns, %s tested, %s matched, %s finalized (see log for details)",#s,tested,matched,finalized)
    else
        return nil
    end
end)

-- misc

function lxml.nonspace(id,pattern) -- slow, todo loop
    xmltprint(xmlcollect(getid(id),pattern,true))
end

function lxml.strip(id,pattern,nolines,anywhere)
    xml.strip(getid(id),pattern,nolines,anywhere)
end

function lxml.stripped(id,pattern,nolines)
    local root = getid(id)
    local str = xmltext(root,pattern) or ""
    str = gsub(str,"^%s*(.-)%s*$","%1")
    if nolines then
        str = gsub(str,"%s+"," ")
    end
    xmlsprint(str,root)
end

function lxml.delete(id,pattern)
    xml.delete(getid(id),pattern)
end

lxml.obsolete = { }

lxml.get_id = getid   lxml.obsolete.get_id = getid

-- goodies:

function texfinalizers.lettered(collected)
    if collected then
        local nc = #collected
        if nc > 0 then
            for c=1,nc do
                contextsprint(ctxcatcodes,lettered(collected[c].dt[1]))
            end
        end
    end
end

-- function texfinalizers.apply(collected,what) -- to be tested
--     if collected then
--         for c=1,#collected do
--             contextsprint(ctxcatcodes,what(collected[c].dt[1]))
--         end
--     end
-- end

function lxml.toparameters(id)
    local e = getid(id)
    if e then
        local a = e.at
        if a and next(a) then
            local setups, s = { }, 0
            for k, v in next, a do
                s = s + 1
                setups[s] = k .. "=" .. v
            end
            setups = concat(setups,",")
            -- tracing
            context(setups)
        end
    end
end

local template = '<?xml version="1.0" ?>\n\n<!-- %s -->\n\n%s'

function lxml.tofile(id,pattern,filename,comment)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        io.savedata(filename,format(template,comment or "exported fragment",tostring(collected[1])))
    else
        os.remove(filename) -- get rid of old content
    end
end

texfinalizers.upperall = xmlfinalizers.upperall
texfinalizers.lowerall = xmlfinalizers.lowerall

function lxml.tobuffer(id,pattern,name,unescaped,contentonly)
    local collected = xmlapplylpath(getid(id),pattern)
    if collected then
        local collected = collected[1]
        if unescaped == true then
            -- expanded entities !
            if contentonly then
                collected = xmlserializetotext(collected.dt)
            else
                collected = xmlcontent(collected)
            end
        elseif unescaped == false then
            local t = { }
            xmlstring(collected,function(s) t[#t+1] = s end)
            collected = concat(t)
        else
            collected = tostring(collected)
        end
        buffers.assign(name,collected)
    else
        buffers.erase(name)
    end
end

-- parameters

do

    local function setatt(id,name,value)
        local e = getid(id)
        if e then
            local a = e.at
            if a then
                a[name] = value
            else
                e.at = { [name] = value }
            end
        end
    end

    local function setpar(id,name,value)
        local e = getid(id)
        if e then
            local p = e.pa
            if p then
                p[name] = value
            else
                e.pa = { [name] = value }
            end
        end
    end

    lxml.setatt = setatt
    lxml.setpar = setpar

    function lxml.setattribute(id,pattern,name,value)
        local collected = xmlapplylpath(getid(id),pattern)
        if collected then
            for i=1,#collected do
                setatt(collected[i],name,value)
            end
        end
    end

    function lxml.setparameter(id,pattern,name,value)
        local collected = xmlapplylpath(getid(id),pattern)
        if collected then
            for i=1,#collected do
                setpar(collected[i],name,value)
            end
        end
    end

    lxml.setparam = lxml.setparameter

end

-- relatively new:

do

    local permitted        = nil
    local ctx_xmlinjector  = context.xmlinjector

    xml.pihandlers["injector"] = function(category,rest,e)
        local options = options_to_array(rest)
        local action  = options[1]
        if not action then
            return
        end
        local n = #options
        if n > 1 then
            local category = options[2]
            if category == "*" then
                ctx_xmlinjector(action)
            elseif permitted then
                if n == 2 then
                    if permitted[category] then
                        ctx_xmlinjector(action)
                    end
                else
                    for i=2,n do
                        local category = options[i]
                        if category == "*" or permitted[category] then
                            ctx_xmlinjector(action)
                            return
                        end
                    end
                end
            end
        else
            ctx_xmlinjector(action)
        end
    end

    local pattern = P("context-") * C((1-patterns.whitespace)^1) * C(P(1)^1)

    function lxml.applyselectors(id)
        local root = getid(id)
        local function filter(e)
            local dt = e.dt
            if not dt then
                report_lxml("error in selector, no data in %a",e.tg or "?")
                return
            end
            local ndt  = #dt
            local done = false
            local i = 1
            while i <= ndt do
                local dti = dt[i]
                if type(dti) == "table" then
                    if dti.tg == "@pi@" then
                        local text = dti.dt[1]
                        local what, rest = lpegmatch(pattern,text)
                        if what == "select" then
                            local categories = options_to_hash(rest)
                            if categories["begin"] then
                                local okay = false
                                if permitted then
                                    for k, v in next, permitted do
                                        if categories[k] then
                                            okay = k
                                            break
                                        end
                                    end
                                end
                                if okay then
                                    if trace_selectors then
                                        report_lxml("accepting selector: %s",okay)
                                    end
                                else
                                    categories.begin = false
                                    if trace_selectors then
                                        report_lxml("rejecting selector: % t",sortedkeys(categories))
                                    end
                                end
                                for j=i,ndt do
                                    local dtj = dt[j]
                                    if type(dtj) == "table" then
                                        local tg = dtj.tg
                                        if tg == "@pi@" then
                                            local text = dtj.dt[1]
                                            local what, rest = lpegmatch(pattern,text)
                                            if what == "select" then
                                                local categories = options_to_hash(rest)
                                                if categories["end"] then
                                                    i = j
                                                    break
                                                else
                                                    -- error
                                                end
                                            end
                                        elseif not okay then
                                            dtj.tg = "@cm@"
                                        end
                                    else
    --                                     dt[j] = "" -- okay ?
                                    end
                                end
                            end
                        elseif what == "include" then
                            local categories = options_to_hash(rest)
                            if categories["begin"] then
                                local okay = false
                                if permitted then
                                    for k, v in next, permitted do
                                        if categories[k] then
                                            okay = k
                                            break
                                        end
                                    end
                                end
                                if okay then
                                    if trace_selectors then
                                        report_lxml("accepting include: %s",okay)
                                    end
                                else
                                    categories.begin = false
                                    if trace_selectors then
                                        report_lxml("rejecting include: % t",sortedkeys(categories))
                                    end
                                end
                                if okay then
                                    for j=i,ndt do
                                        local dtj = dt[j]
                                        if type(dtj) == "table" then
                                            local tg = dtj.tg
                                            if tg == "@cm@" then
                                                local content = dtj.dt[1]
                                                local element = root and xml.toelement(content,root)
                                                dt[j] = element
                                                element.__p__ = dt -- needs checking
                                                done = true
                                            elseif tg == "@pi@" then
                                                local text = dtj.dt[1]
                                                local what, rest = lpegmatch(pattern,text)
                                                if what == "include" then
                                                    local categories = options_to_hash(rest)
                                                    if categories["end"] then
                                                        i = j
                                                        break
                                                    else
                                                        -- error
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        elseif dti then
                            filter(dti)
                        end
                    end
                    if done then
                        -- probably not needed
                        xml.reindex(dt)
                    end
                end
                i = i + 1
            end
        end
        xmlwithelements(root,filter)
    end

    function xml.setinjectors(set)
        local s = settings_to_set(set)
        if permitted then
            for k, v in next, s do
                permitted[k] = true
            end
        else
            permitted = s
        end
    end

    function xml.resetinjectors(set)
        if permitted and set and set ~= "" then
            local s = settings_to_set(set)
            for k, v in next, s do
                if v then
                    permitted[k] = nil
                end
            end
        else
            permitted = nil
        end
    end

end

implement {
    name      = "xmlsetinjectors",
    actions   = xml.setinjectors,
    arguments = "string"
}

implement {
    name      = "xmlresetinjectors",
    actions   = xml.resetinjectors,
    arguments = "string"
}

implement {
    name      = "xmlapplyselectors",
    actions   = lxml.applyselectors,
    arguments = "string"
}

-- bonus: see x-lmx-html.mkiv

function texfinalizers.xml(collected,name,setup)
    local root = collected[1]
    if not root then
        return
    end
    if not name or name == "" then
        report_lxml("missing name in xml finalizer")
        return
    end
    xmlrename(root,name)
    name = "lmx:" .. name
    buffers.assign(name,strip(xmltostring(root)))
    context.xmlprocessbuffer(name,name,setup or (name..":setup"))
end

-- experiment

do

    local xmltoelement = xml.toelement
    local xmlreindex   = xml.reindex

    function lxml.replace(root,pattern,whatever)
        if type(root) == "string" then
            root = lxml.getid(root)
        end
        local collected = xmlapplylpath(root,pattern)
        if collected then
            local isstring = type(whatever) == "string"
            for c=1,#collected do
                local e = collected[c]
                local p = e.__p__
                if p then
                    local d = p.dt
                    local n = e.ni
                    local w = isstring and whatever or whatever(e)
                    if w then
                        local t = xmltoelement(w,root).dt
                        if t then
                            t.__p__ = p
                            if type(t) == "table" then
                                local t1 = t[1]
                                d[n] = t1
                                t1.at.type = e.at.type or t1.at.type
                                for i=2,#t do
                                    n = n + 1
                                    insert(d,n,t[i])
                                end
                            else
                                d[n] = t
                            end
                            xmlreindex(d) -- probably not needed
                        end
                    end
                end
            end
        end
    end

    -- function document.mess_around(root)
    --     lxml.replace(
    --         root,
    --         "p[@variant='foo']",
    --         function(c)
    --             return (string.gsub(tostring(c),"foo","<bar>%1</bar>"))
    --         end
    --     )
    -- end

end
