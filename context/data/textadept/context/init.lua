local info = {
    version   = 1.002,
    comment   = "ini for textadept for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

if not textadept then
    return
end

-- The textadept documentation says that there can be a lexers directory under a user
-- directory but it's not in the package path. The next involved a bit or trial and
-- error in order to avoid crashes so I suppose it can be done better. If I use
-- textadept alongside scite I will make a different key binding. The code below is
-- a bit of a mess, which is a side effect of stepwise adaption combined with shared
-- iuse of code.
--
-- We use the commandline switch -u to point to the location where this file is located
-- as we then can keep it outside the program area. We also put some other files under
-- themes.
--
-- A problem is that scite needs the lexer.lua file while for textadept we don't want
-- to touch that one. So we end up with duplicate files. We cannot configure scite to
-- use an explicit lexer so both lexer paths have the same files except that the textadept
-- one has no lexer.lua there. Unfortunately themes is not requires's but always looked
-- up with an explicit path. (Maybe I should patch that.)
--
-- We are in one of:
--
-- tex/texmf-context/context/data/textadept/context
-- data/develop/context/scite/data/context/textadept

package.path = table.concat ( {
    --
    _USERHOME .. "/?.lua",
    --
    _USERHOME .. "/lexers/?.lua",
    _USERHOME .. "/modules/?.lua",
    _USERHOME .. "/themes/?.lua",
    _USERHOME .. "/data/?.lua",
    --
    package.path
    --
}, ';')

-- We now reset the session location to a writeable user area. We also take the opportunity
-- to increase the list.

local sessionpath = os.getenv(not WIN32 and 'HOME' or 'USERPROFILE') .. '/.textadept'
local sessionfile = not CURSES and 'session' or 'session_term'

textadept.session.default_session  = sessionpath .. "/" .. sessionfile
textadept.session.save_on_quit     = true
textadept.session.max_recent_files = 25

-- Let's load our adapted lexer framework.

require("scite-context-lexer")
require("textadept-context-runner")
require("textadept-context-files")
require("scite-context-theme")
require("textadept-context-settings")
require("textadept-context-types")

-- This prevents other themes to spoil our settings.

-- ui.set_theme("scite-context-theme")
buffer:set_theme("scite-context-theme")

-- Since version 10 there is some settings stuff in the main init file but that
-- crashes on load_settings. It has to do with the replacement of properties
-- but we already had that replaced for a while. There is some blob made that
-- gets loaded but it's not robust (should be done different I think). Anyway,
-- intercepting the two event handlers is easiest. Maybe some day I will
-- replace that init anyway (if these fundamentals keep changing between
-- versions.)
--
-- I admit that it's not a beautiful solution but it works ok and I already
-- spent too much time figuring things out anyway.

local events_connect = events.connect

local function events_newbuffer()
    local buffer = _G.buffer
    local SETDIRECTFUNCTION = _SCINTILLA.properties.direct_function[1]
    local SETDIRECTPOINTER  = _SCINTILLA.properties.doc_pointer[2]
    local SETLUASTATE       = _SCINTILLA.functions.change_lexer_state[1]
    local SETLEXERLANGUAGE  = _SCINTILLA.properties.lexer_language[2]
    buffer.lexer_language = 'lpeg'
    buffer:private_lexer_call(SETDIRECTFUNCTION, buffer.direct_function)
    buffer:private_lexer_call(SETDIRECTPOINTER, buffer.direct_pointer)
    buffer:private_lexer_call(SETLUASTATE, _LUA)
    buffer.property['lexer.lpeg.home'] = _USERHOME..'/lexers/?.lua;'.. _HOME..'/lexers'
 -- load_settings()
    buffer:private_lexer_call(SETLEXERLANGUAGE, 'text')
    if buffer == ui.command_entry then
        buffer.caret_line_visible = false
    end
end

-- Why these resets:

local ctrl_keys = {
    '[', ']', '/', '\\', 'Z', 'Y', 'X', 'C', 'V', 'A', 'L', 'T', 'D', 'U'
}

local ctrl_shift_keys = {
    'L', 'T', 'U', 'Z'
}

local function events_newview()
    local buffer = _G.buffer
    for i=1, #ctrl_keys do
        buffer:clear_cmd_key(string.byte(ctrl_keys[i]) | buffer.MOD_CTRL << 16)
    end
    for i=1, #ctrl_shift_keys do
        buffer:clear_cmd_key(string.byte(ctrl_shift_keys[i]) | (buffer.MOD_CTRL | buffer.MOD_SHIFT) << 16)
    end
    if #_VIEWS > 1 then
     -- load_settings()
        local SETLEXERLANGUAGE = _SCINTILLA.properties.lexer_language[2]
        buffer:private_lexer_call(SETLEXERLANGUAGE, buffer._lexer or 'text')
    end
end

events.connect = function(where,what,location)
    if location == 1 then
        if where == events.BUFFER_NEW then
            return events_connect(where,events_newbuffer,location)
        elseif where == events.VIEW_NEW then
            return events_connect(where,events_newview,location)
        end
    end
    return events_connect(where,what,location)
end

local savedrequire = require

require = function(name,...)
    return savedrequire(name == "lexer" and "scite-context-lexer" or name,...)
end
