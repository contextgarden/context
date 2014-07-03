if not modules then modules = { } end modules ['data-tre'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- \input tree://oeps1/**/oeps.tex

local find, gsub, lower = string.find, string.gsub, string.lower
local basename, dirname, joinname = file.basename, file.dirname, file   .join
local globdir, isdir = dir.glob, lfs.isdir

local trace_locating = false  trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_trees   = logs.reporter("resolvers","trees")

local resolvers      = resolvers
local resolveprefix  = resolvers.resolve
local notfound       = resolvers.finders.notfound

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
    if trace_locating then
        report_trees("analysing %a",name)
    end
    resolvers.methodhandler("hashers",name)

    resolvers.generators.file(specification)
end

-- This is a variation on tree lookups but this time we do cache in the given
-- root. We use a similar hasher as the resolvers because we have to deal with
-- for instance trees with 50K xml files plus a similar amount of resources to
-- deal and we don't want too much overhead.

local collectors = { }

-- table.setmetatableindex(collectors, function(t,k)
--     local rootname = gsub(k,"[/%*]+$","")
--     local dataname = joinname(rootname,"dirlist")
--     local content  = caches.loadcontent(dataname,"files",dataname)
--     local lookup   = resolvers.get_from_content
--     if not content then
--         content  = resolvers.scanfiles(rootname)
--         caches.savecontent(dataname,"files",content,dataname)
--     end
--     local v = function(filename)
--         local path, name = lookup(content,filename)
--         if not path then
--             return filename
--         elseif type(path) == "table" then
--             -- maybe a warning that the first name is taken
--             path = path[1]
--         end
--         return joinname(rootname,path,name)
--     end
--     t[k] = v
--     return v
-- end)

-- function resolvers.finders.dirlist(specification) -- can be called directly too
--     local spec = specification.filename
--     if spec ~= "" then
--         local path, name = dirname(spec), basename(spec)
--         return path and collectors[path](name) or notfound()
--     end
--     return notfound()
-- end

table.setmetatableindex(collectors, function(t,k)
    local rootname = gsub(k,"[/%*]+$","")
    local dataname = joinname(rootname,"dirlist")
    local content  = caches.loadcontent(dataname,"files",dataname)
    local lookup   = resolvers.get_from_content
    if not content then
        content  = resolvers.scanfiles(rootname)
        caches.savecontent(dataname,"files",content,dataname)
    end
    local v = function(filename)
        local path, name = lookup(content,filename)
        if not path then
            return filename
        elseif type(path) == "table" then
            -- maybe a warning that the first name is taken
            path = path[1]
        end
        return joinname(rootname,path,name)
    end
    t[k] = v
    return v
end)

function resolvers.finders.dirlist(specification) -- can be called directly too
    local spec = specification.filename
    if spec ~= "" then
        local path, name = dirname(spec), basename(spec)
        return path and collectors[path](name) or notfound()
    end
    return notfound()
end

resolvers.locators  .dirlist = resolvers.locators  .tree
resolvers.hashers   .dirlist = resolvers.hashers   .tree
resolvers.generators.dirlist = resolvers.generators.file
resolvers.openers   .dirlist = resolvers.openers   .file
resolvers.loaders   .dirlist = resolvers.loaders   .file

-- local locate = collectors[ [[E:\temporary\mb-mp]] ]
-- local locate = collectors( [[\\storage-2\resources\mb-mp]] )

-- print(resolvers.findtexfile("tree://e:/temporary/mb-mp/**/VB_wmf_03_vw_01d_ant.jpg"))
-- print(resolvers.findtexfile("tree://t:/**/tufte.tex"))
-- print(resolvers.findtexfile("dirlist://e:/temporary/mb-mp/**/VB_wmf_03_vw_01d_ant.jpg"))
