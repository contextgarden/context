if not modules then modules = { } end modules ['trac-xml'] = {
    version   = 1.001,
    comment   = "companion to trac-log.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Application helpinfo can be defined in several ways:
--
-- helpinfo = "big blob of help"
--
-- helpinfo = { basic = "blob of basic help", extra = "blob of extra help" }
--
-- helpinfo = "<?xml version=1.0?><application>...</application/>"
--
-- helpinfo = "somefile.xml"
--
-- In the case of an xml file, the file should be either present on the same path
-- as the script, or we should be be able to locate it using the resolver.

local formatters   = string.formatters
local reporters    = logs.reporters
local xmlserialize = xml.serialize
local xmlcollected = xml.collected
local xmltext      = xml.text
local xmlfirst     = xml.first

-- there is no need for a newhandlers { name = "help", parent = "string" }

local function showhelp(specification,...)
    local root = xml.convert(specification.helpinfo or "")
    if not root then
        return
    end
    local xs = xml.gethandlers("string")
    xml.sethandlersfunction(xs,"short",function(e,handler) xmlserialize(e.dt,handler) end)
    xml.sethandlersfunction(xs,"ref",  function(e,handler) handler.handle("--"..e.at.name) end)
    local wantedcategories = select("#",...) == 0 and true or table.tohash { ... }
    local nofcategories = xml.count(root,"/application/flags/category")
    local report = specification.report
    for category in xmlcollected(root,"/application/flags/category") do
        local categoryname = category.at.name or ""
        if wantedcategories == true or wantedcategories[categoryname] then
            if nofcategories > 1 then
                report("%s options:",categoryname)
                report()
            end
            for subcategory in xmlcollected(category,"/subcategory") do
                for flag in xmlcollected(subcategory,"/flag") do
                    local name  = flag.at.name
                    local value = flag.at.value
                 -- local short = xmlfirst(s,"/short")
                 -- local short = xmlserialize(short,xs)
                    local short = xmltext(xmlfirst(flag,"/short"))
                    if value then
                        report("--%-20s %s",formatters["%s=%s"](name,value),short)
                    else
                        report("--%-20s %s",name,short)
                    end
                end
                report()
            end
        end
    end
    for category in xmlcollected(root,"/application/examples/category") do
        local title = xmltext(xmlfirst(category,"/title"))
        if title and title ~= "" then
            report()
            report(title)
            report()
        end
        for subcategory in xmlcollected(category,"/subcategory") do
            for example in xmlcollected(subcategory,"/example") do
                local command = xmltext(xmlfirst(example,"/command"))
                local comment = xmltext(xmlfirst(example,"/comment"))
                report(command)
            end
            report()
        end
    end
    for comment in xmlcollected(root,"/application/comments/comment") do
        local comment = xmltext(comment)
        report()
        report(comment)
        report()
    end
end

local reporthelp = reporters.help
local exporthelp = reporters.export

local function xmlfound(t)
    local helpinfo = t.helpinfo
    if type(helpinfo) == "table" then
        return false
    end
    if type(helpinfo) ~= "string" then
        helpinfo = "Warning: no helpinfo found."
        t.helpinfo = helpinfo
        return false
    end
    if string.find(helpinfo,".xml$") then
        local ownscript = environment.ownscript
        local helpdata  = false
        if ownscript then
            local helpfile = file.join(file.pathpart(ownscript),helpinfo)
            helpdata = io.loaddata(helpfile)
            if helpdata == "" then
                helpdata = false
            end
        end
        if not helpdata then
            local helpfile = resolvers.findfile(helpinfo,"tex")
            helpdata = helpfile and io.loaddata(helpfile)
        end
        if helpdata and helpdata ~= "" then
            helpinfo = helpdata
        else
            helpinfo = formatters["Warning: help file %a is not found."](helpinfo)
        end
    end
    t.helpinfo = helpinfo
    return string.find(t.helpinfo,"^<%?xml") and true or false
end

function reporters.help(t,...)
    if xmlfound(t) then
        showhelp(t,...)
    else
        reporthelp(t,...)
    end
end

function reporters.export(t,methods,filename)
    if not xmlfound(t) then
        return exporthelp(t)
    end
    if not methods or methods == "" then
        methods = environment.arguments["exporthelp"]
    end
    if not filename or filename == "" then
        filename = environment.files[1]
    end
    dofile(resolvers.findfile("trac-exp.lua","tex"))
    local exporters = logs.exporters
    if not exporters or not methods then
        return exporthelp(t)
    end
    if methods == "all" then
        methods = table.keys(exporters)
    elseif type(methods) == "string" then
        methods = utilities.parsers.settings_to_array(methods)
    else
        return exporthelp(t)
    end
    if type(filename) ~= "string" or filename == "" then
        filename = false
    elseif file.pathpart(filename) == "" then
        t.report("export file %a will not be saved on the current path (safeguard)",filename)
        return
    end
    for i=1,#methods do
        local method = methods[i]
        local exporter = exporters[method]
        if exporter then
            local result = exporter(t,method)
            if result and result ~= "" then
                if filename then
                    local fullname = file.replacesuffix(filename,method)
                    t.report("saving export in %a",fullname)
                    dir.mkdirs(file.pathpart(fullname))
                    io.savedata(fullname,result)
                else
                    reporters.lines(t,result)
                end
            else
                t.report("no output from exporter %a",method)
            end
        else
            t.report("unknown exporter %a",method)
        end
    end
end
