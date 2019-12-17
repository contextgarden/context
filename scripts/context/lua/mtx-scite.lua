if not modules then modules = { } end modules ['mtx-scite'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- mtxrun --script scite --tree --source=t:/texmf/tex/context --target=e:/tmp/context --numbers

local P, R, S, C, Ct, Cf, Cc, Cg = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cf, lpeg.Cc, lpeg.Cg
local lpegmatch = lpeg.match
local format, lower, gmatch = string.format, string.lower, string.gmatch

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-scite</entry>
  <entry name="detail">Scite Helper Script</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="words"><short>convert spell-*.txt into spell-*.lua</short></flag>
    <flag name="tree"><short>converts a tree into an html tree (--source --target --numbers)</short></flag>
    <flag name="file"><short>converts a file into an html file (--source --target --numbers --lexer)</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-scite",
    banner   = "Scite Helper Script 1.00",
    helpinfo = helpinfo,
}

local report = application.report

local scite = require("util-sci")

scripts       = scripts       or { }
scripts.scite = scripts.scite or { }

-- todo: append to global properties else order of loading problem
-- linux problem ... files are under root protection so we need --install
--
-- local scitesignals = { "scite-context.rme", "context.properties" }
-- local screenfont   = "lmtypewriter10-regular.ttf"

-- function scripts.scite.start(indeed)
--     local usedsignal, datapath, fullname, workname, userpath, fontpath
--     if os.type == "windows" then
--         workname = "scite.exe"
--         userpath = os.getenv("USERPROFILE") or ""
--         fontpath = os.getenv("SYSTEMROOT")
--         fontpath = (fontpath and file.join(fontpath,"fonts")) or ""
--     else
--         workname = "scite"
--         userpath = os.getenv("HOME") or ""
--         fontpath = ""
--     end
--     local binpaths = file.split_path(os.getenv("PATH")) or file.split_path(os.getenv("path"))
--     for i=1,#scitesignals do
--         local scitesignal = scitesignals[i]
--         local scitepath = resolvers.findfile(scitesignal,"other text files") or ""
--         if scitepath ~= "" then
--             scitepath  = file.dirname(scitepath) -- data
--             if scitepath == "" then
--                 scitepath = resolvers.cleanpath(lfs.currentdir())
--             else
--                 usedsignal, datapath = scitesignal, scitepath
--                 break
--             end
--         end
--     end
--     if not datapath or datapath == "" then
--         report("invalid datapath, maybe you need to regenerate the file database")
--         return false
--     end
--     if not binpaths or #binpaths == 0 then
--         report("invalid binpath")
--         return false
--     end
--     for i=1,#binpaths do
--         local p = file.join(binpaths[i],workname)
--         if lfs.isfile(p) and lfs.attributes(p,"size") > 10000 then -- avoind stub
--             fullname = p
--             break
--         end
--     end
--     if not fullname then
--         report("unable to locate %s",workname)
--         return false
--     end
--     local properties  = dir.glob(file.join(datapath,"*.properties"))
--     local luafiles    = dir.glob(file.join(datapath,"*.lua"))
--     local extrafont   = resolvers.findfile(screenfont,"truetype font") or ""
--     local pragmafound = dir.glob(file.join(datapath,"pragma.properties"))
--     if userpath == "" then
--         report("unable to figure out userpath")
--         return false
--     end
--     local verbose = environment.argument("verbose")
--     local tobecopied, logdata = { }, { }
--     local function check_state(fullname,newpath)
--         local basename = file.basename(fullname)
--         local destination = file.join(newpath,basename)
--         local pa, da = lfs.attributes(fullname), lfs.attributes(destination)
--         if not da then
--             logdata[#logdata+1] = { "new        : %s", basename }
--             tobecopied[#tobecopied+1] = { fullname, destination }
--         elseif pa.modification > da.modification then
--             logdata[#logdata+1] = { "outdated   : %s", basename }
--             tobecopied[#tobecopied+1] = { fullname, destination }
--         else
--             logdata[#logdata+1] = { "up to date : %s", basename }
--         end
--     end
--     for i=1,#properties do
--         check_state(properties[i],userpath)
--     end
--     for i=1,#luafiles do
--         check_state(luafiles[i],userpath)
--     end
--     if fontpath ~= "" then
--         check_state(extrafont,fontpath)
--     end
--     local userpropfile = "SciTEUser.properties"
--     if os.name ~= "windows" then
--         userpropfile = "."  .. userpropfile
--     end
--     local fullpropfile = file.join(userpath,userpropfile)
--     local userpropdata = io.loaddata(fullpropfile) or ""
--     local propfiledone = false
--     if pragmafound then
--         if userpropdata == "" then
--             logdata[#logdata+1] = { "error      : no user properties found on '%s'", fullpropfile }
--         elseif string.find(userpropdata,"import *pragma") then
--             logdata[#logdata+1] = { "up to date : 'import pragma' in '%s'", userpropfile }
--         else
--             logdata[#logdata+1] = { "yet unset  : 'import pragma' in '%s'", userpropfile }
--             userproperties = userpropdata .. "\n\nimport pragma\n\n"
--             propfiledone = true
--         end
--     else
--         if string.find(userpropdata,"import *context") then
--             logdata[#logdata+1] = { "up to date : 'import context' in '%s'", userpropfile }
--         else
--             logdata[#logdata+1] = { "yet unset  : 'import context' in '%s'", userpropfile }
--             userproperties = userpropdata .. "\n\nimport context\n\n"
--             propfiledone = true
--         end
--     end
--     if not indeed or verbose then
--         report("used signal: %s", usedsignal)
--         report("data path  : %s", datapath)
--         report("full name  : %s", fullname)
--         report("user path  : %s", userpath)
--         report("extra font : %s", extrafont)
--     end
--     if #logdata > 0 then
--         report("")
--         for k=1,#logdata do
--             local v = logdata[k]
--             report(v[1],v[2])
--         end
--     end
--     if indeed then
--         if #tobecopied > 0 then
--             report("warning    : copying updated files")
--             for i=1,#tobecopied do
--                 local what = tobecopied[i]
--                 report("copying    : '%s' => '%s'",what[1],what[2])
--                 file.copy(what[1],what[2])
--             end
--         end
--         if propfiledone then
--             report("saving     : '%s'",userpropfile)
--             io.savedata(fullpropfile,userpropdata)
--         end
--         os.launch(fullname)
--     end
-- end

-- local splitter = (Cf(Ct("") * (Cg(C(R("az","AZ","\127\255")^1) * Cc(true)) + P(1))^1,rawset) )^0
--
-- local function splitwords(words)
--     return lpegmatch(splitter,words) -- or just split and tohash
-- end

local function splitwords(words)
    local w = { }
    for s in string.gmatch(words,"[a-zA-Z\127-255]+") do
        if #s > 2 then -- will become option
            w[lower(s)] = s
        end
    end
    return w
end

-- maybe: lowerkey = UpperWhatever

function scripts.scite.words()
    for i=1,#environment.files do
        local tag = environment.files[i]
        local tag = string.match(tag,"spell%-(..)%.") or tag
        local txtname = format("spell-%s.txt",tag)
        local luaname = format("spell-%s.lua",tag)
        local lucname = format("spell-%s.luc",tag)
        if lfs.isfile(txtname) then
            report("loading %s",txtname)
            local olddata = io.loaddata(txtname) or ""
            local words = splitwords(olddata)
            local min, max, n = 100, 1, 0
            for k, v in next, words do
                local l = #k
                if l < min then
                    min = l
                end
                if l > max then
                    max = l
                end
                n = n + 1
            end
            if min > max then
                min = max
            end
            local newdata = {
                words  = words,
                source = oldname,
                min    = min,
                max    = max,
                n      = n,
            }
            report("saving %q, %s words, %s shortest, %s longest",luaname,n,min,max)
            io.savedata(luaname,table.serialize(newdata,true))
            report("compiling %q",lucname)
            os.execute(format("luac -s -o %s %s",lucname,luaname))
        else
            report("no data file %s",txtname)
        end
    end
    report("you need to move the lua files to lexers/data")
end

function scripts.scite.tree()
    local source  = environment.argument("source")
    local target  = environment.argument("target")
    local numbers = environment.argument("numbers")
    if not lfs.isdir(source) then
        report("you need to pass a valid source path with --source")
        return
    end
    if not lfs.isdir(target) then
        report("you need to pass a valid target path with --target")
        return
    end
    if source == target then
        report("source and target paths must be different")
        return
    end
    scite.converttree(source,target,numbers)
end

function scripts.scite.file()
    local source  = environment.argument("source")
    local target  = environment.argument("target")
    local lexer   = environment.argument("lexer")
    local numbers = environment.argument("numbers")
    if source then
        local target = target or file.replacesuffix(source,"html")
        if source == target then
            report("the source file cannot be the same as the target")
        else
            scite.filetohtml(source,lexer,target,numbers)
        end

    else
        for i=1,#environment.files do
            local source  = environment.files[i]
            local target  = file.replacesuffix(source,"html")
            if source == target then
                report("the source file cannot be the same as the target")
            else
                scite.filetohtml(source,nil,target,numbers)
            end
        end
    end
end

-- if environment.argument("start") then
--     scripts.scite.start(true)
-- elseif environment.argument("test") then
--     scripts.scite.start()
-- else
--     application.help()
-- end

if environment.argument("words") then
    scripts.scite.words()
elseif environment.argument("tree") then
    scripts.scite.tree()
elseif environment.argument("file") then
    scripts.scite.file()
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end

