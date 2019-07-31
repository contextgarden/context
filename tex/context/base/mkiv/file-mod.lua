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

local format, find, concat, tonumber = string.format, string.find, table.concat, tonumber
local sortedhash = table.sortedhash
local basename = file.basename

local trace_modules     = false  trackers  .register("modules.loading",          function(v) trace_modules     = v end)
local permit_unprefixed = false  directives.register("modules.permitunprefixed", function(v) permit_unprefixed = v end)

local report            = logs.reporter("modules")

local commands          = commands
local context           = context
local implement         = interfaces.implement

local findbyscheme      = resolvers.finders.byscheme -- use different one
local iterator          = utilities.parsers.iterator

-- modules can have a specific suffix or can specify one

local prefixes = {
    "m", -- module, extends functionality
    "p", -- private code
    "s", -- styles
    "x", -- xml specific modules
 -- "v", -- an old internal one for examples
    "t", -- third party extensions
}

-- the order might change and how about cld

local suffixes = CONTEXTLMTXMODE > 0 and
{
    "mklx", -- preprocessed mkiv lmtx files
    "mkxl", -- mkiv lmtx files
    "mkvi", -- preprocessed mkiv files
    "mkiv", -- mkiv files
    "tex",  -- normally source code files
    "cld",  -- context lua documents (often stand alone)
    "lua",  -- lua files
}
    or
{
    "mkvi",
    "mkiv",
    "tex",
    "cld",
    "lua",
}

local modstatus = { }
local missing   = false

local function usemodule(name,hasscheme)
    local foundname
    if hasscheme then
        -- no auto suffix as http will return a home page or error page
        -- so we only add one if missing
        local fullname = file.addsuffix(name,"tex")
        if trace_modules then
            report("checking url %a",fullname)
        end
        foundname = resolvers.findtexfile(fullname) or ""
    elseif file.suffix(name) ~= "" then
        if trace_modules then
            report("checking file %a",name)
        end
        foundname = findbyscheme("any",name) or ""
    else
        for i=1,#suffixes do
            local fullname = file.addsuffix(name,suffixes[i])
            if trace_modules then
                report("checking file %a",fullname)
            end
            foundname = findbyscheme("any",fullname) or ""
            if foundname ~= "" then
                break
            end
        end
    end
    if foundname ~= "" then
        if trace_modules then
            report("loading file %a",foundname)
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

function environment.usemodules(prefix,askedname,truename)
    local truename = truename or environment.truefilename(askedname)
    local hasprefix = prefix and prefix ~= ""
    local hashname = ((hasprefix and prefix) or "*") .. "-" .. truename
    local status = modstatus[hashname] or false -- yet unset
    if status == 0 then
        -- not found
    elseif status == 1 then
        status = status + 1
    else
        if trace_modules then
            report("locating, prefix %a, askedname %a, truename %a",prefix,askedname,truename)
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
            elseif find(truename,"-",1,true) and usemodule(truename) then
                -- assume a user namespace
                report("using user prefixed file %a",truename)
                status = 1
            elseif permit_unprefixed and usemodule(truename) then
                report("using unprefixed file %a",truename)
                status = 1
            else
                status = 0
            end
        end
    end
    if status == 0 then
        missing = true
        report("%a is not found",askedname)
    elseif status == 1 then
        report("%a is loaded",trace_modules and truename or askedname)
    else
        report("%a is already loaded",trace_modules and truename or askedname)
    end
    modstatus[hashname] = status
end

statistics.register("loaded tex modules", function()
    if next(modstatus) then
        local t, f, nt, nf = { }, { }, 0, 0
        for k, v in sortedhash(modstatus) do
            local b = basename(k)
            if v == 0 then
                nf = nf + 1
                f[nf] = b
            else
                nt = nt + 1
                t[nt] = b
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

logs.registerfinalactions(function()
    logs.startfilelogging(report,"used modules")
    for k, v in sortedhash(modstatus) do
        report(v == 0 and "missing: %s" or "loaded : %s",basename(k))
    end
    logs.stopfilelogging()
    if missing and logs.loggingerrors() then
        logs.starterrorlogging(report,"missing modules")
        for k, v in sortedhash(modstatus) do
            if v == 0 then
                report("%w%s",6,basename(k))
            end
        end
        logs.stoperrorlogging()
    end
end)

-- moved from syst-lua.lua:

local lpegmatch = lpeg.match
local splitter  = lpeg.tsplitter(lpeg.S(". "),tonumber)

function environment.comparedversion(one,two) -- one >= two
    if not two or two == "" then
        one, two = environment.version, one
    elseif one == "" then
        one = environment.version
    end
    one = lpegmatch(splitter,one)
    two = lpegmatch(splitter,two)
    one = (one[1] or 0) * 10000 + (one[2] or 0) * 100 + (one[3] or 0)
    two = (two[1] or 0) * 10000 + (two[2] or 0) * 100 + (two[3] or 0)
    if one < two then
        return -1
    elseif one > two then
        return 1
    else
        return 0
    end
end

environment.comparedversion = comparedversion


function environment.useluamodule(list)
    for filename in iterator(list) do
        environment.loadluafile(filename)
    end
end

local strings = interfaces.strings

implement {
    name      = "usemodules",
    actions   = environment.usemodules,
    arguments = strings[2]
}

implement {
    name      = "doifelseolderversion",
    actions   = function(one,two) commands.doifelse(comparedversion(one,two) >= 0) end,
    arguments = strings[2]
}

implement {
    name      = "useluamodule",
    actions   = environment.useluamodule,
    arguments = "string"
}

implement {
    name      = "loadluamodule",
    actions   = function(name) dofile(resolvers.findctxfile(name)) end, -- hack
    arguments = "string"
}

