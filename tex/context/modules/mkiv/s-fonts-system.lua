if not modules then modules = { } end modules ['s-fonts-system'] = {
    version   = 1.001,
    comment   = "companion to s-fonts-system.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- ["zapfinoforteltpro"]={
--  ["designsize"]=0,
--  ["filename"]="zapfinoforteltpro.otf",
--  ["fontname"]="zapfinoforteltpro",
--  ["fontweight"]="regular",
--  ["family"]="zapfinoforteltpro",
--  ["subfamily"]="regular",
--  ["familyname"]="zapfinoforteltpro",
--  ["subfamilyname"]="regular",
--  ["format"]="otf",
--  ["fullname"]="zapfinoforteltpro",
--  ["maxsize"]=0,
--  ["minsize"]=0,
--  ["modification"]=1105543074,
--  ["rawname"]="ZapfinoForteLTPro",
--  ["style"]="normal",
--  ["variant"]="normal",
--  ["weight"]="normal",
--  ["width"]="normal",
-- }

moduledata.fonts        = moduledata.fonts        or { }
moduledata.fonts.system = moduledata.fonts.system or { }

local context = context
local NC, NR, HL = context.NC, context.NR, context.HL
local ctx_bold = context.bold
local ctx_verbatim = context.verbatim
local lpegmatch = lpeg.match
local sortedhash = table.sortedhash
local formatters = string.formatters
local concat = table.concat
local lower = string.lower
local gsub = string.gsub
local find = string.find

local function allfiles(specification)
    local pattern = lower(specification.pattern or "")
    local list    = fonts.names.list(pattern,false,true)
    if list then
        local files = { }
        for k, v in next, list do
            files[file.basename(string.lower(v.filename))] = v
        end
        return files
    end
end

function moduledata.fonts.system.showinstalled(specification)
    specification = interfaces.checkedspecification(specification)
    local files = allfiles(specification)
    if files then
        context.starttabulate { "|Tl|Tl|Tl|Tl|Tl|Tl|" }
            HL()
            NC() ctx_bold("filename")
            NC() ctx_bold("fontname")
            NC() ctx_bold("subfamily")
            NC() ctx_bold("variant")
            NC() ctx_bold("weight")
            NC() ctx_bold("width")
            NC() NR()
            HL()
            for filename, data in table.sortedpairs(files) do
                NC() context(filename)
                NC() context(data.fontname)
                NC() context(data.subfamily)
                NC() context(data.variant)
                NC() context(data.weight)
                NC() context(data.width)
                NC() NR()
            end
        context.stoptabulate()
    end
end

function moduledata.fonts.system.cacheinstalled(specification)
    specification = interfaces.checkedspecification(specification)
    local files = allfiles(specification)
    if files then
        local threshold = tonumber(specification.threshold)
        local suffixes  = specification.suffixes
        if suffixes then
            suffixes = utilities.parsers.settings_to_set(suffixes)
        else
            suffixes = { otf = true, ttf = true }
        end
        for filename, data in table.sortedpairs(files) do
            if string.find(filename," ") then
                -- skip this one
            elseif suffixes[file.suffix(filename)] then
                local fullname = resolvers.findfile(filename)
                context.start()
                context.type(fullname)
                context.par()
                if threshold and file.size(fullname) > threshold then
                    logs.report("fonts","ignoring : %s",fullname)
                else
                    logs.report("fonts","caching  : %s",fullname)
                    context.definedfont { filename }
                end
                context.stop()
            end
        end
    end
end

local splitter = lpeg.splitat(lpeg.S("._"),true)

local method = 4

function moduledata.fonts.system.showinstalledglyphnames(specification)
    specification = interfaces.checkedspecification(specification)
    local paths   = caches.getreadablepaths()
    local files   = { }
    local names   = table.setmetatableindex("table")
    local f_u     = formatters["%04X"]
    for i=1,#paths do
        local list = dir.glob(paths[i].."/fonts/o*/**." .. utilities.lua.suffixes.tmc)
        for i=1,#list do
            files[list[i]] = true
        end
    end
    for filename in table.sortedhash(files) do
        local fontname = file.nameonly(filename)
        logs.report("system","fontfile: %s",fontname)
        local data = table.load(filename)
        if data then
            if method == 1 then
                local unicodes = data.resources.unicodes
                if unicodes then
                    for n, u in sortedhash(unicodes) do
                        if u >= 0xF0000 or (u >= 0xE000 and u <= 0xF8FF) then
                            -- skip
                        else
                             local f = lpegmatch(splitter,n) or n
                             if #f > 0 then
                                 local t = names[f]
                                 t[u] = (t[u] or 0) + 1
                             end
                        end
                    end
                end
            elseif method == 2 then
                local unicodes = data.resources.unicodes
                if unicodes then
                    for n, u in sortedhash(unicodes) do
                        if u >= 0xF0000 or (u >= 0xE000 and u <= 0xF8FF) then
                            -- skip
                        else
                            local t = names[n]
                            t[u] = (t[u] or 0) + 1
                        end
                    end
                end
            elseif method == 3 then
                local descriptions = data.descriptions
                if descriptions then
                    for u, d in sortedhash(descriptions) do
                        local n = d.name
                        local u = d.unicode
                        if n and u then
                            if type(u) == "table" then
                                local t = { }
                                for i=1,#u do
                                    t[i] = f_u(u[i])
                                end
                                u = concat(t," ")
                            end
                            local t = names[n]
                            t[u] = (t[u] or 0) + 1
                        end
                    end
                end
            elseif method == 4 then
                local descriptions = data.descriptions
                if descriptions then
                    for u, d in sortedhash(descriptions) do
                        local n = d.name
                        local u = d.unicode
                        if n and not u and not find(n,"^%.") then
                            local n = names[n]
                            n[#n+1] = fontname
                        end
                    end
                end
            else
                -- nothing
            end
        end
    end
 -- names[".notdef"] = nil
 -- names[".null"]   = nil
    if method == 4 then
        if next(names) then
            context.starttabulate { "|l|pl|" }
            local f_u = formatters["%04X~(%i)"]
            local f_s = formatters["%s~(%i)"]
            for k, v in sortedhash(names) do
                NC() ctx_verbatim(k)
                NC() context("% t",v)
                NC() NR()
            end
            context.stoptabulate()
        end
        table.save("s-fonts-system-glyph-unknowns.lua",names)
    else
        if next(names) then
            context.starttabulate { "|l|pl|" }
            local f_u = formatters["%04X~(%i)"]
            local f_s = formatters["%s~(%i)"]
            for k, v in sortedhash(names) do
                local t = { }
                for k, v in sortedhash(v) do
                    if type(k) == "string" then
                        t[#t+1] = f_s(k,v)
                    else
                        t[#t+1] = f_u(k,v)
                    end
                end
                NC() ctx_verbatim(k)
                NC() context("%, t",t)
                NC() NR()
            end
            context.stoptabulate()
        end
        table.save("s-fonts-system-glyph-names.lua",names)
    end
end

-- -- --

-- local skip = {
--     "adobeblank",
--     "veramo",
--     "unitedstates",
--     "tirek",
--     "svbasicmanual",
--     "sahel",
--     "prsprorg",
--     "piratdia",
--     "notoserifthai",
--     "coelacanthsubhdheavy",
-- }

-- local function bad(name)
--     name = lower(name)
--     for i=1,#skip do
--         if find(name,skip[i]) then
--             return true
--         end
--     end
-- end

-- function moduledata.fonts.system.showprivateglyphnames(specification)
--     specification = interfaces.checkedspecification(specification)
--     local paths   = caches.getreadablepaths()
--     local files   = { }
--     local names   = table.setmetatableindex("table")
--     local f_u     = formatters["%04X"]
--     for i=1,#paths do
--         local list = dir.glob(paths[i].."/fonts/o*/**.tmc")
--         for i=1,#list do
--             files[list[i]] = true
--         end
--     end
--     for filename in table.sortedhash(files) do
--         logs.report("system","fontfile: %s",file.nameonly(filename))
--         local data = table.load(filename)
--         if data and data.format == "truetype" or data.format == "opentype" then
--             local basename  = file.basename(data.resources.filename)
--             local cleanname = gsub(basename," ","")
--             if not bad(cleanname) then
--                 local descriptions = data.descriptions
--                 if descriptions then
--                     local done = 0
--                     for u, d in sortedhash(descriptions) do
--                         local dn = d.name
--                         local du = d.unicode
--                         if dn and du and (u >= 0xF0000 or (u >= 0xE000 and u <= 0xF8FF)) and not find(dn,"notdef") then
--                             if type(du) == "table" then
--                                 local t = { }
--                                 for i=1,#du do
--                                     t[i] = f_u(du[i])
--                                 end
--                                 du = concat(t," ")
--                             end
--                             if done == 0 then
--                                 logs.report("system","basename: %s",basename)
--                                 context.starttitle { title = basename }
--                                 context.start()
--                                 context.definefont( { "tempfont" }, { "file:" .. cleanname })
--                                 context.starttabulate { "|T||T|T|" }
--                             end
--                             NC() context("%U",u)
--                             NC() context.tempfont() context.char(u) -- could be getglyph
--                             NC() ctx_verbatim(dn)
--                             NC() context(du)
--                             NC() NR()
--                             done = done + 1
--                         end
--                     end
--                     if done > 0 then
--                         logs.report("system","privates: %i",done)
--                         context.stoptabulate()
--                         context.stop()
--                         context.stoptitle()
--                     end
--                 end
--             end
--         end
--     end
-- end

