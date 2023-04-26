
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

#include "platform.h"
#include "internals.h"


double convertP8ToDouble(posit8_t a){
	union ui8_p8 uZ;
	double d8;
	uZ.p = a;

	if (uZ.ui==0){
		return 0;
	}
	else if(uZ.ui==0x7F){ //maxpos
		return 64;
	}
	else if (uZ.ui==0x81){ //-maxpos
		return -64;
	}
	else if (uZ.ui == 0x80){ //NaR
		return NAN;
	}

	bool regS, sign;
	uint_fast8_t reg, shift=2, frac;
	int_fast8_t k=0;
	double fraction_max;

	sign = signP8UI( uZ.ui );
	if (sign) uZ.ui = -uZ.ui & 0xFF;
	regS = signregP8UI( uZ.ui );

	uint_fast8_t tmp = (uZ.ui<<2) & 0xFF;
	if (regS){
		while (tmp>>7){
			k++;
			shift++;
			tmp= (tmp<<1) & 0xFF;
		}
		reg = k+1;
	}
	else{
		k=-1;
		while (!(tmp>>7)){
			k--;
			shift++;
			tmp= (tmp<<1) & 0xFF;
		}
		tmp&=0x7F;
		reg =-k;
	}
	frac = (tmp & 0x7F) >> shift;


	fraction_max = pow(2, 6-reg) ;
	d8 = (double)( pow(2, k) * (1+((double)frac/fraction_max)) );

	if (sign)
		d8 = -d8;

	return d8;
}
