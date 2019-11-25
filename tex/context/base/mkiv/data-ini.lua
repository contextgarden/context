if not modules then modules = { } end modules ['data-ini'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local next, type, getmetatable, rawset = next, type, getmetatable, rawset
local gsub, find, gmatch, char = string.gsub, string.find, string.gmatch, string.char
local filedirname, filebasename, filejoin = file.dirname, file.basename, file.join
local ostype, osname, osuname, ossetenv, osgetenv = os.type, os.name, os.uname, os.setenv, os.getenv
local sortedpairs = table.sortedpairs

local P, S, R, C, Cs, Cc, lpegmatch = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.match

local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v end)
local trace_expansions = false  trackers.register("resolvers.expansions", function(v) trace_expansions = v end)

local report_initialization = logs.reporter("resolvers","initialization")

-- The code here used to be part of a data-res but for convenience we now split it over multiple
-- files. As this file is now the starting point we introduce resolvers here. We also put some
-- helpers here that later can be reimplemented of extended.

resolvers       = resolvers or { }
local resolvers = resolvers

-- We don't want the kpse library to kick in. Also, we want to be able to
-- execute programs. Control over execution is implemented later.

texconfig.kpse_init    = false
texconfig.shell_escape = 't'

if not (environment and environment.default_texmfcnf) and kpse and kpse.default_texmfcnf then
    local default_texmfcnf = kpse.default_texmfcnf()
    -- looks more like context
    default_texmfcnf = gsub(default_texmfcnf,"$SELFAUTOLOC","selfautoloc:")
    default_texmfcnf = gsub(default_texmfcnf,"$SELFAUTODIR","selfautodir:")
    default_texmfcnf = gsub(default_texmfcnf,"$SELFAUTOPARENT","selfautoparent:")
    default_texmfcnf = gsub(default_texmfcnf,"$HOME","home:")
    --
    environment.default_texmfcnf = default_texmfcnf
end

kpse = { original = kpse }

setmetatable(kpse, {
    __index = function(kp,name)
        report_initialization("fatal error: kpse library is accessed (key: %s)",name)
        os.exit()
    end
} )

-- First we check a couple of environment variables. Some might be
-- set already but we need then later on. We start with the system
-- font path.

do

    local osfontdir = osgetenv("OSFONTDIR")

    if osfontdir and osfontdir ~= "" then
        -- ok
    elseif osname == "windows" then
        ossetenv("OSFONTDIR","c:/windows/fonts//")
    elseif osname == "macosx" then
        ossetenv("OSFONTDIR","$HOME/Library/Fonts//;/Library/Fonts//;/System/Library/Fonts//")
    end

end

-- Next comes the user's home path. We need this as later on we have
-- to replace ~ with its value.

do

    local homedir = osgetenv(ostype == "windows" and 'USERPROFILE' or 'HOME') or ''

    if not homedir or homedir == "" then
        homedir = char(127) -- we need a value, later we wil trigger on it
    end

    homedir = file.collapsepath(homedir)

    ossetenv("HOME",       homedir) -- can be used in unix cnf files
    ossetenv("USERPROFILE",homedir) -- can be used in windows cnf files

    environment.homedir = homedir

end

-- The following code sets the name of the own binary and its
-- path. This is fallback code as we have os.selfdir now.

do

    local args = environment.originalarguments or arg -- this needs a cleanup

    if not environment.ownmain then
        environment.ownmain = status and string.match(string.lower(status.banner),"this is ([%a]+)") or "luatex"
    end

    local ownbin  = environment.ownbin  or args[-2] or arg[-2] or args[-1] or arg[-1] or arg[0] or "luatex"
    local ownpath = environment.ownpath or os.selfdir

    ownbin  = file.collapsepath(ownbin)
    ownpath = file.collapsepath(ownpath)

    if not ownpath or ownpath == "" or ownpath == "unset" then
        ownpath = args[-1] or arg[-1]
        ownpath = ownpath and filedirname(gsub(ownpath,"\\","/"))
        if not ownpath or ownpath == "" then
            ownpath = args[-0] or arg[-0]
            ownpath = ownpath and filedirname(gsub(ownpath,"\\","/"))
        end
        local binary = ownbin
        if not ownpath or ownpath == "" then
            ownpath = ownpath and filedirname(binary)
        end
        if not ownpath or ownpath == "" then
            if os.binsuffix ~= "" then
                binary = file.replacesuffix(binary,os.binsuffix)
            end
            local path = osgetenv("PATH")
            if path then
                for p in gmatch(path,"[^"..io.pathseparator.."]+") do
                    local b = filejoin(p,binary)
                    if lfs.isfile(b) then
                        -- we assume that after changing to the path the currentdir function
                        -- resolves to the real location and use this side effect here; this
                        -- trick is needed because on the mac installations use symlinks in the
                        -- path instead of real locations
                        local olddir = lfs.currentdir()
                        if lfs.chdir(p) then
                            local pp = lfs.currentdir()
                            if trace_locating and p ~= pp then
                                report_initialization("following symlink %a to %a",p,pp)
                            end
                            ownpath = pp
                            lfs.chdir(olddir)
                        else
                            if trace_locating then
                                report_initialization("unable to check path %a",p)
                            end
                            ownpath =  p
                        end
                        break
                    end
                end
            end
        end
        if not ownpath or ownpath == "" then
            ownpath = "."
            report_initialization("forcing fallback to ownpath %a",ownpath)
        elseif trace_locating then
            report_initialization("using ownpath %a",ownpath)
        end
    end

    environment.ownbin  = ownbin
    environment.ownpath = ownpath

end

resolvers.ownpath = environment.ownpath

function resolvers.getownpath()
    return environment.ownpath
end

-- The self variables permit us to use only a few (or even no)
-- environment variables.

do

    local ownpath = environment.ownpath or dir.current()

    if ownpath then
        ossetenv('SELFAUTOLOC',    file.collapsepath(ownpath))
        ossetenv('SELFAUTODIR',    file.collapsepath(ownpath .. "/.."))
        ossetenv('SELFAUTOPARENT', file.collapsepath(ownpath .. "/../.."))
    else
        report_initialization("error: unable to locate ownpath")
        os.exit()
    end

end

-- The running os:

-- todo: check is context sits here os.platform is more trustworthy
-- that the bin check as mtx-update runs from another path

local texos   = environment.texos   or osgetenv("TEXOS")
local texmfos = environment.texmfos or osgetenv('SELFAUTODIR')

if not texos or texos == "" then
    texos = file.basename(texmfos)
end

ossetenv('TEXMFOS',       texmfos)      -- full bin path
ossetenv('TEXOS',         texos)        -- partial bin parent
ossetenv('SELFAUTOSYSTEM',os.platform)  -- bonus

environment.texos   = texos
environment.texmfos = texmfos

-- The current root:

local texroot = environment.texroot or osgetenv("TEXROOT")

if not texroot or texroot == "" then
    texroot = osgetenv('SELFAUTOPARENT')
    ossetenv('TEXROOT',texroot)
end

environment.texroot = file.collapsepath(texroot)

-- if type(profiler) == "table" and not jit then
--     directives.register("system.profile",function()
--         profiler.start("luatex-profile.log")
--     end)
-- end

-- a forward definition

-- Because we use resolvers.resolve a lot later on, we will implement the basics here and
-- add more later.

local prefixes     = utilities.storage.allocate()
resolvers.prefixes = prefixes

local resolved     = { }
local abstract     = { }
local dynamic      = { }

function resolvers.resetresolve(str)
    resolved, abstract = { }, { }
end

function resolvers.allprefixes(separator)
    local all = table.sortedkeys(prefixes)
    if separator then
        for i=1,#all do
            all[i] = all[i] .. ":"
        end
    end
    return all
end

local function _resolve_(method,target)
    local action = prefixes[method]
    if action then
        return action(target)
    else
        return method .. ":" .. target
    end
end

function resolvers.unresolve(str)
    return abstract[str] or str
end

function resolvers.setdynamic(str)
    dynamic[str] = true
end

-- home:xx;selfautoparent:xx;

local pattern   = Cs((C(R("az")^2) * P(":") * C((1-S(" \"\';,"))^1) / _resolve_ + P(1))^0)

local prefix    = C(R("az")^2) * P(":")
local target    = C((1-S(" \"\';,"))^1)
local notarget  = (#S(";,") + P(-1)) * Cc("")

local p_resolve = Cs(((prefix * (target + notarget)) / _resolve_ + P(1))^0)
local p_simple  = prefix * P(-1)

local function resolve(str) -- use schemes, this one is then for the commandline only
    if type(str) == "table" then
        local res = { }
        for i=1,#str do
            res[i] = resolve(str[i])
        end
        return res
    end
    -- already resolved
    local res = resolved[str]
    if res then
        return res
    end
    -- simple resolving of (dynamic) methods
    local simple = lpegmatch(p_simple,str)
    local action = prefixes[simple]
    if action then
        local res = action(res)
        if not dynamic[simple] then
            resolved[simple] = res
            abstract[res] = simple
        end
        return res
    end
    -- more extensive resolving (multiple too)
    res = lpegmatch(p_resolve,str)
    resolved[str] = res
    abstract[res] = str
    return res
end

resolvers.resolve = resolve

if type(osuname) == "function" then

    for k, v in next, osuname() do
        if not prefixes[k] then
            prefixes[k] = function() return v end
        end
    end

end

if ostype == "unix" then

    -- We need to distringuish between a prefix and something else : so we
    -- have a special repath variant for linux. Also, when a new prefix is
    -- defined, we need to remake the matcher.

    local pattern

    local function makepattern(t,k,v)
        if t then
            rawset(t,k,v)
        end
        local colon = P(":")
        for k, v in sortedpairs(prefixes) do
            if p then
                p = P(k) + p
            else
                p = P(k)
            end
        end
        pattern = Cs((p * colon + colon/";" + P(1))^0)
    end

    makepattern()

    table.setmetatablenewindex(prefixes,makepattern)

    function resolvers.repath(str)
        return lpegmatch(pattern,str)
    end

else -- already the default:

    function resolvers.repath(str)
        return str
    end

end
