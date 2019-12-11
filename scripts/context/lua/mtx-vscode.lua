if not modules then modules = { } end modules ['mtx-vscode'] = {
    version   = 1.000,
    comment   = "this script is experimental",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE",
    license   = "see context related readme files"
}

-- todo: folding and comments
-- todo: runners (awaiting global script setup)
-- todo: dark theme

-- Already for quite a while lexing in ConTeXt is kind of standardized and the way
-- the format evolved also relates to how I see the source. We started with lexing
-- beginning of 1990 with texedit/wdt in Modula2 and went via perltk (texwork),
-- Scite (native), Scite (lpeg) as well as different stages in verbatim. So, as
-- github uses VSCODE I decided to convert the couple of base lexers to the format
-- that this editor likes. It's all about habits and consistency, not about tons of
-- fancy features that I don't need and would not use anyway.
--
-- I use a lua script to generate the lexer definitions simply because that way the
-- update will be in sync with the updates in the context distribution.
--
--   code.exe --extensions-dir e:\vscode\extensions --install-extension context
--
-- In the end all these systems look alike so again we we have these token onto
-- styling mappings. We even have embedded lexers. Actually, when reading the
-- explanations it has become internally more close to what scintilla does with
-- tokens and numbers related to it but then mapped back onto css.
--
-- Multiline lexing is a pain here, so I just assume that stuff belonging together is
-- on one line (like keys to simple values). I'm not in the mood for ugly multistep
-- parsing now. Here the lpeg lexers win.
--
-- We can optimize these expressions if needed but it all looks fast enough. Anyway,
-- we do start from the already old lexers that we use in SciTe. The lexing as well
-- as use of colors is kind of consistent and standardized in context and I don't
-- want to change it. The number of colors is not that large and (at least to me) it
-- looks less extreme. We also use a gray background because over time we figured
-- out that this works best (1) for long sessions, and (2) for colors. We have quite
-- some embedding so that is another reason for consistency.
--
-- I do remember generating plist files many years ago but stopped doing that
-- because I never could check them in practice. We're now kind of back to that. The
-- reason for using a lua script to generate the json file is that it is easier to
-- keep in sync with context and also because then a user can just generate the
-- extension her/himself.
--
-- There are nice examples of lexer definitions in the vc extensions path. My regexp
-- experiences are somewhat rusted and I don't really have intentions to spend too
-- much time on them. Compared to the lpeg lexers the regexp based ones are often
-- more compact. It's just a different concept. Anyway, I might improve things after
-- I've read more of the specs (it seems like the regexp engine is the one from ruby).

-- We normally use a light gray background with rather dark colors which at least
-- for us is less tiresome. The problem with dark backgrounds is that one needs to
-- use light colors from pastel palettes. I need to figure out a mapping that works
-- for a dark background so that optionally one can install without color theme.

-- It is possible to define tasks and even relate them to languages but for some reason
-- it can not be done global but per workspace which makes using vscode no option for
-- me (too many different folders with source code, documentation etc). It's kind of
-- strange because simple runners are provided by many editors. I don't want to program
-- a lot to get such simple things done so, awaiting global tasks I stick to using the
-- terminal. But we're prepared.

-- Another showstopper is the fact that we cannot disable utf8 for languages (like pdf,
-- which is just bytes). I couldn't figure out how to set it in the extension.

-- {
--     "window.zoomLevel": 2,
--     "editor.renderWhitespace": "all",
--     "telemetry.enableCrashReporter": false,
--     "telemetry.enableTelemetry": false,
--     "editor.fontFamily": "Dejavu Sans Mono, Consolas, 'Courier New', monospace",
--     "window.autoDetectHighContrast": false,
--     "zenMode.hideLineNumbers": false,
--     "zenMode.centerLayout": false,
--     "zenMode.fullScreen": false,
--     "zenMode.hideTabs": false,
--     "workbench.editor.showIcons": false,
--     "workbench.settings.enableNaturalLanguageSearch": false,
--     "window.enableMenuBarMnemonics": false,
--     "search.location": "panel",
--     "breadcrumbs.enabled": false,
--     "workbench.activityBar.visible": false,
--     "editor.minimap.enabled": false,
--     "workbench.iconTheme": null,
--     "extensions.ignoreRecommendations": true,
--     "editor.renderControlCharacters": true,
--     "terminal.integrated.scrollback": 5000,
--     "workbench.colorTheme": "ConTeXt",
--     "[context.cld]": {},
--     "terminal.integrated.fontSize": 10,
--     "terminal.integrated.rendererType": "dom",
--     "workbench.colorCustomizations": {
--         "terminal.ansiBlack":         "#000000",
--         "terminal.ansiWhite":         "#FFFFFF",
--         "terminal.ansiRed":           "#7F0000",
--         "terminal.ansiGreen":         "#007F00",
--         "terminal.ansiBlue":          "#00007F",
--         "terminal.ansiMagenta":       "#7F007F",
--         "terminal.ansiCyan":          "#007F7F",
--         "terminal.ansiYellow":        "#7F7F00",
--         "terminal.ansiBrightBlack":   "#000000",
--         "terminal.ansiBrightWhite":   "#FFFFFF",
--         "terminal.ansiBrightRed":     "#7F0000",
--         "terminal.ansiBrightGreen":   "#007F00",
--         "terminal.ansiBrightBlue":    "#00007F",
--         "terminal.ansiBrightMagenta": "#7F007F",
--         "terminal.ansiBrightCyan":    "#007F7F",
--         "terminal.ansiBrightYellow":  "#7F7F00",
--     }
-- }

-- kind of done:
--
--   tex mps lua cld bibtex sql bnf(untested) pdf xml json c(pp)(simplified)
--
-- unlikely to be done (ok, i'm not interested in all this ide stuff anyway):
--
--   cpp-web tex-web web web-snippets txt
--
-- still todo:
--
--   xml: preamble and dtd
--   pdf: nested string (..(..)..)

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-vscode</entry>
  <entry name="detail">vscode extension generator</entry>
  <entry name="version">1.00</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="generate"><short>generate extension in sync with current version</short></flag>
    <flag name="start"><short>start vscode with extension context</short></flag>
   </subcategory>
  </category>
 </flags>
 <examples>
  <category>
   <title>Example</title>
   <subcategory>
    <example><command>mtxrun --script vscode --generate e:/vscode/extensions</command></example>
    <example><command>mtxrun --script vscode --generate</command></example>
    <example><command>mtxrun --script vscode --start</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
    name     = "mtx-vscode",
    banner   = "vscode extension generator",
    helpinfo = helpinfo,
}

local report = application.report

require("util-jsn")

scripts        = scripts        or { }
scripts.vscode = scripts.vscode or { }

local readmedata = [[
These files are generated. You can use these extensions with for instance:

  code.exe --extensions-dir <someplace>/tex/texmf-context/context/data/vscode/extensions --install-extension context

There are examples of scripts and keybindings too.
]]

local function locate()
    local name = resolvers.findfile("vscode-context.readme")
    if name and name ~= "" then
        local path = file.dirname(file.dirname(name))
        if lfs.isdir(path) then
            return path
        end
    end
end

function scripts.vscode.generate(targetpath)

    local targetpath = targetpath or environment.files[1] or locate()

    if not targetpath or targetpath == "" or not lfs.isdir(targetpath) then
        report("invalid targetpath %a",targetpath)
        return
    end

    local contextpath = string.gsub(targetpath,"\\","/")  .. "/context"

    dir.makedirs(contextpath)

    if not lfs.chdir(contextpath) then
        return
    end

    local syntaxpath     = contextpath .. "/syntaxes"
    local themepath      = contextpath .. "/themes"
    local taskpath       = contextpath .. "/tasks"
    local keybindingpath = contextpath .. "/keybindings"
    local settingspath   = contextpath .. "/settings"

    dir.makedirs(syntaxpath)
    dir.makedirs(themepath)
    dir.makedirs(taskpath)
    dir.makedirs(keybindingpath)
    dir.makedirs(settingspath)

    if not lfs.isdir(syntaxpath)     then return end
    if not lfs.isdir(themepath)      then return end
    if not lfs.isdir(taskpath)       then return end
    if not lfs.isdir(keybindingpath) then return end
    if not lfs.isdir(settingspath)   then return end

    -- The package.

    local languages    = { }
    local grammars     = { }
    local themes       = { }
    local tasks        = { }
    local keybindings  = { }

    local function registerlexer(lexer)

        local category    = lexer.category
        local contextid   = "context." .. category
        local scope       = "source." .. contextid

        local setupfile   = "./settings/context-settings-" .. category .. ".json"
        local grammarfile = "./syntaxes/context-syntax-" .. category .. ".json"

        local grammar = utilities.json.tojson {
            name       = contextid,
            scopeName  = scope,
            version    = lexer.version,
            repository = lexer.repository,
            patterns   = lexer.patterns,
        }

        local setup = utilities.json.tojson(lexer.setup)

        local suffixes   = lexer.suffixes or { }
        local extensions = { }

        for i=1,#suffixes do
            extensions[i] = "." .. string.gsub(suffixes[i],"%.","")
        end

        table.sort(extensions)

        languages[#languages+1] = {
            id            = contextid,
            extensions    = #extensions > 0 and extensions or nil,
            aliases       = { lexer.description },
            configuration = setupfile,
        }

        grammars[#grammars+1] = {
            language  = contextid,
            scopeName = "source." .. contextid,
            path      = grammarfile,
        }

        report("saving grammar for %a in %a",category,grammarfile)
        report("saving setup for %a in %a",category,setupfile)

        io.savedata(grammarfile, grammar)
        io.savedata(setupfile, setup)

    end

    local function registertheme(theme)

        local category = theme.category
        local filename = "./themes/" .. category .. ".json"

        themes[#themes+1] = {
            label   = theme.description,
            uiTheme = "vs",
            path    = filename,
        }

        local data = utilities.json.tojson {
            ["$schema"]     = "vscode://schemas/color-theme",
            ["name"]        = category,
            ["colors"]      = theme.colors,
            ["tokenColors"] = theme.styles,
        }

        report("saving theme %a in %a",category,filename)

        io.savedata(filename,data)

    end

    local function registertask(task)

        local category = task.category
        local filename = "./tasks/" .. category .. ".json"

        tasks[#tasks+1] = {
            label = task.description,
            path  = filename,
        }

        local data = utilities.json.tojson {
            ["name"]  = category,
            ["tasks"] = task.tasks,
        }

        report("saving task %a in %a",category,filename)
        io.savedata(filename,data)

    end

    local function registerkeybinding(keybinding)

        local bindings = keybinding.keybindings

        if bindings then

            local category = keybinding.category
            local filename = "./keybindings/" .. category .. ".json"

            report("saving keybinding %a in %a",category,filename)

            io.savedata(filename,utilities.json.tojson(bindings))

            for i=1,#bindings do
                 keybindings[#keybindings+1] = bindings[i]
            end

        end
    end

    local function savepackage()

        local packagefile  = "package.json"
        local whateverfile = "package.nls.json"
        local readmefile   = "vscode-context.readme"

        local specification = utilities.json.tojson {
            name        = "context",
            displayName = "ConTeXt",
            description = "ConTeXt Syntax Highlighting",
            publisher   = "ConTeXt Development Team",
            version     = "1.0.0",
            engines     = {
                vscode = "*"
            },
            categories = {
                "Lexers",
                "Syntaxes"
            },
            contributes = {
                languages   = languages,
                grammars    = grammars,
                themes      = themes,
                tasks       = tasks,
                keybindings = keybindings,
            },

        }

        report("saving package in %a",packagefile)

        io.savedata(packagefile,specification)

        local whatever = utilities.json.tojson {
            displayName = "ConTeXt",
            description = "Provides syntax highlighting and bracket matching in ConTeXt files.",
        }

        report("saving whatever in %a",whateverfile)

        io.savedata(whateverfile,whatever)

        report("saving readme in %a",readmefile)

        io.savedata(readmefile,readmedata)

    end

    -- themes

    do

        local mycolors = {
            red       = "#7F0000",
            green     = "#007F00",
            blue      = "#00007F",
            cyan      = "#007F7F",
            magenta   = "#7F007F",
            yellow    = "#7F7F00",
            orange    = "#B07F00",
            white     = "#FFFFFF",
            light     = "#CFCFCF",
            grey      = "#808080",
            dark      = "#4F4F4F",
            black     = "#000000",
            selection = "#F7F7F7",
            logpanel  = "#E7E7E7",
            textpanel = "#CFCFCF",
            linepanel = "#A7A7A7",
            tippanel  = "#444444",
            right     = "#0000FF",
            wrong     = "#FF0000",
        }

        local colors = {
            ["editor.background"]               = mycolors.textpanel,
            ["editor.foreground"]               = mycolors.black,
            ["editorLineNumber.foreground"]     = mycolors.black,
            ["editorIndentGuide.background"]    = mycolors.textpanel,
            ["editorBracketMatch.background"]   = mycolors.textpanel,
            ["editorBracketMatch.border"]       = mycolors.orange,
            ["editor.lineHighlightBackground"]  = mycolors.textpanel,
            ["focusBorder"]                     = mycolors.black,

            ["activityBar.background"]          = mycolors.black,

            ["sideBar.background"]              = mycolors.linepanel,
            ["sideBar.foreground"]              = mycolors.black,
            ["sideBar.border"]                  = mycolors.white,
            ["sideBarTitle.foreground"]         = mycolors.black,
            ["sideBarSectionHeader.background"] = mycolors.linepanel,
            ["sideBarSectionHeader.foreground"] = mycolors.black,

            ["statusBar.foreground"]            = mycolors.black,
            ["statusBar.background"]            = mycolors.linepanel,
            ["statusBar.border"]                = mycolors.white,
            ["statusBar.noFolderForeground"]    = mycolors.black,
            ["statusBar.noFolderBackground"]    = mycolors.linepanel,
            ["statusBar.debuggingForeground"]   = mycolors.black,
            ["statusBar.debuggingBackground"]   = mycolors.linepanel,

            ["notification.background"]         = mycolors.black,
        }

        local styles = {

            { scope = "context.whitespace",              settings = { } },
            { scope = "context.default",                 settings = { foreground = mycolors.black } },
            { scope = "context.number",                  settings = { foreground = mycolors.cyan } },
            { scope = "context.comment",                 settings = { foreground = mycolors.yellow } },
            { scope = "context.keyword",                 settings = { foreground = mycolors.blue, fontStyle = "bold" } },
            { scope = "context.string",                  settings = { foreground = mycolors.magenta } },
            { scope = "context.error",                   settings = { foreground = mycolors.red } },
            { scope = "context.label",                   settings = { foreground = mycolors.red, fontStyle = "bold"  } },
            { scope = "context.nothing",                 settings = { } },
            { scope = "context.class",                   settings = { foreground = mycolors.black, fontStyle = "bold" } },
            { scope = "context.function",                settings = { foreground = mycolors.black, fontStyle = "bold" } },
            { scope = "context.constant",                settings = { foreground = mycolors.cyan, fontStyle = "bold" } },
            { scope = "context.operator",                settings = { foreground = mycolors.blue } },
            { scope = "context.regex",                   settings = { foreground = mycolors.magenta } },
            { scope = "context.preprocessor",            settings = { foreground = mycolors.yellow, fontStyle = "bold" } },
            { scope = "context.tag",                     settings = { foreground = mycolors.cyan } },
            { scope = "context.type",                    settings = { foreground = mycolors.blue } },
            { scope = "context.variable",                settings = { foreground = mycolors.black } },
            { scope = "context.identifier",              settings = { } },
            { scope = "context.linenumber",              settings = { background = mycolors.linepanel } },
            { scope = "context.bracelight",              settings = { foreground = mycolors.orange, fontStyle = "bold" } },
            { scope = "context.bracebad",                settings = { foreground = mycolors.orange, fontStyle = "bold" } },
            { scope = "context.controlchar",             settings = { } },
            { scope = "context.indentguide",             settings = { foreground = mycolors.linepanel, back = colors.white } },
            { scope = "context.calltip",                 settings = { foreground = mycolors.white, back = colors.tippanel } },
            { scope = "context.invisible",               settings = { background = mycolors.orange } },
            { scope = "context.quote",                   settings = { foreground = mycolors.blue, fontStyle = "bold" } },
            { scope = "context.special",                 settings = { foreground = mycolors.blue } },
            { scope = "context.extra",                   settings = { foreground = mycolors.yellow } },
            { scope = "context.embedded",                settings = { foreground = mycolors.black, fontStyle = "bold" } },
            { scope = "context.char",                    settings = { foreground = mycolors.magenta } },
            { scope = "context.reserved",                settings = { foreground = mycolors.magenta, fontStyle = "bold" } },
            { scope = "context.definition",              settings = { foreground = mycolors.black, fontStyle = "bold" } },
            { scope = "context.okay",                    settings = { foreground = mycolors.dark } },
            { scope = "context.warning",                 settings = { foreground = mycolors.orange } },
            { scope = "context.standout",                settings = { foreground = mycolors.orange, fontStyle = "bold" } },
            { scope = "context.command",                 settings = { foreground = mycolors.green, fontStyle = "bold" } },
            { scope = "context.internal",                settings = { foreground = mycolors.orange, fontStyle = "bold" } },
            { scope = "context.preamble",                settings = { foreground = mycolors.yellow } },
            { scope = "context.grouping",                settings = { foreground = mycolors.red } },
            { scope = "context.primitive",               settings = { foreground = mycolors.blue, fontStyle = "bold" } },
            { scope = "context.plain",                   settings = { foreground = mycolors.dark, fontStyle = "bold" } },
            { scope = "context.user",                    settings = { foreground = mycolors.green } },
            { scope = "context.data",                    settings = { foreground = mycolors.cyan, fontStyle = "bold" } },
            { scope = "context.text",                    settings = { foreground = mycolors.black } },

            { scope = { "emphasis" }, settings = { fontStyle = "italic" } },
            { scope = { "strong"   }, settings = { fontStyle = "bold"   } },

            { scope = { "comment"  }, settings = { foreground = mycolors.black  } },
            { scope = { "string"   }, settings = { foreground = mycolors.magenta } },

            {
                scope = {
                    "constant.numeric",
                    "constant.language.null",
                    "variable.language.this",
                    "support.type.primitive",
                    "support.function",
                    "support.variable.dom",
                    "support.variable.property",
                    "support.variable.property",
                    "meta.property-name",
                    "meta.property-value",
                    "support.constant.handlebars"
                },
                settings = {
                    foreground = mycolors.cyan,
                }
            },

            {
                scope = {
                    "keyword",
                    "storage.modifier",
                    "storage.type",
                    "variable.parameter"
                },
                settings = {
                    foreground = mycolors.blue,
                    fontStyle  = "bold",
                }
            },

            {
                scope = {
                    "entity.name.type",
                    "entity.other.inherited-class",
                    "meta.function-call",
                    "entity.other.attribute-name",
                    "entity.name.function.shell"
                },
                settings = {
                    foreground = mycolors.black,
                }
            },

            {
                scope = {
                    "entity.name.tag",
                },
                settings = {
                    foreground = mycolors.black,
                }
            },

        }

        registertheme {
            category    = "context",
            description = "ConTeXt",
            colors      = colors,
            styles      = styles,
        }

    end

    do

        local presentation = {
            echo             = true,
            reveal           = "always",
            focus            = false,
            panel            = "shared",
            showReuseMessage = false,
            clear            = true,
        }

        local tasks = {
            {
                group   = "build",
                label   = "process tex file",
                type    = "shell",
                command =                          "context     --autogenerate --autopdf ${file}",
                windows = { command = "chcp 65001 ; context.exe --autogenerate --autopdf ${file}" },
            },
            {
                group   = "build",
                label   = "check tex file",
                type    = "shell",
                command =                          "mtxrun     --autogenerate --script check ${file}",
                windows = { command = "chcp 65001 ; mtxrun.exe --autogenerate --script check ${file}" },
            },
            {
                group   = "build",
                label   = "identify fonts",
                type    = "shell",
                command =                          "mtxrun     --script fonts --reload --force",
                windows = { command = "chcp 65001 ; mtxrun.exe --script fonts --reload --force" },
            },
            {
                group   = "build",
                label   = "process lua file",
                type    = "shell",
                command =                          "mtxrun     --script ${file}",
                windows = { command = "chcp 65001 ; mtxrun.exe --script ${file}" },
            },
        }

        for i=1,#tasks do
            local task = tasks[i]
            if not task.windows then
                task.windows = {  command = "chcp 65001 ; " .. task.command }
            end
            if not task.presentation then
                task.presentation = presentation
            end
        end

        registertask {
            category    = "context",
            description = "ConTeXt Tasks",
            tasks       = tasks,
        }

    end

    do

         local keybindings = {
            {
             -- runner  = "context --autogenerate --autopdf ${file}",
                key     = "ctrl-F12",
                command = "workbench.action.tasks.runTask",
                args    = "process tex file",
                when    = "editorTextFocus && editorLangId == context.tex",
            },
            {
             -- runner  = "mtxrun --autogenerate --script check ${file}",
                key     = "F12",
                command = "workbench.action.tasks.runTask",
                args    = "check tex file",
                when    = "editorTextFocus && editorLangId == context.tex",
            },
            {
             -- runner  = "mtxrun --script ${file}",
                key     = "ctrl-F12",
                command = "workbench.action.tasks.runTask",
                args    = "process lua file",
                when    = "editorTextFocus && editorLangId == context.cld",
            }
        }

        registerkeybinding {
            category    = "context",
            description = "ConTeXt Keybindings",
            keybindings = keybindings,
        }

    end

    -- helpers

    local function loaddefinitions(name)
        return table.load(resolvers.findfile(name))
    end

    local escapes = {
        ["."]  = "\\.",
        ["-"]  = "\\-",
        ["+"]  = "\\+",
        ["*"]  = "\\*",
        ['"']  = '\\"',
        ["'"]  = "\\'",
        ['^']  = '\\^',
        ['$']  = '\\$',
        ["|"]  = "\\|",
        ["\\"] = "\\\\",
        ["["]  = "\\[",
        ["]"]  = "\\]",
        ["("]  = "\\(",
        [")"]  = "\\)",
        ["%"]  = "\\%",
        ["!"]  = "\\!",
        ["&"]  = "\\&",
        ["?"]  = "\\?",
        ["~"]  = "\\~",
    }

    local function sorter(a,b)
        return a > b
    end

    local function oneof(t)
        local result = { }
        table.sort(t,sorter)
        for i=1,#t do
            result[i] = string.gsub(t[i],".",escapes)
        end
        return table.concat(result,"|")
    end

    local function capture(str)
        return "(" .. str .. ")"
    end

    local function captures(str)
        return "\\*(" .. str .. ")\\*"
    end

    local function include(str)
        return { include = str }
    end

    local function configuration(s)
        if s then
            local pairs    = s.pairs
            local comments = s.comments
            return {
                brackets         = pairs,
                autoClosingPairs = pairs,
                surroundingPairs = pairs,
                comments = {
                    lineComment  = comments and comments.inline or nil,
                    blockComment = comments and comments.display or nil,
                },
            }
        else
            return { }
        end
    end

    -- I need to figure out a decent mapping for dark as the defaults are just
    -- not to my taste and we also have a different categorization.

    local mapping = {
        ["context.default"]      = "text source",
        ["context.number"]       = "constant.numeric",
        ["context.comment"]      = "comment",
        ["context.keyword"]      = "keyword",
        ["context.string"]       = "string source",
        ["context.label"]        = "meta.tag",
        ["context.constant"]     = "support.constant",
        ["context.operator"]     = "keyword.operator.js",
        ["context.identifier"]   = "support.variable",
        ["context.quote"]        = "string",
        ["context.special"]      =      "unset",
        ["context.extra"]        =      "unset",
        ["context.embedded"]     = "meta.embedded",
        ["context.reserved"]     =      "unset",
        ["context.definition"]   = "keyword",
        ["context.warning"]      = "invalid",
        ["context.command"]      =      "unset",
        ["context.grouping"]     =      "unset",
        ["context.primitive"]    = "keyword",
        ["context.plain"]        =      "unset",
        ["context.user"]         =      "unset",
        ["context.data"]         = "text source",
        ["context.text"]         = "text source",
    }

    local function styler(namespace)
        local done  = { }
        local style = function(what,where)
            if not what or not where then
                report()
                report("?  %-5s  %-20s  %s",namespace,what or "?",where or "?")
                report()
                os.exit()
            end
-- if mapping then
--     what = mapping[what] or what
-- end
            local hash = what .. "." .. where
            if done[hash] then
                report("-  %-5s  %-20s  %s",namespace,what,where)
            else
             -- report("+  %-5s  %-20s  %s",namespace,what,where)
                done[hash] = true
            end
            return hash .. "." .. namespace
        end
        return style, function(what,where) return { name = style(what, where) } end
    end

    local function embedded(name)
        return { { include = "source.context." .. name } }
    end

    -- The tex lexer.

    do

        local interface_lowlevel   = loaddefinitions("scite-context-data-context.lua")
        local interface_interfaces = loaddefinitions("scite-context-data-interfaces.lua")
        local interface_tex        = loaddefinitions("scite-context-data-tex.lua")

        local constants  = interface_lowlevel.constants
        local helpers    = interface_lowlevel.helpers
        local interfaces = interface_interfaces.common
        local primitives = { }
        local overloaded = { }

        for i=1,#helpers do
            overloaded[helpers[i]] = true
        end
        for i=1,#constants do
            overloaded[constants[i]] = true
        end

        local function add(data)
            for k, v in next, data do
                if v ~= "/" and v ~= "-" then
                    if not overloaded[v] then
                        primitives[#primitives+1] = v
                    end
                    v = "normal" .. v
                    if not overloaded[v] then
                        primitives[#primitives+1] = v
                    end
                end
            end
        end

        add(interface_tex.tex)
        add(interface_tex.etex)
        add(interface_tex.pdftex)
        add(interface_tex.aleph)
        add(interface_tex.omega)
        add(interface_tex.luatex)
        add(interface_tex.xetex)

        local luacommands = {
            "ctxlua", "ctxcommand", "ctxfunction",
            "ctxlatelua", "ctxlatecommand",
            "cldcommand", "cldcontext",
            "luaexpr", "luascript", "luathread",
            "directlua", "latelua",
        }

        local luaenvironments = {
            "luacode",
            "luasetups", "luaparameterset",
            "ctxfunction", "ctxfunctiondefinition",
        }

        local mpscommands = {
            "reusableMPgraphic", "usableMPgraphic",
            "uniqueMPgraphic", "uniqueMPpagegraphic",
            "useMPgraphic", "reuseMPgraphic",
            "MPpositiongraphic",
        }

        local mpsenvironments_o = {
            "MPpage"
        }

        local mpsenvironments_a = {
            "MPcode", "useMPgraphic", "reuseMPgraphic",
            "MPinclusions", "MPinitializations", "MPdefinitions", "MPextensions",
            "MPgraphic", "MPcalculation",
        }

        -- clf_a-zA-z_

        -- btx|xml a-z
        -- a-z btx|xml a-z

        -- mp argument {...text}
        local function words(list)
            table.sort(list,sorter)
            return "\\\\(" .. table.concat(list,"|") .. ")" .. "(?=[^a-zA-Z])"
        end

        local function bwords(list)
            table.sort(list,sorter)
            return "(\\\\(" .. table.concat(list,"|") .. "))\\s*(\\{)"
        end

        local function ewords()
            return "(\\})"
        end

        local function environments(list)
            table.sort(list,sorter)
            last = table.concat(list,"|")
            if #list > 1 then
                last = "(?:" .. last .. ")"
            end
            return capture("\\\\start" .. last), capture("\\\\stop" .. last)
        end

        local capturedconstants     = words(constants)
        local capturedprimitives    = words(primitives)
        local capturedhelpers       = words(helpers)
        local capturedcommands      = words(interfaces)
        local capturedmpscommands   = words(mpscommands)

        local spaces                = "\\s*"
        local identifier            = "[a-zA-Z\\_@!?\127-\255]+"

        local comment               = "%.*$\\n?"
        local ifprimitive           = "\\\\if[a-zA-Z\\_@!?\127-\255]*"
        local csname                = "\\\\[a-zA-Z\\_@!?\127-\255]+"
        local csprefix              = "\\\\(btx|xml)[a-z]+"
        local cssuffix              = "\\\\[a-z]+(btx|xml)[a-z]*"
        local csreserved            = "\\\\(\\?\\?|[a-z]\\!)[a-zA-Z\\_@!?\127-\255]+"

        local luaenvironmentopen,
              luaenvironmentclose   = environments(luaenvironments)
        local luacommandopen,
              luacommandclose       = environments(luacommands)

        local mpsenvironmentopen_o,
              mpsenvironmentclose_o = environments(mpsenvironments_o)
        local mpsenvironmentopen_a,
              mpsenvironmentclose_a = environments(mpsenvironments_a)

        local argumentopen          = capture("\\{")
        local argumentclose         = capture("\\}")
        local argumentcontent       = capture("[^\\}]*")

        local optionopen            = capture("\\[")
        local optionclose           = capture("\\]")
        local optioncontent         = capture("[^\\]]*")

        -- not ok yet, todo: equal in settings .. but it would become quite ugly, lpeg wins here
        -- so instead we color differently

        local option                = "(?:" .. optionopen   .. optioncontent   .. optionclose   ..  ")?"
        local argument              = "(?:" .. argumentopen .. argumentcontent .. argumentclose ..  ")?"

        local mpsenvironmentopen_o  = mpsenvironmentopen_o .. spaces .. option   .. spaces .. option
        local mpsenvironmentopen_a  = mpsenvironmentopen_a .. spaces .. argument .. spaces .. argument

        local style, styled         = styler("tex")

        local capturedgroupings = oneof {
            "{", "}", "$"
        }

        local capturedextras = oneof {
            "~", "%", "^", "&", "_",
            "-", "+", "/",
            "'", "`",
            "\\", "|",
        }

        local capturedspecials = oneof {
            "(", ")", "[", "]", "<", ">",
            "#", "=", '"',
        }

        local capturedescaped = "\\\\."

        registerlexer {

            category    = "tex",
            description = "ConTeXt TEX",
            suffixes    = { "tex", "mkiv", "mkvi", "mkix", "mkxi", "mkil", "mkxl", "mklx" },
            version     = "1.0.0",

            setup       = configuration {
                pairs = {
                    { "{", "}" },
                    { "[", "]" },
                    { "(", ")" },
                },
                comments = {
                    inline  = "%",
                },
            },

            repository  = {

                comment = {
                    name  = style("context.comment", "comment"),
                    match = texcomment,
                },

                constant = {
                    name  = style("context.constant", "commands.constant"),
                    match = capturedconstants,
                },

                ifprimitive = {
                    name  = style("context.primitive", "commands.if"),
                    match = ifprimitive,
                },

                primitive = {
                    name  = style("context.primitive", "commands.primitive"),
                    match = capturedprimitives,
                },

                helper = {
                    name  = style("context.plain", "commands.plain"),
                    match = capturedhelpers,
                },

                command = {
                    name  = style("context.command", "commands.context"),
                    match = capturedcommands,
                },

                csname = {
                    name  = style("context.user", "commands.user"),
                    match = csname,
                },

                escaped = {
                    name  = style("context.command", "commands.escaped"),
                    match = capturedescaped,
                },

                subsystem_prefix = {
                    name  = style("context.embedded", "subsystem.prefix"),
                    match = csprefix,
                },

                subsystem_suffix = {
                    name  = style("context.embedded", "subsystem.suffix"),
                    match = cssuffix,
                },

                grouping = {
                    name  = style("context.grouping", "symbols.groups"),
                    match = capturedgroupings,
                },

                extra = {
                    name  = style("context.extra", "symbols.extras"),
                    match = capturedextras,
                },

                special = {
                    name  = style("context.special", "symbols.special"),
                    match = capturedspecials,
                },

                reserved = {
                    name  = style("context.reserved", "commands.reserved"),
                    match = csreserved,
                },

                lua_environment = {
                    ["begin"]     = luaenvironmentopen,
                    ["end"]       = luaenvironmentclose,
                    patterns      = embedded("cld"),
                    beginCaptures = { ["0"] = styled("context.embedded", "lua.environment.open") },
                    endCaptures   = { ["0"] = styled("context.embedded", "lua.environment.close") },
                },

                lua_command = {
                    ["begin"]     = luacommandopen,
                    ["end"]       = luacommandclose,
                    patterns      = embedded("cld"),
                    beginCaptures = {
                        ["1"] = styled("context.embedded", "lua.command.open"),
                        ["2"] = styled("context.grouping", "lua.command.open"),
                    },
                    endCaptures   = {
                        ["1"] = styled("context.grouping", "lua.command.close"),
                    },

                },

                metafun_environment_o = {
                    ["begin"]     = mpsenvironmentopen_o,
                    ["end"]       = mpsenvironmentclose_o,
                    patterns      = embedded("mps"),
                    beginCaptures = {
                        ["1"] = styled("context.embedded", "metafun.environment.start.o"),
                        ["2"] = styled("context.embedded", "metafun.environment.open.o.1"),
                        ["3"] = styled("context.warning", "metafun.environment.content.o.1"),
                        ["4"] = styled("context.embedded", "metafun.environment.close.o.1"),
                        ["5"] = styled("context.embedded", "metafun.environment.open.o.2"),
                        ["6"] = styled("context.warning", "metafun.environment.content.o.2"),
                        ["7"] = styled("context.embedded", "metafun.environment.close.o.2"),
                    },
                    endCaptures   = {
                        ["0"] = styled("context.embedded", "metafun.environment.stop.o")
                    },
                },

                metafun_environment_a = {
                    ["begin"]     = mpsenvironmentopen_a,
                    ["end"]       = mpsenvironmentclose_a,
                    patterns      = embedded("mps"),
                    beginCaptures = {
                        ["1"] = styled("context.embedded", "metafun.environment.start.a"),
                        ["2"] = styled("context.embedded", "metafun.environment.open.a.1"),
                        ["3"] = styled("context.warning", "metafun.environment.content.a.1"),
                        ["4"] = styled("context.embedded", "metafun.environment.close.a.1"),
                        ["5"] = styled("context.embedded", "metafun.environment.open.a.2"),
                        ["6"] = styled("context.warning", "metafun.environment.content.a.2"),
                        ["7"] = styled("context.embedded", "metafun.environment.close.a.2"),
                    },
                    endCaptures   = {
                        ["0"] = styled("context.embedded", "metafun.environment.stop.a")
                    },
                },

                metafun_command = {
                    name  = style("context.embedded", "metafun.command"),
                    match = capturedmpscommands,
                },

            },

            patterns = {
                include("#comment"),
                include("#constant"),
                include("#lua_environment"),
                include("#lua_command"),
                include("#metafun_environment_o"),
                include("#metafun_environment_a"),
                include("#metafun_command"),
                include("#subsystem_prefix"),
                include("#subsystem_suffix"),
                include("#ifprimitive"),
                include("#helper"),
                include("#command"),
                include("#primitive"),
                include("#reserved"),
                include("#csname"),
                include("#escaped"),
                include("#grouping"),
                include("#special"),
                include("#extra"),
            },

        }

    end

    -- The metafun lexer.

    do

        local metapostprimitives = { }
        local metapostinternals  = { }
        local metapostshortcuts  = { }
        local metapostcommands   = { }

        local metafuninternals   = { }
        local metafunshortcuts   = { }
        local metafuncommands    = { }

        local mergedshortcuts    = { }
        local mergedinternals    = { }

        do

            local definitions = loaddefinitions("scite-context-data-metapost.lua")

            if definitions then
                metapostprimitives = definitions.primitives or { }
                metapostinternals  = definitions.internals  or { }
                metapostshortcuts  = definitions.shortcuts  or { }
                metapostcommands   = definitions.commands   or { }
            end

            local definitions = loaddefinitions("scite-context-data-metafun.lua")

            if definitions then
                metafuninternals  = definitions.internals or { }
                metafunshortcuts  = definitions.shortcuts or { }
                metafuncommands   = definitions.commands  or { }
            end

            for i=1,#metapostshortcuts do
                mergedshortcuts[#mergedshortcuts+1] = metapostshortcuts[i]
            end
            for i=1,#metafunshortcuts do
                mergedshortcuts[#mergedshortcuts+1] = metafunshortcuts[i]
            end

            for i=1,#metapostinternals do
                mergedinternals[#mergedinternals+1] = metapostinternals[i]
            end
            for i=1,#metafuninternals do
                mergedinternals[#mergedinternals+1] = metafuninternals[i]
            end


        end

        local function words(list)
            table.sort(list,sorter)
            return "(" .. table.concat(list,"|") .. ")" .. "(?=[^a-zA-Z\\_@!?\127-\255])"
        end

        local capturedshortcuts          = oneof(mergedshortcuts)
        local capturedinternals          = words(mergedinternals)
        local capturedmetapostcommands   = words(metapostcommands)
        local capturedmetafuncommands    = words(metafuncommands)
        local capturedmetapostprimitives = words(metapostprimitives)

        local capturedsuffixes = oneof {
            "#@", "@#", "#"
        }
        local capturedspecials = oneof {
            "#@", "@#", "#",
            "(", ")", "[", "]", "{", "}",
            "<", ">", "=", ":",
            '"',
        }
        local capturedexatras = oneof {
            "+-+", "++",
            "~", "%", "^", "&",
            "_", "-", "+", "*", "/",
            "`", "'", "|", "\\",
        }

        local spaces              = "\\s*"
        local mandatespaces       = "\\s+"

        local identifier          = "[a-zA-Z\\_@!?\127-\255]+"

        local decnumber           = "[\\-]?[0-9]+(\\.[0-9]+)?([eE]\\-?[0-9]+)?"

        local comment             = "%.*$\\n?"

        local stringopen          = "\""
        local stringclose         = stringopen

        local qualifier           = "[\\.]"
        local optionalqualifier   = spaces .. qualifier .. spaces

        local capturedstringopen  = capture(stringopen)
        local capturedstringclose = capture(stringclose)

        local capturedlua         = capture("lua")

        local capturedopen        = capture("\\(")
        local capturedclose       = capture("\\)")

        local capturedtexopen     = capture("(?:b|verbatim)tex") .. mandatespaces
        local capturedtexclose    = mandatespaces .. capture("etex")

        local texcommand          = "\\[a-zA-Z\\_@!?\127-\255]+"

        local style, styled       = styler("mps")

        registerlexer {

            category    = "mps",
            description = "ConTeXt MetaFun",
            suffixes    = { "mp", "mpii", "mpiv", "mpxl" },
            version     = "1.0.0",

            setup       = configuration {
                pairs = {
                    { "{", "}" },
                    { "[", "]" },
                    { "(", ")" },
                },
                comments = {
                    inline  = "%",
                },
            },

            repository  = {

                comment = {
                    name  = style("context.comment", "comment"),
                    match = comment,
                },

                internal = {
                    name  = style("context.reserved", "internal"),
                    match = capturedshortcuts,
                },

                shortcut = {
                    name  = style("context.data", "shortcut"),
                    match = capturedinternals,
                },

                helper = {
                    name  = style("context.command.metafun", "helper"),
                    match = capturedmetafuncommands,
                },

                plain = {
                    name  = style("context.plain", "plain"),
                    match = capturedmetapostcommands,
                },

                primitive = {
                    name  = style("context.primitive", "primitive"),
                    match = capturedmetapostprimitives,
                },

                quoted = {
                    name          = style("context.string", "string.text"),
                    ["begin"]     = stringopen,
                    ["end"]       = stringclose,
                    beginCaptures = { ["0"] = styled("context.special", "string.open") },
                    endCaptures   = { ["0"] = styled("context.special", "string.close") },
                },

                identifier = {
                    name  = style("context.default", "identifier"),
                    match = identifier,
                },

                suffix = {
                    name  = style("context.number", "suffix"),
                    match = capturedsuffixes,
                },

                special = {
                    name  = style("context.special", "special"),
                    match = capturedspecials,
                },

                number = {
                    name  = style("context.number", "number"),
                    match = decnumber,
                },

                extra = {
                    name  = "context.extra",
                    match = capturedexatras,
                },

                luacall = {
                    ["begin"]     = capturedlua .. spaces .. capturedopen .. spaces .. capturedstringopen,
                    ["end"]       = capturedstringclose .. spaces .. capturedclose,
                    patterns      = embedded("cld"),
                    beginCaptures =  {
                        ["1"] = styled("context.embedded", "lua.command"),
                        ["2"] = styled("context.special",  "lua.open"),
                        ["3"] = styled("context.special",  "lua.text.open"),
                    },
                    endCaptures   =  {
                        ["1"] = styled("context.special", "lua.text.close"),
                        ["2"] = styled("context.special", "lua.close"),
                    },
                },

                -- default and embedded have the same color but differ in boldness

                luacall_suffixed = {
                    name      = style("context.embedded", "luacall"),
                    ["begin"] = capturedlua,
                    ["end"]   = "(?!(" .. optionalqualifier .. identifier .. "))",
                    patterns  = {
                        {
                            match = qualifier,
                         -- name  = style("context.operator", "luacall.qualifier"),
                            name  = style("context.default", "luacall.qualifier"),
                        },
                    }
                },

                texlike = { -- simplified variant
                    name  = style("context.warning","unexpected.tex"),
                    match = texcommand,
                },

                texstuff = {
                    name          = style("context.string", "tex"),
                    ["begin"]     = capturedtexopen,
                    ["end"]       = capturedtexclose,
                    patterns      = embedded("tex"),
                    beginCaptures = { ["1"] = styled("context.primitive", "tex.open") },
                    endCaptures   = { ["1"] = styled("context.primitive", "tex.close") },
                },

            },

            patterns = {
                include("#comment"),
                include("#internal"),
                include("#shortcut"),
                include("#luacall_suffixed"),
                include("#luacall"),
                include("#helper"),
                include("#plain"),
                include("#primitive"),
                include("#texstuff"),
                include("#suffix"),
                include("#identifier"),
                include("#number"),
                include("#quoted"),
                include("#special"),
                include("#texlike"),
                include("#extra"),
            },

        }

    end

    -- The lua lexer.

    do

        local function words(list)
            table.sort(list,sorter)
            return "(" .. table.concat(list,"|") .. ")" .. "(?=[^a-zA-Z])"
        end

        local capturedkeywords = words {
            "and", "break", "do", "else", "elseif", "end", "false", "for", "function", -- "goto",
            "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
            "until", "while",
        }

        local capturedbuiltin = words {
            "assert", "collectgarbage", "dofile", "error", "getmetatable",
            "ipairs", "load", "loadfile", "module", "next", "pairs",
            "pcall", "print", "rawequal", "rawget", "rawset", "require",
            "setmetatable", "tonumber", "tostring", "type", "unpack", "xpcall", "select",
            "string", "table", "coroutine", "debug", "file", "io", "lpeg", "math", "os", "package", "bit32", "utf8",
            -- todo: also extra luametatex ones
        }

        local capturedconstants = words {
            "_G", "_VERSION", "_M", "\\.\\.\\.", "_ENV",
            "__add", "__call", "__concat", "__div", "__idiv", "__eq", "__gc", "__index",
            "__le", "__lt", "__metatable", "__mode", "__mul", "__newindex",
            "__pow", "__sub", "__tostring", "__unm", "__len",
            "__pairs", "__ipairs",
            "__close",
            "NaN",
           "<const>", "<toclose>",
        }

        local capturedcsnames = words { -- todo: option
            "commands",
            "context",
         -- "ctxcmd",
         -- "ctx",
            "metafun",
            "metapost",
            "ctx[A-Za-z_]*",
        }

        local capturedoperators = oneof {
            "+", "-", "*", "/", "%", "^",
            "#", "=", "<", ">",
            ";", ":", ",", ".",
            "{", "}", "[", "]", "(", ")",
            "|", "~", "'"
        }

        local spaces                = "\\s*"

        local identifier            = "[_\\w][_\\w0-9]*"
        local qualifier             = "[\\.\\:]"
        local optionalqualifier     = spaces .. "[\\.\\:]*" .. spaces

        local doublequote           = "\""
        local singlequote           = "\'"

        local doublecontent         = "(?:\\\\\"|[^\"])*"
        local singlecontent         = "(?:\\\\\'|[^\'])*"

        local captureddouble        = capture(doublequote) .. capture(doublecontent) .. capture(doublequote)
        local capturedsingle        = capture(singlequote) .. capture(singlecontent) .. capture(singlequote)

        local longcommentopen       = "--\\[\\["
        local longcommentclose      = "\\]\\]"

        local longstringopen        = "\\[(=*)\\["
        local longstringclose       = "\\](\\2)\\]"

        local shortcomment          = "--.*$\\n?"

        local hexnumber             = "[\\-]?0[xX][A-Fa-f0-9]+(\\.[A-Fa-f0-9]+)?([eEpP]\\-?[A-Fa-f0-9]+)?"
        local decnumber             = "[\\-]?[0-9]+(\\.[0-9]+)?([eEpP]\\-?[0-9]+)?"

        local capturedidentifier    = capture(identifier)
        local capturedgotodelimiter = capture("::")
        local capturedqualifier     = capture(qualifier)
        local capturedgoto          = capture("goto")

        local style, styled         = styler("lua")

        local lualexer = {

            category    = "lua",
            description = "ConTeXt Lua",
         -- suffixes    = { "lua", "luc", "cld", "tuc", "luj", "lum", "tma", "lfg", "luv", "lui" },
            version     = "1.0.0",

            setup       = configuration {
                pairs = {
                    { "(", ")" },
                    { "{", "}" },
                    { "[", "]" },
                },
                comments = {
                    inline  = "--",
                    display = { "--[[", "]]" },
                },
            },

            repository  = {

                shortcomment = {
                    name  = style("context.comment", "comment.short"),
                    match = shortcomment,
                },

                longcomment = {
                    name      = style("context.comment", "comment.long"),
                    ["begin"] = longcommentopen,
                    ["end"]   = longcommentclose,
                },

                keyword = {
                    name  = style("context.keyword", "reserved.keyword"),
                    match = capturedkeywords,
                },

                builtin = {
                    name  = style("context.plain", "reserved.builtin"),
                    match = capturedbuiltin,
                },

                constant = {
                    name  = style("context.data", "reserved.constants"),
                    match = capturedconstants,
                },

                csname = {
                    name      = style("context.user", "csname"),
                    ["begin"] = capturedcsnames,
                    ["end"]   = "(?!(" .. optionalqualifier .. identifier .. "))",
                    patterns  = {
                        {
                            match = qualifier,
                            name  = style("context.operator", "csname.qualifier")
                        },
                    }
                },

                identifier_keyword = {
                    match  = spaces .. capturedqualifier .. spaces .. capturedkeywords,
                    captures = {
                        ["1"] = styled("context.operator", "identifier.keyword"),
                        ["2"] = styled("context.warning", "identifier.keyword"),
                    },
                },

                identifier_valid = {
                    name  = style("context.default", "identifier.valid"),
                    match = identifier,
                },

                ["goto"] = {
                    match    = capturedgoto .. spaces .. capturedidentifier,
                    captures = {
                        ["1"] = styled("context.keyword",  "goto.keyword"),
                        ["2"] = styled("context.grouping", "goto.target"),
                    }
                },

                label = {
                    match    = capturedgotodelimiter .. capturedidentifier .. capturedgotodelimiter,
                    captures = {
                        ["1"] = styled("context.keyword",  "label.open"),
                        ["2"] = styled("context.grouping", "label.target"),
                        ["3"] = styled("context.keyword",  "label.close"),
                    }
                },

                operator = {
                    name  = style("context.special", "operator"),
                    match = capturedoperators,
                },

                string_double = {
                    match    = captureddouble,
                    captures = {
                        ["1"] = styled("context.special", "doublequoted.open"),
                        ["2"] = styled("context.string",  "doublequoted.text"),
                        ["3"] = styled("context.special", "doublequoted.close"),
                    },
                },

                string_single = {
                    match    = capturedsingle,
                    captures = {
                        ["1"] = styled("context.special", "singlequoted.open"),
                        ["2"] = styled("context.string",  "singlequoted.text"),
                        ["3"] = styled("context.special", "singlequoted.close"),
                    },
                },

                string_long = {
                    name          = style("context.string", "long.text"),
                    ["begin"]     = longstringopen,
                    ["end"]       = longstringclose,
                    beginCaptures = { ["0"] = styled("context.special", "string.long.open") },
                    endCaptures   = { ["0"] = styled("context.special", "string.long.close") },
                },

                number_hex = {
                    name  = style("context.number", "hexnumber"),
                    match = hexnumber,
                },

                number = {
                    name  = style("context.number", "decnumber"),
                    match = decnumber,
                },

            },

            patterns   = {
                include("#keyword"),
                include("#buildin"),
                include("#constant"),
                include("#csname"),
                include("#goto"),
                include("#number_hex"),
                include("#number"),
                include("#identifier_keyword"),
                include("#identifier_valid"),
                include("#longcomment"),
                include("#string_long"),
                include("#string_double"),
                include("#string_single"),
                include("#shortcomment"),
                include("#label"),
                include("#operator"),
            },

        }

        local texstringopen  = "\\\\!!bs"
        local texstringclose = "\\\\!!es"
        local texcommand     = "\\\\[A-Za-z\127-\255@\\!\\?_]*"

        local cldlexer = {

            category    = "cld",
            description = "ConTeXt CLD",
            suffixes    = { "lua", "luc", "cld", "tuc", "luj", "lum", "tma", "lfg", "luv", "lui" },
            version     = lualexer.version,
            setup       = lualexer.setup,

            repository  = {

                texstring = {
                    name          = style("context.string", "texstring.text"),
                    ["begin"]     = texstringopen,
                    ["end"]       = texstringclose,
                    beginCaptures = { ["0"] = styled("context.special", "texstring.open") },
                    endCaptures   = { ["0"] = styled("context.special", "texstring.close") },
                },

             -- texcomment = {
             --     -- maybe some day
             -- },

                texcommand = {
                    name  = style("context.warning", "texcommand"),
                    match = texcommand
                },

            },

            patterns = {
                include("#texstring"),
             -- include("#texcomment"),
                include("#texcommand"),
            },

        }

        table.merge (cldlexer.repository,lualexer.repository)
        table.imerge(cldlexer.patterns,  lualexer.patterns)

        registerlexer(lualexer)
        registerlexer(cldlexer)

    end

    -- The xml lexer.

    local xmllexer, xmlconfiguration  do

        local spaces            = "\\s*"

        local namespace         = "(?:[-\\w.]+:)?"
        local name              = "[-\\w.:]+"

        local equal             = "="

        local elementopen       = "<"
        local elementclose      = ">"
        local elementopenend    = "</"
        local elementempty      = "/?"
        local elementnoclose    = "?:([^>]*)"

        local entity            = "&.*?;"

        local doublequote       = "\""
        local singlequote       = "\'"

        local doublecontent     = "(?:\\\\\"|[^\"])*"
        local singlecontent     = "(?:\\\\\'|[^\'])*"

        local captureddouble    = capture(doublequote) .. capture(doublecontent) .. capture(doublequote)
        local capturedsingle    = capture(singlequote) .. capture(singlecontent) .. capture(singlequote)

        local capturednamespace = capture(namespace)
        local capturedname      = capture(name)
        local capturedopen      = capture(elementopen)
        local capturedclose     = capture(elementclose)
        local capturedempty     = capture(elementempty)
        local capturedopenend   = capture(elementopenend)

        local cdataopen        = "<!\\[CDATA\\["
        local cdataclose       = "]]>"

        local commentopen      = "<!--"
        local commentclose     = "-->"

        local processingopen   = "<\\?"
        local processingclose  = "\\?>"

        local instructionopen  = processingopen .. name
        local instructionclose = processingclose

        local xmlopen          = processingopen .. "xml"
        local xmlclose         = processingclose

        local luaopen          = processingopen .. "lua"
        local luaclose         = processingclose

        local style, styled    = styler("xml")

        registerlexer {

            category    = "xml",
            description = "ConTeXt XML",
            suffixes    = {
                "xml", "xsl", "xsd", "fo", "exa", "rlb", "rlg", "rlv", "rng",
                "xfdf", "xslt", "dtd", "lmx", "htm", "html", "xhtml", "ctx",
                "export", "svg", "xul",
            },
            version     = "1.0.0",

            setup       = configuration {
                comments = {
                    display = { "<!--", "-->" },
                },
            },

            repository  = {

                attribute_double = {
                    match    = capturednamespace .. capturedname .. spaces .. equal .. spaces .. captureddouble,
                    captures = {
                        ["1"] = styled("context.plain",    "attribute.double.namespace"),
                        ["2"] = styled("context.constant", "attribute.double.name"),
                        ["3"] = styled("context.special",  "attribute.double.open"),
                        ["4"] = styled("context.string",   "attribute.double.text"),
                        ["5"] = styled("context.special",  "attribute.double.close"),
                    },
                },

                attribute_single = {
                    match    = capturednamespace .. capturedname .. spaces .. equal .. spaces .. capturedsingle,
                    captures = {
                        ["1"] = styled("context.plain",    "attribute.single.namespace"),
                        ["2"] = styled("context.constant", "attribute.single.name"),
                        ["3"] = styled("context.special",  "attribute.single.open"),
                        ["4"] = styled("context.string",   "attribute.single.text"),
                        ["5"] = styled("context.special",  "attribute.single.close"),
                    },
                },

                attributes = {
                    patterns = {
                        include("#attribute_double"),
                        include("#attribute_single"),
                    }
                },

                entity = {
                    name  = style("context.constant", "entity"),
                    match = entity,
                },

                instruction = {
                    name          = style("context.default", "instruction.text"),
                    ["begin"]     = instructionopen,
                    ["end"]       = instructionclose,
                    beginCaptures = { ["0"] = styled("context.command", "instruction.open") },
                    endCaptures   = { ["0"] = styled("context.command", "instruction.close") },
                },

                instruction_xml = {
                    ["begin"]     = xmlopen,
                    ["end"]       = xmlclose,
                    beginCaptures = { ["0"] = styled("context.command", "instruction.xml.open") },
                    endCaptures   = { ["0"] = styled("context.command", "instruction.xml.close") },
                    patterns      = { include("#attributes") }
                },

                instruction_lua = {
                    ["begin"]     = luaopen,
                    ["end"]       = luaclose,
                    patterns      = embedded("cld"),
                    beginCaptures = { ["0"] = styled("context.command", "instruction.lua.open") },
                    endCaptures   = { ["0"] = styled("context.command", "instruction.lua.close") },
                },

                cdata = {
                    name          = style("context.default", "cdata.text"),
                    ["begin"]     = cdataopen,
                    ["end"]       = cdataclose,
                    beginCaptures = { ["0"] = styled("context.command", "cdata.open") },
                    endCaptures   = { ["0"] = styled("context.command", "cdata.close") },
                },

                comment = {
                    name          = style("context.comment", "comment.text"),
                    ["begin"]     = commentopen,
                    ["end"]       = commentclose,
                    beginCaptures = { ["0"] = styled("context.command", "comment.open") },
                    endCaptures   = { ["0"] = styled("context.command", "comment.close") },
                },

                open = {
                    ["begin"]     = capturedopen .. capturednamespace .. capturedname,
                    ["end"]       = capturedempty .. capturedclose,
                    patterns      = { include("#attributes") },
                    beginCaptures = {
                        ["1"] = styled("context.keyword", "open.open"),
                        ["2"] = styled("context.plain",   "open.namespace"),
                        ["3"] = styled("context.keyword", "open.name"),
                    },
                    endCaptures   = {
                        ["1"] = styled("context.keyword", "open.empty"),
                        ["2"] = styled("context.keyword", "open.close"),
                    },
                },

                close = {
                    match    = capturedopenend .. capturednamespace .. capturedname .. spaces .. capturedclose,
                    captures = {
                        ["1"] = styled("context.keyword", "close.open"),
                        ["2"] = styled("context.plain",   "close.namespace"),
                        ["3"] = styled("context.keyword", "close.name"),
                        ["4"] = styled("context.keyword", "close.close"),
                    },
                },

                element_error = {
                    name  = style("context.error","error"),
                    match = elementopen .. elementnoclose .. elementclose,
                },

            },

            patterns = {
             -- include("#preamble"),
                include("#comment"),
                include("#cdata"),
             -- include("#doctype"),
                include("#instruction_xml"),
                include("#instruction_lua"),
                include("#instruction"),
                include("#close"),
                include("#open"),
                include("#element_error"),
                include("#entity"),
            },

        }

    end

    -- The bibtex lexer. Again we assume the keys to be on the same line as the
    -- first snippet of the value.

    do

        local spaces            = "\\s*"
        local open              = "{"
        local close             = "}"
        local hash              = "#"
        local equal             = "="
        local comma             = ","

        local doublequote       = "\""
        local doublecontent     = "(?:\\\\\"|[^\"])*"

        local singlequote       = "\'"
        local singlecontent     = "(?:\\\\\'|[^\'])*"

        local groupopen         = "{"
        local groupclose        = "}"
        local groupcontent      = "(?:\\\\{|\\\\}|[^\\{\\}])*"

        local shortcut          = "@(?:string|String|STRING)"    -- enforce consistency
        local comment           = "@(?:comment|Comment|COMMENT)" -- enforce consistency

        local keyword           = "[a-zA-Z0-9\\_@:\\-]+"

        local capturedcomment   = spaces .. capture(comment) .. spaces
        local capturedshortcut  = spaces .. capture(shortcut) .. spaces
        local capturedkeyword   = spaces .. capture(keyword) .. spaces
        local capturedopen      = spaces .. capture(open) .. spaces
        local capturedclose     = spaces .. capture(close) .. spaces
        local capturedequal     = spaces .. capture(equal) .. spaces
        local capturedcomma     = spaces .. capture(comma) .. spaces
        local capturedhash      = spaces .. capture(hash) .. spaces

        local captureddouble    = spaces .. capture(doublequote) .. capture(doublecontent) .. capture(doublequote) .. spaces
        local capturedsingle    = spaces .. capture(singlequote) .. capture(singlecontent) .. capture(singlequote) .. spaces
        local capturedgroup     = spaces .. capture(groupopen) .. capture(groupcontent) .. capture(groupclose) .. spaces

        local forget            = "%.*$\\n?"

        local style, styled     = styler("bibtex")

        registerlexer {

            category    = "bibtex",
            description = "ConTeXt bibTeX",
            suffixes    = { "bib", "btx" },
            version     = "1.0.0",

            setup       = configuration {
                pairs = {
                    { "{", "}" },
                },
                comments = {
                    inline  = "%",
                },
            },

            repository  = {

                forget = {
                    name  = style("context.comment", "comment.comment.inline"),
                    match = forget,
                },

                comment = {
                    name  = style("context.comment", "comment.comment.content"),
                    ["begin"]     = capturedcomment .. capturedopen,
                    ["end"]       = capturedclose,
                    beginCaptures = {
                        ["1"] = styled("context.keyword", "comment.name"),
                        ["2"] = styled("context.grouping", "comment.open"),
                    },
                    endCaptures   = {
                        ["1"] = styled("context.grouping", "comment.close"),
                    },
                },

                -- a bit inefficient but good enough

                string_double = {
                    match    = capturedkeyword .. capturedequal .. captureddouble,
                    captures = {
                        ["1"] = styled("context.command","doublequoted.key"),
                        ["2"] = styled("context.operator","doublequoted.equal"),
                        ["3"] = styled("context.special", "doublequoted.open"),
                        ["4"] = styled("context.text", "doublequoted.text"),
                        ["5"] = styled("context.special", "doublequoted.close"),
                    },
                },

                string_single = {
                    match    = capturedkeyword .. capturedequal .. capturedsingle,
                    captures = {
                        ["1"] = styled("context.command","singlequoted.key"),
                        ["2"] = styled("context.operator","singlequoted.equal"),
                        ["3"] = styled("context.special", "singlequoted.open"),
                        ["4"] = styled("context.text", "singlequoted.text"),
                        ["5"] = styled("context.special", "singlequoted.close"),
                    },
                },

                string_grouped = {
                    match    = capturedkeyword .. capturedequal .. capturedgroup,
                    captures = {
                        ["1"] = styled("context.command","grouped.key"),
                        ["2"] = styled("context.operator","grouped.equal"),
                        ["3"] = styled("context.operator", "grouped.open"),
                        ["4"] = styled("context.text", "grouped.text"),
                        ["5"] = styled("context.operator", "grouped.close"),
                    },
                },

                string_value = {
                    match    = capturedkeyword .. capturedequal .. capturedkeyword,
                    captures = {
                        ["1"] = styled("context.command", "value.key"),
                        ["2"] = styled("context.operator", "value.equal"),
                        ["3"] = styled("context.text", "value.text"),
                    },
                },

                string_concat = {
                    patterns = {
                        {
                            match    = capturedhash .. captureddouble,
                            captures = {
                                ["1"] = styled("context.operator","concat.doublequoted.concatinator"),
                                ["2"] = styled("context.special", "concat.doublequoted.open"),
                                ["3"] = styled("context.text", "concat.doublequoted.text"),
                                ["4"] = styled("context.special", "concat.doublequoted.close"),
                            }
                        },
                        {
                            match    = capturedhash .. capturedsingle,
                            captures = {
                                ["1"] = styled("context.operator","concat.singlequoted.concatinator"),
                                ["2"] = styled("context.special", "concat.singlequoted.open"),
                                ["3"] = styled("context.text", "concat.singlequoted.text"),
                                ["4"] = styled("context.special", "concat.singlequoted.close"),
                            },
                        },
                        {
                            match    = capturedhash .. capturedgroup,
                            captures = {
                                ["1"] = styled("context.operator","concat.grouped.concatinator"),
                                ["2"] = styled("context.operator", "concat.grouped.open"),
                                ["3"] = styled("context.text", "concat.grouped.text"),
                                ["4"] = styled("context.operator", "concat.grouped.close"),
                            },
                        },
                        {
                            match    = capturedhash .. capturedkeyword,
                            captured = {
                                ["1"] = styled("context.operator","concat.value.concatinator"),
                                ["2"] = styled("context.text", "concat.value.text"),
                            },
                        },
                    },
                },

                separator = {
                    match = capturedcomma,
                    name  = style("context.operator","definition.separator"),
                },

                definition = {
                    name      = style("context.warning","definition.error"),
                    ["begin"] = capturedkeyword .. capturedopen .. capturedkeyword .. capturedcomma,
                    ["end"]   = capturedclose,
                    beginCaptures = {
                        ["1"] = styled("context.keyword", "definition.category"),
                        ["2"] = styled("context.grouping", "definition.open"),
                        ["3"] = styled("context.warning", "definition.label.text"),
                        ["3"] = styled("context.operator", "definition.label.separator"),
                    },
                    endCaptures = {
                        ["1"] = styled("context.grouping", "definition.close"),
                    },
                    patterns  = {
                        include("#string_double"),
                        include("#string_single"),
                        include("#string_grouped"),
                        include("#string_value"),
                        include("#string_concat"),
                        include("#separator"),
                    },
                },

                concatinator = {
                    match = capturedhash,
                    name  = style("context.operator","definition.concatinator"),
                },

                shortcut = {
                    name      =  style("context.warning","shortcut.error"),
                    ["begin"] = capturedshortcut .. capturedopen,
                    ["end"]   = capturedclose,
                    beginCaptures = {
                        ["1"] = styled("context.keyword", "shortcut.name"),
                        ["2"] = styled("context.grouping", "shortcut.open"),
                    },
                    endCaptures = {
                        ["1"] = styled("context.grouping", "shortcut.close"),
                    },
                    patterns  = {
                        include("#string_double"),
                        include("#string_single"),
                        include("#string_grouped"),
                        include("#string_value"),
                        include("#string_concat"),
                    },
                },

            },

            patterns = {
                include("#forget"),
                include("#comment"),
                include("#shortcut"),
                include("#definition"),
            },

        }

    end

    -- The sql lexer (only needed occasionally in documentation and so).

    do

        -- ANSI SQL 92 | 99 | 2003

        local function words(list)
            table.sort(list,sorter)
            local str = table.concat(list,"|")
            return "(" .. str .. "|" .. string.upper(str) .. ")" .. "(?=[^a-zA-Z])"
        end

        local capturedkeywords = words {
            "absolute", "action", "add", "after", "all", "allocate", "alter", "and", "any",
            "are", "array", "as", "asc", "asensitive", "assertion", "asymmetric", "at",
            "atomic", "authorization", "avg", "before", "begin", "between", "bigint",
            "binary", "bit", "bit_length", "blob", "boolean", "both", "breadth", "by",
            "call", "called", "cascade", "cascaded", "case", "cast", "catalog", "char",
            "char_length", "character", "character_length", "check", "clob", "close",
            "coalesce", "collate", "collation", "column", "commit", "condition", "connect",
            "connection", "constraint", "constraints", "constructor", "contains", "continue",
            "convert", "corresponding", "count", "create", "cross", "cube", "current",
            "current_date", "current_default_transform_group", "current_path",
            "current_role", "current_time", "current_timestamp",
            "current_transform_group_for_type", "current_user", "cursor", "cycle", "data",
            "date", "day", "deallocate", "dec", "decimal", "declare", "default",
            "deferrable", "deferred", "delete", "depth", "deref", "desc", "describe",
            "descriptor", "deterministic", "diagnostics", "disconnect", "distinct", "do",
            "domain", "double", "drop", "dynamic", "each", "element", "else", "elseif",
            "end", "equals", "escape", "except", "exception", "exec", "execute", "exists",
            "exit", "external", "extract", "false", "fetch", "filter", "first", "float",
            "for", "foreign", "found", "free", "from", "full", "function", "general", "get",
            "global", "go", "goto", "grant", "group", "grouping", "handler", "having",
            "hold", "hour", "identity", "if", "immediate", "in", "indicator", "initially",
            "inner", "inout", "input", "insensitive", "insert", "int", "integer",
            "intersect", "interval", "into", "is", "isolation", "iterate", "join", "key",
            "language", "large", "last", "lateral", "leading", "leave", "left", "level",
            "like", "local", "localtime", "localtimestamp", "locator", "loop", "lower",
            "map", "match", "max", "member", "merge", "method", "min", "minute", "modifies",
            "module", "month", "multiset", "names", "national", "natural", "nchar", "nclob",
            "new", "next", "no", "none", "not", "null", "nullif", "numeric", "object",
            "octet_length", "of", "old", "on", "only", "open", "option", "or", "order",
            "ordinality", "out", "outer", "output", "over", "overlaps", "pad", "parameter",
            "partial", "partition", "path", "position", "precision", "prepare", "preserve",
            "primary", "prior", "privileges", "procedure", "public", "range", "read",
            "reads", "real", "recursive", "ref", "references", "referencing", "relative",
            "release", "repeat", "resignal", "restrict", "result", "return", "returns",
            "revoke", "right", "role", "rollback", "rollup", "routine", "row", "rows",
            "savepoint", "schema", "scope", "scroll", "search", "second", "section",
            "select", "sensitive", "session", "session_user", "set", "sets", "signal",
            "similar", "size", "smallint", "some", "space", "specific", "specifictype",
            "sql", "sqlcode", "sqlerror", "sqlexception", "sqlstate", "sqlwarning", "start",
            "state", "static", "submultiset", "substring", "sum", "symmetric", "system",
            "system_user", "table", "tablesample", "temporary", "then", "time", "timestamp",
            "timezone_hour", "timezone_minute", "to", "trailing", "transaction", "translate",
            "translation", "treat", "trigger", "trim", "true", "under", "undo", "union",
            "unique", "unknown", "unnest", "until", "update", "upper", "usage", "user",
            "using", "value", "values", "varchar", "varying", "view", "when", "whenever",
            "where", "while", "window", "with", "within", "without", "work", "write", "year",
            "zone",
        }

        -- The dialects list is taken from drupal.org with standard subtracted.
        --
        -- MySQL 3.23.x | 4.x | 5.x
        -- PostGreSQL 8.1
        -- MS SQL Server 2000
        -- MS ODBC
        -- Oracle 10.2

        local captureddialects = words {
            "a", "abort", "abs", "access", "ada", "admin", "aggregate", "alias", "also",
            "always", "analyse", "analyze", "assignment", "attribute", "attributes", "audit",
            "auto_increment", "avg_row_length", "backup", "backward", "bernoulli", "bitvar",
            "bool", "break", "browse", "bulk", "c", "cache", "cardinality", "catalog_name",
            "ceil", "ceiling", "chain", "change", "character_set_catalog",
            "character_set_name", "character_set_schema", "characteristics", "characters",
            "checked", "checkpoint", "checksum", "class", "class_origin", "cluster",
            "clustered", "cobol", "collation_catalog", "collation_name", "collation_schema",
            "collect", "column_name", "columns", "command_function", "command_function_code",
            "comment", "committed", "completion", "compress", "compute", "condition_number",
            "connection_name", "constraint_catalog", "constraint_name", "constraint_schema",
            "containstable", "conversion", "copy", "corr", "covar_pop", "covar_samp",
            "createdb", "createrole", "createuser", "csv", "cume_dist", "cursor_name",
            "database", "databases", "datetime", "datetime_interval_code",
            "datetime_interval_precision", "day_hour", "day_microsecond", "day_minute",
            "day_second", "dayofmonth", "dayofweek", "dayofyear", "dbcc", "defaults",
            "defined", "definer", "degree", "delay_key_write", "delayed", "delimiter",
            "delimiters", "dense_rank", "deny", "derived", "destroy", "destructor",
            "dictionary", "disable", "disk", "dispatch", "distinctrow", "distributed", "div",
            "dual", "dummy", "dump", "dynamic_function", "dynamic_function_code", "enable",
            "enclosed", "encoding", "encrypted", "end-exec", "enum", "errlvl", "escaped",
            "every", "exclude", "excluding", "exclusive", "existing", "exp", "explain",
            "fields", "file", "fillfactor", "final", "float4", "float8", "floor", "flush",
            "following", "force", "fortran", "forward", "freetext", "freetexttable",
            "freeze", "fulltext", "fusion", "g", "generated", "granted", "grants",
            "greatest", "header", "heap", "hierarchy", "high_priority", "holdlock", "host",
            "hosts", "hour_microsecond", "hour_minute", "hour_second", "identified",
            "identity_insert", "identitycol", "ignore", "ilike", "immutable",
            "implementation", "implicit", "include", "including", "increment", "index",
            "infile", "infix", "inherit", "inherits", "initial", "initialize", "insert_id",
            "instance", "instantiable", "instead", "int1", "int2", "int3", "int4", "int8",
            "intersection", "invoker", "isam", "isnull", "k", "key_member", "key_type",
            "keys", "kill", "lancompiler", "last_insert_id", "least", "length", "less",
            "limit", "lineno", "lines", "listen", "ln", "load", "location", "lock", "login",
            "logs", "long", "longblob", "longtext", "low_priority", "m", "matched",
            "max_rows", "maxextents", "maxvalue", "mediumblob", "mediumint", "mediumtext",
            "message_length", "message_octet_length", "message_text", "middleint",
            "min_rows", "minus", "minute_microsecond", "minute_second", "minvalue",
            "mlslabel", "mod", "mode", "modify", "monthname", "more", "move", "mumps",
            "myisam", "name", "nesting", "no_write_to_binlog", "noaudit", "nocheck",
            "nocompress", "nocreatedb", "nocreaterole", "nocreateuser", "noinherit",
            "nologin", "nonclustered", "normalize", "normalized", "nosuperuser", "nothing",
            "notify", "notnull", "nowait", "nullable", "nulls", "number", "octets", "off",
            "offline", "offset", "offsets", "oids", "online", "opendatasource", "openquery",
            "openrowset", "openxml", "operation", "operator", "optimize", "optionally",
            "options", "ordering", "others", "outfile", "overlay", "overriding", "owner",
            "pack_keys", "parameter_mode", "parameter_name", "parameter_ordinal_position",
            "parameter_specific_catalog", "parameter_specific_name",
            "parameter_specific_schema", "parameters", "pascal", "password", "pctfree",
            "percent", "percent_rank", "percentile_cont", "percentile_disc", "placing",
            "plan", "pli", "postfix", "power", "preceding", "prefix", "preorder", "prepared",
            "print", "proc", "procedural", "process", "processlist", "purge", "quote",
            "raid0", "raiserror", "rank", "raw", "readtext", "recheck", "reconfigure",
            "regexp", "regr_avgx", "regr_avgy", "regr_count", "regr_intercept", "regr_r2",
            "regr_slope", "regr_sxx", "regr_sxy", "regr_syy", "reindex", "reload", "rename",
            "repeatable", "replace", "replication", "require", "reset", "resource",
            "restart", "restore", "returned_cardinality", "returned_length",
            "returned_octet_length", "returned_sqlstate", "rlike", "routine_catalog",
            "routine_name", "routine_schema", "row_count", "row_number", "rowcount",
            "rowguidcol", "rowid", "rownum", "rule", "save", "scale", "schema_name",
            "schemas", "scope_catalog", "scope_name", "scope_schema", "second_microsecond",
            "security", "self", "separator", "sequence", "serializable", "server_name",
            "setof", "setuser", "share", "show", "shutdown", "simple", "soname", "source",
            "spatial", "specific_name", "sql_big_result", "sql_big_selects",
            "sql_big_tables", "sql_calc_found_rows", "sql_log_off", "sql_log_update",
            "sql_low_priority_updates", "sql_select_limit", "sql_small_result",
            "sql_warnings", "sqlca", "sqrt", "ssl", "stable", "starting", "statement",
            "statistics", "status", "stddev_pop", "stddev_samp", "stdin", "stdout",
            "storage", "straight_join", "strict", "string", "structure", "style",
            "subclass_origin", "sublist", "successful", "superuser", "synonym", "sysdate",
            "sysid", "table_name", "tables", "tablespace", "temp", "template", "terminate",
            "terminated", "text", "textsize", "than", "ties", "tinyblob", "tinyint",
            "tinytext", "toast", "top", "top_level_count", "tran", "transaction_active",
            "transactions_committed", "transactions_rolled_back", "transform", "transforms",
            "trigger_catalog", "trigger_name", "trigger_schema", "truncate", "trusted",
            "tsequal", "type", "uescape", "uid", "unbounded", "uncommitted", "unencrypted",
            "unlisten", "unlock", "unnamed", "unsigned", "updatetext", "use",
            "user_defined_type_catalog", "user_defined_type_code", "user_defined_type_name",
            "user_defined_type_schema", "utc_date", "utc_time", "utc_timestamp", "vacuum",
            "valid", "validate", "validator", "var_pop", "var_samp", "varbinary", "varchar2",
            "varcharacter", "variable", "variables", "verbose", "volatile", "waitfor",
            "width_bucket", "writetext", "x509", "xor", "year_month", "zerofill",
        }

        local capturedoperators = oneof {
            "+", "-", "*", "/",
            "%", "^", "!", "&", "|", "?", "~",
            "=", "<", ">",
            ";", ":", ".",
            "{", "}", "[", "]", "(", ")",
        }

        local spaces          = "\\s*"
        local identifier      = "[a-zA-Z\\_][a-zA-Z0-9\\_]*"

        local comment         = "%.*$\\n?"
        local commentopen     = "/\\*"
        local commentclose    = "\\*/"

        local doublequote     = "\""
        local singlequote     = "\'"
        local reversequote    = "`"

        local doublecontent   = "(?:\\\\\"|[^\"])*"
        local singlecontent   = "(?:\\\\\'|[^\'])*"
        local reversecontent  = "(?:\\\\`|[^`])*"

        local decnumber       = "[\\-]?[0-9]+(\\.[0-9]+)?([eEpP]\\-?[0-9]+)?"

        local captureddouble  = capture(doublequote) .. capture(doublecontent) .. capture(doublequote)
        local capturedsingle  = capture(singlequote) .. capture(singlecontent) .. capture(singlequote)
        local capturedreverse = capture(reversequote) .. capture(reversecontent) .. capture(reversequote)

        local style, styled   = styler("sql")

        registerlexer {

            category    = "sql",
            description = "ConTeXt SQL",
            suffixes    = { "sql" },
            version     = "1.0.0",

            setup       = configuration {
--                 comments = {
--                     inline  = "...",
--                     display = { "...", "..." },
--                 },
            },

            repository  = {

                comment_short = {
                    name  = style("context.comment", "comment.comment"),
                    match = comment,
                },

                comment_long = {
                    name          = style("context.comment", "comment.text"),
                    ["begin"]     = commentopen,
                    ["end"]       = commentclose,
                    beginCaptures = { ["0"] = styled("context.command", "comment.open") },
                    endCaptures   = { ["0"] = styled("context.command", "comment.close") },
                },

                keyword_standard = {
                    name  = style("context.keyword", "reserved.standard"),
                    match = capturedkeywords,
                },

                keyword_dialect = {
                    name  = style("context.keyword", "reserved.dialect"),
                    match = captureddialects,
                },

                operator = {
                    name  = style("context.special", "operator"),
                    match = capturedoperators,

                },

                identifier = {
                    name  = style("context.text", "identifier"),
                    match = identifier,
                },

                string_double = {
                    match    = captureddouble,
                    captures = {
                        ["1"] = styled("context.special", "doublequoted.open"),
                        ["2"] = styled("context.text", "doublequoted.text"),
                        ["3"] = styled("context.special", "doublequoted.close"),
                    },
                },

                string_single = {
                    match    = capturedsingle,
                    captures = {
                        ["1"] = styled("context.special", "singlequoted.open"),
                        ["2"] = styled("context.text", "singlequoted.text"),
                        ["3"] = styled("context.special", "singlequoted.close"),
                    },
                },

                string_reverse = {
                    match    = capturedreverse,
                    captures = {
                        ["1"] = styled("context.special", "reversequoted.open"),
                        ["2"] = styled("context.text", "reversequoted.text"),
                        ["3"] = styled("context.special", "reversequoted.close"),
                    },
                },

                number = {
                    name  = style("context.number", "number"),
                    match = decnumber,
                },

            },

            patterns = {
                include("#keyword_standard"),
                include("#keyword_dialect"),
                include("#identifier"),
                include("#string_double"),
                include("#string_single"),
                include("#string_reverse"),
                include("#comment_long"),
                include("#comment_short"),
                include("#number"),
                include("#operator"),
            },

        }

    end

    -- The bnf lexer (only used for documentation, untested).

    do

        local operators = oneof {
            "*", "+", "-", "/",
            ",", ".", ":", ";",
            "(", ")", "<", ">", "{", "}", "[",  "]",
             "#", "=", "?", "@", "|", " ", "!","$", "%", "&", "\\", "^", "-", "_", "`", "~",
        }

        local spaces          = "\\s*"

        local text            = "[a-zA-Z0-9]|" .. operators

        local doublequote     = "\""
        local singlequote     = "\'"

        local termopen        = "<"
        local termclose       = ">"
        local termcontent     = "([a-zA-Z][a-zA-Z0-9\\-]*)"

        local becomes         = "::="
        local extra           = "|"

        local captureddouble  = capture(doublequote) .. capture(text) .. capture(doublequote)
        local capturedsingle  = capture(singlequote) .. capture(text) .. capture(singlequote)
        local capturedterm    = capture(termopen) .. capture(termcontent) .. capture(termclose)

        local style, styled   = styler("bnf")

        registerlexer {

            category    = "bnf",
            description = "ConTeXt BNF",
            suffixes    = { "bnf" },
            version     = "1.0.0",

            setup       = configuration {
                pairs = {
                    { "<", ">" },
                },
            },

            repository  = {

                term = {
                    match    = capturedterm,
                    captures = {
                        ["1"] = styled("context.command", "term.open"),
                        ["2"] = styled("context.text", "term.text"),
                        ["3"] = styled("context.command", "term.close"),
                    },
                },

                text_single = {
                    match    = capturedsingle,
                    captures = {
                        ["1"] = styled("context.special", "singlequoted.open"),
                        ["2"] = styled("context.text", "singlequoted.text"),
                        ["3"] = styled("context.special", "singlequoted.close"),
                    },
                },

                text_double = {
                    match    = captureddouble,
                    captures = {
                        ["1"] = styled("context.special", "doublequoted.open"),
                        ["2"] = styled("context.text", "doublequoted.text"),
                        ["3"] = styled("context.special", "doublequoted.close"),
                    },
                },

                becomes = {
                    name  = style("context.operator", "symbol.becomes"),
                    match = becomes,
                },

                extra = {
                    name  = style("context.extra", "symbol.extra"),
                    match = extra,
                },

            },

            patterns = {
                include("#term"),
                include("#text_single"),
                include("#text_reverse"),
                include("#becomes"),
                include("#extra"),
            },

        }

    end

    do

        -- A rather simple one, but consistent with the rest. I don't use an IDE or fancy
        -- features. No tricks for me.

        local function words(list)
            table.sort(list,sorter)
            return "\\b(" .. table.concat(list,"|") .. ")\\b"
        end

        local capturedkeywords = words { -- copied from cpp.lua
            -- c
            "asm", "auto", "break", "case", "const", "continue", "default", "do", "else",
            "extern", "false", "for", "goto", "if", "inline", "register", "return",
            "sizeof", "static", "switch", "true", "typedef", "volatile", "while",
            "restrict",
            -- hm
            "_Bool", "_Complex", "_Pragma", "_Imaginary",
            -- c++.
            "catch", "class", "const_cast", "delete", "dynamic_cast", "explicit",
            "export", "friend", "mutable", "namespace", "new", "operator", "private",
            "protected", "public", "signals", "slots", "reinterpret_cast",
            "static_assert", "static_cast", "template", "this", "throw", "try", "typeid",
            "typename", "using", "virtual"
        }

        local captureddatatypes = words { -- copied from cpp.lua
            "bool", "char", "double", "enum", "float", "int", "long", "short", "signed",
            "struct", "union", "unsigned", "void"
        }

        local capturedluatex = words { -- new
            "word", "halfword", "quarterword", "scaled", "pointer", "glueratio",
        }

        local capturedmacros = words { -- copied from cpp.lua
            "define", "elif", "else", "endif", "error", "if", "ifdef", "ifndef", "import",
            "include", "line", "pragma", "undef", "using", "warning"
        }

        local operators = oneof {
            "*", "+", "-", "/",
            "%", "^", "!", "&", "?", "~", "|",
            "=", "<", ">",
            ";", ":", ".",
            "{", "}", "[", "]", "(", ")",
        }

        local spaces          = "\\s*"

        local identifier      = "[A-Za-z_][A-Za-z_0-9]*"

        local comment         = "//.*$\\n?"
        local commentopen     = "/\\*"
        local commentclose    = "\\*/"

        local doublequote     = "\""
        local singlequote     = "\'"
        local reversequote    = "`"

        local doublecontent   = "(?:\\\\\"|[^\"])*"
        local singlecontent   = "(?:\\\\\'|[^\'])*"

        local captureddouble  = capture(doublequote) .. capture(doublecontent) .. capture(doublequote)
        local capturedsingle  = capture(singlequote) .. capture(singlecontent) .. capture(singlequote)

        local texopen         = "/\\*tex"
        local texclose        = "\\*/"

        local hexnumber       = "[\\-]?0[xX][A-Fa-f0-9]+(\\.[A-Fa-f0-9]+)?([eEpP]\\-?[A-Fa-f0-9]+)?"
        local decnumber       = "[\\-]?[0-9]+(\\.[0-9]+)?([eEpP]\\-?[0-9]+)?"

        local capturedmacros  = spaces .. capture("#") .. spaces .. capturedmacros

        local style, styled   = styler("c")

        registerlexer {

            category    = "cpp",
            description = "ConTeXt C",
            suffixes    = { "c", "h", "cpp", "hpp" },
            version     = "1.0.0",

            setup       = configuration {
                pairs = {
                    { "{", "}" },
                    { "[", "]" },
                    { "(", ")" },
                },
            },

            repository  = {

                keyword = {
                    match = capturedkeywords,
                    name  = style("context.keyword","c"),
                },

                datatype = {
                    match = captureddatatypes,
                    name  = style("context.keyword","datatype"),
                },

                luatex = {
                    match = capturedluatex,
                    name  = style("context.command","luatex"),
                },

                macro = {
                    match = capturedmacros,
                    captures = {
                        ["1"] = styled("context.data","macro.tag"),
                        ["2"] = styled("context.data","macro.name"),
                    }
                },

                texcomment = {
                    ["begin"]     = texopen,
                    ["end"]       = texclose,
                    patterns      = embedded("tex"),
                    beginCaptures = { ["0"] = styled("context.comment", "tex.open") },
                    endCaptures   = { ["0"] = styled("context.comment", "tex.close") },
                },

                longcomment = {
                    name      = style("context.comment","long"),
                    ["begin"] = commentopen,
                    ["end"]   = commentclose,
                },

                shortcomment = {
                    name  = style("context.comment","short"),
                    match = comment,
                },

                identifier = {
                    name  = style("context.default","identifier"),
                    match = identifier,
                },

                operator = {
                    name  = style("context.operator","any"),
                    match = operators,
                },

                string_double = {
                    match    = captureddouble,
                    captures = {
                        ["1"] = styled("context.special", "doublequoted.open"),
                        ["2"] = styled("context.string",  "doublequoted.text"),
                        ["3"] = styled("context.special", "doublequoted.close"),
                    },
                },

                string_single = {
                    match    = capturedsingle,
                    captures = {
                        ["1"] = styled("context.special", "singlequoted.open"),
                        ["2"] = styled("context.string",  "singlequoted.text"),
                        ["3"] = styled("context.special", "singlequoted.close"),
                    },
                },

                hexnumber = {
                    name  = style("context.number","hex"),
                    match = hexnumber,
                },

                decnumber = {
                    name  = style("context.number","dec"),
                    match = decnumber,
                },

            },

            patterns = {
                include("#keyword"),
                include("#datatype"),
                include("#luatex"),
                include("#identifier"),
                include("#macro"),
                include("#string_double"),
                include("#string_single"),
                include("#texcomment"),
                include("#longcomment"),
                include("#shortcomment"),
                include("#hexnumber"),
                include("#decnumber"),
                include("#operator"),
            },

        }

    end

    -- The pdf lexer.

    do

        -- we can assume no errors in the syntax

        local spaces                  = "\\s*"

        local reserved                = oneof { "true" ,"false" , "null" }
        local reference               = "R"

        local dictionaryopen          = "<<"
        local dictionaryclose         = ">>"

        local arrayopen               = "\\["
        local arrayclose              = "\\]"

        local stringopen              = "\\("
        local stringcontent           = "(?:\\\\[\\(\\)]|[^\\(\\)])*"
        local stringclose             = "\\)"

        local hexstringopen           = "<"
        local hexstringcontent        = "[^>]*"
        local hexstringclose          = ">"

        local unicodebomb             = "feff"

        local objectopen              = "obj"    -- maybe also ^ $
        local objectclose             = "endobj" -- maybe also ^ $

        local streamopen              = "^stream$"
        local streamclose             = "^endstream$"

        local name                    = "/[^\\s<>/\\[\\]\\(\\)]+"   -- no need to be more clever than this
        local integer                 = "[\\-]?[0-9]+"              -- no need to be more clever than this
        local real                    = "[\\-]?[0-9]*[\\.]?[0-9]+"  -- no need to be more clever than this

        local capturedcardinal        = "([0-9]+)"

        local captureddictionaryopen  = capture(dictionaryopen)
        local captureddictionaryclose = capture(dictionaryclose)

        local capturedarrayopen       = capture(arrayopen)
        local capturedarrayclose      = capture(arrayclose)

        local capturedobjectopen      = capture(objectopen)
        local capturedobjectclose     = capture(objectclose)

        local capturedname            = capture(name)
        local capturedinteger         = capture(integer)
        local capturedreal            = capture(real)
        local capturedreserved        = capture(reserved)
        local capturedreference       = capture(reference)

        local capturedunicode         = capture(hexstringopen) .. capture(unicodebomb) .. capture(hexstringcontent) .. capture(hexstringclose)
        local capturedunicode         = capture(hexstringopen) .. capture(unicodebomb) .. capture(hexstringcontent) .. capture(hexstringclose)
        local capturedwhatsit         = capture(hexstringopen) .. capture(hexstringcontent) .. capture(hexstringclose)
        local capturedstring          = capture(stringopen) .. capture(stringcontent) .. capture(stringclose)

        local style, styled           = styler("pdf")

        -- strings are not ok yet: there can be nested unescaped () but not critical now

        registerlexer {

            category    = "pdf",
            description = "ConTeXt PDF",
            suffixes    = { "pdf" },
            version     = "1.0.0",

            setup       = configuration {
                pairs = {
                    { "<", ">" },
                    { "[", "]" },
                    { "(", ")" },
                },
            },

            repository  = {

                comment = {
                    name  = style("context.comment","comment"),
                    match = "%.*$\\n?",
                },

                content = {
                    patterns = {
                        { include = "#dictionary" },
                        { include = "#stream" },
                        { include = "#array" },
                        {
                            name  = style("context.constant","object.content.name"),
                            match = capturedname,
                        },
                        {
                            match    = capturedcardinal .. spaces .. capturedcardinal .. spaces .. capturedreference,
                            captures = {
                                ["1"] = styled("context.warning","content.reference.1"),
                                ["2"] = styled("context.warning","content.reference.2"),
                                ["3"] = styled("context.command","content.reference.3"),
                            }
                        },
                        {
                            name  = style("context.number","content.real"),
                            match = capturedreal,
                        },
                        {
                            name  = style("context.number","content.integer"),
                            match = capturedinteger,
                        },
                        {
                            match    = capturedstring,
                            captures = {
                                ["1"] = styled("context.quote","content.string.open"),
                                ["2"] = styled("context.string","content.string.text"),
                                ["3"] = styled("context.quote","content.string.close"),
                            }
                        },
                        {
                            name  = style("context.number","content.reserved"),
                            match = capturedreserved,
                        },
                        {
                            match    = capturedunicode,
                            captures = {
                                ["1"] = styled("context.quote","content.unicode.open"),
                                ["2"] = styled("context.plain","content.unicode.bomb"),
                                ["3"] = styled("context.string","content.unicode.text"),
                                ["4"] = styled("context.quote","content.unicode.close"),
                            }
                        },
                        {
                            match    = capturedwhatsit,
                            captures = {
                                ["1"] = styled("context.quote","content.whatsit.open"),
                                ["2"] = styled("context.string","content.whatsit.text"),
                                ["3"] = styled("context.quote","content.whatsit.close"),
                            }
                        },
                    },
                },

                object = {
                    ["begin"]     = capturedcardinal .. spaces .. capturedcardinal .. spaces .. capturedobjectopen,
                    ["end"]       = capturedobjectclose,
                    patterns      = { { include = "#content" } },
                    beginCaptures = {
                        ["1"] = styled("context.warning","object.1"),
                        ["2"] = styled("context.warning","object.2"),
                        ["3"] = styled("context.keyword", "object.open")
                    },
                    endCaptures   = {
                        ["1"] = styled("context.keyword", "object.close")
                    },
                },

                array = {
                    ["begin"]     = capturedarrayopen,
                    ["end"]       = capturedarrayclose,
                    patterns      = { { include = "#content" } },
                    beginCaptures = { ["1"] = styled("context.grouping", "array.open") },
                    endCaptures   = { ["1"] = styled("context.grouping", "array.close") },
                },

                dictionary = {
                    ["begin"]     = captureddictionaryopen,
                    ["end"]       = captureddictionaryclose,
                    beginCaptures = { ["1"] = styled("context.grouping", "dictionary.open") },
                    endCaptures   = { ["1"] = styled("context.grouping", "dictionary.close") },
                    patterns      = {
                        {
                            ["begin"]     = capturedname .. spaces,
                            ["end"]       = "(?=[>])",
                            beginCaptures = { ["1"] = styled("context.command", "dictionary.name") },
                            patterns = { { include = "#content" } },
                        },
                    },
                },

                xref = {
                    ["begin"] = "xref" .. spaces,
                    ["end"]   = "(?=[^0-9])",
                    captures  = {
                        ["0"] = styled("context.keyword", "xref.1"),
                    },
                    patterns = {
                        {
                            ["begin"] = capturedcardinal .. spaces .. capturedcardinal .. spaces,
                            ["end"]   = "(?=[^0-9])",
                            captures  = {
                                ["1"] = styled("context.number", "xref.2"),
                                ["2"] = styled("context.number", "xref.3"),
                            },
                            patterns = {
                                {
                                    ["begin"] = capturedcardinal .. spaces .. capturedcardinal .. spaces .. "([fn])" .. spaces,
                                    ["end"]   = "(?=.)",
                                    captures = {
                                        ["1"] = styled("context.number", "xref.4"),
                                        ["2"] = styled("context.number", "xref.5"),
                                        ["3"] = styled("context.keyword", "xref.6"),
                                    },
                                },
                            },
                        },
                    },
                },

                startxref = {
                    ["begin"] = "startxref" .. spaces,
                    ["end"]   = "(?=[^0-9])",
                    captures  = {
                        ["0"] = styled("context.keyword", "startxref.1"),
                    },
                    patterns = {
                        {
                            ["begin"] = capturedcardinal .. spaces,
                            ["end"]   = "(?=.)",
                            captures  = {
                                ["1"] = styled("context.number", "startxref.2"),
                            },
                        },
                    },
                },

                trailer = {
                    name  = style("context.keyword", "trailer"),
                    match = "trailer",
                },

                stream = {
                    ["begin"]     = streamopen,
                    ["end"]       = streamclose,
                    beginCaptures = { ["0"] = styled("context.keyword", "stream.open") },
                    endCaptures   = { ["0"] = styled("context.keyword", "stream.close") },
                },

            },

            patterns = {
                include("#object"),
                include("#comment"),
                include("#trailer"),
                include("#dictionary"), -- cheat: trailer dict
                include("#startxref"),
                include("#xref"),
            },

        }

    end

    -- The JSON lexer. I don't want to spend time on (and mess up the lexer) with
    -- some ugly multistage key/value parser so we just assume that the key is on
    -- the same line as the colon and the value. It looks bad otherwise anyway.

    do

        local spaces             = "\\s*"
        local separator          = "\\,"
        local becomes            = "\\:"

        local arrayopen          = "\\["
        local arrayclose         = "\\]"

        local hashopen           = "\\{"
        local hashclose          = "\\}"

        local stringopen         = "\""
        local stringcontent      = "(?:\\\\\"|[^\"])*"
        local stringclose        = stringopen

        local reserved           = oneof { "true", "false", "null" }

        local hexnumber          = "[\\-]?0[xX][A-Fa-f0-9]+(\\.[A-Fa-f0-9]+)?([eEpP]\\-?[A-Fa-f0-9]+)?"
        local decnumber          = "[\\-]?[0-9]+(\\.[0-9]+)?([eEpP]\\-?[0-9]+)?"

        local capturedarrayopen  = capture(arrayopen)
        local capturedarrayclose = capture(arrayclose)
        local capturedhashopen   = capture(hashopen)
        local capturedhashclose  = capture(hashclose)

        local capturedreserved   = capture(reserved)
        local capturedbecomes    = capture(becomes)
        local capturedseparator  = capture(separator)
        local capturedstring     = capture(stringopen) .. capture(stringcontent) .. capture(stringclose)
        local capturedhexnumber  = capture(hexnumber)
        local captureddecnumber  = capture(decnumber)

        local style, styled      = styler("json")

        registerlexer {

            category    = "json",
            description = "ConTeXt JSON",
            suffixes    = { "json" },
            version     = "1.0.0",

            setup       = configuration {
                pairs = {
                    { "{", "}" },
                    { "[", "]" },
                },
            },

            repository = {

                separator = {
                    name  = style("context.operator","separator"),
                    match = spaces .. capturedseparator,
                },

                reserved = {
                    name  = style("context.primitive","reserved"),
                    match = spaces .. capturedreserved,
                },

                hexnumber = {
                    name  = style("context.number","hex"),
                    match = spaces .. capturedhexnumber,
                },

                decnumber = {
                    name  = style("context.number","dec"),
                    match = spaces .. captureddecnumber,
                },

                string = {
                    match    = spaces .. capturedstring,
                    captures = {
                        ["1"] = styled("context.quote","string.open"),
                        ["2"] = styled("context.string","string.text"),
                        ["3"] = styled("context.quote","string.close"),
                    },
                },

                kv_reserved = {
                    match    = capturedstring .. spaces .. capturedbecomes .. spaces .. capturedreserved,
                    captures = {
                        ["1"] = styled("context.quote",    "reserved.key.open"),
                        ["2"] = styled("context.text",     "reserved.key.text"),
                        ["3"] = styled("context.quote",    "reserved.key.close"),
                        ["4"] = styled("context.operator", "reserved.becomes"),
                        ["5"] = styled("context.primitive","reserved.value"),
                    }
                },

                kv_hexnumber = {
                    match = capturedstring .. spaces .. capturedbecomes .. spaces .. capturedhexnumber,
                    captures = {
                        ["1"] = styled("context.quote",   "hex.key.open"),
                        ["2"] = styled("context.text",    "hex.key.text"),
                        ["3"] = styled("context.quote",   "hex.key.close"),
                        ["4"] = styled("context.operator","hex.becomes"),
                        ["5"] = styled("context.number",  "hex.value"),
                    }
                },

                kv_decnumber = {
                    match = capturedstring .. spaces .. capturedbecomes .. spaces .. captureddecnumber,
                    captures = {
                        ["1"] = styled("context.quote",   "dec.key.open"),
                        ["2"] = styled("context.text",    "dec.key.text"),
                        ["3"] = styled("context.quote",   "dec.key.close"),
                        ["4"] = styled("context.operator","dec.becomes"),
                        ["5"] = styled("context.number",  "dec.value"),
                    }
                },

                kv_string = {
                    match = capturedstring .. spaces .. capturedbecomes .. spaces .. capturedstring,
                    captures = {
                        ["1"] = styled("context.quote",   "string.key.open"),
                        ["2"] = styled("context.text",    "string.key.text"),
                        ["3"] = styled("context.quote",   "string.key.close"),
                        ["4"] = styled("context.operator","string.becomes"),
                        ["5"] = styled("context.quote",   "string.value.open"),
                        ["6"] = styled("context.string",  "string.value.text"),
                        ["7"] = styled("context.quote",   "string.value.close"),
                    },
                },

                kv_array = {
                    ["begin"]     = capturedstring .. spaces .. capturedbecomes .. spaces .. capturedarrayopen,
                    ["end"]       = arrayclose,
                    beginCaptures = {
                        ["1"] = styled("context.quote",   "array.key.open"),
                        ["2"] = styled("context.text",    "array.key.text"),
                        ["3"] = styled("context.quote",   "array.key.close"),
                        ["4"] = styled("context.operator","array.becomes"),
                        ["5"] = styled("context.grouping","array.value.open")
                    },
                    endCaptures   = {
                        ["0"] = styled("context.grouping","array.value.close")
                    },
                    patterns      = { include("#content") },
                },

                kv_hash = {
                    ["begin"]     = capturedstring .. spaces .. capturedbecomes .. spaces .. capturedhashopen,
                    ["end"]       = hashclose,
                    beginCaptures = {
                        ["1"] = styled("context.quote",   "hash.key.open"),
                        ["2"] = styled("context.text",    "hash.key.text"),
                        ["3"] = styled("context.quote",   "hash.key.close"),
                        ["4"] = styled("context.operator","hash.becomes"),
                        ["5"] = styled("context.grouping","hash.value.open")
                    },
                    endCaptures   = {
                        ["0"] = styled("context.grouping","hash.value.close")
                    },
                    patterns      = { include("#kv_content") },
                },

                content = {
                    patterns = {
                        include("#string"),
                        include("#hexnumber"),
                        include("#decnumber"),
                        include("#reserved"),
                        include("#hash"),
                        include("#array"),
                        include("#separator"),
                    },
                },

                kv_content = {
                    patterns = {
                        include("#kv_string"),
                        include("#kv_hexnumber"),
                        include("#kv_decnumber"),
                        include("#kv_reserved"),
                        include("#kv_hash"),
                        include("#kv_array"),
                        include("#separator"),
                    },
                },

                array = {
                    ["begin"]     = arrayopen,
                    ["end"]       = arrayclose,
                    beginCaptures = { ["0"] = styled("context.grouping","array.open") },
                    endCaptures   = { ["0"] = styled("context.grouping","array.close") },
                    patterns      = { include("#content") },
                },

                hash = {
                    ["begin"]     = hashopen,
                    ["end"]       = hashclose,
                    beginCaptures = { ["0"] = styled("context.grouping","hash.open") },
                    endCaptures   = { ["0"] = styled("context.grouping","hash.close") },
                    patterns      = { include("#kv_content") },
                },

            },

            patterns = {
                include("#content"),
            },

        }

    end

    savepackage()

end

function scripts.vscode.start()
    local path = locate()
    if path then
        local command = 'start "vs code context" code --reuse-window --ignore-gpu-blacklist --extensions-dir "' .. path .. '" --install-extension context'
        report("running command: %s",command)
        os.execute(command)
    end
end

if environment.arguments.generate then
    scripts.vscode.generate()
elseif environment.arguments.start then
    scripts.vscode.start()
elseif environment.arguments.exporthelp then
    application.export(environment.arguments.exporthelp,environment.files[1])
else
    application.help()
end

scripts.vscode.generate([[t:/vscode/data/context/extensions]])
