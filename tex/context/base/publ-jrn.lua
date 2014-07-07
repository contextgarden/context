if not modules then modules = { } end modules ['publ-jrn'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- require("char-utf")

-- Abhandlungen aus dem Westfälischen Museum für Naturkunde = Abh. Westfäl. Mus. Nat.kd.
-- Abhandlungen der Naturforschenden Gesellschaft in Zürich = Abh. Nat.forsch. Ges. Zür.
-- Abhandlungen des Naturwissenschaftlichen Vereins zu Bremen = Abh. Nat.wiss. Ver. Bremen

local find = string.find
local P, C, S, Cs, lpegmatch, lpegpatterns = lpeg.P, lpeg.C, lpeg.S, lpeg.Cs, lpeg.match, lpeg.patterns

local lower = characters.lower

local report_journals  = logs.reporter("publications","journals")

local journals         = { }
publications.journals  = journals

local expansions       = { }
local abbreviations    = { }
local nofexpansions    = 0
local nofabbreviations = 0

local valid      = 1 - S([[ ."':;,-]])
local pattern    = Cs((valid^1 + P(1)/"")^1)

local function simplify(name)
    -- we have utf but it doesn't matter much if we lower the bytes
    return name and lower(lpegmatch(pattern,name)) or name
end

local function add(expansion,abbreviation)
    if expansion and abbreviation then
        local se = simplify(expansion)
        local sa = simplify(abbreviation)
        if not expansions[sa] then
            expansions[sa] = expansion
            nofexpansions = nofexpansions + 1
        end
        if not abbreviations[se] then
            abbreviations[se] = abbreviation
            nofabbreviations = nofabbreviations + 1
        end
    end
end

local whitespace = lpegpatterns.whitespace^0
local separator  = whitespace * lpeg.P("=") * whitespace
local endofline  = lpegpatterns.space^0 * (lpegpatterns.newline + P(-1))
local splitter   = whitespace * C((1-separator)^1) * separator * C((1-endofline)^1)
local pattern    = (splitter / add)^0

function journals.load(filename)
    if not filename then
        return
    end-- error
    if file.suffix(filename,"txt") then
        local data = io.loaddata(filename)
        if type(data) ~= "string" then
            return
        elseif find(data,"=") then
            -- expansion = abbreviation
            lpegmatch(pattern,data)
        end
    elseif file.suffix(filename,"lua") then
        local data = table.load(filename)
        if type(data) ~= "table" then
            return
        else
            local de = data.expansions
            local da = data.abbreviations
            if de and da then
                -- { expansions = { a = e }, abbreviations = { e = a } }
                if next(expansions) then
                    table.merge(expansions,de)
                else
                    expansions = de
                end
                if next(abbreviations) then
                    table.merge(abbreviations,da)
                else
                    abbreviations = da
                end
            elseif #data > 0 then
                -- { expansion, abbreviation }, ... }
                for i=1,#data do
                    local d = d[i]
                    add(d[1],d[2])
                end
            else
                -- { expansion = abbreviation, ... }
                for expansion, abbreviation in data do
                    add(expansion,abbreviation)
                end
            end
        end
    end
    report_journals("file %a loaded, %s expansions, %s abbreviations",filename,nofexpansions,nofabbreviations)
end

function journals.save(filename)
    table.save(filename,{ expansions = expansions, abbreviations = abbreviations })
end

function journals.add(expansion,abbreviation)
    add(expansion,abbreviation)
end

function journals.expanded(name)
    local s = simplify(name)
    return expansions[s] or expansions[simplify(abbreviations[s])] or name
end

function journals.abbreviated(name)
    local s = simplify(name)
    return abbreviations[s] or abbreviations[simplify(expansions[s])] or name
end

commands.btxloadjournallist    = journals.load
commands.btxsavejournallist    = journals.save
commands.btxaddjournal         = function(...)  context(journals.add(...)) end
commands.btxexpandedjournal    = function(name) context(journals.expanded(name)) end
commands.btxabbreviatedjournal = function(name) context(journals.abbreviated(name)) end

-- journals.load("e:/tmp/journals.txt")
-- journals.save("e:/tmp/journals.lua")

-- inspect(journals.expanded   ("Z. Ökol. Nat.schutz"))
-- inspect(journals.abbreviated("Z.       Ökol. Nat. schutz"))

typesetters.manipulators.methods.expandedjournal    = journals.expanded
typesetters.manipulators.methods.abbreviatedjournal = journals.abbreviated
