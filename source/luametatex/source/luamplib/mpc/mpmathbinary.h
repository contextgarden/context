/*3:*/
#line 35 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

#ifndef MPMATHBINARY_H
#define  MPMATHBINARY_H 1
#include "mplib.h"
#include "mpmp.h" 
#include <gmp.h> 
#include <mpfr.h> 

#ifdef HAVE_CONFIG_H
#define MP_STR_HELPER(x) #x
#define MP_STR(x) MP_STR_HELPER(x)
const char*const COMPILED_gmp_version= MP_STR(__GNU_MP_VERSION)"."MP_STR(__GNU_MP_VERSION_MINOR)"."MP_STR(__GNU_MP_VERSION_PATCHLEVEL);
#else
const char*const COMPILED_gmp_version= "unknown";
#endif

const char*COMPILED_MPFR_VERSION_STRING= MPFR_VERSION_STRING;
int COMPILED__GNU_MP_VERSION= __GNU_MP_VERSION;
int COMPILED__GNU_MP_VERSION_MINOR= __GNU_MP_VERSION_MINOR;
int COMPILED__GNU_MP_VERSION_PATCHLEVEL= __GNU_MP_VERSION_PATCHLEVEL;

/*8:*/
#line 198 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"

void*mp_initialize_binary_math(MP mp);

/*:8*/
#line 56 "../../../source/texk/web2c/mplibdir/mpmathbinary.w"
;
#endif

/*:3*/
