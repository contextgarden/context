/*
    See license.txt in the root of this project.
*/

# include <stdio.h>
# include <sys/stat.h>

# include "auxfile.h"
# include "auxmemory.h"

# ifdef _WIN32

    # include <windows.h>
    # include <ctype.h>
    # include <io.h>
    # include <shellapi.h>

    LPWSTR aux_utf8_to_wide(const char *utf8str) {
        if (utf8str) {
            int length = MultiByteToWideChar(CP_UTF8, 0, utf8str, -1, NULL, 0); /* preroll */
            LPWSTR wide = (LPWSTR) lmt_memory_malloc(sizeof(WCHAR) * length);
            MultiByteToWideChar(CP_UTF8, 0, utf8str, -1, wide, length);
            return wide;
        } else {
            return NULL;
        }
    }

    char *aux_utf8_from_wide(LPWSTR widestr) {
        if (widestr) {
            int length = WideCharToMultiByte(CP_UTF8, 0, widestr, -1, NULL, 0, NULL, NULL);
            char * utf8str = (char *) lmt_memory_malloc(sizeof(char) * length);
            WideCharToMultiByte(CP_UTF8, 0, widestr, -1, utf8str, length, NULL, NULL);
            return (char *) utf8str;
        } else {
            return NULL;
        }
    }

    FILE *aux_utf8_fopen(const char *path, const char *mode) {
        if (path && mode) {
            LPWSTR wpath = aux_utf8_to_wide(path);
            LPWSTR wmode = aux_utf8_to_wide(mode);
            FILE *f = _wfopen(wpath,wmode);
            lmt_memory_free(wpath);
            lmt_memory_free(wmode);
            return f;
        } else {
            return NULL;
        }
    }

    FILE *aux_utf8_popen(const char *path, const char *mode) {
        if (path && mode) {
            LPWSTR wpath = aux_utf8_to_wide(path);
            LPWSTR wmode = aux_utf8_to_wide(mode);
            FILE *f = _wpopen(wpath,wmode);
            lmt_memory_free(wpath);
            lmt_memory_free(wmode);
            return f;
        } else {
            return NULL;
        }
    }

    int aux_utf8_system(const char *cmd)
    {
        LPWSTR wcmd = aux_utf8_to_wide(cmd);
        int result = _wsystem(wcmd);
        lmt_memory_free(wcmd);
        return result;
    }

    int aux_utf8_remove(const char *name)
    {
        LPWSTR wname = aux_utf8_to_wide(name);
        int result = _wremove(wname);
        lmt_memory_free(wname);
        return result;
    }

    int aux_utf8_rename(const char *oldname, const char *newname)
    {
        LPWSTR woldname = aux_utf8_to_wide(oldname);
        LPWSTR wnewname = aux_utf8_to_wide(newname);
        int result = _wrename(woldname, wnewname);
        lmt_memory_free(woldname);
        lmt_memory_free(wnewname);
        return result;
    }

    int aux_utf8_setargv(char * **av, char **argv, int argc)
    {
        if (argv) {
            int c = 0;
            LPWSTR *l = CommandLineToArgvW(GetCommandLineW(), &c);
            if (l != NULL) {
                char **v = lmt_memory_malloc(sizeof(char *) * c);
                for (int i = 0; i < c; i++) {
                    v[i] = aux_utf8_from_wide(l[i]);
                }
                *av = v;
                /*tex Let's be nice with path names: |c:\\foo\\etc| */
                if (c > 1) {
                    if ((strlen(v[c-1]) > 2) && isalpha(v[c-1][0]) && (v[c-1][1] == ':') && (v[c-1][2] == '\\')) {
                        for (char *p = v[c-1]+2; *p; p++) {
                            if (*p == '\\') {
                                *p = '/';
                            }
                        }
                    }
                }
            }
            return c;
        } else {
            *av = NULL;
            return argc;
        }
    }

    char *aux_utf8_getownpath(const char *file)
    {
        if (file) {
            char *path = NULL;
            char buffer[MAX_PATH];
            GetModuleFileName(NULL,buffer,sizeof(buffer));
            path = lmt_memory_strdup(buffer);
            if (strlen(path) > 0) {
                for (size_t i = 0; i < strlen(path); i++) {
                    if (path[i] == '\\') {
                        path[i] = '/';
                    }
                }
                return path;
            }
        }
        return lmt_memory_strdup(".");
    }

# else

    # include <string.h>
    # include <stdlib.h>
    # include <unistd.h>

    int aux_utf8_setargv(char * **av, char **argv, int argc)
    {
        *av = argv;
        return argc;
    }

    char *aux_utf8_getownpath(const char *file)
    {
        if (strchr(file, '/')) {
            return lmt_memory_strdup(file);
        } else {
            const char *esp;
            size_t prefixlen = 0;
            size_t totallen = 0;
            size_t filelen = strlen(file);
            char *path = NULL;
            char *searchpath = lmt_memory_strdup(getenv("PATH"));
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
                        path = lmt_memory_malloc(totallen + 1);
                        memcpy(path, index, prefixlen);
                        memcpy(path + prefixlen, file, filelen);
                    } else {
                        totallen = prefixlen + filelen + 1;
# ifdef PATH_MAX
                        if (totallen >= PATH_MAX) {
                            continue;
                        }
# endif
                        path = lmt_memory_malloc(totallen + 1);
                        memcpy(path, index, prefixlen);
                        path[prefixlen] = '/';
                        memcpy(path + prefixlen + 1, file, filelen);
                    }
                    path[totallen] = '\0';
                    if (access(path, X_OK) >= 0) {
                        break;
                    }
                    lmt_memory_free(path);
                    path = NULL;
                    index = esp + 1;
                } while (esp);
            }
            lmt_memory_free(searchpath);
            if (path) {
                return path;
            } else {
                return lmt_memory_strdup("."); /* ok? */
            }
        }
    }

# endif

# ifndef S_ISREG
    # define S_ISREG(mode) (mode & _S_IFREG)
# endif

# ifdef _WIN32

    char *aux_basename(const char *name) {
        char base[256+1];
        char suff[256+1];
        _splitpath(name,NULL,NULL,base,suff);
        {
            size_t b = strlen((const char*)base);
            size_t s = strlen((const char*)suff);
            char *result = (char *) lmt_memory_malloc(sizeof(char) * (b+s+1));
            if (result) {
                memcpy(&result[0], &base[0], b);
                memcpy(&result[b], &suff[0], s);
                result[b + s] = '\0';
            }
            return result;
        }
    }

    char *aux_dirname(const char *name) {
        char driv[256 + 1];
        char path[256 + 1];
        _splitpath(name,driv,path,NULL,NULL);
        {
            size_t d = strlen((const char*)driv);
            size_t p = strlen((const char*)path);
            char *result = (char *) lmt_memory_malloc(sizeof(char) * (d+p+1));
            if (result) {
                if (path[p - 1] == '/' || path[p - 1] == '\\') {
                    --p;
                }
                memcpy(&result[0], &driv[0], d);
                memcpy(&result[d], &path[0], p);
                result[d + p] = '\0';
            }
            return result;
        }
    }

    int aux_is_readable(const char *filename)
    {
        struct _stati64 info;
        LPWSTR w = aux_utf8_to_wide(filename);
        int r = _wstati64(w, &info);
        FILE *f;
        lmt_memory_free(w);
        return (r == 0)
            && (S_ISREG(info.st_mode))
            && ((f = aux_utf8_fopen(filename, "r")) != NULL)
            && ! fclose(f);
    }

# else

    # include <libgen.h>

    int aux_is_readable(const char *filename)
    {
        struct stat finfo;
        FILE *f;
        return (stat(filename, &finfo) == 0)
            && S_ISREG(finfo.st_mode)
            && ((f = fopen(filename, "r")) != NULL)
            && ! fclose(f);
    }

# endif
