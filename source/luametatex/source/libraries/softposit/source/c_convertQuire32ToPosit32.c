
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



posit32_t q32_to_p32(quire32_t qA){

	union ui512_q32 uZ;
	union ui32_p32 uA;
	uint_fast32_t regA, fracA = 0, shift=0, regime;
	uint_fast64_t frac64A;
	bool sign, regSA=0, bitNPlusOne=0, bitsMore=0;
	int_fast32_t expA = 0;
	int i;

	if (isQ32Zero(qA)){
		uA.ui=0;
		return uA.p;
	}
	//handle NaR
	else if (isNaRQ32(qA)){
		uA.ui=0x80000000;
		return uA.p;
	}

	uZ.q = qA;

	sign = uZ.ui[0]>>63;

	if(sign){
		for (i=7; i>=0; i--){
			if (uZ.ui[i]>0){
				uZ.ui[i] = - uZ.ui[i];
				i--;
				while(i>=0){
					uZ.ui[i] = ~uZ.ui[i];
					i--;
				}
				break;
			}
		}
	}
	//minpos and maxpos

	int noLZ =0;

	for (i=0; i<8; i++){
		if (uZ.ui[i]==0){
			noLZ+=64;
		}
		else{
			uint_fast64_t tmp = uZ.ui[i];
			int noLZtmp = 0;

			while (!(tmp>>63)){
				noLZtmp++;
				tmp= (tmp<<1);
			}

			noLZ+=noLZtmp;
			frac64A = tmp;
			if (i!=7 && noLZtmp!=0){
				frac64A+= ( uZ.ui[i+1]>>(64-noLZtmp) );
				if( uZ.ui[i+1] & (((uint64_t)0x1<<(64-noLZtmp))-1) )
					bitsMore=1;
				i++;
			}
			i++;
			while(i<8){
				if (uZ.ui[i]>0){
					bitsMore = 1;;
					break;
				}
				i++;
			}
			break;
		}
	}

	//default dot is between bit 271 and 272, extreme left bit is bit 0. Last right bit is bit 511.
	//Equations derived from quire32_mult  last_pos = 271 - (kA<<2) - expA and first_pos = last_pos - frac_len
	int kA=(271-noLZ) >> 2;
	expA = 271 - noLZ - (kA<<2) ;


	if(kA<0){
		//regA = (-kA & 0xFFFF);
		regA = -kA;
		regSA = 0;
		regime = 0x40000000>>regA;
	}
	else{
		regA = kA+1;
		regSA=1;
		regime = 0x7FFFFFFF - (0x7FFFFFFF>>regA);
	}


	if(regA>30){
		//max or min pos. exp and frac does not matter.
		(regSA) ? (uA.ui= 0x7FFFFFFF): (uA.ui=0x1);
	}
	else{

		//remove hidden bit
		frac64A&=0x7FFFFFFFFFFFFFFF;

		shift = regA+35; //2 es bit, 1 sign bit and 1 r terminating bit , 31+4

		fracA = frac64A>>shift;

		if (regA<=28){
			bitNPlusOne = (frac64A>>(shift-1)) & 0x1;
			expA<<= (28-regA);
			if (frac64A<<(65-shift)) bitsMore=1;

		}
		else {
			if (regA==30){
				bitNPlusOne = expA&0x2;
				bitsMore = (expA&0x1);
				expA = 0;
			}
			else if (regA==29){
				bitNPlusOne = expA&0x1;
				expA>>=1; //taken care of by the pack algo
			}
			if (frac64A>0){
				fracA=0;
				bitsMore =1;
			}
		}

		uA.ui = packToP32UI(regime, expA, fracA);
		if (bitNPlusOne)
			uA.ui +=  (uA.ui&1) |   bitsMore;

	}
	if (sign) uA.ui = -uA.ui & 0xFFFFFFFF;

	return uA.p;

}



