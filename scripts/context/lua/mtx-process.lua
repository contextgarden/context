if not modules then modules = { } end modules ['mtx-process'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lmt",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is a playground for features that I decided to upgrade in 2026 but that we
-- has own way or the other for ages, but differently. This time we use some
-- features that luametatex provides.

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-process</entry>
  <entry name="detail">Parallel processing</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="runners"><short>number of runners (cores) to use</short></flag>
   </subcategory>
   <subcategory>
     <flag name="pattern"><short></short></flag>
     <flag name="terminal"><short></short></flag>
     <flag name="parallel"><short></short></flag>
     <flag name="runners"><short></short></flag>
     <flag name="parallelsequence"><short></short></flag>
     <flag name="parallellist"><short></short></flag>
     <flag name="parallelmodes"><short></short></flag>
     <flag name="squid"><short></short></flag>
   </subcategory>
   <subcategory>
    <flag name="patch"><short>directory to watch</short></flag>
    <flag name="suffix"><short>suffix to watch</short></flag>
    <flag name="template"><short>template for watch command</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Examples</title>
   <subcategory>
    <example><command>mtxrun --script process ...</command></example>
    <example><command>mtxrun --script watch ...</command></example>
   </subcategory>
  </category>
 </examples>
 <comments>
    <comment>patterns are lua patterns and need to be escaped accordingly</comment>
 </comments>
</application>
]]

local application = logs.application {
    name     = "mtx-process",
    banner   = "Parallel Processing 0.10",
    helpinfo = helpinfo,
}

require("util-par.lmt")

local report = application.report

scripts         = scripts         or { }
scripts.process = scripts.process or { }

local getargument = environment.argument

function scripts.process.parallel()
    local pattern  = getargument("pattern")
    local terminal = getargument("terminal")
    local parallel = getargument("parallel")
    local runners  = getargument("runners")
    local sequence = getargument("parallelsequence")
    local list     = getargument("parallellist")
    local modes    = getargument("parallelmodes")
    local squid    = getargument("squid")
    environment.arguments.pattern          = nil
    environment.arguments.terminal         = nil
    environment.arguments.squid            = nil
    environment.arguments.runners          = nil
    environment.arguments.parallel         = nil
    environment.arguments.parallelsequence = nil
    environment.arguments.parallellist     = nil
    environment.arguments.parallelmodes    = nil
    utilities.parallel.job{
        report     = logs.reporter("parallel process"),
        files      = environment.files,
        pattern    = pattern,
        terminal   = terminal,
        parallel   = parallel,
        runners    = runners,
        sequence   = sequence,
        list       = list,
        modes      = modes,
        squid      = squid,
     -- passthese  = environment.arguments,
    }
end

function scripts.process.watch()
    utilities.parallel.watch {
        report   = logs.reporter("parallel watch"),
        runners  = getargument("runners"),
        path     = getargument("path"),     -- ".",
        suffix   = getargument("suffix"),   -- "tex",
        template = getargument("template"), -- "context %q",
        resume   = getargument("resume"),
    }
end

if getargument("exporthelp") then
    application.export(environment.argument("exporthelp"),files[1])
elseif getargument("parallel") or getargument("parallellist") or getargument("parallelmodes") then
    scripts.process.parallel()
elseif getargument("watch") then
    scripts.process.watch()
else
    application.help()
end
