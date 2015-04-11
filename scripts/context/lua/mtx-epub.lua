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
--     images
--     styles
-- mimetype

-- todo:
--
-- remove m_k_v_i prefixes
-- remap fonts %mono% in css so that we can replace
-- coverpage tests
-- split up

-- todo: automated cover page:
--
-- \startMPpage
--     StartPage ;
--         fill Page withcolor .5red ;
--         numeric n ;
--         for i=10 downto 1 :
--             n := i * PaperWidth/40  ;
--             draw
--                 lrcorner Page shifted (0,n)
--               % -- lrcorner Page
--                 -- lrcorner Page shifted (-n,0)
--               % -- cycle
--                 withpen pencircle scaled 1mm
--                 withcolor white ;
--         endfor ;
--         picture p ; p := image (
--             draw
--                 anchored.top(
--                     textext.bot("\tttf Some Title")
--                         xsized .8PaperWidth
--                    ,center topboundary Page
--                 )
--                     withcolor white ;
--         ) ;
--         picture q ; q := image (
--             draw
--                 anchored.top(
--                     textext.bot("\tttf An Author")
--                         xsized .4PaperWidth
--                         shifted (0,-PaperHeight/40)
--                    ,center bottomboundary p
--                 )
--                     withcolor white ;
--         ) ;
--         draw p ;
--         draw q ;
--     StopPage ;
-- \stopMPpage

local format, gsub, find = string.format, string.gsub, string.find
local concat, sortedhash = table.concat, table.sortedhash

local formatters      = string.formatters
local replacetemplate = utilities.templates.replace

local addsuffix       = file.addsuffix
local nameonly        = file.nameonly
local basename        = file.basename
local pathpart        = file.pathpart
local joinfile        = file.join
local suffix          = file.suffix
local addsuffix       = file.addsuffix
local removesuffix    = file.removesuffix
local replacesuffix   = file.replacesuffix

local copyfile        = file.copy
local removefile      = os.remove

local needsupdating   = file.needsupdating

local isdir           = lfs.isdir
local isfile          = lfs.isfile
local mkdir           = lfs.mkdir

local pushdir         = dir.push
local popdir          = dir.pop

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-epub</entry>
  <entry name="detail">ConTeXt EPUB Helpers</entry>
  <entry name="version">1.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="make"><short>create epub zip file</short></flag>
    <flag name="purge"><short>remove obsolete files</short></flag>
    <flag name="rename"><short>rename images to sane names</short></flag>
    <flag name="svgmath"><short>convert mathml to svg</short></flag>
    <flag name="svgstyle"><short>use given tex style for svg generation (overloads style in specification)</short></flag>
    <flag name="all"><short>assume: --purge --rename --svgmath (for fast testing)</short></flag>
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
    banner   = "ConTeXt EPUB Helpers 1.10",
    helpinfo = helpinfo,
}

local report = application.report

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
        <meta name="cover" content="%coverpage%" />
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
local t_prop = [[        <item id="%id%" href="%filename%" media-type="%mime%" properties="%properties%" />]]

-- <!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">

local t_toc = [[
<?xml version="1.0" encoding="UTF-8"?>

<!-- this is no longer needed in epub 3.0+ -->

<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">

    <head>
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
    return nameonly(filename) .. "-" .. suffix(filename)
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

local function relocateimages(imagedata,oldname,newname,subpath,rename)
    local data = io.loaddata(oldname)
    if data then
        subpath = joinfile("..",subpath)
        report("relocating images")
        local n = 0
        local done = gsub(data,[[(id=")(.-)(".-background%-image *: *url%()(.-)(%))]], function(s1,id,s2,name,s3)
            local data = imagedata[id]
            if data then
                local newname = data[id].newname
                if newname then
                    if subpath then
                        name = joinfile(subpath,basename(newname))
                    else
                        name = basename(newname)
                    end
                 -- name = url.addscheme(name)
                end
                if newname then
                    n = n + 1
                    if rename then
                        name = joinfile(subpath,addsuffix(id,suffix(name)))
                    end
                    return s1 .. id .. s2 .. name .. s3
                end
            end
        end)
        report("%s images relocated in %a",n,newname)
        if newname then
            io.savedata(newname,done)
        end
    end
    return images
end

function reportobsolete(oldfiles,newfiles,purge)

    for i=1,#oldfiles do oldfiles[i] = gsub(oldfiles[i],"^[%./]+","") end
    for i=1,#newfiles do newfiles[i] = gsub(newfiles[i],"^[%./]+","") end

    local old  = table.tohash(oldfiles)
    local new  = table.tohash(newfiles)
    local done = false

    for name in sortedhash(old) do
        if not new[name] then
            if not done then
                report()
                if purge then
                    report("removing obsolete files:")
                else
                    report("obsolete files:")
                end
                report()
                done = true
            end
            report("    %s",name)
            if purge then
                removefile(name)
            end
        end
    end

    if done then
        report()
    end

    return done

end


local zippers = {
    {
        name         = "zip",
        binary       = "zip",
        uncompressed = "zip %s -X -0 %s",
        compressed   = "zip %s -X -9 -r %s",
    },
    {
        name         = "7z (7zip)",
        binary       = "7z",
        uncompressed = "7z a -tzip -mx0 %s %s",
        compressed   = "7z a -tzip %s %s",
    },
}

function scripts.epub.make(purge,rename,svgmath,svgstyle)

    -- one can enter a jobname or jobname-export but the simple jobname is
    -- preferred

    local filename = environment.files[1]

    if not filename or filename == "" or type(filename) ~= "string" then
        report("provide filename")
        return
    end

    local specpath, specname, specfull

    if isdir(filename) then
        specpath = filename
        specname = addsuffix(specpath,"lua")
        specfull = joinfile(specpath,specname)
    end

    if not specfull or not isfile(specfull) then
        specpath = filename .. "-export"
        specname = addsuffix(filename .. "-pub","lua")
        specfull = joinfile(specpath,specname)
    end

    if not specfull or not isfile(specfull) then
        report("unknown specificaton file %a for %a",specfull or "?",filename)
        return
    end

    local specification = dofile(specfull)

    if not specification or not next(specification) then
        report("invalid specificaton file %a",specfile)
        return
    end

    report("using specification file %a",specfull)

    -- images: { ... url = location ... }

    local defaultcoverpage = "cover.xhtml"

    local name       = specification.name       or nameonly(filename)
    local identifier = specification.identifier or ""
    local htmlfiles  = specification.htmlfiles  or { }
    local styles     = specification.styles     or { }
    local images     = specification.images     or { }
    local htmlroot   = specification.htmlroot   or htmlfiles[1] or ""
    local language   = specification.language   or "en"
    local creator    = specification.creator    or "context mkiv"
    local author     = specification.author     or "anonymous"
    local title      = specification.title      or name
    local subtitle   = specification.subtitle   or ""
    local imagefile  = specification.imagefile  or ""
    local imagepath  = specification.imagepath  or "images"
    local stylepath  = specification.stylepath  or "styles"
    local coverpage  = specification.firstpage  or defaultcoverpage

    if type(svgstyle) == "string" and not svgstyle then
        svgstyle = specification.svgstyle or ""
    end

    local obsolete   = false

    if #htmlfiles == 0 then
        report("no html files specified")
        return
    end
    if htmlroot == "" then
        report("no html root file specified")
        return
    end

    if subtitle ~= "" then
        title = format("%s, %s",title,subtitle)
    end

    local htmlsource  = specpath
    local imagesource = joinfile(specpath,imagepath)
    local stylesource = joinfile(specpath,stylepath)

    -- once we're here we can start moving files to the right spot; first we deal
    -- with images

    -- ["image-1"]={
    --     height = "7.056cm",
    --     name   = "file:///t:/sources/cow.svg",
    --     page   = "1",
    --     width  = "9.701cm",
    -- }

    -- end of todo

    local pdftosvg   = os.which("mudraw") and formatters[ [[mudraw -o "%s" "%s" %s]] ]

    local f_svgpage  = formatters["%s-page-%s.svg"]
    local f_svgname  = formatters["%s.svg"]

    local notupdated = 0
    local updated    = 0
    local skipped    = 0
    local oldfiles   = dir.glob(file.join(imagesource,"*"))
    local newfiles   = { }

    if not pdftosvg then
        report("the %a binary is not present","mudraw")
    end

    -- a coverpage file has to be in the root of the export tree

    if not coverpage then
        report("no cover page (image) defined")
    elseif suffix(coverpage) ~= "xhtml" then
        report("using cover page %a",coverpage)
        local source = coverpage
        local target = joinfile(htmlsource,coverpage)
        htmlfiles[#htmlfiles+1 ] = coverpage
        report("copying coverpage %a to %a",source,target)
        copyfile(source,target)
    elseif isfile(coverpage) then
        report("using cover page image %a",coverpage)
        images.cover = {
            height = "100%",
            width  = "100%",
            page   = "1",
            name   = url.filename(coverpage),
            used   = coverpage,
        }
        local data = replacetemplate(t_coverxhtml, {
            content = replacetemplate(t_coverimg, {
                image = coverpage,
            })
        })
        coverpage = defaultcoverpage
        local target = joinfile(htmlsource,coverpage)
        report("saving coverpage to %a",target)
        io.savedata(target,data)
        htmlfiles[#htmlfiles+1 ] = coverpage
    else
        report("cover page image %a is not present",coverpage)
        coverpage = false
    end

    if not coverpage then
        local data = replacetemplate(t_coverxhtml, {
            content = "no cover page"
        })
        coverpage = defaultcoverpage
        local target = joinfile(htmlsource,coverpage)
        report("saving dummy coverpage to %a",target)
        io.savedata(target,data)
        htmlfiles[#htmlfiles+1 ] = coverpage
    end

    for id, data in sortedhash(images) do
        local name = url.filename(data.name)
        local used = url.filename(data.used)
        local base = basename(used)
        local page = tonumber(data.page) or 1
        -- todo : check timestamp and prefix, rename to image-*
        if suffix(used) == "pdf" then
            -- todo: pass svg name
            if page > 1 then
                name = f_svgpage(nameonly(name),page)
            else
                name = f_svgname(nameonly(name))
            end
            local source  = used
            local target  = joinfile(imagesource,name)
            if needsupdating(source,target) then
                if pdftosvg then
                    local command = pdftosvg(target,source,page)
                    report("running command %a",command)
                    os.execute(command)
                    updated = updated + 1
                else
                    skipped = skipped + 1
                end
            else
                notupdated = notupdated + 1
            end
            newfiles[#newfiles+1] = target
        else
            name = basename(used)
            local source = used
            local target = joinfile(imagesource,name)
            if needsupdating(source,target) then
                report("copying %a to %a",source,target)
                copyfile(source,target)
                updated = updated + 1
            else
                notupdated = notupdated + 1
                -- no message
            end
            newfiles[#newfiles+1] = target
        end
        local target = newfiles[#newfiles]
        if suffix(target) == "svg" and isfile(target) then
            local data = io.loaddata(target)
            if data then
                local done = gsub(data,"<!(DOCTYPE.-)>","<!-- %1 -->",1)
                if data ~= done then
                    report("doctype fixed in %a",target)
                    io.savedata(target,data)
                end
            end
        end
        data.newname = name -- without path
    end

    report("%s images checked, %s updated, %s kept, %s skipped",updated + notupdated + skipped,updated,notupdated,skipped)

    if reportobsolete(oldfiles,newfiles,purge) then
        obsolete = true
    end

    -- here we can decide not to make an epub

    local uuid          = format("urn:uuid:%s",os.uuid(true)) -- os.uuid()
    local identifier    = "bookid" -- for now

    local epubname      = removesuffix(name)
    local epubpath      = name .. "-epub"
    local epubfile      = replacesuffix(name,"epub")
    local epubroot      = replacesuffix(name,"opf")
    local epubtoc       = "toc.ncx"
    local epubmimetypes = "mimetype"
    local epubcontainer = "container.xml"
    local epubnavigator = "nav.xhtml"

    local metapath      = "META-INF"
    local datapath      = "OEBPS"

    local oldfiles      = dir.glob(file.join(epubpath,"**/*"))
    local newfiles      = { }

    report("creating paths in tree %a",epubpath)

    if not isdir(epubpath) then
        mkdir(epubpath)
    end
    if not isdir(epubpath) then
        report("unable to create path %a",epubpath)
        return
    end

    local metatarget  = joinfile(epubpath,metapath)
    local htmltarget  = joinfile(epubpath,datapath)
    local styletarget = joinfile(epubpath,datapath,stylepath)
    local imagetarget = joinfile(epubpath,datapath,imagepath)

    mkdir(metatarget)
    mkdir(htmltarget)
    mkdir(styletarget)
    mkdir(imagetarget)

    local used       = { }
    local notupdated = 0
    local updated    = 0

    local oldimagespecification = joinfile(htmlsource,imagefile)
    local newimagespecification = joinfile(htmltarget,imagefile)

    report("removing %a",newimagespecification)
 -- removefile(newimagespecification) -- because we update that one

    local function registerone(path,filename,mathml)
        local suffix = suffix(filename)
        local mime = mimetypes[suffix]
        if mime then
            local idmaker  = idmakers[suffix] or idmakers.default
            local fullname = path and joinfile(path,filename) or filename
            if mathml then
                used[#used+1] = replacetemplate(t_prop, {
                    id         = idmaker(filename),
                    filename   = fullname,
                    mime       = mime,
                    properties = "mathml",
                } )
            else
                used[#used+1] = replacetemplate(t_item, {
                    id       = idmaker(filename),
                    filename = fullname,
                    mime     = mime,
                } )
            end
            return true
        end
    end

    local function registerandcopyfile(check,path,name,sourcepath,targetpath,newname,image)

        if name == "" then
            report("ignoring unknown image")
            return
        end

        if newname then
            newname = replacesuffix(newname,suffix(name))
        else
            newname = name
        end

        local source = joinfile(sourcepath,name)
        local target = joinfile(targetpath,newname)
        local mathml = false

        if suffix(source) == "xhtml" then
            if find(io.loaddata(source),"MathML") then
                mathml = true -- inbelievable: the property is only valid when there is mathml
            end
        else
            report("checking image %a -> %a",source,target)
        end
        if registerone(path,newname,mathml) then
            if not check or needsupdating(source,target) or mathml and svgmath then
                report("copying %a to %a",source,target)
                copyfile(source,target)
                updated = updated + 1
            else
                notupdated = notupdated + 1
            end
            newfiles[#newfiles+1] = target
            if mathml and svgmath then
                report()
                report("converting mathml into svg in %a",target)
                report()
                local status, total, unique = moduledata.svgmath.convert(target,svgstyle)
                report()
                if status then
                    report("%s formulas converted, %s are unique",total,unique)
                else
                    report("warning: %a in %a",total,target)
                end
                report()
            end
        end
    end

 -- local nofdummies = 0
 -- local dummyname  = formatters["dummy-figure-%03i"]
 -- local makedummy  = formatters["context --extra=dummies --noconsole --once --result=%s"]
 --
 -- local function registerandcopydummy(targetpath,name)
 --     nofdummies = nofdummies + 1
 --     local newname = dummyname(nofdummies)
 --     local target  = joinfile(targetpath,newname)
 --     if not isfile(target) then
 --         pushdir(targetpath)
 --         report("generating dummy %a for %a",newname,name or "unknown")
 --         os.execute(makedummy(newname))
 --         popdir()
 --     end
 --     return newname
 -- end

    for image, data in sortedhash(images) do
     -- if data.used == "" then
     --     data.newname = registerandcopydummy(imagetarget,data.name)
     -- end
        registerandcopyfile(true,imagepath,data.newname,imagesource,imagetarget,rename and image,true)
    end
    for i=1,#styles do
        registerandcopyfile(false,stylepath,styles[i],stylesource,styletarget)
    end
    for i=1,#htmlfiles do
        registerandcopyfile(false,false,htmlfiles[i],htmlsource,htmltarget)
    end

    relocateimages(images,oldimagespecification,oldimagespecification,imagepath,rename)
    relocateimages(images,oldimagespecification,newimagespecification,imagepath,rename)

    report("%s files registered, %s updated, %s kept",updated + notupdated,updated,notupdated)

    local function saveinfile(what,name,data)
        report("saving %s in %a",what,name)
        io.savedata(name,data)
        newfiles[#newfiles+1] = name
    end

    used[#used+1] = replacetemplate(t_prop, {
        id         = "nav",
        filename   = epubnavigator,
        properties = "nav",
        mime       = "application/xhtml+xml",
    })

    registerone(false,epubtoc)

    saveinfile("navigation data",joinfile(htmltarget,epubnavigator),replacetemplate(t_navtoc, { -- version 3.0
        root = htmlroot,
    } ) )

    saveinfile("used mimetypes",joinfile(epubpath,epubmimetypes),mimetype)

    saveinfile("version 2.0 container",joinfile(metatarget,epubcontainer),replacetemplate(t_container, {
        rootfile = epubroot
    } ) )

    local idmaker = idmakers[suffix(htmlroot)] or idmakers.default

    saveinfile("package specification",joinfile(htmltarget,epubroot),replacetemplate(t_package, {
        identifier = identifier,
        title      = title,
        language   = language,
        uuid       = uuid,
        creator    = creator,
        date       = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        coverpage  = idmaker(coverpage),
        manifest   = concat(used,"\n"),
        rootfile   = idmaker(htmlroot)
    } ) )

    -- t_toc is replaced by t_navtoc in >= 3

    saveinfile("table of contents",joinfile(htmltarget,epubtoc), replacetemplate(t_toc, {
        identifier = uuid, -- identifier,
        title      = title,
        author     = author,
        root       = htmlroot,
    } ) )

    report("creating archive\n\n")

    pushdir(epubpath)

    removefile(epubfile)

    local usedzipper = false

    local function zipped(zipper)
        local ok = os.execute(format(zipper.uncompressed,epubfile,epubmimetypes))
        if ok == 0 then
            os.execute(format(zipper.compressed,epubfile,metapath))
            os.execute(format(zipper.compressed,epubfile,datapath))
            usedzipper = zipper.name
            return true
        end
    end

    -- nice way

    for i=1,#zippers do
        if os.which(zippers[i].binary) and zipped(zippers[i]) then
            break
        end
    end

    -- trial and error

    if not usedzipper then
        for i=1,#zippers do
            if zipped(zippers[i]) then
                break
            end
        end
    end

    popdir()

    if usedzipper then
        local treefile = joinfile(epubpath,epubfile)
        removefile(epubfile)
        copyfile(treefile,epubfile)
        if isfile(epubfile) then
            removefile(treefile)
        end
        report("epub archive made using %s: %s",usedzipper,epubfile)
    else
        local list = { }
        for i=1,#zippers do
            list[#list+1] = zippers[i].name
        end
        report("no epub archive made, install one of: % | t",list)
    end

    if reportobsolete(oldfiles,newfiles,purge) then
        obsolete = true
    end

    if obsolete and not purge then
        report("use --purge to remove obsolete files")
    end

end

--

local a_exporthelp = environment.argument("exporthelp")
local a_make       = environment.argument("make")
local a_all        = environment.argument("all")
local a_purge      = a_all or environment.argument("purge")
local a_rename     = a_all or environment.argument("rename")
local a_svgmath    = a_all or environment.argument("svgmath")
local a_svgstyle   = environment.argument("svgstyle")

if a_make and a_svgmath then
    require("x-math-svg")
end

if a_make then
    scripts.epub.make(a_purge,a_rename,a_svgmath,a_svgstyle)
elseif a_exporthelp then
    application.export(a_exporthelp,environment.files[1])
else
    application.help()
end

-- java -jar d:\epubcheck\epubcheck-3.0.1.jar -v 3.0 -mode xhtml mkiv-publications.tree\mkiv-publications.epub
