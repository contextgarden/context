if not modules then modules = { } end modules ['mtx-cache'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-cache</entry>
  <entry name="detail">ConTeXt &amp; MetaTeX Cache Management</entry>
  <entry name="version">1.01</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="make"><short>generate databases and formats</short></flag>
    <flag name="erase"><short>completely remove cache</short></flag>
    <flag name="list"><short>show cache</short></flag>
   </subcategory>
   <subcategory>
    <flag name="fonts"><short>only wipe fonts</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]


local find = string.find
local filesuffix, replacesuffix = file.suffix, file.replacesuffix
local isfile = lfs.isfile
local remove = os.remove

local application = logs.application {
    name     = "mtx-cache",
    banner   = "ConTeXt & MetaTeX Cache Management 0.10",
    helpinfo = helpinfo,
}

local report = application.report

scripts       = scripts       or { }
scripts.cache = scripts.cache or { }

local function collect(path)
    local all = dir.glob(path .. "/**/*")
    local ext = table.setmetatableindex("table")
    for i=1,#all do
        local name = all[i]
        local list = ext[filesuffix(name)]
        list[#list+1] = name
    end
    return ext
end

local function list(banner,path,ext)
    local total = 0
    report("%s: %s",banner,path)
    report()
    for k, v in table.sortedhash(ext) do
        total = total + #v
        report("%-6s : %4i",k,#v)
    end
    report()
    report("total  : %4i",total)
    report()
end

local function erase(banner,path,list)
    report("%s: %s",banner,path)
    report()
    for ext, list in table.sortedhash(list) do
        local gone = 0
        local kept = 0
        for i=1,#list do
            local filename = list[i]
            if find(filename,"luatex%-cache") then
                remove(filename)
                if isfile(filename) then
                    kept = kept + 1
                else
                    gone = gone + 1
                end
            end
        end
        report("%-6s : %4i gone, %4i kept",ext,gone,kept)
    end
    report()
end

function scripts.cache.make()
    os.execute("mtxrun --generate")
    os.execute("context --make")
    os.execute("mtxrun --script font --reload")
end

function scripts.cache.erase()
    local writable = caches.getwritablepath()
    local groups   = collect(writable)
    list("writable path",writable,groups)
    erase("writable path",writable,groups)
    if environment.argument("make") then
        scripts.cache.make()
    end
end

function scripts.cache.list()
    local readables = caches.getreadablepaths()
    local writable  = caches.getwritablepath()
    local groups    = collect(writable)
    list("writable path",writable,groups)
    for i=1,#readables do
        local readable = readables[i]
        if readable ~= writable then
            local groups = collect(readable)
            list("readable path",readable,groups)
        end
    end
end

if environment.argument("erase") then
    scripts.cache.erase()
elseif environment.argument("list") then
    scripts.cache.list()
elseif environment.argument("make") then
    scripts.cache.make()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
