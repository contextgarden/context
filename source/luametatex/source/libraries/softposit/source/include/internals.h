
/*============================================================================

This C header file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane).

Copyright 2017, 2018 A*STAR.  All rights reserved.

This C header file is part of the SoftFloat IEEE Floating-Point Arithmetic
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

#ifndef internals_h
#define internals_h 1

#ifdef __cplusplus
extern "C"{
#endif

#include "primitives.h"
#include "softposit.h"
#include "softposit_types.h"

#include <stdio.h>

#ifdef SOFTPOSIT_QUAD
#include <quadmath.h>
#endif



enum {
    softposit_mulAdd_subC    = 1,
    softposit_mulAdd_subProd = 2
};


/*----------------------------------------------------------------------------
*----------------------------------------------------------------------------*/
#define signP8UI( a ) ((bool) ((uint8_t) (a)>>7))
#define signregP8UI( a ) ((bool) (((uint8_t) (a)>>6) & 0x1))
#define packToP8UI( regime, fracA) ((uint8_t) regime + ((uint8_t)(fracA)) )


posit8_t softposit_addMagsP8( uint_fast8_t, uint_fast8_t );
posit8_t softposit_subMagsP8( uint_fast8_t, uint_fast8_t );
posit8_t softposit_mulAddP8( uint_fast8_t, uint_fast8_t, uint_fast8_t, uint_fast8_t );


/*----------------------------------------------------------------------------
*----------------------------------------------------------------------------*/
#define signP16UI( a ) ( (bool) ( ( uint16_t ) (a)>>15 ) )
#define signregP16UI( a ) ( (bool) (((uint16_t) (a)>>14) & 0x1) )
#define expP16UI( a, regA ) ((int_fast8_t) ((a)>>(13-regA) & 0x0001))
#define packToP16UI( regime, regA, expA, fracA) ((uint16_t) regime + ((uint16_t) (expA)<< (13-regA)) + ((uint16_t)(fracA)) )

posit16_t softposit_addMagsP16( uint_fast16_t, uint_fast16_t );
posit16_t softposit_subMagsP16( uint_fast16_t, uint_fast16_t );
posit16_t softposit_mulAddP16( uint_fast16_t, uint_fast16_t, uint_fast16_t, uint_fast16_t );


/*----------------------------------------------------------------------------
*----------------------------------------------------------------------------*/
#define signP32UI( a ) ((bool) ((uint32_t) (a)>>31))
#define signregP32UI( a ) ((bool) (((uint32_t) (a)>>30) & 0x1))
#define packToP32UI(regime, expA, fracA) ( (uint32_t) regime + (uint32_t) expA + ((uint32_t)(fracA)) )

posit32_t softposit_addMagsP32( uint_fast32_t, uint_fast32_t );
posit32_t softposit_subMagsP32( uint_fast32_t, uint_fast32_t );
posit32_t softposit_mulAddP32( uint_fast32_t, uint_fast32_t, uint_fast32_t, uint_fast32_t );


/*----------------------------------------------------------------------------
*----------------------------------------------------------------------------*/

posit_2_t softposit_addMagsPX2( uint_fast32_t, uint_fast32_t, int );
posit_2_t softposit_subMagsPX2( uint_fast32_t, uint_fast32_t, int );
posit_2_t softposit_mulAddPX2( uint_fast32_t, uint_fast32_t, uint_fast32_t, uint_fast32_t, int );

/*----------------------------------------------------------------------------
*----------------------------------------------------------------------------*/

posit_1_t softposit_addMagsPX1( uint_fast32_t, uint_fast32_t, int);
posit_1_t softposit_subMagsPX1( uint_fast32_t, uint_fast32_t, int);
posit_1_t softposit_mulAddPX1( uint_fast32_t, uint_fast32_t, uint_fast32_t, uint_fast32_t, int );

/*uint_fast16_t reglengthP32UI (uint32_t);
int_fast16_t regkP32UI(bool, uint_fast32_t);
#define expP32UI( a, regA ) ((int_fast16_t) ((a>>(28-regA)) & 0x2))
#define regP32UI( a, regLen ) (  ((( uint_fast32_t ) (a) & (0x7FFFFFFF)) >> (30-regLen))) )
#define isNaRP32UI( a ) ( ((a) ^ 0x80000000) == 0 )
#define useed32P 16;
//int_fast16_t expP32UI(uint32_t);
#define expP32sizeUI 2;
uint_fast32_t fracP32UI(uint_fast32_t, uint_fast16_t);*/



/*posit32_t convertDecToP32(posit32);
posit32_t convertfloatToP32(float);
posit32_t convertdoubleToP32(double );
//posit32_t convertQuadToP32(__float128);
//__float128 convertP32ToQuadDec(posit32_t);


//posit32_t c_roundPackToP32( bool, bool, int_fast16_t, int_fast16_t, uint_fast16_t, bool, bool );

//#define isNaNP32UI( a ) (((~(a) & 0x7F800000) == 0) && ((a) & 0x007FFFFF))


//posit32_t softposit_roundPackToP32( bool, int_fast16_t, uint_fast32_t );
//posit32_t softposit_normRoundPackToP32( bool, int_fast16_t, uint_fast32_t );

posit32_t softposit_addMagsP32( uint_fast32_t, uint_fast32_t );
posit32_t softposit_subMagsP32( uint_fast32_t, uint_fast32_t );
posit32_t softposit_mulAddP32(uint_fast32_t, uint_fast32_t, uint_fast32_t, uint_fast16_t);


//quire32_t quire32_add(quire32_t, quire32_t);
//quire32_t quire32_sub(quire32_t, quire32_t);
quire32_t quire32_mul(posit32_t, posit32_t);
quire32_t q32_fdp_add(quire32_t, posit32_t, posit32_t);
quire32_t q32_fdp_sub(quire32_t, posit32_t, posit32_t);
posit32_t convertQ32ToP32(quire32_t);
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
*/

#ifdef __cplusplus
}
#endif


#endif



