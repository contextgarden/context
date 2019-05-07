/*3:*/
#line 78 "../../../source/texk/web2c/mplibdir/pngout.w"

#ifndef MPPNGOUT_H
#define MPPNGOUT_H 1
#include "cairo.h"
const char*COMPILED_CAIRO_VERSION_STRING= CAIRO_VERSION_STRING;
#include "pixman.h"
const char*COMPILED_PIXMAN_VERSION_STRING= PIXMAN_VERSION_STRING;
#define PNG_SKIP_SETJMP_CHECK 1
#include "png.h"
#include "mplib.h"
#include "mpmp.h"
#include "mplibps.h"
typedef struct pngout_data_struct{
/*6:*/
#line 112 "../../../source/texk/web2c/mplibdir/pngout.w"

cairo_surface_t*surface;
cairo_t*cr;

/*:6*//*7:*/
#line 119 "../../../source/texk/web2c/mplibdir/pngout.w"

integer dx;
integer dy;

/*:7*//*23:*/
#line 420 "../../../source/texk/web2c/mplibdir/pngout.w"

mp_edge_object**psfonts;
int font_max;
int last_fnum;

/*:23*/
#line 91 "../../../source/texk/web2c/mplibdir/pngout.w"

}pngout_data_struct;
/*4:*/
#line 96 "../../../source/texk/web2c/mplibdir/pngout.w"

void mp_png_backend_initialize(MP mp);
void mp_png_backend_free(MP mp);

/*:4*//*30:*/
#line 586 "../../../source/texk/web2c/mplibdir/pngout.w"

int mp_png_gr_ship_out(mp_edge_object*hh,const char*options,int standalone);

/*:30*/
#line 93 "../../../source/texk/web2c/mplibdir/pngout.w"

#endif

/*:3*/
