if not modules then modules = { } end modules ['strc-ref'] = {
    version   = 1.001,
    comment   = "companion to strc-ref.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- beware, this is a first step in the rewrite (just getting rid of
-- the tuo file); later all access and parsing will also move to lua

-- the useddata and pagedata names might change
-- todo: pack exported data

-- todo: autoload components when :::

local format, find, gmatch, match, strip = string.format, string.find, string.gmatch, string.match, string.strip
local floor = math.floor
local rawget, tonumber, type = rawget, tonumber, type
local lpegmatch = lpeg.match
local insert, remove, copytable = table.insert, table.remove, table.copy
local formatters = string.formatters

local allocate           = utilities.storage.allocate
local mark               = utilities.storage.mark
local setmetatableindex  = table.setmetatableindex

local trace_referencing  = false  trackers.register("structures.referencing",             function(v) trace_referencing = v end)
local trace_analyzing    = false  trackers.register("structures.referencing.analyzing",   function(v) trace_analyzing   = v end)
local trace_identifying  = false  trackers.register("structures.referencing.identifying", function(v) trace_identifying = v end)
local trace_importing    = false  trackers.register("structures.referencing.importing",   function(v) trace_importing   = v end)
local trace_empty        = false  trackers.register("structures.referencing.empty",       function(v) trace_empty       = v end)

local check_duplicates   = true

directives.register("structures.referencing.checkduplicates", function(v)
    check_duplicates = v
end)

local report_references  = logs.reporter("references")
local report_unknown     = logs.reporter("references","unknown")
local report_identifying = logs.reporter("references","identifying")
local report_importing   = logs.reporter("references","importing")
local report_empty       = logs.reporter("references","empty")

local variables          = interfaces.variables
local v_default          = variables.default
local v_url              = variables.url
local v_file             = variables.file
local v_unknown          = variables.unknown
local v_page             = variables.page
local v_auto             = variables.auto

local context            = context
local commands           = commands

local texgetcount        = tex.getcount
local texsetcount        = tex.setcount
local texconditionals    = tex.conditionals

local productcomponent   = resolvers.jobs.productcomponent
local justacomponent     = resolvers.jobs.justacomponent

local logsnewline        = logs.newline
local logspushtarget     = logs.pushtarget
local logspoptarget      = logs.poptarget

local settings_to_array  = utilities.parsers.settings_to_array
local process_settings   = utilities.parsers.process_stripped_settings
local unsetvalue         = attributes.unsetvalue

local structures         = structures
local helpers            = structures.helpers
local sections           = structures.sections
local references         = structures.references
local lists              = structures.lists
local counters           = structures.counters

local jobpositions       = job.positions

-- some might become local

references.defined       = references.defined or allocate()

local defined            = references.defined
local derived            = allocate()
local specials           = allocate()
local runners            = allocate()
local internals          = allocate()
local filters            = allocate()
local executers          = allocate()
local handlers           = allocate()
local tobesaved          = allocate()
local collected          = allocate()
local tobereferred       = allocate()
local referred           = allocate()
local usedinternals      = allocate()
local flaginternals      = allocate()
local usedviews          = allocate()

references.derived       = derived
references.specials      = specials
references.runners       = runners
references.internals     = internals
references.filters       = filters
references.executers     = executers
references.handlers      = handlers
references.tobesaved     = tobesaved
references.collected     = collected
references.tobereferred  = tobereferred
references.referred      = referred
references.usedinternals = usedinternals
references.flaginternals = flaginternals
references.usedviews     = usedviews

local splitreference     = references.splitreference
local splitprefix        = references.splitcomponent -- replaces: references.splitprefix
local prefixsplitter     = references.prefixsplitter
local componentsplitter  = references.componentsplitter

local currentreference   = nil

local txtcatcodes        = catcodes.numbers.txtcatcodes -- or just use "txtcatcodes"
local context_delayed    = context.delayed

local ctx_pushcatcodes                = context.pushcatcodes
local ctx_popcatcodes                 = context.popcatcodes
local ctx_dofinishsomereference       = context.dofinishsomereference
local ctx_dofromurldescription        = context.dofromurldescription
local ctx_dofromurlliteral            = context.dofromurlliteral
local ctx_dofromfiledescription       = context.dofromfiledescription
local ctx_dofromfileliteral           = context.dofromfileliteral
local ctx_expandreferenceoperation    = context.expandreferenceoperation
local ctx_expandreferencearguments    = context.expandreferencearguments
local ctx_getreferencestructureprefix = context.getreferencestructureprefix
local ctx_convertnumber               = context.convertnumber
local ctx_emptyreference              = context.emptyreference

storage.register("structures/references/defined", references.defined, "structures.references.defined")

local initializers = { }
local finalizers   = { }

function references.registerinitializer(func) -- we could use a token register instead
    initializers[#initializers+1] = func
end

function references.registerfinalizer(func) -- we could use a token register instead
    finalizers[#finalizers+1] = func
end

local function initializer() -- can we use a tobesaved as metatable for collected?
    tobesaved = references.tobesaved
    collected = references.collected
    for i=1,#initializers do
        initializers[i](tobesaved,collected)
    end
    for prefix, list in next, collected do
        for tag, data in next, list do
            local r = data.references
            local i = r.internal
            if i then
                internals[i]     = data
                usedinternals[i] = r.used
            end
        end
    end
end

local function finalizer()
    for i=1,#finalizers do
        finalizers[i](tobesaved)
    end
    for prefix, list in next, tobesaved do
        for tag, data in next, list do
            local r = data.references
            local i = r.internal
            local f = flaginternals[i]
            if f then
                r.used = usedviews[i] or true
            end
        end
    end
end

job.register('structures.references.collected', tobesaved, initializer, finalizer)

local maxreferred = 1
local nofreferred = 0

local function initializer() -- can we use a tobesaved as metatable for collected?
    tobereferred = references.tobereferred
    referred     = references.referred
    nofreferred = #referred
end

-- no longer fone this way

-- references.resolvers = references.resolvers or { }
-- local resolvers = references.resolvers
--
-- function resolvers.section(var)
--     local vi = lists.collected[var.i[2]]
--     if vi then
--         var.i = vi
--         var.r = (vi.references and vi.references.realpage) or (vi.pagedata and vi.pagedata.realpage) or 1
--     else
--         var.i = nil
--         var.r = 1
--     end
-- end
--
-- resolvers.float       = resolvers.section
-- resolvers.description = resolvers.section
-- resolvers.formula     = resolvers.section
-- resolvers.note        = resolvers.section
--
-- function resolvers.reference(var)
--     local vi = var.i[2]
--     if vi then
--         var.i = vi
--         var.r = (vi.references and vi.references.realpage) or (vi.pagedata and vi.pagedata.realpage) or 1
--     else
--         var.i = nil
--         var.r = 1
--     end
-- end

-- We make the array sparse (maybe a finalizer should optionally return a table) because
-- there can be quite some page links involved. We only store one action number per page
-- which is normally good enough for what we want (e.g. see above/below) and we do
-- a combination of a binary search and traverse backwards. A previous implementation
-- always did a traverse and was pretty slow on a large number of links (given that this
-- methods was used). It took me about a day to locate this as a bottleneck in processing
-- a 2500 page interactive document with 60 links per page. In that case, traversing
-- thousands of slots per link then brings processing to a grinding halt (especially when
-- there are no slots at all, which is the case in a first run).

local sparsetobereferred = { }

local function finalizer()
    local lastr, lasti
    local n = 0
    for i=1,maxreferred do
        local r = tobereferred[i]
        if not lastr then
            lastr = r
            lasti = i
        elseif r ~= lastr then
            n = n + 1
            sparsetobereferred[n] = { lastr, lasti }
            lastr = r
            lasti = i
        end
    end
    if lastr then
        n = n + 1
        sparsetobereferred[n] = { lastr, lasti }
    end
end

job.register('structures.references.referred', sparsetobereferred, initializer, finalizer)

local function referredpage(n)
    local max = nofreferred
    if max > 0 then
        -- find match
        local min = 1
        while true do
            local mid = floor((min+max)/2)
            local r = referred[mid]
            local m = r[2]
            if n == m then
                return r[1]
            elseif n > m then
                min = mid + 1
            else
                max = mid - 1
            end
            if min > max then
                break
            end
        end
        -- find first previous
        for i=min,1,-1 do
            local r = referred[i]
            if r and r[2] < n then
                return r[1]
            end
        end
    end
    -- fallback
    return texgetcount("realpageno")
end

references.referredpage = referredpage

function references.registerpage(n) -- called in the backend code
    if not tobereferred[n] then
        if n > maxreferred then
            maxreferred = n
        end
        tobereferred[n] = texgetcount("realpageno")
    end
end

-- todo: delay split till later as in destinations we split anyway

local orders, lastorder = { }, 0

local function setnextorder(kind,name)
    lastorder = 0
    if kind and name then
        local ok = orders[kind]
        if not ok then
            ok = { }
            orders[kind] = ok
        end
        lastorder = (ok[name] or 0) + 1
        ok[name] = lastorder
    end
    texsetcount("global","locationorder",lastorder)
end


local function setnextinternal(kind,name)
    setnextorder(kind,name) -- always incremented with internal
    local n = texgetcount("locationcount") + 1
    texsetcount("global","locationcount",n)
    return n
end

local function currentorder(kind,name)
    return orders[kind] and orders[kind][name] or lastorder
end

local function setcomponent(data)
    -- we might consider doing this at the tex end, just like prefix
    local component = productcomponent()
    if component then
        local references = data and data.references
        if references then
            references.component = component
            if references.referenceprefix == component then
                references.referenceprefix = nil
            end
        end
        return component
    end
    -- but for the moment we do it here (experiment)
end

references.setnextorder    = setnextorder
references.setnextinternal = setnextinternal
references.currentorder    = currentorder
references.setcomponent    = setcomponent

commands.setnextreferenceorder    = setnextorder
commands.setnextinternalreference = setnextinternal

function commands.currentreferenceorder(kind,name)
    context(currentorder(kind,name))
end

function references.set(kind,prefix,tag,data)
--  setcomponent(data)
    local pd = tobesaved[prefix] -- nicer is a metatable
    if not pd then
        pd = { }
        tobesaved[prefix] = pd
    end
    local n = 0
    local function action(ref)
        if ref == "" then
            -- skip
        elseif check_duplicates and pd[ref] then
            if prefix and prefix ~= "" then
                report_references("redundant reference %a in namespace %a",ref,prefix)
            else
                report_references("redundant reference %a",ref)
            end
        else
            n = n + 1
            pd[ref] = data
            ctx_dofinishsomereference(kind,prefix,ref)
        end
    end
    process_settings(tag,action)
    return n > 0
end

-- function references.enhance(prefix,tag)
--     local l = tobesaved[prefix][tag]
--     if l then
--         l.references.realpage = texgetcount("realpageno")
--     end
-- end

local getpos = function() getpos = backends.codeinjections.getpos  return getpos () end

local function synchronizepage(reference) -- non public helper
    reference.realpage = texgetcount("realpageno")
    if jobpositions.used then
        reference.x, reference.y = getpos()
    end
end

references.synchronizepage = synchronizepage

function references.enhance(prefix,tag)
    local l = tobesaved[prefix][tag]
    if l then
        synchronizepage(l.references)
    end
end

commands.enhancereference = references.enhance

-- -- -- related to strc-ini.lua -- -- --

-- no metatable here .. better be sparse

local function register_from_lists(collected,derived,pages,sections)
    local derived_g = derived[""] -- global
    if not derived_g then
        derived_g = { }
        derived[""] = derived_g
    end
    for i=1,#collected do
        local entry    = collected[i]
        local metadata = entry.metadata
        if metadata then
            local kind = metadata.kind
            if kind then
                local references = entry.references
                if references then
                    local reference = references.reference
                    if reference and reference ~= "" then
                        local realpage = references.realpage
                        if realpage then
                            local prefix    = references.referenceprefix
                            local component = references.component
                            local derived_p = nil
                            local derived_c = nil
                            if prefix and prefix ~= "" then
                                derived_p = derived[prefix]
                                if not derived_p then
                                    derived_p = { }
                                    derived[prefix] = derived_p
                                end
                            end
                            if component and component ~= "" and component ~= prefix then
                                derived_c = derived[component]
                                if not derived_c then
                                    derived_c = { }
                                    derived[component] = derived_c
                                end
                            end
                            local function action(s)
                                if trace_referencing then
                                    report_references("list entry %a provides %a reference %a on realpage %a",i,kind,s,realpage)
                                end
                                if derived_p and not derived_p[s] then
                                    derived_p[s] = entry
                                end
                                if derived_c and not derived_c[s] then
                                    derived_c[s] = entry
                                end
                                if not derived_g[s] then
                                    derived_g[s] = entry -- first wins
                                end
                            end
                            process_settings(reference,action)
                        end
                    end
                end
            end
        end
    end
 -- inspect(derived)
end

references.registerinitializer(function() register_from_lists(lists.collected,derived) end)

-- urls

local urls      = references.urls or { }
references.urls = urls
local urldata   = urls.data or { }
urls.data       = urldata

function urls.define(name,url,file,description)
    if name and name ~= "" then
        urldata[name] = { url or "", file or "", description or url or file or ""}
    end
end

function urls.get(name)
    local u = urldata[name]
    if u then
        local url, file = u[1], u[2]
        if file and file ~= "" then
            return formatters["%s/%s"](url,file)
        else
            return url
        end
    end
end

function commands.geturl(name)
    local url = urls.get(name)
    if url and url ~= "" then
        ctx_pushcatcodes(txtcatcodes)
        context(url)
        ctx_popcatcodes()
    end
end

-- function commands.gethyphenatedurl(name,...)
--     local url = urls.get(name)
--     if url and url ~= "" then
--         hyphenatedurl(url,...)
--     end
-- end

function commands.doifurldefinedelse(name)
    commands.doifelse(urldata[name])
end

commands.useurl= urls.define

-- files

local files      = references.files or { }
references.files = files
local filedata   = files.data or { }
files.data       = filedata

function files.define(name,file,description)
    if name and name ~= "" then
        filedata[name] = { file or "", description or file or "" }
    end
end

function files.get(name,method,space) -- method: none, before, after, both, space: yes/no
    local f = filedata[name]
    if f then
        context(f[1])
    end
end

function commands.doiffiledefinedelse(name)
    commands.doifelse(filedata[name])
end

commands.usefile= files.define

-- helpers

function references.checkedfile(whatever) -- return whatever if not resolved
    if whatever then
        local w = filedata[whatever]
        if w then
            return w[1]
        else
            return whatever
        end
    end
end

function references.checkedurl(whatever) -- return whatever if not resolved
    if whatever then
        local w = urldata[whatever]
        if w then
            local u, f = w[1], w[2]
            if f and f ~= "" then
                return u .. "/" .. f
            else
                return u
            end
        else
            return whatever
        end
    end
end

function references.checkedfileorurl(whatever,default) -- return nil, nil if not resolved
    if whatever then
        local w = filedata[whatever]
        if w then
            return w[1], nil
        else
            local w = urldata[whatever]
            if w then
                local u, f = w[1], w[2]
                if f and f ~= "" then
                    return nil, u .. "/" .. f
                else
                    return nil, u
                end
            end
        end
    end
    return default
end

-- programs

local programs      = references.programs or { }
references.programs = programs
local programdata   = programs.data or { }
programs.data       = programdata

function programs.define(name,file,description)
    if name and name ~= "" then
        programdata[name] = { file or "", description or file or ""}
    end
end

function programs.get(name)
    local f = programdata[name]
    return f and f[1]
end

function references.checkedprogram(whatever) -- return whatever if not resolved
    if whatever then
        local w = programdata[whatever]
        if w then
            return w[1]
        else
            return whatever
        end
    end
end

commands.defineprogram = programs.define

function commands.getprogram(name)
    local f = programdata[name]
    if f then
        context(f[1])
    end
end

-- shared by urls and files

function references.whatfrom(name)
    context((urldata[name] and v_url) or (filedata[name] and v_file) or v_unknown)
end

function references.from(name)
    local u = urldata[name]
    if u then
        local url, file, description = u[1], u[2], u[3]
        if description ~= "" then
            return description
            -- ok
        elseif file and file ~= "" then
            return url .. "/" .. file
        else
            return url
        end
    else
        local f = filedata[name]
        if f then
            local file, description = f[1], f[2]
            if description ~= "" then
                return description
            else
                return file
            end
        end
    end
end

function commands.from(name)
    local u = urldata[name]
    if u then
        local url, file, description = u[1], u[2], u[3]
        if description ~= "" then
            ctx_dofromurldescription(description)
            -- ok
        elseif file and file ~= "" then
            ctx_dofromurlliteral(url .. "/" .. file)
        else
            ctx_dofromurlliteral(url)
        end
    else
        local f = filedata[name]
        if f then
            local file, description = f[1], f[2]
            if description ~= "" then
                ctx_dofromfiledescription(description)
            else
                ctx_dofromfileliteral(file)
            end
        end
    end
end

function references.define(prefix,reference,list)
    local d = defined[prefix] if not d then d = { } defined[prefix] = d end
    d[reference] = list
end

function references.reset(prefix,reference)
    local d = defined[prefix]
    if d then
        d[reference] = nil
    end
end

commands.definereference = references.define
commands.resetreference  = references.reset

-- \primaryreferencefoundaction
-- \secondaryreferencefoundaction
-- \referenceunknownaction

-- t.special t.operation t.arguments t.outer t.inner

-- to what extend do we check the non prefixed variant

-- local strict = false
--
-- local function resolve(prefix,reference,args,set) -- we start with prefix,reference
--     if reference and reference ~= "" then
--         if not set then
--             set = { prefix = prefix, reference = reference }
--         else
--             if not set.reference then set.reference = reference end
--             if not set.prefix    then set.prefix    = prefix    end
--         end
--         local r = settings_to_array(reference)
--         for i=1,#r do
--             local ri = r[i]
--             local d
--             if strict then
--                 d = defined[prefix] or defined[""]
--                 d = d and d[ri]
--             else
--                 d = defined[prefix]
--                 d = d and d[ri]
--                 if not d then
--                     d = defined[""]
--                     d = d and d[ri]
--                 end
--             end
--             if d then
--                 resolve(prefix,d,nil,set)
--             else
--                 local var = splitreference(ri)
--                 if var then
--                     var.reference = ri
--                     local vo, vi = var.outer, var.inner
--                     if not vo and vi then
--                         -- to be checked
--                         if strict then
--                             d = defined[prefix] or defined[""]
--                             d = d and d[vi]
--                         else
--                             d = defined[prefix]
--                             d = d and d[vi]
--                             if not d then
--                                 d = defined[""]
--                                 d = d and d[vi]
--                             end
--                         end
--                         --
--                         if d then
--                             resolve(prefix,d,var.arguments,set) -- args can be nil
--                         else
--                             if args then var.arguments = args end
--                             set[#set+1] = var
--                         end
--                     else
--                         if args then var.arguments = args end
--                         set[#set+1] = var
--                     end
--                     if var.has_tex then
--                         set.has_tex = true
--                     end
--                 else
--                 --  report_references("funny pattern %a",ri)
--                 end
--             end
--         end
--         return set
--     else
--         return { }
--     end
-- end

setmetatableindex(defined,"table")

local function resolve(prefix,reference,args,set) -- we start with prefix,reference
    if reference and reference ~= "" then
        if not set then
            set = { prefix = prefix, reference = reference }
        else
            if not set.reference then set.reference = reference end
            if not set.prefix    then set.prefix    = prefix    end
        end
        local r = settings_to_array(reference)
        for i=1,#r do
            local ri = r[i]
            local d = defined[prefix][ri] or defined[""][ri]
            if d then
                resolve(prefix,d,nil,set)
            else
                local var = splitreference(ri)
                if var then
                    var.reference = ri
                    local vo, vi = var.outer, var.inner
                    if not vo and vi then
                        -- to be checked
                        d = defined[prefix][vi] or defined[""][vi]
                        --
                        if d then
                            resolve(prefix,d,var.arguments,set) -- args can be nil
                        else
                            if args then var.arguments = args end
                            set[#set+1] = var
                        end
                    else
                        if args then var.arguments = args end
                        set[#set+1] = var
                    end
                    if var.has_tex then
                        set.has_tex = true
                    end
                else
                --  report_references("funny pattern %a",ri)
                end
            end
        end
        return set
    else
        return { }
    end
end

-- prefix == "" is valid prefix which saves multistep lookup

references.currentset = nil

function commands.setreferenceoperation(k,v)
    references.currentset[k].operation = v
end

function commands.setreferencearguments(k,v)
    references.currentset[k].arguments = v
end

function references.expandcurrent() -- todo: two booleans: o_has_tex& a_has_tex
    local currentset = references.currentset
    if currentset and currentset.has_tex then
        for i=1,#currentset do
            local ci = currentset[i]
            local operation = ci.operation
            if operation and find(operation,"\\",1,true) then -- if o_has_tex then
                ctx_expandreferenceoperation(i,operation)
            end
            local arguments = ci.arguments
            if arguments and find(arguments,"\\",1,true) then -- if a_has_tex then
                ctx_expandreferencearguments(i,arguments)
            end
        end
    end
end

commands.expandcurrentreference = references.expandcurrent -- for the moment the same

local externals = { }

-- we have prefixes but also components:
--
-- :    prefix
-- ::   always external
-- :::  internal (for products) or external (for components)

local function loadexternalreferences(name,utilitydata)
    local struc = utilitydata.structures
    if struc then
        local external = struc.references.collected -- direct references
        local lists    = struc.lists.collected      -- indirect references (derived)
        local pages    = struc.pages.collected      -- pagenumber data
        -- a bit weird one, as we don't have the externals in the collected
        for prefix, set in next, external do
            for reference, data in next, set do
                if trace_importing then
                    report_importing("registering %a reference, kind %a, name %a, prefix %a, reference %a",
                        "external","regular",name,prefix,reference)
                end
                local section  = reference.section
                local realpage = reference.realpage
                if section then
                    reference.sectiondata = lists[section]
                end
                if realpage then
                    reference.pagedata = pages[realpage]
                end
            end
        end
        for i=1,#lists do
            local entry      = lists[i]
            local metadata   = entry.metadata
            local references = entry.references
            if metadata and references then
                local reference = references.reference
                if reference and reference ~= "" then
                    local kind     = metadata.kind
                    local realpage = references.realpage
                    if kind and realpage then
                        references.pagedata = pages[realpage]
                        local prefix = references.referenceprefix or ""
                        local target = external[prefix]
                        if not target then
                            target = { }
                            external[prefix] = target
                        end
                     -- for s in gmatch(reference,"%s*([^,]+)") do
                     --     if trace_importing then
                     --         report_importing("registering %s reference, kind %a, name %a, prefix %a, reference %a",
                     --             "external",kind,name,prefix,s)
                     --     end
                     --     target[s] = target[s] or entry
                     -- end
                        local function action(s)
                            if trace_importing then
                                report_importing("registering %s reference, kind %a, name %a, prefix %a, reference %a",
                                    "external",kind,name,prefix,s)
                            end
                            target[s] = target[s] or entry
                        end
                        process_settings(reference,action)
                    end
                end
            end
        end
        externals[name] = external
        return external
    end
end

local externalfiles = { }

setmetatableindex(externalfiles, function(t,k)
    local v = filedata[k]
    if not v then
        v = { k, k }
    end
    externalfiles[k] = v
    return v
end)

setmetatableindex(externals, function(t,k) -- either or not automatically
    local filename = externalfiles[k][1] -- filename
    local fullname = file.replacesuffix(filename,"tuc")
    if lfs.isfile(fullname) then -- todo: use other locator
        local utilitydata = job.loadother(fullname)
        if utilitydata then
            local external = loadexternalreferences(k,utilitydata)
            t[k] = external or false
            return external
        end
    end
    t[k] = false
    return false
end)

local productdata = allocate {
    productreferences   = { },
    componentreferences = { },
    components          = { },
}

references.productdata = productdata

local function loadproductreferences(productname,componentname,utilitydata)
    local struc = utilitydata.structures
    if struc then
        local productreferences = struc.references.collected -- direct references
        local lists = struc.lists.collected      -- indirect references (derived)
        local pages = struc.pages.collected      -- pagenumber data
        -- we use indirect tables to save room but as they are eventually
        -- just references we resolve them to data here (the mechanisms
        -- that use this data check for indirectness)
        for prefix, set in next, productreferences do
            for reference, data in next, set do
                if trace_importing then
                    report_importing("registering %s reference, kind %a, name %a, prefix %a, reference %a",
                        "product","regular",productname,prefix,reference)
                end
                local section  = reference.section
                local realpage = reference.realpage
                if section then
                    reference.sectiondata = lists[section]
                end
                if realpage then
                    reference.pagedata = pages[realpage]
                end
            end
        end
        --
        local componentreferences = { }
        for i=1,#lists do
            local entry      = lists[i]
            local metadata   = entry.metadata
            local references = entry.references
            if metadata and references then
                local reference = references.reference
                if reference and reference ~= "" then
                    local kind     = metadata.kind
                    local realpage = references.realpage
                    if kind and realpage then
                        references.pagedata = pages[realpage]
                        local prefix    = references.referenceprefix or ""
                        local component = references.component
                        local ctarget, ptarget
                        if not component or component == componentname then
                            -- skip
                        else
                            -- one level up
                            local external = componentreferences[component]
                            if not external then
                                external = { }
                                componentreferences[component] = external
                            end
                            if component == prefix then
                                prefix = ""
                            end
                            ctarget = external[prefix]
                            if not ctarget then
                                ctarget = { }
                                external[prefix] = ctarget
                            end
                        end
                        ptarget = productreferences[prefix]
                        if not ptarget then
                            ptarget = { }
                            productreferences[prefix] = ptarget
                        end
                        local function action(s)
                            if ptarget then
                                if trace_importing then
                                    report_importing("registering %s reference, kind %a, name %a, prefix %a, reference %a",
                                        "product",kind,productname,prefix,s)
                                end
                                ptarget[s] = ptarget[s] or entry
                            end
                            if ctarget then
                                if trace_importing then
                                    report_importing("registering %s reference, kind %a, name %a, prefix %a, referenc %a",
                                        "component",kind,productname,prefix,s)
                                end
                                ctarget[s] = ctarget[s] or entry
                            end
                        end
                        process_settings(reference,action)
                    end
                end
            end
        end
        productdata.productreferences   = productreferences -- not yet used
        productdata.componentreferences = componentreferences
    end
end

local function loadproductvariables(product,component,utilitydata)
    local struc = utilitydata.structures
    if struc then
        local lists = struc.lists and struc.lists.collected
        if lists then
            local pages = struc.pages and struc.pages.collected
            for i=1,#lists do
                local li = lists[i]
                if li.metadata.kind == "section" and li.references.component == component then
                    local firstsection = li
                    if firstsection.numberdata then
                        local numbers = firstsection.numberdata.numbers
                        if numbers then
                            if trace_importing then
                                report_importing("initializing section number to %:t",numbers)
                            end
                            productdata.firstsection = firstsection
                            structures.documents.preset(numbers)
                        end
                    end
                    if pages and firstsection.references then
                        local firstpage = pages[firstsection.references.realpage]
                        local number = firstpage and firstpage.number
                        if number then
                            if trace_importing then
                                report_importing("initializing page number to %a",number)
                            end
                            productdata.firstpage = firstpage
                            counters.set("userpage",1,number)
                        end
                    end
                    break
                end
            end
        end
    end
end

local function componentlist(tree,target)
    local branches = tree and tree.branches
    if branches then
        for i=1,#branches do
            local branch = branches[i]
            local type = branch.type
            if type == "component" then
                if target then
                    target[#target+1] = branch.name
                else
                    target = { branch.name }
                end
            elseif type == "product" or type == "component" then
                target = componentlist(branch,target)
            end
        end
    end
    return target
end

local function loadproductcomponents(product,component,utilitydata)
    local job = utilitydata.job
    productdata.components = componentlist(job and job.structure and job.structure.collected) or { }
end

references.registerinitializer(function(tobesaved,collected)
    -- not that much related to tobesaved or collected
    productdata.components = componentlist(job.structure.collected) or { }
end)

function references.loadpresets(product,component) -- we can consider a special components hash
    if product and component and product~= "" and component ~= "" and not productdata.product then -- maybe: productdata.filename ~= filename
        productdata.product = product
        productdata.component = component
        local fullname = file.replacesuffix(product,"tuc")
        if lfs.isfile(fullname) then -- todo: use other locator
            local utilitydata = job.loadother(fullname)
            if utilitydata then
                if trace_importing then
                    report_importing("loading references for component %a of product %a from %a",component,product,fullname)
                end
                loadproductvariables (product,component,utilitydata)
                loadproductreferences(product,component,utilitydata)
                loadproductcomponents(product,component,utilitydata)
             -- inspect(productdata)
            end
        end
    end
end

references.productdata = productdata

local useproduct = commands.useproduct

if useproduct then

    function commands.useproduct(product)
        useproduct(product)
        if texconditionals.autocrossfilereferences then
            local component = justacomponent()
            if component then
                if trace_referencing or trace_importing then
                    report_references("loading presets for component %a of product %a",component,product)
                end
                references.loadpresets(product,component)
            end
        end
    end

end

-- productdata.firstsection.numberdata.numbers
-- productdata.firstpage.number

local function report_identify_special(set,var,i,type)
    local reference = set.reference
    local prefix    = set.prefix or ""
    local special   = var.special
    local error     = var.error
    local kind      = var.kind
    if error then
        report_identifying("type %a, reference %a, index %a, prefix %a, special %a, error %a",type,reference,i,prefix,special,error)
    else
        report_identifying("type %a, reference %a, index %a, prefix %a, special %a, kind %a",type,reference,i,prefix,special,kind)
    end
end

local function report_identify_arguments(set,var,i,type)
    local reference = set.reference
    local prefix    = set.prefix or ""
    local arguments = var.arguments
    local error     = var.error
    local kind      = var.kind
    if error then
        report_identifying("type %a, reference %a, index %a, prefix %a, arguments %a, error %a",type,reference,i,prefix,arguments,error)
    else
        report_identifying("type %a, reference %a, index %a, prefix %a, arguments %a, kind %a",type,reference,i,prefix,arguments,kind)
    end
end

local function report_identify_outer(set,var,i,type)
    local reference = set.reference
    local prefix    = set.prefix or ""
    local outer     = var.outer
    local error     = var.error
    local kind      = var.kind
    if outer then
        if error then
            report_identifying("type %a, reference %a, index %a, prefix %a, outer %a, error %a",type,reference,i,prefix,outer,error)
        else
            report_identifying("type %a, reference %a, index %a, prefix %a, outer %a, kind %a",type,reference,i,prefix,outer,kind)
        end
    else
        if error then
            report_identifying("type %a, reference %a, index %a, prefix %a, error %a",type,reference,i,prefix,error)
        else
            report_identifying("type %a, reference %a, index %a, prefix %a, kind %a",type,reference,i,prefix,kind)
        end
    end
end

local function identify_special(set,var,i)
    local special = var.special
    local s = specials[special]
    if s then
        local outer     = var.outer
        local operation = var.operation
        local arguments = var.arguments
        if outer then
            if operation then
                -- special(outer::operation)
                var.kind = "special outer with operation"
            else
                -- special()
                var.kind = "special outer"
            end
            var.f = outer
        elseif operation then
            if arguments then
                -- special(operation{argument,argument})
                var.kind = "special operation with arguments"
            else
                -- special(operation)
                var.kind = "special operation"
            end
        else
            -- special()
            var.kind = "special"
        end
        if trace_identifying then
            report_identify_special(set,var,i,"1a")
        end
    else
        var.error = "unknown special"
    end
    return var
end

local function identify_arguments(set,var,i)
    local s = specials[var.inner]
    if s then
        -- inner{argument}
        var.kind = "special operation with arguments"
    else
        var.error = "unknown inner or special"
    end
    if trace_identifying then
        report_identify_arguments(set,var,i,"3a")
    end
    return var
end

-- needs checking: if we don't do too much (redundant) checking now
-- inner ... we could move the prefix logic into the parser so that we have 'm for each entry
-- foo:bar -> foo == prefix (first we try the global one)
-- -:bar   -> ignore prefix

local function finish_inner(var,p,i)
    var.kind = "inner"
    var.i = i
    var.p = p
    var.r = (i.references and i.references.realpage) or (i.pagedata and i.pagedata.realpage) or 1
    return var
end

local function identify_inner(set,var,prefix,collected,derived)
    local inner = var.inner
    -- the next test is a safeguard when references are auto loaded from outer
    if not inner or inner == "" then
        return false
    end
    local splitprefix, splitinner = lpegmatch(prefixsplitter,inner)
    if splitprefix and splitinner then
        -- we check for a prefix:reference instance in the regular set of collected
        -- references; a special case is -: which forces a lookup in the global list
        if splitprefix == "-" then
            local i = collected[""]
            if i then
                i = i[splitinner]
                if i then
                    return finish_inner(var,"",i)
                end
            end
        end
        local i = collected[splitprefix]
        if i then
            i = i[splitinner]
            if i then
                return finish_inner(var,splitprefix,i)
            end
        end
        if derived then
            -- next we look for a reference in the regular set of collected references
            -- using the prefix that is active at this moment (so we overload the given
            -- these are taken from other data structures (like lists)
            if splitprefix == "-" then
                local i = derived[""]
                if i then
                    i = i[splitinner]
                    if i then
                        return finish_inner(var,"",i)
                    end
                end
            end
            local i = derived[splitprefix]
            if i then
                i = i[splitinner]
                if i then
                    return finish_inner(var,splitprefix,i)
                end
            end
        end
    end
    -- we now ignore the split prefix and treat the whole inner as a potential
    -- referenice into the global list
    local i = collected[prefix]
    if i then
        i = i[inner]
        if i then
            return finish_inner(var,prefix,i)
        end
    end
    if not i and derived then
        -- and if not found we look in the derived references
        local i = derived[prefix]
        if i then
            i = i[inner]
            if i then
                return finish_inner(var,prefix,i)
            end
        end
    end
    return false
end

local function unprefixed_inner(set,var,prefix,collected,derived,tobesaved)
    local inner = var.inner
    local s = specials[inner]
    if s then
        var.kind = "special"
    else
        local i = (collected and collected[""] and collected[""][inner]) or
                  (derived   and derived  [""] and derived  [""][inner]) or
                  (tobesaved and tobesaved[""] and tobesaved[""][inner])
        if i then
            var.kind = "inner"
            var.p    = ""
            var.i    = i
            var.r    = (i.references and i.references.realpage) or (i.pagedata and i.pagedata.realpage) or 1
        else
            var.error = "unknown inner or special"
        end
    end
    return var
end

local function identify_outer(set,var,i)
    local outer    = var.outer
    local inner    = var.inner
    local external = externals[outer]
    if external then
        local v = identify_inner(set,var,nil,external)
        if v then
            v.kind = "outer with inner"
            set.external = true
            if trace_identifying then
                report_identify_outer(set,v,i,"2a")
            end
            return v
        end
        local v = identify_inner(set,var,var.outer,external)
        if v then
            v.kind = "outer with inner"
            set.external = true
            if trace_identifying then
                report_identify_outer(set,v,i,"2b")
            end
            return v
        end
    end
    local external = productdata.componentreferences[outer]
    if external then
        local v = identify_inner(set,var,nil,external)
        if v then
            v.kind = "outer with inner"
            set.external = true
            if trace_identifying then
                report_identify_outer(set,v,i,"2c")
            end
            return v
        end
    end
    local external = productdata.productreferences[outer]
    if external then
        local vi = external[inner]
        if vi then
            var.kind = "outer with inner"
            var.i = vi
            set.external = true
            if trace_identifying then
                report_identify_outer(set,var,i,"2d")
            end
            return var
        end
    end
    -- the rest
    local special   = var.special
    local arguments = var.arguments
    local operation = var.operation
    if inner then
        -- tricky: in this case we can only use views when we're sure that all inners
        -- are flushed in the outer document so that should become an option
        if arguments then
            -- outer::inner{argument}
            var.kind = "outer with inner with arguments"
        else
            -- outer::inner
            var.kind = "outer with inner"
        end
        var.i = inner
        var.f = outer
        var.r = (inner.references and inner.references.realpage) or (inner.pagedata and inner.pagedata.realpage) or 1
        if trace_identifying then
            report_identify_outer(set,var,i,"2e")
        end
    elseif special then
        local s = specials[special]
        if s then
            if operation then
                if arguments then
                    -- outer::special(operation{argument,argument})
                    var.kind = "outer with special and operation and arguments"
                else
                    -- outer::special(operation)
                    var.kind = "outer with special and operation"
                end
            else
                -- outer::special()
                var.kind = "outer with special"
            end
            var.f = outer
        else
            var.error = "unknown outer with special"
        end
        if trace_identifying then
            report_identify_outer(set,var,i,"2f")
        end
    else
        -- outer::
        var.kind = "outer"
        var.f = outer
        if trace_identifying then
            report_identify_outer(set,var,i,"2g")
        end
    end
    return var
end

-- todo: avoid copy

local function identify_inner_or_outer(set,var,i)
    -- here we fall back on product data
    local inner = var.inner
    if inner and inner ~= "" then

        -- first we look up in collected and derived using the current prefix

        local prefix = set.prefix

        local v = identify_inner(set,var,set.prefix,collected,derived)
        if v then
            if trace_identifying then
                report_identify_outer(set,v,i,"4a")
            end
            return v
        end

        -- nest we look at each component (but we can omit the already consulted one

        local components = job.structure.components
        if components then
            for c=1,#components do
                local component = components[c]
                if component ~= prefix then
                    local v = identify_inner(set,var,component,collected,derived)
                    if v then
                        if trace_identifying then
                            report_identify_outer(set,var,i,"4b")
                        end
                        return v
                    end
                end
            end
        end

        -- as a last resort we will consult the global lists

        local v = unprefixed_inner(set,var,"",collected,derived,tobesaved)
        if v then
            if trace_identifying then
                report_identify_outer(set,v,i,"4c")
            end
            return v
        end

        -- not it gets bad ... we need to look in external files ... keep in mind that
        -- we can best use explicit references for this ... we might issue a warning

        local componentreferences = productdata.componentreferences
        local productreferences = productdata.productreferences
        local components = productdata.components
        if components and componentreferences then
            for c=1,#components do
                local component = components[c]
                local data = componentreferences[component]
                if data then
                    local d = data[""]
                    local vi = d and d[inner]
                    if vi then
                        var.outer = component
                        var.i = vi
                        var.kind = "outer with inner"
                        set.external = true
                        if trace_identifying then
                            report_identify_outer(set,var,i,"4d")
                        end
                        return var
                    end
                end
            end
        end
        local component, inner = lpegmatch(componentsplitter,inner)
        if component then
            local data = componentreferences and componentreferences[component]
            if data then
                local d = data[""]
                local vi = d and d[inner]
                if vi then
                    var.inner = inner
                    var.outer = component
                    var.i = vi
                    var.kind = "outer with inner"
                    set.external = true
                    if trace_identifying then
                        report_identify_outer(set,var,i,"4e")
                    end
                    return var
                end
            end
            local data = productreferences and productreferences[component]
            if data then
                local vi = data[inner]
                if vi then
                    var.inner = inner
                    var.outer = component
                    var.i = vi
                    var.kind = "outer with inner"
                    set.external = true
                    if trace_identifying then
                        report_identify_outer(set,var,i,"4f")
                    end
                    return var
                end
            end
        end
        var.error = "unknown inner"
    else
        var.error = "no inner"
    end
    if trace_identifying then
        report_identify_outer(set,var,i,"4g")
    end
    return var
end

local function identify_inner_component(set,var,i)
    -- we're in a product (maybe ignore when same as component)
    local component = var.component
    local v = identify_inner(set,var,component,collected,derived)
    if not v then
        var.error = "unknown inner in component"
    end
    if trace_identifying then
        report_identify_outer(set,var,i,"5a")
    end
    return var
end

local function identify_outer_component(set,var,i)
    local component = var.component
    local inner = var.inner
    local data = productdata.componentreferences[component]
    if data then
        local d = data[""]
        local vi = d and d[inner]
        if vi then
            var.inner = inner
            var.outer = component
            var.i = vi
            var.kind = "outer with inner"
            set.external = true
            if trace_identifying then
                report_identify_outer(set,var,i,"6a")
            end
            return var
        end
    end
    local data = productdata.productreferences[component]
    if data then
        local vi = data[inner]
        if vi then
            var.inner = inner
            var.outer = component
            var.i = vi
            var.kind = "outer with inner"
            set.external = true
            if trace_identifying then
                report_identify_outer(set,var,i,"6b")
            end
            return var
        end
    end
    var.error = "unknown component"
    if trace_identifying then
        report_identify_outer(set,var,i,"6c")
    end
    return var
end

local nofidentified = 0

local function identify(prefix,reference)
    if not reference then
        prefix    = ""
        reference = prefix
    end
    local set = resolve(prefix,reference)
    local bug = false
    texsetcount("referencehastexstate",set.has_tex and 1 or 0)
    nofidentified = nofidentified + 1
    set.n = nofidentified
    for i=1,#set do
        local var = set[i]
        if var.special then
            var = identify_special(set,var,i)
        elseif var.outer then
            var = identify_outer(set,var,i)
        elseif var.arguments then
            var = identify_arguments(set,var,i)
        elseif not var.component then
            var = identify_inner_or_outer(set,var,i)
        elseif productcomponent() then
            var = identify_inner_component(set,var,i)
        else
            var = identify_outer_component(set,var,i)
        end
        set[i] = var
        bug = bug or var.error
    end
    references.currentset = mark(set) -- mark, else in api doc
    if trace_analyzing then
        report_references(table.serialize(set,reference))
    end
    return set, bug
end

references.identify = identify

local unknowns, nofunknowns, f_valid = { }, 0, formatters["[%s][%s]"]

function references.valid(prefix,reference,highlight,newwindow,layer)
    local set, bug = identify(prefix,reference)
    local unknown = bug or #set == 0
    if unknown then
        currentreference = nil -- will go away
        local str = f_valid(prefix,reference)
        local u = unknowns[str]
        if not u then
            interfaces.showmessage("references",1,str) -- 1 = unknown, 4 = illegal
            unknowns[str] = 1
            nofunknowns = nofunknowns + 1
        else
            unknowns[str] = u + 1
        end
    else
        set.highlight, set.newwindow, set.layer = highlight, newwindow, layer
        currentreference = set[1]
    end
    -- we can do the expansion here which saves a call
    return not unknown
end

function commands.doifelsereference(prefix,reference,highlight,newwindow,layer)
    commands.doifelse(references.valid(prefix,reference,highlight,newwindow,layer))
end

function references.reportproblems() -- might become local
    if nofunknowns > 0 then
        statistics.register("cross referencing", function()
            return format("%s identified, %s unknown",nofidentified,nofunknowns)
        end)
        logspushtarget("logfile")
        logsnewline()
        report_references("start problematic references")
        logsnewline()
        for k, v in table.sortedpairs(unknowns) do
            report_unknown("%4i: %s",v,k)
        end
        logsnewline()
        report_references("stop problematic references")
        logsnewline()
        logspoptarget()
    end
end

luatex.registerstopactions(references.reportproblems)

-- The auto method will try to avoid named internals in a clever way which
-- can make files smaller without sacrificing external references. Some of
-- the housekeeping happens the backend side.

local innermethod        = v_auto       -- only page|auto now
local defaultinnermethod = defaultinnermethod
references.innermethod   = innermethod  -- don't mess with this one directly

function references.setinnermethod(m)
    if toboolean(m) or m == v_page then
        innermethod = v_page
    else
        innermethod = v_auto
    end
    references.innermethod = innermethod
    function references.setinnermethod()
        report_references("inner method is already set and frozen to %a",innermethod)
    end
end

function references.getinnermethod()
    return innermethod or defaultinnermethod
end

directives.register("references.linkmethod", function(v) -- page auto
    references.setinnermethod(v)
end)

-- this is inconsistent

local destinationattributes = { }

local function setinternalreference(prefix,tag,internal,view) -- needs checking
    local destination = unsetvalue
    if innermethod == v_auto then
        local t, tn = { }, 0 -- maybe add to current
        if tag then
            if prefix and prefix ~= "" then
                prefix = prefix .. ":" -- watch out, : here
                local function action(ref)
                    tn = tn + 1
                    t[tn] = prefix .. ref
                end
                process_settings(tag,action)
            else
                local function action(ref)
                    tn = tn + 1
                    t[tn] = ref
                end
                process_settings(tag,action)
            end
        end
        -- ugly .. later we decide to ignore it when we have a real one
        -- but for testing we might want to see them all
        if internal then
            tn = tn + 1
            t[tn] = internal -- when number it's internal
        end
        destination = references.mark(t,nil,nil,view) -- returns an attribute
    end
    if internal then -- new
        destinationattributes[internal] = destination
    end
    texsetcount("lastdestinationattribute",destination)
    return destination
end

local function getinternalreference(internal)
    return destinationattributes[internal] or 0
end

references.setinternalreference = setinternalreference
references.getinternalreference = getinternalreference
commands.setinternalreference   = setinternalreference
commands.getinternalreference   = getinternalreference

function references.setandgetattribute(kind,prefix,tag,data,view) -- maybe do internal automatically here
    local attr = references.set(kind,prefix,tag,data) and setinternalreference(prefix,tag,nil,view) or unsetvalue
    texsetcount("lastdestinationattribute",attr)
    return attr
end

commands.setreferenceattribute = references.setandgetattribute

function references.getinternallistreference(n) -- n points into list (todo: registers)
    local l = lists.collected[n]
    local i = l and l.references.internal
    return i and destinationattributes[i] or 0
end

function commands.getinternallistreference(n) -- this will also be a texcount
    local l = lists.collected[n]
    local i = l and l.references.internal
    context(i and destinationattributes[i] or 0)
end

--

function references.getcurrentmetadata(tag)
    local data = currentreference and currentreference.i
    return data and data.metadata and data.metadata[tag]
end

function commands.getcurrentreferencemetadata(tag)
    local data = references.getcurrentmetadata(tag)
    if data then
        context(data)
    end
end

local function currentmetadata(tag)
    local data = currentreference and currentreference.i
    return data and data.metadata and data.metadata[tag]
end

references.currentmetadata = currentmetadata

local function getcurrentprefixspec(default)
    -- todo: message
    return currentmetadata("kind") or "?", currentmetadata("name") or "?", default or "?"
end

references.getcurrentprefixspec = getcurrentprefixspec

function commands.getcurrentprefixspec(default)
    ctx_getreferencestructureprefix(getcurrentprefixspec(default))
end

local genericfilters = { }
local userfilters    = { }
local textfilters    = { }
local fullfilters    = { }
local sectionfilters = { }

filters.generic = genericfilters
filters.user    = userfilters
filters.text    = textfilters
filters.full    = fullfilters
filters.section = sectionfilters

local function filterreference(name,...) -- number page title ...
    local data = currentreference and currentreference.i -- maybe we should take realpage from here
    if data then
        if name == "realpage" then
            local cs = references.analyze() -- normally already analyzed but also sets state
            context(tonumber(cs.realpage) or 0) -- todo, return and in command namespace
        else -- assumes data is table
            local kind = type(data) == "table" and data.metadata and data.metadata.kind
            if kind then
                local filter = filters[kind] or genericfilters
                filter = filter and (filter[name] or filter.unknown or genericfilters[name] or genericfilters.unknown)
                if filter then
                    if trace_referencing then
                        report_references("name %a, kind %a, using dedicated filter",name,kind)
                    end
                    filter(data,name,...)
                elseif trace_referencing then
                    report_references("name %a, kind %a, using generic filter",name,kind)
                end
            elseif trace_referencing then
                report_references("name %a, unknown kind",name)
            end
        end
    elseif name == "realpage" then
        context(0)
    elseif trace_referencing then
        report_references("name %a, no reference",name)
    end
end

local function filterreferencedefault()
    return filterreference("default",getcurrentprefixspec(v_default))
end

references.filter        = filterreference
references.filterdefault = filterreferencedefault

commands.filterreference        = filterreference
commands.filterdefaultreference = filterreferencedefault

function commands.currentreferencedefault(tag)
    if not tag then
        tag = "default"
    end
    filterreference(tag,context_delayed(getcurrentprefixspec(tag)))
end

function genericfilters.title(data)
    if data then
        local titledata = data.titledata or data.useddata
        if titledata then
            helpers.title(titledata.title or "?",data.metadata)
        end
    end
end

function genericfilters.text(data)
    if data then
        local entries = data.entries or data.useddata
        if entries then
            helpers.title(entries.text or "?",data.metadata)
        end
    end
end

function genericfilters.number(data,what,prefixspec) -- todo: spec and then no stopper
    if data then
        numberdata = lists.reordered(data) -- data.numberdata
        if numberdata then
            helpers.prefix(data,prefixspec)
            sections.typesetnumber(numberdata,"number",numberdata)
        else
            local useddata = data.useddata
            if useddata and useddata.number then
                context(useddata.number)
            end
        end
    end
end

genericfilters.default = genericfilters.text

function genericfilters.page(data,prefixspec,pagespec)
    local pagedata = data.pagedata
    if pagedata then
        local number, conversion = pagedata.number, pagedata.conversion
        if not number then
            -- error
        elseif conversion then
            ctx_convertnumber(conversion,number)
        else
            context(number)
        end
    else
        helpers.prefixpage(data,prefixspec,pagespec)
    end
end

function userfilters.unknown(data,name)
    if data then
        local userdata = data.userdata
        local userkind = userdata and userdata.kind
        if userkind then
            local filter = filters[userkind] or genericfilters
            filter = filter and (filter[name] or filter.unknown)
            if filter then
                filter(data,name)
                return
            end
        end
        local namedata = userdata and userdata[name]
        if namedata then
            context(namedata)
        end
    end
end

function textfilters.title(data)
    helpers.title(data.entries.text or "?",data.metadata)
end

-- no longer considered useful:
--
-- function filters.text.number(data)
--     helpers.title(data.entries.text or "?",data.metadata)
-- end

function textfilters.page(data,prefixspec,pagespec)
    helpers.prefixpage(data,prefixspec,pagespec)
end

fullfilters.title = textfilters.title
fullfilters.page  = textfilters.page

function sectionfilters.number(data,what,prefixspec)
    if data then
        local numberdata = data.numberdata
        if not numberdata then
            local useddata = data.useddata
            if useddata and useddata.number then
                context(useddata.number)
            end
        elseif numberdata.hidenumber then
            local references = data.references
            if trace_empty then
                report_empty("reference %a has a hidden number",references.reference)
                ctx_emptyreference() -- maybe an option
            end
        else
            sections.typesetnumber(numberdata,"number",prefixspec,numberdata)
        end
    end
end

sectionfilters.title   = genericfilters.title
sectionfilters.page    = genericfilters.page
sectionfilters.default = sectionfilters.number

-- filters.note        = { default = genericfilters.number }
-- filters.formula     = { default = genericfilters.number }
-- filters.float       = { default = genericfilters.number }
-- filters.description = { default = genericfilters.number }
-- filters.item        = { default = genericfilters.number }

setmetatableindex(filters, function(t,k) -- beware, test with rawget
    local v = { default = genericfilters.number } -- not copy as it might be extended differently
    t[k] = v
    return v
end)

-- function references.sectiontitle(n)
--     helpers.sectiontitle(lists.collected[tonumber(n) or 0])
-- end

-- function references.sectionnumber(n)
--     helpers.sectionnumber(lists.collected[tonumber(n) or 0])
-- end

-- function references.sectionpage(n,prefixspec,pagespec)
--     helpers.prefixedpage(lists.collected[tonumber(n) or 0],prefixspec,pagespec)
-- end

-- analyze

references.testrunners  = references.testrunners  or { }
references.testspecials = references.testspecials or { }

local runners  = references.testrunners
local specials = references.testspecials

-- We need to prevent ending up in the 'relative location' analyzer as it is
-- pretty slow (progressively). In the pagebody one can best check the reference
-- real page to determine if we need contrastlocation as that is more lightweight.

local function checkedpagestate(n,page,actions,position,spread)
    local p = tonumber(page)
    if not p then
        return 0
    end
    if position and #actions > 0 then
        local i = actions[1].i -- brrr
        if i then
            local a = i.references
            if a then
                local x = a.x
                local y = a.y
                if x and y then
                    local jp = jobpositions.collected[position]
                    if jp then
                        local px = jp.x
                        local py = jp.y
                        local pp = jp.p
                        if p == pp then
                            -- same page
                            if py > y then
                                return 5 -- above
                            elseif py < y then
                                return 4 -- below
                            elseif px > x then
                                return 4 -- below
                            elseif px < x then
                                return 5 -- above
                            else
                                return 1 -- same
                            end
                        elseif spread then
                            if pp % 2 == 0 then
                                -- left page
                                if pp > p then
                                    return 2 -- before
                                elseif pp + 1 == p then
--                                     return 4 -- below (on right page)
                                    return 5 -- above (on left page)
                                else
                                    return 3 -- after
                                end
                            else
                                -- right page
                                if pp < p then
                                    return 3 -- after
                                elseif pp - 1 == p then
--                                     return 5 -- above (on left page)
                                    return 4 -- below (on right page)
                                else
                                    return 2 -- before
                                end
                            end
                        elseif pp > p then
                            return 2 -- before
                        else
                            return 3 -- after
                        end
                    end
                end
            end
        end
    end
    local r = referredpage(n) -- sort of obsolete
    if p > r then
        return 3 -- after
    elseif p < r then
        return 2 -- before
    else
        return 1 -- same
    end
end

local function setreferencerealpage(actions)
    if not actions then
        actions = references.currentset
    end
    if not actions then
        return 0
    else
        local realpage = actions.realpage
        if realpage then
            return realpage
        end
        local nofactions = #actions
        if nofactions > 0 then
            for i=1,nofactions do
                local a = actions[i]
                local what = runners[a.kind]
                if what then
                    what = what(a,actions) -- needs documentation
                end
            end
            realpage = actions.realpage
            if realpage then
                return realpage
            end
        end
        actions.realpage = 0
        return 0
    end
end

-- we store some analysis data alongside the indexed array
-- at this moment only the real reference page is analyzed
-- normally such an analysis happens in the backend code

function references.analyze(actions,position,spread)
    if not actions then
        actions = references.currentset
    end
    if not actions then
        actions = { realpage = 0, pagestate = 0 }
    elseif actions.pagestate then
        -- already done
    else
        local realpage = actions.realpage or setreferencerealpage(actions)
        if realpage == 0 then
            actions.pagestate = 0
        elseif actions.external then
            actions.pagestate = 0
        else
            actions.pagestate = checkedpagestate(actions.n,realpage,actions,position,spread)
        end
    end
    return actions
end

-- function commands.referencepagestate(actions)
--     if not actions then
--         actions = references.currentset
--     end
--     if not actions then
--         context(0)
--     else
--         if not actions.pagestate then
--             references.analyze(actions) -- delayed unless explicitly asked for
--         end
--         context(actions.pagestate)
--     end
-- end

function commands.referencepagestate(position,detail,spread)
    local actions = references.currentset
    if not actions then
        context(0)
    else
        if not actions.pagestate then
            references.analyze(actions,position,spread) -- delayed unless explicitly asked for
        end
        local pagestate = actions.pagestate
        if detail then
            context(pagestate)
        elseif pagestate == 4 then
            context(2) -- compatible
        elseif pagestate == 5 then
            context(3) -- compatible
        else
            context(pagestate)
        end
    end
end

function commands.referencerealpage(actions)
    actions = actions or references.currentset
    context(not actions and 0 or actions.realpage or setreferencerealpage(actions))
end

local plist, nofrealpages

local function realpageofpage(p) -- the last one counts !
    if not plist then
        local pages = structures.pages.collected
        nofrealpages = #pages
        plist = { }
        for rp=1,nofrealpages do
            local page = pages[rp]
            if page then
                plist[page.number] = rp
            end
        end
        references.nofrealpages = nofrealpages
    end
    return plist[p]
end

references.realpageofpage = realpageofpage

function references.checkedrealpage(r)
    if not plist then
        realpageofpage(r) -- just initialize
    end
    if not r then
        return texgetcount("realpageno")
    elseif r < 1 then
        return 1
    elseif r > nofrealpages then
        return nofrealpages
    else
        return r
    end
end

-- use local ?

local pages = allocate {
    [variables.firstpage]       = function() return counters.record("realpage")["first"]    end,
    [variables.previouspage]    = function() return counters.record("realpage")["previous"] end,
    [variables.nextpage]        = function() return counters.record("realpage")["next"]     end,
    [variables.lastpage]        = function() return counters.record("realpage")["last"]     end,

    [variables.firstsubpage]    = function() return counters.record("subpage" )["first"]    end,
    [variables.previoussubpage] = function() return counters.record("subpage" )["previous"] end,
    [variables.nextsubpage]     = function() return counters.record("subpage" )["next"]     end,
    [variables.lastsubpage]     = function() return counters.record("subpage" )["last"]     end,

    [variables.forward]         = function() return counters.record("realpage")["forward"]  end,
    [variables.backward]        = function() return counters.record("realpage")["backward"] end,
}

references.pages = pages

-- maybe some day i will merge this in the backend code with a testmode (so each
-- runner then implements a branch)

runners["inner"] = function(var,actions)
    local r = var.r
    if r then
        actions.realpage = r
    end
end

runners["special"] = function(var,actions)
    local handler = specials[var.special]
    return handler and handler(var,actions)
end

runners["special operation"]                = runners["special"]
runners["special operation with arguments"] = runners["special"]

-- These are the testspecials not the real ones. They are used to
-- check the validity.

function specials.internal(var,actions)
    local v = internals[tonumber(var.operation)]
    local r = v and v.references.realpage
    if r then
        actions.realpage = r
    end
end

specials.i = specials.internal

function specials.page(var,actions)
    local o = var.operation
    local p = pages[o]
    if type(p) == "function" then
        p = p()
    else
        p = tonumber(realpageofpage(tonumber(o)))
    end
    if p then
        var.r = p
        actions.realpage = actions.realpage or p -- first wins
    end
end

function specials.realpage(var,actions)
    local p = tonumber(var.operation)
    if p then
        var.r = p
        actions.realpage = actions.realpage or p -- first wins
    end
end

function specials.userpage(var,actions)
    local p = tonumber(realpageofpage(var.operation))
    if p then
        var.r = p
        actions.realpage = actions.realpage or p -- first wins
    end
end

function specials.deltapage(var,actions)
    local p = tonumber(var.operation)
    if p then
        p = references.checkedrealpage(p + texgetcount("realpageno"))
        var.r = p
        actions.realpage = actions.realpage or p -- first wins
    end
end

function specials.section(var,actions)
    local sectionname = var.arguments
    local destination = var.operation
    local internal    = structures.sections.internalreference(sectionname,destination)
    if internal then
        var.special   = "internal"
        var.operation = internal
        var.arguments = nil
        specials.internal(var,actions)
    end
end

-- needs a better split ^^^

-- done differently now:

function references.export(usedname) end
function references.import(usedname) end
function references.load  (usedname) end

commands.exportreferences = references.export

-- better done here .... we don't insert/remove, just use a pointer

local prefixstack = { "" }
local prefixlevel = 1

function commands.pushreferenceprefix(prefix)
    prefixlevel = prefixlevel + 1
    prefixstack[prefixlevel] = prefix
    context(prefix)
end

function commands.popreferenceprefix()
    prefixlevel = prefixlevel - 1
    if prefixlevel > 0 then
        context(prefixstack[prefixlevel])
    else
        report_references("unable to pop referenceprefix")
    end
end
