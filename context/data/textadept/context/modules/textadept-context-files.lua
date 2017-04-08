local info = {
    version   = 1.002,
    comment   = "file handler for textadept for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer   = require("scite-context-lexer")
local context = lexer.context

local char, format = string.char, string.format

-- What is _CHARSET doing ... I don't want any messing with conversion at all. Scite is
-- more clever with e.g. pdf. How can I show non ascii as escapes.

io.encodings = {
    "UTF-8",
    "ASCII",
    "UTF-16",
}

-- We need this for for instance pdf files (faster too):

local sevenbitascii   = { }
for i=127,255 do
    sevenbitascii[char(i)] = format("0x%02X",i)
end

local function setsevenbitascii(buffer)
    -- we cannot directly assign sevenbitascii to buffer
    local representation = buffer.representation
    for k, v in next, sevenbitascii do
        representation[k] = v
    end
end

-- Here we rebind keys. For this we need to load the alternative runner framework. I will
-- probably change the menu.

local oldrunner = textadept.run
local runner    = require("textadept-context-runner")

local function userunner(runner)
    keys [OSX and 'mr' or                  'cr'  ] = runner.process or runner.run
    keys [OSX and 'mR' or (GUI and 'cR' or 'cmr')] = runner.check   or runner.compile
    keys [OSX and 'mB' or (GUI and 'cB' or 'cmb')] = runner.preview or runner.build
    keys [OSX and 'mX' or (GUI and 'cX' or 'cmx')] = runner.quit    or runner.stop
    textadept.menu.menubar [_L['_Tools']] [_L['_Run']]     [2] = runner.process or runner.run
    textadept.menu.menubar [_L['_Tools']] [_L['_Compile']] [2] = runner.check   or runner.compile
    textadept.menu.menubar [_L['_Tools']] [_L['Buil_d']]   [2] = runner.preview or runner.build
    textadept.menu.menubar [_L['_Tools']] [_L['S_top']]    [2] = runner.quit    or runner.stop
    return poprunner
end

userunner(runner)

-- We have a different way to set up files and runners. Less distributed and morein the way we
-- do things in context.

local dummyrunner    = function() end
local extensions     = textadept.file_types.extensions
local specifications = runner.specifications
local setters        = { }
local defaults       = {
    check   = dummyrunner,
    process = dummyrunner,
    preview = dummyrunner,
}

setmetatable(specifications, { __index = defaults })

function context.install(specification)
    local suffixes = specification.suffixes
    if suffixes then
        local lexer    = specification.lexer
        local setter   = specification.setter
        local encoding = specification.encoding
        for i=1,#suffixes do
            local suffix = suffixes[i]
            if lexer and extensions then
                extensions[suffix] = lexer
            end
            specifications[suffix] = specification
            if lexer then
                setters[lexer] = function()
                    if encoding == "7-BIT-ASCII" then
                        setsevenbitascii(buffer)
                    end
                    if setter then
                        setter(lexer)
                    end
                end
            end
        end
    end
end

local function synchronize(lexer)
    local setter = lexer and setters[lexer]
    if setter then
        local action = context.synchronize
        if action then
            action()
        end
        userunner(runner)
        setter(lexer)
    else
        userunner(oldrunner)
    end
end

events.connect(events.FILE_OPENED,function(filename)
    synchronize(buffer.get_lexer(buffer))
end)

events.connect(events.LEXER_LOADED,function(lexer)
    synchronize(lexer)
end)
