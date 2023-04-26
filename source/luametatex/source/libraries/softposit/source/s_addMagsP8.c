
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


#include "platform.h"
#include "internals.h"

#ifdef SOFTPOSIT_EXACT
posit8_t softposit_addMagsP8( uint_fast8_t uiA, uint_fast8_t uiB, bool isExact){
#else
posit8_t softposit_addMagsP8( uint_fast8_t uiA, uint_fast8_t uiB ){
#endif

	uint_fast8_t regA;
	uint_fast16_t frac16A, frac16B;
	uint_fast8_t fracA=0,  regime, tmp;
	bool sign, regSA, regSB, rcarry=0, bitNPlusOne=0, bitsMore=0;
	int_fast8_t kA=0;
	int_fast16_t shiftRight;
	union ui8_p8 uZ;

	sign = signP8UI( uiA ); //sign is always positive.. actually don't have to do this.
	if (sign){
		uiA = -uiA & 0xFF;
		uiB = -uiB & 0xFF;
	}

	if ((int_fast8_t)uiA < (int_fast8_t)uiB){
		uiA ^= uiB;
		uiB ^= uiA;
		uiA ^= uiB;
	}
	regSA = signregP8UI( uiA );
	regSB = signregP8UI( uiB );

	tmp = (uiA<<2) & 0xFF;
	if (regSA){
		while (tmp>>7){
			kA++;
			tmp= (tmp<<1) & 0xFF;
		}
	}
	else{
		kA=-1;
		while (!(tmp>>7)){
			kA--;
			tmp= (tmp<<1) & 0xFF;
		}
		tmp&=0x7F;
	}
	frac16A = (0x80 | tmp) << 7;
	shiftRight = kA;

	tmp = (uiB<<2) & 0xFF;
	if (regSB){
		while (tmp>>7){
			shiftRight--;
			tmp= (tmp<<1) & 0xFF;
		}
	}
	else{
		shiftRight++;
		while (!(tmp>>7)){
			shiftRight++;
			tmp= (tmp<<1) & 0xFF;
		}
		tmp&=0x7F;
	}
	frac16B = (0x80 | tmp) <<7 ;

	//Manage CLANG (LLVM) compiler when shifting right more than number of bits
	(shiftRight>7) ? (frac16B=0): (frac16B >>= shiftRight); //frac32B >>= shiftRight

	frac16A += frac16B;

	rcarry = 0x8000 & frac16A; //first left bit
	if (rcarry){
		kA++;
		frac16A>>=1;
	}

	if(kA<0){
		regA = (-kA & 0xFF);
		regSA = 0;
		regime = 0x40>>regA;
	}
	else{
		regA = kA+1;
		regSA=1;
		regime = 0x7F-(0x7F>>regA);
	}

	if(regA>6){
		//max or min pos. exp and frac does not matter.
		(regSA) ? (uZ.ui= 0x7F): (uZ.ui=0x1);
	}
	else{
		frac16A = (frac16A&0x3FFF) >> regA;
		fracA = (uint_fast8_t) (frac16A>>8);
		bitNPlusOne = (0x80 & frac16A) ;
		uZ.ui = packToP8UI(regime, fracA);

		//n+1 frac bit is 1. Need to check if another bit is 1 too if not round to even
		if (bitNPlusOne){
			if (0x7F & frac16A) bitsMore=1;
			uZ.ui += (uZ.ui&1) | bitsMore;
		}
	}
	if (sign) uZ.ui = -uZ.ui & 0xFF;
	return uZ.p;
}


