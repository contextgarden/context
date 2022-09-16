/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"
# include "lmtoptional.h"

typedef void* curl_instance ;
typedef int   curl_return_code ;
typedef int   curl_error_code ;

typedef enum curl_option_type {
    curl_ignore   = 0,
    curl_integer  = 1,
    curl_string   = 2,
    curl_function = 3, /* ignored */
    curl_offset   = 4, /* ignored */
} curl_option_type;

/*tex At the \LUA\ end we can have a mapping of useful ones, */

static const int curl_options[] = {
    curl_ignore,    /*   0 */
    curl_string,    /*   1 file | writedata */
    curl_string,    /*   2 url */
    curl_integer,   /*   3 port */
    curl_string,    /*   4 proxy */
    curl_string,    /*   5 userpwd */
    curl_string,    /*   6 proxyuserpwd */
    curl_string,    /*   7 range */
    curl_ignore,    /*   8 */
    curl_string,    /*   9 infile | readdata */
    curl_string,    /*  10 errorbuffer */
    curl_function,  /*  11 writefunction */
    curl_function,  /*  12 readfunction */
    curl_integer,   /*  13 timeout */
    curl_integer,   /*  14 infilesize */
    curl_string,    /*  15 postfields */
    curl_string,    /*  16 referer */
    curl_string,    /*  17 ftpport */
    curl_string,    /*  18 useragent */
    curl_integer,   /*  19 low_speed_limit */
    curl_integer,   /*  20 low_speed_time */
    curl_integer,   /*  21 resume_from */
    curl_string,    /*  22 cookie */
    curl_string,    /*  23 httpheader | rtspheader */
    curl_string,    /*  24 httppost */
    curl_string,    /*  25 sslcert */
    curl_string,    /*  26 keypasswd */
    curl_integer,   /*  27 crlf */
    curl_string,    /*  28 quote */
    curl_string,    /*  29 writeheader | headerdata */
    curl_ignore,    /*  30 */
    curl_string,    /*  31 cookiefile */
    curl_integer,   /*  32 sslversion */
    curl_integer,   /*  33 timecondition */
    curl_integer,   /*  34 timevalue */
    curl_ignore,    /*  35 */
    curl_string,    /*  36 customrequest */
    curl_string,    /*  37 stderr */
    curl_ignore,    /*  38 */
    curl_string,    /*  39 postquote */
    curl_string,    /*  40 writeinfo */
    curl_integer,   /*  41 verbose */
    curl_integer,   /*  42 header */
    curl_integer,   /*  43 noprogress */
    curl_integer,   /*  44 nobody */
    curl_integer,   /*  45 failonerror */
    curl_integer,   /*  46 upload */
    curl_integer,   /*  47 post */
    curl_integer,   /*  48 dirlistonly */
    curl_ignore,    /*  49 */
    curl_integer,   /*  50 append */
    curl_integer,   /*  51 netrc */
    curl_integer,   /*  52 followlocation */
    curl_integer,   /*  53 transfertext */
    curl_integer,   /*  54 put */
    curl_ignore,    /*  55 */
    curl_function,  /*  56 progressfunction */
    curl_string,    /*  57 xferinfodata | progressdata */
    curl_integer,   /*  58 autoreferer */
    curl_integer,   /*  59 proxyport */
    curl_integer,   /*  60 postfieldsize */
    curl_integer,   /*  61 httpproxytunnel */
    curl_string,    /*  62 interface */
    curl_string,    /*  63 krblevel */
    curl_integer,   /*  64 ssl_verifypeer */
    curl_string,    /*  65 cainfo */
    curl_ignore,    /*  66 */
    curl_ignore,    /*  67 */
    curl_integer,   /*  68 maxredirs */
    curl_integer,   /*  69 filetime */
    curl_string,    /*  70 telnetoptions */
    curl_integer,   /*  71 maxconnects */
    curl_integer,   /*  72 closepolicy */
    curl_ignore,    /*  73 */
    curl_integer,   /*  74 fresh_connect */
    curl_integer,   /*  75 forbid_reuse */
    curl_string,    /*  76 random_file */
    curl_string,    /*  77 egdsocket */
    curl_integer,   /*  78 connecttimeout */
    curl_function,  /*  79 headerfunction */
    curl_integer,   /*  80 httpget */
    curl_integer,   /*  81 ssl_verifyhost */
    curl_string,    /*  82 cookiejar */
    curl_string,    /*  83 ssl_cipher_list */
    curl_integer,   /*  84 http_version */
    curl_integer,   /*  85 ftp_use_epsv */
    curl_string,    /*  86 sslcerttype */
    curl_string,    /*  87 sslkey */
    curl_string,    /*  88 sslkeytype */
    curl_string,    /*  89 sslengine */
    curl_integer,   /*  90 sslengine_default */
    curl_integer,   /*  91 dns_use_global_cache */
    curl_integer,   /*  92 dns_cache_timeout */
    curl_string,    /*  93 prequote */
    curl_function,  /*  94 debugfunction */
    curl_string,    /*  95 debugdata */
    curl_integer,   /*  96 cookiesession */
    curl_string,    /*  97 capath */
    curl_integer,   /*  98 buffersize */
    curl_integer,   /*  99 nosignal */
    curl_string,    /* 100 share */
    curl_integer,   /* 101 proxytype */
    curl_string,    /* 102 accept_encoding */
    curl_string,    /* 103 private */
    curl_string,    /* 104 http200aliases */
    curl_integer,   /* 105 unrestricted_auth */
    curl_integer,   /* 106 ftp_use_eprt */
    curl_integer,   /* 107 httpauth */
    curl_function,  /* 108 ssl_ctx_function */
    curl_string,    /* 109 ssl_ctx_data */
    curl_integer,   /* 110 ftp_create_missing_dirs */
    curl_integer,   /* 111 proxyauth */
    curl_integer,   /* 112 server_response_timeout | ftp_response_timeout */
    curl_integer,   /* 113 ipresolve */
    curl_integer,   /* 114 maxfilesize */
    curl_offset,    /* 115 infilesize_large */
    curl_offset,    /* 116 resume_from_large */
    curl_offset,    /* 117 maxfilesize_large */
    curl_string,    /* 118 netrc_file */
    curl_integer,   /* 119 use_ssl */
    curl_offset,    /* 120 postfieldsize_large */
    curl_integer,   /* 121 tcp_nodelay */
    curl_ignore,    /* 122 */
    curl_ignore,    /* 123 */
    curl_ignore,    /* 124 */
    curl_ignore,    /* 125 */
    curl_ignore,    /* 126 */
    curl_ignore,    /* 127 */
    curl_ignore,    /* 128 */
    curl_integer,   /* 129 ftpsslauth */
    curl_function,  /* 130 ioctlfunction */
    curl_string,    /* 131 ioctldata */
    curl_ignore,    /* 132 */
    curl_ignore,    /* 133 */
    curl_string,    /* 134 ftp_account */
    curl_string,    /* 135 cookielist */
    curl_integer,   /* 136 ignore_content_length */
    curl_integer,   /* 137 ftp_skip_pasv_ip */
    curl_integer,   /* 138 ftp_filemethod */
    curl_integer,   /* 139 localport */
    curl_integer,   /* 140 localportrange */
    curl_integer,   /* 141 connect_only */
    curl_function,  /* 142 conv_from_network_function */
    curl_function,  /* 143 conv_to_network_function */
    curl_function,  /* 144 conv_from_utf8_function */
    curl_offset,    /* 145 max_send_speed_large */
    curl_offset,    /* 146 max_recv_speed_large */
    curl_string,    /* 147 ftp_alternative_to_user */
    curl_function,  /* 148 sockoptfunction */
    curl_string,    /* 149 sockoptdata */
    curl_integer,   /* 150 ssl_sessionid_cache */
    curl_integer,   /* 151 ssh_auth_types */
    curl_string,    /* 152 ssh_public_keyfile */
    curl_string,    /* 153 ssh_private_keyfile */
    curl_integer,   /* 154 ftp_ssl_ccc */
    curl_integer,   /* 155 timeout_ms */
    curl_integer,   /* 156 connecttimeout_ms */
    curl_integer,   /* 157 http_transfer_decoding */
    curl_integer,   /* 158 http_content_decoding */
    curl_integer,   /* 159 new_file_perms */
    curl_integer,   /* 160 new_directory_perms */
    curl_integer,   /* 161 postredir */
    curl_string,    /* 162 ssh_host_public_key_md5 */
    curl_function,  /* 163 opensocketfunction */
    curl_string,    /* 164 opensocketdata */
    curl_string,    /* 165 copypostfields */
    curl_integer,   /* 166 proxy_transfer_mode */
    curl_function,  /* 167 seekfunction */
    curl_string,    /* 168 seekdata */
    curl_string,    /* 169 crlfile */
    curl_string,    /* 170 issuercert */
    curl_integer,   /* 171 address_scope */
    curl_integer,   /* 172 certinfo */
    curl_string,    /* 173 username */
    curl_string,    /* 174 password */
    curl_string,    /* 175 proxyusername */
    curl_string,    /* 176 proxypassword */
    curl_string,    /* 177 noproxy */
    curl_integer,   /* 178 tftp_blksize */
    curl_string,    /* 179 socks5_gssapi_service */
    curl_integer,   /* 180 socks5_gssapi_nec */
    curl_integer,   /* 181 protocols */
    curl_integer,   /* 182 redir_protocols */
    curl_string,    /* 183 ssh_knownhosts */
    curl_function,  /* 184 ssh_keyfunction */
    curl_string,    /* 185 ssh_keydata */
    curl_string,    /* 186 mail_from */
    curl_string,    /* 187 mail_rcpt */
    curl_integer,   /* 188 ftp_use_pret */
    curl_integer,   /* 189 rtsp_request */
    curl_string,    /* 190 rtsp_session_id */
    curl_string,    /* 191 rtsp_stream_uri */
    curl_string,    /* 192 rtsp_transport */
    curl_integer,   /* 193 rtsp_client_cseq */
    curl_integer,   /* 194 rtsp_server_cseq */
    curl_string,    /* 195 interleavedata */
    curl_function,  /* 196 interleavefunction */
    curl_integer,   /* 197 wildcardmatch */
    curl_function,  /* 198 chunk_bgn_function */
    curl_function,  /* 199 chunk_end_function */
    curl_function,  /* 200 fnmatch_function */
    curl_string,    /* 201 chunk_data */
    curl_string,    /* 202 fnmatch_data */
    curl_string,    /* 203 resolve */
    curl_string,    /* 204 tlsauth_username */
    curl_string,    /* 205 tlsauth_password */
    curl_string,    /* 206 tlsauth_type */
    curl_integer,   /* 207 transfer_encoding */
    curl_function,  /* 208 closesocketfunction */
    curl_string,    /* 209 closesocketdata */
    curl_integer,   /* 210 gssapi_delegation */
    curl_string,    /* 211 dns_servers */
    curl_integer,   /* 212 accepttimeout_ms */
    curl_integer,   /* 213 tcp_keepalive */
    curl_integer,   /* 214 tcp_keepidle */
    curl_integer,   /* 215 tcp_keepintvl */
    curl_integer,   /* 216 ssl_options */
    curl_string,    /* 217 mail_auth */
    curl_integer,   /* 218 sasl_ir */
    curl_function,  /* 219 xferinfofunction */
    curl_string,    /* 220 xoauth2_bearer */
    curl_string,    /* 221 dns_interface */
    curl_string,    /* 222 dns_local_ip4 */
    curl_string,    /* 223 dns_local_ip6 */
    curl_string,    /* 224 login_options */
    curl_integer,   /* 225 ssl_enable_npn */
    curl_integer,   /* 226 ssl_enable_alpn */
    curl_integer    /* 227 expect_100_timeout_ms */
};

# define curl_option_min             1
# define curl_option_max           227
# define curl_option_writedata       1
# define curl_option_url             2
# define curl_option_writefunction  11

# define curl_integer_base       0 /* long */
# define curl_string_base    10000
# define curl_object_base    10000
# define curl_function_base  20000
# define curl_offset_base    30000
# define curl_offset_blob    40000

typedef size_t (*curl_write_callback) (
    char   *buffer,
    size_t  size,
    size_t  nitems,
    void   *userdata
);

typedef struct curllib_state_info {

    int initialized;
    int padding;

    char * (*curl_version) (
        void
    );

    void (*curl_free) (
        void* p
    );

    curl_instance (*curl_easy_init) (
        void
    );

    void (*curl_easy_cleanup) (
        curl_instance handle
    );

    curl_return_code (*curl_easy_perform) (
        curl_instance handle
    );

    curl_return_code (*curl_easy_setopt) (
        curl_instance handle,
        int           option,
        ...
    );

    char* (*curl_easy_escape) (
        curl_instance  handle,
        const char    *url,
        int            length
    );

    char* (*curl_easy_unescape) (
        curl_instance  handle,
        const char    *url,
        int            length,
        int           *outlength
    );

    const char* (*curl_easy_strerror) (
        curl_error_code errcode
    );

} curllib_state_info;

static curllib_state_info curllib_state = {

    .initialized        = 0,
    .padding            = 0,

    .curl_version       = NULL,
    .curl_free          = NULL,
    .curl_easy_init     = NULL,
    .curl_easy_cleanup  = NULL,
    .curl_easy_perform  = NULL,
    .curl_easy_setopt   = NULL,
    .curl_easy_escape   = NULL,
    .curl_easy_unescape = NULL,
    .curl_easy_strerror = NULL,

};

static int curllib_initialize(lua_State * L)
{
    if (! curllib_state.initialized) {
        const char *filename = lua_tostring(L, 1);
        if (filename) {

            lmt_library lib = lmt_library_load(filename);

            curllib_state.curl_version       = lmt_library_find(lib, "curl_version");
            curllib_state.curl_free          = lmt_library_find(lib, "curl_free");
            curllib_state.curl_easy_init     = lmt_library_find(lib, "curl_easy_init");
            curllib_state.curl_easy_cleanup  = lmt_library_find(lib, "curl_easy_cleanup");
            curllib_state.curl_easy_perform  = lmt_library_find(lib, "curl_easy_perform");
            curllib_state.curl_easy_setopt   = lmt_library_find(lib, "curl_easy_setopt");
            curllib_state.curl_easy_escape   = lmt_library_find(lib, "curl_easy_escape");
            curllib_state.curl_easy_unescape = lmt_library_find(lib, "curl_easy_unescape");
            curllib_state.curl_easy_strerror = lmt_library_find(lib, "curl_easy_strerror");

            curllib_state.initialized = lmt_library_okay(lib);
        }
    }
    lua_pushboolean(L, curllib_state.initialized);
    return 1;
}

/* fetch(url, { options }) | fetch({ options }) */

/* we don't need threads so we can just use the local init */

static size_t curllib_write_cb(char *data, size_t n, size_t l, void *b)
{
    luaL_addlstring((luaL_Buffer *) b, data, n * l);
    return n * l;
}

/*tex
    Always assume a table as we need to sanitize keys anyway. A former variant also accepted strings
    but why have more code than needed.
*/

static int curllib_fetch(lua_State * L)
{
    if (curllib_state.initialized) {
        if (lua_type(L,1) == LUA_TTABLE) {
            curl_instance *curl = curllib_state.curl_easy_init();
            if (curl)  {
                luaL_Buffer buffer;
                luaL_buffinit(L, &buffer);
                curllib_state.curl_easy_setopt(curl, curl_object_base + curl_option_writedata, &buffer);
                curllib_state.curl_easy_setopt(curl, curl_function_base + curl_option_writefunction, &curllib_write_cb);
                lua_pushnil(L);  /* first key */
                while (lua_next(L, 1) != 0) {
                    if (lua_type(L, -2) == LUA_TNUMBER) {
                        int o = lmt_tointeger(L, -2);
                        if (o >= curl_option_min && o <= curl_option_max) {
                            switch (curl_options[o]) {
                                case curl_string:
                                    if (lua_type(L, -1) == LUA_TSTRING) {
                                        curllib_state.curl_easy_setopt(curl, curl_string_base + o, lua_tostring(L, -1));
                                    } else {
                                     // return luaL_error(L, "curl option %d must be a string", o);
                                    }
                                    break;
                                case curl_integer:
                                    switch (lua_type(L, -1)) {
                                        case LUA_TNUMBER:
                                            curllib_state.curl_easy_setopt(curl, curl_integer_base + o, lua_tointeger(L, -1));
                                            break;
                                        case LUA_TBOOLEAN:
                                            curllib_state.curl_easy_setopt(curl, curl_integer_base + o, lua_toboolean(L, -1));
                                            break;
                                        default:
                                         // return luaL_error(L, "curl option %d must be a number of boolean", o);
                                            break;
                                    }
                                    break;
                            }
                        } else {
                         // return luaL_error(L, "curl option %d is invalid", o);
                        }
                    } else {
                     // return luaL_error(L, "curl option id should en a number");
                    }
                    lua_pop(L, 1); /* removes 'value' and keeps 'key' for next iteration */
                }
                int result = curllib_state.curl_easy_perform(curl);
                if (result) {
                    lua_pushboolean(L, 0);
                    lua_pushstring(L, curllib_state.curl_easy_strerror(result));
                    result = 2;
                } else {
                    luaL_pushresult(&buffer);
                    result = 1;
                }
                curllib_state.curl_easy_cleanup(curl);
                return result;
            }
        }
    }
    return 0;
}

static int curllib_escape(lua_State * L)
{
    if (curllib_state.initialized) {
        curl_instance *curl = curllib_state.curl_easy_init();
        if (curl) {
            size_t length = 0;
            const char * url = lua_tolstring(L, 1, &length);
            char *s = curllib_state.curl_easy_escape(curl, url, (int) length);
            if (s) {
                lua_pushstring(L,(const char *) s);
                curllib_state.curl_free(s);
                curllib_state.curl_easy_cleanup(curl);
                return 1;
            }
        }
    }
    return 0;
}

static int curllib_unescape(lua_State * L)
{
    if (curllib_state.initialized) {
        curl_instance *curl = curllib_state.curl_easy_init();
        if (curl) {
            size_t length = 0;
            const char *url = lua_tolstring(L, 1, &length);
            int l = 0;
            char *s = curllib_state.curl_easy_unescape(curl, url, (int) length, &l);
            if (s) {
                lua_pushlstring(L, s, l);
                curllib_state.curl_free(s);
                curllib_state.curl_easy_cleanup(curl);
                return 1;
            }
        }
    }
    return 0;
}

static int curllib_getversion(lua_State * L)
{
    if (curllib_state.initialized) {
        char *version = curllib_state.curl_version();
        if (version) {
            lua_pushstring(L, version);
            return 1;
        }
    }
    return 0;
}

static struct luaL_Reg curllib_function_list[] = {
    { "initialize", curllib_initialize },
    { "fetch",      curllib_fetch      },
    { "escape",     curllib_escape     },
    { "unescape",   curllib_unescape   },
    { "getversion", curllib_getversion },
    { NULL,         NULL               },
};

int luaopen_curl(lua_State * L)
{
    lmt_library_register(L, "curl", curllib_function_list);
    return 0;
}
