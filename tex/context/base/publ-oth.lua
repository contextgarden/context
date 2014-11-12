if not modules then modules = { } end modules ['publ-oth'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local P, S, C, Ct, Cf, Cg, Cmt, Carg = lpeg.P, lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cf, lpeg.Cg, lpeg.Cmt, lpeg.Carg
local lpegmatch = lpeg.match

local p_endofline = lpeg.patterns.newline

local publications = publications

local loaders      = publications.loaders
local getindex     = publications.getindex

local function addfield(t,k,v,fields)
    k = fields[k]
    if k then
        local tk = t[k]
        if tk then
            t[k] = tk .. " and " .. v
        else
            t[k] = v
        end
    end
    return t
end

local function checkfield(_,_,t,categories,all)
    local tag = t.tag
    if tag then
        local category = t.category
        t.tag = nil
        t.category = categories[category] or category
        all[tag] = t
    end
    return true
end

-- endnotes --

local fields = {
    ["@"] = "tag",
    ["0"] = "category",
    ["A"] = "author",
    ["E"] = "editor",
    ["T"] = "title",
    ["D"] = "year",
    ["I"] = "publisher",
}

local categories = {
    ["Journal Article"] = "article",
}

local entry   = P("%") * Cg(C(1) * (S(" \t")^1) * C((1-p_endofline)^0) * Carg(1)) * p_endofline
local record  = Cf(Ct("") * (entry^1), addfield)
local records = (Cmt(record * Carg(2) * Carg(3), checkfield) * P(1))^1

function publications.endnotes_to_btx(data)
    local all = { }
    lpegmatch(records,data,1,fields,categories,all)
    return all
end

function loaders.endnote(dataset,filename)
    -- we could combine the next into checkfield but let's not create too messy code
    local dataset, fullname = publications.resolvedname(dataset,filename)
    if fullname then
        loaders.lua(dataset,publications.endnotes_to_btx(io.loaddata(fullname) or ""))
    end
end

-- refman --

local entry   = Cg(C((1-lpeg.S(" \t")-p_endofline)^1) * (S(" \t-")^1) * C((1-p_endofline)^0) * Carg(1)) * p_endofline
local record  = Cf(Ct("") * (entry^1), addfield)
local records = (Cmt(record * Carg(2) * Carg(3), checkfield) * P(1))^1

local fields = {
    ["SN"] = "tag",
    ["TY"] = "category",
    ["A1"] = "author",
    ["E1"] = "editor",
    ["T1"] = "title",
    ["Y1"] = "year",
    ["PB"] = "publisher",
}

local categories = {
    ["JOUR"] = "article",
}

function publications.refman_to_btx(data)
    local all = { }
    lpegmatch(records,data,1,fields,categories,all)
    return all
end

function loaders.refman(dataset,filename)
    -- we could combine the next into checkfield but let's not create too messy code
    local dataset, fullname = publications.resolvedname(dataset,filename)
    if fullname then
        loaders.lua(dataset,publications.refman_to_btx(io.loaddata(fullname) or ""))
    end
end

-- test --

-- local endnote = [[
-- %0 Journal Article
-- %T Scientific Visualization, Overviews, Methodologies, and Techniques
-- %A Nielson, Gregory M
-- %A Hagen, Hans
-- %A Müller, Heinrich
-- %@ 0818677776
-- %D 1994
-- %I IEEE Computer Society
--
-- %0 Journal Article
-- %T Scientific Visualization, Overviews, Methodologies, and Techniques
-- %A Nielson, Gregory M
-- %A Hagen, Hans
-- %A Müller, Heinrich
-- %@ 0818677775
-- %D 1994
-- %I IEEE Computer Society
-- ]]
--
-- local refman = [[
-- TY  - JOUR
-- T1  - Scientific Visualization, Overviews, Methodologies, and Techniques
-- A1  - Nielson, Gregory M
-- A1  - Hagen, Hans
-- A1  - Müller, Heinrich
-- SN  - 0818677776
-- Y1  - 1994
-- PB  - IEEE Computer Society
--
-- TY  - JOUR
-- T1  - Scientific Visualization, Overviews, Methodologies, and Techniques
-- A1  - Nielson, Gregory M
-- A1  - Hagen, Hans
-- A1  - Müller, Heinrich
-- SN  - 0818677775
-- Y1  - 1994
-- PB  - IEEE Computer Society
-- ]]
--
-- inspect(publications.endnotes_to_btx(endnote))
-- inspect(publications.refman_to_btx(refman))
