if not modules then modules = { } end modules ['font-tmp'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- There is a complet efeature loader but it needs a bit of testing, first so this
-- one does design size only (as needed for identifying).

local next, type = next, type

local report     = logs.reporter("otf reader")

local files      = utilities.files

local readushort = files.readcardinal2  -- 16-bit unsigned integer
local readulong  = files.readcardinal4  -- 24-bit unsigned integer
local readshort  = files.readinteger2   -- 16-bit   signed integer

local readtag    = function(f) return f:read(4) end
local skipshort  = function(f,n) f:read(n and 2*n or 2) end

local readers    = fonts.handlers.otf.readers

local plugins    = { }

function plugins.size(f,fontdata,tableoffset,parameters)
    if not fontdata.designsize then
        f:seek("set",tableoffset+parameters)
        local designsize = readushort(f)
        if designsize > 0 then
            fontdata.designsize = designsize
            skipshort(f,2)
            fontdata.minsize = readushort(f)
            fontdata.maxsize = readushort(f)
        end
    end
end

local function readscripts(f,fontdata,what)
    local datatable = fontdata.tables[what]
    if not datatable then
        return
    end
    local tableoffset = datatable.offset
    f:seek("set",tableoffset)
    local version = readulong(f)
    if version ~= 0x00010000 then
        report("table version %a of %a is not supported (yet), maybe font %s is bad",version,what,fontdata.filename)
        return
    end
    --
    local scriptoffset  = tableoffset + readushort(f)
    local featureoffset = tableoffset + readushort(f)
    local lookupoffset  = tableoffset + readushort(f)
    --
    f:seek("set",scriptoffset)
    local nofscripts = readushort(f)
    local scripts    = { }
    for i=1,nofscripts do
        scripts[readtag(f)] = scriptoffset + readushort(f)
    end
    local languagesystems = table.setmetatableindex("table") -- we share when possible
    for script, offset in next, scripts do
        f:seek("set",offset)
        local defaultoffset = readushort(f)
        local noflanguages  = readushort(f)
        local languages     = { }
        if defaultoffset > 0 then
            languages.dflt = languagesystems[offset + defaultoffset]
        end
        for i=1,noflanguages do
            local language      = readtag(f)
            local offset        = offset + readushort(f)
            languages[language] = languagesystems[offset]
        end
        scripts[script] = languages
    end
    --
    f:seek("set",featureoffset)
    local features    = { }
    local noffeatures = readushort(f)
    for i=1,noffeatures do
        features[i] = {
            tag    = readtag(f),
            offset = readushort(f)
        }
    end
    --
    for i=1,noffeatures do
        local feature = features[i]
        local offset  = featureoffset + feature.offset
        f:seek("set",offset)
        local parameters = readushort(f) -- feature.parameters
        local noflookups = readushort(f)
        skipshort(f,noflookups+1)
        if parameters > 0 then
            feature.parameters = parameters
            local plugin = plugins[feature.tag]
            if plugin then
                plugin(f,fontdata,offset,parameters)
            end
        end
    end
end

function readers.gsub(f,fontdata,specification)
    if specification.details then
        readscripts(f,fontdata,"gsub")
    end
end

function readers.gpos(f,fontdata,specification)
    if specification.details then
        readscripts(f,fontdata,"gpos")
    end
end

