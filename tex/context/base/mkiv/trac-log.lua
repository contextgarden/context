if not modules then modules = { } end modules ['trac-log'] = {
    version   = 1.001,
    comment   = "companion to trac-log.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- In fact all writes could go through lua and we could write the console and
-- terminal handler in lua then. Ok, maybe it's slower then, so a no-go.

local next, type, select, print = next, type, select, print
local write_nl, write = texio and texio.write_nl or print, texio and texio.write or io.write
local format, gmatch, find = string.format, string.gmatch, string.find
local concat, insert, remove = table.concat, table.insert, table.remove
local topattern = string.topattern
local utfchar = utf.char
local datetime = os.date
local openfile = io.open

local setmetatableindex = table.setmetatableindex
local formatters        = string.formatters

local texgetcount       = tex and tex.getcount

-- variant is set now

local variant = "default"
-- local variant = "ansi"

-- todo: less categories, more subcategories (e.g. nodes)
-- todo: split into basics and ctx specific

--[[ldx--
<p>This is a prelude to a more extensive logging module. We no longer
provide <l n='xml'/> based logging as parsing is relatively easy anyway.</p>
--ldx]]--

logs       = logs or { }
local logs = logs

local moreinfo = [[
More information about ConTeXt and the tools that come with it can be found at:
]] .. "\n" .. [[
maillist : ntg-context@ntg.nl / http://www.ntg.nl/mailman/listinfo/ntg-context
webpage  : http://www.pragma-ade.nl / http://tex.aanhet.net
wiki     : http://contextgarden.net
]]

-- -- we extend the formatters:
--
-- function utilities.strings.unichr(s) return "U+" .. format("%05X",s) .. " (" .. utfchar(s) .. ")" end
-- function utilities.strings.chruni(s) return utfchar(s) .. " (U+" .. format("%05X",s) .. ")" end
--
-- utilities.strings.formatters.add (
--     string.formatters, "unichr",
--     [[unichr(%s)]],
--     [[local unichr = utilities.strings.unichr]]
-- )
--
-- utilities.strings.formatters.add (
--     string.formatters, "chruni",
--     [[chruni(%s)]],
--     [[local chruni = utilities.strings.chruni]]
-- )

formatters.add (
    formatters, "unichr",
    [["U+" .. format("%%05X",%s) .. " (" .. utfchar(%s) .. ")"]]
)

formatters.add (
    formatters, "chruni",
    [[utfchar(%s) .. " (U+" .. format("%%05X",%s) .. ")"]]
)

-- function utilities.strings.unichk(s) return s <= 0xFFFF and ("U+" .. format("%05X",s) .. " (" .. utfchar(s) .. ")") or ("U+" .. format("%05X",s)) end
-- function utilities.strings.chkuni(s) return s <= 0xFFFF and (utfchar(s) .. " (U+" .. format("%05X",s) .. ")") or ("U+" .. format("%05X",s)) end
--
-- utilities.strings.formatters.add (
--     string.formatters, "unichk",
--     [[unichk(%s)]],
--     [[local unichk = utilities.strings.unichk]]
-- )
--
-- utilities.strings.formatters.add (
--     string.formatters, "chkuni",
--     [[chkuni(%s)]],
--     [[local chkuni = utilities.strings.chkuni]]
-- )
--
-- print(formatters["Missing character %!chruni! in font."](234))
-- print(formatters["Missing character %!unichr! in font."](234))
-- print(formatters["Missing character %!chkuni! in font."](234))
-- print(formatters["Missing character %!unichk! in font."](234))

-- basic loggers

local function ignore() end

setmetatableindex(logs, function(t,k) t[k] = ignore ; return ignore end)

local report, subreport, status, settarget, setformats, settranslations

local direct, subdirect, writer, pushtarget, poptarget, setlogfile, settimedlog, setprocessor, setformatters, newline

-- we use formatters but best check for % then because for simple messages but
-- we don't want this overhead for single messages (not that there are that
-- many; we could have a special weak table)

if tex and (tex.jobname or tex.formatname) then

    if texio.setescape then
        texio.setescape(0) -- or (false)
    end

    local function useluawrites()

        -- quick hack, awaiting speedup in engine (8 -> 6.4 sec for --make with console2)
        -- still needed for luajittex .. luatex should not have that ^^ mess

        local texio_write_nl = texio.write_nl
        local texio_write    = texio.write
        local io_write       = io.write

        write_nl = function(target,...)
            if not io_write then
                io_write = io.write
            end
            if target == "term and log" then
                texio_write_nl("log",...)
                texio_write_nl("term","")
                io_write(...)
            elseif target == "log" then
                texio_write_nl("log",...)
            elseif target == "term" then
                texio_write_nl("term","")
                io_write(...)
            elseif type(target) == "number" then
                texio_write_nl(target,...) -- a tex output channel
            elseif target ~= "none" then
                texio_write_nl("log",target,...)
                texio_write_nl("term","")
                io_write(target,...)
            end
        end

        write = function(target,...)
            if not io_write then
                io_write = io.write
            end
            if target == "term and log" then
                texio_write("log",...)
                io_write(...)
            elseif target == "log" then
                texio_write("log",...)
            elseif target == "term" then
                io_write(...)
            elseif type(target) == "number" then
                texio_write(target,...) -- a tex output channel
            elseif target ~= "none" then
                texio_write("log",target,...)
                io_write(target,...)
            end
        end

        texio.write    = write
        texio.write_nl = write_nl

        useluawrites   = ignore

    end

 -- local format = string.formatter

    local whereto      = "both"
    local target       = nil
    local targets      = nil

    local formats      = table.setmetatableindex("self")
    local translations = table.setmetatableindex("self")

    local report_yes, subreport_yes, direct_yes, subdirect_yes, status_yes
    local report_nop, subreport_nop, direct_nop, subdirect_nop, status_nop

    local variants = {
        default = {
            formats = {
                report_yes    = formatters["%-15s > %s\n"],
                report_nop    = formatters["%-15s >\n"],
                direct_yes    = formatters["%-15s > %s"],
                direct_nop    = formatters["%-15s >"],
                subreport_yes = formatters["%-15s > %s > %s\n"],
                subreport_nop = formatters["%-15s > %s >\n"],
                subdirect_yes = formatters["%-15s > %s > %s"],
                subdirect_nop = formatters["%-15s > %s >"],
                status_yes    = formatters["%-15s : %s\n"],
                status_nop    = formatters["%-15s :\n"],
            },
            targets = {
                logfile  = "log",
                log      = "log",
                file     = "log",
                console  = "term",
                terminal = "term",
                both     = "term and log",
            },
        },
        ansi = {
            formats = {
                report_yes    = formatters["[0;33m%-15s [0;1m>[0m %s\n"],
                report_nop    = formatters["[0;33m%-15s [0;1m>[0m\n"],
                direct_yes    = formatters["[0;33m%-15s [0;1m>[0m %s"],
                direct_nop    = formatters["[0;33m%-15s [0;1m>[0m"],
                subreport_yes = formatters["[0;33m%-15s [0;1m>[0;35m %s [0;1m>[0m %s\n"],
                subreport_nop = formatters["[0;33m%-15s [0;1m>[0;35m %s [0;1m>[0m\n"],
                subdirect_yes = formatters["[0;33m%-15s [0;1m>[0;35m %s [0;1m>[0m %s"],
                subdirect_nop = formatters["[0;33m%-15s [0;1m>[0;35m %s [0;1m>[0m"],
                status_yes    = formatters["[0;33m%-15s [0;1m:[0m %s\n"],
                status_nop    = formatters["[0;33m%-15s [0;1m:[0m\n"],
            },
            targets = {
                logfile  = "none",
                log      = "none",
                file     = "none",
                console  = "term",
                terminal = "term",
                both     = "term",
            },
        }
    }

    logs.flush = io.flush

    writer = function(...)
        write_nl(target,...)
    end

    newline = function()
        write_nl(target,"\n")
    end

    report = function(a,b,c,...)
        if c ~= nil then
            write_nl(target,report_yes(translations[a],formatters[formats[b]](c,...)))
        elseif b then
            write_nl(target,report_yes(translations[a],formats[b]))
        elseif a then
            write_nl(target,report_nop(translations[a]))
        else
            write_nl(target,"\n")
        end
    end

    direct = function(a,b,c,...)
        if c ~= nil then
            return direct_yes(translations[a],formatters[formats[b]](c,...))
        elseif b then
            return direct_yes(translations[a],formats[b])
        elseif a then
            return direct_nop(translations[a])
        else
            return ""
        end
    end

    subreport = function(a,s,b,c,...)
        if c ~= nil then
            write_nl(target,subreport_yes(translations[a],translations[s],formatters[formats[b]](c,...)))
        elseif b then
            write_nl(target,subreport_yes(translations[a],translations[s],formats[b]))
        elseif a then
            write_nl(target,subreport_nop(translations[a],translations[s]))
        else
            write_nl(target,"\n")
        end
    end

    subdirect = function(a,s,b,c,...)
        if c ~= nil then
            return subdirect_yes(translations[a],translations[s],formatters[formats[b]](c,...))
        elseif b then
            return subdirect_yes(translations[a],translations[s],formats[b])
        elseif a then
            return subdirect_nop(translations[a],translations[s])
        else
            return ""
        end
    end

    status = function(a,b,c,...)
        if c ~= nil then
            write_nl(target,status_yes(translations[a],formatters[formats[b]](c,...)))
        elseif b then
            write_nl(target,status_yes(translations[a],formats[b]))
        elseif a then
            write_nl(target,status_nop(translations[a]))
        else
            write_nl(target,"\n")
        end
    end

    settarget = function(askedwhereto)
        whereto = askedwhereto or whereto or "both"
        target = targets[whereto]
        if not target then
            whereto   = "both"
            target = targets[whereto]
        end
        if target == "term" or target == "term and log" then
            logs.flush = io.flush
        else
            logs.flush = ignore
        end
    end

    local stack = { }

    pushtarget = function(newtarget)
        insert(stack,target)
        settarget(newtarget)
    end

    poptarget = function()
        if #stack > 0 then
            settarget(remove(stack))
        end
    end

    setformats = function(f)
        formats = f
    end

    settranslations = function(t)
        translations = t
    end

    setprocessor = function(f)
        local writeline = write_nl
        write_nl = function(target,...)
            writeline(target,f(...))
        end
    end

    setformatters = function(specification)
        local t = nil
        local f = nil
        local d = variants.default
        if not specification then
            --
        elseif type(specification) == "table" then
            t = specification.targets
            f = specification.formats or specification
        else
            local v = variants[specification]
            if v then
                t = v.targets
                f = v.formats
                variant = specification
            end
        end
        targets = t or d.targets
        target = targets[whereto] or target
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
        direct_yes    = f.direct_yes
        direct_nop    = f.direct_nop
        subdirect_yes = f.subdirect_yes
        subdirect_nop = f.subdirect_nop
        status_yes    = f.status_yes
        status_nop    = f.status_nop
        if variant == "ansi" then
            useluawrites() -- because tex escapes ^^
        end
        settarget(whereto)
    end

    setformatters(variant)

    setlogfile  = ignore
    settimedlog = ignore

else

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

local data, states = { }, nil

function logs.reporter(category,subcategory)
    local logger = data[category]
    if not logger then
        local state = false
        if states == true then
            state = true
        elseif type(states) == "table" then
            for c, _ in next, states do
                if find(category,c) then
                    state = true
                    break
                end
            end
        end
        logger = {
            reporters = { },
            state = state,
        }
        data[category] = logger
    end
    local reporter = logger.reporters[subcategory or "default"]
    if not reporter then
        if subcategory then
            reporter = function(...)
                if not logger.state then
                    subreport(category,subcategory,...)
                end
            end
            logger.reporters[subcategory] = reporter
        else
            local tag = category
            reporter = function(...)
                if not logger.state then
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
    if category == true then
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
        states = utilities.parsers.settings_to_hash(category,type(states)=="table" and states or nil)
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
    return table.sortedkeys(data)
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
        local subcategories = concat(table.sortedkeys(reporters),", ")
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

-- tex specific loggers (might move elsewhere)

local report_pages = logs.reporter("pages") -- not needed but saves checking when we grep for it

local real, user, sub

function logs.start_page_number()
    real = texgetcount("realpageno")
    user = texgetcount("userpageno")
    sub  = texgetcount("subpageno")
end

local timing    = false
local starttime = nil
local lasttime  = nil

trackers.register("pages.timing", function(v) -- only for myself (diagnostics)
    starttime = os.clock()
    timing    = true
end)

function logs.stop_page_number() -- the first page can includes the initialization so we omit this in average
    if timing then
        local elapsed, average
        local stoptime = os.clock()
        if not lasttime or real < 2 then
            elapsed   = stoptime
            average   = stoptime
            starttime = stoptime
        else
            elapsed  = stoptime - lasttime
            average  = (stoptime - starttime) / (real - 1)
        end
        lasttime = stoptime
        if real <= 0 then
            report_pages("flushing page, time %0.04f / %0.04f",elapsed,average)
        elseif user <= 0 then
            report_pages("flushing realpage %s, time %0.04f / %0.04f",real,elapsed,average)
        elseif sub <= 0 then
            report_pages("flushing realpage %s, userpage %s, time %0.04f / %0.04f",real,user,elapsed,average)
        else
            report_pages("flushing realpage %s, userpage %s, subpage %s, time %0.04f / %0.04f",real,user,sub,elapsed,average)
        end
    else
        if real <= 0 then
            report_pages("flushing page")
        elseif user <= 0 then
            report_pages("flushing realpage %s",real)
        elseif sub <= 0 then
            report_pages("flushing realpage %s, userpage %s",real,user)
        else
            report_pages("flushing realpage %s, userpage %s, subpage %s",real,user,sub)
        end
    end
    logs.flush()
end

-- we don't have show_open and show_close callbacks yet

local report_files = logs.reporter("files")
local nesting      = 0
local verbose      = false
local hasscheme    = url.hasscheme

function logs.show_open(name)
 -- if hasscheme(name) ~= "virtual" then
 --     if verbose then
 --         nesting = nesting + 1
 --         report_files("level %s, opening %s",nesting,name)
 --     else
 --         write(formatters["(%s"](name)) -- tex adds a space
 --     end
 -- end
end

function logs.show_close(name)
 -- if hasscheme(name) ~= "virtual" then
 --     if verbose then
 --         report_files("level %s, closing %s",nesting,name)
 --         nesting = nesting - 1
 --     else
 --         write(")") -- tex adds a space
 --     end
 -- end
end

function logs.show_load(name)
 -- if hasscheme(name) ~= "virtual" then
 --     if verbose then
 --         report_files("level %s, loading %s",nesting+1,name)
 --     else
 --         write(formatters["(%s)"](name))
 --     end
 -- end
end

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

-- local function reportlines(t,str)
--     if str then
--         for line in gmatch(str,"([^\n\r]*)[\n\r]") do
--             t.report(line)
--         end
--     end
-- end

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
    lines    = reportlines, -- not to be overloaded
    banner   = reportbanner,
    version  = reportversion,
    help     = reporthelp,
    info     = reportinfo,
    export   = reportexport,
}

local exporters = {
    -- empty
}

logs.reporters = reporters
logs.exporters = exporters

function logs.application(t)
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

function logs.obsolete(old,new)
    local o = loadstring("return " .. new)()
    if type(o) == "function" then
        return function(...)
            report_system("function %a is obsolete, use %a",old,new)
            loadstring(old .. "=" .. new  .. " return ".. old)()(...)
        end
    elseif type(o) == "table" then
        local t, m = { }, { }
        m.__index = function(t,k)
            report_system("table %a is obsolete, use %a",old,new)
            m.__index, m.__newindex = o, o
            return o[k]
        end
        m.__newindex = function(t,k,v)
            report_system("table %a is obsolete, use %a",old,new)
            m.__index, m.__newindex = o, o
            o[k] = v
        end
        if libraries then
            libraries.obsolete[old] = t -- true
        end
        setmetatable(t,m)
        return t
    end
end

if utilities then
    utilities.report = report_system
end

if tex and tex.error then
    function logs.texerrormessage(...) -- for the moment we put this function here
        tex.error(format(...), { })
    end
else
    function logs.texerrormessage(...)
        print(format(...))
    end
end

-- this is somewhat slower but prevents out-of-order messages when print is mixed
-- with texio.write

io.stdout:setvbuf('no')
io.stderr:setvbuf('no')

-- windows: > nul  2>&1
-- unix   : > null 2>&1

if package.helpers.report then
    package.helpers.report = logs.reporter("package loader") -- when used outside mtxrun
end
