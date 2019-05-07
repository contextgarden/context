/*1:*/
#line 57 "../../../source/texk/web2c/mplibdir/psout.w"

#include <w2c/config.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <assert.h>
#include <math.h>
#include "avl.h"
#include "mplib.h"
#include "mplibps.h"
#include "mpmp.h"
#include "mppsout.h"
#include "mpmath.h"
#include "mpstrings.h"
#define zero_t ((math_data*) mp->math) ->zero_t
#define number_zero(A) (((math_data*) (mp->math) ) ->equal) (A,zero_t)
#define number_greater(A,B) (((math_data*) (mp->math) ) ->greater) (A,B)
#define number_positive(A) number_greater(A,zero_t)
#define number_to_scaled(A) (((math_data*) (mp->math) ) ->to_scaled) (A)
#define round_unscaled(A) (((math_data*) (mp->math) ) ->round_unscaled) (A)
#define true 1
#define false 0
#define null_font 0
#define null 0
#define unity 1.0
#define incr(A) (A) = (A) +1
#define decr(A) (A) = (A) -1
#define negate(A) (A) = -(A)
#define odd(A) (abs(A) %2==1)
#define max_quarterword 0x3FFF \

#define wps(A) (mp->write_ascii_file) (mp,mp->output_file,(A) )
#define wps_chr(A) do{ \
char ss[2]; \
ss[0]= (char) (A) ;ss[1]= 0; \
(mp->write_ascii_file) (mp,mp->output_file,(char*) ss) ; \
}while(0)
#define wps_cr (mp->write_ascii_file) (mp,mp->output_file,"\n")
#define wps_ln(A) {wterm_cr;(mp->write_ascii_file) (mp,mp->output_file,(A) ) ;} \

#define ps_room(A) if(mp->ps->ps_offset> 0&&(mp->ps->ps_offset+(int) (A) ) > mp->max_print_line) { \
mp_ps_print_ln(mp) ; \
} \

#define unityold 65536
#define check_buf(size,buf_size)  \
if((unsigned) (size) > (unsigned) (buf_size) ) { \
char S[128]; \
mp_snprintf(S,128,"buffer overflow: (%u,%u) at file %s, line %d", \
(unsigned) (size) ,(unsigned) (buf_size) ,__FILE__,__LINE__) ; \
mp_fatal_error(mp,S) ; \
} \

#define append_char_to_buf(c,p,buf,buf_size) do{ \
if(c==9)  \
c= 32; \
if(c==13||c==EOF)  \
c= 10; \
if(c!=' '||(p> buf&&p[-1]!=32) ) { \
check_buf(p-buf+1,(buf_size) ) ; \
*p++= (char) c; \
} \
}while(0)  \

#define append_eol(p,buf,buf_size) do{ \
check_buf(p-buf+2,(buf_size) ) ; \
if(p-buf> 1&&p[-1]!=10)  \
*p++= 10; \
if(p-buf> 2&&p[-2]==32) { \
p[-2]= 10; \
p--; \
} \
*p= 0; \
}while(0)  \

#define remove_eol(p,buf) do{ \
p= strend(buf) -1; \
if(*p==10)  \
*p= 0; \
}while(0)  \

#define skip(p,c) if(*p==c) p++
#define strend(s) strchr(s,0)
#define str_prefix(s1,s2) (strncmp((s1) ,(s2) ,strlen(s2) ) ==0)  \
 \

#define ENC_STANDARD 0
#define ENC_BUILTIN 1 \

#define enc_eof() (mp->eof_file) (mp,mp->ps->enc_file)
#define enc_close() (mp->close_file) (mp,mp->ps->enc_file)  \

#define FM_BUF_SIZE 1024 \

#define fm_eof() (mp->ps->fm_byte_waiting>=mp->ps->fm_byte_length)
#define fm_close() do{ \
(mp->close_file) (mp,mp->ps->fm_file) ; \
mp_xfree(mp->ps->fm_bytes) ; \
mp->ps->fm_bytes= NULL; \
mp->ps->fm_byte_waiting= 0; \
mp->ps->fm_byte_length= 1; \
}while(0)
#define valid_code(c) (c>=0&&c<256)
#define unwrap_file(ff) (mp->noninteractive?((File*) ff) ->f:ff)  \
 \

#define read_field(r,q,buf) do{ \
q= buf; \
while(*r!=' '&&*r!='\0')  \
*q++= *r++; \
*q= '\0'; \
skip(r,' ') ; \
}while(0)  \

#define set_field(F) do{ \
if(q> buf)  \
fm->F= mp_xstrdup(mp,buf) ; \
if(*r=='\0')  \
goto DONE; \
}while(0)  \

#define cmp_return(a,b)  \
if(a> b)  \
return 1; \
if(a<b)  \
return-1 \

#define do_strdup(a) (a==NULL?NULL:strdup(a) )  \

#define LINK_TFM 0x01
#define LINK_PS 0x02
#define set_tfmlink(fm) ((fm) ->links|= LINK_TFM)
#define set_pslink(fm) ((fm) ->links|= LINK_PS)
#define has_tfmlink(fm) ((fm) ->links&LINK_TFM)
#define has_pslink(fm) ((fm) ->links&LINK_PS)  \

#define is_cfg_comment(c) (c==10||c=='*'||c=='#'||c==';'||c=='%')  \

#define ps_tab_name "psfonts.map" \

#define SMALL_ARRAY_SIZE 256
#define Z_NULL 0 \

#define external_enc() (fm_cur->encoding) ->glyph_names
#define is_used_char(c) mp_char_marked(mp,tex_font,(eight_bits) c)
#define end_last_eexec_line()  \
mp->ps->hexline_length= HEXLINE_WIDTH; \
end_hexline(mp) ; \
mp->ps->t1_eexec_encrypt= false
#define t1_log(s) mp_print(mp,s)
#define t1_putchar(c) wps_chr(c)
#define embed_all_glyphs(tex_font) false
#define t1_char(c) c
#define extra_charset() mp->ps->dvips_extra_charset
#define update_subset_tag()
#define fixedcontent true \

#define t1_ungetchar() mp->ps->t1_byte_waiting--
#define t1_eof() (mp->ps->t1_byte_waiting>=mp->ps->t1_byte_length)
#define t1_close() do{ \
(mp->close_file) (mp,mp->ps->t1_file) ; \
mp_xfree(mp->ps->t1_bytes) ; \
mp->ps->t1_bytes= NULL; \
mp->ps->t1_byte_waiting= 0; \
mp->ps->t1_byte_length= 0; \
}while(0)
#define valid_code(c) (c>=0&&c<256)  \

#define t1_c1 52845
#define t1_c2 22719 \

#define HEXLINE_WIDTH 64 \

#define t1_prefix(s) str_prefix(mp->ps->t1_line_array,s)
#define t1_buf_prefix(s) str_prefix(mp->ps->t1_buf_array,s)
#define t1_suffix(s) str_suffix(mp->ps->t1_line_array,mp->ps->t1_line_ptr,s)
#define t1_buf_suffix(s) str_suffix(mp->ps->t1_buf_array,mp->ps->t1_buf_ptr,s)
#define t1_charstrings() strstr(mp->ps->t1_line_array,charstringname)
#define t1_subrs() t1_prefix("/Subrs")
#define t1_end_eexec() t1_suffix("mark currentfile closefile")
#define t1_cleartomark() t1_prefix("cleartomark")  \

#define alloc_array(T,n,s) do{ \
size_t nn= (size_t) n; \
if(mp->ps->T##_array==NULL) { \
mp->ps->T##_limit= s; \
if(nn> mp->ps->T##_limit)  \
mp->ps->T##_limit= nn; \
mp->ps->T##_array= mp_xmalloc(mp,mp->ps->T##_limit,sizeof(T##_entry) ) ; \
mp->ps->T##_ptr= mp->ps->T##_array; \
} \
else if((size_t) (mp->ps->T##_ptr-mp->ps->T##_array) +nn> mp->ps->T##_limit) { \
size_t last_ptr_index; \
last_ptr_index= (size_t) (mp->ps->T##_ptr-mp->ps->T##_array) ; \
mp->ps->T##_limit*= 2; \
mp->ps->T##_limit+= s; \
if((size_t) (mp->ps->T##_ptr-mp->ps->T##_array) +nn> mp->ps->T##_limit)  \
mp->ps->T##_limit= (size_t) (mp->ps->T##_ptr-mp->ps->T##_array) +nn; \
mp->ps->T##_array= mp_xrealloc(mp,mp->ps->T##_array,mp->ps->T##_limit,sizeof(T##_entry) ) ; \
mp->ps->T##_ptr= mp->ps->T##_array+last_ptr_index; \
} \
}while(0)  \

#define FONT_KEYS_NUM 11 \

#define ASCENT_CODE 0
#define CAPHEIGHT_CODE 1
#define DESCENT_CODE 2
#define FONTNAME_CODE 3
#define ITALIC_ANGLE_CODE 4
#define STEMV_CODE 5
#define XHEIGHT_CODE 6
#define FONTBBOX1_CODE 7
#define FONTBBOX2_CODE 8
#define FONTBBOX3_CODE 9
#define FONTBBOX4_CODE 10
#define MAX_KEY_CODE (FONTBBOX1_CODE+1)  \

#define check_subr(SUBR) if(SUBR>=mp->ps->subr_size||SUBR<0) { \
char s[128]; \
mp_snprintf(s,128,"Subrs array: entry index out of range (%i)",SUBR) ; \
mp_fatal_error(mp,s) ; \
} \

#define cs_getchar(mp) cdecrypt(*data++,&cr)  \

#define mark_subr(mp,n) cs_mark(mp,0,n)
#define mark_cs(mp,s) cs_mark(mp,s,0)
#define SMALL_BUF_SIZE 256 \

#define cs_no_debug(A) cs_do_debug(mp,f,A,#A)
#define cs_debug(A)  \

#define F_INCLUDED 0x01
#define F_SUBSETTED 0x02
#define F_TRUETYPE 0x04
#define F_BASEFONT 0x08 \

#define set_included(fm) ((fm) ->type|= F_INCLUDED)
#define set_subsetted(fm) ((fm) ->type|= F_SUBSETTED)
#define set_truetype(fm) ((fm) ->type|= F_TRUETYPE)
#define set_basefont(fm) ((fm) ->type|= F_BASEFONT)  \

#define is_included(fm) ((fm) ->type&F_INCLUDED)
#define is_subsetted(fm) ((fm) ->type&F_SUBSETTED)
#define is_truetype(fm) ((fm) ->type&F_TRUETYPE)
#define is_basefont(fm) ((fm) ->type&F_BASEFONT)
#define is_reencoded(fm) ((fm) ->encoding!=NULL)
#define is_fontfile(fm) (fm_fontfile(fm) !=NULL)
#define is_t1fontfile(fm) (is_fontfile(fm) &&!is_truetype(fm) )  \

#define fm_slant(fm) (fm) ->slant
#define fm_extend(fm) (fm) ->extend
#define fm_fontfile(fm) (fm) ->ff_name \

#define applied_reencoding(A) ((mp_font_is_reencoded(mp,(A) ) ) && \
((!mp_font_is_subsetted(mp,(A) ) ) ||(prologues==2) ) )  \

#define mp_link(A) (A) ->link
#define sc_factor(A) ((mp_font_size_node) (A) ) ->sc_factor_ \

#define mp_is_ps_name(M,A) mp_do_is_ps_name(A)  \

#define mp_gr_toss_knot_list(B,A) mp_do_gr_toss_knot_list(A)  \

#define bend_tolerance (131/65536.0)  \

#define mp_gr_toss_dashes(A,B) mp_do_gr_toss_dashes(B)  \

#define gr_has_color(A) (gr_type((A) ) <mp_start_clip_code)  \

#define gs_red mp->ps->gs_state->red_field
#define gs_green mp->ps->gs_state->green_field
#define gs_blue mp->ps->gs_state->blue_field
#define gs_black mp->ps->gs_state->black_field
#define gs_colormodel mp->ps->gs_state->colormodel_field
#define gs_ljoin mp->ps->gs_state->ljoin_field
#define gs_lcap mp->ps->gs_state->lcap_field
#define gs_adj_wx mp->ps->gs_state->adj_wx_field
#define gs_miterlim mp->ps->gs_state->miterlim_field
#define gs_dash_p mp->ps->gs_state->dash_p_field
#define gs_dash_init_done mp->ps->gs_state->dash_done_field
#define gs_previous mp->ps->gs_state->previous_field
#define gs_width mp->ps->gs_state->width_field \

#define mp_void (mp_node) (null+1)  \

#define set_ljoin_miterlim(p)  \
if(gs_ljoin!=(quarterword) gr_ljoin_val(p) ) { \
ps_room(14) ; \
mp_ps_print_char(mp,' ') ; \
mp_ps_print_char(mp,'0'+gr_ljoin_val(p) ) ; \
mp_ps_print_cmd(mp," setlinejoin"," lj") ; \
gs_ljoin= (quarterword) gr_ljoin_val(p) ; \
} \
if(gs_miterlim!=gr_miterlim_val(p) ) { \
ps_room(27) ; \
mp_ps_print_char(mp,' ') ; \
mp_ps_print_double(mp,gr_miterlim_val(p) ) ; \
mp_ps_print_cmd(mp," setmiterlimit"," ml") ; \
gs_miterlim= gr_miterlim_val(p) ; \
} \

#define set_color_objects(pq)  \
object_color_model= pq->color_model; \
object_color_a= pq->color.a_val; \
object_color_b= pq->color.b_val; \
object_color_c= pq->color.c_val; \
object_color_d= pq->color.d_val; \

#define aspect_bound 10.0/65536.0 \
 \

#define do_x_loc 1
#define do_y_loc 2 \

#define mp_make_double(A,B,C) ((B) /(C) )
#define mp_take_double(A,B,C) ((B) *(C) )  \

#define fscale_tolerance (65/65536.0)  \

#define font_size_size sizeof(struct mp_font_size_node_data)  \

#define pen_is_elliptical(A) ((A) ==gr_next_knot((A) ) )  \

#define do_write_prescript(a,b) { \
if((gr_pre_script((b*) a) ) !=NULL) { \
mp_ps_print_nl(mp,gr_pre_script((b*) a) ) ; \
mp_ps_print_ln(mp) ; \
} \
} \


#line 72 "../../../source/texk/web2c/mplibdir/psout.w"

/*29:*/
#line 658 "../../../source/texk/web2c/mplibdir/psout.w"

static void enc_free(MP mp);

/*:29*//*31:*/
#line 666 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_reload_encodings(MP mp);
static void mp_font_encodings(MP mp,font_number lastfnum,boolean encodings_only);

/*:31*//*39:*/
#line 780 "../../../source/texk/web2c/mplibdir/psout.w"

static const char nontfm[]= "<nontfm>";

/*:39*//*41:*/
#line 903 "../../../source/texk/web2c/mplibdir/psout.w"

static boolean mp_has_fm_entry(MP mp,font_number f,fm_entry**fm);

/*:41*//*63:*/
#line 1564 "../../../source/texk/web2c/mplibdir/psout.w"

static void fm_free(MP mp);

/*:63*//*92:*/
#line 2321 "../../../source/texk/web2c/mplibdir/psout.w"

static key_entry font_keys[FONT_KEYS_NUM]= {
{"Ascent","Ascender",0,false},
{"CapHeight","CapHeight",0,false},
{"Descent","Descender",0,false},
{"FontName","FontName",0,false},
{"ItalicAngle","ItalicAngle",0,false},
{"StemV","StdVW",0,false},
{"XHeight","XHeight",0,false},
{"FontBBox","FontBBox",0,false},
{"","",0,false},
{"","",0,false},
{"","",0,false}
};


/*:92*//*100:*/
#line 3403 "../../../source/texk/web2c/mplibdir/psout.w"

static void t1_free(MP mp);

/*:100*//*110:*/
#line 3606 "../../../source/texk/web2c/mplibdir/psout.w"

boolean cs_parse(MP mp,mp_ps_font*f,const char*cs_name,int subr);

/*:110*//*112:*/
#line 3709 "../../../source/texk/web2c/mplibdir/psout.w"

void cs_do_debug(MP mp,mp_ps_font*f,int i,char*s);
static void finish_subpath(MP mp,mp_ps_font*f);
static void add_curve_segment(MP mp,mp_ps_font*f,double dx1,double dy1,double dx2,
double dy2,double dx3,double dy3);
static void add_line_segment(MP mp,mp_ps_font*f,double dx,double dy);
static void start_subpath(MP mp,mp_ps_font*f,double dx,double dy);

/*:112*//*117:*/
#line 4097 "../../../source/texk/web2c/mplibdir/psout.w"

static boolean mp_font_is_reencoded(MP mp,font_number f);
static boolean mp_font_is_included(MP mp,font_number f);
static boolean mp_font_is_subsetted(MP mp,font_number f);

/*:117*//*119:*/
#line 4134 "../../../source/texk/web2c/mplibdir/psout.w"

static char*mp_fm_encoding_name(MP mp,font_number f);
static char*mp_fm_font_name(MP mp,font_number f);
static char*mp_fm_font_subset_name(MP mp,font_number f);

/*:119*//*121:*/
#line 4207 "../../../source/texk/web2c/mplibdir/psout.w"

static integer mp_fm_font_slant(MP mp,font_number f);
static integer mp_fm_font_extend(MP mp,font_number f);

/*:121*//*123:*/
#line 4231 "../../../source/texk/web2c/mplibdir/psout.w"

static boolean mp_do_ps_font(MP mp,font_number f);

/*:123*//*125:*/
#line 4261 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_list_used_resources(MP mp,int prologues,int procset);

/*:125*//*127:*/
#line 4330 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_list_supplied_resources(MP mp,int prologues,int procset);

/*:127*//*129:*/
#line 4401 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_list_needed_resources(MP mp,int prologues);

/*:129*//*131:*/
#line 4457 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_write_font_definition(MP mp,font_number f,int prologues);

/*:131*//*133:*/
#line 4512 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_print_defined_name(MP mp,font_number f,int prologues);

/*:133*//*139:*/
#line 4588 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_mark_string_chars(MP mp,font_number f,char*s,size_t l);

/*:139*//*141:*/
#line 4608 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_unmark_font(MP mp,font_number f);

/*:141*//*143:*/
#line 4621 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_print_improved_prologue(MP mp,mp_edge_object*h,int p1,int procset);

/*:143*//*145:*/
#line 4682 "../../../source/texk/web2c/mplibdir/psout.w"

static font_number mp_print_font_comments(MP mp,mp_edge_object*h,int prologues);


/*:145*//*150:*/
#line 4760 "../../../source/texk/web2c/mplibdir/psout.w"

static halfword mp_ps_marks_out(MP mp,font_number f);

/*:150*//*155:*/
#line 4821 "../../../source/texk/web2c/mplibdir/psout.w"

static boolean mp_check_ps_marks(MP mp,font_number f);

/*:155*//*159:*/
#line 4880 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_print_prologue(MP mp,mp_edge_object*h,int prologues,int procset);

/*:159*//*163:*/
#line 4946 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_pair_out(MP mp,double x,double y);

/*:163*//*165:*/
#line 4955 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_print_cmd(MP mp,const char*l,const char*s);

/*:165*//*167:*/
#line 4982 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_string_out(MP mp,const char*s,size_t l);

/*:167*//*169:*/
#line 5000 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_name_out(MP mp,char*s,boolean lit);

/*:169*//*171:*/
#line 5030 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_print_initial_comment(MP mp,mp_edge_object*hh,int prologues);

/*:171*//*177:*/
#line 5130 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_do_gr_toss_knot_list(mp_gr_knot p);

/*:177*//*184:*/
#line 5230 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_do_gr_toss_dashes(mp_dash_object*dl);

/*:184*//*196:*/
#line 5509 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_gr_fix_graphics_state(MP mp,mp_graphic_object*p);

/*:196*//*204:*/
#line 5740 "../../../source/texk/web2c/mplibdir/psout.w"

static boolean mp_gr_coord_rangeOK(mp_gr_knot h,
quarterword zoff,double dz);

/*:204*//*209:*/
#line 5831 "../../../source/texk/web2c/mplibdir/psout.w"

static boolean mp_gr_same_dashes(mp_dash_object*h,mp_dash_object*hh);

/*:209*//*212:*/
#line 5869 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_gr_stroke_ellipse(MP mp,mp_graphic_object*h,boolean fill_also);

/*:212*//*218:*/
#line 6002 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_gr_ps_fill_out(MP mp,mp_gr_knot p);

/*:218*//*220:*/
#line 6022 "../../../source/texk/web2c/mplibdir/psout.w"

static double mp_gr_choose_scale(MP mp,mp_graphic_object*p);

/*:220*//*222:*/
#line 6054 "../../../source/texk/web2c/mplibdir/psout.w"

static quarterword mp_size_index(MP mp,font_number f,double s);

/*:222*//*224:*/
#line 6080 "../../../source/texk/web2c/mplibdir/psout.w"

static double mp_indexed_size(MP mp,font_number f,quarterword j);

/*:224*//*226:*/
#line 6100 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_clear_sizes(MP mp);

/*:226*//*229:*/
#line 6130 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_apply_mark_string_chars(MP mp,mp_edge_object*h,int next_size);

/*:229*/
#line 73 "../../../source/texk/web2c/mplibdir/psout.w"

/*24:*/
#line 560 "../../../source/texk/web2c/mplibdir/psout.w"

static char notdef[]= ".notdef";

/*:24*//*78:*/
#line 1821 "../../../source/texk/web2c/mplibdir/psout.w"

static const char*standard_glyph_names[256]=
{notdef,notdef,notdef,notdef,notdef,notdef,notdef,notdef,
notdef,notdef,notdef,notdef,notdef,notdef,notdef,notdef,notdef,
notdef,notdef,notdef,notdef,notdef,notdef,
notdef,notdef,notdef,notdef,notdef,notdef,notdef,notdef,notdef,
"space","exclam","quotedbl","numbersign",
"dollar","percent","ampersand","quoteright","parenleft",
"parenright","asterisk","plus","comma","hyphen","period",
"slash","zero","one","two","three","four","five","six","seven",
"eight","nine","colon","semicolon","less",
"equal","greater","question","at","A","B","C","D","E","F",
"G","H","I","J","K","L","M","N","O","P","Q",
"R","S","T","U","V","W","X","Y","Z","bracketleft",
"backslash","bracketright","asciicircum","underscore",
"quoteleft","a","b","c","d","e","f","g","h","i","j","k",
"l","m","n","o","p","q","r","s","t","u","v",
"w","x","y","z","braceleft","bar","braceright","asciitilde",
notdef,notdef,notdef,notdef,notdef,notdef,notdef,
notdef,notdef,notdef,notdef,notdef,notdef,notdef,notdef,notdef,
notdef,notdef,notdef,notdef,notdef,notdef,
notdef,notdef,notdef,notdef,notdef,notdef,notdef,notdef,notdef,
notdef,notdef,notdef,"exclamdown","cent",
"sterling","fraction","yen","florin","section","currency",
"quotesingle","quotedblleft","guillemotleft",
"guilsinglleft","guilsinglright","fi","fl",notdef,"endash",
"dagger","daggerdbl","periodcentered",notdef,
"paragraph","bullet","quotesinglbase","quotedblbase",
"quotedblright","guillemotright","ellipsis","perthousand",
notdef,"questiondown",notdef,"grave","acute","circumflex",
"tilde","macron","breve","dotaccent","dieresis",notdef,
"ring","cedilla",notdef,"hungarumlaut","ogonek","caron","emdash",
notdef,notdef,notdef,notdef,notdef,notdef,
notdef,notdef,notdef,notdef,notdef,notdef,notdef,notdef,notdef,
notdef,"AE",notdef,"ordfeminine",notdef,notdef,
notdef,notdef,"Lslash","Oslash","OE","ordmasculine",notdef,
notdef,notdef,notdef,notdef,"ae",notdef,notdef,
notdef,"dotlessi",notdef,notdef,"lslash","oslash","oe",
"germandbls",notdef,notdef,notdef,notdef};
static const char charstringname[]= "/CharStrings";

/*:78*//*86:*/
#line 1954 "../../../source/texk/web2c/mplibdir/psout.w"

static const char*cs_token_pairs_list[][2]= {
{" RD","NP"},
{" -|","|"},
{" RD","noaccess put"},
{" -|","noaccess put"},
{NULL,NULL}
};

/*:86*/
#line 74 "../../../source/texk/web2c/mplibdir/psout.w"


/*:1*//*4:*/
#line 94 "../../../source/texk/web2c/mplibdir/psout.w"

static boolean mp_isdigit(int a){
return(a>='0'&&a<='9');
}
static int mp_tolower(int a){
if(a>='A'&&a<='Z')
return a-'A'+'a';
return a;
}
static int mp_strcasecmp(const char*s1,const char*s2){
int r;
char*ss1,*ss2,*c;
ss1= mp_strdup(s1);
c= ss1;
while(*c!='\0'){
*c= (char)mp_tolower(*c);c++;
}
ss2= mp_strdup(s2);
c= ss2;
while(*c!='\0'){
*c= (char)mp_tolower(*c);c++;
}
r= strcmp(ss1,ss2);
free(ss1);free(ss2);
return r;
}

/*:4*//*6:*/
#line 126 "../../../source/texk/web2c/mplibdir/psout.w"
void mp_ps_backend_initialize(MP mp){
mp->ps= mp_xmalloc(mp,1,sizeof(psout_data_struct));
memset(mp->ps,0,sizeof(psout_data_struct));
/*8:*/
#line 146 "../../../source/texk/web2c/mplibdir/psout.w"

mp->ps->ps_offset= 0;

/*:8*//*25:*/
#line 563 "../../../source/texk/web2c/mplibdir/psout.w"

mp->ps->enc_tree= NULL;

/*:25*//*34:*/
#line 722 "../../../source/texk/web2c/mplibdir/psout.w"

mp->ps->fm_byte_waiting= 0;
mp->ps->fm_byte_length= 1;
mp->ps->fm_bytes= NULL;

/*:34*//*38:*/
#line 777 "../../../source/texk/web2c/mplibdir/psout.w"

mp->ps->mitem= NULL;

/*:38*//*44:*/
#line 921 "../../../source/texk/web2c/mplibdir/psout.w"

mp->ps->tfm_tree= NULL;
mp->ps->ps_tree= NULL;
mp->ps->ff_tree= NULL;

/*:44*//*70:*/
#line 1636 "../../../source/texk/web2c/mplibdir/psout.w"

mp->ps->char_array= NULL;
mp->ps->job_id_string= NULL;

/*:70*//*76:*/
#line 1789 "../../../source/texk/web2c/mplibdir/psout.w"

mp->ps->dvips_extra_charset= NULL;
mp->ps->t1_byte_waiting= 0;
mp->ps->t1_byte_length= 0;
mp->ps->t1_bytes= NULL;

/*:76*//*85:*/
#line 1946 "../../../source/texk/web2c/mplibdir/psout.w"

mp->ps->t1_line_array= NULL;
mp->ps->t1_buf_array= NULL;

/*:85*//*88:*/
#line 1975 "../../../source/texk/web2c/mplibdir/psout.w"

mp->ps->hexline_length= 0;

/*:88*//*94:*/
#line 2596 "../../../source/texk/web2c/mplibdir/psout.w"

{
int i;
for(i= 0;i<256;i++){
mp->ps->t1_builtin_glyph_names[i]= strdup(notdef);
assert(mp->ps->t1_builtin_glyph_names[i]);
}
}

/*:94*//*193:*/
#line 5456 "../../../source/texk/web2c/mplibdir/psout.w"

mp->ps->gs_state= NULL;

/*:193*/
#line 129 "../../../source/texk/web2c/mplibdir/psout.w"
;
}
void mp_ps_backend_free(MP mp){
/*62:*/
#line 1558 "../../../source/texk/web2c/mplibdir/psout.w"

if(mp->ps->mitem!=NULL){
mp_xfree(mp->ps->mitem->map_line);
mp_xfree(mp->ps->mitem);
}

/*:62*//*73:*/
#line 1679 "../../../source/texk/web2c/mplibdir/psout.w"

mp_xfree(mp->ps->job_id_string);

/*:73*//*194:*/
#line 5459 "../../../source/texk/web2c/mplibdir/psout.w"

mp_xfree(mp->ps->gs_state);

/*:194*/
#line 132 "../../../source/texk/web2c/mplibdir/psout.w"
;
enc_free(mp);
t1_free(mp);
fm_free(mp);
mp_xfree(mp->ps);
mp->ps= NULL;
}

/*:6*//*9:*/
#line 160 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_print_ln(MP mp){
wps_cr;
mp->ps->ps_offset= 0;
}

/*:9*//*10:*/
#line 166 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_print_char(MP mp,int s){
if(s==13){
wps_cr;mp->ps->ps_offset= 0;
}else{
wps_chr(s);incr(mp->ps->ps_offset);
}
}

/*:10*//*11:*/
#line 175 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_do_print(MP mp,const char*ss,size_t len){
size_t j= 0;
if(len> 255){
while(j<len){
mp_ps_print_char(mp,ss[j]);incr(j);
}
}else{
static char outbuf[256];
strncpy(outbuf,ss,len+1);
while(j<len){
if(*(outbuf+j)==13){
*(outbuf+j)= '\n';
mp->ps->ps_offset= 0;
}else{
mp->ps->ps_offset++;
}
j++;
}
(mp->write_ascii_file)(mp,mp->output_file,outbuf);
}
}

/*:11*//*12:*/
#line 204 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_print(MP mp,const char*ss){
ps_room(strlen(ss));
mp_ps_do_print(mp,ss,strlen(ss));
}
static void mp_ps_dsc_print(MP mp,const char*dsc,const char*ss){
ps_room(strlen(ss));
if(mp->ps->ps_offset==0){
mp_ps_do_print(mp,"%%+ ",4);
mp_ps_do_print(mp,dsc,strlen(dsc));
mp_ps_print_char(mp,' ');
}
mp_ps_do_print(mp,ss,strlen(ss));
}

/*:12*//*13:*/
#line 222 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_print_nl(MP mp,const char*s){
if(mp->ps->ps_offset> 0)mp_ps_print_ln(mp);
mp_ps_print(mp,s);
}

/*:13*//*14:*/
#line 234 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_print_int(MP mp,integer n){
integer m;
char outbuf[24];
unsigned char dig[23];
int k= 0;
int l= 0;
if(n<0){
mp_ps_print_char(mp,'-');
if(n> -100000000){
negate(n);
}else{
m= -1-n;n= m/10;m= (m%10)+1;k= 1;
if(m<10){
dig[0]= (unsigned char)m;
}else{
dig[0]= 0;incr(n);
}
}
}
do{
dig[k]= (unsigned char)(n%10);n= n/10;incr(k);
}while(n!=0);

while(k--> 0){
outbuf[l++]= (char)('0'+dig[k]);
}
outbuf[l]= '\0';
(mp->write_ascii_file)(mp,mp->output_file,outbuf);
}

/*:14*//*15:*/
#line 268 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_print_dd(MP mp,integer n){
n= abs(n)%100;
mp_ps_print_char(mp,'0'+(n/10));
mp_ps_print_char(mp,'0'+(n%10));
}

/*:15*//*16:*/
#line 285 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_ps_print_double_new(MP mp,double s){
char*value,*c;
int i;
value= mp_xmalloc(mp,1,32);
memset(value,0,32);
mp_snprintf(value,32,"%.6f",s);
for(i= 31;i>=0;i--){
if(value[i]){
if(value[i]=='0')
value[i]= '\0';
else
break;
}
}
if(value[i]=='.')
value[i]= '\0';
c= value;
while(*c){
mp_ps_print_char(mp,*c);
c++;
}
free(value);
}

static void mp_ps_print_double_scaled(MP mp,double ss){
int delta;
int s= ss*unityold;
if(s<0){
mp_ps_print_char(mp,'-');
negate(s);
}
mp_ps_print_int(mp,s/unityold);
s= 10*(s%unityold)+5;
if(s!=5){
delta= 10;
mp_ps_print_char(mp,'.');
do{
if(delta> unityold)
s= s+0100000-(delta/2);
mp_ps_print_char(mp,'0'+(s/unityold));
s= 10*(s%unityold);
delta= delta*10;
}while(s> delta);
}
}
static void mp_ps_print_double(MP mp,double s){
if(mp->math_mode==mp_math_scaled_mode){
mp_ps_print_double_scaled(mp,s);
}else{
mp_ps_print_double_new(mp,s);
}
}


/*:16*//*20:*/
#line 410 "../../../source/texk/web2c/mplibdir/psout.w"

static int enc_getchar(MP mp){
size_t len= 1;
unsigned char abyte= 0;
void*byte_ptr= &abyte;
(mp->read_binary_file)(mp,mp->ps->enc_file,&byte_ptr,&len);
return abyte;
}

/*:20*//*21:*/
#line 419 "../../../source/texk/web2c/mplibdir/psout.w"

static boolean mp_enc_open(MP mp,char*n){
mp->ps->enc_file= (mp->open_file)(mp,n,"r",mp_filetype_encoding);
if(mp->ps->enc_file!=NULL)
return true;
else
return false;
}
static void mp_enc_getline(MP mp){
char*p;
int c;
RESTART:
if(enc_eof()){
mp_error(mp,"unexpected end of file",NULL,true);
}
p= mp->ps->enc_line;
do{
c= enc_getchar(mp);
append_char_to_buf(c,p,mp->ps->enc_line,ENC_BUF_SIZE);
}while(c&&c!=10);
append_eol(p,mp->ps->enc_line,ENC_BUF_SIZE);
if(p-mp->ps->enc_line<2||*mp->ps->enc_line=='%')
goto RESTART;
}
static void mp_load_enc(MP mp,char*enc_name,
char**enc_encname,char**glyph_names){
char buf[ENC_BUF_SIZE],*p,*r;
int names_count;
char*myname;
unsigned save_selector= mp->selector;
if(!mp_enc_open(mp,enc_name)){
char err[256];
mp_snprintf(err,255,"cannot open encoding file %s for reading",enc_name);
mp_print(mp,err);
return;
}
mp_normalize_selector(mp);
mp_print(mp,"{");
mp_print(mp,enc_name);
mp_enc_getline(mp);
if(*mp->ps->enc_line!='/'||(r= strchr(mp->ps->enc_line,'['))==NULL){
char msg[256];
remove_eol(r,mp->ps->enc_line);
mp_snprintf(msg,256,"invalid encoding vector (a name or `[' missing): `%s'",mp->ps->enc_line);
mp_error(mp,msg,NULL,true);
}
while(*(r-1)==' ')r--;
myname= mp_xmalloc(mp,(size_t)(r-mp->ps->enc_line),1);
memcpy(myname,(mp->ps->enc_line+1),(size_t)((r-mp->ps->enc_line)-1));
*(myname+(r-mp->ps->enc_line-1))= 0;
*enc_encname= myname;
while(*r!='[')r++;
r++;
names_count= 0;
skip(r,' ');
for(;;){
while(*r=='/'){
for(p= buf,r++;
*r!=' '&&*r!=10&&*r!=']'&&*r!='/';*p++= *r++);
*p= 0;
skip(r,' ');
if(names_count> 256){
mp_error(mp,"encoding vector contains more than 256 names",NULL,true);
}
if(mp_xstrcmp(buf,notdef)!=0)
glyph_names[names_count]= mp_xstrdup(mp,buf);
names_count++;
}
if(*r!=10&&*r!='%'){
if(str_prefix(r,"] def"))
goto DONE;
else{
char msg[256];
remove_eol(r,mp->ps->enc_line);
mp_snprintf(msg,256,"invalid encoding vector: a name or `] def' expected: `%s'",mp->ps->enc_line);
mp_error(mp,msg,NULL,true);
}
}
mp_enc_getline(mp);
r= mp->ps->enc_line;
}
DONE:
enc_close();
mp_print(mp,"}");
mp->selector= save_selector;
}
static void mp_read_enc(MP mp,enc_entry*e){
if(e->loaded)
return;
mp_xfree(e->enc_name);
e->enc_name= NULL;
mp_load_enc(mp,e->file_name,&e->enc_name,e->glyph_names);
e->loaded= true;
}

/*:21*//*22:*/
#line 518 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_write_enc(MP mp,enc_entry*e){
int i;
size_t s,foffset;
char**g;
if(e->objnum!=0)
return;
e->objnum= 1;
g= e->glyph_names;

mp_ps_print(mp,"\n%%%%BeginResource: encoding ");
mp_ps_print(mp,e->enc_name);
mp_ps_print_nl(mp,"/");
mp_ps_print(mp,e->enc_name);
mp_ps_print(mp," [ ");
mp_ps_print_ln(mp);
foffset= strlen(e->file_name)+3;
for(i= 0;i<256;i++){
s= strlen(g[i]);
if(s+1+foffset>=80){
mp_ps_print_ln(mp);
foffset= 0;
}
foffset+= s+2;
mp_ps_print_char(mp,'/');
mp_ps_print(mp,g[i]);
mp_ps_print_char(mp,' ');
}
if(foffset> 75)
mp_ps_print_ln(mp);
mp_ps_print_nl(mp,"] def\n");
mp_ps_print(mp,"%%%%EndResource");
}


/*:22*//*26:*/
#line 566 "../../../source/texk/web2c/mplibdir/psout.w"

static int comp_enc_entry(void*p,const void*pa,const void*pb){
(void)p;
return strcmp(((const enc_entry*)pa)->file_name,
((const enc_entry*)pb)->file_name);
}
static void*destroy_enc_entry(void*pa){
enc_entry*p;
int i;
p= (enc_entry*)pa;
mp_xfree(p->file_name);
if(p->glyph_names!=NULL)
for(i= 0;i<256;i++)
if(p->glyph_names[i]!=notdef)
mp_xfree(p->glyph_names[i]);
mp_xfree(p->enc_name);
mp_xfree(p->glyph_names);
mp_xfree(p);
return NULL;
}

/*:26*//*27:*/
#line 590 "../../../source/texk/web2c/mplibdir/psout.w"

static void*copy_enc_entry(const void*pa){
const enc_entry*p;
enc_entry*q;
int i;
p= (const enc_entry*)pa;
q= malloc(sizeof(enc_entry));
if(q!=NULL){
memset(q,0,sizeof(enc_entry));
if(p->enc_name!=NULL){
q->enc_name= strdup(p->enc_name);
if(q->enc_name==NULL)
return NULL;
}
q->loaded= p->loaded;
if(p->file_name!=NULL){
q->file_name= strdup(p->file_name);
if(q->file_name==NULL)
return NULL;
}
q->objnum= p->objnum;
q->tounicode= p->tounicode;
q->glyph_names= malloc(256*sizeof(char*));
if(p->glyph_names==NULL)
return NULL;
for(i= 0;i<256;i++){
if(p->glyph_names[i]!=NULL){
q->glyph_names[i]= strdup(p->glyph_names[i]);
if(q->glyph_names[i]==NULL)
return NULL;
}
}
}
return(void*)q;
}

static enc_entry*mp_add_enc(MP mp,char*s){
int i;
enc_entry tmp,*p;

if(mp->ps->enc_tree==NULL){
mp->ps->enc_tree= avl_create(comp_enc_entry,
copy_enc_entry,
destroy_enc_entry,
malloc,free,NULL);
}
tmp.file_name= s;
p= (enc_entry*)avl_find(&tmp,mp->ps->enc_tree);
if(p!=NULL)
return p;
p= mp_xmalloc(mp,1,sizeof(enc_entry));
memset(p,0,sizeof(enc_entry));
p->loaded= false;
p->file_name= mp_xstrdup(mp,s);
p->objnum= 0;
p->tounicode= 0;
p->glyph_names= mp_xmalloc(mp,256,sizeof(char*));
for(i= 0;i<256;i++){
p->glyph_names[i]= mp_xstrdup(mp,notdef);
}
assert(avl_ins(p,mp->ps->enc_tree,avl_false)> 0);
destroy_enc_entry(p);
return avl_find(&tmp,mp->ps->enc_tree);
}

/*:27*//*30:*/
#line 661 "../../../source/texk/web2c/mplibdir/psout.w"
static void enc_free(MP mp){
if(mp->ps->enc_tree!=NULL)
avl_destroy(mp->ps->enc_tree);
}

/*:30*//*32:*/
#line 670 "../../../source/texk/web2c/mplibdir/psout.w"
void mp_reload_encodings(MP mp){
font_number f;
enc_entry*e;
fm_entry*fm_cur;
font_number lastfnum= mp->last_fnum;
for(f= null_font+1;f<=lastfnum;f++){
if(mp->font_enc_name[f]!=NULL){
mp_xfree(mp->font_enc_name[f]);
mp->font_enc_name[f]= NULL;
}
if(mp_has_fm_entry(mp,f,&fm_cur)){
if(fm_cur!=NULL&&fm_cur->ps_name!=NULL&&is_reencoded(fm_cur)){
e= fm_cur->encoding;
mp_read_enc(mp,e);
}
}
}
}
static void mp_font_encodings(MP mp,font_number lastfnum,boolean encodings_only){
font_number f;
enc_entry*e;
fm_entry*fm;
for(f= null_font+1;f<=lastfnum;f++){
if(mp_has_font_size(mp,f)&&mp_has_fm_entry(mp,f,&fm)){
if(fm!=NULL&&(fm->ps_name!=NULL)){
if(is_reencoded(fm)){
if(encodings_only||(!is_subsetted(fm))){
e= fm->encoding;
mp_write_enc(mp,e);

e->objnum= 0;
}
}
}
}
}
}

/*:32*//*35:*/
#line 740 "../../../source/texk/web2c/mplibdir/psout.w"

static int fm_getchar(MP mp){
if(mp->ps->fm_bytes==NULL){
void*byte_ptr;
(void)fseek(unwrap_file(mp->ps->fm_file),0,SEEK_END);
mp->ps->fm_byte_length= (size_t)ftell(unwrap_file(mp->ps->fm_file));
(void)fseek(unwrap_file(mp->ps->fm_file),0,SEEK_SET);
if(mp->ps->fm_byte_length==0)
return EOF;
mp->ps->fm_bytes= mp_xmalloc(mp,mp->ps->fm_byte_length,1);
byte_ptr= (void*)mp->ps->fm_bytes;
(mp->read_binary_file)(mp,mp->ps->fm_file,&byte_ptr,&mp->ps->fm_byte_length);
}
if(mp->ps->fm_byte_waiting>=mp->ps->fm_byte_length)
return 10;
return*(mp->ps->fm_bytes+mp->ps->fm_byte_waiting++);
}

/*:35*//*40:*/
#line 807 "../../../source/texk/web2c/mplibdir/psout.w"

static fm_entry*new_fm_entry(MP mp){
fm_entry*fm;
fm= mp_xmalloc(mp,1,sizeof(fm_entry));
fm->tfm_name= NULL;
fm->ps_name= NULL;
fm->flags= 4;
fm->ff_name= NULL;
fm->subset_tag= NULL;
fm->encoding= NULL;
fm->tfm_num= null_font;
fm->tfm_avail= TFM_UNCHECKED;
fm->type= 0;
fm->slant= 0;
fm->extend= 0;
fm->ff_objnum= 0;
fm->fn_objnum= 0;
fm->fd_objnum= 0;
fm->charset= NULL;
fm->all_glyphs= false;
fm->links= 0;
fm->pid= -1;
fm->eid= -1;
return fm;
}

static void*copy_fm_entry(const void*p){
fm_entry*fm;
const fm_entry*fp;
fp= (const fm_entry*)p;
fm= malloc(sizeof(fm_entry));
if(fm==NULL)
return NULL;
memcpy(fm,fp,sizeof(fm_entry));
fm->tfm_name= do_strdup(fp->tfm_name);
fm->ps_name= do_strdup(fp->ps_name);
fm->ff_name= do_strdup(fp->ff_name);
fm->subset_tag= do_strdup(fp->subset_tag);
fm->charset= do_strdup(fp->charset);
return(void*)fm;
}


static void*delete_fm_entry(void*p){
fm_entry*fm= (fm_entry*)p;
mp_xfree(fm->tfm_name);
mp_xfree(fm->ps_name);
mp_xfree(fm->ff_name);
mp_xfree(fm->subset_tag);
mp_xfree(fm->charset);
mp_xfree(fm);
return NULL;
}

static ff_entry*new_ff_entry(MP mp){
ff_entry*ff;
ff= mp_xmalloc(mp,1,sizeof(ff_entry));
ff->ff_name= NULL;
ff->ff_path= NULL;
return ff;
}

static void*copy_ff_entry(const void*p){
ff_entry*ff;
const ff_entry*fp;
fp= (const ff_entry*)p;
ff= (ff_entry*)malloc(sizeof(ff_entry));
if(ff==NULL)
return NULL;
ff->ff_name= do_strdup(fp->ff_name);
ff->ff_path= do_strdup(fp->ff_path);
return ff;
}

static void*delete_ff_entry(void*p){
ff_entry*ff= (ff_entry*)p;
mp_xfree(ff->ff_name);
mp_xfree(ff->ff_path);
mp_xfree(ff);
return NULL;
}

static char*mk_base_tfm(MP mp,char*tfmname,int*i){
static char buf[SMALL_BUF_SIZE];
char*p= tfmname,*r= strend(p)-1,*q= r;
while(q> p&&mp_isdigit(*q))
--q;
if(!(q> p)||q==r||(*q!='+'&&*q!='-'))
return NULL;
check_buf(q-p+1,SMALL_BUF_SIZE);
strncpy(buf,p,(size_t)(q-p));
buf[q-p]= '\0';
*i= atoi(q);
return buf;
}

/*:40*//*42:*/
#line 906 "../../../source/texk/web2c/mplibdir/psout.w"

boolean mp_has_fm_entry(MP mp,font_number f,fm_entry**fm){
fm_entry*res= NULL;
res= mp_fm_lookup(mp,f);
if(fm!=NULL){
*fm= res;
}
return(res!=NULL);
}

/*:42*//*45:*/
#line 928 "../../../source/texk/web2c/mplibdir/psout.w"

static int comp_fm_entry_tfm(void*p,const void*pa,const void*pb){
(void)p;
return strcmp(((const fm_entry*)pa)->tfm_name,
((const fm_entry*)pb)->tfm_name);
}

/*:45*//*46:*/
#line 937 "../../../source/texk/web2c/mplibdir/psout.w"
static int comp_fm_entry_ps(void*p,const void*pa,const void*pb){
int i;
const fm_entry*p1= (const fm_entry*)pa;
const fm_entry*p2= (const fm_entry*)pb;
(void)p;
assert(p1->ps_name!=NULL&&p2->ps_name!=NULL);
if((i= strcmp(p1->ps_name,p2->ps_name)))
return i;
cmp_return(p1->slant,p2->slant);
cmp_return(p1->extend,p2->extend);
if(p1->tfm_name!=NULL&&p2->tfm_name!=NULL&&
(i= strcmp(p1->tfm_name,p2->tfm_name)))
return i;
return 0;
}

/*:46*//*47:*/
#line 955 "../../../source/texk/web2c/mplibdir/psout.w"
static int comp_ff_entry(void*p,const void*pa,const void*pb){
(void)p;
return strcmp(((const ff_entry*)pa)->ff_name,
((const ff_entry*)pb)->ff_name);
}

/*:47*//*48:*/
#line 961 "../../../source/texk/web2c/mplibdir/psout.w"
static void create_avl_trees(MP mp){
if(mp->ps->tfm_tree==NULL){
mp->ps->tfm_tree= avl_create(comp_fm_entry_tfm,
copy_fm_entry,
delete_fm_entry,
malloc,free,NULL);
assert(mp->ps->tfm_tree!=NULL);
}
if(mp->ps->ps_tree==NULL){
mp->ps->ps_tree= avl_create(comp_fm_entry_ps,
copy_fm_entry,
delete_fm_entry,
malloc,free,NULL);
assert(mp->ps->ps_tree!=NULL);
}
if(mp->ps->ff_tree==NULL){
mp->ps->ff_tree= avl_create(comp_ff_entry,
copy_ff_entry,
delete_ff_entry,
malloc,free,NULL);
assert(mp->ps->ff_tree!=NULL);
}
}

/*:48*//*49:*/
#line 997 "../../../source/texk/web2c/mplibdir/psout.w"

static int avl_do_entry(MP mp,fm_entry*fp,int mode){
fm_entry*p;
char s[128];


if(strcmp(fp->tfm_name,nontfm)){
p= (fm_entry*)avl_find(fp,mp->ps->tfm_tree);
if(p!=NULL){
if(mode==FM_DUPIGNORE){
mp_snprintf(s,128,"fontmap entry for `%s' already exists, duplicates ignored",
fp->tfm_name);
mp_warn(mp,s);
goto exit;
}else{
if(mp_has_font_size(mp,p->tfm_num)){
mp_snprintf(s,128,
"fontmap entry for `%s' has been used, replace/delete not allowed",
fp->tfm_name);
mp_warn(mp,s);
goto exit;
}
(void)avl_del(p,mp->ps->tfm_tree,NULL);
p= NULL;
}
}
if(mode!=FM_DELETE){
if(p==NULL){
assert(avl_ins(fp,mp->ps->tfm_tree,avl_false)> 0);
}
set_tfmlink(fp);
}
}



if(fp->ps_name!=NULL){
assert(fp->tfm_name!=NULL);
p= (fm_entry*)avl_find(fp,mp->ps->ps_tree);
if(p!=NULL){
if(mode==FM_DUPIGNORE){
mp_snprintf(s,128,
"ps_name entry for `%s' already exists, duplicates ignored",
fp->ps_name);
mp_warn(mp,s);
goto exit;
}else{
if(mp_has_font_size(mp,p->tfm_num)){

mp_snprintf(s,128,
"fontmap entry for `%s' has been used, replace/delete not allowed",
p->tfm_name);
mp_warn(mp,s);
goto exit;
}
(void)avl_del(p,mp->ps->ps_tree,NULL);
p= NULL;
}
}
if(mode!=FM_DELETE){
if(p==NULL){
assert(avl_ins(fp,mp->ps->ps_tree,avl_false)> 0);
}
set_pslink(fp);
}
}
exit:
if(!has_tfmlink(fp)&&!has_pslink(fp))
return 1;
else
return 0;
}

/*:49*//*50:*/
#line 1072 "../../../source/texk/web2c/mplibdir/psout.w"

static int check_fm_entry(MP mp,fm_entry*fm,boolean warn){
int a= 0;
char s[128];
assert(fm!=NULL);
if(fm->ps_name!=NULL){
if(is_basefont(fm)){
if(is_fontfile(fm)&&!is_included(fm)){
if(warn){
mp_snprintf(s,128,"invalid entry for `%s': "
"font file must be included or omitted for base fonts",
fm->tfm_name);
mp_warn(mp,s);
}
a+= 1;
}
}else{











}
}
if(is_truetype(fm)&&is_reencoded(fm)&&!is_subsetted(fm)){
if(warn){
mp_snprintf(s,128,
"invalid entry for `%s': only subsetted TrueType font can be reencoded",
fm->tfm_name);
mp_warn(mp,s);
}
a+= 4;
}
if((fm->slant!=0||fm->extend!=0)&&
(is_truetype(fm))){
if(warn){
mp_snprintf(s,128,
"invalid entry for `%s': "
"SlantFont/ExtendFont can be used only with embedded T1 fonts",
fm->tfm_name);
mp_warn(mp,s);
}
a+= 8;
}
if(abs(fm->slant)> 1000){
if(warn){
mp_snprintf(s,128,
"invalid entry for `%s': too big value of SlantFont (%d/1000.0)",
fm->tfm_name,(int)fm->slant);
mp_warn(mp,s);
}
a+= 16;
}
if(abs(fm->extend)> 2000){
if(warn){
mp_snprintf(s,128,
"invalid entry for `%s': too big value of ExtendFont (%d/1000.0)",
fm->tfm_name,(int)fm->extend);
mp_warn(mp,s);
}
a+= 32;
}
if(fm->pid!=-1&&
!(is_truetype(fm)&&is_included(fm)&&
is_subsetted(fm)&&!is_reencoded(fm))){
if(warn){
mp_snprintf(s,128,
"invalid entry for `%s': "
"PidEid can be used only with subsetted non-reencoded TrueType fonts",
fm->tfm_name);
mp_warn(mp,s);
}
a+= 64;
}
return a;
}

/*:50*//*51:*/
#line 1157 "../../../source/texk/web2c/mplibdir/psout.w"
static boolean check_basefont(char*s){
static const char*basefont_names[]= {
"Courier",
"Courier-Bold",
"Courier-Oblique",
"Courier-BoldOblique",
"Helvetica",
"Helvetica-Bold",
"Helvetica-Oblique",
"Helvetica-BoldOblique",
"Symbol",
"Times-Roman",
"Times-Bold",
"Times-Italic",
"Times-BoldItalic",
"ZapfDingbats"
};
static const int Index[]=
{-1,-1,-1,-1,-1,-1,8,0,-1,4,10,9,-1,-1,5,2,12,6,
-1,3,-1,7
};
const size_t n= strlen(s);
int k= -1;
if(n> 21)
return false;
if(n==12){
switch(*s){
case'C':
k= 1;
break;
case'T':
k= 11;
break;
case'Z':
k= 13;
break;
default:
return false;
}
}else
k= Index[n];
if(k> -1&&!strcmp(basefont_names[k],s))
return true;
return false;
}

/*:51*//*52:*/
#line 1206 "../../../source/texk/web2c/mplibdir/psout.w"
static void fm_scan_line(MP mp){
int a,b,c,j,u= 0,v= 0;
float d;
fm_entry*fm;
char fm_line[FM_BUF_SIZE],buf[FM_BUF_SIZE];
char*p,*q,*s;
char warn_s[128];
char*r= NULL;
switch(mp->ps->mitem->type){
case MAPFILE:
p= fm_line;
do{
c= fm_getchar(mp);
append_char_to_buf(c,p,fm_line,FM_BUF_SIZE);
}while(c!=10);
*(--p)= '\0';
r= fm_line;
break;
case MAPLINE:
r= mp->ps->mitem->map_line;
break;
default:
assert(0);
}
if(*r=='\0'||is_cfg_comment(*r))
return;
fm= new_fm_entry(mp);
read_field(r,q,buf);
set_field(tfm_name);
p= r;
read_field(r,q,buf);
if(*buf!='<'&&*buf!='"')
set_field(ps_name);
else
r= p;
if(mp_isdigit(*r)){
fm->flags= atoi(r);
while(mp_isdigit(*r))
r++;
}
if(fm->ps_name==NULL)
fm->ps_name= xstrdup(fm->tfm_name);
while(1){
skip(r,' ');
switch(*r){
case'\0':
goto DONE;
case'"':
r++;
u= v= 0;
do{
skip(r,' ');
if(sscanf(r,"%f %n",&d,&j)> 0){
s= r+j;
if(*(s-1)=='E'||*(s-1)=='e')
s--;
if(str_prefix(s,"SlantFont")){
d*= (float)1000.0;
fm->slant= (short int)(d> 0?d+0.5:d-0.5);
r= s+strlen("SlantFont");
}else if(str_prefix(s,"ExtendFont")){
d*= (float)1000.0;
fm->extend= (short int)(d> 0?d+0.5:d-0.5);
if(fm->extend==1000)
fm->extend= 0;
r= s+strlen("ExtendFont");
}else{
for(r= s;
*r!=' '&&*r!='"'&&*r!='\0';
r++);
c= *r;
*r= '\0';
mp_snprintf(warn_s,128,
"invalid entry for `%s': unknown name `%s' ignored",
fm->tfm_name,s);
mp_warn(mp,warn_s);
*r= (char)c;
}
}else
for(;*r!=' '&&*r!='"'&&*r!='\0';r++);
}
while(*r==' ');
if(*r=='"')
r++;
else{
mp_snprintf(warn_s,128,
"invalid entry for `%s': closing quote missing",
fm->tfm_name);
mp_warn(mp,warn_s);
goto bad_line;
}
break;
case'P':
if(sscanf(r,"PidEid=%i, %i %n",&a,&b,&c)>=2){
fm->pid= (short int)a;
fm->eid= (short int)b;
r+= c;
break;
}
default:
a= b= 0;
if(*r=='<'){
a= *r++;
if(*r=='<'||*r=='[')
b= *r++;
}
read_field(r,q,buf);

if(strlen(buf)> 4&&mp_strcasecmp(strend(buf)-4,".enc")==0){
fm->encoding= mp_add_enc(mp,buf);
u= v= 0;
}else if(strlen(buf)> 0){





if(a=='<'||u=='<'){
set_included(fm);
if((a=='<'&&b==0)||(a==0&&v==0))
set_subsetted(fm);

}
set_field(ff_name);
u= v= 0;
}else{
u= a;
v= b;
}
}
}
DONE:
if(fm->ps_name!=NULL&&check_basefont(fm->ps_name))
set_basefont(fm);
if(is_fontfile(fm)
&&mp_strcasecmp(strend(fm_fontfile(fm))-4,".ttf")==0)
set_truetype(fm);
if(check_fm_entry(mp,fm,true)!=0)
goto bad_line;





if(avl_do_entry(mp,fm,mp->ps->mitem->mode)==0){
delete_fm_entry(fm);
return;
}
bad_line:
delete_fm_entry(fm);
}

/*:52*//*53:*/
#line 1359 "../../../source/texk/web2c/mplibdir/psout.w"
static void fm_read_info(MP mp){
char*n;
char s[256];
if(mp->ps->tfm_tree==NULL)
create_avl_trees(mp);
if(mp->ps->mitem->map_line==NULL)
return;
mp->ps->mitem->lineno= 1;
switch(mp->ps->mitem->type){
case MAPFILE:
n= mp->ps->mitem->map_line;
mp->ps->fm_file= (mp->open_file)(mp,n,"r",mp_filetype_fontmap);
if(!mp->ps->fm_file){
mp_snprintf(s,256,"cannot open font map file %s",n);
mp_warn(mp,s);
}else{
unsigned save_selector= mp->selector;
mp_normalize_selector(mp);
mp_print(mp,"{");
mp_print(mp,n);
while(!fm_eof()){
fm_scan_line(mp);
mp->ps->mitem->lineno++;
}
fm_close();
mp_print(mp,"}");
mp->selector= save_selector;
mp->ps->fm_file= NULL;
}

break;
case MAPLINE:
fm_scan_line(mp);
break;
default:
assert(0);
}
mp->ps->mitem->map_line= NULL;
return;
}

/*:53*//*54:*/
#line 1400 "../../../source/texk/web2c/mplibdir/psout.w"
static void init_fm(fm_entry*fm,font_number f){
if(fm->tfm_num==null_font){
fm->tfm_num= f;
fm->tfm_avail= TFM_FOUND;
}
}

/*:54*//*56:*/
#line 1410 "../../../source/texk/web2c/mplibdir/psout.w"

fm_entry*mp_fm_lookup(MP mp,font_number f){
char*tfm;
fm_entry*fm;
fm_entry tmp;
int e;
if(mp->ps->tfm_tree==NULL)
mp_read_psname_table(mp);
tfm= mp->font_name[f];
assert(strcmp(tfm,nontfm));

tmp.tfm_name= tfm;
fm= (fm_entry*)avl_find(&tmp,mp->ps->tfm_tree);
if(fm!=NULL){
init_fm(fm,f);
return(fm_entry*)fm;
}
tfm= mk_base_tfm(mp,mp->font_name[f],&e);
if(tfm==NULL)
return NULL;

tmp.tfm_name= tfm;
fm= (fm_entry*)avl_find(&tmp,mp->ps->tfm_tree);
if(fm!=NULL){
return(fm_entry*)fm;
}
return NULL;
}

/*:56*//*57:*/
#line 1449 "../../../source/texk/web2c/mplibdir/psout.w"

static ff_entry*check_ff_exist(MP mp,fm_entry*fm){
ff_entry*ff;
ff_entry tmp;

assert(fm->ff_name!=NULL);
tmp.ff_name= fm->ff_name;
ff= (ff_entry*)avl_find(&tmp,mp->ps->ff_tree);
if(ff==NULL){
ff= new_ff_entry(mp);
ff->ff_name= mp_xstrdup(mp,fm->ff_name);
ff->ff_path= mp_xstrdup(mp,fm->ff_name);
assert(avl_ins(ff,mp->ps->ff_tree,avl_false)> 0);
delete_ff_entry(ff);
ff= (ff_entry*)avl_find(&tmp,mp->ps->ff_tree);
}
return ff;
}

/*:57*//*58:*/
#line 1473 "../../../source/texk/web2c/mplibdir/psout.w"
static void mp_process_map_item(MP mp,char*s,int type){
char*p;
int mode;
if(*s==' ')
s++;
switch(*s){
case'+':
mode= FM_DUPIGNORE;
s++;
break;
case'=':
mode= FM_REPLACE;
s++;
break;
case'-':
mode= FM_DELETE;
s++;
break;
default:
mode= FM_DUPIGNORE;
mp_xfree(mp->ps->mitem->map_line);
mp->ps->mitem->map_line= NULL;
}
if(*s==' ')
s++;
p= s;
switch(type){
case MAPFILE:
while(*p!='\0'&&*p!=' ')
p++;
*p= '\0';
break;
case MAPLINE:
break;
default:
assert(0);
}
if(mp->ps->mitem->map_line!=NULL)
fm_read_info(mp);
if(*s!='\0'){
mp->ps->mitem->mode= mode;
mp->ps->mitem->type= type;
mp->ps->mitem->map_line= s;
fm_read_info(mp);
}
}

/*:58*//*60:*/
#line 1525 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_map_file(MP mp,mp_string t){
char*ss= mp_str(mp,t);
char*s= mp_xstrdup(mp,ss);
mp_process_map_item(mp,s,MAPFILE);
}
void mp_map_line(MP mp,mp_string t){
char*ss= mp_str(mp,t);
char*s= mp_xstrdup(mp,ss);
mp_process_map_item(mp,s,MAPLINE);
mp_xfree(s);
}

/*:60*//*61:*/
#line 1539 "../../../source/texk/web2c/mplibdir/psout.w"
void mp_init_map_file(MP mp,int is_troff){
char*r;
mp->ps->mitem= mp_xmalloc(mp,1,sizeof(mapitem));
mp->ps->mitem->mode= FM_DUPIGNORE;
mp->ps->mitem->type= MAPFILE;
mp->ps->mitem->map_line= NULL;
r= (mp->find_file)(mp,"mpost.map","r",mp_filetype_fontmap);
if(r!=NULL){
mp_xfree(r);
mp->ps->mitem->map_line= mp_xstrdup(mp,"mpost.map");
}else{
if(is_troff){
mp->ps->mitem->map_line= mp_xstrdup(mp,"troff.map");
}else{
mp->ps->mitem->map_line= mp_xstrdup(mp,"pdftex.map");
}
}
}

/*:61*//*64:*/
#line 1567 "../../../source/texk/web2c/mplibdir/psout.w"

static void fm_free(MP mp){
if(mp->ps->tfm_tree!=NULL)
avl_destroy(mp->ps->tfm_tree);
if(mp->ps->ps_tree!=NULL)
avl_destroy(mp->ps->ps_tree);
if(mp->ps->ff_tree!=NULL)
avl_destroy(mp->ps->ff_tree);
}

/*:64*//*66:*/
#line 1589 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_read_psname_table(MP mp){
font_number k;
char*s;
static int isread= 0;
if(mp->ps->mitem==NULL){
mp->ps->mitem= mp_xmalloc(mp,1,sizeof(mapitem));
mp->ps->mitem->mode= FM_DUPIGNORE;
mp->ps->mitem->type= MAPFILE;
mp->ps->mitem->map_line= NULL;
}
s= mp_xstrdup(mp,ps_tab_name);
mp->ps->mitem->map_line= s;
if(isread==0){
isread++;
fm_read_info(mp);
}
for(k= mp->last_ps_fnum+1;k<=mp->last_fnum;k++){
if(mp_has_fm_entry(mp,k,NULL)){
mp_xfree(mp->font_ps_name[k]);
mp->font_ps_name[k]= mp_fm_font_name(mp,k);
}
}
mp->last_ps_fnum= mp->last_fnum;
}


/*:66*//*71:*/
#line 1644 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_set_job_id(MP mp){
char*name_string,*s;
size_t slen;
if(mp->ps->job_id_string!=NULL)
return;
if(mp->job_name==NULL)
mp->job_name= mp_xstrdup(mp,"mpout");
name_string= mp_xstrdup(mp,mp->job_name);
slen= SMALL_BUF_SIZE+
strlen(name_string);
s= mp_xmalloc(mp,slen,sizeof(char));
 /*@-bufferoverflowhigh@*/
sprintf(s,"%.4u/%.2u/%.2u %.2u:%.2u %s",
((unsigned)number_to_scaled(internal_value(mp_year))>>16),
((unsigned)number_to_scaled(internal_value(mp_month))>>16),
((unsigned)number_to_scaled(internal_value(mp_day))>>16),
((unsigned)number_to_scaled(internal_value(mp_time))>>16)/60,
((unsigned)number_to_scaled(internal_value(mp_time))>>16)%60,
name_string);
 /*@=bufferoverflowhigh@*/
mp->ps->job_id_string= mp_xstrdup(mp,s);
mp_xfree(s);
mp_xfree(name_string);
}
static void fnstr_append(MP mp,const char*ss){
size_t n= strlen(ss)+1;
alloc_array(char,n,SMALL_ARRAY_SIZE);
strcat(mp->ps->char_ptr,ss);
mp->ps->char_ptr= strend(mp->ps->char_ptr);
}

/*:71*//*74:*/
#line 1685 "../../../source/texk/web2c/mplibdir/psout.w"

static unsigned long crc32(unsigned long oldcrc,const Byte*buf,size_t len){
unsigned long ret= 0;
size_t i;
if(oldcrc==0)
ret= (unsigned long)((23<<24)+(45<<16)+(67<<8)+89);
else
for(i= 0;i<len;i++)
ret= (ret<<2)+buf[i];
return ret;
}
static boolean mp_char_marked(MP mp,font_number f,eight_bits c){
integer b;
b= mp->char_base[f];
if((c>=mp->font_bc[f])&&(c<=mp->font_ec[f])&&(mp->font_info[b+c].qqqq.b3!=0))
return true;
else
return false;
}

static void make_subset_tag(MP mp,fm_entry*fm_cur,char**glyph_names,font_number tex_font)
{
char tag[7];
unsigned long crc;
int i;
size_t l;
if(mp->ps->job_id_string==NULL)
mp_fatal_error(mp,"no job id!");
l= strlen(mp->ps->job_id_string)+1;

alloc_array(char,l,SMALL_ARRAY_SIZE);
strcpy(mp->ps->char_array,mp->ps->job_id_string);
mp->ps->char_ptr= strend(mp->ps->char_array);
if(fm_cur->tfm_name!=NULL){
fnstr_append(mp," TFM name: ");
fnstr_append(mp,fm_cur->tfm_name);
}
fnstr_append(mp," PS name: ");
if(fm_cur->ps_name!=NULL)
fnstr_append(mp,fm_cur->ps_name);
fnstr_append(mp," Encoding: ");
if(fm_cur->encoding!=NULL&&(fm_cur->encoding)->file_name!=NULL)
fnstr_append(mp,(fm_cur->encoding)->file_name);
else
fnstr_append(mp,"built-in");
fnstr_append(mp," CharSet: ");
for(i= 0;i<256;i++)
if(mp_char_marked(mp,tex_font,(eight_bits)i)&&
glyph_names[i]!=notdef&&
strcmp(glyph_names[i],notdef)!=0){
if(glyph_names[i]!=NULL){
fnstr_append(mp,"/");
fnstr_append(mp,glyph_names[i]);
}
}
if(fm_cur->charset!=NULL){
fnstr_append(mp," Extra CharSet: ");
fnstr_append(mp,fm_cur->charset);
}
crc= crc32(0L,Z_NULL,0);
crc= crc32(crc,(Bytef*)mp->ps->char_array,strlen(mp->ps->char_array));






for(i= 0;i<6;i++){
tag[i]= (char)('A'+crc%26);
crc/= 26;
}
tag[6]= 0;
mp_xfree(fm_cur->subset_tag);
fm_cur->subset_tag= mp_xstrdup(mp,tag);
}



/*:74*//*77:*/
#line 1807 "../../../source/texk/web2c/mplibdir/psout.w"

static int t1_getchar(MP mp){
if(mp->ps->t1_bytes==NULL){
void*byte_ptr;
(void)fseek(unwrap_file(mp->ps->t1_file),0,SEEK_END);
mp->ps->t1_byte_length= (size_t)ftell(unwrap_file(mp->ps->t1_file));
(void)fseek(unwrap_file(mp->ps->t1_file),0,SEEK_SET);
mp->ps->t1_bytes= mp_xmalloc(mp,mp->ps->t1_byte_length,1);
byte_ptr= (void*)mp->ps->t1_bytes;
(mp->read_binary_file)(mp,mp->ps->t1_file,&byte_ptr,&mp->ps->t1_byte_length);
}
return*(mp->ps->t1_bytes+mp->ps->t1_byte_waiting++);
}

/*:77*//*80:*/
#line 1869 "../../../source/texk/web2c/mplibdir/psout.w"

#define T1_BUF_SIZE   0x100

#define CS_HSTEM            1
#define CS_VSTEM            3
#define CS_VMOVETO          4
#define CS_RLINETO          5
#define CS_HLINETO          6
#define CS_VLINETO          7
#define CS_RRCURVETO        8
#define CS_CLOSEPATH        9
#define CS_CALLSUBR         10
#define CS_RETURN           11
#define CS_ESCAPE           12
#define CS_HSBW             13
#define CS_ENDCHAR          14
#define CS_RMOVETO          21
#define CS_HMOVETO          22
#define CS_VHCURVETO        30
#define CS_HVCURVETO        31
#define CS_1BYTE_MAX        (CS_HVCURVETO + 1)

#define CS_DOTSECTION       CS_1BYTE_MAX + 0
#define CS_VSTEM3           CS_1BYTE_MAX + 1
#define CS_HSTEM3           CS_1BYTE_MAX + 2
#define CS_SEAC             CS_1BYTE_MAX + 6
#define CS_SBW              CS_1BYTE_MAX + 7
#define CS_DIV              CS_1BYTE_MAX + 12
#define CS_CALLOTHERSUBR    CS_1BYTE_MAX + 16
#define CS_POP              CS_1BYTE_MAX + 17
#define CS_SETCURRENTPOINT  CS_1BYTE_MAX + 33
#define CS_2BYTE_MAX        (CS_SETCURRENTPOINT + 1)
#define CS_MAX              CS_2BYTE_MAX

/*:80*//*89:*/
#line 1988 "../../../source/texk/web2c/mplibdir/psout.w"

static void end_hexline(MP mp){
if(mp->ps->hexline_length>=HEXLINE_WIDTH){
wps_cr;
mp->ps->hexline_length= 0;
}
}
static void t1_check_pfa(MP mp){
const int c= t1_getchar(mp);
mp->ps->t1_pfa= (c!=128)?true:false;
t1_ungetchar();
}
static int t1_getbyte(MP mp)
{
int c= t1_getchar(mp);
if(mp->ps->t1_pfa)
return c;
if(mp->ps->t1_block_length==0){
if(c!=128)
mp_fatal_error(mp,"invalid marker");
c= t1_getchar(mp);
if(c==3){
while(!t1_eof())
(void)t1_getchar(mp);
return EOF;
}
mp->ps->t1_block_length= t1_getchar(mp)&0xff;
mp->ps->t1_block_length|= (int)(((unsigned)t1_getchar(mp)&0xff)<<8);
mp->ps->t1_block_length|= (int)(((unsigned)t1_getchar(mp)&0xff)<<16);
mp->ps->t1_block_length|= (int)(((unsigned)t1_getchar(mp)&0xff)<<24);
c= t1_getchar(mp);
}
mp->ps->t1_block_length--;
return c;
}
static int hexval(int c){
if(c>='A'&&c<='F')
return c-'A'+10;
else if(c>='a'&&c<='f')
return c-'a'+10;
else if(c>='0'&&c<='9')
return c-'0';
else
return-1;
}
static byte edecrypt(MP mp,byte cipher){
byte plain;
if(mp->ps->t1_pfa){
while(cipher==10||cipher==13)
cipher= (byte)t1_getbyte(mp);
mp->ps->last_hexbyte= cipher= (byte)(((byte)hexval(cipher)<<4)+
hexval(t1_getbyte(mp)));
}
plain= (byte)(cipher^(mp->ps->t1_dr>>8));
mp->ps->t1_dr= (unsigned short)((cipher+mp->ps->t1_dr)*t1_c1+t1_c2);
return plain;
}
static byte cdecrypt(byte cipher,unsigned short*cr)
{
const byte plain= (byte)(cipher^(*cr>>8));
*cr= (unsigned short)((cipher+*cr)*t1_c1+t1_c2);
return plain;
}
static byte eencrypt(MP mp,byte plain)
{
const byte cipher= (byte)(plain^(mp->ps->t1_er>>8));
mp->ps->t1_er= (unsigned short)((cipher+mp->ps->t1_er)*t1_c1+t1_c2);
return cipher;
}

static byte cencrypt(byte plain,unsigned short*cr)
{
const byte cipher= (byte)(plain^(*cr>>8));
*cr= (unsigned short)((cipher+*cr)*t1_c1+t1_c2);
return cipher;
}

static char*eol(char*s){
char*p= strend(s);
if(p!=NULL&&p-s> 1&&p[-1]!=10){
*p++= 10;
*p= 0;
}
return p;
}
static float t1_scan_num(MP mp,char*p,char**r)
{
float f;
char s[128];
skip(p,' ');
if(sscanf(p,"%g",&f)!=1){
remove_eol(p,mp->ps->t1_line_array);
mp_snprintf(s,128,"a number expected: `%s'",mp->ps->t1_line_array);
mp_fatal_error(mp,s);
}
if(r!=NULL){
for(;mp_isdigit(*p)||*p=='.'||
*p=='e'||*p=='E'||*p=='+'||*p=='-';p++);
*r= p;
}
return f;
}

static boolean str_suffix(const char*begin_buf,const char*end_buf,
const char*s)
{
const char*s1= end_buf-1,*s2= strend(s)-1;
if(*s1==10)
s1--;
while(s1>=begin_buf&&s2>=s){
if(*s1--!=*s2--)
return false;
}
return s2<s;
}

/*:89*//*90:*/
#line 2127 "../../../source/texk/web2c/mplibdir/psout.w"

static void t1_getline(MP mp){
int c,l,eexec_scan;
char*p;
static const char eexec_str[]= "currentfile eexec";
static int eexec_len= 17;
RESTART:
if(t1_eof())
mp_fatal_error(mp,"unexpected end of file");
mp->ps->t1_line_ptr= mp->ps->t1_line_array;
alloc_array(t1_line,1,T1_BUF_SIZE);
mp->ps->t1_cslen= 0;
eexec_scan= 0;
c= t1_getbyte(mp);
if(c==EOF)
goto EXIT;
while(!t1_eof()){
if(mp->ps->t1_in_eexec==1)
c= edecrypt(mp,(byte)c);
alloc_array(t1_line,1,T1_BUF_SIZE);
append_char_to_buf(c,mp->ps->t1_line_ptr,mp->ps->t1_line_array,mp->ps->t1_line_limit);
if(mp->ps->t1_in_eexec==0&&eexec_scan>=0&&eexec_scan<eexec_len){
if(mp->ps->t1_line_array[eexec_scan]==eexec_str[eexec_scan])
eexec_scan++;
else
eexec_scan= -1;
}
if(c==10||(mp->ps->t1_pfa&&eexec_scan==eexec_len&&c==32))
break;
if(mp->ps->t1_cs&&mp->ps->t1_cslen==0&&
(mp->ps->t1_line_ptr-mp->ps->t1_line_array> 4)&&
(t1_suffix(" RD ")||t1_suffix(" -| "))){
p= mp->ps->t1_line_ptr-5;
while(*p!=' ')
p--;
l= (int)t1_scan_num(mp,p+1,0);
mp->ps->t1_cslen= (unsigned short)l;
mp->ps->cs_start= (int)(mp->ps->t1_line_ptr-mp->ps->t1_line_array);

alloc_array(t1_line,l,T1_BUF_SIZE);
while(l--> 0){
*mp->ps->t1_line_ptr= (t1_line_entry)edecrypt(mp,(byte)t1_getbyte(mp));
mp->ps->t1_line_ptr++;
}
}
c= t1_getbyte(mp);
}
alloc_array(t1_line,2,T1_BUF_SIZE);
append_eol(mp->ps->t1_line_ptr,mp->ps->t1_line_array,mp->ps->t1_line_limit);
if(mp->ps->t1_line_ptr-mp->ps->t1_line_array<2)
goto RESTART;
if(eexec_scan==eexec_len)
mp->ps->t1_in_eexec= 1;
EXIT:

mp->ps->t1_buf_ptr= mp->ps->t1_buf_array;
alloc_array(t1_buf,mp->ps->t1_line_limit,mp->ps->t1_line_limit);
}

static void t1_putline(MP mp)
{
char ss[256];
int ss_cur= 0;
static const char*hexdigits= "0123456789ABCDEF";
char*p= mp->ps->t1_line_array;
if(mp->ps->t1_line_ptr-mp->ps->t1_line_array<=1)
return;
if(mp->ps->t1_eexec_encrypt){
while(p<mp->ps->t1_line_ptr){
byte b= eencrypt(mp,(byte)*p++);
if(ss_cur>=253){
ss[ss_cur]= '\0';
(mp->write_ascii_file)(mp,mp->output_file,(char*)ss);
ss_cur= 0;
}
ss[ss_cur++]= hexdigits[b/16];
ss[ss_cur++]= hexdigits[b%16];
mp->ps->hexline_length+= 2;
if(mp->ps->hexline_length>=HEXLINE_WIDTH){
ss[ss_cur++]= '\n';
mp->ps->hexline_length= 0;
}
}
}else{
while(p<mp->ps->t1_line_ptr){
if(ss_cur>=255){
ss[ss_cur]= '\0';
(mp->write_ascii_file)(mp,mp->output_file,(char*)ss);
ss_cur= 0;
}
ss[ss_cur++]= (char)(*p++);
}
}
ss[ss_cur]= '\0';
(mp->write_ascii_file)(mp,mp->output_file,(char*)ss);
}

static void t1_puts(MP mp,const char*s)
{
if(s!=mp->ps->t1_line_array)
strcpy(mp->ps->t1_line_array,s);
mp->ps->t1_line_ptr= strend(mp->ps->t1_line_array);
t1_putline(mp);
}

static void t1_init_params(MP mp,const char*open_name_prefix,
char*cur_file_name){
if((open_name_prefix!=NULL)&&strlen(open_name_prefix)){
t1_log(open_name_prefix);
t1_log(cur_file_name);
}
mp->ps->t1_lenIV= 4;
mp->ps->t1_dr= 55665;
mp->ps->t1_er= 55665;
mp->ps->t1_in_eexec= 0;
mp->ps->t1_cs= false;
mp->ps->t1_scan= true;
mp->ps->t1_synthetic= false;
mp->ps->t1_eexec_encrypt= false;
mp->ps->t1_block_length= 0;
t1_check_pfa(mp);
}
static void t1_close_font_file(MP mp,const char*close_name_suffix){
if((close_name_suffix!=NULL)&&strlen(close_name_suffix)){
t1_log(close_name_suffix);
}
t1_close();
}

static void t1_check_block_len(MP mp,boolean decrypt){
int l,c;
char s[128];
if(mp->ps->t1_block_length==0)
return;
c= t1_getbyte(mp);
if(decrypt)
c= edecrypt(mp,(byte)c);
l= mp->ps->t1_block_length;
if(!(l==0&&(c==10||c==13))){
mp_snprintf(s,128,"%i bytes more than expected were ignored",l+1);
mp_warn(mp,s);
while(l--> 0)
(void)t1_getbyte(mp);
}
}
static void t1_start_eexec(MP mp,fm_entry*fm_cur){
int i;
if(!mp->ps->t1_pfa)
t1_check_block_len(mp,false);
for(mp->ps->t1_line_ptr= mp->ps->t1_line_array,i= 0;i<4;i++){
(void)edecrypt(mp,(byte)t1_getbyte(mp));
*mp->ps->t1_line_ptr++= 0;
}
mp->ps->t1_eexec_encrypt= true;
if(!mp->ps->read_encoding_only)
if(is_included(fm_cur))
t1_putline(mp);
}
static void t1_stop_eexec(MP mp){
int c;
end_last_eexec_line();
if(!mp->ps->t1_pfa)
t1_check_block_len(mp,true);
else{
c= edecrypt(mp,(byte)t1_getbyte(mp));
if(!(c==10||c==13)){
if(mp->ps->last_hexbyte==0)
t1_puts(mp,"00");
else
mp_warn(mp,"unexpected data after eexec");
}
}
mp->ps->t1_cs= false;
mp->ps->t1_in_eexec= 2;
}
static void t1_modify_fm(MP mp){
mp->ps->t1_line_ptr= eol(mp->ps->t1_line_array);
}

static void t1_modify_italic(MP mp){
mp->ps->t1_line_ptr= eol(mp->ps->t1_line_array);
}

/*:90*//*93:*/
#line 2351 "../../../source/texk/web2c/mplibdir/psout.w"

static void t1_scan_keys(MP mp,font_number tex_font,fm_entry*fm_cur){
int i,k;
char*p,*r;
key_entry*key;
if(fm_extend(fm_cur)!=0||fm_slant(fm_cur)!=0){
if(t1_prefix("/FontMatrix")){
t1_modify_fm(mp);
return;
}
if(t1_prefix("/ItalicAngle")){
t1_modify_italic(mp);
return;
}
}
if(t1_prefix("/FontType")){
p= mp->ps->t1_line_array+strlen("FontType")+1;
if((i= (int)t1_scan_num(mp,p,0))!=1){
char s[128];
mp_snprintf(s,125,"Type%d fonts unsupported by metapost",i);
mp_fatal_error(mp,s);
}
return;
}
for(key= font_keys;key-font_keys<MAX_KEY_CODE;key++)
if(str_prefix(mp->ps->t1_line_array+1,key->t1name))
break;
if(key-font_keys==MAX_KEY_CODE)
return;
key->valid= true;
p= mp->ps->t1_line_array+strlen(key->t1name)+1;
skip(p,' ');
if((k= (int)(key-font_keys))==FONTNAME_CODE){
if(*p!='/'){
char s[128];
remove_eol(p,mp->ps->t1_line_array);
mp_snprintf(s,128,"a name expected: `%s'",mp->ps->t1_line_array);
mp_fatal_error(mp,s);
}
r= ++p;
if(is_included(fm_cur)){

strncpy(mp->ps->fontname_buf,p,FONTNAME_BUF_SIZE);
for(i= 0;mp->ps->fontname_buf[i]!=10;i++);
mp->ps->fontname_buf[i]= 0;

if(is_subsetted(fm_cur)){
if(fm_cur->encoding!=NULL&&fm_cur->encoding->glyph_names!=NULL)
make_subset_tag(mp,fm_cur,fm_cur->encoding->glyph_names,tex_font);
else
make_subset_tag(mp,fm_cur,mp->ps->t1_builtin_glyph_names,tex_font);

alloc_array(t1_line,(size_t)(r-mp->ps->t1_line_array)+6+1+strlen(mp->ps->fontname_buf)+1,
T1_BUF_SIZE);
strncpy(r,fm_cur->subset_tag,6);
*(r+6)= '-';
strncpy(r+7,mp->ps->fontname_buf,strlen(mp->ps->fontname_buf)+1);
mp->ps->t1_line_ptr= eol(r);
}else{


mp->ps->t1_line_ptr= eol(r);
}
}
return;
}
if((k==STEMV_CODE||k==FONTBBOX1_CODE)
&&(*p=='['||*p=='{'))
p++;
if(k==FONTBBOX1_CODE){
for(i= 0;i<4;i++){
key[i].value= t1_scan_num(mp,p,&r);
p= r;
}
return;
}
key->value= t1_scan_num(mp,p,0);
}
static void t1_scan_param(MP mp,font_number tex_font,fm_entry*fm_cur)
{
static const char*lenIV= "/lenIV";
if(!mp->ps->t1_scan||*mp->ps->t1_line_array!='/')
return;
if(t1_prefix(lenIV)){
mp->ps->t1_lenIV= (short int)t1_scan_num(mp,mp->ps->t1_line_array+strlen(lenIV),0);
return;
}
t1_scan_keys(mp,tex_font,fm_cur);
}
static void copy_glyph_names(MP mp,char**glyph_names,int a,int b){
if(glyph_names[b]!=notdef)
mp_xfree(glyph_names[b]);
glyph_names[b]= mp_xstrdup(mp,glyph_names[a]);
}
static void t1_builtin_enc(MP mp){
int i,a,b,c,counter= 0;
char*r,*p;



if(t1_suffix("def")){
(void)sscanf(mp->ps->t1_line_array+strlen("/Encoding"),"%255s",mp->ps->t1_buf_array);
if(strcmp(mp->ps->t1_buf_array,"StandardEncoding")==0){
for(i= 0;i<256;i++){
if(mp->ps->t1_builtin_glyph_names[i]!=notdef)
mp_xfree(mp->ps->t1_builtin_glyph_names[i]);
mp->ps->t1_builtin_glyph_names[i]=
mp_xstrdup(mp,standard_glyph_names[i]);
}
mp->ps->t1_encoding= ENC_STANDARD;
}else{
char s[128];
mp_snprintf(s,128,"cannot subset font (unknown predefined encoding `%s')",
mp->ps->t1_buf_array);
mp_fatal_error(mp,s);
}
return;
}else
mp->ps->t1_encoding= ENC_BUILTIN;
















for(i= 0;i<256;i++){
if(mp->ps->t1_builtin_glyph_names[i]!=notdef){
mp_xfree(mp->ps->t1_builtin_glyph_names[i]);
mp->ps->t1_builtin_glyph_names[i]= mp_xstrdup(mp,notdef);
}
}
if(t1_prefix("/Encoding [")||t1_prefix("/Encoding[")){
r= strchr(mp->ps->t1_line_array,'[')+1;
skip(r,' ');
for(;;){
while(*r=='/'){
for(p= mp->ps->t1_buf_array,r++;
*r!=32&&*r!=10&&*r!=']'&&*r!='/';
*p++= *r++);
*p= 0;
skip(r,' ');
if(counter> 255){
mp_fatal_error
(mp,"encoding vector contains more than 256 names");
}
if(strcmp(mp->ps->t1_buf_array,notdef)!=0){
if(mp->ps->t1_builtin_glyph_names[counter]!=notdef)
mp_xfree(mp->ps->t1_builtin_glyph_names[counter]);
mp->ps->t1_builtin_glyph_names[counter]= mp_xstrdup(mp,mp->ps->t1_buf_array);
}
counter++;
}
if(*r!=10&&*r!='%'){
if(str_prefix(r,"] def")
||str_prefix(r,"] readonly def"))
break;
else{
char s[128];
remove_eol(r,mp->ps->t1_line_array);
mp_snprintf(s,128,"a name or `] def' or `] readonly def' expected: `%s'",
mp->ps->t1_line_array);
mp_fatal_error(mp,s);
}
}
t1_getline(mp);
r= mp->ps->t1_line_array;
}
}else{
p= strchr(mp->ps->t1_line_array,10);
for(;p!=NULL;){
if(*p==10){
t1_getline(mp);
p= mp->ps->t1_line_array;
}



if(sscanf(p,"dup %i%255s put",&i,mp->ps->t1_buf_array)==2&&
*mp->ps->t1_buf_array=='/'&&valid_code(i)){
if(strcmp(mp->ps->t1_buf_array+1,notdef)!=0){
if(mp->ps->t1_builtin_glyph_names[i]!=notdef)
mp_xfree(mp->ps->t1_builtin_glyph_names[i]);
mp->ps->t1_builtin_glyph_names[i]=
mp_xstrdup(mp,mp->ps->t1_buf_array+1);
}
p= strstr(p," put")+strlen(" put");
skip(p,' ');
}



else if(sscanf(p,"dup dup %i exch %i get put",&b,&a)==2
&&valid_code(a)&&valid_code(b)){
copy_glyph_names(mp,mp->ps->t1_builtin_glyph_names,a,b);
p= strstr(p," get put")+strlen(" get put");
skip(p,' ');
}



else if(sscanf
(p,"dup dup %i %i getinterval %i exch putinterval",
&a,&c,&b)==3&&valid_code(a)&&valid_code(b)
&&valid_code(c)){
for(i= 0;i<c;i++)
copy_glyph_names(mp,mp->ps->t1_builtin_glyph_names,a+i,b+i);
p= strstr(p," putinterval")+strlen(" putinterval");
skip(p,' ');
}



else if((p==mp->ps->t1_line_array||(p> mp->ps->t1_line_array&&p[-1]==' '))
&&strcmp(p,"def\n")==0)
return;



else{
while(*p!=' '&&*p!=10)
p++;
skip(p,' ');
}
}
}
}

static void t1_check_end(MP mp){
if(t1_eof())
return;
t1_getline(mp);
if(t1_prefix("{restore}"))
t1_putline(mp);
}

/*:93*//*96:*/
#line 2611 "../../../source/texk/web2c/mplibdir/psout.w"

static boolean t1_open_fontfile(MP mp,fm_entry*fm_cur,const char*open_name_prefix){
ff_entry*ff;
ff= check_ff_exist(mp,fm_cur);
mp->ps->t1_file= NULL;
if(ff->ff_path!=NULL){
mp->ps->t1_file= (mp->open_file)(mp,ff->ff_path,"r",mp_filetype_font);
}
if(mp->ps->t1_file==NULL){
char err[256];
mp_snprintf(err,255,"cannot open Type 1 font file %s for reading",ff->ff_path);
mp_warn(mp,err);
return false;
}
t1_init_params(mp,open_name_prefix,fm_cur->ff_name);
mp->ps->fontfile_found= true;
return true;
}

static void t1_scan_only(MP mp,font_number tex_font,fm_entry*fm_cur){
do{
t1_getline(mp);
t1_scan_param(mp,tex_font,fm_cur);
}
while(mp->ps->t1_in_eexec==0);
t1_start_eexec(mp,fm_cur);
do{
t1_getline(mp);
t1_scan_param(mp,tex_font,fm_cur);
}
while(!(t1_charstrings()||t1_subrs()));
}

static void t1_include(MP mp,font_number tex_font,fm_entry*fm_cur){
do{
t1_getline(mp);
t1_scan_param(mp,tex_font,fm_cur);
t1_putline(mp);
}
while(mp->ps->t1_in_eexec==0);
t1_start_eexec(mp,fm_cur);
do{
t1_getline(mp);
t1_scan_param(mp,tex_font,fm_cur);
t1_putline(mp);
}
while(!(t1_charstrings()||t1_subrs()));
mp->ps->t1_cs= true;
do{
t1_getline(mp);
t1_putline(mp);
}
while(!t1_end_eexec());
t1_stop_eexec(mp);
if(fixedcontent){
do{
t1_getline(mp);
t1_putline(mp);
}
while(!t1_cleartomark());
t1_check_end(mp);
}
}

/*:96*//*97:*/
#line 2682 "../../../source/texk/web2c/mplibdir/psout.w"

static const char**check_cs_token_pair(MP mp){
const char**p= (const char**)cs_token_pairs_list;
for(;p[0]!=NULL;++p)
if(t1_buf_prefix(p[0])&&t1_buf_suffix(p[1]))
return p;
return NULL;
}

static void cs_store(MP mp,boolean is_subr){
char*p;
cs_entry*ptr;
int subr;
for(p= mp->ps->t1_line_array,mp->ps->t1_buf_ptr= mp->ps->t1_buf_array;*p!=' ';
*mp->ps->t1_buf_ptr++= *p++);
*mp->ps->t1_buf_ptr= 0;
if(is_subr){
subr= (int)t1_scan_num(mp,p+1,0);
check_subr(subr);
ptr= mp->ps->subr_tab+subr;
}else{
ptr= mp->ps->cs_ptr++;
if(mp->ps->cs_ptr-mp->ps->cs_tab> mp->ps->cs_size){
char s[128];
mp_snprintf(s,128,"CharStrings dict: more entries than dict size (%i)",mp->ps->cs_size);
mp_fatal_error(mp,s);
}
ptr->glyph_name= mp_xstrdup(mp,mp->ps->t1_buf_array+1);
}

memcpy(mp->ps->t1_buf_array,mp->ps->t1_line_array+mp->ps->cs_start-4,
(size_t)(mp->ps->t1_cslen+4));

for(p= mp->ps->t1_line_array+mp->ps->cs_start+mp->ps->t1_cslen,mp->ps->t1_buf_ptr=
mp->ps->t1_buf_array+mp->ps->t1_cslen+4;*p!=10;*mp->ps->t1_buf_ptr++= *p++);
*mp->ps->t1_buf_ptr++= 10;
if(is_subr&&mp->ps->cs_token_pair==NULL)
mp->ps->cs_token_pair= check_cs_token_pair(mp);
ptr->len= (unsigned short)(mp->ps->t1_buf_ptr-mp->ps->t1_buf_array);
ptr->cslen= mp->ps->t1_cslen;
ptr->data= mp_xmalloc(mp,(size_t)ptr->len,sizeof(byte));
memcpy(ptr->data,mp->ps->t1_buf_array,(size_t)ptr->len);
ptr->valid= true;
}

#define store_subr(mp)    cs_store(mp,true)
#define store_cs(mp)      cs_store(mp,false)

#define CC_STACK_SIZE       24

static double cc_stack[CC_STACK_SIZE],*stack_ptr= cc_stack;
static cc_entry cc_tab[CS_MAX];
static boolean is_cc_init= false;


#define cc_pop(N)                       \
    if (stack_ptr - cc_stack < (N))     \
        stack_error(N);                 \
    stack_ptr -=  N

#define stack_error(N) {                \
    char s[256];                        \
    mp_snprintf(s,255,"CharString: invalid access (%i) to stack (%i entries)", \
                 (int) N, (int)(stack_ptr - cc_stack));                  \
    mp_warn(mp,s);                    \
    goto cs_error;                    \
}


#define cc_get(N)   ((N) < 0 ? *(stack_ptr + (N)) : *(cc_stack + (N)))

#define cc_push(V)  *stack_ptr++ =  (double)(V)
#define cc_clear()  stack_ptr =  cc_stack

#define set_cc(N, B, A, C) \
    cc_tab[N].nargs =  A;   \
    cc_tab[N].bottom =  B;  \
    cc_tab[N].clear =  C;   \
    cc_tab[N].valid =  true

static void cc_init(void){
int i;
if(is_cc_init)
return;
for(i= 0;i<CS_MAX;i++)
cc_tab[i].valid= false;
set_cc(CS_HSTEM,true,2,true);
set_cc(CS_VSTEM,true,2,true);
set_cc(CS_VMOVETO,true,1,true);
set_cc(CS_RLINETO,true,2,true);
set_cc(CS_HLINETO,true,1,true);
set_cc(CS_VLINETO,true,1,true);
set_cc(CS_RRCURVETO,true,6,true);
set_cc(CS_CLOSEPATH,false,0,true);
set_cc(CS_CALLSUBR,false,1,false);
set_cc(CS_RETURN,false,0,false);



set_cc(CS_HSBW,true,2,true);
set_cc(CS_ENDCHAR,false,0,true);
set_cc(CS_RMOVETO,true,2,true);
set_cc(CS_HMOVETO,true,1,true);
set_cc(CS_VHCURVETO,true,4,true);
set_cc(CS_HVCURVETO,true,4,true);
set_cc(CS_DOTSECTION,false,0,true);
set_cc(CS_VSTEM3,true,6,true);
set_cc(CS_HSTEM3,true,6,true);
set_cc(CS_SEAC,true,5,true);
set_cc(CS_SBW,true,4,true);
set_cc(CS_DIV,false,2,false);
set_cc(CS_CALLOTHERSUBR,false,0,false);
set_cc(CS_POP,false,0,false);
set_cc(CS_SETCURRENTPOINT,true,2,true);
is_cc_init= true;
}

/*:97*//*98:*/
#line 2807 "../../../source/texk/web2c/mplibdir/psout.w"

static void cs_warn(MP mp,const char*cs_name,int subr,const char*fmt,...){
char buf[SMALL_BUF_SIZE];
char s[300];
va_list args;
va_start(args,fmt);
 /*@-bufferoverflowhigh@*/
(void)vsprintf(buf,fmt,args);
 /*@=bufferoverflowhigh@*/
va_end(args);
if(cs_name==NULL){
mp_snprintf(s,299,"Subr (%i): %s",(int)subr,buf);
}else{
mp_snprintf(s,299,"CharString (/%s): %s",cs_name,buf);
}
mp_warn(mp,s);
}

static void cs_mark(MP mp,const char*cs_name,int subr)
{
byte*data;
int i,b,cs_len;
integer a,a1,a2;
unsigned short cr;
static integer lastargOtherSubr3= 3;

cs_entry*ptr;
cc_entry*cc;
if(cs_name==NULL){
check_subr(subr);
ptr= mp->ps->subr_tab+subr;
if(!ptr->valid)
return;
}else{
if(mp->ps->cs_notdef!=NULL&&
(cs_name==notdef||strcmp(cs_name,notdef)==0))
ptr= mp->ps->cs_notdef;
else{
for(ptr= mp->ps->cs_tab;ptr<mp->ps->cs_ptr;ptr++)
if(strcmp(ptr->glyph_name,cs_name)==0)
break;
if(ptr==mp->ps->cs_ptr){
char s[128];
mp_snprintf(s,128,"glyph `%s' undefined",cs_name);
mp_warn(mp,s);
return;
}
if(ptr->glyph_name==notdef)
mp->ps->cs_notdef= ptr;
}
}


if(!ptr->valid||(ptr->is_used&&cs_name!=NULL))
return;
ptr->is_used= true;
cr= 4330;
cs_len= (int)ptr->cslen;
data= ptr->data+4;
for(i= 0;i<mp->ps->t1_lenIV;i++,cs_len--)
(void)cs_getchar(mp);
while(cs_len> 0){
--cs_len;
b= cs_getchar(mp);
if(b>=32){
if(b<=246)
a= b-139;
else if(b<=250){
--cs_len;
a= (int)((unsigned)(b-247)<<8)+108+cs_getchar(mp);
}else if(b<=254){
--cs_len;
a= -(int)((unsigned)(b-251)<<8)-108-cs_getchar(mp);
}else{
cs_len-= 4;
a= (cs_getchar(mp)&0xff)<<24;
a|= (cs_getchar(mp)&0xff)<<16;
a|= (cs_getchar(mp)&0xff)<<8;
a|= (cs_getchar(mp)&0xff)<<0;
if(sizeof(integer)> 4&&(a&0x80000000))
a|= ~0x7FFFFFFF;
}
cc_push(a);
}else{
if(b==CS_ESCAPE){
b= cs_getchar(mp)+CS_1BYTE_MAX;
cs_len--;
}
if(b>=CS_MAX){
cs_warn(mp,cs_name,subr,"command value out of range: %i",
(int)b);
goto cs_error;
}
cc= cc_tab+b;
if(!cc->valid){
cs_warn(mp,cs_name,subr,"command not valid: %i",(int)b);
goto cs_error;
}
if(cc->bottom){
if(stack_ptr-cc_stack<cc->nargs)
cs_warn(mp,cs_name,subr,
"less arguments on stack (%i) than required (%i)",
(int)(stack_ptr-cc_stack),(int)cc->nargs);
else if(stack_ptr-cc_stack> cc->nargs)
cs_warn(mp,cs_name,subr,
"more arguments on stack (%i) than required (%i)",
(int)(stack_ptr-cc_stack),(int)cc->nargs);
}
switch(cc-cc_tab){
case CS_CALLSUBR:
a1= (integer)cc_get(-1);
cc_pop(1);
mark_subr(mp,a1);
if(!mp->ps->subr_tab[a1].valid){
cs_warn(mp,cs_name,subr,"cannot call subr (%i)",(int)a1);
goto cs_error;
}
break;
case CS_DIV:
cc_pop(2);
cc_push(0);
break;
case CS_CALLOTHERSUBR:
a1= (integer)cc_get(-1);
if(a1==3)
lastargOtherSubr3= (integer)cc_get(-3);
a1= (integer)cc_get(-2)+2;
cc_pop(a1);
break;
case CS_POP:
cc_push(lastargOtherSubr3);




break;
case CS_SEAC:
a1= (integer)cc_get(3);
a2= (integer)cc_get(4);
cc_clear();
mark_cs(mp,standard_glyph_names[a1]);
mark_cs(mp,standard_glyph_names[a2]);
break;
default:
if(cc->clear)
cc_clear();
}
}
}
return;
cs_error:
cc_clear();
ptr->valid= false;
ptr->is_used= false;
}

static void t1_subset_ascii_part(MP mp,font_number tex_font,fm_entry*fm_cur)
{
int i,j;
t1_getline(mp);
while(!t1_prefix("/Encoding")){
t1_scan_param(mp,tex_font,fm_cur);






if(t1_prefix("FontDirectory")){
char*endloc,*p;
char new_line[T1_BUF_SIZE]= {0};
p= mp->ps->t1_line_array;
while((endloc= strstr(p,fm_cur->ps_name))!=NULL){
int n= (endloc-mp->ps->t1_line_array)+strlen(fm_cur->subset_tag)+2+strlen(fm_cur->ps_name);
if(n>=T1_BUF_SIZE){
mp_fatal_error(mp,"t1_subset_ascii_part: buffer overrun detected.");
}
strncat(new_line,p,(endloc-p));
strcat(new_line,fm_cur->subset_tag);
strcat(new_line,"-");
strcat(new_line,fm_cur->ps_name);
p= endloc+strlen(fm_cur->ps_name);
}
if(strlen(new_line)+strlen(p)+1>=T1_BUF_SIZE){
mp_fatal_error(mp,"t1_subset_ascii_part: buffer overrun detected.");
}
strcat(new_line,p);
strcpy(mp->ps->t1_line_array,new_line);
mp->ps->t1_line_ptr= mp->ps->t1_line_array+strlen(mp->ps->t1_line_array);
t1_putline(mp);
}else{
t1_putline(mp);
}
t1_getline(mp);
}
t1_builtin_enc(mp);
if(is_reencoded(fm_cur))
mp->ps->t1_glyph_names= external_enc();
else
mp->ps->t1_glyph_names= mp->ps->t1_builtin_glyph_names;
if((!is_subsetted(fm_cur))&&mp->ps->t1_encoding==ENC_STANDARD)
t1_puts(mp,"/Encoding StandardEncoding def\n");
else{
t1_puts
(mp,"/Encoding 256 array\n0 1 255 {1 index exch /.notdef put} for\n");
for(i= 0,j= 0;i<256;i++){
if(is_used_char(i)&&mp->ps->t1_glyph_names[i]!=notdef&&
strcmp(mp->ps->t1_glyph_names[i],notdef)!=0){
j++;
mp_snprintf(mp->ps->t1_line_array,(int)mp->ps->t1_line_limit,
"dup %i /%s put\n",(int)t1_char(i),
mp->ps->t1_glyph_names[i]);
t1_puts(mp,mp->ps->t1_line_array);
}
}



if(j==0)
t1_puts(mp,"dup 0 /.notdef put\n");
t1_puts(mp,"readonly def\n");
}
do{
t1_getline(mp);
t1_scan_param(mp,tex_font,fm_cur);
if(!t1_prefix("/UniqueID"))
t1_putline(mp);
}
while(mp->ps->t1_in_eexec==0);
}

#define t1_subr_flush(mp)  t1_flush_cs(mp,true)
#define t1_cs_flush(mp)    t1_flush_cs(mp,false)

static void cs_init(MP mp){
mp->ps->cs_ptr= mp->ps->cs_tab= NULL;
mp->ps->cs_dict_start= mp->ps->cs_dict_end= NULL;
mp->ps->cs_count= mp->ps->cs_size= mp->ps->cs_size_pos= 0;
mp->ps->cs_token_pair= NULL;
mp->ps->subr_tab= NULL;
mp->ps->subr_array_start= mp->ps->subr_array_end= NULL;
mp->ps->subr_max= mp->ps->subr_size= mp->ps->subr_size_pos= 0;
}

static void init_cs_entry(cs_entry*cs){
cs->data= NULL;
cs->glyph_name= NULL;
cs->len= 0;
cs->cslen= 0;
cs->is_used= false;
cs->valid= false;
}

static void t1_mark_glyphs(MP mp,font_number tex_font);

static void t1_read_subrs(MP mp,font_number tex_font,fm_entry*fm_cur,int read_only)
{
int i,s;
cs_entry*ptr;
t1_getline(mp);
while(!(t1_charstrings()||t1_subrs())){
t1_scan_param(mp,tex_font,fm_cur);
if(!read_only)
t1_putline(mp);
t1_getline(mp);
}
FOUND:
mp->ps->t1_cs= true;
mp->ps->t1_scan= false;
if(!t1_subrs())
return;
mp->ps->subr_size_pos= (int)(strlen("/Subrs")+1);

mp->ps->subr_size= (int)t1_scan_num(mp,mp->ps->t1_line_array+mp->ps->subr_size_pos,0);
if(mp->ps->subr_size==0){
while(!t1_charstrings())
t1_getline(mp);
return;
}

mp->ps->subr_tab= (cs_entry*)mp_xmalloc(mp,(size_t)mp->ps->subr_size,sizeof(cs_entry));
for(ptr= mp->ps->subr_tab;ptr-mp->ps->subr_tab<mp->ps->subr_size;ptr++)
init_cs_entry(ptr);
mp->ps->subr_array_start= mp_xstrdup(mp,mp->ps->t1_line_array);
t1_getline(mp);
while(mp->ps->t1_cslen){
store_subr(mp);
t1_getline(mp);
}

for(i= 0;i<mp->ps->subr_size&&i<4;i++)
mp->ps->subr_tab[i].is_used= true;







#define POST_SUBRS_SCAN     5
s= 0;
*mp->ps->t1_buf_array= 0;
for(i= 0;i<POST_SUBRS_SCAN;i++){
if(t1_charstrings())
break;
s+= (int)(mp->ps->t1_line_ptr-mp->ps->t1_line_array);
alloc_array(t1_buf,s,T1_BUF_SIZE);
strcat(mp->ps->t1_buf_array,mp->ps->t1_line_array);
t1_getline(mp);
}
mp->ps->subr_array_end= mp_xstrdup(mp,mp->ps->t1_buf_array);
if(i==POST_SUBRS_SCAN){

for(ptr= mp->ps->subr_tab;ptr-mp->ps->subr_tab<mp->ps->subr_size;ptr++)
if(ptr->valid)
mp_xfree(ptr->data);
mp_xfree(mp->ps->subr_tab);
mp_xfree(mp->ps->subr_array_start);
mp_xfree(mp->ps->subr_array_end);
cs_init(mp);
mp->ps->t1_cs= false;
mp->ps->t1_synthetic= true;
while(!(t1_charstrings()||t1_subrs()))
t1_getline(mp);
goto FOUND;
}
}

/*:98*//*99:*/
#line 3135 "../../../source/texk/web2c/mplibdir/psout.w"

static void t1_flush_cs(MP mp,boolean is_subr)
{
char*p;
byte*r,*return_cs= NULL;
cs_entry*tab,*end_tab,*ptr;
char*start_line,*line_end;
int count,size_pos;
unsigned short cr,cs_len= 0;
if(is_subr){
start_line= mp->ps->subr_array_start;
line_end= mp->ps->subr_array_end;
size_pos= mp->ps->subr_size_pos;
tab= mp->ps->subr_tab;
count= mp->ps->subr_max+1;
end_tab= mp->ps->subr_tab+count;
}else{
start_line= mp->ps->cs_dict_start;
line_end= mp->ps->cs_dict_end;
size_pos= mp->ps->cs_size_pos;
tab= mp->ps->cs_tab;
end_tab= mp->ps->cs_ptr;
count= mp->ps->cs_count;
}
mp->ps->t1_line_ptr= mp->ps->t1_line_array;
for(p= start_line;p-start_line<size_pos;)
*mp->ps->t1_line_ptr++= *p++;
while(mp_isdigit(*p))
p++;
mp_snprintf(mp->ps->t1_line_ptr,(int)mp->ps->t1_line_limit,"%u",(unsigned)count);
strcat(mp->ps->t1_line_ptr,p);
mp->ps->t1_line_ptr= eol(mp->ps->t1_line_array);
t1_putline(mp);


if(is_subr){
cr= 4330;
cs_len= 0;
return_cs= mp_xmalloc(mp,(size_t)(mp->ps->t1_lenIV+1),sizeof(byte));
if(mp->ps->t1_lenIV>=0){
for(cs_len= 0,r= return_cs;
cs_len<(unsigned short)mp->ps->t1_lenIV;cs_len++,r++)
*r= cencrypt(0x00,&cr);
*r= cencrypt(CS_RETURN,&cr);
}else{
*return_cs= CS_RETURN;
}
cs_len++;
}

for(ptr= tab;ptr<end_tab;ptr++){
if(ptr->is_used){
if(is_subr)
mp_snprintf(mp->ps->t1_line_array,(int)mp->ps->t1_line_limit,
"dup %i %u",(int)(ptr-tab),ptr->cslen);
else
mp_snprintf(mp->ps->t1_line_array,(int)mp->ps->t1_line_limit,
"/%s %u",ptr->glyph_name,ptr->cslen);
p= strend(mp->ps->t1_line_array);
memcpy(p,ptr->data,(size_t)ptr->len);
mp->ps->t1_line_ptr= p+ptr->len;
t1_putline(mp);
}else{

if(is_subr){
mp_snprintf(mp->ps->t1_line_array,(int)mp->ps->t1_line_limit,
"dup %i %u%s ",(int)(ptr-tab),
cs_len,mp->ps->cs_token_pair[0]);
p= strend(mp->ps->t1_line_array);
memcpy(p,return_cs,(size_t)cs_len);
mp->ps->t1_line_ptr= p+cs_len;
t1_putline(mp);
mp_snprintf(mp->ps->t1_line_array,(int)mp->ps->t1_line_limit,
" %s",mp->ps->cs_token_pair[1]);
mp->ps->t1_line_ptr= eol(mp->ps->t1_line_array);
t1_putline(mp);
}
}
mp_xfree(ptr->data);
if(ptr->glyph_name!=notdef)
mp_xfree(ptr->glyph_name);
}
mp_snprintf(mp->ps->t1_line_array,(int)mp->ps->t1_line_limit,"%s",line_end);
mp->ps->t1_line_ptr= eol(mp->ps->t1_line_array);
t1_putline(mp);
if(is_subr)
mp_xfree(return_cs);
mp_xfree(tab);
mp_xfree(start_line);
mp_xfree(line_end);
if(is_subr){
mp->ps->subr_array_start= NULL;
mp->ps->subr_array_end= NULL;
mp->ps->subr_tab= NULL;
}else{
mp->ps->cs_dict_start= NULL;
mp->ps->cs_dict_end= NULL;
mp->ps->cs_tab= NULL;
}
}

static void t1_mark_glyphs(MP mp,font_number tex_font)
{
int i;
char*charset= extra_charset();
char*g,*s,*r;
cs_entry*ptr;
if(mp->ps->t1_synthetic||embed_all_glyphs(tex_font)){
if(mp->ps->cs_tab!=NULL)
for(ptr= mp->ps->cs_tab;ptr<mp->ps->cs_ptr;ptr++)
if(ptr->valid)
ptr->is_used= true;
if(mp->ps->subr_tab!=NULL){
for(ptr= mp->ps->subr_tab;ptr-mp->ps->subr_tab<mp->ps->subr_size;ptr++)
if(ptr->valid)
ptr->is_used= true;
mp->ps->subr_max= mp->ps->subr_size-1;
}
return;
}
mark_cs(mp,notdef);
for(i= 0;i<256;i++)
if(is_used_char(i)){
if(mp->ps->t1_glyph_names[i]==notdef||
strcmp(mp->ps->t1_glyph_names[i],notdef)==0){
char S[128];
mp_snprintf(S,128,"character %i is mapped to %s",i,notdef);
mp_warn(mp,S);
}else
mark_cs(mp,mp->ps->t1_glyph_names[i]);
}
if(charset==NULL)
goto SET_SUBR_MAX;
g= s= charset+1;
r= strend(g);
while(g<r){
while(*s!='/'&&s<r)
s++;
*s= 0;
mark_cs(mp,g);
g= s+1;
}
SET_SUBR_MAX:
if(mp->ps->subr_tab!=NULL)
for(mp->ps->subr_max= -1,ptr= mp->ps->subr_tab;
ptr-mp->ps->subr_tab<mp->ps->subr_size;
ptr++)
if(ptr->is_used&&ptr-mp->ps->subr_tab> mp->ps->subr_max)
mp->ps->subr_max= (int)(ptr-mp->ps->subr_tab);
}

static void t1_do_subset_charstrings(MP mp,font_number tex_font)
{
cs_entry*ptr;
mp->ps->cs_size_pos= (int)(
strstr(mp->ps->t1_line_array,charstringname)+strlen(charstringname)
-mp->ps->t1_line_array+1);


mp->ps->cs_size= (int)t1_scan_num(mp,mp->ps->t1_line_array+mp->ps->cs_size_pos,0);
mp->ps->cs_ptr= mp->ps->cs_tab= mp_xmalloc(mp,(size_t)mp->ps->cs_size,sizeof(cs_entry));
for(ptr= mp->ps->cs_tab;ptr-mp->ps->cs_tab<mp->ps->cs_size;ptr++)
init_cs_entry(ptr);
mp->ps->cs_notdef= NULL;
mp->ps->cs_dict_start= mp_xstrdup(mp,mp->ps->t1_line_array);
t1_getline(mp);
while(mp->ps->t1_cslen){
store_cs(mp);
t1_getline(mp);
}
mp->ps->cs_dict_end= mp_xstrdup(mp,mp->ps->t1_line_array);
t1_mark_glyphs(mp,tex_font);
}

static void t1_subset_charstrings(MP mp,font_number tex_font)
{
cs_entry*ptr;
t1_do_subset_charstrings(mp,tex_font);
if(mp->ps->subr_tab!=NULL){
if(mp->ps->cs_token_pair==NULL)
mp_fatal_error
(mp,"This Type 1 font uses mismatched subroutine begin/end token pairs.");
t1_subr_flush(mp);
}
for(mp->ps->cs_count= 0,ptr= mp->ps->cs_tab;ptr<mp->ps->cs_ptr;ptr++)
if(ptr->is_used)
mp->ps->cs_count++;
t1_cs_flush(mp);
}

static void t1_subset_end(MP mp)
{
if(mp->ps->t1_synthetic){
while(!strstr(mp->ps->t1_line_array,"definefont")){
t1_getline(mp);
t1_putline(mp);
}
while(!t1_end_eexec())
t1_getline(mp);
t1_putline(mp);
}else
while(!t1_end_eexec()){
t1_getline(mp);
t1_putline(mp);
}
t1_stop_eexec(mp);
if(fixedcontent){
while(!t1_cleartomark()){
t1_getline(mp);
t1_putline(mp);
}
if(!mp->ps->t1_synthetic)
t1_check_end(mp);
}
}

static int t1_updatefm(MP mp,font_number f,fm_entry*fm)
{
char*s,*p;
mp->ps->read_encoding_only= true;
if(!t1_open_fontfile(mp,fm,NULL)){
return 0;
}
t1_scan_only(mp,f,fm);
s= mp_xstrdup(mp,mp->ps->fontname_buf);
p= s;
while(*p!=' '&&*p!=0)
p++;
*p= 0;
mp_xfree(fm->ps_name);
fm->ps_name= s;
t1_close_font_file(mp,"");
return 1;
}


static void writet1(MP mp,font_number tex_font,fm_entry*fm_cur){
unsigned save_selector= mp->selector;
mp_normalize_selector(mp);
mp->ps->read_encoding_only= false;
if(!is_included(fm_cur)){
if(!t1_open_fontfile(mp,fm_cur,"{"))
return;
t1_scan_only(mp,tex_font,fm_cur);
t1_close_font_file(mp,"}");
return;
}
if(!is_subsetted(fm_cur)){
if(!t1_open_fontfile(mp,fm_cur,"<<"))
return;
t1_include(mp,tex_font,fm_cur);
t1_close_font_file(mp,">>");
return;
}

if(!t1_open_fontfile(mp,fm_cur,"<"))
return;
t1_subset_ascii_part(mp,tex_font,fm_cur);
t1_start_eexec(mp,fm_cur);
cc_init();
cs_init(mp);
t1_read_subrs(mp,tex_font,fm_cur,false);
t1_subset_charstrings(mp,tex_font);
t1_subset_end(mp);
t1_close_font_file(mp,">");
mp->selector= save_selector;
}

/*:99*//*101:*/
#line 3406 "../../../source/texk/web2c/mplibdir/psout.w"

static void t1_free(MP mp){
int k;

mp_xfree(mp->ps->subr_array_start);
mp_xfree(mp->ps->subr_array_end);
mp_xfree(mp->ps->cs_dict_start);
mp_xfree(mp->ps->cs_dict_end);
cs_init(mp);

mp_xfree(mp->ps->t1_line_array);
mp_xfree(mp->ps->char_array);
mp->ps->char_array= NULL;

mp->ps->t1_line_array= mp->ps->t1_line_ptr= NULL;
mp->ps->t1_line_limit= 0;
mp_xfree(mp->ps->t1_buf_array);
mp->ps->t1_buf_array= mp->ps->t1_buf_ptr= NULL;
mp->ps->t1_buf_limit= 0;

for(k= 0;k<=255;k++){
if(mp->ps->t1_builtin_glyph_names[k]!=notdef)
mp_xfree(mp->ps->t1_builtin_glyph_names[k]);
mp->ps->t1_builtin_glyph_names[k]= notdef;
}
}

/*:101*//*103:*/
#line 3454 "../../../source/texk/web2c/mplibdir/psout.w"


mp_ps_font*mp_ps_font_parse(MP mp,int tex_font){
mp_ps_font*f;
fm_entry*fm_cur;
char msg[128];
(void)mp_has_fm_entry(mp,(font_number)tex_font,&fm_cur);
if(fm_cur==NULL){
mp_snprintf(msg,128,"fontmap entry for `%s' not found",mp->font_name[tex_font]);
mp_warn(mp,msg);
return NULL;
}
if(is_truetype(fm_cur)||
(fm_cur->ps_name==NULL&&fm_cur->ff_name==NULL)||
(!is_included(fm_cur))){
mp_snprintf(msg,128,"font `%s' cannot be embedded",mp->font_name[tex_font]);
mp_warn(mp,msg);
return NULL;
}
if(!t1_open_fontfile(mp,fm_cur,"<")){
return NULL;
}
f= mp_xmalloc(mp,1,sizeof(struct mp_ps_font));
f->font_num= tex_font;
f->t1_glyph_names= NULL;
f->cs_tab= NULL;
f->cs_ptr= NULL;
f->subr_tab= NULL;
f->orig_x= f->orig_y= 0.0;
f->slant= (int)fm_cur->slant;
f->extend= (int)fm_cur->extend;
t1_getline(mp);
while(!t1_prefix("/Encoding")){
t1_scan_param(mp,(font_number)tex_font,fm_cur);
t1_getline(mp);
}
t1_builtin_enc(mp);
if(is_reencoded(fm_cur)){
mp_read_enc(mp,fm_cur->encoding);;
f->t1_glyph_names= external_enc();
}else{
f->t1_glyph_names= mp->ps->t1_builtin_glyph_names;
}
do{
t1_getline(mp);
t1_scan_param(mp,(font_number)tex_font,fm_cur);
}while(mp->ps->t1_in_eexec==0);


cc_init();
cs_init(mp);


t1_read_subrs(mp,(font_number)tex_font,fm_cur,true);
mp->ps->t1_synthetic= true;
t1_do_subset_charstrings(mp,(font_number)tex_font);
f->cs_tab= mp->ps->cs_tab;
mp->ps->cs_tab= NULL;
f->cs_ptr= mp->ps->cs_ptr;
mp->ps->cs_ptr= NULL;
f->subr_tab= mp->ps->subr_tab;
mp->ps->subr_tab= NULL;
f->subr_size= mp->ps->subr_size;
mp->ps->subr_size= mp->ps->subr_size_pos= 0;
f->t1_lenIV= mp->ps->t1_lenIV;
t1_close_font_file(mp,">");
return f;
}

/*:103*//*105:*/
#line 3528 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_ps_font_free(MP mp,mp_ps_font*f){
cs_entry*ptr;
for(ptr= f->cs_tab;ptr<f->cs_ptr;ptr++){
if(ptr->glyph_name!=notdef)
mp_xfree(ptr->glyph_name);
mp_xfree(ptr->data);
}
mp_xfree(f->cs_tab);
f->cs_tab= NULL;
for(ptr= f->subr_tab;ptr-f->subr_tab<f->subr_size;ptr++){
if(ptr->glyph_name!=notdef)
mp_xfree(ptr->glyph_name);
mp_xfree(ptr->data);
}
mp_xfree(f->subr_tab);
f->subr_tab= NULL;
t1_free(mp);
mp_xfree(f);
}

/*:105*//*108:*/
#line 3566 "../../../source/texk/web2c/mplibdir/psout.w"

mp_edge_object*mp_ps_do_font_charstring(MP mp,mp_ps_font*f,char*nam){
mp_edge_object*h= NULL;
f->h= NULL;f->p= NULL;f->pp= NULL;f->ignore_flex_hint= 0;f->flex_hint_index= 0;
f->cur_x= f->cur_y= 0.0;
f->orig_x= f->orig_y= 0.0;
if(nam==NULL){
mp_warn(mp,"nonexistant glyph requested");
return h;
}
if(cs_parse(mp,f,nam,0)){
h= f->h;
}else{
char err[256];
mp_snprintf(err,255,"Glyph interpreter failed (missing glyph '%s'?)",nam);
mp_warn(mp,err);
if(f->h!=NULL){
finish_subpath(mp,f);
mp_gr_toss_objects(f->h);
}
}
f->h= NULL;f->p= NULL;f->pp= NULL;
return h;
}

mp_edge_object*mp_ps_font_charstring(MP mp,mp_ps_font*f,int c){
char*s= NULL;
if(f!=NULL&&f->t1_glyph_names!=NULL&&c>=0&&c<256)
s= f->t1_glyph_names[c];
return mp_ps_do_font_charstring(mp,f,s);
}



/*:108*//*111:*/
#line 3610 "../../../source/texk/web2c/mplibdir/psout.w"

static void start_subpath(MP mp,mp_ps_font*f,double dx,double dy)
{
assert(f->pp==NULL);
assert(f->p==NULL);
f->pp= mp_xmalloc(mp,1,sizeof(struct mp_gr_knot_data));
f->pp->data.types.left_type= mp_explicit;
f->pp->data.types.right_type= mp_explicit;
f->pp->x_coord= (f->cur_x+dx);
f->pp->y_coord= (f->cur_y+dy);
f->pp->left_x= f->pp->right_x= f->pp->x_coord;
f->pp->left_y= f->pp->right_y= f->pp->y_coord;
f->pp->next= NULL;
f->cur_x+= dx;
f->cur_y+= dy;
f->p= mp_new_graphic_object(mp,mp_fill_code);
gr_path_p((mp_fill_object*)f->p)= f->pp;
}

static void add_line_segment(MP mp,mp_ps_font*f,double dx,double dy)
{
mp_gr_knot n;
assert(f->pp!=NULL);
n= mp_xmalloc(mp,1,sizeof(struct mp_gr_knot_data));
n->data.types.left_type= mp_explicit;
n->data.types.right_type= mp_explicit;
n->next= gr_path_p((mp_fill_object*)f->p);
n->x_coord= (f->cur_x+dx);
n->y_coord= (f->cur_y+dy);
n->right_x= n->x_coord;
n->right_y= n->y_coord;
n->left_x= n->x_coord;
n->left_y= n->y_coord;
f->pp->next= n;
f->pp= n;
f->cur_x+= dx;
f->cur_y+= dy;
}

static void add_curve_segment(MP mp,mp_ps_font*f,double dx1,double dy1,double dx2,
double dy2,double dx3,double dy3)
{
mp_gr_knot n;
n= mp_xmalloc(mp,1,sizeof(struct mp_gr_knot_data));
n->data.types.left_type= mp_explicit;
n->data.types.right_type= mp_explicit;
n->next= gr_path_p((mp_fill_object*)f->p);
n->x_coord= (f->cur_x+dx1+dx2+dx3);
n->y_coord= (f->cur_y+dy1+dy2+dy3);
n->right_x= n->x_coord;
n->right_y= n->y_coord;
n->left_x= (f->cur_x+dx1+dx2);
n->left_y= (f->cur_y+dy1+dy2);
f->pp->right_x= (f->cur_x+dx1);
f->pp->right_y= (f->cur_y+dy1);
f->pp->next= n;
f->pp= n;
f->cur_x+= dx1+dx2+dx3;
f->cur_y+= dy1+dy2+dy3;
}

static void finish_subpath(MP mp,mp_ps_font*f)
{
if(f->p!=NULL){
if(f->h->body==NULL){
f->h->body= f->p;
}else{
mp_graphic_object*q= f->h->body;
while(gr_link(q)!=NULL)
q= gr_link(q);
q->next= f->p;
}
}
if(f->p!=NULL){
mp_gr_knot r,rr;
assert(f->pp!=NULL);
r= gr_path_p((mp_fill_object*)f->p);
rr= r;
if(r){
if(r==f->pp){
r->next= r;
}else if(r->x_coord==f->pp->x_coord&&r->y_coord==f->pp->y_coord){
while(rr->next!=f->pp)
rr= rr->next;
rr->next= r;
r->left_x= f->pp->left_x;
r->left_y= f->pp->left_y;
mp_xfree(f->pp);
}
}
}
f->p= NULL;
f->pp= NULL;
}

/*:111*//*113:*/
#line 3717 "../../../source/texk/web2c/mplibdir/psout.w"

void cs_do_debug(MP mp,mp_ps_font*f,int i,char*s){
int n= cc_tab[i].nargs;
(void)mp;
(void)f;
while(n> 0){
fprintf(stdout,"%d ",(int)cc_get((-n)));
n--;
}
fprintf(stdout,"%s\n",s);
}

boolean cs_parse(MP mp,mp_ps_font*f,const char*cs_name,int subr)
{
byte*data;
int i,b,cs_len;
integer a,a1,a2;
unsigned short cr;
static integer lastargOtherSubr3= 3;

cs_entry*ptr;
cc_entry*cc;

if(cs_name==NULL){
ptr= f->subr_tab+subr;
}else{
i= 0;
for(ptr= f->cs_tab;ptr<f->cs_ptr;ptr++,i++){
if(strcmp(ptr->glyph_name,cs_name)==0)
break;
}
ptr= f->cs_tab+i;
}
if(ptr==f->cs_ptr)
return false;
data= ptr->data+4;
cr= 4330;
cs_len= (int)ptr->cslen;
for(i= 0;i<f->t1_lenIV;i++,cs_len--)
(void)cs_getchar(mp);

while(cs_len> 0){
--cs_len;
b= cs_getchar(mp);
if(b>=32){
if(b<=246)
a= b-139;
else if(b<=250){
--cs_len;
a= (int)((unsigned)(b-247)<<8)+108+cs_getchar(mp);
}else if(b<=254){
--cs_len;
a= -(int)((unsigned)(b-251)<<8)-108-cs_getchar(mp);
}else{
cs_len-= 4;
a= (cs_getchar(mp)&0xff)<<24;
a|= (cs_getchar(mp)&0xff)<<16;
a|= (cs_getchar(mp)&0xff)<<8;
a|= (cs_getchar(mp)&0xff)<<0;
if(sizeof(integer)> 4&&(a&0x80000000))
a|= ~0x7FFFFFFF;
}
cc_push(a);
}else{
if(b==CS_ESCAPE){
b= cs_getchar(mp)+CS_1BYTE_MAX;
cs_len--;
}
if(b>=CS_MAX){
cs_warn(mp,cs_name,subr,"command value out of range: %i",
(int)b);
goto cs_error;
}
cc= cc_tab+b;
if(!cc->valid){
cs_warn(mp,cs_name,subr,"command not valid: %i",(int)b);
goto cs_error;
}
if(cc->bottom){
if(stack_ptr-cc_stack<cc->nargs)
cs_warn(mp,cs_name,subr,
"less arguments on stack (%i) than required (%i)",
(int)(stack_ptr-cc_stack),(int)cc->nargs);
else if(stack_ptr-cc_stack> cc->nargs)
cs_warn(mp,cs_name,subr,
"more arguments on stack (%i) than required (%i)",
(int)(stack_ptr-cc_stack),(int)cc->nargs);
}
switch(cc-cc_tab){
case CS_CLOSEPATH:
cs_debug(CS_CLOSEPATH);
finish_subpath(mp,f);
cc_clear();
break;
case CS_HLINETO:
cs_debug(CS_HLINETO);
add_line_segment(mp,f,cc_get(-1),0);
cc_clear();
break;
case CS_HVCURVETO:
cs_debug(CS_HVCURVETO);
add_curve_segment(mp,f,cc_get(-4),0,cc_get(-3),cc_get(-2),0,cc_get(-1));
cc_clear();
break;
case CS_RLINETO:
cs_debug(CS_RLINETO);
add_line_segment(mp,f,cc_get(-2),cc_get(-1));
cc_clear();
break;
case CS_RRCURVETO:
cs_debug(CS_RRCURVETO);
add_curve_segment(mp,f,cc_get(-6),cc_get(-5),cc_get(-4),cc_get(-3),cc_get(-2),cc_get(-1));
cc_clear();
break;
case CS_VHCURVETO:
cs_debug(CS_VHCURVETO);
add_curve_segment(mp,f,0,cc_get(-4),cc_get(-3),cc_get(-2),cc_get(-1),0);
cc_clear();
break;
case CS_VLINETO:
cs_debug(CS_VLINETO);
add_line_segment(mp,f,0,cc_get(-1));
cc_clear();
break;
case CS_HMOVETO:
cs_debug(CS_HMOVETO);


if(f->pp==NULL){
start_subpath(mp,f,cc_get(-1),0);
}else{
add_line_segment(mp,f,cc_get(-1),0);
}
cc_clear();
break;
case CS_RMOVETO:
cs_debug(CS_RMOVETO);
if(f->ignore_flex_hint==1){
f->flex_hint_data[f->flex_hint_index++]= cc_get(-2);
f->flex_hint_data[f->flex_hint_index++]= cc_get(-1);
}else{
if(f->pp==NULL){
start_subpath(mp,f,cc_get(-2),cc_get(-1));
}else{
add_line_segment(mp,f,cc_get(-2),cc_get(-1));
}
}
cc_clear();
break;
case CS_VMOVETO:
cs_debug(CS_VMOVETO);
if(f->pp==NULL){
start_subpath(mp,f,0,cc_get(-1));
}else{
add_line_segment(mp,f,0,cc_get(-1));
}
cc_clear();
break;

case CS_DOTSECTION:
cs_debug(CS_DOTSECTION);
cc_clear();
break;
case CS_HSTEM:
cs_debug(CS_HSTEM);
cc_clear();
break;
case CS_HSTEM3:
cs_debug(CS_HSTEM3);
cc_clear();
break;
case CS_VSTEM:
cs_debug(CS_VSTEM);
cc_clear();
break;
case CS_VSTEM3:
cs_debug(CS_VSTEM3);
cc_clear();
break;

case CS_SEAC:
cs_debug(CS_SEAC);
{double adx,ady,asb;
asb= cc_get(0);
adx= cc_get(1);
ady= cc_get(2);
a1= (integer)cc_get(3);
a2= (integer)cc_get(4);
cc_clear();
(void)cs_parse(mp,f,standard_glyph_names[a1],0);
f->orig_x+= (adx-asb);
f->orig_y+= ady;
(void)cs_parse(mp,f,standard_glyph_names[a2],0);
}
break;
case CS_ENDCHAR:
cs_debug(CS_ENDCHAR);
cc_clear();
return true;
break;
case CS_HSBW:
cs_debug(CS_HSBW);
if(!f->h){
f->h= mp_xmalloc(mp,1,sizeof(mp_edge_object));
f->h->body= NULL;f->h->next= NULL;
f->h->parent= mp;
f->h->filename= NULL;
f->h->minx= f->h->miny= f->h->maxx= f->h->maxy= 0.0;
}
f->cur_x= cc_get(-2)+f->orig_x;
f->cur_y= 0.0+f->orig_y;
f->orig_x= f->cur_x;
f->orig_y= f->cur_y;
cc_clear();
break;
case CS_SBW:
cs_debug(CS_SBW);
if(!f->h){
f->h= mp_xmalloc(mp,1,sizeof(mp_edge_object));
f->h->body= NULL;f->h->next= NULL;
f->h->parent= mp;
f->h->filename= NULL;
f->h->minx= f->h->miny= f->h->maxx= f->h->maxy= 0.0;
}
f->cur_x= cc_get(-4)+f->orig_x;
f->cur_y= cc_get(-3)+f->orig_y;
f->orig_x= f->cur_x;
f->orig_y= f->cur_y;
cc_clear();
break;

case CS_DIV:
cs_debug(CS_DIV);
{double num,den,res;
num= cc_get(-2);
den= cc_get(-1);
res= num/den;
cc_pop(2);
cc_push(res);
break;
}

case CS_CALLSUBR:
cs_debug(CS_CALLSUBR);
a1= (integer)cc_get(-1);
if(a1==1)
f->ignore_flex_hint= 1;
if(a1==0){



























f->ignore_flex_hint= 0;
f->flex_hint_index= 0;
add_curve_segment(mp,f,f->flex_hint_data[0]+f->flex_hint_data[2],f->flex_hint_data[1]+f->flex_hint_data[3],
f->flex_hint_data[4],f->flex_hint_data[5],
f->flex_hint_data[6],f->flex_hint_data[7]);
add_curve_segment(mp,f,f->flex_hint_data[8],f->flex_hint_data[9],
f->flex_hint_data[10],f->flex_hint_data[11],
f->flex_hint_data[12],f->flex_hint_data[13]);
}
cc_pop(1);
(void)cs_parse(mp,f,NULL,a1);
break;
case CS_RETURN:
cs_debug(CS_RETURN);
return true;
break;
case CS_CALLOTHERSUBR:
cs_debug(CS_CALLOTHERSUBR);
a1= (integer)cc_get(-1);
if(a1==3)
lastargOtherSubr3= (integer)cc_get(-3);
a1= (integer)cc_get(-2)+2;
cc_pop(a1);
break;
case CS_POP:
cc_push(lastargOtherSubr3);
break;
case CS_SETCURRENTPOINT:
cs_debug(CS_SETCURRENTPOINT);

cc_clear();
break;
default:
if(cc->clear)
cc_clear();
}
}
}
return true;
cs_error:
cc_clear();
ptr->valid= false;
ptr->is_used= false;
return false;
}

/*:113*//*118:*/
#line 4102 "../../../source/texk/web2c/mplibdir/psout.w"

boolean mp_font_is_reencoded(MP mp,font_number f){
fm_entry*fm;
if(mp_has_font_size(mp,f)&&mp_has_fm_entry(mp,f,&fm)){
if(fm!=NULL
&&(fm->ps_name!=NULL)
&&is_reencoded(fm))
return true;
}
return false;
}
boolean mp_font_is_included(MP mp,font_number f){
fm_entry*fm;
if(mp_has_font_size(mp,f)&&mp_has_fm_entry(mp,f,&fm)){
if(fm!=NULL
&&(fm->ps_name!=NULL&&fm->ff_name!=NULL)
&&is_included(fm))
return true;
}
return false;
}
boolean mp_font_is_subsetted(MP mp,font_number f){
fm_entry*fm;
if(mp_has_font_size(mp,f)&&mp_has_fm_entry(mp,f,&fm)){
if(fm!=NULL
&&(fm->ps_name!=NULL&&fm->ff_name!=NULL)
&&is_included(fm)&&is_subsetted(fm))
return true;
}
return false;
}

/*:118*//*120:*/
#line 4140 "../../../source/texk/web2c/mplibdir/psout.w"
char*mp_fm_encoding_name(MP mp,font_number f){
enc_entry*e;
fm_entry*fm;
if(mp_has_fm_entry(mp,f,&fm)){
if(fm!=NULL&&(fm->ps_name!=NULL)){
if(is_reencoded(fm)){
e= fm->encoding;
if(e->enc_name!=NULL)
return mp_xstrdup(mp,e->enc_name);
}else{
return NULL;
}
}
}
{
char msg[256];
mp_snprintf(msg,256,"fontmap encoding problems for font %s",mp->font_name[f]);
mp_error(mp,msg,NULL,true);
}
return NULL;
}
char*mp_fm_font_name(MP mp,font_number f){
fm_entry*fm;
if(mp_has_fm_entry(mp,f,&fm)){
if(fm!=NULL&&(fm->ps_name!=NULL)){
if(mp_font_is_included(mp,f)&&!mp->font_ps_name_fixed[f]){

if(t1_updatefm(mp,f,fm)){
mp->font_ps_name_fixed[f]= true;
}else{
char msg[256];
mp_snprintf(msg,256,"font loading problems for font %s",mp->font_name[f]);
mp_error(mp,msg,NULL,true);
}
}
return mp_xstrdup(mp,fm->ps_name);
}
}
{
char msg[256];
mp_snprintf(msg,256,"fontmap name problems for font %s",mp->font_name[f]);
mp_error(mp,msg,NULL,true);
}
return NULL;
}

static char*mp_fm_font_subset_name(MP mp,font_number f){
fm_entry*fm;
if(mp_has_fm_entry(mp,f,&fm)){
if(fm!=NULL&&(fm->ps_name!=NULL)){
if(is_subsetted(fm)){
char*s= mp_xmalloc(mp,strlen(fm->ps_name)+8,1);
mp_snprintf(s,(int)strlen(fm->ps_name)+8,"%s-%s",fm->subset_tag,fm->ps_name);
return s;
}else{
return mp_xstrdup(mp,fm->ps_name);
}
}
}
{
char msg[256];
mp_snprintf(msg,256,"fontmap name problems for font %s",mp->font_name[f]);
mp_error(mp,msg,NULL,true);
}
return NULL;
}

/*:120*//*122:*/
#line 4212 "../../../source/texk/web2c/mplibdir/psout.w"
static integer mp_fm_font_slant(MP mp,font_number f){
fm_entry*fm;
if(mp_has_fm_entry(mp,f,&fm)){
if(fm!=NULL&&(fm->ps_name!=NULL)){
return fm->slant;
}
}
return 0;
}
static integer mp_fm_font_extend(MP mp,font_number f){
fm_entry*fm;
if(mp_has_fm_entry(mp,f,&fm)){
if(fm!=NULL&&(fm->ps_name!=NULL)){
return fm->extend;
}
}
return 0;
}

/*:122*//*124:*/
#line 4234 "../../../source/texk/web2c/mplibdir/psout.w"
static boolean mp_do_ps_font(MP mp,font_number f){
fm_entry*fm_cur;
(void)mp_has_fm_entry(mp,f,&fm_cur);
if(fm_cur==NULL)
return true;
if(is_truetype(fm_cur)||
(fm_cur->ps_name==NULL&&fm_cur->ff_name==NULL)){
return false;
}
if(is_included(fm_cur)){
mp_ps_print_nl(mp,"%%BeginResource: font ");
if(is_subsetted(fm_cur)){
mp_ps_print(mp,fm_cur->subset_tag);
mp_ps_print_char(mp,'-');
}
mp_ps_print(mp,fm_cur->ps_name);
mp_ps_print_ln(mp);
writet1(mp,f,fm_cur);
mp_ps_print_nl(mp,"%%EndResource");
mp_ps_print_ln(mp);
}
return true;
}

/*:124*//*126:*/
#line 4264 "../../../source/texk/web2c/mplibdir/psout.w"
static void mp_list_used_resources(MP mp,int prologues,int procset){
font_number f;
int ff;
int ldf;
boolean firstitem;
if(procset> 0)
mp_ps_print_nl(mp,"%%DocumentResources: procset mpost");
else
mp_ps_print_nl(mp,"%%DocumentResources: procset mpost-minimal");
ldf= null_font;
firstitem= true;
for(f= null_font+1;f<=mp->last_fnum;f++){
if((mp_has_font_size(mp,f))&&(mp_font_is_reencoded(mp,f))){
for(ff= ldf;ff>=null_font;ff--){
if(mp_has_font_size(mp,(font_number)ff))
if(mp_xstrcmp(mp->font_enc_name[f],mp->font_enc_name[ff])==0)
goto FOUND;
}
if(mp_font_is_subsetted(mp,f))
goto FOUND;
if((size_t)mp->ps->ps_offset+1+strlen(mp->font_enc_name[f])>
(size_t)mp->max_print_line)
mp_ps_print_nl(mp,"%%+ encoding");
if(firstitem){
firstitem= false;
mp_ps_print_nl(mp,"%%+ encoding");
}
mp_ps_print_char(mp,' ');
mp_ps_dsc_print(mp,"encoding",mp->font_enc_name[f]);
ldf= (int)f;
}
FOUND:
;
}
ldf= null_font;
firstitem= true;
for(f= null_font+1;f<=mp->last_fnum;f++){
if(mp_has_font_size(mp,f)){
for(ff= ldf;ff>=null_font;ff--){
if(mp_has_font_size(mp,(font_number)ff))
if(mp_xstrcmp(mp->font_name[f],mp->font_name[ff])==0)
goto FOUND2;
}
if((size_t)mp->ps->ps_offset+1+strlen(mp->font_ps_name[f])>
(size_t)mp->max_print_line)
mp_ps_print_nl(mp,"%%+ font");
if(firstitem){
firstitem= false;
mp_ps_print_nl(mp,"%%+ font");
}
mp_ps_print_char(mp,' ');
if((prologues==3)&&(mp_font_is_subsetted(mp,f))){
char*s= mp_fm_font_subset_name(mp,f);
mp_ps_dsc_print(mp,"font",s);
mp_xfree(s);
}else{
mp_ps_dsc_print(mp,"font",mp->font_ps_name[f]);
}
ldf= (int)f;
}
FOUND2:
;
}
mp_ps_print_ln(mp);
}

/*:126*//*128:*/
#line 4333 "../../../source/texk/web2c/mplibdir/psout.w"
static void mp_list_supplied_resources(MP mp,int prologues,int procset){
font_number f;
int ff;
int ldf;
boolean firstitem;
if(procset> 0)
mp_ps_print_nl(mp,"%%DocumentSuppliedResources: procset mpost");
else
mp_ps_print_nl(mp,"%%DocumentSuppliedResources: procset mpost-minimal");
ldf= null_font;
firstitem= true;
for(f= null_font+1;f<=mp->last_fnum;f++){
if((mp_has_font_size(mp,f))&&(mp_font_is_reencoded(mp,f))){
for(ff= ldf;ff>=null_font;ff++){
if(mp_has_font_size(mp,(font_number)ff))
if(mp_xstrcmp(mp->font_enc_name[f],mp->font_enc_name[ff])==0)
goto FOUND;
}
if((prologues==3)&&(mp_font_is_subsetted(mp,f)))
goto FOUND;
if((size_t)mp->ps->ps_offset+1+strlen(mp->font_enc_name[f])> (size_t)mp->max_print_line)
mp_ps_print_nl(mp,"%%+ encoding");
if(firstitem){
firstitem= false;
mp_ps_print_nl(mp,"%%+ encoding");
}
mp_ps_print_char(mp,' ');
mp_ps_dsc_print(mp,"encoding",mp->font_enc_name[f]);
ldf= (int)f;
}
FOUND:
;
}
ldf= null_font;
firstitem= true;
if(prologues==3){
for(f= null_font+1;f<=mp->last_fnum;f++){
if(mp_has_font_size(mp,f)){
for(ff= ldf;ff>=null_font;ff--){
if(mp_has_font_size(mp,(font_number)ff))
if(mp_xstrcmp(mp->font_name[f],mp->font_name[ff])==0)
goto FOUND2;
}
if(!mp_font_is_included(mp,f))
goto FOUND2;
if((size_t)mp->ps->ps_offset+1+strlen(mp->font_ps_name[f])> (size_t)mp->max_print_line)
mp_ps_print_nl(mp,"%%+ font");
if(firstitem){
firstitem= false;
mp_ps_print_nl(mp,"%%+ font");
}
mp_ps_print_char(mp,' ');
if(mp_font_is_subsetted(mp,f)){
char*s= mp_fm_font_subset_name(mp,f);
mp_ps_dsc_print(mp,"font",s);
mp_xfree(s);
}else{
mp_ps_dsc_print(mp,"font",mp->font_ps_name[f]);
}
ldf= (int)f;
}
FOUND2:
;
}
mp_ps_print_ln(mp);
}
}

/*:128*//*130:*/
#line 4404 "../../../source/texk/web2c/mplibdir/psout.w"
static void mp_list_needed_resources(MP mp,int prologues){
font_number f;
int ff;
int ldf;
boolean firstitem;
ldf= null_font;
firstitem= true;
for(f= null_font+1;f<=mp->last_fnum;f++){
if(mp_has_font_size(mp,f)){
for(ff= ldf;ff>=null_font;ff--){
if(mp_has_font_size(mp,(font_number)ff))
if(mp_xstrcmp(mp->font_name[f],mp->font_name[ff])==0)
goto FOUND;
};
if((prologues==3)&&(mp_font_is_included(mp,f)))
goto FOUND;
if((size_t)mp->ps->ps_offset+1+strlen(mp->font_ps_name[f])> (size_t)mp->max_print_line)
mp_ps_print_nl(mp,"%%+ font");
if(firstitem){
firstitem= false;
mp_ps_print_nl(mp,"%%DocumentNeededResources: font");
}
mp_ps_print_char(mp,' ');
mp_ps_dsc_print(mp,"font",mp->font_ps_name[f]);
ldf= (int)f;
}
FOUND:
;
}
if(!firstitem){
mp_ps_print_ln(mp);
ldf= null_font;

for(f= null_font+1;f<=mp->last_fnum;f++){
if(mp_has_font_size(mp,f)){
for(ff= ldf;ff>=null_font;ff--){
if(mp_has_font_size(mp,(font_number)ff))
if(mp_xstrcmp(mp->font_name[f],mp->font_name[ff])==0)
goto FOUND2;
}
if((prologues==3)&&(mp_font_is_included(mp,f)))
goto FOUND2;
mp_ps_print(mp,"%%IncludeResource: font ");
mp_ps_print(mp,mp->font_ps_name[f]);
mp_ps_print_ln(mp);
ldf= (int)f;
}
FOUND2:
;
}
}
}

/*:130*//*132:*/
#line 4465 "../../../source/texk/web2c/mplibdir/psout.w"
static void mp_write_font_definition(MP mp,font_number f,int prologues){
if((applied_reencoding(f))||(mp_fm_font_slant(mp,f)!=0)||
(mp_fm_font_extend(mp,f)!=0)||
(mp_xstrcmp(mp->font_name[f],"psyrgo")==0)||
(mp_xstrcmp(mp->font_name[f],"zpzdr-reversed")==0)){
if((mp_font_is_subsetted(mp,f))&&
(mp_font_is_included(mp,f))&&(prologues==3)){
char*s= mp_fm_font_subset_name(mp,f);
mp_ps_name_out(mp,s,true);
mp_xfree(s);
}else{
mp_ps_name_out(mp,mp->font_ps_name[f],true);
}
mp_ps_print(mp," fcp");
mp_ps_print_ln(mp);
if(applied_reencoding(f)){
mp_ps_print(mp,"/Encoding ");
mp_ps_print(mp,mp->font_enc_name[f]);
mp_ps_print(mp," def ");
};
if(mp_fm_font_slant(mp,f)!=0){
mp_ps_print_int(mp,mp_fm_font_slant(mp,f));
mp_ps_print(mp," SlantFont ");
};
if(mp_fm_font_extend(mp,f)!=0){
mp_ps_print_int(mp,mp_fm_font_extend(mp,f));
mp_ps_print(mp," ExtendFont ");
};
if(mp_xstrcmp(mp->font_name[f],"psyrgo")==0){
mp_ps_print(mp," 890 ScaleFont ");
mp_ps_print(mp," 277 SlantFont ");
};
if(mp_xstrcmp(mp->font_name[f],"zpzdr-reversed")==0){
mp_ps_print(mp," FontMatrix [-1 0 0 1 0 0] matrix concatmatrix /FontMatrix exch def ");
mp_ps_print(mp,"/Metrics 2 dict dup begin ");
mp_ps_print(mp,"/space[0 -278]def ");
mp_ps_print(mp,"/a12[-904 -939]def ");
mp_ps_print(mp,"end def ");
};
mp_ps_print(mp,"currentdict end");
mp_ps_print_ln(mp);
mp_ps_print_defined_name(mp,f,prologues);
mp_ps_print(mp," exch definefont pop");
mp_ps_print_ln(mp);
}
}

/*:132*//*134:*/
#line 4516 "../../../source/texk/web2c/mplibdir/psout.w"
static void mp_ps_print_defined_name(MP mp,font_number f,int prologues){
mp_ps_print(mp," /");
if((mp_font_is_subsetted(mp,f))&&
(mp_font_is_included(mp,f))&&(prologues==3)){
char*s= mp_fm_font_subset_name(mp,f);
mp_ps_print(mp,s);
mp_xfree(s);
}else{
mp_ps_print(mp,mp->font_ps_name[f]);
}
if(mp_xstrcmp(mp->font_name[f],"psyrgo")==0)
mp_ps_print(mp,"-Slanted");
if(mp_xstrcmp(mp->font_name[f],"zpzdr-reversed")==0)
mp_ps_print(mp,"-Reverse");
if(applied_reencoding(f)){
mp_ps_print(mp,"-");
mp_ps_print(mp,mp->font_enc_name[f]);
}
if(mp_fm_font_slant(mp,f)!=0){
mp_ps_print(mp,"-Slant_");mp_ps_print_int(mp,mp_fm_font_slant(mp,f));
}
if(mp_fm_font_extend(mp,f)!=0){
mp_ps_print(mp,"-Extend_");mp_ps_print_int(mp,mp_fm_font_extend(mp,f));
}
}

/*:134*//*140:*/
#line 4591 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_mark_string_chars(MP mp,font_number f,char*s,size_t l){
integer b;
int bc,ec;
unsigned char*k;
b= mp->char_base[f];
bc= (int)mp->font_bc[f];
ec= (int)mp->font_ec[f];
k= (unsigned char*)s;
while(l--> 0){
if((*k>=bc)&&(*k<=ec))
mp->font_info[b+*k].qqqq.b3= mp_used;
k++;
}
}


/*:140*//*142:*/
#line 4611 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_unmark_font(MP mp,font_number f){
int k;
for(k= mp->char_base[f]+mp->font_bc[f];
k<=mp->char_base[f]+mp->font_ec[f];
k++)
mp->font_info[k].qqqq.b3= mp_unused;
}


/*:142*//*144:*/
#line 4624 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_print_improved_prologue(MP mp,mp_edge_object*h,int prologues,int procset){
quarterword next_size;
mp_node*cur_fsize;
boolean done_fonts;
font_number f;
cur_fsize= mp_xmalloc(mp,(size_t)(mp->font_max+1),sizeof(mp_node));
mp_list_used_resources(mp,prologues,procset);
mp_list_supplied_resources(mp,prologues,procset);
mp_list_needed_resources(mp,prologues);
mp_ps_print_nl(mp,"%%EndComments");
mp_ps_print_nl(mp,"%%BeginProlog");
if(procset> 0)
mp_ps_print_nl(mp,"%%BeginResource: procset mpost");
else
mp_ps_print_nl(mp,"%%BeginResource: procset mpost-minimal");
mp_ps_print_nl(mp,"/bd{bind def}bind def"
"/fshow {exch findfont exch scalefont setfont show}bd");
if(procset> 0)/*158:*/
#line 4859 "../../../source/texk/web2c/mplibdir/psout.w"

{
mp_ps_print_nl(mp,"/hlw{0 dtransform exch truncate exch idtransform pop setlinewidth}bd");
mp_ps_print_nl(mp,"/vlw{0 exch dtransform truncate idtransform setlinewidth pop}bd");
mp_ps_print_nl(mp,"/l{lineto}bd/r{rlineto}bd/c{curveto}bd/m{moveto}bd"
"/p{closepath}bd/n{newpath}bd");
mp_ps_print_nl(mp,"/C{setcmykcolor}bd/G{setgray}bd/R{setrgbcolor}bd"
"/lj{setlinejoin}bd/ml{setmiterlimit}bd");
mp_ps_print_nl(mp,"/lc{setlinecap}bd/S{stroke}bd/F{fill}bd/q{gsave}bd"
"/Q{grestore}bd/s{scale}bd/t{concat}bd");
mp_ps_print_nl(mp,"/sd{setdash}bd/rd{[] 0 setdash}bd/P{showpage}bd/B{q F Q}bd/W{clip}bd");
}


/*:158*/
#line 4642 "../../../source/texk/web2c/mplibdir/psout.w"
;
mp_ps_print_nl(mp,"/fcp{findfont dup length dict begin"
"{1 index/FID ne{def}{pop pop}ifelse}forall}bd");
mp_ps_print_nl(mp,"/fmc{FontMatrix dup length array copy dup dup}bd"
"/fmd{/FontMatrix exch def}bd");
mp_ps_print_nl(mp,"/Amul{4 -1 roll exch mul 1000 div}bd"
"/ExtendFont{fmc 0 get Amul 0 exch put fmd}bd");
mp_ps_print_nl(mp,"/ScaleFont{dup fmc 0 get"
" Amul 0 exch put dup dup 3 get Amul 3 exch put fmd}bd");
mp_ps_print_nl(mp,"/SlantFont{fmc 2 get dup 0 eq{pop 1}if"
" Amul FontMatrix 0 get mul 2 exch put fmd}bd");
mp_ps_print_nl(mp,"%%EndResource");
/*135:*/
#line 4542 "../../../source/texk/web2c/mplibdir/psout.w"

mp_font_encodings(mp,mp->last_fnum,(prologues==2));
/*136:*/
#line 4546 "../../../source/texk/web2c/mplibdir/psout.w"

{
next_size= 0;
/*147:*/
#line 4720 "../../../source/texk/web2c/mplibdir/psout.w"

for(f= null_font+1;f<=mp->last_fnum;f++)
cur_fsize[f]= mp->font_sizes[f]

/*:147*/
#line 4549 "../../../source/texk/web2c/mplibdir/psout.w"
;
do{
done_fonts= true;
for(f= null_font+1;f<=mp->last_fnum;f++){
if(cur_fsize[f]!=null){
if(prologues==3){
if(!mp_do_ps_font(mp,f)){
if(mp_has_fm_entry(mp,f,NULL)){
mp_error(mp,"Font embedding failed",NULL,true);
}
}
}
if(cur_fsize[f]==mp_void)
cur_fsize[f]= null;
else
cur_fsize[f]= mp_link(cur_fsize[f]);
if(cur_fsize[f]!=null){mp_unmark_font(mp,f);done_fonts= false;}
}
}
if(!done_fonts)
/*137:*/
#line 4574 "../../../source/texk/web2c/mplibdir/psout.w"

{
next_size++;
mp_apply_mark_string_chars(mp,h,next_size);
}

/*:137*/
#line 4570 "../../../source/texk/web2c/mplibdir/psout.w"
;
}while(!done_fonts);
}

/*:136*/
#line 4544 "../../../source/texk/web2c/mplibdir/psout.w"


/*:135*/
#line 4654 "../../../source/texk/web2c/mplibdir/psout.w"
;
mp_ps_print_nl(mp,"%%EndProlog");
mp_ps_print_nl(mp,"%%BeginSetup");
mp_ps_print_ln(mp);
for(f= null_font+1;f<=mp->last_fnum;f++){
if(mp_has_font_size(mp,f)){
if(mp_has_fm_entry(mp,f,NULL)){
mp_write_font_definition(mp,f,prologues);
mp_ps_name_out(mp,mp->font_name[f],true);
mp_ps_print_defined_name(mp,f,prologues);
mp_ps_print(mp," def");
}else{
char s[256];
mp_snprintf(s,256,"font %s cannot be found in any fontmapfile!",mp->font_name[f]);
mp_warn(mp,s);
mp_ps_name_out(mp,mp->font_name[f],true);
mp_ps_name_out(mp,mp->font_name[f],true);
mp_ps_print(mp," def");
}
mp_ps_print_ln(mp);
}
}
mp_ps_print_nl(mp,"%%EndSetup");
mp_ps_print_nl(mp,"%%Page: 1 1");
mp_ps_print_ln(mp);
mp_xfree(cur_fsize);
}

/*:144*//*146:*/
#line 4687 "../../../source/texk/web2c/mplibdir/psout.w"

static font_number mp_print_font_comments(MP mp,mp_edge_object*h,int prologues){
quarterword next_size;
mp_node*cur_fsize;
int ff;
boolean done_fonts;
font_number f;
int ds;
int ldf= 0;
cur_fsize= mp_xmalloc(mp,(size_t)(mp->font_max+1),sizeof(mp_node));
if(prologues> 0){
/*148:*/
#line 4728 "../../../source/texk/web2c/mplibdir/psout.w"

{
ldf= null_font;
for(f= null_font+1;f<=mp->last_fnum;f++){
if(mp->font_sizes[f]!=null){
if(ldf==null_font)
mp_ps_print_nl(mp,"%%DocumentFonts:");
for(ff= ldf;ff>=null_font;ff--){
if(mp->font_sizes[ff]!=null)
if(mp_xstrcmp(mp->font_ps_name[f],mp->font_ps_name[ff])==0)
goto FOUND;
}
if((size_t)mp->ps->ps_offset+1+strlen(mp->font_ps_name[f])> (size_t)mp->max_print_line)
mp_ps_print_nl(mp,"%%+");
mp_ps_print_char(mp,' ');
mp_ps_print(mp,mp->font_ps_name[f]);
ldf= (int)f;
FOUND:
;
}
}
}

/*:148*/
#line 4699 "../../../source/texk/web2c/mplibdir/psout.w"
;
}else{
next_size= 0;
/*147:*/
#line 4720 "../../../source/texk/web2c/mplibdir/psout.w"

for(f= null_font+1;f<=mp->last_fnum;f++)
cur_fsize[f]= mp->font_sizes[f]

/*:147*/
#line 4702 "../../../source/texk/web2c/mplibdir/psout.w"
;
do{done_fonts= true;
for(f= null_font+1;f<=mp->last_fnum;f++){
if(cur_fsize[f]!=null){
/*157:*/
#line 4842 "../../../source/texk/web2c/mplibdir/psout.w"

{
if(mp_check_ps_marks(mp,f)){
double dds;
mp_ps_print_nl(mp,"%*Font: ");
mp_ps_print(mp,mp->font_name[f]);
mp_ps_print_char(mp,' ');
ds= (mp->font_dsize[f]+8)/16.0;
dds= (double)ds/65536.0;
mp_ps_print_double(mp,mp_take_double(mp,dds,sc_factor(cur_fsize[f])));
mp_ps_print_char(mp,' ');
mp_ps_print_double(mp,dds);
mp_ps_marks_out(mp,f);
}
cur_fsize[f]= mp_link(cur_fsize[f]);
}

/*:157*/
#line 4706 "../../../source/texk/web2c/mplibdir/psout.w"
;
}
if(cur_fsize[f]!=null){mp_unmark_font(mp,f);done_fonts= false;};
}
if(!done_fonts){
/*137:*/
#line 4574 "../../../source/texk/web2c/mplibdir/psout.w"

{
next_size++;
mp_apply_mark_string_chars(mp,h,next_size);
}

/*:137*/
#line 4712 "../../../source/texk/web2c/mplibdir/psout.w"
;
}
}while(!done_fonts);
}
mp_xfree(cur_fsize);
return(font_number)ldf;
}

/*:146*//*149:*/
#line 4751 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_hex_digit_out(MP mp,quarterword d){
if(d<10)mp_ps_print_char(mp,d+'0');
else mp_ps_print_char(mp,d+'a'-10);
}

/*:149*//*151:*/
#line 4765 "../../../source/texk/web2c/mplibdir/psout.w"

static halfword mp_ps_marks_out(MP mp,font_number f){
eight_bits bc,ec;
int p;
int d;
unsigned b;
bc= mp->font_bc[f];
ec= mp->font_ec[f];
/*152:*/
#line 4786 "../../../source/texk/web2c/mplibdir/psout.w"

p= mp->char_base[f]+bc;
while((mp->font_info[p].qqqq.b3==mp_unused)&&(bc<ec)){
p++;bc++;
}
p= mp->char_base[f]+ec;
while((mp->font_info[p].qqqq.b3==mp_unused)&&(bc<ec)){
p--;ec--;
}

/*:152*/
#line 4774 "../../../source/texk/web2c/mplibdir/psout.w"
;
/*153:*/
#line 4796 "../../../source/texk/web2c/mplibdir/psout.w"

mp_ps_print_char(mp,' ');
mp_hex_digit_out(mp,(quarterword)(bc/16));
mp_hex_digit_out(mp,(quarterword)(bc%16));
mp_ps_print_char(mp,':')

/*:153*/
#line 4775 "../../../source/texk/web2c/mplibdir/psout.w"
;
/*154:*/
#line 4804 "../../../source/texk/web2c/mplibdir/psout.w"

b= 8;d= 0;
for(p= mp->char_base[f]+bc;p<=mp->char_base[f]+ec;p++){
if(b==0){
mp_hex_digit_out(mp,(quarterword)d);
d= 0;b= 8;
}
if(mp->font_info[p].qqqq.b3!=mp_unused)
d+= (int)b;
b= b>>1;
}
mp_hex_digit_out(mp,(quarterword)d)


/*:154*/
#line 4776 "../../../source/texk/web2c/mplibdir/psout.w"
;
while((ec<mp->font_ec[f])&&(mp->font_info[p].qqqq.b3==mp_unused)){
p++;ec++;
}
return(ec+1);
}

/*:151*//*156:*/
#line 4824 "../../../source/texk/web2c/mplibdir/psout.w"

static boolean mp_check_ps_marks(MP mp,font_number f){
int p;
for(p= mp->char_base[f];p<=mp->char_base[f]+mp->font_ec[f];p++){
if(mp->font_info[p].qqqq.b3==mp_used)
return true;
}
return false;
}


/*:156*//*160:*/
#line 4883 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_print_prologue(MP mp,mp_edge_object*h,int prologues,int procset){
font_number f;
font_number ldf;
ldf= mp_print_font_comments(mp,h,prologues);
mp_ps_print_ln(mp);
if((prologues==1)&&(mp->last_ps_fnum==0))
mp_read_psname_table(mp);
mp_ps_print(mp,"%%BeginProlog");mp_ps_print_ln(mp);
if((prologues> 0)||(procset> 0)){
if(ldf!=null_font){
if(prologues> 0){
for(f= null_font+1;f<=mp->last_fnum;f++){
if(mp_has_font_size(mp,f)){
mp_ps_name_out(mp,mp->font_name[f],true);
mp_ps_name_out(mp,mp->font_ps_name[f],true);
mp_ps_print(mp," def");
mp_ps_print_ln(mp);
}
}
if(procset==0){
mp_ps_print(mp,"/fshow {exch findfont exch scalefont setfont show}bind def");
mp_ps_print_ln(mp);
}
}
}
if(procset> 0){
mp_ps_print_nl(mp,"%%BeginResource: procset mpost");
if((prologues> 0)&&(ldf!=null_font))
mp_ps_print_nl(mp,
"/bd{bind def}bind def/fshow {exch findfont exch scalefont setfont show}bd");
else
mp_ps_print_nl(mp,"/bd{bind def}bind def");
/*158:*/
#line 4859 "../../../source/texk/web2c/mplibdir/psout.w"

{
mp_ps_print_nl(mp,"/hlw{0 dtransform exch truncate exch idtransform pop setlinewidth}bd");
mp_ps_print_nl(mp,"/vlw{0 exch dtransform truncate idtransform setlinewidth pop}bd");
mp_ps_print_nl(mp,"/l{lineto}bd/r{rlineto}bd/c{curveto}bd/m{moveto}bd"
"/p{closepath}bd/n{newpath}bd");
mp_ps_print_nl(mp,"/C{setcmykcolor}bd/G{setgray}bd/R{setrgbcolor}bd"
"/lj{setlinejoin}bd/ml{setmiterlimit}bd");
mp_ps_print_nl(mp,"/lc{setlinecap}bd/S{stroke}bd/F{fill}bd/q{gsave}bd"
"/Q{grestore}bd/s{scale}bd/t{concat}bd");
mp_ps_print_nl(mp,"/sd{setdash}bd/rd{[] 0 setdash}bd/P{showpage}bd/B{q F Q}bd/W{clip}bd");
}


/*:158*/
#line 4916 "../../../source/texk/web2c/mplibdir/psout.w"
;
mp_ps_print_nl(mp,"%%EndResource");
mp_ps_print_ln(mp);
}
}
mp_ps_print(mp,"%%EndProlog");
mp_ps_print_nl(mp,"%%Page: 1 1");mp_ps_print_ln(mp);
}

/*:160*//*162:*/
#line 4939 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_ps_pair_out(MP mp,double x,double y){
ps_room(26);
mp_ps_print_double(mp,x);mp_ps_print_char(mp,' ');
mp_ps_print_double(mp,y);mp_ps_print_char(mp,' ');
}

/*:162*//*164:*/
#line 4949 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_ps_print_cmd(MP mp,const char*l,const char*s){
if(number_positive(internal_value(mp_procset))){ps_room(strlen(s));mp_ps_print(mp,s);}
else{ps_room(strlen(l));mp_ps_print(mp,l);};
}

/*:164*//*166:*/
#line 4958 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_ps_string_out(MP mp,const char*s,size_t l){
ASCII_code k;
mp_ps_print(mp,"(");
while(l--> 0){
k= (ASCII_code)*s++;
if(mp->ps->ps_offset+5> mp->max_print_line){
mp_ps_print_char(mp,'\\');
mp_ps_print_ln(mp);
}
if((/*161:*/
#line 4934 "../../../source/texk/web2c/mplibdir/psout.w"

(k<=' ')||(k> '~')

/*:161*/
#line 4968 "../../../source/texk/web2c/mplibdir/psout.w"
)){
mp_ps_print_char(mp,'\\');
mp_ps_print_char(mp,'0'+(k/64));
mp_ps_print_char(mp,'0'+((k/8)%8));
mp_ps_print_char(mp,'0'+(k%8));
}else{
if((k=='(')||(k==')')||(k=='\\'))
mp_ps_print_char(mp,'\\');
mp_ps_print_char(mp,k);
}
}
mp_ps_print_char(mp,')');
}

/*:166*//*168:*/
#line 4989 "../../../source/texk/web2c/mplibdir/psout.w"

static boolean mp_do_is_ps_name(char*s){
ASCII_code k;
while((k= (ASCII_code)*s++)){
if((k<=' ')||(k> '~'))return false;
if((k=='(')||(k==')')||(k=='<')||(k=='>')||
(k=='{')||(k=='}')||(k=='/')||(k=='%'))return false;
}
return true;
}

/*:168*//*170:*/
#line 5003 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_ps_name_out(MP mp,char*s,boolean lit){
ps_room(strlen(s)+2);
mp_ps_print_char(mp,' ');
if(mp_is_ps_name(mp,s)){
if(lit)mp_ps_print_char(mp,'/');
mp_ps_print(mp,s);
}else{
mp_ps_string_out(mp,s,strlen(s));
if(!lit)mp_ps_print(mp,"cvx ");
mp_ps_print(mp,"cvn");
}
}


/*:170*//*172:*/
#line 5033 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_print_initial_comment(MP mp,mp_edge_object*hh,int prologues){
int t;
char*s;
mp_ps_print(mp,"%!PS");
if(prologues> 0)
mp_ps_print(mp,"-Adobe-3.0 EPSF-3.0");
mp_ps_print_nl(mp,"%%BoundingBox: ");
if(hh->minx> hh->maxx){
mp_ps_print(mp,"0 0 0 0");
}else if(prologues<0){
mp_ps_pair_out(mp,hh->minx,hh->miny);
mp_ps_pair_out(mp,hh->maxx,hh->maxy);
}else{
mp_ps_pair_out(mp,floor(hh->minx),floor(hh->miny));
mp_ps_pair_out(mp,-floor(-hh->maxx),-floor(-hh->maxy));
}
mp_ps_print_nl(mp,"%%HiResBoundingBox: ");
if(hh->minx> hh->maxx){
mp_ps_print(mp,"0 0 0 0");
}else{
mp_ps_pair_out(mp,hh->minx,hh->miny);
mp_ps_pair_out(mp,hh->maxx,hh->maxy);
}
mp_ps_print_nl(mp,"%%Creator: MetaPost ");
s= mp_metapost_version();
mp_ps_print(mp,s);
mp_xfree(s);
mp_ps_print_nl(mp,"%%CreationDate: ");
mp_ps_print_int(mp,round_unscaled(internal_value(mp_year)));
mp_ps_print_char(mp,'.');
mp_ps_print_dd(mp,round_unscaled(internal_value(mp_month)));
mp_ps_print_char(mp,'.');
mp_ps_print_dd(mp,round_unscaled(internal_value(mp_day)));
mp_ps_print_char(mp,':');
t= round_unscaled(internal_value(mp_time));
mp_ps_print_dd(mp,t/60);
mp_ps_print_dd(mp,t%60);
mp_ps_print_nl(mp,"%%Pages: 1");
}

/*:172*//*175:*/
#line 5099 "../../../source/texk/web2c/mplibdir/psout.w"

static mp_gr_knot mp_gr_copy_knot(MP mp,mp_gr_knot p){
mp_gr_knot q;
q= mp_xmalloc(mp,1,sizeof(struct mp_gr_knot_data));
memcpy(q,p,sizeof(struct mp_gr_knot_data));
gr_next_knot(q)= NULL;
return q;
}

/*:175*//*176:*/
#line 5110 "../../../source/texk/web2c/mplibdir/psout.w"

static mp_gr_knot mp_gr_copy_path(MP mp,mp_gr_knot p){
mp_gr_knot q,pp,qq;
if(p==NULL)
return NULL;
q= mp_gr_copy_knot(mp,p);
qq= q;
pp= gr_next_knot(p);
while(pp!=p){
gr_next_knot(qq)= mp_gr_copy_knot(mp,pp);
qq= gr_next_knot(qq);
pp= gr_next_knot(pp);
}
gr_next_knot(qq)= q;
return q;
}

/*:176*//*178:*/
#line 5136 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_do_gr_toss_knot_list(mp_gr_knot p){
mp_gr_knot q;
mp_gr_knot r;
if(p==NULL)
return;
q= p;
do{
r= gr_next_knot(q);
mp_xfree(q);q= r;
}while(q!=p);
}



/*:178*//*179:*/
#line 5151 "../../../source/texk/web2c/mplibdir/psout.w"

static void mp_gr_ps_path_out(MP mp,mp_gr_knot h){
mp_gr_knot p,q;
double d;
boolean curved;
ps_room(40);
mp_ps_print_cmd(mp,"newpath ","n ");
mp_ps_pair_out(mp,gr_x_coord(h),gr_y_coord(h));
mp_ps_print_cmd(mp,"moveto","m");
p= h;
do{
if(gr_right_type(p)==mp_endpoint){
if(p==h)mp_ps_print_cmd(mp," 0 0 rlineto"," 0 0 r");
return;
}
q= gr_next_knot(p);
/*180:*/
#line 5174 "../../../source/texk/web2c/mplibdir/psout.w"

curved= true;
/*181:*/
#line 5195 "../../../source/texk/web2c/mplibdir/psout.w"

if(gr_right_x(p)==gr_x_coord(p))
if(gr_right_y(p)==gr_y_coord(p))
if(gr_left_x(q)==gr_x_coord(q))
if(gr_left_y(q)==gr_y_coord(q))curved= false;
d= gr_left_x(q)-gr_right_x(p);
if(fabs(gr_right_x(p)-gr_x_coord(p)-d)<=bend_tolerance)
if(fabs(gr_x_coord(q)-gr_left_x(q)-d)<=bend_tolerance)
{d= gr_left_y(q)-gr_right_y(p);
if(fabs(gr_right_y(p)-gr_y_coord(p)-d)<=bend_tolerance)
if(fabs(gr_y_coord(q)-gr_left_y(q)-d)<=bend_tolerance)curved= false;
}

/*:181*/
#line 5176 "../../../source/texk/web2c/mplibdir/psout.w"
;
mp_ps_print_ln(mp);
if(curved){
mp_ps_pair_out(mp,gr_right_x(p),gr_right_y(p));
mp_ps_pair_out(mp,gr_left_x(q),gr_left_y(q));
mp_ps_pair_out(mp,gr_x_coord(q),gr_y_coord(q));
mp_ps_print_cmd(mp,"curveto","c");
}else if(q!=h){
mp_ps_pair_out(mp,gr_x_coord(q),gr_y_coord(q));
mp_ps_print_cmd(mp,"lineto","l");
}

/*:180*/
#line 5168 "../../../source/texk/web2c/mplibdir/psout.w"
;
p= q;
}while(p!=h);
mp_ps_print_cmd(mp," closepath"," p");
}

/*:179*//*185:*/
#line 5233 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_do_gr_toss_dashes(mp_dash_object*dl){
if(dl==NULL)
return;
mp_xfree(dl->array);
mp_xfree(dl);
}


/*:185*//*186:*/
#line 5242 "../../../source/texk/web2c/mplibdir/psout.w"

static mp_dash_object*mp_gr_copy_dashes(MP mp,mp_dash_object*dl){
mp_dash_object*q= NULL;
(void)mp;
if(dl==NULL)
return NULL;
q= mp_xmalloc(mp,1,sizeof(mp_dash_object));
memcpy(q,dl,sizeof(mp_dash_object));
if(dl->array!=NULL){
size_t i= 0;
while(*(dl->array+i)!=-1)i++;
q->array= mp_xmalloc(mp,i,sizeof(double));
memcpy(q->array,dl->array,(i*sizeof(double)));
}
return q;
}


/*:186*//*190:*/
#line 5389 "../../../source/texk/web2c/mplibdir/psout.w"

mp_graphic_object*mp_new_graphic_object(MP mp,int type){
mp_graphic_object*p;
size_t size;
switch(type){
case mp_fill_code:size= sizeof(mp_fill_object);break;
case mp_stroked_code:size= sizeof(mp_stroked_object);break;
case mp_text_code:size= sizeof(mp_text_object);break;
case mp_start_clip_code:size= sizeof(mp_clip_object);break;
case mp_start_bounds_code:size= sizeof(mp_bounds_object);break;
case mp_special_code:size= sizeof(mp_special_object);break;
default:size= sizeof(mp_graphic_object);break;
}
p= (mp_graphic_object*)mp_xmalloc(mp,1,size);
memset(p,0,size);
gr_type(p)= type;
return p;
}

/*:190*//*195:*/
#line 5472 "../../../source/texk/web2c/mplibdir/psout.w"
static void mp_gs_unknown_graphics_state(MP mp,int c){
struct _gs_state*p;
if((c==0)||(c==-1)){
if(mp->ps->gs_state==NULL){
mp->ps->gs_state= mp_xmalloc(mp,1,sizeof(struct _gs_state));
gs_previous= NULL;
}else{
while(gs_previous!=NULL){
p= gs_previous;
mp_xfree(mp->ps->gs_state);
mp->ps->gs_state= p;
}
}
gs_red= c;gs_green= c;gs_blue= c;gs_black= c;
gs_colormodel= mp_uninitialized_model;
gs_ljoin= 3;
gs_lcap= 3;
gs_miterlim= 0.0;
gs_dash_p= NULL;
gs_dash_init_done= false;
gs_width= -1.0;
}else if(c==1){
p= mp->ps->gs_state;
mp->ps->gs_state= mp_xmalloc(mp,1,sizeof(struct _gs_state));
memcpy(mp->ps->gs_state,p,sizeof(struct _gs_state));
gs_previous= p;
}else if(c==2){
p= gs_previous;
mp_xfree(mp->ps->gs_state);
mp->ps->gs_state= p;
}
}


/*:195*//*197:*/
#line 5512 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_gr_fix_graphics_state(MP mp,mp_graphic_object*p){

mp_gr_knot pp,path_p;
mp_dash_object*hh;
double wx,wy,ww;
quarterword adj_wx;
double tx,ty;
if(gr_has_color(p))
/*200:*/
#line 5589 "../../../source/texk/web2c/mplibdir/psout.w"

{
int object_color_model;
double object_color_a,object_color_b,object_color_c,object_color_d;
if(gr_type(p)==mp_fill_code){
mp_fill_object*pq= (mp_fill_object*)p;
set_color_objects(pq);
}else if(gr_type(p)==mp_stroked_code){
mp_stroked_object*pq= (mp_stroked_object*)p;
set_color_objects(pq);
}else{
mp_text_object*pq= (mp_text_object*)p;
set_color_objects(pq);
}

if(object_color_model==mp_rgb_model){
if((gs_colormodel!=mp_rgb_model)||(gs_red!=object_color_a)||
(gs_green!=object_color_b)||(gs_blue!=object_color_c)){
gs_red= object_color_a;
gs_green= object_color_b;
gs_blue= object_color_c;
gs_black= -1.0;
gs_colormodel= mp_rgb_model;
{ps_room(36);
mp_ps_print_char(mp,' ');
mp_ps_print_double(mp,gs_red);mp_ps_print_char(mp,' ');
mp_ps_print_double(mp,gs_green);mp_ps_print_char(mp,' ');
mp_ps_print_double(mp,gs_blue);
mp_ps_print_cmd(mp," setrgbcolor"," R");
}
}
}else if(object_color_model==mp_cmyk_model){
if((gs_red!=object_color_a)||(gs_green!=object_color_b)||
(gs_blue!=object_color_c)||(gs_black!=object_color_d)||
(gs_colormodel!=mp_cmyk_model)){
gs_red= object_color_a;
gs_green= object_color_b;
gs_blue= object_color_c;
gs_black= object_color_d;
gs_colormodel= mp_cmyk_model;
{ps_room(45);
mp_ps_print_char(mp,' ');
mp_ps_print_double(mp,gs_red);
mp_ps_print_char(mp,' ');
mp_ps_print_double(mp,gs_green);
mp_ps_print_char(mp,' ');
mp_ps_print_double(mp,gs_blue);
mp_ps_print_char(mp,' ');
mp_ps_print_double(mp,gs_black);
mp_ps_print_cmd(mp," setcmykcolor"," C");
}
}
}else if(object_color_model==mp_grey_model){
if((gs_red!=object_color_a)||(gs_colormodel!=mp_grey_model)){
gs_red= object_color_a;
gs_green= -1.0;
gs_blue= -1.0;
gs_black= -1.0;
gs_colormodel= mp_grey_model;
{ps_room(16);
mp_ps_print_char(mp,' ');
mp_ps_print_double(mp,gs_red);
mp_ps_print_cmd(mp," setgray"," G");
}
}
}else if(object_color_model==mp_no_model){
gs_colormodel= mp_no_model;
}
}

/*:200*/
#line 5521 "../../../source/texk/web2c/mplibdir/psout.w"
;
if((gr_type(p)==mp_fill_code)||(gr_type(p)==mp_stroked_code)){
if(gr_type(p)==mp_fill_code){
pp= gr_pen_p((mp_fill_object*)p);
path_p= gr_path_p((mp_fill_object*)p);
}else{
pp= gr_pen_p((mp_stroked_object*)p);
path_p= gr_path_p((mp_stroked_object*)p);
}
if(pp!=NULL)
if(pen_is_elliptical(pp)){
/*201:*/
#line 5676 "../../../source/texk/web2c/mplibdir/psout.w"

/*202:*/
#line 5703 "../../../source/texk/web2c/mplibdir/psout.w"

if((gr_right_x(pp)==gr_x_coord(pp))&&(gr_left_y(pp)==gr_y_coord(pp))){
wx= fabs(gr_left_x(pp)-gr_x_coord(pp));
wy= fabs(gr_right_y(pp)-gr_y_coord(pp));
}else{
double a,b;
a= gr_left_x(pp)-gr_x_coord(pp);
b= gr_right_x(pp)-gr_x_coord(pp);
wx= sqrt(a*a+b*b);
a= gr_left_y(pp)-gr_y_coord(pp);
b= gr_right_y(pp)-gr_y_coord(pp);
wy= sqrt(a*a+b*b);
}

/*:202*/
#line 5678 "../../../source/texk/web2c/mplibdir/psout.w"
;
/*203:*/
#line 5728 "../../../source/texk/web2c/mplibdir/psout.w"

tx= 1.0/65536.0;ty= 1.0/65536.0;
if(mp_gr_coord_rangeOK(path_p,do_y_loc,wy))tx= aspect_bound;
else if(mp_gr_coord_rangeOK(path_p,do_x_loc,wx))ty= aspect_bound;
if(wy/ty>=wx/tx){ww= wy;adj_wx= 0;}
else{ww= wx;adj_wx= 1;}

/*:203*/
#line 5680 "../../../source/texk/web2c/mplibdir/psout.w"
;
if((ww!=gs_width)||(adj_wx!=gs_adj_wx)){
if(adj_wx!=0){
ps_room(13);
mp_ps_print_char(mp,' ');mp_ps_print_double(mp,ww);
mp_ps_print_cmd(mp,
" 0 dtransform exch truncate exch idtransform pop setlinewidth"," hlw");
}else{
if(number_positive(internal_value(mp_procset))){
ps_room(13);
mp_ps_print_char(mp,' ');
mp_ps_print_double(mp,ww);
mp_ps_print(mp," vlw");
}else{
ps_room(15);
mp_ps_print(mp," 0 ");mp_ps_print_double(mp,ww);
mp_ps_print(mp," dtransform truncate idtransform setlinewidth pop");
}
}
gs_width= ww;
gs_adj_wx= adj_wx;
}

/*:201*/
#line 5533 "../../../source/texk/web2c/mplibdir/psout.w"
;
/*207:*/
#line 5792 "../../../source/texk/web2c/mplibdir/psout.w"

if(gr_type(p)==mp_fill_code||gr_dash_p(p)==NULL){
hh= NULL;
}else{
hh= gr_dash_p(p);
}
if(hh==NULL){
if(gs_dash_p!=NULL||gs_dash_init_done==false){
mp_ps_print_cmd(mp," [] 0 setdash"," rd");
gs_dash_p= NULL;
gs_dash_init_done= true;
}
}else if(!mp_gr_same_dashes(gs_dash_p,hh)){
/*208:*/
#line 5811 "../../../source/texk/web2c/mplibdir/psout.w"

{gs_dash_p= hh;
if((gr_dash_p(p)==NULL)||(hh==NULL)||(hh->array==NULL)){
mp_ps_print_cmd(mp," [] 0 setdash"," rd");
}else{
int i;
ps_room(28);
mp_ps_print(mp," [");
for(i= 0;*(hh->array+i)!=-1;i++){
ps_room(13);
mp_ps_print_double(mp,*(hh->array+i));
mp_ps_print_char(mp,' ');
}
ps_room(22);
mp_ps_print(mp,"] ");
mp_ps_print_double(mp,hh->offset);
mp_ps_print_cmd(mp," setdash"," sd");
}
}

/*:208*/
#line 5805 "../../../source/texk/web2c/mplibdir/psout.w"
;
}

/*:207*/
#line 5534 "../../../source/texk/web2c/mplibdir/psout.w"
;
/*198:*/
#line 5542 "../../../source/texk/web2c/mplibdir/psout.w"

if(gr_type(p)==mp_stroked_code){
mp_stroked_object*ts= (mp_stroked_object*)p;
if((gr_left_type(gr_path_p(ts))==mp_endpoint)||(gr_dash_p(ts)!=NULL))
if(gs_lcap!=(quarterword)gr_lcap_val(ts)){
ps_room(13);
mp_ps_print_char(mp,' ');
mp_ps_print_char(mp,'0'+gr_lcap_val(ts));
mp_ps_print_cmd(mp," setlinecap"," lc");
gs_lcap= (quarterword)gr_lcap_val(ts);
}
}

/*:198*/
#line 5535 "../../../source/texk/web2c/mplibdir/psout.w"
;
/*199:*/
#line 5572 "../../../source/texk/web2c/mplibdir/psout.w"

if(gr_type(p)==mp_stroked_code){
mp_stroked_object*ts= (mp_stroked_object*)p;
set_ljoin_miterlim(ts);
}else{
mp_fill_object*ts= (mp_fill_object*)p;
set_ljoin_miterlim(ts);
}

/*:199*/
#line 5536 "../../../source/texk/web2c/mplibdir/psout.w"
;
}
}
if(mp->ps->ps_offset> 0)mp_ps_print_ln(mp);
}

/*:197*//*205:*/
#line 5744 "../../../source/texk/web2c/mplibdir/psout.w"

boolean mp_gr_coord_rangeOK(mp_gr_knot h,
quarterword zoff,double dz){
mp_gr_knot p;
double zlo,zhi;
double z;
if(zoff==do_x_loc){
zlo= gr_x_coord(h);
zhi= zlo;
p= h;
while(gr_right_type(p)!=mp_endpoint){
z= gr_right_x(p);
/*206:*/
#line 5780 "../../../source/texk/web2c/mplibdir/psout.w"

if(z<zlo)zlo= z;
else if(z> zhi)zhi= z;
if(zhi-zlo> dz)return false

/*:206*/
#line 5756 "../../../source/texk/web2c/mplibdir/psout.w"
;
p= gr_next_knot(p);z= gr_left_x(p);
/*206:*/
#line 5780 "../../../source/texk/web2c/mplibdir/psout.w"

if(z<zlo)zlo= z;
else if(z> zhi)zhi= z;
if(zhi-zlo> dz)return false

/*:206*/
#line 5758 "../../../source/texk/web2c/mplibdir/psout.w"
;
z= gr_x_coord(p);
/*206:*/
#line 5780 "../../../source/texk/web2c/mplibdir/psout.w"

if(z<zlo)zlo= z;
else if(z> zhi)zhi= z;
if(zhi-zlo> dz)return false

/*:206*/
#line 5760 "../../../source/texk/web2c/mplibdir/psout.w"
;
if(p==h)break;
}
}else{
zlo= gr_y_coord(h);
zhi= zlo;
p= h;
while(gr_right_type(p)!=mp_endpoint){
z= gr_right_y(p);
/*206:*/
#line 5780 "../../../source/texk/web2c/mplibdir/psout.w"

if(z<zlo)zlo= z;
else if(z> zhi)zhi= z;
if(zhi-zlo> dz)return false

/*:206*/
#line 5769 "../../../source/texk/web2c/mplibdir/psout.w"
;
p= gr_next_knot(p);z= gr_left_y(p);
/*206:*/
#line 5780 "../../../source/texk/web2c/mplibdir/psout.w"

if(z<zlo)zlo= z;
else if(z> zhi)zhi= z;
if(zhi-zlo> dz)return false

/*:206*/
#line 5771 "../../../source/texk/web2c/mplibdir/psout.w"
;
z= gr_y_coord(p);
/*206:*/
#line 5780 "../../../source/texk/web2c/mplibdir/psout.w"

if(z<zlo)zlo= z;
else if(z> zhi)zhi= z;
if(zhi-zlo> dz)return false

/*:206*/
#line 5773 "../../../source/texk/web2c/mplibdir/psout.w"
;
if(p==h)break;
}
}
return true;
}

/*:205*//*210:*/
#line 5836 "../../../source/texk/web2c/mplibdir/psout.w"

boolean mp_gr_same_dashes(mp_dash_object*h,mp_dash_object*hh){
boolean ret= false;
int i= 0;
if(h==hh)ret= true;
else if((h==NULL)||(hh==NULL))ret= false;
else if(h->offset!=hh->offset)ret= false;
else if(h->array==hh->array)ret= true;
else if(h->array==NULL||hh->array==NULL)ret= false;
else{/*211:*/
#line 5849 "../../../source/texk/web2c/mplibdir/psout.w"

{
while(*(h->array+i)!=-1&&
*(hh->array+i)!=-1&&
*(h->array+i)==*(hh->array+i))i++;
if(i> 0){
if(*(h->array+i)==-1&&*(hh->array+i)==-1)
ret= true;
}
}

/*:211*/
#line 5845 "../../../source/texk/web2c/mplibdir/psout.w"
;}
return ret;
}

/*:210*//*213:*/
#line 5873 "../../../source/texk/web2c/mplibdir/psout.w"
void mp_gr_stroke_ellipse(MP mp,mp_graphic_object*h,boolean fill_also){

double txx,txy,tyx,tyy;
mp_gr_knot p;
double d1,det;
double s;
boolean transformed;
transformed= false;
/*214:*/
#line 5912 "../../../source/texk/web2c/mplibdir/psout.w"

if(gr_type(h)==mp_fill_code){
p= gr_pen_p((mp_fill_object*)h);
}else{
p= gr_pen_p((mp_stroked_object*)h);
}
txx= gr_left_x(p);
tyx= gr_left_y(p);
txy= gr_right_x(p);
tyy= gr_right_y(p);
if((gr_x_coord(p)!=0.0)||(gr_y_coord(p)!=0.0)){
mp_ps_print_nl(mp,"");
mp_ps_print_cmd(mp,"gsave ","q ");
mp_ps_pair_out(mp,gr_x_coord(p),gr_y_coord(p));
mp_ps_print(mp,"translate ");
txx-= gr_x_coord(p);
tyx-= gr_y_coord(p);
txy-= gr_x_coord(p);
tyy-= gr_y_coord(p);
transformed= true;
}else{
mp_ps_print_nl(mp,"");
}
/*215:*/
#line 5943 "../../../source/texk/web2c/mplibdir/psout.w"

if(gs_width!=unity){
if(gs_width==0.0){
txx= unity;tyy= unity;
}else{
txx= mp_make_double(mp,txx,gs_width);
txy= mp_make_double(mp,txy,gs_width);
tyx= mp_make_double(mp,tyx,gs_width);
tyy= mp_make_double(mp,tyy,gs_width);
}
}
if((txy!=0.0)||(tyx!=0.0)||(txx!=unity)||(tyy!=unity)){
if((!transformed)){
mp_ps_print_cmd(mp,"gsave ","q ");
transformed= true;
}
}

/*:215*/
#line 5936 "../../../source/texk/web2c/mplibdir/psout.w"


/*:214*/
#line 5882 "../../../source/texk/web2c/mplibdir/psout.w"
;
/*217:*/
#line 5984 "../../../source/texk/web2c/mplibdir/psout.w"

det= mp_take_double(mp,txx,tyy)-mp_take_double(mp,txy,tyx);
d1= 4*(aspect_bound+1/65536.0);
if(fabs(det)<d1){
if(det>=0){d1= d1-det;s= 1;}
else{d1= -d1-det;s= -1;};
d1= d1*unity;
if(fabs(txx)+fabs(tyy)>=fabs(txy)+fabs(tyy)){
if(fabs(txx)> fabs(tyy))tyy= tyy+(d1+s*fabs(txx))/txx;
else txx= txx+(d1+s*fabs(tyy))/tyy;
}else{
if(fabs(txy)> fabs(tyx))tyx= tyx+(d1+s*fabs(txy))/txy;
else txy= txy+(d1+s*fabs(tyx))/tyx;
}
}

/*:217*/
#line 5883 "../../../source/texk/web2c/mplibdir/psout.w"
;
if(gr_type(h)==mp_fill_code){
mp_gr_ps_path_out(mp,gr_path_p((mp_fill_object*)h));
}else{
mp_gr_ps_path_out(mp,gr_path_p((mp_stroked_object*)h));
}
if(number_zero(internal_value(mp_procset))){
if(fill_also)mp_ps_print_nl(mp,"gsave fill grestore");
/*216:*/
#line 5961 "../../../source/texk/web2c/mplibdir/psout.w"

if((txy!=0.0)||(tyx!=0.0)){
mp_ps_print_ln(mp);
mp_ps_print_char(mp,'[');
mp_ps_pair_out(mp,txx,tyx);
mp_ps_pair_out(mp,txy,tyy);
mp_ps_print(mp,"0 0] concat");
}else if((txx!=unity)||(tyy!=unity)){
mp_ps_print_ln(mp);
mp_ps_pair_out(mp,txx,tyy);
mp_ps_print(mp,"scale");
}

/*:216*/
#line 5891 "../../../source/texk/web2c/mplibdir/psout.w"
;
mp_ps_print(mp," stroke");
if(transformed)mp_ps_print(mp," grestore");
}else{
if(fill_also)mp_ps_print_nl(mp,"B");else mp_ps_print_ln(mp);
if((txy!=0.0)||(tyx!=0.0)){
mp_ps_print(mp," [");
mp_ps_pair_out(mp,txx,tyx);
mp_ps_pair_out(mp,txy,tyy);
mp_ps_print(mp,"0 0] t");
}else if((txx!=unity)||(tyy!=unity)){
mp_ps_print(mp," ");
mp_ps_pair_out(mp,txx,tyy);
mp_ps_print(mp," s");
};
mp_ps_print(mp," S");
if(transformed)mp_ps_print(mp," Q");
}
mp_ps_print_ln(mp);
}

/*:213*//*219:*/
#line 6005 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_gr_ps_fill_out(MP mp,mp_gr_knot p){
mp_gr_ps_path_out(mp,p);
mp_ps_print_cmd(mp," fill"," F");
mp_ps_print_ln(mp);
}

/*:219*//*221:*/
#line 6025 "../../../source/texk/web2c/mplibdir/psout.w"
double mp_gr_choose_scale(MP mp,mp_graphic_object*p){

double a,b,c,d,ad,bc;
double r;
a= gr_txx_val(p);
b= gr_txy_val(p);
c= gr_tyx_val(p);
d= gr_tyy_val(p);
if(a<0)negate(a);
if(b<0)negate(b);
if(c<0)negate(c);
if(d<0)negate(d);
ad= (a-d)/2.0;
bc= (b-c)/2.0;
a= (d+ad);
b= ad;
d= sqrt(a*a+b*b);
a= (c+bc);
b= bc;
c= sqrt(a*a+b*b);
r= sqrt(c*c+d*d);
return r;
}

/*:221*//*223:*/
#line 6057 "../../../source/texk/web2c/mplibdir/psout.w"

quarterword mp_size_index(MP mp,font_number f,double s){
mp_node p,q;
int i;
p= NULL;
q= mp->font_sizes[f];
i= 0;
while(q!=null){
if(fabs(s-sc_factor(q))<=fscale_tolerance)
return(quarterword)i;
else
{p= q;q= mp_link(q);incr(i);};
if(i==max_quarterword)
mp_overflow(mp,"sizes per font",max_quarterword);

}
q= (mp_node)mp_xmalloc(mp,1,font_size_size);
mp_link(q)= NULL;
sc_factor(q)= s;
if(i==0)mp->font_sizes[f]= q;else mp_link(p)= q;
return(quarterword)i;
}

/*:223*//*225:*/
#line 6083 "../../../source/texk/web2c/mplibdir/psout.w"

double mp_indexed_size(MP mp,font_number f,quarterword j){
mp_node p;
int i;
p= mp->font_sizes[f];
i= 0;
if(p==null)mp_confusion(mp,"size");
while((i!=j)){
incr(i);
assert(p);
p= mp_link(p);
if(p==null)mp_confusion(mp,"size");
}
assert(p);
return sc_factor(p);
}

/*:225*//*227:*/
#line 6103 "../../../source/texk/web2c/mplibdir/psout.w"
void mp_clear_sizes(MP mp){
font_number f;
mp_node p;
for(f= null_font+1;f<=mp->last_fnum;f++){
while(mp->font_sizes[f]!=null){
p= mp->font_sizes[f];
mp->font_sizes[f]= mp_link(p);
mp_xfree(p);
}
}
}

/*:227*//*230:*/
#line 6133 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_apply_mark_string_chars(MP mp,mp_edge_object*h,int next_size){
mp_graphic_object*p;
p= h->body;
while(p!=NULL){
if(gr_type(p)==mp_text_code){
if(gr_font_n(p)!=null_font){
if(gr_size_index(p)==(unsigned char)next_size)
mp_mark_string_chars(mp,gr_font_n(p),gr_text_p(p),gr_text_l(p));
}
}
p= gr_link(p);
}
}

/*:230*//*234:*/
#line 6194 "../../../source/texk/web2c/mplibdir/psout.w"

int mp_gr_ship_out(mp_edge_object*hh,int qprologues,int qprocset,int standalone){
mp_graphic_object*p;
double ds,scf;
font_number f;
boolean transformed;
int prologues,procset;
MP mp= hh->parent;
if(standalone){
mp->jump_buf= malloc(sizeof(jmp_buf));
if(mp->jump_buf==NULL||setjmp(*(mp->jump_buf)))
return 0;
}
if(mp->history>=mp_fatal_error_stop)return 1;
if(qprologues<0)
prologues= (int)((unsigned)number_to_scaled(internal_value(mp_prologues))>>16);
else
prologues= qprologues;
if(qprocset<0)
procset= (int)((unsigned)number_to_scaled(internal_value(mp_procset))>>16);
else
procset= qprocset;
mp_open_output_file(mp);
mp_print_initial_comment(mp,hh,prologues);

/*231:*/
#line 6148 "../../../source/texk/web2c/mplibdir/psout.w"

for(f= null_font+1;f<=mp->last_fnum;f++){
if(mp->font_sizes[f]!=null){
mp_unmark_font(mp,f);
mp->font_sizes[f]= null;
}
}

/*:231*/
#line 6219 "../../../source/texk/web2c/mplibdir/psout.w"
;
if(prologues==2||prologues==3){
mp_reload_encodings(mp);
}
/*232:*/
#line 6156 "../../../source/texk/web2c/mplibdir/psout.w"

p= hh->body;
while(p!=null){
if(gr_type(p)==mp_text_code){
f= gr_font_n(p);
if(f!=null_font){
switch(prologues){
case 2:
case 3:
mp->font_sizes[f]= mp_void;
mp_mark_string_chars(mp,f,gr_text_p(p),gr_text_l(p));
if(mp_has_fm_entry(mp,f,NULL)){
if(mp->font_enc_name[f]==NULL)
mp->font_enc_name[f]= mp_fm_encoding_name(mp,f);
mp_xfree(mp->font_ps_name[f]);
mp->font_ps_name[f]= mp_fm_font_name(mp,f);
}
break;
case 1:
mp->font_sizes[f]= mp_void;
break;
default:
gr_size_index(p)= (unsigned char)mp_size_index(mp,f,mp_gr_choose_scale(mp,p));
if(gr_size_index(p)==0)
mp_mark_string_chars(mp,f,gr_text_p(p),gr_text_l(p));
}
}
}
p= gr_link(p);
}


/*:232*/
#line 6223 "../../../source/texk/web2c/mplibdir/psout.w"
;
if(prologues==2||prologues==3){
mp_print_improved_prologue(mp,hh,prologues,procset);
}else{
mp_print_prologue(mp,hh,prologues,procset);
}
mp_gs_unknown_graphics_state(mp,0);
p= hh->body;
while(p!=NULL){
if(gr_has_color(p)){
/*237:*/
#line 6337 "../../../source/texk/web2c/mplibdir/psout.w"

{
if(gr_type(p)==mp_fill_code){do_write_prescript(p,mp_fill_object);}
else if(gr_type(p)==mp_stroked_code){do_write_prescript(p,mp_stroked_object);}
else if(gr_type(p)==mp_text_code){do_write_prescript(p,mp_text_object);}
}

/*:237*/
#line 6233 "../../../source/texk/web2c/mplibdir/psout.w"
;
}
mp_gr_fix_graphics_state(mp,p);
switch(gr_type(p)){
case mp_fill_code:
if(gr_pen_p((mp_fill_object*)p)==NULL){
mp_gr_ps_fill_out(mp,gr_path_p((mp_fill_object*)p));
}else if(pen_is_elliptical(gr_pen_p((mp_fill_object*)p))){
mp_gr_stroke_ellipse(mp,p,true);
}else{
mp_gr_ps_fill_out(mp,gr_path_p((mp_fill_object*)p));
mp_gr_ps_fill_out(mp,gr_htap_p(p));
}
if(gr_post_script((mp_fill_object*)p)!=NULL){
mp_ps_print_nl(mp,gr_post_script((mp_fill_object*)p));
mp_ps_print_ln(mp);
}
break;
case mp_stroked_code:
if(pen_is_elliptical(gr_pen_p((mp_stroked_object*)p)))
mp_gr_stroke_ellipse(mp,p,false);
else{
mp_gr_ps_fill_out(mp,gr_path_p((mp_stroked_object*)p));
}
if(gr_post_script((mp_stroked_object*)p)!=NULL){
mp_ps_print_nl(mp,gr_post_script((mp_stroked_object*)p));
mp_ps_print_ln(mp);
}
break;
case mp_text_code:
if((gr_font_n(p)!=null_font)&&(gr_text_l(p)> 0)){
if(prologues> 0)
scf= mp_gr_choose_scale(mp,p);
else
scf= mp_indexed_size(mp,gr_font_n(p),(quarterword)gr_size_index(p));
/*239:*/
#line 6355 "../../../source/texk/web2c/mplibdir/psout.w"

transformed= (gr_txx_val(p)!=scf)||(gr_tyy_val(p)!=scf)||
(gr_txy_val(p)!=0)||(gr_tyx_val(p)!=0);
if(transformed){
mp_ps_print_cmd(mp,"gsave [","q [");
mp_ps_pair_out(mp,mp_make_double(mp,gr_txx_val(p),scf),
mp_make_double(mp,gr_tyx_val(p),scf));
mp_ps_pair_out(mp,mp_make_double(mp,gr_txy_val(p),scf),
mp_make_double(mp,gr_tyy_val(p),scf));
mp_ps_pair_out(mp,gr_tx_val(p),gr_ty_val(p));
mp_ps_print_cmd(mp,"] concat 0 0 moveto","] t 0 0 m");
}else{
mp_ps_pair_out(mp,gr_tx_val(p),gr_ty_val(p));
mp_ps_print_cmd(mp,"moveto","m");
}
mp_ps_print_ln(mp)

/*:239*/
#line 6270 "../../../source/texk/web2c/mplibdir/psout.w"
;
mp_ps_string_out(mp,gr_text_p(p),gr_text_l(p));
mp_ps_name_out(mp,mp->font_name[gr_font_n(p)],false);
/*238:*/
#line 6344 "../../../source/texk/web2c/mplibdir/psout.w"

ps_room(18);
mp_ps_print_char(mp,' ');
ds= (mp->font_dsize[gr_font_n(p)]+8)/16;
mp_ps_print_double(mp,(mp_take_double(mp,ds,scf)/65536.0));
mp_ps_print(mp," fshow");
if(transformed)
mp_ps_print_cmd(mp," grestore"," Q")



/*:238*/
#line 6273 "../../../source/texk/web2c/mplibdir/psout.w"
;
mp_ps_print_ln(mp);
}
if(gr_post_script((mp_text_object*)p)!=NULL){
mp_ps_print_nl(mp,gr_post_script((mp_text_object*)p));mp_ps_print_ln(mp);
}
break;
case mp_start_clip_code:
mp_ps_print_nl(mp,"");mp_ps_print_cmd(mp,"gsave ","q ");
mp_gr_ps_path_out(mp,gr_path_p((mp_clip_object*)p));
mp_ps_print_cmd(mp," clip"," W");
mp_ps_print_ln(mp);
if(number_positive(internal_value(mp_restore_clip_color)))
mp_gs_unknown_graphics_state(mp,1);
break;
case mp_stop_clip_code:
mp_ps_print_nl(mp,"");mp_ps_print_cmd(mp,"grestore","Q");
mp_ps_print_ln(mp);
if(number_positive(internal_value(mp_restore_clip_color)))
mp_gs_unknown_graphics_state(mp,2);
else
mp_gs_unknown_graphics_state(mp,-1);
break;
case mp_start_bounds_code:
case mp_stop_bounds_code:
break;
case mp_special_code:
{
mp_special_object*ps= (mp_special_object*)p;
mp_ps_print_nl(mp,gr_pre_script(ps));
mp_ps_print_ln(mp);
}
break;
}
p= gr_link(p);
}
mp_ps_print_cmd(mp,"showpage","P");mp_ps_print_ln(mp);
mp_ps_print(mp,"%%EOF");mp_ps_print_ln(mp);
(mp->close_file)(mp,mp->output_file);
if(prologues<=0)
mp_clear_sizes(mp);
return 1;
}

/*:234*//*236:*/
#line 6320 "../../../source/texk/web2c/mplibdir/psout.w"

int mp_ps_ship_out(mp_edge_object*hh,int prologues,int procset){
return mp_gr_ship_out(hh,prologues,procset,(int)true);
}





/*:236*//*241:*/
#line 6376 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_gr_toss_object(mp_graphic_object*p){
mp_fill_object*tf;
mp_stroked_object*ts;
mp_text_object*tt;
switch(gr_type(p)){
case mp_fill_code:
tf= (mp_fill_object*)p;
mp_xfree(gr_pre_script(tf));
mp_xfree(gr_post_script(tf));
mp_gr_toss_knot_list(mp,gr_pen_p(tf));
mp_gr_toss_knot_list(mp,gr_path_p(tf));
mp_gr_toss_knot_list(mp,gr_htap_p(p));
break;
case mp_stroked_code:
ts= (mp_stroked_object*)p;
mp_xfree(gr_pre_script(ts));
mp_xfree(gr_post_script(ts));
mp_gr_toss_knot_list(mp,gr_pen_p(ts));
mp_gr_toss_knot_list(mp,gr_path_p(ts));
if(gr_dash_p(p)!=NULL)
mp_gr_toss_dashes(mp,gr_dash_p(p));
break;
case mp_text_code:
tt= (mp_text_object*)p;
mp_xfree(gr_pre_script(tt));
mp_xfree(gr_post_script(tt));
mp_xfree(gr_text_p(p));
mp_xfree(gr_font_name(p));
break;
case mp_start_clip_code:
mp_gr_toss_knot_list(mp,gr_path_p((mp_clip_object*)p));
break;
case mp_start_bounds_code:
mp_gr_toss_knot_list(mp,gr_path_p((mp_bounds_object*)p));
break;
case mp_stop_clip_code:
case mp_stop_bounds_code:
break;
case mp_special_code:
mp_xfree(gr_pre_script((mp_special_object*)p));
break;
}
mp_xfree(p);
}


/*:241*//*242:*/
#line 6423 "../../../source/texk/web2c/mplibdir/psout.w"

void mp_gr_toss_objects(mp_edge_object*hh){
mp_graphic_object*p,*q;
p= hh->body;
while(p!=NULL){
q= gr_link(p);
mp_gr_toss_object(p);
p= q;
}
mp_xfree(hh->filename);
mp_xfree(hh);
}

/*:242*//*244:*/
#line 6439 "../../../source/texk/web2c/mplibdir/psout.w"

mp_graphic_object*
mp_gr_copy_object(MP mp,mp_graphic_object*p){
mp_fill_object*tf;
mp_stroked_object*ts;
mp_text_object*tt;
mp_clip_object*tc;
mp_bounds_object*tb;
mp_special_object*tp;
mp_graphic_object*q= NULL;
switch(gr_type(p)){
case mp_fill_code:
tf= (mp_fill_object*)mp_new_graphic_object(mp,mp_fill_code);
gr_pre_script(tf)= mp_xstrdup(mp,gr_pre_script((mp_fill_object*)p));
gr_post_script(tf)= mp_xstrdup(mp,gr_post_script((mp_fill_object*)p));
gr_path_p(tf)= mp_gr_copy_path(mp,gr_path_p((mp_fill_object*)p));
gr_htap_p(tf)= mp_gr_copy_path(mp,gr_htap_p(p));
gr_pen_p(tf)= mp_gr_copy_path(mp,gr_pen_p((mp_fill_object*)p));
q= (mp_graphic_object*)tf;
break;
case mp_stroked_code:
ts= (mp_stroked_object*)mp_new_graphic_object(mp,mp_stroked_code);
gr_pre_script(ts)= mp_xstrdup(mp,gr_pre_script((mp_stroked_object*)p));
gr_post_script(ts)= mp_xstrdup(mp,gr_post_script((mp_stroked_object*)p));
gr_path_p(ts)= mp_gr_copy_path(mp,gr_path_p((mp_stroked_object*)p));
gr_pen_p(ts)= mp_gr_copy_path(mp,gr_pen_p((mp_stroked_object*)p));
gr_dash_p(ts)= mp_gr_copy_dashes(mp,gr_dash_p(p));
q= (mp_graphic_object*)ts;
break;
case mp_text_code:
tt= (mp_text_object*)mp_new_graphic_object(mp,mp_text_code);
gr_pre_script(tt)= mp_xstrdup(mp,gr_pre_script((mp_text_object*)p));
gr_post_script(tt)= mp_xstrdup(mp,gr_post_script((mp_text_object*)p));
gr_text_p(tt)= mp_xstrldup(mp,gr_text_p(p),gr_text_l(p));
gr_text_l(tt)= gr_text_l(p);
gr_font_name(tt)= mp_xstrdup(mp,gr_font_name(p));
q= (mp_graphic_object*)tt;
break;
case mp_start_clip_code:
tc= (mp_clip_object*)mp_new_graphic_object(mp,mp_start_clip_code);
gr_path_p(tc)= mp_gr_copy_path(mp,gr_path_p((mp_clip_object*)p));
q= (mp_graphic_object*)tc;
break;
case mp_start_bounds_code:
tb= (mp_bounds_object*)mp_new_graphic_object(mp,mp_start_bounds_code);
gr_path_p(tb)= mp_gr_copy_path(mp,gr_path_p((mp_bounds_object*)p));
q= (mp_graphic_object*)tb;
break;
case mp_special_code:
tp= (mp_special_object*)mp_new_graphic_object(mp,mp_special_code);
gr_pre_script(tp)= mp_xstrdup(mp,gr_pre_script((mp_special_object*)p));
q= (mp_graphic_object*)tp;
break;
case mp_stop_clip_code:
q= mp_new_graphic_object(mp,mp_stop_clip_code);
break;
case mp_stop_bounds_code:
q= mp_new_graphic_object(mp,mp_stop_bounds_code);
break;
}
return q;
}
/*:244*/
