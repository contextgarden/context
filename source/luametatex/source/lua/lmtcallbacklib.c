/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex

    These are the supported callbacks (by name). This list must have the same size and order as the
    array in |lmtcallbacklib.h|! The structure and capabilities evolved a bit over time. There are 
    differences between \LUATEX\ and \LUAMETATEX\ in callbacks with the same name. 

*/

callback_state_info lmt_callback_state = {
    .index   = 0,
    .options = 0,
    .items   = {
        { .value = 0, .state = 0,                          .name = ""                     }, /*tex empty on purpose */
        { .value = 0, .state = 0,                          .name = "test_only"            },
        { .value = 0, .state = callback_state_fundamental, .name = "find_log_file"        },
        { .value = 0, .state = callback_state_fundamental, .name = "find_format_file"     },
        { .value = 0, .state = callback_state_fundamental, .name = "open_data_file"       },
        { .value = 0, .state = callback_state_fundamental, .name = "process_jobname"      },
        { .value = 0, .state = callback_state_fundamental, .name = "start_run"            },
        { .value = 0, .state = callback_state_fundamental, .name = "stop_run"             },
        { .value = 0, .state = callback_state_fundamental, .name = "define_font"          },
        { .value = 0, .state = callback_state_selective,   .name = "quality_font"         },
        { .value = 0, .state = callback_state_selective,   .name = "pre_output"           },
        { .value = 0, .state = 0,                          .name = "buildpage"            },
        { .value = 0, .state = callback_state_selective,   .name = "hpack"                },
        { .value = 0, .state = callback_state_selective,   .name = "vpack"                },
        { .value = 0, .state = callback_state_selective,   .name = "hyphenate"            },
        { .value = 0, .state = callback_state_selective,   .name = "ligaturing"           },
        { .value = 0, .state = callback_state_selective,   .name = "kerning"              },
        { .value = 0, .state = callback_state_selective,   .name = "glyph_run"            },
        { .value = 0, .state = 0,                          .name = "pre_linebreak"        },
        { .value = 0, .state = callback_state_selective,   .name = "linebreak"            },
        { .value = 0, .state = 0,                          .name = "post_linebreak"       },
        { .value = 0, .state = callback_state_selective,   .name = "append_to_vlist"      },
        { .value = 0, .state = callback_state_selective,   .name = "alignment"            },
        { .value = 0, .state = callback_state_selective,   .name = "local_box"            },
        { .value = 0, .state = callback_state_selective,   .name = "packed_vbox"          },
        { .value = 0, .state = callback_state_selective,   .name = "mlist_to_hlist"       },
        { .value = 0, .state = callback_state_fundamental, .name = "pre_dump"             },
        { .value = 0, .state = callback_state_fundamental, .name = "start_file"           },
        { .value = 0, .state = callback_state_fundamental, .name = "stop_file"            },
        { .value = 0, .state = callback_state_tracing,     .name = "intercept_tex_error"  },
        { .value = 0, .state = callback_state_tracing,     .name = "intercept_lua_error"  },
        { .value = 0, .state = callback_state_tracing,     .name = "show_error_message"   },
        { .value = 0, .state = callback_state_tracing,     .name = "show_warning_message" },
        { .value = 0, .state = callback_state_tracing,     .name = "hpack_quality"        },
        { .value = 0, .state = callback_state_tracing,     .name = "vpack_quality"        },
        { .value = 0, .state = callback_state_tracing,     .name = "linebreak_check"      },
        { .value = 0, .state = callback_state_tracing,     .name = "balance_check"        },
        { .value = 0, .state = callback_state_tracing,     .name = "show_vsplit"          },
        { .value = 0, .state = callback_state_tracing,     .name = "show_build"           },
        { .value = 0, .state = 0,                          .name = "insert_par"           },
        { .value = 0, .state = callback_state_selective,   .name = "append_adjust"        },
        { .value = 0, .state = callback_state_selective,   .name = "append_migrate"       },
        { .value = 0, .state = callback_state_selective,   .name = "append_line"          },
     /* { .value = 0, .state = callback_state_selective,   .name = "pre_line"             }, */
        { .value = 0, .state = 0,                          .name = "insert_distance"      },
     /* { .value = 0, .state = 0,                          .name = "fire_up_output"       }, */
        { .value = 0, .state = callback_state_fundamental, .name = "wrapup_run"           },
        { .value = 0, .state = 0,                          .name = "begin_paragraph"      },
        { .value = 0, .state = 0,                          .name = "paragraph_context"    },
     /* { .value = 0, .state = 0,                          .name = "get_math_char"        }, */
        { .value = 0, .state = 0,                          .name = "math_rule"            },
        { .value = 0, .state = 0,                          .name = "make_extensible"      },
        { .value = 0, .state = 0,                          .name = "register_extensible"  },
        { .value = 0, .state = callback_state_tracing,     .name = "show_whatsit"         },
        { .value = 0, .state = callback_state_tracing,     .name = "get_attribute"        },
        { .value = 0, .state = callback_state_tracing,     .name = "get_noad_class"       },
        { .value = 0, .state = callback_state_tracing,     .name = "get_math_dictionary"  },
        { .value = 0, .state = callback_state_tracing,     .name = "show_lua_call"        },
        { .value = 0, .state = callback_state_tracing,     .name = "trace_memory"         },
        { .value = 0, .state = callback_state_tracing,     .name = "handle_overload"      },
        { .value = 0, .state = callback_state_tracing,     .name = "missing_character"    },
        { .value = 0, .state = callback_state_selective,   .name = "process_character"    },
        { .value = 0, .state = callback_state_tracing,     .name = "linebreak_quality"    },
        { .value = 0, .state = callback_state_selective,   .name = "paragraph_pass"       },
        { .value = 0, .state = callback_state_selective,   .name = "handle_uleader"       },
        { .value = 0, .state = callback_state_selective,   .name = "handle_uinsert"       },
        { .value = 0, .state = 0,                          .name = "italic_correction"    },
        { .value = 0, .state = callback_state_tracing,     .name = "show_loners"          },
        { .value = 0, .state = callback_state_selective,   .name = "tail_append"          },
        { .value = 0, .state = 0,                          .name = "balance_boundary"     },
        { .value = 0, .state = 0,                          .name = "balance_insert"       },
    } 
};

/*tex

    This is the generic callback handler, inspired by the one described in the \LUA\ manual(s). It
    got adapted over time and can also handle some userdata arguments.

*/

static int callbacklib_aux_run(lua_State *L, int id, int special, const char *values, va_list vl, int top, int base)
{
    int narg = 0;
    int nres = 0;
    if (special == 2) {
        /*tex copy the enclosing table */
        lua_pushvalue(L, -2);
    }
    for (narg = 0; *values; narg++) {
        switch (*values++) {
            case callback_boolean_key:
                /*tex A boolean: */
                lua_pushboolean(L, va_arg(vl, int));
                break;
            case callback_charnum_key:
                /*tex A (8 bit) character: */
                {
                    char cs = (char) va_arg(vl, int);
                    lua_pushlstring(L, &cs, 1);
                }
                break;
            case callback_integer_key:
                /*tex An integer: */
                lua_pushinteger(L, va_arg(vl, int));
                break;
            case callback_line_key:
                /*tex A buffer section, with implied start: */
                lua_pushlstring(L, (char *) (lmt_fileio_state.io_buffer + lmt_fileio_state.io_first), (size_t) va_arg(vl, int));
                break;
            case callback_strnumber_key:
                /*tex A \TEX\ string (indicated by an index): */
                {
                    size_t len;
                    const char *s = tex_makeclstring(va_arg(vl, int), &len);
                    lua_pushlstring(L, s, len);
                }
                break;
            case callback_lstring_key:
                /*tex A \LUA\ string: */
                {
                    lstring *lstr = va_arg(vl, lstring *);
                    lua_pushlstring(L, (const char *) lstr->s, lstr->l);
                }
                break;
            case callback_node_key:
                /*tex A \TEX\ node: */
             // lmt_push_node_fast(L, va_arg(vl, int));
                lmt_push_node_to_callback(L, va_arg(vl, int));
                break;
            case callback_string_key:
                /*tex A \CCODE\ string: */
                lua_pushstring(L, va_arg(vl, char *));
                break;
            case '-':
                narg--;
                break;
            case '>':
                goto ENDARGS;
            default:
                ;
        }
    }
  ENDARGS:
    nres = (int) strlen(values);
    if (special == 1) {
        nres++;
    } else if (special == 2) {
        narg++;
    }
    lmt_lua_state.saved_callback_count++;
    {
        int i = lua_pcall(L, narg, nres, base);
        if (i) {
            /*tex
                We can't be more precise here as it could be called before \TEX\ initialization is
                complete.
            */
            lua_remove(L, top + 2);
            lmt_error(L, "run callback", id, (i == LUA_ERRRUN ? 0 : 1));
            lua_settop(L, top);
            return 0;
        }
    }
    if (nres == 0) {
        return 1;
    }
    nres = -nres;
    while (*values) {
        int t = lua_type(L, nres);
        switch (*values++) {
            case callback_boolean_key:
                switch (t) {
                    case LUA_TBOOLEAN:
                        *va_arg(vl, int *) = lua_toboolean(L, nres);
                        break;
                    case LUA_TNIL:
                        *va_arg(vl, int *) = 0;
                        break;
                    default:
                        return tex_formatted_error("callback", "boolean or nil expected, false or nil, not: %s\n", lua_typename(L, t));
                }
                break;
            /*
            case callback_charnum_key:
                break;
            */
            case callback_integer_key:
                switch (t) {
                    case LUA_TNUMBER:
                        *va_arg(vl, int *) = lmt_tointeger(L, nres);
                        break;
                    default:
                        return tex_formatted_error("callback", "number expected, not: %s\n", lua_typename(L, t));
                }
                break;
            case callback_line_key:
                switch (t) {
                    case LUA_TSTRING:
                        {
                            size_t len;
                            const char *s = lua_tolstring(L, nres, &len);
                            if (s && (len > 0)) {
                                int *bufloc = va_arg(vl, int *);
                                int ret = *bufloc;
                                if (tex_room_in_buffer(ret + (int) len)) {
                                    strncpy((char *) (lmt_fileio_state.io_buffer + ret), s, len);
                                    *bufloc += (int) len;
                                    /* while (len--) {  fileio_state.io_buffer[(*bufloc)++] = *s++; } */
                                    while ((*bufloc) - 1 > ret && lmt_fileio_state.io_buffer[(*bufloc) - 1] == ' ') {
                                        (*bufloc)--;
                                    }
                               } else {
                                    return 0;
                               }
                            }
                            /*tex We can assume no more arguments! */
                        }
                        break;
                    case LUA_TNIL:
                        /*tex We assume no more arguments! */
                        return 0;
                    default:
                        return tex_formatted_error("callback", "string or nil expected, not: %s\n", lua_typename(L, t));
                }
                break;
            case callback_strnumber_key:
                switch (t) {
                    case LUA_TSTRING:
                        {
                            size_t len;
                            const char *s = lua_tolstring(L, nres, &len);
                            if (s) {
                                *va_arg(vl, int *) = tex_maketexlstring(s, len);
                            } else {
                                /*tex |len| can be zero */
                                *va_arg(vl, int *) = 0;
                            }
                        }
                        break;
                    default:
                        return tex_formatted_error("callback", "string expected, not: %s\n", lua_typename(L, t));
               }
                break;
            case callback_lstring_key:
                switch (t) {
                    case LUA_TSTRING:
                        {
                            size_t len;
                            const char *s = lua_tolstring(L, nres, &len);
                            if (s && len > 0) {
                                lstring *lsret = lmt_memory_malloc(sizeof(lstring));
                                if (lsret) {
                                    lsret->s = lmt_memory_malloc((unsigned) (len + 1));
                                    if (lsret->s) {
                                        (void) memcpy(lsret->s, s, (len + 1));
                                        lsret->l = len;
                                        *va_arg(vl, lstring **) = lsret;
                                    } else {
                                        *va_arg(vl, int *) = 0;
                                    }
                                } else {
                                    *va_arg(vl, int *) = 0;
                                }
                            } else {
                                /*tex |len| can be zero */
                                *va_arg(vl, int *) = 0;
                            }
                        }
                        break;
                    default:
                        return tex_formatted_error("callback", "string expected, not: %s\n", lua_typename(L, t));
                }
                break;
            case callback_node_key:
                switch (t) {
                    case LUA_TUSERDATA:
                     // *va_arg(vl, int *) = lmt_check_isnode(L, nres);
                        *va_arg(vl, int *) = lmt_pop_node_from_callback(L, nres);
                        break;
                    default:
                        *va_arg(vl, int *) = null;
                        break;
                }
                break;
            case callback_string_key:
                switch (t) {
                    case LUA_TSTRING:
                        {
                            size_t len;
                            const char *s = lua_tolstring(L, nres, &len);
                            if (s) {
                                char *ss = lmt_memory_malloc((unsigned) (len + 1));
                                if (ss) {
                                    memcpy(ss, s, (len + 1));
                                 }
                                *va_arg(vl, char **) = ss;
                            } else {
                                *va_arg(vl, char **) = NULL;
                             // *va_arg(vl, int *) = 0;
                            }
                        }
                        break;
                    default:
                        return tex_formatted_error("callback", "string expected, not: %s\n", lua_typename(L, t));
                }
                break;
            case callback_result_s_key:
                switch (t) {
                    case LUA_TNIL:
                        *va_arg(vl, int *) = 0;
                        break;
                    case LUA_TBOOLEAN:
                        if (lua_toboolean(L, nres) == 0) {
                            *va_arg(vl, int *) = 0;
                            break;
                        } else {
                            return tex_formatted_error("callback", "string, false or nil expected, not: %s\n", lua_typename(L, t));
                        }
                    case LUA_TSTRING:
                        {
                            size_t len;
                            const char *s = lua_tolstring(L, nres, &len);
                            if (s) {
                                char *ss = lmt_memory_malloc((unsigned) (len + 1));
                                if (ss) {
                                    memcpy(ss, s, (len + 1));
                                    *va_arg(vl, char **) = ss;
                                } else {
                                   *va_arg(vl, char **) = NULL;
                                // *va_arg(vl, int *) = 0;
                                }
                            } else {
                                *va_arg(vl, char **) = NULL;
                             // *va_arg(vl, int *) = 0;
                            }
                        }
                        break;
                    default:
                        return tex_formatted_error("callback", "string, false or nil expected, not: %s\n", lua_typename(L, t));
                }
                break;
            case callback_result_i_key:
                switch (t) {
                    case LUA_TNUMBER:
                        *va_arg(vl, int *) = lmt_tointeger(L, nres);
                        break;
                    default:
                     /* *va_arg(vl, int *) = 0; */ /*tex We keep the value! */
                        break;
                }
                break;
            default:
                return tex_formatted_error("callback", "invalid value type returned\n");
        }
        nres++;
    }
    return 1;
}

/*tex
    Especially the \IO\ related callbacks are registered once, for instance when a file is opened,
    and (re)used later. These are dealt with here.
*/

int lmt_run_saved_callback_close(lua_State *L, int r)
{
    int ret = 0;
    int stacktop = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, r);
    lua_push_key(close);
    if (lua_rawget(L, -2) == LUA_TFUNCTION) {
        ret = lua_pcall(L, 0, 0, 0);
        if (ret) {
            return tex_formatted_error("lua", "error in close file callback") - 1;
        }
    }
    lua_settop(L, stacktop);
    return ret;
}

int lmt_run_saved_callback_line(lua_State *L, int r, int firstpos)
{
    int ret = -1; /* -1 is error, >= 0 is buffer length */
    int stacktop = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, r);
    lua_push_key(reader);
    if (lua_rawget(L, -2) == LUA_TFUNCTION) {
        lua_pushvalue(L, -2);
        lmt_lua_state.file_callback_count++;
        ret = lua_pcall(L, 1, 1, 0);
        if (ret) {
            ret = tex_formatted_error("lua", "error in read line callback") - 1;
        } else if (lua_type(L, -1) == LUA_TSTRING) {
            size_t len;
            const char *s = lua_tolstring(L, -1, &len);
            if (s && len > 0) {
                while (len >= 1 && s[len-1] == ' ') {
                    len--;
                }
                if (len > 0) {
                    if (tex_room_in_buffer(firstpos + (int) len)) {
                        strncpy((char *) (lmt_fileio_state.io_buffer + firstpos), s, len);
                        ret = firstpos + (int) len;
                    } else {
                        tex_overflow_error("buffer", (int) len);
                        ret = 0;
                    }
                } else {
                    ret = 0;
                }
            } else {
                ret = 0;
            }
        } else {
            ret = -1;
        }
    }
    lua_settop(L, stacktop);
    return ret;
}

/*tex

    Many callbacks have a specific handler, so they don't use the previously mentioned generic one.
    The next bunch of helpers checks for them being set and deals invoking them as well as reporting
    errors.

*/

# define callbacks_trace 0

int lmt_callback_okay(lua_State *L, int i, int *top)
{
    *top = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_callback_state.index);
    lua_pushcfunction(L, lmt_traceback); /* goes before function */
    if (lua_rawgeti(L, -2, i) == LUA_TFUNCTION) {
        if (lmt_callback_state.options & callback_option_trace) {
            /*tex Just a raw print because we don't want interference */
            printf("[callback %02i : %s]\n",i,lmt_callback_state.items[i].name);
        }
        lmt_lua_state.saved_callback_count++;
        return 1;
    } else {
        lua_pop(L, 3);
        return 0;
    }
}

void lmt_callback_error(lua_State *L, int top, int i)
{
    lua_remove(L, top + 2);
    lmt_error(L, "callback error", -1, (i == LUA_ERRRUN ? 0 : 1));
    lua_settop(L, top);
}

int lmt_run_and_save_callback(lua_State *L, int i, const char *values, ...)
{
    int top = 0;
    int ret = 0;
    if (lmt_callback_okay(L, i, &top)) {
        va_list args;
        va_start(args, values);
        ret = callbacklib_aux_run(L, i, 1, values, args, top, top + 2);
        va_end(args);
        if (ret > 0) {
            ret = lua_type(L, -1) == LUA_TTABLE ? luaL_ref(L, LUA_REGISTRYINDEX) : 0;
        }
        lua_settop(L, top);
    }
    return ret;
}

int lmt_run_callback(lua_State *L, int i, const char *values, ...)
{
    int top = 0;
    int ret = 0;
    if (lmt_callback_okay(L, i, &top)) {
        va_list args;
        va_start(args, values);
        ret = callbacklib_aux_run(L, i, 0, values, args, top, top + 2);
        va_end(args);
        lua_settop(L, top);
    }
    return ret;
}

void lmt_destroy_saved_callback(lua_State *L, int i)
{
    luaL_unref(L, LUA_REGISTRYINDEX, i);
}

static int callbacklib_found(lua_State *L)
{
    switch (lua_type(L, 1)) { 
        case LUA_TNUMBER: 
            {
                int cb = lua_tointeger(L, 1);
                return (cb > 0 && cb < total_callbacks) ? cb :  -1;
            }
        case LUA_TSTRING:   
            {
                const char *s = lua_tostring(L, 1);
                if (s) {
                    /* hm, why not start at 1 */
                    for (int cb = 0; cb < total_callbacks; cb++) {
                        if (strcmp(lmt_callback_state.items[cb].name, s) == 0) {
                            return cb;
                        }
                    }
                }
                return -1;
            } 
        default:
            return -1;
    }
}

static int callbacklib_register(lua_State *L)
{
    int cb = callbacklib_found(L);
    if (cb > 0) {
        if (lmt_callback_state.items[cb].state & callback_state_frozen) {
           /*tex Maybe issue a message. */
        } else {
            switch (lua_type(L, 2)) {
                case LUA_TFUNCTION:
                    lmt_callback_state.items[cb].value = cb;
                    lmt_callback_state.items[cb].state |= callback_state_set;
                    lmt_callback_state.items[cb].state |= callback_state_touched;
                    break;
                case LUA_TBOOLEAN:
                    if (lua_toboolean(L, 2)) {
                        goto BAD; /*tex Only |false| is valid. */
                    }
                    // fall through
                case LUA_TNIL:
                    lmt_callback_state.items[cb].value = -1;
                    lmt_callback_state.items[cb].state &= ~ callback_state_set;
                    lmt_callback_state.items[cb].state |= callback_state_touched;
                    break;
            }
            /*tex Push the callback table on the stack. */ 
            lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_callback_state.index);
            /*tex Push the function or |nil|. */
            lua_pushvalue(L, 2);
            /*tex Update the value. */
            lua_rawseti(L, -2, cb);
            lua_pop(L, 1); /* was: lua_rawseti(L, LUA_REGISTRYINDEX, lmt_callback_state.metatable_index); */
            /*tex Return the callback id, which is a fixed value. */
            lua_pushinteger(L, cb);
            return 1;
        } 
    }
  BAD:
    lua_pushnil(L);
    return 1;
}

static int callbacklib_getstate(lua_State *L)
{
    int cb = callbacklib_found(L);
    if (cb > 0) {
        lua_pushinteger(L, lmt_callback_state.items[cb].state);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int callbacklib_setstate(lua_State *L)
{
    int cb = callbacklib_found(L);
    if (cb > 0) {
        /*tex We can always enable and disable. */
        if (lua_type(L, 2) == LUA_TNUMBER) {
            lmt_callback_state.items[cb].state |= (lua_tointeger(L, 2) & 0xFFFF);
        } else { 
            lmt_callback_state.items[cb].state &= ~ callback_state_disabled;
        }
        lua_pushboolean(L, 1);
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

static int callbacklib_setoptions(lua_State *L)
{
    int options = lua_tointeger(L, 1);
    int set = lua_type(L, 2) == LUA_TBOOLEAN ? lua_toboolean(L, 2) : 1;
    if (options & callback_option_direct) {
        if (lmt_callback_state.options & callback_option_direct) {
            tex_formatted_warning("callbacks", "direct node mode is enabled and can't be changed");
        } else if (set) { 
            lmt_callback_state.options |= callback_option_direct;
        }
    }
    if (options & callback_option_trace) {
        if (set) {
            lmt_callback_state.options |= callback_option_trace; 
        } else {
            lmt_callback_state.options &= ~ callback_option_trace;
        }
    }
    return 0;
}

static int callbacklib_getoptions(lua_State *L)
{
    lua_pushinteger(L, lmt_callback_state.options);
    return 1;
}

void lmt_run_memory_callback(const char* what, int success)
{
    lmt_run_callback(lmt_lua_state.lua_instance, trace_memory_callback, "Sb->", what, success);
    fflush(stdout);
}

/*tex

    The \LUA\ library that deals with callbacks has some diagnostic helpers that makes it possible
    to implement a higher level interface.

*/

static int callbacklib_find(lua_State *L)
{
    int cb = callbacklib_found(L);
    if (cb > 0 && ! (lmt_callback_state.items[cb].state & callback_state_private)) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, lmt_callback_state.index);
        lua_rawgeti(L, -1, cb);
    } else { 
        lua_pushnil(L);
    }
    return 1;
}

static int callbacklib_known(lua_State *L)
{
    lua_pushboolean(L, callbacklib_found(L) > 0);
    return 1;
}

static int callbacklib_getindex(lua_State *L)
{
    int cb = callbacklib_found(L);
    if (cb > 0) {
        lua_pushinteger(L, cb);
    } else { 
        lua_pushnil(L);
    }
    return 1;
}

static int callbacklib_list(lua_State *L)
{
    lua_createtable(L, 0, total_callbacks);
    for (int cb = 1; cb < total_callbacks; cb++) {
        lua_pushstring(L, lmt_callback_state.items[cb].name);
        lua_pushboolean(L, lmt_callback_defined(cb));
        lua_rawset(L, -3);
    }
    return 1;
}

static int callbacklib_names(lua_State *L)
{
    lua_createtable(L, total_callbacks, 0);
    for (int cb = 1; cb < total_callbacks; cb++) {
        lua_pushstring(L, lmt_callback_state.items[cb].name);
        lua_rawseti(L, -2, cb);
    }
    return 1;
}

/* todo: language function calls */

void lmt_push_callback_usage(lua_State *L)
{
    lua_createtable(L, 0, 9);
    lua_push_integer_at_key(L, saved,    lmt_lua_state.saved_callback_count);
    lua_push_integer_at_key(L, file,     lmt_lua_state.file_callback_count);
    lua_push_integer_at_key(L, direct,   lmt_lua_state.direct_callback_count);
    lua_push_integer_at_key(L, function, lmt_lua_state.function_callback_count);
    lua_push_integer_at_key(L, value,    lmt_lua_state.value_callback_count);
    lua_push_integer_at_key(L, local,    lmt_lua_state.local_callback_count);
    lua_push_integer_at_key(L, bytecode, lmt_lua_state.bytecode_callback_count);
    lua_push_integer_at_key(L, message,  lmt_lua_state.message_callback_count);
    lua_push_integer_at_key(L, count,
        lmt_lua_state.saved_callback_count
      + lmt_lua_state.file_callback_count
      + lmt_lua_state.direct_callback_count
      + lmt_lua_state.function_callback_count
      + lmt_lua_state.value_callback_count
      + lmt_lua_state.local_callback_count
      + lmt_lua_state.bytecode_callback_count
      + lmt_lua_state.message_callback_count
    );
}

static int callbacklib_usage(lua_State *L)
{
    lmt_push_callback_usage(L);
    return 1;
}

static int callbacklib_testonly(lua_State *L)
{
    int cb = lmt_callback_defined(test_only_callback);
    if (cb > 0) {
        int top = 0;
        if (lmt_callback_okay(L, cb, &top)) {
            int i; 
            lua_pushinteger(L, lmt_callback_state.items[cb].state);
            i = lmt_callback_call(L, 1, 0, top);
            if (i) {
                lmt_callback_error(L, top, i);
            } else {
                lmt_callback_wrapup(L, top);
                lua_pushboolean(L, 1);
                return 1;
            }
        }
    }
    lua_pushboolean(L, 0);
    return 1;
}

static int callbacklib_getoptionvalues(lua_State *L)
{
    lua_createtable(L, 2, 0);
    lua_set_string_by_index(L, callback_option_direct, "direct");
    lua_set_string_by_index(L, callback_option_trace,  "trace");
    return 1;
}

static int callbacklib_getstatevalues(lua_State *L)
{
    lua_createtable(L, 2, 6);
    lua_set_string_by_index(L, callback_state_set,         "set");
    lua_set_string_by_index(L, callback_state_disabled,    "disabled");
    lua_set_string_by_index(L, callback_state_frozen,      "frozen");
    lua_set_string_by_index(L, callback_state_private,     "private");
    lua_set_string_by_index(L, callback_state_touched,     "touched");
    lua_set_string_by_index(L, callback_state_tracing,     "tracing");
    lua_set_string_by_index(L, callback_state_selective,   "selective");
    lua_set_string_by_index(L, callback_state_fundamental, "fundamental");
    return 1;
}

static const struct luaL_Reg callbacklib_function_list[] = {
    { "find",            callbacklib_find            },
    { "known",           callbacklib_known           },
    { "register",        callbacklib_register        },
    { "list",            callbacklib_list            },
    { "names",           callbacklib_names           },
    { "usage",           callbacklib_usage           },
    { "getindex",        callbacklib_getindex        },
    { "setstate",        callbacklib_setstate        },
    { "getstate",        callbacklib_getstate        },
    { "setoptions",      callbacklib_setoptions      },
    { "getoptions",      callbacklib_getoptions      },
    { "testonly",        callbacklib_testonly        },
    { "getoptionvalues", callbacklib_getoptionvalues },
    { "getstatevalues",  callbacklib_getstatevalues  },
    { NULL,              NULL                        },
};

int luaopen_callback(lua_State *L)
{
    lua_newtable(L);
    luaL_setfuncs(L, callbacklib_function_list, 0);
    lua_createtable(L, total_callbacks, 0);
    lmt_callback_state.index = luaL_ref(L, LUA_REGISTRYINDEX);
    return 1;
}
