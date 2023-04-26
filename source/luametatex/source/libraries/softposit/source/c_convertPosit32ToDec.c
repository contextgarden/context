
/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane).

Copyright 2017, 2018 A*STAR.  All rights reserved.

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

#include <math.h>

#ifdef SOFTPOSIT_QUAD
#include <quadmath.h>
#endif

#include "platform.h"
#include "internals.h"



#ifdef SOFTPOSIT_QUAD
__float128 convertP32ToQuad(posit32_t a){

	union ui32_p32 uZ;
	__float128 p32;
	uZ.p = a;

	if (uZ.ui==0){
		p32 = 0;
		return p32;
	}
	else if(uZ.ui==0x7FFFFFFF){ //maxpos
		p32 = 1.329227995784916e+36;
		return p32;
	}
	else if (uZ.ui==0x80000001){ //-maxpos
		p32 = -1.329227995784916e+36;
		return p32;
	}
	else if (uZ.ui == 0x80000000){
		p32 = NAN;
		return p32;
	}

	bool regS, sign;
	uint_fast32_t reg, shift=2, frac, tmp;
	int_fast32_t k=0;
	int_fast8_t exp;
	__float128 fraction_max;

	sign = signP32UI( uZ.ui );
	if (sign)
		uZ.ui = -uZ.ui & 0xFFFFFFFF;
	regS = signregP32UI( uZ.ui );

	tmp = tmp = (uZ.ui<<2)&0xFFFFFFFF;
	if (regS){
		while (tmp>>31){
			k++;
			shift++;
			tmp= (tmp<<1) & 0xFFFFFFFF;
		}
		reg = k+1;
	}
	else{
		k=-1;
		while (!(tmp>>31)){
			k--;
			shift++;
			tmp= (tmp<<1) & 0xFFFFFFFF;
		}
		tmp&=0x7FFFFFFF;
		reg =-k;
	}
	exp = tmp>>29;
	frac = (tmp & 0x1FFFFFFF) >> shift;

	(reg>28) ? (fraction_max=1) : (fraction_max = pow(2, 28-reg) ) ;

	p32 = (__float128)( pow(16, k)* pow(2, exp) * (1+((__float128)frac/fraction_max)) );

	if (sign)
		p32 = -p32;

	return p32;

}

__float128 convertPX2ToQuad(posit_2_t a){

	union ui32_pX2 uZ;
	__float128 p32;
	uZ.p = a;

	if (uZ.ui==0){
		p32 = 0;
		return p32;
	}
	else if(uZ.ui==0x7FFFFFFF){ //maxpos
		p32 = 1.329227995784916e+36;
		return p32;
	}
	else if (uZ.ui==0x80000001){ //-maxpos
		p32 = -1.329227995784916e+36;
		return p32;
	}
	else if (uZ.ui == 0x80000000){
		p32 = INFINITY;
		return p32;
	}

	bool regS, sign;
	uint_fast32_t reg, shift=2, frac, tmp;
	int_fast32_t k=0;
	int_fast8_t exp;
	__float128 fraction_max;

	sign = signP32UI( uZ.ui );
	if (sign)
		uZ.ui = -uZ.ui & 0xFFFFFFFF;
	regS = signregP32UI( uZ.ui );

	tmp = tmp = (uZ.ui<<2)&0xFFFFFFFF;
	if (regS){
		while (tmp>>31){
			k++;
			shift++;
			tmp= (tmp<<1) & 0xFFFFFFFF;
		}
		reg = k+1;
	}
	else{
		k=-1;
		while (!(tmp>>31)){
			k--;
			shift++;
			tmp= (tmp<<1) & 0xFFFFFFFF;
		}
		tmp&=0x7FFFFFFF;
		reg =-k;
	}
	exp = tmp>>29;
	frac = (tmp & 0x1FFFFFFF) >> shift;

	(reg>28) ? (fraction_max=1) : (fraction_max = pow(2, 28-reg) ) ;

	p32 = (__float128)( pow(16, k)* pow(2, exp) * (1+((__float128)frac/fraction_max)) );

	if (sign)
		p32 = -p32;

	return p32;

}


#endif


double convertP32ToDouble(posit32_t pA){
	union ui32_p32 uA;
	union ui64_double uZ;
	uint_fast32_t uiA, tmp=0;
	uint_fast64_t expA=0, uiZ, fracA=0;
	bool signA=0, regSA;
	int_fast32_t scale, kA=0;

	uA.p = pA;
	uiA = uA.ui;

	if (uA.ui == 0)
		return 0;
	else if(uA.ui == 0x80000000)
		return NAN;

	else{
		signA = signP32UI( uiA );
		if(signA) uiA = (-uiA & 0xFFFFFFFF);
		regSA = signregP32UI(uiA);
		tmp = (uiA<<2)&0xFFFFFFFF;
		if (regSA){

			while (tmp>>31){
				kA++;
				tmp= (tmp<<1) & 0xFFFFFFFF;
			}
		}
		else{
			kA=-1;
			while (!(tmp>>31)){
				kA--;
				tmp= (tmp<<1) & 0xFFFFFFFF;
			}
			tmp&=0x7FFFFFFF;
		}
		expA = tmp>>29; //to get 2 bits

		fracA = (((uint64_t)tmp<<3)  & 0xFFFFFFFF)<<20;

		expA = (((kA<<2)+expA) + 1023) << 52;
		uiZ = expA + fracA + (((uint64_t)signA&0x1)<<63);

		uZ.ui = uiZ;
		return uZ.d;
	}
}
/*double convertP32ToDoubleOld(posit32_t pA){
	union ui32_p32 uZ;
	double d32;
	uZ.p = pA;

	if (uZ.ui==0){
		return  0;
	}
	else if(uZ.ui==0x7FFFFFFF){ //maxpos
		return  1.329227995784916e+36;
	}
	else if (uZ.ui==0x80000001){ //-maxpos
		return -1.329227995784916e+36;
	}
	else if (uZ.ui == 0x80000000){
		return INFINITY;
	}

	bool regS, sign;
	uint_fast32_t reg, shift=2, frac, tmp;
	int_fast32_t k=0;
	int_fast8_t exp;
	double fraction_max;

	sign = signP32UI( uZ.ui );
	if (sign)
		uZ.ui = -uZ.ui & 0xFFFFFFFF;
	regS = signregP32UI( uZ.ui );

	tmp = (uZ.ui<<2)&0xFFFFFFFF;
	if (regS){
		while (tmp>>31){
			k++;
			shift++;
			tmp= (tmp<<1) & 0xFFFFFFFF;
		}
		reg = k+1;
	}
	else{
		k=-1;
		while (!(tmp>>31)){
			k--;
			shift++;
			tmp= (tmp<<1) & 0xFFFFFFFF;
		}
		tmp&=0x7FFFFFFF;
		reg =-k;
	}
	exp = tmp>>29;

	frac = (tmp & 0x1FFFFFFF) >> shift;

	(reg>28) ? (fraction_max=1) : (fraction_max = pow(2, 28-reg) ) ;


	d32 = (double)( pow(16, k)* pow(2, exp) * (1+((double)frac/fraction_max)) );
	if (sign)
		d32 = -d32;

	return d32;

}*/


double convertPX2ToDouble(posit_2_t a){
	union ui32_pX2 uZ;
	double d32;
	uZ.p = a;

	if (uZ.ui==0){
		return  0;
	}
	else if(uZ.ui==0x7FFFFFFF){ //maxpos
		return  1.329227995784916e+36;
	}
	else if (uZ.ui==0x80000001){ //-maxpos
		return -1.329227995784916e+36;
	}
	else if (uZ.ui == 0x80000000){
		return INFINITY;
	}

	bool regS, sign;
	uint_fast32_t reg, shift=2, frac, tmp;
	int_fast32_t k=0;
	int_fast8_t exp;
	double fraction_max;

	sign = signP32UI( uZ.ui );
	if (sign)
		uZ.ui = -uZ.ui & 0xFFFFFFFF;
	regS = signregP32UI( uZ.ui );

	tmp = (uZ.ui<<2)&0xFFFFFFFF;
	if (regS){
		while (tmp>>31){
			k++;
			shift++;
			tmp= (tmp<<1) & 0xFFFFFFFF;
		}
		reg = k+1;
	}
	else{
		k=-1;
		while (!(tmp>>31)){
			k--;
			shift++;
			tmp= (tmp<<1) & 0xFFFFFFFF;
		}
		tmp&=0x7FFFFFFF;
		reg =-k;
	}
	exp = tmp>>29;

	frac = (tmp & 0x1FFFFFFF) >> shift;

	(reg>28) ? (fraction_max=1) : (fraction_max = pow(2, 28-reg) ) ;


	d32 = (double)( pow(16, k)* pow(2, exp) * (1+((double)frac/fraction_max)) );
	if (sign)
		d32 = -d32;

	return d32;

}


