/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

engine_state_info lmt_engine_state = {
    .lua_init         = 0,
    .lua_only         = 0,
    .luatex_banner    = NULL,
    .engine_name      = NULL,
    .startup_filename = NULL,
    .startup_jobname  = NULL,
    .dump_name        = NULL,
    .utc_time         = 0,
    .permit_loadlib   = 0,
};

/*tex
    We assume that the strings are proper \UTF\ and in \MSWINDOWS\ we handle wide characters to get
    that right.
*/

typedef struct environment_state_info {
    char **argv;
    int    argc;
    int    npos;
    char  *flag;
    char  *value;
    char  *name;
    char  *ownpath;
    char  *ownbase;
    char  *ownname;
    char  *owncore;
    char  *input_name;
    int    luatex_lua_offset;
} environment_state_info;

static environment_state_info lmt_environment_state = {
    .argv              = NULL,
    .argc              = 0,
    .npos              = 0,
    .flag              = NULL,
    .value             = NULL,
    .name              = NULL,
    .ownpath           = NULL,
    .ownbase           = NULL,
    .ownname           = NULL,
    .owncore           = NULL,
    .input_name        = NULL,
    .luatex_lua_offset = 0,
};

/*tex todo: make helpers in loslibext which has similar code */

static void enginelib_splitnames(void)
{
    char *p = lmt_memory_strdup(lmt_environment_state.ownpath); /*tex We need to make copies! */
    /*
    printf("ownpath = %s\n",environment_state.ownpath);
    printf("ownbase = %s\n",environment_state.ownbase);
    printf("ownname = %s\n",environment_state.ownname);
    printf("owncore = %s\n",environment_state.owncore);
    */
    /*
        We loose some here but not enough to worry about. Maybe eventually we will use our own
        |basename| and |dirname| anyway.
    */
    lmt_environment_state.ownbase = aux_basename(lmt_memory_strdup(p));
    lmt_environment_state.ownname = aux_basename(lmt_memory_strdup(p));
    lmt_environment_state.ownpath = aux_dirname(lmt_memory_strdup(p)); /* We could use p and not free later, but this is cleaner. */
    /* */
    for (size_t i = 0; i < strlen(lmt_environment_state.ownname); i++) {
        if (lmt_environment_state.ownname[i] == '.') {
            lmt_environment_state.ownname[i] = '\0';
            break ;
        }
    }
    lmt_environment_state.owncore = lmt_memory_strdup(lmt_environment_state.ownname);
    /*
    printf("ownpath = %s\n",environment_state.ownpath);
    printf("ownbase = %s\n",environment_state.ownbase);
    printf("ownname = %s\n",environment_state.ownname);
    printf("owncore = %s\n",environment_state.owncore);
    */
    lmt_memory_free(p);
}

/*tex A bunch of internalized strings: see |linterface.h |.*/

/* declare_shared_lua_keys; */
/* declare_metapost_lua_keys; */

char *tex_engine_input_filename(void)
{
    /*tex When npos equals zero we have no filename i.e. nothing that doesn't start with |--|. */
    return lmt_environment_state.npos > 0 && lmt_environment_state.npos < lmt_environment_state.argc ? lmt_environment_state.argv[lmt_environment_state.npos] : NULL;
}

/*tex

    Filenames can have spaces in which case (double) quotes are used to indicate the bounds of the
    string. At the \TEX\ level curly braces are also an option but these are dealt with in the
    scanner.

    Comment: maybe we should also support single quotes, so that we're consistent with \LUA\ quoting.

*/

static char *enginelib_normalize_quotes(const char* name, const char* mesg)
{
    char *ret = lmt_memory_malloc(strlen(name) + 3);
    if (ret) {
        int must_quote = strchr(name, ' ') != NULL;
        /* Leave room for quotes and NUL. */
        int quoted = 0;
        char *p = ret;
        if (must_quote) {
            *p++ = '"';
        }
        for (const char *q = name; *q; q++) {
            if (*q == '"') {
                quoted = ! quoted;
            } else {
                *p++ = *q;
            }
        }
        if (must_quote) {
            *p++ = '"';
        }
        *p = '\0';
        if (quoted) {
            tex_emergency_message("system", "unbalanced quotes in %s %s\n", mesg, name);
            tex_emergency_exit();
        }
    }
    return ret;
}

/*

    We support a minimum set of options but more can be supported by supplying an (startup)
    initialization script and/or by setting values in the |texconfig| table. At some point we might
    provide some default initiazation script but that's for later. In fact, a bug in \LUATEX\ <
    1.10 made some of the command line options get lost anyway due to setting their values before
    checking the config table (probably introduced at some time). As no one noticed that anyway,
    removing these from the commandline is okay.

    Part of the commandline handler is providing (minimal) help information and reporting credits
    (more credits can be found in the source file). Here comes the basic help.

    At some point I will likely add a |--permitloadlib| flag and block loading of libraries when
    that flag is not given so that we satisfy operating systems and/or distributions that have some
    restrictions on loading libraries. It also means that the optional modules will be (un)locked,
    but we can control that in the runners so it's no big deal because we will never depend on
    external code for the \CONTEXT\ core features.

*/

static void enginelib_show_help(void)
{
    puts(
        "Usage: " luametatex_name_lowercase " --lua=FILE [OPTION]... [TEXNAME[.tex]] [COMMANDS]\n"
        "   or: " luametatex_name_lowercase " --lua=FILE [OPTION]... \\FIRST-LINE\n"
        "   or: " luametatex_name_lowercase " --lua=FILE [OPTION]... &FMT ARGS\n"
        "\n"
        "Run " luametatex_name_camelcase " on TEXNAME, usually creating TEXNAME.pdf. Any remaining COMMANDS"
        "are processed as luatex input, after TEXNAME is read.\n"
        "\n"
        "Alternatively, if the first non-option argument begins with a backslash,\n"
        luametatex_name_camelcase " interprets all non-option arguments as an input line.\n"
        "\n"
        "Alternatively, if the first non-option argument begins with a &, the next word\n"
        "is taken as the FMT to read, overriding all else. Any remaining arguments are\n"
        "processed as above.\n"
        "\n"
        "If no arguments or options are specified, prompt for input.\n"
        "\n"
        "The following regular options are understood:\n"
        "\n"
        "  --credits           display credits and exit\n"
        "  --fmt=FORMAT        load the format file FORMAT\n"
        "  --help              display help and exit\n"
        "  --ini               be ini" luametatex_name_lowercase ", for dumping formats\n"
        "  --jobname=STRING    set the job name to STRING\n"
        "  --lua=FILE          load and execute a lua initialization script\n"
        "  --version           display version and exit\n"
        "\n"
        "Alternate behaviour models can be obtained by special switches\n"
        "\n"
        "  --luaonly           run a lua file, then exit\n"
        "\n"
        "Loading libraries from Lua is blocked unless one explicitly permits it:\n"
        "\n"
        "  --permitloadlib     permit loading of external libraries (coming)\n"
        "\n"
        "See the reference manual for more information about the startup process.\n"
        "\n"
        "Email bug reports to " luametatex_bug_address ".\n"
    );
    exit(EXIT_SUCCESS);
}

/*tex

    This is the minimal version info display.  The credits option provides a bit more information.
*/

static void enginelib_show_version_info(void)
{
    tex_print_version_banner();
    puts(
        "\n"
        "\n"
        "Execute '" luametatex_name_lowercase " --credits' for credits and version details.\n"
        "\n"
        "There is NO warranty. Redistribution of this software is covered by the terms\n"
        "of the GNU General Public License, version 2 or (at your option) any later\n"
        "version. For more information about these matters, see the file named COPYING\n"
        "and the LuaMetaTeX source.\n"
        "\n"
        "Functionality : level " LMT_TOSTRING(luametatex_development_id) "\n"
        "Support       : " luametatex_support_address "\n"
        "Copyright     : The Lua(Meta)TeX Team(s) (2005-2022+)\n"
        "\n"
        "The LuaMetaTeX project is related to ConTeXt development. This macro package\n"
        "tightly integrates TeX and MetaPost in close cooperation with Lua. Updates will\n"
        "happen in sync with ConTeXt and when needed. Don't be fooled by unchanged dates:\n"
        "long term stability is the objective."
    );
    exit(EXIT_SUCCESS);
}

/*tex

    We only mention the most relevelant credits here. The first part is there to indicate a bit of
    history. A very large part of the code, of course, comes from Don Knuths original \TEX, and the
    same is true for most documentation!

    Most of the \ETEX\ extensions are present too. Much of the expansion and protrusion code
    originates in \PDFTEX\ but we don't have any of its backend code. From \OMEGA\ (\ALEPH) we took
    bits and pieces too, for instance the basics of handling directions but at this point we only
    have two directions left (that don't need much code). One features that sticks are the left-
    and right boxes.

    The \METAPOST\ library is an important component and also add quite some code. Here we use a
    stripped down version of the version 2 library with some extra additions.

    We take \LUA\ as it is. In the meantime we went from \LUA\ 5.2 to 5.3 to 5.4 and will follow up
    on what makes sense. For as far as possible no changes are made but there are some configuration
    options in use. We use an \UTF8\ aware setup. Of course \LPEG\ is part of the deal.

    The lean and mean \PDF\ library is made for \LUATEX\ and we use that one here too. In
    \LUAMETATEX\ we use some of its helpers to implement for instance md5 and sha support. In
    \LUAMETATEX\ there are some more than mentioned here but they are {\em not} part of the default
    binary. Some libraries mentioned below can become loaded on demand.

*/

static void enginelib_show_credits(void)
{
    tex_print_version_banner();
    puts(
        "\n"
        "\n"
        "Here we mention those involved in the bits and pieces that define " luametatex_name_camelcase ". More details of\n"
        "what comes from where can be found in the manual and other documents (that come with ConTeXt).\n"
        "\n"
        "  luametatex : Hans Hagen, Alan Braslau, Mojca Miklavec, Wolfgang Schuster, Mikael Sundqvist\n"
        "\n"
        "It is a follow up on:\n"
        "\n"
        "  luatex     : Hans Hagen, Hartmut Henkel, Taco Hoekwater, Luigi Scarso\n"
        "\n"
        "This program itself builds upon the code from:\n"
        "\n"
        "  tex        : Donald Knuth\n"
        "\n"
        "We also took a few features from:\n"
        "\n"
        "  etex       : Peter Breitenlohner, Phil Taylor and friends\n"
        "\n"
        "The font expansion and protrusion code is derived from:\n"
        "\n"
        "  pdftex     : Han The Thanh and friends\n"
        "\n"
        "Part of the bidirectional text flow model is inspired by:\n"
        "\n"
        "  omega      : John Plaice and Yannis Haralambous\n"
        "  aleph      : Giuseppe Bilotta\n"
        "\n"
        "Graphic support is originates in:\n"
        "\n"
        "  metapost   : John Hobby, Taco Hoekwater, Luigi Scarso, Hans Hagen and friends\n"
        "\n"
        "All this is opened up with:\n"
        "\n"
        "  lua        : Roberto Ierusalimschy, Waldemar Celes and Luiz Henrique de Figueiredo\n"
        "  lpeg       : Roberto Ierusalimschy\n"
        "\n"
        "A few libraries are embedded, of which we mention:\n"
        "\n"
# ifdef MI_MALLOC_VERSION
        "  mimalloc   : Daan Leijen (https://github.com/microsoft/mimalloc)\n" /* not enabled for arm yet */
# endif
        "  miniz      : Rich Geldreich etc\n"
        "  pplib      : Paweł Jackowski (with partial code from libraries)\n"
        "  md5        : Peter Deutsch (with partial code from pplib libraries)\n"
        "  sha2       : Aaron D. Gifford (with partial code from pplib libraries)\n"
        "  socket     : Diego Nehab (partial and adapted)\n"
        "  libcerf    : Joachim Wuttke (adapted for MSVC)\n"
        "  decnumber  : Mike Cowlishaw from IBM (one of the number models in MP)\n"
        "  avl        : Richard (adapted a bit to fit in)\n"
        "  hjn        : Raph Levien (derived from TeX's hyphenator, but adapted again)\n"
        "\n"
        "The code base contains more names and references. Some libraries are partially adapted or\n"
        "have been replaced. The MetaPost library has additional functionality, some of which is\n"
        "experimental. The LuaMetaTeX project relates to ConTeXt. This LuaMetaTeX 2+ variant is a\n"
        "lean and mean variant of LuaTeX 1+ but the core typesetting functionality is the same and\n"
        "and has been extended in many aspects.\n"
        "\n"
        "There is a lightweight subsystem for optional libraries but here we also delegate as much\n"
        "as possibe to Lua. A few interfaces are provided bny default, others can be added using a\n"
        "simple foreign interface subsystem. Although this is provided an dconsidered part of the\n"
        "LuaMetaTeX engine it is not something ConTeXt depends (and will) depend on.\n"
        "\n"
        "version   : " luametatex_version_string " | " LMT_TOSTRING(luametatex_development_id) "\n"
        "format id : " LMT_TOSTRING(luametatex_format_fingerprint) "\n"
# ifdef __DATE__
        "date      : " __TIME__ " | " __DATE__ "\n"
# endif
# ifdef LMT_COMPILER_USED
        "compiler  : " LMT_COMPILER_USED "\n"
# endif
    );
    exit(EXIT_SUCCESS);
}

/*tex

    Some properties of the command line (and startup call) are reflected in variables that start
    with \type {self}.

*/

static void enginelib_prepare_cmdline(int zero_offset)
{
    lua_State *L = lmt_lua_state.lua_instance;
    /*tex We keep this reorganized |arg| table, which can start at -3! */
    lua_createtable(L, lmt_environment_state.argc, 0);
    for (lua_Integer i = 0; i < lmt_environment_state.argc; i++) {
        lua_set_string_by_index(L, (int) (i - zero_offset), lmt_environment_state.argv[i]);
    }
    lua_setglobal(L, "arg");
    /* */
    lua_getglobal(L, "os");
    lua_set_string_by_key(L, "selfbin",  lmt_environment_state.argv[0]);
    lua_set_string_by_key(L, "selfpath", lmt_environment_state.ownpath);
    lua_set_string_by_key(L, "selfdir",  lmt_environment_state.ownpath); /* for old times sake */
    lua_set_string_by_key(L, "selfbase", lmt_environment_state.ownbase);
    lua_set_string_by_key(L, "selfname", lmt_environment_state.ownname);
    lua_set_string_by_key(L, "selfcore", lmt_environment_state.owncore);
    lua_createtable(L, lmt_environment_state.argc, 0);
    for (lua_Integer i = 0; i < lmt_environment_state.argc; i++) {
        lua_set_string_by_index(L, (int) i, lmt_environment_state.argv[i]);
    }
    lua_setfield(L, -2, "selfarg");
}

/*tex

    Argument checking is somewhat tricky because it can interfere with the used console (shell). It
    makes sense to combine this with the \LUA\ command line parser code but even that is no real way
    out. For instance, on \MSWINDOWS\ we need to deal with wide characters.

    The code below is as independent from libraries as possible and differs from the the code used
    in other \TEX\ engine.  We issue no warnings and silently recover, because in the end the macro
    package (and its \LUA\ code) can deal with that.

*/

static void enginelib_check_option(char **options, int i)
{
    char *option = options[i];
    char *n = option;
    lmt_environment_state.flag = NULL;
    lmt_environment_state.value = NULL;
    if (*n == '-') {
        n++;
    } else {
        goto NOTHING;
    }
    if (*n == '-') {
        n++;
    } else {
        goto NOTHING;
    }
    if (*n == '\0') {
        return;
    }
    {
        char *v = strchr(n, '=');
        size_t l = (int) (v ? (v - n) : strlen(n));
        lmt_environment_state.flag = lmt_memory_malloc(l + 1);
        if (lmt_environment_state.flag) {
            memcpy(lmt_environment_state.flag, n, l);
            lmt_environment_state.flag[l] = '\0';
            if (v) {
                v++;
                l = (int) strlen(v);
                lmt_environment_state.value = lmt_memory_malloc(l + 1);
                if (lmt_environment_state.value) {
                    memcpy(lmt_environment_state.value, v, l);
                    lmt_environment_state.value[l] = '\0';
                }
            }
        }
        return;
    }
  NOTHING:
    if (lmt_environment_state.name == NULL && i > 0) {
        lmt_environment_state.name = option;
        lmt_environment_state.npos = i;
    }
}

/*tex

    The |lmt| suffix is actually a \CONTEXT\ thing but it permits us to have \LUA\ files for
    \LUAMETATEX\ and \LUATEX\ alongside. The ones for this engine can use a more recent variant of
    \LUA\ and thereby be not compatible. Especially syntax extension complicates this like using
    |<const>| in \LUA 5.4+ or before that bitwise operators in \LUA\ 5.3 (not/never in \LUAJIT).

*/

const char *suffixes[] = { "lmt", "lua", NULL };

static void enginelib_parse_options(void)
{
    /*tex We add 5 chars (separator and suffix) so we reserve 6. */
    char *firstfile = (char*) lmt_memory_malloc(strlen(lmt_environment_state.ownpath) + strlen(lmt_environment_state.owncore) + 6);
    for (int i = 0; suffixes[i]; i++) {
        sprintf(firstfile, "%s/%s.%s", lmt_environment_state.ownpath, lmt_environment_state.owncore, suffixes[i]);
        /* stat */
        if (aux_is_readable(firstfile)) {
            lmt_memory_free(lmt_engine_state.startup_filename);
            lmt_engine_state.startup_filename = firstfile;
            lmt_environment_state.luatex_lua_offset = 0;
            lmt_engine_state.lua_only = 1;
            lmt_engine_state.lua_init = 1;
            return;
        }
    }
    lmt_memory_free(firstfile);
    firstfile = NULL;
    /* */
    for (int i = 1;;) {
        if (i == lmt_environment_state.argc || *lmt_environment_state.argv[i] == '\0') {
            break;
        }
        enginelib_check_option(lmt_environment_state.argv, i);
        i++;
        if (! lmt_environment_state.flag) {
            continue;
        }
        if (strcmp(lmt_environment_state.flag, "luaonly") == 0) {
            lmt_engine_state.lua_only = 1;
            lmt_environment_state.luatex_lua_offset = i;
            lmt_engine_state.lua_init = 1;
        } else if (strcmp(lmt_environment_state.flag, "lua") == 0) {
            if (lmt_environment_state.value) {
                lmt_memory_free(lmt_engine_state.startup_filename);
                lmt_engine_state.startup_filename = lmt_memory_strdup(lmt_environment_state.value);
                lmt_environment_state.luatex_lua_offset = i - 1;
                lmt_engine_state.lua_init = 1;
            }
        } else if (strcmp(lmt_environment_state.flag, "jobname") == 0) {
            if (lmt_environment_state.value) {
                lmt_memory_free(lmt_engine_state.startup_jobname);
                lmt_engine_state.startup_jobname = lmt_memory_strdup(lmt_environment_state.value);
            }
        } else if (strcmp(lmt_environment_state.flag, "fmt") == 0) {
            if (lmt_environment_state.value) {
                lmt_memory_free(lmt_engine_state.dump_name);
                lmt_engine_state.dump_name = lmt_memory_strdup(lmt_environment_state.value);
            }
        } else if (! lmt_engine_state.permit_loadlib && strcmp(lmt_environment_state.flag, "permitloadlib") == 0) {
            lmt_engine_state.permit_loadlib = 1;
        } else if (strcmp(lmt_environment_state.flag, "ini") == 0) {
            lmt_main_state.run_state = initializing_state;
        } else if (strcmp(lmt_environment_state.flag, "help") == 0) {
            enginelib_show_help();
        } else if (strcmp(lmt_environment_state.flag, "version") == 0) {
            enginelib_show_version_info();
        } else if (strcmp(lmt_environment_state.flag, "credits") == 0) {
            enginelib_show_credits();
        }
        lmt_memory_free(lmt_environment_state.flag);
        lmt_environment_state.flag = NULL;
        if (lmt_environment_state.value) {
            lmt_memory_free(lmt_environment_state.value);
            lmt_environment_state.value = NULL;
        }
    }
    /*tex This is an attempt to find |input_name| or |dump_name|. */
    if (lmt_environment_state.argv[lmt_environment_state.npos]) { /* aka name */
        if (lmt_engine_state.lua_only) {
            if (! lmt_engine_state.startup_filename) {
                lmt_engine_state.startup_filename = lmt_memory_strdup(lmt_environment_state.argv[lmt_environment_state.npos]);
                lmt_environment_state.luatex_lua_offset = lmt_environment_state.npos;
            }
        } else if (lmt_environment_state.argv[lmt_environment_state.npos][0] == '&') {
            /*tex This is historic but and might go away. */
            if (! lmt_engine_state.dump_name) {
                lmt_engine_state.dump_name = lmt_memory_strdup(lmt_environment_state.argv[lmt_environment_state.npos] + 1);
            }
        } else if (lmt_environment_state.argv[lmt_environment_state.npos][0] == '*') {
            /*tex This is historic but and might go away. */
            if (! lmt_environment_state.input_name) {
                lmt_environment_state.input_name = lmt_memory_strdup(lmt_environment_state.argv[lmt_environment_state.npos] + 1);
            }
        } else if (lmt_environment_state.argv[lmt_environment_state.npos][0] == '\\') {
            /*tex We have a command but this and might go away. */
        } else {
            /*tex We check for some suffixes first. */
            firstfile = lmt_memory_strdup(lmt_environment_state.argv[lmt_environment_state.npos]);
            for (int i = 0; suffixes[i]; i++) {
                if (strstr(firstfile, suffixes[i]) == firstfile + strlen(firstfile) - 4){
                    if (lmt_engine_state.startup_filename) {
                        lmt_memory_free(firstfile);
                    } else {
                        lmt_engine_state.startup_filename = firstfile;
                        lmt_environment_state.luatex_lua_offset = lmt_environment_state.npos;
                        lmt_engine_state.lua_only = 1;
                        lmt_engine_state.lua_init = 1;
                    }
                    goto DONE;
                }
            }
            if (lmt_environment_state.input_name) {
                lmt_memory_free(firstfile);
            } else {
                lmt_environment_state.input_name = firstfile;
            }
        }
    }
  DONE:
    /*tex Finalize the input filename. */
    if (lmt_environment_state.input_name) {
        /* probably not ok */
        lmt_environment_state.argv[lmt_environment_state.npos] = enginelib_normalize_quotes(lmt_environment_state.input_name, "argument");
    }
}

/*tex

    Being a general purpose typesetting system, a \TEX\ system normally has its own way of dealing
    with language, script, country etc.\ specific properties. It is for that reason that we disable
    locales.

*/

static void enginelib_set_locale(void)
{
    setlocale(LC_ALL, "C");
}

static void enginelib_update_options(void)
{
    int starttime = -1;
    int utc = -1;
    int permitloadlib =  -1;
    if (! lmt_environment_state.input_name) {
        tex_engine_get_config_string("jobname", &lmt_environment_state.input_name);
    }
    if (! lmt_engine_state.dump_name) {
        tex_engine_get_config_string("formatname", &lmt_engine_state.dump_name);
    }
    tex_engine_get_config_number("starttime", &starttime);
    if (starttime >= 0) {
        aux_set_start_time(starttime);
    }
    tex_engine_get_config_boolean("useutctime", &utc);
    if (utc >= 0 && utc <= 1) {
        lmt_engine_state.utc_time = utc;
    }
    tex_engine_get_config_boolean("permitloadlib", &permitloadlib);
    if (permitloadlib >= 0) {
        lmt_engine_state.permit_loadlib = permitloadlib;
    }
}

/*tex

    We have now arrived at the main initializer. What happens after this is determined by what
    callbacks are set. The engine can behave as just a \LUA\ interpreter, startup the \TEX\
    machinery in so called virgin mode, or load a format and carry on from that.

*/

void tex_engine_initialize(int ac, char **av)
{
    /*tex Save to pass along to topenin. */
    lmt_print_state.selector = terminal_selector_code;
    lmt_environment_state.argc = aux_utf8_setargv(&lmt_environment_state.argv, av, ac);
    /* initializations */
    lmt_engine_state.lua_only = 0;
    lmt_engine_state.lua_init = 0;
    lmt_engine_state.startup_filename = NULL;
    lmt_engine_state.startup_jobname = NULL;
    lmt_engine_state.engine_name = luametatex_name_lowercase;
    lmt_engine_state.dump_name = NULL;
    lmt_engine_state.luatex_banner = lmt_memory_strdup(lmt_version_state.banner);
    /* preparations */
    lmt_environment_state.ownpath = aux_utf8_getownpath(lmt_environment_state.argv[0]);
    enginelib_splitnames();
    aux_set_run_time();
    /*tex
        Some options must be initialized before options are parsed. We don't need that many as we
        can delegate to \LUA.
    */
    /*tex Parse the commandline. */
    enginelib_parse_options();
    /*tex Forget about locales. */
    enginelib_set_locale();
    /*tex Initialize the \LUA\ instance and keys. */
    lmt_initialize();
    /*tex This can be redone later. */
    lmt_initialize_functions(0);
    lmt_initialize_properties(0);
    /*tex For word handlers. */
    lmt_initialize_languages();
    /*tex Here start the key definitions (will become functions). */
    lmt_initialize_interface();
    lmt_nodelib_initialize();
    lmt_tokenlib_initialize();
    lmt_fontlib_initialize();
    /*tex Collect arguments. */
    enginelib_prepare_cmdline(lmt_environment_state.luatex_lua_offset);
    if (lmt_engine_state.startup_filename && ! aux_is_readable(lmt_engine_state.startup_filename)) {
        lmt_memory_free(lmt_engine_state.startup_filename);
        lmt_engine_state.startup_filename = NULL;
    }
    /*tex
        Now run the file (in \LUATEX\ there is a special \TEX\ table pushed with limited
        functionality (initialize, run, finish) but the normal tex helpers are not unhidden so
        basically one has no \TEX. We no longer have that.
    */
    if (lmt_engine_state.startup_filename) {
        lua_State *L = lmt_lua_state.lua_instance;
        if (lmt_engine_state.lua_only) {
            if (luaL_loadfile(L, lmt_engine_state.startup_filename)) {
                tex_emergency_message("lua error", "startup file: %s", lmt_error_string(L, -1));
                tex_emergency_exit();
            } else if (lua_pcall(L, 0, 0, 0)) {
                tex_emergency_message("lua error", "function call: %s", lmt_error_string(L, -1));
                lmt_traceback(L);
                tex_emergency_exit();
            } else {
                /*tex We're okay. */
                exit(lmt_error_state.default_exit_code);
            }
        } else {
            /*tex a normal tex run */
            if (luaL_loadfile(L, lmt_engine_state.startup_filename)) {
                tex_emergency_message("lua error", "startup file: %s", lmt_error_string(L, -1));
                tex_emergency_exit();
            } else if (lua_pcall(L, 0, 0, 0)) {
                tex_emergency_message("lua error", "function call: %s", lmt_error_string(L, -1));
                lmt_traceback(L);
                tex_emergency_exit();
            }
            enginelib_update_options();
            tex_check_fmt_name();
        }
    } else if (lmt_engine_state.lua_init) {
        tex_emergency_message("startup error", "no valid startup file given, quitting");
        tex_emergency_exit();
    } else {
        tex_check_fmt_name();
    }
}

/*tex

    For practical and historical reasons some of the initalization and checking is split. The
    mainbody routine call out to these functions. The timing is sort of tricky: we can use a start
    up script, that sets some configuration parameters, and for sure some callbacks, and these, in
    turn, are then responsible for follow up actions like telling where to find the format file
    (when a dump is loaded) or startup file (when we're in virgin mode). When we are in neither of
    these modes the engine is just a \LUA\ interpreter which means that only a subset of libraries
    is initialized.

*/

static void tex_engine_get_config_numbers(const char *name, int *minimum, int *maximum, int *size, int *step)
{
    lua_State *L = lmt_lua_state.lua_instance;
    if (L && size) {
        int stacktop = lua_gettop(L);
        if (lua_getglobal(L, "texconfig") == LUA_TTABLE) {
            switch (lua_getfield(L, -1, name)) {
                case LUA_TNUMBER:
                    if (size) {
                        *size = (int) lmt_roundnumber(L, -1);
                    }
                    break;
                case LUA_TTABLE:
                    if (size && lua_getfield(L, -1, "size")) {
                        *size = (int) lmt_roundnumber(L, -1);
                    }
                    lua_pop(L, 1);
                    if (size && lua_getfield(L, -1, "plus")) {
                        *size += (int) lmt_roundnumber(L, -1);
                    }
                    lua_pop(L, 1);
                    if (step && lua_getfield(L, -1, "step")) {
                        int stp = (int) lmt_roundnumber(L, -1);
                        if (stp > *step) {
                            *step = stp;
                        }
                    }
                    break;
            }
            if (minimum && *size < *minimum) {
                *size = *minimum;
            } else if (maximum && *size > *maximum) {
                *size = *maximum;
            }
        }
        lua_settop(L, stacktop);
    }
}

void tex_engine_set_memory_data(const char *name, memory_data *data)
{
    tex_engine_get_config_numbers(name, &data->minimum, &data->maximum, &data->size, &data->step);
}

void tex_engine_set_limits_data(const char *name, limits_data *data)
{
    tex_engine_get_config_numbers(name, &data->minimum, &data->maximum, &data->size, NULL);
}

void tex_engine_get_config_boolean(const char *name, int *target)
{
    lua_State *L = lmt_lua_state.lua_instance;
    if (L) {
        int stacktop = lua_gettop(L);
        if (lua_getglobal(L, "texconfig") == LUA_TTABLE) {
            switch (lua_getfield(L, -1, name)) {
                case LUA_TBOOLEAN:
                    *target = lua_toboolean(L, -1);
                    break;
                case LUA_TNUMBER:
                    *target = (lua_tointeger(L, -1) == 0 ? 0 : 1);
                    break;
            }
        }
        lua_settop(L, stacktop);
    }
}

void tex_engine_get_config_number(const char *name, int *target)
{
    tex_engine_get_config_numbers(name, NULL, NULL, target, NULL);
}

void tex_engine_get_config_string(const char *name, char **target)
{
    lua_State *L = lmt_lua_state.lua_instance;
    if (L) {
        int stacktop = lua_gettop(L);
        if (lua_getglobal(L, "texconfig") == LUA_TTABLE) {
            if (lua_getfield(L, -1, name) == LUA_TSTRING) {
                *target = lmt_memory_strdup(lua_tostring(L, -1));
            }
        }
        lua_settop(L, stacktop);
    }
}

int tex_engine_run_config_function(const char *name)
{
    lua_State *L = lmt_lua_state.lua_instance;
    if (L) {
        if (lua_getglobal(L, "texconfig") == LUA_TTABLE) {
            if (lua_getfield(L, -1, name) == LUA_TFUNCTION) {
                if (! lua_pcall(L, 0, 0, 0)) {
                    return 1;
                } else {
                    /*tex
                        We can't be more precise here as it's called before \TEX\ initialization
                        happens.
                    */
                    tex_emergency_message("lua", "this went wrong: %s\n", lmt_error_string(L, -1));
                    tex_emergency_exit();
                }
            }
        }
    }
    return 0;
}

void tex_engine_check_configuration(void)
{
    tex_engine_run_config_function("init");
}

void lmt_make_table(
    lua_State     *L,
    const char    *tab,
    const char    *mttab,
    lua_CFunction  getfunc,
    lua_CFunction  setfunc
)
{
    lua_pushstring(L, tab);          /*tex |[{<tex>},"dimen"]| */
    lua_newtable(L);                 /*tex |[{<tex>},"dimen",{}]| */
    lua_settable(L, -3);             /*tex |[{<tex>}]| */
    lua_pushstring(L, tab);          /*tex |[{<tex>},"dimen"]| */
    lua_gettable(L, -2);             /*tex |[{<tex>},{<dimen>}]| */
    luaL_newmetatable(L, mttab);     /*tex |[{<tex>},{<dimen>},{<dimen_m>}]| */
    lua_pushstring(L, "__index");    /*tex |[{<tex>},{<dimen>},{<dimen_m>},"__index"]| */
    lua_pushcfunction(L, getfunc);   /*tex |[{<tex>},{<dimen>},{<dimen_m>},"__index","getdimen"]| */
    lua_settable(L, -3);             /*tex |[{<tex>},{<dimen>},{<dimen_m>}]| */
    lua_pushstring(L, "__newindex"); /*tex |[{<tex>},{<dimen>},{<dimen_m>},"__newindex"]| */
    lua_pushcfunction(L, setfunc);   /*tex |[{<tex>},{<dimen>},{<dimen_m>},"__newindex","setdimen"]| */
    lua_settable(L, -3);             /*tex |[{<tex>},{<dimen>},{<dimen_m>}]| */
    lua_setmetatable(L, -2);         /*tex |[{<tex>},{<dimen>}]| : assign the metatable */
    lua_pop(L, 1);                   /*tex |[{<tex>}]| : clean the stack */
}

static void *enginelib_aux_luaalloc(
    void   *ud,    /*tex Not used, but passed by \LUA. */
    void   *ptr,   /*tex The old pointer. */
    size_t  osize, /*tex The old size. */
    size_t  nsize  /*tex The new size. */
)
{
    (void) ud;
    lmt_lua_state.used_bytes += (int) (nsize - osize);
    if (lmt_lua_state.used_bytes > lmt_lua_state.used_bytes_max) {
        lmt_lua_state.used_bytes_max = lmt_lua_state.used_bytes;
    }
    /*tex Quite some reallocs happen in \LUA. */
    if (nsize == 0) {
        /* printf("free %i\n",(int) osize); */
        lmt_memory_free(ptr);
        return NULL;
    } else if (osize == 0) {
        /* printf("malloc %i\n",(int) nsize); */
        return lmt_memory_malloc(nsize);
    } else {
        /* printf("realloc %i -> %i\n",(int)osize,(int)nsize); */
        return lmt_memory_realloc(ptr, nsize);
    }
}

static int enginelib_aux_luapanic(lua_State *L)
{
    (void) L;
    tex_emergency_message("lua", "panic: unprotected error in call to Lua API (%s)\n", lmt_error_string(L, -1));
    return tex_emergency_exit();
}

static const luaL_Reg lmt_libs_lua_function_list[] = {
    { "_G",        luaopen_base      },
    { "package",   luaopen_package   },
    { "table",     luaopen_table     },
    { "io",        luaopen_io        },
    { "os",        luaopen_os        },
    { "string",    luaopen_string    },
    { "math",      luaopen_math      },
    { "debug",     luaopen_debug     },
    { "lpeg",      luaopen_lpeg      },
    { "utf8",      luaopen_utf8      },
    { "coroutine", luaopen_coroutine },
    { NULL,        NULL              },
};

static const luaL_Reg lmt_libs_extra_function_list[] = {
    { "md5",      luaopen_md5      },
    { "sha2",     luaopen_sha2     },
    { "aes",      luaopen_aes      },
    { "basexx",   luaopen_basexx   },
    { "lfs",      luaopen_filelib  }, /* for practical reasons we keep this namespace */
    { "fio",      luaopen_fio      },
    { "sio",      luaopen_sio      },
    { "sparse",   luaopen_sparse   },
    { "xzip",     luaopen_xzip     },
    { "xmath",    luaopen_xmath    },
    { "xcomplex", luaopen_xcomplex },
    { "xdecimal", luaopen_xdecimal },
    { NULL,       NULL             },
};

static const luaL_Reg lmt_libs_socket_function_list[] = {
    { "socket",   luaopen_socket_core },
    { "mime",     luaopen_mime_core   },
    { NULL,       NULL                },
};

static const luaL_Reg lmt_libs_more_function_list[] = {
    { "lua",      luaopen_lua    },
    { "luac",     luaopen_luac   },
    { "status",   luaopen_status },
    { "texio",    luaopen_texio  },
    { NULL,       NULL           },
};

static const luaL_Reg lmt_libs_tex_function_list[] = {
    { "tex",      luaopen_tex      },
    { "token",    luaopen_token    },
    { "node",     luaopen_node     },
    { "callback", luaopen_callback },
    { "font",     luaopen_font     },
    { "language", luaopen_language },
    { NULL,       NULL             },
};

static const luaL_Reg lmt_libs_mp_function_list[] = {
    { "mplib", luaopen_mplib },
    { NULL,    NULL          },
};

static const luaL_Reg lmt_libs_pdf_function_list[] = {
    { "pdfe",      luaopen_pdfe      },
    { "pdfdecode", luaopen_pdfdecode },
    { "pngdecode", luaopen_pngdecode },
    { NULL,        NULL              },
};

/*tex

    So, we have different library initialization lists for the the two \TEX\ modes (ini and normal)
    and \LUA\ mode (interpeter). It's not pretty yet but it might become better over time.

 */

static void enginelib_luaopen_liblist(lua_State *L, const luaL_Reg *lib)
{
    for (; lib->func; lib++) {
        luaL_requiref(L, lib->name, lib->func, 1);
        lua_setglobal(L, lib->name);
    }
}

/*tex

    In order to overcome (expected) debates about security we disable loading libraries unless
    explicitly enabled (as in \LUATEX). An exception are the optional libraries, but as these
    interfaces are rather bound to the cannonical \LUAMETATEX\ source code we can control these
    from \CONTEXT\ of needed because before users can run code, we can block support of these
    libraries. On the other hand, we have no reason to distrust the few that can (optionally) be
    used (they also cannot clash with different \LUA\ versions).

    \starttyping
    package.loadlib = nil|
    package.searchers[4] = nil
    package.searchers[3] = nil
    \stoptyping

*/

static int loadlib_warning(lua_State *L)
{
    (void) L;
    tex_normal_error("lua loadlib", "you can only load external libraries when --permitloadlib is given");
    return 0;
}

static void enginelib_disable_loadlib(lua_State *L)
{
    int top = lua_gettop(L);
    lua_getglobal(L, "package");
    lua_pushliteral(L, "loadlib");
    lua_pushcfunction(L, &loadlib_warning);
    lua_rawset(L, -3);
    lua_pushliteral(L, "searchers");
    lua_rawget(L, -2);
    lua_pushnil(L);
    lua_rawseti(L, -2, 4);
    lua_pushnil(L);
    lua_rawseti(L, -2, 3);
    lua_settop(L, top);
}

void lmt_initialize(void)
{
    lua_State *L = lua_newstate(enginelib_aux_luaalloc, NULL);
    if (L) {
        /*tex By default we use the generational garbage collector. */
        lua_gc(L, LUA_GCGEN, 0, 0);
        /* */
        lmt_lua_state.bytecode_max = -1;
        lmt_lua_state.bytecode_bytes = 0;
        lmt_lua_state.lua_instance = L;
        /* */
        lua_atpanic(L, &enginelib_aux_luapanic);
        /*tex Initialize the internalized strings. */
        lmt_initialize_shared_keys(L);
        lmt_initialize_metapost_keys(L);
        /*tex This initializes all the 'simple' libraries: */
        enginelib_luaopen_liblist(L, lmt_libs_lua_function_list);
        /*tex This initializes all the 'extra' libraries: */
        enginelib_luaopen_liblist(L, lmt_libs_extra_function_list);
        /*tex These are special: we extend them. */
        luaextend_os(L);
        luaextend_io(L);
        luaextend_string(L);
        /*tex Loading the socket library is a bit odd (old stuff). */
        enginelib_luaopen_liblist(L, lmt_libs_socket_function_list);
        /*tex This initializes the 'tex' related libraries that have some luaonly functionality */
        enginelib_luaopen_liblist(L, lmt_libs_more_function_list);
        /*tex This initializes the 'tex' related libraries. */
        if (! lmt_engine_state.lua_only) {
            enginelib_luaopen_liblist(L, lmt_libs_tex_function_list);
        }
        if (! lmt_engine_state.permit_loadlib) {
            enginelib_disable_loadlib(L);
        }
        /*tex Optional stuff. */
        luaopen_optional(L);
        /*tex This initializes the 'metapost' related libraries. */
        enginelib_luaopen_liblist(L, lmt_libs_mp_function_list);
        /*tex This initializes the 'pdf' related libraries. */
        enginelib_luaopen_liblist(L, lmt_libs_pdf_function_list);
        /*tex This one can become optional! */
        luaextend_xcomplex(L);
        /*tex We're nearly done! In this table we're going to put some info: */
        lua_createtable(L, 0, 0);
        lua_setglobal(L, "texconfig");
        /* Maybe this will embed the checkstack function that some libs need. */
     /* lua_checkstack(L, 1); */
    } else {
        tex_emergency_message("system", "the Lua state can't be created");
        tex_emergency_exit();
    }
}

int lmt_traceback(lua_State *L)
{
    const char *msg = lua_tostring(L, 1);
    luaL_traceback(L, L, msg ? msg : "<no message>", 1);
    return 1;
}

void lmt_error(
    lua_State  *L,
    const char *where,   /*tex The message has two parts. */
    int         detail,  /*tex A function slot or callback index or ... */
    int         is_fatal /*tex We quit if this is the case */
)
{
    char* err = NULL;
    if (lua_type(L, -1) == LUA_TSTRING) {
        const char *luaerr = lua_tostring(L, -1);
        size_t len = strlen(luaerr) + strlen(where) + 32; /*tex Add some slack. */
        err = (char *) lmt_memory_malloc((unsigned) len);
        if (err) {
            if (detail >= 0) {
                snprintf(err, len, "%s [%i]: %s", where, detail, luaerr);
            } else {
                snprintf(err, len, "%s: %s", where, luaerr);
            }
            if (lmt_error_state.last_lua_error) {
                lmt_memory_free(lmt_error_state.last_lua_error);
            }
        }
        lmt_error_state.last_lua_error = err;
    }
    if (is_fatal > 0) {
        /*
            Normally a memory error from lua. The pool may overflow during the |maketexlstring()|,
            but we are crashing anyway so we may as well abort on the pool size. It is probably
            too risky to show the error context now but we can imagine some more granularity.
        */
        tex_normal_error("lua", err ? err : where);
        /*tex
            This should never be reached, so there is no need to close, so let's make sure of
            that!
        */
        /* lua_close(L); */
    }
    else {
        tex_normal_warning("lua", err ? err : where);
    }
}

/*tex

    As with other dump related actions, this module provides its relevant properties. A dump is
    just that: variables written to a stream, and an undump reads instead. Some basic checking
    happens in these functions.

*/

void lmt_dump_engine_info(dumpstream f)
{
    /*tex We align |engine_name| to 4 bytes with one or more trailing |NUL|. */
    int x = (int) strlen(lmt_engine_state.engine_name);
    if (x > 0) {
        char *format_engine = lmt_memory_malloc((size_t) x + 5);
        if (format_engine) {
            memcpy(format_engine, lmt_engine_state.engine_name, (size_t) x + 1);
            for (int k = x; k <= x + 3; k++) {
                format_engine[k] = 0;
            }
            x = x + 4 - (x % 4);
            dump_int(f, x);
            dump_things(f, format_engine[0], x);
            lmt_memory_free(format_engine);
            return;
        }
    }
    tex_normal_error("system","dumping engine info failed");
}

void lmt_undump_engine_info(dumpstream f)
{
    int x;
    undump_int(f, x);
    if ((x > 1) && (x < 256)) {
        char *format_engine = lmt_memory_malloc((size_t) x);
        if (format_engine) {
            undump_things(f, format_engine[0], x);
            format_engine[x - 1] = 0;
            if (strcmp(lmt_engine_state.engine_name, format_engine)) {
                lmt_memory_free(format_engine);
                goto BAD;
            } else {
                lmt_memory_free(format_engine);
                return;
            }
        }
    }
  BAD:
    tex_fatal_undump_error("engine");
}

const char *lmt_error_string(lua_State* L, int index)
{
    const char *s = lua_tostring(L, index);
    return s ? s : "unknown error";
}
