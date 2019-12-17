if not modules then modules = { } end modules ['mtx-modules'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- should be an extra

scripts         = scripts         or { }
scripts.modules = scripts.modules or { }

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-modules</entry>
  <entry name="detail">ConTeXt Module Documentation Generators</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="convert"><short>convert source files (tex, mkii, mkiv, mp, etc.) to 'ted' files</short></flag>
    <flag name="process"><short>process source files (tex, mkii, mkiv, mp, etc.) to 'pdf' files</short></flag>
    <flag name="prep"><short>use original name with suffix 'prep' appended</short></flag>
    <flag name="direct"><short>use old method instead of extra</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-modules",
    banner   = "ConTeXt Module Documentation Generators 1.00",
    helpinfo = helpinfo,
}

local report = application.report

-- Documentation can be woven into a source file. This script can generates
-- a file with the documentation and source fragments properly tagged. The
-- documentation is included as comment:
--
-- %D ......  some kind of documentation
-- %M ......  macros needed for documenation
-- %S B       begin skipping
-- %S E       end skipping
--
-- The generated file is structured as:
--
-- \starttypen
-- \startmodule[type=suffix]
-- \startdocumentation
-- \stopdocumentation
-- \startdefinition
-- \stopdefinition
-- \stopmodule
-- \stoptypen
--
-- Macro definitions specific to the documentation are not surrounded by
-- start-stop commands. The suffix specification can be overruled at runtime,
-- but defaults to the file extension. This specification can be used for language
-- depended verbatim typesetting.
--
-- In the mkiv variant we filter the \module settings so that we don't have
-- to mess with global document settings.

local find, format, sub, is_empty, strip, gsub = string.find, string.format, string.sub, string.is_empty, string.strip, string.gsub

local function source_to_ted(inpname,outname,filetype)
    local data = io.loaddata(inpname)
    if not data or data == "" then
        report("invalid module name '%s'",inpname)
        return
    end
    report("converting '%s' to '%s'",inpname,outname)
    local skiplevel, indocument, indefinition = 0, false, false
    local started = false
    local settings = format("type=%s",filetype or file.suffix(inpname))
    local preamble, n = lpeg.match(lpeg.Cs((1-lpeg.patterns.newline^2)^1) * lpeg.Cp(),data)
    if preamble then
        preamble = string.match(preamble,"\\module.-%[(.-)%]")
        if preamble then
            preamble = gsub(preamble,"%%D *","")
            preamble = gsub(preamble,"%%(.-)[\n\r]","")
            preamble = gsub(preamble,"[\n\r]","")
            preamble = strip(preamble)
            settings = format("%s,%s",settings,preamble)
            data = string.sub(data,n,#data)
        end
    end
    local lines = string.splitlines(data)
    local result = { }
    result[#result+1] = format("\\startmoduledocumentation[%s]",settings)
    for i=1,#lines do
        local line = lines[i]
        if find(line,"^%%D ") or find(line,"^%%D$") then
            if skiplevel == 0 then
                local someline = #line < 3 and "" or sub(line,4,#line)
                if indocument then
                    result[#result+1] = someline
                else
                    if indefinition then
                        result[#result+1] = "\\stopdefinition"
                        indefinition = false
                    end
                    if not indocument then
                        result[#result+1] = "\\startdocumentation"
                    end
                    result[#result+1] = someline
                    indocument = true
                end
            end
        elseif find(line,"^%%M ") or find(line,"^%%M$") then
            if skiplevel == 0 then
                local someline = (#line < 3 and "") or sub(line,4,#line)
                result[#result+1] = someline
            end
        elseif find(line,"^%%S B") then
            skiplevel = skiplevel + 1
        elseif find(line,"^%%S E") then
            skiplevel = skiplevel - 1
        elseif find(line,"^%%") then
            -- nothing
        elseif skiplevel == 0 then
            inlocaldocument = indocument
            inlocaldocument = false
            local someline = line
            if indocument then
                result[#result+1] = "\\stopdocumentation"
                indocument = false
            end
            if indefinition then
                if is_empty(someline) then
                    result[#result+1] = "\\stopdefinition"
                    indefinition = false
                else
                    result[#result+1] = someline
                end
            elseif not is_empty(someline) then
                result[#result+1] = "\n"
                result[#result+1] = "\\startdefinition"
                indefinition = true
                if inlocaldocument then
                    -- nothing
                else
                    result[#result+1] = someline
                end
            end
        end
    end
    if indocument then
        result[#result+1] = "\\stopdocumentation"
    end
    if indefinition then
        result[#result+1] = "\\stopdefinition"
    end
    result[#result+1] = "\\stopmoduledocumentation"
    io.savedata(outname,table.concat(result,"\n"))
    return true
end

local suffixes = table.tohash {
    "tex",
    "mkii",
    "mkiv", "mkvi", "mkil", "mkli",
    "mp", "mpii", "mpiv",
}

function scripts.modules.process(runtex)
    local processed = { }
    local files     = environment.files
    if environment.arguments.direct then
        local prep = environment.argument("prep")
        for i=1,#files do
            local shortname = files[i]
            local suffix    = file.suffix(shortname)
            if suffixes[suffix] then
                local longname
                if prep then
                    longname = shortname .. ".prep"
                else
                    longname = file.removesuffix(shortname) .. "-" .. suffix .. ".ted"
                end
                local done = source_to_ted(shortname,longname)
                if done and runtex then
                    local command = format("mtxrun --script context --usemodule=module-basic --purge %s",longname)
                    report()
                    report("running: %s",command)
                    report()
                    os.execute(command)
                    processed[#processed+1] = longname
                end
            end
        end
    else
        for i=1,#files do
            local name    = files[i]
            local only    = file.nameonly(name)
            local command = format("mtxrun --script context --extra=module --result=%s %s",only,name)
            report()
            report("running: %s",command)
            report()
            os.execute(command)
            processed[#processed+1] = command
        end
    end
    if #processed > 0 then
        report()
        for i=1,#processed do
            report("processed: %s",processed[i])
        end
    end
end

--  context --ctx=m-modules.ctx xxx.mkiv

if environment.argument("process") then
    scripts.modules.process(true)
elseif environment.argument("convert") then
    scripts.modules.process(false)
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
