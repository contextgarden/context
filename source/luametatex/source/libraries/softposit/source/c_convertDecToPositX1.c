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

void checkQuadExtraPX1TwoBits(__float128 f32, __float128 temp, bool * bitsNPlusOne, bool * bitsMore ){
	temp /= 2;
	if (temp<=f32){
		*bitsNPlusOne = 1;
		f32-=temp;
	}
	if (f32>0)
		*bitsMore = 1;
}

uint_fast32_t convertQuadFractionPX1(__float128 f32, uint_fast16_t fracLength, bool * bitNPlusOne, bool * bitsMore ){

	uint_fast32_t frac=0;

	if(f32==0) return 0;
	else if(f32==INFINITY) return 0x80000000;

	f32 -= 1; //remove hidden bit
	if (fracLength==0)
		checkQuadExtraPX1TwoBits(f32, 1.0, bitNPlusOne, bitsMore);
	else{
		__float128 temp = 1;
		while (true){
			temp /= 2;
			if (temp<=f32){

				f32-=temp;

				fracLength--;
				frac = (frac<<1) + 1; //shift in one

				if (f32==0){
					frac <<= (uint_fast32_t)fracLength;
					break;
				}

				if (fracLength == 0){
					checkQuadExtraPX1TwoBits(f32, temp, bitNPlusOne, bitsMore);
					break;
				}
			}
			else{
				frac <<= 1; //shift in a zero
				fracLength--;
				if (fracLength == 0){
					checkQuadExtraPX1TwoBits(f32, temp, bitNPlusOne, bitsMore);
					break;
				}
			}

		}
	}

	return frac;
}

posit_1_t convertQuadToPX1(__float128 f32, int x){

	union ui32_pX1 uZ;
	bool sign, regS;
	uint_fast32_t reg, frac=0;
	int_fast32_t exp=0;
	bool bitNPlusOne=0, bitsMore=0;

	(f32>=0) ? (sign=0) : (sign=1);

	if (f32 == 0 ){
		uZ.ui = 0;
		return uZ.p;
	}
	else if(f32 == INFINITY || f32 == -INFINITY || f32 == NAN){
		uZ.ui = 0x80000000;
		return uZ.p;
	}
	else if (f32 == 1) {
		uZ.ui = 0x40000000;
		return uZ.p;
	}
	else if (f32 == -1){
		uZ.ui = 0xC0000000;
		return uZ.p;
	}
	else if (f32>1 || f32<-1){
		if (sign){
			//Make negative numbers positive for easier computation
			f32 = -f32;
		}

		regS = 1;
		reg = 1; //because k = m-1; so need to add back 1
		// minpos
		if (x==32 && f32 <= 8.673617379884035e-19){
			uZ.ui = 1;
		}
		else{
			//regime
			while (f32>=4){
				f32 *=0.25;  // f32/=4;
				reg++;
			}
			if (f32>=2){
				f32*=0.5;
				exp++;
			}

			int fracLength = x-3-reg;
			if (fracLength<0){
				if (reg==x-2){
					bitNPlusOne=exp;
					exp=0;
				}
				if(f32>1) bitsMore=1;
			}
			else
				frac = convertQuadFractionPX1 (f32, fracLength, &bitNPlusOne, &bitsMore);

			if (reg==30 && frac>0){
				bitsMore = 1;
				frac = 0;
			}

			if (reg>(x-2) ){
				uZ.ui=(regS) ? (0x7FFFFFFF & ((int32_t)0x80000000>>(x-1)) ): (0x1 << (32-x));
			}
			//rounding off fraction bits
			else{

				uint_fast32_t regime = 1;
				if (regS) regime = ( (1<<reg)-1 ) <<1;
				uZ.ui = ((uint32_t) (regime) << (30-reg)) + ((uint32_t) (exp)<< (29-reg)) + ((uint32_t)(frac<<(32-x)));
				//uZ.ui = ((uint32_t) (regime) << (30-reg)) + ((uint32_t) exp ) + ((uint32_t)(frac<<(32-x)));
				//minpos
				if (uZ.ui==0 && frac>0){
					uZ.ui = 0x1 << (32-x);
				}
				if (bitNPlusOne)
					uZ.ui +=  ( ((uZ.ui>>(32-x)) & 0x1) | bitsMore ) << (32-x);
			}
			if (sign) uZ.ui = -uZ.ui & 0xFFFFFFFF;

		}
	}
	else if (f32 < 1 || f32 > -1 ){
		if (sign){
			//Make negative numbers positive for easier computation
			f32 = -f32;
		}
		regS = 0;
		reg = 0;

		//regime
		while (f32<1){
			f32 *= 4;
			reg++;
		}

		if (f32>=2){
			f32*=0.5;
			exp++;
		}


		int fracLength = x-3-reg;
		if (fracLength<0){
			if (reg==x-2){
				bitNPlusOne=exp;
				exp=0;
			}
			if(f32>1) bitsMore=1;
		}
		else
			frac = convertQuadFractionPX1 (f32, fracLength, &bitNPlusOne, &bitsMore);

		if (reg==30 && frac>0){
			bitsMore = 1;
			frac = 0;
		}

		if (reg>(x-2) ){
			uZ.ui=(regS) ? (0x7FFFFFFF & ((int32_t)0x80000000>>(x-1)) ): (0x1 << (32-x));
		}
		//rounding off fraction bits
		else{

			uint_fast32_t regime = 1;
			if (regS) regime = ( (1<<reg)-1 ) <<1;
			uZ.ui = ((uint32_t) (regime) << (30-reg)) + ((uint32_t) (exp)<< (29-reg)) + ((uint32_t)(frac<<(32-x)));
			//uZ.ui = ((uint32_t) (regime) << (30-reg)) + ((uint32_t) exp ) + ((uint32_t)(frac<<(32-x)));
			//minpos
			if (uZ.ui==0 && frac>0){
				uZ.ui = 0x1 << (32-x);
			}
			if (bitNPlusOne)
				uZ.ui +=  ( ((uZ.ui>>(32-x)) & 0x1) | bitsMore ) << (32-x);
		}
		if (sign) uZ.ui = -uZ.ui & 0xFFFFFFFF;

	}
	else {
		//NaR - for NaN, INF and all other combinations
		uZ.ui = 0x80000000;
	}
	return uZ.p;
}

#endif

void checkExtraPX1TwoBits(double f32, double temp, bool * bitsNPlusOne, bool * bitsMore ){
	temp /= 2;
	if (temp<=f32){
		*bitsNPlusOne = 1;
		f32-=temp;
	}
	if (f32>0)
		*bitsMore = 1;
}
uint_fast32_t convertFractionPX1(double f32, uint_fast16_t fracLength, bool * bitsNPlusOne, bool * bitsMore ){

	uint_fast32_t frac=0;

	if(f32==0) return 0;
	else if(f32==INFINITY) return 0x80000000;

	f32 -= 1; //remove hidden bit
	if (fracLength==0)
		checkExtraPX1TwoBits(f32, 1.0, bitsNPlusOne, bitsMore);
	else{
		double temp = 1;
		while (true){
			temp /= 2;
			if (temp<=f32){
				f32-=temp;
				fracLength--;
				frac = (frac<<1) + 1; //shift in one
				if (f32==0){
					frac <<= (uint_fast16_t)fracLength;
					break;
				}

				if (fracLength == 0){
					checkExtraPX1TwoBits(f32, temp, bitsNPlusOne, bitsMore);
					break;
				}
			}
			else{

				frac <<= 1; //shift in a zero
				fracLength--;
				if (fracLength == 0){
					checkExtraPX1TwoBits(f32, temp, bitsNPlusOne, bitsMore);
					break;
				}
			}
		}
	}

	return frac;
}


posit_1_t convertDoubleToPX1(double f32, int x){

	union ui32_pX1 uZ;
	bool sign, regS;
	uint_fast32_t reg, frac=0;
	int_fast32_t exp=0;
	bool bitNPlusOne=0, bitsMore=0;

	(f32>=0) ? (sign=0) : (sign=1);

	if (f32 == 0 ){
		uZ.ui = 0;
		return uZ.p;
	}
	else if(f32 == INFINITY || f32 == -INFINITY || f32 == NAN){
		uZ.ui = 0x80000000;
		return uZ.p;
	}
	else if (f32 == 1) {
		uZ.ui = 0x40000000;
		return uZ.p;
	}
	else if (f32 == -1){
		uZ.ui = 0xC0000000;
		return uZ.p;
	}
	else if (f32>1 || f32<-1){
		if (sign){
			//Make negative numbers positive for easier computation
			f32 = -f32;
		}
		regS = 1;
		reg = 1; //because k = m-1; so need to add back 1
		// minpos
		if (x==32 && f32 <= 8.673617379884035e-19){
			uZ.ui = 1;
		}
		else{
			//regime
			while (f32>=4){
				f32 *=0.25;  // f32/=4;
				reg++;
			}
			if (f32>=2){
				f32*=0.5;
				exp++;
			}
//printf("reg: %d, exp: %d f32: %.26lf\n", reg, exp, f32);
			int fracLength = x-3-reg;
			if (fracLength<0){
				if (reg==x-2){
					bitNPlusOne=exp;
					exp=0;
				}
				if(f32>1) bitsMore=1;
			}
			else
				frac = convertFractionPX1(f32, fracLength, &bitNPlusOne, &bitsMore);

			if (reg==30 && frac>0){
				bitsMore = 1;
				frac = 0;
			}

			if (reg>(x-2) ){
				uZ.ui=(regS) ? (0x7FFFFFFF & ((int32_t)0x80000000>>(x-1)) ): (0x1 << (32-x));
			}
			//rounding off fraction bits
			else{

				uint_fast32_t regime = 1;
				if (regS) regime = ( (1<<reg)-1 ) <<1;
//printf("reg: %d, exp: %d bitNPlusOne: %d bitsMore: %d\n", reg, exp, bitNPlusOne, bitsMore);
//printBinary(&regime, 32);
				uZ.ui = ((uint32_t) (regime) << (30-reg)) + ((uint32_t) (exp)<< (29-reg)) + ((uint32_t)(frac<<(32-x)));
				//uZ.ui = ((uint32_t) (regime) << (30-reg)) + ((uint32_t) exp ) + ((uint32_t)(frac<<(32-x)));
				//minpos
				if (uZ.ui==0 && frac>0){
					uZ.ui = 0x1 << (32-x);
				}
//printBinary(&uZ.ui, 32);
//uint32_t tt = (uZ.ui>>(32-x));
//printBinary(&tt, 32);
				if (bitNPlusOne)
					uZ.ui +=  ( ((uZ.ui>>(32-x)) & 0x1) | bitsMore ) << (32-x);
			}
			if (sign) uZ.ui = -uZ.ui & 0xFFFFFFFF;

		}
	}
	else if (f32 < 1 || f32 > -1 ){
		if (sign){
			//Make negative numbers positive for easier computation
			f32 = -f32;
		}
		regS = 0;
		reg = 0;

		//regime
		while (f32<1){
			f32 *= 4;
			reg++;
		}

		if (f32>=2){
			f32*=0.5;
			exp++;
		}

		int fracLength = x-3-reg;
		if (fracLength<0){
			if (reg==x-2){
				bitNPlusOne=exp;
				exp=0;
			}

			if(f32>1) bitsMore=1;
		}
		else
			frac = convertFractionPX1 (f32, fracLength, &bitNPlusOne, &bitsMore);

		if (reg==30 && frac>0){
			bitsMore = 1;
			frac = 0;
		}

		if (reg>(x-2) ){
			uZ.ui=(regS) ? (0x7FFFFFFF & ((int32_t)0x80000000>>(x-1)) ): (0x1 << (32-x));
		}
		//rounding off fraction bits
		else{
			uint_fast32_t regime = 1;
			if (regS) regime = ( (1<<reg)-1 ) <<1;
			uZ.ui = ((uint32_t) (regime) << (30-reg)) + ((uint32_t) (exp)<< (29-reg)) + ((uint32_t)(frac<<(32-x)));
			//uZ.ui = ((uint32_t) (regime) << (30-reg)) + ((uint32_t) exp ) + ((uint32_t)(frac<<(32-x)));
			//minpos
			if (uZ.ui==0 && frac>0){
				uZ.ui = 0x1 << (32-x);
			}
			if (bitNPlusOne)
				uZ.ui +=  ( ((uZ.ui>>(32-x)) & 0x1) | bitsMore ) << (32-x);
		}
		if (sign) uZ.ui = -uZ.ui & 0xFFFFFFFF;

	}
	else {
		//NaR - for NaN, INF and all other combinations
		uZ.ui = 0x80000000;
	}
	return uZ.p;
}





