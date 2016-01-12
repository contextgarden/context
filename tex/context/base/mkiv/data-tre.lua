if not modules then modules = { } end modules ['data-tre'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- tree://e:/temporary/mb-mp/**/drawing.jpg
-- tree://e:/temporary/mb-mp/**/Drawing.jpg
-- tree://t:./**/tufte.tex
-- tree://t:/./**/tufte.tex
-- tree://t:/**/tufte.tex
-- dirlist://e:/temporary/mb-mp/**/drawing.jpg
-- dirlist://e:/temporary/mb-mp/**/Drawing.jpg
-- dirlist://e:/temporary/mb-mp/**/just/some/place/drawing.jpg
-- dirlist://e:/temporary/mb-mp/**/images/drawing.jpg
-- dirlist://e:/temporary/mb-mp/**/images/drawing.jpg?option=fileonly
-- dirlist://///storage-2/resources/mb-mp/**/drawing.jpg
-- dirlist://e:/**/drawing.jpg

local find, gsub, lower = string.find, string.gsub, string.lower
local basename, dirname, joinname = file.basename, file.dirname, file   .join
local globdir, isdir, isfile = dir.glob, lfs.isdir, lfs.isfile
local P, lpegmatch = lpeg.P, lpeg.match

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_trees   = logs.reporter("resolvers","trees")

local resolvers      = resolvers
local resolveprefix  = resolvers.resolve
local notfound       = resolvers.finders.notfound
local lookup         = resolvers.get_from_content

-- A tree search is rather dumb ... there is some basic caching of searched trees
-- but nothing is cached over runs ... it's also a wildcard one so we cannot use
-- the normal scanner.

local collectors = { }
local found      = { }

function resolvers.finders.tree(specification) -- to be adapted to new formats
    local spec = specification.filename
    local okay = found[spec]
    if okay == nil then
        if spec ~= "" then
            local path = dirname(spec)
            local name = basename(spec)
            if path == "" then
                path = "."
            end
            local names = collectors[path]
            if not names then
                local pattern = find(path,"/%*+$") and path or (path .. "/*")
                names = globdir(pattern)
                collectors[path] = names
            end
            local pattern = "/" .. gsub(name,"([%.%-%+])", "%%%1") .. "$"
            for i=1,#names do
                local fullname = names[i]
                if find(fullname,pattern) then
                    found[spec] = fullname
                    return fullname
                end
            end
            -- let's be nice:
            local pattern = lower(pattern)
            for i=1,#names do
                local fullname = lower(names[i])
                if find(fullname,pattern) then
                    if isfile(fullname) then
                        found[spec] = fullname
                        return fullname
                    else
                        -- no os name mapping
                        break
                    end
                end
            end
        end
        okay = notfound() -- false
        found[spec] = okay
    end
    return okay
end

function resolvers.locators.tree(specification)
    local name = specification.filename
    local realname = resolveprefix(name) -- no shortcut
    if realname and realname ~= '' and isdir(realname) then
        if trace_locating then
            report_trees("locator %a found",realname)
        end
        resolvers.appendhash('tree',name,false) -- don't cache
    elseif trace_locating then
        report_trees("locator %a not found",name)
    end
end

function resolvers.hashers.tree(specification)
    local name = specification.filename
 -- if trace_locating then
        report_trees("analyzing %a",name)
 -- end
    resolvers.methodhandler("hashers",name)

    resolvers.generators.file(specification)
end

-- This is a variation on tree lookups but this time we do cache in the given
-- root. We use a similar hasher as the resolvers because we have to deal with
-- for instance trees with 50K xml files plus a similar amount of resources to
-- deal and we don't want too much overhead.

local collectors = { }
local splitter   = lpeg.splitat("/**/")
local stripper   = lpeg.replacer { [P("/") * P("*")^1 * P(-1)] = "" }

table.setmetatableindex(collectors, function(t,k)
    local rootname = lpegmatch(stripper,k)
    local dataname = joinname(rootname,"dirlist")
    local content  = caches.loadcontent(dataname,"files",dataname)
    if not content then
        -- path branch usecache onlyonce tolerant
        content = resolvers.scanfiles(rootname,nil,nil,false,true) -- so we accept crap
        caches.savecontent(dataname,"files",content,dataname)
    end
    t[k] = content
    return content
end)


local function checked(root,p,n)
    if p then
        if type(p) == "table" then
            for i=1,#p do
                local fullname = joinname(root,p[i],n)
                if isfile(fullname) then -- safeguard
                    return fullname
                end
            end
        else
            local fullname = joinname(root,p,n)
            if isfile(fullname) then -- safeguard
                return fullname
            end
        end
    end
    return notfound()
end

-- no funny characters in path but in filename permitted .. sigh

local function resolve(specification) -- can be called directly too
    local filename = specification.filename
 -- inspect(specification)
    if filename ~= "" then
        local root, rest = lpegmatch(splitter,filename)
        if root and rest then
            local path, name = dirname(rest), basename(rest)
            if name ~= rest then
                local content = collectors[root]
                local p, n = lookup(content,name)
                if not p then
                    return notfound()
                end
                local pattern = ".*/" .. path .. "$"
                local istable = type(p) == "table"
                if istable then
                    for i=1,#p do
                        local pi = p[i]
                        if pi == path or find(pi,pattern) then
                            local fullname = joinname(root,pi,n)
                            if isfile(fullname) then -- safeguard
                                return fullname
                            end
                        end
                    end
                elseif p == path or find(p,pattern) then
                    local fullname = joinname(root,p,n)
                    if isfile(fullname) then -- safeguard
                        return fullname
                    end
                end
                local queries = specification.queries
                if queries and queries.option == "fileonly" then
                    return checked(root,p,n)
                else
                    return notfound()
                end
            end
        end
        local path, name = dirname(filename), basename(filename)
        local root = lpegmatch(stripper,path)
        local content = collectors[path]
        local p, n = lookup(content,name)
        if p then
            return checked(root,p,n)
        end
    end
    return notfound()
end

resolvers.finders   .dirlist = resolve
resolvers.locators  .dirlist = resolvers.locators  .tree
resolvers.hashers   .dirlist = resolvers.hashers   .tree
resolvers.generators.dirlist = resolvers.generators.file
resolvers.openers   .dirlist = resolvers.openers   .file
resolvers.loaders   .dirlist = resolvers.loaders   .file

function resolvers.finders.dirfile(specification)
    local queries = specification.queries
    if queries then
        queries.option = "fileonly"
    else
        specification.queries = { option = "fileonly" }
    end
    return resolve(specification)
end

resolvers.locators  .dirfile = resolvers.locators  .dirlist
resolvers.hashers   .dirfile = resolvers.hashers   .dirlist
resolvers.generators.dirfile = resolvers.generators.dirlist
resolvers.openers   .dirfile = resolvers.openers   .dirlist
resolvers.loaders   .dirfile = resolvers.loaders   .dirlist

-- local locate = collectors[ [[E:\temporary\mb-mp]] ]
-- local locate = collectors( [[\\storage-2\resources\mb-mp]] )

-- print(resolvers.findtexfile("tree://e:/temporary/mb-mp/**/VB_wmf_03_vw_01d_ant.jpg"))
-- print(resolvers.findtexfile("tree://t:/**/tufte.tex"))
-- print(resolvers.findtexfile("dirlist://e:/temporary/mb-mp/**/VB_wmf_03_vw_01d_ant.jpg"))
