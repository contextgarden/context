if not modules then modules = { } end modules ['mtx-epub'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The epub specification is far from beautiful. Especially the id related
-- part is messy and devices/programs react differently on them (so an id is not
-- really an id but has some special property). Then there is this ncx suffix
-- thing. Somehow it give the impression of a reversed engineered application
-- format so it will probably take a few cycles to let it become a real
-- clean standard. Thanks to Adam Reviczky, Luigi Scarso and Andy Thomas for
-- helping to figure out all the puzzling details.

-- This is preliminary code. At some point we will deal with images as well but
-- first we need a decent strategy to export them. More information will be
-- available on the wiki.

-- META-INF
--     container.xml
-- OEBPS
--     content.opf
--     toc.ncx
--     Images
--     Styles
--     Text
-- mimetype

local format, gsub, find = string.format, string.gsub, string.find
local concat = table.concat
local replace = utilities.templates.replace

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-epub</entry>
  <entry name="detail">ConTeXt EPUB Helpers</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="make"><short>create epub zip file</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Example</title>
   <subcategory>
    <example><command>mtxrun --script epub --make mydocument</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-epub",
    banner   = "ConTeXt EPUB Helpers 1.00",
    helpinfo = helpinfo,
}

-- script code

scripts      = scripts      or { }
scripts.epub = scripts.epub or { }

local mimetype = "application/epub+zip"

local t_container = [[
<?xml version="1.0" encoding="UTF-8"?>

<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
    <rootfiles>
        <rootfile full-path="OEBPS/%rootfile%" media-type="application/oebps-package+xml"/>
    </rootfiles>
</container>
]]

-- urn:uuid:

-- <dc:identifier id="%identifier%" opf:scheme="UUID">%uuid%</dc:identifier>

local t_package = [[
<?xml version="1.0" encoding="UTF-8"?>

<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="%identifier%" version="3.0">

    <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
        <dc:title>%title%</dc:title>
        <dc:language>%language%</dc:language>
        <dc:identifier id="%identifier%">%uuid%</dc:identifier>
        <dc:creator>%creator%</dc:creator>
        <dc:date>%date%</dc:date>
        <!--
            <dc:subject>%subject%</dc:subject>
            <dc:description>%description%</dc:description>
            <dc:publisher>%publisher%</dc:publisher>
            <dc:source>%source%</dc:source>
            <dc:relation>%relation%</dc:relation>
            <dc:coverage>%coverage%</dc:coverage>
            <dc:rights>%rights%</dc:rights>
        -->
        <meta name="cover" content="%firstpage%" />
        <meta name="generator" content="ConTeXt MkIV" />
        <meta property="dcterms:modified">%date%</meta>
    </metadata>

    <manifest>
%manifest%
    </manifest>

    <spine toc="ncx">
        <itemref idref="cover-xhtml" />
        <itemref idref="%rootfile%" />
    </spine>

</package>
]]

local t_item = [[        <item id="%id%" href="%filename%" media-type="%mime%" />]]
local t_nav  = [[        <item id="%id%" href="%filename%" media-type="%mime%" properties="%properties%" />]]

-- <!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">

local t_toc = [[
<?xml version="1.0" encoding="UTF-8"?>

<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">

    <head>
        <meta charset="utf-8" />

        <meta name="generator"         content="ConTeXt MkIV" />
        <meta name="dtb:uid"           content="%identifier%" />
        <meta name="dtb:depth"         content="2" />
        <meta name="dtb:totalPgeCount" content="0" />
        <meta name="dtb:maxPageNumber" content="0" />
    </head>

    <docTitle>
        <text>%title%</text>
    </docTitle>

    <docAuthor>
        <text>%author%</text>
    </docAuthor>

    <navMap>
        <navPoint id="np-1" playOrder="1">
            <navLabel>
                <text>start</text>
            </navLabel>
            <content src="%root%"/>
        </navPoint>
    </navMap>

</ncx>
]]

local t_navtoc = [[
<?xml version="1.0" encoding="UTF-8"?>

<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
    <head>
        <meta charset="utf-8" />
        <title>navtoc</title>
    </head>
    <body>
        <div class="navtoc">
            <!-- <nav epub:type="lot"> -->
            <nav epub:type="toc" id="navtoc">
                <ol>
                    <li><a href="%root%">document</a></li>
                </ol>
            </nav>
        </div>
    </body>
</html>
]]

-- <html xmlns="http://www.w3.org/1999/xhtml">
-- <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

local t_coverxhtml = [[
<?xml version="1.0" encoding="UTF-8"?>

<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta charset="utf-8" />
        <title>cover page</title>
    </head>
    <body>
        <div class="coverpage">
            %content%
        </div>
    </body>
</html>
]]

local t_coverimg = [[
    <img src="%image%" alt="The cover image" style="max-width: 100%%;" />
]]

-- We need to figure out what is permitted. Numbers only seem to give
-- problems is some applications as do names with dashes. Also the
-- optional toc is supposed to be there and although id's are by
-- concept neutral, there are sometimes hard requirements with respect
-- to their name like ncx and toc.ncx). Maybe we should stick to 3.0
-- only.

local function dumbid(filename)
 -- return (string.gsub(os.uuid(),"%-%","")) -- to be tested
    return file.nameonly(filename) .. "-" .. file.suffix(filename)
end

local mimetypes = {
    xhtml   = "application/xhtml+xml",
    xml     = "application/xhtml+xml",
    html    = "application/html",
    css     = "text/css",
    svg     = "image/svg+xml",
    png     = "image/png",
    jpg     = "image/jpeg",
    ncx     = "application/x-dtbncx+xml",
    gif     = "image/gif",
 -- default = "text/plain",
}

local idmakers = {
    ncx     = function(filename) return "ncx"            end,
 -- css     = function(filename) return "stylesheet"     end,
    default = function(filename) return dumbid(filename) end,
}

-- specification = {
--     name = "document",
--     identifier = "123",
--     root = "a.xhtml",
--     files = {
--         "a.xhtml",
--         "b.css",
--         "c.png",
--     }
-- }

local function locateimages(oldname,newname,subpath)
    local data = io.loaddata(oldname)
    local images = { }
    local done = gsub(data,"(background%-image *: * url%()(.-)(%))", function(before,name,after)
        if subpath then
            name = file.join(subpath,name)
        end
        images[#images+1] = name
        return before .. name .. after
    end)
    if newname then
        io.savedata(done,newname)
    end
    return images
end

local zippers = {
    {
        name         = "zip",
        uncompressed = "zip %s -X -0 %s",
        compressed   = "zip %s -X -9 -r %s",
    },
    {
        name         = "7zip (7z)",
        uncompressed = "7z a -tzip -mx0 %s %s",
        compressed   = "7z a -tzip %s %s",
    },
}

function scripts.epub.make()

    local filename = environment.files[1]

    if not filename or filename == "" or type(filename) ~= "string" then
        application.report("provide filename")
        return
    end

    filename = file.basename(filename)

    local specfile = file.replacesuffix(filename,"specification")

    if not lfs.isfile(specfile) then
        application.report("unknown specificaton file %a",specfile)
        return
    end

    local specification = dofile(specfile)

    if not specification or not next(specification) then
        application.report("invalid specificaton file %a",specfile)
        return
    end

    local name       = specification.name       or file.removesuffix(filename)
    local identifier = specification.identifier or ""
    local files      = specification.files      or { file.addsuffix(filename,"xhtml") }
    local images     = specification.images     or { }
    local root       = specification.root       or files[1]
    local language   = specification.language   or "en"
    local creator    = specification.author     or "context"
    local title      = specification.title      or name
    local firstpage  = specification.firstpage  or ""
    local lastpage   = specification.lastpage   or ""

 -- identifier = gsub(identifier,"[^a-zA-z0-9]","")

    if firstpage == "" then
     -- firstpage = "firstpage.jpg" -- dummy
    else
        images[firstpage] = firstpage
    end
    if lastpage == "" then
     -- lastpage = "lastpage.jpg" -- dummy
    else
        images[lastpage] = lastpage
    end

    local uuid = format("urn:uuid:%s",os.uuid(true)) -- os.uuid()

    identifier = "bookid" -- for now

    local epubname   = name
    local epubpath   = file.replacesuffix(name,"tree")
    local epubfile   = file.replacesuffix(name,"epub")
    local epubroot   = file.replacesuffix(name,"opf")
    local epubtoc    = "toc.ncx"
    local epubcover  = "cover.xhtml"

    application.report("creating paths in tree %a",epubpath)
    lfs.mkdir(epubpath)
    lfs.mkdir(file.join(epubpath,"META-INF"))
    lfs.mkdir(file.join(epubpath,"OEBPS"))

    local used = { }

    local function registerone(filename)
        local suffix = file.suffix(filename)
        local mime = mimetypes[suffix]
        if mime then
            local idmaker = idmakers[suffix] or idmakers.default
            used[#used+1] = replace(t_item, {
                id         = idmaker(filename),
                filename   = filename,
                mime       = mime,
            } )
            return true
        end
    end

    local function copyone(filename,alternative)
        if registerone(filename) then
            local target = file.join(epubpath,"OEBPS",file.basename(filename))
            local source = alternative or filename
            file.copy(source,target)
            application.report("copying %a to %a",source,target)
        end
    end

    if lfs.isfile(epubcover) then
        copyone(epubcover)
        epubcover = false
    else
        registerone(epubcover)
    end

    copyone("toc.ncx")

    local function copythem(files)
        for i=1,#files do
            local filename = files[i]
            if type(filename) == "string" then
                local suffix = file.suffix(filename)
                if suffix == "xhtml" then
                    local alternative = file.replacesuffix(filename,"html")
                    if lfs.isfile(alternative) then
                        copyone(filename,alternative)
                    else
                        copyone(filename)
                    end
                elseif suffix == "css" then
                    if filename == "export-example.css" then
                        if lfs.isfile(filename) then
                            os.remove(filename)
                            local original = resolvers.findfile(filename)
                            application.report("updating local copy of %a from %a",filename,original)
                            file.copy(original,filename)
                        else
                            filename = resolvers.findfile(filename)
                        end
                    elseif not lfs.isfile(filename) then
                        filename = resolvers.findfile(filename)
                    else
                        -- use specific local one
                    end
                    copyone(filename)
                else
                    copyone(filename)
                end
            end
        end
    end

    copythem(files)

    local theimages = { }

    for k, v in table.sortedpairs(images) do
        theimages[#theimages+1] = k
        if not lfs.isfile(k) and file.suffix(k) == "svg" and file.suffix(v) == "pdf" then
            local command = format("inkscape --export-plain-svg=%s %s",k,v)
            application.report("running command %a\n\n",command)
            os.execute(command)
        end
    end

    used[#used+1] = replace(t_nav, {
        id         = "nav",
        filename   = "nav.xhtml",
        properties = "nav",
        mime       = "application/xhtml+xml",
    })

    io.savedata(file.join(epubpath,"OEBPS","nav.xhtml"),replace(t_navtoc, { -- version 3.0
        root = root,
    } ) )

    copythem(theimages)

    local idmaker = idmakers[file.suffix(root)] or idmakers.default

    io.savedata(file.join(epubpath,"mimetype"),mimetype)

    io.savedata(file.join(epubpath,"META-INF","container.xml"),replace(t_container, { -- version 2.0
        rootfile = epubroot
    } ) )

    io.savedata(file.join(epubpath,"OEBPS",epubroot),replace(t_package, {
        identifier = identifier,
        title      = title,
        language   = language,
        uuid       = uuid,
        creator    = creator,
        date       = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        firstpage  = idmaker(firstpage),
        manifest   = concat(used,"\n"),
        rootfile   = idmaker(root)
    } ) )

    -- t_toc is replaced by t_navtoc in >= 3

    io.savedata(file.join(epubpath,"OEBPS",epubtoc), replace(t_toc, {
        identifier = uuid, -- identifier,
        title      = title,
        author     = author,
        root       = root,
    } ) )

    if epubcover then

        io.savedata(file.join(epubpath,"OEBPS",epubcover), replace(t_coverxhtml, {
            content = firstpage ~= "" and replace(t_coverimg, { image = firstpage }) or "no cover page defined",
        } ) )

    end

    application.report("creating archive\n\n")

    lfs.chdir(epubpath)
    os.remove(epubfile)

    local done = false

    for i=1,#zippers do
        local zipper = zippers[i]
        if os.execute(format(zipper.uncompressed,epubfile,"mimetype")) then
            os.execute(format(zipper.compressed,epubfile,"META-INF"))
            os.execute(format(zipper.compressed,epubfile,"OEBPS"))
            done = zipper.name
            break
        end
    end

    lfs.chdir("..")

    local treefile = file.join(epubpath,epubfile)

    os.remove(epubfile)
    file.copy(treefile,epubfile)
    if lfs.isfile(epubfile) then
        os.remove(treefile)
    end

    if done then
        application.report("epub archive made using %s: %s",done,epubfile)
    else
        local list = { }
        for i=1,#zippers do
            list[#list+1] = zipper.name
        end
        application.report("no epub archive made, install one of: %s",concat(list," "))
    end

end

--

if environment.argument("make") then
    scripts.epub.make()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end

-- java -jar d:\epubcheck\epubcheck-3.0.1.jar -v 3.0 -mode xhtml mkiv-publications.tree\mkiv-publications.epub
