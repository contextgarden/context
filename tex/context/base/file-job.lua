if not modules then modules = { } end modules ['file-job'] = {
    version   = 1.001,
    comment   = "companion to file-job.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- in retrospect dealing it's not that bad to deal with the nesting
-- and push/poppign at the tex end

local gsub, match, find = string.gsub, string.match, string.find
local insert, remove, concat = table.insert, table.remove, table.concat
local validstring = string.valid
local sortedhash = table.sortedhash
local formatters = string.formatters

local commands, resolvers, context = commands, resolvers, context

local trace_jobfiles  = false  trackers.register("system.jobfiles", function(v) trace_jobfiles = v end)

local report_jobfiles = logs.reporter("system","jobfiles")

local texsetcount       = tex.setcount
local elements          = interfaces.elements
local constants         = interfaces.constants
local variables         = interfaces.variables
local logsnewline       = logs.newline
local logspushtarget    = logs.pushtarget
local logspoptarget     = logs.poptarget
local settings_to_array = utilities.parsers.settings_to_array
local allocate          = utilities.storage.allocate

local nameonly          = file.nameonly
local suffixonly        = file.suffix
local basename          = file.basename
local addsuffix         = file.addsuffix
local removesuffix      = file.removesuffix
local dirname           = file.dirname
local joinpath          = file.join
local is_qualified_path = file.is_qualified_path

local cleanpath         = resolvers.cleanpath
local inputstack        = resolvers.inputstack
local resolveprefix     = resolvers.resolve

local hasscheme         = url.hasscheme

local jobresolvers      = resolvers.jobs

local registerextrapath = resolvers.registerextrapath

local v_outer           = variables.outer
local v_text            = variables.text
local v_project         = variables.project
local v_environment     = variables.environment
local v_product         = variables.product
local v_component       = variables.component
local c_prefix          = variables.prefix

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

function commands.processfile(name)
    name = findctxfile(name)
    if name ~= "" then
        context.input(name)
    end
end

function commands.doifinputfileelse(name)
    commands.doifelse(findctxfile(name) ~= "")
end

function commands.locatefilepath(name)
    context(dirname(findctxfile(name)))
end

function commands.usepath(paths)
    report_jobfiles("using path: %s",paths)
    registerextrapath(paths)
end

function commands.usesubpath(subpaths)
    report_jobfiles("using subpath: %s",subpaths)
    registerextrapath(nil,subpaths)
end

function commands.allinputpaths()
    context(concat(resolvers.instance.extra_paths or { },","))
end

function commands.setdocumentfilenames()
    environment.initializefilenames()
end

function commands.usezipfile(name,tree)
    if tree and tree ~= "" then
        resolvers.usezipfile(formatters["zip:///%s?tree=%s"](name,tree))
    else
        resolvers.usezipfile(formatters["zip:///%s"](name))
    end
end

local report_system  = logs.reporter("system")

-- moved from tex to lua:

local texpatterns = { "%s.mkvi", "%s.mkiv", "%s.tex" }
local luapatterns = { "%s" .. utilities.lua.suffixes.luc, "%s.lua" }
local cldpatterns = { "%s.cld" }
local xmlpatterns = { "%s.xml" }

local uselibrary = commands.uselibrary
local input      = context.input

-- status
--
-- these need to be synced with input stream:

local processstack   = { }
local processedfile  = ""
local processedfiles = { }

function commands.processedfile()
    context(processedfile)
end

function commands.processedfiles()
    context(concat(processedfiles,","))
end

function commands.dostarttextfile(name)
    insert(processstack,name)
    processedfile = name
    insert(processedfiles,name)
end

function commands.dostoptextfile()
    processedfile = remove(processstack) or ""
end

local function startprocessing(name,notext)
    if not notext then
     -- report_system("begin file %a at line %a",name,status.linenumber or 0)
        context.dostarttextfile(name)
    end
end

local function stopprocessing(notext)
    if not notext then
        context.dostoptextfile()
     -- report_system("end file %a at line %a",name,status.linenumber or 0)
    end
end

--

local typestack   = { }
local currenttype = v_text

--

local action  = function(name,foundname) input(foundname) end
local failure = function(name,foundname) report_jobfiles("unknown %s file %a","tex",name) end

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

local action  = function(name,foundname) dofile(foundname) end
local failure = function(name,foundname) report_jobfiles("unknown %s file %a","lua",name) end

local function useluafile(name,onlyonce,notext)
    uselibrary {
        name     = name,
        patterns = luapatterns,
        action   = action,
        failure  = failure,
        onlyonce = onlyonce,
    }
end

local action  = function(name,foundname) dofile(foundname) end
local failure = function(name,foundname) report_jobfiles("unknown %s file %a","cld",name) end

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

local action  = function(name,foundname) context.xmlprocess(foundname,"main","") end
local failure = function(name,foundname) report_jobfiles("unknown %s file %a","xml",name) end

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

commands.usetexfile = usetexfile
commands.useluafile = useluafile
commands.usecldfile = usecldfile
commands.usexmlfile = usexmlfile

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

commands.useanyfile = useanyfile

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
    report_system("invalid \\%s%s ... \\%s%s structure",elements.start,v_text,elements.stop,v_text)
    startstoperror = dummyfunction
end

local function starttext()
    if textlevel == 0 then
        if trace_jobfiles then
            report_jobfiles("starting text")
        end
     -- registerfileinfo[begin]jobfilename
        context.dostarttext()
    end
    textlevel = textlevel + 1
    texsetcount("global","textlevel",textlevel)
end

local function stoptext()
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
        -- registerfileinfo[end]jobfilename
        context.finalend()
        commands.stoptext = dummyfunction
    end
end

commands.starttext = starttext
commands.stoptext  = stoptext

function commands.forcequitjob(reason)
    if reason then
        report_system("forcing quit: %s",reason)
    else
        report_system("forcing quit")
    end
    context.batchmode()
    while textlevel >= 0 do
        context.stoptext()
    end
end

function commands.forceendjob()
    report_system([[don't use \end to finish a document]])
    context.stoptext()
end

function commands.autostarttext()
    if textlevel == 0 then
        report_system([[auto \starttext ... \stoptext]])
    end
    context.starttext()
end

commands.autostoptext = stoptext

-- project structure

function commands.processfilemany(name)
    useanyfile(name,false)
end

function commands.processfileonce(name)
    useanyfile(name,true)
end

function commands.processfilenone(name)
    -- skip file
end

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

local report_structures = logs.reporter("system","structure")
local report_structure  = logs.reporter("used structure")

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

local function log_tree(top,depth)
    report_structure("%s%s: %s",depth,top.type,top.name)
    local branches = top.branches
    if #branches > 0 then
        depth = depth .. "  "
        for i=1,#branches do
            log_tree(branches[i],depth)
        end
    end
end

luatex.registerstopactions(function()
    logspushtarget("logfile")
    logsnewline()
    report_structures("start used structure")
    logsnewline()
    root.name = environment.jobname
    log_tree(root,"")
    logsnewline()
    report_structures("stop used structure")
    logsnewline()
    logspoptarget()
end)

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

local context_processfilemany = context.processfilemany
local context_processfileonce = context.processfileonce
local context_processfilenone = context.processfilenone

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

local function processfilemany(name) processfilecommon(name,context_processfilemany) end
local function processfileonce(name) processfilecommon(name,context_processfileonce) end
local function processfilenone(name) processfilecommon(name,context_processfilenone) end

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

function commands.useproject    (name) process(v_project,    name) end
function commands.useenvironment(name) process(v_environment,name) end
function commands.useproduct    (name) process(v_product,    name) end
function commands.usecomponent  (name) process(v_component,  name) end

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
        name = nameonly(inputstack[#inputstack] or name)
    end
    return name
end

function commands.startproject    (name) gotonextlevel(v_project,    autoname(name)) end
function commands.startproduct    (name) gotonextlevel(v_product,    autoname(name)) end
function commands.startcomponent  (name) gotonextlevel(v_component,  autoname(name)) end
function commands.startenvironment(name) gotonextlevel(v_environment,autoname(name)) end

function commands.stopproject    () gotopreviouslevel(v_project    ) end
function commands.stopproduct    () gotopreviouslevel(v_product    ) end
function commands.stopcomponent  () gotopreviouslevel(v_component  ) end
function commands.stopenvironment() gotopreviouslevel(v_environment) end

function commands.currentproject    () context(topofstack(v_project    )) end
function commands.currentproduct    () context(topofstack(v_product    )) end
function commands.currentcomponent  () context(topofstack(v_component  )) end
function commands.currentenvironment() context(topofstack(v_environment)) end

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

function commands.loadexamodes(filename)
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

function document.getargument(key,default) -- commands
    local v = document.arguments[key]
    if type(v) == "boolean" then
        v = (v and "yes") or "no"
        document.arguments[key] = v
    end
    context(v or default or "")
end

function document.setargument(key,value)
    document.arguments[key] = value -- only strings
end

function document.getfilename(i) -- commands
    context(document.files[tonumber(i)] or "")
end

function commands.getcommandline() -- has to happen at the tex end in order to expand

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

function commands.setdocumentmodes() -- was setup: *runtime:modes
    apply(document.options.ctxfile    .modes,context.enablemode)
    apply(document.options.commandline.modes,context.enablemode)
end

function commands.setdocumentmodules() -- was setup: *runtime:modules
    apply(document.options.ctxfile    .modules,context.usemodule)
    apply(document.options.commandline.modules,context.usemodule)
end

function commands.setdocumentenvironments() -- was setup: *runtime:environments
    apply(document.options.ctxfile    .environments,context.environment)
    apply(document.options.commandline.environments,context.environment)
end

local report_files    = logs.reporter("system","files")
local report_options  = logs.reporter("system","options")
local report_file     = logs.reporter("used file")
local report_option   = logs.reporter("used option")

luatex.registerstopactions(function()
    local foundintrees = resolvers.instance.foundintrees
    if #foundintrees > 0 then
        logspushtarget("logfile")
        logsnewline()
        report_files("start used files")
        logsnewline()
        for i=1,#foundintrees do
            report_file("%4i: % T",i,foundintrees[i])
        end
        logsnewline()
        report_files("stop used files")
        logsnewline()
        logspoptarget()
    end
end)

luatex.registerstopactions(function()
    local files = document.files -- or environment.files
    local arguments = document.arguments -- or environment.arguments
    --
    logspushtarget("logfile")
    logsnewline()
    report_options("start commandline options")
    logsnewline()
    if arguments and next(arguments) then
        for argument, value in sortedhash(arguments) do
            report_option("%s=%A",argument,value)
        end
    else
        report_file("no arguments")
    end
    logsnewline()
    report_options("stop commandline options")
    logsnewline()
    report_options("start commandline files")
    logsnewline()
    if files and #files > 0 then
        for i=1,#files do
            report_file("% 4i: %s",i,files[i])
        end
    else
        report_file("no files")
    end
    logsnewline()
    report_options("stop commandline files")
    logsnewline()
    logspoptarget()
end)

if environment.initex then

    local report_storage       = logs.reporter("system","storage")
    local report_table         = logs.reporter("stored table")
    local report_module        = logs.reporter("stored module")
    local report_attribute     = logs.reporter("stored attribute")
    local report_catcodetable  = logs.reporter("stored catcodetable")
    local report_corenamespace = logs.reporter("stored corenamespace")

    luatex.registerstopactions(function()
        logspushtarget("logfile")
        logsnewline()
        report_storage("start stored tables")
        logsnewline()
        for k,v in sortedhash(storage.data) do
            report_table("%03i %s",k,v[1])
        end
        logsnewline()
        report_storage("stop stored tables")
        logsnewline()
        report_storage("start stored modules")
        logsnewline()
        for k,v in sortedhash(lua.bytedata) do
            report_module("%03i %s %s",k,v[2],v[1])
        end
        logsnewline()
        report_storage("stop stored modules")
        logsnewline()
        report_storage("start stored attributes")
        logsnewline()
        for k,v in sortedhash(attributes.names) do
            report_attribute("%03i %s",k,v)
        end
        logsnewline()
        report_storage("stop stored attributes")
        logsnewline()
        report_storage("start stored catcodetables")
        logsnewline()
        for k,v in sortedhash(catcodes.names) do
            report_catcodetable("%03i % t",k,v)
        end
        logsnewline()
        report_storage("stop stored catcodetables")
        logsnewline()
        report_storage("start stored corenamespaces")
        for k,v in sortedhash(interfaces.corenamespaces) do
            report_corenamespace("%03i %s",k,v)
        end
        logsnewline()
        report_storage("stop stored corenamespaces")
        logsnewline()
        logspoptarget()
    end)

end

function commands.doifelsecontinuewithfile(inpname,basetoo)
    local inpnamefull = addsuffix(inpname,"tex")
    local inpfilefull = addsuffix(environment.inputfilename,"tex")
    local continue = inpnamefull == inpfilefull
    if basetoo and not continue then
        continue = inpnamefull == basename(inpfilefull)
    end
    if continue then
        report_system("continuing input file %a",inpname)
    end
    commands.doifelse(continue)
end
