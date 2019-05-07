/*

    Copyright 2019 LuaTeX team <bugs@@luatex.org>

    This file is part of LuaTeX.

    LuaTeX is free software; you can redistribute it and/or modify it under the
    terms of the GNU General Public License as published by the Free Software
    Foundation; either version 2 of the License, or (at your option) any later
    version.

    LuaTeX is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
    A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
    details.

    You should have received a copy of the GNU General Public License along with
    LuaTeX; if not, see <http://www.gnu.org/licenses/>.

*/

/*tex

The \PNG\ and \SVG\ backends are not available in \LUATEX, because it's complex
to manage the math formulas at run time. In this respect \POSTSCRIPT\ and the
highlevel |objects| are better, and they are the standard way. Another problem is
how to emit the warning: the |normal_warning| function is not available when
\LUATEX\ is called as \LUA\ only.

*/

# include <stdio.h>

# include "luamplib/mplibstuff.h"

extern void normal_warning(const char *t, const char *p);

/*
# define mplibstuff_message(MSG) do { \
    if (luatex_state.lua_only) { \
        fprintf(stdout,"mplib: " #MSG " not available.\n"); \
    } else { \
        normal_warning("mplib",  #MSG " not available."); \
    } \
} while (0)
*/

# define mplibstuff_message(MSG) \
    normal_warning("mplib",  #MSG " not available.");

void mp_png_backend_initialize (void *mp)
{
    (void) (mp);
    return;
}

void mp_png_backend_free (void *mp)
{
    (void) (mp);
    return;
}

int mp_png_gr_ship_out (void *hh, void *options, int standalone)
{
    (void) (hh);
    (void) (options);
    (void) (standalone);
    mplibstuff_message(png backend);
    return 1;
}

int mp_png_ship_out (void *hh, const char *options)
{
    (void) (hh);
    (void) (options);
    mplibstuff_message(png backend);
    return 1;
}

void mp_svg_backend_initialize (void *mp)
{
    (void) (mp);
    return;
}

void mp_svg_backend_free (void *mp)
{
    (void) (mp);
    return;
}

int mp_svg_ship_out (void *hh, int prologues)
{
    (void) (hh);
    (void) (prologues);
    mplibstuff_message(svg backend);
    return 1;
}

int mp_svg_gr_ship_out (void *hh, int prologues, int standalone)
{
    (void) (hh);
    (void) (prologues);
    (void) (standalone);
    mplibstuff_message(svg backend);
    return 1;
}

void *mp_initialize_binary_math(void *mp)
{
    (void) (mp);
    mplibstuff_message(math binary);
    return NULL;
}

const char* cairo_version_string (void)
{
    return CAIRO_VERSION_STRING;
}

const char* mpfr_get_version(void)
{
    return MPFR_VERSION_STRING;
}

const char* pixman_version_string (void)
{
    return PIXMAN_VERSION_STRING;
}
