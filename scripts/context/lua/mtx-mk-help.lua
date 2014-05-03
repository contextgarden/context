if not modules then modules = { } end modules ['mtx-mk-help'] = {
    version   = 1.001,
    comment   = "a script for making help files",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[

mtxrun                             --exporthelp=all %targetpath%\mkiv\mtxrun.tmp
context                            --exporthelp=all %targetpath%\mkiv\context.tmp
mtxrun --script context            --exporthelp=all %targetpath%\mkiv\mtx-context.tmp

mtxrun --script babel              --exporthelp=all %targetpath%\mkiv\mtx-babel.tmp
mtxrun --script base               --exporthelp=all %targetpath%\mkiv\mtx-base.tmp
mtxrun --script cache              --exporthelp=all %targetpath%\mkiv\mtx-cache.tmp
mtxrun --script chars              --exporthelp=all %targetpath%\mkiv\mtx-chars.tmp
mtxrun --script check              --exporthelp=all %targetpath%\mkiv\mtx-check.tmp
mtxrun --script colors             --exporthelp=all %targetpath%\mkiv\mtx-colors.tmp
mtxrun --script convert            --exporthelp=all %targetpath%\mkiv\mtx-convert.tmp
mtxrun --script epub               --exporthelp=all %targetpath%\mkiv\mtx-epub.tmp
mtxrun --script fcd                --exporthelp=all %targetpath%\mkiv\mtx-fcd.tmp
mtxrun --script flac               --exporthelp=all %targetpath%\mkiv\mtx-flac.tmp
mtxrun --script fonts              --exporthelp=all %targetpath%\mkiv\mtx-fonts.tmp
mtxrun --script grep               --exporthelp=all %targetpath%\mkiv\mtx-grep.tmp
mtxrun --script interface          --exporthelp=all %targetpath%\mkiv\mtx-interface.tmp
mtxrun --script metapost           --exporthelp=all %targetpath%\mkiv\mtx-metapost.tmp
mtxrun --script metatex            --exporthelp=all %targetpath%\mkiv\mtx-metatex.tmp
mtxrun --script modules            --exporthelp=all %targetpath%\mkiv\mtx-modules.tmp
mtxrun --script mtxworks           --exporthelp=all %targetpath%\mkiv\mtx-mtxworks.tmp
mtxrun --script package            --exporthelp=all %targetpath%\mkiv\mtx-package.tmp
mtxrun --script patterns           --exporthelp=all %targetpath%\mkiv\mtx-patterns.tmp
mtxrun --script pdf                --exporthelp=all %targetpath%\mkiv\mtx-pdf.tmp
mtxrun --script profile            --exporthelp=all %targetpath%\mkiv\mtx-profile.tmp
mtxrun --script rsync              --exporthelp=all %targetpath%\mkiv\mtx-rsync.tmp
mtxrun --script scite              --exporthelp=all %targetpath%\mkiv\mtx-scite.tmp
mtxrun --script server             --exporthelp=all %targetpath%\mkiv\mtx-server.tmp
mtxrun --script texworks           --exporthelp=all %targetpath%\mkiv\mtx-texworks.tmp
mtxrun --script timing             --exporthelp=all %targetpath%\mkiv\mtx-timing.tmp
mtxrun --script tools              --exporthelp=all %targetpath%\mkiv\mtx-tools.tmp
mtxrun --script unzip              --exporthelp=all %targetpath%\mkiv\mtx-unzip.tmp
mtxrun --script update             --exporthelp=all %targetpath%\mkiv\mtx-update.tmp
mtxrun --script watch              --exporthelp=all %targetpath%\mkiv\mtx-watch.tmp

mtxrun --script mk-help luatools   --exporthelp=all %targetpath%\mkiv\luatools.tmp

mtxrun --script mk-help texmfstart --exporthelp=all %targetpath%\mkii\texmfstart.tmp
mtxrun --script mk-help texexec    --exporthelp=all %targetpath%\mkii\texexec.tmp
mtxrun --script mk-help texutil    --exporthelp=all %targetpath%\mkii\texutil.tmp
mtxrun --script mk-help ctxtools   --exporthelp=all %targetpath%\mkii\ctxtools.tmp
mtxrun --script mk-help textools   --exporthelp=all %targetpath%\mkii\textools.tmp
mtxrun --script mk-help pdftools   --exporthelp=all %targetpath%\mkii\pdftools.tmp
mtxrun --script mk-help tmftools   --exporthelp=all %targetpath%\mkii\tmftools.tmp
mtxrun --script mk-help xmltools   --exporthelp=all %targetpath%\mkii\xmltools.tmp
mtxrun --script mk-help pstopdf    --exporthelp=all %targetpath%\mkii\pstopdf.tmp
mtxrun --script mk-help rlxtools   --exporthelp=all %targetpath%\mkii\rlxtools.tmp
mtxrun --script mk-help imgtopdf   --exporthelp=all %targetpath%\mkii\imgtopdf.tmp

]]--

local helpinfo = os.resultof("mtxrun --exporthelp") or ""
local helpinfo = string.match(helpinfo,[[^.-(<application>.-</application>)]]) or [[<application></application>]]

local texmfstart = logs.application {
    name     = "texmfstart",
    banner   = "texmfstart 7.0.0",
    helpinfo = [[<?xml version="1.0"?>]] .. helpinfo,
}

-- let's also put luatools here:

local helpinfo = os.resultof("luatools --exporthelp") or ""
local helpinfo = string.match(helpinfo,[[^.-(<application>.-</application>)]]) or [[<application></application>]]
local helpinfo = string.gsub(helpinfo,"mtx%-base","luatools")

local luatools = logs.application {
    name     = "luatools",
    banner   = "luatools 1.35",
    helpinfo = [[<?xml version="1.0"?>]] .. helpinfo,
}

--

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">texexec</entry>
  <entry name="detail">TeXExec</entry>
  <entry name="version">6.2.1</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="make"><short>make formats</short></flag>
    <flag name="check"><short>check versions</short></flag>
    <flag name="process"><short>process file</short></flag>
    <flag name="mptex"><short>process mp file</short></flag>
    <flag name="mpxtex"><short>process mpx file</short></flag>
    <flag name="mpgraphic"><short>process mp file to stand-alone graphics</short></flag>
    <flag name="mpstatic"><short>process mp/ctx file to stand-alone graphics</short></flag>
    <flag name="listing"><short>list of file content</short></flag>
    <flag name="figures"><short>generate overview of figures</short></flag>
    <flag name="modules"><short>generate module documentation</short></flag>
    <flag name="pdfarrange"><short>impose pages (booklets)</short></flag>
    <flag name="pdfselect"><short>select pages from file(s)</short></flag>
    <flag name="pdfcopy"><short>copy pages from file(s)</short></flag>
    <flag name="pdftrim"><short>trim pages from file(s)</short></flag>
    <flag name="pdfcombine"><short>combine multiple pages</short></flag>
    <flag name="pdfsplit"><short>split file in pages</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local texexec = logs.application {
    name     = "texexec",
    banner   = "TeXExec 6.2.1",
    helpinfo = helpinfo,
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">texutil</entry>
  <entry name="detail">TeXUtil</entry>
  <entry name="version">9.1.0</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="references"><short>convert tui file into tuo file</short></flag>
    <flag name="figures"><short>generate figure dimensions file</short></flag>
    <flag name="logfile"><short>filter essential log messages</short></flag>
    <flag name="purgefiles"><short>remove most temporary files</short></flag>
    <flag name="purgeallfiles"><short>remove all temporary files</short></flag>
    <flag name="documentation"><short>generate documentation file from source</short></flag>
    <flag name="analyzefile"><short>analyze pdf file</short></flag>
   </subcategory>
  </category>
 </flags>
</application>]]

local texutil = logs.application {
    name     = "texutil",
    banner   = "TeXUtil 9.1.0",
    helpinfo = helpinfo,
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">ctxtools</entry>
  <entry name="detail">CtxTools</entry>
  <entry name="version">1.3.5</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="touchcontextfile"><short>update context version</short></flag>
    <flag name="contextversion"><short>report context version</short></flag>
    <flag name="jeditinterface"><short>generate jedit syntax files [<ref name="pipe]"/></short></flag>
    <flag name="bbeditinterface"><short>generate bbedit syntax files [<ref name="pipe]"/></short></flag>
    <flag name="sciteinterface"><short>generate scite syntax files [<ref name="pipe]"/></short></flag>
    <flag name="rawinterface"><short>generate raw syntax files [<ref name="pipe]"/></short></flag>
    <flag name="translateinterface"><short>generate interface files (xml) [nl de ..]</short></flag>
    <flag name="purgefiles"><short>remove temporary files [<ref name="all"/> <ref name="recurse]"/> [basename]</short></flag>
    <flag name="documentation  generate documentation [--type" value="]"><short>[filename]</short></flag>
    <flag name="filterpages'"><short>) # no help, hidden temporary feature</short></flag>
    <flag name="dpxmapfiles"><short>convert pdftex mapfiles to dvipdfmx [<ref name="force]"/> [texmfroot]</short></flag>
    <flag name="listentities"><short>create doctype entity definition from enco-uc.tex</short></flag>
    <flag name="brandfiles"><short>add context copyright notice [<ref name="force]"/></short></flag>
    <flag name="platformize"><short>replace line-endings [<ref name="recurse"/> <ref name="force]"/> [pattern]</short></flag>
    <flag name="dependencies  analyze depedencies within context [--save --compact --filter" value="[macros|filenames] ]"><short>[filename]</short></flag>
    <flag name="updatecontext"><short>download latest version and remake formats [<ref name="proxy]"/></short></flag>
    <flag name="disarmutfbom"><short>remove utf bom [<ref name="force]"/></short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local ctxtools = logs.application {
    name     = "ctxtools",
    banner   = "CtxTools 1.3.5",
    helpinfo = helpinfo,
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">textools</entry>
  <entry name="detail">TeXTools</entry>
  <entry name="version">1.3.1</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="removemapnames"><short>[pattern]   [<ref name="recurse]"/></short></flag>
    <flag name="restoremapnames"><short>[pattern]   [<ref name="recurse]"/></short></flag>
    <flag name="hidemapnames"><short>[pattern]   [<ref name="recurse]"/></short></flag>
    <flag name="videmapnames"><short>[pattern]   [<ref name="recurse]"/></short></flag>
    <flag name="findfile"><short>filename    [<ref name="recurse]"/></short></flag>
    <flag name="unzipfiles"><short>[pattern]   [<ref name="recurse]"/></short></flag>
    <flag name="fixafmfiles"><short>[pattern]   [<ref name="recurse]"/></short></flag>
    <flag name="mactodos"><short>[pattern]   [<ref name="recurse]"/></short></flag>
    <flag name="fixtexmftrees"><short>[texmfroot] [<ref name="force]"/></short></flag>
    <flag name="replacefile"><short>filename    [<ref name="force]"/></short></flag>
    <flag name="updatetree"><short>fromroot toroot [<ref name="force"/> <ref name="nocheck"/> <ref name="merge"/> <ref name="delete]"/></short></flag>
    <flag name="downcasefilenames"><short>[<ref name="recurse]"/> [<ref name="force]"/></short></flag>
    <flag name="stripformfeeds"><short>[<ref name="recurse]"/> [<ref name="force]"/></short></flag>
    <flag name="showfont"><short>filename</short></flag>
    <flag name="encmake"><short>afmfile encodingname</short></flag>
    <flag name="tpmmake"><short>tpm file (run in texmf root)</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local textools = logs.application {
    name     = "textools",
    banner   = "TeXTools 1.3.1",
    helpinfo = helpinfo,
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">pdftools</entry>
  <entry name="detail">PDFTools</entry>
  <entry name="version">1.2.1</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="spotimage  filename --colorspec" value=""><short><ref name="colorname="/>  [<ref name="retain"/> <ref name="invert"/> <ref name="subpath=]"/></short></flag>
    <flag name="colorimage  filename --colorspec" value=""><short>[<ref name="retain"/> <ref name="invert"/> <ref name="colorname="/> ]</short></flag>
    <flag name="convertimage"><short>filename [<ref name="retain"/> <ref name="subpath]"/></short></flag>
    <flag name="downsampleimage"><short>filename [<ref name="retain"/> <ref name="subpath"/> <ref name="lowres"/> <ref name="normal]"/></short></flag>
    <flag name="info"><short>filename</short></flag>
    <flag name="countpages"><short>[<ref name="pattern"/> <ref name="threshold]"/></short></flag>
    <flag name="checkembedded"><short>[<ref name="pattern]"/></short></flag>
    <flag name="analyzefile"><short>filename</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local pdftools = logs.application {
    name     = "pdftools",
    banner   = "PDFTools 1.2.1",
    helpinfo = helpinfo,
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">tmftools</entry>
  <entry name="detail">TMFTools</entry>
  <entry name="version">1.1.0</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="analyze"><short>[<ref name="strict"/> <ref name="sort"/> <ref name="rootpath"/> <ref name="treepath"/> <ref name="delete"/> <ref name="force"/>] [pattern]</short></flag>
   </subcategory>
   <subcategory>
    <flag name="serve"><short>act as kpse server</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local tmftools = logs.application {
    name     = "tmftools",
    banner   = "TMFTools 1.2.1",
    helpinfo = helpinfo,
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">xmltools</entry>
  <entry name="detail">XMLTools</entry>
  <entry name="version">1.2.2</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="dir"><short>generate directory listing</short></flag>
    <flag name="mmlpages"><short>generate graphic from mathml</short></flag>
    <flag name="analyze"><short>report entities and elements [<ref name="utf"/> <ref name="process"/>]</short></flag>
    <flag name="cleanup"><short>cleanup xml file [<ref name="force"/>]</short></flag>
    <flag name="enhance"><short>enhance xml file (partial)</short></flag>
    <flag name="filter"><short>filter elements from xml file [<ref name="element"/>]</short></flag>
    <flag name="dir"><short>generate ddirectory listing</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local xmltools = logs.application {
    name     = "xmltools",
    banner   = "XMLTools 1.2.1",
    helpinfo = helpinfo,
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">pstopdf</entry>
  <entry name="detail">PStoPDF</entry>
  <entry name="version">2.0.1</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="request"><short>handles exa request file</short></flag>
    <flag name="watch"><short>watch folders for conversions (untested)</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local pstopdf = logs.application {
    name     = "pstopdf",
    banner   = "PStoPDF 2.0.1",
    helpinfo = helpinfo,
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">rlxtools</entry>
  <entry name="detail">RlxTools</entry>
  <entry name="version">1.0.1</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="manipulate"><short>[<ref name="test]"/> manipulatorfile resourselog</short></flag>
    <flag name="identify"><short>[<ref name="collect]"/> filename</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local rlxtools = logs.application {
    name     = "rlxtools",
    banner   = "RlxTools 1.0.1",
    helpinfo = helpinfo,
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">imgtopdf</entry>
  <entry name="detail">ImgToPdf</entry>
  <entry name="version">1.1.2</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="convert"><short>convert image into pdf</short></flag>
    <flag name="compression"><short>level of compression in percent</short></flag>
    <flag name="depth"><short>image depth in bits</short></flag>
    <flag name="colorspace"><short> colorspace (rgb,cmyk,gray)</short></flag>
    <flag name="quality"><short>quality in percent</short></flag>
    <flag name="inputpath"><short>path where files are looked for</short></flag>
    <flag name="outputpath"><short>path where files end up</short></flag>
    <flag name="auto"><short>determine settings automatically</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local imgtopdf = logs.application {
    name     = "imgtopdf",
    banner   = "ImgToPdf 1.1.2",
    helpinfo = helpinfo,
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mptopdf</entry>
  <entry name="detail">convert MetaPost figures to PDF</entry>
  <entry name="version">1.4.1</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="metafun"><short>use the metafun format to process the file (default is mpost)</short></flag>
    <flag name="texexec"><short>use texexec (context) to process text snippets</short></flag>
    <flag name="latex"><short>use latex to process text snippets</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local mptopdf = logs.application {
    name     = "mptopdf",
    banner   = "MPtoPDF 1.4.1",
    helpinfo = helpinfo,
}

-- texmfstart.rb   is normally replaced by mtxrun
-- runtools.rb     is run from within context
-- concheck.rb     is run from within editors
-- texsync.rb      is no longer in the zip
-- mpstools.rb     is no longer in the zip
-- rscortool.rb    is only run indirectly
-- rsfiltool.rb    is only run indirectly
-- rslibtool.rb    is only run indirectly

local application = logs.application {
    name     = "mk-help",
    banner   = "Mk Help generator 1.00",
}

local filename  = environment.files[1]

if not filename then
    application.report("no mk script given")
    return
end

local mkapplication

if     filename == "texmfstart" then mkapplication = texmfstart
elseif filename == "luatools"   then mkapplication = luatools
elseif filename == "texexec"    then mkapplication = texexec
elseif filename == "texutil"    then mkapplication = texutil
elseif filename == "ctxtools"   then mkapplication = ctxtools
elseif filename == "textools"   then mkapplication = textools
elseif filename == "pdftools"   then mkapplication = pdftools
elseif filename == "tmftools"   then mkapplication = tmftools
elseif filename == "xmltools"   then mkapplication = xmltools
elseif filename == "pstopdf"    then mkapplication = pstopdf
elseif filename == "rlxtools"   then mkapplication = rlxtools
elseif filename == "imgtopdf"   then mkapplication = imgtopdf
elseif filename == "mptopdf"    then mkapplication = mptopdf  end

if not mkapplication then
    application.report("no valid mk script given")
    return
end

if environment.argument("exporthelp") then
    mkapplication.export(environment.argument("exporthelp"),environment.files[2])
else
    mkapplication.help()
end
