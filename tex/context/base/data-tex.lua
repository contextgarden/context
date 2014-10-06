if not modules then modules = { } end modules ['data-tex'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local char, find = string.char, string.find
local insert, remove = table.insert, table.remove

local trace_locating = false trackers.register("resolvers.locating", function(v) trace_locating = v end)

local report_tex = logs.reporter("resolvers","tex")

local resolvers = resolvers

local sequencers        = utilities.sequencers
local methodhandler     = resolvers.methodhandler
local splitlines        = string.splitlines
local utffiletype       = utf.filetype
local setmetatableindex = table.setmetatableindex

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

local helpers     = resolvers.openers.helpers
local appendgroup = sequencers.appendgroup

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

resolvers.inputstack = resolvers.inputstack or { }

local inputstack = resolvers.inputstack

function helpers.textopener(tag,filename,filehandle,coding)
    local lines
    local t_filehandle = type(filehandle)
    if not filehandle then
        lines = io.loaddata(filename)
    elseif t_filehandle == "string" then
        lines = filehandle
    elseif t_filehandle == "table" then
        lines = filehandle
    else
        lines = filehandle:read("*a") -- io.readall(filehandle) ... but never that large files anyway
     -- lines = io.readall(filehandle)
        filehandle:close()
    end
    if type(lines) == "string" then
        local coding = coding or utffiletype(lines) -- so we can signal no regime
        if trace_locating then
            report_tex("%a opener: %a opened using method %a",tag,filename,coding)
        end
        if coding == "utf-16-be" then
            lines = utf.utf16_to_utf8_be_t(lines)
        elseif coding == "utf-16-le" then
            lines = utf.utf16_to_utf8_le_t(lines)
        elseif coding == "utf-32-be" then
            lines = utf.utf32_to_utf8_be_t(lines)
        elseif coding == "utf-32-le" then
            lines = utf.utf32_to_utf8_le_t(lines)
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
    logs.show_open(filename)
    insert(inputstack,filename)
    local currentline, noflines = 0, noflines
    local t = {
        filename    = filename,
        noflines    = noflines,
     -- currentline = 0,
        close       = function()
            if trace_locating then
                report_tex("%a closer: %a closed",tag,filename)
            end
            logs.show_close(filename)
            remove(inputstack)
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
                if not content then
                    return nil
                elseif content == "" then
                    return ""
             -- elseif content == ctrl_d or ctrl_z then
             --     return nil -- we need this as \endinput does not work in prints
                else
                    local runner = textlineactions.runner
                    if runner then
                        return runner(content,filename,currentline,noflines,coding) or content
                    else
                        return content
                    end
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
    local ok, data, size = resolvers.loadbinfile(filename, filetype)
    return data or ""
end

resolvers.texdatablob = resolvers.loadtexfile

local function installhandler(namespace,what,where,func)
    if not func then
        where, func = "after", where
    end
    if where == "before" or where == "after" then
        sequencers.appendaction(namespace,where,func)
    else
        report_tex("installing input %a handlers in %a is not possible",what,tostring(where))
    end
end

function resolvers.installinputlinehandler(...) installhandler(helpers.textlineactions,"line",...) end
function resolvers.installinputfilehandler(...) installhandler(helpers.textfileactions,"file",...) end

-- local basename = file.basename
-- resolvers.installinputlinehandler(function(str,filename,linenumber,noflines)
--     report_tex("[lc] file %a, line %a of %a, length %a",basename(filename),linenumber,noflines,#str)
-- end)
-- resolvers.installinputfilehandler(function(str,filename)
--     report_tex("[fc] file %a, length %a",basename(filename),#str)
-- end)
