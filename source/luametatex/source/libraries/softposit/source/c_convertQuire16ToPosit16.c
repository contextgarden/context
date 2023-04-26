
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

//TODO DEPRECATED
posit16_t convertQ16ToP16(quire16_t qA){
	return q16_to_p16(qA);
}


posit16_t q16_to_p16(quire16_t qA){
	union ui128_q16 uZ;
	union ui16_p16 uA;
	uint_fast16_t regA, fracA = 0, shift=0, regime;
	uint_fast64_t frac64A;
	bool sign, regSA=0, bitNPlusOne=0, bitsMore=0;
	int_fast8_t expA = 0;


	if (isQ16Zero(qA)){
		uA.ui=0;
		return uA.p;
	}
	//handle NaR
	else if (isNaRQ16(qA)){
		uA.ui=0x8000;
		return uA.p;
	}

	uZ.q = qA;

	sign = uZ.ui[0]>>63;

	if(sign){
		//probably need to do two's complement here before the rest.
		if (uZ.ui[1]==0){
			uZ.ui[0] = -uZ.ui[0];
		}
		else{
			uZ.ui[1] = -uZ.ui[1];
			uZ.ui[0] = ~(uZ.ui[0]);
		}
	}


	int noLZ =0;

	if (uZ.ui[0] == 0){
		noLZ+=64;
		uint_fast64_t tmp = uZ.ui[1];

		while(!(tmp>>63)){
			noLZ++;
			tmp<<=1;
		}
		frac64A = tmp;
	}
	else{
		uint_fast64_t tmp = uZ.ui[0];
		int noLZtmp = 0;

		while(!(tmp>>63)){
			noLZtmp++;
			tmp<<=1;
		}
		noLZ+=noLZtmp;
		frac64A = tmp;
		frac64A+= ( uZ.ui[1]>>(64-noLZtmp) );
		if (uZ.ui[1]<<noLZtmp)bitsMore = 1;
	}

	//default dot is between bit 71 and 72, extreme left bit is bit 0. Last right bit is bit 127.
	//Equations derived from quire16_mult  last_pos = 71 - (kA<<1) - expA and first_pos = last_pos - frac_len
	int kA=(71-noLZ) >> 1;
	expA = 71 - noLZ - (kA<<1) ;

	if(kA<0){
		regA = (-kA & 0xFFFF);
		regSA = 0;
		regime = 0x4000>>regA;
	}
	else{
		regA = kA+1;
		regSA=1;
		regime = 0x7FFF - (0x7FFF>>regA);
	}

	if(regA>14){
		//max or min pos. exp and frac does not matter.
		(regSA) ? (uA.ui= 0x7FFF): (uA.ui=0x1);
	}
	else{

		//remove hidden bit
		frac64A&=0x7FFFFFFFFFFFFFFF;
		shift = regA+50; //1 es bit, 1 sign bit and 1 r terminating bit , 16+31+3
		fracA = frac64A>>shift;

		if (regA!=14){
			bitNPlusOne = (frac64A>>(shift-1)) & 0x1;
			unsigned long long tmp = frac64A<<(65-shift);
			if(frac64A<<(65-shift)) bitsMore = 1;
		}
		else if (frac64A>0){
			fracA=0;
			bitsMore=1;
		}

		if (regA==14 && expA) bitNPlusOne = 1;

		uA.ui = packToP16UI(regime, regA, expA, fracA);

		if (bitNPlusOne){
			uA.ui += (uA.ui&1) |  bitsMore;
		}
	}

	if (sign) uA.ui = -uA.ui & 0xFFFF;
	return uA.p;
}



