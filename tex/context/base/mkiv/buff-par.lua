if not modules then modules = { } end modules ['buff-par'] = {
    version   = 1.001,
    comment   = "companion to buff-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber = tonumber
local insert, remove, find, gmatch, match = table.insert, table.remove, string.find, string.gmatch, string.match
local fullstrip, formatters = string.fullstrip, string.formatters

local trace_parallel  = false  trackers.register("buffers.parallel", function(v) trace_parallel = v end)

local report_parallel = logs.reporter("buffers","parallel")

local variables         = interfaces.variables
local v_all             = variables.all

local parallel          = buffers.parallel or { }
buffers.parallel        = parallel

local settings_to_array = utilities.parsers.settings_to_array

local context           = context
local implement         = interfaces.implement

local data              = { }

function parallel.define(category,tags)
    local tags = settings_to_array(tags)
    local entries = { }
    data[category] = {
        tags    = tags,
        entries = entries,
    }
    for i=1,#tags do
        entries[tags[i]] = {
            lines  = { },
            number = 0,
        }
    end
end

function parallel.reset(category,tags)
    if not tags or tags == "" or tags == v_all then
        tags = table.keys(entries)
    else
        tags = settings_to_array(tags)
    end
    for i=1,#tags do
        entries[tags[i]] = {
            lines  = { },
            number = 0,
        }
    end
end

function parallel.next(category)
    local dc = data[category]
    local tags = dc.tags
    local entries = dc.entries
    for i=1,#tags do
        insert(entries[tags[i]].lines, { })
    end
end

function parallel.save(category,tag,content,frombuffer)
    if frombuffer then
        content = buffers.raw(content)
    end
    local dc = data[category]
    if not dc then
        report_parallel("unknown category %a",category)
        return
    end
    local entries = dc.entries[tag]
    if not entries then
        report_parallel("unknown entry %a",tag)
        return
    end
    local lines = entries.lines
    if not lines then
        return
    end
    local line = lines[#lines]
    if not line then
        return
    end
    -- maybe no strip
    -- use lpeg
    if find(content,"%s*%[") then
        local done = false

        local function flush(content,label)
            if done then
                line = { }
                insert(lines,line)
            else
                done = true
            end
            line.content = fullstrip(content)
            line.label   = label
        end


        local leading, rest = match(content,"^%s*([^%[]+)(.*)$")
        if leading then
            if leading ~= "" then
                flush(leading)
            end
            content = rest
        end
        for label, content in gmatch(content,"%s*%[(.-)%]%s*([^%[]+)") do
            if trace_parallel and label ~= "" then
                report_parallel("reference found of category %a, tag %a, label %a",category,tag,label)
            end
            flush(content,label)
        end
    else
        line.content = fullstrip(content)
        line.label = ""
    end
    -- print("[["..line.content.."]]")
end

function parallel.hassomecontent(category,tags)
    local dc = data[category]
    if not dc then
        return false
    end
    local entries = dc.entries
    if not tags or tags == "" or tags == v_all then
        tags = table.keys(entries)
    else
        tags = utilities.parsers.settings_to_array(tags)
    end
    for t=1,#tags do
        local tag = tags[t]
        local lines = entries[tag].lines
        for i=1,#lines do
            local content = lines[i].content
            if content and content ~= "" then
                return true
            end
        end
    end
    return false
end

local ctx_doflushparallel = context.doflushparallel
local f_content           = formatters["\\input{%s}"]
local save_byscheme       = resolvers.savers.byscheme

function parallel.place(category,tags,options)
    local dc = data[category]
    if not dc then
        return
    end
    local entries   = dc.entries
    local tags      = utilities.parsers.settings_to_array(tags)
    local options   = utilities.parsers.settings_to_hash(options) -- options can be hash too
    local start     = tonumber(options.start)
    local n         = tonumber(options.n)
    local criterium = options.criterium
    local max       = 1
    if n then
        max = n
    elseif criterium == v_all then
        max = 0
        for t=1,#tags do
            local tag = tags[t]
            local lines = entries[tag].lines
            if #lines > max then
                max = #lines
            end
        end
    end
    for i=1,max do
        for t=1,#tags do
            local tag = tags[t]
            local entry = entries[tag]
            if entry then
                local lines   = entry.lines
                local number  = entry.number + 1
                entry.number  = number
                local line    = remove(lines,1)
                local content = line and line.content
                local label   = line and line.label or ""
                if content then
                    local virtual = save_byscheme("virtual","parallel",content)
                    ctx_doflushparallel(tag,1,number,label,f_content(virtual))
                else
                    ctx_doflushparallel(tag,0,number,"","")
                end
            end
        end
    end
end

-- interface

implement {
    name      = "defineparallel",
    actions   = parallel.define,
    arguments = "2 strings",
}

implement {
    name      = "nextparallel",
    actions   = parallel.next,
    arguments = "string"
}

implement {
    name      = "saveparallel",
    actions   = parallel.save,
    arguments = { "string", "string", "string", true },
}

implement {
    name      = "placeparallel",
    actions   = parallel.place,
    arguments = {
        "string",
        "string",
        {
            { "start" },
            { "n" },
            { "criterium" },
            { "setups" },
        }
    }
}

implement {
    name      = "resetparallel",
    actions   = parallel.reset,
    arguments = "2 strings",
}

implement {
    name      = "doifelseparallel",
    actions   = { parallel.hassomecontent, commands.doifelse } ,
    arguments = "2 strings",
}
