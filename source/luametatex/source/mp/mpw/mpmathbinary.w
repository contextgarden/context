% This file is part of MetaPost. The MetaPost program is in the public domain.

@ @(mpmathbinary.h@>=
# ifndef MPMATHBINARY_H
# define MPMATHBINARY_H 1

# include "mp.h"

math_data *mp_initialize_binary_math (MP mp);

# endif

@ @c
# include <stdio.h>

@ @c
# include "mpconfig.h"
# include "mpmathbinary.h"

extern void tex_normal_warning (const char *t, const char *p);

math_data *mp_initialize_binary_math (MP mp)
{
    (void) (mp);
    tex_normal_warning("mplib", "binary mode is not available.");
    return NULL;
}
