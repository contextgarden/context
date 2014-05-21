if not modules then modules = { } end modules ['file-mod'] = {
    version   = 1.001,
    comment   = "companion to file-mod.mkvi",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This module will be redone! For instance, the prefixes will move to data-*
-- as they arr sort of generic along with home:// etc/.

-- context is not defined yet! todo! (we need to load tupp-fil after cld)
-- todo: move startreadingfile to lua and push regime there

--[[ldx--
<p>It's more convenient to manipulate filenames (paths) in
<l n='lua'/> than in <l n='tex'/>. These methods have counterparts
at the <l n='tex'/> side.</p>
--ldx]]--

local format, concat, tonumber = string.format, table.concat, tonumber

local trace_modules     = false  trackers  .register("modules.loading",          function(v) trace_modules     = v end)
local permit_unprefixed = false  directives.register("modules.permitunprefixed", function(v) permit_unprefixed = v end)

local report_modules    = logs.reporter("resolvers","modules")

commands                = commands or { }
local commands          = commands

local context           = context

local findbyscheme      = resolvers.finders.byscheme -- use different one
local iterator          = utilities.parsers.iterator

-- modules can have a specific suffix or can specify one

local prefixes  = { "m", "p", "s", "x", "v", "t" }
local suffixes  = { "mkvi", "mkiv", "tex", "cld", "lua" } -- order might change and how about cld
local modstatus = { }

local function usemodule(name,hasscheme)
    local foundname
    if hasscheme then
        -- no auto suffix as http will return a home page or error page
        -- so we only add one if missing
        local fullname = file.addsuffix(name,"tex")
        if trace_modules then
            report_modules("checking url %a",fullname)
        end
        foundname = resolvers.findtexfile(fullname) or ""
    elseif file.suffix(name) ~= "" then
        if trace_modules then
            report_modules("checking file %a",name)
        end
        foundname = findbyscheme("any",name) or ""
    else
        for i=1,#suffixes do
            local fullname = file.addsuffix(name,suffixes[i])
            if trace_modules then
                report_modules("checking file %a",fullname)
            end
            foundname = findbyscheme("any",fullname) or ""
            if foundname ~= "" then
                break
            end
        end
    end
    if foundname ~= "" then
        if trace_modules then
            report_modules("loading file %a",foundname)
        end
        context.startreadingfile()
        resolvers.jobs.usefile(foundname,true) -- once, notext
     -- context.input(foundname)
        context.stopreadingfile()
        return true
    else
        return false
    end
end

function commands.usemodules(prefix,askedname,truename)
    local truename = truename or environment.truefilename(askedname)
    local hasprefix = prefix and prefix ~= ""
    local hashname = ((hasprefix and prefix) or "*") .. "-" .. truename
    local status = modstatus[hashname]
    if status == 0 then
        -- not found
    elseif status == 1 then
        status = status + 1
    else
        if trace_modules then
            report_modules("locating, prefix %a, askedname %a, truename %a",prefix,askedname,truename)
        end
        local hasscheme = url.hasscheme(truename)
        if hasscheme then
            -- no prefix and suffix done
            if usemodule(truename,true) then
                status = 1
            else
                status = 0
            end
        elseif hasprefix then
            if usemodule(prefix .. "-" .. truename) then
                status = 1
            else
                status = 0
            end
        else
            for i=1,#prefixes do
                -- todo: reconstruct name i.e. basename
                local thename = prefixes[i] .. "-" .. truename
                if usemodule(thename) then
                    status = 1
                    break
                end
            end
            if status then
                -- ok, don't change
            elseif not permit_unprefixed then
                -- forget about it
            elseif usemodule(truename) then
                report_modules("using unprefixed file %a",truename)
                status = 1
            else
                status = 0
            end
        end
    end
    if status == 0 then
        report_modules("%a is not found",askedname)
    elseif status == 1 then
        report_modules("%a is loaded",trace_modules and truename or askedname)
    else
        report_modules("%a is already loaded",trace_modules and truename or askedname)
    end
    modstatus[hashname] = status
end

statistics.register("loaded tex modules", function()
    if next(modstatus) then
        local t, f, nt, nf = { }, { }, 0, 0
        for k, v in table.sortedhash(modstatus) do
            k = file.basename(k)
            if v == 0 then
                nf = nf + 1
                f[nf] = k
            else
                nt = nt + 1
                t[nt] = k
            end
        end
        if nf == 0 then
            return format("%s requested, all found (%s)",nt,concat(t," "))
        elseif nt == 0 then
            return format("%s requested, all missing (%s)",nf,concat(f," "))
        else
            return format("%s requested, %s found (%s), %s missing (%s)",nt+nf,nt,concat(t," "),nf,concat(f," "))
        end
    else
        return nil
    end
end)

-- moved from syst-lua.lua:

local splitter = lpeg.tsplitter(lpeg.S(". "),tonumber)

function commands.doifolderversionelse(one,two) -- one >= two
    if not two then
        one, two = environment.version, one
    elseif one == "" then
        one = environment.version
    end
    one = lpeg.match(splitter,one)
    two = lpeg.match(splitter,two)
    one = (one[1] or 0) * 10000 + (one[2] or 0) * 100 + (one[3] or 0)
    two = (two[1] or 0) * 10000 + (two[2] or 0) * 100 + (two[3] or 0)
    commands.doifelse(one>=two)
end

function commands.useluamodule(list)
    for filename in iterator(list) do
        environment.loadluafile(filename)
    end
end
