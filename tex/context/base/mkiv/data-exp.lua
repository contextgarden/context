if not modules then modules = { } end modules ['data-exp'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local format, find, gmatch, lower, char, sub = string.format, string.find, string.gmatch, string.lower, string.char, string.sub
local concat, sort = table.concat, table.sort
local sortedkeys = table.sortedkeys
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns
local Ct, Cs, Cc, Carg, P, C, S = lpeg.Ct, lpeg.Cs, lpeg.Cc, lpeg.Carg, lpeg.P, lpeg.C, lpeg.S
local type, next = type, next
local isdir = lfs.isdir

local collapsepath, joinpath, basename = file.collapsepath, file.join, file.basename

local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v end)
local trace_expansions = false  trackers.register("resolvers.expansions", function(v) trace_expansions = v end)
local trace_globbing   = true   trackers.register("resolvers.globbing",   function(v) trace_globbing   = v end)

local report_expansions = logs.reporter("resolvers","expansions")
local report_globbing   = logs.reporter("resolvers","globbing")

local resolvers     = resolvers
local resolveprefix = resolvers.resolve

-- As this bit of code is somewhat special it gets its own module. After
-- all, when working on the main resolver code, I don't want to scroll
-- past this every time. See data-obs.lua for the gsub variant.

-- local function f_first(a,b)
--     local t, n = { }, 0
--     for s in gmatch(b,"[^,]+") do
--         n = n + 1 ; t[n] = a .. s
--     end
--     return concat(t,",")
-- end
--
-- local function f_second(a,b)
--     local t, n = { }, 0
--     for s in gmatch(a,"[^,]+") do
--         n = n + 1 ; t[n] = s .. b
--     end
--     return concat(t,",")
-- end

-- kpsewhich --expand-braces '{a,b}{c,d}'
-- ac:bc:ad:bd

-- old  {a,b}{c,d} => ac ad bc bd
--
-- local function f_both(a,b)
--     local t, n = { }, 0
--     for sa in gmatch(a,"[^,]+") do
--         for sb in gmatch(b,"[^,]+") do
--             n = n + 1 ; t[n] = sa .. sb
--         end
--     end
--     return concat(t,",")
-- end
--
-- new  {a,b}{c,d} => ac bc ad bd

local function f_both(a,b)
    local t, n = { }, 0
    for sb in gmatch(b,"[^,]+") do              -- and not sa
        for sa in gmatch(a,"[^,]+") do          --         sb
            n = n + 1 ; t[n] = sa .. sb
        end
    end
    return concat(t,",")
end

local comma   = P(",")
local nocomma = (1-comma)^1
local docomma = comma^1/","
local before  = Cs((nocomma * Carg(1) + docomma)^0)
local after   = Cs((Carg(1) * nocomma + docomma)^0)
local both    = Cs(((C(nocomma) * Carg(1))/function(a,b) return lpegmatch(before,b,1,a) end + docomma)^0)

local function f_first (a,b) return lpegmatch(after, b,1,a) end
local function f_second(a,b) return lpegmatch(before,a,1,b) end
local function f_both  (a,b) return lpegmatch(both,  b,1,a) end

-- print(f_first ("a",    "x,y,z"))
-- print(f_second("a,b,c","x"))
-- print(f_both  ("a,b,c","x,y,z"))

local left  = P("{")
local right = P("}")
local var   = P((1 - S("{}" ))^0)
local set   = P((1 - S("{},"))^0)
local other = P(1)

local l_first  = Cs( ( Cc("{") * (C(set) * left * C(var) * right / f_first) * Cc("}")               + other )^0 )
local l_second = Cs( ( Cc("{") * (left * C(var) * right * C(set) / f_second) * Cc("}")              + other )^0 )
local l_both   = Cs( ( Cc("{") * (left * C(var) * right * left * C(var) * right / f_both) * Cc("}") + other )^0 )
local l_rest   = Cs( ( left * var * (left/"") * var * (right/"") * var * right                      + other )^0 )

local stripper_1 = lpeg.stripper ("{}@")
local replacer_1 = lpeg.replacer { { ",}", ",@}" }, { "{,", "{@," }, }

local function splitpathexpr(str, newlist, validate) -- I couldn't resist lpegging it (nice exercise).
    if trace_expansions then
        report_expansions("expanding variable %a",str)
    end
    local t, ok, done = newlist or { }, false, false
    local n = #t
    str = lpegmatch(replacer_1,str)
    repeat
        local old = str
        repeat
            local old = str
            str = lpegmatch(l_first, str)
        until old == str
        repeat
            local old = str
            str = lpegmatch(l_second,str)
        until old == str
        repeat
            local old = str
            str = lpegmatch(l_both,  str)
        until old == str
        repeat
            local old = str
            str = lpegmatch(l_rest,  str)
        until old == str
    until old == str -- or not find(str,"{",1,true)
    str = lpegmatch(stripper_1,str)
    if validate then
        for s in gmatch(str,"[^,]+") do
            s = validate(s)
            if s then
                n = n + 1
                t[n] = s
            end
        end
    else
        for s in gmatch(str,"[^,]+") do
            n = n + 1
            t[n] = s
        end
    end
    if trace_expansions then
        for k=1,#t do
            report_expansions("% 4i: %s",k,t[k])
        end
    end
    return t
end

-- We could make the previous one public.

local function validate(s)
    s = collapsepath(s) -- already keeps the trailing / and //
    return s ~= "" and not find(s,"^!*unset/*$") and s
end

resolvers.validatedpath = validate -- keeps the trailing //

function resolvers.expandedpathfromlist(pathlist)
    local newlist = { }
    for k=1,#pathlist do
        splitpathexpr(pathlist[k],newlist,validate)
    end
    return newlist
end

-- {a,b,c,d}
-- a,b,c/{p,q,r},d
-- a,b,c/{p,q,r}/d/{x,y,z}//
-- a,b,c/{p,q/{x,y,z},r},d/{p,q,r}
-- a,b,c/{p,q/{x,y,z},r},d/{p,q,r}
-- a{b,c}{d,e}f
-- {a,b,c,d}
-- {a,b,c/{p,q,r},d}
-- {a,b,c/{p,q,r}/d/{x,y,z}//}
-- {a,b,c/{p,q/{x,y,z}},d/{p,q,r}}
-- {a,b,c/{p,q/{x,y,z},w}v,d/{p,q,r}}
-- {$SELFAUTODIR,$SELFAUTOPARENT}{,{/share,}/texmf{-local,.local,}/web2c}

local usedhomedir = nil
local donegation  = (P("!") /""     )^0
local doslashes   = (P("\\")/"/" + 1)^0

local function expandedhome()
    if not usedhomedir then
        usedhomedir = lpegmatch(Cs(donegation * doslashes),environment.homedir or "")
        if usedhomedir == "~" or usedhomedir == "" or not isdir(usedhomedir) then
            if trace_expansions then
                report_expansions("no home dir set, ignoring dependent path using current path")
            end
            usedhomedir = "."
        end
    end
    return usedhomedir
end

local dohome  = ((P("~") + P("$HOME") + P("%HOME%")) / expandedhome)^0
local cleanup = Cs(donegation * dohome * doslashes)

resolvers.cleanpath = function(str)
    return str and lpegmatch(cleanup,str) or ""
end

-- print(resolvers.cleanpath(""))
-- print(resolvers.cleanpath("!"))
-- print(resolvers.cleanpath("~"))
-- print(resolvers.cleanpath("~/test"))
-- print(resolvers.cleanpath("!~/test"))
-- print(resolvers.cleanpath("~/test~test"))

-- This one strips quotes and funny tokens.

-- we have several options here:
--
-- expandhome = P("~") / "$HOME"              : relocateble
-- expandhome = P("~") / "home:"              : relocateble
-- expandhome = P("~") / environment.homedir  : frozen but unexpanded
-- expandhome = P("~") = dohome               : frozen and expanded

local expandhome = P("~") / "$HOME"

local dodouble = P('"') / "" * (expandhome + (1 - P('"')))^0 * P('"') / ""
local dosingle = P("'") / "" * (expandhome + (1 - P("'")))^0 * P("'") / ""
local dostring =               (expandhome +  1              )^0

local stripper = Cs(
    lpegpatterns.unspacer * (dosingle + dodouble + dostring) * lpegpatterns.unspacer
)

function resolvers.checkedvariable(str) -- assumes str is a string
    return type(str) == "string" and lpegmatch(stripper,str) or str
end

-- The path splitter:

-- A config (optionally) has the paths split in tables. Internally
-- we join them and split them after the expansion has taken place. This
-- is more convenient.

local cache = { }

local splitter = lpeg.tsplitat(";") -- as we move towards urls, prefixes and use tables we no longer do :

local backslashswapper = lpeg.replacer("\\","/")

local function splitconfigurationpath(str) -- beware, this can be either a path or a { specification }
    if str then
        local found = cache[str]
        if not found then
            if str == "" then
                found = { }
            else
                local split = lpegmatch(splitter,lpegmatch(backslashswapper,str)) -- can be combined
                found = { }
                local noffound = 0
                for i=1,#split do
                    local s = split[i]
                    if not find(s,"^{*unset}*") then
                        noffound = noffound + 1
                        found[noffound] = s
                    end
                end
                if trace_expansions then
                    report_expansions("splitting path specification %a",str)
                    for k=1,noffound do
                        report_expansions("% 4i: %s",k,found[k])
                    end
                end
                cache[str] = found
            end
        end
        return found
    end
end

resolvers.splitconfigurationpath = splitconfigurationpath

function resolvers.splitpath(str)
    if type(str) == 'table' then
        return str
    else
        return splitconfigurationpath(str)
    end
end

function resolvers.joinpath(str)
    if type(str) == 'table' then
        return joinpath(str)
    else
        return str
    end
end

-- The next function scans directories and returns a hash where the
-- entries are either strings or tables.
--
-- starting with . or .. etc or funny char
--
-- local l_forbidden = S("~`!#$%^&*()={}[]:;\"\'||\\/<>,?\n\r\t")
-- local l_confusing = P(" ")
-- local l_character = lpegpatterns.utf8
-- local l_dangerous = P(".")
--
-- local l_normal = (l_character - l_forbidden - l_confusing - l_dangerous) * (l_character - l_forbidden - l_confusing^2)^0 * P(-1)
-- ----- l_normal = l_normal * Cc(true) + Cc(false)
--
-- local function test(str)
--     print(str,lpegmatch(l_normal,str))
-- end
-- test("ヒラギノ明朝 Pro W3")
-- test("..ヒラギノ明朝 Pro W3")
-- test(":ヒラギノ明朝 Pro W3;")
-- test("ヒラギノ明朝 /Pro W3;")
-- test("ヒラギノ明朝 Pro  W3")

-- a lot of this caching can be stripped away when we have ssd's everywhere
--
-- we could cache all the (sub)paths here if needed

local attributes, directory = lfs.attributes, lfs.dir

local weird          = P(".")^1 + lpeg.anywhere(S("~`!#$%^&*()={}[]:;\"\'||<>,?\n\r\t"))
local lessweird      = P(".")^1 + lpeg.anywhere(S("~`#$%^&*:;\"\'||<>,?\n\r\t"))
local timer          = { }
local scanned        = { }
local nofscans       = 0
local scancache      = { }
local fullcache      = { }
----- simplecache    = { }
local nofsharedscans = 0
local addcasecraptoo = true -- experiment to let case matter a  bit (still fuzzy)

-- So, we assume either a lowercase name or a mixed case one but only one such case
-- as having Foo fOo foo FoO FOo etc on the system is braindead in any sane project.

local function scan(files,remap,spec,path,n,m,r,onlyone,tolerant)
    local full     = path == "" and spec or (spec .. path .. '/')
    local dirlist  = { }
    local nofdirs  = 0
    local pattern  = tolerant and lessweird or weird
    local filelist = { }
    local noffiles = 0
    for name, mode in directory(full) do
        if not lpegmatch(pattern,name) then
            if not mode then
                mode = attributes(full..name,"mode")
            end
            if mode == "file" then
                n = n + 1
                noffiles = noffiles + 1
                filelist[noffiles] = name
            elseif mode == "directory" then
                m = m + 1
                nofdirs = nofdirs + 1
                if path ~= "" then
                    dirlist[nofdirs] = path .. "/" .. name
                else
                    dirlist[nofdirs] = name
                end
            end
        end
    end
    if noffiles > 0 then
        sort(filelist)
        for i=1,noffiles do
            local name  = filelist[i]
            local lower = lower(name)
            local paths = files[lower]
            if paths then
                if onlyone then
                    -- forget about it
                else
                    if name ~= lower then
                        local rl = remap[lower]
                        if not rl then
                            remap[lower] = name
                            r = r + 1
                        elseif trace_globbing and rl ~= name then
                            report_globbing("confusing filename, name: %a, lower: %a, already: %a",name,lower,rl)
                        end
                        if addcasecraptoo then
                            local paths = files[name]
                            if not paths then
                                files[name] = path
                            elseif type(paths) == "string" then
                                files[name] = { paths, path }
                            else
                                paths[#paths+1] = path
                            end
                        end
                    end
                    if type(paths) == "string" then
                        files[lower] = { paths, path }
                    else
                        paths[#paths+1] = path
                    end
                end
            else -- probably unique anyway
                files[lower] = path
                if name ~= lower then
                    local rl = remap[lower]
                    if not rl then
                        remap[lower] = name
                        r = r + 1
                    elseif trace_globbing and rl ~= name then
                        report_globbing("confusing filename, name: %a, lower: %a, already: %a",name,lower,rl)
                    end
                end
            end
        end
    end
    if nofdirs > 0 then
        sort(dirlist)
        for i=1,nofdirs do
            files, remap, n, m, r = scan(files,remap,spec,dirlist[i],n,m,r,onlyonce,tolerant)
        end
    end
    scancache[sub(full,1,-2)] = files
    return files, remap, n, m, r
end

local function scanfiles(path,branch,usecache,onlyonce,tolerant)
    local realpath = resolveprefix(path)
    if usecache then
        local content = fullcache[realpath]
        if content then
            if trace_locating then
                report_expansions("using cached scan of path %a, branch %a",path,branch or path)
            end
            nofsharedscans = nofsharedscans + 1
            return content
        end
    end
    --
    statistics.starttiming(timer)
    if trace_locating then
        report_expansions("scanning path %a, branch %a",path,branch or path)
    end
    local content
    if isdir(realpath) then
        local files, remap, n, m, r = scan({ },{ },realpath .. '/',"",0,0,0,onlyonce,tolerant)
        content = {
            metadata = {
                path        = path, -- can be selfautoparent:texmf-whatever
                files       = n,
                directories = m,
                remappings  = r,
            },
            files = files,
            remap = remap,
        }
        if trace_locating then
            report_expansions("%s files found on %s directories with %s uppercase remappings",n,m,r)
        end
    else
        content = {
            metadata = {
                path        = path, -- can be selfautoparent:texmf-whatever
                files       = 0,
                directories = 0,
                remappings  = 0,
            },
            files = { },
            remap = { },
        }
        if trace_locating then
            report_expansions("invalid path %a",realpath)
        end
    end
    if usecache then
        scanned[#scanned+1] = realpath
        fullcache[realpath] = content
    end
    nofscans = nofscans + 1
    statistics.stoptiming(timer)
    return content
end

resolvers.scanfiles = scanfiles

function resolvers.simplescanfiles(path,branch,usecache)
    return scanfiles(path,branch,usecache,true,true) -- onlyonce
end

function resolvers.scandata()
    table.sort(scanned)
    return {
        n      = nofscans,
        shared = nofsharedscans,
        time   = statistics.elapsedtime(timer),
        paths  = scanned,
    }
end

function resolvers.get_from_content(content,path,name) -- or (content,name)
    if not content then
        return
    end
    local files = content.files
    if not files then
        return
    end
    local remap = content.remap
    if not remap then
        return
    end
    if name then
        -- this one resolves a remapped name
        local used = lower(name)
        return path, remap[used] or used
    else
        -- this one does a lookup and resolves a remapped name
        local name = path
--         if addcasecraptoo then
--             local path = files[name]
--             if path then
--                 return path, name
--             end
--         end
        local used = lower(name)
        local path = files[used]
        if path then
            return path, remap[used] or used
        end
    end
end

local nothing = function() end

function resolvers.filtered_from_content(content,pattern)
    if content and type(pattern) == "string" then
        local pattern = lower(pattern)
        local files   = content.files -- we could store the sorted list
        local remap   = content.remap
        if files and remap then
            local f = sortedkeys(files)
            local n = #f
            local i = 0
            local function iterator()
                while i < n do
                    i = i + 1
                    local k = f[i]
                    if find(k,pattern) then
                        return files[k], remap and remap[k] or k
                    end
                end
            end
            return iterator
        end
    end
    return nothing
end

-- inspect(resolvers.simplescanfiles("e:/temporary/mb-mp"))
-- inspect(resolvers.scanfiles("e:/temporary/mb-mp"))
