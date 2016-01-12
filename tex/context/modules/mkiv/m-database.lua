if not modules then modules = { } end modules ['m-database'] = {
    version   = 1.001,
    comment   = "companion to m-database.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local sub, gmatch = string.sub, string.gmatch
local concat = table.concat
local lpegpatterns, lpegmatch, lpegsplitat = lpeg.patterns, lpeg.match, lpeg.splitat
local lpegP, lpegC, lpegS, lpegCt, lpegCc, lpegCs = lpeg.P, lpeg.C, lpeg.S, lpeg.Ct, lpeg.Cc, lpeg.Cs
local stripstring = string.strip

moduledata.database     = moduledata.database     or { }
moduledata.database.csv = moduledata.database.csv or { }

-- One also needs to enable context.trace, here we only plug in some code (maybe
-- some day this tracker will also toggle the main context tracer.

local trace_flush     = false  trackers.register("module.database.flush", function(v) trace_flush = v end)
local report_database = logs.reporter("database")

local context = context

local l_tab   = lpegpatterns.tab
local l_space = lpegpatterns.space
local l_comma = lpegpatterns.comma
local l_empty = lpegS("\t\n\r ")^0 * lpegP(-1)

local v_yes   = interfaces.variables.yes

local separators = { -- not interfaced
    tab    = l_tab,
    tabs   = l_tab^1,
    comma  = l_comma,
    space  = l_space,
    spaces = l_space^1,
}

function moduledata.database.csv.process(settings)
    local data
    if settings.type == "file" then
        local filename = resolvers.finders.byscheme("any",settings.database)
        data = filename ~= "" and io.loaddata(filename)
        data = data and string.splitlines(data)
    else
        data = buffers.getlines(settings.database)
    end
    if data and #data > 0 then
        local catcodes = tonumber(settings.catcodes) or tex.catcodetable
        context.pushcatcodes(catcodes)
        if trace_flush then
            context.pushlogger(report_database)
        end
        local separatorchar, quotechar, commentchar = settings.separator, settings.quotechar, settings.commentchar
        local before, after = settings.before or "", settings.after or ""
        local first, last = settings.first or "", settings.last or ""
        local left, right = settings.left or "", settings.right or ""
        local setups = settings.setups or ""
        local strip = settings.strip == v_yes or false
        local command = settings.command or ""
        separatorchar = (not separatorchar and ",") or separators[separatorchar] or separatorchar
        local separator = type(separatorchar) == "string" and lpegS(separatorchar) or separatorchar
        local whatever  = lpegC((1 - separator)^0)
        if quotechar and quotechar ~= "" then
            local quotedata = nil
            for chr in gmatch(quotechar,".") do
                local quotechar = lpegP(chr)
                local quoteword = lpegCs(((l_space^0 * quotechar)/"") * (1 - quotechar)^0 * ((quotechar * l_space^0)/""))
                if quotedata then
                    quotedata = quotedata + quoteword
                else
                    quotedata = quoteword
                end
            end
            whatever = quotedata + whatever
        end
        local checker = commentchar ~= "" and lpegS(commentchar)
        if strip then
            whatever = whatever / stripstring
        end
        if left ~= "" then
            whatever = lpegCc(left) * whatever
        end
        if right ~= "" then
            whatever = whatever * lpegCc(right)
        end
        if command ~= "" then
            whatever = lpegCc("{") * whatever * lpegCc("}")
        end
        whatever = whatever * (separator/"" * whatever)^0
        if first ~= "" then
            whatever = lpegCc(first) * whatever
        end
        if last ~= "" then
            whatever = whatever * lpegCc(last)
        end
        if command ~= "" then
            whatever = lpegCs(lpegCc(command) * whatever)
        else
            whatever = lpegCs(whatever)
        end
        local found = false
        for i=1,#data do
            local line = data[i]
            if not lpegmatch(l_empty,line) and (not checker or not lpegmatch(checker,line)) then
                if not found then
                    if setups ~= "" then
                        context.begingroup()
                        context.setups { setups }
                    end
                    context(before)
                    found = true
                end
                context(lpegmatch(whatever,line))
            end
        end
        if found then
            context(after)
            if setups ~= "" then
                context.endgroup()
            end
        end
        context.popcatcodes()
        if trace_flush then
            context.poplogger()
        end
    else
        -- message
    end
end
