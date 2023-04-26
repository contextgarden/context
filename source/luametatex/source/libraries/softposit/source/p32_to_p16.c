
/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane).

Copyright 2017 2018 A*STAR.  All rights reserved.

This C source file was based on SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3d, by John R. Hauser.

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

posit16_t pX2_to_p16( posit_2_t pA ){
	posit32_t p32 = {.v = pA.v};
	return p32_to_p16(p32);
}

posit16_t p32_to_p16( posit32_t pA ){

	union ui32_p32 uA;
	union ui16_p16 uZ;
	uint_fast32_t uiA, tmp=0, exp_frac32A;
	uint_fast16_t regime, exp_frac=0;
	bool sign, regSA, bitsMore=0, bitNPlusOne=0;
	int_fast16_t kA=0, regA;

	uA.p = pA;
	uiA = uA.ui;

	if (uiA==0x80000000 || uiA==0 ){
		uZ.ui = (uint16_t)(uiA>>16);
		return uZ.p;
	}

	sign = signP32UI( uiA );
	if (sign) uiA = -uiA & 0xFFFFFFFF;

	if (uiA>0x7F600000) uZ.ui = 0x7FFF;
	else if (uiA<0x00A00000) uZ.ui = 0x1;
	else{
		regSA = signregP32UI(uiA);

		//regime
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
		//exp and frac
		exp_frac32A = tmp<<1;
printBinary(&exp_frac32A, 32);
printf("kA: %d\n", kA);
		if(kA<0){
			regA = (-kA)<<1;
			if (exp_frac32A&0x80000000) regA--;
			exp_frac32A = (exp_frac32A<<1) &0xFFFFFFFF;
			regSA = 0;
			regime = 0x4000>>regA;
		}
		else{
			regA = (kA<<1)+1;
			if (exp_frac32A&0x80000000) regA++;
			exp_frac32A = (exp_frac32A<<1) &0xFFFFFFFF;
			regSA=1;
			regime = 0x7FFF - (0x7FFF>>regA);
		}
		if ((exp_frac32A>>(17+regA)) & 0x1) bitNPlusOne = 1;
		if (regA<14) exp_frac = (uint16_t) (exp_frac32A>>(18+regA));

		uZ.ui = regime + exp_frac;
		if (bitNPlusOne){
			if ((exp_frac32A<<(15-regA)) & 0xFFFFFFFF) bitsMore=1;
			uZ.ui += (bitNPlusOne & (uZ.ui&1)) | ( bitNPlusOne & bitsMore);
		}
	}




	if (sign) uZ.ui = (-uZ.ui & 0xFFFF);
	return uZ.p;
}

