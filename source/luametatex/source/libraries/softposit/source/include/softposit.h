/*============================================================================

This C header file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane).

Copyright 2017, 2018 A*STAR.  All rights reserved.

This C header file was based on SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3d, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2017 The Regents of the
University of California.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions, and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions, and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

 3. Neither the name of the University nor the names of its contributors may
    be used to endorse or promote products derived from this software without
    specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS", AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ARE
DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=============================================================================*/


/*============================================================================
| Note:  If SoftPosit is modified from SoftFloat and is made available as a
| general library for programs to use, it is strongly recommended that a
| platform-specific version of this header, "softposit.h", be created that
| folds in "softposit_types.h" and that eliminates all dependencies on
| compile-time macros.
*============================================================================*/


#ifndef softposit_h
#define softposit_h 1

#ifdef __cplusplus
extern "C"{
#endif

#include <stdbool.h>
#include <stdint.h>

#ifdef SOFTPOSIT_QUAD
#include <quadmath.h>
#endif

#include "softposit_types.h"

#include <stdio.h>


#ifndef THREAD_LOCAL
#define THREAD_LOCAL
#endif

#define castUI( a ) ( (a).v )

/*----------------------------------------------------------------------------
| Integer-to-posit conversion routines.
*----------------------------------------------------------------------------*/
posit8_t  ui32_to_p8( uint32_t );
posit16_t ui32_to_p16( uint32_t );
posit32_t ui32_to_p32( uint32_t );
//posit64_t ui32_to_p64( uint32_t );


posit8_t  ui64_to_p8( uint64_t );
posit16_t ui64_to_p16( uint64_t );
posit32_t ui64_to_p32( uint64_t );
//posit64_t ui64_to_p64( uint64_t );

posit8_t  i32_to_p8( int32_t );
posit16_t i32_to_p16( int32_t );
posit32_t i32_to_p32( int32_t );
//posit64_t i32_to_p64( int32_t );

posit8_t  i64_to_p8( int64_t );
posit16_t i64_to_p16( int64_t );
posit32_t i64_to_p32( int64_t );
//posit64_t i64_to_p64( int64_t );



/*----------------------------------------------------------------------------
| 8-bit (quad-precision) posit operations.
*----------------------------------------------------------------------------*/
#define isNaRP8UI( a ) ( ((a) ^ 0x80) == 0 )

uint_fast32_t p8_to_ui32( posit8_t );
uint_fast64_t p8_to_ui64( posit8_t );
int_fast32_t p8_to_i32( posit8_t);
int_fast64_t p8_to_i64( posit8_t);

posit16_t p8_to_p16( posit8_t );
posit32_t p8_to_p32( posit8_t );
//posit64_t p8_to_p64( posit8_t );

posit_1_t p8_to_pX1( posit8_t, int );
posit_2_t p8_to_pX2( posit8_t, int );

posit8_t p8_roundToInt( posit8_t );
posit8_t p8_add( posit8_t, posit8_t );
posit8_t p8_sub( posit8_t, posit8_t );
posit8_t p8_mul( posit8_t, posit8_t );
posit8_t p8_mulAdd( posit8_t, posit8_t, posit8_t );
posit8_t p8_div( posit8_t, posit8_t );
posit8_t p8_sqrt( posit8_t );
bool p8_eq( posit8_t, posit8_t );
bool p8_le( posit8_t, posit8_t );
bool p8_lt( posit8_t, posit8_t );


//Quire 8
quire8_t q8_fdp_add(quire8_t, posit8_t, posit8_t);
quire8_t q8_fdp_sub(quire8_t, posit8_t, posit8_t);
posit8_t q8_to_p8(quire8_t);
#define isNaRQ8( q ) ( (q).v==0x80000000  )
#define isQ8Zero(q) ( (q).v==0 )

int_fast64_t p8_int( posit8_t );

#define q8_clr(q) ({\
	(q).v=0;\
	q;\
})

static inline quire8_t q8Clr(){
    quire8_t q;
	q.v=0;
	return q;
}

#define castQ8(a)({\
		union ui32_q8 uA;\
		uA.ui = (a);\
		uA.q;\
})


#define castP8(a)({\
		union ui8_p8 uA;\
		uA.ui = (a);\
		uA.p;\
})


#define negP8(a)({\
		union ui8_p8 uA;\
		uA.p = (a);\
		uA.ui = -uA.ui&0xFF;\
		uA.p; \
})

#define absP8(a)({\
		union ui8_p8 uA;\
		uA.p = (a);\
		int mask = uA.ui >> 7;\
		uA.ui = ((uA.ui + mask) ^ mask)&0xFF;\
		uA.p; \
})

//Helper
double convertP8ToDouble(posit8_t);
posit8_t convertDoubleToP8(double);

/*----------------------------------------------------------------------------
| 16-bit (half-precision) posit operations.
*----------------------------------------------------------------------------*/
#define isNaRP16UI( a ) ( ((a) ^ 0x8000) == 0 )

uint_fast32_t p16_to_ui32( posit16_t );
uint_fast64_t p16_to_ui64( posit16_t );
int_fast32_t p16_to_i32( posit16_t);
int_fast64_t p16_to_i64( posit16_t );
posit8_t p16_to_p8( posit16_t );
posit32_t p16_to_p32( posit16_t );
//posit64_t p16_to_p64( posit16_t );

posit_1_t p16_to_pX1( posit16_t, int );
posit_2_t p16_to_pX2( posit16_t, int );

posit16_t p16_roundToInt( posit16_t);
posit16_t p16_add( posit16_t, posit16_t );
posit16_t p16_sub( posit16_t, posit16_t );
posit16_t p16_mul( posit16_t, posit16_t );
posit16_t p16_mulAdd( posit16_t, posit16_t, posit16_t );
posit16_t p16_div( posit16_t, posit16_t );
posit16_t p16_sqrt( posit16_t );
bool p16_eq( posit16_t, posit16_t );
bool p16_le( posit16_t, posit16_t );
bool p16_lt( posit16_t, posit16_t );


#ifdef SOFTPOSIT_QUAD
	__float128 convertP16ToQuadDec(posit16_t);
	posit16_t convertQuadToP16(__float128);
#endif

//Quire 16
quire16_t q16_fdp_add(quire16_t, posit16_t, posit16_t);
quire16_t q16_fdp_sub(quire16_t, posit16_t, posit16_t);
posit16_t convertQ16ToP16(quire16_t);
posit16_t q16_to_p16(quire16_t);
#define isNaRQ16( q ) ( (q).v[0]==0x8000000000000000ULL && (q).v[1]==0 )
#define isQ16Zero(q) (q.v[0]==0 && q.v[1]==0)
quire16_t q16_TwosComplement(quire16_t);


int_fast64_t p16_int( posit16_t);

void printBinary(uint64_t*, int);
void printBinaryPX(uint32_t*, int);
void printHex(uint64_t);
void printHex64(uint64_t);
void printHexPX(uint32_t, int);

#define q16_clr(q) ({\
	(q).v[0]=0;\
	(q).v[1]=0;\
	q;\
})

static inline quire16_t q16Clr(){
    quire16_t q;
	q.v[0]=0;
	q.v[1]=0;
	return q;
}

#define castQ16(l, r)({\
		union ui128_q16 uA;\
		uA.ui[0] = l; \
		uA.ui[1] = r; \
		uA.q;\
})


#define castP16(a)({\
		union ui16_p16 uA;\
		uA.ui = (a);\
		uA.p;\
})



#define negP16(a)({\
		union ui16_p16 uA;\
		uA.p = (a);\
		uA.ui = -uA.ui&0xFFFF;\
		uA.p; \
})

#define absP16(a)({\
		union ui16_p16 uA;\
		uA.p = (a);\
		int mask = uA.ui >> 15;\
		uA.ui = ((uA.ui + mask) ^ mask)&0xFFFF;\
		uA.p; \
})

//Helper

double convertP16ToDouble(posit16_t);
posit16_t convertFloatToP16(float);
posit16_t convertDoubleToP16(double);

/*----------------------------------------------------------------------------
| 32-bit (single-precision) posit operations.
*----------------------------------------------------------------------------*/
uint_fast32_t p32_to_ui32( posit32_t );
uint_fast64_t p32_to_ui64( posit32_t);
int_fast32_t p32_to_i32( posit32_t );
int_fast64_t p32_to_i64( posit32_t );

posit8_t p32_to_p8( posit32_t );
posit16_t p32_to_p16( posit32_t );
//posit64_t p32_to_p64( posit32_t );


posit32_t p32_roundToInt( posit32_t );
posit32_t p32_add( posit32_t, posit32_t );
posit32_t p32_sub( posit32_t, posit32_t );
posit32_t p32_mul( posit32_t, posit32_t );
posit32_t p32_mulAdd( posit32_t, posit32_t, posit32_t );
posit32_t p32_div( posit32_t, posit32_t );
posit32_t p32_sqrt( posit32_t );
bool p32_eq( posit32_t, posit32_t );
bool p32_le( posit32_t, posit32_t );
bool p32_lt( posit32_t, posit32_t );

posit_1_t p32_to_pX1( posit32_t, int);
posit_2_t p32_to_pX2( posit32_t, int );

#define isNaRP32UI( a ) ( ((a) ^ 0x80000000) == 0 )

int64_t p32_int( posit32_t);

#ifdef SOFTPOSIT_QUAD
	__float128 convertP32ToQuad(posit32_t);
	posit32_t convertQuadToP32(__float128);
#endif


quire32_t q32_fdp_add(quire32_t, posit32_t, posit32_t);
quire32_t q32_fdp_sub(quire32_t, posit32_t, posit32_t);
posit32_t q32_to_p32(quire32_t);
#define isNaRQ32( q ) ( q.v[0]==0x8000000000000000ULL && q.v[1]==0 && q.v[2]==0 && q.v[3]==0 && q.v[4]==0 && q.v[5]==0 && q.v[6]==0 && q.v[7]==0)
#define isQ32Zero(q) (q.v[0]==0 && q.v[1]==0 && q.v[2]==0 && q.v[3]==0 && q.v[4]==0 && q.v[5]==0 && q.v[6]==0 && q.v[7]==0)
quire32_t q32_TwosComplement(quire32_t);

#define q32_clr(q) ({\
	q.v[0]=0;\
	q.v[1]=0;\
	q.v[2]=0;\
	q.v[3]=0;\
	q.v[4]=0;\
	q.v[5]=0;\
	q.v[6]=0;\
	q.v[7]=0;\
	q;\
})

static inline quire32_t q32Clr(){
    quire32_t q;
	q.v[0]=0;
    q.v[1]=0;
	q.v[2]=0;
    q.v[3]=0;
	q.v[4]=0;
    q.v[5]=0;
	q.v[6]=0;
    q.v[7]=0;
	return q;
}

#define castQ32(l0, l1, l2, l3, l4, l5, l6, l7)({\
		union ui512_q32 uA;\
		uA.ui[0] = l0; \
		uA.ui[1] = l1; \
		uA.ui[2] = l2; \
		uA.ui[3] = l3; \
		uA.ui[4] = l4; \
		uA.ui[5] = l5; \
		uA.ui[6] = l6; \
		uA.ui[7] = l7; \
		uA.q;\
})


#define castP32(a)({\
	posit32_t pA = {.v = (a)};\
	pA; \
})



#define negP32(a)({\
		union ui32_p32 uA;\
		uA.p = (a);\
		uA.ui = -uA.ui&0xFFFFFFFF;\
		uA.p; \
})

#define absP32(a)({\
		union ui32_p32 uA;\
		uA.p = (a);\
		int mask = uA.ui >> 31; \
		uA.ui = ((uA.ui + mask) ^ mask)&0xFFFFFFFF; \
		uA.p; \
})

//Helper

double convertP32ToDouble(posit32_t);
posit32_t convertFloatToP32(float);
posit32_t convertDoubleToP32(double);


/*----------------------------------------------------------------------------
| Dyanamic 2 to 32-bit Posits for es = 2
*----------------------------------------------------------------------------*/

posit_2_t pX2_add( posit_2_t, posit_2_t, int);
posit_2_t pX2_sub( posit_2_t, posit_2_t, int);
posit_2_t pX2_mul( posit_2_t, posit_2_t, int);
posit_2_t pX2_div( posit_2_t, posit_2_t, int);
posit_2_t pX2_mulAdd( posit_2_t, posit_2_t, posit_2_t, int);
posit_2_t pX2_roundToInt( posit_2_t, int );
posit_2_t ui32_to_pX2( uint32_t, int );
posit_2_t ui64_to_pX2( uint64_t, int );
posit_2_t i32_to_pX2( int32_t, int );
posit_2_t i64_to_pX2( int64_t, int );
posit_2_t pX2_sqrt( posit_2_t, int );

uint_fast32_t pX2_to_ui32( posit_2_t );
uint_fast64_t pX2_to_ui64( posit_2_t );
int_fast32_t pX2_to_i32( posit_2_t );
int_fast64_t pX2_to_i64( posit_2_t );
int64_t pX2_int( posit_2_t );

bool pX2_eq( posit_2_t, posit_2_t);
bool pX2_le( posit_2_t, posit_2_t);
bool pX2_lt( posit_2_t, posit_2_t);

posit8_t pX2_to_p8( posit_2_t );
posit16_t pX2_to_p16( posit_2_t );
posit_2_t pX2_to_pX2( posit_2_t, int);
posit_1_t pX2_to_pX1( posit_2_t, int);
static inline posit32_t pX2_to_p32(posit_2_t pA){
	posit32_t p32 = {.v = pA.v};
	return p32;
}

#define isNaRPX2UI( a ) ( ((a) ^ 0x80000000) == 0 )

//Helper
posit_2_t convertDoubleToPX2(double, int);

double convertPX2ToDouble(posit_2_t);

#ifdef SOFTPOSIT_QUAD
	__float128 convertPX2ToQuad(posit_2_t);
	posit_2_t convertQuadToPX2(__float128, int);
#endif


quire_2_t qX2_fdp_add( quire_2_t q, posit_2_t pA, posit_2_t );
quire_2_t qX2_fdp_sub( quire_2_t q, posit_2_t pA, posit_2_t );
posit_2_t qX2_to_pX2(quire_2_t, int);
#define isNaRQX2( q ) ( q.v[0]==0x8000000000000000ULL && q.v[1]==0 && q.v[2]==0 && q.v[3]==0 && q.v[4]==0 && q.v[5]==0 && q.v[6]==0 && q.v[7]==0)
#define isQX2Zero(q) (q.v[0]==0 && q.v[1]==0 && q.v[2]==0 && q.v[3]==0 && q.v[4]==0 && q.v[5]==0 && q.v[6]==0 && q.v[7]==0)
quire_2_t qX2_TwosComplement(quire_2_t);

#define qX2_clr(q) ({\
	q.v[0]=0;\
	q.v[1]=0;\
	q.v[2]=0;\
	q.v[3]=0;\
	q.v[4]=0;\
	q.v[5]=0;\
	q.v[6]=0;\
	q.v[7]=0;\
	q;\
})

static inline quire_2_t qX2Clr(){
	quire_2_t q;
	q.v[0]=0;
    q.v[1]=0;
	q.v[2]=0;
    q.v[3]=0;
	q.v[4]=0;
    q.v[5]=0;
	q.v[6]=0;
    q.v[7]=0;
	return q;
}

#define castQX2(l0, l1, l2, l3, l4, l5, l6, l7)({\
		union ui512_qX2 uA;\
		uA.ui[0] = l0; \
		uA.ui[1] = l1; \
		uA.ui[2] = l2; \
		uA.ui[3] = l3; \
		uA.ui[4] = l4; \
		uA.ui[5] = l5; \
		uA.ui[6] = l6; \
		uA.ui[7] = l7; \
		uA.q;\
})


#define castPX2(a)({\
	posit_2_t pA = {.v = (a)};\
	pA; \
})



#define negPX2(a)({\
		union ui32_pX2 uA;\
		uA.p = (a);\
		uA.ui = -uA.ui&0xFFFFFFFF;\
		uA.p; \
})

#define absPX2(a)({\
		union ui32_pX2 uA;\
		uA.p = (a);\
		int  mask = uA.ui >> 31; \
		uA.ui = ((uA.ui + mask) ^ mask)&0xFFFFFFFF; \
		uA.p; \
})

/*----------------------------------------------------------------------------
| Dyanamic 2 to 32-bit Posits for es = 1
*----------------------------------------------------------------------------*/

posit_1_t pX1_add( posit_1_t, posit_1_t, int);
posit_1_t pX1_sub( posit_1_t, posit_1_t, int);
posit_1_t pX1_mul( posit_1_t, posit_1_t, int);
posit_1_t pX1_div( posit_1_t, posit_1_t, int);
posit_1_t pX1_mulAdd( posit_1_t, posit_1_t, posit_1_t, int);
posit_1_t pX1_roundToInt( posit_1_t, int );
posit_1_t ui32_to_pX1( uint32_t, int );
posit_1_t ui64_to_pX1( uint64_t, int );
posit_1_t i32_to_pX1( int32_t, int );
posit_1_t i64_to_pX1( int64_t, int );
posit_1_t pX1_sqrt( posit_1_t, int );

uint_fast32_t pX1_to_ui32( posit_1_t );
uint_fast64_t pX1_to_ui64( posit_1_t );
int_fast32_t pX1_to_i32( posit_1_t );
int_fast64_t pX1_to_i64( posit_1_t );
int64_t pX1_int( posit_1_t );

bool pX1_eq( posit_1_t, posit_1_t);
bool pX1_le( posit_1_t, posit_1_t);
bool pX1_lt( posit_1_t, posit_1_t);

posit8_t pX1_to_p8( posit_1_t );
posit16_t pX1_to_p16( posit_1_t );
posit32_t pX1_to_p32( posit_1_t );
posit_1_t pX1_to_pX1( posit_1_t, int);
posit_2_t pX1_to_pX2( posit_1_t, int);


#define isNaRpX1UI( a ) ( ((a) ^ 0x80000000) == 0 )

//Helper
posit_1_t convertDoubleToPX1(double, int);
double convertPX1ToDouble(posit_1_t);

#ifdef SOFTPOSIT_QUAD
	__float128 convertPX1ToQuad(posit_1_t);
	posit_1_t convertQuadToPX1(__float128, int);
#endif


quire_1_t qX1_fdp_add( quire_1_t q, posit_1_t pA, posit_1_t );
quire_1_t qX1_fdp_sub( quire_1_t q, posit_1_t pA, posit_1_t );
posit_1_t qX1_to_pX1(quire_1_t, int);
#define isNaRqX1( q ) ( q.v[0]==0x8000000000000000ULL && q.v[1]==0 && q.v[2]==0 && q.v[3]==0 && q.v[4]==0 && q.v[5]==0 && q.v[6]==0 && q.v[7]==0)
#define isqX1Zero(q) (q.v[0]==0 && q.v[1]==0 && q.v[2]==0 && q.v[3]==0 && q.v[4]==0 && q.v[5]==0 && q.v[6]==0 && q.v[7]==0)
quire_1_t qX1_TwosComplement(quire_1_t);

#define qX1_clr(q) ({\
	q.v[0]=0;\
	q.v[1]=0;\
	q.v[2]=0;\
	q.v[3]=0;\
	q.v[4]=0;\
	q.v[5]=0;\
	q.v[6]=0;\
	q.v[7]=0;\
	q;\
})

static inline quire_1_t qX1Clr(){
	quire_1_t q;
	q.v[0]=0;
    q.v[1]=0;
	q.v[2]=0;
    q.v[3]=0;
	q.v[4]=0;
    q.v[5]=0;
	q.v[6]=0;
    q.v[7]=0;
	return q;
}

#define castqX1(l0, l1, l2, l3, l4, l5, l6, l7)({\
		union ui512_qX1 uA;\
		uA.ui[0] = l0; \
		uA.ui[1] = l1; \
		uA.ui[2] = l2; \
		uA.ui[3] = l3; \
		uA.ui[4] = l4; \
		uA.ui[5] = l5; \
		uA.ui[6] = l6; \
		uA.ui[7] = l7; \
		uA.q;\
})


#define castpX1(a)({\
	posit_1_t pA = {.v = (a)};\
	pA; \
})



#define negpX1(a)({\
		union ui32_pX1 uA;\
		uA.p = (a);\
		uA.ui = -uA.ui&0xFFFFFFFF;\
		uA.p; \
})

#define absPX1(a)({\
		union ui32_pX1 uA;\
		uA.p = (a);\
		int mask = uA.ui >> 31; \
		uA.ui = ((uA.ui + mask) ^ mask)&0xFFFFFFFF;\
		uA.p; \
})
/*----------------------------------------------------------------------------
| 64-bit (double-precision) floating-point operations.
*----------------------------------------------------------------------------*/
/*uint_fast32_t p64_to_ui32( posit64_t, uint_fast16_t, bool );
uint_fast64_t p64_to_ui64( posit64_t, uint_fast16_t, bool );
int_fast32_t p64_to_i32( posit64_t, uint_fast16_t, bool );
int_fast64_t p64_to_i64( posit64_t, uint_fast16_t, bool );

posit8_t p64_to_p8( posit64_t );
posit16_t p64_to_p16( posit64_t );
posit32_t p64_to_p32( posit64_t );

posit64_t p64_roundToInt( posit64_t, uint_fast16_t, bool );
posit64_t p64_add( posit64_t, posit64_t );
posit64_t p64_sub( posit64_t, posit64_t );
posit64_t p64_mul( posit64_t, posit64_t );
posit64_t p64_mulAdd( posit64_t, posit64_t, posit64_t );
posit64_t p64_div( posit64_t, posit64_t );
posit64_t p64_rem( posit64_t, posit64_t );
posit64_t p64_sqrt( posit64_t );
bool p64_eq( posit64_t, posit64_t );
bool p64_le( posit64_t, posit64_t );*/

#ifdef __cplusplus
}
#endif

#endif

