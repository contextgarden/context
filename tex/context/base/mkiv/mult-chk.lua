if not modules then modules = { } end modules ['mult-chk'] = {
    version   = 1.001,
    comment   = "companion to mult-chk.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format = string.format
local lpegmatch = lpeg.match
local type = type

local make_settings_to_hash_pattern = utilities.parsers.make_settings_to_hash_pattern
local settings_to_set               = utilities.parsers.settings_to_set
local allocate                      = utilities.storage.allocate

local report_interface = logs.reporter("interface","checking")

local interfaces = interfaces
local implement  = interfaces.implement

interfaces.syntax = allocate {
    test = { keys = table.tohash { "a","b","c","d","e","f","g" } }
}

function interfaces.invalidkey(category,key)
    report_interface("invalid key %a for %a in line %a",key,category,tex.inputlineno)
end

function interfaces.setvalidkeys(category,list)
    local s = interfaces.syntax[category]
    if not s then
        interfaces.syntax[category] = {
            keys = settings_to_set(list)
        }
    else
        s.keys = settings_to_set(list)
    end
end

function interfaces.addvalidkeys(category,list)
    local s = interfaces.syntax[category]
    if not s then
        interfaces.syntax[category] = {
            keys = settings_to_set(list)
        }
    else
        settings_to_set(list,s.keys)
    end
end

implement {
    name      = "setvalidinterfacekeys",
    actions   = interfaces.setvalidkeys,
    arguments = "2 strings"
}

implement {
    name      = "addvalidinterfacekeys",
    actions   = interfaces.addvalidkeys,
    arguments = "2 strings"
}

-- weird code, looks incomplete ... probably an experiment

local prefix, category, keys

local setsomevalue = context.setsomevalue
local invalidkey   = interfaces.invalidkey

local function set(key,value)
    if keys and not keys[key] then
        invalidkey(category,key)
    else
        setsomevalue(prefix,key,value)
    end
end

local pattern = make_settings_to_hash_pattern(set,"tolerant")

function interfaces.getcheckedparameters(k,p,s)
    if s and s ~= "" then
        prefix, category = p, k
        keys = k and k ~= "" and interfaces.syntax[k].keys
        lpegmatch(pattern,s)
    end
end

implement {
    name      = "getcheckedinterfaceparameters",
    actions   = interfaces.getcheckedparameters,
    arguments = "3 strings"
}
