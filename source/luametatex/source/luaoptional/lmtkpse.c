/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"
# include "lmtoptional.h"

/*tex

    As part of the lean and mean concept we have no \KPSE\ on board and as with \LUATEX\ the
    \CONTEXT\ macro package doesn't need it. However, because we might want to play with it being
    a runner for other engines (as we do with the \LUATEX\ binary in kpse mode), we have at least
    an interface for it. One problem is to locate the right version of the delayed loaded kpse
    library (but we can add some clever locating code for that if needed). We keep the interface
    mostly the same as \LUATEX.

    This is actually a left-over from an experiment, but it works okay, so I moved the code into
    the source tree and made a proper \CONTEXT\ library wrapper too. We are less clever than in
    \LUATEX, so there are no additional lookup functions. After all, it is just about locating
    files and not about writing a searcher in \LUA. So, there no subdir magic either, as one has
    \LUA\ for that kind of stuff. No \DPI\ related magic either. In \LUATEX\ there are some more
    functions in the \type {kpse} namespace but these don't really relate to locating files.

    We can actually omit the next two lists and pass numbers but then we need to store that list at
    the \LUA\ end so we don't save much (but I might do it some day nevertheless). The nect code is
    rather lightweight which is on purpose. Of course occationally we need to check the \API\ but
    \KPSE\ pretty stable and we don't need the extra stuff that it provides (keep in mind that it
    has to serve all kind of programs in the \TEX\ infrastructure so it's a complex beast).

*/

typedef enum kpselib_file_format_type {
    kpse_gf_format, kpse_pk_format, kpse_any_glyph_format, kpse_tfm_format, kpse_afm_format,
    kpse_base_format, kpse_bib_format, kpse_bst_format, kpse_cnf_format, kpse_db_format,
    kpse_fmt_format, kpse_fontmap_format, kpse_mem_format, kpse_mf_format, kpse_mfpool_format,
    kpse_mft_format, kpse_mp_format, kpse_mppool_format, kpse_mpsupport_format, kpse_ocp_format,
    kpse_ofm_format, kpse_opl_format, kpse_otp_format, kpse_ovf_format, kpse_ovp_format,
    kpse_pict_format, kpse_tex_format, kpse_texdoc_format, kpse_texpool_format,
    kpse_texsource_format, kpse_tex_ps_header_format, kpse_troff_font_format, kpse_type1_format,
    kpse_vf_format, kpse_dvips_config_format, kpse_ist_format, kpse_truetype_format,
    kpse_type42_format, kpse_web2c_format, kpse_program_text_format, kpse_program_binary_format,
    kpse_miscfonts_format, kpse_web_format, kpse_cweb_format, kpse_enc_format, kpse_cmap_format,
    kpse_sfd_format, kpse_opentype_format, kpse_pdftex_config_format, kpse_lig_format,
    kpse_texmfscripts_format, kpse_lua_format, kpse_fea_format, kpse_cid_format, kpse_mlbib_format,
    kpse_mlbst_format, kpse_clua_format, /* kpse_ris_format, */ /* kpse_bltxml_format, */
    kpse_last_format
} kpselib_file_format_type;

static const char *const kpselib_file_type_names[] = {
    "gf", "pk", "bitmap font", "tfm", "afm", "base", "bib", "bst", "cnf", "ls-R", "fmt", "map",
    "mem", "mf", "mfpool", "mft", "mp", "mppool", "MetaPost support", "ocp", "ofm", "opl", "otp",
    "ovf", "ovp", "graphic/figure", "tex", "TeX system documentation", "texpool",
    "TeX system sources", "PostScript header",  "Troff fonts", "type1 fonts", "vf", "dvips config",
    "ist", "truetype fonts", "type42 fonts", "web2c files", "other text files", "other binary files",
    "misc fonts", "web", "cweb", "enc files", "cmap files", "subfont definition files",
    "opentype fonts", "pdftex config", "lig files", "texmfscripts", "lua", "font feature files",
    "cid maps", "mlbib", "mlbst", "clua",
    NULL
};

typedef struct kpselib_state_info {

    int initialized;
    int prognameset;

    void   (*lib_kpse_set_program_name)   ( const char *prog, const char *name );
    void   (*lib_kpse_reset_program_name) ( const char *name );
    char * (*lib_kpse_path_expand)        ( const char *name );
    char * (*lib_kpse_brace_expand)       ( const char *name );
    char * (*lib_kpse_var_expand)         ( const char *name );
    char * (*lib_kpse_var_value)          ( const char *name );
    char * (*lib_kpse_readable_file)      ( const char *name );
    char * (*lib_kpse_find_file)          ( const char *name, int filetype, int mustexist );
    char **(*lib_kpse_all_path_search)    ( const char *path, const char *name );

} kpselib_state_info;

static kpselib_state_info kpselib_state = {

    .initialized                 = 0,
    .prognameset                 = 0,

    .lib_kpse_set_program_name   = NULL,
    .lib_kpse_reset_program_name = NULL,
    .lib_kpse_path_expand        = NULL,
    .lib_kpse_brace_expand       = NULL,
    .lib_kpse_var_expand         = NULL,
    .lib_kpse_var_value          = NULL,
    .lib_kpse_readable_file      = NULL,
    .lib_kpse_find_file          = NULL,
    .lib_kpse_all_path_search    = NULL,

};

static int kpselib_aux_valid_progname(lua_State *L)
{
    (void) L;
    if (kpselib_state.prognameset) {
        return 1;
    } else if (! kpselib_state.initialized) {
        tex_normal_warning("kpse", "not yet initialized");
        return 0;
    } else {
        tex_normal_warning("kpse", "no program name set");
        return 0;
    }
}

static int kpselib_set_program_name(lua_State *L)
{
    (void) L;
    if (kpselib_state.initialized) {
        const char *exe_name = luaL_checkstring(L, 1);
        const char *prog_name = luaL_optstring(L, 2, exe_name);
        if (kpselib_state.prognameset) {
            kpselib_state.lib_kpse_reset_program_name(prog_name);
        } else {
            kpselib_state.lib_kpse_set_program_name(exe_name, prog_name);
            kpselib_state.prognameset = 1;
        }
    }
    return 0;
}

static int kpselib_find_file(lua_State *L)
{
    if (kpselib_aux_valid_progname(L)) {
        unsigned filetype = kpse_tex_format;
        int mustexist = 0;
        const char *filename = luaL_checkstring(L, 1);
        int top = lua_gettop(L);
        for (int i = 2; i <= top; i++) {
            switch (lua_type(L, i)) {
                case LUA_TBOOLEAN:
                    mustexist = lua_toboolean(L, i);
                    break;
                case LUA_TNUMBER:
                    /*tex This is different from \LUATEX: we accept a filetype number. */
                    filetype = (unsigned) lua_tointeger(L, i);
                    break;
                case LUA_TSTRING:
                    filetype = luaL_checkoption(L, i, NULL, kpselib_file_type_names);
                    break;
            }
            if (filetype >= kpse_last_format) {
                filetype = kpse_tex_format;
            }
        }
        lua_pushstring(L, kpselib_state.lib_kpse_find_file(filename, filetype, mustexist));
        return 1;
    } else {
        return 0;
    }
}

/*
    I'll ask Taco about the free. For now it will do. Currently I only need to do some lookups for
    checking clashes with other installations (issue reported on context ml).
*/

static int kpselib_find_files(lua_State *L)
{
    if (kpselib_aux_valid_progname(L)) {
        const char *userpath = luaL_checkstring(L, 1);
        const char *filename = luaL_checkstring(L, 2);
        char *filepath = kpselib_state.lib_kpse_path_expand(userpath);
        if (filepath) {
            char **result = kpselib_state.lib_kpse_all_path_search(filepath, filename);
         /* free(filepath); */ /* crashes, so it looks like def kpse keeps it */
            if (result) {
                lua_Integer r = 0;
                lua_newtable(L);
                while (result[r]) {
                    lua_pushstring(L, result[r]);
                    lua_rawseti(L, -2, ++r);
                }
             /* free(result); */ /* idem */
                return 1;
            }
        } else {
         /* free(filepath); */ /* idem */
        }
    }
    return 0;
}

static int kpselib_expand_path(lua_State *L)
{
    if (kpselib_aux_valid_progname(L)) {
        lua_pushstring(L, kpselib_state.lib_kpse_path_expand(luaL_checkstring(L, 1)));
        return 1;
    } else {
        return 0;
    }
}

static int kpselib_expand_braces(lua_State *L)
{
    if (kpselib_aux_valid_progname(L)) {
        lua_pushstring(L, kpselib_state.lib_kpse_brace_expand(luaL_checkstring(L, 1)));
    return 1;
    } else {
        return 0;
    }
}

static int kpselib_expand_var(lua_State *L)
{
    if (kpselib_aux_valid_progname(L)) {
        lua_pushstring(L, kpselib_state.lib_kpse_var_expand(luaL_checkstring(L, 1)));
        return 1;
    } else {
        return 0;
    }
}

static int kpselib_var_value(lua_State *L)
{
    if (kpselib_aux_valid_progname(L)) {
        lua_pushstring(L, kpselib_state.lib_kpse_var_value(luaL_checkstring(L, 1)));
        return 1;
    } else {
        return 0;
    }
}

static int kpselib_readable_file(lua_State *L)
{
    if (kpselib_aux_valid_progname(L)) {
        /* Why the dup? */
        char *name = strdup(luaL_checkstring(L, 1));
        lua_pushstring(L, kpselib_state.lib_kpse_readable_file(name));
        free(name);
        return 1;
    } else {
        return 0;
    }
}

static int kpselib_get_file_types(lua_State *L)
{
    if (kpselib_aux_valid_progname(L)) {
        lua_createtable(L, kpse_last_format, 0);
        for (lua_Integer i = 0; i < kpse_last_format; i++) {
            if (kpselib_file_type_names[i]) {
                lua_pushstring(L, kpselib_file_type_names[i]);
                lua_rawseti(L, -2, i + 1);
            } else {
                break;
            }
        }
        return 1;
    } else {
        return 0;
    }
}

static int kpselib_initialize(lua_State *L)
{
    if (! kpselib_state.initialized) {
        const char *filename = lua_tostring(L, 1);
        if (filename) {

            lmt_library lib = lmt_library_load(filename);

            kpselib_state.lib_kpse_set_program_name   = lmt_library_find(lib, "kpse_set_program_name");
            kpselib_state.lib_kpse_reset_program_name = lmt_library_find(lib, "kpse_reset_program_name");
            kpselib_state.lib_kpse_all_path_search    = lmt_library_find(lib, "kpse_all_path_search");
            kpselib_state.lib_kpse_find_file          = lmt_library_find(lib, "kpse_find_file");
            kpselib_state.lib_kpse_path_expand        = lmt_library_find(lib, "kpse_path_expand");
            kpselib_state.lib_kpse_brace_expand       = lmt_library_find(lib, "kpse_brace_expand");
            kpselib_state.lib_kpse_var_expand         = lmt_library_find(lib, "kpse_var_expand");
            kpselib_state.lib_kpse_var_value          = lmt_library_find(lib, "kpse_var_value");
            kpselib_state.lib_kpse_readable_file      = lmt_library_find(lib, "kpse_readable_file");

            kpselib_state.initialized = lmt_library_okay(lib);
        }
    }
    lua_pushboolean(L, kpselib_state.initialized);
    return 1;
}

/*tex We use the official names here, with underscores. */

/* init_prog           : no need         */
/* show_path           : maybe           */
/* lookup              : maybe           */
/* default_texmfcnf    : not that useful */
/* record_output_file  : makes no sense  */
/* record_input_file   : makes no sense  */
/* check_permissions   : luatex extra    */

static struct luaL_Reg kpselib_function_list[] = {
    { "initialize",       kpselib_initialize         },
    { "set_program_name", kpselib_set_program_name   },
    { "find_file",        kpselib_find_file          },
    { "find_files",       kpselib_find_files         },
    { "expand_path",      kpselib_expand_path        },
    { "expand_var",       kpselib_expand_var         },
    { "expand_braces",    kpselib_expand_braces      },
    { "var_value",        kpselib_var_value          },
    { "readable_file",    kpselib_readable_file      },
    { "get_file_types",   kpselib_get_file_types     },
    { NULL,               NULL                       },
};

int luaopen_kpse(lua_State * L)
{
    lmt_library_register(L, "kpse", kpselib_function_list);
    return 0;
}
