if not modules then modules = { } end modules ['trac-log'] = {
    version   = 1.001,
    comment   = "companion to trac-log.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- In fact all writes could go through lua and we could write the console and
-- terminal handler in lua then. Ok, maybe it's slower then, so a no-go.
--
-- This is the version for mtxrun. The alternative functions for the TeX engines
-- have been separated. In order to keep in sync we use tex specific witer names.
--
-- Todo: some cleanup (less local needed).

local next, type, select, print = next, type, select, print
local format, gmatch, find = string.format, string.gmatch, string.find
local concat, insert, remove = table.concat, table.insert, table.remove
local topattern = string.topattern
local utfchar = utf.char
local datetime = os.date
local openfile = io.open

local write_nl = print
local write    = io.write

local setmetatableindex = table.setmetatableindex
local formatters        = string.formatters
local settings_to_hash  = utilities.parsers.settings_to_hash
local sortedkeys        = table.sortedkeys

local variant = "default"
----- variant = "ansi"

logs       = logs or { }
local logs = logs

local moreinfo = [[
More information about ConTeXt and the tools that come with it can be found at:
]] .. "\n" .. [[
maillist : ntg-context@ntg.nl / http://www.ntg.nl/mailman/listinfo/ntg-context
webpage  : http://www.pragma-ade.nl / http://tex.aanhet.net
wiki     : http://contextgarden.net
]]

formatters.add (
    formatters, "unichr",
    [["U+" .. format("%%05X",%s) .. " (" .. utfchar(%s) .. ")"]]
)

formatters.add (
    formatters, "chruni",
    [[utfchar(%s) .. " (U+" .. format("%%05X",%s) .. ")"]]
)

-- basic loggers

local function ignore() end

setmetatableindex(logs, function(t,k) t[k] = ignore ; return ignore end)

local report, subreport, status, settarget, setformats, settranslations

local direct, subdirect, writer, pushtarget, poptarget, setlogfile, settimedlog, setprocessor, setformatters, newline

-- we use formatters but best check for % then because for simple messages but
-- we don't want this overhead for single messages (not that there are that
-- many; we could have a special weak table)

local function ansisupported(specification)
    if specification ~= "ansi" and specification ~= "ansilog" then
        return false
    elseif os and os.enableansi then
        return os.enableansi()
    else
        return false
    end
end

do

    local report_yes, subreport_yes, status_yes
    local report_nop, subreport_nop, status_nop

    local variants = {
        default = {
            formats = {
                report_yes    = formatters["%-15s | %s"],
                report_nop    = formatters["%-15s |"],
                subreport_yes = formatters["%-15s | %s | %s"],
                subreport_nop = formatters["%-15s | %s |"],
                status_yes    = formatters["%-15s : %s\n"],
                status_nop    = formatters["%-15s :\n"],
            },
        },
        ansi = {
            formats = {
                report_yes    = formatters["[0;32m%-15s [0;1m|[0m %s"],
                report_nop    = formatters["[0;32m%-15s [0;1m|[0m"],
                subreport_yes = formatters["[0;32m%-15s [0;1m|[0;31m %s [0;1m|[0m %s"],
                subreport_nop = formatters["[0;32m%-15s [0;1m|[0;31m %s [0;1m|[0m"],
                status_yes    = formatters["[0;32m%-15s [0;1m:[0m %s\n"],
                status_nop    = formatters["[0;32m%-15s [0;1m:[0m\n"],
            },
        },
    }

    logs.flush = ignore

    writer = function(s)
        write_nl(s)
    end

    newline = function()
        write_nl("\n")
    end

    report = function(a,b,c,...)
        if c then
            write_nl(report_yes(a,formatters[b](c,...)))
        elseif b then
            write_nl(report_yes(a,b))
        elseif a then
            write_nl(report_nop(a))
        else
            write_nl("")
        end
    end

    subreport = function(a,sub,b,c,...)
        if c then
            write_nl(subreport_yes(a,sub,formatters[b](c,...)))
        elseif b then
            write_nl(subreport_yes(a,sub,b))
        elseif a then
            write_nl(subreport_nop(a,sub))
        else
            write_nl("")
        end
    end

    status = function(a,b,c,...) -- not to be used in lua anyway
        if c then
            write_nl(status_yes(a,formatters[b](c,...)))
        elseif b then
            write_nl(status_yes(a,b)) -- b can have %'s
        elseif a then
            write_nl(status_nop(a))
        else
            write_nl("\n")
        end
    end

    direct          = ignore
    subdirect       = ignore

    settarget       = ignore
    pushtarget      = ignore
    poptarget       = ignore
    setformats      = ignore
    settranslations = ignore

    setprocessor = function(f)
        local writeline = write_nl
        write_nl = function(s)
            writeline(f(s))
        end
    end

    setformatters = function(specification)
        local f = nil
        local d = variants.default
        if specification then
            if type(specification) == "table" then
                f = specification.formats or specification
            else
                if not ansisupported(specification) then
                    specification = "default"
                end
                local v = variants[specification]
                if v then
                    f = v.formats
                end
            end
        end
        if f then
            d = d.formats
        else
            f = d.formats
            d = f
        end
        setmetatableindex(f,d)
        report_yes    = f.report_yes
        report_nop    = f.report_nop
        subreport_yes = f.subreport_yes
        subreport_nop = f.subreport_nop
        status_yes    = f.status_yes
        status_nop    = f.status_nop
    end

    setformatters(variant)

    setlogfile = function(name,keepopen)
        if name and name ~= "" then
            local localtime = os.localtime
            local writeline = write_nl
            if keepopen then
                local f = io.open(name,"ab")
                write_nl = function(s)
                    writeline(s)
                    f:write(localtime()," | ",s,"\n")
                end
            else
                write_nl = function(s)
                    writeline(s)
                    local f = io.open(name,"ab")
                    f:write(localtime()," | ",s,"\n")
                    f:close()
                end
            end
        end
        setlogfile = ignore
    end

    settimedlog = function()
        local localtime = os.localtime
        local writeline = write_nl
        write_nl = function(s)
            writeline(localtime() .. " | " .. s)
        end
        settimedlog = ignore
    end

end

logs.report          = report
logs.subreport       = subreport
logs.status          = status
logs.settarget       = settarget
logs.pushtarget      = pushtarget
logs.poptarget       = poptarget
logs.setformats      = setformats
logs.settranslations = settranslations

logs.setlogfile      = setlogfile
logs.settimedlog     = settimedlog
logs.setprocessor    = setprocessor
logs.setformatters   = setformatters

logs.direct          = direct
logs.subdirect       = subdirect
logs.writer          = writer
logs.newline         = newline

-- installer

-- todo: renew (un) locks when a new one is added and wildcard

local data   = { }
local states = nil
local force  = false

function logs.reporter(category,subcategory)
    local logger = data[category]
    if not logger then
        local state = states == true
        if not state and type(states) == "table" then
            for c, _ in next, states do
                if find(category,c) then
                    state = true
                    break
                end
            end
        end
        logger = {
            reporters = { },
            state     = state,
        }
        data[category] = logger
    end
    local reporter = logger.reporters[subcategory or "default"]
    if not reporter then
        if subcategory then
            reporter = function(...)
                if force or not logger.state then
                    subreport(category,subcategory,...)
                end
            end
            logger.reporters[subcategory] = reporter
        else
            local tag = category
            reporter = function(...)
                if force or not logger.state then
                    report(category,...)
                end
            end
            logger.reporters.default = reporter
        end
    end
    return reporter
end

logs.new = logs.reporter -- for old times sake

-- context specicific: this ends up in the macro stream

local ctxreport = logs.writer

function logs.setmessenger(m)
    ctxreport = m
end

function logs.messenger(category,subcategory)
    -- we need to avoid catcode mess (todo: fast context)
    if subcategory then
        return function(...)
            ctxreport(subdirect(category,subcategory,...))
        end
    else
        return function(...)
            ctxreport(direct(category,...))
        end
    end
end

-- so far

local function setblocked(category,value) -- v.state == value == true : disable
    if category == true or category == "all" then
        -- lock all
        category, value = "*", true
    elseif category == false then
        -- unlock all
        category, value = "*", false
    elseif value == nil then
        -- lock selective
        value = true
    end
    if category == "*" then
        states = value
        for k, v in next, data do
            v.state = value
        end
    else
        alllocked = false
        states = settings_to_hash(category,type(states)=="table" and states or nil)
        for c in next, states do
            local v = data[c]
            if v then
                v.state = value
            else
                c = topattern(c,true,true)
                for k, v in next, data do
                    if find(k,c) then
                        v.state = value
                    end
                end
            end
        end
    end
end

function logs.disable(category,value)
    setblocked(category,value == nil and true or value)
end

function logs.enable(category)
    setblocked(category,false)
end

function logs.categories()
    return sortedkeys(data)
end

function logs.show()
    local n, c, s, max = 0, 0, 0, 0
    for category, v in table.sortedpairs(data) do
        n = n + 1
        local state = v.state
        local reporters = v.reporters
        local nc = #category
        if nc > c then
            c = nc
        end
        for subcategory, _ in next, reporters do
            local ns = #subcategory
            if ns > c then
                s = ns
            end
            local m = nc + ns
            if m > max then
                max = m
            end
        end
        local subcategories = concat(sortedkeys(reporters),", ")
        if state == true then
            state = "disabled"
        elseif state == false then
            state = "enabled"
        else
            state = "unknown"
        end
        -- no new here
        report("logging","category %a, subcategories %a, state %a",category,subcategories,state)
    end
    report("logging","categories: %s, max category: %s, max subcategory: %s, max combined: %s",n,c,s,max)
end

local delayed_reporters = { }

setmetatableindex(delayed_reporters,function(t,k)
    local v = logs.reporter(k.name)
    t[k] = v
    return v
end)

function utilities.setters.report(setter,...)
    delayed_reporters[setter](...)
end

directives.register("logs.blocked", function(v)
    setblocked(v,true)
end)

directives.register("logs.target", function(v)
    settarget(v)
end)

-- we don't have show_open and show_close callbacks yet

----- report_files = logs.reporter("files")
local nesting      = 0
local verbose      = false
local hasscheme    = url.hasscheme

-- there may be scripts out there using this:

local simple = logs.reporter("comment")

logs.simple     = simple
logs.simpleline = simple

-- obsolete

logs.setprogram   = ignore -- obsolete
logs.extendbanner = ignore -- obsolete
logs.reportlines  = ignore -- obsolete
logs.reportbanner = ignore -- obsolete
logs.reportline   = ignore -- obsolete
logs.simplelines  = ignore -- obsolete
logs.help         = ignore -- obsolete

-- applications

local Carg, C, lpegmatch = lpeg.Carg, lpeg.C, lpeg.match
local p_newline = lpeg.patterns.newline

local linewise = (
    Carg(1) * C((1-p_newline)^1) / function(t,s) t.report(s) end
  + Carg(1) * p_newline^2        / function(t)   t.report()  end
  + p_newline
)^1

local function reportlines(t,str)
    if str then
        lpegmatch(linewise,str,1,t)
    end
end

local function reportbanner(t)
    local banner = t.banner
    if banner then
        t.report(banner)
        t.report()
    end
end

local function reportversion(t)
    local banner = t.banner
    if banner then
        t.report(banner)
    end
end

local function reporthelp(t,...)
    local helpinfo = t.helpinfo
    if type(helpinfo) == "string" then
        reportlines(t,helpinfo)
    elseif type(helpinfo) == "table" then
        for i=1,select("#",...) do
            reportlines(t,t.helpinfo[select(i,...)])
            if i < n then
                t.report()
            end
        end
    end
end

local function reportinfo(t)
    t.report()
    reportlines(t,t.moreinfo)
end

local function reportexport(t,method)
    report(t.helpinfo)
end

local reporters = {
    lines   = reportlines, -- not to be overloaded
    banner  = reportbanner,
    version = reportversion,
    help    = reporthelp,
    info    = reportinfo,
    export  = reportexport,
}

local exporters = {
    -- empty
}

logs.reporters = reporters
logs.exporters = exporters

function logs.application(t)
    --
    local arguments = environment and environment.arguments
    if arguments then
        local ansi = arguments.ansi or arguments.ansilog
        if ansi then
            logs.setformatters(arguments.ansi and "ansi" or "ansilog")
        end
    end
    --
    t.name     = t.name   or "unknown"
    t.banner   = t.banner
    t.moreinfo = moreinfo
    t.report   = logs.reporter(t.name)
    t.help     = function(...)
        reporters.banner(t)
        reporters.help(t,...)
        reporters.info(t)
    end
    t.export   = function(...)
        reporters.export(t,...)
    end
    t.identify = function()
        reporters.banner(t)
    end
    t.version  = function()
        reporters.version(t)
    end
    return t
end

-- somewhat special .. will be redone (already a better solution in place in lmx)

-- logging to a file

-- local syslogname = "oeps.xxx"
--
-- for i=1,10 do
--     logs.system(syslogname,"context","test","fonts","font %s recached due to newer version (%s)","blabla","123")
-- end

local f_syslog = formatters["%s %s => %s => %s => %s\r"]

function logs.system(whereto,process,jobname,category,fmt,arg,...)
    local message = f_syslog(datetime("%d/%m/%y %H:%m:%S"),process,jobname,category,arg == nil and fmt or format(fmt,arg,...))
    for i=1,10 do
        local f = openfile(whereto,"a") -- we can consider keeping the file open
        if f then
            f:write(message)
            f:close()
            break
        else
            sleep(0.1)
        end
    end
end

local report_system = logs.reporter("system","logs")

if utilities then
    utilities.report = report_system
end

-- this is somewhat slower but prevents out-of-order messages when print is mixed
-- with texio.write

-- io.stdout:setvbuf('no')
-- io.stderr:setvbuf('no')

-- windows: > nul  2>&1
-- unix   : > null 2>&1

if package.helpers.report then
    package.helpers.report = logs.reporter("package loader") -- when used outside mtxrun
end
