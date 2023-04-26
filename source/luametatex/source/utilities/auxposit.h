/*
    See license.txt in the root of this project.
*/

# ifndef LMT_UTILITIES_POSIT_H
# define LMT_UTILITIES_POSIT_H

# include "libraries/softposit/source/include/softposit.h"
# include <math.h>

typedef posit32_t  posit_t;
typedef posit32_t *posit;

/*tex

    Below is the abstraction of posits for \METAPOST\ and \LUA. Currently we have only 32 bit 
    posits, but for \TEX\ that is okay. It's why we have extra aliases for \TEX\ so that we 
    can update \LUA\ and \METAPOST\ with 64 bit without changes. 

*/

# define posit_bits             32

# define i64_to_posit           i64_to_p32
# define posit_to_i64           p32_to_i64
                                
# define double_to_posit        convertDoubleToP32
# define posit_to_double        convertP32ToDouble
# define integer_to_posit       i64_to_p32
# define posit_to_integer       p32_to_i64

# define posit_round_to_integer p32_roundToInt

# define posit_eq               p32_eq 
# define posit_le               p32_le    
# define posit_lt               p32_lt   
# define posit_gt(a,b)          (! p32_le(a,b))
# define posit_ge(a,b)          (! p32_lt(a,b))
# define posit_ne(a,b)          (! p32_eq(a,b))
                                
# define posit_add              p32_add   
# define posit_sub              p32_sub
# define posit_mul              p32_mul
# define posit_div              p32_div  
# define posit_sqrt             p32_sqrt
                                
# define posit_is_NaR           isNaRP32UI

# define posit_eq_zero(a) (a.v == 0)         

inline static posit_t posit_neg(posit_t a) { posit_t p ; p.v = -a.v & 0xFFFFFFFF; return p; } 
inline static posit_t posit_abs(posit_t a) { posit_t p ; int mask = a.v >> 31; p.v = ((a.v + mask) ^ mask) & 0xFFFFFFFF; return p; }

//     static posit_t posit_neg     (posit_t v)            { return posit_mul(v, integer_to_posit(-1)) ; }
inline static posit_t posit_fabs    (posit_t v)            { return double_to_posit(fabs (posit_to_double(v))); }
inline static posit_t posit_exp     (posit_t v)            { return double_to_posit(exp  (posit_to_double(v))); }
inline static posit_t posit_log     (posit_t v)            { return double_to_posit(log  (posit_to_double(v))); }   
inline static posit_t posit_sin     (posit_t v)            { return double_to_posit(sin  (posit_to_double(v))); }   
inline static posit_t posit_cos     (posit_t v)            { return double_to_posit(cos  (posit_to_double(v))); }   
inline static posit_t posit_tan     (posit_t v)            { return double_to_posit(tan  (posit_to_double(v))); }   
inline static posit_t posit_asin    (posit_t v)            { return double_to_posit(asin (posit_to_double(v))); }   
inline static posit_t posit_acos    (posit_t v)            { return double_to_posit(acos (posit_to_double(v))); }   
inline static posit_t posit_atan    (posit_t v)            { return double_to_posit(atan (posit_to_double(v))); }   
inline static posit_t posit_atan2   (posit_t v, posit_t w) { return double_to_posit(atan2(posit_to_double(v),posit_to_double(w))); }   
inline static posit_t posit_pow     (posit_t v, posit_t w) { return double_to_posit(pow  (posit_to_double(v),posit_to_double(w))); }   
inline static posit_t posit_round   (posit_t v)            { return posit_round_to_integer(v); }   
inline static posit_t posit_floor   (posit_t v)            { return double_to_posit(floor(posit_to_double(v))); }   
inline static posit_t posit_modf    (posit_t v)            { double d; return double_to_posit(modf(posit_to_double(v), &d)); }   
   
inline static posit_t posit_d_log   (double v)             { return double_to_posit(log  (v)); }   
inline static posit_t posit_d_sin   (double v)             { return double_to_posit(sin  (v)); }   
inline static posit_t posit_d_cos   (double v)             { return double_to_posit(cos  (v)); }   
inline static posit_t posit_d_asin  (double v)             { return double_to_posit(asin (v)); }   
inline static posit_t posit_d_acos  (double v)             { return double_to_posit(acos (v)); }   
inline static posit_t posit_d_atan  (double v)             { return double_to_posit(atan (v)); }   
inline static posit_t posit_d_atan2 (double v, double w)   { return double_to_posit(atan2(v,w)); }   
                                                              
inline static int     posit_i_round (posit_t v)            { return posit_to_integer(v); }   
   
/*tex 

    The next code is used at the \TEX\ end where we are always 32 bit, while at some 
    point \METAPOST\ and \LUA\ will go 64 bit. 

    The posit lib code is somewhat over the top wrt comparisons, so I might   
    eventually replace that. 

    Not all relevant parts are done yet (I need to check where dimensions and posits)
    get cast. 

*/

typedef int       halfword;
typedef posit32_t tex_posit;

# define tex_double_to_posit(p)         double_to_posit(p)       
# define tex_posit_to_double(p)         posit_to_double((tex_posit) { .v = (uint32_t) p })       

# define tex_integer_to_posit(p)        integer_to_posit((int32_t) p)      
# define tex_posit_to_integer(p)        posit_to_integer((tex_posit) { .v = (uint32_t) p })      

# define tex_posit_round_to_integer(p)  posit_round_to_integer((tex_posit) { .v = (uint32_t) p })

# define tex_posit_eq(p,q)              posit_eq((tex_posit) { .v = (uint32_t) p }, (tex_posit) { .v = (uint32_t) q })             
# define tex_posit_le(p,q)              posit_le((tex_posit) { .v = (uint32_t) p }, (tex_posit) { .v = (uint32_t) q })             
# define tex_posit_lt(p,q)              posit_lt((tex_posit) { .v = (uint32_t) p }, (tex_posit) { .v = (uint32_t) q })             
# define tex_posit_gt(p,q)              posit_gt((tex_posit) { .v = (uint32_t) p }, (tex_posit) { .v = (uint32_t) q })
# define tex_posit_ge(p,q)              posit_ge((tex_posit) { .v = (uint32_t) p }, (tex_posit) { .v = (uint32_t) q })
# define tex_posit_ne(p,q)              posit_ne((tex_posit) { .v = (uint32_t) p }, (tex_posit) { .v = (uint32_t) q })
                                
# define tex_posit_add(p,q)             (halfword) posit_add((tex_posit) { .v = (uint32_t) p }, (tex_posit) { .v = (uint32_t) q }).v
# define tex_posit_sub(p,q)             (halfword) posit_sub((tex_posit) { .v = (uint32_t) p }, (tex_posit) { .v = (uint32_t) q }).v
# define tex_posit_mul(p,q)             (halfword) posit_mul((tex_posit) { .v = (uint32_t) p }, (tex_posit) { .v = (uint32_t) q }).v
# define tex_posit_div(p,q)             (halfword) posit_div((tex_posit) { .v = (uint32_t) p }, (tex_posit) { .v = (uint32_t) q }).v
# define tex_posit_sqrt(p)              (halfword) posit_sqrt((tex_posit) { .v = (uint32_t) p }.v
                                     
# define tex_posit_is_NaR(p)            posit_is_NaR((tex_posit) { .v = (uint32_t) p })         

# define tex_posit_eq_zero(p)           posit_eq_zero((tex_posit) { .v = (uint32_t) p })        

inline static halfword tex_posit_neg(halfword a) 
{ 
    posit32_t p ; 
    p.v = -a & 0xFFFFFFFF; 
    return p.v; 
} 

inline static halfword tex_posit_abs(halfword a) { 
    posit32_t p ; 
    int mask = a >> 31; 
    p.v = ((a + mask) ^ mask) & 0xFFFFFFFF; 
    return p.v; 
}

inline static tex_posit tex_dimension_to_posit(halfword p) 
{
    return p32_div(ui32_to_p32(p), ui32_to_p32(65536));
}

inline static halfword tex_posit_to_dimension(halfword p) 
{
    posit32_t x; 
    x.v = (uint32_t) p; 
    return posit_to_integer(p32_mul(x, i32_to_p32(65536)));     
}

# endif
