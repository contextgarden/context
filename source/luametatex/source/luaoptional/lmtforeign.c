/*
    See license.txt in the root of this project.
*/

/*tex

    In \LUATEX\ we provide an ffi library that is derived from luajit but it got orphaned a few years
    after it showed up. A problem with such libraries is that they need to be maintained actively
    because platforms and processors evolve. So, having a mechanism like that makes not much sense in
    a \TEX\ engine. In \LUAMETATEX\ we therefore don't use that library but have a model for delayed
    loading of optional libraries. A few interfaces are built in (like zint) but we don't ship any
    library: you get what is installed on the system (which actually is the whole idea behind using
    most libraries). Delayed loading is implemented by using function pointers and in practice that
    is fast enough (after all we use them in \TEX\ as well as \METAPOST\ without much penalty).

    But \unknown\ what if a user wants to use a library and doesn't want to write an interface? We
    kind of end up again with something ffi. When looking around I ran into an \LUA\ module that
    was made a few years ago (for 5.1 and 5.2) called 'alien' that also binds to libffi. But that
    library looks a bit more complex than we need. For instance, mechanisms for callbacks use libffi
    calls than need some compile time properties that normally come from the h files generated on
    the system and I don't want to impose on users to also install and compile a whole chain of
    dependencies. We could (and maybe some day will if users really need it) provide callbacks
    too but then we also need to keep some system specific 'constants' in sync. We then probaly
    also need to provide libraries at the contextgarden.

    The basics of an interface as used in this module (running over specs) is given in the \LUA\
    manual\ and we also use it for callbacks in \LUATEX\ and therefore \LUAMETATEX. There we use
    varargs but here specification if converted into a recipe that libffi will bind to a function.
    Some code below looks like the code in alien (after all I took a good look at it). The ffi
    part is filtered from the ffi.h.in file. The interfaces are sort of what we do with other
    libraries.

    For the record: when testing, I just used a version of libffi that came with inkscape and I
    saw several other instances on my system disk. A quick test with loading showed that it is no
    problem in the ecosystem that we use in \TEX. The buildot on the contextgarden generates
    binaries for several platforms and one can observe that some platforms (like bsd) are not
    that downward compatible, so there we have multiple versions. This also means that finding
    matching libraries can be an issue. In \CONTEXT\ we never depend on external or evolving
    libraries so it's a user's choice in the end.

    The \LUATEX\ build script and infrastructure are more complex than the \LUAMETATEX\ ones and
    it's often the libraries that make for the - sometimes incompatible - changes which in turn
    demands adaptation of the scripts etc in the build farm. We try to avoid that as much as
    possible but if we ever decide to also provide libraries that match the binaries, but it
    remains a depencenie that you want to avoid in long running projects.

    Comment: I might look into a vararg variant some day, just for fun. Actually, this module is
    mostly about the fun, so it will take some time to evolve.

*/

/*tex
    Because it is an optional module, we use the optional interface.
*/

# include "luametatex.h"
# include "lmtoptional.h"

/*tex
    We need to define a few ffi datatypes and function prototypes. We need to keep an eye on how
    the library evolves but I assume the api is rather stable. We don't want to depend on a system
    specific header file.
*/

typedef struct ffi_type {
    size_t            size;
    unsigned short    alignment;
    unsigned short    type;
    struct ffi_type **elements;
} ffi_type;

typedef enum ffi_types {
    ffi_void_type,
    ffi_int_type,
    ffi_float_type,
    ffi_double_type,
    ffi_longdouble_type,
    ffi_uint8_type,
    ffi_int8_type,
    ffi_uint16_type,
    ffi_int16_type,
    ffi_uint32_type,
    ffi_int32_type,
    ffi_uint64_type,
    ffi_int64_type,
    ffi_struct_type,
    ffi_pointer_type,
    ffi_complex_type, /* unsupported */
    ffi_last_type,
} ffi_types;

/*
    The libffi api document says that the size and alignment should be zero but somehow we do crash
    when we set the size to some value. Only size_t is now system dependent (e.g. on 32 bit windows
    it's different).

    We only need to support the architectures and operating systems that the ecosystem runs on so we
    check a bit differently. We just don't want all these dependencies in the source tree. We have:

    -- 32 64 bit intel linux | freebsd | openbsd
    --    64 bit intel osx
    -- 32 64 bit intel windows mingw
    --    64 bit windows msvc
    --    64 bit arm msvc
    -- 32 64 bit arm (rpi etc)
    --    64 bit arm darwin

*/

# if PTRDIFF_MAX == 65535
#   define ffi_size_t_type ffi_uint16_type
# elif PTRDIFF_MAX == 2147483647
#   define ffi_size_t_type ffi_uint32_type
# elif PTRDIFF_MAX == 9223372036854775807
#   define ffi_size_t_type ffi_uint64_type
# elif defined(_WIN64)
#   define ffi_size_t_type ffi_uint64_type
# else
#   define ffi_size_t_type ffi_uint32_type
# endif

/*tex This comes from the libffi.h* file: */

typedef enum ffi_abi {

# if defined (X86_WIN64)

    FFI_FIRST_ABI = 0,
    FFI_WIN64,            /* sizeof(long double) == 8  - microsoft compilers */
    FFI_GNUW64,           /* sizeof(long double) == 16 - GNU compilers */
    FFI_LAST_ABI,
# ifdef __GNUC__
    FFI_DEFAULT_ABI = FFI_GNUW64
# else
    FFI_DEFAULT_ABI = FFI_WIN64
# endif

# elif defined (X86_64) || (defined (__x86_64__) && defined (X86_DARWIN))

    FFI_FIRST_ABI = 1,
    FFI_UNIX64,
    FFI_WIN64,
    FFI_EFI64 = FFI_WIN64,
    FFI_GNUW64,
    FFI_LAST_ABI,
    FFI_DEFAULT_ABI = FFI_UNIX64

# elif defined (X86_WIN32)

    FFI_FIRST_ABI = 0,
    FFI_SYSV      = 1,
    FFI_STDCALL   = 2,
    FFI_THISCALL  = 3,
    FFI_FASTCALL  = 4,
    FFI_MS_CDECL  = 5,
    FFI_PASCAL    = 6,
    FFI_REGISTER  = 7,
    FFI_LAST_ABI,
    FFI_DEFAULT_ABI = FFI_MS_CDECL

# else

    FFI_FIRST_ABI = 0,
    FFI_SYSV      = 1,
    FFI_THISCALL  = 3,
    FFI_FASTCALL  = 4,
    FFI_STDCALL   = 5,
    FFI_PASCAL    = 6,
    FFI_REGISTER  = 7,
    FFI_MS_CDECL  = 8,
    FFI_LAST_ABI,
    FFI_DEFAULT_ABI = FFI_SYSV

#endif

} ffi_abi;

typedef enum ffi_status {
    FFI_OK,
    FFI_BAD_TYPEDEF,
    FFI_BAD_ABI
} ffi_status;

typedef struct {
    ffi_abi    abi;
    unsigned   nargs;
    ffi_type **arg_types;
    ffi_type  *rtype;
    unsigned   bytes;
    unsigned   flags;
} ffi_cif;

typedef struct foreign_state_info {

    int initialized;
    int padding;

    ffi_status (*ffi_prep_cif) (
        ffi_cif       *cif,
        ffi_abi        abi,
        unsigned int   nargs,
        ffi_type      *rtype,
        ffi_type     **atypes
    );

    void (*ffi_call) (
        ffi_cif  *cif,
        void    (*fn) (void),
        void     *rvalue,
        void    **avalue
    );

    ffi_type ffi_type_void;
    ffi_type ffi_type_uint8;
    ffi_type ffi_type_int8;
    ffi_type ffi_type_uint16;
    ffi_type ffi_type_int16;
    ffi_type ffi_type_uint32;
    ffi_type ffi_type_int32;
    ffi_type ffi_type_uint64;
    ffi_type ffi_type_int64;
    ffi_type ffi_type_float;
    ffi_type ffi_type_double;
    ffi_type ffi_type_pointer;
    ffi_type ffi_type_size_t;


} foreign_state_info;

static foreign_state_info foreign_state = {

    .initialized  = 0,
    .padding      = 0,

    .ffi_prep_cif = NULL,
    .ffi_call     = NULL,

    .ffi_type_void    = { .size = 1,                .alignment = 0, .type = ffi_void_type,    .elements = NULL },
    .ffi_type_uint8   = { .size = sizeof(uint8_t),  .alignment = 0, .type = ffi_uint8_type,   .elements = NULL },
    .ffi_type_int8    = { .size = sizeof(int8_t),   .alignment = 0, .type = ffi_int8_type,    .elements = NULL },
    .ffi_type_uint16  = { .size = sizeof(uint16_t), .alignment = 0, .type = ffi_uint16_type,  .elements = NULL },
    .ffi_type_int16   = { .size = sizeof(int16_t),  .alignment = 0, .type = ffi_int16_type,   .elements = NULL },
    .ffi_type_uint32  = { .size = sizeof(uint32_t), .alignment = 0, .type = ffi_uint32_type,  .elements = NULL },
    .ffi_type_int32   = { .size = sizeof(int32_t),  .alignment = 0, .type = ffi_int32_type,   .elements = NULL },
    .ffi_type_uint64  = { .size = sizeof(uint64_t), .alignment = 0, .type = ffi_uint64_type,  .elements = NULL },
    .ffi_type_int64   = { .size = sizeof(int64_t),  .alignment = 0, .type = ffi_int64_type,   .elements = NULL },
    .ffi_type_float   = { .size = sizeof(float),    .alignment = 0, .type = ffi_float_type,   .elements = NULL },
    .ffi_type_double  = { .size = sizeof(double),   .alignment = 0, .type = ffi_double_type,  .elements = NULL },
    .ffi_type_pointer = { .size = sizeof(void *),   .alignment = 0, .type = ffi_pointer_type, .elements = NULL },
    .ffi_type_size_t  = { .size = sizeof(size_t),   .alignment = 0, .type = ffi_size_t_type,  .elements = NULL },

};

/*tex
    We use similar names as in other modules:
*/

#define FOREIGN_METATABLE_LIBRARY  "foreign.library"
#define FOREIGN_METATABLE_FUNCTION "foreign.function"
#define FOREIGN_METATABLE_POINTER  "foreign.pointer"

/*tex
    First I had some info structure as we have elsewhere but in the end not much was needed so we
    now have some simple arrays instead.
*/

typedef enum foreign_type {
    foreign_type_void,
    foreign_type_byte,       foreign_type_char,
    foreign_type_short,      foreign_type_ushort,
    foreign_type_int,        foreign_type_uint,
    foreign_type_long,       foreign_type_ulong,
    foreign_type_longlong,   foreign_type_ulonglong,
    foreign_type_float,      foreign_type_double,
    foreign_type_size_t,
    foreign_type_string,
    foreign_type_pointer,
    foreign_type_reference_to_char,
    foreign_type_reference_to_int,
    foreign_type_reference_to_uint,
    foreign_type_reference_to_double,
    foreign_type_max,
} foreign_type;

# define foreign_first_value_return_type foreign_type_void
# define foreign_last_value_return_type  foreign_type_pointer

static const char *foreign_typenames[] = {
    "void",
    /* basic types */
    "byte",       "char",
    "short",      "ushort",
    "int",        "uint",
    "long",       "ulong",
    "longlong",   "ulonglong",
    "float",      "double",
    "size_t",
    "string",
    "pointer",
    "reference to char",
    "reference to int",
    "reference to uint",
    "reference to double",
    NULL,
};

static ffi_type *foreign_typecodes[] = {
    &foreign_state.ffi_type_void,
    &foreign_state.ffi_type_int8,    &foreign_state.ffi_type_uint8,
    &foreign_state.ffi_type_int16,   &foreign_state.ffi_type_uint16,
    &foreign_state.ffi_type_int32,   &foreign_state.ffi_type_uint32,
    &foreign_state.ffi_type_int64,   &foreign_state.ffi_type_uint64,
    &foreign_state.ffi_type_int64,   &foreign_state.ffi_type_uint64,
    &foreign_state.ffi_type_float,   &foreign_state.ffi_type_double,
    &foreign_state.ffi_type_size_t,
    &foreign_state.ffi_type_pointer, /* string */
    &foreign_state.ffi_type_pointer, /* pointer */
    &foreign_state.ffi_type_pointer,
    &foreign_state.ffi_type_pointer,
    &foreign_state.ffi_type_pointer,
    &foreign_state.ffi_type_pointer,
    NULL,
};

typedef struct foreign_library {
    void    *library;
    char    *name;
    ffi_abi  abi;
    int      padding;
} foreign_library;

typedef enum foreign_states {
    foreign_state_initialized,
    foreign_state_registered,
} foreign_states;

typedef struct foreign_function {
    foreign_library *library;
    char            *name;
    void            *function;
    foreign_type     result_type;
    int              nofarguments;
    foreign_type    *arguments;
    ffi_type        *ffi_result_type;
    ffi_type       **ffi_arguments;
    ffi_cif          cif;
    ffi_abi          abi;
} foreign_function;

typedef enum foreign_pointer_types {
    foreign_pointer_state_regular,
    foreign_pointer_state_buffer,
} foreign_pointer_types;

typedef struct foreign_pointer {
    void *ptr;
    int   state;
    int   padding;
} foreign_pointer;

/*tex
    We use the already defined helpers instead of setting up loading here. That way we're also
    consistent in lookups. You need to pass the resolved name (so at the \LUA\ end we wrap the
    loader to use the library resolver. So no check for loaders here etc.
*/


#ifdef WIN32
# ifndef WINDOWS
#  define WINDOWS
# endif
#endif

#if !defined(WINDOWS) || defined(_WIN64)
#define FFI_STDCALL FFI_DEFAULT_ABI
#endif

#ifdef __APPLE__
#define FFI_SYSV FFI_DEFAULT_ABI
#endif

typedef struct foreign_abi_entry {
    const char *name;
    ffi_abi     abi;
} foreign_abi_entry;

# define foreign_abi_max 3

static foreign_abi_entry foreign_abi_map[] = {
    { .name = "default", .abi = FFI_DEFAULT_ABI },
    { .name = "cdecl",   .abi = FFI_SYSV        },
    { .name = "stdcall", .abi = FFI_STDCALL     },
};

typedef enum foreign_library_uv_slots {
    library_name_uv      = 1,
    library_registry_uv  = 2,

} foreign_library_uv_slots;

typedef enum foreign_function_uv_slots {
    function_name_uv      = 1,
    function_finalizer_uv = 2,
} foreign_function_uv_slots;

static int foreignlib_not_yet_initialized(lua_State *L)
{
    return luaL_error(L, "foreign: not yet initialized");
}

static int foreignlib_allocation_error(lua_State *L)
{
    return luaL_error(L, "foreign: allocation error");
}

static foreign_library *foreignlib_library_check(lua_State *L, int index)
{
    return (foreign_library *) luaL_checkudata(L, index, FOREIGN_METATABLE_LIBRARY);
}

static foreign_function *foreignlib_function_check(lua_State *L, int index)
{
    return (foreign_function *) luaL_checkudata(L, index, FOREIGN_METATABLE_FUNCTION);
}

static foreign_pointer *foreignlib_pointer_check(lua_State *L, int index)
{
    return (foreign_pointer *) luaL_checkudata(L, index, FOREIGN_METATABLE_POINTER);
}

static int foreignlib_library_tostring(lua_State *L)
{
    foreign_library *library = foreignlib_library_check(L, 1);
    if (library) {
        lua_pushfstring(L, "<foreign.library %s>", library->name ? library->name : "unknown");
        return 1;
    } else {
        return 0;
    }
}

static int foreignlib_function_tostring(lua_State *L)
{
    foreign_function *function = foreignlib_function_check(L, 1);
    if (function) {
        foreign_library *library = function->library;
        if (library) {
            lua_pushfstring(L, "<foreign.function %s in library %s>", function->name ? function->name : "unknown", ((library && library->name) ? library->name : "unknown"));
            return 1;
        }
    }
    return 0;
}

static int foreignlib_pointer_tostring(lua_State *L)
{
    foreign_pointer *pointer = foreignlib_pointer_check(L, 1);
    if (! pointer) {
        return 0;
    } else {
        lua_pushfstring(L, pointer->state == foreign_pointer_state_buffer ? "<foreign.buffer %p>" : "<foreign.pointer %p>", pointer->ptr);
        return 1;
    }
}

static int foreignlib_pointer_gc(lua_State *L)
{
    foreign_pointer *pointer = foreignlib_pointer_check(L, 1);
    if (pointer->state == foreign_pointer_state_buffer) {
        lmt_memory_free(pointer->ptr);
        /* not needed: */
        pointer->state = foreign_pointer_state_regular;
        pointer->ptr = NULL;
    }
    return 0;
}

/*tex
    We accept numbers as well as names (just in case go symboloc as we do with other modules).
*/

static int foreignlib_type_found(lua_State *L, int slot, int dflt)
{
    switch (lua_type(L, slot)) {
        case LUA_TNUMBER:
            {
                int i = (int) lua_tointeger(L, slot);
                if (i >= 0 && i < foreign_type_max) {
                    return i;
                }
                break;
            }
        case LUA_TSTRING:
            {
                const char *s = lua_tostring(L, slot);
                for (int i = 0; i < foreign_type_max; i++) {
                    if (strcmp(s, foreign_typenames[i]) == 0) {
                        return i;
                    }
                }
                break;
            }
    }
    return dflt;
}

static int foreignlib_abi_found(lua_State *L, int slot, int dflt)
{
    switch (lua_type(L, slot)) {
        case LUA_TNUMBER:
            {
                int i = (int) lua_tointeger(L, slot);
                if (i >= 0 && i < foreign_abi_max) {
                    return foreign_abi_map[i].abi;
                }
                break;
            }
        case LUA_TSTRING:
            {
                const char *s = lua_tostring(L, slot);
                for (int i = 0; i < foreign_abi_max; i++) {
                    if (strcmp(s, foreign_abi_map[i].name) == 0) {
                        return foreign_abi_map[i].abi;
                    }
                }
                break;
            }
    }
    return dflt;
}

static int foreignlib_types(lua_State* L)
{
    lua_createtable(L, foreign_type_max, 0);
    for (lua_Integer i = 0; i < foreign_type_max; i++) {
        lua_pushstring(L, foreign_typenames[i]);
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

static int foreignlib_abivalues(lua_State* L)
{
    lua_createtable(L, 0, foreign_abi_max);
    for (lua_Integer i = 0; i < foreign_abi_max; i++) {
        lua_pushstring(L, foreign_abi_map[i].name);
        lua_pushinteger(L, foreign_abi_map[i].abi);
        lua_rawset(L, -3);
    }
    return 1;
}

static int foreignlib_load(lua_State *L)
{
    if (foreign_state.initialized) {
        size_t len;
        const char *libraryname = lua_tolstring(L, 1, &len);
        if (libraryname && len > 0) {
            foreign_library *library = (foreign_library *) lua_newuserdatauv(L, sizeof(foreign_library), 2);
            if (library) {
                void *libraryreference = lmt_library_open_indeed(libraryname);
                if (libraryreference) {
                    library->name = lmt_memory_malloc(sizeof(char) * (len + 1));
                    if (library->name) {
                        strcpy(library->name, libraryname);
                        library->library = libraryreference;
                        library->abi = foreignlib_abi_found(L, 2, FFI_DEFAULT_ABI);
                        lua_pushvalue(L, 1);
                        lua_setiuservalue(L, -2, library_name_uv);
                        lua_newtable(L);
                        lua_setiuservalue(L, -2, library_registry_uv);
                        luaL_getmetatable(L, FOREIGN_METATABLE_LIBRARY);
                        lua_setmetatable(L, -2);
                        return 1;
                    } else {
                        goto ALLOCATION_ERROR;
                    }
                } else {
                    return luaL_error(L, "foreign: invalid library");
                }
            } else {
                goto ALLOCATION_ERROR;
            }
        } else {
            return luaL_error(L, "foreign: invalid library name");
        }
    ALLOCATION_ERROR:
        return foreignlib_allocation_error(L);
    } else {
        return foreignlib_not_yet_initialized(L);
    }
}

static int foreignlib_library_register(lua_State *L)
{
    if (foreign_state.initialized) {
        /* 1:library 2:specification */
        foreign_library *library = foreignlib_library_check(L, 1);
        if (lua_type(L, 2) == LUA_TTABLE) {
            /* 1:library 2:specification -1:name */
            if (lua_getfield(L, 2, "name") == LUA_TSTRING) {
                /* 1:library 2:specification -2:name */
                lua_getiuservalue(L, 1, library_registry_uv);
                /* 1:library 2:specification -2:name -1:registry */
                lua_pushvalue(L, -2);
                /* 1:library 2:specification -3:name -2:registry -1:name */
                lua_rawget(L, -2);
                if (lua_type(L, -1) == LUA_TUSERDATA) {
                    /* 1:library 2:specification -3:name -2:registry -1:function */
                    return 1;
                } else {
                    /* 1:library 2:specification -3:name -2:registry -1:nil */
                    size_t len;
                    const char *functionname = lua_tolstring(L, -3, &len);
                    void *functionreference = lmt_library_find_indeed(library->library, functionname);
                    lua_pop(L, 1);
                    if (functionreference) {
                        /* 1:library 2:specification -2:name -1:registry */
                        foreign_function *function = (foreign_function *) lua_newuserdatauv(L, sizeof(foreign_function), 2);
                        if (function) {
                            /* 1:library 2:specification -3:name -2:registry -1:function */
                            lua_pushvalue(L, -3);
                            /* 1:library 2:specification -4:name -3:registry -2:function -1:name */
                            lua_pushvalue(L, -2);
                            /* 1:library 2:specification -5:name -4:registry -3:function -2:name -1:function */
                            lua_rawset(L, -4);
                            /* 1:library 2:specification -3:name -2:registry -1:function */
                            lua_pushvalue(L, -3);
                            /* 1:library 2:specification -4:name -3:registry -2:function -1:name */
                            lua_setiuservalue(L, -2, function_name_uv);
                            lua_getfield(L, 2, "finalizer");
                            /* 1:library 2:specification -4:name -3:registry -2:function -1:finalizer */
                            lua_setiuservalue(L, -2, function_finalizer_uv);
                            /* 1:library 2:specification -3:name -2:registry -1:function */
                            luaL_getmetatable(L, FOREIGN_METATABLE_FUNCTION);
                            /* 1:library 2:specification -4:name -3:registry -2:function -1:metatable */
                            lua_setmetatable(L, -2);
                            /* 1:library 2:specification -3:name -2:registry -1:function */
                            function->name = (char *) lmt_memory_malloc((size_t) len + 1);
                            if (function->name) {
                                strcpy(function->name, functionname);
                                function->function = functionreference;
                                function->library = library;
                                function->arguments = NULL;
                                function->ffi_arguments = NULL;
                                /* set the return type */
                                lua_getfield(L, 2, "result");
                                function->result_type = foreignlib_type_found(L, -1, foreign_type_void);
                                if (function->result_type >= foreign_first_value_return_type && function->result_type <= foreign_last_value_return_type) {
                                    function->ffi_result_type = foreign_typecodes[function->result_type];
                                    lua_pop(L, 1);
                                    /* set the abi (will move to library) */
                                    lua_getfield(L, 2, "abi");
                                    function->abi = foreignlib_abi_found(L, -1, library->abi);
                                    lua_pop(L, 1);
                                    /* set the argument types */
                                    switch (lua_getfield(L, 2, "arguments")) {
                                        case LUA_TTABLE:
                                            {
                                                function->nofarguments = (int) lua_rawlen(L, -1);
                                                if (function->nofarguments > 0) {
                                                    function->ffi_arguments = (ffi_type **) lmt_memory_malloc(function->nofarguments * sizeof(ffi_type *));
                                                    function->arguments = (foreign_type *) lmt_memory_malloc(function->nofarguments * sizeof(foreign_type));
                                                    if (function->ffi_arguments && function->arguments) {
                                                        for (lua_Integer i = 0; i < function->nofarguments; i++) {
                                                            lua_rawgeti(L, -1, i + 1);
                                                            function->arguments[i] = foreignlib_type_found(L, -1, foreign_type_int); /* maybe issue an error */
                                                            function->ffi_arguments[i] = foreign_typecodes[function->arguments[i]];
                                                            lua_pop(L, 1);
                                                        }
                                                    } else {
                                                        goto ALLOCATION_ERROR;
                                                    }
                                                }
                                                break;
                                            }
                                        case LUA_TSTRING:
                                            {
                                                /* Just one argument, no varag here as it's too ugly otherwise. */
                                                function->nofarguments = 1;
                                                function->ffi_arguments = (ffi_type **) lmt_memory_malloc(sizeof(ffi_type *));
                                                function->arguments = (foreign_type *) lmt_memory_malloc(sizeof(foreign_type));
                                                if (function->ffi_arguments && function->arguments) {
                                                    function->arguments[0] = foreignlib_type_found(L, -1, foreign_type_int); /* maybe issue an error */
                                                    function->ffi_arguments[0] = foreign_typecodes[function->arguments[0]];
                                                } else {
                                                    goto ALLOCATION_ERROR;
                                                }
                                                break;
                                            }
                                    }
                                    lua_pop(L, 1);
                                    if (foreign_state.ffi_prep_cif(&(function->cif), function->abi, function->nofarguments, function->ffi_result_type, function->ffi_arguments) == FFI_OK) {
                                        return 1;
                                    } else {
                                        return luaL_error(L, "foreign: error in libffi preparation");
                                    }
                                } else {
                                    return luaL_error(L, "foreign: invalid return type for function %s", functionname);
                                }
                            } else {
                                goto ALLOCATION_ERROR;
                            }
                        }
                    } else {
                        return luaL_error(L, "foreign: unknown function %s", functionname);
                    }
                }
            } else {
                return luaL_error(L, "foreign: function name expected");
            }
        } else {
            return luaL_error(L, "foreign: specification table expected");
        }
    ALLOCATION_ERROR:
        return foreignlib_allocation_error(L);
    } else {
        return foreignlib_not_yet_initialized(L);
    }
}

static int foreignlib_library_registered(lua_State *L)
{
    if (foreign_state.initialized) {
        foreign_library *library = foreignlib_library_check(L, 1);
        if (library) {
            lua_getiuservalue(L, 1, library_registry_uv);
            if (lua_type(L, 2) == LUA_TSTRING) {
                lua_pushvalue(L, 2);
                lua_rawget(L, -2);
                if (lua_type(L, -1) == LUA_TUSERDATA) {
                /* 1:library 2:name -3:registry -2:name -1:function */
                    return 1;
                } else {
                    size_t len;
                    const char *functionname = lua_tolstring(L, 2, &len);
                    return luaL_error(L, "foreign: unknown function %s", functionname);
                }
            } else {
                lua_newtable(L);
                lua_pushnil(L);
                while (lua_next(L, -3)) {
                    /* key -2 value -1 | key has to stay*/
                    lua_pushvalue(L, -2);
                    lua_rawset(L, -4);
                }
                lua_pop(L, 1);
                return 1;
            }
        }
    } else {
        return foreignlib_not_yet_initialized(L);
    }
    return 0;
}

static int foreignlib_library_available(lua_State *L)
{
    if (foreign_state.initialized) {
        foreign_library *library = foreignlib_library_check(L, 1);
        if (library && lua_type(L, 2) == LUA_TSTRING) {
            lua_getiuservalue(L, 1, library_registry_uv);
            lua_pushvalue(L, 2);
            lua_rawget(L, -2);
            lua_pushboolean(L, lua_type(L, -1) == LUA_TUSERDATA);
            return 1;
        }
    } else {
        return foreignlib_not_yet_initialized(L);
    }
    return 0;
}

 /*tex This one is adapted from the alien version (watch the way pointer arguments are returned). */

static int foreignlib_function_call(lua_State *L)
{
    int nofreturnvalues = 1; /* we always return at least nil */
    foreign_function *function = foreignlib_function_check(L, 1);
    ffi_cif *cif = &(function->cif);
    int nofarguments = lua_gettop(L) - 1;
    void **arguments = NULL;
    int luacall = 0;
    if (nofarguments != function->nofarguments) {
        return luaL_error(L, "foreign: function '%s' expects %d arguments", function->name, function->nofarguments);
    }
    lua_getiuservalue(L, 1, function_finalizer_uv);
    luacall = lua_type(L, -1) == LUA_TFUNCTION;
    if (! luacall) {
        lua_pop(L, 1);
    }
    if (nofarguments > 0) {
        arguments = lmt_memory_malloc(sizeof(void*) * nofarguments);
        if (arguments) {
            for (int i = 0; i < nofarguments; i++) {
                void *argument = NULL;
                int slot = i + 2;
                switch (function->arguments[i]) {
                    case foreign_type_byte     : argument = lmt_memory_malloc(sizeof(char));               *((char               *) argument) = (signed char)        lua_tointeger(L, slot); break;
                    case foreign_type_char     : argument = lmt_memory_malloc(sizeof(unsigned char));      *((unsigned char      *) argument) = (unsigned char)      lua_tointeger(L, slot); break;
                    case foreign_type_short    : argument = lmt_memory_malloc(sizeof(short));              *((short              *) argument) = (short)              lua_tointeger(L, slot); break;
                    case foreign_type_ushort   : argument = lmt_memory_malloc(sizeof(unsigned short));     *((unsigned short     *) argument) = (unsigned short)     lua_tointeger(L, slot); break;
                    case foreign_type_int      : argument = lmt_memory_malloc(sizeof(int));                *((int                *) argument) = (int)                lua_tointeger(L, slot); break;
                    case foreign_type_uint     : argument = lmt_memory_malloc(sizeof(unsigned int));       *((unsigned int       *) argument) = (unsigned int)       lua_tointeger(L, slot); break;
                    case foreign_type_long     : argument = lmt_memory_malloc(sizeof(long));               *((long               *) argument) = (long)               lua_tointeger(L, slot); break;
                    case foreign_type_ulong    : argument = lmt_memory_malloc(sizeof(unsigned long));      *((unsigned long      *) argument) = (unsigned long)      lua_tointeger(L, slot); break;
                    case foreign_type_longlong : argument = lmt_memory_malloc(sizeof(long long));          *((long long          *) argument) = (long long)          lua_tointeger(L, slot); break;
                    case foreign_type_ulonglong: argument = lmt_memory_malloc(sizeof(unsigned long long)); *((unsigned long long *) argument) = (unsigned long long) lua_tointeger(L, slot); break;
                    case foreign_type_float    : argument = lmt_memory_malloc(sizeof(float));              *((float              *) argument) = (float)              lua_tonumber (L, slot); break;
                    case foreign_type_double   : argument = lmt_memory_malloc(sizeof(double));             *((double             *) argument) = (double)             lua_tonumber (L, slot); break;
                    case foreign_type_size_t   : argument = lmt_memory_malloc(sizeof(size_t));             *((size_t             *) argument) = (size_t)             lua_tointeger(L, slot); break;
                    case foreign_type_string   :
                        {
                            argument = lmt_memory_malloc(sizeof(char*));
                            if (argument) {
                                *((const char**) argument) = lua_type(L, slot) == LUA_TSTRING ? lua_tostring(L, slot) : NULL;
                                break;
                            } else {
                                return foreignlib_allocation_error(L);
                            }
                        }
                    case foreign_type_pointer   :
                        {
                            /* why not just use the pointers */
                            argument = lmt_memory_malloc(sizeof(char*));
                            if (argument) {
                                switch (lua_type(L, slot)) {
                                    case LUA_TSTRING:
                                        {
                                            /*tex A packed 5.4 string. */
                                            *((const char **) argument) = lua_tostring(L, slot);
                                            break;
                                        }
                                    case LUA_TUSERDATA:
                                        {
                                            /*tex A constructed array or so. */
                                            foreign_pointer *pointer = foreignlib_pointer_check(L, slot);
                                            *((void **) argument) = pointer ? pointer->ptr : NULL;
                                            break;
                                        }
                                    default:
                                        {
                                            *((void **) argument) = NULL;
                                            break;
                                        }
                                }
                                break;
                            } else {
                                return foreignlib_allocation_error(L);
                            }
                        }
                    case foreign_type_reference_to_char:
                        {
                            argument = lmt_memory_malloc(sizeof(char *));
                            if (argument) {
                                *((char **) argument) = lmt_memory_malloc(sizeof(char));
                                **((char **) argument) = (char) lua_tointeger(L, slot);
                                nofreturnvalues++;
                                break;
                            } else {
                                return foreignlib_allocation_error(L);
                            }
                        }
                    case foreign_type_reference_to_int:
                        {
                            argument = lmt_memory_malloc(sizeof(int *));
                            if (argument) {
                                *((int **) argument) = lmt_memory_malloc(sizeof(int));
                                **((int **) argument) = (int) lua_tointeger(L, slot);
                                nofreturnvalues++;
                                break;
                            } else {
                                return foreignlib_allocation_error(L);
                            }
                        }
                    case foreign_type_reference_to_uint:
                        {
                            argument = lmt_memory_malloc(sizeof(unsigned int *));
                            if (argument) {
                                *((unsigned int **) argument) = lmt_memory_malloc(sizeof(unsigned int));
                                **((unsigned int **) argument) = (unsigned int) lua_tointeger(L, slot);
                                nofreturnvalues++;
                                break;
                            } else {
                                return foreignlib_allocation_error(L);
                            }
                        }
                    case foreign_type_reference_to_double:
                        {
                            argument = lmt_memory_malloc(sizeof(double *));
                            if (argument) {
                                *((double **) argument) = lmt_memory_malloc(sizeof(double));
                                **((double **) argument) = (double) lua_tonumber(L, slot);
                                nofreturnvalues++;
                                break;
                            } else {
                                return foreignlib_allocation_error(L);
                            }
                        }
                    default:
                        return luaL_error(L, "foreign: invalid parameter %d for '%s')", function->arguments[i], function->name);
                }
                arguments[i] = argument;
            }
        } else {
            return foreignlib_allocation_error(L);
        }
    }
    switch (function->result_type) {
        case foreign_type_void     : {                       foreign_state.ffi_call(cif, function->function, NULL, arguments); lua_pushnil    (L);                       break; }
        case foreign_type_byte     : { int                r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushinteger(L, (signed char)      r); break; }
        case foreign_type_char     : { int                r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushinteger(L, (unsigned char)    r); break; }
        case foreign_type_short    : { int                r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushinteger(L, (short)            r); break; }
        case foreign_type_ushort   : { int                r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushinteger(L, (unsigned short)   r); break; }
        case foreign_type_int      : { int                r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushinteger(L, (int)              r); break; }
        case foreign_type_uint     : { int                r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushinteger(L, (unsigned int)     r); break; }
        case foreign_type_long     : { long               r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushinteger(L, (long)             r); break; }
        case foreign_type_ulong    : { unsigned long      r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushinteger(L, (unsigned long)    r); break; }
        case foreign_type_longlong : { long long          r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushinteger(L, (lua_Integer)      r); break; }
        case foreign_type_ulonglong: { unsigned long long r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushinteger(L, (lua_Integer)      r); break; }
        case foreign_type_float    : { float              r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushnumber (L, (lua_Number)       r); break; }
        case foreign_type_double   : { double             r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushnumber (L,                    r); break; }
        case foreign_type_size_t   : { size_t             r; foreign_state.ffi_call(cif, function->function, &r,   arguments); lua_pushinteger(L,                    r); break; }
        case foreign_type_string   :
            {
                void *str = NULL;
                foreign_state.ffi_call(cif, function->function, &str, arguments);
                if (str) {
                    lua_pushstring(L, (char *) str);
                } else {
                    lua_pushnil(L);
                }
                break;
            }
        case foreign_type_pointer  :
            {
                void *ptr = NULL;
                foreign_state.ffi_call(cif, function->function, &ptr, arguments);
                if (ptr) {
                    foreign_pointer *pointer = (foreign_pointer *) lua_newuserdatauv(L, sizeof(foreign_pointer), 0);
                    luaL_getmetatable(L, FOREIGN_METATABLE_POINTER);
                    lua_setmetatable(L, -2);
                    pointer->ptr = ptr;
                    pointer->state = foreign_pointer_state_regular;
                } else {
                    lua_pushnil(L);
                }
                break;
            }
        default:
            return luaL_error(L, "foreign: invalid return value %d for '%s')", function->result_type, function->name);
    }
    for (int i = 0; i < nofarguments; i++) {
        switch (function->arguments[i]) {
            case foreign_type_reference_to_char  : lua_pushinteger(L, **(char         **) arguments[i]); break;
            case foreign_type_reference_to_int   : lua_pushinteger(L, **(int          **) arguments[i]); break;
            case foreign_type_reference_to_uint  : lua_pushinteger(L, **(unsigned int **) arguments[i]); break;
            case foreign_type_reference_to_double: lua_pushnumber (L, **(double       **) arguments[i]); break;
            default: break;
        }
        lmt_memory_free(arguments[i]); /* not needed for pointers when we just use pointer */
    }
    lmt_memory_free(arguments);
    if (luacall) {
        lua_call(L, nofreturnvalues, 1);
        return 1;
    } else {
        return nofreturnvalues;
    }
}

static int foreignlib_library_gc(lua_State *L)
{
    foreign_library *library = foreignlib_library_check(L, 1);
    if (library->library) {
        lmt_library_open_indeed(library->library);
        lmt_memory_free(library->name);
    }
    return 0;
}

static int foreignlib_function_gc(lua_State *L)
{
    foreign_function *function = foreignlib_function_check(L, 1);
    lmt_memory_free(function->name);
    lmt_memory_free(function->arguments);
    lmt_memory_free(function->ffi_arguments);
    return 0;
}

/* */

static int foreignlib_newbuffer(lua_State *L)
{
    size_t size = lua_tointeger(L, 1);
    foreign_pointer *pointer = (foreign_pointer *) lua_newuserdatauv(L, sizeof(foreign_pointer), 0);
    luaL_getmetatable(L, FOREIGN_METATABLE_POINTER);
    lua_setmetatable(L, -2);
    pointer->ptr = lmt_memory_malloc(size);
    pointer->state = foreign_pointer_state_buffer;
    return 1;
}

static int foreignlib_getbuffer(lua_State *L)
{
    foreign_pointer *pointer = foreignlib_pointer_check(L, 1);
    if (pointer && pointer->state == foreign_pointer_state_buffer && pointer->ptr) {
        size_t size = lua_tointeger(L, 2);
        if (size > 0) {
            lua_pushlstring(L, pointer->ptr, size);
        } else {
            lua_pushnil(L);
        }
        lmt_memory_free(pointer->ptr);
        pointer->ptr = NULL;
        pointer->state = foreign_pointer_state_regular;
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/* pointer to array of pointers */

static int foreignlib_totable(lua_State *L)
{
    foreign_pointer *pointer = foreignlib_pointer_check(L, 1);
    if (pointer) {
        void *ptr = pointer->ptr;
        if (ptr) {
            int resulttype = foreignlib_type_found(L, 2, foreign_type_void);
            int size = (int) luaL_optinteger(L, 3, -1);
            lua_createtable(L, size > 0 ? size : 0, 0);
            switch (resulttype) {
                case foreign_type_void:
                    return 0;
                case foreign_type_string:
                    {
                        void **ptr = pointer->ptr;
                        if (ptr) {
                            lua_Integer r = 0;
                            lua_newtable(L);
                            if (size < 0) {
                                while (ptr[r]) {
                                    lua_pushstring(L, ptr[r]);
                                    lua_rawseti(L, -2, ++r);
                                }
                            } else {
                                for (lua_Integer i = 0; i < size; i++) {
                                    lua_pushstring(L, ptr[i]);
                                    lua_rawseti(L, -2, ++r);
                                }
                            }
                        }
                        break;
                    }
                case foreign_type_byte     : { signed char        *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushinteger(L, (lua_Integer) p[i]); lua_rawseti(L, -2, i + 1); } break; }
                case foreign_type_char     : { unsigned char      *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushinteger(L, (lua_Integer) p[i]); lua_rawseti(L, -2, i + 1); } break; }
                case foreign_type_short    : { short              *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushinteger(L, (lua_Integer) p[i]); lua_rawseti(L, -2, i + 1); } break; }
                case foreign_type_ushort   : { unsigned short     *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushinteger(L, (lua_Integer) p[i]); lua_rawseti(L, -2, i + 1); } break; }
                case foreign_type_int      : { int                *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushinteger(L, (lua_Integer) p[i]); lua_rawseti(L, -2, i + 1); } break; }
                case foreign_type_uint     : { unsigned int       *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushinteger(L, (lua_Integer) p[i]); lua_rawseti(L, -2, i + 1); } break; }
                case foreign_type_long     : { long               *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushinteger(L, (lua_Integer) p[i]); lua_rawseti(L, -2, i + 1); } break; }
                case foreign_type_ulong    : { unsigned long      *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushinteger(L, (lua_Integer) p[i]); lua_rawseti(L, -2, i + 1); } break; }
                case foreign_type_longlong : { long long          *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushinteger(L, (lua_Integer) p[i]); lua_rawseti(L, -2, i + 1); } break; }
                case foreign_type_ulonglong: { unsigned long long *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushinteger(L, (lua_Integer) p[i]); lua_rawseti(L, -2, i + 1); } break; }
                case foreign_type_float    : { float              *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushnumber (L, (lua_Number)  p[i]); lua_rawseti(L, -2, i + 1); } break; }
                case foreign_type_double   : { double             *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushnumber (L, (lua_Number)  p[i]); lua_rawseti(L, -2, i + 1); } break; }
                case foreign_type_size_t   : { size_t             *p = ptr; for (lua_Integer i = 0; i < size; i++) { lua_pushinteger(L, (lua_Integer) p[i]); lua_rawseti(L, -2, i + 1); } break; }
            }
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

/*tex

    Here we prepare some metatables. Todo: newindex. When we don't use a metatable for the
    library we can have more keys, like list and so.

    local library = foreign.load("whatever","abi")

    library:register   { name = ..., result = ..., arguments = { ... }, abi = ...  )
    library:registered ("name")
    library:registered ()
    library:available  ("name")

    foreign.load()
    foreign.abivalues()
    foreign.types()

    todo: ckeck what this abi does: probably better at lib loading time than per function

*/

static struct luaL_Reg foreignlib_function_methods[] = {
    { "register",   foreignlib_library_register   },
    { "registered", foreignlib_library_registered },
    { "available",  foreignlib_library_available  },
    { NULL,         NULL                          },
};

static void foreignlib_populate(lua_State *L)
{
    luaL_newmetatable(L, FOREIGN_METATABLE_LIBRARY);
    lua_pushliteral(L, "__gc");
    lua_pushcfunction(L, foreignlib_library_gc);
    lua_settable(L, -3);
    lua_pushliteral(L, "__tostring");
    lua_pushcfunction(L, foreignlib_library_tostring);
    lua_settable(L, -3);
    lua_pushliteral(L, "__index");
    lua_newtable(L);
    for (int i = 0; foreignlib_function_methods[i].name; i++) {
        lua_pushstring(L, foreignlib_function_methods[i].name);
        lua_pushcfunction(L, foreignlib_function_methods[i].func);
        lua_settable(L, -3);
    }
    lua_settable(L, -3);
    lua_pop(L, 1);

    luaL_newmetatable(L, FOREIGN_METATABLE_FUNCTION);
    lua_pushliteral(L, "__gc");
    lua_pushcfunction(L, foreignlib_function_gc);
    lua_settable(L, -3);
    lua_pushliteral(L, "__tostring");
    lua_pushcfunction(L, foreignlib_function_tostring);
    lua_settable(L, -3);
    lua_pushliteral(L, "__call");
    lua_pushcfunction(L, foreignlib_function_call);
    lua_settable(L, -3);
    lua_pop(L, 1);

    luaL_newmetatable(L, FOREIGN_METATABLE_POINTER);
    lua_pushliteral(L, "__gc");
    lua_pushcfunction(L, foreignlib_pointer_gc);
    lua_settable(L, -3);
    lua_pushliteral(L, "__tostring");
    lua_pushcfunction(L, foreignlib_pointer_tostring);
    lua_settable(L, -3);
}

/*tex
    Finally it all somes together in the initializer. We expect the caller to handle the lookup
    of |libffi| which can have different names per operating system.
*/

static int foreignlib_initialize(lua_State * L)
{
    if (! foreign_state.initialized) {
        if (lmt_engine_state.permit_loadlib) {
            /*tex Just an experiment. */
            const char *filename = lua_tostring(L, 1); /* libffi */
            if (filename) {

                lmt_library lib = lmt_library_load(filename);

                foreign_state.ffi_prep_cif = lmt_library_find(lib, "ffi_prep_cif");
                foreign_state.ffi_call     = lmt_library_find(lib, "ffi_call"    );

                foreign_state.initialized = lmt_library_okay(lib);
            }
            if (foreign_state.initialized) {
                foreignlib_populate(L);
            }
        } else {
            return luaL_error(L, "foreign: use --permitloadlib to enable this");
        }
    }
    lua_pushboolean(L, foreign_state.initialized);
    return 1;
}

static struct luaL_Reg foreignlib_function_list[] = {
    { "initialize", foreignlib_initialize },
    { "load",       foreignlib_load       },
    { "types",      foreignlib_types      },
    { "newbuffer",  foreignlib_newbuffer  },
    { "getbuffer",  foreignlib_getbuffer  },
    { "abivalues",  foreignlib_abivalues  }, /* mostly for diagnostics */
    { "totable",    foreignlib_totable    },
    { NULL,         NULL                  },
};

int luaopen_foreign(lua_State * L)
{
    lmt_library_register(L, "foreign", foreignlib_function_list);
    return 0;
}
