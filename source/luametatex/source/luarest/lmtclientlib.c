/*
    See license.txt in the root of this project.
*/

# include <luametatex.h>

/*tex

    When you search a bit you find plenty templates for downloading something. When we started with
    \LUIATEX\ we decided to add |luasocket| and in \LUAMETATEX\ we have the optional curl support
    library. However, because it looks like we can just assume that curl is available on \LINUX\
    and \OSX\ and that the generic \MSWINDOWS\ interface will be around as long as this operating
    system is there. Although \CURL\ is nowadays installed on \MSWINDOWS\ we cannot assume the
    library to be there.

    So, after investigating this a bit I settled for two code paths, something we need to have
    anyway due to the wide filenames. We already had helpers for that so we could save some code
    here. The first implementation was rather simple, apart from all these flags \unknown\ not
    something you like to waste time on figuring them out.

    This module is still kind of simple because we only need to fetch and delegate all other logic
    to the \LUA\ end where we already have all in place anyway. The curl code path is a variant of
    what we already had in the optional |lmtcurl| file but limited to |http(s)| usage.

    After we had all in place a bit of checking with gemini about a potential speedup by writing
    directly to the lua buffer (no intermediate buffer in the windows code path and larger socket
    buffers) as well as checking the content length and preallocating the buffer at the start
    gave a better saturation of the (1GB) connection I tested with. Before that, the socket
    library performed better, after that code below won.

    By adding the |supported| method we can fallback to other methods (when available) but the
    assumption is that on posix systems we have libcurl installed. This module might evolve a bit
    depending on usage. Because we no longer need |ftp|, |mail| and other features we might at
    some point drop |luasocket| or come up with a simpler server option.

*/

/* tex

    We need to occasionally check if the methods used here are still valid. It looks like the
    api's has been stable for quite a while so we're probably good, but flags can evolve. Checking
    is typically something that tools can help with because there isn't something spectacular
    going on here. Of course we might want to improve performance. The reason why we pass so many
    arguments to |clientlib_aux_http_request| is that we want to use the \LUA\ buffer mechanism
    efficiently.

    I decided to add th eoption to limit the size but it can be configured. After checking
    with gemini (flash) and codex (luna) a few safeguards were added, like wiping forwarded
    headers and such and makign sure we only handle http(s). There is plenty on the web about all
    this stuff but \unknown\ how to find it and these are common coding patterns.

    Because this is just some auxiliary module and no core engine functionality we can improve
    matters over time. It doesn't impact how \LUAMETATEX\ and \CONTEXT\ work, apart from maybe
    installation and occasional inclusion of images from the web or a server.

*/

# define default_timeout_connect    60
# define default_timeout_receive     0
# define default_maxsize          (512 * 1024 * 1024)

typedef struct {
    const char  *url;
    const char  *method;
    const char **headers;
    size_t       length;
    const char  *body;
    long         timeout;
    size_t       maxsize;
    int          tolerant;
} http_request_data;

static inline void clientlib_aux_preset(http_request_data *data)
{
    data->url      = NULL;
    data->method   = "GET";
    data->headers  = NULL;
    data->length   = 0;
    data->body     = NULL;
    data->timeout  = default_timeout_receive;
    data->maxsize  = default_maxsize;
    data->tolerant = 0;
}

static inline void clientlib_aux_reset(http_request_data *data)
{
    lmt_memory_free(data->headers);
}

# if _WIN32

    # include <stdint.h>
    # include <windows.h>
    # include <winhttp.h>

    /*tex After checking this redirect callback was recommended: */

    typedef struct {
        LPCWSTR      host;
        DWORD        scheme;
        DWORD        port;
        const char **headers;
    } winhttp_redirect_ctx;

    static void CALLBACK WinHttpRedirectCallback(
        HINTERNET hInternet,
        DWORD_PTR dwContext,
        DWORD     dwInternetStatus,
        LPVOID    lpvStatusInformation,
        DWORD     dwStatusInformationLength
    )
    {
        (void) dwStatusInformationLength;
        if (dwInternetStatus == WINHTTP_CALLBACK_STATUS_REDIRECT) {
            LPCWSTR redirect_url = (LPCWSTR) lpvStatusInformation;
            winhttp_redirect_ctx *ctx = (winhttp_redirect_ctx *) dwContext;

            URL_COMPONENTS target_comp;
            memset(&target_comp, 0, sizeof(target_comp));
            target_comp.dwStructSize     = sizeof(target_comp);
            target_comp.dwHostNameLength = (DWORD) -1;

            if (WinHttpCrackUrl(redirect_url, 0, 0, &target_comp)) {
                if (ctx && ctx->host && (
                        (DWORD) target_comp.nScheme != ctx->scheme ||
                        (DWORD) target_comp.nPort   != ctx->port ||
                        target_comp.dwHostNameLength != wcslen(ctx->host) ||
                        _wcsnicmp(target_comp.lpszHostName, ctx->host, target_comp.dwHostNameLength) != 0))
                {
                    // strip default sensitive headers
                    WinHttpAddRequestHeaders(hInternet, L"Authorization:", (DWORD) -1, WINHTTP_ADDREQ_FLAG_REPLACE);
                    WinHttpAddRequestHeaders(hInternet, L"Cookie:", (DWORD) -1, WINHTTP_ADDREQ_FLAG_REPLACE);
                    // strip all user-defined custom headers
                    if (ctx->headers) {
                        for (int i = 0; ctx->headers[i] != NULL; i++) {
                            const char *hdr = ctx->headers[i];
                            const char *colon = strchr(hdr, ':');
                            size_t name_len = colon ? (size_t) (colon - hdr) : strlen(hdr);
                            if (name_len > 0) {
                                if (name_len <= SIZE_MAX - 2) {
                                    char *buf = (char *) lmt_memory_malloc(name_len + 2);
                                    if (buf) {
                                        memcpy(buf, hdr, name_len);
                                        buf[name_len]     = ':';
                                        buf[name_len + 1] = '\0';
                                        LPWSTR wname = aux_utf8_to_wide(buf);
                                        if (wname) {
                                            WinHttpAddRequestHeaders(hInternet, wname, (DWORD) -1, WINHTTP_ADDREQ_FLAG_REPLACE);
                                            lmt_memory_free(wname);
                                        }
                                        lmt_memory_free(buf);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    static int clientlib_aux_http_request(
        http_request_data  *data,
        luaL_Buffer        *b,
        int                *status_code,
        char              **errormessage
    )
    {
        LPWSTR wurl    = aux_utf8_to_wide(data->url);
        LPWSTR wmethod = aux_utf8_to_wide(data->method);

        URL_COMPONENTS components;

        memset(&components, 0, sizeof(components));

        components.dwStructSize      = sizeof(components);
        components.dwHostNameLength  = (DWORD) -1;
        components.dwUrlPathLength   = (DWORD) -1;
        components.dwExtraInfoLength = (DWORD) -1;
        components.dwSchemeLength    = (DWORD) -1;

        if (! WinHttpCrackUrl(wurl, 0, 0, &components)) {
            *errormessage = lmt_memory_strdup("invalid url");
            lmt_memory_free(wurl);
            lmt_memory_free(wmethod);
            return 0;
        }

     // if (components.nScheme != INTERNET_SCHEME_HTTP && components.nScheme != INTERNET_SCHEME_HTTPS) {
     //     *errormessage = lmt_memory_strdup("only http and https protocols are allowed");
     //     lmt_memory_free(wurl);
     //     lmt_memory_free(wmethod);
     //     return 0;
     // }

        DWORD host_len = components.dwHostNameLength;
        WCHAR *host = (WCHAR *) lmt_memory_malloc((host_len + 1) * sizeof(WCHAR));
        if (! host) {
            *errormessage = lmt_memory_strdup("out of memory for host");
            lmt_memory_free(wurl);
            lmt_memory_free(wmethod);
            return 0;
        }
        wcsncpy(host, components.lpszHostName, host_len);
        host[host_len] = L'\0';

        DWORD path_len = components.dwUrlPathLength + components.dwExtraInfoLength;
        WCHAR *path = (WCHAR *) lmt_memory_malloc((path_len + 1) * sizeof(WCHAR));
        if (! path) {
            *errormessage = lmt_memory_strdup("out of memory for path");
            lmt_memory_free(host);
            lmt_memory_free(wurl);
            lmt_memory_free(wmethod);
            return 0;
        }

        if (components.lpszUrlPath && path_len > 0) {
            wcsncpy(path, components.lpszUrlPath, path_len);
            path[path_len] = L'\0';
        } else {
            path[0] = L'\0';
        }

        HINTERNET session    = WinHttpOpen(L"LMTHTTP/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
        HINTERNET connection = session ? WinHttpConnect(session, host, components.nPort, 0) : NULL;

        DWORD     flags      = (components.nScheme == INTERNET_SCHEME_HTTPS) ? WINHTTP_FLAG_SECURE : 0;
        HINTERNET request    = connection ? WinHttpOpenRequest(connection, wmethod, path, NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, flags) : NULL;

        int       success    = 0;

        if (! request) {
            *errormessage = lmt_memory_strdup("http(s) connection failed");
            if (connection) {
                WinHttpCloseHandle(connection);
            }
            if (session) {
                WinHttpCloseHandle(session);
            }
            lmt_memory_free(host);
            lmt_memory_free(path);
            lmt_memory_free(wurl);
            lmt_memory_free(wmethod);
            return 0;
        }

        if (data->tolerant) {
            DWORD security_flags = SECURITY_FLAG_IGNORE_UNKNOWN_CA
                                 | SECURITY_FLAG_IGNORE_CERT_CN_INVALID
                                 | SECURITY_FLAG_IGNORE_CERT_DATE_INVALID
                                 | SECURITY_FLAG_IGNORE_CERT_WRONG_USAGE;
            WinHttpSetOption(
                request,
                WINHTTP_OPTION_SECURITY_FLAGS,
                &security_flags,
                sizeof(security_flags)
            );
        }

        if (data->headers) {
            for (int i = 0; data->headers[i] != NULL; i++) {
                LPWSTR wheader = aux_utf8_to_wide(data->headers[i]);
                WinHttpAddRequestHeaders(request, wheader, (DWORD) -1, WINHTTP_ADDREQ_FLAG_ADD | WINHTTP_ADDREQ_FLAG_REPLACE);
                lmt_memory_free(wheader);
            }
        }

        winhttp_redirect_ctx redirect_ctx = {
            .host    = host,
            .scheme  = (DWORD) components.nScheme,
            .port    = (DWORD) components.nPort,
            .headers = data->headers
        };

        DWORD_PTR redirect_context = (DWORD_PTR) &redirect_ctx;
        if (! WinHttpSetOption(
                request,
                WINHTTP_OPTION_CONTEXT_VALUE,
                &redirect_context,
                sizeof(redirect_context)))
        {
            *errormessage = lmt_memory_strdup("http(s) redirect context setup failed");
            goto winhttp_cleanup;
        }

        if (WinHttpSetStatusCallback(
            request,
            WinHttpRedirectCallback,
            WINHTTP_CALLBACK_FLAG_REDIRECT,
            0
        ) == WINHTTP_INVALID_STATUS_CALLBACK) {
            *errormessage = lmt_memory_strdup("https(s) redirect callback setup failed");
            goto winhttp_cleanup;
        }

        if (data->timeout > 0) {
            if (data->timeout > (long) (INT_MAX / 1000) || ! WinHttpSetTimeouts(
                    request,                        // times ln ms:
                    1000 * default_timeout_connect, // resolveTimeout
                    1000 * default_timeout_connect, // connectTimeout
                    1000 * default_timeout_connect, // sendTimeout
                    1000 * data->timeout            // receiveTimeout
                ))
            {
                *errormessage = lmt_memory_strdup("https(s) timeout setup failed");
                goto winhttp_cleanup;
            }
        }

        if (data->length > (size_t) ((DWORD) -1)) {
            *errormessage = lmt_memory_strdup("https(s) request body is too large");
            goto winhttp_cleanup;
        }

        if (WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS, 0, (LPVOID) (uintptr_t) data->body, (DWORD) data->length, (DWORD) data->length, 0)) {
            if (! WinHttpReceiveResponse(request, NULL)) {
                *errormessage = lmt_memory_strdup("https(s) receive response failed");
            } else {
                DWORD status     = 0;
                DWORD statussize = sizeof(status);

                WinHttpQueryHeaders(
                    request,
                    WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                    WINHTTP_HEADER_NAME_BY_INDEX,
                    &status,
                    &statussize,
                    WINHTTP_NO_HEADER_INDEX
                );

                *status_code = (int) status;

                DWORD  available  = 0;
                DWORD  downloaded = 0;
                size_t totalread  = 0;
                int    read_ok    = 1;

                DWORD content_length = 0;
                DWORD cl_size        = sizeof(content_length);
                if (WinHttpQueryHeaders(
                        request,
                        WINHTTP_QUERY_CONTENT_LENGTH | WINHTTP_QUERY_FLAG_NUMBER,
                        WINHTTP_HEADER_NAME_BY_INDEX,
                        &content_length,
                        &cl_size,
                        WINHTTP_NO_HEADER_INDEX)
                ) {
                    if (content_length > data->maxsize) {
                        read_ok = 0;
                        *errormessage = lmt_memory_strdup("content length exceeded size limit");
                    } else {
                        luaL_prepbuffsize(b, content_length);
                    }
                }

                while (read_ok) {
                    if (! WinHttpQueryDataAvailable(request, &available)) {
                        *errormessage = lmt_memory_strdup("https(s) query data available failed");
                        read_ok = 0;
                        break;
                    }
                    if (available == 0) {
                        break; /* end of response */
                    }
                    if (totalread > data->maxsize || (size_t) available > data->maxsize - totalread) {
                        *errormessage = lmt_memory_strdup("response body exceeded size limit");
                        read_ok = 0;
                        break;
                    }
                    char *dest = luaL_prepbuffsize(b, available);
                    if (! WinHttpReadData(request, dest, available, &downloaded) || downloaded == 0) {
                        *errormessage = lmt_memory_strdup("https(s) read data failed");
                        read_ok = 0;
                        break;
                    }
                    luaL_addsize(b, downloaded);
                    totalread += downloaded;
                }
                if (read_ok) {
                    success = 1;
                }
            }
        } else {
            *errormessage = lmt_memory_strdup("https(s) request failed");
        }

      winhttp_cleanup:
        WinHttpCloseHandle(request);
        WinHttpCloseHandle(connection);
        WinHttpCloseHandle(session);
        lmt_memory_free(host);
        lmt_memory_free(path);
        lmt_memory_free(wurl);
        lmt_memory_free(wmethod);
        return success;
    }

    static int clientlib_aux_supported(void)
    {
        return 1;
    }

# else

    # include <dlfcn.h>
    # include <strings.h>

    typedef void*       (*fn_curl_easy_init)      (void);
    typedef void        (*fn_curl_easy_cleanup)   (void*);
    typedef int         (*fn_curl_easy_perform)   (void*);
    typedef int         (*fn_curl_easy_setopt)    (void*, int, ...);
    typedef int         (*fn_curl_easy_getinfo)   (void*, int, ...);
    typedef const char* (*fn_curl_easy_strerror)  (int);
    typedef void*       (*fn_curl_slist_append)   (void*, const char*);
    typedef void        (*fn_curl_slist_free_all) (void*);

    static void                  *curl_handle         = NULL;
    static int                    curl_loaded         = -1; /* not yet checked */

    static fn_curl_easy_init      curl_easy_init      = NULL;
    static fn_curl_easy_cleanup   curl_easy_cleanup   = NULL;
    static fn_curl_easy_perform   curl_easy_perform   = NULL;
    static fn_curl_easy_setopt    curl_easy_setopt    = NULL;
    static fn_curl_easy_getinfo   curl_easy_getinfo   = NULL;
    static fn_curl_easy_strerror  curl_easy_strerror  = NULL;
    static fn_curl_slist_append   curl_slist_append   = NULL;
    static fn_curl_slist_free_all curl_slist_free_all = NULL;

    /*tex The complete list is in the |lmtcurl.c| file. */

    # define curl_option_writedata            1
    # define curl_option_url                  2
    # define curl_option_readdata             9
    # define curl_option_writefunction       11
    # define curl_option_timeout             13
    # define curl_option_postfields          15
    # define curl_option_httpheader          23
    # define curl_option_headerdata          29
    # define curl_option_customrequest       36
    # define curl_option_header              42
    # define curl_option_post                47
    # define curl_option_followlocation      52
    # define curl_option_postfieldsize       60
    # define curl_option_ssl_verifypeer      64
    # define curl_option_maxredirs           68
    # define curl_option_connecttimeout      78
    # define curl_option_headerfunction      79
    # define curl_option_httpget             80
    # define curl_option_ssl_verifyhost      81
    # define curl_option_buffersize          98
    # define curl_option_nosignal            99
    # define curl_option_protocols          181
    # define curl_option_redir_protocols    182

    # define curl_proto_http              (1L << 0)
    # define curl_proto_https             (1L << 1)

    # define curl_integer_base                0 /* long */
    # define curl_string_base             10000
    # define curl_object_base             10000
    # define curl_function_base           20000
    # define curl_offset_base             30000
    # define curl_blob_base               40000

    # define curl_info_long            0x200000
    # define curl_info_double          0x300000

    # define curl_responsecode                2
    # define curl_content_length_download    15

    /*tex Because we know we're on \UNIX\ we can do this: */

    static void *clientlib_aux_load_curl_library(void)
    {
        static const char *names[] = {
            "libcurl.so.4",
            "libcurl.so",
            "libcurl.4.dylib",
            "libcurl.dylib",
            NULL
        };
        for (int i = 0; names[i]; i++) {
            void *handle = dlopen(names[i], RTLD_LAZY | RTLD_GLOBAL);
            if (handle) {
                return handle;
            }
        }
        return NULL;
    }

    static int clientlib_aux_curl_loaded(void)
    {
        if (curl_loaded >= 0) {
            return curl_loaded;
        }
        curl_handle = clientlib_aux_load_curl_library();
        if (curl_handle) {
            curl_easy_init      = (fn_curl_easy_init)      dlsym(curl_handle, "curl_easy_init");
            curl_easy_cleanup   = (fn_curl_easy_cleanup)   dlsym(curl_handle, "curl_easy_cleanup");
            curl_easy_perform   = (fn_curl_easy_perform)   dlsym(curl_handle, "curl_easy_perform");
            curl_easy_setopt    = (fn_curl_easy_setopt)    dlsym(curl_handle, "curl_easy_setopt");
            curl_easy_getinfo   = (fn_curl_easy_getinfo)   dlsym(curl_handle, "curl_easy_getinfo");
            curl_easy_strerror  = (fn_curl_easy_strerror)  dlsym(curl_handle, "curl_easy_strerror");
            curl_slist_append   = (fn_curl_slist_append)   dlsym(curl_handle, "curl_slist_append");
            curl_slist_free_all = (fn_curl_slist_free_all) dlsym(curl_handle, "curl_slist_free_all");
            if (   ! curl_easy_init    || ! curl_easy_cleanup || ! curl_easy_setopt
                || ! curl_easy_perform || ! curl_easy_getinfo || ! curl_easy_strerror
                || ! curl_slist_append || ! curl_slist_free_all) {
                dlclose(curl_handle);
                curl_handle = NULL;
            }
        }
        curl_loaded = curl_handle != NULL;
        return curl_loaded;
    }

    typedef struct {
        luaL_Buffer *buffer;
        size_t       maxsize;
        size_t       bytesread;
        int          exceeded;
    } curl_stream_context;

    static size_t write_callback(
        void   *buffer,
        size_t  size,
        size_t  nitems,
        void   *userdata
    )
    {
        size_t total = size * nitems;
        curl_stream_context *ctx = (curl_stream_context *) userdata;
        if (ctx->bytesread > ctx->maxsize || total > ctx->maxsize - ctx->bytesread) {
            ctx->exceeded = 1;
            return 0; /* Returning 0 causes libcurl to abort with CURLE_WRITE_ERROR */
        } else {
            luaL_addlstring(ctx->buffer, (const char*) buffer, total);
            ctx->bytesread += total;
            return total;
        }
    }

    static int parse_content_length(const char *data, size_t length, size_t *value)
    {
        size_t i      = 0;
        size_t result = 0;
        while (i < length && (data[i] == ' ' || data[i] == '\t')) {
            i++;
        }
        if (i == length || data[i] < '0' || data[i] > '9') {
            return 0;
        }
        while (i < length && data[i] >= '0' && data[i] <= '9') {
            size_t digit = (size_t) (data[i] - '0');
            if (result > (SIZE_MAX - digit) / 10) {
                return 0;
            }
            result = result * 10 + digit;
            i++;
        }
        while (i < length && (data[i] == ' ' || data[i] == '\t' || data[i] == '\r' || data[i] == '\n')) {
            i++;
        }
        if (i != length) {
            return 0;
        }
        *value = result;
        return 1;
    }

    static size_t header_callback(
        char   *buffer,
        size_t  size,
        size_t  nitems,
        void   *userdata
    )
    {
        size_t total = size * nitems;
        curl_stream_context *ctx = (curl_stream_context *) userdata;
        if (total > 15 && strncasecmp(buffer, "Content-Length:", 15) == 0) {
            size_t val_len = total - 15;
            size_t len = 0;
            if (parse_content_length(buffer + 15, val_len, &len)) {
                if (len > ctx->maxsize) {
                    ctx->exceeded = 1;
                    return 0; /* Abort request on header processing */
                } else if (len > 0) {
                    luaL_prepbuffsize(ctx->buffer, len);
                }
            }
        }
        return total;
    }

    static int clientlib_aux_http_request(
        http_request_data  *data,
        luaL_Buffer        *buffer,
        int                *status_code,
        char              **errormessage
    )
    {
        if (! clientlib_aux_curl_loaded()) {
            *errormessage = lmt_memory_strdup("libcurl is not available on this system");
            return 0;
        }

        void *curl = curl_easy_init();
        if (! curl) {
            *errormessage = lmt_memory_strdup("initializing dynamic curl failed");
            return 0;
        }

        void *slist = NULL;
        if (data->headers) {
            for (int i = 0; data->headers[i] != NULL; i++) {
                void *next = curl_slist_append(slist, data->headers[i]);
                if (! next) {
                    *errormessage = lmt_memory_strdup("adding https(s) request header failed");
                    if (slist) {
                        curl_slist_free_all(slist);
                    }
                    curl_easy_cleanup(curl);
                    return 0;
                }
                slist = next;
            }
        }

        curl_stream_context ctx = {
            .buffer    = buffer,
            .maxsize   = data->maxsize,
            .bytesread = 0,
            .exceeded  = 0
        };

        int code = 0;

        # define curl_setopt_checked(...) \
            do { \
                if (curl_easy_setopt(__VA_ARGS__) != 0) { \
                    *errormessage = lmt_memory_strdup("configuring libcurl failed"); \
                    goto curl_cleanup; \
                } \
            } while (0)

        curl_setopt_checked(curl, curl_integer_base + curl_option_nosignal, 1L);
        curl_setopt_checked(curl, curl_integer_base + curl_option_protocols, (long) (curl_proto_http | curl_proto_https));
        curl_setopt_checked(curl, curl_integer_base + curl_option_redir_protocols, (long) (curl_proto_http | curl_proto_https));
        curl_setopt_checked(curl, curl_integer_base + curl_option_followlocation, 1L);
        curl_setopt_checked(curl, curl_integer_base + curl_option_maxredirs, 10L); /* plenty */

        if (data->timeout > 0) {
            curl_setopt_checked(curl, curl_integer_base + curl_option_connecttimeout, (long) default_timeout_connect);
            curl_setopt_checked(curl, curl_integer_base + curl_option_timeout, data->timeout);
        }

        curl_setopt_checked(curl, curl_string_base + curl_option_url, (const void*) data->url);

        if (strcasecmp(data->method, "GET") == 0) {
            curl_setopt_checked(curl, curl_integer_base + curl_option_httpget, 1L);
        } else if (strcasecmp(data->method, "POST") == 0) {
            curl_setopt_checked(curl, curl_integer_base + curl_option_post, 1L);
        } else {
            curl_setopt_checked(curl, curl_string_base + curl_option_customrequest, (const void*) data->method);
        }

        if (slist) {
            curl_setopt_checked(curl, curl_object_base + curl_option_httpheader, (const void*) slist);
        }

        if (data->body && data->length > 0) {
            if (data->length > (size_t) LONG_MAX) {
                *errormessage = lmt_memory_strdup("https(s) request body is too large");
                goto curl_cleanup;
            }
            curl_setopt_checked(curl, curl_string_base + curl_option_postfields, (const void*) data->body);
            curl_setopt_checked(curl, curl_integer_base + curl_option_postfieldsize, (long) data->length);
        }

        if (data->tolerant) {
            curl_setopt_checked(curl, curl_integer_base + curl_option_ssl_verifypeer, 0L);
            curl_setopt_checked(curl, curl_integer_base + curl_option_ssl_verifyhost, 0L);
        }

        curl_setopt_checked(curl, curl_function_base + curl_option_headerfunction, header_callback);
        curl_setopt_checked(curl, curl_object_base + curl_option_headerdata, (const void*) &ctx);

        curl_setopt_checked(curl, curl_function_base + curl_option_writefunction, write_callback);
        curl_setopt_checked(curl, curl_object_base + curl_option_writedata, (const void*) &ctx);

        curl_setopt_checked(curl, curl_integer_base + curl_option_buffersize, 1024L * 1024L);
        curl_setopt_checked(curl, curl_integer_base + curl_option_header, 0L);

        code = curl_easy_perform(curl);
        if (code == 0) {
            long status = 0;
            if (curl_easy_getinfo(curl, curl_info_long + curl_responsecode, &status) != 0) {
                *errormessage = lmt_memory_strdup("getting https(s) response status failed");
                code = 1;
            } else {
                *status_code = (int) status;
            }
        } else if (ctx.exceeded) {
            *errormessage = lmt_memory_strdup("response body exceeded size limit");
        } else {
            *errormessage = lmt_memory_strdup(curl_easy_strerror(code));
        }

        # undef curl_setopt_checked

      curl_cleanup:

        if (slist) {
            curl_slist_free_all(slist);
        }
        curl_easy_cleanup(curl);
        return (code == 0 && *errormessage == NULL);
    }

    static int clientlib_aux_supported(void)
    {
        return clientlib_aux_curl_loaded();
    }

# endif

/*tex

    Currently this is what goes in and out. Often just an \URL\ is enough which is why
    it comes first while checking the boolean is easy too.

    \starttabulate[|l|l|]
      \NC url      \EQ string  (mandate)                  \NC \NR
      \NC method   \EQ string  (optional, default: GET)   \NC \NR
      \NC headers  \EQ table   (optional)                 \NC \NR
      \NC body     \EQ string  (optional)                 \NC \NR
      \NC timeout  \EQ number  (optional, default: 0)     \NC \NR
      \NC maxsize  \EQ number  (optional, default: 512MB) \NC \NR
      \NC tolerant \EQ boolean (optional, default: false) \NC \NR
      \HL
      \NC result   \EQ integer + string \NC \NR
      \NC error    \EQ false   + string \NC \NR
    \stoptabulate

    When |tolerant| is |true| an \HTTPS\ request will not fail on an expired certificate,
    something that can make sense when we have an installer that gets from an okay site
    where keeping certifiates up-to-date can be a bit a pain.

*/

/*tex
    When we want to be more efficient we can use keys and/ur userdata with defaults
    but for now we are okay.
*/

/*tex
    Watch out: these string have to live till we return from the caller!
*/

static const char** lmt_tostrings(lua_State *L, int index)
{
    if (lua_istable(L, index)) {
        size_t len = lua_rawlen(L, index);
        const char **list = (const char**) lmt_memory_calloc(len + 1, sizeof(char*));
        for (size_t i = 1; i <= len; i++) {
            lua_rawgeti(L, index, i);
            list[i - 1] = lua_tostring(L, -1);
            lua_pop(L, 1);
        }
        return list;
    } else {
        return NULL;
    }
}

# if defined(_WIN32) || defined(_MSC_VER)
    # include <string.h>
    # define strcasecmp  _stricmp
    # define strncasecmp _strnicmp
# else
    # include <strings.h>
# endif

static int clientlib_httprequest(lua_State *L)
{
    http_request_data data;
    clientlib_aux_preset(&data);

    if (lua_type(L, 1) == LUA_TTABLE) {
        if (lua_getfield(L, 1, "url")      == LUA_TSTRING)  { data.url      = lua_tostring (L, -1); } lua_pop(L, 1);
        if (lua_getfield(L, 1, "method")   == LUA_TSTRING)  { data.method   = lua_tostring (L, -1); } lua_pop(L, 1);
        if (lua_getfield(L, 1, "body")     == LUA_TSTRING)  { data.body     = lua_tolstring(L, -1, &data.length); } lua_pop(L, 1);
        if (lua_getfield(L, 1, "timeout")  == LUA_TNUMBER)  { data.timeout  = lmt_toulong  (L, -1); } lua_pop(L, 1);
        if (lua_getfield(L, 1, "maxsize")  == LUA_TNUMBER)  { data.maxsize  = lmt_tosizet  (L, -1); } lua_pop(L, 1);
        if (lua_getfield(L, 1, "tolerant") == LUA_TBOOLEAN) { data.tolerant = lua_toboolean(L, -1); } lua_pop(L, 1);
        if (lua_getfield(L, 1, "headers")  == LUA_TTABLE)   { data.headers  = lmt_tostrings(L, -1); } lua_pop(L, 1);
    } else {
        data.url      = luaL_checkstring(L, 1);
        /* We keep this for now. */
        data.method   = luaL_optstring  (L, 2, data.method);
        data.headers  = lmt_tostrings   (L, 3);
        data.body     = lua_tolstring   (L, 4, &data.length);
        data.timeout  = lmt_optulong    (L, 5, data.timeout);
        data.maxsize  = lmt_optsizet    (L, 6, data.maxsize);
        data.tolerant = lua_toboolean   (L, 7);
    }
    if (data.timeout < 0) {
        data.timeout = 0;
    }

    if (strncasecmp(data.url, "http://", 7) != 0 && strncasecmp(data.url, "https://", 8) != 0) {

        lua_pushboolean(L, 0);
        lua_pushstring(L, "only http and https protocols are allowed");

    } else if (! lmt_valid_target(L, security_client, data.url, security_http_request)) {

        lua_pushboolean(L, 0);
        lua_pushstring(L, "the http(s) request is blocked");

    } else {

        luaL_Buffer buffer;
        luaL_buffinit(L, &buffer);

        int   status       = 0;
        char *errormessage = NULL;

        int success = clientlib_aux_http_request(
            &data, &buffer, &status, &errormessage
        );

        if (! success || errormessage) {
            lua_pushboolean(L, 0);
            lua_pushstring(L, errormessage ? errormessage : "the http(s) request failed");
            lmt_memory_free(errormessage);
        } else {
            /*tex
                We need to finish the buffer first, and as that can involve pushing stuff on the stack
                we need to keep the order right. Which in turn means pushing the status after that is
                done and then move it up (swap places).
            */
            luaL_pushresult(&buffer);
            lua_pushinteger(L, status);
            lua_insert(L, -2);
        }
    }

    clientlib_aux_reset(&data);
    return 2;
}

static int clientlib_supported(lua_State *L)
{
    lua_pushboolean(L, clientlib_aux_supported());
    return 1;
}

static const struct luaL_Reg clientlib_function_list[] = {
    { "httprequest", clientlib_httprequest },
    { "supported",   clientlib_supported   },
    { NULL,          NULL                  },
};

int luaopen_client(lua_State *L)
{
    luaL_newlib(L, clientlib_function_list);
    return 1;
}
