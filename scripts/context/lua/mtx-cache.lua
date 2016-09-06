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
  <entry name="detail">ConTeXt & MetaTeX Cache Management</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="purge"><short>remove not used files</short></flag>
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
    local tmas, tmcs, rest = { }, { }, { }
    for i=1,#all do
        local name = all[i]
        local suffix = filesuffix(name)
        if suffix == "tma" then
            tmas[#tmas+1] = name
        elseif suffix == "tmc" then
            tmcs[#tmcs+1] = name
        else
            rest[#rest+1] = name
        end
    end
    return tmas, tmcs, rest, all
end

local function list(banner,path,tmas,tmcs,rest)
    report("%s: %s",banner,path)
    report()
    report("tma   : %4i",#tmas)
    report("tmc   : %4i",#tmcs)
    report("rest  : %4i",#rest)
    report("total : %4i",#tmas+#tmcs+#rest)
    report()
end

local function purge(banner,path,list,all)
    report("%s: %s",banner,path)
    report()
    local fonts = environment.argument("fonts")
    local n = 0
    for i=1,#list do
        local filename = list[i]
        if find(filename,"luatex%-cache") then -- safeguard
            if fonts and not find(filename,"fonts") then
                -- skip
            elseif all then
                remove(filename)
                n = n + 1
            elseif not fonts or find(filename,"fonts") then
                local suffix = filesuffix(filename)
                if suffix == "tma" then
                    local checkname = replacesuffix(filename,"tma","tmc")
                    if isfile(checkname) then
                        remove(filename)
                        n = n + 1
                    end
                end
            end
        end
    end
    report("removed tma files : %i",n)
    report()
    return n
end

function scripts.cache.purge()
    local writable = caches.getwritablepath()
    local tmas, tmcs, rest = collect(writable)
    list("writable path",writable,tmas,tmcs,rest)
    purge("writable path",writable,tmas)
    list("writable path",writable,tmas,tmcs,rest)
end

function scripts.cache.erase()
    local writable = caches.getwritablepath()
    local tmas, tmcs, rest, all = collect(writable)
    list("writable path",writable,tmas,tmcs,rest)
    purge("writable path",writable,all,true)
    list("writable path",writable,tmas,tmcs,rest)
end

function scripts.cache.list()
    local readables = caches.getreadablepaths()
    local writable = caches.getwritablepath()
    local tmas, tmcs, rest = collect(writable)
    list("writable path",writable,tmas,tmcs,rest)
    for i=1,#readables do
        local readable = readables[i]
        if readable ~= writable then
            local tmas, tmcs = collect(readable)
            list("readable path",readable,tmas,tmcs,rest)
        end
    end
end

if environment.argument("purge") then
    scripts.cache.purge()
elseif environment.argument("erase") then
    scripts.cache.erase()
elseif environment.argument("list") then
    scripts.cache.list()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end
