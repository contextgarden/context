
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

__float128 convertPX1ToQuad(posit_1_t a){

	union ui32_pX1 uZ;
	__float128 p32;
	uZ.p = a;

	if (uZ.ui==0){
		p32 = 0;
		return p32;
	}
	else if(uZ.ui==0x7FFFFFFF){ //maxpos
		p32 = 1152921504606847000;
		return p32;
	}
	else if (uZ.ui==0x80000001){ //-maxpos
		p32 = -1152921504606847000;
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
	exp = tmp>>30;
	frac = (tmp & 0x1FFFFFFF) >> shift;

	(reg>29) ? (fraction_max=1) : (fraction_max = pow(2, 29-reg) ) ;

	p32 = (__float128)( pow(16, k)* pow(2, exp) * (1+((__float128)frac/fraction_max)) );

	if (sign)
		p32 = -p32;

	return p32;

}


#endif




double convertPX1ToDouble(posit_1_t a){
	union ui32_pX1 uZ;
	double d32;
	uZ.p = a;

	if (uZ.ui==0){
		return  0;
	}
	else if(uZ.ui==0x7FFFFFFF){ //maxpos
		return  1152921504606847000;
	}
	else if (uZ.ui==0x80000001){ //-maxpos
		return -1152921504606847000;
	}
	else if (uZ.ui == 0x80000000){
		return NAN;
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
	exp = tmp>>30;

	frac = (tmp & 0x3FFFFFFF) >> shift;

	(reg>29) ? (fraction_max=1) : (fraction_max = pow(2, 29-reg) ) ;

	d32 = (double)( pow(4, k)* pow(2, exp) * (1+((double)frac/fraction_max)) );
	if (sign)
		d32 = -d32;

	return d32;

}


