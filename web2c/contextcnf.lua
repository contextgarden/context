return {

    type    = "configuration",
    version = "1.1.1",
    date    = "2011-06-02",
    time    = "14:59:00",
    comment = "ConTeXt MkIV configuration file",
    author  = "Hans Hagen, PRAGMA-ADE, Hasselt NL",

    content = {

        -- Originally there was support for engines and progname but I don't expect
        -- other engines to use this file, so first engines were removed. After that
        -- if made sense also to get rid of progname. At some point specific formats
        -- will be supported but then as a subtable with fallbacks, which sounds more
        -- natural. Also, at some point the paths will become tables. For the moment
        -- I don't care too much about it as extending is easy.

        variables = {

            -- The following variable is predefined (but can be overloaded) and in
            -- most cases you can leave this one untouched. The built-in definition
            -- permits relocation of the tree.
            --
            --  if this_is_texlive then
            --      resolvers.luacnfspec = 'selfautodir:;selfautoparent:;{selfautodir:,selfautoparent:}{/share,}/texmf{-local,}/web2c'
            --  else
            --      resolvers.luacnfspec = 'home:texmf/web2c;selfautoparent:texmf{-local,-context,}/web2c'
            --  end
            --
            -- more readable is:
            --
            -- TEXMFCNF     = {
            --     "home:texmf/web2c,
            --     "selfautoparent:texmf-local/web2c",
            --     "selfautoparent:texmf-context/web2c",
            --     "selfautoparent:texmf/web2c",
            -- }

            -- One problem is that DEFAULT_TEXMFCNF is hardcoded in kpse so in fact we should
            -- have access to it without the need to initialize kpse.

            -- We have only one cache path but there can be more. The first writable one
            -- will be chose but there can be more readable paths.
            --
            -- Keep in mind that MkIV does not run at all on older texlives so when using
            -- that you don't need to worry about ancient and obsolete configuration paths,
            -- simply because no configuration will be found there.

            TEXMFCACHE      = "$SELFAUTOPARENT/texmf-cache",

            -- not used by context at all

            TEXMFSYSVAR     = "$TEXMFCACHE",
            TEXMFVAR        = "$TEXMFCACHE",

            -- I don't like this texmf under home and texmf-home would make more
            -- sense. One never knows what installers put under texmf anywhere and
            -- sorting out problems will be a pain. But on the other hand ... home
            -- mess is normally under the users own responsibility.
            --
            -- By using prefixes we don't get expanded paths in the cache __path__
            -- entry. This makes the tex root relocatable.

            TEXMFOS         = "selfautodir:",
            TEXMFSYSTEM     = "selfautoparent:texmf-$SELFAUTOSYSTEM",
            TEXMFMAIN       = "selfautoparent:texmf",
            TEXMFDIST       = "selfautoparent:texmf-dist",
            TEXMFCONTEXT    = "selfautoparent:texmf-context",
            TEXMFLOCAL      = "selfautoparent:texmf-local",
            TEXMFFONTS      = "selfautoparent:texmf-fonts",
            TEXMFPROJECT    = "selfautoparent:texmf-project",

            TEXMFHOME       = "home:texmf",
         -- TEXMFHOME       = os.name == "macosx" and "home:Library/texmf" or "home:texmf",

            -- We need texmfos for a few rare files but as I have a few more bin trees
            -- a hack is needed. Maybe other users also have texmf-platform-new trees.

            TEXMF           = "{$TEXMFHOME,!!$TEXMFPROJECT,!!$TEXMFFONTS,!!$TEXMFLOCAL,!!$TEXMFCONTEXT,!!$TEXMFSYSTEM,!!$TEXMFDIST,!!$TEXMFMAIN}",

            TEXFONTMAPS     = ".;$TEXMF/fonts/data//;$TEXMF/fonts/map/{pdftex,dvips}//",
            ENCFONTS        = ".;$TEXMF/fonts/data//;$TEXMF/fonts/enc/{dvips,pdftex}//",
            VFFONTS         = ".;$TEXMF/fonts/{data,vf}//",
            TFMFONTS        = ".;$TEXMF/fonts/{data,tfm}//",
            PKFONTS         = ".;$TEXMF/fonts/{data,pk}//",
            T1FONTS         = ".;$TEXMF/fonts/{data,type1}//;$OSFONTDIR",
            AFMFONTS        = ".;$TEXMF/fonts/{data,afm}//;$OSFONTDIR",
            TTFONTS         = ".;$TEXMF/fonts/{data,truetype}//;$OSFONTDIR",
            OPENTYPEFONTS   = ".;$TEXMF/fonts/{data,opentype}//;$OSFONTDIR",
            FONTFEATURES    = ".;$TEXMF/fonts/{data,fea}//;$OPENTYPEFONTS;$TTFONTS;$T1FONTS;$AFMFONTS",
            FONTCIDMAPS     = ".;$TEXMF/fonts/{data,cid}//",
            OFMFONTS        = ".;$TEXMF/fonts/{data,ofm,tfm}//",
            OVFFONTS        = ".;$TEXMF/fonts/{data,ovf,vf}//",

            TEXINPUTS       = ".;$TEXMF/tex/{context,plain/base,generic}//",
            MPINPUTS        = ".;$TEXMF/metapost/{context,base,}//",

            -- In the next variable the inputs path will go away.

            TEXMFSCRIPTS    = ".;$TEXMF/scripts/context/{lua,ruby,python,perl}//;$TEXINPUTS",
            PERLINPUTS      = ".;$TEXMF/scripts/context/perl",
            PYTHONINPUTS    = ".;$TEXMF/scripts/context/python",
            RUBYINPUTS      = ".;$TEXMF/scripts/context/ruby",
            LUAINPUTS       = ".;$TEXINPUTS;$TEXMF/scripts/context/lua//;$TEXMF",
            CLUAINPUTS      = ".;$SELFAUTOLOC/lib/{context,$engine,luatex}/lua//",

            -- texmf-local/tex/generic/example/foo :
            --
            -- package.helpers.trace = true
            -- require("example.foo.bar")

            -- Not really used by MkIV so they might go away.

            BIBINPUTS       = ".;$TEXMF/bibtex/bib//;$TEXMF/tex/context//",
            BSTINPUTS       = ".;$TEXMF/bibtex/bst//;$TEXMF/tex/context//",

            -- Experimental

            ICCPROFILES     = ".;$TEXMF/colors/icc/{context,profiles}//;$OSCOLORDIR",

            -- A few special ones that will change some day.

            FONTCONFIG_FILE = "fonts.conf",
            FONTCONFIG_PATH = "$TEXMFSYSTEM/fonts/conf",

         -- EXTRAFONTS      = ".;e:/tmp//",

            -- we now have a different subsystem for this,

        },

        -- We have a few reserved subtables. These control runtime behaviour. The
        -- keys have names like 'foo.bar' which means that you have to use keys
        -- like ['foo.bar'] so for convenience we also support 'foo_bar'.

        directives = {

            -- There are a few variables that determine the engines
            -- limits. Most will fade away when we close in on version 1.

            ["luatex.expanddepth"]       =  "10000", -- 10000
            ["luatex.hashextra"]         = "100000", --     0
            ["luatex.nestsize"]          =   "1000", --    50
            ["luatex.maxinopen"]         =   "1000", --    15
            ["luatex.maxprintline"]      = " 10000", --    79
            ["luatex.maxstrings"]        = "500000", -- 15000 -- obsolete
            ["luatex.paramsize"]         =  "25000", --    60
            ["luatex.savesize"]          = "100000", --  4000
            ["luatex.stacksize"]         = "100000", --   300

            -- A few process related variables come next.

         -- ["system.checkglobals"]      = "10",
         -- ["system.nostatistics"]      = "yes",
            ["system.errorcontext"]      = "10",
            ["system.compile.cleanup"]   = "no",    -- remove tma files
            ["system.compile.strip"]     = "yes",   -- strip tmc files

            -- sandboxing (these only kick in when --sandbox is given) .. the examples
            -- below are just that, examples, as sandboxing is off by default ... when
            -- turned on, restrictions kick in, and programs registered at runtime have
            -- (even) more restrictions than already registered ones

         -- ["system.rootlist"]          = { "/data" }, -- { { "/data", "read" }, ... }
         --
         -- ["system.executionmode"]     = "list", -- none | list | all
         -- ["system.executionlist"]     = {
         --     "context",
         --     "bibtex", "mlbibcontext",
         --     "curl",
         --     "gswin64c", "gswin32c", "gs",
         --     "gm", "graphicmagick", "imagemagick",
         --     "pdftops",
         --     "pstoedit",
         --     "inkscape",
         --     "woff2_decompress",
         --     "hb-shape",
         -- },
         --
         -- ["system.librarymode"]       = "list", -- none | list | all
         -- ["system.librarylist"]       = {
         --     "mysql",
         --     "sqlite3",
         --     "libharfbuzz", "libharfbuzz-0",
         -- }

            -- The mplib library support mechanisms have their own
            -- configuration. Normally these variables can be left as
            -- they are.

            ["mplib.texerrors"]          = "yes",

            -- Normally you can leave the font related directives untouched
            -- as they only make sense when testing.

         -- ["fonts.autoreload"]         = "no",
         -- ["fonts.otf.loader.cleanup"] = "0",     -- 0 1 2 3

            -- In an edit cycle it can be handy to launch an editor. The
            -- preferred one can be set here.

         -- ["pdfview.method"]           = "sumatra",

         -- ["fonts.usesystemfonts"]     = false,

            -- You can permit loading modules with no prefix:

         -- ["modules.permitunprefixed"] = "no",

            -- You can permit loading files from anywhere in the TDS tree:

         -- ["resolvers.otherwise"]      = "no",

        },

        experiments = {
            ["fonts.autorscale"] = "yes",
        },

        trackers = {
        },

    },

 -- TEXMFCACHE  = "$SELFAUTOPARENT/texmf-cache", -- for old times sake

}
