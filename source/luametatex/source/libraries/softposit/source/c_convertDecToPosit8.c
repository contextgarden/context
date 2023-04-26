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

void checkExtraTwoBitsP8(double f8, double temp, bool * bitsNPlusOne, bool * bitsMore ){
	temp /= 2;
	if (temp<=f8){
		*bitsNPlusOne = 1;
		f8-=temp;
	}
	if (f8>0)
		*bitsMore = 1;
}
uint_fast16_t convertFractionP8(double f8, uint_fast8_t fracLength, bool * bitsNPlusOne, bool * bitsMore ){

	uint_fast8_t frac=0;

	if(f8==0) return 0;
	else if(f8==INFINITY) return 0x80;

	f8 -= 1; //remove hidden bit
	if (fracLength==0)
		checkExtraTwoBitsP8(f8, 1.0, bitsNPlusOne, bitsMore);
	else{
		double temp = 1;
		while (true){
			temp /= 2;
			if (temp<=f8){
				f8-=temp;
				fracLength--;
				frac = (frac<<1) + 1; //shift in one
				if (f8==0){
					//put in the rest of the bits
					frac <<= (uint_fast8_t)fracLength;
					break;
				}

				if (fracLength == 0){
					checkExtraTwoBitsP8(f8, temp, bitsNPlusOne, bitsMore);

					break;
				}
			}
			else{
				frac <<= 1; //shift in a zero
				fracLength--;
				if (fracLength == 0){
					checkExtraTwoBitsP8(f8, temp, bitsNPlusOne, bitsMore);
					break;
				}
			}
		}
	}


	//printf("convertfloat: frac:%d f16: %.26f  bitsNPlusOne: %d, bitsMore: %d\n", frac, f16, bitsNPlusOne, bitsMore);

	return frac;
}
posit8_t convertDoubleToP8(double f8){
	union ui8_p8 uZ;
	bool sign;
	uint_fast8_t reg, frac=0;
	bool bitNPlusOne=0, bitsMore=0;

	(f8>=0) ? (sign=0) : (sign=1);
	// sign: 1 bit, frac: 8 bits, mantisa: 23 bits
	//sign = a.parts.sign;
	//frac = a.parts.fraction;
	//exp = a.parts.exponent;

	if (f8 == 0 ){
		uZ.ui = 0;
		return uZ.p;
	}
	else if(f8 == INFINITY || f8 == -INFINITY || f8 == NAN){
		uZ.ui = 0x80;
		return uZ.p;
	}
	else if (f8 == 1) {
		uZ.ui = 0x40;
		return uZ.p;
	}
	else if (f8 == -1){
		uZ.ui = 0xC0;
		return uZ.p;
	}
	else if (f8 >= 64){
		//maxpos
		uZ.ui = 0x7F;
		return uZ.p;
	}
	else if (f8 <= -64){
		// -maxpos
		uZ.ui = 0x81;
		return uZ.p;
	}
	else if(f8 <= 0.015625 && !sign){
		//minpos
		uZ.ui = 0x1;
		return uZ.p;
	}
	else if(f8 >= -0.015625 && sign){
		//-minpos
		uZ.ui = 0xFF;
		return uZ.p;
	}
	else if (f8>1 || f8<-1){
		if (sign){
			//Make negative numbers positive for easier computation
			f8 = -f8;
		}
		reg = 1; //because k = m-1; so need to add back 1
		// minpos
		if (f8 <= 0.015625){
			uZ.ui = 1;
		}
		else{
			//regime
			while (f8>=2){
				f8 *=0.5;
				reg++;
			}

			//rounding off regime bits
			if (reg>6 )
				uZ.ui= 0x7F;
			else{
				int8_t fracLength = 6-reg;
				frac = convertFractionP8 (f8, fracLength, &bitNPlusOne, &bitsMore);
				uint_fast8_t regime = 0x7F - (0x7F>>reg);
				uZ.ui = packToP8UI(regime, frac);
				if (bitNPlusOne)
					uZ.ui += ((uZ.ui&1) |  bitsMore );
			}
			if(sign) uZ.ui = -uZ.ui & 0xFF;
		}
	}
	else if (f8 < 1 || f8 > -1 ){

		if (sign){
			//Make negative numbers positive for easier computation
			f8 = -f8;
		}
		reg = 0;

		//regime
		//printf("here we go\n");
		while (f8<1){
			f8 *= 2;
			reg++;
		}
		//rounding off regime bits
		if (reg>6 )
			uZ.ui=0x1;
		else{
			int_fast8_t fracLength = 6-reg;
			frac = convertFractionP8 (f8, fracLength, &bitNPlusOne, &bitsMore);
			uint_fast8_t regime = 0x40>>reg;
			uZ.ui = packToP8UI(regime, frac);
			if (bitNPlusOne)
				uZ.ui += ((uZ.ui&1) |  bitsMore );
		}
		if(sign) uZ.ui = -uZ.ui & 0xFF;

	}
	else {
		//NaR - for NaN, INF and all other combinations
		uZ.ui = 0x80;
	}
	return uZ.p;
}



