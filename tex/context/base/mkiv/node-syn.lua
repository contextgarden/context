if not modules then modules = { } end modules ['node-syn'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- See node-syn.lmt for some comments. Because it's either unsupported and/or due
-- to the mix of old and new libraries used in viewers the compressed (share same y
-- coordinates) code has been removed. It doesn't save much anyway. I also removed
-- the g, x, k, r, f specific code. The repeat mode has been added here too, which
-- can work better with some versions of the libraries used in viewers.
--
-- Unfortunately there is still no way to signal that we don't want synctex to open
-- a file.

local type, rawset = type, rawset
local concat = table.concat
local formatters = string.formatters
local replacesuffix, suffixonly, nameonly, collapsepath = file.replacesuffix, file.suffix, file.nameonly, file.collapsepath
local openfile, renamefile, removefile = io.open, os.rename, os.remove

local report_system = logs.reporter("system")

local tex                 = tex
local texget              = tex.get

local nuts                = nodes.nuts

local getid               = nuts.getid
local getlist             = nuts.getlist
local setlist             = nuts.setlist
local getnext             = nuts.getnext
local getwhd              = nuts.getwhd
local getsubtype          = nuts.getsubtype

local nodecodes           = nodes.nodecodes
local kerncodes           = nodes.kerncodes

local glyph_code          = nodecodes.glyph
local disc_code           = nodecodes.disc
local glue_code           = nodecodes.glue
local penalty_code        = nodecodes.penalty
local kern_code           = nodecodes.kern
local hlist_code          = nodecodes.hlist
local vlist_code          = nodecodes.vlist
local fontkern_code       = kerncodes.fontkern

local insertbefore        = nuts.insertbefore
local insertafter         = nuts.insertafter

local nodepool            = nuts.pool
local new_latelua         = nodepool.latelua
local new_rule            = nodepool.rule
local new_kern            = nodepool.kern

local getdimensions       = nuts.dimensions
local getrangedimensions  = nuts.rangedimensions

local getinputfields      = nuts.getsynctexfields
local forceinputstatefile = tex.forcesynctextag   or tex.force_synctex_tag
local forceinputstateline = tex.forcesynctexline  or tex.force_synctex_line
local getinputstateline   = tex.getsynctexline    or tex.get_synctex_line
local setinputstatemode   = tex.setsynctexmode    or tex.set_synctex_mode

local foundintree         = resolvers.foundintree

local getpagedimensions   = nil --defined later

local eol                 = "\010"
local z_hlist             = "[0,0:0,0:0,0,0\010"
local s_hlist             = "]\010"
local f_hvoid             = formatters["h%i,%i:%i,%i:%i,%i,%i\010"]
local f_hlist             = formatters["(%i,%i:%i,%i:%i,%i,%i\010"]
local s_hlist             = ")\010"
local f_rule              = formatters["r%i,%i:%i,%s:%i,%i,%i\010"]
local f_plist             = formatters["[%i,%i:%i,%i:%i,%i,%i\010"]
local s_plist             = "]\010"

local synctex             = luatex.synctex or { }
luatex.synctex            = synctex

local getpos ; getpos = function() getpos = job.positions.getpos return getpos() end

-- status stuff

local enabled = false
local userule = false
local paused  = 0
local used    = false
local never   = false

-- get rid of overhead in mkiv

tex.set_synctex_no_files(1)

local noftags            = 0
local stnums             = { }
local nofblocked         = 0
local blockedfilenames   = { }
local blockedsuffixes    = {
    mkii = true,
    mkiv = true,
    mkvi = true,
    mkxl = true,
    mklx = true,
    mkix = true,
    mkxi = true,
 -- lfg  = true,
}

local sttags = table.setmetatableindex(function(t,fullname)
    local name = collapsepath(fullname)
    if blockedsuffixes[suffixonly(name)] then
        -- Just so that I don't get the ones on my development tree.
        nofblocked = nofblocked + 1
        return 0
    elseif blockedfilenames[nameonly(name)] then
        -- So we can block specific files.
        nofblocked = nofblocked + 1
        return 0
    elseif foundintree(name) then
        -- One shouldn't edit styles etc this way.
        nofblocked = nofblocked + 1
        return 0
    else
        noftags = noftags + 1
        t[name] = noftags
        if name ~= fullname then
            t[fullname] = noftags
        end
        stnums[noftags] = name
        return noftags
    end
end)

function synctex.blockfilename(name)
    blockedfilenames[nameonly(name)] = name
end

function synctex.setfilename(name,line)
    if paused == 0 and name then
        forceinputstatefile(sttags[name])
        if line then
            forceinputstateline(line)
        end
    end
end

function synctex.resetfilename()
    if paused == 0 then
        forceinputstatefile(0)
        forceinputstateline(0)
    end
end

do

    local nesting = 0
    local ignored = false

    function synctex.pushline()
        nesting = nesting + 1
        if nesting == 1 then
            local l = getinputstateline()
            ignored = l and l > 0
            if not ignored then
                forceinputstateline(texget("inputlineno"))
            end
        end
    end

    function synctex.popline()
        if nesting == 1 then
            if not ignored then
                forceinputstateline()
                ignored = false
            end
        end
        nesting = nesting - 1
    end

end

-- the node stuff

local filehandle = nil
local nofsheets  = 0
local nofobjects = 0
local last       = 0
local filesdone  = 0
local sncfile    = false

local function writeanchor()
    local size = filehandle:seek("end")
    filehandle:write("!",size-last,eol)
    last = size
end

local function writefiles()
    local total = #stnums
    if filesdone < total then
        for i=filesdone+1,total do
            filehandle:write("Input:",i,":",stnums[i],eol)
        end
        filesdone = total
    end
end

local function makenames()
    sncfile = replacesuffix(tex.jobname,"synctex")
end

local function flushpreamble()
    makenames()
    filehandle = openfile(sncfile,"wb")
    if filehandle then
        filehandle:write("SyncTeX Version:1",eol)
        writefiles()
        filehandle:write("Output:pdf",eol)
        filehandle:write("Magnification:1000",eol)
        filehandle:write("Unit:1",eol)
        filehandle:write("X Offset:0",eol)
        filehandle:write("Y Offset:0",eol)
        filehandle:write("Content:",eol)
        flushpreamble = function()
            writefiles()
            return filehandle
        end
    else
        enabled = false
    end
    return filehandle
end

function synctex.wrapup()
    sncfile = nil
end

local function flushpostamble()
    if not filehandle then
        return
    end
    writeanchor()
    filehandle:write("Postamble:",eol)
    filehandle:write("Count:",nofobjects,eol)
    writeanchor()
    filehandle:write("Post scriptum:",eol)
    filehandle:close()
    enabled = false
end

getpagedimensions = function()
    getpagedimensions = backends.codeinjections.getpagedimensions
    return getpagedimensions()
end

local x_hlist  do

    local function doaction(t,l,w,h,d)
        local pagewidth, pageheight = getpagedimensions() -- we could save some by setting it per page
        local x, y = getpos()
        y = pageheight - y
        if userule then
            -- This cheat works in viewers that use the newer library:
            filehandle:write(f_hlist(t,l,x,y,0,0,0)) -- w,h,d))
            filehandle:write(f_rule(t,l,x,y,w,h,d))
            filehandle:write(s_hlist)
        else
            -- This works in viewers that use the older library:
            filehandle:write(f_hvoid(t,l,x,y,w,h,d))
        end
        nofobjects = nofobjects + 1
    end

    x_hlist = function(head,current,t,l,w,h,d)
        if filehandle then
            return insertbefore(head,current,new_latelua(function() doaction(t,l,w,h,d) end))
        else
            return head
        end
    end

end

-- color is already handled so no colors

local collect      = nil
local fulltrace    = false
local trace        = false
local height       = 10 * 65536
local depth        =  5 * 65536
local traceheight  =      32768
local tracedepth   =      32768

trackers.register("system.synctex.visualize", function(v)
    trace     = v
    fulltrace = v == "real"
end)

local collect_min  do

    local function inject(head,first,last,tag,line)
        local w, h, d = getdimensions(first,getnext(last))
        if h < height then
            h = height
        end
        if d < depth then
            d = depth
        end
        if trace then
            head = insertbefore(head,first,new_rule(w,fulltrace and h or traceheight,fulltrace and d or tracedepth))
            head = insertbefore(head,first,new_kern(-w))
        end
        head = x_hlist(head,first,tag,line,w,h,d)
        return head
    end

    collect_min = function(head)
        local current = head
        while current do
            local id = getid(current)
            if id == glyph_code then
                local first = current
                local last  = current
                local tag   = 0
                local line  = 0
                while true do
                    if id == glyph_code then
                        local tc, lc = getinputfields(current)
                        if tc and tc > 0 then
                            tag  = tc
                            line = lc
                        end
                        last = current
                    elseif id == disc_code or (id == kern_code and getsubtype(current) == fontkern_code) then
                        last = current
                    else
                        if tag > 0 then
                            head = inject(head,first,last,tag,line)
                        end
                        break
                    end
                    current = getnext(current)
                    if current then
                        id = getid(current)
                    else
                        if tag > 0 then
                            head = inject(head,first,last,tag,line)
                        end
                        return head
                    end
                end
            end
            -- pick up (as id can have changed)
            if id == hlist_code or id == vlist_code then
                local list = getlist(current)
                if list then
                    local l = collect(list)
                    if l ~= list then
                        setlist(current,l)
                    end
                end
            end
            current = getnext(current)
        end
        return head
    end

end

local collect_max  do

    local function inject(parent,head,first,last,tag,line)
        local w, h, d = getrangedimensions(parent,first,getnext(last))
        if h < height then
            h = height
        end
        if d < depth then
            d = depth
        end
        if trace then
            head = insertbefore(head,first,new_rule(w,fulltrace and h or traceheight,fulltrace and d or tracedepth))
            head = insertbefore(head,first,new_kern(-w))
        end
        head = x_hlist(head,first,tag,line,w,h,d)
        return head
    end

    collect_max = function(head,parent)
        local current = head
        while current do
            local id = getid(current)
            if id == glyph_code then
                local first = current
                local last  = current
                local tag   = 0
                local line  = 0
                while true do
                    if id == glyph_code then
                        local tc, lc = getinputfields(current)
                        if tc and tc > 0 then
                            if tag > 0 and (tag ~= tc or line ~= lc) then
                                head  = inject(parent,head,first,last,tag,line)
                                first = current
                            end
                            tag  = tc
                            line = lc
                            last = current
                        else
                            if tag > 0 then
                                head = inject(parent,head,first,last,tag,line)
                                tag  = 0
                            end
                            first = nil
                            last  = nil
                        end
                    elseif id == disc_code then
                        if not first then
                            first = current
                        end
                        last = current
                    elseif id == kern_code and getsubtype(current) == fontkern_code then
                        if first then
                            last = current
                        end
                    elseif id == glue_code then
                     -- if tag > 0 then
                     --     local tc, lc = getinputfields(current)
                     --     if tc and tc > 0 then
                     --         if tag ~= tc or line ~= lc then
                     --             head = inject(parent,head,first,last,tag,line)
                     --             tag  = 0
                     --             break
                     --         end
                     --     else
                     --         head = inject(parent,head,first,last,tag,line)
                     --         tag  = 0
                     --         break
                     --     end
                     -- else
                     --     tag = 0
                     --     break
                     -- end
                     -- id = nil -- so no test later on
                    elseif id == penalty_code then
                        -- go on (and be nice for math)
                    else
                        if tag > 0 then
                            head = inject(parent,head,first,last,tag,line)
                            tag  = 0
                        end
                        break
                    end
                    current = getnext(current)
                    if current then
                        id = getid(current)
                    else
                        if tag > 0 then
                            head = inject(parent,head,first,last,tag,line)
                        end
                        return head
                    end
                end
            end
            -- pick up (as id can have changed)
            if id == hlist_code or id == vlist_code then
                local list = getlist(current)
                if list then
                    local l = collect(list,current)
                    if l and l ~= list then
                        setlist(current,l)
                    end
                end
            end
            current = getnext(current)
        end
        return head
    end

end

collect = collect_max

function synctex.collect(head,where)
    if enabled and where ~= "object" then
        return collect(head,head)
    else
        return head
    end
end

-- also no solution for bad first file resolving in sumatra

function synctex.start()
    if enabled then
        nofsheets = nofsheets + 1 -- could be realpageno
        if flushpreamble() then
            writeanchor()
            filehandle:write("{",nofsheets,eol)
            -- this seems to work:
         -- local pagewidth, pageheight = getpagedimensions()
            filehandle:write(f_plist(1,0,0,0,0,0,0))
        end
    end
end

function synctex.stop()
    if enabled then
        filehandle:write(s_plist)
        writeanchor()
        filehandle:write("}",nofsheets,eol)
        nofobjects = nofobjects + 2
    end
end

local enablers  = { }
local disablers = { }

function synctex.registerenabler(f)
    enablers[#enablers+1] = f
end

function synctex.registerdisabler(f)
    disablers[#disablers+1] = f
end

function synctex.enable(use_rule)
    if not never and not enabled then
        enabled = true
        userule = use_rule
        setinputstatemode(3) -- we want details
        if not used then
            nodes.tasks.enableaction("shipouts","luatex.synctex.collect")
            report_system("synctex functionality is enabled, expect 5-10 pct runtime overhead!")
            used = true
        end
        for i=1,#enablers do
            enablers[i](true)
        end
    end
end

function synctex.disable()
    if enabled then
        setinputstatemode(0)
        report_system("synctex functionality is disabled!")
        enabled = false
        for i=1,#disablers do
            disablers[i](false)
        end
    end
end

function synctex.finish()
    if enabled then
        flushpostamble()
    else
        makenames()
        removefile(sncfile)
    end
end

local filename = nil

function synctex.pause()
    paused = paused + 1
    if enabled and paused == 1 then
        setinputstatemode(0)
    end
end

function synctex.resume()
    if enabled and paused == 1 then
        setinputstatemode(3)
    end
    paused = paused - 1
end

-- not the best place

luatex.registerstopactions(synctex.finish)

statistics.register("synctex tracing",function()
    if used then
        return string.format("%i referenced files, %i files ignored, %i objects flushed, logfile: %s",
            noftags,nofblocked,nofobjects,sncfile)
    end
end)

local implement = interfaces.implement
local variables = interfaces.variables

function synctex.setup(t)
    if t.state == variables.never then
        synctex.disable() -- just in case
        never = true
        return
    end
    if t.method == variables.max then
        collect = collect_max
    else
        collect = collect_min
    end
    if t.state == variables.start then
        synctex.enable(false)
    elseif t.state == variables["repeat"] then
        synctex.enable(true)
    else
        synctex.disable()
    end
end

implement {
    name      = "synctexblockfilename",
    arguments = "string",
    actions   = synctex.blockfilename,
}

implement {
    name      = "synctexsetfilename",
    arguments = "string",
    actions   = synctex.setfilename,
}

implement {
    name      = "synctexresetfilename",
    actions   = synctex.resetfilename,
}

implement {
    name      = "setupsynctex",
    actions   = synctex.setup,
    arguments = {
        {
            { "state" },
            { "method" },
        },
    },
}

implement {
    name    = "synctexpause",
    actions = synctex.pause,
}

implement {
    name    = "synctexresume",
    actions = synctex.resume,
}

implement {
    name    = "synctexpushline",
    actions = synctex.pushline,
}

implement {
    name    = "synctexpopline",
    actions = synctex.popline,
}

implement {
    name    = "synctexdisable",
    actions = synctex.disable,
}
