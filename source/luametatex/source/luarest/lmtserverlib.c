/*
    See license.txt in the root of this project.
*/

# include <luametatex.h>
/*tex

    One of the first decisions we (Taco & Hans) made when we started with \LUATEX\ is to also
    let it act as a \LUA\ interpreter. That would permits is to steer away from the \RUBY\ and
    \PERL\ depencies (runners, scripts). In the end we saw other macro packages (etc) also use
    \LUATEX\ as interpreter. We've come far from packagers and distributers complaints that
    \quotation {It's bad that \CONTEXT\ uses a  script to manage multipeas runs.} indeed.

    However, it makes little sense to have a full blown server in the engine but there are
    some arguments for a simple one and they come from how we used the engien as server.

    - We have a lot of libraries on board and like to use them. In a self contained ecosystem
      like \CONTEXT\ we don't want users to depend on external tools. Support for sockets is
      something that can provided by a library but then one needs to compile it.

    - Applications are simple, for instance we have a help server and that one just serves a
      single user on a local machine. The response is simple and can be generated fast. Blocking
      is not really an issue (unless a client does).

    - We have straightforward services behind a proxy where the service handles for instance an
      interface and orchestrates a product run, but large downloads are delegated to the proxy
      so they don't block.

    So, we don't need to support various protocols, deal with many client atthe same time, recover
    from tricky situations. We've run services like these for very long periods of time on the
    engine in \LUA\ mode without problems.

    So from these experiences we came to the following solution, which for now is an experiment
    only. It's also something that is not meant to compete with what is out there, just something
    I need myself and in the perspective of the \CONTEXT\ ecosystem.

    The basics one can finds everywhere in the Internet (or just look in the luasocket sources)
    and once these are in place one stepwise adds to it. Asking e.g. Gemini for platform specific
    solutions and http specifics is handy, after all these technologies evolved.

    We can go very simple and let the \LUA\ end construct the whole response but even then we need
    to catch errors. Some instead we return a table and do some work here.

    Because we want to add features (and actually did in the process) we pass a tabel to the server
    startup function.

    .status     : integer
    .mime       : string
    .body       : string
    .statistics : boolean        (add statistics table to reply)
    .trace      : boolean        (enable lua error reporting)
    .headers    : string | table
    .timeout    : integer        (client timeout)
    .report     : function       (ConTeXt reporter callback)
    .step       : function       (called at the end of the loop)
    .delay      : select delay   (handy for step)

    A client request triggers a callback that also gets a table:

    .method  : string
    .path    : string
    .body    : string
    .ip      : string
    .headers : table

    The code below started with little but stepwise was extended to suit our needs, which is a
    simple, robust and performant servlet without adding to much code to the engine and lots of
    wrapper code in \LUA. It's a compromise.

    There are a few platform dependencies so that's what the Internet is for: figuring out how to
    deal with those. Maintaining this is not too hard because nowadays one can consult various tools
    to check and report issues. The main logic and interfaces are just regular \LUA.

    Just for the record: if we don't include (the stripped down) luasocket library we safe some 50K
    or 1% on the engine binary which is just noise, but we also get a smaller mtxrun.lmt file, as
    well as a smaller format file (although we delay loading). It anyway removes a dependency (we
    just can't keep track of how external libraries change over time) and we can make usage a bit
    cleaner.

*/

# ifdef _WIN32

    # include <winsock2.h>
    # include <ws2tcpip.h>
    # include <time.h>

    typedef SOCKET socket_t;

    # define close_socket(s)   closesocket(s)
    # define invalid_socket(s) ((s) == INVALID_SOCKET)
    # define would_block       (WSAGetLastError() == WSAEWOULDBLOCK)
    # define send_flags        0

    # define strncasecmp       _strnicmp

    static inline int set_nonblocking(socket_t fd)
    {
        u_long mode = 1;
        return ioctlsocket(fd, FIONBIO, &mode) == 0;
    }

# else

    # include <sys/socket.h>
    # include <netinet/in.h>
    # include <arpa/inet.h>
    # include <unistd.h>
    # include <fcntl.h>
    # include <errno.h>
    # include <time.h>
    # include <strings.h>

    typedef int socket_t;

    # define close_socket(s)   close(s)
    # define invalid_socket(s) ((s) < 0)
    # define would_block       (errno == EAGAIN || errno == EWOULDBLOCK)

    # ifdef MSG_NOSIGNAL
        # define send_flags MSG_NOSIGNAL
    # else
        # define send_flags 0
    # endif

    static inline int set_nonblocking(socket_t fd)
    {
        int flags = fcntl(fd, F_GETFL, 0);
        return (flags != -1) && (fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0);
    }

# endif

static inline void serverlib_aux_set_no_sigpipe(socket_t fd)
{
# ifdef SO_NOSIGPIPE
    int option = 1;
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &option, sizeof(option));
# else
    (void) fd;
# endif
}

/*

    We maintain a double linked list of connections (clients) that are in two states: reading or
    writing. We also decided to add a way to get statistics. Because the server itself is blocking,
    we don't need a server record and userdata.

*/

# define default_timeout 60
# define default_delay    1

typedef struct server_statistics {
    time_t start_time;
    size_t total_requests;
    size_t total_errors;
    size_t bytes_read;
    size_t bytes_written;
    size_t active_clients;
    size_t max_nofclients;
    size_t timedout_clients;
    size_t client_timeout;
} server_statistics;

typedef enum {
    client_state_reading = 0,
    client_state_writing = 1,
} client_states;

typedef struct client {
    socket_t    fd;                  /* aka |filedescriptor|, the common name for this */
    char        peer_ip[INET_ADDRSTRLEN];
    char        read_buffer[65536];  /* if we even need more we can have some dynamic fallback */
    size_t      read_bytes;
    const char *write_buffer;        /* pointer to Lua string data (no copy needed) */
    size_t      write_length;
    size_t      write_position;
    int         write_reference;     /* registry reference to anchor Lua string |write_buffer| */
    int         state;
    time_t      last_time;
    struct      client *prev;
    struct      client *next;
} client;

/* We have a more extensive list of messages (and mimes) at the \LUA\ end. */

static inline const char *serverlib_aux_status_to_string(int status)
{
    switch (status) {
        case 200: return "OK";
        case 201: return "Created";
        case 204: return "No Content";
        case 400: return "Bad Request";
        case 401: return "Unauthorized";
        case 403: return "Forbidden";
        case 404: return "Not Found";
        case 413: return "Request Entity Too Large";
        case 500: return "Internal Error";
        default:  return "OK";
    }
}

static int serverlib_aux_get_content_length(
    const char *buffer,
    size_t      header_len,
    size_t     *content_length
)
{
    const char *ptr = buffer;
    const char *end = buffer + header_len;
    int         first_line = 1;
    int         found      = 0;

    *content_length = 0;

    while (ptr < end) {
        const char *line_end = strstr(ptr, "\r\n");
        if (! line_end || line_end > end) {
            break;
        }
        if (! first_line && (size_t) (line_end - ptr) >= 15 &&
            (ptr[0] == 'C' || ptr[0] == 'c') && strncasecmp(ptr, "content-length:", 15) == 0) {
            const char *value = ptr + 15;
            size_t length = 0;

            while (value < line_end && (*value == ' ' || *value == '\t')) {
                value++;
            }
            if (value == line_end || *value < '0' || *value > '9') {
                return 0;
            }
            while (value < line_end && *value >= '0' && *value <= '9') {
                size_t digit = (size_t) (*value - '0');
                if (length > (SIZE_MAX - digit) / 10) {
                    return 0;
                }
                length = length * 10 + digit;
                value++;
            }
            while (value < line_end && (*value == ' ' || *value == '\t')) {
                value++;
            }
            if (value != line_end || (found && *content_length != length)) {
                return 0;
            }
            *content_length = length;
            found = 1;
        }
        first_line = 0;
        ptr = line_end + 2;
    }
    return 1;
}

static size_t serverlib_aux_buffer_length(int length, size_t size)
{
    if (length <= 0 || size == 0) {
        return 0;
    } else if ((size_t) length >= size) {
        return size - 1;
    } else {
        return (size_t) length;
    }
}

static void serverlib_aux_report(
    lua_State  *L,
    int         report_ref,
    const char *fmt,
    ...
)
{
    if (report_ref == LUA_NOREF || ! fmt) {
        return;
    }

    lua_rawgeti(L, LUA_REGISTRYINDEX, report_ref);
    lua_pushstring(L, fmt);
    int nargs = 1;

    /* We need to map onto our formatter and deal with the vararg. */

    va_list args;
    va_start(args, fmt);
    const char *p = fmt;
    while (*p) {
        if (*p == '%') {
            p++;
            switch (*p) {
                case 's':
                    {
                        const char *s = va_arg(args, const char *);
                        lua_pushstring(L, s ? s : "");
                        nargs++;
                        break;
                    }
                case 'i':
             /* case 'd': */
                    {
                        int i = va_arg(args, int);
                        lua_pushinteger(L, i);
                        nargs++;
                        break;
                    }
                case '\0':
                    continue; /*quits the while */
                default:
                    break;
            }
        }
        p++;
    }
    va_end(args);

    if (lua_pcall(L, nargs, 0, 0) != LUA_OK) {
        /* we just ignore errors */
        lua_pop(L, 1);
    }
}

static void serverlib_aux_client(
    client            **head,
    socket_t            fd,
    const char         *ip,
    server_statistics  *statistics
)
{
    client *c = (client*) lmt_memory_calloc(1, sizeof(client));
    if (! c) {
        close_socket(fd);
        return;
    }
    c->fd = fd;
    c->write_reference = LUA_NOREF;
    c->state = client_state_reading;
    if (ip) {
        strncpy(c->peer_ip, ip, sizeof(c->peer_ip) - 1);
    }
    c->last_time = time(NULL);
    c->next = *head;
    c->prev = NULL;
    if (*head) {
        (*head)->prev = c;
    }
    *head = c;
    if (statistics) {
        statistics->active_clients++;
        if (statistics->active_clients > statistics->max_nofclients) {
            statistics->max_nofclients = statistics->active_clients;
        }
    }
}

static void serverlib_aux_remove_client(
    lua_State          *L,
    client            **head,
    client             *target,
    server_statistics  *statistics
)
{
    if (target) {
        if (target->prev) {
            target->prev->next = target->next;
        } else {
            *head = target->next;
        }
        if (target->next) {
            target->next->prev = target->prev;
        }
        close_socket(target->fd);
        if (target->write_reference != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, target->write_reference);
            target->write_reference = LUA_NOREF;
        }
        lmt_memory_free(target);
        if (statistics && statistics->active_clients > 0) {
            statistics->active_clients--;
        }
    }
}

static void serverlib_aux_send_error_response(
    lua_State         *L,
    client            *c,
    server_statistics *statistics,
    int                status,
    const char        *body,
    int                report_ref
)
{
    statistics->total_errors++;
    serverlib_aux_report(L, report_ref, "error %i for client %s (%s)", status, c->peer_ip[0] ? c->peer_ip : "client", body ? body : "");

    size_t body_length = body ? strlen(body) : 0;

    luaL_Buffer buffer;
    luaL_buffinit(L, &buffer);

    char header[128];
    int header_length = snprintf(header, sizeof(header),
        "HTTP/1.1 %d %s\r\n"
        "Content-Type: text/plain\r\n"
        "Content-Length: %zu\r\n"
        "Connection: close\r\n\r\n",
        status, serverlib_aux_status_to_string(status), body_length
    );
    luaL_addlstring(&buffer, header, serverlib_aux_buffer_length(header_length, sizeof(header)));

    if (body_length > 0) {
        luaL_addlstring(&buffer, body, body_length);
    }

    luaL_pushresult(&buffer);
    c->write_buffer = lua_tolstring(L, -1, &c->write_length);
    c->write_reference = luaL_ref(L, LUA_REGISTRYINDEX); /* also pops */
    c->state = client_state_writing;
}

/*tex

    Features like the report and step (with delay) are just there because we need those in existing
    applications. Some use cases are (private:) hue and evohome servers (wrappers), publishing on
    demand workflows where we produce sets of (educational) documents from a huge collection of xml
    files based on user selection (chapters, features), context related services (help, font samples,
    etc). These various applications determined what we have below. But some more might be added.

    We run on localhost, mayeb on a server in the intranet, and for the outside world simpe servers
    like below sit nicely behind for instance nginx that then does the https and deals with the
    redirection of subdomains.

*/

static void serverlib_aux_process_request(
    lua_State         *L,
    client            *c,
    size_t             content_length,
    int                callback_ref,
    int                trace,
    server_statistics *statistics,
    int                stats,
    int                report_ref
)
{
    char method[16] = { 0 };
    char path[512]  = { 0 };

    statistics->total_requests++;

    /* first we validate the http request line strictly using space delimiters */

    char *line_end = strstr(c->read_buffer, "\r\n");
    char *sp1 = line_end ? strchr(c->read_buffer, ' ') : NULL;
    char *sp2 = sp1 ? strchr(sp1 + 1, ' ') : NULL;

    if (! line_end || ! sp1 || ! sp2 || sp1 > line_end || sp2 > line_end) {
        serverlib_aux_send_error_response(L, c, statistics, 400, "400 Bad Request", report_ref);
        return;
    }

    size_t m_len = sp1 - c->read_buffer;
    size_t p_len = sp2 - (sp1 + 1);

    if (m_len == 0 || m_len >= sizeof(method) || p_len == 0 || p_len >= sizeof(path)) {
        serverlib_aux_send_error_response(L, c, statistics, 400, "400 Bad Request", report_ref);
        return;
    }

    memcpy(method, c->read_buffer, m_len);
    method[m_len] = '\0';
    memcpy(path, sp1 + 1, p_len);
    path[p_len] = '\0';

    /* we're fine and can push the callback function */
    lua_rawgeti(L, LUA_REGISTRYINDEX, callback_ref);

    /* we take a look at the keys in the table */
    lua_newtable(L);
    lua_pushstring(L, method);
    lua_setfield(L, -2, "method");
    lua_pushstring(L, path);
    lua_setfield(L, -2, "path");
    lua_pushstring(L, c->peer_ip);
    lua_setfield(L, -2, "ip");

    /* extract request body payload if present */
    char *header_end = strstr(c->read_buffer, "\r\n\r\n");
    if (header_end) {
        const char *body_ptr = header_end + 4;
        size_t header_len = (header_end - c->read_buffer) + 4;
        size_t body_len = (c->read_bytes > header_len) ? (c->read_bytes - header_len) : 0;
        if (body_len > content_length) {
            body_len = content_length;
        }

        lua_pushlstring(L, body_ptr, body_len);
        lua_setfield(L, -2, "body");
    }

    /*
        we need headers when we want to handle post requests, we could do this in Lua instead
        as we did before
    */
    if (header_end) {
        lua_newtable(L);
        /* skip the request line */
        char *line_start = strstr(c->read_buffer, "\r\n");
        if (line_start && line_start < header_end) {
            /* skip the initial \r\n */
            line_start += 2;
            while (line_start < header_end) {
                char *next_line = strstr(line_start, "\r\n");
                if (! next_line || next_line > header_end) {
                    break;
                }
                char *colon = memchr(line_start, ':', next_line - line_start);
                if (colon) {
                    /* lowercase key */
                    size_t klen = colon - line_start;
                    char *val_start = colon + 1;
                    char key_buf[256]; /* plenty */
                    char *key = key_buf;
                    if (klen >= sizeof(key_buf)) {
                        key = (char *) lmt_memory_malloc(klen);
                        if (! key) {
                            line_start = next_line + 2;
                            continue;
                        }
                    }
                    for (size_t i = 0; i < klen; i++) {
                        key[i] = (char) tolower((unsigned char) line_start[i]);
                    }
                    lua_pushlstring(L, key, klen);
                    if (key != key_buf) {
                        lmt_memory_free(key);
                    }
                    size_t vlen = next_line - val_start;
                    lua_pushlstring(L, val_start, vlen);
                    lua_settable(L, -3);
                }
                line_start = next_line + 2;
            }
        }
        lua_setfield(L, -2, "headers");
    }

    if (stats) {
        lua_newtable(L);
        lua_pushinteger(L, (lua_Integer) (time(NULL) - statistics->start_time));
        lua_setfield(L, -2, "uptime");
        lua_pushinteger(L, (lua_Integer) statistics->total_requests);
        lua_setfield(L, -2, "requests");
        lua_pushinteger(L, (lua_Integer) statistics->total_errors);
        lua_setfield(L, -2, "errors");
        lua_pushinteger(L, (lua_Integer) statistics->bytes_read);
        lua_setfield(L, -2, "bytesread");
        lua_pushinteger(L, (lua_Integer) statistics->bytes_written);
        lua_setfield(L, -2, "byteswritten");
        lua_pushinteger(L, (lua_Integer) statistics->active_clients);
        lua_setfield(L, -2, "activeclients");
        lua_pushinteger(L, (lua_Integer) statistics->max_nofclients);
        lua_setfield(L, -2, "maxnofclients");
        lua_pushinteger(L, (lua_Integer) statistics->client_timeout);
        lua_setfield(L, -2, "clienttimeout");
        lua_pushinteger(L, (lua_Integer) statistics->timedout_clients);
        lua_setfield(L, -2, "timedoutclients");
        lua_setfield(L, -2, "statistics");
    }

    /* time for some action */
    if (lua_pcall(L, 1, 1, 0) == LUA_OK) {
        int         status      = 200;
        const char *mime        = "text/plain";
        size_t      mime_length = sizeof("text/plain") - 1;
        const char *body        = "";
        size_t      body_length = 0;

        if (lua_istable(L, -1)) {
            int table_index = lua_gettop(L);

            lua_getfield(L, table_index, "status");
            if (lua_isinteger(L, -1)) {
                status = (int) lua_tointeger(L, -1);
            }
            lua_pop(L, 1);
            if (status >= 400) {
                statistics->total_errors++;
                serverlib_aux_report(L, report_ref, "handler returned status %i for %s %s", status, method, path);
            }

            lua_getfield(L, table_index, "mime");
            if (lua_isstring(L, -1)) {
                mime = lua_tolstring(L, -1, &mime_length);
            }
            lua_pop(L, 1);

            lua_getfield(L, table_index, "body");
            if (lua_isstring(L, -1)) {
                body = lua_tolstring(L, -1, &body_length);
            }
            lua_pop(L, 1);

            luaL_Buffer buffer;
            luaL_buffinit(L, &buffer);

            char status_header[128];
            int status_length = snprintf(status_header, sizeof(status_header),
                "HTTP/1.1 %d %s\r\nContent-Type: ",
                status, serverlib_aux_status_to_string(status)
            );
            luaL_addlstring(&buffer, status_header,
                serverlib_aux_buffer_length(status_length, sizeof(status_header)));
            luaL_addlstring(&buffer, mime, mime_length);

            char content_header[128];
            int content_length_header = snprintf(content_header, sizeof(content_header),
                "\r\nContent-Length: %zu\r\nConnection: close\r\n", body_length
            );
            luaL_addlstring(&buffer, content_header,
                serverlib_aux_buffer_length(content_length_header, sizeof(content_header)));

            lua_getfield(L, table_index, "headers");
            if (lua_isstring(L, -1)) {
                size_t len = 0;
                const char *str = lua_tolstring(L, -1, &len);
                if (len > 0) {
                    luaL_addlstring(&buffer, str, len);
                    if (len < 2 || str[len - 2] != '\r' || str[len - 1] != '\n') {
                        luaL_addstring(&buffer, "\r\n");
                    }
                }
                lua_pop(L, 1);
            } else if (lua_istable(L, -1)) {
                int index = lua_gettop(L);
                lua_pushnil(L);
                while (lua_next(L, index) != 0) {
                    if (lua_type(L, -2) == LUA_TSTRING && lua_isstring(L, -1)) {
                        luaL_addstring(&buffer, lua_tostring(L, -2));
                        luaL_addstring(&buffer, ": ");
                        luaL_addstring(&buffer, lua_tostring(L, -1));
                        luaL_addstring(&buffer, "\r\n");
                    } else if (lua_type(L, -2) == LUA_TNUMBER && lua_isstring(L, -1)) {
                        luaL_addstring(&buffer, lua_tostring(L, -1));
                        luaL_addstring(&buffer, "\r\n");
                    }
                    lua_pop(L, 1);
                }
                lua_pop(L, 1);
            } else {
                lua_pop(L, 1);
            }

            luaL_addstring(&buffer, "\r\n");

            if (body_length > 0) {
                luaL_addlstring(&buffer, body, body_length);
            }

            luaL_pushresult(&buffer);
            lua_remove(L, table_index);
        } else {
            luaL_Buffer buffer;
            luaL_buffinit(L, &buffer);
            luaL_addstring(&buffer, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
            luaL_pushresult(&buffer);
            lua_remove(L, -2);
        }
        /* now the result string is at the top: -1 */
        c->write_buffer = lua_tolstring(L, -1, &c->write_length);
        c->write_reference = luaL_ref(L, LUA_REGISTRYINDEX);
        c->state = client_state_writing;
    } else {
        const char *err = trace ? lua_tostring(L, -1) : "Internal Server Error";
        serverlib_aux_report(L, report_ref, "lua callback error: %s", lua_tostring(L, -1));
        serverlib_aux_send_error_response(L, c, statistics, 500, err, report_ref);
        lua_pop(L, 1);
    }
}

/*
    Here we have the event loop. When a request is encountered the \LUA\ callback kicks in.
*/

static int serverlib_httpserver(lua_State *L)
{
    int  port               = 0;
    int  client_timeout     = default_timeout;
    int  trace              = 0;
    int  stats              = 0;
    int  callback_ref       = LUA_NOREF;
    int  report_ref         = LUA_NOREF;
    int  step_ref           = LUA_NOREF;
# ifdef _WIN32
    int  wsa_initialized    = 0;
# endif
    long select_sec         = default_delay;
    long select_usec        = 0;

    server_statistics statistics;
    memset(&statistics, 0, sizeof(server_statistics));
    statistics.start_time = time(NULL);

    if (lua_istable(L, 1)) {

        lua_getfield(L, 1, "port");
        if (lua_isinteger(L, -1)) {
            port = lmt_tointeger(L, -1);
        }
        lua_pop(L, 1);

        lua_getfield(L, 1, "report");
        if (lua_isfunction(L, -1)) {
            report_ref = luaL_ref(L, LUA_REGISTRYINDEX);
        } else {
            lua_pop(L, 1);
        }

        lua_getfield(L, 1, "action");
        if (lua_isfunction(L, -1)) {
            callback_ref = luaL_ref(L, LUA_REGISTRYINDEX);
        } else {
            lua_pop(L, 1);
            serverlib_aux_report(L, report_ref, "valid 'action' function required");
            goto DONE;
        }

        lua_getfield(L, 1, "timeout");
        if (lua_isinteger(L, -1)) {
            client_timeout = lmt_tointeger(L, -1);
        }
        lua_pop(L, 1);

        lua_getfield(L, 1, "trace");
        trace = lua_toboolean(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, 1, "statistics");
        stats = lua_toboolean(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, 1, "step");
        if (lua_isfunction(L, -1)) {
            step_ref = luaL_ref(L, LUA_REGISTRYINDEX);
        } else {
            lua_pop(L, 1);
        }

        lua_getfield(L, 1, "delay"); /* also accepts 0.5 */
        if (lua_isnumber(L, -1)) {
            double d = lua_tonumber(L, -1);
            if (d > 0.0) {
                select_sec  = (long) d;
                select_usec = (long) ((d - (double) select_sec) * 1000000.0);
            }
        }
        lua_pop(L, 1);

    } else {
        /* we don't have the reporter available */
        return luaL_error(L, "server.httpserver expects a table");
    }

    statistics.client_timeout = client_timeout;

    if (port <= 0 || port > 65535) {
        serverlib_aux_report(L, report_ref, "valid 'port' required");
        goto DONE;
    }

# ifdef _WIN32
    WSADATA wsa;
    if (WSAStartup(MAKEWORD(2, 2), &wsa) == 0) {
        wsa_initialized = 1;
    } else {
        serverlib_aux_report(L, report_ref, "failed to initialize winsock");
        goto DONE;
    }
# endif

    socket_t server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (invalid_socket(server_fd)) {
        serverlib_aux_report(L, report_ref, "failed to create socket");
        goto DONE;
    }

# ifndef _WIN32
    if (server_fd >= FD_SETSIZE) {
        serverlib_aux_report(L, report_ref, "server socket descriptor too large");
        close_socket(server_fd);
        goto DONE;
    }
# endif

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, (const char*) &opt, sizeof(opt));
    if (! set_nonblocking(server_fd)) {
        serverlib_aux_report(L, report_ref, "failed to configure socket");
        close_socket(server_fd);
        goto DONE;
    }

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(server_fd, (struct sockaddr*) &addr, sizeof(addr)) < 0 || listen(server_fd, 128) < 0) {
        serverlib_aux_report(L, report_ref, "failed to bind or listen on port %i", port);
        close_socket(server_fd);
        goto DONE;
    }

# if !defined(_WIN32) && !defined(MSG_NOSIGNAL) && !defined(SO_NOSIGPIPE)
    signal(SIGPIPE, SIG_IGN);
# endif

    serverlib_aux_report(L, report_ref, "non-blocking event loop started on http://localhost:%i", port);

    client *clients = NULL;

    while (1) {
        fd_set read_fds, write_fds;
        FD_ZERO(&read_fds);
        FD_ZERO(&write_fds);

        /* always monitor listening socket for new incoming connections */
        FD_SET(server_fd, &read_fds);
        socket_t max_fd = server_fd;

        /* register client sockets depending on state */
        client *current = clients;
        while (current) {
            if (current->state == client_state_reading) {
                FD_SET(current->fd, &read_fds);
            } else if (current->state == client_state_writing) {
                FD_SET(current->fd, &write_fds);
            }
            if (current->fd > max_fd) {
                max_fd = current->fd;
            }
            current = current->next;
        }

        /* we can configure the timeout */
        struct timeval timeout = { select_sec, select_usec };
        int activity = select((int) max_fd + 1, &read_fds, &write_fds, NULL, &timeout);
        if (activity < 0) {
# ifdef _WIN32
            if (WSAGetLastError() == WSAEINTR) {
# else
            if (errno == EINTR) {
# endif
                continue;
            }
            serverlib_aux_report(L, report_ref, "select failed");
            break;
        }

        /* handle a new connection and possibly add it to the linked list */
        if (FD_ISSET(server_fd, &read_fds)) {
            struct sockaddr_in client_addr;
            socklen_t addrlen = sizeof(client_addr);
            socket_t client_fd = accept(server_fd, (struct sockaddr*) &client_addr, &addrlen);
            if (! invalid_socket(client_fd)) {
# ifdef _WIN32
                int room = statistics.active_clients < (size_t) (FD_SETSIZE - 1);
# else
                int room = client_fd < FD_SETSIZE;
# endif
                if (room && set_nonblocking(client_fd)) {
                    serverlib_aux_set_no_sigpipe(client_fd);
                    char ip_str[INET_ADDRSTRLEN] = {0};
                    inet_ntop(AF_INET, &client_addr.sin_addr, ip_str, INET_ADDRSTRLEN);
                    serverlib_aux_client(&clients, client_fd, ip_str, &statistics);
                } else {
                    close_socket(client_fd);
                }
            }
        }

        /* service existing clients in the linked list */
        current = clients;
        while (current) {
            /* we save the next pointer becauuse we can free current */
            client *next = current->next;
            if (current->state == client_state_reading && FD_ISSET(current->fd, &read_fds)) {
                /* read state: accumulate request bytes */
                int n = recv(
                    current->fd, current->read_buffer + current->read_bytes,
                    sizeof(current->read_buffer) - 1 - current->read_bytes,
                    0
                );
                if (n > 0) {
                    statistics.bytes_read += n;
                    current->last_time = time(NULL); /* update timestamp */
                    current->read_bytes += n;
                    current->read_buffer[current->read_bytes] = '\0';

                    /* check if the https header end (\r\n\r\n) is reached */
                    char *header_end = strstr(current->read_buffer, "\r\n\r\n");
                    if (header_end) {
                        size_t header_len = (header_end - current->read_buffer) + 4;
                        size_t content_len = 0;
                        if (! serverlib_aux_get_content_length(current->read_buffer, header_len, &content_len)) {
                            serverlib_aux_send_error_response(L, current, &statistics, 400, "400 Bad Request", report_ref);
                        } else if (content_len >= sizeof(current->read_buffer) - header_len) {
                            serverlib_aux_send_error_response(L, current, &statistics, 413, "413 Request Entity Too Large", report_ref);
                        } else if (current->read_bytes >= header_len + content_len) {
                            serverlib_aux_process_request(L, current, content_len, callback_ref, trace, &statistics, stats, report_ref);
                        }
                    }
                } else if (n == 0 || (n < 0 && ! would_block)) {
                    /* the client closed the connection or went bad */
                    serverlib_aux_remove_client(L, &clients, current, &statistics);
                }
            } else if (current->state == client_state_writing && FD_ISSET(current->fd, &write_fds)) {
                /* write state: send response chunk by chunk */
                int sent = send(
                    current->fd,
                    current->write_buffer + current->write_position,
                    (int) (current->write_length - current->write_position),
                    send_flags
                );
                if (sent > 0) {
                    statistics.bytes_written += sent;
                    current->write_position += sent;
                    if (current->write_position >= current->write_length) {
                        /* we're finished sending response */
                        serverlib_aux_remove_client(L, &clients, current, &statistics);
                    }
                } else if (sent < 0 && ! would_block) {
                    serverlib_aux_remove_client(L, &clients, current, &statistics);
                }
            }
            current = next;
        }

        /* cleanup stale clients */
        if (client_timeout > 0) {
            time_t now = time(NULL);
            current = clients;
            while (current) {
                client *next = current->next;
                if (now - current->last_time > client_timeout) {
                    serverlib_aux_report(L, report_ref, "client %s timed out", current->peer_ip[0] ? current->peer_ip : "client");
                    serverlib_aux_remove_client(L, &clients, current, &statistics);
                    statistics.timedout_clients += 1;
                }
                current = next;
            }
        }

        /* optionally run a step function */
        if (step_ref != LUA_NOREF) {
            lua_rawgeti(L, LUA_REGISTRYINDEX, step_ref);
            if (lua_pcall(L, 0, 1, 0) == LUA_OK) {
                if (lua_isnumber(L, -1)) {
                    double d = lua_tonumber(L, -1);
                    if (d >= 0.0) {
                        select_sec  = (long) d;
                        select_usec = (long) ((d - (double) select_sec) * 1000000.0);
                    }
                }
            } else if (trace) {
                serverlib_aux_report(L, report_ref, "lua step callback error: %s", lua_tostring(L, -1));
            }
            lua_pop(L, 1);
        }
    }

    while (clients) {
        serverlib_aux_remove_client(L, &clients, clients, &statistics);
    }
    close_socket(server_fd);

  DONE:
    if (callback_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, callback_ref);
    }
    if (report_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, report_ref);
    }
    if (step_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, step_ref);
    }
# ifdef _WIN32
    if (wsa_initialized) {
        WSACleanup();
    }
# endif
    return 0;
}

static int serverlib_supported(lua_State *L)
{
    /* todo: some magick check */
    lua_pushboolean(L, 1);
    return 1;
}

static const struct luaL_Reg serverlib_function_list[] = {
    { "httpserver", serverlib_httpserver },
    { "supported",  serverlib_supported  },
    { NULL,         NULL                 },
};

int luaopen_server(lua_State *L)
{
    luaL_newlib(L, serverlib_function_list);
    return 1;
}
