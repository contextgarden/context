if not modules then modules = { } end modules ['data-tex'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tostring, tonumber, type = tostring, tonumber, type
local char, find = string.char, string.find

local trace_locating = false trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_tex = logs.reporter("resolvers","tex")


local sequencers        = utilities.sequencers
local utffiletype       = utf.filetype
local setmetatableindex = table.setmetatableindex
local loaddata          = io.loaddata
----- readall           = io.readall

local resolvers         = resolvers
local methodhandler     = resolvers.methodhandler
local loadbinfile       = resolvers.loadbinfile
local pushinputname     = resolvers.pushinputname
local popinputname      = resolvers.popinputname

-- local fileprocessor = nil
-- local lineprocessor = nil

local textfileactions = sequencers.new {
    arguments    = "str,filename,coding",
    returnvalues = "str",
    results      = "str",
}

local textlineactions = sequencers.new {
    arguments    = "str,filename,linenumber,noflines,coding",
    returnvalues = "str",
    results      = "str",
}

local helpers      = resolvers.openers.helpers
local appendgroup  = sequencers.appendgroup
local appendaction = sequencers.appendaction

helpers.textfileactions = textfileactions
helpers.textlineactions = textlineactions

appendgroup(textfileactions,"before") -- user
appendgroup(textfileactions,"system") -- private
appendgroup(textfileactions,"after" ) -- user

appendgroup(textlineactions,"before") -- user
appendgroup(textlineactions,"system") -- private
appendgroup(textlineactions,"after" ) -- user

local ctrl_d = char( 4) -- unix
local ctrl_z = char(26) -- windows

----------------------------------------

local lpegmatch  = lpeg.match
local newline    = lpeg.patterns.newline
local tsplitat   = lpeg.tsplitat

local linesplitters = {
    tsplitat(newline),                       -- default since we started
    tsplitat(lpeg.S(" ")^0 * newline),
    tsplitat(lpeg.S(" \t")^0 * newline),
    tsplitat(lpeg.S(" \f\t")^0 * newline),   -- saves a bit of space at the cost of runtime
 -- tsplitat(lpeg.S(" \v\f\t")^0 * newline),
 -- tsplitat(lpeg.R("\0\31")^0 * newline),
}

local linesplitter = linesplitters[1]

directives.register("system.linesplitmethod",function(v)
    linesplitter = linesplitters[tonumber(v) or 1] or linesplitters[1]
end)

local function splitlines(str)
    return lpegmatch(linesplitter,str)
end

-----------------------------------------

local wideutfcoding = {
    ["utf-16-be"] = utf.utf16_to_utf8_be_t,
    ["utf-16-le"] = utf.utf16_to_utf8_le_t,
    ["utf-32-be"] = utf.utf32_to_utf8_be_t,
    ["utf-32-le"] = utf.utf32_to_utf8_le_t,
}

local function textopener(tag,filename,filehandle,coding)
    local lines
    local t_filehandle = type(filehandle)
    if not filehandle then
        lines = loaddata(filename)
    elseif t_filehandle == "string" then
        lines = filehandle
    elseif t_filehandle == "table" then
        lines = filehandle
    else
        lines = filehandle:read("*a") -- readall(filehandle) ... but never that large files anyway
     -- lines = readall(filehandle)
        filehandle:close()
    end
    if type(lines) == "string" then
        local coding = coding or utffiletype(lines) -- so we can signal no regime
        if trace_locating then
            report_tex("%a opener: %a opened using method %a",tag,filename,coding)
        end
        local wideutf = wideutfcoding[coding]
        if wideutf then
            lines = wideutf(lines)
        else -- utf8 or unknown (could be a mkvi file)
            local runner = textfileactions.runner
            if runner then
                lines = runner(lines,filename,coding) or lines
            end
            lines = splitlines(lines)
        end
    elseif trace_locating then
        report_tex("%a opener: %a opened",tag,filename)
    end
    local noflines = #lines
    if lines[noflines] == "" then -- maybe some special check is needed
        lines[noflines] = nil
    end
    pushinputname(filename)
    local currentline, noflines = 0, noflines
    local t = {
        filename    = filename,
        noflines    = noflines,
     -- currentline = 0,
        close       = function()
            local usedname = popinputname() -- should match filename
            if trace_locating then
                report_tex("%a closer: %a closed",tag,filename)
            end
            t = nil
        end,
        reader      = function(self)
            self = self or t
         -- local currentline, noflines = self.currentline, self.noflines
            if currentline >= noflines then
                return nil
            else
                currentline = currentline + 1
             -- self.currentline = currentline
                local content = lines[currentline]
                if content == "" then
                    return ""
             -- elseif content == ctrl_d or ctrl_z then
             --     return nil -- we need this as \endinput does not work in prints
                elseif content then
                    local runner = textlineactions.runner
                    if runner then
                        return runner(content,filename,currentline,noflines,coding) or content
                    else
                        return content
                    end
                else
                    return nil
                end
            end
        end
    }
    setmetatableindex(t,function(t,k)
        if k == "currentline" then
            return currentline
        else
            -- no such key
        end
    end)
    return t
end

helpers.settextopener(textopener) -- can only be done once

function resolvers.findtexfile(filename,filetype)
    return methodhandler('finders',filename,filetype)
end

function resolvers.opentexfile(filename)
    return methodhandler('openers',filename)
end

function resolvers.openfile(filename)
    local fullname = methodhandler('finders',filename)
    return fullname and fullname ~= "" and methodhandler('openers',fullname) or nil
end

function resolvers.loadtexfile(filename,filetype)
    -- todo: optionally apply filters
    local ok, data, size = loadbinfile(filename, filetype)
    return data or ""
end

resolvers.texdatablob = resolvers.loadtexfile

local function installhandler(namespace,what,where,func)
    if not func then
        where, func = "after", where
    end
    if where == "before" or where == "after" then
        appendaction(namespace,where,func)
    else
        report_tex("installing input %a handlers in %a is not possible",what,tostring(where))
    end
end

function resolvers.installinputlinehandler(...) installhandler(textlineactions,"line",...) end
function resolvers.installinputfilehandler(...) installhandler(textfileactions,"file",...) end

-- local basename = file.basename
-- resolvers.installinputlinehandler(function(str,filename,linenumber,noflines)
--     report_tex("[lc] file %a, line %a of %a, length %a",basename(filename),linenumber,noflines,#str)
-- end)
-- resolvers.installinputfilehandler(function(str,filename)
--     report_tex("[fc] file %a, length %a",basename(filename),#str)
-- end)
