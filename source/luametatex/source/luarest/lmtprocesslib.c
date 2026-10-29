/*
    See license.txt in the root of this project.
*/

/*
    This is work in progress. We already have some parallel processing features but these use the
    regular \LUA\ popen feature. We don't want to use some library that adds too much to the
    binary so after asking around a bit for the basics we ended up here. It kind of set up like
    the serial module, with a userdatum and such.

    The interfaces should be the same for windows and posix and because posix wants the arguments
    split form the command, that is what gets in. We also want to be abel to discard the output
    because \TEX\ also produces a log file. The reason for thisa module is that I want to process
    the tets suite faster. The (in 2026) about 2200 files took 800 seconds on my 2018 laptop with
    the regular |popen| feature but some 450 with the non-blocking approach.

    The rewrite to a faster process handling involved (also at the \CONTEXT) efficient support for
    handling lines (using a callback) using a (growing) buffer for pending content. Of course
    interwoven output in a visible acceptable way is something to handle at the \LUA\ end; in
    |mtx-context| we can use colors. We might add some more features here.

    The code is a bit messy because snippets come from suggestions from e.g. Gemini as well as
    searching.  We have a bit special interface wrt commands, polling, flushing but eventually we
    get there. This kind of platform specific code is not really nice to deal with. With the search
    engines trying to be intelligent it's harder to figure out these interfaces but oen can just
    ignore most. It actually is handy to query for the more obscure api calls but because answers
    differ one has to be on the edge: don't expect generated code to work.

*/

# include "luametatex.h"

/*tex See |lmtinterface.h| for |PROCESS_METATABLE_INSTANCE|. */

// open  ( command, nulled )           : process (userdata)
// poll  ( { process, ... }, timeout ) : output/exit (table with indices of first table)
// read  ( process, [callback] )       : string (continue) | false (continue) | true (eof/exit)
// close ( process )                   : exitcode (integer)

/*tex 

    A too large buffer can make pending output of other processes pile up. When we run multiple \TEX\
    jobs in parallel, often the output interweaves nicely. This is why we introduced callbacks so 
    that we can stay at the \CCODE\ end. So, 4096 *or even less) is plenty. 

*/

# define buffersize 4096 // 16384

/*tex

    Contrary to the already present |popen| interface here we start a process with or without a pipe
    (which is again just a file). By nulling we avoid overhead in discarding and \TEX\ has it's own
    log file anyway. Once opened, we can poll what processes have output pending. We then either
    handle this in \LUA, or we stay at the \CCODE\ end and let a callback deal with lines. This saves
    copying strings and restarting a poll. When a process is ended, the poller returns so that we can
    close the process and start a new one at the \LUA\ end, where we do the housekeeping.

    There are subtle differences between POSIX and Windows, for instance in passing the commands. We
    assume proper quoting at the \LUA\ end because there it is known what we are dealing with. On
    Windows we pass a copy of the command (because the string can be messed with) and in POSIX we
    create an array of pointers, so there we need to be clever with quotes. Because (unless we null)
    we feedback lines we keep a buffer for pending output.

    On Windows we can emulate forking or we can be a bit more native. In any case, the spawn is less
    efficient so we never saturate the hardware. We keep both code paths so that at some point we can
    test a bit more.

*/

# ifdef _WIN32

    # include <windows.h>

    typedef struct process_data {
        HANDLE  read;
        HANDLE  process;
        int     closed;
        int     nulled;
        char   *partial;
        size_t  length;
        size_t  capacity;
    } process_data;

# else

    # include <unistd.h>
    # include <fcntl.h>
    # include <poll.h>
    # include <sys/wait.h>
    # include <errno.h>

    typedef struct process_data {
        int     read;
        pid_t   process;
        int     closed;
        int     nulled;
        int     exited;
        int     status;
        char   *partial;
        size_t  length;
        size_t  capacity;
    } process_data;

# endif

/*tex
    We share this one, because it doesn't set any values in the data structure. We could use pointer
    comparison here but the number of checks is not that large.
*/

static inline process_data * processlib_aux_valid(lua_State *L, int i)
{
    process_data * process = lua_touserdata(L, i);
    if (process && lua_getmetatable(L, i)) {
        lua_get_metatablelua(process_instance);
        if (! lua_rawequal(L, -1, -2)) {
            process = NULL;
        }
        lua_pop(L, 2);
    }
    return process;
}

/*tex
    When we enable a terminal (see \CONTEXT\ usage) it makes sense to handle lines here instead
    of splitting and appending in \LUA, so here is a helper.
*/

static void processlib_callback(
    lua_State    *L,
    process_data *process,
    const char   *data,
    size_t        len,
    int           eof
)
{
    /*tex We can have long lines, so we need to let the buffer grow on demand. */
    if (len > 0) {
        size_t needed = process->length + len;
        if (needed > process->capacity) {
            size_t capacity = process->capacity ? process->capacity * 2 : buffersize;
            if (capacity < needed) {
                capacity = needed;
            }
            char *buffer = lmt_memory_realloc(process->partial, capacity);
            if (! buffer) {
                tex_formatted_warning("process lib", "out of memory in line buffering");
                return;
            }
            process->partial  = buffer;
            process->capacity = capacity;
        }
        memcpy(process->partial + process->length, data, len);
        process->length = needed;
    }
    /*tex We need to handle both line endings. The callback is the second argument to read. */
    size_t start = 0;
    for (size_t i = 0; i < process->length; i++) {
        if (process->partial[i] == '\n') {
            size_t line_len = i - start;
            if (line_len > 0 && process->partial[start + line_len - 1] == '\r') {
                line_len--;
            }
            lua_pushvalue(L, 2);
            lua_pushlstring(L, process->partial + start, line_len);
            lua_call(L, 1, 0);
            start = i + 1;
        }
    }
    /*tex We now move the pending rest to the start. */
    if (start < process->length) {
        size_t remaining = process->length - start;
        if (eof) {
            /*tex We flush pending text when we exit (eof). */
            if (remaining > 0 && process->partial[start + remaining - 1] == '\r') {
                remaining--;
            }
            lua_pushvalue(L, 2);
            lua_pushlstring(L, process->partial + start, remaining);
            lua_call(L, 1, 0);
            process->length = 0;
        } else {
            /*tex We handle the rest next time (no blocking by waiting). */
            memmove(process->partial, process->partial + start, remaining);
            process->length = remaining;
        }
    } else {
        process->length = 0;
    }
}

# ifdef _WIN32

# if 0 /* 1 = fork like, 0 = native non-blocking */ /* there is not much difference currently */

    static BOOL process_create_pipe(PHANDLE hRead, PHANDLE hWrite, LPSECURITY_ATTRIBUTES lpSA)
    {
        if (CreatePipe(hRead, hWrite, lpSA, 0)) {
            SetHandleInformation(hRead, HANDLE_FLAG_INHERIT, 0);
            return TRUE;
        } else {
            return FALSE;
        }
    }

    static int processlib_read(lua_State *L)
    {
        process_data *process  = processlib_aux_valid(L, 1);
        int           callback = lua_type(L, 2) == LUA_TFUNCTION;

        if (! process || process->closed || process->nulled || ! process->read) {
            if (callback && process && process->length > 0) {
                processlib_callback(L, process, NULL, 0, 1);
            }
            lua_pushboolean(L, 1); /* we're done */
            return 1;
        }

        char buf[buffersize];
        DWORD available = 0;
        DWORD bytes     = 0;
        BOOL  okay      = PeekNamedPipe(process->read, NULL, 0, NULL, &available, NULL);

        if (! okay) {
            DWORD err = GetLastError();
            if (err == ERROR_BROKEN_PIPE || err == ERROR_PIPE_NOT_CONNECTED) {
                if (callback && process->length > 0) {
                    processlib_callback(L, process, NULL, 0, 1);
                }
                lua_pushboolean(L, 1); /* we're done */
            } else {
                lua_pushboolean(L, 0); /* we continue */
            }
            return 1;
        }

        if (available > 0) {
            if (ReadFile(process->read, buf, sizeof(buf), &bytes, NULL) && bytes > 0) {
                if (callback) {
                    processlib_callback(L, process, buf, (size_t) bytes, 0);
                    lua_pushboolean(L, 0); /* we continue */
                } else {
                    lua_pushlstring(L, buf, bytes); /* some data */
                }
                return 1;
            }
        }

        DWORD exit_code;
        if (GetExitCodeProcess(process->process, &exit_code) && exit_code != STILL_ACTIVE) {
            PeekNamedPipe(process->read, NULL, 0, NULL, &available, NULL);
            if (available == 0) {
                if (callback && process->length > 0) {
                    processlib_callback(L, process, NULL, 0, 1);
                }
                lua_pushboolean(L, 1); /* we're done */
                return 1;
            }
        }

        lua_pushboolean(L, 0); /* we continue */
        return 1;
    }

# else

    static BOOL process_create_pipe(PHANDLE hRead, PHANDLE hWrite, LPSECURITY_ATTRIBUTES lpSA) /* non-blocking */
    {
        if (! CreatePipe(hRead, hWrite, lpSA, 0)) {
            return FALSE;
        } else {
            /* prevent child process from inheriting the read end */
            SetHandleInformation(*hRead, HANDLE_FLAG_INHERIT, 0);
            /* set pipe mode to NOWAIT (non-blocking I/O) */
            DWORD mode = PIPE_READMODE_BYTE | PIPE_NOWAIT;
            if (! SetNamedPipeHandleState(*hRead, &mode, NULL, NULL)) {
                CloseHandle(*hRead);
                CloseHandle(*hWrite);
                *hRead  = NULL;
                *hWrite = NULL;
                return FALSE;
            } else {
                return TRUE;
            }
        }
    }

    static int processlib_read(lua_State *L)
    {
        process_data *process  = processlib_aux_valid(L, 1);
        int           callback = lua_type(L, 2) == LUA_TFUNCTION;

        if (! process || process->closed || process->nulled || ! process->read) {
            if (callback && process && process->length > 0) {
                processlib_callback(L, process, NULL, 0, 1);
            }
            lua_pushboolean(L, 1); /* we're done */
            return 1;
        }

     // /* loop until pipe is empty so child process is never blocked on stdout writes */

        char  buf[buffersize];
        DWORD bytes_read = 0;

     // while (1) {
            BOOL ok = ReadFile(process->read, buf, sizeof(buf), &bytes_read, NULL);
            if (ok && bytes_read > 0) {
                if (callback) {
                    processlib_callback(L, process, buf, (size_t) bytes_read, 0);
                    lua_pushboolean(L, 0); /* we continue */
                } else {
                    lua_pushlstring(L, buf, bytes_read); /* some data */
                }
            } else {
                DWORD err = GetLastError();
                if (! ok && (err == ERROR_NO_DATA || err == ERROR_MORE_DATA)) {
                    lua_pushboolean(L, 1); /* we continue */
                } else {
                    /* broken pipe or EOF */
                    if (callback && process->length > 0) {
                        processlib_callback(L, process, NULL, 0, 1);
                    }
                    lua_pushboolean(L, 1); /* we're done */
                }
            }
            return 1;
     // }
    }

# endif

    /*tex
        We delegate quoting to the caller because we also have |--foo="bar bar"| like arguments.
    */

    static int processlib_open(lua_State *L)
    {
        size_t len;
        const char *cmd_constant = lua_tolstring(L, 1, &len);

        if (! cmd_constant || ! lmt_valid_target(L, security_executable, cmd_constant, security_open_process)) {
            return 0;
        }

        int nulled = lua_toboolean(L, 2);

        HANDLE hRead  = NULL;
        HANDLE hWrite = NULL;
        HANDLE hNull  = NULL;

        SECURITY_ATTRIBUTES sa = { sizeof(SECURITY_ATTRIBUTES), NULL, TRUE };

        if (nulled) {
            hNull = CreateFileA(
                "NUL",
                GENERIC_WRITE,
                FILE_SHARE_READ | FILE_SHARE_WRITE,
                &sa,
                OPEN_EXISTING,
                FILE_ATTRIBUTE_NORMAL,
                NULL
            );
            if (hNull == INVALID_HANDLE_VALUE) {
                tex_formatted_warning("process lib", "opening nul device failed");
                return 0;
            }
        } else {
            if (! process_create_pipe(&hRead, &hWrite, &sa)) {
                tex_formatted_warning("process lib", "creating pipe failed");
                return 0;
            }
        }

        STARTUPINFOA        si = { 0 };
        PROCESS_INFORMATION pi = { 0 };

        si.cb          = sizeof(STARTUPINFOA);
        si.hStdOutput  = nulled ? hNull : hWrite;
        si.hStdError   = nulled ? hNull : hWrite;
        si.dwFlags    |= STARTF_USESTDHANDLES;

        char *cmd_mutable  = lmt_memory_malloc(len + 1);

        if (! cmd_mutable) {
            if (hRead)  CloseHandle(hRead);
            if (hWrite) CloseHandle(hWrite);
            if (hNull)  CloseHandle(hNull);
            tex_formatted_warning("process lib", "out of memory");
            return 0;
        } else {
            memcpy(cmd_mutable, cmd_constant, len + 1);
        }

        BOOL result = CreateProcessA(
            NULL,
            cmd_mutable,      // has to be writable
            NULL,
            NULL,
            TRUE,             // inherit handles
            CREATE_NO_WINDOW, // instead of 0
            NULL,
            NULL,
            &si,
            &pi
        );

        lmt_memory_free(cmd_mutable);

        if (! result) {
            if (hRead)  CloseHandle(hRead);
            if (hWrite) CloseHandle(hWrite);
            if (hNull)  CloseHandle(hNull);
            tex_formatted_warning("process lib", "creating process failed");
            return 0;
        }

        if (hWrite)     CloseHandle(hWrite);
        if (hNull)      CloseHandle(hNull);
        if (pi.hThread) CloseHandle(pi.hThread);

        process_data *process = lua_newuserdatauv(L, sizeof(process_data), 0);
        lua_get_metatablelua(process_instance);
        lua_setmetatable(L, -2);
        process->read     = hRead;
        process->process  = pi.hProcess;
        process->closed   = 0;
        process->nulled   = nulled;
        process->partial  = NULL;
        process->length   = 0;
        process->capacity = 0;
        return 1;
    }

    /*tex

        We played with avoiding the fetching from the table but for our use case it doesn't really
        matters much. We need to allocate and free then (or impose a maximum). The not so accurate
        timer (rounds) has also some impact but it can be neglected. We can use the one in timerlib
        if needed. We have (in the archive) a variant that uses a specific windows feature: delegate
        the checking using an array of processes. However, it means more code. This is mostly used
        for parallel \CONTEXT\ runs, like the test suite and experiments gave the impression that
        we're talking noise here.

        Todo: test again, as it might matter when we don't null the output. Another thing to play
        with is collecting more because now the 4096 can end in the middle of a line.

    */

    static int processlib_poll(lua_State *L)
    {
        luaL_checktype(L, 1, LUA_TTABLE);
        ULONGLONG timeout = (ULONGLONG) luaL_optinteger(L, 2, -1);
        ULONGLONG start   = GetTickCount64();
        int       count   = (int) lua_rawlen(L, 1);
        int       index   = 1;
        lua_newtable(L);
        if (count == 0) {
            /*tex Normally we check before we call the poller, but just in case. */
            return 1;
        }
        /*tex
            We could validate the userdata in the table once and then avoid repetitive checking of 
            the userdata.
        */
        while (1) {
            int ready = 0;
            for (int i = 1; i <= count; i++) {
                lua_rawgeti(L, 1, i);
                process_data *process = processlib_aux_valid(L, -1);
                lua_pop(L, 1);
                if (process && ! process->closed) {
                    if (process->nulled) {
                        /* nulled processes have no pipe; check if the process terminated */
                        if (WaitForSingleObject(process->process, 0) == WAIT_OBJECT_0) {
                            lua_pushinteger(L, i);
                            lua_rawseti(L, -2, index++);
                            ready++;
                        }
                        continue;
                    }
                    DWORD available = 0;
                    BOOL  okay      = PeekNamedPipe(process->read, NULL, 0, NULL, &available, NULL);
                    /* Pipe has data to read */
                    if (okay && available > 0) {
                        lua_pushinteger(L, i);
                        lua_rawseti(L, -2, index++);
                        ready++;
                        continue;
                    }
                    /* check if pipe is broken (EOF) or process has terminated */
                    DWORD err    = GetLastError();
                    BOOL  broken = ! okay && (err == ERROR_BROKEN_PIPE || err == ERROR_PIPE_NOT_CONNECTED);
                    BOOL  dead   = (WaitForSingleObject(process->process, 0) == WAIT_OBJECT_0);
                    if (broken || dead) {
                        /* mark as ready so caller knows to read (which will hit EOF) or close */
                        lua_pushinteger(L, i);
                        lua_rawseti(L, -2, index++);
                        ready++;
                    }
                }
            }
            if (ready > 0 || timeout == 0) {
                break;
            }
            if (timeout != (ULONGLONG) -1 && (GetTickCount64() - start) >= timeout) {
                break;
            }
            Sleep(5); /* rounded to 15 ms */
        }
        return 1;
    }

    static int processlib_close(lua_State *L)
    {
        process_data *process = processlib_aux_valid(L, 1);
        if (process && ! process->closed) {
            DWORD exitcode = 0;
            if (process->read) {
                CloseHandle(process->read);
                process->read = NULL;
            }
            if (process->process) {
                WaitForSingleObject(process->process, INFINITE);
                GetExitCodeProcess(process->process, &exitcode);
                CloseHandle(process->process);
                process->process = NULL;
            }
            lua_pushinteger(L, exitcode);
            if (process->partial) {
                lmt_memory_free(process->partial);
                process->partial  = NULL;
                process->length   = 0;
                process->capacity = 0;
            }
            process->closed = 1;
        } else {
            lua_pushnil(L);
        }
        return 1;
    }

# else

    # define MAX_ARGS 64

    /*tex
        Here we need to split the arguments, so

            context "foo.tex" --crap --foo="oof foo"

        has to become:

            context
            foo.tex
            --crap
            --foo="oof foo"

        but we need to check that.
    */

    static int parse_command(char *cmd, char **argv)
    {
        int   argc      = 0;
        char *p         = cmd;
        int   in_quotes = 0;
        while (*p && argc < MAX_ARGS - 1) {
            /* we normally only have spaces in context but there can be multiple */
            while (*p && (*p == ' ' || *p == '\t')) {
                p++;
            }
            if (*p == '\0') {
                break;
            }
            /* next argument */
            argv[argc++] = p;
            char *dst = p;
            /* obey quotes after = */
            int quote_is_literal = 0;
            while (*p) {
                if (*p == '"') {
                    /* quote right after '=': treat the quotes as literal characters */
                    if (! in_quotes && dst > argv[argc - 1] && *(dst - 1) == '=') {
                        quote_is_literal = 1;
                    }
                    if (quote_is_literal) {
                        /* we keep the quote character */
                        *dst++ = *p++;
                        in_quotes = ! in_quotes;
                        if (! in_quotes) {
                            /* we arrived at the closing quote */
                            quote_is_literal = 0;
                        }
                    } else {
                        /* outer wrapper quote: strip it */
                        in_quotes = ! in_quotes;
                        p++;
                    }
                } else if ((*p == ' ' || *p == '\t') && ! in_quotes) {
                    /* skip space */
                    p++;
                    /* go one with the next argument */
                    break;
                } else {
                    /* copy a regular character */
                    *dst++ = *p++;
                }
            }
            /* end the current argument */
            *dst = '\0';
        }
        argv[argc] = NULL;
        return argc;
    }

    static int processlib_open(lua_State *L)
    {
        size_t len;
        const char *cmd_constant = lua_tolstring(L, 1, &len);

        if (! cmd_constant || ! lmt_valid_target(L, security_executable, cmd_constant, security_open_process)) {
            return 0;
        }

        char *argv[MAX_ARGS];
        char *cmd_mutable  = lmt_memory_malloc(len + 1);

        if (! cmd_mutable) {
            tex_formatted_warning("process lib", "out of memory");
            return 0;
        } else {
            memcpy(cmd_mutable, cmd_constant, len + 1);
        }

        int nulled = lua_toboolean(L, 2);
        int count  = parse_command(cmd_mutable, argv);

        if (! count) {
            lmt_memory_free(cmd_mutable);
            return 0;
        }

        int pipefd[2] = { -1, -1 };

        if (! nulled) {
            if (pipe(pipefd) == -1) {
                tex_formatted_warning("process lib", "creating pipe failed");
                lmt_memory_free(cmd_mutable);
                return 0;
            }
        }

        pid_t pid = fork();
        if (pid == -1) {
            /* fork failed */
            if (! nulled) {
                close(pipefd[0]);
                close(pipefd[1]);
            }
            tex_formatted_warning("process lib", "fork failed");
            lmt_memory_free(cmd_mutable);
            return 0;
        }

        /* child process */
        if (pid == 0) {
            if (nulled) {
                int devnull = open("/dev/null", O_RDWR);
                if (devnull == -1) {
                    _exit(127);
                }
                if (dup2(devnull, STDIN_FILENO) == -1 || dup2(devnull, STDOUT_FILENO) == -1 || dup2(devnull, STDERR_FILENO) == -1) {
                    _exit(127);
                }
                if (devnull > STDERR_FILENO) {
                    close(devnull);
                }
            } else {
                close(pipefd[0]);  /* close unused read end */
                if (dup2(pipefd[1], STDOUT_FILENO) == -1 || dup2(pipefd[1], STDERR_FILENO) == -1) {
                    /* redirect standard output and standard error */
                    _exit(127);
                }
                close(pipefd[1]);  /* close duplicate handle */
            }

            execvp(argv[0], argv); /* replace process image */
            _exit(127);
        }

        lmt_memory_free(cmd_mutable);

        if (! nulled) {
            close(pipefd[1]);
            /* set non-blocking mode */
            int flags = fcntl(pipefd[0], F_GETFL, 0);
            fcntl(pipefd[0], F_SETFL, flags | O_NONBLOCK);
        }

        /* wrap state in userdata */
        process_data *process = lua_newuserdatauv(L, sizeof(process_data), 0);
        lua_get_metatablelua(process_instance);
        lua_setmetatable(L, -2);
        process->read     = nulled ? -1 : pipefd[0];
        process->process  = pid;
        process->closed   = 0;
        process->nulled   = nulled;
        process->exited   = 0;
        process->status   = -1;
        process->partial  = NULL;
        process->length   = 0;
        process->capacity = 0;
        return 1;
    }

    static int processlib_read(lua_State *L)
    {
        process_data *process  = processlib_aux_valid(L, 1);
        int           callback = lua_type(L, 2) == LUA_TFUNCTION;

        if (! process || process->closed || process->nulled || process->read < 0) {
            if (callback && process && process->length > 0) {
                processlib_callback(L, process, NULL, 0, 1);
            }
            lua_pushboolean(L, 1); /* we're done */
            return 1;
        }

        char buf[buffersize];
        ssize_t n;
        do {
            n = read(process->read, buf, sizeof(buf));
        } while (n == -1 && errno == EINTR);

        if (n > 0) {
            if (callback) {
                processlib_callback(L, process, buf, (size_t) n, 0);
                lua_pushboolean(L, 0); /* we continue */
            } else {
                lua_pushlstring(L, buf, n);
            }
        } else if (n == 0) {
            /* EOF reached */
            if (callback && process->length > 0) {
                processlib_callback(L, process, NULL, 0, 1);
            }
            lua_pushboolean(L, 1); /* we're done */
        } else if (errno == EAGAIN || errno == EWOULDBLOCK) {
            lua_pushboolean(L, 0); /* we continue */
        } else {
            lua_pushboolean(L, 1); /* we're done */
        }
        return 1;
    }

    static inline int processlib_aux_reap(process_data *process)
    {
        if (process->exited) {
            return 1;
        } else {
            int   status;
            pid_t result;
            do {
                result = waitpid(process->process, &status, WNOHANG);
            } while (result == -1 && errno == EINTR);
            if (result == process->process) {
                process->status = status;
                process->exited = 1;
            } else if (result == -1) {
                /* There is no useful status left if waiting failed. */
                process->status = -1;
                process->exited = 1;
            }
            return process->exited;
        }
    }

    static int processlib_poll(lua_State *L)
    {
        luaL_checktype(L, 1, LUA_TTABLE);
        int timeout  = (int) luaL_optinteger(L, 2, -1);
        int count    = (int) lua_rawlen(L, 1);
        int index    = 1;
        int ready    = 0;
        int fd_count = 0;
        int nulled   = 0;

        lua_newtable(L);
        if (count == 0) {
            return 1;
        }

        struct pollfd *fds = lmt_memory_malloc(sizeof(struct pollfd) * count);
        if (! fds) {
            tex_formatted_warning("process lib", "out of memory");
            return 0;
        }

        for (int i = 1; i <= count; i++) {
            lua_rawgeti(L, 1, i);
            process_data *process = processlib_aux_valid(L, -1);
            lua_pop(L, 1);
            if (process && ! process->closed) {
                if (process->nulled || process->read < 0) {
                    nulled++;
                } else {
                    fds[fd_count].fd     = process->read;
                    fds[fd_count].events = POLLIN | POLLHUP | POLLERR;
                    fd_count++;
                }
            }
        }

        if (fd_count == 0 && nulled == 0) {
            lmt_memory_free(fds);
            return 1;
        }

        int remaining = timeout;
        while (ready == 0) {
            if (nulled) {
                for (int i = 1; i <= count; i++) {
                    lua_rawgeti(L, 1, i);
                    process_data *process = processlib_aux_valid(L, -1);
                    lua_pop(L, 1);
                    if (process && ! process->closed && (process->nulled || process->read < 0) && processlib_aux_reap(process)) {
                        lua_pushinteger(L, i);
                        lua_rawseti(L, -2, index++);
                        ready++;
                    }
                }
                if (ready > 0) {
                    break;
                }
            }

            if (remaining == 0) {
                break;
            }

            int wait = remaining;
            if (nulled && (wait < 0 || wait > 5)) {
                /* waitpid cannot be included in poll, so check it periodically */
                wait = 5;
            }

            int ret;
            do {
                ret = poll(fds, fd_count, wait);
            } while (ret == -1 && errno == EINTR);

            if (ret > 0) {
                int fd_idx = 0;
                for (int i = 1; i <= count; i++) {
                    lua_rawgeti(L, 1, i);
                    process_data *process = processlib_aux_valid(L, -1);
                    lua_pop(L, 1);
                    if (process && ! process->closed && ! process->nulled && process->read >= 0) {
                        /* Check if readable, hung up (EOF), or errored */
                        if (fds[fd_idx].revents & (POLLIN | POLLHUP | POLLERR)) {
                            lua_pushinteger(L, i);
                            lua_rawseti(L, -2, index++);
                            ready++;
                        }
                        fd_idx++;
                    }
                }
                break;
            } else if (ret < 0) {
                break;
            }

            if (remaining > 0) {
                remaining -= wait;
            }
            if (! nulled) {
                break;
            }
        }
        lmt_memory_free(fds);
        return 1;
    }

    static int processlib_close(lua_State *L)
    {
        process_data *process = processlib_aux_valid(L, 1);
        if (process && ! process->closed) {
            if (process->read >= 0) {
                close(process->read);
                process->read = -1;
            }
            if (! process->exited) {
                int   status;
                pid_t p;
                do {
                    p = waitpid(process->process, &status, 0);
                } while (p == -1 && errno == EINTR);
                if (p == process->process) {
                    process->status = status;
                } else {
                    process->status = -1;
                }
                process->exited = 1;
            }
            if (process->partial) {
                lmt_memory_free(process->partial);
                process->partial  = NULL;
                process->length   = 0;
                process->capacity = 0;
            }
            process->closed = 1;
            if (process->status >= 0 && WIFEXITED(process->status)) {
                lua_pushinteger(L, WEXITSTATUS(process->status));
            } else if (process->status >= 0 && WIFSIGNALED(process->status)) {
                lua_pushinteger(L, -WTERMSIG(process->status));
            } else {
                lua_pushinteger(L, -1);
            }
        } else {
            lua_pushnil(L);
        }
        return 1;
    }

# endif

static int processlib_tostring(lua_State *L)
{
    process_data * process = processlib_aux_valid(L, 1);
    if (process) { // && ! process->closed) {
        lua_pushfstring(L, "<process %p>", process);
        return 1;
    } else {
        return 0;
    }
}

static int processlib_gc(lua_State *L)
{
    return processlib_close(L);
}

static const struct luaL_Reg processlib_function_list[] = {
    /* management */
    { "open",     processlib_open     },
    { "read",     processlib_read     },
    { "poll",     processlib_poll     },
    { "close",    processlib_close    },
    /* */
    { "tostring", processlib_tostring },
    /* */
    { "__gc",     processlib_gc       },
    /* */
    { NULL,       NULL                },
};

int luaopen_process(lua_State *L)
{
    luaL_newmetatable(L, PROCESS_METATABLE_INSTANCE);
    luaL_setfuncs(L, processlib_function_list, 0);
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, -2);
    lua_settable(L, -3);
    lua_pushliteral(L, "__tostring");
    lua_pushliteral(L, "tostring");
    lua_gettable(L, -3);
    lua_settable(L, -3);
    lua_pushliteral(L, "__name");
    lua_pushliteral(L, "process");
    lua_settable(L, -3);
    return 1;
}

/*tex

    For now we put this code here because processes and watchdogs kind of relate (or can be
    combined). As usual with this low level hackery, the operating specific code was the
    result of some querying on the web and from that we moved on.

    We use a simple model: we create a watchdog and bind a callback function to it that we
    register in the \LUA\ registry. We limits the functionality here because the (various)
    applications can best be done at the \LUA\ end (which is also more fun). We can quit
    am event handler explicitly because the garbage collector can take a while to kick in
    because we use little memory.

    Because this is not a POSIX feature we need a seperate branch for linux and the bsd
    operating systems. We could also trigger on a change in file but that feature is not
    available on osx so not portable. In practice we should work with a job ticket (at
    leat that's what I always did) and those are unique (and later cleaned up). Anyway, the
    intelligence sits at the \LUA\ end.

*/

# if defined(_WIN32)

    // already ok

# elif defined(__linux__)

    /* It is actually a kernel feature, so the library is basically a wrapper. */

    # include <sys/inotify.h>

# elif defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)

    # include <sys/types.h>
    # include <sys/event.h>

# endif

typedef struct watch_data {
    int        lua_ref;
    char      *path;

# if defined(_WIN32)

    HANDLE     hDir;
    OVERLAPPED overlapped;
    char       buffer[4096];
    DWORD      bytesReturned;

# elif defined(__linux__)

    int        fd;
    int        wd;

# elif defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)

    int        fd;
    int        kq;

# endif
} watch_data;

// /* todo (when we add more features) */
//
// static inline watch_data * watchlib_aux_valid(lua_State *L)
// {
//     watch_data * w = lua_touserdata(L, 1);
//     if (w && lua_getmetatable(L, i)) {
//         lua_get_metatablelua(watch_instance);
//         if (! lua_rawequal(L, -1, -2)) {
//             w = NULL;
//         }
//         lua_pop(L, 2);
//     }
//     return w;
// }

static void watchlib_aux_callback(lua_State *L, int lua_ref, const char *filename)
{
    lua_rawgeti(L, LUA_REGISTRYINDEX, lua_ref);
    lua_pushstring(L, filename ? filename : "");
    /*tex We might at some point pass more details. */
    if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
        tex_formatted_warning("watcher","error in callback: %s", lua_tostring(L, -1));
        lua_pop(L, 1);
    }
}

static int watchlib_register(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    watch_data *w = (watch_data *) lua_newuserdata(L, sizeof(watch_data));
    memset(w, 0, sizeof(watch_data));

    w->path = lmt_memory_strdup(path);

    lua_pushvalue(L, 2);
    w->lua_ref = luaL_ref(L, LUA_REGISTRYINDEX);

    luaL_getmetatable(L, WATCHER_METATABLE_INSTANCE);
    lua_setmetatable(L, -2); /* so we gc on error */

    # if defined(_WIN32)

        w->hDir = CreateFileA(
            path,
            FILE_LIST_DIRECTORY,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            NULL,
            OPEN_EXISTING,
            FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
            NULL
        );
        if (w->hDir == INVALID_HANDLE_VALUE) {
            return luaL_error(L, "watcher: failed to open directory for monitoring");
        }
        memset(&w->overlapped, 0, sizeof(OVERLAPPED));
        w->overlapped.hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);
        ReadDirectoryChangesW(
            w->hDir, w->buffer, sizeof(w->buffer),
            FALSE,
            FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME,
         // FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME | FILE_NOTIFY_CHANGE_LAST_WRITE | FILE_NOTIFY_CHANGE_ATTRIBUTES;
            &w->bytesReturned,
            &w->overlapped,
            NULL
        );

    # elif defined(__linux__)

        w->fd = inotify_init1(IN_NONBLOCK);
        if (w->fd < 0) {
            return luaL_error(L, "watcher: failed to initialize inotify");
        }
        w->wd = inotify_add_watch(w->fd, path, IN_CREATE | IN_MOVED_TO);
     // w->wd = inotify_add_watch(w->fd, path, IN_CREATE | IN_MOVED_TO | IN_MODIFY | IN_ATTRIB);
        if (w->wd < 0) {
            close(w->fd);
            return luaL_error(L, "watcher: failed to add watch for path: %s", path);
        }

    # elif defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)

        w->kq = kqueue();
        if (w->kq == -1) {
            return luaL_error(L, "watcher: failed to create kqueue");
        }
        w->fd = open(path, O_RDONLY);
        if (w->fd == -1) {
            close(w->kq);
            return luaL_error(L, "watcher: failed to open directory for kqueue");
        }
        struct kevent ev;
        EV_SET(
            &ev,
            w->fd,
            EVFILT_VNODE,
            EV_ADD | EV_ENABLE | EV_CLEAR,
            NOTE_WRITE | NOTE_EXTEND | NOTE_RENAME | NOTE_DELETE,
            0,
            NULL
        );
        if (kevent(w->kq, &ev, 1, NULL, 0, NULL) == -1) {
            close(w->fd);
            close(w->kq);
            return luaL_error(L, "watcher: failed to register kqueue event");
        }

    # endif

    return 1;
}

static int watchlib_check(lua_State *L)
{
    watch_data *w = (watch_data *) luaL_checkudata(L, 1, WATCHER_METATABLE_INSTANCE);

    if (! w->path) {
        return 0;
    }

    # if defined(_WIN32)

        DWORD transferred = 0;
        if (GetOverlappedResult(w->hDir, &w->overlapped, &transferred, FALSE)) {
            if (transferred > 0) {
                char *p = w->buffer;
                for (;;) {
                    FILE_NOTIFY_INFORMATION *fni = (FILE_NOTIFY_INFORMATION *)p;
                    if (fni->Action == FILE_ACTION_ADDED || fni->Action == FILE_ACTION_RENAMED_NEW_NAME) {
                        char filename[MAX_PATH];
                        int size = WideCharToMultiByte(CP_UTF8, 0, fni->FileName, fni->FileNameLength / sizeof(WCHAR), filename, sizeof(filename) - 1, NULL, NULL);
                        filename[size] = '\0';
                        watchlib_aux_callback(L, w->lua_ref, filename);
                    }
                    if (fni->NextEntryOffset == 0) break;
                    p += fni->NextEntryOffset;
                }
            }
            // re-arm asynchronous read
            memset(&w->overlapped, 0, sizeof(OVERLAPPED));
            w->overlapped.hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);
            ReadDirectoryChangesW(
                w->hDir,
                w->buffer,
                sizeof(w->buffer),
                FALSE,
                FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME,
                &w->bytesReturned,
                &w->overlapped,
                NULL
            );
        }

     # elif defined(__linux__)

        char buf[4096] __attribute__ ((aligned(__alignof__(struct inotify_event))));
        ssize_t len = read(w->fd, buf, sizeof(buf));
        if (len < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                return 0;
            } else {
                return luaL_error(L, "watcher: error reading inotify events");
            }
        }

        const struct inotify_event *event;
        for (char *ptr = buf; ptr < buf + len; ptr += sizeof(struct inotify_event) + event->len) {
            event = (const struct inotify_event *) ptr;
            if (event->len > 0 && (event->mask & (IN_CREATE | IN_MOVED_TO))) {
                watchlib_aux_callback(L, w->lua_ref, event->name);
            }
        }

    # elif defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)

        struct timespec timeout = { 0, 0 }; /* Non-blocking poll */
        struct kevent ev;
        int n = kevent(w->kq, NULL, 0, &ev, 1, &timeout);
        if (n > 0) {
            // kqueue signals that directory changed; pass directory path or notification
            watchlib_aux_callback(L, w->lua_ref, w->path);
            // re-add event structure if cleared
            struct kevent readd;
            EV_SET(
                &readd,
                w->fd,
                EVFILT_VNODE,
                EV_ADD | EV_ENABLE | EV_CLEAR,
                NOTE_WRITE | NOTE_EXTEND | NOTE_RENAME | NOTE_DELETE,
                0,
                NULL
            );
            kevent(w->kq, &readd, 1, NULL, 0, NULL);
        }

    # endif

    return 0;
}

static int watchlib_gc(lua_State *L)
{
    watch_data *w = (watch_data *) luaL_checkudata(L, 1, WATCHER_METATABLE_INSTANCE);

    if (! w->path) {
        return 0;
    }

    if (w->lua_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, w->lua_ref);
    }
    if (w->path) {
        lmt_memory_free(w->path);
        w->path = NULL;
    }

    # if defined(_WIN32)

        if (w->hDir != INVALID_HANDLE_VALUE) {
            CancelIo(w->hDir);
            CloseHandle(w->hDir);
        }
        if (w->overlapped.hEvent) {
            CloseHandle(w->overlapped.hEvent);
        }

    # elif defined(__linux__)

        if (w->fd >= 0) {
            if (w->wd >= 0) {
                inotify_rm_watch(w->fd, w->wd);
            }
            close(w->fd);
        }

    # elif defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)

        if (w->fd >= 0) {
            close(w->fd);
        }
        if (w->kq >= 0) {
            close(w->kq);
        }

    # endif

    w->path = NULL; /* A signal that we're done with it. */

    return 0;
}

/*tex

    Currently this one is the same as a garbage collection. We let \LUA\ do the userdata cleanup
    but this way we can make sure that there is no dangling event handler when we're done.

*/

static int watchlib_unregister(lua_State *L)
{
    return watchlib_gc(L);
}

static int watchlib_tostring(lua_State *L)
{
    watch_data *w = (watch_data *) luaL_checkudata(L, 1, WATCHER_METATABLE_INSTANCE);
    if (w) {
        lua_pushfstring(L, "<watcher %p : %s>", w, w->path ? w->path : "not active");
        return 1;
    } else {
        return 0;
    }
}

static const struct luaL_Reg watchlib_function_list[] = {
    { "register",   watchlib_register   },
    { "unregister", watchlib_unregister },
    { "check",      watchlib_check      },
    /* */
    { "tostring",   watchlib_tostring   },
    /* */
    { "__gc",       watchlib_gc         },
    /* */
    { NULL,         NULL                }
};

int luaopen_watcher(lua_State *L)
{
    luaL_newmetatable(L, WATCHER_METATABLE_INSTANCE);
    luaL_setfuncs(L, watchlib_function_list, 0);
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, -2);
    lua_settable(L, -3);
    lua_pushliteral(L, "__tostring");
    lua_pushliteral(L, "tostring");
    lua_gettable(L, -3);
    lua_settable(L, -3);
    lua_pushliteral(L, "__name");
    lua_pushliteral(L, "watcher");
    lua_settable(L, -3);
    return 1;
}
