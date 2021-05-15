if not modules then modules = { } end modules ['lang-tra'] = {
    version   = 1.001,
    comment   = "companion to lang-tra.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utfbyte, utfsplit = utf.byte, utf.split

local nuts                = nodes.nuts

local nextchar            = nuts.traversers.char

local getattr             = nuts.getattr
local setchar             = nuts.setchar

local insertbefore        = nuts.insertbefore
local copy_node           = nuts.copy

local texsetattribute     = tex.setattribute

local transliteration     = { }
languages.transliteration = transliteration

local a_transliteration   = attributes.private("transliteration")
local unsetvalue          = attributes.unsetvalue

local lastmapping         = 0
local loadedmappings      = { }

function transliteration.define(name,vector)
    local m = loadedmappings[vector]
    if m == nil then
        lastmapping = lastmapping + 1
        local data = require("lang-imp-" .. name)
        if data then
            local transliterations = data.transliterations
            if transliterations then
                for name, d in next, transliterations do
                    local vector = d.vector
                    if not vector then
                        local mapping = d.mapping
                        if mapping then
                            vector = { }
                            for k, v in next, mapping do
                                local vv = utfsplit(v)
                                for i=1,#vv do
                                    vv[i] = utfbyte(vv[i])
                                end
                                vector[utfbyte(k)] = vv
                            end
                            d.vector = vector
                        end
                    end
                    d.attribute = lastmapping
                    loadedmappings[name] = d
                    loadedmappings[lastmapping] = d
                end
            end
        end
        m = loadedmappings[vector] or false
    end
end

local enabled = false

function transliteration.set(vector)
    if not enabled then
        nodes.tasks.enableaction("processors", "languages.transliteration.handler")
        enabled = true
    end
    local m = loadedmappings[vector]
    texsetattribute(a_transliteration,m and m.attribute or unsetvalue)
end

function transliteration.handler(head)
    local aprev  = nil
    local vector = nil
    for current, char in nextchar, head do
        local a = getattr(current,a_transliteration)
        if a then
            if a ~= aprev then
                aprev = a
                vector = loadedmappings[a]
                if vector then
                    vector = vector.vector
                end
            end
            if vector then
                local t = vector[char]
                if t then
                    local n = #t
                    setchar(current,t[n])
                    local p = current
                    if n > 1 then
                        for i = n-1,1,-1 do
                            local g = copy_node(current)
                            setchar(g,t[i])
                            head, p = insertbefore(head, p, g)
                        end
                    end
                end
            end
        end
    end
    return head
end

interfaces.implement {
    name      = "settransliteration",
    arguments = "string",
    actions   = transliteration.set,
}

interfaces.implement {
    name      = "definedtransliteration",
    arguments = "2 strings",
    actions   = transliteration.define,
}

nodes.tasks.prependaction("processors", "normalizers", "languages.transliteration.handler", nil, "nut", "disabled" )

