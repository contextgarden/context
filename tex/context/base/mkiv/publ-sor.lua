if not modules then modules = { } end modules ['publ-sor'] = {
    version   = 1.001,
    comment   = "this module part of publication support",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- if needed we can optimize this one: chekc if it's detail or something else
-- and use direct access, but in practice it's fast enough

local type          = type
local concat        = table.concat
local formatters    = string.formatters
local compare       = sorters.comparers.basic -- (a,b)
local sort          = table.sort

local toarray       = utilities.parsers.settings_to_array
local utfchar       = utf.char

local publications  = publications
local writers       = publications.writers

local variables     = interfaces.variables
local v_short       = variables.short
local v_default     = variables.default
local v_reference   = variables.reference
local v_dataset     = variables.dataset
local v_list        = variables.list
local v_index       = variables.index
local v_cite        = variables.cite
local v_used        = variables.used

local report        = logs.reporter("publications","sorters")

local trace_sorters = false  trackers.register("publications.sorters",function(v) trace_sorters = v end)

-- authors(s) | year | journal | title | pages

local template = [[
local type, tostring = type, tostring

local writers  = publications.writers
local datasets = publications.datasets
local getter   = publications.getfaster -- (current,data,details,field,categories,types)
local strip    = sorters.strip
local splitter = sorters.splitters.utf

local function newsplitter(splitter)
    return table.setmetatableindex({},function(t,k) -- could be done in the sorter but seldom that many shared
        local v = splitter(k,true)                  -- in other cases
        t[k] = v
        return v
    end)
end

return function(dataset,list,method) -- indexer
    local current       = datasets[dataset]
    local luadata       = current.luadata
    local details       = current.details
    local specification = publications.currentspecification
    local categories    = specification.categories
    local types         = specification.types
    local splitted      = newsplitter(splitter) -- saves mem
    local snippets      = { } -- saves mem
    local result        = { }

%helpers%

    for i=1,#list do
        -- either { tag, tag, ... } or { { tag, index }, { tag, index } }
        local li    = list[i]
        local tag   = type(li) == "string" and li or li[1]
        local index = tostring(i)
        local entry = luadata[tag]
        if entry then
            -- maybe optional: if entry.key then push the keygetter
            -- in slot 1 and ignore (e.g. author)
            local detail  = details[tag]
            result[i] = {
                index  = i,
                split  = {

%getters%

                },
            }
        else
            result[i] = {
                index  = i,
                split  = {

%unknowns%

                },
            }
        end
    end
    return result
end
]]

local f_getter = formatters["splitted[strip(getter(current,entry,detail,%q,categories,types) or %q)], -- %s"]
local f_writer = formatters["splitted[strip(writer_%s(getter(current,entry,detail,%q,categories,types) or %q,snippets))], -- %s"]
local f_helper = formatters["local writer_%s = writers[%q] -- %s: %s"]
local f_value  = formatters["splitted[%q], -- %s"]
local s_index  = "splitted[index], -- the order in the list, always added"

-- there is no need to cache this in specification

local sharedmethods      = { }
publications.sortmethods = sharedmethods

local function sortsequence(dataset,list,sorttype)

    if not list or #list == 0 then
        return
    end

    local specification = publications.currentspecification
    local types         = specification.types
    local sortmethods   = specification.sortmethods
    local method        = sortmethods and sortmethods[sorttype] or sharedmethods[sorttype]
    local sequence      = method and method.sequence

    local s_default     = "<before end>"
    local s_unknown     = "<at the end>"

    local c_default     = utfchar(0xFFFE)
    local c_unknown     = utfchar(0xFFFF)

    if not sequence and type(sorttype) == "string" then
        local list = toarray(sorttype)
        if #list > 0 then
            local indexdone = false
            sequence = { }
            for i=1,#list do
                local entry   = toarray(list[i])
                local field   = entry[1]
                local default = entry[2]
                local unknown = entry[3] or default
                sequence[i] = {
                    field   = field,
                    default = default == s_default and c_default or default or c_default,
                    unknown = unknown == s_unknown and c_unknown or unknown or c_unknown,
                }
                if field == "index" then
                    indexdone = true
                end
            end
            if not indexdone then
                sequence[#sequence+1] = {
                    field   = "index",
                    default = 0,
                    unknown = 0,
                }
            end
        end
        if trace_sorters then
            report("creating sequence from method %a",sorttype)
        end
    end

    if sequence then

        local getters  = { }
        local unknowns = { }
        local helpers  = { }

        if trace_sorters then
            report("initializing method %a",sorttype)
        end

        for i=1,#sequence do
            local step      = sequence[i]
            local field     = step.field or "?"
            local default   = step.default or c_default
            local unknown   = step.unknown or c_unknown
            local fldtype   = types[field]
            local fldwriter = step.writer or fldtype
            local writer    = fldwriter and writers[fldwriter]

            if trace_sorters then
                report("% 3i : field %a, type %a, default %a, unknown %a",i,field,fldtype,
                    default == c_default and s_default or default,
                    unknown == c_unknown and s_unknown or unknown
                )
            end

            if writer then
                local h = #helpers + 1
                getters[i] = f_writer(h,field,default,field)
                helpers[h] = f_helper(h,fldwriter,field,fldtype)
            else
                getters[i] = f_getter(field,default,field)
            end
            unknowns[i] = f_value(unknown,field)
        end

        unknowns[#unknowns+1] = s_index
        getters [#getters +1] = s_index

        local code = utilities.templates.replace(template, {
            helpers  = concat(helpers, "\n"),
            getters  = concat(getters, "\n"),
            unknowns = concat(unknowns,"\n"),
        })

     -- print(code)

        local action, error = loadstring(code)
        if type(action) == "function" then
            action = action()
        else
            report("error when compiling sort method %a: %s",sorttype,error or "unknown")
        end
        if type(action) == "function" then
            local valid = action(dataset,list,method)
            if valid and #valid > 0 then
-- sorters.setlanguage(options.language,options.method)
                sorters.sort(valid,compare)
                return valid
            else
                report("error when applying sort method %a",sorttype)
            end
        else
            report("error in sort method %a",sorttype)
        end
    else
        report("invalid sort method %a",sorttype)
    end

end

-- tag | listindex | reference | userdata | dataindex

-- short      : short + tag index
-- dataset    : index + tag
-- list       : list + index
-- reference  : tag + index
-- used       : reference + dataset
-- authoryear : complex sort

local sorters = { }

sorters[v_short] = function(dataset,rendering,list) -- should we store it
    local shorts = rendering.shorts
    local function compare(a,b)
        if a and b then
            local taga = a[1]
            local tagb = b[1]
            if taga and tagb then
                local shorta = shorts[taga]
                local shortb = shorts[tagb]
                if shorta and shortb then
                    -- assumes ascii shorts ... no utf yet
                    return shorta < shortb
                end
                -- fall back on tag order
                return taga < tagb
            end
            -- fall back on dataset order
            local indexa = a[5]
            local indexb = b[5]
            if indexa and indexb then
                return indexa < indexb
            end
        end
        return false
    end
    sort(list,compare)
end

sorters[v_dataset] = function(dataset,rendering,list) -- dataset index
    local function compare(a,b)
        if a and b then
            local indexa = a[5]
            local indexb = b[5]
            if indexa and indexb then
                return indexa < indexb
            end
            local taga = a[1]
            local tagb = b[1]
            if taga and tagb then
                return taga < tagb
            end
        end
        return false
    end
    sort(list,compare)
end

sorters[v_list] = function(dataset,rendering,list) -- list index (normally redundant)
    local function compare(a,b)
        if a and b then
            local lista = a[2]
            local listb = b[2]
            if lista and listb then
                return lista < listb
            end
            local indexa = a[5]
            local indexb = b[5]
            if indexa and indexb then
                return indexa < indexb
            end
        end
        return false
    end
    sort(list,compare)
end

sorters[v_reference] = function(dataset,rendering,list) -- tag
    local function compare(a,b)
        if a and b then
            local taga = a[1]
            local tagb = b[1]
            if taga and tagb then
                return taga < tagb
            end
            local indexa = a[5]
            local indexb = b[5]
            if indexa and indexb then
                return indexa < indexb
            end
        end
        return false
    end
    sort(list,compare)
end

sorters[v_used] = function(dataset,rendering,list) -- tag
    local function compare(a,b)
        if a and b then
            local referencea = a[2]
            local referenceb = b[2]
            if referencea and referenceb then
                return referencea < referenceb
            end
            local indexa = a[5]
            local indexb = b[5]
            if indexa and indexb then
                return indexa < indexb
            end
        end
        return false
    end
    sort(list,compare)
end

sorters[v_default] = sorters[v_list]
sorters[""]        = sorters[v_list]
sorters[v_cite]    = sorters[v_list]
sorters[v_index]   = sorters[v_dataset]

local function anything(dataset,rendering,list,sorttype)
    local valid = sortsequence(dataset,list,sorttype) -- field order
    if valid and #valid > 0 then
        -- hm, we have a complication here because a sortsequence doesn't know if there's a field
        -- so there is no real catch possible here .., anyway, we add a index as last entry when no
        -- one is set so that should be good enough (needs testing)
        for i=1,#valid do
            local v = valid[i]
            valid[i] = list[v.index]
        end
        return valid
    end
end

table.setmetatableindex(sorters,function(t,k) return anything end)

publications.lists.sorters = sorters

-- publications.sortmethods.key = {
--     sequence = {
--         { field = "key",   default = "", unknown = "" },
--         { field = "index", default = "", unknown = "" },
--     },
-- }
