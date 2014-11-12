if not modules then modules = { } end modules ['publ-usr'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, Cs, R, Cc, Carg = lpeg.P, lpeg.Cs, lpeg.R, lpeg.Cc, lpeg.Carg
local lpegmatch = lpeg.match
local settings_to_hash = utilities.parsers.settings_to_hash

local publications = publications
local datasets     = publications.datasets

-- local str = [[
--     \startpublication[k=Berdnikov:TB21-2-129,t=article,a={{Berdnikov},{}},y=2000,n=2257,s=BHHJ00]
--     \artauthor[]{Alexander}[A.]{}{Berdnikov}
--     \artauthor[]{Hans}[H.]{}{Hagen}
--     \artauthor[]{Taco}[T.]{}{Hoekwater}
--     \artauthor[]{Bogus{\l}aw}[B.]{}{Jackowski}
--     \pubyear{2000}
--     \arttitle{{Even more MetaFun with \MP: A request for permission}}
--     \journal{TUGboat}
--     \issn{0896-3207}
--     \volume{21}
--     \issue{2}
--     \pages{129--130}
--     \month{6}
--     \stoppublication
-- ]]

local remapped = {
    artauthor = "author",
    arttitle  = "title",
}

local function register(target,key,a,b,c,d,e)
    key = remapped[key] or key
    if b and d and e then
        local s = nil
        if b ~= "" and b then
            s = s and s .. " " .. b or b
        end
        if d ~= "" and d then
            s = s and s .. " " .. d or d
        end
        if e ~= "" and e then
            s = s and s .. " " .. e or e
        end
        if a ~= "" and a then
            s = s and s .. " " .. a or a
        end
        local value = target[key]
        if s then
            if value then
                target[key] = value .. " and " .. s
            else
                target[key] = s
            end
        else
            if not value then
                target[key] = s
            end
        end
    else
        target[key] = b
    end
end

local leftbrace    = P("{")
local rightbrace   = P("}")
local leftbracket  = P("[")
local rightbracket = P("]")
local backslash    = P("\\")
local letter       = R("az","AZ")

local key          = backslash * Cs(letter^1) * lpeg.patterns.space^0
local mandate      = leftbrace * Cs(lpeg.patterns.balanced) * rightbrace + Cc(false)
local optional     = leftbracket * Cs((1-rightbracket)^0) * rightbracket + Cc(false)
local value        = optional^-1 * mandate^-1 * optional^-1 * mandate^-2

local pattern      = ((Carg(1) * key * value) / register + P(1))^0

function publications.addtexentry(dataset,settings,content)
    local current  = datasets[dataset]
    local settings = settings_to_hash(settings)
    local data = {
        tag      = settings.tag      or settings.k or "no tag",
        category = settings.category or settings.t or "article",
    }
    lpegmatch(pattern,content,1,data) -- can set tag too
    current.userdata[data.tag] = data
    current.luadata[data.tag] = data
    publications.markasupdated(current)
    return data
end

commands.addbtxentry = publications.addtexentry
