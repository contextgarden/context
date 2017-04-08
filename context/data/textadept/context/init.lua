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

ui.set_theme("scite-context-theme")
