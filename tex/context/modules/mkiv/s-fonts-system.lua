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

local lower = string.lower

local context = context
local NC, NR, HL = context.NC, context.NR, context.HL
local bold = context.bold

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
            NC() bold("filename")
            NC() bold("fontname")
            NC() bold("subfamily")
            NC() bold("variant")
            NC() bold("weight")
            NC() bold("width")
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
        for filename, data in table.sortedpairs(files) do
            if string.find(filename," ") then
                -- skip this one
            else
                local s = file.suffix(filename)
                if s == "otf" or s == "ttf" then
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
end
