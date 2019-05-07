/*
    See license.txt in the root of this project.
*/

# include "luatex-common.h"

engine_state_info engine_state = { 0, 0, NULL, NULL, NULL, NULL, NULL, 0 };

typedef struct environment_state_info {
    char **argv;
    int argc;
    int npos;
    char *flag;
    char *value;
    char *name;
    char *ownpath;
    char *ownbase;
    char *ownname;
    char *owncore;
    char *input_name;
    int luatex_lua_offset;
} environment_state_info ;

static environment_state_info environment_state = { NULL, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0 };

/*tex
    Test for readability.
*/

# define is_readable(a) \
       (stat(a,&finfo) == 0) \
    && S_ISREG(finfo.st_mode) \
    && ((f=fopen(a,"r")) != NULL) \
    && !fclose(f)

/*tex todo: make helpers in loslibext which has similar code */

static void splitnames(void)
{
    size_t i;
    char *p  = strdup(environment_state.ownpath); /*tex We need to make copies! */
    /*
    printf("ownpath = %s\n",environment_state.ownpath);
    printf("ownbase = %s\n",environment_state.ownbase);
    printf("ownname = %s\n",environment_state.ownname);
    printf("owncore = %s\n",environment_state.owncore);
    */
    environment_state.ownbase = basename(strdup(p));
    environment_state.ownname = basename(strdup(p));
    environment_state.ownpath = dirname(strdup(p)); /* We could use p and not free later, but this is cleaner. */
    /* */
    for (i=0;i<strlen(environment_state.ownname);i++) {
        if (environment_state.ownname[i] == '.') {
            environment_state.ownname[i] = '\0';
            break ;
        }
    }
    environment_state.owncore = strdup(environment_state.ownname);
    /*
    printf("ownpath = %s\n",environment_state.ownpath);
    printf("ownbase = %s\n",environment_state.ownbase);
    printf("ownname = %s\n",environment_state.ownname);
    printf("owncore = %s\n",environment_state.owncore);
    */
    free(p);
}

# ifdef _WIN32

static void getnames(void)
{
    size_t i;
    char buffer[MAX_PATH];
    GetModuleFileName(NULL,buffer,sizeof(buffer));
    environment_state.ownpath = strdup(buffer);
    for (i=0;i<strlen(environment_state.ownpath);i++) {
        if (environment_state.ownpath[i] == '\\') {
            environment_state.ownpath[i] = '/';
        }
    }
}

# else /* taken from oslibext */

static void getnames(void)
{
    const char *file = environment_state.argv[0];
    if (strchr(file, '/')) {
        environment_state.ownpath = strdup(file);
    } else {
        const char *esp;
        size_t prefixlen = 0;
        size_t totallen = 0;
        size_t filelen = strlen(file);
        char *path = NULL;
        char *searchpath = strdup(getenv("PATH"));
        const char *index = searchpath;
        if (index) {
            do {
                esp = strchr(index, ':');
                if (esp) {
                    prefixlen = (size_t) (esp - index);
                } else {
                    prefixlen = strlen(index);
                }
                if (prefixlen == 0 || index[prefixlen - 1] == '/') {
                    totallen = prefixlen + filelen;
# ifdef PATH_MAX
                    if (totallen >= PATH_MAX) {
                        continue;
                    }
# endif
                    path = malloc(totallen + 1);
                    memcpy(path, index, prefixlen);
                    memcpy(path + prefixlen, file, filelen);
                } else {
                    totallen = prefixlen + filelen + 1;
# ifdef PATH_MAX
                    if (totallen >= PATH_MAX) {
                        continue;
                    }
# endif
                    path = malloc(totallen + 1);
                    memcpy(path, index, prefixlen);
                    path[prefixlen] = '/';
                    memcpy(path + prefixlen + 1, file, filelen);
                }
                path[totallen] = '\0';
                if (access(path, X_OK) >= 0) {
                    environment_state.ownpath = path;
                    break;
                }
                free(path);
                path = NULL;
                index = esp + 1;
            } while (esp);
        }
        free(searchpath);
    }
    if (environment_state.ownpath == NULL) {
        environment_state.ownpath = strdup(".");
    }
}

# endif

/*tex internalized strings: see luatex-api.h */

set_make_keys;

/*tex

    This is supposed to open the terminal for input, but what we really do is
    copy command line arguments into \TEX's buffer, so it can handle them. If
    nothing is available, or we've been called already (and hence, |argc==0|), we
    return with |last=first|.

*/

void command_line_to_input(unsigned char *buffer, int first)
{
    if (environment_state.npos < environment_state.argc) { /* optind < environment_state.argc */
        /*tex We have command line arguments. */
        int k = first;
        int i;
        for (i = environment_state.npos; i < environment_state.argc; i++) {
            char *ptr = &(environment_state.argv[i][0]);
            /*tex We cannot use strcat, because we have multibyte UTF-8 input. */
            while (*ptr) {
                buffer[k++] = (unsigned char) * (ptr++);
            }
            buffer[k++] = ' ';
        }
        /*tex Don't do this again. */
        environment_state.argc = 0;
        buffer[k] = 0;
    }
}

/*tex

    Normalize quoting of filename, that is, only quote if there is a space, and
    always use the quote-name-quote style.

*/

static char* normalize_quotes(const char* name, const char* mesg)
{
    int quoted = 0;
    int must_quote = (strchr(name, ' ') != NULL);
    /* Leave room for quotes and NUL. */
    char* ret = (char*) malloc((unsigned) strlen(name) + 3);
    char* p = ret;
    const char* q;
    if (must_quote)
        *p++ = '"';
    for (q = name; *q; q++) {
        if (*q == '"')
            quoted = !quoted;
        else
            *p++ = *q;
    }
    if (must_quote)
        *p++ = '"';
    *p = '\0';
    if (quoted) {
        fprintf(stderr, "unbalanced quotes in %s %s\n", mesg, name);
        exit(EXIT_FAILURE);
    }
    return ret;
}

/*

    We support a minimum set of options. More can be supported by supplying an initialization
    script by setting values in the |texcinfig| table. At some point we might provide some
    default initialzation script but that's for later. In fact, a bug in \LUATEX\ < 1.10 made
    some of the command lin eoptions get lost anyway due to setting their values before checking
    the config table (probably introduced at some time). As no one noticed that anyway, removing
    these from the commandline is okay.

    On the todo list is a simple option scanned as we don't need that much.

*/

static void show_help(void)
{
    puts(
        "Usage: " my_name " --lua=FILE [OPTION]... [TEXNAME[.tex]] [COMMANDS]\n"
        "   or: " my_name " --lua=FILE [OPTION]... \\FIRST-LINE\n"
        "   or: " my_name " --lua=FILE [OPTION]... &FMT ARGS\n"
        "\n"
        "Run " My_Name " on TEXNAME, usually creating TEXNAME.pdf. Any remaining COMMANDS"
        "are processed as luatex input, after TEXNAME is read.\n"
        "\n"
        "Alternatively, if the first non-option argument begins with a backslash,\n"
        my_name " interprets all non-option arguments as an input line.\n"
        "\n"
        "Alternatively, if the first non-option argument begins with a &, the next word\n"
        "is taken as the FMT to read, overriding all else. Any remaining arguments are\n"
        "processed as above.\n"
        "\n"
        "If no arguments or options are specified, prompt for input.\n"
        "\n"
        "The following regular options are understood:\n"
        "\n"
        "  --credits                     display credits and exit\n"
        "  --fmt=FORMAT                  load the format file FORMAT\n"
        "  --help                        display help and exit\n"
        "  --ini                         be ini" my_name ", for dumping formats\n"
        "  --jobname=STRING              set the job name to STRING\n"
        "  --lua=FILE                    load and execute a lua initialization script\n"
        "  --version                     display version and exit\n"
        "\n"
        "Alternate behaviour models can be obtained by special switches\n"
        "\n"
        "  --luaonly                      run a lua file, then exit\n"
        "\n"
        "See the reference manual for more information about the startup process.\n"
        "\n"
        "Email bug reports to " BUG_ADDRESS ".\n"
    );
    exit(EXIT_SUCCESS);
}

# define STR(tok) STR2(tok)
# define STR2(tok) #tok

static void show_version_info(void)
{
    print_version_banner();
    puts(
        "\n"
        "\n"
        "Execute '" my_name " --credits' for credits and version details.\n"
        "\n"
        "There is NO warranty. Redistribution of this software is covered by the terms\n"
        "of the GNU General Public License, version 2 or (at your option) any later\n"
        "version. For more information about these matters, see the file named COPYING\n"
        "and the LuaTeX source.\n"
        "\n"
        "Functionality : level " STR(luatex_development_id) "\n"
        "Support       : " SUPPORT_ADDRESS "\n"
        "Copyright     : The LuaTeX Team (2005-2019+)\n"
    );
    exit(EXIT_SUCCESS);
}

static void show_credits(void)
{
    print_version_banner();
    puts(
        "\n"
        "\n"
        "The LuaTeX team is Hans Hagen, Hartmut Henkel, Taco Hoekwater, Luigi Scarso.\n"
        "\n"
        My_Name " builds upon the code from:\n"
        "\n"
        "  tex        : Donald Knuth\n"
        "  etex       : Peter Breitenlohner, Phil Taylor and friends\n"
        "\n"
        "The expansion and protrusion code is derived from:\n"
        "\n"
        "  pdftex     : Han The Thanh and friends\n"
        "\n"
        "Much of the bidirectional text flow model is taken from:\n"
        "\n"
        "  omega      : John Plaice and Yannis Haralambous\n"
        "  aleph      : Giuseppe Bilotta\n"
        "\n"
        "Graphic support is provided by:\n"
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
        "  ffi        : James R. McKaskill\n"
        "  libdeflate : Eric Biggers (experimental)\n"
        "  libcerf    : Joachim Wuttke (experimental)\n"
        "  pplib      : Paweł Jackowski (with partial code from libraries)\n"
        "  md5        : Peter Deutsch (with partial code from pplib libraries)\n"
        "  sha2       : Aaron D. Gifford (with partial code from pplib libraries)\n"
        "  socket     : Diego Nehab (partial and adapted)\n"
        "  zlib       : Jean-loup Gailly and Mark Adler Tiago Dionizio\n"
        "\n"
        "The code base contains more names and references. The zlib library might be replaced\n"
        "once libdeflate provides support for streams. Some libraries are partially adapted.\n"
        "We use an adapted version of the lfs from the Kepler Project. The libcerf library is\n"
        "included as part of experiments with MetaPost."
        "\n"
        "This program is the result of the LuaMetaTeX project, which relates to ConTeXt. The\n"
        "LuaTeX 2+ variant is a lean and mean variant of LuaTeX 1+ but the core typesetting\n"
        "functionality is the same. This version has development identifier " STR(luatex_development_id) ".\n"
    );
    exit(EXIT_SUCCESS);
}

# undef STR2
# undef STR

# define lua_set_string_by_key(L,a,b) \
    lua_pushstring(L, b); \
    lua_setfield(L, -2, a);

# define lua_set_string_by_index(L,a,b) \
    lua_pushstring(L, b); \
    lua_rawseti(L, -2, a);

static void prepare_cmdline(lua_State * L, int zero_offset)
{
    int i;
    luaL_checkstack(L, environment_state.argc + 3, "too many arguments to script");
    /*tex We keep this reorganized |arg| table, which can start at -3! */
    lua_createtable(L, environment_state.argc, 0);
    for (i = 0; i < environment_state.argc; i++) {
        lua_set_string_by_index(L,(i - zero_offset),environment_state.argv[i]);
    }
    lua_setglobal(L, "arg");
    /* */
    lua_getglobal(L, "os");
    lua_set_string_by_key(L,"selfbin", environment_state.argv[0]);
    lua_set_string_by_key(L,"selfpath",environment_state.ownpath);
    lua_set_string_by_key(L,"selfdir", environment_state.ownpath); /* for old times sake */
    lua_set_string_by_key(L,"selfbase",environment_state.ownbase);
    lua_set_string_by_key(L,"selfname",environment_state.ownname);
    lua_set_string_by_key(L,"selfcore",environment_state.owncore);
    lua_createtable(L, environment_state.argc, 0);
    for (i = 0; i < environment_state.argc; i++) {
        lua_set_string_by_index(L,i,environment_state.argv[i]);
    }
    lua_setfield(L, -2, "selfarg");
    return;
}

/*tex

Test whether getopt found an option \quote {A}. Assumes the option index is in
the variable |option_index|, and the option table in a variable |long_options|.

Todo: merge this code with the lua arg collector (no need for getopt_long_only
then). So, as we have not that many arguments we handle them in the main loop.

*/

/*tex

    We issue no warnings, we silently recover, as we don't want clutter. Beware,
    |startup_jobname| is really special in the sense that it must be a simple
    filename with no suffix and no path!

*/

static void check_option(char **options, int i)
{
    char *option = options[i];
    char *n = option;
    char *v = NULL;
    int l ;
    environment_state.flag = NULL;
    environment_state.value = NULL;
    if (*n == '-') {
        n++;
    } else {
        if (environment_state.name == NULL && i > 0) {
            environment_state.name = option;
            environment_state.npos = i;
        }
        return;
    }
    if (*n == '-') {
        n++;
    } else {
        if (environment_state.name == NULL && i > 0) {
            environment_state.name = option;
            environment_state.npos = i;
        }
        return;
    }
    if (*n == '\0') {
        return;
    }
    v = strchr(n,'=');
    if (v != NULL) {
        l = v - n;
    } else {
        l = strlen(n);
    }
    environment_state.flag = malloc(l + 1);
    memcpy(environment_state.flag,n,l);
    environment_state.flag[l] = '\0';
    if (v != NULL) {
        v++;
        l = (int) strlen(v);
        environment_state.value = malloc(l + 1);
        memcpy(environment_state.value,v,l);
        environment_state.value[l] = '\0';
    }
}

static void parse_options(void)
{
    int i = 1;
    struct stat finfo;
    FILE *f;
    char *firstfile = (char*) malloc(strlen(environment_state.ownpath) + strlen(environment_state.owncore) + 6);
    sprintf(firstfile,"%s/%s.lua",environment_state.ownpath,environment_state.owncore);
    /* stat */
    if (is_readable(firstfile)) {
        free(engine_state.startup_filename);
        engine_state.startup_filename = firstfile;
        environment_state.luatex_lua_offset = 0;
        engine_state.lua_only = 1;
        engine_state.lua_init = 1;
        return;
    } else {
        free(firstfile);
        firstfile = NULL;
    }
    /* */
    for (;;) {
        if (i == environment_state.argc || *environment_state.argv[i] == '\0') {
            break;
        }
        check_option(environment_state.argv,i);
        i++;
        if (environment_state.flag == NULL) {
            continue;
        }
        if (strcmp(environment_state.flag,"luaonly") == 0) {
            engine_state.lua_only = 1;
            environment_state.luatex_lua_offset = i;
            engine_state.lua_init = 1;
        } else if (strcmp(environment_state.flag,"lua") == 0) {
            if (environment_state.value != NULL) {
                free(engine_state.startup_filename);
                engine_state.startup_filename = strdup(environment_state.value); // normalize_quotes(environment_state.value,"lua");
                environment_state.luatex_lua_offset = i - 1;
                engine_state.lua_init = 1;
            }
        } else if (strcmp(environment_state.flag,"jobname") == 0) {
            if (environment_state.value != NULL) {
                free(engine_state.startup_jobname);
                engine_state.startup_jobname = strdup(environment_state.value); // normalize_quotes(environment_state.value,"jobname");
            }
        } else if (strcmp(environment_state.flag,"fmt") == 0) {
            if (environment_state.value != NULL) {
                free(engine_state.dump_name);
                engine_state.dump_name = strdup(environment_state.value);
            }
        } else if (strcmp(environment_state.flag,"ini") == 0) {
            main_state.ini_version = 1;
        } else if (strcmp(environment_state.flag,"help") == 0) {
            show_help();
        } else if (strcmp(environment_state.flag,"version") == 0) {
            show_version_info();
        } else if (strcmp(environment_state.flag,"credits") == 0) {
            show_credits();
        }
        free(environment_state.flag);
        environment_state.flag = NULL;
        if (environment_state.value != NULL) {
            free(environment_state.value);
            environment_state.value = NULL;
        }
    }
    /*tex This is an attempt to find |input_name| or |dump_name|. */
    if (environment_state.npos == 0) {
        /* no filename found */
        environment_state.npos = environment_state.argc ;
    }
    if (environment_state.argv[environment_state.npos]) { /* aka name */
        if (engine_state.lua_only) {
            if (engine_state.startup_filename == NULL) {
                engine_state.startup_filename = strdup(environment_state.argv[environment_state.npos]);
                environment_state.luatex_lua_offset = environment_state.npos;
            }
        } else if (environment_state.argv[environment_state.npos][0] == '&') {
            /*tex This is historic but and might go away. */
            if (engine_state.dump_name == NULL) {
                engine_state.dump_name = strdup(environment_state.argv[environment_state.npos] + 1);
            }
        } else if (environment_state.argv[environment_state.npos][0] == '*') {
            /*tex This is historic but and might go away. */
            if (environment_state.input_name == NULL) {
                environment_state.input_name = strdup(environment_state.argv[environment_state.npos] + 1);
            }
        } else if (environment_state.argv[environment_state.npos][0] == '\\') {
            /*tex We have a command but this and might go away. */
        } else {
            firstfile = strdup(environment_state.argv[environment_state.npos]);
            if ((strstr(firstfile, ".lua") == firstfile + strlen(firstfile) - 4)
             || (strstr(firstfile, ".luc") == firstfile + strlen(firstfile) - 4)) {
                if (engine_state.startup_filename == NULL) {
                    engine_state.startup_filename = firstfile;
                    environment_state.luatex_lua_offset = environment_state.npos;
                    engine_state.lua_only = 1;
                    engine_state.lua_init = 1;
                } else {
                    free(firstfile);
                }
            } else {
                if (environment_state.input_name == NULL) {
                    environment_state.input_name = firstfile;
                } else {
                    free(firstfile);
                }
            }
        }
    }
    /*tex Finalize the input filename. */
    if (environment_state.input_name != NULL) {
        /* probably not ok */
        environment_state.argv[environment_state.npos] = normalize_quotes(environment_state.input_name, "argument");
    }
}

static void set_locale(void)
{
    setlocale(LC_ALL, "C");
}


static void update_options(void)
{
    int starttime = -1;
    int utc = -1;
    if (!environment_state.input_name) {
        get_lua_string("texconfig", "jobname", &environment_state.input_name);
    }
    if (!engine_state.dump_name) {
        get_lua_string("texconfig", "formatname", &engine_state.dump_name);
    }
    get_lua_number("texconfig", "start_time", &starttime);
    if (starttime >= 0) {
        set_start_time(starttime);
    }
    get_lua_boolean("texconfig", "use_utc_time", &utc);
    if (utc >= 0 && utc <= 1) {
        engine_state.utc_time = utc;
    }
}

void lua_initialize(int ac, char **av)
{
    struct stat finfo;
    FILE *f;
    char *given_file = NULL;
    char *banner;
    size_t len;
    /*tex Save to pass along to topenin. */
    const char *fmt = "This is " My_Name ", Version %s" ;
    selector = term_only;
    environment_state.argc = ac;
    environment_state.argv = av;
    /* initializations */
    engine_state.lua_only = 0;
    engine_state.lua_init = 0;
    engine_state.startup_filename = NULL;
    engine_state.startup_jobname = NULL;
    engine_state.engine_name = my_name;
    engine_state.dump_name = NULL;
    /* preparations */
    getnames();
    splitnames();
    set_run_time();
// # ifdef _WIN32
//     /*tex Why here and why needed? */
//     _setmaxstdio(2048);
//     _setmode(_fileno(stdin), _O_BINARY);
// # endif
    /* */
    len = strlen(fmt) + strlen(version_state.verbose) ;
    banner = malloc(len);
    sprintf(banner, fmt, version_state.verbose);
    engine_state.luatex_banner = banner;
    /*tex
        Some options must be initialized before options are parsed. We don't
        need that many as we can delegate to \LUA.
    */
    /*tex Parse the commandline. */
    parse_options();
    /*tex Forget about locales. */
    set_locale();
    initialize_lua();
    /*tex This can be redone later. */
    initialize_functions(0);
    initialize_properties(0);
    /*tex Initialize the internalized strings. */
    set_init_keys;
    /*tex Here start the key definitions. */
    set_l_pack_type_index;
    set_l_group_code_index;
    set_l_local_par_index;
    set_l_math_style_name_index;
    /* */
    l_set_node_data();
    l_set_token_data();
    l_set_font_data();
    /*tex Collect arguments. */
    prepare_cmdline(Luas, environment_state.luatex_lua_offset);
    if (engine_state.startup_filename != NULL && !is_readable(engine_state.startup_filename)) {
        free(engine_state.startup_filename);
        engine_state.startup_filename = NULL;
    }
    /*tex
        Now run the file (in luatex there is a special tex table pushed with limited
        functionality (initialize, run, finish) but the normal tex helpers are not
        unhidden so basically one has no tex. We no longer have that.
    */
    if (engine_state.startup_filename != NULL) {
        if (engine_state.lua_only) {
            if (luaL_loadfile(Luas, engine_state.startup_filename)) {
                emergency_message("lua error","%s",lua_tostring(Luas, -1));
                exit(EXIT_FAILURE);
            } else if (lua_pcall(Luas, 0, 0, 0)) {
                emergency_message("lua error","%s",lua_tostring(Luas, -1));
                lua_traceback(Luas);
                exit(EXIT_FAILURE);
            } else if (given_file) {
                free(given_file);
            }
            exit(0);
        } else {
            /*tex a normal tex run */
            if (luaL_loadfile(Luas, engine_state.startup_filename)) {
                emergency_message("lua error","%s",lua_tostring(Luas, -1));
                exit(EXIT_FAILURE);
            } else if (lua_pcall(Luas, 0, 0, 0)) {
                emergency_message("lua error","%s",lua_tostring(Luas, -1));
                lua_traceback(Luas);
                exit(EXIT_FAILURE);
            }
            update_options();
            check_fmt_name();
        }
    } else if (engine_state.lua_init) {
        emergency_message("startup error","no valid startup file given, quitting");
        exit(EXIT_FAILURE);
    } else {
        /* init */
        check_fmt_name();
    }
    /*tex

        At this point we haven't yet set the startup file. This is because we still have
        this \quote {first input line} hackery around. So we check it later.

    */
    /* moved here but why needed */
# ifdef _WIN32
    if (environment_state.argc > 1) {
        char *pp;
        if ((strlen(environment_state.argv[environment_state.argc-1]) > 2) && isalpha(environment_state.argv[environment_state.argc-1][0]) && (environment_state.argv[environment_state.argc-1][1] == ':') && (environment_state.argv[environment_state.argc-1][2] == '\\')) {
            for (pp=environment_state.argv[environment_state.argc-1]+2; *pp; pp++) {
                if (*pp == '\\')
                    *pp = '/';
            }
        }
    }
# endif
}

void check_texconfig_init(void)
{
    if (Luas != NULL) {
        lua_getglobal(Luas, "texconfig");
        if (lua_istable(Luas, -1)) {
            lua_getfield(Luas, -1, "init");
            if (lua_isfunction(Luas, -1)) {
                int i = lua_pcall(Luas, 0, 0, 0);
                if (i) {
                    /*tex
                        We can't be more precise here as it's called before \TEX\
                        initialization happens.
                    */
                    fprintf(stderr, "This went wrong: %s\n", lua_tostring(Luas, -1));
                    error();
                }
            }
        }
    }
}
