if not modules then modules = { } end modules ['publ-usr'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, Cs, R, Cc, C, Carg = lpeg.P, lpeg.Cs, lpeg.R, lpeg.Cc, lpeg.C, lpeg.Carg
local lpegmatch = lpeg.match
local settings_to_hash = utilities.parsers.settings_to_hash

local publications = publications
local datasets     = publications.datasets

local report       = logs.reporter("publications")
local trace        = false  trackers.register("publications",function(v) trace = v end)

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

local lists = {
    author    = true,
    editor    = true,
 -- artauthor = true,
 -- arteditor = true,
}

local function registervalue(target,key,value)
    target[key] = value
end

-- Instead of being generic we just hardcode the old stuff:

local function registerauthor(target,key,juniors,firstnames,initials,vons,surnames)
    local value = target[key]
    target[key]= ((value and value .. " and {") or "{") ..
        vons       .. "},{" ..
        surnames   .. "},{" ..
        juniors    .. "},{" ..
        firstnames .. "},{" ..
        initials   .. "}"
end

local leftbrace    = P("{")
local rightbrace   = P("}")
local leftbracket  = P("[")
local rightbracket = P("]")
local backslash    = P("\\")
local letter       = R("az","AZ")

local skipspaces   = lpeg.patterns.whitespace^0
local key          = Cs(letter^1)
local value        = leftbrace   * Cs(lpeg.patterns.balanced) * rightbrace
local optional     = leftbracket * Cs((1-rightbracket)^0)     * rightbracket

local authorkey    = (P("artauthor") + P("author")) / "author"
                   + (P("arteditor") + P("editor")) / "editor"
local authorvalue  = (optional + Cc("{}")) * skipspaces -- [juniors]
                   * (value    + Cc("{}")) * skipspaces -- {firstnames}
                   * (optional + Cc("{}")) * skipspaces -- [initials]
                   * (value    + Cc("{}")) * skipspaces -- {vons}
                   * (value    + Cc("{}")) * skipspaces -- {surnames}

local keyvalue     = Carg(1) * authorkey * skipspaces * authorvalue / registerauthor
                   + Carg(1) * key       * skipspaces * value       / registervalue

local pattern      = (backslash * keyvalue + P(1))^0

local function addtexentry(dataset,settings,content)
    local current  = datasets[dataset]
    local settings = settings_to_hash(settings)
    local data = {
        tag      = settings.tag      or settings.k or "no tag",
        category = settings.category or settings.t or "article",
    }
    lpegmatch(pattern,content,1,data) -- can set tag too
    local tag   = data.tag
    local index = publications.getindex(dataset,current.luadata,tag)
    current.ordered[index] = data
    current.luadata[tag]   = data
    current.userdata[tag]  = data
    current.details[tag]   = nil
    return data
end

local pattern = ( Carg(1)
      * P("\\startpublication")
      * skipspaces
      * optional
      * C((1 - P("\\stoppublication"))^1)
      * P("\\stoppublication") / addtexentry
      + P("%") * (1-lpeg.patterns.newline)^0
      + P(1)
)^0

function publications.loaders.bbl(dataset,filename)
    local dataset, fullname = publications.resolvedname(dataset,filename)
    if not fullname then
        return
    end
    local data = io.loaddata(filename) or ""
    if data == "" then
        report("empty file %a, nothing loaded",fullname)
        return
    end
    if trace then
        report("loading file %a",fullname)
    end
    lpegmatch(pattern,data,1,dataset)
end

publications.addtexentry = addtexentry
commands.addbtxentry     = addtexentry
