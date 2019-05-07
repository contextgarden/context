/*2:*/
#line 43 "../../../source/texk/web2c/mplibdir/tfmin.w"

#include <w2c/config.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mplib.h"
#include "mpmp.h"
#include "mpmath.h"
#include "mpstrings.h"
/*3:*/
#line 59 "../../../source/texk/web2c/mplibdir/tfmin.w"

font_number mp_read_font_info(MP mp,char*fname);

/*:3*/
#line 52 "../../../source/texk/web2c/mplibdir/tfmin.w"
;
#define qi(A) (quarterword) (A)
#define null_font 0
#define false 0
#define true 1
#define hlp1(A) mp->help_line[0]= A;}
#define hlp2(A,B) mp->help_line[1]= A;hlp1(B)
#define hlp3(A,B,C) mp->help_line[2]= A;hlp2(B,C)
#define help3 {mp->help_ptr= 3;hlp3 \

#define tfget do{ \
size_t wanted= 1; \
unsigned char abyte= 0; \
void*tfbyte_ptr= &abyte; \
(mp->read_binary_file) (mp,mp->tfm_infile,&tfbyte_ptr,&wanted) ; \
if(wanted==0) goto BAD_TFM; \
tfbyte= (int) abyte; \
}while(0)
#define read_two(A) {(A) = tfbyte; \
if((A) > 127) goto BAD_TFM; \
tfget;(A) = (A) *0400+tfbyte; \
}
#define tf_ignore(A) {for(jj= (A) ;jj>=1;jj--) tfget;} \

#define integer_as_fraction(A) (int) (A)  \


#line 53 "../../../source/texk/web2c/mplibdir/tfmin.w"


/*:2*//*4:*/
#line 62 "../../../source/texk/web2c/mplibdir/tfmin.w"

font_number mp_read_font_info(MP mp,char*fname){
boolean file_opened;
font_number n;
halfword lf,tfm_lh,bc,ec,nw,nh,nd;
size_t whd_size;
int i,ii;
int jj;
int z;
int d;
int h_and_d;
int tfbyte= 0;
n= null_font;
/*12:*/
#line 234 "../../../source/texk/web2c/mplibdir/tfmin.w"

file_opened= false;
mp_ptr_scan_file(mp,fname);
if(strlen(mp->cur_area)==0){mp_xfree(mp->cur_area);mp->cur_area= NULL;}
if(strlen(mp->cur_ext)==0){
mp_xfree(mp->cur_ext);
mp->cur_ext= mp_xstrdup(mp,".tfm");
}
mp_pack_file_name(mp,mp->cur_name,mp->cur_area,mp->cur_ext);
mp->tfm_infile= (mp->open_file)(mp,mp->name_of_file,"r",mp_filetype_metrics);
if(!mp->tfm_infile)goto BAD_TFM;
file_opened= true







/*:12*/
#line 75 "../../../source/texk/web2c/mplibdir/tfmin.w"
;
/*6:*/
#line 109 "../../../source/texk/web2c/mplibdir/tfmin.w"

/*7:*/
#line 138 "../../../source/texk/web2c/mplibdir/tfmin.w"

tfget;read_two(lf);
tfget;read_two(tfm_lh);
tfget;read_two(bc);
tfget;read_two(ec);
if((bc> 1+ec)||(ec> 255))goto BAD_TFM;
tfget;read_two(nw);
tfget;read_two(nh);
tfget;read_two(nd);
whd_size= (size_t)((ec+1-bc)+nw+nh+nd);
if(lf<(int)(6+(size_t)tfm_lh+whd_size))goto BAD_TFM;
tf_ignore(10)

/*:7*/
#line 110 "../../../source/texk/web2c/mplibdir/tfmin.w"
;
/*8:*/
#line 157 "../../../source/texk/web2c/mplibdir/tfmin.w"

if(mp->next_fmem<(size_t)bc)
mp->next_fmem= (size_t)bc;
if(mp->last_fnum==mp->font_max)
mp_reallocate_fonts(mp,(mp->font_max+(mp->font_max/4)));
while(mp->next_fmem+whd_size>=mp->font_mem_size){
size_t l= mp->font_mem_size+(mp->font_mem_size/4);
font_data*font_info;
font_info= mp_xmalloc(mp,(l+1),sizeof(font_data));
memset(font_info,0,sizeof(font_data)*(l+1));
memcpy(font_info,mp->font_info,sizeof(font_data)*(mp->font_mem_size+1));
mp_xfree(mp->font_info);
mp->font_info= font_info;
mp->font_mem_size= l;
}
mp->last_fnum++;
n= mp->last_fnum;
mp->font_bc[n]= (eight_bits)bc;
mp->font_ec[n]= (eight_bits)ec;
mp->char_base[n]= (int)(mp->next_fmem-(size_t)bc);
mp->width_base[n]= (int)(mp->next_fmem+(size_t)(ec-bc)+1);
mp->height_base[n]= mp->width_base[n]+nw;
mp->depth_base[n]= mp->height_base[n]+nh;
mp->next_fmem= mp->next_fmem+whd_size;


/*:8*/
#line 111 "../../../source/texk/web2c/mplibdir/tfmin.w"
;
/*9:*/
#line 187 "../../../source/texk/web2c/mplibdir/tfmin.w"

if(tfm_lh<2)goto BAD_TFM;
tf_ignore(4);
tfget;read_two(z);
tfget;z= z*0400+tfbyte;
tfget;z= z*0400+tfbyte;
mp->font_dsize[n]= mp_take_fraction(mp,z,integer_as_fraction(267432584));

tf_ignore(4*(tfm_lh-2))

/*:9*/
#line 112 "../../../source/texk/web2c/mplibdir/tfmin.w"
;
/*10:*/
#line 197 "../../../source/texk/web2c/mplibdir/tfmin.w"

ii= mp->width_base[n];
i= mp->char_base[n]+bc;
while(i<ii){
tfget;mp->font_info[i].qqqq.b0= qi(tfbyte);
tfget;h_and_d= tfbyte;
mp->font_info[i].qqqq.b1= qi(h_and_d/16);
mp->font_info[i].qqqq.b2= qi(h_and_d%16);
tfget;tfget;
i++;
}
while(i<(int)mp->next_fmem){
/*11:*/
#line 220 "../../../source/texk/web2c/mplibdir/tfmin.w"

{
tfget;d= tfbyte;
if(d>=0200)d= d-0400;
tfget;d= d*0400+tfbyte;
tfget;d= d*0400+tfbyte;
tfget;d= d*0400+tfbyte;
mp->font_info[i].sc= mp_take_fraction(mp,d*16,integer_as_fraction(mp->font_dsize[n]));
i++;
}

/*:11*/
#line 210 "../../../source/texk/web2c/mplibdir/tfmin.w"
;
}
goto DONE

/*:10*/
#line 114 "../../../source/texk/web2c/mplibdir/tfmin.w"


/*:6*/
#line 77 "../../../source/texk/web2c/mplibdir/tfmin.w"
;
BAD_TFM:
/*5:*/
#line 94 "../../../source/texk/web2c/mplibdir/tfmin.w"

{
char msg[256];
const char*hlp[]= {
"I wasn't able to read the size data for this font so this",
"`infont' operation won't produce anything. If the font name",
"is right, you might ask an expert to make a TFM file",
NULL};
if(file_opened)
hlp[2]= "is right, try asking an expert to fix the TFM file";
mp_snprintf(msg,256,"Font %s not usable: TFM file %s",fname,
(file_opened?"is bad":"not found"));
mp_error(mp,msg,hlp,true);
}

/*:5*/
#line 79 "../../../source/texk/web2c/mplibdir/tfmin.w"
;
DONE:
if(file_opened)(mp->close_file)(mp,mp->tfm_infile);
if(n!=null_font){
mp->font_ps_name[n]= mp_xstrdup(mp,fname);
mp->font_name[n]= mp_xstrdup(mp,fname);
}
return n;
}

/*:4*/
