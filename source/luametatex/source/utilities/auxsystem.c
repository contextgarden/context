/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex This code is taken from the \LUA\ socket library: |timeout.c|. */

# ifdef _WIN32

    double aux_get_current_time(void) {
        FILETIME ft;
        double t;
        GetSystemTimeAsFileTime(&ft);
        /* Windows file time (time since January 1, 1601 (UTC)) */
        t  = ft.dwLowDateTime/1.0e7 + ft.dwHighDateTime*(4294967296.0/1.0e7);
        /* convert to Unix Epoch time (time since January 1, 1970 (UTC)) */
        return (t - 11644473600.0);
    }

# else

    double aux_get_current_time(void) {
        struct timeval v;
        gettimeofday(&v, (struct timezone *) NULL);
        /* Unix Epoch time (time since January 1, 1970 (UTC)) */
        return v.tv_sec + v.tv_usec/1.0e6;
    }

# endif

void aux_set_run_time(void)
{
    lmt_main_state.start_time = aux_get_current_time();
}

double aux_get_run_time(void)
{
    return aux_get_current_time() - lmt_main_state.start_time;
}

/*tex

    In order to avoid all kind of time code in the backend code we use a function. The start time
    can be overloaded in several ways:

    \startitemize[n]
        \startitem
            By setting the environmment variable |SOURCE_DATE_EPOCH|. This will influence the \PDF\
            timestamp and \PDF\ id that is derived from the time. This variable is consulted when
            the kpse library is enabled which is analogue to other properties.
        \stopitem
        \startitem
            By setting the |texconfig.start_time| variable (as with other variables we use the
            internal name there). This has the same effect as (1) and is provided for when kpse is
            not used to set these variables or when an overloaded is wanted. This is analogue to
            other properties.
        \stopitem
    \stopitemize

    To some extend a cleaner solution would be to have a flag that disables all variable data in
    one go (like filenames and so) but we just follow the method implemented in pdftex where
    primitives are used to disable it.

*/

static int start_time = -1; /*tex This will move to one of the structs. */

static int aux_get_start_time(void) {
    if (start_time < 0) {
        start_time = (int) time((time_t *) NULL);
    }
    return start_time;
}

/*tex

    This one is used to fetch a value from texconfig which can also be used to set properties.
    This might come in handy when one has other ways to get date info in the \PDF\ file.

*/

void aux_set_start_time(int s) {
    if (s >= 0) {
        start_time = s ;
    }
}

/*tex

    All our interrupt handler has to do is set \TEX's global variable |interrupt|; then they
    will do everything needed.

*/

# ifdef _WIN32

    /* Win32 doesn't set SIGINT ... */

    static BOOL WINAPI catch_interrupt(DWORD arg)
    {
        switch (arg) {
            case CTRL_C_EVENT:
            case CTRL_BREAK_EVENT:
                aux_quit_the_program();
                return 1;
            default:
                /*tex No need to set interrupt as we are exiting anyway. */
                return 0;
        }
    }

    void aux_set_interrupt_handler(void)
    {
        SetConsoleCtrlHandler(catch_interrupt, TRUE);
    }

# else

    /* static RETSIGTYPE catch_interrupt(int arg) */

    static void catch_interrupt(int arg)
    {
        (void) arg;
        aux_quit_the_program();
        (void) signal(SIGINT, catch_interrupt);
    }

    void aux_set_interrupt_handler(void)
    {
        /* RETSIGTYPE (*old_handler) (int); */
        void (*old_handler) (int);
        old_handler = signal(SIGINT, catch_interrupt);
        if (old_handler != SIG_DFL) {
            signal(SIGINT, old_handler);
        }
    }

# endif

void aux_get_date_and_time(int *minutes, int *day, int *month, int *year, int *utc)
{
    time_t myclock = aux_get_start_time();
    struct tm *tmptr ;
    if (*utc) {
        tmptr = gmtime(&myclock);
    } else {
        tmptr = localtime(&myclock);
    }
    *minutes = tmptr->tm_hour * 60 + tmptr->tm_min;
    *day = tmptr->tm_mday;
    *month = tmptr->tm_mon + 1;
    *year = tmptr->tm_year + 1900;
 /* set_interrupt_handler(); */
}
