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

void checkExtraTwoBitsP16(double f16, double temp, bool * bitsNPlusOne, bool * bitsMore ){
	temp /= 2;
	if (temp<=f16){
		*bitsNPlusOne = 1;
		f16-=temp;
	}
	if (f16>0)
		*bitsMore = 1;
}
uint_fast16_t convertFractionP16(double f16, uint_fast8_t fracLength, bool * bitsNPlusOne, bool * bitsMore ){

	uint_fast16_t frac=0;

	if(f16==0) return 0;
	else if(f16==INFINITY) return 0x8000;

	f16 -= 1; //remove hidden bit
	if (fracLength==0)
		checkExtraTwoBitsP16(f16, 1.0, bitsNPlusOne, bitsMore);
	else{
		double temp = 1;
		while (true){
			temp /= 2;
			if (temp<=f16){
				f16-=temp;
				fracLength--;
				frac = (frac<<1) + 1; //shift in one
				if (f16==0){
					//put in the rest of the bits
					frac <<= (uint_fast8_t)fracLength;
					break;
				}

				if (fracLength == 0){
					checkExtraTwoBitsP16(f16, temp, bitsNPlusOne, bitsMore);

					break;
				}
			}
			else{
				frac <<= 1; //shift in a zero
				fracLength--;
				if (fracLength == 0){
					checkExtraTwoBitsP16(f16, temp, bitsNPlusOne, bitsMore);
					break;
				}
			}
		}
	}

	return frac;
}
posit16_t convertFloatToP16(float a){
	return convertDoubleToP16((double) a);
}

posit16_t convertDoubleToP16(double f16){
	union ui16_p16 uZ;
	bool sign, regS;
	uint_fast16_t reg, frac=0;
	int_fast8_t exp=0;
	bool bitNPlusOne=0, bitsMore=0;

	(f16>=0) ? (sign=0) : (sign=1);

	if (f16 == 0 ){
		uZ.ui = 0;
		return uZ.p;
	}
	else if(f16 == INFINITY || f16 == -INFINITY || f16 == NAN){
		uZ.ui = 0x8000;
		return uZ.p;
	}
	else if (f16 == 1) {
		uZ.ui = 16384;
		return uZ.p;
	}
	else if (f16 == -1){
		uZ.ui = 49152;
		return uZ.p;
	}
	else if (f16 >= 268435456){
		//maxpos
		uZ.ui = 32767;
		return uZ.p;
	}
	else if (f16 <= -268435456){
		// -maxpos
		uZ.ui = 32769;
		return uZ.p;
	}
	else if(f16 <= 3.725290298461914e-9 && !sign){
		//minpos
		uZ.ui = 1;
		return uZ.p;
	}
	else if(f16 >= -3.725290298461914e-9 && sign){
		//-minpos
		uZ.ui = 65535;
		return uZ.p;
	}
	else if (f16>1 || f16<-1){
		if (sign){
			//Make negative numbers positive for easier computation
			f16 = -f16;
		}

		regS = 1;
		reg = 1; //because k = m-1; so need to add back 1
		// minpos
		if (f16 <= 3.725290298461914e-9){
			uZ.ui = 1;
		}
		else{
			//regime
			while (f16>=4){
				f16 *=0.25;
				reg++;
			}
			if (f16>=2){
				f16*=0.5;
				exp++;
			}

			int fracLength = 13-reg;

			if (fracLength<0){
				//reg == 14, means rounding bits is exp and just the rest.
				if (f16>1) 	bitsMore = 1;

			}
			else
				frac = convertFractionP16 (f16, fracLength, &bitNPlusOne, &bitsMore);


			if (reg==14 && frac>0) {
				bitsMore = 1;
				frac=0;
			}
			if (reg>14)
				(regS) ? (uZ.ui= 32767): (uZ.ui=0x1);
			else{
				uint_fast16_t regime = 1;
				if (regS) regime = ( (1<<reg)-1 ) <<1;
				uZ.ui = ((uint16_t) (regime) << (14-reg)) + ((uint16_t) (exp)<< (13-reg)) + ((uint16_t)(frac));
				//n+1 frac bit is 1. Need to check if another bit is 1 too if not round to even
				if (reg==14 && exp) bitNPlusOne = 1;
				uZ.ui += (bitNPlusOne & (uZ.ui&1)) | ( bitNPlusOne & bitsMore);
			}
			if (sign) uZ.ui = -uZ.ui & 0xFFFF;
		}
	}
	else if (f16 < 1 || f16 > -1 ){

		if (sign){
			//Make negative numbers positive for easier computation
			f16 = -f16;
		}
		regS = 0;
		reg = 0;

		//regime
		while (f16<1){
			f16 *= 4;
			reg++;
		}
		if (f16>=2){
			f16/=2;
			exp++;
		}
		if (reg==14){
			bitNPlusOne = exp;
			if (frac>1) bitsMore = 1;
		}
		else{
			//only possible combination for reg=15 to reach here is 7FFF (maxpos) and FFFF (-minpos)
			//but since it should be caught on top, so no need to handle
			int_fast8_t fracLength = 13-reg;
			frac = convertFractionP16 (f16, fracLength, &bitNPlusOne, &bitsMore);
		}

		if (reg==14 && frac>0) {
			bitsMore = 1;
			frac=0;
		}
		if (reg>14)
			(regS) ? (uZ.ui= 32767): (uZ.ui=0x1);
		else{
			uint_fast16_t regime = 1;
			if (regS) regime = ( (1<<reg)-1 ) <<1;
			uZ.ui = ((uint16_t) (regime) << (14-reg)) + ((uint16_t) (exp)<< (13-reg)) + ((uint16_t)(frac));
			//n+1 frac bit is 1. Need to check if another bit is 1 too if not round to even
			if (reg==14 && exp) bitNPlusOne = 1;
			uZ.ui += (bitNPlusOne & (uZ.ui&1)) | ( bitNPlusOne & bitsMore);
		}
		if (sign) uZ.ui = -uZ.ui & 0xFFFF;
	}
	else {
		//NaR - for NaN, INF and all other combinations
		uZ.ui = 0x8000;
	}
	return uZ.p;
}


#ifdef SOFTPOSIT_QUAD
	void checkQuadExtraTwoBitsP16(__float128 f16, double temp, bool * bitsNPlusOne, bool * bitsMore ){
		temp /= 2;
		if (temp<=f16){
			*bitsNPlusOne = 1;
			f16-=temp;
		}
		if (f16>0)
			*bitsMore = 1;
	}
	uint_fast16_t convertQuadFractionP16(__float128 f16, uint_fast8_t fracLength, bool * bitsNPlusOne, bool * bitsMore ){

		uint_fast16_t frac=0;

		if(f16==0) return 0;
		else if(f16==INFINITY) return 0x8000;

		f16 -= 1; //remove hidden bit
		if (fracLength==0)
			checkQuadExtraTwoBitsP16(f16, 1.0, bitsNPlusOne, bitsMore);
		else{
			__float128 temp = 1;
			while (true){
				temp /= 2;
				if (temp<=f16){
					f16-=temp;
					fracLength--;
					frac = (frac<<1) + 1; //shift in one
					if (f16==0){
						//put in the rest of the bits
						frac <<= (uint_fast8_t)fracLength;
						break;
					}

					if (fracLength == 0){
						checkQuadExtraTwoBitsP16(f16, temp, bitsNPlusOne, bitsMore);

						break;
					}
				}
				else{
					frac <<= 1; //shift in a zero
					fracLength--;
					if (fracLength == 0){
						checkQuadExtraTwoBitsP16(f16, temp, bitsNPlusOne, bitsMore);
						break;
					}
				}
			}
		}

		return frac;
	}


	posit16_t convertQuadToP16(__float128 f16){
		union ui16_p16 uZ;
		bool sign, regS;
		uint_fast16_t reg, frac=0;
		int_fast8_t exp=0;
		bool bitNPlusOne=0, bitsMore=0;

		(f16>=0) ? (sign=0) : (sign=1);

		if (f16 == 0 ){
			uZ.ui = 0;
			return uZ.p;
		}
		else if(f16 == INFINITY || f16 == -INFINITY || f16 == NAN){
			uZ.ui = 0x8000;
			return uZ.p;
		}
		else if (f16 == 1) {
			uZ.ui = 16384;
			return uZ.p;
		}
		else if (f16 == -1){
			uZ.ui = 49152;
			return uZ.p;
		}
		else if (f16 >= 268435456){
			//maxpos
			uZ.ui = 32767;
			return uZ.p;
		}
		else if (f16 <= -268435456){
			// -maxpos
			uZ.ui = 32769;
			return uZ.p;
		}
		else if(f16 <= 3.725290298461914e-9 && !sign){
			//minpos
			uZ.ui = 1;
			return uZ.p;
		}
		else if(f16 >= -3.725290298461914e-9 && sign){
			//-minpos
			uZ.ui = 65535;
			return uZ.p;
		}
		else if (f16>1 || f16<-1){
			if (sign){
				//Make negative numbers positive for easier computation
				f16 = -f16;
			}
			regS = 1;
			reg = 1; //because k = m-1; so need to add back 1
			// minpos
			if (f16 <= 3.725290298461914e-9){
				uZ.ui = 1;
			}
			else{
				//regime
				while (f16>=4){
					f16 *=0.25;
					reg++;
				}
				if (f16>=2){
					f16*=0.5;
					exp++;
				}

				int8_t fracLength = 13-reg;
				if (fracLength<0){
					//reg == 14, means rounding bits is exp and just the rest.
					if (f16>1) 	bitsMore = 1;
				}
				else
					frac = convertQuadFractionP16 (f16, fracLength, &bitNPlusOne, &bitsMore);

				if (reg==14 && frac>0) {
					bitsMore = 1;
					frac=0;
				}

				if (reg>14)
					(regS) ? (uZ.ui= 32767): (uZ.ui=0x1);
				else{
					uint_fast16_t regime = 1;
					if (regS) regime = ( (1<<reg)-1 ) <<1;
					uZ.ui = ((uint16_t) (regime) << (14-reg)) + ((uint16_t) (exp)<< (13-reg)) + ((uint16_t)(frac));
					//n+1 frac bit is 1. Need to check if another bit is 1 too if not round to even
					if (reg==14 && exp) bitNPlusOne = 1;
					uZ.ui += (bitNPlusOne & (uZ.ui&1)) | ( bitNPlusOne & bitsMore);
				}
				if (sign) uZ.ui = -uZ.ui & 0xFFFF;
			}
		}
		else if (f16 < 1 || f16 > -1 ){
			if (sign){
				//Make negative numbers positive for easier computation
				f16 = -f16;
			}
			regS = 0;
			reg = 0;

			//regime
			while (f16<1){
				f16 *= 4;
				reg++;
			}
			if (f16>=2){
				f16/=2;
				exp++;
			}
			if (reg==14){
				bitNPlusOne = exp;
				if (frac>1) bitsMore = 1;
			}
			else{
				//only possible combination for reg=15 to reach here is 7FFF (maxpos) and FFFF (-minpos)
				//but since it should be caught on top, so no need to handle
				int_fast8_t fracLength = 13-reg;
				frac = convertQuadFractionP16 (f16, fracLength, &bitNPlusOne, &bitsMore);
			}

			if (reg==14 && frac>0) {
				bitsMore = 1;
				frac=0;
			}
			if (reg>14)
				(regS) ? (uZ.ui= 32767): (uZ.ui=0x1);
			else{
				uint_fast16_t regime = 1;
				if (regS) regime = ( (1<<reg)-1 ) <<1;
				uZ.ui = ((uint16_t) (regime) << (14-reg)) + ((uint16_t) (exp)<< (13-reg)) + ((uint16_t)(frac));
				//n+1 frac bit is 1. Need to check if another bit is 1 too if not round to even
				if (reg==14 && exp) bitNPlusOne = 1;
				uZ.ui += (bitNPlusOne & (uZ.ui&1)) | ( bitNPlusOne & bitsMore);
			}
			if (sign) uZ.ui = -uZ.ui & 0xFFFF;

		}
		else {
			//NaR - for NaN, INF and all other combinations
			uZ.ui = 0x8000;
		}
		return uZ.p;
	}
#endif



