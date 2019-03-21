if not modules then modules = { } end modules ['mtx-tools'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local find, format, sub, rep, gsub, lower = string.find, string.format, string.sub, string.rep, string.gsub, string.lower

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-tools</entry>
  <entry name="detail">Some File Related Goodies</entry>
  <entry name="version">1.01</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="disarmutfbomb"><short>remove utf bomb if present</short></flag>
    <flag name="force"><short>remove indeed</short></flag>
   </subcategory>
   <subcategory>
    <flag name="dirtoxml"><short>glob directory into xml</short></flag>
    <flag name="pattern"><short>glob pattern (default: *)</short></flag>
    <flag name="url"><short>url attribute (no processing)</short></flag>
    <flag name="root"><short>the root of the globbed path (default: .)</short></flag>
    <flag name="output"><short>output filename (console by default)</short></flag>
    <flag name="recurse"><short>recurse into subdirecories</short></flag>
    <flag name="stripname"><short>take pathpart of given pattern</short></flag>
    <flag name="longname"><short>set name attributes to full path name</short></flag>
    <flag name="downcase"><short>lowercase names</short></flag>
   </subcategory>
   <subcategory>
    <flag name="showstring"><short>show unicode characters in given string</short></flag>
    <flag name="showfile"><short>show unicode characters in given file</short></flag>
   </subcategory>
   <subcategory>
    <flag name="pattern"><short>glob pattern (default: *)</short></flag>
    <flag name="recurse"><short>recurse into subdirecories</short></flag>
    <flag name="force"><short>downcase indeed</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-tools",
    banner   = "Some File Related Goodies 1.01",
    helpinfo = helpinfo,
}

local report  = application.report
local writeln = (logs and logs.writer) or (texio and texio.write_nl) or print

scripts       = scripts       or { }
scripts.tools = scripts.tools or { }

local bomb_1, bomb_2 = "^\254\255", "^\239\187\191"

function scripts.tools.disarmutfbomb()
    local force, done = environment.argument("force"), false
    local files = environment.files
    for i=1,#files do
        local name = files[i]
        if lfs.isfile(name) then
            local data = io.loaddata(name)
            if not data then
                -- just skip
            elseif find(data,bomb_1) then
                report("file '%s' has a 2 character utf bomb",name)
                if force then
                    io.savedata(name,(gsub(data,bomb_1,"")))
                end
                done = true
            elseif find(data,bomb_2) then
                report("file '%s' has a 3 character utf bomb",name)
                if force then
                    io.savedata(name,(gsub(data,bomb_2,"")))
                end
                done = true
            else
            --  report("file '%s' has no utf bomb",name)
            end
        end
    end
    if done and not force then
        report("use --force to do a real disarming")
    end
end

function scripts.tools.downcase()
    local pattern = environment.argument('pattern') or "*"
    local recurse = environment.argument('recurse')
    local force   = environment.argument('force')
    local n = 0
    if recurse and not find(pattern,"^%*%*%/") then
        pattern = "**/*" .. pattern
    end
    dir.glob(pattern,function(name)
        local basename = file.basename(name)
        if lower(basename) ~= basename then
            n = n + 1
            local low = lower(name)
            if n == 1 then
                report()
            end
            report("%a renamed to %a",name,low)
            if force then
                os.rename(name,low)
            end
        end
    end)
    if n > 0 then
        report()
        if force then
            report("%s files renamed",n)
        else
            report("use --force to do a real rename (%s files involved)",n)
        end
    else
        report("nothing to do")
    end
end

function scripts.tools.dirtoxml()

    local join, removesuffix, suffixonly, date = file.join, file.removesuffix, file.suffixonly, os.date

    local xmlns      = "http://www.pragma-ade.com/rlg/xmldir.rng"
    local timestamp  = "%Y-%m-%d %H:%M"

    local pattern    = environment.argument('pattern') or ".*"
    local url        = environment.argument('url')     or "no-url"
    local root       = environment.argument('root')    or "."
    local outputfile = environment.argument('output')

    local recurse    = environment.argument('recurse') or false
    local stripname  = environment.argument('stripname')
    local longname   = environment.argument('longname')

    local function flush(list,result,n,path)
        n, result = n or 1, result or { }
        local d = rep("  ",n)
        for name, attr in table.sortedhash(list) do
            local mode = attr.mode
            if mode == "file" then
                result[#result+1] = format("%s<file name='%s'>",d,(longname and path and join(path,name)) or name)
                result[#result+1] = format("%s  <base>%s</base>",d,removesuffix(name))
                result[#result+1] = format("%s  <type>%s</type>",d,suffixonly(name))
                result[#result+1] = format("%s  <size>%s</size>",d,attr.size)
                result[#result+1] = format("%s  <permissions>%s</permissions>",d,sub(attr.permissions,7,9))
                result[#result+1] = format("%s  <date>%s</date>",d,date(timestamp,attr.modification))
                result[#result+1] = format("%s</file>",d)
            elseif mode == "directory" then
                result[#result+1] = format("%s<directory name='%s'>",d,name)
                flush(attr.list,result,n+1,(path and join(path,name)) or name)
                result[#result+1] = format("%s</directory>",d)
            end
        end
    end

    if not pattern or pattern == ""  then
        report('provide --pattern=')
        return
    end

    if stripname then
        pattern = file.dirname(pattern)
    end

    local luapattern = string.topattern(pattern,true)

    lfs.chdir(root)

    local list = dir.collectpattern(root,luapattern,recurse)

    if list[outputfile] then
        list[outputfile] = nil
    end

    local result = { "<?xml version='1.0'?>" }
    result[#result+1] = format("<files url=%q root=%q pattern=%q luapattern=%q xmlns='%s' timestamp='%s'>",url,root,pattern,luapattern,xmlns,date(timestamp))
    flush(list,result)
    result[#result+1] = "</files>"

    result = table.concat(result,"\n")

    if not outputfile or outputfile == "" then
        writeln(result)
    else
        io.savedata(outputfile,result)
    end

end

local function showstring(s)
    if not characters or not characters.data then
        require("char-def")
    end
    local d = characters.data
    local f = string.formatters["%U  %s  %-30s  %c"]
    for c in string.utfvalues(s) do
        local cs = d[c]
        print(f(c,cs.category or "",cs.description or "",c))
    end
end

function scripts.tools.showstring()
    local files = environment.files
    for i=1,#files do
        showstring(files[i])
    end
end

function scripts.tools.showfile()
    local files = environment.files
    for i=1,#files do
        showstring(io.loaddata(files[i]) or "")
    end
end

if environment.argument("disarmutfbomb") then
    scripts.tools.disarmutfbomb()
elseif environment.argument("dirtoxml") then
    scripts.tools.dirtoxml()
elseif environment.argument("downcase") then
    scripts.tools.downcase()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
elseif environment.argument("showstring") then
    scripts.tools.showstring()
elseif environment.argument("showfile") then
    scripts.tools.showfile()
else
    application.help()
end
