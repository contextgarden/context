/*2:*/
#line 17 "../../../source/texk/web2c/mplibdir/mpstrings.w"

#include <w2c/config.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <assert.h>
#ifdef HAVE_UNISTD_H
#  include <unistd.h>
#endif
#include <time.h>
#include "mpstrings.h"

/*:2*//*5:*/
#line 52 "../../../source/texk/web2c/mplibdir/mpstrings.w"

#define STRCMP_RESULT(a) ((a)<0 ? -1 : ((a)> 0 ? 1 : 0))
static int comp_strings_entry(void*p,const void*pa,const void*pb){
const mp_lstring*a= (const mp_lstring*)pa;
const mp_lstring*b= (const mp_lstring*)pb;
size_t l;
unsigned char*s,*t;
(void)p;
s= a->str;
t= b->str;
l= (a->len<=b->len?a->len:b->len);
while(l--> 0){
if(*s!=*t)
return STRCMP_RESULT(*s-*t);
s++;t++;
}
return STRCMP_RESULT((int)(a->len-b->len));
}
void*copy_strings_entry(const void*p){
mp_string ff;
const mp_lstring*fp;
fp= (const mp_lstring*)p;
ff= malloc(sizeof(mp_lstring));
if(ff==NULL)
return NULL;
ff->str= malloc(fp->len+1);
if(ff->str==NULL){
return NULL;
}
memcpy((char*)ff->str,(char*)fp->str,fp->len+1);
ff->len= fp->len;
ff->refs= 0;
return ff;
}
static void*delete_strings_entry(void*p){
mp_string ff= (mp_string)p;
mp_xfree(ff->str);
mp_xfree(ff);
return NULL;
}

/*:5*//*7:*/
#line 96 "../../../source/texk/web2c/mplibdir/mpstrings.w"

static mp_string new_strings_entry(MP mp){
mp_string ff;
ff= mp_xmalloc(mp,1,sizeof(mp_lstring));
ff->str= NULL;
ff->len= 0;
ff->refs= 0;
return ff;
}


/*:7*//*9:*/
#line 116 "../../../source/texk/web2c/mplibdir/mpstrings.w"

char*mp_strldup(const char*p,size_t l){
char*r,*s;
if(p==NULL)
return NULL;
r= malloc((size_t)(l*sizeof(char)+1));
if(r==NULL)
return NULL;
s= memcpy(r,p,(size_t)(l));
*(s+l)= '\0';
return s;
}
char*mp_strdup(const char*p){
if(p==NULL)
return NULL;
return mp_strldup(p,strlen(p));
}

/*:9*//*10:*/
#line 134 "../../../source/texk/web2c/mplibdir/mpstrings.w"

int mp_xstrcmp(const char*a,const char*b){
if(a==NULL&&b==NULL)
return 0;
if(a==NULL)
return-1;
if(b==NULL)
return 1;
return strcmp(a,b);
}
char*mp_xstrldup(MP mp,const char*s,size_t l){
char*w;
if(s==NULL)
return NULL;
w= mp_strldup(s,l);
if(w==NULL){
mp_fputs("Out of memory!\n",mp->err_out);
mp->history= mp_system_error_stop;
mp_jump_out(mp);
}
return w;
}
char*mp_xstrdup(MP mp,const char*s){
if(s==NULL)
return NULL;
return mp_xstrldup(mp,s,strlen(s));
}


/*:10*//*11:*/
#line 163 "../../../source/texk/web2c/mplibdir/mpstrings.w"

void mp_initialize_strings(MP mp){
mp->strings= avl_create(comp_strings_entry,
copy_strings_entry,
delete_strings_entry,malloc,free,NULL);
mp->cur_string= NULL;
mp->cur_length= 0;
mp->cur_string_size= 0;
}

/*:11*//*12:*/
#line 173 "../../../source/texk/web2c/mplibdir/mpstrings.w"

void mp_dealloc_strings(MP mp){
if(mp->strings!=NULL)
avl_destroy(mp->strings);
mp->strings= NULL;
mp_xfree(mp->cur_string);
mp->cur_string= NULL;
mp->cur_length= 0;
mp->cur_string_size= 0;
}

/*:12*//*15:*/
#line 199 "../../../source/texk/web2c/mplibdir/mpstrings.w"

char*mp_str(MP mp,mp_string ss){
(void)mp;
return(char*)ss->str;
}

/*:15*//*16:*/
#line 205 "../../../source/texk/web2c/mplibdir/mpstrings.w"

mp_string mp_rtsl(MP mp,const char*s,size_t l){
mp_string str,nstr;
str= new_strings_entry(mp);
str->str= (unsigned char*)mp_xstrldup(mp,s,l);
str->len= l;
nstr= (mp_string)avl_find(str,mp->strings);
if(nstr==NULL){
assert(avl_ins(str,mp->strings,avl_false)> 0);
nstr= (mp_string)avl_find(str,mp->strings);
}
(void)delete_strings_entry(str);
add_str_ref(nstr);
return nstr;
}

/*:16*//*17:*/
#line 221 "../../../source/texk/web2c/mplibdir/mpstrings.w"

mp_string mp_rts(MP mp,const char*s){
return mp_rtsl(mp,s,strlen(s));
}


/*:17*//*20:*/
#line 266 "../../../source/texk/web2c/mplibdir/mpstrings.w"

void mp_reset_cur_string(MP mp){
mp_xfree(mp->cur_string);
mp->cur_length= 0;
mp->cur_string_size= 63;
mp->cur_string= (unsigned char*)mp_xmalloc(mp,64,sizeof(unsigned char));
memset(mp->cur_string,0,64);
}


/*:20*//*24:*/
#line 305 "../../../source/texk/web2c/mplibdir/mpstrings.w"

void mp_flush_string(MP mp,mp_string s){
if(s->refs==0){
mp->strs_in_use--;
mp->pool_in_use= mp->pool_in_use-(integer)s->len;
(void)avl_del(s,mp->strings,NULL);
}
}


/*:24*//*25:*/
#line 318 "../../../source/texk/web2c/mplibdir/mpstrings.w"

mp_string mp_intern(MP mp,const char*s){
mp_string r;
r= mp_rts(mp,s);
r->refs= MAX_STR_REF;
return r;
}

/*:25*//*28:*/
#line 337 "../../../source/texk/web2c/mplibdir/mpstrings.w"

mp_string mp_make_string(MP mp){
mp_string str;
mp_lstring tmp;
tmp.str= mp->cur_string;
tmp.len= mp->cur_length;
str= (mp_string)avl_find(&tmp,mp->strings);
if(str==NULL){
str= mp_xmalloc(mp,1,sizeof(mp_lstring));
str->str= mp->cur_string;
str->len= tmp.len;
assert(avl_ins(str,mp->strings,avl_false)> 0);
str= (mp_string)avl_find(&tmp,mp->strings);
mp->pool_in_use= mp->pool_in_use+(integer)str->len;
if(mp->pool_in_use> mp->max_pl_used)
mp->max_pl_used= mp->pool_in_use;
mp->strs_in_use++;
if(mp->strs_in_use> mp->max_strs_used)
mp->max_strs_used= mp->strs_in_use;
}
add_str_ref(str);
mp_reset_cur_string(mp);
return str;
}


/*:28*//*30:*/
#line 371 "../../../source/texk/web2c/mplibdir/mpstrings.w"

integer mp_str_vs_str(MP mp,mp_string s,mp_string t){
(void)mp;
return comp_strings_entry(NULL,(const void*)s,(const void*)t);
}



/*:30*//*32:*/
#line 382 "../../../source/texk/web2c/mplibdir/mpstrings.w"

mp_string mp_cat(MP mp,mp_string a,mp_string b){
mp_string str;
size_t needed;
size_t saved_cur_length= mp->cur_length;
unsigned char*saved_cur_string= mp->cur_string;
size_t saved_cur_string_size= mp->cur_string_size;
needed= a->len+b->len;
mp->cur_length= 0;

mp->cur_string= (unsigned char*)mp_xmalloc(mp,needed+1,sizeof(unsigned char));
mp->cur_string_size= 0;
str_room(needed+1);
(void)memcpy(mp->cur_string,a->str,a->len);
(void)memcpy(mp->cur_string+a->len,b->str,b->len);
mp->cur_length= needed;
mp->cur_string[needed]= '\0';
str= mp_make_string(mp);
mp_xfree(mp->cur_string);
mp->cur_length= saved_cur_length;
mp->cur_string= saved_cur_string;
mp->cur_string_size= saved_cur_string_size;
return str;
}


/*:32*//*34:*/
#line 411 "../../../source/texk/web2c/mplibdir/mpstrings.w"

mp_string mp_chop_string(MP mp,mp_string s,integer a,integer b){
integer l;
integer k;
boolean reversed;
if(a<=b)
reversed= false;
else{
reversed= true;
k= a;
a= b;
b= k;
}
l= (integer)s->len;
if(a<0){
a= 0;
if(b<0)
b= 0;
}
if(b> l){
b= l;
if(a> l)
a= l;
}
str_room((size_t)(b-a));
if(reversed){
for(k= b-1;k>=a;k--){
append_char(*(s->str+k));
}
}else{
for(k= a;k<b;k++){
append_char(*(s->str+k));
}
}
return mp_make_string(mp);
}
/*:34*/
