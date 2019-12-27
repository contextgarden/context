if not modules then modules = { } end modules ['file-job'] = {
    version   = 1.001,
    comment   = "companion to file-job.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- in retrospect dealing it's not that bad to deal with the nesting
-- and push/poppign at the tex end

local next, rawget, tostring, tonumber = next, rawget, tostring, tonumber
local gsub, match, find = string.gsub, string.match, string.find
local insert, remove, concat = table.insert, table.remove, table.concat
local validstring, formatters = string.valid, string.formatters
local sortedhash = table.sortedhash
local setmetatableindex, setmetatablenewindex = table.setmetatableindex, table.setmetatablenewindex

local commands          = commands
local resolvers         = resolvers
local context           = context

local ctx_doifelse      = commands.doifelse

local implement         = interfaces.implement

local trace_jobfiles    = false  trackers.register("system.jobfiles", function(v) trace_jobfiles = v end)

local report            = logs.reporter("system")
local report_jobfiles   = logs.reporter("system","jobfiles")
local report_functions  = logs.reporter("system","functions")

local texsetcount       = tex.setcount
local elements          = interfaces.elements
local constants         = interfaces.constants
local variables         = interfaces.variables
local settings_to_array = utilities.parsers.settings_to_array
local allocate          = utilities.storage.allocate

local nameonly          = file.nameonly
local suffixonly        = file.suffix
local basename          = file.basename
local addsuffix         = file.addsuffix
local removesuffix      = file.removesuffix
local dirname           = file.dirname
local is_qualified_path = file.is_qualified_path

local cleanpath         = resolvers.cleanpath
local toppath           = resolvers.toppath
local resolveprefix     = resolvers.resolve

local hasscheme         = url.hasscheme

local jobresolvers      = resolvers.jobs

local registerextrapath = resolvers.registerextrapath
local resetextrapaths   = resolvers.resetextrapaths
local getextrapaths     = resolvers.getextrapath
local pushextrapath     = resolvers.pushextrapath
local popextrapath      = resolvers.popextrapath

----- v_outer           = variables.outer
local v_text            = variables.text
local v_project         = variables.project
local v_environment     = variables.environment
local v_product         = variables.product
local v_component       = variables.component
local v_yes             = variables.yes

-- main code .. there is some overlap .. here we have loc://

local function findctxfile(name) -- loc ? any ?
    if is_qualified_path(name) then -- maybe when no suffix do some test for tex
        return name
    elseif not hasscheme(name) then
        return resolvers.finders.byscheme("loc",name) or ""
    else
        return resolvers.findtexfile(name) or ""
    end
end

resolvers.findctxfile = findctxfile

implement {
    name      = "processfile",
    arguments = "string",
    actions   = function(name)
        name = findctxfile(name)
        if name ~= "" then
            context.input(name)
        end
    end
}

implement {
    name      = "doifelseinputfile",
    arguments = "string",
    actions   = function(name)
        ctx_doifelse(findctxfile(name) ~= "")
    end
}

implement {
    name      = "locatefilepath",
    arguments = "string",
    actions   = function(name)
        context(dirname(findctxfile(name)))
    end
}

implement {
    name      = "usepath",
    arguments = "string",
    actions   = function(paths)
        report_jobfiles("using path: %s",paths)
        registerextrapath(paths)
    end
}

implement {
    name      = "pushpath",
    arguments = "string",
    actions   = function(paths)
        report_jobfiles("pushing path: %s",paths)
        pushextrapath(paths)
    end
}

implement {
    name      = "poppath",
    actions   = function(paths)
        popextrapath()
        report_jobfiles("popping path")
    end
}

implement {
    name      = "usesubpath",
    arguments = "string",
    actions   = function(subpaths)
        report_jobfiles("using subpath: %s",subpaths)
        registerextrapath(nil,subpaths)
    end
}

implement {
    name      = "resetpath",
    actions   = function()
        report_jobfiles("resetting path")
        resetextrapaths()
    end
}

implement {
    name      = "allinputpaths",
    actions   = function()
        context(concat(getextrapaths(),","))
    end
}

implement {
    name      = "usezipfile",
    arguments = "2 strings",
    actions   = function(name,tree)
        if tree and tree ~= "" then
            resolvers.usezipfile(formatters["zip:///%s?tree=%s"](name,tree))
        else
            resolvers.usezipfile(formatters["zip:///%s"](name))
        end
    end
}

-- moved from tex to lua:

local texpatterns = { "%s.mkvi", "%s.mkiv", "%s.mklx", "%s.mkxl", "%s.tex" }
local luapatterns = { "%s" .. utilities.lua.suffixes.luc, "%s.lua", "%s.lmt" }
local cldpatterns = { "%s.cld" }
local xmlpatterns = { "%s.xml" }

local uselibrary = resolvers.uselibrary
local input      = context.input

-- status
--
-- these need to be synced with input stream:

local processstack   = { }
local processedfile  = ""
local processedfiles = { }

implement {
    name    = "processedfile",
    actions = function()
        context(processedfile)
    end
}

implement {
    name    = "processedfiles",
    actions = function()
        context(concat(processedfiles,","))
    end
}

implement {
    name      = "dostarttextfile",
    arguments = "string",
    actions   = function(name)
        insert(processstack,name)
        processedfile = name
        insert(processedfiles,name)
    end
}

implement {
    name      = "dostoptextfile",
    actions   = function()
        processedfile = remove(processstack) or ""
    end
}

local function startprocessing(name,notext)
    if not notext then
     -- report("begin file %a at line %a",name,status.linenumber or 0)
        context.dostarttextfile(name)
    end
end

local function stopprocessing(notext)
    if not notext then
        context.dostoptextfile()
     -- report("end file %a at line %a",name,status.linenumber or 0)
    end
end

--

local typestack   = { }
local currenttype = v_text
local nofmissing  = 0
local missing     = {
    tex = setmetatableindex("number"),
    lua = setmetatableindex("number"),
    cld = setmetatableindex("number"),
    xml = setmetatableindex("number"),
}

local function reportfailure(kind,name)
    nofmissing = nofmissing + 1
    missing[kind][name] = true
    report_jobfiles("unknown %s file %a",kind,name)
end

--

local function action(name,foundname)
    input(foundname)
end
local function failure(name,foundname)
    reportfailure("tex",name)
end
local function usetexfile(name,onlyonce,notext)
    startprocessing(name,notext)
    uselibrary {
        name     = name,
        patterns = texpatterns,
        action   = action,
        failure  = failure,
        onlyonce = onlyonce,
    }
    stopprocessing(notext)
end

local function action(name,foundname)
    dofile(foundname)
end
local function failure(name,foundname)
    reportfailure("lua",name)
end
local function useluafile(name,onlyonce,notext)
    uselibrary {
        name     = name,
        patterns = luapatterns,
        action   = action,
        failure  = failure,
        onlyonce = onlyonce,
    }
end

local function action(name,foundname)
    dofile(foundname)
end
local function failure(name,foundname)
    reportfailure("cld",name)
end
local function usecldfile(name,onlyonce,notext)
    startprocessing(name,notext)
    uselibrary {
        name     = name,
        patterns = cldpatterns,
        action   = action,
        failure  = failure,
        onlyonce = onlyonce,
    }
    stopprocessing(notext)
end

local function action(name,foundname)
    context.xmlprocess(foundname,"main","")
end
local function failure(name,foundname)
    reportfailure("xml",name)
end
local function usexmlfile(name,onlyonce,notext)
    startprocessing(name,notext)
    uselibrary {
        name     = name,
        patterns = xmlpatterns,
        action   = action,
        failure  = failure,
        onlyonce = onlyonce,
    }
    stopprocessing(notext)
end

local suffixes = {
    mkvi = usetexfile,
    mkiv = usetexfile,
    tex  = usetexfile,
    luc  = useluafile,
    lua  = useluafile,
    cld  = usecldfile,
    xml  = usexmlfile,
    [""] = usetexfile,
}

local function useanyfile(name,onlyonce)
    local s = suffixes[suffixonly(name)]
    context(function() resolvers.pushpath(name) end)
    if s then
     -- s(removesuffix(name),onlyonce)
        s(name,onlyonce) -- so, first with suffix, then without
    else
        usetexfile(name,onlyonce) -- e.g. ctx file
     -- resolvers.readfilename(name)
    end
    context(resolvers.poppath)
end

implement { name = "usetexfile",     actions = usetexfile, arguments = "string" }
implement { name = "useluafile",     actions = useluafile, arguments = "string" }
implement { name = "usecldfile",     actions = usecldfile, arguments = "string" }
implement { name = "usexmlfile",     actions = usexmlfile, arguments = "string" }

implement { name = "usetexfileonce", actions = usetexfile, arguments = { "string", true } }
implement { name = "useluafileonce", actions = useluafile, arguments = { "string", true } }
implement { name = "usecldfileonce", actions = usecldfile, arguments = { "string", true } }
implement { name = "usexmlfileonce", actions = usexmlfile, arguments = { "string", true } }

implement { name = "useanyfile",     actions = useanyfile, arguments = "string" }
implement { name = "useanyfileonce", actions = useanyfile, arguments = { "string", true } }

function jobresolvers.usefile(name,onlyonce,notext)
    local s = suffixes[suffixonly(name)]
    if s then
     -- s(removesuffix(name),onlyonce,notext)
        s(name,onlyonce,notext) -- so, first with suffix, then without
    end
end

-- document structure

local textlevel = 0 -- inaccessible for user, we need to define counter textlevel at the tex end

local function dummyfunction() end

local function startstoperror()
    report("invalid \\%s%s ... \\%s%s structure",elements.start,v_text,elements.stop,v_text)
    startstoperror = dummyfunction
end

local stopped

local function starttext()
    if textlevel == 0 then
        if trace_jobfiles then
            report_jobfiles("starting text")
        end
        context.dostarttext()
    end
    textlevel = textlevel + 1
    texsetcount("global","textlevel",textlevel)
end

local function stoptext()
    if not stopped then
        if textlevel == 0 then
            startstoperror()
        elseif textlevel > 0 then
            textlevel = textlevel - 1
        end
        texsetcount("global","textlevel",textlevel)
        if textlevel <= 0 then
            if trace_jobfiles then
                report_jobfiles("stopping text")
            end
            context.dostoptext()
            stopped = true
        end
    end
end

implement { name = "starttext", actions = starttext }
implement { name = "stoptext",  actions = stoptext  }

implement {
    name      = "forcequitjob",
    arguments = "string",
    actions   = function(reason)
        if reason then
            report("forcing quit: %s",reason)
        else
            report("forcing quit")
        end
        context.batchmode()
        while textlevel >= 0 do
            context.stoptext()
        end
    end
}

implement {
    name    = "forceendjob",
    actions = function()
        report([[don't use \end to finish a document]])
        context.stoptext()
    end
}

implement {
    name    = "autostarttext",
    actions = function()
        if textlevel == 0 then
            report([[auto \starttext ... \stoptext]])
        end
        context.starttext()
    end
}

implement {
    name    = "autostoptext",
    actions = stoptext
}

-- project structure

implement {
    name      = "processfilemany",
    arguments = { "string", false },
    actions   = useanyfile
}

implement {
    name      = "processfileonce",
    arguments = { "string", true },
    actions   = useanyfile
}

implement {
    name      = "processfilenone",
    arguments = "string",
    actions   = dummyfunction,
}

local tree               = { type = "text", name = "", branches = { } }
local treestack          = { }
local top                = tree.branches
local root               = tree

local project_stack      = { }
local product_stack      = { }
local component_stack    = { }
local environment_stack  = { }

local stacks = {
    [v_project    ] = project_stack,
    [v_product    ] = product_stack,
    [v_component  ] = component_stack,
    [v_environment] = environment_stack,
}

--

local function pushtree(what,name)
    local t = { }
    top[#top+1] = { type = what, name = name, branches = t }
    insert(treestack,top)
    top = t
end

local function poptree()
    top = remove(treestack)
 -- inspect(top)
end

do

    local function log_tree(report,top,depth)
        report("%s%s: %s",depth,top.type,top.name)
        local branches = top.branches
        if #branches > 0 then
            depth = depth .. "  "
            for i=1,#branches do
                log_tree(report,branches[i],depth)
            end
        end
    end

    logs.registerfinalactions(function()
        root.name = environment.jobname
        --
        logs.startfilelogging(report,"used files")
        log_tree(report,root,"")
        logs.stopfilelogging()
        --
        if nofmissing > 0 and logs.loggingerrors() then
            logs.starterrorlogging(report,"missing files")
            for kind, list in sortedhash(missing) do
                for name in sortedhash(list) do
                    report("%w%s  %s",6,kind,name)
                end
            end
            logs.stoperrorlogging()
        end
    end)

end

local jobstructure      = job.structure or { }
job.structure           = jobstructure
jobstructure.collected  = jobstructure.collected or { }
jobstructure.tobesaved  = root
jobstructure.components = { }

local function initialize()
    local function collect(root,result)
        local branches = root.branches
        if branches then
            for i=1,#branches do
                local branch = branches[i]
                if branch.type == "component" then
                    result[#result+1] = branch.name
                end
                collect(branch,result)
            end
        end
        return result
    end
    jobstructure.components = collect(jobstructure.collected,{})
end

job.register('job.structure.collected',root,initialize)

-- component: small unit, either or not components itself
-- product  : combination of components

local ctx_processfilemany = context.processfilemany
local ctx_processfileonce = context.processfileonce
local ctx_processfilenone = context.processfilenone

-- we need a plug in the nested loaded, push pop pseudo current dir

local function processfilecommon(name,action)
    -- experiment, might go away
--     if not hasscheme(name) then
--         local path = dirname(name)
--         if path ~= "" then
--             registerextrapath(path)
--             report_jobfiles("adding search path %a",path)
--         end
--     end
    -- till here
    action(name)
end

local function processfilemany(name) processfilecommon(name,ctx_processfilemany) end
local function processfileonce(name) processfilecommon(name,ctx_processfileonce) end
local function processfilenone(name) processfilecommon(name,ctx_processfilenone) end

local processors = utilities.storage.allocate {
 -- [v_outer] = {
 --     [v_text]        = { "many", processfilemany },
 --     [v_project]     = { "once", processfileonce },
 --     [v_environment] = { "once", processfileonce },
 --     [v_product]     = { "once", processfileonce },
 --     [v_component]   = { "many", processfilemany },
 -- },
    [v_text] = {
        [v_text]        = { "many", processfilemany },
        [v_project]     = { "once", processfileonce }, -- dubious
        [v_environment] = { "once", processfileonce },
        [v_product]     = { "many", processfilemany }, -- dubious
        [v_component]   = { "many", processfilemany },
    },
    [v_project] = {
        [v_text]        = { "many", processfilemany },
        [v_project]     = { "none", processfilenone },
        [v_environment] = { "once", processfileonce },
        [v_product]     = { "none", processfilenone },
        [v_component]   = { "none", processfilenone },
    },
    [v_environment] = {
        [v_text]        = { "many", processfilemany },
        [v_project]     = { "none", processfilenone },
        [v_environment] = { "once", processfileonce },
        [v_product]     = { "none", processfilenone },
        [v_component]   = { "none", processfilenone },
    },
    [v_product] = {
        [v_text]        = { "many", processfilemany },
        [v_project]     = { "once", processfileonce },
        [v_environment] = { "once", processfileonce },
        [v_product]     = { "many", processfilemany },
        [v_component]   = { "many", processfilemany },
    },
    [v_component] = {
        [v_text]        = { "many", processfilemany },
        [v_project]     = { "once", processfileonce },
        [v_environment] = { "once", processfileonce },
        [v_product]     = { "none", processfilenone },
        [v_component]   = { "many", processfilemany },
    }
}

local start = {
    [v_text]        = nil,
    [v_project]     = nil,
    [v_environment] = context.startreadingfile,
    [v_product]     = context.starttext,
    [v_component]   = context.starttext,
}

local stop = {
    [v_text]        = nil,
    [v_project]     = nil,
    [v_environment] = context.stopreadingfile,
    [v_product]     = context.stoptext,
    [v_component]   = context.stoptext,
}

jobresolvers.processors = processors

local function topofstack(what)
    local stack = stacks[what]
    return stack and stack[#stack] or environment.jobname
end

local function productcomponent() -- only when in product
    local product = product_stack[#product_stack]
    if product and product ~= "" then
        local component = component_stack[1]
        if component and component ~= "" then
            return component
        end
    end
end

local function justacomponent()
    local product = product_stack[#product_stack]
    if not product or product == "" then
        local component = component_stack[1]
        if component and component ~= "" then
            return component
        end
    end
end

jobresolvers.productcomponent = productcomponent
jobresolvers.justacomponent   = justacomponent

function jobresolvers.currentproject    () return topofstack(v_project    ) end
function jobresolvers.currentproduct    () return topofstack(v_product    ) end
function jobresolvers.currentcomponent  () return topofstack(v_component  ) end
function jobresolvers.currentenvironment() return topofstack(v_environment) end

local done     = { }
local tolerant = false -- too messy, mkii user with the wrong structure should adapt

local function process(what,name)
    local depth = #typestack
    local process
    --
    name = resolveprefix(name)
    --
--  if not tolerant then
        -- okay, would be best but not compatible with mkii
        process = processors[currenttype][what]
--  elseif depth == 0 then
--      -- could be a component, product or (brr) project
--      if trace_jobfiles then
--          report_jobfiles("%s : %s > %s (case 1)",depth,currenttype,v_outer)
--      end
--      process = processors[v_outer][what]
--  elseif depth == 1 and typestack[1] == v_text then
--      -- we're still not doing a component or product
--      if trace_jobfiles then
--          report_jobfiles("%s : %s > %s (case 2)",depth,currenttype,v_outer)
--      end
--      process = processors[v_outer][what]
--  else
--      process = processors[currenttype][what]
--  end
    if process then
        local method = process[1]
        if method == "none" then
            if trace_jobfiles then
                report_jobfiles("%s : %s : %s %s %a in %s %a",depth,method,"ignoring",what,name,currenttype,topofstack(currenttype))
            end
        elseif method == "once" and done[name] then
            if trace_jobfiles then
                report_jobfiles("%s : %s : %s %s %a in %s %a",depth,method,"skipping",what,name,currenttype,topofstack(currenttype))
            end
        else
            -- keep in mind that we also handle "once" at the file level
            -- so there is a double catch
            done[name] = true
            local before = start[what]
            local after  = stop [what]
            if trace_jobfiles then
                report_jobfiles("%s : %s : %s %s %a in %s %a",depth,method,"processing",what,name,currenttype,topofstack(currenttype))
            end
            if before then
                before()
            end
            process[2](name)
            if after then
                after()
            end
        end
    else
        if trace_jobfiles then
            report_jobfiles("%s : %s : %s %s %a in %s %a",depth,"none","ignoring",what,name,currenttype,topofstack(currenttype))
        end
    end
end

implement { name = "useproject",     actions = function(name) process(v_project,    name) end, arguments = "string" }
implement { name = "useenvironment", actions = function(name) process(v_environment,name) end, arguments = "string" }
implement { name = "useproduct",     actions = function(name) process(v_product,    name) end, arguments = "string" } -- will be overloaded
implement { name = "usecomponent",   actions = function(name) process(v_component,  name) end, arguments = "string" }

-- todo: setsystemmode to currenttype
-- todo: make start/stop commands at the tex end

local start = {
    [v_project]     = context.startprojectindeed,
    [v_product]     = context.startproductindeed,
    [v_component]   = context.startcomponentindeed,
    [v_environment] = context.startenvironmentindeed,
}

local stop = {
    [v_project]     = context.stopprojectindeed,
    [v_product]     = context.stopproductindeed,
    [v_component]   = context.stopcomponentindeed,
    [v_environment] = context.stopenvironmentindeed,
}

local function gotonextlevel(what,name) -- todo: something with suffix name
    insert(stacks[what],name)
    insert(typestack,currenttype)
    currenttype = what
    pushtree(what,name)
    if start[what] then
        start[what]()
    end
end

local function gotopreviouslevel(what)
    if stop[what] then
        stop[what]()
    end
    poptree()
    currenttype = remove(typestack) or v_text
    remove(stacks[what]) -- not currenttype ... weak recovery
 -- context.endinput() -- does not work
    context.signalendofinput(what)
end

local function autoname(name)
    if name == "*" then
        name = nameonly(toppath() or name)
    end
    return name
end

implement { name = "startproject",       actions = function(name) gotonextlevel(v_project,    autoname(name)) end, arguments = "string" }
implement { name = "startproduct",       actions = function(name) gotonextlevel(v_product,    autoname(name)) end, arguments = "string" }
implement { name = "startcomponent",     actions = function(name) gotonextlevel(v_component,  autoname(name)) end, arguments = "string" }
implement { name = "startenvironment",   actions = function(name) gotonextlevel(v_environment,autoname(name)) end, arguments = "string" }

implement { name = "stopproject",        actions = function() gotopreviouslevel(v_project    ) end }
implement { name = "stopproduct",        actions = function() gotopreviouslevel(v_product    ) end }
implement { name = "stopcomponent",      actions = function() gotopreviouslevel(v_component  ) end }
implement { name = "stopenvironment",    actions = function() gotopreviouslevel(v_environment) end }

implement { name = "currentproject",     actions = function() context(topofstack(v_project    )) end }
implement { name = "currentproduct",     actions = function() context(topofstack(v_product    )) end }
implement { name = "currentcomponent",   actions = function() context(topofstack(v_component  )) end }
implement { name = "currentenvironment", actions = function() context(topofstack(v_environment)) end }

-- -- -- this will move -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
--
--  <?xml version='1.0' standalone='yes'?>
--  <exa:variables xmlns:exa='htpp://www.pragma-ade.com/schemas/exa-variables.rng'>
--      <exa:variable label='mode:pragma'>nee</exa:variable>
--      <exa:variable label='mode:variant'>standaard</exa:variable>
--  </exa:variables>
--
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local report_examodes = logs.reporter("system","examodes")

local function convertexamodes(str)
    local x = xml.convert(str)
    for e in xml.collected(x,"exa:variable") do
        local label = e.at and e.at.label
        if label and label ~= "" then
            local data = xml.text(e)
            local mode = match(label,"^mode:(.+)$")
            if mode then
                context.enablemode { formatters["%s:%s"](mode,data) }
            end
            context.setvariable("exa:variables",label,(gsub(data,"([{}])","\\%1")))
        end
    end
end

function environment.loadexamodes(filename)
    if not filename or filename == "" then
        filename = removesuffix(tex.jobname)
    end
    filename = resolvers.findfile(addsuffix(filename,'ctm')) or ""
    if filename ~= "" then
        report_examodes("loading %a",filename) -- todo: message system
        convertexamodes(io.loaddata(filename))
    else
        report_examodes("no mode file %a",filename) -- todo: message system
    end
end

implement {
    name      = "loadexamodes",
    actions   = environment.loadexamodes,
    arguments = "string"
}

-- changed in mtx-context
-- code moved from luat-ini

-- todo: locals when mtx-context is changed

document = document or {
    arguments = allocate(),
    files     = allocate(),
    variables = allocate(), -- for templates
    options   = {
        commandline = {
            environments = allocate(),
            modules      = allocate(),
            modes        = allocate(),
        },
        ctxfile = {
            environments = allocate(),
            modules      = allocate(),
            modes        = allocate(),
        },
    },
    functions = table.setmetatablenewindex(function(t,k,v)
        if rawget(t,k) then
            report_functions("overloading document function %a",k)
        end
        rawset(t,k,v)
        return v
    end),
}

function document.setargument(key,value)
    document.arguments[key] = value
end

function document.setdefaultargument(key,default)
    local v = document.arguments[key]
    if v == nil or v == "" then
        document.arguments[key] = default
    end
end

function document.setfilename(i,name)
    if name then
        document.files[tonumber(i)] = name
    else
        document.files[#document.files+1] = tostring(i)
    end
end

function document.getargument(key,default)
    local v = document.arguments[key]
    if type(v) == "boolean" then
        v = (v and "yes") or "no"
        document.arguments[key] = v
    end
    return v or default or ""
end

function document.getfilename(i)
    return document.files[tonumber(i)] or ""
end

implement {
    name      = "setdocumentargument",
    actions   = document.setargument,
    arguments = "2 strings"
}

implement {
    name      = "setdocumentdefaultargument",
    actions   = document.setdefaultargument,
    arguments = "2 strings"
}

implement {
    name      = "setdocumentfilename",
    actions   = document.setfilename,
    arguments = { "integer", "string" }
}

implement {
    name      = "getdocumentargument",
    actions   = { document.getargument, context },
    arguments = "2 strings"
}

implement {
    name      = "getdocumentfilename",
    actions   = { document.getfilename, context },
    arguments = "integer"
}

function document.setcommandline() -- has to happen at the tex end in order to expand

    -- the document[arguments|files] tables are copies

    local arguments = document.arguments
    local files     = document.files
    local options   = document.options

    for k, v in next, environment.arguments do
        k = gsub(k,"^c:","") -- already done, but better be safe than sorry
        if arguments[k] == nil then
            arguments[k] = v
        end
    end

    -- in the new mtx=context approach we always pass a stub file so we need to
    -- to trick the files table which actually only has one entry in a tex job

    if arguments.timing then
        context.usemodule("timing")
    end

    if arguments.batchmode then
        context.batchmode(false)
    end

    if arguments.nonstopmode then
        context.nonstopmode(false)
    end

    if arguments.nostatistics then
        directives.enable("system.nostatistics")
    end

    if arguments.paranoid then
        context.setvalue("maxreadlevel",1)
    end

    if validstring(arguments.path)  then
        context.usepath { arguments.path }
    end

    if arguments.export then
        context.setupbackend { export = v_yes }
    end

    local inputfile = validstring(arguments.input)

    if inputfile and dirname(inputfile) == "." and lfs.isfile(inputfile) then
        -- nicer in checks
        inputfile = basename(inputfile)
    end

    local forcedruns = arguments.forcedruns
    local kindofrun  = arguments.kindofrun
    local currentrun = arguments.currentrun
    local maxnofruns = arguments.maxnofruns or arguments.runs

 -- context.setupsystem {
 --     [constants.directory] = validstring(arguments.setuppath),
 --     [constants.inputfile] = inputfile,
 --     [constants.file]      = validstring(arguments.result),
 --     [constants.random]    = validstring(arguments.randomseed),
 --     -- old:
 --     [constants.n]         = validstring(kindofrun),
 --     [constants.m]         = validstring(currentrun),
 -- }

    context.setupsystem {
        directory = validstring(arguments.setuppath),
        inputfile = inputfile,
        file      = validstring(arguments.result),
        random    = validstring(arguments.randomseed),
        -- old:
        n         = validstring(kindofrun),
        m         = validstring(currentrun),
    }

    forcedruns = tonumber(forcedruns) or 0
    kindofrun  = tonumber(kindofrun)  or 0
    maxnofruns = tonumber(maxnofruns) or 0
    currentrun = tonumber(currentrun) or 0

    local prerollrun = forcedruns > 0 and currentrun > 0 and currentrun < forcedruns

    environment.forcedruns = forcedruns
    environment.kindofrun  = kindofrun
    environment.maxnofruns = maxnofruns
    environment.currentrun = currentrun
    environment.prerollrun = prerollrun

    context.setconditional("prerollrun",prerollrun)

    if validstring(arguments.arguments) then
        context.setupenv { arguments.arguments }
    end

    if arguments.once then
        directives.enable("system.runonce")
    end

    if arguments.noarrange then
        context.setuparranging { variables.disable }
    end

    --

    local commandline  = options.commandline

    commandline.environments = table.append(commandline.environments,settings_to_array(validstring(arguments.environment)))
    commandline.modules      = table.append(commandline.modules,     settings_to_array(validstring(arguments.usemodule)))
    commandline.modes        = table.append(commandline.modes,       settings_to_array(validstring(arguments.mode)))

    --

    if #files == 0 then
        local list = settings_to_array(validstring(arguments.files))
        if list and #list > 0 then
            files = list
        end
    end

    if #files == 0 then
        files = { validstring(arguments.input) }
    end

    --

    document.arguments = arguments
    document.files     = files

end

-- commandline wins over ctxfile

local function apply(list,action)
    if list then
        for i=1,#list do
            action { list[i] }
        end
    end
end

function document.setmodes() -- was setup: *runtime:modes
    apply(document.options.ctxfile    .modes,context.enablemode)
    apply(document.options.commandline.modes,context.enablemode)
end

function document.setmodules() -- was setup: *runtime:modules
    apply(document.options.ctxfile    .modules,context.usemodule)
    apply(document.options.commandline.modules,context.usemodule)
end

function document.setenvironments() -- was setup: *runtime:environments
    apply(document.options.ctxfile    .environments,context.environment)
    apply(document.options.commandline.environments,context.environment)
end

function document.setfilenames()
    local initialize = environment.initializefilenames
    if initialize then
        initialize()
    else
        -- fatal error
    end
end

implement { name = "setdocumentcommandline",  actions = document.setcommandline,  onlyonce = true }
implement { name = "setdocumentmodes",        actions = document.setmodes,        onlyonce = true }
implement { name = "setdocumentmodules",      actions = document.setmodules,      onlyonce = true }
implement { name = "setdocumentenvironments", actions = document.setenvironments, onlyonce = true }
implement { name = "setdocumentfilenames",    actions = document.setfilenames,    onlyonce = true }

do

    logs.registerfinalactions(function()
        local foundintrees = resolvers.foundintrees()
        if #foundintrees > 0 then
            logs.startfilelogging(report,"used files")
            for i=1,#foundintrees do
                report("%4i: % T",i,foundintrees[i])
            end
            logs.stopfilelogging()
        end
    end)

    logs.registerfinalactions(function()
        local files = document.files -- or environment.files
        local arguments = document.arguments -- or environment.arguments
        --
        logs.startfilelogging(report,"commandline options")
        if arguments and next(arguments) then
            for argument, value in sortedhash(arguments) do
                report("%s=%A",argument,value)
            end
        else
            report("no arguments")
        end
        logs.stopfilelogging()
        --
        logs.startfilelogging(report,"commandline files")
        if files and #files > 0 then
            for i=1,#files do
                report("% 4i: %s",i,files[i])
            end
        else
            report("no files")
        end
        logs.stopfilelogging()
    end)

end

if environment.initex then

    logs.registerfinalactions(function()
        local startfilelogging = logs.startfilelogging
        local stopfilelogging  = logs.stopfilelogging
        startfilelogging(report,"stored tables")
        for k,v in sortedhash(storage.data) do
            report("%03i %s",k,v[1])
        end
        stopfilelogging()
        startfilelogging(report,"stored modules")
        for k,v in sortedhash(lua.bytedata) do
            report("%03i %s %s",k,v.name)
        end
        stopfilelogging()
        startfilelogging(report,"stored attributes")
        for k,v in sortedhash(attributes.names) do
            report("%03i %s",k,v)
        end
        stopfilelogging()
        startfilelogging(report,"stored catcodetables")
        for k,v in sortedhash(catcodes.names) do
            report("%03i % t",k,v)
        end
        stopfilelogging()
        startfilelogging(report,"stored corenamespaces")
        for k,v in sortedhash(interfaces.corenamespaces) do
            report("%03i %s",k,v)
        end
        stopfilelogging()
    end)

end

implement {
    name      = "doifelsecontinuewithfile",
    arguments = "string",
    actions   = function(inpname,basetoo)
        local inpnamefull = addsuffix(inpname,"tex")
        local inpfilefull = addsuffix(environment.inputfilename,"tex")
        local continue = inpnamefull == inpfilefull
     -- if basetoo and not continue then
        if not continue then
            continue = inpnamefull == basename(inpfilefull)
        end
        if continue then
            report("continuing input file %a",inpname)
        end
        ctx_doifelse(continue)
    end
}
