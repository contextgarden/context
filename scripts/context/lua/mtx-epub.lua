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

local format, gsub = string.format, string.gsub
local concat = table.concat
local replace = utilities.templates.replace

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-epub</entry>
  <entry name="detail">ConTeXt EPUB Helpers</entry>
  <entry name="version">0.12</entry>
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
    banner   = "ConTeXt EPUB Helpers 0.12",
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

local t_package = [[
<?xml version="1.0" encoding="UTF-8"?>

<package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="%identifier%">

    <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
        <dc:title>%title%</dc:title>
        <dc:language>%language%</dc:language>
        <dc:identifier id="%identifier%" opf:scheme="UUID">urn:uuid:%uuid%</dc:identifier>
        <dc:creator>%creator%</dc:creator>
        <dc:date>%date%</dc:date>
        <meta name="cover" content="%firstpage%" />
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

local t_item = [[        <item id="%id%" href="%filename%" media-type="%mime%"/>]]

local t_toc = [[
<?xml version="1.0"?>

<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">

<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">

    <head>
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

local t_coverxhtml = [[
<?xml version="1.0" encoding="UTF-8"?>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <title>cover.xhtml</title>
    </head>
    <body>
        <div>
            <img src="%image%" alt="The cover image" style="max-width: 100%%;" />
        </div>
    </body>
</html>
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

    if filename and filename ~= "" and type(filename) == "string" then

        filename = file.basename(filename)
        local specfile = file.replacesuffix(filename,"specification")
        local specification = lfs.isfile(specfile) and dofile(specfile) or { }

        local name       = specification.name       or file.removesuffix(filename)
        local identifier = specification.identifier or os.uuid(true)
        local files      = specification.files      or { file.addsuffix(filename,"xhtml") }
        local images     = specification.images     or { }
        local root       = specification.root       or files[1]
        local language   = specification.language   or "en"
        local creator    = specification.author     or "My Self"
        local title      = specification.title      or "My Title"
        local firstpage  = specification.firstpage  or ""
        local lastpage   = specification.lastpage   or ""

     -- identifier = gsub(identifier,"[^a-zA-z0-9]","")

        if firstpage ~= "" then
            images[firstpage] = firstpage
        end
        if lastpage ~= "" then
            images[lastpage] = lastpage
        end

        identifier = "BookId" -- weird requirement

        local epubname   = name
        local epubpath   = file.replacesuffix(name,"tree")
        local epubfile   = file.replacesuffix(name,"epub")
        local epubroot   = file.replacesuffix(name,"opf")
        local epubtoc    = "toc.ncx"
        local epubcover  = "cover.xhtml"

        application.report("creating paths in tree %s",epubpath)
        lfs.mkdir(epubpath)
        lfs.mkdir(file.join(epubpath,"META-INF"))
        lfs.mkdir(file.join(epubpath,"OEBPS"))

        local used = { }

        local function copyone(filename)
            local suffix = file.suffix(filename)
            local mime = mimetypes[suffix]
            if mime then
                local idmaker = idmakers[suffix] or idmakers.default
                local target = file.join(epubpath,"OEBPS",filename)
                file.copy(filename,target)
                application.report("copying %s to %s",filename,target)
                used[#used+1] = replace(t_item, {
                    id       = idmaker(filename),
                    filename = filename,
                    mime     = mime,
                } )
            end
        end

        copyone("cover.xhtml")
        copyone("toc.ncx")

        local function copythem(files)
            for i=1,#files do
                local filename = files[i]
                if type(filename) == "string" then
                    copyone(filename)
                end
            end
        end

        copythem(files)

        local theimages = { }

        for k, v in table.sortedpairs(images) do
            theimages[#theimages+1] = k
            if not lfs.isfile(k) and file.suffix(k) == "svg" and file.suffix(v) == "pdf" then
                local command = format("inkscape --export-plain-svg=%s %s",k,v)
                application.report("running command '%s'\n\n",command)
                os.execute(command)
            end
        end

        copythem(theimages)

        local idmaker = idmakers[file.suffix(root)] or idmakers.default

        container = replace(t_container, {
            rootfile = epubroot
        } )
        package = replace(t_package, {
            identifier = identifier,
            title      = title,
            language   = language,
            uuid       = os.uuid(),
            creator    = creator,
            date       = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            firstpage  = idmaker(firstpage),
            manifest   = concat(used,"\n"),
            rootfile   = idmaker(root)
        } )
        toc = replace(t_toc, {
            identifier = identifier,
            title      = title,
            author     = author,
            root       = root,
        } )
        coverxhtml = replace(t_coverxhtml, {
            image      = firstpage
        } )

        io.savedata(file.join(epubpath,"mimetype"),mimetype)
        io.savedata(file.join(epubpath,"META-INF","container.xml"),container)
        io.savedata(file.join(epubpath,"OEBPS",epubroot),package)
        io.savedata(file.join(epubpath,"OEBPS",epubtoc),toc)
        io.savedata(file.join(epubpath,"OEBPS",epubcover),coverxhtml)

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

        if done then
            application.report("epub archive made using %s: %s",done,file.join(epubpath,epubfile))
        else
            local list = { }
            for i=1,#zippers do
                list[#list+1] = zipper.name
            end
            application.report("no epub archive made, install one of: %s",concat(list," "))
        end

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
