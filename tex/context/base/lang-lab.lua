if not modules then modules = { } end modules ['lang-lab'] = {
    version   = 1.001,
    comment   = "companion to lang-lab.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, find = string.format, string.find
local next, rawget, type = next, rawget, type
local lpegmatch = lpeg.match
local formatters = string.formatters

local prtcatcodes = catcodes.numbers.prtcatcodes -- todo: use different method

local trace_labels  = false  trackers.register("languages.labels", function(v) trace_labels = v end)
local report_labels = logs.reporter("languages","labels")

languages.labels        = languages.labels or { }
local labels            = languages.labels

local context           = context
local implement         = interfaces.implement

local variables         = interfaces.variables
local settings_to_array = utilities.parsers.settings_to_array

local splitter = lpeg.splitat(":")

local function split(tag)
    return lpegmatch(splitter,tag)
end

labels.split = split

local contextsprint      = context.sprint

local f_setlabeltextpair = formatters["\\setlabeltextpair{%s}{%s}{%s}{%s}{%s}"]
local f_key_key          = formatters["\\v!%s:\\v!%s"]
local f_key_raw          = formatters["\\v!%s:%s"]
local f_raw_key          = formatters["%s:\\v!%s"]
local f_raw_raw          = formatters["%s:%s"]
local f_key              = formatters["\\v!%s"]
local f_raw              = formatters["%s"]

local function definelanguagelabels(data,class,tag,rawtag)
    for language, text in next, data.labels do
        if text == "" then
            -- skip
        elseif type(text) == "table" then
            contextsprint(prtcatcodes,f_setlabeltextpair(class,language,tag,text[1],text[2]))
            if trace_labels then
                report_labels("language %a, defining label %a as %a and %a",language,rawtag,text[1],text[2])
            end
        else
            contextsprint(prtcatcodes,f_setlabeltextpair(class,language,tag,text,""))
            if trace_labels then
                report_labels("language %a, defining label %a as %a",language,rawtag,text)
            end
        end
    end
end

function labels.define(class,name,prefixed)
    local list = languages.data.labels[name]
    if list then
        report_labels("defining label set %a",name)
        for tag, data in next, list do
            tag = variables[tag] or tag
            if data.hidden then
                -- skip
            elseif prefixed then
                local first, second = lpegmatch(splitter,tag)
                if second then
                    if rawget(variables,first) then
                        if rawget(variables,second) then
                            definelanguagelabels(data,class,f_key_key(first,second),tag)
                        else
                            definelanguagelabels(data,class,f_key_raw(first,second),tag)
                        end
                     elseif rawget(variables,second) then
                        definelanguagelabels(data,class,f_raw_key(first,second),tag)
                    else
                        definelanguagelabels(data,class,f_raw_raw(first,second),tag)
                    end
                elseif rawget(variables,rawtag) then
                    definelanguagelabels(data,class,f_key(tag),tag)
                else
                    definelanguagelabels(data,class,tag,tag)
                end
            else
                definelanguagelabels(data,class,tag,tag)
            end
        end
    else
        report_labels("unknown label set %a",name)
    end
end

-- function labels.check()
--     for category, list in next, languages.data.labels do
--         for tag, specification in next, list do
--             for language, text in next, specification.labels do
--                 if type(text) == "string" and find(text,",") then
--                     report_labels("warning: label with comma found, category %a, language %a, tag %a, text %a",
--                         category, language, tag, text)
--                 end
--             end
--         end
--     end
-- end
--
-- labels.check()

-- interface

interfaces.implement {
    name      = "definelabels",
    actions   = labels.define,
    arguments = { "string",  "string", "boolean" }
}

-- function commands.setstrippedtextprefix(str)
--     context(string.strip(str))
-- end

-- list       : { "a", "b", "c" }
-- separator  : ", "
-- last       : " and "

-- text       : "a,b,c"
-- separators : "{, },{ and }"

local function concatcommalist(settings) -- it's too easy to forget that this one is there
    local list = settings.list or settings_to_array(settings.text or "")
    local size = #list
    local command = settings.command and context[settings.command] or context
    if size > 1 then
        local separator, last = " ", " "
        if settings.separators then
            local set = settings_to_array(settings.separators)
            separator = set[1] or settings.separator or separator
            last      = set[2] or settings.last      or last
        else
            separator = settings.separator or separator
            last      = settings.last      or last
        end
        command(list[1])
        for i=2,size-1 do
            context(separator)
            command(list[i])
        end
        context(last)
    end
    if size > 0 then
        command(list[size])
    end
end

implement {
    name      = "concatcommalist",
    actions   = concatcommalist,
    arguments = {
        {
            { "text" },
            { "separators" },
            { "separator" },
            { "last" },
        }
    }
}
