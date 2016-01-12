if not modules then modules = { } end modules ['luat-sta'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this code is used in the updater

local gmatch, match = string.gmatch, string.match
local type = type

states          = states or { }
local states    = states

states.data     = states.data or { }
local data      = states.data

states.hash     = states.hash or { }
local hash      = states.hash

states.tag      = states.tag      or ""
states.filename = states.filename or ""

function states.save(filename,tag)
    tag = tag or states.tag
    filename = file.addsuffix(filename or states.filename,'lus')
    io.savedata(filename,
        "-- generator : luat-sta.lua\n" ..
        "-- state tag : " .. tag .. "\n\n" ..
        table.serialize(data[tag or states.tag] or {},true)
    )
end

function states.load(filename,tag)
    states.filename = filename
    states.tag = tag or "whatever"
    states.filename = file.addsuffix(states.filename,'lus')
    data[states.tag], hash[states.tag] = (io.exists(filename) and dofile(filename)) or { }, { }
end

local function set_by_tag(tag,key,value,default,persistent)
    local d, h = data[tag], hash[tag]
    if d then
        if type(d) == "table" then
            local dkey, hkey = key, key
            local pre, post = match(key,"(.+)%.([^%.]+)$")
            if pre and post then
                for k in gmatch(pre,"[^%.]+") do
                    local dk = d[k]
                    if not dk then
                        dk = { }
                        d[k] = dk
                    elseif type(dk) == "string" then
                        -- invalid table, unable to upgrade structure
                        -- hope for the best or delete the state file
                        break
                    end
                    d = dk
                end
                dkey, hkey = post, key
            end
            if value == nil then
                value = default
            elseif value == false then
                -- special case
            elseif persistent then
                value = value or d[dkey] or default
            else
                value = value or default
            end
            d[dkey], h[hkey] = value, value
        elseif type(d) == "string" then
            -- weird
            data[tag], hash[tag] = value, value
        end
    end
end

local function get_by_tag(tag,key,default)
    local h = hash[tag]
    if h and h[key] then
        return h[key]
    else
        local d = data[tag]
        if d then
            for k in gmatch(key,"[^%.]+") do
                local dk = d[k]
                if dk ~= nil then
                    d = dk
                else
                    return default
                end
            end
            if d == false then
                return false
            else
                return d or default
            end
        end
    end
end

states.set_by_tag = set_by_tag
states.get_by_tag = get_by_tag

function states.set(key,value,default,persistent)
    set_by_tag(states.tag,key,value,default,persistent)
end

function states.get(key,default)
    return get_by_tag(states.tag,key,default)
end

--~ data.update = {
--~ 	["version"] = {
--~ 		["major"] = 0,
--~ 		["minor"] = 1,
--~ 	},
--~ 	["rsync"] = {
--~ 		["server"]     = "contextgarden.net",
--~ 		["module"]     = "minimals",
--~ 		["repository"] = "current",
--~ 		["flags"]      = "-rpztlv --stats",
--~ 	},
--~ 	["tasks"] = {
--~ 		["update"] = true,
--~ 		["make"]   = true,
--~         ["delete"] = false,
--~ 	},
--~ 	["platform"] = {
--~ 		["host"]  = true,
--~ 		["other"] = {
--~ 			["mswin"]     = false,
--~ 			["linux"]     = false,
--~ 			["linux-64"]  = false,
--~ 			["osx-intel"] = false,
--~ 			["osx-ppc"]   = false,
--~ 			["sun"]       = false,
--~ 		},
--~ 	},
--~ 	["context"] = {
--~ 		["available"] = {"current", "beta", "alpha", "experimental"},
--~ 		["selected"]  = "current",
--~ 	},
--~ 	["formats"] = {
--~ 		["cont-en"] = true,
--~ 		["cont-nl"] = true,
--~ 		["cont-de"] = false,
--~ 		["cont-cz"] = false,
--~ 		["cont-fr"] = false,
--~ 		["cont-ro"] = false,
--~ 	},
--~ 	["engine"] = {
--~ 		["pdftex"] = {
--~ 			["install"] = true,
--~ 			["formats"] = {
--~ 				["pdftex"] = true,
--~ 			},
--~ 		},
--~ 		["luatex"] = {
--~ 			["install"] = true,
--~ 			["formats"] = {
--~ 			},
--~ 		},
--~ 		["xetex"] = {
--~ 			["install"] = true,
--~ 			["formats"] = {
--~ 				["xetex"] = false,
--~ 			},
--~ 		},
--~ 		["metapost"] = {
--~ 			["install"] = true,
--~ 			["formats"] = {
--~ 				["mpost"] = true,
--~ 				["metafun"] = true,
--~ 			},
--~ 		},
--~ 	},
--~ 	["fonts"] = {
--~ 	},
--~ 	["doc"] = {
--~ 	},
--~ 	["modules"] = {
--~ 		["f-urwgaramond"] = false,
--~ 		["f-urwgothic"] = false,
--~ 		["t-bnf"] = false,
--~ 		["t-chromato"] = false,
--~ 		["t-cmscbf"] = false,
--~ 		["t-cmttbf"] = false,
--~ 		["t-construction-plan"] = false,
--~ 		["t-degrade"] = false,
--~ 		["t-french"] = false,
--~ 		["t-lettrine"] = false,
--~ 		["t-lilypond"] = false,
--~ 		["t-mathsets"] = false,
--~ 		["t-tikz"] = false,
--~ 		["t-typearea"] = false,
--~ 		["t-vim"] = false,
--~ 	},
--~ }

--~ states.save("teststate", "update")
--~ states.load("teststate", "update")

--~ print(states.get_by_tag("update","rsync.server","unknown"))
--~ states.set_by_tag("update","rsync.server","oeps")
--~ print(states.get_by_tag("update","rsync.server","unknown"))
--~ states.save("teststate", "update")
--~ states.load("teststate", "update")
--~ print(states.get_by_tag("update","rsync.server","unknown"))
